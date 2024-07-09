variable "prefix" {
  type    = string
  default = "poc"
}

variable "name" {
  type    = string
  default = "lrn"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["acc", "dev", "prod"], lower(var.environment))
    error_message = "The environment for this resource must be acc, dev, oder prod."
  }
}

variable "region_shortname" {
  type    = string
  default = "euw1"
}

variable "gcp_project" {
  type    = string
  default = "dummy-parisa-2023"
}

variable "location" {
  type    = string
  default = "europe-west1"
}
