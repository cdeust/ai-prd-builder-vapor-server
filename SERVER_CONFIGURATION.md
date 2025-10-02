# Server Configuration Guide

## Port and Host Configuration

The AI PRD Builder Vapor server supports flexible port and host configuration through environment variables.

### Configuration Options

#### 1. Environment Variables (.env.development)

```bash
# Server host (default: 0.0.0.0)
HOST=0.0.0.0

# Server port (default: 8080)
PORT=8080
```

#### 2. Command-line Environment Variables

```bash
# Run on custom port
PORT=3000 swift run

# Run on specific host and port
HOST=127.0.0.1 PORT=9000 swift run

# Production configuration
HOST=0.0.0.0 PORT=80 swift run
```

#### 3. Multiple Environments

Create environment-specific files:

**.env.development** (Development)
```bash
HOST=0.0.0.0
PORT=8080
SUPABASE_URL=https://dev.supabase.co
```

**.env.production** (Production)
```bash
HOST=0.0.0.0
PORT=8080
SUPABASE_URL=https://prod.supabase.co
```

### Default Values

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Listen on all interfaces |
| `PORT` | `8080` | HTTP server port |

### Common Port Configurations

**Development (No Conflicts)**
```bash
PORT=8080  # Default - AI PRD Builder
PORT=3000  # Alternative - Common frontend dev server
PORT=5173  # Vite default
```

**Production**
```bash
PORT=80    # HTTP (requires sudo/admin)
PORT=443   # HTTPS (requires SSL setup)
PORT=8080  # Standard alternative
```

**Docker**
```bash
# docker-compose.yml
ports:
  - "3001:8080"  # Map external 3001 to internal 8080
```

### Verify Configuration

The server logs its configuration on startup:

```
🚀 AI PRD Builder server configured successfully
📊 Database: PostgreSQL
🌐 Server: 0.0.0.0:8080
🔧 Environment: development
```

### Frontend CORS Configuration

If running frontend on a different port, update CORS:

**Sources/App/Configuration/MiddlewareConfigurator.swift**
```swift
let corsConfiguration = CORSMiddleware.Configuration(
    allowedOrigin: .custom("http://localhost:5173"),  // Vite default
    allowedMethods: [.GET, .POST, .PUT, .PATCH, .DELETE, .OPTIONS],
    allowedHeaders: [.accept, .authorization, .contentType, .origin]
)
```

### Troubleshooting

**Port Already in Use**
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=8081 swift run
```

**Cannot Bind to Port 80/443**
```bash
# Option 1: Use sudo (not recommended)
sudo PORT=80 swift run

# Option 2: Use reverse proxy (recommended)
# Nginx/Apache proxy to :8080

# Option 3: Use alternative port
PORT=8080 swift run
```

### Environment Variable Priority

1. **Command-line** (highest priority)
   ```bash
   PORT=9000 swift run
   ```

2. **.env.development** (if exists)
   ```bash
   PORT=8080
   ```

3. **Default values** (lowest priority)
   ```swift
   let port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 8080
   ```

### Testing Different Configurations

```bash
# Test on port 3000
PORT=3000 swift run
curl http://localhost:3000/health

# Test on specific IP
HOST=127.0.0.1 PORT=8080 swift run
curl http://127.0.0.1:8080/health

# Test production-like setup
HOST=0.0.0.0 PORT=8080 swift run
curl http://your-ip:8080/health
```

---

**The server is already fully configurable!** 🎉

Just set `PORT=<your-port>` in `.env.development` or as an environment variable.
