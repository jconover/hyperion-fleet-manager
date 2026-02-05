# API

RESTful API service for fleet management operations.

## Structure

```
api/
├── src/                # Source code
│   ├── handlers/      # HTTP request handlers
│   ├── models/        # Data models
│   ├── services/      # Business logic
│   ├── middleware/    # HTTP middleware
│   ├── config/        # Configuration
│   └── utils/         # Utility functions
├── tests/             # API tests
├── docs/              # API documentation
├── go.mod             # Go module definition
├── go.sum             # Go dependencies
├── Dockerfile         # Container image
└── README.md          # This file
```

## Endpoints

### Fleet Operations

```
GET    /api/v1/fleets              # List all fleets
GET    /api/v1/fleets/:id          # Get fleet details
POST   /api/v1/fleets              # Create new fleet
PUT    /api/v1/fleets/:id          # Update fleet
DELETE /api/v1/fleets/:id          # Delete fleet
```

### Vehicle Management

```
GET    /api/v1/vehicles            # List vehicles
GET    /api/v1/vehicles/:id        # Get vehicle details
POST   /api/v1/vehicles            # Register vehicle
PUT    /api/v1/vehicles/:id        # Update vehicle
DELETE /api/v1/vehicles/:id        # Remove vehicle
```

### Health and Monitoring

```
GET    /api/v1/health              # Health check
GET    /api/v1/metrics             # Prometheus metrics
GET    /api/v1/status              # System status
```

## Development

### Prerequisites

- Go 1.21 or later
- PostgreSQL 15
- Redis 7
- Docker

### Local Setup

```bash
# Install dependencies
go mod download

# Run database migrations
go run cmd/migrate/main.go up

# Start API server
go run cmd/api/main.go
```

### Configuration

Configure via environment variables or `.env` file:

```bash
API_PORT=8080
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hyperion
DB_USER=postgres
DB_PASSWORD=secret
REDIS_HOST=localhost
REDIS_PORT=6379
LOG_LEVEL=info
```

### Running Tests

```bash
# Unit tests
go test ./... -v

# Integration tests
go test ./... -tags=integration -v

# Coverage
go test ./... -cover -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### Building

```bash
# Build binary
go build -o bin/api cmd/api/main.go

# Build Docker image
docker build -t hyperion-api:latest .

# Run container
docker run -p 8080:8080 hyperion-api:latest
```

## API Documentation

Interactive API documentation available at:

- Swagger UI: `http://localhost:8080/swagger`
- ReDoc: `http://localhost:8080/redoc`
- OpenAPI spec: `http://localhost:8080/openapi.json`

## Authentication

API uses JWT tokens for authentication:

```bash
# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"secret"}'

# Use token
curl http://localhost:8080/api/v1/fleets \
  -H "Authorization: Bearer <token>"
```

## Rate Limiting

Rate limits enforced per API key:

- 1000 requests per hour
- 100 requests per minute
- Configurable per endpoint

## Error Handling

Standard error response format:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Fleet not found",
    "details": {
      "fleet_id": "123"
    }
  }
}
```

## Monitoring

- Prometheus metrics at `/metrics`
- Health check at `/health`
- Structured logging with correlation IDs
- Distributed tracing with OpenTelemetry

## Security

- HTTPS only in production
- JWT authentication
- API key authentication
- Rate limiting
- Input validation
- SQL injection prevention
- XSS protection
- CORS configuration

## Performance

- Connection pooling
- Redis caching
- Database query optimization
- Gzip compression
- Async processing for long operations

## Deployment

### Docker

```bash
docker build -t hyperion-api:v1.0.0 .
docker push hyperion-api:v1.0.0
```

### Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

## Best Practices

- Use context for request scoping
- Implement graceful shutdown
- Log with structured format
- Use middleware for cross-cutting concerns
- Validate input thoroughly
- Handle errors consistently
- Document all endpoints
- Version the API
- Use dependency injection
- Write comprehensive tests
