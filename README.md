# kak-bundle

**kak-bundle** is a plugin manager for Kakoune designed for speed without sacrificing utility. It can install and
update plugins, and optionally manage loading individual plugins and scripts for testing purposes.

## Install

**kak-bundle** can be located anywhere on the system, but in order to manage itself, it should be installed in the
plugin installation directory. By default, this is `%val{config}/bundle/plugins`, which in most cases expands to
`~/.config/kak/bundle/`, but this can be changed by setting the `bundle_path` option. The following assumes
the default location:

```
mkdir -p $HOME/.config/kak/bundle/
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/bundle/kak-bundle
```

This isn't enough by itself, though &mdash; Kakoune needs to be told to load kak-bundle. This is done by adding the following
line to your kakrc:

```
source "%val{config}/bundle/plugins/kak-bundle/rc/kak-bundle.kak"
bundle-noload kak-bundle https://codeberg.org/jdugan6240/kak-bundle
```

Alternatively, the need to load kak-bundle manually can be avoided by placing the kak-bundle repo in your autoload:

```
mkdir -p $HOME/.config/kak/autoload/bundle/
git clone https://codeberg.org/jdugan6240/kak-bundle $HOME/.config/kak/autoload/bundle/kak-bundle
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
  cd ${kak_opt_bundle_path}/kak-lsp
  cargo install --locked --force --path .
}
```
The first parameter is the name of the plugin, and the second parameter is an installer (usually a URL), which must lead to a repository
matching the name of the plugin. The third and fourth parameters are optional, and contain a code block that runs when the plugin
is loaded, and a shell code block that runs after the plugin is installed, respectively (a compilation step, for example). Keep in mind that
if the post-install shell block is defined, the configuration block must be defined as well.

It may be desirable, however, in some scenarios to grab a plugin from a specific branch or filepath. For this, `kak-bundle`
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
# external plugins load normally, but bundle-update will ignore them
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
bundle-noload kak-lsp https://github.com/kak-lsp/kak-lsp.git
```
As before, the installer specified in the second argument must match the plugin name specified in the first argument.

Once these commands are written in your kakrc for the first time, the kakrc must be re-sourced to inform **kak-bundle**
about the registered plugins. To avoid collisions with redefining existing commands/options, this is best done by restarting
Kakoune.

After this is done, the registered plugins can be installed with the `bundle-install` command, and all installed plugins
can be uninstalled with the `bundle-clean` command.

Plugins may receive updates after being installed. Use the `bundle-update` command to update all installed plugins, or
pass specific plugin folders (under `bundle_path`) as arguments to update selectively:
```
bundle-update                        # update all plugins
bundle-update kak-lsp kakoune-extra  # update individual plugins
```

## Tips and Tricks

### Colorschemes

`kak-bundle` doesn't support colorschemes by default, but they're pretty easy to add support for by running post-install code.
Take this example for [one.kak](https://github.com/raiguard/one.kak):

```
bundle one.kak https://github.com/raiguard/one.kak %{
  # Configure here...
  colorscheme one-dark
} %{
  # Post-install code here...
  mkdir -p ${kak_config}/colors
  ln -sf "${kak_opt_bundle_path}/one.kak" "${kak_config}/colors/"
}
```

## **kak-bundle** Configuration

**kak-bundle** provides the following options that can be used to change how kak-bundle works:

- `bundle_path` &mdash; This dictates the directory **kak-bundle** installs plugins to. This is `%val{config}/bundle` by default.
- `bundle_git_clone_opts` &mdash; This determines the options `bundle-install` and `bundle-update` pass to the `git clone` command to install
and update plugins. By default, this is `'--single-branch --no-tags'`.
- `bundle_git_shallow_opts` &mdash; This determines the shallow clone options `bundle-install` and `bundle-update` pass to the `git clone` command
to install and update plugins. This is used to create shallow clones of the plugin repositories, which store less of the plugin's commit
history, thus saving space and download time. By default, this is `'--depth=1'`.

## Performance

**kak-bundle** was designed for speed from the start, which translates to extremely fast load times. For reference, here's some (old) performance
statistics comparing the performance of **kak-bundle** with the `kak-bundle-plug` addon to that of `plug.kak`'s `plug-chain` command (courtesy of
Alin Mr. (https://codeberg.org/almr)):

| Command                                                                                         | Mean [ms]    | Min [ms] | Max [ms] |
|-------------------------------------------------------------------------------------------------|--------------|----------|----------|
| KAKOUNE_POSIX_SHELL=/bin/dash KAK_PLUG_CHAIN=plug-chain /opt/kak/bin/kak -ui dummy -e quit      | 282.1 +- 2.9 | 277.6    | 285.8    |
| KAKOUNE_POSIX_SHELL=/bin/dash KAK_PLUG_CHAIN=kak-bundle-plug /opt/kak/bin/kak -ui dummy -e quit | 244.1 +- 2.6 | 240.1    | 247.5    |

## License

This plugin is "licensed" under the Unlicense.

## Contributors

James Dugan (https://codeberg.org/jdugan6240)

Alin Mr. <almr.oss@outlook.com>
