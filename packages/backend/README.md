# Backend API Guide

This document summarizes the REST endpoints exposed by the backend service and the payloads they expect. Share this with teammates who integrate Flutter or other clients.

## Base URL
- REST: `http://localhost:5189`

## REST Endpoints
System
- `GET /` -> "Hello World!" (health check placeholder)
- `GET /health` -> health status JSON
- `GET /health-ui` -> health checks dashboard
- `GET /health-ui-api` -> health UI API

API (versioned)
- `GET /api/v1/data`
- `GET /api/v1/countries`
- `POST /api/v1/countries`
- `PUT /api/v1/countries/{id}`
- `DELETE /api/v1/countries/{id}`
- `GET /api/v2/data`

## LLM API Endpoints
- `POST /api/ai/chatgpt`
- `POST /api/ai/gemini`
- `POST /api/ai/hybrid`

Request body (JSON):
```json
{
  "prompt": "Plan a 2-day Tokyo trip",
  "model": "gpt-4o",
  "systemPrompt": "You are a travel planner",
  "sessionId": "abc123"
}
```
Notes:
- `model` is optional and provider-specific.
- `sessionId` is optional; the server generates one if omitted.

Response body (JSON):
```json
{
  "provider": "chatgpt",
  "sessionId": "abc123",
  "content": "..."
}
```

## Conversation Context
- No server-side history is stored currently.
- If you need context, send it from the client (e.g., prepend a summary in `systemPrompt`).

## Configuration
Required for production:
- `FirebaseCredentials` (JSON string, loaded from environment)

Required for LLM providers:
- `OpenAiApiKey`
- `GeminiApiKey`

Optional:
- `OpenAiModel` (default: `gpt-4o`)
- `GeminiModel` (default: `gemini-2.0-flash`)
- `FoundationPrompt` (prefix used in hybrid mode)

## Notes
- Firebase auth is initialized but not enforced on endpoints yet.
