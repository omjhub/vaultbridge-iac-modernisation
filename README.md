# VaultBridge — Infrastructure as Code Modernisation on AWS

**Client:** VaultBridge Financial Technologies (Lagos, Nigeria) — a fintech operating across Nigeria, Kenya, Ghana, and Rwanda, 2.4 million users, up to 340,000 transactions/day, held to a 99.95% uptime SLA (4.38 hours downtime/year maximum) and regulated by the Central Bank of Nigeria.
**Engagement:** Infrastructure as Code modernisation, two-week programme
**Region:** AWS eu-west-1 (Ireland)
**Stack:** Terraform 1.15.7, AWS (VPC, EC2, RDS, S3, IAM), PostgreSQL 15
**Full report:** [vaultbridge-technical-report.pdf](./vaultbridge-technical-report.pdf)

## The problem

VaultBridge's cloud infrastructure was managed entirely through the AWS Console: no version control, no peer review, no automated validation. On 28 November 2023, an engineer temporarily opened database port 5432 to the entire internet while debugging a connectivity issue, got pulled into another call, and never reverted it. Automated scanners found the exposure in six minutes and launched a brute-force attack. The resulting outage lasted 4 hours 12 minutes, affected roughly 47,000 transactions, and cost the business $214,000.

The root cause wasn't a skills gap. It was a system where the unsafe action (a broad CIDR range, a manual console change with no review) was structurally just as easy as the safe one. This programme's design principle responds to that directly: **make the unsafe approach harder than the safe approach, structurally, not just procedurally.**

## What I built

A three-tier AWS architecture, provisioned entirely through Terraform and deployed only through a reviewed CI/CD pipeline, never through a local `terraform apply`.

- **Network layer:** a VPC (`10.0.0.0/16`) across two availability zones, with public subnets (EC2, internet gateway) and private subnets (RDS) that have **no route to the internet gateway at all**. Not a deny rule, an absent route, which can't be silently bypassed by a misconfigured security group.
- **Security layer:** the RDS security group accepts inbound traffic only via a *security group reference* to the EC2 tier, not a CIDR block. A CIDR-based rule encodes an IP address that breaks the moment the EC2 instance is replaced; a security group reference encodes the actual intent ("the app tier talks to the database") and survives instance replacement. SSH is restricted to a single `/32` address, the minimum possible range.
- **Database layer:** RDS PostgreSQL with `publicly_accessible = false` (removes the public DNS endpoint entirely), encryption at rest (KMS), enforced TLS in transit, and connection/disconnection/duration audit logging for CBN compliance evidence.
- **State management:** a two-stage bootstrap pattern (a minimal local-state workspace creates the S3 backend, everything else uses it as remote state), with AES-256 encryption, versioning, and native S3 locking.

## The validation block that mirrors the actual incident

The November 2023 incident happened because a broad CIDR range was typed where a narrow one belonged. This project has a Terraform validation block that catches exactly that category of mistake before any AWS API call is made:

```hcl
variable "my_ip_cidr" {
  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be /32. A broader CIDR violates least-privilege policy."
  }
}
```

Tested against `x.x.x.x/24`: the plan fails immediately with that error message, before Terraform ever reaches AWS. Additional validation blocks enforce region restrictions, exactly two subnet CIDRs for multi-AZ compliance, blocked reserved database usernames, and a minimum password length.

## Proof the pipeline actually enforces the workflow

A five-job GitHub Actions pipeline (format check, validate, security scan, plan, apply) structurally separates plan (runs on every pull request) from apply (runs only on merge to `main`), so the plan a reviewer approves is the plan that gets applied.

The most useful demonstration in the whole project wasn't the pipeline passing, it was the pipeline **failing on its first run**. The first push to the feature branch failed the format check job because `rds.tf` had inconsistent indentation introduced alongside a lifecycle block. The merge to `main` was blocked automatically, no reviewer had to catch it by hand. `terraform fmt` fixed it, the second run passed clean, and the fix is in the commit history.

## Security scanning: findings triaged, not hidden

tfsec and Checkov both run in the pipeline. Checkov: 46 checks passed, 11 failed. Every failed check was individually reviewed and given an explicit, documented decision, not blanket-suppressed:

| Finding | Decision | Rationale |
|---|---|---|
| Port 80 open to `0.0.0.0/0` | Accepted by design | Public web app requires open HTTP |
| Multi-AZ not enabled | Deferred (high priority) | Doubles RDS cost on free tier; flagged as the top production gap |
| Deletion protection off | Deferred | Required for demo teardown; must be `true` in production |
| Backup retention = 0 | Deferred | AWS free-tier constraint; 7 days minimum in production |
| Auto minor version upgrade | **Fixed** | `auto_minor_version_upgrade = true` added directly to `rds.tf` |

The Multi-AZ gap is flagged explicitly as the most significant open risk: a single-AZ database is incompatible with VaultBridge's 99.95% SLA, and it's documented as the first item for any production promotion.

## Results

All 19 defined success metrics were met, independently verified against at least two sources (Terraform state, AWS Console, and AWS CLI) rather than trusting Terraform's own output alone. End-to-end connectivity was confirmed by SSHing into the EC2 instance and querying PostgreSQL directly: `inet_client_addr()` and `inet_server_addr()` both returned private `10.0.x.x` addresses, confirming the connection never touched the public internet, and `pg_stat_ssl` confirmed TLS was active from the server's own perspective, not just the client's claim.

## Tools

`Terraform` `AWS (VPC, EC2, RDS, S3, IAM)` `tfsec` `Checkov` `GitHub Actions` `PostgreSQL`
