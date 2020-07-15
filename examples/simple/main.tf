resource "random_pet" "name" {
  prefix = "terraform-registry"
}

module "registry" {
  source        = "../.."
  store_bucket  = random_pet.name.id
  github_secret = "supersecret"
  # access_tokens = var.access_tokens # Only needed if there are private repos sending web-hooks
}

