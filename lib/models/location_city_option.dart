/// One row in the "pick a city" list: a city label and how many locations use it.
class LocationCityOption {
  final String city;
  final int locationCount;

  const LocationCityOption({
    required this.city,
    required this.locationCount,
  });
}
