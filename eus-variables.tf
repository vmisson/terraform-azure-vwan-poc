variable "eus-location" {
  type    = string
  default = "East US2"
}

variable "eus-name" {
  type    = string
  default = "eus"
}

variable "eus-onprem-address-space" {
  type    = string
  default = "10.100.2.0/24"
}

variable "eus-onprem-asn" {
  type    = number
  default = 65003
}

variable "eus-vhub-address-space" {
  type    = string
  default = "10.30.0.0/23"
}

variable "eus-firewall-address-space" {
  type    = string
  default = "10.30.2.0/24"
}

variable "eus-spoke1-address-space" {
  type    = string
  default = "10.30.3.0/25"
}

variable "eus-spoke2-address-space" {
  type    = string
  default = "10.30.3.128/25"
}

