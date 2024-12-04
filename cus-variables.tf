variable "cus-location" {
  type    = string
  default = "Central US"
}

variable "cus-name" {
  type    = string
  default = "cus"
}

variable "cus-onprem-address-space" {
  type    = string
  default = "10.100.3.0/24"
}

variable "cus-onprem-asn" {
  type    = number
  default = 65004
}

variable "cus-vhub-address-space" {
  type    = string
  default = "10.40.0.0/23"
}

variable "cus-firewall-address-space" {
  type    = string
  default = "10.40.2.0/24"
}

variable "cus-spoke1-address-space" {
  type    = string
  default = "10.40.3.0/25"
}

variable "cus-spoke2-address-space" {
  type    = string
  default = "10.40.3.128/25"
}

