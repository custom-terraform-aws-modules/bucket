# to ensure unique identifier of S3 bucket
resource "random_string" "suffix" {
  length  = 63 - length(var.identifier) - 1
  special = false
  upper   = false
}

################################
# Glacier Vault                #
################################

resource "aws_sns_topic" "glacier" {
  count = var.storage_class == "GLACIER" ? 1 : 0
  name  = "${var.identifier}-glacier"

  tags = var.tags
}

resource "aws_glacier_vault" "main" {
  count = var.storage_class == "GLACIER" ? 1 : 0
  name  = "${var.identifier}-${random_string.suffix.result}"

  notification {
    sns_topic = aws_sns_topic.glacier[0].arn
    events    = ["ArchiveRetrievalCompleted", "InventoryRetrievalCompleted"]
  }

  tags = var.tags
}

################################
# S3 Bucket                    #
################################

resource "aws_s3_bucket" "main" {
  count         = var.storage_class == "DEFAULT" ? 1 : 0
  bucket        = "${var.identifier}-${random_string.suffix.result}"
  force_destroy = var.force_destroy

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "main" {
  count  = var.storage_class == "DEFAULT" ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  count  = var.storage_class == "DEFAULT" ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

################################
# SNS                          #
################################

data "aws_iam_policy_document" "topic" {
  count = length(var.queues) > 1 ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["SNS:Publish"]

    resources = ["arn:aws:sns:*:*:${var.identifier}-sqs-fanout"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main[0].arn]
    }
  }
}

resource "aws_sns_topic" "fanout" {
  count  = length(var.queues) > 1 ? 1 : 0
  name   = "${var.identifier}-sqs-fanout"
  policy = data.aws_iam_policy_document.topic[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "fanout" {
  count = length(var.queues) > 1 ? length(var.queues) : 0

  statement {
    effect = "Allow"

    # this can not be sns.amazonaws.com specific
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:${var.queues[count.index]["identifier"]}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.fanout[0].arn]
    }
  }
}

resource "aws_s3_bucket_notification" "topic" {
  count  = length(var.queues) > 1 ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  topic {
    topic_arn = aws_sns_topic.fanout[0].arn
    events    = ["s3:ObjectCreated:*"]
  }
}

################################
# SQS Queues                   #
################################

data "aws_iam_policy_document" "queue" {
  count = length(var.queues) == 1 ? 1 : 0

  statement {
    effect = "Allow"

    # this can not be sqs.amazonaws.com specific
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["sqs:SendMessage"]

    resources = ["arn:aws:sqs:*:*:${var.queues[0]["identifier"]}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main[0].arn]
    }
  }
}

# save indices of queues which have a related deadletter queue to later connect them
locals {
  deadletter_queues = [for i, v in var.queues : i if v["max_receive_count"] > 0]
}

resource "aws_sqs_queue" "deadletter" {
  count = length(local.deadletter_queues)
  name  = "${var.queues[local.deadletter_queues[count.index]]["identifier"]}-deadletter"

  tags = var.tags
}

locals {
  deadletter_output = [for i, v in var.queues : {
    arn         = try(aws_sqs_queue.deadletter[index(local.deadletter_queues, i)].arn, null)
    url         = try(aws_sqs_queue.deadletter[index(local.deadletter_queues, i)].url, null)
    queue_index = try(index(local.deadletter_queues, i), null)
  }]
}

resource "aws_sqs_queue" "main" {
  count                      = length(var.queues)
  name                       = var.queues[count.index]["identifier"]
  message_retention_seconds  = var.queues[count.index]["message_retention_seconds"]
  visibility_timeout_seconds = var.queues[count.index]["visibility_timeout_seconds"]
  policy = length(var.queues) > 1 ? (
  data.aws_iam_policy_document.fanout[count.index].json) : data.aws_iam_policy_document.queue[0].json

  redrive_policy = var.queues[count.index]["max_receive_count"] > 0 ? jsonencode({
    deadLetterTargetArn = local.deadletter_output[count.index]["arn"]
    maxReceiveCount     = var.queues[count.index]["max_receive_count"]
  }) : null

  tags = var.tags
}

resource "aws_sqs_queue_redrive_allow_policy" "main" {
  count     = length(local.deadletter_queues)
  queue_url = aws_sqs_queue.deadletter[count.index].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.main[local.deadletter_queues[count.index]].arn]
  })
}

resource "aws_s3_bucket_notification" "queue" {
  count  = length(var.queues) == 1 ? 1 : 0
  bucket = aws_s3_bucket.main[0].id

  queue {
    queue_arn = aws_sqs_queue.main[0].arn
    events    = ["s3:ObjectCreated:*"]
  }
}
