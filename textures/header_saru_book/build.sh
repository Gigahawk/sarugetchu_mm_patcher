#!/usr/bin/env bash


IMG_WIDTH=256
IMG_HEIGHT=64
IMG_BPP=4
IMG_COLORS=$((2**IMG_BPP))

# サルブック
STRING="MONKEY BOOK"
FONT="Zero-Cool"
FONTSIZE=37
STROKEWIDTH=1.2
STROKECOLOR='#01008B'
BORDERWIDTH=1.5
BORDERCOLOR='#02FDFF'
GRADIENTCOLORS='#FD6600-#FFF302'
GRADIENTHEIGHT=28
GRADIENTOFFSET=$(((IMG_HEIGHT-GRADIENTHEIGHT)/2))

echo "Generating header image for '$STRING'"

#echo "Cleaning old files"
#rm -rf *.png *.aseprite

magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    -font "$FONT" -pointsize "$FONTSIZE" \
    -fill red \
    -gravity center \
    -annotate +0+0 "$STRING" \
    out_no_border_mask.png

magick \
    -size "${IMG_WIDTH}x${GRADIENTHEIGHT}" \
    "gradient:$GRADIENTCOLORS" \
    gradient.png

magick out_no_border_mask.png \
    gradient.png \
    -gravity center \
    -compose Atop -composite \
    out_no_border.png


magick out_no_border.png \
    \( +clone -alpha extract \
        -morphology edge "disk:$STROKEWIDTH" \
        -background "$STROKECOLOR" \
        -alpha shape \) \
    -compose over -composite \
    \( +clone -alpha extract \
        -morphology edgeout "disk:$BORDERWIDTH" \
        -background "$BORDERCOLOR" \
        -alpha shape \) \
    -compose over -composite \
    out_border.png



echo "Quantizing image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- out_border.png

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png
