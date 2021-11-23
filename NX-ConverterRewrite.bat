@echo off
setlocal ENABLEDELAYEDEXPANSION
if not exist original\ mkdir original\ > nul
copy %1 original\ > nul
set bnpname=%1
set bnpname=%bnpname:.bnp=-NX.bnp%
rem ^ This turns "*.bnp" into "*-NX.bnp", which is then set as the filename of the ported BNP in the final step.
echo Extracting BNP...
echo.
if not exist 7z.exe (curl -s -o 7z.exe https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.exe)
if not exist 7z.dll (curl -s -o 7z.dll https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.dll)
7z x -oextracted\ %1 > nul
if not exist bfresconverter.zip (echo Downloading BfresConverter...&echo.&curl -L -s -o bfresconverter.zip https://gamebanana.com/dl/485626)
7z x -obfresconverter\ bfresconverter.zip > nul
del bfresconverter.zip
mkdir bfresconverter\batch-temp\
rem Preparing extracted\ to be passed to BCML auto-conversion
for /r . %%z in (*.sbfres) do (move "%%z" bfresconverter\batch-temp > nul)
for /r . %%y in (*.sbitemico) do (move "%%y" bfresconverter\batch-temp > nul)
if exist "extracted\logs\actorinfo.yml" (move "extracted\logs\actorinfo.yml" .) > nul
rem BCML's converter doesn't like options right now, so I'm moving it off to the side.
rem This should be fixed once BCML 3.7.1 is published.
if exist "extracted\options" (move "extracted\options" .) > nul
del %1
rem ^ The "> nul" silences the command so that it doesn't keep logging that it successfully moved things around.

echo Running BCML auto-conversion...
call :print_convert-py
convert.py
del convert.py

echo.
echo Converting actorinfo...
echo.
if exist "actorinfo.yml" (call :print_actorinfo-py)
actorinfo.py
del actorinfo.py
move actorinfo.yml extracted\logs\ > nul

cd bfresconverter\batch-temp\
echo Attempting automatic bfres conversion...
echo.
call :bfresparam
rem ^ This adds all files in the current dir to a variable and passes them to bfresconverter.
move SwitchConverted\*.sbfres ..\..\extracted\01007EF00011E000\romfs\Model > nul
move SwitchConverted\*.sbitemico ..\..\extracted\01007EF00011E000\romfs\UI\StockItem > nul
cd ..\..
rem I just discovered I can do ..\.. to go up 2 levels, and it's awesome.
rmdir /Q /S bfresconverter
cd extracted\
echo Converting HKX...
if not exist HKXConvert.exe (
	echo Downloading HKXConverter...
	curl -L -# -o HKXConvert.exe https://github.com/krenyy/HKXConvert/releases/download/1.0.1/HKXConvert.exe
)
:HKX
for /r . %%f in (*.sbactorpack) do (
	sarc x --directory temp "%%f"
	if errorlevel 1 (pip install sarc&goto :HKX)
	rem This (hopefully) stops sarc from being a dependency
	del "%%f"
	
	rem Searches recursively for files with an extension starting with *.hk,
	rem then converts them to json and back to NX using HKXConvert.
	for /r . %%x in (*.hk*) do (
		echo.
		echo Converting to JSON...
		HKXConvert.exe hkx2json "%%x" hkcl.json
		del "%%x"
		echo Converting to HKCL...
		echo.
		HKXConvert.exe json2hkx --nx hkcl.json "%%x"
		del hkcl.json
	)
	rem Repackage back into SARC
	sarc c temp "%%f"
	rmdir temp /S /Q
)
if exist "HKXConvert.exe" del HKXConvert.exe
echo.
echo Finished automatic conversion.
echo Zipping new BNP...
copy ..\7z.exe . > nul
copy ..\7z.dll . > nul
7z a %bnpname% 01007EF00011E000 logs info.json > nul
move %bnpname% .. > nul
cd ..
rmdir /S /Q extracted\
del 7z.exe
del 7z.dll
pause
cls
echo Automatic conversion completed. BfresConverter can make mistakes, so take a look at the original file
echo and make sure all your bfres files are accounted for. If some didn't get converted, try running them
echo through BfresConverter manually.
pause
exit

:print_convert-py
rem Calls BCML in Python to auto-convert the remaining files.
echo from pathlib import Path > convert.py
echo from bcml.dev import convert_mod >> convert.py
echo def main():  >> convert.py
echo     warnings = convert_mod(Path(r"%CD%\extracted"), False, True) >> convert.py
echo if __name__ == "__main__":  >> convert.py
echo     main()  >> convert.py
exit /b

:print_actorinfo-py
rem Multiplies all instSize entries in actorinfo log by 1.6, then puts it in the auto-converted mod.
rem This is rather inaccurate, but I don't know what I'm doing enough to implement a more accurate
rem version. I was going to use BCML's implementation, but it seems to break frequently. Will file a
rem GitHub issue later.
echo from oead import byml, S32 > actorinfo.py
echo actorinfo = byml.from_text(open(r"%CD%\actorinfo.yml", "r", encoding="utf-8").read())  >> actorinfo.py
echo for _, actor in actorinfo.items(): >> actorinfo.py
echo     if "instSize" in actor: >> actorinfo.py
echo         actor["instSize"] = S32(int(actor["instSize"].v * 1.6))  >> actorinfo.py
echo open(r"%CD%\actorinfo.yml", "w", encoding="utf-8").write(byml.to_text(actorinfo))  >> actorinfo.py
exit /b

:bfresparam
set params=
@for /f %%i in ('dir /b /a-d') do (set params=!params! "%%i")
..\BfresPlatformConverter.exe %params%
exit /b