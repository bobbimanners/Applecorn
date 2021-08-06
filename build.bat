cd /d %0\..

rem build auxmem sources
copy auxhdr.s+mosequ.s+mosinit.s+vdu.s+filesys.s+kernel.s auxmem.s

merlin32 -V . applecorn.s
copy applecorn applecorn#062000
pause
