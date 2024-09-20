///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Returns external module attachment mode.
//
// Parameters:
//  ProgramModule - AnyRef - a reference corresponding to the program module for which
//    the attaching mode is requested.
//
// Returns:
//   String - 
//  
//
Function ExternalModuleAttachmentMode(Val ProgramModule) Export
	
	If SafeModeManager.SafeModeSet() Then
		// При установленном выше по стеку безопасном режиме - 
		// 
		Return SafeMode();
	EndIf;
		
	SetPrivilegedMode(True);
	
	ModuleProperties = SafeModeManagerInternal.PropertiesForPermissionRegister(ProgramModule);
	Query = New Query(
		"SELECT
		|	ExternalModulesAttachmentModes.SafeMode
		|FROM
		|	InformationRegister.ExternalModulesAttachmentModes AS ExternalModulesAttachmentModes
		|WHERE
		|	ExternalModulesAttachmentModes.ProgramModuleType = &ProgramModuleType
		|	AND ExternalModulesAttachmentModes.ModuleID = &ModuleID");
	
	Query.SetParameter("ProgramModuleType", ModuleProperties.Type);
	Query.SetParameter("ModuleID", ModuleProperties.Id);
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Result = QuerySelection.SafeMode;
	Else
		Result = Undefined;
	EndIf;
	
	SSLSubsystemsIntegration.OnAttachExternalModule(ProgramModule, Result);
	SafeModeManagerOverridable.OnAttachExternalModule(ProgramModule, Result);
	Return Result;
	
EndFunction

#EndRegion

#EndIf
