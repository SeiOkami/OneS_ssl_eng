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
	
	ExternalSystemsTypes = ConversationsInternalClientServer.ExternalSystemsTypes();
	
	Telegram1 = ConnectionsList.GetItems().Add();
	Telegram1.Description = NStr("en = 'Telegram chats';");
	Telegram1.Active = -1;
	Telegram1.Type = ExternalSystemsTypes.Telegram;
	
	VKontakte = ConnectionsList.GetItems().Add();
	VKontakte.Description = NStr("en = 'VK chats';");
	VKontakte.Active = -1;
	VKontakte.Type = ExternalSystemsTypes.VKontakte;
	
	UpdateIntegrationsList();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateBotTelegram(Command)
	Notification = New NotifyDescription("AfterChangeIntegration", ThisObject);
	ConversationsInternalClient.ShowIntegrationInformation(ThisObject, 
		New Structure("Type", ConversationsInternalClientServer.ExternalSystemsTypes().Telegram),
		Notification);
EndProcedure

&AtClient
Procedure CreateBotVKontakte(Command)
	Notification = New NotifyDescription("AfterChangeIntegration", ThisObject);
	ConversationsInternalClient.ShowIntegrationInformation(ThisObject, 
		New Structure("Type", ConversationsInternalClientServer.ExternalSystemsTypes().VKontakte),
		Notification);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterChangeIntegration(Result, AdditionalParameters) Export
	UpdateIntegrationsList();	
EndProcedure

&AtServer
Procedure UpdateIntegrationsList()

	IntegrationTypes = New Map;
	
	For Each IntegrationType In ConnectionsList.GetItems() Do
		IntegrationType.GetItems().Clear();
		IntegrationTypes.Insert(IntegrationType.Type, IntegrationType);
	EndDo;
	
	For Each Integration In CollaborationSystem.GetIntegrations() Do
		
		Category = IntegrationTypes[Integration.ExternalSystemType];
		If Category <> Undefined Then
			NewIntegration = Category.GetItems().Add();
			IntegrationToFormData(Integration, NewIntegration);	
		Else
			WriteLogEvent(ConversationsInternal.EventLogEvent(),
				EventLogLevel.Error,,,
				NStr("en = 'Unsupported type of external integration';"));
		EndIf;
			
	EndDo;

EndProcedure

// Parameters:
//  Integration - CollaborationSystemIntegration 
//  FormData1 - FormDataTreeItem of See DataProcessor.EnableDiscussions.Form.SettingsOfMessagesFromOtherApplications.ConnectionsList
//
&AtServer
Procedure IntegrationToFormData(Val Integration, Val FormData1)
	
	FormData1.Active = ?(Integration.Use, 0, 2);
	FormData1.Description = Integration.Presentation;
	FormData1.Id = Integration.ID;
	FormData1.Type = Integration.ExternalSystemType;

EndProcedure

&AtClient
Procedure ConnectionsListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	Integration = ConnectionsList.FindByID(RowSelected);
	If Integration.Id = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("AfterChangeIntegration", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("Type", Integration.Type);
	FormParameters.Insert("Id", Integration.Id);
	ConversationsInternalClient.ShowIntegrationInformation(
		ThisObject, 
		FormParameters,
		Notification);
EndProcedure

&AtClient
Procedure Refresh(Command)
	UpdateAtServer();
EndProcedure

&AtServer
Procedure UpdateAtServer()
	UpdateIntegrationsList();
EndProcedure

#EndRegion
