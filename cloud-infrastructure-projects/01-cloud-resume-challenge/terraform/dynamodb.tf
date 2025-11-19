# DynamoDB table for visitor counter
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "${var.project_name}-visitor-counter"
  billing_mode   = "PAY_PER_REQUEST" # On-demand pricing
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-visitor-counter"
  }
}

# Initialize the visitor counter with a starting value
resource "aws_dynamodb_table_item" "visitor_counter_init" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = jsonencode({
    id = {
      S = "visitor_count"
    }
    count = {
      N = "0"
    }
  })

  lifecycle {
    ignore_changes = [item]
  }
}
