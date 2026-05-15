"""
One-off generator: Ceylon Trails project overview PDF for final reports.
Run: python tools/generate_project_report_pdf.py
"""
from __future__ import annotations

from pathlib import Path

from fpdf import FPDF


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Ceylon_Trails_Project_Report.pdf"


class ReportPDF(FPDF):
    def __init__(self) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(18, 18, 18)
        self.set_auto_page_break(auto=True, margin=16)
        self.alias_nb_pages()
        self.set_title("Ceylon Trails - Project Report")
        self.set_author("Ceylon Trails")

    def header(self) -> None:
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(12, 59, 46)
        self.cell(0, 8, "Ceylon Trails - Final Year Project", ln=1)
        self.set_draw_color(200, 200, 200)
        y = self.get_y()
        self.line(self.l_margin, y, self.w - self.r_margin, y)
        self.ln(4)

    def footer(self) -> None:
        self.set_y(-14)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(100, 100, 100)
        self.cell(0, 6, "Page " + str(self.page_no()) + " / {nb}", align="C")


def _text_w(pdf: ReportPDF) -> float:
    return pdf.w - pdf.l_margin - pdf.r_margin


def h(pdf: ReportPDF, text: str, level: int = 1) -> None:
    pdf.set_x(pdf.l_margin)
    pdf.ln(2 if level == 1 else 1)
    if level == 1:
        pdf.set_font("Helvetica", "B", 14)
        pdf.set_text_color(12, 59, 46)
    else:
        pdf.set_font("Helvetica", "B", 11)
        pdf.set_text_color(30, 30, 30)
    pdf.multi_cell(_text_w(pdf), 7, text)
    pdf.set_text_color(20, 20, 20)


def p(pdf: ReportPDF, text: str) -> None:
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(25, 25, 25)
    pdf.multi_cell(_text_w(pdf), 5.5, text)
    pdf.ln(1)


def bullet(pdf: ReportPDF, lines: list[str]) -> None:
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Helvetica", "", 10.5)
    for line in lines:
        pdf.set_x(pdf.l_margin)
        pdf.multi_cell(_text_w(pdf), 5.5, f"- {line}")
    pdf.ln(1)


def main() -> None:
    pdf = ReportPDF()
    pdf.add_page()

    h(pdf, "Executive summary", 1)
    p(
        pdf,
        "Ceylon Trails is a Flutter mobile application for discovering and experiencing Sri Lankan "
        "cultural heritage. It combines Firebase-backed content (heritage sites and artifacts), "
        "Google Maps browsing and directions, optional 3D models (GLB via model-viewer), Android "
        "ARCore-based augmented reality placement, multilingual UI (English, Sinhala, Tamil), "
        "text-to-speech narration, and an AI heritage guide powered through the OpenRouter HTTP API. "
        "A separate React + Vite admin panel supports CRUD on Firestore and uploads to Firebase Storage.",
    )

    h(pdf, "1. Problem and objectives", 1)
    p(
        pdf,
        "Heritage information is often fragmented. The app centralizes curated entries, supports "
        "discovery (home dashboard, map, city filters, saved items), deepens engagement with 3D/AR "
        "and narration, and adds conversational AI with context from the current screen.",
    )

    h(pdf, "2. System architecture", 1)
    p(
        pdf,
        "Client: Flutter app. Backend: Firebase Authentication, Cloud Firestore, Firebase Storage. "
        "External services: Google Maps (in-app SDK and external Maps app for directions URLs), "
        "OpenRouter for chat completions. Admin: React web app using the Firebase JS SDK.",
    )

    h(pdf, "3. Technology stack", 1)
    bullet(
        pdf,
        [
            "Flutter (Dart), Material UI, flutter_localizations + AppLocalizations",
            "firebase_core, firebase_auth, cloud_firestore",
            "google_maps_flutter, geolocator, permission_handler",
            "model_viewer_plus and arcore_flutter_plus as local path packages (forked for Android fixes)",
            "http client to OpenRouter; flutter_tts; shared_preferences; path_provider",
            "flutter_cache_manager + custom GLB cache manager for remote 3D assets",
            "Admin: React, Vite, React Router, Firestore + Storage SDK",
        ],
    )

    h(pdf, "4. Application flow", 1)
    h(pdf, "4.1 Startup (main.dart)", 2)
    p(
        pdf,
        "WidgetsFlutterBinding is initialized, Firebase.initializeApp runs with platform options, "
        "saved UI locale loads, MaterialApp starts with supported locales en/si/ta. The initial route "
        "is LoadingScreen. On AppLifecycleState.detached, SessionAssetCacheService clears disk caches "
        "for downloaded assets tied to the session.",
    )
    h(pdf, "4.2 Welcome and authentication", 2)
    p(
        pdf,
        "LoadingScreen offers Get Started (LoginScreen) or Continue as Guest. Guest flow calls "
        "FirebaseAuth.signInAnonymously with a 12 second timeout so Firestore rules that require "
        "request.auth still work on physical devices. On failure or timeout, SnackBars inform the user "
        "but navigation to MainShellScreen still proceeds so the app is not blocked.",
    )
    p(
        pdf,
        "Registered users sign in with email and password; successful login uses pushAndRemoveUntil "
        "to MainShellScreen. Sign-up and forgot-password screens exist on the same stack pattern.",
    )

    h(pdf, "4.3 Main shell navigation", 2)
    p(
        pdf,
        "MainShellScreen hosts four tabs in an IndexedStack: Home (HomeDashboardScreen), Map "
        "(LocationsScreen with Map / Places / Saved sections), AI (HeritageAiGuideScreen), Profile "
        "(ProfileScreen). A bottom bar switches tabs. MainShellController (shell_nav.dart) exposes "
        "tabIndex, locationsKey for forced remount, locationsSection, locationsCityFilter, "
        "locationsFocusSearch, and methods goHome, showMapTab, goMap, goAi, goProfile. "
        "MainShellScope provides inherited access for deep links from Home to Map with filters.",
    )

    h(pdf, "5. Core features", 1)
    h(pdf, "5.1 Home dashboard", 2)
    p(
        pdf,
        "Streams all locations from Firestore. Near Me uses Geolocator permissions and debounced "
        "positions; NearMeCityService matches coordinates to predefined city geofences (center + "
        "radius) to infer city and nearby site counts. UI can navigate the shell to the Map tab "
        "with a chosen section or city.",
    )
    h(pdf, "5.2 Locations / map", 2)
    p(
        pdf,
        "LocationsScreen shows a Google Map centered on Sri Lanka, static demo markers, and Firestore-"
        "driven lists. Places supports city search and filtering. Saved section holds user-saved "
        "entries (local state pattern in app). Tapping a site opens LocationDetailScreen.",
    )
    h(pdf, "5.3 Location detail and directions", 2)
    p(
        pdf,
        "Shows narrative content, tags, rating, and streams artifacts for the location. "
        "MapsDirectionsService opens https://www.google.com/maps/dir/ with destination coordinates "
        "and travelmode=driving; origin is omitted so Google Maps uses the device current location. "
        "If lat/lng are missing, the app tries cache-first Firestore reads on locations/{id}, then "
        "falls back to a text place query. SnackBars guide admins to add latitude/longitude fields.",
    )
    h(pdf, "5.4 Artifacts, 3D, AR, narration, contextual AI", 2)
    p(
        pdf,
        "Artifact model (models/artifact.dart) includes title, siteName, media paths, history, "
        "quickFacts, modelPath, optional modelPathAr and plane/distance variants (Close/Far/Wall/Ceiling), "
        "and locationId as string or DocumentReference (normalized when parsing).",
    )
    p(
        pdf,
        "ArtifactDetailScreen resolves remote images and GLBs through SessionAssetCacheService "
        "(remote GLB to file URI for ModelViewer). VoiceNarrationService reads text with flutter_tts; "
        "VoiceNarrationSettings stores locale and rate. AIChatPanel uses GeminiService to call OpenRouter "
        "with streaming tokens, grounded on the artifact title, history, and quick facts.",
    )
    p(
        pdf,
        "Viewer3DScreen provides fullscreen ModelViewer with immersive system UI. ARViewScreen (Android) "
        "uses ARCore: camera permission before session, plane detection scoring, tap-to-place Sceneform "
        "GLB, optional contextual model choice by surface kind and distance, rotate/scale gestures.",
    )
    h(pdf, "5.5 General AI tab", 2)
    p(
        pdf,
        "HeritageAiGuideScreen embeds AIChatPanel as a full-page chat with broad Sri Lankan heritage "
        "context and canned quick facts; dismiss returns to Home via shell callback.",
    )
    h(pdf, "5.6 Profile", 2)
    p(
        pdf,
        "App language selection (AppLocaleController), voice narration language and speed, sign-out, "
        "and session cache management aligned with Firebase session lifecycle.",
    )

    h(pdf, "6. Firestore data access", 1)
    p(
        pdf,
        "FirestoreService streams locations, filters by city, builds distinct city options with counts, "
        "and merges two artifact queries: locationId equal to string id and locationId equal to "
        "DocumentReference to locations/{id}. Merged docs are de-duplicated by id and sorted by "
        "createdAt/updatedAt when present. Malformed documents are skipped with debug logs so one bad "
        "row does not empty a list.",
    )

    h(pdf, "7. Configuration and security notes", 1)
    p(
        pdf,
        "OpenRouter and optional Google REST keys are passed at compile time via --dart-define or "
        "--dart-define-from-file=secrets.json (see secrets.example.json). Keys must not be committed. "
        "AR requires camera permission; Near Me requires location permission. Firebase security rules "
        "must be configured to match anonymous and email users.",
    )

    h(pdf, "8. Admin panel", 1)
    p(
        pdf,
        "React + Vite app with routes for Dashboard, Users, Locations, and Artifacts. dbService "
        "wraps Firestore CRUD; storageService uploads and deletes files in Firebase Storage (e.g. GLB). "
        "Shared Sri Lanka city constants keep admin dropdowns aligned with the mobile app.",
    )

    h(pdf, "9. Limitations and platform notes", 1)
    bullet(
        pdf,
        [
            "ARCore flow targets Android; iOS AR is not the primary documented path in ARViewScreen.",
            "3D viewing depends on the device WebView for model-viewer.",
            "AI requires network and a compile-time API key; hot reload does not inject new defines.",
        ],
    )

    h(pdf, "10. Repository layout (high level)", 1)
    bullet(
        pdf,
        [
            "lib/ : Flutter screens, widgets, services, models, constants, l10n wiring",
            "admin_panel/ : React admin",
            "packages/arcore_flutter_plus, packages/model_viewer_plus : local forks",
            "assets/ : images and bundled GLB models",
        ],
    )

    h(pdf, "Document generated from codebase", 1)
    p(
        pdf,
        "This PDF was generated automatically for submission as project documentation. "
        f"Output file: {OUT.name}",
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUT))
    print(f"Wrote: {OUT}")


if __name__ == "__main__":
    main()
