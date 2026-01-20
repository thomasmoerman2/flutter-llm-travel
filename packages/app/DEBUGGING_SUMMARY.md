# 🔍 Enhanced Debugging for Google Places API

I've added comprehensive logging to help diagnose the "REQUEST_DENIED" issue. Here's what you'll now see:

## 📊 New Debug Logs

When you tap the orange sparkle button, you'll see detailed logs like this:

### 1. API Key Verification
```
🔍 Google Places API Key Check:
   - Key exists: true
   - Key length: 39
   - Key preview: AIzaSyXXXX...
```

**What to check**:
- Key should exist (true)
- Length should be ~39 characters
- Preview should start with "AIzaSy"

### 2. API Request Details
```
🔍 Searching Google Places: restaurant near (48.8566, 2.3522)
```

**What this shows**: The place type and coordinates being searched

### 3. Error Details (if REQUEST_DENIED)
```
❌ Google Places API error: REQUEST_DENIED
📄 Full API response: {...}
🔴 REQUEST_DENIED details: [Google's actual error message]
🔑 API Key (first 10 chars): AIzaSyXXXX...
🌐 Request URL (without key): https://maps.googleapis.com/...
```

**What to look for**: Google's `error_message` field tells you EXACTLY what's wrong

## 🧪 Quick Test Script

Run this from the app directory to test your API key independently:

```bash
cd packages/app
./test_google_places.sh
```

This will:
- ✅ Verify API key is in `.env`
- ✅ Show key length and preview
- ✅ Make a real API request
- ✅ Show the exact error from Google
- ✅ Save full response to JSON file

## 🎯 Most Common Issues (in order of likelihood)

### 1. Wrong API Enabled (90% of cases)
**What you'll see**:
```
error_message: "This API project is not authorized to use this API"
```

**Fix**: Enable **"Places API (New)"** in [Google Cloud Console](https://console.cloud.google.com/apis/library)

### 2. API Key Restrictions (5% of cases)
**What you'll see**:
```
error_message: "API key not valid. Please pass a valid API key."
```

**Fix**: Edit your API key → Set restrictions to "None" (for testing)

### 3. Billing Not Enabled (4% of cases)
**What you'll see**:
```
error_message: "Places API has not been used in project before or it is disabled"
```

**Fix**: Enable billing in [Google Cloud Console](https://console.cloud.google.com/billing)

### 4. API Key Not Loaded (1% of cases)
**What you'll see**:
```
Key exists: false
Key length: 0
```

**Fix**: Restart the app completely (hot reload doesn't reload .env)

## 📝 Diagnostic Checklist

Run through these steps:

```bash
# Step 1: Test API key independently
cd packages/app
./test_google_places.sh

# Step 2: Check what status you get
# - "OK" = API key works! ✅
# - "REQUEST_DENIED" = See error message for details
# - "ZERO_RESULTS" = API works, just no places found ✅

# Step 3: Look at the saved response
cat google_places_test_response.json
```

## 🔧 What I Changed in the Code

### File: `google_places_service.dart`

1. **Added API key logging**:
   - Shows if key exists
   - Shows key length
   - Shows first 10 characters

2. **Added full error response logging**:
   - Logs complete API response
   - Extracts `error_message` from Google
   - Shows sanitized request URL

3. **Enhanced error messages**:
   - Now includes Google's exact error message
   - Lists common fixes
   - Shows what to check in Google Cloud Console

## 🎨 Example Debug Session

Here's what a typical debug session looks like:

```
[User taps orange sparkle button]

🔍 Google Places API Key Check:
   - Key exists: true
   - Key length: 39
   - Key preview: AIzaSyBJKL...

🔍 Fetching nearby places at (48.8566, 2.3522)
🔍 Searching Google Places: restaurant near (48.8566, 2.3522)

❌ Google Places API error: REQUEST_DENIED
📄 Full API response: {
  "html_attributions": [],
  "results": [],
  "status": "REQUEST_DENIED",
  "error_message": "This API project is not authorized to use this API. Please ensure that this API is activated in the APIs Console"
}
🔴 REQUEST_DENIED details: This API project is not authorized to use this API. Please ensure that this API is activated in the APIs Console
🔑 API Key (first 10 chars): AIzaSyBJKL...
🌐 Request URL (without key): https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=48.8566,2.3522&radius=2000&type=restaurant&key=***KEY***
```

**In this example**: The error message clearly says "API not activated in APIs Console" → Go enable "Places API (New)"!

## 📚 Documentation Files

I created these helpful files:

1. **`GOOGLE_PLACES_GUIDE.md`** - How to use the feature
2. **`GOOGLE_PLACES_TROUBLESHOOTING.md`** - Detailed troubleshooting (⭐ START HERE)
3. **`test_google_places.sh`** - Test script to verify API key
4. **`DEBUGGING_SUMMARY.md`** - This file

## 🚀 Next Steps

1. **Run the test script**:
   ```bash
   cd packages/app
   ./test_google_places.sh
   ```

2. **Look at the error message** in the output

3. **Follow the fix** in `GOOGLE_PLACES_TROUBLESHOOTING.md`

4. **Restart your app** and try again

5. **Check the new detailed logs** in the console

## 💡 Pro Tip

The test script is the fastest way to diagnose issues because:
- ✅ Tests API key directly (no Flutter involved)
- ✅ Shows Google's exact error message
- ✅ Takes 2 seconds to run
- ✅ Saves full response for inspection

If the test script works but the app doesn't, then it's an app configuration issue (likely `.env` not reloading).

If the test script fails, then it's a Google Cloud Console configuration issue.
