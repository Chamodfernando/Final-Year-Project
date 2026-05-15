import 'package:flutter/widgets.dart';

/// Drives the post-login [MainShellScreen] tab strip (HOME / MAP / AI / PROFILE).
class MainShellController extends ChangeNotifier {
  int tabIndex = 0;
  int locationsKey = 0;
  int locationsSection = 0;
  String? locationsCityFilter;
  bool locationsFocusSearch = false;

  void goHome() {
    tabIndex = 0;
    notifyListeners();
  }

  /// Switch to Map tab without changing [LocationsScreen] instance (state kept).
  void showMapTab() {
    tabIndex = 1;
    notifyListeners();
  }

  void goMap({
    int section = 0,
    String? cityFilter,
    bool focusPlacesSearch = false,
    bool remountLocations = false,
  }) {
    tabIndex = 1;
    locationsSection = section;
    locationsCityFilter = cityFilter;
    locationsFocusSearch = focusPlacesSearch;
    if (remountLocations) locationsKey++;
    notifyListeners();
  }

  void goAi() {
    tabIndex = 2;
    notifyListeners();
  }

  void goProfile() {
    tabIndex = 3;
    notifyListeners();
  }
}

class MainShellScope extends InheritedNotifier<MainShellController> {
  const MainShellScope({
    super.key,
    required MainShellController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static MainShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>()?.notifier;
  }

  static MainShellController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'MainShellScope not found');
    return c!;
  }
}
