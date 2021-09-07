declare-option -hidden str bundle_plugins

declare-option -hidden str bundle_core_path "%val{runtime}/autoload"
declare-option -hidden str bundle_autoload_path "%val{config}/autoload/bundle"

define-command bundle -params 1 %{
    set-option -add global bundle_plugins %arg{1}
    set-option -add global bundle_plugins " "
}

define-command bundle-install %{
    nop %sh{
        #Clean the autoload
        rm -Rf "$kak_opt_bundle_autoload_path"
        mkdir -p "$kak_opt_bundle_autoload_path"

        #Link the core plugins (no sense in copying them over)
        ln -s "$kak_opt_bundle_core_path" "$kak_opt_bundle_autoload_path/core"

        #Install the plugins
        cd "$kak_opt_bundle_autoload_path"
        set -- $kak_opt_bundle_plugins
        for plugin in "$@"
        do
            git clone $plugin
        done
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean %{
    nop %sh{
        rm -Rf "$kak_opt_bundle_autoload_path"
    }
    echo "kak-bundle: bundle-clean completed"
}

define-command bundle-update %{
    nop %sh{
        for dir in $kak_opt_bundle_autoload_path/*
        do
            cd $dir
            git pull
        done
    }
    echo "kak-bundle: bundle-update completed"
}
