# terraform-app

Templates for the automation and deployment of application infrastructure within AWS managed by Terraform modules.

## Structure
```
    examples/
        standalone-app
        docker-app

    modules/
        aws_asg
        aws_rds
        aws_alb
        aws_ec2
        ....
```

## Additional features


#### Persistent Storage
enable_efs = true

#### Custom script to run on startup
user_data = file("${path.module}/user_data.sh")

#### RDS Database
postgres v 13 is supported for now, can easily add additional database engines later as needed

db_instance = "postgres"

db_name     = "db_name"


#### ASG Min/Max Instance count

min_instance = 1

max_instance = 1

#### Custom Health Check

health_path     = "/helpdesk"

health_response = "302"

#### Disable health check

health_enabled = false


## Dealing with secrets 

### Secret I already have 
Example: There is a specific key, or license, or password needed by the application that already exists. It needs to be passed into the application securely.

When deploying the url-shortener there was a Geolite License Key that needed to be passed into the docker container securely for the ttam-techops-prd account. There was a known license key to be used with the application. 

After logging into the tech-ops-prd aws navigate to  `AWS Systems Manager` > `Parameter Store` > `Create Parameter` 
```
Name:              /app/url-shorty/db_license
Description:       optional
Tier:              Standard
Type:              Secure String
Data Type:         Text
Value:             Insert License Key Here
```
Make sure the name matches the format `/app/your_app_name/variable_name`


In order for docker to have access to the geo-lite license key that was stored in parameter store it can set as a variable in the `user_data.sh` file:

`DB_LICENSE=$(aws ssm get-parameter --name /app/url-shorty/db_license --with-decryption | jq -r .Parameter.Value)`

The variable can be passed into the docker run command as follows:
```
docker run \
    --name my_shlink \
    -p 8080:8080 \
    -e GEOLITE_LICENSE_KEY=$DB_LICENSE \
```


### Secret consumed and created by the application 
Example: For a key, password, or username managed by AWS. Terraform has built in functions to provision and store these.

When deploying the url-shortener it required a database username and password. These are two secrets that only the application needed access to. In the `user_data.sh` the ssm parameter store was used to pull the information needed for the database. 

`DB_USERNAME=$(aws ssm get-parameter --name /app/url-shorty/db_username --with-decryption | jq -r .Parameter.Value)`
`DB_PASSWORD=$(aws ssm get-parameter --name /app/url-shorty/db_password --with-decryption | jq -r .Parameter.Value)`

```
docker run \
    --name my_docker \
    -p 8080:8080 \
    -e DB_USER=$DB_USERNAME \
    -e DB_PASSWORD=$DB_PASSWORD \
```

At the bottom of the `main.tf` we have included commented out examples of what terraform modules were used to store the username and password in the parameter store. 

To store a random username for the rds database and store it in parameter store:
```
resource "random_string" "db_username" {
  count       = var.db_instance == "postgres" ? 1 : 0
  min_numeric = 0
  length      = 8
  special     = false
}
```

```
resource "aws_ssm_parameter" "db_username" {
  count = var.db_instance == "postgres" ? 1 : 0
  name  = "/app/${var.app_name}/db_username"
  type  = "String"
  value = random_string.db_username[0].result
}
```

To store a random password for the rds database and store it in parameter store:
```
resource "random_password" "db_password" {
  count   = var.db_instance == "postgres" ? 1 : 0
  length  = 16
  special = false
}
```

```
resource "aws_ssm_parameter" "db_password" {
  count = var.db_instance == "postgres" ? 1 : 0
  name  = "/app/${var.app_name}/db_password"
  type  = "SecureString"
  value = random_password.db_password[0].result
}
```

### Pull Request
When the changes to the `user_data.sh` and `main.tf` files are complete you are ready to submit a pull request. 

When the PR is approved, Drone builds the resources in AWS.  

The `/deployments` directory contains a folder for every application built with the app-stack.


### Resources Provisioned
- Modules:
  - alb
  - efs
  - iam_role
  - app
  
- AWS Resources:
  - Autoscaling Group
    - ALB Target Group
    - ALB Listener
    - ALB Security Group
    - ALB R53 Human Readable Record
    - Launch Configuration
      - EC2 Instance Profile
      - EC2 Security Group
      - EC2 Instance User Data Definition
    - RDS Database
      - RDS Subnet Group

### Optional Resources 

- Persistent Storage
- Custom user_data script to run on startup
- RDS Database
- Auto-scaling-group Min / Max Instance count
- Custom Health Check
- Disable health check
