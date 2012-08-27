@echo off
set LOVEPREFIX="c:\program files (x86)\love"
rmdir /s /q exe
mkdir exe
7z a exe\ld24.zip *.lua README assets\*.png assets\*.ttf assets\*.wav
copy /b %LOVEPREFIX%\love.exe + exe\ld24.zip exe\pincers.exe
copy %LOVEPREFIX%\*.dll exe
del exe\ld24.zip
cd exe
7z a pincers.zip pincers.exe *.dll

