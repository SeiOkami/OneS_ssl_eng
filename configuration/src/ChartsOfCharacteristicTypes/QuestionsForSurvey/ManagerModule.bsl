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
		|	QuestionsForSurvey.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
		|WHERE
		|	(QuestionsForSurvey.RadioButtonType = VALUE(Enum.RadioButtonTypesInQuestionnaires.EmptyRef)
		|			OR QuestionsForSurvey.CheckBoxType = VALUE(Enum.CheckBoxKindsInQuestionnaires.EmptyRef)
		|			OR QuestionsForSurvey.MinValue <> 0
		|				AND NOT QuestionsForSurvey.ShouldUseMinValue
		|			OR QuestionsForSurvey.MaxValue <> 0
		|				AND NOT QuestionsForSurvey.ShouldUseMaxValue)
		|	AND NOT QuestionsForSurvey.IsFolder";
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Fill in a value of the new RadioButtonType attribute for the the QuestionsForSurvey chart of characteristic types.
// 
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "ChartOfCharacteristicTypes.QuestionsForSurvey");
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While Selection.Next() Do
		RepresentationOfTheReference = String(Selection.Ref);
		Try
			
			FillNewAttributes(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;

		Except
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process the question for survey %1 due to:
					|%2';"), 
				RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.ChartsOfCharacteristicTypes.QuestionsForSurvey, Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "ChartOfCharacteristicTypes.QuestionsForSurvey");

	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some survey questions: %1';"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.ChartsOfCharacteristicTypes.QuestionsForSurvey,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Another batch of survey questions is processed: %1';"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Fills in values of the new RadioButtonType and CheckBoxType attributes for the passed object.
//   
// Parameters:
//   QuestionForSurvey - ChartOfCharacteristicTypesRef.QuestionsForSurvey 
//
Procedure FillNewAttributes(QuestionForSurvey)
	
	BeginTransaction();
	Try
	
		Block = New DataLock;
		LockItem = Block.Add("ChartOfCharacteristicTypes.QuestionsForSurvey");
		LockItem.SetValue("Ref", QuestionForSurvey);
		Block.Lock();
		
		Object = QuestionForSurvey.GetObject();
		
		If Object.RadioButtonType = Enums.RadioButtonTypesInQuestionnaires.EmptyRef() Then
			Object.RadioButtonType = Enums.RadioButtonTypesInQuestionnaires.RadioButton;
		EndIf;
		
		If Object.CheckBoxType = Enums.CheckBoxKindsInQuestionnaires.EmptyRef() Then
			Object.CheckBoxType = Enums.CheckBoxKindsInQuestionnaires.CheckBox;
		EndIf;    
			
		If ValueIsFilled(Object.MinValue) Then
			Object.ShouldUseMinValue = True;
		EndIf;
		
		If ValueIsFilled(Object.MaxValue) Then
			Object.ShouldUseMaxValue = True;
		EndIf;
		
		InfobaseUpdate.WriteData(Object);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure
	
#EndRegion

#EndIf