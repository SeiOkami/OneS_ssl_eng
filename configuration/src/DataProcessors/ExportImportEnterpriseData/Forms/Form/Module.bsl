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
	
	AvailableVersionsArray = New Map;
	ExtensionsCollection = New Map;
	Try
		DataExchangeOverridable.OnGetAvailableFormatVersions(AvailableVersionsArray);
		DataExchangeOverridable.OnGetAvailableFormatExtensions(ExtensionsCollection);
	Except
		// Cannot get available format versions.
		Raise NStr("en = 'The infobase does not support universal data synchronization format.';");
	EndTry;
	
	For Each Extension In ExtensionsCollection Do
		ExtensionRow = FormatExtensions.Add();
		ExtensionRow.Namespace = Extension.Key;
		ExtensionRow.BaseVersion    = Extension.Value;
	EndDo;

	DataProcessorObject = FormAttributeToValue("Object");
	FormOpenOption = ?(Parameters.Property("ImportOnly"), "ImportOnly", "");
	
	If FormOpenOption = "ImportOnly" Then
		ThisObject.Title = NStr("en = 'Import EnterpriseData data';");
		Items.LabelExportWithIntegratedDataProcessor.Visible = True;
	Else
		Items.LabelExportWithIntegratedDataProcessor.Visible = False;
		ThisObject.Title = NStr("en = 'Export and import EnterpriseData data';");
	EndIf;
	
	MetaDataProcessorName = DataProcessorObject.Metadata().Name;
	NameParts = StrSplit(FormName, ".");
	
	BaseNameForForm = "DataProcessor." + MetaDataProcessorName;
	DataProcessorName = NameParts[1];
	
	Object.ExportSource = "Filter";
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	FillInTheDefaultFormatVersion(AvailableVersionsArray);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If ValueIsFilled(Object.FormatVersion) Then
		
		If Items.FormatVersion.ChoiceList.FindByValue(Object.FormatVersion) = Undefined Then
			
			AvailableVersionsArray = New Map;
			DataExchangeOverridable.OnGetAvailableFormatVersions(AvailableVersionsArray);
			FillInTheDefaultFormatVersion(AvailableVersionsArray);
			
		Else
			
			RefreshExportRulesAtServer();
			UpdateTheUploadRulesOnTheServer();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If FormOpenOption = "ImportOnly" Then
		OperationKind = "Load";
		DeveloperMode = False;
	EndIf;
	
	If Not ValueIsFilled(OperationKind) Then
		OperationKind = "Load";
	EndIf;
	// value saved by default appears only when the form is opened.
	If ValueIsFilled(Object.PathToExportExchangeManager) Then
		RefreshExportRulesAtServer();
	EndIf;
	SetVisibility1();
#If WebClient Then
	BeginInstallFileSystemExtension();
#EndIf
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OperationKindOnChange(Item)
	SetVisibility1();
EndProcedure

&AtClient
Procedure FormatVersionOnChange(Item)
	If Not ValueIsFilled(Object.FormatVersion) Then
		Return;
	EndIf;
	
	RefreshExportRulesAtServer();
EndProcedure

&AtClient
Procedure FormatVersionDownloadOnChange(Item)
	
	If Not ValueIsFilled(Object.FormatVersion) Then
		Return;
	EndIf;
	
	UpdateTheUploadRulesOnTheServer();
	
EndProcedure

&AtClient
Procedure PathToExportExchangeManagerStartChoice(Item, ChoiceData, StandardProcessing)
	ManagerModuleStartChoice("PathToExportExchangeManager", StandardProcessing, True);
EndProcedure

&AtClient
Procedure PathToImportExchangeManagerStartChoice(Item, ChoiceData, StandardProcessing)
	ManagerModuleStartChoice("PathToImportExchangeManager", StandardProcessing, False);
EndProcedure

&AtClient
Procedure PathToExportExchangeManagerOnChange(Item)
	ExportExchangeManagerPathOnChangeAtServer();
EndProcedure

&AtClient
Procedure ExportRulesTableSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	CurrentData = Items.ExportRulesTable.CurrentData;
	If CurrentData.FullMetadataName = "" Then
		Return;
	EndIf;
	StructureFilter = New Structure("FullMetadataName", CurrentData.FullMetadataName);
	AddRegistrationRows = Object.AdditionalRegistration.FindRows(StructureFilter);
	CurrPeriodChoice = Undefined;
	CurrDataPeriod = Undefined;
	CurrFilter = Undefined;
	
	If AddRegistrationRows.Count() > 0 Then
		CurrPeriodChoice = AddRegistrationRows[0].PeriodSelection;
		CurrDataPeriod = AddRegistrationRows[0].Period;
		CurrFilter = AddRegistrationRows[0].Filter;
	EndIf;
	
	NameOfFormToOpen_ = BaseNameForForm + ".Form.PeriodAndFilterEdit";
	FormParameters = New Structure;
	FormParameters.Insert("Title",           CurrentData.Presentation);
	FormParameters.Insert("PeriodSelection",        CurrPeriodChoice);
	FormParameters.Insert("SettingsComposer", SettingsComposerByTableName(
									CurrentData.FullMetadataName, CurrentData.Presentation, CurrFilter));
	FormParameters.Insert("DataPeriod",        CurrDataPeriod);
	
	FormParameters.Insert("FormStorageAddress", UUID);
	
	OpenForm(NameOfFormToOpen_, FormParameters, Items.ExportRulesTable);
EndProcedure

&AtClient
Procedure ExportRulesTableChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	FullMDName = Items.ExportRulesTable.CurrentData.FullMetadataName;
	CurrentRowID = Items.ExportRulesTable.CurrentData.GetID();
	FilterStringEditingAdditionalCompositionServer(ValueSelected, FullMDName, CurrentRowID);
EndProcedure

&AtClient
Procedure PathToImportFileStartChoice(Item, ChoiceData, StandardProcessing)
	SelectFileForImportAtClient();
EndProcedure

&AtClient
Procedure ExportFilePathStartChoice(Item, ChoiceData, StandardProcessing)
	SelectFileForExportAtClient();
EndProcedure

&AtClient
Procedure ImportSourceOnChange(Item)
	SetVisibility1();
EndProcedure

&AtClient
Procedure ExportLocationOnChange(Item)
	SetVisibility1();
EndProcedure

&AtClient
Procedure ExportSourceOnChange(Item)
	SetVisibility1();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteOperation(Command)
	JobID = Undefined;
	
	If OperationKind = "Load" Then
		If ImportSource = 1 Then // A text field.
			If Not ValueIsFilled(DataForXDTOImport) Then
				CommonClient.MessageToUser(NStr("en = 'Please specify the data to import.';"));
				Return;
			EndIf;
		Else
			If Not ValueIsFilled(PathToImportFile) Then
				SelectFileForImportAtClient(True);
				Return;
			EndIf;
		EndIf;
		
		AttachIdleHandler("ImportMessage", 0.1, True);
	Else
		AttachIdleHandler("ExportData", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure AbortExportImport(Command)
	If JobID = Undefined Then
		Return;
	EndIf;
	AbortExportImportServer();
	JobID = Undefined;
	Items.ExportImport.CurrentPage = ?(OperationKind = "Load", Items.Load, Items.Upload0);
	SetVisibilityAvailabilityOfButtons(True);
	Message = New UserMessage();
	Message.Text = NStr("en = 'The operation is canceled.';");
	Message.Message();

EndProcedure

&AtClient
Procedure SaveXML(Command)
	FileAddressInStorage = SaveXMLAtServer();
	If ValueIsFilled(ExportFilePath) Then
		WriteExportResultToFile(FileAddressInStorage);
	Else
		SelectFileForExportAtClient(True, FileAddressInStorage);
	EndIf;
EndProcedure

&AtClient
Procedure OpenXML(Command)
	
	AdditionalParameters = New Structure("FileKind", "DataFile");
	Notification = New NotifyDescription("PutFileInStorageComplete", ThisObject, AdditionalParameters);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	
	If ValueIsFilled(PathToImportFile) Then
		ImportParameters.Interactively = False;
		FileSystemClient.ImportFile_(Notification, ImportParameters, PathToImportFile);
	Else
		ImportParameters.FormIdentifier = UUID;
		ImportParameters.Dialog.Filter = "Files XML (*.xml)|*.xml";
		
		FileSystemClient.ImportFile_(Notification, ImportParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShouldSaveSettings(Command)
	
	FileAddressInStorage = SaveExportSettingsAtServer();
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Filter = "Files XML (*.xml)|*.xml";

	FileSystemClient.SaveFile(
		Undefined,
		FileAddressInStorage,
		NStr("en = 'Export settings file.xml';"),
		SavingParameters);
	
EndProcedure

&AtClient
Procedure RestoreSettings(Command)
	
	AdditionalParameters = New Structure("FileKind", "SettingsFile");
	Notification = New NotifyDescription("PutFileInStorageComplete", ThisObject, AdditionalParameters);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Filter = "Files XML (*.xml)|*.xml";
	
	FileSystemClient.ImportFile_(Notification, ImportParameters);
	
EndProcedure

&AtClient
Procedure EnableDeveloperMode(Command)
	
	DeveloperMode = Not DeveloperMode;
	UseDataExchangeMessageDirectory = ?(DeveloperMode, UseDataExchangeMessageDirectory, False);
	ImportSource = ?(DeveloperMode, ImportSource, 0);
	ExportLocation = ?(DeveloperMode, ExportLocation, 0);
	Object.ExportSource = ?(DeveloperMode, Object.ExportSource, "Filter");
	SetVisibility1();
	
EndProcedure

&AtClient
Procedure UseInternalMessageDirectory(Command)
	
	Items.FormUseInternalMessageDirectory.Check = Not Items.FormUseInternalMessageDirectory.Check;
	UseDataExchangeMessageDirectory = Items.FormUseInternalMessageDirectory.Check;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportMessage()
	
	Items.TimeConsumingOperationNoteTextDecoration.Title = NStr("en = 'Importing data…';");
	Items.ExportImport.CurrentPage = Items.Waiting;
	
	SetVisibilityAvailabilityOfButtons(False);
	
	If ImportSource = 1 Then
		StartDataImport();
	Else
		ImportFromFileAtClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartDataImport()
	ArrayOfMessages = Undefined;
	TimeConsumingOperation = ImportDataAtServer();
	JobID = TimeConsumingOperation.JobID;
	If TimeConsumingOperation.Status = "Completed2" Then
		TimeConsumingOperation.Property("Messages", ArrayOfMessages);
		ReportOperationEnd(True);
	Else
		ModuleTimeConsumingOperationsClient = CommonClient.CommonModule("TimeConsumingOperationsClient");
		IdleParameters = ModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		
		NotifyDescription = New NotifyDescription("OnCompleteImport", ThisObject);
		ModuleTimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	EndIf;

EndProcedure

&AtClient
Procedure OnCompleteImport(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Raise NStr("en = 'Cannot import data.';");
	ElsIf Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	ReportOperationEnd(True);
EndProcedure

&AtClient
Procedure ExportData()
	Items.TimeConsumingOperationNoteTextDecoration.Title = NStr("en = 'Exporting data…';");
	Items.ExportImport.CurrentPage = Items.Waiting;
	SetVisibilityAvailabilityOfButtons(False);
	ArrayOfMessages = Undefined;
	TimeConsumingOperation = ExportDataAtServer();
	JobID = TimeConsumingOperation.JobID;
	If TimeConsumingOperation.Status = "Completed2" Then
		ResultStorageAddress = TimeConsumingOperation.ResultAddress;
		TimeConsumingOperation.Property("Messages", ArrayOfMessages);
		ProcessExportResult();
	Else
		ModuleTimeConsumingOperationsClient = CommonClient.CommonModule("TimeConsumingOperationsClient");
		IdleParameters = ModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		
		NotifyDescription = New NotifyDescription("OnCompleteExport", ThisObject);
		ModuleTimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	EndIf;
EndProcedure

&AtClient
Procedure OnCompleteExport(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Raise NStr("en = 'Cannot export data. The export result is missing.';");
	ElsIf Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	ResultStorageAddress = Result.ResultAddress;
	ProcessExportResult();
EndProcedure

&AtClient
Procedure ProcessExportResult()
	If ExportLocation = 1 Then
		Object.XDTOExportResult = GetFromTempStorage(ResultStorageAddress);
		ReportOperationEnd(False);
	Else
		If Not ValueIsFilled(ExportFilePath) Then
			// After the file is selected, the export result will be written to it.
			SelectFileForExportAtClient(True, ResultStorageAddress);
		Else
			WriteExportResultToFile(ResultStorageAddress);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure WriteExportResultToFile(ResultStorageAddress)
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Interactively = False;

	FileSystemClient.SaveFile(
		New NotifyDescription("WriteExportResultToFileCompletion", ThisObject),
		ResultStorageAddress,
		ExportFilePath,
		SavingParameters);
	
EndProcedure

// Parameters:
//   ObtainedFiles - Array of TransferredFileDescription
//                   - Undefined - 
//   AdditionalParameters - Arbitrary - arbitrary additional parameters.
// 
&AtClient
Procedure WriteExportResultToFileCompletion(ObtainedFiles, AdditionalParameters) Export
	
	If ObtainedFiles = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ExportFilePath) Then
		ExportFilePath = ObtainedFiles.Get(0).Name;
	EndIf;
	ReportOperationEnd(False);
	
EndProcedure

&AtClient
Procedure SelectFileForImportAtClient(ImportAfterChoice = False)
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.Filter = NStr("en = 'Import data (*.xml)|*.xml';");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ForImport",          True);
	AdditionalParameters.Insert("ImportAfterChoice", ImportAfterChoice);
	
	ChoiceNotification = New NotifyDescription("FileSelected", ThisObject, AdditionalParameters);
	
	FileSystemClient.ShowSelectionDialog(ChoiceNotification, OpenFileDialog);
	
EndProcedure

&AtClient
Procedure SelectFileForExportAtClient(ExportAfterChoice = False, ResultStorageAddress = "")
	
	OpenFileDialog = New FileDialog(FileDialogMode.Save);
	OpenFileDialog.Filter = NStr("en = 'Export data (*.xml)|*.xml';");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ForImport",             False);
	AdditionalParameters.Insert("ExportAfterChoice",    ExportAfterChoice);
	AdditionalParameters.Insert("ResultStorageAddress", ResultStorageAddress);
	
	ChoiceNotification = New NotifyDescription("FileSelected", ThisObject, AdditionalParameters);
	
	FileSystemClient.ShowSelectionDialog(ChoiceNotification, OpenFileDialog);
	
EndProcedure

&AtClient
Procedure PutFileInStorageComplete(FileThatWasPut, AdditionalParameters) Export
	
	ImportFileAddress = "";
	If FileThatWasPut = Undefined Then
		
		Return;
		
	EndIf;
	
	ImportFileAddress = FileThatWasPut.Location;
	If AdditionalParameters.FileKind = "DataFile" Then
		
		OpenXMLAtServer();
		
	ElsIf AdditionalParameters.FileKind = "DataFileToImport" Then
		
		StartDataImport();
		
	ElsIf AdditionalParameters.FileKind = "SettingsFile" Then
		
		ImportExportSettingsAtServer();
		Items.ExportRulesTable.InitialTreeView = InitialTreeView.ExpandTopLevel;
		
	EndIf;
	
EndProcedure

&AtServer
Function ExportDataAtServer()
	AddFilterDataIfNecessary();
	ResultStorageAddress = "";
	DataProcessorObject = FormAttributeToValue("Object");
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ExportLocation", ExportLocation);
	ParametersStructure.Insert("IsBackgroundJob", True);
	ParametersStructure.Insert("PathToExportExchangeManager", DataProcessorObject.PathToExportExchangeManager);
	ParametersStructure.Insert("FormatVersion", DataProcessorObject.FormatVersion);
	ParametersStructure.Insert("FormatExtension", DataProcessorObject.FormatExtension);
	ParametersStructure.Insert("ExchangeNode", DataProcessorObject.ExchangeNode);
	ParametersStructure.Insert("AllDocumentsFilterPeriod", DataProcessorObject.AllDocumentsFilterPeriod);
	ParametersStructure.Insert("AdditionalRegistration", DataProcessorObject.AdditionalRegistration);

	JobParameters = New Structure;
	JobParameters.Insert("DataProcessorName", DataProcessorName);
	JobParameters.Insert("MethodName", "ExportToXMLResult");
	JobParameters.Insert("ExecutionParameters", ParametersStructure);
	JobParameters.Insert("IsExternalDataProcessor", False);

	MethodToExecute = "TimeConsumingOperations.RunDataProcessorObjectModuleProcedure";

	ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
	ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Export EnterpriseData data';");
	BackgroundJobResult = ModuleTimeConsumingOperations.ExecuteInBackground(MethodToExecute, JobParameters, ExecutionParameters);
	Return BackgroundJobResult;
EndFunction

&AtServer
Function ImportDataAtServer()
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	ParametersStructure = New Structure;
	If ImportSource = 1 Then
		
		ParametersStructure.Insert("XMLText", DataForXDTOImport);
		
	Else
		
		BinaryData = GetFromTempStorage(ImportFileAddress); // BinaryData
		If UseDataExchangeMessageDirectory = True Then
			
			TempFilesStorageDirectory = DataExchangeCached.TempFilesStorageDirectory();
			AddressOnServer = CommonClientServer.GetFullFileName(
				TempFilesStorageDirectory, String(New UUID) + ".xml")
			
		Else
			
			AddressOnServer = GetTempFileName("xml");
			// 
			// 
			
		EndIf;
		
		BinaryData.Write(AddressOnServer);
		DeleteFromTempStorage(ImportFileAddress);
		ParametersStructure.Insert("AddressOnServer", AddressOnServer);
		
	EndIf;
	
	ParametersStructure.Insert("PathToImportExchangeManager", DataProcessorObject.PathToImportExchangeManager);
	ParametersStructure.Insert("FormatVersion", DataProcessorObject.FormatVersion);
	ParametersStructure.Insert("IsBackgroundJob", True);
	
	JobParameters = New Structure;
	JobParameters.Insert("DataProcessorName", DataProcessorName);
	JobParameters.Insert("MethodName", "MessageImport");
	JobParameters.Insert("ExecutionParameters", ParametersStructure);
	JobParameters.Insert("IsExternalDataProcessor", False);
	
	MethodToExecute = "TimeConsumingOperations.RunDataProcessorObjectModuleProcedure";
	
	ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
	ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Import EnterpriseData data';");
	BackgroundJobResult = ModuleTimeConsumingOperations.ExecuteInBackground(MethodToExecute, JobParameters, ExecutionParameters);
	Return BackgroundJobResult;

EndFunction

&AtServer
Procedure AddFilterDataIfNecessary()
	If Object.ExportSource = "Node" Then
		TreeRows = Object.ExportRulesTable.GetItems();
		TreeRows.Clear();
		Object.AdditionalRegistration.Clear();
		Return;
	Else
		Object.ExchangeNode = Undefined;
	EndIf;
	
	For Each MetadataGroupString In Object.ExportRulesTable.GetItems() Do
		For Each MetadataString In MetadataGroupString.GetItems() Do
			FullMDName = MetadataString.FullMetadataName;
			AdditionStrings = Object.AdditionalRegistration.FindRows(New Structure("FullMetadataName", FullMDName));
			If MetadataString.Enable = False Then
				If AdditionStrings.Count() > 0 Then
					MetadataString.FilterPresentation = "";
					TotalRows = AdditionStrings.Count();
					For Counter = 1 To TotalRows Do
						Object.AdditionalRegistration.Delete(AdditionStrings[TotalRows-Counter]);
					EndDo;
				EndIf;
			ElsIf AdditionStrings.Count() = 0 Then
				NewString = Object.AdditionalRegistration.Add();
				FillPropertyValues(NewString, MetadataString, "FullMetadataName, Presentation");
				NewString.FilterAsString = NStr("en = 'All objects';");
				NewString.PeriodSelection = MetadataString.FilterByPeriod;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure ManagerModuleStartChoice(ManagerModuleAttribute, StandardProcessing, UpdateExport)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ManagerModule",   True);
	AdditionalParameters.Insert("AttributeName",      ManagerModuleAttribute);
	AdditionalParameters.Insert("UpdateExport", UpdateExport);
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.Filter = NStr("en = 'External data processor (*.epf)|*.epf';");
	
	ChoiceNotification = New NotifyDescription("FileSelected", ThisObject, AdditionalParameters);
		
	FileSystemClient.ShowSelectionDialog(ChoiceNotification, OpenFileDialog);
	
EndProcedure

&AtServer
Function SaveXMLAtServer()
	TX = New TextDocument;
	TX.SetText(Object.XDTOExportResult);
	AddressOnServer = GetTempFileName("xml");
	TX.Write(AddressOnServer);
	AddressInStorage = PutToTempStorage(New BinaryData(AddressOnServer));
	DeleteFiles(AddressOnServer);
	Return AddressInStorage;
EndFunction

&AtServer
Procedure OpenXMLAtServer()
	BinaryData = GetFromTempStorage(ImportFileAddress); // BinaryData
	AddressOnServer = GetTempFileName("xml");
	BinaryData.Write(AddressOnServer);
	TX = New TextDocument;
	TX.Read(AddressOnServer);
	DataForXDTOImport = TX.GetText();
	DeleteFiles(AddressOnServer);
EndProcedure

&AtServer
Function SaveExportSettingsAtServer()
	AddFilterDataIfNecessary();
	TempFileName1 = GetTempFileName("xml");

	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFileName1);
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Objects");
	If ValueIsFilled(Object.AllDocumentsFilterPeriod) Then
		XMLWriter.WriteStartElement("Period");
		XMLWriter.WriteAttribute("Beg", XMLString(Object.AllDocumentsFilterPeriod.StartDate));
		XMLWriter.WriteAttribute("End", XMLString(Object.AllDocumentsFilterPeriod.EndDate));
		XMLWriter.WriteEndElement(); //Period
	EndIf;
	For Each Page1 In Object.AdditionalRegistration Do
		XMLWriter.WriteStartElement("Object");
		XMLWriter.WriteAttribute("Type", XMLString(Page1.FullMetadataName));
		If Page1.PeriodSelection Then
			XMLWriter.WriteAttribute("Sel_Period", XMLString(Page1.PeriodSelection));
			If ValueIsFilled(Page1.Period) Then
				XMLWriter.WriteAttribute("Beg_Period", XMLString(Page1.Period.StartDate));
				XMLWriter.WriteAttribute("End_Period", XMLString(Page1.Period.EndDate));
			EndIf;
		EndIf;
		XMLWriter.WriteAttribute("F_String", XMLString(Page1.FilterAsString));
		If Page1.Filter.Items.Count() > 0 Then
			
			For Each FilterElement In Page1.Filter.Items Do
				XMLWriter.WriteStartElement("Filter");
				XMLWriter.WriteAttribute("Comp", XMLString(TrimAll(FilterElement.ComparisonType)));
				XMLWriter.WriteAttribute("Present", XMLString(TrimAll(FilterElement.Presentation)));
				
				If ValueIsFilled(FilterElement.LeftValue) Then
					WriteFilterValue(FilterElement.LeftValue, "_L", XMLWriter)
				EndIf;
				
				If ValueIsFilled(FilterElement.RightValue) Then
					
					If TypeOf(FilterElement.RightValue) = Type("ValueList") Then
						
						RecordMultipleSelectionValue(FilterElement.RightValue, "_R", XMLWriter)
						
					Else
						
						WriteFilterValue(FilterElement.RightValue, "_R", XMLWriter)
						
					EndIf;
					
				EndIf;
				
				XMLWriter.WriteEndElement();//Filter
			EndDo;
			
		EndIf;
		XMLWriter.WriteEndElement(); //Object
	EndDo;
	XMLWriter.WriteEndElement(); //Objects
	XMLWriter.Close();
	AddressInStorage = PutToTempStorage(New BinaryData(TempFileName1));
	DeleteFiles(TempFileName1);
	Return AddressInStorage;
EndFunction

&AtServer
Procedure RecordMultipleSelectionValue(Val FilterItemValue, Postfix, XMLWriter)
	
	XMLWriter.WriteAttribute("Type" + Postfix,  String(TypeOf(FilterItemValue)));
	
	For Each ValueListItem In FilterItemValue Do
		
		XMLWriter.WriteStartElement("Array");
		WriteFilterValue(ValueListItem.Value, Postfix, XMLWriter);
		XMLWriter.WriteEndElement();
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteFilterValue(Val FilterItemValue, Postfix, XMLWriter)
	DataType = TypeOf(FilterItemValue);
	MetadataObject =  Metadata.FindByType(DataType);
	
	If MetadataObject <> Undefined Then
		XMLWriter.WriteAttribute("Type" + Postfix,  MetadataObject.FullName());
	Else 
		XMLWriter.WriteAttribute("Type" + Postfix,  String(DataType));
	EndIf;
	If XMLType(DataType) <> Undefined Then
		XMLWriter.WriteAttribute("Val" + Postfix, XMLString(FilterItemValue));
	Else
		XMLWriter.WriteAttribute("Val" + Postfix, XMLString(String(FilterItemValue)));
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibility1()
	Items.FormAbort.Visible = False;
	// 
	Items.ExportImport.CurrentPage = ?(OperationKind = "Load", Items.Load, Items.Upload0);
	// A limited option of using the data processor.
	If ValueIsFilled(FormOpenOption) Then
		Items.FormEnableAdvancedFeatures.Visible = False;
		Items.OperationKind.Visible = False;
		Items.PathToImportExchangeManager.Visible = False;
		Items.DataForImportGroup.Visible = False;
		Items.ImportSource.Visible = False;
		Return;
	EndIf;
	If OperationKind = "Upload0" Then
		Items.ExchangeNode.Visible = (DeveloperMode And Object.ExportSource = "Node");
		Items.FiltersSettingsGroup.Visible = (Object.ExportSource = "Filter");
		Items.ExportRulesTable.Visible = (Object.ExportSource = "Filter");
		Items.PathToExportExchangeManager.Visible = DeveloperMode And Not DataSeparationEnabled;
		Items.ExportSource.Visible = DeveloperMode;
		Items.ExportLocation.Visible = DeveloperMode;
		Items.ExportResult.Visible = ExportLocation = 1;
		Items.ExportFilePath.Visible = ExportLocation <> 1;
		Items.ExportMain.PagesRepresentation = ?(ExportLocation = 1, FormPagesRepresentation.TabsOnTop, FormPagesRepresentation.None);
	Else
		Items.FormUseInternalMessageDirectory.Visible = DeveloperMode;
		Items.PathToImportExchangeManager.Visible = DeveloperMode And Not DataSeparationEnabled;
		Items.ImportSource.Visible = DeveloperMode;
		Items.DataForImportGroup.Visible = (ImportSource = 1);
		Items.PathToImportFile.Visible = (ImportSource <> 1);
	EndIf;
	Items.FormEnableAdvancedFeatures.Check = DeveloperMode;
EndProcedure

&AtServer
Procedure RefreshExportRulesAtServer()
	
	Items.FormatExtension.ChoiceList.Clear();
	Items.FormatExtension.ChoiceList.Add("", NStr("en = '<without extension>';"));
	For Each Extension In FormatExtensions.FindRows(New Structure("BaseVersion", Object.FormatVersion)) Do
		Items.FormatExtension.ChoiceList.Add(Extension.Namespace);
	EndDo;
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.FillExportRules();
	ValueToFormAttribute(DataProcessorObject, "Object");
EndProcedure

&AtServer
Procedure UpdateTheUploadRulesOnTheServer()
	
	Items.FormatExtensionImport.ChoiceList.Clear();
	Items.FormatExtensionImport.ChoiceList.Add("", NStr("en = '<without extension>';"));
	For Each Extension In FormatExtensions.FindRows(New Structure("BaseVersion", Object.FormatVersion)) Do
		
		Items.FormatExtensionImport.ChoiceList.Add(Extension.Namespace);
		
	EndDo;
	
EndProcedure

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.FilterPresentation(Period, Filter);
EndFunction

&AtServer 
Procedure FilterStringEditingAdditionalCompositionServer(ChoiceStructure, FullMDName, CurRowID)
	AddRegistrationData = Object.AdditionalRegistration.FindRows(
		New Structure("FullMetadataName", FullMDName));
	CurrentData = Object.ExportRulesTable.FindByID(CurRowID);
	If AddRegistrationData.Count() = 0 Then
		String = Object.AdditionalRegistration.Add();
		FillPropertyValues(String, CurrentData,"FullMetadataName, Presentation");
		FillString = String;
	Else
		FillString = AddRegistrationData[0];
	EndIf;
	
	FillString.Period       = ChoiceStructure.DataPeriod;
	FillString.Filter        = ChoiceStructure.SettingsComposer.Settings.Filter;
	FillString.FilterAsString = FilterPresentation(FillString.Period, FillString.Filter);
	
	CurrentData.FilterPresentation = FillString.FilterAsString;
	CurrentData.Enable = True;
EndProcedure

&AtClient
Procedure TableOfUploadRulesIncludeOnChange(Item)
	CurrentRowData = Items.ExportRulesTable.CurrentData;
	If CurrentRowData.GetItems().Count() > 0 Then
		For Each Page1 In CurrentRowData.GetItems() Do
			Page1.Enable = CurrentRowData.Enable;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure ExportExchangeManagerPathOnChangeAtServer()
	RefreshExportRulesAtServer();
EndProcedure

&AtClient
Procedure FileSelected(SelectedFiles, AdditionalParameters) Export
	
	If Not ValueIsFilled(SelectedFiles) Then
		Return;
	EndIf;
	
	If AdditionalParameters.Property("ForImport") Then
		If AdditionalParameters.ForImport Then
			PathToImportFile = SelectedFiles[0];
			// Check whether the file exists.
			If AdditionalParameters.ImportAfterChoice Then
				AttachIdleHandler("ImportMessage", 0.1, True);
			EndIf;
		Else
			ExportFilePath = SelectedFiles[0];
			If AdditionalParameters.ExportAfterChoice Then
				WriteExportResultToFile(AdditionalParameters.ResultStorageAddress);
			EndIf;
		EndIf;
	ElsIf AdditionalParameters.Property("ManagerModule") Then
		Object[AdditionalParameters.AttributeName] = SelectedFiles[0];
		If AdditionalParameters.UpdateExport Then
			ExportExchangeManagerPathOnChangeAtServer();
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ImportFromFileAtClient()
	
	AdditionalParameters = New Structure("FileKind", "DataFileToImport");
	Notification = New NotifyDescription("PutFileInStorageComplete", ThisObject, AdditionalParameters);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	
	If ValueIsFilled(PathToImportFile) Then
		ImportParameters.Interactively = False;
		FileSystemClient.ImportFile_(Notification, ImportParameters, PathToImportFile);
	Else
		ImportParameters.FormIdentifier = UUID;
		ImportParameters.Dialog.Filter = "Files XML (*.xml)|*.xml";
		
		FileSystemClient.ImportFile_(Notification, ImportParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportOperationEnd(Load = False)
	OutputBackgroundJobMessages();
	JobID = Undefined;
	Items.ExportImport.CurrentPage = ?(Load, Items.Load, Items.Upload0);
	SetVisibilityAvailabilityOfButtons(True);
	Message = New UserMessage();
	If Load Then
		Message.Text = NStr("en = 'Data import completed.';");
	Else
		Message.Text = NStr("en = 'Data has been exported.';");
	EndIf;
	Message.Message();
EndProcedure

&AtClient
Procedure SetVisibilityAvailabilityOfButtons(FlagEnabled)
	Items.UpperGroup.Visible = FlagEnabled;
	Items.FormExecuteOperation.Visible = FlagEnabled;
	Items.FormEnableAdvancedFeatures.Enabled = FlagEnabled;
	Items.FormAbort.Visible = Not FlagEnabled;
EndProcedure

&AtClient
Procedure OutputBackgroundJobMessages()
	If Not ValueIsFilled(ArrayOfMessages) Then
		ArrayOfMessages = ReadBackgroundJobMessages(JobID);
	EndIf;
	If ValueIsFilled(ArrayOfMessages) Then
		For Each CurrMessage In ArrayOfMessages Do
			If StrStartsWith(CurrMessage.Text,"{") Then
				Continue;
			EndIf;
			CurrMessage.Message();
		EndDo;
	EndIf;
EndProcedure

&AtServerNoContext
Function ReadBackgroundJobMessages(Id)
	If Not ValueIsFilled(Id) Then
		Return Undefined;
	EndIf;
	Job = BackgroundJobs.FindByUUID(Id);
	If Job = Undefined Then
		Return Undefined;
	EndIf;
	
	Return Job.GetUserMessages(True);
EndFunction

&AtServerNoContext
Function ComplianceOfSKDSelections()
	
	MatchingSelections = New Map;
	MatchingSelections.Insert("Greater", DataCompositionComparisonType.Greater);
	MatchingSelections.Insert("Greater or equal", DataCompositionComparisonType.GreaterOrEqual);
	MatchingSelections.Insert("In group_ssly", DataCompositionComparisonType.InHierarchy);
	MatchingSelections.Insert("In list_ssly", DataCompositionComparisonType.InList);
	MatchingSelections.Insert("In group_ssly from_ssly list0", DataCompositionComparisonType.InListByHierarchy);
	MatchingSelections.Insert("Filled", DataCompositionComparisonType.Filled);
	MatchingSelections.Insert("Less", DataCompositionComparisonType.Less);
	MatchingSelections.Insert("Less or equal", DataCompositionComparisonType.LessOrEqual);
	MatchingSelections.Insert("Begins From1", DataCompositionComparisonType.BeginsWith);
	MatchingSelections.Insert("Not In group_ssly", DataCompositionComparisonType.NotInHierarchy);
	MatchingSelections.Insert("Not In list_ssly", DataCompositionComparisonType.NotInList);
	MatchingSelections.Insert("Not In group_ssly from_ssly list0", DataCompositionComparisonType.NotInListByHierarchy);
	MatchingSelections.Insert("Not filled", DataCompositionComparisonType.NotFilled);
	MatchingSelections.Insert("Not begins From1", DataCompositionComparisonType.NotBeginsWith);
	MatchingSelections.Insert("Not respond template_ssly", DataCompositionComparisonType.NotLike);
	MatchingSelections.Insert("Not equal", DataCompositionComparisonType.NotEqual);
	MatchingSelections.Insert("Not contains", DataCompositionComparisonType.NotContains);
	MatchingSelections.Insert("Respond template_ssly", DataCompositionComparisonType.Like);
	MatchingSelections.Insert("Equal", DataCompositionComparisonType.Equal);
	MatchingSelections.Insert("Contains", DataCompositionComparisonType.Contains);
	
	Return MatchingSelections;
	
EndFunction

&AtServer
Procedure AbortExportImportServer()
	ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
	ModuleTimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

&AtServer
Procedure FillInTheDefaultFormatVersion(AvailableVersionsArray)
	
	If AvailableVersionsArray.Count() = 0 Then
		
		StringSupportedFormatVersions = NStr("en = 'No supported format versions are found.';", Common.DefaultLanguageCode());
		
		Items.FormExecuteOperation.Enabled = False;
		Items.StringSupportedFormatVersions.TextColor = StyleColors.ErrorNoteText;
		
	Else
		
		Items.FormatVersion.ChoiceList.Clear();
		
		VersionsListPresentation = "";
		For Each ArrayElement In AvailableVersionsArray Do
			
			VersionsListPresentation = VersionsListPresentation + "; " + ArrayElement.Key;
			Items.FormatVersion.ChoiceList.Add(ArrayElement.Key);
			
		EndDo;
		
		VersionsListPresentation = Mid(VersionsListPresentation, 3);
		StringSupportedFormatVersions = StrTemplate(NStr("en = 'Supported format versions: %1';"), VersionsListPresentation);
		Object.FormatVersion = Items.FormatVersion.ChoiceList[AvailableVersionsArray.Count()-1].Value;
		
		RefreshExportRulesAtServer();
		UpdateTheUploadRulesOnTheServer();
		
	EndIf;
	
EndProcedure

#Region LoadingTheUploadSettings

&AtServer
Function MultipleSelectionValue(XMLReader, ValueTypeFilter, FilterValue)
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.Name <> "Array" Then
			
			Continue;
			
		EndIf;
		
		ElementSelectionValue = Undefined;
		TypeOfElementSelectionValue = Undefined;
		While XMLReader.ReadAttribute() Do
		
			If XMLReader.Name = "Val_R" Then
				
				ElementSelectionValue = XMLReader.Value;
				
			ElsIf XMLReader.Name = "Type_R" Then
				
				TypeOfElementSelectionValue = XMLReader.Value;
				
			EndIf;
			
		EndDo;
		
		FilterValue.Add(SingleValueOfSelection(TypeOfElementSelectionValue, ElementSelectionValue));
		
	EndDo;
	
	Return FilterValue;
	
EndFunction

&AtServer
Function SingleValueOfSelection(ValueTypeFilter, FilterValue)
	
	FullFilterItemName = Metadata.FindByFullName(ValueTypeFilter);
	If FullFilterItemName <> Undefined Then
		
		FilterObjectManager = Common.ObjectManagerByFullName(ValueTypeFilter);
		If StrFind(Upper(ValueTypeFilter), "ENUM") > 0 Then
			
			Return FilterObjectManager[FilterValue];
			
		Else
			
			Return FilterObjectManager.GetRef(New UUID(FilterValue));
			
		EndIf;
		
	Else
		
		Return XMLValue(Type(ValueTypeFilter), FilterValue);
		
	EndIf;
	
EndFunction

&AtServer
Function BringTheSelectionValueToTheValueOfTheSKD(XMLReader, ValueTypeFilter, FilterValue)
	
	If ValueTypeFilter = Type("ValueList") Then
		
		FilterValue = New ValueList;
		Return MultipleSelectionValue(XMLReader, ValueTypeFilter, FilterValue);
		
	ElsIf FilterValue <> Undefined Then
		
		Return SingleValueOfSelection(ValueTypeFilter, FilterValue);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

&AtServer
Procedure ReadThePeriodValue(XMLReader)
	
	While XMLReader.ReadAttribute() Do
		
		If XMLReader.Name = "Beg" Then
			
			Object.AllDocumentsFilterPeriod.StartDate = XMLValue(Type("Date"), XMLReader.Value);
			
		ElsIf XMLReader.Name = "End" Then
			
			Object.AllDocumentsFilterPeriod.EndDate = XMLValue(Type("Date"), XMLReader.Value);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ReadAnObjectTypeValue(XMLReader, ANewLineOfSelectionOfSKD)
	
	ANewLineOfSelectionOfSKD = Object.AdditionalRegistration.Add();
	
	While XMLReader.ReadAttribute() Do
		
		If XMLReader.Name = "Type" Then
			
			ANewLineOfSelectionOfSKD.FullMetadataName = XMLValue(Type("String"), XMLReader.Value);
			
		ElsIf XMLReader.Name = "Sel_Period" Then
			
			ANewLineOfSelectionOfSKD.PeriodSelection = XMLValue(Type("Boolean"), XMLReader.Value);
			
		ElsIf XMLReader.Name = "Beg_Period" Then
			
			ANewLineOfSelectionOfSKD.Period.StartDate = XMLValue(Type("Date"), XMLReader.Value);
			 
		ElsIf XMLReader.Name = "End_Period" Then
			
			ANewLineOfSelectionOfSKD.Period.EndDate = XMLValue(Type("Date"), XMLReader.Value);
			
		ElsIf XMLReader.Name = "F_String" Then
			
			ANewLineOfSelectionOfSKD.FilterAsString = XMLValue(Type("String"), XMLReader.Value);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ReadTheValueOfSKDSelections(XMLReader, FIlterRow)
	
	ComplianceOfSKDSelections = ComplianceOfSKDSelections();
	
	ValueTypeFilter = Undefined;
	FilterValue = Undefined;
	While XMLReader.ReadAttribute() Do
		
		If XMLReader.Name = "Present" Then
		
			FIlterRow.Presentation = XMLValue(Type("String"), XMLReader.Value);
			
		ElsIf XMLReader.Name = "Comp" Then
			
			PageComparisonType = TrimAll(XMLValue(Type("String"), XMLReader.Value));
			If ValueIsFilled(PageComparisonType) Then
				
				FIlterRow.ComparisonType = ComplianceOfSKDSelections[PageComparisonType];
				
			EndIf;
			
		ElsIf XMLReader.Name = "Val_L" Then
			
			FIlterRow.LeftValue = New DataCompositionField(TrimAll(XMLValue(Type("String"), XMLReader.Value)));
			
		ElsIf XMLReader.Name = "Val_R" Then
			
			FilterValue = XMLReader.Value;
			
		ElsIf XMLReader.Name = "Type_R" Then
			
			ValueTypeFilter = XMLReader.Value;
			If TrimAll(Type("ValueList")) = ValueTypeFilter Then
				
				ValueTypeFilter = Type("ValueList");
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	FIlterRow.RightValue = BringTheSelectionValueToTheValueOfTheSKD(XMLReader, ValueTypeFilter, FilterValue);
	
EndProcedure

&AtServer
Procedure ImportExportSettingsAtServer()
	
	BinaryData = GetFromTempStorage(ImportFileAddress); // BinaryData
	FileNameAtServer = GetTempFileName("xml");
	BinaryData.Write(FileNameAtServer);

	Object.AdditionalRegistration.Clear();
	Object.AllDocumentsFilterPeriod = New StandardPeriod;
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FileNameAtServer);
	
	ANewLineOfSelectionOfSKD = Undefined;
	While XMLReader.Read() Do
		
		If XMLReader.NodeType <> XMLNodeType.StartElement Then
			
			Continue;
			
		EndIf;
		
		If XMLReader.Name = "Period" Then
			
			ReadThePeriodValue(XMLReader)
			
		ElsIf XMLReader.Name = "Object" Then
			
			ReadAnObjectTypeValue(XMLReader, ANewLineOfSelectionOfSKD);
		
		ElsIf XMLReader.Name = "Filter" Then
			
			FilterDCS = ANewLineOfSelectionOfSKD.Filter; // DataCompositionFilter
			FIlterRow = FilterDCS.Items.Add(Type("DataCompositionFilterItem"));
			
			ReadTheValueOfSKDSelections(XMLReader, FIlterRow);
			
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	DeleteFiles(FileNameAtServer);
	
	RefreshExportRulesAtServer();

EndProcedure

#EndRegion

#EndRegion