# kak-bundle

- Upstream: https://codeberg.org/jdugan6240/kak-bundle
- Read-only mirror (automatically updated from upstream every 8h): https://github.com/jdugan6240/kak-bundle

**kak-bundle** is a plugin manager for Kakoune designed for speed without sacrificing utility. It can install and
update plugins, and optionally manage loading individual plugins and scripts for testing purposes.

## Install

**kak-bundle** can be located anywhere on the system, but in order to manage itself, it should be installed in the
plugin installation directory. By default, this is `%val{config}/bundle`, which in most cases expands to
`~/.config/kak/bundle/`, but this can be changed by setting the `bundle_path` option. The following assumes
the default location:

```sh
mkdir -p $HOME/.config/kak/bundle/
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/bundle/kak-bundle
```

This isn't enough by itself, though &mdash; Kakoune needs to be told to load kak-bundle. This is done by adding the following
line to your kakrc:

```kak
source "%val{config}/bundle/kak-bundle/rc/kak-bundle.kak"
bundle-noload kak-bundle https://codeberg.org/jdugan6240/kak-bundle
```

Alternatively, the need to load kak-bundle manually can be avoided by placing the kak-bundle repo in your autoload:

```sh
mkdir -p $HOME/.config/kak/autoload/bundle/
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/autoload/bundle/kak-bundle
```

This option doesn't allow kak-bundle to manage itself, however.

## Usage

Plugins are registered and loaded with the `bundle` command.

```kak
bundle kak-lsp https://github.com/kak-lsp/kak-lsp %{
  # Configure here...
  map global user l %{:enter-user-mode lsp<ret>} -docstring "LSP mode"
}
```
The first parameter is the name of the plugin, and the second parameter is an installer (usually a URL), which must lead to a repository
matching the name of the plugin. The third parameter is optional, and contains a kakscript block that runs when the plugin is loaded.

Some plugins, such as the above `kak-lsp`, require shell code to be executed after being installed - a compilation step, for
example. This is supported with the `bundle-install-hook` command, as follows:
```kak
bundle-install-hook kak-lsp %{
  # Any shell code that needs to be run goes here...
  cargo install --locked --force --path .
}
```

It may be desirable, however, in some scenarios to grab a plugin from a specific branch or filepath. For this, **kak-bundle**
has the concept of "installers", or custom shell code that is run to create a directory in `bundle_path` containing the
plugin code. These are run in the `bundle_path` directory. Installers allow for all sorts of options regarding plugin
install. Some examples are shown below:

```kak
# extract a specific branch / tag of a plugin repository:
bundle my-plugin 'git clone -b BRANCH_OR_TAG ... $URL'

# rename the clone, e.g. to avoid conflicting names:
bundle my-plugin 'git clone $URL ./my-plugin'

# load an externally-managed plugin from outside bundle_path:
bundle my-plugin 'ln -sf ~/src/my-plugin'
```
As with URLs, the name of the repository/directory must match the plugin name specified in the first argument.

Sometimes, it is not desirable to load every script a plugin has to offer, or they need to be loaded in a specific order.
For this use case, kak-bundle allows for specifying custom loading logic for a plugin with the `bundle-customload` command.
An example of this for [kakoune-extra](https://github.com/lenormf/kakoune-extra):
```kak
bundle-customload kakoune-extra https://github.com/lenormf/kakoune-extra %{
  # Custom loading logic here...
  source "%opt{bundle_path}/kakoune-extra/fzf.kak"
  source "%opt{bundle_path}/kakoune_extra/tldr.kak"
  source "%opt{bundle_path}/kakoune_extra/utils.kak"

  # Configuration goes here too...
}
```
In this case, three arguments are required - the plugin name, the installer, and the code block containing the custom
loading logic.

Finally, kak-bundle provides a command, `bundle-noload`, to register a plugin without loading it. This is useful, for example,
for testing how plugins behave when other plugins aren't loaded. An example:
```kak
bundle-noload kak-lsp https://github.com/kak-lsp/kak-lsp.git %{
  # This configuration code isn't run on startup...
}
```
As before, the installer specified in the second argument must match the plugin name specified in the first argument.

Once these commands are written in your kakrc for the first time, the kakrc must be re-sourced to inform **kak-bundle**
about the registered plugins. To avoid collisions with redefining existing commands/options, this is best done by restarting
Kakoune.

After this is done, the `bundle-install` command will install all registered but uninstalled plugins.
The `bundle-clean` command will uninstall all plugins no longer registered.
`bundle-install` and `bundle-clean` can also accept individual plugins as arguments to install/uninstall selectively.
Calling bundle-install on an already installed plugin will reinstall it.

Some plugins, when installed, leave behind artifacts that aren't removed by just removing the plugin repository (`kak-lsp` for example).
For this use case, `kak-bundle` supports defining cleaners, which is shell code run after running the `bundle-clean` command. For example:

```kak
bundle-cleaner kak-lsp %{
  rm ~/.cargo/bin/kak-lsp
}
```

Now, when running `bundle-clean kak-lsp`, in addition to the plugin repo being removed from `bundle_path`, the `kak-lsp` binary
is removed as well.

Plugins may receive updates after being installed. Use the `bundle-update` command to update all installed plugins, or
pass specific plugins as arguments to update selectively:
```kak
bundle-update                         # update all plugins
bundle-update kak-lsp kakoune-extra   # update individual plugins
```

`bundle-update` by default runs `git pull` within the plugin directory, but this may not be appropriate for all plugins - say,
plugins installed via symlinking or for plugins installed with a shallow clone (basically, a truncated git history). In this case,
`kak-bundle` offers the ability to set updaters for each plugin - shell code run in place of `git pull` whenever updating a plugin. This
is done with the `bundle-updater` command as follows (in this case, a shallow-cloned `kak-lsp`):
```kak
bundle-updater kak-lsp %{
 # This is just an example. There's likely more efficient ways to do this.
 cd ../
 rm -rf kak-lsp
 git clone --depth=1 https://github.com/kak-lsp/kak-lsp
}
```

## **kak-bundle** Configuration

**kak-bundle** provides the following options that can be used to change how kak-bundle works:

- `bundle_path` &mdash; This dictates the directory **kak-bundle** installs plugins to. This is `%val{config}/bundle` by default.
- `bundle_parallel` &mdash; `4` by default, this determines how many parallel install/update jobs `bundle-install` can spawn; set to 1 to disable parallelism.

## **kak-bundle** User Hooks

In addition, **kak-bundle** provides a user-defined hook to further customize how **kak-bundle** works, which does nothing by default. It is:

- `bundle-after-install` &mdash; This is run immediately after `bundle-install` completes (including the post-install code defined for each plugin).
-
This hook also exposes the following options, which allows for unique handling based on whether the install/update succeeded or failed:

- `bundle_succeeded` &mdash; This option outlines whether the most recent install/update operation succeeded or failed.
- `bundle_failed_installs` &mdash; This option lists which installers/updaters, if any, failed in the most recent install/update operation.
- `bundle_failed_install_hooks` &mdash; This option lists which install hooks, if any, failed in the most recent install/update operation.

The following example shows an implementation that simply deletes the bundle-status buffer if the install/update succeeds, and writes it to /tmp/bundle-log if not:

```kak
hook global User bundle-after-install %{
  evaluate-commands %sh{
    if [ "$kak_opt_bundle_succeeded" = "true" ]; then
      printf "%s\n" "delete-buffer *bundle-status*"
    else
      printf "%s\n" "write -force /tmp/bundle-log"
      printf "%s\n" "delete-buffer *bundle-status*"
      printf "%s\n" "info -title 'kak-bundle' 'Install/Update failed'"
    fi
  }
}
```

## Tips and Tricks

### Colorschemes

colorschemes in **kak-bundle** are registered using the `bundle-theme` command, which is a pretty simple wrapper.
If we take the example of [one.kak](https://github.com/raiguard/one.kak), then we can write

```kak
bundle-theme one.kak https://github.com/raiguard/one.kak
```
which is equivalent to

```kak
bundle-noload one.kak https://github.com/raiguard/one.kak # Notice, no config block
bundle-install-hook one.kak %{
  # Post-install code here...
  mkdir -p ${kak_config}/colors
  ln -sf "${kak_opt_bundle_path}/one.kak" "${kak_config}/colors/"
}
# The below command is optional, but allows for cleanly uninstalling the colorscheme
bundle-cleaner one.kak %{
  # Remove the symlink
  rm -rf "${kak_config}/colors/one.kak"
}
```
Once we've installed the colorscheme we can simply load it with `colorscheme one-dark` like any other colorscheme.
If you need to override the predefined install hook and cleaner, just run `bundle-install-hook` and `bundle-cleaner` again
in your kakrc.

### Bootstrap kak-bundle

The process of installing and loading **kak-bundle** can be automated, at a slight load time cost, by adding the following to
the top of your kakrc:

```kak
evaluate-commands %sh{
  # We're assuming the default bundle_path here...
  plugins="$kak_config/bundle"
  mkdir -p "$plugins"
  [ ! -e "$plugins/kak-bundle" ] && \
    git clone -q https://codeberg.org/jdugan6240/kak-bundle "$plugins/kak-bundle"
  printf "%s\n" "source '$plugins/kak-bundle/rc/kak-bundle.kak'"
}
bundle-noload kak-bundle https://codeberg.org/jdugan6240/kak-bundle
```

This will create the needed directories on Kakoune launch, and download **kak-bundle** if not installed already.

### Running `bundle-install` outside of Kakoune

It can be desirable to update plugins outside of Kakoune - say, as part of a systemwide upgrade process. **kak-bundle**
provides support for this in the form of its `bundle-after-install` hook, which is a user-defined hook that is triggered
upon completion of `bundle-install`. Place the following in your kakrc:

```kak
hook global User bundle-after-install %{
  # This is run after bundle-install completes.
  # This could be for automatically deleting the *bundle* buffer, or some other similar action.
  # In this case, we want to exit Kakoune, so we return to the command line.
  quit!
}
```

Then, run the following on the command line: `kak -e 'bundle-install'`. **kak-bundle** will update the plugins, and then trigger
the hook, quitting Kakoune and returning you to the command line.


## Performance

**kak-bundle** is designed for speed, and runs no shell code on startup. This makes its load time pretty close to optimal.

The following load times were obtained using the benchmark suite in the benchmark/ directory on the author's machine (an M4 Mac Mini with 16GB RAM; your exact times may vary):

| Plugin Manager | Mean [ms]     | Min [ms] | Max [ms] |
|----------------|---------------|----------|----------|
| kak-bundle     | 205.9 +- 2.3  | 202.8    | 209.7    |
| [cork.kak](https://github.com/topisani/cork.kak)       | 228.4 +- 1.6  | 226.0    | 231.8    |
| [plug.kak](https://github.com/andreyorst/plug.kak)       | 355.2 +- 2.7 | 350.9    | 358.5    |

## Contributing

Any kind of contributions are welcome! Please read [CONTRIBUTING.md](https://codeberg.org/jdugan6240/kak-bundle/src/branch/master/CONTRIBUTING.md) before doing so.

## License

This plugin is licensed under the BSD0 license.
