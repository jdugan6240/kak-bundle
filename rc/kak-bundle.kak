declare-option -docstring %{
    git clone options (defaults: single-branch, no tags)
} str bundle_git_clone_opts '--single-branch --no-tags'
declare-option -docstring %{
    git shallow options (clone & update; defaults: --depth=1)
} str bundle_git_shallow_opts '--depth=1'

declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_path "%val{config}/bundle"

declare-option -hidden str bundle_install_hooks %{}

declare-option -hidden str bundle_sh_source %sh{ echo "${kak_source%%.kak}.sh" }

#Highlighters
hook global WinSetOption filetype=kak %{
    try %{
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-clean|bundle-install|bundle)\s' 0:keyword
    } catch %{
        echo -debug "Error: kak-bundle: can't declare highlighters for 'kak' filetype: %val{error}"
    }
}

define-command bundle -params 2..4 -docstring %{
    bundle <plugin-name> <installer> [config] [post-install code] - Register and load plugin
} %{
    set-option -add global bundle_plugins %arg{2}
    try %{
        source "%opt{bundle_path}/%arg{1}-load.kak"
    }
    try %{
        evaluate-commands %arg{3}
    }
    try %{
        set-option -add global bundle_install_hooks %arg{4}
        set-option -add global bundle_install_hooks '
        '
    }
}

define-command bundle-clean -docstring %{
    bundle-clean - Uninstall all plugins
} %{
	evaluate-commands %sh{
    	# kak_opt_bundle_path
    	. "${kak_opt_bundle_sh_source}"
    	bundle_cd_clean
	}
}

define-command bundle-install -params .. -docstring %{
    bundle-install [plugins] - Install selected plugins (or all registered plugins if none selected)
} %{
    evaluate-commands %sh{
        # kak_config
        # kak_opt_bundle_path
        # kak_opt_bundle_git_clone_opts
        # kak_opt_bundle_git_shallow_opts
        # kak_quoted_opt_bundle_plugins
        # kak_opt_bundle_install_hooks
        . "${kak_opt_bundle_sh_source}"
        bundle_install $@
    }
}
