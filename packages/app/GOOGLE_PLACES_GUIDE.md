# Google Places Integration Guide

## How to See Place Suggestions

### Visual Guide

```
┌─────────────────────────────────┐
│         Map View                │
│                                 │
│    🟠 Orange Markers            │
│    = Google Places Suggestions  │
│                                 │
│    🔴 Red Markers               │
│    = Regular Search Results     │
│                                 │
│    ⚫ Black Circles             │
│    = AI-suggested Locations     │
│                                 │
│                                 │
│                                 │
│               ┌──────────────┐  │
│               │  🔍 Search   │  │
│               └──────────────┘  │
│                          ⭕ ←─ Orange sparkle button
└─────────────────────────────────┘
```

## Step-by-Step Instructions

1. **Open the app** and navigate to the **Map** tab

2. **Pan/zoom** to any location you're interested in (e.g., a city center, tourist area)

3. **Tap the orange sparkle button** (⭕ with sparkles icon) in the bottom right

4. **See the results**:
   - **Large orange markers** appear on the map
   - A **bottom sheet** slides up showing:
     - "Suggested Places"
     - "Nearby [restaurants & food]" (changes based on time)
     - List of places with ratings and types

5. **Tap any place** in the list to zoom to it on the map

## Marker Colors Explained

| Color        | Meaning                  | Size   |
|--------------|--------------------------|--------|
| 🟠 **Orange** | Google Places suggestions | Large  |
| 🔴 **Red**    | Mapbox search results    | Medium |
| ⚫ **Black**  | AI-suggested locations   | Circle |

## Time-Based Suggestions

The app automatically suggests different types of places based on the current time:

- **6 AM - 11 AM**: ☕ Cafes, bakeries, breakfast spots
- **11 AM - 2 PM**: 🍔 Restaurants, food trucks (lunch time!)
- **2 PM - 5 PM**: 🏛️ Museums, tourist attractions, galleries, parks
- **5 PM - 9 PM**: 🍽️ Restaurants, bars, entertainment
- **9 PM - 6 AM**: 🍺 Bars, nightlife, late-night spots

## Example Usage Scenario

**Scenario**: You're a tourist in Paris at noon

1. Open the app, go to Map tab
2. Zoom into the city center
3. Tap the orange sparkle button
4. You'll see: "Suggested Places - Nearby restaurants & food"
5. Orange markers appear on nearby restaurants
6. Tap one to see details and navigate

## Troubleshooting

**No results appearing?**
- Make sure you have `GOOGLE_PLACES_API_KEY` set in your `.env` file
- Ensure the Places API is enabled in Google Cloud Console
- Check that you're zoomed into a populated area
- Try a different location (some rural areas may have fewer places)

**Button not working?**
- Wait for the loading spinner to finish
- Make sure you have an internet connection
- Check console logs for any API errors

## Technical Details

- **Search radius**: 2km (1.2 miles) from map center
- **Max results**: Limited by Google Places API (typically 20)
- **API**: Google Places API (Nearby Search)
- **Marker style**: Mapbox marker-15 icon, size 2.2, orange (#FF6B35)
