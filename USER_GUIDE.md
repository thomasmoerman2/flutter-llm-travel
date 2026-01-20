# User Guide

**🇬🇧 English** | [🇳🇱 Nederlands](USER_GUIDE_NL.md)

Complete guide for using the AI-Powered Travel Planning Research Platform for research, development, and presentations.

---

## Table of Contents

- [Getting Started](#getting-started)
- [For Researchers](#for-researchers)
- [For Developers](#for-developers)
- [For Presenters](#for-presenters)
- [Feature Deep Dive](#feature-deep-dive)
- [FAQ](#faq)

---

## Getting Started

### First Launch

1. **Start the Backend:**
   ```bash
   cd packages/backend
   dotnet run
   ```
   Wait for: `Now listening on: http://localhost:5005`

2. **Start the iOS App:**
   ```bash
   # Open iOS Simulator if not running
   open -a Simulator

   # In another terminal
   cd packages/app
   flutter run
   ```

3. **Create an Account:**
   - App will show login screen
   - Tap "Register" or "Create Account"
   - Enter email and password
   - Tap "Sign Up"

4. **You're Ready!**
   - You'll be taken to the main chat interface
   - Your conversations will be saved automatically

### Quick Start: First Conversation

1. **Select AI Model** (Settings tab/gear icon):
   - GPT (recommended for first try)
   - Gemini
   - Hybrid
   - Apple Intelligence (iOS only)

2. **Send a Query:**
   ```
   "Plan a 2-day trip to Paris with must-see landmarks"
   ```

3. **Watch the Response:**
   - Text streams in word-by-word
   - JSON location data is extracted automatically

4. **View on Map:**
   - Tap "Map" tab
   - See markers for all locations
   - Tap markers for details

5. **Generate Route (Optional):**
   - Tap route button or select route type
   - Choose: Walking, Driving, or Cycling
   - Route polyline appears on map

---

## For Researchers

### Conducting AI Model Comparison Studies

#### Experimental Setup

**Goal:** Compare how different AI models structure travel recommendations

**1. Create Test Dataset**

Prepare standardized queries covering various complexity levels:

**Simple queries:**
- "Recommend 5 restaurants in Tokyo"
- "Best museums in Barcelona"

**Medium complexity:**
- "Plan a 3-day trip to Rome with historical sites"
- "Create a food tour itinerary in Paris"

**Complex queries:**
- "Design a 2-week multi-country itinerary: France → Italy → Greece with mix of culture, food, and nature"
- "Plan a family-friendly trip to Iceland with kids ages 8 and 12, focusing on geothermal sites and waterfalls"

**2. Test Each Model**

For each query:

a. **Create New Conversation:**
   - Tap "New Chat" button
   - Ensures clean slate for each test

b. **Select Model:**
   - Settings → AI Model
   - Choose: GPT, Gemini, or Hybrid

c. **Send Query:**
   - Copy-paste exact query (ensures consistency)
   - Wait for complete response

d. **Record Observations:**
   - Response time (how long until complete)
   - Location count (how many places suggested)
   - Response structure (concise vs verbose)
   - JSON validity (did parsing succeed?)

e. **Save Screenshot:**
   - iOS: Press Volume Up + Side Button
   - Screenshots saved to Photos app

f. **Check Map:**
   - Switch to Map tab
   - Verify locations are placed correctly
   - Note any missing or incorrect markers

**3. Repeat for All Models**

Send same query to:
- GPT model
- Gemini model
- Hybrid model
- (Optional) Apple Intelligence

Keep conversations separate for easy comparison.

---

#### Data Collection

**Automated Export from Firestore**

**Method 1: Firebase Console (Manual)**

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore Database
4. Click "conversations" collection
5. Click on conversation document
6. Copy JSON data
7. Paste into spreadsheet or analysis tool

**Method 2: Programmatic Export (Recommended)**

Create a Node.js script to export all conversations:

```javascript
// export-conversations.js
const admin = require('firebase-admin');
const fs = require('fs');

// Initialize with your service account
const serviceAccount = require('./firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportConversations(userId) {
  const snapshot = await db.collection('conversations')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc')
    .get();

  const conversations = [];
  snapshot.forEach(doc => {
    conversations.push({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate(),
      updatedAt: doc.data().updatedAt?.toDate(),
    });
  });

  // Save to JSON file
  fs.writeFileSync(
    'conversations_export.json',
    JSON.stringify(conversations, null, 2)
  );

  console.log(`Exported ${conversations.length} conversations`);
}

// Get your user ID from Firebase Console → Authentication
exportConversations('YOUR_USER_ID_HERE');
```

**Run the script:**
```bash
npm install firebase-admin
node export-conversations.js
```

**Method 3: Firebase CLI**

```bash
# Export entire Firestore database
firebase firestore:export gs://your-bucket-name/exports/conversations

# Download from Cloud Storage
gsutil cp -r gs://your-bucket-name/exports/conversations ./firestore-backup
```

---

#### Analysis Metrics

**Quantitative Metrics**

| Metric | How to Measure | Purpose |
|--------|---------------|---------|
| **Response Time** | Note time from send to completion | Compare model speed |
| **Token Count** | Word count or use tokenizer | Assess verbosity, estimate cost |
| **Location Count** | Parse JSON, count `locations` array | Compare thoroughness |
| **JSON Validity** | Check if parser extracted data | Measure structured output reliability |
| **Coordinate Accuracy** | Verify each location on Google Maps | Assess factual correctness |
| **Route Appropriateness** | Is walking/driving logical for distances? | Measure reasoning quality |

**Example Python Analysis:**

```python
import json
import pandas as pd

# Load exported data
with open('conversations_export.json') as f:
    data = json.load(f)

# Extract metrics
records = []
for conv in data:
    model = conv.get('model', 'unknown')
    for msg in conv.get('messages', []):
        if msg['role'] == 'assistant':
            locations = msg.get('locations', [])
            records.append({
                'model': model,
                'query': conv['messages'][0]['content'],
                'response_length': len(msg['content']),
                'location_count': len(locations),
                'has_json': bool(locations),
                'conversation_id': conv['id']
            })

df = pd.DataFrame(records)

# Compare models
print("\n=== Model Comparison ===")
print(df.groupby('model').agg({
    'response_length': 'mean',
    'location_count': 'mean',
    'has_json': 'mean'
}))

# Statistical tests
from scipy import stats
gpt_lengths = df[df['model'] == 'gpt']['response_length']
gemini_lengths = df[df['model'] == 'gemini']['response_length']
t_stat, p_value = stats.ttest_ind(gpt_lengths, gemini_lengths)
print(f"\nT-test p-value: {p_value}")
```

**Qualitative Metrics**

Create evaluation rubric (1-5 scale):

| Criterion | 1 (Poor) | 3 (Good) | 5 (Excellent) |
|-----------|----------|----------|---------------|
| **Creativity** | Generic, predictable | Some unique ideas | Highly creative, personalized |
| **Accuracy** | Wrong locations | Mostly correct | 100% verified correct |
| **Coherence** | Disjointed, random order | Logical flow | Seamless narrative, perfect ordering |
| **Completeness** | Missing key details | Adequate information | Comprehensive with extras |
| **Description Quality** | Minimal or none | Decent descriptions | Rich, engaging descriptions |

**Blind Evaluation:**
- Have multiple reviewers
- Show responses without revealing which model
- Calculate inter-rater reliability (Cohen's kappa)

---

#### Research Questions to Explore

**1. Model Accuracy Comparison**

**Hypothesis:** Different LLMs have varying location accuracy rates.

**Method:**
- Send 50 travel queries to each model
- Manually verify every coordinate on Google Maps
- Calculate accuracy percentage per model

**Expected Finding:** Hybrid mode may have highest accuracy due to dual verification.

**2. Response Structure Analysis**

**Hypothesis:** Models organize information differently based on training data.

**Method:**
- Analyze JSON structure (flat vs nested)
- Count average locations per response
- Categorize organizational patterns

**Example Patterns:**
- Chronological (day 1, day 2, day 3)
- Geographical (by neighborhood/district)
- Thematic (museums together, restaurants together)
- Mixed approach

**3. Hybrid Processing Value**

**Hypothesis:** Two-stage processing improves quality but adds latency.

**Method:**
- Same 30 queries to GPT-only vs Hybrid
- Measure response time for both
- Compare output quality (accuracy, completeness)
- Calculate cost difference

**Analysis:** Does the improvement justify 2x cost and latency?

**4. User Preference Study**

**Hypothesis:** Users prefer certain model outputs.

**Method:**
- Recruit 20+ participants
- Show anonymized responses from different models
- Ask: "Which would you use for actual trip planning?"
- Calculate preference percentages

**Statistical Analysis:** Chi-square test for significance

---

#### Tips for Valid Research

**Control Variables:**
- Use same device (avoid iOS vs simulator differences)
- Same time of day (model performance can vary)
- Same network conditions
- Same system prompts (already controlled in backend)
- Same user account

**Document Everything:**
- Exact model versions (check OpenAI/Google docs)
- SDK versions (check package.json, backend.csproj)
- Date of experiments (models updated regularly)
- System prompt used

**Sample Size:**
- Minimum 30 queries per condition for statistical power
- More complex analyses need 50+

**Reproducibility:**
- Save all queries in spreadsheet
- Export raw data (JSON from Firestore)
- Document analysis scripts
- Include in research paper appendix

---

## For Developers

### Extending the Application

#### Adding a New AI Model

**Example: Adding Claude (Anthropic)**

**Step 1: Add Backend Endpoint**

Edit `packages/backend/Routes/RouteGroup.cs`:

```csharp
// Add using statement at top
using Anthropic.SDK;

// Inside the ConfigureRoutes method, add new endpoint:
group.MapPost("/model/claude", async (MessageRequest request) =>
{
    try
    {
        var apiKey = builder.Configuration["ClaudeAPIKey"];
        var client = new AnthropicClient(apiKey);

        var response = await client.Messages.CreateAsync(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 4096,
            messages: new[] {
                new Message {
                    Role = "user",
                    Content = systemPrompt + "\n\n" + request.Message
                }
            }
        );

        return Results.Ok(new MessageResponse
        {
            Response = response.Content.First().Text
        });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Claude API error");
        return Results.Problem($"Error: {ex.Message}");
    }
}).RequireAuthorization();
```

**Step 2: Add API Key to Configuration**

Edit `packages/backend/appsettings.Development.json`:

```json
{
  "ClaudeAPIKey": "sk-ant-YOUR-KEY-HERE",
  // ... other keys
}
```

**Step 3: Update Flutter Service Factory**

Edit `packages/app/lib/services/ai/ai_service_factory.dart`:

```dart
static AIService create(String modelType) {
  switch (modelType) {
    case 'claude':
      return RestAIService('/model/claude');
    case 'gpt':
      return RestAIService('/model/gpt');
    case 'gemini':
      return RestAIService('/model/gemini');
    case 'hybrid':
      return RestAIService('/model/hybrid');
    case 'apple':
      return AppleIntelligenceService();
    default:
      return RestAIService('/model/gpt');
  }
}
```

**Step 4: Update Settings UI**

Edit `packages/app/lib/routes/settings_page.dart`, add to model dropdown:

```dart
DropdownMenuItem(
  value: 'claude',
  child: Text('Claude (Anthropic)'),
),
```

**Step 5: Test**

```bash
# Restart backend
cd packages/backend
dotnet run

# Hot reload Flutter app (press 'r' in terminal where app is running)
# Or restart completely (press 'R')

# Select Claude model in settings
# Send test query
```

---

#### Modifying System Prompts

System prompts control AI behavior and output format.

**Location:** `packages/backend/Routes/RouteGroup.cs`

**Current Prompt:**

```csharp
const string systemPrompt = @"
You are a travel planning assistant. When users ask for travel recommendations, places, routes, or itineraries:

1. Provide a helpful summary in natural language
2. Include a JSON code block with location data (use ```json code block)
3. Required JSON fields: name (string), lat (number), lng (number)
4. Optional JSON fields: description (string), day (number for multi-day trips)
5. Optional: routeType field with values: 'driving', 'walking', or 'cycling'

Example format:
{
  ""locations"": [
    {""name"": ""Eiffel Tower"", ""lat"": 48.8584, ""lng"": 2.2945, ""description"": ""Iconic landmark"", ""day"": 1}
  ],
  ""routeType"": ""walking""
}
";
```

**Customization Examples:**

**For More Detailed Responses:**

```csharp
const string systemPrompt = @"
You are an expert travel planner with deep knowledge of worldwide destinations. When users ask for travel recommendations:

1. Provide engaging, detailed narratives about each location
2. Include local tips, best times to visit, and insider knowledge
3. Always include JSON code block with structured data
4. Add historical context and cultural significance to descriptions

[... rest of prompt ...]
";
```

**For Budget-Conscious Travel:**

```csharp
const string systemPrompt = @"
You are a budget travel expert. When planning trips:

1. Prioritize free or low-cost activities
2. Mention approximate costs when known
3. Suggest money-saving tips
4. Include JSON with location data

Add optional 'cost' field to JSON (low/medium/high)

[... rest of prompt ...]
";
```

**Testing Prompt Changes:**

1. Edit the prompt in `RouteGroup.cs`
2. Save file
3. Restart backend (`Ctrl+C`, then `dotnet run`)
4. Send test queries
5. Compare outputs

**Tips:**
- Be specific about JSON structure (parser depends on exact field names)
- Include few-shot examples for consistency
- Test with diverse queries
- Document prompt version in research notes

---

#### Customizing Map Behavior

**Location:** `packages/app/lib/routes/map_page.dart`

**Change Marker Style:**

```dart
// Find marker creation code around line 300-400
// Current: Blue pin markers

// Custom color marker:
pointAnnotationManager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    iconColor: Colors.red.value,  // Change color
    iconSize: 1.2,                  // Adjust size
    textField: location.name,       // Label
    textSize: 14.0,                 // Text size
  ),
);

// Custom image marker:
pointAnnotationManager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    iconImage: "custom-pin",  // Asset name
    iconSize: 1.5,
    textField: location.name,
  ),
);
// Note: Register custom image in assets first
```

**Change Route Line Style:**

```dart
// Find polyline creation code
polylineAnnotationManager.create(
  PolylineAnnotationOptions(
    geometry: LineString(coordinates: routeCoordinates),
    lineColor: Colors.blue.value,  // Change to any color
    lineWidth: 8.0,                 // Make thicker
    lineOpacity: 0.8,               // Add transparency
    lineCap: LineCap.ROUND,         // Rounded ends
    lineJoin: LineJoin.ROUND,       // Rounded corners
  ),
);
```

**Change Camera Animation:**

```dart
// Find _fitCameraToBounds method
void _fitCameraToBounds(List<LatLng> locations) {
  // ... bounding box calculation ...

  mapboxMap.flyTo(
    CameraOptions(
      center: centerPoint,
      zoom: calculatedZoom,
      bearing: 0,          // Map rotation (0 = north up)
      pitch: 45,           // 3D tilt (0-60 degrees)
    ),
    MapAnimationOptions(
      duration: 2000,      // Animation time in ms (default 1000)
      startDelay: 500,     // Delay before starting
    ),
  );
}
```

**Add Custom Map Style:**

```dart
// In initState or map initialization
mapboxMap = await MapboxMap.create(
  MapOptions(
    styleUri: MapboxStyles.OUTDOORS,  // Change style
    // Options: STREETS, OUTDOORS, LIGHT, DARK, SATELLITE, SATELLITE_STREETS

    center: Point(coordinates: Position(-74.0060, 40.7128)),
    zoom: 12.0,
  ),
);
```

---

#### Adding New Features

**Example: Add "Favorites" Feature**

**1. Update Firestore Schema:**

Add `favorites` field to conversation document:

```dart
// In firestore_access.dart
Future<void> toggleFavorite(String conversationId, bool isFavorite) async {
  await _firestore
      .collection('conversations')
      .doc(conversationId)
      .update({'favorite': isFavorite});
}
```

**2. Update UI:**

Add star icon to conversation list:

```dart
// In conversation_sidebar.dart
IconButton(
  icon: Icon(
    conversation.favorite ? Icons.star : Icons.star_border,
    color: conversation.favorite ? Colors.yellow : Colors.grey,
  ),
  onPressed: () {
    firestoreService.toggleFavorite(
      conversation.id,
      !conversation.favorite,
    );
  },
)
```

**3. Add Filter:**

```dart
// In conversation_sidebar.dart
Future<List<Conversation>> _loadFavorites() async {
  final snapshot = await firestore
      .collection('conversations')
      .where('userId', isEqualTo: userId)
      .where('favorite', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .get();

  return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
}
```

**4. Test:**

- Hot reload app
- Tap star icon on conversation
- Verify it persists after restart
- Check Firestore Console to see `favorite: true`

---

## For Presenters

### 5-Minute Demo Script

**Pre-Demo Checklist** (10 minutes before):

- [ ] Backend running (`npm run dev:backend`)
- [ ] iOS simulator open with app running
- [ ] Test account logged in
- [ ] Create test conversation beforehand (optional backup)
- [ ] Browser open to `localhost:5005/swagger`
- [ ] Sample queries ready to copy-paste
- [ ] Screen recording software ready (optional)

---

**Demo Flow:**

**[0:00 - 0:30] Introduction**

> "This is a research project exploring how different AI models structure travel recommendations. It's built with Flutter for iOS and .NET 9 for the backend, integrating multiple LLM providers: OpenAI GPT, Google Gemini, and a hybrid processing pipeline."

**Show:**
- Project structure briefly (if screen sharing code)
- Or jump straight to app

---

**[0:30 - 1:00] Authentication**

> "The app uses Firebase Authentication for user management. All conversations are saved to Firestore in real-time."

**Show:**
- Login screen
- Quick login (or use Touch ID if available)

---

**[1:00 - 2:00] Basic Query - GPT Model**

> "Let's start with the GPT-4o-mini model. Watch how the response streams in word-by-word, creating a natural conversational feel."

**Do:**
- Navigate to Settings, show model selection
- Select "GPT"
- Return to chat
- Send query: `"Plan a 2-day trip to Rome with historical sites"`
- Watch response stream
- Point out the natural language response

> "Notice how the AI structures the response with day-by-day breakdown"

---

**[2:00 - 2:45] Map Visualization**

> "The system automatically extracts location data from the AI response and visualizes it on a map using Mapbox."

**Do:**
- Switch to Map tab
- Show markers for all locations
- Tap a marker to show details
- Zoom in/out, pan around

> "Each location has coordinates and descriptions extracted via JSON parsing from the AI's text output."

---

**[2:45 - 3:30] Route Generation**

> "We can also generate optimized routes between locations using Mapbox Directions API."

**Do:**
- Tap route button or select route type
- Choose "Walking"
- Watch polyline appear connecting locations
- Show camera auto-fitting to entire route

> "The system automatically calculates the bounding box and fits the camera to show all points"

---

**[3:30 - 4:30] Model Comparison**

> "Now let's compare with Google's Gemini model using the exact same query."

**Do:**
- Create new conversation
- Settings → select "Gemini"
- Send **exact same query**: `"Plan a 2-day trip to Rome with historical sites"`
- Watch different response structure

> "Notice Gemini's response might be more verbose, or structure recommendations differently. This is what makes the research interesting - comparing how different training data and architectures affect output."

**Side-by-side comparison:**
- Switch back to GPT conversation
- Show response
- Switch to Gemini conversation
- Show response
- Discuss differences

---

**[4:30 - 5:00] Hybrid Processing & Architecture**

> "The hybrid mode sends the query to GPT first, then passes that response to Gemini for refinement and fact-checking. This is interesting from a research perspective - is two-stage processing worth the added latency and cost?"

**Show:**
- Switch to Swagger UI (`localhost:5005/swagger`)
- Show `/model/gpt`, `/model/gemini`, `/model/hybrid` endpoints
- Briefly explain the architecture

> "All of this is stored in Firestore, allowing researchers to export conversations and analyze model performance, accuracy, location count, response structure, and more."

---

**[5:00] Closing**

> "This platform enables empirical research on LLM integration patterns. The code is open source, extensible to other AI models, and demonstrates modern patterns like factory design, streaming responses, and multi-model architectures."

**Optional extras if time:**
- Show Apple Intelligence option (on-device processing)
- Briefly show code structure
- Mention internationalization support (Dutch, French, English)

---

### Example Queries for Maximum Impact

**Visual Impact (many locations):**
```
"Design a photography tour of Iceland's top 8 natural wonders: waterfalls, geysers, and glaciers"
```

**Complex Multi-City:**
```
"Create a 7-day European capital tour: Paris → Amsterdam → Berlin → Prague, with major landmarks in each city"
```

**Nuanced Requirements:**
```
"Plan a romantic anniversary dinner in New York with Michelin-starred options, intimate ambiance, and views of the city"
```

**Creative Challenge:**
```
"Suggest 5 hidden gems in Kyoto that tourists rarely visit, focusing on authentic local experiences"
```

**Hybrid Processing Demo:**
```
"Develop a sustainable eco-tourism itinerary in Costa Rica with minimal environmental impact"
```

---

### Handling Q&A

**Q: How do you prevent AI hallucinations or fake locations?**

A: "We parse structured JSON output which includes coordinates. You can add validation by geocoding the coordinates and checking if they match the location name. Hybrid processing also helps as the second model can fact-check the first."

---

**Q: What about cost?**

A: "GPT-4o-mini is very cost-effective at $0.15 per million input tokens. For research usage with hundreds of queries, you're typically under $10/month. Gemini has a generous free tier. Hybrid mode doubles the cost but may provide better results."

---

**Q: Can this work offline?**

A: "Partial offline support. Conversations are cached locally, so you can view them offline. However, generating new AI responses requires the backend API. The exception is Apple Intelligence which processes on-device and works fully offline."

---

**Q: How accurate are the locations?**

A: "That's actually one of the research questions! In my tests, accuracy varies by model and query complexity. Hybrid processing tends to be most accurate. You can verify by checking each coordinate on Google Maps."

---

**Q: Can I add other AI models?**

A: "Absolutely. The architecture uses the factory pattern, so adding a new model is straightforward: add a backend endpoint, update the factory, add to settings UI. Takes about 30 minutes. I can show the code structure if interested."

---

## Feature Deep Dive

### AI Models Explained

#### GPT-4o-mini (OpenAI)

**When to use:**
- Need fast responses (1-3 seconds typical)
- Want consistent JSON formatting
- Cost-sensitive research (most economical)
- Baseline comparison for other models

**Characteristics:**
- Concise, to-the-point responses
- Excellent at following format instructions
- Good geographical knowledge
- Sometimes formulaic/predictable

**Best for:** Quick prototyping, high-volume testing

---

#### Gemini 2.5 Flash (Google)

**When to use:**
- Want alternative perspective vs OpenAI
- Budget-conscious (free tier available)
- Need conversational, detailed responses
- Comparing training approaches

**Characteristics:**
- Often more verbose than GPT
- Strong context understanding
- May generate longer descriptions
- JSON formatting less consistent

**Best for:** Comparative analysis, free tier research

---

#### Hybrid Mode (GPT + Gemini Pipeline)

**When to use:**
- Maximum quality desired
- Fact-checking is critical
- Research on multi-stage processing
- Not time-sensitive

**How it works:**
1. User query → GPT-4o-mini
2. GPT generates initial recommendations
3. GPT output + original query → Gemini
4. Gemini refines, fact-checks, enhances
5. Final Gemini output returned

**Trade-offs:**
- 2x latency (sum of both models)
- 2x cost (two API calls)
- Potentially higher accuracy
- More complex error handling

**Best for:** Research on whether dual-processing improves quality

---

#### Apple Intelligence (iOS Only)

**When to use:**
- Privacy is critical (data never leaves device)
- Offline capability needed
- No API costs desired
- iOS-specific features

**Characteristics:**
- On-device neural engine processing
- Works completely offline
- No cost (included in device)
- Platform-specific (only Apple devices with Neural Engine)
- Generally less capable than cloud models

**Best for:** Privacy research, offline scenarios, cost elimination

---

### Map Features Explained

#### Marker Types

**1. Search Result Markers (Blue Pins)**
- Created when you manually search for places
- Uses Mapbox Geocoding API
- Tappable for details
- Temporary (not saved to conversation)

**2. AI-Generated Markers (Circle Annotations)**
- Created from AI response JSON
- Labeled with location name
- Saved to Firestore with conversation
- Persistent across app restarts

---

#### Routing

**Supported Types:**

**Walking:**
- Pedestrian paths, sidewalks, crosswalks
- Best for: City tours, sightseeing
- Typically shortest distance

**Driving:**
- Road network, fastest routes
- Best for: Day trips, distant locations
- Considers traffic data

**Cycling:**
- Bike-friendly routes where available
- Best for: Active exploration
- May not be available in all regions

**How to use:**
1. Get AI recommendations with multiple locations
2. Tap route button or select route type
3. System calculates optimal path
4. Polyline appears on map
5. Camera auto-fits to show entire route

---

#### Search & Geocoding

**Forward Geocoding:** Place name → Coordinates

Example: "Eiffel Tower" → (48.8584, 2.2945)

**Reverse Geocoding:** Coordinates → Place name

Example: (48.8584, 2.2945) → "Eiffel Tower, Paris, France"

**Two Services:**

1. **Mapbox Geocoding** (Primary):
   - Fast, accurate
   - Free tier sufficient
   - Autocomplete support

2. **Google Places** (Backup):
   - Richer data (ratings, photos)
   - More expensive
   - Better POI database

---

### Conversation Management

**Features:**

- **Multi-conversation support**: Create unlimited conversations
- **Real-time sync**: Changes across devices instantly
- **Automatic titles**: First message becomes title
- **Model tracking**: Each conversation remembers which model was used
- **Persistent**: Saved to Firestore, survives app restarts
- **Offline cache**: Recent conversations available offline

**Firestore Structure:**

```
conversations/{conversationId}
├── userId: string
├── title: string
├── model: string ("gpt" | "gemini" | "hybrid" | "apple")
├── createdAt: timestamp
├── updatedAt: timestamp
└── messages: [
    {
      role: "user" | "assistant",
      content: string,
      timestamp: timestamp,
      locations?: [...],
      routeType?: string
    }
  ]
```

**Accessing Data:**
- Firebase Console: View/edit conversations
- Programmatic: Export via Firebase Admin SDK
- App: View in conversation sidebar

---

## FAQ

**Q: Do I need to pay for API keys?**

A: OpenAI requires payment after $5 free credit. Gemini has generous free tier. Mapbox free tier (50K map loads/month) is usually sufficient for research.

---

**Q: Can I use this on Android?**

A: Currently iOS only. Extending to Android would require code modifications (platform-specific code, Firebase setup, testing), but Flutter makes this feasible.

---

**Q: How do I export my research data?**

A: See "For Researchers → Data Collection" section above. Use Firebase Console manually, or write a script with Firebase Admin SDK.

---

**Q: Can I modify the system prompts?**

A: Yes! Edit `packages/backend/Routes/RouteGroup.cs`, find the `systemPrompt` variable. Restart backend after changes.

---

**Q: What if the map doesn't show locations?**

A: Check that JSON parsing succeeded. AI must return properly formatted JSON code block. See troubleshooting section in INSTALLATION.md.

---

**Q: How do I add my own AI model?**

A: See "For Developers → Adding a New AI Model" section above. Requires backend endpoint, factory update, and UI change. About 30 minutes of work.

---

**Q: Can I use this for commercial projects?**

A: Check the LICENSE file. This is a research project - if adapting for commercial use, ensure compliance with all API terms of service (OpenAI, Google, Mapbox, Firebase).

---

**Q: How much does it cost to run?**

**Development:**
- Firebase: Free (Spark plan)
- Mapbox: Free (within limits)
- OpenAI: ~$5-10/month for moderate research usage
- Gemini: Free tier usually sufficient
- Total: ~$10/month

**Production (100 daily active users):**
- Would depend on usage patterns
- Estimate: $50-200/month depending on AI model usage

---

**Q: Is my data private?**

A:
- Conversations stored in your Firebase project (you control access)
- API calls to OpenAI/Google send your queries to their servers
- Apple Intelligence processes entirely on-device (most private)
- For maximum privacy: Use Apple Intelligence model

---

**Q: Can I contribute to the project?**

A: Yes! See README.md Contributing section. Fork the repo, make changes, submit pull request.

---

## Getting Help

If you need assistance:

1. **Check Documentation:**
   - INSTALLATION.md for setup issues
   - README.md for architecture overview
   - This guide for usage questions

2. **Common Issues:**
   - See INSTALLATION.md Troubleshooting section

3. **GitHub Issues:**
   - [github.com/thomasmoerman2/mono_research/issues](https://github.com/thomasmoerman2/mono_research/issues)
   - Search existing issues first
   - Provide details: error messages, logs, screenshots

4. **Community:**
   - Open GitHub Discussion for questions
   - Tag with appropriate labels

---

**Happy researching!** 🚀
