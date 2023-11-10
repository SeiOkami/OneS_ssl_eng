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
	
	ShowExternalUsersSettings = Parameters.ShowExternalUsersSettings;
	UseExternalUsers = ExternalUsers.UseExternalUsers();
	
	RecommendedSettingsValues = New Structure;
	RecommendedSettingsValues.Insert("MinPasswordLength", 8);
	RecommendedSettingsValues.Insert("MaxPasswordLifetime", 30);
	RecommendedSettingsValues.Insert("MinPasswordLifetime", 1);
	RecommendedSettingsValues.Insert("DenyReusingRecentPasswords", 10);
	RecommendedSettingsValues.Insert("WarnAboutPasswordExpiration", 5);
	RecommendedSettingsValues.Insert("InactivityPeriodBeforeDenyingAuthorization", 45);
	
	RecommendedCommonSettingsValues = New Structure;
	RecommendedCommonSettingsValues.Insert("PasswordAttemptsCountBeforeLockout", 3);
	RecommendedCommonSettingsValues.Insert("PasswordLockoutDuration", 5);
	
	LogonSettings = UsersInternal.LogonSettings();
	If Common.DataSeparationEnabled() Then
		Items.GroupWarnAboutPasswordExpiration.Visible = False;
		Items.GroupWarnAboutPasswordExpiration2.Visible = False;
	EndIf;
	
	FillSettingsInForm(LogonSettings.Overall, RecommendedCommonSettingsValues);
	ShowInList = LogonSettings.Overall.ShowInList;
	AreSeparateSettingsForExternalUsers = LogonSettings.Overall.AreSeparateSettingsForExternalUsers;
	
	FillSettingsInForm(LogonSettings.Users, RecommendedSettingsValues);
	PasswordMustMeetComplexityRequirements = LogonSettings.Users.PasswordMustMeetComplexityRequirements;
	
	FillSettingsInForm(LogonSettings.ExternalUsers, RecommendedSettingsValues, True);
	PasswordMustMeetComplexityRequirements2 = LogonSettings.ExternalUsers.PasswordMustMeetComplexityRequirements;
	
	If UseExternalUsers Then
		If ShowExternalUsersSettings Then
			Items.Pages.CurrentPage = Items.ForExternalUsers;
		EndIf;
		UpdateExternalUsersSettingsAvailability(ThisObject);
	Else
		Items.ForExternalUsers.Visible = False;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Items.WarningConfigurationInService.Visible = True;
		Items.FormWriteAndClose.Enabled = False;
		Items.Pages.ReadOnly = True;
		Items.NoteShowInListDataSeparationEnabled.Visible = True;
		Items.ShowInList.Enabled = False;
		
	ElsIf UseExternalUsers Then
		Items.NoteShowInListExternalUsers.Visible = True;
		Items.ShowInList.Enabled = False;
	EndIf;
	
	If Common.FileInfobase() Then
		Items.GroupPasswordAttemptsCountBeforeLockout.Visible = False;
		Items.GroupPasswordLockoutDuration.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AreSeparateSettingsForExternalUsersOnChange(Item)
	
	UpdateExternalUsersSettingsAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure PasswordMustMeetComplexityRequirementsOnChange(Item)
	
	If MinPasswordLength < 7 Then
		MinPasswordLength = 7;
	EndIf;
	If MinPasswordLength2 < 7 Then
		MinPasswordLength2 = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure MinPasswordLengthOnChange(Item)
	
	If MinPasswordLength < 7
	  And PasswordMustMeetComplexityRequirements Then
		
		MinPasswordLength = 7;
	EndIf;
	
	If MinPasswordLength2 < 7
	  And PasswordMustMeetComplexityRequirements2 Then
		
		MinPasswordLength2 = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingEnableOnChange(Item)
	
	NameOnForm = Left(Item.Name, StrLen(Item.Name) - StrLen("Enable"));
	SettingName = ?(StrEndsWith(NameOnForm, "2"),
		Left(NameOnForm, StrLen(NameOnForm) - 1), NameOnForm);
	
	If ThisObject[Item.Name] = False Then
		ThisObject[NameOnForm] = RecommendedSettingsValues[SettingName];
	EndIf;
	
	Items[NameOnForm].Enabled = ThisObject[Item.Name];
	
EndProcedure

&AtClient
Procedure CommonSettingEnableOnChange(Item)
	
	SettingName = Left(Item.Name, StrLen(Item.Name) - StrLen("Enable"));
	
	If ThisObject[Item.Name] = False Then
		ThisObject[SettingName] = RecommendedCommonSettingsValues[SettingName];
	EndIf;
	
	Items[SettingName].Enabled = ThisObject[Item.Name];
	
	If Item.Name = "PasswordAttemptsCountBeforeLockoutEnable" Then
		If PasswordLockoutDurationEnable <> PasswordAttemptsCountBeforeLockoutEnable Then
			PasswordLockoutDurationEnable = PasswordAttemptsCountBeforeLockoutEnable;
			CommonSettingEnableOnChange(Items.PasswordLockoutDurationEnable);
		EndIf;
	ElsIf Item.Name = "PasswordLockoutDurationEnable" Then
		If PasswordAttemptsCountBeforeLockoutEnable <> PasswordLockoutDurationEnable Then
			PasswordAttemptsCountBeforeLockoutEnable = PasswordLockoutDurationEnable;
			CommonSettingEnableOnChange(Items.PasswordAttemptsCountBeforeLockoutEnable);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowInListClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ShowInListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ShowInList = ValueSelected
	 Or ValueSelected = "EnabledForNewUsers"
	 Or ValueSelected = "DisabledForNewUsers" Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("ShowInListChoiceProcessingCompletion",
		ThisObject, ValueSelected);
	
	If ValueSelected = "HiddenAndEnabledForAllUsers" Then
		QueryText =
			NStr("en = 'When you start the application, the user choice list will become full.
			           |The Show in list attribute in cards
			           | of all users will be enabled and hidden.';");
	Else
		QueryText =
			NStr("en = 'The user list in the startup dialog will be cleared
			           |(attribute ""Show in choice list"" will be cleared and hidden from all user profiles).
			           |';");
	EndIf;
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAtServer();
	Notify("Write_ConstantsSet", New Structure, "UserAuthorizationSettings");
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure UpdateExternalUsersSettingsAvailability(Form)
	
	Form.Items.SettingsGroup12.Enabled =
		Form.AreSeparateSettingsForExternalUsers;
	
EndProcedure

&AtServer
Procedure FillSettingsInForm(Settings, RecommendedSettingsValues, ForExternalUsers = False)
	
	For Each KeyAndValue In RecommendedSettingsValues Do
		NameOnForm = KeyAndValue.Key + ?(ForExternalUsers, "2", "");
		If ValueIsFilled(Settings[KeyAndValue.Key]) Then
			ThisObject[NameOnForm + "Enable"] = True;
			ThisObject[NameOnForm] = Settings[KeyAndValue.Key];
		Else
			ThisObject[NameOnForm] = KeyAndValue.Value;
			Items[NameOnForm].Enabled = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteAtServer()
	
	BeginTransaction();
	Try
		Overall = Users.CommonAuthorizationSettingsNewDetails();
		FillSettingsFromForm(Overall, RecommendedCommonSettingsValues);
		If IsShowInListPropertyBulkChangeConfirmed
		   And Overall.ShowInList <> ShowInList
		   And (    ShowInList = "HiddenAndEnabledForAllUsers"
		      Or ShowInList = "HiddenAndDisabledForAllUsers") Then
			UsersInternal.SetShowInListAttributeForAllInfobaseUsers(
				ShowInList = "HiddenAndEnabledForAllUsers");
		EndIf;
		Overall.ShowInList = ShowInList;
		Overall.AreSeparateSettingsForExternalUsers = AreSeparateSettingsForExternalUsers;
		Users.SetCommonAuthorizationSettings(Overall);
		
		UsersSettings = Users.NewDescriptionOfLoginSettings();
		FillSettingsFromForm(UsersSettings, RecommendedSettingsValues);
		UsersSettings.PasswordMustMeetComplexityRequirements = PasswordMustMeetComplexityRequirements;
		Users.SetLoginSettings(UsersSettings);
		
		ExternalUsersSettings = Users.NewDescriptionOfLoginSettings();
		FillSettingsFromForm(ExternalUsersSettings, RecommendedSettingsValues, True);
		ExternalUsersSettings.PasswordMustMeetComplexityRequirements = PasswordMustMeetComplexityRequirements2;
		Users.SetLoginSettings(ExternalUsersSettings, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure FillSettingsFromForm(Settings, RecommendedSettingsValues, ForExternalUsers = False)
	
	For Each KeyAndValue In RecommendedSettingsValues Do
		NameOnForm = KeyAndValue.Key + ?(ForExternalUsers, "2", "");
		If ThisObject[NameOnForm + "Enable"] Then
			Settings[KeyAndValue.Key] = ThisObject[NameOnForm];
		Else
			Settings[KeyAndValue.Key] = 0;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowInListChoiceProcessingCompletion(Response, ValueSelected) Export
	
	If Response = DialogReturnCode.Yes Then
		ShowInList = ValueSelected;
		IsShowInListPropertyBulkChangeConfirmed = True;
	EndIf;
	
EndProcedure

#EndRegion
