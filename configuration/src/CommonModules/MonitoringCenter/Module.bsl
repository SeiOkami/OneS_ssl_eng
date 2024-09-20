///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region Common

// Check the subsystem state.
// Returns:
//  Boolean - 
//
Function MonitoringCenterEnabled() Export
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParametersExternalCall(
		MonitoringCenterParameters);
	Return MonitoringCenterParameters.EnableMonitoringCenter
		Or MonitoringCenterParameters.ApplicationInformationProcessingCenter;
EndFunction

// Enables the MonitoringCenter subsystem.
//
Procedure EnableSubsystem() Export

	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters();

	MonitoringCenterParameters.EnableMonitoringCenter = True;
	MonitoringCenterParameters.ApplicationInformationProcessingCenter = False;

	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	SchedJob = MonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
	MonitoringCenterInternal.SetDefaultScheduleExternalCall(SchedJob);

EndProcedure

// Disables the MonitoringCenter subsystem.
//
Procedure DisableSubsystem() Export

	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters();

	MonitoringCenterParameters.EnableMonitoringCenter = False;
	MonitoringCenterParameters.ApplicationInformationProcessingCenter = False;

	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	MonitoringCenterInternal.DeleteScheduledJobExternalCall("StatisticsDataCollectionAndSending");

EndProcedure

// Returns a string presentation of infobase ID in the Monitoring center.
// Returns:
//  String - 
//
Function InfoBaseID() Export

	ParametersToGet = New Structure;
	ParametersToGet.Insert("EnableMonitoringCenter");
	ParametersToGet.Insert("ApplicationInformationProcessingCenter");
	ParametersToGet.Insert("DiscoveryPackageSent");
	ParametersToGet.Insert("LastPackageNumber");
	ParametersToGet.Insert("InfoBaseID");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);

	If (MonitoringCenterParameters.EnableMonitoringCenter
		Or MonitoringCenterParameters.ApplicationInformationProcessingCenter)
		And MonitoringCenterParameters.DiscoveryPackageSent Then
		Return String(MonitoringCenterParameters.InfoBaseID);
	EndIf;
	
	// 
	Return "";

EndFunction

#EndRegion

#Region BusinessStatistics

// Writes a business statistics operation.
//
// Parameters:
//  OperationName	- String	- a statistics operation name, if it is missing, a new one is created.
//  Value	- Number		- a quantitative value of the statistics operation.
//  Comment	- String	- an arbitrary comment.
//  Separator	- String	- a value separator in OperationName if separator is not a point.
//
Procedure WriteBusinessStatisticsOperation(OperationName, Value, Comment = Undefined, Separator = ".") Export
	If WriteBusinessStatisticsOperations() Then
		InformationRegisters.StatisticsOperationsClipboard.WriteBusinessStatisticsOperation(OperationName, Value, Comment,
			Separator);
	EndIf;
EndProcedure

// Writes a unique business statistics operation by hours.
// Uniqueness is checked upon writing.
//
// Parameters:
//  OperationName      - String - a statistics operation name, if it is missing, a new one is created.
//  UniqueKey - String - a key used to check whether a record is unique. Its maximum length is 100.
//  Value         - Number  - a quantitative value of the statistics operation.
//  Replace         - Boolean - determines a replacement mode of an existing record.
//                              True - an existing record will be deleted before writing.
//                              False - if a record already exists, new data is ignored.
//                              The default value is False.
//
Procedure WriteBusinessStatisticsOperationHour(OperationName, UniqueKey, Value, Replace = False) Export

	WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
	WriteParameters.OperationName = OperationName;
	WriteParameters.UniqueKey = UniqueKey;
	WriteParameters.Value = Value;
	WriteParameters.Replace = Replace;
	WriteParameters.EntryType = 1;
	WriteParameters.RecordPeriod = BegOfHour(CurrentUniversalDate());

	MonitoringCenterInternal.WriteBusinessStatisticsOperationInternal(WriteParameters);

EndProcedure

// Writes a unique business statistics operation by days.
// Uniqueness is checked upon writing.
//
// Parameters:
//  OperationName      - String - a statistics operation name, if it is missing, a new one is created.
//  UniqueKey - String - a key used to check whether a record is unique. Its maximum length is 100.
//  Value         - Number  - a quantitative value of the statistics operation.
//  Replace         - Boolean - determines a replacement mode of an existing record.
//                              True - an existing record will be deleted before writing.
//                              False - if a record already exists, new data is ignored.
//                              The default value is False.
//
Procedure WriteBusinessStatisticsOperationDay(OperationName, UniqueKey, Value, Replace = False) Export

	WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
	WriteParameters.OperationName = OperationName;
	WriteParameters.UniqueKey = UniqueKey;
	WriteParameters.Value = Value;
	WriteParameters.Replace = Replace;
	WriteParameters.EntryType = 2;
	WriteParameters.RecordPeriod = BegOfDay(CurrentUniversalDate());

	MonitoringCenterInternal.WriteBusinessStatisticsOperationInternal(WriteParameters);

EndProcedure


// Returns a business statistics registration status.
// Returns:
//  Boolean - 
//
Function WriteBusinessStatisticsOperations() Export
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter, RegisterBusinessStatistics");

	MonitoringCenterInternal.GetMonitoringCenterParameters(MonitoringCenterParameters);

	Return (MonitoringCenterParameters.EnableMonitoringCenter
		Or MonitoringCenterParameters.ApplicationInformationProcessingCenter)
		And MonitoringCenterParameters.RegisterBusinessStatistics;
EndFunction

#EndRegion

#Region ConfigurationStatistics

// Writes statistics by configuration objects.
//
// Parameters:
//  MetadataNamesMap - Structure:
//   * Key		- String - 	metadata object name.
//   * Value	- String - 	data selection query text, it must
//							contain the Quantity field. If Quantity is equal to zero,
//                          it is not recorded.
//
Procedure WriteConfigurationStatistics(MetadataNamesMap) Export
	Parameters = New Map;
	For Each CurMetadata In MetadataNamesMap Do
		Parameters.Insert(CurMetadata.Key, New Structure("Query, StatisticsOperations, StatisticsKind",
			CurMetadata.Value, , 0));
	EndDo;

	If Common.DataSeparationEnabled() And Common.SubsystemExists(
		"CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		DataAreaRow = Format(ModuleSaaSOperations.SessionSeparatorValue(), "NG=0");
	Else
		DataAreaRow = "0";
	EndIf;
	DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaRow);

	InformationRegisters.ConfigurationStatistics.Write(Parameters, DataAreaRef);
EndProcedure

// Writes statistics by a configuration object.
//
// Parameters:
//  ObjectName -	String	- a statistics operation name, if it is missing, a new one is created.
//  Value - 		Number	- a quantitative value of the statistics operation. If the value
//                            is equal to zero, it is not recorded.
//
Procedure WriteConfigurationObjectStatistics(ObjectName, Value) Export

	If Value <> 0 Then
		StatisticsOperation = MonitoringCenterCached.GetStatisticsOperationRef(ObjectName);

		If Common.DataSeparationEnabled() And Common.SubsystemExists(
			"CloudTechnology.Core") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			DataAreaRow = Format(ModuleSaaSOperations.SessionSeparatorValue(), "NG=0");
		Else
			DataAreaRow = "0";
		EndIf;
		DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaRow);

		RecordSet = InformationRegisters.ConfigurationStatistics.CreateRecordSet();
		RecordSet.Filter.StatisticsOperation.Set(StatisticsOperation);

		NewRecord1 = RecordSet.Add();
		NewRecord1.StatisticsAreaID = DataAreaRef;
		NewRecord1.StatisticsOperation = StatisticsOperation;
		NewRecord1.Value = Value;
		RecordSet.Write(True);
	EndIf;

EndProcedure

#EndRegion

#EndRegion