# JellyTV — Manual Smoke Test Checklist

After Phase 0/1 completes, run this checklist on a real Apple TV 4K (or the
tvOS Simulator) against a real LAN Jellyfin server. The motif workflow
verifies the package boundary with unit tests and the build with `xcodebuild`,
but a live server is the only way to confirm the actual auth flow works
end-to-end.

## Setup

1. Have a Jellyfin server running on your LAN, version 10.9 or later. Note its
   URL (e.g. `http://192.168.1.50:8096`).
2. In the Jellyfin admin dashboard → **Quick Connect** → **Enable Quick Connect**
   so you can test the QC flow.
3. Open `JellyTV/JellyTV.xcodeproj` in Xcode.
4. Select the **JellyTV** scheme + **Apple TV 4K (3rd generation)** simulator
   destination, hit **⌘R**.

## Phase 1 acceptance criteria — must all pass

### Connect flow

- [ ] On first launch, the app shows the **server URL entry** screen.
- [ ] The TextField has initial focus (Siri Remote / arrow keys land on it).
- [ ] Type a URL **without a scheme** (e.g. `192.168.1.50:8096`) and tap
      Connect → server validates successfully (the `normalizeServerURL` helper
      should prepend `http://`).
- [ ] Type a URL with a scheme (`http://192.168.1.50:8096`) → also works.
- [ ] Type a clearly invalid URL (`asdf`) → friendly error message
      ("That doesn't look like a valid server URL…").
- [ ] Type a URL pointing at nothing reachable (`http://10.99.99.99`) → friendly
      "Couldn't reach the server" error after the request times out.
- [ ] Successfully connecting transitions to the **choose mode** screen showing
      the server name (or host fallback).

### Quick Connect flow

- [ ] On the choose-mode screen, "Use Quick Connect" has default focus.
- [ ] Tap "Use Quick Connect" → the 6-character code displays in large
      monospaced type, with a polling spinner beneath it.
- [ ] Open Jellyfin in a browser → log in → user menu → Quick Connect → enter
      the code → approve.
- [ ] Within ~2 seconds, the app picks up the approval, shows
      "Signed in as \<your name\>", and a Sign Out button.
- [ ] If you wait too long (5+ minutes) without approving the code, the app
      transitions to a `quickConnectExpired` failure state with a retry path —
      it does NOT spin forever (this is the regression test for the #B1
      critic finding).

### Quick Connect disabled

- [ ] Disable Quick Connect in the Jellyfin admin → tap "Use Quick Connect" in
      the app → user-friendly "Quick Connect is not enabled on this server.
      Use username and password instead." message. The app does NOT show a
      generic "auth failed" error (this is the regression test for the #C4
      critic finding — the actor's per-callsite remap of 401 → quickConnectDisabled).

### Password sign-in flow

- [ ] On the choose-mode screen, tap "Sign in with username & password".
- [ ] Username + password fields appear; typing into username then **Submit**
      moves focus to password.
- [ ] Wrong password → "Wrong username or password" friendly error.
- [ ] Right password → transitions to "Signed in as \<your name\>".

### Session persistence (#1657 regression test)

- [ ] After signing in, **force-quit the app** in the simulator (Cmd+Shift+H,
      then swipe up on the JellyTV preview).
- [ ] Relaunch the app from the home screen.
- [ ] App goes briefly through `loading` then directly to "Signed in as \<your
      name\>" — does NOT show the sign-in screen again.

### Network blip on launch (critic C8 regression test)

- [ ] Sign in successfully.
- [ ] **Stop the Jellyfin server** (or pull the LAN cable).
- [ ] Force-quit and relaunch the app.
- [ ] App shows the **Reconnecting** screen with "Try Again" + "Sign Out"
      buttons. It does NOT silently sign you out and dump you back to the URL
      entry screen.
- [ ] Restart the server, tap **Try Again** → app transitions to "Signed in as
      \<your name\>".

### Sign out

- [ ] On the signed-in screen, tap **Sign Out**.
- [ ] App returns to the URL entry screen.
- [ ] Force-quit and relaunch → app starts at URL entry (credentials cleared,
      not silently restored).

## "Must not regress" checklist (from softplan §7)

These are bugs the SwiftFin tvOS App Store build still has on v1.0.1. Phase 1
must not have any of them. Most are not testable until Phase 2/3/4 ships, but
the Phase 1 ones are:

- [ ] **No crash on Connect / sign in** — happy-path Connect → sign-in
      completes without an `EXC_BAD_ACCESS` or fatal-error.
- [ ] **Persistent login** — relaunch lands you in the signed-in state. ✓
      (covered above)

The other items (audio tracks, FF/RW, scrolling crashes, etc.) are deferred to
their respective phases.
