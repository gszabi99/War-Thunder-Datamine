#!/bin/bash
VER=`cat D:/WarThunder/datamine/char.vromfs.bin_u/version`
git add .
git commit -am "$VER"
git tag $VER
git push origin $VER