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
	
	Object.SurveyMode = Enums.SurveyModes.Questionnaire;
	If Parameters.Property("SurveyMode") Then
		Object.SurveyMode = Parameters.SurveyMode;
		Object.Respondent = Parameters.Respondent;
	Else
		CurrentUser = Users.AuthorizedUser();
		If TypeOf(CurrentUser) <> Type("CatalogRef.ExternalUsers") Then 
			Object.Respondent = CurrentUser;
		Else	
			Object.Respondent = ExternalUsers.GetExternalUserAuthorizationObject(CurrentUser);
		EndIf;
	EndIf;
	
	RespondentQuestionnairesTable();
	 
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_Questionnaire" Or EventName = "PostingQuestionnaire" Then
		RespondentQuestionnairesTable();
	EndIf;
	
EndProcedure 

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure QuestionnairesTreeBeforeChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.QuestionnairesTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.QuestionnaireSurvey) = Type("DocumentRef.Questionnaire") Then
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Key",CurrentData.QuestionnaireSurvey);
		ParametersStructure.Insert("FillingFormOnly", True);
		ParametersStructure.Insert("SurveyMode", Object.SurveyMode);
		ParametersStructure.Insert("Title", CurrentData.Presentation);
		OpenForm("Document.Questionnaire.ObjectForm", ParametersStructure, Item);
	ElsIf TypeOf(CurrentData.QuestionnaireSurvey) = Type("DocumentRef.PollPurpose") Then
		ParametersStructure = New Structure;
		FillingValues 	= New Structure;
		FillingValues.Insert("Respondent", Object.Respondent);
		FillingValues.Insert("Survey", CurrentData.QuestionnaireSurvey);
		FillingValues.Insert("SurveyMode", Object.SurveyMode);
		ParametersStructure.Insert("Title", CurrentData.Presentation);
		ParametersStructure.Insert("FillingValues", FillingValues);
		ParametersStructure.Insert("FillingFormOnly", True);
		OpenForm("Document.Questionnaire.ObjectForm", ParametersStructure, Item, CurrentData.Presentation);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ArchivedQuestionnaires(Command)
	
	OpenForm("DataProcessor.AvailableQuestionnaires.Form.ArchivedQuestionnaires",New Structure("Respondent",Object.Respondent),ThisObject);
	
EndProcedure 

&AtClient
Procedure Refresh(Command)
	
	RespondentQuestionnairesTable();
	
EndProcedure 

#EndRegion

#Region Private

&AtServer
Procedure RespondentQuestionnairesTable()
	
	QuestionnairesTable.Clear();
	
	ReceivedQuestionnairesTable = Surveys.TableOfQuestionnairesAvailableToRespondent(Object.Respondent);
	
	If ReceivedQuestionnairesTable <> Undefined Then
		
		For Each TableRow In ReceivedQuestionnairesTable Do
			
			NewRow = QuestionnairesTable.Add();
			If Not ValueIsFilled(TableRow.QuestionnaireSurvey) Then
				
				NewRow.Presentation = TableRow.Status;
				NewRow.Status        = TableRow.Status;
				
			Else
				
				NewRow.Status        = TableRow.Status;
				NewRow.QuestionnaireSurvey   = TableRow.QuestionnaireSurvey;
				NewRow.Presentation = GetQuestionnaireTreeRowsPresentation(TableRow);
				
			EndIf;
			
			NewRow.PictureCode = ?(TableRow.Status = "Surveys",0,1);
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Generates a row presentation for the questionnaires tree.
//
// Parameters:
//  TreeRow  - ValueTreeRow - based on it, a presentation of questionnaires 
//                 and surveys in the tree is generated.
//
&AtServer
Function GetQuestionnaireTreeRowsPresentation(TreeRow)
	
	If TypeOf(TreeRow.QuestionnaireSurvey) = Type("DocumentRef.PollPurpose") Then
		If ValueIsFilled(TreeRow.EndDate) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" must be filled out by %2';"),
				TreeRow.Description, Format(BegOfDay(EndOfDay(TreeRow.EndDate) + 1), "DLF=D"));
		Else	
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1""';"), TreeRow.Description);
		EndIf;
	ElsIf TypeOf(TreeRow.QuestionnaireSurvey) = Type("DocumentRef.Questionnaire") Then
		If ValueIsFilled(TreeRow.QuestionnaireDate) And ValueIsFilled(TreeRow.EndDate) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" was last edited on %2 and must be filled out by %3';"), 
				TreeRow.Description, Format(TreeRow.QuestionnaireDate, "DLF=D"),
				Format(BegOfDay(EndOfDay(TreeRow.EndDate) + 1), "DLF=D"));
		ElsIf ValueIsFilled(TreeRow.QuestionnaireDate) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" was last edited on %2';"), 
				TreeRow.Description, Format(TreeRow.QuestionnaireDate, "DLF=D"));
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1""';"), TreeRow.Description);
		EndIf;
	EndIf;
	Return "";
	
EndFunction

#EndRegion
