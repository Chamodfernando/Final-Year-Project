import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'ceylon_glb_cache_manager.dart';

class SessionAssetCacheService {
  SessionAssetCacheService._();
  static final SessionAssetCacheService instance = SessionAssetCacheService._();

  final Set<String> _sessionUrls = <String>{};

  bool _isRemote(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  Future<String> resolveModelSource(String pathOrUrl) async {
    if (_isRemote(pathOrUrl)) {
      final file = await CeylonGlbCacheManager().getSingleFile(pathOrUrl);
      return Uri.file(file.path).toString();
    }
    return pathOrUrl;
  }

  /// Source string for [ModelViewer] (`model_viewer_plus`).
  ///
  /// Remote URLs are downloaded via [CeylonGlbCacheManager] (disk + SQLite)
  /// and returned as `file://...` so reopening an artifact does not hit the
  /// network while the cache entry is fresh ([Config.stalePeriod] on the GLB
  /// manager). Bundled `assets/` paths pass through unchanged.
  Future<String> resolveModelSourceForModelViewer(String pathOrUrl) async {
    return resolveModelSource(pathOrUrl.trim());
  }

  Future<ImageProvider> resolveImageProvider(String pathOrUrl) async {
    if (_isRemote(pathOrUrl)) {
      final file = await DefaultCacheManager().getSingleFile(pathOrUrl);
      _sessionUrls.add(pathOrUrl);
      return FileImage(file);
    }
    if (pathOrUrl.startsWith('file://')) {
      return FileImage(File(Uri.parse(pathOrUrl).toFilePath()));
    }
    return AssetImage(pathOrUrl);
  }

  /// Clears downloaded `.glb` cache and remote images tracked this session (logout).
  Future<void> clearSessionCache() async {
    await CeylonGlbCacheManager().emptyCache();
    for (final url in _sessionUrls) {
      await DefaultCacheManager().removeFile(url);
    }
    _sessionUrls.clear();
  }
}
