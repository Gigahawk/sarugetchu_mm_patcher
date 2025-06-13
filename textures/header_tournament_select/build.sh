#!/usr/bin/env bash


IMG_WIDTH=256
IMG_HEIGHT=32
IMG_BPP=4
IMG_COLORS=$((2**IMG_BPP))

# トーナメントセレクト
STRING="TOURNAMENT SELECT"
FONT="Zero-Cool"
FONTSIZE=36
STROKEWIDTH=1.7

echo "Generating header image for '$STRING'"

echo "Cleaning old files"
rm -rf *.png *.aseprite

echo "Generating unscaled image"
magick \
    -background none \
    -font "$FONT" -pointsize "$FONTSIZE" \
    -fill white \
    -stroke black -strokewidth "$STROKEWIDTH" \
    label:"$STRING" out_unscaled.png

TEXT_WIDTH=$(identify -format "%w" out_unscaled.png)
if [ "$TEXT_WIDTH" -gt "$IMG_WIDTH" ]; then
    SCALE_FACTOR=$(awk "BEGIN {print $IMG_WIDTH/$TEXT_WIDTH}")
    NEW_WIDTH=$(awk "BEGIN {print int($TEXT_WIDTH * $SCALE_FACTOR)}")
    echo "Unscaled image is $TEXT_WIDTH wide, needs to be sclaed by $SCALE_FACTOR to $NEW_WIDTH"
    magick out_unscaled.png -resize ${NEW_WIDTH}x! out_scaled.png
else
    cp out_unscaled.png out_scaled.png
fi

echo "Building raw image"
magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    out_scaled.png \
    -gravity west \
    -geometry +0+0 -composite \
    out_raw.png

echo "Quantizing image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- out_raw.png

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png
