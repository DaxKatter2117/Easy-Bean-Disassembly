@echo off

cd %~dp0
py Word_to_Byte.py "%~dpnx1" "%~n1.bin"