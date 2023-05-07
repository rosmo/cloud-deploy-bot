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

terraform {
  required_version = ">= 1.4.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.60.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.60.0"
    }
  }
}

locals {
  functions = {
    resources = {
      topic = "clouddeploy-resources"
    }
    operations = {
      topic = "clouddeploy-operations"
    }
    approvals = {
      topic = "clouddeploy-approvals"
    }
    chat = {
      topic = "clouddeploy-chat"
    }
  }
}

module "project" {
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project?ref=daily-2023.05.06"
  name           = var.project_id
  project_create = false
  services = [
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "chat.googleapis.com"
  ]
}

module "pubsub-topics" {
  for_each = local.functions

  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/pubsub?ref=daily-2023.05.06"
  project_id = module.project.project_id
  name       = each.value.topic
  iam = each.key == "chat" ? {
    "roles/pubsub.publisher" = ["serviceAccount:chat-api-push@system.gserviceaccount.com"]
    } : {
    "roles/clouddeploy.serviceAgent" = [format("serviceAccount:service-%d@gcp-sa-clouddeploy.iam.gserviceaccount.com", module.project.number)]
  }
}

data "google_service_account" "compute-engine-default" {
  account_id = format("%d-compute@developer.gserviceaccount.com", module.project.number)
}

module "chat-service-account" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=daily-2023.05.06"
  project_id = module.project.project_id
  name       = "cd-bot-chat"
  iam        = {}
  iam_sa_roles = {
    (data.google_service_account.compute-engine-default.name) = ["roles/iam.serviceAccountUser"]
  }
}

resource "google_service_account_iam_member" "chat-service-account-actas-self" {
  for_each = local.functions

  service_account_id = module.chat-service-account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.key == "chat" ? module.chat-service-account.iam_email : format("serviceAccount:%s", module.functions[each.key].service_account)
}

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

module "build-bucket" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=daily-2023.05.06"
  project_id = module.project.project_id

  name          = format("clouddeploy-render-%s", random_string.random.result)
  location      = var.cloud_deploy_region
  storage_class = "REGIONAL"
  labels        = {}

  lifecycle_rules = {
    lr-0 = {
      action = {
        type = "Delete"
      }
      condition = {
        age = 1
      }
    }
  }

  iam = {
    "roles/storage.objectAdmin" = [module.chat-service-account.iam_email]
  }
}

module "functions" {
  for_each = local.functions

  source =  "github.com/GoogleCloudPlatform/pubsub2inbox"

  project_id         = module.project.project_id
  region             = var.region
  cloud_functions_v2 = true

  function_name = format("cd-bot-%s", each.key)

  service_account        = each.key == "chat" ? module.chat-service-account.email : format("cd-bot-%s", each.key)
  create_service_account = each.key == "chat" ? false : true

  pubsub_topic = module.pubsub-topics[each.key].id

  config = templatefile("${path.module}/cloud-deploy-bot.yaml", {
    chat_space          = var.chat_space
    service_account     = module.chat-service-account.email
    build_bucket        = module.build-bucket.name
    repository          = var.cloud_deploy_repository
    cloud_deploy_region = var.cloud_deploy_region
    delivery_pipeline   = var.delivery_pipeline_name
  })
  use_local_files  = true
  local_files_path = "pubsub2inbox/"

  bucket_name     = format("clouddeploy-source-%s", each.key)
  bucket_location = var.region

  function_roles = each.key == "chat" ? ["cloud-deploy"] : ["cloud-deploy-ro"]
}
