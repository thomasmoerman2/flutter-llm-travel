# Backend API

Minimal ASP.NET Core API for travel/AI model requests.

## Requirements
- .NET SDK 9.0

## Configuration
The API reads configuration from standard ASP.NET Core sources (appsettings files,
environment variables, etc.). Required keys for the AI endpoints:
- `OpenAIAPIKey` for `POST /model/gpt`
- `GeminiAPIKey` for `POST /model/gemini`
- `FirebaseCredentials` optional JSON string for Firebase Admin
- `CORS` allowed origin list for the `production` CORS policy

For local development you can set these in `appsettings.Development.json` or export
environment variables before running.

Example (macOS/Linux):
```bash
export OpenAIAPIKey="..."
export GeminiAPIKey="..."
export FirebaseCredentials='{"type":"service_account", ...}'
export CORS="http://localhost:3000"
```

## Run locally
From this folder:
```bash
dotnet restore
dotnet run
```

The console output shows the exact URLs (HTTP/HTTPS) the app is listening on.

## Useful URLs
- Health: `/`
- Swagger UI: `/swagger/index.html`
- Swagger JSON: `/swagger/v1/swagger.json`

## Notes
- Logs are written to `logs/log.txt` (rolling daily).
- No authentication middleware is enforced in the current pipeline.
