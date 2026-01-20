# Installatiehandleiding

**🇳🇱 Nederlands** | [🇬🇧 English](INSTALLATION.md)

Volledige stapsgewijze instructies voor het opzetten van het AI-Powered Travel Planning Research Platform.

> **Platformvereiste**: Dit project vereist **macOS met Xcode** voor iOS ontwikkeling.

---

## Inhoudsopgave

- [Vereisten](#vereisten)
- [Benodigde Software](#benodigde-software)
- [Benodigde API Keys & Services](#benodigde-api-keys--services)
- [Installatiestappen](#installatiestappen)
- [Verificatie](#verificatie)
- [Probleemoplossing](#probleemoplossing)

---

## Vereisten

Voordat je begint, zorg ervoor dat je het volgende hebt:

- macOS computer (vereist voor iOS ontwikkeling)
- Actieve internetverbinding
- Apple ID (voor Xcode)
- Ongeveer 30-60 minuten voor volledige installatie

---

## Benodigde Software

### 1. Flutter SDK 3.10.4 of nieuwer

**Waarom Flutter?** Moderne iOS ontwikkeling met hot reload voor snelle iteratie, uitstekende prestaties, en potentieel voor toekomstige cross-platform uitbreiding.

**Waarom versie 3.10.4+?** Stabiele release met benodigde features voor Mapbox integratie en Firebase compatibiliteit.

**Installatie:**

1. Bezoek [flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
2. Download de Flutter SDK
3. Pak het archief uit:
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_*.zip
   ```
4. Voeg Flutter toe aan je PATH:
   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```
5. Voeg toe aan je shell profiel (`~/.zshrc` of `~/.bash_profile`):
   ```bash
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
   ```
6. Verifieer installatie:
   ```bash
   flutter doctor
   ```

> **Let op**: macOS is vereist voor iOS ontwikkeling. Windows/Linux gebruikers kunnen de backend draaien maar kunnen de iOS app niet bouwen/draaien.

---

### 2. Xcode 13+ (Vereist)

**Waarom Xcode?** Apple's officiële IDE, vereist voor iOS ontwikkeling, bevat iOS simulator en build tools.

**Installatie:**

1. Open App Store op macOS
2. Zoek naar "Xcode"
3. Klik op "Ophalen" of "Installeren" (dit kan 30+ minuten duren)
4. Open Xcode zodra geïnstalleerd
5. Accepteer de licentieovereenkomst
6. Installeer aanvullende componenten wanneer gevraagd

**Command-line configuratie:**

```bash
# Installeer Xcode Command Line Tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Accepteer licentie
sudo xcodebuild -license accept
```

---

### 3. CocoaPods

**Waarom CocoaPods?** Dependency manager voor iOS projecten, vereist voor Firebase en Mapbox integratie.

**Installatie:**

```bash
sudo gem install cocoapods
pod setup
```

**Verifieer installatie:**
```bash
pod --version
```

---

### 4. .NET SDK 9.0

**Waarom .NET 9?** Nieuwste LTS versie, minimale APIs voor cleane endpoint definities, uitstekende async/await ondersteuning voor AI model streaming.

**Installatie:**

1. Bezoek [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0)
2. Download de macOS installer (.pkg)
3. Voer de installer uit
4. Volg de installatie prompts

**Verifieer installatie:**
```bash
dotnet --version
# Moet 9.0.x tonen
```

---

### 5. Node.js & npm

**Waarom Node.js?** Vereist voor Lerna monorepo beheer en gecoördineerde script uitvoering.

**Aanbevolen Versie:** Node.js 18+ LTS

**Installatie:**

1. Bezoek [nodejs.org](https://nodejs.org)
2. Download de LTS versie voor macOS
3. Voer de installer uit (.pkg)
4. Volg de installatie prompts

**Verifieer installatie:**
```bash
node --version
npm --version
```

---

### 6. Git (Versiebeheer)

**Installatie (indien nog niet geïnstalleerd):**

```bash
# Git komt meestal met Xcode Command Line Tools
git --version

# Indien niet geïnstalleerd, installeer via Homebrew
brew install git
```

---

## Benodigde API Keys & Services

### 1. OpenAI API Key

**Doel:** GPT-4o-mini model voor reisaanbevelingen

**Hoe te verkrijgen:**

1. Maak een account aan op [platform.openai.com](https://platform.openai.com)
2. Navigeer naar API sectie
3. Klik op "API keys" in de linker zijbalk
4. Klik op "Create new secret key"
5. Geef het een naam (bijv. "Travel Research")
6. Kopieer de key (begint met `sk-proj-...`)
7. **Bewaar het veilig** - je kunt het niet opnieuw bekijken

**Prijzen:**
- Pay-as-you-go: ~$0.15 per 1M tokens input, $0.60 per 1M tokens output (2025 prijzen)
- Gratis tier: $5 credit voor nieuwe accounts
- Typisch onderzoeksgebruik: $5-10/maand

---

### 2. Google Gemini API Key

**Doel:** Gemini 2.5 Flash model voor alternatief AI perspectief

**Hoe te verkrijgen:**

1. Bezoek [aistudio.google.com](https://aistudio.google.com)
2. Log in met Google account
3. Klik op "Get API key" knop
4. Klik op "Create API key"
5. Selecteer of maak een Google Cloud project
6. Kopieer de key (begint met `AIzaSy...`)

**Prijzen:**
- Royale gratis tier: 60 requests per minuut
- Na gratis tier: pay-as-you-go
- Typisch onderzoeksgebruik: Gratis tier is meestal voldoende

---

### 3. Mapbox Access Token

**Doel:** Kaartweergave, geocoding, routing, en plaatsen zoeken

**Hoe te verkrijgen:**

1. Maak een account aan op [mapbox.com](https://mapbox.com)
2. Navigeer naar Account → Tokens
3. Gebruik de standaard publieke token, of:
4. Klik op "Create a token"
5. Geef het een naam (bijv. "Travel App iOS")
6. Zorg dat deze scopes geselecteerd zijn:
   - `styles:read`
   - `fonts:read`
   - `datasets:read`
7. Klik op "Create token"
8. Kopieer de token (begint met `pk.eyJ1...`)

**Prijzen:**
- Gratis tier: 50.000 kaartladingen/maand
- Geocoding: 100.000 requests/maand gratis
- Directions: 100.000 requests/maand gratis
- Royaal voor onderzoeksprojecten

---

### 4. Firebase Project

**Doel:** Authenticatie, Firestore database, en backend authenticatie verificatie

#### Stap 1: Maak Firebase Project

1. Bezoek [console.firebase.google.com](https://console.firebase.google.com)
2. Klik op "Add project" of "Create a project"
3. Voer projectnaam in (bijv. "travel-ai-research")
4. Klik op "Continue"
5. Schakel Google Analytics uit (optioneel, niet nodig voor onderzoek)
6. Klik op "Create project"
7. Wacht op project creatie (kan 1-2 minuten duren)
8. Klik op "Continue" wanneer klaar

#### Stap 2: Activeer Firebase Authentication

1. In Firebase Console, klik op "Build" in linker zijbalk
2. Klik op "Authentication"
3. Klik op "Get started"
4. Onder "Sign-in method" tab
5. Klik op "Email/Password"
6. Activeer de toggle voor "Email/Password"
7. Laat "Email link" uitgeschakeld (niet nodig)
8. Klik op "Save"

#### Stap 3: Activeer Cloud Firestore

1. In Firebase Console, klik op "Build" in linker zijbalk
2. Klik op "Firestore Database"
3. Klik op "Create database"
4. Kies "Start in test mode" (voor ontwikkeling)
5. Klik op "Next"
6. Selecteer Cloud Firestore locatie (kies dichtstbijzijnde)
7. Klik op "Enable"
8. Wacht op database creatie

**Beveiligingsregels (voor ontwikkeling):**

Na database creatie, klik op "Rules" tab en gebruik:

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

Klik op "Publish"

> **Productie opmerking**: Voor productie, implementeer strengere beveiligingsregels.

#### Stap 4: Registreer iOS App

1. In Firebase Project Overview, klik op het iOS icoon (+)
2. Voer iOS bundle ID in:
   - Standaard is meestal `com.example.app`
   - Om de jouwe te vinden: Open `packages/app/ios/Runner.xcodeproj` in Xcode
   - Selecteer "Runner" in linker zijbalk
   - Zoek naar "Bundle Identifier" onder "General" tab
3. Optioneel: Voer App nickname in (bijv. "Travel AI iOS")
4. Laat App Store ID leeg
5. Klik op "Register app"
6. Download `GoogleService-Info.plist`
7. **Belangrijk**: Bewaar dit bestand, je hebt het nodig in Stap 4 van Installatie

#### Stap 5: Genereer Firebase Admin SDK Credentials

**Voor Backend:**

1. In Firebase Console, klik op tandwiel icoon ⚙️ naast "Project Overview"
2. Klik op "Project settings"
3. Navigeer naar "Service accounts" tab
4. Klik op "Generate new private key"
5. Bevestig door te klikken op "Generate key"
6. Een JSON bestand wordt gedownload (bijv. `travel-ai-research-firebase-adminsdk-xxxxx.json`)
7. **Houd dit bestand extreem veilig**
8. **Commit dit nooit naar git**
9. Je gebruikt deze JSON inhoud in de backend configuratie

#### Stap 6: Configureer Firebase CLI (Optioneel maar Aanbevolen)

```bash
# Installeer Firebase CLI globaal
npm install -g firebase-tools

# Login bij Firebase
firebase login

# Dit opent browser voor authenticatie
```

**Prijzen:**
- Spark plan (gratis tier) is voldoende voor onderzoek:
  - Authentication: Onbeperkt gebruikers
  - Firestore: 1 GB opslag
  - Firestore: 50K reads/dag, 20K writes/dag

---

## Installatiestappen

### Stap 1: Clone de Repository

```bash
# Navigeer naar je ontwikkelingsmap
cd ~/Documents

# Clone de repository
git clone https://github.com/thomasmoerman2/mono_research.git

# Navigeer naar project
cd mono_research
```

---

### Stap 2: Installeer Root Dependencies

```bash
npm install
```

**Wat dit doet:** Installeert Lerna en zet monorepo workspace management op.

**Verwachte output:**
```
added 200 packages in 15s
```

---

### Stap 3: Backend Setup

#### Installeer Backend Dependencies

```bash
cd packages/backend
dotnet restore
```

**Wat dit doet:** Downloadt alle NuGet packages (OpenAI SDK, Google GenAI, Firebase Admin, Serilog, etc.)

**Verwachte output:**
```
Restore completed in 5.2 sec for backend.csproj
```

#### Configureer Backend API Keys

Maak `appsettings.Development.json` in `packages/backend/` map:

```bash
# Maak het bestand
touch packages/backend/appsettings.Development.json
```

Open het in je editor en voeg toe:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "OpenAIAPIKey": "YOUR_OPENAI_KEY_HERE",
  "GeminiAPIKey": "YOUR_GEMINI_KEY_HERE",
  "FirebaseCredentials": {
    "type": "service_account",
    "project_id": "your-project-id",
    "private_key_id": "your-private-key-id",
    "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com",
    "client_id": "your-client-id",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/v1/metadata/x509/firebase-adminsdk-xxxxx%40your-project-id.iam.gserviceaccount.com"
  },
  "CORS": "*"
}
```

**Vervang placeholders:**
- `YOUR_OPENAI_KEY_HERE` → Je OpenAI API key (sk-proj-...)
- `YOUR_GEMINI_KEY_HERE` → Je Gemini API key (AIzaSy...)
- `FirebaseCredentials` → Kopieer volledige JSON inhoud van Firebase Admin SDK bestand dat je hebt gedownload

**Configuratie Uitleg:**

- `OpenAIAPIKey`: Gebruikt door `/model/gpt` en `/model/hybrid` endpoints
- `GeminiAPIKey`: Gebruikt door `/model/gemini` en `/model/hybrid` endpoints
- `FirebaseCredentials`: Verifieert JWT tokens van Flutter app
- `CORS`: `"*"` staat alle origins toe (voor ontwikkeling). Voor productie, specificeer exacte URL

> **Beveiliging**: `appsettings.Development.json` staat in `.gitignore`. Commit nooit API keys.

---

### Stap 4: Flutter App Setup

#### Installeer Flutter Dependencies

```bash
cd ../app
# of vanaf root: cd packages/app

flutter pub get
```

**Wat dit doet:** Downloadt alle Flutter packages (Mapbox SDK, Firebase, HTTP client, etc.)

**Verwachte output:**
```
Running "flutter pub get" in app...
Resolving dependencies...
Got dependencies!
```

**Als je fouten ziet over Flutter SDK versie:**
```bash
flutter upgrade
flutter doctor
```

#### Plaats Firebase Configuratiebestand

1. Kopieer het `GoogleService-Info.plist` bestand dat je hebt gedownload van Firebase
2. Plaats het in `packages/app/ios/Runner/` map

```bash
# Vanaf packages/app map
cp ~/Downloads/GoogleService-Info.plist ios/Runner/

# Verifieer dat het er is
ls ios/Runner/GoogleService-Info.plist
```

#### Genereer Firebase Options (Aanbevolen)

```bash
# Zorg dat je in packages/app map bent
cd packages/app

# Configureer Flutter Firebase
flutterfire configure
```

**Volg de prompts:**
1. Selecteer je Firebase project
2. Wanneer gevraagd om platforms, **selecteer alleen iOS**
3. Druk op Enter om te bevestigen

Dit genereert automatisch `lib/firebase_options.dart`.

#### Configureer Environment Variables

Maak `.env` bestand in `packages/app/` map:

```bash
touch packages/app/.env
```

Open het en voeg toe:

```env
API_BASE_URL=http://localhost:5005
MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN_HERE
ENV=development
DEBUG=true
```

**Vervang placeholders:**
- `YOUR_MAPBOX_TOKEN_HERE` → Je Mapbox publieke token (pk.eyJ1...)

**Configuratie Uitleg:**

- `API_BASE_URL`: Backend REST API URL (localhost voor ontwikkeling)
- `MAPBOX_ACCESS_TOKEN`: Gebruikt door kaart SDK voor weergave
- `ENV`: Environment indicator (development/production)
- `DEBUG`: Activeer verbose logging (true/false)

> **Beveiliging**: `.env` staat in `.gitignore`. Hoewel Mapbox tokens publiek zijn, is het nog steeds best practice om ze niet te committen.

#### Installeer iOS Dependencies

```bash
cd ios
pod install
cd ..
```

**Wat dit doet:** Installeert iOS native dependencies via CocoaPods (Firebase, Mapbox native SDKs)

**Verwachte output:**
```
Analyzing dependencies
Downloading dependencies
Installing Firebase (10.x.x)
Installing Mapbox (11.x.x)
...
Pod installation complete!
```

---

### Stap 5: Verifieer Configuratiebestanden

**Checklist - zorg dat deze bestanden bestaan:**

Backend:
- [ ] `packages/backend/appsettings.Development.json` (met je API keys)

Flutter app:
- [ ] `packages/app/.env` (met Mapbox token en API URLs)
- [ ] `packages/app/ios/Runner/GoogleService-Info.plist`
- [ ] `packages/app/lib/firebase_options.dart` (gegenereerd door FlutterFire)
- [ ] `packages/app/ios/Podfile.lock` (aangemaakt na pod install)

**Verifieer met:**

```bash
# Vanaf root map
ls packages/backend/appsettings.Development.json
ls packages/app/.env
ls packages/app/ios/Runner/GoogleService-Info.plist
ls packages/app/lib/firebase_options.dart
```

---

## Verificatie

### Test Backend

```bash
# Vanaf packages/backend map
cd packages/backend
dotnet run
```

**Verwachte output:**
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5005
      Now listening on: https://localhost:5006
```

**Verifieer in browser:**
```bash
# In een andere terminal
curl http://localhost:5005/
```

Moet welkomstbericht met API documentatie links retourneren.

**Controleer Swagger UI:**
Open browser: `http://localhost:5005/swagger/index.html`

Druk `Ctrl+C` om de backend te stoppen.

---

### Test Flutter App

```bash
# Open iOS Simulator (als deze nog niet draait)
open -a Simulator

# Vanaf packages/app map
cd packages/app
flutter run
```

**Verwachte output:**
```
Launching lib/main.dart on iPhone 15 Pro in debug mode...
Running Xcode build...
✓ Built build/ios/iphoneos/Runner.app
Flutter run key commands:
r Hot reload
R Hot restart
h List all available commands
```

**De app moet:**
1. Starten op de iOS simulator
2. Het login/registratie scherm tonen
3. De app UI weergeven (Cupertino design)

**Test basis functionaliteit:**
- Probeer een test account aan te maken
- Login moet werken
- Hoofdinterface moet zichtbaar zijn

Druk `q` in terminal om te stoppen.

---

### Draai Alles Samen

```bash
# Vanaf root map
npm run dev
```

**Dit start:**
- Backend op http://localhost:5005
- Flutter app op iOS simulator

Druk `Ctrl+C` één keer om beide te stoppen.

---

## Probleemoplossing

### Flutter Doctor Problemen

**Probleem:** `flutter doctor` toont fouten

**Oplossing:**

```bash
# Fix Xcode problemen
sudo xcodebuild -license accept
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Fix CocoaPods
sudo gem install cocoapods
pod setup

# Voer doctor opnieuw uit
flutter doctor -v
```

---

### CocoaPods Installatie Mislukt

**Probleem:** `pod install` mislukt met permission errors

**Oplossing:**

```bash
# Installeer zonder sudo
gem install cocoapods --user-install

# Voeg toe aan PATH (voeg toe aan ~/.zshrc of ~/.bash_profile)
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

# Probeer opnieuw
cd packages/app/ios
pod install
```

---

### Backend Start Niet - Poort Conflict

**Probleem:** `Address already in use: 5005`

**Oplossing:**

```bash
# Vind proces dat poort 5005 gebruikt
lsof -i :5005

# Beëindig proces (vervang PID met daadwerkelijk proces ID)
kill -9 <PID>

# Of verander poort in packages/backend/Properties/launchSettings.json
```

---

### Firebase Configuratie Problemen

**Probleem:** App crasht bij opstarten met Firebase fouten

**Oplossing:**

1. **Controleer bestandsplaatsing:**
   ```bash
   ls packages/app/ios/Runner/GoogleService-Info.plist
   ```

2. **Regenereer firebase_options.dart:**
   ```bash
   cd packages/app
   flutterfire configure
   # Selecteer je project, alleen iOS
   ```

3. **Clean en rebuild:**
   ```bash
   flutter clean
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter run
   ```

---

### Mapbox Kaart Wordt Niet Weergegeven

**Probleem:** Kaart toont leeg scherm

**Oplossingen:**

1. **Controleer token in .env:**
   ```bash
   cat packages/app/.env
   # Zorg dat MAPBOX_ACCESS_TOKEN correct is (begint met pk.eyJ1...)
   ```

2. **Herstart app na .env wijzigingen:**
   ```bash
   flutter run
   # .env wijzigingen vereisen volledige herstart
   ```

3. **Controleer Mapbox token geldigheid:**
   - Login bij mapbox.com
   - Controleer dat token niet is verwijderd of verlopen
   - Controleer dat token juiste scopes heeft

---

### Xcode Build Mislukt

**Probleem:** Build mislukt met signing of provisioning fouten

**Oplossingen:**

1. **Open in Xcode:**
   ```bash
   open packages/app/ios/Runner.xcworkspace
   ```

2. **Selecteer Runner target in linker zijbalk**

3. **Ga naar "Signing & Capabilities" tab**

4. **Selecteer je development team** (persoonlijk Apple ID is prima)

5. **Zorg dat "Automatically manage signing" is aangevinkt**

6. **Probeer opnieuw te builden in Xcode** (⌘+B)

---

### Kan iOS Simulator Niet Vinden

**Probleem:** `flutter devices` toont geen iOS simulators

**Oplossingen:**

```bash
# Open Simulator app
open -a Simulator

# Of open via Xcode
# Xcode → Open Developer Tool → Simulator

# Lijst beschikbare simulators
xcrun simctl list devices

# Boot een specifieke simulator
xcrun simctl boot "iPhone 15 Pro"
```

---

## Volgende Stappen

Zodra installatie compleet is:

1. **Lees USER_GUIDE_NL.md** voor instructies over het gebruik van de applicatie
2. **Lees README.md** voor projectoverzicht en architectuur details
3. **Start met ontwikkelen** of onderzoek experimenten uitvoeren

---

## Hulp Krijgen

Als je problemen tegenkomt die hier niet behandeld worden:

1. Controleer [GitHub Issues](https://github.com/thomasmoerman2/mono_research/issues)
2. Bekijk Flutter documentatie: [docs.flutter.dev](https://docs.flutter.dev)
3. Bekijk Firebase documentatie: [firebase.google.com/docs](https://firebase.google.com/docs)
4. Open een nieuwe issue met:
   - macOS versie
   - Xcode versie (`xcodebuild -version`)
   - Flutter versie (`flutter --version`)
   - Foutmeldingen en logs

---

**Installatie compleet!** Je bent klaar om het AI-Powered Travel Planning Research Platform te gebruiken.
