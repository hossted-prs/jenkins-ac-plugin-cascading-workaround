ARG VERSION=2.8.1

FROM eclipse-temurin:17-jdk as build

ARG VERSION

WORKDIR /srv

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN curl -fsSLO "https://updates.jenkins.io/download/plugins/uno-choice/$VERSION/uno-choice.hpi"

RUN jar -xf uno-choice.hpi WEB-INF/lib/uno-choice.jar && \
    jar -xf WEB-INF/lib/uno-choice.jar org/biouno/unochoice/stapler/unochoice/UnoChoice.js

RUN --mount=source=assets,target=/mnt/assets \
    { \
        echo && \
        cat /mnt/assets/UnoChoice.append.js && \
        echo \
    ; } | \
    tee -a org/biouno/unochoice/stapler/unochoice/UnoChoice.js 1>/dev/null

RUN jar -uf WEB-INF/lib/uno-choice.jar org/biouno/unochoice/stapler/unochoice/UnoChoice.js && \
    jar -uf uno-choice.hpi WEB-INF/lib/uno-choice.jar

FROM scratch

ARG VERSION

COPY --from=build /srv/uno-choice.hpi "/uno-choice_v$VERSION-fixed.hpi"