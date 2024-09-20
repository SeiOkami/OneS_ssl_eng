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
	
	ShowWarningOnFormClose = True;
	
	// Checking whether the form is opened from 1C:Enterprise script.
	If Not Parameters.Property("ExchangeMessageFileName") Then
		
		NString = NStr("en = 'The form cannot be opened interactively.';");
		Common.MessageToUser(NString,,,, Cancel);
		Return;
		
	EndIf;
	
	// Initializing the data processor with the passed parameters.
	FillPropertyValues(Object, Parameters,, "UsedFieldsList, TableFieldsList");
	
	MaxUserFields         = Parameters.MaxUserFields;
	UnapprovedMappingTableTempStorageAddress = Parameters.UnapprovedMappingTableTempStorageAddress;
	UsedFieldsList  = Parameters.UsedFieldsList;
	TableFieldsList       = Parameters.TableFieldsList;
	MappingFieldsList = Parameters.MappingFieldsList;
	
	Parameters.Property("Title", Title);
	
	AutomaticObjectMappingScenario();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	NavigationNumber = 0;
	
	// Selecting the second wizard step.
	SetNavigationNumber(2);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Object.AutomaticallyMappedObjectsTable.Count() = 0
		Or ShowWarningOnFormClose <> True Then
		Return;
	EndIf;
			
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	ShowMessageBox(, NStr("en = 'The form contains automatic mapping data. The action is canceled.';"));
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	ShowWarningOnFormClose = False;
	
	// Context server call.
	NotifyChoice(PutAutomaticallyMappedObjectsTableInTempStorage());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ShowWarningOnFormClose = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

&AtClient
Procedure ClearCheckBoxes(Command)
	
	SetAllMarksAtServer(False);
	
EndProcedure

&AtClient
Procedure SelectCheckBoxes(Command)
	
	SetAllMarksAtServer(True);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	ShowWarningOnFormClose = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeNavigationNumber(Iterator_SSLy)
	
	ClearMessages();
	
	SetNavigationNumber(NavigationNumber + Iterator_SSLy);
	
EndProcedure

&AtClient
Procedure SetNavigationNumber(Val Value)
	
	IsMoveNext = (Value > NavigationNumber);
	
	NavigationNumber = Value;
	
	If NavigationNumber < 0 Then
		
		NavigationNumber = 0;
		
	EndIf;
	
	NavigationNumberOnChange(IsMoveNext);
	
EndProcedure

&AtClient
Procedure NavigationNumberOnChange(Val IsMoveNext)
	
	// Executing navigation event handlers.
	ExecuteNavigationEventHandlers(IsMoveNext);
	
	// Setting page view.
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	Items.PanelMain.CurrentPage = Items[NavigationRowCurrent.MainPageName];
	
	If IsMoveNext And NavigationRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteNavigationEventHandlers(Val IsMoveNext)
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	If NavigationRowCurrent.TimeConsumingOperation And Not IsMoveNext Then
		
		SetNavigationNumber(NavigationNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(NavigationRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, SkipPage, IsMoveNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		CalculationResult = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsMoveNext Then
				
				SetNavigationNumber(NavigationNumber + 1);
				
				Return;
				
			Else
				
				SetNavigationNumber(NavigationNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTimeConsumingOperationHandler()
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	// TimeConsumingOperationProcessing handler.
	If Not IsBlankString(NavigationRowCurrent.TimeConsumingOperationHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.TimeConsumingOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		CalculationResult = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetNavigationNumber(NavigationNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetNavigationNumber(NavigationNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure NavigationTableNewRow(NavigationNumber,
									MainPageName,
									OnOpenHandlerName = "",
									TimeConsumingOperation = False,
									TimeConsumingOperationHandlerName = "")
	NewRow = NavigationTable.Add();
	
	NewRow.NavigationNumber = NavigationNumber;
	NewRow.MainPageName = MainPageName;
	
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = TimeConsumingOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
EndProcedure

&AtServer
Function PutAutomaticallyMappedObjectsTableInTempStorage()
	
	Return PutToTempStorage(Object.AutomaticallyMappedObjectsTable.Unload(New Structure("Check", True), "DestinationUUID, SourceUUID, SourceType, DestinationType"));
	
EndFunction

&AtServer
Procedure SetTableFieldVisible(Val FormTableName, Val MaxUserFieldsCount)
	
	SourceFieldName2 = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	DestinationFieldName1 = StrReplace("#FormTableName#DestinationFieldNN","#FormTableName#", FormTableName);
	
	// Making all mapping table fields invisible.
	For FieldNumber = 1 To MaxUserFieldsCount Do
		
		SourceField = StrReplace(SourceFieldName2, "NN", String(FieldNumber));
		DestinationField = StrReplace(DestinationFieldName1, "NN", String(FieldNumber));
		
		ItemSourceField = Items[SourceField]; // FormField
		ItemDestinationField = Items[DestinationField]; // FormField
		
		ItemSourceField.Visible = False;
		ItemDestinationField.Visible = False;
		
	EndDo;
	
	// Making all mapping table fields that are selected by user visible.
	For Each Item In Object.UsedFieldsList Do
		
		FieldNumber = Object.UsedFieldsList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName2, "NN", String(FieldNumber));
		DestinationField = StrReplace(DestinationFieldName1, "NN", String(FieldNumber));
		
		ItemSourceField = Items[SourceField]; // FormField
		ItemDestinationField = Items[DestinationField]; // FormField
		
		// 
		ItemSourceField.Visible = Item.Check;
		ItemDestinationField.Visible = Item.Check;
		
		// 
		ItemSourceField.Title = Item.Presentation;
		ItemDestinationField.Title = Item.Presentation;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAllMarksAtServer(Check)
	
	ValueTable = Object.AutomaticallyMappedObjectsTable.Unload();
	
	ValueTable.FillValues(Check, "Check");
	
	Object.AutomaticallyMappedObjectsTable.Load(ValueTable);
	
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeNavigationNumber(-1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure BackgroundJobIdleHandler()
	
	TimeConsumingOperationCompleted = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	ElsIf State = "Completed" Then
		
		TimeConsumingOperation = False;
		TimeConsumingOperationCompleted = True;
		
		GoToNext();
		
	Else // Failed
		
		TimeConsumingOperation = False;
		
		GoBack();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

// Page 1: Automatic object mapping error.
//
&AtClient
Function Attachable_ObjectMappingErrorOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.Close1.DefaultButton = True;
	
	Return Undefined;
	
EndFunction

// Page 2 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWaitingTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	TimeConsumingOperation          = False;
	TimeConsumingOperationCompleted = True;
	JobID        = Undefined;
	TempStorageAddress    = "";
	
	Result = BackgroundJobStartAtServer(Cancel);
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	If Result.Status = "Running" Then
		
		GoToNext                = False;
		TimeConsumingOperation          = True;
		TimeConsumingOperationCompleted = False;
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.OutputMessages    = True;
		
		CompletionNotification2 = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(Result, CompletionNotification2, IdleParameters);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Page 2 Handler of background job completion notification.
&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	
	TimeConsumingOperation          = False;
	TimeConsumingOperationCompleted = True;
	
	If Result = Undefined Then
		GoBack();
	ElsIf Result.Status = "Error" Or Result.Status = "Canceled" Then
		RecordError(Result.DetailErrorDescription);
		GoBack();
	Else
		GoToNext();
	EndIf;
	
EndProcedure

// Page 3 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWaitingTimeConsumingOperationCompletionTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If TimeConsumingOperationCompleted Then
		
		ExecuteObjectMappingCompletion(Cancel);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Page 4: Operations with the automatic object mapping result.
//
&AtClient
Function Attachable_ObjectMappingOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.Apply.DefaultButton = True;
	
	If EmptyResult Then
		SkipPage = True;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Page 5: Empty result of automatic object mapping.
//
&AtClient
Function Attachable_EmptyObjectMappingResultEmptyObjectMappingResultOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.Close.DefaultButton = True;
	
	Return Undefined;
	
EndFunction

// Page 2: Object mapping.
//
&AtServer
Function BackgroundJobStartAtServer(Cancel)
	
	FormAttributes = New Structure;
	FormAttributes.Insert("UsedFieldsList",  UsedFieldsList);
	FormAttributes.Insert("TableFieldsList",       TableFieldsList);
	FormAttributes.Insert("MappingFieldsList", MappingFieldsList);
	
	JobParameters = New Structure;
	JobParameters.Insert("ObjectContext",             DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
	JobParameters.Insert("FormAttributes",              FormAttributes);
	JobParameters.Insert("UnapprovedMappingTable", GetFromTempStorage(UnapprovedMappingTableTempStorageAddress));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Automatic object mapping';");
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.InfobasesObjectsMapping.ExecuteAutomaticObjectMapping",
		JobParameters,
		ExecutionParameters);
		
	If Result = Undefined Then
		Cancel = True;
		Return Undefined;
	EndIf;
	
	JobID     = Result.JobID;
	TempStorageAddress = Result.ResultAddress;
	
	If Result.Status = "Error" Or Result.Status = "Canceled" Then
		Cancel = True;
		RecordError(Result.DetailErrorDescription);
	EndIf;
	
	Return Result;
	
EndFunction

// Page 3: Object mapping.
//
&AtServer
Procedure ExecuteObjectMappingCompletion(Cancel)
	
	Try
		AfterObjectMapping(GetFromTempStorage(TempStorageAddress));
	Except
		Cancel = True;
		RecordError(ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

&AtServer
Procedure AfterObjectMapping(Val MappingResult)
	
	DataProcessorObject = DataProcessors.InfobasesObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(MappingResult.ObjectContext, DataProcessorObject);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	EmptyResult = MappingResult.EmptyResult;
	
	If Not EmptyResult Then
		
		Modified = True;
		
		// Setting titles and table field visibility on the form.
		SetTableFieldVisible("AutomaticallyMappedObjectsTable", MaxUserFields);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecordError(DetailErrorDescription)
	WriteLogEvent(
		NStr("en = 'Object mapping wizard.Automatic object mapping';", Common.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,DetailErrorDescription);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure AutomaticObjectMappingScenario()
	
	NavigationTable.Clear();
	
	NavigationTableNewRow(1, "ObjectMappingError", "Attachable_ObjectMappingErrorOnOpen");
	
	// Waiting for object mapping.
	NavigationTableNewRow(2, "ObjectMappingWait",, True, "Attachable_ObjectMappingWaitingTimeConsumingOperationProcessing");
	NavigationTableNewRow(3, "ObjectMappingWait",, True, "Attachable_ObjectMappingWaitingTimeConsumingOperationCompletionTimeConsumingOperationProcessing");
	
	// Operations with the automatic object mapping result.
	NavigationTableNewRow(4, "ObjectsMapping", "Attachable_ObjectMappingOnOpen");
	NavigationTableNewRow(5, "EmptyObjectMappingResult", "Attachable_EmptyObjectMappingResultEmptyObjectMappingResultOnOpen");
	
EndProcedure

#EndRegion
