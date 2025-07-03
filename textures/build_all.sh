#!/usr/bin/env bash


mapfile -t scripts < <(find . -type f -name 'build.sh')

# Sequentially run each one
for script_path in "${scripts[@]}"; do
    script_dir=$(dirname "$script_path")
    cd "$script_dir" || exit 1
    echo "Running $script_path"
    ./build.sh || exit 1
    cd - > /dev/null || exit 1
done
