variable "identifier" {
  description = "Unique identifier to differentiate global resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "force_destroy" {
  description = "A flag for wether or not being able to destroy a non empty bucket."
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class of the S3 bucket. For example 'GLACIER' for a deep archive bucket."
  type        = string
  default     = "DEFAULT"
  validation {
    condition     = var.storage_class == "DEFAULT" || var.storage_class == "GLACIER"
    error_message = "Storage class must be either 'DEFAULT' or 'GLACIER'"
  }
}

variable "queues" {
  description = "A list of object to define SQS queues."
  type = list(object({
    identifier                 = string
    message_retention_seconds  = optional(number, 345600)
    visibility_timeout_seconds = optional(number, 300)
    max_receive_count          = optional(number, 0)
  }))
  default = []
  validation {
    condition     = !contains([for v in var.queues : length(v["identifier"]) > 2], false)
    error_message = "Identifier of queues must be at least 3 characters"
  }
  validation {
    condition     = length(toset([for v in var.queues : v["identifier"]])) == length(var.queues)
    error_message = "Identifier of queues must be unique"
  }
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
