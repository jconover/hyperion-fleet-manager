# GitHub Actions CI/CD Setup Guide

This guide will help you set up the GitHub Actions workflows for the Hyperion Fleet Manager project.

## Prerequisites

- GitHub repository with admin access
- AWS account with appropriate permissions
- Terraform Cloud/Enterprise account (optional)
- Infracost account (for cost estimation)

## Step 1: Configure AWS OIDC Provider

### 1.1 Create OIDC Provider in AWS

```bash
# Get GitHub's OIDC thumbprint
THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha1 -noout | cut -d'=' -f2 | tr -d ':')

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "${THUMBPRINT}"
```

### 1.2 Create IAM Roles for Each Environment

Create three IAM roles (dev, staging, prod) with the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
        }
      }
    }
  ]
}
```

### 1.3 Attach Permissions to Roles

Attach appropriate policies to each role:

```bash
# Example for dev environment
aws iam attach-role-policy \
  --role-name github-actions-dev \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Create and attach custom policy for Terraform state
aws iam put-role-policy \
  --role-name github-actions-dev \
  --policy-name terraform-state-access \
  --policy-document file://terraform-state-policy.json
```

Example `terraform-state-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state-bucket/hyperion-fleet/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    }
  ]
}
```

## Step 2: Configure GitHub Secrets

Navigate to your repository → Settings → Secrets and variables → Actions

### Required Secrets

Add the following secrets:

```bash
# AWS Role ARNs
AWS_ROLE_DEV=arn:aws:iam::ACCOUNT_ID:role/github-actions-dev
AWS_ROLE_STAGING=arn:aws:iam::ACCOUNT_ID:role/github-actions-staging
AWS_ROLE_PROD=arn:aws:iam::ACCOUNT_ID:role/github-actions-prod

# Infracost API Key
INFRACOST_API_KEY=your-infracost-api-key
```

### Optional Secrets

```bash
# Slack webhook for notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Step 3: Configure GitHub Environments

### 3.1 Create Environments

Navigate to Settings → Environments and create:

1. **dev**
   - No protection rules
   - Secrets: None (uses repository secrets)

2. **staging**
   - Required reviewers: 1 reviewer
   - Wait timer: 0 minutes
   - Deployment branches: `main` only

3. **prod**
   - Required reviewers: 2 reviewers (senior team members)
   - Wait timer: 5 minutes
   - Deployment branches: `main` only
   - Environment secrets (if needed)

4. **prod-approval**
   - Required reviewers: 2 reviewers (different from prod)
   - Additional approval gate for production

5. **prod-rollback**
   - Required reviewers: 1 reviewer
   - For emergency rollback approvals

### 3.2 Configure Environment Protection Rules

For each protected environment (staging, prod):

```yaml
Protection rules:
  ✓ Required reviewers (1-2 depending on environment)
  ✓ Wait timer (optional delay before deployment)
  ✓ Deployment branches (restrict to main)
  ✓ Environment secrets (if different from repo secrets)
```

## Step 4: Set Up Infracost

### 4.1 Create Infracost Account

1. Sign up at https://www.infracost.io/
2. Get your API key from the dashboard
3. Add it to GitHub secrets as `INFRACOST_API_KEY`

### 4.2 Configure Infracost (Optional)

Create `.infracost/infracost.yml` in your repository:

```yaml
version: 0.1
projects:
  - path: infrastructure/environments/dev
    name: hyperion-fleet-dev
  - path: infrastructure/environments/staging
    name: hyperion-fleet-staging
  - path: infrastructure/environments/prod
    name: hyperion-fleet-prod
```

## Step 5: Configure Branch Protection

Navigate to Settings → Branches → Add rule for `main`:

```yaml
Branch protection rules for 'main':
  ✓ Require pull request reviews before merging
  ✓ Require status checks to pass before merging
    - terraform-fmt
    - terraform-validate
    - tflint-scan
    - checkov-scan
    - tfsec-scan
  ✓ Require branches to be up to date before merging
  ✓ Include administrators
  ✓ Require linear history (optional)
  ✓ Do not allow bypassing the above settings
```

## Step 6: Configure Notifications (Optional)

### Slack Integration

1. Create a Slack incoming webhook
2. Add webhook URL to GitHub secrets
3. Uncomment notification sections in workflows

### Email Notifications

Configure in repository Settings → Notifications

## Step 7: Initialize Terraform Backend

Before running workflows, ensure Terraform backend is configured:

```bash
# Create S3 bucket for state
aws s3 mb s3://terraform-state-hyperion-fleet --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-hyperion-fleet \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-hyperion-fleet \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Step 8: Test the Setup

### 8.1 Test PR Validation

1. Create a feature branch
2. Make a small change to infrastructure
3. Create a pull request
4. Verify all checks run successfully

### 8.2 Test Dev Deployment

1. Merge PR to main
2. Verify automatic deployment to dev
3. Check deployment status in Actions tab

### 8.3 Test Staging Deployment

1. Manually trigger staging deployment
2. Approve when prompted
3. Verify deployment completes

### 8.4 Test Drift Detection

1. Manually trigger drift detection workflow
2. Verify it completes without errors
3. Check artifacts for drift reports

## Step 9: Configure Code Owners

The `.github/CODEOWNERS` file is already configured. Update team names to match your GitHub organization:

```bash
# Replace placeholder team names with actual teams
sed -i 's/@devops-team/@your-devops-team/g' .github/CODEOWNERS
sed -i 's/@platform-engineering/@your-platform-team/g' .github/CODEOWNERS
# ... etc
```

## Step 10: Enable Dependabot

Dependabot is configured via `.github/dependabot.yml`. It will automatically:

- Update GitHub Actions weekly
- Update Terraform providers weekly
- Create PRs for updates

To customize:

1. Edit `.github/dependabot.yml`
2. Update schedule, reviewers, and labels
3. Commit changes

## Verification Checklist

- [ ] AWS OIDC provider created
- [ ] IAM roles created for all environments
- [ ] GitHub secrets configured
- [ ] GitHub environments created with protection rules
- [ ] Branch protection rules enabled
- [ ] Infracost API key added
- [ ] Terraform backend initialized
- [ ] CODEOWNERS updated
- [ ] Test PR validation successful
- [ ] Test dev deployment successful
- [ ] Test staging deployment successful
- [ ] Drift detection workflow tested
- [ ] Compliance scan workflow tested

## Troubleshooting

### Workflow fails with AWS authentication error

- Verify OIDC provider is configured correctly
- Check IAM role trust policy includes correct repository
- Verify role ARN in GitHub secrets is correct

### Terraform init fails

- Check S3 bucket and DynamoDB table exist
- Verify IAM role has permissions to access backend
- Check backend configuration in Terraform files

### Infracost fails

- Verify API key is correct
- Check Infracost service status
- Ensure Terraform plan is generated successfully

### Approval not working

- Verify reviewers have correct permissions
- Check environment protection rules
- Ensure reviewers are part of the organization

## Security Best Practices

1. **Least Privilege**: Grant minimum required permissions to IAM roles
2. **Separate Roles**: Use different roles for each environment
3. **Audit Logging**: Enable CloudTrail for all AWS API calls
4. **Secret Rotation**: Rotate API keys and credentials regularly
5. **Review Access**: Periodically review who has access to environments
6. **Monitor Workflows**: Set up alerts for failed deployments
7. **Secure Branches**: Protect main branch from direct pushes
8. **Code Review**: Require reviews for all infrastructure changes

## Maintenance

### Monthly Tasks

- Review and close resolved drift detection issues
- Review security scan findings
- Update Terraform and provider versions
- Review and merge Dependabot PRs

### Quarterly Tasks

- Review IAM role permissions
- Audit GitHub environment access
- Review and update runbooks
- Test disaster recovery procedures

## Support

For issues or questions:

- Create an issue in the repository
- Contact the DevOps team
- Review workflow logs in Actions tab
- Check AWS CloudTrail for API errors

## Next Steps

After completing setup:

1. Create infrastructure for each environment
2. Test complete deployment pipeline
3. Document environment-specific configurations
4. Train team on workflow usage
5. Set up monitoring and alerting
6. Create runbooks for common operations
