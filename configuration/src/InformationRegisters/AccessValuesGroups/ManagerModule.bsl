///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// It must be called:
// 1) When adding a new user (or an external user),
//    When adding a new user group (or an external user group),
//    when changing the user group members (or groups of external users).
//    Parameters = Structure with one of the properties or both of them:
//    - Users: a single user or an array.
//    - UserGroups: a single user group or an array.
//
// 2) When changing assignee groups.
//    Parameters = Structure with one property:
//    - PerformersGroups: Undefined, a single assignee group or an array.
//
// 3) When changing an authorization object of an external user.
//    Parameters = Structure with one property:
//    - AuthorizationObjects: Undefined, a single authorization object or an array.
//
// Types used in the parameters:
//
//  User - CatalogRef.Users;
//                         CatalogRef.ExternalUsers.
//
//  User group - CatalogRef.UserGroups,
//                         CatalogRef.ExternalUsersGroups.
//
//  Performer - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
//
//  Group of assignees - for example, CatalogRef.TaskPerformersGroups.
//
//  Authorization object - for example, CatalogRef.Individuals.
//
// Parameters:
//  Parameters     - Undefined - update all without filter.
//                  see options above.
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateUsersGroups(Parameters = Undefined, HasChanges = Undefined) Export
	
	UpdateKind = "";
	
	If Parameters = Undefined Then
		UpdateKind = "All";
	
	ElsIf Parameters.Count() = 2
	        And Parameters.Property("Users")
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("Users") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("PerformersGroups") Then
		
		UpdateKind = "PerformersGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("AuthorizationObjects") Then
		
		UpdateKind = "AuthorizationObjects";
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1
			           |of the %2 information register manager module.
			           |
			           |Some parameters are invalid.';"),
			"UpdateUsersGroups",
			"AccessValuesGroups");
		Raise ErrorText;
	EndIf;
	
	BeginTransaction();
	Try
		If InfobaseUpdate.InfobaseUpdateInProgress()
		 Or InfobaseUpdate.IsCallFromUpdateHandler() Then
			
			DeleteUnusedRecords(HasChanges);
		EndIf;
		
		If UpdateKind = "UsersAndUserGroups" Then
			
			If Parameters.Property("Users") Then
				UpdateUsers(        Parameters.Users, HasChanges);
				UpdatePerformersGroups( , Parameters.Users, HasChanges);
			EndIf;
			
			If Parameters.Property("UserGroups") Then
				UpdateUserGroups(Parameters.UserGroups, HasChanges);
			EndIf;
			
		ElsIf UpdateKind = "PerformersGroups" Then
			UpdatePerformersGroups(Parameters.PerformersGroups, , HasChanges);
			
		ElsIf UpdateKind = "AuthorizationObjects" Then
			UpdateAuthorizationObjects(Parameters.AuthorizationObjects, HasChanges);
		Else
			UpdateUsers(       ,   HasChanges);
			UpdateUserGroups( ,   HasChanges);
			UpdatePerformersGroups(  , , HasChanges);
			UpdateAuthorizationObjects(  ,   HasChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes unused data after changing content
// of value types and access value groups.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges1() Export
	
	SetPrivilegedMode(True);
	
	If Constants.LimitAccessAtRecordLevel.Get() Then
		AccessManagementInternal.SetDataFillingForAccessRestriction(True);
	EndIf;
	
	UpdateEmptyAccessValuesGroups();
	DeleteUnusedRecords();
	
EndProcedure

#EndRegion

#Region Private

// Updates register data after changing access values.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	DeleteUnusedRecords(HasChanges);
	
	UpdateUsersGroups( , HasChanges);
	
	UpdateAccessValuesGroups( , HasChanges);
	
EndProcedure

// Updates access value groups in the InformationRegister.AccessValuesGroups.
//
// Parameters:
//  AccessValues - CatalogObject
//                  - CatalogRef
//                  - Array - 
//                  - Undefined - 
//                    
//                    
//                    
//
//  HasChanges   - Boolean - (return value) - if recorded,
//                    True is set, otherwise, it does not change.
//
Procedure UpdateAccessValuesGroups(AccessValues = Undefined,
                                        HasChanges   = Undefined) Export
	
	ValuesWithChangesByTypes = New Map;
	
	If AccessValues = Undefined Then
		
		AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
		AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each TableName In AccessValuesWithGroups.NamesOfTablesToUpdate Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", TableName);
			// 
			Selection = Query.Execute().Select();
			
			ObjectManager = Common.ObjectManagerByFullName(TableName);
			UpdateAccessValueGroups(ObjectManager.EmptyRef(), HasChanges, ValuesWithChangesByTypes);
			
			While Selection.Next() Do
				UpdateAccessValueGroups(Selection.Ref, HasChanges, ValuesWithChangesByTypes);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(AccessValues) = Type("Array") Then
		
		For Each AccessValue In AccessValues Do
			UpdateAccessValueGroups(AccessValue, HasChanges, ValuesWithChangesByTypes);
		EndDo;
	Else
		UpdateAccessValueGroups(AccessValues, HasChanges, ValuesWithChangesByTypes);
	EndIf;
	
	AccessManagementInternal.ScheduleUpdateOfDependentListsByValuesWithGroups(
		ValuesWithChangesByTypes);
	
EndProcedure

// Fills groups for blank references to the access value types in use.
Procedure UpdateEmptyAccessValuesGroups()
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	
	ValuesWithChangesByTypes = New Map;
	
	For Each TableName In AccessValuesWithGroups.NamesOfTablesToUpdate Do
		EmptyRef = PredefinedValue(TableName + ".EmptyRef");
		UpdateAccessValueGroups(EmptyRef, Undefined, ValuesWithChangesByTypes);
	EndDo;
	
	AccessManagementInternal.ScheduleUpdateOfDependentListsByValuesWithGroups(
		ValuesWithChangesByTypes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// 
	Return;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	UpdateRegisterData();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Deletes unnecessary records if any are found.
Procedure DeleteUnusedRecords(HasChanges = Undefined)
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	ValuesGroupsTypes = AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypesForUpdate;
	
	GroupsAndValuesTypesTable = New ValueTable;
	GroupsAndValuesTypesTable.Columns.Add("ValuesType",      Metadata.DefinedTypes.AccessValue.Type);
	GroupsAndValuesTypesTable.Columns.Add("ValuesGroupsType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue In ValuesGroupsTypes Do
		If TypeOf(KeyAndValue.Key) = Type("Type") Then
			Continue;
		EndIf;
		String = GroupsAndValuesTypesTable.Add();
		String.ValuesType      = KeyAndValue.Key;
		String.ValuesGroupsType = KeyAndValue.Value;
	EndDo;
	
	// 
	// 
	// 
	// 
	// 
	// 
	
	
	Query = New Query;
	Query.SetParameter("GroupsAndValuesTypesTable", GroupsAndValuesTypesTable);
	Query.Text =
	"SELECT
	|	TypesTable.ValuesType AS ValuesType,
	|	TypesTable.ValuesGroupsType AS ValuesGroupsType
	|INTO GroupsAndValuesTypesTable
	|FROM
	|	&GroupsAndValuesTypesTable AS TypesTable
	|
	|INDEX BY
	|	TypesTable.ValuesType,
	|	TypesTable.ValuesGroupsType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValueGroups.AccessValue AS AccessValue,
	|	ValueGroups.AccessValuesGroup AS AccessValuesGroup,
	|	ValueGroups.DataGroup AS DataGroup
	|FROM
	|	(SELECT
	|		AccessValuesGroups.AccessValue AS AccessValue,
	|		AccessValuesGroups.AccessValuesGroup AS AccessValuesGroup,
	|		AccessValuesGroups.DataGroup AS DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.AccessValue = UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 0
	|		AND NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						GroupsAndValuesTypesTable AS GroupsAndValuesTypesTable
	|					WHERE
	|						VALUETYPE(GroupsAndValuesTypesTable.ValuesType) = VALUETYPE(AccessValuesGroups.AccessValue)
	|						AND VALUETYPE(GroupsAndValuesTypesTable.ValuesGroupsType) = VALUETYPE(AccessValuesGroups.AccessValuesGroup))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsers)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup > 4) AS ValueGroups";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			RecordSet = CreateRecordSet();
			RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
			RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
			RecordSet.Filter.DataGroup.Set(Selection.DataGroup);
			RecordSet.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
EndProcedure

// Updates access value groups in InformationRegister.AccessValuesGroups.
//
// Parameters:
//  AccessValue - CatalogRef
//                    CatalogObject.
//                    If Object is passed, the update is performed only when it is changed.
//
//  HasChanges   - Boolean - (return value) - if recorded,
//                    True is set, otherwise, it does not change.
//
Procedure UpdateAccessValueGroups(AccessValue, HasChanges, ValuesWithChangesByTypes)
	
	SetPrivilegedMode(True);
	
	AccessValueType = TypeOf(AccessValue);
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	
	AccessKindProperties = AccessValuesWithGroups.ByTypesForUpdate.Get(AccessValueType);
	
	ErrorTitle =
		NStr("en = 'An error occurred when updating Access Value Groups.';")
		+ Chars.LF
		+ Chars.LF;
	
	If AccessKindProperties = Undefined Then
		ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For type ""%1""
			           |usage of access value groups is not configured.';"),
			String(AccessValueType));
		Raise ErrorText;
	EndIf;
	
	If AccessValuesWithGroups.ByRefTypesForUpdate.Get(AccessValueType) = Undefined Then
		Ref = UsersInternal.ObjectRef2(AccessValue);
		Object = AccessValue;
	Else
		Ref = AccessValue;
		Object = Undefined;
	EndIf;
	
	// Preparing previous field values.
	AttributeName      = "AccessGroup";
	TabularSectionName = "AccessGroups";
	
	If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
		FieldForQuery = "Ref";
	ElsIf AccessKindProperties.MultipleValuesGroups Then
		FieldForQuery = TabularSectionName;
	Else
		FieldForQuery = AttributeName;
	EndIf;
	
	Try
		If ValueIsFilled(Ref) Then
			PreviousValues1 = Common.ObjectAttributesValues(Ref, FieldForQuery);
		Else
			PreviousValues1 = New Structure(FieldForQuery, Undefined);
		EndIf;
	Except
		Error = ErrorInfo();
		TypeMetadata = Metadata.FindByType(AccessValueType);
		
		If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot read attribute ""%3"" of access value ""%1""
				           |of type ""%2""
				           | due to:
				           |%4';"),
				String(AccessValue),
				String(AccessValueType),
				"Ref",
				ErrorProcessing.BriefErrorDescription(Error));
			Raise ErrorText;
			
		ElsIf AccessKindProperties.MultipleValuesGroups Then
			TabularSectionMetadata1 = TypeMetadata.TabularSections.Find("AccessGroups");
			
			If TabularSectionMetadata1 = Undefined
			 Or TabularSectionMetadata1.Attributes.Find("AccessGroup") = Undefined Then
				
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Special tabular section ""%2""
					           |with special attribute ""%3"" is not created
					           |for access value type ""%1"".';"),
					String(AccessValueType),
					"AccessGroups",
					"AccessGroup");
				Raise ErrorText;
			Else
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot read tabular section ""%3""
					           |with attribute ""%4"" of access value ""%1""
					           |of type ""%2""
					           | due to:
					           |%5';"),
					String(AccessValue),
					String(AccessValueType),
					"AccessGroups",
					"AccessGroup",
					ErrorProcessing.BriefErrorDescription(Error));
				Raise ErrorText;
			EndIf;
		Else
			If TypeMetadata.Attributes.Find("AccessGroup") = Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Special attribute ""%2""
					           |is not created for access value type ""%1"".';"),
					String(AccessValueType), "AccessGroup");
				Raise ErrorText;
			Else
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot read attribute ""%3"" of access value ""%1""
					           |of type ""%2""
					           | due to:
					           |%4';"),
					String(AccessValue),
					String(AccessValueType),
					"AccessGroup",
					ErrorProcessing.BriefErrorDescription(Error));
				Raise ErrorText;
			EndIf;
		EndIf;
	EndTry;
	
	// Check for object modifications.
	UpdateRequired = False;
	If Object <> Undefined Then
		
		If Object.IsNew() Then
			UpdateRequired = True;
			
		ElsIf AccessKindProperties.ValuesGroupsType <> Type("Undefined") Then
			
			If AccessKindProperties.MultipleValuesGroups Then
				Value = Object[TabularSectionName].Unload();
				Value.Sort(AttributeName);
				If PreviousValues1[TabularSectionName] <> Undefined Then
					PreviousValues1[TabularSectionName] = PreviousValues1[TabularSectionName].Unload();
					PreviousValues1[TabularSectionName].Sort(AttributeName);
				EndIf;
			Else
				Value = Object[AttributeName];
			EndIf;
			
			If Not Common.DataMatch(Value, PreviousValues1[FieldForQuery]) Then
				UpdateRequired = True;
			EndIf;
		EndIf;
		NewValues = Object;
	Else
		UpdateRequired = True;
		NewValues = PreviousValues1;
	EndIf;
	
	// Preparing new records for update.
	NewRecords = CreateRecordSet().Unload();
	
	If Constants.LimitAccessAtRecordLevel.Get() Then
		
		// Add value groups.
		If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
			Record = NewRecords.Add();
			Record.AccessValue       = Ref;
			Record.AccessValuesGroup = Ref;
		Else
			AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
			ValuesGroupsTypes = AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypesForUpdate;
			
			AccessValuesGroupsEmptyRef = ValuesGroupsTypes.Get(TypeOf(Ref));
			
			If AccessKindProperties.MultipleValuesGroups Then
				If NewValues[TabularSectionName] = Undefined Then
					AccessValuesGroups = New ValueTable;
					AccessValuesGroups.Columns.Add("AccessGroup");
				Else
					AccessValuesGroups = NewValues[TabularSectionName].Unload();
				EndIf;
				If AccessValuesGroups.Count() = 0 Then
					AccessValuesGroups.Add();
				Else
					AccessValuesGroups.GroupBy("AccessGroup");
				EndIf;
				For Each String In AccessValuesGroups Do
					Record = NewRecords.Add();
					Record.AccessValue       = Ref;
					Record.AccessValuesGroup = String[AttributeName];
					If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupsEmptyRef) Then
						Record.AccessValuesGroup = AccessValuesGroupsEmptyRef;
					EndIf;
				EndDo;
			Else
				Record = NewRecords.Add();
				Record.AccessValue       = Ref;
				Record.AccessValuesGroup = NewValues[AttributeName];
				If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupsEmptyRef) Then
					Record.AccessValuesGroup = AccessValuesGroupsEmptyRef;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	FixedFilter = New Structure;
	FixedFilter.Insert("AccessValue", Ref);
	FixedFilter.Insert("DataGroup", 0);
	
	Data = New Structure;
	Data.Insert("RegisterManager",       InformationRegisters.AccessValuesGroups);
	Data.Insert("NewRecords",            NewRecords);
	Data.Insert("FixedFilter",     FixedFilter);
	Data.Insert("AdditionalProperties", AdditionalProperties);
	
	HasCurrentChanges = False;
	BeginTransaction();
	Try
		AccessManagementInternal.UpdateRecordSets(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Not UpdateRequired And Not HasCurrentChanges Then
		Return;
	EndIf;
	
	If AccessKindProperties.ValuesGroupsType <> Type("Undefined")
	   And (Object = Undefined Or Not Object.IsNew()) Then
		
		CurrentRef = ValuesWithChangesByTypes.Get(AccessKindProperties.ValuesType);
		
		If CurrentRef = Undefined Then
			ValuesWithChangesByTypes.Insert(AccessKindProperties.ValuesType, Ref);
			
		ElsIf TypeOf(CurrentRef) = AccessKindProperties.ValuesType Then
			ValuesWithChangesByTypes.Insert(AccessKindProperties.ValuesType, True);
		EndIf;
	EndIf;
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User 1 - The same User.
//
//                               1 - User group
//                                   of the same user.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user 1 - The same External user.
//
//                               1 - External user group
//                                   of the same external user.
//
Procedure UpdateUsers(Users1 = Undefined,
                                HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	UserGroupCompositions.User AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	1 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.UsersGroup,
	|	1,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",       "&UserFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",          "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Users1, "Users",
		"&UserFilterCriterion1:UserGroupCompositions.User
		|&UserFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 1, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 1));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User group 2 - The same User group.
//
//                               2 - A user
//                                   of the same user group.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user group 2 - The same External user group.
//
//                               2 - An external user
//                                   from the same external user group.
//
//
Procedure UpdateUserGroups(UserGroups = Undefined,
                                      HasChanges       = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	2 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserGroupFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&UserGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, UserGroups, "UserGroups",
		"&UserGroupFilterCriterion1:UserGroupCompositions.UsersGroup
		|&UserGroupFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 2, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 2));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// Assignee group 3 - A user
//                                   of the same assignee group.
//
//                               3 - User group
//                                   of the same assignee group user.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Assignee group 3 - An external user
//                                   of the same assignee group.
//
//                               3 - An external user group
//                                   of an external user
//                                   of the same assignee group.
//
Procedure UpdatePerformersGroups(PerformersGroups = Undefined,
                                     Assignees        = Undefined,
                                     HasChanges      = Undefined)
	
	SetPrivilegedMode(True);
	
	// 
	// 
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If PerformersGroups = Undefined
	   And Assignees        = Undefined Then
	
		ParameterContent = Undefined;
		ParameterValue   = Undefined;
	
	ElsIf PerformersGroups <> Undefined Then
		ParameterContent = "PerformersGroups";
		ParameterValue   = PerformersGroups;
		
	ElsIf Assignees <> Undefined Then
		ParameterContent = "Assignees";
		ParameterValue   = Assignees;
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1
			           |of the %2 information register manager module.
			           |
			           |Some parameters are invalid.';"),
			"UpdatePerformersGroups",
			"AccessValuesGroups");
		Raise ErrorText;
	EndIf;
	
	NoPerformerGroups = True;
	SSLSubsystemsIntegration.OnDeterminePerformersGroups(Query.TempTablesManager,
		ParameterContent, ParameterValue, NoPerformerGroups);
	
	If NoPerformerGroups Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.DataGroup.Set(3);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		Return;
	EndIf;
	
	// 
	Query.SetParameter("EmptyValueGroupsReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValuesGroup").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueGroupsReferences.EmptyRef
	|INTO EmptyValueGroupsReferences
	|FROM
	|	&EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|
	|INDEX BY
	|	EmptyValueGroupsReferences.EmptyRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User
	|INTO AssigneeGroupsUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.Users)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.Users.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User AS ExternalUser
	|INTO ExternalPerformerGroupUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.ExternalUsers)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PerformerGroupsTable";
	
	If PerformersGroups = Undefined
	   And Assignees <> Undefined Then
		
		// 
		// 
		QueryText =
		"SELECT
		|	AssigneeGroupsUsers.PerformersGroup
		|FROM
		|	AssigneeGroupsUsers AS AssigneeGroupsUsers
		|
		|UNION
		|
		|SELECT
		|	ExternalPerformerGroupUsers.PerformersGroup
		|FROM
		|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers";
		// ACC:96-
		
		Query.Text = TemporaryTablesQueriesText + "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|" + QueryText;
		
		QueriesResults = Query.ExecuteBatch();
		Count = QueriesResults.Count();
		
		PerformersGroups = QueriesResults[Count-1].Unload().UnloadColumn("PerformersGroup");
		TemporaryTablesQueriesText = Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	AssigneeGroupsUsers.PerformersGroup AS AccessValue,
	|	AssigneeGroupsUsers.User AS AccessValuesGroup,
	|	3 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AssigneeGroupsUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON AssigneeGroupsUsers.User = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups))
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	ExternalPerformerGroupUsers.ExternalUser,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON ExternalPerformerGroupUsers.ExternalUser = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups))";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&AssigneeGroupFilterCriterion"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, PerformersGroups, "PerformersGroups",
		"&AssigneeGroupFilterCriterion:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 3, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 3));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// For the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Authorization object 4 - An external user
//                                   of the same authorization object.
//
//                               4 - An external user group
//                                   of an external user
//                                   of the same authorization object.
//
Procedure UpdateAuthorizationObjects(AuthorizationObjects = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyValueReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValue").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueReferences.EmptyRef
	|INTO EmptyValueReferences
	|FROM
	|	&EmptyValueReferences AS EmptyValueReferences
	|
	|INDEX BY
	|	EmptyValueReferences.EmptyRef";
	
	QueryText =
	"SELECT
	|	CAST(UserGroupCompositions.User AS Catalog.ExternalUsers).AuthorizationObject AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	4 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers))
	|			AND UserGroupCompositions.User = ExternalUsers.Ref
	|		INNER JOIN EmptyValueReferences AS EmptyValueReferences
	|		ON (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(EmptyValueReferences.EmptyRef))
	|			AND (ExternalUsers.AuthorizationObject <> EmptyValueReferences.EmptyRef)
	|WHERE
	|	&AuthorizationObjectFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&AuthorizationObjectFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AuthorizationObjects, "AuthorizationObjects",
		"&AuthorizationObjectFilterCriterion1:ExternalUsers.AuthorizationObject
		|&AuthorizationObjectFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 4, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 4));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

#EndRegion

#EndIf