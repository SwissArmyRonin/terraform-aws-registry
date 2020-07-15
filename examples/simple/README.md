# Full example

This shows an example of setting up a minal registry.

**NB: Remember to ccpy `terraform.tfvars.sample` to `terraform.tfvars`, and fill in some proper values!**

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| archive | ~> 1.3 |
| aws | ~> 2.70 |
| null | ~> 2.1 |
| random | ~> 2.2 |

## Providers

| Name | Version |
|------|---------|
| random | ~> 2.2 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_tokens | GitHub personal access tokens. The keys in the map are either a "organization",<br>    or a "username", and the values are a personal access token. If a private<br>    repository sends a webhook, there must be a corresponding token for the <br>    originating repository's user or organization, in order for the registry to<br>    clone the repo. Tokens are stored as encrypted values in SSM parameters store. | `map(string)` | n/a | yes |

## Outputs

No output.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
