import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/env_config.dart';
import '../services/mapbox_directions_service.dart';
import '../services/offline_storage_service.dart';
import '../services/theme_color.dart';
import '../services/mapbox_search_service.dart';
import '../services/google_places_service.dart';

/// Content-only widget for the map page (without navigation)
/// Used inside RootLayout
class MapPageContent extends StatefulWidget {
  final double bottomInset;
  final void Function(List<LocationData>, RouteType?)? onRouteDisplayed;

  const MapPageContent({
    super.key,
    this.bottomInset = 16,
    this.onRouteDisplayed,
  });

  @override
  State<MapPageContent> createState() => MapPageContentState();
}

class MapPageContentState extends State<MapPageContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final CameraOptions _cameraOptions;
  late final Widget _mapWidget;
  bool _hasToken = true;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _labelAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  List<LocationData>? _pendingLocations;
  RouteType? _pendingRouteType;
  bool _pendingIsRoute = false;
  bool _pendingReset = false;
  List<LocationData> _currentLocations = [];

  // Search state
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  List<String> _allSuggestions = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;
  bool _hasQuery = false;

  // Google Places state
  List<PlaceResult> _placeSuggestions = [];
  bool _isFetchingPlaces = false;
  PointAnnotationManager? _placesAnnotationManager;
  CircleAnnotationManager? _placesCircleManager; // Alternative using circles
  PointAnnotationManager? _placesLabelAnnotationManager;

  @override
  void initState() {
    super.initState();
    _cameraOptions = CameraOptions(
      center: Point(coordinates: Position(-98.0, 39.5)),
      zoom: 2,
      bearing: 0,
      pitch: 0,
    );

    final token = EnvConfig.mapboxAccessToken;
    if (token.isEmpty) {
      _hasToken = false;
    } else {
      MapboxOptions.setAccessToken(token);
    }

    _mapWidget = MapWidget(
      cameraOptions: _cameraOptions,
      onMapCreated: _onMapCreated,
    );

    _searchController.addListener(_filterSuggestions);
    _searchController.addListener(_updateQueryState);
    _searchFocusNode.addListener(_handleFocusChange);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Handle map creation
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Create point annotation manager for markers (search results)
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    // Create circle annotation manager for location markers (from AI)
    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    // Create label annotation manager for location names
    _labelAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    // Create polyline annotation manager for routes
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    // Create point annotation manager for Google Places suggestions
    _placesAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    // Also create circle manager as alternative
    _placesCircleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    // // debugPrint('✅ Map annotation managers created');
    _applyPendingMapUpdate();
  }

  /// Perform search
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final hadFocus = _searchFocusNode.hasFocus;

    setState(() {
      _isSearching = true;
      _showResults = false;
      _showSuggestions = false;
    });

    try {
      final results = await MapboxSearchService.search(query, limit: 10);

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _showResults = results.isNotEmpty;
      });

      _restoreFocusIfNeeded(hadFocus);

      if (results.isNotEmpty) {
        await _showMarkersOnMap(results);
        await _fitCameraToResults(results);
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _showResults = false;
      });

      _restoreFocusIfNeeded(hadFocus);

      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Search Error'),
          content: Text('Failed to search: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final raw = await rootBundle.loadString('assets/data/places.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _allSuggestions = decoded.whereType<String>().toList();
      }
    } catch (_) {
      _allSuggestions = [];
    }
  }

  void _handleFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
      });
    } else {
      _filterSuggestions();
    }
  }

  void _filterSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    final hadFocus = _searchFocusNode.hasFocus;
    if (query.isEmpty) {
      if (_showSuggestions || _filteredSuggestions.isNotEmpty) {
        setState(() {
          _filteredSuggestions = [];
          _showSuggestions = false;
        });
      }
      return;
    }

    final matches = _allSuggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .take(6)
        .toList();

    setState(() {
      _filteredSuggestions = matches;
      _showSuggestions = _searchFocusNode.hasFocus && matches.isNotEmpty;
    });

    if (hadFocus && !_searchFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_searchFocusNode.hasFocus) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _updateQueryState() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (hasQuery != _hasQuery) {
      setState(() {
        _hasQuery = hasQuery;
      });
    }
  }

  bool get _isMapReady =>
      _mapboxMap != null &&
      _pointAnnotationManager != null &&
      _circleAnnotationManager != null &&
      _labelAnnotationManager != null &&
      _polylineAnnotationManager != null;

  void _applyPendingMapUpdate() {
    if (_pendingReset) {
      _pendingReset = false;
      resetMap();
      return;
    }

    final locations = _pendingLocations;
    if (locations == null) return;

    final routeType = _pendingRouteType;
    final isRoute = _pendingIsRoute;
    _pendingLocations = null;
    _pendingRouteType = null;
    _pendingIsRoute = false;

    if (isRoute && routeType != null) {
      showRouteOnMap(locations, routeType);
    } else {
      showLocationsOnMap(locations);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showResults = false;
      _showSuggestions = false;
    });
    _restoreFocusIfNeeded(true);
  }

  /// Suggest nearby places using Google Places API based on route locations
  Future<void> _suggestNearbyPlaces() async {
    // // debugPrint('🟠 _suggestNearbyPlaces() called');
    // // debugPrint('   Current locations count: ${_currentLocations.length}');

    if (_mapboxMap == null) {
      // // debugPrint('❌ Map not initialized');
      return;
    }

    if (_currentLocations.isEmpty) {
      // // debugPrint('⚠️ No locations to search around');
      return;
    }

    setState(() {
      _isFetchingPlaces = true;
      _showResults = false;
      _showSuggestions = false;
    });

    try {
      // Calculate center of current route locations (not map center!)
      double centerLat = 0;
      double centerLng = 0;
      for (final location in _currentLocations) {
        centerLat += location.latitude;
        centerLng += location.longitude;
      }
      centerLat /= _currentLocations.length;
      centerLng /= _currentLocations.length;

      debugPrint(
        '🔍 Fetching places near route center at ($centerLat, $centerLng)',
      );
      // // debugPrint('   Route has ${_currentLocations.length} locations:');
      for (var i = 0; i < _currentLocations.length; i++) {
        final loc = _currentLocations[i];
        debugPrint(
          '   [$i] ${loc.name} at (${loc.latitude}, ${loc.longitude})',
        );
      }

      // Try multiple search strategies to always find suggestions
      List<PlaceResult> places = [];

      // Strategy 1: Try 500m radius with time-based types
      // // debugPrint('🔍 Strategy 1: Searching within 500m radius...');
      places = await GooglePlacesService.searchNearby(
        latitude: centerLat,
        longitude: centerLng,
        radius: 500,
      );
      // // debugPrint('   Found ${places.length} places');

      // Strategy 2: If no results, try 1000m radius
      if (places.isEmpty) {
        // // debugPrint('🔍 Strategy 2: Expanding to 1000m radius...');
        places = await GooglePlacesService.searchNearby(
          latitude: centerLat,
          longitude: centerLng,
          radius: 1000,
        );
        // // debugPrint('   Found ${places.length} places');
      }

      // Strategy 3: If still no results, try 2000m with popular places
      if (places.isEmpty) {
        debugPrint(
          '🔍 Strategy 3: Searching for popular places within 2000m...',
        );
        places = await GooglePlacesService.searchNearby(
          latitude: centerLat,
          longitude: centerLng,
          radius: 2000,
        );
        // // debugPrint('   Found ${places.length} places');
      }

      // Strategy 4: If still nothing, try 5000m radius (tourist attractions, landmarks)
      if (places.isEmpty) {
        // // debugPrint('🔍 Strategy 4: Searching for landmarks within 5000m...');
        places = await GooglePlacesService.searchNearby(
          latitude: centerLat,
          longitude: centerLng,
          radius: 5000,
        );
        // // debugPrint('   Found ${places.length} places');
      }

      // // debugPrint('✅ Total places found: ${places.length}');

      setState(() {
        _placeSuggestions = places;
        _isFetchingPlaces = false;
      });

      if (places.isNotEmpty) {
        // // debugPrint('🟠 Calling _showPlacesOnMap with ${places.length} places');
        await _showPlacesOnMap(places);

        // // debugPrint('🟠 Calling _fitCameraToPlaces');
        await _fitCameraToPlaces(places);

        // // debugPrint('✅ Successfully showed ${places.length} place markers');
      } else {
        // // debugPrint('⚠️ No places found even after all strategies');
        if (!mounted) return;
        _showNoPlacesFoundDialog();
      }
    } catch (e) {
      setState(() {
        _isFetchingPlaces = false;
        _placeSuggestions = [];
      });

      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Places Error'),
          content: Text('Failed to fetch nearby places: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Show place markers on the map with tap listeners
  Future<void> _showPlacesOnMap(List<PlaceResult> places) async {
    if (_placesAnnotationManager == null) {
      // // debugPrint('❌ Places annotation manager is null!');
      return;
    }

    // // debugPrint('🟠 Clearing old place markers...');
    await _placesAnnotationManager!.deleteAll();
    await _placesLabelAnnotationManager?.deleteAll();

    // // debugPrint('🟠 Creating ${places.length} orange place markers...');
    final annotations = <PointAnnotationOptions>[];
    final labelAnnotations = <PointAnnotationOptions>[];

    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      debugPrint(
        '   [$i] ${place.name} at (${place.latitude}, ${place.longitude})',
      );

      try {
        final annotation = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(place.longitude, place.latitude),
          ),
          iconImage: 'marker-15',
          iconSize: 2.5, // Even larger for visibility
          iconAnchor: IconAnchor.BOTTOM,
          iconColor: 0xFFFF6B35, // Vibrant orange
        );
        annotations.add(annotation);
        // // debugPrint('   ✓ Annotation $i created');
      } catch (e) {
        // // debugPrint('   ✗ Error creating annotation $i: $e');
      }
    }

    // // debugPrint('🟠 Total annotations to create: ${annotations.length}');

    final createdAnnotations = await _placesAnnotationManager!.createMulti(
      annotations,
    );
    // // debugPrint('✅ Created ${createdAnnotations.length} point annotations');

    if (createdAnnotations.isEmpty && places.isNotEmpty) {
      // // debugPrint('⚠️ WARNING: Places exist but no point markers created!');
    }

    if (labelAnnotations.isNotEmpty && _placesLabelAnnotationManager != null) {
      final createdLabels = await _placesLabelAnnotationManager!.createMulti(
        labelAnnotations,
      );
      // // debugPrint('✅ Created ${createdLabels.length} place emoji labels');
    }

    // ALSO create circle markers as backup (we know these work)
    // // debugPrint('🔵 Creating backup circle markers...');
    if (_placesCircleManager != null) {
      await _placesCircleManager!.deleteAll();

      final circleAnnotations = <CircleAnnotationOptions>[];
      for (var i = 0; i < places.length; i++) {
        final place = places[i];
        circleAnnotations.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(place.longitude, place.latitude),
            ),
            circleRadius: 15.0, // Larger for visibility
            circleColor: 0xFFFF6B35, // Orange
            circleStrokeColor: 0xFFFFFFFF, // White stroke
            circleStrokeWidth: 3.0,
          ),
        );
      }

      final createdCircles = await _placesCircleManager!.createMulti(
        circleAnnotations,
      );
      // // debugPrint('✅ Created ${createdCircles.length} orange circle markers');
    }

    // Verify markers are still there after creation
    await Future.delayed(const Duration(milliseconds: 100));
    final allAnnotations = await _placesAnnotationManager!.getAnnotations();
    debugPrint(
      '🔍 Verification: ${allAnnotations.length} point markers exist after creation',
    );

    if (allAnnotations.isEmpty && createdAnnotations.isNotEmpty) {
      debugPrint(
        '🚨 CRITICAL: Point markers were created but disappeared immediately!',
      );
    }

    // Add tap listener for place markers
    _placesAnnotationManager!.addOnPointAnnotationClickListener(
      _PlaceAnnotationClickListener(
        onTap: (annotation) {
          // Find which place was tapped based on coordinates
          final tappedCoords = annotation.geometry.coordinates;
          for (final place in _placeSuggestions) {
            if ((place.longitude - tappedCoords.lng).abs() < 0.0001 &&
                (place.latitude - tappedCoords.lat).abs() < 0.0001) {
              // // debugPrint('🟠 Place marker tapped: ${place.name}');
              _showPlaceDetailsModal(place);
              break;
            }
          }
        },
      ),
    );

    // Also add tap listener for circles
    if (_placesCircleManager != null) {
      _placesCircleManager!.addOnCircleAnnotationClickListener(
        _CircleAnnotationClickListener(
          onTap: (annotation) {
            final tappedCoords = annotation.geometry.coordinates;
            for (final place in _placeSuggestions) {
              if ((place.longitude - tappedCoords.lng).abs() < 0.0001 &&
                  (place.latitude - tappedCoords.lat).abs() < 0.0001) {
                // // debugPrint('🟠 Circle marker tapped: ${place.name}');
                _showPlaceDetailsModal(place);
                break;
              }
            }
          },
        ),
      );
    }
  }

  /// Show modal with place details and option to add to route
  void _showPlaceDetailsModal(PlaceResult place) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: ThemeColor.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColor.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.sparkles,
                              size: 24,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Rating
                      if (place.rating != null) ...[
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.star,
                              size: 18,
                              color: Color(0xFFFFA000),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              place.ratingDisplay,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Type
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 18,
                            color: ThemeColor.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            place.typeDescription,
                            style: const TextStyle(
                              fontSize: 15,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Address
                      if (place.vicinity != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.navigation,
                              size: 18,
                              color: ThemeColor.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                place.vicinity!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: ThemeColor.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Open now indicator
                      if (place.openNow != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 18,
                              color: place.openNow!
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              place.openNow! ? 'Open now' : 'Closed',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: place.openNow!
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Divider
                      Container(
                        height: 1,
                        color: ThemeColor.textSecondary.withOpacity(0.1),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          // Zoom to place button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _goToPlace(place);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColor.textSecondary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.zoomIn,
                                      size: 18,
                                      color: ThemeColor.textPrimary,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Zoom to Place',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeColor.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Add to route button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _addPlaceToRoute(place);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.plus,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add to Route',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Add a place to the current route
  void _addPlaceToRoute(PlaceResult place) {
    // Convert PlaceResult to LocationData
    final newLocation = LocationData(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      description: place.vicinity ?? place.typeDescription,
      day: null,
      placeType: place.types.isNotEmpty ? place.types.first : null,
      placeIcon: place.icon ?? 'google',
    );

    // Add to current locations
    var updatedLocations = [..._currentLocations, newLocation];

    debugPrint(
      '✅ Added ${place.name} to route (${updatedLocations.length} total locations)',
    );

    // Auto-optimize route if we have 3+ locations
    if (updatedLocations.length >= 3) {
      // // debugPrint('🔧 Auto-optimizing route...');
      updatedLocations = MapboxDirectionsService.optimizeRoute(
        updatedLocations,
      );
    }

    // Show the updated route on the map
    if (updatedLocations.length >= 2) {
      // If we have multiple locations, show as a route
      showRouteOnMap(updatedLocations, RouteType.walking);
    } else {
      // If only one location, just show the marker
      showLocationsOnMap(updatedLocations);
    }

    // Show confirmation
    final wasOptimized = updatedLocations.length >= 3;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Added to Route'),
        content: Text(
          wasOptimized
              ? '${place.name} has been added and your route with ${updatedLocations.length} locations has been optimized for the shortest distance!'
              : '${place.name} has been added to your route with ${updatedLocations.length} ${updatedLocations.length == 1 ? 'location' : 'locations'}.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Fit camera to show all places
  Future<void> _fitCameraToPlaces(List<PlaceResult> places) async {
    if (_mapboxMap == null || places.isEmpty) return;

    if (places.length == 1) {
      final place = places.first;
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(place.longitude, place.latitude)),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 800),
      );
      return;
    }

    // Calculate bounds
    double minLng = places.first.longitude;
    double maxLng = places.first.longitude;
    double minLat = places.first.latitude;
    double maxLat = places.first.latitude;

    for (final place in places) {
      if (place.longitude < minLng) minLng = place.longitude;
      if (place.longitude > maxLng) maxLng = place.longitude;
      if (place.latitude < minLat) minLat = place.latitude;
      if (place.latitude > maxLat) maxLat = place.latitude;
    }

    final centerLng = (minLng + maxLng) / 2;
    final centerLat = (minLat + maxLat) / 2;

    final lngDiff = maxLng - minLng;
    final latDiff = maxLat - minLat;
    final maxDiff = lngDiff > latDiff ? lngDiff : latDiff;

    double zoom = 12;
    if (maxDiff > 5) {
      zoom = 5;
    } else if (maxDiff > 2) {
      zoom = 7;
    } else if (maxDiff > 1) {
      zoom = 8;
    } else if (maxDiff > 0.5) {
      zoom = 9;
    } else if (maxDiff > 0.2) {
      zoom = 10;
    } else if (maxDiff > 0.1) {
      zoom = 11;
    }

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  /// Navigate to a selected place
  void _goToPlace(PlaceResult place) {
    if (_mapboxMap != null) {
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(place.longitude, place.latitude)),
          zoom: 16,
        ),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  void _showNoPlacesFoundDialog() {
    final timeDesc = GooglePlacesService.getPlaceTypeDescription(
      DateTime.now(),
    );
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No Places Found'),
        content: Text(
          'No $timeDesc found in this area. Try moving the map to a different location.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    setState(() {
      _showSuggestions = false;
    });
    _restoreFocusIfNeeded(true);
    _performSearch();
  }

  void _restoreFocusIfNeeded(bool hadFocus) {
    if (!hadFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Widget _buildSuggestionsList() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.35,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: _filteredSuggestions.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          color: ThemeColor.textSecondary.withOpacity(0.08),
        ),
        itemBuilder: (context, index) {
          final suggestion = _filteredSuggestions[index];
          return GestureDetector(
            onTap: () => _selectSuggestion(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 16,
                    color: ThemeColor.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      suggestion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Show markers for search results
  Future<void> _showMarkersOnMap(List<SearchResult> results) async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();

    final annotations = results.map((result) {
      return PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(result.longitude, result.latitude),
        ),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconAnchor: IconAnchor.BOTTOM,
      );
    }).toList();

    await _pointAnnotationManager!.createMulti(annotations);
  }

  Future<void> _clearMapOverlays({bool preservePlaces = false}) async {
    // // debugPrint('🧹 Clearing map overlays (preservePlaces: $preservePlaces)...');
    await _pointAnnotationManager?.deleteAll();
    await _circleAnnotationManager?.deleteAll();
    await _labelAnnotationManager?.deleteAll();
    await _polylineAnnotationManager?.deleteAll();

    // Only clear place markers if not preserving them
    if (!preservePlaces) {
      await _placesAnnotationManager?.deleteAll();
      await _placesCircleManager?.deleteAll();
      await _placesLabelAnnotationManager?.deleteAll();
      // // debugPrint('   Cleared place markers');
    } else {
      // // debugPrint('   Preserved place markers');
    }

    // // debugPrint('✅ Map overlays cleared');
  }

  Future<void> _showLocationMarkers(List<LocationData> locations) async {
    if (_circleAnnotationManager == null || _labelAnnotationManager == null) {
      // // debugPrint('❌ Circle or label annotation manager is null');
      return;
    }

    // Store current locations for tap handling
    _currentLocations = locations;

    // // debugPrint('📍 Creating ${locations.length} numbered markers with labels');
    final circleAnnotations = <CircleAnnotationOptions>[];
    final labelAnnotations = <PointAnnotationOptions>[];
    final numberAnnotations = <PointAnnotationOptions>[];

    for (var i = 0; i < locations.length; i++) {
      final location = locations[i];
      final markerNumber = i + 1;
      debugPrint(
        '   Creating marker $markerNumber: ${location.name} at (${location.latitude}, ${location.longitude})',
      );

      // Get place icon/emoji based on place type
      String placeEmoji = _getPlaceEmoji(location.placeType);

      // Create circle marker with custom data for tap handling
      circleAnnotations.add(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          circleRadius: 14.0, // Slightly bigger radius for number
          circleColor: ThemeColor.primary.value,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 3.0, // Thicker stroke
        ),
      );

      // Create number text on the marker
      numberAnnotations.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          textField: '$markerNumber',
          textSize: 14.0,
          textColor: 0xFFFFFFFF, // White text
          textHaloColor: ThemeColor.primary.value, // Primary color halo
          textHaloWidth: 1.0,
          textOffset: [0.0, 0.0], // Centered on marker
          textAnchor: TextAnchor.CENTER,
        ),
      );

      // Create location name label with emoji if available
      final labelText = placeEmoji.isNotEmpty
          ? '$placeEmoji ${location.name}'
          : location.name;

      labelAnnotations.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          textField: labelText,
          textSize: 12.0,
          textColor: 0xFF000000, // Black text
          textHaloColor: 0xFFFFFFFF, // White halo for readability
          textHaloWidth: 2.0,
          textOffset: [0.0, -2.5], // Offset above the marker
          textAnchor: TextAnchor.BOTTOM,
        ),
      );
    }

    final createdCircles = await _circleAnnotationManager!.createMulti(
      circleAnnotations,
    );
    final createdLabels = await _labelAnnotationManager!.createMulti(
      labelAnnotations,
    );
    final createdNumbers = await _labelAnnotationManager!.createMulti(
      numberAnnotations,
    );

    // Add tap listener for circles
    _circleAnnotationManager!.addOnCircleAnnotationClickListener(
      _CircleAnnotationClickListener(
        onTap: (annotation) {
          // Find which location was tapped based on coordinates
          final tappedCoords = annotation.geometry.coordinates;
          for (final location in _currentLocations) {
            // Check if coordinates match (with small tolerance for floating point)
            if ((location.longitude - tappedCoords.lng).abs() < 0.0001 &&
                (location.latitude - tappedCoords.lat).abs() < 0.0001) {
              // // debugPrint('📍 Marker tapped: ${location.name}');
              _showLocationDetails(location);
              break;
            }
          }
        },
      ),
    );

    debugPrint(
      '✅ Successfully created ${createdCircles.length} markers, ${createdNumbers.length} numbers, and ${createdLabels.length} labels on map',
    );
  }

  /// Get emoji icon based on place type
  String _getPlaceEmoji(String? placeType) {
    if (placeType == null || placeType.isEmpty) return '';

    final type = placeType.toLowerCase();

    // Common place type mappings to emojis
    if (type.contains('restaurant') || type.contains('food')) return '🍽️';
    if (type.contains('cafe') || type.contains('coffee')) return '☕';
    if (type.contains('bar') || type.contains('night_club')) return '🍺';
    if (type.contains('hotel') || type.contains('lodging')) return '🏨';
    if (type.contains('museum')) return '🏛️';
    if (type.contains('park')) return '🌳';
    if (type.contains('shopping') || type.contains('store')) return '🛍️';
    if (type.contains('gym') || type.contains('stadium')) return '⚽';
    if (type.contains('hospital') || type.contains('doctor')) return '🏥';
    if (type.contains('pharmacy')) return '💊';
    if (type.contains('bank') || type.contains('atm')) return '🏦';
    if (type.contains('airport')) return '✈️';
    if (type.contains('train') || type.contains('subway')) return '🚆';
    if (type.contains('bus')) return '🚌';
    if (type.contains('church') ||
        type.contains('mosque') ||
        type.contains('temple'))
      return '⛪';
    if (type.contains('school') || type.contains('university')) return '🎓';
    if (type.contains('library')) return '📚';
    if (type.contains('movie') || type.contains('theater')) return '🎭';
    if (type.contains('spa') || type.contains('beauty')) return '💆';
    if (type.contains('gas_station') || type.contains('fuel')) return '⛽';
    if (type.contains('parking')) return '🅿️';
    if (type.contains('beach')) return '🏖️';
    if (type.contains('mountain')) return '⛰️';
    if (type.contains('tourist')) return '📸';

    return '📍'; // Default location pin
  }

  /// Launch external navigation app with route waypoints
  Future<void> _launchExternalNavigation(
    List<LocationData> locations,
    RouteType routeType,
  ) async {
    if (locations.isEmpty) return;

    try {
      // Determine travel mode based on route type
      String travelMode;
      switch (routeType) {
        case RouteType.walking:
          travelMode = 'walking';
          break;
        case RouteType.cycling:
          travelMode = 'bicycling';
          break;
        case RouteType.driving:
          travelMode = 'driving';
          break;
      }

      if (Platform.isIOS) {
        // Try Apple Maps first on iOS
        final appleMapsUrl = _buildAppleMapsUrl(locations, travelMode);
        final appleMapsUri = Uri.parse(appleMapsUrl);

        if (await canLaunchUrl(appleMapsUri)) {
          await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
          // // debugPrint('✅ Launched Apple Maps');
          return;
        }
      }

      // Fallback to Google Maps (works on both iOS and Android)
      final googleMapsUrl = _buildGoogleMapsUrl(locations, travelMode);
      final googleMapsUri = Uri.parse(googleMapsUrl);

      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
        // // debugPrint('✅ Launched Google Maps');
      } else {
        throw Exception('No map app available');
      }
    } catch (e) {
      // // debugPrint('❌ Failed to launch navigation: $e');
      if (!mounted) return;

      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Navigation Error'),
          content: const Text(
            'Could not open navigation app. Please make sure you have Google Maps or Apple Maps installed.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Build Apple Maps URL with waypoints
  String _buildAppleMapsUrl(List<LocationData> locations, String travelMode) {
    if (locations.isEmpty) return '';

    // Apple Maps URL scheme
    // For multiple waypoints, we use the destination and let Apple Maps optimize
    final destination = locations.last;
    final daddr = '${destination.latitude},${destination.longitude}';

    // Apple Maps transport type: d=driving, w=walking, r=transit
    String transportType = 'd';
    if (travelMode == 'walking') {
      transportType = 'w';
    } else if (travelMode == 'bicycling') {
      transportType = 'w'; // Apple Maps doesn't have cycling, use walking
    }

    // If we have waypoints, encode them
    if (locations.length > 2) {
      // Get intermediate waypoints (excluding first and last)
      final waypoints = locations.sublist(1, locations.length - 1);
      final waypointStr = waypoints
          .map((loc) => '${loc.latitude},${loc.longitude}')
          .join('|');

      return 'http://maps.apple.com/?daddr=$daddr&dirflg=$transportType&waypoints=$waypointStr';
    }

    return 'http://maps.apple.com/?daddr=$daddr&dirflg=$transportType';
  }

  /// Build Google Maps URL with waypoints
  String _buildGoogleMapsUrl(List<LocationData> locations, String travelMode) {
    if (locations.isEmpty) return '';

    final origin = locations.first;
    final destination = locations.last;

    // Build waypoints string (all points between origin and destination)
    String waypointsParam = '';
    if (locations.length > 2) {
      final waypoints = locations.sublist(1, locations.length - 1);
      waypointsParam = waypoints
          .map((loc) => '${loc.latitude},${loc.longitude}')
          .join('|');
    }

    // Google Maps URL
    final originParam = '${origin.latitude},${origin.longitude}';
    final destParam = '${destination.latitude},${destination.longitude}';

    var url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$originParam'
        '&destination=$destParam'
        '&travelmode=$travelMode';

    if (waypointsParam.isNotEmpty) {
      url += '&waypoints=$waypointsParam';
    }

    return url;
  }

  void _showLocationDetails(LocationData location) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: const BoxDecoration(
            color: ThemeColor.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ThemeColor.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location name
                  Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description if available
                  if (location.description != null &&
                      location.description!.isNotEmpty) ...[
                    Text(
                      location.description!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: ThemeColor.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Coordinates
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 16,
                        color: ThemeColor.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: ThemeColor.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Close',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _drawRoute(RouteInfo route) async {
    if (_polylineAnnotationManager == null) return;

    final positions = route.geometry
        .map((coord) => Position(coord[0], coord[1]))
        .toList();

    final line = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: ThemeColor.primary.value,
      lineWidth: 4.0,
    );

    await _polylineAnnotationManager!.create(line);
  }

  Future<void> _fitCameraToLocations(List<LocationData> locations) async {
    if (_mapboxMap == null || locations.isEmpty) {
      debugPrint(
        '❌ Cannot fit camera: map=${_mapboxMap != null}, locations=${locations.length}',
      );
      return;
    }

    // // debugPrint('📷 Fitting camera to ${locations.length} location(s)');
    for (var i = 0; i < locations.length; i++) {
      debugPrint(
        '   [$i] ${locations[i].name}: ${locations[i].latitude}, ${locations[i].longitude}',
      );
    }

    if (locations.length == 1) {
      final location = locations.first;
      // // debugPrint('📍 Single location - zooming to level 12');
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          zoom: 12,
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 1000, startDelay: 0),
      );
      // // debugPrint('✅ Camera moved to single location');
      return;
    }

    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;

    for (final location in locations) {
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
    }

    // // debugPrint('📐 Bounds: Lng[$minLng, $maxLng], Lat[$minLat, $maxLat]');

    final padding = 0.1;
    final lngPadding = (maxLng - minLng) * padding;
    final latPadding = (maxLat - minLat) * padding;

    final centerLng = (minLng + maxLng) / 2;
    final centerLat = (minLat + maxLat) / 2;
    final zoomLevel = _calculateZoomLevel(
      maxLng - minLng + lngPadding * 2,
      maxLat - minLat + latPadding * 2,
    );

    // // debugPrint('📷 Camera center: ($centerLat, $centerLng), zoom: $zoomLevel');

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoomLevel,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1500, startDelay: 0),
    );
    // // debugPrint('✅ Camera fitted to all locations');
  }

  /// Fit camera to show all search results
  Future<void> _fitCameraToResults(List<SearchResult> results) async {
    if (_mapboxMap == null || results.isEmpty) return;

    if (results.length == 1) {
      final result = results.first;
      final zoom = _getZoomLevelForPlaceType(result.placeType);
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(result.longitude, result.latitude),
          ),
          zoom: zoom,
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 1000, startDelay: 0),
      );
      return;
    }

    double minLng = results.first.longitude;
    double maxLng = results.first.longitude;
    double minLat = results.first.latitude;
    double maxLat = results.first.latitude;

    for (final result in results) {
      if (result.longitude < minLng) minLng = result.longitude;
      if (result.longitude > maxLng) maxLng = result.longitude;
      if (result.latitude < minLat) minLat = result.latitude;
      if (result.latitude > maxLat) maxLat = result.latitude;
    }

    final padding = 0.1;
    final lngPadding = (maxLng - minLng) * padding;
    final latPadding = (maxLat - minLat) * padding;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position((minLng + maxLng) / 2, (minLat + maxLat) / 2),
        ),
        zoom: _calculateZoomLevel(
          maxLng - minLng + lngPadding * 2,
          maxLat - minLat + latPadding * 2,
        ),
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1500, startDelay: 0),
    );
  }

  /// Calculate appropriate zoom level based on bounds
  double _calculateZoomLevel(double lngSpan, double latSpan) {
    final maxSpan = lngSpan > latSpan ? lngSpan : latSpan;
    if (maxSpan >= 180) return 1;
    if (maxSpan >= 90) return 2;
    if (maxSpan >= 45) return 3;
    if (maxSpan >= 20) return 4;
    if (maxSpan >= 10) return 5;
    if (maxSpan >= 5) return 6;
    if (maxSpan >= 2) return 7;
    if (maxSpan >= 1) return 8;
    if (maxSpan >= 0.5) return 9;
    if (maxSpan >= 0.2) return 10;
    return 11;
  }

  /// Navigate to a specific search result
  Future<void> _goToResult(SearchResult result) async {
    if (_mapboxMap == null) return;

    setState(() {
      _showResults = false;
    });

    final zoom = _getZoomLevelForPlaceType(result.placeType);

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(result.longitude, result.latitude)),
        zoom: zoom,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  /// Get appropriate zoom level based on place type
  double _getZoomLevelForPlaceType(String? placeType) {
    if (placeType == null) return 10; // Default

    switch (placeType.toLowerCase()) {
      case 'country':
        return 5; // Country view - very zoomed out
      case 'region':
        return 7; // State/region view
      case 'place':
        return 11; // City view
      case 'district':
      case 'locality':
        return 12; // District/neighborhood view
      case 'poi':
      case 'poi.landmark':
        return 15; // Point of interest - zoom in close
      case 'address':
        return 16; // Street address - very close
      default:
        return 10; // Default moderate zoom
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasToken) {
      return const Center(
        child: Text(
          'Missing MAPBOX_ACCESS_TOKEN in .env',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ThemeColor.textSecondary,
          ),
        ),
      );
    }

    // Get keyboard height to adjust UI when keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          Focus(canRequestFocus: false, skipTraversal: true, child: _mapWidget),

          // Local suggestions list
          if (!_showResults &&
              _showSuggestions &&
              _filteredSuggestions.isNotEmpty)
            Positioned(
              key: const ValueKey('map_suggestions'),
              left: 16,
              right: 16,
              bottom: widget.bottomInset + 80 + keyboardHeight,
              child: _buildSuggestionsList(),
            ),

          // Search results list
          if (_showResults && _searchResults.isNotEmpty)
            Positioned(
              key: const ValueKey('map_results'),
              left: 16,
              right: 16,
              bottom: widget.bottomInset + 80 + keyboardHeight,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0x1A000000),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Search Results',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showResults = false;
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ThemeColor.background,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 16,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return GestureDetector(
                            onTap: () => _goToResult(result),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ThemeColor.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: ThemeColor.primary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      LucideIcons.mapPin,
                                      size: 20,
                                      color: ThemeColor.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          result.shortName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: ThemeColor.textPrimary,
                                          ),
                                        ),
                                        if (result.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            result.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: ThemeColor.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 16,
                                    color: ThemeColor.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar
          Positioned(
            key: const ValueKey('map_search_bar'),
            left: 16,
            right: 16,
            bottom: widget.bottomInset + keyboardHeight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ThemeColor.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: 'map.input_placeholder'.tr(),
                      placeholderStyle: const TextStyle(
                        color: ThemeColor.textSecondary,
                        fontSize: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeColor.background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: ThemeColor.textPrimary,
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  if (_hasQuery) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ThemeColor.textSecondary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 14,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isSearching ? null : _performSearch,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isSearching
                            ? ThemeColor.primary.withOpacity(0.5)
                            : ThemeColor.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSearching
                          ? const CupertinoActivityIndicator(
                              color: ThemeColor.background,
                              radius: 8,
                            )
                          : const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: ThemeColor.textPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating action button for place suggestions (only show when there are locations)
          if (_currentLocations.isNotEmpty)
            Positioned(
              right: 16,
              bottom: widget.bottomInset + 70 + keyboardHeight,
              child: GestureDetector(
                onTap: _isFetchingPlaces ? null : _suggestNearbyPlaces,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isFetchingPlaces
                        ? const Color(0xFFFF6B35).withOpacity(0.5)
                        : const Color(0xFFFF6B35), // Orange for suggestions
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isFetchingPlaces
                      ? const CupertinoActivityIndicator(
                          color: Colors.white,
                          radius: 12,
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              LucideIcons.sparkles,
                              size: 24,
                              color: Colors.white,
                            ),
                            // Debug indicator showing count
                            if (_placeSuggestions.isNotEmpty)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_placeSuggestions.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void showSavedRoutesSheet() {
    _showSavedRoutesSheet();
  }

  void showLocationsListSheet(
    List<LocationData> locations,
    RouteType? routeType, {
    Function(List<LocationData>, RouteType?)? onRouteUpdated,
  }) {
    _showLocationsListSheet(
      locations,
      routeType,
      onRouteUpdated: onRouteUpdated,
    );
  }

  Future<void> resetMap() async {
    _pendingLocations = null;
    _pendingRouteType = null;
    _pendingIsRoute = false;
    _pendingReset = false;
    _currentLocations = [];

    if (!_isMapReady) {
      _pendingReset = true;
      return;
    }

    if (!mounted) return;

    _searchController.clear();
    setState(() {
      _searchResults = [];
      _filteredSuggestions = [];
      _showResults = false;
      _showSuggestions = false;
      _hasQuery = false;
    });

    await _clearMapOverlays();

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(0, 0)),
        zoom: 1,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 800, startDelay: 0),
    );
  }

  Future<void> showLocationsOnMap(List<LocationData> locations) async {
    debugPrint(
      '🗺️ MapPage.showLocationsOnMap called with ${locations.length} locations',
    );
    // // debugPrint('   Map ready: $_isMapReady');

    if (!_isMapReady) {
      // // debugPrint('⏳ Map not ready, saving as pending');
      _pendingReset = false;
      _pendingLocations = locations;
      _pendingRouteType = null;
      _pendingIsRoute = false;
      return;
    }

    if (!mounted) {
      // // debugPrint('❌ Widget not mounted');
      return;
    }
    if (locations.isEmpty) {
      // // debugPrint('❌ No locations to show');
      return;
    }

    // // debugPrint('🧹 Clearing search UI');
    setState(() {
      _showResults = false;
      _showSuggestions = false;
    });

    // // debugPrint('🧹 Clearing existing map overlays (preserving places)');
    await _clearMapOverlays(preservePlaces: true);
    // // debugPrint('📍 Adding ${locations.length} location markers');
    await _showLocationMarkers(locations);

    // Small delay to ensure markers are rendered before zooming
    await Future.delayed(const Duration(milliseconds: 300));

    // // debugPrint('📷 Fitting camera to locations');
    await _fitCameraToLocations(locations);
    // // debugPrint('✅ Locations displayed on map');
    widget.onRouteDisplayed?.call(locations, null);
  }

  Future<void> showRouteOnMap(
    List<LocationData> locations,
    RouteType routeType,
  ) async {
    debugPrint(
      '🗺️ MapPage.showRouteOnMap called with ${locations.length} locations',
    );
    // // debugPrint('   Route type: ${routeType.name}');
    // // debugPrint('   Map ready: $_isMapReady');

    if (!_isMapReady) {
      // // debugPrint('⏳ Map not ready, saving as pending');
      _pendingReset = false;
      _pendingLocations = locations;
      _pendingRouteType = routeType;
      _pendingIsRoute = true;
      return;
    }

    if (!mounted) {
      // // debugPrint('❌ Widget not mounted');
      return;
    }
    if (locations.isEmpty) {
      // // debugPrint('❌ No locations to show');
      return;
    }

    // // debugPrint('🧹 Clearing search UI');
    setState(() {
      _showResults = false;
      _showSuggestions = false;
    });

    if (locations.length < 2) {
      // // debugPrint('ℹ️ Only 1 location, showing as marker instead of route');
      await showLocationsOnMap(locations);
      return;
    }

    // // debugPrint('🧹 Clearing existing map overlays (preserving places)');
    await _clearMapOverlays(preservePlaces: true);
    // // debugPrint('📍 Adding ${locations.length} location markers');
    await _showLocationMarkers(locations);

    try {
      // // debugPrint('🛣️ Calculating route with Mapbox...');
      final route = await MapboxDirectionsService.calculateRoute(
        waypoints: locations,
        routeType: routeType,
      );
      // // debugPrint('✅ Route calculated successfully');
      // // debugPrint('📏 Drawing route on map');
      await _drawRoute(route);

      // Small delay to ensure route is rendered before zooming
      await Future.delayed(const Duration(milliseconds: 300));

      // // debugPrint('📷 Fitting camera to locations');
      await _fitCameraToLocations(locations);
      // // debugPrint('✅ Route displayed on map');
    } catch (e) {
      // // debugPrint('❌ Route calculation failed: $e');

      // Small delay before zooming
      await Future.delayed(const Duration(milliseconds: 300));

      // // debugPrint('📷 Fitting camera to locations (without route)');
      await _fitCameraToLocations(locations);
    }
    widget.onRouteDisplayed?.call(locations, routeType);
  }

  void _showLocationsListSheet(
    List<LocationData> locations,
    RouteType? routeType, {
    Function(List<LocationData>, RouteType?)? onRouteUpdated,
  }) {
    final reorderableLocations = List<LocationData>.from(locations);
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: ThemeColor.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ThemeColor.textSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title with hint
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Locations (${reorderableLocations.length})',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ThemeColor.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Long press and drag to reorder',
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeColor.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reorderable Locations list with timeline
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: reorderableLocations.length,
                          onReorder: (oldIndex, newIndex) {
                            setModalState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = reorderableLocations.removeAt(
                                oldIndex,
                              );
                              reorderableLocations.insert(newIndex, item);
                            });
                            // // debugPrint('🔄 Reordered: $oldIndex -> $newIndex');
                          },
                          itemBuilder: (context, index) {
                            final location = reorderableLocations[index];
                            final isLast =
                                index == reorderableLocations.length - 1;

                            // Calculate distance to next waypoint
                            String? distanceText;
                            String? durationText;
                            RouteType? segmentRouteType;
                            if (!isLast && routeType != null) {
                              final nextLocation =
                                  reorderableLocations[index + 1];
                              final distance =
                                  MapboxDirectionsService.calculateDistance(
                                    location.latitude,
                                    location.longitude,
                                    nextLocation.latitude,
                                    nextLocation.longitude,
                                  );
                              final resolvedSegmentRouteType =
                                  MapboxDirectionsService.detectRouteTypeForDistance(
                                    distance,
                                  );
                              segmentRouteType = resolvedSegmentRouteType;

                              // Format distance
                              if (distance < 1) {
                                distanceText = '${(distance * 1000).toInt()} m';
                              } else if (distance < 10) {
                                distanceText =
                                    '${distance.toStringAsFixed(1)} km';
                              } else {
                                distanceText = '${distance.toInt()} km';
                              }

                              // Estimate duration based on route type and distance
                              double speedKmh;
                              switch (resolvedSegmentRouteType) {
                                case RouteType.walking:
                                  speedKmh = 5; // 5 km/h walking
                                  break;
                                case RouteType.cycling:
                                  speedKmh = 15; // 15 km/h cycling
                                  break;
                                case RouteType.driving:
                                  speedKmh =
                                      60; // 60 km/h driving (average with traffic)
                                  break;
                              }

                              final durationHours = distance / speedKmh;
                              final durationMin = (durationHours * 60).toInt();

                              if (durationMin < 60) {
                                durationText = '${durationMin} min';
                              } else {
                                final hours = durationMin ~/ 60;
                                final mins = durationMin % 60;
                                durationText = '${hours}h ${mins}min';
                              }
                            }

                            return Column(
                              key: ValueKey(location.name + index.toString()),
                              children: [
                                // Location card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: ThemeColor.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      // Number badge
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: ThemeColor.inputBackground,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: ThemeColor.divider,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: ThemeColor.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Location info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    location.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: ThemeColor
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (location.placeIcon !=
                                                        null &&
                                                    location
                                                        .placeIcon!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: ThemeColor.surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            ThemeColor.divider,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: const [
                                                        Icon(
                                                          LucideIcons.mapPin,
                                                          size: 12,
                                                          color: ThemeColor
                                                              .textSecondary,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Google',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: ThemeColor
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (location.description != null &&
                                                location
                                                    .description!
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                location.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      ThemeColor.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        LucideIcons.gripVertical,
                                        size: 20,
                                        color: ThemeColor.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),

                                // Distance connector (timeline)
                                if (!isLast && distanceText != null)
                                  Container(
                                    margin: const EdgeInsets.only(left: 20),
                                    child: Row(
                                      children: [
                                        // Vertical line with icon
                                        SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Vertical line
                                              Positioned(
                                                left: 19.5,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 2,
                                                  color: ThemeColor.divider,
                                                ),
                                              ),
                                              // Arrow icon
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: ThemeColor.background,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: ThemeColor.divider,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  (segmentRouteType ??
                                                              routeType) ==
                                                          RouteType.walking
                                                      ? LucideIcons.footprints
                                                      : (segmentRouteType ??
                                                                routeType) ==
                                                            RouteType.cycling
                                                      ? LucideIcons.bike
                                                      : LucideIcons.car,
                                                  size: 12,
                                                  color: ThemeColor.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Distance and duration info
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ThemeColor.surface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  LucideIcons.moveHorizontal,
                                                  size: 14,
                                                  color: ThemeColor.textPrimary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  distanceText,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        ThemeColor.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  LucideIcons.clock,
                                                  size: 14,
                                                  color:
                                                      ThemeColor.textSecondary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  durationText ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: ThemeColor
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Spacing
                                if (!isLast)
                                  const SizedBox(height: 0)
                                else
                                  const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action buttons
                      if (reorderableLocations.length >= 2)
                        Column(
                          children: [
                            // Show/Update Route button (primary action)
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                onRouteUpdated?.call(
                                  reorderableLocations,
                                  routeType,
                                );
                                await showRouteOnMap(
                                  reorderableLocations,
                                  routeType ?? RouteType.walking,
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColor.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      routeType != null
                                          ? LucideIcons.refreshCw
                                          : LucideIcons.route,
                                      size: 20,
                                      color: ThemeColor.textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      routeType != null
                                          ? 'Update Route'
                                          : 'Show Route',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeColor.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Navigate and Save buttons
                            Row(
                              children: [
                                // Navigate button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _launchExternalNavigation(
                                        reorderableLocations,
                                        routeType ?? RouteType.walking,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            LucideIcons.navigation,
                                            size: 20,
                                            color: ThemeColor.textPrimary,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Navigate',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: ThemeColor.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Save Route button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _saveRouteDialog(
                                        reorderableLocations,
                                        routeType,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            LucideIcons.save,
                                            size: 20,
                                            color: ThemeColor.textPrimary,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Save',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: ThemeColor.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _saveRouteDialog(List<LocationData> locations, RouteType? routeType) {
    final TextEditingController nameController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Save Route'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                routeType != null
                    ? 'Save this ${routeType.name} route with ${locations.length} stops:'
                    : 'Give your route a name:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'e.g., Amsterdam Tour',
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                nameController.dispose();
                Navigator.pop(context);
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final routeName = nameController.text.trim();
                if (routeName.isEmpty) {
                  // Show error
                  return;
                }

                Navigator.pop(context);

                // Check if route with this name already exists
                final existingRoute = await _checkExistingRoute(routeName);

                if (!mounted) return;

                if (existingRoute != null) {
                  // Route exists, ask user what to do
                  _showOverwriteDialog(
                    routeName,
                    existingRoute,
                    locations,
                    routeType,
                    nameController,
                  );
                } else {
                  // Route doesn't exist, save it
                  await _saveRoute(routeName, locations, routeType, null);
                  nameController.dispose();

                  if (!mounted) return;
                  // Show success message
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Success'),
                      content: Text('Route "$routeName" saved!'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Check if a route with the given name already exists
  Future<QueryDocumentSnapshot?> _checkExistingRoute(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('savedRoutes')
          .where('userId', isEqualTo: user.uid)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      // // debugPrint('❌ Error checking existing route: $e');
      return null;
    }
  }

  /// Show dialog to ask user if they want to overwrite or create new
  void _showOverwriteDialog(
    String routeName,
    QueryDocumentSnapshot existingRoute,
    List<LocationData> locations,
    RouteType? routeType,
    TextEditingController nameController,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Route Already Exists'),
        content: Text(
          'A route named "$routeName" already exists. Do you want to overwrite it or create a new one?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              nameController.dispose();
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Create New'),
            onPressed: () {
              Navigator.pop(context);
              // Show dialog again to enter a different name
              _saveRouteDialog(locations, routeType);
              nameController.dispose();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Overwrite'),
            onPressed: () async {
              Navigator.pop(context);
              await _saveRoute(
                routeName,
                locations,
                routeType,
                existingRoute.id,
              );
              nameController.dispose();

              if (!mounted) return;
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Success'),
                  content: Text('Route "$routeName" updated!'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoute(
    String name,
    List<LocationData> locations,
    RouteType? routeType,
    String?
    existingDocId, // If provided, update this document instead of creating new
  ) async {
    // // debugPrint('💾 Saving route: $name with ${locations.length} locations');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // // debugPrint('❌ User not logged in, cannot save route');
        return;
      }

      final routeData = {
        'userId': user.uid,
        'name': name,
        'locationCount': locations.length,
        'locations': locations.map((loc) => loc.toJson()).toList(),
        'routeType': routeType?.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final now = DateTime.now();

      if (existingDocId != null) {
        // Update existing route
        await FirebaseFirestore.instance
            .collection('savedRoutes')
            .doc(existingDocId)
            .update(routeData);
        // // debugPrint('✅ Route updated: $name');

        // Update offline storage
        await OfflineStorageService.saveRoute(
          id: existingDocId,
          name: name,
          locations: locations.map((loc) => loc.toJson()).toList(),
          routeType: routeType?.name,
          createdAt: now, // Will use existing createdAt if available
          updatedAt: now,
        );
      } else {
        // Create new route
        routeData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('savedRoutes')
            .add(routeData);

        // // debugPrint('✅ Route saved to Firestore successfully');

        // Also save to offline storage for offline access
        await OfflineStorageService.saveRoute(
          id: docRef.id,
          name: name,
          locations: locations.map((loc) => loc.toJson()).toList(),
          routeType: routeType?.name,
          createdAt: now,
          updatedAt: now,
        );

        // // debugPrint('✅ Route also saved to offline storage');
      }
    } catch (e) {
      // // debugPrint('❌ Error saving route: $e');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to save route: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _showSavedRoutesSheet() {
    final user = FirebaseAuth.instance.currentUser;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.62;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              color: ThemeColor.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _SheetIconButton(
                          icon: LucideIcons.x,
                          onTap: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'map.saved_routes'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 36), // Placeholder for symmetry
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: user == null
                          ? Center(
                              child: Text(
                                'Please log in to view saved routes',
                                style: TextStyle(
                                  color: ThemeColor.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('savedRoutes')
                                  .where('userId', isEqualTo: user.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  debugPrint(
                                    '❌ Error loading routes: ${snapshot.error}',
                                  );
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Error loading routes',
                                          style: TextStyle(
                                            color: ThemeColor.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${snapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: ThemeColor.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final routes = snapshot.data?.docs ?? [];

                                if (routes.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'map.no_saved_routes'.tr(),
                                      style: TextStyle(
                                        color: ThemeColor.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: routes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final routeDoc = routes[index];
                                    final routeData =
                                        routeDoc.data() as Map<String, dynamic>;
                                    final routeName =
                                        routeData['name'] as String;
                                    final locationCount =
                                        routeData['locationCount'] as int;
                                    final routeType =
                                        routeData['routeType'] as String?;

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _loadSavedRoute(routeDoc.id, routeData);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ThemeColor.surface,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    routeName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: ThemeColor
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        routeType == 'walking'
                                                            ? LucideIcons
                                                                  .footprints
                                                            : routeType ==
                                                                  'cycling'
                                                            ? LucideIcons.bike
                                                            : LucideIcons.car,
                                                        size: 12,
                                                        color: ThemeColor
                                                            .textSecondary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$locationCount stops',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: ThemeColor
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _SheetIconButton(
                                              icon: LucideIcons.trash2,
                                              onTap: () async {
                                                await _deleteSavedRoute(
                                                  routeDoc.id,
                                                  routeName,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              LucideIcons.chevronRight,
                                              size: 18,
                                              color: ThemeColor.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadSavedRoute(
    String routeId,
    Map<String, dynamic> routeData,
  ) async {
    // // debugPrint('📍 Loading saved route: ${routeData['name']}');

    try {
      final locationsData = routeData['locations'] as List<dynamic>;
      final locations = locationsData
          .map((loc) => LocationData.fromJson(loc as Map<String, dynamic>))
          .toList();

      final routeTypeName = routeData['routeType'] as String?;
      RouteType? routeType;
      if (routeTypeName != null) {
        routeType = RouteType.values.firstWhere(
          (e) => e.name == routeTypeName,
          orElse: () => RouteType.driving,
        );
      }

      if (routeType != null) {
        await showRouteOnMap(locations, routeType);
      } else {
        await showLocationsOnMap(locations);
      }

      // // debugPrint('✅ Route loaded successfully');
    } catch (e) {
      // // debugPrint('❌ Error loading route: $e');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load route: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteSavedRoute(String routeId, String routeName) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete "$routeName"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('savedRoutes')
          .doc(routeId)
          .delete();

      // // debugPrint('✅ Route deleted successfully');
    } catch (e) {
      // // debugPrint('❌ Error deleting route: $e');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to delete route: ${e.toString()}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _SheetIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? ThemeColor.primary : ThemeColor.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? ThemeColor.background : ThemeColor.textPrimary,
        ),
      ),
    );
  }
}

/// Custom implementation of OnCircleAnnotationClickListener
class _CircleAnnotationClickListener extends OnCircleAnnotationClickListener {
  final void Function(CircleAnnotation) onTap;

  _CircleAnnotationClickListener({required this.onTap});

  @override
  void onCircleAnnotationClick(CircleAnnotation annotation) {
    onTap(annotation);
  }
}

class _PlaceAnnotationClickListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onTap;

  _PlaceAnnotationClickListener({required this.onTap});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation);
  }
}
