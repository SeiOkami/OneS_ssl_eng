///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers.

// Matches the GetExchangePlans web service operation
Function GetConfigurationExchangePlans()
	
	Return StrConcat(DataExchangeSaaSCached.DataSynchronizationExchangePlans(), ",");
EndFunction

// Matches the PrepareExchangeExecution web service operation
Function ScheduleDataExchangeExecution(AreasForDataExchangeString)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	AreasForDataExchange = ValueFromStringInternal(AreasForDataExchangeString);
	
	SetPrivilegedMode(True);
	
	For Each Item In AreasForDataExchange Do
		
		SeparatorValue = Item.Key;
		DataExchangeScenario = Item.Value;
		
		Parameters = New Array;
		Parameters.Add(DataExchangeScenario);
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName"    , "DataExchangeSaaS.ExecuteDataExchange");
		JobParameters.Insert("Parameters"    , Parameters);
		JobParameters.Insert("Key"         , "1");
		JobParameters.Insert("DataArea", SeparatorValue);
		
		Try
			ModuleJobsQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Description <> ModuleJobsQueue.GetDuplicateTaskExceptionTextWithSameKey() Then
				Raise;
			EndIf;
		EndTry;
		
	EndDo;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInFirstDataBase web service operation
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Var_Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfobaseNodeCode + ScenarioRow.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
	JobParameters.Insert("Parameters"    , Parameters);
	JobParameters.Insert("Key"         , Var_Key);
	JobParameters.Insert("DataArea", ScenarioRow.ValueOfSeparatorOfFirstInformationBase);
	
	Try
		SetPrivilegedMode(True);
		ModuleJobsQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Description <> ModuleJobsQueue.GetDuplicateTaskExceptionTextWithSameKey() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInSecondDataBase web service operation
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioString)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Var_Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfobaseNodeCode + ScenarioRow.ThisNodeCode;
	
	Parameters = New Array;
	Parameters.Add(ScenarioRowIndex);
	Parameters.Add(DataExchangeScenario);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
	JobParameters.Insert("Parameters"    , Parameters);
	JobParameters.Insert("Key"         , Var_Key);
	JobParameters.Insert("DataArea", ScenarioRow.ValueOfSeparatorOfSecondInformationBase);
	
	Try
		SetPrivilegedMode(True);
		ModuleJobsQueue.AddJob(JobParameters);
	Except
		If ErrorInfo().Description <> ModuleJobsQueue.GetDuplicateTaskExceptionTextWithSameKey() Then
			Raise;
		EndIf;
	EndTry;
	
	Return "";
	
EndFunction

// Matches the TestConnection web service operation
Function TestConnection(SettingsStructureString, TransportKindAsString, ErrorMessage)
	
	Cancel = False;
	
	// 
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorAttachment(Cancel,
			ValueFromStringInternal(SettingsStructureString),
			Enums.ExchangeMessagesTransportTypes[TransportKindAsString],
			ErrorMessage);
	
	If Cancel Then
		Return False;
	EndIf;
	
	// Checking the connection to the manager application through the web service
	Try
		DataExchangeSaaSCached.GetExchangeServiceWSProxy();
	Except
		ErrorMessage = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
EndFunction

#EndRegion
