import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Forward geocoding (place name / address → coordinates) via Google Geocoding API.
///
/// Supply the same API key you use for Maps, via compile-time define:
/// `GOOGLE_MAPS_API_KEY` in `secrets.json` when using `--dart-define-from-file`.
///
/// In [Google Cloud Console](https://console.cloud.google.com/apis/library),
/// enable **Geocoding API** for the project and restrict the key (e.g. Android app
/// package + SHA-1, plus Geocoding API) — do not ship an unrestricted key.
class GoogleGeocodingService {
  GoogleGeocodingService._();

  static const String _apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Shortens common Google Cloud errors (e.g. API not enabled) for SnackBars.
  static String _friendlyGeocodeFailure(String? status, String? err) {
    final e = err ?? '';
    if (e.contains('not activated on your API project') ||
        e.contains('API is not activated') ||
        e.contains('has not been used in project')) {
      return 'Geocoding is still blocked. On the Google Cloud project that owns THIS API key: '
          '(1) Enable Geocoding API in Library. '
          '(2) APIs & Services → Credentials → your Maps key → API restrictions → '
          'add Geocoding API to the allowed list (keys with "Restrict key" must list every API). '
          'Then wait 1–2 minutes and fully restart the app.';
    }
    if (e.isNotEmpty) return e;
    return 'Geocoding failed (status: ${status ?? 'unknown'}). Check the API key in Google Cloud.';
  }

  /// [address] should be a full place query (e.g. title, city, country).
  ///
  /// Returns coordinates on success. On failure, [message] is a short user-facing
  /// hint when available (e.g. API denied, quota).
  static Future<({double lat, double lng})?> geocodeAddress(
    String address, {
    void Function(String message)? onFailure,
  }) async {
    final q = address.trim();
    if (q.isEmpty) {
      onFailure?.call('Missing place name to search.');
      return null;
    }
    if (!isConfigured) {
      onFailure?.call(
        'Add GOOGLE_MAPS_API_KEY to secrets.json and run with --dart-define-from-file=secrets.json',
      );
      return null;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{'address': q, 'key': _apiKey},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        onFailure?.call('Geocoding request failed (${response.statusCode}).');
        return null;
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final status = map['status'] as String?;
      final err = map['error_message'] as String?;

      if (status == 'OK') {
        final results = map['results'] as List<dynamic>?;
        if (results == null || results.isEmpty) {
          onFailure?.call('No results for that search.');
          return null;
        }

        final first = results.first as Map<String, dynamic>;
        final geometry = first['geometry'] as Map<String, dynamic>?;
        final loc = geometry?['location'] as Map<String, dynamic>?;
        if (loc == null) {
          onFailure?.call('Invalid response from Geocoding API.');
          return null;
        }

        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) {
          onFailure?.call('Invalid coordinates in Geocoding response.');
          return null;
        }

        return (lat: lat, lng: lng);
      }

      if (status == 'ZERO_RESULTS') {
        onFailure?.call('No map match for that place. Try another spelling or add coordinates in Firestore.');
        return null;
      }

      if (status == 'REQUEST_DENIED') {
        onFailure?.call(_friendlyGeocodeFailure(status, err));
        return null;
      }

      if (status == 'OVER_QUERY_LIMIT') {
        onFailure?.call('Geocoding quota exceeded. Try again later or check billing in Google Cloud.');
        return null;
      }

      if (kDebugMode) {
        debugPrint('GoogleGeocodingService: status=$status error=$err');
      }
      onFailure?.call(_friendlyGeocodeFailure(status, err));
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GoogleGeocodingService: $e\n$st');
      }
      onFailure?.call('Network error while looking up the place.');
      return null;
    }
  }
}
