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
	
	SetConditionalAppearance();
	
	EventLogFilter = New Structure;
	DefaultEventLogFilter = New Structure;
	FilterValues = GetEventLogFilterValues("Event").Event;
	
	If Not IsBlankString(Parameters.User) Then
		If TypeOf(Parameters.User) = Type("ValueList") Then
			FilterByUser = Parameters.User;
		Else
			UserName = Parameters.User;
			FilterByUser = New ValueList;
			FilterByUser.Add(UserName, UserName);
		EndIf;
		EventLogFilter.Insert("User", FilterByUser);
	EndIf;
	
	If ValueIsFilled(Parameters.EventLogEvent) Then
		FilterByEvent = New ValueList;
		If TypeOf(Parameters.EventLogEvent) = Type("Array") Then
			For Each Event In Parameters.EventLogEvent Do
				EventPresentation = FilterValues[Event];
				FilterByEvent.Add(Event, EventPresentation);
			EndDo;
		Else
			FilterByEvent.Add(Parameters.EventLogEvent, Parameters.EventLogEvent);
		EndIf;
		EventLogFilter.Insert("Event", FilterByEvent);
	EndIf;
	
	EventLogFilter.Insert("StartDate", 
		?(ValueIsFilled(Parameters.StartDate), Parameters.StartDate, BegOfDay(CurrentSessionDate())));
	EventLogFilter.Insert("EndDate", 
		?(ValueIsFilled(Parameters.EndDate), Parameters.EndDate, EndOfDay(CurrentSessionDate())));
	
	If Parameters.Data <> Undefined Then
		EventLogFilter.Insert("Data", Parameters.Data);
	EndIf;
	
	If Parameters.Session <> Undefined Then
		EventLogFilter.Insert("Session", Parameters.Session);
	EndIf;
	
	// Level - value list.
	If Parameters.Level <> Undefined Then
		FilterByLevel = New ValueList;
		If TypeOf(Parameters.Level) = Type("Array") Then
			For Each LevelPresentation In Parameters.Level Do
				FilterByLevel.Add(LevelPresentation, LevelPresentation);
			EndDo;
		ElsIf TypeOf(Parameters.Level) = Type("String") Then
			FilterByLevel.Add(Parameters.Level, Parameters.Level);
		Else
			FilterByLevel = Parameters.Level;
		EndIf;
		EventLogFilter.Insert("Level", FilterByLevel);
	EndIf;
	
	// ApplicationName - value list.
	If Parameters.ApplicationName <> Undefined Then
		ApplicationsList = New ValueList;
		For Each Package In Parameters.ApplicationName Do
			ApplicationsList.Add(Package, ApplicationPresentation(Package));
		EndDo;
		EventLogFilter.Insert("ApplicationName", ApplicationsList);
	EndIf;
	
	EventsCountLimit = 200;
	
	If Common.IsWebClient() Or Common.IsMobileClient() Then
		ItemToRemove = Items.EventsCountLimit.ChoiceList.FindByValue(10000);
		Items.EventsCountLimit.ChoiceList.Delete(ItemToRemove);
		Items.EventsCountLimit.MaxValue = 1000;
	EndIf;
	
	FilterDefault = FilterDefault(FilterValues);
	If Not EventLogFilter.Property("Event") Then
		EventLogFilter.Insert("Event", FilterDefault);
	EndIf;
	DefaultEventLogFilter.Insert("Event", FilterDefault);
	Items.SessionDataSeparationPresentation.Visible = Not Common.SeparatedDataUsageAvailable();
	
	Severity = "AllEvents";
	
	// Switched to True if the event log must not be generated in background.
	ShouldNotRunInBackground = Parameters.ShouldNotRunInBackground;
	
	If Common.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"TitleLocation",		FormItemTitleLocation.None);
		CommonClientServer.SetFormItemProperty(Items, "Severity",	"ChoiceButton",				True);
		CommonClientServer.SetFormItemProperty(Items, "Log", 		"CommandBarLocation", FormItemCommandBarLabelLocation.None);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Data.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.Data");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataPresentation.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Log.MetadataPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshCurrentList", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EventsCountLimitOnChange(Item)
	
#If WebClient Or MobileClient Then
	EventsCountLimit = ?(EventsCountLimit > 1000, 1000, EventsCountLimit);
#EndIf
	
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure SeverityOnChange(Item)
	
	EventLogFilter.Delete("Level");
	FilterByLevel = New ValueList;
	If Severity = "Error" Then
		FilterByLevel.Add("Error", "Error");
	ElsIf Severity = "Warning" Then
		FilterByLevel.Add("Warning", "Warning");
	ElsIf Severity = "Information" Then
		FilterByLevel.Add("Information", "Information");
	ElsIf Severity = "Note" Then
		FilterByLevel.Add("Note", "Note");
	EndIf;
	
	If FilterByLevel.Count() > 0 Then
		EventLogFilter.Insert("Level", FilterByLevel);
	EndIf;
	
	RefreshCurrentList();
EndProcedure

#EndRegion

#Region LogFormTableItemEventHandlers

&AtClient
Procedure LogSelection(Item, RowSelected, Field, StandardProcessing)
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("CurrentData", Items.Log.CurrentData);
	ChoiceParameters.Insert("Field", Field);
	ChoiceParameters.Insert("DateInterval", DateInterval);
	ChoiceParameters.Insert("EventLogFilter", EventLogFilter);
	ChoiceParameters.Insert("DataStorage", DataStorage);
	
	EventLogClient.EventsChoice(ChoiceParameters);
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Structure") And ValueSelected.Property("Event") Then
		
		If ValueSelected.Event = "EventLogFilterSet" Then
			
			EventLogFilter.Clear();
			For Each ListItem In ValueSelected.Filter Do
				EventLogFilter.Insert(ListItem.Presentation, ListItem.Value);
			EndDo;
			
			If EventLogFilter.Property("Level") Then
				If EventLogFilter.Level.Count() > 0 Then
					Severity = String(EventLogFilter.Level);
				EndIf;
			Else
				Severity = "AllEvents";
			EndIf;
			
			RefreshCurrentList();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RefreshCurrentList()
	
	Items.Pages.CurrentPage = Items.TimeConsumingOperationProgress;
	CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "ReportGeneration");
	
	ExecutionResult = ReadEventLog();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CompletionNotification2 = New NotifyDescription("RefreshCurrentListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(ExecutionResult, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtClient
Procedure RefreshCurrentListCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		LoadPreparedData(Result.ResultAddress);
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
	ElsIf Result.Status = "Error" Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		MoveToListEnd();
		Raise Result.BriefErrorDescription;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFilter()
	
	EventLogFilter = DefaultEventLogFilter;
	Severity = "AllEvents";
	RefreshCurrentList();
	
EndProcedure

&AtClient
Procedure OpenDataForViewing()
	
	EventLogClient.OpenDataForViewing(Items.Log.CurrentData);
	
EndProcedure

&AtClient
Procedure ViewCurrentEventInNewWindow()
	
	EventLogClient.ViewCurrentEventInNewWindow(Items.Log.CurrentData, DataStorage);
	
EndProcedure

&AtClient
Procedure SetPeriodForViewing()
	
	Notification = New NotifyDescription("SetPeriodForViewingCompletion", ThisObject);
	EventLogClient.SetPeriodForViewing(DateInterval, EventLogFilter, Notification)
	
EndProcedure

&AtClient
Procedure SetFilter()
	
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure FilterPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SetFilterOnClient();
	
EndProcedure

&AtClient
Procedure SetFilterByValueInCurrentColumn()
	
	ExcludeColumns = New Array;
	ExcludeColumns.Add("Date");
	
	If EventLogClient.SetFilterByValueInCurrentColumn(
			Items.Log.CurrentData,
			Items.Log.CurrentItem,
			EventLogFilter,
			ExcludeColumns) Then
		
		RefreshCurrentList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportLogForTechnicalSupport(Command)
	
	FileSavingParameters = FileSystemClient.FileSavingParameters();
	FileSavingParameters.Dialog.Filter = NStr("en = 'Event Log data';") + "(*.xml)|*.xml";
	FileSystemClient.SaveFile(Undefined, ExportRegistrationLog(), "EventLog.xml", FileSavingParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetPeriodForViewingCompletion(IntervalSet, AdditionalParameters) Export
	
	If IntervalSet Then
		RefreshCurrentList();
	EndIf;
	
EndProcedure

&AtServer
Function FilterDefault(EventsList)
	
	FilterDefault = New ValueList;
	
	For Each LogEvent In EventsList Do
		
		If LogEvent.Key = "_$Transaction$_.Commit"
			Or LogEvent.Key = "_$Transaction$_.Begin"
			Or LogEvent.Key = "_$Transaction$_.Rollback" Then
			Continue;
		EndIf;
		
		FilterDefault.Add(LogEvent.Key, LogEvent.Value);
		
	EndDo;
	
	Return FilterDefault;
EndFunction

&AtServer
Function ReadEventLog()
	
	If ValueIsFilled(JobID) Then
		TimeConsumingOperations.CancelJobExecution(JobID);
	EndIf;
	
	StartDate    = Undefined; // Date
	EndDate = Undefined; // Date
	FilterDatesSpecified = EventLogFilter.Property("StartDate", StartDate) And EventLogFilter.Property("EndDate", EndDate)
		And ValueIsFilled(StartDate) And ValueIsFilled(EndDate);
		
	If FilterDatesSpecified And StartDate > EndDate Then
		CommonClientServer.SetSpreadsheetDocumentFieldState(Items.TimeConsumingOperationProgressField, "DontUse");
		Items.Pages.CurrentPage = Items.EventLog;
		Raise NStr("en = 'Incorrect event log filter settings. 
			|The start date cannot be later than the end date.';");
	EndIf;
	
	ReportParameters = ReportParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0; // 
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Updating event log';");
	ExecutionParameters.RunNotInBackground1 = ShouldNotRunInBackground;
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground("EventLog.ReadEventLogEvents",
		ReportParameters, ExecutionParameters);
	
	If ExecutionResult.Status = "Error" Then
		Items.Pages.CurrentPage = Items.EventLog;
		Raise ExecutionResult.BriefErrorDescription;
	EndIf;
	JobID = ExecutionResult.JobID;
	
	EventLog.GenerateFilterPresentation(FilterPresentation, EventLogFilter, DefaultEventLogFilter);
	
	Return ExecutionResult;
	
EndFunction

&AtServer
Function ReportParameters()
	ReportParameters = New Structure;
	ReportParameters.Insert("EventLogFilter", EventLogFilter);
	ReportParameters.Insert("EventsCountLimit", EventsCountLimit);
	ReportParameters.Insert("UUID", UUID);
	ReportParameters.Insert("OwnerManager", DataProcessors.EventLog);
	ReportParameters.Insert("AddAdditionalColumns", False);
	ReportParameters.Insert("Log", FormAttributeToValue("Log"));

	Return ReportParameters;
EndFunction

&AtServer
Procedure LoadPreparedData(ResultAddress)
	Result      = GetFromTempStorage(ResultAddress);
	LogEvents = Result.LogEvents;
	
	If DataStorage = Undefined Then
		Address = UUID;
	Else
		Address = DataStorage;
	EndIf;
	DataStorage = PutToTempStorage(New Map, Address);
	EventLog.PutDataInTempStorage(LogEvents, DataStorage);
	
	ValueToFormData(LogEvents, Log);
EndProcedure

&AtClient
Procedure MoveToListEnd()
	If Log.Count() > 0 Then
		Items.Log.CurrentRow = Log[Log.Count() - 1].GetID();
	EndIf;
EndProcedure 

&AtClient
Procedure SetFilterOnClient()
	
	FilterForms = New ValueList;
	For Each KeyAndValue In EventLogFilter Do
		FilterForms.Add(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	OpenForm(
		"DataProcessor.EventLog.Form.EventLogFilter", 
		New Structure("Filter, DefaultEvents", FilterForms, DefaultEventLogFilter.Event), 
		ThisObject);
	
EndProcedure

&AtClient
Procedure SeverityClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtServer
Function ExportRegistrationLog()
	Return EventLog.TechnicalSupportLog(EventLogFilter, EventsCountLimit, UUID);
EndFunction

#EndRegion
