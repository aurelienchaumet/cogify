@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo   Installation de Cogify
echo ============================================
echo.

rem --- 1. Recherche de conda existant ---
set CONDA_BAT=
if exist "%ProgramData%\miniconda3\condabin\conda.bat" set CONDA_BAT=%ProgramData%\miniconda3\condabin\conda.bat
if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" set CONDA_BAT=%USERPROFILE%\miniconda3\condabin\conda.bat
if exist "%ProgramData%\Anaconda3\condabin\conda.bat" set CONDA_BAT=%ProgramData%\Anaconda3\condabin\conda.bat
if exist "%USERPROFILE%\Anaconda3\condabin\conda.bat" set CONDA_BAT=%USERPROFILE%\Anaconda3\condabin\conda.bat

if not defined CONDA_BAT (
    echo Conda introuvable. Telechargement et installation de Miniconda...
    echo ^(cela peut prendre quelques minutes^)
    echo.

    set MINICONDA_EXE=%TEMP%\miniconda_installer.exe
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe' -OutFile '%MINICONDA_EXE%'"

    if not exist "%MINICONDA_EXE%" (
        echo ERREUR : le telechargement de Miniconda a echoue.
        echo Verifiez votre connexion internet, ou installez Miniconda manuellement :
        echo https://docs.conda.io/en/latest/miniconda.html
        pause
        exit /b 1
    )

    echo Installation silencieuse de Miniconda dans %USERPROFILE%\miniconda3 ...
    start /wait "" "%MINICONDA_EXE%" /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /S /D=%USERPROFILE%\miniconda3

    set CONDA_BAT=%USERPROFILE%\miniconda3\condabin\conda.bat
    del "%MINICONDA_EXE%"
)

if not exist "%CONDA_BAT%" (
    echo ERREUR : conda toujours introuvable apres installation.
    pause
    exit /b 1
)

echo.
echo Conda trouve : %CONDA_BAT%
echo.

rem --- 2. Creation de l'environnement cogify ---
echo Creation de l'environnement "cogify" ^(Python, GDAL, Streamlit^)...
echo ^(cela peut prendre plusieurs minutes^)
call "%CONDA_BAT%" env create -f environment.yml --force
if errorlevel 1 (
    echo ERREUR lors de la creation de l'environnement conda.
    pause
    exit /b 1
)

echo.
echo Environnement "cogify" cree avec succes.
echo.

rem --- 3. Creation du raccourci bureau ---
echo Creation du raccourci sur le bureau...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create_shortcut.ps1"

echo.
echo ============================================
echo   Installation terminee !
echo   Lancez "Cogify" depuis le bureau.
echo ============================================
pause
