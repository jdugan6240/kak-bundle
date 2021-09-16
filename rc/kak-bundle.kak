declare-option -docstring %{
    git clone options (defaults: single-branch, shallow, no-tags)
} str bundle_git_clone_opts '--single-branch --depth 3 --no-tags'

declare-option -docstring %{
    Print information messages
} bool bundle_verbose false

declare-option -docstring %{
    Run install & update commands in parallel
} bool bundle_parallel false

declare-option -hidden str-list bundle_plugins

declare-option -hidden str-list bundle_loaded_sources
declare-option -hidden str-list bundle_new_sources

declare-option -hidden str bundle_path "%val{config}/bundle/plugins"

declare-option -hidden str bundle_sh_code %{
    set -u; exec 3>&1 1>&2  # from here on, use 1>&3 to output to Kakoune
    vvc() {  # execute command, maybe print beforehand, maybe background
        ! "$kak_opt_bundle_verbose" || printf 'bundle: executing %s\n' "$*" 1>&2
        if "$kak_opt_bundle_parallel"; then
            bundle_tmp_new job
            printf '%s\n' "$*" >"$tmp_file".cmd
            { "$@" >"$tmp_file".log 2>&1 3>&1; } &
        else
            "$@"
        fi
    }
    bundle_cd() {  # cd to bundle_path, create if missing
        [ -d "$kak_opt_bundle_path" ] || mkdir -p "$kak_opt_bundle_path"
        if ! cd "$kak_opt_bundle_path"; then
            printf '%s\n' "bundle: fatal: failed to create $kak_opt_bundle_path"
            exit 1
        fi
    }
    bundle_cd_clean() {  # clean, re-create and cd to bundle_path
        ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: cleaning $kak_opt_bundle_path ..." 1>&2
        rm -Rf "$kak_opt_bundle_path"
        bundle_cd
    }
    tmp_cnt=0 tmp_dir= tmp_file=
    bundle_tmp_new() {  # increments counter, stores filename in tmp_file
        if [ -z "$tmp_dir" ]; then
            tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle.$$.XXXXXX)
            touch "$tmp_dir"/.rmme  # safeguard
        fi
        tmp_cnt=$(( tmp_cnt + 1 ))
        tmp_file=$tmp_dir/bundle-$(printf '%05d' "$tmp_cnt").${1:-tmp}
    }
    bundle_tmp_clean() {
        if "$kak_opt_bundle_parallel"; then
            wait
        fi
        if [ -n "$tmp_dir" ] && [ -e "$tmp_dir"/.rmme ]; then
            if "$kak_opt_bundle_verbose"; then
                for log in "$tmp_dir"/*.job.log
                do
                    printf 'bundle: output from: '
                    cat "${log%.log}.cmd"
                    cat "$log"
                done 1>&2
            fi
            rm -Rf "$tmp_dir"
        fi
    }
}

define-command bundle -params 1 -docstring "Tells kak-bundle to manage this plugin." %{
    set-option -add global bundle_plugins %arg{1}
}

define-command bundle-install -docstring "Install all plugins known to kak-bundle." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel"
        bundle_cd_clean

        #Install the plugins
        eval set -- "$kak_quoted_opt_bundle_plugins"
        for plugin in "$@"
        do
            case "$plugin" in
                (*' '*) vvc eval "$plugin" ;;
                (*) eval "vvc git clone $kak_opt_bundle_git_clone_opts \"\$plugin\"" ;;
            esac
        done
        bundle_tmp_clean
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel"
        bundle_cd_clean
    }
}

define-command bundle-update -docstring "Update all currently installed plugins." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel"
        for dir in "$kak_opt_bundle_path"/*
        do
            if ! [ -h "$dir" ] && cd "$dir" 2>/dev/null; then
                ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: updating in $PWD ..." 1>&2
                vvc git pull
            else
                ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: skipping $dir ..." 1>&2
            fi
        done
        bundle_tmp_clean
    }
    echo "kak-bundle: bundle-update completed"
}

define-command bundle-force-update -params 1 -docstring "Forces an update on a specific plugin when bundle-update won't work." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel"
        cd "$kak_opt_bundle_path/$1" &&
          git reset --hard "$(git rev-parse @{u})"
    }
}

define-command bundle-source -params 1 %{
  try %{ source %arg{1} } catch %{ echo -debug "bundle: couldn't source %arg{1}" }
} -hidden

define-command bundle-load-new %{
    # set-difference A-B (don't load again)
    set -remove global bundle_new_sources %opt{bundle_loaded_sources}
    # "%opt{}" concatenates "source" statements with spaces between
    eval "%opt{bundle_new_sources}"

    # A + B-A = A-union-B
    set -add    global bundle_loaded_sources %opt{bundle_new_sources}
    set global bundle_new_sources
} -hidden

define-command bundle-load -params .. -docstring "Loads the given plugins (or all)." %{
    set global bundle_new_sources
    eval %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel"
        load_directory() {
            ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: loading $1 ..."
            while IFS= read -r path; do
                [ -n "$path" ] || continue  # heredoc might produce single empty line
                printf '%s\n' "set -add global bundle_new_sources %<bundle-source %<$path>;>" >&3

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
    bundle-load-new
}
