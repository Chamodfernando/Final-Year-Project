package com.example.ceylon_trails

import io.flutter.embedding.android.FlutterActivity

/// Default entry activity.
///
/// Remote `.glb` files are cached on disk (flutter_cache_manager). We do not
/// delete that cache from native code so models stay on disk across backgrounding
/// and cold starts until the user clears app data or uses in-app cache clear.
class MainActivity : FlutterActivity()
