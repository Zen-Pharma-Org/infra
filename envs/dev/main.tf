terraform {
  backend "s3" {
    bucket       = "zen-pharma-terraform-state-ravi-891498120856"
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "pharma"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name = "pharma-dev-vpc"
  cidr = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]

  database_subnets = [
    "10.0.5.0/24",
    "10.0.6.0/24"
  ]

  tags = {
    Project     = "pharma"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
module "eks" {
  source = "../../modules/eks"

  project = "pharma"
  env     = "dev"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  kubernetes_version = "1.33"

  instance_types = ["t3.micro"]

  desired_size = 2
  min_size     = 1
  max_size     = 3
}
module "iam" {
  source = "../../modules/iam"

  project = "pharma"
  env     = "dev"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  aws_account_id = "891498120856"

  github_org = "Zen-Pharma-Org"
}
module "ecr" {
  source = "../../modules/ecr"

  project = "pharma"
  env     = "dev"

  repositories = [
    "api-gateway",
    "auth-service",
    "drug-catalog-service",
    "inventory-service",
    "manufacturing-service",
    "notification-service",
    "pharma-ui",
    "supplier-service",
    "qc-service",
  ]
}
module "rds" {
  source = "../../modules/rds"

  project = "pharma"
  env     = "dev"

  username = "pharmaadmin"
  password = var.db_password

  vpc_id = module.vpc.vpc_id

  db_subnet_group_name = module.vpc.database_subnet_group_name

  eks_node_security_group_id = module.eks.node_security_group_id
}
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project     = "pharma"
  env         = "dev"
  db_username = "pharmaadmin"
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
  db_host     = module.rds.db_instance_address
}
