@echo off

set APP_NAME=%0

set BUILD_TARGET=x64
set BUILD_MODE=.
set TZ_MODE=.
set DATABASE=.
set ALL=.

set VS80_VC_FOLDER=
set VS90_VC_FOLDER=
set VS100_VC_FOLDER=
set VCVARS=bin\amd64\vcvarsamd64.bat

:CHECK_OPTION
if "%1" == "" (GOTO :CHECK_ENV)

if "%1" == "/debug" (
if "%BUILD_MODE%" == "." (
set BUILD_MODE=debug
shift
) else (GOTO :ERROR_BUILD_MODE)
)
if "%1" == "/release" (
if "%BUILD_MODE%" == "." (
set BUILD_MODE=release
shift
) else (GOTO :ERROR_BUILD_MODE)
)
if "%1" == "/new" (
if "%TZ_MODE%" == "." (
set TZ_MODE=new
GOTO :DO_SHIFT
) else (GOTO :ERROR_BUILD_MODE)
)
if "%1" == "/extend" (
if "%TZ_MODE%" == "." (
set TZ_MODE=extend
GOTO :DO_SHIFT
) else (GOTO :ERROR_BUILD_MODE)
)

if "%BUILD_MODE%" == "." (
if "%1" == "/h"            (GOTO :SHOW_USAGE)
if "%1" == "/?"            (GOTO :SHOW_USAGE)
if "%1" == "/help"         (GOTO :SHOW_USAGE)
GOTO :ERROR
) else (
if "%TZ_MODE%" == "." set TZ_MODE=new
GOTO :GET_DATABASE_NAME
)

:DO_SHIFT
shift
GOTO :GET_DATABASE_NAME

:GET_DATABASE_NAME
if not "%1" == "" (
if "%1" == "-d" (
set DATABASE=%2
shift
shift
GOTO :CHECK_OPTION
) else (if "%1" == "-all" (
set ALL=all
shift
GOTO :CHECK_OPTION
) else (GOTO :ERROR_BUILD_MODE)
)
) else (if "%TZ_MODE%" == "extend" ( GOTO :ERROR_BUILD_MODE
) else ( GOTO :CHECK_OPTION ))

:CHECK_ENV

if "%BUILD_MODE%" == "." set BUILD_MODE=release
if "%TZ_MODE%" == "." set TZ_MODE=new

@echo. Matching environment with the selected options...

@echo. Searching for Visual Studio installs...

if NOT "%VS80COMNTOOLS%"=="" (
@echo. Found installation for Visual Studio 2005
)
if NOT "%VS90COMNTOOLS%"=="" (
@echo. Found installation for Visual Studio 2008
)
if NOT "%VS100COMNTOOLS%"=="" (
@echo. Found installation for Visual Studio 2010
)

@echo. Checking for %BUILD_TARGET% configuration...

if exist "%VS90COMNTOOLS%..\..\VC\%VCVARS%" (
@echo. Found %BUILD_TARGET% configuration in Visual Studio 2008.
call "%VS90COMNTOOLS%..\..\VC\%VCVARS%"
goto :BUILD
)

if exist "%VS80COMNTOOLS%..\..\VC\%VCVARS%" (
echo Found %BUILD_TARGET% configuration in Visual Studio 2005.
call "%VS80COMNTOOLS%..\..\VC\%VCVARS%"
goto :BUILD
)

if exist "%VS100COMNTOOLS%..\..\VC\%VCVARS%" (
echo Found %BUILD_TARGET% configuration in Visual Studio 2010.
call "%VS100COMNTOOLS%..\..\VC\%VCVARS%"
goto :BUILD
)

goto :ENV_ERROR

:BUILD
@echo. Running %APP_NAME% with parameters:
@echo.         BUILD_TARGET = %BUILD_TARGET%
@echo.         BUILD_MODE = %BUILD_MODE%
@echo.         TZ_MODE = %TZ_MODE%
if "%TZ_MODE%" == "extend" ( 
if not "%DATABASE%" == "." (
echo          DATABASE_NAME = %DATABASE%
)
)
@echo.

@echo. Generating timezone C file with mode %TZ_MODE% ...

if not "%DATABASE%" == "." (
%CUBRID%\bin\cubrid gen_tz -g %TZ_MODE% %DATABASE%
) else (%CUBRID%\bin\cubrid gen_tz -g %TZ_MODE%)

if %ERRORLEVEL% NEQ 0 goto :ERROR_GENTZ

@echo. Compiling timezone library ...

mkdir %CUBRID%\timezones\tzlib\Output
set CURRENT_DIR=%CD%
cd /D %CUBRID%\timezones\tzlib
nmake -f makefile %BUILD_MODE%
@echo. Done.

cd /D %CURRENT_DIR%

if not exist "%CUBRID%\timezones\tzlib\Output\tzlib.dll" goto :BUILD_FAILED

if exist "%CUBRID%\lib\libcubrid_timezones.dll" (
set curTimestamp=%date:~7,2%_%date:~4,2%_%date:~10,4%_%time:~0,2%_%time:~3,2%
@echo. Found a previous version of the timezone library. Saving it to "%CUBRID%\timezones\old_lib\libcubrid_timezones.%curTimestamp%.dll"...
mkdir %CUBRID%\timezones\old_lib > NUL 2>&1
copy %CUBRID%\lib\libcubrid_timezones.dll %CUBRID%\timezones\old_lib\libcubrid_timezones.%curTimestamp%.dll
)

@echo. Copying %CUBRID%\timezones\tzlib\Output\tzlib.dll to %CUBRID%\lib\libcubrid_timezones.dll ...
copy %CUBRID%\timezones\tzlib\Output\tzlib.dll %CUBRID%\lib\libcubrid_timezones.dll /y
@echo. Done.

@echo. Removing build folder %CUBRID%\timezones\tzlib\Output...
rmdir /S /Q %CUBRID%\timezones\tzlib\Output
@echo. Done.

@echo. Removing timezone C source file %CUBRID%\timezones\tzlib\timezones.c ...
del /Q %CUBRID%\timezones\tzlib\timezones.c
@echo. Done.

@echo. The timezone library has been created at %CUBRID%\lib\libcubrid_timezones.dll
@echo. To check compatibility and synchronize your existing databases, run:
@echo. "SOME SYNC TIMEZONES UTILITY"
goto :eof

:ERROR_TARGET
@echo. Target already set to %BUILD_TARGET%
GOTO :SHOW_USAGE

:ERROR_BUILD_MODE
@echo. Build mode already set to %BUILD_MODE%
@echo. Only one of the options "/new" or "/extend" can be used.
GOTO :SHOW_USAGE

:ERROR
@echo. Invalid parameter %1
GOTO :SHOW_USAGE

:ERROR_GENTZ
@echo. ERROR : cubrid gen_tz -g %TZ_MODE% failed!
goto :GENERIC_ERROR

:ENV_ERROR
@echo. ERROR: Tools and configuration for %BUILD_TARGET% were not found.
goto :GENERIC_ERROR

:BUILD_FAILED
@echo. ERROR: Timezone DLL compile failed!
goto :GENERIC_ERROR

:SHOW_USAGE
@echo.
@echo.USAGE: %APP_NAME% [/release^|/debug] [/new^|/extend] [-d database_name^|-all] (only for extend mode)
@echo.Build timezone shared 32bit DLL for CUBRID
@echo. OPTIONS
@echo.  /release or /debug    Build with release or debug mode (default: release)
@echo.  /new or /extend       Type of timezone library to generate.
@echo.                        See detailed description below for each flag.
@echo.                        By default, /new is used, unless specified otherwise.
@echo.         /new    = build timezone library from scratch; also generates a
@echo.                   C file containing all timezone names (for developers)
@echo.         /extend = build timezone library using the data in the input
@echo.                   folder; timezone IDs encoded into CUBRID are preserved;
@echo.                   new timezones are added; GMT offset and daylight saving
@echo.                   information is updated (or added, for new timezones);
@echo.                   timezone removal is not allowed (if a timezone encoded
@echo.                   into CUBRID is missing from the input files, the
@echo.                   associated data is imported from the old timezone library.
@echo.                   a new C file containing all timezone names is generated,
@echo.                   and it must be included in CUBRID src before the new
@echo.                   timezone library can be used.
@echo.        -d = the flag tells that next is the database name
@echo.        database_name = optional parameter when using extend mode;
@echo.                        the computed timezone checksum is written in
@echo.                        the timezone_checksum column of the db_root
@echo.                        system table;
@echo.        -all = flag that signals that all the databases available on disk
@echo.               will be updated with the new checksum
@echo.  /help /h /?      Display this help message and exit
@echo.
@echo. Examples:
@echo.  %APP_NAME%                  # Build and pack timezone data (32bit/release)
@echo.  %APP_NAME% /debug           # Create debug mode library with timezone data

:GENERIC_ERROR
if exist %CUBRID%\timezones\tzlib\Output (
rmdir /S /Q %CUBRID%\timezones\tzlib\Output
)
if exist %CUBRID%\timezones\tzlib\timezones.c (
del /Q %CUBRID%\timezones\tzlib\timezones.c
)
EXIT /B %ERRORLEVEL%

:eof
