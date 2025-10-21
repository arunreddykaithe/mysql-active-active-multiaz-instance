variable "peering_name" {
  description = "Name for the VPC peering connection"
  type        = string
}

variable "requester_vpc_id" {
  description = "ID of the requester VPC"
  type        = string
}

variable "requester_vpc_cidr" {
  description = "CIDR block of the requester VPC"
  type        = string
}

variable "requester_route_table_id" {
  description = "Route table ID in requester VPC"
  type        = string
}

variable "accepter_vpc_id" {
  description = "ID of the accepter VPC"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR block of the accepter VPC"
  type        = string
}

variable "accepter_route_table_id" {
  description = "Route table ID in accepter VPC"
  type        = string
}

variable "accepter_region" {
  description = "Region of the accepter VPC"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
