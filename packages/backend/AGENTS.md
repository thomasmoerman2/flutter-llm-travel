# Repository Guidelines

## Project Structure & Module Organization
- `Program.cs` hosts the minimal API setup, middleware, and route registration.
- `Routes/` groups endpoint mappings (versioned route groups).
- `Services/`, `Repositories/`, and `Context/` contain business logic, data access, and MongoDB context abstractions.
- `Models/`, `DTO/`, and `Validators/` define data shapes and FluentValidation rules.
- `Exceptions/` and `Globals.cs` hold shared errors and constants.
- `Tests/test.http` is a manual API test collection for REST clients.
- `Properties/launchSettings.json` defines local dev profiles and ports.

## Build, Test, and Development Commands
- `dotnet restore` installs NuGet dependencies.
- `dotnet build` compiles the backend (`net9.0`).
- `dotnet run --launch-profile http` runs the API on `http://localhost:5189` (see `Properties/launchSettings.json`).
- `dotnet watch run` enables hot reload during development.
- `dotnet test` is standard, but there is no test project yet; use `Tests/test.http` for now.

## Coding Style & Naming Conventions
- Use .NET conventions: 4-space indentation, braces on new lines, and one type per file.
- Naming: `PascalCase` for types and public members, `camelCase` for locals/parameters, and `I`-prefixed interfaces (e.g., `IMongoContext`).
- Keep routes and services small and cohesive; add validators in `Validators/` when adding new DTOs.
- Prefer structured logging with Serilog (`logger.LogInformation("Message {Field}", value)`).

## Testing Guidelines
- Manual API checks live in `Tests/test.http` (VS Code REST Client or similar).
- If you add automated tests, place them in a new `<Project>.Tests` project and name files `*Tests.cs`.

## Commit & Pull Request Guidelines
- Commit history uses short, lowercase subjects; `feat:` appears in existing commits.
- Prefer conventional-style prefixes (`feat:`, `fix:`, `chore:`) with concise imperative subjects.
- PRs should include: a clear summary, testing steps/outputs, and links to related issues.
- Call out configuration changes (e.g., `appsettings.Development.json`) explicitly in the PR description.

## Configuration & Security Tips
- MongoDB settings are defined in `appsettings.Development.json`; replace placeholders locally.
- Do not commit secrets; use user-secrets or environment variables for credentials.
