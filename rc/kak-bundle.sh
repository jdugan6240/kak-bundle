#!/bin/sh

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
