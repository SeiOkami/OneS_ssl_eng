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
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	CheckDataSynchronizationSettingPossibility(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	HandlerParameters = Undefined;
	OnStartGetDataExchangeSettingOptionsAtServer(UUID, HandlerParameters, TimeConsumingOperation);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnStartGetDataExchangeSettingOptions(True);
	
EndProcedure

&AtClient
Procedure URLProcessing(FormattedStringURL, StandardProcessing)
	
	CommandRows = CreateExchangeCommands.FindRows(
		New Structure("URL", FormattedStringURL));
		
	If CommandRows.Count() = 0 Then
		Return;
	EndIf;
	
	CommandString = CommandRows[0];
	StandardProcessing = False;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangePlanName",                     CommandString.ExchangePlanName);
	WizardParameters.Insert("SettingID",             CommandString.SettingID);
	WizardParameters.Insert("SettingOptionDetails",          CommandString.SettingOptionDetails);
	WizardParameters.Insert("DataExchangeWithExternalSystem",       CommandString.ExternalSystem);
	WizardParameters.Insert("ExternalSystemConnectionParameters", CommandString.ExternalSystemConnectionParameters);
	WizardParameters.Insert("NewSYnchronizationSetting");
	
	WizardUniqueKey = WizardParameters.ExchangePlanName + "_" + WizardParameters.SettingID;
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.SyncSetup", WizardParameters, , WizardUniqueKey);
	
	Close();

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExternalSystemsErrorLabelDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenEventLog" Then
		
		StandardProcessing = False;
		
		If CommonClient.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
		
			EventLogEvent = New Array;
			
			ModuleDataExchangeWithExternalSystemsClient = CommonClient.CommonModule("DataExchangeWithExternalSystemsClient");
			EventLogEvent.Add(ModuleDataExchangeWithExternalSystemsClient.EventLogEventName());
			
			Filter = New Structure;
			Filter.Insert("EventLogEvent", EventLogEvent);
			Filter.Insert("Level",                   "Error");
			Filter.Insert("StartDate",                EventLogFilterStartDate());
			
			EventLogClient.OpenEventLog(Filter, ThisObject);
		
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateSettingsList(Command)
	
	OnStartGetDataExchangeSettingOptions();
	
EndProcedure

&AtClient
Procedure EnableOnlineSupport(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport") Then
		ClosingNotification1 = New NotifyDescription("EnableOnlineSupportCompletion", ThisObject);
		
		ModuleOnlineUserSupportClient = CommonClient.CommonModule("OnlineUserSupportClient");
		ModuleOnlineUserSupportClient.EnableInternetUserSupport(ClosingNotification1, ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function EventLogFilterStartDate()
	
	Return BegOfDay(CurrentSessionDate());
	
EndFunction

&AtClient
Procedure OnStartGetDataExchangeSettingOptions(OnOpen = False)
	
	If Not OnOpen Then
		HandlerParameters = Undefined;
		OnStartGetDataExchangeSettingOptionsAtServer(UUID, HandlerParameters, TimeConsumingOperation);
	EndIf;
	
	If TimeConsumingOperation Then
		Items.SettingsOptionsPanel.CurrentPage  = Items.PageWait;
		Items.FormUpdateSettingsList.Enabled = False;
		
		DataExchangeClient.InitIdleHandlerParameters(IdleHandlerParameters);

		AttachIdleHandler("OnWaitForGetDataExchangeSettingOptions",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteGettingDataExchangeSettingsOptions();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForGetDataExchangeSettingOptions()
	
	OnWaitForGetDataExchangeSettingOptionsAtServer(HandlerParameters, TimeConsumingOperation);
	
	If TimeConsumingOperation Then
		DataExchangeClient.UpdateIdleHandlerParameters(IdleHandlerParameters);

		AttachIdleHandler("OnWaitForGetDataExchangeSettingOptions",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteGettingDataExchangeSettingsOptions();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteGettingDataExchangeSettingsOptions()
	
	OnCompleteGettingDataExchangeSettingsOptionsAtServer();
	
EndProcedure

&AtClient
Procedure EnableOnlineSupportCompletion(Result, AdditionalParameters) Export
	
	OnStartGetDataExchangeSettingOptions();
	
EndProcedure

&AtServerNoContext
Procedure OnStartGetDataExchangeSettingOptionsAtServer(UUID, HandlerParameters, ContinueWait)
	
	WizardModule = DataExchangeServer.ModuleDataExchangeCreationWizard();
	WizardModule.OnStartGetDataExchangeSettingOptions(UUID, HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitForGetDataExchangeSettingOptionsAtServer(HandlerParameters, ContinueWait)
	
	WizardModule = DataExchangeServer.ModuleDataExchangeCreationWizard();
	WizardModule.OnWaitForGetDataExchangeSettingOptions(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteGettingDataExchangeSettingsOptionsAtServer()
	
	Settings = Undefined;
	
	WizardModule = DataExchangeServer.ModuleDataExchangeCreationWizard();
	WizardModule.OnCompleteGettingDataExchangeSettingsOptions(HandlerParameters, Settings);
	
	ClearNewExchangeCreationCommands();
	AddCreateNewExchangeCommands(Settings);
	
	Items.SettingsOptionsPanel.CurrentPage  = Items.SettingsOptionsPage;
	Items.FormUpdateSettingsList.Enabled = True;
	
EndProcedure

&AtServer
Procedure ClearNewExchangeCreationCommands()
	
	CreateExchangeCommands.Clear();
	
	DeleteGroupSubordinateItems(Items.OtherApplicationsExchangeGroup);
	DeleteGroupSubordinateItems(Items.DIBExchangeGroup);
	DeleteGroupSubordinateItems(Items.ExternalSystemsSettingsOptionsPage);
	
EndProcedure

&AtServer
Procedure DeleteGroupSubordinateItems(GroupItem1)
	
	While GroupItem1.ChildItems.Count() > 0 Do
		Items.Delete(GroupItem1.ChildItems[0]);
	EndDo;
	
EndProcedure

&AtServer
Procedure AddCreateNewExchangeCommands(Settings)
	
	ExchangeDefaultSettings = Undefined;
	If Settings.Property("ExchangeDefaultSettings", ExchangeDefaultSettings) Then
		
		SettingsTableOtherApplications = ExchangeDefaultSettings.Copy(New Structure("IsDIBExchangePlan", False));
		SettingsTableOtherApplications.Sort("IsXDTOExchangePlan");
		AddNewExchangeCreationCommandsStandardSettings(SettingsTableOtherApplications, Items.OtherApplicationsExchangeGroup);
		
		DIBSettingsTable = ExchangeDefaultSettings.Copy(New Structure("IsDIBExchangePlan", True));
		AddNewExchangeCreationCommandsStandardSettings(DIBSettingsTable, Items.DIBExchangeGroup);
		
	EndIf;
	
	SettingsExternalSystems = Undefined;
	If Settings.Property("SettingsExternalSystems", SettingsExternalSystems) Then
		
		Items.ExternalSystemsExchangeGroup.Visible = True;
		
		If SettingsExternalSystems.ErrorCode = "" Then
			
			If SettingsExternalSystems.SettingVariants.Count() > 0 Then
				AddNewExchangeCreationCommandsSettingsExternalSystems(
					SettingsExternalSystems.SettingVariants, Items.ExternalSystemsSettingsOptionsPage);
				Items.ExternalSystemsExchangePanel.CurrentPage = Items.ExternalSystemsSettingsOptionsPage;
			Else
				Items.ExternalSystemsExchangePanel.CurrentPage = Items.ExternalStystemsNoneSettingsOptionsPage;
			EndIf;
			
		ElsIf SettingsExternalSystems.ErrorCode = "InvalidUsernameOrPassword" Then
			
			If Common.DataSeparationEnabled()
				And Common.SeparatedDataUsageAvailable() Then
				Items.ExternalSystemsExchangePanel.CurrentPage = Items.PageExternalSystemsOnlineSupportNotEnabledInSaaS;
			Else
				Items.ExternalSystemsExchangePanel.CurrentPage = Items.PageExternalSystemsOnlineSupportNotEnabled;
			EndIf;
			
		ElsIf ValueIsFilled(SettingsExternalSystems.ErrorCode) Then
			
			Items.ExternalSystemsExchangePanel.CurrentPage = Items.ExternalSystemsErrorPage;
			
		EndIf;
		
	Else
		
		Items.ExternalSystemsExchangeGroup.Visible = False;
		
	EndIf;
	
EndProcedure

// Parameters:
//   SettingsTable1 - ValueTable - a table of available synchronization settings.
//   ParentGroup2 - FormGroup - a parent form item.
//
&AtServer
Procedure AddNewExchangeCreationCommandsStandardSettings(SettingsTable1, ParentGroup2)
	
	ConfigurationTable = SettingsTable1.Copy(, "CorrespondentConfigurationName");
	ConfigurationTable.GroupBy("CorrespondentConfigurationName");
	
	For Each ConfigurationString In ConfigurationTable Do
		
		SetupStrings = SettingsTable1.FindRows(
			New Structure("CorrespondentConfigurationName", ConfigurationString.CorrespondentConfigurationName));
		
		For Each SettingString In SetupStrings Do
			
			SettingOptionDetails = SettingOptionDetailsStructure();
			FillPropertyValues(SettingOptionDetails, SettingString);
			SettingOptionDetails.CorrespondentDescription = SettingString.CorrespondentConfigurationDescription;
			
			AddNewExchangeCreationCommandForSettingOption(
				ParentGroup2,
				SettingString.ExchangePlanName,
				SettingString.SettingID,
				SettingOptionDetails);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddNewExchangeCreationCommandsSettingsExternalSystems(SettingVariants, ParentGroup2)
	
	For Each SettingsOption In SettingVariants Do
		
		SettingOptionDetails = SettingOptionDetailsStructure();
		FillPropertyValues(SettingOptionDetails, SettingsOption);
		
		AddNewExchangeCreationCommandForSettingOption(
			ParentGroup2,
			SettingsOption.ExchangePlanName,
			SettingsOption.SettingID,
			SettingOptionDetails,
			True,
			SettingsOption.ConnectionParameters);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddNewExchangeCreationCommandForSettingOption(
		ParentGroup2,
		ExchangePlanName,
		SettingID,
		SettingOptionDetails,
		ExternalSystem = False,
		ExternalSystemConnectionParameters = Undefined)
	
	URL = "Setting" + ExchangePlanName + "Variant" + SettingID;
			
	ItemRef1 = Items.Add(
		"LabelDecoration" + URL,
		Type("FormDecoration"),
		ParentGroup2);
	ItemRef1.Type = FormDecorationType.Label;
	ItemRef1.Title = New FormattedString(
		SettingOptionDetails.NewDataExchangeCreationCommandTitle, , , , URL);
	ItemRef1.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	ItemRef1.AutoMaxWidth = False;
	
	ItemRef1.ExtendedTooltip.Title = SettingOptionDetails.BriefExchangeInfo;
	ItemRef1.ExtendedTooltip.AutoMaxWidth = False;
	
	StringCommand = CreateExchangeCommands.Add();
	StringCommand.URL = URL;
	StringCommand.ExchangePlanName = ExchangePlanName;
	StringCommand.SettingID = SettingID;
	StringCommand.SettingOptionDetails = SettingOptionDetails;
	StringCommand.ExternalSystem = ExternalSystem;
	StringCommand.ExternalSystemConnectionParameters = ExternalSystemConnectionParameters;
	
EndProcedure

&AtServerNoContext
Function SettingOptionDetailsStructure()
	
	ModuleWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Return ModuleWizard.SettingOptionDetailsStructure();
	
EndFunction

&AtServer
Procedure CheckDataSynchronizationSettingPossibility(Cancel = False)
	
	MessageText = "";
	If Common.DataSeparationEnabled() Then
		If Common.SeparatedDataUsageAvailable() Then
			ModuleDataExchangeSaaSCached = Common.CommonModule("DataExchangeSaaSCached");
			If Not ModuleDataExchangeSaaSCached.DataSynchronizationSupported() Then
		 		MessageText = NStr("en = 'This application does not support data synchronization setup.';");
				Cancel = True;
			EndIf;
		Else
			MessageText = NStr("en = 'Cannot configure data synchronization in shared mode.';");
			Cancel = True;
		EndIf;
	Else
		ExchangePlansList = DataExchangeCached.SSLExchangePlans();
		If ExchangePlansList.Count() = 0 Then
			MessageText = NStr("en = 'This application does not support data synchronization setup.';");
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel
		And Not IsBlankString(MessageText) Then
		Common.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion