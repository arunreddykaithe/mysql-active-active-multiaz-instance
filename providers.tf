terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region provider
provider "aws" {
  alias  = "region1"
  region = var.region1
  
  default_tags {
    tags = {
      Project     = "MySQL-MultiAZ-ActiveActive"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.region1
    }
  }
}

# Secondary region provider
provider "aws" {
  alias  = "region2"
  region = var.region2
  
  default_tags {
    tags = {
      Project     = "MySQL-MultiAZ-ActiveActive"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.region2
    }
  }
}
