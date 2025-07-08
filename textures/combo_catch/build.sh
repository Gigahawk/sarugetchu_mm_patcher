#!/usr/bin/env bash

# コンボ ゲッチュ
../build_header.sh \
    -s "COMBO CATCH" \
    -w 128 \
    -h 32 \
    -b 4 \
    -f "Sangyo" \
    -c '#00CBCCCC' \
    --font-size 18 \
    --scale-factor 1.35 \
    -x 15 `# Technically should be 17, but taking all the space we can get` \
    -g west \
    --outline combo
