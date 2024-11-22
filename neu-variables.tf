variable "neu-location" {
  type    = string
  default = "North Europe"
}

variable "neu-name" {
  type    = string
  default = "neu"
}

variable "neu-onprem-address-space" {
  type    = string
  default = "10.100.0.0/24"
}

variable "neu-onprem-asn" {
  type    = number
  default = 65001
}

variable "neu-vhub-address-space" {
  type    = string
  default = "10.10.0.0/23"
}

variable "neu-firewall-address-space" {
  type    = string
  default = "10.10.2.0/24"
}

variable "neu-spoke1-address-space" {
  type    = string
  default = "10.10.3.0/25"
}

variable "neu-spoke2-address-space" {
  type    = string
  default = "10.10.3.128/25"
}

