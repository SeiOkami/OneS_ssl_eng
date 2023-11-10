///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// To call from the AccountingCheckResults report command.
//
// Parameters:
//  ReportDetailsData -  DataCompositionDetailsData
//  SpreadsheetDocument - SpreadsheetDocument
//  DetailsIndex - Number
//                    - Undefined
// Returns:
//  Boolean
// 
Function IgnoreIssue(ReportDetailsData, SpreadsheetDocument, DetailsIndex) Export
	Result = SelectedCellDetails(ReportDetailsData, SpreadsheetDocument, DetailsIndex);
	If Result = Undefined Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ObjectWithIssue", Result.ObjectWithIssue);
	Query.SetParameter("CheckRule", Result.CheckRule);
	Query.SetParameter("CheckKind", Result.CheckKind);
	Query.Text = 
		"SELECT
		|	AccountingCheckResults.IgnoreIssue AS IgnoreIssue
		|FROM
		|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
		|WHERE
		|	AccountingCheckResults.ObjectWithIssue = &ObjectWithIssue
		|	AND AccountingCheckResults.CheckRule = &CheckRule
		|	AND AccountingCheckResults.CheckKind = &CheckKind";
	Value = Query.Execute().Unload()[0].IgnoreIssue;
	
	AccountingAudit.IgnoreIssue(Result, Not Value);
	
	RowFound = False;
	For LineNumber = 1 To SpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			Area = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			If Area.Details <> DetailsIndex Then
				Continue;
			EndIf;
			RowFound = True;
			Break;
		EndDo;
		If RowFound Then
			Break;
		EndIf;
	EndDo;
	
	If RowFound Then
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			Area = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
			If Value Then
				LastRow = SpreadsheetDocument.TableHeight;
				TextColor = SpreadsheetDocument.Area(LastRow, 1, LastRow, 1).TextColor;
				If TextColor <> Undefined Then
					Area.TextColor = TextColor;
				EndIf;
			Else
				Area.TextColor = StyleColors.InaccessibleCellTextColor;
			EndIf;
		EndDo;
	EndIf;
	
	Return True;
EndFunction

// To call from the AccountingCheckResults report command.
//
Function DataForObjectChangeHistory(ReportDetailsData, SpreadsheetDocument, DetailsIndex) Export
	Details = SelectedCellDetails(ReportDetailsData, SpreadsheetDocument, DetailsIndex);
	If Details = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Ref", Details.ObjectWithIssue);
	Result.Insert("ToVersion", False);
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		Result.ToVersion = ModuleObjectsVersioning.ObjectVersioningEnabled(Details.FullObjectName);
	EndIf;
	
	Return Result;
EndFunction

// To call from the AccountingCheckResults report.
//
Function SelectedCellDetails(ReportDetailsData, SpreadsheetDocument, DetailsIndex) Export
	If DetailsIndex = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ObjectWithIssue");
	Result.Insert("CheckRule");
	Result.Insert("CheckKind");
	Result.Insert("IssueSummary");
	Result.Insert("FullObjectName");
	
	DetailsData = GetFromTempStorage(ReportDetailsData); // DataCompositionDetailsData
	Details       = DetailsData.Items[DetailsIndex].GetFields();
	Value          = Details[0].Value;
	ValueInParts   = StrSplit(Value, ";");
	
	If ValueInParts.Count() < 5 Then
		Return Undefined;
	EndIf;
	
	ObjectManager = Common.ObjectManagerByFullName(ValueInParts[0]);
	Result.ObjectWithIssue = ObjectManager.GetRef(New UUID(ValueInParts[1]));
	Result.CheckRule  = Catalogs.AccountingCheckRules.GetRef(New UUID(ValueInParts[2]));
	Result.CheckKind      = Catalogs.ChecksKinds.GetRef(New UUID(ValueInParts[3]));
	Result.IssueSummary = ValueInParts[4];
	Result.FullObjectName = ValueInParts[0];
	
	Return Result;
EndFunction

#EndRegion