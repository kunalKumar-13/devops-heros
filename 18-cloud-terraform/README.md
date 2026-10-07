# Session 19 — Cloud Networking with Terraform

**Kunal Kumar · Roll No. 24BCS10027**

The Session 19 mini-project: a public network on AWS, written in Terraform.
A VPC, a public subnet, an internet gateway, a route table that sends
`0.0.0.0/0` to it, the association that makes the subnet public, and a web
security group. Every piece is checked with the AWS CLI after `apply`, then
everything is destroyed.

- Terraform code: [`vpc/`](vpc/)
- Lab script: [`lab.sh`](lab.sh), run by the `terraform` job in
  [`.github/workflows/sessions-lab.yml`](../.github/workflows/sessions-lab.yml)
- Full transcript: [`session-output.txt`](session-output.txt)

> **Where it ran.** Same setup as Session 18: no AWS account, so the lab runs
> against [Moto](https://github.com/getmoto/moto), which implements the real
> EC2 API, on the CI runner. The code in `vpc/` is unchanged real-AWS
> Terraform; only a git-ignored `emulator_override.tf` points the provider at
> the emulator.

---

## Architecture

```text
Region ap-south-1
└── VPC 10.20.0.0/16 (DNS support + hostnames on)
    ├── Internet Gateway ───────────────────────────────┐
    ├── Public route table: 10.20.0.0/16 → local        │
    │                       0.0.0.0/0    → igw ─────────┘
    ├── Route table association: public subnet ↔ public route table
    ├── Public subnet 10.20.1.0/24, ap-south-1a, public IPs on launch
    └── Security group "web"
          in : 80 and 443 from 0.0.0.0/0, 22 from 203.0.113.10/32 only
          out: everything
```

| File | What it is |
|---|---|
| [`vpc/versions.tf`](vpc/versions.tf) | Terraform and provider versions |
| [`vpc/variables.tf`](vpc/variables.tf) | region, AZ, CIDRs, project prefix, `ssh_cidr` |
| [`vpc/main.tf`](vpc/main.tf) | the six resources |
| [`vpc/outputs.tf`](vpc/outputs.tf) | VPC, subnet, internet gateway and security group IDs |
| [`vpc/terraform.tfvars.example`](vpc/terraform.tfvars.example) | copy to `terraform.tfvars`; put your own IP in `ssh_cidr` |

```bash
cd vpc
terraform init && terraform fmt -check && terraform validate
terraform plan -out=tfplan        # 6 to add
terraform apply tfplan
terraform output
terraform state list
terraform destroy                 # 6 destroyed
```

---

## Questions from the mini-project

**Which subnet should an EC2 instance use?** The public subnet
(`10.20.1.0/24`). It's the one whose route table has `0.0.0.0/0 → igw`, and it
has `map_public_ip_on_launch = true`, so the instance gets a public IP.

**Which security group?** `web`: 80/443 open for the website, 22 only from one
admin address.

**Why does a public subnet need a route to the Internet Gateway?** That route
is what *makes* it public. A subnet has no "public" setting of its own; if its
route table has no `0.0.0.0/0 → igw`, traffic to the internet has nowhere to
go and the subnet is private, even with an internet gateway attached to the
VPC.

**What else does an EC2 instance need to be reachable from the internet?** A
public IP (or Elastic IP), a security group that allows the port, a network ACL
that allows it (the default one does), and something actually listening on
that port inside the instance. For SSH, also the key pair.

**Why shouldn't SSH be open to `0.0.0.0/0`?** Every IPv4 address gets scanned
for port 22 constantly, and password-guessing bots start within minutes of an
instance coming up. Allow only your own `/32` (or use SSM Session Manager and
open no port at all). The lab checks the rule really is a single `/32`.

## Interview questions

| | |
|---|---|
| **IaaS vs PaaS vs SaaS** | IaaS rents you machines, networks and disks (EC2, VPC); you manage the OS up. PaaS runs your code and manages the platform (Elastic Beanstalk, Heroku). SaaS is a finished product you just use (Gmail). |
| **Region vs Availability Zone** | A region is a geographic area (ap-south-1, Mumbai). An AZ is one or more separate data centres inside it, with independent power and network. Spreading across AZs survives a data-centre failure. |
| **VPC vs Subnet** | A VPC is your private network in a region, with one CIDR (`10.20.0.0/16`). A subnet is a slice of it (`10.20.1.0/24`) that lives in exactly one AZ. |
| **Public vs private subnet** | Public: its route table sends `0.0.0.0/0` to an internet gateway. Private: it doesn't (at most to a NAT gateway for outbound-only). |
| **Route table** | Rules for where traffic from a subnet goes, by destination CIDR. Every table has the `local` route for the VPC itself. |
| **Internet gateway** | The VPC's door to the internet, attached to the VPC, used as a route target. It also does the public-IP ↔ private-IP translation. |
| **Security group** | A stateful firewall on each network interface. Allow rules only; replies to allowed traffic are let back automatically. |
| **Terraform** | Infrastructure as code: describe resources in HCL, and Terraform creates, updates and deletes them to match, keeping track in its state. |
| **`plan` vs `apply`** | `plan` shows what would change and changes nothing. `apply` makes the changes (applying a saved plan file applies exactly that plan). |
| **`terraform state`** | Terraform's record of which real object (e.g. `vpc-0abc`) each resource in the code corresponds to. It's how it knows what exists and what to update. |
| **`terraform destroy`** | Deletes everything in the state, in dependency order (association and SG before subnet, subnet and IGW before the VPC). |

---

## What happened when it ran

Every command below ran in GitHub Actions on a fresh machine; these are verbatim excerpts of the transcript.

Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

**Verified results: 7 passed, 0 failed** (the checks the lab script makes; the job fails if any of them fail):

```text
  PASS  the VPC exists with CIDR 10.20.0.0/16
  PASS  the public subnet is 10.20.1.0/24 and assigns public IPs
  PASS  an internet gateway is attached to the VPC
  PASS  the subnet routes 0.0.0.0/0 to the internet gateway
  PASS  the security group opens exactly 22, 80 and 443 (22 80 443)
  PASS  SSH is open to a single /32, not the internet (203.0.113.10/32)
  PASS  destroy removed the VPC
```

**3. apply**

```console
kunal@terraform-lab:~$ terraform apply -input=false -no-color tfplan
aws_vpc.main: Creating...
aws_vpc.main: Still creating... [10s elapsed]
aws_vpc.main: Creation complete after 10s [id=vpc-49839e3b84a6a2207]
aws_internet_gateway.main: Creating...
aws_subnet.public: Creating...
aws_security_group.web: Creating...
aws_internet_gateway.main: Creation complete after 0s [id=igw-3c97efabe98084ffe]
aws_route_table.public: Creating...
aws_security_group.web: Creation complete after 0s [id=sg-1b9d1d3ec7c187e46]
aws_route_table.public: Creation complete after 0s [id=rtb-6a1a96bee5f4bf6a9]
aws_subnet.public: Still creating... [10s elapsed]
aws_subnet.public: Creation complete after 10s [id=subnet-be6d56b9e624b0a0f]
aws_route_table_association.public: Creating...
aws_route_table_association.public: Creation complete after 0s [id=rtbassoc-85ed2bb8aa37395a2]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

internet_gateway_id = "igw-3c97efabe98084ffe"
public_subnet_id = "subnet-be6d56b9e624b0a0f"
vpc_id = "vpc-49839e3b84a6a2207"
web_security_group_id = "sg-1b9d1d3ec7c187e46"

kunal@terraform-lab:~$ terraform output -no-color
internet_gateway_id = "igw-3c97efabe98084ffe"
public_subnet_id = "subnet-be6d56b9e624b0a0f"
vpc_id = "vpc-49839e3b84a6a2207"
web_security_group_id = "sg-1b9d1d3ec7c187e46"
```

**4. Verify each piece with the AWS CLI**

```console
kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 ec2 describe-vpcs --vpc-ids vpc-49839e3b84a6a2207 --query 'Vpcs[0].{Id:VpcId,Cidr:CidrBlock,State:State}' --output table
--------------------------------------------------------
|                     DescribeVpcs                     |
+---------------+-------------------------+------------+
|     Cidr      |           Id            |   State    |
+---------------+-------------------------+------------+
|  10.20.0.0/16 |  vpc-49839e3b84a6a2207  |  available |
+---------------+-------------------------+------------+

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 ec2 describe-subnets --subnet-ids subnet-be6d56b9e624b0a0f --query 'Subnets[0].{Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIPOnLaunch:MapPublicIpOnLaunch}' --output table
--------------------------------------------------
|                 DescribeSubnets                |
+-------------------+----------------------------+
|  AZ               |  ap-south-1a               |
|  Cidr             |  10.20.1.0/24              |
|  Id               |  subnet-be6d56b9e624b0a0f  |
|  PublicIPOnLaunch |  True                      |
+-------------------+----------------------------+

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=vpc-49839e3b84a6a2207 --query 'InternetGateways[0].{Id:InternetGatewayId,AttachedTo:Attachments[0].VpcId,State:Attachments[0].State}' --output table
-----------------------------------------------------------------
|                   DescribeInternetGateways                    |
+------------------------+-------------------------+------------+
|       AttachedTo       |           Id            |   State    |
+------------------------+-------------------------+------------+
|  vpc-49839e3b84a6a2207 |  igw-3c97efabe98084ffe  |  available |
+------------------------+-------------------------+------------+

>>> the route that makes the subnet public: 0.0.0.0/0 to the internet gateway

kunal@terraform-lab:~$ aws --endpoint-url http://127.0.0.1:5000 ec2 describe-route-tables --filters Name=association.subnet-id,Values=subnet-be6d56b9e624b0a0f --query 'RouteTables[0].Routes[].{Destination:DestinationCidrBlock,Target:GatewayId}' --output table
-------------------------------------------
|           DescribeRouteTables           |
+---------------+-------------------------+
|  Destination  |         Target          |
+---------------+-------------------------+
|  10.20.0.0/16 |  local                  |
|  0.0.0.0/0    |  igw-3c97efabe98084ffe  |
+---------------+-------------------------+

[... 10 more lines in the full transcript ...]
```

**6. destroy**

```console
kunal@terraform-lab:~$ terraform destroy -input=false -no-color -auto-approve
aws_vpc.main: Refreshing state... [id=vpc-49839e3b84a6a2207]
aws_internet_gateway.main: Refreshing state... [id=igw-3c97efabe98084ffe]
aws_subnet.public: Refreshing state... [id=subnet-be6d56b9e624b0a0f]
aws_security_group.web: Refreshing state... [id=sg-1b9d1d3ec7c187e46]
aws_route_table.public: Refreshing state... [id=rtb-6a1a96bee5f4bf6a9]
aws_route_table_association.public: Refreshing state... [id=rtbassoc-85ed2bb8aa37395a2]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_internet_gateway.main will be destroyed
[... 211 more lines in the full transcript ...]
```

