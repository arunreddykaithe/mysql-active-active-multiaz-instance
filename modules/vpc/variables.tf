variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "peer_vpc_cidr" {
  description = "CIDR block of peer VPC for security group rules"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access MySQL"
  type        = list(string)
}

variable "map_public_ip_on_launch" {
  description = "Whether to assign public IPs to instances in subnets"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
