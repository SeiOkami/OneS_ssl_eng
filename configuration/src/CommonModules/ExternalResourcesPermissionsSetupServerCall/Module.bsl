///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Checks whether the permissions to use external resources are applied.
// Used for troubleshooting issues when changes in security profile settings
// in a server cluster were made but the operation within which the
// changes had to be done was not completed.
//
// Returns:
//   Structure:
//  CheckResult - Boolean - if False, then the operation was not completed and the
//                      user must be prompted to cancel the changes in the security
//                      profile settings in the server cluster,
//  RequestsIDs - Array(UUID) - an array of IDs of requests
//                           to use external resources that must be applied to
//                           cancel changes in the security profile settings in the server cluster,
//  TempStorageAddress - String - an address in a temporary storage, where the
//                             state of permission requests, which must be applied
//                             to cancel changes in the security profile settings in the server
//                             cluster, was placed,
//  StateTemporaryStorageAddress - String - an address in a temporary storage, to which the
//                                      inner processing state was placed.
//                                      ExternalResourcePermissionSetup.
//
Function CheckApplyPermissionsToUseExternalResources() Export
	
	Return DataProcessors.ExternalResourcesPermissionsSetup.ExecuteApplicabilityCheckRequestsProcessing();
	
EndFunction

// Deletes requests to use external resources if the user cancels them.
//
// Parameters:
//  RequestsIDs - Array of UUID - an array of IDs of requests to
//                           use external resources.
//
Procedure CancelApplyRequestsToUseExternalResources(Val RequestsIDs) Export
	
	InformationRegisters.RequestsForPermissionsToUseExternalResources.DeleteRequests(RequestsIDs);
	
EndProcedure

#EndRegion
