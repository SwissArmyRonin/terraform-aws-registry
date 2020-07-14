variable "custom_domain_name" {
  description = "If a custom domain name is assigned to the API gateway, provide it here"
  type        = string
}

variable "access_tokens" {
  description = <<EOF
    GitHub personal access tokens. The keys in the map are either a "organization",
    or a "username", and the values are a personal access token. If a private
    repository sends a webhook, there must be a corresponding token for the 
    originating repository's user or organization, in order for the registry to
    clone the repo. Tokens are stored as encrypted values in SSM parameters store.
  EOF
  type        = map(string)
}
