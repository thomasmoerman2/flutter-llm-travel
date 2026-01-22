# Backend API

Minimal API for travel/AI model requests. The API is mounted at runtime by ASP.NET; use your host base URL.

## Requirements
- Configuration keys:
  - `OpenAIAPIKey`: required for `POST /model/gpt`.
  - `GeminiAPIKey`: required for `POST /model/gemini`.
  - `FirebaseCredentials`: optional; only initialized if set.
  - `CORS`: origin list used by the `production` CORS policy.
- Swagger:
  - UI: `/swagger/index.html`
  - JSON: `/swagger/v1/swagger.json`


## Headers
- Common:
  - `Accept: application/json`
- JSON body endpoints:
  - `Content-Type: application/json`
- CORS:
  - Allowed header: `X-MCT-Header` (allowed, not required)

## Authentication
- No authentication middleware is enforced in the current pipeline.

## Endpoints

### `GET /`
Health and docs pointer.

Response example:
```json
{
  "hello": "Hello, Developer",
  "docs": "API Documentation /swagger/index.html",
  "docsJson": "API Documentation /swagger/v1/swagger.json"
}
```

### `GET /model`
List available AI model endpoints.

Response example:
```json
{
  "head": "Here a list of AI models on this project",
  "data": [
    { "endpoints": "/gpt", "provider": "OpenAI", "model": "gpt-4o-mini" },
    { "endpoints": "/gemini", "provider": "Google", "model": "gemini-pro" },
    { "endpoints": "/hybrid", "provider": "Mixed", "model": "Apple Foundation / gpt-4o-mini / gemini-pro" }
  ]
}
```

### `POST /model/gpt`
Send a message to OpenAI.

Request body:
```json
{ "message": "your message" }
```

Success response:
```json
{ "response": "..." }
```

Possible errors:
- `400` invalid JSON or missing/empty `message`
- `500` OpenAI API key not configured
- `503` OpenAI service not reachable
- `504` OpenAI request timed out

### `POST /model/gemini`
Send a message to Gemini.

Request body:
```json
{ "message": "your message" }
```

Success response:
```json
{ "response": { "...": "Gemini response payload" } }
```

Possible errors:
- `400` invalid JSON or missing/empty `message`
- `500` Gemini API key not configured
- `503` Gemini service not reachable
- `504` Gemini request timed out

### `POST /model/hybrid`
Placeholder endpoint. Currently returns `204 No Content`.

### Fallback
Any unknown path returns:
```json
{ "error": "Not found", "status": 404, "path": "/your/path" }
```
