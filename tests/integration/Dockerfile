# =======================================================================
# tests/integration/Dockerfile
# -----------------------------------------------------------------------
# Runs `install.sh install` non-interactively on a clean Ubuntu image and
# verifies installed tools, idempotency, and uninstall (ADR-0007).
#
# ARG UBUNTU_VERSION: "24.04" / "26.04" / "devel" / "rolling"
# =======================================================================
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    CI=true

# Only what a fresh host needs before agentyard runs: sudo (the image runs
# as root otherwise). agentyard installs ca-certificates / curl itself, but
# fetching the repository requires curl, so the image provides it.
# Ubuntu's own (old) `gh` is preinstalled on purpose: agentyard must replace
# it with the official build (assert-tools.sh checks `gh attestation`).
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl sudo gh \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash testuser \
    && echo 'testuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/testuser \
    && chmod 0440 /etc/sudoers.d/testuser

WORKDIR /workspace
COPY --chown=testuser:testuser . /workspace
USER testuser

ENTRYPOINT ["/workspace/tests/integration/entrypoint.sh"]
