#!/bin/bash

for size in 16 24 32 48 64 128 256 512; do
  inkscape --export-filename="favicon_${size}.png" \
           --export-width=$size --export-height=$size favicon.svg
done

convert favicon_{16,24,32,48,64,128,256,512}.png favicon.ico
rm favicon_{16,24,32,48,64,128,256,512}.png