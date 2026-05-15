import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'location_detail_screen.dart';
import 'locations.dart';
import 'models/location.dart' as model;
import 'services/firestore_service.dart';
import 'services/near_me_city_service.dart';
import 'shell_nav.dart';

/// Shell background, cards, and brand greens aligned with [LocationsScreen].
class _DashColors {
  static const Color shell = Color(0xFFEBEBEB);
  static const Color cream = Color(0xFFF9F6F0);
  static const Color forest = Color(0xFF0C3B2E);
  static const Color bodyGray = Color(0xFF5C5C5C);
  static const Color captionGray = Color(0xFF6B6B6B);
  static const Color starGold = Color(0xFFC9A227);
  /// Hairline borders / soft shadows.
  static Color line(bool dark) => Colors.black.withValues(alpha: dark ? 0.08 : 0.05);
}

void _dashHapticTap() {
  HapticFeedback.selectionClick();
}

Widget _ratingStarRow(double rating) {
  final full = rating.clamp(0.0, 5.0).round().clamp(0, 5);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Padding(
        padding: const EdgeInsets.only(right: 1),
        child: Icon(
          Icons.star_rounded,
          size: 15,
          color: i < full
              ? _DashColors.starGold
              : Colors.white.withValues(alpha: 0.35),
        ),
      ),
    ),
  );
}

/// Post-login home: featured carousel, near-me and highlights (no map — use Locations → Map).
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirestoreService _firestore = FirestoreService();

  StreamSubscription<Position>? _nearMeSub;
  Timer? _nearMeDebounce;
  StreamSubscription<List<model.Location>>? _nearCityPlacesSub;

  String? _detectedCity;
  int _nearSiteCount = 0;
  List<model.Location> _nearPlaces = [];

  static const Duration _nearMeDebounceDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNearMeIfPossible());
  }

  @override
  void dispose() {
    _nearMeDebounce?.cancel();
    _nearMeSub?.cancel();
    _nearCityPlacesSub?.cancel();
    super.dispose();
  }

  Future<void> _startNearMeIfPossible() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled || !mounted) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (!mounted) return;

      try {
        final first = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        if (mounted) _scheduleNearMeEvaluation(first);
      } catch (e) {
        if (kDebugMode) debugPrint('Dashboard near me: initial position failed: $e');
      }

      _nearMeSub?.cancel();
      _nearMeSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 200,
        ),
      ).listen(
        _scheduleNearMeEvaluation,
        onError: (Object e) {
          if (kDebugMode) debugPrint('Dashboard near me stream error: $e');
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Dashboard near me: $e');
    }
  }

  void _scheduleNearMeEvaluation(Position position) {
    _nearMeDebounce?.cancel();
    _nearMeDebounce = Timer(_nearMeDebounceDuration, () {
      if (!mounted) return;
      final detected = NearMeCityService.cityContainingUser(
        position.latitude,
        position.longitude,
      );
      if (detected == _detectedCity) return;
      setState(() => _detectedCity = detected);
      _subscribePlacesForCity(detected);
    });
  }

  Future<void> _refreshNearMeFromGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on location services to refresh Near you.')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed for Near you.')),
          );
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) _scheduleNearMeEvaluation(p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh location: $e')),
        );
      }
    }
  }

  void _subscribePlacesForCity(String? city) {
    _nearCityPlacesSub?.cancel();
    _nearCityPlacesSub = null;
    if (city == null || city.isEmpty) {
      setState(() {
        _nearSiteCount = 0;
        _nearPlaces = [];
      });
      return;
    }
    _nearCityPlacesSub = _firestore.streamLocationsByCity(city).listen((list) {
      if (!mounted) return;
      setState(() {
        _nearPlaces = list;
        _nearSiteCount = list.length;
      });
    });
  }

  String _nearMeSummaryLine() {
    if (_detectedCity != null && _nearSiteCount > 0) {
      return '$_nearSiteCount heritage sites in your area ($_detectedCity).';
    }
    if (_detectedCity != null) {
      return 'You appear to be in the $_detectedCity area. Open the list to browse tagged sites.';
    }
    return 'Turn on location or wait for GPS to see sites matched to your city area.';
  }

  String _nearMeCtaLabel() {
    if (_detectedCity != null && _nearSiteCount > 0) {
      return '$_nearSiteCount sites near you';
    }
    if (_detectedCity != null) {
      return 'Sites in $_detectedCity';
    }
    return 'Sites near you';
  }

  void _openPlacesTab({bool focusCitySearch = false}) {
    final shell = MainShellScope.maybeOf(context);
    if (shell != null) {
      shell.goMap(
        section: 1,
        focusPlacesSearch: focusCitySearch,
        remountLocations: true,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationsScreen(
          initialSection: 1,
          focusPlacesCitySearch: focusCitySearch,
        ),
      ),
    );
  }

  Future<void> _onPullRefresh() async {
    HapticFeedback.mediumImpact();
    await _refreshNearMeFromGps();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _openNearMeSheet() async {
    if (_detectedCity == null) {
      await _startNearMeIfPossible();
      if (!mounted) return;
      if (_detectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not place you in a known city area yet. '
              'Try again after GPS locks, or browse from Map / Places.',
            ),
          ),
        );
        return;
      }
    }

    final city = _detectedCity!;
    final places = List<model.Location>.from(_nearPlaces);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.28,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: _DashColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Near you — $city',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _DashColors.forest,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    places.isEmpty
                        ? 'No heritage sites are tagged for this city in the database yet. '
                            'Try Map / Places to explore.'
                        : 'You are in the $city area. Explore these locations:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: _DashColors.captionGray,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: places.isEmpty
                      ? Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              final shell = MainShellScope.maybeOf(context);
                              if (shell != null) {
                                shell.goMap(
                                  section: 1,
                                  cityFilter: city,
                                  remountLocations: true,
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LocationsScreen(
                                      initialSection: 1,
                                      initialCityFilter: city,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Open in Places',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: _DashColors.forest,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: places.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                          itemBuilder: (_, i) {
                            final p = places[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Text(
                                p.title.isEmpty ? 'Untitled' : p.title,
                                style: GoogleFonts.playfairDisplay(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _DashColors.forest,
                                ),
                              ),
                              subtitle: Text(
                                '${p.city} · ${p.district}'.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _DashColors.captionGray,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: _DashColors.forest.withValues(alpha: 0.5),
                              ),
                              onTap: () {
                                _dashHapticTap();
                                Navigator.pop(ctx);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LocationDetailScreen(
                                      id: p.id,
                                      title: p.title,
                                      city: p.city,
                                      district: p.district,
                                      description: p.description,
                                      history: p.description,
                                      imagePath: p.imagePath,
                                      tags: p.tags,
                                      rating: p.rating,
                                      latitude: p.latitude,
                                      longitude: p.longitude,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _DashColors.shell,
      drawer: _DashboardDrawer(l10n: l10n),
      body: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: _DashColors.cream,
          child: StreamBuilder<List<model.Location>>(
            stream: _firestore.streamLocations(),
            builder: (context, snapshot) {
              final locations = snapshot.data;
              final hasData = locations != null && locations.isNotEmpty;
              final carouselItems =
                  hasData ? locations.take(12).toList() : <model.Location>[];
              final sorted = hasData
                  ? (List<model.Location>.from(locations)
                    ..sort((a, b) => b.rating.compareTo(a.rating)))
                  : <model.Location>[];
              final highlightsTop = sorted.take(6).toList();

              return RefreshIndicator(
                color: _DashColors.forest,
                displacement: 48,
                onRefresh: _onPullRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                  SliverToBoxAdapter(
                    child: _HomeHeroBlock(
                      onMenu: () {
                        _dashHapticTap();
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      onSearch: () {
                        _dashHapticTap();
                        _openPlacesTab(focusCitySearch: true);
                      },
                      carousel: hasData
                          ? _AutoAdvanceCarousel(
                              key: ValueKey(carouselItems.map((e) => e.id).join('|')),
                              items: carouselItems,
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                height: 196,
                                child: _CarouselPlaceholder(),
                              ),
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Divider(height: 1, thickness: 1, color: _DashColors.line(false)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            title: 'Near you',
                            subtitle: 'Based on your approximate city area',
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _DashColors.line(false)),
                            ),
                            child: InkWell(
                              onTap: () {
                                _dashHapticTap();
                                _openNearMeSheet();
                              },
                              borderRadius: BorderRadius.circular(20),
                              splashColor: _DashColors.forest.withValues(alpha: 0.08),
                              highlightColor: _DashColors.forest.withValues(alpha: 0.04),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _DashColors.forest.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.near_me_rounded,
                                        color: _DashColors.forest,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _nearMeCtaLabel(),
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: _DashColors.forest,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _nearMeSummaryLine(),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: _DashColors.captionGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _refreshNearMeFromGps();
                                      },
                                      icon: Icon(Icons.refresh_rounded, color: _DashColors.forest),
                                      tooltip: 'Refresh location',
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: _DashColors.forest.withValues(alpha: 0.45),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(
                                child: _SectionHeader(
                                  title: 'Highlights',
                                  subtitle: 'Top-rated from your catalogue',
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _dashHapticTap();
                                  _openPlacesTab();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'See all',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: _DashColors.forest,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                  if (!hasData)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Add locations in Firestore to see highlights.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _DashColors.captionGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final loc = highlightsTop[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HighlightRow(
                                location: loc,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LocationDetailScreen(
                                        id: loc.id,
                                        title: loc.title,
                                        city: loc.city,
                                        district: loc.district,
                                        description: loc.description,
                                        history: loc.description,
                                        imagePath: loc.imagePath,
                                        tags: loc.tags,
                                        rating: loc.rating,
                                        latitude: loc.latitude,
                                        longitude: loc.longitude,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: highlightsTop.length,
                        ),
                    ),
                  ),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _DashColors.forest,
            height: 1.1,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.35,
              color: _DashColors.captionGray,
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeHeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - 36)
      ..quadraticBezierTo(w * 0.58, h + 14, w * 0.28, h - 22)
      ..quadraticBezierTo(w * 0.12, h - 34, 0, h - 30)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HomeHeroBlock extends StatelessWidget {
  const _HomeHeroBlock({
    required this.onMenu,
    required this.onSearch,
    required this.carousel,
  });

  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final Widget carousel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 338,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ClipPath(
            clipper: _HomeHeaderWaveClipper(),
            child: Container(
              width: double.infinity,
              height: 232,
              color: _DashColors.forest,
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onMenu,
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Ceylon Trails',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
                        tooltip: 'Search',
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: Text(
                      'POPULAR HERITAGE SITES',
                      textAlign: TextAlign.left,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.65,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 132,
            height: 200,
            child: carousel,
          ),
        ],
      ),
    );
  }
}

Widget _dashLocationCoverImage(String path) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: _DashColors.forest.withValues(alpha: 0.25),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 40),
        ),
      ),
    );
  }
  return Image.asset(
    path,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => ColoredBox(
      color: _DashColors.forest.withValues(alpha: 0.25),
      child: const Center(
        child: Icon(Icons.landscape_outlined, color: Colors.white54, size: 40),
      ),
    ),
  );
}

/// Advances every 4 seconds: [animateToPage] with increasing index moves the strip
/// left in LTR (each new card enters from the right — right-to-left progression).
class _AutoAdvanceCarousel extends StatefulWidget {
  const _AutoAdvanceCarousel({super.key, required this.items});

  final List<model.Location> items;

  @override
  State<_AutoAdvanceCarousel> createState() => _AutoAdvanceCarouselState();
}

class _AutoAdvanceCarouselState extends State<_AutoAdvanceCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  Timer? _resumeAfterUserScroll;

  static const double _viewportFraction = 0.88;
  static const Duration _advanceInterval = Duration(seconds: 4);
  static const Duration _slideDuration = Duration(milliseconds: 520);
  static const Duration _resumeAutoAfterIdle = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
    _restartTimer();
  }

  void _onUserScroll() {
    _timer?.cancel();
    _resumeAfterUserScroll?.cancel();
    if (widget.items.length <= 1) return;
    _resumeAfterUserScroll = Timer(_resumeAutoAfterIdle, () {
      if (!mounted) return;
      _restartTimer();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(_advanceInterval, (_) => _goNext());
  }

  void _goNext() {
    if (!mounted || !_pageController.hasClients) return;
    final n = widget.items.length;
    if (n <= 1) return;
    final current = _pageController.page?.round() ?? 0;
    final next = (current + 1) % n;
    _pageController.animateToPage(
      next,
      duration: _slideDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeAfterUserScroll?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is UserScrollNotification) {
          _onUserScroll();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(
          parent: PageScrollPhysics(),
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final loc = widget.items[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: _FeaturedCarouselCard(
              location: loc,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocationDetailScreen(
                      id: loc.id,
                      title: loc.title,
                      city: loc.city,
                      district: loc.district,
                      description: loc.description,
                      history: loc.description,
                      imagePath: loc.imagePath,
                      tags: loc.tags,
                      rating: loc.rating,
                      latitude: loc.latitude,
                      longitude: loc.longitude,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedCarouselCard extends StatelessWidget {
  final model.Location location;
  final VoidCallback onTap;

  const _FeaturedCarouselCard({
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _dashHapticTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _dashLocationCoverImage(location.imagePath),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (location.city.trim().isNotEmpty)
                      Text(
                        location.city.trim().toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    if (location.city.trim().isNotEmpty) const SizedBox(height: 4),
                    Text(
                      location.title.isEmpty ? 'Heritage site' : location.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ratingStarRow(location.rating > 0 ? location.rating : 4.8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Center(
          child: Text(
            'Featured sites will appear here once locations load.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _DashColors.captionGray,
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final model.Location location;
  final VoidCallback onTap;

  const _HighlightRow({
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _DashColors.line(false)),
      ),
      child: InkWell(
        onTap: () {
          _dashHapticTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: _DashColors.forest.withValues(alpha: 0.08),
        highlightColor: _DashColors.forest.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: location.imagePath.startsWith('http')
                      ? Image.network(
                          location.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPh(),
                        )
                      : Image.asset(
                          location.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPh(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.title.isEmpty ? 'Untitled' : location.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _DashColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${location.city} · ${location.district}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: _DashColors.captionGray),
                    ),
                  ],
                ),
              ),
              if (location.rating > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                    Text(
                      location.rating.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _DashColors.bodyGray,
                      ),
                    ),
                  ],
                ),
              Icon(Icons.chevron_right_rounded, color: _DashColors.forest.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPh() {
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  final AppLocalizations l10n;

  const _DashboardDrawer({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _DashColors.cream,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/ceylon_trails_logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ceylon Trails',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _DashColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            ListTile(
              leading: Icon(Icons.map_outlined, color: _DashColors.forest),
              title: Text('Map', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
                final shell = MainShellScope.maybeOf(context);
                if (shell != null) {
                  shell.goMap(section: 0, remountLocations: true);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocationsScreen(initialSection: 0)),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.museum_outlined, color: _DashColors.forest),
              title: Text('Places', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
                final shell = MainShellScope.maybeOf(context);
                if (shell != null) {
                  shell.goMap(section: 1, remountLocations: true);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocationsScreen(initialSection: 1)),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_outline, color: _DashColors.forest),
              title: Text(l10n.savedPlaces, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: _DashColors.forest),
              title: Text(l10n.savedArtifacts, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: _DashColors.forest),
              title: Text(l10n.settings, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              title: Text(
                l10n.logOut,
                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                _dashHapticTap();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
