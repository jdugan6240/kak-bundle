declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_core_path "%val{runtime}/autoload"
declare-option -hidden str bundle_autoload_path "%val{config}/autoload/bundle"

define-command bundle -params 1 -docstring "Tells kak-bundle to manage this plugin." %{
    set-option -add global bundle_plugins %arg{1}
}

define-command bundle-install -docstring "Install all plugins known to kak-bundle." %{
    nop %sh{
        #Clean the autoload
        rm -Rf "$kak_opt_bundle_autoload_path"
        mkdir -p "$kak_opt_bundle_autoload_path"

        #Link the core plugins (no sense in copying them over)
        ln -s "$kak_opt_bundle_core_path" "$kak_opt_bundle_autoload_path/core"

        #Install the plugins
        cd "$kak_opt_bundle_autoload_path"
        eval set -- "$kak_quoted_opt_bundle_plugins"
        for plugin in "$@"
        do
            git clone "$plugin"
        done
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        rm -Rf "$kak_opt_bundle_autoload_path"
    }
    echo "kak-bundle: bundle-clean completed"
}

define-command bundle-update -docstring "Update all currently installed plugins." %{
    nop %sh{
        for dir in "$kak_opt_bundle_autoload_path"/*
        do
            cd "$dir" && git pull
        done
    }
    echo "kak-bundle: bundle-update completed"
}

define-command bundle-force-update -params 1 -docstring "Forces an update on a specific plugin when bundle-update won't work." %{
    nop %sh{
        cd "$kak_opt_bundle_autoload_path/$1" &&
          git reset --hard "$(git rev-parse @{u})"
    }
}
