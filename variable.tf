variable "region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = can(regex("[a-z][a-z]-[a-z]+-[1-9]", var.region))
    error_message = "Must be valid AWS Region."
  }
}

variable "project" {
  type    = string
  default = "iac-lambda-functions-deployment"
}

variable "api-key" {
  description = "Enter your openweather API key"
}

variable "subnet_public_cidr_block" {
  default = "10.0.1.0/24"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "subnet_private_cidr_block" {
  default = "10.0.2.0/24"
}

variable "ip" {
  type = string
  description = "Enter a IP CIDR Range for VPC Ingress Access"

  validation {
    condition     = can(cidrhost(var.ip, 0))
    error_message = "Must be valid IPv4 CIDR."
  }
}