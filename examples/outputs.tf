output "alb" {
  value = module.alb
}

output "asg_name" {
  value = aws_autoscaling_group.instance_asg.name
}


