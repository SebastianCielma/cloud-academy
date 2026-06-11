resource "google_monitoring_notification_channel" "email_alert" {
  display_name = "${var.prefix}-devops-email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "armor_blocks" {
  display_name = "${var.prefix}-high-armor-blocks"
  combiner     = "OR"
  conditions {
    display_name = "Cloud Armor Deny > 10 in 1 min"
    condition_threshold {
      filter          = "metric.type=\"networksecurity.googleapis.com/edge_security_policy/request_count\" resource.type=\"edge_security_policy\" metric.labels.outcome=\"DENY\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10
    }
  }
  notification_channels = [google_monitoring_notification_channel.email_alert.name]
}

resource "google_monitoring_alert_policy" "server_errors" {
  display_name = "${var.prefix}-high-5xx-errors"
  combiner     = "OR"
  conditions {
    display_name = "5xx Errors > 5 in 1 min"
    condition_threshold {
      filter          = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" metric.labels.response_code_class=\"500\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
    }
  }
  notification_channels = [google_monitoring_notification_channel.email_alert.name]
}

resource "google_monitoring_dashboard" "lb_dashboard" {
  dashboard_json = <<EOF
{
  "displayName": "${var.prefix}-Security-and-Traffic-Dashboard",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "Total HTTP/HTTPS Requests",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\""
              }
            }
          }]
        }
      },
      {
        "title": "Cloud Armor Blocked Requests (403)",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"networksecurity.googleapis.com/edge_security_policy/request_count\" resource.type=\"edge_security_policy\" metric.labels.outcome=\"DENY\""
              }
            }
          }]
        }
      }
    ]
  }
}
EOF
}