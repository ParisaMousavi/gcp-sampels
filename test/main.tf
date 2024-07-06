resource "google_storage_bucket" "auto-expire" {
  name          = "shushihsa"
  location      = var.location
  force_destroy = true
}
