import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_colors.dart';
import 'location_detail_screen.dart';
import 'models/location.dart' as model;
import 'services/firestore_service.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Key so we can open the drawer from our custom header row
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Center roughly in central Sri Lanka so all markers are visible
  static const LatLng _initialCenter = LatLng(7.5, 80.6);

  // Locations
  static const LatLng _sigiriyaLatLng = LatLng(7.9570, 80.7603);
  static const LatLng _nineArchLatLng = LatLng(6.8740, 81.0470);
  static const LatLng _toothTempleLatLng = LatLng(7.2936, 80.6413);

  // Use final (NOT const) so we can create normal Marker objects
  static final Set<Marker> _sriLankaMarkers = {
    Marker(
      markerId: const MarkerId('sigiriya'),
      position: _sigiriyaLatLng,
      infoWindow: const InfoWindow(
        title: 'Sigiriya Rock Fortress',
        snippet: 'Dambulla, Central Province',
      ),
    ),
    Marker(
      markerId: const MarkerId('nine_arch'),
      position: _nineArchLatLng,
      infoWindow: const InfoWindow(
        title: 'Nine Arch Bridge',
        snippet: 'Ella, Uva Province',
      ),
    ),
    Marker(
      markerId: const MarkerId('tooth_temple'),
      position: _toothTempleLatLng,
      infoWindow: const InfoWindow(
        title: 'Temple of the Tooth Relic',
        snippet: 'Kandy, Central Province',
      ),
    ),
  };

  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.dashboardBackground,

        // Side menu
        drawer: const _DashboardDrawer(),

        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: menu + profile
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Menu (drawer)
                    _CircleIconButton(
                      icon: Icons.menu_rounded,
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),

                    // Profile
                    _CircleIconButton(
                      icon: Icons.person,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Logo + search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HeaderCard(),
              ),

              const SizedBox(height: 12),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.tabInactive,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Places'),
                    Tab(text: 'Map'),
                    Tab(text: 'Saved'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Tab views
              Expanded(
                child: TabBarView(
                  children: [
                    const _PlacesTab(),
                    _MapTab(
                      center: _initialCenter,
                      markers: _sriLankaMarkers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                    const _PlaceholderTab(label: 'Saved'),
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
/*                             CIRCLE ICON BUTTON                             */
/* -------------------------------------------------------------------------- */

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          width: 40,
          child: Center(
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               HEADER CARD                                  */
/* -------------------------------------------------------------------------- */

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Logo
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/ceylon_trails_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'CEYLON TRAILS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar (enabled TextField)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.black.withOpacity(0.05),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 44,
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.subtleText.withOpacity(0.9),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Search places, trails, or artifacts',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.subtleText.withOpacity(0.9),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 PLACES TAB                                 */
/* -------------------------------------------------------------------------- */

class _PlacesTab extends StatelessWidget {
  const _PlacesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<model.Location>>(
      stream: FirestoreService().streamLocations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final places = snapshot.data ?? [];

        if (places.isEmpty) {
          return const Center(child: Text('No locations found. Add some in the Admin Panel!'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: places.length,
          itemBuilder: (context, index) {
            final place = places[index];
            return _PlaceCard(place: place);
          },
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  MAP TAB                                   */
/* -------------------------------------------------------------------------- */

class _MapTab extends StatelessWidget {
  final LatLng center;
  final Set<Marker> markers;
  final void Function(GoogleMapController) onMapCreated;

  const _MapTab({
    required this.center,
    required this.markers,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: _MapCard(
        center: center,
        markers: markers,
        onMapCreated: onMapCreated,
      ),
    );
  }
}

/* ------------------------------- Map card --------------------------------- */

class _MapCard extends StatelessWidget {
  final LatLng center;
  final Set<Marker> markers;
  final void Function(GoogleMapController) onMapCreated;

  const _MapCard({
    required this.center,
    required this.markers,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: 7.5, // zoomed out so multiple markers are visible
            ),
            markers: markers,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onMapCreated: onMapCreated,
          ),
        ),
      ),
    );
  }
}

/* ------------------------------- Place model ------------------------------ */

class _PlaceCard extends StatelessWidget {
  final model.Location place;

  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to Location Detail screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationDetailScreen(
              id: place.id,
              title: place.title,
              district: place.district,
              description: place.description,
              history: place.description, // Use description for now as history
              imagePath: place.imagePath,
              tags: place.tags,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: place.imagePath.startsWith('http')
                    ? Image.network(
                        place.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.image_not_supported)),
                      )
                    : Image.asset(
                        place.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.image_not_supported)),
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.district,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.subtleText.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: place.tags
                        .map((tag) => _PlaceTagWidget(label: tag))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTagWidget extends StatelessWidget {
  final String label;

  const _PlaceTagWidget({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.chipBgGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/* -------------------------- Placeholder tabs ------------------------------ */

class _PlaceholderTab extends StatelessWidget {
  final String label;

  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label coming soon',
        style: TextStyle(
          color: AppColors.subtleText.withOpacity(0.8),
          fontSize: 14,
        ),
      ),
    );
  }
}

/* ---------------------------- Drawer content ------------------------------ */

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/ceylon_trails_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'CEYLON TRAILS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Menu items (placeholders for now)
            ListTile(
              leading: const Icon(Icons.bookmark_outline,
                  color: AppColors.primaryGreen),
              title: const Text('Saved Places'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: navigate to Saved Places
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.primaryGreen),
              title: const Text('Saved Artifacts'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.primaryGreen),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading:
              const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              title: const Text(
                'Log Out',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: handle logout if needed
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Helper: history per place ----------------------- */

String _historyTextFor(String title) {
  if (title == 'Sigiriya Rock Fortress') {
    return
      'Sigiriya, also known as the Lion Rock, is an ancient rock fortress '
          'located in the northern Matale District. It was selected by King '
          'Kasyapa (477–495 CE) as his new capital and he built his palace on '
          'top of this massive rock, decorating its sides with colourful frescoes. '
          'The remains of the extensive gardens, reservoirs and other structures '
          'at the base of the rock are among the oldest landscaped gardens in the world.';
  } else if (title == 'Nine Arch Bridge') {
    return
      'The Nine Arch Bridge near Ella is a colonial-era viaduct built entirely '
          'of stone and brick. Completed in 1921, it spans a lush valley of tea '
          'plantations and has become one of Sri Lanka’s most photographed railway '
          'landmarks, especially when trains curve across its dramatic arches.';
  } else if (title == 'Temple of the Tooth Relic') {
    return
      'The Temple of the Tooth Relic (Sri Dalada Maligawa) in Kandy houses what '
          'is believed to be the sacred tooth relic of the Buddha. The temple '
          'complex is part of a royal palace and is one of the most important '
          'Buddhist pilgrimage sites in the world, with daily rituals and annual '
          'processions such as the Kandy Esala Perahera.';
  }
  return '';
}
