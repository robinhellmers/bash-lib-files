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

register_help_text 'generate_unique_filename' \
"generate_unique_filename <base_path> <suffix>

Generates unique filenames based on naming template '<base_path><suffix><num>'
where it counts <num> from 1 upwards. Using the first, non-existing filename
based on the files in the filesystem.

Arguments:
<base_path>:
    Path including filename. Excluding suffix.
<suffix>:
    Suffix to be used with an number after it to make it unique.
    That is <suffix><num> whereas the <num> will be generated.

Example:
    <base_path>: \"\$HOME/myfile.sh\"
    <suffix>: '.backup-'

    Which generates files in the style
        \$HOME/myfile.sh.backup-3
"

register_function_flags 'generate_unique_filename' \
                        '-m' '--max-backups' 'true' \
                        "Maximum number of backups. (Default: 100)"

# Function to generate a unique filename
generate_unique_filename()
{
    local base_path suffix path_os_type max_backups
    _handle_args_generate_unique_filename "$@"

    return_code=255

    local counter=1
    local file_exists='true'

    until [[ "$file_exists" == 'false' ]]
    do
        if (( counter > max_backups ))
        then
            return_code=1
            echo_error "Maximum number of backups for '${base_path}${suffix}': $max_backups"
            return 1
        fi

        new_path="${base_path}${suffix}${counter}"
        ((counter++))

        case "$path_os_type" in
            'windows')
                [[ -f "$(wslpath -u "$new_path")" ]] || file_exists='false'
                ;;
            'linux')
                [[ -f "$new_path" ]] || file_exists='false'
                ;;
            *)
                ;;
        esac
    done

    return_code=0
    generated_filename="$new_path"
}

_handle_args_generate_unique_filename()
{
    _handle_args 'generate_unique_filename' "$@"

    ###
    # Non-flagged arguments
    base_path="${non_flagged_args[0]}"
    suffix="${non_flagged_args[1]}"

    local base_path_dir="$(dirname "$base_path")"

    if [[ -z "$base_path" ]]
    then
        invalid_function_usage 2 'generate_unique_filename' \
            "Given <base_path> is empty."
        exit 1
    elif [[ -z "$suffix" ]]
    then
        invalid_function_usage 2 'generate_unique_filename' \
            "Given <suffix> is empty."
        exit 1
    fi

    path_os_type=''

    if is_windows_path "$base_path"
    then
        local base_path_linux_style="$(wslpath -u "$base_path")"
        if ! [[ -f "$base_path_linux_style" ]] &&
           ! [[ -d "$(dirname "$base_path_linux_style")" ]]
        then
            invalid_function_usage 2 'generate_unique_filename' \
                "Directory/file of given base path does not exist: '$(dirname "$base_path_linux_style")'"
            exit 1
        fi

        path_os_type='windows'

    elif is_linux_path --directory "$base_path_dir"
    then
        if ! is_linux_path --directory "$base_path_dir" --exists
        then
            invalid_function_usage 2 'generate_unique_filename' \
                "Directory of given base path does not exist: '$base_path_dir'"
            exit 1
        fi

        path_os_type='linux'

    else
        invalid_function_usage 2 'generate_unique_filename' \
            "Could not recognize <base_path> as a Linux or Windows path: $base_path"
        exit 1
    fi

    ###

    ###
    # Flags
    max_backups=100

    if [[ "$max_backups_flag" == 'true' ]]
    then
        local regex_number='^[0-9]+$'

        if ! [[ $max_backups_flag_value =~ $regex_number ]] ||
             (( max_backups_flag_value <= 0 ))
        then
            invalid_function_usage 2 'generate_unique_filename' \
                "Given max backups value (-m/--max-backups) is not an positive integer: '$max_backups_flag_value'"
            exit 1
        fi

        max_backups="$max_backups_flag_value"
    fi
    ###
}
