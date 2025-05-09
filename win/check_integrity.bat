@echo off

set "MM_ISO_NAME=mm.iso"
set "MM_ISO_MD5=946D0AEB90772EFD9105B0F785B2C7EC"
set "SDK_ISO_NAME=sdk.iso"
set "SDK_ISO_MD5=C70D267EF19D81AB51E503A76A9882BD"

echo Checking %MM_ISO_NAME% md5
for /f "delims=" %%A in ('.\md5\md5.exe %MM_ISO_NAME%') do (
    echo %%A | find "%MM_ISO_MD5%" >nul
    if not errorlevel 1 (
        echo %MM_ISO_NAME% is correct
    ) else (
        echo Error: wrong or corrupted iso: (got '%%A', expected '%MM_ISO_MD5%')
    )
)

echo Checking %SDK_ISO_NAME% md5
for /f "delims=" %%A in ('.\md5\md5.exe %SDK_ISO_NAME%') do (
    echo %%A | find "%SDK_ISO_MD5%" >nul
    if not errorlevel 1 (
        echo %SDK_ISO_NAME% is correct
    ) else (
        echo Error: wrong or corrupted iso: (got '%%A', expected '%SDK_ISO_MD5%')
    )
)

pause