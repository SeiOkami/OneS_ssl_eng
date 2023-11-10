///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Called when requests to use external resources are confirmed.
// 
// Parameters:
//  RequestsIDs - Array - Request IDs.
//  OwnerForm - ClientApplicationForm - Form that must be locked before permissions are applied.
//  ClosingNotification1 - NotifyDescription - Notification triggered when permissions are granted.
//  StandardProcessing - Boolean - indicates that the standard processing of usage of permissions to use
//    external resources is executed (connection to a service agent via COM connection or to an administration server
//    requesting cluster connection parameters from the user). Can be set to False
//    in the event handler. In this case, standard session termination processing is not performed.
//
Procedure OnConfirmRequestsToUseExternalResources(Val RequestsIDs, OwnerForm, ClosingNotification1, StandardProcessing) Export
	
	
	
EndProcedure

#EndRegion