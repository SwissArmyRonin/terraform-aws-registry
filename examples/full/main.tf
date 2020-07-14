
resource "random_pet" "name" {
  prefix = "terraform-registry"
}

locals {
  secret             = "supersecret"
  custom_domain_name = var.custom_domain_name
}

module "registry" {
  source = "../.."

  registry_name             = random_pet.name.id
  store_bucket              = random_pet.name.id
  api_name                  = random_pet.name.id
  lambda_webhook_name       = format("webhook-%s", random_pet.name.id)
  lambda_registry_name      = format("registry-%s", random_pet.name.id)
  lambda_webhook_role_name  = format("webhook-%s", random_pet.name.id)
  lambda_registry_role_name = format("registry-%s", random_pet.name.id)
  github_secret             = local.secret
  custom_domain_name        = local.custom_domain_name
  access_tokens             = var.access_tokens

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

data "archive_file" "webhook" {
  type        = "zip"
  source_dir  = format("%s/sample", path.module)
  output_path = format("%s/sample.zip", path.module)
}

resource "aws_s3_bucket_object" "module" {
  bucket        = module.registry.store_bucket_id
  key           = format("%s/%s/%s/%s.zip", local.namespace, local.name, local.provider, local.version)
  source        = data.archive_file.webhook.output_path
  storage_class = "REDUCED_REDUNDANCY"
}

resource "aws_dynamodb_table_item" "module" {
  table_name = module.registry.registry_name
  hash_key   = "Id"
  range_key  = "Version"

  item = jsonencode({
    "Id" : { "S" : format("%s/%s/%s", local.namespace, local.name, local.provider) },
    "Version" : { "S" : local.version }
  })
}

output "example" {
  value = <<TEXT
    Put the following in your ~/.terraformrc file:
    
      host "registry.io" {
        services = {
          "modules.v1" = "${module.registry.endpoint_root}/modules/"
        }
      }
    
    To load the example module, use this:
    
      module "example" {
          source = "${local.custom_domain_name != null ? local.custom_domain_name : "registry.io"}/swissarmyronin/example/aws"
          version = "~> 1.0"
          prefix = "test"
      }

    Add the following webhook to your GitHub repo:

      Payload URL: ${module.registry.endpoint_root}/webhook
      Content type: application/json
      Secret: ${local.secret}
      SSL verification: enabled
      Events: "Let me select individual events"
      ... then deselect everything and select "Branch or tag creation"
  TEXT
}
