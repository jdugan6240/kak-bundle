declare-option -docstring %{
    Maximum install jobs to run in parallel
} int bundle_parallel 4

# There's unfortunately not an easy way to create a dictionary that
# contains strings with spaces in POSIX shell. So, essentially what
# we do here is define strings that consist of 🦀 delimited values,
# and have each value follow its key in the list. It's not pretty by
# any means, and requires some nontrivial shell gymnastics, but it works.
# This will obviously break if one of the values contains a 🦀, but it's
# a small price to pay for not requiring bundle-clean to leave behind
# a bunch of installer and post-install-hook files to avoid breaking bundle-install.
declare-option -hidden str bundle_install_hooks
declare-option -hidden str bundle_installers
declare-option -hidden str bundle_cleaners
declare-option -hidden str bundle_updaters

declare-option -hidden str-list bundle_plugins
declare-option -hidden str bundle_path "%val{config}/bundle"

declare-option -hidden str bundle_src "%val{source}"

declare-option -hidden str bundle_log_running
declare-option -hidden str bundle_log_finished
declare-option -hidden str bundle_tmp_dir

declare-option -hidden str-list bundle_plugins_to_install

declare-option -hidden str bundle_sh_code %{
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
            1) dict=$kak_opt_bundle_install_hooks ;; # We're grabbing a post-install hook
            2) dict=$kak_opt_bundle_cleaners ;; # We're grabbing a cleaner
            3) dict=$kak_opt_bundle_updaters ;; # We're grabbing an updater
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
            printf "\n"
        done
        touch "$tmp_dir"/.hooks-done
    }

    bundle_status_init() {
        bundle_tmp_new  # ensure tmp_dir exists
        printf >&3 '%s\n' \
            'edit -scratch *bundle-status*' \
            "set buffer bundle_tmp_dir %<$tmp_dir>" \
            'hook -group bundle-status buffer NormalIdle .* %{ bundle-status-update-hook }'
    }
}

# Highlighters

hook global ModuleLoaded kak %@
    try %$
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-clean|bundle-install|bundle-update|bundle-cleaner|bundle-updater|bundle-install-hook|bundle-customload|bundle-noload|bundle)\s' 0:keyword
        add-highlighter shared/kakrc/bundle_install_hook1 region -recurse '\{' '\bbundle-install-hook\K\h[\w\.]+\K\h%\{' '\}' ref sh 
        add-highlighter shared/kakrc/bundle_install_hook2 region -recurse '\[' '\bbundle-install-hook\K\h[\w\.]+\K\h%\[' '\]' ref sh 
        add-highlighter shared/kakrc/bundle_install_hook3 region -recurse '\(' '\bbundle-install-hook\K\h[\w\.]+\K\h%\(' '\)' ref sh 
        add-highlighter shared/kakrc/bundle_install_hook4 region -recurse '<' '\bbundle-install-hook\K\h[\w\.]+\K\h%<' '>' ref sh 
        add-highlighter shared/kakrc/bundle_cleaner1 region -recurse '\{' '\bbundle-cleaner\K\h[\w\.]+\K\h%\{' '\}' ref sh 
        add-highlighter shared/kakrc/bundle_cleaner2 region -recurse '\[' '\bbundle-cleaner\K\h[\w\.]+\K\h%\[' '\]' ref sh 
        add-highlighter shared/kakrc/bundle_cleaner3 region -recurse '\(' '\bbundle-cleaner\K\h[\w\.]+\K\h%\(' '\)' ref sh 
        add-highlighter shared/kakrc/bundle_cleaner4 region -recurse '<' '\bbundle-cleaner\K\h[\w\.]+\K\h%<' '>' ref sh
        add-highlighter shared/kakrc/bundle_updater1 region -recurse '\{' '\bbundle-updater\K\h[\w\.]+\K\h%\{' '\}' ref sh 
        add-highlighter shared/kakrc/bundle_updater2 region -recurse '\[' '\bbundle-updater\K\h[\w\.]+\K\h%\[' '\]' ref sh 
        add-highlighter shared/kakrc/bundle_updater3 region -recurse '\(' '\bbundle-updater\K\h[\w\.]+\K\h%\(' '\)' ref sh 
        add-highlighter shared/kakrc/bundle_updater4 region -recurse '<' '\bbundle-updater\K\h[\w\.]+\K\h%<' '>' ref sh
    $ catch %$
        echo -debug "Error: kak-bundle: can't declare highlighters for 'kak' filetype: %val{error}"
    $
@

# Internal commands

define-command -hidden bundle-add-installer -params 2 %{
    set-option -add global bundle_installers %arg{1}
    set-option -add global bundle_installers 🦀
    set-option -add global bundle_installers %arg{2}
    set-option -add global bundle_installers 🦀
}
define-command -hidden bundle-add-install-hook -params 2 %{
    set-option -add global bundle_install_hooks %arg{1}
    set-option -add global bundle_install_hooks 🦀
    set-option -add global bundle_install_hooks %arg{2}
    set-option -add global bundle_install_hooks 🦀
}
define-command -hidden bundle-add-cleaner -params 2 %{
    set-option -add global bundle_cleaners %arg{1}
    set-option -add global bundle_cleaners 🦀
    set-option -add global bundle_cleaners %arg{2}
    set-option -add global bundle_cleaners 🦀
}
define-command -hidden bundle-add-updater -params 2 %{
    set-option -add global bundle_updaters %arg{1}
    set-option -add global bundle_updaters 🦀
    set-option -add global bundle_updaters %arg{2}
    set-option -add global bundle_updaters 🦀
}

# HACK to allow comparing strings
define-command -hidden bundle-list-len-eq0 -params 0 nop -override
declare-option -hidden str-list bundle_str_test
define-command -hidden bundle-streq -params .. %{
    set-option global bundle_str_test %arg{1}
    set-option -remove global bundle_str_test %arg{2}
    bundle-list-len-eq0 %opt{bundle_str_test}
} -override

# Commands

define-command bundle -params 2..4 -docstring %{
    bundle <plugin-name> <installer> [config] [post-install code] - Register and load plugin
} %{
    set-option -add global bundle_plugins %arg{1}
    bundle-add-installer %arg{1} %arg{2}
    try %{
        hook global -group bundle-loaded User "bundle-loaded=%arg{1}" %arg{3}
    }
    try %{
        source "%opt{bundle_path}/%arg{1}-load.kak"
    }
    # Kept around for backwards compatibility purposes
    try %{
        bundle-streq %arg{4} ""
    } catch %{
        bundle-add-install-hook %arg{1} %arg{4}
    }
}

define-command bundle-customload -params 3..4 -docstring %{
    bundle-customload <plugin-name> <installer> <loading-code> [post-install code] - Register and load plugin with custom loading logic
} %{
    set-option -add global bundle_plugins %arg{1}
    bundle-add-installer %arg{1} %arg{2}
    try %{
        evaluate-commands %arg{3}
    }
    # Kept around for backwards compatibility purposes
    try %{
        bundle-streq %arg{4} ""
    } catch %{
        bundle-add-install-hook %arg{1} %arg{4}
    }
}

define-command bundle-noload -params 2..4 -docstring %{
    bundle-noload <plugin-name> <installer> - Register plugin without loading 
} %{
    set-option -add global bundle_plugins %arg{1}
    bundle-add-installer %arg{1} %arg{2}
    try %{
        hook global -group bundle-loaded User "bundle-loaded=%arg{1}" %arg{3}
    }
    # Kept around for backwards compatibility purposes
    try %{
        bundle-streq %arg{4} ""
    } catch %{
        bundle-add-install-hook %arg{1} %arg{4}
    }
}

define-command bundle-install-hook -params 2 -docstring %{
    bundle-install-hook <plugin-name> <install-hook> - Define shell code to be run after installing plugin
} %{
    bundle-add-install-hook %arg{1} %arg{2}
}

define-command bundle-cleaner -params 2 -docstring %{
    bundle-cleaner <plugin-name> <cleaner> - Define shell code to be run after uninstalling (cleaning) plugin
} %{
    bundle-add-cleaner %arg{1} %arg{2}
}

define-command bundle-updater -params 2 -docstring %{
    bundle-updater <plugin-name> <cleaner> - Define shell code to be run to update plugin
} %{
    bundle-add-updater %arg{1} %arg{2}
}

define-command bundle-clean -params .. -docstring %{
    bundle-clean [plugins] - Uninstall selected plugins (or all registered plugins if none selected)
} -shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do printf "$plugin\n"; done
} %{
    evaluate-commands %sh{
        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_cleaners"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"

        [ $# != 0 ] || eval set -- "$kak_quoted_opt_bundle_plugins"
        for plugin; do
            rm -rf "$kak_opt_bundle_path/$plugin" "$kak_opt_bundle_path/$plugin-load.kak"
            cleaner=$(get_dict_value $plugin 2)
            printf "echo -debug %s" "$cleaner"
            eval "$cleaner"
        done
    }
}

define-command bundle-install -params .. -docstring %{
    bundle-install [plugins] - Install selected plugins (or all registered plugins if none selected)
} -shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do printf "$plugin\n"; done
} %{
    set-option global bundle_plugins_to_install ""
    evaluate-commands %sh{
        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"

        bundle_status_init
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_opt_bundle_plugins"

        for plugin
        do
            printf "set-option -add global bundle_plugins_to_install %s\n" "$plugin" >&3
        done

        #Install the plugins
        (
        for plugin
        do

            installer=$(get_dict_value $plugin 0)
            rm -Rf "$plugin"
            case "$installer" in
                (*' '*) vvc eval "$installer" ;;
                (*) eval "vvc git clone \"\$installer\"" ;;
            esac
        done
        bundle_tmp_log_wait
        > "$tmp_dir"/.install-done
        ) >/dev/null 2>&1 3>&- &
    }
}


define-command bundle-update -params .. -docstring %{
    bundle-update [plugins] - Update selected plugins (or all registered plugins if none selected)
} -shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do printf "$plugin\n"; done
} %{
    set-option global bundle_plugins_to_install ""
    evaluate-commands %sh{
        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"

        bundle_status_init
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_opt_bundle_plugins"

        for plugin
        do
            printf "set-option -add global bundle_plugins_to_install %s\n" "$plugin" >&3
        done

        #Install the plugins
        (
        for plugin
        do
            bundle_cd
            cd $plugin
            updater=$(get_dict_value $plugin 3)
            if [ -z $updater ]; then
                eval "vvc git pull"
            else
                vvc eval "$updater"
            fi
        done
        bundle_tmp_log_wait
        > "$tmp_dir"/.install-done
        ) >/dev/null 2>&1 3>&- &
    }
}

# Install UI

define-command bundle-status-close %{
    delete-buffer *bundle-status*
} -hidden

define-command bundle-status-log-load -params 4 %{
    buffer *bundle-status*
    evaluate-commands "set -add buffer bundle_log_%arg{1} ""## in <%%arg{2}>: %%arg{3}%%arg{4}"" "
} -hidden

define-command bundle-status-log-show -params 1 -docstring %{
    Show all loaded logs in status buffer
} %{
    buffer *bundle-status*
    evaluate-commands -save-regs dquote %{
        execute-keys %{%"_d}
        set-register dquote %opt{bundle_log_finished}
        execute-keys %{P}
        set-register dquote %opt{bundle_log_running}
        execute-keys %{P}
        set-register dquote "(%arg{1} running)"
        execute-keys %{<a-o>} %{geP}
    }
} -hidden

define-command bundle-install-hook-update-hook -params .. %{
    # Print install hook output into buffer
    evaluate-commands -- %sh{
        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        tmp_dir=$kak_opt_bundle_tmp_dir

        tmp_dir=$kak_opt_bundle_tmp_dir
        printf >&3 '%s\n' 'buffer *bundle-status*'

        printf >&3 'set buffer bundle_log_%s ""\n' finished running  # clear log vars
        running=0
        set -- "$tmp_dir"/*.job.log
        for log; do
            ! [ -e "$log" ] || bundle_tmp_log_load "${log%.log}" >&3
        done
        printf >&3 '%s\n' "bundle-status-log-show $running"

        hook_tmp_file=$tmp_dir/bundle-install-hooks-output

        hook_output=$(cat $hook_tmp_file | sed 's/"/""/g')

        for line in "$hook_output"; do
            printf >&3 '%s\n' \
                "set-register dquote \"$line\"" \
                "exec %{o} %{<esc>} %{p}" \
                "set-register dquote %{}"
        done

        printf >&3 '%s\n' 'exec gh'

    }
    # Determine if the install hooks are done
    evaluate-commands -- %sh{
        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        tmp_dir=$kak_opt_bundle_tmp_dir
        if [ -e "$tmp_dir/.hooks-done" ]; then
            # Indicate that install is done
            printf >&3 '%s\n' \
                'rmhooks buffer bundle-status' \
                'map buffer normal <esc> %{: bundle-status-close<ret>}' \
                'exec %{ge} %{o} %{DONE (<} %{esc} %{> = dismiss)} %{<esc>}' \
                'nop -- %sh{
                    set -- "$kak_opt_bundle_tmp_dir"
                    if [ -n "$1" ] && [ -e "$1"/.rmme ]; then rm -Rf "$1"; fi
                }' \
                'set buffer bundle_tmp_dir %{}' \
                "evaluate-commands -client ${kak_client:-client0} %{ try %{ trigger-user-hook bundle-after-install } }"
        fi
    }
} -hidden

define-command bundle-status-update-hook -params .. -docstring %{
} %{
    evaluate-commands -- %sh{

        set -u; exec 3>&1 1>&2
        eval "$kak_opt_bundle_sh_code"
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_updaters"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        tmp_dir=$kak_opt_bundle_tmp_dir
        printf >&3 '%s\n' 'buffer *bundle-status*'

        printf >&3 'set buffer bundle_log_%s ""\n' finished running  # clear log vars
        running=0
        set -- "$tmp_dir"/*.job.log
        for log; do
            ! [ -e "$log" ] || bundle_tmp_log_load "${log%.log}" >&3
        done
        printf >&3 '%s\n' "bundle-status-log-show $running"
        if [ -e "$tmp_dir/.install-done" ]; then
    for plugin in $kak_opt_bundle_plugins_to_install; do
                setup_load_file $plugin
            done

            # Install is done; remove install hooks
            printf >&3 '%s\n' 'rmhooks buffer bundle-status'

            # Prepare to place output of install hooks in buffer
            printf >&3 '%s\n' 'hook -group bundle-status buffer NormalIdle .* %{ bundle-install-hook-update-hook }'
            printf >&3 '%s\n' 'hook -once -group bundle-status buffer NormalIdle .* %{ exec HLHL }'

            # Now run install hooks
            hook_tmp_file=$tmp_dir/bundle-install-hooks-output
            (
                {
                    printf '%s\n' 'Running post-install hooks'
                    eval set -- "$kak_opt_bundle_plugins_to_install"
                    post_install_hooks $@
                } > $hook_tmp_file 2>&1 &
            ) >/dev/null 2>&1 3>&- &

            printf >&3 '%s\n' 'exec HLHL'
        fi
    }
    hook -once -group bundle-status buffer NormalIdle .* %{
        exec HLHL
    }  # re-trigger
} -hidden
