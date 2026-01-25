# Multi-Model LLM Integration Research Platform

A research application investigating multi-model Large Language Model integration patterns for intelligent travel planning with real-time map visualization.

**Author:** Thomas Moerman
**Institution Research Project**

---

## Technical Architecture

### Monorepo Structure

```
mono_research/
├── packages/
│   ├── app/              # Flutter iOS client (Dart)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── routes/           # UI pages
│   │   │   │   ├── home_page.dart        # Chat interface
│   │   │   │   ├── map_page.dart         # Mapbox visualization
│   │   │   │   ├── compare_page.dart     # Side-by-side model comparison
│   │   │   │   └── settings_page.dart    # Model selection
│   │   │   ├── services/
│   │   │   │   ├── ai/                   # AI integrations
│   │   │   │   │   ├── ai_service_factory.dart
│   │   │   │   │   ├── rest_ai_service.dart
│   │   │   │   │   └── apple_intelligence_service.dart
│   │   │   │   ├── chat_service.dart
│   │   │   │   ├── firestore_access.dart
│   │   │   │   ├── location_parser.dart
│   │   │   │   └── mapbox_directions_service.dart
│   │   │   ├── widgets/
│   │   │   └── models/
│   │   └── assets/i18n/          # Localization (NL, EN, FR)
│   │
│   └── backend/          # .NET 9 ASP.NET Core API (C#)
│       ├── Program.cs
│       ├── Routes/RouteGroup.cs  # AI model endpoints
│       ├── Services/FirebaseAuthenticationHandler.cs
│       ├── Dockerfile
│       └── logs/
│
├── package.json          # Lerna workspace configuration
└── lerna.json
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Frontend | Flutter 3.10.4+ (Dart) | iOS mobile application |
| Backend | .NET 9 / ASP.NET Core | RESTful API with streaming |
| Authentication | Firebase Auth | JWT-based user management |
| Database | Cloud Firestore | Real-time conversation storage |
| Maps | Mapbox SDK | Geocoding, directions, visualization |
| AI Models | OpenAI, Google GenAI, Apple Intelligence | Multi-model integration |
| Containerization | Docker | Backend deployment |

### AI Model Integration

**GPT-4o-mini (OpenAI)**
- Primary model for structured JSON output
- Fast inference, cost-effective

**Gemini 2.5 Flash (Google)**
- Alternative model for comparative analysis
- Different reasoning patterns

**Hybrid Mode**
- Two-stage pipeline: GPT generates initial response, Gemini refines
- Research focus on quality improvement vs latency trade-off

**Apple Intelligence**
- On-device iOS processing
- Privacy-focused, offline capable

---

## System Requirements

### Development Environment

- macOS with Xcode 15+
- Flutter SDK 3.10.4+
- .NET SDK 9.0
- Node.js 18+ LTS
- iOS Simulator or physical iOS device

### Required API Credentials

This project requires active API keys and service configurations that are not included in the repository:

- OpenAI API key with GPT-4o-mini access
- Google AI Studio API key for Gemini
- Mapbox access token (public and secret)
- Firebase project with Authentication and Firestore enabled
- Firebase service account credentials for backend

### Configuration Files (Not Included)

```
packages/backend/appsettings.Development.json    # API keys
packages/app/.env                                 # Environment variables
packages/app/ios/Runner/GoogleService-Info.plist # Firebase iOS config
packages/app/lib/firebase_options.dart           # Firebase configuration
```

---

## Installation

### 1. Dependencies

```bash
# Root workspace
npm install

# Backend
cd packages/backend
dotnet restore

# Flutter app
cd packages/app
flutter pub get
```

### 2. Backend Configuration

Create `packages/backend/appsettings.Development.json`:

```json
{
  "OpenAIAPIKey": "sk-proj-...",
  "GeminiAPIKey": "...",
  "FirebaseCredentials": { ... },
  "CORS": "*"
}
```

### 3. App Configuration

Create `packages/app/.env`:

```
MAPBOX_ACCESS_TOKEN=pk.eyJ1...
MAPBOX_SECRET_TOKEN=sk.eyJ1...
API_BASE_URL=http://localhost:5005
```

### 4. Firebase Setup

- Configure Firebase project with Authentication (Email/Password)
- Enable Cloud Firestore
- Download `GoogleService-Info.plist` to `packages/app/ios/Runner/`
- Run `flutterfire configure` to generate `firebase_options.dart`

---

## Running the Application

### Development Mode

**Backend:**
```bash
cd packages/backend
dotnet run
# API: http://localhost:5005
# Swagger: http://localhost:5005/swagger/index.html
```

**iOS App:**
```bash
cd packages/app
flutter run
```

**Both (parallel):**
```bash
npm run dev
```

### Docker Deployment

```bash
cd packages/backend
docker build -t mono-research-backend .
docker run -p 5005:5005 mono-research-backend
```

---

## API Reference

### Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/` | Health check | No |
| POST | `/model/gpt` | GPT-4o-mini generation | Required |
| POST | `/model/gemini` | Gemini 2.5 Flash generation | Required |
| POST | `/model/hybrid` | Two-stage GPT→Gemini pipeline | Required |

### Request Format

```json
{
  "message": "Plan a 3-day trip to Paris"
}
```

### Response Format

AI responses contain natural language with embedded JSON for location parsing:

```json
{
  "locations": [
    {
      "name": "Eiffel Tower",
      "lat": 48.8584,
      "lng": 2.2945,
      "description": "Iconic iron lattice tower",
      "day": 1
    }
  ],
  "routeType": "walking"
}
```

---

## Project Features

### Conversation Interface
- Real-time streaming responses with word-by-word display
- Multi-conversation management with Firestore persistence
- Model selection per conversation

### Map Visualization
- Automatic marker placement from AI-generated coordinates
- Multi-stop routing with Mapbox Directions API
- Support for driving, walking, cycling routes
- Camera auto-fitting to display all locations

### Model Comparison
- Side-by-side comparison view for research analysis
- Run identical queries against multiple models
- Export results for empirical evaluation

### Internationalization
- Dutch, English, French language support
- Extensible localization system

---

## Data Collection

Conversations are stored in Firestore with the following schema:

```
conversations/{conversationId}
├── userId: string
├── title: string
├── model: "gpt" | "gemini" | "hybrid" | "apple"
├── createdAt: timestamp
├── updatedAt: timestamp
└── messages: array
    ├── role: "user" | "assistant"
    ├── content: string
    ├── timestamp: timestamp
    └── locations: array (optional)
```

This structure supports research data export for:
- Response time analysis
- Location accuracy verification
- Model output comparison
- Quality metric evaluation


---

## External References

**Frameworks:**
- [Flutter Documentation](https://docs.flutter.dev/)
- [ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/)

**AI APIs:**
- [OpenAI API](https://platform.openai.com/docs/)
- [Google AI for Developers](https://ai.google.dev/docs)

**Services:**
- [Firebase](https://firebase.google.com/docs)
- [Mapbox](https://docs.mapbox.com/)


```
Moerman, T. (2026). Multi-Model LLM Integration Research Platform.
```
