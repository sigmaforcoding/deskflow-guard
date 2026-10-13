# Verified state

Initial open-source version: 0.1.0, 2026-10-14.

- Swift 6 native manager built with warnings treated as errors on Apple Silicon macOS.
- Seven regression tests cover failure classification and client selection.
- Native manager start/stop and login toggle controls were exercised locally.
- Multi-server GUI connection was exercised: first address failed, second connected; current log classification allowed the intermediate failure.
- Login/logout and intentional network-loss behavior remain untested end to end.

Key behavior: only final `failed to connect to server:` stops the client. Intermediate `failed to connect to server=..., trying next server in list` must continue. A SIGKILL is used to avoid Deskflow's normal-exit restart; see README for tradeoffs.

Before expanding supported versions, verify their log wording and process-exit behavior. The current guard targets all clients using the configured installed executable path; simultaneous instances are not supported.

## Discoverability documentation, 2026-10-14

README now includes concrete Chinese scenarios, bilingual search phrases and English use cases. Repository metadata should describe Deskflow keyboard/mouse sharing, login startup, reconnection loops and log spam. These describe existing behavior, not additional compatibility guarantees. Code is unchanged; no new runtime tests needed for this documentation-only update.
