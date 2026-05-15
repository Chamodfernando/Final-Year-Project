/// Approximate city centers + radii (km) for “near me” geofencing.
/// [CityGeofence.city] must match the Firestore `city` string on locations.
///
/// Coordinates are rough municipal centers; tune radii if overlaps feel wrong.
class CityGeofence {
  final String city;
  final double latitude;
  final double longitude;
  final double radiusKm;

  const CityGeofence({
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });
}

/// Aligned with [kSriLankaCities] in `sri_lanka_cities.dart`.
const List<CityGeofence> kCityGeofences = [
  CityGeofence(city: 'Ampara', latitude: 7.3014, longitude: 81.6740, radiusKm: 22),
  CityGeofence(city: 'Anuradhapura', latitude: 8.3114, longitude: 80.4037, radiusKm: 28),
  CityGeofence(city: 'Badulla', latitude: 6.9896, longitude: 81.0557, radiusKm: 20),
  CityGeofence(city: 'Batticaloa', latitude: 7.7102, longitude: 81.6924, radiusKm: 22),
  CityGeofence(city: 'Bentota', latitude: 6.4185, longitude: 80.0000, radiusKm: 16),
  CityGeofence(city: 'Chilaw', latitude: 7.5758, longitude: 79.7953, radiusKm: 18),
  CityGeofence(city: 'Colombo', latitude: 6.9271, longitude: 79.8612, radiusKm: 38),
  CityGeofence(city: 'Dambulla', latitude: 7.8600, longitude: 80.6517, radiusKm: 22),
  CityGeofence(city: 'Ella', latitude: 6.8667, longitude: 81.0463, radiusKm: 14),
  CityGeofence(city: 'Galle', latitude: 6.0354, longitude: 80.2160, radiusKm: 22),
  CityGeofence(city: 'Gampaha', latitude: 7.0877, longitude: 79.9995, radiusKm: 22),
  CityGeofence(city: 'Hambantota', latitude: 6.1244, longitude: 81.1185, radiusKm: 22),
  CityGeofence(city: 'Hatton', latitude: 6.8986, longitude: 80.5969, radiusKm: 18),
  CityGeofence(city: 'Jaffna', latitude: 9.6615, longitude: 80.0255, radiusKm: 26),
  CityGeofence(city: 'Kalutara', latitude: 6.5854, longitude: 79.9607, radiusKm: 20),
  CityGeofence(city: 'Kandy', latitude: 7.2906, longitude: 80.6337, radiusKm: 28),
  CityGeofence(city: 'Kegalle', latitude: 7.2513, longitude: 80.3454, radiusKm: 18),
  CityGeofence(city: 'Kilinochchi', latitude: 9.3961, longitude: 80.3982, radiusKm: 20),
  CityGeofence(city: 'Kurunegala', latitude: 7.4816, longitude: 80.3609, radiusKm: 22),
  CityGeofence(city: 'Mannar', latitude: 8.9810, longitude: 79.9044, radiusKm: 22),
  CityGeofence(city: 'Matale', latitude: 7.4675, longitude: 80.6234, radiusKm: 20),
  CityGeofence(city: 'Matara', latitude: 5.9485, longitude: 80.5353, radiusKm: 20),
  CityGeofence(city: 'Mirissa', latitude: 5.9463, longitude: 80.4514, radiusKm: 12),
  CityGeofence(city: 'Monaragala', latitude: 6.8764, longitude: 81.3453, radiusKm: 22),
  CityGeofence(city: 'Moratuwa', latitude: 6.7731, longitude: 79.8816, radiusKm: 16),
  CityGeofence(city: 'Negombo', latitude: 7.2083, longitude: 79.8358, radiusKm: 18),
  CityGeofence(city: 'Nuwara Eliya', latitude: 6.9497, longitude: 80.7891, radiusKm: 18),
  CityGeofence(city: 'Panadura', latitude: 6.7135, longitude: 79.9043, radiusKm: 16),
  CityGeofence(city: 'Point Pedro', latitude: 9.8167, longitude: 80.2331, radiusKm: 16),
  CityGeofence(city: 'Polonnaruwa', latitude: 7.9396, longitude: 81.0013, radiusKm: 24),
  CityGeofence(city: 'Puttalam', latitude: 8.0362, longitude: 79.8283, radiusKm: 20),
  CityGeofence(city: 'Ratnapura', latitude: 6.6828, longitude: 80.3992, radiusKm: 22),
  CityGeofence(city: 'Sigiriya', latitude: 7.9567, longitude: 80.7603, radiusKm: 14),
  CityGeofence(city: 'Trincomalee', latitude: 8.5874, longitude: 81.2152, radiusKm: 24),
  CityGeofence(city: 'Vavuniya', latitude: 8.7514, longitude: 80.4971, radiusKm: 22),
  CityGeofence(city: 'Wattala', latitude: 6.9909, longitude: 79.8830, radiusKm: 14),
  CityGeofence(city: 'Welimada', latitude: 6.9028, longitude: 80.9121, radiusKm: 16),
];
