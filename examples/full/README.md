# Full example

This shows an example of setting up a registry and manually putting a module in it, that can then be referenced from the registry using the format:

```terraform
module "example" {
    source = "registry.io/swissarmyronin/example/aws"
    version = "~> 1.0"
    prefix = "test"
}
```

Since the sample is manually created, it won't be filtered with `.tfignore`.