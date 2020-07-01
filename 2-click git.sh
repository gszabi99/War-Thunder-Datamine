#!/bin/bash
VER=`cat D:/WarThunder/datamine/monitor/version.txt`
git add .
git commit -am "$VER"
git tag $VER
git push origin $VER
git push