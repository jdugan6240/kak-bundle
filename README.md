# kak-bundle

**kak-bundle** is a plugin manager for Kakoune designed for speed without sacrificing utility. It can install and
update plugins, and optionally manage loading individual plugins for testing purposes.

## Install

**kak-bundle** can be located anywhere on the system, but in order to manage itself, it should be installed in the
plugin installation directory. By default, this is `%val{config}/bundle/plugins`, which in most cases expands to
`~/.config/kak/bundle/plugins`, but this can be changed by setting the `bundle_path` option. The following assumes
the default location:

```
mkdir -p $HOME/.config/kak/bundle/plugins
git clone https://github.com/jdugan6240/kak-bundle $HOME/.config/kak/bundle/plugins/kak-bundle
```

This isn't enough by itself, though - Kakoune needs to be told to load kak-bundle. This is done by adding the following
line to your kakrc:

```
source %val{config}/bundle/plugins/kak-bundle/rc/kak-bundle.kak
bundle https://github.com/jdugan6240/kak-bundle
```

Alternatively, the need to load kak-bundle manually can be avoided by placing the kak-bundle repo in your autoload:

```
mkdir -p $HOME/.config/kak/autoload/bundle/
git clone https://github.com/jdugan6240/kak-bundle $HOME/.config/kak/autoload/bundle/kak-bundle
```

This option doesn't allow kak-bundle to manage itself, however, unless the `bundle_path` option is set to the autoload
directory.

## Usage

Plugins are registered with the `bundle` command. This command accepts a single argument, which in most cases is a URL
leading to the repository of the desired plugin. For example, for [kak-lsp](https://github.com/kak-lsp/kak-lsp):

```
bundle https://github.com/kak-lsp/kak-lsp
```

However, this by itself will not load the plugin, unless `bundle_path` is set to a location in your autoload. To actually
load the installed plugins, the `bundle-load` command must be called. The `bundle-load` command with no arguments will
load all registered plugins by default:

```
bundle-load # Load all registered plugins
```

However, `bundle-load` can be used to selectively load specific registered plugins if desired. This is done by passing
the names of the plugins to `bundle-load` as arguments:

```
bundle-load kak-lsp # Note that only kak-lsp is loaded, not any additional registered plugins
```

Once these commands are written in your kakrc for the first time, the kakrc must be re-sourced to inform **kak-bundle**
about the registered plugins. To avoid collisions with redefining existing commands/options, this is best done by restarting
Kakoune.

After this is done, the registered plugins can be installed with the `bundle-install` command.

If a plugin has received updates since being installed, **kak-bundle** can update all installed plugins with the `bundle-update`
command.

**kak-bundle** also optionally supports loading specific scripts from a plugin, if not all the scripts from a plugin are desired.
This is done with the `bundle-pickyload` command. For example, selecting a specific script from [kakoune-extra](https://github.com/lenormf/kakoune-extra):

```
bundle-pickyload kakoune-extra/overstrike.kak
```

The above command assumes the desired script is in the top level directory of the plugin. Many plugins place their kakscripts in
the rc/ directory, however, in which case you can do something like the following ([powerline.kak](https://github.com/andreyorst/powerline.kak)):

```
bundle-pickyload powerline.kak/rc/powerline.kak powerline.kak/rc/themes/gruvbox.kak powerline.kak/rc/modules/bufname.kak
```

## **kak-bundle** Configuration

**kak-bundle** provides the following options that can be used to change how kak-bundle works:

- `bundle_path` - This dictates the directory **kak-bundle** installs plugins to. This is `%val{config}/bundle/plugins` by default.
- `bundle_parallel` - `false` by default, this determines if `bundle-install` and `bundle-update` should install plugins in parallel.
- `bundle_verbose` - `false` by default, this determines if extra information is printed to a log file.
- `bundle_git_clone_opts` - This determines the options `bundle-install` and `bundle-update` pass to the `git clone` command to install
and update plugins. By default, this is `'--single-branch --no-tags'`.
- `bundle_git_shallow_opts` - This determines the shallow clone options `bundle-install` and `bundle-update` pass to the `git clone` command
to install and update plugins. This is used to create shallow clones of the plugin repositories, which store less of the plugin's commit
history, thus saving space and download time. By default, this is `'--depth=1'`.

## Tips and Tricks

### Loading specific plugin branches or tags

In addition to accepting the URL of the desired plugin, the `bundle` command can also accept an entire `git clone` command.
This can be useful for extracting a specific branch or tag of a given plugin repository:

```
bundle 'git clone -b BRANCH ... $URL'
```

### Running post-update hooks

Some plugins require additional processing after being installed - say, a compilation step. A notable example of a plugin like this
is [kak-lsp](https://github.com/kak-lsp/kak-lsp). While **kak-bundle** has no builtin support for this, it's fairly trivial to define
a command that does this (using kak-lsp as an example):

```
def bundle-install-hooks %{
    bundle-install
    eval %sh{
   	    cd $kak_opt_bundle_path/kak-lsp
   	    cargo install --locked --force --path .
   	    echo "echo Post-install processing complete"
    }
}
```

You can then run the new command `bundle-install-hooks` instead of `bundle-install`.

### [plug.kak](https://github.com/andreyorst/plug.kak) Compatibility

If coming from `plug.kak` as your plugin manager, there's an addon to `kak-bundle` that may ease the transition. The [kak-bundle-plug](https://github.com/kstr0k/kak-bundle-plug)
plugin is designed to emulate the `plug-chain` command that `plug.kak` provides, even supporting many of the switches that the `plug`
command supports. More details on how this plugin works can be found in its repository's README.

## Troubleshooting

In certain cases, running `bundle-update` will fail to update certain plugins. This can occur in the following cases:

- There are local changes that would be overwritten by `git pull`, which `bundle-update` uses, and
- The author of the plugin force-pushes to their repository, rewriting history in the process.

In this case, running `bundle-force-update <plugin_name>`, where `<plugin_name>` is the name of the plugin causing issues,
and then running `bundle-update` will force an update to the plugin. However, this will overwrite any local changes made to
the plugin that haven't been committed to the plugin's remote repository. For example, with kak-lsp, this would be
`bundle-force-update kak-lsp` and `bundle-update`.

## License

This plugin is "licensed" under the Unlicense.
