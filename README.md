# Serverless Private Terraform Registry

This module creates a Terraform registry. 

Using the code in the project, it is possible to deploy a serverless Terraform module registry in AWS, backed by GitHub.

## Why do you need this

When using git as storage for Terraform modules, there are a number of drawbacks.

### Versioning

It is not possible to use the source/version syntax when including. Instead, one has to proveide a speicif url, including a version in a provider specific format.

Example: Sourcing the latest patch of version 1.0 for the "security-module".

```terraform
module "sg" {
    source = "git@github.com:swissarmyronin/example?ref=v1.0.2"
	...
}
```

If the module had been in a Terraform registry, it would be possible to specify that in a clearer manner, where the specific patch was left to Terraform.

```terraform
module "sg" {
    source = "registry.io/swissarmyronin/example/aws"
    version = "~> 1.0"
    ...
}
```

The second example simply points at the latest patch of version 1.0.

### Download speed

When you have a large project with many modules and a lot of history, another issue becomes apparent. Suddenly the download stage of `terraform init` becomes a bottle-neck. 

This happens because GitHub throttles frequent traffic, meaning that running multiple pulls becomes slow, and it happens because the process fetches a lot of irrelevant information, such as documentation, examples, build-files, and Git historical data. There is no way to tell Terraform that only the module core is needed.

## What you get

This project provides a private Terraform Registry, where every Git release of a module triggers a new version in the registry, while protecting against the loss of old versions, if someone makes accidental reuse of an old version tag.

The registry also filters the code that Terraform gets from the registry based on a mechanism similar to .gitignore, meaning that downloads stay fast and small as the repository with the module grows.

Finally, it decouples the source of the module from the use, allowing the use of private GitHub repositories as backing for public modules.

## How it works

For a more detailed description of the features, see the [docs/README.md](docs/README.md)-file.

## Future work

The initial design is focused on a very narrow set of uses cases, but some additions could be envisaged:

### Support the login protocol

The current registry can have private sources of modules, but all modules are public. A future feature would be to support a the Terraform [login protocol](https://www.terraform.io/docs/commands/login.html#protocol-v1) as well, to make the registry truly private.

### Supporting other sources than GitHub

To support other back-ends than Git, it would be simple to add additional Clone Lambdas that support other back-ends. As long as new releases can trigger a web-hook with enough information to fetch and store the release in the registry.

### Graphical user-interface

It would be nice to have a simple UI interface  for the repository similar to Terraform's public registry, where the input and output variables, along with a README file could be stored.

### Support the whole Terraform registry API

Currently on the registry part is finished, but the example shows how to populate and use the registry as is.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.12 |

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_tokens | GitHub personal access tokens. The keys in the map are either a "organization",<br>    or a "username", and the values are a personal access token. If a private<br>    repository sends a webhook, there must be a corresponding token for the <br>    originating repository's user or organization, in order for the registry to<br>    clone the repo. Tokens are stored as encrypted values in SSM parameters store. | `map(string)` | `{}` | no |
| api\_name | The name of the API gateway that fronts the registry. | `string` | `"terraform-registry"` | no |
| custom\_domain\_name | If a custom domain name is assigned to the API gateway, provide it here | `string` | `null` | no |
| github\_secret | The secret used by GitHub webhooks. Secrets are stored as encrypted values in SSM parameters store. | `string` | n/a | yes |
| lambda\_registry\_name | The name of the lambda that handles Terraform registry queries. | `string` | `"terraform-registry"` | no |
| lambda\_registry\_role\_name | The name of the role used to execute the registry lambda. | `string` | `"terraform-registry-role"` | no |
| lambda\_webhook\_name | The name of the lambda that handles Terraform registry update. | `string` | `"terraform-webhook"` | no |
| lambda\_webhook\_role\_name | The name of the role used to execute the webhook lambda. | `string` | `"terraform-webhook-role"` | no |
| registry\_name | The name of the DynamoDB table used to store the registry. | `string` | `"terraform-registry"` | no |
| ssm\_prefix | Secret values are stored as SSM parameters with this prefix | `string` | `"terraform-registry"` | no |
| store\_bucket | The name of the bucket used to store the module binaries. | `string` | n/a | yes |
| tags | A set of tags that should be applied to all resources, if possible | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| endpoint\_root | The root address of registry endpoints |
| registry\_name | The name of the registry DynamoDB table |
| store\_bucket\_id | The name of the registry S3 bucket |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Pre-commit hooks

If you intend to contribute, make sure to install and run the pre-commit hooks before making a PR.

See [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) for more info.