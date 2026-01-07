# Backend request guidance

This note describes the data that works best when sending requests to the backend from the app so the AI can return consistent, structured results (locations, routes, and helpful text).

## What the backend expects (conceptually)

The backend is optimized when the user message is:

- Clear intent: ask for places, a route, or an itinerary.
- Context: region/country, dates, pace, interests, budget, and travel mode.
- Output shape hint: request a JSON block with locations and optional route type.

The app already parses JSON blocks from the AI response. When the AI includes locations in the expected format, the UI can render markers and routes automatically.

## Location JSON shape (best case)

Include a JSON block in the AI response so the app can parse it. The parser looks for a fenced JSON block like this:

```json
{
  "locations": [
    {
      "name": "Lisbon",
      "lat": 38.7223,
      "lng": -9.1393,
      "description": "City center and food",
      "day": 1
    },
    {
      "name": "Sintra",
      "lat": 38.7979,
      "lng": -9.3906,
      "description": "Palace and gardens",
      "day": 2
    }
  ]
}
```

### Required fields

- `name`: string
- `lat`: number
- `lng`: number

### Optional fields

- `description`: string
- `day`: number (useful for multi-day itineraries)

## Route JSON shape (best case)

When the user asked for a route, include a `route` or `routeType` field in the same JSON block:

```json
{
  "locations": [
    {"name": "Paris", "lat": 48.8566, "lng": 2.3522},
    {"name": "Reims", "lat": 49.2583, "lng": 4.0317}
  ],
  "route": { "type": "driving" }
}
```

Supported route types:
- `driving`
- `walking`
- `cycling`

If a route type is omitted but a route is implied, the app will auto-detect a mode based on distance.

## Recommended request format (from frontend)

When you send the user prompt to the backend, these details help the AI generate clean JSON:

- City/country and travel dates
- Interests (food, museums, nature)
- Pace (relaxed vs packed)
- Constraints (budget, child-friendly, accessibility)
- Explicit ask for JSON output

Example message to backend:

```
Plan a 2-day trip in Lisbon, relaxed pace, food + viewpoints, no long walks. Return a short summary and a JSON block of locations with lat/lng. If a route makes sense, include route.type.
```

## Why this helps

- The app parses JSON blocks in the response and uses them for map markers/routes.
- Clear intent and constraints reduce off-topic suggestions.
- Specifying JSON blocks prevents the AI from returning unstructured lists that cannot be mapped.

## Files involved

- `lib/services/location_parser.dart` parses the JSON block.
- `lib/services/chat_service.dart` stores parsed locations + routeType into message metadata.
- `lib/routes/map_page.dart` renders markers and routes from metadata.
