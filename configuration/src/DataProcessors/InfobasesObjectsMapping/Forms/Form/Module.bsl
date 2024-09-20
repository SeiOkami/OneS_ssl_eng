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
	
	// Checking whether the form is opened from 1C:Enterprise script.
	If Not Parameters.Property("ExchangeMessageFileName") Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	PerformDataMapping = True;
	ExecuteDataImport      = True;
	
	If Parameters.Property("PerformDataMapping") Then
		PerformDataMapping = Parameters.PerformDataMapping;
	EndIf;
	
	If Parameters.Property("ExecuteDataImport") Then
		ExecuteDataImport = Parameters.ExecuteDataImport;
	EndIf;
	
	// Initializing the data processor with the passed parameters.
	FillPropertyValues(Object, Parameters);
	
	// Calling a constructor of the current data processor instance.
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.Designer();
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// Removing possible search fields and attributes with strings of unlimited length from the list.
	MetadataObjectType = Metadata.FindByType(Type(Object.DestinationTypeString));
	
	If MetadataObjectType <> Undefined Then
		
		RowIndex = Object.TableFieldsList.Count() - 1;
		
		While RowIndex >= 0 Do
			
			Item = Object.TableFieldsList[RowIndex];
			RowIndex = RowIndex - 1;
			MetadataObjectAttribute1 = MetadataObjectType.Attributes.Find(Item.Value);
			
			If MetadataObjectAttribute1 <> Undefined
				And MetadataObjectAttribute1.Type = New TypeDescription("String",, New StringQualifiers(0)) Then
				Object.TableFieldsList.Delete(Item);
				Continue;
			EndIf;
			
		EndDo;
	EndIf;
	
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
	
	MappingStatusFilterOptions = New Structure;
	
	// Populate filter list.
	ChoiceList = Items.FilterByMappingStatus.ChoiceList;
	
	NewListItem = ChoiceList.Add("AllObjects", NStr("en = 'All data';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, New FixedStructure);
	
	NewListItem = ChoiceList.Add("UnapprovedMappedObjects", NStr("en = 'Changes';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, 
						New FixedStructure("MappingStatus",  3));
	
	NewListItem = ChoiceList.Add("MappedObjects", NStr("en = 'Mapped data';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, 
						New FixedStructure("MappingStatusAdditional", 0));
	
	NewListItem = ChoiceList.Add("UnmappedObjects", NStr("en = 'Unmapped data';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, 
						New FixedStructure("MappingStatusAdditional", 1));
	
	NewListItem = ChoiceList.Add("UnmappedDestinationObjects", NStr("en = 'Unmapped data (this infobase)';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, 
						New FixedStructure("MappingStatus",  1));
	
	NewListItem = ChoiceList.Add("UnmappedSourceObjects", NStr("en = 'Unmapped data in the peer infobase';"));
	MappingStatusFilterOptions.Insert(NewListItem.Value, 
						New FixedStructure("MappingStatus", -1));
	
	// Default values.
	FilterByMappingStatus = "UnmappedObjects";
		
	// Set the form title.
	Synonym = Undefined;
	Parameters.Property("Synonym", Synonym);
	If IsBlankString(Synonym) Then
		DataPresentation = String(Metadata.FindByType(Type(Object.DestinationTypeString)));
	Else
		DataPresentation = Synonym;
	EndIf;
	Title = NStr("en = 'Data mapping ""[DataPresentation]""';");
	Title = StrReplace(Title, "[DataPresentation]", DataPresentation);
	
	// 
	Items.LinksGroup.Visible                                    = PerformDataMapping;
	Items.RunAutoMapping.Visible           = PerformDataMapping;
	Items.MappingDigestInfo.Visible               = PerformDataMapping;
	Items.MappingTableContextMenuLinksGroup.Visible = PerformDataMapping;
	
	Items.RunDataImport.Visible = ExecuteDataImport;
	
	CurrentApplicationDescription = DataExchangeCached.ThisNodeDescription(Object.InfobaseNode);
	CurrentApplicationDescription = ?(IsBlankString(CurrentApplicationDescription), NStr("en = 'This application';"), CurrentApplicationDescription);
	
	SecondApplicationDescription = String(Object.InfobaseNode);
	SecondApplicationDescription = ?(IsBlankString(SecondApplicationDescription), NStr("en = 'Other application';"), SecondApplicationDescription);
	
	Items.CurrentApplicationData.Title = CurrentApplicationDescription;
	Items.SecondApplicationData.Title = SecondApplicationDescription;
	
	Items.Explanation.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'To map %1 data
		|to%2 data, click ""Map automatically"".
		|Then you can map the remaining data manually.';"),
		CurrentApplicationDescription, SecondApplicationDescription);
	
	ObjectMappingScenario();
	
	ApplyUnapprovedRecordsTable = False;
	ApplyAutomaticMappingResult = False;
	AutoMappedObjectsTableAddress = "";
	WriteAndClose = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ShowWarningOnFormClose = True;
	
	// Setting a flag that shows whether the form has been modified.
	AttachIdleHandler("SetFormModified", 2);
	
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	If Object.UnapprovedMappingTable.Count() = 0 Then
		// 
		Return;
	EndIf;
	
	If ShowWarningOnFormClose = True Then
		Notification = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		
		CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
		
		Return;
	EndIf;
	
	If Exit Then
		Return;
	EndIf;
		
	BeforeCloseContinuation();
	
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(Val QuestionResult = Undefined, Val AdditionalParameters = Undefined) Export
	// 
	// 
	WriteAndClose(Undefined);
EndProcedure

&AtClient
Procedure BeforeCloseContinuation()
	WriteAndClose = True;
	ShowWarningOnFormClose = True;
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("UniqueKey",       Parameters.Key);
	NotificationParameters.Insert("DataImportedSuccessfully", Object.DataImportedSuccessfully);
	
	Notify("ObjectMappingFormClosing", NotificationParameters);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.AutomaticMappingSetting") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		// Performing automatic object mapping.
		FormParameters = New Structure;
		FormParameters.Insert("DestinationTableName",                         Object.DestinationTableName);
		FormParameters.Insert("ExchangeMessageFileName",                     Object.ExchangeMessageFileName);
		FormParameters.Insert("SourceTableObjectTypeName",              Object.SourceTableObjectTypeName);
		FormParameters.Insert("SourceTypeString",                         Object.SourceTypeString);
		FormParameters.Insert("DestinationTypeString",                         Object.DestinationTypeString);
		FormParameters.Insert("DestinationTableFields",                        Object.DestinationTableFields);
		FormParameters.Insert("DestinationTableSearchFields",                  Object.DestinationTableSearchFields);
		FormParameters.Insert("InfobaseNode",                      Object.InfobaseNode);
		FormParameters.Insert("TableFieldsList",                          Object.TableFieldsList.Copy());
		FormParameters.Insert("UsedFieldsList",                     Object.UsedFieldsList.Copy());
		FormParameters.Insert("MappingFieldsList",                    ValueSelected.Copy());
		FormParameters.Insert("MaxUserFields", MaxUserFields());
		FormParameters.Insert("Title",                                   Title);
		
		FormParameters.Insert("UnapprovedMappingTableTempStorageAddress", PutUnapprovedMappingTableInTempStorage());
		
		// Opening the automatic object mapping form.
		OpenForm("DataProcessor.InfobasesObjectsMapping.Form.AutoMappingResult", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.AutoMappingResult") Then
		
		If TypeOf(ValueSelected) = Type("String")
			And Not IsBlankString(ValueSelected) Then
			
			ApplyAutomaticMappingResult = True;
			AutoMappedObjectsTableAddress = ValueSelected;
			
			UpdateMappingTable();
			
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.TableFieldSetup") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.UsedFieldsList = ValueSelected.Copy();
		SetTableFieldVisible("MappingTable"); // Setting visibility and titles of the mapping table fields.
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.MappingFieldTableSetup") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.TableFieldsList = ValueSelected.Copy();
		
		FillListWithSelectedItems(Object.TableFieldsList, Object.UsedFieldsList);
		
		// Generate sort table.
		FillSortTable(Object.UsedFieldsList);
		
		// Updating the mapping table.
		UpdateMappingTable();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.SortingSetup") Then
		
		If TypeOf(ValueSelected) <> Type("FormDataCollection") Then
			Return;
		EndIf;
		
		Object.SortTable.Clear();
		
		// Filling the form collection with retrieved settings.
		For Each TableRow In ValueSelected Do
			FillPropertyValues(Object.SortTable.Add(), TableRow);
		EndDo;
		
		// Sort mapping table.
		ExecuteTableSorting();
		
		// Updating tabular section filter
		SetTabularSectionFilter();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobasesObjectsMapping.Form.MappingChoiceForm") Then
		
		If ValueSelected = Undefined Then
			Return; // Manual mapping is canceled.
		EndIf;
		
		BeginningRowID = Items.MappingTable.CurrentRow;
		
		// Server call.
		FoundRows = MappingTable.FindRows(New Structure("SerialNumber", ValueSelected));
		If FoundRows.Count() > 0 Then
			EndingRowID = FoundRows[0].GetID();
			// Process retrieved mapping.
			AddUnapprovedMappingAtClient(BeginningRowID, EndingRowID);
		EndIf;
		
		// Switching to the mapping table.
		CurrentItem = Items.MappingTable;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterByMappingStatusOnChange(Item)
	
	SetTabularSectionFilter();
	
EndProcedure

#EndRegion

#Region MappingTableFormTableItemEventHandlers

&AtClient
Procedure MappingTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	SetMappingInteractively();
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MappingTableBeforeRowChange(Item, Cancel)
	Cancel = True;
	SetMappingInteractively();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateMappingTable();
	
EndProcedure

&AtClient
Procedure RunAutoMapping(Command)
	
	Cancel = False;
	
	// Determining the number of user-defined fields to be displayed.
	CheckUserFieldsFilled(Cancel, Object.UsedFieldsList.UnloadValues());
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the mapping field list.
	FormParameters = New Structure;
	FormParameters.Insert("MappingFieldsList", Object.TableFieldsList.Copy());
	
	OpenForm("DataProcessor.InfobasesObjectsMapping.Form.AutomaticMappingSetting", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure RunDataImport(Command)
	NString = NStr("en = 'Do you want to import data into the infobase?';");
	Notification = New NotifyDescription("RunDataImportAfterPromptToConfirmDataImport", ThisObject);
	
	ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ChangeTableFields(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.UsedFieldsList.Copy());
	
	OpenForm("DataProcessor.InfobasesObjectsMapping.Form.TableFieldSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SetupTableFieldsList(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.TableFieldsList.Copy());
	
	OpenForm("DataProcessor.InfobasesObjectsMapping.Form.MappingFieldTableSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure Sort(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("SortTable", Object.SortTable);
	
	OpenForm("DataProcessor.InfobasesObjectsMapping.Form.SortingSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddMapping(Command)
	
	SetMappingInteractively();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	SelectedRows = Items.MappingTable.SelectedRows;
	
	HasMappingByRef = False;
	For Each RowID In SelectedRows Do
		String = MappingTable.FindByID(RowID);
		If String.MappingByRef Then
			HasMappingByRef = True;
			Break;
		EndIf;
	EndDo;
	
	If HasMappingByRef Then

		QueryText = NStr(
			"en = 'You are trying to clear the mapping of objects mapped by references.
			|You need to set a new mapping for these objects immediately. Otherwise, they will be mapped by references again.
			|
			|Do you want to clear the mapping?';", 
			CommonClient.DefaultLanguageCode());
			
		Title = NStr("en = 'Clear mapping';", CommonClient.DefaultLanguageCode());
		
		Notification = New NotifyDescription("CancelMappingCompletion", ThisObject);
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo,,, Title); 
		
	Else
	
		UndoMappingAtServer();
	
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelMappingCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		UndoMappingAtServer()
	EndIf;

EndProcedure

&AtClient
Procedure UndoMappingAtServer()

	SelectedRows = Items.MappingTable.SelectedRows;
	
	CancelMappingAtServer(SelectedRows);
	
	// 
	SetTabularSectionFilter();
	
EndProcedure



&AtClient
Procedure WriteRefresh(Command)
	
	ApplyUnapprovedRecordsTable = True;
	
	UpdateMappingTable();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	ApplyUnapprovedRecordsTable = True;
	WriteAndClose = True;
	
	UpdateMappingTable();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

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
	
		// Navigation event handlers.
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() = 0 Then
			Return;
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
	IsLongOperation = False,
	TimeConsumingOperationHandlerName = "")
	
	NewRow = NavigationTable.Add();
	NewRow.NavigationNumber          = NavigationNumber;
	NewRow.MainPageName              = MainPageName;
	NewRow.OnOpenHandlerName        = OnOpenHandlerName;
	NewRow.TimeConsumingOperation               = IsLongOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableDestinationField1.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MappingTable.MappingStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = -1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'No mapping. The object will be copied';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableSourceField1.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MappingTable.MappingStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'No mapping';"));

	//
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTablePictureMappingByRef.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MappingTable.MappingByRef");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Show", False);

EndProcedure

&AtClient
Procedure RunDataImportAfterPromptToConfirmDataImport(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Object.DataImportedSuccessfully Then
		NString = NStr("en = 'Data is already received. Do you want to receive data again?';");
		Notification = New NotifyDescription("RunDataImportAfterPromptToReimportData", ThisObject);
		
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	ExecuteDataImportAfterConfirmGettingData();
EndProcedure

&AtClient
Procedure RunDataImportAfterPromptToReimportData(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteDataImportAfterConfirmGettingData();
EndProcedure

&AtClient
Procedure ExecuteDataImportAfterConfirmGettingData()
	
	// Importing data on the server.
	Cancel = False;
	ExecuteDataImportAtServer(Cancel);
	
	If Cancel Then
		NString = NStr("en = 'Errors occurred while receiving data.
		                     |Do you want to view the event log?';");
		
		Notification = New NotifyDescription("RunDataImportAfterPromptToOpenEventLog", ThisObject);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		
		Return;
	EndIf;
	
	// Updating mapping table data.
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure RunDataImportAfterPromptToOpenEventLog(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeNavigationNumber(-1);
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer(SelectedRows)
	
	For Each RowID In SelectedRows Do
		
		CurrentData = MappingTable.FindByID(RowID);
		
		If CurrentData.MappingStatus = 0 Then // 
			
			CancelDataMapping(CurrentData, False);
			
		ElsIf CurrentData.MappingStatus = 3 Then // 
			
			CancelDataMapping(CurrentData, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CancelDataMapping(CurrentData, IsUnapprovedMapping)
	
	Filter = New Structure;
	Filter.Insert("SourceUUID", CurrentData.DestinationUUID);
	Filter.Insert("DestinationUUID", CurrentData.SourceUUID);
	Filter.Insert("SourceType",                     CurrentData.DestinationType);
	Filter.Insert("DestinationType",                     CurrentData.SourceType);
	
	If IsUnapprovedMapping Then
		For Each FoundString In Object.UnapprovedMappingTable.FindRows(Filter) Do
			// 
			Object.UnapprovedMappingTable.Delete(FoundString);
		EndDo;
		
	Else
		CancelApprovedMappingAtServer(Filter);
		
	EndIf;
	
	// Adding new source and destination rows to the mapping table.
	NewSourceRow = MappingTable.Add();
	NewDestinationRow = MappingTable.Add();
	
	FillPropertyValues(NewSourceRow, CurrentData, "SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, SourceUUID, SourceType, SourcePictureIndex");
	FillPropertyValues(NewDestinationRow, CurrentData, "DestinationField1, DestinationField2, DestinationField3, DestinationField4, DestinationField5, DestinationUUID, DestinationType, DestinationPictureIndex");
	
	// 
	NewSourceRow.SortField1 = CurrentData.SourceField1;
	NewSourceRow.SortField2 = CurrentData.SourceField2;
	NewSourceRow.SortField3 = CurrentData.SourceField3;
	NewSourceRow.SortField4 = CurrentData.SourceField4;
	NewSourceRow.SortField5 = CurrentData.SourceField5;
	NewSourceRow.PictureIndex  = CurrentData.SourcePictureIndex;
	
	// 
	NewDestinationRow.SortField1 = CurrentData.DestinationField1;
	NewDestinationRow.SortField2 = CurrentData.DestinationField2;
	NewDestinationRow.SortField3 = CurrentData.DestinationField3;
	NewDestinationRow.SortField4 = CurrentData.DestinationField4;
	NewDestinationRow.SortField5 = CurrentData.DestinationField5;
	NewDestinationRow.PictureIndex  = CurrentData.DestinationPictureIndex;
	
	NewSourceRow.MappingStatus = -1;
	NewSourceRow.MappingStatusAdditional = 1; // 
	
	NewDestinationRow.MappingStatus = 1;
	NewDestinationRow.MappingStatusAdditional = 1; // 
	
	// 
	MappingTable.Delete(CurrentData);
	
	// 
	NewSourceRow.SerialNumber = NextNumberByMappingOrder();
	NewDestinationRow.SerialNumber = NextNumberByMappingOrder();
	
	NewSourceRow.MappingByRef = False;
	NewDestinationRow.MappingByRef = False;
	
EndProcedure

&AtServer
Procedure CancelApprovedMappingAtServer(Filter)
	
	If DataExchangeServer.IsXDTOExchangePlan(Object.InfobaseNode) Then
		FilterPublicIDs = New Structure("InfobaseNode, Id, Ref",
			Object.InfobaseNode,
			Filter.DestinationUUID,
			Filter.SourceUUID);
		InformationRegisters.SynchronizedObjectPublicIDs.DeleteRecord(FilterPublicIDs);
	Else
		Filter.Insert("InfobaseNode", Object.InfobaseNode);
	
		InformationRegisters.InfobaseObjectsMaps.DeleteRecord(Filter);
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// 
	DataProcessorObject.ApplyUnapprovedRecordsTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	TablesToImport = New Array;
	
	DataTableKey = DataExchangeServer.DataTableKey(Object.SourceTypeString, Object.DestinationTypeString, Object.IsObjectDeletion);
	
	TablesToImport.Add(DataTableKey);
	
	// 
	DataProcessorObject.ExecuteDataImportForInfobase(Cancel, TablesToImport);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectsCount, Object.DataImportedSuccessfully);
	
EndProcedure

&AtServer
Function PutUnapprovedMappingTableInTempStorage()
	
	Return PutToTempStorage(Object.UnapprovedMappingTable.Unload(), UUID);
	
EndFunction

&AtServer
Function GetMappingChoiceTableTempStorageAddress(FilterParameters)
	
	Columns = "SerialNumber, SortField1, SortField2, SortField3, SortField4, SortField5, PictureIndex";
	
	Return PutToTempStorage(MappingTable.Unload(FilterParameters, Columns));
	
EndFunction

&AtClient
Procedure SetFormModified()
	
	Modified = (Object.UnapprovedMappingTable.Count() > 0);
	
EndProcedure

&AtClient
Procedure UpdateMappingTable()
	
	Items.TableButtons.Enabled = False;
	Items.TableHeaderGroup.Enabled = False;
	
	NavigationNumber = 0;
	
	// Selecting the second wizard step.
	SetNavigationNumber(2);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure FillSortTable(SourceValueList)
	
	Object.SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = Object.SortTable.Add();
		
		TableRow.FieldName               = Item.Value;
		TableRow.Use         = IsFirstField; // 
		TableRow.SortDirection = True; // 
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillListWithSelectedItems(SourceList, DestinationList)
	
	DestinationList.Clear();
	
	For Each Item In SourceList Do
		
		If Item.Check Then
			
			DestinationList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetTabularSectionFilter()
	
	Items.MappingTable.RowFilter = MappingStatusFilterOptions[FilterByMappingStatus];
	
EndProcedure

&AtClient
Procedure CheckUserFieldsFilled(Cancel, UserFields)
	
	If UserFields.Count() = 0 Then
		
		// One or more fields must be specified.
		NString = NStr("en = 'Specify at least one field to display';");
		
		CommonClient.MessageToUser(NString,,"Object.TableFieldsList",, Cancel);
		
	ElsIf UserFields.Count() > MaxUserFields() Then
		
		// The value must not exceed the specified number.
		MessageString = NStr("en = 'Reduce the number of fields. You can select no more than %1 fields.';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(MaxUserFields()));
		
		CommonClient.MessageToUser(MessageString,,"Object.TableFieldsList",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetTableFieldVisible(FormTableName)
	
	SourceFieldName2 = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	DestinationFieldName1 = StrReplace("#FormTableName#DestinationFieldNN","#FormTableName#", FormTableName);
	
	// Making all mapping table fields invisible.
	For FieldNumber = 1 To MaxUserFields() Do
		
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

&AtClient
Procedure SetMappingInteractively()
	CurrentData = Items.MappingTable.CurrentData;
	
	If CurrentData=Undefined Then
		Return;
	EndIf;
	
	// 
	// 
	If Not (CurrentData.MappingStatus=-1 Or CurrentData.MappingStatus=+1) Then
		
		ShowMessageBox(, NStr("en = 'Objects are already mapped.';"), 2);
		
		// Switching to the mapping table.
		CurrentItem = Items.MappingTable;
		Return;
	EndIf;
	
	CannotCreateMappingFast = False;
	
	SelectedRows = Items.MappingTable.SelectedRows;
	If SelectedRows.Count()<>2 Then
		CannotCreateMappingFast = True;
		
	Else
		Id1 = SelectedRows[0];
		Id2 = SelectedRows[1];
		
		String1 = MappingTable.FindByID(Id1);
		String2 = MappingTable.FindByID(Id2);
		
		If Not (( String1.MappingStatus = -1 // 
				And String2.MappingStatus = +1 ) // 
			Or ( String1.MappingStatus = +1 // 
				And String2.MappingStatus = -1 )) Then // 
			CannotCreateMappingFast = True;
		EndIf;
	EndIf;
	
	If CannotCreateMappingFast Then
		// Set the mapping in a regular way.
		FilterParameters = New Structure("MappingStatus", ?(CurrentData.MappingStatus = -1, 1, -1));
		FilterParameters.Insert("PictureIndex", CurrentData.PictureIndex);
		
		FormParameters = New Structure;
		FormParameters.Insert("TempStorageAddress",   GetMappingChoiceTableTempStorageAddress(FilterParameters));
		FormParameters.Insert("StartRowSerialNumber", CurrentData.SerialNumber);
		FormParameters.Insert("UsedFieldsList",    Object.UsedFieldsList.Copy());
		FormParameters.Insert("MaxUserFields", MaxUserFields());
		FormParameters.Insert("ObjectToMap", GetObjectToMap(CurrentData));
		FormParameters.Insert("Application1", ?(CurrentData.MappingStatus = -1, SecondApplicationDescription, CurrentApplicationDescription));
		FormParameters.Insert("Application2", ?(CurrentData.MappingStatus = -1, CurrentApplicationDescription, SecondApplicationDescription));
		
		OpenForm("DataProcessor.InfobasesObjectsMapping.Form.MappingChoiceForm", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
		Return;
	EndIf;
	
	// Prompt for a quick mapping.
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,     NStr("en = 'Apply';"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
	
	Notification = New NotifyDescription("SetMappingInteractivelyCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Id1", Id1);
	Notification.AdditionalParameters.Insert("Id2", Id2);
	
	QueryText = NStr("en = 'Do you want to map the selected objects?';");
	ShowQueryBox(Notification, QueryText, Buttons,, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure SetMappingInteractivelyCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AddUnapprovedMappingAtClient(AdditionalParameters.Id1, AdditionalParameters.Id2);
	CurrentItem = Items.MappingTable;
EndProcedure

&AtClient
Function GetObjectToMap(Data)
	
	Result = New Array;
	
	FieldNamePattern = ?(Data.MappingStatus = -1, "SourceFieldNN", "DestinationFieldNN");
	
	For FieldNumber = 1 To MaxUserFields() Do
		
		Field = StrReplace(FieldNamePattern, "NN", String(FieldNumber));
		
		If Items["MappingTable" + Field].Visible
			And ValueIsFilled(Data[Field]) Then
			
			Result.Add(Data[Field]);
			
		EndIf;
		
	EndDo;
	
	If Result.Count() = 0 Then
		
		Result.Add(NStr("en = '<not specified>';"));
		
	EndIf;
	
	Return StrConcat(Result, ", ");
EndFunction

&AtClient
Procedure AddUnapprovedMappingAtClient(Val BeginningRowID, Val EndingRowID)
	
	// 
	// 
	// 
	// 
	
	BeginningRow    = MappingTable.FindByID(BeginningRowID);
	EndingRow = MappingTable.FindByID(EndingRowID);
	
	If BeginningRow = Undefined Or EndingRow = Undefined Then
		Return;
	EndIf;
	
	If BeginningRow.MappingStatus=-1 And EndingRow.MappingStatus=+1 Then
		SourceRow1 = BeginningRow;
		DestinationRow1 = EndingRow;
	ElsIf BeginningRow.MappingStatus=+1 And EndingRow.MappingStatus=-1 Then
		SourceRow1 = EndingRow;
		DestinationRow1 = BeginningRow;
	Else
		Return;
	EndIf;
	
	// Adding a row to the unapproved mapping table.
	NewRow = Object.UnapprovedMappingTable.Add();
	
	NewRow.SourceUUID = DestinationRow1.DestinationUUID;
	NewRow.SourceType                     = DestinationRow1.DestinationType;
	NewRow.DestinationUUID = SourceRow1.SourceUUID;
	NewRow.DestinationType                     = SourceRow1.SourceType;
	
	// Adding a row to the mapping table as an unapproved one.
	NewRowUnapproved = MappingTable.Add();
	
	// Taking sorting fields from the destination row.
	FillPropertyValues(NewRowUnapproved, SourceRow1, "SourcePictureIndex, SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, SourceUUID, SourceType");
	FillPropertyValues(NewRowUnapproved, DestinationRow1, "DestinationPictureIndex, DestinationField1, DestinationField2, DestinationField3, DestinationField4, DestinationField5, DestinationUUID, DestinationType, SortField1, SortField2, SortField3, SortField4, SortField5, PictureIndex");
	
	NewRowUnapproved.MappingStatus               = 3; // 
	NewRowUnapproved.MappingStatusAdditional = 0;
	
	// 
	MappingTable.Delete(BeginningRow);
	MappingTable.Delete(EndingRow);
	
	// 
	NewRowUnapproved.SerialNumber = NextNumberByMappingOrder();
	
	NewRowUnapproved.MappingByRef = AreObjectsMappedByRef(NewRowUnapproved);
	
	// Setting the filter and updating data in the mapping table.
	SetTabularSectionFilter();
EndProcedure

&AtServer
Function NextNumberByMappingOrder()
	Result = 0;
	
	For Each String In MappingTable Do
		Result = Max(Result, String.SerialNumber);
	EndDo;
	
	Return Result + 1;
EndFunction

&AtClient
Procedure ExecuteTableSorting()
	
	SortFields = GetSortingFields();
	If Not IsBlankString(SortFields) Then
		MappingTable.Sort(SortFields);
	EndIf;
	
EndProcedure

&AtClient
Function GetSortingFields()
	
	// Function return value.
	SortFields = "";
	
	FieldPattern = "SortFieldNN #SortDirection"; // 
	
	For Each TableRow In Object.SortTable Do
		
		If TableRow.Use Then
			
			Separator = ?(IsBlankString(SortFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ListItem = Object.UsedFieldsList.FindByValue(TableRow.FieldName);
			
			FieldIndex = Object.UsedFieldsList.IndexOf(ListItem) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortDirection", SortDirectionStr);
			
			SortFields = SortFields + Separator + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortFields;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Properties

&AtClient
Function MaxUserFields()
	
	Return DataExchangeClient.MaxObjectsMappingFieldsCount();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

// Page 1: Object mapping error.
//
&AtClient
Function Attachable_ObjectMappingErrorOnOpen(Cancel, SkipPage, IsMoveNext)
	
	ApplyUnapprovedRecordsTable = False;
	ApplyAutomaticMappingResult = False;
	AutoMappedObjectsTableAddress = "";
	WriteAndClose = False;
	
	Items.TableButtons.Enabled = True;
	Items.TableHeaderGroup.Enabled = True;
	
	Return Undefined;
	
EndFunction

// Page 2 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWaitingTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	// Determining the number of user-defined fields to be displayed.
	CheckUserFieldsFilled(Cancel, Object.UsedFieldsList.UnloadValues());
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
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
		RecordError(NStr("en = 'Background job is canceled by administrator.';"));
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
	
	If WriteAndClose Then
		GoToNext = False;
		Close();
		Return Undefined;
	EndIf;
	
	If TimeConsumingOperationCompleted Then
		ExecuteObjectMappingCompletion(Cancel);
	EndIf;
	
	Items.TableButtons.Enabled          = True;
	Items.TableHeaderGroup.Enabled = True;
	
	// Setting filter in the mapping tabular section.
	SetTabularSectionFilter();
	
	// Setting mapping table field headers and visibility.
	SetTableFieldVisible("MappingTable");
	
	Return Undefined;

EndFunction

// Page 2 Object mapping in background job.
//
&AtServer
Function BackgroundJobStartAtServer(Cancel)
	
	FormAttributes = New Structure;
	FormAttributes.Insert("ApplyOnlyUnapprovedRecordsTable",    WriteAndClose);
	FormAttributes.Insert("ApplyUnapprovedRecordsTable",          ApplyUnapprovedRecordsTable);
	FormAttributes.Insert("ApplyAutomaticMappingResult", ApplyAutomaticMappingResult);
	
	JobParameters = New Structure;
	JobParameters.Insert("ObjectContext", DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
	JobParameters.Insert("FormAttributes",  FormAttributes);
	
	If ApplyAutomaticMappingResult Then
		JobParameters.Insert("AutomaticallyMappedObjectsTable", GetFromTempStorage(AutoMappedObjectsTableAddress));
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Object mapping';");
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.InfobasesObjectsMapping.MapObjects",
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
		AfterObjectMapping();
	Except
		Cancel = True;
		RecordError(ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

&AtServer
Procedure AfterObjectMapping()
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	MappingResult = GetFromTempStorage(TempStorageAddress);
	
	// {Mapping digest}
	ObjectCountInSource       = MappingResult.ObjectCountInSource;
	ObjectCountInDestination       = MappingResult.ObjectCountInDestination;
	MappedObjectCount   = MappingResult.MappedObjectCount;
	UnmappedObjectsCount = MappingResult.UnmappedObjectsCount;
	MappedObjectPercentage       = MappingResult.MappedObjectPercentage;
	PictureIndex                     = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectsCount, Object.DataImportedSuccessfully);
	
	MappingTable.Load(MappingResult.MappingTable);
	
	For Each String In MappingTable Do
		String.MappingByRef = AreObjectsMappedByRef(String);
	EndDo;
	
	DataProcessorObject = DataProcessors.InfobasesObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(MappingResult.ObjectContext, DataProcessorObject);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	If ApplyUnapprovedRecordsTable Then
		Modified = False;
	EndIf;
	
	ApplyUnapprovedRecordsTable           = False;
	ApplyAutomaticMappingResult  = False;
	AutoMappedObjectsTableAddress = "";
	
EndProcedure

&AtServer
Procedure RecordError(DetailErrorDescription)
	
	WriteLogEvent(
		NStr("en = 'Object mapping wizard.Data analysis';", Common.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		, DetailErrorDescription);
	
EndProcedure

&AtClientAtServerNoContext
Function AreObjectsMappedByRef(String)
	
	Return ValueIsFilled(String.DestinationUUID)
		And String(String.DestinationUUID.UUID()) = String.SourceUUID;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure ObjectMappingScenario()
	
	NavigationTable.Clear();
	NavigationTableNewRow(1, "ObjectMappingError", "Attachable_ObjectMappingErrorOnOpen");
	
	// Waiting for object mapping.
	NavigationTableNewRow(2, "ObjectMappingWait",, True, "Attachable_ObjectMappingWaitingTimeConsumingOperationProcessing");
	NavigationTableNewRow(3, "ObjectMappingWait",, True, "Attachable_ObjectMappingWaitingTimeConsumingOperationCompletionTimeConsumingOperationProcessing");
	
	// Operations with object mapping table.
	NavigationTableNewRow(4, "ObjectsMapping");
	
EndProcedure

#EndRegion
