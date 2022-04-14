declare-option -docstring %{
    git clone options (defaults: single-branch, no tags)
} str bundle_git_clone_opts '--single-branch --no-tags'
declare-option -docstring %{
    git shallow options (clone & update; defaults: --depth=1)
} str bundle_git_shallow_opts '--depth=1'

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
}

# Highlighters

hook global WinSetOption filetype=kak %{
    try %{
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-clean|bundle-install|bundle-customload|bundle-noload|bundle)\s' 0:keyword
    } catch %{
        echo -debug "Error: kak-bundle: can't declare highlighters for 'kak' filetype: %val{error}"
    }
}

# Commands

define-command bundle -params 2..4 -docstring %{
    bundle <plugin-name> <installer> [config] [post-install code] - Register and load plugin
} %{
    set-option -add global bundle_plugins %arg{1}
    echo -to-file "%opt{bundle_path}/%arg{1}-installer" %arg{2}
    try %{
        hook global -group bundle-loaded User "bundle-loaded=%arg{1}" %arg{3}
    }
    try %{
        source "%opt{bundle_path}/%arg{1}-load.kak"
    }
    try %{
        echo -to-file "%opt{bundle_path}/%arg{1}-install-hooks" %arg{4}
    }
}

define-command bundle-customload -params 3..4 -docstring %{
    bundle-customload <plugin-name> <installer> <loading-code> [post-install code] - Register and load plugin with custom loading logic
} %{
    set-option -add global bundle_plugins %arg{1}
    echo -to-file "%opt{bundle_path}/%arg{1}-installer" %arg{2}
    try %{
        evaluate-commands %arg{3}
    } catch %{
        echo -debug %val{error}
    }
    try %{
        echo -to-file "%opt{bundle_path}/%arg{1}-install-hooks" %arg{4}
    }
}

define-command bundle-noload -params 2 -docstring %{
    bundle-noload <plugin-name> <installer> - Register plugin without loading 
} %{
    set-option -add global bundle_plugins %arg{1}
    echo -to-file "%opt{bundle_path}/%arg{1}-installer" %arg{2}
    try %{
        hook global -group bundle-loaded User "bundle-loaded=%arg{1}" %arg{3}
    }
    try %{
        echo -to-file "%opt{bundle_path}/%arg{1}-install-hooks" %arg{4}
    }
}

define-command bundle-clean -docstring %{
    bundle-clean - Uninstall all plugins
} %{
    evaluate-commands %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_path"
        rm -rf "$kak_opt_bundle_path"
        mkdir -p "$kak_opt_bundle_path"
    }
}

define-command bundle-install -params .. -docstring %{
    bundle-install [plugins] - Install selected plugins (or all registered plugins if none selected)
} %{
    evaluate-commands %sh{
        # "$kak_opt_bundle_path"
        # "$kak_opt_bundle_plugins"
        # "$kak_config"
        eval "$kak_opt_bundle_sh_code"
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_quoted_opt_bundle_plugins"

        # Setup fifo
        fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
        output=$fifo_tmp_dir/fifo
        mkfifo "$output"
        ( {
            # Install the plugins
            for plugin; do
                installer=$(cat $plugin-installer)
                rm -Rf "$plugin"
                case "$installer" in
                    (*' '*) eval "$installer" ;;
                    (*) git clone $kak_opt_bundle_git_clone_opts $kak_opt_bundle_git_shallow_opts "$installer" ;;
                esac
                setup_load_file $plugin
            done
            # Run post-install hooks
            printf "\nRunning post-install hooks...\n\n"
            for plugin; do
                if [ -f "$plugin-install-hooks" ]; then
                    cd "$plugin"
                    eval $(cat "../$plugin-install-hooks")
                    cd "$kak_opt_bundle_path"
                else
                    echo "No plugin install hooks for $plugin"
                fi
            done
            printf "\nDone. Press <esc> to exit.\n"
        } > "$output" 2>&1 & ) > /dev/null 2>&1 < /dev/null
        printf '%s\n' \
                "edit! -fifo ${output} -scroll *bundle-install*" \
                "map buffer normal <esc> %{: delete-buffer *bundle-install*<ret>}" \
                "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
    }
}
complete-command -menu bundle-install shell-script-candidates %{
    for plugin in $kak_opt_bundle_plugins; do
       echo $plugin
    done
}
