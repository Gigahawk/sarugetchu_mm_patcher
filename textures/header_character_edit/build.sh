#!/usr/bin/env bash


IMG_WIDTH=256
IMG_HEIGHT=32
IMG_BPP=8
IMG_COLORS=$((2**IMG_BPP))

# キャラクタエディット
STRING="CHARACTER EDIT"
FONT="Zero-Cool"
FONTSIZE=36
STROKEWIDTH=2
# The texture isn't properly centered even in the original,
# move it down by 1 pixel (all we can do) to compensate
YOFFSET=1

echo "Generating header image for '$STRING'"

echo "Cleaning old files"
rm -rf *.png *.aseprite

echo "Generating unscaled image"
magick \
    -background none \
    -font "$FONT" -pointsize "$FONTSIZE" \
    -fill white \
    label:"$STRING" out_unscaled.png

TEXT_WIDTH=$(identify -format "%w" out_unscaled.png)
if [ "$TEXT_WIDTH" -gt "$IMG_WIDTH" ]; then
    SCALE_FACTOR=$(awk "BEGIN {print $IMG_WIDTH/($TEXT_WIDTH + 2 * $STROKEWIDTH)}")
    NEW_WIDTH=$(awk "BEGIN {print int($TEXT_WIDTH * $SCALE_FACTOR)}")
    echo "Unscaled image is $TEXT_WIDTH wide, needs to be sclaed by $SCALE_FACTOR to $NEW_WIDTH"
    magick out_unscaled.png -resize ${NEW_WIDTH}x! out_scaled.png
else
    cp out_unscaled.png out_scaled.png
fi

echo "Compositing scaled image onto correct size image"
magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    out_scaled.png \
    -gravity center \
    -geometry "+0+${YOFFSET}" -composite\
    out_no_border.png

echo "Compositing outline onto text"
magick out_no_border.png \
    \( +clone -alpha extract \
        -morphology edgeout "square:$STROKEWIDTH" \
        -background "black" \
        -alpha shape \) \
    -compose over -composite \
    out_raw.png

echo "Quantizing image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- out_raw.png

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png
