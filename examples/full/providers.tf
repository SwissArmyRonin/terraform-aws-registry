provider "aws" {
  version = "~> 2.67"
  region  = "eu-central-1"
}

provider "random" {
  version = "~> 2.2"
}

provider "archive" {
  version = "~> 1.3"
}