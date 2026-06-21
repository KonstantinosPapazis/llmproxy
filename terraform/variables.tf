# =============================================================================
# Variables for LiteLLM CloudWatch alarms + dashboard
# =============================================================================
# These reference the resources you already manage in Terraform (RDS,
# ElastiCache, ECS service, ALB). Pass the identifiers/suffixes as inputs.

variable "aws_region" {
  description = "AWS region for the dashboard and alarms."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming alarms, SNS topic, and the dashboard."
  type        = string
  default     = "litellm"
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Notification target
# ----------------------------------------------------------------------------
variable "alarm_email" {
  description = "Optional email to subscribe to the alarms SNS topic. Leave empty to skip."
  type        = string
  default     = ""
}

variable "extra_alarm_action_arns" {
  description = "Additional SNS/Chatbot/Lambda ARNs to notify (e.g. existing Slack Chatbot topic)."
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------
# ALB identifiers (from your existing Terraform)
# ----------------------------------------------------------------------------
variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB, e.g. app/my-alb/50dc6c495c0c9188 (aws_lb.x.arn_suffix)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the LiteLLM target group (aws_lb_target_group.x.arn_suffix)."
  type        = string
}

# ----------------------------------------------------------------------------
# ECS identifiers
# ----------------------------------------------------------------------------
variable "ecs_cluster_name" {
  description = "ECS cluster name running the LiteLLM service."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for the LiteLLM proxy."
  type        = string
}

variable "ecs_min_running_tasks" {
  description = "Alarm if RunningTaskCount drops below this (requires Container Insights)."
  type        = number
  default     = 2
}

variable "ecs_container_insights_enabled" {
  description = "Set true if ECS Container Insights is enabled (needed for RunningTaskCount alarm)."
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# RDS / Aurora identifiers
# ----------------------------------------------------------------------------
variable "rds_instance_id" {
  description = "Aurora writer DB instance identifier (DBInstanceIdentifier) for per-instance metrics."
  type        = string
}

variable "rds_cluster_id" {
  description = "Aurora DB cluster identifier (DBClusterIdentifier) for cluster-level metrics (replica lag)."
  type        = string
}

variable "rds_is_aurora" {
  description = "True for Aurora: skips the FreeStorageSpace alarm (Aurora storage auto-scales) and enables replica-lag alarm."
  type        = bool
  default     = true
}

variable "rds_is_serverless_v2" {
  description = "True for Aurora Serverless v2: enables ACUUtilization alarm and serverless-capacity dashboard widgets."
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# ElastiCache identifiers
# ----------------------------------------------------------------------------
variable "elasticache_cluster_ids" {
  description = "List of ElastiCache node (cache cluster) ids, e.g. [\"litellm-redis-001\", \"litellm-redis-002\"]."
  type        = list(string)
}

# ----------------------------------------------------------------------------
# Thresholds (sane defaults; tune after load testing)
# ----------------------------------------------------------------------------
variable "thresholds" {
  description = "Alarm thresholds."
  type = object({
    alb_target_5xx_count       = number
    alb_elb_5xx_count          = number
    alb_p95_latency_seconds    = number
    ecs_cpu_percent            = number
    ecs_memory_percent         = number
    rds_cpu_percent            = number
    rds_connections            = number
    rds_free_storage_bytes     = number
    rds_freeable_memory_bytes  = number
    rds_replica_lag_ms         = number
    rds_acu_utilization_pct    = number
    redis_cpu_percent          = number
    redis_memory_percent       = number
    redis_evictions            = number
    redis_replication_lag_secs = number
  })
  default = {
    alb_target_5xx_count       = 25
    alb_elb_5xx_count          = 10
    alb_p95_latency_seconds    = 10
    ecs_cpu_percent            = 80
    ecs_memory_percent         = 85
    rds_cpu_percent            = 80
    rds_connections            = 80
    rds_free_storage_bytes     = 5368709120 # 5 GiB (only used when rds_is_aurora = false)
    rds_freeable_memory_bytes  = 536870912  # 512 MiB
    rds_replica_lag_ms         = 1000
    rds_acu_utilization_pct    = 90
    redis_cpu_percent          = 75
    redis_memory_percent       = 80
    redis_evictions            = 100
    redis_replication_lag_secs = 5
  }
}

variable "alarm_period_seconds" {
  description = "Metric period for alarms."
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Number of periods that must breach before alarming."
  type        = number
  default     = 3
}
