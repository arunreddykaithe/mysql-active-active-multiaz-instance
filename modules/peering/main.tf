# ========================================
# VPC Peering Module
# ========================================

# VPC Peering Connection (created in requester region)
resource "aws_vpc_peering_connection" "main" {
  provider = aws.requester

  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  peer_region = var.accepter_region
  auto_accept = false

  tags = merge(
    var.tags,
    {
      Name = var.peering_name
      Side = "Requester"
    }
  )
}

# Accept VPC Peering Connection (in accepter region)
resource "aws_vpc_peering_connection_accepter" "main" {
  provider = aws.accepter

  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true

  tags = merge(
    var.tags,
    {
      Name = var.peering_name
      Side = "Accepter"
    }
  )
}

# Add route to accepter VPC in requester route table
resource "aws_route" "requester_to_accepter" {
  provider = aws.requester

  route_table_id            = var.requester_route_table_id
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}

# Add route to requester VPC in accepter route table
resource "aws_route" "accepter_to_requester" {
  provider = aws.accepter

  route_table_id            = var.accepter_route_table_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}
