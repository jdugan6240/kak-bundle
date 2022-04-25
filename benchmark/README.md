# kak-bundle Benchmark #

This is a benchmarking suite measuring the load time of three plugin managers for Kakoune:

- [plug.kak](https://github.com/andreyorst/plug.kak)
- [cork.kak](https://github.com/topisani/cork.kak)
- kak-bundle

The benchmark uses three equivalent configurations for the plugin managers that load the following plugins:

- [harpoon.kak] "https://github.com/raiguard/harpoon.kak"
- [kak-ansi] "https://github.com/eraserhd/kak-ansi"
- [kakoune-buffer-switcher] "https://github.com/occivink/kakoune-buffer-switcher"
- [kakoune-fandt] "https://github.com/listentolist/kakoune-fandt"
- [kakoune-focus] "https://github.com/caksoylar/kakoune-focus"
- [kakoune-gdb] "https://github.com/occivink/kakoune-gdb"
- [kakoune-grep-write] "https://github.com/JacobTravers/kakoune-grep-write"
- [kakoune-mirror] "https://github.com/delapouite/kakoune-mirror"
- [kakoune-multi-file] "https://github.com/natasky/kakoune-multi-file"
- [kakoune-smooth-scroll] "https://github.com/caksoylar/kakoune-smooth-scroll"
- [kakoune-sort-selections] "https://github.com/occivink/kakoune-sort-selections"
- [kakoune-state-save] "https://gitlab.com/Screwtapello/kakoune-state-save"
- [kakoune-sudo-write] "https://github.com/occivink/kakoune-sudo-write"
- [kakoune-text-objects] "https://github.com/delapouite/kakoune-text-objects"
- [local-kakrc] "https://github.com/dgmulf/local-kakrc"
- [mark.kak] "https://github.com/alexherbo2/mark.kak"
- [rainmeter.kak] "https://github.com/raiguard/rainmeter.kak"
- [smarttab.kak] "https://github.com/andreyorst/smarttab.kak"

To give the best chance to each plugin manager, only shallow clones of each plugin are performed to reduce time spent searching
for .kak files, and the `plug-chain` command is utilized for `plug.kak` to speed up load time.

## Running the Benchmark ##

The [hyperfine](https://github.com/sharkdp/hyperfine") tool must be installed to run the benchmark.

To run the benchmark, simply navigate to this directory and run the run_benchmark.sh script.
