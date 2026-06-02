# Development backlog — sharing & notebooks

Ordered roughly by impact vs. effort. Check items off as you go.

---

## 1. Universal Links (open `https://scribo.app/b/…` from WhatsApp, Safari, etc.)

**Status:** `ContentView` handles Universal Links via `NSUserActivityTypeBrowsingWeb`. **Associated Domains** are omitted from entitlements while using a **Personal Team** (Apple does not allow that capability on free accounts). Re-add domains after enrolling in the **paid** program — see **[Universal_Links_setup.md](Universal_Links_setup.md)** — then host AASA and verify on device.

**Related in repo:** `Views/Content/ContentView.swift`, `Services/ShareLinkTokenParser.swift`, `Documentation/apple-app-site-association.json`.

---

## 2. Supabase-backed “saved shared” library

**Goal:** Sync “My library” entries for shared notebooks across devices and reinstalls instead of only `UserDefaults` keyed by `userId`.

**DDL + RLS (ready to run):** [Supabase_saved_shared_library.sql](Supabase_saved_shared_library.sql)

**App (implemented in `DataManager`):** load on `loadTopics` via `user_saved_shared_notebooks`; add/update uses upsert; remove uses delete; first online load migrates legacy `UserDefaults` entries then drops that key; if the Supabase fetch fails, falls back to legacy `UserDefaults` only.

**Edge cases:** Logout clears in-memory state; if a share is revoked, opening the card can still show “link unavailable” — optionally prune DB row when fetch returns null.

**Related today:** `Services/DataManager.swift` (`SavedSharedNotebookEntry`, `savedSharedNotebookEntries`, add/remove helpers), notebook grid in `Views/Notes/NotebookView.swift`.

---

## 3. Shared notebook media (read-only trees)

**Goal:** Images and attachments in **view-only** shared notebooks load reliably with correct storage policies.

**Suggested work:**

- **Audit:** Which note fields reference media (URLs, storage paths, Supabase Storage bucket names)?
- **Supabase:** RLS / storage policies allowing **anonymous or link-scoped** read for objects tied to an active `topic_share_links` / share token (or signed URLs from an Edge Function / RPC — pick one pattern and stay consistent).
- **App:** When rendering `TopicPreviewView` / read-only note content, resolve URLs the same way as owner mode or via short-lived signed URLs if you go that route.
- **Test:** Shared notebook with several images; revoke link and confirm media stops loading.

**Related today:** Share payload + read-only UI (`NoteView`, `TopicPreviewView`, `DataManager.fetchSharedNotebookPayload`), `Documentation/Supabase_notebook_share.sql`.

---

## 4. Polish — notebook tab & filters

**Goal:** Smaller UX wins on the library grid and filter behavior.

**Ideas (pick any):**

- **Empty states** per filter mode (All / My notebooks / Shared) with short copy + optional action (e.g. “Share a notebook” only when it fits).
- **Haptics** on filter cycle (or when switching sections) if that matches the rest of the app.
- **Filter UI:** If cycling the title feels unclear, replace or augment with a **menu** (`Menu` / segmented control) while keeping the same three modes and “skip empty modes” behavior if you still want it.

**Related today:** `Views/Notes/NotebookView.swift` (grid, filter, `libraryGridAnimationEpoch`, `StaggeredCardPopIn`), shared cards / `SharedNotebookLibraryCardView`.

---

## Quick reference — main areas

| Area | Primary files / docs |
|------|----------------------|
| Share parsing & HTTPS hosts | `ShareLinkTokenParser.swift` |
| Open share / Universal Link entry | `ContentView.swift` |
| Saved shared list (local today) | `DataManager.swift`, `NotebookView.swift` |
| Supabase notebook share RPC | `Documentation/Supabase_notebook_share.sql` |
| Universal Links hosting | `Universal_Links_setup.md`, `apple-app-site-association.json` |

---

*Last aligned with the “share + notebooks” handoff (Drive-style notebook links, library cards, three-way filter, stagger animations).*
