# GitHub Actions Workflows

This directory contains CI/CD workflows for the Hyperion Fleet Manager infrastructure.

## Workflows Overview

### PR Validation (`pr-validation.yml`)

Automatically runs on pull requests to validate infrastructure changes before merging.

**Triggers:**
- Pull requests to `main` or `develop` branches
- Changes to `infrastructure/`, `scripts/`, or `.github/workflows/`

**Checks performed:**
- Terraform formatting check
- Terraform validate across all environments
- TFLint static analysis
- Checkov security scanning
- tfsec security scanning
- PowerShell script analysis (PSScriptAnalyzer)
- Terraform plan for all environments
- Cost estimation with Infracost

**Requirements:**
- All checks must pass before merge
- Security findings are uploaded to GitHub Security tab
- Plan output and cost estimates are posted as PR comments

### Deploy to Dev (`deploy-dev.yml`)

Automatically deploys infrastructure changes to the development environment.

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Steps:**
1. Terraform plan
2. Terraform apply
3. Smoke tests
4. Deployment status update

**Features:**
- Automatic deployment on merge to main
- Post-deployment smoke tests
- Deployment status tracking
- Failure notifications

### Deploy to Staging (`deploy-staging.yml`)

Manual deployment to staging environment with approval.

**Triggers:**
- Manual workflow dispatch only

**Steps:**
1. Terraform plan
2. Manual approval (GitHub Environment protection)
3. Terraform apply
4. Post-deployment validation
5. Deployment status update

**Features:**
- Requires manual approval
- Comprehensive post-deployment tests
- Health checks and smoke tests
- Performance baseline validation

### Deploy to Production (`deploy-prod.yml`)

Controlled production deployment with multiple approval gates.

**Triggers:**
- Manual workflow dispatch only

**Steps:**
1. Pre-deployment checks
2. Terraform plan
3. Manual approval (production approval environment)
4. Create deployment snapshot
5. Terraform apply
6. Post-deployment validation
7. Monitoring initialization
8. Deployment status update

**Features:**
- Multiple approval gates
- Pre-deployment verification
- Deployment window checks
- Snapshot creation before apply
- Extended health checks
- Automatic rollback on failure
- Enhanced monitoring activation

### Drift Detection (`drift-detection.yml`)

Detects configuration drift between Terraform state and actual infrastructure.

**Triggers:**
- Scheduled: Every Monday at 6 AM UTC
- Manual workflow dispatch

**Checks:**
- Compares Terraform state with actual AWS resources
- Runs for all environments (dev, staging, prod)
- Creates GitHub issues for critical drift

**Features:**
- Weekly automated scans
- Drift reports uploaded as artifacts
- GitHub issue creation for production drift
- Summary report with recommendations

### Compliance Scan (`compliance-scan.yml`)

Daily security and compliance scanning.

**Triggers:**
- Scheduled: Daily at 2 AM UTC
- Manual workflow dispatch

**Scans performed:**
- Checkov security compliance
- tfsec security compliance
- AWS Config compliance check
- AWS Security Hub findings
- IAM policy compliance

**Features:**
- Daily automated scans
- Results uploaded to GitHub Security
- Compliance summary reports
- Threshold-based failure detection

## Composite Actions

Reusable actions located in `.github/actions/`:

### setup-terraform
Sets up Terraform with AWS credentials and caching.

**Inputs:**
- `terraform_version`: Terraform version (default: 1.7.0)
- `aws_role`: AWS IAM role ARN
- `aws_region`: AWS region (default: us-east-1)
- `working_directory`: Terraform working directory

### run-security-scan
Runs comprehensive security scanning with Checkov and tfsec.

**Inputs:**
- `directory`: Directory to scan
- `upload_sarif`: Upload results to GitHub Security
- `fail_on_severity`: Severity level to fail on

### terraform-plan-comment
Posts Terraform plan output as a PR comment.

**Inputs:**
- `plan_file`: Path to plan text file
- `environment`: Environment name
- `github_token`: GitHub token

## Required Secrets

Configure these secrets in your GitHub repository:

### AWS IAM Roles (OIDC)
- `AWS_ROLE_DEV`: Dev environment role ARN
- `AWS_ROLE_STAGING`: Staging environment role ARN
- `AWS_ROLE_PROD`: Production environment role ARN

### Third-party Services
- `INFRACOST_API_KEY`: Infracost API key for cost estimation

### Optional
- `SLACK_WEBHOOK_URL`: Slack webhook for notifications

## GitHub Environments

Configure these environments with protection rules:

### dev
- Auto-deploy on merge to main
- No approval required

### staging
- Manual deployment only
- Requires 1 approval

### prod
- Manual deployment only
- Requires 2 approvals
- Deployment branch restrictions

### prod-approval
- Additional approval gate for production
- Required reviewers: DevOps team leads

### prod-rollback
- Approval required for rollback operations
- Emergency contact required

## OIDC Configuration

Configure AWS IAM identity provider for GitHub Actions:

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list <THUMBPRINT>

# Create IAM role with trust policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"
        }
      }
    }
  ]
}
```

## Usage Examples

### Running PR Validation
Create a pull request with infrastructure changes. The workflow runs automatically.

### Deploying to Development
```bash
# Automatic on merge to main
git checkout main
git merge feature-branch
git push origin main
```

### Deploying to Staging
```bash
# Manual trigger from GitHub UI
# Go to Actions -> Deploy to Staging -> Run workflow
```

### Deploying to Production
```bash
# Manual trigger with approval
# 1. Go to Actions -> Deploy to Production -> Run workflow
# 2. Wait for approval from designated reviewers
# 3. Monitor deployment progress
```

### Running Drift Detection
```bash
# Check specific environment
# Go to Actions -> Drift Detection -> Run workflow
# Select environment: dev, staging, prod, or all
```

### Manual Compliance Scan
```bash
# Go to Actions -> Daily Compliance Scan -> Run workflow
```

## Monitoring and Alerts

### Workflow Failures
- Failed workflows trigger notifications
- Check Actions tab for detailed logs
- Review artifacts for scan results

### Security Findings
- View in Security tab -> Code scanning alerts
- Checkov and tfsec results categorized
- SARIF format for standardized reporting

### Drift Detection
- Check for open issues labeled `infrastructure-drift`
- Review drift reports in workflow artifacts
- Prioritize production drift immediately

## Best Practices

1. **Always review Terraform plans** before approving deployments
2. **Monitor deployments** for at least 15 minutes after completion
3. **Address security findings** promptly, especially CRITICAL/HIGH
4. **Investigate drift** as soon as detected
5. **Keep workflows updated** with Dependabot
6. **Document changes** in PR descriptions
7. **Test in dev/staging** before production
8. **Have rollback plans** for production changes

## Troubleshooting

### Workflow fails on Terraform init
- Check backend configuration
- Verify AWS credentials/permissions
- Check S3 bucket and DynamoDB table access

### Security scans fail
- Review security findings in artifacts
- Update Terraform code to fix issues
- Document accepted risks if needed

### Drift detected
- Review drift report
- Determine if changes were intentional
- Update Terraform code or revert manual changes

### Cost estimation fails
- Check Infracost API key
- Verify plan file is generated
- Review Infracost service status

## Maintenance

### Updating Terraform Version
1. Update `TERRAFORM_VERSION` in workflow files
2. Test in development first
3. Update across all workflows

### Updating Action Versions
Dependabot automatically creates PRs for updates.

### Adding New Environments
1. Create environment directory in `infrastructure/environments/`
2. Add secrets for new environment
3. Update workflows to include new environment
4. Configure GitHub environment protection

## Support

For issues or questions:
- Create an issue in the repository
- Contact DevOps team
- Review workflow run logs in Actions tab
