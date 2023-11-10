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
	
	InfobaseNode = DataExchangeServer.MasterNode();
	IsStandaloneWorkplace = DataExchangeServer.IsStandaloneWorkplace();
	
	If IsStandaloneWorkplace Then
		Items.ConnectionParametersPages.CurrentPage = Items.SWPPage;
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		AccountPasswordRecoveryAddress = ModuleStandaloneMode.AccountPasswordRecoveryAddress();
		TimeConsumingOperationAllowed = True;
		
		If DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode) Then
			Password = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
		EndIf;
		
	EndIf;
	
	NodeNameLabel = NStr("en = 'Cannot install the application update received from
		|""%1"".
		|See the <a href = ""%2"">Event Log</a> for technical information.';");
	Items.NodeNameHelpText.Title = 
		StringFunctions.FormattedString(NodeNameLabel, InfobaseNode.Description, "EventLog");
	
	SetFormItemsView();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NodeNameHelpTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters,,,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SyncAndContinue(Command)
	
	WarningText = "";
	HasErrors = False;
	TimeConsumingOperation = False;
	
	CheckUpdateRequired();
	
	If UpdateStatus = "NoUpdateRequired" Then
		
		SynchronizeAndContinueWithoutIBUpdate();
		
	ElsIf UpdateStatus = "InfobaseUpdate" Then
		
		SynchronizeAndContinueWithIBUpdate();
		
	ElsIf UpdateStatus = "ConfigurationUpdate" Then
		
		WarningText = NStr("en = 'Changes that have not been applied yet were received from the main node.
			|Open Designer and update the database configuration.';");
		
	EndIf;
	
	If Not TimeConsumingOperation Then
		
		SyncAndContinueCompletion();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotSyncAndContinue(Command)
	
	DoNotSyncAndContinueAtServer();
	
	Close("Continue");
	
EndProcedure

&AtClient
Procedure ExitApplication(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ConnectionParameters(Command)
	
	Filter              = New Structure("Peer", InfobaseNode);
	FillingValues = New Structure("Peer", InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", Undefined);
	
EndProcedure

&AtClient
Procedure ForgotPassword(Command)
	DataExchangeClient.OpenInstructionHowToChangeDataSynchronizationPassword(AccountPasswordRecoveryAddress);
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure SynchronizeAndContinueWithoutIBUpdate()
	
	ImportDataExchangeMessageWithoutUpdating();
	
	If TimeConsumingOperation Then
		RetryCountOnConnectionError = 0;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithoutIBUpdateCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithoutIBUpdateCompletion()
	
	// 
	// 
	// 
	// 
	// 
	// 
	//   
	// 
	//   
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		// If the message is imported, reimporting is not required.
		If Constants.LoadDataExchangeMessage.Get() Then
			Constants.LoadDataExchangeMessage.Set(False);
		EndIf;
		Constants.RetryDataExchangeMessageImportBeforeStart.Set(False);
		
		Try
			ExportMessageAfterInfobaseUpdate();
		Except
			// 
			// 
			EventLogMessageKey = DataExchangeServer.DataExchangeEventLogEvent();
			WriteLogEvent(EventLogMessageKey,
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	ElsIf ConfigurationChanged() Then
		If Not Constants.LoadDataExchangeMessage.Get() Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Changes to be applied were received from the main node.
			|Open Designer and update the database configuration.';");
	Else
		
		If InfobaseUpdate.InfobaseUpdateRequired() Then
			EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		
		WarningText = NStr("en = 'Receiving data from the master node is completed with errors.
			|For more information, see the event log.';");
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportMessageAfterInfobaseUpdate()
	
	// 
	DataExchangeServer.DisableDataExchangeMessageImportRepeatBeforeStart();
	
	Try
		If GetFunctionalOption("UseDataSynchronization") Then
			
			InfobaseNode = DataExchangeServer.MasterNode();
			
			If InfobaseNode <> Undefined Then
				
				ExecuteExport = True;
				
				TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(InfobaseNode);
				
				TransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
				
				If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
					And Not TransportSettings.WSRememberPassword Then
					
					ExecuteExport = False;
					
					InformationRegisters.CommonInfobasesNodesSettings.SetDataSendingFlag(InfobaseNode);
					
				EndIf;
				
				If ExecuteExport Then
					
					AuthenticationParameters = ?(IsStandaloneWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
					
					// Export only.
					Cancel = False;
					
					ExchangeParameters = DataExchangeServer.ExchangeParameters();
					ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
					ExchangeParameters.ExecuteImport1 = False;
					ExchangeParameters.ExecuteExport2 = True;
					ExchangeParameters.AuthenticationParameters = AuthenticationParameters;
					
					If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
						
						ExchangeParameters.TheTimeoutOnTheServer = 15;
						
					EndIf;
					
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, Cancel);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Except
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithoutUpdating()
	
	Try
		ImportMessageBeforeInfobaseUpdate();
	Except
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemsView();
	
EndProcedure

&AtServer
Procedure ImportMessageBeforeInfobaseUpdate()
	
	If DataExchangeInternal.DataExchangeMessageImportModeBeforeStart(
			"SkipImportDataExchangeMessageBeforeStart") Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDataSynchronization") Then
		
		If InfobaseNode <> Undefined Then
			
			SetPrivilegedMode(True);
			DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
			SetPrivilegedMode(False);
			
			// 
			DataExchangeServer.UpdateDataExchangeRules();
			
			TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
			
			OperationStartDate = CurrentSessionDate();
			
			AuthenticationParameters = ?(IsStandaloneWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
			
			// Import only.
			ExchangeParameters = DataExchangeServer.ExchangeParameters();
			ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
			ExchangeParameters.ExecuteImport1 = True;
			ExchangeParameters.ExecuteExport2 = False;
			
			ExchangeParameters.TimeConsumingOperationAllowed = TimeConsumingOperationAllowed;
			ExchangeParameters.TimeConsumingOperation          = TimeConsumingOperation;
			ExchangeParameters.OperationID       = OperationID;
			ExchangeParameters.FileID          = FileID;
			ExchangeParameters.AuthenticationParameters     = AuthenticationParameters;
			
			If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
				
				ExchangeParameters.TheTimeoutOnTheServer = 15;
				
			EndIf;
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, HasErrors);
			
			TimeConsumingOperationAllowed = ExchangeParameters.TimeConsumingOperationAllowed;
			TimeConsumingOperation          = ExchangeParameters.TimeConsumingOperation;
			OperationID       = ExchangeParameters.OperationID;
			FileID          = ExchangeParameters.FileID;
			AuthenticationParameters     = ExchangeParameters.AuthenticationParameters;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure SynchronizeAndContinueWithIBUpdate()
	
	ImportDataExchangeMessageWithUpdate();
	
	If TimeConsumingOperation Then
		RetryCountOnConnectionError = 0;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
		
	Else
		
		SynchronizeAndContinueWithIBUpdateCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SynchronizeAndContinueWithIBUpdateCompletion()
	
	SetPrivilegedMode(True);
	
	If Not HasErrors Then
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		If Not Constants.LoadDataExchangeMessage.Get() Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
			"SkipImportPriorityDataBeforeStart", True);
		
	ElsIf ConfigurationChanged() Then
			
		If Not Constants.LoadDataExchangeMessage.Get() Then
			Constants.LoadDataExchangeMessage.Set(True);
		EndIf;
		WarningText = NStr("en = 'Changes to be applied were received from the main node.
			|Open Designer and update the database configuration.';");
		
	Else
		
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", False);
		
		EnableDataExchangeMessageImportRecurrenceBeforeStart();
		
		WarningText = NStr("en = 'Receiving data from the master node is completed with errors.
			|For more information, see the event log.';");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportDataExchangeMessageWithUpdate()
	
	Try
		ImportPriorityDataToSubordinateDIBNode();
	Except
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
	EndTry;
	
	SetFormItemsView();
	
EndProcedure

&AtServer
Procedure ImportPriorityDataToSubordinateDIBNode()
	
	If DataExchangeInternal.DataExchangeMessageImportModeBeforeStart(
			"SkipImportDataExchangeMessageBeforeStart") Then
		Return;
	EndIf;
	
	If DataExchangeInternal.DataExchangeMessageImportModeBeforeStart(
			"SkipImportPriorityDataBeforeStart") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
	SetPrivilegedMode(False);
	
	CheckDataSynchronizationEnabled();
	
	If GetFunctionalOption("UseDataSynchronization") Then
		
		InfobaseNode = DataExchangeServer.MasterNode();
		
		If InfobaseNode <> Undefined Then
			
			TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
			
			ParameterName = "StandardSubsystems.DataExchange.RecordRules."
				+ DataExchangeCached.GetExchangePlanName(InfobaseNode);
			RegistrationRulesUpdated = StandardSubsystemsServer.ApplicationParameter(ParameterName);
			If RegistrationRulesUpdated = Undefined Then
				DataExchangeServer.UpdateDataExchangeRules();
			EndIf;
			RegistrationRulesUpdated = StandardSubsystemsServer.ApplicationParameter(ParameterName);
			If RegistrationRulesUpdated = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot update data registration rules cache for exchange plan ""%1""';"),
					DataExchangeCached.GetExchangePlanName(InfobaseNode));
			EndIf;
			
			OperationStartDate = CurrentSessionDate();
			
			AuthenticationParameters = ?(IsStandaloneWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
			
			// Importing application parameters only.
			ExchangeParameters = DataExchangeServer.ExchangeParameters();
			ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
			ExchangeParameters.ExecuteImport1 = True;
			ExchangeParameters.ExecuteExport2 = False;
			ExchangeParameters.ParametersOnly   = True;
			
			ExchangeParameters.TimeConsumingOperationAllowed = TimeConsumingOperationAllowed;
			ExchangeParameters.TimeConsumingOperation          = TimeConsumingOperation;
			ExchangeParameters.OperationID       = OperationID;
			ExchangeParameters.FileID          = FileID;
			ExchangeParameters.AuthenticationParameters     = AuthenticationParameters;
			
			If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
				
				ExchangeParameters.TheTimeoutOnTheServer = 15;
				
			EndIf;
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, HasErrors);
			
			TimeConsumingOperationAllowed = ExchangeParameters.TimeConsumingOperationAllowed;
			TimeConsumingOperation          = ExchangeParameters.TimeConsumingOperation;
			OperationID       = ExchangeParameters.OperationID;
			FileID          = ExchangeParameters.FileID;
			AuthenticationParameters     = ExchangeParameters.AuthenticationParameters;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure DoNotSyncAndContinueAtServer()
	
	SetPrivilegedMode(True);
	
	If Not InfobaseUpdate.InfobaseUpdateRequired() Then
		If Constants.LoadDataExchangeMessage.Get() Then
			Constants.LoadDataExchangeMessage.Set(False);
			DataExchangeServer.ClearDataExchangeMessageFromMasterNode();
		EndIf;
	EndIf;
	
	DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
		"SkipImportDataExchangeMessageBeforeStart", True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure CheckUpdateRequired()
	
	SetPrivilegedMode(True);
	
	If ConfigurationChanged() Then
		UpdateStatus = "ConfigurationUpdate";
	ElsIf InfobaseUpdate.InfobaseUpdateRequired() Then
		UpdateStatus = "InfobaseUpdate";
	Else
		UpdateStatus = "NoUpdateRequired";
	EndIf;
	
EndProcedure

&AtClient
Procedure SyncAndContinueCompletion()
	
	SetFormItemsView();
	
	If IsBlankString(WarningText) Then
		Close("Continue");
	Else
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Sets the RetryDataExchangeMessageImportBeforeStart constant value to True.
// Clears exchange messages received from the master node.
//
&AtServer
Procedure EnableDataExchangeMessageImportRecurrenceBeforeStart()
	
	DataExchangeServer.ClearDataExchangeMessageFromMasterNode();
	
	Constants.RetryDataExchangeMessageImportBeforeStart.Set(True);
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationIdleHandler()
	
	AuthenticationParameters = ?(IsStandaloneWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
	
	ActionState = TimeConsumingOperationStateForInfobaseNode(
		OperationID,
		InfobaseNode,
		AuthenticationParameters,
		WarningText);
		
	If ActionState = Undefined
		And RetryCountOnConnectionError < 5 Then
		RetryCountOnConnectionError = RetryCountOnConnectionError + 1;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
		Return;
	EndIf;
	
	If ActionState = "Active" Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
	Else
		If ActionState <> "Completed" Then
			HasErrors = True;
		EndIf;
		TimeConsumingOperation = False;
		
		ProcessTimeConsumingOperationCompletion();
		
		If UpdateStatus = "NoUpdateRequired" Then
			
			SynchronizeAndContinueWithoutIBUpdateCompletion();
			
		ElsIf UpdateStatus = "InfobaseUpdate" Then
			
			SynchronizeAndContinueWithIBUpdateCompletion();
			
		EndIf;
		
		SyncAndContinueCompletion();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckDataSynchronizationEnabled()
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		
		If Common.DataSeparationEnabled() Then
			
			UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
			UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			UseDataSynchronization.DataExchange.Load = True;
			UseDataSynchronization.Value = True;
			UseDataSynchronization.Write();
			
		Else
			
			If DataExchangeServer.GetExchangePlansInUse().Count() > 0 Then
				
				UseDataSynchronization = Constants.UseDataSynchronization.CreateValueManager();
				UseDataSynchronization.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				UseDataSynchronization.DataExchange.Load = True;
				UseDataSynchronization.Value = True;
				UseDataSynchronization.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemsView()
	
	If DataExchangeServer.LoadDataExchangeMessage()
		And InfobaseUpdate.InfobaseUpdateRequired() Then
		
		Items.FormDoNotSyncAndContinue.Visible = False;
		Items.DoNotSyncHelpText.Visible = False;
	Else
		Items.FormDoNotSyncAndContinue.Visible = True;
		Items.DoNotSyncHelpText.Visible = True;
	EndIf;
	
	Items.PanelMain.CurrentPage = ?(TimeConsumingOperation, Items.TimeConsumingOperation, Items.Begin);
	Items.TimeConsumingOperationButtonsGroup.Visible = TimeConsumingOperation;
	Items.MainButtonsGroup.Visible = Not TimeConsumingOperation;
	
EndProcedure

&AtClient
Procedure ProcessTimeConsumingOperationCompletion()
	
	If Not HasErrors Then
		
		ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
			InfobaseNode,
			FileID,
			OperationStartDate);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate)
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	AuthenticationParameters = ?(IsStandaloneWorkplace, New Structure("UseCurrentUser, Password", True, Password), Undefined);
	
	SetPrivilegedMode(True);
	
	Try
		FileExchangeMessages = DataExchangeWebService.GetFileFromStorageInService(New UUID(FileID),
			InfobaseNode,, AuthenticationParameters);
	Except
		DataExchangeServer.WriteExchangeFinishWithError(InfobaseNode,
			Enums.ActionsOnExchange.DataImport,
			OperationStartDate,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			HasErrors = True;
		Return;
	EndTry;
	
	NewMessage = New BinaryData(FileExchangeMessages);
	DataExchangeServer.SetDataExchangeMessageFromMasterNode(NewMessage, InfobaseNode);
	
	Try
		DeleteFiles(FileExchangeMessages);
	Except
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Try
		
		ParametersOnly = (UpdateStatus = "InfobaseUpdate");
		TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
		
		ExchangeParameters = DataExchangeServer.ExchangeParameters();
		ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
		ExchangeParameters.ExecuteImport1 = True;
		ExchangeParameters.ExecuteExport2 = False;
		ExchangeParameters.ParametersOnly = ParametersOnly;
		ExchangeParameters.AuthenticationParameters = AuthenticationParameters;
		
		If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
			
			ExchangeParameters.TheTimeoutOnTheServer = 15;
			
		EndIf;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, HasErrors);
		
	Except
		
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		HasErrors = True;
		
	EndTry;
	
EndProcedure

&AtServerNoContext
Function TimeConsumingOperationStateForInfobaseNode(
		TimeConsumingOperationID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorMessage)
		
	ActionState = Undefined;
	Try
		ActionState = DataExchangeInternal.TimeConsumingOperationStateForInfobaseNode(
			TimeConsumingOperationID,
			InfobaseNode,
			AuthenticationParameters,
			ErrorMessage);
	Except
		Information = ErrorInfo();
		ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
			
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
	EndTry;
		
	Return ActionState;
	
EndFunction

#EndRegion