---
name: roblox-publish-checklist
description: Pre-publish / pre-update gate for a Roblox game - one scripted preflight via the Studio MCP checks data safety, monetization handlers, backdoors/secrets, streaming, UI sizing and debug leftovers; then a short interactive checklist covers what only a human can verify (live-server DataStore test, real purchases, mobile device, FTUE, metadata, assets permissions). Produces a GO / GO-with-risks / NO-GO verdict and keeps progress in PUBLISH.md. Use when the user is about to publish, make the game public, push a major update, asks "is my game ready", "what's missing before release", or wants a launch checklist.
---

# Roblox publish checklist

Two layers: **scan what code can verify, ask only about what it can't.** Don't read scripts one by one for this; don't re-ask items already ticked in `PUBLISH.md`.

## Workflow
1. Read `PUBLISH.md` (project root) if it exists: skip items already `[x]` unless the user says the area changed.
2. **Preflight (1 call):** run `references/preflight.lua` via `execute_luau`. Output lines are `FAIL / WARN / INFO / PASS`. Confirm each FAIL/WARN by reading the cited `path:line` before reporting; they are heuristics.
3. **Manual items:** walk the sections below in order, only the unticked `[H]`/`[L]` ones, in batches of 3-5 yes/no questions. Record answers in `PUBLISH.md` with date + note.
4. **Verdict:** 
   - **NO-GO**: any confirmed FAIL or any unticked Blocker.
   - **GO with risks**: no Blockers open, WARNs remain. List them.
   - **GO**: all Blockers and Shoulds ticked, no WARN.
5. Output per `ihaveadhd`: verdict, blockers list (`path:line` / item), risks, next action. No essay.

Tags: **[A]** preflight covers it, **[H]** human check, **[L]** needs a published/live server (Studio hides the problem). **B** = Blocker, **S** = Should, **N** = Nice.

## Data and persistence
- B [A] DataStore calls wrapped in `pcall` with retry/backoff (`luau-language` idioms). 
- B [A] `game:BindToClose` saves everyone; it may yield up to ~30 s, so save in parallel and keep it fast.
- B [A] Save on `PlayerRemoving` too.
- B [H][L] End-to-end test on a **live** server: new player, returning player, quit mid-session, rejoin. Studio needs "Enable Studio Access to API Services" and still isn't proof.
- S [A] `UpdateAsync` (not `SetAsync`) for saves, so concurrent writers don't clobber.
- S [A][H] Session lock so one profile isn't live on two servers (lock in `UpdateAsync` with a timeout for crashed servers, or a proven library like ProfileStore). Essential for economy/progression games.
- S [A] Data version field + migration path.
- S [H] Request budget respected: limits scale with players and change over time, check current docs; autosave every few minutes, never per-frame.
- S [H] Recovery plan for corrupted data (versioned DataStore keys, backups).
- N [H] Leaderboards use OrderedDataStore, updated at intervals.

## Security
- B [A] No `loadstring`, `require(<assetId>)`, `InsertService:LoadAsset` from free models (classic backdoors). Audit every free-model script.
- B [A] No secrets/keys in scripts (anything in ReplicatedStorage/clients is readable; server scripts still end up in version history).
- B [H] Every remote validates type, range, ownership, cooldown (run `roblox-code-review`). Currency, damage, inventory, progression computed on the server.
- B [A] No server logic or secrets in client-visible modules.
- S [H] Anti-exploit for competitive games: speed/teleport sanity checks and server-side hit detection.
- S [H] Debug/admin commands and `IsStudio()` branches can't be triggered live.

## Monetization (skip if none)
- B [A] `ProcessReceipt` set, grants first, **persists the grant**, then returns `PurchaseGranted`; returns `NotProcessedYet` if the player/data isn't ready.
- B [A] Receipt handling is idempotent: the same `PurchaseId` can arrive again; don't double-grant.
- B [H][L] Real purchase test of each product and pass in a live server (Studio prompts don't prove the flow).
- B [H] Pass/Premium benefits granted server-side; check ownership with `UserOwnsGamePassAsync` on join and handle purchase-finished events.
- S [A] `PlayerMembershipChanged` handled if Premium perks exist.
- S [H] Purchases work from any game state (mid-round, in menus, during death) with no lost items.
- N [H] Prices reviewed against the genre.

## Performance
- B [H] Core scenes hold 30+ FPS on a mid-range phone, or mobile is excluded in Game Settings.
- S [A] StreamingEnabled if the map is large (parts > ~10k); radii sensible.
- S [H] MicroProfiler: sustained frame time under 16.6 ms (60 FPS) or 33 ms (30 FPS); isolated spikes OK, repeated ones aren't. Fixes: `roblox-optimization`.
- S [H] Memory stable over a 20+ min session (no per-join/per-spawn leaks).
- S [A] No `print` spam, no deprecated `wait/spawn/delay` in hot paths.
- N [H] Network: remotes not fired every frame; payloads small.

## Mobile and UI
- B [H] All core actions work with touch only: no hover, no right-click, no keyboard-only.
- S [A] UI sized with Scale + constraints; buttons >= ~44 px.
- S [H] Respect safe areas (top bar, notch): use `ScreenGui.ScreenInsets`, test on a notched device/emulator.
- S [H] Mobile on-screen action buttons via `ContextActionService:BindAction` with `createTouchButton`; plain `UserInputService` keys are fine for desktop-only actions.
- S [H] Text readable (>= ~14 px equivalent).

## Gameplay
- B [H] Core loop runs start to finish without script errors (check the Developer Console, F9, on the live server).
- B [H] Multiplayer test with 2+ real clients if multiplayer.
- S [H] Edge cases: death mid-transaction, disconnect mid-save, empty/full inventory, stack limits.
- S [H] A new player understands the goal within ~2 minutes (FTUE). Ask someone who hasn't seen the game.
- S [H] Progression has no dead ends early/mid/late.
- S [H] Respawn leaves no stale tools, effects or connections.
- S [H] AFK players don't break rounds or farm rewards.
- S [H] A script error degrades one feature, not the whole game (pcall at boundaries).

## Assets and permissions
- B [H][L] Every animation, audio and image used is owned by the game's owner (user or group) or public. Studio under your own account works; a group game or other account silently fails.
- S [H] No assets that could be moderated/removed at launch (copyright audio).

## Metadata and compliance
- B [H] Experience guidelines questionnaire (age rating) completed accurately.
- B [H] Allowed devices set correctly; restrict rather than ship a broken platform.
- S [H] Icon 512x512; at least 3 thumbnails (or video); description with search keywords; genre set.
- S [A] `MaxPlayers` fits the design and server capacity.
- N [H] Social links / group page for update notes.

## Social (if relevant)
- B [H] Any player-written text shown to others goes through `TextService:FilterStringAsync` (or TextChatService); use the correct getter for the audience (chat vs non-chat broadcast).
- S [H] Private servers set up and working; basic report/mute/kick tools for social games.
- S [H] Group-rank gated features tested with real ranks.

## Analytics and operations
- S [H] Key events tracked: join/session length, first-time vs returning, tutorial completion, core loop actions, purchases, drop-off points. Roblox's dashboard covers retention and funnels; custom events through `AnalyticsService` (confirm the current API).
- S [H] Error visibility: server `ScriptContext.Error` / `LogService` logged with context, or the Creator Dashboard performance/error reports.
- S [H] Publish to a **staging place/experience** first; know how to roll back via version history.
- N [H] Plan for updates: shutdown notice (MessagingService) for breaking changes.

## Before pressing Publish
1. Fresh-account playthrough on desktop and phone (console if supported).
2. Live-server DataStore + purchase test done.
3. Someone else played it.
4. F9 console clean through a full session.
5. `PUBLISH.md` shows every Blocker ticked.

## PUBLISH.md format
```
# Publish status (updated YYYY-MM-DD)
Verdict: NO-GO | GO with risks | GO
- [x] BindToClose (A, 2025-..)  - [ ] Live DataStore test (L)  - [x] Age questionnaire (H, note)
Open risks: ...
```
