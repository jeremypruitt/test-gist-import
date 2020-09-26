#!/bin/bash -il
set -e
set -o pipefail

# -------------------------------------------------------------------------
# Include external bash libs
# -------------------------------------------------------------------------

DEFAULT_BASH_LIB_DIR="${HOME}/bash-lib"
BASH_LIB_DIR=${BASH_LIB_DIR:-${DEFAULT_BASH_LIB_DIR}}
OUTPUT_HELPER_FILE="$BASH_LIB_DIR/output-helper.sh"
OUTPUT_HELPER_URL="https://gist.githubusercontent.com/jeremypruitt/6b1bcd6bcfbff1daa75624d9d12ac6e5/raw/9d51a75afd4fac32ca4215bd15ac7b0804661671/output-helper.sh"
BRIGHT=`tput bold`; RED=`tput setaf 1`

install_output_helper() { curl --silent "$OUTPUT_HELPER_URL" -o "$OUTPUT_HELPER_FILE"; }

[[ ! -d "$BASH_LIB_DIR" ]] && mkdir -p "$BASH_LIB_DIR"
[[ ! -f "$OUTPUT_HELPER_FILE" ]] && install_output_helper

source "$OUTPUT_HELPER_FILE"


# -------------------------------------------------------------------------
# VARS & INPUT
# -------------------------------------------------------------------------

# Get ARGS
TASK=${1}
ARGS=${@:2}
PWD=$( pwd )
original_dir="${PWD}"
scratch_dir=""

# Formatting
DEFAULT=`tput sgr0`
BRIGHT=`tput bold`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

# Docker
VERSION="0.2.0"
VERSION_FIGLET="2.2.5"
DOCKER_IMAGE="foo/scaffold:${VERSION}"
DOCKER_IMAGE_FIGLET="foo/figlet:${VERSION_FIGLET}"
DOCKER_BIN="docker"
DOCKER_BUILD="${DOCKER_BIN} build"
DOCKER_RUN="${DOCKER_BIN} run"
DOCKER_RUN_IT="${DOCKER_RUN} -it"
DOCKER_INSPECT="${DOCKER_BIN} inspect"

DOCKER_SOCK="-v /var/run/docker.sock:/var/run/docker.sock"
DOCKER_GITCONFIG="-v $HOME/.gitconfig:/root/.gitconfig"
DOCKER_SSHDIR="-v $HOME/.ssh:/root/.ssh"
DOCKER_GNUPGDIR="-v $HOME/.gnupg:/root/.gnupg"
DOCKER_GPG_SOCK="$HOME/.gnupg/S.gpg-agent"

usage() {
    echo "USAGE:"
    echo "  $0 SUBCOMMAND"
    echo ""
    echo "SUBCOMMANDS:"
    echo "  create-api <SCAFFOLD_STACK_NAME>"
    echo "                   Create new repo, scaffold code, and PR new pipeline."
    echo "                   EX: $ $0 create-api python-flask"
    echo ""
    echo "  destroy-api <SCAFFOLD_STACK_NAME>"
    echo "                   Remove repo and pipeline"
    echo "                   EX: $ $0 destroy-api python-flask"
    echo ""
    echo "  check-local-env  Check local env to ensure dependencies met"
    echo "  figlet           Turn text into colored asciiart w/ figlet+lolcat"
    echo "  help             Show this output"
    echo ""

    log rocket "Checking you local env to determine if requriements are met"
    _check_local_env
}

_check_local_env() {
    set +e
    which docker      >/dev/null 2>&1 || MISSING="$MISSING\n  -> docker binary. Install docker desktop here: https://www.docker.com/products/docker-desktop"
    docker image inspect $DOCKER_IMAGE \
                      >/dev/null 2>&1 || MISSING="$MISSING\n  -> docker image $DOCKER_IMAGE. Run './runner.sh build-images' to create the docker image."
    set -e

    if [[ ! -z $MISSING ]]; then
      log error "The following capabilities are missing from your local environment: $MISSING"
    else
      log rocket "All requirements are met. You should be able to use all runner.sh commands."
    fi
}

check_for_ssh_agent() {
  launchd_ssh_agent_regex="^/private/tmp/com.apple.launchd.*/Listeners"

  if [[ "$SSH_AUTH_SOCK" =~ $launchd_ssh_agent_regex ]]; then
    ssh-add -l 2>/dev/null
    ssh_add_rc=$?

    if [[ "$ssh_add_rc" -eq 0 ]]; then
      set +e
      confirm "It looks like you have at least 1 identity loaded in your ssh-agent. Would you prefer to use the ssh-agent to connect with bitbucket? If you say No then we will mount the \$HOME/.ssh directory which includes both the ssh keys and the ssh config file. If you say Yes then we will mount only the SSH agent and the \$HOME/.ssh/config file."
      use_ssh_agent=$?
      set -e

      if [[ $use_ssh_agent == 0 ]]; then
        echo "* TRUE: use_ssh_agent is 0 which means the user confirmed using the SSH agent instead of mounting ssh keys"
        DOCKER_SSH_AUTH="--mount type=bind,src=/run/host-services/ssh-auth.sock,target=/run/host-services/ssh-auth.sock -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock -v $HOME/.ssh/config:/root/.ssh/config"
      fi
    fi
  fi
}

run_figlet() {
  local message="$1"
  $DOCKER_RUN -t --rm --env message="$message" $DOCKER_IMAGE_FIGLET
}

run_lolcat() {
  local message="$1"
  $DOCKER_RUN -t --rm --env message="$message" $DOCKER_IMAGE_FIGLET bash -c "echo $message | lolcat"
}

cleanup() {
  log rocket "cleanup() fired! Contact foo@example.com if you need assistance."
  if [[ $scratch_dir ]]; then
    log clean "Removing scratch dir: $scratch_dir"
    rm -rf "$scratch_dir"
  fi
  log clean "Going back to original dir: $original_dir"
  cd $original_dir
}


_(){ eval "$@" 2>&1 | sed "s/^/   /" ; return "$PIPESTATUS" ;}
# -------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------

case $TASK in

    build-images|build_image)
      ARG_VCS_REF="--build-arg VCS_REF=$( git rev-parse --short HEAD )"
      ARG_BUILD_DATE="--build-arg BUILD_DATE=$( date -u +'%Y-%m-%dT%H:%M:%SZ' )"
      ARG_VERSION="--build-arg VERSION=${VERSION}"

      log info "Building Docker Images"

      log check "Building docker image: $DOCKER_IMAGE_FIGLET"
      ARG_VERSION="--build-arg VERSION=${VERSION_FIGLET}"
      DOCKER_ARGS="$ARG_VCS_REF $ARG_BUILD_DATE $ARG_VERSION"
      DOCKER_BUILD_CMD="$DOCKER_BUILD -t $DOCKER_IMAGE_FIGLET -f Dockerfile.figlet $DOCKER_ARGS ."
      log blank "Docker Command: $DOCKER_BUILD_CMD"
      $DOCKER_BUILD_CMD

      log check "Building docker image: $DOCKER_IMAGE"
      DOCKER_BUILD_SSH="--ssh default=${HOME}/.ssh/bitbucket-for-codefresh.id_rsa"
      DOCKER_ARGS="$ARG_VCS_REF $ARG_BUILD_DATE $ARG_VERSION"
      DOCKER_BUILD_CMD="$DOCKER_BUILD $DOCKER_BUILD_SSH -t $DOCKER_IMAGE -f Dockerfile $DOCKER_ARGS ."
      log blank "Docker Command: DOCKER_BUILDKIT=1 $DOCKER_BUILD_CMD"
      DOCKER_BUILDKIT=1 $DOCKER_BUILD_CMD
    ;;

    figlet|f)
      message="$ARGS"
      if [[ -z $message ]]; then
        log error "Must provide plaintext to convert to ascii-text. EX:"
        log blank "  $ ./runner.sh figlet Example Text"
        exit 1
      fi
      run_figlet "$message"
    ;;
    
    create-api)
      lower_rule
      run_figlet "Create Flask API"
      upper_rule

      log info "This task will do the following to create a new api"
      log indent "Create a bitbucket repo, scaffold code, and PR a codefresh pipeline"
      log indent "Scaffold new code, and PR a codefresh pipeline"
      log indent "Submit PR to add new api pipeline to the codefresh-pipelines repo"
      horizontal_rule

      if [[ "${CREATE_API}" -ne "1" ]]; then
        log error "Must confirm by setting the CREATE_API env var to 1. EX:"
        log blank "$ CREATE_API=1 ./runner.sh create"
        exit 237
      fi

      project_name=$2
      stack_lang_name=""
      if [[ -z $project_name ]]; then
        log error "Must provide one of the following langs/frameworks:"
        log blank "${BRIGHT}${RED}✔ python-flask${DEFAULT}"
        exit 1
      fi
      if [[ $project_name == "python-flask" ]]; then
        stack_lang_name="cookiecutter-flask-restful"
      else
        log error "Must provide a valid lang/framework combination:"
        log blank "${BRIGHT}${RED}✔ python-flask${DEFAULT}"
        exit 2
      fi

      DOCKER_SSH_AUTH="$DOCKER_SSHDIR"
      check_for_ssh_agent

      scratch_dir="$( mktemp -d ${original_dir}/tmp-scaffold-create-api.XXXXXXX )"
      trap cleanup EXIT

      project_name="platform"
      stack_lang_repo_url="git+ssh://git@src.aligntech.com/${project_name}/${stack_lang_name}.git"
      codefresh_repo_url="git+ssh://git@src.aligntech.com/${project_name}/cookiecutter-codefresh-pipeline.git"

      # Generate codefresh and stack lang config files
      DOCKER_SCRATCH_DIR="-v $scratch_dir:$scratch_dir --env scratch_dir=$scratch_dir"
      DOCKER_CMD="$DOCKER_RUN -it --rm -v ${PWD}:/codefresh-pipelines -w /codefresh-pipelines $DOCKER_SCRATCH_DIR"
      $DOCKER_CMD $DOCKER_IMAGE python3 generate-cookiecutter-config-files.py

      # Scaffold codefresh and stack lang
      DOCKER_CMD="$DOCKER_RUN -it --rm $DOCKER_GITCONFIG $DOCKER_SSH_AUTH -v ${PWD}:/codefresh-pipelines -w /codefresh-pipelines $DOCKER_SCRATCH_DIR"
      $DOCKER_CMD $DOCKER_IMAGE cookiecutter $stack_lang_repo_url \
                                             --checkout refactor-hook \
                                             --config-file "${scratch_dir}/stack_lang-config_file.yaml" \
                                             --output-dir "${scratch_dir}" \
                                             --no-input

      $DOCKER_CMD $DOCKER_IMAGE cookiecutter $codefresh_repo_url \
                                             --checkout feature/add-hook-to-create-branch-and-pr \
                                             --config-file ${scratch_dir}/codefresh_pipeline-config_file.yaml \
                                             --no-input
      ;;

    destroy-api)
      lower_rule
      run_figlet "Destroy Flask API"
      upper_rule

      log info "This task will do the following to destroy an existing api:"
      log indent "Ensure the removal of the Flask API bitbucket repo"
      log indent "Ensure the removal of local Flask API codefresh-pipelines branches"
      log indent "Ensure the removal of any related codefresh-pipelines bitbucket PRs"
      log indent "Open a PR in the codefresh-pipelines repo to remove the Flask API pipeline dir"
      horizontal_rule

      if [[ "${DESTROY_API}" -ne 1 ]]; then
        log error "Must confirm by setting the DESTROY_API env var to 1. EX:"
        log blank "$ DESTROY_API=1 ./runner.sh destroy-api"
        exit 237
      fi

      DOCKER_SSH_AUTH="$DOCKER_SSHDIR"
      log check "Checking for presence of SSH agent"
      check_for_ssh_agent

      scratch_dir="$( mktemp -d ${original_dir}/tmp-scaffold-create-api.XXXXXXX )"
      trap cleanup EXIT

      project_name="platform"
      stack_lang_repo_url="git+ssh://git@src.aligntech.com/${project_name}/${stack_lang_name}.git"
      codefresh_repo_url="git+ssh://git@src.aligntech.com/${project_name}/cookiecutter-codefresh-pipeline.git"

      DOCKER_SCRATCH_DIR="-v $scratch_dir:$scratch_dir --env scratch_dir=$scratch_dir"

      log info "Remove the bitbucket repo named ${project_name}/${repo_name}"
      DOCKER_CMD="$DOCKER_RUN -it --rm $DOCKER_GITCONFIG $DOCKER_SSH_AUTH -v ${PWD}:/codefresh-pipelines -w /codefresh-pipelines"
      $DOCKER_CMD $DOCKER_IMAGE python3 delete-bitbucket-repo.py

      log info "Remove any related codefresh-pipelines branches"
      DOCKER_CMD="$DOCKER_RUN -it --rm $DOCKER_GITCONFIG $DOCKER_SSH_AUTH -v ${PWD}:/codefresh-pipelines -w /codefresh-pipelines"
      $DOCKER_CMD $DOCKER_IMAGE python3 remove-codefresh-pipelines-branches.py
      #log indent "Get list of local branches for the codesfresh-pipelines repo"
      #log indent "Determine if local codefresh-pipelines branch exists"
      #log indent "If it exists, then delete the remote branch"

      log info "Create a PR to remove the pipeline configs in the codefresh-pipelines master branch"
      DOCKER_CMD="$DOCKER_RUN -it --rm $DOCKER_GITCONFIG $DOCKER_SSH_AUTH -v ${PWD}:/codefresh-pipelines -w /codefresh-pipelines $DOCKER_SCRATCH_DIR"
      $DOCKER_CMD $DOCKER_IMAGE python3 create-pr-to-remove-pipeline-config-dir.py
      #log indent "TODO: Get all PRs for the codefresh-pipelines repo"
      #log indent "TODO: Determine if there is a PR relevant to the Flask API repo"
      #log indent "TODO: Open a PR in the codefresh-pipelines repo to remove the Flask API pipeline dir"
      ;;

    help)
      usage
      exit 0
      ;;

    *)
      usage
      exit 1
      ;;
esac