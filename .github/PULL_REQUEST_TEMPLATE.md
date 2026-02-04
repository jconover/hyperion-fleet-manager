## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

- [ ] New infrastructure resource
- [ ] Update to existing resource
- [ ] Bug fix
- [ ] Configuration change
- [ ] Documentation update
- [ ] Refactoring

## Environments Affected

- [ ] Dev
- [ ] Staging
- [ ] Production

## Changes Made

<!-- List the key changes made in this PR -->

-
-
-

## Terraform Plan Summary

<!-- Will be automatically populated by the PR validation workflow -->

## Security Considerations

<!-- Describe any security implications of these changes -->

- [ ] No new security groups or firewall rules added
- [ ] No sensitive data exposed in outputs
- [ ] IAM policies follow least privilege principle
- [ ] Encryption enabled where applicable
- [ ] No hardcoded credentials or secrets

## Testing

<!-- Describe how these changes have been tested -->

- [ ] Terraform validate passed
- [ ] Terraform plan reviewed
- [ ] Security scans passed (Checkov, tfsec)
- [ ] Manual testing completed (if applicable)
- [ ] Smoke tests defined

## Rollback Plan

<!-- Describe how to rollback these changes if needed -->

## Documentation

- [ ] README updated (if needed)
- [ ] Terraform variables documented
- [ ] Outputs documented
- [ ] Runbook updated (if needed)

## Checklist

- [ ] Code follows project conventions
- [ ] Changes are backward compatible
- [ ] No breaking changes (or documented if unavoidable)
- [ ] Terraform formatting applied (`terraform fmt`)
- [ ] Variable descriptions are clear and complete
- [ ] Resource tags are consistent
- [ ] State file impact considered
- [ ] Cost implications reviewed

## Additional Notes

<!-- Any additional information that reviewers should know -->

## Related Issues

<!-- Link to related issues or tickets -->

Closes #
Related to #

---

**Note:** This PR will trigger automated validation including:
- Terraform format check
- Terraform validate
- TFLint analysis
- Checkov security scan
- tfsec security scan
- PowerShell script analysis
- Terraform plan for all environments
- Cost estimation with Infracost
