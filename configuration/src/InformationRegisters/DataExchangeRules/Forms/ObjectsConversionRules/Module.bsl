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
	
	UpdateExchangePlanChoiceList();
	
	UpdateRuleTemplateChoiceList();
	
	UpdateRuleInfo();
	
	RulesSource = ?(Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate,
		"StandardRulesFromConfiguration", "RuelsImportedFromFile");
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.DebugSettingsGroup.Enabled = Record.DebugMode;
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	DataExchangeRulesImportEventLogEvent = DataExchangeServer.DataExchangeRulesImportEventLogEvent();
	
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If RulesSource = "RuelsImportedFromFile" And IsBlankString(Record.RulesFileName) Then
		
		MessageString = NStr("en = 'Exchange rule file is not specified.';");
		CommonClient.MessageToUser(MessageString,,,, HasBlankFields);
		
	EndIf;
	
	If Record.DebugMode Then
		
		If Record.ExportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified';");
				CommonClient.MessageToUser(MessageString,, "Record.ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.ImportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified';");
				CommonClient.MessageToUser(MessageString,, "Record.ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.DataExchangeLoggingMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'Exchange protocol file name is not specified.';");
				CommonClient.MessageToUser(MessageString,, "Record.ExchangeProtocolFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RulesTemplateName = "";
	
	// Server call.
	UpdateRuleTemplateChoiceList();
	
EndProcedure

&AtClient
Procedure RulesSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		
		Record.DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebugOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebug.Enabled = Record.ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)';") + "|*.epf" );
	
	DataExchangeClient.FileSelectionHandler(Record, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)';") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(Record, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebugOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebug.Enabled = Record.ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	Items.ExchangeProtocolFile.Enabled = Record.DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Text document (*.txt)';")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(Record, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RulesTemplateNameOnChange(Item)
	Record.CorrespondentRulesTemplateName = Record.RulesTemplateName + "Correspondent";
EndProcedure

&AtClient
Procedure EnableDebuggingOnChange(Item)
	
	Items.DebugSettingsGroup.Enabled = Record.DebugMode;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select an exchange rule archive';"));
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)';") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);

	// Export to an archive.
	StorageAddress = GetRuleArchiveTempStorageAddressAtServer();
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Conversion rules';");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("en = 'Select a file to export rules to';") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)';") + "|*.zip");
	
	FileToReceive = New Structure("Name, Location", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)

	If Not CheckFillingAtClient() Then
		Cancel = True;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	AllowExternalResource(WriteParameters)
	
EndProcedure

&AtClient
Procedure WriteRules(Command)

	If Not CheckFillingAtClient() Then
		Cancel = True;
	EndIf;
	
	WriteParameters = New Structure;
	AllowExternalResource(WriteParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateExchangePlanChoiceList()
	
	ExchangePlansList = DataExchangeCached.SSLExchangePlansList();
	
	FillList(ExchangePlansList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure UpdateRuleTemplateChoiceList()
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		Items.MainGroup2.Title = NStr("en = 'Conversion rules';");
		
	Else
		
		Items.MainGroup2.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.MainGroup2.Title, Metadata.ExchangePlans[Record.ExchangePlanName].Synonym);
		
	EndIf;
	
	TemplatesList = DataExchangeCached.ConversionRulesForExchangePlanFromConfiguration(Record.ExchangePlanName);
	
	ChoiceList = Items.RulesTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplatesList, ChoiceList);
	
	Items.SourceConfigurationTemplate.CurrentPage = ?(TemplatesList.Count() = 1,
		Items.SingleTemplatePage, Items.SeveralTemplatesPage);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, DestinationList)
	
	For Each Item In SourceList Do
		
		FillPropertyValues(DestinationList.Add(), Item);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ImportRulesCompletion(Val PutFilesResult, Val AdditionalParameters) Export
	
	PutFileAddress = PutFilesResult.Location;
	ErrorText           = PutFilesResult.ErrorDescription;
	
	If IsBlankString(ErrorText) And IsBlankString(PutFileAddress) Then
		ErrorText = NStr("en = 'An error occurred while sending a file of data synchronization settings to the server.';");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonClient.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// The file is successfully transferred, importing the file to the server.
	NameParts = CommonClientServer.ParseFullFileName(PutFilesResult.Name);
	
	PerformRuleImport(PutFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val PutFileAddress, Val FileName, Val IsArchive)
	Cancel = False;
	
	ImportRulesAtServer(Cancel, PutFileAddress, FileName, IsArchive);
	
	If Not Cancel Then
		ShowUserNotification(,, NStr("en = 'The rules are imported to the infobase.';"));
		Return;
	EndIf;
	
	ErrorText = NStr("en = 'Errors occurred when importing the rules.
	                         |Go to the event log?';");
	
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
EndProcedure

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", DataExchangeRulesImportEventLogEvent);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RulesFileName, IsArchive)
	
	Record.RulesSource = ?(RulesSource = "StandardRulesFromConfiguration",
		Enums.DataExchangeRulesSources.ConfigurationTemplate, Enums.DataExchangeRulesSources.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TempStorageAddress, RulesFileName, IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// 
		DataExchangeInternal.ResetObjectsRegistrationMechanismCache();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Create the temporary directory at the server and generate file paths.
	TempDirectoryName = GetTempFileName("");
	CreateDirectory(TempDirectoryName);
	PathToFile = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "ExchangeRules";
	CorrespondentFilePath = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "CorrespondentExchangeRules";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.XMLRules,
	|	DataExchangeRules.XMLCorrespondentRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind = &RulesKind";
	Query.SetParameter("ExchangePlanName", Record.ExchangePlanName); 
	Query.SetParameter("RulesKind", Record.RulesKind);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		NString = NStr("en = 'Cannot receive exchange rules.';");
		DataExchangeServer.ReportError(NString);
		DeleteFiles(TempDirectoryName);
		Return "";
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		// 
		RuleBinaryData = Selection.XMLRules.Get(); // BinaryData
		RuleBinaryData.Write(PathToFile + ".xml");
		
		CorrespondentRulesBinaryData = Selection.XMLCorrespondentRules.Get(); // BinaryData
		CorrespondentRulesBinaryData.Write(CorrespondentFilePath + ".xml");
		
		FilesPackingMask = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilesPackingMask);
		
		// Placing the ZIP archive with the rules in the storage.
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TempStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		DeleteFiles(TempDirectoryName);
		Return TempStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RulesSource = Enums.DataExchangeRulesSources.File Then
		
		RulesInformation = NStr("en = 'Using rules imported from the file
		|might cause errors when migrating to a new version of the application.
		|
		|[RulesInformation]';");
		
		RulesInformation = StrReplace(RulesInformation, "[RulesInformation]", Record.RulesInformation);
		
	Else
		
		RulesInformation = Record.RulesInformation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResource(WriteParameters)
	
	ClosingNotification1 = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, WriteParameters);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
				
		If RulesSource = "StandardRulesFromConfiguration" Then
			// From configuration.
			PerformRuleImport(Undefined, "", False);
		EndIf;
		
		Write(WriteParameters);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestToUseExternalResources(Val Record)
	
	PermissionsRequests = New Array;
	RegistrationRulesFromFile = InformationRegisters.DataExchangeRules.RegistrationRulesFromFile(Record.ExchangePlanName);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionsRequests, Record, True, RegistrationRulesFromFile);
	Return PermissionsRequests;
	
EndFunction


#EndRegion