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

#<!--* freshness: { owner: 'ttaggart@google.com' reviewed: '2019-sep-21' } *-->

 
resource "google_compute_firewall" "allow-10net" {
  name          = "allow-10net-ingress"
  network       = google_compute_network.bce.name
  project       = google_project.bce.project_id

  source_ranges = [
    "10.0.0.0/8", 
  ]

  allow {
    protocol    = "tcp"
  }

   allow {
    protocol    = "udp"
  }

  allow {
    protocol    = "icmp"
  }
}

resource "google_compute_firewall" "allow-ssh" {
  name          = "allow-ssh"
  network       = google_compute_network.bce.name
  project       = google_project.bce.project_id

  source_ranges = [
    "35.235.240.0/20", 
  ]

  allow {
    protocol    = "tcp"
    ports       = ["22"]
  }
}

