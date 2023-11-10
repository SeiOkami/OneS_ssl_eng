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
	
	If Not AccessRight("CollaborationSystemInfoBaseRegistration", Metadata) Then 
		Cancel = True;
		Return;
	EndIf;
	
	InstallDefaultCollaborationServer(ThisObject);

	InfobaseName = Constants.SystemTitle.Get();
	If Not ValueIsFilled(InfobaseName) Then
		InfobaseName = Metadata.BriefInformation;
	EndIf;
	RegistrationState = CurrentRegistrationState();
	
	OnChangeFormState(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CreateAdministratorRequiredNoteURLProcessing(Item, 
	FormattedStringURL, StandardProcessing)
	
	Close();
	
EndProcedure

&AtClient
Procedure CollaborationServerChoiceDialogOnChange(Item)
	InstallDefaultCollaborationServer(ThisObject);
	UpdateServerChoiceItems(ThisObject);
EndProcedure

&AtClient
Procedure CollaborationServerChoiceLocallyOnChange(Item)
	UpdateServerChoiceItems(ThisObject);
EndProcedure

&AtClient
Procedure CollaborationServerAddressOnChange(Item)
	CollaborationServer = CollaborationServerAddress;
	UpdateServerChoiceItems(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateAccount(Command)
	
	If RegistrationState = "UnlockRequired" Then 
		OnUnlock();
	ElsIf RegistrationState = "NotRegistered1" Then 
		OnReceiveRegistrationCode();
	ElsIf RegistrationState = "WaitForConfirmationCodeInput" Then 
		OnRegister();
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If RegistrationState = "WaitForConfirmationCodeInput" Then 
		OnRejectConfirmationCodeInput();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtClient
Procedure OnUnlock()
	
	ConversationsInternalServerCall.Unlock();
	
	RegistrationState = "Registered1";
	OnChangeFormState(ThisObject);
	Notify("ConversationsEnabled", True);
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure OnReceiveRegistrationCode()
	
	If IsBlankString(Email) Then 
		ShowMessageBox(, NStr("en = 'Email address is not filled in';"));
		Return;
	EndIf;
	
	If Not CommonClientServer.EmailAddressMeetsRequirements(Email) Then 
		ShowMessageBox(, NStr("en = 'The email address contains errors';"));
		Return;
	EndIf;
	
	If CollaborationServerChoice = 1 And IsBlankString(CollaborationServerAddress) Then
		ShowMessageBox(, NStr("en = 'URL of local collaboration server is not specified';"));
		Return;
	EndIf;
	
	RegistrationParameters = New CollaborationSystemInfoBaseRegistrationParameters;
	RegistrationParameters.ServerAddress = CollaborationServer;
	RegistrationParameters.Email = Email;
	
	Notification = New NotifyDescription("AfterReceiveRegistrationCodeSuccessfully", ThisObject,,
		"OnProcessGetRegistrationCodeError", ThisObject);
	CollaborationSystem.BeginInfoBaseRegistration(Notification, RegistrationParameters);
	
	RegistrationState = "WaitForCollaborationServerResponse";
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure AfterReceiveRegistrationCodeSuccessfully(RegistrationCompleted, MessageText, Context) Export
	
	ShowMessageBox(, MessageText);
	
	RegistrationState = "WaitForConfirmationCodeInput";
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure OnProcessGetRegistrationCodeError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorProcessing.ShowErrorInfo(ErrorInfo);
	
	RegistrationState = "NotRegistered1";
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure OnRegister()
	
	If IsBlankString(RegistrationCode) Then 
		ShowMessageBox(, NStr("en = 'Registration code is required';"));
		Return;
	EndIf;
	
	RegistrationParameters = New CollaborationSystemInfoBaseRegistrationParameters;
	RegistrationParameters.ServerAddress = CollaborationServer;
	RegistrationParameters.Email = Email;
	RegistrationParameters.InfoBaseName = InfobaseName;
	RegistrationParameters.ActivationCode = TrimAll(RegistrationCode);
	
	Notification = New NotifyDescription("AfterRegisterSuccessfully", ThisObject,,
		"OnProcessRegistrationError", ThisObject);
	
	CollaborationSystem.BeginInfoBaseRegistration(Notification, RegistrationParameters);
	
	RegistrationState = "WaitForCollaborationServerResponse";
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure AfterRegisterSuccessfully(RegistrationCompleted, MessageText, Context) Export
	
	If RegistrationCompleted Then 
		Notify("ConversationsEnabled", True);
		RegistrationState = "Registered1";
	Else 
		ShowMessageBox(, MessageText);
		RegistrationState = "WaitForConfirmationCodeInput";
	EndIf;
	
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure OnProcessRegistrationError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorProcessing.ShowErrorInfo(ErrorInfo);
	
	RegistrationState = "WaitForConfirmationCodeInput";
	OnChangeFormState(ThisObject);
	
EndProcedure

&AtClient
Procedure OnRejectConfirmationCodeInput()
	
	Notification = New NotifyDescription("AfterConfirmRefuseToEnterConfirmationCode", ThisObject);
	ShowQueryBox(Notification, 
		NStr("en = 'If not entered, the code sent to your email will be invalid.
		           |You can continue only after a new code is requested.';"), 
		QuestionDialogMode.OKCancel,, DialogReturnCode.Cancel);
	
EndProcedure

&AtClient
Procedure AfterConfirmRefuseToEnterConfirmationCode(QuestionResult, Context) Export 
	
	If QuestionResult = DialogReturnCode.OK Then 
		RegistrationState = "NotRegistered1";
		OnChangeFormState(ThisObject);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure OnChangeFormState(Form) 
	
	RegistrationState = Form.RegistrationState;
	
	If RegistrationState = "WaitForConfirmationCodeInput" Then
		Form.RegistrationCode = "";
	EndIf;
	
	SetPage(Form);
	RefreshCommandBarButtonsVisibility(Form);
	UpdateServerChoiceItems(Form);
	
EndProcedure

#EndRegion

#Region PresentationModel

// Returns:
//   String - 
//   
//   
//   
//   
//
&AtServerNoContext
Function CurrentRegistrationState()
	
	CurrentUser = InfoBaseUsers.CurrentUser();
	
	If IsBlankString(CurrentUser.Name) Then 
		Return "CreateAdministratorRequired";
	EndIf;
	
	If ConversationsInternal.Locked2() Then 
		Return "UnlockRequired";
	EndIf;
	
	Return ?(CollaborationSystem.InfoBaseRegistered(),
		"Registered1", "NotRegistered1");
	
EndFunction

&AtClientAtServerNoContext
Procedure InstallDefaultCollaborationServer(Form)
	Form.CollaborationServer = "wss://1cdialog.com:443";
EndProcedure

#EndRegion

#Region Presentations

&AtClientAtServerNoContext
Procedure SetPage(Form)
	
	RegistrationState = Form.RegistrationState;
	Items = Form.Items;
	
	If RegistrationState = "CreateAdministratorRequired" Then 
		Items.Pages.CurrentPage = Items.CreateAdministratorRequired;
	ElsIf RegistrationState = "UnlockRequired" Then 
		Items.Pages.CurrentPage = Items.UnlockRequired;
	ElsIf RegistrationState = "NotRegistered1" Then 
		Items.Pages.CurrentPage = Items.OfferRegistration;
	ElsIf RegistrationState = "WaitForConfirmationCodeInput" Then 
		Items.Pages.CurrentPage = Items.EnterRegistrationCode;
	ElsIf RegistrationState = "WaitForCollaborationServerResponse" Then
		Items.Pages.CurrentPage = Items.TimeConsumingOperation;
	ElsIf RegistrationState = "Registered1" Then
		Items.Pages.CurrentPage = Items.RegistrationComplete;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshCommandBarButtonsVisibility(Form)
	
	RegistrationState = Form.RegistrationState;
	
	If RegistrationState = "CreateAdministratorRequired" Then 
		Form.Items.CreateAccount.Visible = False;
		Form.Items.Back.Visible = False;
	ElsIf RegistrationState = "UnlockRequired" Then 
		Form.Items.CreateAccount.Visible = True;
		Form.Items.CreateAccount.Title = NStr("en = 'Restore connection';");
		Form.Items.Back.Visible = False;
	ElsIf RegistrationState = "NotRegistered1" Then 
		Form.Items.CreateAccount.Visible = True;
		Form.Items.Back.Visible = False;
	ElsIf RegistrationState = "WaitForConfirmationCodeInput" Then 
		Form.Items.CreateAccount.Visible = True;
		Form.Items.Back.Visible = True;
	ElsIf RegistrationState = "WaitForCollaborationServerResponse" Then 
		Form.Items.CreateAccount.Visible = False;
		Form.Items.Back.Visible = False;
	ElsIf RegistrationState = "Registered1" Then 
		Form.Items.CreateAccount.Visible = False;
		Form.Items.Back.Visible = False;
		Form.Items.Close.DefaultButton = True;
		Form.Items.Close.Title = NStr("en = 'Finish';");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateServerChoiceItems(Form)
	CollaborationServerPresentation = ?(Form.CollaborationServerChoice = 0, 
		NStr("en = '1C:Dialog';"),
		Form.CollaborationServer);
	CaptionPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Connect to %1';"),
		CollaborationServerPresentation);
			
	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"LocalCollaborationServerGroup",
		"Title",
		CaptionPresentation);
	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"LocalCollaborationServerGroup",
		"Enabled",
		Form.CollaborationServerChoice <> 0);
EndProcedure

#EndRegion

#EndRegion