import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps with turn-by-turn directions to a destination.
///
/// [origin] is optional; when omitted, Google Maps typically uses the device’s
/// current location as the starting point.
class MapsDirectionsService {
  MapsDirectionsService._();

  static Future<bool> openGoogleMapsDirections({
    required double destinationLatitude,
    required double destinationLongitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final dest =
        '${destinationLatitude.toStringAsFixed(7)},${destinationLongitude.toStringAsFixed(7)}';
    final query = <String, String>{
      'api': '1',
      'destination': dest,
      'travelmode': 'driving',
    };
    if (originLatitude != null && originLongitude != null) {
      query['origin'] =
          '${originLatitude.toStringAsFixed(7)},${originLongitude.toStringAsFixed(7)}';
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', query);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Same as [openGoogleMapsDirections] but [destinationQuery] is a place name or address
  /// (Google resolves it). Use when lat/lng are not stored in Firestore.
  static Future<bool> openGoogleMapsDirectionsToPlaceQuery({
    required String destinationQuery,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final trimmed = destinationQuery.trim();
    if (trimmed.isEmpty) return false;
    final query = <String, String>{
      'api': '1',
      'destination': trimmed,
      'travelmode': 'driving',
    };
    if (originLatitude != null && originLongitude != null) {
      query['origin'] =
          '${originLatitude.toStringAsFixed(7)},${originLongitude.toStringAsFixed(7)}';
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', query);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
