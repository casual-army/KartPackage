@echo off
git init
git remote add origin git@github.com:casual-army/KartPackage.git
git pull
powershell -c if (-not (Test-Path .\textures.kart)) {Expand-Archive -DestinationPath . .\textures.zip}
start powershell -c $Args=@(); $Args+='-file';$Args+=gci .\mods\loadfirst\*;$Args+='bonuschars.kart';$Args+=gci .\mods\chars\*;$Args+=gci .\mods\tracks\*;$Args+=gci .\mods\music\*;$Args+=gci .\mods\loadlast\*;Start-Process srb2kart.exe -ArgumentList $Args