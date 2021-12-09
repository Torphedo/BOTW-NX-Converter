@echo off
if exist "NX-Converter.exe" (del "NX-Converter.exe")
if exist "target\release\NX-Converter.exe" (del "target\release\NX-Converter.exe")
echo Building bcml-installer...
cargo build --release
echo Build finished.
copy "target\release\NX-Converter.exe" . > NUL
pause
cls
NX-Converter.exe