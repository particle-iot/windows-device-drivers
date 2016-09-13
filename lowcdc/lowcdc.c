/*++

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
--*/

#include <wdm.h>
#include <usbdi.h>
#include "lowcdc.h"


#ifdef ALLOC_PRAGMA
#pragma alloc_text (INIT, DriverEntry)
#pragma alloc_text (PAGE, FilterAddDevice)
#pragma alloc_text (PAGE, FilterDispatchPnp)
#pragma alloc_text (PAGE, FilterUnload)
#pragma alloc_text (PAGE, FilterDispatchIoXp)
#pragma alloc_text (PAGE, FilterDispatchIoVista)
#endif


NTSTATUS
DriverEntry(
    __in PDRIVER_OBJECT  DriverObject,
    __in PUNICODE_STRING RegistryPath
    )
/*++

Routine Description:

    Installable driver initialization entry point.
    This entry point is called directly by the I/O system.

Arguments:

    DriverObject - pointer to the driver object

    RegistryPath - pointer to a unicode string representing the path,
                   to driver-specific key in the registry.

Return Value:

    STATUS_SUCCESS if successful,
    STATUS_UNSUCCESSFUL otherwise.

--*/
{
    NTSTATUS            status = STATUS_SUCCESS;
    ULONG               ulIndex;
    PDRIVER_DISPATCH  * dispatch;
	ULONG				value;

    UNREFERENCED_PARAMETER (RegistryPath);

    DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL, "Entered the Driver Entry\n" ));

    //
    // Create dispatch points
    //
    for (ulIndex = 0, dispatch = DriverObject->MajorFunction;
         ulIndex <= IRP_MJ_MAXIMUM_FUNCTION;
         ulIndex++, dispatch++) {

        *dispatch = FilterPass;
    }

    DriverObject->MajorFunction[IRP_MJ_PNP]            = FilterDispatchPnp;
    DriverObject->MajorFunction[IRP_MJ_POWER]          = FilterDispatchPower;
    DriverObject->DriverExtension->AddDevice           = FilterAddDevice;
    DriverObject->DriverUnload                         = FilterUnload;

	DriverObject->MajorFunction[IRP_MJ_INTERNAL_DEVICE_CONTROL] = FilterDispatchIoVista;

	return status;
}


NTSTATUS
FilterAddDevice(
    __in PDRIVER_OBJECT DriverObject,
    __in PDEVICE_OBJECT PhysicalDeviceObject
    )
/*++

Routine Description:

    The Plug & Play subsystem is handing us a brand new PDO, for which we
    (by means of INF registration) have been asked to provide a driver.

    We need to determine if we need to be in the driver stack for the device.
    Create a function device object to attach to the stack
    Initialize that device object
    Return status success.

    Remember: We can NOT actually send ANY non pnp IRPS to the given driver
    stack, UNTIL we have received an IRP_MN_START_DEVICE.

Arguments:

    DeviceObject - pointer to a device object.

    PhysicalDeviceObject -  pointer to a device object created by the
                            underlying bus driver.

Return Value:

    NT status code.

--*/
{
    NTSTATUS                status = STATUS_SUCCESS;
    PDEVICE_OBJECT          deviceObject = NULL;
    PDEVICE_EXTENSION       deviceExtension;
    ULONG                   deviceType = FILE_DEVICE_SERIAL_PORT;

    PAGED_CODE ();


    //
    // IoIsWdmVersionAvailable(1, 0x20) returns TRUE on os after Windows 2000.
    //
//    if (!IoIsWdmVersionAvailable(1, 0x20)) {
    if (!RtlIsNtDdiVersionAvailable(NTDDI_WIN2K)) {
        //
        // Win2K system bugchecks if the filter attached to a storage device
        // doesn't specify the same DeviceType as the device it's attaching
        // to. This bugcheck happens in the filesystem when you disable
        // the devicestack whose top level deviceobject doesn't have a VPB.
        // To workaround we will get the toplevel object's DeviceType and
        // specify that in IoCreateDevice.
        //
        deviceObject = IoGetAttachedDeviceReference(PhysicalDeviceObject);
        deviceType = deviceObject->DeviceType;
        ObDereferenceObject(deviceObject);
    }

    //
    // Create a filter device object.
    //

    status = IoCreateDevice (DriverObject,
                             sizeof (DEVICE_EXTENSION),
                             NULL,  // No Name
                             deviceType,
                             FILE_DEVICE_SECURE_OPEN,
                             FALSE,
                             &deviceObject);


    if (!NT_SUCCESS (status)) {
        //
        // Returning failure here prevents the entire stack from functioning,
        // but most likely the rest of the stack will not be able to create
        // device objects either, so it is still OK.
        //
        return status;
    }

    DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL,
                "AddDevice PDO (0x%p) FDO (0x%p)\n", PhysicalDeviceObject, deviceObject ));

    deviceExtension = (PDEVICE_EXTENSION) deviceObject->DeviceExtension;

    deviceExtension->Type = DEVICE_TYPE_FIDO;

    deviceExtension->NextLowerDriver = IoAttachDeviceToDeviceStack (
                                       deviceObject,
                                       PhysicalDeviceObject);
    //
    // Failure for attachment is an indication of a broken plug & play system.
    //

    if (NULL == deviceExtension->NextLowerDriver) {

        IoDeleteDevice(deviceObject);
        return STATUS_UNSUCCESSFUL;
    }

    deviceObject->Flags |= deviceExtension->NextLowerDriver->Flags &
                            (DO_BUFFERED_IO | DO_DIRECT_IO |
                            DO_POWER_PAGABLE );


    deviceObject->DeviceType = deviceExtension->NextLowerDriver->DeviceType;

    deviceObject->Characteristics =
                          deviceExtension->NextLowerDriver->Characteristics;

    deviceExtension->Self = deviceObject;

    //
    // Let us use remove lock to keep count of IRPs so that we don't 
    // deteach and delete our deviceobject until all pending I/Os in our
    // devstack are completed. Remlock is required to protect us from
    // various race conditions where our driver can get unloaded while we
    // are still running dispatch or completion code.
    //
    
    IoInitializeRemoveLock (&deviceExtension->RemoveLock , 
                            POOL_TAG,
                            1, // MaxLockedMinutes 
                            100); // HighWatermark, this parameter is 
                                // used only on checked build. Specifies 
                                // the maximum number of outstanding 
                                // acquisitions allowed on the lock
                                

    //
    // Set the initial state of the Filter DO
    //

    INITIALIZE_PNP_STATE(deviceExtension);

    DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL,
                "AddDevice: %p to %p->%p \n", deviceObject,
                       deviceExtension->NextLowerDriver,
                       PhysicalDeviceObject ));

    deviceObject->Flags &= ~DO_DEVICE_INITIALIZING;

    return STATUS_SUCCESS;
}


NTSTATUS
FilterPass (
    __in PDEVICE_OBJECT DeviceObject,
    __in PIRP Irp
    )
/*++

Routine Description:

    The default dispatch routine.  If this driver does not recognize the
    IRP, then it should send it down, unmodified.
    If the device holds iris, this IRP must be queued in the device extension
    No completion routine is required.

    For demonstrative purposes only, we will pass all the (non-PnP) Irps down
    on the stack (as we are a filter driver). A real driver might choose to
    service some of these Irps.

    As we have NO idea which function we are happily passing on, we can make
    NO assumptions about whether or not it will be called at raised IRQL.
    For this reason, this function must be in put into non-paged pool
    (aka the default location).

Arguments:

   DeviceObject - pointer to a device object.

   Irp - pointer to an I/O Request Packet.

Return Value:

      NT status code

--*/
{
    PDEVICE_EXTENSION           deviceExtension;
    NTSTATUS    status;
    
    deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;
    status = IoAcquireRemoveLock (&deviceExtension->RemoveLock, Irp);
    if (!NT_SUCCESS (status)) {
        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        return status;
    }

   IoSkipCurrentIrpStackLocation (Irp);
   status = IoCallDriver (deviceExtension->NextLowerDriver, Irp);
   IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
   return status;
}


NTSTATUS
FilterDispatchPnp (
    __in PDEVICE_OBJECT DeviceObject,
    __in PIRP Irp
    )
/*++

Routine Description:

    The plug and play dispatch routines.

    Most of these the driver will completely ignore.
    In all cases it must pass on the IRP to the lower driver.

Arguments:

   DeviceObject - pointer to a device object.

   Irp - pointer to an I/O Request Packet.

Return Value:

      NT status code

--*/
{
    PDEVICE_EXTENSION           deviceExtension;
    PIO_STACK_LOCATION         irpStack;
    NTSTATUS                            status;
    KEVENT                               event;

    PAGED_CODE();

    deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;
    irpStack = IoGetCurrentIrpStackLocation(Irp);

    DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL,
                "FilterDO %s IRP:0x%p \n",
                PnPMinorFunctionString(irpStack->MinorFunction), Irp ));

    status = IoAcquireRemoveLock (&deviceExtension->RemoveLock, Irp);
    if (!NT_SUCCESS (status)) {
        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        return status;
    }
    

    switch (irpStack->MinorFunction) {
    case IRP_MN_START_DEVICE:

        //
        // The device is starting.
        // We cannot touch the device (send it any non pnp irps) until a
        // start device has been passed down to the lower drivers.
        //
        KeInitializeEvent(&event, NotificationEvent, FALSE);
        IoCopyCurrentIrpStackLocationToNext(Irp);
        IoSetCompletionRoutine(Irp,
                               (PIO_COMPLETION_ROUTINE) FilterStartCompletionRoutine,
                               &event,
                               TRUE,
                               TRUE,
                               TRUE);

        status = IoCallDriver(deviceExtension->NextLowerDriver, Irp);
        
        //
        // Wait for lower drivers to be done with the Irp. Important thing to
        // note here is when you allocate memory for an event in the stack  
        // you must do a KernelMode wait instead of UserMode to prevent 
        // the stack from getting paged out.
        //
        if (status == STATUS_PENDING) {

           KeWaitForSingleObject(&event, Executive, KernelMode, FALSE, NULL);          
           status = Irp->IoStatus.Status;
        }

        if (NT_SUCCESS (status)) {

            //
            // As we are successfully now back, we will
            // first set our state to Started.
            //

            SET_NEW_PNP_STATE(deviceExtension, Started);

            //
            // On the way up inherit FILE_REMOVABLE_MEDIA during Start.
            // This characteristic is available only after the driver stack is started!.
            //
            if (deviceExtension->NextLowerDriver->Characteristics & FILE_REMOVABLE_MEDIA) {

                DeviceObject->Characteristics |= FILE_REMOVABLE_MEDIA;
            }
        }
        
        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
        return status;

    case IRP_MN_REMOVE_DEVICE:

        //
        // Wait for all outstanding requests to complete
        //
        DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL, "Waiting for outstanding requests\n" ));

        IoReleaseRemoveLockAndWait(&deviceExtension->RemoveLock, Irp);

        IoSkipCurrentIrpStackLocation(Irp);

        status = IoCallDriver(deviceExtension->NextLowerDriver, Irp);

        SET_NEW_PNP_STATE(deviceExtension, Deleted);
        
        IoDetachDevice(deviceExtension->NextLowerDriver);
        IoDeleteDevice(DeviceObject);
        return status;


    case IRP_MN_QUERY_STOP_DEVICE:
        SET_NEW_PNP_STATE(deviceExtension, StopPending);
        status = STATUS_SUCCESS;
        break;

    case IRP_MN_CANCEL_STOP_DEVICE:

        //
        // Check to see whether you have received cancel-stop
        // without first receiving a query-stop. This could happen if someone
        // above us fails a query-stop and passes down the subsequent
        // cancel-stop.
        //

        if (StopPending == deviceExtension->DevicePnPState)
        {
            //
            // We did receive a query-stop, so restore.
            //
            RESTORE_PREVIOUS_PNP_STATE(deviceExtension);
        }
        status = STATUS_SUCCESS; // We must not fail this IRP.
        break;

    case IRP_MN_STOP_DEVICE:
        SET_NEW_PNP_STATE(deviceExtension, Stopped);
        status = STATUS_SUCCESS;
        break;

    case IRP_MN_QUERY_REMOVE_DEVICE:

        SET_NEW_PNP_STATE(deviceExtension, RemovePending);
        status = STATUS_SUCCESS;
        break;

    case IRP_MN_SURPRISE_REMOVAL:

        SET_NEW_PNP_STATE(deviceExtension, SurpriseRemovePending);
        status = STATUS_SUCCESS;
        break;

    case IRP_MN_CANCEL_REMOVE_DEVICE:

        //
        // Check to see whether you have received cancel-remove
        // without first receiving a query-remove. This could happen if
        // someone above us fails a query-remove and passes down the
        // subsequent cancel-remove.
        //

        if (RemovePending == deviceExtension->DevicePnPState)
        {
            //
            // We did receive a query-remove, so restore.
            //
            RESTORE_PREVIOUS_PNP_STATE(deviceExtension);
        }

        status = STATUS_SUCCESS; // We must not fail this IRP.
        break;

    case IRP_MN_DEVICE_USAGE_NOTIFICATION:

        //
        // On the way down, pagable might become set. Mimic the driver
        // above us. If no one is above us, just set pagable.
        //
        if ((DeviceObject->AttachedDevice == NULL) ||
            (DeviceObject->AttachedDevice->Flags & DO_POWER_PAGABLE)) {

            DeviceObject->Flags |= DO_POWER_PAGABLE;
        }

        IoCopyCurrentIrpStackLocationToNext(Irp);

        IoSetCompletionRoutine(
            Irp,
            FilterDeviceUsageNotificationCompletionRoutine,
            NULL,
            TRUE,
            TRUE,
            TRUE
            );

        return IoCallDriver(deviceExtension->NextLowerDriver, Irp);

    default:
        //
        // If you don't handle any IRP you must leave the
        // status as is.
        //
        status = Irp->IoStatus.Status;

        break;
    }

    //
    // Pass the IRP down and forget it.
    //
    Irp->IoStatus.Status = status;
    IoSkipCurrentIrpStackLocation (Irp);
    status = IoCallDriver (deviceExtension->NextLowerDriver, Irp);
    IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
    return status;
}

NTSTATUS
FilterStartCompletionRoutine(
    __in PDEVICE_OBJECT   DeviceObject,
    __in PIRP             Irp,
    __in PVOID            Context
    )
/*++
Routine Description:
    A completion routine for use when calling the lower device objects to
    which our filter deviceobject is attached.

Arguments:

    DeviceObject - Pointer to deviceobject
    Irp          - Pointer to a PnP Irp.
    Context      - NULL
Return Value:

    NT Status is returned.

--*/

{
    PKEVENT             event = (PKEVENT)Context;

    UNREFERENCED_PARAMETER (DeviceObject);

    //
    // If the lower driver didn't return STATUS_PENDING, we don't need to 
    // set the event because we won't be waiting on it. 
    // This optimization avoids grabbing the dispatcher lock, and improves perf.
    //
    if (Irp->PendingReturned == TRUE) {
        KeSetEvent (event, IO_NO_INCREMENT, FALSE);
    }

    //
    // The dispatch routine will have to call IoCompleteRequest
    //

    return STATUS_MORE_PROCESSING_REQUIRED;

}

NTSTATUS
FilterDeviceUsageNotificationCompletionRoutine(
    __in PDEVICE_OBJECT   DeviceObject,
    __in PIRP             Irp,
    __in PVOID            Context
    )
/*++
Routine Description:
    A completion routine for use when calling the lower device objects to
    which our filter deviceobject is attached.

Arguments:

    DeviceObject - Pointer to deviceobject
    Irp          - Pointer to a PnP Irp.
    Context      - NULL
Return Value:

    NT Status is returned.

--*/

{
    PDEVICE_EXTENSION       deviceExtension;

    UNREFERENCED_PARAMETER(Context);

    deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;


    if (Irp->PendingReturned) {

        IoMarkIrpPending(Irp);
    }

    //
    // On the way up, pagable might become clear. Mimic the driver below us.
    //
    if (!(deviceExtension->NextLowerDriver->Flags & DO_POWER_PAGABLE)) {

        DeviceObject->Flags &= ~DO_POWER_PAGABLE;
    }

    IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 

    return STATUS_CONTINUE_COMPLETION;

}

NTSTATUS
FilterDispatchPower(
    __in PDEVICE_OBJECT    DeviceObject,
    __in PIRP              Irp
    )
/*++

Routine Description:

    This routine is the dispatch routine for power irps.

Arguments:

    DeviceObject - Pointer to the device object.

    Irp - Pointer to the request packet.

Return Value:

    NT Status code
--*/
{
    PDEVICE_EXTENSION   deviceExtension;
    NTSTATUS    status;
    
    deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;
    status = IoAcquireRemoveLock (&deviceExtension->RemoveLock, Irp);
    if (!NT_SUCCESS (status)) { // may be device is being removed.
        Irp->IoStatus.Status = status;
        PoStartNextPowerIrp(Irp);
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        return status;
    }

    PoStartNextPowerIrp(Irp);
    IoSkipCurrentIrpStackLocation(Irp);
    status = PoCallDriver(deviceExtension->NextLowerDriver, Irp);
    IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
    return status;
}



VOID
FilterUnload(
    __in PDRIVER_OBJECT DriverObject
    )
/*++

Routine Description:

    Free all the allocated resources in DriverEntry, etc.

Arguments:

    DriverObject - pointer to a driver object.

Return Value:

    VOID.

--*/
{
    PAGED_CODE ();

    //
    // The device object(s) should be NULL now
    // (since we unload, all the devices objects associated with this
    // driver must be deleted.
    //
    ASSERT(DriverObject->DeviceObject == NULL);

    //
    // We should not be unloaded until all the devices we control
    // have been removed from our queue.
    //
    DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL, "unload\n" ));

    return;
}


NTSTATUS
FilterDispatchIoXp(
    __in PDEVICE_OBJECT    DeviceObject,
    __in PIRP              Irp
    )
/*++

Routine Description:

    This routine is the dispatch routine for non passthru irps.
    We will check the input device object to see if the request
    is meant for the control device object. If it is, we will
    handle and complete the IRP, if not, we will pass it down to 
    the lower driver.
    
Arguments:

    DeviceObject - Pointer to the device object.

    Irp - Pointer to the request packet.

Return Value:

    NT Status code
--*/
{
    PDEVICE_EXTENSION   deviceExtension;
    PURB                urb    = URB_FROM_IRP(Irp);
    NTSTATUS            status;
    static UCHAR        intr_addr;
	static USBD_PIPE_HANDLE intr_handle;
    

    PAGED_CODE ();

	deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;
    status = IoAcquireRemoveLock (&deviceExtension->RemoveLock, Irp);
    if (!NT_SUCCESS (status)) {
        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        return status;
    }

    //	retrieve the interrupt pipe address
    if( URB_FUNCTION_SELECT_CONFIGURATION==urb->UrbHeader.Function ) {
        USB_CONFIGURATION_DESCRIPTOR	*pdsc;
        UCHAR                           *ptr;
        UCHAR                           *pend;

		DbgPrt(( DPFLTR_IHVBUS_ID, DBG_LEVEL, " XP: Bulk\n" ));

		pdsc	= urb->UrbSelectConfiguration.ConfigurationDescriptor;
        ptr		= (UCHAR *)pdsc;
        for( pend=ptr+pdsc->wTotalLength,ptr+=*ptr; ptr<pend; ptr+=*ptr ) {
            if( *(ptr+1)==USB_ENDPOINT_DESCRIPTOR_TYPE && *(ptr+3)==USB_ENDPOINT_TYPE_INTERRUPT ) {
                intr_addr   = *(ptr+2);
				break;
            }
        }
    }

	//	ignore unused interrupt request
    if( URB_FUNCTION_BULK_OR_INTERRUPT_TRANSFER==urb->UrbHeader.Function &&
        *((UCHAR *)urb->UrbBulkOrInterruptTransfer.PipeHandle+6)==intr_addr ) {
		IoSkipCurrentIrpStackLocation (Irp);
        Irp->IoStatus.Status = status	= STATUS_INTERNAL_ERROR;
        IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
        return status;
	}

    IoSkipCurrentIrpStackLocation (Irp);
    status = IoCallDriver (deviceExtension->NextLowerDriver, Irp);
    IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
    return status;
}


NTSTATUS
FilterDispatchIoVista(
    __in PDEVICE_OBJECT    DeviceObject,
    __in PIRP              Irp
    )
/*++

Routine Description:

    This routine is the dispatch routine for non passthru irps.
    We will check the input device object to see if the request
    is meant for the control device object. If it is, we will
    handle and complete the IRP, if not, we will pass it down to 
    the lower driver.
    
Arguments:

    DeviceObject - Pointer to the device object.

    Irp - Pointer to the request packet.

Return Value:

    NT Status code
--*/
{
    PDEVICE_EXTENSION   deviceExtension;
    PURB                urb    = URB_FROM_IRP(Irp);
    NTSTATUS            status;
    static UCHAR        intr_addr;
	static USBD_PIPE_HANDLE intr_handle = 0;
    
 
	PAGED_CODE ();

    deviceExtension = (PDEVICE_EXTENSION) DeviceObject->DeviceExtension;
    status = IoAcquireRemoveLock (&deviceExtension->RemoveLock, Irp);
    if (!NT_SUCCESS (status)) {
        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);
        return status;
    }

    if( URB_FUNCTION_SELECT_CONFIGURATION==urb->UrbHeader.Function ) {
        USB_CONFIGURATION_DESCRIPTOR    *pdsc;
        UCHAR                           *ptr;
        UCHAR                           *pend;
		int                             i, j;

        pdsc = urb->UrbSelectConfiguration.ConfigurationDescriptor;

		// Get interrupt endpoint number
        ptr    = (UCHAR *)pdsc;
        for( pend=ptr+pdsc->wTotalLength,ptr+=*ptr; ptr<pend; ptr+=*ptr ) {
            if( *(ptr+1)==USB_ENDPOINT_DESCRIPTOR_TYPE ) {
				DbgPrt((DPFLTR_IHVBUS_ID, DBG_LEVEL, "Endpoint 0x%x\n", (int)*(ptr + 2)));
				if (*(ptr + 3) == USB_ENDPOINT_TYPE_INTERRUPT) {
					intr_addr = *(ptr + 2);
					DbgPrt((DPFLTR_IHVBUS_ID, DBG_LEVEL, "Interrupt endpoint 0x%x\n", intr_addr));
				}
            }
        }

        IoSkipCurrentIrpStackLocation (Irp);

        status = IoCallDriver (deviceExtension->NextLowerDriver, Irp);

        if( NT_SUCCESS(status) && intr_addr) {
            USBD_INTERFACE_INFORMATION    *interface_info;

            interface_info = (USBD_INTERFACE_INFORMATION *)&urb->UrbSelectConfiguration.Interface;
            if( interface_info!=NULL ) {
				DbgPrt((DPFLTR_IHVBUS_ID, DBG_LEVEL, "Number of pipes %d\n", (int)interface_info->NumberOfPipes));
                for( i=0; i<(int)interface_info->NumberOfPipes; i++ ) {
                    USBD_PIPE_INFORMATION    *pipe_info = &interface_info->Pipes[i];
                    //    retrieve interrupt pipe handle
                    if( pipe_info!=NULL ) {
						if (pipe_info->EndpointAddress == intr_addr) {
							intr_handle = pipe_info->PipeHandle;
							DbgPrt((DPFLTR_IHVBUS_ID, DBG_LEVEL,
								"[Interrupt Pipe]: [%x-%x]-[%x-%x-%x-%x] handle=%x IRP:0x%p\n",
								pipe_info->MaximumTransferSize,
								pipe_info->PipeFlags,
								pipe_info->MaximumPacketSize,
								pipe_info->EndpointAddress,
								pipe_info->Interval,
								pipe_info->PipeType,
								pipe_info->PipeHandle,
								Irp));
						}
                    }
                }
            }
        }

        IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp);
        return status;
    }

	//  ignore unused interrupt request
    if( URB_FUNCTION_BULK_OR_INTERRUPT_TRANSFER==urb->UrbHeader.Function &&
        urb->UrbBulkOrInterruptTransfer.PipeHandle==intr_handle && intr_handle) {
		DbgPrt((DPFLTR_IHVBUS_ID, DBG_LEVEL, "Ignoring interrupt transfer to endpoint 0x%x\n", intr_handle));
		IoSkipCurrentIrpStackLocation (Irp);
        Irp->IoStatus.Status = status	= STATUS_INTERNAL_ERROR;
        IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
        return status;
	}

    IoSkipCurrentIrpStackLocation (Irp);
    status = IoCallDriver (deviceExtension->NextLowerDriver, Irp);
    IoReleaseRemoveLock(&deviceExtension->RemoveLock, Irp); 
    return status;
}

#if DBG

PCHAR
PnPMinorFunctionString (
    UCHAR MinorFunction
)
{
    switch (MinorFunction)
    {
        case IRP_MN_START_DEVICE:
            return "IRP_MN_START_DEVICE";
        case IRP_MN_QUERY_REMOVE_DEVICE:
            return "IRP_MN_QUERY_REMOVE_DEVICE";
        case IRP_MN_REMOVE_DEVICE:
            return "IRP_MN_REMOVE_DEVICE";
        case IRP_MN_CANCEL_REMOVE_DEVICE:
            return "IRP_MN_CANCEL_REMOVE_DEVICE";
        case IRP_MN_STOP_DEVICE:
            return "IRP_MN_STOP_DEVICE";
        case IRP_MN_QUERY_STOP_DEVICE:
            return "IRP_MN_QUERY_STOP_DEVICE";
        case IRP_MN_CANCEL_STOP_DEVICE:
            return "IRP_MN_CANCEL_STOP_DEVICE";
        case IRP_MN_QUERY_DEVICE_RELATIONS:
            return "IRP_MN_QUERY_DEVICE_RELATIONS";
        case IRP_MN_QUERY_INTERFACE:
            return "IRP_MN_QUERY_INTERFACE";
        case IRP_MN_QUERY_CAPABILITIES:
            return "IRP_MN_QUERY_CAPABILITIES";
        case IRP_MN_QUERY_RESOURCES:
            return "IRP_MN_QUERY_RESOURCES";
        case IRP_MN_QUERY_RESOURCE_REQUIREMENTS:
            return "IRP_MN_QUERY_RESOURCE_REQUIREMENTS";
        case IRP_MN_QUERY_DEVICE_TEXT:
            return "IRP_MN_QUERY_DEVICE_TEXT";
        case IRP_MN_FILTER_RESOURCE_REQUIREMENTS:
            return "IRP_MN_FILTER_RESOURCE_REQUIREMENTS";
        case IRP_MN_READ_CONFIG:
            return "IRP_MN_READ_CONFIG";
        case IRP_MN_WRITE_CONFIG:
            return "IRP_MN_WRITE_CONFIG";
        case IRP_MN_EJECT:
            return "IRP_MN_EJECT";
        case IRP_MN_SET_LOCK:
            return "IRP_MN_SET_LOCK";
        case IRP_MN_QUERY_ID:
            return "IRP_MN_QUERY_ID";
        case IRP_MN_QUERY_PNP_DEVICE_STATE:
            return "IRP_MN_QUERY_PNP_DEVICE_STATE";
        case IRP_MN_QUERY_BUS_INFORMATION:
            return "IRP_MN_QUERY_BUS_INFORMATION";
        case IRP_MN_DEVICE_USAGE_NOTIFICATION:
            return "IRP_MN_DEVICE_USAGE_NOTIFICATION";
        case IRP_MN_SURPRISE_REMOVAL:
            return "IRP_MN_SURPRISE_REMOVAL";

        default:
            return "unknown_pnp_irp";
    }
}

#endif


