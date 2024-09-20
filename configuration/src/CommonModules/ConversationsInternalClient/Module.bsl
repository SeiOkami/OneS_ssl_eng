///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Function Connected2() Export
	
	Return ConversationsInternalServerCall.Connected2();
	
EndFunction

Procedure ShowConnection(CompletionDetails = Undefined) Export
	
	OpenForm("DataProcessor.EnableDiscussions.Form",,,,,, CompletionDetails);
	
EndProcedure

Procedure ShowDisconnection() Export
	
	If Not ConversationsInternalServerCall.Connected2() Then 
		ShowMessageBox(, NStr("en = 'Conversations are already disabled.';"));
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Disconnect", NStr("en = 'Disable';"));
	Buttons.Add(DialogReturnCode.No);
	
	Notification = New NotifyDescription("AfterResponseToDisablePrompt", ThisObject);
	
	ShowQueryBox(Notification, NStr("en = 'Do you want to disable conversations?';"),
		Buttons,, DialogReturnCode.No);
	
EndProcedure

Procedure AfterWriteUser(Form, CompletionDetails) Export
	
	If Not Form.SuggestDiscussions Then
		ExecuteNotifyProcessing(CompletionDetails);
		Return;
	EndIf;
	
	Form.SuggestDiscussions = False;
		
	CompletionNotification2 = New NotifyDescription("SuggestDiscussionsCompletion", ThisObject, CompletionDetails);
	QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionParameters.PromptDontAskAgain = True;
	QuestionParameters.Title = NStr("en = 'Conversations (collaboration system)';");
	StandardSubsystemsClient.ShowQuestionToUser(CompletionNotification2, Form.SuggestConversationsText,
		QuestionDialogMode.YesNo, QuestionParameters);
	
EndProcedure

Procedure OnGetCollaborationSystemUsersChoiceForm(ChoicePurpose, Form, ConversationID, Parameters, SelectedForm, StandardProcessing) Export

	Parameters.Insert("SelectConversationParticipants", True);
	Parameters.Insert("ChoiceMode", True);
	Parameters.Insert("CloseOnChoice", False);
	Parameters.Insert("MultipleChoice", True);
	Parameters.Insert("AdvancedPick", True);
	Parameters.Insert("SelectedUsers", New Array);
	Parameters.Insert("PickFormHeader", NStr("en = 'Conversation members';"));
	
	StandardProcessing = False;
	
	SelectedForm = "Catalog.Users.ChoiceForm";

EndProcedure

Procedure ShowSettingOfIntegrationWithExternalSystems() Export
	OpenForm("DataProcessor.EnableDiscussions.Form.SettingsOfMessagesFromOtherApplications",,ThisObject);
EndProcedure

#EndRegion

#Region Private

Procedure StartPickingConversationParticipants(Item) Export
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	FormParameters.Insert("MultipleChoice", True);
	FormParameters.Insert("AdvancedPick", True);
	FormParameters.Insert("SelectedUsers", New Array);
	FormParameters.Insert("PickFormHeader", NStr("en = 'Conversation members';"));
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters,Item,,,,,FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

Procedure ShowIntegrationInformation(Form, IntegrationDetails, IntegrationChangeNotification) Export

	Notification = New NotifyDescription("IntegrationCreationCompletion", ThisObject,
		New Structure("Notification", IntegrationChangeNotification));
		
	IntegrationTypes = ConversationsInternalClientServer.ExternalSystemsTypes();
	FormName = "DataProcessor.EnableDiscussions.Form";
	If IntegrationDetails.Type = IntegrationTypes.Telegram Then
		FormName = FormName + ".BotCreationTelegram";
	ElsIf IntegrationDetails.Type = IntegrationTypes.VKontakte Then	
		FormName = FormName + ".BotCreationVKontakte";
	EndIf;
		
	OpenForm(FormName,
		IntegrationDetails,
		Form,,,,
		Notification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

Procedure IntegrationCreationCompletion(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.Notification, True);

EndProcedure

Procedure AfterResponseToDisablePrompt(ReturnCode, Context) Export
	
	If ReturnCode = "Disconnect" Then 
		OnDisconnect();
	EndIf;
	
EndProcedure

Procedure OnDisconnect()
	
	Notification = New NotifyDescription("AfterDisconnectSuccessfully", ThisObject,,
		"OnProcessDisableDiscussionError", ThisObject);
	
	Try
		CollaborationSystem.BeginInfoBaseUnregistration(Notification);
	Except
		OnProcessDisableDiscussionError(ErrorInfo(), False, Undefined);
	EndTry;
	
EndProcedure

Procedure AfterDisconnectSuccessfully(Context) Export
	
	Notify("ConversationsEnabled", False);
	
EndProcedure

Procedure OnProcessDisableDiscussionError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Conversations.An error occurred when unregistering infobase';",
			CommonClient.DefaultLanguageCode()),
		"Error",
		ErrorProcessing.DetailErrorDescription(ErrorInfo),, True);
	
	ErrorProcessing.ShowErrorInfo(ErrorInfo);
	
EndProcedure

Procedure SuggestDiscussionsCompletion(Result, CompletionDetails) Export
	
	If Result = Undefined Then
		ExecuteNotifyProcessing(CompletionDetails);
		Return;
	EndIf;
	
	If Result.NeverAskAgain Then
		CommonServerCall.CommonSettingsStorageSave("ApplicationSettings", "SuggestDiscussions", False);
	EndIf;
	
	If Result.Value = DialogReturnCode.Yes Then
		ShowConnection();
		Return;
	EndIf;
	ExecuteNotifyProcessing(CompletionDetails);
	
EndProcedure

#EndRegion