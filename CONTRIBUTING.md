# Contributing

First off, thanks for taking the time to contribute! It's by no means required, so I greatly appreciate it! ❤️

Contributions should be made to the upstream repo at [Codeberg](https://codeberg.org/jdugan6240/kak-bundle), not the [GitHub mirror](https://github.com/jdugan6240/kak-bundle).
Pull requests cannot be turned off on the Github mirror due to a [missing GitHub feature](https://github.com/orgs/community/discussions/8907), so please refrain from opening PR's there.
Codeberg's great, I promise 🙂

All types of contributions are highly valued, from a new feature or bugfix to correcting typos in documentation to simply reporting a bug you encountered.

## Feature/Bugfix Requests

For feature requests, please include a description of the feature and a problem/use case that this new feature will solve.

For bugfix requests, please include the desired behavior, the actual behavior, and a method to reproduce.

With that being said, if any additional information is required, you'll be asked for it.
I don't believe being hard-nosed on requiring users to fill out an issue template and closing without comment if they don't is respectful to users.
It's not much of a hardship for maintainers to politely ask for the information they need, instead of driving contributors away needlessly.

Drive-by spam will not be tolerated, however, and if queries for more information are refused or ignored, your issue will be closed and locked.

Also, please check the issue tracker to make sure your issue hasn't already been reported.
Duplicates **WILL** be immediately closed.

# Code Contributions

If you instead want to submit a bugfix, documentation fix or new feature, there are a few requirements that need to be met before merging can be considered.
After all, I'm on the hook for maintaining whatever you contribute.
- All shell code must be POSIX compliant. This is to ensure maximum portability, as not all systems come with bash/zsh as the default shell.
- Your changes should not meaningfully affect `kak-bundle`'s load time. In other words, Kakoune startup with `kak-bundle` in use should only increase by a couple milliseconds at most, if at all. Load time is the biggest reason to use kak-bundle over other plugin managers, after all.
- Any code changes should also match the style of the surrounding code, when possible. The big requirement here is 4 space indentation.
- The documentation (AKA the README) should be updated with details of your change(s), if necessary.
- The pull request itself must contain a description of the changes you made.

A PR may not be immediately rejected if these conditions aren't met, but they are ultimately required.
If you need help, please ask!
