#   Copyright 2023 Google LLC
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Region where to deploy Cloud Functions"
  type        = string
}

variable "cloud_deploy_region" {
  description = "Region where your Cloud Deploy resources are in"
  type        = string
}

variable "chat_space" {
  description = "Google Chat space ID"
  type        = string
}

variable "delivery_pipeline_name" {
  description = "Delivery pipeline name"
  type        = string
  default     = "helloworld-app"
}

variable "build_bucket" {
  description = "Build bucket for passing Skaffold files"
  type        = string
  default     = null
}

variable "cloud_deploy_repository" {
  description = "Git repository containing your Cloud Deploy files (skaffold.yaml)"
  type        = string
}

