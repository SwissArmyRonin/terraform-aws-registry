# This is a sample module
variable "prefix" {
    description = "Bucket name prefix"
    type = string    
}

resource "aws_s3_bucket" "this" {
    bucket_prefix = var.prefix
}

output "bucket_id" {
    value = aws_s3_bucket.this.id
}