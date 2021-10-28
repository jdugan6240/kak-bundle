declare-option -docstring %{
    git clone options (defaults: single-branch, no-tags)
} str bundle_git_clone_opts '--single-branch --no-tags'
declare-option -docstring %{
    git shallow options (clone & update; defaults: --depth=1)
} str bundle_git_shallow_opts '--depth=1'


declare-option -docstring %{
    Print information messages
} bool bundle_verbose false

declare-option -docstring %{
    Run install & update commands in parallel
} bool bundle_parallel false

declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_path "%val{config}/bundle/plugins"
declare-option -hidden str-list bundle_loaded_plugins 'kak-bundle'

declare-option -hidden str bundle_sh_code %{
    set -u; exec 3>&1 1>&2  # from here on, use 1>&3 to output to Kakoune
    newline='
'
    vvc() {  # execute command, maybe print beforehand, maybe background
        ! "$kak_opt_bundle_verbose" || printf 'bundle: executing %s\n' "$*" 1>&2
        bundle_tmp_new job
        printf '%s\n' "$*" >"$tmp_file".cmd
        printf '%s' "$PWD" >"$tmp_file".pwd

        > "$tmp_file.running"; >"$tmp_file".log
        ( ( "$@" ); rm -f "$tmp_file.running" ) >"$tmp_file".log 2>&1 3>&- &
        "$kak_opt_bundle_parallel" || bundle_tmp_log_wait
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
        tmp_file=$tmp_dir/bundle-"$tmp_cnt.${1:-tmp}"
    }
    bundle_tmp_log_load() {  # args: log-without-ext finished-or-running
        if [ -e "$1.running" ]; then
            ! "$2" || return 0
            running=$(( running + 1))
            status="%{...$newline}"
        else
            "$2" || return 0
            status="%file<$1.log>"
        fi
        printf 'bundle-status-log-load %s%s%s %s\n' '%<' "$1" '>' "$status"
    }
    bundle_tmp_log_wait() {
        [ -n "$tmp_dir" ] || return 0
        while :; do
            {
            printf '%s\n' 'set global bundle_log %{}; edit -scratch *bundle-status*'
            running=0
            set -- "$tmp_dir"/*.job.log
            for finished in true false; do  # running jobs -> bottom
                for log; do
                    ! [ -e "$log" ] || bundle_tmp_log_load "${log%.log}" "$finished"
                done
            done
            printf '%s\n' "bundle-status-log-show $running"
            } >"$kak_command_fifo"

            [ "$running" != 0 ] || break
            for dummy in 1 2 3; do  # update in N secs, or as soon as jobs finish
                sleep 1
                set -- "$tmp_dir"/*.job.running; [ -e "$1" ] || set --
                [ $# = "$running" ] || break
            done
        done
    }
    bundle_tmp_clean() {
        if "$kak_opt_bundle_parallel"; then
            bundle_tmp_log_wait
        fi
        if [ -n "$tmp_dir" ] && [ -e "$tmp_dir"/.rmme ]; then
            rm -Rf "$tmp_dir"
        fi
    }
    is_loaded() {
        query=$1
        eval set -- $kak_quoted_opt_bundle_loaded_plugins
        case " $* " in
            (*" $query "*) ;;  # return 0 # probably enough (no ' ' in paths)
            (*) return 1 ;;
        esac
        for plug
        do
            [ "$query" != "$plug" ] || return 0
        done
        return 1
    }
    load_directory() {
        ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: loading $1 ..."
        while IFS= read -r path; do
            [ -n "$path" ] || continue  # heredoc might produce single empty line
            printf '%s\n' "bundle-source %<$path>" >&3
    done <<EOF
$(find -L "$1" -type f -name '*.kak')
EOF
    }
    bundle_cmd_load() {
        bundle_cd
        if [ $# = 0 ]; then
            for val in *
            do
                if is_loaded "$val"; then continue; fi
                printf '%s\n' "set -add global bundle_loaded_plugins %<$val>" >&3
                load_directory "$kak_opt_bundle_path/$val"
            done
            return 0
        fi
        for val in "$@"
        do
            if is_loaded "$val"; then continue; fi
            if [ -e "$kak_opt_bundle_path/$val" ]; then
                load_directory "$kak_opt_bundle_path/$val"
                printf '%s\n' "set -add global bundle_loaded_plugins %<$val>" >&3
            else
                printf '%s\n' "bundle: ignoring missing plugin <$val>"
            fi
        done
    }
}

define-command bundle -params 1 -docstring "Tells kak-bundle to manage this plugin." %{
    set-option -add global bundle_plugins %arg{1}
}

declare-option -hidden str bundle_log
define-command bundle-status-log-load -params 2 -docstring %{
} %{
    set -add global bundle_log "## in <"
    eval set -add global bundle_log "%%file<%arg{1}.pwd>"
    set -add global bundle_log '>: '
    eval set -add global bundle_log "%%file<%arg{1}.cmd>"
    set -add global bundle_log %arg{2}
} -hidden

define-command bundle-status-log-show -params 1 -docstring %{
    Show all loaded logs in status buffer
} %{
    buffer *bundle-status*
    eval -save-regs dquote %{
        exec %{%"_d}
        reg dquote %opt{bundle_log}
        exec %{P}
        reg dquote "(%arg{1} running)"
        exec %{2<a-o>} %{geP}
    }
}

define-command bundle-install -docstring "Install all plugins known to kak-bundle." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_cd_clean

        #Install the plugins
        eval set -- "$kak_quoted_opt_bundle_plugins"
        for plugin in "$@"
        do
            case "$plugin" in
                (*' '*) vvc eval "$plugin" ;;
                (*) eval "vvc git clone $kak_opt_bundle_git_clone_opts $kak_opt_bundle_git_shallow_opts \"\$plugin\"" ;;
            esac
        done
        bundle_tmp_clean
    }
    echo "kak-bundle: bundle-install completed"
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_cd_clean
    }
}

define-command bundle-update -docstring "Update all currently installed plugins." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        for dir in "$kak_opt_bundle_path"/*
        do
            if ! [ -h "$dir" ] && cd "$dir" 2>/dev/null; then
                ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: updating in $PWD ..." 1>&2
                vvc git pull $kak_opt_bundle_git_shallow_opts
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
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        cd "$kak_opt_bundle_path/$1" &&
          git reset --hard "$(git rev-parse @{u})"
    }
}

define-command bundle-source -params 1 %{
  try %{ source %arg{1} } catch %{ echo -debug "bundle: couldn't source %arg{1}" }
} -hidden

define-command bundle-load -params .. -docstring "Loads the given plugins (or all)." %{
    eval %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_cmd_load "$@"
    }
}

define-command bundle-register-and-load -params .. %{
    eval -- %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        shifted=0
        while [ $# != 0 ]
        do
            [ $# -ge 2 ] || { printf '%s\n' 'bundle: ignoring stray arguments: %s' "$*"; return 1; }
            path=$1; path=${path%.git}; path=${path%/}  # strip final / or .git
            path=${path##*/}; : "${path:?bundle: bad plugin spec <$1>}"
            bundle_cmd_load "$path"
            printf '%s\n' >&3 \
                "bundle %arg{$(( $shifted + 1 ))}" \
                "eval %arg{$(( shifted + 2 ))}"
            shift 2; shifted=$(( shifted + 2 ))
        done
    }
}

define-command bundle-pickyload -params .. -docstring "Loads specific script files in plugin." %{
    eval -- %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_cd
        # Load scripts, if their corresponding plugin hasn't been loaded already
        for path in "$@"
        do
            plugin=${path%%/*}
            if is_loaded "$plugin"; then continue; fi
            printf '%s\n' "bundle-source %<$kak_opt_bundle_path/$path>" >&3
            printf "$plugin\n"
        done
        # Add loaded scripts to the list of loaded plugins
        for path in "$@"
        do
            plugin=${path%%/*}
            if is_loaded "$plugin"; then continue; fi
            printf '%s\n' "set -add global bundle_loaded_plugins %<$plugin>" >&3
        done
    }
}
