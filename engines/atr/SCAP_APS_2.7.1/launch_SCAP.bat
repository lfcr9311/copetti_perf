@echo off
for %%i in (%cd%\input\*.xml) do (
	echo Execute file: %%i
	SCAPApp.exe %%i
)
pause