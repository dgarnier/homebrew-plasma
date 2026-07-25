# Reproduces the ubuntu-24.04 leg of this tap's CI locally, so Linux-only
# failures can be caught without a ~4 minute round trip through GitHub Actions.
#
# See docker/README.md for usage.
ARG BASE=ghcr.io/homebrew/ubuntu24.04:latest
FROM ${BASE}

# Match the environment set by .github/workflows/tests.yml.
ENV HOMEBREW_NO_SANDBOX_LINUX=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1

# Bake this tap's common dependencies into an image layer so that iterating on
# a formula does not re-pour the whole stack every run. All of these have
# x86_64_linux bottles in homebrew-core, so this is a download, not a build.
ARG PREINSTALL="gcc open-mpi metis scalapack openblas scotch hdf5-mpi fftw gsl"
RUN brew install ${PREINSTALL}

COPY --chown=linuxbrew:linuxbrew run-test.sh /home/linuxbrew/run-test.sh
RUN chmod +x /home/linuxbrew/run-test.sh

ENTRYPOINT ["/home/linuxbrew/run-test.sh"]
