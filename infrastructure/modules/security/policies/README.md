# IAM Policy Templates

This directory contains JSON policy document templates used by the Security Module. These are reference templates showing the structure of policies created by the module.

## Policy Files

### ec2-assume-role-policy.json
**Purpose**: Trust policy for EC2 instances to assume IAM roles

**Key Features**:
- Allows EC2 service to assume the role
- Condition: Source account must match
- Condition: Source ARN must be EC2 instance

**Variables** (replaced at runtime):
- `${account_id}`: AWS account ID
- `${region}`: AWS region

### s3-access-policy.json
**Purpose**: IAM policy for S3 bucket access with KMS encryption

**Permissions**:
- `s3:ListBucket`: List bucket contents
- `s3:GetBucketLocation`: Get bucket region
- `s3:GetObject`: Read objects
- `s3:GetObjectVersion`: Read object versions
- `s3:PutObject`: Write objects
- `s3:DeleteObject`: Delete objects
- `kms:Decrypt`: Decrypt with KMS
- `kms:GenerateDataKey`: Generate data keys

**Variables** (replaced at runtime):
- `${bucket_arns}`: List of S3 bucket ARNs
- `${kms_key_arn}`: KMS key ARN for S3 encryption
- `${region}`: AWS region

### secrets-manager-access-policy.json
**Purpose**: IAM policy for Secrets Manager access with KMS decryption

**Permissions**:
- `secretsmanager:GetSecretValue`: Retrieve secret values
- `secretsmanager:DescribeSecret`: Get secret metadata
- `kms:Decrypt`: Decrypt secret with KMS
- `kms:DescribeKey`: Get KMS key metadata

**Variables** (replaced at runtime):
- `${secret_arn}`: Secrets Manager secret ARN
- `${kms_key_arn}`: KMS key ARN for Secrets Manager
- `${region}`: AWS region

### kms-key-policy-template.json
**Purpose**: Generic KMS key policy template

**Permissions**:
- Root account: Full KMS permissions
- AWS services: Decrypt, GenerateDataKey, CreateGrant, DescribeKey
- Condition: Via specific service only

**Variables** (replaced at runtime):
- `${account_id}`: AWS account ID
- `${service_name}`: AWS service name (ec2, rds, s3, secretsmanager)
- `${region}`: AWS region

## Usage

These templates are for reference only. The actual policies are created by Terraform using `aws_iam_policy_document` data sources in `main.tf`.

### Why Templates?

While Terraform generates these policies dynamically, the templates serve several purposes:

1. **Documentation**: Clear examples of policy structure
2. **Testing**: Can be used for manual policy testing
3. **Compliance**: Easy to review for security audits
4. **Reference**: Helpful when writing custom policies

## Policy Best Practices

### Least Privilege
All policies follow the principle of least privilege:
- Minimal required permissions
- Resource-specific ARNs (no wildcards where possible)
- Conditional statements for additional security

### ViaService Condition
KMS policies use `kms:ViaService` condition to ensure keys can only be used through specific AWS services:

```json
"Condition": {
  "StringEquals": {
    "kms:ViaService": "s3.us-east-1.amazonaws.com"
  }
}
```

### Source Account/ARN Conditions
Assume role policies use source conditions to prevent confused deputy attacks:

```json
"Condition": {
  "StringEquals": {
    "aws:SourceAccount": "123456789012"
  },
  "ArnLike": {
    "aws:SourceArn": "arn:aws:ec2:*:123456789012:instance/*"
  }
}
```

## Testing Policies

To test policies manually:

### Test S3 Policy
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/role-name \
  --action-names s3:GetObject s3:PutObject \
  --resource-arns arn:aws:s3:::bucket-name/*
```

### Test Secrets Manager Policy
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/role-name \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:us-east-1:123456789012:secret:secret-name
```

### Test KMS Policy
```bash
aws kms get-key-policy \
  --key-id alias/key-alias \
  --policy-name default
```

## Policy Validation

Validate JSON syntax:
```bash
for file in *.json; do
  echo "Validating $file..."
  cat "$file" | jq empty || echo "Invalid JSON: $file"
done
```

## References

- [IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
- [IAM JSON Policy Elements](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html)
- [KMS Key Policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)
- [S3 Bucket Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-policies.html)
- [Secrets Manager Policies](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access.html)
- [IAM Policy Simulator](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)
