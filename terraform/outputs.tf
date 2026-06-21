output "alarms_sns_topic_arn" {
  description = "SNS topic that receives all LiteLLM alarm notifications. Wire this into Slack (AWS Chatbot) or PagerDuty."
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.litellm.dashboard_name
}

output "dashboard_url" {
  description = "Direct link to the CloudWatch dashboard."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.litellm.dashboard_name}"
}
