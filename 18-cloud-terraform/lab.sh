#!/usr/bin/env bash
# Session 19 lab: build a public VPC with Terraform, verify it with the AWS CLI,
# then tear it down. Runs against an AWS-compatible API at $AWS_ENDPOINT (Moto
# in the pipeline); the Terraform in vpc/ is unchanged real-AWS code.
set -uo pipefail
cd "$(dirname "$0")/vpc"
source ../../labs/lib.sh

: "${AWS_ENDPOINT:=http://localhost:5000}"
export AWS_ACCESS_KEY_ID=testing AWS_SECRET_ACCESS_KEY=testing AWS_DEFAULT_REGION=ap-south-1
AWS="aws --endpoint-url $AWS_ENDPOINT"

cat > emulator_override.tf <<EOF
provider "aws" {
  access_key                  = "testing"
  secret_key                  = "testing"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  endpoints {
    ec2 = "$AWS_ENDPOINT"
    sts = "$AWS_ENDPOINT"
  }
}
EOF

banner "1. init, fmt, validate"
run terraform init -input=false -no-color
run terraform fmt -check -diff
run terraform validate -no-color

banner "2. plan"
run terraform plan -input=false -no-color -out=tfplan

banner "3. apply"
run terraform apply -input=false -no-color tfplan
run terraform output -no-color
VPC=$(terraform output -raw vpc_id)
SUBNET=$(terraform output -raw public_subnet_id)
SG=$(terraform output -raw web_security_group_id)

banner "4. Verify each piece with the AWS CLI"
runsh "$AWS ec2 describe-vpcs --vpc-ids $VPC --query 'Vpcs[0].{Id:VpcId,Cidr:CidrBlock,State:State}' --output table"
runsh "$AWS ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[0].{Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIPOnLaunch:MapPublicIpOnLaunch}' --output table"
runsh "$AWS ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC --query 'InternetGateways[0].{Id:InternetGatewayId,AttachedTo:Attachments[0].VpcId,State:Attachments[0].State}' --output table"
note "the route that makes the subnet public: 0.0.0.0/0 to the internet gateway"
runsh "$AWS ec2 describe-route-tables --filters Name=association.subnet-id,Values=$SUBNET --query 'RouteTables[0].Routes[].{Destination:DestinationCidrBlock,Target:GatewayId}' --output table"
runsh "$AWS ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:IpRanges[0].CidrIp}' --output table"

banner "5. State"
run terraform state list

banner "6. destroy"
run terraform destroy -input=false -no-color -auto-approve
runsh "$AWS ec2 describe-vpcs --filters Name=tag:Project,Values=kunal-web --query 'length(Vpcs)'"
note "0 VPCs tagged Project=kunal-web remain"

rm -f emulator_override.tf tfplan
