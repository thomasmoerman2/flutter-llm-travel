import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_access.dart';

/// Service to manage app preferences and settings
class PreferencesService {
  static const String _selectedModelKey = 'selected_ai_model';
  static const String _defaultModel = 'ChatGPT';
  static final FirestoreAccess _firestore = FirestoreAccess();

  /// Get the currently selected AI model
  /// Checks Firestore first if user is logged in, then falls back to local storage
  static Future<String> getSelectedModel() async {
    final user = FirebaseAuth.instance.currentUser;

    // If user is logged in, try to get from Firestore first
    if (user != null) {
      try {
        final firestoreModel = await _firestore.getUserAIModel(user.uid);
        if (firestoreModel != null) {
          // Save to local storage for offline access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_selectedModelKey, firestoreModel);
          return firestoreModel;
        }
      } catch (e) {
        // If Firestore fails, fall through to local storage
      }
    }

    // Fall back to local storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey) ?? _defaultModel;
  }

  /// Save the selected AI model
  /// Saves to both local storage and Firestore (if user is logged in)
  static Future<bool> setSelectedModel(String model) async {
    // Save to local storage first
    final prefs = await SharedPreferences.getInstance();
    final localSuccess = await prefs.setString(_selectedModelKey, model);

    // If user is logged in, also save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.saveUserAIModel(user.uid, model);
      } catch (e) {
        // Firestore save failed, but local storage succeeded
        // Continue anyway - the local value is still saved
      }
    }

    return localSuccess;
  }

  /// Clear all preferences (useful for logout/reset)
  static Future<bool> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.clear();
  }

  /// Check if a specific preference exists
  static Future<bool> hasKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }
}
