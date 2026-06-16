# Coding Agent Image

This repository provides a two-image setup for running terminal coding agents, including Claude Code, Pi, Codex CLI, GitHub Copilot CLI, and Gemini CLI, in a container while keeping file ownership aligned with the host user. It also includes Python, `uv`, and the Rust toolchain for isolated utility workflows that use the same mount and user-mapping model.

## Why use this?

Coding agents can be paired with third-party gateways or local model backends, but in those setups the safety properties are not always guaranteed. Running agents inside Docker helps limit the visible filesystem scope to the paths you intentionally mount into the container.

Docker alone is not enough, because the default `root` runtime often causes files created or modified in bind-mounted directories to become owned by `root` on the host. This project solves that by building a user-facing image that mirrors the target host user through `USERNAME`, `UID`, and `GID`.

## How It Works

### Shared base image

The shared base image is built from [Dockerfile.base](./Dockerfile.base). It:

- uses `node:24-trixie-slim`, providing the Node.js runtime needed by npm-installed agents
- installs `bash`, `git`, `sed`, `awk`, `ripgrep`, `ca-certificates`, and `curl`
- installs Python, `uv`, and the Rust toolchain for isolated utility workflows
- installs Claude Code with the official installer
- installs Pi, Codex CLI, GitHub Copilot CLI, and Gemini CLI globally through npm
- copies the real Claude binary into a global location
- exposes `claude`, `pi`, `codex`, `copilot`, and `gemini` on `PATH`
- disables Claude auto-updates through a wrapper

This image is intended to be built in CI and published to GHCR.

### User-facing image

The user-facing image is built from [Dockerfile](./Dockerfile). It:

- builds on top of the published shared base image
- creates a real in-container user from `USERNAME`, `UID`, and `GID`
- creates the matching home directory
- links `claude` under `${HOME}/.local/bin`
- runs agent commands as that created user

## Get The Shared Base Image

If you want to use the shared base image directly, you can pull the published image from GHCR:

```bash
docker pull ghcr.io/ironblood/coding-agent-image-base:latest
```

If you want to build it locally instead, or if an agent version shipped in the CI-built image is outdated:

```bash
docker build -f Dockerfile.base -t coding-agent-image-base:local .
```

## Build The User-Facing Image

Build the user-facing image with host-matching values so files written into bind-mounted directories keep the expected ownership on the host.

```bash
# Use the CI-built shared base image from GHCR by default.
export BASE_IMAGE=ghcr.io/ironblood/coding-agent-image-base:latest

# If you prefer a locally built shared base image instead:
# docker build -f Dockerfile.base -t coding-agent-image-base:local .
# export BASE_IMAGE=coding-agent-image-base:local

export USERNAME=$(id -un)
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

docker build \
  --build-arg BASE_IMAGE=$BASE_IMAGE \
  --build-arg USERNAME=$USERNAME \
  --build-arg UID=$USER_ID \
  --build-arg GID=$GROUP_ID \
  -t coding-agent-image:local .
```

## Run Claude Code

Claude Code expects two configuration paths to be mounted into the created user's home directory:

- `/path/to/.claude`: the Claude configuration directory
- `/path/to/.claude.json`: the Claude configuration file

These should be mounted to `/home/$USERNAME/.claude` and `/home/$USERNAME/.claude.json` inside the container.

### Use Claude with the default Anthropic backend

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.claude:/home/$USERNAME/.claude \
  -v /path/to/.claude.json:/home/$USERNAME/.claude.json \
  coding-agent-image:local claude
```

### Use Claude with a third-party gateway

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.claude:/home/$USERNAME/.claude \
  -v /path/to/.claude.json:/home/$USERNAME/.claude.json \
  -e ANTHROPIC_BASE_URL=http://host-or-gateway:port \
  -e ANTHROPIC_AUTH_TOKEN=your-token \
  coding-agent-image:local claude
```

### Use Claude with a model server running in another container on the same host

On some Linux setups, especially when the model server is reached through another container on the same host, the container may also need `--add-host=host.docker.internal:host-gateway`.

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  --add-host=host.docker.internal:host-gateway \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.claude:/home/$USERNAME/.claude \
  -v /path/to/.claude.json:/home/$USERNAME/.claude.json \
  -e ANTHROPIC_BASE_URL=http://host.docker.internal:port \
  -e ANTHROPIC_AUTH_TOKEN=your-token \
  coding-agent-image:local claude
```

## Run Pi

Pi stores its global user state under `~/.pi/agent`. Mounting `~/.pi` persists its configuration and sessions while leaving room for additional Pi state.

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.pi:/home/$USERNAME/.pi \
  coding-agent-image:local pi
```

## Run Codex CLI

Codex stores its user configuration, authentication, and session state under `~/.codex`. Mount that directory to preserve state between container runs.

On Linux, Codex normally uses its own `bubblewrap`-based sandbox. In an ordinary Docker container, that nested sandbox may not have the required capabilities. When Docker is the intended isolation boundary, the [Codex container guidance](https://developers.openai.com/codex/agent-approvals-security#run-codex-in-dev-containers) recommends running Codex with `--sandbox danger-full-access` inside the container.

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.codex:/home/$USERNAME/.codex \
  coding-agent-image:local codex --sandbox danger-full-access
```

## Run GitHub Copilot CLI

GitHub Copilot CLI stores user settings, credentials, permissions, and sessions under `~/.copilot`. Mount that directory to preserve state between container runs.

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.copilot:/home/$USERNAME/.copilot \
  coding-agent-image:local copilot
```

## Run Gemini CLI

Gemini CLI stores user settings and user-level state under `~/.gemini`. Mount that directory to preserve state between container runs.

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)

docker run --rm -it \
  -e TERM \
  -e COLORTERM \
  -e TERM_PROGRAM \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.gemini:/home/$USERNAME/.gemini \
  coding-agent-image:local gemini
```

## Run Python Or uv

Python and `uv` are included as general utilities. They are not coding agents, but they can reuse the same isolated workspace mount and host-matching user setup.

```bash
export WORKING_DIR=/path/to/working/dir

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  coding-agent-image:local python --version
```

```bash
export WORKING_DIR=/path/to/working/dir

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  coding-agent-image:local uv run python --version
```

## Run Rust

The Rust toolchain is included as a general utility. The shared toolchain is installed globally, while Cargo project state and build outputs stay inside the mounted workspace or the created user's home directory.

```bash
export WORKING_DIR=/path/to/working/dir

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  coding-agent-image:local rustc --version
```

```bash
export WORKING_DIR=/path/to/working/dir

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  coding-agent-image:local cargo test
```

## Notes

- **Persistent config**: mount only the state needed by the agent you run: `~/.claude` and `~/.claude.json` for Claude Code, `~/.pi` for Pi, `~/.codex` for Codex, `~/.copilot` for Copilot, or `~/.gemini` for Gemini.
- **Terminal styling**: forward `TERM`, `COLORTERM`, and `TERM_PROGRAM` so interactive agents can use the terminal capabilities and color support detected on the host.
- **Working directory**: mount the workspace at the same absolute path inside the container as it uses on the host. This keeps path references consistent between the host and the container.
- **Updates**: Claude auto-updates are disabled in the shared base image. To update installed agents, pull or rebuild the shared base image and then rebuild the user-facing image.

## Troubleshooting

- If your model backend is not reachable from inside the container, verify the value of `ANTHROPIC_BASE_URL` from inside the container first:
  `docker run --rm -e ANTHROPIC_BASE_URL=http://host-or-gateway:port -e ANTHROPIC_AUTH_TOKEN=your-token coding-agent-image:local sh -lc 'echo "$ANTHROPIC_BASE_URL"; echo "$ANTHROPIC_AUTH_TOKEN"'`
