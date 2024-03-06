output "id" {
  description = "ID of the S3 bucket."
  value       = aws_s3_bucket.main.id
}

output "arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.main.arn
}

output "queues" {
  description = "List of objects of each created queue."
  value = [for index, value in var.queues : {
    url = aws_sqs_queue.main[index].url
    arn = aws_sqs_queue.main[index].arn
  }]
}
