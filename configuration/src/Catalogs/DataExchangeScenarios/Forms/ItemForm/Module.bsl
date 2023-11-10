///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var NumberOfRowToProcess;

&AtClient
Var RowsCount;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = (Object.Ref.IsEmpty());
	
	InfobaseNode = Undefined;
	
	If IsNew
		And Parameters.Property("InfobaseNode", InfobaseNode)
		And InfobaseNode <> Undefined Then
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(Object, InfobaseNode);
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(Object, InfobaseNode);
		
		Description = NStr("en = 'Synchronization scenario for %1';");
		Object.Description = StringFunctionsClientServer.SubstituteParametersToString(Description, String(InfobaseNode));
		
		JobSchedule = Catalogs.DataExchangeScenarios.DefaultJobSchedule();
		
		Object.UseScheduledJob = True;
	Else
		// 
		// 
		JobSchedule = Catalogs.DataExchangeScenarios.GetDataExchangeExecutionSchedule(Object.Ref);
	EndIf;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	If DataSeparationEnabled Then
		
		ToolTipText = NStr("en = 'Minimum interval must be over 15 minutes (900 seconds).
                              |The exact scenario execution time depends on the application workload.';");
		
		Items.ConfigureJobSchedule.ExtendedTooltip.Title = ToolTipText;
		Items.ConfigureJobSchedule.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
		Items.ExchangeSettingsExchangeTransportKind.Visible = False;
		Items.ExchangeSettingsInfobaseNode.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		Items.ExchangeSettingsInfobaseNode.DropListButton = False;
		
	EndIf;
		
	If Not IsNew Then
		RefreshDataExchangesStates();
	EndIf;
	
	SSLExchangePlans = DataExchangeCached.SSLExchangePlans();
	For Each ExchangePlanName In SSLExchangePlans Do
		ExchangeNodesList.Add(Type("ExchangePlanRef." + ExchangePlanName));
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSchedulePresentation();
	
	SetScheduleSetupHyperlinkAvailability();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	ValidateExchangeSettingInService(Cancel);
		
	Catalogs.DataExchangeScenarios.UpdateScheduledJobData(Cancel, JobSchedule, CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DataExchangeScenarios", WriteParameters, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseScheduledJobOnChange(Item)
	
	SetScheduleSetupHyperlinkAvailability();
	
EndProcedure

&AtClient
Procedure ScheduleCompositionOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeTransportKindChoiceList(Item.ChildItems.ExchangeSettingsExchangeTransportKind.ChoiceList, Item.CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeOnChange(Item)
	
	If DataSeparationEnabled Then
		Items.ScheduleComposition.CurrentData.ExchangeTransportKind = 
			PredefinedValue("Enum.ExchangeMessagesTransportTypes.WS");
	Else	
		Items.ScheduleComposition.CurrentData.ExchangeTransportKind = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If DataSeparationEnabled Then
		
		ChoiceInitialValue = Items.ScheduleComposition.CurrentData.InfobaseNode;
		FormParameters = New Structure("ChoiceInitialValue", ChoiceInitialValue);
		
		StandardProcessing = False;
		OpenForm("Catalog.DataExchangeScenarios.Form.SelectExchangePlanNode", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region ExchangeSettingsFormTableItemEventHandlers

&AtClient
Procedure ExchangeSettingsExchangeTransportKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FillExchangeTransportKindChoiceList(Item.ChoiceList, CurrentData.InfobaseNode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeSettingsInfobaseNodeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) = Type("Type") And ExchangeNodesList.FindByValue(ValueSelected) = Undefined Then
		MessageText = NStr("en = 'Cannot use data of this type in this form.
			|Please select another data type.';");
		Field = StringFunctionsClientServer.SubstituteParametersToString("ExchangeSettings[%1].InfobaseNode", Items.ScheduleComposition.CurrentData.LineNumber-1);
		CommonClient.MessageToUser(MessageText, , Field, "Object");
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteExchange(Command)
	
	IsNew = (Object.Ref.IsEmpty());
	
	If Modified Or IsNew Then
		
		Write();
		
	EndIf;
	
	NumberOfRowToProcess     = 1;
	RowsCount = Object.ExchangeSettings.Count();
	
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtClient
Procedure ConfigureJobSchedule(Command)
	
	EditScheduledJobSchedule();
	
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure TransportSettings(Command)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	ElsIf Not ValueIsFilled(CurrentData.InfobaseNode) Then
		Return;
	EndIf;
	
	Filter              = New Structure("Peer", CurrentData.InfobaseNode);
	FillingValues = New Structure("Peer", CurrentData.InfobaseNode);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", ThisObject);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	CurrentData = Items.ScheduleComposition.CurrentData;
	
	If CurrentData = Undefined
		Or Not ValueIsFilled(CurrentData.InfobaseNode) Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode,
																	ThisObject,
																	CurrentData.CurrentAction);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure EditScheduledJobSchedule()
	
	// Creating a new schedule if it is not initialized in a form on the server.
	If JobSchedule = Undefined Then
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	// Opening a dialog box for editing the schedule.
	NotifyDescription = New NotifyDescription("EditScheduledJobScheduleCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure EditScheduledJobScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		If DataSeparationEnabled 
			And Schedule.RepeatPeriodInDay < 15*60 Then
			
			Schedule.RepeatPeriodInDay = 15*60;
			WarningText = NStr("en = 'Minimum interval must be over 15 minutes (900 seconds).';");
			ShowMessageBox(, WarningText);
			
		EndIf;
		
		JobSchedule = Schedule;
		RefreshSchedulePresentation();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	SchedulePresentation = String(JobSchedule);
	
	If SchedulePresentation = String(New JobSchedule) Then
		
		SchedulePresentation = NStr("en = 'No schedule';");
		
	EndIf;
	
	Items.ConfigureJobSchedule.Title = SchedulePresentation;
	
EndProcedure

&AtClient
Procedure SetScheduleSetupHyperlinkAvailability()
	
	Items.ConfigureJobSchedule.Enabled = Object.UseScheduledJob;
	
EndProcedure

&AtClient
Procedure ExecuteDataExchangeAtClient()
	
	If NumberOfRowToProcess > RowsCount Then // выход of рекурсии
		OutputState = (RowsCount > 1);
		Status(NStr("en = 'Data is synchronized.';"), ?(OutputState, 100, Undefined));
		Return; // Exit.
	EndIf;
	
	CurrentData = Object.ExchangeSettings[NumberOfRowToProcess - 1];
	
	OutputState = (RowsCount > 1);
	
	MessageString = "";
	If CurrentData.CurrentAction = PredefinedValue("Enum.ActionsOnExchange.DataImport") Then
		MessageString = NStr("en = 'Receiving data from %1.';");
	ElsIf CurrentData.CurrentAction = PredefinedValue("Enum.ActionsOnExchange.DataExport") Then
		MessageString = NStr("en = 'Sending data to %1.';");
	EndIf;
	
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, 
		CurrentData.InfobaseNode);
	
	Progress = Round(100 * (NumberOfRowToProcess -1) / ?(RowsCount = 0, 1, RowsCount));
	Status(MessageString, ?(OutputState, Progress, Undefined));
	
	// Starting data exchange by setting string.
	ExecuteDataExchangeBySettingString(NumberOfRowToProcess);
	
	UserInterruptProcessing();
	
	NumberOfRowToProcess = NumberOfRowToProcess + 1;
	
	// Calling this procedure recursively.
	AttachIdleHandler("ExecuteDataExchangeAtClient", 0.1, True);
	
EndProcedure

&AtServer
Procedure RefreshDataExchangesStates()
	
	SetPrivilegedMode(True);
	
	QueryText = "
	|SELECT
	|	DataExchangeScenariosExchangeSettings.InfobaseNode,
	|	DataExchangeScenariosExchangeSettings.ExchangeTransportKind,
	|	DataExchangeScenariosExchangeSettings.CurrentAction,
	|	CASE
	|	WHEN DataExchangesStates.ExchangeExecutionResult IS NULL
	|	THEN 0
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
	|	THEN 2
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|	THEN 2
	|	WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed2)
	|	THEN 0
	|	ELSE 1
	|	END AS ExchangeExecutionResult
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenariosExchangeSettings
	|LEFT JOIN InformationRegister.DataExchangesStates AS DataExchangesStates
	|	ON DataExchangesStates.InfobaseNode = DataExchangeScenariosExchangeSettings.InfobaseNode
	|	 AND DataExchangesStates.ActionOnExchange      = DataExchangeScenariosExchangeSettings.CurrentAction
	|WHERE
	|	DataExchangeScenariosExchangeSettings.Ref = &Ref
	|ORDER BY
	|	DataExchangeScenariosExchangeSettings.LineNumber ASC
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object.Ref);
	
	Object.ExchangeSettings.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure ExecuteDataExchangeBySettingString(Val IndexOf)
	
	Cancel = False;
	
	// 
	DataExchangeServer.ExecuteDataExchangeByDataExchangeScenario(Cancel, Object.Ref, IndexOf);
	
	// Updating tabular section data of the data exchange scenario.
	RefreshDataExchangesStates();
	
EndProcedure

&AtClient
Procedure FillExchangeTransportKindChoiceList(ChoiceList, InfobaseNode)
	
	ChoiceList.Clear();
	
	If ValueIsFilled(InfobaseNode) Then
		
		For Each Item In UsedExchangeMessagesTransports(InfobaseNode) Do
			
			ChoiceList.Add(Item, String(Item));
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UsedExchangeMessagesTransports(Val InfobaseNode)
	
	Return DataExchangeCached.UsedExchangeMessagesTransports(InfobaseNode);
	
EndFunction

&AtServer
Procedure ValidateExchangeSettingInService(Cancel)
	
	If DataSeparationEnabled Then
		
		ExchangeSettings = Object.ExchangeSettings.Unload();
		ExchangeSettings.GroupBy("InfobaseNode,ExchangeTransportKind,CurrentAction");
		Object.ExchangeSettings.Load(ExchangeSettings);
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	ExchangeSettings.InfobaseNode AS InfobaseNode,
			|	ExchangeSettings.CurrentAction AS CurrentAction
			|INTO TT_ExchangeSettings
			|FROM
			|	&ExchangeSettings AS ExchangeSettings
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TT_ExchangeSettings.InfobaseNode AS InfobaseNode
			|INTO TT_Load
			|FROM
			|	TT_ExchangeSettings AS TT_ExchangeSettings
			|WHERE
			|	TT_ExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataImport)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TT_ExchangeSettings.InfobaseNode AS InfobaseNode
			|INTO TT_Upload0
			|FROM
			|	TT_ExchangeSettings AS TT_ExchangeSettings
			|WHERE
			|	TT_ExchangeSettings.CurrentAction = VALUE(Enum.ActionsOnExchange.DataExport)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ISNULL(TT_Upload0.InfobaseNode, TT_Load.InfobaseNode) AS InfobaseNode,
			|	CASE
			|		WHEN TT_Upload0.InfobaseNode IS NULL
			|			THEN 1
			|		WHEN TT_Load.InfobaseNode IS NULL
			|			THEN 2
			|	END AS MissingAction
			|FROM
			|	TT_Load AS TT_Load
			|		FULL JOIN TT_Upload0 AS TT_Upload0
			|		ON TT_Load.InfobaseNode = TT_Upload0.InfobaseNode
			|WHERE
			|	(TT_Upload0.InfobaseNode IS NULL
			|			OR TT_Load.InfobaseNode IS NULL)";
		
		Query.SetParameter("ExchangeSettings", ExchangeSettings);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			Cancel = True;
			
			Selection = Result.Select();
			
			While Selection.Next() Do
				
				If Selection.MissingAction = 1 Then
					MessageTemplate = NStr("en = 'An action to send data is missing for infobase ""%1""';");
				Else
					MessageTemplate = NStr("en = 'An action to receive data is missing for infobase ""%1""';");
				EndIf;
				
				MessageText = StrTemplate(MessageTemplate, Selection.InfobaseNode);
				
				Common.MessageToUser(MessageText);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
