///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function IsRecord(RecordPeriod, EntryType, Var_Key, StatisticsOperation)
    
    Query = New Query;
    
    Query.Text = "
    |SELECT TOP 1
    |   TRUE
    |FROM
    |   InformationRegister.StatisticsMeasurements
    |WHERE
    |   RecordPeriod = &RecordPeriod
    |   AND EntryType = &EntryType
    |   AND Key = &Key
    |   AND StatisticsOperation = &StatisticsOperation
    |";
    
    Query.SetParameter("RecordPeriod", RecordPeriod);
    Query.SetParameter("EntryType", EntryType);
    Query.SetParameter("Key", Var_Key);
    Query.SetParameter("StatisticsOperation", StatisticsOperation);
    
    
    SetPrivilegedMode(True);
    Result = Query.Execute();
    SetPrivilegedMode(False);
    
    Return Not Result.IsEmpty();    
    
EndFunction

Procedure WriteBusinessStatisticsOperation(RecordPeriod, EntryType, Var_Key, StatisticsOperation, OperationValue, Replace) Export
    
    IsRecord = IsRecord(RecordPeriod, EntryType, Var_Key, StatisticsOperation);
    
    If Not IsRecord Or Replace Then
        
        BeginTransaction();
        Try
            
            Block = New DataLock;
            
            LockItemRecordPeriod = Block.Add("InformationRegister.StatisticsMeasurements");
		    LockItemRecordPeriod.SetValue("RecordPeriod", RecordPeriod);            
            LockItemRecordPeriod.SetValue("EntryType", EntryType);                  
            LockItemRecordPeriod.SetValue("Key", Var_Key);                            
            LockItemRecordPeriod.SetValue("StatisticsOperation", StatisticsOperation);
                           
		    Block.Lock();
            
            IsRecord = IsRecord(RecordPeriod, EntryType, Var_Key, StatisticsOperation);
            
            If Not IsRecord Or Replace Then
                
                RecordManager = CreateRecordManager();
                RecordManager.RecordPeriod = RecordPeriod;
                RecordManager.Key = Var_Key;
                RecordManager.EntryType = EntryType;
                RecordManager.StatisticsOperation = StatisticsOperation;
                RecordManager.DeletionID = BegOfDay(RecordPeriod);
                RecordManager.OperationValue = OperationValue;
                
                SetPrivilegedMode(True);
                If IsRecord And Replace Then
                    RecordManager.Write(True);
                Else
                    RecordManager.Write(False);
                EndIf;
                SetPrivilegedMode(False);
                
            EndIf;
            CommitTransaction();
        Except
            RollbackTransaction();
        EndTry;
        
    EndIf;
         
EndProcedure

Function GetHourMeasurements(StartDate, EndDate) Export
    
    Return GetMeasurementsByType(StartDate, EndDate, 1);
        
EndFunction

Function GetDayMeasurements(StartDate, EndDate) Export
    
    Return GetMeasurementsByType(StartDate, EndDate, 2);
        
EndFunction

Function GetMeasurementsByType(StartDate, EndDate, EntryType)
    
    Query = New Query;
    Query.Text = "
    |SELECT
    |   StatisticsOperations.Description AS StatisticsOperation,
    |   MeasurementsStatisticsOperations.RecordPeriod AS Period,
    |   COUNT(*) AS ValuesCount,
    |   SUM(MeasurementsStatisticsOperations.OperationValue) AS ValueSum
    |FROM
    |   InformationRegister.StatisticsMeasurements AS MeasurementsStatisticsOperations
    |INNER JOIN
    |   InformationRegister.StatisticsOperations AS StatisticsOperations
	|ON
	|	MeasurementsStatisticsOperations.StatisticsOperation = StatisticsOperations.OperationID
    |WHERE
    |   MeasurementsStatisticsOperations.EntryType = &EntryType
    |   AND MeasurementsStatisticsOperations.RecordPeriod BETWEEN &StartDate AND &EndDate
    |GROUP BY
    |   StatisticsOperations.Description,
    |   MeasurementsStatisticsOperations.RecordPeriod
    |";
    
    Query.SetParameter("StartDate", StartDate);
    Query.SetParameter("EndDate", EndDate);
    Query.SetParameter("EntryType", EntryType);
    
    Result = Query.Execute();
    
    Return Result;
    
EndFunction

Procedure DeleteRecords(AggregationBoundary, ProcessRecordsUntil) Export
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	               |	StatisticsMeasurements.RecordPeriod AS RecordPeriod
	               |FROM
	               |	InformationRegister.StatisticsMeasurements AS StatisticsMeasurements
	               |WHERE
	               |	StatisticsMeasurements.RecordPeriod >= &AggregationBoundary
	               |	AND StatisticsMeasurements.RecordPeriod < &ProcessRecordsUntil
	               |
	               |ORDER BY
	               |	StatisticsMeasurements.RecordPeriod";
	
	Query.SetParameter("AggregationBoundary", AggregationBoundary);
	Query.SetParameter("ProcessRecordsUntil", ProcessRecordsUntil);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	RecordSet = CreateRecordSet();
	While Selection.Next() Do
		RecordSet.Filter.RecordPeriod.Set(Selection.RecordPeriod);
		RecordSet.Write(True);
	EndDo;
EndProcedure

#EndRegion

#EndIf
