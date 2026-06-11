@echo off
chcp 65001 >nul
cd /d "%~dp0"

set LOGFILE=%~dp0lancer_cogify.log
echo [Cogify] Demarrage : %date% %time% > "%LOGFILE%"

if exist "%ProgramData%\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=%ProgramData%\miniconda3\condabin\conda.bat"
) else if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\miniconda3\condabin\conda.bat"
) else if exist "%ProgramData%\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=%ProgramData%\Anaconda3\condabin\conda.bat"
) else if exist "%USERPROFILE%\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\Anaconda3\condabin\conda.bat"
) else (
    echo [Cogify] Conda introuvable. Lancez install.bat ^(a la racine du dossier^) d'abord. >> "%LOGFILE%"
    exit /b 1
)

echo [Cogify] Conda trouve : %CONDA_BAT% >> "%LOGFILE%"

call "%CONDA_BAT%" activate cogify >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    echo [Cogify] Echec de l'activation de l'environnement "cogify". >> "%LOGFILE%"
    exit /b 1
)

if not exist "%USERPROFILE%\.streamlit" mkdir "%USERPROFILE%\.streamlit"
if not exist "%USERPROFILE%\.streamlit\credentials.toml" (
    echo [general] > "%USERPROFILE%\.streamlit\credentials.toml"
    echo email = "" >> "%USERPROFILE%\.streamlit\credentials.toml"
)

echo [Cogify] Environnement active, lancement de Streamlit... >> "%LOGFILE%"
streamlit run app.py >> "%LOGFILE%" 2>&1
