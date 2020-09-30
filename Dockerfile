# syntax=docker/dockerfile:1.0.0-experimental

# -------------------------------------------------------------------------
FROM python:3.8-slim
# -------------------------------------------------------------------------
LABEL maintainer="Jeremy Pruitt <jepruitt@aligntech.com>"

ARG VERSION
ARG BUILD_DATE
ARG VCS_REF

# LABELS: label-schema
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.version=$VERSION

LABEL org.label-schema.name="codefresh-pipelines"
LABEL org.label-schema.description="The codefresh pipeline runner can be used to help scaffold new code, push it to a new repo, and connect the repo to a new codefresh pipeline"
LABEL org.label-schema.url="https://src.foo.com/projects/TEAM/repos/codefresh-pipelines"
LABEL org.label-schema.vendor="Team Name"

LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vcs-url="git@src.foo.com:team/codefresh-pipelines"

LABEL org.label-schema.docker.cmd="./runner.sh create-api"
LABEL org.label-schema.docker.cmd.devel="vim Dockerfile"
LABEL org.label-schema.docker.cmd.help="./runner.sh help"
LABEL org.label-schema.docker.cmd.test=""
LABEL org.label-schema.docker.debug=""
LABEL org.label-schema.docker.params=""

LABEL com.foo.com.build-date=BUILD_DATE

ENV COOKIECUTTER_VERSION 1.5.1
ENV STASHY_VERSION 0.6
ENV CLICK_VERSION 7.1.1
ENV PYYAML_VERSION 5.3.1
ENV COLORAMA_VERSION 0.4.3
ENV LOLPYTHON_VERSION 2.0
ENV PYFIGLET_VERSION 0.8.post1
ENV CLI_HELPER_VERSION 0.1.1

WORKDIR /app

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y git gnupg2

# This is necessary to prevent the "git clone" operation from failing
# with an "unknown host key" error.
RUN mkdir -m 700 /root/.ssh; \
  touch -m 600 /root/.ssh/known_hosts; \
  ssh-keyscan src.foo.com > /root/.ssh/known_hosts

RUN pip install --no-cache-dir \
        cookiecutter==$COOKIECUTTER_VERSION \
        stashy==$STASHY_VERSION \
        click==$CLICK_VERSION \
        pyyaml==$PYYAML_VERSION \
        colorama==$COLORAMA_VERSION \
        lolpython==$LOLPYTHON_VERSION \
        pyfiglet==$PYFIGLET_VERSION

RUN --mount=type=ssh pip install --no-cache-dir git+ssh://git@src.foo.com/team/cli-helper.git@$CLI_HELPER_VERSION


WORKDIR /usr/share
RUN git clone https://github.com/xero/figlet-fonts

WORKDIR /app
RUN pyfiglet -L /usr/share/figlet-fonts/Cybermedium.flf

CMD [ "cookiecutter", "--help" ]