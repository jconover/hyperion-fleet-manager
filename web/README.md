# Web Applications

Frontend web applications for Hyperion Fleet Manager.

## Structure

```
web/
└── fleet-dashboard/    # Main fleet management dashboard
```

## Fleet Dashboard

React-based web dashboard for fleet visualization and management.

See [fleet-dashboard/README.md](fleet-dashboard/README.md) for detailed documentation.

### Quick Start

```bash
cd web/fleet-dashboard

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

### Features

- Real-time fleet monitoring
- Interactive dashboards
- Fleet and vehicle management
- Deployment management
- Analytics and reporting
- User authentication
- Responsive design

## Technology Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Material-UI** - Component library
- **Redux Toolkit** - State management
- **React Router** - Routing
- **Axios** - HTTP client
- **Socket.io** - WebSocket client

## Development

### Prerequisites

- Node.js >= 18.0
- npm >= 9.0

### Environment Setup

```bash
# Copy environment template
cp .env.example .env.local

# Edit configuration
vim .env.local
```

### Running Locally

```bash
# Development mode
npm run dev

# Production build
npm run build

# Preview production build
npm run preview
```

### Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Coverage
npm run test:coverage
```

## Deployment

### Docker

```bash
# Build image
docker build -t fleet-dashboard:latest .

# Run container
docker run -p 80:80 fleet-dashboard:latest
```

### Static Hosting

```bash
# Build production bundle
npm run build

# Deploy to S3
aws s3 sync dist/ s3://fleet-dashboard/

# Or use CDN
# Files in dist/ directory ready for CDN
```

## Future Applications

Planned web applications:

- **fleet-analytics** - Advanced analytics dashboard
- **fleet-admin** - Administration portal
- **fleet-mobile** - Mobile-optimized interface

## Best Practices

- Component-based architecture
- TypeScript for type safety
- Comprehensive testing
- Responsive design
- Accessibility compliance
- Performance optimization
- Security best practices
- Code splitting
- Lazy loading

## Contributing

To contribute:

1. Follow TypeScript standards
2. Write tests
3. Ensure accessibility
4. Test on multiple browsers
5. Update documentation
