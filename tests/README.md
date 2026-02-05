# Tests

Comprehensive testing suite for the Hyperion Fleet Manager.

## Structure

```
tests/
├── integration/       # Integration tests
├── e2e/              # End-to-end tests
└── performance/      # Performance tests
```

## Test Types

### Integration Tests

Located in `integration/`:

Tests that verify interactions between components:

- API integration with database
- Cache integration
- Message queue integration
- External service integration
- Terraform module integration

### End-to-End Tests

Located in `e2e/`:

Full user workflow tests:

- Complete fleet deployment workflow
- User authentication flow
- Vehicle registration process
- Dashboard interactions
- CLI command execution

### Performance Tests

Located in `performance/`:

Load and performance testing:

- API load tests
- Database query performance
- Cache performance
- Concurrent user simulation
- Stress testing

## Running Tests

### All Tests

```bash
make test
```

### Specific Test Suites

```bash
# Unit tests (in component directories)
make test-unit

# Integration tests
make test-integration

# End-to-end tests
make test-e2e

# Performance tests
make test-performance
```

## Test Framework

### Go Tests

For API and CLI:

```bash
# Run tests
go test ./... -v

# With coverage
go test ./... -cover -coverprofile=coverage.out

# Integration tests
go test -tags=integration ./... -v

# Specific package
go test ./api/src/handlers -v
```

### JavaScript Tests

For dashboard:

```bash
cd web/fleet-dashboard

# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Coverage
npm run test:coverage
```

### Terraform Tests

For infrastructure:

```bash
cd infrastructure

# Validate
terraform validate

# Plan
terraform plan

# Terratest
cd tests
go test -v -timeout 30m
```

## Test Standards

### Test Structure

Follow Arrange-Act-Assert (AAA):

```go
func TestCreateFleet(t *testing.T) {
    // Arrange
    client := NewTestClient()
    fleet := &Fleet{Name: "test-fleet"}
    
    // Act
    result, err := client.CreateFleet(fleet)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, result)
    assert.Equal(t, "test-fleet", result.Name)
}
```

### Test Naming

- Use descriptive test names
- Include what is being tested
- Include expected behavior
- Example: `TestCreateFleet_WithValidData_ReturnsFleet`

### Test Data

- Use test fixtures
- Clean up after tests
- Isolate test data
- Use factories for test objects

## Integration Test Setup

### Prerequisites

```bash
# Docker for test dependencies
docker-compose -f docker-compose.test.yml up -d

# Wait for services
./scripts/wait-for-services.sh
```

### Test Database

```bash
# Create test database
createdb hyperion_test

# Run migrations
go run cmd/migrate/main.go -env=test up
```

### Cleanup

```bash
# Stop test services
docker-compose -f docker-compose.test.yml down

# Drop test database
dropdb hyperion_test
```

## E2E Test Configuration

### Playwright Configuration

```typescript
// playwright.config.ts
export default {
  testDir: './e2e',
  use: {
    baseURL: 'http://localhost:3000',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  }
}
```

### Running E2E Tests

```bash
# Start application
npm run dev

# Run E2E tests
npm run test:e2e

# Run in headed mode
npm run test:e2e -- --headed

# Debug mode
npm run test:e2e -- --debug
```

## Performance Testing

### Load Testing with k6

```javascript
// load-test.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 }
  ]
};

export default function() {
  const res = http.get('http://api/v1/fleets');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500
  });
}
```

Run load test:

```bash
k6 run tests/performance/load-test.js
```

### Artillery Configuration

```yaml
# artillery.yml
config:
  target: 'http://api:8080'
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "Get Fleets"
    flow:
      - get:
          url: "/api/v1/fleets"
```

Run with Artillery:

```bash
artillery run tests/performance/artillery.yml
```

## Test Coverage

### Coverage Goals

- Unit tests: > 80%
- Integration tests: > 60%
- Critical paths: 100%

### Generate Coverage

```bash
# Go coverage
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html

# JavaScript coverage
cd web/fleet-dashboard
npm run test:coverage
```

### Coverage Reports

View coverage:

```bash
# Open HTML report
open coverage.html

# Console summary
go tool cover -func=coverage.out
```

## Continuous Integration

### GitHub Actions

Tests run on:

- Pull requests
- Push to main
- Nightly builds

### Test Matrix

Test across:

- Multiple Go versions
- Multiple Node versions
- Multiple OS (Linux, macOS, Windows)
- Multiple browsers (Chrome, Firefox, Safari)

## Mocking

### HTTP Mocking

```go
// Using httptest
server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(fleet)
}))
defer server.Close()
```

### Database Mocking

```go
// Using sqlmock
db, mock, err := sqlmock.New()
mock.ExpectQuery("SELECT").WillReturnRows(rows)
```

### AWS Mocking

```go
// Using LocalStack
endpoint := "http://localhost:4566"
client := s3.New(session.New(&aws.Config{
    Endpoint: aws.String(endpoint)
}))
```

## Test Utilities

### Test Helpers

Located in `tests/helpers/`:

- Database setup/teardown
- Test data factories
- Mock services
- Assertion helpers

### Fixtures

Located in `tests/fixtures/`:

- Test data files
- Configuration files
- Sample payloads

## Best Practices

- Write tests first (TDD)
- Keep tests independent
- Use descriptive names
- Test edge cases
- Mock external dependencies
- Clean up after tests
- Use table-driven tests
- Avoid test interdependence
- Run tests in parallel where possible
- Maintain test data separately

## Troubleshooting

### Flaky Tests

```bash
# Run test multiple times
go test -count=10 ./...

# Enable verbose output
go test -v ./...
```

### Debugging Tests

```bash
# Go debugging
go test -v -run TestSpecific

# JavaScript debugging
npm run test -- --inspect-brk
```

### CI Failures

- Check test logs
- Verify environment variables
- Check service dependencies
- Review recent changes
- Run tests locally

## Documentation

Document tests with:

- Test purpose
- Prerequisites
- Setup steps
- Expected outcomes
- Known issues
