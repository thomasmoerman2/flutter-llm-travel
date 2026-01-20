# Gebruikershandleiding

**🇳🇱 Nederlands** | [🇬🇧 English](USER_GUIDE.md)

Volledige gids voor het gebruik van het AI-Powered Travel Planning Research Platform voor onderzoek, ontwikkeling en presentaties.

---

## Inhoudsopgave

- [Aan de Slag](#aan-de-slag)
- [Voor Onderzoekers](#voor-onderzoekers)
- [Voor Ontwikkelaars](#voor-ontwikkelaars)
- [Voor Presentatoren](#voor-presentatoren)
- [Functionaliteit Uitgelegd](#functionaliteit-uitgelegd)
- [Veelgestelde Vragen](#veelgestelde-vragen)

---

## Aan de Slag

### Eerste Keer Opstarten

1. **Start de Backend:**
   ```bash
   cd packages/backend
   dotnet run
   ```
   Wacht op: `Now listening on: http://localhost:5005`

2. **Start de iOS App:**
   ```bash
   # Open iOS Simulator als deze nog niet draait
   open -a Simulator

   # In een andere terminal
   cd packages/app
   flutter run
   ```

3. **Maak een Account:**
   - App toont login scherm
   - Tik op "Register" of "Create Account"
   - Voer email en wachtwoord in
   - Tik op "Sign Up"

4. **Je bent Klaar!**
   - Je wordt naar de hoofd chat interface gebracht
   - Je gesprekken worden automatisch opgeslagen

### Snel Start: Eerste Gesprek

1. **Selecteer AI Model** (Settings tab/tandwiel icoon):
   - GPT (aanbevolen voor eerste poging)
   - Gemini
   - Hybrid
   - Apple Intelligence (alleen iOS)

2. **Verstuur een Query:**
   ```
   "Plan een 2-daagse reis naar Parijs met must-see bezienswaardigheden"
   ```

3. **Bekijk het Antwoord:**
   - Tekst komt woord-voor-woord binnen
   - JSON locatiedata wordt automatisch geëxtraheerd

4. **Bekijk op Kaart:**
   - Tik op "Map" tab
   - Zie markers voor alle locaties
   - Tik op markers voor details

5. **Genereer Route (Optioneel):**
   - Tik op route knop of selecteer route type
   - Kies: Wandelen, Rijden, of Fietsen
   - Route polyline verschijnt op kaart

---

## Voor Onderzoekers

### AI Model Vergelijkingsstudies Uitvoeren

#### Experimentele Opzet

**Doel:** Vergelijk hoe verschillende AI modellen reisaanbevelingen structureren

**1. Maak Test Dataset**

Bereid gestandaardiseerde queries voor met verschillende complexiteitsniveaus:

**Eenvoudige queries:**
- "Beveel 5 restaurants aan in Tokio"
- "Beste musea in Barcelona"

**Gemiddelde complexiteit:**
- "Plan een 3-daagse reis naar Rome met historische plekken"
- "Maak een food tour route in Parijs"

**Complexe queries:**
- "Ontwerp een 2-weken multi-land route: Frankrijk → Italië → Griekenland met mix van cultuur, eten en natuur"
- "Plan een gezinsvriendelijke reis naar IJsland met kinderen van 8 en 12 jaar, focus op geothermische plekken en watervallen"

**2. Test Elk Model**

Voor elke query:

a. **Maak Nieuw Gesprek:**
   - Tik op "New Chat" knop
   - Zorgt voor schone lei voor elke test

b. **Selecteer Model:**
   - Settings → AI Model
   - Kies: GPT, Gemini, of Hybrid

c. **Verstuur Query:**
   - Copy-paste exacte query (zorgt voor consistentie)
   - Wacht op volledig antwoord

d. **Noteer Observaties:**
   - Antwoordtijd (hoe lang tot compleet)
   - Aantal locaties (hoeveel plekken voorgesteld)
   - Antwoordstructuur (beknopt vs uitgebreid)
   - JSON geldigheid (is parsing gelukt?)

e. **Bewaar Screenshot:**
   - iOS: Druk Volume Up + Side Button
   - Screenshots opgeslagen in Photos app

f. **Controleer Kaart:**
   - Wissel naar Map tab
   - Verifieer dat locaties correct geplaatst zijn
   - Noteer ontbrekende of incorrecte markers

**3. Herhaal voor Alle Modellen**

Verstuur dezelfde query naar:
- GPT model
- Gemini model
- Hybrid model
- (Optioneel) Apple Intelligence

Houd gesprekken gescheiden voor makkelijke vergelijking.

---

#### Data Verzameling

**Geautomatiseerde Export vanuit Firestore**

**Methode 1: Firebase Console (Handmatig)**

1. Open [Firebase Console](https://console.firebase.google.com)
2. Selecteer je project
3. Navigeer naar Firestore Database
4. Klik op "conversations" collectie
5. Klik op gesprek document
6. Kopieer JSON data
7. Plak in spreadsheet of analyse tool

**Methode 2: Programmatische Export (Aanbevolen)**

Maak een Node.js script om alle gesprekken te exporteren:

```javascript
// export-conversations.js
const admin = require('firebase-admin');
const fs = require('fs');

// Initialiseer met je service account
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

  // Bewaar naar JSON bestand
  fs.writeFileSync(
    'conversations_export.json',
    JSON.stringify(conversations, null, 2)
  );

  console.log(`${conversations.length} gesprekken geëxporteerd`);
}

// Krijg je user ID van Firebase Console → Authentication
exportConversations('YOUR_USER_ID_HERE');
```

**Voer het script uit:**
```bash
npm install firebase-admin
node export-conversations.js
```

**Methode 3: Firebase CLI**

```bash
# Exporteer volledige Firestore database
firebase firestore:export gs://your-bucket-name/exports/conversations

# Download van Cloud Storage
gsutil cp -r gs://your-bucket-name/exports/conversations ./firestore-backup
```

---

#### Analyse Metrics

**Kwantitatieve Metrics**

| Metric | Hoe te Meten | Doel |
|--------|--------------|------|
| **Antwoordtijd** | Noteer tijd van versturen tot voltooiing | Vergelijk modelsnelheid |
| **Token Count** | Woord count of gebruik tokenizer | Beoordeel uitgebreidheid, schat kosten |
| **Aantal Locaties** | Parse JSON, tel `locations` array | Vergelijk volledigheid |
| **JSON Geldigheid** | Controleer of parser data extracteerde | Meet betrouwbaarheid gestructureerde output |
| **Coördinaat Nauwkeurigheid** | Verifieer elke locatie op Google Maps | Beoordeel feitelijke correctheid |
| **Route Geschiktheid** | Is wandelen/rijden logisch voor afstanden? | Meet redeneerkwaliteit |

**Voorbeeld Python Analyse:**

```python
import json
import pandas as pd

# Laad geëxporteerde data
with open('conversations_export.json') as f:
    data = json.load(f)

# Extraheer metrics
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

# Vergelijk modellen
print("\n=== Model Vergelijking ===")
print(df.groupby('model').agg({
    'response_length': 'mean',
    'location_count': 'mean',
    'has_json': 'mean'
}))

# Statistische tests
from scipy import stats
gpt_lengths = df[df['model'] == 'gpt']['response_length']
gemini_lengths = df[df['model'] == 'gemini']['response_length']
t_stat, p_value = stats.ttest_ind(gpt_lengths, gemini_lengths)
print(f"\nT-test p-waarde: {p_value}")
```

**Kwalitatieve Metrics**

Maak evaluatie rubric (1-5 schaal):

| Criterium | 1 (Slecht) | 3 (Goed) | 5 (Uitstekend) |
|-----------|-----------|----------|----------------|
| **Creativiteit** | Generiek, voorspelbaar | Enkele unieke ideeën | Zeer creatief, gepersonaliseerd |
| **Nauwkeurigheid** | Verkeerde locaties | Meestal correct | 100% geverifieerd correct |
| **Samenhang** | Onsamenhangende, willekeurige volgorde | Logische flow | Naadloos verhaal, perfecte volgorde |
| **Volledigheid** | Mist belangrijke details | Adequate informatie | Uitgebreid met extra's |
| **Beschrijvingskwaliteit** | Minimaal of geen | Degelijke beschrijvingen | Rijk, boeiende beschrijvingen |

**Blinde Evaluatie:**
- Gebruik meerdere beoordelaars
- Toon antwoorden zonder te onthullen welk model
- Bereken inter-rater reliability (Cohen's kappa)

---

#### Onderzoeksvragen om te Verkennen

**1. Model Nauwkeurigheid Vergelijking**

**Hypothese:** Verschillende LLMs hebben variërende locatie nauwkeurigheidspercentages.

**Methode:**
- Verstuur 50 reisqueries naar elk model
- Verifieer handmatig elke coördinaat op Google Maps
- Bereken nauwkeurigheidspercentage per model

**Verwachte Bevinding:** Hybrid modus kan hoogste nauwkeurigheid hebben door dubbele verificatie.

**2. Antwoordstructuur Analyse**

**Hypothese:** Modellen organiseren informatie verschillend gebaseerd op trainingsdata.

**Methode:**
- Analyseer JSON structuur (plat vs genest)
- Tel gemiddelde locaties per antwoord
- Categoriseer organisatiepatronen

**Voorbeeld Patronen:**
- Chronologisch (dag 1, dag 2, dag 3)
- Geografisch (per buurt/wijk)
- Thematisch (musea samen, restaurants samen)
- Gemengde aanpak

**3. Hybrid Processing Waarde**

**Hypothese:** Twee-fase processing verbetert kwaliteit maar voegt latency toe.

**Methode:**
- Dezelfde 30 queries naar GPT-alleen vs Hybrid
- Meet antwoordtijd voor beide
- Vergelijk output kwaliteit (nauwkeurigheid, volledigheid)
- Bereken kostenverschil

**Analyse:** Rechtvaardigt de verbetering de 2x kosten en latency?

**4. Gebruikersvoorkeur Studie**

**Hypothese:** Gebruikers geven voorkeur aan bepaalde model outputs.

**Methode:**
- Rekruteer 20+ deelnemers
- Toon geanonimiseerde antwoorden van verschillende modellen
- Vraag: "Welke zou je gebruiken voor echte reisplanning?"
- Bereken voorkeurpercentages

**Statistische Analyse:** Chi-kwadraat test voor significantie

---

#### Tips voor Geldig Onderzoek

**Controleer Variabelen:**
- Gebruik zelfde apparaat (vermijd iOS vs simulator verschillen)
- Zelfde tijd van dag (modelprestaties kunnen variëren)
- Zelfde netwerkcondities
- Zelfde systeem prompts (al gecontroleerd in backend)
- Zelfde gebruikersaccount

**Documenteer Alles:**
- Exacte modelversies (controleer OpenAI/Google docs)
- SDK versies (controleer package.json, backend.csproj)
- Datum van experimenten (modellen worden regelmatig geüpdatet)
- Gebruikte systeem prompt

**Steekproefgrootte:**
- Minimaal 30 queries per conditie voor statistische power
- Meer complexe analyses hebben 50+ nodig

**Reproduceerbaarheid:**
- Bewaar alle queries in spreadsheet
- Exporteer ruwe data (JSON van Firestore)
- Documenteer analyse scripts
- Voeg toe in onderzoekspaper bijlage

---

## Voor Ontwikkelaars

### De Applicatie Uitbreiden

#### Een Nieuw AI Model Toevoegen

**Voorbeeld: Claude (Anthropic) Toevoegen**

**Stap 1: Voeg Backend Endpoint Toe**

Bewerk `packages/backend/Routes/RouteGroup.cs`:

```csharp
// Voeg using statement toe bovenaan
using Anthropic.SDK;

// Binnen de ConfigureRoutes methode, voeg nieuw endpoint toe:
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
        logger.LogError(ex, "Claude API fout");
        return Results.Problem($"Fout: {ex.Message}");
    }
}).RequireAuthorization();
```

**Stap 2: Voeg API Key toe aan Configuratie**

Bewerk `packages/backend/appsettings.Development.json`:

```json
{
  "ClaudeAPIKey": "sk-ant-YOUR-KEY-HERE",
  // ... andere keys
}
```

**Stap 3: Update Flutter Service Factory**

Bewerk `packages/app/lib/services/ai/ai_service_factory.dart`:

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

**Stap 4: Update Settings UI**

Bewerk `packages/app/lib/routes/settings_page.dart`, voeg toe aan model dropdown:

```dart
DropdownMenuItem(
  value: 'claude',
  child: Text('Claude (Anthropic)'),
),
```

**Stap 5: Test**

```bash
# Herstart backend
cd packages/backend
dotnet run

# Hot reload Flutter app (druk 'r' in terminal waar app draait)
# Of herstart volledig (druk 'R')

# Selecteer Claude model in settings
# Verstuur test query
```

---

#### Systeem Prompts Aanpassen

Systeem prompts controleren AI gedrag en output formaat.

**Locatie:** `packages/backend/Routes/RouteGroup.cs`

**Huidige Prompt:**

```csharp
const string systemPrompt = @"
Je bent een reisplanning assistent. Wanneer gebruikers vragen om reisaanbevelingen, plaatsen, routes, of reisplannen:

1. Geef een behulpzaam overzicht in natuurlijke taal
2. Voeg een JSON code block toe met locatiedata (gebruik ```json code block)
3. Verplichte JSON velden: name (string), lat (number), lng (number)
4. Optionele JSON velden: description (string), day (number voor meerdaagse reizen)
5. Optioneel: routeType veld met waarden: 'driving', 'walking', of 'cycling'

Voorbeeld formaat:
{
  ""locations"": [
    {""name"": ""Eiffel Tower"", ""lat"": 48.8584, ""lng"": 2.2945, ""description"": ""Iconisch monument"", ""day"": 1}
  ],
  ""routeType"": ""walking""
}
";
```

**Aanpassingsvoorbeelden:**

**Voor Meer Gedetailleerde Antwoorden:**

```csharp
const string systemPrompt = @"
Je bent een expert reisplanner met diepe kennis van wereldwijde bestemmingen. Wanneer gebruikers vragen om reisaanbevelingen:

1. Geef boeiende, gedetailleerde verhalen over elke locatie
2. Voeg lokale tips, beste tijden om te bezoeken, en insider kennis toe
3. Voeg altijd JSON code block toe met gestructureerde data
4. Voeg historische context en culturele betekenis toe aan beschrijvingen

[... rest van prompt ...]
";
```

**Voor Budgetbewuste Reizen:**

```csharp
const string systemPrompt = @"
Je bent een budget reis expert. Bij het plannen van reizen:

1. Prioriteer gratis of goedkope activiteiten
2. Vermeld geschatte kosten indien bekend
3. Suggereer geldbesparende tips
4. Voeg JSON toe met locatiedata

Voeg optioneel 'cost' veld toe aan JSON (low/medium/high)

[... rest van prompt ...]
";
```

**Prompt Wijzigingen Testen:**

1. Bewerk de prompt in `RouteGroup.cs`
2. Bewaar bestand
3. Herstart backend (`Ctrl+C`, dan `dotnet run`)
4. Verstuur test queries
5. Vergelijk outputs

**Tips:**
- Wees specifiek over JSON structuur (parser hangt af van exacte veldnamen)
- Voeg few-shot voorbeelden toe voor consistentie
- Test met diverse queries
- Documenteer prompt versie in onderzoeksnotities

---

#### Kaartgedrag Aanpassen

**Locatie:** `packages/app/lib/routes/map_page.dart`

**Markerstijl Wijzigen:**

```dart
// Vind marker creatie code rond regel 300-400
// Huidig: Blauwe pin markers

// Custom kleur marker:
pointAnnotationManager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    iconColor: Colors.red.value,  // Verander kleur
    iconSize: 1.2,                 // Pas grootte aan
    textField: location.name,      // Label
    textSize: 14.0,                // Tekstgrootte
  ),
);

// Custom image marker:
pointAnnotationManager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    iconImage: "custom-pin",  // Asset naam
    iconSize: 1.5,
    textField: location.name,
  ),
);
// Opmerking: Registreer eerst custom image in assets
```

**Route Lijn Stijl Wijzigen:**

```dart
// Vind polyline creatie code
polylineAnnotationManager.create(
  PolylineAnnotationOptions(
    geometry: LineString(coordinates: routeCoordinates),
    lineColor: Colors.blue.value,  // Verander naar elke kleur
    lineWidth: 8.0,                 // Maak dikker
    lineOpacity: 0.8,               // Voeg transparantie toe
    lineCap: LineCap.ROUND,         // Afgeronde uiteinden
    lineJoin: LineJoin.ROUND,       // Afgeronde hoeken
  ),
);
```

**Camera Animatie Wijzigen:**

```dart
// Vind _fitCameraToBounds methode
void _fitCameraToBounds(List<LatLng> locations) {
  // ... bounding box berekening ...

  mapboxMap.flyTo(
    CameraOptions(
      center: centerPoint,
      zoom: calculatedZoom,
      bearing: 0,          // Kaart rotatie (0 = noord omhoog)
      pitch: 45,           // 3D tilt (0-60 graden)
    ),
    MapAnimationOptions(
      duration: 2000,      // Animatie tijd in ms (standaard 1000)
      startDelay: 500,     // Vertraging voor start
    ),
  );
}
```

**Voeg Custom Kaartstijl Toe:**

```dart
// In initState of kaart initialisatie
mapboxMap = await MapboxMap.create(
  MapOptions(
    styleUri: MapboxStyles.OUTDOORS,  // Verander stijl
    // Opties: STREETS, OUTDOORS, LIGHT, DARK, SATELLITE, SATELLITE_STREETS

    center: Point(coordinates: Position(-74.0060, 40.7128)),
    zoom: 12.0,
  ),
);
```

---

#### Nieuwe Features Toevoegen

**Voorbeeld: Voeg "Favorieten" Feature Toe**

**1. Update Firestore Schema:**

Voeg `favorites` veld toe aan gesprek document:

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

Voeg ster icoon toe aan gespreklijst:

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

**3. Voeg Filter Toe:**

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
- Tik op ster icoon bij gesprek
- Verifieer dat het blijft na herstart
- Controleer Firestore Console om `favorite: true` te zien

---

## Voor Presentatoren

### 5-Minuten Demo Script

**Pre-Demo Checklist** (10 minuten van tevoren):

- [ ] Backend draait (`npm run dev:backend`)
- [ ] iOS simulator open met app draaiend
- [ ] Test account ingelogd
- [ ] Maak vooraf test gesprek (optionele backup)
- [ ] Browser open op `localhost:5005/swagger`
- [ ] Voorbeeldqueries klaar om te copy-pasten
- [ ] Screen recording software klaar (optioneel)

---

**Demo Flow:**

**[0:00 - 0:30] Introductie**

> "Dit is een onderzoeksproject dat verkent hoe verschillende AI modellen reisaanbevelingen structureren. Het is gebouwd met Flutter voor iOS en .NET 9 voor de backend, en integreert meerdere LLM providers: OpenAI GPT, Google Gemini, en een hybride verwerkingspipeline."

**Toon:**
- Projectstructuur kort (als je code deelt)
- Of spring direct naar de app

---

**[0:30 - 1:00] Authenticatie**

> "De app gebruikt Firebase Authentication voor gebruikersbeheer. Alle gesprekken worden real-time opgeslagen in Firestore."

**Toon:**
- Login scherm
- Snelle login (of gebruik Touch ID indien beschikbaar)

---

**[1:00 - 2:00] Basis Query - GPT Model**

> "Laten we beginnen met het GPT-4o-mini model. Let op hoe het antwoord woord-voor-woord binnenkomt, wat een natuurlijk conversationeel gevoel creëert."

**Doe:**
- Navigeer naar Settings, toon modelselectie
- Selecteer "GPT"
- Keer terug naar chat
- Verstuur query: `"Plan een 2-daagse reis naar Rome met historische plekken"`
- Bekijk streaming antwoord
- Wijs op natuurlijke taal antwoord

> "Let op hoe de AI het antwoord structureert met dag-per-dag indeling"

---

**[2:00 - 2:45] Kaartvisualisatie**

> "Het systeem extraheert automatisch locatiedata uit het AI antwoord en visualiseert het op een kaart met Mapbox."

**Doe:**
- Wissel naar Map tab
- Toon markers voor alle locaties
- Tik op een marker om details te tonen
- Zoom in/uit, pan rond

> "Elke locatie heeft coördinaten en beschrijvingen geëxtraheerd via JSON parsing uit de tekstoutput van de AI."

---

**[2:45 - 3:30] Route Generatie**

> "We kunnen ook geoptimaliseerde routes genereren tussen locaties met de Mapbox Directions API."

**Doe:**
- Tik op route knop of selecteer route type
- Kies "Walking"
- Bekijk polyline verschijnen die locaties verbindt
- Toon camera auto-fitting naar volledige route

> "Het systeem berekent automatisch de bounding box en past de camera aan om alle punten te tonen"

---

**[3:30 - 4:30] Modelvergelijking**

> "Laten we nu vergelijken met Google's Gemini model met exact dezelfde query."

**Doe:**
- Maak nieuw gesprek
- Settings → selecteer "Gemini"
- Verstuur **exact dezelfde query**: `"Plan een 2-daagse reis naar Rome met historische plekken"`
- Bekijk verschillende antwoordstructuur

> "Let op dat Gemini's antwoord mogelijk uitgebreider is, of aanbevelingen anders structureert. Dit maakt het onderzoek interessant - vergelijken hoe verschillende trainingsdata en architecturen de output beïnvloeden."

**Kant-aan-kant vergelijking:**
- Wissel terug naar GPT gesprek
- Toon antwoord
- Wissel naar Gemini gesprek
- Toon antwoord
- Bespreek verschillen

---

**[4:30 - 5:00] Hybrid Processing & Architectuur**

> "De hybrid modus stuurt de query eerst naar GPT, en geeft dat antwoord vervolgens door aan Gemini voor verfijning en fact-checking. Dit is interessant vanuit onderzoeksperspectief - is twee-fase processing de toegevoegde latency en kosten waard?"

**Toon:**
- Wissel naar Swagger UI (`localhost:5005/swagger`)
- Toon `/model/gpt`, `/model/gemini`, `/model/hybrid` endpoints
- Leg kort architectuur uit

> "Dit alles wordt opgeslagen in Firestore, waardoor onderzoekers gesprekken kunnen exporteren en modelprestaties, nauwkeurigheid, aantal locaties, antwoordstructuur en meer kunnen analyseren."

---

**[5:00] Afsluiting**

> "Dit platform maakt empirisch onderzoek naar LLM integratie patronen mogelijk. De code is open source, uitbreidbaar naar andere AI modellen, en demonstreert moderne patronen zoals factory design, streaming responses, en multi-model architecturen."

**Optionele extra's indien tijd:**
- Toon Apple Intelligence optie (on-device verwerking)
- Laat kort code structuur zien
- Vermeld internationalisatie ondersteuning (Nederlands, Frans, Engels)

---

### Voorbeeldqueries voor Maximale Impact

**Visuele Impact (veel locaties):**
```
"Ontwerp een fotografietour van IJslands top 8 natuurwonderen: watervallen, geysers en gletsjers"
```

**Complex Multi-City:**
```
"Maak een 7-daagse Europese hoofdstad tour: Parijs → Amsterdam → Berlijn → Praag, met belangrijke bezienswaardigheden in elke stad"
```

**Genuanceerde Vereisten:**
```
"Plan een romantisch jubileumdiner in New York met Michelin-ster opties, intieme ambiance, en uitzicht over de stad"
```

**Creatieve Uitdaging:**
```
"Suggereer 5 verborgen pareltjes in Kyoto die toeristen zelden bezoeken, focus op authentieke lokale ervaringen"
```

**Hybrid Processing Demo:**
```
"Ontwikkel een duurzame eco-toerisme route in Costa Rica met minimale milieu-impact"
```

---

### Q&A Afhandelen

**V: Hoe voorkom je AI hallucinaties of neppe locaties?**

A: "We parsen gestructureerde JSON output die coördinaten bevat. Je kunt validatie toevoegen door de coördinaten te geocoden en te controleren of ze overeenkomen met de locatienaam. Hybrid processing helpt ook omdat het tweede model het eerste kan fact-checken."

---

**V: Wat zijn de kosten?**

A: "GPT-4o-mini is zeer kosteneffectief op $0.15 per miljoen input tokens. Voor onderzoeksgebruik met honderden queries, zit je meestal onder $10/maand. Gemini heeft een royale gratis tier. Hybrid modus verdubbelt de kosten maar kan betere resultaten geven."

---

**V: Kan dit offline werken?**

A: "Gedeeltelijke offline ondersteuning. Gesprekken worden lokaal gecached, dus je kunt ze offline bekijken. Echter, nieuwe AI antwoorden genereren vereist de backend API. De uitzondering is Apple Intelligence dat on-device verwerkt en volledig offline werkt."

---

**V: Hoe nauwkeurig zijn de locaties?**

A: "Dat is eigenlijk een van de onderzoeksvragen! In mijn tests varieert nauwkeurigheid per model en query complexiteit. Hybrid processing is meestal het meest nauwkeurig. Je kunt verifiëren door elke coördinaat op Google Maps te controleren."

---

**V: Kan ik andere AI modellen toevoegen?**

A: "Absoluut. De architectuur gebruikt het factory patroon, dus een nieuw model toevoegen is eenvoudig: voeg een backend endpoint toe, update de factory, voeg toe aan settings UI. Duurt ongeveer 30 minuten. Ik kan de code structuur laten zien als je geïnteresseerd bent."

---

## Functionaliteit Uitgelegd

### AI Modellen Uitgelegd

#### GPT-4o-mini (OpenAI)

**Wanneer te gebruiken:**
- Snelle antwoorden nodig (1-3 seconden typisch)
- Consistente JSON formattering gewenst
- Kostengevoelig onderzoek (meest economisch)
- Baseline vergelijking voor andere modellen

**Kenmerken:**
- Beknopte, to-the-point antwoorden
- Uitstekend in het volgen van formaat instructies
- Goede geografische kennis
- Soms formalistisch/voorspelbaar

**Beste voor:** Snel prototypen, hoogvolume testen

---

#### Gemini 2.5 Flash (Google)

**Wanneer te gebruiken:**
- Alternatief perspectief vs OpenAI gewenst
- Budgetbewust (gratis tier beschikbaar)
- Conversationele, gedetailleerde antwoorden nodig
- Training benaderingen vergelijken

**Kenmerken:**
- Vaak uitgebreider dan GPT
- Sterke context begrip
- Kan langere beschrijvingen genereren
- JSON formattering minder consistent

**Beste voor:** Vergelijkende analyse, gratis tier onderzoek

---

#### Hybrid Modus (GPT + Gemini Pipeline)

**Wanneer te gebruiken:**
- Maximale kwaliteit gewenst
- Fact-checking is cruciaal
- Onderzoek naar multi-stage processing
- Niet tijdgevoelig

**Hoe het werkt:**
1. Gebruikersquery → GPT-4o-mini
2. GPT genereert initiële aanbevelingen
3. GPT output + originele query → Gemini 2.5 Flash
4. Gemini verbetert, fact-checkt en verfijnt GPT output
5. Finale Gemini output geretourneerd

**Afwegingen:**
- 2x latency (som van beide modellen)
- 2x kosten (twee API calls)
- Mogelijk hogere nauwkeurigheid
- Complexere foutafhandeling

**Beste voor:** Onderzoek of dual-processing kwaliteit verbetert

---

#### Apple Intelligence (Alleen iOS)

**Wanneer te gebruiken:**
- Privacy is cruciaal (data verlaat apparaat nooit)
- Offline mogelijkheid nodig
- Geen API kosten gewenst
- iOS-specifieke features

**Kenmerken:**
- On-device neural engine verwerking
- Werkt volledig offline
- Geen kosten (inbegrepen in apparaat)
- Platform-specifiek (alleen Apple apparaten met Neural Engine)
- Over het algemeen minder capabel dan cloud modellen

**Beste voor:** Privacy onderzoek, offline scenario's, kosten eliminatie

---

### Kaart Features Uitgelegd

#### Marker Typen

**1. Zoekresultaat Markers (Blauwe Pins)**
- Gemaakt wanneer je handmatig naar plaatsen zoekt
- Gebruikt Mapbox Geocoding API
- Tappable voor details
- Tijdelijk (niet opgeslagen in gesprek)

**2. AI-Gegenereerde Markers (Cirkel Annotaties)**
- Gemaakt van AI antwoord JSON
- Gelabeld met locatienaam
- Opgeslagen in Firestore met gesprek
- Blijvend over app herstarts

---

#### Routing

**Ondersteunde Typen:**

**Wandelen:**
- Voetgangerspaden, trottoirs, zebrapaden
- Beste voor: Stadstours, sightseeing
- Typisch kortste afstand

**Rijden:**
- Wegennetwerk, snelste routes
- Beste voor: Dagtochten, verre locaties
- Houdt rekening met verkeersdata

**Fietsen:**
- Fietsvriendelijke routes waar beschikbaar
- Beste voor: Actieve verkenning
- Mogelijk niet beschikbaar in alle regio's

**Hoe te gebruiken:**
1. Krijg AI aanbevelingen met meerdere locaties
2. Tik op route knop of selecteer route type
3. Systeem berekent optimaal pad
4. Polyline verschijnt op kaart
5. Camera past automatisch aan om volledige route te tonen

---

#### Zoeken & Geocoding

**Forward Geocoding:** Plaatsnaam → Coördinaten

Voorbeeld: "Eiffeltoren" → (48.8584, 2.2945)

**Reverse Geocoding:** Coördinaten → Plaatsnaam

Voorbeeld: (48.8584, 2.2945) → "Eiffeltoren, Parijs, Frankrijk"

**Twee Services:**

1. **Mapbox Geocoding** (Primair):
   - Snel, nauwkeurig
   - Gratis tier voldoende
   - Autocomplete ondersteuning

2. **Google Places** (Backup):
   - Rijkere data (beoordelingen, foto's)
   - Duurder
   - Betere POI database

---

### Gespreks Beheer

**Features:**

- **Multi-gesprek ondersteuning**: Maak onbeperkt gesprekken
- **Real-time sync**: Wijzigingen over apparaten direct
- **Automatische titels**: Eerste bericht wordt titel
- **Model tracking**: Elk gesprek onthoudt welk model gebruikt werd
- **Blijvend**: Opgeslagen in Firestore, overleeft app herstarts
- **Offline cache**: Recente gesprekken beschikbaar offline

**Firestore Structuur:**

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

**Data Toegang:**
- Firebase Console: Bekijk/bewerk gesprekken
- Programmatisch: Exporteer via Firebase Admin SDK
- App: Bekijk in gesprek zijbalk

---

## Veelgestelde Vragen

**V: Moet ik betalen voor API keys?**

A: OpenAI vereist betaling na $5 gratis credit. Gemini heeft royale gratis tier. Mapbox gratis tier (50K kaartladingen/maand) is meestal voldoende voor onderzoek.

---

**V: Kan ik dit op Android gebruiken?**

A: Momenteel alleen iOS. Uitbreiden naar Android zou code aanpassingen vereisen (platform-specifieke code, Firebase setup, testen), maar Flutter maakt dit haalbaar.

---

**V: Hoe exporteer ik mijn onderzoeksdata?**

A: Zie "Voor Onderzoekers → Data Verzameling" sectie hierboven. Gebruik Firebase Console handmatig, of schrijf een script met Firebase Admin SDK.

---

**V: Kan ik de systeem prompts aanpassen?**

A: Ja! Bewerk `packages/backend/Routes/RouteGroup.cs`, vind de `systemPrompt` variabele. Herstart backend na wijzigingen.

---

**V: Wat als de kaart geen locaties toont?**

A: Controleer dat JSON parsing gelukt is. AI moet correct geformatteerd JSON code block retourneren. Zie troubleshooting sectie in INSTALLATION_NL.md.

---

**V: Hoe voeg ik mijn eigen AI model toe?**

A: Zie "Voor Ontwikkelaars → Een Nieuw AI Model Toevoegen" sectie hierboven. Vereist backend endpoint, factory update, en UI wijziging. Ongeveer 30 minuten werk.

---

**V: Kan ik dit gebruiken voor commerciële projecten?**

A: Controleer het LICENSE bestand. Dit is een onderzoeksproject - indien aangepast voor commercieel gebruik, zorg voor naleving van alle API servicevoorwaarden (OpenAI, Google, Mapbox, Firebase).

---

**V: Hoeveel kost het om te draaien?**

**Ontwikkeling:**
- Firebase: Gratis (Spark plan)
- Mapbox: Gratis (binnen limieten)
- OpenAI: ~$5-10/maand voor matig onderzoeksgebruik
- Gemini: Gratis tier meestal voldoende
- Totaal: ~$10/maand

**Productie (100 dagelijkse actieve gebruikers):**
- Hangt af van gebruikspatronen
- Schatting: $50-200/maand afhankelijk van AI model gebruik

---

**V: Is mijn data privé?**

A:
- Gesprekken opgeslagen in jouw Firebase project (jij controleert toegang)
- API calls naar OpenAI/Google sturen je queries naar hun servers
- Apple Intelligence verwerkt volledig on-device (meest privé)
- Voor maximale privacy: Gebruik Apple Intelligence model

---

**V: Kan ik bijdragen aan het project?**

A: Ja! Zie README.md Contributing sectie. Fork de repo, maak wijzigingen, dien pull request in.

---

## Hulp Krijgen

Als je hulp nodig hebt:

1. **Controleer Documentatie:**
   - INSTALLATION_NL.md voor setup problemen
   - README.md voor architectuuroverzicht
   - Deze gids voor gebruiksvragen

2. **Veelvoorkomende Problemen:**
   - Zie INSTALLATION_NL.md Probleemoplossing sectie

3. **GitHub Issues:**
   - [github.com/thomasmoerman2/mono_research/issues](https://github.com/thomasmoerman2/mono_research/issues)
   - Zoek eerst bestaande issues
   - Geef details: foutmeldingen, logs, screenshots

4. **Community:**
   - Open GitHub Discussion voor vragen
   - Tag met toepasselijke labels

---

**Veel onderzoeksplezier!** 🚀
