#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -e

#export AWS_DEFAULT_REGION=#REGION
#export APP_NAME=#APP_NAME
#export USER=#SYS_USER

#BASE SYSTEM SUPPORT
#Based on Ubuntu
#sudo apt-get update
#sudo apt-get install -y nfs-common ca-certificates zip

#AWS THINGS
#curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
#unzip awscliv2.zip
#sudo ./aws/install

#SECRETS
#Example of how to pull and decrypt secrets from ssm param store and assign to a variable
#export DB_PASSWORD=$(aws ssm get-parameter --name /app/${APP_NAME}/db_password --query Parameter.Value --output text --with-decryption)

#---APP INSTALL BELOW HERE ---
# GA VERSION
#Speciric to the binary version to be pulled later
#GAW_VERSION="2.305.0"

# docker run \
#     --name <my_docker> \
#     -p 8443:8443 \
#     -e DB_PASSWORD=$DB_PASSWORD \
#     --pull always \
#     --security-opt=no-new-privileges \
#     --read-only \
#     --tmpfs /tmp \
#     --log-driver syslog --log-opt syslog-address=tcp://log-collector.security.caseyreed.com:5140 \
#     artifactory.caseyreed.com/docker/security/nginx-docker:latest
