// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:developer' as developer;
import 'dart:io'
    show
        ContentType,
        File,
        HttpClient,
        HttpHeaders,
        HttpResponse,
        HttpServer,
        HttpStatus,
        InternetAddress,
        Platform;

import 'package:android_intent_plus/android_intent.dart' as android_intent;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as android;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart'
    as ios;

import 'html_builder.dart';
import 'model_viewer_plus.dart';

/// Log line for `adb logcat | findstr CeylonModelViewer` (Windows) or
/// `adb logcat | grep CeylonModelViewer` (macOS/Linux).
void _cmv(String message) {
  developer.log(message, name: 'CeylonModelViewer');
  debugPrint('CeylonModelViewer: $message');
}

String _cmvShortUrl(Uri u) =>
    '${u.scheme}://${u.host}${u.path}${u.hasQuery ? '?…' : ''}';

class ModelViewerState extends State<ModelViewer> {
  HttpServer? _proxy;
  WebViewController? _webViewController;
  late String _proxyURL;

  @override
  void initState() {
    super.initState();
    unawaited(_initProxy().then((_) => _initController()));
  }

  @override
  void dispose() {
    if (_proxy != null) {
      unawaited(_proxy!.close(force: true));
      _proxy = null;
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    if (_proxy == null || _webViewController == null) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading Model Viewer',
        ),
      );
    }
    final controller = _webViewController!;
    final gestures = const <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
    };

    // Android default (texture layer) often cannot render WebGL used by
    // <model-viewer>; hybrid composition fixes blank / infinite loading.
    if (Platform.isAndroid) {
      return WebViewWidget.fromPlatformCreationParams(
        params: android.AndroidWebViewWidgetCreationParams
            .fromPlatformWebViewWidgetCreationParams(
          PlatformWebViewWidgetCreationParams(
            controller: controller.platform,
            layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            gestureRecognizers: gestures,
          ),
          displayWithHybridComposition: true,
        ),
      );
    }

    return WebViewWidget(
      controller: controller,
      gestureRecognizers: gestures,
    );
  }

  String _buildHTML(String htmlTemplate) {
    String src;
    if (widget.src.startsWith('data:')) {
      src = widget.src;
    } else {
      src = '/model';
    }
    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate,
      src: src,
      alt: widget.alt,
      poster: widget.poster,
      loading: widget.loading,
      reveal: widget.reveal,
      withCredentials: widget.withCredentials,
      // AR Attributes
      ar: widget.ar,
      arModes: widget.arModes,
      arScale: widget.arScale,
      arPlacement: widget.arPlacement,
      iosSrc: widget.iosSrc,
      xrEnvironment: widget.xrEnvironment,
      // Cameras Attributes
      cameraControls: widget.cameraControls,
      disablePan: widget.disablePan,
      disableTap: widget.disableTap,
      touchAction: widget.touchAction,
      disableZoom: widget.disableZoom,
      orbitSensitivity: widget.orbitSensitivity,
      autoRotate: widget.autoRotate,
      autoRotateDelay: widget.autoRotateDelay,
      rotationPerSecond: widget.rotationPerSecond,
      interactionPrompt: widget.interactionPrompt,
      interactionPromptStyle: widget.interactionPromptStyle,
      interactionPromptThreshold: widget.interactionPromptThreshold,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      maxCameraOrbit: widget.maxCameraOrbit,
      minCameraOrbit: widget.minCameraOrbit,
      maxFieldOfView: widget.maxFieldOfView,
      minFieldOfView: widget.minFieldOfView,
      interpolationDecay: widget.interpolationDecay,
      // Lighting & Env Attributes
      skyboxImage: widget.skyboxImage,
      environmentImage: widget.environmentImage,
      exposure: widget.exposure,
      shadowIntensity: widget.shadowIntensity,
      shadowSoftness: widget.shadowSoftness,
      // Animation Attributes
      animationName: widget.animationName,
      animationCrossfadeDuration: widget.animationCrossfadeDuration,
      autoPlay: widget.autoPlay,
      // Materials & Scene Attributes
      variantName: widget.variantName,
      orientation: widget.orientation,
      scale: widget.scale,
      // CSS Styles
      backgroundColor: widget.backgroundColor,
      // Annotations CSS
      minHotspotOpacity: widget.minHotspotOpacity,
      maxHotspotOpacity: widget.maxHotspotOpacity,
      // Others
      innerModelViewerHtml: widget.innerModelViewerHtml,
      relatedCss: widget.relatedCss,
      relatedJs: widget.relatedJs,
      id: widget.id,
      debugLogging: widget.debugLogging,
    );
  }

  Future<void> _initController() async {
    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isAndroid) {
      params = android.AndroidWebViewControllerCreationParams();
    } else if (Platform.isIOS) {
      params = ios.WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final webViewController =
        WebViewController.fromPlatformCreationParams(params);
    await webViewController.setBackgroundColor(Colors.transparent);
    await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    // Page is http://127.0.0.1 — <model-viewer> pulls https workers/wasm/CDN.
    // Default WebView blocks that mixed content; model stays on “loading”.
    if (Platform.isAndroid) {
      await (webViewController.platform as android.AndroidWebViewController)
          .setMixedContentMode(android.MixedContentMode.alwaysAllow);
    }
    await webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) async {
          debugPrint('ModelViewer wants to load: ${request.url}');
          if (Platform.isIOS && request.url == widget.iosSrc) {
            await launchUrl(
              Uri.parse(request.url.trimLeft()),
              mode: LaunchMode.inAppWebView,
            );
            return NavigationDecision.prevent;
          }
          if (!Platform.isAndroid) {
            return NavigationDecision.navigate;
          }
          if (!request.url.startsWith('intent://')) {
            return NavigationDecision.navigate;
          }
          try {
            // Original, just keep as a backup
            // See: https://developers.google.com/ar/develop/java/scene-viewer
            // final intent = android_content.AndroidIntent(
            //   action: "android.intent.action.VIEW", // Intent.ACTION_VIEW
            //   data: "https://arvr.google.com/scene-viewer/1.0",
            //   arguments: <String, dynamic>{
            //     'file': widget.src,
            //     'mode': 'ar_preferred',
            //   },
            //   package: "com.google.ar.core",
            //   flags: <int>[
            //     Flag.FLAG_ACTIVITY_NEW_TASK
            //   ], // Intent.FLAG_ACTIVITY_NEW_TASK,
            // );

            final String fileURL;
            if (['http', 'https', 'data']
                .contains(Uri.parse(widget.src).scheme)) {
              fileURL = widget.src;
            } else {
              fileURL = p.joinAll([_proxyURL, 'model']);
            }
            final intent = android_intent.AndroidIntent(
              action: 'android.intent.action.VIEW',
              // Intent.ACTION_VIEW
              // See https://developers.google.com/ar/develop/scene-viewer#3d-or-ar
              // data should be something like "https://arvr.google.com/scene-viewer/1.0?file=https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Avocado/glTF/Avocado.gltf"
              data: Uri(
                scheme: 'https',
                host: 'arvr.google.com',
                path: '/scene-viewer/1.0',
                queryParameters: {
                  'mode': 'ar_preferred',
                  'file': fileURL,
                },
              ).toString(),
              // package changed to com.google.android.googlequicksearchbox
              // to support the widest possible range of devices
              package: 'com.google.android.googlequicksearchbox',
              arguments: <String, dynamic>{
                'browser_fallback_url':
                    'market://details?id=com.google.android.googlequicksearchbox',
              },
            );
            await intent.launch().onError((error, stackTrace) {
              debugPrint('ModelViewer Intent Error: $error');
            });
          } on Object catch (error) {
            debugPrint('ModelViewer failed to launch AR: $error');
          }
          return NavigationDecision.prevent;
        },
      ),
    );
    widget.javascriptChannels?.forEach((element) {
      webViewController.addJavaScriptChannel(
        element.name,
        onMessageReceived: element.onMessageReceived,
      );
    });

    await webViewController.setOnConsoleMessage((JavaScriptConsoleMessage m) {
      _cmv('JS console [${m.level.name}] ${m.message}');
    });

    debugPrint('ModelViewer initializing... <$_proxyURL>');
    widget.onWebViewCreated?.call(webViewController);
    // Attach WebView before awaiting navigation — on some Android builds
    // loadRequest never completes and would leave an endless spinner.
    setState(() => _webViewController = webViewController);
    await webViewController.loadRequest(Uri.parse(_proxyURL));
  }

  Future<void> _initProxy() async {
    _proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    setState(() {
      final host = _proxy!.address.address;
      final port = _proxy!.port;
      _proxyURL = 'http://$host:$port/';
    });

    _proxy!.listen((request) async {
      final response = request.response;
      final path = request.uri.path;
      final url = Uri.parse(widget.src);

      try {
        if (path == '/' || path == '/index.html') {
          final htmlTemplate = await rootBundle
              .loadString('packages/model_viewer_plus/assets/template.html');
          final html = utf8.encode(_buildHTML(htmlTemplate));
          response
            ..statusCode = HttpStatus.ok
            ..headers.add('Content-Type', 'text/html;charset=UTF-8')
            ..headers.add('Content-Length', html.length.toString())
            ..add(html);
          await response.close();
        } else if (path == '/model-viewer.min.js') {
          final code = await _readAsset(
            'packages/model_viewer_plus/assets/model-viewer.min.js',
          );
          response
            ..statusCode = HttpStatus.ok
            ..headers
                .add('Content-Type', 'application/javascript;charset=UTF-8')
            ..headers.add('Content-Length', code.lengthInBytes.toString())
            ..add(code);
          await response.close();
        } else if (path == '/model') {
          final modelUri = Uri.parse(widget.src.trim());
          _cmv(
            'GET /model src=${modelUri.scheme} ${_cmvShortUrl(modelUri)}',
          );
          try {
            if (modelUri.isScheme('https') || modelUri.isScheme('http')) {
              await _streamRemoteGlb(modelUri, response);
            } else if (modelUri.isScheme('file')) {
              final data = await File(modelUri.toFilePath()).readAsBytes();
              response
                ..statusCode = HttpStatus.ok
                ..headers.contentType =
                    ContentType('application', 'octet-stream')
                ..headers.set(HttpHeaders.accessControlAllowOriginHeader, '*')
                ..headers.contentLength = data.length
                ..add(data);
              await response.close();
            } else {
              final data = await _readAsset(modelUri.path);
              response
                ..statusCode = HttpStatus.ok
                ..headers.contentType =
                    ContentType('application', 'octet-stream')
                ..headers.set(HttpHeaders.accessControlAllowOriginHeader, '*')
                ..headers.contentLength = data.length
                ..add(data);
              await response.close();
            }
          } catch (e, st) {
            _cmv('/model failed (catch): $e\n$st');
            debugPrint('model_viewer /model failed: $e\n$st');
            response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType =
                  ContentType('text', 'plain', charset: 'utf-8');
            response.write('Model load failed');
            await response.close();
          }
        } else if (path == '/favicon.ico') {
          final text = utf8.encode("Resource '${request.uri}' not found");
          response
            ..statusCode = HttpStatus.notFound
            ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
            ..headers.add('Content-Length', text.length.toString())
            ..add(text);
          await response.close();
        } else {
          if (request.uri.isAbsolute) {
            debugPrint('Redirect: ${request.uri}');
            await response.redirect(request.uri);
          } else if (request.uri.hasAbsolutePath) {
            final pathSegments = [...url.pathSegments]..removeLast();
            final tryDestination = p.joinAll([
              url.origin,
              ...pathSegments,
              request.uri.path.replaceFirst('/', ''),
            ]);
            debugPrint('Try: $tryDestination');
            await response.redirect(Uri.parse(tryDestination));
          } else {
            debugPrint('404 with ${request.uri}');
            final text = utf8.encode("Resource '${request.uri}' not found");
            response
              ..statusCode = HttpStatus.notFound
              ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
              ..headers.add('Content-Length', text.length.toString())
              ..add(text);
            await response.close();
          }
        }
      } catch (e, st) {
        debugPrint('model_viewer proxy handler: $e\n$st');
        try {
          response.statusCode = HttpStatus.internalServerError;
          await response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _streamRemoteGlb(Uri url, HttpResponse response) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 45);
    try {
      _cmv('HTTP client GET ${_cmvShortUrl(url)}');
      final rq = await client.getUrl(url);
      rq.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
      );
      final remote = await rq.close();
      final code = remote.statusCode;
      _cmv('HTTP response status=$code');

      if (code < 200 || code >= 400) {
        final body = await consolidateHttpClientResponseBytes(remote);
        final snippet = utf8.decode(
          body.length > 400 ? body.sublist(0, 400) : body,
          allowMalformed: true,
        );
        _cmv(
          'HTTP error body len=${body.length} snippet=$snippet',
        );
        response.statusCode = HttpStatus.badGateway;
        response.headers.contentType =
            ContentType('text', 'plain', charset: 'utf-8');
        await response.close();
        return;
      }

      response.statusCode = code;
      final ct = remote.headers.contentType;
      if (ct != null) {
        response.headers.contentType = ct;
      } else {
        response.headers.contentType = ContentType('application', 'octet-stream');
      }
      response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
      final cl = remote.contentLength;
      if (cl >= 0) {
        _cmv('piping stream contentLength=$cl');
      } else {
        _cmv('piping stream (chunked / unknown length)');
      }
      await response.addStream(remote);
      await response.close();
      _cmv('pipe completed successfully');
    } catch (e, st) {
      _cmv('HTTP exception (often offline / DNS / TLS): $e');
      _cmv('$st');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<Uint8List> _readAsset(final String key) async {
    final data = await rootBundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

}
