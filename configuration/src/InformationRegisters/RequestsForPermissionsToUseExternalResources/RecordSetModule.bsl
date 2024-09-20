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

Procedure OnWrite(Cancel, Replacing)
	
	// 
	// 
	If SafeModeManager.SafeModeSet() Then
		
		CurrentSafeMode = SafeMode();
		
		For Each Record In ThisObject Do
			
			If Record.SafeMode <> CurrentSafeMode Then
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Safe mode (%1) is different from the current one (%2)';"),
					Record.SafeMode, CurrentSafeMode);
				
			EndIf;
			
			ProgramModule = SafeModeManagerInternal.ReferenceFormPermissionRegister(
				Record.OwnerType, Record.ModuleID);
			
			If ProgramModule <> Catalogs.MetadataObjectIDs.EmptyRef() Then
				
				ProgramModuleSafeMode = InformationRegisters.ExternalModulesAttachmentModes.ExternalModuleAttachmentMode(
					ProgramModule);
				
				If Record.SafeMode <> ProgramModuleSafeMode Then
					
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot perform the permission request for the %1 program module in the %2 safe mode';"),
						String(ProgramModule), Record.SafeMode);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf