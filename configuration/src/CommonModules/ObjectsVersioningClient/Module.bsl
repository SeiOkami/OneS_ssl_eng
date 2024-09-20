///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens object version report in version comparison mode.
//
// Parameters:
//  Ref                       - AnyRef - reference to the versioned object;
//  SerializedObjectAddress - String - address of binary data of the compared object
//                                          version in the temporary storage.
//
Procedure OpenReportOnChanges(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", Parameters);
	
EndProcedure

// Shows an object's saved version.
//
// Parameters:
//  Ref                       - AnyRef - reference to the versioned object;
//  SerializedObjectAddress - String - address of the object version binary data in the temporary storage.
//
Procedure OpenReportOnObjectVersion(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	Parameters.Insert("ByVersion", True);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", Parameters);
	
EndProcedure

// The NotificationProcessing event handler for the form that requires a changes history storing check box to be displayed.
//
// Parameters:
//   EventName - String - a name of an event that is got by an event handler on the form.
//   StoreChangeHistory - Number - an attribute that will store the flag value.
// 
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
//		ModuleObjectVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
//		ModuleObjectVersioningClient.StoreHistoryCheckBoxChangeNotificationProcessing(
//			EventName, 
//			StoreChangeHistory);
//	EndIf;
//
Procedure StoreHistoryCheckBoxChangeNotificationProcessing(Val EventName, StoreChangeHistory) Export
	
	If EventName = "ChangelogStorageModeChanged" Then
		StoreChangeHistory = ObjectsVersioningInternalServerCall.StoreHistoryCheckBoxValue();
	EndIf;
	
EndProcedure

// The OnChange event handler for the check box that switches change history storage mode.
// The check box must be related to the Boolean type attribute.
// 
// Parameters:
//   StoreChangesHistoryCheckBoxValue - Boolean - a new flag value to be processed.
// 
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
//		ModuleObjectVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
//		ModuleObjectVersioningClient.ShowSetting();
//	EndIf;
//
Procedure OnStoreHistoryCheckBoxChange(StoreChangesHistoryCheckBoxValue) Export
	
	ObjectsVersioningInternalServerCall.SetChangeHistoryStorageMode(
		StoreChangesHistoryCheckBoxValue);
	
	Notify("ChangelogStorageModeChanged");
	
EndProcedure

// Opens up an object versioning control form.
// Remember to set the command that calls the procedure 
// dependent on the UseObjectsVersioning functional option.
//
// Example:
//	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
//		ModuleObjectVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
//		ModuleObjectVersioningClient.ShowSetting();
//	EndIf;
//
Procedure ShowSetting() Export
	
	OpenForm("InformationRegister.ObjectVersioningSettings.ListForm");
	
EndProcedure

#EndRegion

#Region Internal

// Opens a report on a version or version comparison.
//
// Parameters:
//  Ref - AnyRef - object reference;
//  VersionsToCompare - Array - a collection of versions to compare. If there is only one version, the report on the version will be opened.
//
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare) Export
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("VersionsToCompare", VersionsToCompare);
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", ReportParameters);
	
EndProcedure

// Opens a list of an object's versions.
//
// Parameters:
//  Ref        - AnyRef - versioned object;
//  OwnerForm - ClientApplicationForm - a form used to open a history of changes from.
//
Procedure ShowChangeHistory(Ref, OwnerForm) Export
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Ref", Ref);
	OpeningParameters.Insert("ReadOnly", OwnerForm.ReadOnly);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.SelectStoredVersions", OpeningParameters, OwnerForm);
	
EndProcedure

#EndRegion
