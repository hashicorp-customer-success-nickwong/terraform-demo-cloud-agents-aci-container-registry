variable "prefix" {
  type    = string
  default = "nwong"
}

variable "github_organization" {
  type    = string
  default = "hashicorp-customer-success-nickwong"
}

variable "github_token" {
  type = string
}

variable "location" {
  type    = string
  default = "Canada Central"
}

variable "location_secondary" {
  type    = string
  default = "East US"
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    owner       = "nick-wong"
  }
}
