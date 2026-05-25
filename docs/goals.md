# Project Goal

This project builds a docker image to run terminal coding agents in an isolated environment with the same user id and group id of the current user from the host system, so that ownership of newly created files and folders still belongs to the current user.

The first supported agent was Claude Code. The next iteration expands the shared base image to support multiple coding agents, initially Claude Code and Pi. The image should stay minimal and only include the agents and utilities needed for supported workflows. At minimum, it shall contain the Claude Code CLI, the Pi CLI, and explicitly install the runtime utilities `bash`, `git`, `sed`, `awk`, and `ripgrep` from the Debian package repository.

These utilities are part of the runtime contract and should be installed explicitly rather than assumed to be present in the base image.

The preferred implementation is to use `debian:bookworm-slim` as the base image and install each supported agent with its official setup method. Claude Code is installed with:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Pi is intended to be installed with:

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

The Claude Code installer has been confirmed to run in a non-interactive image build environment. The Pi installer still needs to be validated in the same build environment.

If that setup path does not work reliably in the image build, an acceptable fallback is to install Claude Code with npm instead. In that fallback case, it is acceptable to switch the base image from `debian:bookworm-slim` to a Node-based image in order to simplify the Node.js/npm setup.

Because the official installer places the `claude` binary under `$HOME/.local/bin` by default, the image shall make `claude` available on a global `PATH` for the runtime user instead of relying only on the build-time home directory layout. For version 1, the shared base image may satisfy this by resolving the real installed binary, copying it into a global location such as `/opt/claude-code/bin/claude`, and exposing `claude` through a stable wrapper on `/usr/local/bin`.

This project is delivered as two images represented by two Dockerfiles. One shared base image contains supported agent installations, global `PATH` exposure, runtime utilities, installation verification, and agent-specific shared launcher behavior such as disabling Claude auto-updates. A second user-facing image builds on top of that base image and contains the runtime configuration that mirrors the target host user.

The shared base image is intended to be buildable in CI and may be published to a container registry such as GHCR. The user-specific image may then use that published base image to avoid rerunning the Claude installer during local development unless the shared base contents change.

This repository tracks both the shared base-image Dockerfile and the reusable user-facing Dockerfile.

To reflect support for multiple agents, the shared base image should be published as `coding-agent-image-base`, and the locally built user-facing image should use the name `coding-agent-image`.

The user-facing image should be built with host-matching `USERNAME`, `UID`, and `GID` values so that files created or modified in bind-mounted directories remain owned by the current host user without requiring later `chown` operations on the host.

The project working directory shall be bind-mounted into the container at the same absolute path that it uses on the host system. The goal is for coding agents to observe and record real host paths rather than rewritten container-only paths such as `/workspace`. This is required because agent configurations and sessions may keep path-based records, and those records should stay understandable and stable when inspected from the host.

The user-facing image should create a real in-container user account and a matching home directory such as `/home/$USERNAME`, and it should run agent commands as that user by default.

Agent configuration paths inside the container should follow that created user's home directory. For Claude Code, both `~/.claude` and `~/.claude.json` shall be made available at their expected locations under that home path. For Pi, `~/.pi` shall be mountable under the same home path; Pi currently stores its default global configuration under `~/.pi/agent` and also supports overriding that directory with `PI_CODING_AGENT_DIR`.

In this project, “isolated environment” means Claude Code should only be able to access files that are intentionally exposed to the container through bind mounts. The purpose is to reduce the impact of malicious or unsafe commands by limiting the visible filesystem scope to the specific project directory and required Claude configuration paths, rather than exposing broad host locations such as the full home directory or the host root filesystem.

The required host paths and environment variables depend on the selected agent and backend. Claude Code workflows may use `~/.claude`, `~/.claude.json`, `ANTHROPIC_BASE_URL`, and `ANTHROPIC_AUTH_TOKEN`. Pi workflows may mount `~/.pi` to persist its `~/.pi/agent` configuration and sessions, together with any provider credentials required by the selected Pi provider.

Because more than one agent is available, the user-facing image should not start a single fixed agent by default. Users shall invoke the intended binary, such as `claude` or `pi`, when running the image.

The runtime example below shows a Claude Code workflow. Other supported agents, such as Pi, may require different configuration mounts or provider environment variables.

The user-facing image should define its in-container user and home path internally from build arguments. Users do not need to pass `HOME` as a runtime environment variable for version 1.

The purpose of that home path is to provide stable locations for agent configuration and user-local launcher paths, including `~/.claude`, `~/.claude.json`, `~/.pi`, and `~/.local/bin/claude`.

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
