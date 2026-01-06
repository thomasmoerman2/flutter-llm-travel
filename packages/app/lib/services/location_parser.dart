import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mapbox_directions_service.dart';

/// Service to parse location data from AI responses
class LocationParser {
  /// Extract locations from AI response text
  ///
  /// Looks for JSON blocks in markdown code fences:
  /// ```json
  /// { "locations": [...] }
  /// ```
  static List<LocationData> parseLocations(String responseText) {
    try {
      // Look for JSON code blocks
      final jsonBlockRegex = RegExp(
        r'```json\s*\n(.*?)\n```',
        multiLine: true,
        dotAll: true,
      );

      final match = jsonBlockRegex.firstMatch(responseText);
      if (match == null) {
        debugPrint('📍 No JSON location block found in response');
        return [];
      }

      final jsonString = match.group(1);
      if (jsonString == null || jsonString.trim().isEmpty) {
        return [];
      }

      debugPrint('📍 Found JSON block, parsing...');

      // Parse JSON
      final jsonData = jsonDecode(jsonString);

      if (jsonData is! Map<String, dynamic>) {
        debugPrint('⚠️ JSON is not an object');
        return [];
      }

      final locations = jsonData['locations'];
      if (locations == null || locations is! List) {
        debugPrint('⚠️ No locations array in JSON');
        return [];
      }

      // Convert to LocationData objects
      final locationList = <LocationData>[];
      for (final loc in locations) {
        if (loc is! Map<String, dynamic>) continue;

        try {
          locationList.add(LocationData.fromJson(loc));
        } catch (e) {
          debugPrint('⚠️ Failed to parse location: $e');
        }
      }

      debugPrint('✅ Parsed ${locationList.length} locations');
      return locationList;
    } catch (e) {
      debugPrint('❌ Error parsing locations: $e');
      return [];
    }
  }

  /// Remove JSON blocks from response text for display
  ///
  /// Returns the cleaned text without the JSON blocks
  static String cleanResponseText(String responseText) {
    return responseText.replaceAll(
      RegExp(
        r'```json\s*\n.*?\n```',
        multiLine: true,
        dotAll: true,
      ),
      '',
    ).trim();
  }
}
