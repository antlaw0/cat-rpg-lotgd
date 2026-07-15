@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Cat RPG Development Server

rem Use the folder containing this batch file when it is inside the project.
set "PROJECT_DIR=%~dp0"

rem Otherwise, fall back to Anthony's current Cat RPG project location.
if not exist "%PROJECT_DIR%docker-compose.yml" (
    set "PROJECT_DIR=C:\Users\alawl\Desktop\Game Dev Projects\persistent-game\cat-rpg-lotgd"
)

set "GAME_URL=http://localhost/"

if not exist "%PROJECT_DIR%\docker-compose.yml" (
    echo ERROR: docker-compose.yml was not found.
    echo Expected project folder:
    echo %PROJECT_DIR%
    echo.
    echo Put run.bat in the Cat RPG project root or update PROJECT_DIR in this file.
    pause
    exit /b 1
)

cd /d "%PROJECT_DIR%"

where docker >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker was not found in PATH.
    echo Install or repair Docker Desktop, then run this file again.
    pause
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo Docker Desktop is not running. Starting it now...

    if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
        start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
    ) else (
        echo ERROR: Docker Desktop could not be started automatically.
        echo Start Docker Desktop manually, then run this file again.
        pause
        exit /b 1
    )

    set /a DOCKER_ATTEMPTS=0

    :WAIT_FOR_DOCKER
    timeout /t 2 /nobreak >nul
    docker info >nul 2>&1
    if not errorlevel 1 goto DOCKER_READY

    set /a DOCKER_ATTEMPTS+=1
    if !DOCKER_ATTEMPTS! GEQ 60 (
        echo ERROR: Docker Desktop did not become ready.
        echo Open Docker Desktop and check its status.
        pause
        exit /b 1
    )

    goto WAIT_FOR_DOCKER
)

:DOCKER_READY

for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%B"

if defined CURRENT_BRANCH (
    if /i not "!CURRENT_BRANCH!"=="prototype/cat-rpg" (
        echo WARNING: The current Git branch is "!CURRENT_BRANCH!".
        echo The expected Cat RPG development branch is "prototype/cat-rpg".
        echo.
    )
)

if /i "%~1"=="rebuild" (
    echo Rebuilding and starting the Cat RPG containers...
    docker compose up -d --build
) else (
    echo Starting the Cat RPG containers...
    docker compose up -d
)

if errorlevel 1 (
    echo.
    echo ERROR: Docker Compose could not start the project.
    echo Recent container output follows:
    docker compose logs --tail 40
    pause
    exit /b 1
)

rem Ensure the game and Twig cache directory exists and is writable.
docker compose exec -T web sh -lc "mkdir -p /var/www/html/data/cache && chown -R www-data:www-data /var/www/html/data/cache && chmod -R u+rwX,g+rwX /var/www/html/data/cache" >nul 2>&1

echo Waiting for the game server to answer...
set /a WEB_ATTEMPTS=0

:WAIT_FOR_WEB
powershell -NoProfile -Command "try { $response = Invoke-WebRequest -UseBasicParsing -Uri '%GAME_URL%' -TimeoutSec 3; if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto OPEN_GAME

set /a WEB_ATTEMPTS+=1
if !WEB_ATTEMPTS! GEQ 30 goto WEB_NOT_READY

timeout /t 2 /nobreak >nul
goto WAIT_FOR_WEB

:OPEN_GAME
echo.
echo Cat RPG is running at %GAME_URL%
echo Opening the game in your default browser...
start "" "%GAME_URL%"
echo.
docker compose ps
exit /b 0

:WEB_NOT_READY
echo.
echo The containers started, but the website did not answer yet.
echo Check the status and logs with:
echo   docker compose ps
echo   docker compose logs --tail 100 web
echo.
docker compose ps
pause
exit /b 1
