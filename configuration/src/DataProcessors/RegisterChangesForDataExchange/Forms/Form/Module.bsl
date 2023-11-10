///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
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
//                                                
//                                                
// 
//                                                
//                                                
//

#Region Variables

&AtClient
Var MetadataCurrentRow;

#EndRegion

#Region Public

#Region ForCallsFromOtherSubsystems

// 

// 

// Command export handler for the additional reports and data processors subsystem.
//
// Parameters:
//     CommandID - String - command ID to execute.
//     RelatedObjects    - Array of AnyRef - references to process. This parameter is not used in the current procedure,
//                            expected that a similar parameter is passed and processed during the from creation.
//     CreatedObjects     - Array of AnyRef - a return value, an array of references to created objects. 
//                            This parameter is not used in the current data processor.
//
&AtClient
Procedure ExecuteCommand(CommandID, RelatedObjects, CreatedObjects) Export
	
	If CommandID = "OpenRegistrationEditingForm" Then
		
		If RegistrationObjectParameter <> Undefined Then
			// Using parameters that are set in the OnCreateAtServer procedure.
			
			RegistrationFormParameters = New Structure;
			RegistrationFormParameters.Insert("RegistrationObject",  RegistrationObjectParameter);
			RegistrationFormParameters.Insert("RegistrationTable", RegistrationTableParameter);

			OpenForm(ThisFormName + "Form.ObjectRegistrationNodes", RegistrationFormParameters);
		EndIf;
		
	EndIf;
	
EndProcedure
// ACC:78-on

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	CheckPlatformVersionAndCompatibilityMode();
	
	RegistrationTableParameter = Undefined;
	RegistrationObjectParameter  = Undefined;
	
	OpenWithNodeParameter = False;
	CurrentObject = ThisObject();
	ThisFormName = GetFormName();
	// Analyze form parameters and setting options.
	If Parameters.AdditionalDataProcessorRef = Undefined Then
		// Starting the data processor in standalone mode, with the ExchangeNodeRef parameter specified.
		ExchangeNodeReference = Parameters.ExchangeNode;
		Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
		OpenWithNodeParameter = True;
		
	Else
		// This data processor is called from the additional reports and data processors subsystem.
		If TypeOf(Parameters.RelatedObjects) = Type("Array") And Parameters.RelatedObjects.Count() > 0 Then
			
			// The form is opened with the specified object.
			RelatedObject = Parameters.RelatedObjects[0];
			Type = TypeOf(RelatedObject);
			
			If ExchangePlans.AllRefsType().ContainsType(Type) Then
				ExchangeNodeReference = RelatedObject;
				OpenWithNodeParameter = True;
			Else
				// Filling internal attributes.
				LongDesc = CurrentObject.MetadataCharacteristics(RelatedObject.Metadata());
				If LongDesc.IsReference Then
					RegistrationObjectParameter = RelatedObject;
					
				ElsIf LongDesc.IsRecordsSet Then
					// Structure and table name
					RegistrationTableParameter = LongDesc.TableName;
					RegistrationObjectParameter  = New Structure;
					For Each Dimension In CurrentObject.RecordSetDimensions(RegistrationTableParameter) Do
						CurName = Dimension.Name;
						RegistrationObjectParameter.Insert(CurName, RelatedObject.Filter[CurName].Value);
					EndDo;
					
				EndIf;
			EndIf;
			
		Else
			Raise StrReplace(
				NStr("en = 'Invalid destination object parameters for the ""%1"" command';"),
				"%1", Parameters.CommandID);
		EndIf;
		
	EndIf;
	
	// 
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	CurrentObject.ReadSignsOfBSDSupport();
	ThisObject(CurrentObject);
	
	// Initializing other parameters only if this form will be opened
	If RegistrationObjectParameter <> Undefined Then
		Return;
	EndIf;
	Items.GroupPages.CurrentPage = Items.Main;
	// 
	Parameters.Property("NamesOfMetadataToHide", NamesOfMetadataToHide);
	AddNameOfMetadataToHide();
	
	Items.ObjectsListOptions.CurrentPage = Items.BlankPage;
	Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
	
	ExchangePlanNodeDescription = String(ExchangeNodeReference);
	
	FillAdditionalInformation();
	
	If Not ControlSettings() And OpenWithNodeParameter Then
		
		MessageText = StrReplace(
			NStr("en = 'Cannot change item registration state for node ""%1"".';"),
			"%1", ExchangePlanNodeDescription);
		
		Raise MessageText;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If ForceCloseForm Then
		Return;
	EndIf;
	
	If TimeConsumingOperationStarted Then
		Cancel = True;
		Notification = New NotifyDescription("ConfirmFormClosingCompletion", ThisObject);
		ShowQueryBox(Notification, NStr("en = 'Abort registration?';"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If TimeConsumingOperationStarted Then
		EndExecutingTimeConsumingOperation(IDBackgroundJob);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Not (TypeOf(ChoiceSource) = Type("ClientApplicationForm")
			And ChoiceSource.UniqueKey = QueryResultChoiceFormUniqueKey) Then
		Return;
	EndIf;
	
	// Analyzing selected value, it must be a structure.
	If TypeOf(ValueSelected) <> Type("Structure") 
		Or (Not ValueSelected.Property("ChoiceAction"))
		Or (Not ValueSelected.Property("ChoiceData"))
		Or TypeOf(ValueSelected.ChoiceAction) <> Type("Boolean")
		Or TypeOf(ValueSelected.ChoiceData) <> Type("String") Then
		Error = NStr("en = 'Unexpected query result';");
	Else
		Error = RefControlForQuerySelection(ValueSelected.ChoiceData);
	EndIf;
	
	If Error <> "" Then 
		ShowMessageBox(,Error);
		Return;
	EndIf;
		
	If ValueSelected.ChoiceAction Then
		Text = NStr("en = 'Do you want to register the query result
		                 |at node ""%1""?';"); 
	Else
		Text = NStr("en = 'Do you want to unregister the query result
		                 |at node ""%1""?';");
	EndIf;
	Text = StrReplace(Text, "%1", String(ExchangeNodeReference));
					 
	QuestionTitle = NStr("en = 'Confirm operation';");
	
	Notification = New NotifyDescription("ChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ValueSelected", ValueSelected);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ObjectDataExchangeRegistrationEdit" Then
		FillRegistrationCountInTreeRows();
		UpdatePageContent();

	ElsIf EventName = "ExchangeNodeDataEdit" And ExchangeNodeReference = Parameter Then
		SetMessageNumberTitle();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	// Automatic settings.
	CurrentObject = ThisObject();
	CurrentObject.ShouldSaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If RegistrationObjectParameter <> Undefined Then
		// 
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.ExchangeNode) Then
		ExchangeNodeReference = Parameters.ExchangeNode;
	Else
		ExchangeNodeReference = Settings["ExchangeNodeReference"];
		// If restored exchange node is deleted, clearing the ExchangeNodeRef value.
		If ExchangeNodeReference <> Undefined 
		    And ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeReference))
		    And IsBlankString(ExchangeNodeReference.DataVersion) Then
			ExchangeNodeReference = Undefined;
		EndIf;
	EndIf;
	
	ControlSettings();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
//

&AtClient
Procedure ExchangeNodeRef1StartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CurFormName = ThisFormName + "Form.SelectExchangePlanNode";
	CurParameters = New Structure("MultipleChoice, ChoiceInitialValue", False, ExchangeNodeReference);
	OpenForm(CurFormName, CurParameters, Item);
EndProcedure

&AtClient
Procedure ExchangeNodeRef1ChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ExchangeNodeReference <> ValueSelected Then
		ExchangeNodeReference = ValueSelected;
		AttachIdleHandler("ExchangeNodeChoiceProcessing", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure ExchangeNodeRef1OnChange(Item)
	ExchangeNodeChoiceProcessingServer();
	ExpandMetadataTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ExchangeNodeRef1Clearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FilterByMessageNumberOptionOnChange(Item)
	SetFiltersInDynamicLists();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ObjectsListOptionsOnCurrentPageChange(Item, CurrentPage)
	UpdatePageContent(CurrentPage);
EndProcedure

#EndRegion

#Region MetadataTreeFormTableItemEventHandlers
//

&AtClient
Procedure MetadataTreeTaggingOnChange(Item)
	ChangeMark(Items.MetadataTree.CurrentRow);
EndProcedure

&AtClient
Procedure MetadataTreeOnActivateRow(Item)
	If Items.MetadataTree.CurrentRow <> MetadataCurrentRow Then
		MetadataCurrentRow  = Items.MetadataTree.CurrentRow;
		AttachIdleHandler("SetUpChangeEditing", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region ConstantsListFormTableItemEventHandlers

&AtClient
Procedure ConstantsListOnActivateRow(Item)
	
	CommandAvailability = Items.ConstantsList.SelectedRows.Count() > 0;
	Items.ShowExportResult.Enabled = CommandAvailability;
	
EndProcedure

&AtClient
Procedure ConstantsListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Result = AddRegistrationAtServer(True, ValueSelected);
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
	ReportRegistrationResults(Result);
	
	If TypeOf(ValueSelected) = Type("Array") And ValueSelected.Count() > 0 Then
		Item.CurrentRow = ValueSelected[0];
	Else
		Item.CurrentRow = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion

#Region ReferenceListFormTableItemEventHandlers

&AtClient
Procedure ReferenceListOnActivateRow(Item)
	
	CommandAvailability = Items.ReferenceList.SelectedRows.Count() > 0;
	Items.ShowExportResult.Enabled = CommandAvailability;
	
EndProcedure

&AtClient
Procedure ReferenceListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	CurrentRef = CurrentRefsListData().Ref;
	If Not ValueIsFilled(CurrentRef)
		Or Not ValueIsFilled(ReferencesListTableName) Then
		Return;
	EndIf;
	ParametersStructure = New Structure("Key, ReadOnly", CurrentRef, True);
	If IsFolder(CurrentRef) Then
		OpenForm(ReferencesListTableName + ".FolderForm", ParametersStructure, ThisObject);	
	Else
		OpenForm(ReferencesListTableName + ".ObjectForm", ParametersStructure, ThisObject);
	EndIf;

EndProcedure

&AtServer
Function IsFolder(Ref)
	
	MetadataObject = Ref.GetObject().Metadata();
	
	If (Metadata.Catalogs.Contains(MetadataObject) Or Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject))
		And MetadataObject.Hierarchical 
		And MetadataObject.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
		
		If Metadata.Catalogs.Contains(MetadataObject) Then
			TableName = "Catalog." + MetadataObject.Name;
		Else
			TableName = "ChartOfCharacteristicTypes." + MetadataObject.Name;
		EndIf;
		
	Else
		
		Return False;
		
	EndIf;
	
	QueryText = 
		"SELECT
		|	Table.Ref AS Ref
		|FROM
		|	#Table AS Table
		|WHERE
		|	Table.IsFolder
		|	AND Table.Ref = &Ref";
					
	QueryText1 = StrReplace(QueryText, "#Table", TableName);

	Query = New Query(QueryText1);
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtClient
Procedure ReferenceListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure

#EndRegion

#Region RecordSetsListFormTableItemEventHandlers

&AtClient
Procedure RecordSetsListOnActivateRow(Item)
	
	CommandAvailability = Items.RecordSetsList.SelectedRows.Count() > 0;
	Items.ShowExportResult.Enabled = CommandAvailability;
	
EndProcedure

&AtClient
Procedure RecordSetsListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	WriteParameters = RecordSetKeyStructure(Item.CurrentData);
	If WriteParameters <> Undefined Then
		OpenForm(WriteParameters.FormName, New Structure(WriteParameters.Parameter, WriteParameters.Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetsListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure AddRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeReference) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ConstantsPage Then
		AddConstantRegistrationInList();
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		AddRegistrationInReferenceList();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		AddRegistrationToRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeReference) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ConstantsPage Then
		DeleteConstantRegistrationInList();
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		DeleteRegistrationFromReferenceList();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		DeleteRegistrationInRecordSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeReference) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ReferencesListPage Then
		AddRegistrationInListFilter();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		AddRegistrationToRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeReference) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ReferencesListPage Then
		DeleteRegistrationInListFilter();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		DeleteRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenNodeRegistrationForm(Command)
	
	If SelectExchangeNodeProhibited Then
		Return;
	EndIf;
		
	Data = GetCurrentObjectToEdit();
	If Data <> Undefined Then
		RegistrationTable = ?(TypeOf(Data) = Type("Structure"), RecordSetsListTableName, "");
		OpenForm(ThisFormName + "Form.ObjectRegistrationNodes",
			New Structure("RegistrationObject, RegistrationTable, NotifyAboutChanges", 
				Data, RegistrationTable, True), ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExportResult(Command)
	
	CurrentPage = Items.ObjectsListOptions.CurrentPage;
	Result = New Array;
	
	If CurrentPage = Items.ConstantsPage Then 
		FormItem = Items.ConstantsList;
		For Each String In FormItem.SelectedRows Do
			curData = FormItem.RowData(String);
			Result.Add(New Structure("TypeFlag, Data", 1, curData.MetaFullName));
		EndDo;
		
	ElsIf CurrentPage = Items.RecordSetPage Then
		MeasurementList = RecordSetKeyNameArray(RecordSetsListTableName);
		FormItem = Items.RecordSetsList;
		Prefix = "RecordSetsList";
		For Each Item In FormItem.SelectedRows Do
			curData = New Structure();
			Data = FormItem.RowData(Item);
			For Each Name In MeasurementList Do
				If Data.Property(Prefix + Name) Then 
					curData.Insert(Name, Data[Prefix + Name]);
				EndIf;
			EndDo;
			Result.Add(New Structure("TypeFlag, Data", 2, curData));
		EndDo;
		
	ElsIf CurrentPage = Items.ReferencesListPage Then
		FormItem = Items.ReferenceList;
		For Each Item In FormItem.SelectedRows Do
			curData = FormItem.RowData(Item); // See CurrentRefsListData
			Result.Add(New Structure("TypeFlag, Data", 3, curData.Ref));
		EndDo;
		
	Else
		Return;
		
	EndIf;
	
	If Result.Count() > 0 Then
		Text = SerializationText(Result);
		TextTitle = NStr("en = 'Export result (DIB)';");
		Text.Show(TextTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditMessagesNumbers(Command)
	
	If ValueIsFilled(ExchangeNodeReference) Then
		CurFormName = ThisFormName + "Form.ExchangePlanNodeMessageNumbers";
		CurParameters = New Structure("ExchangeNodeReference", ExchangeNodeReference);
		OpenForm(CurFormName, CurParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddObjectDeletionRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteRegistrationFromReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationPickup(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddRegistrationInReferenceList(True);
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure AddRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		AddRegistrationToRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteRegistrationInRecordSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		DeleteRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAllData(Command)
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure AddQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		ActionWithQueryResult(True);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeReference) Then
		ActionWithQueryResult(False);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

&AtClient
Procedure EditObjectMessageNumber(Command)
	
	If Items.ObjectsListOptions.CurrentPage = Items.ConstantsPage Then
		EditConstantMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.ReferencesListPage Then
		EditRefMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.RecordSetPage Then
		EditMessageNoSetList()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterMOIDAndPredefinedItems(Command)
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	QueryText     = StrReplace( 
		NStr("en = 'Do you want to register items to recover the DIB subnode
		     |at node ""%1""?';"),
		"%1", ExchangeNodeReference);
	
	Notification = New NotifyDescription("RegisterMetadataObjectIDCompletion", ThisObject);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConfirmFormClosingCompletion(QuestionResult, AdditionalParameters) Export
	
	If Not QuestionResult = DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReferenceListMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReferenceList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Pending export';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConstantsListMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ConstantsList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Pending export';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecordSetsListMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSetsList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Pending export';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataTreeChangeCountString.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataTree.ChangeCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Unchanged';"));
	
EndProcedure
//

// Dialog continuation notification handler.
&AtClient 
Procedure RegisterMetadataObjectIDCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(RegisterMOIDAndPredefinedItemsAtServer() );
		
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure ChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return
	EndIf;
	ValueSelected = AdditionalParameters.ValueSelected;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(ValueSelected.ChoiceAction, 
		AdditionalParameters.Property("NoAutoRegistration") And AdditionalParameters.NoAutoRegistration,
		Undefined);
		BackgroundJobParameters.Insert("AddressData2", ValueSelected.ChoiceData);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		ReportRegistrationResults(ChangeQueryResultRegistrationServer(ValueSelected.ChoiceAction, ValueSelected.ChoiceData));
		
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	EndIf;
EndProcedure

&AtClient
Procedure EditConstantMessageNo()
	curData = Items.ConstantsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditConstantMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaFullName", curData.MetaFullName);
	
	MessageNo = curData.MessageNo;
	ToolTip = NStr("en = 'Sent message number';"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure EditConstantMessageNoCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// 
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(MessageNo, AdditionalParameters.MetaFullName));
		
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

// Parameters:
//   Ref - ExchangePlanRef
//
// Returns:
//   Structure - 
//     * Ref - ExchangePlanRef
//
&AtClient
Function AdditionalMessageNumberEditParameters(Ref)
	Return New Structure("Ref", Ref);
EndFunction

&AtClient
Procedure EditRefMessageNo()
	curData = CurrentRefsListData();
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription(
		"EditRefMessageNoCompletion",
		ThisObject,
		AdditionalMessageNumberEditParameters(curData.Ref));
	
	MessageNo = curData.MessageNo;
	ToolTip = NStr("en = 'Sent message number';"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Dialog continuation notification handler.
//
// Parameters:
//   MessageNo - Number
//   AdditionalParameters - See AdditionalMessageNumberEditParameters
//
&AtClient
Procedure EditRefMessageNoCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// 
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(MessageNo, AdditionalParameters.Ref));
		
	Items.ReferenceList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditMessageNoSetList()
	curData = Items.RecordSetsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditMessageNoSetListCompletion", ThisObject, New Structure);
	
	RowData = New Structure;
	KeysNames = RecordSetKeyNameArray(RecordSetsListTableName);
	For Each Name In KeysNames Do
		If curData.Property("RecordSetsList" + Name) Then
			RowData.Insert(Name, curData["RecordSetsList" + Name]);
		EndIf;
	EndDo;
	
	Notification.AdditionalParameters.Insert("RowData", RowData);
	
	MessageNo = curData.MessageNo;
	ToolTip = NStr("en = 'Sent message number';"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure EditMessageNoSetListCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// 
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(
		MessageNo, AdditionalParameters.RowData, RecordSetsListTableName));
	
	Items.RecordSetsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure SetUpChangeEditing()
	
	SetUpChangeEditingServer(MetadataCurrentRow);
	
	CurrentListPage = Items.ObjectsListOptions.CurrentPage;
	If CurrentListPage <> Items.ConstantsPage
		And CurrentListPage <> Items.ReferencesListPage
		And CurrentListPage <> Items.RecordSetPage Then
		
		Items.ShowExportResult.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandMetadataTree()
	For Each String In MetadataTree.GetItems() Do
		Items.MetadataTree.Expand( String.GetID() );
	EndDo;
EndProcedure

&AtServer
Procedure SetMessageNumberTitle()
	
	Text = NStr("en = 'Sent message #%1. Received message #%2';");
	
	Data = ReadMessageNumbers();
	Text = StrReplace(Text, "%1", Format(Data.SentNo, "NFD=0; NZ="));
	Text = StrReplace(Text, "%2", Format(Data.ReceivedNo, "NFD=0; NZ="));
	
	Items.FormEditMessagesNumbers.Title = Text;
EndProcedure	

&AtClient
Procedure ExchangeNodeChoiceProcessing()
	ExchangeNodeChoiceProcessingServer();
EndProcedure

&AtServer
Procedure ExchangeNodeChoiceProcessingServer()
	
	// Modifying node numbers in the FormEditMessageNumbers title.
	SetMessageNumberTitle();
	
	// Refresh metadata tree.
	ReadMetadataTree();
	FillRegistrationCountInTreeRows();
	
	// 
	Items.ObjectsListOptions.CurrentPage = Items.BlankPage;
	
	// Setting visibility for related buttons.
	
	MetaNodeExchangePlan = ExchangeNodeReference.Metadata();
	
	FillAdditionalInformation();
	
	If Object.DIBModeAvailable                             // Current SSL version supports MOID.
		And (ExchangePlans.MasterNode() = Undefined)          // Current infobase is a master node.
		And MetaNodeExchangePlan.DistributedInfoBase Then // Текущий узел - DIB
		Items.FormRegisterMOIDAndPredefinedItems.Visible = True;
	Else
		Items.FormRegisterMOIDAndPredefinedItems.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportRegistrationResults(Results)
	Command = Results.Command;
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			WarningTitle = NStr("en = 'Registered items:';");
			WarningText = NStr("en = '%1 out of %2 items are registered.
			                           |Node: %0';");
		Else
			WarningTitle = NStr("en = 'Unregistered items:';");
			WarningText = NStr("en = '%1 items are unregistered.
			                           |Node: %0';");
		EndIf;
	Else
		WarningTitle = NStr("en = 'Message number changed:';");
		WarningText = NStr("en = 'Message number changed to %3
		                           |for %1 item(s).';");
	EndIf;
	
	WarningText = StrReplace(WarningText, "%0", ExchangeNodeReference);
	WarningText = StrReplace(WarningText, "%1", Format(Results.Success, "NZ=0;"));
	WarningText = StrReplace(WarningText, "%2", Format(Results.Total, "NZ=0;"));
	WarningText = StrReplace(WarningText, "%3", Command);
	
	WarningRequired = Results.Total <> Results.Success;
	If WarningRequired Then
		ShowMessageBox(, WarningText, , WarningTitle);
	Else
		ShowUserNotification(WarningTitle,
			GetURL(ExchangeNodeReference),
			WarningText,
			Items.HiddenPictureInformation32.Picture);
	EndIf;
EndProcedure

&AtServer
Function GetQueryResultChoiceForm()
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	ThisObject(CurrentObject);
	
	Validation = CurrentObject.CheckSettingsCorrectness();
	ThisObject(CurrentObject);
	
	If Validation.QueryExternalDataProcessorAddressSetting <> Undefined Then
		Return Undefined;
		
	ElsIf IsBlankString(CurrentObject.QueryExternalDataProcessorAddressSetting) Then
		Return Undefined;
		
	ElsIf Lower(Right(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		Return Undefined;
		
	Else
		DataProcessor = DataProcessors[CurrentObject.QueryExternalDataProcessorAddressSetting].Create();
		FormIdentifier = ".Form";
		
	EndIf;
	
	Return DataProcessor.Metadata().FullName() + FormIdentifier;
EndFunction

&AtClient
Procedure AddConstantRegistrationInList()
	CurFormName = ThisFormName + "Form.SelectConstant";
	CurParameters = New Structure();
	CurParameters.Insert("ExchangeNode",ExchangeNodeReference);
	CurParameters.Insert("MetadataNamesArray",MetadataNamesStructure.Constants);
	CurParameters.Insert("PresentationsArray",MetadataPresentationsStructure.Constants);
	CurParameters.Insert("AutoRecordsArray",MetadataAutoRecordStructure.Constants);
	OpenForm(CurFormName, CurParameters, Items.ConstantsList);
EndProcedure

&AtClient
Procedure DeleteConstantRegistrationInList()
	
	Item = Items.ConstantsList;
	
	PresentationsList = New Array;
	NamesList          = New Array;
	For Each String In Item.SelectedRows Do
		Data = Item.RowData(String);
		PresentationsList.Add(Data.Description);
		NamesList.Add(Data.MetaFullName);
	EndDo;
	
	Count = NamesList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("en = 'Do you want to unregister ""%2""
		                 |at node ""%1""?';"); 
	Else
		Text = NStr("en = 'Do you want to unregister the constants
		                 |at node ""%1""?';"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeReference);
	Text = StrReplace(Text, "%2", PresentationsList[0]);
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	
	Notification = New NotifyDescription("DeleteConstantRegistrationInListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("NamesList", NamesList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure DeleteConstantRegistrationInListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	ReportRegistrationResults(DeleteRegistrationAtServer(True, AdditionalParameters.NamesList));
		
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationInReferenceList(IsPick = False)
	CurFormName = ReferencesListTableName + ".ChoiceForm";
	CurParameters = New Structure();
	CurParameters.Insert("ChoiceMode", True);
	CurParameters.Insert("MultipleChoice", True);
	CurParameters.Insert("CloseOnChoice", IsPick);
	CurParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);

	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistrationInReferenceList()
	Ref = ObjectRefToDelete();
	DataChoiceProcessing(Items.ReferenceList, Ref);
EndProcedure

&AtServer
Function ObjectRefToDelete(Val Var_UUID = Undefined)
	LongDesc = ThisObject().MetadataCharacteristics(ReferencesListTableName);
	If Var_UUID = Undefined Then
		Return LongDesc.Manager.GetRef();
	EndIf;
	Return LongDesc.Manager.GetRef(Var_UUID);
EndFunction

&AtClient 
Procedure AddRegistrationInListFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		ReferencesListTableName);
	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient 
Procedure DeleteRegistrationInListFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		ReferencesListTableName);
	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient
Procedure DeleteRegistrationFromReferenceList()
	
	Item = Items.ReferenceList;
	
	DeletionList = New Array;
	For Each String In Item.SelectedRows Do
		Data = Item.RowData(String); // See CurrentRefsListData
		DeletionList.Add(Data.Ref);
	EndDo;
	
	Count = DeletionList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("en = 'Do you want to unregister ""%2""
		                 |at node ""%1""?';"); 
	Else
		Text = NStr("en = 'Do you want to unregister the selected items
		                 |at node ""%1""?';"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeReference);
	Text = StrReplace(Text, "%2", DeletionList[0]);
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	
	Notification = New NotifyDescription("DeleteRegistrationFromReferenceListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("DeletionList", DeletionList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure DeleteRegistrationFromReferenceListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(DeleteRegistrationAtServer(True, AdditionalParameters.DeletionList));
		
	Items.ReferenceList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationToRecordSetFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		RecordSetsListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetsList);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSet()
	
	StructureOfData = "";
	KeysNames = RecordSetKeyNameArray(RecordSetsListTableName);
	For Each Name In KeysNames Do
		StructureOfData = StructureOfData +  "," + Name;
	EndDo;
	StructureOfData = Mid(StructureOfData, 2);
	
	Data = New Array;
	Item = Items.RecordSetsList;
	For Each String In Item.SelectedRows Do
		curData = Item.RowData(String);
		RowData = New Structure;
		For Each Name In KeysNames Do
			ColumnName = "RecordSetsList" + Name;
			If curData.Property(ColumnName) Then 
				RowData.Insert(Name, curData[ColumnName]);
			EndIf;
		EndDo;
		Data.Add(RowData);
	EndDo;
	
	If Data.Count() = 0 Then
		Return;
	EndIf;
	
	Case = New Structure();
	Case.Insert("TableName",RecordSetsListTableName);
	Case.Insert("ChoiceData",Data);
	Case.Insert("ChoiceAction",False);
	Case.Insert("FieldsStructure",StructureOfData);
	DataChoiceProcessing(Items.RecordSetsList, Case);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSetFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		RecordSetsListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetsList);
EndProcedure

&AtClient
Procedure AddSelectedObjectRegistration(NoAutoRegistration = True)
	
	Data = GetSelectedMetadataNames(NoAutoRegistration);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		// 
		Data = GetCurrentRowMetadataNames(NoAutoRegistration);
	EndIf;
	
	Text = NStr("en = 'Do you want to register %1 for export to node ""%2""?
	                 |
	                 |This might take a while.';");
					 
	Text = StrReplace(Text, "%1", Data.LongDesc);
	Text = StrReplace(Text, "%2", ExchangeNodeReference);
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	
	Notification = New NotifyDescription("AddSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("NoAutoRegistration", NoAutoRegistration);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure AddSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(True, AdditionalParameters.NoAutoRegistration, 
										AdditionalParameters.MetaNames);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		Result = AddRegistrationAtServer(AdditionalParameters.NoAutoRegistration, 
			AdditionalParameters.MetaNames);
		
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
		ReportRegistrationResults(Result);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteSelectedObjectRegistration(NoAutoRegistration = True)
	
	Data = GetSelectedMetadataNames(NoAutoRegistration);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		Data = GetCurrentRowMetadataNames(NoAutoRegistration);
	EndIf;
	
	Text = NStr("en = 'Do you want to unregister %1 for export to node ""%2""?
	                 |
	                 |This might take a while.';");
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	
	Text = StrReplace(Text, "%1", Data.LongDesc);
	Text = StrReplace(Text, "%2", ExchangeNodeReference);
	
	Notification = New NotifyDescription("DeleteSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("NoAutoRegistration", NoAutoRegistration);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure DeleteSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(False, AdditionalParameters.NoAutoRegistration, 
										AdditionalParameters.MetaNames);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		ReportRegistrationResults(DeleteRegistrationAtServer(AdditionalParameters.NoAutoRegistration, 
				AdditionalParameters.MetaNames));
			
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	EndIf;
EndProcedure

&AtClient
Procedure BackgroundJobStartClient(BackgroundJobParameters)
	TimeConsumingOperationStarted = True;
	TimeConsumingOperationKind = ?(BackgroundJobParameters.Command, True, False);
	AttachIdleHandler("TimeConsumingOperationPage1", 0.1, True);
	Result = BackgroundJobStartAtServer(BackgroundJobParameters);
	If Result = Undefined Then
		TimeConsumingOperationStarted = False;
		WarningText = NStr("en = 'Error starting background job.';");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	CommonModuleTimeConsumingOperationsClient = CommonModuleTimeConsumingOperationsClient();
	If Result.Status = "Running" Then
		IdleParameters = CommonModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		CompletionNotification2 = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		CommonModuleTimeConsumingOperationsClient.WaitCompletion(Result, CompletionNotification2, IdleParameters);
	Else
		BackgroundJobCompleteResult = Result;
		AttachIdleHandler("BackgroundJobExecutionResult", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure TimeConsumingOperationPage1()
	If Not TimeConsumingOperationStarted Then
		Return;
	EndIf;
	If TimeConsumingOperationKind Then
		OperationStatus = NStr("en = 'Registering in progress. Please wait.';");
	Else
		OperationStatus = NStr("en = 'Unregistering in progress. Please wait.';");
	EndIf;
	Items.TimeConsumingOperationStatus.Title = OperationStatus;
	Items.GroupPages.CurrentPage = Items.Waiting;
EndProcedure

&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	
	BackgroundJobCompleteResult = Result;
	BackgroundJobExecutionResult();
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionResult()
	
	BackgroundJobGetResultAtServer();
	TimeConsumingOperationStarted = False;
	
	Items.GroupPages.CurrentPage = Items.Main;
	CurrentItem = Items.MetadataTree;
	
	If ValueIsFilled(ErrorMessage) Then
		Message = New UserMessage;
		Message.Text = ErrorMessage;
		Message.Message();
	EndIf;
	
	If Not BackgroundJobCompleteResult = Undefined Then
		If BackgroundJobCompleteResult.Property("AdditionalResultData")
			And BackgroundJobCompleteResult.AdditionalResultData.Property("Command") Then
			
			ReportRegistrationResults(BackgroundJobCompleteResult.AdditionalResultData);
			FillRegistrationCountInTreeRows();
			UpdatePageContent();
			
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function BackgroundJobStartAtServer(BackgroundJobParameters)
	
	ModuleTimeConsumingOperations = CommonModuleTimeConsumingOperations();
	ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.AdditionalResult = False;
	
	If BackgroundJobParameters.Property("AddressData2") Then
		// Data storage address is passed.
		Result = GetFromTempStorage(BackgroundJobParameters.AddressData2);
		Result= Result[Result.UBound()];
		Data = Result.Unload().UnloadColumn("Ref");
		BackgroundJobParameters.Insert("Data", Data);
	EndIf;
	ProcedureName = FormAttributeToValue("Object").Metadata().FullName() + ".ObjectModule.ChangeRegistration";
	Result = ModuleTimeConsumingOperations.ExecuteInBackground(ProcedureName, BackgroundJobParameters, ExecutionParameters);
	IDBackgroundJob  = Result.JobID;
	BackgroundJobStorageAddress = Result.ResultAddress;
	
	Return Result;
	
EndFunction

&AtServer
Procedure BackgroundJobGetResultAtServer()
	
	If BackgroundJobCompleteResult <> Undefined Then
		BackgroundJobCompleteResult.Insert("AdditionalResultData", New Structure);
		ErrorMessage = "";
		StandardErrorPresentation = NStr("en = 'Error changing registration state. See the Event log for details.';");
		
		If BackgroundJobCompleteResult.Status = "Error" Then
			ErrorMessage = BackgroundJobCompleteResult.DetailErrorDescription;
		Else
			BackgroundExecutionResult = GetFromTempStorage(BackgroundJobStorageAddress);
			
			If BackgroundExecutionResult = Undefined Then
				ErrorMessage = StandardErrorPresentation;
			Else
				BackgroundJobCompleteResult.AdditionalResultData = BackgroundExecutionResult;
				DeleteFromTempStorage(BackgroundJobStorageAddress);
			EndIf;
		EndIf;
	EndIf;
	
	BackgroundJobStorageAddress = Undefined;
	IDBackgroundJob  = Undefined;
	
EndProcedure

&AtServerNoContext
Procedure EndExecutingTimeConsumingOperation(JobID)
	ModuleTimeConsumingOperations = CommonModuleTimeConsumingOperations();
	ModuleTimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

// Returns a reference to the TimeConsumingOperationsClient common module.
//
// Returns:
//  CommonModule - 
//
&AtClient
Function CommonModuleTimeConsumingOperationsClient()
	
	// Don't call CalculateInSafeMode. Calculation takes a string literal instead.
	Module = Eval("TimeConsumingOperationsClient");
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise NStr("en = 'Common module TimeConsumingOperationsClient is not found.';");
	EndIf;
	
	Return Module;
	
EndFunction

// Returns a reference to the TimeConsumingOperations common module.
//
// Returns:
//  CommonModule - 
//
&AtServerNoContext
Function CommonModuleTimeConsumingOperations()

	If Metadata.CommonModules.Find("TimeConsumingOperations") <> Undefined Then
		// Don't call CalculateInSafeMode. Calculation takes a string literal instead.
		Module = Eval("TimeConsumingOperations");
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise NStr("en = 'Common module TimeConsumingOperations is not found.';");
	EndIf;
	
	Return Module;
	
EndFunction

// Returns:
//   Structure - 
//     * Action - Boolean
//     * FormTable - FormTable
//     * Data - Arbitrary
//     * TableName - String
//     * Ref - AnyRef
//
&AtClient
Function AdditionalDataChoiceProcessingParameters()
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Action");
	AdditionalParameters.Insert("FormTable");
	AdditionalParameters.Insert("Data");
	AdditionalParameters.Insert("TableName");
	AdditionalParameters.Insert("Ref");
	
	Return AdditionalParameters;
	
EndFunction

&AtClient
Procedure DataChoiceProcessing(FormTable, ValueSelected)
	
	Ref = Undefined;
	Type    = TypeOf(ValueSelected);
	
	If Type = Type("Structure") Then
		If Not (ValueSelected.Property("TableName")
			And ValueSelected.Property("ChoiceAction")
			And ValueSelected.Property("ChoiceData")) Then
			// 
			Return;
		EndIf;
		TableName = ValueSelected.TableName;
		Action   = ValueSelected.ChoiceAction;
		Data     = ValueSelected.ChoiceData;
	Else
		TableName = Undefined;
		Action = True;
		If Type = Type("Array") Then
			Data = ValueSelected;
		Else		
			Data = New Array;
			Data.Add(ValueSelected);
		EndIf;
		
		If Data.Count() = 1 Then
			Ref = Data[0];
		EndIf;
	EndIf;
	
	If Action Then
		Result = AddRegistrationAtServer(True, Data, TableName);
		
		FormTable.Refresh();
		FillRegistrationCountInTreeRows();
		ReportRegistrationResults(Result);
		
		FormTable.CurrentRow = Ref;
		Return;
	EndIf;
	
	If Ref = Undefined Then
		Text = NStr("en = 'Do you want to unregister the selected items
		                 |at node ""%1""?';"); 
	Else
		Text = NStr("en = 'Do you want to unregister ""%2""
		                 |at node ""%1""?';"); 
	EndIf;
		
	Text = StrReplace(Text, "%1", ExchangeNodeReference);
	Text = StrReplace(Text, "%2", Ref);
	
	QuestionTitle = NStr("en = 'Confirm operation';");
		
	AdditionalParameters = AdditionalDataChoiceProcessingParameters();
	AdditionalParameters.Action     = Action;
	AdditionalParameters.FormTable = FormTable;
	AdditionalParameters.Data       = Data;
	AdditionalParameters.TableName   = TableName;
	AdditionalParameters.Ref       = Ref;
	
	Notification = New NotifyDescription("DataChoiceProcessingCompletion", ThisObject, AdditionalParameters);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
//
// Parameters:
//   QuestionResult -DialogReturnCode
//   AdditionalParameters - See AdditionalDataChoiceProcessingParameters
//
&AtClient
Procedure DataChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(False, True, AdditionalParameters.Data, 
										AdditionalParameters.TableName);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		Result = DeleteRegistrationAtServer(True, AdditionalParameters.Data, AdditionalParameters.TableName);
	
		AdditionalParameters.FormTable.Refresh();
		FillRegistrationCountInTreeRows();
		ReportRegistrationResults(Result);
	EndIf;
	
	AdditionalParameters.FormTable.CurrentRow = AdditionalParameters.Ref;
EndProcedure

&AtServer
Procedure UpdatePageContent(Page = Undefined)
	CurrRow = ?(Page = Undefined, Items.ObjectsListOptions.CurrentPage, Page);
	
	If CurrRow = Items.ReferencesListPage Then
		Items.ReferenceList.Refresh();
		
	ElsIf CurrRow = Items.ConstantsPage Then
		Items.ConstantsList.Refresh();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Items.RecordSetsList.Refresh();
		
	ElsIf CurrRow = Items.BlankPage Then
		String = Items.MetadataTree.CurrentRow;
		If String <> Undefined Then
			Data = MetadataTree.FindByID(String);
			If Data <> Undefined Then
				SetUpEmptyPage(Data.Description, Data.MetaFullName);
			EndIf;
		EndIf;
	EndIf;
EndProcedure	

&AtClient
Function GetCurrentObjectToEdit()
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	
	If CurrRow = Items.ReferencesListPage Then
		Data = CurrentRefsListData();
		If Data <> Undefined Then
			Return Data.Ref; 
		EndIf;
		
	ElsIf CurrRow = Items.ConstantsPage Then
		Data = Items.ConstantsList.CurrentData;
		If Data <> Undefined Then
			Return Data.MetaFullName; 
		EndIf;
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Data = Items.RecordSetsList.CurrentData;
		If Data <> Undefined Then
			Result = New Structure;
			Dimensions = RecordSetKeyNameArray(RecordSetsListTableName);
			For Each Name In Dimensions  Do
				If Data.Property("RecordSetsList" + Name) Then
					Result.Insert(Name, Data["RecordSetsList" + Name]);
				EndIf;
			EndDo;
		EndIf;
		Return Result;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns:
//   FormDataStructure:
//     * Ref - AnyRef
//     * MessageNo - Number
//     * NotExported - Boolean
//
&AtClient
Function CurrentRefsListData()
	
	Return Items.ReferenceList.CurrentData;
	
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = ThisFormName + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure ActionWithQueryResult(ActionCommand)
	
	CurFormName = GetQueryResultChoiceForm();
	If CurFormName <> Undefined Then
		// Open form.
		If ActionCommand Then
			Text = NStr("en = 'Register query results';");
		Else
			Text = NStr("en = 'Unregister query results';");
		EndIf;
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Title", Text);
		ParametersStructure.Insert("ChoiceAction", ActionCommand);
		ParametersStructure.Insert("ChoiceMode", True);
		ParametersStructure.Insert("CloseOnChoice", False);
		
		If Not ValueIsFilled(QueryResultChoiceFormUniqueKey) Then
			QueryResultChoiceFormUniqueKey = New UUID;
		EndIf;
		
		OpenForm(CurFormName, ParametersStructure, ThisObject, QueryResultChoiceFormUniqueKey);
		Return;
	EndIf;
	
	// Не настроено или что-
	Text = NStr("en = 'Query data processor not specified.
	                        |Do you want to specify it now?';");
	
	QuestionTitle = NStr("en = 'Settings';");

	Notification = New NotifyDescription("ActionWithQueryResultCompletion", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure ActionWithQueryResultCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OpenDataProcessorSettingsForm();
EndProcedure

&AtServer
Function ProcessQuotationMarksInRow(String)
	Return StrReplace(String, """", """""");
EndFunction

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction

&AtServer
Procedure ChangeMark(String)
	DataElement = MetadataTree.FindByID(String);
	ThisObject().ChangeMark(DataElement);
EndProcedure

&AtServer
Procedure ReadMetadataTree()
	Data = ThisObject().GenerateMetadataStructure(ExchangeNodeReference);
	
	// Deleting rows that cannot be edited.
	MetaTree = Data.Tree;
	For Each ListItem In NamesOfMetadataToHide Do
		DeleteMetadataValueTreeRows(ListItem.Value, MetaTree.Rows);
	EndDo;
	
	ValueToFormAttribute(MetaTree, "MetadataTree");
	MetadataAutoRecordStructure = Data.AutoRecordStructure;
	MetadataPresentationsStructure   = Data.PresentationsStructure;
	MetadataNamesStructure            = Data.NamesStructure;
EndProcedure

&AtServer 
Procedure DeleteMetadataValueTreeRows(Val MetaFullName, TreeRows)
	If IsBlankString(MetaFullName) Then
		Return;
	EndIf;
	
	// In the current set.
	Filter = New Structure("MetaFullName", MetaFullName);
	For Each DeletionRow In TreeRows.FindRows(Filter, False) Do
		TreeRows.Delete(DeletionRow);
		// If there are no subordinate rows left, deleting the parent row.
		If TreeRows.Count() = 0 Then
			ParentString = TreeRows.Parent;
			If ParentString.Parent <> Undefined Then
				ParentString.Parent.Rows.Delete(ParentString);
				// 
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	// Deleting subordinate row recursively.
	For Each TreeRow In TreeRows Do
		DeleteMetadataValueTreeRows(MetaFullName, TreeRow.Rows);
	EndDo;
EndProcedure

&AtServer
Procedure FormatChangeCount(String)
	String.ChangeCountString = Format(String.ChangeCount, "NZ=0;") + " / " + Format(String.NotExportedCount, "NZ=0;");
EndProcedure

&AtServer
Procedure FillRegistrationCountInTreeRows()
	
	Data = ThisObject().GetChangeCount(MetadataNamesStructure, ExchangeNodeReference);
	
	// Insert values to the tree.
	Filter = New Structure("MetaFullName, ExchangeNode", Undefined, ExchangeNodeReference);
	Zeros   = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
	
	For Each Root In MetadataTree.GetItems() Do
		RootSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
		
		For Each Var_Group In Root.GetItems() Do
			GroupSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
			
			NodesList = Var_Group.GetItems();
			If NodesList.Count() = 0 And MetadataNamesStructure.Property(Var_Group.MetaFullName) Then
				// Node collection without nodes, sum manually and take auto record from structure.
				For Each MetaName1 In MetadataNamesStructure[Var_Group.MetaFullName] Do
					Filter.MetaFullName = MetaName1;
					Found4 = Data.FindRows(Filter);
					If Found4.Count() > 0 Then
						String = Found4[0];
						GroupSum.ChangeCount     = GroupSum.ChangeCount     + String.ChangeCount;
						GroupSum.ExportedCount   = GroupSum.ExportedCount   + String.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + String.NotExportedCount;
					EndIf;
				EndDo;
				
			Else
				// Calculating count values for each node
				For Each Node In NodesList Do
					Filter.MetaFullName = Node.MetaFullName;
					Found4 = Data.FindRows(Filter);
					If Found4.Count() > 0 Then
						String = Found4[0];
						FillPropertyValues(Node, String, "ChangeCount, ExportedCount, NotExportedCount");
						GroupSum.ChangeCount     = GroupSum.ChangeCount     + String.ChangeCount;
						GroupSum.ExportedCount   = GroupSum.ExportedCount   + String.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + String.NotExportedCount;
					Else
						FillPropertyValues(Node, Zeros);
					EndIf;
					
					FormatChangeCount(Node);
				EndDo;
				
			EndIf;
			FillPropertyValues(Var_Group, GroupSum);
			
			RootSum.ChangeCount     = RootSum.ChangeCount     + Var_Group.ChangeCount;
			RootSum.ExportedCount   = RootSum.ExportedCount   + Var_Group.ExportedCount;
			RootSum.NotExportedCount = RootSum.NotExportedCount + Var_Group.NotExportedCount;
			
			FormatChangeCount(Var_Group);
		EndDo;
		
		FillPropertyValues(Root, RootSum);
		
		FormatChangeCount(Root);
	EndDo;
	
EndProcedure

&AtServer
Function ChangeQueryResultRegistrationServer(Command, Address)
	
	Result = GetFromTempStorage(Address);
	Result= Result[Result.UBound()];
	Data = Result.Unload().UnloadColumn("Ref");
	
	If Command Then
		Return AddRegistrationAtServer(True, Data);
	EndIf;
		
	Return DeleteRegistrationAtServer(True, Data);
EndFunction

&AtServer
Function RefControlForQuerySelection(Address)
	
	Result = ?(Address = Undefined, Undefined, GetFromTempStorage(Address));
	If TypeOf(Result) = Type("Array") Then 
		Result = Result[Result.UBound()];	
		If Result.Columns.Find("Ref") = Undefined Then
			Return NStr("en = 'The last query result is missing the ""Reference"" column';");
		EndIf;
	Else		
		Return NStr("en = 'Error getting query result';");
	EndIf;
	
	Return "";
EndFunction

&AtServer
Procedure SetUpChangeEditingServer(CurrentRow)
	
	Data = MetadataTree.FindByID(CurrentRow);
	If Data = Undefined Then
		Return;
	EndIf;
	
	TableName   = Data.MetaFullName;
	Description = Data.Description;
	CurrentObject   = ThisObject();
	
	If IsBlankString(TableName) Then
		Meta = Undefined;
	Else		
		Meta = CurrentObject.MetadataByFullName(TableName);
	EndIf;
	
	If Meta = Undefined Then
		SetUpEmptyPage(Description, TableName);
		NewPage1 = Items.BlankPage;
		
	ElsIf Meta = Metadata.Constants Then
		// All constants are included in the list
		SetUpConstantList();
		NewPage1 = Items.ConstantsPage;
		
	ElsIf TypeOf(Meta) = Type("MetadataObjectCollection") Then
		// All catalogs, all documents, and so on
		SetUpEmptyPage(Description, TableName);
		NewPage1 = Items.BlankPage;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		// One constant.
		SetUpConstantList(TableName, Description);
		NewPage1 = Items.ConstantsPage;
		
	ElsIf Metadata.Catalogs.Contains(Meta) 
		Or Metadata.Documents.Contains(Meta)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(Meta)
		Or Metadata.ChartsOfAccounts.Contains(Meta)
		Or Metadata.ChartsOfCalculationTypes.Contains(Meta)
		Or Metadata.BusinessProcesses.Contains(Meta)
		Or Metadata.Tasks.Contains(Meta) Then
		// Reference data type.
		SetUpRefList(TableName, Description);
		NewPage1 = Items.ReferencesListPage;
		
	Else
		// Checking whether a record set is passed
		Dimensions = CurrentObject.RecordSetDimensions(TableName);
		If Dimensions <> Undefined Then
			SetUpRecordSet(TableName, Dimensions, Description);
			NewPage1 = Items.RecordSetPage;
		Else
			SetUpEmptyPage(Description, TableName);
			NewPage1 = Items.BlankPage;
		EndIf;
		
	EndIf;
	
	Items.ConstantsPage.Visible    = False;
	Items.ReferencesListPage.Visible = False;
	Items.RecordSetPage.Visible = False;
	Items.BlankPage.Visible       = False;
	
	Items.ObjectsListOptions.CurrentPage = NewPage1;
	NewPage1.Visible = True;
	
	SetUpGeneralMenuCommandVisibility();
	
EndProcedure

// Displaying changes for a reference type (catalog, document, chart of characteristic types, 
// chart of accounts, calculation type, business processes, tasks).
//
&AtServer
Procedure SetUpRefList(TableName, Description)
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = 
	"SELECT
	|	ChangesTable.Ref AS Ref,
	|	ChangesTable.MessageNo AS MessageNo,
	|	CASE
	|		WHEN ChangesTable.MessageNo IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NotExported,
	|	MainTable.Ref AS ObjectRef2
	|FROM
	|	&NameOfTheChangeMetadataTable AS ChangesTable
	|		LEFT JOIN &MetadataTableName AS MainTable
	|		ON ChangesTable.Ref = MainTable.Ref
	|WHERE
	|	ChangesTable.Node = &SelectedNode";
	
	ListProperties.QueryText = StrReplace(ListProperties.QueryText, "&NameOfTheChangeMetadataTable", TableName + ".Changes");
	ListProperties.QueryText = StrReplace(ListProperties.QueryText, "&MetadataTableName", TableName);
		
	SetDynamicListProperties(Items.ReferenceList, ListProperties);
	
	ReferenceList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeReference);
	ReferencesListTableName = TableName;
	
	// Object presentation.
	Meta = ThisObject().MetadataByFullName(TableName);
	CurTitle = Meta.ObjectPresentation;
	If IsBlankString(CurTitle) Then
		CurTitle = Description;
	EndIf;
	Items.ReferencesListRefPresentation.Title = CurTitle;
EndProcedure

// Displaying changes for constants.
//
&AtServer
Procedure SetUpConstantList(TableName = Undefined, Description = "")
	
	If TableName = Undefined Then
		// All constants.
		Names = MetadataNamesStructure.Constants;
		Presentations = MetadataPresentationsStructure.Constants;
		AutoRecord = MetadataAutoRecordStructure.Constants;
	Else
		Names = New Array;
		Names.Add(TableName);
		Presentations = New Array;
		Presentations.Add(Description);
		IndexOf = MetadataNamesStructure.Constants.Find(TableName);
		AutoRecord = New Array;
		AutoRecord.Add(MetadataAutoRecordStructure.Constants[IndexOf]);
	EndIf;
	
	QueryTextTemplate2 = 
	"SELECT
	|	&AutoRecordPictureIndex AS AutoRecordPictureIndex,
	|	2 AS PictureIndex,
	|	""&CustomRepresentationOfAConstant"" AS Description,
	|	""&MetadataTableNamePresentation"" AS MetaFullName,
	|	ChangesTable.MessageNo AS MessageNo,
	|	CASE
	|		WHEN ChangesTable.MessageNo IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NotExported
	|FROM
	|	&MetadataTableName AS ChangesTable
	|WHERE
	|	ChangesTable.Node = &SelectedNode";
	
	// The limit to the number of tables must be considered.
	Text = "";
	For IndexOf = 0 To Names.UBound() Do
		
		Name = Names[IndexOf];
		
		If Not IsBlankString(Text) Then
			
			Text = Text + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
			
		EndIf;
		
		SubqueryText = StrReplace(QueryTextTemplate2, "&AutoRecordPictureIndex", Format(AutoRecord[IndexOf], "NZ=; NG="));
		SubqueryText = StrReplace(SubqueryText, "&CustomRepresentationOfAConstant", ProcessQuotationMarksInRow(Presentations[IndexOf]));
		SubqueryText = StrReplace(SubqueryText, "&MetadataTableNamePresentation", Name);
		SubqueryText = StrReplace(SubqueryText, "&MetadataTableName", SubstituteParametersToString("%1.Changes", Name));
		
		Text = Text + SubqueryText;
		
	EndDo;
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	
	ResultingQueryText = 
	"SELECT
	|	AutoRecordPictureIndex,
	|	PictureIndex,
	|	MetaFullName,
	|	NotExported,
	|	Description,
	|	MessageNo
	|{SELECT
	|	AutoRecordPictureIndex,
	|	PictureIndex,
	|	Description,
	|	MetaFullName,
	|	MessageNo,
	|	NotExported}
	|FROM
	|	&TheTextOfASubquery AS Data
	|{WHERE
	|	Description,
	|	MessageNo,
	|	NotExported}";
	
	ResultingQueryText = StrReplace(ResultingQueryText, "&TheTextOfASubquery", SubstituteParametersToString("(%1)", Text));
	ListProperties.QueryText = ResultingQueryText;
	
	SetDynamicListProperties(Items.ConstantsList, ListProperties);
		
	ListItems = ConstantsList.Order.Items;
	If ListItems.Count() = 0 Then
		Item = ListItems.Add(Type("DataCompositionOrderItem"));
		Item.Field = New DataCompositionField("Description");
		Item.Use = True;
	EndIf;
	
	ConstantsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeReference);
EndProcedure	

// Displaying cap with an empty page.
&AtServer
Procedure SetUpEmptyPage(Description, TableName = Undefined)
	
	If TableName = Undefined Then
		CountsText = "";
	Else
		Tree = FormAttributeToValue("MetadataTree");
		String = Tree.Rows.Find(TableName, "MetaFullName", True);
		If String <> Undefined Then
			CountsText = NStr("en = 'Items registered: %1
			                          |Items exported: %2
			                          |Items pending export: %3';");
	
			CountsText = StrReplace(CountsText, "%1", Format(String.ChangeCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%2", Format(String.ExportedCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%3", Format(String.NotExportedCount, "NFD=0; NZ="));
		EndIf;
	EndIf;
	
	Text = NStr("en = '%1.
	                 |
	                 |%2
	                 |
	                 |To register or unregister items for exchange with node ""%3"",
	                 |select an object in the metadata object tree and click Register or Unregister.
	                 |';");
		
	Text = StrReplace(Text, "%1", Description);
	Text = StrReplace(Text, "%2", CountsText);
	Text = StrReplace(Text, "%3", ExchangeNodeReference);
	Items.EmptyPageDecoration.Title = Text;
EndProcedure

// Displaying changes for record sets.
//
&AtServer
Procedure SetUpRecordSet(TableName, Dimensions, Description)
	
	ChoiceText = "";
	Prefix     = "RecordSetsList";
	For Each String In Dimensions Do
		Name = String.Name;
		ChoiceText = ChoiceText + ",ChangesTable." + Name + " AS " + Prefix + Name + Chars.LF;
		// 
		String.Name = Prefix + Name;
	EndDo;
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = 
	"SELECT ALLOWED
	|	ChangesTable.MessageNo AS MessageNo,
	|	CASE 
	|		WHEN ChangesTable.MessageNo IS NULL THEN TRUE ELSE FALSE
	|	END AS NotExported
	|
	|	" + ChoiceText + "
	|FROM
	|	" + TableName + ".Changes AS ChangesTable
	|WHERE
	|	ChangesTable.Node = &SelectedNode";
	
	SetDynamicListProperties(Items.RecordSetsList, ListProperties);
	
	RecordSetsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeReference);
	
	// Adding columns to the appropriate group.
	ThisObject().AddColumnsToFormTable(
		Items.RecordSetsList, 
		"MessageNo, NotExported, 
		|Order, Filter, Group, StandardPicture, Parameters, ConditionalAppearance",
		Dimensions,
		Items.RecordSetsListDimensionsGroup);
	
	RecordSetsListTableName = TableName;
EndProcedure

// Common filter by the MessageNumber field.
//
&AtServer
Procedure SetFilterByMessageNo(DynamList, Variant)
	
	Field = New DataCompositionField("NotExported");
	// Iterating through the filter item list to delete a specific item.
	ListItems = DynamList.Filter.Items;
	IndexOf = ListItems.Count();
	While IndexOf > 0 Do
		IndexOf = IndexOf - 1;
		Item = ListItems[IndexOf];
		If Item.LeftValue = Field Then 
			ListItems.Delete(Item);
		EndIf;
	EndDo;
	
	FilterElement = ListItems.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = Field;
	FilterElement.ComparisonType  = DataCompositionComparisonType.Equal;
	FilterElement.Use = False;
	FilterElement.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	If Variant = 1 Then 		// Выгруженные
		FilterElement.RightValue = False;
		FilterElement.Use  = True;
		
	ElsIf Variant = 2 Then	// 
		FilterElement.RightValue = True;
		FilterElement.Use  = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpGeneralMenuCommandVisibility()
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	
	If CurrRow = Items.ConstantsPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = True;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = True;
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	Else
		Items.FormAddRegistrationForSingleObject.Enabled = False;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = False;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	EndIf;
	
EndProcedure

&AtServer
Function RecordSetKeyNameArray(TableName, NamePrefix = "")
	Result = New Array;
	Dimensions = ThisObject().RecordSetDimensions(TableName);
	If Dimensions <> Undefined Then
		For Each String In Dimensions Do
			Result.Add(NamePrefix + String.Name);
		EndDo;
	EndIf;
	Return Result;
EndFunction	

&AtServer
Function GetManagerByMetadata(TableName) 
	LongDesc = ThisObject().MetadataCharacteristics(TableName);
	If LongDesc <> Undefined Then
		Return LongDesc.Manager;
	EndIf;
	Return Undefined;
EndFunction

&AtServer
Function SerializationText(Serialization)
	
	DataProcessorObject = ThisObject();
	
	Text = New TextDocument;
	
	Record = New XMLWriter;
	For Each Item In Serialization Do
		Record.SetString("UTF-16");
		Value = Undefined;
		
		If Item.TypeFlag = 1 Then
			// Metadata
			Manager = GetManagerByMetadata(Item.Data);
			Value = Manager.CreateValueManager();
			
		ElsIf Item.TypeFlag = 2 Then
			// 
			Manager = GetManagerByMetadata(RecordSetsListTableName);
			Value = Manager.CreateRecordSet();
			For Each NameValue In Item.Data Do
				DataProcessorObject.SetFilterItemValue(Value.Filter, NameValue.Key, NameValue.Value);
			EndDo;
			Value.Read();
			
		ElsIf Item.TypeFlag = 3 Then
			// Ссылка
			Value = Item.Data.GetObject();
			If Value = Undefined Then
				Value = New ObjectDeletion(Item.Data);
			EndIf;
		EndIf;
		
		WriteXML(Record, Value);
		Text.AddLine(Record.Close());
	EndDo;
	
	Return Text;
EndFunction	

&AtServer
Function DeleteRegistrationAtServer(NoAutoRegistration, ItemsToDelete, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(False, NoAutoRegistration, ItemsToDelete, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function AddRegistrationAtServer(NoAutoRegistration, ItemsToAdd, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(True, NoAutoRegistration, ItemsToAdd, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function EditMessageNumberAtServer(MessageNo, Data, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(MessageNo, True, Data, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function GetSelectedMetadataDetails(NoAutoRegistration, MetaGroupName = Undefined, MetaNodeName = Undefined)
    
	If MetaGroupName = Undefined And MetaNodeName = Undefined Then
		// No item selected.
		Text = NStr("en = 'all items %1 of the metadata type';");
		
	ElsIf MetaGroupName <> Undefined And MetaNodeName = Undefined Then
		// 
		Text = "%2 %1";
		
	ElsIf MetaGroupName = Undefined And MetaNodeName <> Undefined Then
		// 
		Text = NStr("en = 'all items %1 of the metadata type';");
		
	Else
		// 
		Text = NStr("en = 'all items of type ""%3"" %1';");
		
	EndIf;
	
	If NoAutoRegistration Then
		FlagText = "";
	Else
		FlagText = NStr("en = 'with Autoregistration flag';");
	EndIf;
	
	Presentation = "";
	For Each KeyValue In MetadataPresentationsStructure Do
		If KeyValue.Key = MetaGroupName Then
			IndexOf = MetadataNamesStructure[MetaGroupName].Find(MetaNodeName);
			Presentation = ?(IndexOf = Undefined, "", KeyValue.Value[IndexOf]);
			Break;
		EndIf;
	EndDo;
	
	Text = StrReplace(Text, "%1", FlagText);
	Text = StrReplace(Text, "%2", Lower(MetaGroupName));
	Text = StrReplace(Text, "%3", Presentation);
	
	Return TrimAll(Text);
EndFunction

&AtServer
Function GetCurrentRowMetadataNames(NoAutoRegistration) 
	
	String = MetadataTree.FindByID(Items.MetadataTree.CurrentRow);
	If String = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("MetaNames, LongDesc", 
		New Array, GetSelectedMetadataDetails(NoAutoRegistration));
	MetaName1 = String.MetaFullName;
	If IsBlankString(MetaName1) Then
		Result.MetaNames.Add(Undefined);	
	Else
		Result.MetaNames.Add(MetaName1);	
		
		Parent = String.GetParent();
		MetaParentName = Parent.MetaFullName;
		If IsBlankString(MetaParentName) Then
			Result.LongDesc = GetSelectedMetadataDetails(NoAutoRegistration, String.Description);
		Else
			Result.LongDesc = GetSelectedMetadataDetails(NoAutoRegistration, MetaParentName, MetaName1);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function GetSelectedMetadataNames(NoAutoRegistration)
	
	Result = New Structure("MetaNames, LongDesc", 
		New Array, GetSelectedMetadataDetails(NoAutoRegistration));
	
	For Each Root In MetadataTree.GetItems() Do
		
		If Root.Check = 1 Then
			Result.MetaNames.Add(Undefined);
			Return Result;
		EndIf;
		
		NumberOfPartial = 0;
		GroupCount     = 0;
		NodeCount     = 0;
		For Each Var_Group In Root.GetItems() Do
			
			If Var_Group.Check = 0 Then
				Continue;
			ElsIf Var_Group.Check = 1 Then
				//	
				GroupCount = GroupCount + 1;
				GroupDetails = GetSelectedMetadataDetails(NoAutoRegistration, Var_Group.Description);
				
				If Var_Group.GetItems().Count() = 0 Then
					// Reading marked data from the metadata names structure.
					AutoArray = MetadataAutoRecordStructure[Var_Group.MetaFullName];
					NamesArray = MetadataNamesStructure[Var_Group.MetaFullName];
					For IndexOf = 0 To NamesArray.UBound() Do
						If NoAutoRegistration Or AutoArray[IndexOf] = 2 Then
							Result.MetaNames.Add(NamesArray[IndexOf]);
							NodeDetails = GetSelectedMetadataDetails(NoAutoRegistration, Var_Group.MetaFullName, NamesArray[IndexOf]);
						EndIf;
					EndDo;
					
					Continue;
				EndIf;
				
			Else
				NumberOfPartial = NumberOfPartial + 1;
			EndIf;
			
			For Each Node In Var_Group.GetItems() Do
				If Node.Check = 1 Then
					// Node.AutoRecord = 2 -> allowed
					If NoAutoRegistration Or Node.AutoRecord = 2 Then
						Result.MetaNames.Add(Node.MetaFullName);
						NodeDetails = GetSelectedMetadataDetails(NoAutoRegistration, Var_Group.MetaFullName, Node.MetaFullName);
						NodeCount = NodeCount + 1;
					EndIf;
				EndIf
			EndDo;
			
		EndDo;
		
		If GroupCount = 1 And NumberOfPartial = 0 Then
			Result.LongDesc = GroupDetails;
		ElsIf GroupCount = 0 And NodeCount = 1 Then
			Result.LongDesc = NodeDetails;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ReadMessageNumbers()
	
	QueryAttributes = "SentNo, ReceivedNo";
	
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeReference, QueryAttributes);
	
	Return Data;
	
EndFunction

&AtServer
Procedure ProcessNodeChangeProhibition()
	OperationsAllowed = Not SelectExchangeNodeProhibited;
	
	If OperationsAllowed Then
		Items.ExchangeNodeReference.Visible = True;
		Title = NStr("en = 'Data registration manager';");
	Else
		Items.ExchangeNodeReference.Visible = False;
		Title = StrReplace(NStr("en = 'Data registration manager: Exchange with ""%1""';"), "%1", String(ExchangeNodeReference));
	EndIf;
	
	Items.FormOpenNodeRegistrationForm.Visible = OperationsAllowed;
	
	Items.ConstantsListContextMenuOpenNodeRegistrationForm.Visible       = OperationsAllowed;
	Items.ReferenceListContextMenuOpenNodeRegistrationForm.Visible         = OperationsAllowed;
	Items.RecordSetsListContextMenuOpenNodeRegistrationForm.Visible = OperationsAllowed;
EndProcedure

&AtServer
Function ControlSettings()
	Result = True;
	
	// Checking a specified exchange node.
	CurrentObject = ThisObject();
	If ExchangeNodeReference <> Undefined And ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeReference)) Then
		AllowedExchangeNodes = CurrentObject.GenerateNodeTree();
		PlanName = ExchangeNodeReference.Metadata().Name;
		If AllowedExchangeNodes.Rows.Find(PlanName, "ExchangePlanName1", True) = Undefined Then
			// A node with an invalid exchange plan.
			ExchangeNodeReference = Undefined;
			Result = False;
		ElsIf ExchangeNodeReference = ExchangePlans[PlanName].ThisNode() Then
			// This node.
			ExchangeNodeReference = Undefined;
			Result = False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ExchangeNodeReference) Then
		ExchangeNodeChoiceProcessingServer();
	EndIf;
	ProcessNodeChangeProhibition();
	
	// Settings dependencies.
	SetFiltersInDynamicLists();
	
	Return Result;
EndFunction

&AtServer
Procedure SetFiltersInDynamicLists()
	SetFilterByMessageNo(ConstantsList,       FilterByMessageNumberOption);
	SetFilterByMessageNo(ReferenceList,         FilterByMessageNumberOption);
	SetFilterByMessageNo(RecordSetsList, FilterByMessageNumberOption);
EndProcedure

&AtServer
Function RecordSetKeyStructure(Val CurrentData)
	
	DataProcessorObject = ThisObject();
	
	LongDesc = DataProcessorObject.MetadataCharacteristics(RecordSetsListTableName);
	
	If LongDesc = Undefined Then
		// 
		Return Undefined;
	EndIf;
	
	Result = New Structure("FormName, Parameter, Value");
	
	Dimensions = New Structure;
	KeysNames = RecordSetKeyNameArray(RecordSetsListTableName);
	
	For Each Name In KeysNames Do
		ColumnName = "RecordSetsList" + Name;
		If CurrentData.Property(ColumnName) Then
			Dimensions.Insert(Name, CurrentData[ColumnName]);
		EndIf;	
	EndDo;
	
	If Dimensions.Property("Recorder") Then
		MetaRecorder = Metadata.FindByType(TypeOf(Dimensions.Recorder));
		If MetaRecorder = Undefined Then
			Result = Undefined;
		Else
			Result.FormName = MetaRecorder.FullName() + ".ObjectForm";
			Result.Parameter = "Key";
			Result.Value = Dimensions.Recorder;
		EndIf;
		
	ElsIf Dimensions.Count() = 0 Then
		// 
		Result.FormName = RecordSetsListTableName + ".ListForm";
		
	Else
		Set = LongDesc.Manager.CreateRecordSet(); // 
		For Each KeyValue In Dimensions Do
			DataProcessorObject.SetFilterItemValue(Set.Filter, KeyValue.Key, KeyValue.Value);
		EndDo;
		Set.Read();
		If Set.Count() = 1 Then
			// 
			Result.FormName = RecordSetsListTableName + ".RecordForm";
			Result.Parameter = "Key";
			
			Var_Key = New Structure;
			For Each SetColumn In Set.Unload().Columns Do
				ColumnName = SetColumn.Name;
				Var_Key.Insert(ColumnName, Set[0][ColumnName]);
			EndDo;
			Result.Value = LongDesc.Manager.CreateRecordKey(Var_Key);
		Else
			// Список
			Result.FormName = RecordSetsListTableName + ".ListForm";
			Result.Parameter = "Filter";
			Result.Value = Dimensions;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		And (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_3"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_4"]))) Then
		
		Raise NStr("en = 'The data processor supports 1C:Enterprise 8.3.5 or later,
			|with disabled compatibility mode.';");
		
	EndIf;
	
EndProcedure

&AtServer
Function RegisterMOIDAndPredefinedItemsAtServer()
	
	CurrentObject = ThisObject();
	Return CurrentObject.SSLUpdateAndRegisterMasterNodeMetadataObjectID(ExchangeNodeReference);
	
EndFunction

&AtServer
Function PrepareRegistrationChangeParameters(Command, NoAutoRegistration, Data, TableName = Undefined)
	Result = New Structure;
	Result.Insert("Command", Command);
	Result.Insert("NoAutoRegistration", NoAutoRegistration);
	Result.Insert("Node", ExchangeNodeReference);
	Result.Insert("Data", Data);
	Result.Insert("TableName", TableName);
	
	Result.Insert("ConfigurationSupportsSSL",       Object.ConfigurationSupportsSSL);
	Result.Insert("RegisterWithSSLMethodsAvailable",  Object.RegisterWithSSLMethodsAvailable);
	Result.Insert("DIBModeAvailable",                 Object.DIBModeAvailable);
	Result.Insert("ObjectExportControlSetting", Object.ObjectExportControlSetting);
	Result.Insert("BatchRegistrationIsAvailable",       Object.BatchRegistrationIsAvailable);
	
	Result.Insert("MetadataNamesStructure",           MetadataNamesStructure);
	
	Return Result;
EndFunction

&AtServer
Procedure AddNameOfMetadataToHide()
	// Registers with the Node dimension are hidden
	For Each InformationRegisterMetadata In Metadata.InformationRegisters Do
		For Each RegisterDimension In InformationRegisterMetadata.Dimensions Do
			If Lower(RegisterDimension.Name) = "node" Then
				NamesOfMetadataToHide.Add("InformationRegister." + InformationRegisterMetadata.Name);
				Break;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure SetDynamicListProperties(List, ParametersStructure)
	
	Form = List.Parent;
	
	While TypeOf(Form) <> Type("ClientApplicationForm") Do
		Form = Form.Parent;
	EndDo;
	
	DynamicList = Form[List.DataPath];
	QueryText = ParametersStructure.QueryText;
	
	If Not IsBlankString(QueryText) Then
		DynamicList.QueryText = QueryText;
	EndIf;
	
	MainTable = ParametersStructure.MainTable;
	
	If Not IsBlankString(MainTable) Then
		DynamicList.MainTable = MainTable;
	EndIf;
	
	DynamicDataRead = ParametersStructure.DynamicDataRead;
	
	If TypeOf(DynamicDataRead) = Type("Boolean") Then
		DynamicList.DynamicDataRead = DynamicDataRead;
	EndIf;
	
EndProcedure

&AtServer
Function DynamicListPropertiesStructure()
	
	Return New Structure("QueryText, MainTable, DynamicDataRead");
	
EndFunction

&AtServer
Procedure FillAdditionalInformation()
	
	If Not IsConfigurationSupportsDataSyncLib() Then
		Items.AdditionalInformationGroup.Visible = False;
		Return;
	EndIf;
	
	ModuleDataExchangeCached = CommonModuleDataExchangeCached();
	ModuleDataExchangeRegistrationCached = CommonModuleDataExchangeRegistrationCached();
	ModuleDataExchangeRegistrationServer = CommonModuleDataExchangeRegistrationServer();
	
	If ValueIsFilled(ExchangeNodeReference) Then
		
		ExchangePlanName = ModuleDataExchangeCached.GetExchangePlanName(ExchangeNodeReference);
		
		If ModuleDataExchangeCached.IsSSLDataExchangeNode(ExchangeNodeReference)
			And (ModuleDataExchangeCached.IsStandardDataExchangeNode(ExchangePlanName)
				Or ModuleDataExchangeCached.IsUniversalDataExchangeNode(ExchangeNodeReference)) Then
			
			SelectiveRegistrationMode = ModuleDataExchangeRegistrationCached.ExchangePlanDataSelectiveRegistrationMode(ExchangePlanName);
			If SelectiveRegistrationMode = ModuleDataExchangeRegistrationServer.SelectiveRegistrationModeDisabled()Then
				
				TitleText = NStr("en = 'Disabled.';", DefaultLanguageCode());
				
			ElsIf SelectiveRegistrationMode = ModuleDataExchangeRegistrationServer.SelectiveRegistrationModeModification() Then
				
				TitleText = NStr("en = 'Modified.';", DefaultLanguageCode());
				
			Else
				
				TitleText = NStr("en = 'According to XML rules.';", DefaultLanguageCode());
				
			EndIf;
			
		Else
			
			TitleText = NStr("en = 'Not supported.';", DefaultLanguageCode());
			
		EndIf;
		
	Else
		
		TitleText = NStr("en = 'Specify a synchronization setting.';", DefaultLanguageCode());
		
	EndIf;
	
	TitleTemplate1 = NStr("en = 'Selective registration mode: %1';", DefaultLanguageCode());
	TitleText = StrTemplate(TitleTemplate1, TitleText);
	Items.DecorationSelectiveRegistrationMode.Title = TitleText;
	
EndProcedure

&AtServer
Function IsConfigurationSupportsDataSyncLib()
	
	Return Metadata.Subsystems.Find("StandardSubsystems") <> Undefined
		And Metadata.Subsystems["StandardSubsystems"].Subsystems.Find("DataExchange") <> Undefined
		And Metadata.Subsystems["StandardSubsystems"].Subsystems["DataExchange"].Subsystems.Find("Registration") <> Undefined; 
	
EndFunction

&AtServer
Function CommonModuleDataExchangeCached()
	Return Eval("DataExchangeCached"); // 
EndFunction

&AtServer
Function CommonModuleDataExchangeRegistrationCached()
	Return Eval("DataExchangeRegistrationCached"); // 
EndFunction

&AtServer
Function CommonModuleDataExchangeRegistrationServer()
	Return Eval("DataExchangeRegistrationServer"); // 
EndFunction


////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Function SubstituteParametersToString(Val SubstitutionString, Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
	
EndFunction

&AtServer 
Function DefaultLanguageCode()
	
	Return Metadata.DefaultLanguage.LanguageCode;
	
EndFunction

#EndRegion