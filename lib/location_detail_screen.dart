import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'artifact_detail_screen.dart';
import 'models/artifact.dart' as model;
import 'models/location.dart';
import 'services/firestore_service.dart';
import 'services/maps_directions_service.dart';

Future<void> _openGoogleDirectionsForLocation(
  BuildContext context, {
  required String locationId,
  required String title,
  required String city,
  required String district,
  required double? latitude,
  required double? longitude,
}) async {
  double? lat = latitude;
  double? lng = longitude;

  final id = locationId.trim();
  // When the list/detail already has coords, skip Firestore — those reads delay opening Maps.
  if (id.isNotEmpty && (lat == null || lng == null)) {
    try {
      final ref = FirebaseFirestore.instance.collection('locations').doc(id);
      // Prefer local cache first (same data the locations stream already merged).
      // Forcing Source.server often fails on flaky networks (timeouts) and can skip
      // fresh listener state — see Firestore "Could not reach ... backend" logs.
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await ref.get(const GetOptions(source: Source.cache));
      } catch (_) {
        snap = await ref.get();
      }
      if (snap.exists) {
        final loc = Location.fromFirestore(snap);
        lat = loc.latitude ?? lat;
        lng = loc.longitude ?? lng;
      }
      if (lat == null || lng == null) {
        final snap2 = await ref.get();
        if (snap2.exists) {
          final loc2 = Location.fromFirestore(snap2);
          lat = loc2.latitude ?? lat;
          lng = loc2.longitude ?? lng;
        }
      }
    } catch (e, st) {
      assert(() {
        debugPrint('Directions: could not load locations/$id: $e\n$st');
        return true;
      }());
    }
  }

  if (lat == null || lng == null) {
    if (kDebugMode) {
      debugPrint(
        'Directions: no lat/lng for id="$id". '
        'If you added coords in Firebase, open the **same** document id the app uses '
        '(watch for capital I vs lowercase l in the id). Trying Maps by place name…',
      );
    }
    final placeParts = <String>[
      if (title.trim().isNotEmpty) title.trim(),
      if (city.trim().isNotEmpty) city.trim(),
      if (district.trim().isNotEmpty) district.trim(),
      'Sri Lanka',
    ];
    final placeQuery = placeParts.join(', ');
    final openedByName = await MapsDirectionsService.openGoogleMapsDirectionsToPlaceQuery(
      destinationQuery: placeQuery,
    );
    if (openedByName) {
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id.isEmpty
              ? 'Add latitude and longitude in Firestore for this place, or check your network.'
              : 'No coordinates for this place in the database. In Firebase Console, '
                    'open locations → document id:\n$id\nand add number fields latitude and longitude. '
                    'Check the letter I vs l in the id if you already added coords elsewhere.',
        ),
      ),
    );
    return;
  }

  // Omit origin: Geolocator.getCurrentPosition often blocks several seconds; Google Maps
  // uses the device’s current location when [origin] is not in the URL.
  final opened = await MapsDirectionsService.openGoogleMapsDirections(
    destinationLatitude: lat,
    destinationLongitude: lng,
  );
  if (context.mounted && !opened) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Maps. Check that the app is installed.'),
      ),
    );
  }
}

class LocationDetailScreen extends StatelessWidget {
  final String id;
  final String title;
  /// Primary city / town (from admin).
  final String city;
  final String district;
  final String description; // short summary if you ever need it
  final String history; // full history text shown under "History"
  final String imagePath;
  final List<String> tags;
  final String distanceText;
  final double rating;

  /// WGS84 from Firestore — required for Google Maps directions.
  final double? latitude;
  final double? longitude;

  const LocationDetailScreen({
    super.key,
    required this.id,
    required this.title,
    this.city = '',
    required this.district,
    required this.description,
    required this.history,
    required this.imagePath,
    required this.tags,
    this.distanceText = '15 km away',
    this.rating = 4.8,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.locationDetailBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: back button + label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location Details',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 12,
                      color: AppColors.subtleText,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        height: 230,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildImage(imagePath),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.65),
                                    Colors.black.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 20,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Body
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.locationDetailBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // City + district
                          Text(
                            city.trim().isEmpty
                                ? district
                                : '${city.trim()} · $district',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Distance + rating row
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distanceText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                  AppColors.subtleText.withOpacity(0.95),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                  AppColors.subtleText.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.directions_rounded, size: 22),
                              label: const Text(
                                'Directions in Google Maps',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              onPressed: () => _openGoogleDirectionsForLocation(
                                context,
                                locationId: id,
                                title: title,
                                city: city,
                                district: district,
                                latitude: latitude,
                                longitude: longitude,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Tags
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: tags
                                .map(
                                  (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBgOrange,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          ),

                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.black.withOpacity(0.04),
                          ),
                          const SizedBox(height: 16),

                          // History section
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Expandable history text
                          _ExpandableText(
                            text: history,
                            trimLines: 8,
                          ),

                          const SizedBox(height: 20),

                          // Artifacts section (single Firestore subscription)
                          StreamBuilder<List<model.Artifact>>(
                            stream: FirestoreService().streamArtifacts(id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Artifacts from this Site',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    SizedBox(
                                      height: 200,
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                  ],
                                );
                              }
                              if (snapshot.hasError) {
                                return Text(
                                  'Error loading artifacts: ${snapshot.error}',
                                  style: TextStyle(color: AppColors.subtleText),
                                );
                              }
                              final artifacts = snapshot.data ?? [];
                              final n = artifacts.length;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      const Text(
                                        'Artifacts from this Site',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (n > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '($n)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.subtleText,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (n > 1) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Swipe sideways to see all artifacts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.subtleText,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 200,
                                    child: artifacts.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No artifacts found for this site.',
                                              style: TextStyle(color: AppColors.subtleText),
                                            ),
                                          )
                                        : ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.only(right: 16),
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: artifacts.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 12),
                                            itemBuilder: (context, index) {
                                              final art = artifacts[index];
                                              return _ArtifactCard(
                                                imagePath: art.imagePath,
                                                title: art.title,
                                                subtitle: art.timePeriod,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => ArtifactDetailScreen(
                                                        title: art.title,
                                                        siteName: art.siteName,
                                                        imagePath: art.imagePath,
                                                        timePeriod: art.timePeriod,
                                                        material: art.material,
                                                        dimensions: art.dimensions,
                                                        history: art.history,
                                                        quickFacts: art.quickFacts,
                                                        modelPath: art.modelPath,
                                                        modelPathAr: art.modelPathAr,
                                                        modelPathArClose: art.modelPathArClose,
                                                        modelPathArFar: art.modelPathArFar,
                                                        modelPathArWall: art.modelPathArWall,
                                                        modelPathArCeiling: art.modelPathArCeiling,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      );
    }
  }

  // Bottom bar (Note: this was moved inside the class in the final version)
  Widget _buildBottomBar(BuildContext context) {
      return SafeArea(
        top: false,
        child: Container(
          color: AppColors.locationDetailBackground,
          padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              _BottomIconButton(
                icon: Icons.favorite_border,
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Start Trail',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _BottomIconButton(
                icon: Icons.map_outlined,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
  }
}

/* ------------------------- Expandable History Text ------------------------ */

class _ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;

  const _ExpandableText({
    required this.text,
    this.trimLines = 8,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.trimLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.subtleText.withOpacity(0.95),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Text(
            _expanded ? 'Read less' : 'Read more',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }
}

/* ------------------------- Artifact card + button ------------------------- */

class _ArtifactCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ArtifactCard({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildArtifactImage(imagePath),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.view_in_ar,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '3D',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.subtleText.withOpacity(0.9),
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

  Widget _buildArtifactImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
        ),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
        ),
      );
    }
  }
}

class _BottomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _BottomIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: Colors.black.withOpacity(0.08),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        child: Icon(
          icon,
          color: AppColors.primaryGreen,
          size: 22,
        ),
      ),
    );
  }
}
