#!/usr/bin/env bash
# Session 18 lab: the full Terraform lifecycle on an S3 bucket.
#
# Runs against an AWS-compatible API at $AWS_ENDPOINT (Moto in the pipeline),
# because there is no AWS account. The Terraform in s3-bucket/ is unchanged
# real-AWS code; a throwaway override file points the provider at the
# emulator for this run only.
set -uo pipefail
cd "$(dirname "$0")/s3-bucket"
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
  s3_use_path_style           = true
  endpoints {
    s3  = "$AWS_ENDPOINT"
    sts = "$AWS_ENDPOINT"
  }
}
EOF

banner "0. The code (unchanged real-AWS Terraform)"
runsh "ls -1 *.tf | grep -v override"
note "emulator_override.tf points the provider at $AWS_ENDPOINT for this run; it is git-ignored"

banner "1. terraform init  (downloads the aws and random providers)"
run terraform init -input=false -no-color

banner "2. terraform fmt and validate"
run terraform fmt -check -diff
run terraform validate -no-color

banner "3. terraform plan"
run terraform plan -input=false -no-color -out=tfplan

banner "4. terraform apply"
run terraform apply -input=false -no-color tfplan

banner "5. State: what Terraform now tracks"
run terraform state list
runsh "terraform state show -no-color aws_s3_bucket.this | grep -E 'bucket |arn |tags'"

banner "6. Outputs"
run terraform output -no-color
BUCKET=$(terraform output -raw bucket_name)

banner "7. Verify with the AWS CLI, independently of Terraform"
runsh "$AWS s3api list-buckets --query 'Buckets[].Name' --output text"
runsh "$AWS s3api get-bucket-versioning --bucket $BUCKET"
runsh "$AWS s3api get-bucket-encryption --bucket $BUCKET --query 'ServerSideEncryptionConfiguration.Rules[0]'"
runsh "$AWS s3api get-public-access-block --bucket $BUCKET"
runsh "echo 'hello from kunal' > note.txt && $AWS s3 cp note.txt s3://$BUCKET/note.txt && $AWS s3 ls s3://$BUCKET/"

banner "8. Idempotence: planning again changes nothing"
run terraform plan -input=false -no-color -detailed-exitcode
note "exit code 0 from -detailed-exitcode means: no changes"

banner "9. A change: turn versioning off, see an in-place update"
run terraform plan -input=false -no-color -var enable_versioning=false
run terraform apply -input=false -no-color -auto-approve -var enable_versioning=false
runsh "$AWS s3api get-bucket-versioning --bucket $BUCKET"

banner "10. terraform destroy"
runsh "$AWS s3 rm s3://$BUCKET --recursive"
run terraform destroy -input=false -no-color -auto-approve -var enable_versioning=false
run terraform state list
runsh "$AWS s3api list-buckets --query 'Buckets[].Name' --output text; echo '(no buckets left)'"

rm -f emulator_override.tf tfplan note.txt
