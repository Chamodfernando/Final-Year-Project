import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'session_asset_cache_service.dart';

/// Picks a lighter model for ARCore when available ([modelPathAr] or `*_ar.glb` / `*_ar.gltf`).
class ArModelPathResolver {
  ArModelPathResolver._();

  static bool _isRemote(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  /// `assets/models/foo.glb` → `assets/models/foo_ar.glb`; already `*_ar.*` → null.
  static String? deriveBundledArPath(String assetPath) {
    final t = assetPath.trim();
    if (!t.startsWith('assets/')) return null;
    final lower = t.toLowerCase();
    if (!lower.endsWith('.glb') && !lower.endsWith('.gltf')) return null;
    if (lower.endsWith('_ar.glb') || lower.endsWith('_ar.gltf')) return null;
    final dot = t.lastIndexOf('.');
    final base = t.substring(0, dot);
    final ext = t.substring(dot);
    return '${base}_ar$ext';
  }

  static Future<bool> _assetExistsInBundle(String assetKey) async {
    try {
      final json = await rootBundle.loadString('AssetManifest.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (map.containsKey(assetKey)) return true;
      return map.keys.any((k) => k == assetKey || k.endsWith('/$assetKey'));
    } catch (_) {
      return false;
    }
  }

  /// Path string suitable for [ARViewScreen] / Sceneform (asset key, `file://`, or `https://`).
  static Future<String> resolveForAr({
    required String primaryPath,
    String? modelPathAr,
  }) async {
    final override = modelPathAr?.trim();
    if (override != null && override.isNotEmpty) {
      return SessionAssetCacheService.instance.resolveModelSource(override);
    }
    final primary = primaryPath.trim();
    if (primary.startsWith('assets/')) {
      final derived = deriveBundledArPath(primary);
      if (derived != null && await _assetExistsInBundle(derived)) {
        return derived;
      }
    }
    return SessionAssetCacheService.instance.resolveModelSource(primary);
  }

  /// Arguments for `prefetchReferenceModel` / [ArCoreReferenceNode] on Android.
  static ({String? object3DFileName, String? objectUrl}) toArCoreChannelFields(
    String resolvedPath,
  ) {
    final t = resolvedPath.trim();
    if (_isRemote(t)) {
      return (object3DFileName: null, objectUrl: t);
    }
    if (t.startsWith('file://')) {
      return (object3DFileName: t, objectUrl: null);
    }
    if (t.startsWith('assets/')) {
      return (
        object3DFileName: 'file:///android_asset/flutter_assets/$t',
        objectUrl: null,
      );
    }
    if (t.startsWith('/')) {
      return (object3DFileName: 'file://$t', objectUrl: null);
    }
    return (object3DFileName: 'file:///$t', objectUrl: null);
  }

  /// Fire-and-forget Sceneform warm-up on Android (no AR view required).
  static Future<void> prefetchForArIfAndroid(String resolvedPath) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final fields = toArCoreChannelFields(resolvedPath);
    await ArCoreNativePrefetch.prefetch(
      object3DFileName: fields.object3DFileName,
      objectUrl: fields.objectUrl,
    );
  }
}

/// Isolated so `arcore_flutter_plus` is not imported from services in web builds.
class ArCoreNativePrefetch {
  ArCoreNativePrefetch._();

  static const String _utilsChannel = 'arcore_flutter_plus/utils';

  static Future<void> prefetch({
    String? object3DFileName,
    String? objectUrl,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (object3DFileName == null && objectUrl == null) return;
    try {
      await MethodChannel(_utilsChannel).invokeMethod<void>(
        'prefetchReferenceModel',
        {
          'object3DFileName': object3DFileName,
          'objectUrl': objectUrl,
        },
      );
    } catch (_) {}
  }
}
