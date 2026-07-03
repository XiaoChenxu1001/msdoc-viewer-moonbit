@echo off
REM Multi-target build script for MS-DOC Viewer

echo === MS-DOC Viewer Multi-Target Build ===

REM Clean build directory to avoid cache issues
echo Cleaning _build directory...
if exist _build rmdir /s /q _build

REM Build JS target (Browser + Node.js)
echo [1/4] Building JS target...
moon build --target js --release
if %ERRORLEVEL% NEQ 0 (echo JS build failed! & exit /b 1)

REM Build JS Worker target (Browser Web Worker)
echo [2/4] Building JS Worker target...
moon build --target js --release worker
if %ERRORLEVEL% NEQ 0 (echo Worker build failed! & exit /b 1)

REM Build WASM linear memory target (Browser WASM)
echo [3/4] Building WASM target...
moon build --target wasm --release
if %ERRORLEVEL% NEQ 0 (echo WASM build failed! & exit /b 1)

REM Build WASM-GC target (MoonBit WASM Runtime)
echo [4/4] Building WASM-GC target...
moon build --target wasm-gc --release
if %ERRORLEVEL% NEQ 0 (echo WASM-GC build failed! & exit /b 1)

echo.
echo === Build Complete ===
echo JS:          _build\js\release\build\core\core.js
echo JS Worker:   _build\js\release\build\worker\worker.js
echo WASM:        _build\wasm\release\build\core\core.wasm
echo WASM-GC:     _build\wasm-gc\release\build\core\core.wasm
echo.
echo Demos (serve project root with any HTTP server):
echo   demo\index.html   - Landing page with all demos
echo   demo\js.html      - JS target demo
echo   demo\wasm.html    - WASM target demo
echo   demo\worker.html  - Web Worker demo
