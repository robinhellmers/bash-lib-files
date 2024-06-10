#####################
### Guard library ###
#####################
guard_source_max_once() {
    local file_name="$(basename "${BASH_SOURCE[0]}")"
    local guard_var="guard_${file_name%.*}" # file_name wo file extension

    [[ "${!guard_var}" ]] && return 1
    [[ "$guard_var" =~ ^[_a-zA-Z][_a-zA-Z0-9]*$ ]] \
        || { echo "Invalid guard: '$guard_var'"; exit 1; }
    declare -gr "$guard_var=true"
}

guard_source_max_once || return 0

##############################
### Library initialization ###
##############################
init_lib()
{
    # Unset as only called once and most likely overwritten when sourcing libs
    unset -f init_lib

    if ! [[ -d "$LIB_PATH" ]]
    then
        echo "LIB_PATH is not defined to a directory for the sourced script."
        echo "LIB_PATH: '$LIB_PATH'"
        exit 1
    fi

    ### Source libraries ###
    #
    # Always start with 'lib_core.bash'
    source "$LIB_PATH/lib_core.bash" || exit 1
    source_lib "$LIB_PATH/lib_handle_input.bash"
}

init_lib

#####################
### Library start ###
#####################

###
# List of functions for usage outside of lib
#
# - is_windows_path()
# - is_linux_path()
###

register_help_text 'is_windows_path' \
"is_windows_path <path>

Arguments:
<path>:
    Path to check
"

register_function_flags 'is_windows_path'

is_windows_path()
{
    _handle_args 'is_windows_path' "$@"

    local path="$1"
    # Check if path contains backslashes (typically Windows)
    [[ "$path" =~ \\ ]]
}

register_help_text 'is_linux_path' \
"is_linux_path <path>

Checks if path is a Linux path based on the strictness given.

Arguments:
<path>:
    Path to check

Strictness:
'loose':
    Only checks if there exists forward slashes
'strict':
    Actually checks if there is as path
"

register_function_flags 'is_linux_path' \
                        '-d' '--directory' 'false' \
                        "Given path is expected to be a directory. (Default)" \
                        '-f' '--file' 'false' \
                        "Given path is expected to be a file." \
                        '-e' '--exists' 'false' \
                        "Check if given directory/file exists."

is_linux_path()
{
    local path strictness check_if_existing
    _handle_args_is_linux_path "$@"

    if [[ "$check_if_existing" != 'true' ]]
    then
        # Only check if it looks like a linux path, not allowing spaces
        [[ "$path" =~ ^(/[^/ ]*)+/?$ ]]
        return
    fi

    case "$path_type" in
        'file')
            [[ -f "$path" ]]
            return
            ;;
        'directory')
            [[ -d "$path" ]]
            return
            ;;
        *)
            echo_error "Unhandled 'path_type': '$path_type'"
            exit 1
            ;;
    esac
}

_handle_args_is_linux_path()
{
    _handle_args 'is_linux_path' "$@"

    ###
    # Non-flagged arguments
    path="${non_flagged_args[0]}"
    ###

    ###
    # -d, --directory, -f --file
    if [[ "$directory_flag" == 'true' && "$file_flag" == 'true' ]]
    then
        invalid_function_usage 2 'is_linux_path' \
            "Both --directory and --file flags given."
        exit 1
    fi

    path_type='directory'
    if [[ "$file_flag" == 'true' ]]
    then
        path_type='file'
    fi
    ###

    ###
    # -e, --exists
    check_if_existing='false'
    if [[ "$exists_flag" == 'true' ]]
    then
        check_if_existing='true'
    fi
    ###
}
                ;;
        esac
    fi
    ###
}
