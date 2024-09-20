///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens a report on all issues of the passed issue type.
//
// Parameters:
//   ChecksKind - CatalogRef.ChecksKinds - a reference to a check kind.
//               - String - 
//               - Array of String - 
//   ExactMap - Boolean - If True, filter only by the given check kind.
//                 If False, select all check kinds related to the passed kind.
//
// Example:
//   OpenIssuesReport("SystemChecks");
//
Procedure OpenIssuesReport(ChecksKind, ExactMap = True) Export
	
	// 
	// 
	
	AccountingAuditInternalClient.OpenIssuesReport(ChecksKind, ExactMap);
	
EndProcedure

// Open the report form when clicking the hyperlink that informs of having issues.
//
//  Parameters:
//     Form                - ClientApplicationForm - a form of an object with issues.
//     ObjectWithIssue     - AnyRef - a reference to an object with issues.
//     StandardProcessing - Boolean - a flag indicating whether
//                            the standard (system) event processing is executed is passed to this parameter.
//
// Example:
//    AccountingAuditClient.OpenObjectProblemsReport(ThisObject, Object.Ref, StandardProcessing);
//
Procedure OpenObjectIssuesReport(Form, ObjectWithIssue, StandardProcessing) Export
	
	// 
	// 
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ObjectReference", ObjectWithIssue);
	
	OpenForm("Report.AccountingCheckResults.Form", FormParameters);
	
EndProcedure

// Open the report form, double clicking the cell of the list form table with a picture,
// which informs that the selected object has some issues.
//
//  Parameters:
//     Form                   - ClientApplicationForm - a form of an object with issues.
//     ListName               - String - the name of the target dynamic list as the form attribute.
//     Field                    - FormField - a column containing picture
//                               that informs of existing issues.
//     StandardProcessing    - Boolean - a flag indicating whether
//                               the standard (system) event processing is executed is passed to this parameter.
//     AdditionalParameters - Structure
//                             - Undefined - 
//                               
//
// Example:
//    AccountingAuditClient.OpenListedIssuesReport("ThisObject", "List", Field, StandardProcessing);
//
Procedure OpenListedIssuesReport(Form, ListName, Field, StandardProcessing, AdditionalParameters = Undefined) Export
	
	ProcedureName = "AccountingAuditClient.OpenListedIssuesReport";
	CommonClientServer.CheckParameter(ProcedureName, "Form", Form, Type("ClientApplicationForm"));
	CommonClientServer.CheckParameter(ProcedureName, "ListName", ListName, Type("String"));
	CommonClientServer.CheckParameter(ProcedureName, "Field", Field, Type("FormField"));
	CommonClientServer.CheckParameter(ProcedureName, "StandardProcessing", StandardProcessing, Type("Boolean"));
	If AdditionalParameters <> Undefined Then
		CommonClientServer.CheckParameter(ProcedureName, "AdditionalParameters", AdditionalParameters, Type("Structure"));
	EndIf;
	
	AdditionalProperties = Form[ListName].SettingsComposer.Settings.AdditionalProperties;
	
	If Not (AdditionalProperties.Property("IndicatorColumn")
		And AdditionalProperties.Property("MetadataObjectKind")
		And AdditionalProperties.Property("MetadataObjectName")
		And AdditionalProperties.Property("ListName")) Then
		StandardProcessing = True;
	Else
		
		FormTable   = Form.Items.Find(AdditionalProperties.ListName);
		
		If Field.Name <> AdditionalProperties.IndicatorColumn Then
			StandardProcessing = True;
		Else
			CurrentData = Form.Items[ListName].CurrentData;
			If CurrentData[Field.Name] = 0 Then
				Return; // No errors by object.
			EndIf;
			
			StandardProcessing = False;
			
			ContextData = New Structure;
			ContextData.Insert("SelectedRows",     FormTable.SelectedRows);
			ContextData.Insert("MetadataObjectKind", AdditionalProperties.MetadataObjectKind);
			ContextData.Insert("MetadataObjectName", AdditionalProperties.MetadataObjectName);
			
			FormParameters = New Structure;
			FormParameters.Insert("ContextData", ContextData);
			OpenForm("Report.AccountingCheckResults.Form", FormParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
