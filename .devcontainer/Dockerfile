# Use the official Dev Container base image for Debian Bookworm
# We use this instead of plain Debian to get a better development experience out of the box
# as it includes common tools and configurations for development.
FROM mcr.microsoft.com/devcontainers/base:bookworm AS base

LABEL org.opencontainers.image.description="Development Container for Swindon Makerspace Access System"

# libparse-debianchangelog-perl \
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        perl \ 
        cpanminus \
        build-essential \
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
    && cpanm -S Carton \
# for Perl::LanguageServer
    && apt-get -y install  --no-install-recommends \
        libanyevent-perl \
        libclass-refresh-perl \
        libdata-dump-perl \
        libio-aio-perl \
        libjson-perl \
        libmoose-perl \
        libpadwalker-perl \
        libscalar-list-utils-perl \
        libcoro-perl \
    && cpanm Perl::LanguageServer \
    && rm -rf /var/lib/apt/lists/*
