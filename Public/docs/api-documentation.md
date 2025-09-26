# AI PRD Builder API Documentation

## Overview

The AI PRD Builder API provides endpoints for generating Product Requirements Documents (PRDs) using the complete **ai-orchestrator** Swift CLI system. The API supports multiple AI providers including Apple Intelligence (on-device), Anthropic Claude, OpenAI GPT, and Google Gemini with intelligent fallback. The API follows RESTful principles and supports real-time updates via WebSockets.

### Key Features

- 🍎 **Apple Intelligence Integration**: Privacy-first on-device PRD generation
- 🔄 **Multi-Provider Fallback**: Automatic failover between providers
- 🎯 **ai-orchestrator System**: Full access to advanced reasoning and thinking frameworks
- ⚡ **Real-time WebSocket**: Interactive clarifications and status updates
- 🏛️ **Clean Architecture**: SOLID principles with separated controllers
- 📊 **Flexible Database**: PostgreSQL, Supabase, or MongoDB support

## Base URL

```
https://your-domain.com/api/v1
```

## Authentication

Currently, authentication is handled at the application level. Future versions will include JWT-based authentication.

## Content Type

All requests and responses use `application/json` content type with `snake_case` key formatting.

## Error Handling

The API returns structured error responses:

```json
{
  "error": {
    "code": "validation",
    "message": "Description is required",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `404` - Not Found
- `422` - Unprocessable Entity (business rule violation)
- `429` - Rate Limited
- `500` - Internal Server Error

## Endpoints

### PRD Generation

#### 1.1 Generate PRD

Generate a comprehensive PRD from requirements using ai-orchestrator.

**POST** `/api/v1/prd/generate`

#### Request Body

```json
{
  "title": "User Authentication System",
  "description": "Implement secure user registration and login functionality with multi-factor authentication support.",
  "mockup_sources": [
    {
      "type": "wireframe",
      "url": "https://example.com/mockup.png",
      "content": "Login page wireframe with email/password fields"
    }
  ],
  "priority": "high",
  "preferred_provider": "anthropic",
  "options": {
    "include_test_cases": true,
    "include_api_spec": true,
    "include_technical_details": true,
    "max_sections": 10,
    "target_audience": "technical",
    "custom_prompt": "Focus on security best practices"
  }
}
```

#### Response

```json
{
  "request_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "completed",
  "message": "PRD generated successfully.",
  "analysis": {
    "confidence": 85,
    "clarifications_needed": [],
    "assumptions": [
      "Users will access the system via web browser",
      "Email will be the primary authentication method"
    ],
    "gaps": []
  },
  "document": {
    "id": "456e7890-e89b-12d3-a456-426614174001",
    "request_id": "123e4567-e89b-12d3-a456-426614174000",
    "title": "User Authentication System",
    "content": "# User Authentication System PRD\n\n## Executive Summary\n...",
    "sections": [
      {
        "id": "789e0123-e89b-12d3-a456-426614174002",
        "title": "Executive Summary",
        "content": "This document outlines...",
        "order": 1,
        "section_type": "executive_summary"
      }
    ],
    "metadata": {
      "format": "markdown",
      "language": "en",
      "word_count": 2500,
      "estimated_read_time": 13,
      "tags": [],
      "attachments": []
    },
    "generated_at": "2024-01-15T10:30:00Z",
    "generated_by": "anthropic",
    "confidence": 0.85,
    "version": 1
  }
}
```

#### 1.2 Generate PRD Interactively

Generate PRD with interactive clarifications support.

**POST** `/api/v1/prd/generate/interactive`

Same request/response format as `/prd/generate` but optimized for WebSocket-based clarification flow.

#### 1.3 Generate with Specific Provider

Generate PRD using a specific AI provider.

**POST** `/api/v1/prd/generate/provider/{providerName}`

**Path Parameters:**
- `providerName`: Provider identifier (`anthropic`, `openai`, `gemini`, `apple`)

### 2. Requirements Analysis

#### 2.1 Analyze Requirements

Analyze requirements without generating a full PRD.

**POST** `/api/v1/prd/analyze`

#### Request Body

```json
{
  "description": "Build a mobile app for food delivery",
  "mockup_sources": [
    {
      "type": "screenshot",
      "url": "https://example.com/app-mockup.png"
    }
  ]
}
```

#### Response

```json
{
  "confidence": 60,
  "clarifications_needed": [
    "Which platforms should the mobile app support?",
    "What payment methods should be integrated?",
    "Do you need real-time order tracking?"
  ],
  "assumptions": [
    "App will connect to restaurant partners",
    "Users need account creation functionality"
  ],
  "gaps": [
    "Business model details",
    "Technical architecture preferences"
  ]
}
```

### 3. PRD Management

#### 3.1 Get Generation Status

Check the status of a PRD generation request.

**GET** `/api/v1/prd/{requestId}/status`

#### Response

```json
{
  "request_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "progress": 75,
  "document": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:32:30Z",
  "completed_at": null
}
```

#### 3.2 List PRD Requests

Get a paginated list of PRD requests for the current user.

**GET** `/api/v1/prd/requests?limit=20&offset=0`

#### Response

```json
{
  "requests": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "User Authentication System",
      "status": "completed",
      "priority": "high",
      "created_at": "2024-01-15T10:30:00Z",
      "completed_at": "2024-01-15T10:35:00Z"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 1
  }
}
```

#### 3.3 Export PRD Document

Export a generated PRD in various formats.

**GET** `/api/v1/prd/documents/{documentId}/export?format=markdown`

#### Query Parameters

- `format`: Export format (`markdown`, `html`, `pdf`, `docx`, `json`)

#### Response

Returns the document content with appropriate content-type headers for download.

### 4. AI Provider Management

#### 4.1 Get Available Providers

List all available AI providers and their capabilities.

**GET** `/api/v1/prd/providers`

#### Response

```json
{
  "providers": [
    {
      "name": "apple",
      "isAvailable": true,
      "priority": 200,
      "capabilities": ["text-generation", "on-device", "privacy-first"],
      "lastUsed": null
    },
    {
      "name": "anthropic",
      "isAvailable": true,
      "priority": 100,
      "capabilities": ["text-generation", "analysis", "long-context"],
      "lastUsed": "2025-01-15T10:30:00Z"
    }
  ]
}
```

#### 4.2 Get Provider Status

Get health and performance metrics for all providers.

**GET** `/api/v1/prd/providers/status`

#### Response

```json
{
  "providers": {
    "apple": {
      "isHealthy": true,
      "lastChecked": "2025-01-15T10:35:00Z",
      "failureCount": 0,
      "avgResponseTime": 0.8
    },
    "anthropic": {
      "isHealthy": true,
      "lastChecked": "2025-01-15T10:35:00Z",
      "failureCount": 0,
      "avgResponseTime": 2.3
    }
  }
}
```

### 5. WebSocket Real-time Updates

#### 5.1 Status Updates WebSocket

Connect to WebSocket for real-time generation updates.

**WebSocket** `/api/v1/prd/ws/{requestId}`

Connects to receive real-time status updates for a specific PRD generation request.

#### Messages

**Status Update (Server → Client):**
```json
{
  "request_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "progress": 50,
  "message": "Analyzing requirements..."
}
```

**Clarification Request (Server → Client):**
```json
{
  "type": "clarification",
  "questions": [
    "Which user roles should the system support?",
    "What are the password complexity requirements?"
  ]
}
```

**Clarification Response (Client → Server):**
```json
{
  "type": "clarification_answers",
  "answers": [
    "Support admin, manager, and regular user roles",
    "Minimum 8 characters with uppercase, lowercase, numbers, and symbols"
  ]
}
```

#### 5.2 Interactive Generation WebSocket

**WebSocket** `/api/v1/prd/ws/interactive/{requestId}`

Connects for interactive PRD generation with bidirectional communication.

**Start Generation (Client → Server):**
```json
{
  "type": "start_generation",
  "generateCommand": {
    "requestId": "123e4567-e89b-12d3-a456-426614174000",
    "title": "Feature Title",
    "description": "Feature description...",
    "mockupSources": [],
    "priority": "high"
  }
}
```

**Generation Complete (Server → Client):**
```json
{
  "type": "generation_complete",
  "result": {
    "id": "456e7890-e89b-12d3-a456-426614174001",
    "title": "Generated PRD",
    "content": "# Executive Summary\n...",
    "sections": [...],
    "confidence": 0.92
  }
}
```

## Data Models

### MockupSource

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Type of mockup (`wireframe`, `screenshot`, `prototype`, `sketch`) |
| `url` | string? | URL to the mockup resource |
| `local_path` | string? | Local file path |
| `content` | string? | Description or content |

### Priority

Enum values: `low`, `medium`, `high`, `critical`

### RequestStatus

Enum values: `pending`, `processing`, `completed`, `failed`

### DocumentFormat

Enum values: `markdown`, `html`, `pdf`, `docx`, `json`

### SectionType

Enum values:
- `executive_summary`
- `problem_statement`
- `user_stories`
- `functional_requirements`
- `non_functional_requirements`
- `technical_requirements`
- `acceptance_criteria`
- `timeline`
- `risks`
- `appendix`

## Rate Limits

| Endpoint | Rate Limit |
|----------|------------|
| `/prd/generate` | 10 requests per hour |
| `/prd/analyze` | 50 requests per hour |
| All other endpoints | 100 requests per hour |

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_TYPE` | Database type (`postgresql`, `supabase`, `mongodb`) | `postgresql` |
| `DATABASE_URL` | PostgreSQL connection string | - |
| `SUPABASE_URL` | Supabase project URL | - |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | - |
| `MONGODB_CONNECTION_STRING` | MongoDB connection string | - |
| `MONGODB_DATABASE` | MongoDB database name | `ai_prd_builder` |
| `ANTHROPIC_API_KEY` | Anthropic API key (fallback) | - |
| `OPENAI_API_KEY` | OpenAI API key (optional) | - |
| `GEMINI_API_KEY` | Google Gemini API key (optional) | - |
| `SKIP_DATABASE` | Skip database setup for testing | `false` |
| `PORT` | Server port | 8080 |

## Health Check

**GET** `/health`

Returns server health status:

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "environment": "production"
}
```

## Example Workflows

### 1. Simple PRD Generation

```bash
# Generate PRD
curl -X POST https://api.example.com/api/v1/prd/generate \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Chat Feature",
    "description": "Add real-time messaging to the app"
  }'

# Response includes request_id and either completed PRD or clarification needs
```

### 2. Interactive PRD Generation with Clarifications

```bash
# 1. Start generation
curl -X POST https://api.example.com/api/v1/prd/generate \
  -H "Content-Type: application/json" \
  -d '{"title": "E-commerce Platform", "description": "Build online store"}'

# 2. Response indicates clarifications needed
# 3. Connect to WebSocket for interactive clarification
# 4. Provide answers through WebSocket
# 5. Receive completed PRD
```

### 3. Batch Analysis

```bash
# Analyze multiple requirements
for desc in "Feature A" "Feature B" "Feature C"; do
  curl -X POST https://api.example.com/api/v1/prd/analyze \
    -H "Content-Type: application/json" \
    -d "{\"description\": \"$desc\"}"
done
```

## Support

For API support, please:
1. Check this documentation
2. Review the health endpoint
3. Contact the development team with request IDs for debugging

## Changelog

### v1.0.0 (Current)
- ✅ ai-orchestrator Swift CLI system integration
- ✅ Apple Intelligence (on-device) support
- ✅ Multi-provider fallback (Anthropic, OpenAI, Gemini)
- ✅ Clean Architecture with SOLID principles
- ✅ Split controllers (Generation, Management, Provider, WebSocket)
- ✅ WebSocket support for real-time updates and interactive clarifications
- ✅ Multiple database support (PostgreSQL, Supabase, MongoDB)
- ✅ Export functionality for multiple formats
- ✅ Comprehensive error handling with DomainErrorMiddleware
- ✅ Async/await throughout with modern Swift concurrency