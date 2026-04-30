output "karpenter_node_role_arn" {
  description = "ARN of the IAM role assumed by Karpenter-launched nodes"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_role_name" {
  description = "Name of the IAM role assumed by Karpenter-launched nodes"
  value       = aws_iam_role.karpenter_node.name
}

output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IRSA role"
  value       = aws_iam_role.karpenter_controller.arn
}

output "interruption_queue_url" {
  description = "URL of the SQS queue for Karpenter spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "interruption_queue_arn" {
  description = "ARN of the SQS queue for Karpenter spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}
