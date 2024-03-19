variable "name" {
  description = "The ECR name"
}

variable "scan_on_push" {
  description = "Whether to scan or not an image when pushing"
  default     = true
}

variable "image_mutability" {
  description = "Configuration regarding image mutability"
  default     = "IMMUTABLE"
}

variable "tags" {
  description = "The tags to associate with this repository"
  type        = map(string)
  default     = {}
}

variable "environment" {
  type        = string
  description = "The environment"
}

variable "owner" {
  type        = string
  description = "The owner of the product"
}

variable "product" {
  type        = string
  description = "The product"
}