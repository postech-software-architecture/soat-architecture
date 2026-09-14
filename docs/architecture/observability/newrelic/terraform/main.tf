locals {
  dashboard_templates = sort(fileset(path.module, "../dashboards/*.json.tftpl"))
  dashboard_count     = length(local.dashboard_templates)
  processing_query    = "FROM Metric SELECT sum(workshop.ordem_servico.processing.error.count) WHERE environment = '${var.environment}'"
}

resource "newrelic_one_dashboard_json" "w5" {
  for_each = toset(local.dashboard_templates)

  json = templatefile("${path.module}/${each.value}", {
    account_id = var.account_id
  })
}

resource "newrelic_alert_policy" "w5" {
  name                = "W5 - Workshop Operational Observability"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "processing_failures" {
  policy_id                    = newrelic_alert_policy.w5.id
  name                         = "W5 - three processing failures in five minutes"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 86400

  nrql {
    query             = local.processing_query
    evaluation_offset = 0
  }

  critical {
    operator              = "above_or_equals"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  # NRQL conditions automatically recover when the signal is below the
  # threshold for the next evaluation window; no manual close is required.
}

resource "newrelic_notification_destination" "w5" {
  count = var.notification_enabled ? 1 : 0

  name = "W5 configurable notification destination"
  type = var.notification_destination_type

  property {
    key           = "url"
    value         = var.notification_destination_url
    display_value = "configured-at-apply-time"
  }
}

resource "newrelic_notification_channel" "w5" {
  count = var.notification_enabled ? 1 : 0

  name           = "W5 operational alerts"
  type           = var.notification_destination_type
  destination_id = newrelic_notification_destination.w5[0].id
  product        = "IINT"

  property {
    key           = "payload"
    value         = "{\"id\":\"{{issue.id}}\",\"title\":\"{{issue.title}}\"}"
    display_value = "sanitized issue payload"
  }
}

resource "newrelic_workflow" "w5" {
  count = var.notification_enabled ? 1 : 0

  name                  = "W5 operational workflow"
  muting_rules_handling = "DONT_NOTIFY_FULLY_MUTED_ISSUES"

  issues_filter {
    name = "W5 processing failure condition"
    type = "FILTER"

    predicate {
      attribute = "accumulations.conditionName"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_nrql_alert_condition.processing_failures.name]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.w5[0].id
  }
}

resource "newrelic_synthetics_monitor" "w5" {
  count = var.synthetic_enabled ? 1 : 0

  name             = "W5 API Gateway smoke"
  type             = "SIMPLE"
  status           = "DISABLED"
  uri              = var.synthetic_uri
  locations_public = var.synthetic_locations
  period           = "EVERY_10_MINUTES"
}

check "exactly_six_dashboards" {
  assert {
    condition     = local.dashboard_count == 6
    error_message = "W5 must provision exactly six dashboards; found ${local.dashboard_count}."
  }
}

check "notification_requires_endpoint" {
  assert {
    condition     = !var.notification_enabled || length(trimspace(var.notification_destination_url)) > 0
    error_message = "notification_destination_url is required when notification_enabled=true."
  }
}
