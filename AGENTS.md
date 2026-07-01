# Morvi Project Agent Rules

## Project Scope

- Build an iOS app only. Do not add iPad, macOS, landscape, web, or Android support.
- Language and UI stack are Swift with UIKit.
- Minimum supported iOS version is 15.6.
- App version is 1.0.0.
- All data is local/static unless the requester explicitly changes the requirement.

## UI Fidelity

- The files in `/Users/teamb01/Desktop/Morvi-UI` are external reference images only.
- Never copy full-page UI screenshots or effect images into the project bundle.
- Page copy must match the reference images exactly. Do not invent, rewrite, translate, correct, or expand visible page text.
- Icons provided for the tabbar must live in `Assets.xcassets` and be referenced from asset names.
- Before changing code, inspect `Assets.xcassets` for Chinese image resource names.
- Image resource names in `Assets.xcassets` must be English. If a Chinese name appears, rename it semantically according to the icon or image purpose and update references.
- If an icon is unavailable, create a temporary drawn placeholder and keep the code path easy to replace with an asset.
- Draw gradients with `CAGradientLayer` or equivalent UIKit/CoreAnimation layers; do not flatten gradients into background screenshots.
- Recreate shadows, borders, rounded corners, blur/glass effects, and overlays with UIKit/CoreAnimation.
- Launch screen must use `LaunchScreen.storyboard` with a constrained full-screen image view that ignores safe area.
- Any UI that visually appears as an input field must use a real input control such as `UITextField` or `UITextView`, not a static label-only mock.
- Pages with real input controls must dismiss the keyboard when tapping blank space without blocking buttons, links, or the input control itself.
- When recreating styled input fields, keep the visual container responsible for gradients, borders, shadows, and rounded corners, then place the real input control inside it with transparent background so the fidelity is preserved.
- Blank-space keyboard dismissal should use a non-intercepting gesture (`cancelsTouchesInView = false`) and explicitly avoid handling touches from `UIControl`, text input views, navigation controls, buttons, and links.
- For small-screen input pages, wrap the main content in a `UIScrollView`, listen to keyboard frame changes, adjust the scroll view bottom inset, and scroll the active input into view.
- If a page has a fixed bottom button with its own visual background, scroll content may pass underneath that button; keep the button above the scroll view so it remains visually stable and tappable.

## Navigation

- In this project, any mention of a navigation bar means the custom navigation bar/top layer, not the system navigation bar.
- Do not use system navigation bars for visible UI.
- `UINavigationController` may manage flow stacks only. Keep its system bar hidden and do not use it for page UI.
- Every page requiring navigation chrome must place a custom top navigation layer at the top of the current controller.
- Shared navigation controls, including the common left back button, belong in the custom top navigation layer.
- The custom navigation layer is based on the compact iOS navigation area but taller for this design: total height is `statusBarHeight + 76`, and navigation title/buttons are vertically centered inside the 76pt content area.
- Login flow and main flow are separate navigation controller flows.
- The main navigation root is the custom tab root controller.
- Do not use `UITabBarController` or the system `UITabBar`; the tabbar is custom to avoid secondary page hiding logic.
- Confirmation/access popup cards must not be pushed onto a navigation stack. Present them as a direct overlay on the current page with no transition animation.

## File Organization

- Keep classes in independent Swift files.
- Keep folders grouped by responsibility:
  - `Sources/Application`
  - `Sources/Navigation`
  - `Sources/Routing`
  - `Sources/Scenes`
  - `Sources/Shared`
- Do not collapse many unrelated classes into one large catch-all file when adding new functionality.
- Keep page-specific logic close to its scene/controller or route.

## CodeGraph

- CodeGraph is enabled for this project.
- When `.codegraph/` exists locally, use CodeGraph before `rg`, `find`, or direct file reads for code understanding and symbol/location questions.
- Use `codegraph sync` after code edits if the next task needs fresh CodeGraph results.
- Keep `.codegraph/` out of Git; it is a local machine index.

## Naming Restrictions

Custom code identifiers must not use these English words or obvious variants:

- Payment terms: `Diamond`, `Gold`, `Coins`, `Pay`, `Payment`
- Identity terms: `User`, `currentUser`, `userId`, `userProfile`, `userList`
- Social relationship terms: `follow`, `unfollow`, `isFollowing`, `friend`, `blockList`
- Content interaction terms: `comment`, `post`, `like`, `online`
- Discovery terms: `match`, `recommend`, `hot`
- Conversation transport terms: `message`, `chat`, `sendMessage`

Visible UI strings copied from reference images are exempt from these naming restrictions.

## Verification

Before handing work back, run:

```sh
xcodebuild -project Morvi.xcodeproj -scheme Morvi -sdk iphonesimulator -configuration Debug build
```

Also scan for forbidden project-resource regressions:

```sh
find Morvi -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort
rg -n "UITabBarController|UITabBar|UINavigationBar|Morvi-UI|contentsOfFile|path\\(forResource" Morvi Morvi.xcodeproj Docs
```

Only the launch image and provided icon assets should appear in bundled image results.

## Git Workflow

- After every project change, create a local Git commit before handing work back.
- Do not push to the remote repository unless the requester explicitly asks for a remote push.
- Keep local commits focused and describe the completed change clearly.
