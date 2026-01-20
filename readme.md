# AI-Powered Travel Planning Research Platform

> An iOS research application exploring multi-model LLM integration for intelligent travel planning with real-time map visualization

[![Flutter](https://img.shields.io/badge/Flutter-3.10.4+-02569B?logo=flutter)](https://flutter.dev)
[![iOS](https://img.shields.io/badge/Platform-iOS-000000?logo=apple)](https://developer.apple.com)
[![.NET](https://img.shields.io/badge/.NET-9.0-512BD4?logo=.net)](https://dotnet.microsoft.com)

**Author:** Thomas Moerman
**Version:** 0.0.1
**Repository:** [github.com/thomasmoerman2/mono_research](https://github.com/thomasmoerman2/mono_research)

---

> **🍎 Platform Note**: This project is currently built for **iOS only**. macOS with Xcode is required for development. While the project uses Flutter (which supports multiple platforms), extending to Android or web would require code modifications and additional platform-specific configurations.

---

## Quick Links

### 📚 Documentation

**English:**
- 📦 **[Installation Guide](INSTALLATION.md)** - Complete setup instructions with prerequisites and API keys
- 📖 **[User Guide](USER_GUIDE.md)** - How to use the app for research, development, and presentations

**Nederlands:**
- 📦 **[Installatiehandleiding](INSTALLATION_NL.md)** - Volledige installatie-instructies met vereisten en API keys
- 📖 **[Gebruikershandleiding](USER_GUIDE_NL.md)** - Hoe de app te gebruiken voor onderzoek, ontwikkeling en presentaties

---

## Table of Contents

- [Research Context](#research-context)
- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [API Endpoints Reference](#api-endpoints-reference)
- [Research Methodology](#research-methodology)
- [Contributing](#contributing)
- [References](#references)
- [Acknowledgments](#acknowledgments)

---

## Research Context

### What Problem Does This Explore?

This project investigates **multi-model Large Language Model (LLM) integration patterns** for practical applications, specifically in the domain of intelligent travel planning. As LLMs from different providers (OpenAI, Google, Apple) exhibit varying strengths in reasoning, creativity, and factual accuracy, this research explores:

1. **Model Comparison**: How do different LLMs structure travel recommendations and location data?
2. **Hybrid Processing**: Can combining multiple models in a pipeline improve output quality?
3. **Cloud vs On-Device AI**: What are the architectural patterns for integrating cloud-based and on-device AI in iOS applications?
4. **Real-World Usability**: How do streaming responses and map visualization enhance the user experience of AI-generated recommendations?

### Why Multiple AI Models?

**GPT-4o-mini (OpenAI)**: Fast, cost-effective, excellent at structured output (JSON), strong baseline performance.

**Gemini 2.5 Flash (Google)**: Alternative reasoning approach, different training data, provides comparative perspective.

**Hybrid Mode**: Two-stage processing where GPT generates initial recommendations and Gemini refines/enhances them, combining strengths of both models.

**Apple Intelligence**: On-device processing for privacy-conscious scenarios and offline capability (iOS only).

### Expected Outcomes

- Empirical comparison of LLM performance in travel planning tasks
- Validated architectural patterns for multi-model integration
- Insights into hybrid processing benefits and trade-offs
- Reference implementation for researchers building similar systems

### Use Cases

- **Academic Research**: Study LLM behavior, comparison methodologies, user interaction patterns
- **Educational**: Learn iOS development with Flutter, API integration, modern mobile architecture
- **Presentations**: Demonstrate practical AI integration in real-world applications
- **Prototyping**: Foundation for commercial travel planning or recommendation systems

> **Note**: While the project is currently built for iOS, the Flutter framework allows for future extension to Android and web platforms with code modifications.

---

## Architecture Overview

### Monorepo Structure

This project uses a **monorepo architecture** managed by Lerna and npm workspaces, enabling coordinated development of frontend and backend with shared tooling:

```
mono_research/
├── packages/
│   ├── app/              # Flutter iOS client (Dart)
│   │   ├── lib/
│   │   │   ├── main.dart              # Entry point, auth guard
│   │   │   ├── routes/                # UI pages (login, home, map, settings)
│   │   │   ├── services/              # Business logic layer
│   │   │   │   ├── ai/                # AI model integrations
│   │   │   │   ├── auth_service.dart  # Firebase authentication
│   │   │   │   ├── chat_service.dart  # Conversation management
│   │   │   │   └── firestore_access.dart
│   │   │   ├── widgets/               # Reusable UI components
│   │   │   └── models/                # Data classes
│   │   ├── assets/
│   │   │   ├── i18n/                  # Localization (NL, EN, FR)
│   │   │   └── .env                   # Environment configuration
│   │   └── package.json
│   │
│   └── backend/          # .NET 9 ASP.NET Core API (C#)
│       ├── Program.cs                 # App configuration, CORS, auth
│       ├── Routes/
│       │   └── RouteGroup.cs          # AI model endpoints
│       ├── Services/
│       │   └── FirebaseAuthenticationHandler.cs
│       ├── appsettings.json           # Production config
│       ├── appsettings.Development.json # API keys (git-ignored)
│       ├── logs/                      # Rolling log files
│       └── backend.csproj
│
├── package.json          # Root workspace, Lerna scripts
├── lerna.json           # Monorepo configuration
├── readme.md            # This file
└── node_modules/        # Shared dependencies
```

**Why Monorepo?**
- **Unified versioning**: Frontend and backend stay in sync
- **Shared tooling**: Single npm install, coordinated build scripts
- **Easier refactoring**: Changes across packages in single commit
- **Simplified CI/CD**: Single repository to clone and deploy

### Technology Stack

| Layer | Technology | Purpose | Key Libraries |
|-------|-----------|---------|---------------|
| **Frontend** | Flutter 3.10.4+ | iOS mobile UI (extensible to Android/Web) | `mapbox_maps_flutter`, `firebase_auth`, `cloud_firestore` |
| **Backend** | .NET 9 / ASP.NET Core | RESTful API server | `OpenAI` SDK, `Google.GenAI`, `FirebaseAdmin` |
| **Authentication** | Firebase Auth | User management, JWT tokens | `firebase_auth`, `Microsoft.AspNetCore.Authentication.JwtBearer` |
| **Database** | Cloud Firestore | Real-time conversation storage | `cloud_firestore`, Firestore SDK |
| **Maps** | Mapbox | Mapping, geocoding, routing | `mapbox_maps_flutter`, Mapbox APIs |
| **AI Models** | OpenAI GPT, Google Gemini | Natural language processing | `OpenAI` NuGet, `Google.GenAI` NuGet |
| **Monorepo** | Lerna + npm workspaces | Package management | `lerna` 9.0.3 |
| **Logging** | Serilog | Structured logging | `Serilog.AspNetCore` |
| **API Docs** | Swagger / OpenAPI | Interactive API documentation | `Swashbuckle.AspNetCore` |

### Component Interaction Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App (Dart)                       │
│  ┌─────────────┐   ┌──────────────┐   ┌───────────────────┐   │
│  │  UI Layer   │   │ Service Layer│   │  Data Models      │   │
│  │ (routes/)   │──▶│ (services/)  │──▶│ (ChatMessage)     │   │
│  └─────────────┘   └──────────────┘   └───────────────────┘   │
│         │                  │                      │             │
│         │                  ▼                      ▼             │
│         │         ┌─────────────────┐   ┌─────────────────┐   │
│         │         │ AIServiceFactory│   │ Firestore Access│   │
│         │         │  (model select) │   │  (persistence)  │   │
│         │         └─────────────────┘   └─────────────────┘   │
│         │                  │                      │             │
└─────────┼──────────────────┼──────────────────────┼─────────────┘
          │                  │                      │
          │                  ▼                      ▼
          │         ┌─────────────────┐   ┌─────────────────┐
          │         │  REST HTTP/WS   │   │  Firebase SDK   │
          │         └─────────────────┘   └─────────────────┘
          │                  │                      │
          ▼                  ▼                      ▼
┌─────────────────┐  ┌──────────────────────────────────────────┐
│   Mapbox API    │  │        .NET Backend (C#)                 │
│  - Geocoding    │  │  ┌────────────────────────────────────┐ │
│  - Directions   │  │  │  RouteGroup.cs                     │ │
│  - Maps SDK     │  │  │  - POST /model/gpt                 │ │
└─────────────────┘  │  │  - POST /model/gemini              │ │
                     │  │  - POST /model/hybrid              │ │
                     │  └────────────────────────────────────┘ │
                     │           │              │               │
                     │           ▼              ▼               │
                     │  ┌──────────────┐  ┌─────────────────┐ │
                     │  │ OpenAI SDK   │  │ Google.GenAI SDK│ │
                     │  └──────────────┘  └─────────────────┘ │
                     │           │              │               │
                     └───────────┼──────────────┼───────────────┘
                                 │              │
                                 ▼              ▼
                        ┌────────────────────────────┐
                        │   External AI APIs         │
                        │  - OpenAI GPT-4o-mini      │
                        │  - Google Gemini 2.5 Flash │
                        └────────────────────────────┘
```

### AI Integration Patterns

#### Factory Pattern for Model Selection

The `AIServiceFactory` (packages/app/lib/services/ai/ai_service_factory.dart) implements the **Factory Design Pattern** to dynamically instantiate AI service implementations based on user selection:

```dart
// Simplified conceptual example
abstract class AIService {
  Stream<String> sendMessage(String message, String conversationId);
}

class AIServiceFactory {
  static AIService create(String modelType) {
    switch (modelType) {
      case 'gpt': return RestAIService('/model/gpt');
      case 'gemini': return RestAIService('/model/gemini');
      case 'hybrid': return RestAIService('/model/hybrid');
      case 'apple': return AppleIntelligenceService();
      default: return RestAIService('/model/gpt');
    }
  }
}
```

**Benefits:**
- Decoupling: UI doesn't need to know implementation details
- Extensibility: Add new models without changing existing code
- Testability: Easy to mock services for unit testing

#### Hybrid Processing Pipeline

The hybrid endpoint (`/model/hybrid`) demonstrates a **two-stage processing pipeline**:

1. **Stage 1 (GPT-4o-mini)**: Generate initial travel recommendations with structured location data
2. **Stage 2 (Gemini 2.5 Flash)**: Enhance and refine the GPT response with additional context and verification

**Implementation** (packages/backend/Routes/RouteGroup.cs:hybrid endpoint):

```csharp
// Stage 1: GPT generates baseline
var gptResponse = await gptClient.CompleteAsync(userMessage, systemPrompt);

// Stage 2: Gemini refines with GPT output as context
var geminiPrompt = $"Previous AI response: {gptResponse}\nEnhance this...";
var finalResponse = await geminiClient.CompleteAsync(geminiPrompt);
```

**Research Value**: Compare single-model vs hybrid-model output quality, accuracy, and coherence.

#### Streaming Response Handling

Real-time word-by-word streaming enhances perceived responsiveness:

```dart
// packages/app/lib/services/chat_service.dart
Stream<String> streamResponse = aiService.sendMessage(message, conversationId);

await for (String word in streamResponse) {
  // Update UI incrementally, creating typewriter effect
  currentResponse += word;
  notifyListeners();
}
```

**Backend** uses Server-Sent Events (SSE) or chunked transfer encoding to stream tokens as they're generated by the AI model.

---

## Key Features

### AI-Powered Conversational Interface
- Multi-model support (GPT, Gemini, Hybrid, Apple Intelligence)
- Real-time streaming responses with word-by-word display
- Conversation persistence in Firestore with real-time sync
- Multi-conversation management (create, switch, delete)
- Structured JSON extraction from natural language responses

### Intelligent Map Visualization
- Automatic location marker placement from AI responses
- Multi-stop routing with Mapbox Directions API (driving, walking, cycling)
- Interactive search and geocoding
- Camera auto-fitting to display all locations
- Route visualization with polylines

### iOS-Focused Design
- Built specifically for iOS with Cupertino design system
- Platform-specific optimizations (Apple Intelligence, native frameworks)
- Extensible Flutter architecture allows future Android/Web support with modifications
- Responsive UI adapting to different iPhone and iPad screen sizes

### Authentication & Security
- Firebase Authentication with email/password
- JWT-based API authentication
- Protected routes and auth state management
- Secure API key management via environment variables

### Offline Capabilities
- Local conversation caching
- Offline storage service with sync when online
- Graceful degradation when network unavailable

### Internationalization
- Multi-language support (Dutch, English, French)
- Easy localization with `easy_localization` package

---

## Quick Start

### Prerequisites

> **📦 Complete setup instructions**: See **[INSTALLATION.md](INSTALLATION.md)** for detailed prerequisites, API keys, and step-by-step installation.

**Required (macOS only):**
- macOS with Xcode 13+
- Flutter SDK 3.10.4+
- .NET SDK 9.0
- Node.js 18+ LTS

**Required API Keys:**
- OpenAI API key (GPT-4o-mini)
- Google Gemini API key
- Mapbox access token
- Firebase project with Auth & Firestore

### Installation Summary

```bash
# 1. Clone repository
git clone https://github.com/thomasmoerman2/mono_research.git
cd mono_research

# 2. Install dependencies
npm install                          # Root (Lerna)
cd packages/backend && dotnet restore  # Backend
cd ../app && flutter pub get         # Flutter app

# 3. Configure API keys (see INSTALLATION.md for details)
# - Create packages/backend/appsettings.Development.json
# - Create packages/app/.env
# - Add Firebase configuration files

# 4. Verify setup
flutter doctor
```

**Start Backend:**
```bash
cd packages/backend
dotnet run
```
Backend runs on `http://localhost:5005` (Swagger UI: `/swagger/index.html`)

**Start iOS App:**
```bash
# Open iOS Simulator
open -a Simulator

# Run app
cd packages/app
flutter run
```

**Or run both together:**
```bash
# From root directory
npm run dev
```

---

## Project Structure

### For Researchers: Conducting Experiments

#### Testing Different AI Models

1. **Launch the app** and log in (create account via Register button if first time)

2. **Start a new conversation** (tap "New Chat" or similar button)

3. **Select AI model:**
   - Open settings (gear icon or Settings tab)
   - Choose model: GPT, Gemini, Hybrid, or Apple Intelligence
   - Each model has different characteristics for comparison

4. **Send travel queries:**
   ```
   Example queries:
   - "Plan a 3-day trip to Paris with must-see landmarks"
   - "Recommend family-friendly activities in Barcelona"
   - "Create a food tour itinerary in Tokyo"
   - "Suggest a 5-day road trip through Iceland"
   ```

5. **Observe and record:**
   - Response time (streaming speed)
   - Location accuracy (check map visualization)
   - Response structure and creativity
   - JSON format correctness

#### Comparing Responses

**Method 1: Multiple Conversations**
- Create separate conversations for each model
- Send identical query to each
- Switch between conversations to compare side-by-side

**Method 2: Sequential Testing**
- Change model in settings
- Send query
- Take screenshot or copy response
- Repeat with different model

#### Where Data is Stored

**Firestore Database:**
- All conversations are stored in Firestore
- Collection: `conversations`
- Each document contains: userId, messages[], timestamp, model

**Accessing Raw Data:**
- Firebase Console → Firestore Database → `conversations` collection
- Click on conversation document to view JSON structure
- Export to JSON for analysis

**Exporting for Analysis:**

Option 1: Firebase Console Export (manual):
- Firestore Database → Select conversations
- Click "Export" → Choose format

Option 2: Programmatic Export (advanced):
```bash
# Using Firebase CLI
firebase firestore:export gs://your-bucket-name/export-folder

# Using admin SDK script (create custom Node.js script)
```

#### Research Metrics to Collect

1. **Response Quality:**
   - Location accuracy (do coordinates match real places?)
   - Itinerary coherence (logical order, appropriate timing)
   - Creativity vs. predictability

2. **Performance:**
   - Time to first token (latency)
   - Total response time
   - Backend API response time (check logs)

3. **Structured Data:**
   - JSON validity (does parser extract cleanly?)
   - Field completeness (name, lat, lng, description)
   - Route type appropriateness

4. **Hybrid Processing:**
   - Does Stage 2 (Gemini) improve Stage 1 (GPT) output?
   - Measure added latency
   - Compare final output quality vs single-model

### For Developers: Extending the Project

#### Adding a New AI Model

**Step 1: Add Backend Endpoint**

Edit `packages/backend/Routes/RouteGroup.cs`, add new endpoint:

```csharp
group.MapPost("/model/newmodel", async (MessageRequest request) => {
    try {
        // Initialize your model's SDK
        var client = new YourModelClient(apiKey);

        // Send request
        var response = await client.GenerateAsync(request.Message, systemPrompt);

        return Results.Ok(new MessageResponse { Response = response });
    }
    catch (Exception ex) {
        logger.LogError(ex, "New model error");
        return Results.Problem("Error processing request");
    }
}).RequireAuthorization();
```

**Step 2: Add Configuration**

Edit `packages/backend/appsettings.Development.json`:

```json
{
  "NewModelAPIKey": "your-api-key-here"
}
```

**Step 3: Update Flutter Factory**

Edit `packages/app/lib/services/ai/ai_service_factory.dart`:

```dart
static AIService create(String modelType) {
  switch (modelType) {
    case 'newmodel':
      return RestAIService('/model/newmodel');
    // ... existing cases
  }
}
```

**Step 4: Update Settings UI**

Edit `packages/app/lib/routes/settings_page.dart`, add model option to dropdown/selector.

#### Modifying System Prompts

Backend system prompts control how AI models structure their responses.

Edit `packages/backend/Routes/RouteGroup.cs`, find `systemPrompt` variable:

```csharp
const string systemPrompt = @"
You are a travel planning assistant. When users ask for travel recommendations...

[Your custom instructions here]

Example JSON format:
{
  ""locations"": [
    {""name"": ""..."", ""lat"": 0.0, ""lng"": 0.0, ""description"": ""..."", ""day"": 1},
    ...
  ],
  ""routeType"": ""walking""
}
";
```

**Tips:**
- Be specific about JSON structure (parser expects exact field names)
- Include few-shot examples for better consistency
- Test with multiple queries to ensure reliable output

#### Customizing Map Behavior

**Marker Styles:**

Edit `packages/app/lib/routes/map_page.dart`, find marker creation code:

```dart
// Current: Blue pin markers for search results
// Customize: Change color, icon, size

pointAnnotationManager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    iconImage: "custom-marker-icon",  // Use custom asset
    iconSize: 1.5,
    iconColor: Colors.red.value,
  ),
);
```

**Route Appearance:**

```dart
// Find polyline creation code
polylineAnnotationManager.create(
  PolylineAnnotationOptions(
    geometry: LineString(coordinates: routeCoordinates),
    lineColor: Colors.blue.value,  // Change color
    lineWidth: 5.0,                // Change width
    lineCap: LineCap.ROUND,
  ),
);
```

**Camera Behavior:**

Edit camera animation in `_fitCameraToBounds()` method:

```dart
mapboxMap.flyTo(
  CameraOptions(
    center: centerPoint,
    zoom: calculatedZoom,
    bearing: 0,
    pitch: 0,
  ),
  MapAnimationOptions(duration: 1000),  // Adjust animation duration
);
```

### For Presentations: Quick Demo Workflow

#### Pre-Demo Checklist

1. **Environment Running:** `npm run dev` from root (both backend and app)
2. **Test Account Created:** Have login credentials ready
3. **Backend Health Check:** Visit `http://localhost:5005/` to confirm API is responding
4. **Sample Queries Prepared:** Have 2-3 interesting queries ready to copy-paste

#### Demo Script (5-7 minutes)

**1. Introduction (30 seconds)**
- "This is a research project exploring multi-model LLM integration for travel planning"
- Show repo structure briefly (monorepo with Flutter + .NET)

**2. Authentication (30 seconds)**
- Open app, log in
- Mention: "Firebase Authentication with JWT tokens securing the backend"

**3. Basic Query - Single Model (1 minute)**
- Select GPT model in settings
- Send query: *"Plan a 2-day trip to Rome with historical sites"*
- Show streaming response
- Switch to Map tab, show markers

**4. Route Visualization (1 minute)**
- Tap route button/option
- Show multi-stop route on map
- Mention: "Mapbox Directions API with automatic camera fitting"

**5. Model Comparison (2 minutes)**
- Create new conversation
- Switch to Gemini model
- Send **identical query**
- Show different response structure/style
- Discuss: "Different LLMs have different strengths"

**6. Hybrid Processing (1 minute)**
- Create new conversation
- Select Hybrid model
- Send query: *"Create a culinary tour of Barcelona"*
- Explain: "GPT generates initial recommendations, Gemini refines them"
- Show result on map

**7. Architecture Highlight (1 minute)**
- Show backend Swagger UI (`localhost:5005/swagger`)
- Briefly show endpoint structure
- Mention key technologies: Flutter, .NET 9, OpenAI, Google AI, Mapbox, Firebase

**8. Research Context (30 seconds)**
- "All conversations stored in Firestore for analysis"
- "Can compare model performance, response quality, location accuracy"
- "Patterns applicable to any domain requiring structured LLM output"

#### Example Showcase Queries

**For Visual Impact:**
- "Design a photo tour of Iceland's waterfalls and geysers" (multiple scenic locations)
- "Create a 7-day European capital tour: Paris → Amsterdam → Berlin → Prague" (multi-city route)

**For AI Capability:**
- "Plan a surprise anniversary dinner in New York with romantic ambiance and Michelin-starred options" (nuanced requirements)
- "Suggest hidden gems in Kyoto away from tourist crowds" (tests creativity)

**For Hybrid Processing:**
- "Develop a sustainable eco-tourism itinerary in Costa Rica" (benefits from multi-perspective refinement)

#### Handling Questions

**Q: How do you prevent hallucinated locations?**
A: "We parse structured JSON output from LLMs, validate coordinates, and can add verification via geocoding APIs"

**Q: Cost considerations?**
A: "GPT-4o-mini very cost-effective (~$0.15 per 1M input tokens). Hybrid mode approximately doubles cost but improves quality. Research usage typically under $10/month."

**Q: Can this work offline?**
A: "Partial offline support with cached conversations. Apple Intelligence enables fully on-device processing on iOS."

---

## Project Features Explained

### AI Model Integration Deep Dive

#### GPT-4o-mini (OpenAI)

**Characteristics:**
- Fast inference (typically 1-3 seconds for travel itinerary)
- Excellent at structured output (JSON formatting)
- Cost-effective ($0.15 per 1M input tokens)
- Broad training data, good geographical knowledge
- Conservative, factually accurate responses

**Best Use Cases:**
- Quick prototyping
- High-volume applications (cost-sensitive)
- When structured data extraction is critical

**Limitations:**
- Can be formulaic/predictable
- Less creative than larger models
- May lack depth for complex queries

#### Gemini 2.5 Flash (Google)

**Characteristics:**
- Competitive speed with GPT-4o-mini
- Different training approach (more multimodal data)
- Generous free tier (60 requests/min)
- Sometimes more verbose/conversational
- Strong at context understanding

**Best Use Cases:**
- Comparative analysis vs OpenAI models
- Projects prioritizing Google ecosystem
- Budget-conscious research (free tier)

**Limitations:**
- JSON formatting can be less consistent
- May generate longer responses (higher token usage)

#### Hybrid Mode (GPT + Gemini Pipeline)

**Process:**
1. User query sent to GPT-4o-mini with system prompt
2. GPT generates structured travel recommendations with JSON
3. GPT response + original query sent to Gemini 2.5 Flash
4. Gemini enhances, fact-checks, and refines GPT output
5. Final Gemini response returned to user

**Advantages:**
- Leverages strengths of both models
- Potential for higher quality through refinement
- Interesting research comparisons (is two-stage processing worth the latency?)

**Trade-offs:**
- Double the latency (sum of both model response times)
- Double the cost (two API calls)
- More complex error handling

**Research Questions:**
- Does hybrid output have higher location accuracy?
- Do users perceive quality improvement?
- What types of queries benefit most from hybrid processing?

#### Apple Intelligence (iOS Only)

**Characteristics:**
- On-device processing (no API call)
- Maximum privacy (data never leaves device)
- No cost (included in device)
- Works offline
- Limited to Apple devices with Neural Engine

**Implementation:**
Uses iOS native frameworks (likely Core ML or equivalent). See `packages/app/lib/services/ai/apple_intelligence_service.dart`.

**Best Use Cases:**
- Privacy-critical applications
- Offline scenarios
- Cost elimination for high-volume apps

**Limitations:**
- Platform-specific (not cross-platform)
- Generally less capable than cloud models
- May require model conversion/optimization

### Map Features Deep Dive

#### Location Markers

**Two Types:**

1. **Search Result Markers** (User-initiated search):
   - Blue pin markers
   - Created when user searches for places
   - Tappable for details
   - Source: Mapbox Geocoding API

2. **AI-Generated Location Markers** (From AI responses):
   - Circle annotations with labels
   - Created when AI response contains JSON with locations
   - Automatically placed at coordinates from LLM
   - Labeled with location name
   - Source: Parsed from AI response

**Implementation:**

`packages/app/lib/services/location_parser.dart` extracts JSON from AI text:

```dart
// Simplified conceptual code
String extractJson(String aiResponse) {
  // Find ```json...``` code block
  // Parse JSON
  // Extract locations array
  return parsedLocations;
}
```

`packages/app/lib/routes/map_page.dart` creates markers:

```dart
for (var location in locations) {
  pointAnnotationManager.create(
    PointAnnotationOptions(
      geometry: Point(coordinates: Position(location.lng, location.lat)),
      textField: location.name,
    ),
  );
}
```

#### Multi-Stop Routing

**Supported Route Types:**
- **Driving:** Fastest car routes via roads
- **Walking:** Pedestrian paths, sidewalks, shortcuts
- **Cycling:** Bike-friendly routes (where available)

**Data Flow:**
1. User selects route type (or AI suggests in JSON: `"routeType": "walking"`)
2. App extracts waypoints from locations (lat/lng pairs)
3. `MapboxDirectionsService` calls Mapbox Directions API
4. API returns optimized route polyline (encoded geometry)
5. App decodes polyline and draws on map
6. Camera fits to show entire route

**Implementation:**

`packages/app/lib/services/mapbox_directions_service.dart`:

```dart
Future<RouteResponse> getRoute(
  List<LatLng> waypoints,
  String profile, // 'driving-traffic', 'walking', 'cycling'
) async {
  // Build API URL with waypoints
  // Call Mapbox Directions API
  // Parse response (duration, distance, geometry)
  return RouteResponse(...);
}
```

**Automatic Optimization:**
Mapbox Directions API automatically optimizes waypoint order for driving/cycling (optional parameter).

#### Search and Geocoding

**Geocoding:** Convert place name → coordinates
**Reverse Geocoding:** Convert coordinates → place name

**Services:**

1. **Mapbox Geocoding** (`packages/app/lib/services/mapbox_search_service.dart`):
   - Primary search
   - Fast, accurate, free tier sufficient for research
   - Supports autocomplete, filtering by country, bbox

2. **Google Places** (`packages/app/lib/services/google_places_service.dart`):
   - Alternative/backup
   - Rich place details (ratings, photos, reviews)
   - More expensive but more comprehensive

**Usage:**
- User types in search bar → autocomplete suggestions appear
- Select suggestion → map flies to location, marker placed
- Or: Tap map → reverse geocode to get address

#### Camera Auto-Fitting

**Challenge:** When displaying multiple locations (e.g., 5-stop itinerary), how to fit all points in view?

**Solution:** Calculate bounding box, set camera to show entire box with padding.

**Implementation** in `packages/app/lib/routes/map_page.dart`:

```dart
void _fitCameraToBounds(List<LatLng> locations) {
  // Find min/max lat/lng
  double minLat = locations.map((l) => l.lat).reduce(min);
  double maxLat = locations.map((l) => l.lat).reduce(max);
  double minLng = locations.map((l) => l.lng).reduce(min);
  double maxLng = locations.map((l) => l.lng).reduce(max);

  // Calculate center and zoom
  LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  double zoom = calculateZoomForBounds(minLat, maxLat, minLng, maxLng);

  // Animate camera
  mapboxMap.flyTo(CameraOptions(center: center, zoom: zoom));
}
```

**User Experience:** When AI returns multiple locations, map automatically zooms to show all points elegantly.

### Conversation Management

#### Firestore Schema

```
conversations (collection)
├── {conversationId} (document)
│   ├── userId: string
│   ├── title: string (auto-generated from first message)
│   ├── createdAt: timestamp
│   ├── updatedAt: timestamp
│   ├── model: string ("gpt" | "gemini" | "hybrid" | "apple")
│   └── messages: array
│       ├── [0]
│       │   ├── role: "user" | "assistant"
│       │   ├── content: string
│       │   ├── timestamp: timestamp
│       │   ├── locations: array (optional, if message has locations)
│       │   └── routeType: string (optional, if message defines route)
│       ├── [1] ...
│       └── [n] ...
```

#### Real-Time Sync

**Firestore Listener** in `packages/app/lib/services/firestore_access.dart`:

```dart
Stream<List<Conversation>> watchConversations(String userId) {
  return firestore
    .collection('conversations')
    .where('userId', isEqualTo: userId)
    .orderBy('updatedAt', descending: true)
    .snapshots()
    .map((snapshot) => snapshot.docs.map(...).toList());
}
```

**Benefits:**
- Changes in one device instantly appear on another (multi-device sync)
- Persistence across app restarts
- Enables collaboration (multiple researchers viewing same conversation in real-time)

#### Offline Support

`packages/app/lib/services/offline_storage_service.dart`:

- Caches recent conversations locally
- Queues messages sent while offline
- Syncs when connection restored
- Uses `shared_preferences` for lightweight caching

**Trade-offs:**
- Offline mode cannot generate new AI responses (requires backend API)
- Can view/replay existing conversations offline
- Apple Intelligence service can work fully offline

---

## API Endpoints Reference

### Base URL

**Local Development:** `http://localhost:5005`
**Production:** Your deployed backend URL (e.g., `https://api.yourproject.com`)

### Authentication

All `/model/*` endpoints require Firebase JWT authentication.

**Header Required:**
```
Authorization: Bearer <Firebase_ID_Token>
```

**How to Obtain Token:**
1. User logs in via Firebase Auth in Flutter app
2. App retrieves ID token: `await FirebaseAuth.instance.currentUser?.getIdToken()`
3. Token included in HTTP request headers

**Backend Verification:**
`FirebaseAuthenticationHandler` validates token, extracts user ID, rejects if invalid/expired.

### Endpoints

#### GET /

**Description:** Health check, welcome message with documentation links

**Authentication:** Not required

**Response:**
```json
{
  "message": "Welcome to the Travel Planning API",
  "documentation": "/swagger/index.html",
  "health": "OK"
}
```

**Example:**
```bash
curl http://localhost:5005/
```

---

#### POST /model/gpt

**Description:** Generate travel recommendations using OpenAI GPT-4o-mini

**Authentication:** Required

**Request Body:**
```json
{
  "message": "Plan a 3-day trip to Paris"
}
```

**Response:**
```json
{
  "response": "Here's a wonderful 3-day itinerary for Paris...\n\n```json\n{\n  \"locations\": [\n    {\n      \"name\": \"Eiffel Tower\",\n      \"lat\": 48.8584,\n      \"lng\": 2.2945,\n      \"description\": \"Iconic iron tower with stunning city views\",\n      \"day\": 1\n    },\n    {\n      \"name\": \"Louvre Museum\",\n      \"lat\": 48.8606,\n      \"lng\": 2.3376,\n      \"description\": \"World's largest art museum\",\n      \"day\": 2\n    }\n  ],\n  \"routeType\": \"walking\"\n}\n```"
}
```

**Example:**
```bash
curl -X POST http://localhost:5005/model/gpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -d '{"message": "Recommend 5 restaurants in Tokyo"}'
```

---

#### POST /model/gemini

**Description:** Generate travel recommendations using Google Gemini 2.5 Flash

**Authentication:** Required

**Request/Response:** Same format as `/model/gpt`

**Example:**
```bash
curl -X POST http://localhost:5005/model/gemini \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -d '{"message": "Plan a 2-day trip to Barcelona"}'
```

---

#### POST /model/hybrid

**Description:** Generate enhanced recommendations using two-stage GPT + Gemini processing

**Authentication:** Required

**Process:**
1. Sends user message to GPT-4o-mini
2. Takes GPT response and sends to Gemini for refinement
3. Returns final Gemini-enhanced response

**Request/Response:** Same format as other model endpoints, but typically higher quality output with longer latency

**Example:**
```bash
curl -X POST http://localhost:5005/model/hybrid \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -d '{"message": "Create a luxury food tour in Rome"}'
```

---

#### GET /swagger/index.html

**Description:** Interactive Swagger UI for API exploration

**Authentication:** Not required

**Usage:** Open in browser to test endpoints interactively

**URL:** `http://localhost:5005/swagger/index.html`

---

#### GET /swagger/v1/swagger.json

**Description:** OpenAPI specification in JSON format

**Authentication:** Not required

**Usage:** Import into API clients (Postman, Insomnia), generate client SDKs

**URL:** `http://localhost:5005/swagger/v1/swagger.json`

---

### Response Format

**Success (200 OK):**
```json
{
  "response": "AI-generated text with optional JSON code block"
}
```

**Error (400 Bad Request):**
```json
{
  "error": "Invalid request format",
  "details": "Message field is required"
}
```

**Error (401 Unauthorized):**
```json
{
  "error": "Authentication failed",
  "details": "Invalid or expired Firebase token"
}
```

**Error (500 Internal Server Error):**
```json
{
  "error": "AI model error",
  "details": "OpenAI API rate limit exceeded"
}
```

### Expected JSON Format in AI Responses

For location parsing to work correctly, AI models should return JSON in this structure:

```json
{
  "locations": [
    {
      "name": "Location Name",
      "lat": 48.8584,
      "lng": 2.2945,
      "description": "Optional description",
      "day": 1
    }
  ],
  "routeType": "driving"
}
```

**Field Descriptions:**
- `locations` (array, required): List of places
  - `name` (string, required): Display name for marker label
  - `lat` (number, required): Latitude (-90 to 90)
  - `lng` (number, required): Longitude (-180 to 180)
  - `description` (string, optional): Details about the location
  - `day` (number, optional): For multi-day itineraries
- `routeType` (string, optional): `"driving"`, `"walking"`, or `"cycling"`

**Parser Location:**
`packages/app/lib/services/location_parser.dart` handles extraction and validation.

---

## Development Workflow

### Project Structure for Developers

**When adding new features, know where to place code:**

| Feature Type | Location | Example |
|-------------|----------|---------|
| New UI page | `packages/app/lib/routes/` | `new_feature_page.dart` |
| Reusable UI component | `packages/app/lib/widgets/` | `custom_button.dart` |
| Business logic | `packages/app/lib/services/` | `analytics_service.dart` |
| Data model | `packages/app/lib/models/` | `trip.dart` |
| Backend endpoint | `packages/backend/Routes/RouteGroup.cs` | Add `.MapPost()` in group |
| Backend service | `packages/backend/Services/` | `CacheService.cs` |
| Backend middleware | `packages/backend/Program.cs` | Add to pipeline |

### Git Workflow

**Branch Strategy:**
```bash
# Main branch for stable releases
main

# Development branch (optional)
develop

# Feature branches
feature/add-new-ai-model
feature/improve-map-markers
fix/authentication-bug
```

**Recommended Workflow:**
```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, commit frequently
git add .
git commit -m "feat: add new AI model endpoint"

# Push to remote
git push origin feature/your-feature-name

# Create pull request on GitHub
# After review and approval, merge to main
```

**Commit Message Convention (optional):**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

### Testing

#### Flutter App Testing

**Run All Tests:**
```bash
cd packages/app
flutter test
```

**Run Specific Test:**
```bash
flutter test test/services/location_parser_test.dart
```

**Widget Testing:**
```bash
flutter test --plain-name "ChatMessage displays correctly"
```

**Integration Testing:**
```bash
flutter test integration_test/app_test.dart
```

**Test Coverage:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

#### Backend Testing

**Manual API Testing:**

Located in `packages/backend/Tests/test.http`:

```http
### Test GPT endpoint
POST http://localhost:5005/model/gpt
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN_HERE

{
  "message": "Plan a trip to London"
}
```

**Using REST Client Extensions:**
- VS Code: Install "REST Client" extension, open `test.http`, click "Send Request"
- Rider/Visual Studio: HTTP files supported natively

**Using curl:**
```bash
curl -X POST http://localhost:5005/model/gpt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(firebase auth:token)" \
  -d '{"message": "Test query"}'
```

**Unit Testing (C#):**
```bash
cd packages/backend
dotnet test
```

#### Manual Testing Checklist

Before presentations or releases, verify:

**Frontend:**
- [ ] User can register and log in
- [ ] User can create new conversation
- [ ] User can send message and receive streaming response
- [ ] User can switch AI models in settings
- [ ] Map displays markers from AI response
- [ ] Routing works (drawing polyline on map)
- [ ] Search places functionality works
- [ ] App persists conversations in Firestore
- [ ] Logout works correctly

**Backend:**
- [ ] Health check endpoint responds (`GET /`)
- [ ] Swagger UI loads (`/swagger/index.html`)
- [ ] GPT endpoint returns valid response
- [ ] Gemini endpoint returns valid response
- [ ] Hybrid endpoint completes both stages
- [ ] Authentication rejects requests without token
- [ ] CORS allows requests from frontend origin
- [ ] Logs are writing to `logs/log.txt`

### Debugging Tips

**Flutter Hot Reload:**
- Press `r` in terminal after code changes for instant reload
- Press `R` for full app restart
- Press `p` to toggle performance overlay
- Press `h` to display all available commands

**Flutter DevTools:**
```bash
flutter pub global activate devtools
flutter pub global run devtools
# Open in browser, connect to running app
```

**Backend Logging:**
- Check console output for real-time logs
- Check `packages/backend/logs/log.txt` for persistent logs
- Increase verbosity: Change `LogLevel.Default` to `Debug` in `appsettings.Development.json`

**Network Debugging:**
- Use browser DevTools Network tab (for web app)
- Use Charles Proxy or Proxyman for mobile app traffic inspection
- Check Firestore Console for database writes

---

## Troubleshooting

### Common Issues and Solutions

#### Flutter SDK Version Mismatch

**Symptoms:**
```
Error: The current Flutter SDK version is 3.8.0
This project requires Flutter SDK 3.10.4 or higher
```

**Solution:**
```bash
flutter upgrade
flutter doctor  # Verify version
```

If you need specific version:
```bash
# Using fvm (Flutter Version Management)
dart pub global activate fvm
fvm install 3.10.4
fvm use 3.10.4
```

---

#### API Key Configuration Errors

**Symptoms:**
```
[Backend Error] OpenAI API key not found
[Backend Error] 401 Unauthorized from OpenAI
```

**Solution:**
1. Verify `appsettings.Development.json` exists in `packages/backend/`
2. Check key format: `"OpenAIAPIKey": "sk-proj-..."`
3. Ensure no extra spaces or quotes
4. Restart backend: `Ctrl+C`, then `dotnet run`

**Testing API key:**
```bash
# Test OpenAI key
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-proj-YOUR_KEY"

# Test Gemini key
curl "https://generativelanguage.googleapis.com/v1/models?key=YOUR_KEY"
```

---

#### Firebase Authentication Issues

**Symptoms:**
```
[App Error] Firebase Auth: User not found
[Backend Error] 401 Unauthorized - Invalid Firebase token
```

**Solutions:**

1. **Email/Password not enabled:**
   - Firebase Console → Authentication → Sign-in method
   - Enable Email/Password provider

2. **Missing configuration files:**
   - Check `packages/app/ios/Runner/GoogleService-Info.plist` exists
   - Check `packages/app/lib/firebase_options.dart` exists
   - Run `flutterfire configure` to regenerate (select iOS only when prompted)

3. **Backend can't verify tokens:**
   - Ensure `FirebaseCredentials` in `appsettings.Development.json` is valid JSON
   - Check `project_id` matches Firebase Console project
   - Verify private key is complete (including `-----BEGIN/END PRIVATE KEY-----`)

4. **Token expired:**
   - Tokens expire after 1 hour
   - App automatically refreshes, but force logout/login if issues persist

---

#### Mapbox Token Problems

**Symptoms:**
```
[App Error] MapboxMapException: Invalid access token
[Map Error] 401 Unauthorized
```

**Solutions:**

1. **Token format incorrect:**
   - Should start with `pk.eyJ1IjoI...`
   - Check for extra spaces in `.env` file
   - Ensure no quotes around token in `.env`

2. **Token not loaded:**
   ```bash
   # Verify .env file exists
   ls packages/app/.env

   # Restart app after changing .env
   flutter run
   ```

3. **Token restrictions:**
   - Mapbox Console → Tokens → Check URL restrictions
   - For local dev, don't add restrictions
   - For production, add specific URLs

4. **Quota exceeded:**
   - Check usage in Mapbox Console
   - Free tier: 50k map loads/month
   - If exceeded, upgrade plan or create new account (testing only)

---

#### CORS Errors During Development

**Symptoms:**
```
Access to XMLHttpRequest blocked by CORS policy
No 'Access-Control-Allow-Origin' header present
```

**Solution:**

1. **Check backend CORS configuration:**
   - `packages/backend/appsettings.Development.json`: `"CORS": "*"`
   - For specific origin: `"CORS": "http://localhost:8080"`

2. **Verify CORS middleware in backend:**
   - `packages/backend/Program.cs` should have:
     ```csharp
     app.UseCors("development");
     ```

3. **Web-specific issue:**
   - Flutter web runs on `http://localhost:<random-port>`
   - Use `"CORS": "*"` for development
   - Or find exact port: Look at terminal when running `flutter run -d chrome`

4. **Restart backend after config changes**

---

#### Port Conflicts

**Symptoms:**
```
[Backend Error] Address already in use: 5005
[Backend Error] Failed to bind to address
```

**Solution:**

**macOS/Linux:**
```bash
# Find process using port 5005
lsof -i :5005

# Kill process
kill -9 <PID>
```

**Windows:**
```cmd
# Find process
netstat -ano | findstr :5005

# Kill process
taskkill /PID <PID> /F
```

**Alternative:** Change port in `packages/backend/Properties/launchSettings.json`:
```json
{
  "applicationUrl": "http://localhost:5010;https://localhost:5011"
}
```

Also update `API_BASE_URL` in `packages/app/.env`.

---

#### Build Errors After Pulling Changes

**Symptoms:**
```
Error: Could not resolve package...
Error: Method not found...
```

**Solution:**

```bash
# Root dependencies
npm install

# Backend dependencies
cd packages/backend
dotnet restore
dotnet clean
dotnet build

# Flutter dependencies
cd ../app
flutter clean
flutter pub get
flutter pub upgrade
flutter pub outdated  # Check for updates
```

---

#### Firestore Permission Denied

**Symptoms:**
```
[Firestore Error] PERMISSION_DENIED: Missing or insufficient permissions
```

**Solution:**

1. **Check Firestore Rules:**
   - Firebase Console → Firestore Database → Rules tab
   - Temporary fix (development only):
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```
   - Publish rules

2. **User not authenticated:**
   - Ensure user is logged in
   - Check `FirebaseAuth.instance.currentUser != null`

3. **Wrong user ID:**
   - Queries filtered by `userId` must match authenticated user's ID

---

#### Map Not Displaying

**Symptoms:**
- Blank white/black screen where map should be
- Map shows briefly then disappears

**Solutions:**

1. **Mapbox token issue:** See "Mapbox Token Problems" above

2. **iOS permissions:**
   - Check `packages/app/ios/Runner/Info.plist` has location permissions:
     ```xml
     <key>NSLocationWhenInUseUsageDescription</key>
     <string>This app needs access to location for map features</string>
     ```
   - Ensure location permissions are granted in iOS Settings

3. **SDK initialization:**
   - Ensure `MapboxOptions.setAccessToken()` called before map creation
   - Check `main.dart` initialization code
   - Verify token is loaded correctly from `.env` file

4. **Simulator issues:**
   - Try running on a physical iOS device
   - Reset simulator: Device → Erase All Content and Settings

---

## Research Methodology

### Experimental Setup

This project is designed to facilitate empirical research on LLM behavior and multi-model integration patterns. Below are guidelines for conducting rigorous experiments.

#### Research Design

**Comparative Study Structure:**

1. **Define Research Questions**
   - Example: "Do different LLMs structure travel itineraries differently?"
   - Example: "Does hybrid processing improve location accuracy vs single models?"

2. **Create Test Dataset**
   - Prepare 20-50 standardized queries
   - Vary complexity (simple: "restaurants in Paris" → complex: "2-week multi-country itinerary")
   - Include diverse domains (food, history, nature, adventure, luxury)

3. **Controlled Variables**
   - Same system prompt for all models (already implemented)
   - Same user account for all tests
   - Same time of day (model performance can vary)
   - Same network conditions

4. **Measurement Protocol**
   - Send each query to each model (GPT, Gemini, Hybrid)
   - Record responses in separate conversations
   - Export conversations from Firestore
   - Measure quantitative metrics (see below)

#### Data Collection

**Automated Collection:**

Export all conversations programmatically using Firebase Admin SDK:

```javascript
// Node.js script example
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();
const conversationsRef = db.collection('conversations');

async function exportConversations() {
  const snapshot = await conversationsRef
    .where('userId', '==', 'YOUR_USER_ID')
    .get();

  const data = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));

  fs.writeFileSync('conversations_export.json', JSON.stringify(data, null, 2));
}
```

**Manual Collection:**

- Firebase Console → Firestore Database → `conversations` collection
- Click each conversation → Copy JSON
- Paste into spreadsheet or analysis tool

**Metrics to Collect:**

| Metric | How to Measure | Purpose |
|--------|---------------|---------|
| **Response Time** | Backend logs (check `logs/log.txt` for request duration) | Compare model speed |
| **Token Count** | Count words or use tokenizer libraries | Assess verbosity, cost estimation |
| **Location Count** | Parse JSON, count `locations` array length | Compare thoroughness |
| **JSON Validity** | Run parser, record success/failure | Measure structured output reliability |
| **Coordinate Accuracy** | Manual verification via Google Maps | Assess factual correctness |
| **Route Appropriateness** | Human evaluation (is walking/driving logical?) | Measure reasoning quality |
| **Description Quality** | Qualitative rating scale (1-5) | Subjective assessment |
| **Itinerary Coherence** | Does order make sense? Logical flow? | Measure planning capability |

#### Evaluation Approach

**Quantitative Analysis:**

```python
# Example Python analysis script
import json
import pandas as pd

# Load exported conversations
with open('conversations_export.json') as f:
    data = json.load(f)

# Extract metrics
records = []
for conv in data:
    for msg in conv['messages']:
        if msg['role'] == 'assistant':
            records.append({
                'model': conv['model'],
                'query': conv['messages'][0]['content'],
                'response_length': len(msg['content']),
                'location_count': len(msg.get('locations', [])),
                'has_valid_json': bool(msg.get('locations')),
            })

df = pd.DataFrame(records)

# Compare models
print(df.groupby('model').mean())
```

**Qualitative Analysis:**

Create evaluation rubric:

| Criterion | 1 (Poor) | 3 (Good) | 5 (Excellent) |
|-----------|----------|----------|---------------|
| **Creativity** | Generic suggestions | Some unique ideas | Highly personalized, creative |
| **Accuracy** | Wrong locations | Mostly correct | 100% verified correct |
| **Coherence** | Disjointed | Logical flow | Seamless narrative |
| **Completeness** | Missing key info | Adequate detail | Comprehensive with extras |

Blind evaluation: Have multiple reviewers rate responses without knowing which model generated them.

#### Metrics for Evaluation

**Location Accuracy Rate:**
```
Accuracy = (Correct Locations / Total Locations) × 100%
```

Manual verification: Check each location on Google Maps, confirm coordinates match location name.

**JSON Parsing Success Rate:**
```
Success Rate = (Parseable Responses / Total Responses) × 100%
```

**Response Time (Latency):**
- Median response time per model
- 95th percentile response time
- Hybrid overhead: `hybrid_time - (gpt_time + gemini_time)`

**Cost per Query:**
```
GPT Cost = (input_tokens × $0.00000015) + (output_tokens × $0.0000006)
Gemini Cost = (using free tier? $0 : calculated similarly)
Hybrid Cost = GPT Cost + Gemini Cost
```

**User Preference (if conducting user study):**
- Show responses from different models (anonymized)
- Ask: "Which response would you use for planning?"
- Record preferences, calculate preference percentage per model

#### Reproducibility Considerations

For research publication, ensure:

1. **Version Pinning:**
   - Document exact model versions (GPT-4o-mini version from OpenAI docs, Gemini 2.5 Flash release date)
   - Record SDK versions (`OpenAI` NuGet version, `Google.GenAI` version)
   - Note Flutter, .NET versions

2. **System Prompt:**
   - Include exact system prompt text in paper appendix
   - Document any changes made during research

3. **Random Seed (if applicable):**
   - Some models support `seed` parameter for reproducibility
   - Document temperature, top_p settings (if changed from defaults)

4. **Ethical Considerations:**
   - Disclose AI-generated content in publications
   - Cite model providers appropriately
   - Note that model behavior may change over time (models are continually updated)

### Example Research Questions

#### 1. How do different LLMs structure travel recommendations?

**Hypothesis:** Different training data and architectures lead to distinct structuring patterns.

**Method:**
- Send 30 identical queries to GPT, Gemini, and Hybrid
- Analyze JSON structure (nested vs flat), field usage (description richness), location density
- Qualitative coding: categorize organizational approaches

**Expected Findings:**
- GPT may be more concise, formulaic
- Gemini may be more verbose, narrative-driven
- Hybrid may combine structure from GPT with richness from Gemini

#### 2. Does hybrid processing improve location accuracy?

**Hypothesis:** Two-stage verification reduces hallucinated or incorrect locations.

**Method:**
- 50 queries, record GPT-only vs Hybrid responses
- Manually verify all coordinates on Google Maps
- Calculate accuracy rate for each

**Expected Findings:**
- Hybrid should have equal or higher accuracy (Gemini catches GPT errors)
- May reveal whether accuracy gain justifies latency/cost increase

#### 3. What are trade-offs between on-device and cloud AI?

**Hypothesis:** Cloud models are more capable, but on-device offers privacy/speed benefits.

**Method:**
- Compare Apple Intelligence (on-device) vs GPT (cloud) on iOS devices
- Measure response time, response quality, offline capability

**Expected Findings:**
- On-device: faster, works offline, more private, but less accurate
- Cloud: slower, requires internet, privacy concerns, but higher quality

---

## References

### Package Documentation

- **Flutter App Detailed Docs:** [packages/app/README.md](packages/app/README.md)
- **Backend API Detailed Docs:** [packages/backend/README.md](packages/backend/README.md)

### Specific Feature Guides

- **Mapbox Integration:** [packages/app/MAPBOX.md](packages/app/MAPBOX.md) - Map rendering, markers, routes, camera control
- **Backend Payload Format:** [packages/app/BACKEND_PAYLOAD.md](packages/app/BACKEND_PAYLOAD.md) - Expected JSON structure from AI responses
- **Offline Behavior:** [packages/app/OFFLINE.md](packages/app/OFFLINE.md) - Caching and sync strategies
- **Google Places Setup:** [packages/app/GOOGLE_PLACES_GUIDE.md](packages/app/GOOGLE_PLACES_GUIDE.md) - Alternative geocoding service
- **Google Places Troubleshooting:** [packages/app/GOOGLE_PLACES_TROUBLESHOOTING.md](packages/app/GOOGLE_PLACES_TROUBLESHOOTING.md)

### External Documentation

**Flutter:**
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter for Web](https://docs.flutter.dev/platform-integration/web)

**.NET / C#:**
- [ASP.NET Core Documentation](https://learn.microsoft.com/en-us/aspnet/core/)
- [Minimal APIs Guide](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis)
- [.NET 9 Release Notes](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-9)

**AI APIs:**
- [OpenAI API Documentation](https://platform.openai.com/docs/)
- [OpenAI .NET SDK](https://github.com/openai/openai-dotnet)
- [Google Gemini API](https://ai.google.dev/docs)
- [Google GenAI .NET SDK](https://github.com/google/generative-ai-dotnet)

**Firebase:**
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Cloud Firestore](https://firebase.google.com/docs/firestore)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [FlutterFire (Firebase for Flutter)](https://firebase.flutter.dev/)

**Mapbox:**
- [Mapbox Maps SDK for Flutter](https://docs.mapbox.com/flutter/)
- [Mapbox Geocoding API](https://docs.mapbox.com/api/search/geocoding/)
- [Mapbox Directions API](https://docs.mapbox.com/api/navigation/directions/)

**Monorepo Management:**
- [Lerna Documentation](https://lerna.js.org/)
- [npm Workspaces](https://docs.npmjs.com/cli/v7/using-npm/workspaces)

---

## Acknowledgments

### Technologies Used

This project is built upon the following open-source technologies and commercial services:

**Frontend:**
- [Flutter](https://flutter.dev/) - Google's UI toolkit for cross-platform apps
- [Dart](https://dart.dev/) - Programming language optimized for UI
- [Mapbox Maps SDK](https://www.mapbox.com/) - Mapping and location services
- [Firebase](https://firebase.google.com/) - Authentication and database backend
- [easy_localization](https://pub.dev/packages/easy_localization) - Internationalization
- [Lucide Icons](https://lucide.dev/) - Beautiful icon library

**Backend:**
- [.NET](https://dotnet.microsoft.com/) - Microsoft's cross-platform framework
- [ASP.NET Core](https://dotnet.microsoft.com/apps/aspnet) - Web framework
- [Serilog](https://serilog.net/) - Structured logging library
- [Swashbuckle](https://github.com/domaindrivendev/Swashbuckle.AspNetCore) - Swagger/OpenAPI generation

**AI Services:**
- [OpenAI](https://openai.com/) - GPT models and API
- [Google AI](https://ai.google/) - Gemini models and API

**Development Tools:**
- [Lerna](https://lerna.js.org/) - Monorepo management
- [Visual Studio Code](https://code.visualstudio.com/) - Code editor
- [GitHub](https://github.com/) - Version control and collaboration

### Research Inspiration

This project draws inspiration from:
- Academic research on LLM evaluation and comparison methodologies
- Industry best practices for multi-model AI architectures
- iOS mobile development patterns and Apple Human Interface Guidelines
- Modern API design principles

### Open Source Libraries

A full list of dependencies with licenses:
- **Flutter packages:** See [packages/app/pubspec.yaml](packages/app/pubspec.yaml)
- **NuGet packages:** See [packages/backend/backend.csproj](packages/backend/backend.csproj)

### Author

**Thomas Moerman**
Researcher exploring practical applications of multi-model LLM integration

- GitHub: [@thomasmoerman2](https://github.com/thomasmoerman2)
- Repository: [mono_research](https://github.com/thomasmoerman2/mono_research)

---

## License

*[Specify your license here - MIT, Apache 2.0, or proprietary research license]*

For academic use and research purposes, please cite this repository as:

```
Moerman, T. (2025). AI-Powered Travel Planning Research Platform:
A Multi-Model LLM Integration Study.
GitHub repository. https://github.com/thomasmoerman2/mono_research
```

---

## Contributing

Contributions are welcome! If you'd like to contribute to this research project:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Code Style:**
- Flutter: Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- C#: Follow [Microsoft C# Coding Conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)

**Before submitting:**
- Run tests: `flutter test` and `dotnet test`
- Ensure code is formatted: `flutter format .` and `dotnet format`
- Update documentation if adding features

---

## Support

**Issues:** [GitHub Issues](https://github.com/thomasmoerman2/mono_research/issues)
**Questions:** Open a discussion or issue on GitHub

---

**Thank you for your interest in this research project!**

If you use this work in your research or publications, please consider citing this repository and sharing your findings with the community.
