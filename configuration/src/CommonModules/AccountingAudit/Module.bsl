///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to perform data integrity checks and get their results.

// Executes the indicated data integrity check with the specified parameters.
//
// Parameters:
//   Validation                    - CatalogRef.AccountingCheckRules
//                               - String - Check rule to run, or its string ID.
//                                 
//   CheckExecutionParameters - Structure
//                               - Array - Custom additional check parameters that define the check procedure and object.
//                                  
//                                 See AccountingAudit.CheckExecutionParameters.
//                               - Structure:
//       * Property1 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Parameter's first value.
//       * Property2 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Parameter's second value.
//       * Property3 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Parameter's third value.
//       …                                              
//     - Array - Check parameters (Structure elements as described above). 
//   ObjectsToCheck - AnyRef - if passed, only this object will be checked.
//                                     The check must support random check and have
//                                     the SupportsRandomCheck property set to True.
//                                     See AccountingAuditOverridable.OnDefineChecks.
//                      - Array - References to the objects to be checked.
//
// Example:
//   1. Check = AccountingAudit.CheckByID("CheckRefIntegrity");
//      AccountingAudit.RunCheck(Check);
//   2. CheckExecutionParameters = New Array;
//      Parameter1 = AccountingAudit.CheckExecutionParameters("MonthEndClosing", Company1, MonthToClose);
//      CheckExecutionParameters(Parameter1);
//      Parameter2 = AccountingAudit.CheckExecutionParameters("MonthEndClosing", Company2, MonthToClose);
//      CheckExecutionParameters.Add(Parameter2);
//      RunCheck("CheckDocumentsPosting", CheckExecutionParameters);
//
Procedure ExecuteCheck(Val Validation, Val CheckExecutionParameters = Undefined, ObjectsToCheck = Undefined) Export
	
	If TypeOf(Validation) = Type("String") Then
		CheckToExecute = CheckByID(Validation);
		If CheckToExecute.IsEmpty() Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Data integrity check with ID %1 does not exist (see %2).';"),
				Validation,
				"AccountingAuditOverridable.OnDefineChecks");
		EndIf;
	Else
		CommonClientServer.CheckParameter("AccountingAudit.ExecuteCheck", "Validation",
			Validation, Type("CatalogRef.AccountingCheckRules"));
		CheckToExecute = Validation;
	EndIf;
	
	If CheckExecutionParameters <> Undefined Then
		CheckCheckExecutionParameters(CheckExecutionParameters, "AccountingAudit.ExecuteCheck");
	EndIf;
	
	AccountingAuditInternal.ExecuteCheck(CheckToExecute, CheckExecutionParameters, ObjectsToCheck);
	
EndProcedure

// Executes checks by a given context - a common flag that links a package of checks.
// If the specified flag is set for a group of checks, all checks of this group are executed. 
// In this case, the presence (or absence) of the specified flag in the check itself does not matter.
// Checks with the Usage check box set to False are ignored.
//
// Parameters:
//    AccountingChecksContext - DefinedType.AccountingChecksContext - Checks' context.
//
// Example:
//    AccountingAudit.PerformChecksInContext(Enumerations.BusinessTransactions.MonthEndClosing);
//
Procedure ExecuteChecksInContext(AccountingChecksContext) Export
	
	CommonClientServer.CheckParameter("AccountingAudit.ExecuteChecksInContext",
		"AccountingChecksContext", AccountingChecksContext,
		Metadata.DefinedTypes.AccountingChecksContext.Type);
	
	ChecksByContext = AccountingAuditInternal.ChecksByContext(AccountingChecksContext);
	
	MethodParameters        = New Map;
	CheckUpperBoundary = ChecksByContext.UBound();
	
	For IndexOfCheck = 0 To CheckUpperBoundary Do
		ParametersArray = New Array;
		ParametersArray.Add(ChecksByContext[IndexOfCheck]);
		
		MethodParameters.Insert(IndexOfCheck, ParametersArray);
	EndDo;
	
	ProcedureName = "AccountingAudit.ExecuteCheck";
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Data integrity';");
	ExecutionParameters.WaitCompletion = Undefined;
	
	ExecutionResult = TimeConsumingOperations.ExecuteProcedureinMultipleThreads(
		ProcedureName,
		ExecutionParameters,
		MethodParameters);
	
	If ExecutionResult.Status <> "Completed2" Then
		If ExecutionResult.Status = "Error" Then
			ErrorText = ExecutionResult.DetailErrorDescription;
		ElsIf ExecutionResult.Status = "Canceled" Then
			ErrorText = NStr("en = 'The background job is canceled.';");
		Else
			ErrorText = NStr("en = 'Background job error';");
		EndIf;
		Raise ErrorText;
	EndIf;
	
	Results = GetFromTempStorage(ExecutionResult.ResultAddress); // Map
	If TypeOf(Results) <> Type("Map") Then
		ErrorText = NStr("en = 'The background job did not return a result';");
		Raise ErrorText;
	EndIf;
	
	For Each ResultDetails In Results Do
		Result = ResultDetails.Value; // See TimeConsumingOperations.ExecuteProcedure
		If Result.Status <> "Completed2" Then
			If Result.Status = "Error" Then
				ErrorText = Result.DetailErrorDescription;
			ElsIf Result.Status = "Canceled" Then
				ErrorText = NStr("en = 'The background job is canceled.';");
			Else
				ErrorText = NStr("en = 'Background job error';");
			EndIf;
			Raise ErrorText;
		EndIf;
	EndDo;
	
	If MethodParameters.Count() <> Results.Count() Then
		ErrorText = NStr("en = 'Some checks were not performed';");
		Raise ErrorText;
	EndIf;
	
EndProcedure

// Sums up the detected issue amount for the specified check kind.
//
// Parameters:
//   ChecksKind                - CatalogRef.ChecksKinds - a reference to a check kind.
//                              - String - 
//                              - Array of String - 
//   SearchByExactMap - Boolean - regulates accuracy capabilities. If True, the search is conducted
//                                by the passed properties for equality, other properties must be equal
//                                Undefined (tabular section of additional properties has to be blank).
//                                If False, other property values can be arbitrary, the main thing is
//                                that the corresponding properties need to be equal to the structure properties. Default value is True.
//   ConsiderPersonResponsible    - Boolean - if True, consider only issues with unfilled person responsible
//                                and those who have the current user as a person responsible.
//                                Default value is False.
//
// Returns:
//  Structure:
//    * Count - Number - a total number of the issues found.
//    * HasErrors - Boolean - indicates whether the detected issues include issues with the Error severity.
//
// Example:
//   1) Result = SummaryInformationOnChecksKinds("SystemChecks");
//   2) ChecksKind = New Array;
//      ChecksKind.Add("MonthEndClosing");
//      ChecksKind.Add(Company);
//      ChecksKind.Add(ClosingMonth);
//      Result = SummaryInformationOnChecksKinds(ChecksKind);
//
Function SummaryInformationOnChecksKinds(ChecksKind = Undefined, SearchByExactMap = True, ConsiderPersonResponsible = False) Export
	
	ProcedureName = "AccountingAudit.SummaryInformationOnChecksKinds";
	If ChecksKind <> Undefined Then
		CommonClientServer.CheckParameter(ProcedureName, "ChecksKind", ChecksKind, AccountingAuditInternal.TypeDetailsCheckKind());
	EndIf;
	CommonClientServer.CheckParameter(ProcedureName, "SearchByExactMap", SearchByExactMap, Type("Boolean"));
	
	Return AccountingAuditInternal.SummaryInformationOnChecksKinds(ChecksKind, SearchByExactMap, ConsiderPersonResponsible);
	
EndFunction

// Returns detailed information about detected issues of one or several check kinds of interest.
//
// Parameters:
//   ChecksKind                - CatalogRef.ChecksKinds - a reference to a check kind.
//                              - String - 
//                              - Array of String - 
//   SearchByExactMap - Boolean - if True, the check kind is determined by the exact match of
//                                all property values in the ChecksKind parameter (see example 2). 
//                                If False, the check kind is determined both by the specified property values
//                                and by any values of the unspecified properties in the ViewCheck parameter (see Example No. 3). 
//
// Returns:
//   ValueTable:
//     * ObjectWithIssue         - AnyRef - a reference to object, which the issue is connected to.
//     * IssueSeverity         - EnumRef.AccountingIssueSeverity - Issue severity:
//                                  Information, Warning, Error, UsefulTip, or ImportantInformation.
//     * CheckRule          - CatalogRef.AccountingCheckRules - an executed check with issue details.
//     * ChecksKind              - CatalogRef.ChecksKinds - check kind.
//     * IssueSummary        - String - a text summary of the found issue.
//     * EmployeeResponsible            - CatalogRef.Users - it is filled in if the checking algorithm
//                                  identified a specific person responsible for the detected issue.
//     * Detected                 - Date - date and time when the issue is detected.
//     * AdditionalInformation - ValueStorage - arbitrary additional information related 
//                                  to the found issue. 
//
// Example:
//   1) Result = DetailedInformationOnChecksKinds("SystemChecks");
//   2) ChecksKind = New Array;
//      ChecksKind.Add("MonthEndClosing");
//      ChecksKind.Add(Company);
//      ChecksKind.Add(ClosingMonth);
//      Result = DetailedInformationOnChecksKinds(ChecksKind);
//   3) Select all month-end closing issues by all periods for the specified company:
//      ChecksKind = New Array;
//      ChecksKind.Add("MonthEndClosing");
//      ChecksKind.Add(Company);
//      Result = DetailedInformationOnChecksKinds(ChecksKind, False); 
//
Function DetailedInformationOnChecksKinds(ChecksKind, SearchByExactMap = True) Export
	
	ProcedureName = "AccountingAudit.DetailedInformationOnChecksKinds";
	CommonClientServer.CheckParameter(ProcedureName, "ChecksKind", ChecksKind, AccountingAuditInternal.TypeDetailsCheckKind());
	CommonClientServer.CheckParameter(ProcedureName, "SearchByExactMap", SearchByExactMap, Type("Boolean"));
	
	Return AccountingAuditInternal.DetailedInformationOnChecksKinds(ChecksKind, SearchByExactMap);
	
EndFunction

// Returns a check to the passed ID.
//
// Parameters:
//   Id - String - a check string ID. For example, "CheckRefIntegrity".
//
// Returns: 
//   CatalogRef.AccountingCheckRules -  
//      
//
Function CheckByID(Id) Export
	
	CommonClientServer.CheckParameter("AccountingAudit.CheckByID", "Id", Id, Type("String"));
	Return AccountingAuditInternal.CheckByID(Id);
	
EndFunction

// Returns the number of issues detected at the passed object.
//
// Parameters:
//   ObjectWithIssue - AnyRef - an object, for which you need to calculate the number of issues.
//
// Returns:
//   Number
//
Function IssuesCountByObject(ObjectWithIssue) Export
	
	CommonClientServer.CheckParameter("AccountingAudit.IssuesCountByObject", "ObjectWithIssue",
		ObjectWithIssue, Common.AllRefsTypeDetails());
	
	Query = New Query(
	"SELECT ALLOWED
	|	COUNT(*) AS Count
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	AccountingCheckResults.ObjectWithIssue = &ObjectWithIssue
	|	AND NOT AccountingCheckResults.IgnoreIssue");
	Query.SetParameter("ObjectWithIssue", ObjectWithIssue);
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Select();
	Return ?(Result.Next(), Result.Count, 0); 
	
EndFunction

// Calculates the number of issues detected by the passed check rule.
//
// Parameters:
//   CheckRule - CatalogRef.AccountingCheckRules - a rule, for which
//                     you need to calculate the number of issues.
//
// Returns:
//   Number
//
Function IssuesCountByCheckRule(CheckRule) Export
	
	CommonClientServer.CheckParameter("AccountingAudit.IssuesCountByCheckRule", "CheckRule",
		CheckRule, Type("CatalogRef.AccountingCheckRules"));
	
	Query = New Query(
		"SELECT ALLOWED
		|	COUNT(*) AS Count
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.CheckRule = &CheckRule
		|	AND NOT AccountingCheckResults.IgnoreIssue");
	Query.SetParameter("CheckRule", CheckRule);
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Select();
	If Result.Next() Then
		IssuesCount = Result.Count;
	Else
		IssuesCount = 0;
	EndIf;
	
	Return IssuesCount;
	
EndFunction

// Generates check execution parameters for passing to the procedures and functions RunCheck, IssueDetails,
// CheckKind, and so on.
// The parameters contain a clarification for what exactly the check is required,
// for example, check the month-end closing for a particular company during a specific period.
// The order of parameters is taken into consideration.
//
// Parameters:
//     Parameter1     - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's first parameter.
//     Parameter2     - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's second parameter.
//     Parameter3     - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's third parameter.
//     Parameter4     - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's fourth parameter.
//     Parameter5     - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's fifth parameter.
//     AnotherParameters - Array - other check parameters (items of the AnyRef, Boolean, Number, String, and Date types).
//
// Returns:
//    Structure:
//       * Description - String - a check kind presentation. 
//       * Property1 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's first parameter.
//       * Property2 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's second parameter.
//       * Property3 - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - Check's third parameter.
//       ...                                              
//       * СвойствоН - AnyRef
//                   - Boolean
//                   - Number
//                   - String
//                   - Date - 
//
// Example:
//     1. Parameters = CheckExecutionParameters("SystemChecks");
//     2. Parameters = CheckExecutionParameters("MonthEndClosing", CompanyRef, MonthToClose);
//
Function CheckExecutionParameters(Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val AnotherParameters = Undefined) Export
	
	Return AccountingAuditInternal.CheckExecutionParameters(Parameter1, Parameter2, Parameter3, Parameter4, Parameter5, AnotherParameters);
	
EndFunction

// Clears previous check results, leaving only those issues that were ignored earlier
// (the IgnoreIssue flag = True).
// The previous results are cleared automatically for non-parameter checks, and then the check algorithm is executed.
// For checks with parameters, preliminary clearing of the previous results need to be performed explicitly using
// this procedure in the check algorithm itself. Otherwise, the same issue will be registered 
// multiple times with several consecutive check startups.
//
// Parameters:
//     Validation                    - CatalogRef.AccountingCheckRules - a check,
//                                   whose results need to be cleared.
//     CheckExecutionParameters - See AccountingAudit.CheckExecutionParameters
//                                 - Array    - several check parameters (array elements of the Structure type,
//                                               as described above).
//
Procedure ClearPreviousCheckResults(Val Validation, Val CheckExecutionParameters) Export
	
	CommonClientServer.CheckParameter("AccountingAudit.ClearPreviousCheckResults", "Validation",
		Validation, Type("CatalogRef.AccountingCheckRules"));
	CheckCheckExecutionParameters(CheckExecutionParameters, "AccountingAudit.ClearPreviousCheckResults");
	
	AccountingAuditInternal.ClearPreviousCheckResults(Validation, CheckExecutionParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to register data integrity issues.

// Generates an issue description for the subsequent registration
// using the AccountingAudit.WriteIssue procedure in the check handler procedure.
//
// Parameters:
//   ObjectWithIssue  - AnyRef - Object the issue relates to.
//   CheckParameters - Structure - parameters of the check being performed, whose value needs to be taken from the similarly named 
//                                   parameter of the check handler procedure:
//     * Validation         - CatalogRef.AccountingCheckRules - Completed check.
//     * CheckKind      - CatalogRef.ChecksKinds - a reference to
//                                                          a check kind.
//     * IssueSeverity   - EnumRef.AccountingIssueSeverity - Severity level that you need to assign to
//                            the found data integrity issue:
//                            Information, Warning, Error, UsefulTip, or ImportantInformation.
//     * Id      - String - Check string ID.
//     * CheckStartDate - Date - a threshold date that indicates the boundary of the checked
//                            objects (only for objects with a date). Do not check objects whose date is less than 
//                            the specified one. Not filled in by default (check all).
//     * IssuesLimit       - Number - Number of objects to check.
//                            By default, 1,000. To check all the objects, set it to 0.
//     * CheckKind        - CatalogRef.ChecksKinds - a reference to
//                            a check kind.
//
// Returns:
//   Structure:
//     * ObjectWithIssue         - AnyRef -
//     * Validation                 - CatalogRef.AccountingCheckRules - a reference to the executed check.
//                                  Taken from the CheckParameters structure.
//     * CheckKind              - CatalogRef.ChecksKinds - Reference to the completed check's kind.
//                                  Defined by the CheckParameters structure.
//     * IssueSeverity         - CatalogRef.ChecksKinds - Reference to the completed check's kind.
//                                  Defined by the CheckParameters structure.
//     * IssueSummary        - String - an issue summary string. Not filled in by default.
//     * UniqueKey         - UUID - Issue uniqueness key.
//     * Detected                 - Date - Time when the issue was detected.
//     * AdditionalInformation - ValueStorage
//                                - Undefined - Arbitrary issue details.
//                                  By default, Undefined.
//     * EmployeeResponsible            - CatalogRef.Users
//                                - Undefined -  
//                                  
//
// Example:
//  Issue = AccountingAudit.IssueDetails(DocumentWithIssue, CheckParameters);
//  Issue.CheckKind = CheckKind;
//  Issue.IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
//    NStr("en = 'There is an unpassed ""%2""'" document by the ""%1"" counterparty), Result.Counterparty, 
//      DocumentWithIssue);
//  AccountingAudit.WriteIssue(Issue, CheckParameters);
//
Function IssueDetails(ObjectWithIssue, CheckParameters) Export
	
	ProcedureName = "AccountingAudit.IssueDetails";
	CommonClientServer.CheckParameter(ProcedureName, "ObjectWithIssue", ObjectWithIssue, 
		Common.AllRefsTypeDetails());
	CommonClientServer.CheckParameter(ProcedureName, "CheckParameters", CheckParameters, Type("Structure"), 
		AccountingAuditInternal.CheckParametersPropertiesExpectedTypes());
		
	Return AccountingAuditInternal.IssueDetails(ObjectWithIssue, CheckParameters);
	
EndFunction

// Saves the check result.
//
// Parameters:
//   Issue1          - See AccountingAudit.IssueDetails.
//   CheckParameters - See AccountingAudit.IssueDetails.CheckParameters.
//
Procedure WriteIssue(Issue1, CheckParameters = Undefined) Export
	
	ProcedureName = "AccountingAudit.WriteIssue";
	CommonClientServer.CheckParameter(ProcedureName, "Issue1", Issue1, Type("Structure"), 
		AccountingAuditInternal.IssueDetailsPropertiesTypesToExpect());
	If CheckParameters <> Undefined Then
		CommonClientServer.CheckParameter(ProcedureName, "CheckParameters", CheckParameters, Type("Structure"), 
			AccountingAuditInternal.CheckParametersPropertiesExpectedTypes());
	EndIf;
	
	AccountingAuditInternal.WriteIssue(Issue1, CheckParameters);
	
EndProcedure

// Sets or clears the flag of ignoring a data integrity issue. 
// When setting the Ignore parameter to True, an issue is no longer displayed to users in object forms 
// and report on the check results. For example, this is useful if a user has decided that 
// the detected issue is not significant or a user does not plan to tackle it.
// When reset to False, the issue becomes relevant again.
//
// Parameters:
//   IssueDetails             - Structure:
//     * ObjectWithIssue         - AnyRef - a reference to object, which the issue is connected to.
//     * CheckRule          - CatalogRef.AccountingCheckRules - an executed check with issue details.
//     * ChecksKind              - CatalogRef.ChecksKinds - check kind.
//     * IssueSummary        - String - a text summary of the found issue.
//     * AdditionalInformation - ValueStorage - additional information on the ignored issue.
//   Ignore - Boolean - a value set to the specified issue.
//
Procedure IgnoreIssue(Val IssueDetails, Val Ignore) Export
	
	ProcedureName = "AccountingAudit.IgnoreIssue";
	CommonClientServer.CheckParameter(ProcedureName, "Ignore", Ignore, Type("Boolean"));
	CommonClientServer.CheckParameter(ProcedureName, "IssueDetails", IssueDetails, Type("Structure"), 
		AccountingAuditInternal.IssueDetailsPropertiesTypesToExpect(False));
	
	AccountingAuditInternal.IgnoreIssue(IssueDetails, Ignore);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for embedding a subsystem in forms of configuration objects.

// In the list form, it displays a column with a picture informing that there are issues with objects in the rows. 
// Called form the OnCreateAtServer event of the list form.
// The dynamic lists needs to have the main table determined. 
//
// Parameters:
//   Form                  - ClientApplicationForm - list form.
//   ListsNames           - String - dynamic list names, separated with commas.
//   AdditionalProperties - Structure
//                          - Undefined - 
//      * ProblemIndicatorFieldID - String - a dynamic list field name that
//                            will be used to show an object problem
//                            indicator.
//
Procedure OnCreateListFormAtServer(Form, ListsNames, AdditionalProperties = Undefined) Export
	
	ProcedureName = "AccountingAudit.OnCreateListFormAtServer";
	CommonClientServer.CheckParameter(ProcedureName, "Form", Form, Type("ClientApplicationForm"));
	CommonClientServer.CheckParameter(ProcedureName, "ListsNames", ListsNames, Type("String"));
	ProblemIndicatorFieldID = Undefined;
	If AdditionalProperties <> Undefined Then
		CommonClientServer.CheckParameter(ProcedureName, "AdditionalProperties", AdditionalProperties, Type("Structure"));
		AdditionalProperties.Property("ProblemIndicatorFieldID", ProblemIndicatorFieldID);
	EndIf;
	
	If Not SubsystemAvailable() Then
		Return;
	EndIf;
	
	GlobalSettings = AccountingAuditInternal.GlobalSettings();
	NamesList          = StrSplit(ListsNames, ",");
	ValuesPicture    = PictureLib.AccountingIssuesSeverityCollection;
	
	For Each ListName In NamesList Do
		FormTable = Form.Items.Find(TrimAll(ListName));
		If FormTable = Undefined Then
			Continue;
		EndIf;
			
		CurrentList   = Form[FormTable.DataPath];
		MainTable = CurrentList.MainTable;
		If Not ValueIsFilled(MainTable) Then
			Continue;
		EndIf;
			
		QueryText = "";
		If CurrentList.CustomQuery Then
			QueryText = CurrentList.QueryText;
		Else
			SchemaToPerform               = FormTable.GetPerformingDataCompositionScheme();
			DynamicListDataSet = SchemaToPerform.DataSets.Find("DynamicListDataSet"); // DataCompositionSchemaDataSetQuery
			If DynamicListDataSet <> Undefined Then
				CurrentList.CustomQuery = True;
				QueryText = DynamicListDataSet.Query;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(QueryText) Or Not StrStartsWith(QueryText, "SELECT") Then // @query-part-1
			Continue;
		EndIf;
			
		If ProblemIndicatorFieldID = Undefined Then
			ColumnName = "ErrorIndicator_" + Common.CheckSumString(Form.FormName + GetPathSeparator() + ListName);
		Else
			ColumnName = ProblemIndicatorFieldID;
		EndIf;
		
		SeparatedName = StrSplit(MainTable, ".");
		
		ComposerAdditionalProperties = CurrentList.SettingsComposer.Settings.AdditionalProperties;
		ComposerAdditionalProperties.Insert("IndicatorColumn",    ColumnName);
		ComposerAdditionalProperties.Insert("MetadataObjectKind", SeparatedName.Get(0));
		ComposerAdditionalProperties.Insert("MetadataObjectName", SeparatedName.Get(1));
		ComposerAdditionalProperties.Insert("ListName",            ListName);
		
		If ProblemIndicatorFieldID = Undefined Then
			DynamicListPropertiesStructure = Common.DynamicListPropertiesStructure();
			FieldToAdd = " 0 AS " + ColumnName + ",";
			QueryAsArray = StrSplit(QueryText, Chars.LF);
			InsertionPosition = Undefined;
			If StrOccurrenceCount(QueryText, "SELECT") > 1 Then // @query-part-1
				IndexOf = 0;
				For Each QueryString In QueryAsArray Do
					If StrStartsWith(TrimAll(QueryString), "SELECT") Then // @query-part-1
						If InsertionPosition = Undefined Then
							InsertionPosition = IndexOf + 1;
						Else
							Break;
						EndIf;
					ElsIf StrStartsWith(TrimAll(QueryString), "INTO") Then
						InsertionPosition = Undefined;
					EndIf;
					IndexOf = IndexOf + 1;
				EndDo;
			Else
				InsertionPosition = 1;
			EndIf;
			QueryAsArray.Insert(InsertionPosition, FieldToAdd);
			DynamicListPropertiesStructure.QueryText = StrConcat(QueryAsArray, Chars.LF);
			Common.SetDynamicListProperties(FormTable, DynamicListPropertiesStructure);
		EndIf;
		
		IndicationColumnParameters = New Structure;
		
		AccountingAuditInternal.OnDetermineIndicatiomColumnParameters(IndicationColumnParameters, MainTable);
		AccountingAuditOverridable.OnDetermineIndicatiomColumnParameters(IndicationColumnParameters, MainTable);
		
		ErrorIndicatorColumn = Form.Items.Add(ColumnName, Type("FormField"), FormTable);
		ErrorIndicatorColumn.Type                = FormFieldType.PictureField;
		ErrorIndicatorColumn.DataPath        = StringFunctionsClientServer.SubstituteParametersToString("%1.%2", ListName, ColumnName);
		ErrorIndicatorColumn.TitleLocation = IndicationColumnParameters.TitleLocation;
		ErrorIndicatorColumn.HeaderPicture      = GlobalSettings.IssuesIndicatorPicture;
		ErrorIndicatorColumn.ValuesPicture   = ValuesPicture;
		ErrorIndicatorColumn.Title          = NStr("en = 'Error indicator';");
		
		ListColumns = FormTable.ChildItems;
		If ListColumns.Count() > 0 Then
			If IndicationColumnParameters.OutputLast Then
				Form.Items.Move(ErrorIndicatorColumn, FormTable);
			Else
				Form.Items.Move(ErrorIndicatorColumn, FormTable, ListColumns.Get(0));
			EndIf;
		EndIf;
		
		FormTable.SetAction("Selection", "Attachable_Selection");
		
	EndDo;
	
EndProcedure

// In the list form, it displays a column with a picture informing that there are issues with objects in the rows. 
// Called from the OnGetDataAtServer event of the list form.
//
// Parameters:
//   Settings              - DataCompositionSettings - contains a copy of dynamic list full settings.
//   Rows                 - DynamicListRows - a collection contains data and design of all the rows
//                            got in the list, except for the grouping rows.
//   KeyFieldName       - String - "Ref" or the specified column name that contains an object reference.
//   AdditionalProperties - Structure
//                          - Undefined - 
//                            
//
Procedure OnGetDataAtServer(Settings, Rows, KeyFieldName = "Ref", AdditionalProperties = Undefined) Export
	
	ProcedureName = "AccountingAudit.OnGetDataAtServer";
	CommonClientServer.CheckParameter(ProcedureName, "Settings", Settings, Type("DataCompositionSettings"));
	CommonClientServer.CheckParameter(ProcedureName, "Rows", Rows, Type("DynamicListRows"));
	CommonClientServer.CheckParameter(ProcedureName, "KeyFieldName", KeyFieldName, Type("String"));
	If AdditionalProperties <> Undefined Then
		CommonClientServer.CheckParameter(ProcedureName, "AdditionalProperties", AdditionalProperties, Type("Structure"));
	EndIf;
	
	If Not SubsystemAvailable() Then
		Return;
	EndIf;
	
	ComposerAdditionalProperties = Settings.AdditionalProperties;
	If ComposerAdditionalProperties.Property("IndicatorColumn") Then
		
		IndicatorColumn = Settings.AdditionalProperties.IndicatorColumn;
		
		If KeyFieldName = "Ref" Then
			RowsKeys = Rows.GetKeys();
			KeyRef = True;
		Else
			StartKeys = Rows.GetKeys();
			KeyRef     = Common.IsReference(Type(StartKeys[0]));
			RowsKeys     = New Array;
			For Each StartKey In StartKeys Do
				RowsKeys.Add(StartKey[KeyFieldName]);
			EndDo;
		EndIf;
		
		ObjectsWithIssues = AccountingAuditInternal.ObjectsWithIssues(RowsKeys, True);
		
		For Each Composite In RowsKeys Do
			
			If KeyRef Then
				AccountingAuditInternal.FillPictureIndex(Rows, Rows[Composite], Composite, IndicatorColumn, ObjectsWithIssues);
			Else
				For Each ListLine In Rows Do
					If ListLine.Key[KeyFieldName] = Composite Then
						AccountingAuditInternal.FillPictureIndex(Rows, ListLine.Value, Composite, IndicatorColumn, ObjectsWithIssues);
					EndIf;
				EndDo;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Displays a group with a picture and a label in the form of an object, informing about issues with this object. 
// Called from the OnReadAtServer event of the object form.
//
// Parameters:
//   Form         - ClientApplicationForm - object form.
//   CurrentObject - DocumentObject - an object that will be read.
//                 - CatalogObject
//                 - ExchangePlanObject
//                 - ChartOfCharacteristicTypesObject
//                 - ChartOfAccountsObject
//                 - ChartOfCalculationTypesObject
//                 - TaskObject
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	ProcedureName = "AccountingAudit.OnReadAtServer";
	CommonClientServer.CheckParameter(ProcedureName, "Form", Form, Type("ClientApplicationForm"));
	CommonClientServer.CheckParameter(ProcedureName, "CurrentObject", CurrentObject, 
		AccountingAuditInternalCached.TypeDetailsAllObjects());
	
	If Not SubsystemAvailable() Then
		Return;
	EndIf;
	
	Settings = AccountingAuditInternal.GlobalSettings();
	Settings.Insert("IssuesCount", 0);
	Settings.Insert("IssueText", "");
	Settings.Insert("IssueSeverity", Undefined);
	Settings.Insert("LastCheckDate", Undefined);
	Settings.Insert("DetailedKind", False);
	
	ObjectReference             = CurrentObject.Ref;
	ManagedFormItems   = Form.Items;
	Settings.IssuesCount = IssuesCountByObject(ObjectReference);
	NamesUniqueKey       = Common.CheckSumString(ObjectReference.Metadata().FullName()
		+ GetPathSeparator() + Form.FormName);
		
	GroupDecoration = ManagedFormItems.Find("ErrorIndicatorGroup_" + NamesUniqueKey);
	
	IndicationGroupParameters = New Structure;
	AccountingAuditInternal.OnDetermineIndicationGroupParameters(IndicationGroupParameters, TypeOf(ObjectReference));
	AccountingAuditOverridable.OnDetermineIndicationGroupParameters(IndicationGroupParameters, TypeOf(ObjectReference));
	
	If Settings.IssuesCount = 0 Then
		If GroupDecoration <> Undefined Then
			ManagedFormItems.Delete(GroupDecoration);
		EndIf;
		Return;
	EndIf;
	Settings.DetailedKind = IndicationGroupParameters.DetailedKind And Settings.IssuesCount = 1;
	If Settings.DetailedKind Then
		FillPropertyValues(Settings, AccountingAuditInternal.ObjectIssueInfo(ObjectReference));
	EndIf;
	
	Settings.LastCheckDate = AccountingAuditInternal.LastObjectCheck(ObjectReference);
	If GroupDecoration <> Undefined Then
		
		LabelDecoration = ManagedFormItems.Find("LabelDecoration_" + NamesUniqueKey);
		If LabelDecoration <> Undefined Then
			LabelDecoration.Title = AccountingAuditInternal.GenerateCommonStringIndicator(Form, ObjectReference, Settings);
		EndIf;
		
	Else
		
		ErrorIndicatorGroup = AccountingAuditInternal.PlaceErrorIndicatorGroup(Form, NamesUniqueKey,
			IndicationGroupParameters.GroupParentName, IndicationGroupParameters.OutputAtBottom);
		
		MainRowIndicator = AccountingAuditInternal.GenerateCommonStringIndicator(Form, ObjectReference, Settings);
		
		AccountingAuditInternal.FillErrorIndicatorGroup(Form, ErrorIndicatorGroup, NamesUniqueKey,
			MainRowIndicator, Settings);
		
	EndIf;
	
EndProcedure

// Starts a background check of the passed object.
// Only those checks are executed by which errors were detected and
// whose SupportsRandomCheck property is True.
// 
// Parameters:
//   CurrentObject - DocumentObject - <MetadataObjectKind>Object.<MetadataObjectName>.
//                 - CatalogObject
//                 - ExchangePlanObject
//                 - ChartOfCharacteristicTypesObject
//                 - ChartOfAccountsObject
//                 - ChartOfCalculationTypesObject
//                 - TaskObject
//
Procedure AfterWriteAtServer(CurrentObject) Export
	Query = New Query;
	Query.Text =
		"SELECT DISTINCT
		|	AccountingCheckResults.CheckRule AS CheckRule
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.ObjectWithIssue = &ObjectWithIssue";
	Query.SetParameter("ObjectWithIssue", CurrentObject.Ref);
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Checks = Result.UnloadColumn("CheckRule");
	If Checks.Count() = 0 Then
		Return;
	EndIf;
	
	TimeConsumingOperations.ExecuteProcedure(, "AccountingAuditInternal.CheckObject", CurrentObject.Ref, Checks);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns True if you have the rights to view data integrity issues.
//
// Returns:
//   Boolean
//
Function SubsystemAvailable() Export
	
	Return AccountingAuditInternal.SubsystemAvailable();
	
EndFunction

// Returns check kinds by passed parameters.
//
// Parameters:
//   ChecksKind                - String
//                              - Array of String 
//                              - CatalogRef.ChecksKinds - 
//                                
//   SearchByExactMap - Boolean - regulates accuracy capabilities. If True, the search is conducted
//                                by the passed properties for equality, other properties must be equal
//                                Undefined (tabular section of additional properties has to be blank).
//                                If False, other property values can be arbitrary, the main thing is
//                                that the corresponding properties need to be equal to the structure properties. Default value is True.
//
// Returns:
//   Array - Items of the CatalogRef.ChecksKinds catalog, or an empty array if there are no search results. 
//            For an exact match search, the array contains one element.
//
Function ChecksKinds(ChecksKind, SearchByExactMap = True) Export
	
	ProcedureName = "AccountingAudit.ChecksKinds";
	CommonClientServer.CheckParameter(ProcedureName, "ChecksKind", ChecksKind, AccountingAuditInternal.TypeDetailsCheckKind());
	CommonClientServer.CheckParameter(ProcedureName, "SearchByExactMap", SearchByExactMap, Type("Boolean"));
	
	Return AccountingAuditInternal.ChecksKinds(ChecksKind, SearchByExactMap);
	
EndFunction

// Returns an existing ChecksKinds catalog item or creates a new one 
// to register or filter records of data check results.
//
// Parameters:
//     CheckExecutionParameters - String - a string ID of a check kind (Property1)
//                                 - Structure - Information records that identify the check kind.
//     SearchOnly - Boolean - If True and the specified check kind does not exist, returns an empty reference. 
//                   If False, creates an item is and returns its reference.
//
// Returns:
//   CatalogRef.ChecksKinds - Existing or a created catalog item.
//      If SearchOnly = True and the item was not found, returns an empty reference to the CatalogRef.ChecksKinds catalog. 
//      
//
// Example:
//   CheckKind = AccountingAudit.CheckKind("SystemChecks");
//
Function CheckKind(Val CheckExecutionParameters, Val SearchOnly = False) Export
	
	AllowedTypes = New Array;
	AllowedTypes.Add(Type("String"));
	AllowedTypes.Add(Type("Structure"));
	CommonClientServer.CheckParameter("AccountingAudit.CheckKind",
		"CheckExecutionParameters", CheckExecutionParameters, AllowedTypes);
	If TypeOf(CheckExecutionParameters) = Type("Structure") Then
		CheckCheckExecutionParameter(CheckExecutionParameters, "AccountingAudit.CheckKind");
	EndIf;
	CommonClientServer.CheckParameter("AccountingAudit.CheckKind", "SearchOnly", SearchOnly, Type("Boolean"));
	
	Return AccountingAuditInternal.CheckKind(CheckExecutionParameters, SearchOnly);
	
EndFunction

// Forcibly updates the list of data integrity checks when changing metadata
// or other settings.
//
Procedure UpdateAccountingChecksParameters() Export
	
	If Not Common.DataSeparationEnabled() Then
		AccountingAuditInternal.UpdateAccountingChecksParameters();
	EndIf;
	
	If AccountingAuditInternal.HasChangesOfAccountingChecksParameters() Then
		AccountingAuditInternal.UpdateAuxiliaryRegisterDataByConfigurationChanges();
	EndIf;
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use DetailedInformationOnChecksKinds instead.
// Returns detailed information about detected issues of the specified check kind.
//
// Parameters:
//   ChecksKind                - CatalogRef.ChecksKinds - a reference to a check kind.
//                              - String - 
//                              - Array of String - 
//   SearchByExactMap - Boolean - regulates accuracy capabilities. If True, the search is conducted
//                                by the passed properties for equality, other properties must be equal
//                                Undefined (tabular section of additional properties has to be blank).
//                                If False, other property values can be arbitrary, the main thing is
//                                that the corresponding properties need to be equal to the structure properties. Default value is True.
//
// Returns:
//   ValueTable:
//     * ObjectWithIssue         - AnyRef - a reference to the object that is the Source of issues.
//     * CheckRule          - CatalogRef.AccountingCheckRules - a reference to the executed check.
//     * IssueSummary        - String - a string summary of the found issue.
//     * IssueSeverity         - EnumRef.AccountingIssueSeverity - Issue severity:
//                                  Information, Warning, Error, or UsefulTip.
//     * EmployeeResponsible            - CatalogRef.Users - it is filled in if it is possible
//                                  to identify a person responsible for the problematic object.
//     * AdditionalInformation - ValueStorage - Internal property with additional issue info.
//                                  
//     * Detected                 - Date - Server time when the issue was identified.
//
// Example:
//   1) Result = DetailedInformationOnChecksKinds("SystemChecks");
//   2) ChecksKind = New Array;
//      ChecksKind.Add("MonthEndClosing");
//      ChecksKind.Add(Company);
//      ChecksKind.Add(ClosingMonth);
//      Result = DetailedInformationOnChecksKinds(ChecksKind);
//
Function DetailedInformationOnCheckKinds(ChecksKind, SearchByExactMap = True) Export
	
	ProcedureName = "AccountingAudit.DetailedInformationOnChecksKinds";
	CommonClientServer.CheckParameter(ProcedureName, "ChecksKind", ChecksKind, AccountingAuditInternal.TypeDetailsCheckKind());
	CommonClientServer.CheckParameter(ProcedureName, "SearchByExactMap", SearchByExactMap, Type("Boolean"));
	
	DetailedInformation = New ValueTable;
	ChecksKindsArray = New Array;
	
	If TypeOf(ChecksKind) = Type("CatalogRef.ChecksKinds") Then
		ChecksKindsArray.Add(ChecksKind);
	Else
		ChecksKindsArray = AccountingAuditInternal.ChecksKinds(ChecksKind, SearchByExactMap);
	EndIf;
	
	If ChecksKindsArray.Count() = 0 Then
		Return DetailedInformation;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
	|	AccountingCheckResults.IssueSeverity AS IssueSeverity,
	|	AccountingCheckResults.CheckRule AS CheckRule,
	|	AccountingCheckResults.CheckKind AS CheckKind
	|FROM
	|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
	|WHERE
	|	NOT AccountingCheckResults.IgnoreIssue
	|	AND AccountingCheckResults.CheckKind IN (&ChecksKindsArray)");
	
	Query.SetParameter("ChecksKindsArray", ChecksKindsArray);
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		DetailedInformation = Result.Unload();
	EndIf;
	
	Return DetailedInformation;
	
EndFunction

// Deprecated. Obsolete. Use SummaryInformationOnChecksKinds instead.
// Sums up the detected issue amount for the specified check kind.
//
// Parameters:
//   ChecksKind                - CatalogRef.ChecksKinds - a reference to a check kind.
//                              - String - 
//                              - Array of String - 
//   SearchByExactMap - Boolean - regulates accuracy capabilities. If True, the search is conducted
//                                by the passed properties for equality, other properties must be equal
//                                Undefined (tabular section of additional properties has to be blank).
//                                If False, other property values can be arbitrary, the main thing is
//                                that the corresponding properties need to be equal to the structure properties. Default value is True.
//
// Returns:
//  Structure:
//    * Count - Number - a total number of the issues found.
//    * HasErrors - Boolean - indicates whether the detected issues include issues with the Error severity.
//
// Example:
//   1) Result = SummaryInformationOnChecksKinds("SystemChecks");
//   2) ChecksKind = New Array;
//      ChecksKind.Add("MonthEndClosing");
//      ChecksKind.Add(Company);
//      ChecksKind.Add(ClosingMonth);
//      Result = SummaryInformationOnChecksKinds(ChecksKind);
//
Function SummaryInformationOnCheckKinds(ChecksKind, SearchByExactMap = True) Export
	
	ProcedureName = "AccountingAudit.SummaryInformationOnChecksKinds";
	CommonClientServer.CheckParameter(ProcedureName, "ChecksKind", ChecksKind, AccountingAuditInternal.TypeDetailsCheckKind());
	CommonClientServer.CheckParameter(ProcedureName, "SearchByExactMap", SearchByExactMap, Type("Boolean"));
	
	SummaryInformation = New Structure;
	SummaryInformation.Insert("Count", 0);
	SummaryInformation.Insert("HasErrors", False);
	
	ChecksKindsArray = New Array;
	If TypeOf(ChecksKind) = Type("CatalogRef.ChecksKinds") Then
		ChecksKindsArray.Add(ChecksKind);
	Else
		ChecksKindsArray = AccountingAuditInternal.ChecksKinds(ChecksKind, SearchByExactMap);
		If ChecksKindsArray.Count() = 0 Then
			Return SummaryInformation;
		EndIf;
	EndIf;
	
	Query = New Query(
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
	|	NOT AccountingCheckResults.IgnoreIssue
	|	AND AccountingCheckResults.CheckKind IN (&ChecksKindsArray)");
	
	Query.SetParameter("ChecksKindsArray", ChecksKindsArray);
	Result = Query.Execute().Select();
	Result.Next();
	
	FillPropertyValues(SummaryInformation, Result);
	
	Return SummaryInformation;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

Function ObjectsWithIssues(CheckRule, Offset = Undefined, Batch = 1000) Export
	
	Query = New Query;
	QueryText = "SELECT TOP 1000
		|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
		|	AccountingCheckResults.CheckRule AS CheckRule,
		|	AccountingCheckResults.CheckKind AS CheckKind,
		|	AccountingCheckResults.UniqueKey AS UniqueKey
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.CheckRule = &CheckRule
		|	AND NOT AccountingCheckResults.IgnoreIssue
		|	AND AccountingCheckResults.ObjectWithIssue > &ObjectWithIssue
		|
		|ORDER BY
		|	AccountingCheckResults.ObjectWithIssue";
	
	If Batch = 1000 Then
		QueryText = StrReplace(QueryText, "1000", Format(Batch, "NG=0"));
	EndIf;
	Query.Text = QueryText;
	
	If Offset = Undefined Then
		Offset = "";
	EndIf;
	
	Query.SetParameter("CheckRule",  CheckRule);
	Query.SetParameter("ObjectWithIssue", Offset);
	
	Return Query.Execute().Unload();
	
EndFunction

Function ObjectsWithIssuesByCheckKind(CheckKind, Offset = Undefined, Batch = 1000) Export
	
	Query = New Query;
	QueryText = "SELECT TOP 1000
		|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
		|	AccountingCheckResults.CheckRule AS CheckRule,
		|	AccountingCheckResults.CheckKind AS CheckKind,
		|	AccountingCheckResults.UniqueKey AS UniqueKey
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.CheckKind = &CheckKind
		|	AND NOT AccountingCheckResults.IgnoreIssue
		|	AND AccountingCheckResults.ObjectWithIssue > &ObjectWithIssue
		|
		|ORDER BY
		|	AccountingCheckResults.ObjectWithIssue";
	
	If Batch = 1000 Then
		QueryText = StrReplace(QueryText, "1000", Format(Batch, "NG=0"));
	EndIf;
	Query.Text = QueryText;
	
	If Offset = Undefined Then
		Offset = "";
	EndIf;
	
	Query.SetParameter("CheckKind",      CheckKind);
	Query.SetParameter("ObjectWithIssue", Offset);
	
	Return Query.Execute().Unload();
	
EndFunction

Procedure ClearResultByCheckKind(ObjectWithIssue, CheckKind) Export
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.AccountingCheckResults");
	DataLockItem.SetValue("ObjectWithIssue", ObjectWithIssue);
	DataLockItem.SetValue("CheckKind",      CheckKind);
	
	BeginTransaction();
	
	Try
		
		DataLock.Lock();
		
		Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
		Set.Filter.ObjectWithIssue.Set(ObjectWithIssue);
		Set.Filter.CheckKind.Set(CheckKind);
		Set.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Procedure ClearCheckResult(ObjectWithIssue, CheckRule) Export
	
	BeginTransaction();
	
	Try
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add("InformationRegister.AccountingCheckResults");
		DataLockItem.SetValue("ObjectWithIssue", ObjectWithIssue);
		DataLockItem.SetValue("CheckRule", CheckRule);
		DataLock.Lock();
		
		Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
		Set.Filter.ObjectWithIssue.Set(ObjectWithIssue);
		Set.Filter.CheckRule.Set(CheckRule);
		Set.Clear();
		Set.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Procedure ClearResultOnCheck(Validation) Export
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.AccountingCheckResults");
	DataLockItem.SetValue("CheckRule", Validation);
	
	BeginTransaction();
	
	Try
		DataLock.Lock();
		
		Set = InformationRegisters.AccountingCheckResults.CreateRecordSet();
		Set.Filter.CheckRule.Set(Validation);
		Set.Filter.IgnoreIssue.Set(False);
		Set.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckCheckExecutionParameters(CheckExecutionParameters, NameOfAProcedureOrAFunction)
	
	If TypeOf(CheckExecutionParameters) = Type("Structure") Then
		ExecutionParameters = New Array;
		ExecutionParameters.Add(CheckExecutionParameters);
		CheckExecutionParameters = ExecutionParameters;
	EndIf;
	
	CommonClientServer.CheckParameter(NameOfAProcedureOrAFunction, "CheckExecutionParameters",
		CheckExecutionParameters, Type("Array"));
	
	For Each CheckParameter1 In CheckExecutionParameters Do
		CheckCheckExecutionParameter(CheckParameter1, NameOfAProcedureOrAFunction);
	EndDo;

EndProcedure

Procedure CheckCheckExecutionParameter(CheckParameter1, NameOfAProcedureOrAFunction)
	
	CommonClientServer.CheckParameter(NameOfAProcedureOrAFunction, "CheckExecutionParameters.Item",
		CheckParameter1, Type("Structure"));
	For Each CurrentParameter In CheckParameter1 Do
		CommonClientServer.CheckParameter(NameOfAProcedureOrAFunction,
		CurrentParameter.Key, CurrentParameter.Value, AccountingAuditInternal.ExpectedPropertiesTypesOfChecksKinds());
	EndDo;

EndProcedure

Function EventLogEvent()
	
	Return NStr("en = 'Data integrity';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion


