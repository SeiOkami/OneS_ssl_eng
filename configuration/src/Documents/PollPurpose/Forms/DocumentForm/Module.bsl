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
	
	AvailableTypes = FormAttributeToValue("Object").Metadata().Attributes.RespondentsType.Type.Types();
	
	For Each AvailableType In AvailableTypes Do
		
		TypesArray = New Array;
		TypesArray.Add(AvailableType);
		Items.RespondentsType.ChoiceList.Add(New TypeDescription(TypesArray),String(AvailableType));
		
	EndDo;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	If Object.Ref.IsEmpty() And Not UseExternalUsers Then
		Object.RespondentsType = New ("CatalogRef.Users");
	EndIf; 
	Items.RespondentsType.Visible = UseExternalUsers;
	
	If Object.RespondentsType = Undefined Then
		If AvailableTypes.Count() > 0 Then
			 Object.RespondentsType = New(AvailableTypes[0]);
			 RespondentsType = Items.RespondentsType.ChoiceList[0].Value;
		 EndIf;
	 Else
		TypesArray = New Array;
		TypesArray.Add(TypeOf(Object.RespondentsType));
		RespondentsType = New TypeDescription(TypesArray);
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		OnCreatReadAtServer();
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ProcessRespondentTypeChange();
	AvailabilityControl();
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If (Object.StartDate > Object.EndDate) And (Object.EndDate <> Date(1,1,1)) Then
	
		CommonClient.MessageToUser(NStr("en = 'The start date cannot be greater than end date.';"),,"Object.StartDate");
		Cancel = True;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SelectRespondents" Then
		
		For Each ArrayElement In Parameter.SelectedRespondents Do
			
			If Object.Respondents.FindRows(New Structure("Respondent", ArrayElement)).Count() = 0 Then
				
				NewRow = Object.Respondents.Add();
				NewRow.Respondent = ArrayElement;
				
			EndIf;
			
		EndDo;
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreatReadAtServer();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RespondentsTypeOnChange(Item)
	
	ProcessRespondentTypeChange();
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure FreeSurveyOnChange(Item)
	
	AvailabilityControl();
	If Object.Respondents.Count() > 0 Then
		Object.Respondents.Clear();
	EndIf;
	
EndProcedure

#EndRegion

#Region RespondentsFormTableItemEventHandlers

&AtClient
Procedure RespondentsRespondentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Respondents.CurrentData;
	
	Value                 = CurrentData.Respondent;
	CurrentData.Respondent = RespondentsType.AdjustValue(Value);
	Item.ChooseType      = False;
	
EndProcedure

&AtClient
Procedure RespondentsOnStartEdit(Item, NewRow, Copy)
	
	CurrentData = Items.Respondents.CurrentData;
	
	Value                  = CurrentData.Respondent;
	CurrentData.Respondent  = RespondentsType.AdjustValue(Value);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickRespondents(Command)
	
	FilterStructure1 = New Structure;
	FilterStructure1.Insert("RespondentType",Object.RespondentsType);
	FilterStructure1.Insert("Respondents",Object.Respondents);
	
	OpenForm("Document.PollPurpose.Form.FormSelectRespondents",FilterStructure1,ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ProcessRespondentTypeChange()
	
	Items.RespondentsRespondent.TypeRestriction  = RespondentsType;
	Items.RespondentsRespondent.AvailableTypes	= RespondentsType;
	
	RespondentNewType = New(RespondentsType.Types()[0]);
	If Object.RespondentsType <> RespondentNewType Then
		Object.RespondentsType = RespondentNewType;
	EndIf;
	
	For Each RespondentsRow In Object.Respondents Do
		
		If Not RespondentsType.ContainsType(TypeOf(RespondentsRow.Respondent)) Then
			Object.Respondents.Clear();
			Items.Respondents.Refresh();
		EndIf;
		
		Break;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AvailabilityControl()

	Items.Respondents.ReadOnly           = Object.FreeSurvey;
	Items.RespondentsSelect.Enabled = Not Object.FreeSurvey;

EndProcedure

&AtServer
Procedure OnCreatReadAtServer()

	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);

EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
