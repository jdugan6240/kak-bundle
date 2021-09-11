# kak-bundle

A minimalist plugin manager for Kakoune.

## Install

### Autoload

Create the autoload directory, if you haven't already:

```
mkdir ~/.config/kak/autoload/
```

Clone kak-bundle in the autoload directory:

```
git clone https://github.com/jdugan6240/kak-bundle ~/.config/kak/autoload/kak-bundle
```

### Manual

Clone kak-bundle anywhere on your system:

```
git clone https://github.com/jdugan6240/kak-bundle
```

Add the following to your kakrc:

```
source path_to_kak_bundle_repo/rc/kak-bundle.kak
```

## Usage

Registering plugins with kak-bundle in your kakrc is done as follows (kak-lsp in this example):

```
bundle https://github.com/kak-lsp/kak-lsp
```

Once your kakrc is saved and reloaded, run `bundle-install` to install the registered plugins, `bundle-clean` to
clear any installed plugins, and `bundle-update` to update any installed plugins.

That's all there is to it. Seriously. This plugin manager doesn't do anything else.

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
