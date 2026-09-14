variable "account_id" {
  description = "New Relic account ID. Never commit the value to a secret-bearing file."
  type        = number
}

variable "api_key" {
  description = "New Relic User API key supplied through TF_VAR_api_key or the CI environment."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "New Relic region used by the account."
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment used by alert NRQL filters."
  type        = string
  default     = "prod"
}

variable "notification_enabled" {
  description = "Creates the notification destination/channel/workflow when true."
  type        = bool
  default     = false
}

variable "notification_destination_type" {
  description = "Configured destination type, for example WEBHOOK or EMAIL."
  type        = string
  default     = "WEBHOOK"
}

variable "notification_destination_url" {
  description = "Notification endpoint supplied only at apply time; never commit a real URL."
  type        = string
  sensitive   = true
  default     = ""
}

variable "synthetic_enabled" {
  description = "Creates the synthetic monitor when true. Disabled by default until a real URL is approved."
  type        = bool
  default     = false
}

variable "synthetic_uri" {
  description = "API Gateway URL for the synthetic smoke check."
  type        = string
  default     = "https://example.invalid/api/health"
}

variable "synthetic_locations" {
  description = "Public New Relic locations for the synthetic monitor."
  type        = list(string)
  default     = ["AWS_US_EAST_1"]
}
