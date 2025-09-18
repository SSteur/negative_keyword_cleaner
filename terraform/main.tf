resource "null_resource" "enable_cloud_apis" {
  provisioner "local-exec" {
    command = "gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com iam.googleapis.com --project ${var.project_id}"
  }
}

##
# Custom Service Account
#

resource "google_service_account" "main" {
  account_id   = "neg-keywords-cleaner-test"
  display_name = "Negative Keywords Cleaner Service Account"

  depends_on = [null_resource.enable_cloud_apis]
}

##
# Cloud Storage
#
resource "random_id" "bucket_main_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new Project ID
    ami_id = var.project_id
  }
  byte_length = 8
}

resource "google_storage_bucket" "main" {
  name                        = "neg-kws-cleaner-test-${random_id.bucket_main_suffix.hex}"
  location                    = var.location
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  depends_on                  = [null_resource.enable_cloud_apis]
}
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.run_service_account_email}"
}

##
# Vertex AI
#

resource "google_project_service" "aiplatform" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_cloud_apis]
}

resource "google_project_service" "generativeai" {
  service            = "generativelanguage.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_cloud_apis]
}

resource "google_project_service" "apikeys" {
  service            = "apikeys.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_cloud_apis]
}

resource "random_id" "vertexai_apikey_suffix" {
  byte_length = 8
}
##
# Google Ads
#

resource "google_project_service" "googleads" {
  service            = "googleads.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_cloud_apis]
}

##
# Cloud Run Deployment
#

resource "google_project_service" "cloud_run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_cloud_apis]
}

resource "google_cloud_run_v2_service" "default" {
  name     = "neg-kws-cleaner"
  location = var.location
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.container_image


      env {
        name  = "port"
        value = "8080"
      }

      env {
        name  = "DEFAULT_BUCKET_NAME"
        value = google_storage_bucket.main.name
      }

      env {
        name  = "MCC_ID"
        value = var.mcc_id
      }

      env {
        name = "OAUTH_WEB_JSON"
        value_source {
          secret_key_ref {
            secret  = "nk-cleaner-test-oauth-web-json"
            version = "latest"
          }
        }
      }

      # Google Ads API token
      env {
        name = "GOOGLE_ADS_API_TOKEN"
        value_source {
          secret_key_ref {
            secret  = "nk-cleaner-test-google-ads-api-token"
            version = "latest"
          }
        }
      }

      # Gemini key
      env {
        name = "GOOGLE_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "nk-cleaner-test-gemini-key"
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "8Gi"
        }
      }
    }
    timeout          = "1800s"
    service_account  = var.run_service_account_email
    session_affinity = true
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "policy" {
  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "null_resource" "env_var_update" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "gcloud run services update ${google_cloud_run_v2_service.default.name} --update-env-vars=OAUTH_REDIRECT_URI=${google_cloud_run_v2_service.default.uri} --region=${google_cloud_run_v2_service.default.location} --platform=managed"
  }

  depends_on = [google_cloud_run_v2_service.default]
}
