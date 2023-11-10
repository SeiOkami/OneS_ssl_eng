///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// 
// 
// 
//  
// 
// 
// Parameters:
//  TimeConsumingOperation     - See TimeConsumingOperations.ExecuteInBackground
//  CompletionNotification2  - NotifyDescription - the notification that is called on completion of the background job. 
//                           The notification handler has the following parameters: 
//   * Result - Structure
//               - Undefined - 
//     ** Status           - String - "Completed " if the job has completed;
//	                                  "Error" if the job has completed with error.
//     ** ResultAddress  - String - the address of the temporary storage where the procedure result
//	                                  must be (or already is) stored.
//     ** AdditionalResultAddress - String - If the AdditionalResult parameter is set, 
//	                                     it contains the address of the additional temporary storage
//	                                     where the procedure result must be (or already is) stored.
//     ** BriefErrorDescription   - String - contains brief description of the exception if Status = "Error".
//     ** DetailErrorDescription - String - contains detailed description of the exception if Status = "Error".
//     ** Messages        - FixedArray - 
//                                         
//                                         
//                                         
//                                         
//   * AdditionalParameters - Arbitrary - arbitrary data that was passed in the notification details. 
//  IdleParameters      - See TimeConsumingOperationsClient.IdleParameters
//
Procedure WaitCompletion(Val TimeConsumingOperation, Val CompletionNotification2 = Undefined, 
	Val IdleParameters = Undefined) Export
	
	CheckParametersWaitForCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters);
	
	AdvancedOptions_ = IdleParameters(Undefined);
	If IdleParameters <> Undefined Then
		FillPropertyValues(AdvancedOptions_, IdleParameters);
	EndIf;
	If TimeConsumingOperation.Property("ResultAddress") Then
		AdvancedOptions_.Insert("ResultAddress", TimeConsumingOperation.ResultAddress);
	EndIf;
	If TimeConsumingOperation.Property("AdditionalResultAddress") Then
		AdvancedOptions_.Insert("AdditionalResultAddress", TimeConsumingOperation.AdditionalResultAddress);
	EndIf;
	AdvancedOptions_.Insert("JobID", TimeConsumingOperation.JobID);
	
	If TimeConsumingOperation.Status <> "Running" Then
		AdvancedOptions_.Insert("AccumulatedMessages", New Array);
		AdvancedOptions_.Insert("CompletionNotification2", CompletionNotification2);
		If AdvancedOptions_.OutputIdleWindow Then
			ProcessMessagesToUser(TimeConsumingOperation.Messages,
				AdvancedOptions_.AccumulatedMessages,
				AdvancedOptions_.OutputMessages,
				AdvancedOptions_.OwnerForm);
			FinishLongRunningOperation(AdvancedOptions_, TimeConsumingOperation);
		Else
			TimeConsumingOperation.Insert("Progress");
			TimeConsumingOperation.Insert("IsBackgroundJobCompleted");
			ProcessActiveOperationResult(AdvancedOptions_, TimeConsumingOperation);
		EndIf;
		Return;
	EndIf;
	
	If AdvancedOptions_.OutputIdleWindow Then
		AdvancedOptions_.Delete("OwnerForm");
		
		Context = New Structure;
		Context.Insert("Result");
		Context.Insert("JobID", AdvancedOptions_.JobID);
		Context.Insert("CompletionNotification2", CompletionNotification2);
		ClosingNotification1 = New NotifyDescription("OnFormClosureLongRunningOperation",
			ThisObject, Context);
		
		OpenForm("CommonForm.TimeConsumingOperation", AdvancedOptions_, 
			?(IdleParameters <> Undefined, IdleParameters.OwnerForm, Undefined),
			,,,ClosingNotification1);
	Else
		AdvancedOptions_.Insert("AccumulatedMessages", New Array);
		AdvancedOptions_.Insert("CompletionNotification2", CompletionNotification2);
		AdvancedOptions_.Insert("CurrentInterval", ?(AdvancedOptions_.Interval <> 0, AdvancedOptions_.Interval, 1));
		AdvancedOptions_.Insert("Control", CurrentDate() + AdvancedOptions_.CurrentInterval); // 
		AdvancedOptions_.Insert("LastProgressSendTime", 0);
		
		Operations = TimeConsumingOperationsInProgress();
		Operations.List.Insert(AdvancedOptions_.JobID, AdvancedOptions_);
		ServerNotificationsClient.AttachServerNotificationReceiptCheckHandler();
	EndIf;
	
EndProcedure

// Returns a blank structure for the IdleParameters parameter of TimeConsumingOperationsClient.WaitForCompletion procedure.
//
// Parameters:
//  OwnerForm - ClientApplicationForm
//                - Undefined - 
//
// Returns:
//  Structure              -  
//   * OwnerForm          - ClientApplicationForm
//                            - Undefined - 
//   * Title              - String - Title displayed on the wait form. If empty, the title is hidden. 
//   * MessageText         - String - the message text that is displayed in the idle form.
//                                       The default value is "Please wait…".
//   * OutputIdleWindow   - Boolean - If True, open the idle window with visual indication of a long-running operation. 
//                                       Set the value to False if you use your own indication engine.
//   * OutputProgressBar - Boolean - show execution progress as percentage in the idle form.
//                                      The handler procedure of a long-running operation can report the progress of its execution
//                                      by calling the TimeConsumingOperations.ReportProgress procedure.
//   * OutputMessages          - Boolean -
//                                       
//   * ExecutionProgressNotification - NotifyDescription - 
//                                      
//                                      
//      
//      
//                                           
//	                                         
//                                           
//	     
//	     
//	      
//                                  
//       
//
//   * Interval               - Number  - Interval between long-running operation completion checks, in seconds.
//                                       The default value is 0. After each check, the value increases from 1 to 15 seconds
//                                       with increment 1.4.
//   * UserNotification - Structure:
//     ** Show            - Boolean - show user notification upon completion of the long-running operation if True.
//     ** Text               - String - the user notification text.
//     ** URL - String - the user notification URL.
//     ** Explanation           - String - the user notification note.
//     ** Picture            - Picture - Picture to show in the notification dialog.
//                                         If Undefined, don't show the picture.
//     ** Important              - Boolean - If True, after being closed automatically, add the notification to the notification center.
//                                       
//   
//   * ShouldCancelWhenOwnerFormClosed - Boolean -
//       
//   
//   * MustReceiveResult - Boolean - For internal use only.
//
Function IdleParameters(OwnerForm) Export
	
	Result = New Structure;
	Result.Insert("OwnerForm", OwnerForm);
	Result.Insert("MessageText", "");
	Result.Insert("Title", ""); 
	Result.Insert("AttemptNumber", 1);
	Result.Insert("OutputIdleWindow", True);
	Result.Insert("OutputProgressBar", False);
	Result.Insert("ExecutionProgressNotification", Undefined);
	Result.Insert("OutputMessages", False);
	Result.Insert("Interval", 0);
	Result.Insert("MustReceiveResult", False);
	Result.Insert("ShouldCancelWhenOwnerFormClosed",
		TypeOf(OwnerForm) = Type("ClientApplicationForm") And OwnerForm.IsOpen());
	
	UserNotification = New Structure;
	UserNotification.Insert("Show", False);
	UserNotification.Insert("Text", Undefined);
	UserNotification.Insert("URL", Undefined);
	UserNotification.Insert("Explanation", Undefined);
	UserNotification.Insert("Picture", Undefined);
	UserNotification.Insert("Important", Undefined);
	Result.Insert("UserNotification", UserNotification);
	
	Return Result;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Fills the parameter structure with default values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - the structure to be filled with default values. 
//
// 
Procedure InitIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters = New Structure;
	IdleHandlerParameters.Insert("MinInterval", 1);
	IdleHandlerParameters.Insert("MaxInterval", 15);
	IdleHandlerParameters.Insert("CurrentInterval", 1);
	IdleHandlerParameters.Insert("IntervalIncreaseCoefficient", 1.4);
	
EndProcedure

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Fills the parameter structure with new calculated values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - the structure to be filled with calculated values. 
//
// 
Procedure UpdateIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval * IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
		
EndProcedure

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Opens the long-running operation progress form.
// 
// Parameters:
//  FormOwner        - ClientApplicationForm - the form used to open the long-running operation progress form. 
//  JobID - UUID - a background job ID.
//
// Returns:
//  ClientApplicationForm     - 
// 
Function OpenTimeConsumingOperationForm(Val FormOwner, Val JobID) Export
	
	Return OpenForm("CommonForm.TimeConsumingOperation",
		New Structure("JobID", JobID), 
		FormOwner);
	
EndFunction

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Closes the long-running operation progress form.
// 
// Parameters:
//  TimeConsumingOperationForm - ClientApplicationForm - the reference to the long-running operation indication form. 
//
Procedure CloseTimeConsumingOperationForm(TimeConsumingOperationForm) Export
	
	If TypeOf(TimeConsumingOperationForm) = Type("ClientApplicationForm") Then
		If TimeConsumingOperationForm.IsOpen() Then
			TimeConsumingOperationForm.Close();
		EndIf;
	EndIf;
	TimeConsumingOperationForm = Undefined;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

// Parameters:
//  Parameters - See CommonOverridable.ПередПериодическойОтправкойДанныхКлиентаНаСервер.Параметры
//  AreChatsActive - Boolean -
//  Interval - Number -
//
Procedure BeforeRecurringClientDataSendToServer(Parameters, AreChatsActive, Interval) Export
	
	Result = LongRunningOperationCheckParameters(AreChatsActive, Interval);
	If Result = Undefined Then
		Return;
	EndIf;
	
	Parameters.Insert("StandardSubsystems.Core.LongRunningOperationCheckParameters", Result)
	
EndProcedure

// Parameters:
//  Results - See CommonOverridable.OnReceiptRecurringClientDataOnServer.Results
//  AreChatsActive - Boolean -
//  Interval - Number -
//
Procedure AfterRecurringReceiptOfClientDataOnServer(Results, AreChatsActive, Interval) Export
	
	OperationsResult = Results.Get( // See TimeConsumingOperations.LongRunningOperationCheckResult
		"StandardSubsystems.Core.LongRunningOperationCheckResult");
	
	If OperationsResult = Undefined Then
		Return;
	EndIf;
	
	CurrentLongRunningOperations = TimeConsumingOperationsInProgress();
	TimeConsumingOperationsInProgress = CurrentLongRunningOperations.List;
	ActionsUnderControl     = CurrentLongRunningOperations.ActionsUnderControl;
	
	For Each OperationResult In OperationsResult Do
		Operation = ActionsUnderControl[OperationResult.Key];
		Result = OperationResult.Value; // Structure
		Result.Insert("IsBackgroundJobCompleted");
		Result.Insert("LongRunningOperationsControlWithoutInteractionSystem");
		ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result);
	EndDo;
	
	CurrentLongRunningOperations.ActionsUnderControl = New Map;

	If TimeConsumingOperationsInProgress.Count() = 0 Then
		Return;
	EndIf;
	
	ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive);
	
EndProcedure

// Parameters:
//  Result - Undefined
//  Context - Structure:
//   * Result - Structure
//               - Undefined
//   * JobID  - UUID
//                           - Undefined
//   * CompletionNotification2 - NotifyDescription
//                           - Undefined
//
Procedure OnFormClosureLongRunningOperation(Result, Context) Export
	
	If Context.CompletionNotification2 <> Undefined Then
		NotifyOfLongRunningOperationEnd(Context.CompletionNotification2,
			Context.Result, Context.JobID);
	EndIf;
	
EndProcedure

// Parameters:
//  AreChatsActive - Boolean -
//  Interval - Number -
//
// Returns:
//  Undefined - 
//  
//   * JobsToCheck - Array of UUID
//   * JobsToCancel - Array of UUID
//
Function LongRunningOperationCheckParameters(AreChatsActive, Interval)
	
	CurrentDate = CurrentDate(); // 
	
	ActionsUnderControl = New Map;
	JobsToCheck = New Array;
	JobsToCancel = New Array;
	
	CurrentLongRunningOperations = TimeConsumingOperationsInProgress();
	TimeConsumingOperationsInProgress = CurrentLongRunningOperations.List;
	CurrentLongRunningOperations.ActionsUnderControl = ActionsUnderControl;
	
	If Not ValueIsFilled(TimeConsumingOperationsInProgress) Then
		Return Undefined;
	EndIf;
	
	For Each TimeConsumingOperation In TimeConsumingOperationsInProgress Do
		
		TimeConsumingOperation = TimeConsumingOperation.Value;
		
		If IsLongRunningOperationCanceled(TimeConsumingOperation) Then
			ActionsUnderControl.Insert(TimeConsumingOperation.JobID, TimeConsumingOperation);
			JobsToCancel.Add(TimeConsumingOperation.JobID);
		Else
			ChatsControlInterval = ChatsControlInterval();
			DateOfControl = TimeConsumingOperation.Control
				+ ?(Not AreChatsActive Or TimeConsumingOperation.CurrentInterval > ChatsControlInterval,
					0, ChatsControlInterval - TimeConsumingOperation.CurrentInterval);
			
			If DateOfControl <= CurrentDate Then
				ActionsUnderControl.Insert(TimeConsumingOperation.JobID, TimeConsumingOperation);
				JobsToCheck.Add(TimeConsumingOperation.JobID);
			EndIf;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(JobsToCheck)
	   And Not ValueIsFilled(JobsToCancel) Then
		
		ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive);
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("JobsToCheck", JobsToCheck);
	Result.Insert("JobsToCancel",   JobsToCancel);
	
	Return Result;
	
EndFunction

Function IsLongRunningOperationCanceled(TimeConsumingOperation)
	
	Return TimeConsumingOperation.ShouldCancelWhenOwnerFormClosed
	    And TimeConsumingOperation.OwnerForm <> Undefined
		And Not TimeConsumingOperation.OwnerForm.IsOpen();
	
EndFunction

Procedure ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result)
	
	If TimeConsumingOperationsInProgress.Get(Operation.JobID) = Undefined Then
		Return;
	EndIf;
	
	Try
		If ProcessActiveOperationResult(Operation, Result) Then
			TimeConsumingOperationsInProgress.Delete(Operation.JobID);
		EndIf;
	Except
		// 
		TimeConsumingOperationsInProgress.Delete(Operation.JobID);
		Raise;
	EndTry;
	
EndProcedure

Procedure ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive)
	
	CurrentDate = CurrentDate(); // 
	NewInterval = 120; 
	For Each Operation In TimeConsumingOperationsInProgress Do
		NewInterval = Max(Min(NewInterval, Operation.Value.Control - CurrentDate), 1);
	EndDo;
	
	ChatsControlInterval = ChatsControlInterval();
	If AreChatsActive And NewInterval < ChatsControlInterval Then
		NewInterval = ChatsControlInterval;
	EndIf;
	
	If Interval > NewInterval Then
		Interval = NewInterval;
	EndIf;
	
EndProcedure

// Returns:
//  Number - 
//          
//          
//          
//          
//          
//
Function ChatsControlInterval()
	
	Return 30;
	
EndFunction

// See StandardSubsystemsClient.OnReceiptServerNotification
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	TimeConsumingOperationsInProgress = TimeConsumingOperationsInProgress().List;
	Operation = TimeConsumingOperationsInProgress.Get(Result.JobID);
	If Operation = Undefined
	 Or IsLongRunningOperationCanceled(Operation) Then
		Return;
	EndIf;
	
	If Result.NotificationKind = "Progress" Then
		If Operation.LastProgressSendTime < Result.TimeSentOn Then
			Operation.LastProgressSendTime = Result.TimeSentOn;
		Else
			Return; // 
		EndIf;
	EndIf;
	
	ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result.Result);
	
EndProcedure

// Parameters:
//  TimeConsumingOperation - Structure:
//   * OwnerForm          - ClientApplicationForm
//                            - Undefined
//   * Title              - String
//   * MessageText         - String
//   * OutputIdleWindow   - Boolean
//   * OutputProgressBar - Boolean
//   * ExecutionProgressNotification - NotifyDescription
//                                    - Undefined
//   * OutputMessages      - Boolean
//   * Interval               - Number
//   * UserNotification - Structure:
//     ** Show            - Boolean
//     ** Text               - String
//     ** URL - String
//     ** Explanation           - String
//     ** Picture            - Picture
//     ** Important              - Boolean
//    
//   * ShouldCancelWhenOwnerFormClosed - Boolean
//   * MustReceiveResult
//   
//   * JobID  - UUID
//   * AccumulatedMessages  - Array
//   * CompletionNotification2 - NotifyDescription
//                           - Undefined
//   * CurrentInterval       - Number
//   * Control              - Date
//    
//   * LastProgressSendTime - Number -
//
//  Result - See TimeConsumingOperations.OperationNewRuntimeResult
//
Function ProcessActiveOperationResult(TimeConsumingOperation, Result)
	
	If Result.Status <> "Canceled" Then
		If TimeConsumingOperation.ExecutionProgressNotification <> Undefined Then
			Progress = New Structure;
			Progress.Insert("Status", Result.Status);
			Progress.Insert("JobID", TimeConsumingOperation.JobID);
			Progress.Insert("Progress", Result.Progress);
			Progress.Insert("Messages", Result.Messages);
			Try
				ExecuteNotifyProcessing(TimeConsumingOperation.ExecutionProgressNotification, Progress);
			Except
				ErrorInfo = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An error occurred when calling a notification about the progress of
					           |the ""%1"" long-running operation:
					           |%2';"),
					String(TimeConsumingOperation.JobID),
					ErrorProcessing.DetailErrorDescription(ErrorInfo));
				EventLogClient.AddMessageForEventLog(
					NStr("en = 'Long-running operations.Error calling the event handler';",
						CommonClient.DefaultLanguageCode()),
					"Error",
					ErrorText);
			EndTry;
		ElsIf Result.Messages <> Undefined Then
			For Each Message In Result.Messages Do
				TimeConsumingOperation.AccumulatedMessages.Add(Message);
			EndDo;
		EndIf;
	EndIf;
	
	If Result.Status <> "Running" Then
		If Result.Status <> "Completed2"
		 Or Result.Property("IsBackgroundJobCompleted")
		 Or Not (  TimeConsumingOperation.Property("ResultAddress")
		         And ValueIsFilled(TimeConsumingOperation.ResultAddress)
		       Or TimeConsumingOperation.Property("AdditionalResultAddress")
		         And ValueIsFilled(TimeConsumingOperation.AdditionalResultAddress))
		 // 
		 // 
		 Or TimeConsumingOperationsServerCall.IsBackgroundJobCompleted(TimeConsumingOperation.JobID) Then
		 
			FinishLongRunningOperation(TimeConsumingOperation, Result);
			Return True;
		EndIf;
	EndIf;
	
	IdleInterval = TimeConsumingOperation.CurrentInterval;
	If TimeConsumingOperation.Interval = 0
	   And Result.Property("LongRunningOperationsControlWithoutInteractionSystem") Then
		IdleInterval = IdleInterval * 1.4;
		If IdleInterval > 15 Then
			IdleInterval = 15;
		EndIf;
		TimeConsumingOperation.CurrentInterval = IdleInterval;
	EndIf;
	TimeConsumingOperation.Control = CurrentDate() + IdleInterval; // 
	Return False;
	
EndFunction

Procedure ProcessMessagesToUser(Messages, AccumulatedMessages, OutputMessages, FormOwner) Export
	
	TargetID = ?(OutputMessages And FormOwner <> Undefined,
		FormOwner.UUID, Undefined);
	
	For Each UserMessage In Messages Do
		AccumulatedMessages.Add(UserMessage);
		If TargetID <> Undefined Then
			NewMessage = New UserMessage;
			FillPropertyValues(NewMessage, UserMessage);
			NewMessage.TargetID = TargetID;
			NewMessage.Message();
		EndIf;
	EndDo;
	
EndProcedure

Procedure FinishLongRunningOperation(Val TimeConsumingOperation, Val Status)
	
	If Status.Status = "Completed2" Then
		ShowNotification(TimeConsumingOperation.UserNotification);
	EndIf;
	
	If TimeConsumingOperation.CompletionNotification2 = Undefined Then
		Return;
	EndIf;
	
	If Status.Status = "Canceled" Then
		Result = Undefined;
	Else
		Result = New Structure;
		Result.Insert("Status",    Status.Status);
		If TimeConsumingOperation.Property("ResultAddress") Then
			Result.Insert("ResultAddress", TimeConsumingOperation.ResultAddress);
		EndIf;
		If TimeConsumingOperation.Property("AdditionalResultAddress") Then
			Result.Insert("AdditionalResultAddress", TimeConsumingOperation.AdditionalResultAddress);
		EndIf;
		Result.Insert("BriefErrorDescription", Status.BriefErrorDescription);
		Result.Insert("DetailErrorDescription", Status.DetailErrorDescription);
		Result.Insert("Messages", New FixedArray(TimeConsumingOperation.AccumulatedMessages));
	EndIf;
	
	NotifyOfLongRunningOperationEnd(TimeConsumingOperation.CompletionNotification2,
		Result, TimeConsumingOperation.JobID);
	
EndProcedure

Procedure NotifyOfLongRunningOperationEnd(CompletionNotification2, Result, JobID)
	
	Try
		ExecuteNotifyProcessing(CompletionNotification2, Result);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when calling a notification about the completion of
			           |the ""%1"" long-running operation:
			           |%2';"),
			String(JobID),
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Long-running operations.Error calling the event handler';",
				CommonClient.DefaultLanguageCode()),
			"Error", ErrorText,, True);
		ErrorProcessing.ShowErrorInfo(ErrorInfo);
	EndTry;
	
EndProcedure

// Returns:
//   Structure:
//    * List - Map of KeyAndValue:
//       ** Key - UUID - ID of the background task.
//       ** Value - See ProcessActiveOperationResult.TimeConsumingOperation
//    * ActionsUnderControl - Map of KeyAndValue:
//       ** Key - UUID - ID of the background task.
//       ** Value - See ProcessActiveOperationResult.TimeConsumingOperation
//
Function TimeConsumingOperationsInProgress()
	
	ParameterName = "StandardSubsystems.TimeConsumingOperationsInProgress";
	If ApplicationParameters[ParameterName] = Undefined Then
		Operations = New Structure;
		Operations.Insert("List", New Map);
		Operations.Insert("ActionsUnderControl", New Map);
		ApplicationParameters.Insert(ParameterName, Operations);
	EndIf;
	
	Return ApplicationParameters[ParameterName];

EndFunction

Procedure CheckParametersWaitForCompletion(Val TimeConsumingOperation, Val CompletionNotification2, Val IdleParameters)
	
	CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
		"TimeConsumingOperation", TimeConsumingOperation, Type("Structure"));
	
	If CompletionNotification2 <> Undefined Then
		CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
			"CompletionNotification2", CompletionNotification2, Type("NotifyDescription"));
	EndIf;
	
	If IdleParameters <> Undefined Then
		
		PropertyTypes = New Structure;
		If IdleParameters.OwnerForm <> Undefined Then
			PropertyTypes.Insert("OwnerForm", Type("ClientApplicationForm"));
		EndIf;
		PropertyTypes.Insert("MessageText", Type("String"));
		PropertyTypes.Insert("Title",      Type("String"));
		PropertyTypes.Insert("OutputIdleWindow", Type("Boolean"));
		PropertyTypes.Insert("OutputProgressBar", Type("Boolean"));
		PropertyTypes.Insert("OutputMessages", Type("Boolean"));
		PropertyTypes.Insert("Interval", Type("Number"));
		PropertyTypes.Insert("UserNotification", Type("Structure"));
		PropertyTypes.Insert("MustReceiveResult", Type("Boolean"));
		
		CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
			"IdleParameters", IdleParameters, Type("Structure"), PropertyTypes);
			
		VerificationMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Parameter %1 must be equal to or greater than 1';"), "IdleParameters.Interval");
		
		CommonClientServer.Validate(IdleParameters.Interval = 0 Or IdleParameters.Interval >= 1,
			VerificationMessage, "TimeConsumingOperationsClient.WaitCompletion");
			
		VerificationMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'If parameter %1 is set to %2, parameter %3 is not supported';"),
			"IdleParameters.OutputIdleWindow",
			"True",
			"IdleParameters.ExecutionProgressNotification");
			
		CommonClientServer.Validate(Not (IdleParameters.ExecutionProgressNotification <> Undefined And IdleParameters.OutputIdleWindow), 
			VerificationMessage, "TimeConsumingOperationsClient.WaitCompletion");
			
	EndIf;

EndProcedure

Procedure ShowNotification(UserNotification, FormOwner = Undefined) Export
	
	Notification = UserNotification;
	If Not Notification.Show Then
		Return;
	EndIf;
	
	NotificationURL = Notification.URL;
	NotificationComment = Notification.Explanation;
	
	If FormOwner <> Undefined And FormOwner.Window <> Undefined Then
		If NotificationURL = Undefined Then
			NotificationURL = FormOwner.Window.GetURL();
		EndIf;
		If NotificationComment = Undefined Then
			NotificationComment = FormOwner.Window.Title;
		EndIf;
	EndIf;
	
	AlertStatus = Undefined;
	If TypeOf(Notification.Important) = Type("Boolean") Then
		AlertStatus = ?(Notification.Important, UserNotificationStatus.Important, UserNotificationStatus.Information);
	EndIf;
	
	ShowUserNotification(?(Notification.Text <> Undefined, Notification.Text, NStr("en = 'Operation completed.';")), 
		NotificationURL, NotificationComment, Notification.Picture, AlertStatus);

EndProcedure

#EndRegion