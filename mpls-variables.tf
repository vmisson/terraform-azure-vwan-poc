variable "mpls-location" {
  type    = string
  default = "North Europe"
}

variable "mpls-name" {
  type    = string
  default = "mpls"
}

variable "mpls-onprem-address-space" {
  type    = string
  default = "10.200.0.0/24"
}

variable "mpls-onprem-asn" {
  type    = number
  default = 65010
}


