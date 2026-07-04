# Local Data Architecture

Morvi uses a local SQLite database stored in Application Support:

`Application Support/Morvi/morvi.sqlite`

The data layer is initialized from `AppDelegate` through `LocalDataStack.prepareIfNeeded()`. Migrations are handled by `LocalDataMigrator`, and first-run static data is inserted by `LocalSeedLoader`.

## Folder Layout

- `Morvi/Sources/Data/Storage`: SQLite connection, migration, bootstrapping, date text helpers.
- `Morvi/Sources/Data/Records`: Plain Swift record structs for database rows.
- `Morvi/Sources/Data/Repositories`: Protocols and SQLite-backed implementations.
- `Morvi/Sources/Data/Seed`: Local seed data for the current static UI.

## Schema

- `account_profile`: profile, avatar, cover, registration detail fields.
- `local_session`: local auth/session state; credentials stay outside SQLite.
- `account_relation`: directional account relationship rows for profile counts and lists.
- `creative_work`: Discover, gallery detail, persona waterfall items, uploaded work.
- `theme_catalog`: Travel, Food, Family, Friends, Lifestyle.
- `work_theme_link`: many-to-many link between works and themes.
- `work_reaction`: reaction rows used for displayed count metrics.
- `work_reply`: replies under works and detail panels.
- `mood_entry`: Home feeling editor and Weekly Feeling data.
- `restricted_relation`: restricted roster list.
- `report_record`: report reason selections and optional detail.
- `credit_account`: local balance value for Wallet.
- `credit_activity`: balance activity ledger.
- `agreement_acceptance`: EULA and privacy acceptance state.
- `dialogue_thread`: ordinary dialogue and AI dialogue list rows.
- `dialogue_entry`: text, image, audio, and AI intro entries.
- `permission_copy`: system permission copy from the built-in information sheet.
- `local_seed_state`: seed batch markers.

## Notes

- Visible UI text remains controlled by the page implementations and reference UI.
- Timeline display text is computed in UI code, not stored in SQLite.
- Dialogue avatar grouping is computed from side, account key, and timeline grouping.
- Media assets are referenced by asset names and dimension metadata so waterfall layouts can calculate cell height.
- Built-in profile images are stored in `Assets.xcassets` with `builtin_avatar_*` names.
- Built-in video files are stored in `Morvi/Media` with `builtin_*.mp4` names and copied into the app bundle.
- The current setup uses the system SQLite C library to avoid network dependency. The repository protocols keep the page layer insulated if this is later replaced by a higher-level SQLite wrapper.
