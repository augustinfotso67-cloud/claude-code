@echo off
REM Trading Algo Office - launcher Windows (double-clic)
cd /d "%~dp0"
echo.
echo  ===========================================
echo   Trading Algo Office - bureau virtuel 3D
echo  ===========================================
echo.
echo  Le navigateur va s'ouvrir automatiquement.
echo  Laisse cette fenetre OUVERTE pendant que tu utilises le bureau.
echo  Pour fermer : Ctrl+C ou ferme cette fenetre.
echo.

REM Cherche Python (py launcher d'abord, puis python)
where py >nul 2>&1
if %errorlevel%==0 (
    start "" http://localhost:8765
    py -m http.server 8765
    goto :end
)
where python >nul 2>&1
if %errorlevel%==0 (
    start "" http://localhost:8765
    python -m http.server 8765
    goto :end
)

echo  [ERREUR] Python n'est pas installe.
echo  Telecharge-le sur https://www.python.org/downloads/
echo  (coche "Add Python to PATH" pendant l'installation)
echo.
pause

:end
