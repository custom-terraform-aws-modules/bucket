################################
# S3 Bucket                    #
################################

resource "random_string" "suffix" {
  length  = 63 - length(var.identifier)
  special = false
  upper   = false
}

resource "aws_s3_bucket" "main" {
  bucket        = "${var.identifier}-${random_string.suffix.result}"
  force_destroy = var.force_destroy

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "deny" {
  statement {
    effect = "Deny"

    actions = ["s3:*"]

    resources = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.deny.json
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
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

resource "aws_sns_topic" "main" {
  count  = length(var.queues) > 1 ? 1 : 0
  name   = "${var.identifier}-sqs-fanout"
  policy = data.aws_iam_policy_document.topic[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "fanout" {
  count = length(var.queues) > 1 ? length(var.queues) : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:${try(var.queues[count.index]["identifier"], "")}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.main[0].arn]
    }
  }
}

resource "aws_s3_bucket_notification" "topic" {
  count  = length(var.queues) > 1 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  topic {
    topic_arn = aws_sns_topic.main[0].arn
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

    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }

    actions = ["sqs:SendMessage"]

    resources = ["arn:aws:sqs:*:*:${try(var.queues[0]["identifier"], "")}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

resource "aws_sqs_queue" "deadletter" {
  count = length(var.queues)
  name  = "${try(var.queues[count.index]["identifier"], "")}-deadletter"

  tags = var.tags
}

resource "aws_sqs_queue" "main" {
  count                      = length(var.queues)
  name                       = try(var.queues[count.index]["identifier"], "")
  message_retention_seconds  = try(var.queues["message_retention_seconds"], 345600)
  visibility_timeout_seconds = try(var.queues["visibility_timeout_seconds"], 300)
  policy                     = length(var.queues) > 1 ? data.aws_iam_policy_document.fanout[count.index].json : data.aws_iam_policy_document.queue[0].json

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[count.index].arn
    maxReceiveCount     = try(var.queues["max_receive_count"], 4)
  })

  tags = var.tags
}

resource "aws_sqs_queue_redrive_allow_policy" "main" {
  count     = length(var.queues)
  queue_url = aws_sqs_queue.deadletter[count.index].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.main[count.index].arn]
  })
}

resource "aws_s3_bucket_notification" "queue" {
  count  = length(var.queues) == 1 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  queue {
    queue_arn = aws_sqs_queue.main[0].arn
    events    = ["s3:ObjectCreated:*"]
  }
}
