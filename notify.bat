@echo off
:: Convenience wrapper - run from project root
:: Usage: notify.bat "message"
:: Rich:  notify.bat -t "Title" -m "Message" -s success -a agent-name
python "%~dp0tools\discord_notify\notify.py" %*
