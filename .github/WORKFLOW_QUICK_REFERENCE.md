# GitHub Actions Workflow Quick Reference

## Common Commands

### Trigger Workflows Manually

```bash
# Using GitHub CLI
gh workflow run deploy-staging.yml
gh workflow run deploy-prod.yml
gh workflow run drift-detection.yml -f environment=prod
gh workflow run compliance-scan.yml

# View workflow runs
gh run list --workflow=deploy-dev.yml
gh run watch

# View workflow details
gh run view <run-id>
```

### Check Workflow Status

```bash
# List all workflows
gh workflow list

# View specific workflow runs
gh run list --workflow=pr-validation.yml --limit 5

# Download artifacts
gh run download <run-id>
```

## Workflow Triggers Quick Reference

| Workflow | Automatic | Manual | Schedule |
|----------|-----------|--------|----------|
| PR Validation | ✓ (on PR) | - | - |
| Deploy Dev | ✓ (on main push) | ✓ | - |
| Deploy Staging | - | ✓ | - |
| Deploy Prod | - | ✓ | - |
| Drift Detection | - | ✓ | ✓ (Weekly) |
| Compliance Scan | - | ✓ | ✓ (Daily) |
| Workflow Validation | ✓ (on workflow changes) | - | - |

## Common Workflow Scenarios

### Scenario 1: Deploy Infrastructure Change

```bash
# 1. Create feature branch
git checkout -b feature/add-vpc

# 2. Make changes
# Edit infrastructure files

# 3. Commit and push
git add .
git commit -m "Add VPC configuration"
git push origin feature/add-vpc

# 4. Create PR
gh pr create --title "Add VPC configuration" --body "..."

# 5. Wait for PR validation to complete
# Review checks in PR

# 6. Merge PR (after approval)
gh pr merge --squash

# 7. Dev deployment runs automatically
# Monitor: gh run watch

# 8. Deploy to staging (manual)
gh workflow run deploy-staging.yml

# 9. Approve staging deployment in UI
# Monitor deployment

# 10. Deploy to production (manual, after staging success)
gh workflow run deploy-prod.yml

# 11. Approve production deployment
# Monitor deployment closely
```

### Scenario 2: Emergency Hotfix

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/fix-security-group

# 2. Make minimal required changes
# Fix the issue

# 3. Create PR with [HOTFIX] prefix
gh pr create --title "[HOTFIX] Fix security group ingress" --body "..."

# 4. Request expedited review
# Tag senior engineers

# 5. After approval, merge
gh pr merge --squash

# 6. Deploy directly to production (if critical)
gh workflow run deploy-prod.yml

# 7. Monitor closely for issues
# Have rollback plan ready
```

### Scenario 3: Investigate Drift

```bash
# 1. Run drift detection
gh workflow run drift-detection.yml -f environment=prod

# 2. Wait for completion
gh run watch

# 3. Download drift report
gh run download <run-id>

# 4. Review drift-report-prod/drift-plan.txt
cat drift-reports/drift-report-prod/drift-plan.txt

# 5. Determine action:
# Option A: Update Terraform to match reality
# Option B: Apply Terraform to revert manual changes

# 6. Create PR with fix
# Document reason for drift
```

### Scenario 4: Review Security Findings

```bash
# 1. Navigate to Security tab in GitHub
# 2. Review Code scanning alerts
# 3. Click on specific finding for details

# 4. Download detailed scan results
gh run list --workflow=compliance-scan.yml
gh run download <run-id>

# 5. Review findings
cat compliance-reports/compliance-scan-results/checkov-compliance.json

# 6. Create issues for high-priority findings
gh issue create --title "Fix: Security finding in S3 bucket" --label security

# 7. Create PR with fixes
```

### Scenario 5: Rollback Failed Deployment

```bash
# 1. If post-deployment validation fails, rollback triggers automatically

# Manual rollback:
# 2. Identify last known good deployment
gh run list --workflow=deploy-prod.yml --limit 10

# 3. Checkout previous working version
git checkout <previous-commit-sha>

# 4. Create rollback branch
git checkout -b rollback/prod-deployment

# 5. Create PR
gh pr create --title "[ROLLBACK] Revert to previous production state" --body "..."

# 6. Fast-track approval
# 7. Deploy to production
gh workflow run deploy-prod.yml
```

## Approval Workflow

### Staging Approval

1. Workflow creates deployment and pauses
2. Designated reviewer receives notification
3. Reviewer checks:
   - Terraform plan looks correct
   - No unexpected changes
   - Security scans passed
4. Approve in GitHub UI (Environment deployments)
5. Deployment continues

### Production Approval

1. Pre-deployment checks complete
2. First approval gate (prod-approval environment)
3. Reviewer 1 and 2 approve
4. Second approval gate (prod environment)
5. Additional reviewers approve
6. Deployment proceeds
7. Post-deployment validation runs
8. Monitor for 15+ minutes

## Monitoring Deployments

### Real-time Monitoring

```bash
# Watch deployment progress
gh run watch

# View logs for specific job
gh run view <run-id> --log

# View logs for specific step
gh run view <run-id> --log-failed
```

### Post-Deployment

1. Check workflow summary in Actions tab
2. Review deployment status comments on commit
3. Check CloudWatch dashboards
4. Monitor application logs
5. Verify health checks passing

## Common Issues and Solutions

### Issue: Workflow stuck on approval

**Solution:**
```bash
# Check who needs to approve
gh run view <run-id>

# Contact reviewers
# Or cancel and restart
gh run cancel <run-id>
gh workflow run <workflow-name>
```

### Issue: Terraform plan fails

**Solution:**
```bash
# Download plan artifacts
gh run download <run-id>

# Review error in plan file
cat terraform-plan-dev/tfplan.txt

# Fix locally and test
cd infrastructure/environments/dev
terraform init
terraform plan

# Push fix and retry
```

### Issue: Security scan finds issues

**Solution:**
```bash
# Download scan results
gh run download <run-id>

# Review findings
cat checkov-results.json | jq '.results'

# Fix issues or document exceptions
# Add to .checkov.yml if acceptable risk
```

### Issue: Cost spike detected

**Solution:**
```bash
# Download Infracost report
gh run download <run-id>

# Review cost breakdown
cat infracost-*.json | jq

# Adjust resources if needed
# Add cost optimization measures
```

## Useful GitHub CLI Commands

```bash
# Install GitHub CLI
# See: https://cli.github.com/

# Login
gh auth login

# View PR checks
gh pr checks

# View PR status
gh pr status

# List workflows
gh workflow list

# View workflow file
gh workflow view deploy-prod.yml

# Cancel running workflow
gh run cancel <run-id>

# Re-run failed jobs
gh run rerun <run-id> --failed

# Download all artifacts
gh run download <run-id>

# Create issue from template
gh issue create --template bug_report
```

## Environment Variables Reference

Common environment variables used in workflows:

```yaml
TERRAFORM_VERSION: '1.7.0'
AWS_REGION: 'us-east-1'
ENVIRONMENT: 'dev|staging|prod'
```

## Secrets Reference

```bash
# AWS OIDC Roles
AWS_ROLE_DEV
AWS_ROLE_STAGING
AWS_ROLE_PROD

# Third-party Services
INFRACOST_API_KEY

# Optional
SLACK_WEBHOOK_URL
```

## Artifacts Reference

| Workflow | Artifact Name | Contents | Retention |
|----------|---------------|----------|-----------|
| PR Validation | terraform-plan-* | Terraform plans | 30 days |
| PR Validation | tflint-results | TFLint output | 30 days |
| PR Validation | checkov-results | Security scan | 30 days |
| PR Validation | tfsec-results | Security scan | 30 days |
| Deploy * | terraform-outputs-* | TF outputs | 90 days |
| Drift Detection | drift-report-* | Drift analysis | 90 days |
| Drift Detection | drift-summary-report | Summary | 90 days |
| Compliance | compliance-scan-results | Scan results | 90 days |
| Compliance | securityhub-findings-* | AWS findings | 90 days |

## Best Practices Checklist

### Before Creating PR
- [ ] Run `terraform fmt -recursive`
- [ ] Run `terraform validate` locally
- [ ] Test in local/dev environment
- [ ] Document changes in PR description
- [ ] Review security implications
- [ ] Estimate cost impact

### During PR Review
- [ ] All validation checks passed
- [ ] Security scans show no critical issues
- [ ] Terraform plans reviewed for all environments
- [ ] Cost estimates acceptable
- [ ] Documentation updated
- [ ] At least 1 approval from code owner

### Before Production Deployment
- [ ] Successfully deployed to staging
- [ ] Smoke tests passed in staging
- [ ] Rollback plan documented
- [ ] Monitoring dashboards ready
- [ ] Team notified of deployment
- [ ] Change ticket created (if required)

### After Production Deployment
- [ ] Health checks passing
- [ ] Monitor for 15+ minutes
- [ ] Review CloudWatch metrics
- [ ] Check error rates
- [ ] Verify cost impact
- [ ] Update documentation if needed

## Emergency Contacts

```yaml
DevOps Team Lead: @team-lead
On-Call Engineer: See PagerDuty
Security Team: @security-team
Platform Team: @platform-team
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Infracost Documentation](https://www.infracost.io/docs/)
- [GitHub CLI Manual](https://cli.github.com/manual/)
