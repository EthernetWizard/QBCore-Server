@echo off
echo ============================================
echo   StabCity AI - QBCore Database Setup
echo ============================================
echo.
echo This will create the 'qbcore' database in MariaDB.
echo.

set MYSQL_PATH="C:\Program Files\MariaDB 12.2\bin\mysql.exe"

echo Enter your MariaDB root password:
set /p MYSQL_PASS=Password:

echo.
echo Creating database 'qbcore'...
%MYSQL_PATH% -u root -p%MYSQL_PASS% -e "CREATE DATABASE IF NOT EXISTS qbcore CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Database 'qbcore' created!
    echo.
    echo QBCore will auto-create all tables on first boot.
    echo.
    echo Your connection string for server.cfg:
    echo   set mysql_connection_string "mysql://root:%MYSQL_PASS%@localhost/qbcore"
    echo.
) else (
    echo [ERROR] Failed to create database. Check your password.
    echo.
)

pause
