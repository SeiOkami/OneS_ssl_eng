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
	Result.Add("IsRequired");
	Result.Add("Notes");
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
		|	QuestionnaireTemplateQuestions.Ref
		|FROM
		|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
		|WHERE
		|	QuestionnaireTemplateQuestions.HintPlacement = &EmptyRef";
	Query.Parameters.Insert("EmptyRef", Enums.TooltipDisplayMethods.EmptyRef());
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Assign a value to the HintPlacement attribute in the QuestionnaireTemplateQuestions catalog.
// 
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.QuestionnaireTemplateQuestions");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While Selection.Next() Do
		RepresentationOfTheReference = String(Selection.Ref);
		Try
			
			FillTooltipDisplayMethodAttribute(Selection);
			ObjectsProcessed = ObjectsProcessed + 1;
			
		Except
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process questionnaire template question %1 due to:
					|%2';"), 
					RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.QuestionnaireTemplateQuestions, Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.QuestionnaireTemplateQuestions");
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some questionnaire template questions: %1';"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.QuestionnaireTemplateQuestions,,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Yet another batch of questionnaire template questions is processed: %1';"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Assign a value to the HintPlacement attribute in the passed object.
//
Procedure FillTooltipDisplayMethodAttribute(Selection)
	
	BeginTransaction();
	Try
	
		Block = New DataLock;
		LockItem = Block.Add("Catalog.QuestionnaireTemplateQuestions");
		LockItem.SetValue("Ref", Selection.Ref);
		Block.Lock();
		
		CatalogObject = Selection.Ref.GetObject();
		
		If CatalogObject.HintPlacement <> Enums.TooltipDisplayMethods.EmptyRef() Then
			RollbackTransaction();
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			Return;
		EndIf;
		
		CatalogObject.HintPlacement = Enums.TooltipDisplayMethods.AsTooltip;
		
		InfobaseUpdate.WriteData(CatalogObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
