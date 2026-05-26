# Tasks

## Convention

> Note: this section is maintained by human contributors. Do NOT edit this part or treat this section as real tasks. This section only explained how to mark the state of a task.

- [ ] A task
- [+] An on-going task
- [?] An on-going task which needs human contributors to confirm blocks.
- [x] A finished task

## Task Lists

### Shared Base Image

- [x] Initially use `debian:bookworm-slim` as the base image for the shared Claude image (superseded by the multi-agent base-image switch below).
- [x] Install the Debian runtime utilities required by version 1: `bash`, `git`, `sed`, `awk`, and `ripgrep`.
- [x] Install Claude Code with the official setup method during image build.
- [x] Make the installed `claude` binary available on a global `PATH` instead of leaving it only under `$HOME/.local/bin`.
- [x] Verify the Claude Code installation during image build with `which claude` and `claude --version`.
- [x] Confirm that the official Claude Code installer works reliably and non-interactively in the image build.
- [x] Add a dedicated Dockerfile for the shared base image and move the shared installation steps into it.
- [x] Add or update CI to build the shared base image and publish it to GHCR.

### User-Facing Image

- [x] Add a committed user-facing Dockerfile that builds on the published shared base image.
- [x] Document or encode the base-image reference in the user-facing Dockerfile so it can be adjusted per user.
- [x] Create a real in-container user from `USERNAME`, `UID`, and `GID`.
- [x] Create the matching home directory for the configured in-container user.
- [x] Link `claude` under `${HOME}/.local/bin` and add that path to `PATH`.
- [x] Initially set the user-facing image to start Claude Code as the created user by default (superseded by explicit agent invocation below).
- [x] Build the user-facing image with host-matching `USERNAME`, `UID`, and `GID` values so files created in bind-mounted directories remain owned by the host user.
- [x] Write `README.md` as the end-user manual for building and running the shared base image and the user-facing image.

### Multi-Agent Expansion

- [x] Switch the shared base image to `node:24-trixie-slim` to provide Pi's Node.js and npm runtime.
- [x] Install Pi globally with npm using the non-interactive command provided by its official installer.
- [x] Verify the Pi npm installation during image build and that `pi` is available on a global `PATH`.
- [x] Confirm that Pi does not require any additional launcher relocation, wrapper behavior, or runtime packages in the shared base image.
- [x] Remove the inherited `node` user and group from the shared base image so the user-facing image can reuse a host UID/GID such as `1000:1000`.
- [x] Update the user-facing image so it no longer starts `claude` by default and instead allows the user to invoke an installed agent such as `claude` or `pi`.
- [x] Document Pi configuration persistence through its default `~/.pi/agent` directory and any supported runtime overrides.
- [x] Rename the broader multi-agent image targets to `coding-agent-image-base` and `coding-agent-image` across implementation and user documentation.
- [x] Update the CI workflow and `README.md` after the multi-agent Dockerfile behavior is validated.

### Additional Npm Agents

- [+] Install Codex CLI globally with the official npm package `@openai/codex`.
- [+] Install GitHub Copilot CLI globally with the official npm package `@github/copilot`, without suppressing its installation scripts.
- [+] Install Gemini CLI globally with the official npm package `@google/gemini-cli`.
- [+] Verify that `codex`, `copilot`, and `gemini` are available on a global `PATH` and can report their versions during the shared base-image build.
- [+] Confirm that the three new CLIs remain executable from the non-root user-facing image.
- [ ] Decide how update checks or automatic updates for the newly installed CLIs should be handled in a centrally built shared base image.
- [x] Document the runtime configuration mounts for `~/.codex`, `~/.copilot`, and `~/.gemini` in `README.md`.
- [+] Update the CI workflow to verify the new agents after the shared base and user-facing images are built.
