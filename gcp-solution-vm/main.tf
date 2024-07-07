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

# Each GCP project can only have one App Engine. If it's already enabled this line is not required.
#--------------------------------------------------
# resource "google_app_engine_application" "this" {
#   project     = data.google_project.this.project_id
#   location_id = var.location
# }