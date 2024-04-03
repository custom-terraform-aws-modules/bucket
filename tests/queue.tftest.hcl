provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

run "invalid_identifier" {
  command = plan

  variables {
    identifier = "test"
    queues = [
      {
        identifier                 = "abc"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "ab"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      }
    ]
  }

  expect_failures = [var.queues]
}

run "duplicate_identifier" {
  command = plan

  variables {
    identifier = "test"
    queues = [
      {
        identifier                 = "abc"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "bar"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "abc"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "foo"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      }
    ]
  }

  expect_failures = [var.queues]
}

run "no_queue" {
  command = plan

  variables {
    identifier = "test"
    queues     = []
  }

  assert {
    condition     = length(data.aws_iam_policy_document.queue) == 0
    error_message = "S3 to SQS queue IAM policy was created unexpectedly"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == 0
    error_message = "SQS deadletter queue was created unexpectedly"
  }

  assert {
    condition     = length(aws_sqs_queue.main) == 0
    error_message = "SQS queue was created unexpectedly"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.queue) == 0
    error_message = "SQS bucket notification was created unexpectedly"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.topic) == 0
    error_message = "SNS bucket notification was created unexpectedly"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.fanout) == 0
    error_message = "SNS fanout IAM policy was created unexpectedly"
  }

  assert {
    condition     = length(aws_sns_topic.fanout) == 0
    error_message = "SNS topic was created unexpectedly"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.topic) == 0
    error_message = "S3 to SNS IAM policy was created unexpectedly"
  }
}

run "single_queue" {
  command = plan

  variables {
    identifier = "test-bucket"
    queues = [
      {
        identifier                 = "test-queue"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      }
    ]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.queue) == 1
    error_message = "S3 to SQS queue IAM policy was not created"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == 1
    error_message = "SQS deadletter queue was not created"
  }

  assert {
    condition     = length(aws_sqs_queue.main) == 1
    error_message = "SQS queue was not created"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.queue) == 1
    error_message = "SQS bucket notification was not created"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.topic) == 0
    error_message = "SNS bucket notification was created unexpectedly"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.fanout) == 0
    error_message = "SNS fanout IAM policy was created unexpectedly"
  }

  assert {
    condition     = length(aws_sns_topic.fanout) == 0
    error_message = "SNS topic was created unexpectedly"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.topic) == 0
    error_message = "S3 to SNS IAM policy was created unexpectedly"
  }
}

run "multiple_queues" {
  command = plan

  variables {
    identifier = "test-bucket"
    queues = [
      {
        identifier                 = "test-queue-one"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "test-queue-two"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "test-queue-three"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      }
    ]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.queue) == 0
    error_message = "S3 to SQS queue IAM policy was created unexpectedly"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == length(var.queues)
    error_message = "SQS deadletter queues were not created"
  }

  assert {
    condition     = length(aws_sqs_queue.main) == length(var.queues)
    error_message = "SQS queues were not created"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.queue) == 0
    error_message = "SQS bucket notification was created unexpectedly"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.topic) == 1
    error_message = "SNS bucket notification was not created"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.fanout) == length(var.queues)
    error_message = "SNS fanout IAM policies were not created"
  }

  assert {
    condition     = length(aws_sns_topic.fanout) == 1
    error_message = "SNS topic was not created"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.topic) == 1
    error_message = "S3 to SNS IAM policy was not created"
  }
}

run "queue_without_deadletter" {
  command = plan

  variables {
    identifier = "test-bucket"
    queues = [
      {
        identifier                 = "test-queue-one"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      }
    ]
  }

  assert {
    condition     = length(aws_sqs_queue.main) == 1
    error_message = "Main SQS queue was not created"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == 0
    error_message = "Deadletter SQS queue was created unexpectedly"
  }

  assert {
    condition     = length(local.deadletter_queues) == 0
    error_message = "Deadletter index list has an unexpected length"
  }

  assert {
    condition     = length(local.deadletter_output) == 1
    error_message = "Deadletter output list has an unexpected length"
  }

  assert {
    condition = local.deadletter_output[0]["arn"] == null && (
    local.deadletter_output[0]["url"] == null)
    error_message = "Deadletter output at index '0' is not null"
  }
}

run "multiple_queues_single_deadletter" {
  command = plan

  variables {
    identifier = "test-bucket"
    queues = [
      {
        identifier                 = "test-queue-one"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      },
      {
        identifier                 = "test-queue-two"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      },
      {
        identifier                 = "test-queue-three"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "test-queue-four"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      }
    ]
  }

  assert {
    condition     = length(aws_sqs_queue.main) == length(var.queues)
    error_message = "SQS queues were not created"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == 1
    error_message = "Unexpected amount of deadletter SQS queues were created"
  }

  assert {
    condition     = length(local.deadletter_queues) == 1
    error_message = "Deadletter index list has an unexpected length"
  }

  assert {
    condition     = length(local.deadletter_output) == length(var.queues)
    error_message = "Deadletter output list has an unexpected length"
  }

  assert {
    condition     = [for i, v in local.deadletter_output : v["queue_index"]] == [null, null, 0, null]
    error_message = "Unexpected deadletter output"
  }
}

run "multiple_queues_multiple_deadletter" {
  command = plan

  variables {
    identifier = "test-bucket"
    queues = [
      {
        identifier                 = "test-queue-one"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      },
      {
        identifier                 = "test-queue-two"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      },
      {
        identifier                 = "test-queue-three"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "test-queue-four"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      },
      {
        identifier                 = "test-queue-five"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 0
      },
      {
        identifier                 = "test-queue-six"
        message_retention_seconds  = 345600
        visibility_timeout_seconds = 300
        max_receive_count          = 4
      }
    ]
  }

  assert {
    condition     = length(aws_sqs_queue.main) == length(var.queues)
    error_message = "SQS queues were not created"
  }

  assert {
    condition     = length(aws_sqs_queue.deadletter) == 3
    error_message = "Unexpected amount of deadletter SQS queues were created"
  }

  assert {
    condition     = length(local.deadletter_queues) == 3
    error_message = "Deadletter index list has an unexpected length"
  }

  assert {
    condition     = length(local.deadletter_output) == length(var.queues)
    error_message = "Deadletter output list has an unexpected length"
  }

  assert {
    condition     = [for i, v in local.deadletter_output : v["queue_index"]] == [null, null, 0, 1, null, 2]
    error_message = "Unexpected deadletter output"
  }
}
