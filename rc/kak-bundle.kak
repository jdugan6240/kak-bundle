declare-option -docstring %{
    git clone options (defaults: single-branch, no tags)
} str bundle_git_clone_opts '--single-branch --no-tags'
declare-option -docstring %{
    git shallow options (clone & update; defaults: --depth=1)
} str bundle_git_shallow_opts '--depth=1'

declare-option -hidden str-list bundle_plugins
declare-option -hidden str bundle_path "%val{config}/bundle"
declare-option -hidden str bundle_install_hooks %{}

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

define-command bundle-customload -params 3..4 -docstring %{
    bundle-customload <plugin-name> <installer> <loading-code> [post-install code] - Register and load plugin with custom loading logic
} %{
    set-option -add global bundle_plugins %arg{2}
    try %{
        evaluate-commands %arg{3}
    } catch %{
        echo -debug %val{error}
    }
    try %{
        set-option -add global bundle_install_hooks %arg{4}
        set-option -add global bundle_install_hooks '
        '
    }
}

define-command bundle-noload -params 2 -docstring %{
    bundle-noload <plugin-name> <installer> - Register plugin without loading 
} %{
    set-option -add global bundle_plugins %arg{2}
}

define-command bundle-clean -docstring %{
    bundle-clean - Uninstall all plugins
} %{
	evaluate-commands %sh{
    	# kak_opt_bundle_path
    	# eval "$kak_opt_bundle_sh_code"
	# 
        bundle_cd() { # cd to bundle-path; create if missing
            [ -d "$kak_opt_bundle_path" ] || mkdir -p "$kak_opt_bundle_path"
            cd "$kak_opt_bundle_path"
        }

        bundle_cd_clean() { # clean, recreate, and cd to bundle_path
            rm -rf "$kak_opt_bundle_path"
            bundle_cd
        }
    	bundle_cd_clean
	}
}

define-command bundle-install -params .. -docstring %{
    bundle-install [plugins] - Install selected plugins (or all registered plugins if none selected)
} %{
    evaluate-commands %sh{
        bundle_cd() { # cd to bundle-path; create if missing
            [ -d "$kak_opt_bundle_path" ] || mkdir -p "$kak_opt_bundle_path"
            cd "$kak_opt_bundle_path"
        }

        bundle_cd_clean() { # clean, recreate, and cd to bundle_path
            rm -rf "$kak_opt_bundle_path"
            bundle_cd
        }

        installer2path() { # args: outvar installer
            [ $1 = path ] || local path
            path=$2; path=${path%.git}; path=${path%/}  # strip final / or .git
            path=${path##*/}
            eval "$1=\$path"
        }

        setup_load_file() { # Create the plugin load file
            name=$1
            folder="$kak_opt_bundle_path/$name"

        	# Be careful not to load colorschemes
        	# We don't want them being loaded prematurely
            find -L "$folder" -type f -name '*\.kak' ! -path "$folder/colors/*" \
            | sed 's/.*/source "&"/' \
            > "$kak_opt_bundle_path/$name-load.kak"
        }

        bundle_install() { # Perform the install
            bundle_cd
            [ $# != 0 ] || eval set -- "$kak_quoted_opt_bundle_plugins"

            # Setup fifo and install the plugins
            fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
            output=$fifo_tmp_dir/fifo
            mkfifo "$output"
            ( {
                for plugin
                do
                    installer2path path "$plugin"
                    rm -Rf "$path"
                    case "$plugin" in
                        (*' '*) eval "$plugin" ;;
                        (*) git clone $kak_opt_bundle_git_clone_opts $kak_opt_bundle_git_shallow_opts "$plugin" ;;
                    esac
                    setup_load_file $path
                done
                # Run post-install hooks
                printf "\nRunning post-install hooks...\n\n"
                eval "$kak_opt_bundle_install_hooks"
                printf "\nDone. Press <esc> to exit.\n"
            } > "$output" 2>&1 & ) > /dev/null 2>&1 < /dev/null
            printf '%s\n' \
                    "edit! -fifo ${output} -scroll *bundle-install*" \
                    "map buffer normal <esc> %{: delete-buffer *bundle-install*<ret>}" \
                    "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
        }
        # kak_config
        # kak_opt_bundle_path
        # kak_opt_bundle_git_clone_opts
        # kak_opt_bundle_git_shallow_opts
        # kak_quoted_opt_bundle_plugins
        # kak_opt_bundle_install_hooks
        # eval "$kak_opt_bundle_sh_code"
        bundle_install $@
    }
}
