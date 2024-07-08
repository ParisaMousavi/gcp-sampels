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

# gcloud builds submit
#----------------------------------------------------------------------------------
# resource "google_cloudbuild_trigger" "filename-trigger" {
#   name     = "test"
#   location = var.location
#   filename = "/workspaces/gcp-iac/quickstart-docker/cloudbuild.yaml"
# }