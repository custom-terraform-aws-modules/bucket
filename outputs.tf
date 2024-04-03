output "id" {
  description = "The ID of the S3 bucket."
  value       = "${var.identifier}-${random_string.suffix.result}"
}

output "arn" {
  description = "The ARN of the S3 bucket."
  value = var.storage_class == "DEFAULT" ? try(aws_s3_bucket.main[0].arn, null) : (
  try(aws_glacier_vault.main[0].arn, null))
}

output "uri" {
  description = "The URI of the S3 bucket."
  value = var.storage_class == "DEFAULT" ? (
    try(aws_s3_bucket.main[0].bucket_regional_domain_name, null)) : (
  try(aws_glacier_vault.main[0].location, null))
}

output "queues" {
  description = "List of objects of each created queue."
  value = [for index, value in var.queues : {
    queue_arn      = aws_sqs_queue.main[index].arn
    queue_url      = aws_sqs_queue.main[index].url
    deadletter_arn = local.deadletter_output[index]["arn"]
    deadletter_url = local.deadletter_output[index]["url"]
  }]
}
