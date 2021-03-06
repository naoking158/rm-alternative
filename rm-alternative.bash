#!/usr/bin/env bash
#
#
# ===============
# This is a modified rm program to move SRC to RM_ALT_TRASH instead of remove it.
#
# Usage:
#     $0 [OPTION]... SRC [SRC]...
#
# Options:
#     -h, --help
#     -n, --dry-run
#     -d, --delete  ----  `rm -rf SRC` is executed using `/bin/rm` (Be careful!!!)
#         --restore ----  Restore previously moved files to their original locations.
#                             Previously moved history is saved in RM_ALT_HIST
#
# Default values:
#     RM_ALT_TRASH = ~/.myTrash
#     RM_ALT_HIST  = $RM_ALT_TRASH/.moved_hist
#


set -Ceu
set -o functrace

declare -x RM_ALT_TRASH="${RM_ALT_TRASH:=${HOME}/.myTrash}"
declare -x RM_ALT_HIST="${RM_ALT_HIST:=${RM_ALT_TRASH}/.moved_hist}"

# Avoid split file name with white space
SAVEIFS=IFS
IFS=$(echo -en "\n\b")

function postprocess() {
    export IFS=$SAVEIFS
}
trap postprocess EXIT

function failure() {
    local lineno=$1
    local msg=$2
    echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

function help () {
    awk -v CMD="$(basename $0)" 'NR > 2 {
    if (/^#/) {
        sub("^# ?", "");
        sub("\\$0", CMD);
        sub("Be careful!!!", "\033[31;1m\&\033[0m");
        print }
    else { exit }
    }' $0
    exit 1
}

function e_newline() {
    printf "\n"
}

function e_header() {
    printf " \033[37;1m%s\033[m\n" "$*"
}

function e_important() {
    printf " \033[31;1m%s\033[m\n" "$*"
}

function ink() {
    if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
        echo "Usage: ink <color> <text>"
        echo "Colors:"
        echo "  black, white, red, green, yellow, blue, purple, cyan, gray"
        return 1
    fi

    local open="\033["
    local close="${open}0m"
    local black="0;30m"
    local red="1;31m"
    local green="1;32m"
    local yellow="1;33m"
    local blue="1;34m"
    local purple="1;35m"
    local cyan="1;36m"
    local gray="0;37m"
    local white="$close"

    local text="$1"
    local color="$close"

    if [ "$#" -eq 2 ]; then
        text="$2"
        case "$1" in
            black | red | green | yellow | blue | purple | cyan | gray | white)
            eval color="\$$1"
            ;;
        esac
    fi

    printf "${open}${color}${text}${close}"
}

function e_error() {
    printf " \033[31m%s\033[m\n" "??? $*" 1>&2
}

function die() {
    e_error "$1" 1>&2
    exit "${2:-1}"
}

function move_to_trash() {
    SRC="$1"
    FNAME="$(basename $1)"
    DEST="${RM_ALT_TRASH}/${FNAME}"

    if [[ "${isDryRun:-}" ]]; then
        ink cyan "from"
        ink gray " $(realpath ${SRC})"
        ink cyan " to"
        ink gray " $DEST\n"
    else
        if [[ "${isDelete:-}" ]]; then
            /bin/rm -rf "$SRC"
        else
            # If $DEST file is duplicated, older one is renamed with date.
            [[ -e "$DEST" ]] && { mv "$DEST" "${DEST}-$(date +'%Y%m%d%H%M%S')"; }
            mv "$SRC" "${DEST}"
        fi
    fi
    return 0
}

function safe_rm() {
    [[ "${isDryRun:-}" ]] && { ink cyan "\nBellow files will be moved...\n"; }
    for i in $@; do
        move_to_trash "$i"
    done
    return 0
}

function move_from_trash() {
    DEST="$1"
    FNAME="$(basename $1)"
    SRC="${RM_ALT_TRASH}/${FNAME}"

    ink gray " $DEST\n"
    
    [[ -e "$DEST" ]] && die "$DEST is exist."
    [[ -z "${isDryRun:-}" ]] && mv "$SRC" "$DEST"
    return 0
}

function restore() {
    ink cyan "\nBellow files are restored...\n"
    while read F; do
        [[ "${#F}" > 0 ]] && { move_from_trash "$F"; } 
    done < $RM_ALT_HIST
    e_newline
}


# https://zenn.dev/kawarimidoll/articles/d546892a6d36eb
[[ $# = 0 ]] && help
while (( $# > 0 )); do
    case $1 in
        -h | -help | --help)
            help
            ;;
        -n | --dry-run)
            isDryRun=$1
            ;;
        -d | --delete)
            isDelete=$1
            ;;
        --restore)
            RESTORE=$1
            ;;
        -*)
            e_error "Illegal option -- '$(echo $1 | sed 's/^-*//')'."
            # echo
            # echo "Illegal option -- '$(echo $1 | sed 's/^-*//')'." 1>&2
            help
            ;;
        *)
            if [[ -z ${ARGS:-} ]]; then
                ARGS=("$1")
            else
                ARGS=("${ARGS[@]}" "$1")
            fi
            ;;
    esac
    shift
done

[[ -z ${ARGS:-} && -z ${RESTORE:-} ]] && help

[[ ! -e $RM_ALT_TRASH ]] && mkdir -p $RM_ALT_TRASH

if [[ "${RESTORE:-}" ]]; then
    if [[ "${isDelete:-}" ]]; then
        die "-d/--delete and --restore options cannot be used simultaneously."
    elif [[ -e $RM_ALT_HIST ]]; then
        restore        
    else
        die "You have no removed data."
    fi
else
    safe_rm "${ARGS[@]}" && [[ -z "${isDryRun:-}" ]] && {
        REMOVED_LIST=()
        for i in "${ARGS[@]}"; do
            REMOVED_LIST+="$(realpath $i)\n"
        done
        [[ -z "${isDelete:-}" ]] && {
            echo -e "${REMOVED_LIST[@]}" >| "$RM_ALT_HIST";
        }
    }
fi

[[ "${isDryRun:-}" ]] && { e_important "This is dry run. File are unchanged."; }
exit 0

