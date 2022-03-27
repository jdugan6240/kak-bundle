# kak-bundle

**kak-bundle** is a plugin manager for Kakoune designed for speed without sacrificing utility. It can install and
update plugins, and optionally manage loading individual plugins and scripts for testing purposes.

![bundle-status](/img/install.jpg)

## Install

**kak-bundle** can be located anywhere on the system, but in order to manage itself, it should be installed in the
plugin installation directory. By default, this is `%val{config}/bundle/plugins`, which in most cases expands to
`~/.config/kak/bundle/plugins`, but this can be changed by setting the `bundle_path` option. The following assumes
the default location:

```
mkdir -p $HOME/.config/kak/bundle/plugins
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/bundle/plugins/kak-bundle
```

This isn't enough by itself, though &mdash; Kakoune needs to be told to load kak-bundle. This is done by adding the following
line to your kakrc:

```
source "%val{config}/bundle/plugins/kak-bundle/rc/kak-bundle.kak"
bundle https://codeberg.org/jdugan6240/kak-bundle
```

Alternatively, the need to load kak-bundle manually can be avoided by placing the kak-bundle repo in your autoload:

```
mkdir -p $HOME/.config/kak/autoload/bundle/
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/autoload/bundle/kak-bundle
```

This option doesn't allow kak-bundle to manage itself, however, unless the `bundle_path` option is set to the autoload
directory.

## Usage

Plugins are registered with the `bundle` command. This command accepts a single argument, which in most cases is a URL
leading to the repository of the desired plugin. For example, for [kak-lsp](https://github.com/kak-lsp/kak-lsp):

```
bundle https://github.com/kak-lsp/kak-lsp
```

Some plugins require additional processing after install. For those plugins, the `bundle` command can optionally accept
a second argument representing shell code to be run after the install takes place. An example of this configuration
with `kak-lsp`:

```
bundle https://github.com/kak-lsp/kak-lsp %{
  cd ${kak_opt_bundle_path}/kak-lsp
  cargo install --locked --force --path .
}
```

`kak-bundle` can also be told to run configuration commands when a given plugin is loaded. This is done with the `bundle-config`
command. This can be useful to prevent errors in your kakrc if a plugin isn't yet installed. An example of this with `kak-lsp` is as follows:

```
bundle-config kak-lsp %{
  lsp-inlay-diagnostics-enable
  set global lsp_diagnostic_line_error_sign '║'
  set global lsp_diagnostic_line_warning_sign '┊'
  
  hook global KakEnd .* lsp-exit
}
```

Note that we don't pass the URL of the plugin here, but rather the plugin name directly.

However, none of this by itself will not load the plugin, unless `bundle_path` is set to a location in your autoload. To actually
load the installed plugins, the `bundle-load` command must be called. With no arguments it will load all registered plugins:

```
bundle-load # Load all registered plugins
```

Alternatively, if passed the names of specific plugins as arguments, `bundle-load` will selectively load those:

```
bundle-load kak-lsp # only kak-lsp is loaded -- not any additional registered plugins
```

Once these commands are written in your kakrc for the first time, the kakrc must be re-sourced to inform **kak-bundle**
about the registered plugins. To avoid collisions with redefining existing commands/options, this is best done by restarting
Kakoune.

After this is done, the registered plugins can be installed with the `bundle-install` command.

Plugins may receive updates after being installed. Use the `bundle-update` command to update all installed plugins, or
pass specific plugin folders (under `bundle_path`) as arguments to update selectively:
```
bundle-update                        # update all plugins
bundle-update kak-lsp kakoune-extra  # update individual plugins
```

## Advanced commands

### Installers

In addition to simple URLs, the `bundle` command takes full shell commands ("installers") as an argument (recognized as such if they contain space characters).
The installers will run from `bundle_path`. Each installer **must** create a directory with a name that exactly matches the substring after the **last "`/`"
in the installer command**; this is important for `bundle-install`, `bundle-config`, and `bundle-register-and-load` (to be introduced below).

Installers can be useful for a number of things:
```
# extract a specific branch / tag of a plugin repository:
bundle 'git clone -b BRANCH_OR_TAG ... $URL'

# rename the clone, e.g. to avoid conflicting names:
bundle 'git clone $URL ./renamed-folder'

# load an externally-managed plugin from outside bundle_path:
bundle 'ln -sf ~/src/my-plugin'
# external plugins load normally, but bundle-update will ignore them
```

### Register, load and configure

**kak-bundle** provides a "super-command" that combines the plugin registration, loading and configuration steps, for one or several plugins

```
bundle-register-and-load \
  URL-1 %{
    # config-1 kakscript code
  } \
  'installer-shell-code-2 args...' %{
    # config-2 kakscript code
  } \
  # etc; keep it in one long command
```

This can be more convenient and maintainable than performing the steps separately, although post-install hooks aren't currently supported with
this approach. There can be any number of `register-and-load` calls, each with one or more plugin arguments. Passing multiple `plugin+config` pairs
speeds up loading, as each `register-and-load` translates into a single shell invocation.

### Partial loading

**kak-bundle** supports loading specific scripts from a plugin, if not all the scripts from a plugin are desired.
This is done with the `bundle-pickyload` command. For example, selecting a specific script from [kakoune-extra](https://github.com/lenormf/kakoune-extra):

```
bundle-pickyload kakoune-extra/overstrike.kak
```

The above command assumes the desired script is in the top level directory of the plugin. Many plugins place their kakscripts in
the rc/ directory, however, in which case you can do something like the following ([powerline.kak](https://github.com/andreyorst/powerline.kak)):

```
bundle-pickyload powerline.kak/rc/powerline.kak \
                 powerline.kak/rc/themes/gruvbox.kak \
                 powerline.kak/rc/modules/bufname.kak
```

## **kak-bundle** Configuration

**kak-bundle** provides the following options that can be used to change how kak-bundle works:

- `bundle_path` &mdash; This dictates the directory **kak-bundle** installs plugins to. This is `%val{config}/bundle/plugins` by default.
- `bundle_parallel` &mdash; `4` by default, this determines how many parallel jobs `bundle-install` and `bundle-update` can spawn; set to 1 to disable parallelism.
- `bundle_verbose` &mdash; `false` by default, this determines if extra information is printed to a log file.
- `bundle_git_clone_opts` &mdash; This determines the options `bundle-install` and `bundle-update` pass to the `git clone` command to install
and update plugins. By default, this is `'--single-branch --no-tags'`.
- `bundle_git_shallow_opts` &mdash; This determines the shallow clone options `bundle-install` and `bundle-update` pass to the `git clone` command
to install and update plugins. This is used to create shallow clones of the plugin repositories, which store less of the plugin's commit
history, thus saving space and download time. By default, this is `'--depth=1'`.

### [plug.kak](https://github.com/andreyorst/plug.kak) Compatibility

If coming from `plug.kak` as your plugin manager, there's an addon to `kak-bundle` that may ease the transition. The [kak-bundle-plug](https://github.com/kstr0k/kak-bundle-plug)
plugin is designed to emulate the `plug-chain` command that `plug.kak` provides, supporting many of the switches that the `plug`
command supports. More details on how this addon works can be found in its repository's README.

## Performance

**kak-bundle** was designed for speed from the start, which translates to extremely fast load times. For reference, here's some (old) performance
statistics comparing the performance of **kak-bundle** with the `kak-bundle-plug` addon to that of `plug.kak`'s `plug-chain` command (courtesy of
Alin Mr. (https://codeberg.org/almr)):

| Command                                                                                         | Mean [ms]    | Min [ms] | Max [ms] |
|-------------------------------------------------------------------------------------------------|--------------|----------|----------|
| KAKOUNE_POSIX_SHELL=/bin/dash KAK_PLUG_CHAIN=plug-chain /opt/kak/bin/kak -ui dummy -e quit      | 282.1 +- 2.9 | 277.6    | 285.8    |
| KAKOUNE_POSIX_SHELL=/bin/dash KAK_PLUG_CHAIN=kak-bundle-plug /opt/kak/bin/kak -ui dummy -e quit | 244.1 +- 2.6 | 240.1    | 247.5    |

## Troubleshooting

In certain cases, running `bundle-update` will fail to update certain plugins. This can occur in the following cases:

- There are local changes that would be overwritten by `git pull`, which `bundle-update` uses, and
- The author of the plugin force-pushes to their repository, rewriting history in the process.

In this case, running `bundle-force-update <plugin_name>`, where `<plugin_name>` is the name of the plugin causing issues,
and then running `bundle-update` will force the repository to reset, allowing an update. However, this will overwrite any
local changes made to the plugin that haven't been committed to the plugin's remote repository. For example, with kak-lsp, this would be
`bundle-force-update kak-lsp` and `bundle-update`.

## License

This plugin is "licensed" under the Unlicense.

## Contributors

James Dugan (https://codeberg.org/jdugan6240)

Alin Mr. <almr.oss@outlook.com>
