output "bucket_name" {
  description = "The generated bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN, for use in IAM policies."
  value       = aws_s3_bucket.this.arn
}

output "versioning" {
  description = "Whether versioning is on."
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}
