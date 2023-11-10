///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version          = "*";
	Handler.ExecutionMode = "Deferred";
	Handler.Id   = New UUID("c17ea385-6085-471f-ab94-219ec30a5a38");
	Handler.Comment     = NStr("en = 'Updating data integrity checks to reflect the changes in the new version of the application.
		|Some of the checks will be unavailable until the update is complete.';");
	Handler.Procedure       = "AccountingAuditInternal.UpdateAuxiliaryRegisterDataByConfigurationChanges";
	
	Handler = Handlers.Add();
	Handler.Version                              = "3.0.1.25";
	Handler.Id                       = New UUID("4a240e04-87df-4c10-9f7f-97969c61e84f");
	Handler.Procedure                           = "InformationRegisters.AccountingCheckResults.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode                     = "Deferred";
	Handler.UpdateDataFillingProcedure = "InformationRegisters.AccountingCheckResults.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead                     = "InformationRegister.AccountingCheckResults";
	Handler.ObjectsToChange                   = "InformationRegister.AccountingCheckResults";
	Handler.ObjectsToLock                  = "InformationRegister.AccountingCheckResults";
	Handler.ExecutionPriorities                = InfobaseUpdate.HandlerExecutionPriorities();
	Handler.CheckProcedure                   = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment                         = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Initial setting of the %1 flag and calculation of checksums in the ""Data integrity check results"" information register for better performance.';"),
		"IgnoreIssue");
	
	Handler = Handlers.Add();
	Handler.Version                              = "3.0.1.195";
	Handler.Id                       = New UUID("fcd45d27-8e5d-45dd-9648-deff60825ae1");
	Handler.Procedure                           = "Catalogs.AccountingCheckRules.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode                     = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.AccountingCheckRules.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead                     = "Catalog.AccountingCheckRules";
	Handler.ObjectsToChange                   = "Catalog.AccountingCheckRules";
	Handler.ObjectsToLock                  = "Catalog.AccountingCheckRules";
	Handler.ExecutionPriorities                = InfobaseUpdate.HandlerExecutionPriorities();
	Handler.CheckProcedure                   = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment                         = NStr("en = 'Disabling automatic start of system checks in the ""Data integrity"" subsystem.';");
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not SubsystemAvailable() Then
		Return;
	EndIf;
	
	AllIssues = SummaryInformationOnChecksKinds(Undefined, True, True);
	
	CheckKind = CheckKind("SystemChecks");
	Issues    = SummaryInformationOnChecksKinds(CheckKind, True, True);
	
	LastCheckInformation = LastAccountingCheckInformation();
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	Sections                 = ModuleToDoListServer.SectionsForObject("Report.AccountingCheckResults");
	FullUser = Users.IsFullUser();
	
	For Each Section In Sections Do
		
		OwnerID = "AccountingAudit" + StrReplace(Section.FullName(), ".", "_");
		If FullUser Then
			ToDoItem = ToDoList.Add();
			ToDoItem.Id  = OwnerID;
			ToDoItem.HasToDoItems       = AllIssues.HasErrors;
			ToDoItem.Important         = False;
			ToDoItem.Owner       = Section;
			ToDoItem.Presentation  = NStr("en = 'Data integrity issues';");
			ToDoItem.Count     = AllIssues.Count;
			ToDoItem.FormParameters = New Structure;
			ToDoItem.Form          = "Report.AccountingCheckResults.Form";
		EndIf;
		
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "AccountingAuditIncorrectData" + StrReplace(Section.FullName(), ".", "_");
		ToDoItem.HasToDoItems       = Issues.HasErrors;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = ?(FullUser, OwnerID, Section);
		ToDoItem.Presentation  = NStr("en = 'Invalid data';");
		ToDoItem.Count     = Issues.Count;
		ToDoItem.FormParameters = New Structure("CheckKind", CheckKind);
		ToDoItem.Form          = "Report.AccountingCheckResults.Form";
		
		
		// No check was performed for a long time.
		If ValueIsFilled(LastCheckInformation.LastCheckDate) Then
			ToolTip = NStr("en = 'Last checked on %1.';");
			ToolTip = StringFunctionsClientServer.SubstituteParametersToString(ToolTip, 
				Format(LastCheckInformation.LastCheckDate, "DLF=D"));
		Else
			ToolTip = "";
		EndIf;
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "AccountingAuditCheckRequired" + StrReplace(Section.FullName(), ".", "_");
		ToDoItem.HasToDoItems       = LastCheckInformation.WarnSecondCheckRequired;
		ToDoItem.Important         = False;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("en = 'Data integrity has not been checked for a while';");
		ToDoItem.ToolTip      = ToolTip;
		ToDoItem.Form          = "Catalog.AccountingCheckRules.ListForm";
	EndDo;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	//  
	// 
	Types.Add(Metadata.InformationRegisters.AccountingCheckResults);
	
EndProcedure

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.AccountingCheck.Name);
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.InformationRegisters.AccountingCheckResults, True);
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ToDosBuiltIn = Common.SubsystemExists("StandardSubsystems.ToDoList");
	Count = 0;
	If Not Users.IsExternalUserSession() And Not ToDosBuiltIn Then
		Count = SummaryInformationOnChecksKinds(Undefined, True, True).Count;
	EndIf;
	
	Parameters.Insert("AccountingAudit",
		New FixedStructure("NotifyOfAccountingIssues1, AccountingIssuesCount",
			Not ToDosBuiltIn,
			Count));
	
EndProcedure

// See ODataInterfaceOverridable.OnPopulateDependantTablesForODataImportExport
Procedure OnPopulateDependantTablesForODataImportExport(Tables) Export
	
	Tables.Add(Metadata.InformationRegisters.AccountingCheckResults.FullName());
	
EndProcedure

// Updates components of the system data integrity checks upon configuration change.
// 
// Parameters:
//  HasChanges - Boolean - return value. If recorded, True if data is changed; 
//                           otherwise, it is not changed.
//
Procedure UpdateAccountingChecksParameters(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ChecksChecksum = ChecksChecksum();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccountingAudit.SystemChecks",
			ChecksChecksum, HasCurrentChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccountingAudit.SystemChecks",
			?(HasCurrentChanges, New FixedStructure("HasChanges", True), New FixedStructure()));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

Function SystemCheckIssues() Export
	
	SummaryInformationOnChecksKinds = SummaryInformationOnChecksKinds("SystemChecks");
	Return SummaryInformationOnChecksKinds.Count > 0;
	
EndFunction

// Returns date and time of the current check as well as the need to display a warning
// about the second check.
//
Function LastAccountingCheckInformation(ChecksGroup = Undefined) Export
	
	Result = New Structure;
	Result.Insert("LastCheckDate", Undefined);
	Result.Insert("WarnSecondCheckRequired", False);
	
	Query = New Query(
		"SELECT
		|	ISNULL(MAX(AccountingChecksStates.LastRun), UNDEFINED) AS LastRun
		|FROM
		|	InformationRegister.AccountingChecksStates AS AccountingChecksStates
		|		LEFT JOIN Catalog.AccountingCheckRules AS AccountingCheckRules
		|		ON AccountingChecksStates.Validation = AccountingCheckRules.Ref
		|WHERE
		|	&FilterChecksGroup");
	If ChecksGroup = Undefined Then
		FilterChecksGroup = "TRUE";
	Else
		FilterChecksGroup = "AccountingCheckRules.AccountingChecksContext = &AccountingChecksContext";
	EndIf;	
	Query.Text = StrReplace(Query.Text, "&FilterChecksGroup", FilterChecksGroup);
	Query.SetParameter("AccountingChecksContext", "SystemChecks");
	SetPrivilegedMode(True);
	QueryResult = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Result.LastCheckDate = QueryResult[0].LastRun;
	If Result.LastCheckDate = Undefined Then
		Result.WarnSecondCheckRequired = True;
	Else
		TimeFromLastStart = (CurrentSessionDate() - Result.LastCheckDate) / (1000 * 60 * 60 * 30);
		Result.WarnSecondCheckRequired = TimeFromLastStart > 1; // 
	EndIf;
	
	Return Result;
	
EndFunction

Function AccountingSystemChecksInformation() Export
	
	Return LastAccountingCheckInformation("SystemChecks");
	
EndFunction

Function LastObjectCheck(Ref) Export
	
	SetPrivilegedMode(True);
	Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
	Set.Filter.ObjectWithIssue.Set(Ref);
	Set.Read();
	SetPrivilegedMode(False);
	
	Data = Set.Unload(, "Detected");
	Data.Sort("Detected Desc");
	
	If Data.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return Data[0].Detected;
	
EndFunction

// Prepares the data required to perform a data integrity check.
//
// Parameters:
//     Validation - CatalogRef.AccountingCheckRules - a check, whose parameters
//                need to be prepared.
//     CheckExecutionParameters - Structure
//                                 - Array - Custom additional check parameters that define the check procedure and object.
//                                    
//                                 - Structure - See AccountingAudit.CheckExecutionParameters.
//                                 - Array - 
//                                            
//
// Returns:
//   See AccountingAudit.IssueDetails.
//
Function PrepareCheckParameters(Val Validation, Val CheckExecutionParameters) Export
	
	CheckParameters = Common.ObjectAttributesValues(Validation, "CheckStartDate, Id,
		|ScheduledJobID, IssuesLimit, Description, IssueSeverity, RunMethod,
		|AccountingChecksContext, AccountingCheckContextClarification");
	
	If Not CheckParameters.Property("CheckWasStopped") Then
		CheckParameters.Insert("CheckWasStopped", False);
	EndIf;
	If Not CheckParameters.Property("ManualStart1") Then
		CheckParameters.Insert("ManualStart1", True);
	EndIf;
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks().Checks;
	AllCheckProperties  = AccountingChecks.Find(CheckParameters.Id, "Id");
	
	CheckParameters.Insert("Validation",            Validation);
	CheckParameters.Insert("GlobalSettings", GlobalSettings());
	CheckParameters.Insert("CheckIteration",    1);
	If AllCheckProperties <> Undefined Then
		CheckParameters.Insert("SupportsRandomCheck", AllCheckProperties.SupportsRandomCheck);
	EndIf;
	
	If CheckExecutionParameters = Undefined Then
		ChecksGroup = Common.ObjectAttributeValue(Validation, "Parent");
		If ChecksGroup <> Undefined And Not ChecksGroup.IsEmpty() Then
			CheckID = Common.ObjectAttributeValue(ChecksGroup, "Id");
		Else
			CheckID = CheckParameters.Id;
		EndIf;
		CheckExecutionParameters = New Array;
		CheckExecutionParameters.Add(CheckExecutionParameters(CheckID));
	EndIf;
	CheckParameters.Insert("CheckExecutionParameters", CheckExecutionParameters);
	
	Return CheckParameters;
	
EndFunction

// Updates auxiliary data that partially depends on the configuration.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges(Parameters = Undefined) Export
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Catalog.AccountingCheckRules");
		Block.Lock();
		
		UpdateCatalogAuxiliaryDataByConfigurationChanges();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

// See AccountingAudit.SummaryInformationOnChecksKinds.
Function SummaryInformationOnChecksKinds(ChecksKind, SearchByExactMap = True, ConsiderPersonResponsible = False) Export
	
	SummaryInformation = New Structure;
	SummaryInformation.Insert("Count", 0);
	SummaryInformation.Insert("HasErrors", False);
	
	If Not AccessRight("Read", Metadata.InformationRegisters.AccountingCheckResults) Then
		Return SummaryInformation;
	EndIf;
	
	ChecksKinds = New Array;
	
	If TypeOf(ChecksKind) = Type("CatalogRef.ChecksKinds") Then
		ChecksKinds.Add(ChecksKind);
	ElsIf TypeOf(ChecksKind) = Type("String") Then
		CheckExecutionParameters = CheckExecutionParameters(ChecksKind);
		ChecksKinds = ChecksKinds(CheckExecutionParameters, SearchByExactMap);
	ElsIf ChecksKind <> Undefined Then
		CheckExecutionParameters = CheckExecutionParametersFromArray(ChecksKind);
		ChecksKinds = ChecksKinds(CheckExecutionParameters, SearchByExactMap);
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(*) AS Count,
		|	ISNULL(MAX(CASE
		|				WHEN AccountingCheckResults.IssueSeverity = VALUE(Enum.AccountingIssueSeverity.Error)
		|					THEN TRUE
		|				ELSE FALSE
		|			END), FALSE) AS HasErrors
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.CheckRule.DeletionMark = FALSE
		|	AND NOT AccountingCheckResults.IgnoreIssue";
	If ChecksKind <> Undefined Then
		Query.Text = Query.Text + " AND AccountingCheckResults.CheckKind IN (&ChecksKinds)";
		Query.SetParameter("ChecksKinds", ChecksKinds);
	EndIf;
	If ConsiderPersonResponsible Then
		Query.Text = Query.Text + " AND AccountingCheckResults.EmployeeResponsible IN (&EmployeeResponsible)";
		EmployeeResponsible = New Array;
		EmployeeResponsible.Add(Catalogs.Users.EmptyRef());
		EmployeeResponsible.Add(Users.CurrentUser());
		Query.SetParameter("EmployeeResponsible", EmployeeResponsible);
	EndIf;
	Result = Query.Execute().Select();
	Result.Next();
	
	FillPropertyValues(SummaryInformation, Result);
	Return SummaryInformation;
	
EndFunction

// See AccountingAudit.DetailedInformationOnChecksKinds.
Function DetailedInformationOnChecksKinds(ChecksKind, SearchByExactMap = True) Export
	
	DetailedInformation        = New ValueTable;
	DetailedInformationColumns = DetailedInformation.Columns;
	DetailedInformationColumns.Add("ObjectWithIssue",         Common.AllRefsTypeDetails());
	DetailedInformationColumns.Add("IssueSeverity",         New TypeDescription("EnumRef.AccountingIssueSeverity"));
	DetailedInformationColumns.Add("CheckRule",          New TypeDescription("CatalogRef.AccountingCheckRules"));
	DetailedInformationColumns.Add("CheckKind",              New TypeDescription("CatalogRef.ChecksKinds"));
	DetailedInformationColumns.Add("IssueSummary",        New TypeDescription("String"));
	DetailedInformationColumns.Add("EmployeeResponsible",            New TypeDescription("CatalogRef.Users"));
	DetailedInformationColumns.Add("Detected",                 New TypeDescription("Date"));
	DetailedInformationColumns.Add("AdditionalInformation", New TypeDescription("ValueStorage"));
	
	ChecksKinds = New Array;
	
	If TypeOf(ChecksKind) = Type("CatalogRef.ChecksKinds") Then
		ChecksKinds.Add(ChecksKind);
	ElsIf TypeOf(ChecksKind) = Type("String") Then
		CheckExecutionParameters = CheckExecutionParameters(ChecksKind);
		ChecksKinds = ChecksKinds(CheckExecutionParameters, SearchByExactMap);
	Else
		CheckExecutionParameters = CheckExecutionParametersFromArray(ChecksKind);
		ChecksKinds = ChecksKinds(CheckExecutionParameters, SearchByExactMap);
	EndIf;
	
	If ChecksKinds.Count() = 0 Then
		Return DetailedInformation;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
	|	AccountingCheckResults.CheckRule AS CheckRule,
	|	AccountingCheckResults.IssueSeverity AS IssueSeverity,
	|	AccountingCheckResults.CheckKind AS CheckKind,
	|	AccountingCheckResults.IssueSummary AS IssueSummary,
	|	AccountingCheckResults.EmployeeResponsible AS EmployeeResponsible,
	|	AccountingCheckResults.Detected AS Detected,
	|	AccountingCheckResults.AdditionalInformation AS AdditionalInformation
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	AccountingCheckResults.CheckRule.DeletionMark = FALSE
	|	AND NOT AccountingCheckResults.IgnoreIssue
	|	AND AccountingCheckResults.CheckKind IN(&ChecksKinds)");
	
	Query.SetParameter("ChecksKinds", ChecksKinds);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		DetailedInformation = Result.Unload();
	EndIf;
	
	Return DetailedInformation;
	
EndFunction

// See AccountingAudit.ChecksKinds.
Function ChecksKinds(ChecksKind, SearchByExactMap = True) Export
	
	If TypeOf(ChecksKind) = Type("CatalogRef.ChecksKinds") Then
		Result = New Array;
		Result.Add(ChecksKind);
		Return Result;
	EndIf;
	
	If TypeOf(ChecksKind) = Type("String") Then
		CheckExecutionParameters = CheckExecutionParameters(ChecksKind);
	ElsIf TypeOf(ChecksKind) = Type("Array") Then
		CheckExecutionParameters = CheckExecutionParametersFromArray(ChecksKind);
	Else
		CheckExecutionParameters = ChecksKind;
	EndIf;
	
	If TypeOf(CheckExecutionParameters) = Type("Structure") Then
		Return CheckKindRegularSearch(CheckExecutionParameters, SearchByExactMap);
		
	ElsIf TypeOf(CheckExecutionParameters) = Type("Array") Then
		
		If CheckExecutionParameters.Count() > PropertiesCount() Then
			Return CheckKindExtendedSearch(CheckExecutionParameters, CheckExecutionParameters.Count());
		Else
			Return CheckKindRegularSearch(CheckExecutionParameters, SearchByExactMap);
		EndIf;
		
	EndIf;
	
	Return New Array;
	
EndFunction

// See AccountingAudit.CheckKind.
Function CheckKind(Val CheckExecutionParameters, Val SearchOnly = False) Export
	
	If TypeOf(CheckExecutionParameters) = Type("String") Then
		CheckExecutionParameters = CheckExecutionParameters(CheckExecutionParameters);
	EndIf;
	
	BeginTransaction();
	Try
		Block = ChecksKindsLock(CheckExecutionParameters);
		Block.Lock();
		
		If CheckExecutionParameters.Count() - 1 > PropertiesCount() Then
			CheckKindArray = CheckKindExtendedSearch(CheckExecutionParameters, PropertiesCount());
		Else
			CheckKindArray = CheckKindRegularSearch(CheckExecutionParameters);
		EndIf;
		
		If CheckKindArray.Count() = 0 Then
			If SearchOnly Then
				CheckKind = Catalogs.ChecksKinds.EmptyRef();
			Else
				CheckKind = NewCheckKind(CheckExecutionParameters);
			EndIf;
		Else
			CheckKind = CheckKindArray.Get(0);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return CheckKind;
	
EndFunction

// Searches for a check kind by the passed parameters. 
//
// Parameters:
//   CheckExecutionParameters - See AccountingAudit.CheckExecutionParameters.
//   PropertiesCount           - Number - a number of properties, by which the search is performed.
//
// Returns: 
//   CatalogRef.ChecksKinds - 
//
Function CheckKindExtendedSearch(CheckExecutionParameters, PropertiesCount)
	
	Query = New Query(
	"SELECT
	|	ChecksKinds.Ref AS CheckKind
	|INTO TT_ChecksKinds
	|FROM
	|	Catalog.ChecksKinds AS ChecksKinds
	|WHERE
	|	&Condition
	|
	|GROUP BY
	|	ChecksKinds.Ref
	|
	|HAVING
	|	COUNT(ChecksKinds.ObjectProperties.Ref) = &ThresholdValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TypesOfObjectPropertyChecks.Ref AS CheckKind,
	|	TypesOfObjectPropertyChecks.PropertyValue AS PropertyValue,
	|	TypesOfObjectPropertyChecks.PropertyName AS PropertyName
	|FROM
	|	TT_ChecksKinds AS TT_ChecksKinds
	|		INNER JOIN Catalog.ChecksKinds.ObjectProperties AS TypesOfObjectPropertyChecks
	|		ON TT_ChecksKinds.CheckKind = TypesOfObjectPropertyChecks.Ref
	|
	|ORDER BY
	|	CheckKind");
	
	ConditionsText           = " True ";
	ParametersCount   = CheckExecutionParameters.Count() - 1;
	Query.SetParameter("ThresholdValue", ParametersCount - PropertiesCount);
	
	For IndexOf = 1 To PropertiesCount Do
		
		Property  = "Property" + Format(IndexOf, "NG=0");
		Value  = CheckExecutionParameters[Property];
		
		ConditionsText = ConditionsText + " And " + Property + " = &" + Property;
		Query.SetParameter(Property, Value);
		
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "&Condition", ConditionsText);
	Result = Query.Execute().Unload();
	
	TransposedTable = New ValueTable;
	TableColumns1           = TransposedTable.Columns;
	TableColumns1.Add("CheckKind", New TypeDescription("CatalogRef.ChecksKinds"));
	
	TheStructureOfTheSearch = New Structure;
	SearchIndex    = "";
	
	For ThresholdIndex = PropertiesCount + 1 To ParametersCount Do
		
		ColumnName   = "Property" + Format(ThresholdIndex, "NG=0");
		SearchIndex = SearchIndex + ?(ValueIsFilled(SearchIndex), ", ", "") + ColumnName;
		TableColumns1.Add(ColumnName);
		
		TheStructureOfTheSearch.Insert(ColumnName, CheckExecutionParameters[ColumnName]);
		
	EndDo;
	
	CurrentCheckKind = Undefined;
	For Each ResultString1 In Result Do
		
		If CurrentCheckKind <> ResultString1.CheckKind Then
			
			CurrentCheckKind = ResultString1.CheckKind;
			NewRow = TransposedTable.Add();
			NewRow.CheckKind = CurrentCheckKind;
			
		EndIf;
		
		NewRow[ResultString1.PropertyName] = ResultString1.PropertyValue;
		
	EndDo;
	
	If TransposedTable.Count() > 1000 Then
		TransposedTable.Indexes.Add(SearchIndex);
	EndIf;
	
	FoundRows     = TransposedTable.FindRows(TheStructureOfTheSearch);
	ChecksKindsArray = New Array;
	For Each FoundRow In FoundRows Do
		ChecksKindsArray.Add(FoundRow.CheckKind);
	EndDo;
	
	Return ChecksKindsArray;
	
EndFunction

// In order to avoid conflicts when called from different scheduled jobs, locks 
// the CheckKinds catalog by the passed check execution parameters.
//
// Parameters:
//   CheckExecutionParameters - See AccountingAudit.CheckExecutionParameters.
//
// Returns:
//   DataLock  - 
//
Function ChecksKindsLock(CheckExecutionParameters)
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("Catalog.ChecksKinds");
	
	If CheckExecutionParameters.Count() - 1 > PropertiesCount() Then
		IndexOf = 1;
		For Each SearchParameter In CheckExecutionParameters Do
			DataLockItem.SetValue("Property" + Format(IndexOf, "NG=0"), SearchParameter.Value);
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
	
	Return DataLock;
	
EndFunction

// Searches for a check kind by the passed parameters. 
//
// Parameters:
//   CheckExecutionParameters - See AccountingAudit.CheckExecutionParameters.
//   SearchByExactMap - Boolean - If True, the search is conducted
//                                by the passed properties for equality, other properties must be equal
//                                Undefined (tabular section of additional properties has to be blank).
//                                If False, other property values can be arbitrary, the main thing is
//                                that the corresponding properties need to be equal to the structure properties. Default value is True.
//
// Returns: 
//   CatalogRef.ChecksKinds - 
//
Function CheckKindRegularSearch(CheckExecutionParameters, SearchByExactMap = True)
	
	Query = New Query(
	"SELECT
	|	ChecksKinds.Ref AS CheckKind
	|FROM
	|	Catalog.ChecksKinds AS ChecksKinds
	|WHERE
	|	&Condition
	|
	|GROUP BY
	|	ChecksKinds.Ref
	|
	|HAVING
	|	COUNT(ChecksKinds.ObjectProperties.Ref) = 0");
	
	ConditionsText         = " True ";
	ParametersCount = CheckExecutionParameters.Count() - 1;
	PropertiesCount    = PropertiesCount();
	
	For IndexOf = 1 To PropertiesCount Do
		
		Property = "Property" + Format(IndexOf, "NG=0");
		If IndexOf > ParametersCount Then
			If SearchByExactMap Then
				ConditionsText = ConditionsText + " And " + Property + " = Undefined";
			EndIf;
		Else
			Value     = CheckExecutionParameters[Property];
			
			ConditionsText = ConditionsText + " And " + Property + " = &" + Property;
			Query.SetParameter(Property, Value);
		EndIf;
		
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "&Condition", ConditionsText);
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("CheckKind");
	
EndFunction

// Creates a ChecksKinds catalog item based on the specified parameters.
//
// Parameters:
//   CheckExecutionParameters - See AccountingAudit.CheckExecutionParameters.
//
// Returns: 
//    CatalogRef.ChecksKinds - 
//
Function NewCheckKind(CheckExecutionParameters)
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks();
	ChecksGroups = AccountingChecks.ChecksGroups;
	ChecksGroup = ChecksGroups.Find(CheckExecutionParameters.Description, "Id");
	
	NewCheckKind = Catalogs.ChecksKinds.CreateItem();
	If ChecksGroup = Undefined Then
		NewCheckKind.Description = CheckExecutionParameters.Description;
	Else
		NewCheckKind.Description = ChecksGroup.Description;
	EndIf;
	PropertiesCount    = PropertiesCount();
	ParametersCount = CheckExecutionParameters.Count() - 1;
	
	If PropertiesCount > ParametersCount Then
		For IndexOf = 1 To ParametersCount Do
			PropertyName = "Property" + Format(IndexOf, "NG=0");
			NewCheckKind[PropertyName] = CheckExecutionParameters[PropertyName];
		EndDo;
	Else
		For IndexOf = 1 To ParametersCount Do
			PropertyName = "Property" + Format(IndexOf, "NG=0");
			If IndexOf <= PropertiesCount Then
				NewCheckKind[PropertyName] = CheckExecutionParameters[PropertyName];
			Else
				FillPropertyValues(NewCheckKind.ObjectProperties.Add(),
					New Structure("PropertyName, PropertyValue", PropertyName, CheckExecutionParameters[PropertyName]));
			EndIf;
		EndDo;
	EndIf;
	
	NewCheckKind.Write();
	
	Return NewCheckKind.Ref;
	
EndFunction

// The number of properties in the ChecksKinds catalog header.
// 
// Returns: 
//   Number - 
//
Function PropertiesCount()
	
	Return 5;
	
EndFunction

// See AccountingAuditOverridable.OnDefineSettings.
Function GlobalSettings() Export
	
	Settings = New Structure;
	Settings.Insert("IssuesIndicatorPicture",    PictureLib.Warning);
	Settings.Insert("IssuesIndicatorNote",   Undefined);
	Settings.Insert("IssuesIndicatorHyperlink", Undefined);
	
	AccountingAuditOverridable.OnDefineSettings(Settings);
	
	Return Settings;
	
EndFunction

// Returns an array of objects with issues. Maximum reduced to increase performance.
//
//  Parameters:
//    RowsKeys - Array - an array that contains all keys of the dynamic list rows.
//
// Returns:
//   Array of AnyRef - 
//
Function ObjectsWithIssues(RowsKeys, IncludingImportance = False) Export
	
	CurrentUserIsFullUser = Users.IsFullUser();
	
	Query = New Query(
	"SELECT DISTINCT
	|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
	|	MIN(AccountingCheckResults.IssueSeverity.Order) AS IssueOrder
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	AccountingCheckResults.ObjectWithIssue IN(&ListOfObjects)
	|	AND NOT AccountingCheckResults.IgnoreIssue
	|
	|GROUP BY
	|	AccountingCheckResults.ObjectWithIssue");
	Query.SetParameter("ListOfObjects", RowsKeys);
	
	If Not CurrentUserIsFullUser Then
		SetPrivilegedMode(True);
	EndIf;
	
	If IncludingImportance Then
		ObjectsWithIssues = Query.Execute().Unload();
	Else
		ObjectsWithIssues = Query.Execute().Unload().UnloadColumn("ObjectWithIssue");
	EndIf;
	
	If Not CurrentUserIsFullUser Then
		SetPrivilegedMode(False);
	EndIf;
	
	Return ObjectsWithIssues;
	
EndFunction

// See AccountingAudit.IssueDetails.
Function IssueDetails(ObjectWithIssue, CheckParameters) Export
	
	Result = New Structure;
	Result.Insert("ObjectWithIssue",         ObjectWithIssue);
	Result.Insert("CheckRule",          CheckParameters.Validation);
	Result.Insert("IssueSeverity",         CheckParameters.IssueSeverity);
	Result.Insert("IssueSummary",        "");
	Result.Insert("UniqueKey",         New UUID);
	Result.Insert("Detected",                 CurrentSessionDate());
	Result.Insert("AdditionalInformation", New ValueStorage(Undefined));
	Result.Insert("EmployeeResponsible",            Undefined);
	Result.Insert("CheckKind",              ?(CheckParameters.CheckExecutionParameters.Count() = 1,
		CheckKind(CheckParameters.CheckExecutionParameters[0]), Undefined));
	
	Return Result;
	
EndFunction

// See AccountingAudit.WriteIssue.
Procedure WriteIssue(CheckError, CheckParameters = Undefined) Export
	
	If CheckParameters <> Undefined And IsLastCheckIteration(CheckParameters) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CheckError.CheckKind) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Check kind is not specified when saving the issue for the ""%1"" check.';"), 
				CheckError.CheckRule);
	EndIf;
	
	ObjectsToExclude = AccountingAuditInternalCached.ObjectsToExcludeFromCheck();
	
	ObjectWithIssue = CheckError.ObjectWithIssue;
	MetadataObject = ObjectWithIssue.Metadata();
	
	If ObjectsToExclude.Find(MetadataObject.FullName()) <> Undefined Then
		Return;
	EndIf;
	
	AttributesCollection = MetadataObject.Attributes;
	
	AccountingAuditOverridable.BeforeWriteIssue(CheckError, ObjectWithIssue, AttributesCollection);
	
	CheckError.Insert("Checksum", IssueChecksum(CheckError));
	If ThisIssueIgnored(CheckError.Checksum) Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.AccountingCheckResults.CreateRecordSet();
	Filter = RecordSet.Filter;
	Filter.ObjectWithIssue.Set(ObjectWithIssue);
	Filter.CheckRule.Set(CheckError.CheckRule);
	Filter.CheckKind.Set(CheckError.CheckKind);
	Filter.UniqueKey.Set(CheckError.UniqueKey);
	
	NewRecord = RecordSet.Add();
	FillPropertyValues(NewRecord, CheckError);
	
	SetPrivilegedMode(True);
	RecordSet.Write();
	SetPrivilegedMode(False);
	
EndProcedure

// See AccountingAudit.IgnoreIssue.
Procedure IgnoreIssue(IssueDetails, Value) Export
	
	BeginTransaction();
	Try
		DataLock        = New DataLock;
		DataLockItem = DataLock.Add("InformationRegister.AccountingCheckResults");
		DataLockItem.SetValue("ObjectWithIssue", IssueDetails.ObjectWithIssue);
		DataLockItem.SetValue("CheckRule", IssueDetails.CheckRule);
		DataLockItem.SetValue("CheckKind", IssueDetails.CheckKind);
		DataLock.Lock();
		
		Checksum = IssueChecksum(IssueDetails);
		
		Query = New Query(
		"SELECT
		|	AccountingCheckResults.IgnoreIssue AS IgnoreIssue,
		|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
		|	AccountingCheckResults.CheckRule AS CheckRule,
		|	AccountingCheckResults.CheckKind AS CheckKind,
		|	AccountingCheckResults.AdditionalInformation AS AdditionalInformation
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.Checksum = &Checksum");
		
		Query.SetParameter("Checksum", Checksum);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			RollbackTransaction();
			Return;
		EndIf;
		
		PassedAddInfoChecksum = "";
		If IssueDetails.Property("AdditionalInformation") Then
			PassedAddInfoChecksum = Common.CheckSumString(IssueDetails.AdditionalInformation);
		EndIf;
		
		Selection = Result.Select();
		While Selection.Next() Do
			
			If ValueIsFilled(PassedAddInfoChecksum) Then
				
				FoundAddInfoChecksum  = Common.CheckSumString(Selection.AdditionalInformation);
				If FoundAddInfoChecksum <> PassedAddInfoChecksum Then
					Continue;
				EndIf;
				
			EndIf;
			
			If Selection.IgnoreIssue <> Value Then
				
				RecordSet = InformationRegisters.AccountingCheckResults.CreateRecordSet();
				RecordSet.Filter.ObjectWithIssue.Set(Selection.ObjectWithIssue);
				RecordSet.Filter.CheckRule.Set(Selection.CheckRule);
				RecordSet.Filter.CheckKind.Set(Selection.CheckKind);
				RecordSet.Read();
				
				Record = RecordSet.Get(0);
				Record.IgnoreIssue = Value;
				RecordSet.Write();
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns check parameters for the passed scheduled job ID.
//
// Parameters:
//  ScheduledJobID - String - a field to connect to the current background job.
//
// Returns:
//   Structure - 
//       * Id - String - Check string ID.
//
Function CheckByScheduledJobIDParameters(ScheduledJobID)
	
	Query = New Query(
	"SELECT TOP 1
	|	AccountingCheckRules.Id AS Id
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	AccountingCheckRules.ScheduledJobID = &ScheduledJobID
	|	AND AccountingCheckRules.Use");
	
	Query.SetParameter("ScheduledJobID", String(ScheduledJobID));
	Result = Query.Execute().Select();
	
	If Not Result.Next() Then
		Return Undefined;
	Else
		
		ReturnStructure = New Structure;
		ReturnStructure.Insert("Id", Result.Id);
		
		Return ReturnStructure;
		
	EndIf;
	
EndFunction

// Returns text and severity of the data integrity issue.
//
Function ObjectIssueInfo(ObjectReference) Export
	Query = New Query;
	Query.SetParameter("ObjectWithIssue", ObjectReference);
	Query.Text =
		"SELECT
		|	AccountingCheckResults.IssueSummary AS IssueText,
		|	AccountingCheckResults.IssueSeverity AS IssueSeverity
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.ObjectWithIssue = &ObjectWithIssue";
	Result = Query.Execute().Unload();
	
	InformationRecords = New Structure;
	InformationRecords.Insert("IssueText", "");
	InformationRecords.Insert("IssueSeverity", Undefined);
	
	If Result.Count() = 0 Then
		Return InformationRecords;
	EndIf;
	FillPropertyValues(InformationRecords, Result[0]);
	
	Return InformationRecords;
EndFunction

#Region ChecksCatalogUpdate

Function HasChangesOfAccountingChecksParameters() Export
	
	SetPrivilegedMode(True);
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccountingAudit.SystemChecks");
	Return LastChanges = Undefined Or LastChanges.Count() > 0;
	
EndFunction

Procedure AddChecksGroups(ChecksGroups)
	
	For Each ChecksGroup In ChecksGroups Do
		
		ChecksGroupByID = AccountingAudit.CheckByID(ChecksGroup.Id);
		
		If Not ValueIsFilled(ChecksGroupByID) Then
			ChecksGroupObject = Catalogs.AccountingCheckRules.CreateFolder();
		Else
			
			If ChecksGroupByID.AccountingCheckIsChanged Then
				Continue;
			EndIf;
			
			ChecksGroupObject = ChecksGroupByID.GetObject();
			If ChecksGroupByID.DeletionMark Then
				ChecksGroupObject.SetDeletionMark(False);
			EndIf;
			
		EndIf;
		
		FillPropertyValues(ChecksGroupObject, ChecksGroup);
		
		CheckGroupParent        = AccountingAudit.CheckByID(ChecksGroup.GroupID);
		ChecksGroupObject.Parent = CheckGroupParent;
		
		If ValueIsFilled(CheckGroupParent) Then
			ChecksGroupObject.AccountingChecksContext = Common.ObjectAttributeValue(CheckGroupParent, "AccountingChecksContext");
		Else
			ChecksGroupObject.AccountingChecksContext = ChecksGroup.AccountingChecksContext;
		EndIf;
		
		// ACC:1327-
		InfobaseUpdate.WriteData(ChecksGroupObject);
		// ACC:1327-
	EndDo;
	
	Query = New Query(
	"SELECT
	|	ChecksGroups.Id AS Id,
	|	ChecksGroups.Description AS Description
	|INTO TT_ChecksGroups
	|FROM
	|	&ChecksGroups AS ChecksGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingCheckRules.Ref AS Ref
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|		LEFT JOIN TT_ChecksGroups AS TT_ChecksGroups
	|		ON AccountingCheckRules.Id = TT_ChecksGroups.Id
	|WHERE
	|	TT_ChecksGroups.Description IS NULL
	|	AND AccountingCheckRules.IsFolder
	|	AND NOT AccountingCheckRules.Predefined
	|	AND NOT AccountingCheckRules.AccountingCheckIsChanged");
	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("ChecksGroups", ChecksGroups);
	
	// ACC:1327-off A lock is set upper in the stack.
	Result = Query.Execute().Select();
	// ACC:1327-on
	While Result.Next() Do
		ChecksGroupObject = Result.Ref.GetObject();
		ChecksGroupObject.SetDeletionMark(True);
	EndDo;
	
	Query.TempTablesManager.Close();
	
EndProcedure

Procedure AddChecks(Checks)
	
	For Each Validation In Checks Do
		
		CheckByID = AccountingAudit.CheckByID(Validation.Id);
		If Not ValueIsFilled(CheckByID) Then
			
			CheckObject1 = Catalogs.AccountingCheckRules.CreateItem();
			CheckObject1.RunMethod = Enums.CheckMethod.ByCommonSchedule;
			CheckObject1.IssueSeverity = Enums.AccountingIssueSeverity.Error;
			
		Else
			
			If CheckByID.AccountingCheckIsChanged Then
				Continue;
			EndIf;
			
			CheckObject1 = CheckByID.GetObject();
			If CheckByID.DeletionMark Then
				CheckObject1.SetDeletionMark(False);
			EndIf;
			
		EndIf;
		
		FillPropertyValues(CheckObject1, Validation);
		
		CheckParent1        = AccountingAudit.CheckByID(Validation.GroupID);
		CheckObject1.Parent = CheckParent1;
		
		If ValueIsFilled(CheckParent1) Then
			CheckObject1.AccountingChecksContext = Common.ObjectAttributeValue(CheckParent1, "AccountingChecksContext");
		Else
			CheckObject1.AccountingChecksContext = Validation.AccountingChecksContext;
		EndIf;
		
		CheckObject1.Use = Not Validation.isDisabled;
		
		If ValueIsFilled(Validation.IssuesLimit) Then
			CheckObject1.IssuesLimit = Validation.IssuesLimit;
		Else
			CheckObject1.IssuesLimit = 1000;
		EndIf;
		
		If ValueIsFilled(Validation.CheckStartDate) Then
			CheckObject1.CheckStartDate = Validation.CheckStartDate;
		EndIf;
		
		// ACC:1327-
		InfobaseUpdate.WriteData(CheckObject1);
		// ACC:1327-
	EndDo;
	
	Query = New Query(
	"SELECT
	|	Checks.Id AS Id,
	|	Checks.Description AS Description
	|INTO TT_Checks
	|FROM
	|	&Checks AS Checks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingCheckRules.Ref AS Ref
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|		LEFT JOIN TT_Checks AS TT_Checks
	|		ON AccountingCheckRules.Id = TT_Checks.Id
	|WHERE
	|	TT_Checks.Description IS NULL
	|	AND NOT AccountingCheckRules.IsFolder
	|	AND NOT AccountingCheckRules.Predefined
	|	AND NOT AccountingCheckRules.AccountingCheckIsChanged");
	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("Checks", Checks);
	
	// ACC:1327-off A lock is set upper in the stack.
	Result = Query.Execute().Select();
	// ACC:1327-on
	While Result.Next() Do
		CheckObject1 = Result.Ref.GetObject();
		CheckObject1.SetDeletionMark(True);
	EndDo;
	
	Query.TempTablesManager.Close();
	
EndProcedure

Procedure UpdateCatalogAuxiliaryDataByConfigurationChanges()
	
	SetPrivilegedMode(True);
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks();
	SpecifiedItemsUniquenessCheck(AccountingChecks.ChecksGroups, AccountingChecks.Checks);
	AddChecksGroups(AccountingChecks.ChecksGroups);
	AddChecks(AccountingChecks.Checks);
	
EndProcedure

Procedure SpecifiedItemsUniquenessCheck(ChecksGroups, Checks)
	
	Query = New Query(
	"SELECT
	|	Description AS Description,
	|	Id AS Id
	|INTO TT_ChecksGroups
	|FROM
	|	&ChecksGroups AS ChecksGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Description AS Description,
	|	Id AS Id
	|INTO TT_Checks
	|FROM
	|	&Checks AS Checks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ChecksGroups.Description AS Description,
	|	TT_ChecksGroups.Id AS Id
	|INTO TT_CommonTable
	|FROM
	|	TT_ChecksGroups AS TT_ChecksGroups
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Checks.Description,
	|	TT_Checks.Id
	|FROM
	|	TT_Checks AS TT_Checks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CommonTable.Id AS Id
	|INTO TTGroupByID
	|FROM
	|	TT_CommonTable AS TT_CommonTable
	|
	|GROUP BY
	|	TT_CommonTable.Id
	|
	|HAVING
	|	COUNT(TT_CommonTable.Id) > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CommonTable.Description AS Description,
	|	TT_CommonTable.Id AS Id
	|FROM
	|	TTGroupByID AS TTGroupByID
	|		INNER JOIN TT_CommonTable AS TT_CommonTable
	|		ON TTGroupByID.Id = TT_CommonTable.Id
	|
	|ORDER BY
	|	Id
	|TOTALS BY
	|	Id");
	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("ChecksGroups", ChecksGroups);
	Query.SetParameter("Checks",       Checks);
	
	ExceptionText = "";
	Result       = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While Result.Next() Do
		
		ExceptionText = ExceptionText + ?(ValueIsFilled(ExceptionText), Chars.LF, "")
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Duplicate ID: ""%1""';"), Result.Id);
			
		DetailedResult = Result.Select();
		While DetailedResult.Next() Do
			ExceptionText = ExceptionText + Chars.LF + "- " + DetailedResult.Description;
		EndDo;
		
	EndDo;
	
	Query.TempTablesManager.Close();
	
	If ValueIsFilled(ExceptionText) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'In %1 procedure, the following checks have identical IDs:
		|%2';"), "AccountingAuditOverridable.OnDefineChecks", ExceptionText);
	EndIf;
	
EndProcedure

Function ChecksChecksum()
	
	ChecksData = New Map;
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks();
	ChecksContent = New Array;
	
	For Each AccountingChecksItem In AccountingChecks Do
		
		ChecksItemValue = AccountingChecksItem.Value; // ValueTable
		ChecksItemColumns  = ChecksItemValue.Columns;
		
		For Each ChecksItemRow In ChecksItemValue Do
			
			CheckProperties = New Structure;
			For Each ChecksItemColumn In ChecksItemColumns Do
				CheckProperties.Insert(ChecksItemColumn.Name, ChecksItemRow[ChecksItemColumn.Name]);
			EndDo;
			If CheckProperties.Count() > 0 Then
				ChecksContent.Add(CheckProperties);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ChecksData.Insert(Common.CheckSumString(New FixedArray(ChecksContent)));
	Return New FixedMap(ChecksData);
	
EndFunction

#EndRegion

#Region ChecksToSupply

// Checks reference integrity.
//
Procedure CheckReferenceIntegrity(Validation, CheckParameters) Export
	
	CheckedRefs = New Map;
	
	CheckExecutionParameters = ReadParameters(CheckParameters.CheckExecutionParameters);
	If CheckExecutionParameters <> Undefined Then
		If CheckExecutionParameters.ValidationArea = "Registers" Then
			FindDeadRefsInRegisters(CheckExecutionParameters.MetadataObject, CheckParameters, CheckedRefs);
		Else
			FindDeadRefs(CheckExecutionParameters.MetadataObject, CheckParameters, CheckedRefs);
		EndIf;
		
		Return;
	EndIf;
	
	If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
		If TypeOf(CheckParameters.ObjectsToCheck) = Type("Array") Then
			MetadataObject = CheckParameters.ObjectsToCheck[0].Metadata();
		Else
			MetadataObject = CheckParameters.ObjectsToCheck.Metadata();
		EndIf;
		FindDeadRefs(MetadataObject, CheckParameters, CheckedRefs);
		Return;
	EndIf;
	
	ObjectsToExcludeFromCheck = AccountingAuditInternalCached.ObjectsToExcludeFromCheck();
	
	For Each MetadataKind In MetadataObjectsRefKinds() Do
		For Each MetadataObject In MetadataKind Do
			FullName = MetadataObject.FullName();
			If IsSharedMetadataObject(FullName) Then
				Continue;
			EndIf;
			If ObjectsToExcludeFromCheck.Find(FullName) <> Undefined Then
				Continue;
			EndIf;
			FindDeadRefs(MetadataObject, CheckParameters, CheckedRefs); // 
		EndDo;
	EndDo;
	
	For Each MetadataKind In RegistersAsMetadataObjects() Do
		For Each MetadataObject In MetadataKind Do
			FullName = MetadataObject.FullName();
			If IsSharedMetadataObject(FullName) Then
				Continue;
			EndIf;
			If ObjectsToExcludeFromCheck.Find(FullName) <> Undefined Then
				Continue;
			EndIf;
			FindDeadRefsInRegisters(MetadataObject, CheckParameters, CheckedRefs); // 
		EndDo;
	EndDo;
	
EndProcedure

// Checks filling of required attributes.
//
Procedure CheckUnfilledRequiredAttributes(Validation, CheckParameters) Export
	
	CheckExecutionParameters = ReadParameters(CheckParameters.CheckExecutionParameters);
	If CheckExecutionParameters <> Undefined Then
		If CheckExecutionParameters.ValidationArea = "Registers" Then
			
			MetadataObject = CheckExecutionParameters.MetadataObject; //  
			FindNotFilledRequiredAttributesInRegisters(MetadataObject, CheckParameters);
		Else
			FindNotFilledRequiredAttributes(CheckExecutionParameters.MetadataObject, CheckParameters);
		EndIf;
		
		Return;
	EndIf;
	
	If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
		If TypeOf(CheckParameters.ObjectsToCheck) = Type("Array") Then
			MetadataObject = CheckParameters.ObjectsToCheck[0].Metadata();
		Else
			MetadataObject = CheckParameters.ObjectsToCheck.Metadata();
		EndIf;
		FindNotFilledRequiredAttributes(MetadataObject, CheckParameters);
		Return;
	EndIf;
	
	ObjectsToExcludeFromCheck = AccountingAuditInternalCached.ObjectsToExcludeFromCheck();
	
	For Each MetadataKind In MetadataObjectsRefKinds() Do
		
		For Each MetadataObject In MetadataKind Do
			FullName = MetadataObject.FullName();
			If IsSharedMetadataObject(FullName) Then
				Continue;
			EndIf;
			If Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
				Continue;
			EndIf;
			If ObjectsToExcludeFromCheck.Find(FullName) <> Undefined
				 Or StrStartsWith(MetadataObject.Name, "Delete") Then
					Continue;
			EndIf;
			FindNotFilledRequiredAttributes(MetadataObject, CheckParameters); // 
		EndDo;
		
	EndDo;
	
	For Each MetadataKind In RegistersAsMetadataObjects() Do
		For Each MetadataObject In MetadataKind Do
			FullName = MetadataObject.FullName();
			If IsSharedMetadataObject(FullName) Then
				Continue;
			EndIf;
			If Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
				Continue;
			EndIf;
			If ObjectsToExcludeFromCheck.Find(FullName) <> Undefined
				 Or StrStartsWith(MetadataObject.Name, "Delete") Then
					Continue;
			EndIf;
			FindNotFilledRequiredAttributesInRegisters(MetadataObject, CheckParameters); // 
		EndDo;
	EndDo;
	
EndProcedure

// Performs a check for circular references.
//
Procedure CheckCircularRefs(Validation, CheckParameters) Export
	
	For Each MetadataKind In MetadataObjectsRefKinds() Do
		For Each MetadataObject In MetadataKind Do
			If IsSharedMetadataObject(MetadataObject.FullName()) Then
				Continue;
			EndIf;
			If Not HasHierarchy(MetadataObject.StandardAttributes) Then
				Continue;
			EndIf;
			FindCircularRefs(MetadataObject, CheckParameters); // 
		EndDo;
	EndDo;
	
EndProcedure

Procedure FixInfiniteLoopInBackgroundJob(Val CheckParameters, StorageAddress = Undefined) Export
	
	Validation = CheckByID(CheckParameters.CheckID);
	If Not ValueIsFilled(Validation) Then
		Return;
	EndIf;
	
	CorrectCircularRefsProblem(Validation);
	
EndProcedure

// Checks if there are missing predefined items.
//
Procedure CheckMissingPredefinedItems(Validation, CheckParameters) Export
	
	// Clearing the cache before calling the CommonClientServer.PredefinedItem function.
	RefreshReusableValues();
	
	MetadataObjectsKinds = New Array;
	MetadataObjectsKinds.Add(Metadata.Catalogs);
	MetadataObjectsKinds.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectsKinds.Add(Metadata.ChartsOfAccounts);
	MetadataObjectsKinds.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataKind In MetadataObjectsKinds Do
		For Each MetadataObject In MetadataKind Do
			If IsSharedMetadataObject(MetadataObject.FullName()) Then
				Continue;
			EndIf;
			If MetadataObject.PredefinedDataUpdate = Metadata.ObjectProperties.PredefinedDataUpdate.DontAutoUpdate Then
				Continue;
			EndIf;
			If StrStartsWith(MetadataObject.Name, "Delete") Then
				Continue;
			EndIf;
			FindMissingPredefinedItems(MetadataObject, CheckParameters); // 
		EndDo;
	EndDo;
	
EndProcedure

// Checks if there are duplicate predefined items.
//
Procedure CheckDuplicatePredefinedItems(Validation, CheckParameters) Export
	
	MetadataObjectsKinds = New Array;
	MetadataObjectsKinds.Add(Metadata.Catalogs);
	MetadataObjectsKinds.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectsKinds.Add(Metadata.ChartsOfAccounts);
	MetadataObjectsKinds.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataKind In MetadataObjectsKinds Do
		
		If MetadataKind.Count() = 0 Then
			Continue;
		EndIf;
		
		FindPredefinedItemsDuplicates(MetadataKind, CheckParameters); // 
		
	EndDo;
	
EndProcedure

// Checks if there are missing predefined exchange plan nodes.
//
Procedure CheckPredefinedExchangePlanNodeAvailability(Validation, CheckParameters) Export
	
	MetadataExchangePlans = Metadata.ExchangePlans;
	For Each MetadataExchangePlan In MetadataExchangePlans Do
		
		If IsSharedMetadataObject(MetadataExchangePlan.FullName()) Then
			Continue;
		EndIf;
		If ExchangePlans[MetadataExchangePlan.Name].ThisNode() <> Undefined Then
			Continue;
		EndIf;
		
		Issue1 = IssueDetails(Common.MetadataObjectID(MetadataExchangePlan.FullName()), CheckParameters); // @skip-
		Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Predefined node is missing from exchange plan ""%1"" (%2 = Undefined).';"), MetadataExchangePlan.Name, "ThisNode()");
		WriteIssue(Issue1, CheckParameters); // 
		
	EndDo;
	
EndProcedure

#EndRegion

#Region UserErrorsIndication

// Parameters:
//   Form                - ClientApplicationForm
//   NamesUniqueKey - String
//   GroupParentName    - String
//                        - Undefined
//   OutputAtBottom        - Boolean
//
Function PlaceErrorIndicatorGroup(Form, NamesUniqueKey, GroupParentName = Undefined, OutputAtBottom = False) Export
	
	FormAllItems = Form.Items;
	
	If GroupParentName = Undefined Then
		PlaceContext = Form;
	Else
		GroupParent = FormAllItems.Find(GroupParentName);
		If GroupParent = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The specified form group ""%1"" does not exist';"), GroupParentName);
		EndIf;
		PlaceContext = GroupParent;
	EndIf;
	
	ErrorIndicatorGroup = FormAllItems.Add("ErrorIndicatorGroup_" + NamesUniqueKey, Type("FormGroup"), PlaceContext); // FormTable
	ErrorIndicatorGroup.Type                      = FormGroupType.UsualGroup;
	ErrorIndicatorGroup.ShowTitle      = False;
	ErrorIndicatorGroup.Group              = ChildFormItemsGroup.AlwaysHorizontal;
	ErrorIndicatorGroup.HorizontalStretch = True;
	ErrorIndicatorGroup.BackColor                 = StyleColors.MasterFieldBackground;
	
	ContextSubordinateItems = PlaceContext.ChildItems;
	If OutputAtBottom Then
		FormAllItems.Move(ErrorIndicatorGroup, PlaceContext);
	Else
		If ContextSubordinateItems.Count() > 0 Then
			FormAllItems.Move(ErrorIndicatorGroup, PlaceContext, ContextSubordinateItems.Get(0));
		EndIf;
	EndIf;
	
	Return ErrorIndicatorGroup;
	
EndFunction

// Parameters:
//   Form - ClientApplicationForm
//   ErrorIndicatorGroup       - FormGroup
//   NamesUniqueKey         - String
//   IssuesIndicatorPicture - Picture
//                                - Undefined
//   MainRowIndicator         - FormattedString
//
Procedure FillErrorIndicatorGroup(Form, ErrorIndicatorGroup, NamesUniqueKey,
	MainRowIndicator, Settings) Export
	
	LastCheckDate     = Settings.LastCheckDate;
	ToolTip = NStr("en = '(As of %1)';");
	ToolTip = StringFunctionsClientServer.SubstituteParametersToString(ToolTip, LastCheckDate);
	
	ManagedFormItems = Form.Items;
	
	ErrorIndicatorPicture = ManagedFormItems.Add("PictureDecoration_" + NamesUniqueKey, Type("FormDecoration"), ErrorIndicatorGroup);
	ErrorIndicatorPicture.Type            = FormDecorationType.Picture;
	ErrorIndicatorPicture.Picture       = IssuePicture(Settings);
	ErrorIndicatorPicture.PictureSize = PictureSize.RealSize;
	
	LabelDecoration = ManagedFormItems.Add("LabelDecoration_" + NamesUniqueKey, Type("FormDecoration"), ErrorIndicatorGroup);
	LabelDecoration.Type                   = FormDecorationType.Label;
	LabelDecoration.Title             = MainRowIndicator;
	LabelDecoration.VerticalAlign = ItemVerticalAlign.Center;
	LabelDecoration.SetAction("URLProcessing", "Attachable_OpenIssuesReport");
	LabelDecoration.ToolTipRepresentation = ToolTipRepresentation.ShowRight;
	LabelDecoration.AutoMaxWidth = False;
	LabelDecoration.ExtendedTooltip.Title = ToolTip;
	LabelDecoration.ExtendedTooltip.Height = 1;
	
EndProcedure

// Generates a common string that indicates the existence of errors. It consists of an explanatory text and
// a hyperlink that opens the report on the object issues.
//
// Parameters:
//  ClientApplicationForm   - lientApplicationForm - an object form where the indicator group is placed.
//  ObjectReference               - AnyRef - a reference to the object, by which errors were found.
//  ObjectIssuesCount - Number - a quantity of the found object issues.
//  IssuesIndicatorNote - String, Undefined - a string that identifies issues that the current object has.
//                                 Can be overridden by the end developer - adding a parameter when calling is enough.
//  IssuesIndicatorHyperlink - String, Undefined - the string representing the hyperlink 
//                                 that opens and generates a report on the issues of the current object.
//
Function GenerateCommonStringIndicator(Form, ObjectReference, Settings) Export
	
	IssuesIndicatorNote   = Settings.IssuesIndicatorNote;
	IssuesIndicatorHyperlink = Settings.IssuesIndicatorHyperlink;
	IssuesCountByObject   = Settings.IssuesCount;
	TextRef = "Main";
	
	If Settings.DetailedKind And ValueIsFilled(Settings.IssueText) Then
		Return Settings.IssueText;
	EndIf;
	
	If IssuesIndicatorNote <> Undefined Then
		NoteLabel = IssuesIndicatorNote
	Else
		NoteLabel = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'In this %1';"), ObjectPresentationByType(ObjectReference));
	EndIf;
	
	If IssuesIndicatorHyperlink <> Undefined Then
		Hyperlink = IssuesIndicatorHyperlink;
	Else
		Hyperlink = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'issues found (%1)';"), Format(IssuesCountByObject, "NG=0"));
	EndIf;
	
	Return New FormattedString(NoteLabel + " ", New FormattedString(Hyperlink, , , , TextRef));
	
EndFunction

// See AccountingAuditOverridable.OnDetermineIndicationGroupParameters.
Procedure OnDetermineIndicationGroupParameters(IndicationGroupParameters, RefType) Export
	
	IndicationGroupParameters.Insert("GroupParentName", Undefined);
	IndicationGroupParameters.Insert("OutputAtBottom",     False);
	IndicationGroupParameters.Insert("DetailedKind",      True);
	
EndProcedure

// See AccountingAuditOverridable.OnDetermineIndicatiomColumnParameters.
Procedure OnDetermineIndicatiomColumnParameters(IndicationColumnParameters, FullName) Export
	
	IndicationColumnParameters.Insert("TitleLocation", FormItemTitleLocation.None);
	IndicationColumnParameters.Insert("Width",             2);
	IndicationColumnParameters.Insert("OutputLast",  False);
	
EndProcedure

#EndRegion

#Region ChecksExecute

// See AccountingAudit.ExecuteCheck.
Procedure ExecuteCheck(Validation, CheckExecutionParameters = Undefined, ObjectsToCheck = Undefined) Export
	
	If TypeOf(Validation) = Type("String") Then
		CheckToExecute = AccountingAudit.CheckByID(Validation);
	Else
		CheckToExecute = Validation;
	EndIf;
	
	If Not InfobaseUpdate.ObjectProcessed(CheckToExecute).Processed Then
		Return;
	EndIf;
	
	CheckExecutionParametersSpecified = CheckExecutionParameters <> Undefined;
	CheckParameters = PrepareCheckParameters(CheckToExecute, CheckExecutionParameters);
	If CheckRunning(CheckParameters.ScheduledJobID) Then
		Return;
	EndIf;
	
	If ValueIsFilled(ObjectsToCheck) And Not CheckParameters.SupportsRandomCheck Then
		Return;
	EndIf;
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks();
	Checks             = AccountingChecks.Checks;
	CheckString       = Checks.Find(CheckParameters.Id, "Id");
	If CheckString = Undefined Then 
		Return;
	EndIf;
		
	If CheckString.NoCheckHandler Then
		Return;
	EndIf;
	
	CheckParameters.Insert("ObjectsToCheck", ObjectsToCheck);
	
	LastCheckResult = Undefined;
	If ValueIsFilled(ObjectsToCheck) Then
		LastCheckResult = LastObjectCheckResult(CheckParameters);
	ElsIf Not CheckExecutionParametersSpecified Then
		ClearResultsBeforeExecuteCheck(CheckToExecute);
	EndIf;
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id);
	EndIf;
	
	SetAccountingCheckStatus(CheckToExecute);
	
	SessionParameters.AccountingIssuesCounter = 0;
	
	HandlerParameters = New Array;
	HandlerParameters.Add(CheckToExecute);
	HandlerParameters.Add(CheckParameters);
	Common.ExecuteConfigurationMethod(CheckString.HandlerChecks, HandlerParameters);
	
	If SessionParameters.AccountingIssuesCounter > 0
		And CheckParameters.IssueSeverity = Enums.AccountingIssueSeverity.Error Then
		Comment = NStr("en = 'Errors (%2) occurred while checking ""%1""';");
		Comment = StringFunctionsClientServer.SubstituteParametersToString(Comment,
			CheckParameters.Description, SessionParameters.AccountingIssuesCounter);
		WriteLogEvent(NStr("en = 'Data integrity';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			Comment);
		
		SessionParameters.AccountingIssuesCounter = 0;
	EndIf;
	
	If LastCheckResult <> Undefined Then
		DeleteLastCheckResults(LastCheckResult);
	EndIf;
	
	If ModulePerformanceMonitor <> Undefined Then
		ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, 0);
	EndIf;
	
EndProcedure

// To call from the AccountingAudit.AfterWriteAtServer procedure.
// Checks passed objects.
//
Procedure CheckObject(ObjectsToCheck, Checks) Export
	For Each Validation In Checks Do
		ExecuteCheck(Validation, , ObjectsToCheck); // 
	EndDo;
EndProcedure

// AccountingCheck scheduled job handler. Designed to process the background
// startup of application checks.
//
//   Parameters:
//       ScheduledJobID - String
//                                         - Undefined - 
//
Procedure CheckAccounting(ScheduledJobID = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.AccountingCheck);
	
	If ScheduledJobID <> Undefined Then
		
		CheckParameters = CheckByScheduledJobIDParameters(ScheduledJobID);
		If CheckParameters <> Undefined Then
			ExecuteCheck(CheckParameters.Id);
		EndIf;
		
	Else
		
		Query = New Query(
		"SELECT
		|	AccountingCheckRules.Id AS Id
		|FROM
		|	Catalog.AccountingCheckRules AS AccountingCheckRules
		|WHERE
		|	AccountingCheckRules.RunMethod = VALUE(Enum.CheckMethod.ByCommonSchedule)
		|	AND AccountingCheckRules.Use");
		
		Result = Query.Execute().Select();
		While Result.Next() Do
			ExecuteCheck(Result.Id); // 
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteChecks(Val Checks) Export
	
	For Each Validation In Checks Do
		ExecuteCheck(Validation); // 
	EndDo;
	
EndProcedure

// See AccountingAudit.CheckByID.
Function CheckByID(Id) Export
	
	Query = New Query(
	"SELECT TOP 1
	|	AccountingCheckRules.Ref AS Validation
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	AccountingCheckRules.Id = &Id
	|	AND NOT AccountingCheckRules.DeletionMark");
	
	Query.SetParameter("Id", Id);
	Result = Query.Execute().Select();
	
	If Not Result.Next() Then
		Return Catalogs.AccountingCheckRules.EmptyRef();
	Else
		Return Result.Validation;
	EndIf;
	
EndFunction

// See AccountingAudit.ExecuteChecksInContext.
Function ChecksByContext(AccountingChecksContext) Export
	
	Query = New Query(
	"SELECT
	|	""SelectionParentlessItemsConsideringContext"" AS QueryPurpose,
	|	VALUE(Catalog.AccountingCheckRules.EmptyRef) AS Parent,
	|	AccountingCheckRules.Ref AS Validation
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	NOT AccountingCheckRules.IsFolder
	|	AND AccountingCheckRules.Use
	|	AND AccountingCheckRules.Parent = VALUE(Catalog.AccountingCheckRules.EmptyRef)
	|	AND AccountingCheckRules.AccountingChecksContext = &AccountingChecksContext
	|
	|UNION ALL
	|
	|SELECT
	|	""SelectGroupsConsideringContext"",
	|	AccountingCheckRules.Parent,
	|	AccountingCheckRules.Ref
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	AccountingCheckRules.IsFolder
	|	AND AccountingCheckRules.AccountingChecksContext = &AccountingChecksContext
	|
	|UNION ALL
	|
	|SELECT
	|	""SelectionItemsWithParentsIgnoringContext"",
	|	AccountingCheckRules.Parent,
	|	AccountingCheckRules.Ref
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	NOT AccountingCheckRules.IsFolder
	|	AND AccountingCheckRules.Use
	|	AND AccountingCheckRules.Parent <> VALUE(Catalog.AccountingCheckRules.EmptyRef)");
	
	Query.SetParameter("AccountingChecksContext", AccountingChecksContext);
	AllChecks = Query.Execute().Unload();
	
	Result  = New Array;
	ParentChecks = AllChecks.Copy(AllChecks.FindRows(
		New Structure("QueryPurpose", "SelectGroupsConsideringContext")), "Parent, Validation");
	
	For Each ResultString1 In AllChecks Do
		
		If ResultString1.QueryPurpose = "SelectionParentlessItemsConsideringContext"
			Or (ResultString1.QueryPurpose = "SelectionItemsWithParentsIgnoringContext"
			And ParentChecks.Find(ResultString1.Parent) <> Undefined) Then
			Result.Add(ResultString1.Validation);
		EndIf;
		
	EndDo;
	
	Return CommonClientServer.CollapseArray(Result);
	
EndFunction

// See AccountingAudit.CheckExecutionParameters.
Function CheckExecutionParameters(Val Property1, Val Property2 = Undefined, Val Property3 = Undefined,
	Val Property4 = Undefined, Val Property5 = Undefined, Val AdditionalProperties = Undefined) Export
	
	PropertiesCount             = PropertiesCount();
	LastValuableParameterFound = False;
	
	For IndexOf = 2 To PropertiesCount Do
		If IndexOf = 2 Then
			ParameterValue = Property2;
		ElsIf IndexOf = 3 Then
			ParameterValue = Property3;
		ElsIf IndexOf = 4 Then
			ParameterValue = Property4;
		ElsIf IndexOf = 5 Then
			ParameterValue = Property5;
		EndIf;
		If ParameterValue = Undefined Then
			If Not LastValuableParameterFound Then
				LastValuableParameterFound = True;
			EndIf;
		Else
			If LastValuableParameterFound Then
				MessageText = NStr("en = 'The check parameters in %1 are not in correct order.';");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, "AccountingAudit.CheckExecutionParameters");
				Raise MessageText;
			EndIf;
		EndIf;
	EndDo;
	
	If AdditionalProperties <> Undefined And Property5 = Undefined Then
		MessageText = NStr("en = 'The check parameters in %1 are not in correct order.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, "AccountingAudit.CheckExecutionParameters");
		Raise MessageText;
	EndIf;
	
	AllParameters = New Array;
	AllParameters.Add(Property1);
	For IndexOf = 2 To PropertiesCount Do
		
		If IndexOf = 2 Then
			PropertyValue = Property2;
		ElsIf IndexOf = 3 Then
			PropertyValue = Property3;
		ElsIf IndexOf = 4 Then
			PropertyValue = Property4;
		ElsIf IndexOf = 5 Then
			PropertyValue = Property5;
		EndIf;
		If PropertyValue = Undefined Then
			Break;
		EndIf;
		AllParameters.Add(PropertyValue);
		
	EndDo;
	
	If AdditionalProperties <> Undefined Then
		CommonClientServer.SupplementArray(AllParameters, AdditionalProperties); 
	EndIf;
	
	Return CheckExecutionParametersFromArray(AllParameters);
	
EndFunction

Function CheckExecutionParametersFromArray(Val Parameters)
	
	CheckKindDescription = "";
	IndexOf = 1;
	Result = New Structure;
	
	For Each CurrentParameter In Parameters Do
		
		CommonClientServer.CheckParameter("AccountingAudit.CheckExecutionParameters", 
			"Property" + Format(IndexOf, "NG=0"), CurrentParameter, ExpectedPropertiesTypesOfChecksKinds());
			
		CheckKindDescription = CheckKindDescription + ?(ValueIsFilled(CheckKindDescription), ", ", "") 
			+ Format(CurrentParameter, "DLF=D; NG=0");
		Result.Insert("Property" + Format(Parameters.Find(CurrentParameter) + 1, "NG=0"), CurrentParameter);
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	Result.Insert("Description", CheckKindDescription);
	Return Result;

EndFunction

Procedure SetAccountingCheckStatus(Validation)
	
	SetPrivilegedMode(True);
	RecordManager = InformationRegisters.AccountingChecksStates.CreateRecordManager();
	RecordManager.Validation = Validation;
	RecordManager.LastRun = CurrentSessionDate();
	RecordManager.Write();
	
EndProcedure

#EndRegion

#Region RefIntegrityControl

Procedure FindDeadRefs(MetadataObject, CheckParameters, CheckedRefs)
	
	RefAttributes = ObjectRefAttributes(MetadataObject);
	If RefAttributes.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	HasRestrictionByDate = ValueIsFilled(CheckParameters.CheckStartDate) 
		And (Common.IsDocument(MetadataObject) Or Common.IsTask(MetadataObject) 
			Or Common.IsBusinessProcess(MetadataObject));
			
	If HasRestrictionByDate Then
		QueryText = 
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Ref AS ObjectWithIssue,
		|	&RefAttributes
		|	,&TabularSectionsAttributes
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	&Condition
		|	AND SpecifiedTableAlias.Date > &CheckStartDate
		|	AND NOT SpecifiedTableAlias.DeletionMark
		|
		|ORDER BY
		|	SpecifiedTableAlias.Ref";
		Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
	Else
		QueryText = 
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Ref AS ObjectWithIssue,
		|	&RefAttributes
		|	,&TabularSectionsAttributes
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	&Condition
		|	AND NOT SpecifiedTableAlias.DeletionMark
		|
		|ORDER BY
		|	SpecifiedTableAlias.Ref";
	EndIf;
	
	TableName = StrReplace(MetadataObject.FullName(), ".", "");
	If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
		Condition = TableName + ".Ref IN (&Ref)";
		Query.SetParameter("Ref", CheckParameters.ObjectsToCheck);
	Else
		Condition = TableName + ".Ref > &Ref";
		Query.SetParameter("Ref", "");
	EndIf;
	
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	QueryText = StrReplace(QueryText, "&Condition", Condition);
	QueryText = StrReplace(QueryText, "&MetadataObject", MetadataObject.FullName());
	QueryText = StrReplace(QueryText, "&RefAttributes", StrConcat(RefAttributes, ","));
	
	ObjectTabularSectionsAttributes = ObjectTabularSectionsRefAttributes(MetadataObject);
	If ObjectTabularSectionsAttributes.Count() > 0 Then
		Template = TableName + ".%1.(%2) AS %1";
		QueryTabularSections = "";
		For Each TabularSectionAttributes In ObjectTabularSectionsAttributes Do
			TabularSectionName    = TabularSectionAttributes.Key;
			AttributesString      = StrConcat(TabularSectionAttributes.Value, ",");
			FilledTemplate    = StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				TabularSectionName,
				AttributesString);
			
			If ValueIsFilled(QueryTabularSections) Then
				QueryTabularSections = QueryTabularSections + "," + Chars.LF + FilledTemplate;
			Else
				QueryTabularSections = FilledTemplate;
			EndIf;
		EndDo;
		QueryText = StrReplace(QueryText, "&TabularSectionsAttributes", QueryTabularSections);
	Else
		QueryText = StrReplace(QueryText, ",&TabularSectionsAttributes", "");
	EndIf;
	
	Query.Text = QueryText;
	Result = Query.Execute().Unload();
	
	MaxCount = MaxCheckedRefsCount();
	HasEmployeeResponsible = MetadataObject.Attributes.Find("EmployeeResponsible") <> Undefined;
	
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			IssueSummary = "";
			
			ObjectReference = ResultString1.ObjectWithIssue;
			For IndexOf = 1 To Result.Columns.Count() - 1 Do
				RefToCheck = ResultString1[IndexOf];
				If IsDeadRef(RefToCheck, CheckedRefs) Then
					IssueSummary = IssueSummary + ?(ValueIsFilled(IssueSummary), Chars.LF, "")
						+ StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The ""%2"" attribute of the ""%1"" object references an item that does not exist: ""%3"" (%4).';"), 
							ObjectReference, 
							Result.Columns[IndexOf].Name, 
							RefToCheck,
							TypeOf(RefToCheck));
				EndIf;
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
			IssuesLimit    = 1;
			MoreIssues      = 0;
			If ObjectTabularSectionsAttributes.Count() > 0 Then
				For Each TabularSectionAttributes In ObjectTabularSectionsAttributes Do
					
					ObjectTabularSection = ResultString1[TabularSectionAttributes.Key];// ValueTable
					CurrentRowNumber1    = 1;
					
					For Each TSRow In ObjectTabularSection Do
						For Each CurrentColumn In ObjectTabularSection.Columns Do
							TSAttributeName = CurrentColumn.Name;
							DataToCheck1 = TSRow[TSAttributeName];
							If IsDeadRef(DataToCheck1, CheckedRefs) Then
								If IssuesLimit = 0 Then
									MoreIssues = MoreIssues + 1;
									Continue;
								EndIf;
								IssueSummary = IssueSummary + ?(ValueIsFilled(IssueSummary), Chars.LF, "")
									+ StringFunctionsClientServer.SubstituteParametersToString(
										NStr("en = 'The ""%2"" attribute of the ""%3"" table (row #%4) in the ""%1"" object references an item that does not exist: ""%5"" (%6).';"),
										ObjectReference, TSAttributeName, StrReplace(TabularSectionAttributes.Key, TSAttributeName, ""), 
										CurrentRowNumber1, DataToCheck1, TypeOf(DataToCheck1));
								IssuesLimit = IssuesLimit - 1;
							EndIf;
						EndDo;
						CurrentRowNumber1 = CurrentRowNumber1 + 1;
					EndDo;
					
					If CheckedRefs.Count() >= MaxCount Then
						CheckedRefs.Clear();
					EndIf;
					
				EndDo;
			EndIf;
			
			If MoreIssues > 0 Then
				IssueSummary = IssueSummary + Chars.LF + NStr("en = 'More issues';") + ": " + String(MoreIssues);
			EndIf;
			
			If IsBlankString(IssueSummary) Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(ObjectReference, CheckParameters); // @skip-
			Issue1.IssueSummary = NStr("en = 'Reference integrity violation:';") + Chars.LF + IssueSummary;
			If HasEmployeeResponsible Then
				Issue1.EmployeeResponsible = Common.ObjectAttributeValue(ObjectReference, "EmployeeResponsible");
			EndIf;
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
			Break;
		EndIf;
		
		Query.SetParameter("Ref", ResultString1.ObjectWithIssue);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure


// Parameters:
//   MetadataObject - MetadataObject
// Returns:
//   Array of String
//
Function ObjectRefAttributes(MetadataObject)
	
	Result = New Array;
	
	StandardAttributesDetails = MetadataObject.StandardAttributes;// StandardAttributeDescriptions
	For Each StandardAttribute In StandardAttributesDetails Do
		If StandardAttribute.Name = "Ref" Or StandardAttribute.Name = "RoutePoint" Then
			Continue;
		EndIf;
		If Not ContainsRefType(StandardAttribute) Then
			Continue;
		EndIf;
		Result.Add(StandardAttribute.Name);
	EndDo;
	
	AttributesDetails1 = MetadataObject.Attributes;// Array of MetadataObjectAttribute
	For Each Attribute In AttributesDetails1 Do
		If ContainsRefType(Attribute) Then
			Result.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	If Common.IsTask(MetadataObject) Then
		
		AddressingAttributes = MetadataObject.AddressingAttributes;// Array of MetadataObjectAddressingAttribute
		For Each AddressingAttribute In AddressingAttributes Do
			If ContainsRefType(AddressingAttribute) Then
				Result.Add(AddressingAttribute.Name);
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function ObjectTabularSectionsRefAttributes(MetadataObject)
	
	Result = New Map;
	For Each TabularSection In MetadataObject.TabularSections Do
		Attributes = New Array;
		TabularSectionAttributesDetails = TabularSection.Attributes;// Array of MetadataObjectAttribute
		For Each TabularSectionAttribute In TabularSectionAttributesDetails Do
			If ContainsRefType(TabularSectionAttribute) Then
				If TabularSectionAttribute.Name = "RoutePoint" Then
					Continue;
				EndIf;
				Attributes.Add(TabularSectionAttribute.Name);
			EndIf;
		EndDo;
		Result.Insert(TabularSection.Name, Attributes);
	EndDo;
	
	Return Result;
	
EndFunction

Function IsDeadRef(DataToCheck1, CheckedRefs) 
	
	If Not ValueIsFilled(DataToCheck1) Then
		Return False;
	EndIf;
	
	IsDeadRef = CheckedRefs[DataToCheck1];
	If IsDeadRef = False Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("Number") Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("Boolean") Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("String") Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("Date") Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("UUID") Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("ValueStorage") Then
		Return False;
	EndIf;
	
	If Not Common.RefTypeValue(DataToCheck1) Then
		Return False;
	EndIf;
	
	If TypeOf(DataToCheck1) = Type("CatalogRef.MetadataObjectIDs")
		Or TypeOf(DataToCheck1) = Type("CatalogRef.ExtensionObjectIDs") Then
		Return False;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(DataToCheck1)) Then
		Return False;
	EndIf;
	
	If IsDeadRef = Undefined Then
		IsDeadRef = Not Common.RefExists(DataToCheck1);
		CheckedRefs[DataToCheck1] = IsDeadRef;
	EndIf;
	
	Return IsDeadRef;
	
EndFunction

Function MaxCheckedRefsCount()
	
	Return 100000;
	
EndFunction	

#Region RefIntegrityControlInRegisters

Procedure FindDeadRefsInRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	If MetadataObject.Dimensions.Count() = 0 Then
		Return;
	EndIf;
	
	If Common.IsAccumulationRegister(MetadataObject) Then
		FindDeadRefsInAccumulationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	ElsIf Common.IsInformationRegister(MetadataObject) Then
		FindDeadRefsInInformationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	ElsIf Common.IsAccountingRegister(MetadataObject) Then
		FindDeadRefsInAccountingRegisters(MetadataObject, CheckParameters, ExtDimensionTypes(MetadataObject), CheckedRefs);
	ElsIf Common.IsCalculationRegister(MetadataObject) Then
		FindDeadRefsInCalculationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	EndIf;
	
EndProcedure

Procedure FindDeadRefsInAccumulationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	
	FullName         = MetadataObject.FullName();
	RegisterAttributes1 = RegisterRefAttributes(MetadataObject);
	
	QueryText =
	"SELECT TOP 1000
	|	MetadataObject.Recorder AS RecorderAttributeRef,
	|	MetadataObject.Period AS Period
	|FROM
	|	&MetadataObject AS MetadataObject
	|WHERE
	|	MetadataObject.Period > &CheckStartDate
	|
	|GROUP BY
	|	MetadataObject.Period,
	|	MetadataObject.Recorder
	|
	|ORDER BY
	|	MetadataObject.Period";
	
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	
	Query = New Query(QueryText);
	Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
	Result = Query.Execute().Unload();
	
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();// InformationRegisterRecordSet
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			ProblemRecordsNumbers = "";
			For Each CurrentRecord In CurrentRecordSet Do
				For Each AttributeName In RegisterAttributes1 Do
					If IsDeadRef(CurrentRecord[AttributeName], CheckedRefs) Then
						ProblemRecordsNumbers = ProblemRecordsNumbers + ?(ValueIsFilled(ProblemRecordsNumbers), ", ", "")
							+ Format(CurrentRecordSet.IndexOf(CurrentRecord) + 1, "NG=0");
					EndIf;
				EndDo;
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
			If IsBlankString(ProblemRecordsNumbers) Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Records ""%2"" in recorder ""%3"" for accumulation register ""%1"" reference data that does not exist.';"),
				MetadataObject.Presentation(), ProblemRecordsNumbers, ResultString1.RecorderAttributeRef);
				
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		Query.SetParameter("CheckStartDate", ResultString1.Period);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

Procedure FindDeadRefsInInformationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	If MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
		FindDeadRefsInSubordinateInformationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	ElsIf MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		FindDeadRefsInIndependentPeriodicalInformationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	Else
		FindDeadRefsInIndependentNonPeriodicalInformationRegisters(MetadataObject, CheckParameters, CheckedRefs);
	EndIf;
	
EndProcedure

Procedure FindDeadRefsInSubordinateInformationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	FullName         = MetadataObject.FullName();
	RegisterAttributes1 = RegisterRefAttributes(MetadataObject);
	
	ThisRegisterPeriodical = MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical;
	If ThisRegisterPeriodical Then
		
		Query = New Query(
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef,
		|	SpecifiedTableAlias.Period AS Period
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Period > &CheckStartDate
		|
		|GROUP BY
		|	SpecifiedTableAlias.Period,
		|	SpecifiedTableAlias.Recorder
		|
		|ORDER BY
		|	SpecifiedTableAlias.Period");
		
		Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
		
	Else
		
		Query = New Query(
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Recorder > &Recorder
		|
		|GROUP BY
		|	SpecifiedTableAlias.Recorder
		|
		|ORDER BY
		|	SpecifiedTableAlias.Recorder");
		
		Query.SetParameter("Recorder", "");
		
	EndIf;
	
	TableName = StrReplace(FullName, ".", "");
	Query.Text = StrReplace(Query.Text, "SpecifiedTableAlias", TableName);
	Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName);
	Result    = Query.Execute().Unload();
	
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();// InformationRegisterRecordSet
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			ProblemRecordsNumbers = "";
			For Each CurrentRecord In CurrentRecordSet Do
				For Each AttributeName In RegisterAttributes1 Do
					If IsDeadRef(CurrentRecord[AttributeName], CheckedRefs) Then
						ProblemRecordsNumbers = ProblemRecordsNumbers + ?(ValueIsFilled(ProblemRecordsNumbers), ", ", "")
							+ Format(CurrentRecordSet.IndexOf(CurrentRecord) + 1, "NG=0");
					EndIf;
				EndDo;
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
			If IsBlankString(ProblemRecordsNumbers) Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Records ""%2"" in recorder ""%3"" for information register ""%1"" reference data that does not exist.';"),
				MetadataObject.Presentation(), ProblemRecordsNumbers, ResultString1.RecorderAttributeRef);
				
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		If ThisRegisterPeriodical Then
			Query.SetParameter("CheckStartDate", ResultString1.Period);
		Else
			Query.SetParameter("Recorder", ResultString1.RecorderAttributeRef);
		EndIf;
		
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

Procedure FindDeadRefsInIndependentPeriodicalInformationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	IndependentRegisterInformation = IndependentRegisterInformation(MetadataObject);
	SelectionFields1         = IndependentRegisterInformation.SelectionFields1;
	RegisterInformation = IndependentRegisterInformation.RegisterInformation;
	
	TableName = StrReplace(MetadataObject.FullName(), ".", "");
	ConditionByDimensions = "";
	OrderFields = TableName + "." + "Period";
	Dimensions          = MetadataObject.Dimensions;// Array of MetadataObjectDimension
	
	For Each Dimension In Dimensions Do
		ConditionByDimensions = ConditionByDimensions + ?(ValueIsFilled(ConditionByDimensions), " And ", "") + TableName + "." + Dimension.Name + " >= &" + Dimension.Name;
		OrderFields = OrderFields + ?(ValueIsFilled(OrderFields), ", ", "") + TableName + "." + Dimension.Name;
	EndDo;
	
	QueryText =
	"SELECT TOP 1000
	|	SpecifiedTableAlias.Period AS Period,
	|	&SelectionFields1 AS SelectionFields1
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	(SpecifiedTableAlias.Period > &Period
	|				AND NOT &OnlySpecifiedPeriod
	|			OR SpecifiedTableAlias.Period = &Period
	|				AND &OnlySpecifiedPeriod)
	|	AND &Condition
	|
	|ORDER BY
	|	&OrderFields";
	
	QueryText = StrReplace(QueryText, "&OrderFields", OrderFields);
	QueryText = StrReplace(QueryText, "&SelectionFields1 AS SelectionFields1", SelectionFields1);
	QueryText = StrReplace(QueryText, "&MetadataObject", MetadataObject.FullName());
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	
	FirstQueryText = StrReplace(QueryText, "&Condition", "True");
	QueryTextWithCondition = StrReplace(QueryText, "&Condition", ConditionByDimensions);
	
	Query = New Query(FirstQueryText);
	Query.SetParameter("Period", CheckParameters.CheckStartDate);
	Query.SetParameter("OnlySpecifiedPeriod", False);
	Result = Query.Execute().Unload();
	IsFirstPass = True;
	
	While Result.Count() > 0 Do
		
		// The last record is already checked at the previous iteration.
		If Not IsFirstPass And Result.Count() = 1 Then 
			Break;
		EndIf;
		
		For Each ResultString1 In Result Do
			
			If Not IsFirstPass And Result.IndexOf(ResultString1) = 0 Then
				Continue;
			EndIf;
			For Each AttributeInformation In RegisterInformation Do
				
				CurrentRef = ResultString1[AttributeInformation.NameOfMetadataObjects + AttributeInformation.MetadataTypeInNominativeCase + "Ref"];
				If Not IsDeadRef(CurrentRef, CheckedRefs) Then
					Continue;
				EndIf;
				
				AdditionalInformation = New Structure;
				AdditionalInformation.Insert("Period", ResultString1.Period);
				For Each Dimension In Dimensions Do
					DimensionRef = ResultString1[Dimension.Name + "DimensionRef"];
					AdditionalInformation.Insert(Dimension.Name, DimensionRef);
				EndDo;
				
				BrokenRef = ResultString1[AttributeInformation.NameOfMetadataObjects + AttributeInformation.MetadataTypeInNominativeCase + "Ref"];
				Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
				Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" information register in %2, the ""%3"" combination of dimensions, references an item that does not exist: ""%4"" (%5).';"),
					MetadataObject.Presentation(), AttributeInformation.MetadataTypeInInstrumentalCase,
					OrderFields, 
					BrokenRef,
					TypeOf(BrokenRef));
				Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
				WriteIssue(Issue1, CheckParameters); // 
				
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
		EndDo;
		
		If IsFirstPass Then
			IsFirstPass = False;
		EndIf;
		
		// 
		Query.Text = QueryTextWithCondition;
		Query.SetParameter("Period", ResultString1["Period"]);
		Query.SetParameter("OnlySpecifiedPeriod", True);
		For Each Dimension In Dimensions Do
			Query.SetParameter(Dimension.Name, ResultString1[Dimension.Name + "DimensionRef"]);
		EndDo;
		Result = Query.Execute().Unload(); // @skip-
		// 
		If Result.Count() = 0 Or Result.Count() = 1 Then
			Query.Text = FirstQueryText;
			Query.SetParameter("Period", ResultString1["Period"]);
			Query.SetParameter("OnlySpecifiedPeriod", False);
			Result = Query.Execute().Unload(); // @skip-
			IsFirstPass = True;
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//   MetadataObject - MetadataObjectInformationRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//   CheckedRefs - Map
//
Procedure FindDeadRefsInIndependentNonPeriodicalInformationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	IndependentRegisterInformation = IndependentRegisterInformation(MetadataObject);
	SelectionFields1         = IndependentRegisterInformation.SelectionFields1;
	RegisterInformation = IndependentRegisterInformation.RegisterInformation;
	
	TableName = StrReplace(MetadataObject.FullName(), ".", "");
	ConditionByDimensions = "";
	OrderFields  = "";
	
	DimensionsDetails = MetadataObject.Dimensions;
	For Each Dimension In DimensionsDetails Do
		ConditionByDimensions = ConditionByDimensions + ?(ValueIsFilled(ConditionByDimensions), " And ", "") + TableName + "." + Dimension.Name + " >= &" + Dimension.Name;
		OrderFields  = OrderFields + ?(ValueIsFilled(OrderFields), ", ", "") + TableName + "." + Dimension.Name;
	EndDo;
	
	QueryText =
	"SELECT TOP 1000
	|	&SelectionFields1 AS SelectionFields1
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	&Condition
	|
	|ORDER BY
	|	&OrderFields";
	
	QueryText = StrReplace(QueryText, "&OrderFields", OrderFields);
	QueryText = StrReplace(QueryText, "&SelectionFields1 AS SelectionFields1", SelectionFields1);
	QueryText = StrReplace(QueryText, "&MetadataObject", MetadataObject.FullName());
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	
	FirstQueryText   = StrReplace(QueryText, "&Condition", "True");
	QueryTextWithCondition = StrReplace(QueryText, "&Condition", ConditionByDimensions);
	
	Query = New Query(FirstQueryText);
	
	Result       = Query.Execute().Unload();
	IsFirstPass = True;
	
	While Result.Count() > 0 Do
		
		// The last record is already checked at the previous iteration.
		If Not IsFirstPass And Result.Count() = 1 Then
			Break;
		EndIf;
		
		For Each ResultString1 In Result Do
			
			If Not IsFirstPass And Result.IndexOf(ResultString1) = 0 Then
				Continue;
			EndIf;
			
			For Each AttributeInformation In RegisterInformation Do
				
				CurrentRef = ResultString1[AttributeInformation.NameOfMetadataObjects + AttributeInformation.MetadataTypeInNominativeCase + "Ref"];
				If Not IsDeadRef(CurrentRef, CheckedRefs) Then
					Continue;
				EndIf;
				
				AdditionalInformation = New Structure;
				For Each Dimension In DimensionsDetails Do
					DimensionRef = ResultString1[Dimension.Name + "DimensionRef"];
					AdditionalInformation.Insert(Dimension.Name, DimensionRef);
				EndDo;
				
				BrokenRef = ResultString1[AttributeInformation.NameOfMetadataObjects + AttributeInformation.MetadataTypeInNominativeCase + "Ref"];
				Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
				Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" information register in ""%2"", the ""%3"" combination of dimensions, references an item that does not exist: ""%4"" (%5).';"),
					MetadataObject.Presentation(), AttributeInformation.MetadataTypeInInstrumentalCase,
					OrderFields, 
					BrokenRef,
					TypeOf(BrokenRef));
				Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
				WriteIssue(Issue1, CheckParameters); // 
				
			EndDo;
			
		EndDo;
		
		If CheckedRefs.Count() >= MaxCount Then
			CheckedRefs.Clear();
		EndIf;
		
		If IsFirstPass Then
			IsFirstPass = False;
			Query.Text = QueryTextWithCondition;
		EndIf;
		
		For Each Dimension In DimensionsDetails Do
			Query.SetParameter(Dimension.Name, ResultString1[Dimension.Name + "DimensionRef"]);
		EndDo;
		
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

// Parameters:
//   MetadataObject - MetadataObjectAccountingRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//   ExtDimensionTypes - Array
//   CheckedRefs - Map
//
Procedure FindDeadRefsInAccountingRegisters(MetadataObject, CheckParameters, ExtDimensionTypes, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	FullName                      = MetadataObject.FullName();
	
	RefAttributes = New Array;
	
	If Not MetadataObject.Correspondence Then
		If MetadataObject.ChartOfAccounts <> Undefined Then
			RefAttributes.Add("Account");
		EndIf;
	Else
		RefAttributes.Add("AccountDr");
		RefAttributes.Add("AccountCr");
	EndIf;
		
	For Each Dimension In MetadataObject.Dimensions Do
		
		If Not ContainsRefType(Dimension) Then
			Continue;
		EndIf;
		
		If Dimension.Balance Or Not MetadataObject.Correspondence Then
			RefAttributes.Add(Dimension.Name);
		Else
			RefAttributes.Add(Dimension.Name + "Dr");
			RefAttributes.Add(Dimension.Name + "Cr");
		EndIf;
		
	EndDo;
	
	For Each Attribute In MetadataObject.Attributes Do
		If Not ContainsRefType(Attribute) Then
			Continue;
		EndIf;
		RefAttributes.Add(Attribute.Name);
	EndDo;
	
	Query = New Query(
	"SELECT
	|	MetadataObject.Recorder AS RecorderAttributeRef,
	|	MetadataObject.Period AS Period
	|FROM
	|	&MetadataObject AS MetadataObject
	|
	|GROUP BY
	|	MetadataObject.Period,
	|	MetadataObject.Recorder
	|
	|ORDER BY
	|	MetadataObject.Period");
	
	Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName + ".RecordsWithExtDimensions(, , Period > &CheckStartDate, , 1000)");
	Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
	Result = Query.Execute().Unload();
	
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			ProblemRecordsNumbers = "";
			For Each CurrentRecord In CurrentRecordSet Do
				
				ObjectsToCheck = New Array;
				
				For Each ExtDimensionType In ExtDimensionTypes Do
					If Not MetadataObject.Correspondence Then
						ObjectsToCheck.Add(CurrentRecord.ExtDimensions[ExtDimensionType]);
					Else
						ObjectsToCheck.Add(CurrentRecord.ExtDimensionsDr[ExtDimensionType]);
						ObjectsToCheck.Add(CurrentRecord.ExtDimensionsCr[ExtDimensionType]);
					EndIf;
				EndDo;
				
				For Each AttributeName In RefAttributes Do
					ObjectsToCheck.Add(CurrentRecord[AttributeName]);
				EndDo;
				
				For Each ObjectToCheck In ObjectsToCheck Do
					If IsDeadRef(ObjectToCheck, CheckedRefs) Then
						ProblemRecordsNumbers = ProblemRecordsNumbers + ?(ValueIsFilled(ProblemRecordsNumbers), ", ", "")
							+ Format(CurrentRecordSet.IndexOf(CurrentRecord) + 1, "NG=0");
					EndIf;	
				EndDo;
				
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
			If IsBlankString(ProblemRecordsNumbers) Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Records ""%2"" in recorder ""%3"" for accounting register ""%1"" reference data that does not exist.';"),
				MetadataObject.Presentation(), ProblemRecordsNumbers, ResultString1.RecorderAttributeRef);
				
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		Query.SetParameter("CheckStartDate", ResultString1.Period);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

// Parameters:
//   MetadataObject - MetadataObjectCalculationRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//   CheckedRefs - Map
//
Procedure FindDeadRefsInCalculationRegisters(MetadataObject, CheckParameters, CheckedRefs)
	
	MaxCount = MaxCheckedRefsCount();
	FullName         = MetadataObject.FullName();
	RegisterAttributes1 = RegisterRefAttributes(MetadataObject);
	
	Query = New Query(
	"SELECT TOP 1000
	|	MetadataObject.Recorder AS RecorderAttributeRef,
	|	MetadataObject.RegistrationPeriod AS Period
	|FROM
	|	&MetadataObject AS MetadataObject
	|WHERE
	|	MetadataObject.RegistrationPeriod > &CheckStartDate
	|
	|GROUP BY
	|	MetadataObject.RegistrationPeriod,
	|	MetadataObject.Recorder
	|
	|ORDER BY
	|	MetadataObject.RegistrationPeriod");
	
	Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName);
	Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
	Result = Query.Execute().Unload();
	
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			ProblemRecordsNumbers = "";
			For Each CurrentRecord In CurrentRecordSet Do
				For Each AttributeName In RegisterAttributes1 Do
					CurrentRef = CurrentRecord[AttributeName];
					If IsDeadRef(CurrentRef, CheckedRefs) Then
						ProblemRecordsNumbers = ProblemRecordsNumbers + ?(ValueIsFilled(ProblemRecordsNumbers), ", ", "")
							+ Format(CurrentRecordSet.IndexOf(CurrentRecord) + 1, "NG=0");
					EndIf;	
				EndDo;
			EndDo;
			
			If CheckedRefs.Count() >= MaxCount Then
				CheckedRefs.Clear();
			EndIf;
			
			If IsBlankString(ProblemRecordsNumbers) Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Records ""%2"" in recorder ""%3"" for calculation register ""%1"" reference data that does not exist.';"),
				MetadataObject.Presentation(), ProblemRecordsNumbers, ResultString1.RecorderAttributeRef);
				
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		Query.SetParameter("CheckStartDate", ResultString1.Period);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

Function RegisterRefAttributes(MetadataObject)
	
	Dimensions = MetadataObject.Dimensions;
	Attributes = MetadataObject.Attributes;
	
	Result = New Array;
	
	For Each Attribute In Attributes Do
		If ContainsRefType(Attribute) Then
			Result.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	If Common.IsCalculationRegister(MetadataObject) Then
		
		For Each Dimension In Dimensions Do
			If ContainsRefType(Dimension) Then
				Result.Add(Dimension.Name);
			EndIf;
		EndDo;
		
		StandardAttributes = MetadataObject.StandardAttributes;
		For Each StandardAttribute In StandardAttributes Do
			If StandardAttribute.Name = "Recorder" Or Not ContainsRefType(StandardAttribute) Then
				Continue;
			EndIf;
			Result.Add(StandardAttribute.Name);
		EndDo;
		
	ElsIf Common.IsInformationRegister(MetadataObject) Or Common.IsAccumulationRegister(MetadataObject) Then
		
		For Each Dimension In Dimensions Do
			If ContainsRefType(Dimension) Then
				Result.Add(Dimension.Name);
			EndIf;
		EndDo;
		
		Resources = MetadataObject.Resources;
		For Each Resource In Resources Do
			If ContainsRefType(Resource) Then
				Result.Add(Resource.Name);
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function ContainsRefType(Attribute)
	
	AttributeTypes = Attribute.Type.Types();
	For Each Current_Type In AttributeTypes Do
		If Common.IsReference(Current_Type) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ExtDimensionTypes(MetadataObject)
	
	If MetadataObject.ChartOfAccounts = Undefined Then
		Return New Array;
	EndIf;
	
	ExtDimensionTypesMetadataObject = MetadataObject.ChartOfAccounts.ExtDimensionTypes;
	If ExtDimensionTypesMetadataObject = Undefined Or Not ContainsRefType(ExtDimensionTypesMetadataObject) Then
		Return New Array;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ChartOfCharacteristicTypes.Ref AS ExtDimensionType
	|FROM
	|	&ChartOfCharacteristicTypes AS ChartOfCharacteristicTypes");
	
	Query.Text = StrReplace(Query.Text, "&ChartOfCharacteristicTypes", MetadataObject.ChartOfAccounts.ExtDimensionTypes.FullName());
	Return Query.Execute().Unload().UnloadColumn("ExtDimensionType");
	
EndFunction

Function IndependentRegisterInformation(MetadataObject, GetDimensions = True, GetResources = True, GetAttributes = True)
	
	RegisterInformation = New ValueTable;
	RegisterInformation.Columns.Add("MetadataTypeInNominativeCase", New TypeDescription("String", , , , New StringQualifiers(16)));
	RegisterInformation.Columns.Add("MetadataTypeInInstrumentalCase", New TypeDescription("String", , , , New StringQualifiers(16)));
	RegisterInformation.Columns.Add("NameOfMetadataObjects",                    New TypeDescription("String", , , , New StringQualifiers(128)));
	
	SelectionFields1 = "";
	
	If GetDimensions Then
		Dimensions = MetadataObject.Dimensions;
		For Each Dimension In Dimensions Do
			DimensionName = Dimension.Name;
			SelectionFields1  = SelectionFields1 + ?(ValueIsFilled(SelectionFields1), ",", "") 
				+ "SpecifiedTableAlias" + "." + DimensionName + " As " + DimensionName + "DimensionRef";
			FillPropertyValues(RegisterInformation.Add(),
				New Structure("MetadataTypeInNominativeCase, MetadataTypeInInstrumentalCase, NameOfMetadataObjects", 
					"Dimension", NStr("en = 'dimension';"), DimensionName));
		EndDo;
	EndIf;
	
	If GetResources Then
		Resources = MetadataObject.Resources;
		For Each Resource In Resources Do
			ResourceName  = Resource.Name;
			SelectionFields1 = SelectionFields1 + ?(ValueIsFilled(SelectionFields1), ",", "")
				+ "SpecifiedTableAlias" + "." + ResourceName + " As " + ResourceName + "ResourceRef";
			FillPropertyValues(RegisterInformation.Add(),
				New Structure("MetadataTypeInNominativeCase, MetadataTypeInInstrumentalCase, NameOfMetadataObjects", 
					"Resource", NStr("en = 'resource';"), ResourceName));
		EndDo;
	EndIf;
	
	If GetAttributes Then
		Attributes = MetadataObject.Attributes;
		For Each Attribute In Attributes Do
			AttributeName = Attribute.Name;
			SelectionFields1 = SelectionFields1 + ?(ValueIsFilled(SelectionFields1), ",", "")
				+ "SpecifiedTableAlias" + "." + AttributeName + " As " + AttributeName + "AttributeRef";
			FillPropertyValues(RegisterInformation.Add(),
				New Structure("MetadataTypeInNominativeCase, MetadataTypeInInstrumentalCase, NameOfMetadataObjects", 
					"Attribute", NStr("en = 'attribute';"), AttributeName));
		EndDo;
	EndIf;
		
	Return New Structure("RegisterInformation, SelectionFields1", RegisterInformation, SelectionFields1);
	
EndFunction

#EndRegion

#EndRegion

#Region CheckRequiredAttributesFilling


// Parameters:
//   MetadataObject - Arbitrary
//   CheckParameters - See AccountingAudit.IssueDetails
//
Procedure FindNotFilledRequiredAttributes(MetadataObject, CheckParameters)
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
	EndIf;
	
	FullName = MetadataObject.FullName();
	Attributes = MetadataObject.Attributes;
	
	Query = New Query;
	Query.SetParameter("Ref", "");
	
	QueryText = 
	"SELECT TOP 1000
	|	SpecifiedTableAlias.Ref AS ObjectWithIssue
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	&Condition
	|	AND NOT SpecifiedTableAlias.DeletionMark
	|
	|ORDER BY
	|	SpecifiedTableAlias.Ref";
	
	TableName = StrReplace(FullName, ".", "");
	If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
		Condition = TableName + ".Ref IN (&Ref)";
		Query.SetParameter("Ref", CheckParameters.ObjectsToCheck);
	Else
		Condition = TableName + ".Ref > &Ref";
		Query.SetParameter("Ref", "");
	EndIf;
	
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	QueryText = StrReplace(QueryText, "&Condition", Condition);
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	
	Query.Text = QueryText;
	Result = Query.Execute().Unload();
	
	DataCountTotal = 0;
	RestrictionByDate     = CheckParameters.CheckStartDate;
	While Result.Count() > 0 Do
		
		If ModulePerformanceMonitor <> Undefined Then
			MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id + "." + FullName);
		EndIf;
		
		For Each ResultString1 In Result Do
			
			ObjectReference = ResultString1.ObjectWithIssue;
			
			If ValueIsFilled(RestrictionByDate)
				And Common.IsDocument(MetadataObject)
				And Common.ObjectAttributeValue(ObjectReference, "Date") < RestrictionByDate Then
				Continue;
			EndIf;
			
			If Common.IsDocument(MetadataObject) And Not Common.ObjectAttributeValue(ObjectReference, "Posted") Then
				Continue;
			EndIf;
			
			If Common.IsExchangePlan(MetadataObject) And ObjectReference.ThisNode Then
				Continue;
			EndIf;
			
			ObjectToCheck = ObjectReference.GetObject();
			If ObjectToCheck.CheckFilling() Then
				Continue;
			EndIf;
			
			Issue1 = IssueDetails(ObjectReference, CheckParameters); // @skip-
			
			Issue1.IssueSummary = NStr("en = 'Attributes required:';") + Chars.LF + ObjectFillingErrors();
			If Attributes.Find("EmployeeResponsible") <> Undefined Then
				Issue1.Insert("EmployeeResponsible", Common.ObjectAttributeValue(ObjectReference, "EmployeeResponsible"));
			EndIf;
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		DataCountTotal = DataCountTotal + Result.Count();
		If ModulePerformanceMonitor <> Undefined Then
			ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, DataCountTotal);
		EndIf;
		
		If CheckParameters.Property("ObjectsToCheck") And CheckParameters.ObjectsToCheck <> Undefined Then
			Break;
		EndIf;
		
		Query.SetParameter("Ref", ResultString1.ObjectWithIssue);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

Procedure FindNotFilledRequiredAttributesInRegisters(MetadataObject, CheckParameters)
	
	If MetadataObject.Dimensions.Count() = 0 Then
		Return;
	EndIf;
	
	If Common.IsInformationRegister(MetadataObject) Then
		
		If MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
			If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
				FindNotFilledRequiredAttributesInSubordinatePeriodicalRegisters(MetadataObject, CheckParameters);
			Else
				FindNotFilledRequiredAttributesInSubordinateNonPeriodicalRegisters(MetadataObject, CheckParameters);
			EndIf;
		Else	
			If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
				FindNotFilledRequiredAttributesInIndependentPeriodicalInformationRegisters(MetadataObject, CheckParameters);
			Else
				FindNotFilledRequiredAttributesInIndependentNonPeriodicalInformationRegisters(MetadataObject, CheckParameters);
			EndIf;
		EndIf;
		
	ElsIf Common.IsAccumulationRegister(MetadataObject)
		Or Common.IsAccountingRegister(MetadataObject)
		Or Common.IsCalculationRegister(MetadataObject) Then
		
		FindNotFilledRequiredAttributesInSubordinateNonPeriodicalRegisters(MetadataObject, CheckParameters);
		
	EndIf;
	
EndProcedure

// Parameters:
//   MetadataObject - MetadataObjectAccountingRegister
//                    - Arbitrary
//                    - MetadataObjectInformationRegister
//                    - MetadataObjectAccumulationRegister
//                    - MetadataObjectCalculationRegister
//   CheckParameters - See AccountingAudit.IssueDetails 
//
Procedure FindNotFilledRequiredAttributesInSubordinatePeriodicalRegisters(MetadataObject, CheckParameters)
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
	EndIf;
	
	FullName = MetadataObject.FullName();
	TableName = StrReplace(FullName, ".", "");
	If Common.IsCalculationRegister(MetadataObject) Then
		
		Query = New Query(
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef,
		|	SpecifiedTableAlias.RegistrationPeriod AS Period
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.RegistrationPeriod > &CheckStartDate
		|
		|GROUP BY
		|	SpecifiedTableAlias.RegistrationPeriod,
		|	SpecifiedTableAlias.Recorder
		|
		|ORDER BY
		|	SpecifiedTableAlias.RegistrationPeriod");
		
		Query.Text = StrReplace(Query.Text, "SpecifiedTableAlias", TableName);
		Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName);
		Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
		
	ElsIf Common.IsAccountingRegister(MetadataObject) Then
		
		Query = New Query(
		"SELECT
		|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef,
		|	SpecifiedTableAlias.Period AS Period
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|
		|GROUP BY
		|	SpecifiedTableAlias.Period,
		|	SpecifiedTableAlias.Recorder
		|
		|ORDER BY
		|	SpecifiedTableAlias.Period");
		
		Query.Text = StrReplace(Query.Text, "SpecifiedTableAlias", TableName);
		Query.Text = StrReplace(Query.Text, "&MetadataObject", 
			FullName + ".RecordsWithExtDimensions(, , Period > &CheckStartDate AND Recorder > &Recorder, , 1000)");
		Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
		
	Else
		
		Query = New Query(
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef,
		|	SpecifiedTableAlias.Period AS Period
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Period > &CheckStartDate
		|
		|GROUP BY
		|	SpecifiedTableAlias.Period,
		|	SpecifiedTableAlias.Recorder
		|
		|ORDER BY
		|	SpecifiedTableAlias.Period");
		
		Query.Text = StrReplace(Query.Text, "SpecifiedTableAlias", TableName);
		Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName);
		Query.SetParameter("CheckStartDate", CheckParameters.CheckStartDate);
		
	EndIf;
	
	Result        = Query.Execute().Unload();
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	DataCountTotal = 0;
	
	While Result.Count() > 0 Do
		
		If ModulePerformanceMonitor <> Undefined Then
			MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id + "." + FullName);
		EndIf;
		
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			If CurrentRecordSet.CheckFilling() Then
				Continue;
			EndIf;
			
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error in record with the following fields:
				|%1
				|Some values are required: %2';"),
				" • " + NStr("en = 'Recorder:';") + " = """ + ResultString1.RecorderAttributeRef, Chars.LF + ObjectFillingErrors());
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		DataCountTotal = DataCountTotal + Result.Count();
		
		If ModulePerformanceMonitor <> Undefined Then
			ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, DataCountTotal);
		EndIf;
		
		Query.SetParameter("CheckStartDate", ResultString1.Period);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure


// Parameters:
//   MetadataObject - MetadataObjectAccountingRegister
//                    - Arbitrary
//                    - MetadataObjectInformationRegister
//                    - MetadataObjectAccumulationRegister
//                    - MetadataObjectCalculationRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//
Procedure FindNotFilledRequiredAttributesInSubordinateNonPeriodicalRegisters(MetadataObject, CheckParameters)
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
	EndIf;
	
	FullName = MetadataObject.FullName();
	
	Query = New Query(
	"SELECT TOP 1000
	|	SpecifiedTableAlias.Recorder AS RecorderAttributeRef
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Recorder > &Recorder
	|
	|GROUP BY
	|	SpecifiedTableAlias.Recorder
	|
	|ORDER BY
	|	SpecifiedTableAlias.Recorder");
	
	TableName = StrReplace(FullName, ".", "");
	Query.Text = StrReplace(Query.Text, "SpecifiedTableAlias", TableName);
	Query.Text = StrReplace(Query.Text, "&MetadataObject", FullName);
	Query.SetParameter("Recorder", "");
	
	Result        = Query.Execute().Unload();
	RegisterManager = Common.ObjectManagerByFullName(FullName);
	
	DataCountTotal = 0;
	While Result.Count() > 0 Do
		
		If ModulePerformanceMonitor <> Undefined Then
			MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id + "." + FullName);
		EndIf;
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();
			CurrentRecordSet.Filter.Recorder.Set(ResultString1.RecorderAttributeRef);
			CurrentRecordSet.Read();
			
			If CurrentRecordSet.CheckFilling() Then
				Continue;
			EndIf;
			
			AdditionalInformation = New Structure;
			AdditionalInformation.Insert("Recorder", ResultString1.RecorderAttributeRef);
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			
			Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error in record with the following fields:
				|%1
				|Some values are required: %2';"),
				" • " + NStr("en = 'Recorder:';") + " = """ + ResultString1.RecorderAttributeRef, Chars.LF + ObjectFillingErrors());
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		DataCountTotal = DataCountTotal + Result.Count();
		If ModulePerformanceMonitor <> Undefined Then
			ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, DataCountTotal);
		EndIf;
		
		Query.SetParameter("Recorder", ResultString1.RecorderAttributeRef);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure


// Parameters:
//   MetadataObject - MetadataObjectAccountingRegister
//                    - Arbitrary
//                    - MetadataObjectInformationRegister
//                    - MetadataObjectAccumulationRegister
//                    - MetadataObjectCalculationRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//
Procedure FindNotFilledRequiredAttributesInIndependentNonPeriodicalInformationRegisters(MetadataObject, CheckParameters)
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
	EndIf;
	
	FullName           = MetadataObject.FullName();
	RegisterManager    = Common.ObjectManagerByFullName(FullName);
	ConditionByDimensions = "";
	OrderFields  = "";
	Dimensions           = MetadataObject.Dimensions;
	
	HasRequiredAttributes = HasRequiredAttributes(MetadataObject);
	If Not HasRequiredAttributes Then
		Return;
	EndIf;
	
	TableName = StrReplace(FullName, ".", "");
	
	For Each Dimension In Dimensions Do
		ConditionByDimensions = ConditionByDimensions + ?(ValueIsFilled(ConditionByDimensions), " And ", "") + TableName + "." + Dimension.Name + " >= &" + Dimension.Name;
		OrderFields  = OrderFields + ?(ValueIsFilled(OrderFields), ", ", "") + TableName + "." + Dimension.Name;
	EndDo;
	
	SelectionFields1 = IndependentRegisterInformation(MetadataObject, True, False, False).SelectionFields1;
	
	QueryText =
	"SELECT TOP 1000
	|	&SelectionFields1 AS SelectionFields1
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	&Condition
	|
	|ORDER BY
	|	&OrderFields";
	
	QueryText = StrReplace(QueryText, "&OrderFields", OrderFields);
	QueryText = StrReplace(QueryText, "&SelectionFields1 AS SelectionFields1", SelectionFields1);
	QueryText = StrReplace(QueryText, "&MetadataObject", MetadataObject.FullName());
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	
	FirstQueryText   = StrReplace(QueryText, "&Condition", "True");
	QueryTextWithCondition = StrReplace(QueryText, "&Condition", ConditionByDimensions);
	
	Query = New Query(FirstQueryText);
	Result = Query.Execute().Unload();
	
	IsFirstPass = True;
	DataCountTotal = 0;
	While Result.Count() > 0 Do
		
		// The last record is already checked at the previous iteration.
		If Not IsFirstPass And Result.Count() = 1 Then
			Break;
		EndIf;
		
		If ModulePerformanceMonitor <> Undefined Then
			MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id + "." + FullName);
		EndIf;
		
		For Each ResultString1 In Result Do
			
			If Not IsFirstPass And Result.IndexOf(ResultString1) = 0 Then
				Continue;
			EndIf;
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();// InformationRegisterRecordSet
			CurrentSetFilter = CurrentRecordSet.Filter;
			
			RecordSetFilterPresentation = "";
			For Each Dimension In Dimensions Do
				
				DimensionName      = Dimension.Name;
				DimensionValue = ResultString1[DimensionName + "DimensionRef"];
				If Not ValueIsFilled(DimensionValue) Then
					Continue;
				EndIf;
				
				FilterByDimension = CurrentSetFilter[DimensionName];// FilterItem
				FilterByDimension.Set(DimensionValue);
				
				RecordSetFilterPresentation = RecordSetFilterPresentation + ?(ValueIsFilled(RecordSetFilterPresentation), Chars.LF, "")
					+ " • " + DimensionName + " = """ + ResultString1[DimensionName + "DimensionRef"] + """";
				
			EndDo;
			CurrentRecordSet.Read();
			
			If CurrentRecordSet.CheckFilling() Then
				Continue;
			EndIf;
			
			AdditionalInformation = New Structure;
			For Each Dimension In Dimensions Do
				DimensionRef = ResultString1[Dimension.Name + "DimensionRef"];
				AdditionalInformation.Insert(Dimension.Name, DimensionRef);
			EndDo;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			
			Issue1.IssueSummary        = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error in record with the following fields:
				|%1
				|Some values are required: %2';"), RecordSetFilterPresentation, Chars.LF + ObjectFillingErrors());
			Issue1.AdditionalInformation = New ValueStorage(AdditionalInformation);
			
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		If IsFirstPass Then
			IsFirstPass = False;
			Query.Text = QueryTextWithCondition;
		EndIf;
		
		For Each Dimension In Dimensions Do
			Query.SetParameter(Dimension.Name, ResultString1[Dimension.Name + "DimensionRef"]);
		EndDo;
		
		DataCountTotal = DataCountTotal + Result.Count();
		If ModulePerformanceMonitor <> Undefined Then
			ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, DataCountTotal);
		EndIf;
		
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

// Parameters:
//   MetadataObject - MetadataObjectAccountingRegister
//                    - Arbitrary
//                    - MetadataObjectInformationRegister
//                    - MetadataObjectAccumulationRegister
//                    - MetadataObjectCalculationRegister
//   CheckParameters - See AccountingAudit.IssueDetails
//
Procedure FindNotFilledRequiredAttributesInIndependentPeriodicalInformationRegisters(MetadataObject, CheckParameters)
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
	EndIf;
	
	FullName          = MetadataObject.FullName();
	TableName         = StrReplace(FullName, ".", "");
	RegisterManager   = Common.ObjectManagerByFullName(FullName);
	ConditionByDimensions = "";
	OrderFields = TableName + "." + "Period";
	Dimensions          = MetadataObject.Dimensions;
	
	For Each Dimension In Dimensions Do
		ConditionByDimensions = ConditionByDimensions + ?(ValueIsFilled(ConditionByDimensions), " And ", "") + TableName + "." + Dimension.Name + " >= &" + Dimension.Name;
		OrderFields = OrderFields + ?(ValueIsFilled(OrderFields), ", ", "") + TableName + "." + Dimension.Name;
	EndDo;
	
	SelectionFields1 = IndependentRegisterInformation(MetadataObject, True, False, False).SelectionFields1;
	
	QueryText =
		"SELECT TOP 1000
		|	SpecifiedTableAlias.Period AS Period,
		|	&SelectionFields1 AS SelectionFields1
		|FROM
		|	&MetadataObject AS SpecifiedTableAlias
		|WHERE
		|	(SpecifiedTableAlias.Period > &Period
		|				AND NOT &OnlySpecifiedPeriod
		|			OR SpecifiedTableAlias.Period = &Period
		|				AND &OnlySpecifiedPeriod)
		|	AND &Condition
		|ORDER BY &OrderFields";
	
	QueryText = StrReplace(QueryText, "&OrderFields", OrderFields);
	QueryText = StrReplace(QueryText, "&SelectionFields1 AS SelectionFields1", SelectionFields1);
	QueryText = StrReplace(QueryText, "&MetadataObject", MetadataObject.FullName());
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	
	FirstQueryText = StrReplace(QueryText, "&Condition", "True");
	QueryTextWithCondition = StrReplace(QueryText, "&Condition", ConditionByDimensions);
	
	Query = New Query(FirstQueryText);
	Query.SetParameter("Period", CheckParameters.CheckStartDate);
	Query.SetParameter("OnlySpecifiedPeriod", False);
	
	Result = Query.Execute().Unload();
	IsFirstPass = True;
	
	DataCountTotal = Result.Count();
	While Result.Count() > 0 Do
		
		// The last record is already checked at the previous iteration.
		If Not IsFirstPass And Result.Count() = 1 Then
			Break;
		EndIf;
		//
		If ModulePerformanceMonitor <> Undefined Then
			MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(CheckParameters.Id + "." + FullName);
		EndIf;
		//
		For Each ResultString1 In Result Do
			
			CurrentRecordSet = RegisterManager.CreateRecordSet();
			CurrentSetFilter = CurrentRecordSet.Filter;
			
			RecordSetFilterPresentation = StringFunctionsClientServer.SubstituteParametersToString(" • %1 = ""%2""",
				NStr("en = 'Period';"), ResultString1.Period);
			For Each Dimension In Dimensions Do
				
				DimensionName      = Dimension.Name;
				DimensionValue = ResultString1[DimensionName + "DimensionRef"];
				If Not ValueIsFilled(DimensionValue) Then
					Continue;
				EndIf;
				
				FilterByDimension = CurrentSetFilter[DimensionName];// FilterItem
				FilterByDimension.Set(DimensionValue);
				
				RecordSetFilterPresentation = RecordSetFilterPresentation + Chars.LF
					+ " • " + DimensionName + " = """ + ResultString1[DimensionName + "DimensionRef"] + """";
				
			EndDo;
			CurrentRecordSet.Read();
			
			If CurrentRecordSet.CheckFilling() Then
				Continue;
			EndIf;
			
			IssueSummary = ObjectFillingErrors();
			
			RecordSetStructure = New Structure;
			RecordSetStructure.Insert("Period", ResultString1.Period);
			For Each Dimension In Dimensions Do
				DimensionRef = ResultString1[Dimension.Name + "DimensionRef"];
				RecordSetStructure.Insert(Dimension.Name, DimensionRef);
			EndDo;
			
			Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
			
			Issue1.IssueSummary        = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error in record with the following fields:
				|%1
				|Some values are required: %2';"), RecordSetFilterPresentation, Chars.LF + IssueSummary);
			Issue1.AdditionalInformation = New ValueStorage(RecordSetStructure);
			WriteIssue(Issue1, CheckParameters); // 
			
		EndDo;
		
		If IsFirstPass Then
			IsFirstPass = False;
		EndIf;
		
		// 
		Query.Text = QueryTextWithCondition;
		Query.SetParameter("Period", ResultString1.Period);
		Query.SetParameter("OnlySpecifiedPeriod", True);
		For Each Dimension In Dimensions Do
			Query.SetParameter(Dimension.Name, ResultString1[Dimension.Name + "DimensionRef"]);
		EndDo;
		Result = Query.Execute().Unload(); // @skip-
		// 
		If Result.Count() = 0 Or Result.Count() = 1 Then
			Query.Text = FirstQueryText;
			Query.SetParameter("Period", ResultString1.Period);
			Query.SetParameter("OnlySpecifiedPeriod", False);
			Result = Query.Execute().Unload(); // @skip-
			IsFirstPass = True;
		EndIf;
		
		DataCountTotal = DataCountTotal + Result.Count();
		If ModulePerformanceMonitor <> Undefined Then
			ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, DataCountTotal);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region CheckCircularRefs1

Procedure FindCircularRefs(MetadataObject, CheckParameters)
	
	FullName = MetadataObject.FullName();
	Attributes = MetadataObject.Attributes;
	
	QueryText = 
	"SELECT TOP 1000
	|	SpecifiedTableAlias.Ref AS ObjectWithIssue,
	|	REFPRESENTATION(SpecifiedTableAlias.Ref) AS Presentation,
	|	SpecifiedTableAlias.Parent AS Parent
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref > &Ref
	|
	|ORDER BY
	|	SpecifiedTableAlias.Ref";
	
	TableName = StrReplace(MetadataObject.FullName(), ".", "");
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", "");
	
	Result = Query.Execute().Unload();
	
	CheckedItems = New Map;
	While Result.Count() > 0 Do
		
		For Each ResultString1 In Result Do
			
			ObjectReference = ResultString1.ObjectWithIssue;
			If CheckedItems[ObjectReference] <> Undefined Then
				Continue;
			EndIf;
			
			ItemsToCheck = New Array;
			If CheckLevelsLooping(ObjectReference, ResultString1.Parent, ItemsToCheck) Then
				
				Path = "";
				For Each LoopItem In ItemsToCheck Do
					Path = Path + ?(ValueIsFilled(Path), " -> ", "") + String(LoopItem);
					CheckedItems[LoopItem] = True;
				EndDo;
				
				ObjectPresentation = ResultString1.Presentation;
				If ValueIsFilled(Path) Then
					IssueSummary = ObjectPresentation + " -> " + Path + " -> " + ObjectPresentation;
				Else
					IssueSummary = ObjectPresentation + " -> " + ObjectPresentation;
				EndIf;
				
				Issue1 = IssueDetails(ObjectReference, CheckParameters); // @skip-
				
				Issue1.IssueSummary = IssueSummary;
				If Attributes.Find("EmployeeResponsible") <> Undefined Then
					Issue1.Insert("EmployeeResponsible", Common.ObjectAttributeValue(ObjectReference, "EmployeeResponsible"));
				EndIf;
				
				WriteIssue(Issue1, CheckParameters); // 
				
			EndIf;
			
		EndDo;
		
		Query.SetParameter("Ref", ResultString1.ObjectWithIssue);
		Result = Query.Execute().Unload(); // @skip-
		
	EndDo;
	
EndProcedure

Function CheckLevelsLooping(Val ObjectReference, Val CurrentParent, Val AllItems)
	
	While ValueIsFilled(CurrentParent) Do
		If ObjectReference = CurrentParent Then
			Return True;
		EndIf;
		AllItems.Add(CurrentParent);
		CurrentParent = Common.ObjectAttributeValue(CurrentParent, "Parent");
	EndDo;
	Return False;
	
EndFunction

// Parameters:
//   StandardAttributes - StandardAttributeDescriptions
// Returns:
//   Boolean
//
Function HasHierarchy(StandardAttributes)
	
	HasHierarchy = False;
	For Each StandardAttribute In StandardAttributes Do
		If StandardAttribute.Name = "Parent" Then
			HasHierarchy = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasHierarchy;
	
EndFunction

// Corrects circular references as follows: the one that has more terminal subordinate items 
// remains a parent.
//
// Parameters:
//   Validation - CatalogRef.AccountingCheckRules - a check, whose found issues are corrected
//              using this method.
//
Procedure CorrectCircularRefsProblem(Validation)
	
	DescendantsTable = New ValueTable;
	DescendantsTable.Columns.Add("LoopItem");
	DescendantsTable.Columns.Add("ChildrenCount", New TypeDescription("Number"));
	
	Query = New Query(
	"SELECT
	|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
	|	VALUETYPE(AccountingCheckResults.ObjectWithIssue) AS RefType
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	NOT AccountingCheckResults.IgnoreIssue
	|	AND AccountingCheckResults.CheckRule = &CheckRule
	|TOTALS BY
	|	RefType");
	
	Query.SetParameter("CheckRule", Validation);
	Result = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each ObjectTypeString In Result.Rows Do
		FullTableName = Metadata.FindByType(ObjectTypeString.RefType).FullName();
		For Each StringObject In ObjectTypeString.Rows Do
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add(FullTableName);
				LockItem.SetValue("Ref", StringObject.ObjectWithIssue);
				Block.Lock();
				
				ProblemObjectRef = StringObject.ObjectWithIssue;
				Parent = Common.ObjectAttributeValue(ProblemObjectRef, "Parent");
				
				ItemsToCheck = New Array;
				If Not CheckLevelsLooping(ProblemObjectRef, Parent, ItemsToCheck) Then
					RollbackTransaction();
					Continue;
				EndIf;
					
				LoopLastObject = ItemsToCheck[ItemsToCheck.Count() - 1];
				
				FirstLoopChildrenCount = ChildItemsCount(ProblemObjectRef, Parent); // @skip-
				SecondLoopChildrenCount = ChildItemsCount(LoopLastObject, Parent); // @skip-
				
				ObjectWithIssue = ?(FirstLoopChildrenCount > SecondLoopChildrenCount, ProblemObjectRef, LoopLastObject);
				ObjectWithIssue = ObjectWithIssue.GetObject();
				ObjectWithIssue.Parent = Common.ObjectManagerByFullName(ProblemObjectRef.Metadata().FullName()).EmptyRef();
				ObjectWithIssue.DataExchange.Load = True;
				ObjectWithIssue.Write();
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndDo;
	EndDo;
	
EndProcedure

Function ChildItemsCount(ObjectReference, SelectionExclusion, Val InitialValue = 0)
	
	ChildrenCount = InitialValue;
	
	Upload0 = SubordinateParentItems(ObjectReference, SelectionExclusion);
	ChildrenCount = ChildrenCount + Upload0.Count();
	For Each DescendantItem In Upload0 Do
		ChildrenCount = ChildItemsCount(DescendantItem.Ref, SelectionExclusion, ChildrenCount); // @skip-
	EndDo;
	Return ChildrenCount;
	
EndFunction

// Returns:
//   ValueTable:
//   * Ref - AnyRef
//
Function SubordinateParentItems(ObjectReference, Val SelectionExclusion)
	Var Result;
	QueryText =
	"SELECT
	|	SpecifiedTableAlias.Ref AS Ref
	|FROM
	|	&MetadataObject AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Parent = &Parent
	|	AND SpecifiedTableAlias.Ref <> &SelectionExclusion";
	
	FullName = ObjectReference.Metadata().FullName();
	TableName = StrReplace(FullName, ".", "");
	QueryText = StrReplace(QueryText, "SpecifiedTableAlias", TableName);
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Parent",          ObjectReference);
	Query.SetParameter("SelectionExclusion", SelectionExclusion);
	Result = Query.Execute();
	
	Upload0        = Result.Unload();
	Return Upload0
EndFunction

#EndRegion

#Region CheckNoPredefinedItems

Procedure FindMissingPredefinedItems(MetadataObject, CheckParameters)
	
	FullName                = MetadataObject.FullName();
	PredefinedItems = MetadataObject.GetPredefinedNames();
	For Each PredefinedItem In PredefinedItems Do
		
		If StrStartsWith(Upper(PredefinedItem), "DELETE") Then
			Continue;
		EndIf;
		
		FoundItem = Common.PredefinedItem(FullName + "." + PredefinedItem);
		If FoundItem <> Undefined Then
			Continue;
		EndIf;
			
		Issue1 = IssueDetails(Common.MetadataObjectID(MetadataObject), CheckParameters); // @skip-
		Issue1.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Predefined item ""%1"" missing in information database.';"), PredefinedItem);
		WriteIssue(Issue1, CheckParameters); // 
		
	EndDo;
	
EndProcedure

#EndRegion

#Region CheckDuplicatePredefinedItems1

Procedure FindPredefinedItemsDuplicates(MetadataKind, CheckParameters)
	
	TemporaryTableTemplate =
	"SELECT
	|	""&Table"" AS FullName,
	|	Table.PredefinedDataName AS PredefinedDataName 
	|INTO
	|#TempTable
	|FROM
	|	&Table AS Table
	|WHERE Table.Predefined
	|
	|GROUP BY
	|	Table.PredefinedDataName
	|
	|HAVING
	|	COUNT(DISTINCT Table.Ref) > 1";
	
	SelectionTemplate1 =
	"SELECT
	|	&ObjectWithIssue AS ObjectWithIssue, 
	|	TempTable.PredefinedDataName AS PredefinedDataName,
	|	REFPRESENTATION(Table.Ref) AS DuplicateItemRef
	|FROM
	|	&Table AS Table
	|		INNER JOIN #TempTable AS TempTable
	|		ON Table.PredefinedDataName = TempTable.PredefinedDataName";
	
	SelectionTotals = "
	|TOTALS BY ObjectWithIssue, PredefinedDataName"; // @query-part-1
	
	TemporaryTableText = "";
	SelectionText = "";
	
	Query = New Query;
	For Each MetadataObject In MetadataKind Do
		
		TableName = MetadataObject.FullName();
		If IsSharedMetadataObject(TableName) Then
			Continue;
		EndIf;
		
		If StrStartsWith(MetadataObject.Name, "Delete") Then
			Continue;
		EndIf;
		
		If MetadataObject.PredefinedDataUpdate = Metadata.ObjectProperties.PredefinedDataUpdate.DontAutoUpdate Then
			Continue;
		EndIf;
		
		TempTableName = "TT_" + StrReplace(TableName, ".", "");
		
		QueryText = StrReplace(TemporaryTableTemplate, "#TempTable", TempTableName);
		QueryText = StrReplace(QueryText, "&Table", TableName);
		TemporaryTableText = TemporaryTableText + ?(ValueIsFilled(TemporaryTableText), ";", "") + QueryText;
		
		ParameterSuffix = StrReplace(TableName, ".", "_");
		ParameterName = "&ObjectWithIssue" + ParameterSuffix;
		QueryText = StrReplace(SelectionTemplate1, "&ObjectWithIssue",	ParameterName);
		QueryText = StrReplace(QueryText, "&Table", TableName);
		QueryText = StrReplace(QueryText, "#TempTable", TempTableName);
		SelectionText = SelectionText + ?(ValueIsFilled(SelectionText), " UNION ALL ", "") + QueryText;
		Query.SetParameter("ObjectWithIssue" + ParameterSuffix, Common.MetadataObjectID(TableName));
		
	EndDo;
	
	If Not ValueIsFilled(TemporaryTableText) Then
		Return;
	EndIf;
   
	Query.Text = TemporaryTableText + ";" + SelectionText + SelectionTotals;
	Result = Query.Execute().Select(QueryResultIteration.ByGroups);
	While Result.Next() Do
		
		IssueSummary = "";
		ResultByPredefinedItemName = Result.Select(QueryResultIteration.ByGroups);
		
		While ResultByPredefinedItemName.Next() Do
			
			PredefinedDataName = ResultByPredefinedItemName.PredefinedDataName;
			If StrStartsWith(Upper(PredefinedDataName), "DELETE") Then
				Continue;
			EndIf;
			
			IssueSummary = IssueSummary + ?(ValueIsFilled(IssueSummary), Chars.LF, "")
				+ NStr("en = 'Name of the predefined item:';") + " """ + PredefinedDataName + """"
				+ Chars.LF + NStr("en = 'References to the predefined item:';");
				
			DetailedRecords = ResultByPredefinedItemName.Select();
			While DetailedRecords.Next() Do
				IssueSummary = IssueSummary + ?(ValueIsFilled(IssueSummary), Chars.LF, "")
					+ " • """ + DetailedRecords.DuplicateItemRef + """";
			EndDo;
			
		EndDo;
		
		If Not ValueIsFilled(IssueSummary) Then
			Continue;
		EndIf;
		
		Issue1 = IssueDetails(Result.ObjectWithIssue, CheckParameters); // @skip-
		Issue1.IssueSummary = IssueSummary;
		WriteIssue(Issue1, CheckParameters); // 
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Other

Function HasRequiredAttributes(MetadataObject)
	
	For Each Dimension In MetadataObject.Dimensions Do
		If Dimension.FillChecking = FillChecking.ShowError Then
			Return True;
		EndIf;
	EndDo;
	
	For Each Attribute In MetadataObject.Attributes Do
		If Attribute.FillChecking = FillChecking.ShowError Then
			Return True;
		EndIf;
	EndDo;
	
	For Each Resource In MetadataObject.Resources Do
		If Resource.FillChecking = FillChecking.ShowError Then
			Return True;
		EndIf;
	EndDo;
	
	For Each StandardAttribute In MetadataObject.StandardAttributes Do
		If StandardAttribute.FillChecking = FillChecking.ShowError Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ReadParameters(CheckExecutionParameters)
	Result = New Structure("FullName, MetadataObject, ValidationArea");
	If CheckExecutionParameters.Count() <> 1 Then
		Return Undefined;
	EndIf;
	
	ParametersStructure = CheckExecutionParameters[0];
	If TypeOf(ParametersStructure) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If ParametersStructure.Property1 <> "ObjectToCheck" Then
		Return Undefined;
	EndIf;
	
	Result.FullName = ParametersStructure.Property2;
	If StandardSubsystemsServer.IsRegisterTable(Result.FullName) Then
		Result.ValidationArea = "Registers";
	Else
		Result.ValidationArea = "RefObjects";
	EndIf;
	Result.MetadataObject = Common.MetadataObjectByFullName(Result.FullName);
	
	Return Result;
EndFunction

Function ObjectWithIssuePresentation(ObjectWithIssue, ObjectWithIssuePresentation, AdditionalInformation) Export
	
	Result = ObjectWithIssuePresentation + " (" + ObjectWithIssue.Metadata().Presentation() + ")";
	If TypeOf(ObjectWithIssue) <> Type("CatalogRef.MetadataObjectIDs") Then
		Return Result;
	EndIf;
	
	Result = String(ObjectWithIssue) + "<DetailsList>" + Chars.LF + ObjectWithIssue.FullName;
	If Not Common.IsRegister(Common.MetadataObjectByFullName(ObjectWithIssue.FullName)) Then
		Return Result;
	EndIf;
		
	SetStructure  = AdditionalInformation.Get();
	If TypeOf(SetStructure) <> Type("Structure") Then
		Return Result;
	EndIf;
	
	For Each Set_Item In SetStructure Do
		
		FilterValue    = Set_Item.Value;
		ValueTypeFilter = TypeOf(FilterValue);
		TypeInformation   = "";
		
		If ValueTypeFilter = Type("Number") Then
			TypeInformation = "Number";
		ElsIf ValueTypeFilter = Type("String") Then
			TypeInformation = "String";
		ElsIf ValueTypeFilter = Type("Boolean") Then
			TypeInformation = "Boolean";
		ElsIf ValueTypeFilter = Type("Date") Then
			TypeInformation = "Date";
		ElsIf Common.IsReference(ValueTypeFilter) Then
			TypeInformation = FilterValue.Metadata().FullName();
		EndIf;
		
		Result = Result + Chars.LF + String(Set_Item.Key) + "~~~" + TypeInformation + "~~~" + String(XMLString(FilterValue));
		
	EndDo;
	
	Return Result;
	
EndFunction

Function DetailsCell(Ref, CheckRule, CheckKind, IssueSummary) Export
	If Not Common.IsReference(TypeOf(Ref)) Then
		Return "";
	EndIf;
	
	Details = Ref.Metadata().FullName() + ";"
		+ Ref.UUID() + ";"
		+ CheckRule.UUID() + ";"
		+ CheckKind.UUID() + ";"
		+ IssueSummary;
	
	Return Details;
EndFunction

// See AccountingAudit.SubsystemAvailable.
Function SubsystemAvailable() Export
	
	Return AccessRight("View", Metadata.InformationRegisters.AccountingCheckResults);
	
EndFunction

Function IsSharedMetadataObject(FullName)
	
	If Not Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		Return Not ModuleSaaSOperations.IsSeparatedMetadataObject(FullName);
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure FillPictureIndex(Rows, ListLine, Composite, IndicatorColumn, ObjectsWithIssues) Export
	
	If Not ListLine.Data.Property(IndicatorColumn) Then
		Return;
	EndIf;
	
	CellText = ListLine.Appearance.Get(IndicatorColumn).FindParameterValue(New DataCompositionParameter("Text"));
	
	FoundRow = ObjectsWithIssues.Find(Composite, "ObjectWithIssue");
	If FoundRow = Undefined Then
		ListLine.Data[IndicatorColumn] = 0;
		If CellText <> Undefined Then
			CellText.Value = 0;
		EndIf;
	Else
		If FoundRow.IssueOrder = 0
			Or FoundRow.IssueOrder = 1 Then
			ListLine.Data[IndicatorColumn] = 1
		ElsIf FoundRow.IssueOrder = 2
			Or FoundRow.IssueOrder = 3 Then
			ListLine.Data[IndicatorColumn] = 2
		ElsIf FoundRow.IssueOrder = 4 Then
			ListLine.Data[IndicatorColumn] = 3
		Else
			ListLine.Data[IndicatorColumn] = 1
		EndIf;
		
		If CellText <> Undefined Then
			CellText.Value = 1;
		EndIf;
	EndIf;
	
EndProcedure

Function ObjectFillingErrors()
	
	IssueSummary = "";
	For Each UserMessage1 In GetUserMessages(True) Do
		IssueSummary = IssueSummary + ?(ValueIsFilled(IssueSummary), Chars.LF, "") + UserMessage1.Text;
	EndDo;
	
	Return ?(IsBlankString(IssueSummary), NStr("en = 'For more information, open the object form.';"), IssueSummary);
	
EndFunction

Function CheckRunning(ScheduledJobID)
	
	Result = False;
	If ValueIsFilled(ScheduledJobID) Then
		Job = BackgroundJobs.FindByUUID(New UUID(ScheduledJobID));
		If Job <> Undefined And Job.State = BackgroundJobState.Active Then
			Result = True;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// See AccountingAudit.ClearPreviousCheckResults.
Procedure ClearPreviousCheckResults(Validation, CheckExecutionParameters) Export
	
	For Each CheckExecutionParameter In CheckExecutionParameters Do
		
		CheckKind = CheckKind(CheckExecutionParameter, True); // @skip-
		If Not ValueIsFilled(CheckKind) Then
			Continue;
		EndIf;
		
		Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
		Set.Filter.CheckRule.Set(Validation);
		Set.Filter.CheckKind.Set(CheckKind);
		Set.Filter.IgnoreIssue.Set(False);
		Set.Write();
		
	EndDo;
	
EndProcedure

Procedure ClearResultsBeforeExecuteCheck(Validation)
	Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
	Set.Filter.CheckRule.Set(Validation);
	Set.Filter.IgnoreIssue.Set(False);
	Set.Write();
EndProcedure

Function LastObjectCheckResult(CheckExecutionParameters)
	Query = New Query;
	Query.SetParameter("CheckRule", CheckExecutionParameters.Validation);
	Query.SetParameter("ObjectsWithIssues", CheckExecutionParameters.ObjectsToCheck);
	Query.Text =
		"SELECT
		|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
		|	AccountingCheckResults.CheckRule AS CheckRule,
		|	AccountingCheckResults.CheckKind AS CheckKind,
		|	AccountingCheckResults.UniqueKey AS UniqueKey,
		|	AccountingCheckResults.IgnoreIssue AS IgnoreIssue
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.CheckRule = &CheckRule
		|	AND AccountingCheckResults.ObjectWithIssue IN (&ObjectsWithIssues)
		|	AND AccountingCheckResults.IgnoreIssue = FALSE";
	
	Return Query.Execute().Unload();
EndFunction

Procedure DeleteLastCheckResults(LastCheckResult)
	
	For Each String In LastCheckResult Do
		Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
		Set.Filter.ObjectWithIssue.Set(String.ObjectWithIssue);
		Set.Filter.CheckRule.Set(String.CheckRule);
		Set.Filter.CheckKind.Set(String.CheckKind);
		Set.Filter.UniqueKey.Set(String.UniqueKey);
		Set.Filter.IgnoreIssue.Set(String.IgnoreIssue);
		
		SetPrivilegedMode(True);
		Set.Write();
		SetPrivilegedMode(False);
	EndDo;
	
EndProcedure

// Checks whether the number of the allowed limit check iterations is exceeded.
//
// Parameters:
//   CheckParameters - see the CheckParameters parameter in the AccountingAudit.IssueDetails.
//
// Returns:
//   Boolean - 
//
Function IsLastCheckIteration(CheckParameters)
	
	IsLastIteration = False;
	
	If CheckParameters.IssuesLimit <> 0 Then
		If CheckParameters.CheckIteration > CheckParameters.IssuesLimit Then
			IsLastIteration = True;
		Else
			CheckParameters.Insert("CheckIteration", CheckParameters.CheckIteration + 1);
		EndIf;
	EndIf;
	
	Return IsLastIteration;
	
EndFunction

// Returns a metadata object kind string presentation by the object type.
// Restriction: does not process business process route points.
//
// Parameters:
//  ObjectReference - AnyRef - a reference to an object with issues.
//
// Returns:
//  String - 
//
Function ObjectPresentationByType(ObjectReference)
	
	ObjectType = TypeOf(ObjectReference);
	
	If Catalogs.AllRefsType().ContainsType(ObjectType) Then
		
		Return NStr("en = 'catalog item';");
	
	ElsIf Documents.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'document';");
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'business process';");
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'chart of characteristic types';");
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'chart of accounts';");
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'chart of calculation types';");
	
	ElsIf Tasks.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'task';");
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'exchange plan';");
	
	ElsIf Enums.AllRefsType().ContainsType(ObjectType) Then
		Return NStr("en = 'enumeration';");
	
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Invalid parameter value type (%1)';"), String(ObjectType));
	
	EndIf;
	
EndFunction

// Returns the String, Array, and CatalogRef.ChecksKinds types
// to check the parameters of methods working with the check kinds.
//
// Returns:
//    Array - 
//
Function TypeDetailsCheckKind() Export
	
	TypesArray = New Array;
	TypesArray.Add(Type("String"));
	TypesArray.Add(Type("Array"));
	TypesArray.Add(Type("CatalogRef.ChecksKinds"));
	
	Return TypesArray;
	
EndFunction

// Returns allowed parameter types of the check.
//
// Returns:
//   Structure:
//      * IssueSeverity - EnumRef.AccountingIssueSeverity
//      * GlobalSettings - Structure
//      * CheckStartDate - Date
//      * Id - String
//      * ScheduledJobID - String
//      * CheckIteration - Number
//      * IssuesLimit - Number
//      * Description - String
//      * Validation - CatalogRef.AccountingCheckRules
//
Function CheckParametersPropertiesExpectedTypes() Export
	
	PropertiesTypesToExpect = New Structure;
	PropertiesTypesToExpect.Insert("IssueSeverity",                  Type("EnumRef.AccountingIssueSeverity"));
	PropertiesTypesToExpect.Insert("GlobalSettings",               Type("Structure"));
	PropertiesTypesToExpect.Insert("CheckStartDate",                Type("Date"));
	PropertiesTypesToExpect.Insert("Id",                     Type("String"));
	PropertiesTypesToExpect.Insert("ScheduledJobID", Type("String"));
	PropertiesTypesToExpect.Insert("CheckIteration",                  Type("Number"));
	PropertiesTypesToExpect.Insert("IssuesLimit",                      Type("Number"));
	PropertiesTypesToExpect.Insert("Description",                      Type("String"));
	PropertiesTypesToExpect.Insert("Validation",                          Type("CatalogRef.AccountingCheckRules"));
	
	Return PropertiesTypesToExpect;
	
EndFunction

//  
//
// Returns:
//   TypeDescription - 
//
Function ExpectedPropertiesTypesOfChecksKinds() Export
	
	TypesArray = New Array;
	TypesArray.Add(Type("Boolean"));
	TypesArray.Add(Type("String"));
	TypesArray.Add(Type("Date"));
	TypesArray.Add(Type("Number"));
	
	Return New TypeDescription(Common.AllRefsTypeDetails(), TypesArray);
	
EndFunction

// Returns allowed property types of issue description.
//
// Parameters:
//   IssueFullDetails          - Boolean - it affects the composition of return value properties.
//
// Returns:
//   Structure:
//        * ObjectWithIssue         - AnyRef - a reference to the object that is the Source of issues.
//        * CheckRule          - CatalogRef.AccountingCheckRules - a reference to the executed check.
//        * CheckKind              - CatalogRef.ChecksKinds - a reference to 
//                                     a check kind.
//        * IssueSummary        - String - a string summary of the found issue.
//        * UniqueKey         - UUID - an issue unique key. 
//                                     It is returned if IssueFullDetails = True.
//        * IssueSeverity         - EnumRef.AccountingIssueSeverity - Severity level of a data integrity issue 
//                                     Information, Warning, Error, and UsefulTip.
//                                     It is returned if IssueFullDetails = True.
//        * EmployeeResponsible            - CatalogRef.Users - it is filled in if it is possible
//                                     to identify a person responsible for the problematic object.
//                                     It is returned if IssueFullDetails = True.
//        * IgnoreIssue     - Boolean - a flag of ignoring an issue. If the value is True,
//                                     the subsystem ignores the record about an issue.
//                                     It is returned if IssueFullDetails = True.
//        * AdditionalInformation - ValueStorage - a service property with additional
//                                     information related to the detected issue.
//                                     It is returned if IssueFullDetails = True.
//        * Detected                 - Date - server time of the issue identification.
//                                     It is returned if IssueFullDetails = True.
//
Function IssueDetailsPropertiesTypesToExpect(Val IssueFullDetails = True) Export
	
	PropertiesTypesToExpect = New Structure;
	PropertiesTypesToExpect.Insert("ObjectWithIssue",  Common.AllRefsTypeDetails());
	PropertiesTypesToExpect.Insert("CheckRule",   Type("CatalogRef.AccountingCheckRules"));
	PropertiesTypesToExpect.Insert("CheckKind",       Type("CatalogRef.ChecksKinds"));
	PropertiesTypesToExpect.Insert("IssueSummary", Type("String"));
	
	If IssueFullDetails Then
		PropertiesTypesToExpect.Insert("IssueSeverity",         Type("EnumRef.AccountingIssueSeverity"));
		PropertiesTypesToExpect.Insert("Detected",                 Type("Date"));
		PropertiesTypesToExpect.Insert("UniqueKey",         Type("UUID"));
		PropertiesTypesToExpect.Insert("AdditionalInformation", Type("ValueStorage"));
		ResponsiblePersonTypes = New Array;
		ResponsiblePersonTypes.Add(Type("CatalogRef.Users"));
		ResponsiblePersonTypes.Add(Type("Undefined"));
		PropertiesTypesToExpect.Insert("EmployeeResponsible", ResponsiblePersonTypes);
	EndIf;
	
	Return PropertiesTypesToExpect;
	
EndFunction

// Returns:
//   Array of MetadataObjectCatalog
//
Function MetadataObjectsRefKinds()
	
	Result = New Array;
	Result.Add(Metadata.Catalogs);
	Result.Add(Metadata.Documents);
	Result.Add(Metadata.ExchangePlans);
	Result.Add(Metadata.ChartsOfCharacteristicTypes);
	Result.Add(Metadata.ChartsOfAccounts);
	Result.Add(Metadata.ChartsOfCalculationTypes);
	Result.Add(Metadata.BusinessProcesses);
	Result.Add(Metadata.Tasks);
	Return Result;
	
EndFunction

Function RegistersAsMetadataObjects()
	
	Result = New Array;
	Result.Add(Metadata.AccountingRegisters);
	Result.Add(Metadata.AccumulationRegisters);
	Result.Add(Metadata.CalculationRegisters);
	Result.Add(Metadata.InformationRegisters);
	Return Result;
	
EndFunction

Function IssuePicture(Settings)
	IssuesIndicatorPicture = Settings.IssuesIndicatorPicture;
	IssueSeverity = Settings.IssueSeverity;
	
	If IssuesIndicatorPicture <> Undefined And IssuesIndicatorPicture <> PictureLib.Warning Then
		Picture = IssuesIndicatorPicture;
	ElsIf IssueSeverity = Enums.AccountingIssueSeverity.Error
		Or IssueSeverity = Enums.AccountingIssueSeverity.Warning Then
		Picture = PictureLib.Warning;
	ElsIf IssueSeverity = Enums.AccountingIssueSeverity.ImportantInformation
		Or IssueSeverity = Enums.AccountingIssueSeverity.Information Then
		Picture = PictureLib.Information;
	ElsIf IssueSeverity = Enums.AccountingIssueSeverity.UsefulTip Then
		Picture = PictureLib.UsefulTipAccountingAudit;
	Else
		Picture = PictureLib.Warning;
	EndIf;
	
	Return Picture;
EndFunction

#Region IgnoreIssuesInternal

// Generates the ObjectWithIssue, CheckRule, CheckKind dimensions checksum 
// and the IssueSummary resource by the MD5 algorithm.
//
// Parameters:
//   Issue1 - see the AccountingAudit.WriteIssue parameter.
//
// Returns:
//    String - 
//             
//
Function IssueChecksum(Issue1) Export
	
	IssueStructure = New Structure("ObjectWithIssue, CheckRule, CheckKind, IssueSummary");
	FillPropertyValues(IssueStructure, Issue1);
	Return Common.CheckSumString(IssueStructure);
	
EndFunction

// Returns True if an issue was ignored.
//
// Parameters:
//   Checksum - String - a register record checksum by the MD5 algorithm.
//
Function ThisIssueIgnored(Checksum)
	
	Query = New Query(
	"SELECT TOP 1
	|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	AccountingCheckResults.Checksum = &Checksum
	|	AND AccountingCheckResults.IgnoreIssue");
	
	Query.SetParameter("Checksum", Checksum);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#EndRegion

#EndRegion