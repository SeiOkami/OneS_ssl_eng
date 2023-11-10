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
	
	InitializeFormAttributes();
	
	InitializeFormProperties();
	
	SetInitialFormItemsView();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillSetupStagesTable();
	UpdateCurrentSettingsStateDisplay();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	RefExists   = False;
	SettingCompleted = False;
	
	If ValueIsFilled(ExchangeNode) Then
		SettingCompleted = SynchronizationSetupCompleted(ExchangeNode, RefExists);
		If Not RefExists Then
			// 
			Return;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(ExchangeNode)
		Or Not SettingCompleted
		Or (DIBSetup And Not ContinueSetupInSubordinateDIBNode And Not InitialImageCreated(ExchangeNode))Then
		WarningText = NStr("en = 'The data synchronization setup is not completed.
		|Do you want to close the wizard? You can continue the setup later.';");
		CommonClient.ShowArbitraryFormClosingConfirmation(
			ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		Notify("DataExchangeCreationWizardFormClosed");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DataSyncDetails(Command)
	
	DataExchangeClient.OpenSynchronizationDetails(SettingOptionDetails.DetailedExchangeInformation);
	
EndProcedure

&AtClient
Procedure SetUpConnectionParameters(Command)
	
	If IsExchangeWithApplicationInService
		And (Not NewSYnchronizationSetting
			Or Not CurrentSetupStep = "ConnectionSetup") Then
		WarnString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Connection to ""%1"" is already configured.
			|Editing the connection parameters is not allowed.';"), ExchangeNode);
		ShowMessageBox(, WarnString);
		Return;
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("SetUpConnectionParametersCompletion", ThisObject);
	
	If DataExchangeWithExternalSystem Then
		If CommonClient.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
			Context = New Structure;
			Context.Insert("SettingID", SettingID);
			Context.Insert("ConnectionParameters", ExternalSystemConnectionParameters);
			Context.Insert("Peer", ExchangeNode);
			
			If NewSYnchronizationSetting
				And CurrentSetupStep = "ConnectionSetup" Then
				Context.Insert("Mode", "New_Connection");
			Else
				Context.Insert("Mode", "EditConnectionParameters");
			EndIf;
			
			Cancel = False;
			WizardFormName  = "";
			WizardParameters = New Structure;
			
			ModuleDataExchangeWithExternalSystemsClient = CommonClient.CommonModule("DataExchangeWithExternalSystemsClient");
			ModuleDataExchangeWithExternalSystemsClient.BeforeSettingConnectionSettings(
				Context, Cancel, WizardFormName, WizardParameters);
			
			If Not Cancel Then
				OpenForm(WizardFormName,
					WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
			EndIf;
		EndIf;
		Return;
	ElsIf CurrentSetupStep = "ConnectionSetup" Then
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangePlanName",         ExchangePlanName);
		WizardParameters.Insert("SettingID", SettingID);
		If ContinueSetupInSubordinateDIBNode Then
			WizardParameters.Insert("ContinueSetupInSubordinateDIBNode");
		EndIf;
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.ConnectionSetup",
			WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
	Else
		Filter              = New Structure("Peer", ExchangeNode);
		FillingValues = New Structure("Peer", ExchangeNode);
		
		DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
			FillingValues, "DataExchangeTransportSettings", ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure GetConnectionConfirmation(Command)
	
	If Not DataExchangeWithExternalSystem
		Or XDTOCorrespondentSettingsReceived(ExchangeNode) Then
		ShowMessageBox(, NStr("en = 'The connection is confirmed.';"));
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
		Context = New Structure;
		Context.Insert("Mode",                  "ConfirmConnection");
		Context.Insert("Peer",          ExchangeNode);
		Context.Insert("SettingID", "SettingID");
		Context.Insert("ConnectionParameters",   ExternalSystemConnectionParameters);
		
		Cancel = False;
		WizardFormName  = "";
		WizardParameters = New Structure;
		
		ModuleDataExchangeWithExternalSystemsClient = CommonClient.CommonModule("DataExchangeWithExternalSystemsClient");
		ModuleDataExchangeWithExternalSystemsClient.BeforeSettingConnectionSettings(
			Context, Cancel, WizardFormName, WizardParameters);
		
		If Not Cancel Then
			ClosingNotification1 = New NotifyDescription("GetConnectionConfirmationCompletion", ThisObject);
			OpenForm(WizardFormName,
				WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfigureDataExportImportRules(Command)
	
	ContinueNotification = New NotifyDescription("SetDataSendingAndReceivingRulesFollowUp", ThisObject);
	
	// 
	// 
	If XDTOSetup Then
		AbortSetup = False;
		ExecuteXDTOSettingsImportIfNecessary(AbortSetup, ContinueNotification);
		
		If AbortSetup Then
			Return;
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ContinueSetup",            True);
	Result.Insert("DataReceivedForMapping", DataReceivedForMapping);
	
	ExecuteNotifyProcessing(ContinueNotification, Result);
	
EndProcedure

&AtClient
Procedure CreateInitialDIBImage(Command)
	
	WizardParameters = New Structure("Key, Node", ExchangeNode, ExchangeNode);
			
	ClosingNotification1 = New NotifyDescription("CreateInitialDIBImageCompletion", ThisObject);
	OpenForm(InitialImageCreationFormName,
		WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure MapAndExportData(Command)
	
	ContinueNotification = New NotifyDescription("MapAndExportDataFollowUp", ThisObject);
	
	WizardParameters = New Structure;
	WizardParameters.Insert("SendData",     False);
	WizardParameters.Insert("ScheduleSetup", False);
	
	If IsExchangeWithApplicationInService Then
		WizardParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	EndIf;
	
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters",  WizardParameters);
	AuxiliaryParameters.Insert("ClosingNotification1", ContinueNotification);
	
	DataExchangeClient.OpenObjectsMappingWizardCommandProcessing(ExchangeNode,
		ThisObject, AuxiliaryParameters);
	
EndProcedure

&AtClient
Procedure ExecuteInitialDataExport(Command)

	Cancel = False;
	
	BeforePerformingTheInitialUpload(Cancel);
	If Cancel Then
		
		Return;
		
	EndIf;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangeNode", ExchangeNode);
	WizardParameters.Insert("InitialExport");
	
	If SaaSModel Then
		WizardParameters.Insert("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
		WizardParameters.Insert("CorrespondentDataArea",  CorrespondentDataArea);
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("ExecuteInitialDataExportCompletion", ThisObject);
	OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form.ExportMappingData",
		WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforePerformingTheInitialUpload(Cancel)
	
	ArrayOfValues = New Array(3);
	ArrayOfValues[0] = PredefinedValue("Enum.ExchangeMessagesTransportTypes.COM");
	ArrayOfValues[1] = PredefinedValue("Enum.ExchangeMessagesTransportTypes.WS");
	// 
	//                    
	
	ModeOfTransportSupportsDirectConnection = (ArrayOfValues.Find(TransportKind) <> Undefined);
	If Not ModeOfTransportSupportsDirectConnection
		Or DataMappingSupported Then
		
		Return;
		
	EndIf;
	
	CheckResult = CorrespondentSetupIsComplete(ExchangeNode, TransportKind);
	If Not CheckResult.SettingCompleted Then
		
		Cancel = True;
		ShowMessageBox(Undefined, CheckResult.ErrorMessage);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CorrespondentSetupIsComplete(ExchangeNode, TransportKind)
	
	CheckData = New Structure;
	CheckData.Insert("ErrorMessage", "");
	CheckData.Insert("ErrorMessageToUser", "");
	CheckData.Insert("SettingCompleted", False);
	CheckData.Insert("DataReceivedForMapping", False);
	
	SetPrivilegedMode(True);
	If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
	
		ConnectionParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode, Undefined);
		
		
		HasConnection = DataExchangeWebService.CorrespondentConnectionEstablished(ExchangeNode,
			ConnectionParameters, CheckData.ErrorMessageToUser, CheckData.SettingCompleted, CheckData.DataReceivedForMapping);
			
		If Not HasConnection Then
			
			MessageTemplate = NStr("en = 'Cannot connect to the %1 application. Reason: ""%2"".
				|Ensure that:
				| - The password is correct.
				| - The connection address is correct.
				| - The application is available.
				| - Web app synchronization is configured.
				|Then, restart synchronization.';", Common.DefaultLanguageCode());
			CheckData.ErrorMessage = StrTemplate(MessageTemplate, ExchangeNode.Description, CheckData.ErrorMessageToUser);
			
		ElsIf Not CheckData.SettingCompleted Then
			
			MessageTemplate = NStr("en = 'To continue, set up synchronization in ""%1"". 
				|The data exchange is canceled.';", Common.DefaultLanguageCode());
			CheckData.ErrorMessage = StrTemplate(MessageTemplate, ExchangeNode.Description);
			
		EndIf;
		
	Else
		
		ExternalConnection = DataExchangeCached.GetExternalConnectionForInfobaseNode(ExchangeNode, CheckData.ErrorMessage);
		If ExternalConnection = Undefined Then
			
			Return CheckData;
			
		EndIf;
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		
		ThisExchangePlanNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
		NodeCode = DataExchangeServer.NodeIDForExchange(ThisExchangePlanNode);
		
		ExternalConnectionExchangePlanNode = ExternalConnection.DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode);
		If ExternalConnectionExchangePlanNode = Undefined Then
			
			MessageTemplate = NStr("en = 'Error. In the ""%1"" application, the synchronization setting for this application is not found.
					|The data exchange is canceled.';", Common.DefaultLanguageCode());
			CheckData.ErrorMessage = StrTemplate(MessageTemplate, ExchangeNode.Description);
			
		EndIf;
		
		CheckData.SettingCompleted = ExternalConnection.DataExchangeServer.SynchronizationSetupCompleted(ExternalConnectionExchangePlanNode);
		If Not CheckData.SettingCompleted Then
				
			MessageTemplate = NStr("en = 'To continue, set up synchronization in ""%1"". 
				|The data exchange is canceled.';", Common.DefaultLanguageCode());
			CheckData.ErrorMessage = StrTemplate(MessageTemplate, ExchangeNode.Description);
			
		EndIf;
		
	EndIf;
	
	Return CheckData;
	
EndFunction

&AtServerNoContext
Function ReadTheTransportModeForTheNode(ExchangeNode)
	
	Return InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ExchangeNode);
	
EndFunction

&AtServerNoContext
Function SynchronizationSetupStatus(ExchangeNode)
	
	Result = New Structure;
	Result.Insert("SynchronizationSetupCompleted",           SynchronizationSetupCompleted(ExchangeNode));
	Result.Insert("InitialImageCreated",                      InitialImageCreated(ExchangeNode));
	Result.Insert("MessageWithDataForMappingReceived", DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode));
	Result.Insert("XDTOCorrespondentSettingsReceived",       XDTOCorrespondentSettingsReceived(ExchangeNode));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function XDTOCorrespondentSettingsReceived(ExchangeNode)
	
	CorrespondentSettings = DataExchangeXDTOServer.SupportedCorrespondentFormatObjects(ExchangeNode, "SendReceive");
	
	Return CorrespondentSettings.Count() > 0;
	
EndFunction

&AtServerNoContext
Function InitialImageCreated(ExchangeNode)
	
	Return InformationRegisters.CommonInfobasesNodesSettings.InitialImageCreated(ExchangeNode);
	
EndFunction

&AtClient
Procedure SetUpConnectionParametersCompletion(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined
		And TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.Property("ExchangeNode") Then
			ExchangeNode = ClosingResult.ExchangeNode;
			UniqueKey = ExchangePlanName + "_" + SettingID + "_" + ExchangeNode.UUID();
			
			If DataExchangeWithExternalSystem Then
				UpdateExternalSystemConnectionParameters(ExchangeNode, ExternalSystemConnectionParameters);
			EndIf;
			
			If ValueIsFilled(ExchangeNode) Then
				
				TransportKind = ReadTheTransportModeForTheNode(ExchangeNode);
				
			EndIf;
			
		EndIf;
		
		If SaaSModel Then
			ClosingResult.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
			ClosingResult.Property("CorrespondentDataArea",  CorrespondentDataArea);
		EndIf;
		
		If ClosingResult.Property("HasDataToMap")
			And ClosingResult.HasDataToMap Then
			DataReceivedForMapping = True;
		EndIf;
		
		FillSetupStagesTable();
		UpdateCurrentSettingsStateDisplay();
		
		If CurrentSetupStep = "ConnectionSetup" Then
			GoToNextSetupStage();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure UpdateExternalSystemConnectionParameters(ExchangeNode, ExternalSystemConnectionParameters)
	
	ExternalSystemConnectionParameters = InformationRegisters.DataExchangeTransportSettings.ExternalSystemTransportSettings(ExchangeNode);
	
EndProcedure

&AtClient
Procedure GetConnectionConfirmationCompletion(Result, AdditionalParameters) Export
	
	If XDTOCorrespondentSettingsReceived(ExchangeNode) Then
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteXDTOSettingsImportIfNecessary(AbortSetup, ContinueNotification)
	
	SetupStatus = SynchronizationSetupStatus(ExchangeNode);
	If Not SetupStatus.SynchronizationSetupCompleted
			And Not SetupStatus.XDTOCorrespondentSettingsReceived Then
		
		ImportParameters = New Structure;
		ImportParameters.Insert("ExchangeNode", ExchangeNode);
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.XDTOSettingsImport",
			ImportParameters, ThisObject, , , , ContinueNotification, FormWindowOpeningMode.LockOwnerWindow);
			
		AbortSetup = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDataSendingAndReceivingRulesFollowUp(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure")
		Or Not ClosingResult.ContinueSetup Then
		
		Return;
		
	EndIf;
	
	If ClosingResult.DataReceivedForMapping
		And Not DataReceivedForMapping Then
		DataReceivedForMapping = ClosingResult.DataReceivedForMapping;
	EndIf;
	
	FillSetupStagesTable();
	UpdateCurrentSettingsStateDisplay();
	
	ClosingNotification1 = New NotifyDescription("ConfigureDataExportImportRulesCompletion", ThisObject);
	
	CheckParameters = New Structure;
	CheckParameters.Insert("Peer",          ExchangeNode);
	CheckParameters.Insert("ExchangePlanName",         ExchangePlanName);
	CheckParameters.Insert("SettingID", SettingID);
	
	SetupExecuted = False;
	BeforeDataSynchronizationSetup(CheckParameters, SetupExecuted, DataSyncSettingsWizardFormName);
	
	If SetupExecuted Then
		ShowMessageBox(, NStr("en = 'The rules for sending and receiving data are configured.';"));
		ExecuteNotifyProcessing(ClosingNotification1, True);
		Return;
	EndIf;
	
	WizardParameters = New Structure;
	
	If IsBlankString(DataSyncSettingsWizardFormName) Then
		WizardParameters.Insert("Key", ExchangeNode);
		WizardParameters.Insert("WizardFormName", "ExchangePlan.[ExchangePlanName].ObjectForm");
		
		WizardParameters.WizardFormName = StrReplace(WizardParameters.WizardFormName,
			"[ExchangePlanName]", ExchangePlanName);
	Else
		WizardParameters.Insert("ExchangeNode", ExchangeNode);
		WizardParameters.Insert("WizardFormName", DataSyncSettingsWizardFormName);
	EndIf;
	
	OpenForm(WizardParameters.WizardFormName,
		WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ConfigureDataExportImportRulesCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "RulesSetting"
		And SynchronizationSetupCompleted(ExchangeNode) Then
		Notify("Write_ExchangePlanNode");
		If ContinueSetupInSubordinateDIBNode Then
			RefreshInterface();
		EndIf;
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure MapAndExportDataFollowUp(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "MapAndImport"
		And DataForMappingImported(ExchangeNode) Then
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateInitialDIBImageCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "InitialDIBImage"
		And InitialImageCreated(ExchangeNode) Then
		GoToNextSetupStage();
	EndIf;
	
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure ExecuteInitialDataExportCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "InitialDataExport"
		And ClosingResult = ExchangeNode Then
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCurrentSettingsStateDisplay()
	
	// Visibility of setup items.
	For Each SetupStage In SetupSteps Do 		
		CommonClientServer.SetFormItemProperty(Items, SetupStage.Group, "Visible", SetupStage.Used);
	EndDo;
	
	If IsBlankString(CurrentSetupStep) Then
		// All stages are completed.
		For Each SetupStage In SetupSteps Do
			Items[SetupStage.Group].Enabled = True;
			Items[SetupStage.Button].Font = CommonClient.StyleFont("SynchronizationSetupWizardCommandStandardFont");
					
			// Green flag is only for the main setting stages.
			If SetupStage.IsMain Then
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.PageSuccessfully];
			Else
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.EmptySpacePage];
			EndIf;
		EndDo;
	Else
		
		CurrentStageFound = False;
		For Each SetupStage In SetupSteps Do
			If SetupStage.Name1 = CurrentSetupStep Then
				Items[SetupStage.Group].Enabled = True;
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.PageCurrent];
				Items[SetupStage.Button].Font = CommonClient.StyleFont("SynchronizationSetupWizardCommandImportantFont");
				CurrentStageFound = True;
			ElsIf Not CurrentStageFound Then
				Items[SetupStage.Group].Enabled = True;
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.PageSuccessfully];
				Items[SetupStage.Button].Font = CommonClient.StyleFont("SynchronizationSetupWizardCommandStandardFont");
			Else
				Items[SetupStage.Group].Enabled = False;
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.EmptySpacePage];
				Items[SetupStage.Button].Font = CommonClient.StyleFont("SynchronizationSetupWizardCommandStandardFont");
			EndIf;
		EndDo;
		
		For Each SetupStage In SetupSteps Do
			If Not SetupStage.Used Then
				Items[SetupStage.Group].Enabled = False;
				Items[SetupStage.Panel].CurrentPage = Items[SetupStage.EmptySpacePage];
			EndIf;
		EndDo;
		
	EndIf;
			
EndProcedure

&AtClient
Procedure GoToNextSetupStage()
	
	NextRow = Undefined;
	CurrentStageFound = False;
	For Each SetupStagesString In SetupSteps Do
		If CurrentStageFound And SetupStagesString.Used Then
			NextRow = SetupStagesString;
			Break;
		EndIf;
		
		If SetupStagesString.Name1 = CurrentSetupStep Then
			CurrentStageFound = True;
		EndIf;
	EndDo;
	
	If NextRow <> Undefined Then
		CurrentSetupStep = NextRow.Name1;
		
		If CurrentSetupStep = "RulesSetting" Then
			CheckParameters = New Structure;
			CheckParameters.Insert("Peer",          ExchangeNode);
			CheckParameters.Insert("ExchangePlanName",         ExchangePlanName);
			CheckParameters.Insert("SettingID", SettingID);
			
			SetupExecuted = SynchronizationSetupCompleted(ExchangeNode);
			If Not SetupExecuted Then
				If Not XDTOSetup Or XDTOCorrespondentSettingsReceived(ExchangeNode) Then
					BeforeDataSynchronizationSetup(CheckParameters, SetupExecuted, DataSyncSettingsWizardFormName);
				EndIf;
			EndIf;
			
			If SetupExecuted Then
				GoToNextSetupStage();
				Return;
			EndIf;
		EndIf;
			
		If Not NextRow.IsMain Then
			CurrentSetupStep = "";
		EndIf;
	Else
		CurrentSetupStep = "";
	EndIf;
	
	AttachIdleHandler("UpdateCurrentSettingsStateDisplay", 0.2, True);
	
EndProcedure

&AtServerNoContext
Function SynchronizationSetupCompleted(ExchangeNode, RefExists = False)
	
	RefExists = Common.RefExists(ExchangeNode);
	Return DataExchangeServer.SynchronizationSetupCompleted(ExchangeNode);
	
EndFunction

&AtServerNoContext
Function DataForMappingImported(ExchangeNode)
	
	Return Not DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode);
	
EndFunction

&AtServerNoContext
Procedure BeforeDataSynchronizationSetup(CheckParameters, SetupExecuted, WizardFormName)
	
	If DataExchangeServer.HasExchangePlanManagerAlgorithm("BeforeDataSynchronizationSetup", CheckParameters.ExchangePlanName) Then
		
		Context = New Structure;
		Context.Insert("Peer",          CheckParameters.Peer);
		Context.Insert("SettingID", CheckParameters.SettingID);
		Context.Insert("InitialSetting",     Not SynchronizationSetupCompleted(CheckParameters.Peer));
		
		ExchangePlans[CheckParameters.ExchangePlanName].BeforeDataSynchronizationSetup(
			Context, SetupExecuted, WizardFormName);
		
		If SetupExecuted Then
			DataExchangeServer.CompleteDataSynchronizationSetup(CheckParameters.Peer);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region FormInitializationOnCreate

&AtServer
Procedure InitializeFormProperties()
	
	Title = SettingOptionDetails.ExchangeCreateWizardTitle;
	
	If IsBlankString(Title) Then
		If DIBSetup Then
			Title = NStr("en = 'Configure distributed infobase';");
		Else
			Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Configure data synchronization with %1';"),
				SettingOptionDetails.CorrespondentDescription);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	Parameters.Property("SettingOptionDetails",    SettingOptionDetails);
	Parameters.Property("DataExchangeWithExternalSystem", DataExchangeWithExternalSystem);
	
	NewSYnchronizationSetting = Parameters.Property("NewSYnchronizationSetting");
	ContinueSetupInSubordinateDIBNode = Parameters.Property("ContinueSetupInSubordinateDIBNode");
	
	SaaSModel = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
	
	If NewSYnchronizationSetting Then
		ExchangePlanName         = Parameters.ExchangePlanName;
		SettingID = Parameters.SettingID;
		
		If DataExchangeWithExternalSystem Then
			Parameters.Property("ExternalSystemConnectionParameters", ExternalSystemConnectionParameters);
		Else
			If Not ContinueSetupInSubordinateDIBNode Then
				If DataExchangeServer.IsSubordinateDIBNode() Then
					DIBExchangePlanName = DataExchangeServer.MasterNode().Metadata().Name;
					
					ContinueSetupInSubordinateDIBNode = (ExchangePlanName = DIBExchangePlanName)
						And Not Constants.SubordinateDIBNodeSetupCompleted.Get();
				EndIf;
			EndIf;
			
			If ContinueSetupInSubordinateDIBNode Then
				DataExchangeServer.OnContinueSubordinateDIBNodeSetup();
				ExchangeNode = DataExchangeServer.MasterNode();
			EndIf;
		EndIf;
	Else
		ExchangeNode = Parameters.ExchangeNode;
		
		ExchangePlanName         = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		SettingID = DataExchangeServer.SavedExchangePlanNodeSettingOption(ExchangeNode);
		
		If SaaSModel Then
			Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
			Parameters.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
		EndIf;
		
		If DataExchangeWithExternalSystem Then
			UpdateExternalSystemConnectionParameters(ExchangeNode, ExternalSystemConnectionParameters);
		EndIf;
	EndIf;
	
	If ContinueSetupInSubordinateDIBNode
		Or (Not DataExchangeWithExternalSystem
			And SettingOptionDetails = Undefined) Then
		ModuleWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
		SettingOptionDetails = ModuleWizard.SettingOptionDetailsStructure();
		
		SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
			"CorrespondentConfigurationDescription,
			|NewDataExchangeCreationCommandTitle,
			|ExchangeCreateWizardTitle,
			|BriefExchangeInfo,
			|DetailedExchangeInformation",
			SettingID);
			
		FillPropertyValues(SettingOptionDetails, SettingsValuesForOption);
		SettingOptionDetails.CorrespondentDescription = SettingsValuesForOption.CorrespondentConfigurationDescription;
	EndIf;
	
	TransportKind = Undefined;
	If ValueIsFilled(ExchangeNode) Then
		SettingCompleted = SynchronizationSetupCompleted(ExchangeNode);
		TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ExchangeNode);
		TransportSettingsAvailable = ValueIsFilled(TransportKind);
	EndIf;
	
	Backup = Not SaaSModel
		And Not ContinueSetupInSubordinateDIBNode
		And Common.SubsystemExists("StandardSubsystems.IBBackup");
		
	If Backup Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		
		BackupDataProcessorURL =
			ModuleIBBackupServer.BackupDataProcessorURL();
	EndIf;
		
	DIBSetup                  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
	XDTOSetup                 = DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName);
	UniversalExchangeSetup = DataExchangeCached.IsStandardDataExchangeNode(ExchangePlanName); // No conversion rules.
	
	InteractiveSendingAvailable = Not DIBSetup And Not UniversalExchangeSetup;
	
	If Not DataExchangeWithExternalSystem Then
	
		If NewSYnchronizationSetting
			Or DIBSetup
			Or UniversalExchangeSetup Then
			DataReceivedForMapping = False;
		ElsIf IsExchangeWithApplicationInService Then
			DataReceivedForMapping = DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode);
		Else
			If TransportKind = Enums.ExchangeMessagesTransportTypes.COM
				Or TransportKind = Enums.ExchangeMessagesTransportTypes.WS
				Or TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode
				Or Not TransportSettingsAvailable Then
				DataReceivedForMapping = DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode);
			Else
				DataReceivedForMapping = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"InitialImageCreationFormName,
		|DataSyncSettingsWizardFormName,
		|DataMappingSupported",
		SettingID);
	FillPropertyValues(ThisObject, SettingsValuesForOption);
	
	If IsBlankString(InitialImageCreationFormName)
		And Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		InitialImageCreationFormName = "CommonForm.[InitialImageCreationForm]";
		InitialImageCreationFormName = StrReplace(InitialImageCreationFormName,
			"[InitialImageCreationForm]", "CreateInitialImageWithFiles");
	EndIf;
	
	CurrentSetupStep = "";
	If NewSYnchronizationSetting Then
		CurrentSetupStep = "ConnectionSetup";
	ElsIf DataExchangeWithExternalSystem
		And Not XDTOCorrespondentSettingsReceived(ExchangeNode) Then
		CurrentSetupStep = "ConfirmConnection";
	ElsIf Not SynchronizationSetupCompleted(ExchangeNode) Then
		CurrentSetupStep = "RulesSetting";
	ElsIf DIBSetup
		And Not ContinueSetupInSubordinateDIBNode
		And Not InitialImageCreated(ExchangeNode) Then
		If Not IsBlankString(InitialImageCreationFormName) Then
			CurrentSetupStep = "InitialDIBImage";
		EndIf;
	ElsIf ValueIsFilled(ExchangeNode) Then
		MessagesNumbers = Common.ObjectAttributesValues(ExchangeNode, "ReceivedNo, SentNo");
		If MessagesNumbers.ReceivedNo = 0
			And MessagesNumbers.SentNo = 0
			And DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode) Then
			CurrentSetupStep = "MapAndImport";
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Function AddSetupStage(Name1, Button, FormItems, Used, IsMain = True)
	
	StageString = SetupSteps.Add();
	StageString.Name1        = Name1;
	StageString.Button          = Button;
	StageString.Used    = Used;
	StageString.IsMain        = IsMain;
	
	FillPropertyValues(StageString, FormItems);
	
	Return StageString;
	
EndFunction

&AtClient
Procedure FillSetupStagesTable()
	
	SetupSteps.Clear();

	// Configure connection.
	TheStageIsUsed = TransportSettingsAvailable Or NewSYnchronizationSetting;
	
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.ConnectionSetupGroup.Name);
	FormItems.Insert("Panel"			, Items.ConnectionSetupPanel.Name);
	FormItems.Insert("PageSuccessfully", Items.ConnectionSetupSuccessfulPage.Name);
	FormItems.Insert("PageCurrent", Items.ConnectionSetupPageActive.Name);
	FormItems.Insert("EmptySpacePage"	, Items.ConnectionSetupPageEmpty.Name);
	
	AddSetupStage("ConnectionSetup", "SetUpConnectionParameters", FormItems, TheStageIsUsed);

	// 	
	TheStageIsUsed = DataExchangeWithExternalSystem;
	
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.ConnectionConfirmationGroup.Name);
	FormItems.Insert("Panel"			, Items.ConnectionConfirmationPanel.Name);
	FormItems.Insert("PageSuccessfully", Items.ConnectionConfirmationStepSucceededPage.Name);
	FormItems.Insert("PageCurrent", Items.ConnectionConfirmationStepInProgressPage.Name);
	FormItems.Insert("EmptySpacePage"	, Items.ConnectionConfirmationStepToProcessPage.Name);
	
	AddSetupStage("ConfirmConnection", "GetConnectionConfirmation", FormItems, TheStageIsUsed);
		
	// 
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.RulesSetupGroup.Name);
	FormItems.Insert("Panel"			, Items.RulesSetupPanel.Name);
	FormItems.Insert("PageSuccessfully", Items.RulesSetupSuccessfulPage.Name);
	FormItems.Insert("PageCurrent", Items.RulesSetupPageActive.Name);
	FormItems.Insert("EmptySpacePage"	, Items.RulesSetupPageEmpty.Name);
	
	AddSetupStage("RulesSetting", "SetSendingAndReceivingRules", FormItems, True);
		
	// 	
	TheStageIsUsed = Not DataExchangeWithExternalSystem
		And DIBSetup
		And Not ContinueSetupInSubordinateDIBNode
		And Not IsBlankString(InitialImageCreationFormName);
		
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.InitialDIBImageGroup.Name);
	FormItems.Insert("Panel"			, Items.InitialDIBImagePanel.Name);
	FormItems.Insert("PageSuccessfully", Items.InitialDIBImagePageSuccessful.Name);
	FormItems.Insert("PageCurrent", Items.InitialDIBImagePageActive.Name);
	FormItems.Insert("EmptySpacePage"	, Items.InitialDIBImagePageEmpty.Name);
	
	AddSetupStage("InitialDIBImage", "CreateInitialDIBImage", FormItems, TheStageIsUsed);
		
	// 	
	TheStageIsUsed = Not DataExchangeWithExternalSystem 
		And Not DIBSetup
		And Not UniversalExchangeSetup
		And DataReceivedForMapping
		And DataMappingSupported <> False;
		
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.MapAndImportGroup.Name);
	FormItems.Insert("Panel"			, Items.MapAndImportPanel.Name);
	FormItems.Insert("PageSuccessfully", Items.MapAndImportPageSuccessful.Name);
	FormItems.Insert("PageCurrent", Items.MapAndImportPageActive.Name);
	FormItems.Insert("EmptySpacePage"	, Items.MapAndImportPageEmpty.Name);
	
	AddSetupStage("MapAndImport", "MapAndExportData", FormItems, TheStageIsUsed);
		
	// 
	TheStageIsUsed = Not DataExchangeWithExternalSystem
		And InteractiveSendingAvailable
		And (TransportSettingsAvailable
			Or NewSYnchronizationSetting);
			
	FormItems = New Structure;
	FormItems.Insert("Group"			, Items.InitialDataExportGroup.Name);
	FormItems.Insert("Panel"			, Items.InitialDataExportPanel.Name);
	FormItems.Insert("PageSuccessfully", Items.InitialDataExportPageSuccessful.Name);
	FormItems.Insert("PageCurrent", Items.InitialDataExportPageActive.Name);
	FormItems.Insert("EmptySpacePage"	, Items.InitialDataExportPageEmpty.Name);
	
	AddSetupStage("InitialDataExport", "ExecuteInitialDataExport", FormItems, TheStageIsUsed);
	
EndProcedure

&AtServer
Procedure SetInitialFormItemsView()
	
	Items.ExchangeBriefInfoLabelDecoration.Title = SettingOptionDetails.BriefExchangeInfo;
	Items.DataSyncDetails.Visible = ValueIsFilled(SettingOptionDetails.DetailedExchangeInformation);
	Items.GroupBackupPrompt.Visible = Backup;
	Items.GetConnectionConfirmation.ExtendedTooltip.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.GetConnectionConfirmation.ExtendedTooltip.Title,
		SettingOptionDetails.CorrespondentDescription);
		
	If Backup Then
		Items.BackupLabelDecoration.Title = StringFunctions.FormattedString(
			NStr("en = 'It is recommend that you <a href=""%1"">back up your data</a> before you start setting up a new data sync.';"),
			BackupDataProcessorURL);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion