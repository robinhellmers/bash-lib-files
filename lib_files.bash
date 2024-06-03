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
                        '-s' '--strictness' 'true' \
                        "Strictness of checking: 'loose' or 'strict' (default)"

is_linux_path()
{
    local path strictness
    _handle_args_is_linux_path "$@"

    if [[ "$strictness" == 'loose' ]]
    then
        # Only check if there exists forward slashes
        [[ "$path" =~ / ]]
        return
    fi

    if [[ -f "$path" ]]
    then
        echo 1
        [[ -d "$(dirname "$path")" ]]
        return
    fi

    [[ -d "$path" ]]
    return
}


_handle_args_is_linux_path()
{
    _handle_args 'is_linux_path' "$@"

    ###
    # Non-flagged arguments
    path="${non_flagged_args[0]}"
    ###

    ###
    # -s, --strictness
    if [[ "$strictness_flag" == 'true' ]]
    then
        strictness="$strictness_flag_value"

        case "$strictness" in
            'loose')
                ;;
            'strict')
                ;;
            '')
                strictness='strict'
                ;;
            *)
                echo_error "Given strictness for is_linux_path() unknown: $strictness"
                ;;
        esac
    fi
    ###
}
