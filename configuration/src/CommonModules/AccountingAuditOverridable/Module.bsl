///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Allows to set the subsystem common settings.
//
// Parameters:
//   Settings - Structure:
//     * IssuesIndicatorPicture    - Picture - that will be displayed as an error
//                                      indicator in the column of the dynamic list form
//                                      list and on the special object form panel.
//     * IssuesIndicatorNote   - String - a text that describes an error.
//     * IssuesIndicatorHyperlink - String - a text of a hyperlink, by clicking which
//                                      you can generate and open a report with errors.
//
// Example:
//   Settings = New Structure;
//   Settings.Insert("IssuesIndicatorPicture",    PictureLib.Warning);
//   Settings.Insert("ErrorNoteText", Undefined);
//   Settings.Insert("IssuesIndicatorHyperlink", Undefined);
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Adds custom data integrity check rules.
//
// Parameters:
//   ChecksGroups - ValueTable - a table, where check groups are added:
//      * Description                 - String - a check group description.
//      * GroupID          - String - a string ID of the check group, for example: 
//                                       "SystemChecks", "MonthEndClosing", "VATChecks", and so on.
//                                       Required.
//      * Id                - String - a string ID of the check group. Required.
//                                       For uniqueness, select the ID format as follows:
//                                       <Software name>.<Check ID>.For example: 
//                                       StandardSubsystems.SystemChecks".
//      * AccountingChecksContext - DefinedType.AccountingChecksContext - a value that additionally
//                                       specifies the belonging of a data integrity check group to a certain
//                                       category.
//      * Comment                  - String - a comment to a check group.
//
//   Checks - ValueTable - a table, where checks are added:
//      * GroupID          - String - a string ID of the check group, for example: 
//                                                "SystemChecks", "MonthEndClosing", "VATChecks", and so on.
//                                                 Required.
//      * Description                 - String - a check description displayed to a user.
//      * Reasons                      - String - a description of possible reasons that result in issue appearing.
//      * Recommendation                 - String - a recommendation on solving an appeared issue.
//      * Id                - String - an item string ID. Required.
//                                                The ID format has to be as follows:
//                                                <Software name>.<Check ID>.For example:
//                                                StandardSubsystems.SystemChecks.
//      * CheckStartDate           - Date - a threshold date that indicates the boundary of the checked
//                                              objects (only for objects with a date). Do not check objects whose date is less than 
//                                              the specified one. Not filled in 
//                                              by default (check all).
//      * IssuesLimit                 - Number - a number of the checked objects. The default value is 1000. 
//                                               If 0 is specified, check all objects.
//      * HandlerChecks           - String - a name of the export handler procedure of the server common
//                                                module as ModuleName.ProcedureName.
//      * GoToCorrectionHandler - String - a name of the export handler procedure for client common module
//                                                  to start correcting an issue in the form of "ModuleName.ProcedureName"
//                                                  or the full name of the form that needs to be opened to correct the issue.
//                                                  The handler procedure accepts two parameters for input: 
//                                                    CorrectionParameters - Structure - a structure with the following properties:
//                                                      CheckID - String - a string check ID.
//                                                      CheckKind - CatalogRef.ChecksKinds - a check kind
//                                                               that narrows the area of issue correction.
//                                                    AdditionalParameters - Undefined - the parameter is not used.
//                                                 When a form is opened, the same parameters are passed to it as the properties 
//                                                 of the above-mentioned CorrectionParameters structure.
//      * NoCheckHandler       - Boolean - a flag of the service check that does not have the handler procedure.
//      * ImportanceChangeDenied   - Boolean - if True, the administrator cannot change 
//                                                the importance of this check.
//      * AccountingChecksContext - DefinedType.AccountingChecksContext - a value that additionally 
//                                                specifies the belonging of a data integrity check to a certain group 
//                                                or category.
//      * AccountingCheckContextClarification - DefinedType.AccountingCheckContextClarification - a value 
//                                                 that additionally specifies the belonging of a data integrity check 
//                                                 to a certain group or category.
//      * AdditionalParameters      - ValueStorage - an arbitrary additional check information
//                                                 for program use.
//      * Comment                  - String - a text comment to the check.
//      * isDisabled                    - Boolean - if True, the check will not be performed in the background on schedule.
//      * SupportsRandomCheck - Boolean - if True, a check can be called to check a certain object.
//
// Example:
//   1) Adding a check
//      Check = Checks.Add();
//      Check.GroupID = "SystemChecks";
//      Check.Description = NStr("en='Demo: Check of filling the comment in the ""Demo: Goods receipt""'" documents);
//      Check.Reasons = NStr("en='Comment is not entered in the document."');
//      Check.Recommendation = NStr("en='Enter comment to the document.'");
//      Check.ID = "CheckCommentInGoodsReceipt";
//      Check.CheckHandler = "_DemoStandardSubsystems.CheckCommentInGoodsReceipt";
//      Check.CheckStartDate = Date('20140101000000');
//      Check.IssuesLimit = 3;
//   2) Adding a group of checks
//      ChecksGroup = ChecksGroups.Add();
//      ChecksGroup.Description = NStr("en='System Checks'");
//      ChecksGroup.ID = "StandardSubsystems.SystemChecks";
//      ChecksGroup.AccountingChecksContext = "SystemChecks";
//
Procedure OnDefineChecks(ChecksGroups, Checks) Export
	
EndProcedure

// Allows you to adjust the indicator position on issues in object forms.
//
// Parameters:
//   IndicationGroupParameters - Structure - indicator output parameters:
//     * OutputAtBottom     - Boolean - if True is set, the indicator group will be displayed the last 
//                           in the form or at the end of the specified GroupParentName group of items.
//                           False by default - a group is displayed in the beginning of the specified GroupParentName group or 
//                           below the object form command bar.
//     * GroupParentName - String - determines the name of an object form group of items that need to 
//                           contain the indication group.
//     * DetailedKind      - Boolean - if True and only one issue is detected for the object, its details will be
//                           immediately displayed on the card instead of a hyperlink with a transition to the list of issues.
//                           The default value is False.
//
//   ObjectWithIssueType - Type - a type of the reference, for which the indication group parameters are overridden.
//                     For example, TypeOf("DocumentRef.PayrollAccrual").
//
Procedure OnDetermineIndicationGroupParameters(IndicationGroupParameters, Val ObjectWithIssueType) Export
	
EndProcedure

// Allows you to customize the kind and position of the indicator column about issues in the list forms
// (with a dynamic list).
//
// Parameters:
//   IndicationColumnParameters - Structure - indicator output parameters:
//     * OutputLast  - Boolean - if True is set, the indicator column will be displayed at the end.
//                            False by default - the column is displayed in the beginning.
//     * TitleLocation - FormItemTitleLocation - sets the position of the indicator column title.
//     * Width             - Number - an indicator column width.
//
//   FullName - String - object full name of the main dynamic list table.
//                        For example, Metadata.Documents.PayrollAccrual.FullName().
//
Procedure OnDetermineIndicatiomColumnParameters(IndicationColumnParameters, FullName) Export
	
EndProcedure

// Allows you to add information about an issue before registering it.
// In particular, you can fill in additional values for restricting access 
// to the list of data integrity issues at the record level.
//
// Parameters:
//   Issue1 - Structure - information on the issue generated by the check algorithm:
//     * ObjectWithIssue         - AnyRef - the object, because of which the issue is being saved.
//                                                Or a reference to the MetadataObjectIDs catalog item
//     * CheckRule          - CatalogRef.AccountingCheckRules - a reference to the executed check.
//     * CheckKind              - CatalogRef.ChecksKinds - a reference to 
//                                  a check kind.
//     * UniqueKey         - UUID - Issue uniqueness key.
//     * IssueSummary        - String - a string summary of the found issue.
//     * IssueSeverity         - EnumRef.AccountingIssueSeverity - Severity level of a data integrity issue
//                                  Information, Warning, Error, UsefulTip and ImportantInformation.
//     * EmployeeResponsible            - CatalogRef.Users - it is filled in if it is possible
//                                  to identify a person responsible for the problematic object.
//     * IgnoreIssue     - Boolean - a flag of ignoring an issue. If the value is True,
//                                  the subsystem ignores the record about an issue.
//     * AdditionalInformation - ValueStorage - a service property with additional
//                                  information related to the detected issue.
//     * Detected                 - Date - server time of the issue identification.
//
//   ObjectReference  - AnyRef - a reference to the source object of values for
//                     additional dimensions to be added.
//   Attributes       - MetadataObjectCollection - a collection containing attributes of the issue source
//                     object.
//
Procedure BeforeWriteIssue(Issue1, ObjectReference, Attributes) Export
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete: Use the OnDefineChecks function.
// Adds custom data integrity check rules.
//
// Parameters:
//   ChecksGroups - ValueTable - a table, where check groups are added:
//      * Description  - String - a description of the group of checks, for example, "System checks".
//      * Id - String - a group string ID, for example, "SystemChecks".
//
//   Checks - ValueTable - a table, where checks are added:
//      * Description                   - String - a description of the check item. Required.
//      * Reasons                        - String - possible reasons that have lead to an issue.
//                                                  Displayed in the report on issues. Not required.
//      * Recommendation                   - String - a recommendation on solving an appeared issue.
//                                                  Displayed in the report on issues. Not required.
//      * Id                  - String - a check string ID. Required.
//      * ParentID          - String - a string ID of check group, for example, "SystemChecks".
//                                                  Required.
//      * CheckStartDate             - Date - a threshold date that indicates the boundary of the checked
//                                         objects (only for objects with a date). Do not check objects whose date is less than
//                                         the specified one. Not filled in by default (check all).
//      * IssuesLimit                   - Number - the maximum number of the checked objects.
//                                         0 by default - check all objects.
//      * HandlerChecks             - String - an export check handler procedure name in the server common module.
//                                         Designed for searching and registering data integrity issues.
//                                         Check handler parameters:
//                                           * Validation - CatalogRef.AccountingCheckRules - a check being executed.
//                                           * CheckParameters - Structure - parameters of the check that needs to be executed.
//                                                                             For more information, see the documentation. 
//      * GoToCorrectionHandler - String - a client handler procedure name 
//                                         in the client common module or a full name of the form that will open to
//                                         correct an issue. The issue or form correction handler parameters:
//                                          * CheckID - String - an ID of the check 
//                                                                    that has detected an issue.
//                                          * CheckKind - CatalogRef.ChecksKinds - a check kind 
//                                                          that narrows the area of issue correction.
//      * AdditionalParameters        - ValueStorage - an additional information on the check.
//
// Example:
//   Check = Checks.Add();
//   Check.GroupID = "SystemChecks";
//   Check.Description        = NStr("en='Demo: Check of filling the comment in the ""Demo: Goods receipt""'" documents);
//   Check.Reasons            = NStr("en='Comment is not entered in the document."');
//   Check.Recommendation        = NStr("en='Enter comment to the document.'");
//   Check.ID       = "CheckCommentInGoodsReceipt";
//   Check.CheckHandler  = "_DemoStandardSubsystems.CheckCommentInGoodsReceipt";
//   Check.CheckStartDate  = Date('20140101000000');
//   Check.IssuesLimit        = 3;
//
Procedure OnDefineAppliedChecks(ChecksGroups, Checks) Export
	
EndProcedure

#EndRegion

#EndRegion



