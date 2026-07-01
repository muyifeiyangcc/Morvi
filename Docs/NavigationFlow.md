# Morvi Navigation Flow

This document records the current page flow implemented in UIKit.

## Flow Containers

- App root: `FlowShellController`
- Main flow root: `RootTabsController`
- Login/auth pages live in a separate auth `FlowShellController` that is presented from the bottom after an authentication-required action.
- Visible system navigation bars are hidden. All visible top controls are custom layers.
- Main tabs are rendered by `FloatingDockView`, not by `UITabBarController`.

## App Entry

```mermaid
flowchart TD
    Launch["LaunchScreen.storyboard"] --> Main["主流程: 首页 tab"]
    Main -->|Sensitive action| AccessGate["登录弹窗 overlay"]
    AccessGate -->|Cancel| Main
    AccessGate -->|Log in| AuthNav["登录导航 modal"]
    AuthNav --> Entry["登录注册页"]
    Entry -->|Login by email| SignIn["登录页"]
    Entry -->|I'm new| SignUp["注册"]
    Entry -->|Sign up text| SignUp
    Entry -->|User Agreement / Privacy Policy| EULA["EULA"]
    SignIn -->|Log in| Main["主流程: 首页 tab"]
    SignIn -->|Forgot ?| ResetAccess["忘记密码"]
    SignUp -->|Sign up| Main
    ResetAccess -->|Next| SignIn
```

- App launch enters the main flow directly.
- Login/access popup cards are overlays on top of the current main-flow page.
- Tapping `Log in` in the popup closes the overlay and presents a separate auth navigation flow from the bottom.
- The auth navigation root is `EntrySceneController`, so the first presented page is the login/register entry screen.
- Successful auth dismisses the modal auth navigation flow and reveals the existing main-flow page underneath.

## Main Tabs

```mermaid
flowchart LR
    Home["首页"] <--> Discover["发现"]
    Discover <--> DialogueList["消息"]
    DialogueList <--> Persona["我的"]
```

The tabbar maps to pages as follows:

| Tab asset | Page |
| --- | --- |
| `tab_home` | `首页` |
| `tab_discover` | `发现` |
| `tab_dialogue` | `消息` |
| `tab_persona` | `我的` |

## Home Page

| Trigger | Destination |
| --- | --- |
| Avatar / top leading area | `个人信息` |
| Save your feelings | `发布今日感受` |
| Discover card | Switches to `发现` tab |
| Recot Bot card | `AI聊天` |

```mermaid
flowchart TD
    Home["首页"] --> PersonalDetail["个人信息"]
    Home --> FeelingEditor["发布今日感受"]
    Home --> Discover["发现 tab"]
    Home --> AssistantDialogue["AI聊天"]
    PersonalDetail -->|Sign up| ProfileEditor["编辑资料"]
    ProfileEditor -->|Upload| BackToPrevious["返回上一页"]
    FeelingEditor -->|Upload| WeeklyFeeling["本周心情"]
    AssistantDialogue -->|Input area| SpendConfirm["支付"]
```

## Discover Page

| Trigger | Destination |
| --- | --- |
| My works add button | `上传作品-未上传主题` |
| First story avatar | `他人主页` |
| First feed media card | `作品` |
| First feed comment area | `评论区` |

```mermaid
flowchart TD
    Discover["发现"] --> UploadEmpty["上传作品-未上传主题"]
    UploadEmpty -->|Upload| UploadFilled["上传作品-输入主题"]
    UploadFilled -->|Upload| GalleryDetail["作品"]
    Discover --> PublicPersona["他人主页"]
    Discover --> GalleryDetail
    Discover --> RepliesPanel["评论区"]
```

## Dialogue Page

| Trigger | Destination |
| --- | --- |
| Any dialogue card | `聊天` |

```mermaid
flowchart TD
    DialogueList["消息"] --> DirectDialogue["聊天"]
    DirectDialogue -->|Voice icon area| VoiceDialogue["聊天-语音"]
    DirectDialogue -->|Top trailing area| RestrictPanel["拉黑"]
```

## Persona Page

| Trigger | Destination |
| --- | --- |
| Settings icon / top trailing area | `设置` |
| Edit Profile button | `编辑资料` |
| Any media tile | `作品` |

```mermaid
flowchart TD
    Persona["我的"] --> Settings["设置"]
    Persona --> ProfileEditor["编辑资料"]
    Persona --> GalleryDetail["作品"]
```

## Settings Page

| Trigger | Destination |
| --- | --- |
| Wallet row | `钱包` |
| Blacklist row | `黑名单` |
| Privacy Policy row | `EULA` |
| User Agreement row | `EULA` |
| Delete account row | `退出登录弹窗` |
| Log out row | `退出登录弹窗` |

```mermaid
flowchart TD
    Settings["设置"] --> Wallet["钱包"]
    Settings --> RestrictedList["黑名单"]
    Settings --> EULA["EULA"]
    Settings --> ExitConfirm["退出登录弹窗"]
    Wallet -->|Recharge option 1| SpendConfirm["支付"]
    Wallet -->|Recharge option 2| CreditShortage["余额不足"]
```

## Detail And Modal Pages

| Source | Trigger | Destination |
| --- | --- | --- |
| `作品` | Comment area | `评论区` |
| `作品` | Top trailing area | `举报` |
| `他人主页` | Media area | `作品` |
| `他人主页` | Top trailing area | `拉黑` |
| `拉黑` | Option area | `拉黑弹窗` |

```mermaid
flowchart TD
    GalleryDetail["作品"] --> RepliesPanel["评论区"]
    GalleryDetail --> ReportPanel["举报"]
    PublicPersona["他人主页"] --> GalleryDetail
    PublicPersona --> RestrictPanel["拉黑"]
    RestrictPanel --> RestrictConfirm["拉黑弹窗"]
```

## Default Back Behavior

- `BaseSceneController` installs a custom top layer on each pushed page.
- The custom leading/back area pops one controller when the navigation stack has more than one controller.
- Modal-style pages in this project are still represented as pushed controllers unless explicitly noted by their route behavior.

## Debug Direct Launch

In DEBUG builds, any `ScenePage.rawValue` can be opened directly with:

```sh
xcrun simctl launch <device-id> com.local.Morvi --scene=<页面名>
```

Example:

```sh
xcrun simctl launch <device-id> com.local.Morvi --scene=首页
```
