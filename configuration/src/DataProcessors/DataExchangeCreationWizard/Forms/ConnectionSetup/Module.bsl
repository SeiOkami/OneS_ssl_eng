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
	
	CheckCanUseForm(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	InitializeFormAttributes();
	
	InitializeFormProperties();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetNavigationNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to discard the connection parameters for data synchronization?';");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ConnectionSetupMethodOnChange(Item)
	
	OnChangeConnectionSetupMethod();
	
EndProcedure

&AtClient
Procedure ImportConnectionSettingsFromFileOnChange(Item)
	
	OnChangeImportConnectionSettingsFromFile();
	
EndProcedure

&AtClient
Procedure ConnectionSettingsFileNameToImportStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Title", NStr("en = 'Select connection settings file';"));
	DialogSettings.Insert("Filter",    NStr("en = 'Connection settings file (*.xml)';") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ConnectionSettingsFileNameToImport", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure XDTOCorrespondentSettingsFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Title", NStr("en = 'Select peer settings file';"));
	DialogSettings.Insert("Filter",    NStr("en = 'Peer settings file (*.xml)';") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "XDTOCorrespondentSettingsFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ConnectionSettingsFileNameToExportStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Mode",     FileDialogMode.Save);
	DialogSettings.Insert("Title", NStr("en = 'Select file to save connection settings';"));
	DialogSettings.Insert("Filter",    NStr("en = 'Connection settings file (*.xml)';") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ConnectionSettingsFileNameToExport", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalConnectionConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure InternetConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure PassiveModeConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFILEDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(ThisObject, "RegularCommunicationChannelsFILEDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(ThisObject, "ExternalConnectionInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFILEUsageOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFILEUsage();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFTPUsageOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFTPUsage();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsEMAILUsageOnChange(Item)
	
	OnChangeRegularCommunicationChannelsEMAILUsage();
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseOperationModeFileOnChange(Item)
	
	OnChangeExternalConnectionInfobaseOperationMode();
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseOperationModeClientServerOnChange(Item)
	
	OnChangeExternalConnectionInfobaseOperationMode();
	
EndProcedure

&AtClient
Procedure ExternalConnection1CEnterpriseAuthenticationKindOnChange(Item)
	
	OnChangeExternalConnectionAuthenticationKind();
	
EndProcedure

&AtClient
Procedure ExternalConnectionOperatingSystemAuthenticationKindOnChange(Item)
	
	OnChangeExternalConnectionAuthenticationKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsArchiveFilesOnChange(Item)
	
	OnChangeRegularCommunicationChannelsArchiveFiles();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsProtectArchiveWithPasswordOnChange(Item)
	
	OnChangeRegularCommunicationChannelsUseArchivePassword();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFTPEnableFileSizeLimitOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsEMAILEnableAttachmentSizeLimitOnChange(Item)
	
	OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit();
	
EndProcedure

&AtClient
Procedure FixDuplicateSynchronizationSettingsOnChange(Item)
	
	If FixDuplicateSynchronizationSettings And ThisInfobaseHasPeerInfobaseNode Then
		
		ClosingNotification1 = New NotifyDescription("AfterPermissionDeletion", ThisObject, ExchangeNode);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Queries = DataExchangeServerCall.RequestToClearPermissionsToUseExternalResources(ExchangeNode);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, Undefined, ClosingNotification1);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterPermissionDeletion(Result, InfobaseNode) Export
	
	If Not Result = DialogReturnCode.OK Then
		FixDuplicateSynchronizationSettings = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure MoreSettings(Command)
	
	MoreSettingsVisibility = False;

	Items.MoreSettings.Visible = False;
	Items.GroupConnectionSetupOptions.Visible = True;
	
EndProcedure

&AtClient
Procedure ConfigureManually(Command)
	
	ConnectionSetupOptionInService = "InternetManually";
	
	If XDTOSetup Then 
	
		Items.ExternalConnectionConnectionKind.Visible  = AvailableTransportKinds.Property("COM");
		Items.InternetConnectionKind.Visible           = AvailableTransportKinds.Property("WS");
		Items.RegularCommunicationChannelsConnectionKind.Visible = AvailableTransportKinds.Property("FILE")
			Or AvailableTransportKinds.Property("FTP")
			Or AvailableTransportKinds.Property("EMAIL");
			
		Items.PassiveModeConnectionKind.Visible      = AvailableTransportKinds.Property("WSPassiveMode");
		
		Items.SettingsFilePassiveModeGroup.Visible = AvailableTransportKinds.Property("WSPassiveMode");
		Items.SettingsFileRegularCommunicationChannelsGroup.Visible = AvailableTransportKinds.Property("FILE")
			Or AvailableTransportKinds.Property("FTP")
			Or AvailableTransportKinds.Property("EMAIL");
		
		Items.ConnectionSetupMethodsPanel.CurrentPage = Items.ConnectionKindsPage;
		Items.NavigationPanel.CurrentPage = Items.PageNavigationWaysToSetUpConnection;
		OnChangeConnectionKind();
		
	Else
		
		OnChangeConnectionSetupMethod();
	    ChangeNavigationNumber(+1);

	EndIf;
		
EndProcedure

&AtClient
Procedure ApplicationsSaaSOnActivateRow(Item)
	
	If Items.PanelMain.CurrentPage <> Items.ConnectionSetupMethodPage Then
		Return;
	EndIf;
	
	ChooseBestConnectionSetupOption();
		
EndProcedure

&AtClient
Procedure ChooseBestConnectionSetupOption()
		
	CurrentRow = Items.ApplicationsSaaS.CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If HasExchangeAdministrationManage_3_0_1_1
		And CurrentRow.HasExchangeAdministrationManage_3_0_1_1 Then
		
		ConnectionSetupOptionInService = "InternetAuto";
		Items.ConnectionSetupOptionInternet.Visible = True;
		
	Else
		
		ConnectionSetupOptionInService = "ServiceManager";
		Items.ConnectionSetupOptionInternet.Visible = False;
		
	EndIf;
	
	OnChangeConnectionSetupMethod();

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	If ConnectionKind = "PassiveMode" Then 
		ChangeNavigationNumber(-5);
		Items.NavigationPanel.CurrentPage = Items.PageNavigationWaysToSetUpConnection;
	Else
		ChangeNavigationNumber(-1)	
	EndIf;
		
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ForceCloseForm = True;
	
	Result = New Structure;
	Result.Insert("ExchangeNode", ExchangeNode);
	Result.Insert("HasDataToMap", HasDataToMap);
	
	If SaaSModel Then
		Result.Insert("CorrespondentDataArea",  CorrespondentDataArea);
		Result.Insert("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
	EndIf;
	
	Result.Insert("PassiveMode", ConnectionKind = "PassiveMode");
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure HelpCommand(Command)
	
	OpenFormHelp();
	
EndProcedure

&AtClient
Procedure RefreshAvailableApplicationsList(Command)
	
	StartGetConnectionsListForConnection();
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParametersForm();
	
EndProcedure

&AtClient
Procedure DataSyncDetails(Command)
	
	DataExchangeClient.OpenSynchronizationDetails(DetailedExchangeInformation);
	
EndProcedure

&AtClient
Procedure BackCommandIsConnectionSetupMethod(Command)
	
	Items.ConnectionSetupMethodsPanel.CurrentPage = Items.MyApplicationsPage;
	Items.NavigationPanel.CurrentPage = Items.PageNavigationStart;
			
EndProcedure

&AtClient
Procedure NextConnectionSetupMethodCommand(Command)
	
	If ConnectionKind = "Internet" Then
		
		ConnectionSetupOptionInService = "InternetManually";
		OnChangeConnectionSetupMethod();
		
		ChangeNavigationNumber(+1);
		
		Items.ConnectionSetupMethodsPanel.CurrentPage = Items.MyApplicationsPage;
			
	ElsIf ConnectionKind = "PassiveMode" Then
		
		If IsBlankString(XDTOCorrespondentSettingsFileName) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please select a file with peer application settings.';"),
				, "XDTOCorrespondentSettingsFileName");
		Else
			ChangeNavigationNumber(+3);			
		EndIf;
		
	EndIf;	
		
EndProcedure

#EndRegion

#Region Private

#Region GetConnectionsListForConnection

&AtClient
Procedure StartGetConnectionsListForConnection()
	
	Items.SaaSApplicationsPanel.Visible = True;
	Items.ApplicationsSaaS.Enabled = False;
	Items.SaaSApplicationsRefreshAvailableApplicationsList.Enabled = False;
	
	Items.SaaSApplicationsPanel.CurrentPage = Items.SaaSApplicationsPanelWaitPage;
	AttachIdleHandler("GetApplicationListForConnectionOnStart", 0.1, True);
	
EndProcedure

&AtClient
Procedure GetApplicationListForConnectionOnStart()
	
	ParametersOfGetApplicationsListHandler = Undefined;
	ContinueWait = False;
	
	OnStartGetConnectionsListForConnection(ContinueWait);
		
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ParametersOfGetApplicationsListIdleHandler);
			
		AttachIdleHandler("OnWaitForGetApplicationListForConnection",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
	Else
		OnCompleteGettingApplicationsListForConnection();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForGetApplicationListForConnection()
	
	ContinueWait = False;
	OnWaitGetConnectionsListForConnection(ParametersOfGetApplicationsListHandler, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		
		AttachIdleHandler("OnWaitForGetApplicationListForConnection",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
	Else
		ParametersOfGetApplicationsListIdleHandler = Undefined;
		OnCompleteGettingApplicationsListForConnection();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteGettingApplicationsListForConnection()
	
	Cancel = False;
	OnCompleteGettingApplicationsListForConnectionAtServer(Cancel);
	
	Items.SaaSApplicationsRefreshAvailableApplicationsList.Enabled = True;
	Items.ApplicationsSaaS.Enabled = True;
	
	If Cancel Then
		Items.SaaSApplicationsPanel.CurrentPage = Items.SaaSApplicationsErrorPage;
	Else
		Items.SaaSApplicationsPanel.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartGetConnectionsListForConnection(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("Mode",				"NotConfiguredExchanges");
	WizardParameters.Insert("ExchangePlanName",		ExchangePlanName);
	
	If ValueIsFilled(ExchangeFormat) Then
		WizardParameters.Insert("ExchangeFormat", ExchangeFormat);
	Else
		WizardParameters.Insert("ExchangeFormat", ExchangePlanName);
	EndIf;
	WizardParameters.Insert("SettingID", SettingID);
	
	ModuleSetupWizard.OnStartGetApplicationList(WizardParameters,
		ParametersOfGetApplicationsListHandler, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitGetConnectionsListForConnection(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnWaitForGetApplicationList(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteGettingApplicationsListForConnectionAtServer(Cancel = False)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGettingApplicationsList(
		ParametersOfGetApplicationsListHandler, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		Cancel = True;
		Return;
	EndIf;
	
	ApplicationsTable = CompletionStatus.Result; // ValueTable
	
	ApplicationsTable.Columns.Add("PictureUseMode", New TypeDescription("Number"));
	ApplicationsTable.FillValues(1, "PictureUseMode"); // 
	ApplicationsSaaS.Load(ApplicationsTable);
	
EndProcedure

#EndRegion

#Region ConnectionParametersCheck

&AtClient
Procedure OnStartCheckConnectionOnline()
	
	ContinueWait = True;
	
	If ConnectionKind = "Internet" Then
		OnStartTestConnectionAtServer("WS", ContinueWait);
	ElsIf ConnectionKind = "ExternalConnection" Then
		OnStartTestConnectionAtServer("COM", ContinueWait);
	EndIf;
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckOnline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionTestOnline();
	EndIf;
	
EndProcedure
	
&AtClient
Procedure OnWaitForConnectionCheckOnline()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForConnectionCheckOnline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionTestOnline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionTestOnline()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteConnectionTestAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		ChangeNavigationNumber(+1);
	Else
		ChangeNavigationNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClient.MessageToUser(ErrorMessage);
		Else
			CommonClient.MessageToUser(
				NStr("en = 'Cannot connect to the application. Please check the connection settings.';"));
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Procedure OnStartCheckConnectionOffline()
	
	If RegularCommunicationChannelsConnectionCheckQueue = Undefined Then	
		
		RegularCommunicationChannelsConnectionCheckQueue = New Structure;
		
		If RegularCommunicationChannelsFILEUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("FILE");
		EndIf;
		
		If RegularCommunicationChannelsFTPUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("FTP");
		EndIf;
		
		If RegularCommunicationChannelsEMAILUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("EMAIL");
		EndIf;
		
	EndIf;
	
	TransportKindToCheck = Undefined;
	For Each CheckItems In RegularCommunicationChannelsConnectionCheckQueue Do
		TransportKindToCheck = CheckItems.Key;
		Break;
	EndDo;
	
	ContinueWait = True;
	OnStartTestConnectionAtServer(TransportKindToCheck, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckOffline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionCheckOffline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForConnectionCheckOffline()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		AttachIdleHandler("OnWaitForConnectionCheckOffline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionCheckOffline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionCheckOffline()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteConnectionTestAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		
		TransportKindToCheck = Undefined;
		For Each CheckItems In RegularCommunicationChannelsConnectionCheckQueue Do
			TransportKindToCheck = CheckItems.Key;
			Break;
		EndDo;
		RegularCommunicationChannelsConnectionCheckQueue.Delete(TransportKindToCheck);
		
		If RegularCommunicationChannelsConnectionCheckQueue.Count() > 0 Then
			OnStartCheckConnectionOffline();
		Else
			RegularCommunicationChannelsConnectionCheckQueue = Undefined;
			ChangeNavigationNumber(+1);
		EndIf;
		
	Else
		
		TransportKindToCheck = Undefined;
		RegularCommunicationChannelsConnectionCheckQueue = Undefined;
		ChangeNavigationNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClient.MessageToUser(ErrorMessage);
		Else
			CommonClient.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot connect to the application. Please check the connection settings %1.';"), TransportKindToCheck));
		EndIf;
				
	EndIf;
	
EndProcedure

&AtClient
Procedure OnStartConnectionCheckInSaaS()
	
	ContinueWait = True;
	OnStartConnectionCheckInSaaSAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckSaaS",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteSaaSConnectionCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForConnectionCheckSaaS()
	
	ContinueWait = False;
	OnWaitConnectionCheckInSaaSAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForConnectionCheckSaaS",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteSaaSConnectionCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteSaaSConnectionCheck()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteSaaSConnectionTestAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		ChangeNavigationNumber(+1);
	Else
		ChangeNavigationNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClient.MessageToUser(ErrorMessage);
		Else
			CommonClient.MessageToUser(
				NStr("en = 'Cannot connect to the application. Please check the connection settings.';"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartTestConnectionAtServer(TransportKind, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	SettingsStructure = New Structure;
	FillWizardConnectionParametersStructure(SettingsStructure, True);
	SettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes[TransportKind];
	
	ModuleSetupWizard.OnStartTestConnection(
		SettingsStructure, ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForTestConnection(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteConnectionTestAtServer(ConnectionCheckCompleted, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteConnectionTest(ConnectionCheckHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.ConnectionIsSet
			And CompletionStatus.Result.ConnectionAllowed;
			
		If Not ConnectionCheckCompleted
			And Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage; 
		EndIf;
			
		If ConnectionCheckCompleted
			And CompletionStatus.Result.CorrespondentParametersReceived Then
			FillCorrespondentParameters(CompletionStatus.Result.CorrespondentParameters);
		EndIf;
		
		ThisNodeExistsInPeerInfobase = CompletionStatus.Result.ThisNodeExistsInPeerInfobase; 		
		ThisInfobaseHasPeerInfobaseNode = CompletionStatus.Result.ThisInfobaseHasPeerInfobaseNode;
		NodeToDelete = CompletionStatus.Result.NodeToDelete;
				
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartConnectionCheckInSaaSAtServer(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ConnectionSettings = New Structure;
	ConnectionSettings.Insert("ExchangePlanName",              ExchangePlanName);
	ConnectionSettings.Insert("CorrespondentDescription",  CorrespondentDescription);
	ConnectionSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
	
	ConnectionCheckHandlerParameters = Undefined;
	ModuleSetupWizard.OnStartGetCommonDataFromCorrespondentNodes(ConnectionSettings,
		ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckInSaaSAtServer(HandlerParameters, ContinueWait)

	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForGetCommonDataFromCorrespondentNodes(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteSaaSConnectionTestAtServer(ConnectionCheckCompleted, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ConnectionCheckCompleted = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGetCommonDataFromCorrespondentNodes(
		ConnectionCheckHandlerParameters, CompletionStatus);
	ConnectionCheckHandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.CorrespondentParametersReceived;
		
		If Not ConnectionCheckCompleted Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
		
		If ConnectionCheckCompleted Then
			FillCorrespondentParameters(CompletionStatus.Result.CorrespondentParameters, True);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region SaveConnectionSettings

&AtClient
Procedure OnStartSaveConnectionSettings()
	
	ContinueWait = True;
	OnStartSaveConnectionSettingsAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ConnectionSettingsSaveIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForSaveConnectionSettings",
			ConnectionSettingsSaveIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionSettingsSaving();
	EndIf;
	
EndProcedure
	
&AtClient
Procedure OnWaitForSaveConnectionSettings()
	
	ContinueWait = False;
	OnWaitForSaveConnectionSettingsAtServer(IsExchangeWithApplicationInService,
		ConnectionSettingsSaveHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(ConnectionSettingsSaveIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForSaveConnectionSettings",
			ConnectionSettingsSaveIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionSettingsSaving();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionSettingsSaving()
	
	ConnectionSettingsSaved = False;
	ConnectionSettingsAddressInStorage = "";
	ErrorMessage = "";
	
	OnCompleteConnectionSettingsSavingAtServer(ConnectionSettingsSaved,
		ConnectionSettingsAddressInStorage, ErrorMessage);
		
	Result = New Structure;
	Result.Insert("Cancel",             Not ConnectionSettingsSaved);
	Result.Insert("ErrorMessage", ErrorMessage);
	
	CompletionNotification = New NotifyDescription("SaveConnectionSettingsCompletion", ThisObject);
	
	If ConnectionSettingsSaved Then
		If SaveConnectionParametersToFile
			And ValueIsFilled(ConnectionSettingsAddressInStorage) Then
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
			
			FileReceiptNotification = New NotifyDescription("GetConnectionSettingsFileCompletion",
				ThisObject, AdditionalParameters);
				
			FilesToObtain = New Array;
			FilesToObtain.Add(
				New TransferableFileDescription(ConnectionSettingsFileNameToExport, ConnectionSettingsAddressInStorage));
				
			SavingParameters = FileSystemClient.FilesSavingParameters();
			SavingParameters.Interactively = False;
			
			FileSystemClient.SaveFiles(FileReceiptNotification, FilesToObtain, SavingParameters);
			
		Else
			
			ExecuteNotifyProcessing(CompletionNotification, Result);
			
		EndIf;
	Else
		
		ExecuteNotifyProcessing(CompletionNotification, Result);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetConnectionSettingsFileCompletion(ObtainedFiles, AdditionalParameters) Export
	
	Result = New Structure;
	Result.Insert("Cancel",             False);
	Result.Insert("ErrorMessage", "");
	
	If ObtainedFiles = Undefined Then
		Result.Cancel = True;
		Result.ErrorMessage = NStr("en = 'Couldn''t save the connection settings to a file.';");
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
	
EndProcedure

&AtClient
Procedure SaveConnectionSettingsCompletion(Result, AdditionalParameters) Export
	
	If Not Result.Cancel Then
		
		ChangeNavigationNumber(+1);
		
		Notify("Write_ExchangePlanNode");
		
	Else
		
		ChangeNavigationNumber(-1);
		
		MessageText = Result.ErrorMessage;
		If IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Couldn''t save the connection settings.';");
		EndIf;
		
		CommonClient.MessageToUser(MessageText);
			
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartSaveConnectionSettingsAtServer(ContinueWait)
	
	If IsExchangeWithApplicationInService Then
		
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
		
		ConnectionSettings = ModuleSetupWizard.ConnectionSettingsDetails(XDTOSetup);
		
		ConnectionSettings.ExchangePlanName               = CorrespondentExchangePlanName;
		ConnectionSettings.CorrespondentExchangePlanName = ExchangePlanName;
		
		ConnectionSettings.SettingID = SettingID;
		
		ConnectionSettings.ExchangeFormat = ExchangeFormat;
		
		ConnectionSettings.Description               = Description;
		ConnectionSettings.CorrespondentDescription = CorrespondentDescription;
		
		ConnectionSettings.Prefix               = Prefix;
		ConnectionSettings.CorrespondentPrefix = CorrespondentPrefix;
		
		ConnectionSettings.SourceInfobaseID = SourceInfobaseID;
		ConnectionSettings.DestinationInfobaseID = DestinationInfobaseID;
		
		ConnectionSettings.CorrespondentEndpoint = CorrespondentEndpoint;

		ConnectionSettings.CorrespondentDataArea = CorrespondentDataArea;
		
		If XDTOSetup Then
			ConnectionSettings.XDTOCorrespondentSettings.SupportedVersions.Add(ExchangeFormatVersion);
			ConnectionSettings.XDTOCorrespondentSettings.SupportedObjects = SupportedCorrespondentFormatObjects;
		EndIf;
		
	Else
		
		// 
		ConnectionSettings = New Structure;
		FillWizardConnectionParametersStructure(ConnectionSettings);
		
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
			
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ConnectionSettingsSaveHandlerParameters = Undefined;
	ModuleSetupWizard.OnStartSaveConnectionSettings(ConnectionSettings,
		ConnectionSettingsSaveHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitForSaveConnectionSettingsAtServer(IsExchangeWithApplicationInService, HandlerParameters, ContinueWait)
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForSaveConnectionSettings(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteConnectionSettingsSavingAtServer(ConnectionSettingsSaved,
		ConnectionSettingsAddressInStorage, ErrorMessage)
	
	CompletionStatus = Undefined;
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ConnectionSettingsSaved = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnCompleteConnectionSettingsSaving(
		ConnectionSettingsSaveHandlerParameters, CompletionStatus);
	ConnectionSettingsSaveHandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		ConnectionSettingsSaved = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionSettingsSaved = CompletionStatus.Result.ConnectionSettingsSaved;
		
		If Not ConnectionSettingsSaved Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
		
		ExchangeNode = CompletionStatus.Result.ExchangeNode;
		
		If SaveConnectionParametersToFile Then
			TempFile = GetTempFileName("xml");
			
			Record = New TextWriter;
			Record.Open(TempFile, "UTF-8");
			Record.Write(CompletionStatus.Result.XMLConnectionSettingsString);
			Record.Close();
			
			ConnectionSettingsAddressInStorage = PutToTempStorage(
				New BinaryData(TempFile), UUID);
				
			DeleteFiles(TempFile);
		EndIf;
		
		If Not SaaSModel Then
			HasDataToMap = CompletionStatus.Result.HasDataToMap;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Dull font color for unavailable sync settings.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsSaaS.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsSaaS.SyncSetupUnavailable");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
		
EndProcedure

&AtServer
Procedure FillWizardConnectionParametersStructure(WizardSettingsStructure, WithoutCorrespondent = False)
	
	// 
	WizardSettingsStructure.Insert("ExchangePlanName",               ExchangePlanName);
	WizardSettingsStructure.Insert("CorrespondentExchangePlanName", CorrespondentExchangePlanName);
	WizardSettingsStructure.Insert("ExchangeSetupOption", SettingID);
	WizardSettingsStructure.Insert("ExchangeFormat", ExchangeFormat);
	
	If ValueIsFilled(ExchangeNode)
		And Not WithoutCorrespondent Then
		WizardSettingsStructure.Insert("Peer", ExchangeNode);
	EndIf;
	
	If ContinueSetupInSubordinateDIBNode
		Or ImportConnectionParametersFromFile Then
		WizardSettingsStructure.Insert("WizardRunOption", "ContinueDataExchangeSetup");
	Else
		WizardSettingsStructure.Insert("WizardRunOption", "SetUpNewDataExchange");
	EndIf;
	
	WizardSettingsStructure.Insert("RefToNew", Undefined);
	
	WizardSettingsStructure.Insert("PredefinedNodeCode", SourceInfobaseID);
		
	WizardSettingsStructure.Insert("SecondInfobaseNewNodeCode", DestinationInfobaseID);
	WizardSettingsStructure.Insert("CorrespondentNodeCode",   DestinationInfobaseID);
	
	WizardSettingsStructure.Insert("ThisInfobaseDescription",   Description);
	WizardSettingsStructure.Insert("SecondInfobaseDescription", CorrespondentDescription);
	
	WizardSettingsStructure.Insert("SourceInfobasePrefix", Prefix);
	WizardSettingsStructure.Insert("DestinationInfobasePrefix", CorrespondentPrefix);
	
	WizardSettingsStructure.Insert("InfobaseNode", ExchangeNode);
	
	WizardSettingsStructure.Insert("UsePrefixesForExchangeSettings",               UsePrefixesForExchangeSettings);
	WizardSettingsStructure.Insert("UsePrefixesForCorrespondentExchangeSettings", UsePrefixesForCorrespondentExchangeSettings);
	
	WizardSettingsStructure.Insert("SourceInfobaseID", SourceInfobaseID);
	WizardSettingsStructure.Insert("DestinationInfobaseID", DestinationInfobaseID);
	
	WizardSettingsStructure.Insert("ExchangeDataSettingsFileFormatVersion",
		DataExchangeServer.ModuleDataExchangeCreationWizard().DataExchangeSettingsFormatVersion());
		
	WizardSettingsStructure.Insert("ExchangeFormatVersion", ExchangeFormatVersion);
	WizardSettingsStructure.Insert("SupportedObjectsInFormat", SupportedCorrespondentFormatObjects);
	
	// 	
	WizardSettingsStructure.Insert("COMOperatingSystemAuthentication",
		ExternalConnectionAuthenticationKind = 0); // 
	WizardSettingsStructure.Insert("COMInfobaseOperatingMode",
		?(ExternalConnectionInfobaseOperationMode = "File", 0, 1));
	WizardSettingsStructure.Insert("COM1CEnterpriseServerSideInfobaseName",
		ExternalConnectionInfobaseName);
	WizardSettingsStructure.Insert("COMUserName",
		ExternalConnectionUsername);
	WizardSettingsStructure.Insert("COM1CEnterpriseServerName",
		ExternalConnectionServerCluster);
	WizardSettingsStructure.Insert("COMInfobaseDirectory",
		ExternalConnectionInfobaseDirectory);
	WizardSettingsStructure.Insert("COMUserPassword",
		ExternalConnectionPassword);
		
	WizardSettingsStructure.Insert("EMAILMaxMessageSize",
		RegularCommunicationChannelsMAILMaxAttachmentSize);
	WizardSettingsStructure.Insert("EMAILCompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("EMAILAccount",
		RegularCommunicationChannelsMAILUserAccount);
	WizardSettingsStructure.Insert("EMAILTransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
	
	WizardSettingsStructure.Insert("FILEDataExchangeDirectory",
		RegularCommunicationChannelsFILEDirectory);
	WizardSettingsStructure.Insert("FILECompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("FILETransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
	
	WizardSettingsStructure.Insert("FTPCompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("FTPConnectionMaxMessageSize",
		RegularCommunicationChannelsFTPMaxFileSize);
	WizardSettingsStructure.Insert("FTPConnectionPassword",
		RegularCommunicationChannelsFTPPassword);
	WizardSettingsStructure.Insert("FTPConnectionPassiveConnection",
		RegularCommunicationChannelsFTPPassiveMode);
	WizardSettingsStructure.Insert("FTPConnectionUser",
		RegularCommunicationChannelsFTPUser);
	WizardSettingsStructure.Insert("FTPConnectionPort",
		RegularCommunicationChannelsFTPPort);
	WizardSettingsStructure.Insert("FTPConnectionPath",
		RegularCommunicationChannelsFTPPath);
	WizardSettingsStructure.Insert("FTPTransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
		
	WizardSettingsStructure.Insert("WSWebServiceURL", InternetWebAddress);
	WizardSettingsStructure.Insert("WSRememberPassword", InternetRememberPassword);
	WizardSettingsStructure.Insert("WSUserName", InternetUsername);
	WizardSettingsStructure.Insert("WSPassword", InternetPassword);
	
	If ConnectionKind = "Internet" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	ElsIf ConnectionKind = "ExternalConnection" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.COM);
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportKind) Then
			If RegularCommunicationChannelsFILEUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FILE);
			ElsIf RegularCommunicationChannelsFTPUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FTP);
			ElsIf RegularCommunicationChannelsEMAILUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.EMAIL);
			EndIf;
		ElsIf RegularCommunicationChannelsDefaultTransportKind = "FILE" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FILE);
		ElsIf RegularCommunicationChannelsDefaultTransportKind = "FTP" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FTP);
		ElsIf RegularCommunicationChannelsDefaultTransportKind = "EMAIL" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.EMAIL);
		EndIf;
	ElsIf ConnectionKind = "PassiveMode" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
	EndIf;
	
	WizardSettingsStructure.Insert("UseTransportParametersCOM",   ConnectionKind = "ExternalConnection");
	
	WizardSettingsStructure.Insert("UseTransportParametersEMAIL", RegularCommunicationChannelsEMAILUsage);
	WizardSettingsStructure.Insert("UseTransportParametersFILE",  RegularCommunicationChannelsFILEUsage);
	WizardSettingsStructure.Insert("UseTransportParametersFTP",   RegularCommunicationChannelsFTPUsage);
	
	WizardSettingsStructure.Insert("ArchivePasswordExchangeMessages", RegularCommunicationChannelsArchivePassword);
	
	WizardSettingsStructure.Insert("FixDuplicateSynchronizationSettings",	FixDuplicateSynchronizationSettings);
	WizardSettingsStructure.Insert("ThisInfobaseHasPeerInfobaseNode",				ThisInfobaseHasPeerInfobaseNode);
	WizardSettingsStructure.Insert("ThisNodeExistsInPeerInfobase",					ThisNodeExistsInPeerInfobase);
	
	If ConnectionSetupOptionInService = "InternetAuto" Then
		
		WizardSettingsStructure.Insert("WSCorrespondentEndpoint", CorrespondentEndpoint);
		WizardSettingsStructure.Insert("WSCorrespondentDataArea", CorrespondentDataArea);
		WizardSettingsStructure.Insert("WSEndpoint", Endpoint);
		WizardSettingsStructure.Insert("WSDataArea", SessionParameters["DataAreaValue"]);
							
	Else
		
		WizardSettingsStructure.Insert("WSCorrespondentEndpoint", Undefined);
		WizardSettingsStructure.Insert("WSCorrespondentDataArea", 0);
		WizardSettingsStructure.Insert("WSEndpoint", Undefined);
		WizardSettingsStructure.Insert("WSDataArea", 0);
		
	EndIf;

	WizardSettingsStructure.Insert("RestoreExchangeSettings", RestoreExchangeSettings);
	WizardSettingsStructure.Insert("SentNo", SentNo);
	WizardSettingsStructure.Insert("ReceivedNo", ReceivedNo);
	
EndProcedure

&AtServer
Procedure ReadWizardConnectionParametersStructure(WizardSettingsStructure)
	
	// Transforming structure of wizard attributes to structure of form attributes.
	SourceInfobaseID = WizardSettingsStructure.PredefinedNodeCode;
	DestinationInfobaseID = WizardSettingsStructure.SecondInfobaseNewNodeCode;
	
	CorrespondentExchangePlanName = WizardSettingsStructure.CorrespondentExchangePlanName;
	
	UsePrefixesForCorrespondentExchangeSettings =
		Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName)
			Or StrLen(DestinationInfobaseID) <> 36
			Or StrLen(SourceInfobaseID) <> 36;
	
	If DescriptionChangeAvailable Then
		Description = WizardSettingsStructure.ThisInfobaseDescription;
	EndIf;
	
	If CorrespondentDescriptionChangeAvailable Then
		CorrespondentDescription = WizardSettingsStructure.SecondInfobaseDescription;
	EndIf;
	
	If PrefixChangeAvailable Then
		Prefix = WizardSettingsStructure.SourceInfobasePrefix;
		If IsBlankString(Prefix)
			And (UsePrefixesForExchangeSettings Or UsePrefixesForCorrespondentExchangeSettings) Then
			Prefix = WizardSettingsStructure.PredefinedNodeCode;
		EndIf;
	EndIf;
	
	If CorrespondentPrefixChangeAvailable Then
		CorrespondentPrefix = WizardSettingsStructure.DestinationInfobasePrefix;
		If IsBlankString(CorrespondentPrefix)
			And (UsePrefixesForExchangeSettings Or UsePrefixesForCorrespondentExchangeSettings) Then
			CorrespondentPrefix = WizardSettingsStructure.SecondInfobaseNewNodeCode;
		EndIf;
	EndIf;
	
	// Transport settings.
	ExternalConnectionAuthenticationKind =
		?(WizardSettingsStructure.COMOperatingSystemAuthentication, 0, 1); // 
	ExternalConnectionInfobaseOperationMode =
		?(WizardSettingsStructure.COMInfobaseOperatingMode = 0, "File", "ClientServer1");
	ExternalConnectionInfobaseName =
		WizardSettingsStructure.COM1CEnterpriseServerSideInfobaseName;
	ExternalConnectionUsername =
		WizardSettingsStructure.COMUserName;
	ExternalConnectionServerCluster =
		WizardSettingsStructure.COM1CEnterpriseServerName;
	ExternalConnectionInfobaseDirectory =
		WizardSettingsStructure.COMInfobaseDirectory;
	ExternalConnectionPassword =
		WizardSettingsStructure.COMUserPassword;
	
	RegularCommunicationChannelsMAILMaxAttachmentSize =
		WizardSettingsStructure.EMAILMaxMessageSize;
	RegularCommunicationChannelsEMAILEnableAttachmentSizeLimit = 
		ValueIsFilled(RegularCommunicationChannelsMAILMaxAttachmentSize);
	RegularCommunicationChannelsMAILUserAccount =
		WizardSettingsStructure.EMAILAccount;
	
	RegularCommunicationChannelsFILEDirectory =
		WizardSettingsStructure.FILEDataExchangeDirectory;
	
	RegularCommunicationChannelsFTPMaxFileSize =
		WizardSettingsStructure.FTPConnectionMaxMessageSize;
	RegularCommunicationChannelsFTPEnableFileSizeLimit =
		ValueIsFilled(RegularCommunicationChannelsFTPMaxFileSize);
	RegularCommunicationChannelsFTPPassword =
		WizardSettingsStructure.FTPConnectionPassword;
	RegularCommunicationChannelsFTPPassiveMode =
		WizardSettingsStructure.FTPConnectionPassiveConnection;
	RegularCommunicationChannelsFTPUser =
		WizardSettingsStructure.FTPConnectionUser;
	RegularCommunicationChannelsFTPPort =
		WizardSettingsStructure.FTPConnectionPort;
	RegularCommunicationChannelsFTPPath =
		WizardSettingsStructure.FTPConnectionPath;
		
	InternetWebAddress        = WizardSettingsStructure.WSWebServiceURL;
	InternetRememberPassword = WizardSettingsStructure.WSRememberPassword;
	InternetUsername = WizardSettingsStructure.WSUserName;
	InternetPassword          = WizardSettingsStructure.WSPassword;
	
	If WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		ConnectionKind = "Internet";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		ConnectionKind = "ExternalConnection";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		ConnectionKind = "RegularCommunicationChannels";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		ConnectionKind = "PassiveMode";
	EndIf;
	
	RegularCommunicationChannelsEMAILUsage = WizardSettingsStructure.UseTransportParametersEMAIL;
	RegularCommunicationChannelsFILEUsage  = WizardSettingsStructure.UseTransportParametersFILE;
	RegularCommunicationChannelsFTPUsage   = WizardSettingsStructure.UseTransportParametersFTP;
	
	If RegularCommunicationChannelsFILEUsage Then
		RegularCommunicationChannelsDefaultTransportKind = "FILE";
	ElsIf RegularCommunicationChannelsFTPUsage Then
		RegularCommunicationChannelsDefaultTransportKind = "FTP";
	ElsIf RegularCommunicationChannelsEMAILUsage Then
		RegularCommunicationChannelsDefaultTransportKind = "EMAIL";
	EndIf;
	
	RegularCommunicationChannelsTransliterateFileNames =
		WizardSettingsStructure.FILETransliterateExchangeMessageFileNames
		Or WizardSettingsStructure.FTPTransliterateExchangeMessageFileNames
		Or WizardSettingsStructure.EMAILTransliterateExchangeMessageFileNames;
		
	RegularCommunicationChannelsArchiveFiles =
		WizardSettingsStructure.FILECompressOutgoingMessageFile
		Or WizardSettingsStructure.FTPCompressOutgoingMessageFile
		Or WizardSettingsStructure.EMAILCompressOutgoingMessageFile;	
	
	RegularCommunicationChannelsArchivePassword = WizardSettingsStructure.ArchivePasswordExchangeMessages;
	
	RegularCommunicationChannelsProtectArchiveWithPassword = ValueIsFilled(RegularCommunicationChannelsArchivePassword);
	
	If StrLen(SourceInfobaseID) = 36
		And StrLen(DestinationInfobaseID) = 36 Then
		
		ExchangePlanName = DataExchangeServer.FindNameOfExchangePlanThroughUniversalFormat(CorrespondentExchangePlanName);
		
		If ExchangePlans[ExchangePlanName].ThisNode().Code <> SourceInfobaseID
			And DataExchangeServer.ExchangePlanNodes(ExchangePlanName).Count() > 0 Then
			RestoreExchangeSettings = "RestoreWithWarning";
		Else
			RestoreExchangeSettings = "Restoration";
		EndIf;
		
	EndIf;
	
	SentNo = WizardSettingsStructure.SentNo;
	ReceivedNo = WizardSettingsStructure.ReceivedNo
	
EndProcedure

&AtServer
Procedure FillCorrespondentParameters(CorrespondentParameters, CorrespondentInSaaS = False)
	
	If ValueIsFilled(CorrespondentParameters.InfobasePrefix) Then
		CorrespondentPrefix = CorrespondentParameters.InfobasePrefix;
		CorrespondentPrefixChangeAvailable = False;
	Else
		CorrespondentPrefix = CorrespondentParameters.DefaultInfobasePrefix;
		CorrespondentPrefixChangeAvailable = True;
	EndIf;
	
	If Not CorrespondentInSaaS Then
		If ValueIsFilled(CorrespondentParameters.InfobaseDescription) Then
			CorrespondentDescription = CorrespondentParameters.InfobaseDescription;
		Else
			CorrespondentDescription = CorrespondentParameters.DefaultInfobaseDescription;
		EndIf;
	EndIf;
	
	DestinationInfobaseID = CorrespondentParameters.ThisNodeCode;
	
	CorrespondentConfigurationVersion = CorrespondentParameters.ConfigurationVersion;
	
	CorrespondentExchangePlanName = CorrespondentParameters.ExchangePlanName;
	
	If XDTOSetup Then
		UsePrefixesForCorrespondentExchangeSettings = CorrespondentParameters.UsePrefixesForExchangeSettings;
		
		ExchangeFormatVersion = DataExchangeXDTOServer.MaxCommonFormatVersion(
			ExchangePlanName, CorrespondentParameters.ExchangeFormatVersions);
		
		SupportedCorrespondentFormatObjects = New ValueStorage(
			CorrespondentParameters.SupportedObjectsInFormat, New Deflation(9));
	ElsIf ConnectionKind = "Internet"
		And StrLen(DestinationInfobaseID) = 9 Then
		UsePrefixesForExchangeSettings               = False;
		UsePrefixesForCorrespondentExchangeSettings = False;
		
		If IsBlankString(SourceInfobaseID) Then
			SourceInfobaseID = Prefix;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillConnectionParametersFromXMLAtServer(AddressInStorage, Cancel, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	TempFile = GetTempFileName("xml");
		
	FileData = GetFromTempStorage(AddressInStorage); // BinaryData
	FileData.Write(TempFile);
	
	Try
		ConnectionSettings = ModuleSetupWizard.Create();
		ConnectionSettings.ExchangePlanName = ExchangePlanName;
		ConnectionSettings.ExchangeSetupOption = SettingID;
		ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup";
		
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(
			ConnectionSettings, TempFile, True);
	Except
		Cancel = True;
		ErrorMessage   = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		ErrorMessageEventLog = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessageEventLog);
	EndTry;
		
	DeleteFiles(TempFile);
	DeleteFromTempStorage(AddressInStorage);
	
	If Not Cancel Then
		ReadWizardConnectionParametersStructure(ConnectionSettings);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillXDTOCorrespondentSettingsFromXMLAtServer(AddressInStorage, Cancel, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	TempFile = GetTempFileName("xml");
		
	FileData = GetFromTempStorage(AddressInStorage); // BinaryData
	FileData.Write(TempFile);
	
	Try
		XDTOCorrespondentSettings = ModuleSetupWizard.XDTOCorrespondentSettingsFromXML(
			TempFile, True, ExchangePlans[ExchangePlanName].EmptyRef());
	Except
		Cancel = True;
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessage);
	EndTry;

	DeleteFiles(TempFile);
	DeleteFromTempStorage(AddressInStorage);
	
	If Not Cancel Then
		ExchangeFormatVersion = DataExchangeXDTOServer.MaxCommonFormatVersion(ExchangePlanName,
			XDTOCorrespondentSettings.SupportedVersions);
			
		SupportedCorrespondentFormatObjects = New ValueStorage(XDTOCorrespondentSettings.SupportedObjects,
			New Deflation(9));
			
		DestinationInfobaseID = XDTOCorrespondentSettings.SenderID;
		
		UsePrefixesForCorrespondentExchangeSettings = (StrLen(DestinationInfobaseID) <> 36);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAvailableTransportKinds()
	
	AvailableTransportKinds = New Structure;
	
	UsedExchangeMessagesTransports = DataExchangeCached.UsedExchangeMessagesTransports(
		ExchangePlans[ExchangePlanName].EmptyRef(), SettingID);
		
	For Each CurrentTransportKind In UsedExchangeMessagesTransports Do
		// 
		// 	
		If SaaSModel Then
			If CurrentTransportKind <> Enums.ExchangeMessagesTransportTypes.WS
				And CurrentTransportKind <> Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
				Continue;
			EndIf;
			
			If Not XDTOSetup Then
				Continue;
			EndIf;
		EndIf;
			
		AvailableTransportKinds.Insert(Common.EnumerationValueName(CurrentTransportKind));
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCompletePutConnectionSettingsFileForImport(FileThatWasPut, AdditionalParameters) Export
	
	Result = New Structure;
	Result.Insert("Cancel", False);
	Result.Insert("ErrorMessage", "");
	
	If FileThatWasPut = Undefined Then
		Result.Cancel = True;
	Else
		FillConnectionParametersFromXMLAtServer(FileThatWasPut.Location, Result.Cancel, Result.ErrorMessage);
	EndIf;
	
	If Result.Cancel Then
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("en = 'Cannot load the connection settings file.';");
		EndIf;
	Else
		DescriptionChangeAvailable = False;
		PrefixChangeAvailable     = False;
		
		CorrespondentDescriptionChangeAvailable = False;
		CorrespondentPrefixChangeAvailable     = False;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.Notification, Result);
	
EndProcedure

&AtClient
Procedure OnCompletePutXDTOCorrespondentSettingsFile(FileThatWasPut, AdditionalParameters) Export

	If FileThatWasPut = Undefined Then
		Return;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Cancel",             False);
	Result.Insert("ErrorMessage", "");
	
	FillXDTOCorrespondentSettingsFromXMLAtServer(FileThatWasPut.Location, Result.Cancel, Result.ErrorMessage);
	
	If Result.Cancel Then
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("en = 'Cannot load the file with peer application settings.';");
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.Notification, Result);
	
EndProcedure

&AtClient
Procedure ConnectionParametersRegularCommunicationChannelsContinueSetting(Result, AdditionalParameters) Export
	
	If Result.Cancel Then
		ChangeNavigationNumber(-1);
		CommonClient.MessageToUser(Result.ErrorMessage);
		Return;
	EndIf;
	
	Items.InternetAccessParameters.Visible = InternetAccessParametersSetupAvailable;
	
	Items.SyncOverDirectoryGroup.Visible = AvailableTransportKinds.Property("FILE");
	Items.SyncOverFTPGroup.Visible = AvailableTransportKinds.Property("FTP");
	Items.SyncOverEMAILGroup.Visible = AvailableTransportKinds.Property("EMAIL");
	
	If RegularCommunicationChannelsFILEUsage Then
		Items.SyncOverDirectoryGroup.Show();
	Else
		Items.SyncOverDirectoryGroup.Hide();
	EndIf;
	
	If RegularCommunicationChannelsFTPUsage Then
		Items.SyncOverFTPGroup.Show();
	Else
		Items.SyncOverFTPGroup.Hide();
	EndIf;
	
	If RegularCommunicationChannelsEMAILUsage Then
		Items.SyncOverEMAILGroup.Show();
	Else
		Items.SyncOverEMAILGroup.Hide();
	EndIf;
	
	If AdditionalParameters.IsMoveNext Then
	
		OnChangeRegularCommunicationChannelsFILEUsage();
		OnChangeRegularCommunicationChannelsFTPUsage();
		OnChangeRegularCommunicationChannelsEMAILUsage();
		
		OnChangeRegularCommunicationChannelsArchiveFiles();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommonSynchronizationSettingsContinueSetting(Result, AdditionalParameters) Export
	
	If Result.Cancel Then
		If ConnectionKind = "PassiveMode" Then 
			ChangeNavigationNumber(-3);
			Items.NavigationPanel.CurrentPage = Items.PageNavigationWaysToSetUpConnection;
		Else
			ChangeNavigationNumber(-1)	
		EndIf;	
		CommonClient.MessageToUser(Result.ErrorMessage);
		Return;
	EndIf;
	
	If AdditionalParameters.IsMoveNext Then
		Items.RegularCommunicationChannelsDefaultTransportKind.ChoiceList.Clear();
		
		If RegularCommunicationChannelsFILEUsage Then
			Items.RegularCommunicationChannelsDefaultTransportKind.ChoiceList.Add("FILE");
			RegularCommunicationChannelsDefaultTransportKind = "FILE";
		EndIf;
		
		If RegularCommunicationChannelsFTPUsage Then
			Items.RegularCommunicationChannelsDefaultTransportKind.ChoiceList.Add("FTP");
			If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportKind) Then
				RegularCommunicationChannelsDefaultTransportKind = "FTP";
			EndIf;
		EndIf;
		
		If RegularCommunicationChannelsEMAILUsage Then
			Items.RegularCommunicationChannelsDefaultTransportKind.ChoiceList.Add("EMAIL");
			If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportKind) Then
				RegularCommunicationChannelsDefaultTransportKind = "EMAIL";
			EndIf;
		EndIf;
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsDefaultTransportKind",
		"Visible",
		Items.RegularCommunicationChannelsDefaultTransportKind.ChoiceList.Count() > 1);
		
	SaveConnectionParametersToFile = ConnectionKind = "RegularCommunicationChannels"
		And Not DIBSetup 
		And Not ImportConnectionParametersFromFile;
		
	CommonClientServer.SetFormItemProperty(Items,
		"ConnectionSettingsFileNameToExport", "Visible", SaveConnectionParametersToFile);
			
	If SaveConnectionParametersToFile
		And (ConnectionKind = "RegularCommunicationChannels") Then
		If CommonClient.FileInfobase()
			And RegularCommunicationChannelsFILEUsage Then
			ConnectionSettingsFileNameToExport = CommonClientServer.GetFullFileName(
				RegularCommunicationChannelsFILEDirectory, SettingsFileNameForDestination + ".xml");
		EndIf;
	EndIf;
		
	CommonClientServer.SetFormItemProperty(Items,
		"ApplicationSettingsGroupPresentation", "Visible", Not (ConnectionKind = "PassiveMode"));
	
	CommonClientServer.SetFormItemProperty(Items,
		"Description", "ReadOnly", Not DescriptionChangeAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"Prefix", "ReadOnly", Not PrefixChangeAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"CorrespondentDescription", "ReadOnly", Not CorrespondentDescriptionChangeAvailable);
		
	CommonClientServer.SetFormItemProperty(Items,
		"CorrespondentPrefix", "ReadOnly", Not CorrespondentPrefixChangeAvailable);
	
EndProcedure

&AtClient
Procedure RegisterCOMConnectorCompletion(IsRegistered, AdditionalParameters) Export
	
	OnStartCheckConnectionOnline();
	
EndProcedure

#Region FormInitializationOnCreate

&AtServer
Procedure CheckCanUseForm(Cancel = False)
	
	// Parameters of the data exchange creation wizard must be passed.
	If Not Parameters.Property("ExchangePlanName")
		Or Not Parameters.Property("SettingID") Then
		MessageText = NStr("en = 'The form cannot be opened manually.';");
		Common.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormProperties()
	
	If DIBSetup Then
		Title = NStr("en = 'Configure distributed infobase';");
	Else
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Configure connection to %1';"),
			CorrespondentConfigurationDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	ExchangePlanName         = Parameters.ExchangePlanName;
	SettingID = Parameters.SettingID;
	
	ContinueSetupInSubordinateDIBNode = Parameters.Property("ContinueSetupInSubordinateDIBNode");
	
	CorrespondentConfigurationVersion = "";
	
	SaaSModel = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
		
	InternetAccessParametersSetupAvailable = Not SaaSModel
		And Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet");
		
	DIBSetup  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
	XDTOSetup = DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName);
	
	FillAvailableTransportKinds();
	
	If AvailableTransportKinds.Property("COM") Then
		ConnectionKind = "ExternalConnection";
		
		ExternalConnectionInfobaseOperationMode = "File";
		ExternalConnectionAuthenticationKind = 1; // 
	ElsIf AvailableTransportKinds.Property("WS") Then
		ConnectionKind = "Internet";
	ElsIf AvailableTransportKinds.Property("FILE")
		Or AvailableTransportKinds.Property("FTP")
		Or AvailableTransportKinds.Property("EMAIL") Then
		ConnectionKind = "RegularCommunicationChannels";
	ElsIf AvailableTransportKinds.Property("WSPassiveMode") Then
		ConnectionKind = "PassiveMode";
	EndIf;
	
	If AvailableTransportKinds.Property("FILE") Then
		RegularCommunicationChannelsFILEUsage  = True;
	ElsIf AvailableTransportKinds.Property("FTP") Then
		RegularCommunicationChannelsFTPUsage   = True;
	ElsIf AvailableTransportKinds.Property("EMAIL") Then
		RegularCommunicationChannelsEMAILUsage = True;
	EndIf;
	
	If AvailableTransportKinds.Property("FTP") Then
		RegularCommunicationChannelsFTPPort = 21;
		RegularCommunicationChannelsFTPPassiveMode = True;
	EndIf;
	
	// 
	// 
	If XDTOSetup 
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then 
		
		ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
		HasExchangeAdministrationManage_3_0_1_1 =
			ModuleDataExchangeInternalPublication.HasInServiceExchangeAdministrationManage_3_0_1_1();
		
	Else
		
		HasExchangeAdministrationManage_3_0_1_1 = False;
		
	EndIf;
	
	If HasExchangeAdministrationManage_3_0_1_1
		And SaaSModel 
		And (AvailableTransportKinds.Property("WS") Or AvailableTransportKinds.Property("WSPassiveMode")) Then
		
		ConnectionSetupOptionInService = "InternetAuto";
		
	ElsIf SaaSModel Then
		
		ConnectionSetupOptionInService = "ServiceManager";
		IsExchangeWithApplicationInService = True;
		
	Else
		
		ConnectionSetupOptionInService = "";
		
	EndIf;
	
	MoreSettingsVisibility = VisibilityOfMoreSettingsButton();
	
	SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"CorrespondentConfigurationName,
		|ExchangeFormat,
		|SettingsFileNameForDestination,
		|CorrespondentConfigurationDescription,
		|BriefExchangeInfo,
		|DetailedExchangeInformation,
		|DataSyncSettingsWizardFormName",
		SettingID);
	
	FillPropertyValues(ThisObject, SettingsValuesForOption);
	
	CorrespondentExchangePlanName = ExchangePlanName;
	
	DescriptionChangeAvailable = False;
	PrefixChangeAvailable     = False;
	
	CorrespondentDescriptionChangeAvailable = True;
	CorrespondentPrefixChangeAvailable     = True;
	
	If SaaSModel Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		Description = ModuleDataExchangeSaaS.GeneratePredefinedNodeDescription();
	Else
		// This infobase presentation.
		Description = DataExchangeServer.PredefinedExchangePlanNodeDescription(ExchangePlanName);
		If IsBlankString(Description) Then
			DescriptionChangeAvailable = True;
			Description = DataExchangeCached.ThisInfobaseName();
		EndIf;
		DescriptionChangeAvailable = True;
		
		CorrespondentDescription = CorrespondentConfigurationDescription;
	EndIf;
	
	Prefix = GetFunctionalOption("InfobasePrefix");
	If IsBlankString(Prefix) Then
		PrefixChangeAvailable = True;
		DataExchangeOverridable.OnDetermineDefaultInfobasePrefix(Prefix);
	EndIf;
	
	If DIBSetup Then
		ConnectionKind = "RegularCommunicationChannels";
	EndIf;
	
	If ContinueSetupInSubordinateDIBNode Then
		ExchangeNode = DataExchangeServer.MasterNode();
		
		// Filling parameters from connection settings in the constant.
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
		
		ExchangeCreationWizard = ModuleSetupWizard.Create();
		ExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
		ExchangeCreationWizard.ExchangeSetupOption = SettingID;
		ExchangeCreationWizard.WizardRunOption = "ContinueDataExchangeSetup";
		
		ModuleSetupWizard.FillConnectionSettingsFromConstant(ExchangeCreationWizard);		
		ReadWizardConnectionParametersStructure(ExchangeCreationWizard);
		
		DescriptionChangeAvailable = False;
		PrefixChangeAvailable     = False;
		
		CorrespondentDescriptionChangeAvailable = False;
		CorrespondentPrefixChangeAvailable     = False;
	EndIf;
	
	SourceInfobaseID = DataExchangeServer.PredefinedExchangePlanNodeCode(ExchangePlanName);
	
	If XDTOSetup Then
		UsePrefixesForExchangeSettings = Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(
			ExchangePlans[ExchangePlanName].EmptyRef());
		
		If IsBlankString(SourceInfobaseID) Then
			SourceInfobaseID = ?(UsePrefixesForExchangeSettings,
				Prefix, String(New UUID));
		EndIf;
	Else
		UsePrefixesForExchangeSettings = True;
	EndIf;
	
	// To get settings from the correspondent, set the default mode.
	UsePrefixesForCorrespondentExchangeSettings = True;
	
	FillNavigationTable();
	
EndProcedure

&AtServer
Function VisibilityOfMoreSettingsButton()
	
	Return False;
	
EndFunction

#EndRegion

#Region WizardScenarios

&AtServer
Function AddNavigationTableRow(MainPageName, NavigationPageName, DecorationPageName = "")
	
	NavigationsString = NavigationTable.Add();
	NavigationsString.NavigationNumber = NavigationTable.Count();
	NavigationsString.MainPageName = MainPageName;
	NavigationsString.NavigationPageName = NavigationPageName;
	NavigationsString.DecorationPageName = DecorationPageName;
	
	Return NavigationsString;
	
EndFunction

&AtServer
Procedure FillNavigationTable()
	
	NavigationTable.Clear();
	
	If DIBSetup Then
		NewNavigation = AddNavigationTableRow("ConnectionParametersRegularCommunicationChannelsPage", "PageNavigationStart");
		NewNavigation.OnOpenHandlerName = 		"Attachable_CommonCommunicationChannelsConnectionParametersPageOnOpen";
		NewNavigation.OnNavigationToNextPageHandlerName = 	"Attachable_CommonCommunicationChannelsConnectionParametersPageOnGoNext";
	Else
		NewNavigation = AddNavigationTableRow("ConnectionSetupMethodPage", "PageNavigationStart");
		NewNavigation.OnOpenHandlerName 		= "Attachable_ConnectionSetupMethodPageOnOpen";
		NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_ConnectionSetupMethodPageOnGoNext";
		
		NewNavigation = AddNavigationTableRow("ConnectionParametersInternetPage", "PageNavigationFollowUp");
		NewNavigation.OnOpenHandlerName 		= "Attachable_InternetConnectionParametersPageOnOpen";
		NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_InternetConnectionParametersPageOnGoNext";
		
		If Not SaaSModel Then
			NewNavigation = AddNavigationTableRow("ConnectionParametersExternalConnectionPage", "PageNavigationFollowUp");
			NewNavigation.OnOpenHandlerName 		= "Attachable_ConnectionParametersExternalConnectionPageOnOpen";
			NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_ConnectionParametersExternalConnectionPageOnGoNext";
			
			NewNavigation = AddNavigationTableRow("ConnectionParametersRegularCommunicationChannelsPage", "PageNavigationFollowUp");
			NewNavigation.OnOpenHandlerName 		= "Attachable_CommonCommunicationChannelsConnectionParametersPageOnOpen";
			NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_CommonCommunicationChannelsConnectionParametersPageOnGoNext";
		EndIf;
	EndIf;
	
	NewNavigation = AddNavigationTableRow("ConnectionTestPage", "PageNavigationFollowUp");
	NewNavigation.OnOpenHandlerName = "Attachable_ConnectionCheckPageOnOpen";
	NewNavigation.TimeConsumingOperation = True;
	NewNavigation.TimeConsumingOperationHandlerName = "Attachable_ConnectionCheckPageTimeConsumingOperation";
	
	NewNavigation = AddNavigationTableRow("CommonSynchronizationSettingsPage", "PageNavigationFollowUp");
	NewNavigation.OnOpenHandlerName 		= "Attachable_GeneralSynchronizationSettingsPageOnOpen";
	NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_GeneralSynchronizationSettingsPageOnGoNext";
	
	NewNavigation = AddNavigationTableRow("SaveConnectionSettingsPage", "PageNavigationFollowUp");
	NewNavigation.TimeConsumingOperation = True;
	NewNavigation.TimeConsumingOperationHandlerName = "Attachable_SaveConnectionSettingsPageTimeConsumingOperation";
	
	NewNavigation = AddNavigationTableRow("EndPage", "PageNavigationEnd");
	
EndProcedure

#EndRegion

#Region FormAttributesChangesHandlers

&AtClient
Procedure OnChangeConnectionSetupMethod()
	
	If ConnectionSetupOptionInService = "InternetAuto" Then
				
		IsExchangeWithApplicationInService = False;
		ConnectionKind = "Internet";
		  
	ElsIf ConnectionSetupOptionInService = "ServiceManager" Then
			
		IsExchangeWithApplicationInService = True;
		ConnectionKind = "";
				 		
	ElsIf ConnectionSetupOptionInService = "InternetManually" Then
		
		IsExchangeWithApplicationInService = False;
		ConnectionKind = "Internet";
				
	EndIf;
			
EndProcedure

&AtClient
Procedure OnNavigateToPageConnectionTypes()
		
	Items.ExternalConnectionConnectionKind.Visible  = AvailableTransportKinds.Property("COM");
	Items.InternetConnectionKind.Visible           = AvailableTransportKinds.Property("WS");
	Items.RegularCommunicationChannelsConnectionKind.Visible = AvailableTransportKinds.Property("FILE")
		Or AvailableTransportKinds.Property("FTP")
		Or AvailableTransportKinds.Property("EMAIL");
	
	Items.PassiveModeConnectionKind.Visible    = AvailableTransportKinds.Property("WSPassiveMode");
	
	Items.SettingsFilePassiveModeGroup.Visible = AvailableTransportKinds.Property("WSPassiveMode");
	Items.SettingsFileRegularCommunicationChannelsGroup.Visible = AvailableTransportKinds.Property("FILE")
		Or AvailableTransportKinds.Property("FTP")
		Or AvailableTransportKinds.Property("EMAIL");
	
	Items.ConnectionSetupMethodsPanel.CurrentPage = Items.ConnectionKindsPage;
	OnChangeConnectionKind();
  
EndProcedure

&AtClient
Procedure OnChangeImportConnectionSettingsFromFile()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ConnectionSettingsFileNameToImport", "Enabled", ImportConnectionParametersFromFile);
	
EndProcedure

&AtClient
Procedure OnChangeConnectionKind()
	
	CommonClientServer.SetFormItemProperty(Items,
		"SettingsFileRegularCommunicationChannelsGroup", "Enabled", ConnectionKind = "RegularCommunicationChannels");
	
	CommonClientServer.SetFormItemProperty(Items,
		"SettingsFilePassiveModeGroup", "Enabled", ConnectionKind = "PassiveMode");
	
	If ConnectionKind = "RegularCommunicationChannels" Then
		OnChangeImportConnectionSettingsFromFile();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsFILEUsage()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelFILEUsageGroup", "Enabled", RegularCommunicationChannelsFILEUsage);
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsFTPUsage()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelFTPUsageGroup", "Enabled", RegularCommunicationChannelsFTPUsage);
	
	OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit();
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsEMAILUsage()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsEMAILUsageGroup", "Enabled", RegularCommunicationChannelsEMAILUsage);
	
	OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit();
	
EndProcedure

&AtClient
Procedure OnChangeExternalConnectionInfobaseOperationMode()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionInfobaseDirectory",
		"Enabled", ExternalConnectionInfobaseOperationMode = "File");
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionServerCluster",
		"Enabled", ExternalConnectionInfobaseOperationMode = "ClientServer1");
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionInfobaseName",
		"Enabled", ExternalConnectionInfobaseOperationMode = "ClientServer1");
	
EndProcedure
	
&AtClient
Procedure OnChangeExternalConnectionAuthenticationKind()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionUsername",
		"Enabled", ExternalConnectionAuthenticationKind = 1); // 
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionPassword",
		"Enabled", ExternalConnectionAuthenticationKind = 1); // 
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsArchiveFiles()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelArchivePasswordGroup", "Enabled", RegularCommunicationChannelsArchiveFiles);
	
	OnChangeRegularCommunicationChannelsUseArchivePassword();
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsUseArchivePassword()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsArchivePassword", "Enabled", RegularCommunicationChannelsProtectArchiveWithPassword);
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsFTPMaxFileSize",
		"Enabled",
		RegularCommunicationChannelsFTPEnableFileSizeLimit);
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsMAILMaxAttachmentSize",
		"Enabled",
		RegularCommunicationChannelsEMAILEnableAttachmentSizeLimit);
	
EndProcedure

#EndRegion

#Region NavigationEventHandlers

&AtClient
Function Attachable_ConnectionSetupMethodPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.MoreSettings.Visible = MoreSettingsVisibility;
			
	If IsMoveNext Then
	
		If SaaSModel Then
			StartGetConnectionsListForConnection();
			OnChangeConnectionSetupMethod()
		Else
			OnNavigateToPageConnectionTypes();
		EndIf;
		
	Else
		
		If SaaSModel Then
			ChooseBestConnectionSetupOption();	
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionSetupMethodPageOnGoNext(Cancel)
	
	If ConnectionSetupOptionInService = "InternetAuto" 
		Or ConnectionSetupOptionInService = "ServiceManager" Then
		
		CurrentData = Items.ApplicationsSaaS.CurrentData;
		If CurrentData = Undefined Then
			
			CommonClient.MessageToUser(
				NStr("en = 'To continue the connection setup, select an application.';"),
				, "ApplicationsSaaS", , Cancel);
			Return Undefined;
			
		ElsIf CurrentData.SyncSetupUnavailable Then
			
			ShowMessageBox(, CurrentData.ErrorMessage);
			Cancel = True;
			Return Undefined;
			
		Else
			
			AreaPrefix = CurrentData.Prefix;
			
			CorrespondentDescription   = CurrentData.ApplicationDescription;
			CorrespondentAreaPrefix = CurrentData.CorrespondentPrefix;
			
			Endpoint 				= CurrentData.Endpoint;
			CorrespondentEndpoint = CurrentData.CorrespondentEndpoint;
			CorrespondentDataArea = CurrentData.DataArea;
			
			If ConnectionSetupOptionInService = "InternetAuto" Then
				
				ConnectionKind = "Internet";
								
			Else
				
				ConnectionKind = "";
				
				InternetWebAddress		= "";
				InternetUsername = "";
				InternetPassword          = "";
				InternetRememberPassword = False;
				
			EndIf;
				
		EndIf;
		
	ElsIf ConnectionSetupOptionInService = "InternetManually" Then
		
		If ConnectionKind = "RegularCommunicationChannels"
			And ImportConnectionParametersFromFile Then
			If IsBlankString(ConnectionSettingsFileNameToImport) Then
				CommonClient.MessageToUser(
					NStr("en = 'Please select a file with connection settings.';"),
					, "ConnectionSettingsFileNameToImport", , Cancel);
				Return Undefined;
			EndIf;
		ElsIf ConnectionKind = "PassiveMode" Then
			If IsBlankString(XDTOCorrespondentSettingsFileName) Then
				CommonClient.MessageToUser(
					NStr("en = 'Please select a file with peer application settings.';"),
					, "XDTOCorrespondentSettingsFileName", , Cancel);
				Return Undefined;
			EndIf;
		EndIf;
		
		CorrespondentDataArea = 0;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_InternetConnectionParametersPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If (Not SaaSModel And ConnectionKind <> "Internet") 
		Or (SaaSModel And ConnectionSetupOptionInService <> "InternetManually") Then
		SkipPage = True;
		Return Undefined;
	EndIf;
	
	Items.InternetAccessParameters1.Visible = InternetAccessParametersSetupAvailable;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_InternetConnectionParametersPageOnGoNext(Cancel)
	
	If ConnectionKind <> "Internet" Then
		Return Undefined;
	EndIf;
	
	If IsBlankString(InternetWebAddress) And ConnectionSetupOptionInService <> "InternetAuto" Then
		CommonClient.MessageToUser(
			NStr("en = 'Please enter the web application address.';"),
			, "InternetWebAddress", , Cancel);
		Return Undefined;
	EndIf;
	
	InternetWebAddress = TrimAll(InternetWebAddress);
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersExternalConnectionPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SaaSModel Then
		SkipPage = True;
	EndIf;
	
	If ConnectionKind <> "ExternalConnection" Then
		SkipPage = True;
	EndIf;
	
	OnChangeExternalConnectionInfobaseOperationMode();
	OnChangeExternalConnectionAuthenticationKind();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersExternalConnectionPageOnGoNext(Cancel)
	
	If ConnectionKind <> "ExternalConnection" Then
		Return Undefined;
	EndIf;
	
	If ExternalConnectionInfobaseOperationMode = "File" Then
		
		If IsBlankString(ExternalConnectionInfobaseDirectory) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please select an infobase directory.';"),
				, "ExternalConnectionInfobaseDirectory", , Cancel);
			Return Undefined;
		EndIf;
		
	ElsIf ExternalConnectionInfobaseOperationMode = "ClientServer1" Then
		
		If IsBlankString(ExternalConnectionServerCluster) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify a 1C:Enterprise server cluster name.';"),
				, "ExternalConnectionServerCluster", , Cancel);
			Return Undefined;
		EndIf;
		
		If IsBlankString(ExternalConnectionInfobaseName) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify an infobase name in 1C:Enterprise server cluster.';"),
				, "ExternalConnectionInfobaseName", , Cancel);
			Return Undefined;
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_CommonCommunicationChannelsConnectionParametersPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ConnectionKind <> "RegularCommunicationChannels" Then
		SkipPage = True;
		Return Undefined;
	EndIf;
	
	SetupAdditionalParameters = New Structure;
	SetupAdditionalParameters.Insert("IsMoveNext", IsMoveNext);
	ContinueSetupNotification = New NotifyDescription("ConnectionParametersRegularCommunicationChannelsContinueSetting",
		ThisObject, SetupAdditionalParameters);
	
	If IsMoveNext
		And ImportConnectionParametersFromFile Then
		// Importing settings from the file.
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Notification", ContinueSetupNotification);
		
		CompletionNotification2 = New NotifyDescription("OnCompletePutConnectionSettingsFileForImport", ThisObject, AdditionalParameters);
		
		ImportParameters = FileSystemClient.FileImportParameters();
		ImportParameters.FormIdentifier = UUID;
		ImportParameters.Interactively = False;
		
		FileSystemClient.ImportFile_(CompletionNotification2, ImportParameters, ConnectionSettingsFileNameToImport);
	Else
		Result = New Structure;
		Result.Insert("Cancel", False);
		Result.Insert("ErrorMessage", "");
		
		ExecuteNotifyProcessing(ContinueSetupNotification, Result);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_CommonCommunicationChannelsConnectionParametersPageOnGoNext(Cancel)
	
	If ConnectionKind <> "RegularCommunicationChannels" Then
		Return Undefined;
	EndIf;
	
	If Not RegularCommunicationChannelsFILEUsage
		And Not RegularCommunicationChannelsFTPUsage
		And Not RegularCommunicationChannelsEMAILUsage Then
		CommonClient.MessageToUser(
			NStr("en = 'Please select at least one method of transferring data files.';"),
			, "RegularCommunicationChannelsFILEUsage", , Cancel);
		Return Undefined;
	EndIf;
	
	If RegularCommunicationChannelsArchiveFiles
		And RegularCommunicationChannelsProtectArchiveWithPassword
		And IsBlankString(RegularCommunicationChannelsArchivePassword) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please enter the archive password.';"),
			, "RegularCommunicationChannelsArchivePassword", , Cancel);
		Return Undefined;
	EndIf;
	
	If RegularCommunicationChannelsFILEUsage Then
		
		If IsBlankString(RegularCommunicationChannelsFILEDirectory) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please select a file transfer directory.';"),
				, "RegularCommunicationChannelsFILEDirectory", , Cancel);
			Return Undefined;
		EndIf;
		
	EndIf;
	
	If RegularCommunicationChannelsFTPUsage Then
		
		If IsBlankString(RegularCommunicationChannelsFTPPath) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify a file transfer directory.';"),
				, "RegularCommunicationChannelsFTPPath", , Cancel);
			Return Undefined;
		EndIf;
		
		If RegularCommunicationChannelsFTPEnableFileSizeLimit
			And Not ValueIsFilled(RegularCommunicationChannelsFTPMaxFileSize) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify the file size limit.';"),
				, "RegularCommunicationChannelsFTPMaxFileSize", , Cancel);
			Return Undefined;
		EndIf;

	EndIf;
	
	If RegularCommunicationChannelsEMAILUsage Then
		
		If Not ValueIsFilled(RegularCommunicationChannelsMAILUserAccount) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please select an email account.';"),
				, "RegularCommunicationChannelsMAILUserAccount", , Cancel);
			Return Undefined;
		EndIf;
		
		If RegularCommunicationChannelsEMAILEnableAttachmentSizeLimit
			And Not ValueIsFilled(RegularCommunicationChannelsMAILMaxAttachmentSize) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify the attachment size limit.';"),
				, "RegularCommunicationChannelsMAILMaxAttachmentSize", , Cancel);
			Return Undefined;
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ConnectionKind = "PassiveMode" Then
		
		SkipPage = True;
		
	ElsIf ConnectionKind = "ExternalConnection"
		Or ConnectionKind = "Internet"
		Or SaaSModel Then
		
		Items.ConnectionCheckPanel.CurrentPage = Items.ConnectionCheckOnlinePage;
		
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		
		Items.ConnectionCheckPanel.CurrentPage = Items.ConnectionCheckOfflinePage;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckPageTimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	
	If ConnectionKind = "PassiveMode" Then
		
		GoToNext = True;
		
	ElsIf ConnectionKind = "ExternalConnection"
		Or ConnectionKind = "Internet" Then
		
		If ConnectionKind = "ExternalConnection"
			And CommonClient.FileInfobase() Then
			Notification = New NotifyDescription("RegisterCOMConnectorCompletion", ThisObject);
			CommonClient.RegisterCOMConnector(False, Notification);
		Else
			OnStartCheckConnectionOnline();
		EndIf;
		
	ElsIf SaaSModel Then
		
		OnStartConnectionCheckInSaaS();
		
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		
		OnStartCheckConnectionOffline();
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_GeneralSynchronizationSettingsPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	SetupAdditionalParameters = New Structure;
	SetupAdditionalParameters.Insert("IsMoveNext", IsMoveNext);
	ContinueSetupNotification = New NotifyDescription("CommonSynchronizationSettingsContinueSetting",
		ThisObject, SetupAdditionalParameters);
	
	If IsMoveNext
		And ConnectionKind = "PassiveMode" Then
		// Importing correspondent settings from the file.
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Notification", ContinueSetupNotification);
		
		CompletionNotification2 = New NotifyDescription("OnCompletePutXDTOCorrespondentSettingsFile", ThisObject, AdditionalParameters);
		
		ImportParameters = FileSystemClient.FileImportParameters();
		ImportParameters.FormIdentifier = UUID;
		ImportParameters.Interactively = False;
		
		FileSystemClient.ImportFile_(CompletionNotification2, ImportParameters, XDTOCorrespondentSettingsFileName);
	Else
		
		Result = New Structure;
		Result.Insert("Cancel", False);
		Result.Insert("ErrorMessage", "");
		
		ExecuteNotifyProcessing(ContinueSetupNotification, Result);
		
	EndIf;
	
	If ThisInfobaseHasPeerInfobaseNode Or ThisNodeExistsInPeerInfobase Then
	
		Items.DuplicateSynchronizationSettingsGroup.Visible = True;
		
		Hints = New Array;
		
		If ThisNodeExistsInPeerInfobase Then
			ToolTipText = NStr("en = '- New code for the current infobase node';");
			Hints.Add(ToolTipText);
		EndIf;
		
		If ThisInfobaseHasPeerInfobaseNode Then
			ToolTipText = NStr("en = '- Deleting the ""%1"" node';");
			ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(ToolTipText, NodeToDelete);
			Hints.Add(ToolTipText);
		EndIf;
		
		Items.DecorationNoteToCorrect.Title = StrConcat(Hints, Chars.LF);
		
	Else	
		
		Items.DuplicateSynchronizationSettingsGroup.Visible = False;
		
	EndIf;
		
	Items.GroupRestoreExchangeSettings.Visible = 
		RestoreExchangeSettings = "RestoreWithWarning";
		
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_GeneralSynchronizationSettingsPageOnGoNext(Cancel)
	
	If Not ConnectionKind = "PassiveMode" Then
	
		If DescriptionChangeAvailable
			And IsBlankString(Description) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify the description of this application.';"),
				, "Description", , Cancel);
		EndIf;
			
		If PrefixChangeAvailable
			And IsBlankString(Prefix) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify the prefix for this application.';"),
				, "Prefix", , Cancel);
		EndIf;
			
	EndIf;
	
	If CorrespondentDescriptionChangeAvailable
		And IsBlankString(CorrespondentDescription) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify the description of the peer application.';"),
			, "CorrespondentDescription", , Cancel);
	EndIf;
		
	If Not ConnectionKind = "PassiveMode" Then
	
		If CorrespondentPrefixChangeAvailable
			And IsBlankString(CorrespondentPrefix) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify the peer application prefix.';"),
				, "CorrespondentPrefix", , Cancel);
		EndIf;
			
	EndIf;
	
	If SaveConnectionParametersToFile
		And IsBlankString(ConnectionSettingsFileNameToExport) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify the path for saving the connection settings file.';"),
			, "ConnectionSettingsFileNameToExport", , Cancel);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_SaveConnectionSettingsPageTimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartSaveConnectionSettings();
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region AdditionalNavigationHandlers

&AtClient
Procedure ChangeNavigationNumber(Iterator_SSLy)
	
	ClearMessages();
	
	SetNavigationNumber(NavigationNumber + Iterator_SSLy);
	
EndProcedure

&AtClient
Procedure SetNavigationNumber(Val Value)
	
	IsMoveNext = (Value > NavigationNumber);
	
	NavigationNumber = Value;
	
	If NavigationNumber < 1 Then
		
		NavigationNumber = 1;
		
	EndIf;
	
	NavigationNumberOnChange(IsMoveNext);
	
EndProcedure

&AtClient
Procedure NavigationNumberOnChange(Val IsMoveNext)
	
	// Executing navigation event handlers.
	ExecuteNavigationEventHandlers(IsMoveNext);
	
	// Setting page view.
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	Items.PanelMain.CurrentPage  = Items[NavigationRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[NavigationRowCurrent.NavigationPageName];
	
	Items.NavigationPanel.CurrentPage.Enabled = Not (IsMoveNext And NavigationRowCurrent.TimeConsumingOperation);
	
	// Setting the default button.
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		ConfirmButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If ConfirmButton <> Undefined Then
			
			ConfirmButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsMoveNext And NavigationRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteNavigationEventHandlers(Val IsMoveNext)
	
	// Navigation event handlers.
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() > 0 Then
			NavigationRow = NavigationRows[0];
		
			// OnNavigationToNextPage handler.
			If Not IsBlankString(NavigationRow.OnNavigationToNextPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnNavigationToNextPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetNavigationNumber(NavigationNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	Else
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber + 1));
		
		If NavigationRows.Count() > 0 Then
			NavigationRow = NavigationRows[0];
		
			// OnNavigationToPreviousPage handler.
			If Not IsBlankString(NavigationRow.OnSwitchToPreviousPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnSwitchToPreviousPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetNavigationNumber(NavigationNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	EndIf;
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	If NavigationRowCurrent.TimeConsumingOperation And Not IsMoveNext Then
		
		SetNavigationNumber(NavigationNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(NavigationRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, SkipPage, IsMoveNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsMoveNext Then
				
				SetNavigationNumber(NavigationNumber + 1);
				
				Return;
				
			Else
				
				SetNavigationNumber(NavigationNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTimeConsumingOperationHandler()
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	// TimeConsumingOperationProcessing handler.
	If Not IsBlankString(NavigationRowCurrent.TimeConsumingOperationHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.TimeConsumingOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetNavigationNumber(NavigationNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetNavigationNumber(NavigationNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And StrFind(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion