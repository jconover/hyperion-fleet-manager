# GitHub Actions CI/CD for Hyperion Fleet Manager

Enterprise-grade CI/CD pipeline for Terraform infrastructure automation with comprehensive security, governance, and automation.

## Quick Start

```bash
# 1. Validate setup
./.github/scripts/validate-setup.sh

# 2. Read setup guide
cat .github/SETUP.md

# 3. Configure AWS and GitHub
# Follow instructions in SETUP.md

# 4. Test with a PR
git checkout -b test/workflow
# Make a small change
git commit -am "test: workflow validation"
git push origin test/workflow
gh pr create
```

## What's Included

### 🔄 Workflows (7)

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| **PR Validation** | Validate all infrastructure changes | Automatic on PR |
| **Deploy Dev** | Deploy to development | Automatic on merge |
| **Deploy Staging** | Deploy to staging | Manual + Approval |
| **Deploy Prod** | Deploy to production | Manual + 2 Approvals |
| **Drift Detection** | Detect config drift | Weekly + Manual |
| **Compliance Scan** | Security compliance | Daily + Manual |
| **Workflow Validation** | Validate workflows | On workflow changes |

### 🔧 Composite Actions (3)

- **setup-terraform**: Terraform setup with AWS OIDC
- **run-security-scan**: Comprehensive security scanning
- **terraform-plan-comment**: Post plans to PRs

### 📋 Features

**Security**
- ✅ OIDC authentication (no static credentials)
- ✅ Checkov + tfsec security scanning
- ✅ SARIF upload to GitHub Security
- ✅ Command injection prevention
- ✅ Daily compliance scanning

**Automation**
- ✅ Automatic dev deployments
- ✅ Weekly drift detection
- ✅ Automated dependency updates
- ✅ Self-service deployments
- ✅ Automatic rollback

**Governance**
- ✅ Multi-stage approvals
- ✅ Code ownership
- ✅ Cost estimation
- ✅ Deployment tracking
- ✅ Audit trail

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](SETUP.md) | Complete setup instructions |
| [WORKFLOW_QUICK_REFERENCE.md](WORKFLOW_QUICK_REFERENCE.md) | Quick reference guide |
| [workflows/README.md](workflows/README.md) | Detailed workflow docs |
| [workflows/IMPLEMENTATION_SUMMARY.md](workflows/IMPLEMENTATION_SUMMARY.md) | Implementation details |

## Required Configuration

### GitHub Secrets

```bash
AWS_ROLE_DEV           # IAM role for dev
AWS_ROLE_STAGING       # IAM role for staging
AWS_ROLE_PROD          # IAM role for production
INFRACOST_API_KEY      # Cost estimation API key
SLACK_WEBHOOK_URL      # Optional: Slack notifications
```

### GitHub Environments

- `dev` - No approval
- `staging` - 1 reviewer
- `prod` - 2 reviewers + 5 min wait
- `prod-approval` - Additional gate
- `prod-rollback` - Rollback approval

## Usage Examples

### Create Infrastructure Change

```bash
# 1. Create feature branch
git checkout -b feature/add-vpc

# 2. Make changes to infrastructure
vim infrastructure/environments/dev/vpc.tf

# 3. Create PR
gh pr create --title "Add VPC configuration"

# 4. Wait for validation
# All checks must pass

# 5. Merge after approval
gh pr merge --squash

# 6. Dev deploys automatically
# Monitor: gh run watch
```

### Deploy to Production

```bash
# 1. Ensure staging is healthy
gh run list --workflow=deploy-staging.yml

# 2. Trigger production deployment
gh workflow run deploy-prod.yml

# 3. Approve in GitHub UI (2 approvals required)
# 4. Monitor deployment
gh run watch

# 5. Verify health checks pass
# 6. Monitor for 15+ minutes
```

### Check for Drift

```bash
# Run drift detection
gh workflow run drift-detection.yml -f environment=prod

# Download results
gh run download <run-id>

# Review drift report
cat drift-reports/drift-report-prod/drift-plan.txt
```

## Architecture

```
┌─────────────┐
│ Pull Request│
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│     PR Validation Pipeline          │
│  • Format check                     │
│  • Validate                         │
│  • TFLint                           │
│  • Security scans (Checkov, tfsec) │
│  • Terraform plan                   │
│  • Cost estimate                    │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────┐
│    Merge    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Dev Deploy     │
│  (Automatic)    │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Staging Deploy  │
│ (Manual +       │
│  1 Approval)    │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  Prod Deploy    │
│ (Manual +       │
│  2 Approvals)   │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  Success!       │
│  Monitor →      │
└─────────────────┘
```

## Security Best Practices

1. **No Long-lived Credentials**: Uses OIDC for AWS authentication
2. **Least Privilege**: Separate IAM roles per environment
3. **Multiple Approvals**: Production requires 2 approvals
4. **Security Scanning**: Every PR scanned with Checkov + tfsec
5. **Drift Detection**: Weekly checks for manual changes
6. **Compliance Monitoring**: Daily compliance scans
7. **Audit Trail**: All deployments tracked in GitHub

## Support

- **Issues**: Create a GitHub issue
- **Questions**: Contact DevOps team
- **Documentation**: See [SETUP.md](SETUP.md)
- **Quick Reference**: See [WORKFLOW_QUICK_REFERENCE.md](WORKFLOW_QUICK_REFERENCE.md)

## Maintenance

### Daily
- Review compliance scan results
- Monitor deployment metrics

### Weekly
- Review drift detection reports
- Merge Dependabot PRs

### Monthly
- Audit IAM permissions
- Review workflow metrics

## License

See [LICENSE](../LICENSE) file in project root.

---

**Ready to get started?** → Read [SETUP.md](SETUP.md)
