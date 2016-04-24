Copyright (c) Microsoft Corporation.  All rights reserved.

    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
    KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
    PURPOSE.

Copyright (c) Osamu Tamura @ Recursion Co., Ltd.  Portion of rights resereved.

Module Name:

    lowcdc.c

Abstract:

    This module is a filter driver to enable cdc transfer on low speed USB.
    Use with usbser.sys.

Environment:

    Kernel mode

Revision History:

    Fixed bugs - March 15, 2001

    Added Ioctl interface - Aug 16, 2001
    
    Updated to use IoCreateDeviceSecure function - Sep 17, 2002

    Updated to use RemLocks - Oct 29, 2002

	------------------------------

    FilterDispatchIo() added by Osamu Tamura @ Recursion Co., Ltd. - Jun 30, 2008

    Updated to use interrupt pipes for cdc transfer - Dec 22, 2008

	Added registry to switch bulk/interrupt transfer
	Disabled the interrupt pipe for notification message - Jun 07, 2009

	Added support for Win 2000 (bulk mode only) - Aug 20, 2009

    Use bulk transfer by default - Andrey Tolstoy - Apr 24, 2016