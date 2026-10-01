# Architecture — the macOS app

How `dotgit/` is put together and why. The generic layer contract lives
in [`templates/README.md`](templates/README.md); this describes what dotgit
actually does with it.

## The shape

```
Domain  ←  Data  ←  Services  ←  Presentation
                         ↑
                        App  (composition root)
```

Dependencies point left. Domain knows about nothing else and imports no SwiftUI.
Presentation knows about Services and Domain, never Data. `App` is the only place
that knows about everything, and the only place that reads an ambient global.

| Folder | Holds | Rule of thumb |
| --- | --- | --- |
| `Domain/` | Value types and pure use cases | No I/O, no SwiftUI, no `Date()` |
| `Data/` | Protocols and their real implementations | `Sendable`, never `@MainActor` |
| `Services/` | `@MainActor @Observable` state owners | One derived `loadState` each |
| `Presentation/` | Screens and views | Reads state, calls a use case, applies it |
| `App/` | The object graph | Reads ambient globals once, injects everything |
| `Infrastructure/` | `Mock*` doubles and `PreviewGraph` | `#if DEBUG` only |

## Domain

Plain value types plus `enum`s of `static func`s. Everything here is testable with
no stubs at all, which is why the bulk of the behaviour lives here.

The central type is `TrackedRepository`, which joins three independent facts:

- `shared: WorkspaceRepository` — what every Mac agrees on
- `localPath: URL?` — where it lives *here*, `nil` if not cloned
- `snapshot: GitRepositorySnapshot?` — what git said a moment ago

From those it derives one `RepositoryStatus` that the whole app switches on. A
repository absent from this Mac reads as `.notCloned`, never as removed — that
distinction is the reason the shared and local halves are separate types rather
than one record.

Use cases carry the decisions: `SyncPlanUseCase` decides what a sync would do,
`ReadinessEvaluationUseCase` decides what would stop work continuing elsewhere,
`BranchSyncPolicyUseCase` decides whether a branch may be pushed,
`WIPCommitMessageUseCase` resolves the prefix and timestamp rules,
`RepositoryFilterUseCase` and `RepositorySortUseCase` decide what the list shows.
None of them can be exercised only by launching the app.

## Data

Every outside dependency is a `Sendable` protocol with one real implementation, so
a test can substitute it:

| Protocol | Real implementation | Talks to |
| --- | --- | --- |
| `CommandRunning` | `ProcessCommandRunner` | subprocesses |
| `GitClienting` | `ProcessGitClient` | `git` |
| `GitHubCLIClienting` | `ProcessGitHubCLIClient` | `gh` |
| `RepositoryDiscovering` | `FileSystemRepositoryDiscovery` | the file system |
| `ReadinessChecking` | `GitReadinessChecker` | git + the file system |
| `WorkspaceManifestStoring` | `FileWorkspaceManifestStore` | a JSON file |
| `SharedWorkspaceStoring` | `SwiftDataWorkspaceStore` | SwiftData |
| `LocalSettingsStoring` | `UserDefaultsLocalSettingsStore` | `UserDefaults` |
| `SimulatorRuntimeProviding` | `SimctlRuntimeProvider` | `simctl` |
| `DerivedDataProviding` | `FileSystemDerivedDataProvider` | the file system |
| `RepositorySyncPerforming` | `RepositorySyncEngine` | orchestrates the above |
| `PushFallbackPerforming` | `GitHubAccountPushFallback` | git + gh |
| `FilePanelPresenting` | `AppKitFilePanelPresenter` | `NSOpenPanel` |
| `ProjectOpening` | `WorkspaceProjectOpener` | `NSWorkspace` |
| `Clocking` | `SystemClock` | the clock |

Everything the app learns about a repository arrives through `ProcessGitClient`
running `git` and handing the output to a pure parser — `GitStatusParser`,
`GitBranchParser`, `GitSubmoduleParser`, `GitLogParser`, `GitAheadBehindParser`,
`GitRemoteTagParser`, `GitFailureClassifier`. Splitting the parsers out means the
awkward cases (renames, conflicts, peeled tags, an authentication failure that
looks like a generic error) are tested as string-in value-out, with no subprocess
in sight.

Subprocesses run through `ProcessCommandRunner`, which writes stdout and stderr to
temporary files rather than pipes. Pipes deadlock when both fill; `git diff` output
is easily large enough to do it.

### Two stores, deliberately

`SharedWorkspaceStoring` holds what every Mac should agree on: repository
membership, remote URLs, preferred relative paths, per-repository settings, the
handoff branch and commit. It is SwiftData, CloudKit-ready.

`LocalSettingsStoring` holds everything that must *not* travel: absolute paths,
which repositories are cloned here, resolved tool paths, this Mac's workspace root,
menu bar preference, Derived Data locations. It is `UserDefaults`.

This split is the whole point of the app. Anything added to the shared store has to
be meaningful on a different machine.

## Services

One `@MainActor @Observable final class` per screen. Each owns its state, exposes a
single derived `loadState`, and is the only writer of what it owns.

| Service | Owns |
| --- | --- |
| `SettingsService` | Shared preferences and machine-local settings |
| `OnboardingService` | Tool availability and what that enables |
| `RepositoriesService` | The repository list, discovery, maintenance, readiness |
| `SyncService` | The sync plan, progress and summary |
| `ResumeService` | The resume plan and its execution |
| `WorkspaceService` | Manifest loading, preview and apply |
| `GitHubAccountsService` | `gh` accounts and their association |
| `CleanerService` | Simulator runtimes and Derived Data |

`SettingsService` is the single writer of preferences; every other service reads
its behaviour from there rather than keeping a copy. `RepositoriesService` is the
single source of the repository list; `SyncService` and `ResumeService` take
repositories from it and hand outcomes back, which keeps the dependency one-way.

Loading uses `SingleFlightRefreshing`: `refresh()` cancels the in-flight task,
starts a new one and awaits it, so a test never polls.

### Mutations are in place, not reloads

A local change **never** triggers a full reload. Adding, removing and updating each
mutate the published array directly and are synchronous where nothing is awaited.

This is not premature optimisation. `refresh()` re-snapshots every repository, and
one snapshot is roughly ten subprocesses; with a handful of repositories that is
seconds. Worse, `refresh()` cancels the in-flight refresh and returns before
assigning, so a second interaction during the window could discard the change
outright. Toggles appeared dead, deletions appeared to do nothing, and added rows
arrived late. All the same cause.

Adding is the one case with a genuine wait, because the identifier depends on the
remote. The row is inserted immediately as `.loading` and filled in when the
snapshot arrives.

## Presentation

Views read a service through `@Environment`, call a use case, and apply the result.
Nothing else. `MainSplitView` holds the sidebar and swaps the detail column;
`RootView` shows the launch view while the tool checks run, then onboarding or the
main window.

Injection is one `@Entry` key per service, all resolving to the single hoisted
`AppDependencies.shared` graph, so every read returns the same instance and a
preview can override any of them.

Two things live here that look like they could live deeper but must not:

- **Animation.** Keyed on row identities rather than the rows themselves, so a
  background status refresh redraws without the list wobbling. A service importing
  SwiftUI to call `withAnimation` would invert the layering.
- **File panels.** Driven through `FilePanelPresenting` rather than SwiftUI's
  `.fileImporter`, which stops presenting once other sheets are stacked on the same
  view.

## App

`AppDependencies.makeGraph()` is the only function that reads `ProcessInfo`,
`FileManager.default`, `UserDefaults.standard`, `Bundle.main` or `TimeZone.current`.
It resolves the paths to `git`, `gh`, `osascript` and `xcrun` on this Mac, builds
every real implementation, and hands back an `AppGraph`. Everything below receives
plain values and protocols.

## Testing

351 tests, no UI tests. The layering is what makes that reasonable: the decisions
are in Domain where they need no doubles, and the services are driven through
`ServiceHarness`, which assembles the whole graph from stubs.

`ProcessGitClientIntegrationTests` is the exception that earns its keep — it drives
the real `ProcessCommandRunner` and `ProcessGitClient` against a git repository and
bare remote created in a temporary folder, covering the things a stub cannot prove:
that a deletion is really staged, that an ignored file really is not, that a
diverged push is really refused.

## Deliberate constraints

- **The app sandbox is off.** It shells out to `git`, `gh`, `osascript` and `xcrun`
  and reads repositories anywhere on disk.
- **iCloud is written but not switched on.** The models are CloudKit-safe and
  `ModelContainerFactory` asks for a private database when the
  `HRCloudKitContainerIdentifier` Info.plist key is present. The key is unset
  because enabling it needs a development team and a registered container.
- **Nothing is force-pushed, merged or rebased.** A diverged branch is reported.
  Only the current branch is pushed; other branches, unpushed tags and submodule
  changes are surfaced as readiness issues.
- **Secrets never travel.** The manifest carries required environment variable
  *names* and expected configuration template *paths*, never values.
