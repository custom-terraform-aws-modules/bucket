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

variable "queues" {
  description = "A list of object to define SQS queues."
  type = list(object({
    identifier                 = string
    message_retention_seconds  = number
    visibility_timeout_seconds = number
    max_receive_count          = number
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
