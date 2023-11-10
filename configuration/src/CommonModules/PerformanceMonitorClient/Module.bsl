///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Starts measuring the time for the key operation.
// The result is recorded in the TimeMeasurements information register.
// Since client measurements are stored in the client buffer and recorded at the intervals
// specified in the PerformanceMonitorRecordPeriod constant (every minute by default),
// some of the measurements may be lost if the session is terminated.
//
// Parameters:
//  KeyOperation - String - 	name of the key operation. If Undefined, the key operation
//									must be specified explicitly by calling the
//									SetMeasurementKeyOperation procedure.
//  RecordWithError - Boolean -	indicates automatic error recording. 
//									True - if the measurement was stopped automatically, it will be stored
//									with the "Completed with error" flag. If an error
//									cannot occur in a certain code chunk, you must stop the measurement explicitly using the
//									StopTimeMeasurement, or set the error flag False using the
//									SetMeasurementErrorFlag.
//									False - the measurement will be considered correct upon automatic completion.
//  AutoCompletion - Boolean	 - 		indicates whether the measurement must be completed automatically.
//									True - the measurement will be completed automatically
//									via the global idle handler.
//									False - the measurement must be completed explicitly by calling the
//									StopTimeMeasurement procedure.
//
// Returns:
//  UUID - 
//
Function TimeMeasurement(KeyOperation = Undefined, RecordWithError = False, AutoCompletion = True) Export
	
	If Not RunPerformanceMeasurements() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
	Parameters = TimeMeasurementParametersAtClient(KeyOperation);
	Parameters.AutoCompletion = AutoCompletion;
	Parameters.IsFailed = RecordWithError;

	StartTimeMeasurementAtClientInternal(Parameters);
	Return Parameters.MeasurementUUID;
	
EndFunction

// Begins a technological measurement of the key operation time.
// The measurement result will be recorded in InformationRegister.TimeMeasurements.
//
// Parameters:
//  AutoCompletion - Boolean	 - 	indicates whether the measurement must be completed automatically.
//								True - the measurement will be completed automatically
//								via the global idle handler.
//								False - the measurement must be completed explicitly by calling the
//								StopTimeMeasurement procedure.
//  KeyOperation - String - name of the key operation. If Undefined> the key operation
//								must be specified explicitly by calling the
//								SetMeasurementKeyOperation procedure.
//
// Returns:
//  UUID - 
//
Function StartTechologicalTimeMeasurement(AutoCompletion = True, KeyOperation = Undefined) Export
	
	If Not RunPerformanceMeasurements() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;

	Parameters = TimeMeasurementParametersAtClient(KeyOperation);
	Parameters.AutoCompletion = AutoCompletion;
	Parameters.Technological = True;
	Parameters.IsFailed = False;
		
	StartTimeMeasurementAtClientInternal(Parameters);
	Return Parameters.MeasurementUUID;
	
EndFunction

// Completes time measurement on the client.
//
// Parameters:
//  MeasurementUUID - UUID - a measurement UUID.
//  CompletedWithError - Boolean - indicates that the measurement was not completed to the end,
//  							and the key operation completed with error.
//
Procedure StopTimeMeasurement(MeasurementUUID, CompletedWithError = False) Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;

	EndTime = CurrentUniversalDateInMilliseconds();
	StopTimeMeasurementInternal(MeasurementUUID, EndTime);
	
	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		Return;
	EndIf;

	Measurement = TimeMeasurements.Measurements[MeasurementUUID];
	If Measurement = Undefined Then
		Return;
	EndIf;

	Measurement["IsFailed"] = CompletedWithError;
	TimeMeasurements.CompletedMeasurements.Insert(MeasurementUUID, Measurement);
	TimeMeasurements.Measurements.Delete(MeasurementUUID);
	
EndProcedure

// Sets measurement parameters.
//
// Parameters:
//  MeasurementUUID	- UUID - a measurement UUID.
//  MeasurementParameters	- Structure:
//    * KeyOperation - String		- name of the key operation.
//    * MeasurementWeight		- Number			-
//    * Comment		- String
//						- Map - 
//    * IsFailed - Boolean			- indicates whether the measurement was completed with an error,
//											see SetMeasurementErrorFlag.
//
Procedure SetMeasurementParameters(MeasurementUUID, MeasurementParameters) Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;

	Measurements = PerformanceMonitorTimeMeasurement().Measurements;
	For Each Parameter In MeasurementParameters Do
		Measurements[MeasurementUUID][Parameter.Key] = Parameter.Value;
	EndDo;
	
EndProcedure

// Sets the key operation for a measurement.
//
// Parameters:
//  MeasurementUUID 			- UUID - a measurement UUID.
//  KeyOperation	- String - a key operation name.
//
// If the key operation name is not yet known at the time of measurement,
// this procedure can be used to
// specify the key operation name at any time before the measurement is completed.
// For example, this can be done when posting a document because
// it cannot be guaranteed from the start that the document will be completed and not rejected.
// 
// &AtClient
// Procedure BeforeRecord(Cancel, RecordParameters)
//	If RecordParameters.RecordMode = DocumentRecordMode.Posting Then
//		MeasurementIDPosting = PerformanceMonitorClient.BeginTimeMeasurement(True);
//	EndIf;
// EndProcedure
//
// &AtClient
// Procedure AfterRecord(RecordParameters)
//	If RecordParameters.RecordMode = DocumentRecordMode.Posting Then
//		PerformanceMonitorClient.SetMeasurementKeyOperation(MeasurementIDPosting, "_DemoDocumentPosting");
//	EndIf;
// EndProcedure
//
Procedure SetMeasurementKeyOperation(MeasurementUUID, KeyOperation) Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;

	PerformanceMonitorTimeMeasurement().Measurements[MeasurementUUID]["KeyOperation"] = KeyOperation;
	
EndProcedure

// Sets the weight for a measurement operation.
//
// Parameters:
//  MeasurementUUID - UUID - a measurement UUID.
//  MeasurementWeight - Number					- an indicator of
//										  measurement complexity, e.g. the number of lines in a document.
//
Procedure SetMeasurementWeight(MeasurementUUID, MeasurementWeight) Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;
	PerformanceMonitorTimeMeasurement().Measurements[MeasurementUUID]["MeasurementWeight"] = MeasurementWeight;
	
EndProcedure

// Sets a comment for a measurement operation.
//
// Parameters:
//  MeasurementUUID   - UUID - a measurement UUID.
//  Comment - String
//              - Map of KeyAndValue - 
//                               
//                                            * Key     - String - name of the additional parameter.
//                                            * Value - String
//                                                       - Number
//                                                       - Boolean - 
//
Procedure SetMeasurementComment(MeasurementUUID, Comment) Export
		
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;
	PerformanceMonitorTimeMeasurement().Measurements[MeasurementUUID]["Comment"] = Comment;
	
EndProcedure

// Sets an error flag for a measurement.
//
// Parameters:
//  MeasurementUUID	- UUID	- a measurement UUID.
//  Flag		- Boolean					- whether the measurement was successful. True - the measurement was successful.
//											  False - there was an error during the measurement.
//
Procedure SetMeasurementErrorFlag(MeasurementUUID, Flag) Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;
	PerformanceMonitorTimeMeasurement().Measurements[MeasurementUUID]["IsFailed"] = Flag;
	
EndProcedure

// Starts measuring the time of a long-running key operation. You must complete the measurement explicitly by calling
// the FinishTimeConsumingOperationMeasurement procedure.
// The result is recorded in the TimeMeasurements information register.
//
// Parameters:
//  KeyOperation - String - name of the key operation. 
//  RecordWithError - Boolean -	indicates automatic error recording. 
//									True - if the measurement was stopped automatically, it will be stored
//									with the "Completed with error" flag. If an error
//									cannot occur in a certain code chunk, you must stop the measurement explicitly using the
//									StopTimeMeasurement method, or set the error flag False using the
//									SetMeasurementErrorFlag method
//									False - the measurement will be considered correct upon automatic completion.
//									StopTimeMeasurement.
//  AutoCompletion - Boolean	 - 		indicates whether the measurement must be completed automatically.
//									True - the measurement will be completed automatically
//									via the global idle handler.
//									False - the measurement must be completed explicitly by calling the
//									StopTimeMeasurement procedure.
//  LastStepName - String - 	name of the key operation last step. The parameter is useful when
//									running a measurement with automatic completion. Otherwise, the last 
//									actions executed between RecordTimeConsumingOperationMeasurement and 
//									idle handler will be recorded under the name "Last step".
//
// Returns:
//   Map of KeyAndValue:
//     * Key - String
//     * Value - Arbitrary
//    
//     
//     
//     
//     
//     
//
Function StartTimeConsumingOperationMeasurement(KeyOperation, RecordWithError = False, AutoCompletion = False, LastStepName = "LastStep") Export
	
	If Not RunPerformanceMeasurements() Then
		Return New Map;
	EndIf;
	
	Parameters = TimeMeasurementParametersAtClient(KeyOperation);
	Parameters.IsFailed = RecordWithError;
	Parameters.AutoCompletion = AutoCompletion;
			
	StartTimeMeasurementAtClientInternal(Parameters);
	
	TimeMeasurements = PerformanceMonitorTimeMeasurement().Measurements;
	TimeMeasurement = TimeMeasurements[Parameters.MeasurementUUID];
	TimeMeasurement.Insert("LastMeasurementTime", TimeMeasurement["BeginTime"]);
	TimeMeasurement.Insert("WeightedTime", 0.0);
	TimeMeasurement.Insert("MeasurementWeight", 0);
	TimeMeasurement.Insert("NestedMeasurements", New Map);
	TimeMeasurement.Insert("MeasurementUUID", Parameters.MeasurementUUID);
	TimeMeasurement.Insert("Client", True);
	TimeMeasurement.Insert("LastStepName", LastStepName);
	Return TimeMeasurement;
	
EndFunction

// Records the measurement of a nested step of a long-running operation.
// Parameters:
//  MeasurementDetails 		- Map	 - must be obtained by calling the StartTimeConsumingOperationMeasurement method.
//  DataVolume 	- Number			 - amount of data, e.g. lines, processed during the nested step.
//  StepName 			- String		 - an arbitrary name of the nested step.
//  Comment 		- String		 - an arbitrary additional description of the measurement.
//
Procedure FixTimeConsumingOperationMeasure(MeasurementDetails, DataVolume, StepName, Comment = "") Export
	
	If Not ValueIsFilled(MeasurementDetails) Then
		Return;
	EndIf;
	
	CurrentTime = CurrentUniversalDateInMilliseconds();
	DataVolumeInStep = ?(DataVolume = 0, 1, DataVolume);
	
	Duration = CurrentTime - MeasurementDetails["LastMeasurementTime"];
	// Initializing the nested measurement if it's the first time it's performed.
	NestedMeasurements = MeasurementDetails["NestedMeasurements"];
	If NestedMeasurements[StepName] = Undefined Then
		NestedMeasurements.Insert(StepName, New Map);
		NestedMeasurementStep = NestedMeasurements[StepName];
		NestedMeasurementStep.Insert("Comment", Comment);
		NestedMeasurementStep.Insert("BeginTime", MeasurementDetails["LastMeasurementTime"]);
		NestedMeasurementStep.Insert("Duration", 0.0);	
		NestedMeasurementStep.Insert("MeasurementWeight", 0);
	EndIf;                                                            
	// 
	NestedMeasurementStep = NestedMeasurements[StepName];
	NestedMeasurementStep.Insert("EndTime", CurrentTime);
	NestedMeasurementStep.Insert("Duration", Duration + NestedMeasurementStep["Duration"]);
	NestedMeasurementStep.Insert("MeasurementWeight", DataVolumeInStep + NestedMeasurementStep["MeasurementWeight"]);
	
	// 
	MeasurementDetails.Insert("LastMeasurementTime", CurrentTime);
	MeasurementDetails.Insert("MeasurementWeight", DataVolumeInStep + MeasurementDetails["MeasurementWeight"]);
	
EndProcedure

// Completes the measurement of a long-running operation.
// If a step name is specified, records it as a separate nested step
// Parameters:
//  MeasurementDetails 		- Map	 - must be obtained by calling the StartTimeConsumingOperationMeasurement method.
//  DataVolume 	- Number			 - amount of data, e.g. lines, processed during the nested step.
//  StepName 			- String		 - an arbitrary name of the nested step.
//  Comment 		- String		 - an arbitrary additional description of the measurement.
//
Procedure EndTimeConsumingOperationMeasurement(MeasurementDetails, DataVolume, StepName = "", Comment = "") Export
	
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;
		
	If MeasurementDetails["NestedMeasurements"].Count() > 0 Then
		DataVolumeInStep = ?(DataVolume = 0, 1, DataVolume);
		FixTimeConsumingOperationMeasure(MeasurementDetails, DataVolumeInStep, 
			?(IsBlankString(StepName), "LastStep", StepName), Comment);
	EndIf;
	
	MeasurementUUID = MeasurementDetails["MeasurementUUID"];
	EndTime = CurrentUniversalDateInMilliseconds();
	StopTimeMeasurementInternal(MeasurementUUID, EndTime);
	
	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		Return;
	EndIf;

	Measurement = TimeMeasurements.Measurements[MeasurementUUID];
	If Measurement <> Undefined Then
		CompletedMeasurements = TimeMeasurements.CompletedMeasurements;
		MeasurementDetails.Insert("EndTime", Measurement["EndTime"]);
		CompletedMeasurements.Insert(MeasurementUUID, MeasurementDetails);
		TimeMeasurements.Measurements.Delete(MeasurementUUID);
	EndIf;

EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. It will be removed in the next library version.
// Instead, use the
//		PerformanceMonitorClient.TimeMeasurement procedure
// Starts measuring the time for the key operation.
// The result is recorded in the TimeMeasurements information register.
// Since client measurements are stored in the client buffer and recorded at the intervals
// specified in the PerformanceMonitorRecordPeriod constant (every minute by default),
// some of the measurements may be lost if the session is terminated.
//
// Parameters:
//  AutoCompletion - Boolean	 - 	indicates whether the measurement must be completed automatically.
//								True - the measurement will be completed automatically
//								via the global idle handler.
//								False - the measurement must be completed explicitly by calling the
//								StopTimeMeasurement procedure.
//  KeyOperation - String - name of the key operation. If Undefined> the key operation
//								must be specified explicitly by calling the
//								SetMeasurementKeyOperation procedure.
//
// Returns:
//  UUID - 
//
Function StartTimeMeasurement(AutoCompletion = True, KeyOperation = Undefined) Export
	
	If Not RunPerformanceMeasurements() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;

	Parameters = TimeMeasurementParametersAtClient(KeyOperation);
	Parameters.AutoCompletion = AutoCompletion;
	Parameters.IsFailed = False;

	StartTimeMeasurementAtClientInternal(Parameters);
	Return Parameters.MeasurementUUID;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart(Parameters) Export
	
	ParameterName = "StandardSubsystems.PerformanceMonitor.StartTime1";
	BeginTime = ApplicationParameters[ParameterName];
	ApplicationParameters.Delete(ParameterName);
	
	StartTimeMeasurementWithOffset(BeginTime, True, "TotalApplicationStartTime");
	
EndProcedure

// See CommonClientOverridable.BeforeRecurringClientDataSendToServer
Procedure BeforeRecurringClientDataSendToServer(Parameters) Export
	
	ClientParameters = ApplicationParameters["StandardSubsystems.ClientParameters"];
	If ClientParameters = Undefined
	 Or Not ClientParameters.Property("PerformanceMonitor") Then
		Return;
	EndIf;
	RecordPeriod = ClientParameters.PerformanceMonitor.RecordPeriod;
	
	If Not ServerNotificationsClient.TimeoutExpired("StandardSubsystems.PerformanceMonitor", RecordPeriod, True) Then
		Return;
	EndIf;
	
	MeasurementsToWrite = MeasurementsToWrite();
	If MeasurementsToWrite = Undefined
	 Or Not ValueIsFilled(MeasurementsToWrite.CompletedMeasurements) Then
		Return;
	EndIf;
	
	Parameters.Insert("StandardSubsystems.PerformanceMonitor.MeasurementsToWrite", MeasurementsToWrite);
	
EndProcedure

#EndRegion

#Region Private

// Starts measuring the time for the key operation.
// The result is recorded in the TimeMeasurements information register.
//
// Parameters:
//  Offset - Number	 	 - 	measurement start date and time in milliseconds (see the CurrentUniversalDateInMilliseconds). 
//  AutoCompletion - Boolean	 - 	indicates whether the measurement must be completed automatically.
//								True - the measurement will be completed automatically
//								via the global idle handler.
//								False - the measurement must be completed explicitly by calling the
//								StopTimeMeasurement procedure.
//  KeyOperation - String - name of the key operation. If Undefined> the key operation
//								must be specified explicitly by calling the
//								SetMeasurementKeyOperation procedure.
//
// Returns:
//  UUID - 
//
Function StartTimeMeasurementWithOffset(Offset, AutoCompletion = True, KeyOperation = Undefined)
	
	If Not RunPerformanceMeasurements() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;

	Parameters = TimeMeasurementParametersAtClient(KeyOperation);
	Parameters.AutoCompletion = AutoCompletion;
	Parameters.IsFailed = False;
	Parameters.Offset = Offset;

	StartTimeMeasurementAtClientInternal(Parameters);
	Return Parameters.MeasurementUUID;
	
EndFunction

Function RunPerformanceMeasurements()
	
	RunPerformanceMeasurements = False;
	
	StandardSubsystemsParameterName = "StandardSubsystems.ClientParameters";
	
	If ApplicationParameters[StandardSubsystemsParameterName] = Undefined Then
		RunPerformanceMeasurements = PerformanceMonitorServerCallCached.RunPerformanceMeasurements();
	Else
		If ApplicationParameters[StandardSubsystemsParameterName].Property("PerformanceMonitor") Then
			RunPerformanceMeasurements = ApplicationParameters[StandardSubsystemsParameterName]["PerformanceMonitor"]["RunPerformanceMeasurements"];
		Else
			RunPerformanceMeasurements = PerformanceMonitorServerCallCached.RunPerformanceMeasurements();
		EndIf;
	EndIf;
	
	Return RunPerformanceMeasurements; 
	
EndFunction

// Returns:
//  Structure:
//   * KeyOperation - String
//   * MeasurementUUID - UUID
//   * AutoCompletion - Boolean
//   * Technological - Boolean
//   * IsFailed - Boolean
//   * Offset - Number
//   * Comment - 
//
Function TimeMeasurementParametersAtClient(KeyOperation)

	Parameters = New Structure;
	Parameters.Insert("KeyOperation", KeyOperation);
	Parameters.Insert("MeasurementUUID", New UUID());
	Parameters.Insert("AutoCompletion", True);
	Parameters.Insert("Technological", False);
	Parameters.Insert("IsFailed", False);
	Parameters.Insert("Offset", 0);
	Parameters.Insert("Comment", Undefined);
	Return Parameters;

EndFunction

// Returns:
//  Structure:
//   * Measurements - Map
//   * CompletedMeasurements - Map
//   * HasHandler - Boolean
//   * HandlerAttachmentTime - Date 
//   * ClientDateOffset - Number
//
Function PerformanceMonitorTimeMeasurement()
	Return ApplicationParameters["StandardSubsystems.PerformanceMonitorTimeMeasurement"];
EndFunction

// Parameters:
//  Parameters - See TimeMeasurementParametersAtClient
//
Procedure StartTimeMeasurementAtClientInternal(Parameters)
    
    BeginTime = CurrentUniversalDateInMilliseconds();
	If ApplicationParameters = Undefined Then
		ApplicationParameters = New Map;
	EndIf;
		
	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		TimeMeasurements = New Structure;
		TimeMeasurements.Insert("Measurements", New Map);
		TimeMeasurements.Insert("CompletedMeasurements", New Map);
		TimeMeasurements.Insert("HasHandler", False);
		TimeMeasurements.Insert("HandlerAttachmentTime", BeginTime);
		TimeMeasurements.Insert("ClientDateOffset", 0);
		ApplicationParameters["StandardSubsystems.PerformanceMonitorTimeMeasurement"] = TimeMeasurements;
		
		StandardSubsystemsParameterName = "StandardSubsystems.ClientParameters";
		If ApplicationParameters[StandardSubsystemsParameterName] = Undefined Then
			PerformanceMonitorParameters = PerformanceMonitorServerCall.GetParametersAtServer();
			CurrentRecordingPeriod = PerformanceMonitorParameters.RecordPeriod;
			DateAndTimeAtServer = PerformanceMonitorParameters.DateAndTimeAtServer;
		
			DateAndTimeAtClient = CurrentUniversalDateInMilliseconds();
			TimeMeasurements.ClientDateOffset = DateAndTimeAtServer - DateAndTimeAtClient;
		Else
			CurrentRecordingPeriod = Undefined; // 
			StandardSubsystemsApplicationParameters = ApplicationParameters[StandardSubsystemsParameterName];
			If StandardSubsystemsApplicationParameters.Property("PerformanceMonitor") Then
				TimeMeasurements.ClientDateOffset = StandardSubsystemsApplicationParameters["ClientDateOffset"];
			Else
				PerformanceMonitorParameters = PerformanceMonitorServerCall.GetParametersAtServer();
				DateAndTimeAtServer = PerformanceMonitorParameters.DateAndTimeAtServer;
				
				DateAndTimeAtClient = CurrentUniversalDateInMilliseconds();
				TimeMeasurements.ClientDateOffset = DateAndTimeAtServer - DateAndTimeAtClient;
			EndIf;
		EndIf;
				
		UserAgentInformation = "";
#If ThickClientManagedApplication Then
		UserAgentInformation = "ThickClientManagedApplication";
#ElsIf ThickClientOrdinaryApplication Then
		UserAgentInformation = "ThickClient";
#ElsIf ThinClient Then
		UserAgentInformation = "ThinClient";
#ElsIf WebClient Then
		ClientInfo = New SystemInfo();
		UserAgentInformation = ClientInfo.UserAgentInformation;
#EndIf
		TimeMeasurements.Insert("UserAgentInformation", UserAgentInformation);
		If CurrentRecordingPeriod <> Undefined Then
			AttachIdleHandler("WriteResultsAuto", CurrentRecordingPeriod, True);
		EndIf;
	EndIf;
	
	// 
	If Parameters.Offset > 0 Then
		BeginTime = Parameters.Offset + TimeMeasurements.ClientDateOffset;
	Else
		BeginTime = BeginTime + TimeMeasurements.ClientDateOffset;
	EndIf;
		
	Measurement = New Map;
	Measurement.Insert("KeyOperation", Parameters.KeyOperation);
	Measurement.Insert("AutoCompletion", Parameters.AutoCompletion);
	Measurement.Insert("BeginTime", BeginTime);
	Measurement.Insert("Comment", Parameters.Comment);
	Measurement.Insert("IsFailed", Parameters.IsFailed);
	Measurement.Insert("Technological", Parameters.Technological);
	Measurement.Insert("MeasurementWeight", 1);
	TimeMeasurements.Measurements.Insert(Parameters.MeasurementUUID, Measurement);

	If Parameters.AutoCompletion Then
		If Not TimeMeasurements.HasHandler Then
			AttachIdleHandler("EndTimeMeasurementAuto", 0.1, True);
			TimeMeasurements.HasHandler = True;
			TimeMeasurements.HandlerAttachmentTime = CurrentUniversalDateInMilliseconds() + TimeMeasurements.ClientDateOffset;
		EndIf;	
	EndIf;	
	
EndProcedure

Procedure StopTimeMeasurementAtClientAuto() Export
	
	EndTime = CurrentUniversalDateInMilliseconds();

	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		Return;
	EndIf;	

	ToDelete = New Array;

	IncompleteAutoMeasurementsCount = 0;
	For Each TimeMeasurement In TimeMeasurements.Measurements Do
		MeasurementValue = TimeMeasurement.Value;
		If MeasurementValue["AutoCompletion"] Then 
			If MeasurementValue["BeginTime"] <= TimeMeasurements.HandlerAttachmentTime 
				And MeasurementValue["EndTime"] = Undefined Then
				// If there are nested measurements, record the last step.
				If MeasurementValue["NestedMeasurements"] <> Undefined
					And MeasurementValue["NestedMeasurements"].Count() > 0 Then
					FixTimeConsumingOperationMeasure(MeasurementValue, 1, MeasurementValue["LastStepName"]);
				EndIf;
				
				// The client's date offset is calculated within the procedure.
				StopTimeMeasurementInternal(TimeMeasurement.Key, EndTime);
				If ValueIsFilled(TimeMeasurement.Value["KeyOperation"]) Then
					TimeMeasurements.CompletedMeasurements.Insert(TimeMeasurement.Key, TimeMeasurement.Value);
				EndIf;
				ToDelete.Add(TimeMeasurement.Key);
			Else
				IncompleteAutoMeasurementsCount = IncompleteAutoMeasurementsCount + 1;
			EndIf;
		EndIf;
	EndDo;
	
	For Each TimeMeasurement In ToDelete Do
		TimeMeasurements.Measurements.Delete(TimeMeasurement);
	EndDo;
	
	If IncompleteAutoMeasurementsCount = 0 Then
		TimeMeasurements.HasHandler = False;
	Else
		AttachIdleHandler("EndTimeMeasurementAuto", 0.1, True);
		TimeMeasurements.HasHandler = True;
		TimeMeasurements.HandlerAttachmentTime = CurrentUniversalDateInMilliseconds() + TimeMeasurements.ClientDateOffset;
	EndIf;
EndProcedure

Procedure StopTimeMeasurementInternal(MeasurementUUID, Val EndTime)
		
	If Not RunPerformanceMeasurements() Then
		Return;
	EndIf;

	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		Return;
	EndIf;

	ClientDateOffset = TimeMeasurements.ClientDateOffset;
	EndTime = EndTime + ClientDateOffset;

	Measurement = TimeMeasurements.Measurements[MeasurementUUID];
	If Measurement <> Undefined Then
		Measurement.Insert("EndTime", EndTime);
	EndIf;
	
EndProcedure

// Records accumulated key operation time measurements on the server.
//
// Parameters:
//  BeforeCompletion - Boolean - True if the method is called before the application is closed.
//
Procedure WriteResultsAutoNotGlobal(BeforeCompletion = False) Export
	
	MeasurementsToWrite = MeasurementsToWrite();
	If MeasurementsToWrite = Undefined Then
		Return;
	EndIf;

	NewRecordingPeriod = PerformanceMonitorServerCall.RecordKeyOperationsDuration(MeasurementsToWrite);
	
	StandardSubsystemsParameterName = "StandardSubsystems.ClientParameters";
	If ApplicationParameters[StandardSubsystemsParameterName] = Undefined Then
		// 
		AttachIdleHandler("WriteResultsAuto", NewRecordingPeriod, True);
	EndIf;
	
EndProcedure

Function MeasurementsToWrite()
	
	TimeMeasurements = PerformanceMonitorTimeMeasurement();
	If TimeMeasurements = Undefined Then
		Return Undefined;
	EndIf;

	CompletedMeasurements = TimeMeasurements.CompletedMeasurements;
	TimeMeasurements.CompletedMeasurements = New Map;
	
	MeasurementsToWrite = New Structure;
	MeasurementsToWrite.Insert("CompletedMeasurements", CompletedMeasurements);
	MeasurementsToWrite.Insert("UserAgentInformation", TimeMeasurements.UserAgentInformation);
	Return MeasurementsToWrite;
	
EndFunction

#EndRegion