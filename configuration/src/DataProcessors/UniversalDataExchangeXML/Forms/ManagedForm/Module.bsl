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
	
	// First of all, checking the access rights.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en = 'Only administrators can run the data processor manually.';");
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	Object.IsInteractiveMode = True;
	Object.SafeMode = True;
	Object.ExchangeProtocolFileEncoding = "TextEncoding.UTF8";
	
	FormCaption = NStr("en = 'Conversion Rule Data Exchange in XML format (%DataProcessorVersion%)';");
	FormCaption = StrReplace(FormCaption, "%DataProcessorVersion%", ObjectVersionAsStringAtServer());
	
	Title = FormCaption;
	
	FillTypeAvailableToDeleteList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.RulesFileName.ChoiceList.LoadValues(ExchangeRules.UnloadValues());
	Items.ExchangeFileName.ChoiceList.LoadValues(DataImportFromFile.UnloadValues());
	Items.DataFileName.ChoiceList.LoadValues(DataExportToFile.UnloadValues());
	
	OnPeriodChange();
	
	OnChangeChangesRegistrationDeletionType();
	
	ClearDataImportFileData();
	
	DirectExport = ?(Object.DirectReadingInDestinationIB, 1, 0);
	
	SavedImportMode = (Object.ExchangeMode = "Load");
	
	If SavedImportMode Then
		
		// 
		Items.FormMainPanel.CurrentPage = Items.FormMainPanel.ChildItems.Load;
		
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();
	
	ExpandTreeRows(DataToDelete, Items.DataToDelete, "Check");
	
	ArchiveFileOnValueChange();
	DirectExportOnValueChange();
	
	#If WebClient Then
		Items.ExportDebugPages.CurrentPage = Items.ExportDebugPages.ChildItems.WebClientExportGroup;
		Items.ImportDebugPages.CurrentPage = Items.ImportDebugPages.ChildItems.WebClientImportGroup;
		Object.HandlersDebugModeFlag = False;
		
		IsClient = True;
		Items.ProcessingMode.Enabled = False;
	#EndIf
	
	ChangeProcessingMode(IsClient);
	
	SetDebugCommandsEnabled();
	
	If SavedImportMode
		And Object.AutomaticDataImportSetup <> 0 Then
		
		If Object.AutomaticDataImportSetup = 1 Then
			
			NotifyDescription = New NotifyDescription("OnOpenCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to import data from the exchange file?';"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			
		Else
			
			OnOpenCompletion(DialogReturnCode.Yes, Undefined);
			
		EndIf;
		
	EndIf;
	
	If Not IsWindowsClient() Then
		Items.OSGroup.CurrentPage = Items.OSGroup.ChildItems.LinuxGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpenCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportFromForm();
		ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ArchiveFileOnChange(Item)
	
	ArchiveFileOnValueChange();
	
EndProcedure

&AtClient
Procedure ExchangeRulesFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, ThisObject, "RulesFileName", True, , False, True);
	
EndProcedure

&AtClient
Procedure ExchangeRulesFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DirectExportOnChange(Item)
	
	DirectExportOnValueChange();
	
EndProcedure

&AtClient
Procedure FormMainPanelOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage.Name = "Upload0" Then
		
		Object.ExchangeMode = "Upload0";
		
	ElsIf CurrentPage.Name = "Load" Then
		
		Object.ExchangeMode = "Load";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DebugModeFlagOnChange(Item)
	
	If Object.FlagDebugMode Then
		
		Object.UseTransactions = False;
				
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();

EndProcedure

&AtClient
Procedure ProcessedObjectsCountToUpdateStatusOnChange(Item)
	
	If Object.ProcessedObjectsCountToUpdateStatus = 0 Then
		Object.ProcessedObjectsCountToUpdateStatus = 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, ThisObject, "ExchangeFileName", False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, Object, "ExchangeProtocolFileName", False, "txt", False);
	
EndProcedure

&AtClient
Procedure ImportExchangeLogFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, Object, "ImportExchangeLogFileName", False, "txt", False);
	
EndProcedure

&AtClient
Procedure DataFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, ThisObject, "DataFileName", False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure InfobaseToConnectDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	
	FileDialog.Title = NStr("en = 'Select an infobase directory';");
	FileDialog.Directory = Object.InfobaseToConnectDirectory;
	FileDialog.CheckFileExist = True;
	
	Notification = New NotifyDescription("ProcessSelectionInfobaseDirectoryToAdd", ThisObject);
	FileDialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure ProcessSelectionInfobaseDirectoryToAdd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	Object.InfobaseToConnectDirectory = SelectedFiles[0];
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ImportExchangeLogFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseToConnectDirectoryOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseToConnectWindowsAuthenticationOnChange(Item)
	
	Items.InfobaseToConnectUser.Enabled = Not Object.InfobaseToConnectWindowsAuthentication;
	Items.InfobaseToConnectPassword.Enabled = Not Object.InfobaseToConnectWindowsAuthentication;
	
EndProcedure

&AtClient
Procedure RulesFileNameOnChange(Item)
	
	File = New File(RulesFileName);
	
	Notification = New NotifyDescription("AfterExistenceCheckRulesFileName", ThisObject);
	File.BeginCheckingExistence(Notification);
	
EndProcedure

&AtClient
Procedure AfterExistenceCheckRulesFileName(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		MessageToUser(NStr("en = 'Exchange rules file not found';"), "RulesFileName");
		SetImportRuleFlag(False);
		Return;
	EndIf;
	
	If RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("RulesFileNameOnChangeCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to import data exchange rules?';"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure RulesFileNameOnChangeCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportExchangeRules();
		
	Else
		
		SetImportRuleFlag(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOnChange(Item)
	
	ClearDataImportFileData();
	
EndProcedure

&AtClient
Procedure UseTransactionsOnChange(Item)
	
	ProcessTransactionManagementItemsEnabled();
	
EndProcedure

&AtClient
Procedure ImportHandlersDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure ExportHandlerDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure DataFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DataFileNameOnChange(Item)
	
	If EmptyAttributeValue(DataFileName, "DataFileName", Items.DataFileName.Title)
		Or RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	Object.ExchangeFileName = DataFileName;
	
	File = New File(Object.ExchangeFileName);
	Object.ArchiveFile = (Upper(File.Extension) = Upper(".zip"));
	
EndProcedure

&AtClient
Procedure InfobaseToConnectTypeOnChange(Item)
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobaseToConnectPlatformVersionOnChange(Item)
	
	If IsBlankString(Object.InfobaseToConnectPlatformVersion) Then
		
		Object.InfobaseToConnectPlatformVersion = "V8";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangesRegistrationDeletionTypeForExportedExchangeNodesOnChange(Item)
	
	OnChangeChangesRegistrationDeletionType();
	
EndProcedure

&AtClient
Procedure ExportPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

&AtClient
Procedure DeletionPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

&AtClient
Procedure SafeImportOnChange(Item)
	
	ChangeSafeImportMode();
	
EndProcedure

&AtClient
Procedure NameOfImportRulesFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectingFile(Item, ThisObject, "NameOfImportRulesFile", True, , False, True);
	
EndProcedure

&AtClient
Procedure NameOfImportRulesFileOnChange(Item)
	
	PutImportRulesFileInStorage();
	
EndProcedure

#EndRegion

#Region ExportRulesTableFormTableItemEventHandlers

&AtClient
Procedure ExportRulesTableBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "ExchangeNodeRef" Then
		
		If Item.CurrentData.IsFolder Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportRulesTableOnChange(Item)
	
	If Item.CurrentItem.Name = "DER" Then
		
		CurRow = Item.CurrentData;
		
		If CurRow.Enable = 2 Then
			CurRow.Enable = 0;
		EndIf;
		
		SetSubordinateMarks(CurRow, "Enable");
		SetParentMarks(CurRow, "Enable");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataToDeleteFormTableItemEventHandlers

&AtClient
Procedure DataToDeleteOnChange(Item)
	
	CurRow = Item.CurrentData;
	
	SetSubordinateMarks(CurRow, "Check");
	SetParentMarks(CurRow, "Check");

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectionTest(Command)
	
	EstablishConnectionWithDestinationIBAtServer();
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfo(Command)
	
	FileAddress = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("GetExchangeFileInfoCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileAddress, , , UUID);
		
	Else
		
		GetExchangeFileInfoCompletion(True, FileAddress, "", Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfoCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Try
			
			OpenImportFileAtServer(Address);
			ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
			
		Except
			
			MessageToUser(NStr("en = 'Cannot read the exchange file.';"));
			ClearDataImportFileData();
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeletionSelectAll(Command)
	
	For Each String In DataToDelete.GetItems() Do
		
		String.Check = 1;
		SetSubordinateMarks(String, "Check");
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionClearAll(Command)
	
	For Each String In DataToDelete.GetItems() Do
		String.Check = 0;
		SetSubordinateMarks(String, "Check");
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionDelete(Command)
	
	NotifyDescription = New NotifyDescription("DeletionDeleteCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Do you want to delete the selected data from the infobase?';"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure DeletionDeleteCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DeleteAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportSelectAll(Command)
	
	For Each String In Object.ExportRulesTable.GetItems() Do
		String.Enable = 1;
		SetSubordinateMarks(String, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearAll(Command)
	
	For Each String In Object.ExportRulesTable.GetItems() Do
		String.Enable = 0;
		SetSubordinateMarks(String, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearExchangeNodes(Command)
	
	FillExchangeNodeInTreeRowsAtServer(Undefined);
	
EndProcedure

&AtClient
Procedure ExportMarkExchangeNode(Command)
	
	If Items.ExportRulesTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeNodeInTreeRowsAtServer(Items.ExportRulesTable.CurrentData.ExchangeNodeRef);
	
EndProcedure

&AtClient
Procedure SaveParameters(Command)
	
	SaveParametersAtServer();
	
EndProcedure

&AtClient
Procedure RestoreParameters(Command)
	
	RestoreParametersAtServer();
	
EndProcedure

&AtClient
Procedure ExportDebugSetup(Command)
	
	Object.ExchangeRulesFileName = FileNameAtServerOrClient(RulesFileName, RuleFileAddressInStorage);
	
	OpenHandlerDebugSetupForm(True);
	
EndProcedure

&AtClient
Procedure AtClient(Command)
	
	If Not IsClient Then
		
		IsClient = True;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AtServer(Command)
	
	If IsClient Then
		
		IsClient = False;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetup(Command)
	
	ExchangeFileAddressInStorage = "";
	FileNameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ImportDebugSetupCompletion", ThisObject);
		BeginPutFile(NotifyDescription, ExchangeFileAddressInStorage, , , UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ImportDebugSetupCompletion(True, ExchangeFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetupCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Object.ExchangeFileName = FileNameAtServerOrClient(ExchangeFileName ,Address, SelectedFileName);
		
		OpenHandlerDebugSetupForm(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteExport(Command)
	
	ExecuteExportFromForm();
	
EndProcedure

&AtClient
Procedure ExecuteImport(Command)
	
	ExecuteImportFromForm();
	
EndProcedure

&AtClient
Procedure ReadExchangeRules(Command)
	
	If Not IsWindowsClient() And DirectExport = 1 Then
		ShowMessageBox(,NStr("en = 'Only Windows clients support direct infobase connections.';"));
		Return;
	EndIf;
	
	FileNameForExtension = "";
	
	If IsClient Then
		
		If Not IsBlankString(RuleFileAddressInStorage)
			And IsTempStorageURL(RuleFileAddressInStorage) Then
			DeleteFromTempStorage(RuleFileAddressInStorage);
			RuleFileAddressInStorage = "";
		EndIf;
		
		NotifyDescription = New NotifyDescription("ReadExchangeRulesCompletion", ThisObject);
		BeginPutFile(NotifyDescription, RuleFileAddressInStorage, , , UUID);
		
	Else
		
		RuleFileAddressInStorage = "";
		If EmptyAttributeValue(RulesFileName, "RulesFileName", Items.RulesFileName.Title) Then
			Return;
		EndIf;
		
		ReadExchangeRulesCompletion(True, RuleFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadExchangeRulesCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		RuleFileAddressInStorage = Address;
		
		ExecuteImportExchangeRules(Address, SelectedFileName);
		
		If Object.FlagErrors Then
			
			SetImportRuleFlag(False);
			
		Else
			
			SetImportRuleFlag(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Opens an exchange file in an external application.
//
// Parameters:
//  
// 
&AtClient
Procedure OpenInApplication(FileName, StandardProcessing = False)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("NotifyDescription", New NotifyDescription);
	
	File = New File(FileName);
	
	NotifyDescription = New NotifyDescription("AfterDetermineFileExistence", ThisObject, AdditionalParameters);
	File.BeginCheckingExistence(NotifyDescription);
	
EndProcedure

// Continuation of the procedure (see above). 
&AtClient
Procedure AfterDetermineFileExistence(Exists, AdditionalParameters) Export
	
	If Exists Then
		BeginRunningApplication(AdditionalParameters.NotifyDescription, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearDataImportFileData()
	
	Object.ExchangeRulesVersion = "";
	Object.DataExportDate = "";
	ExportPeriodPresentation = "";
	
EndProcedure

&AtClient
Procedure ProcessTransactionManagementItemsEnabled()
	
	Items.UseTransactions.Enabled = Not Object.FlagDebugMode;
	
	Items.ObjectCountPerTransaction.Enabled = Object.UseTransactions;
	
EndProcedure

&AtClient
Procedure ArchiveFileOnValueChange()
	
	If Object.ArchiveFile Then
		DataFileName = StrReplace(DataFileName, ".xml", ".zip");
	Else
		DataFileName = StrReplace(DataFileName, ".zip", ".xml");
	EndIf;
	
	Items.ExchangeFileCompressionPassword.Enabled = Object.ArchiveFile;
	
EndProcedure

&AtServer
Procedure FillExchangeNodeInTreeRows(Tree, ExchangeNode)
	
	For Each String In Tree Do
		
		If String.IsFolder Then
			
			FillExchangeNodeInTreeRows(String.GetItems(), ExchangeNode);
			
		Else
			
			String.ExchangeNodeRef = ExchangeNode;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function RuleAndExchangeFileNamesMatch()
	
	If Upper(TrimAll(RulesFileName)) = Upper(TrimAll(DataFileName)) Then
		
		MessageToUser(NStr("en = 'An exchange rules file cannot be the same as a data file.
		|Select another file.';"));
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Fills a value tree with metadata objects available for deletion.
&AtServer
Procedure FillTypeAvailableToDeleteList()
	
	DataTree = FormAttributeToValue("DataToDelete");
	
	DataTree.Rows.Clear();
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Catalogs';");
	
	For Each MetadataObjectsList In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadataObjectsList.Name;
		MDRow.Metadata = "CatalogRef." + MetadataObjectsList.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Charts of characteristic types';");
	
	For Each MetadataObjectsList In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadataObjectsList.Name;
		MDRow.Metadata = "ChartOfCharacteristicTypesRef." + MetadataObjectsList.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("en = 'Documents';");
	
	For Each MetadataObjectsList In Metadata.Documents Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadataObjectsList.Name;
		MDRow.Metadata = "DocumentRef." + MetadataObjectsList.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = "InformationRegisters";
	
	For Each MetadataObjectsList In Metadata.InformationRegisters Do
		
		If Not AccessRight("Update", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		Subordinate = (MetadataObjectsList.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadataObjectsList.Name;
		MDRow.Metadata = "InformationRegisterRecord." + MetadataObjectsList.Name;
		
	EndDo;
	
	ValueToFormAttribute(DataTree, "DataToDelete");
	
EndProcedure

// Returns data processor version.
&AtServer
Function ObjectVersionAsStringAtServer()
	
	Return FormAttributeToValue("Object").ObjectVersionAsString();
	
EndFunction

&AtClient
Procedure ExecuteImportExchangeRules(RuleFileAddressInStorage = "", FileNameForExtension = "")
	
	Object.FlagErrors = False;
	
	ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension);
	
	If Object.FlagErrors Then
		
		SetImportRuleFlag(False);
		
	Else
		
		SetImportRuleFlag(True);
		ExpandTreeRows(Object.ExportRulesTable, Items.ExportRulesTable, "Enable");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandTreeRows(DataTree, PresentationOnForm, CheckBoxName)
	
	TreeRows = DataTree.GetItems();
	
	For Each String In TreeRows Do
		
		RowID=String.GetID();
		PresentationOnForm.Expand(RowID, False);
		EnableParentIfSubordinateItemsEnabled(String, CheckBoxName);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure EnableParentIfSubordinateItemsEnabled(TreeRow, CheckBoxName)
	
	Enable = TreeRow[CheckBoxName];
	
	For Each SubordinateRow In TreeRow.GetItems() Do
		
		If SubordinateRow[CheckBoxName] = 1 Then
			
			Enable = 1;
			
		EndIf;
		
		If SubordinateRow.GetItems().Count() > 0 Then
			
			EnableParentIfSubordinateItemsEnabled(SubordinateRow, CheckBoxName);
			
		EndIf;
		
	EndDo;
	
	TreeRow[CheckBoxName] = Enable;
	
EndProcedure

&AtClient
Procedure OnPeriodChange()
	
	Object.StartDate = ExportPeriod.StartDate;
	Object.EndDate = ExportPeriod.EndDate;
	
EndProcedure

&AtServer
Procedure ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension)
	
	ExchangeRulesFileName = FileNameAtServerOrClient(RulesFileName ,RuleFileAddressInStorage, FileNameForExtension);
	
	If ExchangeRulesFileName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeRulesFileName = ExchangeRulesFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	ObjectForServer.ExportRulesTable = FormAttributeToValue("Object.ExportRulesTable");
	ObjectForServer.ParametersSetupTable = FormAttributeToValue("Object.ParametersSetupTable");
	
	ObjectForServer.ImportExchangeRules();
	ObjectForServer.InitializeInitialParameterValues();
	ObjectForServer.Parameters.Clear();
	Object.FlagErrors = ObjectForServer.FlagErrors;
	
	If IsClient Then
		
		DeleteFiles(Object.ExchangeRulesFileName);
		
	EndIf;
	
	ValueToFormAttribute(ObjectForServer.ExportRulesTable, "Object.ExportRulesTable");
	ValueToFormAttribute(ObjectForServer.ParametersSetupTable, "Object.ParametersSetupTable");
	
EndProcedure

// Opens file selection dialog.
//
&AtClient
Procedure SelectingFile(Item, StorageObject, PropertyName, CheckForExistence, Val DefaultExtension = "xml",
	ArchiveDataFile = True, RuleFileSelection = False)
	
	FileDialog = New FileDialog(FileDialogMode.Open);

	If DefaultExtension = "txt" Then
		
		FileDialog.Filter = "File protocol_ exchange (*.txt)|*.txt";
		FileDialog.DefaultExt = "txt";
		
	ElsIf Object.ExchangeMode = "Upload0" Then
		
		If ArchiveDataFile Then
			
			FileDialog.Filter = "Archived file data_ (*.zip)|*.zip";
			FileDialog.DefaultExt = "zip";
			
		ElsIf RuleFileSelection Then
			
			FileDialog.Filter = "File data_ (*.xml)|*.xml|Archived file data_ (*.zip)|*.zip";
			FileDialog.DefaultExt = "xml";
			
		Else
			
			FileDialog.Filter = "File data_ (*.xml)|*.xml";
			FileDialog.DefaultExt = "xml";
			
		EndIf; 
		
	Else
		If RuleFileSelection Then
			FileDialog.Filter = "File data_ (*.xml)|*.xml";
			FileDialog.DefaultExt = "xml";
		Else
			FileDialog.Filter = "File data_ (*.xml)|*.xml|Archived file data_ (*.zip)|*.zip";
			FileDialog.DefaultExt = "xml";
		EndIf;
	EndIf;
	
	FileDialog.Title = NStr("en = 'Select file';");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = CheckForExistence;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("StorageObject", StorageObject);
	AdditionalParameters.Insert("PropertyName",    PropertyName);
	AdditionalParameters.Insert("Item",        Item);
	
	Notification = New NotifyDescription("FileSelectionDialogChoiceProcessing", ThisObject, AdditionalParameters);
	FileDialog.Show(Notification);
	
EndProcedure

// Parameters:
//   SelectedFiles - Array of String - a file choice result.
//   AdditionalParameters - Structure - arbitrary additional parameters:
//     * StorageObject - Structure
//                      - ClientApplicationForm - 
//     * PropertyName - String - a name of the storage object property.
//     * Item - FormField - a source of the file choice event.
//
&AtClient
Procedure FileSelectionDialogChoiceProcessing(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.StorageObject[AdditionalParameters.PropertyName] = SelectedFiles[0];
	
	Item = AdditionalParameters.Item;
	
	If Item = Items.RulesFileName Then
		RulesFileNameOnChange(Item);
	ElsIf Item = Items.ExchangeFileName Then
		ExchangeFileNameOnChange(Item);
	ElsIf Item = Items.DataFileName Then
		DataFileNameOnChange(Item);
	ElsIf Item = Items.NameOfImportRulesFile Then
		NameOfImportRulesFileOnChange(Item);
	EndIf;
	
EndProcedure

&AtServer
Procedure EstablishConnectionWithDestinationIBAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ConnectionResult = ObjectForServer.EstablishConnectionWithDestinationIB();
	
	If ConnectionResult <> Undefined Then
		
		MessageToUser(NStr("en = 'Connection established.';"));
		
	EndIf;
	
EndProcedure

// Sets mark value in subordinate tree rows
// according to the mark value in the current row.
//
// Parameters:
//  CurRow      - 
// 
&AtClient
Procedure SetSubordinateMarks(CurRow, CheckBoxName)
	
	SubordinateItems = CurRow.GetItems();
	
	If SubordinateItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each String In SubordinateItems Do
		
		String[CheckBoxName] = CurRow[CheckBoxName];
		
		SetSubordinateMarks(String, CheckBoxName);
		
	EndDo;
		
EndProcedure

// Sets mark values in parent tree rows
// according to the mark value in the current row.
//
// Parameters:
//  CurRow      - 
// 
&AtClient
Procedure SetParentMarks(CurRow, CheckBoxName)
	
	Parent = CurRow.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf; 
	
	CurState = Parent[CheckBoxName];
	
	EnabledItemsFound  = False;
	DisabledItemsFound = False;
	
	For Each String In Parent.GetItems() Do
		If String[CheckBoxName] = 0 Then
			DisabledItemsFound = True;
		ElsIf String[CheckBoxName] = 1
			Or String[CheckBoxName] = 2 Then
			EnabledItemsFound  = True;
		EndIf; 
		If EnabledItemsFound And DisabledItemsFound Then
			Break;
		EndIf; 
	EndDo;
	
	If EnabledItemsFound And DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound And (Not DisabledItemsFound) Then
		Enable = 1;
	ElsIf (Not EnabledItemsFound) And DisabledItemsFound Then
		Enable = 0;
	ElsIf (Not EnabledItemsFound) And (Not DisabledItemsFound) Then
		Enable = 2;
	EndIf;
	
	If Enable = CurState Then
		Return;
	Else
		Parent[CheckBoxName] = Enable;
		SetParentMarks(Parent, CheckBoxName);
	EndIf; 
	
EndProcedure

&AtServer
Procedure OpenImportFileAtServer(FileAddress)
	
	If IsClient Then
		
		BinaryData = GetFromTempStorage(FileAddress); // BinaryData
		AddressOnServer = GetTempFileName(".xml");
		// 
		// 
		BinaryData.Write(AddressOnServer);
		Object.ExchangeFileName = AddressOnServer;
		
	Else
		
		FileOnServer = New File(ExchangeFileName);
		
		If Not FileOnServer.Exists() Then
			
			MessageToUser(NStr("en = 'Exchange file not found on the server.';"), "ExchangeFileName");
			Return;
			
		EndIf;
		
		Object.ExchangeFileName = ExchangeFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	
	ObjectForServer.OpenImportFile(True);
	
	Object.StartDate = ObjectForServer.StartDate;
	Object.EndDate = ObjectForServer.EndDate;
	Object.DataExportDate = ObjectForServer.DataExportDate;
	Object.ExchangeRulesVersion = ObjectForServer.ExchangeRulesVersion;
	Object.Comment = ObjectForServer.Comment;
	
EndProcedure

// Deletes marked metadata tree rows.
//
&AtServer
Procedure DeleteAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	DataBeingDeletedTree = FormAttributeToValue("DataToDelete");
	
	ObjectForServer.InitManagersAndMessages();
	
	For Each TreeRow In DataBeingDeletedTree.Rows Do
		
		For Each MDRow In TreeRow.Rows Do
			
			If Not MDRow.Check Then
				Continue;
			EndIf;
			
			TypeAsString = MDRow.Metadata;
			ObjectForServer.DeleteObjectsOfType(TypeAsString);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Sets an exchange node at tree rows.
//
&AtServer
Procedure FillExchangeNodeInTreeRowsAtServer(ExchangeNode)
	
	FillExchangeNodeInTreeRows(Object.ExportRulesTable.GetItems(), ExchangeNode);
	
EndProcedure

// Saves parameter values.
//
&AtServer
Procedure SaveParametersAtServer()
	
	ParametersTable = FormAttributeToValue("Object.ParametersSetupTable");
	
	ParametersToSave1 = New Map;
	
	For Each TableRow In ParametersTable Do
		ParametersToSave1.Insert(TableRow.Description, TableRow.Value);
	EndDo;
	
	SystemSettingsStorage.Save("UniversalDataExchangeXML", "Parameters", ParametersToSave1);
	
EndProcedure

// Restores parameter values.
//
&AtServer
Procedure RestoreParametersAtServer()
	
	ParametersTable = FormAttributeToValue("Object.ParametersSetupTable");
	RestoredParameters = SystemSettingsStorage.Load("UniversalDataExchangeXML", "Parameters");
	
	If TypeOf(RestoredParameters) <> Type("Map") Then
		Return;
	EndIf;
	
	If RestoredParameters.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Couples In RestoredParameters Do
		
		ParameterName = Couples.Key;
		
		TableRow = ParametersTable.Find(Couples.Key, "Description");
		
		If TableRow <> Undefined Then
			
			TableRow.Value = Couples.Value;
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(ParametersTable, "Object.ParametersSetupTable");
	
EndProcedure

// Performs interactive data export.
//
&AtClient
Procedure ExecuteImportFromForm()
	
	FileAddress = "";
	FileNameForExtension = "";
	
	AddRowToChoiceList(Items.ExchangeFileName.ChoiceList, ExchangeFileName, DataImportFromFile);
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ExecuteImportFromFormCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileAddress, , , UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ExecuteImportFromFormCompletion(True, FileAddress, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteImportFromFormCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		ExecuteImportAtServer(Address, SelectedFileName);
		
		OpenExchangeProtocolDataIfNecessary();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteImportAtServer(FileAddress, FileNameForExtension)
	
	FileToImportName = FileNameAtServerOrClient(ExchangeFileName ,FileAddress, FileNameForExtension);
	
	If FileToImportName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeFileName = FileToImportName;
		
	EndIf;
	
	If Object.SafeImport Then
		If IsTempStorageURL(ImportRulesFileAddressInStorage) Then
			BinaryData = GetFromTempStorage(ImportRulesFileAddressInStorage); // BinaryData
			AddressOnServer = GetTempFileName("xml");
			// 
			// 
			BinaryData.Write(AddressOnServer);
			Object.ExchangeRulesFileName = AddressOnServer;
		Else
			MessageToUser(NStr("en = 'Data import file is not specified.';"));
			Return;
		EndIf;
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExecuteImport();
	
	Try
		
		If Not IsBlankString(FileAddress) Then
			DeleteFiles(FileToImportName);
		EndIf;
		
	Except
		WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", ObjectForServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	RulesAreImported = False;
	Items.FormExecuteExport.Enabled = False;
	Items.ExportNoteLabel.Visible = True;
	Items.ExportDebugAvailableGroup.Enabled = False;
	
EndProcedure

&AtServer
Function FileNameAtServerOrClient(Var_AttributeName ,Val FileAddress, Val FileNameForExtension = ".xml",
	CreateNew = False, CheckForExistence = True)
	
	FileName = Undefined;
	
	If IsClient Then
		
		If CreateNew Then
			
			Extension = ? (Object.ArchiveFile, ".zip", ".xml");
			
			FileName = GetTempFileName(Extension);
			
		Else
			
			Extension = FileExtention(FileNameForExtension);
			BinaryData = GetFromTempStorage(FileAddress); // BinaryData
			AddressOnServer = GetTempFileName(Extension);
			// 
			// 
			BinaryData.Write(AddressOnServer);
			FileName = AddressOnServer;
			
		EndIf;
		
	Else
		
		FileOnServer = New File(Var_AttributeName);
		
		If Not FileOnServer.Exists() And CheckForExistence Then
			
			MessageToUser(NStr("en = 'The file does not exist.';"));
			
		Else
			
			FileName = Var_AttributeName;
			
		EndIf;
		
	EndIf;
	
	Return FileName;
	
EndFunction

&AtServer
Function FileExtention(Val FileName)
	
	PointPosition = LastSeparator(FileName);
	
	Extension = Right(FileName,StrLen(FileName) - PointPosition + 1);
	
	Return Extension;
	
EndFunction

&AtServer
Function LastSeparator(StringWithSeparator, Separator = ".")
	
	StringLength = StrLen(StringWithSeparator);
	
	While StringLength > 0 Do
		
		If Mid(StringWithSeparator, StringLength, 1) = Separator Then
			
			Return StringLength; 
			
		EndIf;
		
		StringLength = StringLength - 1;
		
	EndDo;

EndFunction

&AtClient
Procedure ExecuteExportFromForm()
	
	// Adding rule file name and data file name to the selection list.
	AddRowToChoiceList(Items.RulesFileName.ChoiceList, RulesFileName, ExchangeRules);
	
	If Not Object.DirectReadingInDestinationIB And Not IsClient Then
		
		If RuleAndExchangeFileNamesMatch() Then
			Return;
		EndIf;
		
		AddRowToChoiceList(Items.DataFileName.ChoiceList, DataFileName, DataExportToFile);
		
	EndIf;
	
	DataFileAddressInStorage = ExecuteExportAtServer();
	
	If DataFileAddressInStorage = Undefined Then
		Return;
	EndIf;
	
	ExpandTreeRows(Object.ExportRulesTable, Items.ExportRulesTable, "Enable");
	
	If IsClient And Not DirectExport And Not Object.FlagErrors Then
		
		FileToSaveName = ?(Object.ArchiveFile, NStr("en = 'Export file.zip';"),NStr("en = 'Export file.xml';"));
		
		GetFile(DataFileAddressInStorage, FileToSaveName)
		
	EndIf;
	
	OpenExchangeProtocolDataIfNecessary();
	
EndProcedure

&AtServer
Function ExecuteExportAtServer()
	
	Object.ExchangeRulesFileName = FileNameAtServerOrClient(RulesFileName, RuleFileAddressInStorage);
	
	If Not DirectExport Then
		
		TempDataFileName = FileNameAtServerOrClient(DataFileName, "",,True, False);
		
		If TempDataFileName = Undefined Then
			
			MessageToUser(NStr("en = 'Data file not specified';"));
			Return Undefined;
			
		Else
			
			Object.ExchangeFileName = TempDataFileName;
			
		EndIf;
		
	EndIf;
	
	ExportRulesTable = FormAttributeToValue("Object.ExportRulesTable");
	ParametersSetupTable = FormAttributeToValue("Object.ParametersSetupTable");
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	
	If ObjectForServer.HandlersDebugModeFlag Then
		
		Cancel = False;
		
		File = New File(ObjectForServer.EventHandlerExternalDataProcessorFileName);
		
		If Not File.Exists() Then
			
			MessageToUser(NStr("en = 'The external event debugger file does not exist on the server';"));
			Return Undefined;
			
		EndIf;
		
		ObjectForServer.ExportEventHandlers(Cancel);
		
		If Cancel Then
			
			MessageToUser(NStr("en = 'Cannot export event handlers';"));
			Return "";
			
		EndIf;
		
	Else
		
		ObjectForServer.ImportExchangeRules();
		ObjectForServer.InitializeInitialParameterValues();
		
	EndIf;
	
	ChangeExportRuleTree(ObjectForServer.ExportRulesTable.Rows, ExportRulesTable.Rows);
	ChangeParameterTable(ObjectForServer.ParametersSetupTable, ParametersSetupTable);
	
	ObjectForServer.ExecuteExport();
	ObjectForServer.ExportRulesTable = FormAttributeToValue("Object.ExportRulesTable");
	
	If IsClient And Not DirectExport Then
		
		DataFileAddress = PutToTempStorage(New BinaryData(Object.ExchangeFileName), UUID);
		DeleteFiles(Object.ExchangeFileName);
		
	Else
		
		DataFileAddress = "";
		
	EndIf;
	
	If IsClient Then
		
		DeleteFiles(ObjectForServer.ExchangeRulesFileName);
		
	EndIf;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	Return DataFileAddress;
	
EndFunction

&AtClient
Procedure SetDebugCommandsEnabled()
	
	Items.ImportDebugSetup.Enabled = Object.HandlersDebugModeFlag;
	Items.ExportDebugSetup.Enabled = Object.HandlersDebugModeFlag;
	
EndProcedure

// Modifies a DER tree according to the tree specified in the form.
//
&AtServer
Procedure ChangeExportRuleTree(SourceTreeRows, TreeToReplaceRows)
	
	EnableColumn = TreeToReplaceRows.UnloadColumn("Enable");
	SourceTreeRows.LoadColumn(EnableColumn, "Enable");
	NodeColumn = TreeToReplaceRows.UnloadColumn("ExchangeNodeRef");
	SourceTreeRows.LoadColumn(NodeColumn, "ExchangeNodeRef");
	
	For Each SourceTreeRow1 In SourceTreeRows Do
		
		RowIndex = SourceTreeRows.IndexOf(SourceTreeRow1);
		TreeToChangeRow = TreeToReplaceRows.Get(RowIndex);
		
		ChangeExportRuleTree(SourceTreeRow1.Rows, TreeToChangeRow.Rows);
		
	EndDo;
	
EndProcedure

// Changed parameter table according the table in the form.
//
&AtServer
Procedure ChangeParameterTable(BaseTable, FormTable)
	
	DescriptionColumn = FormTable.UnloadColumn("Description");
	BaseTable.LoadColumn(DescriptionColumn, "Description");
	ValueColumn = FormTable.UnloadColumn("Value");
	BaseTable.LoadColumn(ValueColumn, "Value");
	
EndProcedure

&AtClient
Procedure DirectExportOnValueChange()
	
	ExportingParameters = Items.ExportingParameters;
	
	ExportingParameters.CurrentPage = ?(DirectExport = 0,
										  ExportingParameters.ChildItems.ExportingToFile,
										  ExportingParameters.ChildItems.ExportToDestinationIB);
	
	Object.DirectReadingInDestinationIB = (DirectExport = 1);
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobaseTypeForConnectionOnValueChange()
	
	InfobaseType = Items.InfobaseType;
	InfobaseType.CurrentPage = ?(Object.InfobaseToConnectType,
								InfobaseType.ChildItems.FileInforbaseFind,
								InfobaseType.ChildItems.ServerInfobase);
	
EndProcedure

&AtClient
Procedure AddRowToChoiceList(ValueListToSave, SavingValue, ParameterNameToSave)
	
	If IsBlankString(SavingValue) Then
		Return;
	EndIf;
	
	FoundItem = ValueListToSave.FindByValue(SavingValue);
	If FoundItem <> Undefined Then
		ValueListToSave.Delete(FoundItem);
	EndIf;
	
	ValueListToSave.Insert(0, SavingValue);
	
	While ValueListToSave.Count() > 10 Do
		ValueListToSave.Delete(ValueListToSave.Count() - 1);
	EndDo;
	
	ParameterNameToSave = ValueListToSave;
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupForm(EventHandlersFromRuleFile)
	
	DataProcessorName = Left(FormName, LastSeparator(FormName));
	FormNameToCall = DataProcessorName + "HandlerDebugSetupManagedForm";
	
	FormParameters = New Structure;
	FormParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	FormParameters.Insert("AlgorithmsDebugMode", Object.AlgorithmsDebugMode);
	FormParameters.Insert("ExchangeRulesFileName", Object.ExchangeRulesFileName);
	FormParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	FormParameters.Insert("ReadEventHandlersFromExchangeRulesFile", EventHandlersFromRuleFile);
	FormParameters.Insert("DataProcessorName", DataProcessorName);
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	Handler = New NotifyDescription("OpenHandlerDebugSetupFormCompletion", ThisObject, EventHandlersFromRuleFile);
	
	OpenForm(FormNameToCall, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupFormCompletion(DebugParameters, EventHandlersFromRuleFile) Export
	
	If DebugParameters <> Undefined Then
		
		FillPropertyValues(Object, DebugParameters);
		
		If IsClient Then
			
			If EventHandlersFromRuleFile Then
				
				FileName = Object.ExchangeRulesFileName;
				
			Else
				
				FileName = Object.ExchangeFileName;
				
			EndIf;
			
			Notification = New NotifyDescription("OpenHandlersDebugSettingsFormCompletionFileDeletion", ThisObject);
			BeginDeletingFiles(Notification, FileName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenHandlersDebugSettingsFormCompletionFileDeletion(AdditionalParameters) Export
	
	Return;
	
EndProcedure

&AtClient
Procedure ChangeFileLocation()
	
	Items.RulesFileName.Visible = Not IsClient;
	Items.DataFileName.Visible = Not IsClient;
	Items.ExchangeFileName.Visible = Not IsClient;
	Items.SafeImportGroup.Visible = Not IsClient;
	
	SetImportRuleFlag(False);
	
EndProcedure

&AtClient
Procedure ChangeProcessingMode(WorkMode)
	
	ModeGroup1 = CommandBar.ChildItems.ProcessingMode.ChildItems;
	
	ModeGroup1.FormAtClient.Check = WorkMode;
	ModeGroup1.FormAtServer.Check = Not WorkMode;
	
	CommandBar.ChildItems.ProcessingMode.Title = 
	?(WorkMode, NStr("en = 'Mode (client)';"), NStr("en = 'Mode (server)';"));
	
	Object.ExportRulesTable.GetItems().Clear();
	Object.ParametersSetupTable.Clear();
	
	ChangeFileLocation();
	
EndProcedure

&AtClient
Procedure OpenExchangeProtocolDataIfNecessary()
	
	If Not Object.OpenExchangeProtocolsAfterExecutingOperations Then
		Return;
	EndIf;
	
	#If Not WebClient Then
		
		If Not IsBlankString(Object.ExchangeProtocolFileName) Then
			OpenInApplication(Object.ExchangeProtocolFileName);
		EndIf;
		
		If Object.DirectReadingInDestinationIB Then
			
			Object.ImportExchangeLogFileName = GetProtocolNameForSecondCOMConnectionInfobaseAtServer();
			
			If Not IsBlankString(Object.ImportExchangeLogFileName) Then
				OpenInApplication(Object.ImportExchangeLogFileName);
			EndIf;
			
		EndIf;
		
	#EndIf
	
EndProcedure

&AtServer
Function GetProtocolNameForSecondCOMConnectionInfobaseAtServer()
	
	Return FormAttributeToValue("Object").GetProtocolNameForCOMConnectionSecondInfobase();
	
EndFunction

&AtClient
Function EmptyAttributeValue(Attribute, DataPath, Var_Title)
	
	If IsBlankString(Attribute) Then
		
		MessageText = NStr("en = '""%1"" is required';");
		MessageText = StrReplace(MessageText, "%1", Var_Title);
		
		MessageToUser(MessageText, DataPath);
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

&AtClient
Procedure SetImportRuleFlag(Flag)
	
	RulesAreImported = Flag;
	Items.FormExecuteExport.Enabled = Flag;
	Items.ExportNoteLabel.Visible = Not Flag;
	Items.ExportDebugGroup.Enabled = Flag;
	
EndProcedure

&AtClient
Procedure OnChangeChangesRegistrationDeletionType()
	
	If IsBlankString(ChangesRegistrationDeletionTypeForExportedExchangeNodes) Then
		Object.ChangesRegistrationDeletionTypeForExportedExchangeNodes = 0;
	Else
		Object.ChangesRegistrationDeletionTypeForExportedExchangeNodes = Number(ChangesRegistrationDeletionTypeForExportedExchangeNodes);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

// Returns True if the client application is running on Windows.
//
// Returns:
//  Boolean -  
//
&AtClient
Function IsWindowsClient()
	
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	             Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	Return IsWindowsClient;
	
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
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en = 'The data processor supports 1C:Enterprise 8.3 or later,
			|with disabled compatibility mode.';");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeSafeImportMode(Interactively = True)
	
	Items.SafeImportGroup.Enabled = Object.SafeImport;
	
	ThroughStorage = IsClient;
	#If WebClient Then
		ThroughStorage = True;
	#EndIf
	
	If Object.SafeImport And ThroughStorage Then
		PutImportRulesFileInStorage();
	EndIf;
	
EndProcedure

&AtClient
Procedure PutImportRulesFileInStorage()
	
	ThroughStorage = IsClient;
	#If WebClient Then
		ThroughStorage = True;
	#EndIf
	
	FileAddress = "";
	NotifyDescription = New NotifyDescription("PutImportRulesFileInStorageCompletion", ThisObject);
	
	If ThroughStorage Then
		BeginPutFile(NotifyDescription, FileAddress, , , UUID);
	Else
		BeginPutFile(NotifyDescription, FileAddress, NameOfImportRulesFile, False, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure PutImportRulesFileInStorageCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		ImportRulesFileAddressInStorage = Address;
	EndIf;
	
EndProcedure

#EndRegion