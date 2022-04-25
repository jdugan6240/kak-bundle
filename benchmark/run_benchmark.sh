#!/bin/sh

cur_dir=$PWD

# Create benchmark directories
mkdir -p ~/.config/kak/benchmark/plug
mkdir -p ~/.config/kak/benchmark/bundle
mkdir -p ~/.config/kak/benchmark/cork

# Backup current kakrc
mv ~/.config/kak/kakrc ~/.config/kak/benchmark/kakrc_old

# Install cork.kak
curl -o ~/.local/bin/cork https://raw.githubusercontent.com/topisani/cork.kak/master/cork.sh
chmod +x ~/.local/bin/cork

# Install plug.kak
git clone https://github.com/andreyorst/plug.kak.git ~/.config/kak/benchmark/plug/plug.kak

# Install kak-bundle
git clone --branch big-rewrite https://codeberg.org/jdugan6240/kak-bundle.git ~/.config/kak/benchmark/bundle/kak-bundle

# Install all the necessary plugins in each folder (we're only benchmarking startup time here)
# To give each plugin manager a fair chance, we'll do a shallow clone of each repo
IFS=' '
set -- ~/.config/kak/benchmark/cork ~/.config/kak/benchmark/plug ~/.config/kak/benchmark/bundle
for dir in $@; do
    cd "$dir"
    git clone --single-branch --no-tags --depth=1 "https://github.com/raiguard/harpoon.kak"
    git clone --single-branch --no-tags --depth=1 "https://github.com/eraserhd/kak-ansi"
    git clone --single-branch --no-tags --depth=1 "https://github.com/occivink/kakoune-buffer-switcher"
    git clone --single-branch --no-tags --depth=1 "https://github.com/listentolist/kakoune-fandt"
    git clone --single-branch --no-tags --depth=1 "https://github.com/caksoylar/kakoune-focus"
    git clone --single-branch --no-tags --depth=1 "https://github.com/occivink/kakoune-gdb"
    git clone --single-branch --no-tags --depth=1 "https://github.com/JacobTravers/kakoune-grep-write"
    git clone --single-branch --no-tags --depth=1 "https://github.com/delapouite/kakoune-mirror"
    git clone --single-branch --no-tags --depth=1 "https://github.com/natasky/kakoune-multi-file" 
    git clone --single-branch --no-tags --depth=1 "https://github.com/caksoylar/kakoune-smooth-scroll"
    git clone --single-branch --no-tags --depth=1 "https://github.com/occivink/kakoune-sort-selections" 
    git clone --single-branch --no-tags --depth=1 "https://gitlab.com/Screwtapello/kakoune-state-save"
    git clone --single-branch --no-tags --depth=1 "https://github.com/occivink/kakoune-sudo-write" 
    git clone --single-branch --no-tags --depth=1 "https://github.com/delapouite/kakoune-text-objects" 
    git clone --single-branch --no-tags --depth=1 "https://github.com/dgmulf/local-kakrc"
    git clone --single-branch --no-tags --depth=1 "https://github.com/alexherbo2/mark.kak" 
    git clone --single-branch --no-tags --depth=1 "https://github.com/raiguard/rainmeter.kak" 
    git clone --single-branch --no-tags --depth=1 "https://github.com/andreyorst/smarttab.kak"
done

cd $cur_dir
# Run benchmark for plug.kak
cp ./plug.kak-kakrc ~/.config/kak/kakrc
printf "\n\n\n\nPLUG.KAK\n"
hyperfine "kak -ui dummy -e 'quit'"
# Run benchmark for cork.kak
cp ./cork.kak-kakrc ~/.config/kak/kakrc
printf "\n\n\n\nCORK.KAK\n"
hyperfine "kak -ui dummy -e 'quit'"
# Run benchmark for kak-bundle
cp ./kak-bundle-kakrc ~/.config/kak/kakrc
printf "\n\n\n\nKAK-BUNDLE\n"
hyperfine "kak -ui dummy -e 'quit'"

# Restore kakrc at the end
mv ~/.config/kak/benchmark/kakrc_old ~/.config/kak/kakrc

# Delete benchmark folders
rm -rf ~/.config/kak/benchmark
