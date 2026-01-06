import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mapbox_directions_service.dart';

class ParsedLocationResponse {
  final List<LocationData> locations;
  final RouteType? routeType;
  final String cleanedText;

  const ParsedLocationResponse({
    required this.locations,
    required this.routeType,
    required this.cleanedText,
  });
}

/// Service to parse location data from AI responses
class LocationParser {
  /// Extract locations from AI response text
  ///
  /// Looks for JSON blocks in markdown code fences:
  /// ```json
  /// { "locations": [...] }
  /// ```
  static List<LocationData> parseLocations(String responseText) {
    return parseLocationsAndRoute(responseText).locations;
  }

  static ParsedLocationResponse parseLocationsAndRoute(String responseText) {
    debugPrint('🔍 LocationParser: Searching for JSON in response (${responseText.length} chars)');
    final match = _firstJsonBlock(responseText);
    if (match == null) {
      debugPrint('❌ LocationParser: No JSON block found');
      return ParsedLocationResponse(
        locations: const [],
        routeType: null,
        cleanedText: responseText.trim(),
      );
    }

    final jsonString = match.group(1);
    debugPrint('📦 LocationParser: Found JSON block (${jsonString?.length ?? 0} chars)');
    if (jsonString == null || jsonString.trim().isEmpty) {
      debugPrint('⚠️ LocationParser: JSON block is empty');
      return ParsedLocationResponse(
        locations: const [],
        routeType: null,
        cleanedText: cleanResponseText(responseText),
      );
    }

    try {
      debugPrint('🔄 LocationParser: Parsing JSON...');
      debugPrint('📄 Raw JSON content:\n$jsonString');
      final jsonData = jsonDecode(jsonString);
      if (jsonData is! Map<String, dynamic>) {
        debugPrint('❌ LocationParser: JSON is not a Map');
        return ParsedLocationResponse(
          locations: const [],
          routeType: null,
          cleanedText: cleanResponseText(responseText),
        );
      }
      debugPrint('✅ LocationParser: JSON parsed successfully');
      debugPrint('🔑 JSON keys: ${jsonData.keys.join(", ")}');

      final locationsValue = jsonData['locations'];
      debugPrint('📍 LocationParser: Found locations field: ${locationsValue != null ? "yes (${locationsValue is List ? (locationsValue as List).length : "not a list"})" : "no"}');
      final locationList = <LocationData>[];
      if (locationsValue is List) {
        debugPrint('🔢 LocationParser: Processing ${locationsValue.length} location entries');
        for (final loc in locationsValue) {
          if (loc is! Map<String, dynamic>) {
            debugPrint('⚠️ Skipping non-map location entry: $loc');
            continue;
          }
          try {
            final locationData = LocationData.fromJson(loc);
            locationList.add(locationData);
            debugPrint('✅ Parsed location: ${locationData.name}');
          } catch (e) {
            debugPrint('⚠️ Failed to parse location: $e');
            debugPrint('   Location data was: $loc');
          }
        }
      }
      debugPrint('📊 LocationParser: Total locations parsed: ${locationList.length}');

      final routeType = _parseRouteType(jsonData, locationList);
      return ParsedLocationResponse(
        locations: locationList,
        routeType: routeType,
        cleanedText: cleanResponseText(responseText),
      );
    } catch (e) {
      debugPrint('❌ Error parsing locations: $e');
      return ParsedLocationResponse(
        locations: const [],
        routeType: null,
        cleanedText: cleanResponseText(responseText),
      );
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

  static RegExpMatch? _firstJsonBlock(String responseText) {
    final jsonBlockRegex = RegExp(
      r'```json\s*\n(.*?)\n```',
      multiLine: true,
      dotAll: true,
    );
    return jsonBlockRegex.firstMatch(responseText);
  }

  static RouteType? _parseRouteType(
    Map<String, dynamic> jsonData,
    List<LocationData> locations,
  ) {
    dynamic routeValue = jsonData['routeType'] ?? jsonData['mode'];
    final routeData = jsonData['route'];
    if (routeValue == null && routeData is Map<String, dynamic>) {
      routeValue = routeData['type'] ?? routeData['mode'] ?? routeData['routeType'];
      if (routeValue == null && routeData['enabled'] == true) {
        routeValue = true;
      }
    } else if (routeValue == null && routeData is bool) {
      routeValue = routeData;
    }

    if (routeValue is String) {
      final normalized = routeValue.toLowerCase();
      if (normalized.contains('walk')) return RouteType.walking;
      if (normalized.contains('cycl') || normalized.contains('bike')) {
        return RouteType.cycling;
      }
      if (normalized.contains('drive')) return RouteType.driving;
      return RouteType.driving;
    }

    if (routeValue is bool && routeValue == true) {
      if (locations.length >= 2) {
        return MapboxDirectionsService.detectRouteType(locations);
      }
      return RouteType.driving;
    }

    return null;
  }
}
