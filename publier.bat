@echo off
rem Double-clic = publication. Tout le travail est dans publier_web.ps1.
cd /d "%~dp0"
if not exist "%~dp0publier_web.ps1" (
  echo.
  echo publier_web.ps1 est introuvable dans ce dossier.
  echo Relancez Visionneuse web dans Revit sur CE dossier, en cochant
  echo "Ecrire publier.bat".
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publier_web.ps1"
rem Si PowerShell lui-meme a echoue, la fenetre ne doit PAS se refermer
rem sans rien dire : c'est exactement ce qui s'etait passe.
if errorlevel 1 (
  echo.
  echo La publication s'est arretee. Message ci-dessus.
  pause
)
