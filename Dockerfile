ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG USERNAME=claude
ARG UID=1000
ARG GID=1000

ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}

RUN groupadd --gid "${GID}" "${USERNAME}" \
  && useradd \
    --uid "${UID}" \
    --gid "${GID}" \
    --create-home \
    --home-dir "${HOME}" \
    --shell /bin/bash \
    "${USERNAME}" \
  && mkdir -p "${HOME}/.local/bin" \
  && ln -sf /usr/local/bin/claude "${HOME}/.local/bin/claude" \
  && chown -R "${UID}:${GID}" "${HOME}"

USER ${USERNAME}
