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

// Updates register data after changing the access kind.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
//  WithoutUpdatingDependentData - Boolean - if True, 
//                  do not call the OnChangeAccessKindsUse procedure and
//                  do not schedule the update of the access restriction parameters.
//
Procedure UpdateRegisterData(HasChanges = Undefined, WithoutUpdatingDependentData = False) Export
	
	InformationRegisters.ExtensionVersionParameters.LockForChangeInFileIB();
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	
	UsedAccessKinds = CreateRecordSet().Unload();
	
	For Each AccessKindProperties In AccessKindsProperties.Array Do
		
		If AccessKindProperties.Name = "ExternalUsers"
		 Or AccessKindProperties.Name = "Users" Then
			// These access kinds cannot be disabled by functional options.
			Used = True;
		Else
			Used = True;
			SSLSubsystemsIntegration.OnFillAccessKindUsage(AccessKindProperties.Name, Used);
			AccessManagementOverridable.OnFillAccessKindUsage(AccessKindProperties.Name, Used);
		EndIf;
		
		If Used Then
			UsedAccessKinds.Add().AccessValuesType = AccessKindProperties.Ref;
		EndIf;
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	NewData.AccessValuesType
	|INTO NewData
	|FROM
	|	&UsedAccessKinds AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.AccessValuesType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("AccessValuesType"));
	
	Query = New Query;
	UsedAccessKinds.GroupBy("AccessValuesType");
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.UsedAccessKinds", TemporaryTablesQueriesText);
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	Block = New DataLock;
	Block.Add("InformationRegister.UsedAccessKinds");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.UsedAccessKinds);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			HasChanges = True;
			If Not WithoutUpdatingDependentData Then
				WhenChangingTheUseOfAccessTypes(True);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Parameters:
//  DataElement - InformationRegisterRecordSet.UsedAccessKinds
//
Procedure RegisterAChangeWhenUploading(DataElement) Export
	
	PreviousValues1 = CreateRecordSet();
	If DataElement.Filter.AccessValuesType.Use Then
		PreviousValues1.Filter.AccessValuesType.Set(DataElement.Filter.AccessValuesType.Value);
	EndIf;
	
	PreviousValues1.Read();
	
	Table = PreviousValues1.Unload();
	Table.Columns.Add("LineChangeType", New TypeDescription("Number"));
	Table.FillValues(-1, "LineChangeType");
	
	For Each Record In DataElement Do
		NewRow = Table.Add();
		NewRow.LineChangeType = 1;
		NewRow.AccessValuesType = Record.AccessValuesType;
	EndDo;
	Table.GroupBy("AccessValuesType", "LineChangeType");
	
	Changes = New Array;
	For Each String In Table Do
		If String.LineChangeType = 0 Then
			Continue;
		EndIf;
		Changes.Add(String.AccessValuesType);
	EndDo;
	
	If Not ValueIsFilled(Changes) Then
		Return;
	EndIf;
	
	Catalogs.AccessGroups.RegisterRefs("UsedAccessKinds", Changes);
	
EndProcedure

// For internal use only.
Procedure ProcessTheChangeRegisteredDuringTheUpload() Export
	
	If Common.DataSeparationEnabled() Then
		// 
		Return;
	EndIf;
	
	Changes = Catalogs.AccessGroups.RegisteredRefs("UsedAccessKinds");
	If Changes.Count() = 0 Then
		Return;
	EndIf;
	
	WhenChangingTheUseOfAccessTypes(True);
	
	Catalogs.AccessGroups.RegisterRefs("UsedAccessKinds", Null);
	
EndProcedure

// For the UpdateRegisterData, ProcessChangeRecordedOnImport procedures.
Procedure WhenChangingTheUseOfAccessTypes(PlanToUpdateAccessRestrictionSettings = False) Export
	
	InformationRegisters.AccessGroupsValues.UpdateRegisterData();
	InformationRegisters.UsedAccessKindsByTables.UpdateRegisterData();
	
	If PlanToUpdateAccessRestrictionSettings Then
		AccessManagementInternal.ScheduleAccessRestrictionParametersUpdate(
			"WhenChangingTheUseOfAccessTypes");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
