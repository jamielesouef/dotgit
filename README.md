# dotgit

Never leave work stranded on one Mac.

<p align="center">
  <img src="dotgit/Assets.xcassets/LaunchHero.imageset/dot-hero.png" alt="dotgit" width="480">
</p>

dotgit is a macOS app that watches the git repositories you work in, commits whatever is still uncommitted at the end of the day, pushes it, and tells you what would stop you picking the work up on another Mac.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Building and testing](#building-and-testing)
- [Architecture](#architecture)
- [Known gaps](#known-gaps)
- [Licence](#licence)

## Features

The app opens on **Today**, with **Repositories**, **GitHub Accounts**, **Cleaner** and **Settings** beside it. On launch it runs a startup checklist that shows which tools it found and what it is loading.

### Today

The dashboard: what has work only on this Mac, what has a sync problem, what is genuinely ready to resume, and what is not cloned here. Review and sync everything from one place. The default status filter is set in Settings.

### Repositories

Lists what is tracked with each one's branch, local changes and ahead/behind counts, filterable by dirty, clean, ahead, behind or failed, and sortable. Add a repository with the folder picker or by dropping it on the window; drop a folder that is not itself a repository and dotgit searches inside it and lets you pick which ones to track, skipping folders you have told it to ignore and honouring `.gitignore`. A refresh button re-reads every repository on demand.

The detail pane shows the working tree, recent commits, and per-repository settings: WIP commit prefix, whether to append the time, whether `main` and `master` may be synced, and which GitHub account to prefer.

Linked git worktrees are tracked alongside the repository they belong to, each with its own branch and status, and you can choose which checkout a sync acts on.

Repositories are identified by their remote, with SSH host aliases from `~/.ssh/config` resolved to the real host, so the same repository is recognised on every Mac however its remote is spelt.

### Syncing

Makes a timestamped WIP commit from tracked changes, including deletions, and pushes the current branch. Untracked files are listed but never committed unless you tick them (or select all, or include them by default), and ignored files are never touched. It shows the plan before it does anything, unless you turn confirmation off.

When the remote protects the current branch, dotgit pushes the work to a new `dotgit/<branch>-<timestamp>` branch instead. A diverged branch is reported, never force-pushed. Other branches, unpushed tags and submodule changes are reported rather than acted on. It can ask before creating a branch on the remote.

### Readiness checks

Separates "the current branch is pushed" from "this project could actually be picked up elsewhere", and explains each thing in the way: local-only branches, unpushed tags, submodules needing attention, missing setup instructions, missing configuration templates, and the environment variables the other Mac will need. Variable names travel, values never do.

### Portable workspace

Writes the shared parts of the workspace (repository URLs, preferred relative paths, setup requirements) to a versioned JSON manifest. Load it on another Mac, preview what it would clone, and apply it. Each Mac keeps its own workspace root, so the folder layout does not have to match.

### Resume

Prepares a Mac to continue: clone what is missing, fast-forward what is safe, check out the branch the previous Mac was left on, and flag anything with local changes or divergence instead of touching it. Nothing is merged or rebased. Once a project is ready it can be opened in the application of your choice.

### GitHub Accounts

Lists the accounts `gh` is signed in to, lets a repository prefer one, can check account access before syncing, and can retry a refused push with the other accounts, always putting the account that was active back afterwards, including when every retry failed. It says so plainly when a repository pushes over SSH, where switching accounts changes nothing.

### Cleaner

Shows what simulator runtimes and Derived Data are costing you and removes what you select. Extra Derived Data folders can be added in Settings. It refuses anything inside an Xcode installation, the command line tools or the shared SDK folder.

### Menu bar

A menu bar item carries the overall status, how many repositories have work only on this Mac, and quick access to review, sync and resume. dotgit can keep running in the menu bar when the window closes.

### Maintenance

Settings can remove stale paths on this Mac, drop duplicate entries, and clear tracked repositories either on this Mac only or from the shared workspace. Neither ever deletes repository files.

## Requirements

- macOS 26 and Xcode 26 or newer to build.
- `git` is required.
- `gh` is optional. Without it ordinary git sync still works through your existing git authentication, and only the account features are withheld.

## Repository layout

```
dotgit/               the macOS app sources
dotgitTests/          Swift Testing unit and integration tests
dotgit.xcodeproj      the Xcode project
dotgit.xcworkspace    the project plus docs, for editing the templates in Xcode
docs/                 architecture notes and the code templates the app follows
scripts/              template typechecking for CI
impliment.yaml        the V1 specification the app was built against
```

## Building and testing

```sh
xcodebuild -project dotgit.xcodeproj -scheme dotgit -destination 'platform=macOS' build
xcodebuild -project dotgit.xcodeproj -scheme dotgit -destination 'platform=macOS' test
```

Lint and format are enforced in CI:

```sh
swiftformat --lint .
swiftlint lint --strict
```

There are no UI tests by design. The behaviour lives in the domain, data and service layers and is tested there, including a set of tests that drive real `git` against a repository and bare remote created in a temporary folder.

## Architecture

[`docs/architecture.md`](docs/architecture.md) describes how the app is put together and why: the layers, the protocol seams, the two stores, and the constraints that are deliberate.

Read [`docs/templates/README.md`](docs/templates/README.md) before adding to the app. It is the contract the code follows, not a suggestion: layers run Domain ← Data ← Services ← Presentation, state lives in `@MainActor @Observable` services rather than view models, each service exposes one derived `loadState` the views switch on exhaustively, decisions a view makes are pure use cases that can be tested without launching the app, and concurrency is Swift Concurrency only.

Shared workspace membership and app preferences are held in SwiftData. Anything specific to one machine (absolute paths, which repositories are cloned here, tool locations, the workspace root, the menu bar preference) is kept in `UserDefaults` so it never travels.

## Known gaps

- **iCloud sync is written but switched off.** The SwiftData models are CloudKit-safe and the container asks for a private database when the `HRCloudKitContainerIdentifier` Info.plist key is present. The key is unset, because turning it on needs a development team and a registered iCloud container. Until then the app uses a local store.
- **The app sandbox is off.** It shells out to `git`, `gh`, `osascript` and `xcrun`, and reads repositories anywhere on disk, which a sandboxed app cannot do.
- **The app loads repositories one at a time** when it starts. Adding and removing are immediate, but the initial read will get slower as the list grows.

## Licence

MIT. See [LICENSE](LICENSE).
