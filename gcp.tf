#
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#<!--* freshness: { owner: 'ttaggart@google.com' reviewed: '2020-sep-21' } *-->


/*
 *---------- Add GCP project and enable APIs. -----------
 */

resource "google_project" "bce" {
  name            = "beyond-corp-enterprise"
  project_id      = var.pid
  # If your gcp account is part of a gcp organization
  # uncomment the line below.
  # org_id          = var.org_id
  billing_account = data.google_billing_account.acct.id
}

resource "google_project_service" "compute_api" {
  project   = google_project.bce.project_id
  service   = "compute.googleapis.com"
}

resource "google_project_service" "deployment_manager_api" {
  project = google_project.bce.project_id
  service = "deploymentmanager.googleapis.com"
}

resource "google_project_service" "kubernetes_api" {
  project = google_project.bce.project_id
  service = "container.googleapis.com"
}

resource "google_project_service" "iap_api" {
  project = google_project.bce.project_id
  service = "iap.googleapis.com"
}

/*
 * ------- Enable network and subnet. ------------
 */

resource "google_compute_network" "bce" {
  name                    = "bce-vpc"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
  project                 = google_project.bce.project_id

  depends_on = [
    # The project's services must be set up before the
    # network is enabled as the compute API will not
    # be enabled and cause the setup to fail.
    google_project_service.compute_api,
  ]

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "google_compute_subnetwork" "host" {
  region        = var.region
  name          = "simulated-host-subnet"
  ip_cidr_range = "10.1.1.0/24"
  project       = google_project.bce.project_id
  network       = google_compute_network.bce.self_link

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "google_compute_subnetwork" "cluster" {
  region        = var.region
  name          = "cluster-subnet"
  ip_cidr_range = "10.1.2.0/24"
  project       = google_project.bce.project_id
  network       = google_compute_network.bce.self_link

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

/*
 * ----------VPN Connection----------
 */

resource "google_compute_address" "gcp_vpn_ip" {
  name   = "gcp-vpn-ip"
  region = var.region
  depends_on = [
    google_project.bce,
    google_project_service.compute_api,
  ]
}

resource "google_compute_vpn_gateway" "gcp_vpn_gw" {
  name    = "gcp-vpn-gw-${var.region}"
  network = google_compute_network.bce.name
  region  = var.region
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.gcp_vpn_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.self_link
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500-500"
  ip_address  = google_compute_address.gcp_vpn_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.self_link
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500-4500"
  ip_address  = google_compute_address.gcp_vpn_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.self_link
}


/*
 * ----------VPN Tunnel1----------
 */

resource "google_compute_vpn_tunnel" "gcp_tunnel1" {
  name          = "gcp-tunnel1"
  peer_ip       = aws_vpn_connection.aws_vpn_connection1.tunnel1_address
  shared_secret = aws_vpn_connection.aws_vpn_connection1.tunnel1_preshared_key
  ike_version   = 1

  target_vpn_gateway = google_compute_vpn_gateway.gcp_vpn_gw.self_link

  router = google_compute_router.gcp_router1.name

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_router" "gcp_router1" {
  name    = "gcp-router1"
  region  = var.region
  network = google_compute_network.bce.name
  bgp {
    asn = aws_customer_gateway.aws_cgw.bgp_asn
  }
}

resource "google_compute_router_peer" "gcp_router1_peer" {
  name            = "gcp-to-aws-bgp1"
  router          = google_compute_router.gcp_router1.name
  region          = google_compute_router.gcp_router1.region
  peer_ip_address = aws_vpn_connection.aws_vpn_connection1.tunnel1_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface1.name
}

resource "google_compute_router_interface" "router_interface1" {
  name       = "gcp-to-aws-interface1"
  router     = google_compute_router.gcp_router1.name
  region     = google_compute_router.gcp_router1.region
  ip_range   = "${aws_vpn_connection.aws_vpn_connection1.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel1.name
}

resource "google_compute_route" "route1" {
  name       = "to-aws"
  network    = google_compute_network.bce.name
  dest_range = "10.0.1.0/24"
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel1.id
}

/*
 * ----------VPN Tunnel2----------
 */

resource "google_compute_vpn_tunnel" "gcp_tunnel2" {
  name          = "gcp-tunnel2"
  peer_ip       = aws_vpn_connection.aws_vpn_connection1.tunnel2_address
  shared_secret = aws_vpn_connection.aws_vpn_connection1.tunnel2_preshared_key
  ike_version   = 1

  target_vpn_gateway = google_compute_vpn_gateway.gcp_vpn_gw.self_link

  router = google_compute_router.gcp_router2.name

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_router" "gcp_router2" {
  name    = "gcp-router2"
  region  = var.region
  network = google_compute_network.bce.name
  bgp {
    asn = aws_customer_gateway.aws_cgw.bgp_asn
  }
}

resource "google_compute_router_peer" "gcp_router2_peer" {
  name            = "gcp-to-aws-bgp2"
  router          = google_compute_router.gcp_router2.name
  region          = google_compute_router.gcp_router2.region
  peer_ip_address = aws_vpn_connection.aws_vpn_connection1.tunnel2_vgw_inside_address
  peer_asn        = "64512"
  interface       = google_compute_router_interface.router_interface2.name
}

resource "google_compute_router_interface" "router_interface2" {
  name       = "gcp-to-aws-interface2"
  router     = google_compute_router.gcp_router2.name
  region     = google_compute_router.gcp_router2.region
  ip_range   = "${aws_vpn_connection.aws_vpn_connection1.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.gcp_tunnel2.name
}

/*
 * --------- Create host to test curl command to AWS ----------
 */

resource "google_compute_instance" "host" {
  name                      = "host"
  machine_type              = "n1-standard-1"
  zone                      = var.zone
  project                   = var.pid
  allow_stopping_for_update = "true"
  # can_ip_forward            = "true"

  depends_on = [
    # The compute api must be set up before
    # the collector is created.
    google_project_service.compute_api,
  ]


  tags         = [
    "bce",
  ]

  boot_disk {
    initialize_params {
      image    = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork =google_compute_subnetwork.host.self_link

    access_config {
      // Ephemeral IP
    }
  }
}
