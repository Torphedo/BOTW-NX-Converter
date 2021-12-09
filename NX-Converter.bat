@echo off
setlocal ENABLEDELAYEDEXPANSION
if not exist original\ mkdir original\ > nul
copy %1 original\ > nul
set bnpname=%1
set bnpname=%bnpname:.bnp=-NX.bnp%
rem ^ This turns "*.bnp" into "*-NX.bnp", which is then set as the filename of the ported BNP in the final step.
sarc --help > nul
cls
if errorlevel 1 (pip install sarc)
rem This stops sarc from being a dependency
echo Extracting BNP...
echo.
if not exist 7z.exe (curl -s -o 7z.exe https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.exe)
if not exist 7z.dll (curl -s -o 7z.dll https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.dll)
7z x -oextracted\ %1 > nul
rem Preparing extracted\ to be passed to BCML auto-conversion
for /r . %%z in (*.sbfres) do (
	if not exist bfresconverter\batch-temp (call :bfres-setup)
	move "%%z" bfresconverter\batch-temp > nul
)
for /r . %%y in (*.sbitemico) do (
	if not exist bfresconverter\batch-temp (call :bfres-setup)
	move "%%y" bfresconverter\batch-temp > nul
)
del %1

echo Running BCML auto-conversion...
call :print_convert-py
convert.py
del convert.py

if exist bfresconverter\batch-temp (
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
)
cd extracted\
if exist "extracted\01007EF00011E000\romfs\Actor\Pack\*.sbactorpack" (
	echo Converting HKX...
	if not exist HKXConvert.exe (
		echo Downloading HKXConverter...
		curl -L -# -o HKXConvert.exe https://github.com/krenyy/HKXConvert/releases/download/1.0.1/HKXConvert.exe
	)
	for /r . %%f in (*.sbactorpack) do (
		if not exist HKXConvert.exe (
			echo Downloading HKXConverter...
			curl -L -# -o HKXConvert.exe https://github.com/krenyy/HKXConvert/releases/download/1.0.1/HKXConvert.exe
		)
		sarc x --directory temp "%%f"
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
)
echo.
echo Finished automatic conversion.
echo Zipping new BNP...
move ..\7z.exe . > nul
move ..\7z.dll . > nul
7z a -x^^!*.exe -x^^!*.dll %bnpname% > nul
move %bnpname% .. > nul
cd ..
rmdir /S /Q extracted\
pause
cls
echo Automatic conversion completed. BfresConverter can make mistakes, so take a look at the original file
echo and make sure all your bfres files are accounted for. If some didn't get converted, try running them
echo through BfresConverter manually.
pause
exit

:bfres-setup
echo Setting up BfresConverter...
echo.
curl -L -s -o bfresconverter.zip https://gamebanana.com/dl/485626
7z x -obfresconverter\ bfresconverter.zip > nul
mkdir bfresconverter\batch-temp\
del bfresconverter.zip
exit /b

:print_convert-py
rem Calls BCML in Python to auto-convert the remaining files.
echo from pathlib import Path > convert.py
echo from bcml.dev import convert_mod >> convert.py
echo def main():  >> convert.py
echo     warnings = convert_mod(Path(r"%CD%\extracted"), False, True) >> convert.py
echo if __name__ == "__main__":  >> convert.py
echo     main()  >> convert.py
exit /b

:bfresparam
set params=
@for /f %%i in ('dir /b /a-d') do (set params=!params! "%%i")
..\BfresPlatformConverter.exe %params%
exit /b
