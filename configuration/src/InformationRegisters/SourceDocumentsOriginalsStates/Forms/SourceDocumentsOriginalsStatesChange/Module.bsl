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

	OriginalsStates = SourceDocumentsOriginalsRecording.UsedStates();
	SourceDocumentsOriginalsRecording.OutputOriginalStateCommandsToForm(ThisObject, PrintFormsSet, OriginalsStates);
		
	FillPrintFormsListByRef();

	If Parameters.Property("DocumentRef") Then
		Record.Owner = Parameters.DocumentRef;
		PrintFormsFilter = "All";
		Items.WarningLabel.Title = NStr("en = 'The document original state will be set according to print forms.';");
	ElsIf PrintFormsSet.Count()= 0 Then
		FillAllPrintForms();
		PrintFormsFilter = "All";
		Items.WarningLabel.Title = NStr("en = 'The document original state will be set according to print forms.';");
	Else
		PrintFormsFilter = "Tracked";
	EndIf;	

	SetOriginalRef();

	If PrintFormsSet.Count()= 0 Then
		RestoreFilter = False;
	Else
		RestoreFilter = True;
	EndIf;
		
	RestoreSettings(RestoreFilter);

	SetOriginalRef();
	
	SetPrintFormsFilter();
	
	AppearanceItem = ConditionalAppearance.Items.Add();

	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PrintFormsSet.State"); 
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterElement.Use = True;
	
	AppearanceItem.Appearance.SetParameterValue("TextColor",  WebColors.Gainsboro);
	AppearanceItem.Use = True;

	AppearanceField = AppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("PrintFormsSetPresentation");
	AppearanceField.Use = True;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	// StandardSubsystems.SourceDocumentsOriginalsRecording
	If EventName = "AddDeleteSourceDocumentOriginalState" Then
		Attachable_UpdateOriginalStateCommands();
		RefreshDataRepresentation();
	ElsIf EventName = "SourceDocumentOriginalStateChange" 
		Or EventName = "TabularDocumentsArePrinted" Then
		
		PrintFormsSet.Clear();
		ShowTrackedAtServer();
		If PrintFormsSet.Count()=0 Then
			 ShowAllAtServer();
		EndIf;
	EndIf;
	// End StandardSubsystems.SourceDocumentsOriginalsRecording

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DocumentRefClick(Item, StandardProcessing)

	StandardProcessing = False;
	ShowValue(,Record.Owner);

EndProcedure

#EndRegion

#Region FormTableItemEventHandlers

&AtClient
Procedure PrintFormsSetSelection(Item, RowSelected, Field, StandardProcessing)

	If Field.Name = "OriginalReceivedPicture" Then
		SetOriginalState("SetOriginalReceived");
	EndIf;

EndProcedure

&AtClient
Procedure PrintFormsSetBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PrintFormsSetBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PrintFormsSetStateOnChange(Item)

	CountShift = 0;

	For Each String In PrintFormsSet Do
		If ValueIsFilled(String.State) Then
			CountShift = CountShift+1;
		EndIf;
	EndDo;

	CurrentRow = Items.PrintFormsSet.CurrentData;
	NewIndex = PrintFormsSet.IndexOf(CurrentRow);

	If Not NewIndex <= CountShift Then
		CountShift = NewIndex - CountShift +1;
		PrintFormsSet.Move(NewIndex,-CountShift);
	EndIf;
	
	If Not ValueIsFilled(Items.PrintFormsSet.CurrentData.State) Then
		Items.PrintFormsSet.CurrentData.OriginalReceivedPicture = 0;
	EndIf;

	Items.PrintFormsSet.CurrentData.ChangeAuthor = UsersClient.CurrentUser();
	Items.PrintFormsSet.CurrentData.LastChangeDate = NStr("en = '<just now>';");
	
EndProcedure

&AtClient
Procedure PrintFormsSetStateChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If ValueSelected = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived") Then
		Items.PrintFormsSet.CurrentData.OriginalReceivedPicture = 1;
	Else
		Items.PrintFormsSet.CurrentData.OriginalReceivedPicture = 0;
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearNotTracked();

	SetOverallState();
	
	ShouldSaveSettings();
	
	If PrintFormsSet.Count()<> 0  Then
		WriteSourceDocumentsOriginalsStates();
		Notify("SourceDocumentOriginalStateChange");
		Close();
		SourceDocumentsOriginalsRecordingClient.NotifyUserOfStatesSetting(1, Record.Owner);
	ElsIf PrintFormsSet.Count() = 0 Then
		Close();
	EndIf;
	
EndProcedure

// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_SetOriginalState(Command)

	If Command.Name = "StatesSetup" Then
		SourceDocumentsOriginalsRecordingClient.OpenStatesSetupForm();
	Else
		SetOriginalState(Command.Name);
	EndIf;

EndProcedure

&AtServer
Procedure Attachable_UpdateOriginalStateCommands()

	SourceDocumentsOriginalsRecording.UpdateOriginalStateCommands(ThisObject,Items.PrintFormsSet);

EndProcedure

&AtClient
Procedure SetOriginalState(Command)

	OriginalReceived = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived");
	FoundState = Items.Find(Command);
	If FoundState <> Undefined Then
		StateName = FoundState.Title;
	ElsIf Command = "SetOriginalReceived" Then
		StateName = OriginalReceived;
	Else 
		Return;
	EndIf;

	For Each ListLine In Items.PrintFormsSet.SelectedRows Do
		RowData = Items.PrintFormsSet.RowData(ListLine);
		RowData.State = FindStateInCatalog(StateName);
		RowData.OriginalReceivedPicture = ?(RowData.State = OriginalReceived, 1, 0);
	EndDo;

	Items.PrintFormsSet.Refresh();

EndProcedure

&AtClient
Procedure ShowAllItems(Command)

	ShowAllAtServer() 

EndProcedure

&AtClient
Procedure ShowTracked(Command)
	
	ShowTrackedAtServer()
	
EndProcedure

&AtClient
Procedure AddManually(Command)

	If Not ValueIsFilled(PrintFormManually) Then
		Return;
	EndIf;

	SourceDocument = StrReplace(PrintFormManually," ","");
	
	FoundRows = PrintFormsSet.FindRows(New Structure("TemplateName",SourceDocument));

	If FoundRows.Count() > 0 Then
		ClearMessages();
		CommonClient.MessageToUser(NStr("en = 'The list already contains such form.';"));
		Return;
	EndIf;

	Items.AddOwnPicture.Hide();
	CountShift = 0;

	For Each String In PrintFormsSet Do
		If ValueIsFilled(String.State) Then
			CountShift = CountShift+1;
		EndIf;
	EndDo;

	If CountShift = 0 Then
		CountShift = PrintFormsSet.Count();
	Else
		CountShift = PrintFormsSet.Count() - CountShift;
	EndIf;

	NewRow = PrintFormsSet.Add();
	NewRow.TemplateName = SourceDocument;
	NewRow.Presentation = PrintFormManually;
	NewRow.State = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted");
	NewRow.FromOutside = True;
	NewRow.Picture = 2;
	NewRow.OriginalReceivedPicture = 0;

	LastRow = PrintFormsSet.Count()-1;

	PrintFormsSet.Move(LastRow,-CountShift);

	Items.PrintFormsSet.Refresh();
	Items.PrintFormsSet.SelectedRows.Clear();
	Items.PrintFormsSet.SelectedRows.Add(NewRow.GetID());

EndProcedure

#EndRegion

#Region Private

#Region FillTablePrintFormsSet

&AtServer
Procedure FillInitialPrintFormsList()

	If Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Return;
	EndIf;
	ModulePrintManager = Common.CommonModule("PrintManagement");
	
	// 
	RecordProperties = New Structure("Ref", Record.Owner);
	
	MetadataObject = RecordProperties.Ref.Metadata();
	
	ListOfObjects = New Array;
	ListOfObjects.Add(MetadataObject);

	PrintFormsCollection = ModulePrintManager.ObjectPrintCommandsAvailableForAttachments(MetadataObject);
	PrintFormsList = New ValueList;
	For Each PrintForm In PrintFormsCollection Do
		PrintFormsList.Add(PrintForm.Id, PrintForm.Presentation);
	EndDo;
	PrintObjects = New ValueList;
	PrintObjects.Add(Record.Owner);
	SourceDocumentsOriginalsRecording.WhenDeterminingTheListOfPrintedForms(PrintObjects, PrintFormsList);
	
	FullMetadataObjectName2 = MetadataObject.FullName();
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		QueryCommandsTable = ModuleAdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(
			Enums["AdditionalReportsAndDataProcessorsKinds"].PrintForm, FullMetadataObjectName2, True);
		CommandsTable = QueryCommandsTable.Execute().Unload();
	EndIf;
	
	ModuleIndividualsClientServer = Undefined;		
	TabularSection = SourceDocumentsOriginalsRecording.TableOfEmployees(Record.Owner); 
	If TabularSection <> "" Then
		
		For Each Employee In Record.Owner[TabularSection] Do
			EmployeeFromPM = Employee.Employee;  // CatalogRef
			If ModuleIndividualsClientServer <> Undefined Then
				LastFirstName = ModuleIndividualsClientServer.InitialsAndLastName(EmployeeFromPM.Description);
			Else
				LastFirstName = EmployeeFromPM.Description;
			EndIf;
			For Each CurRow In PrintFormsList Do
				Values = New Structure("Presentation, LASTFIRSTNAME", CurRow.Presentation, LastFirstName);
				NewRow = PrintFormsSet.Add();
				NewRow.TemplateName = CurRow.Value;
				NewRow.Presentation = StringFunctionsClientServer.InsertParametersIntoString(NStr("en = '[Presentation] [LastFirstName]';"), Values);
				NewRow.Picture = 1; 
				NewRow.OriginalReceivedPicture = 0;
				NewRow.Employee = EmployeeFromPM;
			EndDo;
		EndDo;
		If CommandsTable.Count() > 0 Then
			For Each Employee In Record.Owner[TabularSection] Do
				If ModuleIndividualsClientServer <> Undefined Then
					LastFirstName = ModuleIndividualsClientServer.InitialsAndLastName(EmployeeFromPM.Description);
				Else
					LastFirstName = EmployeeFromPM.Description;
				EndIf;
				For Each CurRow In CommandsTable Do
					Values = New Structure("Presentation, LASTFIRSTNAME", CurRow.Presentation, LastFirstName);
					If PrintFormsSet.FindRows(New Structure("TemplateName", CurRow.Id)) = 0 Then
						NewRow = PrintFormsSet.Add();
						NewRow.TemplateName = CurRow.Value;
						NewRow.Presentation =  StringFunctionsClientServer.InsertParametersIntoString(NStr("en = '[Presentation] [LastFirstName]';"), Values);
						NewRow.Picture = 1;
						NewRow.OriginalReceivedPicture = 0;
						NewRow.Employee = EmployeeFromPM;
					EndIf;
				EndDo;
			EndDo;
		EndIf;
	Else
		For Each CurRow In PrintFormsList Do
			NewRow = PrintFormsSet.Add();
			Id = CurRow.Value;
			NewRow.TemplateName = Id;
			NewRow.Presentation = CurRow.Presentation;
			NewRow.Picture = 1; 
			NewRow.OriginalReceivedPicture = 0;
		EndDo;

		If CommandsTable.Count() > 0 Then
			For Each CurRow In CommandsTable Do

				If PrintFormsSet.FindRows(New Structure("TemplateName", CurRow.Id)) = 0 Then
					NewRow = PrintFormsSet.Add();
					Id = CurRow.Value;
					NewRow.TemplateName = Id;
					NewRow.Presentation = CurRow.Presentation;
					NewRow.Picture = 1;
					NewRow.OriginalReceivedPicture = 0;
				EndIf;

			EndDo;
		EndIf;
	EndIf;

	UnusedRows = PrintFormsSet.FindRows(New Structure("Presentation", NStr("en = 'Document set for printing';")));
	For Each UnusedRow In UnusedRows Do
		PrintFormsSet.Delete(UnusedRow);
	EndDo;

	UnusedRows = PrintFormsSet.FindRows(New Structure("Presentation", NStr("en = 'Document set with setting...';")));
	For Each UnusedRow In UnusedRows Do
		PrintFormsSet.Delete(UnusedRow);
	EndDo;

EndProcedure

&AtServer
Procedure FillPrintFormsListByRef()

	Query = New Query;
	Query.Text = "SELECT
	               |	SourceDocumentsOriginalsStates.SourceDocument AS SourceDocument,
	               |	SourceDocumentsOriginalsStates.State AS State,
	               |	SourceDocumentsOriginalsStates.ExternalForm AS FromOutside,
	               |	SourceDocumentsOriginalsStates.SourceDocumentPresentation AS Presentation,
	               |	SourceDocumentsOriginalsStates.LastChangeDate AS LastChangeDate,
	               |	SourceDocumentsOriginalsStates.ChangeAuthor AS ChangeAuthor,
	               |	SourceDocumentsOriginalsStates.Employee AS Employee
	               |FROM
	               |	InformationRegister.SourceDocumentsOriginalsStates AS SourceDocumentsOriginalsStates
	               |WHERE
	               |	NOT SourceDocumentsOriginalsStates.OverallState
	               |	AND SourceDocumentsOriginalsStates.Owner = &Ref";
	
	Query.SetParameter("Ref", Record.Owner);

	Selection = Query.Execute().Select();

	While Selection.Next() Do
		NewRow = PrintFormsSet.Add();
		NewRow.TemplateName = Selection.SourceDocument;
		NewRow.Presentation = Selection.Presentation;
		NewRow.State = Selection.State;
		NewRow.FromOutside = Selection.FromOutside;
		NewRow.LastChangeDate =  Selection.LastChangeDate;
		NewRow.ChangeAuthor = Selection.ChangeAuthor;
		NewRow.Employee = Selection.Employee; 
		
		If Selection.FromOutside = True Then
			NewRow.Picture = 2;
		Else
			NewRow.Picture = 1;
		EndIf;

		If Selection.State = Catalogs.SourceDocumentsOriginalsStates.OriginalReceived Then
			NewRow.OriginalReceivedPicture = 1;
		Else
			NewRow.OriginalReceivedPicture = 0;
		EndIf;

	EndDo;
	
	PrintFormsSet.Sort("Presentation");

EndProcedure

&AtServer
Procedure FillAllPrintForms()

	FillPrintFormsListByRef();
	FillInitialPrintFormsList();

	DeleteFormsDuplicates();

	Query = New Query;
	Query.Text = "SELECT
	               |	SourceDocumentsOriginalsStates.SourceDocument AS SourceDocument,
	               |	SourceDocumentsOriginalsStates.SourceDocumentPresentation AS Presentation,
	               |	SourceDocumentsOriginalsStates.ChangeAuthor AS ChangeAuthor,
	               |	SourceDocumentsOriginalsStates.LastChangeDate AS LastChangeDate,
	               |	SourceDocumentsOriginalsStates.Employee AS Employee
	               |FROM
	               |	InformationRegister.SourceDocumentsOriginalsStates AS SourceDocumentsOriginalsStates
	               |WHERE
	               |	VALUETYPE(SourceDocumentsOriginalsStates.Owner) = &Type
	               |	AND SourceDocumentsOriginalsStates.LastChangeDate BETWEEN &StartDate AND &EndDate
	               |	AND SourceDocumentsOriginalsStates.ExternalForm
	               |
	               |GROUP BY
	               |	SourceDocumentsOriginalsStates.SourceDocument,
	               |	SourceDocumentsOriginalsStates.SourceDocumentPresentation,
	               |	SourceDocumentsOriginalsStates.ChangeAuthor,
	               |	SourceDocumentsOriginalsStates.LastChangeDate,
	               |	SourceDocumentsOriginalsStates.Employee";

	
	Query.Text = StrReplace(Query.Text, "&Type","TYPE ("+Common.TableNameByRef(Record.Owner)+")");
	Query.SetParameter("StartDate",BegOfMonth(BegOfDay(CurrentSessionDate())));
	Query.SetParameter("EndDate",EndOfMonth(EndOfDay(CurrentSessionDate())));

	Selection = Query.Execute().Select();

	While Selection.Next() Do
		NewRow = PrintFormsSet.Add();
		NewRow.TemplateName = Selection.SourceDocument;
		NewRow.Presentation = Selection.Presentation;
		NewRow.FromOutside = True;
		NewRow.Picture = 2;
		NewRow.OriginalReceivedPicture = 0;
		NewRow.LastChangeDate =  Selection.LastChangeDate;
		NewRow.ChangeAuthor = Selection.ChangeAuthor;
		NewRow.Employee = Selection.Employee;	
	EndDo;
	
	DeleteFormsDuplicates();
	
EndProcedure

&AtServer
Procedure ClearNotTracked()
	
	Filter = New Structure("State",PredefinedValue("Catalog.SourceDocumentsOriginalsStates.EmptyRef"));
	FoundRows = PrintFormsSet.FindRows(Filter);
	For Each String In FoundRows Do 
		 PrintFormsSet.Delete(String);
	EndDo;
	 
EndProcedure
	
&AtServer
Procedure DeleteFormsDuplicates()

	PrintFormsToDelete = New Array;
	For Each String In PrintFormsSet Do
		TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Record.Owner); 
		If TS <> "" Then
			Filter = New Structure("Presentation", String.Presentation);
		Else
			Filter = New Structure("TemplateName", String.TemplateName);
		EndIf;
		FoundDuplicates = PrintFormsSet.FindRows(Filter);
		If FoundDuplicates.Count() > 1 Then
			FoundDuplicates.Delete(0);
			CommonClientServer.SupplementArray(PrintFormsToDelete, FoundDuplicates, True);
		EndIf;
	EndDo;
	
	For Each PrintForm In PrintFormsToDelete Do
		PrintFormsSet.Delete(PrintForm);
	EndDo;

EndProcedure

#EndRegion

&AtServer
Procedure ShowAllAtServer() 

	Items.ShowAllItems.Check = True;
	Items.ShowTracked.Check = False;
	PrintFormsFilter = "All";
	
	ClearNotTracked();
	FillAllPrintForms();

EndProcedure

&AtServer
Procedure ShowTrackedAtServer() 

	Items.ShowAllItems.Check = False;
	Items.ShowTracked.Check = True;
	PrintFormsFilter = "Tracked";
	
	ClearNotTracked();
	FillPrintFormsListByRef();
	DeleteFormsDuplicates();
EndProcedure

&AtServer
Procedure SetPrintFormsFilter() 
	
	If PrintFormsFilter = "Tracked" Then
		ShowTrackedAtServer();
	Else 
		ShowAllAtServer();
	EndIf;

EndProcedure

&AtServer
Procedure SetOriginalRef() 

	// To disable configuration checks.
	RecordProperties = New Structure("Ref", Record.Owner);
	
	Document = RecordProperties.Ref.GetObject();
	DocumentType = RecordProperties.Ref.Metadata();

	If Common.SubsystemExists("StandardSubsystems.ObjectsPrefixes") Then
		Values = New Structure("Document,Number,Date",TrimAll(DocumentType),
			ObjectsPrefixesClientServer.NumberForPrinting(Document.Number, True, True),Format(Document.Date,NStr("en = 'DLF=DD';")));
		DocumentReference = NStr("en = '[Document] #[Number], [Date]';");
		DocumentReference = StringFunctionsClientServer.InsertParametersIntoString(DocumentReference,Values);
	Else
		DocumentReference = Record.Owner;
	EndIf;

EndProcedure

&AtServer
Function FindStateInCatalog(Val StateName)

	Return ?(TypeOf(StateName) = Type("String"), 
		Catalogs.SourceDocumentsOriginalsStates.FindByDescription(StateName), StateName);

EndFunction

&AtClient
Procedure SetOverallState()

	ObjectsToWriteCount = 0;

	For Each String In PrintFormsSet Do
		If ValueIsFilled(String.State) Then
			ObjectsToWriteCount = ObjectsToWriteCount + 1;
		EndIf;
	EndDo;

	For Each String In PrintFormsSet Do
		If ValueIsFilled(String.State) Then
			Filter = New Structure("State",String.State);
			FoundRows = PrintFormsSet.FindRows(Filter);

			If FoundRows.Count() = PrintFormsSet.Count() Or ObjectsToWriteCount = 1  Then
				Record.State = String.State;
			Else
				Record.State = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalsNotAll");
			EndIf;

			Break;
		EndIf;
	EndDo

EndProcedure

&AtServer
Procedure WriteSourceDocumentsOriginalsStates()

	CheckOriginalStateRecord = InformationRegisters.SourceDocumentsOriginalsStates.CreateRecordSet();
	CheckOriginalStateRecord.Filter.Owner.Set(Record.Owner);
	CheckOriginalStateRecord.Read(); 

	If CheckOriginalStateRecord.Count() = 0 Then
		InformationRegisters.SourceDocumentsOriginalsStates.WriteCommonDocumentOriginalState(Record.Owner,Record.State);
	EndIf;

	If PrintFormsSet.Count()<> 0 Then
		For Each PrintForm In PrintFormsSet Do
			
			If ValueIsFilled(PrintForm.State) Then
				TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Record.Owner); 
				If TS = "" Then
					CheckOriginalStateRecord.Filter.SourceDocument.Set(PrintForm.TemplateName);
					CheckOriginalStateRecord.Read();
				Else
				 	CheckOriginalStateRecord.Filter.SourceDocument.Set(PrintForm.TemplateName);
					CheckOriginalStateRecord.Filter.Employee.Set(PrintForm.Employee);
					CheckOriginalStateRecord.Read();
				EndIf;
				If CheckOriginalStateRecord.Count() > 0 Then

					If CheckOriginalStateRecord[0].State <> PrintForm.State Then
						InformationRegisters.SourceDocumentsOriginalsStates.WriteDocumentOriginalStateByPrintForms(Record.Owner,
							PrintForm.TemplateName,PrintForm.Presentation,PrintForm.State,PrintForm.FromOutside, PrintForm.Employee);
					EndIf;
				Else
						InformationRegisters.SourceDocumentsOriginalsStates.WriteDocumentOriginalStateByPrintForms(Record.Owner,
							PrintForm.TemplateName,PrintForm.Presentation,PrintForm.State,PrintForm.FromOutside,PrintForm.Employee);
				
				EndIf;
			EndIf;

		EndDo;
	EndIf;
	InformationRegisters.SourceDocumentsOriginalsStates.WriteCommonDocumentOriginalState(Record.Owner,Record.State);
EndProcedure

&AtServer
Procedure RestoreSettings(RestoreFilter)

	Settings = Common.CommonSettingsStorageLoad("InformationRegister.SourceDocumentsOriginalsStates.Form.SourceDocumentsOriginalsStatesChange","PrintFormsFilter");

	If RestoreFilter Then 
		If TypeOf(Settings) = Type("Structure") Then
			PrintFormsFilter = Settings.PrintFormsFilter;
		EndIf;
	EndIf;	
	
EndProcedure

&AtServer
Procedure ShouldSaveSettings()

	AttributesToSaveNames = "PrintFormsFilter";

	Settings = New Structure(AttributesToSaveNames);
	FillPropertyValues(Settings, ThisObject);

	Common.CommonSettingsStorageSave("InformationRegister.SourceDocumentsOriginalsStates.Form.SourceDocumentsOriginalsStatesChange","PrintFormsFilter",Settings);

EndProcedure

#EndRegion
