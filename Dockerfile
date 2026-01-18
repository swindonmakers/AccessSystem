# Multi-stage Dockerfile for AccessSystem
# Stages: base -> deps -> test -> production

# =============================================================================
# BASE STAGE - System dependencies and Perl packages from apt
# =============================================================================
FROM debian:trixie-slim AS base

LABEL org.opencontainers.image.description="AccessSystem - Swindon Makerspace Access Control"

# Install system Perl and essential apt packages
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
    # Core Perl modules from apt (faster than CPAN)
    libalgorithm-diff-perl \
    libalgorithm-diff-xs-perl \
    libalgorithm-merge-perl \
    libcgi-fast-perl \
    libcgi-pm-perl \
    libclass-accessor-perl \
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
    # XML::Parser from apt (avoids build issues)
    libxml-parser-perl \
    # Crypt::DES from apt (fails to build from CPAN, needed by RapidApp)
    libcrypt-des-perl \
    # SSL/TLS support
    libssl-dev \
    libio-socket-ssl-perl \
    libnet-ssleay-perl \
    ca-certificates \
    # For Carton
    && cpanm -n Carton \
    && rm -rf /var/lib/apt/lists/* /root/.cpanm

WORKDIR /app

# =============================================================================
# DEPS STAGE - Install CPAN dependencies via Carton
# =============================================================================
FROM base AS deps

# Copy dependency files first (for better layer caching)
COPY cpanfile cpanfile.snapshot ./

# Create vendor directory structure (for cached install)
COPY vendor/ vendor/

# Install dependencies using cached mode as per README
RUN carton install --cached \
    && rm -rf /root/.cpanm

# =============================================================================
# TEST STAGE - For running tests
# =============================================================================
FROM deps AS test

# Copy application code
COPY lib/ lib/
COPY t/ t/
COPY root/ root/
COPY script/ script/
COPY sql/ sql/

# Copy test and example configs - test config used as local override
COPY accesssystem_api.conf.example accesssystem_api.conf
COPY accesssystem_api_test.conf accesssystem_api_local.conf

# Copy psgi files
COPY app.psgi accesssystem.psgi ./

# Set environment for tests
ENV CATALYST_HOME=/app
ENV PERL5LIB=/app/local/lib/perl5:/app/lib

# Default command runs tests
CMD ["carton", "exec", "prove", "-I", "lib", "-I", "t/lib", "-r", "t/"]

# =============================================================================
# PRODUCTION STAGE - Slim production image
# =============================================================================
FROM deps AS production

# Copy only what's needed for production
COPY lib/ lib/
COPY root/ root/
COPY script/ script/
COPY app.psgi accesssystem.psgi ./

# Config files should be mounted at runtime
# COPY accesssystem_api.conf accesssystem_api_local.conf ./

# Set environment
ENV CATALYST_HOME=/app
ENV PERL5LIB=/app/local/lib/perl5:/app/lib

# Expose default Catalyst port
EXPOSE 3000

# Default command runs the API server
CMD ["carton", "exec", "perl", "script/accesssystem_api_server.pl", "--port", "3000", "--host", "0.0.0.0"]
