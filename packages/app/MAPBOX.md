# Mapbox usage

This document explains how Mapbox is wired in the app, how markers are shown, and how routes are generated when the user taps the “route” action.

## Overview

- Map rendering lives in `lib/routes/map_page.dart` (`MapPageContent`).
- Search uses Mapbox Geocoding in `lib/services/mapbox_search_service.dart`.
- Routing uses Mapbox Directions in `lib/services/mapbox_directions_service.dart`.
- The Mapbox access token is read from `.env` via `lib/services/env_config.dart`.

## Token setup

- Token key: `MAPBOX_ACCESS_TOKEN` in `.env`.
- Read via `EnvConfig.mapboxAccessToken`.
- Set during `MapPageContent.initState()` using `MapboxOptions.setAccessToken(...)`.

## Map initialization

- `MapPageContent` builds a `MapWidget` with initial `CameraOptions`.
- `onMapCreated` stores a `MapboxMap` reference and creates annotation managers:
  - `PointAnnotationManager` for search markers.
  - `CircleAnnotationManager` for AI location markers.
  - `PointAnnotationManager` for labels.
  - `PolylineAnnotationManager` for route lines.

## Search results → markers

Flow:

1) `_performSearch()` calls `MapboxSearchService.search(...)`.
2) Results list is shown in UI.
3) `_showMarkersOnMap(...)` clears the existing search markers and creates new `PointAnnotationOptions`.

Marker details:

- Geometry: `Point(Position(lng, lat))`
- Icon: `marker-15`
- Size: `iconSize: 1.5`

## AI locations → markers

Flow:

1) The AI returns a JSON block with `locations`.
2) `LocationParser.parseLocationsAndRoute(...)` extracts them.
3) `ChatService` stores `locations` and optional `routeType` in message metadata.
4) The chat message shows a “Show on map/Show route” action.
5) Tapping that action calls:
   - `MapPageContent.showLocationsOnMap(...)` or
   - `MapPageContent.showRouteOnMap(...)`

Marker details (AI locations):

- Circles are created in `_showLocationMarkers(...)` using `CircleAnnotationOptions`.
- Labels are created using `PointAnnotationOptions` with `textField`.
- Tapping a circle opens a details sheet (`_showLocationDetails(...)`).

## Routes (when pressing the route button)

Flow:

1) User taps the chat action button for a message with `routeType`.
2) `MapPageContent.showRouteOnMap(...)` is called.
3) The method clears overlays, adds location markers, then calculates a route via:
   - `MapboxDirectionsService.calculateRoute(...)`
4) The route line is drawn using `_drawRoute(...)` with `PolylineAnnotationOptions`.

Route rendering:

- Geometry is returned as GeoJSON coordinates from the Directions API.
- The line is styled with:
  - `lineColor: ThemeColor.primary`
  - `lineWidth: 4.0`

If route calculation fails, the app still shows the markers and fits the camera to the locations.

## Camera fitting

`_fitCameraToLocations(...)` computes a bounding box around the locations and calls `flyTo(...)` with a calculated zoom level so all points are visible.

## Key files

- `lib/routes/map_page.dart`
- `lib/services/mapbox_search_service.dart`
- `lib/services/mapbox_directions_service.dart`
- `lib/services/location_parser.dart`
- `lib/services/env_config.dart`
