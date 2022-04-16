declare-option -docstring %{
    git clone options (defaults: single-branch, no tags)
} str bundle_git_clone_opts '--single-branch --no-tags'
declare-option -docstring %{
    git shallow options (clone & update; defaults: --depth=1)
} str bundle_git_shallow_opts '--depth=1'

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
    bundle_cd() { # cd to bundle-path; create if missing
        [ -d "$kak_opt_bundle_path" ] || mkdir -p "$kak_opt_bundle_path"
        cd "$kak_opt_bundle_path"
    }

    setup_load_file() { # Create the plugin load file
        name=$1
        folder="$kak_opt_bundle_path/$name"

        find -L "$folder" -type f -name '*\.kak' | sed 's/.*/source "&"/' > "$kak_opt_bundle_path/$name-load.kak"
        echo "trigger-user-hook bundle-loaded=$name" >> "$kak_opt_bundle_path/$name-load.kak"
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
        echo "$returned_val"
    }

    post_install_hooks() { # Run post-install hooks of given plugins
        for plugin; do
            hook=$(get_dict_value $plugin 1)
            if ! [ -z "$hook" ]; then
                echo "Running plugin install hook for $plugin"
                cd "$kak_opt_bundle_path/$plugin"
                eval $hook
                cd "$kak_opt_bundle_path"
            else
                echo "No plugin install hooks for $plugin"
            fi
        done
    }
}

# Highlighters

hook global WinSetOption filetype=kak %{
    try %{
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-clean|bundle-install|bundle-update|bundle-customload|bundle-noload|bundle)\s' 0:keyword
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
    for plugin in $kak_opt_bundle_plugins; do echo $plugin; done
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
    for plugin in $kak_opt_bundle_plugins; do echo $plugin; done
} %{
    evaluate-commands %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_plugins" "$kak_opt_bundle_installers" "$kak_opt_bundle_install_hooks" "$kak_opt_bundle_path" "$kak_config"
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_opt_bundle_plugins"

        # Setup fifo
        fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
        output=$fifo_tmp_dir/fifo
        mkfifo "$output"
        ( {
            # Install the plugins
            for plugin; do
                installer=$(get_dict_value $plugin 0)
                rm -Rf "$plugin"
                echo "Installing $plugin..."
                case "$installer" in
                    (*' '*) eval "$installer" ;;
                    (*) git clone $kak_opt_bundle_git_clone_opts $kak_opt_bundle_git_shallow_opts "$installer" ;;
                esac
                echo ""
                setup_load_file $plugin
            done
            # Run post-install hooks
            echo "\nRunning post-install hooks...\n"
            post_install_hooks $@
            echo "\nDone. Press <esc> to exit."
        } > "$output" 2>&1 & ) > /dev/null 2>&1
        printf '%s\n' \
                "edit! -fifo ${output} -scroll *bundle*" \
                "map buffer normal <esc> %{: delete-buffer *bundle*<ret>}" \
                "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
    }
}

define-command bundle-update -params .. -docstring %{
    bundle-install [plugins] - Update selected plugins (or all registered plugins if none selected)
} -shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do echo $plugin; done
} %{
    evaluate-commands %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_plugins" "$kak_opt_bundle_install_hooks" "$kak_opt_bundle_path" "$kak_config"
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_opt_bundle_plugins"

        # Setup fifo
        fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
        output=$fifo_tmp_dir/fifo
        mkfifo "$output"
        ( {
            # Update the plugins
            for plugin; do
                dir="$kak_opt_bundle_path/$plugin"
                [ -e "$dir" ] || continue
                # Ignore symlinked plugins
                if ! [ -h "$dir" ] && cd "$dir" 2>/dev/null; then
                   echo "Updating $plugin..."
                   git pull $kak_opt_bundle_git_shallow_opts
                   echo ""
                fi
                setup_load_file $plugin
            done
            # Run post-install hooks
            echo "\nRunning post-install hooks...\n"
            post_install_hooks $@
            echo "\nDone. Press <esc> to exit."
        } > "$output" 2>&1 & ) > /dev/null 2>&1
        printf '%s\n' \
                "edit! -fifo ${output} -scroll *bundle*" \
                "map buffer normal <esc> %{: delete-buffer *bundle*<ret>}" \
                "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
    }
}
