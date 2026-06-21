# =============================================================================
# CloudWatch alarms + dashboard for the LiteLLM HA stack
# =============================================================================
# Covers ALB, ECS service, RDS/Aurora, and ElastiCache Redis. All alarms notify
# an SNS topic (optionally an email + any extra action ARNs you pass in).

# ----------------------------------------------------------------------------
# SNS topic + subscriptions
# ----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alarm_actions = concat([aws_sns_topic.alarms.arn], var.extra_alarm_action_arns)
  ok_actions    = concat([aws_sns_topic.alarms.arn], var.extra_alarm_action_arns)
}

# ----------------------------------------------------------------------------
# ALB alarms
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${var.name_prefix}-alb-target-5xx"
  alarm_description   = "LiteLLM target group returning 5xx responses."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.alb_target_5xx_count
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_elb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-elb-5xx"
  alarm_description   = "ALB itself returning 5xx (no healthy targets / capacity)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.alb_elb_5xx_count
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  alarm_description   = "One or more LiteLLM targets are unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_p95_latency" {
  alarm_name          = "${var.name_prefix}-alb-p95-latency"
  alarm_description   = "LiteLLM p95 target response time is high."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.alb_p95_latency_seconds
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

# ----------------------------------------------------------------------------
# ECS alarms
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  alarm_description   = "LiteLLM ECS service CPU utilization high."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.ecs_cpu_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  alarm_description   = "LiteLLM ECS service memory utilization high."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.ecs_memory_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  count               = var.ecs_container_insights_enabled ? 1 : 0
  alarm_name          = "${var.name_prefix}-ecs-running-tasks-low"
  alarm_description   = "LiteLLM running task count dropped below the HA minimum."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.ecs_min_running_tasks
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "breaching"
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

# ----------------------------------------------------------------------------
# RDS / Aurora alarms
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization high."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.rds_cpu_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.name_prefix}-rds-connections-high"
  alarm_description   = "RDS database connections approaching the limit."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.rds_connections
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  count               = var.rds_is_aurora ? 0 : 1 # Aurora storage auto-scales; no FreeStorageSpace metric
  alarm_name          = "${var.name_prefix}-rds-free-storage-low"
  alarm_description   = "RDS free storage space is low."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.thresholds.rds_free_storage_bytes
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_low" {
  alarm_name          = "${var.name_prefix}-rds-freeable-memory-low"
  alarm_description   = "RDS freeable memory is low."
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.thresholds.rds_freeable_memory_bytes
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  count               = var.rds_is_aurora ? 1 : 0
  alarm_name          = "${var.name_prefix}-rds-replica-lag"
  alarm_description   = "Aurora cluster max replica lag is high."
  namespace           = "AWS/RDS"
  metric_name         = "AuroraReplicaLagMaximum"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.rds_replica_lag_ms
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_acu_utilization_high" {
  count               = var.rds_is_serverless_v2 ? 1 : 0
  alarm_name          = "${var.name_prefix}-rds-acu-utilization-high"
  alarm_description   = "Aurora Serverless v2 is near its max ACU capacity (scaling ceiling)."
  namespace           = "AWS/RDS"
  metric_name         = "ACUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.rds_acu_utilization_pct
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

# ----------------------------------------------------------------------------
# ElastiCache Redis alarms (one set per node)
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  for_each            = toset(var.elasticache_cluster_ids)
  alarm_name          = "${var.name_prefix}-redis-cpu-high-${each.key}"
  alarm_description   = "ElastiCache node ${each.key} engine CPU high."
  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.redis_cpu_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    CacheClusterId = each.key
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  for_each            = toset(var.elasticache_cluster_ids)
  alarm_name          = "${var.name_prefix}-redis-memory-high-${each.key}"
  alarm_description   = "ElastiCache node ${each.key} memory usage high."
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.redis_memory_percent
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    CacheClusterId = each.key
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions_high" {
  for_each            = toset(var.elasticache_cluster_ids)
  alarm_name          = "${var.name_prefix}-redis-evictions-high-${each.key}"
  alarm_description   = "ElastiCache node ${each.key} is evicting keys (memory pressure)."
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.redis_evictions
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    CacheClusterId = each.key
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_replication_lag" {
  for_each            = toset(var.elasticache_cluster_ids)
  alarm_name          = "${var.name_prefix}-redis-replication-lag-${each.key}"
  alarm_description   = "ElastiCache node ${each.key} replication lag high."
  namespace           = "AWS/ElastiCache"
  metric_name         = "ReplicationLag"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.thresholds.redis_replication_lag_secs
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  treat_missing_data  = "notBreaching"
  dimensions = {
    CacheClusterId = each.key
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
  tags          = var.tags
}

# ----------------------------------------------------------------------------
# Dashboard
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "litellm" {
  dashboard_name = "${var.name_prefix}-ha"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# LiteLLM HA Dashboard\nALB / ECS / RDS / ElastiCache health for the LiteLLM proxy."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Request count & 5xx"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Latency (p50/p95/p99) & host health"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "p50", label = "p50" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average", yAxis = "right" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ECS - CPU / Memory / Running tasks"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average" }],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "RDS - CPU / Connections"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "Aurora - Serverless capacity (ACU) / Freeable memory"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/RDS", "ServerlessDatabaseCapacity", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", label = "Current ACU" }],
            ["AWS/RDS", "ACUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", label = "ACU Utilization %" }],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "ElastiCache - Engine CPU"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            for id in var.elasticache_cluster_ids :
            ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 12
        height = 6
        properties = {
          title  = "ElastiCache - Memory usage %"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            for id in var.elasticache_cluster_ids :
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 20
        width  = 12
        height = 6
        properties = {
          title  = "ElastiCache - Evictions / Replication lag"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = concat(
            [for id in var.elasticache_cluster_ids : ["AWS/ElastiCache", "Evictions", "CacheClusterId", id, { stat = "Sum" }]],
            [for id in var.elasticache_cluster_ids : ["AWS/ElastiCache", "ReplicationLag", "CacheClusterId", id, { stat = "Average", yAxis = "right" }]]
          )
        }
      }
    ]
  })
}
