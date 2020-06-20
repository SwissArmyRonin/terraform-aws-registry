# Serverless Private Terraform Registry

Using the code in the project, it is possible to deploy a serverless Terraform module registry in AWS, backed by GitHub.

## Why do you need this

When using git as storage for Terraform modules, there are a number of drawbacks.

### Versioning

It is not possible to use the source/version syntax when including. Instead, one has to proveide a speicif url, including a version in a provider specific format.

Example: Sourcing the latest patch of version 1.0 for the "security-module".

```terraform
module "sg" {
    source = "git@github.com:myorg/security-module?ref=v1.0.2"
	...
}
```

If the module had been in a Terraform registry, it would be possible to specify that in a clearer manner, where the specific patch was left to Terraform.

```terraform
module "sg" {
    source = "private-repo.com/myorg/security-module"
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