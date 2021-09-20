#!/bin/bash
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

#<!--* freshness: { owner: 'ttaggart@google.com' reviewed: '2020-oct-01' } *-->


# This script sets the env variables.


#### Below commands needs to be set from shell if #####
#### your account is part of a gcp organization. ######
# export TF_VAR_org_id=$(gcloud organizations list | \
#    awk '/your-organization-name/ {print $2}')
# export TF_VAR_org_id
#######################################################


TF_VAR_user_account="$(gcloud auth list \
  --filter=status:ACTIVE \
  --format="value(account)")"
export TF_VAR_user_account

TF_VAR_billing_account="$(gcloud beta billing accounts list \
  --format="value(ACCOUNT_ID)" \
  --filter=NAME:"$TF_VAR_billing_name")"
export TF_VAR_billing_account

TF_VAR_pid="$(echo pm-pid-$(od -An -N4 -i /dev/random) \
  | sed 's/ //')"
export TF_VAR_pid

TF_VAR_region=us-west1
export TF_VAR_region

TF_VAR_zone=us-west1-b
export TF_VAR_zone
