# Fleet Dashboard

Modern web dashboard for visualizing and managing Hyperion fleets.

## Structure

```
fleet-dashboard/
├── src/
│   ├── components/    # React components
│   ├── pages/        # Page components
│   ├── services/     # API services
│   ├── store/        # State management
│   ├── styles/       # CSS/SCSS styles
│   ├── utils/        # Utility functions
│   ├── App.tsx       # Root component
│   └── index.tsx     # Entry point
├── public/           # Static assets
├── package.json      # Dependencies
├── tsconfig.json     # TypeScript config
├── vite.config.ts    # Vite config
└── README.md         # This file
```

## Features

- Real-time fleet monitoring
- Interactive dashboards
- Fleet management operations
- Vehicle tracking and status
- Deployment management
- Metrics and analytics
- Alert management
- User authentication
- Responsive design
- Dark mode support

## Prerequisites

- Node.js >= 18.0
- npm >= 9.0 or yarn >= 1.22

## Development

### Installation

```bash
npm install
```

### Start Development Server

```bash
npm run dev
```

Dashboard available at `http://localhost:5173`

### Environment Variables

Create `.env.local`:

```bash
VITE_API_URL=http://localhost:8080/api/v1
VITE_WS_URL=ws://localhost:8080/ws
VITE_AUTH_DOMAIN=auth.hyperion.example.com
VITE_ENV=development
```

## Building

### Production Build

```bash
npm run build
```

Output in `dist/` directory.

### Preview Production Build

```bash
npm run preview
```

### Type Checking

```bash
npm run type-check
```

### Linting

```bash
npm run lint
npm run lint:fix
```

## Testing

### Unit Tests

```bash
npm run test
```

### Integration Tests

```bash
npm run test:integration
```

### E2E Tests

```bash
npm run test:e2e
```

### Coverage

```bash
npm run test:coverage
```

## Tech Stack

- **Framework**: React 18
- **Build Tool**: Vite
- **Language**: TypeScript
- **UI Library**: Material-UI (MUI)
- **State Management**: Redux Toolkit
- **Routing**: React Router
- **API Client**: Axios
- **Charts**: Recharts
- **Forms**: React Hook Form
- **WebSocket**: Socket.io-client
- **Testing**: Vitest, React Testing Library
- **E2E Testing**: Playwright

## Project Structure

```
src/
├── components/
│   ├── common/          # Reusable components
│   ├── fleet/           # Fleet components
│   ├── vehicle/         # Vehicle components
│   ├── dashboard/       # Dashboard components
│   └── layout/          # Layout components
├── pages/
│   ├── Dashboard/       # Dashboard page
│   ├── Fleets/          # Fleet management
│   ├── Vehicles/        # Vehicle management
│   ├── Deployments/     # Deployment management
│   └── Settings/        # Settings page
├── services/
│   ├── api/            # API client
│   ├── auth/           # Authentication
│   └── websocket/      # WebSocket client
├── store/
│   ├── slices/         # Redux slices
│   └── store.ts        # Redux store
├── hooks/              # Custom React hooks
├── utils/              # Utility functions
├── types/              # TypeScript types
└── styles/             # Global styles
```

## Key Features

### Real-Time Updates

WebSocket connection for live data:

```typescript
// src/services/websocket/websocket.ts
const socket = io(VITE_WS_URL, {
  auth: { token: getAuthToken() }
});

socket.on('fleet:update', (data) => {
  dispatch(updateFleet(data));
});
```

### State Management

Redux Toolkit for state:

```typescript
// src/store/slices/fleetSlice.ts
export const fleetSlice = createSlice({
  name: 'fleet',
  initialState,
  reducers: {
    setFleets: (state, action) => {
      state.fleets = action.payload;
    }
  }
});
```

### API Integration

Axios client for API calls:

```typescript
// src/services/api/fleet.ts
export const getFleets = async () => {
  const response = await apiClient.get('/fleets');
  return response.data;
};
```

## Deployment

### Docker

```bash
# Build image
docker build -t fleet-dashboard:latest .

# Run container
docker run -p 80:80 fleet-dashboard:latest
```

### Nginx

Static files served with Nginx:

```nginx
server {
  listen 80;
  server_name dashboard.hyperion.example.com;

  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /api {
    proxy_pass http://api:8080;
  }
}
```

### CDN Deployment

Deploy to CDN:

```bash
# AWS S3 + CloudFront
aws s3 sync dist/ s3://fleet-dashboard/
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

## Performance

- Code splitting with React.lazy
- Image optimization
- Bundle size optimization
- Service worker for caching
- Lazy loading components
- Memoization with React.memo
- Virtual scrolling for large lists

## Security

- XSS prevention
- CSRF protection
- Content Security Policy
- Secure authentication
- API key management
- Input sanitization
- HTTPS only

## Browser Support

- Chrome >= 90
- Firefox >= 88
- Safari >= 14
- Edge >= 90

## Accessibility

- WCAG 2.1 Level AA compliant
- Keyboard navigation
- Screen reader support
- ARIA labels
- Focus management
- Color contrast

## Best Practices

- Component-based architecture
- TypeScript for type safety
- Consistent code style
- Comprehensive testing
- Error boundaries
- Loading states
- Empty states
- Optimistic updates
- Proper error handling

## Troubleshooting

### Build Issues

```bash
# Clear cache
rm -rf node_modules dist
npm install
npm run build
```

### Development Issues

```bash
# Reset Vite cache
rm -rf node_modules/.vite
npm run dev
```
