declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_path "%val{config}/bundle/plugins"

define-command bundle -params 1 -docstring "Tells kak-bundle to manage this plugin." %{
    set-option -add global bundle_plugins %arg{1}
}

define-command bundle-install -docstring "Install all plugins known to kak-bundle." %{
    nop %sh{
        #Clean the plugin path
        rm -Rf "$kak_opt_bundle_path"
        mkdir -p "$kak_opt_bundle_path"

        #Install the plugins
        eval set -- "$kak_quoted_opt_bundle_plugins"
        cd "$kak_opt_bundle_path" || exit 1
        for plugin in "$@"
        do
            git clone "$plugin"
        done
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        rm -Rf "$kak_opt_bundle_path"
    }
    echo "kak-bundle: bundle-clean completed"
}

define-command bundle-update -docstring "Update all currently installed plugins." %{
    nop %sh{
        for dir in "$kak_opt_bundle_path"/*
        do
            cd "$dir" && git pull
        done
    }
    echo "kak-bundle: bundle-update completed"
}

define-command bundle-force-update -params 1 -docstring "Forces an update on a specific plugin when bundle-update won't work." %{
    nop %sh{
        cd "$kak_opt_bundle_path/$1" &&
          git reset --hard "$(git rev-parse @{u})"
    }
}

define-command bundle-load -params 1.. -docstring "Loads the given plugins." %{
    eval %sh{
        load_directory() {
            while IFS= read -r path; do
                [ -n "$path" ] || continue  # heredoc might produce single empty line
                printf '%s\n' "try %{ source %<$path> } catch %{ echo -debug kak-bundle: could not load %<$path> }"
        done <<EOF
$(find -L "$1" -type f -name '*.kak')
EOF
        }
        for val in "$@"
        do
            if [ -e "$kak_opt_bundle_path/$val" ]; then
                load_directory "$kak_opt_bundle_path/$val"
            fi
        done
    }
}
