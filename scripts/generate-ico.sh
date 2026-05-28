#!/bin/sh

# The ImageMagick conversion tool doesn't seem to always generate
# ICO files with background transparency properly. Please validate
# that the output has a transparent background.

magick -background transparent -density 300 ../app/res/vibemis.svg -resize 256x256 -define icon:auto-resize ../app/vibemis.ico
magick -background transparent -density 300 ../app/res/vibemis.svg -resize 64x64 ../app/vibemis_wix.png
magick -background transparent -density 300 ../app/res/vibemis.svg -resize 128x128 ../app/vibemis.png

echo IMPORTANT: Validate the icon has a transparent background before committing!
