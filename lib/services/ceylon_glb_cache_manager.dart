import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dedicated disk cache for remote `.glb` downloads only.
///
/// Uses its own folder under the temp directory and its own SQLite index under
/// app files — separate from [DefaultCacheManager] (`libCachedImageData`).
class CeylonGlbCacheManager extends CacheManager {
  static const key = 'ceylon_glb_models';

  static final CeylonGlbCacheManager _instance = CeylonGlbCacheManager._();
  factory CeylonGlbCacheManager() => _instance;

  CeylonGlbCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 365),
            maxNrOfCacheObjects: 100,
          ),
        );
}
