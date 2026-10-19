# Contributor and coding-agent guide

Tangerine Studio is an independent, offline macOS file utility. Read README.md,
docs/ARCHITECTURE.md, docs/FEATURES.md and docs/ENGINE.md before changing behavior.

Design work follows [the requested Apple design skill](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md), translated to native SwiftUI/AppKit. See docs/DESIGN.md.

## Working agreements

- Preserve original files. Stage output on the destination volume and publish only
  after success. Never silently overwrite an existing path.
- Keep file content local. Do not add uploads, analytics, remote conversion APIs,
  telemetry or network-dependent processing.
- Keep the native UI responsive: run OCR, conversion and subprocess work outside
  the main actor. Return UI state updates to the main actor.
- Pass subprocess arguments as arrays. Never interpolate user paths, metadata,
  timestamps or JSON into shell commands or AppleScript source.
- Validate archive member paths, reject links/special entries, and bound extraction.
- Do not claim a format or feature is verified without a passing fixture test.
  Record untested behavior honestly in docs/FEATURES.md.
- Keep changes scoped. Preserve the existing visual language and use native APIs
  where they make the user experience better.
- Do not commit generated .app bundles, .venv, .build, sample user files, credentials,
  signing identities, private device identifiers or absolute development paths.
- Dependencies must have pinned versions and compatible redistribution terms.
  Update THIRD_PARTY_NOTICES.md when adding/removing a dependency.
- Agents may work directly on authorized code changes. Do not create, publish or
  upload a release, send messages, or change signing accounts unless requested.

## Commands

```sh
scripts/bootstrap.sh --with-office
swift build
swift test
.venv/bin/python -m unittest discover -s Tests/Python -v
scripts/build-app.sh
open dist/Tangerine.app
```

Use `TANGERINE_SOFFICE=/path/to/soffice` for worker tests when LibreOffice is not
on PATH. Use `TANGERINE_OFFICE_APP=/path/to/LibreOffice.app` when bundling it.

## Verification expectations

- Catalog/UI changes: `swift build` and `swift test`; inspect the actual window.
- Engine changes: relevant tests, then the full Python integration suite.
- Conversion additions: open the result with an independent parser, assert
  contents/dimensions/timing, and hash the original before/after.
- Packaging changes: build the bundle, run its frozen worker on fixtures, verify
  `codesign --verify --deep --strict`, then launch it.
- Interactive file actions and macOS permissions require manual testing. Never
  report those as automated-test passes.
- A failing test must be fixed or reported with a concrete cause. Do not hide a
  failure by weakening assertions or skipping the broken capability.

## Layout

`Sources/Tangerine/` native SwiftUI app, AppKit drag wheel and worker orchestration.
`Resources/engine.py` local conversion engine, bundled with PyInstaller.
`Tests/Swift/` catalog tests; `Tests/Python/` conversion/security tests.
`scripts/` reproducible setup, packaging and verification helpers.
`docs/` architecture, engine API, capabilities and release process.

## Done means

Explain the user-visible change, verification results and remaining limitations.
Update documentation when behavior changes. Public release readiness additionally
requires the manual matrix and release checklist in docs/RELEASING.md.

## Maintainer history and releases

The maintainer repository is `https://github.com/Abdo-ka/Tangerine`. Keep completed
work in coherent conventional commits; update CHANGELOG.md and docs/TIMELINE.md.
Push verified commits when authorized by the maintainer. Never force-push or invent
backdated project history. Release tags trigger a draft DMG workflow. Publication
must follow docs/RELEASING.md, including accurate compatibility and signing claims.
