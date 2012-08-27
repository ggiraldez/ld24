@echo off

echo Building for 64 bits
set LOVEPREFIX="c:\program files (x86)\love"
rmdir /s /q exe
mkdir exe
7z a exe\ld24.zip *.lua README assets\*.png assets\*.ttf assets\*.wav
copy /b %LOVEPREFIX%\love.exe + exe\ld24.zip exe\pincers.exe
copy %LOVEPREFIX%\*.dll exe
move exe\ld24.zip exe\pincers.love
cd exe
7z a pincers.zip pincers.exe *.dll
cd ..

echo Building for 32 bits
set LOVEPREFIX="D:\love-20120827-0758bba0be8a-win-x86-default"
rmdir /s /q exe32
mkdir exe32
7z a exe32\ld24.zip *.lua README assets\*.png assets\*.ttf assets\*.wav
copy /b %LOVEPREFIX%\love.exe + exe32\ld24.zip exe32\pincers32.exe
copy %LOVEPREFIX%\*.dll exe32
move exe32\ld24.zip exe32\pincers.love
cd exe32
7z a pincers32.zip pincers32.exe *.dll
cd ..

