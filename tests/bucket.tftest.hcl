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
    identifier = "ab"
  }

  expect_failures = [var.identifier]
}

run "valid_identifier" {
  command = plan

  variables {
    identifier = "abc"
  }
}

run "invalid_storage_class" {
  command = plan

  variables {
    identifier    = "abc"
    storage_class = "TEST"
  }

  expect_failures = [var.storage_class]
}

run "default_bucket" {
  command = plan

  variables {
    identifier    = "abc"
    storage_class = "DEFAULT"
  }

  assert {
    condition     = length(aws_s3_bucket.main) == 1
    error_message = "S3 bucket was not created"
  }

  assert {
    condition     = length(aws_s3_bucket_ownership_controls.main) == 1
    error_message = "S3 bucket ownership controlas were not created"
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.main) == 1
    error_message = "S3 bucket public access block was not created"
  }

  assert {
    condition     = length(aws_glacier_vault.main) == 0
    error_message = "Glacier vault was created unexpectedly"
  }

  assert {
    condition     = length(aws_sns_topic.glacier) == 0
    error_message = "SNS topic of glacier vault was created unexpectedly"
  }
}

run "glacier_bucket" {
  command = plan

  variables {
    identifier    = "abc"
    storage_class = "GLACIER"
  }

  assert {
    condition     = length(aws_s3_bucket.main) == 0
    error_message = "S3 bucket was created unexpectedly"
  }

  assert {
    condition     = length(aws_s3_bucket_ownership_controls.main) == 0
    error_message = "S3 bucket ownership controlas were created unexpectedly"
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.main) == 0
    error_message = "S3 bucket public access block was not created unexpectedly"
  }

  assert {
    condition     = length(aws_glacier_vault.main) == 1
    error_message = "Glacier vault was not created"
  }

  assert {
    condition     = length(aws_sns_topic.glacier) == 1
    error_message = "SNS topic of glacier vault was not created"
  }
}
