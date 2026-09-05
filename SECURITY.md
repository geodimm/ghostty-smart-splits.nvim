# Security Policy

## Supported Versions

Security updates are provided only for the latest release series.

| Version        | Supported          |
| -------------- | ------------------ |
| Latest release | :white_check_mark: |
| Older releases | :x:                |

Users should update to the latest available release before reporting a security issue.

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.

Instead, use GitHub's **Report a vulnerability** feature under the repository's **Security** tab to report the issue privately.

Please include, where applicable:

- the affected ghostty-smart-splits.nvim version or commit;
- the Neovim, Ghostty, and macOS versions;
- the relevant plugin and Ghostty key-table configuration;
- steps or a minimal configuration that reproduces the issue;
- any AppleScript error output, with sensitive details removed;
- the potential security impact.

Security issues may include Ghostty actions being sent to an unrelated terminal,
execution of actions or commands that the user did not configure, unsafe
handling of terminal IDs or action arguments, or key-table lifecycle behavior
that affects terminals outside the Neovim session.

Routine navigation errors, unsupported layouts, latency, and stale key tables
after a crash or Ghostty configuration reload are normally bugs rather than
security vulnerabilities unless they produce a concrete security impact.

If the report is accepted, the issue will be investigated and a fix will be prepared before details are publicly disclosed when practical.

If the report is not considered a security vulnerability, the reporter will be informed and the issue may be redirected to the normal GitHub issue tracker.
