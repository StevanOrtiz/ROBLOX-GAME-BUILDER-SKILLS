---
name: roblox-ui-live
description: Build Roblox UI as live, persistent, named instances in StarterGui (ScreenGui > containers > components with layout objects) created through the Studio MCP execute_luau, plus a separate controller for behaviour - never UI generated from scratch at runtime. Visual style always comes from the user's prompt; this skill supplies the structure, naming contract, responsive sizing, and the state flow. Use whenever the user asks to create, change, restyle, or fix any Roblox GUI - HUD, shop, inventory, menu, popup, settings, buttons, labels, lists - or asks why UI looks wrong on mobile or does not respond.
---

# Roblox UI - live instances

Style = what the user says in the prompt. Structure = this skill. No default look is imposed.
If no style is given, build neutral and keep all style values in ONE `Theme` table so a restyle is one call.

## Principles
- UI exists as real instances in `StarterGui`, saved with the place. Inspectable and editable by path later. Not spawned by a runtime script.
- Build script (once, via `execute_luau`) = structure + look. Controller (LocalScript/module) = behaviour only. The controller never creates the static structure.
- Names are the API. Controller finds things by exact path. Never leave default names (`Frame`, `TextLabel`).

## Hierarchy
```
<Feature>Gui            ScreenGui  ResetOnSpawn=false, ZIndexBehavior=Sibling
  Main                  Frame      the window/root; Visible=false if a popup
    Header              Frame      TitleLabel, CloseButton
    Body                Frame      content; lists use ItemList + UIListLayout/UIGridLayout
    Footer              Frame      action buttons
  Templates             Folder     <Thing>Template (Visible=false), cloned by controller
```
Components: one Frame per component, children named by role: `CoinsLabel`, `BuyButton`, `ItemTemplate`, `IconImage`, `PriceLabel`.

## Layout rules
- Size/position in **Scale**, with `AnchorPoint` set. Pixels only for padding/stroke/corner.
- Lay out with `UIListLayout` / `UIGridLayout` / `UIPadding`. No hand-placed offsets for repeated items.
- Guard scaling: `UIAspectRatioConstraint`, `UISizeConstraint`, `UITextSizeConstraint` (with `TextScaled`).
- Decoration objects named by type: `Corner`, `Stroke`, `Padding`, `Layout`.
- Must work on phone, tablet, desktop: check small-screen proportions, keep tap targets large.

## Style roles
Tag or attribute key surfaces (`UIRole = "Primary" | "Surface" | "Text" | "Accent"`) so a restyle pass retargets by role (`CollectionService` or attribute) instead of by name hunting.

## Flow
```
user action -> Controller -> Remote (intent) -> Server validates -> state back (Remote/Attribute) -> Controller sets .Text/.Visible
```
- Buttons: `.Activated` (touch, gamepad, mouse), not `MouseButton1Click`.
- One open/close function per window; tween optional; only one modal open at a time.
- List items: clone `Templates/<Thing>Template`, name the clone by item id, parent to `ItemList`; clear and rebuild on state change.
- UI never decides truth (prices, ownership). It displays server state.

## Build procedure (one MCP call per window)
1. Read `GAMEMAP.md`/target path only. Don't read the existing tree.
2. One `execute_luau`: use the helper in `references/ui-builder.lua`, find-or-create everything by name (idempotent), apply Theme, tag roles.
3. Same script then asserts the **name contract** (list of paths the controller needs) and returns `missing = {...}` plus a one-line tree of just this Gui (names only).
4. Write/patch the controller via `multi_edit`. Register it in the client Main.
5. Update `GAMEMAP.md`. No screenshot unless the user asked for visual check.

## Editing existing UI
- Change only the named instance/property: `execute_luau` that resolves the path and sets it. Don't rebuild the window.
- Don't touch UI the request didn't mention, including the user's manual tweaks.

## Don't
Runtime-generated static UI, default names, pixel-only sizes, `MouseButton1Click`, the controller owning game state, reading the full StarterGui to "see what's there".
