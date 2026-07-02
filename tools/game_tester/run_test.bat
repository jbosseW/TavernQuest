@echo off
echo ============================================
echo  Tavern Quest Automated Game Tester
echo  Move mouse to any corner to ABORT
echo ============================================
echo.

if "%~1"=="" (
    echo Usage:
    echo   run_test.bat                     Test Tavern Quest RPG mode
    echo   run_test.bat --mode fishing      Test fishing mode
    echo   run_test.bat --all               Test all modes
    echo   run_test.bat --list              List available modes
    echo   run_test.bat --no-launch         Attach to running game
    echo   run_test.bat --duration 120      Set test duration (seconds)
    echo.
    echo Starting default test (Tavern Quest RPG, 60s)...
    echo.
)

python "%~dp0tester.py" %*
pause
