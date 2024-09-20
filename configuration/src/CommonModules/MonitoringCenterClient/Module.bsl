///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region PublicBusinessStatistics

// 
// 
// 
// 
//
// Parameters:
//  OperationName	- String	- a statistics operation name, if it is missing, a new one is created.
//  Value	- Number		- a quantitative value of the statistics operation.
//
Procedure WriteBusinessStatisticsOperation(OperationName, Value) Export
    
    If RegisterBusinessStatistics() Then 
        WriteParameters = New Structure("OperationName,Value, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.Value = Value;
        WriteParameters.EntryType = 0;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

// 
// 
// 
// 
// 
//
// Parameters:
//  OperationName      - String - a statistics operation name, if it is missing, a new one is created.
//  Value         - Number  - a quantitative value of the statistics operation.
//  Replace         - Boolean - determines a replacement mode of an existing record.
//                              True - an existing record will be deleted before writing.
//                              False - if a record already exists, new data is ignored.
//                              The default value is False.
//  UniqueKey - String - a key used to check whether a record is unique. Its maximum length is 100. If it is not set,
//                              the MD5 hash of user UUID and session number is used.
//                              The default value is Undefined.
//
Procedure WriteBusinessStatisticsOperationHour(OperationName, Value, Replace = False, UniqueKey = Undefined) Export
    
    If RegisterBusinessStatistics() Then
        WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.UniqueKey = UniqueKey;
        WriteParameters.Value = Value;
        WriteParameters.Replace = Replace;
        WriteParameters.EntryType = 1;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

// 
// 
// 
// 
// 
//
// Parameters:
//  OperationName      - String - a statistics operation name, if it is missing, a new one is created.
//  Value         - Number  - a quantitative value of the statistics operation.
//  Replace         - Boolean - determines a replacement mode of an existing record.
//                              True - an existing record will be deleted before writing.
//                              False - if a record already exists, new data is ignored.
//                              The default value is False.
//  UniqueKey - String - a key used to check whether a record is unique. Its maximum length is 100. If it is not set,
//                              the MD5 hash of user UUID and session number is used.
//                              The default value is Undefined.
//
Procedure WriteBusinessStatisticsOperationDay(OperationName, Value, Replace = False, UniqueKey = Undefined) Export
    
    If RegisterBusinessStatistics() Then
        WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.UniqueKey = UniqueKey;
        WriteParameters.Value = Value;
        WriteParameters.Replace = Replace;
        WriteParameters.EntryType = 2;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

#EndRegion

#EndRegion

#Region Internal

Procedure ShowMonitoringCenterSettings(OwnerForm, FormParameters) Export
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.MonitoringCenterSettings",
		FormParameters, OwnerForm,,,,, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

Procedure ShowSendSettingOfContactInfo(OwnerForm) Export
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.SendContactInformation",,
		OwnerForm,,,,, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion

#Region Private

Procedure WriteBusinessStatisticsOperationInternal(WriteParameters)
    
    MonitoringCenterApplicationParameters = MonitoringCenterClientInternal.GetApplicationParameters();
    Measurements = MonitoringCenterApplicationParameters["Measurements"][WriteParameters.EntryType];
    
    Measurement = New Structure("EntryType, Key, StatisticsOperation, Value, Replace");
    Measurement.EntryType = WriteParameters.EntryType;
    Measurement.StatisticsOperation = WriteParameters.OperationName;
    Measurement.Value = WriteParameters.Value;
    
    If Measurement.EntryType = 0 Then
        
        Measurements.Add(Measurement);
        
    Else
        
        If WriteParameters.UniqueKey = Undefined Then
            Measurement.Key = MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters"]["UserHash"];
        Else
            Measurement.Key = WriteParameters.UniqueKey;
        EndIf;
        
        Measurement.Replace = WriteParameters.Replace;
        
        If Not (Measurements[Measurement.Key] <> Undefined And Not Measurement.Replace) Then
            Measurements.Insert(Measurement.Key, Measurement);
        EndIf;
        
    EndIf;
        
EndProcedure

Function RegisterBusinessStatistics()
    
    ParameterName = "StandardSubsystems.MonitoringCenter";
    
    If ApplicationParameters[ParameterName] = Undefined Then
        ApplicationParameters.Insert(ParameterName, MonitoringCenterClientInternal.GetApplicationParameters());
    EndIf;
        
    Return ApplicationParameters[ParameterName]["RegisterBusinessStatistics"];
    
EndFunction

Procedure AfterUpdateID(Result, AdditionalParameters) Export	
	If Result <> Undefined Then
		Notify("IDUpdateMonitoringCenter", Result);
	EndIf;	
EndProcedure

#EndRegion