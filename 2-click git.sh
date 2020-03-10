#!/bin/bash
VER=`cat D:/WarThunder/datamine/char.vromfs.bin_u/version`
git commit -am "$VER"
git push