@echo off

cd %~dp0
py Puyo_Compressor.py "%~dpnx1" "%~n1.cmp"