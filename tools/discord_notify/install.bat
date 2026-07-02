@echo off
echo ==========================================
echo  Tavern Quest Discord Bot - Setup
echo ==========================================
echo.

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.8+ and add to PATH.
    pause
    exit /b 1
)

:: Install dependencies
echo Installing discord.py...
pip install -r "%~dp0requirements.txt"
if errorlevel 1 (
    echo ERROR: pip install failed.
    pause
    exit /b 1
)
echo.

:: Create .env if it doesn't exist
if not exist "%~dp0.env" (
    copy "%~dp0.env.example" "%~dp0.env" >nul
    echo Created .env file from template.
    echo Opening .env in Notepad - paste your token and user ID, then save.
    echo.
    notepad "%~dp0.env"
) else (
    echo .env already exists. Edit it manually if needed:
    echo   %~dp0.env
)

echo.
echo ==========================================
echo  Setup complete!
echo  Run start_bot.bat to launch the bot.
echo ==========================================
pause
