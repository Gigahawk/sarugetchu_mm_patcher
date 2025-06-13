#!/usr/bin/env bash


IMG_WIDTH=256
IMG_HEIGHT=32
IMG_BPP=8
IMG_COLORS=$((2**IMG_BPP))

# ガチャメカセレクト
STRING="LOADOUT"

echo "Generating header image for '$STRING'"

echo "Cleaning old files"
rm -rf *.png *.aseprite

echo "Building raw image"
magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    -font Zero-Cool -pointsize 36 \
    -fill white \
    -stroke black -strokewidth 1.7 \
    -gravity west \
    -annotate +1+0 "$STRING" \
    out_raw.png

echo "Quantizing image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- out_raw.png

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png
