# homerun

Two independent parts sharing one idea — never leave work stranded on one Mac.

- `cli/` — the `homerun` command line tool. Swift package, macOS 13+, ArgumentParser.
- `desktop/` — the macOS app. Xcode project, Swift 6, SwiftUI, SwiftData.

They share no code. A change to one does not imply a change to the other.

## Commands

```sh
# CLI — must run from cli/, there is no Package.swift at the repo root
cd cli && swift build && swift test

# App
cd desktop
xcodebuild -project homerun-app.xcodeproj -scheme homerun-app -destination 'platform=macOS' build
xcodebuild -project homerun-app.xcodeproj -scheme homerun-app -destination 'platform=macOS' test
```

Both GitHub workflows currently run `swift` from the repo root and therefore fail.
They need `working-directory: cli`. Not yet fixed.

## Architecture

**Read `docs/templates/README.md` before touching `desktop/`.** It is the contract the
code follows, not a suggestion. The short version:

- Layers run Domain ← Data ← Services ← Presentation. Domain imports no SwiftUI.
- State lives in `@MainActor @Observable final class *Service`. No view models, no
  `ObservableObject`, no `@Published`.
- A service exposes **one** derived `loadState` the views switch on exhaustively.
  Never raw `isLoading`/`error`/`items` for a view to recombine.
- A decision a view makes is a **use case**: an `enum` of pure `static func`s in
  `Domain/<Feature>/UseCase/`, unit tested. If a branch needs the app running to
  test, it is still in the view.
- Swift Concurrency only. Typed throws at boundaries. Check `Task.isCancelled`
  around every `await`.
- Exhaustive `switch`, no `default`. Adding an enum case must break the build
  everywhere it matters — this is load-bearing and has caught real bugs.
- `foo == false`, never `!foo`. One type per file. `// MARK: -` per section.
- A `let` that wraps across lines gets a blank line after its closing `)`;
  one-line `let`s stay grouped. `App/AppDependencies.swift` is the reference.
- User-facing copy is `String(localized:)`. Spacing from `AppSpacing`.
- Every view ships `#Preview` variants under `#if DEBUG` — empty, long text, and
  the awkward state, not just the happy path.

Shared workspace membership and app preferences go in SwiftData. Anything specific
to one machine — absolute paths, which repositories are cloned here, tool paths,
workspace root, menu bar preference — goes in `UserDefaults` so it never travels.

## Build settings that change how you write code

- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — you need an explicit
  `import Foundation` in any file using `trimmingCharacters`, `URL`, etc. Missing
  it is a hard error, not a warning.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` — nothing is main-actor by default.
- `SWIFT_STRICT_MEMORY_SAFETY = YES` — C calls like `fnmatch` need `unsafe`.
- `ENABLE_APP_SANDBOX = NO`, deliberately. The app shells out to `git`, `gh`,
  `osascript` and `xcrun` and reads repositories anywhere on disk.
- The Xcode project uses **file-system-synchronized groups**. New files under
  `desktop/homerun-app/` join the target automatically — never edit `project.pbxproj`
  to add a file.

## Testing

Swift Testing only. `@Suite("Name", .tags(...))`, `@Test("reads as a sentence")`.
No XCTest. **No UI tests** — this is a project rule, not an oversight.

- Tags come from one catalogue in `homerun-appTests/Support/Tags.swift`.
- `Stub*` lives in the test target, `Mock*` in the app target under `#if DEBUG`.
- No `sleep`, no polling. To assert on something mid-flight, use the continuation
  gate on `StubGitClient` (`holdSnapshots` / `waitUntilSnapshotRequested` /
  `releaseSnapshots`).
- `ServiceHarness` builds the whole service graph with stubs; prefer it to
  assembling services by hand.
- `ProcessGitClientIntegrationTests` drives **real git** against a repository and
  bare remote in a temp folder. Keep it that way — it has caught parsing bugs the
  stubs could not.

## Traps already hit in this codebase

These cost real time. Do not reintroduce them.

- **Never call `refresh()` to reflect a local mutation.** It re-snapshots every
  repository over git (~10 subprocesses each) and cancels any in-flight refresh
  before assigning, so the change can be lost entirely. Add, remove and update all
  mutate `repositories` in place and are synchronous. This bug was fixed three
  separate times before the pattern stuck.
- **No `HSplitView`.** It bridges to `NSSplitView` and does not reliably pass
  invalidation to its children — rows rendered half-drawn and removals did not
  appear until you navigated away and back. Use `HStack` + `Divider`.
- **No `.fileImporter` / `.fileExporter`.** Stacked with the sheets already on a
  screen they stop presenting after first use. Go through `FilePanelPresenting`
  (`NSOpenPanel` / `NSSavePanel`), which is injectable and works every time.
- **Avoid piling presentation modifiers on one view.** Sheets, alerts, confirmation
  dialogs and file pickers on the same view compete.
- **Services must not import SwiftUI.** Animation is a view concern — key
  `.animation(_:value:)` on row identities, not on the rows themselves, so a
  background status refresh does not make the list wobble.
- **`@Entry` defaults are read from a nonisolated context.** An existential in the
  app graph needs `: Sendable` on its protocol.
- **Typed-throws closures need annotating** at the call site:
  `store { () throws(PersistenceError) in ... }`.
- **`accessibilityReduceMotion` is read-only** in `EnvironmentValues`, so that
  branch cannot be exercised in a `#Preview`.
- **Never use SwiftData's default store location.** Unsandboxed, it is the shared
  `~/Library/Application Support/default.store`, which other processes (e.g.
  `icloudmailagent`) migrate to their own model — silently wiping the workspace.
  `ModelContainerFactory.storeURL` puts it under the bundle identifier.
- Adding a non-optional field to `WorkspaceManifestEntry` breaks decoding of every
  manifest written before it. New manifest fields are optional and merge as
  `newValue ?? existing`.

## iCloud

The SwiftData models are CloudKit-safe (defaults or optionals, no unique
constraints, no relationships) and `ModelContainerFactory` asks for a private
database when the `HRCloudKitContainerIdentifier` Info.plist key is present. The
key is unset because enabling it needs a development team and a registered
container, so the app currently uses a local store. Do not add the entitlement
without both, or the build stops signing.

## Git

Default branch is `main`; work happens on feature branches.

Commit messages are prose that explain **why**, not bullet lists of what changed.
Lead with the problem, then the fix, then anything surprising. Match the existing
log.

Pushing needs care: the repo is `jamielesouef/homerun` but the active `gh` account
on this machine is often `j-lesouef`, and the remote is HTTPS so git takes the
active account's token — giving a 403. Switch, push, then switch back:

```sh
gh auth switch --hostname github.com --user jamielesouef
git push
gh auth switch --hostname github.com --user j-lesouef
```

Restore the account even if the push fails. Note `status` is read-only in zsh, so
do not use it as a variable name when capturing the exit code.

## Spec

`impliment.yaml` is the V1 specification the macOS app was built against. It is the
source of truth for what the app is meant to do.
