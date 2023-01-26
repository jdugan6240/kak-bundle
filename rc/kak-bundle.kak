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
    evaluate-commands %sh{
        set -u
        . $(echo "${kak_opt_bundle_src%%.kak}.sh")
        # "$kak_opt_bundle_plugins"
        # "$kak_opt_bundle_installers"
        # "$kak_opt_bundle_install_hooks"
        # "$kak_opt_bundle_path"
        # "$kak_config"
        # "$kak_opt_bundle_parallel"
        # "$kak_client"
        # "$kak_session"
        # "$kak_opt_bundle_git_clone_opts"
        bundle_install $@
    }
}
