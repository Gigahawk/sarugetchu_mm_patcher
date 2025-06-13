#!/usr/bin/env bash


IMG_WIDTH=128
IMG_HEIGHT=16
IMG_BPP=4
IMG_COLORS=$((2**IMG_BPP))

# VS. モード
STRING="VS. MODE"

echo "Generating header image for '$STRING'"

echo "Cleaning old files"
rm -rf *.png *.aseprite

echo "Building raw image"
magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    -font Zero-Cool -pointsize 21 \
    -fill black \
    -gravity east \
    -annotate -2+0 "$STRING" \
    out_raw.png

echo "Quantizing image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- out_raw.png

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png
