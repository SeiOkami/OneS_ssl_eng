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
	
	ValuesCache = New Structure("ArrayOfExchangePlanNodes, SelectionByDateOfOccurrence, SelectionOfExchangePlanNodes, SelectingTypesOfWarnings");
	
	SelectionsBasedOnTheTransmittedParameters();
	
	Items.FormPages.CurrentPage = Items.FiltersPage;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FilterByPeriodPresentation();
	RepresentationOfTheSelectionOfExchangeNodes();
	RepresentationOfTheSelectionByTypesOfWarnings();
	
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
	RepresentationOfTheSelectionByTypesOfWarnings();
	
EndProcedure

&AtClient
Procedure RepresentationOfSelectionOfWarningTypesClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteWarnings(Command)
	
	DeleteWarningsInALongOperation();
	AfterTheStartOfALongTermOperation();
	
EndProcedure

#EndRegion

#Region Private

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
		Triplets = ?(StrLen(TrimAll(ValuesCache.SelectionOfExchangePlanNodes[0])) > 29, "...", "");
		NumberOfMore = ValuesCache.SelectionOfExchangePlanNodes.Count() - 1;
		
		SynchronizationsFilterPresentation = StrTemplate(TextTemplate1, Left(TrimAll(ValuesCache.SelectionOfExchangePlanNodes[0]), 30), Triplets, NumberOfMore);
		
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
		Triplets = ?(StrLen(TrimAll(ValuesCache.SelectingTypesOfWarnings[0])) > 29, "...", "");
		NumberOfMore = ValuesCache.SelectingTypesOfWarnings.Count() - 1;
		
		WarningsTypesFilterPresentation = StrTemplate(TextTemplate1, Left(TrimAll(ValuesCache.SelectingTypesOfWarnings[0]), 30), Triplets, NumberOfMore);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowErrorToUser()
	
	Items.FormPages.CurrentPage = Items.ErrorPage;
	ErrorDescription = TimeConsumingOperation.DetailErrorDescription;
	
EndProcedure

&AtClient
Procedure AfterTheStartOfALongTermOperation()
	
	If TypeOf(TimeConsumingOperation) = Type("Structure")
		And TimeConsumingOperation.Status = "Error" Then
		
		ShowErrorToUser();
		Return;
		
	EndIf;
	
	Items.FormPages.CurrentPage = Items.TimeConsumingOperationPage;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputMessages = True;
	IdleParameters.OutputProgressBar = True;
	IdleParameters.ExecutionProgressNotification = New NotifyDescription("ProgressOfDeletingSynchronizationWarnings", ThisObject); 
	
	CompletionNotification2 = New NotifyDescription("AfterFinishTimeConsumingOperation", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtClient
Procedure AfterFinishTimeConsumingOperation(Result, AdditionalParameters) Export
	
	If TypeOf(TimeConsumingOperation) = Type("Structure")
		And TimeConsumingOperation.Status = "Error" Then
		
		ShowErrorToUser();
		Return;
		
	EndIf;
	
	Items.FormPages.CurrentPage = Items.PageDone;
	
EndProcedure

&AtClient
Procedure ProgressOfDeletingSynchronizationWarnings(Result, AdditionalParameters) Export
	
	If Result = Undefined
		Or Result.Status <> "Running" Then
		
		Return;
		
	EndIf;
	
	If Result.Progress <> Undefined Then
		
		Indication = ?(Result.Progress.Percent < 1, 1, Result.Progress.Percent);
		Items.Indication.ToolTip = Result.Progress.Text;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SelectionsBasedOnTheTransmittedParameters()
	
	Parameters.Property("ArrayOfExchangePlanNodes", ValuesCache.ArrayOfExchangePlanNodes);
	Parameters.Property("SelectionByDateOfOccurrence", ValuesCache.SelectionByDateOfOccurrence);
	Parameters.Property("SelectionOfExchangeNodes", ValuesCache.SelectionOfExchangePlanNodes);
	Parameters.Property("SelectingTypesOfWarnings", ValuesCache.SelectingTypesOfWarnings); 
	
	If Not Parameters.Property("OnlyHiddenRecords", OnlyHiddenRecords) Then
		
		OnlyHiddenRecords = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SortWarningsByType(DeletionParameters)
	
	SelectionOfTypesOfExchangeWarnings = New Array;
	SelectingTheTypesOfVersionWarnings = New Array;
	
	ExchangeValues = New Array;
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError);
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError);
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData);
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.UnpostedDocument);
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.BlankAttributes);
	ExchangeValues.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData);
	
	VersionValues = New Array;
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		EnumManager = Enums["ObjectVersionTypes"];
		VersionValues.Add(EnumManager.RejectedConflictData);
		VersionValues.Add(EnumManager.ConflictDataAccepted);
		VersionValues.Add(EnumManager.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
		VersionValues.Add(EnumManager.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
		
	EndIf;
	
	If ValuesCache.SelectingTypesOfWarnings.Count() > 0 Then
		
		For Each ArrayElement In ValuesCache.SelectingTypesOfWarnings Do
			
			If ExchangeValues.Find(ArrayElement) <> Undefined Then
				
				SelectionOfTypesOfExchangeWarnings.Add(ArrayElement);
				
			EndIf;
			
			If VersionValues.Find(ArrayElement) <> Undefined Then
				
				SelectingTheTypesOfVersionWarnings.Add(ArrayElement);
				
			EndIf;
			
		EndDo;
		
	Else
		
		SelectionOfTypesOfExchangeWarnings = ExchangeValues;
		SelectingTheTypesOfVersionWarnings = VersionValues;
		
	EndIf;
	
	DeletionParameters.Insert("SelectionOfTypesOfExchangeWarnings", SelectionOfTypesOfExchangeWarnings);
	DeletionParameters.Insert("SelectingTheTypesOfVersionWarnings", SelectingTheTypesOfVersionWarnings);
	
EndProcedure

&AtServer
Procedure DeleteWarningsInALongOperation()
	
	If TimeConsumingOperation <> Undefined Then
		
		TimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
		
	EndIf;
	
	Items.FormPages.CurrentPage = Items.TimeConsumingOperationPage;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Delete synchronization warnings';", Common.DefaultLanguageCode());
	
	DeletionParameters = New Structure;
	DeletionParameters.Insert("SelectionByDateOfOccurrence", ValuesCache.SelectionByDateOfOccurrence);
	DeletionParameters.Insert("SelectionOfExchangePlanNodes", ValuesCache.SelectionOfExchangePlanNodes);
	DeletionParameters.Insert("OnlyHiddenRecords", OnlyHiddenRecords);
	SortWarningsByType(DeletionParameters);
	
	OperationsCount = DeletionParameters.SelectionOfTypesOfExchangeWarnings.Count() + DeletionParameters.SelectingTheTypesOfVersionWarnings.Count();
	
	DeletionParameters.Insert("MaximumNumberOfOperations", OperationsCount);
	DeletionParameters.Insert("NumberOfOperationsCurrentStep", 0);
	
	MethodParameters = New Structure("DeletionParameters", DeletionParameters);
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground("InformationRegisters.DataExchangeResults.ClearSynchronizationWarnings", MethodParameters, ExecutionParameters);
	
	Items.FormRemoveWarnings.Enabled = False;
	
EndProcedure

#EndRegion