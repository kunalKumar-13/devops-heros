variable "aws_region" {
  description = "Region for the network."
  type        = string
  default     = "ap-south-1"
}

variable "availability_zone" {
  description = "AZ for the public subnet."
  type        = string
  default     = "ap-south-1a"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "kunal-web"
}

variable "vpc_cidr" {
  description = "Address range for the whole VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Address range for the public subnet; must sit inside vpc_cidr."
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_cidr" {
  description = "Who may SSH in. Your own IP/32 in real use, never 0.0.0.0/0."
  type        = string
  default     = "203.0.113.10/32"
}
