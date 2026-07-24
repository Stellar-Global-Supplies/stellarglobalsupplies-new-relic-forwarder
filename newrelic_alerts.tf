##############################################################################
# Provider & Terraform settings
##############################################################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "newrelic" {
  account_id = 8314321
  api_key    = var.newrelic_api_key
  region     = "EU"
}
##############################################################################
# Variables
##############################################################################
variable "newrelic_api_key" {
  description = "New Relic User API key (User key, starts with NRAK-)"
  type        = string
  sensitive   = true
}
##############################################################################
# New Relic — NRQL Alert Conditions
# Account : 8314321
# Policy  : 1719552
##############################################################################

# ── 1. API Gateway completely down ───────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "api_gateway_completely_down" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "API Gateway completely down"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT sum(`aws.apigateway.Count.Sum`)
      FROM Metric
      WHERE `aws.apigateway.Count.Sum` IS NOT NULL
    EOT
    )
  }

  critical {
    operator              = "below_or_equals"
    threshold             = 0
    threshold_duration    = 600
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 600
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# ── 2. Lambda 100% error rate ─────────────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "lambda_100_percent_error_rate" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Lambda 100% error rate"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT sum(`aws.lambda.Errors.Sum`)
        / sum(`aws.lambda.Invocations.Sum`) * 100
      FROM Metric
    EOT
    )
  }

  critical {
    operator              = "above_or_equals"
    threshold             = 100
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 300
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# ── 3. Web traffic completely stopped ────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "web_traffic_completely_stopped" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Web traffic completely stopped"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT latest(`aws.webtraffic.summary.total_requests`)
      FROM Metric
      WHERE source = 'cloudfront-logs'
    EOT
    )
  }

  critical {
    operator              = "below_or_equals"
    threshold             = 0
    threshold_duration    = 1800
    threshold_occurrences = "all"
  }

  fill_option                = "last_value"
  aggregation_window         = 1800
  aggregation_method         = "cadence"
  aggregation_delay          = 120
}

# ── 4. Supabase collector stopped ─────────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "supabase_collector_stopped" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Supabase collector stopped"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT count(*)
      FROM Log
      WHERE `service.name` = 'supabase-monitor'
      AND logtype = 'supabase_monitor_run'
    EOT
    )
  }

  critical {
    operator              = "below_or_equals"
    threshold             = 0
    threshold_duration    = 10800
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 3600
  aggregation_method = "cadence"
  aggregation_delay  = 120
}

# ── 5. Cost data pipeline broken ──────────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "cost_data_pipeline_broken" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Cost data pipeline broken"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT count(*)
      FROM Metric
      WHERE source = 'cur'
      AND file = 'daily-costs'
    EOT
    )
  }

  critical {
    operator              = "below_or_equals"
    threshold             = 0
    threshold_duration    = 259200
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 86400
  aggregation_method = "cadence"
  aggregation_delay  = 120
}

# ── 6. Monthly spend exceeded $1.50 ──────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "monthly_spend_exceeded_1_50" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Monthly AWS spend exceeded $1.50"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT latest(`aws.cur.v2.summary.monthly_total`)
      FROM Metric
      WHERE source = 'cur'
      AND file = 'summary'
    EOT
    )
  }

  critical {
    operator              = "above"
    threshold             = 1.5
    threshold_duration    = 86400
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 86400
  aggregation_method = "cadence"
  aggregation_delay  = 120
}

# ── 7. Monthly spend exceeded $1.00 ──────────────────────────────────────────
resource "newrelic_nrql_alert_condition" "monthly_spend_exceeded_1_00" {
  account_id                   = 8314321
  policy_id                    = 1719552
  type                         = "static"
  name                         = "Monthly AWS spend exceeded $1.00"
  enabled                      = true
  violation_time_limit_seconds = 259200

  nrql {
    query = trimspace(<<-EOT
      SELECT latest(`aws.cur.v2.summary.monthly_total`)
      FROM Metric
      WHERE source = 'cur'
      AND file = 'summary'
    EOT
    )
  }

  critical {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 86400
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 86400
  aggregation_method = "cadence"
  aggregation_delay  = 120
}
