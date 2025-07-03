#!/usr/bin/env bash

# Default values
IMG_WIDTH=256
IMG_HEIGHT=32
IMG_BPP=8
IMG_COLORS=""
STRING=""
FONT="Zero-Cool"
FONTSIZE=35
FONTCOLOR="white"
FONTSTROKECOLOR=""
FONTSTROKEWIDTH=0
KERNING=0
CLEAN=true
CUT_BOTTOM=0
TOTAL_OUTLINE_WIDTH=0
GRAVITY=west
XOFFSET=""
MARGIN=1
YOFFSET=0
SCALE_FACTOR=""

OUTLINE_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--width)
            IMG_WIDTH="$2"
            shift
            shift
            ;;
        -h|--height)
            IMG_HEIGHT="$2"
            shift
            shift
            ;;
        -g|--gravity)
            GRAVITY="$2"
            shift
            shift
            ;;
        -b|--bpp)
            IMG_BPP="$2"
            shift
            shift
            ;;
        -n|--num-colors)
            IMG_COLORS="$2"
            shift
            shift
            ;;
        -s|--string)
            STRING="$2"
            shift
            shift
            ;;
        -f|--font)
            FONT="$2"
            shift
            shift
            ;;
        --font-size)
            FONTSIZE="$2"
            shift
            shift
            ;;
        --font-stroke-width)
            FONTSTROKEWIDTH="$2"
            shift
            shift
            ;;
        --font-stroke-color)
            FONTSTROKECOLOR="$2"
            shift
            shift
            ;;
        -y|--y-offset)
            YOFFSET="$2"
            shift
            shift
            ;;
        -x|--x-offset)
            XOFFSET="$2"
            shift
            shift
            ;;
        -m|--margin)
            MARGIN="$2"
            shift
            shift
            ;;
        -c|--color)
            FONTCOLOR="$2"
            shift
            shift
            ;;
        -k|--kerning)
            KERNING="$2"
            shift
            shift
            ;;
        --outline)
            if [[ "$2" == "mainmenu" ]]; then
                method="edgeout"
                kernel="square"
                width="2"
                color="black"
                shift
                shift
            elif [[ "$2" == "tournament" ]]; then
                method="edgeout"
                kernel="square"
                width="4"
                color="'#000000ff'"
                shift
                shift
            elif [[ "$2" == "loadout" ]]; then
                method="edge"
                kernel="diamond"
                width="1"
                color="black"
                shift
                shift
            elif [[ "$2" == "loadoutwait" ]]; then
                method="edge"
                kernel="diamond"
                width="1"
                color="black"
                shift
                shift
            else
                method="$2"
                kernel="$3"
                width="$4"
                color="$5"
                shift
                shift
                shift
                shift
                shift
            fi
            OUTLINE_ARGS+=("\( +clone -alpha extract -morphology $method $kernel:$width -auto-level -background $color -alpha shape -write outline.png \)")
            TOTAL_OUTLINE_WIDTH=$((TOTAL_OUTLINE_WIDTH + width))
            ;;
        --scale-factor)
            SCALE_FACTOR="$2"
            shift
            shift
            ;;
        --no-clean)
            CLEAN=false
            shift
            ;;
        --cut-bottom)
            CUT_BOTTOM="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if [[ -z "$STRING" ]]; then
    echo "Error: a string must be provided"
    exit 1
fi

if [[ -z "$IMG_COLORS" ]]; then
    IMG_COLORS=$((2**IMG_BPP))
fi

if [[ -z "$FONTSTROKECOLOR" ]]; then
    FONTSTROKECOLOR=$FONTCOLOR
fi


if [[ -z "$XOFFSET" ]]; then
    # Avoid outline going past edge of font
    XOFFSET=$TOTAL_OUTLINE_WIDTH
fi

if [[ "$YOFFSET" -ge 0 ]]; then
    YOFFSET="+${YOFFSET}"
fi
if [[ "$XOFFSET" -ge 0 ]]; then
    XOFFSET="+${XOFFSET}"
fi

echo "Generating header image for '$STRING'"

if [[ "$CLEAN" == true ]]; then
    echo "Cleaning old files"
    rm -rf *.png *.aseprite
fi

echo "Generating unscaled image"
magick \
    -background none \
    -font "$FONT" -pointsize "$FONTSIZE" \
    -fill "$FONTCOLOR" \
    -stroke "$FONTSTROKECOLOR" -strokewidth $FONTSTROKEWIDTH \
    -kerning "$KERNING" \
    label:"$STRING" out_unscaled.png

TEXT_WIDTH=$(identify -format "%w" out_unscaled.png)
if [[ -z "$SCALE_FACTOR" ]]; then
    if [[ "$TEXT_WIDTH" -gt "$IMG_WIDTH" ]]; then
        SCALE_FACTOR=$(awk "BEGIN {print ($IMG_WIDTH - 2 * $MARGIN)/($TEXT_WIDTH + 2 * $TOTAL_OUTLINE_WIDTH)}")
        NEW_WIDTH=$(awk "BEGIN {print int($TEXT_WIDTH * $SCALE_FACTOR)}")
        echo "Unscaled image is $TEXT_WIDTH wide, needs to be scaled by $SCALE_FACTOR to $NEW_WIDTH"
        magick out_unscaled.png -resize ${NEW_WIDTH}x! out_scaled.png
    else
        echo "Unscaled image fits in texture"
        cp out_unscaled.png out_scaled.png
    fi
else
    echo "Scaling image to provided scale factor $SCALE_FACTOR"
    NEW_WIDTH=$(awk "BEGIN {print int($TEXT_WIDTH * $SCALE_FACTOR)}")
    magick out_unscaled.png -resize ${NEW_WIDTH}x! out_scaled.png
fi

echo "Compositing scaled image onto correct size image"
magick \
    -size "${IMG_WIDTH}x${IMG_HEIGHT}" \
    xc:transparent \
    out_scaled.png \
    -gravity "$GRAVITY" \
    -geometry "${XOFFSET}${YOFFSET}" -composite \
    out_no_border.png

if [[ "$CUT_BOTTOM" -gt 0 ]]; then
    # https://stackoverflow.com/a/64823099
    # For some reason this doesn't work properly if it's included in the previous
    # magick call
    echo "Cropping out bottom to allow room for border to wrap dangling tails"
    magick out_no_border.png \
        \( \
            +clone \
            -alpha extract \
            -fill black \
            -draw "rectangle 0,$((IMG_HEIGHT - CUT_BOTTOM)),${IMG_WIDTH},${IMG_HEIGHT}" \
            -write alpha_mask.png \
        \) \
        -alpha off -compose copyalpha -composite \
        out_border0.png
else
    echo "Skipping bottom crop step"
    cp out_no_border.png out_border0.png
fi

num_borders=${#OUTLINE_ARGS[@]}
for ((i=0;i<num_borders;i++)); do
    src="out_border${i}.png"
    target="out_border$((i + 1)).png"
    echo "Compositing outline onto image (going from $src to $target)"

    cmd="magick $src ${OUTLINE_ARGS[$i]} -compose over -composite $target"
    echo "$cmd"
    eval "$cmd"
done

echo "Quantizing final image"
pngquant -f --output out_quant.png --speed 1 "$IMG_COLORS" -- "out_border${num_borders}.png"

echo "Converting to aseprite"
ssmm-patcher img-to-aseprite -o texture.aseprite out_quant.png