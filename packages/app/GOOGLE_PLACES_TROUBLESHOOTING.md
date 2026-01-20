# Google Places API Troubleshooting Guide

## Understanding "REQUEST_DENIED" Errors

When you see `REQUEST_DENIED`, the logs now show detailed information. Here's how to interpret and fix it:

## 📋 Step-by-Step Debugging

### 1. Check Your Console Logs

When you tap the orange sparkle button, look for these logs:

```
🔍 Google Places API Key Check:
   - Key exists: true/false
   - Key length: XX
   - Key preview: AIzaSyXXXX...

🔍 Searching Google Places: restaurant near (48.8566, 2.3522)

❌ Google Places API error: REQUEST_DENIED
📄 Full API response: { ... }
🔴 REQUEST_DENIED details: [Google's error message]
🔑 API Key (first 10 chars): AIzaSyXXXX...
🌐 Request URL (without key): https://maps.googleapis.com/maps/api/place/nearbysearch/json?...
```

### 2. Common Issues & Solutions

#### Issue #1: Wrong API Enabled ⚠️ **MOST COMMON**

**Symptom**: "This API project is not authorized to use this API"

**Problem**: You might have enabled the wrong Places API. There are TWO versions:
- ❌ Places API (old, deprecated)
- ✅ **Places API (New)** ← You need THIS one

**Fix**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **"APIs & Services" > "Library"**
4. Search for **"Places API (New)"**
5. Click **"Enable"**
6. Also enable **"Places API"** (the old one) as a fallback

#### Issue #2: API Key Restrictions 🔐

**Symptom**: "API key not valid" or "API key doesn't match restrictions"

**Problem**: Your API key has application restrictions that block mobile apps

**Fix**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **"APIs & Services" > "Credentials"**
3. Click on your API key
4. Under "Application restrictions":
   - **Option A**: Choose **"None"** (least secure, good for testing)
   - **Option B**: Choose **"iOS apps"** and add your Bundle ID
   - **Option C**: Choose **"Android apps"** and add your package name + SHA-1
5. Under "API restrictions":
   - Choose **"Restrict key"**
   - Check **"Places API (New)"** and **"Places API"**
6. Click **"Save"**

#### Issue #3: Billing Not Enabled 💳

**Symptom**: "Places API has not been used in project XXX before or it is disabled"

**Problem**: Google Cloud project doesn't have billing enabled

**Fix**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **"Billing"** in the left menu
3. Link a billing account (you get $200 free credit per month)
4. Enable billing for your project

**Note**: Places API pricing:
- First $200/month is FREE
- Basic Data: $17 per 1,000 requests after free tier
- You're unlikely to exceed this during development

#### Issue #4: API Key Not Loaded 📝

**Symptom**: Logs show `Key exists: false` or `Key length: 0`

**Problem**: API key not in `.env` file or Flutter didn't reload it

**Fix**:
1. Check your `.env` file contains:
   ```
   GOOGLE_PLACES_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
2. **Restart the app** completely (hot reload doesn't reload .env)
3. On iOS: Stop debugging, then run again
4. Check the key doesn't have extra spaces or quotes

#### Issue #5: API Key Invalid Format 🔑

**Symptom**: Key length is very short (< 30 characters)

**Problem**: API key is malformed or copied incorrectly

**Fix**:
1. Valid Google API keys look like: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
2. They're typically 39 characters long
3. Start with `AIzaSy`
4. No spaces, quotes, or special characters
5. Get a fresh key from Google Cloud Console if needed

#### Issue #6: Quota Exceeded 📊

**Symptom**: "You have exceeded your daily request quota"

**Problem**: Too many API calls (unlikely during development)

**Fix**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **"APIs & Services" > "Dashboard"**
3. Click **"Places API (New)"**
4. Check your quota usage
5. If needed, request quota increase

## 🧪 Testing Your API Key

### Quick Test with cURL

Run this in your terminal (replace `YOUR_API_KEY`):

```bash
curl "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=48.8566,2.3522&radius=1500&type=restaurant&key=YOUR_API_KEY"
```

**Expected Result**:
- ✅ If working: You'll see JSON with `"status": "OK"` and results
- ❌ If broken: You'll see `"status": "REQUEST_DENIED"` with error details

### Test in Browser

1. Replace `YOUR_API_KEY` in this URL:
   ```
   https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=48.8566,2.3522&radius=1500&type=restaurant&key=YOUR_API_KEY
   ```
2. Paste it in your browser
3. You should see JSON results

## 🔧 Advanced Debugging

### Check What the App Sees

Add this temporary code to `map_page.dart` in the `_suggestNearbyPlaces` method:

```dart
// Right after try {
final testKey = EnvConfig.get('GOOGLE_PLACES_API_KEY');
// debugPrint('🧪 API Key from map_page: ${testKey?.substring(0, 10)}...');
```

### Check .env is Loaded

Add to `main.dart` after `await dotenv.load()`:

```dart
// debugPrint('🔧 Loaded .env with ${dotenv.env.keys.length} keys');
// debugPrint('🔧 Has GOOGLE_PLACES_API_KEY: ${dotenv.env.containsKey('GOOGLE_PLACES_API_KEY')}');
```

## 📞 What to Share When Asking for Help

If you're still stuck, share these logs:

1. **API Key Check logs**:
   ```
   🔍 Google Places API Key Check:
      - Key exists: ?
      - Key length: ?
      - Key preview: ?
   ```

2. **Full error response**:
   ```
   📄 Full API response: { ... }
   🔴 REQUEST_DENIED details: ?
   ```

3. **Your Google Cloud Console settings**:
   - Which APIs are enabled?
   - What restrictions are on your API key?
   - Is billing enabled?

## ✅ Verification Checklist

Before testing again, verify:

- [ ] **Places API (New)** is enabled in Google Cloud Console
- [ ] **Billing** is enabled on your Google Cloud project
- [ ] API key has **no restrictions** (or correct iOS/Android restrictions)
- [ ] `.env` file has `GOOGLE_PLACES_API_KEY=AIzaSy...`
- [ ] API key is 39 characters and starts with `AIzaSy`
- [ ] You **restarted the app** (not just hot reload)
- [ ] You can see the API key in the debug logs
- [ ] cURL test works from command line

## 🎯 Most Likely Solution

Based on common issues, try this first:

1. Go to https://console.cloud.google.com/apis/library
2. Search for "Places API (New)"
3. Make sure it shows **"API ENABLED"** (not "ENABLE")
4. If not enabled, click **"ENABLE"**
5. Go to Credentials > Your API Key > Edit
6. Set "Application restrictions" to **"None"** (for testing)
7. Set "API restrictions" to **"Don't restrict key"** (for testing)
8. Click **"Save"**
9. Wait 1-2 minutes for changes to propagate
10. **Restart your app completely**
11. Try tapping the orange sparkle button again

## 📚 Official Documentation

- [Places API (New) Documentation](https://developers.google.com/maps/documentation/places/web-service/overview)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
- [Troubleshooting Guide](https://developers.google.com/maps/documentation/places/web-service/errors)
