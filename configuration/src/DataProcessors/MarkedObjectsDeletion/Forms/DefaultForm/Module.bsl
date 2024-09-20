///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

// 
&AtClient
Var CurrentOperation1; // See TimeConsumingOperations.ExecuteFunction

&AtClient
Var PresentationOperation; // String

&AtClient
Var DeletionResultsInfo; // See MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo

&AtClient
Var FormJobsQueue; // Array of String

&AtClient
Var PreviousStepResult;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Users.IsFullUser() Then
		ErrorText = NStr("en = 'Insufficient rights to perform the operation.';");
		Return; // Cancel is set in OnOpen.
	EndIf;
	
	If Common.DataSeparationEnabled() And Not Common.SeparatedDataUsageAvailable() Then
		ErrorText = NStr("en = 'To delete marked objects, sign in to the data area.';");
		Return; // Cancel is set in OnOpen.
	EndIf;
	
	If Parameters.ObjectsToDelete.Count() > 0 Then
		ConfigureFormToWorkAsService();
	Else
		ToStartSearchingForTheMarkedSettingOfTheForm(ThisObject);
	EndIf;
	
	If Parameters.MetadataFilter.Count() > 0 Then
		SetPassedMetadataFilter();
	EndIf;
	
	IsMobileClient = Common.IsMobileClient();
	If IsMobileClient Then
		Items.MarkedForDeletionItemsTreeConfigure.Visible = False;
		Items.MarkedForDeletionItemsTreeChange.Visible = False;
		Items.NotDeletedItemsChange.Visible = False;
		Items.Actions.Visible = False;
		Items.Back.Visible = False;
	EndIf;
	
	SetObjectsMarkedForDeletionSelectionState();
	SetConditionalAppearance();	
	SetUsageInstancesActionsList(ThisObject);
	
	ReadOnly = True;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	AdditionalAttributesSettings = Settings["AdditionalAttributesOfItemsMarkedForDeletion"];
	If AdditionalAttributesSettings <> Undefined Then
		AdditionalAttributesNumber = MarkedObjectsDeletionInternal.AdditionalAttributesNumber(
			AdditionalAttributesSettings);
		AddAdditionalAttributes(1, AdditionalAttributesNumber);
		SetConditionalAppearance();
	EndIf;
	
	Filter_Settings = Settings["MetadataFilter"];
	If ValueIsFilled(Filter_Settings) Then
		MetadataFilter = SelectionOfMetadataOnlyExisting(Filter_Settings);
		Items.ConfigureFilter.Title = MetadataFilterPresentation(Filter_Settings);
	ElsIf ValueIsFilled(Parameters.MetadataFilter) Then 
		MetadataFilter = Parameters.MetadataFilter;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(ErrorText) Then
		ShowMessageBox(, ErrorText);
		Cancel = True;
	EndIf;
	
	If DeleteOnOpen Then
		AddJob(FormJobs().DeleteMarkedObjects);
	Else	
		AddJob(FormJobs().MarkedObjectsSearch);
	EndIf;
	AttachIdleHandler("RunJobWithPending", 0.1, True);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If Exit Then
		Return;
	EndIf;
	
	If ShowDialogBeforeClose Then
		Cancel = True;
		Handler = New NotifyDescription("AfterConfirmCancelJob", ThisObject);
		QueryText = NStr("en = 'In progress %1.
							|Do you want to stop it?';");
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort);
		Buttons.Add(DialogReturnCode.Ignore, NStr("en = 'Do not stop';"));
		
		ShowQueryBox(Handler, 
			StringFunctionsClientServer.SubstituteParametersToString(QueryText, Lower(PresentationOperation)),
		 	Buttons, 60, DialogReturnCode.Ignore);
	ElsIf DeleteOnOpen Then 
		OnCloseNotifyDescription.AdditionalParameters.Insert("ClosingResult", DeletionResultsInfo);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DetailsRefClick(Item)
	If IsExclusiveModeSettingError(DetailedBackgroundJobErrorText) Then
		ToOpenTheFormCompleteTheUserExperience();
	Else	
		ErrorText = ?(Item.Name = Items.DetailsBackgroundJobError.Name, DetailedBackgroundJobErrorText, DetailedErrorText);
		StandardSubsystemsClient.ShowDetailedInfo(Undefined, ErrorText);
	EndIf;
EndProcedure

&AtClient
Procedure CancelOperation(Command)
	CancelOperationServer(CurrentOperation1);
	ClearFormJobsQueue();
	
	If CurrentJob().Name = "AdditionalDataProcessorExecution" Then
		SetStateUnsuccessfulDeletion();
	Else
		SetObjectsMarkedForDeletionSelectionState();
	EndIf;
	
	ShowDialogBeforeClose = False;
	CurrentOperation1 = Undefined;
	If DeleteOnOpen Then
		Close();
	EndIf;
EndProcedure

&AtServer
Procedure CancelOperationServer(CurrentOperation1)
	If CurrentOperation1 = Undefined Then
		Return;
	EndIf;
	
	TimeConsumingOperations.CancelJobExecution(CurrentOperation1.JobID);
	MarkedObjectsDeletionInternal.UnlockUsageOfObjectsToDelete(UUID);
	SetExclusiveModeAtServer(False);
EndProcedure

&AtClient
Procedure TotalObjectsToSelect(Command)
	Notification = New NotifyDescription("TotalObjectsToSelectCompletion", ThisObject);
	If ActionsTable.Count() > 0 Then
		ShowQueryBox(Notification, 
			NStr("en = 'Object deletion is not completed.
			|Go back to the list of objects marked for deletion?';"),
			QuestionDialogMode.YesNo);
	Else
		UpdateTheTreeMarkedForDeletion();
		SetObjectsMarkedForDeletionSelectionState();
	EndIf;
EndProcedure

&AtClient
Procedure TotalObjectsToSelectCompletion(Result, AdditionalParameters) Export
	UpdateTheTreeMarkedForDeletion();
	If Result = DialogReturnCode.Yes Then
		ActionsTable.Clear();
		SetObjectsMarkedForDeletionSelectionState();
	EndIf;
EndProcedure

#EndRegion

#Region MarkedForDeletionItemsTreeFormTableItemEventHandlers

&AtClient
Procedure MarkedForDeletionItemsTreeCheckOnChange(Item)
	CurrentData = Items.MarkedForDeletionItemsTree.CurrentData;
	If CurrentData.Check = 2 Then
		CurrentData.Check = 0;
	EndIf;
	
	MarkedForDeletionItemsTreeSetMarkInList(CurrentData, CurrentData.Check, True);
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

#EndRegion

#Region NotTrashFormTableItemEventHandlers

&AtClient
Procedure NotDeletedItemsOnActivateRow(Item)
	AttachIdleHandler("ShowNotDeletedItemsLinksAtClient", 0.1, True);
EndProcedure

&AtClient
Procedure NotDeletedItemsBeforeRowChange(Item, Cancel)
	Cancel = True;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure NotDeletedItemsSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure NotDeletedItemsPresentationOpening(Item, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure NotDeletedItemsLinksChoice(Item, RowSelected, Field, StandardProcessing)
	If Field.Name <> Items.NotDeletedItemRelationsAction.Name Then
		StandardProcessing = False;
		ShowTableObject(Item);
	EndIf;
EndProcedure

&AtClient
Procedure NotDeletedItemsUsageInstancesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	SetReplaceWithContinue(ValueSelected);
EndProcedure

&AtClient
Procedure NotDeletedItemRelationsActionOnChange(Item)
	CurrentData = Items.NotDeletedItemsUsageInstances.CurrentData;
	ValueSelected = CurrentData.ActionPresentation;
	
	If Not ValueIsFilled(ValueSelected) Then
		
		If CurrentData.Action = "ReplaceRef" Then
			For Each Item In NotDeletedItemsUsageInstances.GetItems() Do
				Item.Action = Undefined;
			EndDo;	
			
			Filter = New Structure("Source", CurrentData.ItemToDeleteRef);
			Actions = ActionsTable.FindRows(Filter);
			For Each Action In Actions Do
				ActionsTable.Delete(Action);
			EndDo;
		Else			
			CurrentData.Action = Undefined;
			
			Filter = New Structure("FoundItemReference", CurrentData.FoundItemReference);
			Actions = ActionsTable.FindRows(Filter);
			For Each Action In Actions Do
				ActionsTable.Delete(Action);
			EndDo;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure NotDeletedItemRelationsActionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	CurrentData = Items.NotDeletedItemsUsageInstances.CurrentData;
	CurrentData.ActionPresentation = "";
	
	WhenSelectingAPlaceOfUseAction(ValueSelected, CurrentData);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	If CurrentOperation1 = Undefined Then
		RunJob(FormJobs().MarkedObjectsSearch);
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteActionsAndDelete(Command)
	UpdateTheTreeMarkedForDeletion();
	InformationAboutTheSelectedObjects = SelectedObjectsCount();
	SelectedCountTotal = InformationAboutTheSelectedObjects.SelectedCount;
	If SelectedCountTotal = 0 Then
		WarningText = NStr("en = 'Select at least one item to be deleted.';");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	AddJob(FormJobs().AdditionalDataProcessorExecution);
	AddJob(FormJobs().DeleteMarkedObjects);
	RunJob();
EndProcedure

&AtClient
Procedure NotDeletedItemsChange(Command)
	If Not CommonClientServer.HasAttributeOrObjectProperty(CurrentItem, "CurrentData") Then
		Return;
	EndIf;

	ShowTableObject(CurrentItem);	
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeSelectAll(Command)
	ListItems = MarkedForDeletionItemsTree.GetItems();
	
	For Each Item In ListItems Do
		MarkedForDeletionItemsTreeSetMarkInList(Item, True, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			MarkedForDeletionItemsTreeCheckParent(Item)
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeClearAll(Command)
	ListItems = MarkedForDeletionItemsTree.GetItems();
	
	For Each Item In ListItems Do
		MarkedForDeletionItemsTreeSetMarkInList(Item, False, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			MarkedForDeletionItemsTreeCheckParent(Item)
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeChange(Command)
	ShowTableObject(Items.MarkedForDeletionItemsTree);
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeUpdate(Command)
	RunJob(FormJobs().MarkedObjectsSearch);
EndProcedure

&AtClient
Procedure InstallDelete(Command)
	For Each RowID In Items.NotDeletedItemsUsageInstances.SelectedRows Do
		SelectedRow = NotDeletedItemsUsageInstances.FindByID(RowID);
		WhenSelectingAPlaceOfUseAction("Delete", SelectedRow);
	EndDo;
	
	FillNotDeletedObjectsUsageInstances(ThisObject);
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "NotDeletedItemsUsageInstances", "*", True);
EndProcedure

&AtClient
Procedure SetReplaceWith(Command)
	CurrentData = Items.NotDeletedItemsUsageInstances.CurrentData;
	
	If CurrentData = Undefined Then
		Status(NStr("en = 'Cannot specify an action for the selected row.';"),,,PictureLib.Warning32);
		Return;
	EndIf;
	
	If CurrentData.MainReason Then
		FormPath = NameOfMetadataObjects(CurrentData.ItemToDeleteRef) + ".ChoiceForm";
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		OpenForm(FormPath, FormParameters, Items.NotDeletedItemsUsageInstances, , , , , FormWindowOpeningMode.LockOwnerWindow);
	Else
		Status(NStr("en = 'Cannot specify an action for the selected row.';"),,,PictureLib.Warning32);
	EndIf;
EndProcedure

&AtClient
Procedure SetReplaceWithContinue(Result)
	CurrentData = Items.NotDeletedItemsUsageInstances.CurrentData;
	
	For Each RowID In Items.NotDeletedItemsUsageInstances.SelectedRows Do
		SelectedRow = NotDeletedItemsUsageInstances.FindByID(RowID);
		
		If SelectedRow.ItemToDeleteRef <> CurrentData.ItemToDeleteRef Then
			Continue;
		EndIf;
		
		If Result = Undefined Then
			RegisterUsageInstanceAction(SelectedRow, Undefined);
		Else
			If SelectedRow.MainReason Then
				RegisterUsageInstanceAction(SelectedRow, "ReplaceRef", Result);
			EndIf;
		EndIf;
	EndDo;
	
	For Each SelectedRow In NotDeletedItemsUsageInstances.GetItems() Do
		If SelectedRow.MainReason 
				And SelectedRow.Action <> "Delete" Then
			RegisterUsageInstanceAction(SelectedRow, "ReplaceRef", Result);
		EndIf;
	EndDo;
	
	FillNotDeletedObjectsUsageInstances(ThisObject);
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "NotDeletedItemsUsageInstances", "*", True);
EndProcedure

&AtClient
Procedure Customize(Command)
	ClosingNotification1 = New NotifyDescription("ConfigureFollowUp", ThisObject);
	
	FormParameters = New Structure("SettingsAddress", MarkedObjectsDeletionSettings());
	OpenForm("DataProcessor.MarkedObjectsDeletion.Form.ObjectsDeletionSettings", FormParameters, ThisObject, , , ,
		ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtServer
Function MarkedObjectsDeletionSettings()
	Settings = New Structure;
	Settings.Insert("DeletionMode", DeletionMode);
	Settings.Insert("SelectedAttributes", AdditionalAttributesOfItemsMarkedForDeletion.Unload());
	Return PutToTempStorage(Settings, UUID);
EndFunction

&AtClient
Procedure ConfigureFollowUp(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	ObjectsMarkedForDeletionUpdateRequired = ConfigureFollowUpServer(Result);
	If ObjectsMarkedForDeletionUpdateRequired Then
		RunJob(FormJobs().MarkedObjectsSearch);
	EndIf;
EndProcedure

&AtServer
Function ConfigureFollowUpServer(SettingsAddress)
	Settings = GetFromTempStorage(SettingsAddress);
	DeleteFromTempStorage(SettingsAddress);
	DeletionMode = Settings.DeletionMode;

	SettingsChanged = SettingsChanged(Settings.SelectedAttributes);

	CurrentAdditionalAttributesCount = MarkedObjectsDeletionInternal.AdditionalAttributesNumber(
		AdditionalAttributesOfItemsMarkedForDeletion.Unload());
	NewAdditionalAttributesNumber = MarkedObjectsDeletionInternal.AdditionalAttributesNumber(Settings.SelectedAttributes);
	CurrentGeneratedAttributesCount = CurrentGeneratedAttributesCount(CurrentAdditionalAttributesCount, NewAdditionalAttributesNumber);

	If CurrentGeneratedAttributesCount < NewAdditionalAttributesNumber Then
		AttributesToAddNumber = NewAdditionalAttributesNumber - CurrentGeneratedAttributesCount;
		AddAdditionalAttributes(CurrentGeneratedAttributesCount + 1, AttributesToAddNumber);
	EndIf;
	
	If CurrentAdditionalAttributesCount < CurrentGeneratedAttributesCount 
		And CurrentAdditionalAttributesCount < NewAdditionalAttributesNumber Then
		
		SetAdditionalAttributesVisibility(CurrentAdditionalAttributesCount+1, CurrentGeneratedAttributesCount, True);
	EndIf;

	If CurrentAdditionalAttributesCount > NewAdditionalAttributesNumber Then
		SetAdditionalAttributesVisibility(NewAdditionalAttributesNumber+1,
			CurrentAdditionalAttributesCount, False);
	EndIf;
	
	AdditionalAttributesOfItemsMarkedForDeletion.Load(Settings.SelectedAttributes);
	
	SetConditionalAppearance();
	
	Return NewAdditionalAttributesNumber > CurrentAdditionalAttributesCount Or SettingsChanged;
EndFunction

&AtClient
Procedure DeleteSelectedItems(Command)
	
	InformationAboutTheSelectedObjects = SelectedObjectsCount();
	SelectedCountTotal = InformationAboutTheSelectedObjects.SelectedCount;
	If SelectedCountTotal = 0 Then
		QueryText = NStr("en = 'Select at least one item to be deleted.';");
		ShowMessageBox(, QueryText);
		Return;
	ElsIf SelectedCountTotal = 1 Then
		QueryText = NStr("en = 'Delete the item marked for deletion?';");
	ElsIf SelectedCountTotal = InformationAboutTheSelectedObjects.TotalCount1 Then
		QueryText = NStr("en = 'Delete all items marked for deletion?';");
	Else
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Delete the items marked for deletion (%1)?';"),
			SelectedCountTotal);
	EndIf;
	
	NotificationConfirmationDeleteAll = New NotifyDescription("OnConfirmationDelete",
		ThisObject, InformationAboutTheSelectedObjects);
	ShowQueryBox(NotificationConfirmationDeleteAll, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ConfigureFilter(Command)
	ObjectsToSelectCollection = New ValueList();
	
	ObjectsToSelectCollection.Add("Catalogs");
	ObjectsToSelectCollection.Add("Documents");
	ObjectsToSelectCollection.Add("ChartsOfCharacteristicTypes");
	ObjectsToSelectCollection.Add("ChartsOfAccounts");
	ObjectsToSelectCollection.Add("ChartsOfAccounts");
	ObjectsToSelectCollection.Add("ChartsOfCalculationTypes");
	ObjectsToSelectCollection.Add("BusinessProcesses");
	ObjectsToSelectCollection.Add("Tasks");
	
	FormParameters = New Structure;
	FormParameters.Insert("MetadataObjectsToSelectCollection", ObjectsToSelectCollection);
	FormParameters.Insert("SearchAreas", MetadataFilter);
	FormParameters.Insert("SubsystemsWithCIOnly", True);
	
	ClosingNotification1 = New NotifyDescription("ConfigureFilterCompletion", ThisObject);
	OpenForm("DataProcessor.MarkedObjectsDeletion.Form.SelectMetadataObjectsBySubsystems", FormParameters, ThisObject, , , , ClosingNotification1,
		FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure ExpandRowsOfMarkedObjectsTree(Command)
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "MarkedForDeletionItemsTree");
EndProcedure

&AtClient
Procedure CollapseMarkedObjectTreeRows(Command)
	AllRows = Items.MarkedForDeletionItemsTree;
	For Each RowData In MarkedForDeletionItemsTree.GetItems() Do 
		AllRows.Collapse(RowData.GetID());
	EndDo;
EndProcedure

&AtClient
Procedure SetClearDeletionMark(Command)
	
	ReferencesToProcess = New Array;
	ViewOfTheLastSelectedOne = "";
	TheNumberOfItemsWithTheUncheckedLabel = 0;
	For Each SelectedRow In Items.NotTrash.SelectedRows Do
		Data = Items.NotTrash.RowData(SelectedRow);
		If TypeOf(Data.ItemToDeleteRef) <> Type("String") Then
			ReferencesToProcess.Add(Data.ItemToDeleteRef);
			ViewOfTheLastSelectedOne = Data.Presentation;
		EndIf;
		
		If ItemsWithoutDeletionMark.FindByValue(Data.ItemToDeleteRef) <> Undefined Then
			TheNumberOfItemsWithTheUncheckedLabel = TheNumberOfItemsWithTheUncheckedLabel + 1;
		EndIf;
	EndDo;
	
	SetATag = ReferencesToProcess.Count() = TheNumberOfItemsWithTheUncheckedLabel
							And TheNumberOfItemsWithTheUncheckedLabel <> 0;
	
	Handler = New NotifyDescription("SetClearDeletionMarkFollowUp", ThisObject, ReferencesToProcess);
	If ReferencesToProcess.Count() = 1 Then
		If SetATag Then
			QueryText = NStr("en = 'Mark ""%1"" for deletion?';");
		Else
			QueryText = NStr("en = 'Clear the deletion mark from ""%1""?';");
		EndIf;
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, ViewOfTheLastSelectedOne);
	Else
		If SetATag Then
			QueryText = NStr("en = 'Mark the selected objects (%1) for deletion?';");
		Else
			QueryText = NStr("en = 'Clear the deletion mark from the selected objects (%1)?';");
		EndIf;
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, Format(ReferencesToProcess.Count(), "NZ=0; NG="));
	EndIf;
	
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure SetClearDeletionMarkFollowUp(Result, ReferencesToProcess) Export

	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Changes = Undefined;
	Try
		Changes = SetUncheckDeleteOnTheServer(ReferencesToProcess);
	Except
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		ErrorText = NStr("en = 'Cannot change the deletion mark due to:';")
			+ Chars.LF + ErrorText;
		ShowMessageBox(, ErrorText);
	EndTry;
	
	If Changes <> Undefined Then
		StandardSubsystemsClient.NotifyFormsAboutChange(Changes);
	EndIf;	
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "NotTrash", "*", True);	

EndProcedure

&AtServer
Function SetUncheckDeleteOnTheServer(References)
	
	Try
		Changes = MarkedObjectsDeletionInternal.RemovePutATickRemoval(References);
	Except
		WriteLogEvent(
			NStr("en = 'Delete marked objects.Toggle deletion mark';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Result = New Array;
	NotDeletedItemsTree = FormAttributeToValue("NotTrash");
	TypesInformation = MarkedObjectsDeletionInternal.TypesInformation(Changes.UnloadColumn("Ref"));

	For Each Update In Changes Do
		
		TypeInformation = TypesInformation[TypeOf(Update.Ref)]; // See MarkedObjectsDeletionInternal.TypeInformation
		MetadataStrings = NotDeletedItemsTree.Rows.FindRows(
			New Structure("ItemToDeleteRef", TypeInformation.FullName))[0].Rows;
		Data = MetadataStrings.FindRows(New Structure("ItemToDeleteRef", Update.Ref))[0];
		
		Data.PictureNumber = MarkedObjectsDeletionInternal.PictureNumber(Update.Ref,
			TypeInformation.Referential, TypeInformation.Kind,
			?(Update.DeletionMarkNewValue = True, "Removed", Undefined));
		Result.Add(Update.Ref);

		If Not Update.DeletionMarkNewValue Then
			ItemsWithoutDeletionMark.Add(Update.Ref);
		Else
			ListItem = ItemsWithoutDeletionMark.FindByValue(Update.Ref);
			If ListItem <> Undefined Then
				ItemsWithoutDeletionMark.Delete(ListItem);
			EndIf;
		EndIf;

	EndDo;

	ValueToFormAttribute(NotDeletedItemsTree, "NotTrash");	
	Return StandardSubsystemsServer.PrepareFormChangeNotification(Result);
	
EndFunction

#EndRegion

#Region Private

#Region FormStates

&AtServer
Procedure SetObjectsMarkedForDeletionSelectionState()
	Items.CommandBarForm.Enabled = True;
	Items.RunningState.Visible = False;
	Items.InformationPages.Enabled = True;
	
	Items.InformationPages.CurrentPage = Items.ObjectsToProcessChoicePage;
	Items.StatePresentationPages.Visible = False;
	Items.InformationPages.ReadOnly = False;
	Items.ActiveAfterSearchMarkedObjectsGroup.Enabled = MarkedForDeletionItemsTree.GetItems().Count() > 0;
	
	Items.CommandBarMarkedObjectsSearch.Visible = True;
	Items.CommandBarErrorsProcessing.Visible = False;
	
	Items.SearchFilterSettingsGroup.Enabled = True;
	Items.ProgressPresentation.Visible = False;
	Items.MarkedForDeletionItemsTreeDeleteSelectedItems.DefaultButton = True;
	Items.SearchStringForDeletion.Visible = True;
EndProcedure

&AtServer
Procedure SetObjectsMarkedForDeletionSelectionStateWithStatePanel()
	Items.CommandBarForm.Enabled = True;
	Items.RunningState.Visible = True;
	Items.InformationPages.Enabled = True;
	
	Items.InformationPages.CurrentPage = Items.ObjectsToProcessChoicePage;
	Items.StatePresentationPages.Visible = True;
	Items.InformationPages.ReadOnly = False;
	
	Items.CommandBarMarkedObjectsSearch.Visible = True;
	Items.CommandBarErrorsProcessing.Visible = False;
	
	Items.SearchFilterSettingsGroup.Enabled = True;
	Items.ProgressPresentation.Visible = False;
	Items.MarkedForDeletionItemsTreeDeleteSelectedItems.DefaultButton = True;
	Items.ActiveAfterSearchMarkedObjectsGroup.Enabled = MarkedForDeletionItemsTree.GetItems().Count() > 0;
	Items.SearchStringForDeletion.Visible = False;
EndProcedure

&AtServer
Procedure SetStateUnsuccessfulDeletion()
	Items.CommandBarForm.Enabled = True;
	Items.RunningState.Visible = False;
	Items.InformationPages.Enabled = True;
	Items.InformationPages.Visible = True;
	
	Items.InformationPages.CurrentPage = Items.DeletionFailureReasonsPage;
	Items.StatePresentationPages.Visible = False;
	Items.InformationPages.ReadOnly = False;
	Items.ActiveAfterSearchMarkedObjectsGroup.ReadOnly = False;
	
	Items.CommandBarMarkedObjectsSearch.Visible = False;
	Items.CommandBarErrorsProcessing.Visible = True;
	
	Items.SearchFilterSettingsGroup.Enabled = False;
	Items.ProgressPresentation.Visible = False;
	Items.CommandBarForm.Visible = True;
	Items.ExecuteActionsAndDelete.DefaultButton = True;
	Items.DetailsRef.Visible = False;
	Items.SearchStringForDeletion.Visible = False;
EndProcedure

&AtServer
Procedure SetStateUnsuccessfulDeletionWithStatePanel()
	Items.CommandBarForm.Enabled = True;
	Items.RunningState.Visible = True;
	Items.InformationPages.Enabled = True;
	Items.InformationPages.Visible = True;
	
	Items.InformationPages.CurrentPage = Items.DeletionFailureReasonsPage;
	Items.StatePresentationPages.Visible = True;
	Items.InformationPages.ReadOnly = False;
	Items.ActiveAfterSearchMarkedObjectsGroup.ReadOnly = False;
	
	Items.CommandBarMarkedObjectsSearch.Visible = False;
	Items.CommandBarErrorsProcessing.Visible = True;
	
	Items.SearchFilterSettingsGroup.Enabled = False;
	Items.ProgressPresentation.Visible = False;
	Items.CommandBarForm.Visible = True;
	Items.ExecuteActionsAndDelete.DefaultButton = True;
	
	If IsMobileClient Then
		Items.NotDeletedItemsGroup.Visible = False;
	EndIf;
	Items.DetailsRef.Visible = False;
	Items.SearchStringForDeletion.Visible = False;
EndProcedure

#EndRegion

// Parameters:
//   Ref - AnyRef
// Returns:
//   String
//
&AtServerNoContext
Function NameOfMetadataObjects(Ref)
	Return Ref.Metadata().FullName();
EndFunction

&AtClient
Procedure UpdateTheTreeMarkedForDeletion()
	UpdateTheTreeMarkedForDeletionOnTheServer();
	
	
EndProcedure

&AtServer
Procedure UpdateTheTreeMarkedForDeletionOnTheServer()

	MarkedForDeletion = FormAttributeToValue("MarkedForDeletionItemsTree");
	For Each ListItem In ItemsWithoutDeletionMark Do
	
		MetadataKind = MarkedForDeletion.Rows.FindRows(
							New Structure("ItemToDeleteRef", Upper(NameOfMetadataObjects(ListItem.Value))))[0];
		LinesToDelete = MetadataKind.Rows.FindRows(
							New Structure("ItemToDeleteRef", ListItem.Value));
		For Each TreeRow In LinesToDelete Do
			MetadataKind.Rows.Delete(TreeRow);
		EndDo;
		
		If MetadataKind.Rows.Count() = 0 Then
			MarkedForDeletion.Rows.Delete(MetadataKind);
		EndIf;
	
	EndDo;
	
	For Each NodeOfType In MarkedForDeletion.Rows Do
		NodeElements = NodeOfType.Rows;
		NodeOfType.Check = ItemMarkValues(NodeElements);
		If NodeOfType.Rows.Count() > 0 Then
			NodeMetadataObject = NodeOfType.Rows[0].ItemToDeleteRef.Metadata();
			NodeOfType.Presentation = Common.ListPresentation(NodeMetadataObject) + " (" + NodeOfType.Rows.Count() + ")";
		EndIf;
	EndDo;
	
	ValueToFormAttribute(MarkedForDeletion, "MarkedForDeletionItemsTree");
	ItemsWithoutDeletionMark.Clear();

EndProcedure

#Region Settings

&AtServer
Function SettingsChanged(SelectedAttributes)
	Result = False;
	
	ComparisonTable = MarkedObjectsDeletionInternal.TablesMerge(
		SelectedAttributes,
		AdditionalAttributesOfItemsMarkedForDeletion.Unload());
		
	ComparisonTable.Columns.Add("Number", New TypeDescription("Number"));
	ComparisonTable.FillValues(1,"Number");
	ComparisonTable.GroupBy("Metadata, Attribute", "Number");
	For Each Item In ComparisonTable Do
		If Item.Number <> 2 Then
			Result = True;
			Break;
		EndIf;
	EndDo;
	
	Return Result;		
EndFunction

&AtServer
Function CurrentGeneratedAttributesCount(CurrentAdditionalAttributesCount, NewAdditionalAttributesNumber)
	Result = CurrentAdditionalAttributesCount;
	
	For Cnt = CurrentAdditionalAttributesCount + 1 To NewAdditionalAttributesNumber Do
		If Items.Find("MarkedForDeletionItemsTreeAttribute"+Cnt) <> Undefined Then
			Result = Cnt;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure SetAdditionalAttributesVisibility(InitialNumber, EndNumber, Visible)
	For Cnt = InitialNumber To EndNumber Do
		Items["MarkedForDeletionItemsTreeAttribute" + Cnt].Visible = Visible;
	EndDo;
EndProcedure

&AtServer
Procedure AddAdditionalAttributes(InitialNumber, AttributesToAddNumber)
	AttributesToBeAdded = New Array;
	LastDigitInAttributeName = InitialNumber+AttributesToAddNumber-1;
	For Cnt = InitialNumber To LastDigitInAttributeName Do
		AttributesToBeAdded.Add(New FormAttribute("Attribute"+Cnt, New TypeDescription(), "MarkedForDeletionItemsTree"));
	EndDo;
	ChangeAttributes(AttributesToBeAdded);
	
	For Cnt = InitialNumber To LastDigitInAttributeName Do
		FormItem = Items.Add("MarkedForDeletionItemsTreeAttribute"+Cnt, Type("FormField"), Items.MarkedForDeletionItemsTree);
		FormItem.Type = FormFieldType.InputField;
		FormItem.DataPath = "MarkedForDeletionItemsTree.Attribute"+Cnt;
	EndDo;
EndProcedure

#EndRegion

#Region FormCommands

&AtClient
Function SelectedObjectsCount()
	Result = New Structure;
	Result.Insert("SelectedCount", 0);
	Result.Insert("TotalCount1", 0);
	
	For Each GroupRow In MarkedForDeletionItemsTree.GetItems() Do
		
		For Each ElementString In GroupRow.GetItems() Do
			If ElementString.Check = 1 Then
				Result.SelectedCount = Result.SelectedCount + 1;
			EndIf;
			Result.TotalCount1 = Result.TotalCount1 + 1;
		EndDo;
		
	EndDo;
	
	// All metadata objects are never selected.
	If MetadataFilter.Count() <> 0 Then
		Result.TotalCount1 = -1;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure RegisterUsageInstanceAction(EditablePlaceOfUse, Action, Parameter = Undefined)
	ActionPresentation = ?(Parameter = Undefined,
								NotDeletedItemsUsageInstancesActions.FindByValue(Action).Presentation,
								ReplaceWithCommandPresentation(EditablePlaceOfUse, Parameter));

	If Action = Undefined Then
		Return;
	EndIf;
	
	Success = True;
	
	If Action = "Delete" Then
		Filter = New Structure("FoundItemReference",EditablePlaceOfUse.FoundItemReference);
		RegisteredAction = ActionsTable.FindRows(Filter);
		
		If RegisteredAction.Count() <> 0 Then
			For Each ActionToDelete In RegisteredAction Do
				ActionsTable.Delete(ActionToDelete);
			EndDo;
		EndIf;
		
		RegisteredAction = ActionsTable.Add();
		RegisteredAction.Action = Action;
		RegisteredAction.FoundItemReference = EditablePlaceOfUse.FoundItemReference;
		RegisteredAction.ActionParameter = Parameter;
		RegisteredAction.Source = EditablePlaceOfUse.ItemToDeleteRef;
	ElsIf Action = "ReplaceRef" Then
		Filter = New Structure("FoundItemReference",EditablePlaceOfUse.FoundItemReference);
		RegisteredAction = ActionsTable.FindRows(Filter);
		For Each ActionToDelete In RegisteredAction Do
			ActionsTable.Delete(ActionToDelete);
		EndDo;
		
		Filter = New Structure("Source, Action", EditablePlaceOfUse.ItemToDeleteRef, "ReplaceRef");
		RegisteredAction = ActionsTable.FindRows(Filter);
		For Each ModifiableAction In RegisteredAction Do
			ModifiableAction.ActionParameter = Parameter;
		EndDo;
		
		If RegisteredAction.Count() = 0 Then
			ModifiableAction = ActionsTable.Add();
			ModifiableAction.Action = Action;
			ModifiableAction.FoundItemReference = EditablePlaceOfUse.FoundItemReference;
			ModifiableAction.ActionParameter = Parameter;
			ModifiableAction.Source = EditablePlaceOfUse.ItemToDeleteRef;
		EndIf;
		
		// Reference is replaced in all objects except the ones marked for deletion.
		For Each UsageInstance1 In NotDeletedItemsUsageInstances.GetItems() Do
			Filter = New Structure("FoundItemReference", UsageInstance1.FoundItemReference);
			CurrentAction1 = ActionsTable.FindRows(Filter);
			
			If CurrentAction1.Count() = 0 Then
				ModifiableAction = ActionsTable.Add();
				ModifiableAction.Action = Action;
				ModifiableAction.FoundItemReference = UsageInstance1.FoundItemReference;
				ModifiableAction.ActionParameter = Parameter;
				ModifiableAction.Source = UsageInstance1.ItemToDeleteRef;
			EndIf;
		EndDo;
	Else
		UserMessage = NStr("en = 'Cannot select the %2 action for the %1 occurrence.';");
		UserMessage = StringFunctionsClientServer.SubstituteParametersToString(UserMessage, 
		EditablePlaceOfUse.FoundItemReference,
		EditablePlaceOfUse.ActionPresentation);
		Status(UserMessage);
		Success = False;
	EndIf;
	
	If Success Then
		
		EditablePlaceOfUse.Action = Action;
		EditablePlaceOfUse.ActionPresentation = ActionPresentation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnConfirmationDelete(Result, AdditionalParameters) Export
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	ActionParameter = ?(AdditionalParameters.TotalCount1 = AdditionalParameters.SelectedCount,
		"CompleteRemoval", "");
	AddJob(FormJobs().DeleteMarkedObjects, ActionParameter);
	RunJob();
EndProcedure

&AtClient
Procedure ToOpenTheFormCompleteTheUserExperience()
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		Notification = New NotifyDescription("AfterSettingTheExclusiveMode", ThisObject);
		FormParameters = New Structure("MarkedObjectsDeletion", True);
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.OnOpenExclusiveModeSetErrorForm(Notification, FormParameters);
	Else
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf;

EndProcedure

&AtClient
Procedure AfterSettingTheExclusiveMode(Result, AdditionalParameters) Export
	If Result = False Then // 
		AddJob(FormJobs().DeleteMarkedObjects);
		RunJob();
	EndIf;
EndProcedure

#EndRegion

#Region FormEvents

&AtServerNoContext
Function SelectionOfMetadataOnlyExisting(MetadataFilter)
	Result = New ValueList;
	
	For Each MetadataIsSelected In MetadataFilter Do
		If Common.MetadataObjectByFullName(MetadataIsSelected.Value) = Undefined Then
			Continue;
		EndIf;     
		
		Result.Add(MetadataIsSelected.Value, MetadataIsSelected.Presentation);
	EndDo;                     
	
	Return Result;
EndFunction

&AtServer
Procedure SetPassedMetadataFilter()
	Var Item;
	Var ActiveFilter;
	ActiveFilter = New ValueList;
	For Each Item In Parameters.MetadataFilter Do
		ActiveFilter.Add(Item.Value, Common.MetadataObjectByFullName(Item.Value).Presentation());
	EndDo;
	SetMetadataFilter(ThisObject, ActiveFilter);
	Parameters.MetadataFilter = ActiveFilter;
EndProcedure

// Form settings, if the form is opened from the client API.
&AtServer
Procedure ConfigureFormToWorkAsService()
	DeleteOnOpen = True;
	Items.InformationPages.Visible = False;
	Items.MarkedForDeletionItemsTreeConfigure.Visible = False;
	Items.Back.Visible = False;
	Items.SearchFilterSettingsGroup.Visible = False;
	Items.CommandBarForm.Visible = False;
	Items.StatePresentationPages.Visible = True;
	AutoTitle = False;
	Title = "";
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ColorHyperlink = Metadata.StyleItems.HyperlinkColor.Value;
	InactiveLabelColor = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	
	ConditionalAppearanceItems = ConditionalAppearance.Items;
	ConditionalAppearanceItems.Clear();

	AppearanceItem = ConditionalAppearanceItems.Add();

	AndGroup = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	AndGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	AppearanceFilter = AndGroup.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("NotDeletedItemsUsageInstances.Action");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	AppearanceFilter = AndGroup.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("NotDeletedItemsUsageInstances.MainReason");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("en = 'Select an action';"));
	AppearanceItem.Appearance.SetParameterValue("Font", Metadata.StyleItems.ActionInListColumnFont.Value);

	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("NotDeletedItemRelationsAction");
	
	// 
	AppearanceItem = ConditionalAppearanceItems.Add();
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("NotDeletedItemsUsageInstances.MainReason");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", ColorHyperlink);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("NotDeletedItemRelationsAction");
	
	// Column titles.
	SetConditionalAppearanceOfAdditionalAttributes(ConditionalAppearanceItems, InactiveLabelColor);
	
	// 
	AppearanceItem = ConditionalAppearanceItems.Add();
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("NotDeletedItemsUsageInstances.MainReason");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = False;
	
	AppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("NotDeletedItemRelationsAction");
EndProcedure

&AtServer
Procedure SetConditionalAppearanceOfAdditionalAttributes(ConditionalAppearanceItems, InactiveLabelColor)
	AppearanceItem = ConditionalAppearanceItems.Add();
	
	AppearanceFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceFilter.LeftValue = New DataCompositionField("MarkedForDeletionItemsTree.IsMetadataObjectDetails");
	AppearanceFilter.ComparisonType = DataCompositionComparisonType.Equal;
	AppearanceFilter.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor", InactiveLabelColor);
	
	AdditionalAttributesNumber = MarkedObjectsDeletionInternal.AdditionalAttributesNumber(
		AdditionalAttributesOfItemsMarkedForDeletion.Unload());
	
	For Cnt = 1 To AdditionalAttributesNumber Do
		AppearanceField = AppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField("MarkedForDeletionItemsTreeAttribute" + Cnt);
	EndDo;
EndProcedure

&AtClientAtServerNoContext
Procedure SetUsageInstancesActionsList(Form)
	Form.NotDeletedItemsUsageInstancesActions.Clear();
	Form.NotDeletedItemsUsageInstancesActions.Add("Delete", NStr("en = 'Delete';"));
	Form.NotDeletedItemsUsageInstancesActions.Add("ReplaceRef", NStr("en = 'Replace %PresentationRef% with';"));
	
	Form.Items.NotDeletedItemRelationsAction.ChoiceList.Clear();
	For Each ListItem In Form.NotDeletedItemsUsageInstancesActions Do
		Form.Items.NotDeletedItemRelationsAction.ChoiceList.Add(ListItem.Value, ListItem.Presentation);
	EndDo;
EndProcedure

#EndRegion

#Region OnActivateNotDeletedItemsRow

&AtClient
Procedure ShowNotDeletedItemsLinksAtClient()
	If NotDeletedItemsCurrentRowID = Items.NotTrash.CurrentRow Then
		Return;
	EndIf;

	DetailedErrorText = "";
	FillNotDeletedObjectsUsageInstances(ThisObject);
	
	If NotDeletedItemsUsageInstances.GetItems().Count() = 0 Then
		Items.ReasonsDisplayOptionsPages.CurrentPage = Items.ErrorTextPage;
		SetErrorText();
		Items.Actions.Enabled = False;
	Else	
		Items.ReasonsDisplayOptionsPages.CurrentPage = Items.ReasonsForNotDeletionPage;
		StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "NotDeletedItemsUsageInstances", "*", True);
		Items.Actions.Enabled = True;
	EndIf;
EndProcedure

&AtClient
Procedure SetErrorText()
	Items.ErrorText.Title = ErrorText;
	Items.DetailsRef.Visible = ValueIsFilled(DetailedErrorText) ;
EndProcedure

&AtClientAtServerNoContext
Procedure FillNotDeletedObjectsUsageInstances(Form)
	NotDeletedItemsCurrentRowID = Form.Items.NotTrash.CurrentRow;
	If NotDeletedItemsCurrentRowID = Undefined Then
		TreeRow = Undefined;
	Else
		TreeRow = Form.NotTrash.FindByID(NotDeletedItemsCurrentRowID);
	EndIf;
	
	DisplayedRows = Form.NotDeletedItemsUsageInstances.GetItems();
	DisplayedRows.Clear();
	Form.ReasonsForNotDeletionCache.Clear();
	
	If TreeRow = Undefined Or TreeRow.PictureNumber < 1 Then
		// 
		Form.ErrorText = NStr("en = 'Select an object to view the reason
			|why it cannot be deleted.';")
	Else
		// Reference to a not deleted object is selected.
		ItemsToShow = Form.NotDeletedItemsLinks.FindRows(New Structure("ItemToDeleteRef", TreeRow.ItemToDeleteRef));
		For Each TableRow In ItemsToShow Do
			If TableRow.IsError Then
				Form.ErrorText = TableRow.FoundItemReference;
				Form.DetailedErrorText = TableRow.Presentation;
				Break;
			EndIf;
				
			AddReasonsForNotDeletionRecursively(Form, DisplayedRows, TableRow);
			Form.ReasonsForNotDeletionCache.Add(TableRow.ItemToDeleteRef);
		EndDo;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure FillInTheActionInTheLineOfThePlaceOfUseOfTheUndeletedOnes(Form, Val ReasonForNotDeletion, Action = "")
	If ReasonForNotDeletion.IsError Then
		Return;
	EndIf;
	
	ActionsTable = Form.ActionsTable;
	Filter = New Structure("FoundItemReference, Action", 
					ReasonForNotDeletion.FoundItemReference, "Delete");
	SelectedActions = ActionsTable.FindRows(Filter);
	
	If SelectedActions.Count() = 0 Then
		Filter = New Structure("Source, Action", 
						ReasonForNotDeletion.ItemToDeleteRef, "ReplaceRef");
		SelectedActions = ActionsTable.FindRows(Filter);
	EndIf;
	
	If SelectedActions.Count() > 0 Then
		Action = SelectedActions[0].Action;
		ActionParameter = SelectedActions[0].ActionParameter;
	EndIf;	
	
	If Not ReasonForNotDeletion.MainReason Then
		Action = "Delete";
	EndIf;
	
	ReasonForNotDeletion.Action = Action;
			
	If Action = "ReplaceRef" Then
		ReasonForNotDeletion.ActionPresentation = ReplaceWithCommandPresentation(ReasonForNotDeletion, ActionParameter);
	ElsIf Action = "Delete" Then
		ReasonForNotDeletion.ActionPresentation = Form.NotDeletedItemsUsageInstancesActions.FindByValue(Action).Presentation;
	Else
		ReasonForNotDeletion.ActionPresentation = "";
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure AddReasonsForNotDeletionRecursively(Form, ParentRowsCollection, RowData)
	ReasonsForNotDeletionCache = Form.ReasonsForNotDeletionCache;

	NewRow = ParentRowsCollection.Add();
	SubordinateRows = NewRow.GetItems();
	If RowData.IsError Then
		FillPropertyValues(NewRow, RowData,"IsError,PictureNumber");
		NewRow.Presentation = RowData.FoundItemReference;
		NewRow.FoundItemReference = ?(ValueIsFilled(RowData.Presentation), RowData.Presentation, RowData.FoundItemReference);
	Else	
		FillPropertyValues(NewRow, RowData);
	EndIf;
	ItemsToShow = Form.NotDeletedItemsLinks.FindRows(New Structure("ItemToDeleteRef", RowData.FoundItemReference));
	
	ContainsOnlyErrors = True;
	For Each TableRow In ItemsToShow Do
		If Not TableRow.IsError Then
			ContainsOnlyErrors = False;
		EndIf;
		
		If ReasonsForNotDeletionCache.FindByValue(TableRow.FoundItemReference) = Undefined Then
			ReasonsForNotDeletionCache.Add(TableRow.ItemToDeleteRef);
			AddReasonsForNotDeletionRecursively(Form, SubordinateRows, TableRow);
		EndIf;
	EndDo;

	NewRow.MainReason = Not NewRow.IsError
								And (SubordinateRows.Count() = 0 
									Or ContainsOnlyErrors
									Or ItemsToShow.Count() = 0);
									
	FillInTheActionInTheLineOfThePlaceOfUseOfTheUndeletedOnes(Form,
		 NewRow,
		 ?(ItemsToShow.Count() <> 0, "Delete", ""));

EndProcedure

#EndRegion

#Region OnActivateNotDeletedItemsUsageInstancesRow

&AtClient
Procedure NotDeletedItemsUsageInstancesOnActivateRow(Item)
	CurrentData = Items.NotDeletedItemsUsageInstances.CurrentData;

	If CurrentData = Undefined Then
		Return;
	EndIf;

	If ValueIsFilled(CurrentData.FoundItemReference) Then
		Items.NotDeletedItemRelationsAction.ChoiceList.Clear();
		
		// Deletion is not available for errors and constants.
		If TypeOf(CurrentData.FoundItemReference) <> Type("String") Then
			Items.NotDeletedItemRelationsAction.ChoiceList.Add("Delete", ViewOfTheDeleteCommand(CurrentData));
		EndIf;
		
		Actions = ActionsTable.FindRows(New Structure("FoundItemReference", CurrentData.FoundItemReference));
		If Not(Actions.Count() > 0 
				And Actions[0].Action = "Delete" 
				And Actions[0].Source <> CurrentData.ItemToDeleteRef) Then
		
			Items.NotDeletedItemRelationsAction.ChoiceList.Add("ReplaceRef", ReplaceWithCommandPresentation(CurrentData));
		EndIf;

	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function ReplaceWithCommandPresentation(CurrentData, Parameter = Undefined)
	UpperLevelRow = CurrentData.GetParent();
	
	If UpperLevelRow = Undefined Then
		UpperLevelRowPresentation = CurrentData.PresentationItemToDelete;
	Else	
		UpperLevelRowPresentation = UpperLevelRow.Presentation;
	EndIf;
	
	ReplaceWithCommandPresentation = StrReplace(NStr("en = 'Replace %PresentationRef% with';"),
										"%PresentationRef%", UpperLevelRowPresentation)
										+ Chars.NBSp + ?(Parameter = Undefined, "", Parameter);
		
	Return ReplaceWithCommandPresentation;
EndFunction

&AtClientAtServerNoContext
Function ViewOfTheDeleteCommand(CurrentData)
	Presentation = NStr("en = 'Delete';") + Chars.NBSp + CurrentData.Presentation;
	Return Presentation;
EndFunction

#EndRegion

&AtClient
Procedure ShowTableObject(TableItem)
	TableRow = TableItem.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	Value = Undefined;
	If Not TableRow.Property("FoundItemReference", Value)
		And Not TableRow.Property("ItemToDeleteRef", Value) Then
		Return;
	EndIf;
	
	If TypeOf(Value) = Type("String") 
		And Not CommonClientServer.StructureProperty(TableRow, "IsError", False) Then
			
		If TableRow.Property("IsConstant") And TableRow.IsConstant Then
			FormPath = Value + ".ConstantsForm";
		Else
			FormPath = Value + ".ListForm";
		EndIf;
		OpenForm(FormPath);
	ElsIf CommonClientServer.StructureProperty(TableRow, "IsError", False) Then
		StandardSubsystemsClient.ShowDetailedInfo(Undefined, TableRow.FoundItemReference);
	Else
		ShowValue(, Value);
	EndIf;
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeSetMarkInList(Data, Check, CheckParent)
	
	// Mark as a subordinate item.
	RowItems = Data.GetItems();
	
	For Each Item In RowItems Do
		Item.Check = Check;
		MarkedForDeletionItemsTreeSetMarkInList(Item, Check, False);
	EndDo;
	
	// Check the parent item.
	Parent = Data.GetParent();
	
	If CheckParent And Parent <> Undefined Then 
		MarkedForDeletionItemsTreeCheckParent(Parent);
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkedForDeletionItemsTreeCheckParent(Parent)
	
	RowItems = Parent.GetItems();
	Parent.Check = ItemMarkValues(RowItems);
	
EndProcedure

// Parameters:
//   Result - ValueList of String
//   AdditionalParameters - Structure
//
&AtClient
Procedure ConfigureFilterCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	CurrentFilter = CommonClient.CopyRecursive(MetadataFilter);
	SetMetadataFilter(ThisObject, Result);
	
	If MetadataFilterChanged(CurrentFilter, Result) Then
		RunJob(FormJobs().MarkedObjectsSearch);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure SetMetadataFilter(Form, Result)
	Form.MetadataFilter = ?(Result = Undefined, New ValueList, Result.Copy());// ValueList of String
	Form.Items.ConfigureFilter.Title = MetadataFilterPresentation(Result);
EndProcedure

&AtClientAtServerNoContext
Function MetadataFilterPresentation(FilterValue)
	FilterPresentation = "";
	Presentation = New Array;
	For Each Filter In FilterValue Do
		Presentation.Add(Filter.Presentation);
	EndDo;
	FilterPresentation = StrConcat(Presentation, ", ");
	Return ?(IsBlankString(FilterPresentation), NStr("en = 'All objects marked for deletion';"), FilterPresentation);
EndFunction

&AtClient
Function MetadataFilterChanged(OldFilter, Result)
	RepeatedSearchRequired = False;
	For Each Item In Result Do
		If MetadataFilter.FindByValue(Item.Value) = Undefined Then
			RepeatedSearchRequired = True;
			Break;
		EndIf;
	EndDo;
	
	If OldFilter.Count() <> Result.Count() Then
		RepeatedSearchRequired = True;
	EndIf;
	
	Return RepeatedSearchRequired;
EndFunction

#Region BackgroundJobs

#Region SearchForItemsmarkedForDeletion

&AtClient
Procedure StartMarkedObjectsSearch(Parameter = Undefined)
	SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
	
	PresentationOperation = NStr("en = 'Search for objects marked for deletion';");
	ToStartSearchingForTheMarkedSettingOfTheForm(ThisObject);

	
	Handler = New NotifyDescription("AfterMarkedObjectsSearchCompletion", ThisObject);
	
	CurrentOperation1 = StartMarkedObjectsSearchServer(MetadataFilter, UUID);
	OnStartBackgroundJob(Handler);
EndProcedure

&AtClientAtServerNoContext
Procedure ToStartSearchingForTheMarkedSettingOfTheForm(Form)
	
	Form.Items.StatePresentationPages.CurrentPage = Form.Items.RunningState;
	Form.Items.LongRunningOperationPresentationDecoration.Title = NStr("en = 'Searching for objects marked for deletion…';");
	Form.Items.InformationPages.ReadOnly = True;
	Form.Items.ActiveAfterSearchMarkedObjectsGroup.Enabled = False;

EndProcedure

&AtClient
Procedure OnStartBackgroundJob(Val Handler, IsDeletionProcess = False)
	Var WaitSettings;
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	WaitSettings.OutputProgressBar = True;
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsDeletionProcess", IsDeletionProcess);
	WaitSettings.ExecutionProgressNotification = New NotifyDescription("OnUpdateBackgroundJobProgress",
		ThisObject, AdditionalParameters);
	TimeConsumingOperationsClient.WaitCompletion(CurrentOperation1, Handler, WaitSettings);
	If CurrentOperation1 <> Undefined And CurrentOperation1.Status = "Running" Then
		ShowDialogBeforeClose = True;
	EndIf;
EndProcedure

&AtClient
Procedure AfterCompleteBackgroundJob1(Result)
	PreviousStepResult = Result;
	ShowDialogBeforeClose = False;
	CurrentOperation1 = Undefined;
	JobParameter = DeleteCurrentJob();	
	JobInProgress = False;
	
	If JobsCountInQueue() = 0 Then
		SetExclusiveModeAtServer(False);
	EndIf;
	
	If Result.Status <> "Error" Then
		RunJob(,JobParameter);
	EndIf;
EndProcedure

&AtServer
Function StartMarkedObjectsSearchServer(MetadataFilter, FormUniqueID)
	MethodName = "MarkedObjectsDeletionInternal.MarkedForDeletion";
	
	MethodParameters = TimeConsumingOperations.FunctionExecutionParameters(FormUniqueID);
	MethodParameters.BackgroundJobDescription = NStr("en = 'Search for objects marked for deletion';");
	Job = TimeConsumingOperations.ExecuteFunction(MethodParameters, MethodName,
		MetadataFilter, 
		AdditionalAttributesOfItemsMarkedForDeletion.Unload(), 
		FormAttributeToValue("MarkedForDeletionItemsTree"));

	Return Job;
EndFunction

&AtClient
Procedure AfterMarkedObjectsSearchCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	JobInProgress = False;
	
	If Result.Status = "Error" Then
		
		FillInformationWithBackgroundJobErrors(ThisObject, Result);
		SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
		
	Else
		
		FillMarkedForDeletionItemsTree(Result);
	
		If MarkedForDeletionItemsTree.GetItems().Count() = 0 Then
			Items.StatePresentationPages.CurrentPage = Items.DeletionNotRequiredState;
			JobInProgress = True;
			SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
			ClearFormJobsQueue();
		Else
			SetObjectsMarkedForDeletionSelectionState();
		EndIf;
		
	EndIf;
	
	AfterCompleteBackgroundJob1(Result);
EndProcedure

&AtClientAtServerNoContext
Procedure FillInformationWithBackgroundJobErrors(Form, Result)
	Form.DetailedBackgroundJobErrorText = Result.DetailErrorDescription;
	Form.Items.CompletionPresentationFailedDecoration.Title = 
		?(IsExclusiveModeSettingError(Result.BriefErrorDescription),
			NStr("en = 'Couldn''t set exclusive mode';"),
			Result.BriefErrorDescription);
	Form.Items.StatePresentationPages.CurrentPage = Form.Items.CompletedWithErrorsState;
EndProcedure

&AtServer
Procedure FillMarkedForDeletionItemsTree(Result)
	ValueTree = GetFromTempStorage(Result.ResultAddress);
	DeleteFromTempStorage(Result.ResultAddress);
	FillFormDataTreeItemCollection(MarkedForDeletionItemsTree, ValueTree);
	DeleteFromTempStorage(Result.ResultAddress);
EndProcedure

#EndRegion

#Region DeleteMarkedObjects

&AtClient
Procedure StartMarkedObjectsDeletion(Parameter = Undefined)
	PresentationOperation = NStr("en = 'Delete marked objects';");
	Items.StatePresentationPages.CurrentPage = Items.RunningState;
	Items.LongRunningOperationPresentationDecoration.Title = NStr("en = 'Deleting objects marked for deletion…';");
	SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
	
	Items.CommandBarForm.Enabled = False;
	Items.InformationPages.ReadOnly = True;

	Handler = New NotifyDescription("AfterMarkedObjectsDeletionCompletion", ThisObject);
	CurrentOperation1 = StartMarkedObjectsDeletionServer(
							UUID,
							PreviousStepResult,
							Parameter = "CompleteRemoval");
	OnStartBackgroundJob(Handler);
EndProcedure

&AtServer
Function SetExclusiveModeAtServer(ExclusiveMode)
	Result = New Structure;
	Result.Insert("Success", True);
	Result.Insert("DetailErrorDescription", "");
	Result.Insert("BriefErrorDescription", "");
	If ExclusiveMode() <> ExclusiveMode Then
		Try
			SetExclusiveMode(ExclusiveMode);
		Except
			ErrorInfo = ErrorInfo();
			Result.Success = False;
			Result.BriefErrorDescription =  ErrorProcessing.BriefErrorDescription(ErrorInfo);
			Result.DetailErrorDescription =  ErrorProcessing.DetailErrorDescription(ErrorInfo);
			ErrorInfo = ErrorInfo();
			WriteLogEvent(NStr("en = 'Delete marked objects';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				Result.BriefErrorDescription
				+ Chars.LF + Chars.LF 
				+ Result.DetailErrorDescription);
		EndTry;
	EndIf;
	
	If Not ExclusiveMode Then
		If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
			ModuleIBConnections = Common.CommonModule("IBConnections");
			ModuleIBConnections.AllowUserAuthorization();
		EndIf;
	EndIf;
			
	Return Result;
EndFunction

&AtServer
Function StartMarkedObjectsDeletionServer(FormUniqueID, PreviousStepResult, RepeatSearch = False)
	If DeleteOnOpen Then
		ObjectsToDeleteSource = Parameters.ObjectsToDelete;
	ElsIf RepeatSearch Then
		ObjectsToDeleteSource = Undefined;
	Else	
		ObjectsToDeleteSource = FormAttributeToValue("MarkedForDeletionItemsTree");
	EndIf;
	
	AdditionalAttributesSettings = FormAttributeToValue("AdditionalAttributesOfItemsMarkedForDeletion");
	MethodName = "MarkedObjectsDeletionInternal.ToDeleteMarkedObjects";
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(FormUniqueID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Marked object deletion';");
	
	PreviousStepResultValue = ?(PreviousStepResult <> Undefined 
			And IsTempStorageURL(PreviousStepResult.ResultAddress),
		GetFromTempStorage(PreviousStepResult.ResultAddress),
		Undefined);
	
	AllowedDeletionModes = MarkedObjectsDeletionInternal.AllowedDeletionModes();
	ResultingDeletionMode = ?(AllowedDeletionModes.Find(DeletionMode) <> Undefined,
		DeletionMode, "Standard");
	If ResultingDeletionMode = "Exclusive" Then
		AllowedDeletionModes = MarkedObjectsDeletionInternal.AllowedDeletionModes();
		Job = TimeConsumingOperations.ExecuteFunction(ExecutionParameters, MethodName,
			ObjectsToDeleteSource,
			ResultingDeletionMode,
			AdditionalAttributesSettings,
			PreviousStepResultValue,
			FormUniqueID);
	Else
		DeletionParameters = ParametersOfMarkedObjectsDeletion(ObjectsToDeleteSource, ResultingDeletionMode,
			AdditionalAttributesSettings, PreviousStepResultValue, FormUniqueID);
		BatchesCount = DeletionParameters.Count();
		
		Job = TimeConsumingOperations.ExecuteFunctionInMultipleThreads(MethodName,
			ExecutionParameters, DeletionParameters);
	EndIf;
	
	Return Job;
EndFunction

&AtServer
Function ParametersOfMarkedObjectsDeletion(ObjectsToDeleteSource, ResultingDeletionMode,
	AdditionalAttributesSettings, PreviousStepResultValue, FormUniqueID)
	
	If ObjectsToDeleteSource = Undefined Then
		ObjectsToDeleteSource = FormAttributeToValue("MarkedForDeletionItemsTree");
	EndIf;
	
	DeletionParameters = New Map;
	If TypeOf(ObjectsToDeleteSource) <> Type("ValueTree") Then
		ServerCallParameters = New Array;
		ServerCallParameters.Add(ObjectsToDeleteSource);
		ServerCallParameters.Add(ResultingDeletionMode);
		ServerCallParameters.Add(AdditionalAttributesSettings);
		ServerCallParameters.Add(PreviousStepResultValue);
		ServerCallParameters.Add(FormUniqueID);
		DeletionParameters.Insert(0, ServerCallParameters);
		Return DeletionParameters;
	EndIf;
	
	BatchIndex = 0;
	
	ServerCallParameters = New Array;
	ServerCallParameters.Add(ObjectsToDeleteSource);
	ServerCallParameters.Add(ResultingDeletionMode);
	ServerCallParameters.Add(AdditionalAttributesSettings);
	ServerCallParameters.Add(PreviousStepResultValue);
	ServerCallParameters.Add(FormUniqueID);
	DeletionParameters.Insert(BatchIndex, ServerCallParameters);
	
	Return DeletionParameters;
	
EndFunction

&AtClient
Procedure AfterMarkedObjectsDeletionCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	JobInProgress = False;
	ShowDialogBeforeClose = False;
	
	If Result.Status = "Error" Then
		
		DeletionResultsInfo = ProcessDeletionResultError(ThisObject, Result);
	ElsIf Result.Status = "Completed2" Then 
		UUIDConsideringOwner = ?(FormOwner = Undefined, UUID, FormOwner.UUID);
		DeletionResultsInfo = ProcessTheDeletionResultSuccess(Result, 
			UUIDConsideringOwner, DeletionResultsInfo);
		CommonClient.NotifyObjectsChanged(DeletionResultsInfo.Trash);
	EndIf;
	
	AfterCompleteBackgroundJob1(Result);
	
	If DeleteOnOpen And DeletionResultsInfo.Success Then
		Close(DeletionResultsInfo);
	EndIf;
EndProcedure

&AtClient
Function ProcessDeletionResultError(Var_ThisObject, Result)
	SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
	FillInformationWithBackgroundJobErrors(Var_ThisObject, Result);
	SetExclusiveModeAtServer(False);
	Return MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo();
EndFunction

&AtServer
Function ProcessTheDeletionResultSuccess(Result, FormUniqueID, DeletionResultsInfo)
	
	DeletionResultsInfo = ImportDeletionResult(Result, 
		FormUniqueID, DeletionResultsInfo);
	ProcessDeletionExecutionResult(DeletionResultsInfo);
	SetExclusiveModeAtServer(False);
	
	Return DeletionResultsInfo;
	
EndFunction

// Parameters:
//   DeletionResultsInfo - See MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo
//
&AtServer
Procedure ProcessDeletionExecutionResult(DeletionResultsInfo)
	
	If NotTrash.GetItems().Count() > 0 Then
		Items.StatePresentationPages.CurrentPage = Items.PartialDeletionState;
		Items.PartialDeletionStateLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Deleted %1 of %2.';"),
			DeletionResultsInfo.DeletedItemsCount1,
	 		DeletionResultsInfo.NotDeletedItemsCount1 + DeletionResultsInfo.DeletedItemsCount1);
		SetStateUnsuccessfulDeletionWithStatePanel();
	ElsIf DeletionResultsInfo.DeletedItemsCount1 > 0 Then
		SetObjectsMarkedForDeletionSelectionStateWithStatePanel();
		
		Items.StatePresentationPages.CurrentPage = Items.CompletedState;
		Items.CompletionPresentationSuccessDecoration.Title = NStr("en = 'Deleted successfully.';");
	Else
		SetObjectsMarkedForDeletionSelectionState();
	EndIf;
	
EndProcedure

// Parameters:
//   DeletionResult - Structure:
//   * ResultAddress - String
// Returns:
//   See MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo
//
&AtServer
Function ImportDeletionResult(DeletionResult, ResultStorageID, ResultInfo)
	GeneralOutput = GetFromTempStorage(DeletionResult.ResultAddress);
	If TypeOf(GeneralOutput) = Type("Structure") Then
		BackgroundExecutionResult = GeneralOutput;
	Else
		BackgroundExecutionResult = GetFromTempStorage(GeneralOutput[0].ResultAddress);
		For BatchIndex = 1 To BatchesCount - 1 Do
			BatchResultAddress = GeneralOutput[BatchIndex].ResultAddress;
			ResultOfBatchExecutionInBackground = GetFromTempStorage(BatchResultAddress);
			
			BackgroundExecutionResult.NotDeletedObjectsCount = BackgroundExecutionResult.NotDeletedObjectsCount
				+ ResultOfBatchExecutionInBackground.NotDeletedObjectsCount;
			BackgroundExecutionResult.DeletedItemsCount = BackgroundExecutionResult.DeletedItemsCount
				+ ResultOfBatchExecutionInBackground.DeletedItemsCount;
			CommonClientServer.SupplementTable(ResultOfBatchExecutionInBackground.NotDeletedItemsLinks,
				BackgroundExecutionResult.NotDeletedItemsLinks);
			CommonClientServer.SupplementArray(BackgroundExecutionResult.Trash,
				ResultOfBatchExecutionInBackground.Trash);
			BackgroundExecutionResult.MarkedForDeletionItemsTree =
				MarkedForDeletionItemsTreeWithoutDeletedItems(BackgroundExecutionResult.MarkedForDeletionItemsTree,
				ResultOfBatchExecutionInBackground.Trash);
			MergeItemsMarkedForDeletion(BackgroundExecutionResult.MarkedForDeletionItemsTree,
				ResultOfBatchExecutionInBackground.MarkedForDeletionItemsTree);
			MergeAllNonDeleted(BackgroundExecutionResult.NotTrash, ResultOfBatchExecutionInBackground.NotTrash);
		EndDo;
		ProcessedTotalCount = 0;
		SelectedCountTotal = 0;
		BatchesCount = 0;
		DeletionProgress.Clear();
	EndIf;
	ResultInfo = ?(DeleteOnOpen, ResultInfo, Undefined);

	Result = GenerateDeletionResult(ResultInfo, BackgroundExecutionResult,
		ResultStorageID);

	FillFormDataTreeItemCollection(MarkedForDeletionItemsTree,
		BackgroundExecutionResult.MarkedForDeletionItemsTree);
	FillFormDataTreeItemCollection(NotTrash, BackgroundExecutionResult.NotTrash);

	NotDeletedItemsLinks.Load(BackgroundExecutionResult.NotDeletedItemsLinks);

	Return Result;
EndFunction

&AtServerNoContext
Function MarkedForDeletionItemsTreeWithoutDeletedItems(MarkedForDeletion, Trash)
	
	Result = MarkedForDeletion.Copy();
	ModifiedParents = New Array;
	
	For Each ItemToDeleteRef In Trash Do
		TreeRow = Result.Rows.Find(ItemToDeleteRef, "ItemToDeleteRef", True);
		If TreeRow = Undefined Then
			Continue;
		EndIf;
		
		If TreeRow.Parent <> Undefined Then
			ModifiedParents.Add(TreeRow.Parent);
		EndIf;
		TreeRow.Parent.Rows.Delete(TreeRow);
	EndDo;
	
	ModifiedParents = CommonClientServer.CollapseArray(ModifiedParents);
	
	For Each ModifiedParent In ModifiedParents Do
		If ModifiedParent.Rows.Count() > 0 Then
			Continue;
		EndIf;
		
		Result.Rows.Delete(ModifiedParent);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure MergeItemsMarkedForDeletion(Receiver, Source)
	
	RowsCount = Source.Rows.Count();
	
	For RowIndex = 0 To RowsCount - 1 Do
		TreeRowSource = Source.Rows[RowIndex];
		If TreeRowSource.Check = 0 Then
			Continue;
		EndIf;
		
		TreeRowDestination = Receiver.Rows.Find(TreeRowSource.ItemToDeleteRef, "ItemToDeleteRef"); 
		If TreeRowDestination  = Undefined Then
			Continue;
		EndIf;
		
		TreeRowDestination.Check = TreeRowSource.Check;
		SubstringCount = TreeRowSource.Rows.Count();
		For SubstringIndex = 0 To SubstringCount - 1 Do
			
			TreeSubRowSource = TreeRowSource.Rows[SubstringIndex];
			
			TreeSubRowDestination = TreeRowDestination.Rows.Find(TreeSubRowSource.ItemToDeleteRef, "ItemToDeleteRef");
			If TreeSubRowDestination = Undefined Then
				Continue;
			EndIf;
			
			TreeSubRowDestination.Check = TreeSubRowSource.Check;
		EndDo;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure MergeAllNonDeleted(Receiver, Source)
	
	RowsCount = Source.Rows.Count();
	
	For Each TreeRowSource In Source.Rows Do
		TreeRowDestination = Receiver.Rows.Add();
		FillPropertyValues(TreeRowDestination, TreeRowSource);
		For Each TreeSubRowSource In TreeRowSource.Rows Do
			TreeSubRowDestination = TreeRowDestination.Rows.Add();
			FillPropertyValues(TreeSubRowDestination, TreeSubRowSource);
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function GenerateDeletionResult(ResultInfo, BackgroundExecutionResult, ResultStorageID)
	Result = ?(ResultInfo = Undefined,
		MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo(),
		ResultInfo);
	
	ItemsPreventingDeletionResult = ?(IsTempStorageURL(Result.ResultAddress), 
		GetFromTempStorage(Result.ResultAddress),
		MarkedObjectsDeletionInternal.ObjectsPreventingDeletion());
	
	CommonClientServer.SupplementArray(Result.Trash, BackgroundExecutionResult.Trash);
	Result.DeletedItemsCount1 = BackgroundExecutionResult.DeletedItemsCount + Result.DeletedItemsCount1;
	Result.NotDeletedItemsCount1 = BackgroundExecutionResult.NotDeletedObjectsCount + Result.NotDeletedItemsCount1;
	Result.Success = Result.DeletedItemsCount1 > 0 And Result.NotDeletedItemsCount1 = 0;
	
	NotDeletedResultItemRelations = MarkedObjectsDeletionInternal.TablesMerge(
			ItemsPreventingDeletionResult,
			BackgroundExecutionResult.NotDeletedItemsLinks,
			True);
	Result.ResultAddress = PutToTempStorage(
		NotDeletedResultItemRelations, ResultStorageID);
			
	Return Result;		
EndFunction

#EndRegion

#Region ActionsExecution

&AtClient
Procedure WhenSelectingAPlaceOfUseAction(Val ValueSelected, Val CurrentData)
	
	If ValueSelected = "ReplaceRef" Then
		SetReplaceWith(Undefined);
	ElsIf ValueSelected = "Delete" And Not CurrentData.ReferenceType Then
		Status(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set the Delete action for %1';"),
			CurrentData.Presentation));
	Else	
		RegisterUsageInstanceAction(CurrentData, ValueSelected);
	EndIf;

EndProcedure

&AtClient
Procedure StartAdditionalDataProcessorExecution(Parameter)
	PresentationOperation = NStr("en = 'Additional processing of objects preventing deletion';");
	
	SetStateUnsuccessfulDeletionWithStatePanel();
	
	Items.StatePresentationPages.CurrentPage = Items.RunningState;
	Items.LongRunningOperationPresentationDecoration.Title = NStr("en = 'Additional processing of reasons preventing deleting…';");
	Items.CommandBarForm.Enabled = False;
	Items.InformationPages.ReadOnly = True;
	
		
	Handler = New NotifyDescription("AfterCompleteExecutingAdditionalDataProcessor", ThisObject);
	CurrentOperation1 = StartAdditionalDataProcessorExecutionServer();
	OnStartBackgroundJob(Handler);
EndProcedure

&AtServer
Function StartAdditionalDataProcessorExecutionServer()
	MethodName = "MarkedObjectsDeletionInternal.RunDataProcessorOfReasonsForNotDeletion";
	
	MethodParameters = TimeConsumingOperations.FunctionExecutionParameters(UUID);
	MethodParameters.BackgroundJobDescription = NStr("en = 'Additional processing of objects preventing deletion';");
	
	Job = TimeConsumingOperations.ExecuteFunction(MethodParameters, MethodName, ActionsTable.Unload());
	
	Return Job;
EndFunction

&AtClient
Procedure AfterCompleteExecutingAdditionalDataProcessor(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	JobInProgress = False;
	
	If Result.Status = "Error" Then
		SetStateUnsuccessfulDeletionWithStatePanel();
		FillInformationWithBackgroundJobErrors(ThisObject, Result);
		SetExclusiveModeAtServer(False);
	EndIf;
	
	AfterCompleteBackgroundJob1(Result);
EndProcedure

#EndRegion

&AtClient
Procedure AfterConfirmCancelJob(Response, ExecutionParameters) Export
	If Response = DialogReturnCode.Abort Then
		ShowDialogBeforeClose = False;
		CancelOperationServer(CurrentOperation1);
		SetExclusiveModeAtServer(False);	
		Close(DeletionResultsInfo);
	EndIf;
EndProcedure

&AtClient
Procedure OnUpdateBackgroundJobProgress(Job, AdditionalParameters) Export
	If Job.Progress <> Undefined Then
		ProgressParameters = Undefined;
		If Job.Progress.Property("AdditionalParameters", ProgressParameters)
			And ProgressParameters = "ProgressofMultithreadedProcess" Then
			Return;
		EndIf;
		
		Items.ProgressPresentation.Visible = True;
		If Not AdditionalParameters.IsDeletionProcess Or ProgressParameters = Undefined Then
			ProgressText = Job.Progress.Text;
		Else
			ProgressText = ProgressText(ProgressParameters);
		EndIf;
		Items.ProgressPresentation.Title = ProgressText;
	EndIf;
EndProcedure

&AtServer
Function ProgressText(ProgressParameters)
	
	Filter = New Structure;
	Filter.Insert("SessionNumber", ProgressParameters.SessionNumber);
	TableRows = DeletionProgress.FindRows(Filter);
	If TableRows.Count() = 0 Then
		TableRow = DeletionProgress.Add();
		TableRow.SessionNumber = ProgressParameters.SessionNumber;
		PreviousProcessedCount = 0;
	Else
		TableRow = TableRows[0];
		PreviousProcessedCount = TableRow.ProcessedItemsCount;
	EndIf;
	TableRow.ProcessedItemsCount = ProgressParameters.ProcessedItemsCount;
	ProcessedTotalCount = ProcessedTotalCount
		+ (ProgressParameters.ProcessedItemsCount - PreviousProcessedCount);
	
	ProgressText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Processed %1 of %2';"),
		ProcessedTotalCount,
		SelectedCountTotal);
	Return ProgressText;
	
EndFunction

&AtClientAtServerNoContext
Function ItemMarkValues(ParentItems1)
	
	HasMarkedItems    = False;
	HasUnmarkedItems = False;
	
	For Each ParentItem1 In ParentItems1 Do
		
		If ParentItem1.Check = 0 Then
			HasUnmarkedItems = True;
		ElsIf ParentItem1.Check = 1 Then 	
			HasMarkedItems = True;
		EndIf;
		
		If HasUnmarkedItems And HasMarkedItems Then
			Break;
		EndIf;
		
	EndDo;
	
	If HasMarkedItems Then
		If HasUnmarkedItems Then
			Return 2;
		Else
			Return 1;
		EndIf;
	Else
		Return 0;
	EndIf;
	
EndFunction

#EndRegion

&AtServer
Procedure FillFormDataTreeItemCollection(FormData1, ValueTree)
	FormDataRows = FormData1.GetItems();
	FormDataRows.Clear();
	Common.FillFormDataTreeItemCollection(FormDataRows, ValueTree);
EndProcedure

&AtClientAtServerNoContext
Function IsExclusiveModeSettingError(DetailedBackgroundJobErrorText)
	ErrorTextExclusive = NStr("en = 'Error of separated infobase access';");	
	Return (StrFind(DetailedBackgroundJobErrorText,ErrorTextExclusive) <> 0)
EndFunction

&AtClient
Function OperationDescription(OperationName, Parameter = Undefined)

	Return New Structure("Name, Parameter", OperationName, Parameter);

EndFunction

&AtClient
Procedure AddJob(OperationName, JobParameter = Undefined)
	FormJobsQueue.Add(OperationDescription(OperationName, JobParameter));
EndProcedure

&AtClient
Function DeleteCurrentJob()
	JobDetails = OperationDescription("");
	
	If FormJobsQueue.Count() <> 0 Then
		JobDetails = FormJobsQueue[0];
		FormJobsQueue.Delete(0);
	EndIf;
	
	Return JobDetails.Parameter;
EndFunction

&AtClient
Function CurrentJob()
	Return ?(FormJobsQueue.Count() = 0, OperationDescription(""), FormJobsQueue[0]);
EndFunction

&AtClient
Procedure RunJobWithPending()
	RunJob();
	ReadOnly = False;
EndProcedure

&AtClient
Procedure RunJob(Job = "", Parameter = Undefined)
	Result = New Structure("Success", True);
	
	If Not IsBlankString(Job) And Job <> CurrentJob().Name Then
		AddJob(Job);
	EndIf;
	
	If CurrentOperation1 <> Undefined Then
		Return;
	EndIf;
	
	CurrentFormJob = CurrentJob();
	If Not IsBlankString(CurrentFormJob.Name) Then
		
		If DeletionMode = "Exclusive" 
				And CurrentFormJob.Name <> FormJobs().MarkedObjectsSearch Then
				
			Result = SetExclusiveModeAtServer(True);
			If Not Result.Success Then
				Result.Insert("Status", "Error");
				FillInformationWithBackgroundJobErrors(ThisObject, Result);
				Items.StatePresentationPages.Visible = True;
				Items.StatePresentationPages.CurrentPage = Items.CompletedWithErrorsState;
				Return;
			EndIf;
		EndIf;	
		
		JobInProgress = True;
		
		If CurrentFormJob.Name = FormJobs().DeleteMarkedObjects Then
			StartMarkedObjectsDeletion(CurrentFormJob.Parameter);
		ElsIf CurrentFormJob.Name = FormJobs().MarkedObjectsSearch Then 
			StartMarkedObjectsSearch(CurrentFormJob.Parameter);
		ElsIf CurrentFormJob.Name = FormJobs().AdditionalDataProcessorExecution Then 
			StartAdditionalDataProcessorExecution(CurrentFormJob.Parameter);
		EndIf;
		
	EndIf;
EndProcedure

&AtClient
Function FormJobs()
	Jobs = New Structure;
	Jobs.Insert("DeleteMarkedObjects", "DeleteMarkedObjects");
	Jobs.Insert("MarkedObjectsSearch", "MarkedObjectsSearch");
	Jobs.Insert("AdditionalDataProcessorExecution", "AdditionalDataProcessorExecution");
	Return Jobs;
EndFunction

&AtClient
Procedure ClearFormJobsQueue()
	FormJobsQueue.Clear();
EndProcedure

&AtClient
Function JobsCountInQueue()
	Return  FormJobsQueue.Count();
EndFunction

#EndRegion

#Region Initialization

DeletionResultsInfo = MarkedObjectsDeletionInternalClientServer.NewDeletionResultsInfo(); 
PresentationOperation = "";
FormJobsQueue = New Array;

#EndRegion