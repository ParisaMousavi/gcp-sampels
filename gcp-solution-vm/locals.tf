locals {
  subnets = jsondecode(file("${path.module}/config/subnets.json"))
}