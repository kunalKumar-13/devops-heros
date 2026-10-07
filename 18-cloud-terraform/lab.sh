#!/usr/bin/env bash
# Session 19 lab: build a public VPC with Terraform, verify it with the AWS CLI,
# then tear it down. Runs against an AWS-compatible API at $AWS_ENDPOINT (Moto
# in the pipeline); the Terraform in vpc/ is unchanged real-AWS code.
set -uo pipefail
cd "$(dirname "$0")/vpc"
source ../../labs/lib.sh

: "${AWS_ENDPOINT:=http://127.0.0.1:5000}"
curl -s -o /dev/null --max-time 5 "$AWS_ENDPOINT" || { echo "no AWS API at $AWS_ENDPOINT" >&2; exit 1; }
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
expect_sh "the VPC exists with CIDR 10.20.0.0/16" "$AWS ec2 describe-vpcs --vpc-ids $VPC | grep -q 10.20.0.0/16"
expect_sh "the public subnet is 10.20.1.0/24 and assigns public IPs" "$AWS ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[0].[CidrBlock,MapPublicIpOnLaunch]' --output text | grep -qP '10.20.1.0/24\\s+True'"
expect_sh "an internet gateway is attached to the VPC" "$AWS ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC --query 'length(InternetGateways)' | grep -q 1"
expect_sh "the subnet routes 0.0.0.0/0 to the internet gateway" "$AWS ec2 describe-route-tables --filters Name=association.subnet-id,Values=$SUBNET --query 'RouteTables[0].Routes[?DestinationCidrBlock==\`0.0.0.0/0\`].GatewayId' --output text | grep -q ^igw-"
expect_sh "the security group opens 80, 443 and 22" "[ \"\$($AWS ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions[].FromPort' --output text | tr -s '\\t ' '\\n' | sort -n | tr '\\n' ' ')\" = '22 80 443 ' ]"

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
expect_sh "destroy removed the VPC" "[ \$($AWS ec2 describe-vpcs --filters Name=tag:Project,Values=kunal-web --query 'length(Vpcs)') -eq 0 ]"

rm -f emulator_override.tf tfplan
finish
