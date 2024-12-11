
FROM mcr.microsoft.com/devcontainers/base:buster

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        perl=5.28.1-6+deb10u1 \
        cpanminus \
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
        libparse-debianchangelog-perl \
        libsub-name-perl \
        libswitch-perl \
        libtext-charwidth-perl \
        libtext-iconv-perl \
        libtext-wrapi18n-perl \
        libtimedate-perl \
        liburi-perl \
        libscalar-list-utils-perl \
        # database support
        libpq-dev \
        sqlite3 \
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

COPY cpanfile* /workspaces/AccessSystem/
COPY vendor/ /workspaces/AccessSystem/vendor/

WORKDIR /workspaces/AccessSystem

RUN groupadd --gid 1001 swmakers \
    && useradd --uid 1001 --gid swmakers --shell /bin/bash --create-home swmakers \
    && chown -R swmakers:swmakers /workspaces/AccessSystem

USER swmakers

RUN carton install --cached
