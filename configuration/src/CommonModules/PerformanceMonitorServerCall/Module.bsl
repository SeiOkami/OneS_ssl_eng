///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Parameters:
//  MeasurementsToWrite - Structure:
//   * CompletedMeasurements - Map of KeyAndValue:
//      ** Key - UUID - the unique identifier of the measurement.
//      ** Value - Map
//   * UserAgentInformation - String
//
// Returns:
//   Number - 
//
Function RecordKeyOperationsDuration(MeasurementsToWrite) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	RecordPeriod = PerformanceMonitor.RecordPeriod();
	
	If ExclusiveMode() Then
		Return RecordPeriod;
	EndIf;
	
	If Not Constants.RunPerformanceMeasurements.Get() Then
		Return RecordPeriod;
	EndIf;
		
	Measurements = MeasurementsToWrite.CompletedMeasurements;
	UserAgentInformation = MeasurementsToWrite.UserAgentInformation;	
	
	RecordSet = PerformanceMonitorInternal.ServiceRecordSet(
		InformationRegisters.TimeMeasurements);
	TechnologicalRecordSet = PerformanceMonitorInternal.ServiceRecordSet(
		InformationRegisters.TimeMeasurementsTechnological);
	SessionNumber = InfoBaseSessionNumber();
	RecordDate = Date(1,1,1) + CurrentUniversalDateInMilliseconds()/1000;
	RecordDateBegOfHour = BegOfHour(RecordDate);
	User = InfoBaseUsers.CurrentUser();
	RecordDateLocal = CurrentSessionDate();
	
	DefaultComment = Common.JSONValue(SessionParameters.TimeMeasurementComment);
	DefaultComment.Insert("InfCl", UserAgentInformation);
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
	WriteJSON(JSONWriter, DefaultComment);
	DefaultCommentLine = JSONWriter.Close();
		
	For Each Measurement In Measurements Do
		MeasurementParameters = Measurement.Value;
		Duration = (MeasurementParameters["EndTime"] - MeasurementParameters["BeginTime"])/1000;
		Duration = ?(Duration = 0, 0.001, Duration);
		
		If MeasurementParameters["Technological"] Then
			NewRecord = TechnologicalRecordSet.Add();
		Else
			NewRecord = RecordSet.Add();
		EndIf;
		
		KeyOperation = MeasurementParameters["KeyOperation"];
		CompletedWithError = MeasurementParameters["IsFailed"];
		
		If Not ValueIsFilled(KeyOperation) Then
			Continue;
		EndIf;
				
		If TypeOf(KeyOperation) = Type("String") Then
			KeyOperationRef = PerformanceMonitorCached.GetKeyOperationByName(KeyOperation);
		Else
			KeyOperationRef = KeyOperation;
		EndIf;
		
		
		If MeasurementParameters["Comment"] <> Undefined Then
			DefaultComment.Insert("AddlInf", MeasurementParameters["Comment"]);
			JSONWriter = New JSONWriter;
			JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
			WriteJSON(JSONWriter, DefaultComment);
			DefaultCommentLine = JSONWriter.Close();
		EndIf;
				
		NewRecord.KeyOperation = KeyOperationRef;
		NewRecord.MeasurementStartDate = MeasurementParameters["BeginTime"];
		NewRecord.SessionNumber = SessionNumber;
		NewRecord.RunTime = Duration;
		NewRecord.MeasurementWeight = MeasurementParameters["MeasurementWeight"];
		NewRecord.RecordDate = RecordDate;
		NewRecord.RecordDateBegOfHour = RecordDateBegOfHour;
		NewRecord.EndDate = MeasurementParameters["EndTime"];
		
		If Not MeasurementParameters["Technological"] Then
			NewRecord.CompletedWithError = CompletedWithError;
		EndIf;
		
		NewRecord.User = User;
		NewRecord.RecordDateLocal = RecordDateLocal;
		NewRecord.Comment = DefaultCommentLine;
		
		// Record nested measurements.
		NestedMeasurements = Measurement.Value["NestedMeasurements"];
		If NestedMeasurements = Undefined Then
			Continue;
		EndIf;
		
		WeightedTimeTotal = 0;
	
		For Each NestedMeasurement In NestedMeasurements Do
			MeasurementData = NestedMeasurement.Value;
			NestedMeasurementWeight = MeasurementData["MeasurementWeight"];
			NestedMeasurementDuration = MeasurementData["Duration"];
			NestedMeasurementComment = MeasurementData["Comment"];
			NestedStepKeyOperation = KeyOperation + "." + NestedMeasurement.Key;
			NestedStepKeyOperationLink = PerformanceMonitorCached.GetKeyOperationByName(NestedStepKeyOperation, True);
			WeightedTime = ?(NestedMeasurementWeight = 0, NestedMeasurementDuration, NestedMeasurementDuration / NestedMeasurementWeight);
			WeightedTimeTotal = WeightedTimeTotal + WeightedTime;
			
			If NestedMeasurementComment <> Undefined Then
				DefaultComment.Insert("AddlInf", NestedMeasurementComment);
				JSONWriter = New JSONWriter;
				JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
				WriteJSON(JSONWriter, DefaultComment);
				StepCommentString = JSONWriter.Close();
			EndIf;
		
			NewRecord = RecordSet.Add();
			NewRecord.KeyOperation = NestedStepKeyOperationLink;
			NewRecord.MeasurementStartDate = MeasurementData["BeginTime"];
			NewRecord.SessionNumber = SessionNumber;
			NewRecord.RunTime = WeightedTime/1000;
			NewRecord.MeasurementWeight = NestedMeasurementWeight;
			NewRecord.EndDate = MeasurementData["EndTime"];		
			NewRecord.RecordDate = RecordDate;
			NewRecord.RecordDateBegOfHour = RecordDateBegOfHour;						
			NewRecord.User = User;
			NewRecord.RecordDateLocal = RecordDateLocal;
			NewRecord.Comment = StepCommentString;
		EndDo;
		// Committing the key operation's weighted time.
		If NestedMeasurements.Count() > 0 Then
			KeyOperationWeighted = KeyOperation + ".Specific";
			KeyOperationWeightedRef = PerformanceMonitorCached.GetKeyOperationByName(KeyOperationWeighted, True);
			NewRecord = RecordSet.Add();
			NewRecord.KeyOperation = KeyOperationWeightedRef;
			NewRecord.MeasurementStartDate = MeasurementParameters["BeginTime"];
			NewRecord.SessionNumber = SessionNumber;
			NewRecord.RunTime = WeightedTimeTotal/1000;
			NewRecord.MeasurementWeight = MeasurementParameters["MeasurementWeight"];
			NewRecord.RecordDate = RecordDate;
			NewRecord.RecordDateBegOfHour = RecordDateBegOfHour;
			NewRecord.EndDate = MeasurementParameters["EndTime"];		
			NewRecord.User = User;
			NewRecord.RecordDateLocal = RecordDateLocal;
			NewRecord.Comment = DefaultCommentLine;
		EndIf;
	EndDo;
	
	If RecordSet.Count() > 0 Then
		Try
			RecordSet.Write(False);
		Except
			WriteLogEvent(NStr("en = 'Performance monitor.Error saving measurements';", 
				PerformanceMonitorInternal.DefaultLanguageCode()),
				EventLogLevel.Error,,,ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndIf;
	
	If TechnologicalRecordSet.Count() > 0 Then
		Try
			TechnologicalRecordSet.Write(False);
		Except
			WriteLogEvent(NStr("en = 'Failed to save service samples';", 
				PerformanceMonitorInternal.DefaultLanguageCode()),
				EventLogLevel.Error,,,ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndIf;
	
	Return RecordPeriod;
	
EndFunction

// Performance monitor parameters
//
// Returns:
//   Structure - 
//
Function GetParametersAtServer() Export
	
	Parameters = New Structure("DateAndTimeAtServer, RecordPeriod");
	Parameters.DateAndTimeAtServer = CurrentUniversalDateInMilliseconds();
	
	SetPrivilegedMode(True);
	Parameters.RecordPeriod = PerformanceMonitor.RecordPeriod();
	
	Return Parameters;
	
EndFunction

#EndRegion