# Use the official Dev Container base image for Debian Trixie
# We use this instead of plain Debian to get a better development experience out of the box
# as it includes common tools and configurations for development.
FROM mcr.microsoft.com/devcontainers/base:trixie AS base

LABEL org.opencontainers.image.description="Development Container for Swindon Makerspace Access System"

# libparse-debianchangelog-perl \
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    perl \
    cpanminus \
    build-essential \
    # Database drivers
    libdbd-sqlite3-perl \
    libdbd-pg-perl \
    libpq-dev \
    # Libraries for CPAN XS modules
    libexpat1-dev \
    libxml2-dev \
    zlib1g-dev \
    # Core Perl modules from apt
    libalgorithm-diff-perl \
    libalgorithm-diff-xs-perl \
    libalgorithm-merge-perl \
    libcgi-fast-perl \
    libcgi-pm-perl \
    libclass-accessor-perl \
    libclass-isa-perl \
    libencode-locale-perl \
    libfcgi-perl \
    libfile-fcntllock-perl \
    libhtml-parser-perl \
    libhtml-tagset-perl \
    libhttp-date-perl \
    libhttp-message-perl \
    libio-html-perl \
    libio-string-perl \
    liblocale-gettext-perl \
    liblwp-mediatypes-perl \
    libsub-name-perl \
    libswitch-perl \
    libtext-charwidth-perl \
    libtext-iconv-perl \
    libtext-wrapi18n-perl \
    libtimedate-perl \
    liburi-perl \
    libscalar-list-utils-perl \
    libmoose-perl \
    libjson-perl \
    libdata-dump-perl \
    libtry-tiny-perl \
    libdatetime-perl \
    libpath-class-perl \
    libplack-perl \
    libxml-parser-perl \
    libcrypt-des-perl \
    libssl-dev \
    libio-socket-ssl-perl \
    libnet-ssleay-perl \
    ca-certificates \
    && cpanm -n Carton \
    # for Perl::LanguageServer
    && apt-get -y install  --no-install-recommends \
    libanyevent-perl \
    libclass-refresh-perl \
    libio-aio-perl \
    libpadwalker-perl \
    libcoro-perl \
    && cpanm Perl::LanguageServer \
    && rm -rf /var/lib/apt/lists/* /root/.cpanm

# =============================================================================
# DEPS STAGE - Install CPAN dependencies via Carton
# =============================================================================
FROM base AS deps

WORKDIR /workspace

# Copy dependency files first (for better layer caching)
COPY cpanfile cpanfile.snapshot ./

# Create vendor directory structure (for cached install)
COPY vendor/ vendor/

# Install dependencies using cached mode
RUN carton install --cached \
    && rm -rf /root/.cpanm
