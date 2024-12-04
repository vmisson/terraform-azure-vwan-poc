variable "frc-location" {
  type    = string
  default = "France Central"
}

variable "frc-name" {
  type    = string
  default = "frc"
}

variable "frc-onprem-address-space" {
  type    = string
  default = "10.100.1.0/24"
}

variable "frc-onprem-asn" {
  type    = number
  default = 65002
}

variable "frc-vhub-address-space" {
  type    = string
  default = "10.20.0.0/23"
}

variable "frc-firewall-address-space" {
  type    = string
  default = "10.20.2.0/24"
}

variable "frc-spoke1-address-space" {
  type    = string
  default = "10.20.3.0/25"
}

variable "frc-spoke2-address-space" {
  type    = string
  default = "10.20.3.128/25"
}

