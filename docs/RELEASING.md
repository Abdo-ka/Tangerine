# Release process

The current app is a contributor preview. A public source repository can accept
contributions before a production binary release is ready. Never label an ad-hoc
local build as notarized, App Store approved, fully tested, or an exact clone.

## Before tagging

- [ ] `scripts/bootstrap.sh --with-office` succeeds on a fresh checkout.
- [ ] `swift build`, `swift test`, Python integration tests pass.
- [ ] Package with `scripts/build-app.sh`; verify the frozen worker on real fixtures.
- [ ] Run the manual matrix in CONTRIBUTING.md on supported clean Macs.
- [ ] Exercise every documented conversion route; keep fidelity gaps in FEATURES.md.
- [ ] Audit the actual minimum deployment target of every bundled Mach-O binary;
      do not advertise a lower macOS version than the most restrictive dependency.
- [ ] Test cancellation, malformed inputs, large files, low disk space, filenames
      with spaces/Unicode, output collisions and denied file permissions.
- [ ] Test VoiceOver, keyboard focus, multiple monitors, Spaces and Finder behavior.
- [ ] Verify Pages Automation prompts, absence of unexpected network traffic and
      that documents are never uploaded by this app.
- [ ] Set an owned bundle identifier, distribution name, icon, version and support
      contact. This repository is independent of the commercial Tangerine product.
- [ ] Review all dependency licenses and security advisories. Record FFmpeg build
      flags. Reject nonfree builds; include complete notices and corresponding
      sources/source offers for exactly the binaries shipped (including native
      codec libraries, LibreOffice, Python runtime and Python modules).
- [ ] Preserve/sign nested components in dependency order. Ad-hoc `--deep` is only
      a local-development convenience; it is not the release signing procedure.
- [ ] Sign with your own Developer ID identity and hardened runtime, configuring
      Apple Events and Python JIT/library-validation entitlements only as needed.
      Do not commit signing credentials, certificates, passwords or team IDs.
- [ ] Submit to Apple's notary service, inspect the log, staple the ticket, and
      validate with `codesign --verify --deep --strict` and `spctl --assess -vv`.
- [ ] Test the downloaded/notarized ZIP on a clean Mac without Homebrew, Python,
      FFmpeg, LibreOffice, this checkout, or development environment variables.
- [ ] Update CHANGELOG.md; publish source, corresponding-source materials, binary
      checksums and accurate known limitations together.

## Local preview package

```sh
scripts/build-app.sh
codesign --verify --deep --strict dist/Tangerine.app
open dist/Tangerine.app
```

The bundle includes LibreOffice by default. `ALLOW_NO_OFFICE=1` is for development;
such builds do not support all advertised office conversions. `scripts/build-dmg.sh VERSION` creates a verified drag-to-Applications DMG
named `dist/Tangerine-Studio.dmg`, with a custom, Retina-resolution Finder
background. Drag the app on the left into the real Applications shortcut inside
the center wheel. Only the app and Applications shortcut are visible; licenses
remain inside the app bundle.
The layout is generated with pinned build-only dmgbuild dependencies; it requires
no Finder Automation permission. LZMA (ULMO) compression reduces download size without removing engines or formats.
A SHA-256 checksum accompanies the image.
Version, architecture and audited macOS minimum are recorded inside the installer
and must also appear in release notes.

GitHub's macOS CI verifies code and fixture behavior. Release approval remains a
maintainer responsibility, including manual OS integration and license/source audits.

## GitHub drafts and publication

The maintainer repository is https://github.com/Abdo-ka/Tangerine. Push verified
work as coherent commits and update CHANGELOG.md. Do not fabricate a historical
timeline. The maintainer may explicitly request a fresh repository; preserve a
verified Git bundle and source snapshot outside the checkout before that reset. Tagging `vVERSION` runs the installer
workflow and creates a **draft prerelease** with a DMG and checksum; it does not
publish an unaudited binary automatically.
The workflow can also be dispatched manually with an existing preview tag, keeping
the build tied to that tag while retrying infrastructure or dependency downloads.
Native fixtures run on macOS 26 because the older macOS 14 virtual image lacks
Vision’s inference context. Engine fixtures and the format matrix run on macOS 14.
Both jobs must pass before release packaging starts. Failed checks block the
installer workflow; they are not skipped or converted to success.

Publish the draft after the applicable checklist gates pass. A prerelease may be
ad-hoc signed only when its download page clearly states that it is not notarized,
that Gatekeeper may block launch, and the actual architecture/macOS requirements.
Do not disable Gatekeeper or strip quarantine as part of installation instructions.
Dependency notices and corresponding-source obligations apply to previews too.
Developer ID signing/notarization and clean-machine validation are required before
claiming a broadly supported public release. Available Apple Development identities
are not substitutes for a Developer ID Application identity.
