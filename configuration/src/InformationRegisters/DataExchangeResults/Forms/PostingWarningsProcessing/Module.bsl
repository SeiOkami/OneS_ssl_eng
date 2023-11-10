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
Procedure PostDocuments(Command)
	
	ParametersOfTheEvent = New Structure;
	ParametersOfTheEvent.Insert("NumberOfDaysSpent", 0);
	ParametersOfTheEvent.Insert("TotalCount1", 0);
	
	HoldDocumentsOnTheServer(ParametersOfTheEvent);
	
	If ParametersOfTheEvent.NumberOfDaysSpent > 0 Then
		
		Notify("CorrectionOfDocumentSynchronizationWarnings");
		
	EndIf;
	
	ClearMessages();
	If ParametersOfTheEvent.NumberOfDaysSpent <> ParametersOfTheEvent.TotalCount1 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Posted documents: %1 from %2.';"),
			Format(ParametersOfTheEvent.NumberOfDaysSpent, "NZ=; NG=0"),
			Format(ParametersOfTheEvent.TotalCount1, "NZ=; NG=0"));
		
		ShowMessageBox(Undefined, ErrorMessage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectAllCommand(Command)
	
	ChangeTheLineMark(True);
	
EndProcedure

&AtClient
Procedure RemoveSelection(Command)
	
	ChangeTheLineMark(False);
	
EndProcedure

&AtClient
Procedure PostInDeveloperMode(Command)
	
	Items.TableOfCorrectionObjectsSpendInDeveloperMode.Check 
		= Not Items.TableOfCorrectionObjectsSpendInDeveloperMode.Check;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeTheLineMark(MarkValue)
	
	For Each SelectedRow In PatchObjectsTable Do
		
		SelectedRow.ProcessString = MarkValue;
		
	EndDo;
	
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
	
	For Each ObjectWithIssue In Parameters.DataForSelectedRows Do
		
		NewRow = PatchObjectsTable.Add();
		NewRow.ProcessString = True;
		NewRow.ObjectWithIssue = ObjectWithIssue;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure HoldDocumentsOnTheServer(ParametersOfTheEvent)
	
	WarningTemplate = NStr("en = 'The [%1] document was not posted due to filling check errors. 
		|To fix the issue, open the document and post it manually.';", Common.DefaultLanguageCode());
	
	
	For Each SelectedRow In PatchObjectsTable Do
		
		If Not SelectedRow.ProcessString Then
			
			Continue;
			
		EndIf;
		
		ParametersOfTheEvent.TotalCount1 = ParametersOfTheEvent.TotalCount1 + 1;
		
		BeginTransaction();
		Try
			
			LockDataForEdit(SelectedRow.ObjectWithIssue);
			
			DocumentObject = SelectedRow.ObjectWithIssue.GetObject();
			If DocumentObject.CheckFilling() Then
				
				If Items.TableOfCorrectionObjectsSpendInDeveloperMode.Check Then
					
					DocumentObject.DataExchange.Load = True;
					
				EndIf;
				
				DocumentObject.Write(DocumentWriteMode.Posting);
				
				SelectedRow.PatchResult = NStr("en = 'Document successfully posted.';");
				ParametersOfTheEvent.NumberOfDaysSpent = ParametersOfTheEvent.NumberOfDaysSpent + 1;
				
			Else
				
				SelectedRow.PatchResult = StrTemplate(WarningTemplate, SelectedRow.ObjectWithIssue);
				SelectedRow.UnsuccessfulAttempt = True;
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			SelectedRow.PatchResult = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			SelectedRow.UnsuccessfulAttempt = True;
			
		EndTry;
		
	EndDo;
	
	
EndProcedure

#EndRegion
