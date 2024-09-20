///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var ExternalResourcesAllowed;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangePlanName = Parameters.ExchangePlanName;
	
	If Not ValueIsFilled(ExchangePlanName) Then
		Return;
	EndIf;
	
	Title = StrReplace(Title, "%1", Metadata.ExchangePlans[ExchangePlanName].Synonym);
	
	UpdateRuleInfo();
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.DebugSettingsGroup.Enabled = DebugMode;
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	DataExchangeRulesImportEventLogEvent = DataExchangeServer.DataExchangeRulesImportEventLogEvent();
	
	ApplicationName = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	RuleSetLocation = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, 
								"PathToRulesSetFileOnUserSite, PathToRulesSetFileInTemplateDirectory");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	TooltipTemplate = NStr("en = 'You can download a rule set from %1 
		|or find in %2';");
	
	UpdateDirectoryPattern = NStr("en = 'the %1 application directory';");
	UpdateDirectoryPattern = StringFunctionsClientServer.SubstituteParametersToString(UpdateDirectoryPattern, ApplicationName);
	
	UserSitePattern = NStr("en = '1C:Enterprise 8 user support website';");
	If Not IsBlankString(RuleSetLocation.PathToRulesSetFileOnUserSite) Then
		UserSitePattern = New FormattedString(UserSitePattern,,,, RuleSetLocation.PathToRulesSetFileOnUserSite);
	EndIf;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("TooltipTemplate",            TooltipTemplate);
	AdditionalParameters.Insert("UpdateDirectoryPattern",    UpdateDirectoryPattern);
	AdditionalParameters.Insert("UserSitePattern", UserSitePattern);
	
	If Not IsBlankString(RuleSetLocation.PathToRulesSetFileInTemplateDirectory)
		And CommonClient.IsWindowsClient() Then
		AdditionalParameters.Insert("DefaultDirectory",                AppDataDirectory() + "1C\1Cv8\tmplts\");
		AdditionalParameters.Insert("UserTemplateSettings", AppDataDirectory() + "1C\1CEStart\1CEStart.cfg");
		AdditionalParameters.Insert("FileLocation1",                 "");
		
		SuggestionText = NStr("en = 'To open the directory, install 1C:Enterprise Extension.';");
		Notification = New NotifyDescription("AfterCheckFileSystemExtension", ThisObject, AdditionalParameters);
		FileSystemClient.AttachFileOperationsExtension(Notification, SuggestionText);
	Else
		SetInformationTitleOnReceive(AdditionalParameters);
	EndIf;
	
EndProcedure

// Continuation of the procedure (see above). 
&AtClient
Procedure AfterCheckFileSystemExtension(Result, AdditionalParameters) Export
	
	If Result Then
		File = New File(AdditionalParameters.UserTemplateSettings);
		
		Notification = New NotifyDescription("DetermineFileExists", ThisObject, AdditionalParameters);
		File.BeginCheckingExistence(Notification);
		
	Else
		SetInformationTitleOnReceive(AdditionalParameters);
	EndIf;
	
EndProcedure

// Continuation of the procedure (see above). 
&AtClient
Procedure DetermineFileExists(Exists, AdditionalParameters) Export

#If WebClient Then
	
	Raise NStr("en = 'The operation is not available in web client';");
	
#Else
	
	FoundDirectory = Undefined;
	
	If Exists Then
		
		Text = New TextReader(AdditionalParameters.UserTemplateSettings, TextEncoding.UTF16);
		Page1 = "";
		
		While Page1 <> Undefined Do
			Page1 = Text.ReadLine();
			If Page1 = Undefined Then
				Break;
			EndIf;
			If StrFind(Upper(Page1), Upper("ConfigurationTemplatesLocation")) = 0 Then
				Continue;
			EndIf;
			SeparatorPosition = StrFind(Page1, "=");
			If SeparatorPosition = 0 Then
				Continue;
			EndIf;
			FoundDirectory = CommonClientServer.AddLastPathSeparator(TrimAll(Mid(Page1, SeparatorPosition + 1)));
			Break;
		EndDo;
		
	EndIf;
	
	If FoundDirectory <> Undefined Then
		AdditionalParameters.FileLocation1 = FoundDirectory + RuleSetLocation.PathToRulesSetFileInTemplateDirectory;
	Else
		AdditionalParameters.FileLocation1 = AdditionalParameters.DefaultDirectory + RuleSetLocation.PathToRulesSetFileInTemplateDirectory
	EndIf;
	
	File = New File(AdditionalParameters.FileLocation1);
	
	Notification = New NotifyDescription("DetermineDirectoryExists", ThisObject, AdditionalParameters);
	File.BeginCheckingExistence(Notification);
	
#EndIf
	
EndProcedure

// Continuation of the procedure (see above). 
&AtClient
Procedure DetermineDirectoryExists(Exists, AdditionalParameters) Export
	
	If Exists Then
		AdditionalParameters.UpdateDirectoryPattern = New FormattedString(AdditionalParameters.UpdateDirectoryPattern,,,,
			AdditionalParameters.FileLocation1);
	EndIf;
	
	SetInformationTitleOnReceive(AdditionalParameters);
	
EndProcedure

// Continuation of the procedure (see above). 
&AtClient
Procedure SetInformationTitleOnReceive(AdditionalParameters)
	ToolTipText = SubstituteParametersInFormattedString(AdditionalParameters.TooltipTemplate, 
		AdditionalParameters.UserSitePattern,
		AdditionalParameters.UpdateDirectoryPattern);
	Items.RulesImportInfoDecoration.Title = ToolTipText;
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If DebugMode Then
		
		If ExportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified';");
				CommonClient.MessageToUser(MessageString,, "ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If ImportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'External data processor file name is not specified';");
				CommonClient.MessageToUser(MessageString,, "ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If DataExchangeLoggingMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("en = 'Exchange protocol file name is not specified.';");
				CommonClient.MessageToUser(MessageString,, "ExchangeProtocolFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RulesSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		
		DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebugOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExternalDataProcessorForExportDebug.Enabled = ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)';") + "|*.epf" );
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'External data processor (*.epf)';") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(ThisObject, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebugOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExternalDataProcessorForImportDebug.Enabled = ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeLoggingOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExchangeProtocolFile.Enabled = DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("en = 'Text document (*.txt)';")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(ThisObject, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure EnableDebuggingOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.DebugSettingsGroup.Enabled = DebugMode;
	
EndProcedure

&AtClient
Procedure DoNotStopOnErrorOnChange(Item)
	DebuggingSettingsChanged = True;
EndProcedure

&AtClient
Procedure RulesImportInfoDecorationURLProcessing(
		Item, FormattedStringURL, StandardProcessing)
	
	AdditionalParameters = New Structure;	
	AdditionalParameters.Insert("FormattedStringURL", FormattedStringURL);
		
	Notification = New NotifyDescription("DecorationRuleReceiptInformationURLProcessingAfterFinish",
		ThisObject, AdditionalParameters);
		
	StandardProcessing = False;
	FileSystemClient.OpenURL(FormattedStringURL, Notification);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select an exchange rule archive';"));
	DialogParameters.Insert("Filter", NStr("en = 'ZIP archive (*.zip)';") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonClientServer.ParseFullFileName(RulesFileName);

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
		
	If RulesSource = "StandardRulesFromConfiguration" Then
		BeforeRuleImport(Undefined, "");
	Else
		If ConversionRuleSource = PredefinedValue("Enum.DataExchangeRulesSources.ConfigurationTemplate") Then
			
			ErrorDescription = NStr("en = 'Rules are not imported. If you close the form, the default conversion rules will apply.
			|Apply the default rules?';");
			
			Notification = New NotifyDescription("CloseRuleImportForm", ThisObject);
			
			Buttons = New ValueList;
			Buttons.Add("Use", NStr("en = 'Use';"));
			Buttons.Add("Cancel", NStr("en = 'Cancel';"));
			
			FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
			FormParameters.DefaultButton = "Use";
			FormParameters.PromptDontAskAgain = False;
			
			StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription, Buttons, FormParameters);
		Else
			If DebuggingSettingsChanged Then
				ImportDebugModeSettingsAtServer();
			EndIf;
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DecorationRuleReceiptInformationURLProcessingAfterFinish(ApplicationStarted, AdditionalParameters) Export
	
	If ApplicationStarted Then
		Return;
	EndIf;
	
	FileSystemClient.OpenExplorer(AdditionalParameters.FormattedStringURL);
	
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
	
	If Lower(NameParts.Extension) <> ".zip" Then
		CommonClient.MessageToUser(NStr("en = 'Invalid rules file. Expected a ZIP archive with three files:
			|ExchangeRules.xml. Contains conversion rules for this application.
			|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.
			|RegistrationRules.xml. Contains registration rules for this application.';"));
	EndIf;
	
	BeforeRuleImport(PutFileAddress, NameParts.Name);
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val PutFileAddress, Val FileName, ErrorDescription = Undefined)
	
	Cancel = False;
	DebuggingSettingsChanged = False;
	
	ImportRulesAtServer(Cancel, PutFileAddress, FileName, ErrorDescription);
	
	If TypeOf(ErrorDescription) <> Type("Boolean") And ErrorDescription <> Undefined Then
		
		Buttons = New ValueList;
		
		If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
			Buttons.Add("Cancel", NStr("en = 'Close';"));
		Else
			Buttons.Add("Continue", NStr("en = 'Continue';"));
			Buttons.Add("Cancel", NStr("en = 'Cancel';"));
		EndIf;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PutFileAddress", PutFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.DefaultButton = "Cancel";
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.PromptDontAskAgain = False;
		If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
			FormParameters.Title = NStr("en = 'Cannot import rules';");
		Else
			FormParameters.Title = NStr("en = 'Data synchronization might be performed incorrectly';");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	ElsIf Cancel Then
		ErrorText = NStr("en = 'Errors occurred when importing the rules.
			|Go to the event log?';");
		Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
		ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	Else
		ShowUserNotification(,, NStr("en = 'The rules are imported to the infobase.';"));
		Close();
	EndIf;
	
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
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RulesFileName, ErrorDescription)
	
	SetRuleSource = ?(RulesSource = "StandardRulesFromConfiguration",
		Enums.DataExchangeRulesSources.ConfigurationTemplate, Enums.DataExchangeRulesSources.File);
	
	CovnersionRuleWriting                               = InformationRegisters.DataExchangeRules.CreateRecordManager();
	CovnersionRuleWriting.RulesKind                     = Enums.DataExchangeRulesTypes.ObjectsConversionRules;
	CovnersionRuleWriting.RulesTemplateName               = ConversionRuleTemplateName;
	CovnersionRuleWriting.CorrespondentRulesTemplateName = CorrespondentRulesTemplateName;
	CovnersionRuleWriting.RulesInformation           = ConversionRulesInformation;
	
	FillPropertyValues(CovnersionRuleWriting, ThisObject);
	CovnersionRuleWriting.RulesSource = SetRuleSource;
	
	RegistrationRuleWriting                     = InformationRegisters.DataExchangeRules.CreateRecordManager();
	RegistrationRuleWriting.RulesKind           = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	RegistrationRuleWriting.RulesTemplateName     = RegistrationRuleTemplateName;
	RegistrationRuleWriting.RulesInformation = RegistrationRulesInformation;
	RegistrationRuleWriting.RulesFileName      = RulesFileName;
	RegistrationRuleWriting.ExchangePlanName      = ExchangePlanName;
	RegistrationRuleWriting.RulesSource      = SetRuleSource;
	
	RegisterRecordStructure = New Structure();
	RegisterRecordStructure.Insert("CovnersionRuleWriting", CovnersionRuleWriting);
	RegisterRecordStructure.Insert("RegistrationRuleWriting", RegistrationRuleWriting);
	
	InformationRegisters.DataExchangeRules.ImportRulesSet(Cancel, RegisterRecordStructure,
		ErrorDescription, TempStorageAddress, RulesFileName);
	
	If Not Cancel Then
		
		CovnersionRuleWriting.Write();
		RegistrationRuleWriting.Write();
		
		Modified = False;
		
		// 
		DataExchangeInternal.ResetObjectsRegistrationMechanismCache();
		RefreshReusableValues();
		UpdateRuleInfo();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Create the temporary directory at the server and generate file paths.
	TempDirectoryName = GetTempFileName("");
	CreateDirectory(TempDirectoryName);
	
	PathToFile               = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "ExchangeRules";
	CorrespondentFilePath = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "CorrespondentExchangeRules";
	RegistrationFilePath    = CommonClientServer.AddLastPathSeparator(TempDirectoryName) + "RegistrationRules";
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	DataExchangeRules.XMLRules,
		|	DataExchangeRules.XMLCorrespondentRules,
		|	DataExchangeRules.RulesKind
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		NString = NStr("en = 'Cannot receive exchange rules.';");
		DataExchangeServer.ReportError(NString);
		DeleteFiles(TempDirectoryName);
		Return "";
		
	Else
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectsConversionRules Then
				
				// 
				RuleBinaryData = Selection.XMLRules.Get(); // BinaryData
				RuleBinaryData.Write(PathToFile + ".xml");
				
				// 
				CorrespondentRulesBinaryData = Selection.XMLCorrespondentRules.Get(); // BinaryData
				CorrespondentRulesBinaryData.Write(CorrespondentFilePath + ".xml");
				
			Else
				// 
				RegistrationRulesBinaryData = Selection.XMLRules.Get(); // BinaryData
				RegistrationRulesBinaryData.Write(RegistrationFilePath + ".xml");
			EndIf;
			
		EndDo;
		
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
	
	RulesInformation();
	
	RulesSource = ?(RegistrationRuleSource = Enums.DataExchangeRulesSources.File
		Or ConversionRuleSource = Enums.DataExchangeRulesSources.File,
		"RuelsImportedFromFile", "StandardRulesFromConfiguration");
	
	CommonRulesInformation = "[UsageInformation]
		|
		|[RegistrationRulesInformation]
		|
		|[ConversionRulesInformation]";
	
	If RulesSource = "RuelsImportedFromFile" Then
		UsageInformation = NStr("en = 'Exchange rules imported from a file are applied.';");
	Else
		UsageInformation = NStr("en = 'Default configuration exchange rules are used.';");
	EndIf;
	
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[UsageInformation]", UsageInformation);
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[ConversionRulesInformation]", ConversionRulesInformation);
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[RegistrationRulesInformation]", RegistrationRulesInformation);
	
EndProcedure

&AtServer
Procedure RulesInformation()
	
	Query = New Query;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS ConversionRuleTemplateName,
		|	DataExchangeRules.CorrespondentRulesTemplateName AS CorrespondentRulesTemplateName,
		|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
		|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
		|	DataExchangeRules.RulesFileName AS ConversionRuleFileName,
		|	DataExchangeRules.ExchangeProtocolFileName,
		|	DataExchangeRules.RulesInformation AS ConversionRulesInformation,
		|	DataExchangeRules.RulesSource AS ConversionRuleSource,
		|	DataExchangeRules.NotStopByMistake,
		|	DataExchangeRules.DebugMode,
		|	DataExchangeRules.ExportDebugMode,
		|	DataExchangeRules.ImportDebugMode,
		|	DataExchangeRules.DataExchangeLoggingMode
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)";
		
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS RegistrationRuleTemplateName,
		|	DataExchangeRules.RulesFileName AS RegistrationRuleFileName,
		|	DataExchangeRules.RulesInformation AS RegistrationRulesInformation,
		|	DataExchangeRules.RulesSource AS RegistrationRuleSource
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeRuleImport(Val PutFileAddress, Val FileName)
	
	If Not CheckFillingAtClient() Then
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PutFileAddress", PutFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		ClosingNotification1 = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, AdditionalParameters);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Queries = CreateRequestToUseExternalResources();
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
		Else
			ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
		EndIf;
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	PerformRuleImport(PutFileAddress, FileName);
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		BeforeRuleImport(AdditionalParameters.PutFileAddress, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

&AtServer
Function CreateRequestToUseExternalResources()
	
	PermissionsRequests = New Array;
	RegistrationRulesFromFile = (RulesSource <> "StandardRulesFromConfiguration");
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName", ExchangePlanName);
	RecordStructure.Insert("DebugMode", DebugMode);
	RecordStructure.Insert("ExportDebugMode", ExportDebugMode);
	RecordStructure.Insert("ImportDebugMode", ImportDebugMode);
	RecordStructure.Insert("DataExchangeLoggingMode", DataExchangeLoggingMode);
	RecordStructure.Insert("ExportDebuggingDataProcessorFileName", ExportDebuggingDataProcessorFileName);
	RecordStructure.Insert("ImportDebuggingDataProcessorFileName", ImportDebuggingDataProcessorFileName);
	RecordStructure.Insert("ExchangeProtocolFileName", ExchangeProtocolFileName);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionsRequests, RecordStructure, True, RegistrationRulesFromFile);
	Return PermissionsRequests;
	
EndFunction

&AtClient
// Returns a formatted string based on a template (for example, "%1 moved to %2").
//
// Parameters:
//     Template - String - Generation template.
//     String1 - String
//             - FormattedString
//             - Picture
//             - Undefined - Value to set.
//     String2 - String
//             - FormattedString
//             - Picture
//             - Undefined - Value to set.
//
// Returns:
//     FormattedString - 
//
Function SubstituteParametersInFormattedString(Val Template,
	Val String1 = Undefined, Val String2 = Undefined)
	
	StringParts1 = New Array;
	AllowedTypes = New TypeDescription("String, FormattedString, Picture");
	Begin = 1;
	
	While True Do
		
		Particle = Mid(Template, Begin);
		
		Position = StrFind(Particle, "%");
		
		If Position = 0 Then
			
			StringParts1.Add(Particle);
			
			Break;
			
		EndIf;
		
		Next = Mid(Particle, Position + 1, 1);
		
		If Next = "1" Then
			
			Value = String1;
			
		ElsIf Next = "2" Then
			
			Value = String2;
			
		ElsIf Next = "%" Then
			
			Value = "%";
			
		Else
			
			Value = Undefined;
			
			Position  = Position - 1;
			
		EndIf;
		
		StringParts1.Add(Left(Particle, Position - 1));
		
		If Value <> Undefined Then
			
			Value = AllowedTypes.AdjustValue(Value);
			
			If Value <> Undefined Then
				
				StringParts1.Add( Value );
				
			EndIf;
			
		EndIf;
		
		Begin = Begin + Position + 1;
		
	EndDo;
	
	Return New FormattedString(StringParts1);
	
EndFunction

// Determining the "My Documents" directory of the current Windows user.
//
&AtClient
Function AppDataDirectory()
	
#If MobileClient Then
	Return "";
#Else
	Package = New COMObject("Shell.Application");
	Directory = Package.Namespace(26);
	Result = Directory.Self.Path;
	Return CommonClientServer.AddLastPathSeparator(Result);
#EndIf

EndFunction

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result.Value = "Continue" Then
		
		ErrorDescription = True;
		PerformRuleImport(AdditionalParameters.PutFileAddress, AdditionalParameters.FileName, ErrorDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseRuleImportForm(Result, AdditionalParameters) Export
	If Result <> Undefined And Result.Value = "Use" Then
		Close();
	EndIf;
EndProcedure

&AtServer
Procedure ImportDebugModeSettingsAtServer()
	
	BeginTransaction();
	Try
	    Block = New DataLock;
	    LockItem = Block.Add("InformationRegister.DataExchangeRules");
	    LockItem.SetValue("ExchangePlanName", ExchangePlanName);
		LockItem.SetValue("RulesKind",      Enums.DataExchangeRulesTypes.ObjectsConversionRules);
	    Block.Lock();
	    
		ConversionRulesRecords = InformationRegisters.DataExchangeRules.CreateRecordSet();
		ConversionRulesRecords.Filter.RulesKind.Set(Enums.DataExchangeRulesTypes.ObjectsConversionRules);
		ConversionRulesRecords.Filter.ExchangePlanName.Set(ExchangePlanName);
		
		ConversionRulesRecords.Read();
		If ConversionRulesRecords.Count() > 0 Then
			RulesRecord = ConversionRulesRecords[0];
			RulesRecord.ExportDebuggingDataProcessorFileName = ExportDebuggingDataProcessorFileName;
			RulesRecord.ImportDebuggingDataProcessorFileName = ImportDebuggingDataProcessorFileName;
			RulesRecord.ExchangeProtocolFileName = ExchangeProtocolFileName;
			RulesRecord.NotStopByMistake = NotStopByMistake;
			RulesRecord.DebugMode = DebugMode;
			RulesRecord.ExportDebugMode = ExportDebugMode;
			RulesRecord.ImportDebugMode = ImportDebugMode;
			RulesRecord.DataExchangeLoggingMode = DataExchangeLoggingMode;
			
			ConversionRulesRecords.Write(True);
		EndIf;

	    CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;
	
EndProcedure

#EndRegion