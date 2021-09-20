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

#<!--* freshness: { owner: 'ttaggart@google.com' reviewed: '2020-mar-01' } *-->


# This script writes the Terraform environment variables to a file. This
# file is used to reset or set env variables when your Cloud Shell sesion
# is terminated and the environment lost. To use issue:
#
#     source TF_ENV_VARS


env | grep TF_VAR > TF_ENV_VARS
sed -i "s/^/export /" TF_ENV_VARS
