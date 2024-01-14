# Update the VARIANT arg in devcontainer.json to pick a Perl version
ARG VARIANT=5
FROM perl:${VARIANT}

# [Option] Install zsh
ARG INSTALL_ZSH="true"
# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"

# Install needed packages and setup non-root user. This section is for the devcontainer setup. Use a separate RUN statement to add project dependencies.
ARG USERNAME=swmaker
ARG USER_UID=1000
ARG USER_GID=$USER_UID
COPY library-scripts/*.sh /tmp/library-scripts/
RUN apt-get update \
    && /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

# [Optional] Uncomment this section to install additional packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        carton \
        libanyevent-perl \
        libclass-refresh-perl \
        libcompiler-lexer-perl \
        libcoro-perl \
        libdata-clone-perl \
        libdata-dump-perl \
        libdatetime-perl \
        libio-aio-perl \
        libjson-perl \
        liblist-moreutils-perl \
        libmoose-perl \
        libpadwalker-perl \
        libscalar-list-utils-perl \
    && cpanm Perl::LanguageServer
    # && cpanm Perl::LanguageServer \
    #     Cache::FastMmap \
    #     Data::Clone \
    #     Data::UUID \
    #     DBD::SQLite \
    #     DBI::Const::GetInfoType

        
        
