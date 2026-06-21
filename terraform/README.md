# LiteLLM CloudWatch alarms + dashboard (Terraform)

Observability for the LiteLLM HA stack: CloudWatch alarms and a consolidated
dashboard for the ALB, ECS service, RDS/Aurora, and ElastiCache Redis, plus an
SNS topic for notifications.

This is intentionally **provider-agnostic about resource creation** - it only
references your existing RDS, ElastiCache, ECS, and ALB resources by identifier,
so it can be dropped into your existing Terraform project (which already declares
the `aws` provider) or used as a standalone module.

## What it creates

- `aws_sns_topic.alarms` (+ optional email subscription) for notifications.
- ALB alarms: target 5xx, ELB 5xx, unhealthy hosts, p95 latency.
- ECS alarms: CPU, memory, running task count (Container Insights).
- RDS alarms: CPU, connections, free storage, freeable memory, replica lag (Aurora).
- ElastiCache alarms (per node): engine CPU, memory %, evictions, replication lag.
- `aws_cloudwatch_dashboard.litellm-ha` tying all layers together.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in identifiers
   from your existing Terraform outputs (ARN suffixes, names, ids).
2. If using as part of your existing stack, you can wire identifiers directly
   instead of variables, e.g.:

   ```hcl
   alb_arn_suffix          = aws_lb.litellm.arn_suffix
   target_group_arn_suffix = aws_lb_target_group.litellm.arn_suffix
   ecs_cluster_name        = aws_ecs_cluster.main.name
   ecs_service_name        = aws_ecs_service.litellm.name
   rds_instance_id         = aws_rds_cluster_instance.writer.identifier
   rds_cluster_id          = aws_rds_cluster.litellm.cluster_identifier
   elasticache_cluster_ids = aws_elasticache_replication_group.litellm.member_clusters
   ```

3. `terraform init && terraform plan && terraform apply`.
4. Subscribe the SNS topic (`alarms_sns_topic_arn` output) to Slack via AWS
   Chatbot or to PagerDuty, or pass an existing topic via `extra_alarm_action_arns`.

## Notes

- The `RunningTaskCount` alarm requires **ECS Container Insights** to be enabled
  on the cluster. Set `ecs_container_insights_enabled = false` to skip it.
- **Aurora PostgreSQL Serverless v2** (`rds_is_aurora = true`, `rds_is_serverless_v2 = true`):
  the `FreeStorageSpace` alarm is skipped (storage auto-scales), a cluster-level
  `AuroraReplicaLagMaximum` alarm is created (uses `rds_cluster_id`), and an
  `ACUUtilization` alarm warns when you approach the max ACU ceiling.
- Set `rds_instance_id` to the **writer instance** id for per-instance metrics
  (CPU, connections, freeable memory, ACU) and `rds_cluster_id` to the cluster id.
- ElastiCache alarms are created per node id in `elasticache_cluster_ids` (use the
  replication group's `member_clusters`).
- Tune `thresholds` after load testing; defaults are conservative starting points.
