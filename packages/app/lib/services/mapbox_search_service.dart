import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'env_config.dart';

/// Mapbox Geocoding/Search service
class MapboxSearchService {
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Search for places using Mapbox Geocoding API
  ///
  /// [query] - The search query (e.g., "Tokyo", "Eiffel Tower", "restaurants near me")
  /// [limit] - Maximum number of results (default: 5)
  /// Returns a list of [SearchResult] objects
  static Future<List<SearchResult>> search(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final token = EnvConfig.mapboxAccessToken;
    if (token.isEmpty) {
      debugPrint('❌ Mapbox access token not found');
      throw Exception('Mapbox access token not configured');
    }

    try {
      // Encode query for URL
      final encodedQuery = Uri.encodeComponent(query);

      // Build API URL with parameters
      final url = Uri.parse(
        '$_baseUrl/$encodedQuery.json?access_token=$token&limit=$limit&types=place,poi,address,region,country'
      );

      debugPrint('🔍 Searching Mapbox: $query');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Search request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        final results = features.map((feature) {
          return SearchResult.fromJson(feature as Map<String, dynamic>);
        }).toList();

        debugPrint('✅ Found ${results.length} results for "$query"');
        return results;
      } else {
        debugPrint('❌ Mapbox search failed: ${response.statusCode} - ${response.body}');
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Mapbox search error: $e');
      rethrow;
    }
  }
}

/// Search result from Mapbox Geocoding API
class SearchResult {
  final String id;
  final String placeName;
  final String? placeType;
  final double longitude;
  final double latitude;
  final String? address;
  final String? context; // e.g., "Paris, France"

  SearchResult({
    required this.id,
    required this.placeName,
    this.placeType,
    required this.longitude,
    required this.latitude,
    this.address,
    this.context,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final coordinates = json['center'] as List<dynamic>;
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final placeTypes = json['place_type'] as List<dynamic>? ?? [];

    // Extract context (city, country, etc.)
    String? context;
    final contextList = json['context'] as List<dynamic>?;
    if (contextList != null && contextList.isNotEmpty) {
      context = contextList
          .map((c) => (c as Map<String, dynamic>)['text'] as String?)
          .where((text) => text != null)
          .join(', ');
    }

    return SearchResult(
      id: json['id'] as String,
      placeName: json['place_name'] as String? ?? json['text'] as String,
      placeType: placeTypes.isNotEmpty ? placeTypes.first as String : null,
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
      address: properties['address'] as String?,
      context: context,
    );
  }

  /// Get a short display name for the result
  String get shortName {
    final text = (placeName.split(',').first).trim();
    return text.length > 40 ? '${text.substring(0, 40)}...' : text;
  }

  /// Get a subtitle with location context
  String get subtitle {
    if (context != null && context!.isNotEmpty) {
      return context!;
    }
    final parts = placeName.split(',');
    if (parts.length > 1) {
      return parts.sublist(1).join(',').trim();
    }
    return '';
  }
}
