import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'env_config.dart';

double _parseDouble(dynamic value, String fieldName) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid $fieldName value: $value');
}

/// Route type for Mapbox Directions
enum RouteType {
  driving,
  walking,
  cycling;

  String get mapboxProfile {
    switch (this) {
      case RouteType.driving:
        return 'driving';
      case RouteType.walking:
        return 'walking';
      case RouteType.cycling:
        return 'cycling';
    }
  }

  String get displayName {
    switch (this) {
      case RouteType.driving:
        return 'Driving';
      case RouteType.walking:
        return 'Walking';
      case RouteType.cycling:
        return 'Cycling';
    }
  }

  String get emoji {
    switch (this) {
      case RouteType.driving:
        return '🚗';
      case RouteType.walking:
        return '🚶';
      case RouteType.cycling:
        return '🚴';
    }
  }
}

/// Location data for routes
class LocationData {
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final int? day;
  final String? placeType; // e.g., 'restaurant', 'museum', 'hotel'
  final String? placeIcon; // Icon name for display

  LocationData({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.day,
    this.placeType,
    this.placeIcon,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    final latValue = json['lat'] ?? json['latitude'];
    final lngValue = json['lng'] ?? json['longitude'];
    final nameValue = json['name'] ?? json['title'];

    return LocationData(
      name: nameValue is String && nameValue.isNotEmpty ? nameValue : 'Unknown',
      latitude: _parseDouble(latValue, 'latitude'),
      longitude: _parseDouble(lngValue, 'longitude'),
      description: json['description'] as String?,
      day: json['day'] as int?,
      placeType: json['placeType'] as String?,
      placeIcon: json['placeIcon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      if (day != null) 'day': day,
      if (placeType != null) 'placeType': placeType,
      if (placeIcon != null) 'placeIcon': placeIcon,
    };
  }

  /// Format as Mapbox coordinate string: "lng,lat"
  String get coordinateString => '$longitude,$latitude';
}

/// Route option representing a complete itinerary with multiple locations
class RouteOption {
  final String name;
  final String description;
  final List<LocationData> locations;
  final String? id; // Unique identifier for selection

  RouteOption({
    required this.name,
    required this.description,
    required this.locations,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    final locationsList = json['locations'] as List<dynamic>? ?? [];
    return RouteOption(
      name: json['name'] as String? ?? 'Route Option',
      description: json['description'] as String? ?? '',
      locations: locationsList
          .map((loc) => LocationData.fromJson(loc as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'locations': locations.map((loc) => loc.toJson()).toList(),
      'id': id,
    };
  }
}

/// Route information from Mapbox Directions API
class RouteInfo {
  final List<LocationData> waypoints;
  final RouteType routeType;
  final double distance; // meters
  final double duration; // seconds
  final List<List<double>> geometry; // List of [lng, lat] points
  final String? summary;

  RouteInfo({
    required this.waypoints,
    required this.routeType,
    required this.distance,
    required this.duration,
    required this.geometry,
    this.summary,
  });

  /// Distance in kilometers
  double get distanceKm => distance / 1000;

  /// Duration in minutes
  double get durationMin => duration / 60;

  /// Formatted distance string
  String get distanceFormatted {
    if (distanceKm < 1) {
      return '${distance.toInt()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.toInt()} km';
    }
  }

  /// Formatted duration string
  String get durationFormatted {
    if (durationMin < 60) {
      return '${durationMin.toInt()} min';
    } else {
      final hours = (durationMin / 60).floor();
      final mins = (durationMin % 60).toInt();
      return '${hours}h ${mins}min';
    }
  }
}

/// Mapbox Directions API service
class MapboxDirectionsService {
  static const String _baseUrl =
      'https://api.mapbox.com/directions/v5/mapbox';

  /// Calculate route between locations
  ///
  /// [waypoints] - List of locations to visit
  /// [routeType] - Type of route (driving, walking, cycling)
  /// Returns [RouteInfo] with route geometry and details
  static Future<RouteInfo> calculateRoute({
    required List<LocationData> waypoints,
    required RouteType routeType,
  }) async {
    if (waypoints.length < 2) {
      throw Exception('At least 2 waypoints required for route');
    }

    final token = EnvConfig.mapboxAccessToken;
    if (token.isEmpty) {
      throw Exception('Mapbox access token not configured');
    }

    try {
      // Build coordinates string: "lng,lat;lng,lat;lng,lat"
      final coordinates =
          waypoints.map((w) => w.coordinateString).join(';');

      // Build API URL
      final url = Uri.parse(
        '$_baseUrl/${routeType.mapboxProfile}/$coordinates.json'
        '?access_token=$token'
        '&geometries=geojson'
        '&overview=full'
        '&steps=false',
      );

      debugPrint('🗺️ Calculating ${routeType.displayName} route with ${waypoints.length} waypoints');

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Route calculation timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes == null || routes.isEmpty) {
          throw Exception('No route found');
        }

        final route = routes.first as Map<String, dynamic>;
        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();

        // Extract geometry coordinates
        final geometryData = route['geometry'] as Map<String, dynamic>;
        final coordinates = geometryData['coordinates'] as List<dynamic>;
        final geometry = coordinates
            .map((coord) => [
                  (coord[0] as num).toDouble(),
                  (coord[1] as num).toDouble()
                ])
            .toList();

        debugPrint('✅ Route calculated: ${distance / 1000} km, ${duration / 60} min');

        return RouteInfo(
          waypoints: waypoints,
          routeType: routeType,
          distance: distance,
          duration: duration,
          geometry: geometry,
          summary: route['legs']?[0]?['summary'] as String?,
        );
      } else {
        debugPrint('❌ Route calculation failed: ${response.statusCode}');
        throw Exception('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Route calculation error: $e');
      rethrow;
    }
  }

  /// Auto-detect appropriate route type based on total distance
  ///
  /// Logic:
  /// - < 5 km: Walking
  /// - 5-20 km: Cycling
  /// - > 20 km: Driving
  static RouteType detectRouteTypeForDistance(double distanceKm) {
    if (distanceKm < 5) {
      return RouteType.walking;
    }
    if (distanceKm < 20) {
      return RouteType.cycling;
    }
    return RouteType.driving;
  }

  static RouteType detectRouteType(List<LocationData> waypoints) {
    if (waypoints.length < 2) return RouteType.walking;

    // Calculate total straight-line distance
    double totalDistance = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += calculateDistance(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }

    debugPrint('📏 Total distance: ${totalDistance.toStringAsFixed(1)} km');

    final routeType = detectRouteTypeForDistance(totalDistance);

    switch (routeType) {
      case RouteType.walking:
        debugPrint('🚶 Auto-detected: Walking');
        break;
      case RouteType.cycling:
        debugPrint('🚴 Auto-detected: Cycling');
        break;
      case RouteType.driving:
        debugPrint('🚗 Auto-detected: Driving');
        break;
    }

    return routeType;
  }

  /// Calculate straight-line distance between two points (Haversine formula)
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  /// Optimize route by reordering waypoints to minimize total distance
  /// Uses nearest neighbor algorithm, keeping the first waypoint as start
  static List<LocationData> optimizeRoute(List<LocationData> waypoints) {
    if (waypoints.length <= 2) {
      return waypoints; // No optimization needed for 2 or fewer points
    }

    debugPrint('🔧 Optimizing route with ${waypoints.length} waypoints...');

    final optimized = <LocationData>[waypoints.first]; // Start with first point
    final remaining = List<LocationData>.from(waypoints.skip(1));

    // Nearest neighbor algorithm
    while (remaining.isNotEmpty) {
      final current = optimized.last;
      var nearestIndex = 0;
      var nearestDistance = double.infinity;

      // Find nearest unvisited point
      for (var i = 0; i < remaining.length; i++) {
        final distance = calculateDistance(
          current.latitude,
          current.longitude,
          remaining[i].latitude,
          remaining[i].longitude,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }

      // Add nearest point to optimized route
      optimized.add(remaining.removeAt(nearestIndex));
    }

    // Calculate improvement
    final originalDistance = _calculateTotalDistance(waypoints);
    final optimizedDistance = _calculateTotalDistance(optimized);
    final improvement = ((originalDistance - optimizedDistance) / originalDistance * 100);

    debugPrint('📊 Original distance: ${originalDistance.toStringAsFixed(1)} km');
    debugPrint('📊 Optimized distance: ${optimizedDistance.toStringAsFixed(1)} km');
    debugPrint('✅ Route optimized! Saved ${improvement.toStringAsFixed(1)}% distance');

    return optimized;
  }

  /// Calculate total distance for a route
  static double _calculateTotalDistance(List<LocationData> waypoints) {
    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += calculateDistance(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }
    return total;
  }

}
