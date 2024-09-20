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

// Updates available rights for object rights settings and saves the content of the latest changes.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if changes are found
//                  True is set, otherwise, it is not changed.
//
Procedure UpdateAvailableRightsForObjectsRightsSettings(HasChanges = Undefined) Export
	
	SessionProperties = AccessManagementInternalCached.DescriptionPropertiesAccessTypesSession().SessionProperties;
	PossibleSessionRights = CheckedPossibleSessionPermissions(SessionProperties);
	NewValue = HashSumPossiblePermissions(PossibleSessionRights);
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable",
			NewValue, HasCurrentChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Updates auxiliary register data after changing
// rights based on access values saved to access restriction parameters.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges1() Export
	
	Cache = AccessManagementInternalCached.DescriptionPossibleSessionRightsForSettingObjectRights();
	NewValue = Cache.HashSum;
	
	ParameterName = "StandardSubsystems.AccessManagement.UpdatedPossibleRightsForSettingRightsObjects";
	PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	If PreviousValue2 = NewValue Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	BeginTransaction();
	Try
		Block.Lock();
		IsAlreadyModified = False;
		PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True, IsAlreadyModified);
		If PreviousValue2 <> NewValue Then
			If IsAlreadyModified Then
				AccessManagementInternal.CheckWhetherTheMetadataIsUpToDate();
			EndIf;
			UpdateAuxiliaryRegisterData();
			StandardSubsystemsServer.SetExtensionParameter(ParameterName, NewValue, True);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

// Returns the object right settings.
//
// Parameters:
//  ObjectReference - DefinedType.RightsSettingsOwner - a reference to the object, for which reading of right settings is required.
//
// Returns:
//  Structure:
//    * Inherit        - Boolean - a flag of inheriting parent right settings.
//    * Settings          - ValueTable:
//                         ** SettingsOwner     - DefinedType.RightsSettingsOwner - a reference to an object
//                                                    or an object parent (from the object parent hierarchy).
//                         ** InheritanceIsAllowed - Boolean - inheritance allowed.
//                         ** User          - CatalogRef.Users
//                                                  - CatalogRef.UserGroups
//                                                  - CatalogRef.ExternalUsers
//                                                  - CatalogRef.ExternalUsersGroups
//
//                         The access right names specified in the overridable 
//                         OnFillAvailableRightsForObjectsRightsSettings procedure:
//                         # <RightName1> = Undefined
//                                                 = Boolean —
//                                                       Undefined — the right is not configured,
//                                                       True — the right is allowed,
//                                                       False — the right is prohibited.
//                         # <RightName2> = Undefined
//                                                 = Boolean — similar.
//
Function Read(Val ObjectReference) Export
	
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	
	RightsDetails = AvailableRights.ByTypes.Get(TypeOf(ObjectReference));
	
	If RightsDetails = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1.
			           |
			           |Parameter ""%2"" has invalid value ""%3"".
			           |Table ""%4"" doesn''t support access rights.';"),
			"InformationRegisters.ObjectsRightsSettings.Read",
			"ObjectReference",
			String(ObjectReference),
			ObjectReference.Metadata().FullName());
		Raise ErrorText;
	EndIf;
	
	RightsSettings = New Structure;
	
	// 
	RightsSettings.Insert("Inherit",
		InformationRegisters.ObjectRightsSettingsInheritance.SettingsInheritance(ObjectReference));
	
	// Preparing the right settings table structure.
	Settings = New ValueTable;
	Settings.Columns.Add("User");
	Settings.Columns.Add("SettingsOwner");
	Settings.Columns.Add("InheritanceIsAllowed", New TypeDescription("Boolean"));
	Settings.Columns.Add("ParentSetting",     New TypeDescription("Boolean"));
	For Each RightDetails In RightsDetails Do
		Settings.Columns.Add(RightDetails.Key);
	EndDo;
	
	If AvailableRights.HierarchicalTables.Get(TypeOf(ObjectReference)) = Undefined Then
		SettingsInheritance = AccessManagementInternalCached.BlankRecordSetTable(
			Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get(); // ValueTable
		NewRow = SettingsInheritance.Add();
		SettingsInheritance.Columns.Add("Level", New TypeDescription("Number"));
		NewRow.Object   = ObjectReference;
		NewRow.Parent = ObjectReference;
	Else
		SettingsInheritance = InformationRegisters.ObjectRightsSettingsInheritance.ObjectParents(
			ObjectReference, , , False);
	EndIf;
	
	// Reading object settings and settings of parent objects inherited by the object.
	Query = New Query;
	Query.SetParameter("Object", ObjectReference);
	Query.SetParameter("SettingsInheritance", SettingsInheritance);
	Query.Text =
	"SELECT
	|	SettingsInheritance.Object AS Object,
	|	SettingsInheritance.Parent AS Parent,
	|	SettingsInheritance.Level AS Level
	|INTO SettingsInheritance
	|FROM
	|	&SettingsInheritance AS SettingsInheritance
	|
	|INDEX BY
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsInheritance.Parent AS SettingsOwner,
	|	ObjectsRightsSettings.User AS User,
	|	ObjectsRightsSettings.Right AS Right,
	|	CASE
	|		WHEN SettingsInheritance.Parent <> &Object
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ParentSetting,
	|	ObjectsRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectsRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		INNER JOIN SettingsInheritance AS SettingsInheritance
	|		ON ObjectsRightsSettings.Object = SettingsInheritance.Parent
	|WHERE
	|	(SettingsInheritance.Parent = &Object
	|			OR ObjectsRightsSettings.InheritanceIsAllowed)
	|
	|ORDER BY
	|	ParentSetting DESC,
	|	SettingsInheritance.Level,
	|	ObjectsRightsSettings.SettingsOrder";
	Table = Query.Execute().Unload();
	
	CurrentSettingOwner = Undefined;
	CurrentUser = Undefined;
	For Each String In Table Do
		If CurrentSettingOwner <> String.SettingsOwner
		 Or CurrentUser <> String.User Then
			CurrentSettingOwner = String.SettingsOwner;
			CurrentUser      = String.User;
			Setting = Settings.Add();
			Setting.User      = String.User;
			Setting.SettingsOwner = String.SettingsOwner;
			Setting.ParentSetting = String.ParentSetting;
		EndIf;
		If Settings.Columns.Find(String.Right) = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in procedure %1.
				           |
				           |Table ""%2"" objects
				           |don''t support right ""%3"",
				           |but it exists
				           |in information register ""%4""
				           |for object ""%5"".
				           |
				           |The infobase is probably not updated or updated with errors.
				           |Fix the register data.';"),
				"InformationRegisters.ObjectsRightsSettings.Read",
				ObjectReference.Metadata().FullName(),
				String.Right,
				"ObjectsRightsSettings",
				String(ObjectReference));
			Raise ErrorText;
		EndIf;
		Setting.InheritanceIsAllowed = Setting.InheritanceIsAllowed Or String.InheritanceIsAllowed;
		Setting[String.Right] = Not String.RightIsProhibited;
	EndDo;
	
	RightsSettings.Insert("Settings", Settings);
	
	Return RightsSettings;
	
EndFunction

// Writes the object right settings.
//
// Parameters:
//  ObjectReference - DefinedType.RightsSettingsOwner
//  Settings          - ValueTable:
//                         * SettingsOwner     - DefinedType.RightsSettingsOwner - a reference to an object
//                                                   or an object parent (from the object parent hierarchy).
//                         * InheritanceIsAllowed - Boolean - inheritance allowed.
//                         * User          - CatalogRef.Users
//                                                   CatalogRef.UserGroups
//                                                   CatalogRef.ExternalUsers
//                                                   CatalogRef.ExternalUsersGroups.
//
//                         The access right names specified in the overridable 
//                         OnFillAvailableRightsForObjectsRightsSettings procedure:
//                         # <RightName1> = Undefined
//                                                 = Boolean —
//                                                       Undefined — the right is not configured,
//                                                       True — the right is allowed,
//                                                       False — the right is prohibited.
//                         # <RightName2> = Undefined
//                                                 = Boolean — similar.
//
//  Inherit - Boolean - a flag of inheriting parent right settings.
//
Procedure Write(Val ObjectReference, Val Settings, Val Inherit) Export
	
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	RightsDetails = AvailableRights.ByRefsTypes.Get(TypeOf(ObjectReference)); // Array of See AvailableRightProperties
	
	If RightsDetails = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1.
			           |
			           |Parameter ""%2"" has invalid value ""%3"".
			           |Table ""%4"" doesn''t support access rights.';"),
			"InformationRegisters.ObjectsRightsSettings.Read",
			"ObjectReference",
			String(ObjectReference),
			ObjectReference.Metadata().FullName());
		Raise ErrorText;
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ObjectRightsSettingsInheritance");
		LockItem.SetValue("Object", ObjectReference);
		LockItem.SetValue("Parent", ObjectReference);
		Block.Lock();
		
		// Setting the inheritance setting flag.
		RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
		RecordSet.Filter.Object.Set(ObjectReference);
		RecordSet.Filter.Parent.Set(ObjectReference);
		RecordSet.Read();
		
		If RecordSet.Count() = 0 Then
			ChangedInheritance = True;
			NewRecord = RecordSet.Add();
			NewRecord.Object      = ObjectReference;
			NewRecord.Parent    = ObjectReference;
			NewRecord.Inherit = Inherit;
		Else
			ChangedInheritance = RecordSet[0].Inherit <> Inherit;
			RecordSet[0].Inherit = Inherit;
		EndIf;
		
		// Prepare new settings.
		NewRightsSettings = AccessManagementInternalCached.BlankRecordSetTable(
			Metadata.InformationRegisters.ObjectsRightsSettings.FullName()).Get();
		
		CommonRightsTable = Catalogs.MetadataObjectIDs.EmptyRef();
		
		Filter = New Structure("SettingsOwner", ObjectReference);
		SettingsOrder = 0;
		For Each Setting In Settings.FindRows(Filter) Do
			For Each RightDetails In RightsDetails Do
				If TypeOf(Setting[RightDetails.Name]) <> Type("Boolean") Then
					Continue;
				EndIf;
				SettingsOrder = SettingsOrder + 1;
				
				RightsSetting = NewRightsSettings.Add();
				RightsSetting.SettingsOrder      = SettingsOrder;
				RightsSetting.Object                = ObjectReference;
				RightsSetting.User          = Setting.User;
				RightsSetting.Right                 = RightDetails.Name;
				RightsSetting.Table               = CommonRightsTable;
				RightsSetting.RightIsProhibited        = Not Setting[RightDetails.Name];
				RightsSetting.InheritanceIsAllowed = Setting.InheritanceIsAllowed;
				// Кэш-Attributes
				RightsSetting.RightPermissionLevel =
					?(RightsSetting.RightIsProhibited, 0, ?(RightsSetting.InheritanceIsAllowed, 2, 1));
				RightsSetting.RightProhibitionLevel =
					?(RightsSetting.RightIsProhibited, ?(RightsSetting.InheritanceIsAllowed, 2, 1), 0);
				
				AddedIndividualTablesSettings = False;
				For Each KeyAndValue In AvailableRights.SeparateTables Do
					SeparateTable = KeyAndValue.Key;
					ReadTable    = RightDetails.ReadInTables.Find(   SeparateTable) <> Undefined;
					TableChange = RightDetails.ChangeInTables.Find(SeparateTable) <> Undefined;
					If Not ReadTable And Not TableChange Then
						Continue;
					EndIf;
					AddedIndividualTablesSettings = True;
					TableRightsSettings = NewRightsSettings.Add();
					FillPropertyValues(TableRightsSettings, RightsSetting);
					TableRightsSettings.Table = SeparateTable;
					If ReadTable Then
						TableRightsSettings.ReadingPermissionLevel = RightsSetting.RightPermissionLevel;
						TableRightsSettings.ReadingProhibitionLevel = RightsSetting.RightProhibitionLevel;
					EndIf;
					If TableChange Then
						TableRightsSettings.ChangingPermissionLevel = RightsSetting.RightPermissionLevel;
						TableRightsSettings.ChangingProhibitionLevel = RightsSetting.RightProhibitionLevel;
					EndIf;
				EndDo;
				
				CommonRead    = RightDetails.ReadInTables.Find(   CommonRightsTable) <> Undefined;
				CommonUpdate = RightDetails.ChangeInTables.Find(CommonRightsTable) <> Undefined;
				
				If Not CommonRead And Not CommonUpdate And AddedIndividualTablesSettings Then
					NewRightsSettings.Delete(RightsSetting);
				Else
					If CommonRead Then
						RightsSetting.ReadingPermissionLevel = RightsSetting.RightPermissionLevel;
						RightsSetting.ReadingProhibitionLevel = RightsSetting.RightProhibitionLevel;
					EndIf;
					If CommonUpdate Then
						RightsSetting.ChangingPermissionLevel = RightsSetting.RightPermissionLevel;
						RightsSetting.ChangingProhibitionLevel = RightsSetting.RightProhibitionLevel;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	
		// Writing object right settings and an inheritance flag of right settings.
		Data = New Structure;
		Data.Insert("RecordSet",   InformationRegisters.ObjectsRightsSettings);
		Data.Insert("NewRecords",    NewRightsSettings);
		Data.Insert("FilterField",     "Object");
		Data.Insert("FilterValue", ObjectReference);
		
		HasChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasChanges);
		
		If HasChanges Then
			ObjectsWithChanges = New Array;
		Else
			ObjectsWithChanges = Undefined;
		EndIf;
		
		If ChangedInheritance Then
			RecordSet.Write();
			InformationRegisters.ObjectRightsSettingsInheritance.UpdateOwnerParents(
				ObjectReference, , True, ObjectsWithChanges);
		EndIf;
		
		If ObjectsWithChanges <> Undefined Then
			AddHierarchyObjects(ObjectReference, ObjectsWithChanges);
		EndIf;
		
		If (HasChanges Or ChangedInheritance)
		   And AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
			PlanningParameters.DataAccessKeys = False;
			PlanningParameters.LongDesc = "ObjectsRightsSettingsWrite";
			
			FullName = ObjectReference.Metadata().FullName();
			AccessManagementInternal.ScheduleAccessUpdate(FullName, PlanningParameters);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates auxiliary register data when changing the configuration.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateAuxiliaryRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	
	RightsTables = New ValueTable;
	RightsTables.Columns.Add("RightsOwner", Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.Object.Type);
	RightsTables.Columns.Add("Right",        Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.Right.Type);
	RightsTables.Columns.Add("Table",      Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.Table.Type);
	RightsTables.Columns.Add("Read",       New TypeDescription("Boolean"));
	RightsTables.Columns.Add("Update",    New TypeDescription("Boolean"));
	
	BlankRefsRightsOwner = AccessManagementInternalCached.BlankRefsMapToSpecifiedRefsTypes(
		"InformationRegister.ObjectsRightsSettings.Dimension.Object");
	
	Filter = New Structure;
	For Each KeyAndValue In AvailableRights.ByRefsTypes Do
		RightsOwnerType = KeyAndValue.Key;
		RightsDetails     = KeyAndValue.Value; // FixedArray of See AvailableRightProperties
		
		If BlankRefsRightsOwner.Get(RightsOwnerType) = Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in procedure %1
				           |of the %2 information register manager module.
				           |
				           |Dimension ""%4"" is missing right owner type ""%3"".';"),
				"UpdateAuxiliaryRegisterData",
				"ObjectsRightsSettings",
				RightsOwnerType,
				"Object");
			Raise ErrorText;
		EndIf;
		
		Filter.Insert("RightsOwner", BlankRefsRightsOwner.Get(RightsOwnerType));
		For Each RightDetails In RightsDetails Do
			Filter.Insert("Right", RightDetails.Name);
			
			For Each Table In RightDetails.ReadInTables Do
				String = RightsTables.Add();
				FillPropertyValues(String, Filter);
				String.Table = Table;
				String.Read = True;
			EndDo;
			
			For Each Table In RightDetails.ChangeInTables Do
				Filter.Insert("Table", Table);
				Rows = RightsTables.FindRows(Filter);
				If Rows.Count() = 0 Then
					String = RightsTables.Add();
					FillPropertyValues(String, Filter);
				Else
					String = Rows[0];
				EndIf;
				String.Update = True;
			EndDo;
		EndDo;
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	RightsTables.RightsOwner,
	|	RightsTables.Right,
	|	RightsTables.Table,
	|	RightsTables.Read,
	|	RightsTables.Update
	|INTO RightsTables
	|FROM
	|	&RightsTables AS RightsTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object AS Object,
	|	RightsSettings.User AS User,
	|	RightsSettings.Right AS Right,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO RightsSettings
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right,
	|	ISNULL(RightsTables.Table, VALUE(Catalog.MetadataObjectIDs.EmptyRef)) AS Table,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder,
	|	CASE
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightPermissionLevel,
	|	CASE
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightProhibitionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Read, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingPermissionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Read, FALSE)
	|			THEN 0
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingProhibitionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Update, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingPermissionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Update, FALSE)
	|			THEN 0
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingProhibitionLevel
	|INTO NewData
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN RightsTables AS RightsTables
	|		ON (VALUETYPE(RightsSettings.Object) = VALUETYPE(RightsTables.RightsOwner))
	|			AND RightsSettings.Right = RightsTables.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightsTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightsSettings";
	
	QueryText =
	"SELECT
	|	NewData.Object,
	|	NewData.User,
	|	NewData.Right,
	|	NewData.Table,
	|	NewData.RightIsProhibited,
	|	NewData.InheritanceIsAllowed,
	|	NewData.SettingsOrder,
	|	NewData.RightPermissionLevel,
	|	NewData.RightProhibitionLevel,
	|	NewData.ReadingPermissionLevel,
	|	NewData.ReadingProhibitionLevel,
	|	NewData.ChangingPermissionLevel,
	|	NewData.ChangingProhibitionLevel,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("Object"));
	Fields.Add(New Structure("User"));
	Fields.Add(New Structure("Right"));
	Fields.Add(New Structure("Table"));
	Fields.Add(New Structure("RightIsProhibited"));
	Fields.Add(New Structure("InheritanceIsAllowed"));
	Fields.Add(New Structure("SettingsOrder"));
	Fields.Add(New Structure("RightPermissionLevel"));
	Fields.Add(New Structure("RightProhibitionLevel"));
	Fields.Add(New Structure("ReadingPermissionLevel"));
	Fields.Add(New Structure("ReadingProhibitionLevel"));
	Fields.Add(New Structure("ChangingPermissionLevel"));
	Fields.Add(New Structure("ChangingProhibitionLevel"));
	
	Query = New Query;
	Query.SetParameter("RightsTables", RightsTables);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.ObjectsRightsSettings", TemporaryTablesQueriesText);
	
	Block = New DataLock;
	Block.Add("InformationRegister.ObjectsRightsSettings");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.ObjectsRightsSettings);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See also InformationRegisters.ObjectsRightsSettings.AvailableRights.
// 
//
// Returns:
//   See AccessManagementInternal.RightsForObjectsRightsSettingsAvailable
//
Function RightsForObjectsRightsSettingsAvailable() Export
	
	Cache = AccessManagementInternalCached.DescriptionPossibleSessionRightsForSettingObjectRights();
	
	CurrentSessionDate = CurrentSessionDate();
	If Cache.Validation.Date + 3 > CurrentSessionDate Then
		Return Cache.PossibleSessionRights;
	EndIf;
	
	NewValue = Cache.HashSum;
	
	ParameterName = "StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable";
	PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	If PreviousValue2 <> NewValue Then
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
		LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
		LockItem.SetValue("ParameterName", ParameterName);
		BeginTransaction();
		Try
			Block.Lock();
			IsAlreadyModified = False;
			PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True, IsAlreadyModified);
			If PreviousValue2 <> NewValue Then
				If IsAlreadyModified Then
					AccessManagementInternal.CheckWhetherTheMetadataIsUpToDate();
				EndIf;
				SetSafeModeDisabled(True);
				SetPrivilegedMode(True);
				StandardSubsystemsServer.SetExtensionParameter(ParameterName, NewValue, True);
				SetPrivilegedMode(False);
				SetSafeModeDisabled(False);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	Cache.Validation.Date = CurrentSessionDate;
	
	Return Cache.PossibleSessionRights;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// 
	Return;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	UpdateAuxiliaryRegisterData();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure AddHierarchyObjects(Ref, ObjectsArray)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = StrReplace(
	"SELECT
	|	TableWithHierarchy.Ref
	|FROM
	|	ObjectsTable AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND NOT TableWithHierarchy.Ref IN (&ObjectsArray)",
	"ObjectsTable",
	Ref.Metadata().FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ObjectsArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Returns:
//   See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings.AvailableRights
//
Function PopulatedPossibleSessionPermissions()
	
	AvailableRights = New ValueTable();
	AvailableRights.Columns.Add("RightsOwner",        New TypeDescription("String"));
	AvailableRights.Columns.Add("Name",                 New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("Title",           New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("ToolTip",           New TypeDescription("String", , New StringQualifiers(150)));
	AvailableRights.Columns.Add("InitialValue",   New TypeDescription("Boolean,Number"));
	AvailableRights.Columns.Add("RequiredRights1",      New TypeDescription("Array"));
	AvailableRights.Columns.Add("ReadInTables",     New TypeDescription("Array"));
	AvailableRights.Columns.Add("ChangeInTables",  New TypeDescription("Array"));
	
	SSLSubsystemsIntegration.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	
	Return AvailableRights;
	
EndFunction

// 
// 
//
// Parameters:
//  AccessKindsProperties - See AccessManagementInternal.AccessKindsProperties
//                       - Undefined.
//
// Returns:
//   See AccessManagementInternal.RightsForObjectsRightsSettingsAvailable
//
Function CheckedPossibleSessionPermissions(AccessKindsProperties = Undefined) Export
	
	AvailableRights = PopulatedPossibleSessionPermissions();
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1
		           |of common module %2.';"),
		"OnFillAvailableRightsForObjectsRightsSettings",
		"AccessManagementOverridable")
		+ Chars.LF
		+ Chars.LF;
	
	ByTypes              = New Map;
	ByRefsTypes        = New Map;
	ByFullNames       = New Map;
	OwnersTypes       = New Array;
	SeparateTables     = New Map;
	HierarchicalTables = New Map;
	
	TypeOfRightsOwnersToDefine  = AccessManagementInternalCached.TableFieldTypes("DefinedType.RightsSettingsOwner");
	TypeOfAccessValuesToDefine = AccessManagementInternalCached.TableFieldTypes("DefinedType.AccessValue");
	
	If AccessKindsProperties = Undefined Then
		AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	EndIf;
	
	SubscriptionTypesUpdateRightsSettingsOwnersGroups = AccessManagementInternalCached.TableFieldTypes(
		"DefinedType.RightsSettingsOwnerObject");
	
	SubscriptionTypesWriteAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets");
	
	SubscriptionTypesWriteDependentAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteDependentAccessValuesSets");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RightsOwner");
	AdditionalParameters.Insert("CommonOwnersRights", New Map);
	AdditionalParameters.Insert("IndividualOwnersRights", New Map);
	
	OwnersRightsIndexes = New Map;
	
	For Each AvailableRight In AvailableRights Do
		OwnerMetadataObject = Common.MetadataObjectByFullName(AvailableRight.RightsOwner);
		
		If OwnerMetadataObject = Undefined Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Owner of rights ""%1"" is not found.';"),
				AvailableRight.RightsOwner);
			Raise ErrorText;
		EndIf;
		
		AdditionalParameters.RightsOwner = AvailableRight.RightsOwner;
		
		FillIDs("ReadInTables",    AvailableRight, ErrorTitle, SeparateTables, AdditionalParameters);
		FillIDs("ChangeInTables", AvailableRight, ErrorTitle, SeparateTables, AdditionalParameters);
		
		OwnerRights = ByFullNames[AvailableRight.RightsOwner];
		If OwnerRights = Undefined Then
			OwnerRights = OwnerRights();
			OwnerRightsArray = New Array;
			
			RefType = StandardSubsystemsServer.MetadataObjectReferenceOrMetadataObjectRecordKeyType(
				OwnerMetadataObject);
			
			ObjectType = StandardSubsystemsServer.MetadataObjectOrMetadataObjectRecordSetType(
				OwnerMetadataObject);
			
			If TypeOfRightsOwnersToDefine.Get(RefType) = Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The rights owner type ""%1""
					           |is missing from type collection ""%2"".';"),
					String(RefType),
					"RightsSettingsOwner");
				Raise ErrorText;
			EndIf;
			
			If TypeOfAccessValuesToDefine.Get(RefType) = Undefined Then
				If SubscriptionTypesWriteAccessValuesSets = Undefined Then
					SubscriptionTypesWriteAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
						"WriteAccessValuesSets");
					SubscriptionTypesWriteDependentAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
						"WriteDependentAccessValuesSets");
				EndIf;
				If SubscriptionTypesWriteDependentAccessValuesSets.Get(ObjectType) <> Undefined
				 Or SubscriptionTypesWriteAccessValuesSets.Get(ObjectType) <> Undefined Then
				
					ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Rights owner type ""%1""
						           |is missing from type collection ""%2"".
						           |However, it affects access value sets,
						           |as it is present in the subscription to one of the following events:
						           |- %3
						           |- %4
						           |To avoid mistakes in the %6 register,
						           |add this type to type collection ""%5"".';"),
						String(RefType),
						"AccessValue",
						"WriteDependentAccessValuesSets" + "*",
						"WriteAccessValuesSets" + "*",
						"AccessValue",
						"AccessValuesSets");
					Raise ErrorText;
				EndIf;
			EndIf;
			
			AccessKindProperties = AccessKindsProperties.ByValuesTypes.Get(RefType); // See AccessManagementInternal.AccessKindProperties
			If AccessKindProperties <> Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '""%1"" rights owner type
					           |cannot be used as an access value type
					           |but it is detected in description of access kind ""%2"".';"),
					String(RefType),
					AccessKindProperties.Name);
				Raise ErrorText;
			EndIf;
			
			If AccessKindsProperties.ByGroupsAndValuesTypes.Get(RefType) <> Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '""%1"" rights owner type
					           |cannot be used as a type of access value groups but 
					           |it is detected in description of access kind ""%2"".';"),
					String(RefType),
					AccessKindProperties.Name);
				Raise ErrorText;
			EndIf;
			
			If SubscriptionTypesUpdateRightsSettingsOwnersGroups.Get(ObjectType) = Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The rights owner type ""%1""
					           |is missing from type collection ""%2"".';"),
					String(ObjectType), "RightsSettingsOwnerObject");
				Raise ErrorText;
			EndIf;
			
			ByFullNames.Insert(AvailableRight.RightsOwner, OwnerRights);
			ByRefsTypes.Insert(RefType,  OwnerRightsArray);
			ByTypes.Insert(RefType,  OwnerRights);
			ByTypes.Insert(ObjectType, OwnerRights);
			If HierarchicalMetadataObject(OwnerMetadataObject) Then
				HierarchicalTables.Insert(RefType,  True);
				HierarchicalTables.Insert(ObjectType, True);
			EndIf;
			
			OwnersTypes.Add(Common.ObjectManagerByFullName(
				AvailableRight.RightsOwner).EmptyRef());
				
			OwnersRightsIndexes.Insert(AvailableRight.RightsOwner, 0);
		EndIf;
		
		If OwnerRights.Get(AvailableRight.Name) <> Undefined Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""%2"" right 
				           |is defined again for the ""%1"" right owner.';"),
				AvailableRight.RightsOwner,
				AvailableRight.Name);
			Raise ErrorText;
		EndIf;
		
		For Each RequiredRight In AvailableRight.RequiredRights1 Do
			If AvailableRights.Find(RequiredRight, "Name") <> Undefined Then
				Continue;
			EndIf;
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'For the ""%1"" access right of the ""%2"" access right owner,
				           |an incorrect name of the required ""%3"" access right is specified.';"),
				AvailableRight.Name,
				AvailableRight.RightsOwner,
				RequiredRight);
			Raise ErrorText;
		EndDo;
		
		AvailableRightProperties = AvailableRightProperties(AvailableRight);
		AvailableRightProperties.RightIndex = OwnersRightsIndexes[AvailableRight.RightsOwner];
		OwnersRightsIndexes[AvailableRight.RightsOwner] = AvailableRightProperties.RightIndex + 1;
		
		OwnerRights.Insert(AvailableRight.Name, AvailableRightProperties);
		OwnerRightsArray.Add(AvailableRightProperties);
	EndDo;
	
	// Add tables.
	CommonTable = Catalogs.MetadataObjectIDs.EmptyRef();
	For Each RightsDetails In ByFullNames Do
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(RightsDetails.Key);
		For Each RightDetails In RightsDetails.Value Do
			RightProperties = RightDetails.Value;
			If RightProperties.ChangeInTables.Find(CommonTable) <> Undefined Then
				For Each KeyAndValue In SeparateTables Do
					SeparateTable = KeyAndValue.Key;
					
					If SeparateRights.ChangeInTables[SeparateTable] = Undefined
					   And RightProperties.ChangeInTables.Find(SeparateTable) = Undefined Then
					
						ChangeInTables = New Array(RightProperties.ChangeInTables);
						ChangeInTables.Add(SeparateTable);
						RightProperties.ChangeInTables = New FixedArray(ChangeInTables);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
	AvailableRights = New Structure;
	AvailableRights.Insert("ByTypes",              ByTypes);
	AvailableRights.Insert("ByRefsTypes",        ByRefsTypes);
	AvailableRights.Insert("ByFullNames",       ByFullNames);
	AvailableRights.Insert("OwnersTypes",       OwnersTypes);
	AvailableRights.Insert("SeparateTables",     SeparateTables);
	AvailableRights.Insert("HierarchicalTables", HierarchicalTables);
	
	Return Common.FixedData(AvailableRights);
	
EndFunction

// Parameters:
//  AvailableRights - See AccessManagementInternal.RightsForObjectsRightsSettingsAvailable
//  
// Returns:
//  String
//
Function HashSumPossiblePermissions(AvailableRights) Export
	
	Return AccessManagementInternal.HashAmountsData(AvailableRights);
	
EndFunction

// Returns:
//  Structure:
//   * RightsOwner - String
//   * Name          - String
//   * Title    - String
//   * ToolTip    - String
//   * InitialValue  - Boolean
//   * RequiredRights1     - FixedArray of String
//   * ReadInTables    - FixedArray of String
//   * ChangeInTables - FixedArray of String
//
Function AvailableRightProperties(AvailableRight) Export
	
	AvailableRightProperties = New Structure(
		"RightsOwner,
		|Name,
		|InitialValue,
		|RequiredRights1,
		|ReadInTables,
		|ChangeInTables,
		|RightIndex");
	
	FillPropertyValues(AvailableRightProperties, AvailableRight);
	
	AvailableRightProperties.RequiredRights1 =
		New FixedArray(AvailableRightProperties.RequiredRights1);
	
	AvailableRightProperties.ReadInTables =
		New FixedArray(AvailableRightProperties.ReadInTables);
	
	AvailableRightProperties.ChangeInTables =
		New FixedArray(AvailableRightProperties.ChangeInTables);
	
	Return AvailableRightProperties;
	
EndFunction

// Returns:
//  Map of KeyAndValue:
//   * Key - Type
//   * Value - See AvailableRightProperties
//
Function OwnerRights()
	
	Return New Map();
	
EndFunction

// Returns:
//   Map of KeyAndValue:
//     * Key - String - a full access right name.
//     * Value - FixedStructure:
//         * Name       - String - a possible access right name.
//         * Title - String - a column header.
//         * ToolTip - String - a column hint.
//
Function AvailableRightsPresentation() Export
	
	AvailableRights = PopulatedPossibleSessionPermissions();
	
	AvailableRightsPresentation = New Map;
	
	For Each AvailableRight In AvailableRights Do
		FullRightName = AvailableRight.RightsOwner + "_" + AvailableRight.Name;
		AvailableRightsPresentation.Insert(FullRightName,
			New FixedStructure(New Structure("Name, Title, ToolTip",
				AvailableRight.Name, AvailableRight.Title, AvailableRight.ToolTip)));
	EndDo;
	
	Return New FixedMap(AvailableRightsPresentation);
	
EndFunction

// Parameters:
//   AvailableRightDetails - See AvailableRightProperties
//
// Returns:
//  Structure:
//     * Name       - String
//     * Title - String
//     * ToolTip - String
//
Function AvailableRightPresentation(AvailableRightDetails) Export
	
	AvailableRightsPresentation = AccessManagementInternalCached.AvailableRightsPresentation();
	
	FullRightName = AvailableRightDetails.RightsOwner + "_" + AvailableRightDetails.Name;
	Presentation = AvailableRightsPresentation.Get(FullRightName);
	
	If Not ValueIsFilled(Presentation) Then
		Presentation = New FixedStructure(	New Structure("Name, Title, ToolTip",
			AvailableRightDetails.Name, AvailableRightDetails.Name, ""));
	EndIf;
	
	Return Presentation;
	
EndFunction

Procedure FillIDs(Property, AvailableRight, ErrorTitle, SeparateTables, AdditionalParameters)
	
	If AdditionalParameters.CommonOwnersRights.Get(AdditionalParameters.RightsOwner) = Undefined Then
		CommonRights     = New Structure("ReadInTables, ChangeInTables", "", "");
		SeparateRights = New Structure("ReadInTables, ChangeInTables", New Map, New Map);
		
		AdditionalParameters.CommonOwnersRights.Insert(AdditionalParameters.RightsOwner, CommonRights);
		AdditionalParameters.IndividualOwnersRights.Insert(AdditionalParameters.RightsOwner, SeparateRights);
	Else
		CommonRights     = AdditionalParameters.CommonOwnersRights.Get(AdditionalParameters.RightsOwner);
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(AdditionalParameters.RightsOwner);
	EndIf;
	
	Array = New Array;
	
	For Each Value In AvailableRight[Property] Do
		
		If Value = "*" Then
			If AvailableRight[Property].Count() <> 1 Then
				If Property = "ReadInTables" Then
					ErrorTemplate =
						NStr("en = 'An asterisk (*) is specified for the ""%1""
						           |right owner for the ""%2"" right in tables for reading.
						           |In this case, do not specify separate tables.';")
				Else
					ErrorTemplate =
						NStr("en = 'An asterisk (*) is specified
						           |for the ""%1"" right owner for the ""%2"" right in tables for change.
						           |In this case, do not specify separate tables.';")
				EndIf;
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					ErrorTemplate, AdditionalParameters.RightsOwner, AvailableRight.Name);
				Raise ErrorText;
			EndIf;
			
			If ValueIsFilled(CommonRights[Property]) Then
				If Property = "ReadInTables" Then
					ErrorTemplate =
						NStr("en = 'An asterisk (*) is specified 
						           |for the ""%1"" right owner for the ""%2"" right in tables for reading.
						           |The asterisk is already specified in tables for reading for the ""%3"" right.';")
				Else
					ErrorTemplate =
						NStr("en = 'An asterisk (*) is specified 
						           |for the ""%1"" right owner for the ""%2"" right in tables for change.
						           |The asterisk is already specified in tables for changes for the ""%3"" right.';")
				EndIf;
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
					AdditionalParameters.RightsOwner, AvailableRight.Name, CommonRights[Property]);
				Raise ErrorText;
			Else
				CommonRights[Property] = AvailableRight.Name;
			EndIf;
			
			TypeEmptyLinks = New TypeDescription("CatalogRef.MetadataObjectIDs");
			Array.Add(TypeEmptyLinks.AdjustValue(Undefined));
			
		ElsIf Property = "ReadInTables" Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Specific table ""%3""
				           |for reading is specified for the ""%1"" right owner for the ""%2"" right.
				           |It does not make sense, as the %4 right depends only on the %4 right.
				           |Only using an asterisk (*) makes sense.';"),
				AdditionalParameters.RightsOwner,
				AvailableRight.Name,
				Value,
				"Read");
			Raise ErrorText;
			
		ElsIf Common.MetadataObjectByFullName(Value) = Undefined Then
			If Property = "ReadInTables" Then
				ErrorTemplate = NStr("en = 'Table for reading ""%3""
				                          |is not found for the ""%1"" right owner for the ""%2"" right.';")
			Else
				ErrorTemplate = NStr("en = 'For the right owner ""%1""
				                          |and the ""%2"" right, the table ""%3"" specified in the ""update in tables"" parameter is not found.';")
			EndIf;
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				AdditionalParameters.RightsOwner, AvailableRight.Name, Value);
			Raise ErrorText;
		Else
			TableID = Common.MetadataObjectID(Value);
			Array.Add(TableID);
			
			SeparateTables.Insert(TableID, Value);
			SeparateRights[Property].Insert(TableID, AvailableRight.Name);
		EndIf;
		
	EndDo;
	
	AvailableRight[Property] = Array;
	
EndProcedure

Function HierarchicalMetadataObject(MetadataObjectDetails)
	
	If TypeOf(MetadataObjectDetails) = Type("String") Then
		MetadataObject = Common.MetadataObjectByFullName(MetadataObjectDetails);
	ElsIf TypeOf(MetadataObjectDetails) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectDetails);
	Else
		MetadataObject = MetadataObjectDetails;
	EndIf;
	
	If TypeOf(MetadataObject) <> Type("MetadataObject") Then
		Return False;
	EndIf;
	
	If Not Metadata.Catalogs.Contains(MetadataObject)
	   And Not Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		
		Return False;
	EndIf;
	
	Return MetadataObject.Hierarchical;
	
EndFunction

#EndRegion

#EndIf
