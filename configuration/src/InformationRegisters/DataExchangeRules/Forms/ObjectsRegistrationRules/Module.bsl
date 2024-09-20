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
	
	UpdateRuleSource();
	
	DataExchangeRulesImportEventLogEvent = DataExchangeServer.DataExchangeRulesImportEventLogEvent();
	
	ConfiguringFormElements();
	
EndProcedure

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
	
	If RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.ConfigurationTemplate") Then
		Record.DebugMode = False;
	EndIf;
	
	Items.RegistrationManagerName.Enabled = 
		RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.CustomManager");
		
	Items.FormSaveRegistrationRulesToFile.Enabled = Record.RulesAreImported;
	
	UpdateInformationAboutUnwrittenRules();
	
EndProcedure

&AtClient
Procedure RegistrationManagerNameOnChange(Item)
	
	UpdateInformationAboutUnwrittenRules();

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	ClearMessages();
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("en = 'Select a file to import rules from';"));
	DialogParameters.Insert("Filter",
		  NStr("en = 'Registration rule files (*.xml)';") + "|*.xml|"
		+ NStr("en = 'ZIP archive (*.zip)';")   + "|*.zip");
	
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	DialogParameters.Insert("FilterIndex", ?( Lower(NameParts.Extension) = ".zip", 1, 0) ); 
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	If Not Record.RulesAreImported Then
		
		MessageText = NStr("en = 'Registration rules are not imported';");
		CommonClient.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	StorageAddress = GetURLAtServer();
	NameFilter = NStr("en = 'Rule files (*.xml)';") + "|*.xml";
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Registration rules';");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("en = 'Select a file to export rules to';") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NameFilter);
	
	FileToReceive = New Structure("Name, Location", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
	
EndProcedure

&AtClient
Procedure SaveRegistrationRulesFromTemplate(Command)
	
	List = Items.RulesTemplateName.ChoiceList;
	
	If List.Count() = 0 Then
		
		Template = NStr("en = 'Cannot find a registration rule template for the ""%1"" exchange plan';", 
			CommonClient.DefaultLanguageCode());
			
		Text = StrTemplate(Template, Record.ExchangePlanName);
		
		CommonClient.MessageToUser(Text);
		
	ElsIf List.Count() = 1 Then
		
		SaveRegistrationRulesFromTemplateCompletion(List[0].Value);
		
	Else
		
		Notification = New NotifyDescription("TemplateSelectionEnds", ThisObject);
		List.ShowChooseItem(Notification, NStr("en = 'Select a registration rule template';"));
	
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplateSelectionEnds(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	SaveRegistrationRulesFromTemplateCompletion(Result.Value);
	
EndProcedure

&AtClient
Procedure SaveRegistrationRulesFromTemplateCompletion(TemplateName)
	
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Registration rules';");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
		
	FileAddress = PrepareFileOnServer(TemplateName);
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Select a file to export rules to';");
	SavingParameters.Dialog.Filter = NStr("en = 'Rule files (*.xml)';") + "|*.xml";
	
	FileSystemClient.SaveFile(Undefined, FileAddress, FullFileName, SavingParameters);
	
EndProcedure

&AtServer
Function PrepareFileOnServer(TemplateName)

	TempFileName = GetTempFileName("xml");
	Template = ExchangePlans[Record.ExchangePlanName].GetTemplate(TemplateName);
	Template.Write(TempFileName);
	
	BinaryData = New BinaryData(TempFileName);
	
	DeleteFiles(TempFileName);
	
	Return PutToTempStorage(BinaryData);
		
EndFunction

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	AllowExternalResource(WriteParameters);
	
EndProcedure

&AtClient
Procedure WriteRules(Command)
	
	WriteParameters = New Structure;
	AllowExternalResource(WriteParameters)
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", DataExchangeRulesImportEventLogEvent);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

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
	
	TemplatesList = DataExchangeCached.RegistrationRulesForExchangePlanFromConfiguration(Record.ExchangePlanName);
	
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

&AtServer
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RulesFileName, IsArchive)
	
	Record.RulesSource = RulesSource;
	
	Object = FormAttributeToValue("Record");
	
	If RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate
		Or RulesSource = Enums.DataExchangeRulesSources.File Then
		
		InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TempStorageAddress, RulesFileName, IsArchive);
		
	Else
		
		Object.RulesFileName = "";
		Object.RulesAreRead = Undefined;
		
		If RulesSource = Enums.DataExchangeRulesSources.StandardManager Then
			Object.RegistrationManagerName = DataExchangeCached.RegistrationManagerName(Object.ExchangePlanName);
		EndIf;
			
		Manager = Common.CommonModule(Object.RegistrationManagerName);
		Object.RulesInformation = Manager.RulesInformation();
		
	EndIf;
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// 
		DataExchangeInternal.ResetObjectsRegistrationMechanismCache();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtServer
Function GetURLAtServer()
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", Record.ExchangePlanName);
	Filter.Insert("RulesKind",      Record.RulesKind);
	
	RecordKey = InformationRegisters.DataExchangeRules.CreateRecordKey(Filter);
	
	Return GetURL(RecordKey, "XMLRules");
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RulesSource = Enums.DataExchangeRulesSources.File Then
		
		StringPattern = NStr("en = 'Using rules imported from the file
                             |might cause errors when migrating to a new version of the application.
                             |
                             |%1';");
			
	ElsIf Record.RulesSource = Enums.DataExchangeRulesSources.CustomManager Then
		
		StringPattern = NStr("en = 'Using rules imported from a user module
                             |might cause errors when migrating to a new version of the application.
                             |
                             |%1';");	
	Else
		
		StringPattern = "%1";
		
	EndIf;
	
	RulesInformation = StringFunctions.FormattedString(StringPattern, Record.RulesInformation);
	
EndProcedure

&AtServer
Procedure UpdateInformationAboutUnwrittenRules()
	
	If RulesSource = Record.RulesSource
		And (RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate
		Or RulesSource = Enums.DataExchangeRulesSources.File)Then

		UpdateRuleInfo();
	
	ElsIf RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate Then
		
		RulesInformation = NStr("en = 'Save changes to view rule details';");
		
	ElsIf RulesSource = Enums.DataExchangeRulesSources.File Then
		
		RulesInformation = NStr("en = 'Finish importing to view rule details';");
		
	Else
		
		If RulesSource = Enums.DataExchangeRulesSources.StandardManager Then
			
			RegistrationManagerName = DataExchangeCached.RegistrationManagerName(Record.ExchangePlanName);	
			StringPattern = "%1";
			
		ElsIf RulesSource = Enums.DataExchangeRulesSources.CustomManager Then
			
			RegistrationManagerName = Record.RegistrationManagerName;
			StringPattern = NStr("en = 'Using rules imported from a user module
									|might cause errors when migrating to a new version of the application.
									|
									|%1';");
			
		EndIf;	
		
		Try
			
			Manager = Common.CommonModule(RegistrationManagerName);
			RulesInformation = StringFunctions.FormattedString(StringPattern, Manager.RulesInformation());
			
		Except
			
			MessageText = NStr("en = 'Error getting registration rules details:
                                   |%1';");
			RulesInformation = StringFunctions.FormattedString(MessageText, ErrorInfo().Description);
			
		EndTry;
		
	EndIf;
		
EndProcedure	
	
&AtServer
Procedure UpdateRuleSource()
	
	RulesSource = Record.RulesSource;
	
EndProcedure

&AtServer
Procedure ConfiguringFormElements()

	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	If DataExchangeCached.RulesForRegisteringInManager(Record.ExchangePlanName) Then
		
		Items.StandardRulesGroup.Visible = False;
		Items.RegistrationManagerName.Enabled = RulesSource = Enums.DataExchangeRulesSources.CustomManager;
		Items.FormSaveRegistrationRulesToFile.Enabled = Record.RulesAreImported;
		Items.RulesFromFileActionsGroup.Visible = False;
		Items.ActionGroupWithRulesFromFileManager.Visible = True;
		Items.FormSaveRegistrationRulesToFile.Visible = False;
		Items.FormSaveRegistrationRulesFromTemplate.Visible = True;
		
		NameOfTypicalRegistrationManager = DataExchangeCached.RegistrationManagerName(Record.ExchangePlanName);
		
	Else
		
		Items.GroupRulesManagerTypical.Visible = False;
		Items.GroupRulesManager.Visible = False;
		Items.RulesFromFileActionsGroup.Visible = True;
		Items.ActionGroupWithRulesFromFileManager.Visible = False;
		Items.FormSaveRegistrationRulesFromTemplate.Visible = False;
		
	EndIf;

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
Procedure ImportRulesCompletion(Val PutFilesResult, Val AdditionalParameters) Export
	
	PutFileAddress = PutFilesResult.Location;
	ErrorText           = PutFilesResult.ErrorDescription;
	
	If IsBlankString(ErrorText) And IsBlankString(PutFileAddress) Then
		ErrorText = NStr("en = 'An error occurred when transferring the file to the server';");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonClient.MessageToUser(ErrorText);
		Return;
	EndIf;
	
	RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.File");
	
	// The file is successfully transferred, importing the file to the server.
	NameParts = CommonClientServer.ParseFullFileName(PutFilesResult.Name);
	
	PerformRuleImport(PutFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
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
		
		If RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.ConfigurationTemplate") Then
			// From configuration.
			PerformRuleImport(Undefined, "", False);
		ElsIf RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.StandardManager")
			Or RulesSource = PredefinedValue("Enum.DataExchangeRulesSources.CustomManager") Then
			Record.RulesSource = RulesSource;
			Record.RulesFileName = "";
		EndIf;
		
		Write(WriteParameters);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestToUseExternalResources(Val Record)
	
	PermissionsRequests = New Array;
	ConversionRulesFromFile = InformationRegisters.DataExchangeRules.ConversionRulesFromFile(Record.ExchangePlanName);
	HasConvertionRules = (ConversionRulesFromFile <> Undefined);
	RegistrationRulesFromFile = (Record.RulesSource = Enums.DataExchangeRulesSources.File);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionsRequests,
		?(HasConvertionRules, ConversionRulesFromFile, Record), HasConvertionRules, RegistrationRulesFromFile);
	Return PermissionsRequests;
	
EndFunction


#EndRegion
