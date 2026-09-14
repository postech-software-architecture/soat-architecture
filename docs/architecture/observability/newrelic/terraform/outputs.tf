output "dashboard_ids" {
  description = "IDs of the six versioned W5 dashboards."
  value       = { for key, dashboard in newrelic_one_dashboard_json.w5 : key => dashboard.id }
  sensitive   = false
}

output "alert_policy_id" {
  description = "W5 alert policy ID."
  value       = newrelic_alert_policy.w5.id
}

output "synthetic_monitor_id" {
  description = "Synthetic monitor ID when enabled; null otherwise."
  value       = var.synthetic_enabled ? newrelic_synthetics_monitor.w5[0].id : null
}
