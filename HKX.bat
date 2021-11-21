@echo off
:HKX
for /r . %%f in (*.sbactorpack) do (
	sarc x --directory temp "%%f"
	if errorlevel 1 (pip install sarc&goto :HKX)
	rem This (hopefully) stops sarc from being a dependency
	del "%%f"
	
	if not exist HKXConvert.exe (
		echo Downloading HKXConverter...
		curl -L -# -o HKXConvert.exe https://github.com/krenyy/HKXConvert/releases/download/1.0.1/HKXConvert.exe
	)
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
	sarc c --be temp "%%f"
	rmdir temp /S /Q
)
if exist "HKXConvert.exe" del HKXConvert.exe