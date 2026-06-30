# Morvi UIKit Implementation Notes

## Hard Requirements
- Swift + UIKit only.
- iPhone only, portrait only.
- Minimum iOS version: 15.6.
- App version: 1.0.0.
- System navigation bars stay hidden. Navigation controllers only manage flow stacks.
- Every page owns a top-level custom navigation layer pinned to the top of the controller view.
- Main flow uses a custom floating tab control, not `UITabBarController`.
- Page copy must align with the provided UI images exactly. No invented, corrected, translated, or expanded copy.
- Custom Swift names must avoid the forbidden English words listed in AGENTS.md. UI strings and provided image filenames are exempt.

## Current Structure
- `Morvi/Sources/Application`: app and scene launch.
- `Morvi/Sources/Navigation`: navigation shell with the system bar forced hidden.
- `Morvi/Sources/Routing`: page enum and route factory.
- `Morvi/Sources/Scenes/Auth`: login entry flow.
- `Morvi/Sources/Scenes/Main`: custom tab root flow.
- `Morvi/Sources/Scenes/Common`: reusable reference page controller.
- `Morvi/Sources/Shared/Views`: reusable UIKit views.
- `Morvi/Sources/Shared/Interaction`: transparent hit-area helpers.
- `Morvi/Assets.xcassets`: app assets and provided tabbar icons.
- `Morvi/LaunchScreen.storyboard`: launch screen file using a full-screen constrained image view.

## Page Coverage
Provided full-page UI images are used as external references only and are not bundled into the app. Page route coverage is kept in code through login, main tabs, secondary pages, and modal style pushed pages.

## Visual QA
- Use `/Users/teamb01/Desktop/Morvi-UI` only as external reference material.
- Do not copy full-page UI images into the project or bundle.
- Check every implemented page against its reference for text, spacing, rounded corners, borders, shadows, gradients, blur, and tab/navigation placement.
- Shared visual effects live in UIKit/CoreAnimation helpers inside `ReferenceCanvasView` and `FloatingDockView`.

## Tabbar Icons
- `画板 15@2x/@3x` -> `tab_home`
- `画板 13@2x/@3x` -> `tab_discover`
- `画板 12@2x/@3x` -> `tab_dialogue`
- `画板 14@2x/@3x` -> `tab_persona`

## Verification
Run:

```sh
xcodebuild -project Morvi.xcodeproj -scheme Morvi -sdk iphonesimulator -configuration Debug build
```
