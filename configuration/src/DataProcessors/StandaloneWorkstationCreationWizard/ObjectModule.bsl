///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Creates an initial image of a standalone workstation
// according to the passed settings and puts it to the temporary storage.
// 
// Parameters:
//  Settings - Structure - filter settings on the node.
//  SelectedSynchronizationUsers - Array of CatalogRef.Users
//  InitialImageTempStorageAddress - String
//  InstallationPackageInformationTempStorageAddress - String
// 
Procedure CreateStandaloneWorkstationInitialImage(
		Val Settings,
		Val SelectedSynchronizationUsers,
		Val InitialImageTempStorageAddress,
		Val InstallationPackageInformationTempStorageAddress) Export
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Assigning rights to perform synchronization to selected users
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
			CommonModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
			
			For Each User In SelectedSynchronizationUsers Do
				
				CommonModuleAccessManagementInternal.AddUserToAccessGroup(User,
					DataExchangeServer.DataSynchronizationWithOtherApplicationsAccessProfile());
			EndDo;
			
		EndIf;
		
		// Generating a prefix for a new standalone workstation
		Block = New DataLock;
		LockItem = Block.Add("Constant.LastStandaloneWorkstationPrefix");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		LastPrefix = Constants.LastStandaloneWorkstationPrefix.Get();
		StandaloneWorkstationPrefix = StandaloneModeInternal.GenerateStandaloneWorkstationPrefix(LastPrefix);
		
		Constants.LastStandaloneWorkstationPrefix.Set(StandaloneWorkstationPrefix);
		
		// Creating a standalone workstation node
		StandaloneWorkstation = NewStandaloneWorkstation(Settings);
		
		InitialImageCreationDate = CurrentSessionDate();
		
		// Exporting settings to an initial image of the standalone workstation
		ImportParametersToInitialImage(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation);
		
		// Setting an initial image creation date as the date of the first successful synchronization.
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", StandaloneWorkstation);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataExport);
		RecordStructure.Insert("EndDate", InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangesStates.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", StandaloneWorkstation);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsOnExchange.DataImport);
		RecordStructure.Insert("EndDate", InitialImageCreationDate);
		InformationRegisters.SuccessfulDataExchangesStates.AddRecord(RecordStructure);
		
		DataExchangeServer.CompleteInitialImageCreation(StandaloneWorkstation);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	WriteInitialImageofAutonomousWorkplace(
		InitialImageTempStorageAddress,
		InstallationPackageInformationTempStorageAddress);
	
EndProcedure

#EndRegion

#Region Private

Procedure WriteInitialImageofAutonomousWorkplace(
		InitialImageTempStorageAddress,
		InstallationPackageInformationTempStorageAddress)
	
	StandaloneWorkstationNodeCode = Common.ObjectAttributeValue(StandaloneWorkstation, "Code");
		
	InitialImageDirectory = CommonClientServer.GetFullFileName(
		DataExchangeServer.TempFilesStorageDirectory(),
		StrReplace("Replica_{GUID}", "GUID", StandaloneWorkstationNodeCode));
	InitialImageDirectoryID = DataExchangeServer.PutFileInStorage(InitialImageDirectory);
	
	InstallPackageFileName = CommonClientServer.GetFullFileName(
		DataExchangeServer.TempFilesStorageDirectory(),
		StrReplace("Replica_{GUID}.zip", "GUID", StandaloneWorkstationNodeCode));
	InstallationPackageFileID = DataExchangeServer.PutFileInStorage(InstallPackageFileName);
	
	WriteParameters = StructureSettingsPacketRecords();
	WriteParameters.StartImageAddress = InitialImageTempStorageAddress;
	WriteParameters.AddressInfoPacketSettings = InstallationPackageInformationTempStorageAddress;
	WriteParameters.InitialImageDirectory = InitialImageDirectory;
	WriteParameters.InitialImageDirectoryID = InitialImageDirectoryID;
	WriteParameters.InstallPackageFileName = InstallPackageFileName;
	WriteParameters.InstallationPackageFileID = InstallationPackageFileID;
	
	Try
		
		WriteInstallationPackageToTempStorage(WriteParameters);
		
	Except
		
		WriteLogEvent(
			EventLogEvent(),
			EventLogLevel.Error,
			,
			,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		FilesToBeDeleted = New Array();
		FilesToBeDeleted.Add(
			FileDeleteParameterStructure(InitialImageDirectory, InitialImageDirectoryID));
		FilesToBeDeleted.Add(
			FileDeleteParameterStructure(InstallPackageFileName, InstallationPackageFileID));
		
		For Each DeletionParameters In FilesToBeDeleted Do
			
			Try
				DataExchangeServer.GetFileFromStorage(DeletionParameters.Id);
				DeleteFiles(DeletionParameters.FileName);
			Except
				WriteLogEvent(
					EventLogEvent(),
					EventLogLevel.Error,
					,
					,
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		EndDo;
		
		Raise;
		
	EndTry;
	
EndProcedure

Procedure WriteInstallationPackageToTempStorage(WriteParameters)
		
	InstallationDirectory = CommonClientServer.GetFullFileName(WriteParameters.InitialImageDirectory, "1");
	ArchiveDirectory = CommonClientServer.GetFullFileName(InstallationDirectory, "InfoBase");
	
	CreateDirectory(ArchiveDirectory);
	
	// Create an initial image of the standalone workstation.
	ConnectionString = "File = ""&InfobaseDirectory""";
	ConnectionString = StrReplace(
		ConnectionString, "&InfobaseDirectory", TrimAll(WriteParameters.InitialImageDirectory));
	
	ExportingParameters = DataUploadParameterStructure();
	ExportingParameters.ArchiveDirectory = ArchiveDirectory;
	
	StandaloneWorkstationObject = StandaloneWorkstation.GetObject();
	StandaloneWorkstationObject.AdditionalProperties.Insert("AllocateFilesToInitialImage");
	StandaloneWorkstationObject.AdditionalProperties.Insert("MetadataProperties1", New Map);
	StandaloneWorkstationObject.AdditionalProperties.Insert("ExportingParameters", ExportingParameters);
	
	// 
	DataExchangeInternal.CheckObjectsRegistrationMechanismCache();
	
	Try
		ExchangePlans.CreateInitialImage(StandaloneWorkstationObject, ConnectionString);
		// 
		Constants.SubordinateDIBNodeSettings.Set("");
	Except
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		// 
		Constants.SubordinateDIBNodeSettings.Set("");
		
		ExportingParameters.ExportedData = Undefined;
		ExportingParameters.DestinationStream = Undefined;
		
		// 
		StandaloneModeInternal.DeleteStandaloneWorkstation1(New Structure("StandaloneWorkstation", StandaloneWorkstation), "");
		
		Raise;
	EndTry;
	
	StandaloneModeInternal.CloseInitialImageDataWrite(StandaloneWorkstationObject, True);
	
	InitialImageFileName = CommonClientServer.GetFullFileName(
		WriteParameters.InitialImageDirectory, "1Cv8.1CD");
	
	InitialImageFileNameInArchiveDirectory = CommonClientServer.GetFullFileName(
		ArchiveDirectory, "1Cv8.1CD");
	
	InstructionFileName = CommonClientServer.GetFullFileName(
		ArchiveDirectory, "ReadMe.html");
	
	InstructionText = StandaloneModeInternal.InstructionTextFromTemplate("SWSetupInstruction");
	
	Text = New TextWriter(InstructionFileName, TextEncoding.UTF8);
	Text.Write(InstructionText);
	Text.Close();
	
	MoveFile(InitialImageFileName, InitialImageFileNameInArchiveDirectory);
	
	Archiver = New ZipFileWriter(WriteParameters.InstallPackageFileName, , , , ZIPCompressionLevel.Maximum);
	Archiver.Add(
		CommonClientServer.GetFullFileName(InstallationDirectory, "*.*"),
		ZIPStorePathMode.StoreRelativePath,
		ZIPSubDirProcessingMode.ProcessRecursively);
	Archiver.Write();
	
	Try
		DataExchangeServer.GetFileFromStorage(WriteParameters.InitialImageDirectoryID);
		DeleteFiles(WriteParameters.InitialImageDirectory);
	Except
		WriteLogEvent(
			EventLogEvent(),
			EventLogLevel.Error,
			,
			,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	InstallationPackageFile = New File(WriteParameters.InstallPackageFileName);
	
	FileData = Undefined;
	
	InstallPackageInformation = New Structure;
	InstallPackageInformation.Insert("InstallPackageFileSize", InstallationPackageFile.Size());
	InstallPackageInformation.Insert("InstallPackageFileName", StandaloneModeInternal.InstallPackageFileName());
	
	If StandaloneModeInternal.BigFilesTransferSupported() Then
		
		FileData = New Structure;
		FileData.Insert("InstallationPackageFileID", WriteParameters.InstallationPackageFileID);
		FileData.Insert("FileNameOrAddress", InstallationPackageFile.Name);
		FileData.Insert("WindowsFilePath", Constants.DataExchangeMessageDirectoryForWindows.Get());
		FileData.Insert("LinuxFilePath",   Constants.DataExchangeMessageDirectoryForLinux.Get());
		
	Else
		
		FileData = New BinaryData(WriteParameters.InstallPackageFileName);
		
		Try
			DataExchangeServer.GetFileFromStorage(WriteParameters.InstallationPackageFileID);
			DeleteFiles(WriteParameters.InstallPackageFileName);
		Except
			WriteLogEvent(
				EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
			
	EndIf;
	
	PutToTempStorage(FileData, WriteParameters.StartImageAddress);
	PutToTempStorage(InstallPackageInformation, WriteParameters.AddressInfoPacketSettings);
	
EndProcedure

Procedure ImportParametersToInitialImage(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation)
	
	Constants.SubordinateDIBNodeSettings.Set(ExportParametersToXMLString(StandaloneWorkstationPrefix, InitialImageCreationDate, StandaloneWorkstation));
	
EndProcedure

Function NewStandaloneWorkstation(Settings)
	
	// Updating SaaS application node if necessary
	If IsBlankString(Common.ObjectAttributeValue(StandaloneModeInternal.ApplicationInSaaS(), "Code")) Then
		
		ApplicationInSaaSObject = CreateApplicationInSaaS();
		ApplicationInSaaSObject.DataExchange.Load = True;
		ApplicationInSaaSObject.Write();
		
	EndIf;
	
	// Creating a standalone workstation node
	StandaloneWorkstationObject = CreateStandaloneWorkstation();
	StandaloneWorkstationObject.Description = StandaloneWorkstationDescription;
	StandaloneWorkstationObject.RegisterChanges = True;
	StandaloneWorkstationObject.DataExchange.Load = True;
	
	// 
	DataExchangeEvents.SetNodeFilterValues(StandaloneWorkstationObject, Settings);
	
	StandaloneWorkstationObject.Write();
	
	DataExchangeServer.CompleteDataSynchronizationSetup(StandaloneWorkstationObject.Ref);
	
	Return StandaloneWorkstationObject.Ref;
	
EndFunction

Function ExportParametersToXMLString(StandaloneWorkstationPrefix, Val InitialImageCreationDate, StandaloneWorkstation)
	
	StandaloneWorkstationParameters = Common.ObjectAttributesValues(StandaloneWorkstation, "Code, Description");
	ApplicationParametersInSaaS = Common.ObjectAttributesValues(StandaloneModeInternal.ApplicationInSaaS(), "Code, Description");
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("Parameters");
	XMLWriter.WriteAttribute("FormatVersion", ExchangeDataSettingsFileFormatVersion());
	
	XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	XMLWriter.WriteStartElement("StandaloneWorkstationParameters");
	
	WriteXML(XMLWriter, InitialImageCreationDate,    "InitialImageCreationDate", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, StandaloneWorkstationPrefix, "Prefix", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, SystemTitle(),              "SystemTitle", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, WebServiceURL,                   "URL", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, InfoBaseUsers.CurrentUser().Name, "OwnerName", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, String(Users.AuthorizedUser().UUID()), "Owner", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, StandaloneWorkstationParameters.Code,          "StandaloneWorkstationCode", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, StandaloneWorkstationParameters.Description, "StandaloneWorkstationDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationParametersInSaaS.Code,                "ApplicationCodeInSaaS", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationParametersInSaaS.Description,       "ApplicationDescriptionInSaaS", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, DataExchangeServer.InfobasePrefix(), "ApplicationPrefixSaaS", XMLTypeAssignment.Explicit);
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		WriteXML(XMLWriter, ModuleSaaSOperations.SessionSeparatorValue(), "DataArea", XMLTypeAssignment.Explicit);
	Else
		WriteXML(XMLWriter, 0, "DataArea", XMLTypeAssignment.Explicit);
	EndIf;
	
	XMLWriter.WriteEndElement(); // ПараметрыАвтономногоРабочегоМеста
	XMLWriter.WriteEndElement(); // Параметры
	
	Return XMLWriter.Close();
	
EndFunction

Function ExchangeDataSettingsFileFormatVersion()
	
	Return "1.0";
	
EndFunction

Function EventLogEvent()
	
	Return StandaloneModeInternal.StandaloneWorkstationCreationEventLogMessageText();
	
EndFunction

Function CreateApplicationInSaaS()
	
	Result = ExchangePlans[StandaloneModeInternal.StandaloneModeExchangePlan()].ThisNode().GetObject();
	Result.Code = String(New UUID);
	Result.Description = GenerateApplicationDescriptionInSaaS();
	
	Return Result;
EndFunction

Function CreateStandaloneWorkstation()
	
	CurrentInfobaseSession1 = GetCurrentInfoBaseSession();
	BackgroundJob = CurrentInfobaseSession1.GetBackgroundJob();
	NodeID = ?(BackgroundJob = Undefined,
		New UUID,
		BackgroundJob.UUID);
	
	Result = ExchangePlans[StandaloneModeInternal.StandaloneModeExchangePlan()].CreateNode();
	Result.Code = String(NodeID);
	
	Return Result;
	
EndFunction

Function GenerateApplicationDescriptionInSaaS()
	
	ApplicationDescription = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 (web application)';"), ApplicationDescription);
	
EndFunction

Function SystemTitle()
	
	Result = "";
	
	If Not Common.DataSeparationEnabled()
		Or Common.SeparatedDataUsageAvailable() Then
		Result = Constants.SystemTitle.Get();
	EndIf;
	
	If IsBlankString(Result) Then
		If Common.SubsystemExists("CloudTechnology") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			Result = ModuleSaaSOperations.GetAppName();
		EndIf;
	EndIf;
	
	Return ?(IsBlankString(Result),
		NStr("en = 'Standalone workstation';"),
		Result);
	
EndFunction

Function StructureSettingsPacketRecords()
	
	WriteParameters = New Structure();
	WriteParameters.Insert("StartImageAddress", Undefined);
	WriteParameters.Insert("AddressInfoPacketSettings", Undefined);
	WriteParameters.Insert("InitialImageDirectory", Undefined);
	WriteParameters.Insert("InitialImageDirectoryID", Undefined);
	WriteParameters.Insert("InstallPackageFileName", Undefined);
	WriteParameters.Insert("InstallationPackageFileID", Undefined);
	
	Return WriteParameters;
	
EndFunction

Function DataUploadParameterStructure()
	
	ExportingParameters = New Structure();
	ExportingParameters.Insert("UseOptimizedRecord",
		StandaloneModeInternal.UseOptimizedStandaloneWorkstationCreationWriting());
	ExportingParameters.Insert("ExportedData", Undefined);
	ExportingParameters.Insert("DestinationStream", Undefined);
	ExportingParameters.Insert("ArchiveDirectory", Undefined);
	ExportingParameters.Insert("DataFileName", Undefined);
	ExportingParameters.Insert("FileNumber", 0);
	ExportingParameters.Insert("WrittenItems", 0);
	ExportingParameters.Insert("WrittenItemsAfterCheckFileSize", 0);
	ExportingParameters.Insert("MaximumNumberOfElements", 50000);
	ExportingParameters.Insert("NumberofItemsFileSizeCheck", 1000);
	ExportingParameters.Insert("MaxFileSize", 1024 * 1024 * 100); // 
	
	Return ExportingParameters;
	
EndFunction

Function FileDeleteParameterStructure(FileName, Id)
	
	Return New FixedStructure(
		"FileName, Id", FileName, Id);
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf