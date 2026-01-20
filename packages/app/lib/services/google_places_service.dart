import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'env_config.dart';

/// Google Places API service for finding nearby places
class GooglePlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Get place type suggestions based on current time
  /// Returns appropriate place types for the time of day
  static List<String> getPlaceTypesForTime(DateTime time) {
    final hour = time.hour;

    // Morning (6 AM - 11 AM): Breakfast, cafes, bakeries
    if (hour >= 6 && hour < 11) {
      return ['cafe', 'bakery', 'breakfast_restaurant'];
    }
    // Lunch time (11 AM - 2 PM): Restaurants, food
    else if (hour >= 11 && hour < 14) {
      return ['restaurant', 'food', 'meal_takeaway'];
    }
    // Afternoon (2 PM - 5 PM): Museums, tourist attractions
    else if (hour >= 14 && hour < 17) {
      return ['museum', 'tourist_attraction', 'art_gallery', 'park'];
    }
    // Evening (5 PM - 9 PM): Restaurants, bars, entertainment
    else if (hour >= 17 && hour < 21) {
      return ['restaurant', 'bar', 'night_club', 'movie_theater'];
    }
    // Night (9 PM - 6 AM): Bars, late-night food
    else {
      return ['bar', 'night_club', 'lodging'];
    }
  }

  /// Get human-readable description of place types for the time
  static String getPlaceTypeDescription(DateTime time) {
    final hour = time.hour;

    if (hour >= 6 && hour < 11) {
      return 'breakfast & cafes';
    } else if (hour >= 11 && hour < 14) {
      return 'restaurants & food';
    } else if (hour >= 14 && hour < 17) {
      return 'museums & attractions';
    } else if (hour >= 17 && hour < 21) {
      return 'dining & entertainment';
    } else {
      return 'bars & nightlife';
    }
  }

  /// Search for nearby places using Google Places Nearby Search API
  ///
  /// [latitude] - Latitude of the center point
  /// [longitude] - Longitude of the center point
  /// [radius] - Search radius in meters (default: 1500m / ~1 mile)
  /// [type] - Place type filter (optional, uses time-based if not provided)
  /// [keyword] - Additional keyword search (optional)
  /// Returns a list of [PlaceResult] objects
  static Future<List<PlaceResult>> searchNearby({
    required double latitude,
    required double longitude,
    int radius = 1500,
    String? type,
    String? keyword,
  }) async {
    final apiKey = EnvConfig.get('GOOGLE_PLACES_API_KEY');

    // Detailed API key debugging
    // // debugPrint('🔍 Google Places API Key Check:');
    // // debugPrint('   - Key exists: ${apiKey != null}');
    // // debugPrint('   - Key length: ${apiKey?.length ?? 0}');
    // // debugPrint('   - Key preview: ${apiKey != null && apiKey.length > 10 ? "${apiKey.substring(0, 10)}..." : "TOO_SHORT_OR_NULL"}');

    if (apiKey == null || apiKey.isEmpty) {
      // // debugPrint('❌ Google Places API key not found in .env');
      // // debugPrint('💡 Make sure GOOGLE_PLACES_API_KEY is set in your .env file');
      throw Exception('Google Places API key not configured');
    }

    try {
      // Use time-based type if not specified
      final placeTypes = type != null
          ? [type]
          : getPlaceTypesForTime(DateTime.now());

      // Try each place type until we get results
      for (final placeType in placeTypes) {
        final params = {
          'location': '$latitude,$longitude',
          'radius': radius.toString(),
          'type': placeType,
          'key': apiKey,
        };

        if (keyword != null && keyword.isNotEmpty) {
          params['keyword'] = keyword;
        }

        final url = Uri.parse(
          '$_baseUrl/nearbysearch/json',
        ).replace(queryParameters: params);

        // debugPrint(
          '🔍 Searching Google Places: $placeType near ($latitude, $longitude)',
        );

        final response = await http
            .get(url)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Places request timed out');
              },
            );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String;

          if (status == 'OK') {
            final results = (data['results'] as List<dynamic>)
                .map(
                  (place) =>
                      PlaceResult.fromJson(place as Map<String, dynamic>),
                )
                .toList();

            if (results.isNotEmpty) {
              // debugPrint(
                '✅ Found ${results.length} places for type "$placeType"',
              );
              return results;
            }
          } else if (status == 'ZERO_RESULTS') {
            // // debugPrint('⚠️ No results for type "$placeType", trying next...');
            continue;
          } else {
            // Log full error details from Google
            // // debugPrint('❌ Google Places API error: $status');
            // // debugPrint('📄 Full API response: ${response.body}');

            if (status == 'REQUEST_DENIED') {
              final errorMessage = data['error_message'] as String?;
              // // debugPrint('🔴 REQUEST_DENIED details: $errorMessage');
              // // debugPrint('🔑 API Key (first 10 chars): ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');
              // // debugPrint('🌐 Request URL (without key): ${url.toString().replaceAll(apiKey, "***KEY***")}');

              throw Exception(
                'Google Places API request denied.\n'
                'Details: ${errorMessage ?? "No error message provided"}\n'
                'Common fixes:\n'
                '1. Enable "Places API (New)" in Google Cloud Console\n'
                '2. Check API key restrictions (should allow iOS/Android apps)\n'
                '3. Verify billing is enabled on your Google Cloud project\n'
                '4. Make sure the API key is not restricted to specific IPs/domains',
              );
            }
          }
        } else {
          // // debugPrint('❌ Google Places request failed: ${response.statusCode}');
          // // debugPrint('📄 Response body: ${response.body}');
          throw Exception('Places search failed: ${response.statusCode}');
        }
      }

      // No results found for any type
      // // debugPrint('⚠️ No places found for any type');
      return [];
    } catch (e) {
      // // debugPrint('❌ Google Places error: $e');
      rethrow;
    }
  }

  /// Get detailed information about a place
  ///
  /// [placeId] - The Google Place ID
  /// Returns detailed [PlaceDetails] or null if not found
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final apiKey = EnvConfig.get('GOOGLE_PLACES_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Google Places API key not configured');
    }

    try {
      final url = Uri.parse('$_baseUrl/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'key': apiKey,
          'fields':
              'name,rating,formatted_phone_number,opening_hours,website,price_level,reviews',
        },
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Place details request timed out');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result'] as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      // // debugPrint('❌ Place details error: $e');
      return null;
    }
  }
}

/// A place result from Google Places API
class PlaceResult {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? vicinity;
  final double? rating;
  final int? userRatingsTotal;
  final List<String> types;
  final bool? openNow;
  final String? icon;
  final String? photoReference;

  PlaceResult({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.vicinity,
    this.rating,
    this.userRatingsTotal,
    required this.types,
    this.openNow,
    this.icon,
    this.photoReference,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;

    return PlaceResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      vicinity: json['vicinity'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      types:
          (json['types'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      openNow: openingHours?['open_now'] as bool?,
      icon: json['icon'] as String?,
      photoReference: photos != null && photos.isNotEmpty
          ? (photos.first as Map<String, dynamic>)['photo_reference'] as String?
          : null,
    );
  }

  /// Get a user-friendly type description
  String get typeDescription {
    if (types.isEmpty) return 'Place';

    final type = types.first.replaceAll('_', ' ');
    return type
        .split(' ')
        .map((word) {
          return word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  /// Get rating display text
  String get ratingDisplay {
    if (rating == null) return 'No rating';
    final count = userRatingsTotal != null ? ' ($userRatingsTotal)' : '';
    return '${rating!.toStringAsFixed(1)}★$count';
  }
}

/// Detailed place information
class PlaceDetails {
  final String name;
  final double? rating;
  final String? phoneNumber;
  final String? website;
  final int? priceLevel;
  final bool? openNow;
  final List<String>? weekdayText;

  PlaceDetails({
    required this.name,
    this.rating,
    this.phoneNumber,
    this.website,
    this.priceLevel,
    this.openNow,
    this.weekdayText,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;

    return PlaceDetails(
      name: json['name'] as String,
      rating: (json['rating'] as num?)?.toDouble(),
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      priceLevel: json['price_level'] as int?,
      openNow: openingHours?['open_now'] as bool?,
      weekdayText: (openingHours?['weekday_text'] as List<dynamic>?)
          ?.map((t) => t.toString())
          .toList(),
    );
  }
}
