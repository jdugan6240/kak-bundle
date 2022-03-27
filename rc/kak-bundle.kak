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
    Maximum install & update jobs to run in parallel
} int bundle_parallel 4

declare-option -hidden str-list bundle_plugins

declare-option -hidden str bundle_path "%val{config}/bundle/plugins"
declare-option -hidden str-list bundle_loaded_plugins 'kak-bundle'

declare-option -hidden str bundle_log_running
declare-option -hidden str bundle_log_finished
declare-option -hidden str bundle_tmp_dir

declare-option -docstring %{
    Perform post-install hooks after install/update
} bool bundle_do_install_hooks false

declare-option -docstring %{
    Post-install hooks to be performed after install/update
} str bundle_install_hooks %{}

# since we want to add highlighters to kak filetype we need to require kak module
# using `try' here since kakrc module may not be available in rare cases (such as using autoload without kakrc.kak script)
try %@
    require-module kak
    try %$
        add-highlighter shared/kakrc/code/bundle_keywords   regex '\s(bundle-load|bundle-pickyload|bundle-config|bundle)\s' 0:keyword
    $ catch %$
        echo -debug "Error: kak-bundle: can't declare highlighters for 'kak' filetype: %val{error}"
    $
@ catch %{
    echo -debug "Error: kak-bundle: can't require 'kak' module to declare highlighters for kak-bundle. Check if kakrc.kak is available in your autoload."
}

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

        set -- "$tmp_dir"/*.job.running; [ $# != 1 ] || [ -e "$1" ] || set --
        [ $# -lt "$kak_opt_bundle_parallel" ] || wait $!
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
            > "$tmp_dir"/.rmme  # safeguard
        fi
        tmp_cnt=$(( tmp_cnt + 1 ))
        tmp_file=$tmp_dir/bundle-"$tmp_cnt.${1:-tmp}"
    }
    bundle_tmp_log_load() {  # args: log-without-ext
        local status log_opt
        if [ -e "$1.running" ]; then
            running=$(( running + 1))
            log_opt=running
            status="%{...$newline}"
        else
            log_opt=finished
            status="%file<$1.log>"
        fi
        printf 'bundle-status-log-load %s %%file<%s.pwd> %%file<%s.cmd> %s\n' "$log_opt" "$1" "$1" "$status"
    }
    bundle_tmp_log_wait() {
        [ -n "$tmp_dir" ] || return 0
        while :; do
            set -- "$tmp_dir"/*.job.running; [ $# != 1 ] || [ -e "$1" ] || set --
            [ $# != 0 ] || break
            sleep 1
        done
    }
    bundle_status_init() {
        bundle_tmp_new  # ensure tmp_dir exists
        printf >&3 '%s\n' \
            'edit -scratch *bundle-status*' \
            "set buffer bundle_tmp_dir %<$tmp_dir>" \
            'hook -group bundle-status buffer NormalIdle .* %{ bundle-status-update-hook }'
    }
    installer2path() {  # args: outvar installer
        [ $1 = path ] || local path
        path=$2; path=${path%.git}; path=${path%/}  # strip final / or .git
        path=${path##*/}; : "${path:?bundle: bad plugin spec <$2>}"
        eval "$1=\$path"
    }
    is_loaded() {
        local query plug
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
        local path
        ! "$kak_opt_bundle_verbose" || printf '%s\n' "bundle: loading $1 ..."
        while IFS= read -r path; do
            [ -n "$path" ] || continue  # heredoc might produce single empty line
            printf '%s\n' "bundle-source %<$path>" >&3
    done <<EOF
$(find -L "$1" -type f -name '*.kak')
EOF
    }
    bundle_cmd_load() {
        local val
        bundle_cd
        [ $# != 0 ] || set -- *
        for val
        do
            if is_loaded "$val"; then continue; fi
            if [ -e "$kak_opt_bundle_path/$val" ]; then
                load_directory "$kak_opt_bundle_path/$val"
                printf '%s\n' "set -add global bundle_loaded_plugins %<$val>" >&3
                printf '%s\n' "try %{ trigger-user-hook bundle-loaded=$val }" >&3
            else
                printf '%s\n' "bundle: ignoring missing plugin <$val>"
            fi
        done
    }
}

define-command bundle -params 1..2 -docstring "Tells kak-bundle to manage this plugin." %{ 
    set-option -add global bundle_plugins %arg{1}

    try %{
        set-option -add global bundle_install_hooks %arg{2}
        set-option -add global bundle_install_hooks "
        "
        set-option global bundle_do_install_hooks true
    }
}

define-command bundle-config -params 2 -docstring "Tells kak-bundle to perform commands when plugin is loaded." %{
    try %{ hook global -group cork-loaded User "bundle-loaded=%arg{1}" %arg{2} }
}

define-command bundle-run-install-hooks %{
    delete-buffer *bundle-status*
    eval %sh{
        set -u
        [ -n "$kak_opt_bundle_install_hooks" ] || exit 0
        if "$kak_opt_bundle_do_install_hooks"; then
            fifo_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-bundle-XXXXXXX)
            output=$fifo_tmp_dir/fifo
            mkfifo "$output"
            ( {
                printf '%s\n' 'Running post-install hooks'
                eval "$kak_opt_bundle_install_hooks" # "$kak_config" "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
                printf '\n %s\n' 'Post-install hooks complete; press <ESC> to dismiss'
              } > "$output" 2>&1 & ) > /dev/null 2>&1 < /dev/null
            printf '%s\n' \
                "edit! -fifo ${output} -scroll *bundle-install-hooks*" \
                'map buffer normal <esc> %{: delete-buffer *bundle-install-hooks*<ret>}' \
                "hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -Rf \"$fifo_tmp_dir\" } }"
        fi
    }
}

define-command bundle-status-update-hook -params .. -docstring %{
} %{
    eval -- %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        tmp_dir=$kak_opt_bundle_tmp_dir
        printf >&3 '%s\n' 'buffer *bundle-status*'

        printf >&3 'set buffer bundle_log_%s ""\n' finished running  # clear log vars
        running=0
        set -- "$tmp_dir"/*.job.log
        for log; do
            ! [ -e "$log" ] || bundle_tmp_log_load "${log%.log}" >&3
        done
        printf >&3 '%s\n' "bundle-status-log-show $running"
        if [ -e "$tmp_dir/.done" ]; then
            printf >&3 '%s\n' \
                'rmhooks buffer bundle-status' \
                'map buffer normal <esc> %{: bundle-run-install-hooks<ret>}' \
                'exec %{ge} %{o} %{DONE (<} %{esc} %{> = dismiss)} %{<esc>}' \
                'nop -- %sh{
                    set -- "$kak_opt_bundle_tmp_dir"
                    if [ -n "$1" ] && [ -e "$1"/.rmme ]; then rm -Rf "$1"; fi
                }' \
                'set buffer bundle_tmp_dir %{}'
        fi
    }
    hook -once -group bundle-status buffer NormalIdle .* %{
        exec HLHL
    }  # re-trigger
} -hidden
define-command bundle-status-log-load -params 4 -docstring %{
} %{
    buffer *bundle-status*
    eval "set -add buffer bundle_log_%arg{1} ""## in <%%arg{2}>: %%arg{3}%%arg{4}"" "
} -hidden

define-command bundle-status-log-show -params 1 -docstring %{
    Show all loaded logs in status buffer
} %{
    buffer *bundle-status*
    eval -save-regs dquote %{
        exec %{%"_d}
        reg dquote %opt{bundle_log_finished}
        exec %{P}
        reg dquote %opt{bundle_log_running}
        exec %{P}
        reg dquote "(%arg{1} running)"
        exec %{<a-o>} %{geP}
    }
} -hidden

define-command bundle-install -params .. -docstring "Install specific plugins (or all known to kak-bundle)" %{
    eval -- %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_status_init
        bundle_cd
        [ $# != 0 ] || eval set -- "$kak_quoted_opt_bundle_plugins"

        #Install the plugins
        (
        for plugin
        do
            installer2path path "$plugin"
            rm -Rf "$path"
            case "$plugin" in
                (*' '*) vvc eval "$plugin" ;;
                (*) eval "vvc git clone $kak_opt_bundle_git_clone_opts $kak_opt_bundle_git_shallow_opts \"\$plugin\"" ;;
            esac
        done
        bundle_tmp_log_wait
        > "$tmp_dir"/.done
        ) >/dev/null 2>&1 3>&- &
    }
}

define-command bundle-clean -docstring "Remove all currently installed plugins." %{
    nop %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_cd_clean
    }
}

define-command bundle-update -params .. -docstring "Update specific plugins (or all currently installed)" %{
    eval -- %sh{
        eval "$kak_opt_bundle_sh_code" # "$kak_command_fifo" "$kak_response_fifo" "$kak_opt_bundle_verbose" "$kak_opt_bundle_path" "$kak_opt_bundle_parallel" "$kak_quoted_opt_bundle_loaded_plugins"
        bundle_status_init
        bundle_cd
        [ $# != 0 ] || set -- *
        (
        for dir
        do
            dir=$kak_opt_bundle_path/$dir
            [ -e "$dir" ] || continue
            if ! [ -h "$dir" ] && cd "$dir" 2>/dev/null; then
                vvc git pull $kak_opt_bundle_git_shallow_opts
            fi
        done
        bundle_tmp_log_wait
        > "$tmp_dir"/.done
        ) >/dev/null 2>&1 3>&- &
    }
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
            installer2path path "$1"
            bundle_cmd_load "$path"
            printf '%s\n' >&3 "bundle %arg{$(( $shifted + 1 ))}"
            # don't configure missing plugins # TODO: also track load failues
            ! [ -e "$path" ] || printf '%s\n' >&3 "eval %arg{$(( shifted + 2 ))}"
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
