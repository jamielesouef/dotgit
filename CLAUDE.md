# dotgit

A macOS app that makes sure work is never stranded on one Mac. Xcode project at the repo root, Swift 6, SwiftUI, SwiftData.

# Agents

## Claude System Instructions
- Always be highly concise.
- Provide direct answers with minimal explanation.
- Skip conversational filler and pleasantries.
- Don't show code just what has changed.

## Delegation

Delegate to keep raw output out of this context. Never delegate reading a file you are about to edit — read it yourself.

| When | Agent |
|---|---|
| Need locations of code before editing | code-scout |
| Question about how the code behaves | code-inquiry |
| About to change a symbol used outside its file | impact-analyser (before editing) |
| Starting new code that resembles existing code | precedent-finder |
| Running build/test/lint commands | command-runner, then build-log-triage on the logs |
| Any API/SDK/tool detail that may have changed since training | doc-researcher |
| "Why is this like this" / history questions | git-historian |
| Checking a change against acceptance criteria | acceptance-verifier |
| When commit, creating a PR, pushing | git-ops |

Act on agent JSON directly; don't re-run their searches to double-check unless the result is `partial` or `uncertain`.

## Commands

```sh
xcodebuild -project dotgit.xcodeproj -scheme dotgit -destination 'platform=macOS' build
xcodebuild -project dotgit.xcodeproj -scheme dotgit -destination 'platform=macOS' test
```

## Architecture

**Read `docs/templates/README.md` before touching `dotgit/`.** It is the contract the
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
  `dotgit/` join the target automatically — never edit `project.pbxproj`
  to add a file.

## Testing

Swift Testing only. `@Suite("Name", .tags(...))`, `@Test("reads as a sentence")`.
No XCTest. **No UI tests** — this is a project rule, not an oversight.

- Tags come from one catalogue in `dotgitTests/Support/Tags.swift`.
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

The remote is `git@github.per:jamielesouef/dotgit.git`. `github.per` is an SSH alias in `~/.ssh/config` that pins the `jamielesouef` key, so `git push` works whichever `gh` account is active.

`gh` commands that write to the repo (PRs, renames) use the active `gh` account, which on this machine is often `j-lesouef` and gets a 403. Switch, run, then switch back:

```sh
gh auth switch --hostname github.com --user jamielesouef
gh pr create ...
gh auth switch --hostname github.com --user j-lesouef
```

Restore the account even if the command fails. Note `status` is read-only in zsh, so do not use it as a variable name when capturing the exit code.

## Spec

`impliment.yaml` is the V1 specification the macOS app was built against. It is the
source of truth for what the app is meant to do.
