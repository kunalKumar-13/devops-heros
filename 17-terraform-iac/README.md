# Session 18 — Terraform & Infrastructure as Code

**Kunal Kumar · Roll No. 24BCS10027**

The session's S3 demo, taken through the whole Terraform lifecycle: `init`,
`fmt`, `validate`, `plan`, `apply`, inspect the state and outputs, verify with
the AWS CLI, plan again to prove nothing drifts, change one setting, and
`destroy`.

- Terraform code: [`s3-bucket/`](s3-bucket/)
- Lab script: [`lab.sh`](lab.sh), run by the `terraform` job in
  [`.github/workflows/sessions-lab.yml`](../.github/workflows/sessions-lab.yml)
- Full transcript: [`session-output.txt`](session-output.txt)

> **Where it ran.** I don't have an AWS account for this course, so the lab
> runs against [Moto](https://github.com/getmoto/moto), a server that speaks
> the real AWS S3/EC2/STS APIs, on the CI runner. The Terraform in `s3-bucket/`
> is plain AWS code with nothing emulator-specific in it. The lab adds a
> git-ignored `emulator_override.tf` that points the provider's endpoints at
> Moto; delete that file, run `aws configure`, and the same code creates a
> real bucket. The AWS CLI checks in the lab go to the same API, independently
> of Terraform.

---

## Files

```text
s3-bucket/
├── versions.tf               Terraform >= 1.6, aws ~> 5.80, random ~> 3.6
├── providers.tf              region from a variable, default tags on everything
├── variables.tf              aws_region, project, environment (validated), enable_versioning
├── main.tf                   the bucket, versioning, encryption, public access block
├── outputs.tf                bucket_name, bucket_arn, versioning
├── terraform.tfvars.example  copy to terraform.tfvars to override defaults
├── .terraform.lock.hcl       exact provider versions, committed
└── .gitignore                state, .terraform/, tfvars, the emulator override
```

The bucket is set up the way a real one should be, not just "a bucket":

| Resource | Why |
|---|---|
| `random_id` + `aws_s3_bucket` | bucket names are global across every AWS account, so a random suffix avoids clashes (`kunal-devops-dev-xxxxxxxx`) |
| `aws_s3_bucket_versioning` | overwrites and deletes are recoverable |
| `aws_s3_bucket_server_side_encryption_configuration` | everything encrypted at rest (AES256) |
| `aws_s3_bucket_public_access_block` | all four public-access switches on, so nothing in it can be made public by accident |

## The lifecycle

```bash
terraform init          # download the providers pinned in .terraform.lock.hcl
terraform fmt -check    # formatting, as a check (CI-friendly)
terraform validate      # syntax and types, no API calls
terraform plan -out=tfplan
terraform apply tfplan  # 5 to add
terraform state list
terraform output
aws s3api get-bucket-versioning / get-bucket-encryption / get-public-access-block
terraform plan -detailed-exitcode      # exit 0 = no changes
terraform apply -var enable_versioning=false   # 0 add, 1 change, 0 destroy
terraform destroy       # 5 destroyed
```

## Things worth knowing

**Declarative.** The `.tf` files say what should exist, not the steps to make
it. Terraform compares that with the state and the real API and works out the
steps. That's why running `plan` right after `apply` shows *no changes*: the lab
checks that with `-detailed-exitcode`.

**`plan` vs `apply`.** `plan` is a dry run: it shows what would be created,
changed or destroyed. Saving it with `-out=tfplan` and applying *that file*
guarantees that what gets applied is exactly what was reviewed.

**State.** `terraform.tfstate` maps each resource in the code to the real
object's ID. Without it Terraform can't know the bucket already exists. It can
contain secrets and must never be committed (it's in `.gitignore`); a team
keeps it in a remote backend (an S3 bucket with locking) so everyone shares one
copy.

**In-place update vs replace.** Turning versioning off was `1 to change`, an
update in place. Changing the bucket *name* would be a replace (destroy then
create), which `plan` marks with `-/+`. Reading the plan symbols before typing
`yes` is the whole point of `plan`.

**Variables and validation.** `environment` only accepts `dev`, `staging` or
`prod`; anything else fails at `plan` time with a clear message, before any
API call.

---

## What happened when it ran

Every command below ran in GitHub Actions on a fresh machine; these are verbatim excerpts of the transcript.

Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

**Verified results: 9 passed, 0 failed** (the checks the lab script makes; the job fails if any of them fail):

```text
  PASS  apply created the bucket (kunal-devops-dev-4f8383a7)
  PASS  versioning is Enabled
  PASS  objects are encrypted at rest with AES256
  PASS  all four public-access blocks are on
  PASS  an object can be written and read back
  PASS  re-planning finds no changes (idempotent)
  PASS  the change was applied in place (versioning Suspended)
  PASS  destroy removed the bucket
  PASS  state is empty after destroy
```

**4. terraform apply**

```console
kunal@terraform-lab:~$ terraform apply -input=false -no-color tfplan
random_id.suffix: Creating...
random_id.suffix: Creation complete after 0s [id=T4ODpw]
aws_s3_bucket.this: Creating...
aws_s3_bucket.this: Creation complete after 0s [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_versioning.this: Creating...
aws_s3_bucket_public_access_block.this: Creating...
aws_s3_bucket_server_side_encryption_configuration.this: Creating...
aws_s3_bucket_public_access_block.this: Creation complete after 0s [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_server_side_encryption_configuration.this: Creation complete after 0s [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_versioning.this: Creation complete after 1s [id=kunal-devops-dev-4f8383a7]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = "arn:aws:s3:::kunal-devops-dev-4f8383a7"
bucket_name = "kunal-devops-dev-4f8383a7"
versioning = "Enabled"
```

**7. Verify with the AWS CLI, independently of Terraform**

```console
kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 s3api list-buckets --query 'Buckets[].Name' --output text
kunal-devops-dev-4f8383a7

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 s3api get-bucket-versioning --bucket kunal-devops-dev-4f8383a7
{
    "Status": "Enabled"
}

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 s3api get-bucket-encryption --bucket kunal-devops-dev-4f8383a7 --query 'ServerSideEncryptionConfiguration.Rules[0]'
{
    "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
    },
    "BucketKeyEnabled": false
}

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 s3api get-public-access-block --bucket kunal-devops-dev-4f8383a7
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}

kunal@terraform-lab:~$ echo 'hello from kunal' > note.txt && aws --endpoint-url http://127.0.0.1:5000 s3 cp note.txt s3://kunal-devops-dev-4f8383a7/note.txt && aws --endpoint-url http://127.0.0.1:5000 s3 ls s3://kunal-devops-dev-4f8383a7/
Completed 17 Bytes/17 Bytes (1009 Bytes/s) with 1 file(s) remaining
upload: ./note.txt to s3://kunal-devops-dev-4f8383a7/note.txt      
2026-10-07 17:16:05         17 note.txt
```

**8. Idempotence: planning again changes nothing**

```console
kunal@terraform-lab:~$ terraform plan -input=false -no-color -detailed-exitcode
random_id.suffix: Refreshing state... [id=T4ODpw]
aws_s3_bucket.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_server_side_encryption_configuration.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_versioning.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_public_access_block.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.

>>> exit code 0 from -detailed-exitcode means: no changes
```

**9. A change: turn versioning off, see an in-place update**

```console
kunal@terraform-lab:~$ terraform plan -input=false -no-color -var enable_versioning=false
random_id.suffix: Refreshing state... [id=T4ODpw]
aws_s3_bucket.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_public_access_block.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_server_side_encryption_configuration.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_versioning.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_s3_bucket_versioning.this will be updated in-place
  ~ resource "aws_s3_bucket_versioning" "this" {
        id                    = "kunal-devops-dev-4f8383a7"
        # (2 unchanged attributes hidden)

      ~ versioning_configuration {
          ~ status     = "Enabled" -> "Suspended"
            # (1 unchanged attribute hidden)
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
[... 52 more lines in the full transcript ...]
```

**10. terraform destroy**

```console
kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 s3 rm s3://kunal-devops-dev-4f8383a7 --recursive
delete: s3://kunal-devops-dev-4f8383a7/note.txt

kunal@terraform-lab:~$ terraform destroy -input=false -no-color -auto-approve -var enable_versioning=false
random_id.suffix: Refreshing state... [id=T4ODpw]
aws_s3_bucket.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_versioning.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_public_access_block.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]
aws_s3_bucket_server_side_encryption_configuration.this: Refreshing state... [id=kunal-devops-dev-4f8383a7]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_s3_bucket.this will be destroyed
  - resource "aws_s3_bucket" "this" {
      - arn                         = "arn:aws:s3:::kunal-devops-dev-4f8383a7" -> null
      - bucket                      = "kunal-devops-dev-4f8383a7" -> null
[... 117 more lines in the full transcript ...]
```

