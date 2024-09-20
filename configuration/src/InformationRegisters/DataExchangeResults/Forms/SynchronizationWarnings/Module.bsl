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
	
	ConditionalFormDesign();
	
	ValuesCache = New Structure("ArrayOfExchangePlanNodes, SelectionByDateOfOccurrence, SelectionOfExchangePlanNodes, SelectingTypesOfWarnings");
	ValuesCache.Insert("WarningsShowHiddenWarnings", False);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectExistsInInfobase", Undefined);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase", Undefined);
	ValuesCache.Insert("RejectedConflictData", Undefined);
	ValuesCache.Insert("ConflictDataAccepted", Undefined);
	
	TheVersioningSubsystemExists = Common.SubsystemExists("StandardSubsystems.ObjectsVersioning");
	If TheVersioningSubsystemExists Then
		
		EnumManager = Enums["ObjectVersionTypes"];
		ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectExistsInInfobase", EnumManager.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
		ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase", EnumManager.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
		ValuesCache.Insert("RejectedConflictData", EnumManager.RejectedConflictData);
		ValuesCache.Insert("ConflictDataAccepted", EnumManager.ConflictDataAccepted);
		
		DynamicListWithVersioningWarnings();
		
		Items.ListConflicts.Visible = True;
		Items.ListBlockingDownloadsByDate.Visible = True;
		
	EndIf;
	
	SelectionsBasedOnTheTransmittedParameters();
	
	FieldArray = New Array;
	FieldArray.Add("HasComment");
	FieldArray.Add("ObjectWithIssue");
	FieldArray.Add("LongDesc");
	
	List.SetRestrictionsForUseInOrder(FieldArray);
	
	List.Parameters.SetParameterValue("UnpostedDocument", NStr("en = 'Unposted document';", Common.DefaultLanguageCode()));
	List.Parameters.SetParameterValue("EmptyAttributes", NStr("en = 'Empty attributes';", Common.DefaultLanguageCode()));
	List.Parameters.SetParameterValue("CheckBeforeSend", NStr("en = 'Check before sending';", Common.DefaultLanguageCode()));
	List.Parameters.SetParameterValue("TechnicalErrorSend", NStr("en = 'Technical error (sending)';", Common.DefaultLanguageCode()));
	List.Parameters.SetParameterValue("TechnicalErrorGet", NStr("en = 'Technical error (receipt)';", Common.DefaultLanguageCode()));
	
	If TheVersioningSubsystemExists Then
		
		List.Parameters.SetParameterValue("UnrecognizedExisting", NStr("en = 'Rejected, existing';", Common.DefaultLanguageCode()));
		List.Parameters.SetParameterValue("RejectedNew", NStr("en = 'Rejected, new';", Common.DefaultLanguageCode()));
		List.Parameters.SetParameterValue("AcceptedCollisionData", NStr("en = 'Received conflict data';", Common.DefaultLanguageCode()));
		List.Parameters.SetParameterValue("RejectedCollisionData", NStr("en = 'Rejected conflict data';", Common.DefaultLanguageCode()));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FilterByPeriodPresentation();
	RepresentationOfTheSelectionOfExchangeNodes();
	RepresentationOfTheSelectionByTypesOfWarnings();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CorrectionOfDocumentSynchronizationWarnings"
		Or EventName = "FixingSynchronizationWarningsReviewingCollisions"
		Or EventName = "CorrectionOfSynchronizationWarningsRevisionOfTheBanDate"
		Then
		
		UpdateTheFormList();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PresentationOfSelectionByPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period = ValuesCache.SelectionByDateOfOccurrence;
	Dialog.Show(New NotifyDescription("AfterSelectionByDateOfOccurrence", ThisObject));
	
EndProcedure

&AtClient
Procedure AfterSelectionByDateOfOccurrence(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("StandardPeriod") Then
		
		Return;
		
	EndIf;
	
	ValuesCache.SelectionByDateOfOccurrence = Result;
	SelectionByDateOfOccurrence();
	FilterByPeriodPresentation();
	
EndProcedure

&AtClient
Procedure PresentationOfSelectionByPeriodClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ViewOfSynchronizationSelectionStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ArrayOfExchangePlanNodes", ValuesCache.ArrayOfExchangePlanNodes);
	OpeningParameters.Insert("SelectionOfExchangePlanNodes", ValuesCache.SelectionOfExchangePlanNodes);
	
	NotifyDescription = New NotifyDescription("AfterSelectingTheExchangeNodes", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.SynchronizationsFilter", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterSelectingTheExchangeNodes(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Array") Then
		
		Return;
		
	EndIf;
	
	ValuesCache.SelectionOfExchangePlanNodes = Result;
	SelectionByNodesOfTheInformationBase();
	RepresentationOfTheSelectionOfExchangeNodes();
	
EndProcedure

&AtClient
Procedure ViewOfSynchronizationSelectionClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure RepresentationOfSelectionOfWarningTypesStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("SelectingTypesOfWarnings", ValuesCache.SelectingTypesOfWarnings);
	
	NotifyDescription = New NotifyDescription("AfterSelectionByTypeOfWarnings", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.WarningsFilterByTypes", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterSelectionByTypeOfWarnings(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Array") Then
		
		Return;
		
	EndIf;
	
	ValuesCache.SelectingTypesOfWarnings = Result;
	SelectionByTypesOfWarnings();
	RepresentationOfTheSelectionByTypesOfWarnings();
	
EndProcedure

&AtClient
Procedure RepresentationOfSelectionOfWarningTypesClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRowData = CurrentWarningListData();
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("OccurrenceDate", CurrentRowData.OccurrenceDate);
	OpeningParameters.Insert("ObjectWithIssue", CurrentRowData.ObjectWithIssue);
	OpeningParameters.Insert("LongDesc", CurrentRowData.LongDesc);
	OpeningParameters.Insert("WarningType", CurrentRowData.WarningType);
	OpeningParameters.Insert("InfobaseNode", CurrentRowData.InfobaseNode);
	OpeningParameters.Insert("MetadataObject", CurrentRowData.MetadataObject);
	OpeningParameters.Insert("UniqueKey", CurrentRowData.UniqueKey);
	OpeningParameters.Insert("HideWarning", CurrentRowData.HideWarning);
	OpeningParameters.Insert("WarningComment", CurrentRowData.WarningComment);
	OpeningParameters.Insert("VersionFromOtherApplication", CurrentRowData.VersionFromOtherApplication);
	OpeningParameters.Insert("ThisApplicationVersion", CurrentRowData.ThisApplicationVersion);
	OpeningParameters.Insert("ThisApplicationVersion", CurrentRowData.ThisApplicationVersion);
	OpeningParameters.Insert("VersionFromOtherApplicationAccepted", CurrentRowData.VersionFromOtherApplicationAccepted);
	OpeningParameters.Insert("IsNewObject", CurrentRowData.IsNewObject);
	
	OpenTheProblemCard(OpeningParameters);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("AvailabilityOfFormListCommands", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenObject(Command)
	
	TheCurrentDataRow = CurrentWarningListData();
	OpenTheObjectOfTheCurrentLine(TheCurrentDataRow);
	
EndProcedure

&AtClient
Procedure WarningsHideFromList(Command)
	
	ChangeTheWarningStatus(Items.List.SelectedRows, True);
	
EndProcedure

&AtClient
Procedure WarningsShowInList(Command)
	
	ChangeTheWarningStatus(Items.List.SelectedRows, False);
	
EndProcedure

&AtClient
Procedure WarningsShowHiddenWarnings(Command)
	
	ValuesCache.WarningsShowHiddenWarnings = Not ValuesCache.WarningsShowHiddenWarnings;
	
	SelectionOfHiddenWarnings();
	Items.ListWarningsShowHidden.Check = ValuesCache.WarningsShowHiddenWarnings;
	Items.ListContextMenuWarningsShowHidden.Check = ValuesCache.WarningsShowHiddenWarnings;
	
	
EndProcedure

&AtClient
Procedure EventLog(Command)
	
	WarningsLevels = New Array;
	WarningsLevels.Add(NStr("en = 'Error';", CommonClient.DefaultLanguageCode()));
	WarningsLevels.Add(NStr("en = 'Warning';", CommonClient.DefaultLanguageCode()));
	
	ThereAreUploadEvents = False;
	ThereAreLoadingEvents = False;
	DefineUploadUploadEvents(ThereAreUploadEvents, ThereAreLoadingEvents);
		
	LogFilterParameters = New Structure;
	LogFilterParameters.Insert("Level", WarningsLevels);

	EventLogEvent = New Array;
	For Each Node In ValuesCache.ArrayOfExchangePlanNodes Do
		
		If ThereAreUploadEvents Then
			MessageKey = DataExchangeServerCall.EventLogMessageKeyByActionString(Node, "DataExport");
			If EventLogEvent.Find(MessageKey) = Undefined Then
				EventLogEvent.Add(MessageKey);
			EndIf;
		EndIf;
		
		If ThereAreLoadingEvents Then
			MessageKey = DataExchangeServerCall.EventLogMessageKeyByActionString(Node, "DataImport");
			If EventLogEvent.Find(MessageKey) = Undefined Then
				EventLogEvent.Add(MessageKey);
			EndIf;
		EndIf;
		
	EndDo;
	
	LogFilterParameters.Insert("EventLogEvent", EventLogEvent); 

	OpenForm("DataProcessor.EventLog.Form", LogFilterParameters, ThisObject,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Procedure DefineUploadUploadEvents(ThereAreUploadEvents, ThereAreLoadingEvents)
	
	Filter = ValuesCache.SelectingTypesOfWarnings;
	
	ThereAreUploadEvents = 
		Filter.Find(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData) <> Undefined
		Or Filter.Find(Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError) <> Undefined;
		
	ThereAreLoadingEvents =
		Filter.Find(Enums.DataExchangeIssuesTypes.UnpostedDocument) <> Undefined
		Or Filter.Find(Enums.DataExchangeIssuesTypes.BlankAttributes) <> Undefined
		Or Filter.Find(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData) <> Undefined;
		
	TheVersioningSubsystemExists = Common.SubsystemExists("StandardSubsystems.ObjectsVersioning");
	If Not ThereAreLoadingEvents And TheVersioningSubsystemExists Then
		
		EnumManager = Enums["ObjectVersionTypes"];
		
		ThereAreLoadingEvents =
			Filter.Find(EnumManager.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase) <> Undefined
			Or Filter.Find(EnumManager.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase) <> Undefined
			Or Filter.Find(EnumManager.RejectedConflictData) <> Undefined
			Or Filter.Find(EnumManager.ConflictDataAccepted) <> Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EventLogAtSpecifiedTime(Command)
	
	CurrentRowData = CurrentWarningListData();
	
	If Not ValueIsFilled(CurrentRowData.OccurrenceDate) Then
		
		WarningText = NStr("en = 'The current line does not contain the time and warning date specified';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, WarningText);
		
	EndIf;
	
	LogFilterParameters = New Structure;
	LogFilterParameters.Insert("StartDate",                CurrentRowData.OccurrenceDate - 1);
	LogFilterParameters.Insert("EndDate",             CurrentRowData.OccurrenceDate + 1);
	
	OpenForm("DataProcessor.EventLog.Form", LogFilterParameters, ThisObject,,,,, FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure DisableAutomaticFormUpdate(Command)
	
	Items.ListDisableAutomaticFormUpdates.Check = Not Items.ListDisableAutomaticFormUpdates.Check;
	
EndProcedure

&AtClient
Procedure ObsoleteRecordsDeletion(Command)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ArrayOfExchangePlanNodes", ValuesCache.ArrayOfExchangePlanNodes);
	OpeningParameters.Insert("SelectionByDateOfOccurrence", ValuesCache.SelectionByDateOfOccurrence);
	OpeningParameters.Insert("SelectionOfExchangeNodes", ValuesCache.SelectionOfExchangePlanNodes);
	OpeningParameters.Insert("SelectingTypesOfWarnings", ValuesCache.SelectingTypesOfWarnings); 
	OpeningParameters.Insert("OnlyHiddenRecords", True);
	
	NotifyDescription = New NotifyDescription("AfterDeletingOutdatedRecords", ThisObject);
	OpenForm("InformationRegister.DataExchangeResults.Form.ObsoleteWarningsDeletion", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterDeletingOutdatedRecords(Result, AdditionalParameters) Export
	
	UpdateTheFormList();
	
EndProcedure

&AtClient
Procedure PreviousWarningsForm(Command)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ExchangeNodes", ValuesCache.ArrayOfExchangePlanNodes);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpeningParameters, ThisObject);
	
	Close();
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	NavigateDocumentsThroughTheSelectedLines(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure Conflicts(Command)
	
	CollisionsOnSelectedLines(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure ImportRestrictionByDate(Command)
	
	ForbiddingLoadingBySelectedLines(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure BatchEditAttributes(Command)
	
	GroupChangeOfDetailsForSelectedLines(Items.List.SelectedRows);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function CurrentWarningListData()
	
	CurrentRowData = Items.List.CurrentData;
	If CurrentRowData = Undefined
		Or TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Then
		
		ExceptionText = NStr("en = 'No command execution is provided for the current line';", CommonClient.DefaultLanguageCode());
		Raise ExceptionText;
		
	EndIf;
	
	Return CurrentRowData;
	
EndFunction

&AtClient
Procedure OpenTheObjectOfTheCurrentLine(CurrentRowData)
	
	If Not ValueIsFilled(CurrentRowData.ObjectWithIssue) Then
		
		WarningText = NStr("en = 'Warning in the current line is not linked to an infobase object';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("AfterOpeningTheObject", ThisObject);
	ShowValue(NotifyDescription, CurrentRowData.ObjectWithIssue);
	
EndProcedure

&AtClient
Procedure AfterOpeningTheObject(AdditionalParameters) Export
	
	UpdateTheFormList();
	
EndProcedure

&AtClient
Procedure FilterByPeriodPresentation()
	
	If Not ValueIsFilled(ValuesCache.SelectionByDateOfOccurrence) Then
		
		FilterByPeriodPresentation = NStr("en = 'Filter not set';", CommonClient.DefaultLanguageCode());
		
	Else
		
		FilterByPeriodPresentation = TrimAll(ValuesCache.SelectionByDateOfOccurrence);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RepresentationOfTheSelectionOfExchangeNodes()
	
	If ValuesCache.SelectionOfExchangePlanNodes = Undefined
		Or ValuesCache.SelectionOfExchangePlanNodes.Count() = 0 Then
		
		SynchronizationsFilterPresentation = NStr("en = 'Filter not set';", CommonClient.DefaultLanguageCode());
		
	ElsIf ValuesCache.SelectionOfExchangePlanNodes.Count() = 1 Then
		
		SynchronizationsFilterPresentation = String(ValuesCache.SelectionOfExchangePlanNodes[0]);
		
	Else
		
		TextTemplate1 = NStr("en = '%1%2 (and %3 more pcs)';", CommonClient.DefaultLanguageCode());
		Triplets = ?(StrLen(TrimAll(ValuesCache.SelectionOfExchangePlanNodes[0])) > 32, "...", "");
		NumberOfMore = ValuesCache.SelectionOfExchangePlanNodes.Count() - 1;
		
		SynchronizationsFilterPresentation = StrTemplate(TextTemplate1, Left(TrimAll(ValuesCache.SelectionOfExchangePlanNodes[0]), 33), Triplets, NumberOfMore);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RepresentationOfTheSelectionByTypesOfWarnings()
	
	If ValuesCache.SelectingTypesOfWarnings = Undefined
		Or ValuesCache.SelectingTypesOfWarnings.Count() = 0 Then
		
		WarningsTypesFilterPresentation = NStr("en = 'Filter not set';", CommonClient.DefaultLanguageCode());
		
	ElsIf ValuesCache.SelectingTypesOfWarnings.Count() = 1 Then
		
		WarningsTypesFilterPresentation = String(ValuesCache.SelectingTypesOfWarnings[0]);
		
	ElsIf ValuesCache.SelectingTypesOfWarnings.Count() > 8 Then
		
		WarningsTypesFilterPresentation = NStr("en = 'All warning types';", CommonClient.DefaultLanguageCode());
		
	Else
		
		TextTemplate1 = NStr("en = '%1%2 (and %3 more pcs)';", CommonClient.DefaultLanguageCode());
		Triplets = ?(StrLen(TrimAll(ValuesCache.SelectingTypesOfWarnings[0])) > 32, "...", "");
		NumberOfMore = ValuesCache.SelectingTypesOfWarnings.Count() - 1;
		
		WarningsTypesFilterPresentation = StrTemplate(TextTemplate1, Left(TrimAll(ValuesCache.SelectingTypesOfWarnings[0]), 33), Triplets, NumberOfMore);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenTheProblemCard(OpeningParameters)
	Var ObjectWithIssue, WarningType;
	
	OpeningParameters.Property("ObjectWithIssue", ObjectWithIssue);
	OpeningParameters.Property("WarningType", WarningType);
	
	NotifyDescription = New NotifyDescription("AfterClosingTheWarningCard", ThisObject);
	
	If WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.ApplicationAdministrativeError") Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.ApplicationAdministrationWarning", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.BlankAttributes") Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.BlankAttributeWarning", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.UnpostedDocument") Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.UnpostedDocumentWarning", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData")
		Or WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData") Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.ReceiptSendingHandlersWarnings", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = PredefinedValue("Enum.DataExchangeIssuesTypes.ConvertedObjectValidationError") Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.ObjectConversionWarningOnSend", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase
		Or WarningType = ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.WarningByImportRestrictionDate", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	ElsIf WarningType = ValuesCache.RejectedConflictData
		Or WarningType = ValuesCache.ConflictDataAccepted Then
		
		OpenForm("InformationRegister.DataExchangeResults.Form.ConflictWarning", OpeningParameters, ThisObject, , , , NotifyDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterClosingTheWarningCard(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		UpdateTheFormList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeTheWarningStatus(SelectedRows, HideDisplay)
	
	ASetOfStructures = New Array;
	For Each RowIndex In SelectedRows Do
		
		RowData = Items.List.RowData(RowIndex);
		If RowData = Undefined Then
			
			Continue;
			
		EndIf;
		
		StringDataStructure = New Structure("ObjectWithIssue, WarningType, InfobaseNode, UniqueKey, VersionFromOtherApplication");
		FillPropertyValues(StringDataStructure, RowData);
		
		ASetOfStructures.Add(StringDataStructure);
		
	EndDo;
	
	ChangeTheWarningStatusOnTheServer(ASetOfStructures, HideDisplay);
	UpdateTheFormList();
	AvailabilityOfFormListCommands();
	
EndProcedure

&AtClient
Procedure UpdateTheFormList()
	
	If Not Items.ListDisableAutomaticFormUpdates.Check Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AvailabilityOfFormListCommands()
	
	CurrentRowData = Items.List.CurrentData;
	If CurrentRowData = Undefined
		Or TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Then
		
		Items.ListHideWarningsFromTheList.Enabled = False;
		Items.ListShowWarningsInTheList.Enabled = False;
		Items.ListContextMenuHideWarningsFromTheList.Enabled = False;
		Items.ListContextMenuShowWarningsInTheList.Enabled = False;
		Items.ListOpenObject.Enabled = False;
		Items.ListPostDocument.Enabled = False;
		Items.ListBatchEditAttributes.Enabled = False;
		Items.ListConflicts.Enabled = False;
		Items.ListBlockingDownloadsByDate.Enabled = False;
		Return;
		
	EndIf;
	
	Items.ListHideWarningsFromTheList.Enabled = Not CurrentRowData.HideWarning;
	Items.ListShowWarningsInTheList.Enabled = CurrentRowData.HideWarning;
	Items.ListContextMenuHideWarningsFromTheList.Enabled = Not CurrentRowData.HideWarning;
	Items.ListContextMenuShowWarningsInTheList.Enabled = CurrentRowData.HideWarning;
	
	If Items.ListOpenObject.Enabled = False Then
		
		Items.ListOpenObject.Enabled = True;
		Items.ListPostDocument.Enabled = True;
		Items.ListBatchEditAttributes.Enabled = True;
		Items.ListConflicts.Enabled = True;
		Items.ListBlockingDownloadsByDate.Enabled = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DynamicListWithVersioningWarnings()
	
	ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
	QueryTextVersions = ModuleObjectsVersioning.TextOfTheVersionWarningListRequest();
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.QueryText = List.QueryText + Chars.LF + "UNION ALL" + Chars.LF + QueryTextVersions;
	ListProperties.MainTable = "";
	ListProperties.DynamicDataRead = False;
	
	Common.SetDynamicListProperties(Items.List, ListProperties)
	
EndProcedure

&AtServer
Procedure AddDesignFields(ConditionalAppearanceItem, DesignFieldNames)
	
	For Each FieldName In DesignFieldNames Do
		
		AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField(FieldName);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ConditionalFormDesign()
	
	DesignFieldNames = New Array;
	DesignFieldNames.Add("OccurrenceDate");
	DesignFieldNames.Add("ObjectWithIssue");
	DesignFieldNames.Add("LongDesc");
	DesignFieldNames.Add("WarningTypePresentation");
	DesignFieldNames.Add("InfobaseNode");
	DesignFieldNames.Add("UniqueKey");
	
	// Highlight blocking warnings in red.
	TypesOfCriticalWarnings = New ValueList;
	TypesOfCriticalWarnings.Add(Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError);
	TypesOfCriticalWarnings.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData);
	TypesOfCriticalWarnings.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData);
	
	ErrorsInRed = ConditionalAppearance.Items.Add();
	CommonClientServer.AddCompositionItem(ErrorsInRed.Filter, "List.WarningType", DataCompositionComparisonType.InList, TypesOfCriticalWarnings);
	ErrorsInRed.Appearance.SetParameterValue("TextColor", WebColors.DarkRed);
	AddDesignFields(ErrorsInRed, DesignFieldNames);
	
	// Format hidden warnings in gray.
	HiddenWarningsInGray = ConditionalAppearance.Items.Add();
	CommonClientServer.AddCompositionItem(HiddenWarningsInGray.Filter, "List.HideWarning", DataCompositionComparisonType.Equal, True);
	HiddenWarningsInGray.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	AddDesignFields(HiddenWarningsInGray, DesignFieldNames);
	
EndProcedure

&AtServer
Procedure SelectionsBasedOnTheTransmittedParameters()
	
	Parameters.Property("SelectionByDateOfOccurrence", ValuesCache.SelectionByDateOfOccurrence);
	SelectionByDateOfOccurrence();
	
	Parameters.Property("ExchangeNodes", ValuesCache.ArrayOfExchangePlanNodes);
	Parameters.Property("SelectionOfExchangeNodes", ValuesCache.SelectionOfExchangePlanNodes);
	SelectionByNodesOfTheInformationBase();
	
	Parameters.Property("SelectingTypesOfWarnings", ValuesCache.SelectingTypesOfWarnings); 
	SelectionByTypesOfWarnings();
	
	SelectionOfHiddenWarnings()
	
EndProcedure

&AtServer
Procedure SelectionByDateOfOccurrence()
	Var DataSelectionGroup;
	
	If TypeOf(ValuesCache.SelectionByDateOfOccurrence) <> Type("StandardPeriod") Then
		
		ValuesCache.SelectionByDateOfOccurrence = New StandardPeriod;
		
	EndIf;
	
	Use = ValueIsFilled(ValuesCache.SelectionByDateOfOccurrence);
	
	RepresentationOfTheSelectionGroup = NStr("en = 'Filter by issue date';", Common.DefaultLanguageCode());
	
	FindTheSelectionElementOfTheDynamicList(Undefined, DataSelectionGroup, Undefined, RepresentationOfTheSelectionGroup, True);
	If DataSelectionGroup = Undefined Then
		
		DataSelectionGroup = List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		DataSelectionGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
		DataSelectionGroup.Presentation = RepresentationOfTheSelectionGroup;
		DataSelectionGroup.Use = Use;
		
	Else
		
		DataSelectionGroup.Use = Use;
		
	EndIf;
	
	SelectionByDateOfOccurrence = ValuesCache.SelectionByDateOfOccurrence; // StandardPeriod
	
	ParametersOfTheSelectionElement = New Structure;
	ParametersOfTheSelectionElement.Insert("ItemsCollection", DataSelectionGroup.Items);
	ParametersOfTheSelectionElement.Insert("DataFilterItem", Undefined);
	ParametersOfTheSelectionElement.Insert("LeftSelectionValue", New DataCompositionField("OccurrenceDate"));
	ParametersOfTheSelectionElement.Insert("ComparisonType", DataCompositionComparisonType.GreaterOrEqual);
	ParametersOfTheSelectionElement.Insert("RightValue", SelectionByDateOfOccurrence.StartDate);
	ParametersOfTheSelectionElement.Insert("FilterPresentation", NStr("en = 'Filter date from';", Common.DefaultLanguageCode()));
	ParametersOfTheSelectionElement.Insert("Use", Use);
	
	SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement);
	
	ParametersOfTheSelectionElement.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ParametersOfTheSelectionElement.RightValue = SelectionByDateOfOccurrence.EndDate;
	ParametersOfTheSelectionElement.FilterPresentation = NStr("en = 'Filter date to';", Common.DefaultLanguageCode());
	
	SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement);
	
EndProcedure

&AtServer
Procedure SelectionByNodesOfTheInformationBase()
	
	Use = TypeOf(ValuesCache.SelectionOfExchangePlanNodes) = Type("Array")
		And (ValuesCache.SelectionOfExchangePlanNodes.Count() > 0);
		
	ParametersOfTheSelectionElement = New Structure;
	ParametersOfTheSelectionElement.Insert("DataFilterItem", Undefined);
	ParametersOfTheSelectionElement.Insert("LeftSelectionValue", New DataCompositionField("InfobaseNode"));
	ParametersOfTheSelectionElement.Insert("ComparisonType", DataCompositionComparisonType.InList);
	ParametersOfTheSelectionElement.Insert("RightValue", ValuesCache.SelectionOfExchangePlanNodes);
	ParametersOfTheSelectionElement.Insert("FilterPresentation", NStr("en = 'Synchronization filter';", Common.DefaultLanguageCode()));
	ParametersOfTheSelectionElement.Insert("Use", Use);
	
	SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement);
	
EndProcedure

&AtServer
Procedure SelectionByTypesOfWarnings()
	
	Use = TypeOf(ValuesCache.SelectingTypesOfWarnings) = Type("Array")
		And (ValuesCache.SelectingTypesOfWarnings.Count() > 0);
		
	ParametersOfTheSelectionElement = New Structure;
	ParametersOfTheSelectionElement.Insert("DataFilterItem", Undefined);
	ParametersOfTheSelectionElement.Insert("LeftSelectionValue", New DataCompositionField("WarningType"));
	ParametersOfTheSelectionElement.Insert("ComparisonType", DataCompositionComparisonType.InList);
	ParametersOfTheSelectionElement.Insert("RightValue", ValuesCache.SelectingTypesOfWarnings);
	ParametersOfTheSelectionElement.Insert("FilterPresentation", NStr("en = 'Filter by warning type';", Common.DefaultLanguageCode()));
	ParametersOfTheSelectionElement.Insert("Use", Use);

	SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement);
	
EndProcedure

&AtServer
Procedure SelectionOfHiddenWarnings()
	
	Use = Not ValuesCache.WarningsShowHiddenWarnings;
	
	ParametersOfTheSelectionElement = New Structure;
	ParametersOfTheSelectionElement.Insert("DataFilterItem", Undefined);
	ParametersOfTheSelectionElement.Insert("LeftSelectionValue", New DataCompositionField("HideWarning"));
	ParametersOfTheSelectionElement.Insert("ComparisonType", DataCompositionComparisonType.Equal);
	ParametersOfTheSelectionElement.Insert("RightValue", False);
	ParametersOfTheSelectionElement.Insert("FilterPresentation", NStr("en = 'Filter hidden warnings';", Common.DefaultLanguageCode()));
	ParametersOfTheSelectionElement.Insert("Use", Use);

	SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement);
	
EndProcedure

&AtServer
Procedure FindTheSelectionElementOfTheDynamicList(ItemsCollection, DataFilterItem, LeftSelectionValue, FilterPresentation, SearchForAGroupOfElements = False)
	
	If ItemsCollection = Undefined Then
		
		ItemsCollection = List.Filter.Items;
		
	EndIf;
	
	For Each FilterElement In ItemsCollection Do
		
		If SearchForAGroupOfElements
			And TypeOf(FilterElement) = Type("DataCompositionFilterItemGroup")
			And FilterElement.Presentation = FilterPresentation Then
			
			DataFilterItem = FilterElement;
			Break;
			
		ElsIf FilterElement.Presentation = FilterPresentation
			And FilterElement.LeftValue = LeftSelectionValue Then
			
			DataFilterItem = FilterElement;
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTheDynamicListSelectionValue(ParametersOfTheSelectionElement)
	Var ItemsCollection, DataFilterItem, LeftSelectionValue, TypeOfDynamicListSelectionComparison;
	Var RightValue, FilterPresentation, Use;
	
	ParametersOfTheSelectionElement.Property("ItemsCollection", ItemsCollection);
	ParametersOfTheSelectionElement.Property("DataFilterItem", DataFilterItem);
	ParametersOfTheSelectionElement.Property("LeftSelectionValue",	LeftSelectionValue);
	ParametersOfTheSelectionElement.Property("ComparisonType",		TypeOfDynamicListSelectionComparison);
	ParametersOfTheSelectionElement.Property("RightValue",		RightValue);
	ParametersOfTheSelectionElement.Property("FilterPresentation", FilterPresentation);
	ParametersOfTheSelectionElement.Property("Use",		Use);
	
	If ItemsCollection = Undefined Then
		
		ItemsCollection = List.Filter.Items;
		
	EndIf;
	
	If DataFilterItem = Undefined Then
		
		FindTheSelectionElementOfTheDynamicList(ItemsCollection, DataFilterItem, LeftSelectionValue, FilterPresentation);
		
	EndIf;
	
	If DataFilterItem = Undefined Then
		
		DataFilterItem = ItemsCollection.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue = LeftSelectionValue;
		DataFilterItem.ComparisonType = TypeOfDynamicListSelectionComparison;
		DataFilterItem.RightValue = RightValue;
		DataFilterItem.Presentation = FilterPresentation;
		DataFilterItem.Use = Use;
		
	Else
		
		DataFilterItem.RightValue = RightValue;
		DataFilterItem.Use = Use;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeTheWarningStatusOnTheServer(ASetOfStructures, HideDisplay)
	
	For Each StructureWithStringData In ASetOfStructures Do
		
		If TypeOf(StructureWithStringData.WarningType) = Type("EnumRef.DataExchangeIssuesTypes") Then
			
			InformationRegisters.DataExchangeResults.Ignore(StructureWithStringData.ObjectWithIssue, StructureWithStringData.WarningType, HideDisplay,
				StructureWithStringData.InfobaseNode, StructureWithStringData.UniqueKey);
			
		ElsIf Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			
			ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
			ModuleObjectsVersioning.IgnoreObjectVersion(StructureWithStringData.ObjectWithIssue, StructureWithStringData.VersionFromOtherApplication, HideDisplay);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#Region BatchErrorCorrection

&AtClient
Procedure NavigateDocumentsThroughTheSelectedLines(SelectedRows)
	
	DataForSelectedRows = New Array;
	For Each RowIndex In SelectedRows Do
		
		RowData = Items.List.RowData(RowIndex);
		If RowData = Undefined
			Or RowData.WarningType <> PredefinedValue("Enum.DataExchangeIssuesTypes.UnpostedDocument")
			Or Not ValueIsFilled(RowData.ObjectWithIssue)
			Then
			
			Continue;
			
		EndIf;
		
		DataForSelectedRows.Add(RowData.ObjectWithIssue);
		
	EndDo;
	
	If DataForSelectedRows.Count() = 0 Then
		
		ErrorMessage = NStr("en = 'There are no warnings with the <Unposted document> type in the selected lines';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, ErrorMessage);
		Return
		
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("DataForSelectedRows", DataForSelectedRows);
	
	NotifyDescription = New NotifyDescription("AfterGroupProcessingOfWarnings", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.PostingWarningsProcessing", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure CollisionsOnSelectedLines(SelectedRows)
	
	TypesOfCollisionWarnings = New Array(2);
	TypesOfCollisionWarnings[0] = ValuesCache.RejectedConflictData;
	TypesOfCollisionWarnings[1] = ValuesCache.ConflictDataAccepted;
	
	DataForSelectedRows = New Array;
	For Each RowIndex In SelectedRows Do
		
		RowData = Items.List.RowData(RowIndex);
		If RowData = Undefined
			Or TypesOfCollisionWarnings.Find(RowData.WarningType) = Undefined
			Or Not ValueIsFilled(RowData.ObjectWithIssue)
			Then
			
			Continue;
			
		EndIf;
		
		StructureOfData = New Structure;
		StructureOfData.Insert("VersionFromOtherApplication", RowData.VersionFromOtherApplication);
		StructureOfData.Insert("ThisApplicationVersion", RowData.ThisApplicationVersion);
		StructureOfData.Insert("ObjectWithIssue", RowData.ObjectWithIssue);
		
		DataForSelectedRows.Add(StructureOfData);
		
	EndDo;
	
	If DataForSelectedRows.Count() = 0 Then
		
		ErrorMessage = NStr("en = 'There are no warnings with the <Rejected conflict data> and <Received conflict data> types in the selected lines';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, ErrorMessage);
		Return
		
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("DataForSelectedRows", DataForSelectedRows);
	
	NotifyDescription = New NotifyDescription("AfterGroupProcessingOfWarnings", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.ConflictWarningsProcessing", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure ForbiddingLoadingBySelectedLines(SelectedRows)
	
	TypesOfCollisionWarnings = New Array(2);
	TypesOfCollisionWarnings[0] = ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
	TypesOfCollisionWarnings[1] = ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
	
	DataForSelectedRows = New Array;
	For Each RowIndex In SelectedRows Do
		
		RowData = Items.List.RowData(RowIndex);
		If RowData = Undefined
			Or TypesOfCollisionWarnings.Find(RowData.WarningType) = Undefined
			Or Not ValueIsFilled(RowData.ObjectWithIssue)
			Then
			
			Continue;
			
		EndIf;
		
		StructureOfData = New Structure;
		StructureOfData.Insert("VersionFromOtherApplication", RowData.VersionFromOtherApplication);
		StructureOfData.Insert("ThisApplicationVersion", RowData.ThisApplicationVersion);
		StructureOfData.Insert("ObjectWithIssue", RowData.ObjectWithIssue);
		
		DataForSelectedRows.Add(StructureOfData);
		
	EndDo;
	
	If DataForSelectedRows.Count() = 0 Then
		
		ErrorMessage = NStr("en = 'The selected lines do not contain warnings with the <Rejected, existing> and <Rejected, new> types
			|resulted from an attempt to import data to a closed period.';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, ErrorMessage);
		Return
		
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("DataForSelectedRows", DataForSelectedRows);
	
	NotifyDescription = New NotifyDescription("AfterGroupProcessingOfWarnings", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.WarningsProcessingByImportRestrictionDate", OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure GroupChangeOfDetailsForSelectedLines(SelectedRows)
	
	DataForSelectedRows = New Array;
	For Each RowIndex In SelectedRows Do
		
		RowData = Items.List.RowData(RowIndex);
		If RowData = Undefined
			Or RowData.WarningType <> PredefinedValue("Enum.DataExchangeIssuesTypes.BlankAttributes")
			Or Not ValueIsFilled(RowData.ObjectWithIssue)
			Then
			
			Continue;
			
		EndIf;
		
		DataForSelectedRows.Add(RowData.ObjectWithIssue);
		
	EndDo;
	
	If DataForSelectedRows.Count() = 0 Then
		
		ErrorMessage = NStr("en = 'There are no warnings with the <Empty attributes> types in the selected lines.';", CommonClient.DefaultLanguageCode());
		ShowMessageBox(Undefined, ErrorMessage);
		Return
		
	EndIf;
	
	ChangeTheDetailsOfTheGroupProcessing(DataForSelectedRows)
	
EndProcedure

&AtClient
Procedure ChangeTheDetailsOfTheGroupProcessing(DataForSelectedRows)
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		
		Return;
		
	EndIf;
	
	BulkEditParameters = New Structure;
	BulkEditParameters.Insert("ObjectsArray", DataForSelectedRows);
	
	NotifyDescription = New NotifyDescription("AfterGroupProcessingOfWarnings", ThisObject);
	
	ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
	ModuleBatchObjectsModificationClient.StartChangingTheSelectedOnesWithAnAlert(BulkEditParameters, NotifyDescription)
	
EndProcedure

&AtClient
Procedure AfterGroupProcessingOfWarnings(Result, AdditionalParameters) Export
	
	// 
	// 
	// 
	UpdateTheFormList();
	
EndProcedure

#EndRegion

#EndRegion