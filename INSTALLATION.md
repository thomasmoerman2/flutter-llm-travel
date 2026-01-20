# Installation Guide

**🇬🇧 English** | [🇳🇱 Nederlands](INSTALLATION_NL.md)

Complete step-by-step instructions for setting up the AI-Powered Travel Planning Research Platform.

> **Platform Requirement**: This project requires **macOS with Xcode** for iOS development.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Required Software](#required-software)
- [Required API Keys & Services](#required-api-keys--services)
- [Installation Steps](#installation-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have:

- macOS computer (required for iOS development)
- Active internet connection
- Apple ID (for Xcode)
- Approximately 30-60 minutes for complete setup

---

## Required Software

### 1. Flutter SDK 3.10.4 or newer

**Why Flutter?** Modern iOS development with hot reload for rapid iteration, excellent performance, and potential for future cross-platform expansion.

**Why version 3.10.4+?** Stable release with necessary features for Mapbox integration and Firebase compatibility.

**Installation:**

1. Visit [flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
2. Download the Flutter SDK
3. Extract the archive:
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_*.zip
   ```
4. Add Flutter to your PATH:
   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```
5. Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):
   ```bash
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
   ```
6. Verify installation:
   ```bash
   flutter doctor
   ```

> **Note**: macOS is required for iOS development. Windows/Linux users can run the backend but cannot build/run the iOS app.

---

### 2. Xcode 13+ (Required)

**Why Xcode?** Apple's official IDE, required for iOS development, includes iOS simulator and build tools.

**Installation:**

1. Open App Store on macOS
2. Search for "Xcode"
3. Click "Get" or "Install" (this may take 30+ minutes)
4. Once installed, open Xcode
5. Accept the license agreement
6. Install additional components when prompted

**Command-line setup:**

```bash
# Install Xcode Command Line Tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Accept license
sudo xcodebuild -license accept
```

---

### 3. CocoaPods

**Why CocoaPods?** Dependency manager for iOS projects, required for Firebase and Mapbox integration.

**Installation:**

```bash
sudo gem install cocoapods
pod setup
```

**Verify installation:**
```bash
pod --version
```

---

### 4. .NET SDK 9.0

**Why .NET 9?** Latest LTS version, minimal APIs for clean endpoint definitions, excellent async/await support for AI model streaming.

**Installation:**

1. Visit [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0)
2. Download the macOS installer (.pkg)
3. Run the installer
4. Follow installation prompts

**Verify installation:**
```bash
dotnet --version
# Should show 9.0.x
```

---

### 5. Node.js & npm

**Why Node.js?** Required for Lerna monorepo management and coordinated script execution.

**Recommended Version:** Node.js 18+ LTS

**Installation:**

1. Visit [nodejs.org](https://nodejs.org)
2. Download the LTS version for macOS
3. Run the installer (.pkg)
4. Follow installation prompts

**Verify installation:**
```bash
node --version
npm --version
```

---

### 6. Git (Version Control)

**Installation (if not already installed):**

```bash
# Git usually comes with Xcode Command Line Tools
git --version

# If not installed, install via Homebrew
brew install git
```

---

## Required API Keys & Services

### 1. OpenAI API Key

**Purpose:** GPT-4o-mini model for travel recommendations

**How to Obtain:**

1. Create account at [platform.openai.com](https://platform.openai.com)
2. Navigate to API section
3. Click "API keys" in left sidebar
4. Click "Create new secret key"
5. Give it a name (e.g., "Travel Research")
6. Copy the key (starts with `sk-proj-...`)
7. **Save it securely** - you won't be able to see it again

**Pricing:**
- Pay-as-you-go: ~$0.15 per 1M tokens input, $0.60 per 1M tokens output (2025 pricing)
- Free tier: $5 credit for new accounts
- Typical research usage: $5-10/month

---

### 2. Google Gemini API Key

**Purpose:** Gemini 2.5 Flash model for alternative AI perspective

**How to Obtain:**

1. Visit [aistudio.google.com](https://aistudio.google.com)
2. Sign in with Google account
3. Click "Get API key" button
4. Click "Create API key"
5. Select or create a Google Cloud project
6. Copy the key (starts with `AIzaSy...`)

**Pricing:**
- Generous free tier: 60 requests per minute
- After free tier: pay-as-you-go
- Typical research usage: Free tier is usually sufficient

---

### 3. Mapbox Access Token

**Purpose:** Map rendering, geocoding, routing, and place search

**How to Obtain:**

1. Create account at [mapbox.com](https://mapbox.com)
2. Navigate to Account → Tokens
3. Use the default public token, or:
4. Click "Create a token"
5. Give it a name (e.g., "Travel App iOS")
6. Ensure these scopes are selected:
   - `styles:read`
   - `fonts:read`
   - `datasets:read`
7. Click "Create token"
8. Copy the token (starts with `pk.eyJ1...`)

**Pricing:**
- Free tier: 50,000 map loads/month
- Geocoding: 100,000 requests/month free
- Directions: 100,000 requests/month free
- Generous for research projects

---

### 4. Firebase Project

**Purpose:** Authentication, Firestore database, and backend authentication verification

#### Step 1: Create Firebase Project

1. Visit [console.firebase.google.com](https://console.firebase.google.com)
2. Click "Add project" or "Create a project"
3. Enter project name (e.g., "travel-ai-research")
4. Click "Continue"
5. Disable Google Analytics (optional, not needed for research)
6. Click "Create project"
7. Wait for project creation (may take 1-2 minutes)
8. Click "Continue" when ready

#### Step 2: Enable Firebase Authentication

1. In Firebase Console, click "Build" in left sidebar
2. Click "Authentication"
3. Click "Get started"
4. Under "Sign-in method" tab
5. Click "Email/Password"
6. Enable the toggle for "Email/Password"
7. Leave "Email link" disabled (not needed)
8. Click "Save"

#### Step 3: Enable Cloud Firestore

1. In Firebase Console, click "Build" in left sidebar
2. Click "Firestore Database"
3. Click "Create database"
4. Choose "Start in test mode" (for development)
5. Click "Next"
6. Select Cloud Firestore location (choose closest to you)
7. Click "Enable"
8. Wait for database creation

**Security Rules (for development):**

After database creation, click "Rules" tab and use:

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

Click "Publish"

> **Production Note**: For production, implement stricter security rules.

#### Step 4: Register iOS App

1. In Firebase Project Overview, click the iOS icon (+)
2. Enter iOS bundle ID:
   - Default is usually `com.example.app`
   - To find yours: Open `packages/app/ios/Runner.xcodeproj` in Xcode
   - Select "Runner" in left sidebar
   - Look for "Bundle Identifier" under "General" tab
3. Optional: Enter App nickname (e.g., "Travel AI iOS")
4. Leave App Store ID empty
5. Click "Register app"
6. Download `GoogleService-Info.plist`
7. **Important**: Save this file, you'll need it in Step 4 of Installation

#### Step 5: Generate Firebase Admin SDK Credentials

**For Backend:**

1. In Firebase Console, click gear icon ⚙️ next to "Project Overview"
2. Click "Project settings"
3. Navigate to "Service accounts" tab
4. Click "Generate new private key"
5. Confirm by clicking "Generate key"
6. A JSON file will download (e.g., `travel-ai-research-firebase-adminsdk-xxxxx.json`)
7. **Keep this file extremely secure**
8. **Never commit this to git**
9. You'll use this JSON content in backend configuration

#### Step 6: Configure Firebase CLI (Optional but Recommended)

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# This will open browser for authentication
```

**Pricing:**
- Spark plan (free tier) is sufficient for research:
  - Authentication: Unlimited users
  - Firestore: 1 GB storage
  - Firestore: 50K reads/day, 20K writes/day

---

## Installation Steps

### Step 1: Clone the Repository

```bash
# Navigate to your development directory
cd ~/Documents

# Clone the repository
git clone https://github.com/thomasmoerman2/mono_research.git

# Navigate into project
cd mono_research
```

---

### Step 2: Install Root Dependencies

```bash
npm install
```

**What this does:** Installs Lerna and sets up monorepo workspace management.

**Expected output:**
```
added 200 packages in 15s
```

---

### Step 3: Backend Setup

#### Install Backend Dependencies

```bash
cd packages/backend
dotnet restore
```

**What this does:** Downloads all NuGet packages (OpenAI SDK, Google GenAI, Firebase Admin, Serilog, etc.)

**Expected output:**
```
Restore completed in 5.2 sec for backend.csproj
```

#### Configure Backend API Keys

Create `appsettings.Development.json` in `packages/backend/` directory:

```bash
# Create the file
touch packages/backend/appsettings.Development.json
```

Open it in your editor and add:

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

**Replace placeholders:**
- `YOUR_OPENAI_KEY_HERE` → Your OpenAI API key (sk-proj-...)
- `YOUR_GEMINI_KEY_HERE` → Your Gemini API key (AIzaSy...)
- `FirebaseCredentials` → Copy entire JSON content from Firebase Admin SDK file you downloaded

**Configuration Explanations:**

- `OpenAIAPIKey`: Used by `/model/gpt` and `/model/hybrid` endpoints
- `GeminiAPIKey`: Used by `/model/gemini` and `/model/hybrid` endpoints
- `FirebaseCredentials`: Verifies JWT tokens from Flutter app
- `CORS`: `"*"` allows all origins (for development). For production, specify exact URL

> **Security**: `appsettings.Development.json` is in `.gitignore`. Never commit API keys.

---

### Step 4: Flutter App Setup

#### Install Flutter Dependencies

```bash
cd ../app
# or from root: cd packages/app

flutter pub get
```

**What this does:** Downloads all Flutter packages (Mapbox SDK, Firebase, HTTP client, etc.)

**Expected output:**
```
Running "flutter pub get" in app...
Resolving dependencies...
Got dependencies!
```

**If you see errors about Flutter SDK version:**
```bash
flutter upgrade
flutter doctor
```

#### Place Firebase Configuration File

1. Copy the `GoogleService-Info.plist` file you downloaded from Firebase
2. Place it in `packages/app/ios/Runner/` directory

```bash
# From packages/app directory
cp ~/Downloads/GoogleService-Info.plist ios/Runner/

# Verify it's there
ls ios/Runner/GoogleService-Info.plist
```

#### Generate Firebase Options (Recommended)

```bash
# Make sure you're in packages/app directory
cd packages/app

# Configure Flutter Firebase
flutterfire configure
```

**Follow prompts:**
1. Select your Firebase project
2. When asked for platforms, **select only iOS**
3. Press Enter to confirm

This generates `lib/firebase_options.dart` automatically.

#### Configure Environment Variables

Create `.env` file in `packages/app/` directory:

```bash
touch packages/app/.env
```

Open it and add:

```env
API_BASE_URL=http://localhost:5005
MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN_HERE
ENV=development
DEBUG=true
```

**Replace placeholders:**
- `YOUR_MAPBOX_TOKEN_HERE` → Your Mapbox public token (pk.eyJ1...)

**Configuration Explanations:**

- `API_BASE_URL`: Backend REST API URL (localhost for development)
- `MAPBOX_ACCESS_TOKEN`: Used by map SDK for rendering
- `ENV`: Environment indicator (development/production)
- `DEBUG`: Enable verbose logging (true/false)

> **Security**: `.env` is in `.gitignore`. While Mapbox tokens are public, still best not to commit.

#### Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

**What this does:** Installs iOS native dependencies via CocoaPods (Firebase, Mapbox native SDKs)

**Expected output:**
```
Analyzing dependencies
Downloading dependencies
Installing Firebase (10.x.x)
Installing Mapbox (11.x.x)
...
Pod installation complete!
```

---

### Step 5: Verify Configuration Files

**Checklist - ensure these files exist:**

Backend:
- [ ] `packages/backend/appsettings.Development.json` (with your API keys)

Flutter app:
- [ ] `packages/app/.env` (with Mapbox token and API URLs)
- [ ] `packages/app/ios/Runner/GoogleService-Info.plist`
- [ ] `packages/app/lib/firebase_options.dart` (generated by FlutterFire)
- [ ] `packages/app/ios/Podfile.lock` (created after pod install)

**Verify with:**

```bash
# From root directory
ls packages/backend/appsettings.Development.json
ls packages/app/.env
ls packages/app/ios/Runner/GoogleService-Info.plist
ls packages/app/lib/firebase_options.dart
```

---

## Verification

### Test Backend

```bash
# From packages/backend directory
cd packages/backend
dotnet run
```

**Expected output:**
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5005
      Now listening on: https://localhost:5006
```

**Verify in browser:**
```bash
# In another terminal
curl http://localhost:5005/
```

Should return welcome message with API documentation links.

**Check Swagger UI:**
Open browser: `http://localhost:5005/swagger/index.html`

Press `Ctrl+C` to stop the backend.

---

### Test Flutter App

```bash
# Open iOS Simulator (if not already running)
open -a Simulator

# From packages/app directory
cd packages/app
flutter run
```

**Expected output:**
```
Launching lib/main.dart on iPhone 15 Pro in debug mode...
Running Xcode build...
✓ Built build/ios/iphoneos/Runner.app
Flutter run key commands:
r Hot reload
R Hot restart
h List all available commands
```

**The app should:**
1. Launch on the iOS simulator
2. Show the login/register screen
3. Display the app's UI (Cupertino design)

**Test basic functionality:**
- Try creating a test account
- Login should work
- Main interface should be visible

Press `q` in terminal to quit.

---

### Run Everything Together

```bash
# From root directory
npm run dev
```

**This starts:**
- Backend on http://localhost:5005
- Flutter app on iOS simulator

Press `Ctrl+C` once to stop both.

---

## Troubleshooting

### Flutter Doctor Issues

**Problem:** `flutter doctor` shows errors

**Solution:**

```bash
# Fix Xcode issues
sudo xcodebuild -license accept
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Fix CocoaPods
sudo gem install cocoapods
pod setup

# Run doctor again
flutter doctor -v
```

---

### CocoaPods Installation Fails

**Problem:** `pod install` fails with permission errors

**Solution:**

```bash
# Install without sudo
gem install cocoapods --user-install

# Add to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

# Try again
cd packages/app/ios
pod install
```

---

### Backend Won't Start - Port Conflict

**Problem:** `Address already in use: 5005`

**Solution:**

```bash
# Find process using port 5005
lsof -i :5005

# Kill process (replace PID with actual process ID)
kill -9 <PID>

# Or change port in packages/backend/Properties/launchSettings.json
```

---

### Firebase Configuration Issues

**Problem:** App crashes on startup with Firebase errors

**Solution:**

1. **Check file placement:**
   ```bash
   ls packages/app/ios/Runner/GoogleService-Info.plist
   ```

2. **Regenerate firebase_options.dart:**
   ```bash
   cd packages/app
   flutterfire configure
   # Select your project, iOS only
   ```

3. **Clean and rebuild:**
   ```bash
   flutter clean
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter run
   ```

---

### Mapbox Map Not Showing

**Problem:** Map shows blank screen

**Solutions:**

1. **Check token in .env:**
   ```bash
   cat packages/app/.env
   # Ensure MAPBOX_ACCESS_TOKEN is correct (starts with pk.eyJ1...)
   ```

2. **Restart app after .env changes:**
   ```bash
   flutter run
   # .env changes require full restart
   ```

3. **Check Mapbox token validity:**
   - Login to mapbox.com
   - Check token hasn't been deleted or expired
   - Check token has correct scopes

---

### Xcode Build Fails

**Problem:** Build fails with signing or provisioning errors

**Solutions:**

1. **Open in Xcode:**
   ```bash
   open packages/app/ios/Runner.xcworkspace
   ```

2. **Select Runner target in left sidebar**

3. **Go to "Signing & Capabilities" tab**

4. **Select your development team** (personal Apple ID is fine)

5. **Ensure "Automatically manage signing" is checked**

6. **Try building again in Xcode** (⌘+B)

---

### Can't Find iOS Simulator

**Problem:** `flutter devices` shows no iOS simulators

**Solutions:**

```bash
# Open Simulator app
open -a Simulator

# Or open via Xcode
# Xcode → Open Developer Tool → Simulator

# List available simulators
xcrun simctl list devices

# Boot a specific simulator
xcrun simctl boot "iPhone 15 Pro"
```

---

## Next Steps

Once installation is complete:

1. **Read USER_GUIDE.md** for instructions on using the application
2. **Read README.md** for project overview and architecture details
3. **Start developing** or conducting research experiments

---

## Getting Help

If you encounter issues not covered here:

1. Check [GitHub Issues](https://github.com/thomasmoerman2/mono_research/issues)
2. Review Flutter documentation: [docs.flutter.dev](https://docs.flutter.dev)
3. Review Firebase documentation: [firebase.google.com/docs](https://firebase.google.com/docs)
4. Open a new issue with:
   - macOS version
   - Xcode version (`xcodebuild -version`)
   - Flutter version (`flutter --version`)
   - Error messages and logs

---

**Installation complete!** You're ready to start using the AI-Powered Travel Planning Research Platform.
