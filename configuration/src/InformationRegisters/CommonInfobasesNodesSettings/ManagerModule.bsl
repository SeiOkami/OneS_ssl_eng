///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// 
// 
// 
// 

#Region Internal

Procedure UpdatePrefixes(ExchangeNode, Prefix = "", CorrespondentPrefix = "") Export
	
	HasPrefix = False;
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	
	If ValueIsFilled(Prefix) Then
		RecordStructure.Insert("Prefix", Prefix);
		HasPrefix = True;
	EndIf;
	
	If ValueIsFilled(CorrespondentPrefix) Then
		RecordStructure.Insert("CorrespondentPrefix", CorrespondentPrefix);
		HasPrefix = True;
	EndIf;
	
	If HasPrefix Then
		UpdateRecord(RecordStructure);
	EndIf;
	
EndProcedure

Procedure SetNameOfCorrespondentExchangePlan(ExchangeNode, CorrespondentExchangePlanName) Export

	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	RecordStructure.Insert("CorrespondentExchangePlanName", CorrespondentExchangePlanName);

	UpdateRecord(RecordStructure);
	
EndProcedure

#EndRegion

#Region Private

Procedure SetInitialDataExportFlag(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("InitialDataExport", True);
	RecordStructure.Insert("SentNumberInitialDataExport",
		Common.ObjectAttributeValue(InfobaseNode, "SentNo") + 1);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearInitialDataExportFlag(Val InfobaseNode, Val ReceivedNo) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.CommonInfobasesNodesSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		Block.Lock();
		
		QueryText = "
		|SELECT 1
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
		|WHERE
		|	CommonInfobasesNodesSettings.InfobaseNode = &InfobaseNode
		|	AND CommonInfobasesNodesSettings.InitialDataExport
		|	AND CommonInfobasesNodesSettings.SentNumberInitialDataExport <= &ReceivedNo
		|	AND CommonInfobasesNodesSettings.SentNumberInitialDataExport <> 0
		|";
		
		Query = New Query;
		Query.SetParameter("InfobaseNode", InfobaseNode);
		Query.SetParameter("ReceivedNo", ReceivedNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			RecordStructure.Insert("InitialDataExport", False);
			RecordStructure.Insert("SentNumberInitialDataExport", 0);
			
			UpdateRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function InitialDataExportFlagIsSet(Val InfobaseNode) Export
	
	QueryText =
	"SELECT
	|	1 AS Field1
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobasesNodesSettings.InitialDataExport";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure CommitMappingInfoAdjustmentUnconditionally(InfobaseNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("AdjustMappingData", False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure CommitMappingInfoAdjustment(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobasesNodesSettings.AdjustMappingData
	|	AND CommonInfobasesNodesSettings.SentNo <= &SentNo
	|	AND CommonInfobasesNodesSettings.SentNo <> 0
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("SentNo", SentNo);
	Query.Text = QueryText;
	
	If Not Query.Execute().IsEmpty() Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("AdjustMappingData", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function MustAdjustMappingInfo(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	  CommonInfobasesNodesSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobasesNodesSettings.AdjustMappingData
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Not Query.Execute().IsEmpty();
	
	If Result Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("AdjustMappingData", True);
		RecordStructure.Insert("SentNo", SentNo);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
	Return Result;
EndFunction

Procedure SetDataSendingFlag(Val Recipient) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", Recipient);
	RecordStructure.Insert("ExecuteDataSending", True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearDataSendingFlag(Val Recipient) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If ExecuteDataSending(Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("ExecuteDataSending", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function ExecuteDataSending(Val Recipient) Export
	
	SetPrivilegedMode(True);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return False;
	EndIf;
	
	QueryText =
	"SELECT
	|	CommonInfobasesNodesSettings.ExecuteDataSending AS ExecuteDataSending
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &Recipient";
	
	Query = New Query;
	Query.SetParameter("Recipient", Recipient);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.ExecuteDataSending = True;
	
EndFunction

Procedure SetCorrespondentVersion(Val Peer, Val Version) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If IsBlankString(Version) Then
		Version = "0.0.0.0";
	EndIf;
	
	If CorrespondentVersion(Peer) <> TrimAll(Version) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Peer);
		RecordStructure.Insert("CorrespondentVersion", TrimAll(Version));
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function CorrespondentVersion(Val Peer) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return "0.0.0.0";
	EndIf;
	
	QueryText =
	"SELECT
	|	CommonInfobasesNodesSettings.CorrespondentVersion AS CorrespondentVersion
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &Peer";
	
	Query = New Query;
	Query.SetParameter("Peer", Peer);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return "0.0.0.0";
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Result = TrimAll(Selection.CorrespondentVersion);
	
	If IsBlankString(Result) Then
		Result = "0.0.0.0";
	EndIf;
	
	Return Result;
EndFunction

Procedure SetFlagSettingCompleted(ExchangeNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	RecordStructure.Insert("SettingCompleted",     True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Function SettingCompleted(ExchangeNode) Export
	
	Result = False;
	
	Query = New Query(
	"SELECT
	|	CommonInfobasesNodesSettings.SettingCompleted AS SettingCompleted
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &ExchangeNode");
	Query.SetParameter("ExchangeNode", ExchangeNode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.SettingCompleted;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure SetFlagInitialImageCreated(ExchangeNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	RecordStructure.Insert("InitialImageCreated",   True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Function InitialImageCreated(ExchangeNode) Export
	
	Query = New Query(
	"SELECT
	|	TRUE AS InitialImageCreated
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &ExchangeNode
	|	AND CommonInfobasesNodesSettings.InitialImageCreated");
	Query.SetParameter("ExchangeNode", ExchangeNode);
	
	Selection = Query.Execute().Select();
	
	Return Selection.Next();
	
EndFunction

Function NodePrefixes(ExchangeNode) Export
	
	Result = New Structure;
	Result.Insert("Prefix", "");
	Result.Insert("CorrespondentPrefix", "");
	
	Query = New Query(
	"SELECT
	|	CommonInfobasesNodesSettings.Prefix AS Prefix,
	|	CommonInfobasesNodesSettings.CorrespondentPrefix AS CorrespondentPrefix
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|WHERE
	|	CommonInfobasesNodesSettings.InfobaseNode = &InfobaseNode");
	Query.SetParameter("InfobaseNode", ExchangeNode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure PutMessageForDataMapping(ExchangeNode, MessageID) Export
	
	SetPrivilegedMode(True);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode",          ExchangeNode);
	RecordStructure.Insert("MessageForDataMapping", MessageID);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure SetLoop(ExchangeNode, IsLoopDetected = "", ExchangeDataRegistrationOnLoop = "") Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	
	If ValueIsFilled(IsLoopDetected) Then
		RecordStructure.Insert("IsLoopDetected", IsLoopDetected);
	EndIf;
	
	If ValueIsFilled(ExchangeDataRegistrationOnLoop) Then
		RecordStructure.Insert("ExchangeDataRegistrationOnLoop", ExchangeDataRegistrationOnLoop);
	EndIf;
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Function RegistrationWhileLooping(ExchangeNode) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Settings.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS Settings
		|WHERE
		|	Settings.InfobaseNode = &ExchangeNode
		|	AND (NOT Settings.IsLoopDetected
		|			OR Settings.ExchangeDataRegistrationOnLoop)";
	
	Query.SetParameter("ExchangeNode", ExchangeNode);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

Function CorrespondentExchangePlanName (ExchangeNode) Export

	Result = "";
	
	Query = New Query(
		"SELECT
		|	CommonInfobasesNodesSettings.CorrespondentExchangePlanName AS CorrespondentExchangePlanName
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
		|WHERE
		|	CommonInfobasesNodesSettings.InfobaseNode = &ExchangeNode");
	
	Query.SetParameter("ExchangeNode", ExchangeNode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.CorrespondentExchangePlanName;
	EndIf;
	
	Return Result;
		
EndFunction

// Updates a register record by the passed structure values.
//
Procedure UpdateRecord(RecordStructure)
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");
	
EndProcedure

#Region UpdateHandlers

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.CommonInfobasesNodesSettings";
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray1",                 New Array);
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
	|		LEFT JOIN InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|		ON (CommonInfobasesNodesSettings.InfobaseNode = ConfigurationExchangePlans.InfobaseNode)
	|WHERE
	|	ConfigurationExchangePlans.InfobaseNode <> UNDEFINED
	|	AND (CommonInfobasesNodesSettings.InfobaseNode IS NULL
	|			OR NOT CommonInfobasesNodesSettings.SettingCompleted
	|				AND CommonInfobasesNodesSettings.Prefix = """"
	|				AND CommonInfobasesNodesSettings.CorrespondentPrefix = """")");
	
	Query.TempTablesManager = TempTablesManager;
	
	Result = Query.Execute().Unload();
	
	SupplementTableWithProcessedDIBNodes(Result);
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure SupplementTableWithProcessedDIBNodes(NodesTables)
	
	Query = New Query;
	
	HasDIBExchangePlans = False;
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		If Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName) Then
			Continue;
		EndIf;
		HasDIBExchangePlans = True;
		
		QueryText = 
		"SELECT
		|	ExchangePlanTable.Ref AS InfobaseNode,
		|	ExchangePlanTable.Code AS NodeCode,
		|	CommonInfobasesNodesSettings.CorrespondentPrefix AS CorrespondentPrefix
		|FROM
		|	#ExchangePlanTable AS ExchangePlanTable
		|		INNER JOIN InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
		|		ON (CommonInfobasesNodesSettings.InfobaseNode = ExchangePlanTable.Ref)
		|WHERE
		|	NOT ExchangePlanTable.ThisNode
		|	AND CommonInfobasesNodesSettings.SettingCompleted
		|	AND CommonInfobasesNodesSettings.InitialImageCreated
		|	AND CommonInfobasesNodesSettings.CorrespondentPrefix = """"";
		
		QueryText = StrReplace(QueryText, "#ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		If Not IsBlankString(Query.Text) Then
			Query.Text = Query.Text + "
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		Query.Text = Query.Text + QueryText;
		
	EndDo;
	
	If Not HasDIBExchangePlans Then
		Return;
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NodeCode = TrimAll(Selection.NodeCode);
		
		If NodeCode <> Selection.NodeCode
			And StrLen(NodeCode) = 2
			And IsBlankString(Selection.CorrespondentPrefix) Then
			
			NodesString = NodesTables.Add();
			NodesString.InfobaseNode = Selection.InfobaseNode;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.CommonInfobasesNodesSettings;
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
			
			UpdateCorrespondentCommonSettings(Selection.InfobaseNode);
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
			NStr("en = 'Procedure InformationRegisters.CommonInfobasesNodesSettings.ProcessDataForMigrationToNewVersion failed to process (skipped) some exchange node records: %1';"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The InformationRegisters.CommonInfobasesNodesSettings.ProcessDataForMigrationToNewVersion procedure processed records: %1';"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure UpdateCorrespondentCommonSettings(InfobaseNode) Export
	
	If Not ValueIsFilled(InfobaseNode) Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.InfobaseNode.Set(InfobaseNode);
		
		InfobaseUpdate.MarkProcessingCompletion(RecordSet);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.CommonInfobasesNodesSettings");
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
		
		SettingCompletedBeforeChange = CurrentRecord.SettingCompleted;
		
		CurrentRecord.SettingCompleted = True;
		
		If DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode)
			And Not InfobaseNode = ExchangePlans.MasterNode() Then
			CurrentRecord.InitialImageCreated = True;
		EndIf;
		
		If DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode)
			And SettingCompletedBeforeChange Then
			ThisNodeCode = Common.ObjectAttributeValue(DataExchangeCached.GetThisExchangePlanNode(
				DataExchangeCached.GetExchangePlanName(InfobaseNode)), "Code");
			If ThisNodeCode <> TrimAll(ThisNodeCode) Then
				CurrentRecord.Prefix = "";
			EndIf;
		EndIf;
		
		If IsBlankString(CurrentRecord.CorrespondentPrefix) Then
			NodeCode = TrimAll(Common.ObjectAttributeValue(InfobaseNode, "Code"));
			If StrLen(NodeCode) = 2 Then
				CurrentRecord.CorrespondentPrefix = NodeCode;
			EndIf;
		EndIf;
			
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