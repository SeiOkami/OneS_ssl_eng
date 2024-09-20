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

Procedure WriteMeasurements(Measurements) Export
	If TypeOf(Measurements) = Type("QueryResult") Then
		WriteQueryResult(Measurements);
	EndIf;
EndProcedure

Procedure WriteQueryResult(Measurements)
	If Not Measurements.IsEmpty() Then
		RecordSet = CreateRecordSet();
		
		Selection = Measurements.Select();
		While Selection.Next() Do
			NewRecord1 = RecordSet.Add();
			NewRecord1.Period = Selection.Period;
			NewRecord1.StatisticsOperation = Selection.StatisticsOperation;
			NewRecord1.DeletionID = Selection.DeletionID;
			NewRecord1.ValuesCount = Selection.ValuesCount;
			NewRecord1.ValueSum = Selection.ValueSum;
			NewRecord1.PeriodEnd = Selection.PeriodEnd;
		EndDo;
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write(False);
	EndIf;
EndProcedure

Function GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod) Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200) AS Period,
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200 + &AggregationPeriod - 1) AS PeriodEnd,
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200) AS DeletionID,
	|	MeasurementsStatisticsOperations.StatisticsOperation,
	|	SUM(MeasurementsStatisticsOperations.ValuesCount) AS ValuesCount,
	|	SUM(MeasurementsStatisticsOperations.ValueSum) AS ValueSum
	|FROM
	|	InformationRegister.MeasurementsStatisticsOperations AS MeasurementsStatisticsOperations
	|WHERE
	|	MeasurementsStatisticsOperations.Period >= &AggregationBoundary
	|	AND MeasurementsStatisticsOperations.Period < &ProcessRecordsUntil
	|GROUP BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200),
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200 + &AggregationPeriod - 1),
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	MeasurementsStatisticsOperations.StatisticsOperation
	|";
	
	Query.SetParameter("AggregationBoundary", AggregationBoundary);
	Query.SetParameter("ProcessRecordsUntil", ProcessRecordsUntil);
	Query.SetParameter("AggregationPeriod", AggregationPeriod);
	Query.SetParameter("DeletionPeriod", DeletionPeriod);
	QueryResult = Query.Execute();
	
	Return QueryResult;
EndFunction

Procedure DeleteRecords(AggregationBoundary, ProcessRecordsUntil) Export
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	MeasurementsStatisticsOperations.DeletionID	
	|FROM
	|	InformationRegister.MeasurementsStatisticsOperations AS MeasurementsStatisticsOperations
	|WHERE
	|	MeasurementsStatisticsOperations.Period >= &AggregationBoundary
	|	AND MeasurementsStatisticsOperations.Period < &ProcessRecordsUntil
	|";
	
	Query.SetParameter("AggregationBoundary", AggregationBoundary);
	Query.SetParameter("ProcessRecordsUntil", ProcessRecordsUntil);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	RecordSet = CreateRecordSet();
	While Selection.Next() Do
		
		RecordSet.Filter.DeletionID.Set(Selection.DeletionID);
		RecordSet.Write(True);
	EndDo;
EndProcedure

Function GetMeasurements(StartDate, EndDate, DeletionPeriod) Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsOperations.Description AS StatisticsOperation,
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200) AS Period,
	|	SUM(MeasurementsStatisticsOperations.ValuesCount) AS ValuesCount,
	|	SUM(MeasurementsStatisticsOperations.ValueSum) AS ValueSum
	|FROM
	|	InformationRegister.MeasurementsStatisticsOperations AS MeasurementsStatisticsOperations
	|INNER JOIN
	|	InformationRegister.StatisticsOperations AS StatisticsOperations
	|ON
	|	MeasurementsStatisticsOperations.StatisticsOperation = StatisticsOperations.OperationID
	|WHERE
	|	MeasurementsStatisticsOperations.Period >= &StartDate
	|	AND MeasurementsStatisticsOperations.PeriodEnd <= &EndDate	
	|GROUP BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	StatisticsOperations.Description
	|ORDER BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsOperations.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	StatisticsOperations.Description
	|";
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("DeletionPeriod", DeletionPeriod);
	
	QueryResult = Query.Execute();
	
	Return QueryResult;	
EndFunction

#EndRegion

#EndIf
