output "id" {
  description = "The ID of the S3 bucket."
  value       = try(aws_s3_bucket.main.id, null)
}

output "arn" {
  description = "The ARN of the S3 bucket."
  value       = try(aws_s3_bucket.main.arn, null)
}

output "queues" {
  description = "List of objects of each created queue."
  value = [for index, value in try(var.queues, []) : {
    url = aws_sqs_queue.main[index].url
    arn = aws_sqs_queue.main[index].arn
  }]
}
