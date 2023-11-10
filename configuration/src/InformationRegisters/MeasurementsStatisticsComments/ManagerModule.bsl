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
		ZeroID = CommonClientServer.BlankUUID();
		
		RecordSet = CreateRecordSet();
		
		Selection = Measurements.Select();
		While Selection.Next() Do
			If Selection.StatisticsComment <> ZeroID Then
				NewRecord1 = RecordSet.Add();
				NewRecord1.Period = Selection.Period;
				NewRecord1.StatisticsOperation = Selection.StatisticsOperation;
				NewRecord1.StatisticsComment = Selection.StatisticsComment;
				NewRecord1.DeletionID = Selection.DeletionID;
				NewRecord1.ValuesCount = Selection.ValuesCount;
				NewRecord1.PeriodEnd = Selection.PeriodEnd;
			EndIf;
		EndDo;
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write(False);
	EndIf;
EndProcedure

Function GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod) Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200) AS Period,
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200 + &AggregationPeriod - 1) AS PeriodEnd,
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200) AS DeletionID,
	|	MeasurementsStatisticsComments.StatisticsOperation,
	|	MeasurementsStatisticsComments.StatisticsComment,
	|	SUM(MeasurementsStatisticsComments.ValuesCount) AS ValuesCount
	|FROM
	|	InformationRegister.MeasurementsStatisticsComments AS MeasurementsStatisticsComments
	|WHERE
	|	MeasurementsStatisticsComments.Period >= &AggregationBoundary
	|	AND MeasurementsStatisticsComments.Period < &ProcessRecordsUntil
	|GROUP BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200),
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&AggregationPeriod - 0.5 AS NUMBER(11,0)) * &AggregationPeriod - 63555667200 + &AggregationPeriod - 1),
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	MeasurementsStatisticsComments.StatisticsOperation,
	|	MeasurementsStatisticsComments.StatisticsComment
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
	|	MeasurementsStatisticsComments.DeletionID	
	|FROM
	|	InformationRegister.MeasurementsStatisticsComments AS MeasurementsStatisticsComments
	|WHERE
	|	MeasurementsStatisticsComments.Period >= &AggregationBoundary
	|	AND MeasurementsStatisticsComments.Period < &ProcessRecordsUntil
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
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200) AS Period,
	|	StatisticsComments.Description AS StatisticsComment,
	|	SUM(MeasurementsStatisticsComments.ValuesCount) AS ValuesCount
	|FROM
	|	InformationRegister.MeasurementsStatisticsComments AS MeasurementsStatisticsComments
	|INNER JOIN
	|	InformationRegister.StatisticsOperations AS StatisticsOperations
	|ON
	|	MeasurementsStatisticsComments.StatisticsOperation = StatisticsOperations.OperationID
	|INNER JOIN
	|	InformationRegister.StatisticsComments AS StatisticsComments
	|ON
	|	MeasurementsStatisticsComments.StatisticsComment = StatisticsComments.CommentID
	|WHERE
	|	MeasurementsStatisticsComments.Period >= &StartDate
	|	AND MeasurementsStatisticsComments.PeriodEnd <= &EndDate
	|GROUP BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	StatisticsOperations.Description,
	|	StatisticsComments.Description
	|ORDER BY
	|	DATEADD(DATETIME(2015,1,1),SECOND, CAST((DATEDIFF(DATETIME(2015,1,1), MeasurementsStatisticsComments.Period, SECOND) + 63555667200)/&DeletionPeriod - 0.5 AS NUMBER(11,0)) * &DeletionPeriod - 63555667200),
	|	StatisticsOperations.Description,
	|	StatisticsComments.Description
	|";
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.SetParameter("DeletionPeriod", DeletionPeriod);
	
	QueryResult = Query.Execute();
	
	Return QueryResult;	
EndFunction

#EndRegion

#EndIf