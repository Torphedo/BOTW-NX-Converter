@echo off
setlocal ENABLEDELAYEDEXPANSION
if not exist original\ mkdir original\ > NUL
copy %1 original\ > NUL
if errorlevel = 1 (goto :ERROR)
set bnpname=%1
set bnpname=%bnpname:.bnp=-NX.bnp%
rem ^ This turns "*.bnp" into "*-NX.bnp", which is then set as the filename of the ported BNP in the final step.
echo Extracting BNP...
curl -s -o 7z.exe https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.exe
curl -s -o 7z.dll https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.dll
7z x -oextracted\ %1 > NUL
echo Downloading BfresConverter...
curl -L -s -o bfresconverter.zip https://gamebanana.com/dl/485626
7z x -obfresconverter\ bfresconverter.zip > NUL
del bfresconverter.zip
mkdir bfresconverter\batch\
rem Moves all files that BCML can't auto-convert out of the way
if exist "extracted\logs\actorinfo.yml" (move "extracted\logs\actorinfo.yml" .) > NUL
if exist "extracted\content\Model" (move "extracted\content\Model" bfresconverter\batch\) > NUL
if exist "extracted\content\UI" (move "extracted\content\UI" bfresconverter\batch\) > NUL
rem BCML doesn't like options\, so I'm moving it off to the side.
if exist "extracted\options" (move "extracted\options" .) > NUL
del %1
del 7z.exe
del 7z.dll
rem ^ The "> NUL" silences the command so that it doesn't keep logging that it successfully moved things around.
rem (specifically, it's sending the command output to "NUL")

echo Running BCML auto-conversion...
rem Runs the remaining files through BCML's auto-converter.
echo from pathlib import Path > convert.py
echo from bcml.dev import convert_mod >> convert.py
echo def main():  >> convert.py
echo     warnings = convert_mod(Path(r"%CD%\extracted"), False, True) >> convert.py
echo if __name__ == "__main__":  >> convert.py
echo     main()  >> convert.py
convert.py
del convert.py

Echo Converting actorinfo...
rem Multiplies all instSize entries in actorinfo log by 1.6, then puts it in the auto-converted mod.
if not exist "actorinfo.yml" (goto :dumb_skip)
rem I despise the above if statement, for some reason batch really hates it when I print this python script inside the if statement.
echo from oead import byml, S32 > actorinfo.py
echo actorinfo = byml.from_text(open(r"%CD%\actorinfo.yml", "r", encoding="utf-8").read())  >> actorinfo.py
echo for _, actor in actorinfo.items(): >> actorinfo.py
echo     if "instSize" in actor: >> actorinfo.py
echo         actor["instSize"] = S32(int(actor["instSize"].v * 1.6))  >> actorinfo.py
echo open(r"%CD%\actorinfo.yml", "w", encoding="utf-8").write(byml.to_text(actorinfo))  >> actorinfo.py
actorinfo.py
del actorinfo.py
move actorinfo.yml extracted\logs\ > NUL
:dumb_skip
cd bfresconverter\batch\
echo Attempting automatic bfres conversion...
if exist "Model" (
	move Model\*.sbfres . > NUL
	set filetype=sbfres
	call :bfresparam
	rem ^ This adds all sbfres files in the current dir to a variable and passes them to bfresconverter.
	move SwitchConverted\*.sbfres Model\ > NUL
	move Model ..\..\extracted\01007EF00011E000\romfs\ > NUL
)
if exist "UI" (
	move UI\StockItem\*.sbitemico . > NUL
	set filetype=sbitemico
	call :bfresparam
	rem This gets a littl confusing, but I'm just putting all the newly converted assets back into the rest of the mod files.
	move SwitchConverted\*.sbitemico UI\StockItem\ > NUL
	move UI ..\..\extracted\01007EF00011E000\romfs\ > NUL
)
cd ..\..
rem I just discovered I can do ..\.. to go up 2 levels, and it's awesome.
rmdir /Q /S bfresconverter
echo Finished automatic conversion.
cd extracted\
echo Zipping new BNP...
curl -s -o 7z.exe https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.exe
curl -s -o 7z.dll https://raw.githubusercontent.com/NiceneNerd/BCML/master/bcml/helpers/7z.dll
7z a %bnpname% 01007EF00011E000 logs info.json > NUL
move %bnpname% .. > NUL
cd ..
rmdir /S /Q extracted\
pause
cls
echo Automatic conversion completed. BfresConverter can make mistakes, so take a look at the original file
echo and make sure all your bfres files are accounted for. If some didn't get converted, try running them
echo through BfresConverter manually.
pause
exit

:bfresparam
set params=
@for /f %%i in ('dir /b /a-d') do (set params=!params! "%%i")
..\BfresPlatformConverter.exe %params%
del *.%filetype%
exit /b

:ERROR
rmdir original
echo Please drag a BNP onto this batch script.
pause