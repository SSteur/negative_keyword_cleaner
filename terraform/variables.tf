variable "project_id" {
  type = string
}

variable "location" {
  type    = string
  default = "europe-west1"
}

variable "mcc_id" {
  description = "Google Ads MCC account ID. Set it without hyphens XXXXXXXXXX"
}

variable "container_image" {
  description = "The full container image path to deploy to Cloud Run"
  type        = string
  default     = "gcr.io/vdc200007-search-prod/negative_keyword_cleaner:improved-llm-v1"
}

variable "run_service_account_email" {
  description = "Service account email for Cloud Run runtime"
  type        = string
}


