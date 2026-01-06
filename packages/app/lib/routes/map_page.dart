import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/env_config.dart';
import '../services/theme_color.dart';
import '../services/mapbox_search_service.dart';

/// Content-only widget for the map page (without navigation)
/// Used inside RootLayout
class MapPageContent extends StatefulWidget {
  final double bottomInset;

  const MapPageContent({super.key, this.bottomInset = 16});

  @override
  State<MapPageContent> createState() => MapPageContentState();
}

class MapPageContentState extends State<MapPageContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<_SavedRoute> _savedRoutes = [
    _SavedRoute(title: 'Trip to Portugal', routeCount: 6),
    _SavedRoute(title: 'Roadtrip through the Valley', routeCount: 4),
    _SavedRoute(title: 'Best stops in Rome', routeCount: 8),
    _SavedRoute(title: 'Weekend in Paris', routeCount: 3),
  ];

  late final CameraOptions _cameraOptions;
  late final Widget _mapWidget;
  bool _hasToken = true;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // Search state
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  List<String> _allSuggestions = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;
  bool _hasQuery = false;

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

    // Create point annotation manager for markers
    _pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    // Create polyline annotation manager for routes
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
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

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showResults = false;
      _showSuggestions = false;
    });
    _restoreFocusIfNeeded(true);
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

    return Stack(
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
            bottom: widget.bottomInset + 80,
            child: _buildSuggestionsList(),
          ),

        // Search results list
        if (_showResults && _searchResults.isNotEmpty)
          Positioned(
            key: const ValueKey('map_results'),
            left: 16,
            right: 16,
            bottom: widget.bottomInset + 80,
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
                        bottom: BorderSide(color: Color(0x1A000000), width: 1),
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
                                    color: ThemeColor.primary.withOpacity(0.1),
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
          bottom: widget.bottomInset,
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
                            color: ThemeColor.background,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void showSavedRoutesSheet() {
    _showSavedRoutesSheet();
  }

  void _showSavedRoutesSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
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
                            _SheetIconButton(
                              icon: LucideIcons.plus,
                              filled: true,
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _savedRoutes.isEmpty
                              ? Center(
                                  child: Text(
                                    'map.no_saved_routes'.tr(),
                                    style: TextStyle(
                                      color: ThemeColor.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _savedRoutes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final route = _savedRoutes[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.surface,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  route.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        ThemeColor.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${route.routeCount} routes',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: ThemeColor
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _SheetIconButton(
                                            icon: LucideIcons.trash2,
                                            onTap: () {
                                              setState(() {
                                                _savedRoutes.removeAt(index);
                                              });
                                              modalSetState(() {});
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          _SheetIconButton(
                                            icon: LucideIcons.share2,
                                            onTap: () {},
                                          ),
                                        ],
                                      ),
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
      },
    );
  }
}

class _SavedRoute {
  final String title;
  final int routeCount;

  const _SavedRoute({required this.title, required this.routeCount});
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
