///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Parameters:
//   XDTOSetup - Boolean - True if the exchange via the XDTO is configured.
// 
// Returns:
//   Structure - 
//     * ExchangePlanName - String - an exchange plan name.
//     * CorrespondentExchangePlanName - String - a peer exchange plan name.
//     * SettingID - String - the setting option name as it is specified in the exchange plan manager module.
//     * ExchangeFormat - String - an exchange format name.
//     * Description - String - the description of this application.
//     * CorrespondentDescription - String - the peer infobase application description.
//     * Prefix - String - the prefix of this application.
//     * CorrespondentPrefix - String - peer infobase application prefix.
//     * SourceInfobaseID - String - the ID of this application.
//     * DestinationInfobaseID - String - the peer infobase application ID.
//     * CorrespondentEndpoint - DefinedType.MessagesQueueEndpoint - message exchange point.
//     * Peer - ExchangePlanRef - an exchange plan node.
//     * CorrespondentDataArea - Number - peer infobase data area number.
//     * XDTOCorrespondentSettings - Structure - details of the exchange format settings of the XDTO correspondent:
//       ** SupportedVersions - Array of String - (optional) the set of supported versions of the exchange format.
//       ** SupportedObjects - ValueStorage - a table of supported format objects.
// 
Function ConnectionSettingsDetails(XDTOSetup) Export
	
	ConnectionSettings = New Structure;
	ConnectionSettings.Insert("ExchangePlanName",               "");
	ConnectionSettings.Insert("CorrespondentExchangePlanName", "");
	
	ConnectionSettings.Insert("SettingID", "");
	
	ConnectionSettings.Insert("ExchangeFormat", "");
	
	ConnectionSettings.Insert("Description",               "");
	ConnectionSettings.Insert("CorrespondentDescription", "");
	
	ConnectionSettings.Insert("Prefix",               "");
	ConnectionSettings.Insert("CorrespondentPrefix", "");
	
	ConnectionSettings.Insert("SourceInfobaseID", "");
	ConnectionSettings.Insert("DestinationInfobaseID", "");
	
	ConnectionSettings.Insert("CorrespondentEndpoint");

	ConnectionSettings.Insert("Peer");
	ConnectionSettings.Insert("CorrespondentDataArea", 0);
	
	If XDTOSetup Then
		XDTOCorrespondentSettings = New Structure;
		XDTOCorrespondentSettings.Insert("SupportedVersions", New Array);
		XDTOCorrespondentSettings.Insert("SupportedObjects");
		
		ConnectionSettings.Insert("XDTOCorrespondentSettings", XDTOCorrespondentSettings);
	EndIf;
	
	Return ConnectionSettings;
	
EndFunction

// For internal use
//
Procedure SetUpExchangeStep13011(Parameters, TempStorageAddress) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	MessageExchangePlanName = "MessagesExchange";
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	MessageExchangePlanManager = Common.ObjectManagerByFullName("ExchangePlan."
		+ MessageExchangePlanName);
	
	ConnectionSettings = Undefined; // See ConnectionSettingsDetails
	Parameters.Property("ConnectionSettings", ConnectionSettings);
	
	SessionHandlerParameters = TimeConsumingOperationHandlerParameters();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// 
		DataExchangeSaaS.CreateExchangeSetting_3_0_1_1(ConnectionSettings);
		
		// Send a message to a peer infobase.
		Message = ModuleMessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.SetUpExchangeStep1Message());
			
		Message.Body.CorrespondentZone = ConnectionSettings.CorrespondentDataArea;
		
		Message.Body.ExchangePlan      = ConnectionSettings.ExchangePlanName;
		Message.Body.CorrespondentCode = ConnectionSettings.SourceInfobaseID;
		Message.Body.CorrespondentName = ConnectionSettings.Description;
		
		Message.Body.Code     = ConnectionSettings.DestinationInfobaseID;
		Message.Body.EndPoint = Common.ObjectAttributeValue(MessageExchangePlanManager.ThisNode(), "Code");
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			FormatVersions = Common.UnloadColumn(
				DataExchangeServer.ExchangePlanSettingValue(ConnectionSettings.ExchangePlanName, "ExchangeFormatVersions"), "Key", True);
				
			FormatObjects = DataExchangeXDTOServer.SupportedObjectsInFormat(
				ConnectionSettings.ExchangePlanName, "SendReceive", ConnectionSettings.Peer);
			
			XDTOCorrespondentSettings = New Structure;
			XDTOCorrespondentSettings.Insert("SupportedVersions", FormatVersions);
			XDTOCorrespondentSettings.Insert("SupportedObjects",
				New ValueStorage(FormatObjects, New Deflation(9)));
				
			Message.Body.XDTOSettings = XDTOSerializer.WriteXDTO(XDTOCorrespondentSettings);
		EndIf;
		
		AdditionalProperties = New Structure;
		AdditionalProperties.Insert("Interface",              "3.0.1.1");
		AdditionalProperties.Insert("Prefix",                ConnectionSettings.CorrespondentPrefix);
		AdditionalProperties.Insert("CorrespondentPrefix",  ConnectionSettings.Prefix);
		AdditionalProperties.Insert("SettingID", ConnectionSettings.SettingID);
		
		Message.AdditionalInfo = XDTOSerializer.WriteXDTO(AdditionalProperties);
		
		SessionHandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		Information = ErrorInfo();
		
		SessionHandlerParameters.Cancel = True;
		SessionHandlerParameters.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
	EndTry;
		
	If Not SessionHandlerParameters.Cancel Then
		ModuleMessagesSaaS.DeliverQuickMessages();
		
		SessionHandlerParameters.TimeConsumingOperation = True;
		SessionHandlerParameters.AdditionalParameters.Insert(
			"Peer", ConnectionSettings.Peer);
	EndIf;
	
	Result = New Structure;
	Result.Insert("Peer", ConnectionSettings.Peer);
	Result.Insert("SessionHandlerParameters", SessionHandlerParameters);
	
	PutToTempStorage(Result, TempStorageAddress);
	
EndProcedure

#Region ApplicationsList

// Parameters:
//   Settings - Structure - operation execution setting details.
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   ContinueWait - Boolean - True if a long-running operation is running.
//
Procedure OnStartGetApplicationList(Settings, HandlerParameters, ContinueWait = True) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	HandlerParameters = TimeConsumingOperationHandlerParameters();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// Sending a message to SaaS.
		Message = ModuleMessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.GetDataSynchronizationSettingsMessage());
			
		// ExchangeFormat - Mustn't filter as the whole table is needed, including the nodes with setup synchronization.
		AdditionalProperties = New Structure("Mode");
		FillPropertyValues(AdditionalProperties, Settings);
		
		Message.AdditionalInfo = XDTOSerializer.WriteXDTO(AdditionalProperties);
			
		HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
			
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationMonitor(),
			EventLogLevel.Error, , , ErrorMessage);
			
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorMessage;
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait = False;
	EndTry;
	
	If Not HandlerParameters.Cancel Then
		ModuleMessagesSaaS.DeliverQuickMessages();
		
		For Each SettingItem In Settings Do
			HandlerParameters.AdditionalParameters.Insert(SettingItem.Key, SettingItem.Value);
		EndDo;
		
		ContinueWait = True;
	EndIf;
	
EndProcedure

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   ContinueWait - Boolean - True if a long-running operation is not completed yet.
//
Procedure OnWaitForGetApplicationList(HandlerParameters, ContinueWait = True) Export
	
	If HandlerParameters.AdditionalParameters.Property("WaitForSessionGetCorrespondentParameters") Then
		
		ContinueWait = False;
		
		AreasToDetermineNodeCodes = HandlerParameters.AdditionalParameters.AreasToDetermineNodeCodes.Get();
		
		For Each Area In AreasToDetermineNodeCodes Do
			
			For Each NodesCodesString In Area.NodesCodes Do
				
				If NodesCodesString.ContinueWait Then
					OnWaitSystemMessagesExchangeSession(NodesCodesString.HandlerParameters, NodesCodesString.ContinueWait);
				EndIf;
				
				If Not NodesCodesString.ContinueWait
					And Not ValueIsFilled(NodesCodesString.PredefinedNodeCode)
					And Not NodesCodesString.HandlerParameters.Cancel Then
					
					CorrespondentParameters = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(
						NodesCodesString.HandlerParameters.OperationID).Get();
						
					If CorrespondentParameters.Property("InfoBaseAdmParams") Then
						If CorrespondentParameters.InfoBaseAdmParams.NodeExists Then
							NodesCodesString.PredefinedNodeCode = CorrespondentParameters.InfoBaseAdmParams.ThisNodeCode;
						EndIf;
					EndIf;
					
				EndIf;
				
				ContinueWait = ContinueWait Or NodesCodesString.ContinueWait;
				
			EndDo;
			
		EndDo;
		
		HandlerParameters.AdditionalParameters.AreasToDetermineNodeCodes =
			New ValueStorage(AreasToDetermineNodeCodes, New Deflation(9));
		
	Else
		OnWaitSystemMessagesExchangeSession(HandlerParameters, ContinueWait);
		
		If Not ContinueWait
			And Not HandlerParameters.Cancel Then
			
			SynchronizationSettingsFromServiceManager = Undefined;
			
			SetPrivilegedMode(True);
			Try
				SynchronizationSettingsFromServiceManager = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(
					HandlerParameters.OperationID).Get();
			Except
				Information = ErrorInfo();
				
				HandlerParameters.Cancel = True;
				HandlerParameters.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
				HandlerParameters.OperationID = Undefined;
				
				WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationMonitor(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
					
				Return;
			EndTry;
			
			DeleteUnnecessarySynchronizationSettingsRows(SynchronizationSettingsFromServiceManager, HandlerParameters.AdditionalParameters);
			
			HasPredefinedNodeCode = SynchronizationSettingsFromServiceManager.Columns.Find("PredefinedNodeCode") <> Undefined;
			If Not HasPredefinedNodeCode Then
				SynchronizationSettingsFromServiceManager.Columns.Add("PredefinedNodeCode", New TypeDescription("String"));
			EndIf;
			
			XDTOSynchronizationSettingsStrings = SynchronizationSettingsFromServiceManager.FindRows(
				New Structure("IsXDTOExchangePlan, SynchronizationConfigured", True, True));
				
			AreasToDetermineNodeCodes = New ValueTable;
			AreasToDetermineNodeCodes.Columns.Add("DataArea", New TypeDescription("Number"));
			AreasToDetermineNodeCodes.Columns.Add("ExchangePlan",    New TypeDescription("String"));
			AreasToDetermineNodeCodes.Columns.Add("NodesCodes");
				
			For Each XDTOSynchronizationSettingsString In XDTOSynchronizationSettingsStrings Do
				
				If ValueIsFilled(XDTOSynchronizationSettingsString.PredefinedNodeCode) Then
					Continue;
				EndIf;
				
				NodesCodes = New ValueTable;
				NodesCodes.Columns.Add("ThisNodeCode",             New TypeDescription("String"));
				NodesCodes.Columns.Add("PredefinedNodeCode", New TypeDescription("String"));
				NodesCodes.Columns.Add("HandlerParameters");
				NodesCodes.Columns.Add("ContinueWait",       New TypeDescription("Boolean"));
				
				Query = New Query(
				"SELECT
				|	T.Ref AS ExchangeNode
				|FROM
				|	#ExchangePlanTable AS T
				|WHERE
				|	NOT T.ThisNode");
				
				Query.Text = StrReplace(Query.Text,
					"#ExchangePlanTable", "ExchangePlan." + XDTOSynchronizationSettingsString.ExchangePlan);
				
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					ThisNodeCode = DataExchangeServer.NodeIDForExchange(Selection.ExchangeNode);
					
					CorrespondentDataArea = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(Selection.ExchangeNode,
						"CorrespondentDataArea");
					
					If XDTOSynchronizationSettingsString.DataArea = CorrespondentDataArea Then
						NodesCodesString = NodesCodes.Add();
						NodesCodesString.ThisNodeCode = ThisNodeCode;
						NodesCodesString.PredefinedNodeCode = DataExchangeServer.CorrespondentNodeIDForExchange(Selection.ExchangeNode);
						NodesCodesString.ContinueWait = False; 
						Break;
					EndIf;
				EndDo;
				
				Selection.Reset();
				
				While Selection.Next() Do
					ThisNodeCode = DataExchangeServer.NodeIDForExchange(Selection.ExchangeNode);
					
					If Not NodesCodes.Find(ThisNodeCode, "ThisNodeCode") = Undefined Then
						Continue;
					EndIf;
					
					NodesCodesString = NodesCodes.Add();
					NodesCodesString.ThisNodeCode = ThisNodeCode;
					NodesCodesString.ContinueWait = True;
					
				EndDo;
				
				Area = AreasToDetermineNodeCodes.Add();
				FillPropertyValues(Area, XDTOSynchronizationSettingsString, "DataArea, ExchangePlan");
				Area.NodesCodes = NodesCodes;
				
			EndDo;
				
			HandlerParameters.AdditionalParameters.Insert("SynchronizationSettingsFromServiceManager",
				New ValueStorage(SynchronizationSettingsFromServiceManager, New Deflation(9)));
			HandlerParameters.AdditionalParameters.Insert("AreasToDetermineNodeCodes",
					New ValueStorage(AreasToDetermineNodeCodes, New Deflation(9)));
				
			If AreasToDetermineNodeCodes.Count() > 0 Then
				
				OnStartGetCodesOfDataAreasNodes(HandlerParameters);
				
				If Not HandlerParameters.Cancel Then
					HandlerParameters.AdditionalParameters.Insert("WaitForSessionGetCorrespondentParameters");
					ContinueWait = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   CompletionStatus - Structure - operation execution result details.
//
Procedure OnCompleteGettingApplicationsList(HandlerParameters, CompletionStatus) Export
	
	InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		
		Try
			CompletionStatus.Result = DataSynchronizationApplicationsTable(HandlerParameters.AdditionalParameters);
		Except
			Information = ErrorInfo();
			
			CompletionStatus.Cancel = True;
			CompletionStatus.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
			
			WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationMonitor(),
				EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
		EndTry;
		
	EndIf;
	
	HandlerParameters = Undefined;
	
EndProcedure

#EndRegion

#Region GetCommonDataOfCorrespondentNodes

// Parameters:
//   ConnectionSettings - Structure - operation execution setting details.
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   ContinueWait - Boolean - True if a long-running operation is running.
//
Procedure OnStartGetCommonDataFromCorrespondentNodes(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	HandlerParameters = TimeConsumingOperationHandlerParameters();
	HandlerParameters.AdditionalParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExchangePlanName              = ConnectionSettings.ExchangePlanName;
	CorrespondentDataArea = ConnectionSettings.CorrespondentDataArea;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// Send a message to a peer infobase.
		Message = ModuleMessagesSaaS.NewMessage(
			DataExchangeMessagesManagementInterface.GetCommonDataOfCorrespondentNodeMessage());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		
		AdditionalProperties = New Structure;
		AdditionalProperties.Insert("Interface", "3.0.1.1");
		
		Message.AdditionalInfo = XDTOSerializer.WriteXDTO(AdditionalProperties);
		
		HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorMessage);
			
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorMessage;
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait = False;
		Return;
	EndTry;
	
	ModuleMessagesSaaS.DeliverQuickMessages();
	
EndProcedure

// For internal use.
//
Procedure OnWaitForGetCommonDataFromCorrespondentNodes(HandlerParameters, ContinueWait = True) Export
	
	OnWaitSystemMessagesExchangeSession(HandlerParameters, ContinueWait);
	
EndProcedure

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   CompletionStatus - Structure - operation execution result details.
//
Procedure OnCompleteGetCommonDataFromCorrespondentNodes(HandlerParameters, CompletionStatus) Export
	
	InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus);
	
	ConnectionSettings = HandlerParameters.AdditionalParameters.ConnectionSettings;
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		Result = New Structure;
		Result.Insert("CorrespondentParametersReceived", True);
		Result.Insert("CorrespondentParameters");
		Result.Insert("ErrorMessage", "");
		
		SetPrivilegedMode(True);
		
		Try
			// Peer infobase parameters.
			CorrespondentData = InformationRegisters.SystemMessageExchangeSessions.GetSessionData(
				HandlerParameters.OperationID).Get();
				
			If Not CorrespondentData.Property("InfoBaseAdmParams", Result.CorrespondentParameters) Then
				Result.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'DataExchange interface 3.0.1.1 is not supported.
					|To set up the connection, update %1 or start the setup from it.';"),
					ConnectionSettings.CorrespondentDescription);
				Result.CorrespondentParametersReceived = False;
			EndIf;
			
			CompletionStatus.Result = Result;
			
		Except
			CompletionStatus.Cancel = True;
			CompletionStatus.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
				EventLogLevel.Error, , , CompletionStatus.ErrorMessage);
			
			Return;
		EndTry;
	EndIf;
	
	HandlerParameters = Undefined;
	
EndProcedure

#EndRegion

#Region SaveConnectionSettings

// Parameters:
//   ConnectionSettings - Structure - operation execution setting details.
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   ContinueWait - Boolean - True if a long-running operation is running.
//
Procedure OnStartSaveConnectionSettings(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = BackgroundJobKey(ConnectionSettings.ExchangePlanName,
		NStr("en = 'Peer infobase connection setup';"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Connection to ""%1"" is being set up.';"), ConnectionSettings.ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Peer infobase ""%1"" connection setup';"), ConnectionSettings.ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataSynchronizationBetweenWebApplicationsSetupWizard.SetUpExchangeStep13011",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
	If Not ContinueWait
		And Not HandlerParameters.Cancel Then
		HandlerParameters.AdditionalParameters.Insert("BackgroundJobCompleted");
		ContinueWait = True;
	EndIf;
	
	HandlerParameters.AdditionalParameters.Insert("ConnectionSettings", ConnectionSettings);
	
EndProcedure

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   ContinueWait - Boolean - True if a long-running operation is not completed yet.
//
Procedure OnWaitForSaveConnectionSettings(HandlerParameters, ContinueWait = True) Export
	
	If HandlerParameters.AdditionalParameters.Property("WaitForMessageExchangeSessionInSystem1") Then
		
		OnWaitSystemMessagesExchangeSession(
			HandlerParameters.AdditionalParameters.SessionHandlerParameters, ContinueWait);
			
		If Not ContinueWait
			And Not HandlerParameters.AdditionalParameters.SessionHandlerParameters.Cancel Then
			HandlerParameters.AdditionalParameters.Insert("WaitForMessageExchangeSessionInSystem2");
			HandlerParameters.AdditionalParameters.Delete("WaitForMessageExchangeSessionInSystem1");
			
			OnStartSaveExchangeSettingInServiceManager(HandlerParameters.AdditionalParameters.ConnectionSettings,
				HandlerParameters.AdditionalParameters.SessionHandlerParameters, ContinueWait);
		EndIf;
			
	ElsIf HandlerParameters.AdditionalParameters.Property("WaitForMessageExchangeSessionInSystem2") Then
			
		OnWaitSystemMessagesExchangeSession(
			HandlerParameters.AdditionalParameters.SessionHandlerParameters, ContinueWait);
			
	Else
		
		JobCompleted = False;
		
		If HandlerParameters.AdditionalParameters.Property("BackgroundJobCompleted") Then
			JobCompleted = True;
		Else
			OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
			
			JobCompleted = Not ContinueWait And Not HandlerParameters.Cancel;
		EndIf;
		
		If JobCompleted Then
			
			Result = GetFromTempStorage(HandlerParameters.ResultAddress);
			
			SessionHandlerParameters = Result.SessionHandlerParameters;
			HandlerParameters.AdditionalParameters.Insert("Peer", Result.Peer);
			
			If SessionHandlerParameters.Cancel Then
				ContinueWait = False;
				HandlerParameters.Cancel = True;
				HandlerParameters.ErrorMessage = SessionHandlerParameters.ErrorMessage;
			Else
				ContinueWait = True;
				HandlerParameters.AdditionalParameters.Insert("WaitForMessageExchangeSessionInSystem1");
				HandlerParameters.AdditionalParameters.Insert("SessionHandlerParameters", SessionHandlerParameters);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//   CompletionStatus - Structure - operation execution result details.
//
Procedure OnCompleteConnectionSettingsSaving(HandlerParameters, CompletionStatus) Export
	
	InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		SessionHandlerParameters = HandlerParameters.AdditionalParameters.SessionHandlerParameters;
		
		Result = New Structure;
		Result.Insert("ConnectionSettingsSaved", True);
		Result.Insert("ExchangeNode",                    Undefined);
		Result.Insert("ErrorMessage",             "");
		
		If SessionHandlerParameters.Cancel Then
			// Deleting an exchange node in the current infobase.
			If ValueIsFilled(HandlerParameters.AdditionalParameters.Peer) Then
				DataExchangeServer.DeleteSynchronizationSetting(HandlerParameters.AdditionalParameters.Peer);
			EndIf;
			
			Result.ConnectionSettingsSaved = False;
			Result.ErrorMessage             = SessionHandlerParameters.ErrorMessage;
		Else
			Result.Insert("ExchangeNode", HandlerParameters.AdditionalParameters.Peer);
		EndIf;
		
		CompletionStatus.Result = Result;
		
	EndIf;
	
	HandlerParameters = Undefined;
	
EndProcedure

#EndRegion

#Region DeleteDataSynchronizationSetting

// For internal use.
//
Procedure OnStartDeleteSynchronizationSettings(DeletionSettings, HandlerParameters, ContinueWait) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	HandlerParameters = TimeConsumingOperationHandlerParameters();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// Sending a message to the service manager.
		Message = ModuleMessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.DisableSynchronizationMessage());
			
		Message.Body.CorrespondentZone = DeletionSettings.CorrespondentDataArea;
		Message.Body.ExchangePlan      = DeletionSettings.ExchangePlanName;
		
		HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Disable ""%1"" data synchronization with application ""%2"".';"),
			DeletionSettings.ExchangePlanName, XMLString(DeletionSettings.CorrespondentDataArea));
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Information, , , MessageText);
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorMessage);
		
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorMessage;
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait = False;
		Return;
	EndTry;
	
	ModuleMessagesSaaS.DeliverQuickMessages();
	ContinueWait = True;
	
EndProcedure

// For internal use.
//
Procedure OnWaitForDeleteSynchronizationSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitSystemMessagesExchangeSession(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteSynchronizationSettingsDeletion(HandlerParameters, CompletionStatus) Export
	
	InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		
		Result = New Structure;
		Result.Insert("SettingDeleted",                 True);
		Result.Insert("SettingDeletedInCorrespondent",  True);
		Result.Insert("ErrorMessage",                "");
		Result.Insert("ErrorMessageInCorrespondent", "");
		
		CompletionStatus.Result = Result;
		
	EndIf;
	
	HandlerParameters = Undefined;
	
EndProcedure

#EndRegion

#Region TransportChange

// For internal use.
//
Procedure OnStartDisconnectingFromSM(Settings, HandlerParameters, ContinueWait) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	HandlerParameters = TimeConsumingOperationHandlerParameters();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// 
		Message = ModuleMessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessageDisableSyncOverSM());
			
		Message.Body.CorrespondentZone = Settings.CorrespondentDataArea;
		Message.Body.ExchangePlan      = Settings.ExchangePlanName;
				
		HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Disable data synchronization using service manager (switch to a web service) ""%1"" with application ""%2"".';"),
			Settings.ExchangePlanName, XMLString(Settings.CorrespondentDataArea));
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Information, , , MessageText);
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorMessage);
		
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorMessage;
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait = False;
		Return;
	EndTry;
	
	ModuleMessagesSaaS.DeliverQuickMessages();
	ContinueWait = True;
	
EndProcedure

// For internal use.
//
Procedure OnWaitDisconnectingFromSM(HandlerParameters, ContinueWait) Export
	
	OnWaitSystemMessagesExchangeSession(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteDisconnectingFromSM(HandlerParameters, CompletionStatus) Export 
	
	InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		
		Result = New Structure;
		Result.Insert("IsTransportChanged",                 True);
		Result.Insert("IsTransportChangedInPeer",  True);
		Result.Insert("ErrorMessage",                "");
		Result.Insert("ErrorMessageInCorrespondent", "");
		
		CompletionStatus.Result = Result;
		
	EndIf;
	
	HandlerParameters = Undefined;
	
EndProcedure

#EndRegion


#EndRegion

#Region Private

#Region MessagesExchangeSessions

Procedure OnWaitSystemMessagesExchangeSession(HandlerParameters, ContinueWait)
	
	SessionStatus = "";
	Try
		SessionStatus = SessionStatus(HandlerParameters.OperationID);
	Except
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationMonitor(),
			EventLogLevel.Error, , , ErrorMessage);
			
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorMessage;
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait  = False;
		Return;
	EndTry;
	
	If SessionStatus = "Success" Then
		
		ContinueWait = False;
		
	ElsIf SessionStatus = "Error" Then
		
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = SessionErrorDetails(HandlerParameters.OperationID);
		HandlerParameters.OperationID = Undefined;
		ContinueWait  = False;
		
	Else
		
		ContinueWait = True;
		
	EndIf;
	
EndProcedure

Function SessionStatus(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionStatus(Session);
	
EndFunction

Function SessionErrorDetails(Val Session)
	
	SetPrivilegedMode(True);
	
	Return InformationRegisters.SystemMessageExchangeSessions.SessionErrorDetails(Session);
	
EndFunction 

#EndRegion

#Region TimeConsumingOperations1

// For internal use.
//
Procedure OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait = True)
	
	HandlerParameters = TimeConsumingOperationHandlerParameters(BackgroundJob);
	
	If BackgroundJob.Status = "Running" Then
		HandlerParameters.ResultAddress       = BackgroundJob.ResultAddress;
		HandlerParameters.OperationID = BackgroundJob.JobID;
		HandlerParameters.TimeConsumingOperation    = True;
		
		ContinueWait = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed2" Then
		HandlerParameters.ResultAddress    = BackgroundJob.ResultAddress;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	Else
		HandlerParameters.ErrorMessage = BackgroundJob.BriefErrorDescription;
		If ValueIsFilled(BackgroundJob.DetailErrorDescription) Then
			HandlerParameters.ErrorMessage = BackgroundJob.DetailErrorDescription;
		EndIf;
		
		HandlerParameters.Cancel = True;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait = True)
	
	If HandlerParameters.Cancel
		Or Not HandlerParameters.TimeConsumingOperation Then
		ContinueWait = False;
		Return;
	EndIf;
	
	JobCompleted = False;
	Try
		JobCompleted = TimeConsumingOperations.JobCompleted(HandlerParameters.OperationID);
	Except
		HandlerParameters.Cancel             = True;
		HandlerParameters.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , HandlerParameters.ErrorMessage);
	EndTry;
		
	If HandlerParameters.Cancel Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = Not JobCompleted;
	
EndProcedure

Function TimeConsumingOperationHandlerParameters(BackgroundJob = Undefined)
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("BackgroundJob",          BackgroundJob);
	HandlerParameters.Insert("Cancel",                   False);
	HandlerParameters.Insert("ErrorMessage",       "");
	HandlerParameters.Insert("TimeConsumingOperation",      False);
	HandlerParameters.Insert("OperationID",   Undefined);
	HandlerParameters.Insert("ResultAddress",         Undefined);
	HandlerParameters.Insert("AdditionalParameters", New Structure);
	
	Return HandlerParameters;
	
EndFunction

Function BackgroundJobKey(ExchangePlanName, Action)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'ExchangePlan:%1 Action:%2';"), ExchangePlanName, Action);
	
EndFunction

Function HasActiveBackgroundJobs(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key",      BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

Procedure InitializeCompletionStatusOfTimeConsumingOperation(CompletionStatus)
	
	CompletionStatus = New Structure;
	CompletionStatus.Insert("Cancel",             False);
	CompletionStatus.Insert("ErrorMessage", "");
	CompletionStatus.Insert("Result",         Undefined);

EndProcedure

#EndRegion

// Parameters:
//   HandlerParameters - Structure - secondary parameters:
//     * AdditionalParameters - Structure - arbitrary additional parameters.
//
Procedure OnStartGetCodesOfDataAreasNodes(HandlerParameters)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	AreasToDetermineNodeCodes = HandlerParameters.AdditionalParameters.AreasToDetermineNodeCodes.Get();
	
	SetPrivilegedMode(True);
	
	For Each Area In AreasToDetermineNodeCodes Do
		
		For Each NodesCodesString In Area.NodesCodes Do
			
			If Not NodesCodesString.ContinueWait Then
				Continue;
			EndIf;
			
			NodesCodesString.HandlerParameters = TimeConsumingOperationHandlerParameters();
		
			BeginTransaction();
			Try
				Message = ModuleMessagesSaaS.NewMessage(
					DataExchangeMessagesManagementInterface.GetCorrespondentAccountingParametersMessage());
					
				Message.Body.ExchangePlan      = Area.ExchangePlan;
				Message.Body.CorrespondentCode = NodesCodesString.ThisNodeCode;
				
				Message.Body.CorrespondentZone = Area.DataArea;
				
				AdditionalProperties = New Structure;
				AdditionalProperties.Insert("Interface", "3.0.1.1");
				
				Message.AdditionalInfo = XDTOSerializer.WriteXDTO(AdditionalProperties);
			
				NodesCodesString.HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
					
				CommitTransaction();
			Except
				RollbackTransaction();
				
				ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationMonitor(),
					EventLogLevel.Error, , , ErrorMessage);
					
				HandlerParameters.Cancel = True;
				HandlerParameters.ErrorMessage = ErrorMessage;
				HandlerParameters.OperationID = Undefined;
				
				Break;
			EndTry;
			
		EndDo;
		
		If HandlerParameters.Cancel Then
			Break;
		EndIf;
		
	EndDo;
	
	If Not HandlerParameters.Cancel Then
		ModuleMessagesSaaS.DeliverQuickMessages();
	EndIf;
	
	HandlerParameters.AdditionalParameters.AreasToDetermineNodeCodes =
		New ValueStorage(AreasToDetermineNodeCodes, New Deflation(9));
	
EndProcedure

Procedure OnStartSaveExchangeSettingInServiceManager(ConnectionSettings, HandlerParameters, ContinueWait)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
		
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	HandlerParameters = TimeConsumingOperationHandlerParameters();
	
	ExchangePlanName              = ConnectionSettings.ExchangePlanName;
	CorrespondentDataArea = ConnectionSettings.CorrespondentDataArea;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		// Sending a message to the service manager, enabling synchronization.
		Message = ModuleMessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.EnableSynchronizationMessage());
			
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		Message.Body.ExchangePlan = ExchangePlanName;
		
		HandlerParameters.OperationID = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		Information = ErrorInfo();
		
		WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
			
		HandlerParameters.Cancel = True;
		HandlerParameters.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
		HandlerParameters.OperationID = Undefined;
		
		ContinueWait = False;
		Return;
	EndTry;
	
	ModuleMessagesSaaS.DeliverQuickMessages();
	ContinueWait = True;
	
EndProcedure

Function DataSynchronizationApplicationsTable(Parameters)
	
	SynchronizationSettingsFromServiceManager = Parameters.SynchronizationSettingsFromServiceManager.Get();
	AreasToDetermineNodeCodes          = Parameters.AreasToDetermineNodeCodes.Get();
	
	HasExchangeAdministrationManage_3_0_1_1 = DataExchangeInternalPublication.HasInServiceExchangeAdministrationManage_3_0_1_1();
		
	ApplicationsTable = New ValueTable;
	ApplicationsTable.Columns.Add("ApplicationDescription", New TypeDescription("String"));
	ApplicationsTable.Columns.Add("Prefix",                New TypeDescription("String"));
	ApplicationsTable.Columns.Add("CorrespondentPrefix",  New TypeDescription("String"));
	ApplicationsTable.Columns.Add("CorrespondentVersion",   New TypeDescription("String"));
	ApplicationsTable.Columns.Add("CorrespondentRole",     New TypeDescription("String"));
	ApplicationsTable.Columns.Add("ExchangePlanName",         New TypeDescription("String"));
	ApplicationsTable.Columns.Add("ExchangeFormat",           New TypeDescription("String"));
	ApplicationsTable.Columns.Add("DataArea",          New TypeDescription("Number"));
	
	ApplicationsTable.Columns.Add("Endpoint", New TypeDescription("ExchangePlanRef.MessagesExchange"));
	ApplicationsTable.Columns.Add("CorrespondentEndpoint", New TypeDescription("ExchangePlanRef.MessagesExchange"));
	
	ApplicationsTable.Columns.Add("Peer");
	
	ApplicationsTable.Columns.Add("SyncSetupUnavailable", New TypeDescription("Boolean"));
	ApplicationsTable.Columns.Add("ErrorMessage",                New TypeDescription("String"));
	
	ApplicationsTable.Columns.Add("HasExchangeAdministrationManage_3_0_1_1",	New TypeDescription("Boolean"));
	
	If SynchronizationSettingsFromServiceManager.Count() = 0 Then
		Return ApplicationsTable;
	EndIf;
	
	ListOfProperties = "ApplicationDescription,
					|Prefix,
					|CorrespondentPrefix,
					|CorrespondentVersion,
					|CorrespondentRole,
					|ExchangeFormat,
					|DataArea";
	
	If HasExchangeAdministrationManage_3_0_1_1 Then
		ListOfProperties = ListOfProperties + ",HasExchangeAdministrationManage_3_0_1_1";
	EndIf;
	
	SetPrivilegedMode(True);
	
	For Each SettingFromServiceManager In SynchronizationSettingsFromServiceManager Do
		
		ApplicationRow = ApplicationsTable.Add();
		FillPropertyValues(ApplicationRow, SettingFromServiceManager, ListOfProperties);
		ApplicationRow.ExchangePlanName = SettingFromServiceManager.ExchangePlan;
		ApplicationRow.CorrespondentEndpoint = ExchangePlans["MessagesExchange"].FindByCode(
			SettingFromServiceManager.CorrespondentEndpoint);
			
		If HasExchangeAdministrationManage_3_0_1_1 Then
			ApplicationRow.Endpoint = ExchangePlans["MessagesExchange"].FindByCode(
				SettingFromServiceManager.Endpoint);	
		EndIf;
			
		If ApplicationRow.CorrespondentEndpoint.IsEmpty() Then
			ApplicationRow.SyncSetupUnavailable = True;
			ApplicationRow.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An endpoint with ID ""%2"" is not found for application ""%1"".';"),
				SettingFromServiceManager.ApplicationDescription,
				SettingFromServiceManager.CorrespondentEndpoint);
		ElsIf SettingFromServiceManager.SynchronizationSetupInServiceManager Then
			ApplicationRow.SyncSetupUnavailable = True;
			ApplicationRow.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Endpoint ""%1"" is temporarily unavailable.
				|Try again later.';"),
				ApplicationRow.CorrespondentEndpoint);
		Else
			Try
				TransportSettings = InformationRegisters.DataAreasExchangeTransportSettings.TransportSettings(
					ApplicationRow.CorrespondentEndpoint);
			Except
				Information = ErrorInfo();
				
				WriteLogEvent(DataExchangeSaaS.EventLogEventDataSynchronizationSetup(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
				
				ApplicationRow.SyncSetupUnavailable = True;
				ApplicationRow.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot get connection settings for application ""%1"" due to:
					|%2
					|';"),
					SettingFromServiceManager.ApplicationDescription,
					ErrorProcessing.BriefErrorDescription(Information));
			EndTry;
		EndIf;
			
		If Not ValueIsFilled(SettingFromServiceManager.PredefinedNodeCode)
			And SettingFromServiceManager.IsXDTOExchangePlan
			And SettingFromServiceManager.SynchronizationConfigured Then
			
			Filter = New Structure("DataArea, ExchangePlan");
			FillPropertyValues(Filter, SettingFromServiceManager);
			
			Areas = AreasToDetermineNodeCodes.FindRows(Filter);
			If Areas.Count() > 0 Then
				Area = Areas[0];
				
				For Each NodesCodesString In Area.NodesCodes Do
					If Not ValueIsFilled(NodesCodesString.PredefinedNodeCode) Then
						Continue;
					EndIf;
					
					SettingFromServiceManager.PredefinedNodeCode = NodesCodesString.PredefinedNodeCode;
					Break;
				EndDo;
			EndIf;
		EndIf;
			
		If ValueIsFilled(SettingFromServiceManager.PredefinedNodeCode) Then
			ApplicationRow.Peer = DataExchangeServer.ExchangePlanNodeByCode(ApplicationRow.ExchangePlanName,
				SettingFromServiceManager.PredefinedNodeCode);
		EndIf;
			
		If Not ValueIsFilled(ApplicationRow.Peer) Then
			NodeCodeSaaS = DataExchangeSaaS.ExchangePlanNodeCodeInService(ApplicationRow.DataArea);	
			ApplicationRow.Peer = DataExchangeServer.ExchangePlanNodeByCode(ApplicationRow.ExchangePlanName, NodeCodeSaaS);
		Else
			
			CorrespondentDataArea = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(ApplicationRow.Peer,
				"CorrespondentDataArea");
			
			If CorrespondentDataArea = Undefined Then
				InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(ApplicationRow.Peer,
					"CorrespondentDataArea", SettingFromServiceManager.DataArea);
			EndIf;
			
			If HasExchangeAdministrationManage_3_0_1_1 Then
				InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(ApplicationRow.Peer,
					"HasExchangeAdministrationManage_3_0_1_1", ApplicationRow.HasExchangeAdministrationManage_3_0_1_1);	
			EndIf;			
			
		EndIf;
		
		If Parameters.Mode = "NotConfiguredExchanges"
			And ValueIsFilled(ApplicationRow.Peer) Then
			ApplicationsTable.Delete(ApplicationRow);
		ElsIf Parameters.Mode = "ConfiguredExchanges"
			And Not ValueIsFilled(ApplicationRow.Peer) Then
			ApplicationsTable.Delete(ApplicationRow);
		EndIf;
				
	EndDo;
	
	Return ApplicationsTable;
	
EndFunction

Procedure DeleteUnnecessarySynchronizationSettingsRows(SynchronizationSettingsFromServiceManager, AdditionalParameters)
	
	SynchronizationSettingsFromServiceManager.Columns.Add("IsXDTOExchangePlan", New TypeDescription("Boolean"));
	SynchronizationSettingsFromServiceManager.Columns.Add("DeleteSettingItem",  New TypeDescription("Boolean"));
	
	SynchronizationSettingsFromServiceManager.Columns.Add("ExchangePlanNameToMigrateToNewExchange",
		New TypeDescription("String"));
	
	If SynchronizationSettingsFromServiceManager.Columns.Find("CorrespondentRole") = Undefined Then	
		SynchronizationSettingsFromServiceManager.Columns.Add("CorrespondentRole", New TypeDescription("String"));
	EndIf;
	
	HasCorrespondentVersion = SynchronizationSettingsFromServiceManager.Columns.Find("CorrespondentVersion") <> Undefined;
	
	For Each SettingFromServiceManager In SynchronizationSettingsFromServiceManager Do
		
		If Metadata.ExchangePlans.Find(SettingFromServiceManager.ExchangePlan) = Undefined Then
			SettingFromServiceManager.DeleteSettingItem = True;
			Continue;
		EndIf;
		
		ExchangePlanSettings = DataExchangeServer.ExchangePlanSettingValue(SettingFromServiceManager.ExchangePlan,
			"ExchangePlanNameToMigrateToNewExchange, IsXDTOExchangePlan");
		FillPropertyValues(SettingFromServiceManager, ExchangePlanSettings);
		
		If Not ValueIsFilled(SettingFromServiceManager.SynchronizationConfigured) Then
			SettingFromServiceManager.SynchronizationConfigured = False;
		EndIf;
		
	EndDo;
	
	If AdditionalParameters.Mode = "NotConfiguredExchanges" Then
		
		ConfiguredExchanges = SynchronizationSettingsFromServiceManager.Copy(New Structure("SynchronizationConfigured", True));
		
		For Each SettingFromServiceManager In SynchronizationSettingsFromServiceManager Do
			
			If SettingFromServiceManager.DeleteSettingItem Then
				Continue;
			EndIf;
			
			If Not SettingFromServiceManager.SynchronizationConfigured
				And ConfiguredExchanges.FindRows(New Structure("DataArea", SettingFromServiceManager.DataArea)).Count() > 0 Then
				SettingFromServiceManager.DeleteSettingItem = True;
				Continue;
			EndIf;
			
			SettingVariants = DataExchangeServer.CorrespondentExchangeSettingsOptions(
				SettingFromServiceManager.ExchangePlan,
				?(HasCorrespondentVersion, SettingFromServiceManager.CorrespondentVersion, ""),
				SettingFromServiceManager.CorrespondentRole);
				
			If SettingVariants.Find(AdditionalParameters.SettingID) = Undefined Then
				SettingFromServiceManager.DeleteSettingItem = True;
				Continue;
			EndIf;
			
			// 
			SettingFromServiceManager.DeleteSettingItem = Not SettingFromServiceManager.SynchronizationConfigured
				And ValueIsFilled(SettingFromServiceManager.ExchangePlanNameToMigrateToNewExchange);
			
		EndDo;
	EndIf;
	
	For Each SettingFromServiceManager In SynchronizationSettingsFromServiceManager.FindRows(New Structure("DeleteSettingItem", False)) Do
		
		If AdditionalParameters.Mode = "NotConfiguredExchanges" Then
			If SettingFromServiceManager.ExchangePlan <> AdditionalParameters.ExchangePlanName Then
				SettingFromServiceManager.DeleteSettingItem = True;
				Continue;
			EndIf;
		EndIf;
		
		If AdditionalParameters.Mode = "NotConfiguredExchanges"
			And SettingFromServiceManager.SynchronizationConfigured Then
			SettingFromServiceManager.DeleteSettingItem = True;
		ElsIf AdditionalParameters.Mode = "ConfiguredExchanges"
			And Not SettingFromServiceManager.SynchronizationConfigured Then
			SettingFromServiceManager.DeleteSettingItem = True;
		EndIf;
		
	EndDo;
	
	If SynchronizationSettingsFromServiceManager.Find(True, "DeleteSettingItem") <> Undefined Then
		SynchronizationSettingsFromServiceManager = SynchronizationSettingsFromServiceManager.Copy(
			New Structure("DeleteSettingItem", False));
	EndIf;

EndProcedure

#EndRegion

#EndIf
