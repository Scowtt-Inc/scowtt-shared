# Partial backend — `key` per tenant lives in backend.hcl next to this file.
# State key convention: aws/datasync/<env>/tenants/<id>/02-datasync/terraform.tfstate

terraform {
  backend "s3" {
    bucket         = "scowtt-tfstate-prod"     # bootstrap/01-state-backend → state_bucket_name
    region         = "us-east-1"
    dynamodb_table = "scowtt-tfstate-locks"    # bootstrap/01-state-backend → state_lock_table_name
    encrypt        = true
  }
}
