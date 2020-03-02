@echo off
powershell -c "if (-not (Test-Path .\textures.kart)) {Expand-Archive -DestinationPath . .\textures.zip}"
powershell -c $Args=@(); $Args+='-opengl';$Args+='-msaa 16';$Args+='-file';$Args+=gci .\mods\loadfirst\*;$Args+='bonuschars.kart';$Args+=gci .\mods\chars\*;$Args+=gci .\mods\tracks\*;$Args+=gci .\mods\music\*;$Args+=gci .\mods\loadlast\*;Start-Process srb2kart.exe -ArgumentList $Args