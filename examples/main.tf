### Data Lookup Resources ###
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_default_tags" "default_tags" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "selected" {
  state = "available"
  filter {
    name   = "region-name"
    values = ["us-east-1"]
  }

}

data "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.selected.zone_ids
  filter {
    name   = "tag:Subnet"
    values = ["Private"]
  }
}

data "aws_route53_zone" "selected" {
  name         = "caseyreed.com"
  private_zone = true
}

data "aws_ami" "caseyreed_cis_ubuntu" {
  most_recent      = true
  name_regex       = "^caseyreed-cis-ubuntu-2004-.*"
  owners           = ["1234567890"]
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
    service_name = "nginx-proxy"
    code_repo_link ="github.com/CPCJ79/terraform-app"
    operational_schedule = "officehours, noweekends"
    managed_by = "casey.reed@caseyreed.com"
  }
  namespace = "ie"
  stage = "prod"
  name  = "nginx-proxy"
  attributes = ["internal"]
  delimiter = "-"
}

### Resources ###
###
### Modules ###
module "docker_app" {
  source = "../../modules/null-label"

  namespace  = local.namespace
  stage      = local.stage
  name       = local.tags.service_name
  attributes = local.attributes
  delimiter  = local.delimiter
  tags = local.tags
}

module "sg0" {
  source = "../../modules/aws_sg"
  attributes = [module.docker_app.attributes]

  # Allow unlimited egress
  allow_all_egress = true

  rules = [
    {
      key         = "HTTPS"
      type        = "ingress"
      from_port   = 8443
      to_port     = 8443
      protocol    = "tcp"
      cidr_blocks = [data.aws_subnet.private.cidr_block]
      self        = null
      description = "Allow HTTPS"
    }
  ]

  vpc_id  = data.aws_vpc.default.id

  context = module.docker_app.context
}

module "alb" {
  source = "../../modules/aws_alb"

  context = module.docker_app.context

  vpc_id                                  = data.aws_vpc.default.id
  security_group_ids                      = [module.sg0.id]
  subnet_ids                              = data.aws_subnet.private.id
  target_group_protocol                   = "HTTPS"
  target_group_target_type                = "instance"

}

module "aws_asg" {
  source = "../../modules/aws_asg"

  context = module.docker_app.context

  image_id                    = data.aws_ami.caseyreed_cis_ubuntu.id
  instance_type               = "t3.medium"
  security_group_ids          = [module.sg0.id]
  subnet_ids                  = [data.aws_subnet.private.id]
  health_check_type           = "ELB"
  min_size                    = 1
  max_size                    = 1
  wait_for_capacity_timeout   = "5m"
  associate_public_ip_address = false
  target_group_arns           = [module.alb[0].default_target_group_arn]
  user_data_base64            = local.userdata
  iam_instance_profile_name = join("-", [local.tags.service_name, "prof"])


}
