///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Opens a form where a user can change a password.
Procedure OpenChangePasswordForm(User = Undefined, ContinuationHandler = Undefined, AdditionalParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ReturnPasswordAndDoNotSet", False);
	FormParameters.Insert("PreviousPassword", Undefined);
	FormParameters.Insert("LoginName",  "");
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(FormParameters, AdditionalParameters);
	EndIf;
	FormParameters.Insert("User", User);
	
	OpenForm("CommonForm.PasswordChange", FormParameters,,,,, ContinuationHandler);
	
EndProcedure

// See UsersInternalSaaSClient.RequestPasswordForAuthenticationInService.
Procedure RequestPasswordForAuthenticationInService(ContinuationHandler, OwnerForm = Undefined, ServiceUserPassword = Undefined) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaSClient = CommonClient.CommonModule(
			"UsersInternalSaaSClient");
		
		ModuleUsersInternalSaaSClient.RequestPasswordForAuthenticationInService(
			ContinuationHandler, OwnerForm, ServiceUserPassword);
	EndIf;
	
EndProcedure

Procedure InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters, ErrorDescription) Export
	
	Parameters.Cancel = True;
	Parameters.InteractiveHandler = New NotifyDescription(
		"InteractiveDataProcessorOnInsufficientRightsToSignInError", ThisObject, ErrorDescription);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For role interface in managed forms.

// For internal use only.
//
// Parameters:
//  Form - ClientApplicationForm
//  Unconditionally - Boolean
//
Procedure ExpandRoleSubsystems(Form, Unconditionally = True) Export
	
	Items = Form.Items;
	
	If Not Unconditionally
	   And Not Items.RolesShowSelectedRolesOnly.Check Then
		
		Return;
	EndIf;
	
	// Expand all.
	For Each String In Form.Roles.GetItems() Do
		Items.Roles.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

// For internal use only.
Procedure SelectPurpose(FormData1, Title, SelectUsersAllowed = True, IsFilter = False, NotifyDescription = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormData1", FormData1);
	AdditionalParameters.Insert("IsFilter", IsFilter);
	AdditionalParameters.Insert("NotifyDescription", NotifyDescription);
	
	OnCloseNotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject, AdditionalParameters);
	
	Purpose = ?(IsFilter, FormData1.UsersKind, FormData1.Object.Purpose);
	
	FormParameters = New Structure;
	FormParameters.Insert("Title", Title);
	FormParameters.Insert("Purpose", Purpose);
	FormParameters.Insert("SelectUsersAllowed", SelectUsersAllowed);
	FormParameters.Insert("IsFilter", IsFilter);
	OpenForm("CommonForm.SelectUsersTypes", FormParameters,,,,, OnCloseNotifyDescription);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Idle handlers.

// Opens the security warning window.
Procedure ShowSecurityWarning() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	Var_Key = CommonClientServer.StructureProperty(ClientRunParameters, "SecurityWarningKey");
	If ValueIsFilled(Var_Key) Then
		OpenForm("CommonForm.SecurityWarning", New Structure("Key", Var_Key));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("ErrorInsufficientRightsForAuthorization") Then
		Parameters.RetrievedClientParameters.Insert("ErrorInsufficientRightsForAuthorization");
		InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters,
			ClientParameters.ErrorInsufficientRightsForAuthorization);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart2(Parameters) Export
	
	// Checks user authorization result and generates an error message.
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("AuthorizationError") Then
		Parameters.Cancel = True;
		Parameters.InteractiveHandler = New NotifyDescription("ShowMessageBoxAndContinue",
			StandardSubsystemsClient, ClientParameters.AuthorizationError);
		Return;
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart3(Parameters) Export
	
	// Requires to change a password if necessary.
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("PasswordChangeRequired") Then
		Parameters.InteractiveHandler = New NotifyDescription(
			"InteractiveHandlerOnChangePasswordOnStart", ThisObject);
		Return;
	EndIf;
	
EndProcedure

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	Var_Key = CommonClientServer.StructureProperty(ClientRunParameters, "SecurityWarningKey");
	If ValueIsFilled(Var_Key) Then
		// Slight delay so that the platform has time to draw the current window, on top of which a warning window is displayed.
		AttachIdleHandler("ShowSecurityWarningAfterStart", 0.3, True);
	EndIf;
	
	If ClientRunParameters.Property("AskAboutDisablingOpenIDConnect") Then
		ClickNotification = New NotifyDescription("AskAboutDisablingOpenIDConnect", ThisObject);
		MessageTitle = NStr("en = 'Security warning';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Disable %1 authentication if it is not used.';"), "OpenID-Connect");
		ShowUserNotification(MessageTitle, ClickNotification,
			MessageText, PictureLib.Warning32, UserNotificationStatus.Important);
	EndIf;
	
EndProcedure

// See StandardSubsystemsClient.OnReceiptServerNotification.
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	If Result = "AuthorizationDenied" Then
		OpenForm("CommonForm.AuthorizationDenied");
		
	ElsIf Result = "RolesAreModified" Then
		ShowUserNotification(
			NStr("en = 'Access rights are updated';"),
			"e1cib/app/CommonForm.InfobaseUserRoleChangeControl",
			NStr("en = 'Restart the application so that they come into force.';"),
			PictureLib.Warning32,
			UserNotificationStatus.Important,
			"InfobaseUserRoleChangeControl");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Warns the user about the error of the lack of rights to sign in to the application.
Procedure InteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters, ErrorDescription) Export
	
	ShowMessageBox(
		New NotifyDescription("InteractiveDataProcessorOnInsufficientRightsToSignInErrorAfterWarning",
			ThisObject, Parameters),
		ErrorDescription);
	
EndProcedure

// Exit the application after warning the user about the error of the lack of rights to sign in to the application.
Procedure InteractiveDataProcessorOnInsufficientRightsToSignInErrorAfterWarning(Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Suggests the user to change a password or exit application.
Procedure InteractiveHandlerOnChangePasswordOnStart(Parameters, Context) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OnAuthorization", True);
	
	OpenForm("CommonForm.PasswordChange", FormParameters,,,,, New NotifyDescription(
		"InteractiveHandlerOnChangePasswordOnStartCompletion", ThisObject, Parameters));
	
EndProcedure

// Continue the InteractiveDataProcessorOnChangePasswordOnStart procedure.
Procedure InteractiveHandlerOnChangePasswordOnStartCompletion(Result, Parameters) Export
	
	If Not ValueIsFilled(Result) Then
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// 
Procedure AskAboutDisablingOpenIDConnect(Context) Export
	
	CompletionProcessing = New NotifyDescription(
		"AskAboutDisablingOpenIDConnectCompletion", ThisObject);
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 authentication is enabled for users.
		           |If you do not use this authentication kind, disable it.';"),
		"OpenID-Connect");
	
	Buttons = New ValueList;
	Buttons.Add("DisabledForAllUsers", NStr("en = 'Disable for all users';"));
	Buttons.Add("DoNotDisable",                 NStr("en = 'Do not disable';"));
	Buttons.Add("RemindLater",              NStr("en = 'Remind me later';"));
	
	AdditionalParameters = StandardSubsystemsClient.QuestionToUserParameters();
	AdditionalParameters.Title = NStr("en = 'Security warning';");
	AdditionalParameters.PromptDontAskAgain = False;
	
	StandardSubsystemsClient.ShowQuestionToUser(CompletionProcessing,
		QueryText, Buttons, AdditionalParameters);
	
EndProcedure

// 
Procedure AskAboutDisablingOpenIDConnectCompletion(Result, Parameters) Export
	
	Response = ?(Result <> Undefined, Result.Value, "RemindLater");
	
	If Response = "DisabledForAllUsers" Then
		StandardSubsystemsServerCall.ProcessAnswerOnDisconnectingOpenIDConnect(True);
	ElsIf Response = "DoNotDisable" Then
		StandardSubsystemsServerCall.ProcessAnswerOnDisconnectingOpenIDConnect(False);
	EndIf;
	
EndProcedure

// Writes the results of assignment selection in the form.
//
// Parameters:
//  ClosingResult - Undefined
//                    - ValueList
//  AdditionalParameters - Structure:
//    * FormData1 - ClientApplicationForm
//                  - ManagedFormExtensionForObjects:
//        ** Object - FormDataStructure
//        ** Items - FormAllItems:
//              *** SelectPurpose - FormButton
//    * IsFilter - Boolean
//    * NotifyDescription - NotifyDescription
//
Procedure AfterAssignmentChoice(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined Then
		Return;
	EndIf;
	
	If Not AdditionalParameters.IsFilter Then
		Purpose = AdditionalParameters.FormData1.Object.Purpose;
		Purpose.Clear();
	EndIf;
	
	SynonymArray = New Array;
	TypesArray = New Array;
	
	For Each Item In ClosingResult Do
		
		If Item.Check Then
			SynonymArray.Add(Item.Presentation);
			TypesArray.Add(Item.Value);
			If Not AdditionalParameters.IsFilter Then
				NewRow = Purpose.Add();
				NewRow.UsersType = Item.Value;
			EndIf;
		EndIf;
		
	EndDo;
	
	ItemTitle = StrConcat(SynonymArray, ", ");
	
	If AdditionalParameters.IsFilter Then
		AdditionalParameters.FormData1.UsersKind = ItemTitle;
	Else
		AdditionalParameters.FormData1.Items.SelectPurpose.Title = ItemTitle;
	EndIf;
	
	If AdditionalParameters.NotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.NotifyDescription, TypesArray);
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for UsersSettings data processor.

// Opens the report or form that is passed to it.
//
// Parameters:
//  CurrentItem               - FormTable - a selected row of value tree.
//  User                 - String - the name of an infobase user,
//  CurrentUser          - String - an infobase user name. To open the form,
//                                 this value should match the value of the User parameter.
//  PersonalSettingsFormName - String - a path to open a form of personal settings.
//                                 The CommonForm.FormName kind.
//
Procedure OpenReportOrForm(CurrentItem, User, CurrentUser, PersonalSettingsFormName) Export
	
	ValueTreeItem = CurrentItem;
	If ValueTreeItem.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If User <> CurrentUser Then
		WarningText =
			NStr("en = 'To view settings of another user,
			           |restart the application on behalf of that user and open the setting.';");
		ShowMessageBox(,WarningText);
		Return;
	EndIf;
	
	If ValueTreeItem.Name = "ReportSettingsTree" Then
		
		ObjectKey = ValueTreeItem.CurrentData.Keys[0].Value;
		ObjectKeyRowArray = StrSplit(ObjectKey, "/", False);
		VariantKey = ObjectKeyRowArray[1];
		ReportParameters = New Structure("VariantKey, UserSettingsKey", VariantKey, "");
		
		If ValueTreeItem.CurrentData.Type = "ReportSettings1" Then
			UserSettingsKey = ValueTreeItem.CurrentData.Keys[0].Presentation;
			ReportParameters.Insert("UserSettingsKey", UserSettingsKey);
		EndIf;
		
		OpenForm(ObjectKeyRowArray[0] + ".Form", ReportParameters);
		Return;
		
	ElsIf ValueTreeItem.Name = "Interface" Then
		
		For Each ObjectKey In ValueTreeItem.CurrentData.Keys Do
			
			If ObjectKey.Check = True Then
				
				FormName = StrSplit(ObjectKey.Value, "/")[0];
				FormNameParts = StrSplit(FormName, ".");
				While FormNameParts.Count() > 4 Do
					FormNameParts.Delete(4);
				EndDo;
				FormName = StrConcat(FormNameParts, ".");
				OpenForm(FormName);
				Return;
			Else
				ItemParent = ValueTreeItem.CurrentData.GetParent();
				
				If ValueTreeItem.CurrentData.RowType = "DesktopSettings" Then
					ShowMessageBox(,
						NStr("en = 'To view the desktop settings, go to ""Desktop"" section
						           | in the application command interface.';"));
					Return;
				EndIf;
				
				If ValueTreeItem.CurrentData.RowType = "CommandInterfaceSettings" Then
					ShowMessageBox(,
						NStr("en = 'To view the command interface settings,
						           |select a section in the application command interface.';"));
					Return;
				EndIf;
				
				If ItemParent <> Undefined Then
					WarningText =
						NStr("en = 'To view this setting, open ""%1""
						           |and go to the ""%2"" form.';");
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText,
						ItemParent.Setting, ValueTreeItem.CurrentData.Setting);
					ShowMessageBox(,WarningText);
					Return;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ShowMessageBox(,NStr("en = 'Cannot view this setting.';"));
		Return;
		
	ElsIf ValueTreeItem.Name = "OtherSettings" Then
		
		If ValueTreeItem.CurrentData.Type = "PersonalSettings"
			And PersonalSettingsFormName <> "" Then
			OpenForm(PersonalSettingsFormName);
			Return;
		EndIf;
		
		ShowMessageBox(,NStr("en = 'Cannot view this setting.';"));
		Return;
		
	EndIf;
	
	ShowMessageBox(,NStr("en = 'Select a setting to view.';"));
	
EndProcedure

// Generates a message to display after settings are copied.
//
// Parameters:
//  SettingPresentation            - String - a setting name. It is used when a single setting is copied.
//  SettingsCount                - Number  - settings count. It is used when multiple settings are copied.
//  SettingsCopiedToNote - String - to whom settings are copied.
//
// Returns:
//  String - 
//
Function GenerateNoteOnCopy(SettingPresentation, SettingsCount, SettingsCopiedToNote) Export
	
	If SettingsCount = 1 Then
		
		If StrLen(SettingPresentation) > 24 Then
			SettingPresentation = Left(SettingPresentation, 24) + "...";
		EndIf;
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" copied to %2.';"),
			SettingPresentation,
			SettingsCopiedToNote);
	Else
		SubjectInWords = Format(SettingsCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(SettingsCount,
				"", NStr("en = 'setting,settings,,,0';"));
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 copied to %2.';"),
			SubjectInWords,
			SettingsCopiedToNote);
	EndIf;
	
	Return NotificationComment;
	
EndFunction

// Generates a string that describes the destination users.
//
// Parameters:
//  UsersCount - Number  - used if value is greater than 1.
//  User            - String - a username. It is used if the number of users
//                            is 1.
//
// Returns:
//  String - 
//
Function UsersNote(UsersCount, User) Export
	
	If UsersCount = 1 Then
		SettingsCopiedToNote = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'user ""%1""';"), User);
	Else
		SettingsCopiedToNote = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 users.';"), UsersCount);
	EndIf;
	
	Return SettingsCopiedToNote;
	
EndFunction

#EndRegion
