import 'dart:math' as math;

import '../constants/city_geofences.dart';

/// Haversine distance + geofence lookup for “near me” city detection.
class NearMeCityService {
  NearMeCityService._();

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Great-circle distance between two WGS84 points, in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  /// Among geofences that contain the point, returns the city whose center is closest.
  static String? cityContainingUser(
    double latitude,
    double longitude, [
    List<CityGeofence> fences = kCityGeofences,
  ]) {
    String? bestCity;
    var bestDist = double.infinity;
    for (final f in fences) {
      final d = distanceKm(latitude, longitude, f.latitude, f.longitude);
      if (d <= f.radiusKm && d < bestDist) {
        bestDist = d;
        bestCity = f.city;
      }
    }
    return bestCity;
  }
}
