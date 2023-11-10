///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

// There are two ways to parameterize a form:
//
// Option 1
//     Параметры: 
//         УзелИнформационнойБазы             - ПланОбменаСсылка - узел плана обмена, для которого выполняется помощник.
//         РасширенныйРежимДополненияВыгрузки - Булево           - флаг включения механизма настройки дополнения
//                                                                 выгрузки по сценарию узла.
//
// Вариант 2:
//     Parameters: 
//         InfobaseNodeCode - String - Exchange plan node code, for which the wizard will be opened.
//         ExchangePlanName - String - Name of an exchange plan to use for searching an exchange plan node whose code is specified in the InfobaseNodeCode parameter.
//                                                                 ExportAdditionExtendedMode - Boolean - Flag indicating whether the export addition setup by node scenario is enabled.
//                                                                 
//         
//                                                                 
//
#Region Variables

&AtClient
Var SkipCurrentPageCancelControl;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsStartedFromAnotherApplication = False;
	
	If Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		
		Object.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Object.InfobaseNode);
		
	ElsIf Parameters.Property("InfobaseNodeCode") Then
		
		IsStartedFromAnotherApplication = True;
		
		Object.InfobaseNode = DataExchangeServer.ExchangePlanNodeByCode(
			Parameters.ExchangePlanName, Parameters.InfobaseNodeCode);
		
		If Not ValueIsFilled(Object.InfobaseNode) Then
			Raise NStr("en = 'The data exchange setting is not found.';");
		EndIf;
		
		Object.ExchangePlanName = Parameters.ExchangePlanName;
		
	Else
		
		Raise NStr("en = 'Cannot open this wizard directly.';");
		
	EndIf;
	
	// Interactive data exchange is supported only for universal exchanges.
	If Not DataExchangeCached.IsUniversalDataExchangeNode(Object.InfobaseNode) Then
		Raise NStr("en = 'The selected node does not support settings-based data exchange.';");
	EndIf;
	
	// Check whether exchange settings match the filter.
	AllNodes = DataExchangeEvents.AllExchangePlanNodes(Object.ExchangePlanName);
	If AllNodes.Find(Object.InfobaseNode) = Undefined Then
		Raise NStr("en = 'The selected node does not provide data mapping.';");
	EndIf;
	
	MessageReceivedForDataMapping = DataExchangeServer.MessageWithDataForMappingReceived(Object.InfobaseNode);
	
	If Not Parameters.Property("GetData", GetData) Then
		GetData = True;
	EndIf;
	
	If Not Parameters.Property("SendData", SendData) Then
		SendData = True;
	EndIf;
	
	If MessageReceivedForDataMapping Then
		SendData = False;
	EndIf;
	
	If Not GetData And Not SendData And Not MessageReceivedForDataMapping Then
		Raise NStr("en = 'The data synchronization scenario is not supported.';");
	EndIf;
	
	SaaSModel = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
		
	Parameters.Property("ExchangeMessagesTransportKind", Object.ExchangeMessagesTransportKind);	
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	Parameters.Property("ExportAdditionMode",            ExportAdditionMode);
	Parameters.Property("AdvancedExportAdditionMode", ExportAdditionExtendedMode);
	
	CheckVersionDifference = True;
	
	CorrespondentDescription = String(Object.InfobaseNode);
	
	SetFormHeader();
	
	Items.DeleteMessageForMappingDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'An error occurred while importing a message for mapping.
		|It is recommended that you export data from application ""%1"" again and start synchronization in this application.
		|You can also delete the message for mapping. In this case, synchronization runs in normal mode.';"),
		CorrespondentDescription);
	
	InitializeScheduleSetupWizard(IsStartedFromAnotherApplication);
	
	If ExportAdditionMode Then
		InitializeExportAdditionAttributes();
	EndIf;
	
	InitializeExchangeMessagesTransportSettings();
	
	If ExchangeViaInternalPublication Then
		ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
		HasNodeScheduledExchange = ModuleDataExchangeInternalPublication.HasNodeScheduledExchange(
			Object.InfobaseNode, 
			ScenarioUsingInternalPublication,
			IDOfExchangeViaInternalPublication);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetNavigationNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If ForceCloseForm Then
		Return;
	EndIf;

	CommonClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, Exit,
		NStr("en = 'Do you want to exit the wizard?';"), "ForceCloseForm");
		
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If TimeConsumingOperation Then
		EndExecutingTimeConsumingOperation(JobID);
	EndIf;
	
	If MessageReceivedForDataMapping And Not MappingCancellation Then
		If (EndDataMapping And Not SkipGettingData)
			Or (DataImportResult = "Warning_ExchangeMessageAlreadyAccepted")
			Or DeleteMessageForMapping Then
			DeleteMessageForDataMapping(Object.InfobaseNode, Object.ExchangeMessagesTransportKind);
		EndIf;
	EndIf;
	
	DeleteTempExchangeMessagesDirectory(Object.TempExchangeMessagesDirectoryName, TempDirectoryIDForExchange);
	
	If ValueIsFilled(FormReopeningParameters)
		And FormReopeningParameters.Property("NewDataSynchronizationSetting") Then
		
		NewDataSynchronizationSetting = FormReopeningParameters.NewDataSynchronizationSetting;
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", NewDataSynchronizationSetting);
		FormParameters.Insert("AdvancedExportAdditionMode", True);
		
		OpeningParameters = New Structure;
		OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
		
		DataExchangeClient.OpenFormAfterCloseCurrentOne(ThisObject,
			"DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, OpeningParameters);
		
	Else
		Notify("ObjectMappingWizardFormClosed");
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	// Check whether the additional export item initialization event occurred. 
	If DataExchangeClient.ExportAdditionChoiceProcessing(ValueSelected, ChoiceSource, ExportAddition) Then
		// Event is handled, updating filter details.
		SetExportAdditionFilterDescription();
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ObjectMappingFormClosing" Then
		
		Cancel = False;
		
		UpdateMappingStatisticsDataAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Error gathering statistic data.';"));
		Else
			
			ExpandStatisticsTree(Parameter.UniqueKey);
			
			ShowUserNotification(NStr("en = 'Information collection is complete';"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ExchangeMessagesTransportKindOnChange(Item)
	
	OnChangeExchangeMessagesTransportKind();
	
EndProcedure

&AtClient
Procedure ExchangeMessagesTransportKindClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DataExchangeDirectoryClick(Item)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure EndDataMappingOnChange(Item)
	
	OnChangeFlagEndDataMapping();
	
EndProcedure

&AtClient
Procedure LoadMessageAfterMappingOnChange(Item)
	
	OnChangeFlagImportMessageAfterMapping();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	ExportAdditionExportVariantSetVisibility();
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodOnChange(Item)
	ExportAdditionNodeScenarioPeriodChanging();
EndProcedure

&AtClient
Procedure ExportAdditionCommonDocumentsPeriodClearing(Item, StandardProcessing)
	// 
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodClearing(Item, StandardProcessing)
	// 
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region StatisticsInformationTreeFormTableItemEventHandlers

&AtClient
Procedure StatisticsInformationTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenMappingForm(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	MappingCancellation = True;
	Close();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	// 
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	Result = New Structure;
	Result.Insert("DataExportResult", DataExportResult);
	Result.Insert("DataImportResult", DataImportResult);
	
	ForceCloseForm = True;
	Close(Result);
	
EndProcedure

&AtClient
Procedure OpenScheduleSettings(Command)
	FormParameters = New Structure("InfobaseNode", Object.InfobaseNode);
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ContinueSync(Command)
	
	NavigationNumber = NavigationNumber - 1;
	SetNavigationNumber(NavigationNumber + 1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure OpenDataExchangeDirectory(Command)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

&AtClient
Procedure ConfigureExchangeMessagesTransportParameters(Command)
	
	Filter              = New Structure("Peer", Object.InfobaseNode);
	FillingValues = New Structure("Peer", Object.InfobaseNode);
	
	Notification = New NotifyDescription("ConfigureExchangeMessagesTransportParametersCompletion", ThisObject);
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", ThisObject, , , Notification);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure RefreshAllMappingInformation(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowsKeys = New Array;
	
	GetAllRowKeys(RowsKeys, StatisticsInformationTree.GetItems());
	
	If RowsKeys.Count() > 0 Then
		
		UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys);
		
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, NStr("en = 'Error gathering statistic data.';"));
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
		ShowUserNotification(NStr("en = 'Information collection is complete';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure RunDataImportForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsInformationTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		NString = NStr("en = 'Select a table name in the statistics field.';");
		CommonClient.MessageToUser(NString,,"StatisticsInformationTree",, Cancel);
		Return;
	EndIf;
	
	HasUnmappedObjects = False;
	For Each RowID In SelectedRows Do
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If IsBlankString(TreeRow.Key) Then
			Continue;
		EndIf;
		
		If TreeRow.UnmappedObjectsCount <> 0 Then
			HasUnmappedObjects = True;
			Break;
		EndIf;
	EndDo;
	
	If HasUnmappedObjects Then
		NString = NStr("en = 'Unmapped objects are found.
		                     |When you import the data, duplicates of these objects will be created. Do you want to continue?';");
		
		Notification = New NotifyDescription("ExecuteDataImportForRowQuestionUnmapped", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SelectedRows", SelectedRows);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(SelectedRows);
EndProcedure

&AtClient
Procedure OpenMappingForm(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("en = 'Object mapping cannot be performed for the data type.';"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("DestinationTableName",            CurrentData.DestinationTableName);
	FormParameters.Insert("SourceTableObjectTypeName", CurrentData.ObjectTypeString);
	FormParameters.Insert("DestinationTableFields",           CurrentData.TableFields);
	FormParameters.Insert("DestinationTableSearchFields",     CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeString",            CurrentData.SourceTypeString);
	FormParameters.Insert("DestinationTypeString",            CurrentData.DestinationTypeString);
	FormParameters.Insert("IsObjectDeletion",             CurrentData.IsObjectDeletion);
	FormParameters.Insert("DataImportedSuccessfully",         CurrentData.DataImportedSuccessfully);
	FormParameters.Insert("Key",                           CurrentData.Key);
	FormParameters.Insert("Synonym",                        CurrentData.Synonym);
	
	FormParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	
	OpenForm("DataProcessor.InfobasesObjectsMapping.Form", FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ExportAdditionGeneralDocumentsFilter(Command)
	DataExchangeClient.OpenExportAdditionFormAllDocuments(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilter(Command)
	DataExchangeClient.OpenExportAdditionFormDetailedFilter(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionFilterByNodeScenario(Command)
	DataExchangeClient.OpenExportAdditionFormNodeScenario(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionExportComposition(Command)
	DataExchangeClient.OpenExportAdditionFormDataComposition(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionClearGeneralFilter(Command)
	
	TitleText = NStr("en = 'Confirm operation';");
	QueryText   = NStr("en = 'Do you want to clear the common filter?';");
	NotifyDescription = New NotifyDescription("ExportAdditionClearGeneralFilterCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo,,,TitleText);
	
EndProcedure

&AtClient
Procedure ExportAdditionClearDetailedFilter(Command)
	TitleText = NStr("en = 'Confirm operation';");
	QueryText   = NStr("en = 'Do you want to clear the detailed filter?';");
	NotifyDescription = New NotifyDescription("ExportAdditionClearDetailedFilterCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

&AtClient
Procedure ExportAdditionFiltersHistory(Command)
	// Filling a menu list with all saved settings options.
	VariantList = ExportAdditionServerSettingsHistory();
	
	// Adding the option for saving the current settings.
	Text = NStr("en = 'Save current setting…';");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryMenuSelection", ThisObject);
	ShowChooseFromMenu(NotifyDescription, VariantList, Items.ExportAdditionFiltersHistory);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 
////////////////////////////////////////////////////////////////////////////////

#Region PartToSupply

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And Item.CommandName = CommandName Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure ExecuteMoveNext()
	
	ChangeNavigationNumber(+1);
	
EndProcedure

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
	
	Items.PanelMain.CurrentPage  = Items[NavigationRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[NavigationRowCurrent.NavigationPageName];
	
	Items.NavigationPanel.CurrentPage.Enabled = Not (IsMoveNext And NavigationRowCurrent.TimeConsumingOperation);
	
	// Setting the default button.
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		ConfirmButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If ConfirmButton <> Undefined Then
			
			ConfirmButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsMoveNext And NavigationRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteNavigationEventHandlers(Val IsMoveNext)
	
	// Navigation event handlers.
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() > 0 Then
			NavigationRow = NavigationRows[0];
		
			// OnNavigationToNextPage handler.
			If Not IsBlankString(NavigationRow.OnNavigationToNextPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnNavigationToNextPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetNavigationNumber(NavigationNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	Else
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber + 1));
		
		If NavigationRows.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
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
			
			If VersionDifferenceErrorOnGetData <> Undefined
				And VersionDifferenceErrorOnGetData.HasError Then
				
				ProcessVersionDifferenceError();
				Return;
				
			EndIf;
			
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
Procedure NavigationTableNewRow(
									MainPageName,
									NavigationPageName,
									OnOpenHandlerName = "",
									OnNavigationToNextPageHandlerName = "")
									
	NewRow = NavigationTable.Add();
	
	NewRow.NavigationNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.OnNavigationToNextPageHandlerName = OnNavigationToNextPageHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = False;
	NewRow.TimeConsumingOperationHandlerName = "";
	
EndProcedure

&AtServer
Procedure NavigationTableNewRowTimeConsumingOperation(
									MainPageName,
									NavigationPageName,
									TimeConsumingOperation = False,
									TimeConsumingOperationHandlerName = "",
									OnOpenHandlerName = "")
	
	NewRow = NavigationTable.Add();
	
	NewRow.NavigationNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.OnNavigationToNextPageHandlerName = "";
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = TimeConsumingOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// 
////////////////////////////////////////////////////////////////////////////////

#Region OverridablePart

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS SECTION

#Region ProceduresAndFuctionsOfProcessing

#Region ProceduresAndFunctionsClient

&AtClient
Procedure InitializeDataProcessorVariables()
	
	// Initialize data processor variables.
	ProgressPercent                   = 0;
	FileID                  = "";
	ProgressAdditionalInformation             = "";
	TempStorageAddress            = "";
	ErrorMessage                   = "";
	OperationID               = "";
	TimeConsumingOperation                  = False;
	TimeConsumingOperationCompleted         = True;
	TimeConsumingOperationCompletedWithError = False;
	JobID                = Undefined;
	
EndProcedure

&AtClient
Procedure ConfigureExchangeMessagesTransportParametersCompletion(ClosingResult, AdditionalParameters) Export
	
	InitializeExchangeMessagesTransportSettings();
	
EndProcedure

&AtClient
Procedure ExportAdditionFiltersHistoryCompletion(Response, SettingPresentation) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingPresentation);
		ExportAdditionExportVariantSetVisibility();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionClearGeneralFilterCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionClearGeneralFilterServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionClearDetailedFilterCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		ExportAdditionClearDetailedFilterServer();
	EndIf;
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryMenuSelection(Val SelectedElement, Val AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
		
	SettingPresentation = SelectedElement.Value;
	If TypeOf(SettingPresentation)=Type("String") Then
		// An option is selected, which is name of the setting saved earlier.
		
		TitleText = NStr("en = 'Confirm operation';");
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Do you want to restore ""%1"" settings?';"), SettingPresentation);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFiltersHistoryCompletion", ThisObject, SettingPresentation);
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo,,,TitleText);
		
	ElsIf SettingPresentation=1 Then
		// 
		DataExchangeClient.OpenExportAdditionFormSaveSettings(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowQuestionUnmapped(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(AdditionalParameters.SelectedRows);
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowContinued(Val SelectedRows) 

	RowsKeys = GetSelectedRowKeys(SelectedRows);
	If RowsKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Cancel = False;
	UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys, True);
	
	If Cancel Then
		NString = NStr("en = 'Errors occurred during data import.
		                     |Do you want to view the event log?';");
		
		NotifyDescription = New NotifyDescription("GoToEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
		
	ExpandStatisticsTree(RowsKeys[RowsKeys.UBound()]);
	ShowUserNotification(NStr("en = 'Data import completed.';"));
EndProcedure

&AtClient
Procedure OpenNodeDataExchangeDirectory()
	
	// Server call without context.
	DirectoryName = GetDirectoryNameAtServer(Object.ExchangeMessagesTransportKind, Object.InfobaseNode);
	
	If IsBlankString(DirectoryName) Then
		ShowMessageBox(, NStr("en = 'Data synchronization directory is not specified.';"));
		Return;
	EndIf;
	
	FileSystemClient.OpenExplorer(DirectoryName);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.PanelMain.CurrentPage             = Items.VersionsDifferenceErrorPage;
	Items.NavigationPanel.CurrentPage            = Items.NavigationPageVersionsDifferenceError;
	Items.ContinueSync.DefaultButton  = True;
	Items.DecorationVersionsDifferenceError.Title = VersionDifferenceErrorOnGetData.ErrorText;
	
	VersionDifferenceErrorOnGetData = Undefined;
	
	CheckVersionDifference = False;
	
EndProcedure

&AtClient
Procedure OnChangeFlagEndDataMapping()
	
	LoadMessageAfterMapping = EndDataMapping;
	
	Items.LoadMessageAfterMapping.Enabled = EndDataMapping;
	
	UpdateAvailabilityOfStatisticsInformationMoveCommand();
	UpdateTooltipTitleOfStatisticsInformationMove();
	
EndProcedure

&AtClient
Procedure OnChangeFlagImportMessageAfterMapping()
	
	UpdateAvailabilityOfStatisticsInformationMoveCommand();
	UpdateTooltipTitleOfStatisticsInformationMove();
	
EndProcedure

&AtClient
Procedure UpdateTooltipTitleOfStatisticsInformationMove()
	
	If MessageReceivedForDataMapping Then
		If EndDataMapping Then
			If LoadMessageAfterMapping Then
				Items.StatisticsDataNavigationTooltipDecoration.Title =
					NStr("en = 'Click Next to confirm the mapping and import the exchange message.';");
			Else
				Items.StatisticsDataNavigationTooltipDecoration.Title =
					NStr("en = 'Click ""Save and close"" to confirm the mapping and exit the wizard.';");
			EndIf;
		Else
			Items.StatisticsDataNavigationTooltipDecoration.Title =
				NStr("en = 'Click ""Save and close"" to confirm the mapping and exit the wizard.
				|You can continue editing the mapping next time you start the wizard.';");
		EndIf;
	Else
		Items.StatisticsDataNavigationTooltipDecoration.Title =
			NStr("en = 'Click Next to synchronize data.';");
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAvailabilityOfStatisticsInformationMoveCommand()
	
	Items.DoneCommand.Enabled = Not EndDataMapping Or Not LoadMessageAfterMapping;
	Items.DoneCommand.DefaultButton = EndDataMapping;
	
	Items.StatisticsInformationNextCommand.Enabled = EndDataMapping And LoadMessageAfterMapping;
	Items.StatisticsInformationNextCommand.DefaultButton = EndDataMapping And LoadMessageAfterMapping;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsServer

&AtServer
Procedure UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys, RunDataImport = False)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowsKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	If RunDataImport Then
		DataProcessorObject.RunDataImport(Cancel, RowIndexes);
	EndIf;
	
	// 
	DataProcessorObject.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	StatisticsInformation(DataProcessorObject.StatisticsTable());
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	
	AllDataMapped   = ModuleInteractiveExchangeWizard.AllDataMapped(DataProcessorObject.StatisticsTable());
	HasUnmappedMasterData = Not AllDataMapped And ModuleInteractiveExchangeWizard.HasUnmappedMasterData(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	If TableRows.Count() > 0 Then
		FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
		
		RowsKeys = New Array;
		RowsKeys.Add(NotificationParameters.UniqueKey);
		
		UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys);
	EndIf;
	
EndProcedure

&AtServer
Procedure StatisticsInformation(StatisticsInformation)
	
	TreeItemsCollection = StatisticsInformationTree.GetItems();
	TreeItemsCollection.Clear();
	
	Common.FillFormDataTreeItemCollection(TreeItemsCollection,
		DataExchangeServer.StatisticsInformation(StatisticsInformation));
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	Items.DataMappingStatusPages.CurrentPage = ?(AllDataMapped,
		Items.MappingStatusAllDataMapped,
		Items.MappingStatusUnmappedDataDetected);
	
EndProcedure

&AtServer
Procedure InitializeExchangeMessagesTransportSettings()
	
	TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(Object.InfobaseNode);
	DefaultTransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
	CorrespondentEndpoint = TransportSettings.WSCorrespondentEndpoint;
	
	ConfiguredTransportTypes = InformationRegisters.DataExchangeTransportSettings.ConfiguredTransportTypes(Object.InfobaseNode);
	
	SkipTransportPage = True;
	
	If ConfiguredTransportTypes.Count() > 1
		And Not ValueIsFilled(Object.ExchangeMessagesTransportKind) Then
		SkipTransportPage = ExportAdditionExtendedMode;
	EndIf;
	
	If Not ValueIsFilled(Object.ExchangeMessagesTransportKind) Then
		Object.ExchangeMessagesTransportKind = DefaultTransportKind;
	EndIf;
	
	StartDataExchangeFromCorrespondent = Not ValueIsFilled(Object.ExchangeMessagesTransportKind);
		
	ExchangeBetweenSaaSApplications = SaaSModel
		And (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
			Or Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP);

	ExchangeViaInternalPublication = SaaSModel
		And Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
		And ValueIsFilled(CorrespondentEndpoint);
		
	OnChangeExchangeMessagesTransportKind(True, ConfiguredTransportTypes);
	
EndProcedure

&AtServer
Procedure OnChangeExchangeMessagesTransportKind(Initialization = False, ConfiguredTransportTypes = Undefined)
	
	ExchangeOverExternalConnection = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM);
	ExchangeOverWebService         = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS);
	
	If ExchangeOverWebService Then
		SettingsStructure = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(Object.InfobaseNode);
		FillPropertyValues(ThisObject, SettingsStructure, "WSRememberPassword");
		If WSRememberPassword Then
			WSPassword = String(ThisObject.UUID);
		EndIf;
	EndIf;
	
	UseProgressBar = Not ExchangeOverWebService And Not ExchangeBetweenSaaSApplications And Not ExchangeViaInternalPublication;
	
	If Initialization Then
		SkipTransportPage = SkipTransportPage And (Not ExchangeOverWebService Or WSRememberPassword);
		FillNavigationTable();
		
		Items.ConfigureExchangeMessagesTransportParameters.Visible = DataExchangeServer.HasRightsToAdministerExchanges();
		
		DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfobaseNode,
			Items.ExchangeMessagesTransportKind, ConfiguredTransportTypes);
			
		TransportChoiceList = Items.ExchangeMessagesTransportKind.ChoiceList;
	
		If TransportChoiceList.Count() = 0 Then
			TransportChoiceList.Add(Undefined, NStr("en = 'no connections are configured';"));
			
			Items.ExchangeMessageTransportKindAsString.TextColor = StyleColors.ErrorNoteText
		Else
			Items.ExchangeMessageTransportKindAsString.TextColor = New Color;
		EndIf;
		
		Items.ExchangeMessageTransportKindAsString.Title = TransportChoiceList[0].Presentation;
		Items.ExchangeMessageTransportKindAsString.Visible = (TransportChoiceList.Count() = 1);
		Items.ExchangeMessagesTransportKind.Visible        = Not Items.ExchangeMessageTransportKindAsString.Visible;
		
		Items.WSPassword.Visible          = ExchangeOverWebService And Not WSRememberPassword;
		Items.WSPasswordLabel.Visible   = ExchangeOverWebService And Not WSRememberPassword;
	    Items.WSRememberPassword.Visible = ExchangeOverWebService And Not WSRememberPassword;
		
		SetExchangeDirectoryOpeningButtonVisible();
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeScheduleSetupWizard(IsStartedFromAnotherApplication)
	
	OpenDataExchangeScenarioCreationWizard = DataExchangeServer.HasRightsToAdministerExchanges();
	
	If IsStartedFromAnotherApplication Then
		OpenDataExchangeScenarioCreationWizard = False;
	ElsIf Parameters.Property("ScheduleSetup") Then
		OpenDataExchangeScenarioCreationWizard = Parameters.ScheduleSetup;
	EndIf;
	
	Items.ScheduleSettingsHelpText.Visible = OpenDataExchangeScenarioCreationWizard;
	
EndProcedure

&AtServer
Function GetStatisticsTableRowIndexes(RowsKeys)
	
	RowIndexes = New Array;
	
	For Each Var_Key In RowsKeys Do
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", Var_Key));
		
		RowIndex = Object.StatisticsInformation.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServer
Procedure SetExchangeDirectoryOpeningButtonVisible()
	
	ButtonVisibility = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP);
	
	Items.DataExchangeDirectory.Visible = ButtonVisibility;
	
	If ButtonVisibility Then
		Items.DataExchangeDirectory.Title = GetDirectoryNameAtServer(Object.ExchangeMessagesTransportKind, Object.InfobaseNode);
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckWhetherTransferToNewExchangeIsRequired()
	
	ArrayOfMessages = GetUserMessages(True);
	
	If ArrayOfMessages = Undefined Then
		Return;
	EndIf;
	
	Count = ArrayOfMessages.Count();
	If Count = 0 Then
		Return;
	EndIf;
	
	Message      = ArrayOfMessages[Count-1];
	MessageText = Message.Text;
	
	// A subsystem ID is deleted from the message if necessary.
	If StrStartsWith(MessageText, "{MigrationToNewExchangeDone}") Then
		
		MessageData = Common.ValueFromXMLString(MessageText);
		
		If MessageData <> Undefined
			And TypeOf(MessageData) = Type("Structure") Then
			
			ExchangePlanName                    = MessageData.ExchangePlanNameToMigrateToNewExchange;
			ExchangePlanNodeCode                = MessageData.Code;
			NewDataSynchronizationSetting = ExchangePlans[ExchangePlanName].FindByCode(ExchangePlanNodeCode);
			
			BackgroundJobExecutionResult.AdditionalResultData.Insert("FormReopeningParameters",
				New Structure("NewDataSynchronizationSetting", NewDataSynchronizationSetting));
				
			BackgroundJobExecutionResult.AdditionalResultData.Insert("ForceCloseForm", True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareExportAdditionStructure(StructureAddition)
	
	StructureAddition = New Structure;
	StructureAddition.Insert("ExportOption", ExportAddition.ExportOption);
	StructureAddition.Insert("AllDocumentsFilterPeriod", ExportAddition.AllDocumentsFilterPeriod);
	
	StructureAddition.Insert("AllDocumentsComposer", Undefined);
	If Not IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		AllDocumentsComposer = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		
		StructureAddition.AllDocumentsComposer = AllDocumentsComposer;
	EndIf;
	
	StructureAddition.Insert("NodeScenarioFilterPeriod", ExportAddition.NodeScenarioFilterPeriod);
	StructureAddition.Insert("NodeScenarioFilterPresentation", ExportAddition.NodeScenarioFilterPresentation);
	StructureAddition.Insert("AdditionScenarioParameters", ExportAddition.AdditionScenarioParameters);
	StructureAddition.Insert("CurrentSettingsItemPresentation", ExportAddition.CurrentSettingsItemPresentation);
	StructureAddition.Insert("InfobaseNode", ExportAddition.InfobaseNode);
	
	StructureAddition.Insert("AllDocumentsSettingFilterComposer", ExportAddition.AllDocumentsFilterComposer.GetSettings());
	
	StructureAddition.Insert("AdditionalNodeScenarioRegistration", ExportAddition.AdditionalNodeScenarioRegistration.Unload());
	StructureAddition.Insert("AdditionalRegistration", ExportAddition.AdditionalRegistration.Unload());
	
EndProcedure

#Region ExportAdditionOperations

&AtServer
Procedure InitializeExportAdditionAttributes()
	
	// Getting settings as a structure, settings will be saved implicitly to the form temporary storage.
	ExportAdditionSettings = DataExchangeServer.InteractiveExportChange(
		Object.InfobaseNode, ThisObject.UUID, ExportAdditionExtendedMode);
		
	// 
	// 
	DataExchangeServer.InteractiveExportChangeAttributeBySettings(ThisObject, ExportAdditionSettings, "ExportAddition");
	
	AdditionScenarioParameters = ExportAddition.AdditionScenarioParameters;
	
	// Configuring interface according to the specified scenario.
	
	// Special cases.
	StandardVariantsProhibited = Not AdditionScenarioParameters.OptionDoNotAdd.Use
		And Not AdditionScenarioParameters.AllDocumentsOption.Use
		And Not AdditionScenarioParameters.ArbitraryFilterOption.Use;
		
	If StandardVariantsProhibited Then
		If AdditionScenarioParameters.AdditionalOption.Use Then
			// 
			Items.ExportAdditionNodeAsStringExportOption.Visible = True;
			Items.ExportAdditionNodeExportOption.Visible        = False;
			Items.CustomGroupIndentDecoration.Visible           = False;
			ExportAddition.ExportOption = 3;
		Else
			// 
			ExportAddition.ExportOption = -1;
			Items.ExportAdditionOptions.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// 
	Items.StandardAdditionOptionNone.Visible = AdditionScenarioParameters.OptionDoNotAdd.Use;
	If Not IsBlankString(AdditionScenarioParameters.OptionDoNotAdd.Title) Then
		Items.ExportAdditionExportOption0.ChoiceList[0].Presentation = AdditionScenarioParameters.OptionDoNotAdd.Title;
	EndIf;
	Items.StandardAdditionOptionNoneNote.Title = AdditionScenarioParameters.OptionDoNotAdd.Explanation;
	If IsBlankString(Items.StandardAdditionOptionNoneNote.Title) Then
		Items.StandardAdditionOptionNoneNote.Visible = False;
	EndIf;
	
	Items.StandardAdditionOptionDocuments.Visible = AdditionScenarioParameters.AllDocumentsOption.Use;
	If Not IsBlankString(AdditionScenarioParameters.AllDocumentsOption.Title) Then
		Items.ExportAdditionExportOption1.ChoiceList[0].Presentation = AdditionScenarioParameters.AllDocumentsOption.Title;
	EndIf;
	Items.StandardAdditionOptionDocumentsNote.Title = AdditionScenarioParameters.AllDocumentsOption.Explanation;
	If IsBlankString(Items.StandardAdditionOptionDocumentsNote.Title) Then
		Items.StandardAdditionOptionDocumentsNote.Visible = False;
	EndIf;
	
	Items.StandardAdditionOptionCustom.Visible = AdditionScenarioParameters.ArbitraryFilterOption.Use;
	If Not IsBlankString(AdditionScenarioParameters.ArbitraryFilterOption.Title) Then
		Items.ExportAdditionExportOption2.ChoiceList[0].Presentation = AdditionScenarioParameters.ArbitraryFilterOption.Title;
	EndIf;
	Items.StandardAdditionOptionCustomNote.Title = AdditionScenarioParameters.ArbitraryFilterOption.Explanation;
	If IsBlankString(Items.StandardAdditionOptionCustomNote.Title) Then
		Items.StandardAdditionOptionCustomNote.Visible = False;
	EndIf;
	
	Items.CustomAdditionOption.Visible           = AdditionScenarioParameters.AdditionalOption.Use;
	Items.ExportPeriodNodeScenarioGroup.Visible         = AdditionScenarioParameters.AdditionalOption.UseFilterPeriod;
	Items.ExportAdditionFilterByNodeScenario.Visible    = Not IsBlankString(AdditionScenarioParameters.AdditionalOption.FilterFormName);
	
	Items.ExportAdditionNodeExportOption.ChoiceList[0].Presentation = AdditionScenarioParameters.AdditionalOption.Title;
	Items.ExportAdditionNodeAsStringExportOption.Title              = AdditionScenarioParameters.AdditionalOption.Title;
	
	Items.CustomAdditionOptionNote.Title = AdditionScenarioParameters.AdditionalOption.Explanation;
	If IsBlankString(Items.CustomAdditionOptionNote.Title) Then
		Items.CustomAdditionOptionNote.Visible = False;
	EndIf;
	
	// Command titles.
	If Not IsBlankString(AdditionScenarioParameters.AdditionalOption.FormCommandTitle) Then
		Items.ExportAdditionFilterByNodeScenario.Title = AdditionScenarioParameters.AdditionalOption.FormCommandTitle;
	EndIf;
	
	// Sorting visible items.
	AdditionGroupOrder = New ValueList;
	If Items.StandardAdditionOptionNone.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionNone, 
			Format(AdditionScenarioParameters.OptionDoNotAdd.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionOptionDocuments.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionDocuments, 
			Format(AdditionScenarioParameters.AllDocumentsOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionOptionCustom.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionCustom, 
			Format(AdditionScenarioParameters.ArbitraryFilterOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomAdditionOption.Visible Then
		AdditionGroupOrder.Add(Items.CustomAdditionOption, 
			Format(AdditionScenarioParameters.AdditionalOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	AdditionGroupOrder.SortByPresentation();
	For Each AdditionGroupItem In AdditionGroupOrder Do
		Items.Move(AdditionGroupItem.Value, Items.ExportAdditionOptions);
	EndDo;
	
	// Editing settings is only allowed if the appropriate rights are granted.
	HasRightsToSetup = AccessRight("SaveUserData", Metadata);
	Items.StandardSettingsOptionsImportGroup.Visible = HasRightsToSetup;
	If HasRightsToSetup Then
		// Restore predefined settings.
		SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionSettingsAutoSavingName());
		ExportAddition.CurrentSettingsItemPresentation = "";
	Else
		SetFirstItem = True;
	EndIf;
		
	SetFirstItem = SetFirstItem
		Or ExportAddition.ExportOption<0 
		Or ( (ExportAddition.ExportOption=0) And (Not AdditionScenarioParameters.OptionDoNotAdd.Use) )
		Or ( (ExportAddition.ExportOption=1) And (Not AdditionScenarioParameters.AllDocumentsOption.Use) )
		Or ( (ExportAddition.ExportOption=2) And (Not AdditionScenarioParameters.ArbitraryFilterOption.Use) )
		Or ( (ExportAddition.ExportOption=3) And (Not AdditionScenarioParameters.AdditionalOption.Use) );
	
	If SetFirstItem Then
		For Each AdditionGroupItem In AdditionGroupOrder[0].Value.ChildItems Do
			If TypeOf(AdditionGroupItem)=Type("FormField") And AdditionGroupItem.Type = FormFieldType.RadioButtonField Then
				ExportAddition.ExportOption = AdditionGroupItem.ChoiceList[0].Value;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// 
	Items.AllDocumentsFilterGroup.Enabled  = ExportAddition.ExportOption=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportOption=2;
	Items.CustomFilterGroup.Enabled = ExportAddition.ExportOption=3;
	
	// Description of standard initial filters.
	SetExportAdditionFilterDescription();
	
EndProcedure

&AtServer
Procedure SetFormHeader()
	
	TitleTemplate1 = NStr("en = 'Exchange data with %1';");
	
	If MessageReceivedForDataMapping Then
		TitleTemplate1 = NStr("en = 'Map %1 data';");
	ElsIf GetData And SendData Then
		TitleTemplate1 = NStr("en = 'Synchronize data with %1';");
	ElsIf SendData Then
		TitleTemplate1 = NStr("en = 'Send data to %1';");
	ElsIf GetData Then
		TitleTemplate1 = NStr("en = 'Receive data from %1';");
	EndIf;
		
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		TitleTemplate1, CorrespondentDescription);
	
EndProcedure

&AtClient
Procedure ExportAdditionExportVariantSetVisibility()
	Items.AllDocumentsFilterGroup.Enabled  = ExportAddition.ExportOption=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportOption=2;
	Items.CustomFilterGroup.Enabled = ExportAddition.ExportOption=3;
EndProcedure

&AtServer
Procedure ExportAdditionNodeScenarioPeriodChanging()
	DataExchangeServer.InteractiveExportChangeSetNodeScenarioPeriod(ExportAddition);
EndProcedure

&AtServer
Procedure ExportAdditionClearGeneralFilterServer()
	DataExchangeServer.InteractiveExportChangeClearGeneralFilter(ExportAddition);
	SetGeneralFilterAdditionDescription();
EndProcedure

&AtServer
Procedure ExportAdditionClearDetailedFilterServer()
	DataExchangeServer.InteractiveExportChangeDetailsClearing(ExportAddition);
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetExportAdditionFilterDescription()
	SetGeneralFilterAdditionDescription();
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetGeneralFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveExportChangeGeneralFilterAdditionDetails(ExportAddition);
	NoFilter2 = IsBlankString(Text);
	If NoFilter2 Then
		Text = NStr("en = 'All documents';");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentsFilter.Title = Text;
	Items.ExportAdditionClearGeneralFilter.Visible = Not NoFilter2;
EndProcedure

&AtServer
Procedure SetAdditionDetailDescription()
	
	Text = DataExchangeServer.InteractiveExportChangeDetailedFilterDetails(ExportAddition);
	NoFilter2 = IsBlankString(Text);
	If NoFilter2 Then
		Text = NStr("en = 'No additional data is selected';");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title = Text;
	Items.ExportAdditionClearDetailedFilter.Visible = Not NoFilter2;
EndProcedure

// Returns boolean - success or failure (setting is not found).
&AtServer 
Function ExportAdditionSetSettingsServer(SettingPresentation)
	Result = DataExchangeServer.InteractiveExportChangeRestoreSettings(ExportAddition, SettingPresentation);
	SetExportAdditionFilterDescription();
	Return Result;
EndFunction

&AtServer 
Function ExportAdditionServerSettingsHistory() 
	Return DataExchangeServer.InteractiveExportChangeSettingsHistory(ExportAddition);
EndFunction

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsServerWIthoutContext

&AtServerNoContext
Procedure GetDataExchangesStates(DataImportResult, DataExportResult, Val InfobaseNode)
	
	DataExchangesStates = DataExchangeServer.DataExchangesStatesForInfobaseNode(InfobaseNode);
	
	DataImportResult = DataExchangesStates["DataImportResult"];
	If IsBlankString(DataExportResult) Then
		DataExportResult = DataExchangesStates["DataExportResult"];
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteMessageForDataMapping(ExchangeNode, ExchangeMessagesTransportKind = Undefined)
	
	SetPrivilegedMode(True);
	
	Filter = New Structure("InfobaseNode", ExchangeNode);
	CommonSettings = InformationRegisters.CommonInfobasesNodesSettings.Get(Filter);
	
	If ValueIsFilled(CommonSettings.MessageForDataMapping) Then
		
		WSPassiveModeFileIB = ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode
			And Common.FileInfobase(); 
		
		MessageFileNameInStorage = DataExchangeServer.GetFileFromStorage(CommonSettings.MessageForDataMapping, WSPassiveModeFileIB);
		
		File = New File(MessageFileNameInStorage);
		If File.Exists() And File.IsFile() Then
			DeleteFiles(MessageFileNameInStorage);
		EndIf;
		
		InformationRegisters.CommonInfobasesNodesSettings.PutMessageForDataMapping(ExchangeNode, Undefined);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteTempExchangeMessagesDirectory(TempDirectoryName, DirectoryID)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
			If Not IsBlankString(DirectoryID) Then
				DataExchangeServer.GetFileFromStorage(DirectoryID);
			EndIf;
		Except
			WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
				EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure EndExecutingTimeConsumingOperation(JobID)
	TimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

&AtServerNoContext
Function GetDirectoryNameAtServer(ExchangeMessagesTransportKind, InfobaseNode)
	
	Return InformationRegisters.DataExchangeTransportSettings.DataExchangeDirectoryName(ExchangeMessagesTransportKind, InfobaseNode);
	
EndFunction

&AtServerNoContext
Function TimeConsumingOperationState(Val OperationID, ExchangeNode, GetPasswordFromSessionData, ErrorMessageString = "")
	
	AuthenticationParameters = Undefined;
	If GetPasswordFromSessionData Then
		AuthenticationParameters = DataExchangeServer.DataSynchronizationPassword(ExchangeNode);
	EndIf;
	
	Return DataExchangeInternal.TimeConsumingOperationStateForInfobaseNode(
		OperationID,
		ExchangeNode,
		AuthenticationParameters,
		ErrorMessageString);
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure TimeConsumingOperationIdleHandler()
	
	TimeConsumingOperationCompleted         = False;
	TimeConsumingOperationCompletedWithError = False;
	
	If ExchangeOverWebService Then
		GetPasswordFromSessionData = (Not SkipTransportPage And Not WSRememberPassword);
		ActionState = TimeConsumingOperationState(OperationID, Object.InfobaseNode, GetPasswordFromSessionData, ErrorMessage);
		
		If ActionState = Undefined
			And RetryCountOnConnectionError < 5 Then
			RetryCountOnConnectionError = RetryCountOnConnectionError + 1;
			AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
			Return;
	EndIf;
	Else
		// 
		ActionState = DataExchangeServerCall.JobState(JobID);
	EndIf;
	
	If ActionState = "Active" Or ActionState = "Active" Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
	Else
		
		TimeConsumingOperation          = False;
		TimeConsumingOperationCompleted = True;
		
		If ActionState = "Failed" 
			Or ActionState = "Canceled" 
			Or ActionState = "Failed" Then
			TimeConsumingOperationCompletedWithError = True;
		EndIf;
		
		AttachIdleHandler("ExecuteMoveNext", 0.1, True);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function GetSelectedRowKeys(SelectedRows)
	
	// Function return value.
	RowsKeys = New Array;
	
	For Each RowID In SelectedRows Do
		
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowsKeys.Add(TreeRow.Key);
			
		EndIf;
		
	EndDo;
	
	Return RowsKeys;
EndFunction

&AtClient
Procedure GetAllRowKeys(RowsKeys, TreeItemsCollection)
	
	For Each TreeRow In TreeItemsCollection Do
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowsKeys.Add(TreeRow.Key);
			
		EndIf;
		
		ItemsCollection = TreeRow.GetItems();
		
		If ItemsCollection.Count() > 0 Then
			
			GetAllRowKeys(RowsKeys, ItemsCollection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDataExchangeStatusItemPresentation()
	
	Items.DataImportGroup.Visible = GetData;
	
	Items.DataImportStatusPages.CurrentPage = Items[DataExchangeClient.DataImportStatusPages()[DataImportResult]];
	If Items.DataImportStatusPages.CurrentPage=Items.ImportStatusUndefined Then
		Items.GoToDataImportEventLog.Title = NStr("en = 'Data is not imported.';");
	Else
		Items.GoToDataImportEventLog.Title = DataExchangeClient.DataImportHyperlinksHeaders()[DataImportResult];
	EndIf;
	
	Items.ErrorImportingMessageForMappingGroup.Visible = MessageReceivedForDataMapping And (DataImportResult = "Error");
	
	Items.DataExportGroup.Visible = SendData;
	
	Items.DataExportStatusPages.CurrentPage = Items[DataExchangeClient.DataExportStatusPages()[DataExportResult]];
	If Items.DataExportStatusPages.CurrentPage=Items.ExportStatusUndefined Then
		Items.GoToDataExportEventLog.Title = NStr("en = 'Data is not exported.';");
	Else
		Items.GoToDataExportEventLog.Title = DataExchangeClient.DataExportHyperlinksHeaders()[DataExportResult];
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(Composite = "")
	
	ItemsCollection = StatisticsInformationTree.GetItems();
	
	For Each TreeRow In ItemsCollection Do
		
		Items.StatisticsInformationTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Placing a mouse pointer in the value tree.
	If Not IsBlankString(Composite) Then
		
		RowID = 0;
		
		CommonClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsInformationTree.GetItems(), Composite, False);
		
		Items.StatisticsInformationTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function BackgroundJobParameters()
	
	JobParameters = New Structure();
	JobParameters.Insert("MethodToExecute",      "");
	JobParameters.Insert("JobDescription",   "");
	JobParameters.Insert("MethodParameters",       Undefined);
	JobParameters.Insert("CompletionNotification2", Undefined);
	JobParameters.Insert("CompletionHandler",  Undefined);
	
	Return JobParameters;
	
EndFunction

&AtClient
Procedure BackgroundJobStartClient(JobParameters, Cancel, GetPasswordFromSessionData)
	
	Result = BackgroundJobStartAtServer(JobParameters, GetPasswordFromSessionData);
	
	If Result = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	If VersionDifferenceErrorOnGetData <> Undefined
		And VersionDifferenceErrorOnGetData.HasError Then
		Cancel = True;
		ErrorMessage = VersionDifferenceErrorOnGetData.ErrorText;
		Return;
	EndIf;
	
	BackgroundJobExecutionResult = Result;
	BackgroundJobExecutionResult.Insert("CompletionHandler", JobParameters.CompletionHandler);
	
	If Result.Status = "Running" Then
		
		TimeConsumingOperation = True;
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		BackgroundJobCompletionNotification = New NotifyDescription("BackgroundJobCompletionNotification", ThisObject);
		
		If UseProgressBar Then
			IdleParameters.OutputProgressBar     = True;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("BackgroundJobExecutionProgress", ThisObject);
			IdleParameters.Interval                       = 1;
		EndIf;
		
		TimeConsumingOperationsClient.WaitCompletion(Result, BackgroundJobCompletionNotification, IdleParameters);
		
	Else
		// Job is completed, canceled, or completed with an error.
		AttachIdleHandler(JobParameters.CompletionHandler, 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ProgressStructure      = Progress.Progress;
		
		AdditionalProgressParameters = Undefined;
		If Not ProgressStructure.Property("AdditionalParameters", AdditionalProgressParameters) Then
			Return;
		EndIf;
		
		If Not AdditionalProgressParameters.Property("DataExchange") Then
			Return;
		EndIf;
		
		ProgressPercent       = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtServer
Function BackgroundJobStartAtServer(JobParameters, GetPasswordFromSessionData)
	
	OperationStartDate  = CurrentSessionDate();
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobParameters.JobDescription;
	
	If GetPasswordFromSessionData Then
		SessionDataPassword = New Structure("WSPassword", DataExchangeServer.DataSynchronizationPassword(Object.InfobaseNode));
		FillPropertyValues(JobParameters.MethodParameters, SessionDataPassword);
	EndIf;
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		JobParameters.MethodToExecute,
		JobParameters.MethodParameters,
		ExecutionParameters);
	
	Return Result;
	
EndFunction

&AtClient
Procedure BackgroundJobCompletionNotification(Result, AdditionalParameters) Export
	
	CompletionHandler = BackgroundJobExecutionResult.CompletionHandler;
	BackgroundJobExecutionResult = Result;
	
	// Job is completed, canceled, or completed with an error.
	AttachIdleHandler(CompletionHandler, 0.1, True);
	
EndProcedure

&AtClient
Procedure ProcessBackgroundJobExecutionStatus(CurrentAction = Undefined)
	
	CommitCompletion = False;
	If TypeOf(BackgroundJobExecutionResult) <> Type("Structure") Then
		Return; 
	ElsIf BackgroundJobExecutionResult.Status = "Error" Then
		ErrorMessage = BackgroundJobExecutionResult.DetailErrorDescription;
		CommitCompletion = True;
	ElsIf BackgroundJobExecutionResult.Status = "Canceled" Then
		ErrorMessage = NStr("en = 'The operation was canceled by user.';");
		CommitCompletion = True;
	EndIf;
	
	If ValueIsFilled(CurrentAction)
		And CommitCompletion Then
		DataExchangeServerCall.WriteExchangeFinishWithError(
			Object.InfobaseNode,
			CurrentAction,
			OperationStartDate,
			ErrorMessage);
	EndIf;
		
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SECTION OF STEP CHANGE HANDLERS

#Region NavigationEventHandlers

&AtClient
Function Attachable_BeginningPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	SkipPage = IsMoveNext And SkipTransportPage;
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_BeginningPageOnGoNext(Cancel)
	
	If SkipTransportPage Then
		Return Undefined;
	EndIf;
	
	// Check filling of form attributes.
	If Object.InfobaseNode.IsEmpty() Then
		
		NString = NStr("en = 'Please specify the infobase node.';");
		CommonClient.MessageToUser(NString, , "Object.InfobaseNode", , Cancel);
		
	ElsIf Object.ExchangeMessagesTransportKind.IsEmpty()
		And Not MessageReceivedForDataMapping Then
		
		NString = NStr("en = 'Please specify the connection option.';");
		CommonClient.MessageToUser(NString, , "Object.ExchangeMessagesTransportKind", , Cancel);
		
	ElsIf ExchangeOverWebService And IsBlankString(WSPassword) Then
		
		NString = NStr("en = 'Please enter the password.';");
		CommonClient.MessageToUser(NString, , "WSPassword", , Cancel);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionTestWaitingPageTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If ExchangeOverExternalConnection Then
		If CommonClient.FileInfobase() Then
			CommonClient.RegisterCOMConnector(False);
		EndIf;
		Return Undefined;
	EndIf;
	
	If ExchangeOverWebService Then
		TestConnectionAndSaveSettings(Cancel);
		
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Cannot perform the operation.';"));
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure TestConnectionAndSaveSettings(Cancel)
	
	AuthenticationParameters = Undefined;
	If Not SkipTransportPage Then
		AuthenticationParameters = New Structure;
		AuthenticationParameters.Insert("UseCurrentUser", False);
		AuthenticationParameters.Insert("Password", WSPassword);
	EndIf;
	
	SetPrivilegedMode(True);
	ConnectionParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(
		Object.InfobaseNode, AuthenticationParameters);
		
	ErrorMessage              = "";
	ErrorMessageToUser  = "";
	SettingCompleted             = True;
	DataReceivedForMapping = False;
	
	HasConnection = DataExchangeWebService.CorrespondentConnectionEstablished(Object.InfobaseNode,
		ConnectionParameters, ErrorMessageToUser, SettingCompleted, DataReceivedForMapping);
		
	If Not HasConnection Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot connect to the web application. Reason: ""%1.""
			|Ensure that:
			| - The password is correct.
			| - The connection address is correct.
			| - The application is available.
			| - Web app synchronization is configured.
			|Then, restart synchronization.';"),
			ErrorMessageToUser);
		Cancel = True;
	ElsIf Not SettingCompleted Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To continue, set up synchronization in ""%1"". The data exchange is canceled.';"),
			CorrespondentDescription);
		Cancel = True;
	ElsIf DataReceivedForMapping Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To continue, open %1 and import the data mapping message. The data exchange is canceled.';"),
			CorrespondentDescription);
		Cancel = True;
	EndIf;
	
	If HasConnection And Not SkipTransportPage And WSRememberPassword Then
		Try
			// Updating record in the information register.
			RecordStructure = New Structure;
			RecordStructure.Insert("Peer", Object.InfobaseNode);
			RecordStructure.Insert("WSRememberPassword", True);
			RecordStructure.Insert("WSPassword", WSPassword);
			
			InformationRegisters.DataExchangeTransportSettings.UpdateRecord(RecordStructure);
			
			WSPassword = String(ThisObject.UUID);
		Except
			ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
				EventLogLevel.Error, , , ErrorMessage);
				
			Common.MessageToUser(ErrorMessage, , , , Cancel);
			Return;
		EndTry;
	EndIf;
	
	If Cancel Then
		Common.MessageToUser(ErrorMessage);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_PageDataExchangeJobCheck_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If HasNodeScheduledExchange Then
		
		If ValueIsFilled(ScenarioUsingInternalPublication) Then
			
			Template = NStr("en = 'Synchronization is already scheduled for node ""%1"" 
                           |in scenario ""%2"".
                           |
                           |Click Next to cancel the scenario
                           |and start synchronization by the node.';");
			MessageText = StrTemplate(Template, String(Object.InfobaseNode), String(ScenarioUsingInternalPublication));	

		Else
			
			Template = NStr("en = 'Synchronization is already in progress for node ""%1"".
                           |
                           |Click Next to terminate the current synchronization
                           |and restart it';");
			MessageText = StrTemplate(Template, String(Object.InfobaseNode));

		EndIf;
		
		Items.StatusTaskQueued.Title = MessageText;
		
	Else
		
		SkipPage = True;
		
	EndIf;
		
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_PageDataExchangeTasksCheck_OnNavigateNext(Cancel)
	
	CancelQueueAndResumeOnServer();
	ExecuteMoveNext();
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure CancelQueueAndResumeOnServer()
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.CancelTaskQueue(Object.InfobaseNode, 
	    ScenarioUsingInternalPublication,
		IDOfExchangeViaInternalPublication);
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_DataAnalysisWaitingPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	InitializeDataProcessorVariables();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisWaitingPageTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	SkipGettingData = False;
	GoToNext              = False;
	
	GetPasswordFromSessionData = (Not SkipTransportPage And Not WSRememberPassword);
	
	MethodParameters = New Structure;
	MethodParameters.Insert("Cancel", False);
	MethodParameters.Insert("TimeConsumingOperation",                   TimeConsumingOperation);
	MethodParameters.Insert("OperationID",                OperationID);
	MethodParameters.Insert("DataPackageFileID",       DataPackageFileID);
	MethodParameters.Insert("FileID",                   FileID);
	MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	MethodParameters.Insert("TempExchangeMessagesDirectoryName", Object.TempExchangeMessagesDirectoryName);
	MethodParameters.Insert("ExchangeMessagesTransportKind",         Object.ExchangeMessagesTransportKind);
	MethodParameters.Insert("WSPassword",                             Undefined);
	
	MethodParameters.Insert("MessageReceivedForDataMapping", MessageReceivedForDataMapping);
	MethodParameters.Insert("TempDirectoryIDForExchange", "");
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodToExecute     = "DataProcessors.InteractiveDataExchangeWizard.GetExchangeMessageToTemporaryDirectory";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("en = 'Get exchange message to temporary directory';");
	JobParameters.CompletionHandler = "DataReceiptToTemporaryFolderCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel, GetPasswordFromSessionData);
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure DataReceiptToTemporaryFolderCompletion()
	
	ProcessBackgroundJobExecutionStatus("DataImport");
	
	If ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
	Else
		GetDataToTemporaryDirectoryAtServerCompletion();
	EndIf;
	
	If TimeConsumingOperation And Not SkipGettingData Then
		RetryCountOnConnectionError = 0;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		AttachIdleHandler("ExecuteMoveNext", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisWaitingPageTimeConsumingOperationCompletionTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If TimeConsumingOperationCompleted
		And Not TimeConsumingOperationCompletedWithError Then
		
		// Get the file prepared at the correspondent to the temporary directory.
		If Not ValueIsFilled(Object.ExchangeMessageFileName) Then
			
			GetPasswordFromSessionData = (Not SkipTransportPage And Not WSRememberPassword);
			
			GoToNext = False;
			
			MethodParameters = New Structure;
			MethodParameters.Insert("Cancel",                                False);
			MethodParameters.Insert("FileID",                   FileID);
			MethodParameters.Insert("DataPackageFileID",       DataPackageFileID);
			MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
			MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
			MethodParameters.Insert("TempExchangeMessagesDirectoryName", Object.TempExchangeMessagesDirectoryName);
			MethodParameters.Insert("WSPassword",                             Undefined);
			
			JobParameters = BackgroundJobParameters();
			JobParameters.MethodToExecute     = "DataProcessors.InteractiveDataExchangeWizard.GetExchangeMessageFromCorrespondentToTemporaryDirectory";
			JobParameters.MethodParameters      = MethodParameters;
			JobParameters.JobDescription  = NStr("en = 'Get exchange message file to temporary directory';");
			JobParameters.CompletionHandler = "CorrespondentDataReceiptToTemporaryFolderCompletion";
			
			BackgroundJobStartClient(JobParameters, Cancel, GetPasswordFromSessionData);
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure CorrespondentDataReceiptToTemporaryFolderCompletion()
	
	ProcessBackgroundJobExecutionStatus("DataImport");
	
	If ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
	Else
		GetDataToTemporaryDirectoryAtServerCompletion();
	EndIf;
	
	AttachIdleHandler("ExecuteMoveNext", 0.1, True);
	
EndProcedure

&AtServer
Procedure GetDataToTemporaryDirectoryAtServerCompletion()
	
	ErrorMessageTemplate = NStr("en = 'Cannot import data. See the Event log for details.';");
	MethodExecutionResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
	
	If MethodExecutionResult = Undefined Then
		If Not ValueIsFilled(ErrorMessage) Then
			ErrorMessage = ErrorMessageTemplate;
		EndIf;
	Else
		
		If MethodExecutionResult.Cancel Then
			
			If MethodExecutionResult.Property("ErrorMessage") Then
				ErrorMessage = MethodExecutionResult.ErrorMessage;
			ElsIf Not ValueIsFilled(ErrorMessage) Then
				ErrorMessage = ErrorMessageTemplate;
			EndIf;
			
			If MessageReceivedForDataMapping Then
				MessageReceivedForDataMapping = False;
			EndIf;
			
		Else
			
			FillPropertyValues(ThisObject, MethodExecutionResult, , "WSPassword");
			
			Object.ExchangeMessageFileName              = MethodExecutionResult.ExchangeMessageFileName;
			Object.TempExchangeMessagesDirectoryName = MethodExecutionResult.TempExchangeMessagesDirectoryName;
			
		EndIf;
			
	EndIf;
	
	If ValueIsFilled(ErrorMessage) Then
		
		TimeConsumingOperation                  = False;
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		SkipGettingData           = True;
		
		DataExchangeServerCall.WriteExchangeFinishWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			ErrorMessage);
			
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_DataAnalysisPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SkipGettingData Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataAnalysisTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	GoToNext = False;
	
	MethodParameters = New Structure;
	MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	MethodParameters.Insert("TempExchangeMessagesDirectoryName", Object.TempExchangeMessagesDirectoryName);
	MethodParameters.Insert("CheckVersionDifference",           CheckVersionDifference);
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodToExecute     = "DataProcessors.InteractiveDataExchangeWizard.ExecuteAutomaticDataMapping";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("en = 'Analyze exchange message data';");
	JobParameters.CompletionHandler = "Attachable_DataAnalysisCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel, False);
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure Attachable_DataAnalysisCompletion()
	
	ProcessBackgroundJobExecutionStatus("DataImport");
	
	If Not SkipGettingData And ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
	Else
		AtalyzeDataAtServerCompletion();
	EndIf;
	
	If ForceCloseForm Then
		ThisObject.Close();
	EndIf;

	If Not SkipGettingData Then
		ExpandStatisticsTree();
	EndIf;
	
	AttachIdleHandler("ExecuteMoveNext", 0.1, True);
	
EndProcedure

&AtServer
Procedure AtalyzeDataAtServerCompletion()
	
	// Checking the transition to a new data exchange.
	CheckWhetherTransferToNewExchangeIsRequired();
	If ForceCloseForm Then
		Return;
	EndIf;
	
	Try
		
		AnalysisResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
		
		If AnalysisResult.Property("ErrorText") Then
			VersionDifferenceErrorOnGetData = AnalysisResult;
		ElsIf AnalysisResult.Cancel Then
			
			If AnalysisResult.Property("ExchangeExecutionResult")
				And AnalysisResult.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted Then
				
				SkipGettingData = True;
				
				ExchangeSettingsStructure = New Structure;
				ExchangeSettingsStructure.Insert("InfobaseNode",       Object.InfobaseNode);
				ExchangeSettingsStructure.Insert("ExchangeExecutionResult",    AnalysisResult.ExchangeExecutionResult);
				ExchangeSettingsStructure.Insert("ActionOnExchange",            "DataImport");
				ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
				ExchangeSettingsStructure.Insert("StartDate",                   OperationStartDate);
				ExchangeSettingsStructure.Insert("EndDate",                CurrentSessionDate());
				ExchangeSettingsStructure.Insert("EventLogMessageKey", 
					DataExchangeServer.EventLogMessageKey(Object.InfobaseNode, "DataImport"));
				ExchangeSettingsStructure.Insert("IsDIBExchange", 
					DataExchangeCached.IsDistributedInfobaseNode(Object.InfobaseNode));
				
				DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
			Else
				Raise AnalysisResult.ErrorMessage;
			EndIf;
			
		Else
			
			AllDataMapped   = AnalysisResult.AllDataMapped;
			HasUnmappedMasterData = AnalysisResult.HasUnmappedMasterData;
			StatisticsBlank        = AnalysisResult.StatisticsBlank;
			
			Object.StatisticsInformation.Load(AnalysisResult.StatisticsInformation);
			Object.StatisticsInformation.Sort("Presentation");
			
			StatisticsInformation(Object.StatisticsInformation.Unload());
			
			SetAdditionalInfoGroupVisible();
			
		EndIf;
		
	Except
		SkipGettingData = True;
		
		Information = ErrorInfo();
		ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
		
		DataExchangeServerCall.WriteExchangeFinishWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			ErrorProcessing.DetailErrorDescription(Information));
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_StatisticsInformationPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If StatisticsBlank Or SkipGettingData Then
		SkipPage = True;
		If MessageReceivedForDataMapping Then
			EndDataMapping = StatisticsBlank;
		EndIf;
	EndIf;
	
	If Not SkipPage Then
		Items.MappingCompletionGroup.Visible = MessageReceivedForDataMapping;
		OnChangeFlagEndDataMapping();
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_StatisticsInformationPageOnGoNext(Cancel)
	
	If StatisticsBlank Or SkipGettingData Or AllDataMapped Or Not HasUnmappedMasterData Then
		Return Undefined;
	EndIf;
	
	If SkipCurrentPageCancelControl = True Then
		SkipCurrentPageCancelControl = Undefined;
		Return Undefined;
	EndIf;
	
	// 
	Cancel = True;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,  NStr("en = 'Continue';"));
	Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel';"));
	
	Message = NStr("en = 'Unmapped data is found. This might result in
	                       |duplication of list items.
	                       |Do you want to continue?';");
	
	Notification = New NotifyDescription("StatisticsPageOnGoNextQuestionCompletion", ThisObject);
	
	ShowQueryBox(Notification, Message, Buttons,, DialogReturnCode.Yes);
	
	Return Undefined;
	
EndFunction

// Continuation of the procedure (see above). 
&AtClient
Procedure StatisticsPageOnGoNextQuestionCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_GoStepForwardWithDeferredProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure Attachable_GoStepForwardWithDeferredProcessing()
	
	// 
	SkipCurrentPageCancelControl = True;
	ChangeNavigationNumber( +1 );
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_DataImportOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SkipGettingData Then
		SkipPage = True;
		If Not MessageReceivedForDataMapping Then
			DeleteTempExchangeMessagesDirectory(Object.TempExchangeMessagesDirectoryName, TempDirectoryIDForExchange);
		EndIf;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataImportTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		DeleteTempExchangeMessagesDirectory(Object.TempExchangeMessagesDirectoryName, TempDirectoryIDForExchange);
		Return Undefined;
	EndIf;
	
	GoToNext    = False;
	MethodParameters = New Structure;
	MethodParameters.Insert("InfobaseNode",  Object.InfobaseNode);
	MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodToExecute     = "DataProcessors.InteractiveDataExchangeWizard.RunDataImport";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("en = 'Import data from exchange message';");
	JobParameters.CompletionHandler = "DataImportCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel, False);
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure DataImportCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	If ValueIsFilled(ErrorMessage) And Not SkipGettingData Then
		SkipGettingData = True;
	EndIf;
	
	ProgressBarDisplayed = Items.PanelMain.CurrentPage = Items.DataSynchronizationWaitProgressBarImportPage
		Or Items.PanelMain.CurrentPage = Items.DataSynchronizationWaitProgressBarExportPage;
		
	If UseProgressBar And ProgressBarDisplayed Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	If MessageReceivedForDataMapping Then
		
		CurrentDataImportResult = "";
		CurrentDataExportResult = "";
		GetDataExchangesStates(CurrentDataImportResult, CurrentDataExportResult, Object.InfobaseNode);
		
		If (EndDataMapping And Not SkipGettingData)
			Or (CurrentDataImportResult = "Warning_ExchangeMessageAlreadyAccepted") Then
			DeleteMessageForDataMapping(Object.InfobaseNode, Object.ExchangeMessagesTransportKind);
		EndIf;
		
	EndIf;
		
	AttachIdleHandler("ExecuteMoveNext", 0.1, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_QuestionAboutExportCompositionPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ExportAddition.ExportOption < 0 Then
		// 
		SkipPage = True;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataRegistrationPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ExportAddition.ExportOption < 0 Then
		// 
		SkipPage = True;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataRegistrationPageTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	AttachIdleHandler("OnStartRecordData", 0.1, True);
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OnStartRecordData()
	
	ContinueWait = True;
	OnStartRecordDataAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			DataRegistrationIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForRecordData",
			DataRegistrationIdleHandlerParameters.CurrentInterval, True);
	Else
		AttachIdleHandler("OnCompleteDataRecording", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForRecordData()
	
	ContinueWait = False;
	OnWaitForRecordDataAtServer(DataRegistrationHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataRegistrationIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForRecordData",
			DataRegistrationIdleHandlerParameters.CurrentInterval, True);
	Else
		AttachIdleHandler("OnCompleteDataRecording", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataRecording()
	
	DataRegistered = False;
	ErrorMessage = "";
	
	OnCompleteDataRecordingAtServer(DataRegistrationHandlerParameters, DataRegistered, ErrorMessage);
	
	If DataRegistered Then
		
		ChangeNavigationNumber(+1);
		
	Else
		ChangeNavigationNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClient.MessageToUser(ErrorMessage);
		Else
			CommonClient.MessageToUser(
				NStr("en = 'Cannot register data to export.';"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartRecordDataAtServer(ContinueWait)
	
	RegistrationSettings = New Structure;
	RegistrationSettings.Insert("ExchangeNode", ExportAddition.InfobaseNode);
	RegistrationSettings.Insert("ExportAddition", Undefined);
	
	PrepareExportAdditionStructure(RegistrationSettings.ExportAddition);
	
	DataRegistrationHandlerParameters = Undefined;
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnStartRecordData(RegistrationSettings,
		DataRegistrationHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForRecordDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnWaitForRecordData(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteDataRecordingAtServer(HandlerParameters, DataRegistered, ErrorMessage)
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnCompleteDataRecording(HandlerParameters, CompletionStatus);
	HandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		DataRegistered = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		DataRegistered = CompletionStatus.Result.DataRegistered;
		
		If Not DataRegistered Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_DataExportOnOpen(Cancel, SkipPage, IsMoveNext)
	
	InitializeDataProcessorVariables();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportWaitingPageTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartExportData(Cancel);
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportWaitingPageTimeConsumingOperationCompletionTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If TimeConsumingOperationCompleted Then
		If TimeConsumingOperationCompletedWithError Then
			DataExchangeServerCall.WriteExchangeFinishWithError(
				Object.InfobaseNode,
				"DataExport",
				OperationStartDate,
				ErrorMessage);
		Else
			DataExchangeServerCall.RecordDataExportInTimeConsumingOperationMode(
				Object.InfobaseNode, OperationStartDate);
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OnStartExportData(Cancel)
	
	If ExchangeBetweenSaaSApplications Then
		ContinueWait = True;
		OnStartExportDataAtServer(ContinueWait);
		
		If ContinueWait Then
			DataExchangeClient.InitIdleHandlerParameters(
				DataExportIdleHandlerParameters);
				
			AttachIdleHandler("OnWaitForExportData",
				DataExportIdleHandlerParameters.CurrentInterval, True);
		Else
			OnCompleteDataExport();
		EndIf;

	ElsIf ExchangeViaInternalPublication Then
		
		OnStartExportDataViaInternalPublicationAtServer();
		
		DataExchangeClient.InitIdleHandlerParameters(
			DataExportIdleHandlerParameters);

		AttachIdleHandler("OnWaitDataExportViaInternalPublication",
			DataExportIdleHandlerParameters.CurrentInterval, True);
		
	Else
		GetPasswordFromSessionData = (Not SkipTransportPage And Not WSRememberPassword);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("InfobaseNode",       Object.InfobaseNode);
		MethodParameters.Insert("ExchangeMessagesTransportKind", Object.ExchangeMessagesTransportKind);
		MethodParameters.Insert("ExchangeMessageFileName",      Object.ExchangeMessageFileName);
		MethodParameters.Insert("TimeConsumingOperation",           TimeConsumingOperation);
		MethodParameters.Insert("OperationID",        OperationID);
		MethodParameters.Insert("FileID",           FileID);
		MethodParameters.Insert("WSPassword",                     Undefined);
		MethodParameters.Insert("Cancel",                        False);
		
		JobParameters = BackgroundJobParameters();
		JobParameters.MethodToExecute     = "DataProcessors.InteractiveDataExchangeWizard.RunDataExport";
		JobParameters.MethodParameters      = MethodParameters;
		JobParameters.JobDescription  = NStr("en = 'Export data to exchange message';");
		JobParameters.CompletionHandler = "DataExportCompletion";
		
		BackgroundJobStartClient(JobParameters, Cancel, GetPasswordFromSessionData);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForExportData()
	
	ContinueWait = False;
	OnWaitForExportDataAtServer(DataExportHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForExportData",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDataExport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataExport()
	
	DataExported1 = False;
	ErrorMessage = "";
	
	OnCompleteDataUnloadAtServer(DataExportHandlerParameters, DataExported1, ErrorMessage);
	
	If DataExported1 Then
		ChangeNavigationNumber(+1);
	Else
		ChangeNavigationNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClient.MessageToUser(ErrorMessage);
		Else
			CommonClient.MessageToUser(
				NStr("en = 'Cannot perform data exchange.';"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartExportDataAtServer(ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ExportSettings1 = New Structure;
	ExportSettings1.Insert("Peer", Object.InfobaseNode);
	ExportSettings1.Insert("CorrespondentDataArea", CorrespondentDataArea);
	ExportSettings1.Insert("ExportAddition", Undefined);
	
	PrepareExportAdditionStructure(ExportSettings1.ExportAddition);
	
	DataExportHandlerParameters = Undefined;
	ModuleInteractiveExchangeWizard.OnStartExportData(ExportSettings1,
		DataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForExportDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnWaitForExportData(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteDataUnloadAtServer(HandlerParameters, DataExported1, ErrorMessage)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		DataExported1 = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard.OnCompleteDataExport(HandlerParameters, CompletionStatus);
	HandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		DataExported1 = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		DataExported1 = CompletionStatus.Result.DataExported1;
		
		If Not DataExported1 Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DataExportCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	ProgressBarDisplayed = Items.PanelMain.CurrentPage = Items.DataSynchronizationWaitProgressBarImportPage
		Or Items.PanelMain.CurrentPage = Items.DataSynchronizationWaitProgressBarExportPage;
	
	If UseProgressBar And ProgressBarDisplayed Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	DataExportCompletionAtServer();
	
	If TimeConsumingOperation And Not ValueIsFilled(ErrorMessage) Then
		RetryCountOnConnectionError = 0;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		DeleteTempExchangeMessagesDirectory(Object.TempExchangeMessagesDirectoryName, TempDirectoryIDForExchange);
		AttachIdleHandler("ExecuteMoveNext", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure DataExportCompletionAtServer()
	
	MethodExecutionResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
	
	If MethodExecutionResult = Undefined Then
		MethodExecutionResult = New Structure("Cancel", True);
	Else
		FillPropertyValues(ThisObject, MethodExecutionResult, 
			"TimeConsumingOperation, OperationID, FileID");
	EndIf;
	
	If MethodExecutionResult.Cancel
		And Not ValueIsFilled(ErrorMessage) Then
		ErrorMessage = NStr("en = 'Cannot send data. See the Event log for details.';");
	EndIf;
	
	If ValueIsFilled(ErrorMessage) Then
		
		TimeConsumingOperation                  = False;
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		
		DataExchangeServerCall.WriteExchangeFinishWithError(
			Object.InfobaseNode,
			"DataExport",
			OperationStartDate,
			ErrorMessage);
			
	EndIf;
	
EndProcedure

&AtServer 
Procedure OnStartExportDataViaInternalPublicationAtServer()
	
	StructureAddition = Undefined;
	PrepareExportAdditionStructure(StructureAddition);
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.RunDataExchangeManually(Object.InfobaseNode, 
		ParametersOfExchangeViaInternalPublication, StructureAddition);
	
EndProcedure
	
&AtClient
Procedure OnWaitDataExportViaInternalPublication()
	
	ContinueWait = False;
	OnWaitDataExportViaInternalPublicationAtServer(ParametersOfExchangeViaInternalPublication, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitDataExportViaInternalPublication",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDataExportViaInternalPublication();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure OnWaitDataExportViaInternalPublicationAtServer(ExchangeParameters, ContinueWait)

	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.OnWaitForExportData(ExchangeParameters, ContinueWait);
	
EndProcedure

&AtClient
Procedure OnCompleteDataExportViaInternalPublication()
			
	OutputErrorDescriptionToUser = True;
	ErrorMessage = ParametersOfExchangeViaInternalPublication.ErrorMessage;
	
	ChangeNavigationNumber(+1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_MappingCompletePageOnOpen(Cancel, SkipPage, Val IsMoveNext)
	
	GetDataExchangesStates(DataImportResult, DataExportResult, Object.InfobaseNode);
	
	RefreshDataExchangeStatusItemPresentation();
	
	ForceCloseForm = True;
	
	Return Undefined;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure FillNavigationTable()
	
	If UseProgressBar Then
		PageNameSynchronizationImport = "DataSynchronizationWaitProgressBarImportPage";
		PageNameSynchronizationExport = "DataSynchronizationWaitProgressBarExportPage";
	Else
		PageNameSynchronizationImport = "DataSynchronizationWaitPage";
		PageNameSynchronizationExport = "DataSynchronizationWaitPage";
	EndIf;
	
	NavigationTable.Clear();
	
	NavigationTableNewRow("StartingPage", "NavigationStartPage", "Attachable_BeginningPageOnOpen", "Attachable_BeginningPageOnGoNext");
	
	If ExchangeBetweenSaaSApplications Or ExchangeViaInternalPublication Then
		
		If MessageReceivedForDataMapping Then
			// Getting data (exchange message transport.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, 
				"Attachable_DataAnalysisWaitingPageTimeConsumingOperationProcessing",
				"Attachable_DataAnalysisWaitingPageOnOpen");
			
			// Data analysis pages (automatic data mapping).
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, 
				"Attachable_DataAnalysisTimeConsumingOperationProcessing",
				"Attachable_DataAnalysisPageOnOpen");
			
			// Manual data mapping.
			NavigationTableNewRow("StatisticsInformationPage", "StatisticsInformationNavigationPage", 
				"Attachable_StatisticsInformationPageOnOpen",
				"Attachable_StatisticsInformationPageOnGoNext");
			
			// Data import.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationImport, "NavigationWaitPage", True,
				"Attachable_DataImportTimeConsumingOperationProcessing",
				"Attachable_DataImportOnOpen");
			
		ElsIf SendData Then
			
			If ExchangeViaInternalPublication Then
				NavigationTableNewRow("PageCheckExchangeTasks", "NavigationPageFollowUp", 
					"Attachable_PageDataExchangeJobCheck_OnOpen",
					"Attachable_PageDataExchangeTasksCheck_OnNavigateNext");	
			EndIf;
			
			If ExportAdditionMode Then
				DataExportResult = "";
				NavigationTableNewRow("QuestionAboutExportCompositionPage", "NavigationPageFollowUp", "Attachable_QuestionAboutExportCompositionPageOnOpen");
			EndIf;
			
			// Export and import data.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True, 
				"Attachable_DataExportWaitingPageTimeConsumingOperationProcessing",
				"Attachable_DataExportOnOpen");
		EndIf;
		
	Else
		
		If ExchangeOverWebService
			Or ExchangeOverExternalConnection Then
			// Test connection.
			If GetData Then
				NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, 
					"Attachable_ConnectionTestWaitingPageTimeConsumingOperationProcessing");
			Else
				NavigationTableNewRowTimeConsumingOperation("DataSynchronizationWaitPage", "NavigationWaitPage", True, 
					"Attachable_ConnectionTestWaitingPageTimeConsumingOperationProcessing");
			EndIf;
		EndIf;
		
		If GetData Then
			// Getting data (exchange message transport.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, 
				"Attachable_DataAnalysisWaitingPageTimeConsumingOperationProcessing",
				"Attachable_DataAnalysisWaitingPageOnOpen");
			
			If ExchangeOverWebService Then
				NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True,
					"Attachable_DataAnalysisWaitingPageTimeConsumingOperationCompletionTimeConsumingOperationProcessing");
			EndIf;
			
			// Data analysis pages (automatic data mapping).
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, 
				"Attachable_DataAnalysisTimeConsumingOperationProcessing",
				"Attachable_DataAnalysisPageOnOpen");
			
			// Manual data mapping.
			If MessageReceivedForDataMapping Then
				NavigationTableNewRow("StatisticsInformationPage", "StatisticsInformationNavigationPage", 
					"Attachable_StatisticsInformationPageOnOpen",
					"Attachable_StatisticsInformationPageOnGoNext");
			Else
				NavigationTableNewRow("StatisticsInformationPage", "NavigationPageFollowUp", 
					"Attachable_StatisticsInformationPageOnOpen",
					"Attachable_StatisticsInformationPageOnGoNext");
			EndIf;
			
			// Data import.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationImport, "NavigationWaitPage", True, 
				"Attachable_DataImportTimeConsumingOperationProcessing",
				"Attachable_DataImportOnOpen");
		EndIf;
		
		If SendData Then
			If ExportAdditionMode Then
				// Data export setup.
				DataExportResult = "";
				NavigationTableNewRow("QuestionAboutExportCompositionPage", "NavigationPageFollowUp", "Attachable_QuestionAboutExportCompositionPageOnOpen");
				
				// The long-running operation of registering additional data to export.
				NavigationTableNewRowTimeConsumingOperation("DataRegistrationPage", "NavigationWaitPage", True,
					"Attachable_DataRegistrationPageTimeConsumingOperationProcessing",
					"Attachable_DataRegistrationPageOnOpen");
			EndIf;
			
			// Export data.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True,
				"Attachable_DataExportWaitingPageTimeConsumingOperationProcessing",
				"Attachable_DataExportOnOpen");
			If ExchangeOverWebService Then
				NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True,
					"Attachable_DataExportWaitingPageTimeConsumingOperationCompletionTimeConsumingOperationProcessing");
			EndIf;
		EndIf;
		
	EndIf;
	
	// Totals.
	NavigationTableNewRow("MappingCompletePage", "NavigationEndPage", "Attachable_MappingCompletePageOnOpen");
	
EndProcedure

#EndRegion

#EndRegion