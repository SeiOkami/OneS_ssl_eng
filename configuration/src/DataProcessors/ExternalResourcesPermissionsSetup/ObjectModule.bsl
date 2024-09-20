///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

// 
// 
//
Var RequestsIDs;

// 
Var AdministrationOperations; // ValueTable:
//  * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs - 
//  * ИдентификаторПрограммногоМодуля - UUID - 
//  * Операция - EnumRef.SecurityProfileAdministrativeOperations - 
//  * Имя - String - name of the security profile.

// 
Var RequestsApplicationPlan; // Structure:
//  * Замещаемые - ValueTable -
//      * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторПрограммногоМодуля - UUID,
//      * ТипВладельца - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторВладельца - UUID,
//  * Добавляемые - ValueTable -
//      * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторПрограммногоМодуля - UUID,
//      * ТипВладельца - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторВладельца - UUID,
//      * Тип - String - name of the XDTO type that describes permissions,
//      * Разрешения - Map -
//         * Ключ - String -
//             
//         * Значение - XDTODataObject -
//      * ДополненияРазрешений - Map -
//         * Ключ - String -
//             
//         * Значение - 
//             
//  * Удаляемые - ValueTable -
//      * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторПрограммногоМодуля - UUID,
//      * ТипВладельца - CatalogRef.MetadataObjectIDs,
//      * ИдентификаторВладельца - UUID,
//      * Тип - String - name of the XDTO type that describes permissions,
//      * Разрешения - Map -
//         * Ключ - String -
//             
//         * Значение - XDTODataObject -
//      * ДополненияРазрешений - Map -
//         * Ключ - String -
//             
//         * Значение - 
//             

// 
Var SourcePermissionSliceByOwners; // ValueTable:
// * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
// * ИдентификаторПрограммногоМодуля - UUID,
// * ТипВладельца - CatalogRef.MetadataObjectIDs,
// * ИдентификаторВладельца - UUID,
// * Тип - String - name of the XDTO type that describes permissions,
// * Разрешения - Map -
//   * Ключ - String -
//      
//   * Значение - XDTODataObject -
// * ДополненияРазрешений - Map - description of the add-permission:
//   * Ключ - String -
//      
//   * Значение - 
//      

// 
Var SourcePermissionSliceIgnoringOwners; // ValueTable:
// * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
// * ИдентификаторПрограммногоМодуля - UUID,
// * Тип - String - name of the XDTO type that describes permissions,
// * Разрешения - Map -
//   * Ключ - String -
//      
//   * Значение - XDTODataObject -
// * ДополненияРазрешений - Map - description of the add-permission:
//   * Ключ - String -
//      
//   * Значение - 
//      

// 
Var RequestsApplicationResultByOwners; // ValueTable:
// * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
// * ИдентификаторПрограммногоМодуля - UUID,
// * ТипВладельца - CatalogRef.MetadataObjectIDs,
// * ИдентификаторВладельца - UUID,
// * Тип - String - name of the XDTO type that describes permissions,
// * Разрешения - Map -
//   * Ключ - String -
//      
//   * Значение - XDTODataObject -
// * ДополненияРазрешений - Map - description of the add-permission:
//   * Ключ - String -
//      
//   * Значение - 
//      

// 
Var RequestsApplicationResultIgnoringOwners; // ValueTable:
// * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
// * ИдентификаторПрограммногоМодуля - UUID,
// * Тип - String - name of the XDTO type that describes permissions,
// * Разрешения - Map -
//   * Ключ - String -
//      
//   * Значение - XDTODataObject -
// * ДополненияРазрешений - Map - description of the add-permission:
//   * Ключ - String -
//      
//   * Значение - 
//      

// 
Var DeltaByOwners; // Structure:
//  * Добавляемые - ValueTable -
//    * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторПрограммногоМодуля - UUID,
//    * ТипВладельца - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторВладельца - UUID,
//    * Тип - String - name of the XDTO type that describes permissions,
//    * Разрешения - Map -
//      * Ключ - String -
//         
//      * Значение - XDTODataObject -
//    * ДополненияРазрешений - Map - description of the add-permission:
//      * Ключ - String -
//         
//      * Значение - 
//         
//  * Удаляемые - ValueTable -
//    * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторПрограммногоМодуля - UUID,
//    * ТипВладельца - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторВладельца - UUID,
//    * Тип - String - name of the XDTO type that describes permissions,
//    * Разрешения - Map -
//      * Ключ - String -
//         
//      * Значение - XDTODataObject -
//    * ДополненияРазрешений - Map - description of the add-permission:
//      * Ключ - String -
//         
//      * Значение - 
//         

// 
Var DeltaIgnoringOwners; // Structure:
//  * Добавляемые - ValueTable -
//    * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторПрограммногоМодуля - UUID,
//    * Тип - String - name of the XDTO type that describes permissions,
//    * Разрешения - Map -
//      * Ключ - String -
//         
//      * Значение - XDTODataObject -
//    * ДополненияРазрешений - Map - description of the add-permission:
//      * Ключ - String -
//         
//      * Значение - 
//         
//  * Удаляемые - ValueTable -
//    * ТипПрограммногоМодуля - CatalogRef.MetadataObjectIDs,
//    * ИдентификаторПрограммногоМодуля - UUID,
//    * Тип - String - name of the XDTO type that describes permissions,
//    * Разрешения - Map -
//      * Ключ - String -
//         
//      * Значение - XDTODataObject -
//    * ДополненияРазрешений - Map - description of the add-permission:
//      * Ключ - String -
//         
//      * Значение - 
//         

// 
Var ClearingPermissionsBeforeApply; // Boolean

#EndRegion

#Region Internal

// Adds a permission ID to the list of permissions to be processed. Once the permissions are applied, the
// requests with added IDs are cleared.
//
// Parameters:
//  QueryID - UUID - an ID of the request to use
//    external resources.
//
Procedure AddRequestID(Val QueryID) Export
	
	RequestsIDs.Add(QueryID);
	
EndProcedure

// Adds a security profile administration operation to the request application plan.
//
// Parameters:
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  ModuleID - UUID,
//  Operation - EnumRef.SecurityProfileAdministrativeOperations,
//  Name - String - a security profile name.
//
Procedure AddAdministrationOperation(Val ProgramModuleType, Val ModuleID, Val Operation, Val Name) Export
	
	Filter = New Structure();
	Filter.Insert("ProgramModuleType", ProgramModuleType);
	Filter.Insert("ModuleID", ModuleID);
	Filter.Insert("Operation", Operation);
	
	Rows = AdministrationOperations.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		
		String = AdministrationOperations.Add();
		FillPropertyValues(String, Filter);
		String.Name = Name;
		
	EndIf;
	
EndProcedure

// Adds properties of the request for permissions to use external resources to the request application plan.
//
// Parameters:
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  ModuleID - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  ReplacementMode - Boolean,
//  PermissionsToAdd - Array of XDTODataObject, Undefined,
//  PermissionsToDelete - Array of XDTODataObject, Undefined
//
Procedure AddRequestForPermissionsToUseExternalResources(
		Val ProgramModuleType, Val ModuleID,
		Val OwnerType, Val OwnerID,
		Val ReplacementMode,
		Val PermissionsToAdd = Undefined,
		Val PermissionsToDelete = Undefined) Export
	
	Filter = New Structure();
	Filter.Insert("ProgramModuleType", ProgramModuleType);
	Filter.Insert("ModuleID", ModuleID);
	
	String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
		AdministrationOperations, Filter, False);
	
	If String = Undefined Then
		
		If ProgramModuleType = Catalogs.MetadataObjectIDs.EmptyRef() Then
			
			Name = Constants.InfobaseSecurityProfile.Get();
			
		Else
			
			Name = InformationRegisters.ExternalModulesAttachmentModes.ExternalModuleAttachmentMode(
				SafeModeManagerInternal.ReferenceFormPermissionRegister(
					ProgramModuleType, ModuleID));
			
		EndIf;
		
		AddAdministrationOperation(
			ProgramModuleType,
			ModuleID,
			Enums.SecurityProfileAdministrativeOperations.RefreshEnabled,
			Name);
		
	Else
		
		Name = String.Name;
		
	EndIf;
	
	If ReplacementMode Then
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", ProgramModuleType);
		Filter.Insert("ModuleID", ModuleID);
		Filter.Insert("OwnerType", OwnerType);
		Filter.Insert("OwnerID", OwnerID);
		
		DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
			RequestsApplicationPlan.PermissionsToReplace, Filter);
		
	EndIf;
	
	If PermissionsToAdd <> Undefined Then
		
		For Each PermissionToAdd In PermissionsToAdd Do
			
			Filter = New Structure();
			Filter.Insert("ProgramModuleType", ProgramModuleType);
			Filter.Insert("ModuleID", ModuleID);
			Filter.Insert("OwnerType", OwnerType);
			Filter.Insert("OwnerID", OwnerID);
			Filter.Insert("Type", PermissionToAdd.Type().Name);
			
			String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
				RequestsApplicationPlan.ItemsToAdd, Filter);
			
			PermissionKey = InformationRegisters.PermissionsToUseExternalResources.PermissionKey(PermissionToAdd);
			PermissionAddition = InformationRegisters.PermissionsToUseExternalResources.PermissionAddition(PermissionToAdd);
			
			String.Permissions.Insert(PermissionKey, Common.XDTODataObjectToXMLString(PermissionToAdd));
			
			If ValueIsFilled(PermissionAddition) Then
				String.PermissionsAdditions.Insert(PermissionKey, Common.ValueToXMLString(PermissionAddition));
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If PermissionsToDelete <> Undefined Then
		
		For Each PermissionToDelete In PermissionsToDelete Do
			
			Filter = New Structure();
			Filter.Insert("ProgramModuleType", ProgramModuleType);
			Filter.Insert("ModuleID", ModuleID);
			Filter.Insert("OwnerType", OwnerType);
			Filter.Insert("OwnerID", OwnerID);
			Filter.Insert("Type", PermissionToDelete.Type().Name);
			
			String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
				RequestsApplicationPlan.ItemsToDelete, Filter);
			
			PermissionKey = InformationRegisters.PermissionsToUseExternalResources.PermissionKey(PermissionToDelete);
			PermissionAddition = InformationRegisters.PermissionsToUseExternalResources.PermissionAddition(PermissionToDelete);
			
			String.Permissions.Insert(PermissionKey, Common.XDTODataObjectToXMLString(PermissionToDelete));
			
			If ValueIsFilled(PermissionAddition) Then
				String.PermissionsAdditions.Insert(PermissionKey, Common.ValueToXMLString(PermissionAddition));
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Adds a flag whether to clear permission data from the registers to the request application plan.
// Used to restore profiles.
//
Procedure AddClearingPermissionsBeforeApplying() Export
	
	ClearingPermissionsBeforeApply = True;
	
EndProcedure

// Calculates a result of application of requests to use external resources.
//
Procedure CalculateRequestsApplication() Export
	
	ExternalTransaction = TransactionActive();
	If Not ExternalTransaction Then
		BeginTransaction(); // CAC:326 there in no paired CommitTransaction for StartTransaction since the action is being canceled.
	EndIf;
	
	Try
		DataProcessors.ExternalResourcesPermissionsSetup.LockRegistersOfGrantedPermissions();
		
		SourcePermissionSliceByOwners = InformationRegisters.PermissionsToUseExternalResources.PermissionsSlice();
		CalculateRequestsApplicationResultByOwners();
		CalculateDeltaByOwners();
		
		SourcePermissionSliceIgnoringOwners = InformationRegisters.PermissionsToUseExternalResources.PermissionsSlice(False, True);
		CalculateRequestsApplicationResultIgnoringOwners();
		CalculateDeltaIgnoringOwners();
		
		If Not ExternalTransaction Then
			RollbackTransaction();
		EndIf;
	Except
		If Not ExternalTransaction Then
			RollbackTransaction();
		EndIf;
		Raise;
	EndTry;
	
	If MustApplyPermissionsInServersCluster() Then
		
		Try
			LockDataForEdit(Semaphore());
		Except
			Raise
				NStr("en = 'An error occurred when competitively accessing settings of permissions for external resource usage.
				           |Try to execute the operation later.';");
		EndTry;
		
	EndIf;
	
EndProcedure

// Checks whether permissions must be applied in the server cluster.
//
// Returns:
//   Boolean
//
Function MustApplyPermissionsInServersCluster() Export
	
	If DeltaIgnoringOwners.ItemsToAdd.Count() > 0 Then
		Return True;
	EndIf;
	
	If DeltaIgnoringOwners.ItemsToDelete.Count() > 0 Then
		Return True;
	EndIf;
	
	For Each AdministrationOperation In AdministrationOperations Do
		If AdministrationOperation.Operation = Enums.SecurityProfileAdministrativeOperations.Delete Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks whether the permissions must be written to registers.
//
// Returns:
//   Boolean
//
Function RecordPermissionsToRegisterRequired() Export
	
	If DeltaByOwners.ItemsToAdd.Count() > 0 Then
		Return True;
	EndIf;
	
	If DeltaByOwners.ItemsToDelete.Count() > 0 Then
		Return True;
	EndIf;
	
	For Each AdministrationOperation In AdministrationOperations Do
		If AdministrationOperation.Operation = Enums.SecurityProfileAdministrativeOperations.Delete Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Returns a presentation of requests for permissions to use external resources.
//
// Parameters:
//  AsRequired - Boolean - a presentation is generated as a list of permissions, not as a list of operations
//    upon changing permissions.
//
// Returns:
//   SpreadsheetDocument
//
Function Presentation(Val AsRequired = False) Export
	
	Return Reports.ExternalResourcesInUse.RequestsForPermissionsToUseExternalResoursesPresentation(
		AdministrationOperations,
		DeltaIgnoringOwners.ItemsToAdd,
		DeltaIgnoringOwners.ItemsToDelete,
		AsRequired);
	
EndFunction

// Returns a scenario of applying requests for permissions to use external resources.
//
// Returns:
//   Array of Structure:
//                        * Operation - EnumRef.SecurityProfileAdministrativeOperations,
//                        * Profile - String - a security profile name,
//                        * Permissions - See ClusterAdministration.SecurityProfileProperties
//
Function ApplyingScenario() Export
	
	Result = New Array();
	
	For Each LongDesc In AdministrationOperations Do
		
		ResultItem = New Structure("Operation,Profile,Permissions");
		ResultItem.Operation = LongDesc.Operation;
		ResultItem.Profile = LongDesc.Name;
		ResultItem.Permissions = ProfileInClusterAdministrationInterfaceNotation(ResultItem.Profile, LongDesc.ProgramModuleType, LongDesc.ModuleID);
		
		IsConfigurationProfile = (LongDesc.ProgramModuleType = Catalogs.MetadataObjectIDs.EmptyRef());
		
		If IsConfigurationProfile Then
			
			AdditionalOperationPriority = False;
			
			If LongDesc.Operation = Enums.SecurityProfileAdministrativeOperations.Creating Then
				AdditionalOperation = Enums.SecurityProfileAdministrativeOperations.Purpose;
			EndIf;
			
			If LongDesc.Operation = Enums.SecurityProfileAdministrativeOperations.Delete Then
				AdditionalOperation = Enums.SecurityProfileAdministrativeOperations.AssignmentDeletion;
				AdditionalOperationPriority = True;
			EndIf;
			
			AdditionalItem = New Structure("Operation,Profile,Permissions", AdditionalOperation, LongDesc.Name);
			
		EndIf;
		
		If IsConfigurationProfile And AdditionalOperationPriority Then
			
			Result.Add(AdditionalItem);
			
		EndIf;
		
		Result.Add(ResultItem);
		
		If IsConfigurationProfile And Not AdditionalOperationPriority Then
			
			Result.Add(AdditionalItem);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Serializes an internal state of the object.
//
// Returns:
//   String
//
Function WriteStateToXMLString() Export
	
	State = New Structure();
	
	State.Insert("SourcePermissionSliceByOwners", SourcePermissionSliceByOwners);
	State.Insert("RequestsApplicationResultByOwners", RequestsApplicationResultByOwners);
	State.Insert("DeltaByOwners", DeltaByOwners);
	State.Insert("SourcePermissionSliceIgnoringOwners", SourcePermissionSliceIgnoringOwners);
	State.Insert("RequestsApplicationResultIgnoringOwners", RequestsApplicationResultIgnoringOwners);
	State.Insert("DeltaIgnoringOwners", DeltaIgnoringOwners);
	State.Insert("AdministrationOperations", AdministrationOperations);
	State.Insert("RequestsIDs", RequestsIDs);
	State.Insert("ClearingPermissionsBeforeApply", ClearingPermissionsBeforeApply);
	
	Return Common.ValueToXMLString(State);
	
EndFunction

// Deserializes an internal object state.
//
// Parameters:
//  XMLLine - String - a result returned by the WriteStateToXMLString() function.
//
Procedure ReadStateFromXMLString(Val XMLLine) Export
	
	State = Common.ValueFromXMLString(XMLLine);
	
	SourcePermissionSliceByOwners = State.SourcePermissionSliceByOwners;
	RequestsApplicationResultByOwners = State.RequestsApplicationResultByOwners;
	DeltaByOwners = State.DeltaByOwners;
	SourcePermissionSliceIgnoringOwners = State.SourcePermissionSliceIgnoringOwners;
	RequestsApplicationResultIgnoringOwners = State.RequestsApplicationResultIgnoringOwners;
	DeltaIgnoringOwners = State.DeltaIgnoringOwners;
	AdministrationOperations = State.AdministrationOperations;
	RequestsIDs = State.RequestsIDs;
	ClearingPermissionsBeforeApply = State.ClearingPermissionsBeforeApply;
	
EndProcedure

// Saves in the infobase the fact that requests to use external resource are applied.
//
Procedure CompleteApplyRequestsToUseExternalResources() Export
	
	BeginTransaction();
	Try
		
		If RecordPermissionsToRegisterRequired() Then
			
			If ClearingPermissionsBeforeApply Then
				
				DataProcessors.ExternalResourcesPermissionsSetup.ClearPermissions(, False);
				
			EndIf;
			
			For Each ItemsToDelete In DeltaByOwners.ItemsToDelete Do
				
				For Each KeyAndValue In ItemsToDelete.Permissions Do
					
					InformationRegisters.PermissionsToUseExternalResources.DeletePermission(
						ItemsToDelete.ProgramModuleType,
						ItemsToDelete.ModuleID,
						ItemsToDelete.OwnerType,
						ItemsToDelete.OwnerID,
						KeyAndValue.Key,
						Common.XDTODataObjectFromXMLString(KeyAndValue.Value));
					
				EndDo;
				
			EndDo;
			
			For Each ItemsToAdd In DeltaByOwners.ItemsToAdd Do
				
				For Each KeyAndValue In ItemsToAdd.Permissions Do
					
					AddOn = ItemsToAdd.PermissionsAdditions.Get(KeyAndValue.Key);
					If AddOn <> Undefined Then
						AddOn = Common.ValueFromXMLString(AddOn);
					EndIf;
					
					InformationRegisters.PermissionsToUseExternalResources.AddPermission(
						ItemsToAdd.ProgramModuleType,
						ItemsToAdd.ModuleID,
						ItemsToAdd.OwnerType,
						ItemsToAdd.OwnerID,
						KeyAndValue.Key,
						Common.XDTODataObjectFromXMLString(KeyAndValue.Value),
						AddOn);
					
				EndDo;
				
			EndDo;
			
			For Each LongDesc In AdministrationOperations Do
				
				IsConfigurationProfile = (LongDesc.ProgramModuleType = Catalogs.MetadataObjectIDs.EmptyRef());
				
				If LongDesc.Operation = Enums.SecurityProfileAdministrativeOperations.Creating Then
					
					If IsConfigurationProfile Then
						
						Constants.InfobaseSecurityProfile.Set(LongDesc.Name);
						
					Else
						
						Manager = InformationRegisters.ExternalModulesAttachmentModes.CreateRecordManager();
						Manager.ProgramModuleType = LongDesc.ProgramModuleType;
						Manager.ModuleID = LongDesc.ModuleID;
						Manager.SafeMode = LongDesc.Name;
						Manager.Write();
						
					EndIf;
					
				EndIf;
				
				If LongDesc.Operation = Enums.SecurityProfileAdministrativeOperations.Delete Then
					
					If IsConfigurationProfile Then
						
						Constants.InfobaseSecurityProfile.Set("");
						DataProcessors.ExternalResourcesPermissionsSetup.ClearPermissions();
						
					Else
						
						ProgramModule = SafeModeManagerInternal.ReferenceFormPermissionRegister(
							LongDesc.ProgramModuleType, LongDesc.ModuleID);
						DataProcessors.ExternalResourcesPermissionsSetup.ClearPermissions(
							ProgramModule, True);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		InformationRegisters.RequestsForPermissionsToUseExternalResources.DeleteRequests(RequestsIDs);
		InformationRegisters.RequestsForPermissionsToUseExternalResources.ClearObsoleteRequests();
		
		UnlockDataForEdit(Semaphore());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

// Calculates a request application result by owners.
//
Procedure CalculateRequestsApplicationResultByOwners()
	
	RequestsApplicationResultByOwners = New ValueTable();
	
	For Each SourceColumn In SourcePermissionSliceByOwners.Columns Do
		RequestsApplicationResultByOwners.Columns.Add(SourceColumn.Name, SourceColumn.ValueType);
	EndDo;
	
	For Each InitialString In SourcePermissionSliceByOwners Do
		NewRow = RequestsApplicationResultByOwners.Add();
		FillPropertyValues(NewRow, InitialString);
	EndDo;
	
	// Apply the plan.
	
	// Overwrite
	For Each ReplacementTableRow In RequestsApplicationPlan.PermissionsToReplace Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", ReplacementTableRow.ProgramModuleType);
		Filter.Insert("ModuleID", ReplacementTableRow.ModuleID);
		Filter.Insert("OwnerType", ReplacementTableRow.OwnerType);
		Filter.Insert("OwnerID", ReplacementTableRow.OwnerID);
		
		Rows = RequestsApplicationResultByOwners.FindRows(Filter);
		
		For Each String In Rows Do
			RequestsApplicationResultByOwners.Delete(String);
		EndDo;
		
	EndDo;
	
	// Add permissions.
	For Each AddedItemsRow In RequestsApplicationPlan.ItemsToAdd Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", AddedItemsRow.ProgramModuleType);
		Filter.Insert("ModuleID", AddedItemsRow.ModuleID);
		Filter.Insert("OwnerType", AddedItemsRow.OwnerType);
		Filter.Insert("OwnerID", AddedItemsRow.OwnerID);
		Filter.Insert("Type", AddedItemsRow.Type);
		
		String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
			RequestsApplicationResultByOwners, Filter);
		
		For Each KeyAndValue In AddedItemsRow.Permissions Do
			
			String.Permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
			If AddedItemsRow.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
				String.PermissionsAdditions.Insert(KeyAndValue.Key, AddedItemsRow.PermissionsAdditions.Get(KeyAndValue.Key));
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Delete permissions
	For Each ItemsToDeleteRow In RequestsApplicationPlan.ItemsToDelete Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", ItemsToDeleteRow.ProgramModuleType);
		Filter.Insert("ModuleID", ItemsToDeleteRow.ModuleID);
		Filter.Insert("OwnerType", ItemsToDeleteRow.OwnerType);
		Filter.Insert("OwnerID", ItemsToDeleteRow.OwnerID);
		Filter.Insert("Type", ItemsToDeleteRow.Type);
		
		String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
			RequestsApplicationResultByOwners, Filter);
		
		For Each KeyAndValue In ItemsToDeleteRow.Permissions Do
			
			String.Permissions.Delete(KeyAndValue.Key);
			
			If ItemsToDeleteRow.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
				
				String.PermissionsAdditions.Insert(KeyAndValue.Key, ItemsToDeleteRow.PermissionsAdditions.Get(KeyAndValue.Key));
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates a request application result ignoring owners.
//
Procedure CalculateRequestsApplicationResultIgnoringOwners()
	
	RequestsApplicationResultIgnoringOwners = New ValueTable();
	
	For Each SourceColumn In SourcePermissionSliceIgnoringOwners.Columns Do
		RequestsApplicationResultIgnoringOwners.Columns.Add(SourceColumn.Name, SourceColumn.ValueType);
	EndDo;
	
	For Each ResultString1 In RequestsApplicationResultByOwners Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", ResultString1.ProgramModuleType);
		Filter.Insert("ModuleID", ResultString1.ModuleID);
		Filter.Insert("Type", ResultString1.Type);
		
		String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
			RequestsApplicationResultIgnoringOwners, Filter);
		
		For Each KeyAndValue In ResultString1.Permissions Do
			
			SourcePermission = Common.XDTODataObjectFromXMLString(KeyAndValue.Value);
			// Details must not affect hash sums for an option without owners.
			PermissionDetails = SourcePermission.Description;
			SourcePermission.Description = ""; 
			PermissionKey = InformationRegisters.PermissionsToUseExternalResources.PermissionKey(SourcePermission);
			
			Resolution = String.Permissions.Get(PermissionKey);
			If Resolution = Undefined Then
				
				If ResultString1.Type = "FileSystemAccess" Then
					
					// 
					// 
					
					If SourcePermission.AllowedRead Then
						
						If SourcePermission.AllowedWrite Then
							
							// Searching for the read permission for the same catalog.
							PermissionCopy = Common.XDTODataObjectFromXMLString(Common.XDTODataObjectToXMLString(SourcePermission));
							PermissionCopy.AllowedWrite = False;
							CopyKey = InformationRegisters.PermissionsToUseExternalResources.PermissionKey(PermissionCopy);
							
							// Deleting the nested permission. It becomes useless once the current one is added.
							NestedPermission = String.Permissions.Get(CopyKey);
							If NestedPermission <> Undefined Then
								String.Permissions.Delete(CopyKey);
							EndIf;
							
						Else
							
							// 
							PermissionCopy = Common.XDTODataObjectFromXMLString(Common.XDTODataObjectToXMLString(SourcePermission));
							PermissionCopy.AllowedWrite = True;
							CopyKey = InformationRegisters.PermissionsToUseExternalResources.PermissionKey(PermissionCopy);
							
							// No need to process the permission, the catalog is available by the parent permission.
							ParentPermission = String.Permissions.Get(CopyKey);
							If ParentPermission <> Undefined Then
								Continue;
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				SourcePermission.Description = PermissionDetails; 
				String.Permissions.Insert(PermissionKey, Common.XDTODataObjectToXMLString(SourcePermission));
				
				AddOn = ResultString1.PermissionsAdditions.Get(KeyAndValue.Key);
				If AddOn <> Undefined Then
					String.PermissionsAdditions.Insert(PermissionKey, AddOn);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates a delta between two permission slices by owners.
//
Procedure CalculateDeltaByOwners()
	
	DeltaByOwners = New Structure();
	
	DeltaByOwners.Insert("ItemsToAdd", New ValueTable);
	DeltaByOwners.ItemsToAdd.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaByOwners.ItemsToAdd.Columns.Add("ModuleID", New TypeDescription("UUID"));
	DeltaByOwners.ItemsToAdd.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaByOwners.ItemsToAdd.Columns.Add("OwnerID", New TypeDescription("UUID"));
	DeltaByOwners.ItemsToAdd.Columns.Add("Type", New TypeDescription("String"));
	DeltaByOwners.ItemsToAdd.Columns.Add("Permissions", New TypeDescription("Map"));
	DeltaByOwners.ItemsToAdd.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	DeltaByOwners.Insert("ItemsToDelete", New ValueTable);
	DeltaByOwners.ItemsToDelete.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaByOwners.ItemsToDelete.Columns.Add("ModuleID", New TypeDescription("UUID"));
	DeltaByOwners.ItemsToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaByOwners.ItemsToDelete.Columns.Add("OwnerID", New TypeDescription("UUID"));
	DeltaByOwners.ItemsToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaByOwners.ItemsToDelete.Columns.Add("Permissions", New TypeDescription("Map"));
	DeltaByOwners.ItemsToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	// Comparing source permissions with the resulting ones.
	
	For Each String In SourcePermissionSliceByOwners Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", String.ProgramModuleType);
		Filter.Insert("ModuleID", String.ModuleID);
		Filter.Insert("OwnerType", String.OwnerType);
		Filter.Insert("OwnerID", String.OwnerID);
		Filter.Insert("Type", String.Type);
		
		Rows = RequestsApplicationResultByOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			ResultString1 = Rows.Get(0);
		Else
			ResultString1 = Undefined;
		EndIf;
		
		For Each KeyAndValue In String.Permissions Do
			
			If ResultString1 = Undefined Or ResultString1.Permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission was in the source ones  but it is absent in the resulting ones, it is a permission being deleted.
				
				ItemsToDeleteRow = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
					DeltaByOwners.ItemsToDelete, Filter);
				
				If ItemsToDeleteRow.Permissions.Get(KeyAndValue.Key) = Undefined Then
					
					ItemsToDeleteRow.Permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						ItemsToDeleteRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Comparing the resulting permissions with the source ones.
	
	For Each String In RequestsApplicationResultByOwners Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", String.ProgramModuleType);
		Filter.Insert("ModuleID", String.ModuleID);
		Filter.Insert("OwnerType", String.OwnerType);
		Filter.Insert("OwnerID", String.OwnerID);
		Filter.Insert("Type", String.Type);
		
		Rows = SourcePermissionSliceByOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			InitialString = Rows.Get(0);
		Else
			InitialString = Undefined;
		EndIf;
		
		For Each KeyAndValue In String.Permissions Do
			
			If InitialString = Undefined Or InitialString.Permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission is in resulting ones but it is absent in the source ones, it is a permission being added.
				
				PermissionsToAddRow = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
					DeltaByOwners.ItemsToAdd, Filter);
				
				If PermissionsToAddRow.Permissions.Get(KeyAndValue.Key) = Undefined Then
					
					PermissionsToAddRow.Permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						PermissionsToAddRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Calculates a delta between two permission slices ignoring owners.
//
Procedure CalculateDeltaIgnoringOwners()
	
	DeltaIgnoringOwners = New Structure();
	
	DeltaIgnoringOwners.Insert("ItemsToAdd", New ValueTable);
	DeltaIgnoringOwners.ItemsToAdd.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaIgnoringOwners.ItemsToAdd.Columns.Add("ModuleID", New TypeDescription("UUID"));
	DeltaIgnoringOwners.ItemsToAdd.Columns.Add("Type", New TypeDescription("String"));
	DeltaIgnoringOwners.ItemsToAdd.Columns.Add("Permissions", New TypeDescription("Map"));
	DeltaIgnoringOwners.ItemsToAdd.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	DeltaIgnoringOwners.Insert("ItemsToDelete", New ValueTable);
	DeltaIgnoringOwners.ItemsToDelete.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DeltaIgnoringOwners.ItemsToDelete.Columns.Add("ModuleID", New TypeDescription("UUID"));
	DeltaIgnoringOwners.ItemsToDelete.Columns.Add("Type", New TypeDescription("String"));
	DeltaIgnoringOwners.ItemsToDelete.Columns.Add("Permissions", New TypeDescription("Map"));
	DeltaIgnoringOwners.ItemsToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	// Comparing source permissions with the resulting ones.
	
	For Each String In SourcePermissionSliceIgnoringOwners Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", String.ProgramModuleType);
		Filter.Insert("ModuleID", String.ModuleID);
		Filter.Insert("Type", String.Type);
		
		Rows = RequestsApplicationResultIgnoringOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			ResultString1 = Rows.Get(0);
		Else
			ResultString1 = Undefined;
		EndIf;
		
		For Each KeyAndValue In String.Permissions Do
			
			If ResultString1 = Undefined Or ResultString1.Permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission was in the source ones  but it is absent in the resulting ones, it is a permission being deleted.
				
				ItemsToDeleteRow = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
					DeltaIgnoringOwners.ItemsToDelete, Filter);
				
				If ItemsToDeleteRow.Permissions.Get(KeyAndValue.Key) = Undefined Then
					
					ItemsToDeleteRow.Permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						ItemsToDeleteRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Comparing the resulting permissions with the source ones.
	
	For Each String In RequestsApplicationResultIgnoringOwners Do
		
		Filter = New Structure();
		Filter.Insert("ProgramModuleType", String.ProgramModuleType);
		Filter.Insert("ModuleID", String.ModuleID);
		Filter.Insert("Type", String.Type);
		
		Rows = SourcePermissionSliceIgnoringOwners.FindRows(Filter);
		If Rows.Count() > 0 Then
			InitialString = Rows.Get(0);
		Else
			InitialString = Undefined;
		EndIf;
		
		For Each KeyAndValue In String.Permissions Do
			
			If InitialString = Undefined Or InitialString.Permissions.Get(KeyAndValue.Key) = Undefined Then
				
				// The permission is in resulting ones but it is absent in the source ones, it is a permission being added.
				
				PermissionsToAddRow = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
					DeltaIgnoringOwners.ItemsToAdd, Filter);
				
				If PermissionsToAddRow.Permissions.Get(KeyAndValue.Key) = Undefined Then
					
					PermissionsToAddRow.Permissions.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
					If String.PermissionsAdditions.Get(KeyAndValue.Key) <> Undefined Then
						PermissionsToAddRow.PermissionsAdditions.Insert(KeyAndValue.Key, String.PermissionsAdditions.Get(KeyAndValue.Key));
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Creates security profile details in the
// cluster server administration interface notation.
//
// Parameters:
//  ProfileName - String - a security profile name,
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  ModuleID - UUID
//
// Returns:
//   See ClusterAdministration.SecurityProfileProperties
//
Function ProfileInClusterAdministrationInterfaceNotation(Val ProfileName, Val ProgramModuleType, Val ModuleID)
	
	Profile = ClusterAdministration.SecurityProfileProperties();
	Profile.Name = ProfileName;
	Profile.LongDesc = NewSecurityProfileDetails(ProgramModuleType, ModuleID);
	Profile.SafeModeProfile = True;
	
	Profile.FileSystemFullAccess = False;
	Profile.COMObjectFullAccess = False;
	Profile.AddInFullAccess = False;
	Profile.ExternalModuleFullAccess = False;
	Profile.FullOperatingSystemApplicationAccess = False;
	Profile.InternetResourcesFullAccess = False;
	
	Profile.FullAccessToPrivilegedMode = False;
	
	Filter = New Structure();
	Filter.Insert("ProgramModuleType", ProgramModuleType);
	Filter.Insert("ModuleID", ModuleID);
	
	Rows = RequestsApplicationResultIgnoringOwners.FindRows(Filter);
	
	For Each String In Rows Do
		
		For Each KeyAndValue In String.Permissions Do
			
			Resolution = Common.XDTODataObjectFromXMLString(KeyAndValue.Value);
			
			If String.Type = "FileSystemAccess" Then
				
				If StandardVirtualDirectories().Get(Resolution.Path) <> Undefined Then
					
					ISecurityProfileVirtualDirectory = ClusterAdministration.VirtualDirectoryProperties();
					ISecurityProfileVirtualDirectory.LogicalURL = Resolution.Path;
					ISecurityProfileVirtualDirectory.PhysicalURL = StandardVirtualDirectories().Get(Resolution.Path);
					ISecurityProfileVirtualDirectory.DataReader = Resolution.AllowedRead;
					ISecurityProfileVirtualDirectory.DataWriter = Resolution.AllowedWrite;
					ISecurityProfileVirtualDirectory.LongDesc = Resolution.Description;
					Profile.VirtualDirectories.Add(ISecurityProfileVirtualDirectory);
					
				Else
					
					ISecurityProfileVirtualDirectory = ClusterAdministration.VirtualDirectoryProperties();
					ISecurityProfileVirtualDirectory.LogicalURL = Resolution.Path;
					ISecurityProfileVirtualDirectory.PhysicalURL = EscapePercentChar(Resolution.Path);
					ISecurityProfileVirtualDirectory.DataReader = Resolution.AllowedRead;
					ISecurityProfileVirtualDirectory.DataWriter = Resolution.AllowedWrite;
					ISecurityProfileVirtualDirectory.LongDesc = Resolution.Description;
					Profile.VirtualDirectories.Add(ISecurityProfileVirtualDirectory);
					
				EndIf;
				
			ElsIf String.Type = "CreateComObject" Then
				
				COMClass = ClusterAdministration.COMClassProperties();
				COMClass.Name = Resolution.ProgId;
				COMClass.CLSID = Resolution.CLSID;
				COMClass.Computer = Resolution.ComputerName;
				COMClass.LongDesc = Resolution.Description;
				Profile.COMClasses.Add(COMClass);
				
			ElsIf String.Type = "AttachAddin" Then
				
				AddOn = Common.ValueFromXMLString(String.PermissionsAdditions.Get(KeyAndValue.Key));
				For Each AdditionKeyAndValue In AddOn Do
					
					AddIn = ClusterAdministration.AddInProperties();
					AddIn.Name = Resolution.TemplateName + "\" + AdditionKeyAndValue.Key;
					AddIn.HashSum = AdditionKeyAndValue.Value;
					AddIn.LongDesc = Resolution.Description;
					Profile.AddIns.Add(AddIn);
					
				EndDo;
				
			ElsIf String.Type = "ExternalModule" Then
				
				ExternalModule = ClusterAdministration.ExternalModuleProperties();
				ExternalModule.Name = Resolution.Name;
				ExternalModule.HashSum = Resolution.Hash;
				ExternalModule.LongDesc = Resolution.Description;
				Profile.ExternalModules.Add(ExternalModule);
				
			ElsIf String.Type = "RunApplication" Then
				
				OSApplication = ClusterAdministration.OSApplicationProperties();
				OSApplication.Name = Resolution.CommandMask;
				OSApplication.CommandLinePattern = Resolution.CommandMask;
				OSApplication.LongDesc = Resolution.Description;
				Profile.OSApplications.Add(OSApplication);
				
			ElsIf String.Type = "InternetResourceAccess" Then
				
				InternetResource = ClusterAdministration.InternetResourceProperties();
				InternetResource.Name = Lower(Resolution.Protocol) + "://" + Lower(Resolution.Host) + ":" + Resolution.Port;
				InternetResource.Protocol = Resolution.Protocol;
				InternetResource.Address = Resolution.Host;
				InternetResource.Port = Resolution.Port;
				InternetResource.LongDesc = Resolution.Description;
				Profile.InternetResources.Add(InternetResource);
				
			ElsIf String.Type = "ExternalModulePrivilegedModeAllowed" Then
				
				Profile.FullAccessToPrivilegedMode = True;
				
			EndIf;
			
			
		EndDo;
		
	EndDo;
	
	Return Profile;
	
EndFunction

// Generates security profile details for the infobase or the external module.
//
// Parameters:
//  ExternalModule - AnyRef - a reference to the catalog item used
//    as an external module.
//
// Returns: 
//   String - 
//
Function NewSecurityProfileDetails(Val ProgramModuleType, Val ModuleID)
	
	Template = NStr("en = '[Infobase %1] %2 ""%3""';");
	
	IBName = "";
	ConnectionString = InfoBaseConnectionString();
	Substrings = StrSplit(ConnectionString, ";");
	For Each Substring In Substrings Do
		If StrStartsWith(Substring, "Ref") Then
			IBName = StrReplace(Right(Substring, StrLen(Substring) - 4), """", "");
		EndIf;
	EndDo;
	If IsBlankString(IBName) Then
		Raise NStr("en = 'Infobase connection string must contain the infobase.';");
	EndIf;
	
	If ProgramModuleType = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return StringFunctionsClientServer.SubstituteParametersToString(Template, IBName,
			NStr("en = 'Security profile for infobase';"), InfoBaseConnectionString());
	Else
		ProgramModule = SafeModeManagerInternal.ReferenceFormPermissionRegister(ProgramModuleType, ModuleID);
		Dictionary = SafeModeManagerInternal.ExternalModuleManager(ProgramModule).ExternalModuleContainerDictionary();
		ModuleDescription = Common.ObjectAttributeValue(ProgramModule, "Description");
		Return StringFunctionsClientServer.SubstituteParametersToString(Template, IBName, Dictionary.Nominative, ModuleDescription);
	EndIf;
	
EndFunction

// Returns physical paths of standard virtual directories.
//
// Returns:
//   Map of KeyAndValue:
//                         * Key - String - a virtual directory alias,
//                         * Value - String - a physical path.
//
Function StandardVirtualDirectories()
	
	Result = New Map();
	
	Result.Insert("/temp", "%t/%r/%s/%p");
	Result.Insert("/bin", "%e");
	
	Return Result;
	
EndFunction

// Escapes the percent character in the physical path of the virtual directory.
//
// Parameters:
//  InitialString - String - a source physical path of the virtual directory.
//
// Returns:
//   String
//
Function EscapePercentChar(Val InitialString)
	
	Return StrReplace(InitialString, "%", "%%");
	
EndFunction

// Returns a semaphore to be used when applying requests to use external resources.
//
// Returns:
//   InformationRegisterRecordKey.RequestsForPermissionsToUseExternalResources
//
Function Semaphore()
	
	Var_Key = New Structure();
	Var_Key.Insert("QueryID", New UUID("8e02fbd3-3f9f-4c3c-964d-7c602ad4eb38"));
	
	Return InformationRegisters.RequestsForPermissionsToUseExternalResources.CreateRecordKey(Var_Key);
	
EndFunction

#EndRegion

#Region Initialization

RequestsIDs = New Array();

RequestsApplicationPlan = New Structure();

RequestsApplicationPlan.Insert("PermissionsToReplace", New ValueTable);
RequestsApplicationPlan.PermissionsToReplace.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.PermissionsToReplace.Columns.Add("ModuleID", New TypeDescription("UUID"));
RequestsApplicationPlan.PermissionsToReplace.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.PermissionsToReplace.Columns.Add("OwnerID", New TypeDescription("UUID"));

RequestsApplicationPlan.Insert("ItemsToAdd", New ValueTable);
RequestsApplicationPlan.ItemsToAdd.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("ModuleID", New TypeDescription("UUID"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("OwnerID", New TypeDescription("UUID"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("Type", New TypeDescription("String"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("Permissions", New TypeDescription("Map"));
RequestsApplicationPlan.ItemsToAdd.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));

RequestsApplicationPlan.Insert("ItemsToDelete", New ValueTable);
RequestsApplicationPlan.ItemsToDelete.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("ModuleID", New TypeDescription("UUID"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("OwnerID", New TypeDescription("UUID"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("Type", New TypeDescription("String"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("Permissions", New TypeDescription("Map"));
RequestsApplicationPlan.ItemsToDelete.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));

AdministrationOperations = New ValueTable;
AdministrationOperations.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
AdministrationOperations.Columns.Add("ModuleID", New TypeDescription("UUID"));
AdministrationOperations.Columns.Add("Operation", New TypeDescription("EnumRef.SecurityProfileAdministrativeOperations"));
AdministrationOperations.Columns.Add("Name", New TypeDescription("String"));

ClearingPermissionsBeforeApply = False;

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf