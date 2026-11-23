@echo off
rem Runs the Firebase CLI that setup_local_tools.ps1 placed in local_tools (Node 22 + firebase-tools).
rem Usage (online_setup.md): firebase_local.cmd login / use --add / deploy --only functions,firestore
setlocal
set "NODE_DIR=%~dp0local_tools\node-v22.23.3-win-x64"
set "CLI=%~dp0local_tools\firebase-cli\node_modules\firebase-tools\lib\bin\firebase.js"
if not exist "%NODE_DIR%\node.exe" goto missing
if not exist "%CLI%" goto missing
set "PATH=%NODE_DIR%;%PATH%"
"%NODE_DIR%\node.exe" "%CLI%" %*
exit /b %ERRORLEVEL%
:missing
echo Firebase CLI not found. Run setup_local_tools.ps1 first (online_setup.md 0-3).
exit /b 1
