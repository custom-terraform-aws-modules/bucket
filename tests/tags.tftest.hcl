provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

run "invalid_tags" {
  command = plan

  variables {
    identifier = "test"

    tags = {
      Name = "Foo"
    }
  }

  expect_failures = [var.tags]
}

run "valid_tags" {
  command = plan

  variables {
    identifier = "test"

    tags = {
      Project = "Foo"
    }
  }
}
