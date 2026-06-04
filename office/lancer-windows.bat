@echo off
REM Trading Algo Office - launcher Windows (double-clic)
REM Ouvre directement index.html dans le navigateur (file://).
REM Pas besoin de Python, pas besoin de serveur local.

cd /d "%~dp0"
echo.
echo  ===========================================
echo   Trading Algo Office - bureau virtuel 3D
echo  ===========================================
echo.
echo  Ouverture de index.html dans le navigateur...
echo.

start "" "%~dp0index.html"

REM Petite pause pour qu'on voie le message si ca a marche
echo  Si rien ne s'ouvre :
echo    1. Va dans ce dossier avec l'Explorateur
echo    2. Double-clic directement sur "index.html"
echo    3. Si la page reste blanche, utilise Chrome ou Edge recent
echo       (les anciens navigateurs ne supportent pas le 3D moderne)
echo.
echo  Cette fenetre va se fermer dans 5 secondes.
timeout /t 5 /nobreak >nul
