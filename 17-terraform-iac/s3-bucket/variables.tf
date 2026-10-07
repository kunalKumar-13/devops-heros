variable "aws_region" {
  description = "Region to create the bucket in."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Prefix for the bucket name and a tag on everything."
  type        = string
  default     = "kunal-devops"
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "enable_versioning" {
  description = "Keep every version of every object, so deletes and overwrites are recoverable."
  type        = bool
  default     = true
}
