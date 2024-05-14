### Data Lookup Resources ###
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_default_tags" "default_tags" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "base_ubuntu" {
  most_recent      = true
  name_regex       = "^ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-.*"
  owners           = ["099720109477"]
}

### Local Variables ###
locals {
  enabled = module.this.enabled
  userdata = filebase64("${path.module}/user_data.sh")

  tags = {
    cost_center_number = "0100"
    owner_team     = "security"
    owner_team_coms = "security@caseyreed.com"
    confidentiality = "Confidential"
    environment = "prd"
    service_name = "docker-app"
    code_repo_link ="github.com/CPCJ79/tf-app-aws"
    managed_by = "casey.reed@caseyreed.com"
  }
  namespace = "ie"
  stage = "dev"
  name  = "docker-app"
  attributes = ["internal"]
  delimiter = "-"
}

### Resources ###
###
### Modules ###
module "lables" {
  source = "../../modules/null-label"

  namespace  = local.namespace
  stage      = local.stage
  name       = local.tags.service_name
  attributes = local.attributes
  delimiter  = local.delimiter
  tags = local.tags
}

data "aws_iam_policy_document" "instance_iam_policy" {
  statement {
    sid = "SSMPolicy"

    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/app/${local.tags.service_name}/*",
    ]
  }

  statement {
    sid = "SSMManager"

    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_instance_profile" "docker-app" {
  name = "docker-app-inst-prof"
  role = module.asg_role.name
}

module "asg_role" {
  source = "../../modules/aws_iam_role"

  context = module.lables.context
  role_description = "tf managed asg role"
  policy_description = "tf managed policy permitting ssm and ssh"
  assume_role_actions = [
    "sts:AssumeRole",
  ]
  principals = {
    "Service" : ["ec2.amazonaws.com"],
  }

  policy_documents = [
    data.aws_iam_policy_document.instance_iam_policy.json,
  ]
}

module "sg0" {
  source = "../../modules/aws_sg"

  # Allow unlimited egress
  allow_all_egress = true

  rules = [
    {
      key         = "HTTPS"
      type        = "ingress"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["172.31.16.0/20"]
      self        = null
      description = "Allow HTTPS"
    }
  ]

  vpc_id  = data.aws_vpc.default.id

  context = module.lables.context
}

module "alb" {
  source = "../../modules/aws_alb"

  context = module.lables.context

  access_logs_enabled                     = false
  vpc_id                                  = data.aws_vpc.default.id
  security_group_ids                      = [module.sg0.id]
  subnet_ids                              = ["subnet-0ab600d5ef797038a", "subnet-09c78817d0d8cb4a7"]
  target_group_protocol                   = "HTTPS"
  target_group_target_type                = "instance"
  http_enabled                            = true
  http_redirect                           = false
  https_enabled                           = false
  #certificate_arn                        = ""
  http_port                               = 8080
  target_group_port                       = 8080


}

module "aws_asg" {
  source = "../../modules/aws_asg"

  context = module.lables.context

  image_id                    = data.aws_ami.base_ubuntu.id
  instance_type               = "t3.medium"
  security_group_ids          = [module.sg0.id]
  subnet_ids                  = ["subnet-0ab600d5ef797038a", "subnet-09c78817d0d8cb4a7"]
  health_check_type           = "ELB"
  min_size                    = 1
  max_size                    = 1
  wait_for_capacity_timeout   = "5m"
  associate_public_ip_address = false
  target_group_arns           = [module.alb.default_target_group_arn]
  user_data_base64            = local.userdata
  iam_instance_profile_name   = aws_iam_instance_profile.docker-app.name

}
