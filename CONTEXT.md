# Project context

Deskflow Guard is an independent macOS companion that manages a local log-watching LaunchAgent. The native SwiftUI manager controls the guard and login startup. It does not modify or redistribute Deskflow.

Source of truth: `Sources/Manager.swift`, `Sources/guard.py`, `README.md`. Build using `scripts/build.sh`; tests are in `tests/`.

Keep all user-specific settings, server addresses, runtime logs and generated apps out of source control. No credentials or private session data belong in this repository.
