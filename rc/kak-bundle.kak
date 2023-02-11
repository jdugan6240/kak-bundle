declare-option -docstring %{
    git clone options (defaults: single-branch, depth=1)
} str bundle_git_clone_opts '--single-branch --depth=1'
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

declare-option -hidden str-list bundle_plugins
declare-option -hidden str bundle_path "%val{config}/bundle"

declare-option -hidden str bundle_src "%val{source}"

declare-option -hidden str bundle_log_running
declare-option -hidden str bundle_log_finished
declare-option -hidden str bundle_tmp_dir

declare-option -hidden str-list bundle_plugins_to_install

# Highlighters

hook global WinSetOption filetype=kak %{
    try %{
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-clean|bundle-install|bundle-customload|bundle-noload|bundle)\s' 0:keyword
    } catch %{
        echo -debug "Error: kak-bundle: can't declare highlighters for 'kak' filetype: %val{error}"
    }
}

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
    try %{
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
    try %{
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
    try %{
        bundle-add-install-hook %arg{1} %arg{4}
    }
}

define-command bundle-clean -params .. -docstring %{
    bundle-clean [plugins] - Uninstall selected plugins (or all registered plugins if none selected)
} -shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do printf "$plugin\n"; done
} %{
    evaluate-commands %sh{
        [ $# != 0 ] || eval set -- "$kak_quoted_opt_bundle_plugins"
        for plugin; do
            rm -rf "$kak_opt_bundle_path/$plugin" "$kak_opt_bundle_path/$plugin-load.kak"
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
        . $(echo "${kak_opt_bundle_src%%.kak}.sh")
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        # "$kak_opt_bundle_git_clone_opts"

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
                (*) eval "vvc git clone $kak_opt_bundle_git_clone_opts \"\$installer\"" ;;
            esac
        done
        bundle_tmp_log_wait
        > "$tmp_dir"/.done
        ) >/dev/null 2>&1 3>&- &
    }
}

# Install UI

define-command bundle-run-install-hooks %{
    delete-buffer *bundle-status*
    evaluate-commands %sh{
        set -u
        . $(echo "${kak_opt_bundle_src%%.kak}.sh")
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        # "$kak_opt_bundle_git_clone_opts"
        fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
        output=$fifo_tmp_dir/fifo
        mkfifo "$output"
        ( {
            printf '%s\n' 'Running post-install hooks'
            eval set -- "$kak_opt_bundle_plugins_to_install"
            post_install_hooks $@
            printf '\n %s\n' 'Post-install hooks complete; press <ESC> to dismiss'
          } > "$output" 2>&1 & ) > /dev/null 2>&1 < /dev/null
        printf '%s\n' \
            "edit! -fifo ${output} -scroll *bundle-install-hooks*" \
            'map buffer normal <esc> %{: delete-buffer *bundle-install-hooks*<ret>}' \
            "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
    }
}

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

define-command bundle-status-update-hook -params .. -docstring %{
} %{
    evaluate-commands -- %sh{
        set -u; exec 3>&1 1>&2
        . $(echo "${kak_opt_bundle_src%%.kak}.sh")
        # "$kak_command_fifo"
        # "$kak_response_fifo"
        # "$kak_opt_bundle_verbose"
        # "$kak_opt_bundle_path"
        # "$kak_opt_bundle_parallel"
        # "$kak_quoted_opt_bundle_loaded_plugins"
        tmp_dir=$kak_opt_bundle_tmp_dir
        printf >&3 '%s\n' 'buffer *bundle-status*'

        printf >&3 'set buffer bundle_log_%s ""\n' finished running  # clear log vars
        running=0
        set -- "$tmp_dir"/*.job.log
        for log; do
            ! [ -e "$log" ] || bundle_tmp_log_load "${log%.log}" >&3
        done
        printf >&3 '%s\n' "bundle-status-log-show $running"
        if [ -e "$tmp_dir/.done" ]; then
            for plugin in $kak_opt_bundle_plugins_to_install; do
                setup_load_file $plugin
            done
            # Indicate that install is done
            printf >&3 '%s\n' \
                'rmhooks buffer bundle-status' \
                'map buffer normal <esc> %{: bundle-run-install-hooks<ret>}' \
                'exec %{ge} %{o} %{DONE (<} %{esc} %{> = dismiss)} %{<esc>}' \
                'nop -- %sh{
                    set -- "$kak_opt_bundle_tmp_dir"
                    if [ -n "$1" ] && [ -e "$1"/.rmme ]; then rm -Rf "$1"; fi
                }' \
                'set buffer bundle_tmp_dir %{}'
        fi
    }
    hook -once -group bundle-status buffer NormalIdle .* %{
        exec HLHL
    }  # re-trigger
} -hidden
