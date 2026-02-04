---
name: Feature Request
about: Suggest an idea for this project
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Feature Description

A clear and concise description of the feature you'd like to see.

## Problem Statement

Describe the problem this feature would solve. Example: "I'm always frustrated when [...]"

## Proposed Solution

Describe the solution you'd like to see implemented. Be as detailed as possible.

## Use Case

Explain the use case for this feature. Who would use it and how?

- **User Persona:** [e.g., DevOps Engineer, System Administrator]
- **Scenario:** Describe a specific scenario where this feature would be valuable
- **Frequency:** How often would this feature be used?

## Expected Behavior

Describe how you expect this feature to work.

## Alternative Solutions

Describe any alternative solutions or features you've considered.

## Infrastructure Impact

What would be the infrastructure impact of this feature?

- [ ] New AWS resources required
- [ ] Changes to existing resources
- [ ] New Terraform module needed
- [ ] Changes to existing modules
- [ ] No infrastructure changes

### Estimated Cost Impact

What is the estimated monthly cost impact of this feature?

- [ ] No cost impact
- [ ] Minimal cost increase (< $10/month)
- [ ] Moderate cost increase ($10-$100/month)
- [ ] Significant cost increase (> $100/month)
- [ ] Cost savings expected

## Technical Considerations

Are there any technical considerations or constraints?

- **AWS Service Limits:** Any relevant service quota considerations?
- **Security:** Any security implications?
- **Compliance:** Any compliance requirements?
- **Performance:** Expected performance impact?
- **Scalability:** How will this scale?

## Implementation Suggestions

If you have ideas on how to implement this, please share:

### Terraform Code Sketch

<details>
<summary>Click to expand proposed implementation</summary>

```hcl
# Paste any code sketches or examples
```

</details>

### Module Structure

Describe how this would fit into the existing module structure.

## Documentation Requirements

What documentation would need to be created or updated?

- [ ] README.md
- [ ] ARCHITECTURE.md
- [ ] Module README
- [ ] Architecture Decision Record (ADR)
- [ ] Examples
- [ ] Other: _____________

## Examples

Provide examples of how this feature would be used.

```hcl
# Example configuration using the proposed feature
module "example" {
  source = "..."

  new_feature_param = "value"
}
```

## Related Features

Are there any related features or issues?

- Related to #(issue number)
- Depends on #(issue number)
- Blocks #(issue number)

## Priority

How important is this feature to you?

- [ ] Critical - Blocking current work
- [ ] High - Would significantly improve workflow
- [ ] Medium - Nice to have
- [ ] Low - Minor improvement

## Additional Context

Add any other context, screenshots, diagrams, or examples about the feature request here.

## Research

Have you found similar features in other projects or tools? Please share references:

- Link 1:
- Link 2:

## Willingness to Contribute

- [ ] I am willing to implement this feature
- [ ] I am willing to help with testing
- [ ] I am willing to help with documentation
- [ ] I can provide feedback during development

## Checklist

- [ ] I have searched for existing feature requests
- [ ] I have clearly described the problem and solution
- [ ] I have considered the infrastructure and cost impact
- [ ] I have provided use cases and examples
- [ ] I have reviewed the project roadmap
