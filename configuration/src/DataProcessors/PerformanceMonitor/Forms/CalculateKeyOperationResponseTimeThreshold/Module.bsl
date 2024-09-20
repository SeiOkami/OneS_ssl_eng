///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Parameters.Property("KeyOperation", KeyOperation);
	If Not ValueIsFilled(Period.StartDate) Then
		Period.StartDate = AddMonth(BegOfDay(CurrentSessionDate()), -3);
	EndIf;
	If Not ValueIsFilled(Period.EndDate) Then
		Period.EndDate = BegOfDay(CurrentSessionDate());
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EvaluateResponseTimeThreshold(Command)                             
	CheckResult = FillChecking();
	If CheckResult Then
		
		PickingParameters = New Structure;
		PickingParameters.Insert("KeyOperation", KeyOperation);
		PickingParameters.Insert("StartDate", Period.StartDate);
		PickingParameters.Insert("EndDate", Period.EndDate);
		PickingParameters.Insert("TargetAPDEX", CurrentAPDEX);		
		CalculationResult1 = CalculateResponseTimeThresholdAtServer(PickingParameters);
		If CalculationResult1.Property("ErrorDescription") Then
			Message = New UserMessage;
			Message.Text = CalculationResult1.ErrorDescription;
			Message.Message();
			Return;
		EndIf;
		EstimatedAPDEX = CalculationResult1.EstimatedAPDEX;
		MeasurementsCount = CalculationResult1.MeasurementsCount;
		ResponseTimeThreshold = CalculationResult1.ResponseTimeThreshold;
		
		APDEXScoreChart.ChartType = ChartType.Line;
		APDEXScoreChart.PlotArea.ValuesScale.TitleText = NStr("en = 'Number of samples';");
		APDEXScoreChart.Clear();
		Series = APDEXScoreChart.Series.Add("Time execution, From1");		
		For Each Measurement In CalculationResult1.Measurements Do
			For Each Record In Measurement Do
				Point = APDEXScoreChart.Points.Add(Record.Key);
				Point.Text = Format(Record.Key, "NZ=0");
				APDEXScoreChart.SetValue(Point, Series, Record.Value);
			EndDo;
		EndDo;		
	EndIf;
EndProcedure


#EndRegion

#Region Private

&AtClient
Function FillChecking()
	Success = True;
	If KeyOperation.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'A key operation is required.';");
		Message.Field = "KeyOperation";
		Message.Message();
		Success = False;
	EndIf;
	If Not ValueIsFilled(CurrentAPDEX) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The current Apdex score is required.';");
		Message.Field = "CurrentAPDEX";
		Message.Message();
		Success = False;
	EndIf;
	If Not ValueIsFilled(Period.StartDate) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Start date is required.';");
		Message.Field = "Period";
		Message.Message();
		Success = False;
	EndIf;
	If Not ValueIsFilled(Period.EndDate) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'End date is required.';");
		Message.Field = "Period";
		Message.Message();
		Success = False;
	EndIf;
	Return Success;
EndFunction

&AtServerNoContext
Function CalculateResponseTimeThresholdAtServer(PickingParameters)
	
	CalculationResult1 = New Structure;
	CalculationResult1.Insert("Measurements", New Array);
	CalculationResult1.Insert("MeasurementsCount", 0);
	CalculationResult1.Insert("ResponseTimeThreshold", 0);
	CalculationResult1.Insert("EstimatedAPDEX", 0);
	Minimum = 0;
	Maximum = 0;
	PermissibleDifference = 0.01;
	MaxNumberOfIterations = 1000;
	Counter = 0;
	TTM = New TempTablesManager;
	
	
	Query = New Query("SELECT
	                      |	Measurements.RunTime AS RunTime,
	                      |	1 AS MeasurementsCount
	                      |INTO OperationMeasurements
	                      |FROM
	                      |	InformationRegister.TimeMeasurements AS Measurements
	                      |WHERE
	                      |	Measurements.MeasurementStartDate BETWEEN &StartDate AND &EndDate
	                      |	AND Measurements.KeyOperation = &KeyOperation
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	ISNULL(MAX(OperationMeasurements.RunTime), 0) AS MAXIMUMRunTime,
	                      |	ISNULL(MIN(OperationMeasurements.RunTime), 0) AS MINIMUMRunTime,
	                      |	ISNULL(SUM(OperationMeasurements.MeasurementsCount), 0) AS MeasurementsCount
	                      |FROM
	                      |	OperationMeasurements AS OperationMeasurements");
	Query.TempTablesManager = TTM;
	Query.SetParameter("StartDate", (PickingParameters.StartDate - Date(1,1,1)) * 1000);	
	Query.SetParameter("EndDate", (PickingParameters.EndDate - Date(1,1,1)) * 1000);
	Query.SetParameter("KeyOperation", PickingParameters.KeyOperation);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Minimum = Selection.MINIMUMRunTime;
		Maximum = Selection.MAXIMUMRunTime;
		CalculationResult1.MeasurementsCount = Selection.MeasurementsCount;
	Else
		CalculationResult1.Insert("ErrorDescription", NStr("en = 'No metrics have been received. Try to change Apdex settings.';"));
		Return CalculationResult1;
	EndIf;
	
	If CalculationResult1.MeasurementsCount = 0 Then
		CalculationResult1.Insert("ErrorDescription",
			PerformanceMonitorClientServer.SubstituteParametersToString(
				NStr("en = 'No samples have been received for the %1 key operation. Change the period or choose another key operation.';"),
				PickingParameters.KeyOperation));
		Return CalculationResult1;
	EndIf;
	
	CurrentResponseTimeThreshold = (Minimum + Maximum) / 2;
	EstimatedAPDEX = ApdexValue(TTM, CurrentResponseTimeThreshold);
	Deviation = Max(EstimatedAPDEX - PickingParameters.TargetAPDEX, PickingParameters.TargetAPDEX - EstimatedAPDEX);
	
	While Deviation > PermissibleDifference
		And Counter < MaxNumberOfIterations
		Do
		Counter = Counter + 1;
		DataMin = DeviationAPDEX(Minimum, CurrentResponseTimeThreshold, TTM, PickingParameters.TargetAPDEX); // @skip-
		DataMax = DeviationAPDEX(Maximum, CurrentResponseTimeThreshold, TTM, PickingParameters.TargetAPDEX); // @skip-
		
		If Maximum - Minimum <= 0.002 Then
			Break;
		ElsIf DataMin.Deviation <= DataMax.Deviation Then
			Maximum = CurrentResponseTimeThreshold;
			CurrentResponseTimeThreshold = DataMin.CurrentResponseTimeThreshold;			
			Deviation = DataMin.Deviation;
			EstimatedAPDEX = DataMin.APDEX;
		ElsIf DataMin.Deviation > DataMax.Deviation Then
			Minimum = CurrentResponseTimeThreshold;
			CurrentResponseTimeThreshold = DataMax.CurrentResponseTimeThreshold;			
			Deviation = DataMax.Deviation;
			EstimatedAPDEX = DataMax.APDEX;
		EndIf;
		
	EndDo;
	
	CalculationResult1.ResponseTimeThreshold = CurrentResponseTimeThreshold;
	CalculationResult1.EstimatedAPDEX = EstimatedAPDEX; 
	CalculationResult1.Measurements = MeasurementsMap(TTM);
		
	Return CalculationResult1;
	
EndFunction

&AtServerNoContext
Function DeviationAPDEX(IntervalEndpoint, CurrentResponseTimeThreshold, TempTablesManager, TargetAPDEX)
	CurrentResponseTimeThresholdNew = Round((IntervalEndpoint + CurrentResponseTimeThreshold) / 2, 3);
	APDEX = ApdexValue(TempTablesManager, CurrentResponseTimeThresholdNew);
	Deviation = Max(APDEX - TargetAPDEX, TargetAPDEX - APDEX);	
	Return New Structure("CurrentResponseTimeThreshold, APDEX, Deviation", CurrentResponseTimeThresholdNew, APDEX, Deviation)
EndFunction

&AtServerNoContext
Function MeasurementsMap(TempTablesManager)
	MeasurementsMap = New Array;
	Query = New Query("SELECT
	                      |	CAST(OperationMeasurements.RunTime AS NUMBER(15, 0)) AS RunTime,
	                      |	SUM(OperationMeasurements.MeasurementsCount) AS MeasurementsCount
	                      |FROM
	                      |	OperationMeasurements AS OperationMeasurements
	                      |
	                      |GROUP BY
	                      |	CAST(OperationMeasurements.RunTime AS NUMBER(15, 0))
	                      |
	                      |ORDER BY
	                      |	RunTime");
	Query.TempTablesManager = TempTablesManager;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Measurement = New Map;
		Measurement.Insert(Selection.RunTime, Selection.MeasurementsCount);
		MeasurementsMap.Add(Measurement);
	EndDo;
	Return MeasurementsMap;
EndFunction

&AtServerNoContext
Function ApdexValue(TempTablesManager, CurrentResponseTimeThreshold)
	Query = New Query("SELECT
	               |	SUM(CASE
	               |			WHEN OperationMeasurements.RunTime <= &ResponseTimeThreshold
	               |				THEN OperationMeasurements.MeasurementsCount
	               |			ELSE 0
	               |		END) AS T,
	               |	SUM(CASE
	               |			WHEN OperationMeasurements.RunTime > &ResponseTimeThreshold
	               |					AND OperationMeasurements.RunTime <= 4 * &ResponseTimeThreshold
	               |				THEN OperationMeasurements.MeasurementsCount
	               |			ELSE 0
	               |		END) AS T_4T,
	               |	SUM(OperationMeasurements.MeasurementsCount) AS N,
	               |	ISNULL((SUM(CASE
	               |			WHEN OperationMeasurements.RunTime <= &ResponseTimeThreshold
	               |				THEN OperationMeasurements.MeasurementsCount
	               |			ELSE 0
	               |		END) + SUM(CASE
	               |			WHEN OperationMeasurements.RunTime > &ResponseTimeThreshold
	               |					AND OperationMeasurements.RunTime <= 4 * &ResponseTimeThreshold
	               |				THEN OperationMeasurements.MeasurementsCount
	               |			ELSE 0
	               |		END) / 2) / SUM(OperationMeasurements.MeasurementsCount),0) AS APDEX
	               |FROM
	               |	OperationMeasurements AS OperationMeasurements");
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("ResponseTimeThreshold", CurrentResponseTimeThreshold);
	Selection = Query.Execute().Select();
	Selection.Next();
	Return Round(Selection.APDEX, 3);
EndFunction

#EndRegion