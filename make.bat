@echo off
set LOVEPREFIX="c:\program files (x86)\love"
rmdir /s /q exe
mkdir exe
7z a exe\ld24.zip *.lua assets\*.png assets\*.ttf
copy /b %LOVEPREFIX%\love.exe + exe\ld24.zip exe\ld24.exe
copy %LOVEPREFIX%\*.dll exe
del exe\ld24.zip

