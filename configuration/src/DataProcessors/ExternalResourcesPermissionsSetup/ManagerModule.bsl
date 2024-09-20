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

////////////////////////////////////////////////////////////////////////////////
// Logic of external resource permissions setup wizard.
//

// For internal use.
//
Procedure ExecuteRequestProcessing(Val RequestsIDs, Val TempStorageAddress, Val StateTemporaryStorageAddress, Val AddClearingRequestsBeforeApplying = False) Export
	
	Manager = InformationRegisters.RequestsForPermissionsToUseExternalResources.PermissionsApplicationManager(RequestsIDs);
	
	If AddClearingRequestsBeforeApplying Then
		Manager.AddClearingPermissionsBeforeApplying();
	EndIf;
	
	State = New Structure();
	
	If Manager.MustApplyPermissionsInServersCluster() Then
		
		State.Insert("PermissionApplicationRequired", True);
		
		Result = New Structure();
		Result.Insert("Presentation", Manager.Presentation());
		Result.Insert("Scenario", Manager.ApplyingScenario());
		Result.Insert("State", Manager.WriteStateToXMLString());
		PutToTempStorage(Result, TempStorageAddress);
		
		State.Insert("StorageAddress", TempStorageAddress);
		
	Else
		
		State.Insert("PermissionApplicationRequired", False);
		Manager.CompleteApplyRequestsToUseExternalResources();
		
	EndIf;
	
	PutToTempStorage(State, StateTemporaryStorageAddress);
	
EndProcedure

// For internal use.
//
Procedure ExecuteUpdateRequestProcessing(Val TempStorageAddress, Val StateTemporaryStorageAddress) Export
	
	CallWithDisabledProfiles = Not Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get();
	
	If CallWithDisabledProfiles Then
		
		BeginTransaction();
		
		Constants.UseSecurityProfiles.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
		RequestsIDs = SafeModeManagerInternal.RequestsToUpdateApplicationPermissions();
		RequestsSerialization = InformationRegisters.RequestsForPermissionsToUseExternalResources.WriteRequestsToXMLString(RequestsIDs);
		
	EndIf;
	
	ExecuteRequestProcessing(RequestsIDs, TempStorageAddress, StateTemporaryStorageAddress);
	
	If CallWithDisabledProfiles Then
		
		RollbackTransaction();
		InformationRegisters.RequestsForPermissionsToUseExternalResources.ReadRequestsFromXMLString(RequestsSerialization);
		
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure ExecuteDisableRequestProcessing(Val TempStorageAddress, Val StateTemporaryStorageAddress) Export
	
	Queries = New Array();
	
	BeginTransaction();
	
	Try
		
		IBProfileDeletionRequestID = SafeModeManagerInternal.RequestToDeleteSecurityProfile(
			Catalogs.MetadataObjectIDs.EmptyRef());
		
		Queries.Add(IBProfileDeletionRequestID);
		
		QueryText =
			"SELECT DISTINCT
			|	ExternalModulesAttachmentModes.ProgramModuleType AS ProgramModuleType,
			|	ExternalModulesAttachmentModes.ModuleID AS ModuleID
			|FROM
			|	InformationRegister.ExternalModulesAttachmentModes AS ExternalModulesAttachmentModes";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Queries.Add(SafeModeManagerInternal.RequestToDeleteSecurityProfile(
				SafeModeManagerInternal.ReferenceFormPermissionRegister(Selection.ProgramModuleType, Selection.ModuleID)));
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	ExecuteRequestProcessing(Queries, TempStorageAddress, StateTemporaryStorageAddress);
	
EndProcedure

// For internal use.
//
Procedure ExecuteRecoveryRequestProcessing(Val TempStorageAddress, Val StateTemporaryStorageAddress) Export
	
	BeginTransaction(); // 	
	Try
		ClearPermissions(, False);
		
		RequestsIDs = New Array;
		CommonClientServer.SupplementArray(RequestsIDs, 
			InformationRegisters.RequestsForPermissionsToUseExternalResources.ReplacementRequestsForAllGrantedPermissions());
		CommonClientServer.SupplementArray(RequestsIDs, 
			SafeModeManagerInternal.RequestsToUpdateApplicationPermissions(False));
		
		XMLRequests = InformationRegisters.RequestsForPermissionsToUseExternalResources.WriteRequestsToXMLString(RequestsIDs);
		ExecuteRequestProcessing(RequestsIDs, TempStorageAddress, StateTemporaryStorageAddress, True);
		
		RollbackTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	InformationRegisters.RequestsForPermissionsToUseExternalResources.ReadRequestsFromXMLString(XMLRequests);
	
EndProcedure

// For internal use.
//
Function ExecuteApplicabilityCheckRequestsProcessing() Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Transaction is active';");
	EndIf;
	
	BeginTransaction(); // 
	Try
	
		RequestsIDs = New Array;
		CommonClientServer.SupplementArray(RequestsIDs, 
			InformationRegisters.RequestsForPermissionsToUseExternalResources.ReplacementRequestsForAllGrantedPermissions());
		CommonClientServer.SupplementArray(RequestsIDs, 
			SafeModeManagerInternal.RequestsToUpdateApplicationPermissions(False));
		
		Manager = InformationRegisters.RequestsForPermissionsToUseExternalResources.PermissionsApplicationManager(RequestsIDs);
		XMLRequests = InformationRegisters.RequestsForPermissionsToUseExternalResources.WriteRequestsToXMLString(RequestsIDs);
		
		RollbackTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Result = New Structure();
	
	If Manager.MustApplyPermissionsInServersCluster() Then
		
		TempStorageAddress = PutToTempStorage(Undefined, New UUID());
		
		InformationRegisters.RequestsForPermissionsToUseExternalResources.ReadRequestsFromXMLString(XMLRequests);
		
		Result.Insert("CheckResult", False);
		Result.Insert("RequestsIDs", RequestsIDs);
		
		PermissionRequestState = New Structure();
		PermissionRequestState.Insert("Presentation", Manager.Presentation());
		PermissionRequestState.Insert("Scenario", Manager.ApplyingScenario());
		PermissionRequestState.Insert("State", Manager.WriteStateToXMLString());
		
		PutToTempStorage(PermissionRequestState, TempStorageAddress);
		Result.Insert("TempStorageAddress", TempStorageAddress);
		
		StateTemporaryStorageAddress = PutToTempStorage(Undefined, New UUID());
		
		State = New Structure();
		State.Insert("PermissionApplicationRequired", True);
		State.Insert("StorageAddress", TempStorageAddress);
		
		PutToTempStorage(State, StateTemporaryStorageAddress);
		Result.Insert("StateTemporaryStorageAddress", StateTemporaryStorageAddress);
		
	Else
		
		If Manager.RecordPermissionsToRegisterRequired() Then
			Manager.CompleteApplyRequestsToUseExternalResources();
		EndIf;
		
		Result.Insert("CheckResult", True);
		
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use.
//
Procedure CommitRequests(Val State) Export
	
	Manager = Create();
	Manager.ReadStateFromXMLString(State);
	
	Manager.CompleteApplyRequestsToUseExternalResources();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 
// 
//

// Sets an exclusive managed lock for tables of all registers used
// for storing a list of granted permissions.
//
// Parameters:
//  ProgramModule - AnyRef - a reference to the catalog item that corresponds to the external module whose information
//    on previously granted permissions must be cleared. If the parameter value is not specified,
//    information on granted permissions in all external modules will be blocked.
//   LockAttachmentModes - Boolean - indicates that additional lock of
//    external module attachment modes is required.
//
Procedure LockRegistersOfGrantedPermissions(Val ProgramModule = Undefined, Val LockAttachmentModes = True) Export
	
	If Not TransactionActive() Then
		Raise NStr("en = 'There must be an active transaction';");
	EndIf;
	
	Block = New DataLock();
	
	Registers = New Array();
	Registers.Add(InformationRegisters.PermissionsToUseExternalResources);
	
	If LockAttachmentModes Then
		Registers.Add(InformationRegisters.ExternalModulesAttachmentModes);
	EndIf;
	
	For Each Register In Registers Do
		RegisterLock = Block.Add(Register.CreateRecordSet().Metadata().FullName());
		If ProgramModule <> Undefined Then
			ModuleProperties = SafeModeManagerInternal.PropertiesForPermissionRegister(ProgramModule);
			RegisterLock.SetValue("ProgramModuleType", ModuleProperties.Type);
			RegisterLock.SetValue("ModuleID", ModuleProperties.Id);
		EndIf;
	EndDo;
	
	Block.Lock();
	
EndProcedure

// Clears information registers used for storing the list of granted permissions in the infobase.
//
// Parameters:
//  ProgramModule - AnyRef - a reference to the catalog item that corresponds to the external module whose information
//    on previously granted permissions must be cleared. If the parameter value is not specified,
//    information on granted permissions in all external modules will be cleared.
//   ClearAttachmentModes - Boolean - indicates whether additional clearing of
//    external module attachment modes is required.
//
Procedure ClearPermissions(Val ProgramModule = Undefined, Val ClearAttachmentModes = True) Export
	
	BeginTransaction();
	
	Try
		
		LockRegistersOfGrantedPermissions(ProgramModule, ClearAttachmentModes);
		
		Managers = New Array();
		Managers.Add(InformationRegisters.PermissionsToUseExternalResources);
		
		If ClearAttachmentModes Then
			Managers.Add(InformationRegisters.ExternalModulesAttachmentModes);
		EndIf;
		
		For Each Manager In Managers Do
			Set = Manager.CreateRecordSet(); // InformationRegisterRecordSet.PermissionsToUseExternalResources
			If ProgramModule <> Undefined Then
				ModuleProperties = SafeModeManagerInternal.PropertiesForPermissionRegister(ProgramModule);
				Set.Filter.ProgramModuleType.Set(ModuleProperties.Type);
				Set.Filter.ModuleID.Set(ModuleProperties.Id);
			EndIf;
			Set.Write(True);
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processing permission tables.
//

// Returns a permission table row that meets the filter condition.
// If the table does not contain rows meeting the filter condition, a new one can be added.
// If the table contains more than one row meeting the filter condition, an exception is generated.
//
// Parameters:
//  PermissionsTable - ValueTable:
//    * ProgramModuleType - CatalogRef.MetadataObjectIDs
//    * ModuleID - UUID
//    * Operation - EnumRef.SecurityProfileAdministrativeOperations
//    * Name - String - a security profile name.
//  Filter - Structure
//  AddIfAbsent - Boolean
//
// Returns:
//   - ValueTableRow
//   - Undefined
//
Function PermissionsTableRow(Val PermissionsTable, Val Filter, Val AddIfAbsent = True) Export
	
	Rows = PermissionsTable.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		
		If AddIfAbsent Then
			
			String = PermissionsTable.Add();
			FillPropertyValues(String, Filter);
			Return String;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	ElsIf Rows.Count() = 1 Then
		
		Return Rows.Get(0);
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Rows uniqueness violation in permission table by the filter %1';"),
			Common.ValueToXMLString(Filter));
		
	EndIf;
	
EndFunction

#EndRegion

#EndIf

