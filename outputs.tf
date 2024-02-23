output "id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "read_policy" {
  description = "An object of IAM policy to allow read access of the S3 bucket"
  value = {
    name   = "${var.identifier}-GetBucketObjects"
    policy = data.aws_iam_policy_document.bucket_read.json
  }
}

output "write_policy" {
  description = "An object of IAM policy to allow write access of the S3 bucket"
  value = {
    name   = "${var.identifier}-PutBucketObjects"
    policy = data.aws_iam_policy_document.bucket_write.json
  }
}

output "queues" {
  description = "List of objects of each created queue"
  value = [for index, value in var.queues : {
    url = aws_sqs_queue.main[index].url
    subscription_policy = {
      name   = "${value["identifier"]}-SubscribeQueue"
      policy = data.aws_iam_policy_document.sqs_subscribe[index].json
    }
  }]
}
