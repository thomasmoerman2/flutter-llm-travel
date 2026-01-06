import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/env_config.dart';
import '../services/theme_color.dart';

/// Content-only widget for the map page (without navigation)
/// Used inside RootLayout
class MapPageContent extends StatefulWidget {
  final double bottomInset;

  const MapPageContent({
    super.key,
    this.bottomInset = 16,
  });

  @override
  State<MapPageContent> createState() => MapPageContentState();
}

class MapPageContentState extends State<MapPageContent> {
  final TextEditingController _searchController = TextEditingController();
  final List<_SavedRoute> _savedRoutes = [
    _SavedRoute(title: 'Trip to Portugal', routeCount: 6),
    _SavedRoute(title: 'Roadtrip through the Valley', routeCount: 4),
    _SavedRoute(title: 'Best stops in Rome', routeCount: 8),
    _SavedRoute(title: 'Weekend in Paris', routeCount: 3),
  ];

  late final CameraOptions _cameraOptions;
  bool _hasToken = true;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        MapWidget(cameraOptions: _cameraOptions),
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
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: ThemeColor.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.search,
                    size: 18,
                    color: ThemeColor.background,
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
