# Security policy

The current preview is under active development. Only the latest main branch is
maintained; no production-support guarantee is made for preview builds.

Do not attach private files, credentials, or personal paths to public reports.
If the repository has GitHub private vulnerability reporting enabled, use the
Security tab to report vulnerabilities privately. Otherwise contact a maintainer
through their published profile before sharing exploit details.

Files are processed locally by native frameworks and third-party parsers. Outputs
are staged; failed operations should not publish partial files. Archive paths,
links and entry limits are checked, and subprocesses are invoked without a shell.
This is not a sandbox for actively hostile files. Keep dependencies current and
use OS isolation when evaluating malicious samples.

Conversions do not require network access. Build/setup commands download tools
and dependencies. Apple Pages may perform its own account or application activity.

See docs/RELEASING.md for release dependency/source audits.
