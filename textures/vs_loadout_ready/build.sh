#!/usr/bin/env bash

IMG_COLORS=64
WIDTH=256
HEIGHT=64
# For some reason these are different
BORDERCOLOR='#00FEFF'
FONTCOLOR='#00E3E3'

# セット完了
echo "Building text image"
../build_header.sh \
    -s "READY" \
    -f "ZCOOL-QingKe-HuangYou-Regular" \
    -w $WIDTH \
    -h $HEIGHT \
    -c $FONTCOLOR \
    --num-colors $IMG_COLORS \
    --font-size 43 \
    --font-stroke-width 2 \
    -g "center" \
    -y 1 \
    -x 4 \
    -k 1 \
    --outline "loadout" \
    --no-cut-bottom

echo "Cleaning intermediate files"
rm out_quant.png
rm texture.aseprite

echo "Adding rect border to image"
magick -size "${WIDTH}x${HEIGHT}" xc:none \
  -fill none -stroke $BORDERCOLOR -strokewidth 6 \
  -draw "roundRectangle 4,9 251,55 7,7" \
  \( \
    +clone -alpha extract \
    -morphology edgein diamond:2 \
    -auto-level \
    -background black \
    -alpha shape \
    -write border_outline.png \
  \) \
  -compose over -composite \
  out_border1.png \
  -compose over -composite \
  out_complete.png

echo "Quantizing final image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- "out_complete.png"

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png