///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "RecordForm" Then
		
		StandardProcessing = False;
		
		If Parameters.Key.RulesKind = Enums.DataExchangeRulesTypes.ObjectsConversionRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectsConversionRules";
			
		ElsIf Parameters.Key.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectsRegistrationRules";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
	
#Region Internal

Function ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription, RulesData) Export
	
	If Not DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch") Then
		Return True;
	EndIf;
	
	NameOfConfigurationFormRules = Upper(RulesData.ConfigurationName);
	InfobaseConfigurationName = StrReplace(Upper(Metadata.Name), "BASIC_SSLY", "");
	If NameOfConfigurationFormRules <> InfobaseConfigurationName Then
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorKind", "InvalidConfiguration");
		ErrorDescription.Insert("Picture",  PictureLib.Error32);
		
		ErrorDescription.Insert("ErrorText",
			NStr("en = 'Rules cannot be imported as they are intended for %1 application. 
			|Use rules from the configuration or import a correct set of rules from file.';"));
		ErrorDescription.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription.ErrorText,
			RulesData.ConfigurationSynonymInRules);
		
		Return False;
		
	EndIf;
	
	VersionInRules    = CommonClientServer.ConfigurationVersionWithoutBuildNumber(RulesData.ConfigurationVersion);
	ConfigurationVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(Metadata.Version);
	ComparisonResult = CommonClientServer.CompareVersionsWithoutBuildNumber(VersionInRules, ConfigurationVersion);
	
	If ComparisonResult <> 0 Then
		
		If ComparisonResult < 0 Then
			
			ErrorText = NStr("en = 'Data might be synchronized incorrectly as rules you want to import are designed for the previous version of %1 application (%2).
			| Use the rules from the configuration or import a set of rules designed for the current application version (%3).';");
			ErrorKind = "ObsoleteRules";
			
		Else
			
			ErrorText = NStr("en = 'Data might be synchronized incorrectly as rules you want to import are designed for a newer version of %1 application (%2).
			| Update version of the application or use a set of rules designed for the current application version (%3).';");
			ErrorKind = "ObsoleteConfigurationVersion";
			
		EndIf;
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
			Metadata.Synonym, VersionInRules, ConfigurationVersion);
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", ErrorText);
		ErrorDescription.Insert("ErrorKind",   ErrorKind);
		ErrorDescription.Insert("Picture",    PictureLib.Warning32);
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion
	
#Region Private

// Imports 1C-supplied rules for the exchange plan.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//  RulesFileName - String - a full name of exchange rules file (ZIP).
//
Procedure ImportSuppliedRules(ExchangePlanName, RulesFileName) Export
	
	File = New File(RulesFileName);
	FileName = File.Name;
	
	// Extract data from archive.
	TempDirectoryName = GetTempFileName("");
	If DataExchangeServer.UnpackZipFile(RulesFileName, TempDirectoryName) Then
		
		UnpackedFileList = FindFiles(TempDirectoryName, GetAllFilesMask(), True);
		
		// Canceling import if the archive contains no files.
		If UnpackedFileList.Count() = 0 Then
			Raise NStr("en = 'Rule file not found in archive.';");
		EndIf;
		
		// Canceling import if number of files in the archive does not match the expected number.
		If UnpackedFileList.Count() <> 3 Then
			Raise NStr("en = 'Invalid rule set. Three files are expected:
			|ExchangeRules.xml. Contains conversion rules for this application.
			|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.
			|RegistrationRules.xml. Contains registration rules for this application.';");
		EndIf;
		
		// Saving received file to the binary data.
		For Each ReceivedFile In UnpackedFileList Do
			
			If ReceivedFile.Name = "ExchangeRules.xml" Then
				BinaryData = New BinaryData(ReceivedFile.FullName);
			ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
				CorrespondentBinaryData = New BinaryData(ReceivedFile.FullName);
			ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
				RegistrationBinaryData = New BinaryData(ReceivedFile.FullName);
			Else
				Raise NStr("en = 'Unexpected file names. Expected files:
				|ExchangeRules.xml. Contains conversion rules for this application.
				|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.
				|RegistrationRules.xml. Contains registration rules for this application.';");
			EndIf;
			
		EndDo;
		
	Else
		// Canceling import if unpacking the file failed.
		Raise NStr("en = 'Extraction failed.';");
	EndIf;
	
	// 
	FileSystem.DeleteTempFile(TempDirectoryName);
	
	ConversionRulesInformation = "[SourceRulesInformation]
		|
		|[CorrespondentRulesInformation]";
		
	// Getting the temporary conversion file name in the local file system at server.
	TempFileName = GetTempFileName("xml");
	
	// 
	BinaryData.Write(TempFileName);
	
	// Read conversion rules.
	InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Upload0", ExchangePlanName);
	
	DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, ExchangePlanName, False);
	
	RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
	
	SourceRulesInformation = InfobaseObjectConversion.RulesInformation(False);
	
	// Getting name of the temporary correspondent conversion file in the local file system on the server.
	CorrespondentTempFileName = GetTempFileName("xml");
	// 
	CorrespondentBinaryData.Write(CorrespondentTempFileName);
	
	// 
	InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Load", ExchangePlanName);
	
	// Data processor methods.
	ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
	
	CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", CorrespondentRulesInformation);
	
	// 
	FileSystem.DeleteTempFile(TempFileName);
	FileSystem.DeleteTempFile(CorrespondentTempFileName);
	
	// Writing conversion rules.
	CovnersionRuleWriting = CreateRecordManager();
	CovnersionRuleWriting.ExchangePlanName = ExchangePlanName;
	CovnersionRuleWriting.RulesKind = Enums.DataExchangeRulesTypes.ObjectsConversionRules;
	CovnersionRuleWriting.RulesTemplateName = "ExchangeRules";
	CovnersionRuleWriting.CorrespondentRulesTemplateName = "CorrespondentExchangeRules";
	CovnersionRuleWriting.ExchangePlanNameFromRules = ExchangePlanName;
	CovnersionRuleWriting.RulesFileName = FileName;
	CovnersionRuleWriting.RulesInformation = ConversionRulesInformation;
	CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File;
	CovnersionRuleWriting.XMLRules = New ValueStorage(BinaryData, New Deflation());
	CovnersionRuleWriting.XMLCorrespondentRules = New ValueStorage(CorrespondentBinaryData, New Deflation());
	CovnersionRuleWriting.RulesAreRead = New ValueStorage(RulesAreRead);
	CovnersionRuleWriting.ReadCorrespondentRules = New ValueStorage(ReadCorrespondentRules);
	CovnersionRuleWriting.DebugMode = False;
	CovnersionRuleWriting.RulesAreImported = True;
	CovnersionRuleWriting.Write();
	
	ImportObjectRegistrationRules(RegistrationBinaryData, FileName, ExchangePlanName);
		
EndProcedure

// 
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan that the rules are being loaded for.
//  RulesFileName - String -
//
Procedure DownloadSuppliedObjectRegistrationRules(ExchangePlanName, RulesFileName) Export
	
	File = New File(RulesFileName);
	FileName = File.Name;
	
	RegistrationBinaryData = New BinaryData(RulesFileName);
	
	ImportObjectRegistrationRules(RegistrationBinaryData, FileName, ExchangePlanName);
	
EndProcedure

Procedure ImportObjectRegistrationRules(BinaryData, FileName, ExchangePlanName)
	
	// 
	TempRegistrationFileName = GetTempFileName("xml");
	// 
	BinaryData.Write(TempRegistrationFileName);
	
	// 
	ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
	
	// 
	ChangeRecordRuleImport.ExchangePlanNameForImport = ExchangePlanName;
	
	// 
	ChangeRecordRuleImport.ImportRules(TempRegistrationFileName);
	ReadRegistrationRules   = ChangeRecordRuleImport.ObjectsRegistrationRules;
	RegistrationRulesInformation = ChangeRecordRuleImport.RulesInformation();
	
	If ChangeRecordRuleImport.FlagErrors Then
		Raise NStr("en = 'An error occurred when importing registration rules.';");
	EndIf;
	
	// 
	FileSystem.DeleteTempFile(TempRegistrationFileName);
	
	// 
	RegistrationRuleWriting = CreateRecordManager();
	RegistrationRuleWriting.ExchangePlanName = ExchangePlanName;
	RegistrationRuleWriting.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	RegistrationRuleWriting.RulesTemplateName = "RecordRules";
	RegistrationRuleWriting.ExchangePlanNameFromRules = ExchangePlanName;
	RegistrationRuleWriting.RulesFileName = FileName;
	RegistrationRuleWriting.RulesInformation = RegistrationRulesInformation;
	RegistrationRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File;
	RegistrationRuleWriting.XMLRules = New ValueStorage(BinaryData, New Deflation());
	RegistrationRuleWriting.RulesAreRead = New ValueStorage(ReadRegistrationRules);
	RegistrationRuleWriting.RulesAreImported = True;
	RegistrationRuleWriting.Write();
	
EndProcedure

// Deletes 1C-supplied rules for the exchange plan (clears data in the register).
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan for which the rules are being deleted.
//
Procedure DeleteSuppliedRules(ExchangePlanName) Export
	
	For Each RulesKind In Enums.DataExchangeRulesTypes Do
		DeleteRules(ExchangePlanName, RulesKind);
	EndDo;
	
EndProcedure

// 
//
// Parameters:
//  ExchangePlanName - String - name of the exchange plan for which the rules are being deleted.
//
Procedure DeleteSuppliedObjectRegistrationRules(ExchangePlanName) Export
	
	DeleteRules(ExchangePlanName, Enums.DataExchangeRulesTypes.ObjectsRegistrationRules);
	
EndProcedure

Procedure DeleteRules(ExchangePlanName, RulesKind)
	
	RecordManager = CreateRecordManager();
	RecordManager.RulesKind = RulesKind;
	RecordManager.ExchangePlanName = ExchangePlanName;
	RecordManager.Read();
	RecordManager.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate;
	HasErrors = False;
	ImportRules(HasErrors, RecordManager);
	If HasErrors Then
		Raise NStr("en = 'An error occurred when importing rules from the configuration.';");
	Else
		RecordManager.Write();
	EndIf;
	
EndProcedure

// Determines whether standard conversion rules are used for the exchange plan.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//
// Returns:
//   Boolean - 
//
Function StandardRulesUsed(ExchangePlanName) Export
	QueryText = "
	|SELECT
	|	DataExchangeRules.XMLRules AS XMLRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind      = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)
	|	AND DataExchangeRules.RulesAreImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return False;
	EndIf;
	Selection = Result.Select();
	Selection.Next();
	
	RuleBinaryData = Selection.XMLRules.Get(); // BinaryData
	TempFileName = GetTempFileName("xml");
	RuleBinaryData.Write(TempFileName);
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(TempFileName);
	StandardRules = False;
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If NodeName = "FormatVersion" Then
			While ExchangeRules.ReadAttribute() Do
				If ExchangeRules.LocalName = "Standard3" Then
					StandardRules = True;
					Break;
				EndIf;
			EndDo;
			Break;
		EndIf;
	EndDo;
	ExchangeRules.Close();
	DeleteFiles(TempFileName);
	
	Return StandardRules;
EndFunction

// Parameters:
//   ExchangeMode - String
//   ExchangePlanName - String
//
// Returns:
//   DataProcessorObject.InfobaseObjectConversion
//
Function NewDataProcessorInfobaseObjectConversion(ExchangeMode, ExchangePlanName)
	
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	InfobaseObjectConversion.ExchangeMode = ExchangeMode;
	InfobaseObjectConversion.ExchangePlanNameSOR = ExchangePlanName;
	
	InfobaseObjectConversion.SetEventLogMessageKey(
		DataExchangeServer.DataExchangeRulesImportEventLogEvent());
		
	Return InfobaseObjectConversion;
	
EndFunction

// Imports rules to the register.
//
// Parameters:
//  Cancel - Boolean - cancel recording.
//  Record - InformationRegisterRecord.DataExchangeRules - register record where data will be placed.
//  TempStorageAddress - String - an address of temporary storage, from which XML rules are imported.
//  RulesFileName - String - a name of the file, from which the files are imported (it is also written to the register).
//  BinaryData - BinaryData - data that will store the XML file (including XML files unpacked from a ZIP archive).
//  IsArchive - Boolean - indicates that rules are imported from a ZIP archive, not from an XML file.
//
Procedure ImportRules(Cancel, Record, TempStorageAddress = "", RulesFileName = "", IsArchive = False) Export
	
	// Checking if the exchange plan exists.
	ExchangePlansList = DataExchangeCached.SSLExchangePlans();
	If ExchangePlansList.Find(Record.ExchangePlanName) = Undefined Then
		NString = NStr("en = 'Exchange plan %1 is not used for data synchronization, the rules are not updated.';");
		NString = StringFunctionsClientServer.SubstituteParametersToString(NString, Record.ExchangePlanName);
		DataExchangeServer.ReportError(NString, Cancel);
	Else
		// Checking whether record mandatory fields are filled.
		CheckFieldsFilled(Cancel, Record);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	AreConversionRules = (Record.RulesKind = Enums.DataExchangeRulesTypes.ObjectsConversionRules);
	
	// Getting rule binary data from file or configuration template.
	If Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate Then
		
		BinaryData = BinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RulesTemplateName);
		
		If AreConversionRules Then
			
			If IsBlankString(Record.CorrespondentRulesTemplateName) Then
				Record.CorrespondentRulesTemplateName = Record.RulesTemplateName + "Correspondent";
			EndIf;
			CorrespondentBinaryData = BinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.CorrespondentRulesTemplateName);
			
		EndIf;
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	// If rules are packed into an archive, unpacking the archive and converting the rules data to binary.
	If IsArchive Then
		
		// Getting the archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extract data from archive.
		TempDirectoryName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempDirectoryName) Then
			
			UnpackedFileList = FindFiles(TempDirectoryName, GetAllFilesMask(), True);
			
			// Canceling import if the archive contains no files.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en = 'Rule file not found in archive.';");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			If AreConversionRules Then
				
				// Saving received file to the binary data.
				If UnpackedFileList.Count() = 2 Then
					
					If UnpackedFileList[0].Name = "ExchangeRules.xml" 
						And UnpackedFileList[1].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[0].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[1].FullName);
						
					ElsIf UnpackedFileList[1].Name = "ExchangeRules.xml" 
						And UnpackedFileList[0].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[1].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[0].FullName);
						
					Else
						
						NString = NStr("en = 'Unexpected file names. Expected files:
							|ExchangeRules.xml. Contains conversion rules for this application.
							|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.';");
						DataExchangeServer.ReportError(NString, Cancel);
						
					EndIf;
					
				// Obsolete format.
				ElsIf UnpackedFileList.Count() = 1 Then
					NString = NStr("en = 'The archive contains only a conversion rules file. Two files are expected:
						|ExchangeRules.xml. Contains conversion rules for this application.
						|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.';");
					DataExchangeServer.ReportError(NString, Cancel);
				// Canceling import if there are several files in the archive, but a single file is expected.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en = 'Multiple files are found in the archive. Only one file is expected.';");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			Else
				
				// Saving received file to the binary data.
				If UnpackedFileList.Count() = 1 Then
					BinaryData = New BinaryData(UnpackedFileList[0].FullName);
					
				// Canceling import if there are several files in the archive, but a single file is expected.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("en = 'Multiple files are found in the archive. Only one file is expected.';");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			EndIf;
			
		Else // Если не удалось распаковать файл - 
			NString = NStr("en = 'Extraction failed.';");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// 
		FileSystem.DeleteTempFile(TempDirectoryName);
		FileSystem.DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the temporary file name in the local file system on the server.
	TempFileName = GetTempFileName("xml");
	
	// 
	BinaryData.Write(TempFileName);
	
	If AreConversionRules Then
		
		// Read conversion rules.
		InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Upload0", Record.ExchangePlanName);
		
		DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, Record.ExchangePlanName, Record.DebugMode);
		
		// Data processor methods.
		RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
		
		RulesInformation = InfobaseObjectConversion.RulesInformation(False);
		
		If InfobaseObjectConversion.FlagErrors() Then
			Cancel = True;
		EndIf;
		
		// Getting the temporary file name in the local file system on the server.
		CorrespondentTempFileName = GetTempFileName("xml");
		// 
		CorrespondentBinaryData.Write(CorrespondentTempFileName);
		
		// 
		InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Load", Record.ExchangePlanName);
		
		// Data processor methods.
		ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
		
		DeleteFiles(CorrespondentTempFileName);
		
		CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
		
		If InfobaseObjectConversion.FlagErrors() Then
			Cancel = True;
		EndIf;
		
 		RulesInformation = RulesInformation + Chars.LF + Chars.LF + CorrespondentRulesInformation;
		
	Else // ObjectsRegistrationRules
		
		// Read registration rules.
		ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
		
		// 
		ChangeRecordRuleImport.ExchangePlanNameForImport = Record.ExchangePlanName;
		
		// 
		ChangeRecordRuleImport.ImportRules(TempFileName);
		
		RulesAreRead = ChangeRecordRuleImport.ObjectsRegistrationRules;
		
		RulesInformation = ChangeRecordRuleImport.RulesInformation();
		
		If ChangeRecordRuleImport.FlagErrors Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
	// 
	FileSystem.DeleteTempFile(TempFileName);
	
	If Not Cancel Then
		
		Record.XMLRules          = New ValueStorage(BinaryData, New Deflation());
		Record.RulesAreRead   = New ValueStorage(RulesAreRead);
		
		If AreConversionRules Then
			
			Record.XMLCorrespondentRules = New ValueStorage(CorrespondentBinaryData, New Deflation());
			Record.ReadCorrespondentRules = New ValueStorage(ReadCorrespondentRules);
			
		EndIf;
		
		Record.RulesInformation = RulesInformation;
		Record.RulesFileName = RulesFileName;
		Record.RulesAreImported = True;
		Record.ExchangePlanNameFromRules = Record.ExchangePlanName;
		
	EndIf;
	
EndProcedure

Procedure ImportRulesSet(Cancel, DataToWrite, ErrorDescription, TempStorageAddress = "", RulesFileName = "") Export
	
	CovnersionRuleWriting = DataToWrite.CovnersionRuleWriting;
	RegistrationRuleWriting = DataToWrite.RegistrationRuleWriting;
	
	// Getting rule binary data from file or configuration template.
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate Then
		
		BinaryData               = BinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.RulesTemplateName);
		CorrespondentBinaryData = BinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.CorrespondentRulesTemplateName);
		RegistrationBinaryData    = BinaryDataFromConfigurationTemplate(Cancel, RegistrationRuleWriting.ExchangePlanName, RegistrationRuleWriting.RulesTemplateName);
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File Then
		
		// Getting the archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extract data from archive.
		TempDirectoryName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempDirectoryName) Then
			
			UnpackedFileList = FindFiles(TempDirectoryName, GetAllFilesMask(), True);
			
			// Canceling import if the archive contains no files.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("en = 'Rule file not found in archive.';");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			// Canceling import if number of files in the archive does not match the expected number.
			If UnpackedFileList.Count() <> 3 Then
				NString = NStr("en = 'Invalid rule set. Three files are expected:
					|ExchangeRules.xml. Contains conversion rules for this application.
					|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.
					|RegistrationRules.xml. Contains registration rules for this application.';");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
				
			// Saving received file to the binary data.
			For Each ReceivedFile In UnpackedFileList Do
				
				If ReceivedFile.Name = "ExchangeRules.xml" Then
					BinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
					CorrespondentBinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
					RegistrationBinaryData = New BinaryData(ReceivedFile.FullName);
				Else
					NString = NStr("en = 'Unexpected file names. Expected files:
						|ExchangeRules.xml. Contains conversion rules for this application.
					|CorrespondentExchangeRules.xml. Contains conversion rules for the peer application.
					|RegistrationRules.xml. Contains registration rules for this application.';");
					DataExchangeServer.ReportError(NString, Cancel);
					Break;
				EndIf;
				
			EndDo;
			
		Else 
			// Если не удалось распаковать файл - 
			NString = NStr("en = 'Extraction failed.';");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// 
		FileSystem.DeleteTempFile(TempDirectoryName);
		FileSystem.DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	ConversionRulesInformation = "[SourceRulesInformation]
		|
		|[CorrespondentRulesInformation]";
		
	// Getting the temporary conversion file name in the local file system at server.
	TempFileName = GetTempFileName("xml");
	
	// 
	BinaryData.Write(TempFileName);
	
	// Read conversion rules.
	InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Upload0", CovnersionRuleWriting.ExchangePlanName);
	
	DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.DebugMode);
	
	// Data processor methods.
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File And ErrorDescription = Undefined
		And Not ConversionRulesCompatibleWithCurrentVersion(CovnersionRuleWriting.ExchangePlanName, ErrorDescription, RulesInformationFromFile(TempFileName)) Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
	
	SourceRulesInformation = InfobaseObjectConversion.RulesInformation(False);
	
	If InfobaseObjectConversion.FlagErrors() Then
		Cancel = True;
	EndIf;
	
	// Getting name of the temporary correspondent conversion file in the local file system on the server.
	CorrespondentTempFileName = GetTempFileName("xml");
	// 
	CorrespondentBinaryData.Write(CorrespondentTempFileName);
	
	// 
	InfobaseObjectConversion = NewDataProcessorInfobaseObjectConversion("Load", CovnersionRuleWriting.ExchangePlanName);
	
	// Data processor methods.
	ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
	
	CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
	
	If InfobaseObjectConversion.FlagErrors() Then
		Cancel = True;
	EndIf;
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", CorrespondentRulesInformation);
	
	// Getting the temporary registration file name in the local file system on the server.
	TempRegistrationFileName = GetTempFileName("xml");
	// 
	RegistrationBinaryData.Write(TempRegistrationFileName);

	
	// Read registration rules.
	ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
	
	// 
	ChangeRecordRuleImport.ExchangePlanNameForImport = RegistrationRuleWriting.ExchangePlanName;
	
	// 
	ChangeRecordRuleImport.ImportRules(TempRegistrationFileName);
	ReadRegistrationRules   = ChangeRecordRuleImport.ObjectsRegistrationRules;
	RegistrationRulesInformation = ChangeRecordRuleImport.RulesInformation();
	
	If ChangeRecordRuleImport.FlagErrors Then
		Cancel = True;
	EndIf;
	
	// 
	FileSystem.DeleteTempFile(TempFileName);
	FileSystem.DeleteTempFile(CorrespondentTempFileName);
	FileSystem.DeleteTempFile(TempRegistrationFileName);
	
	If Not Cancel Then
		
		// 
		CovnersionRuleWriting.XMLRules                      = New ValueStorage(BinaryData, New Deflation());
		CovnersionRuleWriting.RulesAreRead               = New ValueStorage(RulesAreRead);
		CovnersionRuleWriting.XMLCorrespondentRules        = New ValueStorage(CorrespondentBinaryData, New Deflation());
		CovnersionRuleWriting.ReadCorrespondentRules = New ValueStorage(ReadCorrespondentRules);
		CovnersionRuleWriting.RulesInformation             = ConversionRulesInformation;
		CovnersionRuleWriting.RulesFileName                  = RulesFileName;
		CovnersionRuleWriting.RulesAreImported                = True;
		CovnersionRuleWriting.ExchangePlanNameFromRules          = CovnersionRuleWriting.ExchangePlanName;
		
		// 
		RegistrationRuleWriting.XMLRules             = New ValueStorage(RegistrationBinaryData, New Deflation());
		RegistrationRuleWriting.RulesAreRead      = New ValueStorage(ReadRegistrationRules);
		RegistrationRuleWriting.RulesInformation    = RegistrationRulesInformation;
		RegistrationRuleWriting.RulesFileName         = RulesFileName;
		RegistrationRuleWriting.RulesAreImported       = True;
		RegistrationRuleWriting.ExchangePlanNameFromRules = RegistrationRuleWriting.ExchangePlanName;
		
	EndIf;
	
EndProcedure

// Gets read object conversion rules from the infobase for an exchange plan.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan as a metadata object.
// 
// Returns:
//  ПравилаЗачитанные - 
//  
//
Function ParsedRulesOfObjectConversion(Val ExchangePlanName, GetCorrespondentRules = False) Export
	
	// Function return value.
	RulesAreRead = Undefined;
	
	QueryTextTemplate2 = 
	"SELECT
	|	&AttributeName AS RulesAreRead
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)
	|	AND DataExchangeRules.RulesAreImported";
	
	AttributeName = StringFunctionsClientServer.SubstituteParametersToString("DataExchangeRules.%1",
		?(GetCorrespondentRules, "ReadCorrespondentRules", "RulesAreRead"));
	
	QueryText = StrReplace(QueryTextTemplate2, "&AttributeName", AttributeName);
	
	Query = New Query(QueryText);
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RulesAreRead = Selection.RulesAreRead;
		
	EndIf;
	
	Return RulesAreRead;
	
EndFunction

Function RulesFromFileUsed(ExchangePlanName, DetailedResult1 = False) Export
	
	Query = New Query(
	"SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RulesKind AS RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.RulesAreImported
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If DetailedResult1 Then
		
		RulesFromFile = New Structure("RecordRules, ConversionRules", False, False);
		
		Selection = Result.Select();
		While Selection.Next() Do
			If Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectsConversionRules Then
				RulesFromFile.ConversionRules = True;
			ElsIf Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules Then
				RulesFromFile.RecordRules = True;
			EndIf;
		EndDo;
		
		Return RulesFromFile;
		
	Else
		Return Not Result.IsEmpty();
	EndIf;
	
EndFunction

Function BinaryDataFromConfigurationTemplate(Cancel, ExchangePlanName, TemplateName)
	
	// Getting the temporary file name in the local file system on the server.
	TempFileName = GetTempFileName("xml");
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManagerByName(ExchangePlanName);
	
	// Getting the template of the standard rules.
	Try
		RulesTemplate = ExchangePlanManager.GetTemplate(TemplateName);
	Except
		
		MessageString = NStr("en = 'An error occurred when retrieving the template of the %1 configuration for the %2 exchange plan.';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, TemplateName, ExchangePlanName);
		DataExchangeServer.ReportError(MessageString, Cancel);
		Return Undefined;
		
	EndTry;
	
	RulesTemplate.Write(TempFileName);
	
	BinaryData = New BinaryData(TempFileName);
	
	// 
	FileSystem.DeleteTempFile(TempFileName);
	
	Return BinaryData;
EndFunction

Procedure CheckFieldsFilled(Cancel, Record)
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		NString = NStr("en = 'Specify an exchange plan.';");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	ElsIf Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate
		    And IsBlankString(Record.RulesTemplateName) Then
		
		NString = NStr("en = 'Specify standard rules.';");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	EndIf;
	
EndProcedure

Function RulesInformationFromFile(RulesFileName)
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(RulesFileName);
	ExchangeRules.Read();
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") And (ExchangeRules.NodeType = XMLNodeType.StartElement)) Then
		Raise NStr("en = 'Exchange rule format error';");
	EndIf;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" And ExchangeRules.NodeType = XMLNodeType.StartElement Then
			
			RulesInformation = New Structure;
			RulesInformation.Insert("ConfigurationVersion", ExchangeRules.GetAttribute("ConfigurationVersion"));
			RulesInformation.Insert("ConfigurationSynonymInRules", ExchangeRules.GetAttribute("ConfigurationSynonym"));
			ExchangeRules.Read();
			RulesInformation.Insert("ConfigurationName", ExchangeRules.Value);
			
		ElsIf (NodeName = "Source") And (ExchangeRules.NodeType = XMLNodeType.EndElement) Then
			
			ExchangeRules.Close();
			Return RulesInformation;
			
		EndIf;
		
	EndDo;
	
	Raise NStr("en = 'Exchange rule format error';");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profiles.

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	ImportedRules = ImportedRules();
	
	While ImportedRules.Next() Do
		
		RequestToUseExternalResources(PermissionsRequests, ImportedRules);
		
	EndDo;
	
EndProcedure

Function RegistrationRulesFromFile(ExchangePlanName) Export
	
	Query = New Query(
	"SELECT TOP 1
	|	TRUE
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function ConversionRulesFromFile(ExchangePlanName) Export
	
	Query = New Query(
	"SELECT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.DebugMode AS DebugMode,
	|	DataExchangeRules.ExportDebugMode AS ExportDebugMode,
	|	DataExchangeRules.ImportDebugMode AS ImportDebugMode,
	|	DataExchangeRules.DataExchangeLoggingMode AS DataExchangeLoggingMode,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName AS ExportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName AS ImportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ExchangeProtocolFileName AS ExchangeProtocolFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ImportedRules()
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	DataExchangeRules.DebugMode,
	|	DataExchangeRules.ExportDebugMode,
	|	DataExchangeRules.ImportDebugMode,
	|	DataExchangeRules.DataExchangeLoggingMode,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ExchangeProtocolFileName,
	|	TRUE AS HasConvertionRules
	|INTO ConversionRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)
	|	AND DataExchangeRules.RulesAreImported = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	TRUE AS RegistrationRulesFromFile
	|INTO RecordRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN RecordRules.RegistrationRulesFromFile
	|			THEN RecordRules.ExchangePlanName
	|		ELSE ConversionRules.ExchangePlanName
	|	END AS ExchangePlanName,
	|	ConversionRules.DebugMode,
	|	ConversionRules.ExportDebugMode,
	|	ConversionRules.ImportDebugMode,
	|	ConversionRules.DataExchangeLoggingMode,
	|	ConversionRules.ExportDebuggingDataProcessorFileName,
	|	ConversionRules.ImportDebuggingDataProcessorFileName,
	|	ConversionRules.ExchangeProtocolFileName,
	|	ISNULL(RecordRules.RegistrationRulesFromFile, FALSE) AS RegistrationRulesFromFile,
	|	ISNULL(ConversionRules.HasConvertionRules, FALSE) AS HasConvertionRules
	|FROM
	|	ConversionRules AS ConversionRules
	|		FULL JOIN RecordRules AS RecordRules
	|		ON ConversionRules.ExchangePlanName = RecordRules.ExchangePlanName";
	
	Return Query.Execute().Select();
	
EndFunction

Procedure RequestToUseExternalResources(PermissionsRequests, Record, HasConvertionRules = Undefined, RegistrationRulesFromFile = Undefined) Export
	
	Permissions = New Array;
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If RegistrationRulesFromFile = Undefined Then
		RegistrationRulesFromFile = Record.RegistrationRulesFromFile;
	EndIf;
	
	If HasConvertionRules = Undefined Then
		HasConvertionRules = Record.HasConvertionRules;
	EndIf;
	
	If RegistrationRulesFromFile Then
		Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
	EndIf;
	
	If HasConvertionRules Then
		
		If Not Record.DebugMode Then
			// Requesting the personal profile is not required.
		Else
			
			If Not RegistrationRulesFromFile Then
				Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
			EndIf;
			
			If Record.DebugMode Then
				
				If Record.ExportDebugMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.ImportDebugMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.DataExchangeLoggingMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, True));
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ExchangePlanID = Common.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
	
	ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
	CommonClientServer.SupplementArray(PermissionsRequests,
		ModuleSafeModeManagerInternal.PermissionsRequestForExternalModule(ExchangePlanID, Permissions));
	
EndProcedure

#EndRegion

#EndIf

