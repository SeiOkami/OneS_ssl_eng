///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Handlers of conditional calls from SSL

// Reads and sets a notification about long standalone workstation synchronization
// Parameters:
//     FlagValue1     - Boolean - a flag value to be set
//     SettingDetails - Structure - takes a value for the setting description.
// For internal use.
//
Function LongSynchronizationQuestionSetupFlag(FlagValue1 = Undefined, SettingDetails = Undefined) Export
	SettingDetails = New Structure;
	
	SettingDetails.Insert("ObjectKey",  "ApplicationSettings");
	SettingDetails.Insert("SettingsKey", "ShowLongSynchronizationWarningSW");
	SettingDetails.Insert("Presentation", NStr("en = 'Show warning about long synchronization';"));
	
	SettingsDescription = New SettingsDescription;
	FillPropertyValues(SettingsDescription, SettingDetails);
	
	If FlagValue1 = Undefined Then
		// Чтение
		Return Common.CommonSettingsStorageLoad(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, True);
	EndIf;
	
	// Запись
	Common.CommonSettingsStorageSave(SettingsDescription.ObjectKey, SettingsDescription.SettingsKey, FlagValue1, SettingsDescription);
EndFunction

// For internal use
// 
Function AccountPasswordRecoveryAddress() Export
	
	SetPrivilegedMode(True);
	
	Return TrimAll(Constants.AccountPasswordRecoveryAddress.Get());
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS USED IN SAAS

// For internal use
// 
Procedure CreateStandaloneWorkstationInitialImage(Parameters,
		InitialImageTempStorageAddress,
		InstallationPackageInformationTempStorageAddress) Export
	
	StandaloneWorkstationCreationWizard = DataProcessors.StandaloneWorkstationCreationWizard.Create();
	
	FillPropertyValues(StandaloneWorkstationCreationWizard, Parameters);
	
	StandaloneWorkstationCreationWizard.CreateStandaloneWorkstationInitialImage(
				Parameters.NodeFiltersSetting,
				Parameters.SelectedSynchronizationUsers,
				InitialImageTempStorageAddress,
				InstallationPackageInformationTempStorageAddress);
	
EndProcedure

// For internal use
// 
Procedure DeleteStandaloneWorkstation1(Parameters, StorageAddress) Export
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
	    LockItem = Block.Add(Common.TableNameByRef(Parameters.StandaloneWorkstation));
	    LockItem.SetValue("Ref", Parameters.StandaloneWorkstation);
	    Block.Lock();
		
		LockDataForEdit(Parameters.StandaloneWorkstation);
		StandaloneWorkstationObject = Parameters.StandaloneWorkstation.GetObject();
		
		If StandaloneWorkstationObject <> Undefined Then
			
			StandaloneWorkstationObject.AdditionalProperties.Insert("DeleteSyncSetting");
			StandaloneWorkstationObject.Delete();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Function StandaloneModeSupported() Export
	
	Return DataExchangeCached.StandaloneModeSupported();
	
EndFunction

// For internal use
// 
Function StandaloneWorkstationsCount() Export
	
	TextTemplate1 = "ExchangePlan.%1";
	NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, StandaloneModeExchangePlan());
	
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	&ExchangePlanName AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInSaaS
	|	AND NOT Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "&ExchangePlanName", NameOfTheStringExchangePlan);
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.Count;
EndFunction

// For internal use
// 
Function ApplicationInSaaS() Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeServer.MasterNode() <> Undefined Then
		
		Return DataExchangeServer.MasterNode();
		
	Else
		
		Return ExchangePlans[StandaloneModeExchangePlan()].ThisNode();
		
	EndIf;
	
EndFunction

// For internal use
// 
Function StandaloneWorkstation() Export
	
	TextTemplate1 = "ExchangePlan.%1";
	NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, StandaloneModeExchangePlan());
	
	QueryText =
	"SELECT TOP 1
	|	Table.Ref AS StandaloneWorkstation
	|FROM
	|	&ExchangePlanName AS Table
	|WHERE
	|	Table.Ref <> &ApplicationInSaaS
	|	AND NOT Table.DeletionMark";
	
	QueryText = StrReplace(QueryText, "&ExchangePlanName", NameOfTheStringExchangePlan);
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.StandaloneWorkstation;
EndFunction

// For internal use
// 
Function StandaloneModeExchangePlan() Export
	
	Return DataExchangeCached.StandaloneModeExchangePlan();
	
EndFunction

// For internal use
// 
Function IsStandaloneWorkstationNode(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.IsStandaloneWorkstationNode(InfobaseNode);
	
EndFunction

// For internal use
// 
Function LastSuccessfulSynchronizationDate(StandaloneWorkstation) Export
	
	QueryText =
	"SELECT
	|	MIN(SuccessfulDataExchangesStates.EndDate) AS SynchronizationDate
	|FROM
	|	&SuccessfulDataExchangesStates AS SuccessfulDataExchangesStates
	|WHERE
	|	SuccessfulDataExchangesStates.InfobaseNode = &StandaloneWorkstation";
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		QueryText = StrReplace(QueryText, "&SuccessfulDataExchangesStates", "InformationRegister.DataAreasSuccessfulDataExchangeStates");
	Else
		QueryText = StrReplace(QueryText, "&SuccessfulDataExchangesStates", "InformationRegister.SuccessfulDataExchangesStates");
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("StandaloneWorkstation", StandaloneWorkstation);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(ValueIsFilled(Selection.SynchronizationDate), Selection.SynchronizationDate, Undefined);
EndFunction

// For internal use
// 
Function GenerateDefaultStandaloneWorkstationDescription() Export
	
	TextTemplate1 = "ExchangePlan.%1";
	NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, StandaloneModeExchangePlan());
	
	QueryText = 
	"SELECT
	|	COUNT(*) AS Count
	|FROM
	|	&ExchangePlanName AS Table
	|WHERE
	|	Table.Description LIKE &NameTemplate";
	
	QueryText = StrReplace(QueryText, "&ExchangePlanName", NameOfTheStringExchangePlan);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("NameTemplate", DefaultStandaloneWorkstationDescription() + "%");
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Count = Selection.Count;
	
	If Count = 0 Then
		
		Return DefaultStandaloneWorkstationDescription();
		
	Else
		
		Return StringFunctionsClientServer.SubstituteParametersToString(
			"%1 (%2)",
			DefaultStandaloneWorkstationDescription(), XMLString(Count + 1));
		
	EndIf;
	
EndFunction

// For internal use
// 
Function GenerateStandaloneWorkstationPrefix(Val LastPrefix = "") Export
	
	AllowedChars = StandaloneWorkstationPrefixAllowedChars();
	
	LastStandaloneWorkstationChar = Left(LastPrefix, 1);
	
	CharPosition = StrFind(AllowedChars, LastStandaloneWorkstationChar);
	
	If CharPosition = 0 Or IsBlankString(LastStandaloneWorkstationChar) Then
		
		Char = Left(AllowedChars, 1); // 
		
	ElsIf CharPosition >= StrLen(AllowedChars) Then
		
		Char = Right(AllowedChars, 1); // 
		
	Else
		
		Char = Mid(AllowedChars, CharPosition + 1, 1); // 
		
	EndIf;
	
	ApplicationPrefix = Right(GetFunctionalOption("InfobasePrefix"), 1);
	
	Result = "[Char][ApplicationPrefix]";
	Result = StrReplace(Result, "[Char]", Char);
	Result = StrReplace(Result, "[ApplicationPrefix]", ApplicationPrefix);
	
	Return Result;
EndFunction

// For internal use
// 
Function InstallPackageFileName() Export
	
	Return NStr("en = 'Standalone mode.zip';");
	
EndFunction

// For internal use
// 
Function DataTransferRestrictionsDetails(StandaloneWorkstation) Export
	
	StandaloneModeExchangePlan = StandaloneModeExchangePlan();
	
	SettingUpSelectionsOnTheDefaultNode = DataExchangeServer.NodeFiltersSetting(StandaloneModeExchangePlan, "");
	
	If SettingUpSelectionsOnTheDefaultNode.Count() = 0 Then
		Return "";
	EndIf;
	
	// Data retrieved from cache cannot be modified. Therefore, copy the settings structure to populate it further.
	NodeFiltersSetting = Common.CopyRecursive(SettingUpSelectionsOnTheDefaultNode, False);
	
	Attributes = New Array;
	
	For Each Item In NodeFiltersSetting Do
		
		Attributes.Add(Item.Key);
		
	EndDo;
	
	Attributes = StrConcat(Attributes, ",");
	
	AttributesValues = Common.ObjectAttributesValues(StandaloneWorkstation, Attributes);
	
	For Each Item In NodeFiltersSetting Do
		
		If TypeOf(Item.Value) = Type("Structure") Then
			
			Table = AttributesValues[Item.Key].Unload();
			
			For Each NestedItem In Item.Value Do
				
				NodeFiltersSetting[Item.Key][NestedItem.Key] = Table.UnloadColumn(NestedItem.Key);
				
			EndDo;
			
		Else
			
			NodeFiltersSetting[Item.Key] = AttributesValues[Item.Key];
			
		EndIf;
		
	EndDo;
	
	Return DataExchangeServer.DataTransferRestrictionsDetails(StandaloneModeExchangePlan, NodeFiltersSetting, "");
EndFunction

// For internal use
// 
Function StandaloneWorkstationsMonitor() Export
	
	TextTemplate1 = "ExchangePlan.%1";
	NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, StandaloneModeExchangePlan());
	
	QueryText = "SELECT
	|	SuccessfulDataExchangesStates.InfobaseNode AS StandaloneWorkstation,
	|	MIN(SuccessfulDataExchangesStates.EndDate) AS SynchronizationDate
	|INTO SuccessfulDataExchangesStates
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
	|GROUP BY
	|	SuccessfulDataExchangesStates.InfobaseNode
	|;
	|
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlan.Ref AS StandaloneWorkstation,
	|	ISNULL(SuccessfulDataExchangesStates.SynchronizationDate, UNDEFINED) AS SynchronizationDate
	|FROM
	|	&ExchangePlanName AS ExchangePlan
	|		LEFT JOIN SuccessfulDataExchangesStates AS SuccessfulDataExchangesStates
	|		ON ExchangePlan.Ref = SuccessfulDataExchangesStates.StandaloneWorkstation
	|WHERE
	|	ExchangePlan.Ref <> &ApplicationInSaaS
	|	AND NOT ExchangePlan.DeletionMark
	|ORDER BY
	|	ExchangePlan.Presentation";
	
	QueryText = StrReplace(QueryText, "&ExchangePlanName", NameOfTheStringExchangePlan);
	
	Query = New Query;
	Query.SetParameter("ApplicationInSaaS", ApplicationInSaaS());
	Query.Text = QueryText;
	
	SynchronizationSettings = Query.Execute().Unload();
	SynchronizationSettings.Columns.Add("SynchronizationDatePresentation");
	
	For Each SyncSetup In SynchronizationSettings Do
		
		If ValueIsFilled(SyncSetup.SynchronizationDate) Then
			SyncSetup.SynchronizationDatePresentation =
				DataExchangeServer.RelativeSynchronizationDate(SyncSetup.SynchronizationDate);
		Else
			SyncSetup.SynchronizationDatePresentation = NStr("en = 'not performed';");
		EndIf;
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

// For internal use
// 
Function StandaloneWorkstationCreationEventLogMessageText() Export
	
	Return NStr("en = 'Standalone mode.Create standalone workstation';", Common.DefaultLanguageCode());
	
EndFunction

// For internal use
// 
Function StandaloneWorkstationDeletionEventLogMessageText() Export
	
	Return NStr("en = 'Standalone mode.Delete standalone workstation';", Common.DefaultLanguageCode());
	
EndFunction

// For internal use
// 
Function InstructionTextFromTemplate(Val TemplateName) Export
	
	Result = DataProcessors.StandaloneWorkstationCreationWizard.GetTemplate(TemplateName).GetText();
	Result = StrReplace(Result, "[ApplicationName1]", Metadata.Synonym);
	Result = StrReplace(Result, "[PlatformVersion]", DataExchangeSaaS.RequiredPlatformVersion());
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS USED IN THE STANDALONE MODE

// For internal use
// 
Procedure SynchronizeDataWithWebApplication() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.DataSynchronizationWithWebApplication);
	
	SetPrivilegedMode(True);
	
	If Not IsStandaloneWorkplace() Then
		
		DetailErrorDescriptionForEventLog =
			NStr("en = 'This infobase is not a standalone workstation. Data synchronization is canceled.';",
			Common.DefaultLanguageCode());
		DetailErrorDescription =
			NStr("en = 'This infobase is not a standalone workstation. Data synchronization is canceled.';");
		
		WriteLogEvent(DataSynchronizationEventLogEvent(),
			EventLogLevel.Error,,, DetailErrorDescriptionForEventLog);
		Raise DetailErrorDescription;
		
	EndIf;
	
	ExchangeNode = ApplicationInSaaS();
	
	Cancel = False;
	DataExchangeServer.CheckWhetherTheExchangeCanBeStarted(ExchangeNode, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS;
	ExchangeParameters.ExecuteImport1 = True;
	ExchangeParameters.ExecuteExport2 = True;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ExchangeParameters.TheTimeoutOnTheServer   = 30;
		ExchangeParameters.TimeConsumingOperationAllowed = True;
	EndIf;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(ExchangeNode, ExchangeParameters, Cancel);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during data synchronization with the web application. See the event log.';");
	EndIf;
	
EndProcedure

// For internal use.
// 
Procedure PerformStandaloneWorkstationSetupOnFirstStart(DataImport = False) Export
	
	If Not Common.FileInfobase() Then
		Raise NStr("en = 'The first start of a standalone workstation must be performed in a file infobase.';");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If DataImport Then
		ImportInitialImageData();
	Else
		DoImportParametersFromInitialImage();
		
		// 
		DataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	
	SetUpMessagesArchiving();
	
	SetPrivilegedMode(False);
	
	If Not DataImport Then
		DataExchangeServer.OnContinueSubordinateDIBNodeSetup();
	EndIf;
	
EndProcedure

// For internal use
// 
Procedure DisableAutoDataSyncronizationWithWebApplication(Source) Export
	
	If Not Common.DataSeparationEnabled() Then
		
		DisableAutomaticSynchronization = False;
		
		For Each SetRow In Source Do
			
			If SetRow.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
				And Not SetRow.WSRememberPassword Then
				
				DisableAutomaticSynchronization = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If DisableAutomaticSynchronization Then
			
			SetPrivilegedMode(True);
			
			ScheduledJobsServer.SetScheduledJobUsage(
				Metadata.ScheduledJobs.DataSynchronizationWithWebApplication, False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use
// 
Function MustPerformStandaloneWorkstationSetupOnFirstStart() Export
	
	SetPrivilegedMode(True);
	Return Not Constants.SubordinateDIBNodeSetupCompleted.Get() And IsStandaloneWorkplace();
	
EndFunction

// For internal use
// 
Function SynchronizeDataWithWebApplicationOnStart() Export
	
	Return IsStandaloneWorkplace()
		And Constants.SubordinateDIBNodeSetupCompleted.Get()
		And Constants.SynchronizeDataWithInternetApplicationsOnStart.Get()
		And SynchronizationWithServiceNotExecutedLongTime()
		And DataExchangeServer.DataSynchronizationPermitted();
		
EndFunction

// For internal use
// 
Function SynchronizeDataWithWebApplicationOnExit() Export
	
	Return IsStandaloneWorkplace()
		And Constants.SubordinateDIBNodeSetupCompleted.Get()
		And Constants.SynchronizeDataWithInternetApplicationsOnExit.Get()
		And DataExchangeServer.DataSynchronizationPermitted();
		
EndFunction

// For internal use
// 
Function DefaultDataSynchronizationSchedule() Export // Every hour.
	
	Months = New Array;
	For Cnt = 1 To 12 Do
		Months.Add(Cnt);
	EndDo;
	
	WeekDays = New Array;
	For Cnt = 1 To 7 Do
		WeekDays.Add(Cnt);
	EndDo;
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*60; // 
	Schedule.DaysRepeatPeriod        = 1; // 
	
	Return Schedule;
EndFunction

// For internal use
// 
Function IsStandaloneWorkplace() Export
	
	Return DataExchangeServer.IsStandaloneWorkplace();
	
EndFunction

// For internal use
// 
Function DataExchangeExecutionFormParameters() Export
	
	Return New Structure("InfobaseNode, AccountPasswordRecoveryAddress, CloseOnSynchronizationDone",
		ApplicationInSaaS(), AccountPasswordRecoveryAddress(), True);
EndFunction

// For internal use
// 
Function SynchronizationWithServiceNotExecutedLongTime(Val Interval = 3600) Export // 
	
	Return True;
	
EndFunction

// Determines whether the object can be changed
// An object cannot be written in a standalone workstation if all of the following conditions are met:
//	1. This is standalone workstation.
//	2. This is a shared metadata object.
//	3. This object is included in the exchange plan of the standalone mode.
//	4. The object does not belong to the exception list.
//
// Parameters:
//   MetadataObject - MetadataObject - metadata of the object to be checked
//   ReadOnly - Boolean - if True, the object is read-only.
//
Procedure DefineDataChangeCapability(MetadataObject, ReadOnly) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	
	ReadOnly = IsStandaloneWorkplace()
		And (Not ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject.FullName(),
			ModuleSaaSOperations.MainDataSeparator())
			And Not ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject.FullName(),
				ModuleSaaSOperations.AuxiliaryDataSeparator()))
		And Not MetadataObjectIsException(MetadataObject)
		And Metadata.ExchangePlans[StandaloneModeExchangePlan()].Content.Contains(MetadataObject);
	
EndProcedure

Function BigFilesTransferSupported() Export
	
	ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
	CTLVersion = ModuleSaaSTechnology.LibraryVersion();
	
	Return CommonClientServer.CompareVersions(CTLVersion, "1.2.2.24") >= 0;
	
EndFunction

Procedure DeleteObsoleteExchangeMessages(StandaloneWorkstation) Export 
	
	StandaloneWorkstationNodeCode = Common.ObjectAttributeValue(StandaloneWorkstation, "Code");
	
	Query = New Query;
	Query.SetParameter("NodeCode", "%" + StandaloneWorkstationNodeCode + "%");
	
	Query.Text = 
	"SELECT
	|	DataAreasDataExchangeMessages.MessageID AS MessageID,
	|	DataAreasDataExchangeMessages.MessageFileName AS FileName,
	|	DataAreasDataExchangeMessages.MessageStoredDate AS MessageStoredDate
	|FROM
	|	InformationRegister.DataAreasDataExchangeMessages AS DataAreasDataExchangeMessages
	|WHERE
	|	DataAreasDataExchangeMessages.MessageFileName LIKE &NodeCode";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	TempFilesStorageDirectory = DataExchangeServer.TempFilesStorageDirectory();
	EventLogEvent = NStr("en = 'Data exchange';", Common.DefaultLanguageCode());
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		MessageFileFullName = CommonClientServer.GetFullFileName(
			TempFilesStorageDirectory, Selection.FileName);
		
		MessageFile = New File(MessageFileFullName);
		FileDeleted = True;
		
		If MessageFile.Exists() Then
			
			Try
				DeleteFiles(MessageFile.FullName);
			Except
				
				FileDeleted = False;
				
				WriteLogEvent(
					EventLogEvent,
					EventLogLevel.Error,
					,
					,
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			EndTry;
			
		EndIf;
		
		RecordStructure = New Structure();
		RecordStructure.Insert("MessageID", Selection.MessageID);
		
		If FileDeleted Then
			InformationRegisters.DataAreasDataExchangeMessages.DeleteRecord(RecordStructure);
		Else 
			
			RecordStructure.Insert("MessageFileName", Selection.FileName);
			RecordStructure.Insert("MessageStoredDate", Selection.MessageStoredDate - 60 * 60 * 24);
			
			InformationRegisters.DataAreasDataExchangeMessages.AddRecord(RecordStructure);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function UseOptimizedStandaloneWorkstationCreationWriting() Export 
	
	Return GetFunctionalOption("UseOptimizedStandaloneWorkstationCreationWriting");
	
EndFunction

Procedure OpenRecordInitialImageData(Recipient) Export 
	
	ExportingParameters = Recipient.AdditionalProperties.ExportingParameters;
	
	If ExportingParameters.ExportedData <> Undefined Then
		Return;
	EndIf;
	
	If ExportingParameters.UseOptimizedRecord Then
		ExportingParameters.FileNumber = ExportingParameters.FileNumber + 1;
		DataFileName = StrTemplate("data_%1.xml", Format(ExportingParameters.FileNumber, "NG=0"));
	Else 
		DataFileName = "data.xml";
	EndIf;
	
	FullDataFileName = CommonClientServer.GetFullFileName(
		ExportingParameters.ArchiveDirectory, DataFileName);
	
	DestinationStream = FileStreams.Create(FullDataFileName);

	ExportedData = New XMLWriter;
	ExportedData.OpenStream(DestinationStream);
	
	ExportedData.WriteXMLDeclaration();
	ExportedData.WriteStartElement("Data");
	ExportedData.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	ExportedData.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	ExportedData.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
	
	ExportingParameters.ExportedData = ExportedData;
	ExportingParameters.DestinationStream = DestinationStream;
	ExportingParameters.DataFileName = FullDataFileName;
	
EndProcedure

Procedure WriteInitialImageDataElement(DataElement, MetadataProperties1, Recipient) Export 
	
	ExportingParameters = Recipient.AdditionalProperties.ExportingParameters;
	
	WriteXML(ExportingParameters.ExportedData, DataElement);
	
	If ExportingParameters.UseOptimizedRecord Then
		
		WrittenItems = ?(MetadataProperties1.IsRecordSet, DataElement.Count(), 1);
		ExportingParameters.WrittenItems = ExportingParameters.WrittenItems + WrittenItems;
		ExportingParameters.WrittenItemsAfterCheckFileSize
			= ExportingParameters.WrittenItemsAfterCheckFileSize + WrittenItems;
	
	EndIf;
	
EndProcedure

Procedure CloseInitialImageDataWrite(Recipient, InitialImageFormed = False) Export 
	
	ExportingParameters = Recipient.AdditionalProperties.ExportingParameters;
	CloseRecord = False;
	
	If InitialImageFormed Then
		CloseRecord = True;
	ElsIf ExportingParameters.UseOptimizedRecord Then
		
		If ExportingParameters.WrittenItems >= ExportingParameters.MaximumNumberOfElements Then
			CloseRecord = True;
		ElsIf ExportingParameters.WrittenItemsAfterCheckFileSize >= ExportingParameters.NumberofItemsFileSizeCheck Then
			
			DataFile = New File(ExportingParameters.DataFileName);
			If DataFile.Exists() And DataFile.Size() >= ExportingParameters.MaxFileSize Then
				CloseRecord = True;
			EndIf;
			
			ExportingParameters.WrittenItemsAfterCheckFileSize = 0;
			
		EndIf;
		
	EndIf;
	
	If Not CloseRecord Then
		Return;
	EndIf;
	
	If ExportingParameters.ExportedData <> Undefined Then
		
		ExportingParameters.ExportedData.WriteEndElement(); // Data
		ExportingParameters.ExportedData.Close();
		
		ExportingParameters.ExportedData = Undefined;
		
	EndIf;
	
	If ExportingParameters.DestinationStream <> Undefined Then
		
		ExportingParameters.DestinationStream.Close();
		
		ExportingParameters.DestinationStream = Undefined;
		
	EndIf;
	
	If ExportingParameters.UseOptimizedRecord And ExportingParameters.WrittenItems > 0 Then
		
		ExportingParameters.WrittenItems = 0;
		ExportingParameters.WrittenItemsAfterCheckFileSize = 0;
		
		ArchiveFileName = StrTemplate("data_%1.zip", Format(ExportingParameters.FileNumber, "NG=0"));
		FullArchiveFileName = CommonClientServer.GetFullFileName(
			ExportingParameters.ArchiveDirectory, ArchiveFileName);
			
		Archiver = New ZipFileWriter(FullArchiveFileName,,,, ZIPCompressionLevel.Maximum);
		Archiver.Add(ExportingParameters.DataFileName);
		Archiver.Write();
		
		Try
			DeleteFiles(ExportingParameters.DataFileName);
		Except
			WriteLogEvent(
				StandaloneWorkstationCreationEventLogMessageText(),
				EventLogLevel.Error,
				,
				,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetRegistersTotalsUsage(Flagusage)
	
	SessionDate = CurrentSessionDate();
	AccumulationRegisterPeriod  = EndOfMonth(AddMonth(SessionDate, -1)); // 
	AccountingRegisterPeriod = EndOfMonth(SessionDate); // 
	
	KindBalance = Metadata.ObjectProperties.AccumulationRegisterType.Balance;
	
	For Each MetadataRegister In Metadata.AccumulationRegisters Do
		
		If MetadataRegister.RegisterType <> KindBalance Then
			Continue;
		EndIf;
		
		AccumulationRegisterManager = AccumulationRegisters[MetadataRegister.Name];
		
		AccumulationRegisterManager.SetTotalsUsing(Flagusage);
		AccumulationRegisterManager.SetPresentTotalsUsing(Flagusage);
		
		If Flagusage Then
			AccumulationRegisterManager.SetMaxTotalsPeriod(AccumulationRegisterPeriod);
			AccumulationRegisterManager.RecalcPresentTotals();
		EndIf;
		
	EndDo;
	
	For Each MetadataRegister In Metadata.AccountingRegisters Do
		
		AccountingRegisterManager = AccountingRegisters[MetadataRegister.Name];
		
		AccountingRegisterManager.SetTotalsUsing(Flagusage);
		AccountingRegisterManager.SetPresentTotalsUsing(Flagusage);
		
		If Flagusage Then
			AccountingRegisterManager.SetMaxTotalsPeriod(AccountingRegisterPeriod);
			AccountingRegisterManager.RecalcPresentTotals();
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsDIBNodeInitialImageObject(Val Object)
	
	If DataExchangeCached.StandaloneModeSupported() Then
		RegistrationMode = StandardSubsystemsCached.ExchangePlanDataRegistrationMode(
			Object.FullName(), DataExchangeCached.StandaloneModeExchangePlan());
		If RegistrationMode = "AutoRecordDisabled" Then
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// For internal use
// 
Function DefaultStandaloneWorkstationDescription()
	
	Result = NStr("en = 'Standalone mode - %1';");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(Result, UserFullName());
	
EndFunction

// For internal use
// 
Function StandaloneWorkstationPrefixAllowedChars()
	
	Return NStr("en = 'ABCDEFGHIKLMNOPQRSTVXYZabcdefghiklmnopqrstvxyz';"); // 54 characters.
	
EndFunction

// For internal use
// 
Procedure DoImportParametersFromInitialImage()
	
	Parameters = GetParametersFromInitialImage();
	
	MasterNodeRef = ExchangePlans.MasterNode();
	Try
		ExchangePlans.SetMasterNode(Undefined);
	Except
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise NStr("en = 'The infobase might be opened in Designer mode.
		|Close Designer and restart the application.';");
	EndTry;
	
	BeginTransaction();
	Try
		ChangeSeparationUsage(True, Parameters.DataArea);
		
		MainNodeObject = MasterNodeRef.GetObject();
		MainNodeObject.DataExchange.Load = True;
		MainNodeObject.AdditionalProperties.Insert("IsSWPMasterNode");
		MainNodeObject.AdditionalProperties.Insert("DeleteSyncSetting");
		MainNodeObject.Delete();
		
		ChangeSeparationUsage(False);
		
		// Creating exchange plan nodes for standalone mode in the zero data area.
		StandaloneWorkstationNode = ExchangePlans[StandaloneModeExchangePlan()].ThisNode().GetObject();
		StandaloneWorkstationNode.Code          = Parameters.StandaloneWorkstationCode;
		StandaloneWorkstationNode.Description = Parameters.StandaloneWorkstationDescription;
		StandaloneWorkstationNode.AdditionalProperties.Insert("GettingExchangeMessage");
		StandaloneWorkstationNode.Write();
		
		ApplicationNodeInSaaS = ExchangePlans[StandaloneModeExchangePlan()].CreateNode();
		ApplicationNodeInSaaS.SetNewObjectRef(MasterNodeRef);
		ApplicationNodeInSaaS.Code          = Parameters.ApplicationCodeInSaaS;
		ApplicationNodeInSaaS.Description = Parameters.ApplicationDescriptionInSaaS;
		ApplicationNodeInSaaS.AdditionalProperties.Insert("GettingExchangeMessage");
		ApplicationNodeInSaaS.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	// 
	ExchangePlans.SetMasterNode(MasterNodeRef);
	StandardSubsystemsServer.SaveMasterNode();
	
	BeginTransaction();
	Try
		Constants.UseDataSynchronization.Set(True);
		Constants.SubordinateDIBNodeSettings.Set("");
		Constants.DistributedInfobaseNodePrefix.Set(Parameters.Prefix);
		Constants.SynchronizeDataWithInternetApplicationsOnStart.Set(True);
		Constants.SynchronizeDataWithInternetApplicationsOnExit.Set(True);
		Constants.SystemTitle.Set(Parameters.SystemTitle);
		
		Constants.IsStandaloneWorkplace.Set(True);
		Constants.UseSeparationByDataAreas.Set(False);
		
		ConstantName = StandaloneMode.ConstantNameArmBasicFunctionality();
		If Metadata.Constants.Find(ConstantName) <> Undefined Then
			
			Constants[ConstantName].Set(True);
			
		EndIf;
		
		// 
		Constants.SubordinateDIBNodeSetupCompleted.Set(True);
		
		// Adding a record to exchange transport information register.
		RecordStructure = New Structure;
		RecordStructure.Insert("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
		RecordStructure.Insert("WSUseLargeVolumeDataTransfer", True);
		RecordStructure.Insert("WSWebServiceURL", Parameters.URL);
		RecordStructure.Insert("Peer", ApplicationInSaaS());
		
		InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
		
		// 
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInSaaS());
		RecordStructure.Insert("SettingCompleted", True);
		RecordStructure.Insert("Prefix", Parameters.Prefix);
		If Parameters.Property("ApplicationPrefixSaaS") Then
			RecordStructure.Insert("CorrespondentPrefix", Parameters.ApplicationPrefixSaaS);
		EndIf;
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "CommonInfobasesNodesSettings");
		
		// 
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInSaaS());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataExport);
		RecordStructure.Insert("EndDate", Parameters.InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangesStates.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", ApplicationInSaaS());
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataImport);
		RecordStructure.Insert("EndDate", Parameters.InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangesStates.AddRecord(RecordStructure);
		
		// 
		// 
		ScheduledJobsServer.SetScheduledJobUsage(Metadata.ScheduledJobs.DataSynchronizationWithWebApplication, False);
		ScheduledJobsServer.SetJobSchedule(Metadata.ScheduledJobs.DataSynchronizationWithWebApplication, DefaultDataSynchronizationSchedule());
		
		// Creating an infobase user and linking it to the Users catalog user.
		Roles = New Array;
		Roles.Add("SystemAdministrator");
		Roles.Add("FullAccess");
		
		IBUserDetails = New Structure;
		IBUserDetails.Insert("Action", "Write");
		IBUserDetails.Insert("Name",       Parameters.OwnerName);
		IBUserDetails.Insert("Roles",      Roles);
		IBUserDetails.Insert("StandardAuthentication", True);
		IBUserDetails.Insert("ShowInList", True);
		
		User = Catalogs.Users.GetRef(New UUID(Parameters.Owner)).GetObject();
		
		If User = Undefined Then
			Raise NStr("en = 'User identification failed.
				|The Users catalog might not be included in the exchange plan of the standalone mode.';");
		EndIf;
		
		SetUserPasswordMinLength(0);
		SetUserPasswordStrengthCheck(False);
		
		User.IsInternal = False;
		User.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
		User.AdditionalProperties.Insert("CreateAdministrator",
			NStr("en = 'Initial standalone workstation setup.';"));
		User.Write();
		
		ExchangePlans.DeleteChangeRecords(ApplicationNodeInSaaS.Ref);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use
// 
Procedure SetUpMessagesArchiving()
	
	Settings = InformationRegisters.ExchangeMessageArchiveSettings.CreateRecordManager();
	Settings.InfobaseNode = ApplicationInSaaS();
	Settings.FilesCount = 1;
	Settings.StoreOnDisk = False;
	Settings.ShouldCompressFiles = True;
	Settings.Write();	
	
EndProcedure

Function ChangeSeparationUsage(Use, DataArea = 0)
	
	If Not Use Then
		SessionParameters.DataAreaValue      = DataArea;
		SessionParameters.DataAreaUsage = Use;
	EndIf;
	
	ValueManager = Constants.UseSeparationByDataAreas.CreateValueManager();
	ValueManager.DataExchange.Load = True;
	ValueManager.Value = Use;
	ValueManager.Write();
	
	If Use Then
		SessionParameters.DataAreaValue      = DataArea;
		SessionParameters.DataAreaUsage = Use;
	EndIf;
	
	RefreshReusableValues();
	
EndFunction

// For internal use
// 
Procedure ImportInitialImageData()
	
	InfobaseDirectory = CommonClientServer.FileInfobaseDirectory();
	DataFileList = GetOrderedListDataFiles(InfobaseDirectory);
	
	If DataFileList = Undefined Then
	
		InitialImageDataFileName = CommonClientServer.GetFullFileName(
			InfobaseDirectory,
			"data.xml");
		
		InitialImageDataFile = New File(InitialImageDataFileName);
		If Not InitialImageDataFile.Exists() Then
			Return; // Initial image data was successfully imported earlier
		EndIf;
		
		DataFileList = New Array();
		DataFileList.Add(InitialImageDataFile.FullName);
		
	EndIf;
	
	DataExchangeInternal.DisableAccessKeysUpdate(True, False);
	SetRegistersTotalsUsage(False);
	
	//  
	// 
	// 
	// 
	SetsOfAccountingRegisters = New Array;
	
	For Each DataFileName In DataFileList Do
		
		InitialImageData = New XMLReader;
		InitialImageData.OpenFile(DataFileName);
		InitialImageData.Read();
		InitialImageData.Read();
		
		Try
			
			While CanReadXML(InitialImageData) Do
				
				DataElement = ReadXML(InitialImageData);
				DataElement.AdditionalProperties.Insert("InitialImageCreating");
				
				DataElement.DataExchange.Load = True;
				DataElement.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				
				If Common.IsAccountingRegister(DataElement.Metadata()) Then
					SetsOfAccountingRegisters.Add(DataElement);
				Else
					DataElement.Write();
				EndIf;
				
			EndDo;
			
			For Each Set In SetsOfAccountingRegisters Do
				Set.Write();
			EndDo;
			
		Except
			
			DataExchangeInternal.DisableAccessKeysUpdate(False, False);
			
			WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			InitialImageData = Undefined;
			Raise;
		EndTry;
		
		InitialImageData.Close();
		
		Try
			DeleteFiles(DataFileName);
		Except
			WriteLogEvent(StandaloneWorkstationCreationEventLogMessageText(),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
	SetRegistersTotalsUsage(True);
	DataExchangeInternal.DisableAccessKeysUpdate(False, False);
	
EndProcedure

Function GetOrderedListDataFiles(InfobaseDirectory)
	
	FoundDataArchiveFiles = FindFiles(InfobaseDirectory, "data_*.zip", False);
	
	If FoundDataArchiveFiles.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	NumberType = New TypeDescription("Number", New NumberQualifiers(10, 0, AllowedSign.Nonnegative));
	
	TableOfFiles = New ValueTable;
	TableOfFiles.Columns.Add("FileName");
	TableOfFiles.Columns.Add("FileNumber", NumberType);
	
	For Each DataArchiveFile In FoundDataArchiveFiles Do
		
		FileNameParts = StrSplit(DataArchiveFile.BaseName, "_", False);
		If FileNameParts.Count() <> 2 Then
			Raise NStr("en = 'File name invalid format';");
		EndIf;
		
		FileNumber = NumberType.AdjustValue(FileNameParts[1]);
		If FileNumber = 0 Then
			Raise NStr("en = 'File name invalid format';");
		EndIf;
		
		ReadingArchive = New ZipFileReader(DataArchiveFile.FullName);
		ReadingArchive.ExtractAll(InfobaseDirectory);
		ReadingArchive.Close();
		
		TableRow = TableOfFiles.Add();
		TableRow.FileName = CommonClientServer.GetFullFileName(
			InfobaseDirectory, DataArchiveFile.BaseName + ".xml");
		TableRow.FileNumber = FileNumber;
		
		Try
			DeleteFiles(DataArchiveFile.FullName);
		Except
			WriteLogEvent(
				StandaloneWorkstationCreationEventLogMessageText(),
				EventLogLevel.Error,
				,
				,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
	TableOfFiles.Sort("FileNumber");
	
	ListOfFiles = New Array();
	For Each TableRow In TableOfFiles Do
		ListOfFiles.Add(TableRow.FileName);
	EndDo;
	
	Return ListOfFiles;
	
EndFunction

// For internal use
// 
Function GetParametersFromInitialImage()
	
	XMLLine = Constants.SubordinateDIBNodeSettings.Get();
	
	If IsBlankString(XMLLine) Then
		Raise NStr("en = 'Settings were not transferred to a standalone workstation.
									|Cannot work with the standalone workstation.';");
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLLine);
	
	XMLReader.Read(); // Параметры
	FormatVersion = XMLReader.GetAttribute("FormatVersion");
	
	XMLReader.Read(); // ПараметрыАвтономногоРабочегоМеста
	
	Result = ReadDataToStructure(XMLReader);
	
	XMLReader.Close();
	
	Return Result;
EndFunction

// For internal use
// 
Function ReadDataToStructure(XMLReader)
	
	// Function return value.
	Result = New Structure;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'XML reading error';");
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		Var_Key = XMLReader.Name;
		
		Result.Insert(Var_Key, ReadXML(XMLReader));
		
	EndDo;
	
	XMLReader.Read();
	
	Return Result;
EndFunction

// For internal use
// 
Function DataSynchronizationEventLogEvent()
	
	Return NStr("en = 'Standalone mode.Data synchronization';", Common.DefaultLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// The function checks whether a passed object is included in the exception list.
Function MetadataObjectIsException(Val MetadataObject)
	
	// Safe password storage.
	If MetadataObject = Metadata.InformationRegisters.SafeDataStorage Then
		Return True;
	EndIf;
	
	// 
	// 
	// 
	// 
	If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
		Return True;
	EndIf;
	
	Return IsDIBNodeInitialImageObject(MetadataObject);
	
EndFunction

#EndRegion