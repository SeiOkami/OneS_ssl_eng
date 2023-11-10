///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("DataForSelectedRows") Then
		
		Raise NStr("en = 'The form cannot be used independently.';", Common.DefaultLanguageCode());
		
	EndIf;
	
	ConditionalFormDesign();
	FillInTheFormTable();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectAllCommand(Command)
	
	ChangeTheLineMark(True);
	
EndProcedure

&AtClient
Procedure RemoveSelection(Command)
	
	ChangeTheLineMark(False);
	
EndProcedure

&AtClient
Procedure ShowDifferences(Command)
	
	ShowDifferencesBetweenObjectVersions();
	
EndProcedure

&AtClient
Procedure ReviseResult(Command)
	
	QueryText = NStr("en = 'Revise the conflict results for the marked lines?';");
	
	NotifyDescription = New NotifyDescription("ReviewTheResultsOfCollisions", ThisObject);
	
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ReviewTheResultsOfCollisions(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	RevisionParameters = New Structure;
	RevisionParameters.Insert("NumberOfRevised", 0);
	RevisionParameters.Insert("TotalCount1", 0);
	
	ReviewTheResultsOnTheServer(RevisionParameters);
	
	If RevisionParameters.NumberOfRevised > 0 Then
		
		Notify("FixingSynchronizationWarningsReviewingCollisions");
		
	EndIf;
	
	ClearMessages();
	If RevisionParameters.NumberOfRevised <> RevisionParameters.TotalCount1 Then
		
		MessageTemplate = NStr("en = 'Lines selected: %1. Objects changed: %2.';", CommonClient.DefaultLanguageCode());
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate,
			Format(RevisionParameters.TotalCount1, "NZ=; NG=0"),
			Format(RevisionParameters.NumberOfRevised, "NZ=; NG=0"));
		
		ShowMessageBox(Undefined, ErrorMessage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenThisApplicationVersion(Command)
	
	OpenVersionAtClient("ThisApplicationVersion");
	
EndProcedure

&AtClient
Procedure OpenOtherApplicationVersion(Command)
	
	OpenVersionAtClient("VersionFromOtherApplication");
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ShowDifferencesBetweenObjectVersions()
	
	TheCurrentDataRow = Items.PatchObjectsTable.CurrentData;
	If TheCurrentDataRow = Undefined Then
		
		Return;
		
	EndIf;
	
	VersionsToCompare = New Array;
	
	If TheCurrentDataRow.ThisApplicationVersion <> 0 Then
		
		VersionsToCompare.Add(TheCurrentDataRow.ThisApplicationVersion);
		
	EndIf;
	
	If TheCurrentDataRow.VersionFromOtherApplication <> 0 Then
		
		VersionsToCompare.Add(TheCurrentDataRow.VersionFromOtherApplication);
		
	EndIf;
	
	If VersionsToCompare.Count() <> 2 Then
		
		MessageText = NStr("en = 'No object version to compare.';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, MessageText);
		Return;
		
	EndIf;
	
	OpenVersionComparisonReport(TheCurrentDataRow.ObjectWithIssue, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure ChangeTheLineMark(MarkValue)
	
	For Each SelectedRow In PatchObjectsTable Do
		
		SelectedRow.ProcessString = MarkValue;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenVersionAtClient(FieldVersion)
	
	CurrentData = Items.PatchObjectsTable.CurrentData;
	If CurrentData = Undefined Then
		
		Return;
		
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(CurrentData[FieldVersion]);
	
	OpenVersionComparisonReport(CurrentData.ObjectWithIssue, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		ModuleObjectsVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
		ModuleObjectsVersioningClient.OpenVersionComparisonReport(Ref, VersionsToCompare);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ConditionalFormDesign()
	
	ErrorsInRed = ConditionalAppearance.Items.Add();
	
	CommonClientServer.AddCompositionItem(ErrorsInRed.Filter, "PatchObjectsTable.UnsuccessfulAttempt", DataCompositionComparisonType.Equal, True);
	ErrorsInRed.Appearance.SetParameterValue("TextColor", WebColors.DarkRed);
	
	AppearanceField = ErrorsInRed.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TableOfCorrectionObjectsObjectWithIssue");
	AppearanceField = ErrorsInRed.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TableOfObjectsOfCorrectionTheResultOfThe");
	AppearanceField = ErrorsInRed.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("TableOfCorrectionObjectsFailedAttempt");
	
EndProcedure

&AtServer
Procedure FillInTheFormTable()
	
	If TypeOf(Parameters.DataForSelectedRows) <> Type("Array") Then
		
		Return;
		
	EndIf;
	
	For Each RowData In Parameters.DataForSelectedRows Do
		
		NewRow = PatchObjectsTable.Add();
		FillPropertyValues(NewRow, RowData);
		NewRow.ProcessString = True;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ReviewTheResultsOnTheServer(RevisionParameters)
	
	If Not Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		Return;
		
	EndIf;
	
	ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
	ErrorTextTemplate = NStr("en = 'Cannot change the object version due to:%1%2';", Common.DefaultLanguageCode());
	
	For Each SelectedRow In PatchObjectsTable Do
		
		If Not SelectedRow.ProcessString Then
			
			Continue;
			
		EndIf;
		
		RevisionParameters.TotalCount1 = RevisionParameters.TotalCount1 + 1;
		
		Try
			
			ModuleObjectsVersioning.OnStartUsingNewObjectVersion(SelectedRow.ObjectWithIssue, SelectedRow.VersionFromOtherApplication);
			RevisionParameters.NumberOfRevised = RevisionParameters.NumberOfRevised + 1;
			
		Except
			
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			
			SelectedRow.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate, Chars.LF, ErrorText);
			SelectedRow.UnsuccessfulAttempt = True;
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion
