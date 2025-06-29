gcc PWDumpX.c -o PWDumpX.exe -lmpr -ladvapi32
gcc -c DumpSvc.c
gcc -c -DBUILD_DLL DumpExt.c md5.c rc4.c
gcc -shared -o DumpExt.dll -Wl,--out-implib,libDumpExt.a DumpExt.o md5.o rc4.o
gcc -o DumpSvc.exe DumpSvc.o -L./ -lDumpExt
