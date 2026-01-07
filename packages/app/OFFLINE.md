# Offline behavior

This document explains what “offline” means in the current app, what data is stored locally, and the current limitations. It reflects the current implementation only.

## Scope

Offline support today is limited to local persistence of routes and conversations plus Firestore caching. There is no full offline UI fallback yet.

## Local storage (SharedPreferences)

Local storage is implemented in `lib/services/offline_storage_service.dart` using `SharedPreferences`.

### What is stored

- Saved routes (from the map page)
- Conversation metadata (title, model, counts)
- Conversation messages (limited history)

### Storage keys

- `offline_saved_routes`
- `offline_conversations`
- `offline_messages_<conversationId>`

### Limits

- Max conversations stored: 10 (`_maxConversations`)
- Max messages per conversation: 50 (`_maxMessagesPerConversation`)

### When data is saved

- Conversations + messages:
  - `ChatService._updateConversation()` writes:
    - `OfflineStorageService.saveConversation(...)`
    - `OfflineStorageService.saveConversationMessages(...)`
- Routes:
  - `MapPageContent._saveRoute(...)` writes:
    - Firestore, and
    - `OfflineStorageService.saveRoute(...)`

## Firestore offline cache

`FirestoreAccess.init()` enables Firestore persistence and unlimited cache size:

- `persistenceEnabled: true`
- `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED`

This only takes effect if `FirestoreAccess.init()` is called during app startup.

## What works offline today

- Previously saved routes and conversations are stored locally.
- Offline storage stats are visible in Settings.
- The local suggestions list in the map search uses `assets/data/places.json` and works without network.

## Current limitations

- The UI does not automatically load from `OfflineStorageService` if Firestore fails.
- Mapbox search and directions require network access.
- Map tiles are not cached; there is no offline map download logic.

## Settings / maintenance

The Settings screen uses:

- `OfflineStorageService.getStorageStats()` for counts and size
- `OfflineStorageService.clearAllOfflineData()` to purge local data

## If you want full offline UI

To enable real offline mode, add a fallback layer that reads from `OfflineStorageService` when Firestore streams fail, and render those records in:

- `HomePageContent` (messages list)
- `ConversationSidebar` (conversation list)
- Map saved routes sheet

## Key files

- `lib/services/offline_storage_service.dart`
- `lib/services/chat_service.dart`
- `lib/routes/map_page.dart`
- `lib/routes/settings_page.dart`
- `lib/services/firestore_access.dart`
