# Scribo – File organization map

Files that are still at the **root** of `Scribo/Scribo/` (or loose under `Views/`) and where they fit in the new folder system.

---

## Root-level Swift files

| File | Purpose | Suggested folder | Reason |
|------|--------|-------------------|--------|
| **AppStateAndErrors.swift** | `NoteDisplayState`, `AppError`, `AlertManager` | `App/` | App-level state and global alert handling; lives next to `ScriboApp`. |
| **LaunchScreenView.swift** | Launch/splash screen | `App/` | Part of app entry flow. |
| **SupabaseConfig.swift** | Supabase client singleton | `Configuration/` | Config/setup (you already have `Configuration/` with StoreKit). |
| **ClassificationLabels.swift** | Static topic/subtopic labels for classification | `Models/` | Domain data used by `TextClassificationService`. |
| **LottieView.swift** | Lottie animation wrapper (UIViewRepresentable) | `Utilities/` | Reusable view helper, like `FontManager` / `SoundManager`. |
| **UIViewRepresentable.swift** | `BannerAdView` (Google Ads) | `Utilities/` | Reusable UIKit bridge. |
| **ProfileViews.swift** | Profile/settings UI (`ProfileSheetView`, `EditableField`, etc.) | `Views/Profile/` | All profile/settings screens in one place. |
| **FeedbackView.swift** | Feedback form (opened from sidebar) | `Views/Profile/` or `Views/Settings/` | Sidebar/settings flow; can sit with `ProfileViews` or in a future `Views/Settings/`. |
| **CameraView.swift** | Camera capture (UIImagePickerController) | `Views/Documents/` | Used for document/photo capture. |
| **ImageGalleryGridView.swift** | Grid of images + selection | `Views/Components/` | Reusable gallery UI (notes, documents). |
| **FullscreenImageViewer.swift** | Full-screen image + zoom | `Views/Components/` | Reusable viewer; often used with `ImageGalleryGridView`. |
| **PrivacyPolicy.swift** | Privacy policy screen | `Views/Legal/` | Legal/content views. |
| **TermsOfUse.swift** | Terms of use screen | `Views/Legal/` | Same. |

---

## Views already under `Views/` but not in a feature subfolder

| File | Suggested folder | Reason |
|------|-------------------|--------|
| **Views/PremiumFeaturePromptView.swift** | `Views/Subscription/` | Premium/paywall UI. |
| **Views/SubscriptionIntegrationExample.swift** | `Views/Subscription/` or keep at `Views/` | Example or demo for subscription flow. |

---

## Folders to add (if you adopt this)

- **`Views/Profile/`** – Profile, settings, feedback (and optionally `ProfileViews.swift` content).
- **`Views/Components/`** – Shared UI (e.g. `ImageGalleryGridView`, `FullscreenImageViewer`).
- **`Views/Legal/`** – `PrivacyPolicy`, `TermsOfUse`.
- **`Configuration/`** – Already exists; add `SupabaseConfig.swift` here.

---

## Resulting structure (only the parts that change)

```
Scribo/
├── App/
│   ├── ScriboApp.swift
│   ├── AppStateAndErrors.swift   ← move
│   └── LaunchScreenView.swift   ← move
├── Configuration/
│   └── SupabaseConfig.swift      ← move
├── Models/
│   ├── ...
│   └── ClassificationLabels.swift ← move
├── Utilities/
│   ├── SoundManager.swift
│   ├── FontManager.swift
│   ├── LottieView.swift          ← move
│   └── UIViewRepresentable.swift ← move (BannerAdView)
├── Views/
│   ├── Profile/
│   │   ├── ProfileViews.swift    ← move (or split later)
│   │   └── FeedbackView.swift    ← move
│   ├── Components/
│   │   ├── ImageGalleryGridView.swift  ← move
│   │   └── FullscreenImageViewer.swift ← move
│   ├── Documents/
│   │   ├── ...
│   │   └── CameraView.swift      ← move
│   ├── Legal/
│   │   ├── PrivacyPolicy.swift   ← move
│   │   └── TermsOfUse.swift      ← move
│   └── Subscription/
│       ├── SubscriptionView.swift
│       ├── PremiumFeaturePromptView.swift   ← move
│       └── SubscriptionIntegrationExample.swift ← move
└── ...
```

---

## Optional refinements

- **ProfileViews.swift** is large; you can later split into `ProfileSheetView.swift`, `EditableField.swift`, etc., still under `Views/Profile/`.
- **AppStateAndErrors.swift**: if you prefer “state” separate from “app”, you could add `App/State/` or `Models/AppState.swift` and keep only `ScriboApp` and `LaunchScreenView` in `App/`.
- **Theme/Theme.swift** is already in a folder; no change needed unless you want to move it under `Extensions/` or `Utilities/`.
- **Managers/NotificationManager.swift**: could be moved to `Services/` for consistency with `DataManager`, `AuthManager`, etc., or left under `Managers/` if you treat that as the home for non–data-layer managers.

If you want, the next step is to apply these moves in the project (create the new folders and move the files as in the table).
