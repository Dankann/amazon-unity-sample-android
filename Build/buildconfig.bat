:: Copyright 2018 Amazon
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.

@ECHO OFF

REM THIS BATCH FILE IS CALLED FROM BUILD.BAT WITH A NAMED CONFIGURATION NAME AS A PARAMETER. THE BATCH FILE BUILDS THE UNITY
REM PROJECT INTO THE IMAGE OF THE SAME NAME. THIS MEANS WE CAN HAVE A UNITY DEBUG SERVER BUILD, A UNITY RELEASE CLIENT BUILD AND
REM SO ON, WHICH OTHERWISE REQUIRES TO BE MANUALLY SET UP IN THE UNITY EDITOR.

REM PLUGINS MUST ALREADY BE BUILT BY NOW

SETLOCAL ENABLEDELAYEDEXPANSION

REM ------- FIND MY ABSOLUTE ROOT -------
SET REL_ROOT=..\
SET ABS_ROOT=
PUSHD %REL_ROOT%
SET ABS_ROOT=%CD%
POPD

REM ------- BUILD NAMED CONFIGURATION (NOT CURRENTLY DEFAULT) -------
REM IS A CONFIGURATION SPECIFIED ON THE COMMAND LINE?
IF "%1" == "" GOTO BUILDDEFAULT
SET CONFIGNAME=%1

CALL LOADCONFIG.BAT %CONFIGNAME%
GOTO BUILD


:BUILDDEFAULT
REM ------- BUILD NAMED CONFIGURATION (DEFAULT) -------
REM WE WILL JUST BUILD THE DEFAULT CONFIGURATION, I.E. WHATEVER IS AT  %ABS_ROOT%\ProjectSettings PROVIDING IT IS NAMED

REM IS THIS A NAMED CONFIGURATION?
IF EXIST %ABS_ROOT%\ProjectSettings\configname GOTO BUILDNAMEDDEFAULT

REM IT WASN'T NAMED
ECHO NO CONFIG NAME WAS AVAILABLE FOR THE DEFAULT CONFIGURATION. USE SAVECONFIG.BAT WITH A NAME TO NAME IT.
EXIT /B 3


:BUILDNAMEDDEFAULT
REM YES, LOAD THE NAME
SET /P CONFIGNAME=<%ABS_ROOT%\ProjectSettings\configname

REM REMOVE LEADING/TRAILING WHITESPACE
FOR /F "TOKENS=* DELIMS= " %%A IN ("%CONFIGNAME%") DO SET CONFIGNAME=%%A
FOR /L %%A IN (1,1,100) DO IF "!CONFIGNAME:~-1!"==" " SET CONFIGNAME=!CONFIGNAME:~0,-1!


:BUILD
ECHO BUILDING %CONFIGNAME%


:KILLUNITY
REM TASKKILL KILLS THE UNITY.EXE PROCESS IF IT IS RUNNING.
TASKLIST | FIND /I "UNITY.EXE" >NUL && (
    TASKKILL /IM "UNITY.EXE" /F 2> NUL
    GOTO KILLUNITY
)


REM REMOVE OLD OUTPUT FOLDER
IF EXIST "%ABS_ROOT%\Output\%CONFIGNAME%" RMDIR /S /Q "%ABS_ROOT%\Output\%CONFIGNAME%"


REM WHICH UNITY EXECUTABLE WILL WE USE?
FOR /f "delims=" %%F IN ('DIR "%ProgramFiles%\Unity\Hub\Editor\" /b /on') DO SET UNITYVERSION=%%F
IF EXIST "%ProgramFiles%\Unity\Hub\Editor\%UNITYVERSION%\Editor\Unity.exe" (
    SET UNITYEXE="%ProgramFiles%\Unity\Hub\Editor\2019.4.17f1\Editor\Unity.exe"
) ELSE (
    IF EXIST "%ProgramFiles%\Unity\Hub\Editor" GOTO ERRORINVALUNITY
    IF EXIST "%ProgramFiles(x86)%\Unity\Editor\Unity.exe" SET UNITYEXE="%ProgramFiles(x86)%\Unity\Editor\Unity.exe"
    IF EXIST "%ProgramFiles%\Unity\Editor\Unity.exe" SET UNITYEXE="%ProgramFiles%\Unity\Editor\Unity.exe"
)
IF "" EQU "%UNITYEXE%" GOTO ERRORNOUNITY
ECHO USING %UNITYEXE% TO BUILD


REM DO A BUILD OF THE STANDALONE USING THE UNITY COMMAND LINE.
%UNITYEXE% -batchmode -buildTarget Win64 -projectPath "%ABS_ROOT%" -buildWindows64Player "%ABS_ROOT%\Output\%CONFIGNAME%\Image\GameLiftUnity.exe" -quit


REM DID THE BUILD COMPLETE SUCCESSFULLY?
IF NOT EXIST "%ABS_ROOT%\Output\%CONFIGNAME%\Image\GameLiftUnity.exe" GOTO BUILDFAILED

REM COPY THE PLUGIN TO THE BUILD DIRECTORY
COPY %ABS_ROOT%\Output\Intermediate\GameLiftClientSDKPlugin\Release\GameLiftClientSDKPlugin.dll %ABS_ROOT%\Output\%CONFIGNAME%\Image\GameLiftUnity_Data\Plugins > NUL
COPY %ABS_ROOT%\Plugin\Sdk\GameLiftServer\GameLift-CSharpSDK-3.1.3\Net35\bin\Release\*.dll %ABS_ROOT%\Output\%CONFIGNAME%\Image\GameLiftUnity_Data\Plugins > NUL


REM FINISHED
ECHO BUILD COMPLETED SUCCESSFULLY. SEE %LOCALAPPDATA%\Unity\Editor\Editor.log
EXIT /B 0

:BUILDFAILED
ECHO BUILD FAILED: LOG AT %LOCALAPPDATA%\Unity\Editor\Editor.log
ECHO SEE %ABS_ROOT%\Build\buildconfig.bat
EXIT /B 0

:ERRORNOUNITY
ECHO "%ProgramFiles(x86)%\Unity\Editor\Unity.exe" OR "%ProgramFiles%\Unity\Editor\Unity.exe" NOT FOUND
ECHO BUILD FAILED: UNITY IS NOT INSTALLED
ECHO SEE %ABS_ROOT%\Build\buildconfig.bat
EXIT /B 0

:ERRORINVALUNITY
ECHO "%ProgramFiles(x86)%\Unity\Hub\Editor\" WAS FOUND BUT A VALID VERSION WAS NOT
ECHO BUILD FAILED: UNITY IS NOT VALID VERSION
ECHO SEE %ABS_ROOT%\Build\buildconfig.bat
EXIT /B 0
