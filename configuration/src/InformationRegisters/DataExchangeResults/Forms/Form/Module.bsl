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
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		
		Items.UnpostedDocumentsContextMenu.ChildItems.UnpostedDocumentsContextMenuEditSelectedDocuments.Visible = False;
		Items.UnpostedDocumentsEditSelectedDocuments.Visible = False;
		Items.BlankAttributesContextMenu.ChildItems.BlankAttributesContextMenuEditSelectedObjects.Visible = False;
		Items.BlankAttributesEditSelectedObjects.Visible = False;
		
	EndIf;
	
	PeriodClosingDatesEnabled = 
		Common.SubsystemExists("StandardSubsystems.PeriodClosingDates");
	
	VersioningUsed = DataExchangeCached.VersioningUsed(, True);
	
	If VersioningUsed Then
		
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.InitializeDynamicListOfCorruptedVersions(Conflicts, "Conflicts");
		
		If PeriodClosingDatesEnabled Then
			ModuleObjectsVersioning.InitializeDynamicListOfCorruptedVersions(RejectedDueToDate, "RejectedDueToDate");
		EndIf;
		
	EndIf;
	
	Items.ConflictPage.Visible                = VersioningUsed;
	Items.RejectedByRestrictionDatePage.Visible = VersioningUsed And PeriodClosingDatesEnabled;
	
	// Setting filters of dynamic lists and saving them in the attribute to manage them.
	DynamicListsFiltersSettings = DynamicListsFiltersSettings();
	
	If Common.DataSeparationEnabled() And VersioningUsed Then
		Items.ConflictsOtherVersionAuthor.Title = NStr("en = 'The version is received from the application';");
	EndIf;
	
	FillNodeList();
	UpdateFiltersAndIgnored();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshIssueDetailsDisplay();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	Notify("DataExchangeResultFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	UpdateAtServer();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	UpdateFiltersAndIgnored();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	UpdateFilterByReason();
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	UpdateFilterByPeriod();
	
EndProcedure

&AtClient
Procedure InfobaseNodeClearing(Item, StandardProcessing)
	
	InfobaseNode = Undefined;
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeOnChange(Item)
	
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InfobaseNode.ListChoiceMode Then
		
		StandardProcessing = False;
		
		Handler = New NotifyDescription("InfobaseNodeStartChoiceCompletion", ThisObject);
		Mode = FormWindowOpeningMode.LockOwnerWindow;
		OpenForm("CommonForm.SelectExchangePlanNodes",,,,,, Handler, Mode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoiceCompletion(ClosingResult, AdditionalParameters) Export
	
	InfobaseNode = ClosingResult;
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InfobaseNode = ValueSelected;
	
EndProcedure

&AtClient
Procedure DataExchangeResultsOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.ConflictPage Then
		Items.SearchString.Enabled = False;
	Else
		Items.SearchString.Enabled = True;
	EndIf;
	
	RefreshIssueDetailsDisplay();
	
EndProcedure

#EndRegion

#Region UnpostedDocumentsFormTableItemEventHandlers

&AtClient
Procedure UnpostedDocumentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure UnpostedDocumentsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region BlankAttributesFormTableItemEventHandlers

&AtClient
Procedure BlankAttributesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure BlankAttributesBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region XDTOErrorsFormTableItemsEventHandlers

&AtClient
Procedure XDTOObjectErrorsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.XDTOObjectErrors);

EndProcedure

&AtClient
Procedure XDTOObjectErrorsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;

EndProcedure

#EndRegion

#Region ConflictsFormTableItemEventHandlers

&AtClient
Procedure ConflictsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ConflictsOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.OtherVersionAccepted Then
			
			ConflictReason = NStr("en = 'The conflict was automatically resolved for application ""%1"". 
				|This application version was replaced with the version of another application.';");
			ConflictReason = StringFunctionsClientServer.SubstituteParametersToString(ConflictReason, Item.CurrentData.OtherVersionAuthor);
			
		Else
			
			ConflictReason =NStr("en = 'The conflict was automatically resolved for this application.
				|This application version was saved, the other application version was rejected.';");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DeclinedByDateFormTableItemsEventHandlers

&AtClient
Procedure RejectedDueToDateBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure RejectedDueToDateOnActivateRow(Item)
	
	LinkedItems1 = New Array; // Array of FormGroup, FormButton
	LinkedItems1.Add(Items.DeclinedByDateCompareWithInfobaseData);
	LinkedItems1.Add(Items.DeclinedByDateAcceptVersion);
	LinkedItems1.Add(Items.RejectedDueToDateChange);
	LinkedItems1.Add(Items.DeclinedByDateOpenVersion);
	LinkedItems1.Add(Items.RejectedDueToDateIgnoreDeclined);
	LinkedItems1.Add(Items.RejectedDueToDateDoNotIgnoreDeclined);
	
	LinkedItems1.Add(Items.DeclinedByDateContextMenuCompareWithInfobaseData);
	LinkedItems1.Add(Items.DeclinedByDateContextMenuAcceptVersion);
	LinkedItems1.Add(Items.RejectedDueToDateContextMenuChange);
	LinkedItems1.Add(Items.RejectedDueToDateContextMenuOpenVersionDeclinedInThisApplication);
	LinkedItems1.Add(Items.DeclinedByDateContextMenuOpenVersion);
	LinkedItems1.Add(Items.DeclinedByDateContextMenuIgnoredGroup);
	
	For Each LinkedItem1 In LinkedItems1 Do
		LinkedItem1.Enabled = (Item.CurrentData <> Undefined);
	EndDo;
	
EndProcedure

#EndRegion

#Region ErrorOnExecuteSendingHandlersCodeFormTableItemEventHandlers

&AtClient
Procedure ErrorOnExecuteSendingHandlersCodeBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region ErrorOnExecuteSendingHandlersCodeFormTableItemEventHandlers

&AtClient
Procedure ErrorOnExecuteGettingHandlersCodeBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowInformationForTechnicians(Command)
	
	LogFilterParameters = PrepareEventLogFilters();
	OpenForm("DataProcessor.EventLog.Form", LogFilterParameters, ThisObject,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	ObjectChange();
	
EndProcedure

&AtClient
Procedure IgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, True, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, False, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, False, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure IgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, True, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure NotIgnoreError(Command)
	
	Ignore(Items.XDTOObjectErrors.SelectedRows, False, "XDTOObjectErrors");
	
EndProcedure

&AtClient
Procedure IgnoreError(Command)
	
	Ignore(Items.XDTOObjectErrors.SelectedRows, True, "XDTOObjectErrors");
	
EndProcedure

&AtClient
Procedure EditSelectedDocuments(Command)
	
	ChangeSelectedItems(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure EditSelectedObjects(Command)
	
	ChangeSelectedItems(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure ChangeSelectedCheckErrors(Command)
	
	ChangeSelectedItems(Items.XDTOObjectErrors);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateAtServer();
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	ClearMessages();
	
	ErrorMessage = "";
	PostDocuments(Items.UnpostedDocuments.SelectedRows, ErrorMessage);
	If Not IsBlankString(ErrorMessage) Then
		ShowMessageBox(, ErrorMessage);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowDifferencesRejectedItems(Command)
	
	ShowDifferences(Items.RejectedDueToDate);
	
EndProcedure

&AtClient
Procedure OpenVersionDeclined(Command)
	
	If Items.RejectedDueToDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(Items.RejectedDueToDate.CurrentData.OtherVersionNumber);
	OpenVersionComparisonReport(Items.RejectedDueToDate.CurrentData.Ref, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenVersionDeclinedInThisApplication(Command)
	
	If Items.RejectedDueToDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(Items.RejectedDueToDate.CurrentData.ThisVersionNumber);
	OpenVersionComparisonReport(Items.RejectedDueToDate.CurrentData.Ref, VersionsToCompare);

EndProcedure

&AtClient
Procedure ShowDifferencesConflicts(Command)
	
	ShowDifferences(Items.Conflicts);
	
EndProcedure

&AtClient
Procedure IgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, True, "Conflicts");
	
EndProcedure

&AtClient
Procedure IgnoreDeclined(Command)
	
	IgnoreVersion(Items.RejectedDueToDate.SelectedRows, True, "RejectedDueToDate");
	
EndProcedure

&AtClient
Procedure NotIgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, False, "Conflicts");
	
EndProcedure

&AtClient
Procedure NotIgnoreDeclined(Command)
	
	IgnoreVersion(Items.RejectedDueToDate.SelectedRows, False, "RejectedDueToDate");
	
EndProcedure

&AtClient
Procedure AcceptVersionDeclined(Command)
	
	NotifyDescription = New NotifyDescription("AcceptVersionDeclinedCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to accept the version even though import is restricted?';"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure AcceptVersionDeclinedCompletion(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ClearMessages();
	
	ErrorMessage = "";
	AcceptRejectVersionAtServer(Items.RejectedDueToDate.SelectedRows, "RejectedDueToDate", ErrorMessage);
	If Not IsBlankString(ErrorMessage) Then
		ShowMessageBox(, ErrorMessage);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPreConflictVersion(Command)
	
	OpenVersionAtClient("ThisVersionNumber");
	
EndProcedure

&AtClient
Procedure OpenConflictVersion(Command)
	
	OpenVersionAtClient("OtherVersionNumber");
	
EndProcedure

&AtClient
Procedure ShowIgnoredConflicts(Command)
	
	ShowIgnoredConflicts = Not ShowIgnoredConflicts;
	ShowIgnoredConflictsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredBlankItems(Command)
	
	ShowIgnoredBlankItems = Not ShowIgnoredBlankItems;
	ShowIgnoredBlankItemsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredErrors(Command)
	
	ShowIgnoredErrors = Not ShowIgnoredErrors;
	ShowIgnoredErrorsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredRejectedItems(Command)
	
	ShowIgnoredRejectedItems = Not ShowIgnoredRejectedItems;
	ShowIgnoredRejectedItemsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredUnpostedItems(Command)
	
	ShowIgnoredUnpostedItems = Not ShowIgnoredUnpostedItems;
	ShowIgnoredUnpostedItemsAtServer();
	
EndProcedure

&AtClient
Procedure ChangeConflictResult(Command)
	
	If Items.Conflicts.CurrentData <> Undefined Then
		
		If Items.Conflicts.CurrentData.OtherVersionAccepted Then
			
			QueryText = NStr("en = 'Do you want to replace the version from another application with the version from this application?';");
			
		Else
			
			QueryText = NStr("en = 'Do you want to replace the version from this application with the version from another application?';");
			
		EndIf;
		
		NotifyDescription = New NotifyDescription("ChangeConflictResultCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeConflictResultCompletion(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ClearMessages();
	
	ErrorMessage = "";
	AcceptRejectVersionAtServer(Items.Conflicts.SelectedRows, "Conflicts", ErrorMessage);
	If Not IsBlankString(ErrorMessage) Then
		ShowMessageBox(, ErrorMessage);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshIssueDetailsDisplay()
	
	Items.PanelDetails.CurrentPage = Items[Items.DataExchangeResults.CurrentPage.Name + "DetailedDescription"];
	
EndProcedure

&AtServer
Function PrepareEventLogFilters()
	
	WarningsLevels = New Array();
	WarningsLevels.Add(String(EventLogLevel.Error));
	WarningsLevels.Add(String(EventLogLevel.Warning));
	
	LogFilterParameters = New Structure;
	LogFilterParameters.Insert("EventLogEvent", DataExchangeServer.DataExchangeEventLogEvent());
	LogFilterParameters.Insert("Level",                   WarningsLevels);   
	
	Return LogFilterParameters;
	
EndFunction

&AtServer
Procedure Ignore(Val SelectedRows, Ignore, TagName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
	
		InformationRegisters.DataExchangeResults.Ignore(SelectedRow.ObjectWithIssue, SelectedRow.IssueType, Ignore);
	
	EndDo;
	
	UpdateAtServer(TagName);
	
EndProcedure

&AtServer
Procedure ShowIgnoredConflictsAtServer(ShouldUpdate = True)
	
	Items.ConflictsShowIgnoredConflicts.Check = ShowIgnoredConflicts;
	
	Filter = Conflicts.SettingsComposer.Settings.Filter;
	FilterElement = Filter.GetObjectByID( DynamicListsFiltersSettings.Conflicts.VersionIgnored );
	FilterElement.RightValue = ShowIgnoredConflicts;
	FilterElement.Use  = Not ShowIgnoredConflicts;
	
	If ShouldUpdate Then
		UpdateAtServer("Conflicts");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredBlankItemsAtServer(ShouldUpdate = True)
	
	Items.BlankAttributesShowIgnoredBlankItems.Check = ShowIgnoredBlankItems;
	
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	FilterElement = Filter.GetObjectByID( DynamicListsFiltersSettings.BlankAttributes.IsSkipped );
	FilterElement.RightValue = ShowIgnoredBlankItems;
	FilterElement.Use  = Not ShowIgnoredBlankItems;
	
	If ShouldUpdate Then
		UpdateAtServer("BlankAttributes");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredErrorsAtServer(ShouldUpdate = True)
	
	Items.XDTOObjectErrorsShowIgnored.Check = ShowIgnoredErrors;
	Filter = XDTOObjectErrors.SettingsComposer.Settings.Filter;
	FilterElement = Filter.GetObjectByID( DynamicListsFiltersSettings.XDTOObjectErrors.IsSkipped );
	FilterElement.RightValue = ShowIgnoredErrors;
	FilterElement.Use  = Not ShowIgnoredErrors;
	
	If ShouldUpdate Then
		UpdateAtServer("BlankAttributes");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredRejectedItemsAtServer(ShouldUpdate = True)
	
	Items.RejectedDueToDateShowIgnoredRejectedItems.Check = ShowIgnoredRejectedItems;
	
	Filter = RejectedDueToDate.SettingsComposer.Settings.Filter;
	FilterElement = Filter.GetObjectByID( DynamicListsFiltersSettings.RejectedDueToDate.VersionIgnored );
	FilterElement.RightValue = ShowIgnoredRejectedItems;
	FilterElement.Use  = Not ShowIgnoredRejectedItems;
	
	If ShouldUpdate Then
		UpdateAtServer("RejectedDueToDate");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredUnpostedItemsAtServer(ShouldUpdate = True)
	
	Items.UnpostedDocumentsShowIgnoredUnpostedItems.Check = ShowIgnoredUnpostedItems;
	
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	FilterElement = Filter.GetObjectByID( DynamicListsFiltersSettings.UnpostedDocuments.IsSkipped );
	FilterElement.RightValue = ShowIgnoredUnpostedItems;
	FilterElement.Use  = Not ShowIgnoredUnpostedItems;
	
	If ShouldUpdate Then
		UpdateAtServer("UnpostedDocuments");
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeSelectedItems(List)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchObjectsModificationClient.ChangeSelectedItems(List);
	EndIf;
	
EndProcedure

&AtServer
Procedure PostDocuments(Val SelectedRows, ErrorMessage = "")
	
	TotalDocumentsCounter = 0;
	UnpostedDocumentsCounter = 0;
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		TotalDocumentsCounter = TotalDocumentsCounter + 1;
		
		LockSet = False;
		
		BeginTransaction();
		Try
			LockDataForEdit(SelectedRow.ObjectWithIssue);
			LockSet = True;
			
			DocumentObject = SelectedRow.ObjectWithIssue.GetObject();
			
			If DocumentObject.CheckFilling() Then
				DocumentObject.Write(DocumentWriteMode.Posting);
			Else
				UnpostedDocumentsCounter = UnpostedDocumentsCounter + 1;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			If Not LockSet Then
				Common.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot post the document ""%1"" due to:
					|%2.';"),
					SelectedRow.ObjectWithIssue,
					ErrorProcessing.BriefErrorDescription(ErrorInfo())));
			EndIf;
			UnpostedDocumentsCounter = UnpostedDocumentsCounter + 1;
		EndTry;
	
	EndDo;
	
	If UnpostedDocumentsCounter > 0 Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Not posted documents: %1 from %2.';"),
			Format(UnpostedDocumentsCounter, "NZ=; NG=0"),
			Format(TotalDocumentsCounter, "NZ=; NG=0"));
	EndIf;
		
	UpdateAtServer("UnpostedDocuments");
	
EndProcedure

&AtServer
Procedure FillNodeList()
	
	NoneExchangeByRules  = True;
	NoneXDTOExchange        = True;
	NoneDIBExchange         = True;
	NoneStandardExchange = True;
	
	ContextOpening = ValueIsFilled(Parameters.ExchangeNodes);
	
	ExchangeNodes = ?(ContextOpening, Parameters.ExchangeNodes, NodesArrayOnOpenOutOfContext());
	Items.InfobaseNode.ChoiceList.LoadValues(ExchangeNodes);
	
	For Each ExchangeNode In ExchangeNodes Do
		
		ExchangePlanName               = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		IsXDTOExchangePlanNode       = DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName);
		IsDIBExchangePlanNode        = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
		IsExchangePlanNodeByRules = DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules");
		
		If IsXDTOExchangePlanNode Then			
			NoneXDTOExchange = False;
		EndIf;
		
		If IsExchangePlanNodeByRules Then
			NoneExchangeByRules = False;
		EndIf;
		
		If IsDIBExchangePlanNode Then
			NoneDIBExchange = False;
		EndIf;
		
		If Not IsXDTOExchangePlanNode
			And Not IsExchangePlanNodeByRules 
			And Not IsDIBExchangePlanNode Then
		    NoneStandardExchange = False;
		EndIf;
		
	EndDo;
	
	SetFilterByNodes(ExchangeNodes);
	NodesList = New ValueList;
	NodesList.LoadValues(ExchangeNodes);
	
	If ExchangeNodes.Count() < 2 Then
		
		InfobaseNode = Undefined;
		Items.InfobaseNode.Visible = False;
		Items.UnpostedDocumentsInfobaseNode.Visible = False;
		Items.BlankAttributesInfobaseNode.Visible = False;
		Items.XDTOObjectErrorsInfobaseNode.Visible = False;
		
		If VersioningUsed Then
			Items.ConflictsOtherVersionAuthor.Visible = False;
			Items.RejectedDueToDateOtherVersionAuthor.Visible = False;
		EndIf;
		
	ElsIf ExchangeNodes.Count() >= 7 Then
		
		Items.InfobaseNode.ListChoiceMode = False;
		
	EndIf;
	
	Items.SearchString.Visible = True;
	
	If NoneExchangeByRules And NoneXDTOExchange And NoneStandardExchange Then
		
		Title = NStr("en = 'Data synchronization conflicts';");
		Items.SearchString.Visible = False;
		Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage;
		Items.DataExchangeResults.PagesRepresentation = FormPagesRepresentation.None;
		
	Else
		
		Items.XDTOErrorPage.Visible             = Not NoneXDTOExchange;
		Items.BlankAttributesPage.Visible = Not NoneXDTOExchange Or Not NoneExchangeByRules;
		Items.UnpostedDocumentsPage.Visible = Not NoneXDTOExchange Or Not NoneExchangeByRules;		
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFilterByNodes(ExchangeNodes)
	
	FilterByNodesDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.NodeInList);
	FilterByNodesDocument.Use = True;
	FilterByNodesDocument.RightValue = ExchangeNodes;
	
	FilterByNodesObject = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.NodeInList);
	FilterByNodesObject.Use = True;
	FilterByNodesObject.RightValue = ExchangeNodes;
	
	FilterByNodesObject = DynamicListFilterItem(XDTOObjectErrors,
		DynamicListsFiltersSettings.XDTOObjectErrors.NodeInList);
	FilterByNodesObject.Use = True;
	FilterByNodesObject.RightValue = ExchangeNodes;

	
	If VersioningUsed Then
		
		FilterByNodesConflict = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.AuthorInList);
		FilterByNodesConflict.Use = True;
		FilterByNodesConflict.RightValue = ExchangeNodes;
		
		FilterByNodesNotAccepted = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.AuthorInList);
		FilterByNodesNotAccepted.Use = True;
		FilterByNodesNotAccepted.RightValue = ExchangeNodes;
		
	EndIf;
	
EndProcedure

&AtServer
Function NodesArrayOnOpenOutOfContext()
	
	ExchangeNodes = New Array;
	
	ExchangePlansList = DataExchangeCached.SSLExchangePlans();
	
	For Each ExchangePlanName In ExchangePlansList Do
		
		If Not AccessRight("Read", ExchangePlans[ExchangePlanName].EmptyRef().Metadata()) Then
			Continue;
		EndIf;	
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	ExchangePlanTable.Ref AS ExchangeNode
		|FROM
		|	&ExchangePlanTable AS ExchangePlanTable
		|WHERE
		|	NOT ExchangePlanTable.ThisNode
		|	AND ExchangePlanTable.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
		Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			ExchangeNodes.Add(Selection.ExchangeNode);
			
		EndDo;
		
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure UpdateFilterByNode(ShouldUpdate = True)
	
	Use = ValueIsFilled(InfobaseNode);
	
	FilterByNodeDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.NodeEqual);
	FilterByNodeDocument.Use = Use;
	FilterByNodeDocument.RightValue = InfobaseNode;
	
	FilterByNodeObject = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.NodeEqual);
	FilterByNodeObject.Use = Use;
	FilterByNodeObject.RightValue = InfobaseNode;
	
	FilterByNodeObject = DynamicListFilterItem(XDTOObjectErrors,
		DynamicListsFiltersSettings.XDTOObjectErrors.NodeEqual);
	FilterByNodeObject.Use = Use;
	FilterByNodeObject.RightValue = InfobaseNode;

	
	If VersioningUsed Then
		
		FilterByNodeConflicts = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.AuthorEqual);
		FilterByNodeConflicts.Use = Use;
		FilterByNodeConflicts.RightValue = InfobaseNode;
		
		FilterByNodeNotAccepted = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.AuthorEqual);
		FilterByNodeNotAccepted.Use = Use;
		FilterByNodeNotAccepted.RightValue = InfobaseNode;
		
	EndIf;
	
	If ShouldUpdate Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Function NotAcceptedCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	QueryOptions = DataExchangeServer.QueryParametersVersioningIssuesCount();
	
	QueryOptions.IsConflictsCount      = False;
	QueryOptions.IncludingIgnored = ShowIgnoredRejectedItems;
	QueryOptions.Period                     = Period;
	QueryOptions.SearchString               = SearchString;
	
	Return DataExchangeServer.VersioningIssuesCount(ExchangeNodes, QueryOptions);
	
EndFunction

&AtServer
Function ConflictCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	QueryOptions = DataExchangeServer.QueryParametersVersioningIssuesCount();
	
	QueryOptions.IsConflictsCount      = True;
	QueryOptions.IncludingIgnored = ShowIgnoredConflicts;
	QueryOptions.Period                     = Period;
	QueryOptions.SearchString               = SearchString;
	
	Return DataExchangeServer.VersioningIssuesCount(ExchangeNodes, QueryOptions);
	
EndFunction

&AtServer
Function BlankAttributeCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	SearchParameters = InformationRegisters.DataExchangeResults.IssueSearchParameters();
	SearchParameters.IssueType                = Enums.DataExchangeIssuesTypes.BlankAttributes;
	SearchParameters.IncludingIgnored = ShowIgnoredBlankItems;
	SearchParameters.Period                     = Period;
	SearchParameters.SearchString               = SearchString;
	SearchParameters.ExchangePlanNodes            = ExchangeNodes;
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(SearchParameters);
	
EndFunction

&AtServer
Function UnpostedDocumentCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	SearchParameters = InformationRegisters.DataExchangeResults.IssueSearchParameters();
	SearchParameters.IssueType                = Enums.DataExchangeIssuesTypes.UnpostedDocument;
	SearchParameters.IncludingIgnored = ShowIgnoredUnpostedItems;
	SearchParameters.Period                     = Period;
	SearchParameters.SearchString               = SearchString;
	SearchParameters.ExchangePlanNodes            = ExchangeNodes;	
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(SearchParameters);
	
EndFunction

&AtServer
Function XDTOErrorsCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	SearchParameters = InformationRegisters.DataExchangeResults.IssueSearchParameters();
	SearchParameters.IssueType                = Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError;
	SearchParameters.IncludingIgnored = ShowIgnoredErrors;
	SearchParameters.Period                     = Period;
	SearchParameters.SearchString               = SearchString;
	SearchParameters.ExchangePlanNodes            = ExchangeNodes;	
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(SearchParameters);
	
EndFunction

&AtServer
Procedure SetPageTitle(Page, Var_Title, Count)
	
	AdditionalString = ?(Count > 0, " (" + Count + ")", "");
	Var_Title = Var_Title + AdditionalString;
	Page.Title = Var_Title;
	
EndProcedure

&AtClient
Procedure OpenObject(Item)
	
	If Item.CurrentRow = Undefined Or TypeOf(Item.CurrentRow) = Type("DynamicListGroupRow") Then
		ShowMessageBox(, NStr("en = 'Cannot run the command for the object.';"));
		Return;
	Else
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectChange()
	
	ResultsPages = Items.DataExchangeResults;
	
	If ResultsPages.CurrentPage = ResultsPages.ChildItems.UnpostedDocumentsPage Then
		
		OpenObject(Items.UnpostedDocuments); 
		
	ElsIf ResultsPages.CurrentPage = ResultsPages.ChildItems.BlankAttributesPage Then
		
		OpenObject(Items.BlankAttributes);
		
	ElsIf ResultsPages.CurrentPage = ResultsPages.ChildItems.XDTOErrorPage Then
		
		OpenObject(Items.XDTOObjectErrors); 		
		
	ElsIf ResultsPages.CurrentPage = ResultsPages.ChildItems.ConflictPage Then
		
		OpenObject(Items.Conflicts);
		
	ElsIf ResultsPages.CurrentPage = ResultsPages.ChildItems.RejectedByRestrictionDatePage Then
		
		OpenObject(Items.RejectedDueToDate);
		
	ElsIf ResultsPages.CurrentPage = Items.DataSendingHandlersExecutionErrorPage Then
		
		OpenObject(Items.ErrorOnExecuteSendingHandlersCode);
		
	ElsIf ResultsPages.CurrentPage = Items.DataReceivingHandlersExecutionErrorPage Then
		
		OpenObject(Items.ErrorOnExecuteGettingHandlersCode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowDifferences(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	
	If Item.CurrentData.ThisVersionNumber <> 0 Then
		VersionsToCompare.Add(Item.CurrentData.ThisVersionNumber);
	EndIf;
	
	If Item.CurrentData.OtherVersionNumber <> 0 Then
		VersionsToCompare.Add(Item.CurrentData.OtherVersionNumber);
	EndIf;
	
	If VersionsToCompare.Count() <> 2 Then
		
		CommonClient.MessageToUser(NStr("en = 'No object version to compare.';"));
		Return;
		
	EndIf;
	
	OpenVersionComparisonReport(Item.CurrentData.Ref, VersionsToCompare);
	
EndProcedure

&AtServer
Procedure UpdateFilterByReason(ShouldUpdate = True)
	
	SearchStringSpecified = ValueIsFilled(SearchString);
	
	CommonClientServer.SetDynamicListFilterItem(
		UnpostedDocuments, "Cause", SearchString, DataCompositionComparisonType.Contains, , SearchStringSpecified);
	
	CommonClientServer.SetDynamicListFilterItem(
		BlankAttributes, "Cause", SearchString, DataCompositionComparisonType.Contains, , SearchStringSpecified);
		
	CommonClientServer.SetDynamicListFilterItem(
		XDTOObjectErrors, "Cause", SearchString, DataCompositionComparisonType.Contains, , SearchStringSpecified);
		
	If VersioningUsed Then
	
		CommonClientServer.SetDynamicListFilterItem(
			RejectedDueToDate, "ProhibitionReason", SearchString, DataCompositionComparisonType.Contains, , SearchStringSpecified);
		
	EndIf;
	
	If ShouldUpdate Then
		UpdateAtServer();
	EndIf;
	
EndProcedure

// Parameters:
//   DynamicList - DynamicList - an object to set a filter.
//   FilterSettings - See FilterSettingByExchangeResults
//                   - See FilterSettingByObjectsVersions
//
&AtServer
Procedure UpdateDynamicListFilterByPeriod(DynamicList, FilterSettings)
	
	Use = ValueIsFilled(Period);
	
	FilterByPeriodFrom  = DynamicListFilterItem(DynamicList, FilterSettings.StartDate);
	FilterByPeriodTo = DynamicListFilterItem(DynamicList, FilterSettings.EndDate);
		
	FilterByPeriodFrom.Use  = Use;
	FilterByPeriodTo.Use = Use;
	
	FilterByPeriodFrom.RightValue  = Period.StartDate;
	FilterByPeriodTo.RightValue = Period.EndDate;
	
EndProcedure

&AtServer
Procedure UpdateFilterByPeriod(ShouldUpdate = True)
	
	// 
	FilterSettings = DynamicListsFiltersSettings.UnpostedDocuments; // See FilterSettingByExchangeResults
	UpdateDynamicListFilterByPeriod(UnpostedDocuments, FilterSettings);
	
	// 
	FilterSettings = DynamicListsFiltersSettings.BlankAttributes; // See FilterSettingByExchangeResults
	UpdateDynamicListFilterByPeriod(BlankAttributes, FilterSettings);
	
	// 
	FilterSettings = DynamicListsFiltersSettings.XDTOObjectErrors; // See FilterSettingByExchangeResults
	UpdateDynamicListFilterByPeriod(XDTOObjectErrors, FilterSettings);
	
	If VersioningUsed Then
		
		FilterSettings = DynamicListsFiltersSettings.Conflicts; // See FilterSettingByObjectsVersions
		UpdateDynamicListFilterByPeriod(Conflicts, FilterSettings);
		
		FilterSettings = DynamicListsFiltersSettings.RejectedDueToDate; // See FilterSettingByObjectsVersions
		UpdateDynamicListFilterByPeriod(RejectedDueToDate, FilterSettings);
		
	EndIf;
	
	If ShouldUpdate Then
		UpdateAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure IgnoreVersion(Val SelectedRows, Ignore, TagName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
			ModuleObjectsVersioning.IgnoreObjectVersion(SelectedRow.Object,
				SelectedRow.VersionNumber, Ignore);
		EndIf;
		
	EndDo;
	
	UpdateAtServer(TagName);
	
EndProcedure

&AtServer
Procedure UpdateAtServer(UpdatedItem = "")
	
	UpdateFormLists(UpdatedItem);
	UpdatePageTitles();
	
EndProcedure

&AtServer
Procedure UpdateFormLists(UpdatedItem)
	
	If ValueIsFilled(UpdatedItem) Then
		
		FormItem = Items.Find(UpdatedItem);
		If FormItem <> Undefined Then
			FormItem.Refresh();
		EndIf;
		
	Else
		
		Items.UnpostedDocuments.Refresh();
		Items.BlankAttributes.Refresh();
		Items.XDTOObjectErrors.Refresh();
		
		If VersioningUsed Then
			Items.Conflicts.Refresh();
			Items.RejectedDueToDate.Refresh();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePageTitles()
	
	SetPageTitle(Items.UnpostedDocumentsPage, NStr("en = 'Unposted documents';"), UnpostedDocumentCount());
	SetPageTitle(Items.BlankAttributesPage, NStr("en = 'Blank attributes';"), BlankAttributeCount());
	SetPageTitle(Items.XDTOErrorPage,             NStr("en = 'An error occurred when checking the objects being converted';"), XDTOErrorsCount());	
	
	If VersioningUsed Then
		SetPageTitle(Items.ConflictPage, NStr("en = 'Conflicts';"), ConflictCount());
		SetPageTitle(Items.RejectedByRestrictionDatePage, NStr("en = 'Items rejected due to restriction date';"), NotAcceptedCount());
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionAtClient(FieldVersion)
	
	CurrentData = CurrentConflictsTableData();
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(CurrentData[FieldVersion]);
	OpenVersionComparisonReport(CurrentData.Ref, VersionsToCompare);
	
EndProcedure

// Returns:
//   FormDataStructure:
//     * Date - Date
//     * Ref - AnyRef
//     * TypeAsString - String
//     * ThisVersionNumber - Number
//     * OtherVersionNumber - Number
//     * OtherVersionAuthor - CatalogRef.ExternalUsers
//                         - CatalogRef.Users
//                         - ExchangePlanRef
//     * OtherVersionAccepted - Boolean
//     * VersionIgnored - Boolean
//
&AtClient
Function CurrentConflictsTableData()
	
	Return Items.Conflicts.CurrentData;
	
EndFunction

&AtClient
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
		ModuleObjectsVersioningClient.OpenVersionComparisonReport(Ref, VersionsToCompare);
	EndIf;
	
EndProcedure

&AtServer
Procedure AcceptRejectVersionAtServer(Val SelectedRows, TagName, ErrorMessage = "")
	
	ModuleObjectsVersioning = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
	EndIf;
	
	TotalDocumentsCounter = 0;
	RejectedDocumentsCounter = 0;
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		TotalDocumentsCounter = TotalDocumentsCounter + 1;
		
		If ModuleObjectsVersioning = Undefined Then
			RejectedDocumentsCounter = RejectedDocumentsCounter + 1;
		Else
			Try
				ModuleObjectsVersioning.OnStartUsingNewObjectVersion(SelectedRow.Object,
					SelectedRow.VersionNumber);
			Except
				ObjectPresentation = ?(Common.RefExists(SelectedRow.Object),
					SelectedRow.Object,
					SelectedRow.Object.Metadata());
				Common.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot accept the object version ""%1"" due to:
					|%2.';"),
					ObjectPresentation,
					ErrorProcessing.BriefErrorDescription(ErrorInfo())));
				RejectedDocumentsCounter = RejectedDocumentsCounter + 1;
			EndTry;
		EndIf;
		
	EndDo;
	
	If RejectedDocumentsCounter > 0 Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Not accepted object versions: %1 from %2.';"),
			Format(RejectedDocumentsCounter, "NZ=; NG=0"),
			Format(TotalDocumentsCounter, "NZ=; NG=0"));
	EndIf;
	
	UpdateAtServer(TagName);
	
EndProcedure

// Parameters:
//   Filter - DataCompositionFilter - a filter object.
//
// Returns:
//   Structure:
//     * IsSkipped - DataCompositionID
//                 - Undefined - 
//     * StartDate - DataCompositionID
//                  - Undefined - 
//     * EndDate - DataCompositionID
//                     - Undefined - 
//     * NodeEqual - DataCompositionID
//                 - Undefined - 
//     * Cause - DataCompositionID
//               - Undefined - 
//     * NodeInList - DataCompositionID
//                   - Undefined - 
//
&AtServer
Function FilterSettingByExchangeResults(Filter)
	
	Setting = New Structure;
	
	Setting.Insert("IsSkipped", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "IsSkipped", DataCompositionComparisonType.Equal, False, ,True)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("NodeEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Setting.Insert("Cause", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Cause", DataCompositionComparisonType.Contains, Undefined, , False)));
	Setting.Insert("NodeInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	Return Setting;
	
EndFunction

// Parameters:
//   Filter - DataCompositionFilter - a filter object.
//   FilterByReason - Boolean - True if the setup must include a filter by issue reason.
//
// Returns:
//   Structure:
//     * AuthorEqual - DataCompositionID
//                  - Undefined - 
//     * StartDate - DataCompositionID
//                  - Undefined - 
//     * EndDate - DataCompositionID
//                     - Undefined - 
//     * VersionIgnored - DataCompositionID
//                             - Undefined - 
//     * AuthorInList - DataCompositionID
//                    - Undefined - 
//     * ProhibitionReason - DataCompositionID
//                      - Undefined - 
//
&AtServer
Function FilterSettingByObjectsVersions(Filter, FilterByReason = False)
	
	Setting = New Structure;
	
	Setting.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
	Setting.Insert("AuthorInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
	If FilterByReason Then
		Setting.Insert("ProhibitionReason", Filter.GetIDByObject(
			CommonClientServer.AddCompositionItem(Filter, "ProhibitionReason", DataCompositionComparisonType.Equal, Undefined, , False)));
	EndIf;
		
	Return Setting;
	
EndFunction

// Returns:
//   Structure:
//     * UnpostedDocuments - See FilterSettingByExchangeResults
//     * BlankAttributes - See FilterSettingByExchangeResults
//     * XDTOObjectErrors - See FilterSettingByExchangeResults
//     * Conflicts - See FilterSettingByObjectsVersions
//     * RejectedDueToDate - See FilterSettingByObjectsVersions
//
&AtServer
Function DynamicListsFiltersSettings()
	
	Result = New Structure;
	
	// Unposted documents.
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	Result.Insert("UnpostedDocuments", FilterSettingByExchangeResults(Filter));
		
	// 
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	Result.Insert("BlankAttributes", FilterSettingByExchangeResults(Filter));
		
	// 
	Filter = XDTOObjectErrors.SettingsComposer.Settings.Filter;
	Result.Insert("XDTOObjectErrors", FilterSettingByExchangeResults(Filter));
		
	If VersioningUsed Then
		
		// Конфликты
		Filter = Conflicts.SettingsComposer.Settings.Filter;
		Result.Insert("Conflicts", FilterSettingByObjectsVersions(Filter));
		
		// 
		Filter = RejectedDueToDate.SettingsComposer.Settings.Filter;
		Result.Insert("RejectedDueToDate", FilterSettingByObjectsVersions(Filter, True));
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function DynamicListFilterItem(Val DynamicList, Val Id)
	Return DynamicList.SettingsComposer.Settings.Filter.GetObjectByID(Id);
EndFunction

&AtServer
Procedure UpdateFiltersAndIgnored()
	
	UpdateFilterByPeriod(False);
	UpdateFilterByNode(False);
	UpdateFilterByReason(False);
	
	ShowIgnoredUnpostedItemsAtServer(False);
	ShowIgnoredBlankItemsAtServer(False);
	ShowIgnoredErrorsAtServer(False);
	
	If VersioningUsed Then
		ShowIgnoredConflictsAtServer(False);
		ShowIgnoredRejectedItemsAtServer(False);
	EndIf;
	
	UpdateAtServer();
	
	If Not Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage Then
		
		For Each Page In Items.DataExchangeResults.ChildItems Do
			
			If StrFind(Page.Title, "(") Then
				Items.DataExchangeResults.CurrentPage = Page;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Unposted documents.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UnpostedDocuments.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UnpostedDocuments.IsSkipped");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject,
		"UnpostedDocuments.DocumentDate",
		Items.UnpostedDocumentsDocumentDate.Name);
	
	// Коллизии.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Conflicts.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConflictsOtherVersionAccepted.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.OtherVersionAccepted");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnacceptedVersion);
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConflictsOtherVersionAccepted.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.OtherVersionNumber");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Deleted';"));
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.BlankAttributes.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("BlankAttributes.IsSkipped");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.XDTOObjectErrors.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("XDTOObjectErrors.IsSkipped");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RejectedDueToDate.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RejectedDueToDateRef.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.NewObject");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Missing';"));
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RejectedDueToDateOtherVersionAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnacceptedVersion);
	
EndProcedure

#EndRegion