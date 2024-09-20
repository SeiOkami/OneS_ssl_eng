///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Called when checking whether security profiles can be used.
//
// Parameters:
//  Cancel - Boolean - if the configuration is not adapted to
//   security profiles,
//   set the parameter value of this procedure to True.
//
Procedure OnCheckSecurityProfilesUsageAvailability(Cancel) Export
	
	
	
EndProcedure

// Called when checking whether security profiles can be set up.
//
// Parameters:
//  Cancel - Boolean - if security profiles cannot be used for the infobase,
//    set the value of this parameter to True.
//
Procedure OnCheckCanSetupSecurityProfiles(Cancel) Export
	
	
	
EndProcedure

// Called when infobase security profiles are enabled for the infobase.
//
Procedure OnEnableSecurityProfiles() Export
	
	
	
EndProcedure

// Fills in a list of requests for external permissions that must be granted
// when an infobase is created or an application is updated.
//
// Parameters:
//  PermissionsRequests - Array of See SafeModeManager.RequestToUseExternalResources
//
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
EndProcedure

// Called when creating a permission request to use external resources.
//
// Parameters:
//  ProgramModule - AnyRef - Reference to the infobase object that represents the module the permissions are requested for.
//    
//  Owner - AnyRef - Reference to the infobase object that owns the requested permissions to use external resources.
//    
//  ReplacementMode - Boolean - indicates that permissions granted earlier by owner are replaced,
//  PermissionsToAdd - Array - XDTODataObject array of permissions being added,
//  PermissionsToDelete - Array - XDTODataObject array of permissions being deleted,
//  StandardProcessing - Boolean - indicates that a standard data processor to create a request to use
//    external resources is processed.
//  Result - UUID - a request ID (if StandardProcessing parameter
//    value is set to False in the handler).
//
Procedure OnRequestPermissionsToUseExternalResources(Val ProgramModule, Val Owner, Val ReplacementMode, 
	Val PermissionsToAdd, Val PermissionsToDelete, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Called when requesting to create a security profile.
//
// Parameters:
//  ProgramModule - AnyRef - Reference to the infobase object that represents the module the permissions are requested for.
//    
//  StandardProcessing - Boolean - indicates that a standard data processor is being executed,
//  Result - UUID - a request ID (if StandardProcessing parameter
//    value is set to False in the handler).
//
Procedure OnRequestToCreateSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Called when requesting to delete a security profile.
//
// Parameters:
//  ProgramModule - AnyRef - Reference to the infobase object that represents the module the permissions are requested for.
//    
//  StandardProcessing - Boolean - indicates that a standard data processor is being executed,
//  Result - UUID - a request ID (if StandardProcessing parameter
//    value is set to False in the handler).
//
Procedure OnRequestToDeleteSecurityProfile(Val ProgramModule, StandardProcessing, Result) Export
	
	
	
EndProcedure

// Called when attaching an external module. In the handler procedure body, you can change
// the safe mode, in which the module is attached.
//
// Parameters:
//  ExternalModule - AnyRef - Reference to the infobase object that represents the external module to be attached.
//    
//  SafeMode - DefinedType.SafeMode - a safe mode, in which the external
//    module will be attached to the infobase. Can be changed within the procedure.
//
Procedure OnAttachExternalModule(Val ExternalModule, SafeMode) Export
	
	
	
EndProcedure

#EndRegion