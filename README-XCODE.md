# Running AI PRD Builder Server in Xcode

## Configuration for Running Without PostgreSQL

If you're running the server from Xcode and don't have PostgreSQL installed, follow these steps:

### 1. Edit the Scheme

1. Open the project in Xcode
2. Select the `Run` scheme from the scheme selector (next to the play/stop buttons)
3. Click "Edit Scheme..." or press `⌘<`

### 2. Set Environment Variables

In the Run scheme configuration:

1. Select the "Run" action on the left
2. Go to the "Arguments" tab
3. In the "Environment Variables" section, add:
   - `SKIP_DATABASE` = `true`
   - `DATABASE_TYPE` = `postgresql`

### 3. Optional: Add AI Provider Keys

If you want to use AI providers, also add:
- `ANTHROPIC_API_KEY` = `your-key-here`
- `OPENAI_API_KEY` = `your-key-here`
- `GEMINI_API_KEY` = `your-key-here`

### 4. Run the Server

Now you can run the server from Xcode (⌘R) and it will use in-memory repositories instead of PostgreSQL.

## Command Line Alternative

You can also run from the command line:

```bash
# Using the provided script
./run-without-db.sh

# Or manually
SKIP_DATABASE=true swift run Run serve --hostname 0.0.0.0 --port 8080
```

## Verify Server is Running

Test the health endpoint:

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "development",
  "timestamp": "2025-09-25T21:45:00Z"
}
```

## Notes

- When using `SKIP_DATABASE=true`, all data is stored in memory and will be lost when the server stops
- This is perfect for development and testing without database dependencies
- For production, ensure PostgreSQL is properly configured and remove `SKIP_DATABASE`