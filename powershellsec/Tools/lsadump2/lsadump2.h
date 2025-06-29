/***************************************************************************
 * 
 * File:    lsadump2.h
 * 
 * Purpose: common definitions
 * 
 * Date:    Sun Jun 07 12:46:59 1998
 * 
 * Copyright (c) 1997-1999 Todd A. Sabin, all rights reserved
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

#ifndef LSADUMP2_H
#define LSADUMP2_H

#define DUMP_PIPE_SIZE 1024

typedef HINSTANCE (WINAPI *pLoadLib_t) (CHAR *);
typedef HINSTANCE (WINAPI *pGetProcAddr_t) (HINSTANCE, CHAR *);
typedef HINSTANCE (WINAPI *pFreeLib_t) (HINSTANCE);
typedef int (*pDumpLsa_t) (CHAR *);

typedef struct _remote_info {
    pLoadLib_t      pLoadLibrary;
    pGetProcAddr_t pGetProcAddress;
    pFreeLib_t     pFreeLibrary;
    CHAR  szDllName[MAX_PATH+1];
    CHAR  szProcName[MAX_PATH+1];
    CHAR  szPipeName[MAX_PATH+1];
} REMOTE_INFO;

#endif
