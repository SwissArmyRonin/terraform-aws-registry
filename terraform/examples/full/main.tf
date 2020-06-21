provider "aws" {
    version = "~> 2.67"
    region = "eu-central-1"
}

provider "random" {
    version = "~> 2.2"
}

resource "random_pet" "name" {
    prefix = "terraform-registry"
}

module "registry" {
    source = "../.."
    
    registry_name = random_pet.name.id
    store_bucket = random_pet.name.id

    tags = {
        "Environment" = terraform.workspace
    }
}