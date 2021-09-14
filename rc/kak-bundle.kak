declare-option -docstring %{
    git clone options (defaults: single-branch, shallow, no-tags)
} str bundle_git_clone_opts '--single-branch --depth 3 --no-tags'

declare-option -docstring %{
    Print information messages
} bool bundle_verbose false

declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_path "%val{config}/bundle/plugins"

declare-option -hidden str bundle_sh_code %{
    set -u; exec 3>&1 1>&2  # from here on, use 1>&3 to output to Kakoune
    vvc() {  # execute command, maybe print beforehand
        ! "$kak_opt_bundle_verbose" || printf 'bundle: executing %s\n' "$*" 1>&2
        "$@"
    }
}

define-command bundle -params 1 -docstring "Tells kak-bundle to manage this plugin." %{
    set-option -add global bundle_plugins %arg{1}
}

define-command bundle-install -docstring "Install all plugins known to kak-bundle." %{
    nop %sh{ eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose"
        #Clean the plugin path
        vvc rm -Rf "$kak_opt_bundle_path"
        mkdir -p "$kak_opt_bundle_path"

        #Install the plugins
        eval set -- "$kak_quoted_opt_bundle_plugins"
        cd "$kak_opt_bundle_path" || exit 1
        for plugin in "$@"
        do
            case "$plugin" in
                (*' '*) (vvc eval "$plugin") ;;
                (*) eval "vvc git clone $kak_opt_bundle_git_clone_opts \"\$plugin\"" ;;
            esac
        done
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        vvc rm -Rf "$kak_opt_bundle_path"
    }
    echo "kak-bundle: bundle-clean completed"
}

define-command bundle-update -docstring "Update all currently installed plugins." %{
    nop %sh{
        for dir in "$kak_opt_bundle_path"/*
        do
            if ! [ -h "$dir" ] && cd "$dir" 2>/dev/null; then
                ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: updating in $PWD ..." 1>&2
                git pull
            else
                ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: skipping $dir ..." 1>&2
            fi
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

define-command bundle-load -params .. -docstring "Loads the given plugins (or all)." %{
    eval %sh{ eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose"
        load_directory() {
            ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: loading $1 ..."
            while IFS= read -r path; do
                [ -n "$path" ] || continue  # heredoc might produce single empty line
                printf '%s\n' "try %{ source %<$path> } catch %{ echo -debug kak-bundle: could not load %<$path> }" 1>&3
        done <<EOF
$(find -L "$1" -type f -name '*.kak')
EOF
        }
        if [ $# = 0 ]; then load_directory "$kak_opt_bundle_path"; exit 0; fi
        for val in "$@"
        do
            if [ -e "$kak_opt_bundle_path/$val" ]; then
                load_directory "$kak_opt_bundle_path/$val"
            fi
        done
    }
}
