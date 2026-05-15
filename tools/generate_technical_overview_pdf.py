"""
Generate Ceylon Trails fully detailed technical overview PDF.
Run: python tools/generate_technical_overview_pdf.py
Requires: pip install fpdf2
"""
from __future__ import annotations

from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Ceylon_Trails_Technical_Overview.pdf"


class TechPDF(FPDF):
    def __init__(self) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(18, 18, 18)
        self.set_auto_page_break(auto=True, margin=16)
        self.alias_nb_pages()
        self.set_title("Ceylon Trails - Technical Overview")
        self.set_author("Ceylon Trails")

    def header(self) -> None:
        self.set_font("Helvetica", "B", 9)
        self.set_text_color(12, 59, 46)
        self.cell(0, 7, "Ceylon Trails - Technical Overview", ln=1)
        self.set_draw_color(200, 200, 200)
        y = self.get_y()
        self.line(self.l_margin, y, self.w - self.r_margin, y)
        self.ln(3)

    def footer(self) -> None:
        self.set_y(-14)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(100, 100, 100)
        self.cell(0, 6, "Page " + str(self.page_no()) + " / {nb}", align="C")


def tw(pdf: TechPDF) -> float:
    return pdf.w - pdf.l_margin - pdf.r_margin


def h(pdf: TechPDF, text: str, level: int = 1) -> None:
    pdf.set_x(pdf.l_margin)
    pdf.ln(2 if level == 1 else 1)
    if level == 1:
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_text_color(12, 59, 46)
    else:
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(30, 30, 30)
    pdf.multi_cell(tw(pdf), 6, text)
    pdf.set_text_color(20, 20, 20)


def p(pdf: TechPDF, text: str) -> None:
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Helvetica", "", 9.5)
    pdf.set_text_color(25, 25, 25)
    pdf.multi_cell(tw(pdf), 4.8, text)
    pdf.ln(0.8)


def bullets(pdf: TechPDF, lines: list[str]) -> None:
    pdf.set_font("Helvetica", "", 9.5)
    for line in lines:
        pdf.set_x(pdf.l_margin)
        pdf.multi_cell(tw(pdf), 4.8, f"- {line}")
    pdf.ln(0.8)


def main() -> None:
    pdf = TechPDF()
    pdf.add_page()

    h(pdf, "Fully detailed technical overview", 1)
    p(
        pdf,
        "This document describes the Ceylon Trails system as implemented in the repository: "
        "Flutter client, Firebase backend-as-a-service, optional OpenRouter LLM HTTP API, "
        "Google Maps SDK and external Maps directions, local forks for ARCore and model-viewer, "
        "and a React admin panel.",
    )

    h(pdf, "1. Repository layout", 1)
    bullets(
        pdf,
        [
            "lib/: Flutter app (screens, widgets, models/, services/, constants/, l10n ARB inputs, firebase_options.dart).",
            "android/, ios/: platform manifests, Gradle, native embedding for Maps, WebView, ARCore.",
            "assets/images/, assets/models/: bundled images and example GLB files (registered in pubspec.yaml).",
            "packages/arcore_flutter_plus/: path dependency; fork for plane detection and tap behaviour.",
            "packages/model_viewer_plus/: path dependency; fork for Android WebView model loading.",
            "admin_panel/: React + Vite SPA (Firestore CRUD, Storage uploads, routed pages).",
            "secrets.example.json: template for --dart-define-from-file (API keys at compile time).",
        ],
    )

    h(pdf, "2. Technology stack", 1)
    bullets(
        pdf,
        [
            "Dart SDK ^3.7.2, Flutter Material (useMaterial3: false in current main.dart theme).",
            "firebase_core, firebase_auth, cloud_firestore; firebase_options.dart from FlutterFire.",
            "google_maps_flutter; url_launcher for https://www.google.com/maps/dir/ links.",
            "model_viewer_plus (path) + webview_flutter (+ platform implementations).",
            "arcore_flutter_plus (path), permission_handler, vector_math.",
            "http client to OpenRouter; flutter_cache_manager; custom CeylonGlbCacheManager for GLB disk cache.",
            "flutter_tts, shared_preferences, path_provider, geolocator, google_fonts, intl.",
            "Admin: React, Vite, react-router-dom, Firebase JS modular SDK.",
        ],
    )

    h(pdf, "3. High-level architecture", 1)
    p(
        pdf,
        "Three-tier pattern: (1) Flutter client reads Firestore and Auth; downloads media from HTTPS URLs "
        "or bundled assets; calls OpenRouter over HTTPS; opens Google Maps externally for driving directions. "
        "(2) Firebase is the authoritative catalogue (documents + Storage URLs or paths in documents). "
        "(3) Admin SPA mutates the same Firestore collections and Storage via the JS SDK. "
        "There is no custom application server in-repo for core catalogue logic; orchestration is client-side "
        "plus Firebase Security Rules (configure rules to match email and anonymous guest modes).",
    )

    h(pdf, "4. Application bootstrap (lib/main.dart)", 1)
    bullets(
        pdf,
        [
            "WidgetsFlutterBinding.ensureInitialized().",
            "Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).",
            "AppLocaleController.instance.loadSavedLocale() before runApp.",
            "MaterialApp: locale from AppLocaleController (AnimatedBuilder); supportedLocales en, si, ta; "
            "delegates include AppLocalizations and Material/Cupertino/Widgets globals; home is LoadingScreen.",
            "pubspec.yaml: flutter: generate: true for l10n code generation.",
        ],
    )

    h(pdf, "5. Navigation and UI shell", 1)
    h(pdf, "5.1 Pre-main shell", 2)
    bullets(
        pdf,
        [
            "LoadingScreen: branding; Get Started pushes LoginScreen; Continue as Guest uses "
            "FirebaseAuth.signInAnonymously with timeout and still navigates to MainShellScreen on failure "
            "(see loading_screen.dart for exact behaviour).",
            "LoginScreen / SignupScreen / ForgotPasswordScreen: email/password; success uses pushAndRemoveUntil "
            "to MainShellScreen.",
        ],
    )
    h(pdf, "5.2 MainShellScreen", 2)
    bullets(
        pdf,
        [
            "Owns MainShellController (ChangeNotifier) for its lifetime; wraps MainShellScope (InheritedNotifier).",
            "Body: IndexedStack of four roots: HomeDashboardScreen; LocationsScreen (ValueKey(locationsKey) for remount); "
            "HeritageAiGuideScreen(onCloseToHome); ProfileScreen(onBackToHome).",
            "Bottom bar: HOME / MAP / AI / PROFILE; forest green styling (#0C3B2E, active chip #165040); haptics.",
            "IndexedStack preserves off-screen tab state (e.g. Places scroll position).",
        ],
    )
    h(pdf, "5.3 MainShellController (lib/shell_nav.dart)", 2)
    bullets(
        pdf,
        [
            "tabIndex 0-3; locationsKey increments to remount LocationsScreen.",
            "locationsSection -> initialSection (0 Map, 1 Places, 2 Saved); locationsCityFilter; locationsFocusSearch.",
            "Methods: goHome, showMapTab, goMap(...), goAi, goProfile.",
        ],
    )

    h(pdf, "6. Feature modules (Flutter)", 1)
    h(pdf, "6.1 Home dashboard", 2)
    p(
        pdf,
        "FirestoreService.streamLocations(); Geolocator near-me with debounce; NearMeCityService + "
        "lib/constants/city_geofences.dart (Haversine + radius). Can call MainShellScope.of(context).goMap(...) "
        "for deep links.",
    )
    h(pdf, "6.2 Locations / map (locations.dart)", 2)
    p(
        pdf,
        "Sections: Map (0), Places (1), Saved (2). GoogleMap centered on Sri Lanka; static Marker set for demo sites. "
        "Streams: streamLocationCityOptions, streamLocationsByCity, streamLocations. Pushes LocationDetailScreen.",
    )
    h(pdf, "6.3 Location detail and directions", 2)
    p(
        pdf,
        "Artifact list via streamArtifacts(locationId). Directions: cache-first Firestore get for lat/lng; "
        "MapsDirectionsService opens Google Maps dir URLs with api=1, destination coords or place query, "
        "travelmode=driving; origin omitted so Maps uses device location.",
    )
    h(pdf, "6.4 Geocoding", 2)
    p(
        pdf,
        "google_geocoding_service.dart uses String.fromEnvironment('GOOGLE_MAPS_API_KEY') with secrets.json "
        "pattern for REST Geocoding (separate from Android Maps SDK key in manifest).",
    )
    h(pdf, "6.5 Artifacts and detail", 2)
    p(
        pdf,
        "models/artifact.dart: fields include modelPath, modelPathAr, contextual AR paths, locationId as string "
        "or DocumentReference (normalized in fromFirestore). ArtifactDetailScreen: SessionAssetCacheService warm-up, "
        "ModelViewer, VoiceNarrationService, AIChatPanel + GeminiService, ARViewScreen entry.",
    )
    h(pdf, "6.6 3D viewer", 2)
    p(pdf, "viewer_3d_screen.dart: fullscreen ModelViewer; immersive SystemChrome while route active.")
    h(pdf, "6.7 AR (ar_view_screen.dart)", 2)
    bullets(
        pdf,
        [
            "Android ARCore path; camera permission before session; plane scoring and timers for weak surfaces.",
            "ArModelPathResolver: Firestore modelPathAr or derived assets/..._ar.glb from AssetManifest.json.",
            "toArCoreChannelFields maps resolved paths to file:// or https for Sceneform; ArCoreNativePrefetch uses "
            "method channel arcore_flutter_plus/utils (isolated to avoid web import of arcore).",
            "ArContextualModelResolver picks close/far/wall/ceiling variants from hit surface kind and distance.",
        ],
    )
    h(pdf, "6.8 AI chat", 2)
    bullets(
        pdf,
        [
            "GeminiService (legacy name): POST https://openrouter.ai/api/v1/chat/completions.",
            "Compile-time keys: OPENROUTER_API_KEY (preferred), DEEPSEEK_API_KEY, GEMINI_API_KEY; OPENROUTER_MODEL "
            "(default openrouter/auto).",
            "Non-streaming JSON body (stream: false); sendMessageStream yields one chunk for UI compatibility.",
            "System prompt from artifact title + truncated history + quick facts; multi-turn _messages list.",
            "Headers: Authorization Bearer, HTTP-Referer, X-Title. userFacingErrorMessage maps HTTP/network errors.",
        ],
    )
    h(pdf, "6.9 Heritage AI tab", 2)
    p(pdf, "heritage_ai_guide_screen.dart: full-page AIChatPanel with general Sri Lanka context.")
    h(pdf, "6.10 Profile", 2)
    p(
        pdf,
        "profile_screen.dart: Firebase user, AppLocaleController language, VoiceNarrationSettings for TTS locale/rate, "
        "sign-out and cache handling as implemented.",
    )

    h(pdf, "7. Data layer (FirestoreService)", 1)
    bullets(
        pdf,
        [
            "streamLocations(): locations snapshots; per-doc try/catch skips malformed documents.",
            "streamLocationsByCity(city): where city isEqualTo trimmed; empty city returns Stream.value([]) without listen.",
            "streamLocationCityOptions(): aggregate distinct city with counts; sort A-Z case-insensitive.",
            "streamArtifacts(locationId): Stream.multi with TWO queries - locationId as string AND as DocumentReference "
            "to locations/{id}; merge by doc id; sort createdAt then updatedAt (Timestamp or parseable string).",
        ],
    )
    h(pdf, "7.1 Location model parsing", 2)
    p(
        pdf,
        "Location.fromFirestore: defensive parsing; lat/lng from flat keys, nested geo objects, GeoPoint-like maps, "
        "and [a,b] pairs using Sri Lanka bounding heuristics when ambiguous.",
    )

    h(pdf, "8. Asset pipeline and caching", 1)
    bullets(
        pdf,
        [
            "SessionAssetCacheService: remote GLB via CeylonGlbCacheManager -> file:// for ModelViewer/AR; "
            "remote images via DefaultCacheManager -> FileImage; bundled assets unchanged.",
            "CeylonGlbCacheManager: dedicated CacheManager key ceylon_glb_models, stalePeriod 365 days, max 100 objects.",
        ],
    )

    h(pdf, "9. Android manifest (summary)", 1)
    bullets(
        pdf,
        [
            "Permissions: INTERNET, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, CAMERA.",
            "Uses-feature: android.hardware.camera.ar optional.",
            "Meta-data: com.google.android.geo.API_KEY for Maps SDK; com.google.ar.core optional.",
            "usesCleartextTraffic true (review for production). Queries for PROCESS_TEXT and VIEW https/http/geo.",
            "Ensure XML is well-formed (each meta-data element properly closed). Restrict keys in Google Cloud Console.",
        ],
    )

    h(pdf, "10. Admin panel", 1)
    bullets(
        pdf,
        [
            "App.jsx: Layout with Dashboard, Users, Locations, Artifacts routes.",
            "firebase/config.js: initializeApp; exports auth, db, storage.",
            "dbService.js: generic Firestore getAll, add, update, delete by collection name.",
            "storageService.js: uploadBytes + getDownloadURL; deleteObject from URL.",
            "sriLankaCities.js: city lists aligned with mobile app.",
        ],
    )

    h(pdf, "11. Build and configuration", 1)
    p(
        pdf,
        "Run with flutter run --dart-define-from-file=secrets.json so String.fromEnvironment receives "
        "OPENROUTER_* and GOOGLE_MAPS_API_KEY at compile time. Hot reload does not inject new defines. "
        "Version in pubspec.yaml: 1.0.0+1.",
    )

    h(pdf, "12. Security notes", 1)
    bullets(
        pdf,
        [
            "Do not commit real OpenRouter keys; rotate any leaked keys.",
            "Maps SDK key is extractable from APK - use Android app restriction + API restrictions.",
            "Admin Firebase web config is public by design; protect with Auth + strict Firestore/Storage rules.",
            "LLM outputs can hallucinate; app uses system prompt and truncated curated context only as mitigation.",
        ],
    )

    h(pdf, "13. Limitations", 1)
    bullets(
        pdf,
        [
            "AR primary path: Android ARCore; iOS ARKit not symmetric in same module.",
            "3D: WebView and device memory bound large GLBs.",
            "AI: requires network; non-streaming completion can feel slower on long answers.",
            "Geofences and default map centre assume Sri Lanka as primary geography.",
        ],
    )

    h(pdf, "14. Output", 1)
    p(pdf, f"This file was generated by tools/generate_technical_overview_pdf.py. Output: {OUT.name}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUT))
    print(f"Wrote: {OUT}")


if __name__ == "__main__":
    main()
