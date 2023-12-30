#!/usr/bin/env bash

function waxwing::monkey_patch_commands_to_record_command_name_only() {
    for func_name in $@; do
        eval "function ${func_name}() { waxwing::write_pipe ${func_name}; }"
    done
}

function waxwing::monkey_patch_commands_to_record_command_name_and_args() {
    for func_name in $@; do
        eval "function ${func_name}() { waxwing::write_pipe ${func_name} "\$@"; }"
    done
}

pipe=waxwing.pipe
function waxwing::clean_pipe() {
    command \rm -f $pipe
}

function waxwing::write_pipe() {
    if [[ ! -f $pipe ]]; then
        command \trap "waxwing::clean_pipe" INT TERM EXIT
    fi
    echo -e "${@//\\/}" >>$pipe
}

function waxwing::read_pipe() {
    contents="$(cat -v $pipe)"
    waxwing::clean_pipe
    echo -e "${contents}"
}

(
    set -euo pipefail
    __PROG__=waxwing


    __WORKDIR__=".${__PROG__}"
    __FILENAME_LOG__="${__PROG__}.log"
    __FILENAME_TRACE__="${__PROG__}.trace"


    function waxwing::__main__() {

        \mkdir -p ${__WORKDIR__}
        (
            local caller_dir=$(pwd)
            cd ${__WORKDIR__}
            (
                export PATH=${caller_dir}:$PATH
                export PS4='${BASH_SOURCE}:${LINENO}: '
                exec 3>${__FILENAME_TRACE__} && BASH_XTRACEFD=3

                set -euTo pipefail -o functrace
                echo "Working Path:  $(realpath ${caller_dir})"
                echo "Search Path:   $(realpath ${caller_dir}/${@})"
                echo ""


                echo "Discovered Tests"
                local collection_test_files=$(waxwing::discover_test_files ${caller_dir} $@)
                for test_file in ${collection_test_files}; do
                    (
                        . ${test_file}
                        echo "    ${test_file#"${caller_dir}/"}"
                        local collection_test_names=$(waxwing::discover_test_funcs)
                        for test_name in ${collection_test_names}; do
                            echo "        ${test_name}"
                        done
                    )
                done
                echo


                for test_file in ${collection_test_files}; do
                    (
                        . ${test_file}
                        local collection_test_names=$(waxwing::discover_test_funcs)
                        for test_name in ${collection_test_names}; do
                            local return_code=0
                            set +e
                            (
                                set -e
                                ${test_name}
                            )  >/dev/null 2>&1
                            return_code=$?

                            local test_id="${test_file#"${caller_dir}/"}::${test_name}"
                            if [[ $return_code == 0 ]]; then
                                printf "\e[1;32mPassed: ${test_id}\e[0m\n"
                            else
                                printf "\e[1;31mFailed: ${test_id}\e[0m\n"
                                set +e
                                (
                                    set -ex
                                    ${test_name}
                                )
                                printf "\e[1;31mFailed: ${test_id}\e[0m\n"
                                exit 1
                            fi
                        done
                    )
                done

            ) | 2>&1 tee ${__FILENAME_LOG__}
        )
    }

    function waxwing::discover_test_files() {
        echo $(find $1/$2 -type f -name "test*.sh")
    }

    function waxwing::discover_test_funcs() {
        echo $(declare -f | grep -o '^test\w*')
    }

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        waxwing::__main__ "$@"
    fi

)
