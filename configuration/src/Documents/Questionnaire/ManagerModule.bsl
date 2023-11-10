///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Respondent");
	Result.Add("EditDate");
	Result.Add("Comment");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	Questionnaire.Ref
		|FROM
		|	Document.Questionnaire AS Questionnaire
		|WHERE
		|	Questionnaire.SurveyMode = &EmptyRef
		|
		|ORDER BY
		|	Questionnaire.Date DESC";
	Query.Parameters.Insert("EmptyRef", Enums.SurveyModes.EmptyRef());
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Fill in a value of the new SurveyMode attribute in the Questionnaire document.
// 
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Document.Questionnaire");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While Selection.Next() Do
		RepresentationOfTheReference = String(Selection.Ref);
		Try
			
			FillSurveyModeAttribute(Selection);
			ObjectsProcessed = ObjectsProcessed + 1;
			
		Except
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process questionnaire %1 due to:
					|%2';"), 
					RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Documents.Questionnaire, Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Document.Questionnaire");
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some questionnaires: %1';"), ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Documents.Questionnaire,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of questionnaires is processed: %1';"), ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Fills a value of the new SurveyMode attribute in the passed document.
//
Procedure FillSurveyModeAttribute(Selection)
	
	BeginTransaction();
	Try
	
		Block = New DataLock;
		LockItem = Block.Add("Document.Questionnaire");
		LockItem.SetValue("Ref", Selection.Ref);
		Block.Lock();
		
		DocumentObject = Selection.Ref.GetObject();
		
		If DocumentObject.SurveyMode <> Enums.SurveyModes.EmptyRef() Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			CommitTransaction();
			Return;
		EndIf;
		
		DocumentObject.SurveyMode = Enums.SurveyModes.Questionnaire;
		
		InfobaseUpdate.WriteData(DocumentObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf