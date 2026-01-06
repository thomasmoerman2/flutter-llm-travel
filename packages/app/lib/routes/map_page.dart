import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/env_config.dart';
import '../services/theme_color.dart';
// import '../services/mapbox_search_service.dart';
// import '../services/mapbox_directions_service.dart';

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
  bool _hasToken = true;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // Search state
  bool _isSearching = false;
  bool _showResults = false;
  List<String> _allSuggestions = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;

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

    _searchController.addListener(_filterSuggestions);
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

    setState(() {
      _isSearching = true;
      _showResults = false;
      _showSuggestions = false;
    });
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
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    setState(() {
      _showSuggestions = false;
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

  /// Fit camera to show all search results

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
        MapWidget(cameraOptions: _cameraOptions, onMapCreated: _onMapCreated),

        // Local suggestions list
        if (!_showResults &&
            _showSuggestions &&
            _filteredSuggestions.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: widget.bottomInset + 80,
            child: _buildSuggestionsList(),
          ),

        // Search bar
        Positioned(
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
                    placeholder: 'Where do you want to go?',
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
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'Saved routes',
                                  style: TextStyle(
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
                              ? const Center(
                                  child: Text(
                                    'No saved routes yet.',
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
