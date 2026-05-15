# Ceylon Trails — Admin panel

## Users tab (Firestore `users`)

The **Users** page lists documents in **`users/{uid}`** in Firestore. Firebase **Authentication** is separate: email/password accounts do **not** automatically create Firestore rows.

- **New behaviour:** The mobile app writes/updates `users/{uid}` on sign-up, sign-in, guest, and when opening the main shell.
- **If `users` never appears in Firestore:** Security rules may be blocking writes — see **`docs/firestore-users-rules.txt`** in the repo root.
- **Existing Auth users (created before that):** Either sign in once on the app **or** run the backfill script below.

### One-time backfill: Auth → Firestore

1. In [Google Cloud Console](https://console.cloud.google.com/) (project **ceylon-trails**): **IAM & Admin → Service Accounts →** create or pick a service account → **Keys → Add key → JSON**.
2. Grant the service account permission to **list Firebase Auth users** and **write Firestore** (for a private dev project, **Editor** is simplest; for production, use minimal roles such as **Firebase Authentication Admin** plus **Cloud Datastore User**).
3. From the **`admin_panel`** folder:

```bash
npm install
```

**Windows (PowerShell):**

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your-service-account.json"
npm run sync-auth-to-firestore
```

**macOS / Linux:**

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/your-service-account.json
npm run sync-auth-to-firestore
```

4. Refresh **Users** in the admin UI.

Never commit the JSON key or expose it in the Vite client.

---

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) (or [oxc](https://oxc.rs) when used in [rolldown-vite](https://vite.dev/guide/rolldown)) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.
