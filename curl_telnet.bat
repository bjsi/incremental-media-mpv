@echo off
set addr=telnet://%1:%2
C:\Windows\System32\curl.exe %addr% < %3%