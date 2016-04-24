/*++

Copyright (c) Microsoft Corporation.  All rights reserved.

    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
    KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
    PURPOSE.

Copyright (c) Osamu Tamura @ Recursion Co., Ltd.  Portion of rights resereved.

Module Name:

    lowcdc.h

Abstract:

    This module is a filter driver to enable cdc transfer on low speed USB.
	Use with usbser.sys.

Environment:

    Kernel mode

Revision History:

	FilterDispatchIo() added by Osamu Tamura @ Recursion Co., Ltd. - Jun 30, 2008

    Use bulk transfer by default - Andrey Tolstoy - Apr 24, 2016
--*/
#include <ntddk.h>


#if !defined(_LOWCDC_H_)
#define _LOWCDC_H_

#define DRIVERNAME	"lowcdc.sys: "

#define USE_INTERRUPT	L"\\lowcdc\\UseInterrupt"

#define	DBG_LEVEL	0xffffffff

#if DBG
#define	DbgPrt(_x_)	DbgPrintEx _x_
#define TRAP() DbgBreakPoint()

#else
#define DbgPrt(_x_)
#define TRAP()
#endif


#ifndef  STATUS_CONTINUE_COMPLETION //required to build driver in Win2K and XP build environment
//
// This value should be returned from completion routines to continue
// completing the IRP upwards. Otherwise, STATUS_MORE_PROCESSING_REQUIRED
// should be returned.
//
#define STATUS_CONTINUE_COMPLETION      STATUS_SUCCESS

#endif

#define POOL_TAG   'cdcL'

//
// These are the states Filter transition to upon
// receiving a specific PnP Irp. Refer to the PnP Device States
// diagram in DDK documentation for better understanding.
//

typedef enum _DEVICE_PNP_STATE {

    NotStarted = 0,         // Not started yet
    Started,                // Device has received the START_DEVICE IRP
    StopPending,            // Device has received the QUERY_STOP IRP
    Stopped,                // Device has received the STOP_DEVICE IRP
    RemovePending,          // Device has received the QUERY_REMOVE IRP
    SurpriseRemovePending,  // Device has received the SURPRISE_REMOVE IRP
    Deleted                 // Device has received the REMOVE_DEVICE IRP

} DEVICE_PNP_STATE;

#define INITIALIZE_PNP_STATE(_Data_)    \
        (_Data_)->DevicePnPState =  NotStarted;\
        (_Data_)->PreviousPnPState = NotStarted;

#define SET_NEW_PNP_STATE(_Data_, _state_) \
        (_Data_)->PreviousPnPState =  (_Data_)->DevicePnPState;\
        (_Data_)->DevicePnPState = (_state_);

#define RESTORE_PREVIOUS_PNP_STATE(_Data_)   \
        (_Data_)->DevicePnPState =   (_Data_)->PreviousPnPState;\

typedef enum _DEVICE_TYPE {

    DEVICE_TYPE_INVALID = 0,         // Invalid Type;
    DEVICE_TYPE_FIDO,                // Device is a filter device.
    DEVICE_TYPE_CDO,                 // Device is a control device.

} DEVICE_TYPE;

//
// A common header for the device extensions of the Filter and control
// device objects
//

typedef struct _COMMON_DEVICE_DATA
{

    DEVICE_TYPE Type;

} COMMON_DEVICE_DATA, *PCOMMON_DEVICE_DATA;


typedef struct _DEVICE_EXTENSION
{
    COMMON_DEVICE_DATA;

    //
    // A back pointer to the device object.
    //

    PDEVICE_OBJECT  Self;

    //
    // The top of the stack before this filter was added.
    //

    PDEVICE_OBJECT  NextLowerDriver;

    //
    // current PnP state of the device
    //

    DEVICE_PNP_STATE  DevicePnPState;

    //
    // Remembers the previous pnp state
    //

    DEVICE_PNP_STATE    PreviousPnPState;

    //
    // Removelock to track IRPs so that device can be removed and
    // the driver can be unloaded safely.
    //
    IO_REMOVE_LOCK RemoveLock;



	// set when PendingIoCount goes to 0; flags device can be removed
    KEVENT RemoveEvent;

	// set when PendingIoCount goes to 1 ( 1st increment was on add device )
	// this indicates no IO requests outstanding, either user, system, or self-staged
    KEVENT NoPendingIoEvent;

	// set to signal driver-generated power request is finished
    KEVENT SelfRequestedPowerIrpEvent;


	// spinlock used to protect inc/dec iocount logic
	KSPIN_LOCK	IoCountSpinLock;

	// incremented when device is added and any IO request is received;
	// decremented when any io request is completed or passed on, and when device is removed
    ULONG PendingIoCount;

	//flag set when processing IRP_MN_REMOVE_DEVICE
    BOOLEAN DeviceRemoved;

 	// flag set when driver has answered success to IRP_MN_QUERY_REMOVE_DEVICE
    BOOLEAN RemoveDeviceRequested;

	// flag set when driver has answered success to IRP_MN_QUERY_STOP_DEVICE
    BOOLEAN StopDeviceRequested;

	// flag set when device has been successfully started
	BOOLEAN DeviceStarted;

    // flag set when IRP_MN_WAIT_WAKE is received and we're in a power state
    // where we can signal a wait
    BOOLEAN EnabledForWakeup;

	// used to flag that we're currently handling a self-generated power request
    BOOLEAN SelfPowerIrp;

} DEVICE_EXTENSION, *PDEVICE_EXTENSION;



DRIVER_INITIALIZE DriverEntry;

DRIVER_ADD_DEVICE FilterAddDevice;

__drv_dispatchType(IRP_MJ_PNP)
DRIVER_DISPATCH FilterDispatchPnp;

__drv_dispatchType(IRP_MJ_POWER)
DRIVER_DISPATCH FilterDispatchPower;

__drv_dispatchType(IRP_MJ_INTERNAL_DEVICE_CONTROL)
DRIVER_DISPATCH FilterDispatchIoXp;
__drv_dispatchType(IRP_MJ_INTERNAL_DEVICE_CONTROL)
DRIVER_DISPATCH FilterDispatchIoVista;

__drv_dispatchType_other
DRIVER_DISPATCH FilterPass;

DRIVER_UNLOAD FilterUnload;

IO_COMPLETION_ROUTINE FilterDeviceUsageNotificationCompletionRoutine;

NTSTATUS
FilterStartCompletionRoutine(
    __in PDEVICE_OBJECT   DeviceObject,
    __in PIRP             Irp,
    __in PVOID            Context
    );

PCHAR
PnPMinorFunctionString (
    UCHAR MinorFunction
);

#endif


