# used this file
# https://cloud.google.com/network-connectivity/docs/vpn/how-to/automate-vpn-setup-with-terraform
module "name" {
  source           = "github.com/ParisaMousavi/gcp-naming?ref=master"
  prefix           = var.prefix
  name             = var.name
  environment      = var.environment
  region_shortname = var.region_shortname
}

module "vpc" {
  source                  = "github.com/ParisaMousavi/gcp-vpc?ref=main"
  name                    = module.name.vpc
  project                 = var.gcp_project
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  subnets                 = local.subnets
}

module "gcr" {
  source         = "github.com/ParisaMousavi/gcp-gcr?ref=main"
  name           = module.name.gcr
  location       = var.location
  format         = "DOCKER"
  immutable_tags = true
  additional_labels = {
    "prefix"           = var.prefix,
    "name"             = var.name,
    "environment"      = var.environment,
    "region_shortname" = var.region_shortname
  }
}

# Each GCP project can only have one App Engine. If it's already enabled this line is not required.
#--------------------------------------------------
# resource "google_app_engine_application" "this" {
#   project     = data.google_project.this.project_id
#   location_id = var.location
# }

resource "google_service_account" "cloudbuild_service_account" {
  account_id = "cloud-sa" # "cloud-sa@dummy-parisa-2023.iam.gserviceaccount.com"
}

output "email" {
  value = google_service_account.cloudbuild_service_account.email
}


#----------------------------------------------------------------------------------
# gcloud projects add-iam-policy-binding ${PROJECT_ID} \
#         --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
#         --role="roles/iam.serviceAccountUser"
#----------------------------------------------------------------------------------
resource "google_project_iam_member" "act_as" {
  project = data.google_project.this.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}


# Cloud Build will need rights to access the on-demand scanning api.
#----------------------------------------------------------------------------------
# gcloud projects add-iam-policy-binding ${PROJECT_ID} \
#         --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
#         --role="roles/ondemandscanning.admin"
#----------------------------------------------------------------------------------
resource "google_project_iam_member" "ondemandscanning" {
  project = data.google_project.this.project_id
  role    = "roles/ondemandscanning.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_project_iam_member" "logs_writer" {
  project = data.google_project.this.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}


# roles/storage.admin
resource "google_project_iam_member" "storage_admin" {
  project = data.google_project.this.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_secret_manager_secret" "github-token-secret" {
  secret_id = "github-token-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github-token-secret-version" {
  secret      = google_secret_manager_secret.github-token-secret.id
  secret_data = file("pat.txt")
}

data "google_iam_policy" "p4sa-secretAccessor" {
  binding {
    role = "roles/secretmanager.secretAccessor"
    // Here, 123456789 is the Google Cloud project number for the project that contains the connection.
    members = ["serviceAccount:service-${data.google_project.this.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  secret_id   = google_secret_manager_secret.github-token-secret.secret_id
  policy_data = data.google_iam_policy.p4sa-secretAccessor.policy_data
}

# Source: https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github#gcloud
resource "google_cloudbuildv2_connection" "my-connection" {
  depends_on = [
    google_secret_manager_secret_iam_policy.policy
  ]
  location = var.location
  name     = module.name.cbv2con
  github_config {
    app_installation_id = 52576984
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret-version.id
    }
  }
}

resource "google_cloudbuildv2_repository" "my-repository" {
  location          = var.location
  name              = "my-repo"
  parent_connection = google_cloudbuildv2_connection.my-connection.name
  remote_uri        = "https://github.com/ParisaMousavi/gcp-sampels.git"
}

# # gcloud builds submit
# #----------------------------------------------------------------------------------
# resource "google_cloudbuild_trigger" "github" {
#   depends_on = [
#     google_project_iam_member.act_as,
#     google_project_iam_member.logs_writer
#   ]
#   name     = "test"
#   location = var.location
#   trigger_template {
#     branch_name = "main"
#     repo_name   = google_cloudbuildv2_repository.my-repository.name
#   }
#   filename        = "sample2/cloudbuild.yaml"
#   service_account = google_service_account.cloudbuild_service_account.id
# }

resource "google_cloudbuild_trigger" "demo-trigger" {
  location = var.location
  name     = module.name.trig
  repository_event_config {
    repository = google_cloudbuildv2_repository.my-repository.id
    push {
      branch = "main"
    }
  }
  filename        = "quickstart-docker/cloudbuild.yaml"
  service_account = google_service_account.cloudbuild_service_account.id
  substitutions = {
    "_SERVICE_NAME" = "quickstart"
  }
}


