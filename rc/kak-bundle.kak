declare-option -docstring %{
    git clone options (defaults: single-branch, no tags, depth=1)
} str bundle_git_clone_opts '--single-branch --no-tags, --depth=1'
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

declare-option -hidden str bundle_sh_code %{
    set -u; 
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

    bundle_tmp_clean() { # Remove temp dir
        rm -r $tmp_dir
    }

    vvc() { # Run commands in parallel
        bundle_tmp_new job
        > $tmp_file.running
        (
            # Print command to be run (so we can easily tell which output came from what command)
            printf "## in <$(pwd)>: $@"  > $tmp_file.running 2>&1
            # Redirect stdout of command to file
            eval "$@" >> $tmp_file.running 2>&1
            # Only after command finishes do we show the output
            # This makes sure we don't mangle output of different processes
            cat $tmp_file.running
            rm $tmp_file.running
        ) &
        set -- $tmp_dir/*.job.running; [ $# != 1 ] || [ -e "$1" ] || set --
        # If too many jobs are running, wait
        if [ $# -ge $kak_opt_bundle_parallel ]; then wait $!; fi
    }

    post_install_hooks() { # Run post-install hooks of given plugins
        for plugin; do
            hook=$(get_dict_value $plugin 1)
            if ! [ -z "$hook" ]; then
                printf "Running plugin install hook for $plugin"
                cd "$kak_opt_bundle_path/$plugin"
                eval "$hook"
                cd "$kak_opt_bundle_path"
            else
                printf "No plugin install hooks for $plugin"
            fi
        done
    }
}

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
    for plugin in $kak_opt_bundle_plugins; do printf $plugin; done
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
    for plugin in $kak_opt_bundle_plugins; do printf $plugin; done
} %{
    evaluate-commands %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_plugins" "$kak_opt_bundle_installers" "$kak_opt_bundle_install_hooks" "$kak_opt_bundle_path" "$kak_config" "$kak_opt_bundle_parallel"
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_opt_bundle_plugins"

        # Setup fifo
        fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
        output=$fifo_tmp_dir/fifo
        mkfifo "$output"
        ( {
            printf "Installing...\n\n"
            # Install the plugins
            for plugin; do
                installer=$(get_dict_value $plugin 0)
                rm -Rf "$plugin"
                case "$installer" in
                    (*' '*) vvc eval "$installer" ;;
                    (*) vvc git clone $kak_opt_bundle_git_clone_opts "$installer" ;;
                esac
            done
            wait
            # Clear temp directory
            bundle_tmp_clean
            # Setup load files
            for plugin; do
                setup_load_file $plugin
            done
            # Run post-install hooks
            printf "\nRunning post-install hooks...\n"
            post_install_hooks $@
            printf "\nDone. Press <esc> to exit."
            # Try to run the user-defined after-install hook.
            printf '%s\n' "evaluate-commands -client ${kak_client:-client0} %{ try %{ trigger-user-hook bundle-after-install } }" | kak -p "$kak_session"
        } > "$output" 2>&1 & ) > /dev/null 2>&1
        printf '%s\n' \
                "edit! -fifo ${output} -scroll *bundle*" \
                "map buffer normal <esc> %{: delete-buffer *bundle*<ret>}" \
                "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
    }
}
