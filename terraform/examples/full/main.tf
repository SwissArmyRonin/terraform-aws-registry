
resource "random_pet" "name" {
  prefix = "terraform-registry"
}

module "registry" {
  source = "../.."

  registry_name             = random_pet.name.id
  store_bucket              = random_pet.name.id
  api_name                  = random_pet.name.id
  lambda_registry_name      = random_pet.name.id
  lambda_registry_role_name = random_pet.name.id

  tags = {
    "Environment" = terraform.workspace
  }
}

# Simulate module in registry
locals {
  namespace = "swissarmyronin"
  provider  = "aws"
  name      = "example"
  version   = "1.0.0"
}

resource "aws_s3_bucket_object" "module" {
  bucket        = module.registry.store_bucket_id
  key           = format("%s/%s/%s/%s.zip", local.namespace, local.name, local.provider, local.version)
  source        = format("%s/terraform-aws-example-1.0.zip", path.module)
  storage_class = "REDUCED_REDUNDANCY"
}

resource "aws_dynamodb_table_item" "module" {
  table_name = module.registry.registry_name
  hash_key   = "Id"
  range_key  = "Version"

  item = jsonencode({
    "Id" : { "S" : "swissarmyronin/example/aws" },
    "Version" : { "S" : "1.0.0" }
  })
}

output "example" {
  value = <<TEXT
    Put the following in your ~/.terraformrc file:
    
      host "registry.io" {
        services = {
          "modules.v1" = "${module.registry.registry_endpoint}/"
        }
      }
    
    To load the example module, use this:
    
      module "example" {
          source = "registry.io/swissarmyronin/example/aws"
          version = "~> 1.0"
          prefix = "test"
      }
  TEXT
}