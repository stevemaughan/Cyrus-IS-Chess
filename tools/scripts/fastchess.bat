@echo off
REM ===========================================================================
REM  Cyrus IS Chess: fastchess self-play (AGENTS.md section 6, Phase 4).
REM  Plays the ReleaseSafe build against itself. What matters: zero time
REM  losses, illegal moves, crashes or disconnects.
REM
REM  Usage:   fastchess.bat [tc] [rounds] [concurrency] [overhead_ms] [name]
REM  Examples:
REM      fastchess.bat                     -> tc 1+0.01, 500 rounds, conc 4
REM      fastchess.bat 0.5+0 1000 8 30     -> bullet without increment
REM      fastchess.bat 10+0.1 200 8 30     -> blitz
REM  Set FASTCHESS_DIR to the folder holding fastchess.exe and UHO.pgn, e.g.
REM      setx FASTCHESS_DIR "C:\Chess\FastChess"
REM ===========================================================================
setlocal
cd /d "%~dp0..\.."

if "%FASTCHESS_DIR%"=="" (
  echo Set FASTCHESS_DIR to the folder holding fastchess.exe and UHO.pgn.
  exit /b 1
)
set FC=%FASTCHESS_DIR%\fastchess.exe
set ENG=%CD%\zig-out-safe\bin\cyrus.exe

set TC=%1
if "%TC%"=="" set TC=1+0.01
set ROUNDS=%2
if "%ROUNDS%"=="" set ROUNDS=500
set CONC=%3
if "%CONC%"=="" set CONC=4
set OVERHEAD=%4
if "%OVERHEAD%"=="" set OVERHEAD=30
set NAME=%5
if "%NAME%"=="" set NAME=selfplay

if not exist fastchess-out mkdir fastchess-out
echo Running: tc=%TC%  rounds=%ROUNDS%  concurrency=%CONC%  overhead=%OVERHEAD%ms

"%FC%" ^
  -engine cmd="%ENG%" name=Cyrus-A "option.Seed=1" ^
  -engine cmd="%ENG%" name=Cyrus-B "option.Seed=2" ^
  -each tc=%TC% "option.Move Overhead=%OVERHEAD%" ^
  -rounds %ROUNDS% -repeat ^
  -concurrency %CONC% ^
  -openings file="%FASTCHESS_DIR%\UHO.pgn" format=pgn order=random ^
  -pgnout file="fastchess-out\%NAME%.pgn" timeleft=true ^
  -log file="fastchess-out\%NAME%.log" level=warn ^
  -config outname="fastchess-out\%NAME%-resume.json" ^
  -ratinginterval 50

endlocal
