# kak-bundle

**kak-bundle** is a plugin manager for Kakoune designed for speed without sacrificing utility. It can install and
update plugins, and optionally manage loading individual plugins and scripts for testing purposes.

## Install

**kak-bundle** can be located anywhere on the system, but in order to manage itself, it should be installed in the
plugin installation directory. By default, this is `%val{config}/bundle`, which in most cases expands to
`~/.config/kak/bundle/`, but this can be changed by setting the `bundle_path` option. The following assumes
the default location:

```
mkdir -p $HOME/.config/kak/bundle/
git clone https://github.com/jdugan6240/kak-bundle $HOME/.config/kak/bundle/kak-bundle
```

This isn't enough by itself, though &mdash; Kakoune needs to be told to load kak-bundle. This is done by adding the following
line to your kakrc:

```
source "%val{config}/bundle/kak-bundle/rc/kak-bundle.kak"
bundle-noload kak-bundle https://github.com/jdugan6240/kak-bundle
```

Alternatively, the need to load kak-bundle manually can be avoided by placing the kak-bundle repo in your autoload:

```
mkdir -p $HOME/.config/kak/autoload/bundle/
git clone https://github.com/jdugan6240/kak-bundle $HOME/.config/kak/autoload/bundle/kak-bundle
```

This option doesn't allow kak-bundle to manage itself, however.

## Usage

Plugins are registered and loaded with the `bundle` command.

```
bundle kak-lsp https://github.com/kak-lsp/kak-lsp %{
  # Configure here...
  hook global KakEnd .* lsp-exit
} %{
  # Post-install code here...
  cargo install --locked --force --path .
}
```
The first parameter is the name of the plugin, and the second parameter is an installer (usually a URL), which must lead to a repository
matching the name of the plugin. The third and fourth parameters are optional, and contain a code block that runs when the plugin
is loaded, and a shell code block that runs after the plugin is installed, respectively (a compilation step, for example). Keep in mind that
if the post-install shell block is defined, the configuration block must be defined as well.

It may be desirable, however, in some scenarios to grab a plugin from a specific branch or filepath. For this, **kak-bundle**
has the concept of "installers", or custom shell code that is run to create a directory in `bundle_path` containing the
plugin code. These are run in the `bundle_path` directory. Installers allow for all sorts of options regarding plugin
install. Some examples are shown below:

```
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
```
bundle-customload kakoune-extra https://github.com/lenormf/kakoune-extra %{
  # Custom loading logic here...
  source "%opt{bundle_path}/kakoune-extra/fzf.kak"
  source "%opt{bundle_path}/kakoune_extra/tldr.kak"
  source "%opt{bundle_path}/kakoune_extra/utils.kak"

  # Configuration goes here too...
} %{
  # Post-install code here...
}
```
In this case, three arguments are required - the plugin name, the installer, and the code block containing the custom
loading logic. The fourth argument is optional, and would contain shell code to run a compilation step or similar.

Finally, kak-bundle provides a command, `bundle-noload`, to register a plugin without loading it. This is useful, for example,
for testing how plugins behave when other plugins aren't loaded. An example:
```
bundle-noload kak-lsp https://github.com/kak-lsp/kak-lsp.git %{
  # This configuration code isn't run on startup...
} %{
  # Post-install code here...
  cargo install --locked --force --path .
}
```
As before, the installer specified in the second argument must match the plugin name specified in the first argument.

Once these commands are written in your kakrc for the first time, the kakrc must be re-sourced to inform **kak-bundle**
about the registered plugins. To avoid collisions with redefining existing commands/options, this is best done by restarting
Kakoune.

After this is done, the registered plugins can be installed with the `bundle-install` command, and installed plugins
can be uninstalled with the `bundle-clean` command. `bundle-install` and `bundle-clean` can also accept individual
plugins as arguments to install/uninstall selectively.

Plugins may receive updates after being installed. Use the `bundle-install` command to update all installed plugins, or
pass specific plugins as arguments to update selectively:
```
bundle-install                        # update all plugins
bundle-install kak-lsp kakoune-extra  # update individual plugins
```

## Tips and Tricks

### Colorschemes

**kak-bundle** doesn't support colorschemes by default, but they're pretty easy to support by running post-install code. Take
this example for [one.kak](https://github.com/raiguard/one.kak):

```
bundle-noload one.kak https://github.com/raiguard/one.kak %{
} %{
  # Post-install code here...
  mkdir -p ${kak_config}/colors
  ln -sf "${kak_opt_bundle_path}/one.kak" "${kak_config}/colors/"
}
# Set the colorscheme later on in the kakrc...
colorscheme one-dark
```

The `bundle-noload` command is necessary in this case, as otherwise the colorscheme would be loaded immediately, which may
conflict with other installed colorschemes.

### Bootstrap kak-bundle

The process of installing and loading **kak-bundle** can be automated, at a slight load time cost, by adding the following to
the top of your kakrc:

```
evaluate-commands %sh{
  # We're assuming the default bundle_path here...
  plugins="$kak_config/bundle"
  mkdir -p "$plugins"
  [ ! -e "$plugins/kak-bundle" ] && \
    git clone -q https://github.com/jdugan6240/kak-bundle "$plugins/kak-bundle"
  printf "%s\n" "source '$plugins/kak-bundle/rc/kak-bundle.kak'"
}
bundle-noload kak-bundle https://github.com/jdugan6240/kak-bundle
```

This will create the needed directories on Kakoune launch, and download **kak-bundle** if not installed already.

### Running `bundle-install` outside of Kakoune

It can be desirable to update plugins outside of Kakoune - say, as part of a systemwide upgrade process. **kak-bundle**
provides support for this in the form of its `bundle-after-install` hook, which is a user-defined hook that is triggered
upon completion of `bundle-install`. Place the following in your kakrc:

```
hook global User bundle-after-install %{
  # This is run after bundle-install completes.
  # This could be for automatically deleting the *bundle* buffer, or some other similar action.
  # In this case, we want to exit Kakoune, so we return to the command line.
  quit!
}
```

Then, run the following on the command line: `kak -e 'bundle-install'`. **kak-bundle** will update the plugins, and then trigger
the hook, quitting Kakoune and returning you to the command line.

## **kak-bundle** Configuration

**kak-bundle** provides the following options that can be used to change how kak-bundle works:

- `bundle_path` &mdash; This dictates the directory **kak-bundle** installs plugins to. This is `%val{config}/bundle` by default.
- `bundle_parallel` &mdash; `4` by default, this determines how many parallel install/update jobs `bundle-install` can spawn; set to 1 to disable parallelism.

In addition, **kak-bundle** provides some user-defined hooks to further customize how **kak-bundle** works. None are defined by
default. They are:

- `bundle-after-install` &mdash; This is run immediately after `bundle-install` completes (including the post-install code defined for each plugin). Example: `hook global User bundle-after-install %{ try %{ delete-buffer *bundle* } }`

## Performance

**kak-bundle** is designed for speed, and runs no shell code on startup. This makes its load time pretty close to optimal.

The following load times were obtained using the benchmark suite in the benchmark/ directory on the author's machine:

| Plugin Manager | Mean [ms]     | Min [ms] | Max [ms] |
|----------------|---------------|----------|----------|
| kak-bundle     | 171.8 +- 14.4 | 150.1    | 193.8    |
| [cork.kak](https://github.com/topisani/cork.kak)       | 176.5 +- 19.3 | 156.0    | 213.3    |
| [plug.kak](https://github.com/andreyorst/plug.kak)       | 264.3 +- 35.1 | 220.4    | 313.6    |

## License

This plugin is "licensed" under the Unlicense.
