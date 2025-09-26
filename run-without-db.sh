#!/bin/bash

# Run the Vapor server without database for testing
echo "🚀 Starting AI PRD Builder Server (without database)..."
echo "⚠️  Note: Running without database - persistence features will be disabled"
echo ""

# Set environment variables
export SKIP_DATABASE=true
export DATABASE_TYPE=postgresql  # Still needed for DI container

# Optional: Set AI provider keys if available
# export ANTHROPIC_API_KEY="your-key-here"
# export OPENAI_API_KEY="your-key-here"
# export GEMINI_API_KEY="your-key-here"

# Run the server
echo "Starting server on http://localhost:8080"
swift run Run serve --hostname 0.0.0.0 --port 8080