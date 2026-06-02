# Universal Links — finish later

The app routes Universal Links in `ContentView` via `NSUserActivityTypeBrowsingWeb`. **Associated Domains** must be added to the entitlements when you are ready to ship Universal Links (see below).

### Personal Team vs paid Apple Developer Program

**Free “Personal Team” accounts cannot use the Associated Domains capability.** Xcode will fail to create a development or distribution profile if `com.apple.developer.associated-domains` is present.

For local development with a Personal Team, **`Scribo.entitlements` and `ScriboDebug.entitlements` intentionally omit Associated Domains.** After you enroll in the **paid** [Apple Developer Program](https://developer.apple.com/programs/), add the capability back to **both** entitlements (same contents):

```xml
<key>com.apple.developer.associated-domains</key>
<array>
	<string>applinks:scribo.app</string>
	<string>applinks:www.scribo.app</string>
</array>
```

Or use Xcode: target **Signing & Capabilities** → **+ Capability** → **Associated Domains** → add `applinks:scribo.app` and `applinks:www.scribo.app`.

Until then, `https://scribo.app/b/…` links still open in Safari; **custom URL schemes** (`scribo://…`) continue to work for testing.

---

## 1. Apple Developer — App ID

1. Sign in to [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Open the App ID for **`com.dauntless.scribos`**.
3. Enable the **Associated Domains** capability (if it is not already on).
4. Save.

If you use Xcode automatic signing, open the Scribo target → **Signing & Capabilities** and confirm **Associated Domains** lists the domains above (after you enable them on a paid team).

## 2. Host the Apple App Site Association (AASA) file

Use the template in this folder:

- [`apple-app-site-association.json`](apple-app-site-association.json)

**Publish it at both URLs if you use both apex and `www`:**

| Location | URL |
|----------|-----|
| Preferred | `https://scribo.app/.well-known/apple-app-site-association` |
| Alternate (also valid) | `https://scribo.app/apple-app-site-association` |
| If you share `www` links | Same paths on `https://www.scribo.app/...` |

**Requirements:**

- **HTTPS** only.
- **No file extension** in the URL (the file on disk can be named anything; the served path must be `apple-app-site-association`).
- Avoid **redirects** on that URL (especially cross-domain); Apple’s fetch can fail.
- **`Content-Type: application/json`** is typical for the unsigned JSON format.

The JSON must include your **Team ID** and **bundle ID** as `appID` in the form `TEAMID.bundleid` (currently `T4U3LQTNHW.com.dauntless.scribos` in the template). Update the template if either changes.

**Paths** in the template match public shares: `/b/*` (notebook), `/n/*` (legacy note). Adjust if your site uses different paths.

## 3. Verify

- After deploying AASA, use an AASA validator or Apple’s documentation tools to confirm the file is reachable and well-formed.
- Install a **fresh build** of the app on a device (iOS caches associations; reinstall or wait if links still open only in Safari).

## 4. Optional: marketing page

If the app is not installed, the link opens in Safari. You can serve a simple landing page at `/b/...` or a generic “Get Scribo” page; Universal Links still apply when the app is installed.

---

**Reference:** [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains) (Apple).
