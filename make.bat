@echo off

rem RELEASE BUILD
tools\assembler\asm68k /k /m /o ws+ /o op+ /o os+ /o ow+ /o oz+ /o oaq+ /o osq+ /o omq+ /o ae- /o v+ /o c+ /o l. /p main.asm, Mean_Bean.gen, Mean_Bean.sym, Mean_Bean.lst
tools\assembler\convsym.exe Mean_Bean.sym Mean_Bean.gen -a
tools\assembler\fixheader Mean_Bean.gen


if not exist "output\" (
    mkdir "output"
)

move "Mean_Bean.gen" "output/Mean_Bean.gen"
move "Mean_Bean.lst" "output/Mean_Bean.lst"
move "Mean_Bean.sym" "output/Mean_Bean.sym"

pause