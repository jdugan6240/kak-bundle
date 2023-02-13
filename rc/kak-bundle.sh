#!/usr/bin/sh

newline='
'

bundle_cd() { # cd to bundle-path; create if missing
    [ -d "$kak_opt_bundle_path" ] || mkdir -p "$kak_opt_bundle_path"
    cd "$kak_opt_bundle_path"
}

setup_load_file() { # Create the plugin load file
    name=$1
    folder="$kak_opt_bundle_path/$name"

    find -L "$folder" -type f -name '*\.kak' | sed 's/.*/source "&"/' > "$kak_opt_bundle_path/$name-load.kak"
    printf "trigger-user-hook bundle-loaded=$name" >> "$kak_opt_bundle_path/$name-load.kak"
}

get_dict_value() { # Retrieves either the installer or post-install hook for a given plugin
    dict=
    case $2 in
        0) dict=$kak_opt_bundle_installers ;; # We're grabbing an installer
        *) dict=$kak_opt_bundle_install_hooks ;; # We're grabbing a post-install hook
    esac
    IFS='🦀'
    found=0
    returned_val=''
    for val in $dict; do
        # If we haven't yet found the key
        if [ $found -eq 0 ]; then
            if [ "$val" = "$1" ]; then found=1; fi
        # We found the key, the next non-blank value is the mapped value
        elif ! [ -z "$val" ]; then
            # Ensure the value isn't another key
            # If it is, then the value mapped to our key is blank and we skipped over it earlier
            IFS=' '
            is_key=0
            for key in $kak_opt_bundle_plugins; do
                if [ "$val" = "$key" ]; then
                    is_key=1
                    break
                fi
            done
            if [ $is_key -eq 0 ]; then returned_val=$val; fi
            break
        fi
    done
    # Whatever the returned value is, print it out
    printf "$returned_val"
}

tmp_dir= tmp_file= tmp_cnt=0
bundle_tmp_new() { # Creates temporary filename
    # Create temp dir if it doesn't exist
    if [ -z "$tmp_dir" ]; then
        tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle.$$.XXXXXX)
        > "$tmp_dir"/.rmme  # safeguard
    fi
    # Create temp filename
    tmp_cnt=$(( tmp_cnt + 1 ))
    tmp_file=$tmp_dir/bundle-"$tmp_cnt.${1:-tmp}"
}

bundle_tmp_log_load() { # args: log-without-ext
    local status log_opt
    # If the 
    if [ -e "$1.running" ]; then
        running=$(( running + 1))
        log_opt=running
        status="%{...$newline}"
    else
        log_opt=finished
        status="%file<$1.log>"
    fi
    printf >&3 'bundle-status-log-load %s %%file<%s.pwd> %%file<%s.cmd> %s\n' "$log_opt" "$1" "$1" "$status" >&3
}

bundle_tmp_log_wait() { # Wait until all jobs have finished
    # Ensure there are jobs to wait for
    [ -n "$tmp_dir" ] || return 0
    # Loop infinitely until all jobs have finished
    while :; do
        set -- "$tmp_dir"/*.job.running; [ $# != 1 ] || [ -e "$1" ] || set --
        [ $# != 0 ] || break
        sleep 1
    done
}

bundle_tmp_clean() { # Remove temp dir
    rm -r $tmp_dir
}

vvc() { # execute command in parallel
    bundle_tmp_new job
    printf '%s\n' "$*" >"$tmp_file".cmd
    printf '%s' "$PWD" >"$tmp_file".pwd

    > "$tmp_file.running"; >"$tmp_file".log
    ( ( "$@" ); rm -f "$tmp_file.running" ) >"$tmp_file".log 2>&1 3>&- &

    set -- "$tmp_dir"/*.job.running; [ $# != 1 ] || [ -e "$1" ] || set --
    [ $# -lt "$kak_opt_bundle_parallel" ] || wait $!
}

post_install_hooks() { # Run post-install hooks of given plugins
    for plugin; do
        hook=$(get_dict_value $plugin 1)
        if ! [ -z "$hook" ]; then
            printf "Running plugin install hook for $plugin\n"
            cd "$kak_opt_bundle_path/$plugin"
            eval "$hook"
            cd "$kak_opt_bundle_path"
        else
            printf "No plugin install hooks for $plugin\n"
        fi
    done
}

bundle_status_init() {
    bundle_tmp_new  # ensure tmp_dir exists
    printf >&3 '%s\n' \
        'edit -scratch *bundle-status*' \
        "set buffer bundle_tmp_dir %<$tmp_dir>" \
        'hook -group bundle-status buffer NormalIdle .* %{ bundle-status-update-hook }'
}
