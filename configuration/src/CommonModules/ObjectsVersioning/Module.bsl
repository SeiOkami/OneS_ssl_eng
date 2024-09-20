///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Saves the object versioning setting.
//
// Parameters:
//  ObjectType - String
//             - Type
//             - MetadataObject
//             - CatalogRef.MetadataObjectIDs - 
//  VersioningMode - EnumRef.ObjectsVersioningOptions - version recording condition;
//  VersionLifetime - EnumRef.VersionsLifetimes - period after which versions must be deleted.
//
Procedure SaveObjectVersioningConfiguration(Val ObjectType, Val VersioningMode, Val VersionLifetime = Undefined) Export
	
	If TypeOf(ObjectType) <> Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = Common.MetadataObjectID(ObjectType);
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ObjectVersioningSettings");
		LockItem.SetValue("ObjectType", ObjectType);
		Block.Lock();
		
		Setting = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
		Setting.ObjectType = ObjectType;
		
		If VersionLifetime = Undefined Then
			Setting.Read();
			If Setting.Selected() Then
				VersionLifetime = Setting.VersionLifetime;
			Else
				Setting.ObjectType = ObjectType;
				VersionLifetime = Enums.VersionsLifetimes.Indefinitely;
			EndIf;
		EndIf;
		
		Setting.VersionLifetime = VersionLifetime;
		Setting.Variant = VersioningMode;
		Setting.Write();
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Configures a form before enabling the versioning subsystem.
//
// Parameters:
//  Form - ClientApplicationForm - a form used to enable the versioning mechanism.
//
Procedure OnCreateAtServer(Form) Export
	
	FullMetadataName = Undefined;
	If HasRightToReadObjectVersionData() And GetFunctionalOption("UseObjectsVersioning") Then
		FormNameArray = StrSplit(Form.FormName, ".", False);
		FullMetadataName = FormNameArray[0] + "." + FormNameArray[1];
	EndIf;
	
	Object = Undefined;
	If FullMetadataName <> Undefined Then
		Object = Common.MetadataObjectID(FullMetadataName);
	EndIf;
	
	Form.SetFormFunctionalOptionParameters(New Structure("VersionizedObjectType", Object));
	
EndProcedure

// Returns a flag that shows that versioning is used for the specified metadata object.
//
// Parameters:
//  ObjectName - String - full path to metadata object. For example, "Catalog.Products".
//
// Returns:
//  Boolean - 
//
Function ObjectVersioningEnabled(ObjectName) Export
	ListOfObjects = CommonClientServer.ValueInArray(ObjectName);
	Return ObjectVersioningIsEnabled(ListOfObjects)[ObjectName];
EndFunction

// Returns a flag indicating that versioning is used for the list of objects.
//
// Parameters:
//  ListOfObjects - Array - a list of metadata object names.
//
// Returns:
//  Map of KeyAndValue:
//   * Key - String - metadata object name.
//   * Value - Boolean - indicates whether versioning is enabled or disabled.
//
Function ObjectVersioningIsEnabled(ListOfObjects) Export
	
	MapTypes = Common.MetadataObjectIDs(ListOfObjects);
	ObjectsTypes = New Array;
	For Each Item In MapTypes Do
		ObjectsTypes.Add(Item.Value);
	EndDo;
	
	QueryText =
	"SELECT
	|	MetadataObjectIDs.FullName AS ObjectName,
	|	ISNULL(ObjectVersioningSettings.Use, FALSE) AS VersioningEnabled
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|		ON ObjectVersioningSettings.ObjectType = MetadataObjectIDs.Ref
	|WHERE
	|	MetadataObjectIDs.Ref IN(&ObjectsTypes)";
	
	Query = New Query(QueryText);
	Query.SetParameter("ObjectsTypes", ObjectsTypes);
	
	Result = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result.Insert(Selection.ObjectName, Selection.VersioningEnabled);
	EndDo;
	
	Return Result;
	
EndFunction

// Enables recording change history for a specified metadata object.
//
// Parameters:
//  ObjectName - String - full path to metadata object. For example, "Catalog.Products".
//  VersioningMode - EnumRef.ObjectsVersioningOptions - object versioning mode.
//
Procedure EnableObjectVersioning(ObjectName, Val VersioningMode = Undefined) Export
	
	If VersioningMode = Undefined Then
		VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnWrite;
	EndIf;
	
	If TypeOf(VersioningMode) = Type("String") Then
		If Metadata.Enums.ObjectsVersioningOptions.EnumValues.Find(VersioningMode) <> Undefined Then
			VersioningMode = Enums.ObjectsVersioningOptions[VersioningMode];
		EndIf;
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Unknown versioning option: %1.';"), VersioningMode);
	CommonClientServer.Validate(TypeOf(VersioningMode) = Type("EnumRef.ObjectsVersioningOptions"),
		ErrorText, "ObjectsVersioning.EnableObjectVersioning");
		
	SaveObjectVersioningConfiguration(ObjectName, VersioningMode);

EndProcedure

// Enables recording change history for specified metadata objects.
//
// Parameters:
//  Objects - Map of KeyAndValue - objects for which versioning must be enabled:
//   * Key    - String - full path to metadata object. For example, "Catalog.Products".
//   * Value - EnumRef.ObjectsVersioningOptions - object versioning mode.
//
Procedure EnableObjectsVersioning(Objects) Export
	
	BeginTransaction();
	Try
		Block = New DataLock();
		Block.Add("InformationRegister.ObjectVersioningSettings");
		Block.Lock();

		For Each ObjectName In Objects Do
			SaveObjectVersioningConfiguration(ObjectName.Key, Enums.ObjectsVersioningOptions.VersionizeOnWrite);
		EndDo;
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Check box state for an object versioning setup form.
//
// Returns: 
//   Boolean - 
//
// Example:
//	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
//		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
//		UseFullTextSearch = ModuleObjectVersioning.StoreHistoryCheckBoxValue();
//	Else 
//		Items.ObjectsVersioningControlGroup.Visibility = False;
//	EndIf;
//
Function StoreHistoryCheckBoxValue() Export
	
	Return GetFunctionalOption("UseObjectsVersioning");
	
EndFunction

#EndRegion

#Region Internal

// Writes an object version to the infobase.
//
// Parameters:
//  Source - CatalogObject, DocumentObject - infobase object to be written.
//  WriteMode - DocumentWriteMode
//
Procedure WriteObjectVersion(Val Source, WriteMode = Undefined) Export
	
	// 
	// 
	If Not GetFunctionalOption("UseObjectsVersioning") Then
		Return;
	EndIf;
	
	If Common.RefTypeValue(Source) Then
		Source = Source.GetObject();
	EndIf;
	
	If Source = Undefined Then
		Return;
	EndIf;
	
	If Source.DataExchange.Load
		And Source.AdditionalProperties.Property("SkipObjectVersionRecord")
		And PrivilegedMode() Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If Source.DataExchange.Load Then
		If Not Source.Ref.IsEmpty() Then
			WriteCurrentVersionData(Source.Ref, True);
		EndIf;
		Return;
	EndIf;
	
	If ObjectWritingInProgress() Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("ObjectVersionInfo") Then
		Return;
	EndIf;
	
	OnCreateObjectVersion(Source, WriteMode);
	
EndProcedure

// Writes a version of the object received during the data exchange to the infobase.
//
// Parameters:
//  Object - CatalogObject, DocumentObject - Object being written.
//  ObjectVersionInfo - Structure - contains object version information.
//  RefExists - Boolean - flag specifying whether the referenced object exists in the infobase.
//
Procedure CreateObjectVersionByDataExchange(Object, ObjectVersionInfo, RefExists, Sender) Export
	
	Ref = Object.Ref;
	
	If Not ValueIsFilled(RefExists) Then
		RefExists = Common.RefExists(Ref);
	EndIf;
	
	ObjectVersionType = Enums.ObjectVersionTypes[ObjectVersionInfo.ObjectVersionType];
	
	If RefExists Then
		If ObjectIsVersioned(Object) And VersionRegisterIsIncludedInExchangePlan(Sender) Then
			Return;
		EndIf;
	Else
		Ref = Common.ObjectManagerByRef(Ref).GetRef(Object.GetNewObjectRef().UUID());
	EndIf;
	LastVersionNumber = LastVersionNumber(Ref);
	
	ObjectVersionInfo.Insert("Object", Ref);
	ObjectVersionInfo.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionInfo.ObjectVersionType = ObjectVersionType;
	
	If Not ValueIsFilled(ObjectVersionInfo.VersionAuthor) Then
		ObjectVersionInfo.VersionAuthor = Users.AuthorizedUser();
	EndIf;
	
	CreateObjectVersion(Object, ObjectVersionInfo, False);
	
EndProcedure

// Sets the object version ignoring flag.
//
// Parameters:
//  Ref - AnyRef - reference to the ignored object.
//  VersionNumber - Number - version number of the ignored object.
//  Ignore - Boolean - version ignoring flag.
//
Procedure IgnoreObjectVersion(Ref, VersionNumber, Ignore) Export
	
	CheckObjectEditRights(Ref.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Ref);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Ref);
	LockItem.SetValue("VersionNumber", VersionNumber);
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet.Read();
		Record = RecordSet[0];
		Record.VersionIgnored = Ignore;
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure ChangeTheSyncWarning(RegisterEntryParameters, CheckForAnEntry) Export
	Var Ref, VersionNumber;
	
	RegisterEntryParameters.Property("Ref", Ref);
	RegisterEntryParameters.Property("VersionNumber", VersionNumber);
	
	If Ref = Undefined
		Or VersionNumber = Undefined Then
		
		Return;
		
	EndIf;
	
	CheckObjectEditRights(Ref.Metadata());
	SetPrivilegedMode(True);
	
	NamesOfUpdatedFields = "";
	For Each StructureItem In RegisterEntryParameters Do
		
		If StrFind("Ref,VersionNumber", StructureItem.Key) <> 0 Then
			
			Continue;
			
		EndIf;
		
		NamesOfUpdatedFields = NamesOfUpdatedFields + "," + StructureItem.Key;
		
	EndDo;
	
	NamesOfUpdatedFields = TrimAll(Mid(NamesOfUpdatedFields, 2));
	If IsBlankString(NamesOfUpdatedFields) Then
		
		Return;
		
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Ref);
	LockItem.SetValue("VersionNumber", VersionNumber);
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Ref;
		RecordManager.VersionNumber = VersionNumber;
		
		RecordManager.Read(); // 
		If Not RecordManager.Selected() Then
			
			// Use case: A user opened the warning dialog and fixed the issue.
			RollbackTransaction();
			Return;
			
		EndIf;
	
		FillPropertyValues(RecordManager, RegisterEntryParameters, NamesOfUpdatedFields);
		RecordManager.Write(True);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Returns the number of conflicts and rejected objects.
//
// Parameters:
//  ExchangeNodes - ExchangePlanRef
//             - Array
//             - ValueList
//             - Undefined - 
//  IsConflictsCount - Boolean - If True, returns the number of conflicts. If False, returns the number of rejected objects.
//  ShowIgnoredItems - Boolean - indicates whether ignored objects are included.
//  InfobaseNode - ExchangePlanRef - filter by a specific node.
//  Period - StandardPeriod - filter by period.
//  SearchString - String - filter by comment.
//
Function ConflictOrRejectedItemCount(ExchangeNodes, IsConflictsCount,
	ShowIgnoredItems, Period, SearchString) Export
	
	Count = 0;
	
	If Not HasRightToReadObjectVersionInfo() Then
		Return Count;
	EndIf;
	
	QueryText = 
		"SELECT ALLOWED
		|	COUNT(ObjectsVersions.Object) AS Count
		|FROM
		|	InformationRegister.ObjectsVersions AS ObjectsVersions
		|WHERE
		|	ObjectsVersions.VersionIgnored <> &FilterBySkipped
		|	AND ObjectsVersions.ObjectVersionType IN(&VersionTypes)
		|	AND &FilterByNode
		|	AND &FilterByPeriod
		|	AND &FilterByReason";
	
	Query = New Query;
	
	FilterBySkipped = ?(ShowIgnoredItems, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ExchangeNodes = Undefined Then
		FIlterRow = "TRUE";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FIlterRow = "ObjectsVersions.VersionAuthor = &ExchangeNodes";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	Else
		FIlterRow = "ObjectsVersions.VersionAuthor IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	QueryText = StrReplace(QueryText, "&FilterByNode", FIlterRow);
	
	If ValueIsFilled(Period) Then
		FIlterRow = "(ObjectsVersions.VersionDate >= &StartDate
		| AND ObjectsVersions.VersionDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
	Else
		FIlterRow = "TRUE";
	EndIf;
	QueryText = StrReplace(QueryText, "&FilterByPeriod", FIlterRow);
	
	VersionTypes = New ValueList;
	If ValueIsFilled(IsConflictsCount) Then
		
		If IsConflictsCount Then
			VersionTypes.Add(Enums.ObjectVersionTypes.ConflictDataAccepted);
			VersionTypes.Add(Enums.ObjectVersionTypes.RejectedConflictData);
			FIlterRow = "TRUE";
		Else
			VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
			VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
			
			If ValueIsFilled(SearchString) Then
				FIlterRow = 
					"CAST(ObjectsVersions.Comment AS STRING(1000)) LIKE &Comment ESCAPE ""~""
					|OR CAST(ObjectsVersions.SynchronizationWarning AS STRING(1000)) LIKE &Comment ESCAPE ""~""";
				Query.SetParameter("Comment", 
					"%" + Common.GenerateSearchQueryString(TrimAll(Left(SearchString, 998))) + "%");
			Else
				FIlterRow = "TRUE";
			EndIf;
		EndIf;
		
	Else // 
		VersionTypes.Add(Enums.ObjectVersionTypes.ConflictDataAccepted);
		VersionTypes.Add(Enums.ObjectVersionTypes.RejectedConflictData);
		VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
		VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
	EndIf;
	QueryText = StrReplace(QueryText, "&FilterByReason", FIlterRow);
	Query.SetParameter("VersionTypes", VersionTypes);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Count = Selection.Count;
	EndIf;
	
	Return Count;
	
EndFunction

Function UpdateInformationAboutProblemsWithDataSynchronizationVersions(SynchronizationNodes) Export
	
	If Not HasRightToReadObjectVersionInfo() Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SynchronizationNodes", SynchronizationNodes);
	
	Query.Text =
	"SELECT ALLOWED TOP 101
	|	1 AS NumberOfVersionWarnings
	|INTO TempTable
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	NOT ObjectsVersions.VersionIgnored
	|	AND ObjectsVersions.VersionAuthor IN (&SynchronizationNodes)
	|	AND ObjectsVersions.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted),
	|		VALUE(Enum.ObjectVersionTypes.RejectedConflictData),
	|		VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase),
	|		VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(SUM(1), 0) AS NumberOfVersionWarnings
	|FROM
	|	TempTable AS TempTable";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Return Selection.NumberOfVersionWarnings;
		
	EndIf;
	
	Return False;
	
EndFunction

Function HasRightToReadObjectVersionInfo() Export
	Return AccessRight("View", Metadata.InformationRegisters.ObjectsVersions);
EndFunction

Function HasRightToReadObjectVersionData() Export
	Return AccessRight("View", Metadata.CommonCommands.ChangeHistory);
EndFunction

// Fills parameters of a dynamic list that displays corrupted object versions
// generated while getting data as a result of data exchange in case of conflicts
// or if writing documents was canceled due to change closing date check failure.
//
// Parameters:
//  List - DynamicList - dynamic list to be initialized.
//  IssueKind - String - list of conflicts is initialized,
//                         RejectedDueToDate - declined due to date.
//
Procedure InitializeDynamicListOfCorruptedVersions(List, IssueKind = "Conflicts") Export
	
	If IssueKind = "RejectedDueToDate" Then
		QueryText =
		"SELECT ALLOWED
		|	UnacceptedVersion.VersionDate AS Date,
		|	UnacceptedVersion.Object AS Ref,
		|	UnacceptedVersion.Comment AS ProhibitionReason,
		|	CASE
		|		WHEN UnacceptedVersion.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS NewObject,
		|	ISNULL(UnacceptedVersion.VersionNumber, 0) AS OtherVersionNumber,
		|	UnacceptedVersion.VersionAuthor AS OtherVersionAuthor,
		|	ISNULL(CurrentVersion.VersionNumber, 0) AS ThisVersionNumber,
		|	VALUETYPE(UnacceptedVersion.Object) AS TypeAsString,
		|	UnacceptedVersion.VersionIgnored AS VersionIgnored
		|FROM
		|	InformationRegister.ObjectsVersions AS UnacceptedVersion
		|		LEFT JOIN InformationRegister.ObjectsVersions AS CurrentVersion
		|		ON UnacceptedVersion.Object = CurrentVersion.Object
		|			AND (UnacceptedVersion.VersionNumber = CurrentVersion.VersionNumber + 1)
		|WHERE
		|	UnacceptedVersion.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase),
		|		VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase))";
		
	ElsIf IssueKind = "Conflicts" Then
		QueryText =
		"SELECT ALLOWED
		|	VersionsOfAnotherProgram.VersionDate AS Date,
		|	VersionsOfAnotherProgram.Object AS Ref,
		|	VALUETYPE(VersionsOfAnotherProgram.Object) AS TypeAsString,
		|	VersionsOfThisProgram.VersionNumber AS ThisVersionNumber,
		|	VersionsOfAnotherProgram.VersionNumber AS OtherVersionNumber,
		|	VersionsOfAnotherProgram.VersionAuthor AS OtherVersionAuthor,
		|	CASE
		|		WHEN VersionsOfAnotherProgram.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS OtherVersionAccepted,
		|	VersionsOfAnotherProgram.VersionIgnored AS VersionIgnored
		|FROM
		|	InformationRegister.ObjectsVersions AS VersionsOfAnotherProgram
		|		LEFT JOIN InformationRegister.ObjectsVersions AS VersionsOfThisProgram
		|		ON VersionsOfAnotherProgram.Object = VersionsOfThisProgram.Object
		|			AND (VersionsOfAnotherProgram.VersionNumber = VersionsOfThisProgram.VersionNumber + 1)
		|WHERE
		|	VersionsOfAnotherProgram.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted),
		|		VALUE(Enum.ObjectVersionTypes.RejectedConflictData))";
	EndIf;
	
	List.QueryText = QueryText;
	List.CustomQuery = True;
	List.MainTable = "InformationRegister.ObjectsVersions";
	List.DynamicDataRead = True;
	
EndProcedure

Function TextOfTheVersionWarningListRequest() Export
	
	Return
	"SELECT
	|	UnacceptedVersion.VersionAuthor,
	|	UnacceptedVersion.Object,
	|	UNDEFINED,
	|	UnacceptedVersion.ObjectVersionType,
	|	CASE
	|		WHEN
	|			UnacceptedVersion.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase)
	|			THEN &UnrecognizedExisting
	|		WHEN
	|			UnacceptedVersion.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase)
	|			THEN &RejectedNew
	|	END,
	|	UnacceptedVersion.VersionDate,
	|	UnacceptedVersion.SynchronizationWarning,
	|	UNDEFINED,
	|	UnacceptedVersion.VersionIgnored,
	|	CASE
	|		WHEN (CAST(UnacceptedVersion.Comment AS STRING(1000))) = """"
	|			THEN FALSE
	|		ELSE TRUE
	|	END,
	|	UnacceptedVersion.Comment,
	|	ISNULL(UnacceptedVersion.VersionNumber, 0),
	|	ISNULL(CurrentVersion.VersionNumber, 0),
	|	UNDEFINED,
	|	CASE
	|		WHEN
	|			UnacceptedVersion.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase)
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|FROM
	|	InformationRegister.ObjectsVersions AS UnacceptedVersion
	|		LEFT JOIN InformationRegister.ObjectsVersions AS CurrentVersion
	|		ON UnacceptedVersion.Object = CurrentVersion.Object
	|		AND (UnacceptedVersion.VersionNumber = CurrentVersion.VersionNumber + 1)
	|WHERE
	|	UnacceptedVersion.ObjectVersionType IN
	|	(VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase),
	|		VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase))
	|
	|UNION ALL
	|
	|SELECT
	|	VersionsOfAnotherProgram.VersionAuthor,
	|	VersionsOfAnotherProgram.Object,
	|	UNDEFINED,
	|	VersionsOfAnotherProgram.ObjectVersionType,
	|	CASE
	|		WHEN VersionsOfAnotherProgram.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted)
	|			THEN &AcceptedCollisionData
	|		WHEN VersionsOfAnotherProgram.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedConflictData)
	|			THEN &RejectedCollisionData
	|	END,
	|	VersionsOfAnotherProgram.VersionDate,
	|	VersionsOfAnotherProgram.SynchronizationWarning,
	|	UNDEFINED,
	|	VersionsOfAnotherProgram.VersionIgnored,
	|	CASE
	|		WHEN (CAST(VersionsOfAnotherProgram.Comment AS STRING(1024))) = """"
	|			THEN FALSE
	|		ELSE TRUE
	|	END,
	|	VersionsOfAnotherProgram.Comment,
	|	ISNULL(VersionsOfAnotherProgram.VersionNumber, 0),
	|	ISNULL(VersionsOfThisProgram.VersionNumber, 0),
	|	CASE
	|		WHEN VersionsOfAnotherProgram.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ObjectsVersions AS VersionsOfAnotherProgram
	|		LEFT JOIN InformationRegister.ObjectsVersions AS VersionsOfThisProgram
	|		ON VersionsOfAnotherProgram.Object = VersionsOfThisProgram.Object
	|		AND (VersionsOfAnotherProgram.VersionNumber = VersionsOfThisProgram.VersionNumber + 1)
	|WHERE
	|	VersionsOfAnotherProgram.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted),
	|		VALUE(Enum.ObjectVersionTypes.RejectedConflictData))";
	
EndFunction

// Returns the command details that are required for adding the command to the "Data integrity check results" report.
// 
// Parameters:
//  Form - ClientApplicationForm
// 
Function ChangeHistoryCommand(Form) Export
	
	If Not GetFunctionalOption("UseObjectsVersioning") Then
		Return Undefined;
	EndIf;
	
	Command = Form.Commands.Add("AccountingAuditObjectChangeHistory");
	Command.Action  = "Attachable_Command";
	Command.Title = NStr("en = 'Object change history';");
	Command.ToolTip = NStr("en = 'Object change history';");
	Command.Picture  = PictureLib.DataHistory;
	
	Return Command;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.ObjectsVersions.FullName());
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	If TypeOf(DataElement) <> Type("InformationRegisterRecordSet.ObjectsVersions") Or DataElement.Count() = 0 Then
		Return;
	EndIf;
	
	ReadInfoAboutNode(DataElement[0]);
	Object = DataElement.Filter.Object.Value;
	
	SerialNumberOfVersionToSynchronize = DataElement.Filter.VersionNumber.Value - DataElement[0].Offset;
	OwnerVersionSerialNumber = DataElement[0].VersionOwner;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Object);

	BeginTransaction();
	Try
		Block.Lock();
		
		VersionNumber = VersionNumberInRegister(Object, SerialNumberOfVersionToSynchronize);
		If ValueIsFilled(OwnerVersionSerialNumber) Then
			DataElement[0].VersionOwner = VersionNumberInRegister(Object, OwnerVersionSerialNumber);
		EndIf;
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(DataElement.Filter.Object.Value);
		RecordSet.Filter.VersionNumber.Set(VersionNumber);
		RecordSet.Read();
		
		If Common.ValueToXMLString(DataElement) = Common.ValueToXMLString(RecordSet) Then
			// 
			ItemReceive = DataItemReceive.Ignore;
			
			CommitTransaction();
			Return;
		EndIf;
		
		HasConflict = ExchangePlans.IsChangeRecorded(Sender.Ref, Object);
		
		ObjectVersionType = Enums.ObjectVersionTypes.RejectedConflictData;
		If Sender.AdditionalProperties.Property("RejectedByClosingDate")
			And Sender.AdditionalProperties.RejectedByClosingDate[Object] <> Undefined Then
				HasConflict = True;
				If Sender.AdditionalProperties.RejectedByClosingDate[Object] = "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase" Then
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
				Else
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
				EndIf;
		EndIf;
		
		// Checking if this version is marked for export.
		VersionsToExport = VersionsToExport(Object, Sender.Ref);
		For Each VersionToExport In VersionsToExport Do
			If VersionToExport.VersionNumber = VersionNumber Then
				HasConflict = True;
			EndIf;
		EndDo;
		
		If Not HasConflict Then
			WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber);
			
			CommitTransaction();
			Return;
		EndIf;
		
		If ObjectVersionType = Enums.ObjectVersionTypes.RejectedConflictData Then
			VersionsToExport = VersionsToExport(Object, Sender.Ref);
			If VersionsToExport.Count() = 0 Then 
				WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber);
				
				CommitTransaction();
				Return;
			EndIf;
			
			MinimalVersionNumber = VersionsToExport[0].VersionNumber;
			For Counter = 1 To VersionsToExport.Count() - 1 Do
				If VersionsToExport[Counter - 1].VersionNumber - VersionsToExport[Counter].VersionNumber = 1 Then
					MinimalVersionNumber = Min(MinimalVersionNumber, VersionsToExport[Counter].VersionNumber);
				Else
					Break;
				EndIf;
			EndDo;
			
			If MinimalVersionNumber > VersionNumber Then
				WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber);
				
				CommitTransaction();
				Return;
			EndIf;
		EndIf;
			
		ObjectVersionConflicts = New Map;
		If Sender.AdditionalProperties.Property("ObjectVersionConflicts") Then
			ObjectVersionConflicts = Sender.AdditionalProperties.ObjectVersionConflicts;
		Else
			Sender.AdditionalProperties.Insert("ObjectVersionConflicts", ObjectVersionConflicts);
		EndIf;
		
		ConflictVersionNumber = ObjectVersionConflicts[Object];
		LastVersionNumber = LastVersionNumber(Object);
		UpdateConflictVersion = True;
		If ConflictVersionNumber = Undefined Then
			ConflictVersionNumber = LastVersionNumber + 1;
			
			RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
			RecordSet.Filter.Object.Set(Object);
			RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
			Record = RecordSet.Add();
			FillPropertyValues(Record, DataElement[0]);
			Record.VersionNumber = ConflictVersionNumber;
			Record.ObjectVersionType = ObjectVersionType;
			Record.VersionDate = CurrentSessionDate();
			Record.VersionAuthor = Sender.Ref;
			Record.Node = Common.SubjectString(Record.VersionAuthor);
			Record.SynchronizationWarning = NStr("en = 'The rejected version (automatic conflict resolving).';", Common.DefaultLanguageCode());
			RecordSet.Write();
			LastVersionNumber = ConflictVersionNumber;
			ObjectVersionConflicts.Insert(Object, ConflictVersionNumber);
			UpdateConflictVersion = False;
		EndIf;
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Filter.VersionNumber.Set(LastVersionNumber + 1);
		Record = RecordSet.Add();
		FillPropertyValues(Record, DataElement[0]);
		Record.VersionNumber = LastVersionNumber + 1;
		Record.VersionOwner = ConflictVersionNumber;
		Record.ObjectVersionType = ObjectVersionType;
		RecordSet.Write();
		
		If UpdateConflictVersion Then
			RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
			RecordSet.Filter.Object.Set(Object);
			RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
			RecordSet.Read();
			For Each Record In RecordSet Do
				Record.Checksum = DataElement[0].Checksum;
				Record.ObjectVersion = DataElement[0].ObjectVersion;
				Record.DataSize = DataElement[0].DataSize;
				Record.HasVersionData = DataElement[0].HasVersionData;
			EndDo;
			RecordSet.Write();
		EndIf;
		
		ItemReceive = DataItemReceive.Ignore;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export
	
	If Sender = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(DataElement) <> Type("InformationRegisterRecordSet.ObjectsVersions") Or DataElement.Count() = 0 Then
		Return;
	EndIf;
	
	ReadInfoAboutNode(DataElement[0]);
	Object = DataElement.Filter.Object.Value;
	
	// Mapping incoming numbers of the version and the version owner with numbers in this infobase.
	SerialNumberOfVersionToSynchronize = DataElement.Filter.VersionNumber.Value - DataElement[0].Offset;
	OwnerVersionSerialNumber = DataElement[0].VersionOwner;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Object);

	BeginTransaction();
	Try
		Block.Lock();
		
		VersionNumber = VersionNumberInRegister(Object, SerialNumberOfVersionToSynchronize);
		If ValueIsFilled(OwnerVersionSerialNumber) Then
			DataElement[0].VersionOwner = VersionNumberInRegister(Object, OwnerVersionSerialNumber);
		EndIf;
		
		// Comparing with the existing version.
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Filter.VersionNumber.Set(VersionNumber);
		RecordSet.Read();
		
		If Common.ValueToXMLString(DataElement) = Common.ValueToXMLString(RecordSet) Then
			// 
			ItemReceive = DataItemReceive.Ignore;
			
			CommitTransaction();
			Return;
		EndIf;
		
		HasConflict = Object.GetObject() <> Undefined And ExchangePlans.IsChangeRecorded(Sender.Ref, Object);
		
		ObjectVersionType = Enums.ObjectVersionTypes.RejectedConflictData;
		If Sender.AdditionalProperties.Property("RejectedByClosingDate")
			And Sender.AdditionalProperties.RejectedByClosingDate[Object] <> Undefined Then
				HasConflict = True;
				If Sender.AdditionalProperties.RejectedByClosingDate[Object] = "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase" Then
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
				Else
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
				EndIf;
		EndIf;
		
		// Checking if this version is marked for export.
		VersionsToExport = VersionsToExport(Object, Sender.Ref);
		For Each VersionToExport In VersionsToExport Do
			If VersionToExport.VersionNumber = VersionNumber Then
				HasConflict = True;
			EndIf;
		EndDo;
		
		// Writing the resulting version and changing its number taking into account versions that will not be synchronized.
		If Not HasConflict Then
			// 
			// 
			If RecordSet.Count() = 0 Then
				Record = RecordSet.Add();
				Record.Object = Object;
				Record.VersionNumber = VersionNumber;
			Else
				Record = RecordSet[0];
			EndIf;
			FillPropertyValues(Record, DataElement[0], , "Object,VersionNumber");
			RecordSet.Write();
			ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
			ItemReceive = DataItemReceive.Ignore;
			
			CommitTransaction();
			Return;
		EndIf;
		
		// Saving data of the last written version.
		LastVersionNumber = LastVersionNumber(Object);
		LatestVersion1 = InformationRegisters.ObjectsVersions.CreateRecordManager();
		LatestVersion1.Object = Object;
		LatestVersion1.VersionNumber = LastVersionNumber;
		LatestVersion1.Read();
		If Not LatestVersion1.HasVersionData Then
			LatestVersion1.ObjectVersion = New ValueStorage(DataToStore(Object), New Deflation(9));
			LatestVersion1.Write();
		EndIf;
		
		If VersionsToExport.Count() = 0 Then 
			WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber);
			
			CommitTransaction();
			Return;
		EndIf;
		
		// Shifting all versions registered for sending to insert a version from the main node.
		
		For Each VersionDetails In VersionsToExport Do
			If VersionDetails.VersionNumber >= VersionNumber Then
				RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
				RecordSet.Filter.Object.Set(Object);
				RecordSet.Filter.VersionNumber.Set(VersionDetails.VersionNumber);
				RecordSet.Read();
				ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
			EndIf;
		EndDo;
		
		ObjectVersionConflicts = New Map;
		If Sender.AdditionalProperties.Property("ObjectVersionConflicts") Then
			ObjectVersionConflicts = Sender.AdditionalProperties.ObjectVersionConflicts;
		Else
			Sender.AdditionalProperties.Insert("ObjectVersionConflicts", ObjectVersionConflicts);
		EndIf;
		
		// Recording the version that will be used as an owner of rejected versions.
		ConflictVersionNumber = ObjectVersionConflicts[Object];
		VersionNumberShift = 1;
		SetRejectedVersionsOwner = False;
		If ConflictVersionNumber = Undefined Then
			VersionNumberShift = 2;
			ConflictVersionNumber = VersionNumber + 1;
			SetRejectedVersionsOwner = True;
		EndIf;
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Read();
		
		ObjectVersions = RecordSet.Unload();
		For Each Version In ObjectVersions Do
			RecordSet.Filter.VersionNumber.Set(Version.VersionNumber);
			RecordSet.Read();
			Record = RecordSet[0];
			Write = False;
			If Record.VersionOwner >= VersionNumber Then
				Record.VersionOwner = Record.VersionOwner + VersionNumberShift;
				Write = True;
			EndIf;
			If Record.VersionNumber >= VersionNumber Then
				Record.VersionNumber = Record.VersionNumber + VersionNumberShift;
				Record.ObjectVersionType = ObjectVersionType;
				If SetRejectedVersionsOwner And Not ValueIsFilled(Record.VersionOwner) Then
					Record.VersionOwner = ConflictVersionNumber;
				EndIf;
				Write = True;
			EndIf;
			If Write Then
				Records = RecordSet.Unload();
				RecordSet.Clear();
				RecordSet.Write();
				RecordSet.Filter.VersionNumber.Set(Records[0].VersionNumber);
				RecordSet.Load(Records);
				RecordSet.Write();
			EndIf;
		EndDo;
		
		// Creating a version that will be an owner of rejected versions.
		If ObjectVersionConflicts[Object] = Undefined Then
			ConflictVersionNumber = VersionNumber + 1;
			VersionAuthor = Common.ObjectManagerByRef(Sender.Ref).ThisNode();
			LastRejectedVersionNumber = VersionsToExport[0].VersionNumber + VersionNumberShift;
			CreateRejectedItemsOwnerVersion(LastRejectedVersionNumber, ConflictVersionNumber, Object, VersionAuthor);
			ObjectVersionConflicts.Insert(Object, ConflictVersionNumber);
		EndIf;
		
		WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave.
Procedure OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient) Export
	
	OnSendDataToRecipient1(DataElement, ItemSend, Recipient);
	
EndProcedure

// See StandardSubsystems.OnSendDataToMaster.
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export
	
	OnSendDataToRecipient1(DataElement, ItemSend, Recipient);
	
EndProcedure

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("ObjectWritingInProgress",
		"ObjectsVersioning.SessionParametersSetting");
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.ClearingObsoleteObjectVersions;
	Setting.FunctionalOption = Metadata.FunctionalOptions.UseObjectsVersioning;
EndProcedure

// Handler of transition to the object version
//
// Parameters:
//  ObjectRef - AnyRef - a reference to the object that has a version.
//  NewVersionNumber - Number - a version number to migrate.
//  IgnoredVersionNumber - Number - a version number to ignore.
//  SkipPeriodClosingCheck - Boolean - the flag specifying whether period-end closing date check is skipped.
//
Procedure OnStartUsingNewObjectVersion(ObjectReference, Val VersionNumber) Export
	
	MetadataObject = ObjectReference.Metadata();
	CheckObjectEditRights(MetadataObject);
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", ObjectReference);
	
	LockItem = Block.Add(MetadataObject.FullName());
	LockItem.SetValue("Ref", ObjectReference);
	
	BeginTransaction();
	Try
		Block.Lock();
		LockDataForEdit(ObjectReference);
		
		RecordSet = ObjectVersionRecord(ObjectReference, VersionNumber);
		Record = RecordSet[0];
		
		If Record.ObjectVersionType = Enums.ObjectVersionTypes.ConflictDataAccepted Then
			VersionNumber = VersionNumber - 1;
			If VersionNumber <> 0 Then
				PreviousRecord = ObjectVersionRecord(ObjectReference, VersionNumber)[0];
				VersionNumber = PreviousRecord.VersionNumber;
			EndIf;
		Else
			VersionNumber = Record.VersionNumber;
		EndIf;
		
		ErrorMessageText = "";
		RestoreVersionServer(ObjectReference, VersionNumber, ErrorMessageText);
		
		If Not IsBlankString(ErrorMessageText) Then
			Raise ErrorMessageText;
		EndIf;
		
		Record.VersionIgnored = True;
		RecordSet.Write();
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not GetFunctionalOption("UseObjectsVersioning")
		Or Not AccessRight("Edit", Metadata.InformationRegisters.ObjectVersioningSettings)
		Or ModuleToDoListServer.UserTaskDisabled("ObsoleteObjectVersions") Then
		Return;
	EndIf;
	
	// 
	// 
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.InformationRegisters.ObjectVersioningSettings.FullName());
	
	ObsoleteVersionsInformation = ObsoleteVersionsInformation();
	ObsoleteDataSize = ObsoleteVersionsInformation.DataSizeString;
	ToolTip = NStr("en = 'Obsolete versions: %1 (%2)';");
	
	For Each Section In Sections Do
		ObsoleteObjectsID = "ObsoleteObjectVersions" + StrReplace(Section.FullName(), ".", "");
		// Add a to-do item.
		ToDoItem = ToDoList.Add();
		ToDoItem.Id = ObsoleteObjectsID;
		// 
		ToDoItem.HasToDoItems      = ObsoleteVersionsInformation.DataSize > (1024 * 1024 * 1024);
		ToDoItem.Presentation = NStr("en = 'Obsolete object versions';");
		ToDoItem.Form         = "InformationRegister.ObjectVersioningSettings.Form.HistoryStorageSettings";
		ToDoItem.ToolTip     = StringFunctionsClientServer.SubstituteParametersToString(ToolTip, ObsoleteVersionsInformation.VersionsCount, ObsoleteDataSize);
		ToDoItem.Owner      = Section;
	EndDo;
	
EndProcedure

// See JobsQueueOverridable.OnDefineHandlerAliases.
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	NamesAndAliasesMap.Insert("ObjectsVersioning.ClearObsoleteObjectVersions");
	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters.
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText =
	"SELECT
	|	VALUETYPE(ObjectsVersions.Object) AS ObjectType,
	|	COUNT(1) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|
	|GROUP BY
	|	VALUETYPE(ObjectsVersions.Object)";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		MetadataObject = Metadata.FindByType(Selection.ObjectType);
		If MetadataObject <> Undefined Then
			ModuleMonitoringCenter.WriteConfigurationObjectStatistics("ObjectVersionCount." + MetadataObject.FullName(), Selection.Count);
		EndIf;
	EndDo;
	
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType.FullName AS ObjectName
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|WHERE
	|	ObjectVersioningSettings.Use = TRUE";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics("ObjectVersioningEnabled" + Selection.ObjectName, True);
	EndDo;
	
EndProcedure

// See ExportImportDataOverridable.OnRegisterDataExportHandlers
Procedure OnRegisterDataExportHandlers(HandlersTable) Export
	
	Handler = HandlersTable.Add();
	Handler.MetadataObject = Metadata.InformationRegisters.ObjectsVersions;
	Handler.Handler = InformationRegisters.ObjectsVersions;
	Handler.BeforeExportObject = True;
	Handler.Version = "1.0.0.1";
	
EndProcedure

// See MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects
Procedure BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete) Export
	
	Context.Insert("Versioning_ObjectsToDelete", ObjectsToDelete);
	
EndProcedure

// See MarkedObjectsDeletionOverridable.AfterDeletingAGroupOfObjects
Procedure AfterDeletingAGroupOfObjects(Context, Success) Export
	
	If Not Success Then
		Return;
	EndIf;
	
	For Each Ref In Context.Versioning_ObjectsToDelete Do
		If Metadata.InformationRegisters.ObjectsVersions.Attributes.VersionAuthor.Type.ContainsType(TypeOf(Ref)) Then
			InformationRegisters.ObjectsVersions.DeleteVersionAuthorInfo(Ref);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  ParameterName - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "ObjectWritingInProgress" Then
		ObjectWritingInProgress(False);
		SpecifiedParameters.Add("ObjectWritingInProgress");
	EndIf;
	
EndProcedure

// Creates an object version and writes it to the infobase.
//
Procedure CreateObjectVersion(Object, ObjectVersionInfo, NormalVersionRecord = True)
	
	CheckObjectEditRights(Object.Metadata());
	
	SetPrivilegedMode(True);
	
	If NormalVersionRecord Then
		PostingChanged = False;
		If ObjectVersionInfo.Property("PostingChanged") Then
			PostingChanged = ObjectVersionInfo.PostingChanged;
		EndIf;
		
		// Creates an object version and writes it to the infobase.
		If Not Object.IsNew() And (PostingChanged And ObjectVersionInfo.VersionNumber > 1 Or CurrentAndPreviousVersionMismatch(Object)) Then
			// If versioning is enabled after the object creation, the previous version is written to the infobase.
			If ObjectVersionInfo.VersionNumber = 1 Then
				If ObjectIsVersioned(Object.Ref) Then
					VersionParameters = New Structure;
					VersionParameters.Insert("VersionNumber", 1);
					VersionParameters.Insert("Comment", NStr("en = 'Version was created from existing object.';"));
					CreateObjectVersion(Object.Ref.GetObject(), VersionParameters);
					ObjectVersionInfo.VersionNumber = 2;
				EndIf;
			EndIf;
			
			// Saving the previous object version.
			RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
			RecordManager.Object = Object.Ref;
			RecordManager.VersionNumber = PreviousVersionNumber(Object.Ref, ObjectVersionInfo.VersionNumber);
			RecordManager.Read();
			If RecordManager.Selected() And Not RecordManager.HasVersionData Then
				RecordManager.ObjectVersion = New ValueStorage(DataToStore(Object.Ref), New Deflation(9));
				RecordManager.Write();
			EndIf;
		EndIf;
		
		ObjectReference = Object.Ref;
		If ObjectReference.IsEmpty() Then
			ObjectReference = Object.GetNewObjectRef();
			If ObjectReference.IsEmpty() Then
				ObjectReference = Common.ObjectManagerByRef(Object.Ref).GetRef();
				Object.SetNewObjectRef(ObjectReference);
			EndIf;
		EndIf;
		
		// 
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = ObjectReference;
		RecordManager.VersionNumber = ObjectVersionInfo.VersionNumber;
		RecordManager.VersionDate = CurrentSessionDate();
		
		VersionAuthor = Undefined;
		If Not Object.AdditionalProperties.Property("VersionAuthor", VersionAuthor) Then
			VersionAuthor = Users.AuthorizedUser();
		EndIf;
		RecordManager.VersionAuthor = VersionAuthor;
		
		RecordManager.ObjectVersionType = Enums.ObjectVersionTypes.ChangedByUser;
		RecordManager.Synchronized = True;
		ObjectVersionInfo.Property("Comment", RecordManager.Comment);
		ObjectVersionInfo.Property("SynchronizationWarning", RecordManager.SynchronizationWarning);
		
		If Not Object.IsNew() Then
			// 
			// 
			If PostingChanged Then
				Object.Posted = Not Object.Posted;
			EndIf;
			
			RecordManager.Checksum = Checksum(DataToStore(Object));
			
			// Restore posting status to prevent failure of other functionality depending on this attribute.
			If PostingChanged Then
				Object.Posted = Not Object.Posted;
			EndIf;
		EndIf;
	Else
		// 
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Object.Ref;
		RecordManager.VersionNumber = PreviousVersionNumber(Object.Ref, ObjectVersionInfo.VersionNumber);
		RecordManager.Read();
		If RecordManager.Selected() And Not RecordManager.HasVersionData Then
			RecordManager.ObjectVersion = New ValueStorage(DataToStore(Object.Ref), New Deflation(9));
			RecordManager.Write();
		EndIf;
		
		DataStorage = New ValueStorage(DataToStore(Object), New Deflation(9));
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.VersionDate = CurrentSessionDate();
		RecordManager.ObjectVersion = DataStorage;
		FillPropertyValues(RecordManager, ObjectVersionInfo);
	EndIf;
	
	RecordManager.Write();
	
EndProcedure

// Writes an object version to the infobase.
//
// Parameters:
//  Object - 
//
Procedure OnCreateObjectVersion(Object, WriteMode)
	
	Var Comment;
	
	If Not ObjectIsVersioned(Object, WriteMode = DocumentWriteMode.Posting
		Or WriteMode = DocumentWriteMode.UndoPosting) Then
			Return;
	EndIf;
	LastVersionNumber = LastVersionNumber(Object.Ref);
	
	If Not Object.AdditionalProperties.Property("ObjectsVersioningVersionComment", Comment) Then
		Comment = "";
	EndIf;
	
	ObjectVersionInfo = New Structure;
	ObjectVersionInfo.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionInfo.Insert("Comment", Comment);
	
	PostingChanged = (WriteMode = DocumentWriteMode.Posting And Not Object.Posted
		Or WriteMode = DocumentWriteMode.UndoPosting And Object.Posted);
	ObjectVersionInfo.Insert("PostingChanged", PostingChanged);
	
	CreateObjectVersion(Object, ObjectVersionInfo);
	
EndProcedure

Procedure WriteCurrentVersionData(Ref, DataExchangeImport = False)
	
	SetPrivilegedMode(True);
	
	If Not ObjectIsVersioned(Ref) Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Ref);
	
	BeginTransaction();
	Try
		Block.Lock();
	
		LastVersionNumber = LastVersionNumber(Ref);
		
		ObjectVersion = New ValueStorage(DataToStore(Ref), New Deflation(9));
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Ref);
		RecordSet.Filter.VersionNumber.Set(LastVersionNumber);
		RecordSet.Read();
		
		For Each Record In RecordSet Do
			If Record.ObjectVersion.Get() = Undefined Then
				Record.ObjectVersion = ObjectVersion;
			EndIf;
		EndDo;
		
		If DataExchangeImport Then
			RecordSet.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", False);
		EndIf;
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


Function ObjectVersionRecord(ObjectReference, VersionNumber)
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectReference);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

Procedure CheckObjectEditRights(MetadataObject)
	
	If Not PrivilegedMode() And Not AccessRight("Update", MetadataObject)Then
		MessageText = NStr("en = 'Insufficient rights to modify %1.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, MetadataObject.Presentation());
		Raise MessageText;
	EndIf;
	
EndProcedure

// Returns a spreadsheet document filled with the object data.
// 
// Parameters:
//  ObjectReference - AnyRef
//
// Returns:
//  SpreadsheetDocument - 
//
Function ReportOnObjectVersion(ObjectReference, Val ObjectVersion = Undefined, CustomVersionNumber = Undefined) Export
	
	VersionNumber = Undefined;
	SerializedObject = Undefined;
	If TypeOf(ObjectVersion) = Type("Number") Then
		VersionNumber = ObjectVersion;
	ElsIf TypeOf(ObjectVersion) = Type("String") Then
		SerializedObject = ObjectVersion;
	EndIf;
	
	If VersionNumber = Undefined Then
		If SerializedObject = Undefined Then
			SerializedObject = SerializeObject(ObjectReference.GetObject());
		EndIf;
		ObjectDetails = XMLObjectPresentationParsing(SerializedObject, ObjectReference);
		ObjectDetails.Insert("ObjectName",     String(ObjectReference));
		ObjectDetails.Insert("ChangeAuthor", "");
		ObjectDetails.Insert("ChangeDate",  CurrentSessionDate());
		ObjectDetails.Insert("Comment", "");
		VersionNumber = 0;
		
		ObjectsVersioningOverridable.AfterParsingObjectVersion(ObjectReference, ObjectDetails);
	Else
		ObjectDetails = ParseVersion(ObjectReference, VersionNumber);
	EndIf;
	
	If CustomVersionNumber = Undefined Then
		CustomVersionNumber = VersionNumberInHierarchy(ObjectReference, VersionNumber);
	EndIf;
	
	LongDesc = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '#%1 / (%2) / %3';"), CustomVersionNumber,
		String(ObjectDetails.ChangeDate), TrimAll(String(ObjectDetails.ChangeAuthor)));
		
	ObjectDetails.Insert("LongDesc", LongDesc);
	ObjectDetails.Insert("VersionNumber", VersionNumber);
	Return GenerateObjectVersionReport(ObjectDetails, ObjectReference);
	
EndFunction

// Returns number of the last saved object version.
//
// Parameters:
//  Ref - AnyRef - reference to an infobase object.
//
// Returns:
//  Number - the version number of the object.
//
Function LastVersionNumber(Ref, ChangedByUser = False) Export
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	ISNULL(MAX(ObjectsVersions.VersionNumber), 0) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND &AdditionalCondition";
	
	If ChangedByUser Then
		AdditionalCondition = "ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)";
	Else
		AdditionalCondition = "TRUE";
	EndIf;
	QueryText = StrReplace(QueryText, "&AdditionalCondition", AdditionalCondition);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ChangedByUser", ChangedByUser);
	
	If TransactionActive() Then
		DataLock = New DataLock();
		LockItem = DataLock.Add("InformationRegister.ObjectsVersions");
		LockItem.SetValue("Object", Ref);
		DataLock.Lock();
	EndIf;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Previous version number changed by user.
Function PreviousVersionNumber(Ref, VersionCurrentNumber)
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(ObjectsVersions.VersionNumber), -1) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)
	|	AND ObjectsVersions.VersionNumber < &VersionCurrentNumber";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionCurrentNumber", VersionCurrentNumber);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Returns a versioning mode enabled for the specified metadata object.
//
// Parameters:
//  ObjectType - CatalogRef.MetadataObjectIDs - Object.
//
// Returns:
//  EnumRef.ObjectsVersioningOptions
//
Function ObjectVersioningOption(ObjectType)
	
	Return GetFunctionalOption("ObjectsVersioningOptions",
		New Structure("VersionizedObjectType", ObjectType));
		
EndFunction	

// Gets an object by its serialized XML presentation.
//
// Parameters:
//  AddressInTempStorage - String - binary data address in temporary storage.
//  ErrorMessageText    - String - error text (return value) when the object cannot be restored.
//
// Returns:
//  Arbitrary - 
//
Function RestoreObjectByXML(ObjectData, ErrorMessageText = "")
	
	SetPrivilegedMode(True);
	
	BinaryData = ObjectData;
	If TypeOf(ObjectData) = Type("Structure") Then
		BinaryData = ObjectData.Object;
	EndIf;
	
	FastInfosetReader = New FastInfosetReader;
	FastInfosetReader.SetBinaryData(BinaryData);
	
	Try
		Object = ReadXML(FastInfosetReader);
	Except
		WriteLogEvent(NStr("en = 'Versioning';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		ErrorMessageText = NStr("en = 'Cannot switch to the selected version.
											|Possible causes: the object version was saved in another application version.
											|Error technical information: %1';");
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageText, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	Return Object;
	
EndFunction

// Returns a structure containing object version and additional information.
//
// Parameters:
//  Ref      - AnyRef - versioned object;
//  VersionNumber - Number  - object version number.
//
// Returns:
//   Structure:
//                          
//                          
//                                        - CatalogRef.ExternalUsers -
//                                          
//                          
// 
// 
//  
//  
//
Function ObjectVersionInfo(Val Ref, Val VersionNumber) Export
	MessageCannotGetVersion = NStr("en = 'Cannot get previous version of the object.';");
	If Not HasRightToReadObjectVersionData() Then
		Raise MessageCannotGetVersion;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ObjectsVersions.VersionAuthor AS VersionAuthor,
	|	ObjectsVersions.VersionDate AS VersionDate,
	|	ObjectsVersions.Comment AS Comment,
	|	ObjectsVersions.SynchronizationWarning AS SynchronizationWarning,
	|	ObjectsVersions.ObjectVersion AS ObjectVersion,
	|	ObjectsVersions.Checksum AS Checksum
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND ObjectsVersions.VersionNumber = &VersionNumber";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionNumber", Number(VersionNumber));
	
	Result = New Structure("ObjectVersion, VersionAuthor, VersionDate, Comment, SynchronizationWarning");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		FillPropertyValues(Result, Selection);
		
		Result.ObjectVersion = Result.ObjectVersion.Get();
		If Result.ObjectVersion = Undefined Then
			Result.ObjectVersion = ObjectVersionData(Ref, VersionNumber, Selection.Checksum);
		EndIf;
		
	EndIf;
	
	If Result.ObjectVersion = Undefined Then
		Raise NStr("en = 'Selected object version is not available in the application.';");
	EndIf;
	
	Return Result;
		
EndFunction

// Checks versioning settings for the passed object
// and returns the versioning mode.
// If versioning is not enabled for the object,
// the default versioning rules apply.
//
Function ObjectIsVersioned(Val Source, WriteModePosting = False)
	
	// Making sure that versioning subsystem is active.
	If Not GetFunctionalOption("UseObjectsVersioning") Then
		Return False;
	EndIf;
	
	VersioningMode = ObjectVersioningOption(Common.MetadataObjectID(Source.Metadata()));
	If VersioningMode = False Then
		VersioningMode = Enums.ObjectsVersioningOptions.DontVersionize;
	EndIf;
	
	Return VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnWrite
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnPost And (WriteModePosting Or Source.Posted)
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnStart And Source.Started;
	
EndFunction

// MD5 checksum.
Function Checksum(Data) Export
	DataHashing = New DataHashing(HashFunction.MD5);
	
	If TypeOf(Data) = Type("Structure") Then
		DataHashing.Append(Data.Object);
		If Data.Property("AdditionalAttributes") Then
			DataHashing.Append(Common.ValueToXMLString(Data.AdditionalAttributes));
		EndIf;
	Else
		DataHashing.Append(Data);
	EndIf;
	
	Return StrReplace(DataHashing.HashSum, " ", "");
EndFunction

Function ObjectVersionData(ObjectReference, VersionNumber, Checksum)
	
	If Not IsBlankString(Checksum) Then
		QueryText = 
		"SELECT TOP 1
		|	ObjectsVersions.ObjectVersion,
		|	ObjectsVersions.VersionNumber
		|FROM
		|	InformationRegister.ObjectsVersions AS ObjectsVersions
		|WHERE
		|	ObjectsVersions.Object = &Object
		|	AND ObjectsVersions.VersionNumber >= &VersionNumber
		|	AND ObjectsVersions.Checksum = &Checksum
		|
		|ORDER BY
		|	ObjectsVersions.VersionNumber DESC";
		
		Query = New Query(QueryText);
		Query.SetParameter("Object", ObjectReference);
		Query.SetParameter("VersionNumber", VersionNumber);
		Query.SetParameter("Checksum", Checksum);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Result = Selection.ObjectVersion.Get();
			If Result = Undefined And Selection.VersionNumber = LastVersionNumber(ObjectReference, True) Then
				Result = DataToStore(ObjectReference);
			EndIf;
			Return Result;
		EndIf;
	Else
		QueryText = 
		"SELECT TOP 1
		|	ObjectsVersions.Checksum
		|FROM
		|	InformationRegister.ObjectsVersions AS ObjectsVersions
		|WHERE
		|	ObjectsVersions.Object = &Object
		|	AND ObjectsVersions.VersionNumber >= &VersionNumber
		|	AND ObjectsVersions.Checksum <> """"
		|
		|ORDER BY
		|	ObjectsVersions.VersionNumber";
		
		Query = New Query(QueryText);
		Query.SetParameter("Object", ObjectReference);
		Query.SetParameter("VersionNumber", VersionNumber);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Return ObjectVersionData(ObjectReference, VersionNumber, Selection.Checksum);
		EndIf;
		
		Return DataToStore(ObjectReference);
	EndIf;
	
EndFunction

Function CurrentAndPreviousVersionMismatch(Object)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectsVersions.Checksum
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Object
	|
	|ORDER BY
	|	ObjectsVersions.VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object.Ref);
	Selection = Query.Execute().Select();
	If Selection.Next() And Not IsBlankString(Selection.Checksum) Then
		Return Selection.Checksum <> Checksum(DataToStore(Object));
	EndIf;
	
	Return Object.IsNew() Or Checksum(DataToStore(Object)) <> Checksum(DataToStore(Object.Ref.GetObject()));
	
EndFunction

// For internal use only.
Procedure ClearObsoleteObjectVersions() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	ObjectsVersions.Object,
	|	ObjectsVersions.VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.HasVersionData
	|	AND &AdditionalConditions";
	
	Query = QueryOnObsoleteVersions(QueryText);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Selection.Object;
		RecordManager.VersionNumber = Selection.VersionNumber;
		RecordManager.Read();
		RecordManager.ObjectVersion = Undefined;
		RecordManager.Write();
	EndDo;
	
EndProcedure

Function ObjectDeletionBoundaries()
	
	Result = New ValueTable;
	Result.Columns.Add("TypesList", New TypeDescription("Array"));
	Result.Columns.Add("DeletionBoundary", New TypeDescription("Date"));
	
	QueryText =
	"SELECT
	|	MetadataObjectIDs.FullName AS ObjectType,
	|	ObjectVersioningSettings.VersionLifetime AS VersionLifetime
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON ObjectVersioningSettings.ObjectType = MetadataObjectIDs.Ref
	|WHERE
	|	NOT MetadataObjectIDs.DeletionMark
	|	AND MetadataObjectIDs.EmptyRefValue <> UNDEFINED
	|
	|ORDER BY
	|	VersionLifetime
	|TOTALS BY
	|	VersionLifetime";
	
	Query = New Query(QueryText);
	LifetimeSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While LifetimeSelection.Next() Do
		ObjectSelection = LifetimeSelection.Select();
		TypesList = New Array;
		While ObjectSelection.Next() Do
			TypesList.Add(ObjectSelection.ObjectType);
		EndDo;
		BoundaryAndObjectTypesMap = Result.Add();
		BoundaryAndObjectTypesMap.DeletionBoundary = DeletionBoundary(LifetimeSelection.VersionLifetime);
		BoundaryAndObjectTypesMap.TypesList = TypesList;
	EndDo;
	
	Return Result;
	
EndFunction

Function DeletionBoundary(VersionLifetime)
	If VersionLifetime = Enums.VersionsLifetimes.LastYear Then
		Return AddMonth(CurrentSessionDate(), -12);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastSixMonths Then
		Return AddMonth(CurrentSessionDate(), -6);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastThreeMonths Then
		Return AddMonth(CurrentSessionDate(), -3);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastMonth Then
		Return AddMonth(CurrentSessionDate(), -1);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastWeek Then
		Return CurrentSessionDate() - 7*24*60*60;
	Else // 
		Return '000101010000';
	EndIf;
EndFunction

// Parameters:
//   DataElement
//   ItemSend - DataItemSend
//   Recipient - ExchangePlanObject
//
Procedure OnSendDataToRecipient1(DataElement, ItemSend, Recipient)
	
	If TypeOf(DataElement) = Type("InformationRegisterRecordSet.ObjectsVersions") And DataElement.Count() > 0 Then
		Record = DataElement[0];
		
		If Not Record.Synchronized Or Record.Object = Undefined Then
			ItemSend = DataItemSend.Ignore;
			Return;
		EndIf;
		
		Object = Record.Object.GetObject();
		If Object = Undefined Then
			ItemSend = DataItemSend.Ignore;
			Return;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			ExchangePlanName = Recipient.Metadata().Name;
			
			ModuleDataExchangeInternal = Common.CommonModule("DataExchangeInternal");
			MetadataObjectDetails = ModuleDataExchangeInternal.ExchangePlanContent(ExchangePlanName).Find(TypeOf(Record.Object), "Type");
			
			If MetadataObjectDetails = Undefined Then
				ItemSend = DataItemSend.Ignore;
				Return;
			EndIf;
			
			Cancel = False;
			
			ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
			ModuleDataExchangeEvents.ObjectsRegistrationMechanismBeforeWrite(ExchangePlanName, Object, Cancel);
			
			If Cancel Or Not Object.DataExchange.Recipients.Contains(Recipient.Ref) Then
				ItemSend = DataItemSend.Ignore;
				Return;
			EndIf;
		EndIf;
		
		AddInfoAboutNode(Record, Recipient);
		
		If LastVersionNumber(Record.Object, True) = Record.VersionNumber Then
			Record.ObjectVersion = New ValueStorage(DataToStore(Record.Object), New Deflation(9));
			Record.DataSize = DataSize(Record.ObjectVersion);
			Record.HasVersionData = True;
		EndIf;
		
		Record.Offset = NumberOfUnsynchronizedVersions(Record.Object, Record.VersionNumber);
		If ValueIsFilled(Record.VersionOwner) Then
			Record.VersionOwner = Record.VersionOwner - NumberOfUnsynchronizedVersions(Record.Object, Record.VersionOwner);
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
// The comment is only saved when the user is either version author or administrator.
//
Procedure AddCommentToVersion(ObjectReference, VersionNumber, Comment) Export
	
	If Not HasRightToReadObjectVersionData() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
	RecordManager.Object = ObjectReference;
	RecordManager.VersionNumber = VersionNumber;
	RecordManager.Read();
	If RecordManager.Selected() Then
		If RecordManager.VersionAuthor = Users.CurrentUser() Or Users.IsFullUser(, , False) Then
			RecordManager.Comment = Comment;
			RecordManager.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Provides information on the number and size of obsolete object versions.
Function ObsoleteVersionsInformation() Export
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	ISNULL(SUM(ObjectsVersions.DataSize), 0) AS DataSize,
	|	COUNT(ObjectsVersions.DataSize) AS VersionsCount
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.HasVersionData
	|	AND &AdditionalConditions";
	
	Query = QueryOnObsoleteVersions(QueryText);
	Selection = Query.Execute().Select();
	
	VersionsCount = 0;
	DataSize = 0;
	If Selection.Next() Then
		DataSize = Selection.DataSize;
		VersionsCount = Selection.VersionsCount;
	EndIf;
	
	Result = New Structure;
	Result.Insert("VersionsCount", VersionsCount);
	Result.Insert("DataSize", DataSize);
	Result.Insert("DataSizeString", DataSizeString(Result.DataSize));
	
	Return Result;
	
EndFunction

// See ObsoleteVersionsInformation.
Function QueryOnObsoleteVersions(QueryText)
	
	Query = New Query;
	ObjectDeletionBoundaries = ObjectDeletionBoundaries();
	AdditionalConditions = "";
	
	For IndexOf = 0 To ObjectDeletionBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexAsString = Format(IndexOf, "NZ=0; NG=0");
		Condition = "";
		For Each Type In ObjectDeletionBoundaries[IndexOf].TypesList Do
			If Not IsBlankString(Condition) Then
				Condition = Condition + "
				|	OR";
			EndIf;
			Condition = Condition + "
			|		ObjectsVersions.Object REFS  " + Type;
		EndDo;
		If IsBlankString(Condition) Then
			Continue;
		EndIf;
		Condition = "(" + Condition + ")";
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersToString(
		"
		|	%1
		|	AND ObjectsVersions.VersionDate < &DeletionBoundary%2",
		Condition,
		IndexAsString);
		Query.SetParameter("TypesList" + IndexAsString, ObjectDeletionBoundaries[IndexOf].TypesList);
		Query.SetParameter("DeletionBoundary" + IndexAsString, ObjectDeletionBoundaries[IndexOf].DeletionBoundary);
	EndDo;
	
	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	Query.Text = QueryText;
	
	Return Query;
	
EndFunction

// String presentation of data volumes. For example: "1.23 GB".
Function DataSizeString(Val DataSize)
	
	UnitOfMeasure = NStr("en = 'bytes';");
	If 1024 <= DataSize And DataSize < 1024 * 1024 Then
		DataSize = DataSize / 1024;
		UnitOfMeasure = NStr("en = 'KB';");
	ElsIf 1024 * 1024 <= DataSize And  DataSize < 1024 * 1024 * 1024 Then
		DataSize = DataSize / 1024 / 1024;
		UnitOfMeasure = NStr("en = 'MB';");
	ElsIf 1024 * 1024 * 1024 <= DataSize Then
		DataSize = DataSize / 1024 / 1024 / 1024;
		UnitOfMeasure = NStr("en = 'GB';");
	EndIf;
	
	If DataSize < 10 Then
		DataSize = Round(DataSize, 2);
	ElsIf DataSize < 100 Then
		DataSize = Round(DataSize, 1);
	Else
		DataSize = Round(DataSize, 0);
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 %2';"), DataSize, UnitOfMeasure);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions related to object report generation.

// Returns a serialized object in the binary data format.
//
// Parameters:
//  Object - Arbitrary - serialized object.
//
// Returns:
//  BinaryData - 
//
Function SerializeObject(Object) Export
	
	XMLWriter = New FastInfosetWriter;
	XMLWriter.SetBinaryData();
	XMLWriter.WriteXMLDeclaration();
	
	WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();

EndFunction

// Reads XML data from file and fills data structures.
// 
// Parameters:
//  VersionData - BinaryData
//               - Structure
//  Ref - AnyRef
//
// Returns:
//  Structure:
//   * Attributes - ValueTable:
//    ** AttributeDescription - String
//    ** AttributeValue - Arbitrary
//    ** AttributeType - String
//    ** Type - Type
//   * TabularSections - Map of KeyAndValue:
//    ** Key - String
//    ** Value - ValueTable
//   * SpreadsheetDocuments - See ObjectsVersioningOverridable.OnReceiveObjectSpreadsheetDocuments.SpreadsheetDocuments
//   * AdditionalAttributes - See ObjectsVersioningOverridable.OnPrepareObjectData.AdditionalAttributes
//   * HiddenAttributes - Array
//
Function XMLObjectPresentationParsing(VersionData, Ref) Export
	
	Result = New Structure;
	Result.Insert("SpreadsheetDocuments");
	Result.Insert("AdditionalAttributes");
	Result.Insert("HiddenAttributes", New Array);
	
	BinaryData = VersionData;
	If TypeOf(VersionData) = Type("Structure") Then
		BinaryData = VersionData.Object;
		VersionData.Property("SpreadsheetDocuments", Result.SpreadsheetDocuments);
		VersionData.Property("AdditionalAttributes", Result.AdditionalAttributes);
		VersionData.Property("HiddenAttributes", Result.HiddenAttributes);
	EndIf;
	
	AttributesValues = New ValueTable;
	AttributesValues.Columns.Add("AttributeDescription");
	AttributesValues.Columns.Add("AttributeValue");
	AttributesValues.Columns.Add("AttributeType");
	AttributesValues.Columns.Add("Type");
	
	TabularSections = New Map;
	
	XMLReader = New FastInfosetReader;
	XMLReader.SetBinaryData(BinaryData);
	
	// 
	// 
	// 
	// 
	// 
	// 
	ReadingLevel = 0;
	
	ObjectMetadata = Ref.Metadata();
	TSFieldValueType = "";
	
	// Main XML parsing cycle.
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ReadingLevel = ReadingLevel + 1;
			If ReadingLevel = 1 Then // Указатель на первом элементе XML - 
				// 
			ElsIf ReadingLevel = 2 Then // Указатель на втором уровне - 
				AttributeName = XMLReader.Name;
				
				// Saving the attribute against a possible case that it may be a tabular section.
				TabularSectionName = AttributeName;
				If TabularSectionMetadata(ObjectMetadata, TabularSectionName) <> Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				NewValue = AttributesValues.Add();
				NewValue.AttributeDescription = AttributeName;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
							And XMLReader.Name = "xsi:type" Then
								NewValue.AttributeType = XMLReader.Value;
								XMLType = XMLReader.Value;
								If StrStartsWith(XMLType, "xs:") Then
									NewValue.Type = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
								Else
									NewValue.Type = FromXMLType(New XMLDataType(XMLType, ""));
								EndIf;
						EndIf;
					EndDo;
				EndIf;
				
				If Not ValueIsFilled(NewValue.Type) Then
					AttributeDetails = AttributeMetadata(ObjectMetadata, AttributeName);
					If AttributeDetails = Undefined Then
						AttributeDetails = Metadata.CommonAttributes.Find(AttributeName);
					EndIf;
					If AttributeDetails = Undefined And Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
						AttributeDetails = ObjectMetadata.AccountingFlags.Find(AttributeName);
					EndIf;
					
					If AttributeDetails <> Undefined
						And AttributeDetails.Type.Types().Count() = 1 Then
						NewValue.Type = AttributeDetails.Type.Types()[0];
					EndIf;
				EndIf;
			ElsIf (ReadingLevel = 3) And XMLReader.Name = "Row" Then // 
				If TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				TabularSections[TabularSectionName].Add();
			ElsIf ReadingLevel = 4 Then
				If XMLReader.Name = "v8:Type" Then
					If NewValue.AttributeValue = Undefined Then
						NewValue.AttributeValue = "";
					EndIf;
				Else // 
					TSFieldValueType = "";
					TSFieldName = XMLReader.Name;
					Table   = TabularSections[TabularSectionName];// ValueTable 
					If Table.Columns.Find(TSFieldName)= Undefined Then
						Table.Columns.Add(TSFieldName);
					EndIf;
					
					If XMLReader.AttributeCount() > 0 Then
						While XMLReader.ReadAttribute() Do
							If XMLReader.NodeType = XMLNodeType.Attribute 
								And XMLReader.Name = "xsi:type" Then
									XMLType = XMLReader.Value;
									If StrStartsWith(XMLType, "xs:") Then
										TSFieldValueType = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
									Else
										TSFieldValueType = FromXMLType(New XMLDataType(XMLType, ""));
									EndIf;
							EndIf;
						EndDo;
					EndIf;
				EndIf;
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			ReadingLevel = ReadingLevel - 1;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If (ReadingLevel = 2) Then // 
				Try
					NewValue.AttributeValue = ?(ValueIsFilled(NewValue.Type), XMLValue(NewValue.Type, XMLReader.Value), XMLReader.Value);
				Except
					NewValue.AttributeValue = XMLReader.Value;
				EndTry;
			ElsIf (ReadingLevel = 4) Then // 
				If NewValue.Type = Type("TypeDescription") Then
					TypeAsString = String(FromXMLType(New XMLDataType(XMLReader.Value, "")));
					If IsBlankString(TypeAsString) Then
						TypeAsString = XMLReader.Value;
					EndIf;
					If Not IsBlankString(NewValue.AttributeValue) Then
						NewValue.AttributeValue = NewValue.AttributeValue + Chars.LF;
					EndIf;
					NewValue.AttributeValue = NewValue.AttributeValue + TypeAsString;
				Else
					If TSFieldValueType = "" Then
						AttributeDetails = Undefined;
						TabularSectionMetadata = TabularSectionMetadata(ObjectMetadata, TabularSectionName);
						If TabularSectionMetadata <> Undefined Then
							AttributeDetails = TabularSectionAttributeMetadata(TabularSectionMetadata, TSFieldName);
							If AttributeDetails = Undefined And Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
								AttributeDetails = ObjectMetadata.ExtDimensionAccountingFlags.Find(TSFieldName);
							EndIf;
							If AttributeDetails <> Undefined
								And AttributeDetails.Type.Types().Count() = 1 Then
									TSFieldValueType = AttributeDetails.Type.Types()[0];
							EndIf;
						EndIf;
					EndIf;
					LastRow = TabularSections[TabularSectionName].Get(TabularSections[TabularSectionName].Count()-1);
					Value = XMLReader.Value;
					If ValueIsFilled(TSFieldValueType) Then
						Try
							Value = XMLValue(TSFieldValueType, XMLReader.Value);
						Except
							Value = XMLReader.Value;
						EndTry;
					EndIf;
					LastRow[TSFieldName] = Value;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	// Exclude tabular sections from the attribute list
	For Each Item In TabularSections Do
		AttributesValues.Delete(AttributesValues.Find(Item.Key));
	EndDo;
	
	// If the object tabular section is empty and column names are not read in, fill the table columns.
	For Each TabularSection In TabularSections Do
		TableName = TabularSection.Key;  // String - 
		Table = TabularSection.Value; // ValueTable - 
		If Table.Columns.Count() = 0 Then
			MetadataTables = TabularSectionMetadata(ObjectMetadata, TableName);
			If MetadataTables <> Undefined Then
				For Each ColumnDetails In TabularSectionAttributes(MetadataTables) Do
					If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
						Table.Columns.Add(ColumnDetails.Name);
					EndIf;
				EndDo;
				If Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
					For Each ColumnDetails In ObjectMetadata.ExtDimensionAccountingFlags Do
						If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
							Table.Columns.Add(ColumnDetails.Name);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Insert("Attributes", AttributesValues);
	Result.Insert("TabularSections", TabularSections);
	
	If Result.HiddenAttributes <> Undefined Then
		For Each AttributeName In Result.HiddenAttributes Do
			If StrEndsWith(AttributeName, ".*") Then
				TabularSectionName = Left(AttributeName, StrLen(AttributeName) - 2);
				If Result.TabularSections[TabularSectionName] <> Undefined Then
					Result.TabularSections.Delete(TabularSectionName);
				EndIf;
			Else
				FoundAttributes = Result.Attributes.FindRows(New Structure("AttributeDescription", AttributeName));
				For Each Attribute In FoundAttributes Do
					Result.Attributes.Delete(Attribute);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If Result.AdditionalAttributes <> Undefined Then
		For Each AdditionalAttribute In Result.AdditionalAttributes Do
			Attribute = AttributesValues.Add();
			Attribute.AttributeDescription = AdditionalAttribute.Description;
			Attribute.AttributeValue = AdditionalAttribute.Value;
			Attribute.Type = TypeOf(AdditionalAttribute.Value);
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  ObjectMetadata - MetadataObject
//  AttributeName - String
// Returns:
//  StandardAttributeDetails, MetadataObjectAttribute, Undefined
//
Function AttributeMetadata(ObjectMetadata, AttributeName)
	Result = ObjectMetadata.Attributes.Find(AttributeName);
	If Result = Undefined Then
		Try
			Result = ObjectMetadata.StandardAttributes[AttributeName];
		Except
			Result = Undefined;
		EndTry;
	EndIf;
	Return Result;
EndFunction

Function TabularSectionMetadata(ObjectMetadata, TabularSectionName) Export
	
	TabularSection = ObjectMetadata.TabularSections.Find(TabularSectionName);
	If TabularSection <> Undefined Then
		Return TabularSection;
	EndIf;
	
	If Not Metadata.ChartsOfAccounts.Contains(ObjectMetadata)
		And Not Metadata.ChartsOfCalculationTypes.Contains(ObjectMetadata) Then
		Return Undefined;
	EndIf;
	
	Try
		TabularSection = ObjectMetadata.StandardTabularSections[TabularSectionName];
	Except
		TabularSection = Undefined;
	EndTry;
	
	Return TabularSection;
	
EndFunction

Function TabularSectionAttributeMetadata(TabularSectionMetadata, AttributeName) Export
	Result = Undefined;
	If TypeOf(TabularSectionMetadata) = Type("StandardTabularSectionDescription") Then
		Try
			Result = TabularSectionMetadata.StandardAttributes[AttributeName];
		Except
			Result = Undefined;
		EndTry;
	Else
		Result = TabularSectionMetadata.Attributes.Find(AttributeName);
	EndIf;
	Return Result;
EndFunction

// Parameters:
//  TabularSectionMetadata - StandardTabularSectionDescription
//                           - MetadataObjectTabularSection
//  
// Returns:
//  StandardAttributeDescriptions, MetadataObjectCollection
//
Function TabularSectionAttributes(TabularSectionMetadata)
	If TypeOf(TabularSectionMetadata) = Type("StandardTabularSectionDescription") Then
		Result = TabularSectionMetadata.StandardAttributes;
	Else
		Result = TabularSectionMetadata.Attributes;
	EndIf;
	Return Result;
EndFunction

Function GenerateObjectVersionReport(ObjectDetails, ObjectReference)
	
	If ObjectReference.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = Common.ObjectManagerByRef(ObjectReference).GetTemplate("ObjectTemplate");
		Return UseStandardTemplateToGenerate(Template, ObjectDetails, ObjectDetails.LongDesc, ObjectReference);
	Else
		SpreadsheetDocument = New SpreadsheetDocument;
		Section3 = SpreadsheetDocument.GetArea("R2");
		OutputTextToReport(SpreadsheetDocument, Section3, "R2C2", ObjectReference.Metadata().Synonym, StyleFonts.ExtraLargeTextFont);
		
		SpreadsheetDocument.Area("C2").ColumnWidth = 30;
		If ObjectDetails.VersionNumber <> 0 Then
			OutputHeaderForVersion(SpreadsheetDocument, ObjectDetails.LongDesc, 4, 3);
			OutputHeaderForVersion(SpreadsheetDocument, ObjectDetails.Comment, 5, 3);
		EndIf;
		
		DisplayedRowNumber = OutputParsedObjectAttributes(SpreadsheetDocument, ObjectDetails, ObjectReference);
		OutputParsedObjectTabularSections(SpreadsheetDocument, ObjectDetails, DisplayedRowNumber + 7, ObjectReference);
		OutputParsedObjectSpreadsheetDocuments(SpreadsheetDocument, ObjectDetails);
		Return SpreadsheetDocument;
	EndIf;
	
EndFunction

Function UseStandardTemplateToGenerate(Template, ObjectVersion, Val VersionDetails, ObjectReference)
	
	Result = New SpreadsheetDocument;
	ObjectMetadata = ObjectReference.Metadata();
	ObjectDescription = ObjectMetadata.Name;
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectReference)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Title
	Area = Template.GetArea("Title");
	Result.Put(Area);
	
	Area = Result.GetArea("R3");
	SetTextProperties(Area.Area("R1C2"), VersionDetails, StyleFonts.ImportantLabelFont);
	Result.Put(Area);
	
	Area = Result.GetArea("R5");
	Result.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Attributes = New Structure;
	For Each AttributeDetails In ObjectVersion.Attributes Do
		AttributeName = AttributeDetails.AttributeDescription;
		AttributeMetadata = AttributeMetadata(ObjectMetadata, AttributeDetails.AttributeDescription);
		If AttributeMetadata = Undefined And Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
			AttributeMetadata = ObjectMetadata.AccountingFlags.Find(AttributeDetails.AttributeDescription);
		EndIf;
		If AttributeMetadata <> Undefined Then
			AttributeName = AttributeMetadata.Name;
		EndIf;
		
		AttributeValue = AttributeDetails.AttributeValue;
		Attributes.Insert(AttributeName, AttributeValue);
	EndDo;
	Header.Parameters.Fill(Attributes);
	Result.Put(Header);
	
	TabularSectionNames = New Array;
	For Each TabularSection In ObjectMetadata.TabularSections Do
		TabularSectionNames.Add(TabularSection.Name);
	EndDo;
	If Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
		For Each TabularSection In ObjectMetadata.StandardTabularSections Do
			TabularSectionNames.Add(TabularSection.Name);
		EndDo;
	EndIf;
	
	For Each TabularSectionName In TabularSectionNames Do
		If ObjectVersion.TabularSections[TabularSectionName].Count() = 0 Then
			Continue;
		EndIf;
		
		TabularSection = ObjectVersion.TabularSections[TabularSectionName].Copy(); // ValueTable
		TabularSection.Columns.Add("LineNumber");
		
		AreaName = TabularSectionName + "Header";
		If Template.Areas.Find(AreaName) = Undefined Then
			Continue;
		EndIf;
		Area = Template.GetArea(AreaName);
		Result.Put(Area);
		
		AreaName = TabularSectionName;
		If Template.Areas.Find(AreaName) = Undefined Then
			Continue;
		EndIf;
		Area = Template.GetArea(AreaName);
		LineNumber = 0;
		For Each TableRow In TabularSection Do
			LineNumber = LineNumber + 1;
			TableRow.LineNumber = LineNumber;
			Area.Parameters.Fill(TableRow);
			Result.Put(Area);
		EndDo;
	EndDo;
	
	If ObjectVersion.Property("SpreadsheetDocuments") Then
		SpreadsheetDocuments = ObjectVersion.SpreadsheetDocuments;// See ObjectSpreadsheetDocuments
		If SpreadsheetDocuments <> Undefined Then
			If Template.Areas.Find("SpreadsheetDocumentsHeader") <> Undefined Then
				SpreadsheetDocumentsHeader = Template.GetArea("SpreadsheetDocumentsHeader");
				Result.Put(SpreadsheetDocumentsHeader);
				SpreadsheetDocumentHeader = ?(Template.Areas.Find("SpreadsheetDocumentHeader") = Undefined,
					Undefined, Template.GetArea("SpreadsheetDocumentHeader"));
				
				For Each StructureItem In SpreadsheetDocuments Do
					If SpreadsheetDocumentHeader <> Undefined Then
						SpreadsheetDocumentDescription = New Structure("SpreadsheetDocumentDescription", StructureItem.Value.Description);
						SpreadsheetDocumentHeader.Parameters.Fill(SpreadsheetDocumentDescription);
						Result.Put(SpreadsheetDocumentHeader);
					EndIf;
					Result.Put(StructureItem.Value.Data);
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	Result.ShowGrid = False;
	Result.Protection = True;
	Result.ReadOnly = True;
	Result.ShowHeaders = False;
	
	Return Result;
	
EndFunction

Procedure OutputHeaderForVersion(Result, Val Text, Val LineNumber, Val ColumnNumber)
	
	If Not IsBlankString(Text) Then
		
		Result.Area("C" + String(ColumnNumber)).ColumnWidth = 50;
		
		State = "R" + Format(LineNumber, "NG=0") + "C" + Format(ColumnNumber, "NG=0");
		Result.Area(State).Text = Text;
		Result.Area(State).BackColor = StyleColors.InaccessibleCellTextColor;
		Result.Area(State).Font = StyleFonts.ImportantLabelFont;
		Result.Area(State).TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		Result.Area(State).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		Result.Area(State).LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		Result.Area(State).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		
	EndIf;
	
EndProcedure

Function OutputParsedObjectAttributes(Result, ObjectVersion, ObjectReference)
	
	Section3 = Result.GetArea("R6");
	OutputTextToReport(Result, Section3, "R1C1:R1C3", " ");
	OutputTextToReport(Result, Section3, "R1C2", "Attributes", StyleFonts.LargeTextFont);
	Result.StartRowGroup("AttributeGroup");
	OutputTextToReport(Result, Section3, "R1C1:R1C3", " ");
	
	NumberOfRowsToOutput = 0;
	
	Attributes = ObjectVersion.Attributes.Copy();
	Attributes.Columns.Add("DescriptionDetailsStructure");
	Attributes.Columns.Add("DisplayedDescription");
	For Each Attribute In Attributes Do
		Attribute.DescriptionDetailsStructure = DisplayedAttributeDescription(ObjectReference, Attribute.AttributeDescription);
		Attribute.DisplayedDescription = Attribute.DescriptionDetailsStructure.DisplayedDescription;
	EndDo;
	Attributes.Sort("DisplayedDescription");
	
	For Each ItemAttribute In Attributes Do
		DescriptionDetailsStructure = ItemAttribute.DescriptionDetailsStructure;
		If Not DescriptionDetailsStructure.OutputAttribute Then
			Continue;
		EndIf;
		
		DisplayedDescription = DescriptionDetailsStructure.DisplayedDescription;
		AttributeDetails = DescriptionDetailsStructure.AttributeDetails;
		
		AttributeValue = ?(ItemAttribute.AttributeValue = Undefined, "", ItemAttribute.AttributeValue);
		ValuePresentation = AttributeValuePresentation(AttributeValue, AttributeDetails);
		
		SetTextProperties(Section3.Area("R1C2"), DisplayedDescription, StyleFonts.ImportantLabelFont);
		SetTextProperties(Section3.Area("R1C3"), ValuePresentation);
		Section3.Area("R1C2:R1C3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section3.Area("R1C2:R1C3").BorderColor = StyleColors.InaccessibleCellTextColor;
		
		Result.Put(Section3);
		
		NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
	EndDo;
	
	Result.EndRowGroup();
	
	Return NumberOfRowsToOutput;
	
EndFunction

Procedure OutputParsedObjectTabularSections(Result, ObjectVersion, OutputRowNumber, ObjectReference)
	
	If ObjectVersion.TabularSections.Count() = 0 Then
		Return;
	EndIf;
	
	ObjectMetadata = ObjectReference.Metadata();
	NumberOfRowsToOutput = 0;
	
	For Each StringTabularSection In ObjectVersion.TabularSections Do
		TabularSectionDescription = StringTabularSection.Key;
		TabularSection = StringTabularSection.Value; // ValueTable
		If TabularSection.Count() = 0 Then
			Continue;
		EndIf;
			
		TSMetadata = TabularSectionMetadata(ObjectMetadata, TabularSectionDescription);
		TSSynonym = TabularSectionDescription;
		If TSMetadata <> Undefined Then
			TSSynonym = TSMetadata.Presentation();
		EndIf;
		
		Section3 = Result.GetArea("R" + XMLString(Result.TableHeight + 1));
		OutputTextToReport(Result, Section3, "R1C1:R1C" + Format(TabularSection.Columns.Count(), "NG=0"), " ");
		OutputArea2 = OutputTextToReport(Result, Section3, "R1C2", TSSynonym, StyleFonts.LargeTextFont);
		Result.Area("R" + Format(OutputArea2.Top, "NG=0") + "C2").CreateFormatOfRows();
		Result.Area("R" + Format(OutputArea2.Top, "NG=0") + "C2").ColumnWidth = Round(StrLen(TSSynonym)*2, 0, RoundMode.Round15as20);
		Result.StartRowGroup("LinesGroup");
		
		OutputTextToReport(Result, Section3, "R1C1:R1C3", " ");
		NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
		OutputRowNumber = OutputRowNumber + 3;
		
		TSToAdd = New SpreadsheetDocument;
		TSToAdd.Join(GenerateEmptySector(TabularSection.Count()+1));
		
		ColumnNumber = 2;
		ColumnDimensionMap = New Map;
		
		Section3 = New SpreadsheetDocument;
		SectionArea1 = Section3.Area("R1C1");
		SetTextProperties(SectionArea1, "N", StyleFonts.ImportantLabelFont, True);
		SectionArea1.BackColor = StyleColors.InaccessibleCellTextColor;
		
		LineNumber = 1;
		For Each LineOfATabularSection In TabularSection Do
			LineNumber = LineNumber + 1;
			SetTextProperties(Section3.Area("R" + Format(LineNumber, "NG=0") + "C1"), 
				Format(LineNumber-1, "NG=0"), , True);
		EndDo;
		TSToAdd.Join(Section3);
		
		ColumnNumber = 3;
		
		For Each TabularSectionColumn In TabularSection.Columns Do
			Section3 = New SpreadsheetDocument;
			FieldDescription = TabularSectionColumn.Name;
			
			FieldDetails = Undefined;
			If TSMetadata <> Undefined Then
				FieldDetails = TabularSectionAttributeMetadata(TSMetadata, FieldDescription);
			EndIf;
			If FieldDetails = Undefined And Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
				FieldDetails = ObjectMetadata.ExtDimensionAccountingFlags.Find(FieldDescription);
			EndIf;
			If FieldDetails = Undefined Then
				DisplayedFieldDescription = FieldDescription;
			Else
				DisplayedFieldDescription = FieldDetails.Presentation();
			EndIf;
			
			ColumnHeaderColor = ?(FieldDetails = Undefined, StyleColors.DeletedAttributeTitleBackground, StyleColors.InaccessibleCellTextColor);
			AreaSection = Section3.Area("R1C1");
			SetTextProperties(AreaSection, DisplayedFieldDescription, StyleFonts.ImportantLabelFont, True);
			AreaSection.BackColor = ColumnHeaderColor;
			ColumnDimensionMap.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
			LineNumber = 1;
			For Each LineOfATabularSection In TabularSection Do
				LineNumber = LineNumber + 1;
				Value = ?(LineOfATabularSection[FieldDescription] = Undefined, "", LineOfATabularSection[FieldDescription]);
				ValuePresentation = AttributeValuePresentation(Value, FieldDetails);
				
				SetTextProperties(Section3.Area("R" + Format(LineNumber, "NG=0") + "C1"), ValuePresentation, , True);
				If StrLen(ValuePresentation) > (ColumnDimensionMap[ColumnNumber] - 4) Then
					ColumnDimensionMap[ColumnNumber] = StrLen(ValuePresentation) + 4;
				EndIf;
			EndDo;
			
			TSToAdd.Join(Section3);
			ColumnNumber = ColumnNumber + 1;
		EndDo;
		
		OutputArea2 = Result.Put(TSToAdd);
		Result.Area(OutputArea2.Top, 1, OutputArea2.Bottom, ColumnNumber).CreateFormatOfRows();
		Result.Area("R" + Format(OutputArea2.Top, "NG=0") + "C2").ColumnWidth = 7;
		For CurrentColumnNumber1 = 3 To ColumnNumber-1 Do
			Result.Area("R" + Format(OutputArea2.Top, "NG=0") + "C" + Format(CurrentColumnNumber1, "NG=0")).ColumnWidth = ColumnDimensionMap[CurrentColumnNumber1];
		EndDo;
		Result.EndRowGroup();
	EndDo;
	
EndProcedure

Function OutputTextToReport(Result, Val Section3, Val State, Val Text, Val Font = Undefined)
	
	If Font = Undefined Then
		Font = StyleFonts.TextFont;
	EndIf;
	
	SectionArea1 = Section3.Area(State);
	
	If TypeOf(SectionArea1) = Type("SpreadsheetDocumentRange") Then
	
		SectionArea1.Text = Text;
		SectionArea1.Font = Font;
		SectionArea1.HorizontalAlign = HorizontalAlign.Left;
		
		SectionArea1.TopBorder = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea1.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea1.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea1.RightBorder = New Line(SpreadsheetDocumentCellLineType.None);
		
	EndIf;
	
	Return Result.Put(Section3);
	
EndFunction

Procedure SetTextProperties(SectionArea1, Text, Val Font = Undefined, Val ShowBorders = False)
	
	If Font = Undefined Then
		Font = StyleFonts.TextFont;
	EndIf;
	
	If TypeOf(SectionArea1) = Type("SpreadsheetDocumentRange") Then
	
		SectionArea1.Text = Text;
		SectionArea1.Font = Font;
		
		If ShowBorders Then
			SectionArea1.TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea1.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea1.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea1.RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea1.HorizontalAlign = HorizontalAlign.Center;
		EndIf;
	
	EndIf
	
EndProcedure

Function GenerateEmptySector(Val CountOfRows, Val OutputType = "")
	
	FillValue = New Array;
	
	For IndexOf = 1 To CountOfRows Do
		FillValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillValue, OutputType);
	
EndFunction

// Parameters:
//  FillValue - Array of String
//  OutputType - String
//
Function GenerateTSRowSector(Val FillValue,Val OutputType = "")
	
	CommonTemplate = InformationRegisters.ObjectsVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If OutputType = ""  Then
		Template = CommonTemplate.GetArea("InitialAttributeValue");
	ElsIf OutputType = "And" Then
		Template = CommonTemplate.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "D" Then
		Template = CommonTemplate.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Template = CommonTemplate.GetArea("DeletedAttribute");
	EndIf;
	
	For Each NextValue In FillValue Do
		Template.Parameters.AttributeValue = NextValue;
		SpreadsheetDocument.Put(Template);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Function AttributeValuePresentation(AttributeValue, MetadataObjectAttribute)
	
	FormatString = "";
	If MetadataObjectAttribute <> Undefined Then
		If TypeOf(AttributeValue) = Type("Date") Then
			FormatString = "DLF=DT";
			If MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Date Then
				FormatString = "DLF=D";
			ElsIf MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Time Then
				FormatString = "DLF=T";
			EndIf;
		EndIf;
	EndIf;
	
	Return Format(AttributeValue, FormatString);
	
EndFunction

Function ParseVersion(Ref, VersionNumber) Export
	
	VersionInfo = ObjectVersionInfo(Ref, VersionNumber);
	
	Result = XMLObjectPresentationParsing(VersionInfo.ObjectVersion, Ref);
	Result.Insert("ObjectName",     String(Ref));
	Result.Insert("ChangeAuthor", TrimAll(String(VersionInfo.VersionAuthor)));
	Result.Insert("ChangeDate",  VersionInfo.VersionDate);
	Result.Insert("Comment",    VersionInfo.Comment);
	
	ObjectsVersioningOverridable.AfterParsingObjectVersion(Ref, Result);
	
	Return Result;
	
EndFunction

Procedure OutputParsedObjectSpreadsheetDocuments(SpreadsheetDocument, ObjectDetails)
	
	SpreadsheetDocuments = ObjectDetails.SpreadsheetDocuments;// See ObjectSpreadsheetDocuments
	
	If SpreadsheetDocuments = Undefined Then
		Return;
	EndIf;
	
	CommonTemplate = InformationRegisters.ObjectsVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	TemplateHeaderSpreadsheetDocuments = CommonTemplate.GetArea("SpreadsheetDocumentsHeader");	
	TemplateRowSpreadsheetDocuments = CommonTemplate.GetArea("SpreadsheetDocumentHeader");
	TemplateEmptyRow = CommonTemplate.GetArea("EmptyRow");
	
	SpreadsheetDocument.Put(TemplateEmptyRow);
	SpreadsheetDocument.Put(TemplateHeaderSpreadsheetDocuments);
	SpreadsheetDocument.Put(TemplateEmptyRow);
	SpreadsheetDocument.StartRowGroup("SpreadsheetDocumentsGroup1");
	
	For Each StructureItem In SpreadsheetDocuments Do
		SpreadsheetDocumentDescription = StructureItem.Value.Description;
		TemplateRowSpreadsheetDocuments.Parameters.SpreadsheetDocumentDescription = SpreadsheetDocumentDescription;
		SpreadsheetDocument.Put(TemplateRowSpreadsheetDocuments);
		SpreadsheetDocument.Put(TemplateEmptyRow);
		
		DisplayedDocument = StructureItem.Value.Data;
		SpreadsheetDocumentDisplayArea = SpreadsheetDocument.Put(DisplayedDocument);
		SpreadsheetDocumentDisplayArea.CreateFormatOfRows();
		
		For ColumnNumber = 1 To DisplayedDocument.TableWidth Do 
			ColumnWidth = DisplayedDocument.Area(1, ColumnNumber, DisplayedDocument.TableHeight, ColumnNumber).ColumnWidth;
			SpreadsheetDocument.Area(SpreadsheetDocumentDisplayArea.Top, ColumnNumber,
				SpreadsheetDocumentDisplayArea.Bottom, ColumnNumber).ColumnWidth = ColumnWidth;
		EndDo;
		
		SpreadsheetDocument.Put(TemplateEmptyRow);
	EndDo;
	
	SpreadsheetDocument.EndRowGroup();
	SpreadsheetDocument.Put(TemplateEmptyRow);
	
EndProcedure

Function DisplayedAttributeDescription(ObjectReference, Val AttributeName) Export
	
	OutputAttribute = True;
	
	AttributeDetails = AttributeMetadata(ObjectReference.Metadata(), AttributeName);
	If AttributeDetails = Undefined Then
		AttributeDetails = Metadata.CommonAttributes.Find(AttributeName);
	EndIf;
	
	AttributeRepresentation = AttributeName;
	If AttributeDetails <> Undefined Then
		AttributeRepresentation = AttributeDetails.Presentation();
	EndIf;
	
	ObjectsVersioningOverridable.OnDetermineObjectAttributeDescription(ObjectReference, 
		AttributeName, AttributeRepresentation, OutputAttribute);
	
	Return New Structure("DisplayedDescription, OutputAttribute, AttributeDetails", 
		AttributeRepresentation, OutputAttribute, AttributeDetails);
	
EndFunction

Function DataToStore(Val Object)
	
	ObjectReference = Object;
	If Common.RefTypeValue(Object) Then
		Object = Object.GetObject();
	Else
		ObjectReference = Object.Ref;
	EndIf;
	
	ObjectData = SerializeObject(Object);
	
	SpreadsheetDocuments = ObjectSpreadsheetDocuments(ObjectReference);
	
	AdditionalAttributes = AdditionalAttributesCollection();
	HiddenAttributes = HiddenAttributesCollection();
	
	ObjectsVersioningOverridable.OnPrepareObjectData(Object, AdditionalAttributes);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnPrepareObjectData(Object, AdditionalAttributes);
		HiddenAttributes.Add("AdditionalAttributes.*");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnPrepareObjectData(Object, AdditionalAttributes);
		HiddenAttributes.Add("ContactInformation.*");
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(ObjectReference);
	Settings = SubsystemSettings();
	Try
		ObjectManager.OnDefineObjectVersioningSettings(Settings);
	Except
		Settings = SubsystemSettings();
	EndTry;
	
	ObjectInternalAttributes = New Array;
	If Settings.OnGetInternalAttributes Then
		ObjectManager.OnGetInternalAttributes(ObjectInternalAttributes);
		CommonClientServer.SupplementArray(HiddenAttributes, ObjectInternalAttributes);
	EndIf;
	CommonClientServer.SupplementArray(HiddenAttributes, ObjectsInternalAttributes());
	
	Result = New Structure;
	
	If SpreadsheetDocuments <> Undefined And SpreadsheetDocuments.Count() > 0 Then
		Result.Insert("SpreadsheetDocuments", SpreadsheetDocuments);
	EndIf;
	
	If AdditionalAttributes.Count() > 0 Then
		Result.Insert("AdditionalAttributes", AdditionalAttributes);
	EndIf;
	
	If HiddenAttributes.Count() > 0 Then
		Result.Insert("HiddenAttributes", HiddenAttributes);
	EndIf;
	
	If Result.Count() > 0 Then
		Result.Insert("Object", ObjectData);
	Else
		Result = ObjectData;
	EndIf;
	
	Return Result;
	
EndFunction

Function AdditionalAttributesCollection()
	Result = New ValueTable;
	Result.Columns.Add("Id");
	Result.Columns.Add("Description", New TypeDescription("String"));
	Result.Columns.Add("Value");
	
	Return Result;
EndFunction

Function HiddenAttributesCollection()
	Return New Array;
EndFunction

// Returns:
//   Array of Structure:
//   * Value - Structure:
//   ** Description - String
//
Function ObjectSpreadsheetDocuments(Ref) Export
	Result = New Structure;
	ObjectsVersioningOverridable.OnReceiveObjectSpreadsheetDocuments(Ref, Result);
	Return Result;
EndFunction

Function ObjectsInternalAttributes()
	Attributes = New Array;
	Attributes.Add("Ref");
	Attributes.Add("IsFolder");
	Attributes.Add("PredefinedDataName");
	
	Return Attributes;
EndFunction

Function DataSize(Data) Export
	Return Base64Value(XDTOSerializer.XMLString(Data)).Size();
EndFunction

Procedure AddInfoAboutNode(Record, Recipient)
	
	If Record.Node = Common.SubjectString(Recipient.Ref) Then
		Record.Node = "";
	Else
		If IsBlankString(Record.Node) Then
			ExchangePlanManager = Common.ObjectManagerByRef(Recipient.Ref);
			Record.Node = Common.SubjectString(ExchangePlanManager.ThisNode());
		EndIf;
	EndIf;
	
	If Record.VersionAuthor = Undefined Then
		Return;
	EndIf;
	AuthorMetadata = Record.VersionAuthor.Metadata();
	If Common.IsExchangePlan(AuthorMetadata) Then
		
		Record.SynchronizationWarning = StringFunctionsClientServer.SubstituteParametersToString("<VersionAuthor>%1;%2</VersionAuthor>",
			AuthorMetadata.Name, Common.ObjectAttributeValue(Record.VersionAuthor, "Code"))
			+ Record.SynchronizationWarning;
			
	EndIf;
	
EndProcedure

Procedure ReadInfoAboutNode(Record)
	
	If StrStartsWith(Record.Comment, "<VersionAuthor>") Then
		Position = StrFind(Record.Comment, "</VersionAuthor>");
		If Position > 0 Then
			NodeDetails = Left(Record.Comment, Position - 1);
			Record.Comment = Mid(Record.Comment, Position + StrLen("</VersionAuthor>"));
			NodeDetails = Mid(NodeDetails, StrLen("<VersionAuthor>") + 1);
			NodeDetails = StrSplit(NodeDetails, ";");
			NodeName = NodeDetails[0];
			NodeCode = NodeDetails[1];
			VersionAuthor = ExchangePlans[NodeName].FindByCode(NodeCode);
			If ValueIsFilled(VersionAuthor) Then
				Record.VersionAuthor = VersionAuthor;
			EndIf;
		EndIf;
		
	ElsIf StrStartsWith(Record.SynchronizationWarning, "<VersionAuthor>") Then
		
		Position = StrFind(Record.SynchronizationWarning, "</VersionAuthor>");
		If Position > 0 Then
			NodeDetails = Left(Record.SynchronizationWarning, Position - 1);
			Record.SynchronizationWarning = Mid(Record.SynchronizationWarning, Position + StrLen("</VersionAuthor>"));
			NodeDetails = Mid(NodeDetails, StrLen("<VersionAuthor>") + 1);
			NodeDetails = StrSplit(NodeDetails, ";");
			NodeName = NodeDetails[0];
			NodeCode = NodeDetails[1];
			VersionAuthor = ExchangePlans[NodeName].FindByCode(NodeCode);
			If ValueIsFilled(VersionAuthor) Then
				Record.VersionAuthor = VersionAuthor;
			EndIf;
		EndIf;
	
	EndIf;
	
	If Record.VersionAuthor = Undefined Then
		Return;
	EndIf;
	AuthorMetadata = Record.VersionAuthor.Metadata();
	
	If Common.IsExchangePlan(AuthorMetadata) Then
		ExchangePlanManager = Common.ObjectManagerByRef(Record.VersionAuthor);
		If Record.VersionAuthor = ExchangePlanManager.ThisNode() Then
			Record.Node = "";
		EndIf;
	EndIf;
	
EndProcedure

Function VersionsToExport(Object, Node)
	
	QueryText =
	"SELECT
	|	VersionsOfChangeObjects.VersionNumber AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions.Changes AS VersionsOfChangeObjects
	|		INNER JOIN InformationRegister.ObjectsVersions AS ObjectsVersions
	|		ON VersionsOfChangeObjects.Object = ObjectsVersions.Object
	|			AND VersionsOfChangeObjects.VersionNumber = ObjectsVersions.VersionNumber
	|WHERE
	|	VersionsOfChangeObjects.Object = &Object
	|	AND VersionsOfChangeObjects.Node = &Node
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object);
	Query.SetParameter("Node", Node);
	
	Return Query.Execute().Unload();
	
EndFunction

Function SubsystemSettings()
	Result = New Structure;
	Result.Insert("OnGetInternalAttributes", False);
	
	Return Result;
EndFunction

Function NumberOfUnsynchronizedVersions(Object, VersionNumber)
	
	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	NOT ObjectsVersions.Synchronized
	|	AND ObjectsVersions.Object = &Object
	|	AND ObjectsVersions.VersionNumber < &VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object);
	Query.SetParameter("VersionNumber", VersionNumber);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Count;
	EndIf;
	
	Return 0;
	
EndFunction

Function ObjectWritingInProgress(Value = Undefined)
	If Value <> Undefined Then
		SessionParameters.ObjectWritingInProgress = Value;
		Return Value;
	EndIf;
	Return SessionParameters.ObjectWritingInProgress;
EndFunction

Function VersionRegisterIsIncludedInExchangePlan(Sender)
	MetadataObject = Metadata.FindByType(TypeOf(Sender));
	Return MetadataObject.Content.Contains(Metadata.InformationRegisters.ObjectsVersions);
EndFunction

Function RestoreVersionServer(Ref, VersionNumber, ErrorMessageText, UndoPosting = False) Export
	
	If Not Users.IsFullUser() Then
		Raise NStr("en = 'Insufficient rights to perform the operation.';");
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectsVersions");
	LockItem.SetValue("Object", Ref);
	
	LockItem = Block.Add(Ref.Metadata().FullName());
	LockItem.SetValue("Ref", Ref);
	
	ErrorID = "RecoveryError";
	
	BeginTransaction();
	Try
		Block.Lock();
		LockDataForEdit(Ref);
		
		CustomNumberPresentation = VersionNumberInHierarchy(Ref, VersionNumber);
		Information = ObjectVersionInfo(Ref, VersionNumber);
		
		AdditionalAttributes = Undefined;
		If TypeOf(Information.ObjectVersion) = Type("Structure") Then
			If Information.ObjectVersion.Property("AdditionalAttributes", AdditionalAttributes) Then
				FoundAttributes = AdditionalAttributes.FindRows(New Structure("Id", Undefined));
				For Each Attribute In FoundAttributes Do
					AdditionalAttributes.Delete(Attribute);
				EndDo;
			EndIf;
		EndIf;
	
		ErrorMessageText = "";
		Object = RestoreObjectByXML(Information.ObjectVersion, ErrorMessageText);
		
		If Not IsBlankString(ErrorMessageText) Then
			RollbackTransaction();
			Return "RecoveryError";
		EndIf;
	
		Object.AdditionalProperties.Insert("ObjectsVersioningVersionComment",
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Object is restored to version %1 created on %2';"),
				CustomNumberPresentation,
				Format(Information.VersionDate, "DLF=DT")));
	
		WriteMode = Undefined;
	
		If Common.IsDocument(Object.Metadata()) And Object.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow Then
			If Object.Posted And Not UndoPosting Then
				WriteMode = DocumentWriteMode.Posting;
			ElsIf Not Object.Ref.IsEmpty() Then
				WriteMode = DocumentWriteMode.UndoPosting;
			EndIf;
			ErrorID = "PostingError";
		EndIf;
		
		If Ref.GetObject() <> Undefined Then
			WriteCurrentVersionData(Ref);
		EndIf;
		
		ObjectWritingInProgress(True);
		If ValueIsFilled(WriteMode) Then
			Object.Write(WriteMode);
		Else
			Object.Write();
		EndIf;
		If ValueIsFilled(AdditionalAttributes) Then
			If Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
				ModulePropertyManagerInternal.OnRestoreObjectVersion(Object, AdditionalAttributes);
			EndIf;
			ObjectsVersioningOverridable.OnRestoreObjectVersion(Object, AdditionalAttributes);
		EndIf;
		ObjectWritingInProgress(False);
		
		WriteObjectVersion(Object);
		CommitTransaction();
	Except
		RollbackTransaction();
		ObjectWritingInProgress(False);
		ErrorMessageText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return ErrorID;
	EndTry;
	
	Return "Recovered";
	
EndFunction

Function VersionNumberInHierarchy(Ref, VersionNumber)
	
	If HasRightToReadObjectVersionData() Then
		SetPrivilegedMode(True);
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.VersionOwner
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	VersionTable = Query.Execute().Unload();
	
	VersionsTree = New ValueTree;
	VersionsTree.Columns.Add("VersionNumber");
	VersionsTree.Columns.Add("VersionNumberPresentation");
	VersionsTree.Columns.Add("IsRejected", New TypeDescription("Boolean"));
	
	FillVersionHierarchy(VersionsTree, VersionTable);
	NumberVersions(VersionsTree.Rows);
	
	VersionDetails = VersionsTree.Rows.Find(VersionNumber, "VersionNumber", True);
	Result = VersionDetails;
	If Result <> Undefined Then
		Result = VersionDetails.VersionNumberPresentation;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillVersionHierarchy(VersionHierarchy, VersionsList) Export
	
	SkippedVersions = New Array;
	For Each VersionDetails In VersionsList Do
		If VersionDetails.VersionOwner = 0 Then
			Item = VersionHierarchy.Rows.Add();
		Else
			FoundVersion = VersionHierarchy.Rows.Find(VersionDetails.VersionOwner, "VersionNumber", True);
			If FoundVersion <> Undefined Then
				Item = FoundVersion.Rows.Add();
				FoundVersion.IsRejected = True;
			Else
				SkippedVersions.Add(VersionDetails);
				Continue;
			EndIf;
		EndIf;
		FillPropertyValues(Item, VersionDetails);
	EndDo;
	
	If SkippedVersions.Count() > 0 Then
		If VersionsList.Count() = SkippedVersions.Count() Then
			Return;
		EndIf;
		FillVersionHierarchy(VersionHierarchy, SkippedVersions);
	EndIf;
	
EndProcedure

Procedure NumberVersions(VersionCollection) Export
	
	VersionCurrentNumber = VersionCollection.Count();
	For Each Version In VersionCollection Do
		NumberPrefix = "";
		If Version.Parent <> Undefined And Not IsBlankString(Version.Parent.VersionNumberPresentation) Then
			NumberPrefix = Version.Parent.VersionNumberPresentation + ".";
		EndIf;
		
		Version.VersionNumberPresentation = NumberPrefix + Format(VersionCurrentNumber, "NG=0");
		NumberVersions(Version.Rows);
		VersionCurrentNumber = VersionCurrentNumber - 1;
	EndDo;
	
EndProcedure

Function VersionNumberInRegister(Object, SerialNumberOfVersionToSynchronize)
	
	QueryText = 
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.Synchronized AS Synchronized
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Object
	|
	|ORDER BY
	|	VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object);
	ObjectsVersions = Query.Execute().Unload();
	ObjectsVersions.Indexes.Add("Synchronized");
	
	VersionsToSynchronize = ObjectsVersions.FindRows(New Structure("Synchronized", True));
	NotVersionsToSynchronize = ObjectsVersions.FindRows(New Structure("Synchronized", False));
	
	If VersionsToSynchronize.Count() >= SerialNumberOfVersionToSynchronize Then
		Return VersionsToSynchronize[SerialNumberOfVersionToSynchronize - 1].VersionNumber;
	EndIf;
	
	Return NotVersionsToSynchronize.Count() + SerialNumberOfVersionToSynchronize;
	
EndFunction

Procedure CreateRejectedItemsOwnerVersion(LastRejectedVersionNumber, ConflictVersionNumber, Object, VersionAuthor)
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Object);
	RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
	Record = RecordSet.Add();
	
	LastVersionToExport = InformationRegisters.ObjectsVersions.CreateRecordManager();
	LastVersionToExport.Object = Object;
	LastVersionToExport.VersionNumber = LastRejectedVersionNumber;
	LastVersionToExport.Read();
	
	FillPropertyValues(Record, LastVersionToExport, , "VersionOwner");
	Record.VersionNumber = ConflictVersionNumber;
	Record.VersionDate = CurrentSessionDate();
	Record.SynchronizationWarning = NStr("en = 'Rejected version (automatic conflict resolving).';");
	Record.VersionAuthor = VersionAuthor;
	
	If Not Record.HasVersionData Then
		Record.ObjectVersion = New ValueStorage(DataToStore(Record.Object), New Deflation(9))
	EndIf;
	RecordSet.Write();

EndProcedure

// For a call from OnReceiveDataFromMaster and OnReceiveDataFromSlave.
//
// Parameters:
//   Sender
//
Procedure WriteVersionWithNumberChange(DataElement, ItemReceive, Sender, VersionNumber)
	
	Object = DataElement.Filter.Object.Value;
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Object);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
		Record.Object = Object;
		Record.VersionNumber = VersionNumber;
	Else
		Record = RecordSet[0];
	EndIf;
	FillPropertyValues(Record, DataElement[0], , "Object,VersionNumber");
	RecordSet.Write(); // 
	
	ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
	ItemReceive = DataItemReceive.Ignore;
	
EndProcedure

#EndRegion
