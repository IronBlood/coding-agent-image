# Project Goal

This project builds a docker image to run terminal coding agents in an isolated environment with the same user id and group id of the current user from the host system, so that ownership of newly created files and folders still belongs to the current user.

The first supported agent was Claude Code. The shared base image has been expanded to support Pi, and the next iteration should add Codex CLI, GitHub Copilot CLI, and Gemini CLI. OpenCode is intentionally out of scope until there is a concrete use case for it. The image should stay minimal and only include agents and utilities needed for supported workflows. At minimum, it shall contain the Claude Code CLI, Pi CLI, Codex CLI, GitHub Copilot CLI, Gemini CLI, and explicitly install the runtime utilities `bash`, `git`, `sed`, `awk`, `ripgrep`, and `fd` from the Debian package repository.

These utilities are part of the runtime contract and should be installed explicitly rather than assumed to be present in the base image. Debian packages `fd` as `fd-find` and exposes the binary as `fdfind`, so the image should provide a compatibility symlink at `/usr/local/bin/fd` for agents that invoke `fd` directly.

The preferred implementation is to use `node:24-trixie-slim` as the shared base image. This keeps a Debian-based image while providing the Node.js and npm runtime required by Pi. Claude Code is installed with its official setup method:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Pi requires Node.js `22.19.0` or newer and npm. Because the selected base image already provides Node.js 24 and npm, Pi is installed directly through the non-interactive npm command used by its official installer:

```bash
npm install -g --ignore-scripts --no-fund --no-audit --loglevel=error --progress=false @earendil-works/pi-coding-agent
```

The Claude Code installer and Pi npm installation have been confirmed to run in a non-interactive image build environment, with both resulting executables available to the user-facing image.

Codex CLI, GitHub Copilot CLI, and Gemini CLI provide npm installation paths compatible with the selected Node.js base image. They should be added with their official package names:

```bash
npm install -g @openai/codex
npm install -g @github/copilot
npm install -g @google/gemini-cli
```

These three installations are intended additions and still require image-build and runtime validation. GitHub Copilot CLI must not be installed with `--ignore-scripts`, because its documented npm installation requires install scripts to remain enabled.

If the Claude Code setup path does not work reliably in the image build, an acceptable fallback is to install Claude Code with npm instead, since the selected base image already provides Node.js and npm.

Because the official installer places the `claude` binary under `$HOME/.local/bin` by default, the image shall make `claude` available on a global `PATH` for the runtime user instead of relying only on the build-time home directory layout. For version 1, the shared base image may satisfy this by resolving the real installed binary, copying it into a global location such as `/opt/claude-code/bin/claude`, and exposing `claude` through a stable wrapper on `/usr/local/bin`. Pi should remain installed through npm's global prefix so that its Node.js runtime and package layout remain intact.

This project is delivered as two images represented by two Dockerfiles. One shared base image contains supported agent installations, global `PATH` exposure, runtime utilities, installation verification, and agent-specific shared launcher behavior such as disabling Claude auto-updates. A second user-facing image builds on top of that base image and contains the runtime configuration that mirrors the target host user.

The shared base image is intended to be buildable in CI and may be published to a container registry such as GHCR. The user-specific image may then use that published base image to avoid rerunning the Claude installer during local development unless the shared base contents change.

This repository tracks both the shared base-image Dockerfile and the reusable user-facing Dockerfile.

To reflect support for multiple agents, the shared base image should be published as `coding-agent-image-base`, and the locally built user-facing image should use the name `coding-agent-image`.

The user-facing image should be built with host-matching `USERNAME`, `UID`, and `GID` values so that files created or modified in bind-mounted directories remain owned by the current host user without requiring later `chown` operations on the host.

The project working directory shall be bind-mounted into the container at the same absolute path that it uses on the host system. The goal is for coding agents to observe and record real host paths rather than rewritten container-only paths such as `/workspace`. This is required because agent configurations and sessions may keep path-based records, and those records should stay understandable and stable when inspected from the host.

The user-facing image should create a real in-container user account and a matching home directory such as `/home/$USERNAME`, and it should run agent commands as that user by default.

Agent configuration paths inside the container should follow that created user's home directory. For Claude Code, both `~/.claude` and `~/.claude.json` shall be made available at their expected locations under that home path. For Pi, `~/.pi` shall be mountable under the same home path; Pi currently stores its default global configuration under `~/.pi/agent` and also supports overriding that directory with `PI_CODING_AGENT_DIR`. For Codex CLI, `~/.codex` shall be mountable to preserve configuration, credentials, and session state, with `CODEX_HOME` available if an alternate state directory is later needed. For GitHub Copilot CLI, `~/.copilot` shall be mountable to preserve settings, credentials, saved permissions, and sessions, with `COPILOT_HOME` available for an alternate location. For Gemini CLI, `~/.gemini` shall be mountable to preserve user settings and user-level state.

In this project, “isolated environment” means coding agents should only be able to access files that are intentionally exposed to the container through bind mounts. The purpose is to reduce the impact of malicious or unsafe commands by limiting the visible filesystem scope to the specific project directory and required agent configuration paths, rather than exposing broad host locations such as the full home directory or the host root filesystem.

The required host paths and environment variables depend on the selected agent and backend. Claude Code workflows may use `~/.claude`, `~/.claude.json`, `ANTHROPIC_BASE_URL`, and `ANTHROPIC_AUTH_TOKEN`. Pi workflows may mount `~/.pi` to persist its `~/.pi/agent` configuration and sessions, together with any provider credentials required by the selected Pi provider. Codex, Copilot, and Gemini workflows may mount `~/.codex`, `~/.copilot`, and `~/.gemini` respectively, together with the authentication or provider environment variables selected by each user.

Because more than one agent is available, the user-facing image should not start a single fixed agent by default. Users shall invoke the intended binary, such as `claude`, `pi`, `codex`, `copilot`, or `gemini`, when running the image.

The runtime example below shows a Claude Code workflow. Other supported agents, such as Pi, may require different configuration mounts or provider environment variables.

The user-facing image should define its in-container user and home path internally from build arguments. Users do not need to pass `HOME` as a runtime environment variable for version 1.

The purpose of that home path is to provide stable locations for agent configuration and user-local launcher paths, including `~/.claude`, `~/.claude.json`, `~/.pi`, `~/.codex`, `~/.copilot`, `~/.gemini`, and `~/.local/bin/claude`.

When a user runs this image, the following files or folders shall be mapped into the container. Consider the following commands as dummy code:

```bash
export WORKING_DIR=/path/to/working/dir
export USERNAME=$(id -un)
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

docker build \
  --build-arg BASE_IMAGE=ghcr.io/owner/coding-agent-image-base \
  --build-arg USERNAME=$USERNAME \
  --build-arg UID=$USER_ID \
  --build-arg GID=$GROUP_ID \
  -t coding-agent-image:local .

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.claude:/home/$USERNAME/.claude \
  -v /path/to/.claude.json:/home/$USERNAME/.claude.json \
  -e ANTHROPIC_BASE_URL=http://host-or-gateway:port \
  -e ANTHROPIC_AUTH_TOKEN=your-token \
  coding-agent-image:local claude
```

For Pi, mount its user state directory and invoke `pi` instead:

```bash
docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.pi:/home/$USERNAME/.pi \
  coding-agent-image:local pi
```

For Codex CLI, GitHub Copilot CLI, or Gemini CLI, mount only the selected agent's user-state directory and invoke that agent:

```bash
docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.codex:/home/$USERNAME/.codex \
  coding-agent-image:local codex

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.copilot:/home/$USERNAME/.copilot \
  coding-agent-image:local copilot

docker run --rm -it \
  -w $WORKING_DIR \
  -v $WORKING_DIR:$WORKING_DIR \
  -v /path/to/.gemini:/home/$USERNAME/.gemini \
  coding-agent-image:local gemini
```
