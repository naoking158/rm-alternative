#!/bin/bash


set -Ceu

readonly ORIGIN=$(pwd)
readonly CMD_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
readonly WORKDIR="${CMD_DIR}/workdir"
[[ -d $WORKDIR ]] || mkdir $WORKDIR

declare -x RM_ALT_TRASH="${WORKDIR}/trash"
declare -x RM_ALT_HIST="${RM_ALT_TRASH}/.moved_hist"

function postprocess() {
    [[ -d "${WORKDIR}" ]] && $(/bin/rm -rf "${WORKDIR}")
    $(cd $ORIGIN)
}
trap postprocess EXIT

function e_header() {
    printf "\n \033[37;1m%s\033[m\n" "$*"
}

function e_arrow() {
    printf " \033[37;1m%s\033[m\n" "➜ $*"
}

function e_done() {
    printf " \033[37;1m%s\033[m...\033[32mOK\033[m\n" "✔ $*"
}


function check_safe_rm() {
    e_header "$FUNCNAME"

    cd $WORKDIR

    cmd="mkdir test-dir"
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="${CMD_DIR}/rm test-dir" &&
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="ls ${RM_ALT_TRASH}/test-dir" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&
    e_done "$FUNCNAME"
}

function check_restore() {
    e_header "$FUNCNAME"

    cd $WORKDIR

    cmd="mkdir test-dir"
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="${CMD_DIR}/rm test-dir" &&
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="rm --restore" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&

    cmd="ls test-dir" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&
    e_done "$FUNCNAME"

    /bin/rm -r test-dir
}

function is_not_exist() {
    if [[ -e $1 ]]; then
        return 1
    else
        return 0
    fi
}

function check_delete() {
    e_header "$FUNCNAME"

    cd $WORKDIR

    cmd="mkdir test-dir"
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="${CMD_DIR}/rm -d test-dir" &&
    e_arrow $cmd &&
    $(eval $cmd) &&
    e_done &&

    cmd="is_not_exist test-dir" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&
    e_done "$FUNCNAME"
}

function check_system_rm_is_called() {
    e_header "$FUNCNAME"
    cd $WORKDIR

    cmd="mkdir test-dir" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&

    echo $(pwd) &&
    cmd="rm -rf test-dir" &&
    e_arrow $cmd &&
    eval $cmd &&
    e_done &&

    e_done "$FUNCNAME"
}

check_safe_rm
check_delete
check_restore
check_system_rm_is_called
