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
	
	SetConditionalAppearance();
	
	If Parameters.Property("Respondent") Then
		Object.Respondent = Parameters.Respondent;
	Else
		SetRespondentAccordingToCurrentExternalUser();
	EndIf;
	SetDynamicListParametersOfQuestionnairesTree();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompletedSurveysValueChoice(Item, Value, StandardProcessing)
	
	CurrentData = Items.CompletedSurveys.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Key",CurrentData.Ref);
	ParametersStructure.Insert("FillingFormOnly",True);
	ParametersStructure.Insert("ReadOnly",True);
	
	OpenForm("Document.Questionnaire.ObjectForm", ParametersStructure,Item);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDynamicListParametersOfQuestionnairesTree()
	
	For Each AvailableParameter In CompletedSurveys.Parameters.AvailableParameters.Items Do
		
		If AvailableParameter.Title = "Respondent" Then
			CompletedSurveys.Parameters.SetParameterValue(AvailableParameter.Parameter,Object.Respondent);
		EndIf;
		
	EndDo;
	
EndProcedure 

&AtServer
Procedure SetRespondentAccordingToCurrentExternalUser()
	
	CurrentUser = Users.AuthorizedUser();
	If TypeOf(CurrentUser) <> Type("CatalogRef.ExternalUsers") Then 
		Object.Respondent = CurrentUser;
	Else	
		Object.Respondent = ExternalUsers.GetExternalUserAuthorizationObject(CurrentUser);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "CompletedSurveys.FillingDate", Items.FillingDate.Name);
	
EndProcedure

#EndRegion
