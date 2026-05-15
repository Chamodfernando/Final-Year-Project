import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'location_detail_screen.dart';
import 'models/location.dart' as model;
import 'models/location_city_option.dart';
import 'profile_screen.dart';
import 'services/firestore_service.dart';
import 'services/google_geocoding_service.dart';

/// Map / Places / Saved heritage UI (shell `#EBEBEB`, cream `#F9F6F0`, forest `#0C3B2E`).
/// Used inside [MainShellScreen] or pushed standalone. Optional [initialSection] / [initialCityFilter].
class _HeritageColors {
  static const Color shell = Color(0xFFEBEBEB);
  static const Color cream = Color(0xFFF9F6F0);
  static const Color forest = Color(0xFF0C3B2E);
  /// Slightly lighter green chip behind active bottom-nav icon.
  static const Color navActiveChip = Color(0xFF165040);
  static const Color segmentTrack = Color(0xFFE4E4E4);
  static const Color starGold = Color(0xFFC9A227);
  static const Color bodyGray = Color(0xFF5C5C5C);
  static const Color captionGray = Color(0xFF6B6B6B);
}

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({
    super.key,
    this.initialSection = 1,
    this.initialCityFilter,
    this.focusPlacesCitySearch = false,
    this.showHeritageBottomBar = true,
    this.onRequestProfileTab,
  });

  /// 0 = Map, 1 = Places, 2 = Saved.
  final int initialSection;

  /// When set, Places opens filtered to this Firestore `city` (if [initialSection] is 1).
  final String? initialCityFilter;

  /// When [initialSection] is 1 and [initialCityFilter] is null, focuses the city search field.
  final bool focusPlacesCitySearch;

  /// When false (e.g. inside [MainShellScreen]), Map/Places/Saved uses only the segmented control.
  final bool showHeritageBottomBar;

  /// When non-null, profile avatar opens PROFILE in the app shell instead of pushing [ProfileScreen].
  final VoidCallback? onRequestProfileTab;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 0 = Map, 1 = Places, 2 = Saved (synced: segmented control + bottom bar).
  late int _section;

  /// When non-null, Places tab lists only locations with this `city` (Firestore).
  String? _placesCityFilter;

  static const LatLng _initialCenter = LatLng(7.5, 80.6);

  static const List<String> _demoDistances = [
    '12.4 km away',
    '4.2 km away',
    '18.1 km away',
    '32.5 km away',
  ];

  void _setSection(int i) {
    if (i == _section) return;
    setState(() => _section = i.clamp(0, 2));
  }

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 2);
    _placesCityFilter = widget.initialCityFilter;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _HeritageColors.shell,
      drawer: const _HeritageDrawer(),
      bottomNavigationBar: widget.showHeritageBottomBar
          ? _HeritageBottomBar(
              index: _section,
              onChanged: _setSection,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeritageTopBar(
              showBack: canPop,
              onBack: canPop ? () => Navigator.of(context).pop() : null,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onProfile: () {
                if (widget.onRequestProfileTab != null) {
                  widget.onRequestProfileTab!();
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                }
              },
            ),
            const _HeritageHeroBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: _HeritageSegmentedControl(
                index: _section,
                onChanged: _setSection,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: ColoredBox(
                  color: _HeritageColors.cream,
                  child: IndexedStack(
                    index: _section,
                    children: [
                      _HeritageMapTab(initialCenter: _initialCenter),
                      _HeritagePlacesPanel(
                        selectedCity: _placesCityFilter,
                        onSelectedCityChanged: (c) =>
                            setState(() => _placesCityFilter = c),
                        demoDistances: _demoDistances,
                        autofocusCitySearch:
                            widget.focusPlacesCitySearch && _section == 1,
                      ),
                      const _HeritageSavedPanel(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  Top bar                                   */
/* -------------------------------------------------------------------------- */

class _HeritageTopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback onMenu;
  final VoidCallback onProfile;

  const _HeritageTopBar({
    required this.showBack,
    required this.onBack,
    required this.onMenu,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          if (showBack && onBack != null)
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _HeritageColors.forest,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            ),
          IconButton(
            onPressed: onMenu,
            icon: Icon(Icons.menu_rounded, color: _HeritageColors.forest, size: 26),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Text(
              'Heritage Sri Lanka',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _HeritageColors.forest,
                height: 1.15,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfile,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: _HeritageColors.forest,
                backgroundImage: const AssetImage('assets/images/ceylon_trails_logo.png'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               Hero banner                                  */
/* -------------------------------------------------------------------------- */

class _HeritageHeroBanner extends StatelessWidget {
  const _HeritageHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/nine_arch.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _HeritageColors.forest,
                  alignment: Alignment.center,
                  child: Icon(Icons.landscape_rounded, color: Colors.white.withValues(alpha: 0.5), size: 64),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cultural Triangle',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Curated Heritage Destinations',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.3,
                      ),
                    ),
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

/* -------------------------------------------------------------------------- */
/*                            Segmented control                               */
/* -------------------------------------------------------------------------- */

class _HeritageSegmentedControl extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _HeritageSegmentedControl({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Map', 'Places', 'Saved'];
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _HeritageColors.segmentTrack,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected ? _HeritageColors.forest : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _HeritageColors.forest,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                         Places: city gate + list                           */
/* -------------------------------------------------------------------------- */

class _PlacesCityListPicker extends StatefulWidget {
  final ValueChanged<String> onCitySelected;
  final bool autofocusSearch;

  const _PlacesCityListPicker({
    required this.onCitySelected,
    this.autofocusSearch = false,
  });

  @override
  State<_PlacesCityListPicker> createState() => _PlacesCityListPickerState();
}

class _PlacesCityListPickerState extends State<_PlacesCityListPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LocationCityOption> _applySearch(List<LocationCityOption> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((o) => o.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            'Choose a city',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _HeritageColors.forest,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Below are cities that have at least one saved location. Tap a city to see its sites, '
            'or use search to narrow the list.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _HeritageColors.captionGray,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            autofocus: widget.autofocusSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search cities…',
              hintStyle: GoogleFonts.inter(color: _HeritageColors.captionGray),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _HeritageColors.captionGray,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _HeritageColors.forest, width: 1.5),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<LocationCityOption>>(
            stream: FirestoreService().streamLocationCityOptions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _HeritageColors.forest),
                );
              }
              if (snapshot.hasError) {
                return _PlacesError(message: snapshot.error.toString());
              }
              final all = snapshot.data ?? [];
              if (all.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No cities yet.\nAdd locations in the admin panel and set each site’s city.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _HeritageColors.bodyGray,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              }
              final filtered = _applySearch(all);
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No cities match your search.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _HeritageColors.captionGray,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                  indent: 12,
                  endIndent: 12,
                ),
                itemBuilder: (context, index) {
                  final o = filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(
                      o.city,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _HeritageColors.forest,
                      ),
                    ),
                    subtitle: Text(
                      '${o.locationCount} heritage site${o.locationCount == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _HeritageColors.captionGray,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: _HeritageColors.forest.withValues(alpha: 0.6),
                    ),
                    onTap: () => widget.onCitySelected(o.city),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeritagePlacesPanel extends StatelessWidget {
  final String? selectedCity;
  final ValueChanged<String?> onSelectedCityChanged;
  final List<String> demoDistances;
  final bool autofocusCitySearch;

  const _HeritagePlacesPanel({
    required this.selectedCity,
    required this.onSelectedCityChanged,
    required this.demoDistances,
    this.autofocusCitySearch = false,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCity == null || selectedCity!.trim().isEmpty) {
      return _PlacesCityListPicker(
        autofocusSearch: autofocusCitySearch,
        onCitySelected: (city) => onSelectedCityChanged(city),
      );
    }

    final city = selectedCity!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => onSelectedCityChanged(null),
                tooltip: 'Back to cities',
                padding: const EdgeInsets.only(left: 4, right: 4),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _HeritageColors.forest,
                ),
              ),
              Expanded(
                child: Text(
                  'Sites in $city',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _HeritageColors.forest,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onSelectedCityChanged(null),
                child: Text(
                  'Change city',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _HeritageColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<model.Location>>(
            stream: FirestoreService().streamLocationsByCity(city),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _HeritageColors.forest),
                );
              }
              if (snapshot.hasError) {
                return _PlacesError(message: snapshot.error.toString());
              }
              final places = snapshot.data ?? [];
              if (places.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No heritage sites in $city yet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _HeritageColors.bodyGray,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Add a location in the admin panel and set its city to "$city", '
                          'or try another city.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _HeritageColors.captionGray,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                itemCount: places.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                  indent: 20,
                  endIndent: 20,
                ),
                itemBuilder: (context, index) {
                  final place = places[index];
                  final dist = demoDistances[index % demoDistances.length];
                  final rating = place.rating > 0 ? place.rating : 4.8;
                  return _HeritagePlaceRow(
                    place: place,
                    distanceText: dist,
                    rating: rating,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LocationDetailScreen(
                            id: place.id,
                            title: place.title,
                            city: place.city,
                            district: place.district,
                            description: place.description,
                            history: place.description,
                            imagePath: place.imagePath,
                            tags: place.tags,
                            rating: rating,
                            latitude: place.latitude,
                            longitude: place.longitude,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'See all heritage sites',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _HeritageColors.forest,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacesError extends StatelessWidget {
  final String message;

  const _PlacesError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: _HeritageColors.bodyGray),
        ),
      ),
    );
  }
}

class _HeritagePlaceRow extends StatelessWidget {
  final model.Location place;
  final String distanceText;
  final double rating;
  final VoidCallback onTap;

  const _HeritagePlaceRow({
    required this.place,
    required this.distanceText,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: place.imagePath.startsWith('http')
                    ? Image.network(
                        place.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : Image.asset(
                        place.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 48, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _HeritageColors.forest,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _placeSubtitle(place),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _HeritageColors.captionGray,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.near_me_outlined,
                              size: 14,
                              color: _HeritageColors.captionGray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distanceText,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _HeritageColors.captionGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: _HeritageColors.starGold),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _HeritageColors.bodyGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: const Color(0xFFE0DDD8),
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            Map tab + search                                */
/* -------------------------------------------------------------------------- */

class _HeritageMapTab extends StatefulWidget {
  final LatLng initialCenter;

  const _HeritageMapTab({required this.initialCenter});

  @override
  State<_HeritageMapTab> createState() => _HeritageMapTabState();
}

class _HeritageMapTabState extends State<_HeritageMapTab> {
  final FirestoreService _firestore = FirestoreService();
  late final Stream<List<model.Location>> _locationsStream;
  late final TextEditingController _searchCtrl;
  GoogleMapController? _mapController;
  bool _centering = false;
  Marker? _searchMarker;

  @override
  void initState() {
    super.initState();
    _locationsStream = _firestore.streamLocations();
    _searchCtrl = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<model.Location> _matches(List<model.Location> all, String query) {
    final t = query.trim().toLowerCase();
    if (t.isEmpty) return const [];
    return all
        .where(
          (loc) =>
              loc.title.toLowerCase().contains(t) ||
              loc.city.toLowerCase().contains(t) ||
              loc.district.toLowerCase().contains(t),
        )
        .take(24)
        .toList();
  }

  Future<void> _goToLocation(model.Location loc) async {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();

    double? lat = loc.latitude;
    double? lng = loc.longitude;

    if (lat == null || lng == null) {
      final address = [
        if (loc.title.trim().isNotEmpty) loc.title.trim(),
        if (loc.city.trim().isNotEmpty) loc.city.trim(),
        if (loc.district.trim().isNotEmpty) loc.district.trim(),
        'Sri Lanka',
      ].join(', ');
      String? geocodeFail;
      final resolved = await GoogleGeocodingService.geocodeAddress(
        address,
        onFailure: (m) => geocodeFail = m,
      );
      if (resolved == null) {
        if (!mounted) return;
        setState(() => _searchMarker = null);
        _showSnack(
          geocodeFail ??
              'Could not find that place on the map. Add latitude/longitude in Firestore or check the name.',
        );
        return;
      }
      lat = resolved.lat;
      lng = resolved.lng;
    }

    if (!mounted) return;
    final target = LatLng(lat, lng);
    setState(() {
      _searchMarker = Marker(
        markerId: const MarkerId('heritage_search_pick'),
        position: target,
        infoWindow: InfoWindow(
          title: loc.title.isEmpty ? 'Location' : loc.title,
          snippet: loc.city.isNotEmpty ? loc.city : loc.district,
        ),
      );
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 13.5),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_centering) return;
    setState(() => _centering = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _showSnack('Turn on Location services to see your position on the map.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Location permission is off. Enable it in system Settings for Ceylon Trails.');
        return;
      }
      if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) {
        _showSnack('Location permission is needed to show where you are.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15),
        ),
      );
    } catch (_) {
      _showSnack('Could not get your current location. Try again.');
    } finally {
      if (mounted) setState(() => _centering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<model.Location>>(
      stream: _locationsStream,
      builder: (context, snap) {
        final all = snap.data ?? [];
        final matches = _matches(all, _searchCtrl.text);
        final markers = <Marker>{
          if (_searchMarker != null) _searchMarker!,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search locations…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: _HeritageColors.captionGray,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _HeritageColors.forest.withValues(alpha: 0.75),
                    ),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: Icon(
                              Icons.close_rounded,
                              color: _HeritageColors.captionGray,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchMarker = null);
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            if (matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, i) {
                        final loc = matches[i];
                        final subtitle = [
                          if (loc.city.trim().isNotEmpty) loc.city.trim(),
                          if (loc.district.trim().isNotEmpty) loc.district.trim(),
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          title: Text(
                            loc.title.isEmpty ? 'Untitled' : loc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _HeritageColors.forest,
                            ),
                          ),
                          subtitle: subtitle.isEmpty
                              ? null
                              : Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _HeritageColors.captionGray,
                                  ),
                                ),
                          trailing: Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: _HeritageColors.forest.withValues(alpha: 0.6),
                          ),
                          onTap: () => _goToLocation(loc),
                        );
                      },
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: widget.initialCenter,
                          zoom: 7.5,
                        ),
                        markers: markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        onMapCreated: (c) => _mapController = c,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Tooltip(
                          message: 'Go to my location',
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _centering ? null : _goToMyLocation,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _centering
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _HeritageColors.forest,
                                        ),
                                      )
                                    : Icon(
                                        Icons.my_location_rounded,
                                        color: _HeritageColors.forest,
                                        size: 26,
                                      ),
                              ),
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
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                Saved panel                                 */
/* -------------------------------------------------------------------------- */

class _HeritageSavedPanel extends StatelessWidget {
  const _HeritageSavedPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.comingSoon('Saved'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _HeritageColors.captionGray,
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                             Bottom navigation                              */
/* -------------------------------------------------------------------------- */

class _HeritageBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _HeritageBottomBar({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: _HeritageColors.forest,
      elevation: 12,
      child: Padding(
        padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              label: 'MAP',
              icon: Icons.explore_outlined,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
            _NavItem(
              label: 'PLACES',
              icon: Icons.museum_outlined,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
            _NavItem(
              label: 'SAVED',
              icon: Icons.auto_awesome_outlined,
              selected: index == 2,
              onTap: () => onChanged(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = Colors.white.withValues(alpha: 0.55);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _HeritageColors.navActiveChip : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : inactive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: selected ? Colors.white : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  Drawer                                    */
/* -------------------------------------------------------------------------- */

class _HeritageDrawer extends StatelessWidget {
  const _HeritageDrawer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: _HeritageColors.cream,
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
                      'Heritage Sri Lanka',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _HeritageColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            ListTile(
              leading: Icon(Icons.bookmark_outline, color: _HeritageColors.forest),
              title: Text(l10n.savedPlaces, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: _HeritageColors.forest),
              title: Text(l10n.savedArtifacts, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: _HeritageColors.forest),
              title: Text(l10n.settings, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              title: Text(
                l10n.logOut,
                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

String _districtLine(String district) {
  final t = district.trim();
  if (t.isEmpty) return '';
  if (t.toLowerCase().contains('district')) return t;
  return '$t District';
}

String _placeSubtitle(model.Location place) {
  final d = _districtLine(place.district);
  final c = place.city.trim();
  if (c.isEmpty) return d;
  if (d.isEmpty) return c;
  return '$c · $d';
}