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

// Matches the GetExchangeFeatures web service operation
Function GetConfigurationExchangePlans()
	
	Result = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/SaaS/ExchangeAdministration/Common", "ExchangeFeatures"));
	ExchangeFeatureType = XDTOFactory.Type("http://www.1c.ru/SaaS/ExchangeAdministration/Common", "ExchangeFeature");
	
	For Each ExchangePlanName In DataExchangeSaaSCached.DataSynchronizationExchangePlans() Do
		
		ExchangeFeature = XDTOFactory.Create(ExchangeFeatureType);
		ExchangeFeature.ExchangePlan = ExchangePlanName;
		
		ExchangeFeature.ExchangeRole = TrimAll(DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "SourceConfigurationName"));
		
		If IsBlankString(ExchangeFeature.ExchangeRole) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The SourceConfigurationName property value is not specified in the OnGetSettings()
				| procedure of the module of the exchange plan manager%1.';"),
				ExchangePlanName);
		EndIf;
		
		Result.Feature.Add(ExchangeFeature);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Matches the PrepareExchangeExecution web service operation
Function ScheduleDataExchangeExecution(DataExchangeAreasXDTO)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	AreasForDataExchange = XDTOSerializer.ReadXDTO(DataExchangeAreasXDTO);
	
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
Function ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Var_Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfobaseNodeCode + ScenarioRow.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		
		SetPrivilegedMode(True);
		ModuleSaaSOperations.SetSessionSeparation(True, ScenarioRow.ValueOfSeparatorOfFirstInformationBase);
		SetPrivilegedMode(False);
		
		ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
			"DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase",
			Parameters,
			Var_Key);
			
		SetPrivilegedMode(True);
		ModuleSaaSOperations.SetSessionSeparation(False);
		SetPrivilegedMode(False);
		
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioRow.ValueOfSeparatorOfFirstInformationBase);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", Var_Key);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			ModuleJobsQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Description <> ModuleJobsQueue.GetDuplicateTaskExceptionTextWithSameKey() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown data exchange mode: %1';"), String(ExchangeMode));
	EndIf;
	
	Return "";
EndFunction

// Matches the StartExchangeExecutionInSecondDataBase web service operation
Function ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenarioXDTO)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return "";
	EndIf;
		
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	Var_Key = ScenarioRow.ExchangePlanName + ScenarioRow.InfobaseNodeCode + ScenarioRow.ThisNodeCode;
	
	ExchangeMode = DataExchangeMode(DataExchangeScenario);
	
	If ExchangeMode = "Manual" Then
		
		Parameters = New Array;
		Parameters.Add(ScenarioRowIndex);
		Parameters.Add(DataExchangeScenario);
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		
		SetPrivilegedMode(True);
		ModuleSaaSOperations.SetSessionSeparation(True, ScenarioRow.ValueOfSeparatorOfSecondInformationBase);
		SetPrivilegedMode(False);
		
		ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
			"DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase",
			Parameters,
			Var_Key);
			
		SetPrivilegedMode(True);
		ModuleSaaSOperations.SetSessionSeparation(False);
		SetPrivilegedMode(False);
		
	ElsIf ExchangeMode = "Automatic" Then
		
		Try
			Parameters = New Array;
			Parameters.Add(ScenarioRowIndex);
			Parameters.Add(DataExchangeScenario);
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", ScenarioRow.ValueOfSeparatorOfSecondInformationBase);
			JobParameters.Insert("MethodName", "DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
			JobParameters.Insert("Parameters", Parameters);
			JobParameters.Insert("Key", Var_Key);
			JobParameters.Insert("Use", True);
			
			SetPrivilegedMode(True);
			ModuleJobsQueue.AddJob(JobParameters);
		Except
			If ErrorInfo().Description <> ModuleJobsQueue.GetDuplicateTaskExceptionTextWithSameKey() Then
				Raise;
			EndIf;
		EndTry;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown data exchange mode: %1';"), String(ExchangeMode));
	EndIf;
	
	Return "";
EndFunction

// Matches the TestConnection web service operation
Function TestConnection(SettingsStructureXTDO, TransportKindAsString, ErrorMessage)
	
	Cancel = False;
	
	// 
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorAttachment(Cancel,
			XDTOSerializer.ReadXDTO(SettingsStructureXTDO),
			Enums.ExchangeMessagesTransportTypes[TransportKindAsString],
			ErrorMessage);
	
	If Cancel Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

// Matches the Ping web service operation
Function Ping()
	
	Return "";
	
EndFunction

//

Function DataExchangeMode(DataExchangeScenario)
	
	Result = "Manual";
	
	If DataExchangeScenario.Columns.Find("Mode") <> Undefined Then
		Result = DataExchangeScenario[0].Mode;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
