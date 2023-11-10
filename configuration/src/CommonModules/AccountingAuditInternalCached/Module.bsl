///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Generates the structure of check tables and check groups for further use.
//
// Returns:
//    Structure:
//       * ChecksGroups - See AccountingAuditInternalCached.ChecksGroupsNewTable
//       * Checks       - See AccountingAuditInternalCached.NewChecksTable
//
Function AccountingChecks() Export
	
	ChecksGroups = ChecksGroupsNewTable();
	Checks       = NewChecksTable();
	
	AddAccountingSystemChecks(ChecksGroups, Checks);
	
	SSLSubsystemsIntegration.OnDefineChecks(ChecksGroups, Checks);
	AccountingAuditOverridable.OnDefineChecks(ChecksGroups, Checks);
	
	// 
	AccountingAuditOverridable.OnDefineAppliedChecks(ChecksGroups, Checks);
	ProvideReverseCompatibility(Checks);
	
	Return New FixedStructure("ChecksGroups, Checks", ChecksGroups, Checks);
	
EndFunction

// Returns an array of types that includes all possible configuration object types.
//
// Returns:
//    Array - 
//
Function TypeDetailsAllObjects() Export
	
	TypesArray = New Array;
	
	MetadataKindsArray = New Array;
	MetadataKindsArray.Add(Metadata.Documents);
	MetadataKindsArray.Add(Metadata.Catalogs);
	MetadataKindsArray.Add(Metadata.ExchangePlans);
	MetadataKindsArray.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataKindsArray.Add(Metadata.ChartsOfAccounts);
	MetadataKindsArray.Add(Metadata.ChartsOfCalculationTypes);
	MetadataKindsArray.Add(Metadata.Tasks);
	
	For Each MetadataKind In MetadataKindsArray Do
		For Each MetadataObject In MetadataKind Do
			
			SeparatedName = StrSplit(MetadataObject.FullName(), ".");
			If SeparatedName.Count() < 2 Then
				Continue;
			EndIf;
			
			TypesArray.Add(Type(SeparatedName.Get(0) + "Object." + SeparatedName.Get(1)));
			
		EndDo;
	EndDo;
	
	Return New FixedArray(TypesArray);
	
EndFunction

Function ObjectsToExcludeFromCheck() Export
	
	Objects = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsToExcludeFromCheck(Objects);
	
	Names = New Array;
	For Each Object In Objects Do
		Names.Add(Object.FullName());
	EndDo;
	
	Return New FixedArray(Names);
	
EndFunction

#EndRegion

#Region Private

// See AccountingAuditOverridable.OnDefineChecks
Procedure AddAccountingSystemChecks(ChecksGroups, Checks)
	
	ChecksGroup = ChecksGroups.Add();
	ChecksGroup.Description                 = NStr("en = 'System checks';");
	ChecksGroup.Id                = "SystemChecks";
	ChecksGroup.AccountingChecksContext = "SystemChecks";
	
	Validation = Checks.Add();
	Validation.GroupID          = ChecksGroup.Id;
	Validation.Description                 = NStr("en = 'Check for empty required attributes';");
	Validation.Reasons                      = NStr("en = 'Invalid data synchronization with external applications or data import.';");
	Validation.Recommendation                 = NStr("en = 'Reconfigure data synchronization or fill the mandatory attributes manually.
		|Batch modification of attributes (the Administration section) can be used for this purpose.
		|If unfilled mandatory attributes are found in registers,
		| generally, you only need to fill in the corresponding fields in the recorder document to eliminate this issue.';");
	Validation.Id                = "StandardSubsystems.CheckBlankMandatoryAttributes";
	Validation.HandlerChecks           = "AccountingAuditInternal.CheckUnfilledRequiredAttributes";
	Validation.AccountingChecksContext = "SystemChecks";
	Validation.SupportsRandomCheck = True;
	Validation.isDisabled                      = True;
	
	Validation = Checks.Add();
	Validation.GroupID          = ChecksGroup.Id;
	Validation.Description                 = NStr("en = 'Reference integrity check';");
	Validation.Reasons                      = NStr("en = 'Accidental or intentional data deletion without reference integrity control, equipment failures, Invalid data synchronization with external applications or data import, errors in third-party tools (such as external data processors or extensions).';");
	Validation.Recommendation                 = NStr("en = 'Depending on the situation, select one of the following options:
		|• Restore deleted data from backup.
		|• Clear references to deleted data (if this is no longer needed).';");
	If Not Common.DataSeparationEnabled() Then
		Validation.Recommendation = Validation.Recommendation + Chars.LF + Chars.LF 
			+ NStr("en = 'To clear references to deleted data, do the following:
			|• Terminate all user sessions, lock the application, and create an infobase backup.
			|• Open Designer, open Administration – Verify and Repair menu, select the check boxes for logical integrity check and referential integrity check.
			| For more information, see ITS: https://its.1c.ru/db/v83doc#bookmark:adm:TI000000142.
			|• Wait for verification and repair to complete, and unlock the application.
			|
			|For distributed infobases, run the repair procedure for the master node only.
			|After that, perform synchronization with subordinate nodes.To clear references to deleted data, do the following:
			|• Terminate all user sessions, lock the application, and create an infobase backup.
			|• Open Designer, open Administration – Verify and Repair menu, select the check boxes for logical integrity check and referential integrity check.
			| For more information, see ITS: https://its.1c.eu/db/v83doc#bookmark:adm:TI000000142.
			|• Wait for verification and repair to complete, and unlock the application.
			|
			|For distributed infobases, run the repair procedure for the master node only.
			|After that, perform synchronization with subordinate nodes.';");
	
	EndIf;
	Validation.Recommendation = Validation.Recommendation + Chars.LF
		+ NStr("en = 'If some dead references are detected in registers, usually, it is enough to remove dead references
		|in recording documents to eliminate the issue.';");
	Validation.Id                = "StandardSubsystems.CheckReferenceIntegrity1";
	Validation.HandlerChecks           = "AccountingAuditInternal.CheckReferenceIntegrity";
	Validation.AccountingChecksContext = "SystemChecks";
	Validation.SupportsRandomCheck = True;
	Validation.isDisabled                      = True;
	
	Validation = Checks.Add();
	Validation.GroupID            = ChecksGroup.Id;
	Validation.Description                   = NStr("en = 'Check for circular references';");
	Validation.Reasons                        = NStr("en = 'Invalid data synchronization with external applications or data import.';");
	Validation.Recommendation                   = NStr("en = 'In one of the items, remove a reference to the parent item (click the hyperlink below to fix the issue automatically).
		|For distributed infobases, run the repair procedure for the master node only.
		|After that, perform synchronization with subordinate nodes.';");
	Validation.Id                  = "StandardSubsystems.CheckCircularRefs1";
	Validation.HandlerChecks             = "AccountingAuditInternal.CheckCircularRefs";
	Validation.GoToCorrectionHandler = "Report.AccountingCheckResults.Form.AutoCorrectIssues";
	Validation.AccountingChecksContext   = "SystemChecks";
	Validation.isDisabled                      = True;
	
	Validation = Checks.Add();
	Validation.GroupID            = ChecksGroup.Id;
	Validation.Description                   = NStr("en = 'Check for missing predefined items';");
	Validation.Reasons                        = NStr("en = 'Invalid data synchronization with external applications or data import, errors in third-party tools (such as external data processors or extensions).';");
	Validation.Recommendation                   = NStr("en = 'Depending on the situation, do one of the following:
		|• Select and specify one of existing items in the list as a predefined item. 
		|• Restore predefined items from backup.
		|• Create missing predefined items again (to do this, click the link below).';"); 
	If Not Common.DataSeparationEnabled() Then
		Validation.Recommendation = Validation.Recommendation + Chars.LF
			+ NStr("en = 'For distributed infobases, run the repair procedure for the master node only.
			|After that, perform synchronization with subordinate nodes.';");
	EndIf;
	Validation.Id                  = "StandardSubsystems.CheckNoPredefinedItems";
	Validation.HandlerChecks             = "AccountingAuditInternal.CheckMissingPredefinedItems";
	Validation.GoToCorrectionHandler = "Report.AccountingCheckResults.Form.AutoCorrectIssues";
	Validation.AccountingChecksContext   = "SystemChecks";
	Validation.isDisabled                      = True;
	
	Validation = Checks.Add();
	Validation.GroupID          = ChecksGroup.Id;
	Validation.Description                 = NStr("en = 'Check for duplicate predefined items';");
	Validation.Reasons                      = NStr("en = 'Invalid data synchronization with external applications or data import.';");
	Validation.Recommendation                 = NStr("en = 'Run duplicate cleaner in the Administration section.';");
	If Not Common.DataSeparationEnabled() Then
		Validation.Recommendation = Validation.Recommendation + Chars.LF  
			+ NStr("en = 'For distributed infobases, run the repair procedure for the master node only.
			|After that, perform synchronization with subordinate nodes.';");
	EndIf;
	Validation.Id                = "StandardSubsystems.CheckDuplicatePredefinedItems1";
	Validation.HandlerChecks           = "AccountingAuditInternal.CheckDuplicatePredefinedItems";
	Validation.AccountingChecksContext = "SystemChecks";
	Validation.isDisabled                    = True;
	
	Validation = Checks.Add();
	Validation.GroupID          = ChecksGroup.Id;
	Validation.Description                 = NStr("en = 'Check for missing predefined nodes in exchange plan';");
	Validation.Reasons                      = NStr("en = 'Incorrect application behavior when running on an obsolete 1C:Enterprise version';");
	If Common.DataSeparationEnabled() Then
		Validation.Recommendation             = NStr("en = 'Contact technical service support.';");
	Else	
		Validation.Recommendation             = NStr("en = '• Upgrade 1C:Enterprise to 8.3.9.2033 or later
			|• Terminate all user sessions, lock the application, and create an infobase backup
			|• Open Designer, open Administration – Verify and Repair menu, select the check boxes for logical integrity check and referential integrity check
			| For more details, refer to ITS: https://its.1c.eu/db/v83doc#bookmark:adm:TI000000142
			|• Wait for verification and repair to complete, and unlock the application
			|
			|For distributed infobases, run the repair procedure for the master node only.
			|After that, perform synchronization with subordinate nodes.';");
	EndIf;
	Validation.Id                = "StandardSubsystems.CheckNoPredefinedExchangePlansNodes";
	Validation.HandlerChecks           = "AccountingAuditInternal.CheckPredefinedExchangePlanNodeAvailability";
	Validation.AccountingChecksContext = "SystemChecks";
	Validation.isDisabled                    = True;
	
EndProcedure

// Creates a table of check groups
//
// Returns:
//   ValueTable:
//      * Description                 - String - a check group description.
//      * GroupID          - String - a string ID of the check group, for example: 
//                                       "SystemChecks", "MonthEndClosing", "VATChecks", and so on.
//                                       Required.
//      * Id                - String - a string ID of the check group. Required.
//                                       The ID format has to be as follows:
//                                       <Software name>.<Check ID>.For example:
//                                       StandardSubsystems.SystemChecks.
//      * AccountingChecksContext - DefinedType.AccountingChecksContext - a value that additionally
//                                       specifies the belonging of a data integrity check group to a certain category.
//      * Comment                  - String - a comment to a check group.
//
Function ChecksGroupsNewTable() Export
	
	ChecksGroups        = New ValueTable;
	ChecksGroupColumns = ChecksGroups.Columns;
	ChecksGroupColumns.Add("Description",                 New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksGroupColumns.Add("Id",                New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksGroupColumns.Add("GroupID",          New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksGroupColumns.Add("AccountingChecksContext", Metadata.DefinedTypes.AccountingChecksContext.Type);
	ChecksGroupColumns.Add("Comment",                  New TypeDescription("String", , , , New StringQualifiers(256)));
	
	Return ChecksGroups;
	
EndFunction

// Creates a check table.
//
// Returns:
//   ValueTable:
//      * GroupID                    - String - a string ID of the check group, for example: 
//                                                 "SystemChecks", "MonthEndClosing", "VATChecks", and so on.
//                                                 Required.
//      * Description                           - String - a check description displayed to a user.
//      * Reasons                                - String - a description of possible reasons that result in issue
//                                                 appearing.
//      * Recommendation                           - String - a recommendation on solving an appeared issue.
//      * Id                          - String - an item string ID. Required.
//                                                 The ID format has to be as follows:
//                                                 <Software name>.<Check ID>.For example:
//                                                 StandardSubsystems.SystemChecks.
//      * CheckStartDate                     - Date - a threshold date that indicates the boundary of the checked
//                                                 objects (only for objects with a date). Do not check objects whose date is less
//                                                 than the specified one. It is not filled in by default (
//                                                 check all).
//      * IssuesLimit                           - Number - a number of the checked objects. The default value is 1000. 
//                                                 If 0 is specified, check all objects.
//      * HandlerChecks                     - String - a name of the export handler procedure of the server common 
//                                                 module as ModuleName.ProcedureName. 
//      * GoToCorrectionHandler         - String - a name of the export handler procedure for client common 
//                                                 module to start correcting an issue in the form of "ModuleName.ProcedureName.
//      * NoCheckHandler                 - Boolean - a flag of the service check that does not have the handler procedure.
//      * ImportanceChangeDenied             - Boolean - if True, the administrator cannot change 
//                                                 the importance of this check.
//      * AccountingChecksContext           - DefinedType.AccountingChecksContext - a value that additionally 
//                                                 specifies the belonging of a data integrity check to a certain group 
//                                                 or category.
//      * AccountingCheckContextClarification - DefinedType.AccountingCheckContextClarification - a value 
//                                                 that additionally specifies the belonging of a data integrity check 
//                                                 to a certain group or category.
//      * AdditionalParameters                - ValueStorage - an additional check information for program
//                                                 use.
//      * Comment                            - String - a comment to the check.
//      * isDisabled                              - Boolean - if True, the check will not be performed in the background on schedule.
//
Function NewChecksTable() Export
	
	Checks        = New ValueTable;
	ChecksColumns = Checks.Columns;
	ChecksColumns.Add("GroupID",                    New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("Description",                           New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("Reasons",                                New TypeDescription("String"));
	ChecksColumns.Add("Recommendation",                           New TypeDescription("String"));
	ChecksColumns.Add("Id",                          New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("CheckStartDate",                     New TypeDescription("Date", , , , , New DateQualifiers(DateFractions.DateTime)));
	ChecksColumns.Add("IssuesLimit",                           New TypeDescription("Number", , , New NumberQualifiers(8, 0, AllowedSign.Nonnegative)));
	ChecksColumns.Add("HandlerChecks",                     New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("GoToCorrectionHandler",         New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("NoCheckHandler",                 New TypeDescription("Boolean"));
	ChecksColumns.Add("ImportanceChangeDenied",             New TypeDescription("Boolean"));
	ChecksColumns.Add("AccountingChecksContext",           Metadata.DefinedTypes.AccountingChecksContext.Type);
	ChecksColumns.Add("AccountingCheckContextClarification", Metadata.DefinedTypes.AccountingCheckContextClarification.Type);
	ChecksColumns.Add("AdditionalParameters",                New TypeDescription("ValueStorage"));
	ChecksColumns.Add("ParentID",                  New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("Comment",                            New TypeDescription("String", , , , New StringQualifiers(256)));
	ChecksColumns.Add("isDisabled",                              New TypeDescription("Boolean"));
	ChecksColumns.Add("SupportsRandomCheck",         New TypeDescription("Boolean"));
	Checks.Indexes.Add("Id");
	
	Return Checks;
	
EndFunction

Procedure ProvideReverseCompatibility(Checks)
	
	For Each Validation In Checks Do
		
		If ValueIsFilled(Validation.GroupID) Then
			Continue;
		EndIf;
		
		Validation.GroupID = Validation.ParentID;
		
	EndDo;
	
EndProcedure

#EndRegion