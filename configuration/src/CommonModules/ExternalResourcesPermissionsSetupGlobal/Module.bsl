///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Performs an asynchronous processing of a notification of closing external resource permissions
// setup wizard form when the call is executed using an idle handler.
// DialogReturnCode.OK is passed as a result to the handler.
//
// The procedure is not intended for direct call.
//
Procedure FinishExternalResourcePermissionSetup() Export
	
	ExternalResourcesPermissionsSetupClient.CompleteSetUpPermissionsToUseExternalResourcesSynchronously(DialogReturnCode.OK);
	
EndProcedure

// Performs an asynchronous processing of a notification of closing external resource permissions
// setup wizard form when the call is executed using an idle handler.
// DialogReturnCode.OK is passed as a result to the handler.
//
// The procedure is not intended for direct call.
//
Procedure CancelExternalResourcePermissionSetup() Export
	
	ExternalResourcesPermissionsSetupClient.CompleteSetUpPermissionsToUseExternalResourcesSynchronously(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion