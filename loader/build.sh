#!/bin/sh

echo "\nCompiling loader...\n"
~/bin/sjasmplus/sjasmplus loader.asm
echo "\nCreating HEX output...\n"
./bin2hex --binaries=0,loader.bin --outfile=loader.hex
echo "Done\n\n";

