terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.36.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-saas-agnostic"
    prefix = "localtest/gcp-solution-vm"
  }
}

provider "google" {
  project     = var.gcp_project
  region      = var.location
  # credentials = "/workspaces/codespaces-blank/credentials.json"
}

