# NOTES.md

## Task 1 — `prevent_destroy` Instance Selection

### Which instance is protected and why?

**`db-server`** has `lifecycle { prevent_destroy = true }` because it holds persistent, stateful data.

**Reason:**
Accidentally deleting or modifying this instance would cause data loss. The other instances (web, app, cache, bastion) are stateless or easily rebuilt; the database is not.

### Implementation note on `prevent_destroy`

module splits the fleet into two `for_each` resources
Because Terraform `lifecycle` blocks are **static** (they cannot reference variables, locals, or expressions), it is impossible to toggle `prevent_destroy` with a variable. 


## Task 2 — Remote State & Locking
note:
The parameter `dynamodb_table` is deprecated. Use `use_lockfile` instead.

### What happens today with local state if two people run `apply` simultaneously?

With local state, two users can run `terraform apply` at the same time with no coordination. Both read the same last-known state from their local copy, both generate a plan, and both begin making API calls. The second apply to finish will overwrite the state file with its own view of the world — silently discarding any resources the first operator created. This causes issues like:

- Drift: The state file no longer reflects reality.
- Duplicate resources: Both users may create the same resource (e.g., two EC2 instances where one was intended).
- Deletes: On the next apply, Terraform may see resources it doesn't know about and try to destroy them.

### How the S3 + DynamoDB backend prevents this

1. **Remote state (S3)**: All users read and write the same `terraform.tfstate` file stored in S3. No user works from a private local copy.

2. **State locking (DynamoDB)**: Before Terraform reads state to build a plan, it writes a lock record (`LockID`) to the DynamoDB table. Any concurrent `terraform apply` or `plan` that tries to acquire the lock finds it taken and fails immediately with a clear error. The lock is released when the operation completes or fails.

3. **Versioning + encryption**: S3 bucket versioning preserves old state files, so a bad apply can be rolled back by restoring a previous version. Encryption protects secrets (e.g., private IPs, outputs) at rest.

---

## Task 3 — Multi-Account IAM

### Q1: Would you actually give `engine` and `ci` IAM users with access keys in a real production setup?

**No — not if any better mechanism is available.**

IAM long-lived access keys are the single biggest source of AWS credential leaks. They are static, don't expire automatically, and if committed to a repo or leaked via a build log they remain valid indefinitely until manually rotated.

**What I'd do instead, in order of preference:**

Better alternative :
- CI runner is GitHub Actions -> Use OIDC federation -> The runner gets short-lived STS tokens via a JWT; no stored key at all.
- CI runner is on an EC2 instance or ECS task -> Attach an IAM Instance Profile / Task Role -> The runner gets credentials from the metadata service; again, no stored key.
- CI runner is on-prem with no OIDC support -> Use `aws sts assume-role` via a very short-lived session (15 min) from a tightly scoped bootstrap key, and rotate that key with Secrets Manager.
- Must use access keys (legacy system) -> Store in AWS Secrets Manager or HashiCorp Vault; never in environment variables or source code; rotate automatically every 90 days via a Lambda.

### Q2: In `roleC`'s trust policy, why does it matter whether you trust Account A root vs. `roleB`'s specific ARN?

**Trusting Account A root (`arn:aws:iam::000000000000:root`)**:  
This delegates trust to Account A's *entire IAM permission system*. It means Account A's administrators can grant *any* principal in Account A (any user, any role) the right to assume `roleC` just by attaching `sts:AssumeRole` to them. The Account B owner has no control over who in Account A eventually gains access

**Trusting only `roleB`'s specific ARN (`arn:aws:iam::000000000000:role/roleB`)**:  
Only `roleB` — and nothing else in Account A — can assume `roleC`. Even if Account A's admins later grant a new user `sts:AssumeRole on *`, that user cannot assume `roleC` because the trust policy is an allowlist. The Account B owner retains full control over who can access. This provides least privilege at the cross-account access.


---

## Task 4 — Least-Privilege CI Policy

### Policy intent

The [`policies/ci-policy.json`](policies/ci-policy.json) grants only the required actions for a CI pipeline:

1. **`ecr:GetAuthorizationToken`** — must be `Resource: *` (it's an account-level call with no resource ARN).
2. **ECR push actions** — scoped to one specific repository ARN: `repository/my-app-repo`.
3. **`ecs:RegisterTaskDefinition` / `DescribeTaskDefinition` / `ListTaskDefinitions`** — must be `Resource: *` (ECS task definitions have no resource-level ARN in IAM for these calls).
4. **`ecs:UpdateService` / `DescribeServices` / `DescribeClusters`** — scoped to the specific cluster and service ARNs.
5. **`iam:PassRole`** — scoped to only the ECS task execution role and task role, with a `Condition` ensuring it can only be passed to `ecs-tasks.amazonaws.com`.
6. **`s3:Get*` / `s3:ListBucket`** — scoped to one specific bucket ARN (`my-ci-build-artifacts`), read-only.

### What was deliberately left out and why

| Omitted action | Why |
|---|---|
| `ecr:DeleteRepository`, `ecr:BatchDeleteImage` | CI should never destroy images — that's a manual/release-management action. |
| `ecs:StopTask`, `ecs:DeleteService`, `ecs:DeleteCluster` | Destructive; CI only deploys, it doesn't tear down infrastructure. |
| `ecs:RunTask` / `ecs:StartTask` | Not needed for a rolling deployment via `UpdateService`. |
| `s3:PutObject`, `s3:DeleteObject` on the artifact bucket | CI *reads* build artifacts, it doesn't write them (the build process writes; the deploy process reads). |
| `iam:*` except `PassRole` | CI never needs to manage IAM. |
| `ecr:GetAuthorizationToken` on a specific repo | AWS requires this to be `Resource: *` — there is no ARN to restrict it to. We accept this and compensate by restricting all other ECR actions to the specific repo. |

---

## Task 5 — Bug Fix

### Bug 1 — Wrong principal type in the trust policy

**Why it fails:**  
`roleB` is an **IAM role**, not an IAM user. The ARN path for roles is `:role/`, not `:user/`. 

**Fix:**  
```hcl
identifiers = ["arn:aws:iam::000000000000:role/roleB"]
```

---

### Bug 2 — Permissions policy allows `s3:*` on `Resource: "*"`

**What the snippet says:**  
```json
{ "Action": "s3:*", "Resource": "*" }
```

**Why it's wrong (two sub-issues):**
we should use specific actions instead of wildcards and also scope the resource to the specific bucket ARN (both bucket-level and object-level resources are needed)
1. `s3:*`: It grants every S3 action — including `DeleteBucket`, `DeleteBucketPolicy`, `PutBucketAcl`, etc. — which is full access to a single named S3 bucket.

2. `Resource: "*"` means every S3 bucket in every account.

**Fix:**  
Scope the resource to the specific bucket ARN (both bucket-level and object-level resources are needed):

```json
{
  "Effect": "Allow",
  "Action": ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject", "s3:PutObject", "s3:DeleteObject", ...],
  "Resource": [
    "arn:aws:s3:::my-cross-account-data-bucket",
    "arn:aws:s3:::my-cross-account-data-bucket/*"
  ]
}
```
