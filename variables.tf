variable "PAT" {
  description = "personal access token"
  default     = ""
}
variable "ORG" {
  description = "org name of repo"
  default     = "obynodavid12"
}
variable "REPO" {
  description = "repo name"
  default     = "ecs-runners"
}
variable "AWS_REGION" {
  description = "region"
  default     = "us-east-2"
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "aws secret access key"
  default     = ""
}
variable "AWS_ACCESS_KEY_ID" {
  description = "aws access key id"
  default     = ""
}

variable "PREFIX" {
  default = "ecs-runner"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default     = "172.31.0.0/16"
}

variable "private_subnet_cidr" {
  description = "CIDR for the Private Subnet"
  default     = "172.31.32.0/20"
}

variable "public_subnet_cidr" {
  description = "CIDR for the Public Subnet"
  default     = "172.31.48.0/20"
}
