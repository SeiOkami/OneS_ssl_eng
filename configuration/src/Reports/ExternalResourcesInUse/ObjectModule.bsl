///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.GenerateImmediately = True;
	Settings.OutputSelectedCellsTotal = False;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	ResultDocument.Clear();
	
	BeginTransaction(); // 
	Try
		SetPrivilegedMode(True);
		
		Constants.UseSecurityProfiles.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
		DataProcessors.ExternalResourcesPermissionsSetup.ClearPermissions();
		PermissionsRequests = SafeModeManagerInternal.RequestsToUpdateApplicationPermissions();
		Manager = InformationRegisters.RequestsForPermissionsToUseExternalResources.PermissionsApplicationManager(PermissionsRequests);
		
		SetPrivilegedMode(False);
		
		RollbackTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	
	ResultDocument.Put(Manager.Presentation(True));
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf