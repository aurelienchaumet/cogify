@echo off
cd /d "%~dp0"

if exist "%ProgramData%\miniconda3\condabin\conda.bat" (
    call "%ProgramData%\miniconda3\condabin\conda.bat" activate cogify
) else if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
    call "%USERPROFILE%\miniconda3\condabin\conda.bat" activate cogify
) else if exist "%ProgramData%\Anaconda3\condabin\conda.bat" (
    call "%ProgramData%\Anaconda3\condabin\conda.bat" activate cogify
) else if exist "%USERPROFILE%\Anaconda3\condabin\conda.bat" (
    call "%USERPROFILE%\Anaconda3\condabin\conda.bat" activate cogify
) else (
    echo [Cogify] Conda introuvable. Lancez install.bat ^(a la racine du dossier^) d'abord.
    pause
    exit /b 1
)

streamlit run app.py
