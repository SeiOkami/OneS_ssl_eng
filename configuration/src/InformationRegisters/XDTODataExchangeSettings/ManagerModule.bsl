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

Procedure UpdateSettings2(InfobaseNode, SettingKind, SettingValue) Export
	
	UpdateRecord(InfobaseNode, "Settings", SettingKind, SettingValue);
	
EndProcedure

Procedure UpdateCorrespondentSettings(InfobaseNode, SettingKind, SettingValue) Export
	
	UpdateRecord(InfobaseNode, "CorrespondentSettings", SettingKind, SettingValue);
	
EndProcedure

Function SettingValue(InfobaseNode, SettingKind) Export
	
	Result = Undefined;
	
	ReadRecord(InfobaseNode, "Settings", SettingKind, Result);
	
	Return Result;
	
EndFunction

Function CorrespondentSettingValue(InfobaseNode, SettingKind) Export
	
	Result = Undefined;
	
	ReadRecord(InfobaseNode, "CorrespondentSettings", SettingKind, Result);
	
	Return Result;
	
EndFunction

#EndRegion
	
#Region Private

Procedure UpdateRecord(InfobaseNode, DimensionName, SettingKind, SettingValue)
	
	Manager = CreateRecordManager();
	Manager.InfobaseNode = InfobaseNode;
	
	Manager.Read();
	
	NewSettings1 = New Structure;
	
	If Manager.Selected() Then
		CurrentSettings = Manager[DimensionName].Get();
		
		If TypeOf(CurrentSettings) = Type("ValueTable") Then
			
			NewSettings1.Insert("SupportedObjects", CurrentSettings);
			
		ElsIf TypeOf(CurrentSettings) = Type("Structure") Then
			
			For Each SettingItem In CurrentSettings Do
				
				NewSettings1.Insert(SettingItem.Key, SettingItem.Value);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	NewSettings1.Insert(SettingKind, SettingValue);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert(DimensionName, New ValueStorage(NewSettings1, New Deflation(9)));
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
	
EndProcedure

Procedure ReadRecord(InfobaseNode, DimensionName, SettingKind, Result)
	
	Manager = CreateRecordManager();
	Manager.InfobaseNode = InfobaseNode;
	
	Manager.Read();
	
	SettingStructure = New Structure;
	
	If Manager.Selected() Then
		CurrentSettings = Manager[DimensionName].Get();
		
		If TypeOf(CurrentSettings) = Type("ValueTable") Then
			
			SettingStructure.Insert("SupportedObjects", CurrentSettings);
			
		ElsIf TypeOf(CurrentSettings) = Type("Structure") Then
			
			For Each SettingItem In CurrentSettings Do
				
				SettingStructure.Insert(SettingItem.Key, SettingItem.Value);
				
			EndDo;
			
		EndIf;
	EndIf;
	
	SettingStructure.Property(SettingKind, Result);
	
EndProcedure

#Region UpdateHandlers

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.XDTODataExchangeSettings";
	
	XTDOExchangePlans = New Array;
	For Each ExchangePlan In DataExchangeCached.SSLExchangePlans() Do
		If Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlan) Then
			Continue;
		EndIf;
		XTDOExchangePlans.Add(ExchangePlan);
	EndDo;
	
	If XTDOExchangePlans.Count() = 0 Then
		Return;
	EndIf;
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray1",                 XTDOExchangePlans);
	QueryOptions.Insert("AdditionalExchangePlanProperties", "");
	QueryOptions.Insert("ResultToTemporaryTable",       True);
	
	TempTablesManager = New TempTablesManager;
	
	ExchangeNodesQuery = New Query(DataExchangeServer.ExchangePlansForMonitorQueryText(QueryOptions, False));
	ExchangeNodesQuery.TempTablesManager = TempTablesManager;
	ExchangeNodesQuery.Execute();
	
	Query = New Query(
	"SELECT
	|	ConfigurationExchangePlans.InfobaseNode AS InfobaseNode
	|FROM
	|	ConfigurationExchangePlans AS ConfigurationExchangePlans
	|		LEFT JOIN InformationRegister.XDTODataExchangeSettings AS XDTODataExchangeSettings
	|		ON (XDTODataExchangeSettings.InfobaseNode = ConfigurationExchangePlans.InfobaseNode)
	|WHERE
	|	(XDTODataExchangeSettings.InfobaseNode IS NULL
	|			OR XDTODataExchangeSettings.CorrespondentExchangePlanName = """")");
	
	Query.TempTablesManager = TempTablesManager;
	
	Result = Query.Execute().Unload();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.XDTODataExchangeSettings;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	FilterPresentation   = NStr("en = 'InfobaseNode = %1';");
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		Try
			
			RefreshDataExchangeSettingsOfCorrespondentXDTO(Selection.InfobaseNode);
			Processed = Processed + 1;
			
		Except
			
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process a set of ""%1"" register records with filter %2 due to:
				|%3';"), RegisterPresentation, FilterPresentation, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion failed to process (skipped) some exchange node records: %1';"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The InformationRegisters.XDTODataExchangeSettings.ProcessDataForMigrationToNewVersion procedure processed records: %1';"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure RefreshDataExchangeSettingsOfCorrespondentXDTO(InfobaseNode) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.XDTODataExchangeSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		
		Block.Lock();
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.InfobaseNode.Set(InfobaseNode);
		
		RecordSet.Read();
		
		If RecordSet.Count() > 0 Then
			CurrentRecord = RecordSet[0];
		Else
			CurrentRecord = RecordSet.Add();
			CurrentRecord.InfobaseNode = InfobaseNode;
		EndIf;
		
		CurrentRecord.CorrespondentExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
		
		InfobaseUpdate.WriteRecordSet(RecordSet);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf