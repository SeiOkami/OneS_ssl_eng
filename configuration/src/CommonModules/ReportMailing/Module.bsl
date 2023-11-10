///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

//  
// 
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings - a report mailing to be executed.
//   LogParameters - See ReportMailing.LogParameters.
//   AdditionalSettings - Structure:
//       * Recipients - Map of KeyAndValue:
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - a set of recipient e-mail addresses in the row with separators.
//
// Returns:
//   Boolean - 
//
Function ExecuteReportsMailing(BulkEmail, LogParameters = Undefined, AdditionalSettings = Undefined) Export

	DefaultLogParameters = LogParameters(BulkEmail);
	If LogParameters <> Undefined Then
		FillPropertyValues(DefaultLogParameters, LogParameters);
	EndIf;
	LogParameters = DefaultLogParameters;
	
	// Check rights settings.
	If Not OutputRight(LogParameters) Then
		Return False;
	EndIf;
	
	BulkEmailObject = BulkEmail.GetObject();
	
	// Check basic mailing attributes.
	If Not BulkEmailObject.IsPrepared
		Or BulkEmailObject.DeletionMark Then
		
		Cause = "";
		If Not BulkEmailObject.IsPrepared Then
			Cause = Cause + Chars.LF + NStr("en = 'Distribution not prepared';");
		EndIf;
		If BulkEmailObject.DeletionMark Then
			Cause = Cause + Chars.LF + NStr("en = 'The distribution is marked for deletion.';");
		EndIf;
		
		LogRecord(LogParameters, EventLogLevel.Warning,
			NStr("en = 'Completing';"), TrimAll(Cause));
		Return False;
		
	EndIf;
	
	StartCommitted = CommonClientServer.StructureProperty(AdditionalSettings, "StartCommitted");
	If StartCommitted <> True Then
		// 
		InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
		StartCommitted = True;
	EndIf;
	
	// Default formats.
	DefaultFormats = New Array;
	FoundItems = BulkEmailObject.ReportFormats.FindRows(New Structure("Report", EmptyReportValue()));
	For Each StringFormat In FoundItems Do
		DefaultFormats.Add(StringFormat.Format);
	EndDo;
	If DefaultFormats.Count() = 0 Then
		FormatsList = FormatsList();
		For Each ListValue In FormatsList Do
			If ListValue.Check Then
				DefaultFormats.Add(ListValue.Value);
			EndIf;
		EndDo;
	EndIf;
	If DefaultFormats.Count() = 0 Then
		Raise NStr("en = 'Default formats are not set.';");
	EndIf;
	
	// Populate report table.
	ReportsTable = MailingListReports();
	For Each RowReport In BulkEmailObject.Reports Do
		Page1 = ReportsTable.Add();
		Page1.Report = RowReport.Report;
		Page1.SendIfEmpty = RowReport.SendIfEmpty;
		Page1.DescriptionTemplate1 = RowReport.DescriptionTemplate1;
		
		// Settings.
		Settings = RowReport.Settings.Get();
		If TypeOf(Settings) = Type("ValueTable") Then
			Page1.Settings = New Structure;
			FoundItems = Settings.FindRows(New Structure("Use", True));
			For Each SettingRow In FoundItems Do
				Page1.Settings.Insert(SettingRow.Attribute, SettingRow.Value);
			EndDo;
		Else
			Page1.Settings = Settings;
		EndIf;
		
		// Форматы
		FoundItems = BulkEmailObject.ReportFormats.FindRows(New Structure("Report", RowReport.Report));
		If FoundItems.Count() = 0 Then
			Page1.Formats = DefaultFormats;
		Else
			For Each StringFormat In FoundItems Do
				Page1.Formats.Add(StringFormat.Format);
			EndDo;
		EndIf;
	EndDo;
	
	// Prepare delivery parameters.
	DeliveryParameters = DeliveryParameters();
	DeliveryParameters.UseFolder = BulkEmailObject.UseFolder;
	DeliveryParameters.UseNetworkDirectory = BulkEmailObject.UseNetworkDirectory;
	DeliveryParameters.UseFTPResource = BulkEmailObject.UseFTPResource;
	DeliveryParameters.UseEmail = BulkEmailObject.UseEmail;
	DeliveryParameters.TransliterateFileNames = BulkEmailObject.TransliterateFileNames;
	DeliveryParameters.Personal = BulkEmailObject.Personal;
	
	RecipientsTypesTable = ReportMailingCached.RecipientsTypesTable();
	FoundItems = RecipientsTypesTable.FindRows(New Structure("MetadataObjectID", BulkEmailObject.MailingRecipientType));
	If FoundItems.Count() = 1 Then
		DeliveryParameters.MailingRecipientType = FoundItems[0].RecipientsType;
	EndIf;
	
	// Marked delivery method checks.
	If Not DeliveryParameters.UseFolder
		And Not DeliveryParameters.UseNetworkDirectory
		And Not DeliveryParameters.UseFTPResource
		And Not DeliveryParameters.UseEmail Then
		LogRecord(LogParameters, EventLogLevel.Warning, NStr("en = 'Delivery method is not selected.';"));
		Return False;
	EndIf;
	
	DeliveryParameters.Personalized = BulkEmailObject.Personalized;
	DeliveryParameters.Archive = BulkEmailObject.Archive;
	DeliveryParameters.ArchiveName = BulkEmailObject.ArchiveName;
	
	// Prepare parameters of delivery to the folder.
	If DeliveryParameters.UseFolder Then
		DeliveryParameters.Folder = BulkEmailObject.Folder;
	EndIf;
	
	// Prepare parameters of delivery to the network directory.
	If DeliveryParameters.UseNetworkDirectory Then
		DeliveryParameters.NetworkDirectoryWindows = BulkEmailObject.NetworkDirectoryWindows;
		DeliveryParameters.NetworkDirectoryLinux = BulkEmailObject.NetworkDirectoryLinux;
	EndIf;
	
	// Prepare parameters of delivery to the FTP resource.
	If DeliveryParameters.UseFTPResource Then
		DeliveryParameters.Server = BulkEmailObject.FTPServer;
		DeliveryParameters.Port = BulkEmailObject.FTPPort;
		DeliveryParameters.Login = BulkEmailObject.FTPLogin;
		
		SetPrivilegedMode(True);
		DeliveryParameters.Password = Common.ReadDataFromSecureStorage(BulkEmail, "FTPPassword");
		SetPrivilegedMode(False);
		
		DeliveryParameters.Directory = BulkEmailObject.FTPDirectory;
		DeliveryParameters.PassiveConnection = BulkEmailObject.FTPPassiveConnection;
	EndIf;
	
	DeliveryParameters.ShouldInsertReportsIntoEmailBody = BulkEmailObject.ShouldInsertReportsIntoEmailBody;
	DeliveryParameters.ShouldAttachReports = BulkEmailObject.ShouldAttachReports;
	DeliveryParameters.ShouldSetPasswordsAndEncrypt = BulkEmailObject.ShouldSetPasswordsAndEncrypt;
	
	// Prepare parameters of delivery by email.
	If DeliveryParameters.UseEmail Then
		DeliveryParameters.Account = BulkEmailObject.Account;
		DeliveryParameters.NotifyOnly = BulkEmailObject.NotifyOnly;
		DeliveryParameters.BCCs = BulkEmailObject.BCCs;
		DeliveryParameters.SubjectTemplate = BulkEmailObject.EmailSubject;
		DeliveryParameters.TextTemplate1 = ?(BulkEmailObject.HTMLFormatEmail,
			BulkEmailObject.EmailTextInHTMLFormat, BulkEmailObject.EmailText);
		
		TheRecipientsOfTheMailingListAreSelected = TheRecipientsOfTheMailingListAreSelected(
			BulkEmail, DeliveryParameters, LogParameters, AdditionalSettings);
		
		If Not TheRecipientsOfTheMailingListAreSelected Then 
			Return False;
		EndIf;
		
		DeliveryParameters.EmailParameters.TextType = ?(BulkEmailObject.HTMLFormatEmail, "HTML", "PlainText");
		DeliveryParameters.EmailParameters.ReplyToAddress = BulkEmailObject.ReplyToAddress;
		DeliveryParameters.EmailParameters.Importance = ?(ValueIsFilled(BulkEmailObject.EmailImportance),
			InternetMailMessageImportance[BulkEmailObject.EmailImportance],
			InternetMailMessageImportance.Normal);
		
		If BulkEmail.HTMLFormatEmail Then
			EmailPicturesInHTMLFormat = BulkEmail.EmailPicturesInHTMLFormat.Get();
			If EmailPicturesInHTMLFormat <> Undefined Then
				DeliveryParameters.Images = EmailPicturesInHTMLFormat;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not StartCommitted Then
		InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
		StartCommitted = True;
	EndIf;
	
	DeliveryParameters.StartCommitted = StartCommitted;
	
	Result = ExecuteBulkEmail(ReportsTable, DeliveryParameters, BulkEmail, LogParameters);
	InformationRegisters.ReportMailingStates.FixMailingExecutionResult(BulkEmail, DeliveryParameters);
	
	Return Result;
	
EndFunction

// Distributes arbitrary reports specified in the Reports parameter.
//
// Parameters:
//   Var_Reports - See ReportMailing.MailingListReports.
//   DeliveryParameters - See ReportMailing.DeliveryParameters.
//   MailingDescription - String - output to the subject and message, as well as to output errors.
//                        - CatalogRef.ReportMailings
//   LogParameters - See ReportMailing.LogParameters.
//
// Returns:
//   Boolean - 
//
Function ExecuteBulkEmail(Var_Reports, DeliveryParameters, MailingDescription = "", LogParameters = Undefined) Export
	
	IsReportsDistributionCatalog = False;
	If TypeOf(MailingDescription) = Type("CatalogRef.ReportMailings")
	   And ValueIsFilled(MailingDescription) Then
		IsReportsDistributionCatalog = True;
	EndIf;
	
	If IsReportsDistributionCatalog Then
		RecordManager = InformationRegisters.ReportMailingStates.CreateRecordManager();
		RecordManager.BulkEmail = LogParameters.Data;
		RecordManager.Read();
		ExecutionDate = RecordManager.LastRunStart;
	Else
		ExecutionDate = CurrentSessionDate();
	EndIf;
	
	DefaultDeliveryOptions = DeliveryParameters();
	FillPropertyValues(DefaultDeliveryOptions, DeliveryParameters);
	DeliveryParameters = DefaultDeliveryOptions;   
	
	IsAutoRedistribution = DeliveryParameters.ReportsTree <> Undefined;
	
	// Add a tree of generated reports  - spreadsheet document and reports saved in formats (of files).
	ReportsTree = CreateReportsTree();
	
	// Fill with default parameters and check whether key delivery parameters are filled.
	If Not CheckAndFillExecutionParameters(Var_Reports, DeliveryParameters, MailingDescription, LogParameters) Then
		Return False;
	EndIf;
	
	DeliveryParameters.ExecutionDate = ExecutionDate;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report distribution %1 is started by %2';"),
		MailingDescription, DeliveryParameters.Author);
	
	LogRecord(LogParameters,, MessageText);
	
	If IsAutoRedistribution Then
		ReportsTree = DeliveryParameters.ReportsTree;
		RowsCount = ReportsTree.Rows.Count();
		For Position = -RowsCount + 1 To 0 Do
			If ReportsTree.Rows[-Position] = DeliveryParameters.GeneralReportsRow Then
				Continue; // Ignore the general reports tree row.
			EndIf;
			If DeliveryParameters.Recipients.Get(ReportsTree.Rows[-Position].Key) = Undefined Then
				ReportsTree.Rows.Delete(-Position);
			EndIf;
		EndDo;
	Else
		ReportsTree = GenerateReportsInMultipleThreads(Var_Reports, DeliveryParameters, MailingDescription, LogParameters); 
	EndIf;

	If TypeOf(LogParameters.Metadata) = Type("String") And ValueIsFilled(LogParameters.Metadata) Then
		LogParameters.Metadata = Common.MetadataObjectByFullName(LogParameters.Metadata);
	EndIf;
	
	If ReportsTree.Rows.Count() = 0 Then

		LogRecord(LogParameters,
			EventLogLevel.Warning,
			NStr("en = 'Report distribution failed. Reports are empty or cannot be generated.';"));
		Return False;
	EndIf;
	
	// Check the number of the saved reports.
	If ReportsTree.Rows.Find(3, "Level", True) = Undefined
		And DeliveryParameters.ReportsForEmailText.Count() = 0 Then
		LogRecord(LogParameters,
			EventLogLevel.Warning,
			NStr("en = 'Report distribution failed. Reports are empty or cannot be generated.';"));
			
		FileSystem.DeleteTemporaryDirectory(DeliveryParameters.TempFilesDir);
		Return False;
	EndIf;
	
	MailingExecuted = False;
	
	// Common reports.
	SharedAttachments = DeliveryParameters.GeneralReportsRow.Rows.FindRows(New Structure("Level", 3), True);
	
	If ValueIsFilled(DeliveryParameters.Account) Then 
		SenderSRepresentation = String(DeliveryParameters.Account);
		SendHiddenCopiesToSender = Common.ObjectAttributeValue(
			DeliveryParameters.Account, "SendBCCToThisAddress");
	Else
		SenderSRepresentation = "";
		SendHiddenCopiesToSender = False;
	EndIf;
	
	// 
	RecipientsList = New Array();
	For Each RecipientRow In ReportsTree.Rows Do
		If RecipientRow = DeliveryParameters.GeneralReportsRow Then
			Continue; // Ignore the general reports tree row.
		EndIf;	
		RecipientsList.Add(RecipientRow.Key);	
	EndDo;
	
	If RecipientsList.Count() > 0 Then
		SetPrivilegedMode(True);
		RecipientsArchivePasswords = Common.ReadOwnersDataFromSecureStorage(RecipientsList,
			"ArchivePassword");
		SetPrivilegedMode(False);
		If CanEncryptAttachments() Then
			RecipientsEncryptionCertificates = GetEncryptionCertificatesForDistributionRecipients(RecipientsList);
		EndIf;
	EndIf;
	
	LogRecord(LogParameters,
		EventLogLevel.Note,
		NStr("en = 'Start report distribution to recipients.';"));
	
	// Send personal reports (personalized).
	QuantityToSend = ReportsTree.Rows.Count();
	SentCount = 0;
	For Each RecipientRow In ReportsTree.Rows Do
		If RecipientRow = DeliveryParameters.GeneralReportsRow Then
			Continue; // Ignore the general reports tree row.
		EndIf;
		
		// Personal attachments.
		PersonalAttachments = RecipientRow.Rows.FindRows(New Structure("Level", 3), True);
		
		// Check the number of saved personal reports.
		If PersonalAttachments.Count() = 0 And DeliveryParameters.ReportsForEmailText.Count() = 0 Then
			Continue;
		EndIf;
		
		If DeliveryParameters.ShouldAttachReports Then

			// Merge common and personal attachments.
			RecipientsAttachments = CombineArrays(SharedAttachments, PersonalAttachments);

			// Generate reports presentation.
			GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow);

			If DeliveryParameters.ShouldSetPasswordsAndEncrypt Then
				// 
				If DeliveryParameters.Archive Then
					ArchivePassword = RecipientsArchivePasswords.Get(RecipientRow.Key);
					DeliveryParameters.ArchivePassword = "";
					If ArchivePassword <> Undefined Then
						DeliveryParameters.ArchivePassword = ArchivePassword;
					EndIf;
				EndIf;

				If CanEncryptAttachments() Then
					FilterParameters = New Structure("BulkEmailRecipient", RecipientRow.Key);
					FoundRows = RecipientsEncryptionCertificates.FindRows(FilterParameters);
					DeliveryParameters.CertificateToEncrypt = ?(FoundRows.Count() > 0,
						FoundRows[0].CertificateToEncrypt, Undefined);
				EndIf;

			// 
				If ValueIsFilled(DeliveryParameters.CertificateToEncrypt) And Not DeliveryParameters.Archive Then
					EncryptedAttachments = New Map;
					For Each Attachment In RecipientsAttachments Do
						ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
						AttachmentBinaryData = ModuleDigitalSignature.Encrypt(
						New BinaryData(Attachment.Value), DeliveryParameters.CertificateToEncrypt);
						AttachmentBinaryData.Write(Attachment.Value);
						
						CharCountBeforeExtension = StrFind(Attachment.Key, ".", SearchDirection.FromEnd);
						EncryptedFileName = Left(Attachment.Key, CharCountBeforeExtension-1) + " " + NStr(
							"en = '(Decrypt)';") + Mid(Attachment.Key, CharCountBeforeExtension);
						EncryptedAttachments.Insert(EncryptedFileName, Attachment.Value);
					EndDo;
					RecipientsAttachments = EncryptedAttachments;
				EndIf;
			Else
				DeliveryParameters.ArchivePassword = "";
				DeliveryParameters.CertificateToEncrypt = Undefined;
			EndIf;

			// Archive attachments.
			ArchiveAttachments(RecipientsAttachments, DeliveryParameters, RecipientRow.Value);

		Else
			RecipientsAttachments = New Array;
		EndIf;

		RecipientAddress = DeliveryParameters.Recipients[RecipientRow.Key];
		RecipientPresentation1 = String(RecipientRow.Key) + " (" + RecipientAddress + ")";
		
		// Delivery.
		Try  
			SendReportsToRecipient(RecipientsAttachments, DeliveryParameters, LogParameters, RecipientRow);
			MailingExecuted = True;
			DeliveryParameters.ExecutedByEmail = True;  
			SentCount = SentCount + 1;
			ProgressText = ReportDistributionProgressText(DeliveryParameters, SentCount, QuantityToSend);
			ProgressPercent = Round(SentCount * 100 / QuantityToSend);
			TimeConsumingOperations.ReportProgress(ProgressPercent, ProgressText);

			AdditionalInfo = "";
			If SendHiddenCopiesToSender Then
				AdditionalInfo = NStr("en = 'A copy was sent to the sender.';");
			EndIf;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Reports are sent from %2 to ''%1''. %3';"), RecipientPresentation1, SenderSRepresentation,
				AdditionalInfo);

			LogRecord(LogParameters, , MessageText);
				
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot send reports to %1:';"), RecipientPresentation1);
			ExtendedErrorPresentation = EmailOperations.ExtendedErrorPresentation(
				ErrorInfo(), Common.DefaultLanguageCode());
			LogRecord(LogParameters,, MessageText, ExtendedErrorPresentation);
			
			If Not EmailClientUsed() And GetFunctionalOption("RetainReportDistributionHistory")
			   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
				HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, RecipientRow.Key, DeliveryParameters.ExecutionDate); 
				HistoryFields.Account = DeliveryParameters.Account;    
				HistoryFields.EMAddress = RecipientRow.Value;
				HistoryFields.Comment = MessageText;
				HistoryFields.Executed = False;
				HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, RecipientRow.Key, RecipientRow.Value); 
				HistoryFields.EmailID = "";
				HistoryFields.Period = CurrentSessionDate();	
				
				InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
			EndIf;
		EndTry;
		
		If MailingExecuted Then
			DeliveryParameters.Recipients.Delete(RecipientRow.Key);
		EndIf;
	EndDo;
	
	// Send general reports.
	If SharedAttachments.Count() > 0 Or DeliveryParameters.ReportsForEmailText.Count() > 0 Then
		// Reports presentation.
		GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow);
		
		If (DeliveryParameters.UseEmail And DeliveryParameters.ShouldAttachReports)
			Or  DeliveryParameters.UseFolder Or DeliveryParameters.UseNetworkDirectory 
			Or DeliveryParameters.UseFTPResource Then

			SetPrivilegedMode(True);
			DeliveryParameters.ArchivePassword = Common.ReadDataFromSecureStorage(
			LogParameters.Data, "ArchivePassword");
			SetPrivilegedMode(False);

			If CanEncryptAttachments() And DeliveryParameters.Personal Then
				RecipientsList = New Array;
				For Each RecipientRow In DeliveryParameters.Recipients Do
					RecipientsList.Add(RecipientRow.Key);
				EndDo;
				RecipientsEncryptionCertificates = GetEncryptionCertificatesForDistributionRecipients(RecipientsList);
				DeliveryParameters.CertificateToEncrypt = ?( RecipientsEncryptionCertificates.Count() > 0,
					RecipientsEncryptionCertificates[0].CertificateToEncrypt, Undefined);
				DeliveryParameters.ShouldSetPasswordsAndEncrypt = ?(ValueIsFilled(DeliveryParameters.CertificateToEncrypt),True, False);

				If Not DeliveryParameters.Archive And DeliveryParameters.ShouldSetPasswordsAndEncrypt Then
				// 	
					EncryptedAttachments = New Map;
					For Each Attachment In SharedAttachments Do
						ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
						AttachmentBinaryData = ModuleDigitalSignature.Encrypt(
						New BinaryData(Attachment.Value), DeliveryParameters.CertificateToEncrypt);
						AttachmentBinaryData.Write(Attachment.Value);
						
						CharCountBeforeExtension = StrFind(Attachment.Key, ".", SearchDirection.FromEnd);
						EncryptedFileName = Left(Attachment.Key, CharCountBeforeExtension-1) + " " + NStr(
							"en = '(Decrypt)';") + Mid(Attachment.Key, CharCountBeforeExtension);
						EncryptedAttachments.Insert(EncryptedFileName, Attachment.Value);
					EndDo;
					SharedAttachments = EncryptedAttachments;
				EndIf;
				
			EndIf;
				
			// Archive attachments.
			ArchiveAttachments(SharedAttachments, DeliveryParameters, DeliveryParameters.TempFilesDir);
				
		Else
			SharedAttachments = New Array;	
		EndIf;
		
		// Delivery.
		If ExecuteDelivery(LogParameters, DeliveryParameters, SharedAttachments) Then
			MailingExecuted = True;
	
			If DeliveryParameters.Recipients <> Undefined Then
				RecipientPresentation1 = New Array;
				For Each BulkEmailRecipient In DeliveryParameters.Recipients Do
					RecipientPresentation1.Add(String(BulkEmailRecipient.Key) + " (" + BulkEmailRecipient.Value + ")");
				EndDo;
				RecipientPresentation1 = StrConcat(RecipientPresentation1, Chars.LF);
				
				AdditionalInfo = "";
				If SendHiddenCopiesToSender Then 
					AdditionalInfo = NStr("en = 'A copy was sent to the sender.';");
				EndIf;
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Reports are sent from %2 to %1 users. %3
					|%4';"),
					DeliveryParameters.Recipients.Count(), SenderSRepresentation, 
					AdditionalInfo, RecipientPresentation1);
				LogRecord(LogParameters,, MessageText);  					
			EndIf;
		EndIf;
	EndIf;

	If MailingExecuted Then
		LogRecord(LogParameters, , NStr("en = 'Report distribution completed';"));
	Else
		LogRecord(LogParameters, , NStr("en = 'Report distribution failed';"));
	EndIf;
	
	If Not IsAutoRedistribution And IsReportsDistributionCatalog Then
		DeliveryParameters.ReportsTree = ReportsTree;
		ResendByEmail(Var_Reports, DeliveryParameters, LogParameters.Data, LogParameters);
	EndIf;
	
	FileSystem.DeleteTemporaryDirectory(DeliveryParameters.TempFilesDir);
	
	// Result.
	If LogParameters.Property("HadErrors") Then
		DeliveryParameters.HadErrors = LogParameters.HadErrors;
	EndIf;
	
	If LogParameters.Property("HasWarnings") Then
		DeliveryParameters.HasWarnings = LogParameters.HasWarnings;
	EndIf;
	
	Return MailingExecuted;
EndFunction

// The constructor for the LogParameters parameter value of the ExecuteReportsMailing and ExecuteBulkEmail functions.
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings - a report mailing to be executed.
//
// Returns:
//   Structure - 
//       * EventName - String - an event name (or events group).
//       * Metadata - Array of MetadataObject, Undefined - metadata to link the event of the event log.
//       * Data     - Arbitrary - data to link the event of the event log.
//
Function LogParameters(BulkEmail = Undefined) Export
	
	LogParameters = New Structure;
	LogParameters.Insert("EventName", NStr("en = 'Report distribution. Manual start';", Common.DefaultLanguageCode()));
	LogParameters.Insert("Data", BulkEmail);
	LogParameters.Insert("Metadata", ?(BulkEmail <> Undefined, BulkEmail.Metadata(), Undefined));
	LogParameters.Insert("ErrorsArray", Undefined); // 
	Return LogParameters;
	
EndFunction

// The constructor for the Reports parameter value of the ExecuteBulkEmail function.
//
// Returns:
//   ValueTable - 
//       * Report - CatalogRef.ReportsOptions
//               - CatalogRef.AdditionalReportsAndDataProcessors - 
//       * SendIfEmpty - Boolean - send a report even if it is blank.
//       * Settings - DataCompositionUserSettings - a spreadsheet document will be generated by the DCS mechanisms.
//                   - Structure - 
//                      ** Key     - String       - a report object attribute name.
//                      ** Value - Arbitrary - a report object attribute value.
//                   - Undefined - 
//                     
//       * Formats - Array of EnumRef.ReportSaveFormats - formats in which the report must be saved and
//                                                                           sent.
//       * DescriptionTemplate1 - String -
//
Function MailingListReports() Export
	
	ReportsTable = New ValueTable;
	ReportsTable.Columns.Add("Report", Metadata.Catalogs.ReportMailings.TabularSections.Reports.Attributes.Report.Type);
	ReportsTable.Columns.Add("SendIfEmpty", New TypeDescription("Boolean"));
	
	SettingTypesArray = New Array;
	SettingTypesArray.Add(Type("Undefined"));
	SettingTypesArray.Add(Type("DataCompositionUserSettings"));
	SettingTypesArray.Add(Type("Structure"));
	
	ReportsTable.Columns.Add("Settings", New TypeDescription(SettingTypesArray));
	ReportsTable.Columns.Add("Formats", New TypeDescription("Array"));
	ReportsTable.Columns.Add("DescriptionTemplate1", New TypeDescription("String", New StringQualifiers(150)));
	Return ReportsTable;
	
EndFunction

// The constructor for the DeliveryParameters parameter value of the ExecuteBulkEmail function.
//
// Returns:
//   Structure - 
//     
//       * Author - CatalogRef.Users - a mailing author.
//       * UseFolder            - Boolean - deliver reports to the "Stored files" subsystem folder.
//       * UseNetworkDirectory   - Boolean - deliver reports to the file system folder.
//       * UseFTPResource        - Boolean - deliver reports to the FTP.
//       * UseEmail - Boolean - deliver reports via email.
//
//     Properties when UseFolder = True:
//       * Folder - CatalogRef.FilesFolders - a folder of the "File Management" subsystem.
//
//     Properties when UseNetworkDirectory = True:
//       * NetworkDirectoryWindows - String - a file system directory (local at server or network).
//       * NetworkDirectoryLinux   - String - a file system directory (local on the server or network).
//
//     Properties when UseFTPResource = True:
//       * Owner            - CatalogRef.ReportMailings
//       * Server              - String - an FTP server name.
//       * Port                - Number  - an FTP server port.
//       * Login               - String - an FTP server user name.
//       * Password              - String - an FTP server user password.
//       * Directory             - String - a path to the directory at the FTP server.
//       * PassiveConnection - Boolean - use passive connection.
//
//     Properties when UseEmail = True:
//       * Account - CatalogRef.EmailAccounts - to send an email message.
//       * Recipients - Map of KeyAndValue - a set of recipients and their email addresses:
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - email addresses of the recipient separated by commas.
//
//     Additional properties:
//       * Archive - Boolean - archive all generated reports into one archive.
//                                 Archiving can be required, for example, when mailing schedules in html format.
//       * ArchiveName    - String - an archive name.
//       * ArchivePassword - String - an archive password.
//       * TransliterateFileNames - Boolean -
//       * CertificateToEncrypt - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates -
//           
//
//     
//       * Personalized - Boolean - a mailing personalized by recipients.
//           The default value is False.
//           If True value is set, each recipient will receive a report with a filter by it.
//           To do this, in reports, set the "[Получатель]" filter by the attribute that match the recipient type.
//           Applies only to delivery by mail,
//           so when setting to the True, other delivery methods are disabled.
//       * NotifyOnly - Boolean - False - send notifications only (do not attach generated reports).
//       * BCCs    - Boolean - False - if True, when sending fill BCCs instead of To.
//       * SubjectTemplate      - String -       an email subject.
//       * TextTemplate1    - String -       an email body.
//       * FormatsParameters - Map of KeyAndValue:
//           ** Key - EnumRef.ReportSaveFormats
//           ** Value - Structure:
//                *** Extension - String
//                *** FileType - SpreadsheetDocumentFileType
//                *** Name - String
//       * EmailParameters - Structure - contains all the necessary information about the email:
//           ** Whom - Array
//                   - String - 
//                   - Array - a collection of structures, addresses:
//                       *** Address - String - postal address (must be filled in).
//                       *** Presentation - String - destination name.
//                   - String - 
//            ** MessageRecipients - Array - array of structures describing the recipients:
//                 *** Address - String - email address of the message recipient.
//                 *** Presentation - String - representation of the addressee.
//            ** Cc - Array
//                     - String - 
//            ** BCCs - Array
//                            - String - 
//            ** Subject       - String - (required) subject of the email message.
//            ** Body       - String - (required) text of the email message (plain text in win-1251 encoding).
//            ** Attachments - Array - files to be attached (described as structures):
//                 *** Presentation - String - attachment file name;
//                 *** AddressInTempStorage - String - address of the attachment's binary data in temporary storage.
//                 *** Encoding - String - encoding of the attachment (used if it differs from the encoding of the message).
//                 *** Id - String - (optional) used to mark images displayed in the message body.
//            ** ReplyToAddress - String -
//            ** BasisIDs - String - IDs of the bases of this message.
//            ** ProcessTexts  - Boolean - the need to process the message texts when sending.
//            ** RequestDeliveryReceipt  - Boolean - need to request a delivery notification.
//            ** RequestReadReceipt - Boolean - need to request a read notification.
//            ** TextType - String
//                         - EnumRef.EmailTextTypes
//                         - InternetMailTextType - 
//                             
//                             
//                                                                       
//                             
//                                                                                             
//
Function DeliveryParameters() Export
	
	DeliveryParameters = ReportMailingClientServer.DeliveryParameters();
	DeliveryParameters.ExecutionDate = CurrentSessionDate();
	DeliveryParameters.Author = Users.CurrentUser();
	DeliveryParameters.TempFilesDir = FileSystem.CreateTemporaryDirectory("RP");
	DeliveryParameters.EmailParameters.Importance = InternetMailMessageImportance.Normal;
	
	If GetFunctionalOption("RetainReportDistributionHistory") Then
		DeliveryParameters.EmailParameters.RequestDeliveryReceipt = True;
		DeliveryParameters.EmailParameters.RequestReadReceipt = True;
	EndIf;
	
	Return DeliveryParameters;
	
EndFunction

// To call from the modules ReportMailingOverridable or ReportMailingCached.
// Adds format (if absent) and sets its parameters (if passed).
//
// Parameters:
//   FormatsList - ValueList
//   FormatRef   - String
//                  - EnumRef.ReportSaveFormats - 
//   Picture                - Picture - a picture of the format.
//   UseByDefault - Boolean   - flag showing that the format is used by default.
//
Procedure SetFormatsParameters(FormatsList, FormatRef, Picture = Undefined, UseByDefault = Undefined) Export
	If TypeOf(FormatRef) = Type("String") Then
		FormatRef = Enums.ReportSaveFormats[FormatRef];
	EndIf;
	ListItem = FormatsList.FindByValue(FormatRef);
	If ListItem = Undefined Then
		ListItem = FormatsList.Add(FormatRef, FormatPresentation(FormatRef), False, PictureLib.BlankFormat);
	EndIf;
	If Picture <> Undefined Then
		ListItem.Picture = Picture;
	EndIf;
	If UseByDefault <> Undefined Then
		ListItem.Check = UseByDefault;
	EndIf;
EndProcedure

// To call from the modules ReportMailingOverridable or ReportMailingCached.
//   Adds recipients type description to the table.
//
// Parameters:
//   TypesTable  - ValueTable - passed from procedure parameters as is. Contains types information.
//   AvailableTypes - Array          - passed from procedure parameters as is. Unused types array.
//   Settings     - Structure       - predefined settings to register the main type.
//     Mandatory parameters:
//       * MainType - Type - a main type for the described recipients.
//     Optional parameters:
//       * Presentation - String - a presentation of this type of recipients in the interface.
//       * CIKind - CatalogRef.ContactInformationKinds - a main type or group of contact information
//           for email addresses of this type of recipients.
//       * ChoiceFormPath - String - a path to the choice form.
//       * AdditionalType - Type - an additional type that can be selected along with the main one from the choice form.
//
Procedure AddItemToRecipientsTypesTable(TypesTable, AvailableTypes, Settings) Export
	SetPrivilegedMode(True);
	
	MainTypesMetadata = Metadata.FindByType(Settings.MainType);
	
	// Register the main type usage.
	TypeIndex = AvailableTypes.Find(Settings.MainType);
	If TypeIndex <> Undefined Then
		AvailableTypes.Delete(TypeIndex);
	EndIf;
	
	// Metadata objects IDs.
	MetadataObjectID = Common.MetadataObjectID(Settings.MainType);
	TableRow = TypesTable.Find(MetadataObjectID, "MetadataObjectID");
	If TableRow = Undefined Then
		TableRow = TypesTable.Add();
		TableRow.MetadataObjectID = MetadataObjectID;
	EndIf;
	
	// Recipients type.
	TypesArray = New Array;
	TypesArray.Add(Settings.MainType);
	
	// 
	TableRow.MainType = New TypeDescription(TypesArray);
	
	// Recipients type: Additional.
	If Settings.Property("AdditionalType") Then
		TypesArray.Add(Settings.AdditionalType);
		
		// 
		TypeIndex = AvailableTypes.Find(Settings.AdditionalType);
		If TypeIndex <> Undefined Then
			AvailableTypes.Delete(TypeIndex);
		EndIf;
	EndIf;
	TableRow.RecipientsType = New TypeDescription(TypesArray);
	
	// Presentation.
	If Settings.Property("Presentation") Then
		TableRow.Presentation = Settings.Presentation;
	Else
		TableRow.Presentation = MainTypesMetadata.Synonym;
	EndIf;
	
	// Email as the main contact information kind for the object.
	If Settings.Property("CIKind") And Not Settings.CIKind.IsFolder Then
		TableRow.MainCIKind = Settings.CIKind;
		TableRow.CIGroup = Settings.CIKind.Parent;
	Else
		If Settings.Property("CIKind") Then
			TableRow.CIGroup = Settings.CIKind;
		Else
			
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				
				ModuleContactsManager = Common.CommonModule("ContactsManager");
				CIGroupName = StrReplace(MainTypesMetadata.FullName(), ".", "");
				TableRow.CIGroup = ModuleContactsManager.ContactInformationKindByName(CIGroupName);
				
			EndIf;
			
		EndIf;
		Query = New Query;
		Query.Text = "SELECT TOP 1 Ref FROM Catalog.ContactInformationKinds WHERE Parent = &Parent AND Type = &Type";
		Query.SetParameter("Parent", TableRow.CIGroup);
		Query.Parameters.Insert("Type", Enums.ContactInformationTypes.Email);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			TableRow.MainCIKind = Selection.Ref;
		EndIf;
	EndIf;
	
	// Full path to the choice form of this object.
	If Settings.Property("ChoiceFormPath") Then
		TableRow.ChoiceFormPath = Settings.ChoiceFormPath;
	Else
		TableRow.ChoiceFormPath = MainTypesMetadata.FullName() +".ChoiceForm";
	EndIf;
EndProcedure

// Distributes several reports and places the result at the ResultAddress address. 
//
// Parameters:
//   ExecutionParameters - Structure - mailings to be executed and their parameters:
//       * MailingArray - Array of CatalogRef.ReportMailings - mailings to be executed.
//       * PreliminarySettings - See ReportMailing.ExecuteReportsMailing.
//   ResultAddress - String - an address in the temporary storage where the result will be placed.
//
Procedure SendBulkEmailsInBackgroundJob(ExecutionParameters, ResultAddress) Export
	MailingArray           = ExecutionParameters.MailingArray;
	PreliminarySettings = ExecutionParameters.PreliminarySettings;
	
	// Selecting all mailings including nested excluding groups.
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	ReportMailings.Ref AS BulkEmail,
	|	ReportMailings.Presentation AS Presentation,
	|	CASE
	|		WHEN ReportMailings.IsPrepared = TRUE
	|				AND ReportMailings.DeletionMark = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsPrepared,
	|	FALSE AS Executed,
	|	FALSE AS WithErrors
	|FROM
	|	Catalog.ReportMailings AS ReportMailings
	|WHERE
	|	ReportMailings.Ref IN HIERARCHY(&MailingArray)
	|	AND ReportMailings.IsFolder = FALSE";
	
	Query.SetParameter("MailingArray", MailingArray);
	MailingsTable = Query.Execute().Unload();
	PreparedReportDistributionDetails = MailingsTable.FindRows(New Structure("IsPrepared", True));
	Completed2 = 0;
	WithErrors = 0;
	
	ArrayOfMessages = New Array;
	For Each TableRow In PreparedReportDistributionDetails Do
		
		LogParameters = LogParameters(TableRow.BulkEmail);
		LogParameters.ErrorsArray = New Array;
		TableRow.Executed = ExecuteReportsMailing(
			TableRow.BulkEmail,
			LogParameters,
			PreliminarySettings);
		TableRow.WithErrors = (LogParameters.ErrorsArray.Count() > 0);
		
		If TableRow.WithErrors Then
			ArrayOfMessages.Add("---" + Chars.LF + Chars.LF + TableRow.Presentation + ":"); // Заголовок
			For Each Message In LogParameters.ErrorsArray Do
				ArrayOfMessages.Add(Message);
			EndDo;
		EndIf;
		
		If TableRow.Executed Then
			Completed2 = Completed2 + 1;
			If TableRow.WithErrors Then
				WithErrors = WithErrors + 1;
			EndIf;
		EndIf;
	EndDo;
	
	Total        = MailingsTable.Count();
	Prepared2 = PreparedReportDistributionDetails.Count();
	NotCompleted2  = Prepared2 - Completed2;
	
	If Total = 0 Then
		MessageText = NStr("en = 'The selected groups contain  no report distributions.';");
	ElsIf Total <= 5 Then
		MessageText = "";
		For Each TableRow In MailingsTable Do
			If Not TableRow.IsPrepared Then
				MessageTemplate = NStr("en = 'Report distribution ""%1"" not prepared.';");
			ElsIf Not TableRow.Executed Then
				MessageTemplate = NStr("en = 'Report distribution ""%1"" not completed.';");
			ElsIf TableRow.WithErrors Then
				MessageTemplate = NStr("en = 'The ""%1"" report distribution is partially completed';");
			Else
				MessageTemplate = NStr("en = 'Report distribution ""%1"" completed successfully.';");
			EndIf;
			MessageTemplate = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, TableRow.Presentation);
			
			If MessageText = "" Then
				MessageText = MessageTemplate;
			Else
				MessageText = MessageText + Chars.LF + Chars.LF + MessageTemplate;
			EndIf;
		EndDo;
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Prepared %1 out of %2 report distributions
			|Completed: %3
			|Partially: %4
			|Not completed: %5';"),
			Format(Prepared2, "NZ=0; NG=0"), Format(Total, "NZ=0; NG=0"),
			Format(Completed2,    "NZ=0; NG=0"),
			Format(WithErrors,    "NZ=0; NG=0"),
			Format(NotCompleted2,  "NZ=0; NG=0"));
	EndIf;
	
	Result = New Structure;
	Result.Insert("BulkEmails", MailingsTable.UnloadColumn("BulkEmail"));
	Result.Insert("Text", MessageText);
	Result.Insert("More", MessagesToUserString(ArrayOfMessages));
	PutToTempStorage(Result, ResultAddress);
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use ExecuteReportsMailing.
// Generates reports and sends them according to the transport settings (Folder, FILE, EMAIL, FTP);
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings - a report mailing to be executed.
//   LogParameters - Structure - parameters of the writing to the event log:
//       * EventName - String - an event name (or events group).
//       * Metadata - MetadataObject - metadata to link the event of the event log.
//       * Data     - Arbitrary - data to link the event of the event log.
//   AdditionalSettings - Structure - settings that override standard mailing parameters:
//       * Recipients - Map of KeyAndValue - a set of recipients and their email addresses:
//           ** Key - CatalogRef - a recipient.
//           ** Value - String - a set of recipient e-mail addresses in the row with separators.
//
// Returns:
//   Boolean - 
//
Function PrepareParametersAndExecuteMailing(BulkEmail, LogParameters = Undefined, AdditionalSettings = Undefined) Export
	
	Return ExecuteReportsMailing(BulkEmail, LogParameters, AdditionalSettings);
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Adds commands for creating mailings to the report form.
//
// Parameters:
//   Form - ClientApplicationForm
//         - ReportFormExtension
//   Cancel - Boolean
//   StandardProcessing - Boolean
//
Procedure ReportFormAddCommands(Form, Cancel, StandardProcessing) Export
	
	// Mailings can be added only if there is an option link (it is internal or additional).
	If Form.ReportSettings.External Then
		Return;
	EndIf;
	If Not InsertRight1() Then
		Return;
	EndIf;
	
	Prefix_Name = ReportsClientServer.CommandNamePrefixWithReportOptionPreSave();
	
	// Add commands and buttons
	Commands = New Array;
	
	CreateCommand = Form.Commands.Add(Prefix_Name + "ReportMailingCreateNew");
	CreateCommand.Action  = "ReportMailingClient.CreateNewBulkEmailFromReport";
	CreateCommand.Picture  = PictureLib.ReportMailing;
	CreateCommand.Title = NStr("en = 'Create report distribution';");
	CreateCommand.ToolTip = NStr("en = 'Include the report with the current settings in a newly created report distribution.';");
	Commands.Add(CreateCommand);
	
	AttachCommand = Form.Commands.Add("ReportMailingAddToExisting");
	AttachCommand.Action  = "ReportMailingClient.AttachReportToExistingBulkEmail";
	AttachCommand.Title = NStr("en = 'Choose existing report distribution';");
	AttachCommand.ToolTip = NStr("en = 'Include the report with the current settings in an existing report distribution.';");
	Commands.Add(AttachCommand);
	
	MailingsWithReportsNumber = MailingsWithReportsNumber(Form.ReportSettings.OptionRef);
	If MailingsWithReportsNumber > 0 Then
		MailingsCommand = Form.Commands.Add("ReportMailingOpenMailingsWithReport");
		MailingsCommand.Action  = "ReportMailingClient.OpenBulkEmailsWithReport";
		MailingsCommand.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Report distribution (%1)';"), 
			MailingsWithReportsNumber);
		MailingsCommand.ToolTip = NStr("en = 'Show the list of distributions that contain the report.';");
		Commands.Add(MailingsCommand);
	EndIf;
	
	ReportsServer.OutputCommand(Form, Commands, "SubmenuSend", False, False, "ReportMailing");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Administration panels.

// Returns True if the user has the right to save report mailings.
Function InsertRight1() Export
	Return CheckAddRightErrorText() = "";
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.Catalogs.ReportMailings.Attributes.MailingRecipientType);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	QueryText = 
	"SELECT
	|	ReportMailings.Ref,
	|	ReportMailings.UseFTPResource,
	|	ReportMailings.FTPServer,
	|	ReportMailings.FTPDirectory,
	|	ReportMailings.FTPPort,
	|	ReportMailings.UseNetworkDirectory,
	|	ReportMailings.NetworkDirectoryWindows,
	|	ReportMailings.NetworkDirectoryLinux
	|FROM
	|	Catalog.ReportMailings AS ReportMailings
	|WHERE
	|	ReportMailings.DeletionMark = FALSE
	|	AND (ReportMailings.UseNetworkDirectory = TRUE
	|		OR ReportMailings.UseFTPResource = TRUE)";
	
	Query = New Query;
	Query.Text = QueryText;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	BulkEmail = Query.Execute().Select();
	While BulkEmail.Next() Do
		
		PermissionsRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(
				PermissionsToUseServerResources(BulkEmail), BulkEmail.Ref));
		
	EndDo;
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	If Not InsertRight1() Then
		Return;
	EndIf;
	
	ToDoName = "ReportMailingIssues";
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled(ToDoName) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	COUNT(ReportMailings.Ref) AS Count
		|FROM
		|	InformationRegister.ReportMailingStates AS ReportMailingStates
		|		INNER JOIN Catalog.ReportMailings AS ReportMailings
		|		ON ReportMailingStates.BulkEmail = ReportMailings.Ref
		|WHERE
		|	ReportMailings.IsPrepared = TRUE
		|	AND ReportMailingStates.WithErrors = TRUE
		|	AND ReportMailings.Author = &Author";
	Filters = New Structure;
	Filters.Insert("DeletionMark", False);
	Filters.Insert("IsPrepared", True);
	Filters.Insert("WithErrors", True);
	Filters.Insert("IsFolder", False);
	If Users.IsFullUser() Then
		Query.Text = StrReplace(Query.Text, "AND ReportMailings.Author = &Author", ""); // @query-part
	Else
		Filters.Insert("Author", Users.CurrentUser());
		Query.SetParameter("Author", Filters.Author);
	EndIf;
	IssuesCount = Query.Execute().Unload()[0].Count;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filters);
	FormParameters.Insert("Representation", "List");
	
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.ReportMailings.FullName());
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = ToDoName + StrReplace(Section.FullName(), ".", "");
		ToDoItem.HasToDoItems       = IssuesCount > 0;
		ToDoItem.Presentation  = NStr("en = 'Report distribution issues';");
		ToDoItem.Count     = IssuesCount;
		ToDoItem.Form          = "Catalog.ReportMailings.ListForm";
		ToDoItem.FormParameters = FormParameters;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = Section;
	EndDo;
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ReportMailings.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ReportMailing;
	Dependence.UseExternalResources = True;
	Dependence.IsParameterized = True;
EndProcedure 

// See JobsQueueOverridable.OnDefineHandlerAliases.
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	NamesAndAliasesMap.Insert(Metadata.ScheduledJobs.ReportMailing.MethodName);
	NamesAndAliasesMap.Insert(Metadata.ScheduledJobs.ReportDistributionHistoryClearUp.MethodName);
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ReportMailings, True);
	
EndProcedure

// See also InfobaseUpdateOverridable.OnDefineSettings
//
// Parameters:
//  Objects - Array of MetadataObject
//
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.ReportMailings);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version    = "3.1.8.98";
	Handler.Procedure = "ReportMailing.SetReportDistributionHistoryRetentionPeriodInMonths";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData      = False;
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version          = "3.1.9.21";
	Handler.Id   = New UUID("a3675668-c1c4-4012-a007-8df47dbed76d");
	Handler.Procedure       = "Catalogs.ReportMailings.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.ReportMailings.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToChange  = "Catalog.ReportMailings";
	Handler.ObjectsToLock = "Catalog.ReportMailings";
	Handler.CheckProcedure  = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Set default report name templates in report distributions. 
		|Set the Attach reports checkbox. We do not recommend that you run report distributions until processing is completed.';");
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		NewRow = Handler.ExecutionPriorities.Add();
		NewRow.Procedure = "NationalLanguageSupportServer.ProcessDataForMigrationToNewVersion";
		NewRow.Order = "Before";
	EndIf;
	
EndProcedure

// See EmailOperationsOverridable.BeforeGetEmailMessagesStatuses
Procedure BeforeGetEmailMessagesStatuses(EmailMessagesIDs) Export
	
	If Not GetFunctionalOption("RetainReportDistributionHistory") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ReportsDistributionHistory.EmailID AS EmailID,
		|	ReportsDistributionHistory.Account AS Sender,
		|	ReportsDistributionHistory.EMAddress AS RecipientAddress
		|FROM
		|	InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
		|WHERE
		|	ReportsDistributionHistory.Status = &EmptyStatus
		|	AND ReportsDistributionHistory.Period >= &VerificationPeriod
		|	AND ReportsDistributionHistory.EmailID <> """"";
	
	Query.SetParameter("VerificationPeriod", CurrentSessionDate() - 259200); // 
	Query.SetParameter("EmptyStatus", Enums.EmailMessagesStatuses.EmptyRef());
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do 
		StringMailsIDs = EmailMessagesIDs.Add();
		FillPropertyValues(StringMailsIDs, Selection);		
	EndDo;
			
EndProcedure 

// See EmailOperationsOverridable.AfterGetEmailMessagesStatuses
Procedure AfterGetEmailMessagesStatuses(DeliveryStatuses) Export
	
	If Not GetFunctionalOption("RetainReportDistributionHistory") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	DeliveryStatuses.StatusChangeDate AS StatusChangeDate,
		|	DeliveryStatuses.Status AS Status,
		|	DeliveryStatuses.Cause AS Cause,
		|	DeliveryStatuses.EmailID AS EmailID,
		|	DeliveryStatuses.RecipientAddress AS RecipientAddress,
		|	DeliveryStatuses.Sender AS Sender
		|INTO DeliveryStatuses
		|FROM
		|	&DeliveryStatuses AS DeliveryStatuses
		|
		|INDEX BY
		|	EmailID
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	ReportsDistributionHistory.ReportMailing AS ReportMailing,
		|	ReportsDistributionHistory.Recipient AS Recipient,
		|	ReportsDistributionHistory.StartDistribution AS StartDistribution,
		|	ReportsDistributionHistory.Period AS Period,
		|	ReportsDistributionHistory.EmailID AS EmailID,
		|	DeliveryStatuses.StatusChangeDate AS StatusChangeDate,
		|	DeliveryStatuses.Status AS Status,
		|	DeliveryStatuses.Cause AS Comment,
		|	ReportsDistributionHistory.Account AS Account,
		|	ReportsDistributionHistory.EMAddress AS EMAddress,
		|	ReportsDistributionHistory.OutgoingEmail AS OutgoingEmail,
		|	ReportsDistributionHistory.SessionNumber AS SessionNumber,
		|	ReportsDistributionHistory.MethodOfObtaining AS MethodOfObtaining,
		|	ReportsDistributionHistory.Executed AS Executed
		|FROM
		|	InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
		|		INNER JOIN DeliveryStatuses AS DeliveryStatuses
		|		ON ReportsDistributionHistory.EmailID = DeliveryStatuses.EmailID
		|		AND ReportsDistributionHistory.EMAddress = DeliveryStatuses.RecipientAddress
		|		AND ReportsDistributionHistory.Account = DeliveryStatuses.Sender";
	
	Query.SetParameter("DeliveryStatuses", DeliveryStatuses);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do		
		HistoryFields = ReportDistributionHistoryFields(Selection.ReportMailing, Selection.Recipient, Selection.StartDistribution); 
		FillPropertyValues(HistoryFields, Selection);   
		HistoryFields.Executed = ?(Selection.Status = Enums.EmailMessagesStatuses.NotDelivered, False, HistoryFields.Executed);   
		HistoryFields.Status = Selection.Status;
		HistoryFields.Comment = Selection.Comment;
		If Selection.Status = Enums.EmailMessagesStatuses.Delivered Then
			HistoryFields.DeliveryDate = Selection.StatusChangeDate;
		EndIf;
		
		InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Scheduled job execution.

// Starts mailing and controls result.
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings - a report mailing to be executed.
//
Procedure ExecuteScheduledMailing(BulkEmail) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ReportMailing);
	
	InformationRegisters.ReportMailingStates.FixMailingStart(BulkEmail);
	
	If Not AccessRight("Read", Metadata.Catalogs.ReportMailings) Then
		Raise
			NStr("en = 'The user has insufficient rights to read report distributions. 
				|Remove this user from all report distributions or change the distribution author. You can change the author on the Schedule tab.';");
	EndIf;
		
	Query = New Query("SELECT ALLOWED ExecuteOnSchedule FROM Catalog.ReportMailings WHERE Ref = &Ref");
	Query.SetParameter("Ref", BulkEmail);
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Raise NStr("en = 'Insufficient rights to view the report distribution.';");
	EndIf;
	If Not Selection.ExecuteOnSchedule Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""Schedule"" check box is cleared for report distribution ""%1"". 
				|Disable the associated scheduled task or edit the report distribution.';"),
			String(BulkEmail));
	EndIf;
	
	ExecuteReportsMailing(BulkEmail, LogParameters(BulkEmail), New Structure("StartCommitted", True));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Generate a recipients list from the Recipients tabular section of mailing.
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings
//            - Structure - 
//              
//   LogParameters - See LogParameters
//
// Returns: 
//   Map of KeyAndValue:
//       * Key     - CatalogRef
//       * Value - String -
//
Function GenerateMailingRecipientsList(BulkEmail, LogParameters = Undefined) Export
	
	RecipientsEmailAddressKind = BulkEmail.RecipientsEmailAddressKind;
	
	If BulkEmail.Personal Then
		
		RecipientsType = TypeOf(BulkEmail.Author);
		RecipientsMetadata = Metadata.FindByType(RecipientsType);
		
		TableOfRecipients = New ValueTable;
		For Each Attribute In Metadata.Catalogs.ReportMailings.TabularSections.Recipients.Attributes Do
			TableOfRecipients.Columns.Add(Attribute.Name, Attribute.Type);
		EndDo;
		TableOfRecipients.Add().Recipient = BulkEmail.Author;
		
	Else
		RecipientsMetadata = Common.MetadataObjectByID(BulkEmail.MailingRecipientType, False);
		RecipientsType = BulkEmail.MailingRecipientType.MetadataObjectKey.Get();
		TableOfRecipients = BulkEmail.Recipients.Unload();
	EndIf;
	
	RecipientsList = New Map;
	
	Query = New Query;
	If RecipientsType = Type("CatalogRef.Users") Then
	
		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	User.Ref AS Recipient,
		|	MAX(TableOfRecipients.Excluded) AS Excluded
		|INTO Recipients
		|FROM
		|	TableOfRecipients AS TableOfRecipients
		|	LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON UserGroupCompositions.UsersGroup = TableOfRecipients.Recipient
		|	LEFT JOIN Catalog.Users AS Users
		|		ON Users.Ref = UserGroupCompositions.User
		|WHERE
		|	NOT Users.DeletionMark
		|	AND NOT Users.Invalid
		|	AND NOT Users.IsInternal
		|
		|GROUP BY
		|	User.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	Recipients.Recipient,
		|	Contacts.Presentation AS EMail
		|FROM
		|	Recipients AS Recipients
		|	LEFT JOIN Catalog.Users.ContactInformation AS Contacts
		|		ON Contacts.Ref = Recipients.Recipient
		|		AND Contacts.Kind = &RecipientsEmailAddressKind
		|WHERE
		|	NOT Recipients.Excluded";
		
	Else
		
		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	Recipients.Ref AS Recipient,
		|	Contacts.Presentation AS EMail
		|FROM
		|	Catalog.Users AS Recipients
		|	LEFT JOIN Catalog.Users.ContactInformation AS Contacts
		|		ON Contacts.Ref = Recipients.Ref
		|		AND Contacts.Kind = &RecipientsEmailAddressKind
		|WHERE
		|	Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			NOT Excluded)
		|	AND NOT Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			Excluded)
		|	AND NOT Recipients.DeletionMark
		|	AND &ThisIsNotGroup";
		
		If Not RecipientsMetadata.Hierarchical Then
			// 
			QueryText = StrReplace(QueryText, "IN HIERARCHY", "In");
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		ElsIf RecipientsMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyOfItems Then
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		Else
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "AND NOT Recipients.IsFolder");
		EndIf;
		
		QueryText = StrReplace(QueryText, "Catalog.Users", RecipientsMetadata.FullName());
		
	EndIf;
	
	Query.SetParameter("TableOfRecipients", TableOfRecipients);
	If ValueIsFilled(RecipientsEmailAddressKind) Then
		Query.SetParameter("RecipientsEmailAddressKind", RecipientsEmailAddressKind);
	Else
		QueryText = StrReplace(QueryText, ".Kind = &RecipientsEmailAddressKind", ".Type = &MailAddressType");
		Query.SetParameter("MailAddressType", Enums.ContactInformationTypes.Email);
	EndIf;
	Query.Text = QueryText;
	
	ErrorMessageTextForEventLog = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot generate recipient list ""%1"" due to:';"), String(RecipientsType));
	
	//  Extension mechanism.
	Try
		StandardProcessing = True;
		ReportMailingOverridable.BeforeGenerateMailingRecipientsList(BulkEmail, Query, StandardProcessing, RecipientsList);
		If StandardProcessing <> True Then
			Return RecipientsList;
		EndIf;
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return RecipientsList;
	EndTry;
	
	// Standard data processor.
	Try
		BulkEmailRecipients = Query.Execute().Unload();
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return RecipientsList;
	EndTry;
	
	RecipientsWithoutAnAddress = New Array;
	
	For Each BulkEmailRecipient In BulkEmailRecipients Do
		If Not ValueIsFilled(BulkEmailRecipient.EMail) Then
			RecipientsWithoutAnAddress.Add(String(BulkEmailRecipient.Recipient));
			Continue;
		EndIf;
		
		CurrentAddress = RecipientsList.Get(BulkEmailRecipient.Recipient);
		CurrentAddress = ?(CurrentAddress = Undefined, "", CurrentAddress + "; ");
		RecipientsList[BulkEmailRecipient.Recipient] = CurrentAddress + BulkEmailRecipient.EMail;
	EndDo;
	
	If RecipientsWithoutAnAddress.Count() > 0 Then 
		PatternOfTheWarningText = NStr("en = 'The reports were not sent to the following recipients as the email address is not filled in:
			|-%1.';");
		
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			PatternOfTheWarningText, StrConcat(RecipientsWithoutAnAddress, ";" + Chars.LF + "- "));
		
		LogRecord(LogParameters, EventLogLevel.Warning, WarningText);
	EndIf;
	
	If RecipientsList.Count() = 0 Then
		ErrorsText = NStr("en = 'Cannot generate recipient list ""%1"". Possible reasons:
		| - ""%2"" email is not specified for some of the recipients.
		| - The list of recipients is empty or recipients are marked for deletion.
		| - The groups of recipients are empty.
		| - All recipients are excluded. If you exclude a group, all its members are excluded from the recipient list.
		| - You have insufficient rights to access catalog ""%1"".';");
		
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(ErrorsText, String(RecipientsType),
			String(RecipientsEmailAddressKind)), "");
	EndIf;
	
	Return RecipientsList;
EndFunction

// 
//
// Parameters:
//   BulkEmail - CatalogRef.ReportMailings
//   LogParameters - See LogParameters
//
// Returns: 
//   Array of CatalogRef.ReportMailings
//
Function GenerateArrayOfDistributionRecipients(BulkEmail, LogParameters)
	
	If BulkEmail.Personal Then
		
		RecipientsType = TypeOf(BulkEmail.Author);
		RecipientsMetadata = Metadata.FindByType(RecipientsType);
		
		TableOfRecipients = New ValueTable;
		For Each Attribute In Metadata.Catalogs.ReportMailings.TabularSections.Recipients.Attributes Do
			TableOfRecipients.Columns.Add(Attribute.Name, Attribute.Type);
		EndDo;
		TableOfRecipients.Add().Recipient = BulkEmail.Author;
		
	Else
		RecipientsMetadata = Common.MetadataObjectByID(BulkEmail.MailingRecipientType, False);
		RecipientsType = BulkEmail.MailingRecipientType.MetadataObjectKey.Get();
		TableOfRecipients = BulkEmail.Recipients.Unload();
	EndIf;
	
	ArrayOfRecipients_ = New Array;
	
	If RecipientsMetadata = Undefined Or RecipientsMetadata = Null Then
		Return ArrayOfRecipients_;
	EndIf;

	Query = New Query;
	If RecipientsType = Type("CatalogRef.Users") Then
	
		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	User.Ref AS Recipient
		|FROM
		|	TableOfRecipients AS TableOfRecipients
		|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON UserGroupCompositions.UsersGroup = TableOfRecipients.Recipient
		|		LEFT JOIN Catalog.Users AS Users
		|		ON Users.Ref = UserGroupCompositions.User
		|WHERE
		|	NOT Users.DeletionMark
		|	AND NOT Users.Invalid
		|	AND NOT Users.IsInternal
		|	AND NOT TableOfRecipients.Excluded
		|GROUP BY
		|	User.Ref";
		
	Else
		
		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	Recipients.Ref AS Recipient
		|FROM
		|	Catalog.Users AS Recipients
		|WHERE
		|	Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			NOT Excluded)
		|	AND NOT Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			Excluded)
		|	AND NOT Recipients.DeletionMark
		|	AND &ThisIsNotGroup";
		
		If Not RecipientsMetadata.Hierarchical Then
			// 
			QueryText = StrReplace(QueryText, "IN HIERARCHY", "In");
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		ElsIf RecipientsMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyOfItems Then
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		Else
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "AND NOT Recipients.IsFolder");
		EndIf;
		
		QueryText = StrReplace(QueryText, "Catalog.Users", RecipientsMetadata.FullName());
		
	EndIf;
	
	Query.SetParameter("TableOfRecipients", TableOfRecipients);
	Query.Text = QueryText;
	
	ErrorMessageTextForEventLog = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot generate recipient list ""%1"" due to:';"), String(RecipientsType));
	
	// 
	RecipientsList = New Map;
	Try
		StandardProcessing = True;
		ReportMailingOverridable.BeforeGenerateMailingRecipientsList(BulkEmail, Query, StandardProcessing, RecipientsList);
		If StandardProcessing <> True Then
			For Each Recipient In RecipientsList Do
				ArrayOfRecipients_.Add(Recipient.Key);
			EndDo;
			Return ArrayOfRecipients_;
		EndIf;
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return ArrayOfRecipients_;
	EndTry;
	
	// 
	Try
		BulkEmailRecipients = Query.Execute().Unload();
	Except
		LogRecord(LogParameters,, ErrorMessageTextForEventLog, ErrorInfo());
		Return ArrayOfRecipients_;
	EndTry;
	
	For Each BulkEmailRecipient In BulkEmailRecipients Do
		ArrayOfRecipients_.Add(BulkEmailRecipient.Recipient);
	EndDo;
	
	Return ArrayOfRecipients_;
	
EndFunction

Function TheRecipientsOfTheMailingListAreSelected(BulkEmail, DeliveryParameters, LogParameters, AdditionalSettings)
	
	Recipients = GenerateMailingRecipientsList(BulkEmail, LogParameters);
	
	If AdditionalSettings <> Undefined
		And AdditionalSettings.Property("Recipients") Then
		
		SelectedRecipients = AdditionalSettings.Recipients;
		ExcludedReceivers = New Array;
		
		For Each Recipient In Recipients Do 
			
			If SelectedRecipients[Recipient.Key] = Undefined Then 
				ExcludedReceivers.Add(Recipient.Key);
			EndIf;
			
		EndDo;
		
		For Each Recipient In ExcludedReceivers Do 
			Recipients.Delete(Recipient);
		EndDo;
		
	EndIf;
	
	If Recipients.Count() = 0 Then
		
		DeliveryParameters.UseEmail = False;
		
		If Not DeliveryParameters.UseFolder
			And Not DeliveryParameters.UseNetworkDirectory
			And Not DeliveryParameters.UseFTPResource Then
			
			Return False;
		EndIf;
		
	EndIf;
	
	DeliveryParameters.Recipients = Recipients;
	
	Return True;
	
EndFunction

// Connects, checks and initializes the report by reference and used before generating or editing
// parameters.
//
// Parameters:
//   LogParameters - See LogParameters.
//   ReportParameters - Structure - a settings report and the result of its initialization:
//       * Report - CatalogRef.ReportsOptions - a report reference.
//       * Settings - Undefined
//                   - DataCompositionUserSettings
//                   - ValueTable -
//           
//           
//   PersonalizationAvailable - Boolean - True if a report can be personalized.
//   FormUniqueID - UUID - DCS location address.
//
// Parameters to be changed during the method operation:
//   eportParameters - Structure:
//     Initialization result:
//       * Initialized - Boolean - True if was successful.
//       * Errors          - String - an error text.
//     Properties of all reports:
//       * Name        - String - a report name.
//       * IsOption - Boolean - True if vendor is the ReportOptions catalog.
//       * DCS        - Boolean - True if a report is based on DCS.
//       * Metadata - MetadataObjectReport - report metadata.
//       * Object     - ReportObject, ExternalReport - a report object.
//     Properties of reports based on DCS:
//       * DCSchema               - DataCompositionSchema
//       * DCSettingsComposer - DataCompositionSettingsComposer
//       * DCSettings           - DataCompositionSettings
//       * SchemaURL            - String - an address of data composition schema in the temporary storage.
//     Properties of arbitrary reports:
//       * AvailableAttributes - Structure - a name and parameters of the attribute:
//           ** AttributeName - Structure - attribute parameters:
//               *** Presentation - String - an attribute presentation.
//               *** Type           - TypeDescription - an attribute type.
//
// Returns: 
//   Boolean - 
//
Function InitializeReport(LogParameters, ReportParameters, PersonalizationAvailable, FormUniqueID = Undefined) Export
	
	// Re-initialize the check.
	If ReportParameters.Property("Initialized") Then
		Return ReportParameters.Initialized;
	EndIf;
	
	ReportParameters.Insert("Initialized", False);
	ReportParameters.Insert("Errors", "");
	ReportParameters.Insert("IsPersonalized", False);
	ReportParameters.Insert("PersonalFilters", New Map);
	ReportParameters.Insert("IsOption", TypeOf(ReportParameters.Report) = Type("CatalogRef.ReportsOptions"));
	ReportParameters.Insert("DCS", False);
	ReportParameters.Insert("AvailableAttributes", Undefined);
	ReportParameters.Insert("DCSettingsComposer", Undefined);
	
	ConnectionParameters = ReportsOptions.ReportGenerationParameters();
	ConnectionParameters.OptionRef1 = ReportParameters.Report;
	ConnectionParameters.FormIdentifier = FormUniqueID;
	ConnectionParameters.DCUserSettings = ReportParameters.Settings;
	If TypeOf(ConnectionParameters.DCUserSettings) <> Type("DataCompositionUserSettings") Then
		ConnectionParameters.DCUserSettings = New DataCompositionUserSettings;
	EndIf;
	Try
		Connection = ReportsOptions.AttachReportAndImportSettings(ConnectionParameters);
		CommonClientServer.SupplementStructure(ReportParameters, Connection, True);
	Except
		ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot import settings from the ""%1"" report.';"),
			String(ReportParameters.Report));
		LogRecord(
			LogParameters,
			EventLogLevel.Error,
			ReportParameters.Errors,
			ErrorInfo());
		Return ReportParameters.Initialized;
	EndTry;
	
	// In existing mailings, we generate only reports that are ready for mailing.
	If ReportMailingCached.ReportsToExclude().Find(Connection.RefOfReport) <> Undefined Then
		ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Report ""%1"" is not intended for distribution.';"), String(Connection.RefOfReport));
		LogRecord(LogParameters, EventLogLevel.Error, ReportParameters.Errors);
		Return False;
	EndIf;
	If Not Connection.Success Then
		LogRecord(LogParameters, EventLogLevel.Error, Connection.ErrorText);
		Return False;
	EndIf;
	ReportParameters.DCSettingsComposer = Connection.Object.SettingsComposer;
	
	// Define whether the report is based on Data Composition System.
	If TypeOf(ReportParameters.Settings) = Type("DataCompositionUserSettings") Then
		ReportParameters.DCS = True;
	ElsIf TypeOf(ReportParameters.Settings) = Type("ValueTable") 
		Or TypeOf(ReportParameters.Settings) = Type("Structure") Then
		ReportParameters.DCS = False;
	Else
		ReportParameters.DCS = (ReportParameters.Object.DataCompositionSchema <> Undefined);
	EndIf;
	
	// Initialize a report and fill its parameters.
	If ReportParameters.DCS Then
		
		// Set personal filters.
		If PersonalizationAvailable Then
			DCUserSettings = ReportParameters.DCSettingsComposer.UserSettings;
			Filter = New Structure("Use, Value", True, "[Recipient]");
			FoundItems = ReportsClientServer.SettingsItemsFiltered(DCUserSettings, Filter);
			For Each DCUserSetting In FoundItems Do
				DCID = DCUserSettings.GetIDByObject(DCUserSetting);
				If DCID <> Undefined Then
					ReportParameters.PersonalFilters.Insert(DCID);
				EndIf;
			EndDo;
		EndIf;
		
	Else // 
		
		// 
		ReportParameters.AvailableAttributes = New Structure;
		For Each Attribute In ReportParameters.Metadata.Attributes Do
			ReportParameters.AvailableAttributes.Insert(Attribute.Name, 
				New Structure("Presentation, Type", Attribute.Presentation(), Attribute.Type));
		EndDo;
		
		If ValueIsFilled(ReportParameters.Settings) Then
			
			// 
			// 
			// 
			For Each SettingDetails In ReportParameters.Settings Do
				If TypeOf(SettingDetails) = Type("ValueTableRow") Then
					AttributeName = SettingDetails.Attribute;
				Else
					AttributeName = SettingDetails.Key;
				EndIf;
				SettingValue = SettingDetails.Value;
				
				// Attribute availability.
				If Not ReportParameters.AvailableAttributes.Property(AttributeName) Then
					Continue;
				EndIf;
				
				// Belonging to the mechanism of personalization.
				If PersonalizationAvailable And SettingValue = "[Recipient]" Then
					// 
					ReportParameters.PersonalFilters.Insert(AttributeName);
				Else
					// 
					ReportParameters.Object[AttributeName] = SettingValue;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	ReportParameters.IsPersonalized = (ReportParameters.PersonalFilters.Count() > 0);
	ReportParameters.Initialized = True;
	
	Return True;
EndFunction

// Generates a report and checks that the result is empty.
//
// Parameters:
//   LogParameters - Structure -See LogRecord.
//   ReportParameters  - See InitializeReport
//   Recipient       - CatalogRef - a recipient reference.
//
// Returns: 
//   Structure - 
//       * TabDoc - SpreadsheetDocument - Spreadsheet document.
//       * IsEmpty - Boolean - True if the report did not contain any parameters values.
//
Function GenerateReport(LogParameters, ReportParameters, Recipient = Undefined)
	Result = New Structure("TabDoc, Generated1, IsEmpty", New SpreadsheetDocument, False, True);
	
	If Not ReportParameters.Property("Initialized") Then
		LogRecord(LogParameters, ,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Report ''%1'' not initialized';"), String(ReportParameters.Report)));
		Return Result;
	EndIf;
	
	GenerationParameters = ReportGenerationParameters(ReportParameters, Recipient);
	Generation1 = ReportsOptions.GenerateReport(GenerationParameters, True, Not ReportParameters.SendIfEmpty);
	
	If Not Generation1.Success Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Report ""%1"":';"),
			String(ReportParameters.Report)), Generation1.ErrorText);
		Result.TabDoc = Undefined;
		Return Result;
	EndIf;
	
	Result.Generated1 = True;
	Result.TabDoc = Generation1.SpreadsheetDocument;
	If ReportParameters.SendIfEmpty Then
		Result.IsEmpty = False;
	Else
		Result.IsEmpty = Generation1.IsEmpty;
	EndIf;
	
	Return Result;
EndFunction

Function ReportGenerationParameters(ReportParameters, Recipient)
	
	ReportGenerationParameters = New Structure;
	
	// Fill personalized recipients data.
	If Recipient <> Undefined And ReportParameters.Property("PersonalFilters") Then
		If ReportParameters.DCS Then
			DCUserSettings = ReportParameters.DCSettingsComposer.UserSettings;
			
			For Each KeyAndValue In ReportParameters.PersonalFilters Do
				Setting = DCUserSettings.GetObjectByID(KeyAndValue.Key);
				
				If TypeOf(Setting) = Type("DataCompositionFilterItem") Then
					Setting.RightValue = Recipient;
				ElsIf TypeOf(Setting) = Type("DataCompositionSettingsParameterValue") Then
					Setting.Value = Recipient;
				EndIf;
			EndDo;
			
			ReportGenerationParameters.Insert("DCUserSettings", DCUserSettings);
		Else
			For Each KeyAndValue In ReportParameters.PersonalFilters Do
				ReportParameters.Object[KeyAndValue.Key] = Recipient;
			EndDo;
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure("Report, Object, DCS, DCSettingsComposer");
	FillPropertyValues(AdditionalParameters, ReportParameters);
	
	ReportMailingOverridable.OnPrepareReportGenerationParameters(ReportGenerationParameters, AdditionalParameters);

	Result = ReportsOptions.ReportGenerationParameters();
	CommonClientServer.SupplementStructure(Result, ReportGenerationParameters, True);

	FillPropertyValues(ReportParameters, AdditionalParameters);
	Result.Connection = ReportParameters;
	
	Return Result;
	
EndFunction

// Transports attachments for all delivery methods.
//
// Parameters:
//   LogParameters  - See LogParameters
//   DeliveryParameters - See ExecuteBulkEmail
//   Attachments          - Map of KeyAndValue:
//     * Key     - String - file name
//     * Value - String -
//
// Returns: 
//   Structure:
//       * Delivery  - String - a delivery method presentation.
//       * Executed - Boolean - True if the delivery is executed at least by one of the methods.
//
Function ExecuteDelivery(LogParameters, DeliveryParameters, Attachments) Export
	Result = False;
	ErrorMessageTemplate = NStr("en = 'Reports are not delivered';");
	TestMode = CommonClientServer.StructureProperty(DeliveryParameters, "TestMode", False);
	
	////////////////////////////////////////////////////////////////////////////
	// To network directory.
	
	If DeliveryParameters.UseNetworkDirectory Then
		
		ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryWindows;
		SystemData = New SystemInfo;
		ServerPlatformType = SystemData.PlatformType;		
		
		If ServerPlatformType = PlatformType.Linux_x86
			Or ServerPlatformType = PlatformType.Linux_x86_64 Then
			ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryLinux;
		EndIf;
		
		AllRecipients = GenerateArrayOfDistributionRecipients(LogParameters.Data, LogParameters);
		Try
			SentCount = 0;
			QuantityToSend = Attachments.Count();
			For Each Attachment In Attachments Do
				FileCopy(Attachment.Value, ServerNetworkDdirectory + Attachment.Key);
				If DeliveryParameters.AddReferences <> "" Then
					DeliveryParameters.RecipientReportsPresentation = StrReplace(
						DeliveryParameters.RecipientReportsPresentation,
						Attachment.Value,
						DeliveryParameters.NetworkDirectoryWindows + Attachment.Key);
				EndIf;
				SentCount = SentCount + 1;
				ProgressText = ReportDistributionProgressText(DeliveryParameters, SentCount, QuantityToSend);
				ProgressPercent = Round(SentCount * 100 / QuantityToSend);
				TimeConsumingOperations.ReportProgress(ProgressPercent, ProgressText);
			EndDo;
			Result = True;
			DeliveryParameters.ExecutedToNetworkDirectory = True;
			
			If TestMode Then // 
				For Each Attachment In Attachments Do
					DeleteFiles(ServerNetworkDdirectory + Attachment.Key);
				EndDo;
			EndIf;
			
			If GetFunctionalOption("RetainReportDistributionHistory") 
			   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Report distributions are placed in the ''%1'' network directory.';"), ServerNetworkDdirectory);
				For Each Recipient In AllRecipients Do     					
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate);  
					HistoryFields.Account = DeliveryParameters.Account;    
					HistoryFields.Comment = MessageText; 
					HistoryFields.Executed = True;   
					HistoryFields.DeliveryDate = CurrentSessionDate();
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
					HistoryFields.EmailID = "";
					
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			EndIf;
		Except
			LogRecord(LogParameters, , ErrorMessageTemplate, ErrorInfo());
			If GetFunctionalOption("RetainReportDistributionHistory")
			   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
				For Each Recipient In AllRecipients Do
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate);   
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.Comment = ErrorMessageTemplate;
					HistoryFields.Executed = False;
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
					HistoryFields.EmailID = "";
					
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			EndIf;
		EndTry;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// To FTP resource.
	
	If DeliveryParameters.UseFTPResource Then
		
		Target = "ftp://"+ DeliveryParameters.Server +":"+ Format(DeliveryParameters.Port, "NZ=0; NG=0") + DeliveryParameters.Directory;
		AllRecipients = GenerateArrayOfDistributionRecipients(LogParameters.Data, LogParameters);
		Try
			If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
				ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
				Proxy = ModuleNetworkDownload.GetProxy("ftp");
			Else
				Proxy = Undefined;
			EndIf;
			If DeliveryParameters.Property("Password") Then
				Password = DeliveryParameters.Password;
			Else
				SetPrivilegedMode(True);
				DataFromStorage = Common.ReadDataFromSecureStorage(DeliveryParameters.Owner, "FTPPassword");
				SetPrivilegedMode(False);
				Password = ?(ValueIsFilled(DataFromStorage), DataFromStorage, "");
			EndIf;
			Join = New FTPConnection(
				DeliveryParameters.Server,
				DeliveryParameters.Port,
				DeliveryParameters.Login,
				Password,
				Proxy,
				DeliveryParameters.PassiveConnection,
				15);
			Join.SetCurrentDirectory(DeliveryParameters.Directory);
			SentCount = 0;
			QuantityToSend = Attachments.Count();
			For Each Attachment In Attachments Do
				Join.Put(Attachment.Value, DeliveryParameters.Directory + Attachment.Key);
				If DeliveryParameters.AddReferences <> "" Then
					DeliveryParameters.RecipientReportsPresentation = StrReplace(
						DeliveryParameters.RecipientReportsPresentation,
						Attachment.Value,
						Target + Attachment.Key);
					SentCount = SentCount + 1;
					ProgressText = ReportDistributionProgressText(DeliveryParameters, SentCount, QuantityToSend);
					ProgressPercent = Round(SentCount * 100 / QuantityToSend);
					TimeConsumingOperations.ReportProgress(ProgressPercent, ProgressText);
				EndIf;
			EndDo;
			
			Result = True;
			DeliveryParameters.ExecutedAtFTP = True;
			
			If TestMode Then // 
				For Each Attachment In Attachments Do
					Join.Delete(DeliveryParameters.Directory + Attachment.Key);
				EndDo;
			EndIf;
			
			If GetFunctionalOption("RetainReportDistributionHistory")
			   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Report distributions published on ''%1''.';"), Target);
				For Each Recipient In AllRecipients Do
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate); 
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.Comment = MessageText;
					HistoryFields.Executed = True; 
					HistoryFields.DeliveryDate = CurrentSessionDate();
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
					HistoryFields.EmailID = "";
			
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			EndIf;
		Except
			LogRecord(LogParameters, , ErrorMessageTemplate, ErrorInfo());
			If GetFunctionalOption("RetainReportDistributionHistory")
			   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
				For Each Recipient In AllRecipients Do
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate); 
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.Comment = ErrorMessageTemplate;
					HistoryFields.Executed = False;
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
					HistoryFields.EmailID = "";
					
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			EndIf;
		EndTry;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// To folder.
	
	If DeliveryParameters.UseFolder Then
		AllRecipients = GenerateArrayOfDistributionRecipients(LogParameters.Data, LogParameters);
		If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
			ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
			Try
				ModuleFilesOperationsInternal.OnExecuteDeliveryToFolder(DeliveryParameters, Attachments);
				Result = True;
				DeliveryParameters.ExecutedToFolder = True; 
				If GetFunctionalOption("RetainReportDistributionHistory")
				   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
					"en = 'Report distributions are placed in the ''%1'' folder.';"), String(DeliveryParameters.Folder));
					For Each Recipient In AllRecipients Do
						HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate);
						HistoryFields.Account = DeliveryParameters.Account;
						HistoryFields.Comment = MessageText;
						HistoryFields.Executed = True;
						HistoryFields.DeliveryDate = CurrentSessionDate();
						HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
						HistoryFields.EmailID = "";
						
						InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(
						HistoryFields);
					EndDo; 
				EndIf;
			Except
				LogRecord(LogParameters, , ErrorMessageTemplate, ErrorInfo()); 
				If GetFunctionalOption("RetainReportDistributionHistory")
				   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
					For Each Recipient In AllRecipients Do
						HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient, DeliveryParameters.ExecutionDate); 
						HistoryFields.Account = DeliveryParameters.Account;
						HistoryFields.Comment = ErrorMessageTemplate;
						HistoryFields.Executed = False;
						HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient);
						HistoryFields.EmailID = "";
						
						InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(
						HistoryFields);
					EndDo;
				EndIf;
			EndTry;
		EndIf;
		
	EndIf;
	
	////////////////////////////////////////////////////////////////////////////
	// By email.
	
	If DeliveryParameters.UseEmail Then
		
		If DeliveryParameters.NotifyOnly Then
			ErrorMessageTemplate = NStr("en = 'Cannot send report distribution notification by email:';");
			EmailAttachments1 = New Map;
		ElsIf Not DeliveryParameters.ShouldAttachReports Then
			EmailAttachments1 = New Map;
		Else
			ErrorMessageTemplate = NStr("en = 'Cannot send report by email:';");
			EmailAttachments1 = Attachments;
		EndIf;
		
		Try
			SendReportsToRecipient(EmailAttachments1, DeliveryParameters, LogParameters);
			If Not DeliveryParameters.NotifyOnly Then
				Result = True;
			EndIf;
			If Result = True Then
				DeliveryParameters.ExecutedByEmail = True;
			EndIf;
			
		Except
			ExtendedErrorPresentation = EmailOperations.ExtendedErrorPresentation(
				ErrorInfo(), Common.DefaultLanguageCode());
				
			LogRecord(LogParameters, EventLogLevel.Error,
				ErrorMessageTemplate, ExtendedErrorPresentation);
				
				If GetFunctionalOption("RetainReportDistributionHistory") And Not EmailClientUsed()
				   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
					For Each RecipientRow In DeliveryParameters.Recipients Do
						RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(RecipientRow.Value);
						For Each EMAddress In RecipientAddresses Do							
							HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, RecipientRow.Key, DeliveryParameters.ExecutionDate); 
							HistoryFields.Account = DeliveryParameters.Account;    
							HistoryFields.EMAddress = EMAddress;
							HistoryFields.Comment = StringFunctionsClientServer.SubstituteParametersToString(
							"%1 %2", ErrorMessageTemplate, ExtendedErrorPresentation);
							HistoryFields.Executed = False;
							HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, RecipientRow.Key,
							EMAddress);
							HistoryFields.EmailID = "";
							
							InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields); 
						EndDo;
						
					EndDo;
				EndIf;		
		EndTry;
		
	EndIf;
	
	Return Result;
EndFunction

// Gets a username by the Users catalog reference.
//
// Parameters:
//   User - CatalogRef.Users - a user reference.
//
// Returns:
//   String - 
//
Function IBUserName(User) Export
	If Not ValueIsFilled(User) Then
		Return "";
	EndIf;
	
	SetPrivilegedMode(True);
	
	IBUser = InfoBaseUsers.FindByUUID(
		Common.ObjectAttributeValue(User, "IBUserID"));
	If IBUser = Undefined Then
		Return "";
	EndIf;
	
	Return IBUser.Name;
EndFunction

// Creates a record in the event log and outputs user messages.
// A brief error presentation is output to the user, and a detailed error presentation is written to the log.
//
// Parameters:
//   LogParameters - See LogParameters
//   LogLevel - EventLogLevel - message importance for the administrator.
//       Determined automatically based on the ProblemDetails parameter type.
//       When type = ErrorInfo, then Error, when type = String, then Warning,
//       otherwise Information.
//   Text - String - brief details of the issue.
//   IssueDetails - ErrorInfo
//                    - String - 
//
Procedure LogRecord(LogParameters, Val LogLevel = Undefined, Val Text = "", Val IssueDetails = Undefined) Export
	
	If LogParameters = Undefined Then
		Return;
	EndIf;
	
	// Determine the event log level based on the type of the passed error message.
	If TypeOf(LogLevel) <> Type("EventLogLevel") Then
		If TypeOf(IssueDetails) = Type("ErrorInfo") Then
			LogLevel = EventLogLevel.Error;
		ElsIf TypeOf(IssueDetails) = Type("String") Then
			LogLevel = EventLogLevel.Warning;
		Else
			LogLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	If LogLevel = EventLogLevel.Error Then
		LogParameters.Insert("HadErrors", True);
	ElsIf LogLevel = EventLogLevel.Warning Then
		LogParameters.Insert("HasWarnings", True);
	EndIf;
	
	WriteToLog = ValueIsFilled(LogParameters.Data);
	
	TextForLog      = Text;
	TextForUser = Text;
	If TypeOf(IssueDetails) = Type("ErrorInfo") Then
		If WriteToLog Then
			TextForLog = TextForLog + Chars.LF + ErrorProcessing.DetailErrorDescription(IssueDetails);
		EndIf;	
		TextForUser = TextForUser + Chars.LF + ErrorProcessing.BriefErrorDescription(IssueDetails);
	ElsIf TypeOf(IssueDetails) = Type("String") Then
		If WriteToLog Then
			TextForLog = TextForLog + Chars.LF + IssueDetails;
		EndIf;
		TextForUser = TextForUser + Chars.LF + IssueDetails;
	EndIf;
	
	// The event log.
	If WriteToLog Then
		WriteLogEvent(LogParameters.EventName, LogLevel, LogParameters.Metadata, 
			LogParameters.Data, TrimAll(TextForLog));
	EndIf;
	
	// 
	TextForUser = TrimAll(TextForUser);
	If (LogLevel = EventLogLevel.Error) Or (LogLevel = EventLogLevel.Warning) Then
		If LogParameters.Property("ErrorsArray") And TypeOf(LogParameters.ErrorsArray) = Type("Array") Then
			Message = New UserMessage;
			Message.Text = TextForUser;
			Message.SetData(LogParameters.Data);
			ErrorsArray = LogParameters.ErrorsArray; // Array of UserMessage
			ErrorsArray.Add(Message);
		Else
			Common.MessageToUser(TextForUser,,,LogParameters.Data);
		EndIf;
	EndIf;
	
EndProcedure

// Generates PermissionsArray according to report mailing data.
//
// Parameters:
//  BulkEmail - QueryResultSelection
//
// Returns:
//  Array
//
Function PermissionsToUseServerResources(BulkEmail) Export
	Permissions = New Array;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If BulkEmail.UseNetworkDirectory Then
		If ValueIsFilled(BulkEmail.NetworkDirectoryWindows) Then
			Item = ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				BulkEmail.NetworkDirectoryWindows,
				True,
				True,
				NStr("en = 'Network directory to publish reports from a Windows server.';"));
			Permissions.Add(Item);
		EndIf;
		If ValueIsFilled(BulkEmail.NetworkDirectoryLinux) Then
			Item = ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				BulkEmail.NetworkDirectoryLinux,
				True,
				True,
				NStr("en = 'Network directory to publish reports from a Linux server.';"));
			Permissions.Add(Item);
		EndIf;
	EndIf;
	If BulkEmail.UseFTPResource Then
		If ValueIsFilled(BulkEmail.FTPServer) Then
			Item = ModuleSafeModeManager.PermissionToUseInternetResource(
				"FTP",
				BulkEmail.FTPServer + BulkEmail.FTPDirectory,
				BulkEmail.FTPPort,
				NStr("en = 'FTP server to publish reports.';"));
			Permissions.Add(Item);
		EndIf;
	EndIf;
	Return Permissions;
EndFunction

Function EventLogParameters(BulkEmail) Export
	Query = New Query;
	Query.Text =
	"SELECT
	|	States1.LastRunStart,
	|	States1.LastRunCompletion,
	|	States1.SessionNumber
	|FROM
	|	InformationRegister.ReportMailingStates AS States1
	|WHERE
	|	States1.BulkEmail = &BulkEmail";
	Query.SetParameter("BulkEmail", BulkEmail);
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	Result = New Structure;
	Result.Insert("StartDate", Selection.LastRunStart);
	Result.Insert("EndDate", Selection.LastRunCompletion);
	// Interval is not more than 30 minutes because sessions numbers can be reused.
	If Not ValueIsFilled(Result.EndDate) Or Result.EndDate < Result.StartDate Then
		Result.EndDate = Result.StartDate + 30 * 60; 
	EndIf;
	If Not ValueIsFilled(Selection.SessionNumber) Then
		Result.Insert("Data", BulkEmail);
	Else
		Sessions = New ValueList;
		Sessions.Add(Selection.SessionNumber);
		Result.Insert("Session", Sessions);
	EndIf;
	Return Result;
EndFunction

Function GetEncryptionCertificatesForDistributionRecipients(RecipientsList) Export
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	CertificatesOfReportDistributionRecipients.BulkEmailRecipient,
		|	CertificatesOfReportDistributionRecipients.CertificateToEncrypt
		|FROM
		|	InformationRegister.CertificatesOfReportDistributionRecipients AS CertificatesOfReportDistributionRecipients
		|WHERE
		|	CertificatesOfReportDistributionRecipients.BulkEmailRecipient IN (&RecipientsList)";
	
	Query.SetParameter("RecipientsList", RecipientsList);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();

EndFunction

Function ReportRedistributionRecipients(BulkEmail, LastRunStart, SessionNumber) Export
	
	Recipients = New Map;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	ReportsDistributionHistory.Recipient AS Recipient,
	|	ReportsDistributionHistory.EMAddress AS EMAddress,
	|	MAX(ReportsDistributionHistory.Executed) AS Executed
	|INTO TT_Recipients
	|FROM
	|	InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
	|WHERE
	|	ReportsDistributionHistory.ReportMailing = &ReportMailing
	|	AND ReportsDistributionHistory.StartDistribution = &StartDistribution
	|	AND ReportsDistributionHistory.SessionNumber = &SessionNumber
	|	AND ReportsDistributionHistory.EMAddress <> """"
	|
	|GROUP BY
	|	ReportsDistributionHistory.Recipient,
	|	ReportsDistributionHistory.EMAddress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Recipients.Recipient AS Recipient,
	|	TT_Recipients.EMAddress AS Email
	|FROM
	|	TT_Recipients AS TT_Recipients
	|WHERE
	|	NOT TT_Recipients.Executed
	|TOTALS BY
	|	Recipient";

	Query.SetParameter("ReportMailing",BulkEmail);
	Query.SetParameter("StartDistribution", LastRunStart);
	Query.SetParameter("SessionNumber", SessionNumber);
	
	QueryResult = Query.Execute();
	
	SampleRecipients = QueryResult.Select(QueryResultIteration.ByGroups);
		
	While SampleRecipients.Next() Do
		Selection = SampleRecipients.Select();
		Email = "";
		While Selection.Next() Do
			CurrentAddress = ?(IsBlankString(Email), "",
				Email + "; ");
			Email = CurrentAddress + Selection.Email;
		EndDo; 
		Recipients.Insert(SampleRecipients.Recipient, Email);
	EndDo;
	
	Return Recipients;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// In addition to generating reports, executes personalization on the list of recipients
//   and generates reports broken down by recipients (if necessary).
//
// Parameters:
//   LogParameters - Structure - parameters of the writing to the event log:
//       * Prefix    - String           - prefix for the name of the event of the event log.
//       * Metadata - MetadataObject - metadata to write to the event log.
//       * Data     - Arbitrary     - data to write to the event log.
//   ReportParameters   - See ExecuteBulkEmail.Var_Reports
//   ReportsTree     - ValueTree   - reports and result of formation.
//   DeliveryParameters - See DeliveryParameters
//   RecipientRef  - CatalogRef -
//
// 
// 
//
Procedure GenerateAndSaveReport(LogParameters, ReportParameters, ReportsTree, DeliveryParameters, RecipientRef)
	
	// 
	//  
	//   
	//   
	//   
	RecipientRow = DefineTreeRowForRecipient(ReportsTree, RecipientRef, DeliveryParameters);
	RecipientsDirectory = RecipientRow.Value;

	// Generate a report for the recipient.
	Result = GenerateReport(LogParameters, ReportParameters, RecipientRef);
	
	// Check the result.
	If Not Result.Generated1 Or (Result.IsEmpty And Not ReportParameters.SendIfEmpty) Then
		
		If GetFunctionalOption("RetainReportDistributionHistory")
		   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
			If Result.Generated1 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = '- ""%1"" is not sent as it is empty.';"), String(ReportParameters.Report));
			Else
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = '- ""%1"" is not sent as it is not generated due to incorrect parameters.';"),
				String(ReportParameters.Report));
			EndIf;
			
			If ValueIsFilled(RecipientRef) Then
				RecipientAddresses = DeliveryParameters.Recipients.Get(RecipientRef);
				If RecipientAddresses <> Undefined Then
					RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(RecipientAddresses);
					For Each Whom In RecipientAddresses Do
						HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, RecipientRef, DeliveryParameters.ExecutionDate);
						HistoryFields.Account = DeliveryParameters.Account;
						HistoryFields.EMAddress = Whom.Address;
						HistoryFields.Comment = MessageText;
						HistoryFields.Executed = False;
						HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, RecipientRef, Whom.Address);
						
						InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
					EndDo;
				EndIf;
			Else
				For Each Recipient In DeliveryParameters.Recipients Do 
					RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(Recipient.Value);
					For Each Whom In RecipientAddresses Do
						HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient.Key, DeliveryParameters.ExecutionDate);
						HistoryFields.Account = DeliveryParameters.Account;
						HistoryFields.EMAddress = Whom.Address;
						HistoryFields.Comment = MessageText;
						HistoryFields.Executed = False;
						HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient.Key, Whom.Address);
						
						InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
					EndDo;
				EndDo;
			EndIf;
		EndIf;

		Return;
		
	EndIf;
	
	// 
	// 
	//   
	//   
	//   
	RowReport = RecipientRow.Rows.Add();
	RowReport.Level   = 2;
	RowReport.Key      = String(ReportParameters.Report);
	RowReport.Value  = Result.TabDoc;
	RowReport.Settings = Common.CopyRecursive(ReportParameters);
	
	// 
	// 
	// 
	RowReport.Settings.Delete("Object");
	RowReport.Settings.Delete("DCSettingsComposer");
	If RowReport.Settings.Property("Metadata") Then
		RowReport.Settings.Metadata = RowReport.Settings.Metadata.FullName();
	EndIf;
	
	ReportPresentation = TrimAll(RowReport.Key);
	
	If DeliveryParameters.UseEmail And DeliveryParameters.ShouldInsertReportsIntoEmailBody
		And Not DeliveryParameters.ShouldAttachReports And Not DeliveryParameters.UseFolder 
		And Not DeliveryParameters.UseNetworkDirectory And Not DeliveryParameters.UseFTPResource Then
	
		ReportParametersForEmailText = ReportParametersForEmailText(RecipientsDirectory, ReportPresentation,
			ReportParameters.DescriptionTemplate1, RecipientRef, RowReport.Value);
		PrepareReportForEmailText(DeliveryParameters, ReportParametersForEmailText, LogParameters);
	Else
		Period = GetPeriodFromUserSettings(ReportParameters.DCUserSettings);
		IsReportPreparedForEmailText = False;
	// Save a spreadsheet document in formats.
		FormatsPresentation = "";
		For Each Format In ReportParameters.Formats Do

			FormatParameters = DeliveryParameters.FormatsParameters.Get(Format);

			If FormatParameters = Undefined Then
				Continue;
			EndIf;

			FullFileName = FullFileNameFromTemplate(
			RecipientsDirectory, RowReport.Key, FormatParameters, DeliveryParameters,
				ReportParameters.DescriptionTemplate1, Period);

			FindFreeFileName(FullFileName);

			StandardProcessing = True;
		
		// 
			ReportMailingOverridable.BeforeSaveSpreadsheetDocumentToFormat(
			StandardProcessing, RowReport.Value, Format, FullFileName);
		
		// Save a report by the built-in subsystem tools.
			If StandardProcessing = True Then
				ErrorTitle = NStr("en = 'Error saving report %1 as %2:';");

				If FormatParameters.FileType = Undefined Then
					LogRecord(LogParameters, EventLogLevel.Error,
						StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, RowReport.Key,
						FormatParameters.Name), NStr("en = 'Format is not supported.';"));
					Continue;
				EndIf;

				ResultDocument = RowReport.Value; // SpreadsheetDocument

				Try
					ResultDocument.Write(FullFileName, FormatParameters.FileType);
				Except
					LogRecord(LogParameters, EventLogLevel.Error,
						StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, RowReport.Key,
						FormatParameters.Name), ErrorInfo());
					Continue;
				EndTry;
			EndIf;
		
		// Checks and result registration.
			TempFile = New File(FullFileName);
			If Not TempFile.Exists() Then
				LogRecord(LogParameters, EventLogLevel.Error,
					StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle + Chars.LF + NStr(
					"en = 'File ""%3"" does not exist.';"), RowReport.Key, FormatParameters.Name,
					TempFile.FullName));
				Continue;
			EndIf;
		
		// 
		// 
		//   
		//   
		//   
			FileRow = RowReport.Rows.Add();
			FileRow.Level = 3;
			FileRow.Key      = TempFile.Name;
			FileRow.Value  = TempFile.FullName;

			FileRow.Settings = New Structure("FileWithDirectory, FileName, FullFileName, DirectoryName, FullDirectoryName, 
												   |Format, Name, Extension, FileType, Ref");

			FileRow.Settings.Format = Format;
			FillPropertyValues(FileRow.Settings, FormatParameters, "Name, Extension, FileType");

			FileRow.Settings.FileName          = TempFile.Name;
			FileRow.Settings.FullFileName    = TempFile.FullName;
			FileRow.Settings.DirectoryName       = TempFile.BaseName + "_files";
			FileRow.Settings.FullDirectoryName = TempFile.Path + FileRow.Settings.DirectoryName + "\";

			FileDirectory = New File(FileRow.Settings.FullDirectoryName);

			FileRow.Settings.FileWithDirectory = (FileDirectory.Exists() And FileDirectory.IsDirectory());

			If FileRow.Settings.FileWithDirectory And Not DeliveryParameters.Archive Then
			// Directory and the file are archived and an archive is sent instead of the file.
				ArchiveName       = TempFile.BaseName + ".zip";
				FullArchiveName = RecipientsDirectory + ArchiveName;

				SaveMode = ZIPStorePathMode.StoreRelativePath;
				ProcessingMode  = ZIPSubDirProcessingMode.ProcessRecursively;

				ZipFileWriter = New ZipFileWriter(FullArchiveName);
				ZipFileWriter.Add(FileRow.Settings.FullFileName, SaveMode, ProcessingMode);
				ZipFileWriter.Add(FileRow.Settings.FullDirectoryName, SaveMode, ProcessingMode);
				ZipFileWriter.Write();

				FileRow.Key     = ArchiveName;
				FileRow.Value = FullArchiveName;
			EndIf;

			FileDirectory = Undefined;
			TempFile = Undefined;

			FormatsPresentation = FormatsPresentation + ?(FormatsPresentation = "", "", ", ") + ?(
				DeliveryParameters.AddReferences = "ToFormats", "<a href = '" + FileRow.Value + "'>", "")
				+ FormatParameters.Name + ?(DeliveryParameters.AddReferences = "ToFormats", "</a>", "");
			
		//
			If DeliveryParameters.AddReferences = "AfterReports" Then
				ReportPresentation = ReportPresentation + Chars.LF + "<" + FileRow.Value + ">";
			EndIf;

			If DeliveryParameters.UseEmail And DeliveryParameters.ShouldInsertReportsIntoEmailBody Then
				If (DeliveryParameters.HTMLFormatEmail And Format = Enums.ReportSaveFormats.HTML)
				   Or (Not DeliveryParameters.HTMLFormatEmail And Format = Enums.ReportSaveFormats.TXT) Then
					ReportParametersForEmailText = ReportParametersForEmailText(RecipientsDirectory, ReportPresentation,
						ReportParameters.DescriptionTemplate1, RecipientRef, RowReport.Value);
					PrepareReportForEmailText(DeliveryParameters, ReportParametersForEmailText,
						LogParameters, FullFileName);
					IsReportPreparedForEmailText = True;
				EndIf;
			EndIf;

		EndDo;
		
		If DeliveryParameters.UseEmail And DeliveryParameters.ShouldInsertReportsIntoEmailBody And Not IsReportPreparedForEmailText Then
			ReportParametersForEmailText = ReportParametersForEmailText(RecipientsDirectory, ReportPresentation,
				ReportParameters.DescriptionTemplate1, RecipientRef, RowReport.Value);
			PrepareReportForEmailText(DeliveryParameters, ReportParametersForEmailText, LogParameters);
		EndIf;

	EndIf;
	
	// 
	ReportPresentation = StrReplace(ReportPresentation, "[FormatsPresentation]", FormatsPresentation);
	RowReport.Settings.Insert("PresentationInEmail", ReportPresentation);
	
EndProcedure

Function ReportParametersForEmailText(RecipientsDirectory, ReportPresentation, DescriptionTemplate1, Recipient, SpreadsheetDocument)
	
	ReportParameters = New Structure("RecipientsDirectory, ReportPresentation, DescriptionTemplate1, Recipient, SpreadsheetDocument");
	ReportParameters.RecipientsDirectory = RecipientsDirectory;
	ReportParameters.ReportPresentation = ReportPresentation;
	ReportParameters.DescriptionTemplate1 = DescriptionTemplate1;
	ReportParameters.Recipient = Recipient;
	ReportParameters.SpreadsheetDocument = SpreadsheetDocument;
	
	Return ReportParameters;
	
EndFunction

Procedure PrepareReportForEmailText(DeliveryParameters, ReportParameters, LogParameters, FullFileName = Undefined)

	If FullFileName = Undefined Then
		FullFileName = PathToTempReportFileForEmailText(DeliveryParameters, ReportParameters, LogParameters);
	EndIf;

	MapKey = ?(ReportParameters.Recipient = Undefined, "Key", ReportParameters.Recipient);
	ReportsForText = DeliveryParameters.ReportsForEmailText.Get(MapKey);
	If ReportsForText = Undefined Then
		FileStructure = New Structure("FullFileName, Presentation", FullFileName, ReportParameters.ReportPresentation);
		ReportsForText = New Array;
		ReportsForText.Add(FileStructure);
		DeliveryParameters.ReportsForEmailText.Insert(MapKey, ReportsForText);
	Else
		FileStructure = New Structure("FullFileName, Presentation", FullFileName, ReportParameters.ReportPresentation);
		ReportsForText.Add(FileStructure);
	EndIf;

EndProcedure

Function PathToTempReportFileForEmailText(DeliveryParameters, ReportParameters, LogParameters)

	Format = ?(DeliveryParameters.HTMLFormatEmail, Enums.ReportSaveFormats.HTML,
		Enums.ReportSaveFormats.TXT);

	FormatParameters = DeliveryParameters.FormatsParameters.Get(Format);
	If FormatParameters = Undefined Then
		Return Undefined;
	EndIf;

	FullFileName = FullFileNameFromTemplate(ReportParameters.RecipientsDirectory, ReportParameters.ReportPresentation,
		FormatParameters, DeliveryParameters, ReportParameters.DescriptionTemplate1, Undefined);

	FindFreeFileName(FullFileName);
	ErrorTitle = NStr("en = 'Error saving report %1 as %2:';");
	If FormatParameters.FileType = Undefined Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, ReportParameters.ReportPresentation,
			FormatParameters.Name), NStr("en = 'Format is not supported.';"));
		Return Undefined;
	EndIf;

	Try
		ReportParameters.SpreadsheetDocument.Write(FullFileName, FormatParameters.FileType);
	Except
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(ErrorTitle, ReportParameters.ReportPresentation,
			FormatParameters.Name), ErrorInfo());
		Return Undefined;
	EndTry;

	Return FullFileName;

EndFunction

//  
// 
// 
//
// 
//   See ExecuteBulkEmail.
//
Function CheckAndFillExecutionParameters(ReportsTable, DeliveryParameters, MailingDescription, LogParameters)
	// Parameters of the writing to the event log.
	If TypeOf(LogParameters) <> Type("Structure") Then
		LogParameters = New Structure;
	EndIf;
	If Not LogParameters.Property("EventName") Then
		LogParameters.Insert("EventName", NStr("en = 'Report distribution. Manual start';", Common.DefaultLanguageCode()));
	EndIf;
	If Not LogParameters.Property("Data") Then
		LogParameters.Insert("Data", MailingDescription);
	EndIf;
	If Not LogParameters.Property("Metadata") Then
		LogParameters.Insert("Metadata", Undefined);
		DataType = TypeOf(LogParameters.Data);
		If DataType <> Type("Structure") And Common.IsReference(DataType) Then
			LogParameters.Metadata = LogParameters.Data.Metadata();
		EndIf;
	EndIf;
	
	// Check access rights.
	If Not OutputRight(LogParameters) Then
		Return False;
	EndIf;
	
	ReportsAvailability = ReportsOptions.ReportsAvailability(ReportsTable.UnloadColumn("Report"));
	Unavailable2 = ReportsAvailability.Copy(New Structure("Available", False));
	If Unavailable2.Count() > 0 Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Report distribution contains unavailable reports (%1):%2';"),
			Unavailable2.Count(),
			Chars.LF + Chars.Tab + StrConcat(Unavailable2.UnloadColumn("Presentation"), Chars.LF + Chars.Tab)));
		Return False;
	EndIf;
	
	DeliveryParameters.BulkEmail = TrimAll(String(MailingDescription));
	DeliveryParameters.ExecutionDate = CurrentSessionDate();
	DeliveryParameters.HadErrors = False;
	DeliveryParameters.HasWarnings = False;
	DeliveryParameters.ExecutedToFolder = False;
	DeliveryParameters.ExecutedToNetworkDirectory = False;
	DeliveryParameters.ExecutedAtFTP = False;
	DeliveryParameters.ExecutedByEmail = False;
	DeliveryParameters.ExecutedPublicationMethods = "";
	
	If DeliveryParameters.UseFolder Then
		If Not ValueIsFilled(DeliveryParameters.Folder) Then
			DeliveryParameters.UseFolder = False;
			LogRecord(LogParameters, EventLogLevel.Warning,
				NStr("en = 'Directory not specified. Delivery to directory is disabled.';"));
		Else
			If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
				ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
				AccessRight = ModuleFilesOperationsInternal.RightToAddFilesToFolder(DeliveryParameters.Folder);
			Else
				AccessRight = True;
			EndIf;
			If Not AccessRight Then
				SetPrivilegedMode(True);
				FoldersPresentation = String(DeliveryParameters.Folder);
				SetPrivilegedMode(False);
				LogRecord(LogParameters, EventLogLevel.Error,
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Insufficient rights to create files in directory ""%1"".';"),
					FoldersPresentation));
				Return False;
			EndIf;
		EndIf;
	EndIf;
	
	If DeliveryParameters.UseNetworkDirectory Then
		If Not ValueIsFilled(DeliveryParameters.NetworkDirectoryWindows) 
			Or Not ValueIsFilled(DeliveryParameters.NetworkDirectoryLinux) Then
			
			If ValueIsFilled(DeliveryParameters.NetworkDirectoryWindows) Then
				SubstitutionValue = NStr("en = 'Linux';");
			ElsIf ValueIsFilled(DeliveryParameters.NetworkDirectoryLinux) Then
				SubstitutionValue = NStr("en = 'Windows';");
			Else
				SubstitutionValue = NStr("en = 'Windows and Linux';");
			EndIf;
			
			DeliveryParameters.UseNetworkDirectory = False;
			LogRecord(LogParameters, EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Network directory %1 not selected. Delivery to network directory is disabled.';"),
				SubstitutionValue));
			
		Else
			
			DeliveryParameters.NetworkDirectoryWindows = CommonClientServer.AddLastPathSeparator(
				DeliveryParameters.NetworkDirectoryWindows);
			DeliveryParameters.NetworkDirectoryLinux = CommonClientServer.AddLastPathSeparator(
				DeliveryParameters.NetworkDirectoryLinux);
			
		EndIf;
	EndIf;
	
	If DeliveryParameters.UseFTPResource And Not ValueIsFilled(DeliveryParameters.Server) Then
		DeliveryParameters.UseFTPResource = False;
		LogRecord(LogParameters, EventLogLevel.Error,
			NStr("en = 'FTP server not specified. Delivery to FTP directory is disabled.';"));
	EndIf;
	
	If DeliveryParameters.UseEmail And Not ValueIsFilled(DeliveryParameters.Account) Then
		DeliveryParameters.UseEmail = False;
		LogRecord(LogParameters, EventLogLevel.Error,
			NStr("en = 'Email account is not selected. Email delivery is disabled.';"));
	EndIf;
	
	If DeliveryParameters.Personalized Then
		If Not DeliveryParameters.UseEmail Then
			LogRecord(LogParameters, EventLogLevel.Error,
				NStr("en = 'Individual reports can be distributed via email only.';"));
			Return False;
		EndIf;
		
		DeliveryParameters.UseFolder = False;
		DeliveryParameters.UseNetworkDirectory = False;
		DeliveryParameters.UseFTPResource = False;
		DeliveryParameters.NotifyOnly = False;
	EndIf;
	
	If DeliveryParameters.UseEmail Then
		If DeliveryParameters.NotifyOnly
			And Not DeliveryParameters.UseFolder
			And Not DeliveryParameters.UseNetworkDirectory
			And Not DeliveryParameters.UseFTPResource Then
			LogRecord(LogParameters, EventLogLevel.Warning,
				NStr("en = 'Email notifications are available only with other delivery methods.';"));
			Return False;
		EndIf;
		
		EmailParameters = DeliveryParameters.EmailParameters;
		
		// Internet mail text type.
		If Not ValueIsFilled(EmailParameters.TextType) Then
			EmailParameters.TextType = InternetMailTextType.PlainText;
		EndIf;
		
		DeliveryParameters.HTMLFormatEmail = EmailParameters.TextType = "HTML"
			Or EmailParameters.TextType = InternetMailTextType.HTML;
		
		// For backward compatibility purposes.
		If EmailParameters.Attachments.Count() > 0 Then
			DeliveryParameters.Images = EmailParameters.Attachments;
		EndIf;
		
		// Message template.
		If Not ValueIsFilled(DeliveryParameters.TextTemplate1) Then
			DeliveryParameters.TextTemplate1 = TextTemplate1();
			If DeliveryParameters.HTMLFormatEmail Then
				Document = New FormattedDocument;
				Document.Add(DeliveryParameters.TextTemplate1, FormattedDocumentItemType.Text);
				Document.GetHTML(DeliveryParameters.TextTemplate1, New Structure);
			EndIf;
		EndIf;
		
		// Delete unnecessary style elements.
		If DeliveryParameters.HTMLFormatEmail Then
			StyleLeft = StrFind(DeliveryParameters.TextTemplate1, "<style");
			StyleRight = StrFind(DeliveryParameters.TextTemplate1, "</style>");
			If StyleLeft > 0 And StyleRight > StyleLeft Then
				DeliveryParameters.TextTemplate1 = Left(DeliveryParameters.TextTemplate1, StyleLeft - 1) + Mid(DeliveryParameters.TextTemplate1, StyleRight + 8);
			EndIf;
		EndIf;
		
		// Value content for the substitution.
		TemplateFillingStructure = New Structure("MailingDescription, Author, SystemTitle, ExecutionDate");
		TemplateFillingStructure.MailingDescription = DeliveryParameters.BulkEmail;
		TemplateFillingStructure.Author                = DeliveryParameters.Author;
		TemplateFillingStructure.SystemTitle     = ThisInfobaseName();
		TemplateFillingStructure.ExecutionDate       = DeliveryParameters.ExecutionDate;
		If Not DeliveryParameters.Personalized Then
			TemplateFillingStructure.Insert("Recipient", "");
		EndIf;
		
		// 
		DeliveryParameters.SubjectTemplate = ReportMailingClientServer.FillTemplate(
			DeliveryParameters.SubjectTemplate, 
			TemplateFillingStructure);
		
		// 
		DeliveryParameters.TextTemplate1 = ReportMailingClientServer.FillTemplate(
			DeliveryParameters.TextTemplate1,
			TemplateFillingStructure);
		
		// 
		DeliveryParameters.FillRecipientInSubjectTemplate =
			StrFind(DeliveryParameters.SubjectTemplate, "[Recipient]") <> 0;
		DeliveryParameters.FillRecipientInMessageTemplate =
			StrFind(DeliveryParameters.TextTemplate1, "[Recipient]") <> 0;
		DeliveryParameters.FillGeneratedReportsInMessageTemplate =
			StrFind(DeliveryParameters.TextTemplate1, "[GeneratedReports]") <> 0;
		DeliveryParameters.FillDeliveryMethodInMessageTemplate =
			StrFind(DeliveryParameters.TextTemplate1, "[DeliveryMethod]") <> 0;
	EndIf;
	
	// Archive name (delete forbidden characters, fill a template) and extension.
	If DeliveryParameters.Archive Then
		Structure = New Structure("MailingDescription, ExecutionDate", DeliveryParameters.BulkEmail, CurrentSessionDate());
		ArchiveName = ReportMailingClientServer.FillTemplate(DeliveryParameters.ArchiveName, Structure);
		DeliveryParameters.ArchiveName = ConvertFileName(ArchiveName, DeliveryParameters.TransliterateFileNames);
		If Lower(Right(DeliveryParameters.ArchiveName, 4)) <> ".zip" Then
			DeliveryParameters.ArchiveName = DeliveryParameters.ArchiveName +".zip";
		EndIf;
	EndIf;
	
	// Formats parameters.
	For Each MetadataFormat In Metadata.Enums.ReportSaveFormats.EnumValues Do
		Format = Enums.ReportSaveFormats[MetadataFormat.Name];
		FormatParameters = WriteSpreadsheetDocumentToFormatParameters(Format);
		FormatParameters.Insert("Name", MetadataFormat.Name);
		DeliveryParameters.FormatsParameters.Insert(Format, FormatParameters);
	EndDo;
	
	// Parameters for adding links to the final files to the message.
	If DeliveryParameters.UseEmail 
		And (DeliveryParameters.UseFolder
			Or DeliveryParameters.UseNetworkDirectory
			Or DeliveryParameters.UseFTPResource)
		And DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		
		If DeliveryParameters.Archive Then
			DeliveryParameters.AddReferences = "ToArchive";
		ElsIf DeliveryParameters.HTMLFormatEmail Then
			DeliveryParameters.AddReferences = "ToFormats";
		Else
			DeliveryParameters.AddReferences = "AfterReports";
		EndIf;
	EndIf;
	
	Return True;
EndFunction

// Generates the mailing list from the recipients list, prepares all email parameters 
//   and passes control to the EmailOperations subsystem.
//   To monitor the fulfillment, it is recommended to call in construction the Attempt… Exception.
//
// Parameters:
//   Attachments - Map of KeyAndValue:
//     * Key     - String - file name
//     * Value - String -
//   DeliveryParameters - See ExecuteBulkEmail.DeliveryParameters
//   LogParameters  - See LogParameters
//   RecipientRow  - 
//       
//       
//
Procedure SendReportsToRecipient(Attachments, DeliveryParameters, LogParameters, RecipientRow = Undefined)
	Recipient = ?(RecipientRow = Undefined, Undefined, RecipientRow.Key);
	EmailParameters = DeliveryParameters.EmailParameters;
	
	DeliveryParameters.Recipient = Recipient;
	
	// Вложения - Reports
	EmailParameters.Attachments = ConvertToMap(Attachments, "Key", "Value");
	
	// Subject and body templates
	SubjectTemplate = DeliveryParameters.SubjectTemplate;
	TextTemplate1 = DeliveryParameters.TextTemplate1;
	
	// Insert generated reports into the message template.
	If DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		If DeliveryParameters.HTMLFormatEmail Then
			DeliveryParameters.RecipientReportsPresentation = StrReplace(
				DeliveryParameters.RecipientReportsPresentation,
				Chars.LF,
				Chars.LF + "<br>");
		EndIf;
		TextTemplate1 = StrReplace(TextTemplate1, "[GeneratedReports]", DeliveryParameters.RecipientReportsPresentation);
	EndIf;
	
	// Delivery method is filled earlier (outside this procedure).
	If DeliveryParameters.FillDeliveryMethodInMessageTemplate Then
		TextTemplate1 = StrReplace(TextTemplate1, "[DeliveryMethod]", ReportMailingClientServer.DeliveryMethodsPresentation(DeliveryParameters));
	EndIf;
	
	// 
	EmailParameters.Subject = SubjectTemplate;
	EmailParameters.Body = TextTemplate1;
	
	// Subject and body of the message
	DeliveryAddressKey = ?(DeliveryParameters.BCCs, "BCCs", "Whom");
	
	If DeliveryParameters.Personal Then
		BulkEmailType = "Personal";
	ElsIf DeliveryParameters.Personalized Then
		BulkEmailType = "Personalized";
	Else
		BulkEmailType = "Shared3";
	EndIf;
	AdditionalTextParameters = New Structure;
	ReportMailingOverridable.OnDefineEmailTextParameters(BulkEmailType,
		DeliveryParameters.MailingRecipientType, AdditionalTextParameters);
	ReportMailingOverridable.OnReceiveEmailTextParameters(BulkEmailType,
		DeliveryParameters.MailingRecipientType, Recipient, AdditionalTextParameters);
	For Each KeyAndValue In AdditionalTextParameters Do
		Parameter = "[" + KeyAndValue.Key + "]";
		EmailParameters.Subject = StrReplace(EmailParameters.Subject, Parameter, String(KeyAndValue.Value));
		EmailParameters.Body = StrReplace(EmailParameters.Body, Parameter, String(KeyAndValue.Value));
	EndDo;
	
	// 
	If DeliveryParameters.ShouldInsertReportsIntoEmailBody Then
		TextOfAllReports = "";
		MapKey = ?(Recipient = Undefined, "Key", Recipient);
		ReportsForText = DeliveryParameters.ReportsForEmailText.Get(MapKey);
		If ReportsForText <> Undefined And ReportsForText.Count() > 0 Then
			For Each Report In ReportsForText Do
				Text = New TextDocument;
				Text.Read(Report.FullFileName);
				ReportText = Text.GetText();
				If DeliveryParameters.HTMLFormatEmail Then
					TextOfAllReports = TextOfAllReports + Chars.LF + "<br>" + "<br>" + ReportText;
				Else
					TextOfAllReports = TextOfAllReports + Chars.LF + Chars.LF + Chars.LF
						+ "------------------------------------------" + Chars.LF + ReportText;
				EndIf;
			EndDo;
			EmailParameters.Body = EmailParameters.Body + Chars.LF + TextOfAllReports;
		EndIf;
	EndIf;
	
	If Recipient = Undefined Then
		If DeliveryParameters.Recipients.Count() = 0 Then
			Return;
		EndIf;
		
		// Templates are not personalized - glue recipients email addresses and joint delivery.
		Whom = "";
		For Each KeyAndValue In DeliveryParameters.Recipients Do
			Whom = Whom + ?(Whom = "", "", ", ") + KeyAndValue.Value;
		EndDo;

		EmailParameters.Insert(DeliveryAddressKey, Whom);
			
		// Send email.
		SendEmailMessage(DeliveryParameters, EmailParameters, RecipientRow, LogParameters);
	Else
		// Deliver to a specific recipient.
		
		// Subject and body of the message
		If DeliveryParameters.FillRecipientInSubjectTemplate Then
			EmailParameters.Subject = StrReplace(EmailParameters.Subject, "[Recipient]", String(Recipient));
		EndIf;
		If DeliveryParameters.FillRecipientInMessageTemplate Then
			EmailParameters.Body = StrReplace(EmailParameters.Body, "[Recipient]", String(Recipient));
		EndIf;
		
		// Получатель
		EmailParameters.Insert(DeliveryAddressKey, DeliveryParameters.Recipients[Recipient]);
		
		// Send email.
		SendEmailMessage(DeliveryParameters, EmailParameters, RecipientRow, LogParameters);
	EndIf;  
			
EndProcedure

Procedure SendEmailMessage(DeliveryParameters, EmailParameters, RecipientRow, LogParameters)
	
	If Not TypeOf(EmailParameters.Importance) = Type("InternetMailMessageImportance") Then
		EmailParameters.Importance = InternetMailMessageImportance.Normal	
	EndIf;	
	
	If EmailClientUsed() And GetFunctionalOption("RetainReportDistributionHistory") Then
		SendEmailMessageInteraction(DeliveryParameters, EmailParameters, RecipientRow, LogParameters);
	Else
		MailMessage = PrepareEmail(DeliveryParameters, EmailParameters);
		SendingResult = EmailOperations.SendMail(DeliveryParameters.Account, MailMessage);   
		
		If GetFunctionalOption("RetainReportDistributionHistory")
		   And TypeOf(LogParameters.Data) = Type("CatalogRef.ReportMailings") Then
			SenderSRepresentation = String(DeliveryParameters.Account);
			
			If DeliveryParameters.Recipient <> Undefined Then
				
				For Each Whom In EmailParameters.Whom Do
					RecipientPresentation1 = String(DeliveryParameters.Recipient) + " (" + Whom.Address + ")";
					
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, DeliveryParameters.Recipient, DeliveryParameters.ExecutionDate);  
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.EMAddress = Whom.Address;
					RecipientErrorText = SendingResult.WrongRecipients.Get(Whom.Address); 
					If RecipientErrorText <> Undefined Then
						HistoryFields.Comment = RecipientErrorText;
						HistoryFields.Executed = False;
					Else
						HistoryFields.Comment = TestOfSuccessfulReportDistribution(DeliveryParameters, RecipientRow, RecipientPresentation1, SenderSRepresentation);
						HistoryFields.Executed = True;
					EndIf;
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, DeliveryParameters.Recipient,
					Whom.Address);
					HistoryFields.EmailID = SendingResult.SMTPEmailID;	

					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			ElsIf DeliveryParameters.Recipients <> Undefined Then
				For Each Recipient In DeliveryParameters.Recipients Do
					If DeliveryParameters.NotifyOnly Then
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Notifications are sent from %2 to ''%1'' . %3';"), RecipientPresentation1,
						SenderSRepresentation);
					Else
						MessageText = TestOfSuccessfulReportDistribution(DeliveryParameters, RecipientRow, RecipientPresentation1, SenderSRepresentation);
					EndIf;
					RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(Recipient.Value);
					For Each Whom In RecipientAddresses Do
						RecipientPresentation1 = String(Recipient.Key) + " (" + Whom.Address + ")";
						HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient.Key, DeliveryParameters.ExecutionDate);
						HistoryFields.Account = DeliveryParameters.Account;    
						HistoryFields.EMAddress = Whom.Address;
						RecipientErrorText = SendingResult.WrongRecipients.Get(Whom.Address); 
						If RecipientErrorText <> Undefined Then
							HistoryFields.Comment = RecipientErrorText;
							HistoryFields.Executed = False;
						Else
							HistoryFields.Comment = MessageText;
							HistoryFields.Executed = True;
						EndIf;
						HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient.Key, Whom.Address);
						HistoryFields.EmailID = SendingResult.SMTPEmailID;
						InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
					EndDo;
				EndDo;
			EndIf;
		EndIf;
		
	EndIf;

EndProcedure
	
Procedure SendEmailMessageInteraction(DeliveryParameters, EmailParameters, RecipientRow, LogParameters)

	ModuleInteractions = Common.CommonModule("Interactions");

	Message = MessageParametersForInteractionSystem(DeliveryParameters, EmailParameters);

	SendingResult = ModuleInteractions.CreateEmail(Message, DeliveryParameters.Account, True);
	
	If TypeOf(LogParameters.Data) <> Type("CatalogRef.ReportMailings")Then
		Return;
	EndIf;
	
	If SendingResult.Sent Then

		If ValueIsFilled(DeliveryParameters.Account) Then
			SenderSRepresentation = String(DeliveryParameters.Account);
			SendHiddenCopiesToSender = Common.ObjectAttributeValue(
			DeliveryParameters.Account, "SendBCCToThisAddress");
		Else
			SenderSRepresentation = "";
			SendHiddenCopiesToSender = False;
		EndIf;

		AdditionalInfo = "";
		If SendHiddenCopiesToSender Then
			AdditionalInfo = NStr("en = 'A copy was sent to the sender.';");
		EndIf;

		If DeliveryParameters.Recipient <> Undefined Then
			If DeliveryParameters.BCCs Then
				RecipientAddresses = ?(TypeOf(EmailParameters.BCCs) = Type("String"),
					CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.BCCs), EmailParameters.BCCs);
			Else
				RecipientAddresses = ?(TypeOf(EmailParameters.Whom) = Type("String"),
					CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Whom), EmailParameters.Whom);
			EndIf;
			For Each Whom In RecipientAddresses Do
				RecipientPresentation1 = String(DeliveryParameters.Recipient) + " (" + Whom.Address + ")";
				
				HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, DeliveryParameters.Recipient, DeliveryParameters.ExecutionDate); 
				HistoryFields.Account = DeliveryParameters.Account;    
				HistoryFields.EMAddress = Whom.Address;
				RecipientErrorText = SendingResult.WrongRecipients.Get(Whom.Address); 
				If RecipientErrorText <> Undefined Then
					HistoryFields.Comment = RecipientErrorText;
					HistoryFields.Executed = False;
				Else
					HistoryFields.Comment = TestOfSuccessfulReportDistribution(DeliveryParameters, RecipientRow, RecipientPresentation1, SenderSRepresentation, AdditionalInfo);
					HistoryFields.Executed = True;
				EndIf;
				HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, DeliveryParameters.Recipient, Whom.Address);   
				HistoryFields.OutgoingEmail = SendingResult.LinkToTheEmail;
				HistoryFields.EmailID = SendingResult.EmailID;	
				
				InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
			EndDo;
		ElsIf DeliveryParameters.Recipients <> Undefined Then
			For Each Recipient In DeliveryParameters.Recipients Do
				RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(Recipient.Value);
				For Each Whom In RecipientAddresses Do
					
					RecipientPresentation1 = String(Recipient.Key) + " (" + Whom.Address + ")";
					If DeliveryParameters.NotifyOnly Then
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Notifications are sent from %2 to ''%1'' . %3';"), RecipientPresentation1,
						SenderSRepresentation, AdditionalInfo);
					Else
						MessageText = TestOfSuccessfulReportDistribution(DeliveryParameters, RecipientRow, RecipientPresentation1, SenderSRepresentation, AdditionalInfo);
					EndIf;
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient.Key, DeliveryParameters.ExecutionDate); 
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.EMAddress = Whom.Address;
					RecipientErrorText = SendingResult.WrongRecipients.Get(Whom.Address);
					If RecipientErrorText <> Undefined Then
						HistoryFields.Comment = RecipientErrorText;
						HistoryFields.Executed = False;
					Else
						HistoryFields.Comment = MessageText;
						HistoryFields.Executed = True;
					EndIf;
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient.Key, Whom.Address);
					HistoryFields.OutgoingEmail = SendingResult.LinkToTheEmail;
					HistoryFields.EmailID = SendingResult.EmailID;
					
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;
			EndDo;
		EndIf;

	Else
		If DeliveryParameters.Recipient <> Undefined Then		
			RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Whom);
			For Each Whom In RecipientAddresses Do
				
				HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, DeliveryParameters.Recipient, DeliveryParameters.ExecutionDate);
				HistoryFields.Account = DeliveryParameters.Account;
				HistoryFields.EMAddress = Whom.Address;
				HistoryFields.Comment = SendingResult.ErrorDescription;
				HistoryFields.Executed = False;
				HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, DeliveryParameters.Recipient, Whom.Address);
				HistoryFields.OutgoingEmail = SendingResult.LinkToTheEmail;
				HistoryFields.EmailID = SendingResult.EmailID;		
				
				InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
			EndDo;	
		Else
			For Each Recipient In DeliveryParameters.Recipients Do	
				RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(Recipient.Value);
				For Each Whom In RecipientAddresses Do
					
					HistoryFields = ReportDistributionHistoryFields(LogParameters.Data, Recipient.Key, DeliveryParameters.ExecutionDate); 
					HistoryFields.Account = DeliveryParameters.Account;
					HistoryFields.EMAddress = Whom.Address;
					HistoryFields.Comment = SendingResult.ErrorDescription;
					HistoryFields.Executed = False;
					HistoryFields.MethodOfObtaining = DistributionReceiptMethod(DeliveryParameters, Recipient.Key, Whom.Address);
					HistoryFields.OutgoingEmail = SendingResult.LinkToTheEmail;
					HistoryFields.EmailID = SendingResult.EmailID;	
					
					InformationRegisters.ReportsDistributionHistory.CommitResultOfDistributionToRecipient(HistoryFields);
				EndDo;		
			EndDo;
		EndIf;

		Raise (SendingResult.ErrorDescription);

	EndIf;

EndProcedure

Function MessageParametersForInteractionSystem(DeliveryParameters, EmailParameters)

	ModuleInteractions = Common.CommonModule("Interactions");
	Message = ModuleInteractions.EmailParameters();
	Message.Subject  = EmailParameters.Subject;
	Message.Text = EmailParameters.Body;
	Message.Importance = EmailParameters.Importance;
	Message.AdditionalParameters.RequestDeliveryReceipt = EmailParameters.RequestDeliveryReceipt;  
	Message.AdditionalParameters.RequestReadReceipt = EmailParameters.RequestReadReceipt;

	If EmailParameters.TextType = "PlainText" Or EmailParameters.TextType = InternetMailTextType.PlainText Then
		Message.AdditionalParameters.EmailFormat1 = Enums.EmailEditingMethods.NormalText;
	Else
		Message.AdditionalParameters.EmailFormat1 = Enums.EmailEditingMethods.HTML;
	EndIf;
	
	If ValueIsFilled(DeliveryParameters.Recipient) Then
		RecipientPresentation1 = String(DeliveryParameters.Recipient);
		If DeliveryParameters.BCCs Then
			RecipientAddresses = ?(TypeOf(EmailParameters.BCCs) = Type("String"),
				CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.BCCs), EmailParameters.BCCs);
			RecipientsTableName = "BccRecipients";
		Else
			RecipientAddresses = ?(TypeOf(EmailParameters.Whom) = Type("String"),
				CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Whom), EmailParameters.Whom);
			RecipientsTableName = "Recipients";
		EndIf;
		
		For Each Whom In RecipientAddresses Do
			NewRow = Message[RecipientsTableName].Add();
			NewRow.Address         = Whom.Address;
			NewRow.Presentation = RecipientPresentation1 + " (" + Whom.Address + ")";
			NewRow.ContactInformationSource = DeliveryParameters.Recipient;
		EndDo;
		
	Else 
		If DeliveryParameters.BCCs Then
			RecipientsTableName = "BccRecipients";
		Else
			RecipientsTableName = "Recipients";
		EndIf;

		For Each Recipient In DeliveryParameters.Recipients Do
			RecipientPresentation1 = String(Recipient.Key);
			RecipientAddresses = CommonClientServer.ParseStringWithEmailAddresses(Recipient.Value);
			For Each Whom In RecipientAddresses Do
				NewRow = Message[RecipientsTableName].Add();
				NewRow.Address         = Whom.Address;
				NewRow.Presentation = RecipientPresentation1 + " (" + Whom.Address + ")";
				NewRow.ContactInformationSource = Recipient.Key;
			EndDo;
		EndDo;
	EndIf;
	
	If ValueIsFilled(EmailParameters.ReplyToAddress) Then
		NewRow = Message.ReplyRecipients.Add();
		NewRow.Address         = EmailParameters.ReplyToAddress;
		NewRow.Presentation = EmailParameters.ReplyToAddress;
	EndIf;
		
	For Each Picture In DeliveryParameters.Images Do
		StringAttachment = Message.Attachments.Add();
		PicFile = Picture.Value.GetBinaryData();
		StringAttachment.AddressInTempStorage = PutToTempStorage(PicFile);
		StringAttachment.Presentation = Picture.Key;
		StringAttachment.Id = Picture.Key;
	EndDo;

	For Each Attachment In EmailParameters.Attachments Do
		StringAttachment = Message.Attachments.Add();
		FileAttachment = New BinaryData(Attachment.Value);
		StringAttachment.AddressInTempStorage = PutToTempStorage(FileAttachment);
		StringAttachment.Presentation = Attachment.Key;
	EndDo;
	
	Return Message;
	
EndFunction
	
Function EmailClientUsed()
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		Return ModuleInteractions.EmailClientUsed();
	EndIf;
	
	Return False;
	
EndFunction
	
Function PrepareEmail(DeliveryParameters, EmailParameters)
	
	If DeliveryParameters.Images.Count() > 0 Then
		FormattedDocument = New FormattedDocument;
		FormattedDocument.SetHTML(EmailParameters.Body, DeliveryParameters.Images);
		EmailParameters.Body = FormattedDocument;
	EndIf;
	
	Return EmailOperations.PrepareEmail(DeliveryParameters.Account, EmailParameters);
	
EndFunction

// Converts the collection to mapping.
Function ConvertToMap(Collection, KeyName, EnumValueName)
	If TypeOf(Collection) = Type("Map") Then
		Return New Map(New FixedMap(Collection));
	EndIf;
	Result = New Map;
	For Each Item In Collection Do
		Result.Insert(Item[KeyName], Item[EnumValueName]);
	EndDo;
	Return Result;
EndFunction

// Combines arrays and returns the result of the union.
Function CombineArrays(Array1, Array2)
	Array = New Array;
	For Each ArrayElement In Array1 Do
		Array.Add(ArrayElement);
	EndDo;
	For Each ArrayElement In Array2 Do
		Array.Add(ArrayElement);
	EndDo;
	Return Array;
EndFunction

// Executes archiving of attachments in accordance with the delivery parameters.
//
// Parameters:
//   Attachments - Map
//            - ValueTreeRow - 
//   DeliveryParameters - See ExecuteBulkEmail.DeliveryParameters
//   TempFilesDir - String - a directory for archiving.
//
Procedure ArchiveAttachments(Attachments, DeliveryParameters, TempFilesDir)
	If Not DeliveryParameters.Archive Then
		Return;
	EndIf;
	
	If DeliveryParameters.ShouldSetPasswordsAndEncrypt And ValueIsFilled(DeliveryParameters.CertificateToEncrypt) Then
		ArchiveNameTooltip = NStr("en = '(Decrypt)';");
		If Lower(Right(DeliveryParameters.ArchiveName, 4)) <> ".zip" Then
			DeliveryParameters.ArchiveName = DeliveryParameters.ArchiveName + " " + ArchiveNameTooltip +".zip";
		Else
			CountOfCharacters = StrLen(DeliveryParameters.ArchiveName) - 4;
			DeliveryParameters.ArchiveName = Left(DeliveryParameters.ArchiveName, CountOfCharacters) + " " + ArchiveNameTooltip +".zip";
		EndIf;
	EndIf;
	
	// Directory and file are archived and the file name is changed to the archive name.
	FullFileName = TempFilesDir + DeliveryParameters.ArchiveName;
	
	SaveMode = ZIPStorePathMode.StoreRelativePath;
	ProcessingMode  = ZIPSubDirProcessingMode.ProcessRecursively;
	
	ZipFileWriter = New ZipFileWriter(FullFileName, DeliveryParameters.ArchivePassword);
	
	For Each Attachment In Attachments Do
		ZipFileWriter.Add(Attachment.Value, SaveMode, ProcessingMode);
		If Attachment.Settings.FileWithDirectory = True Then
			ZipFileWriter.Add(Attachment.Settings.FullDirectoryName, SaveMode, ProcessingMode);
		EndIf;
	EndDo;
	
	ZipFileWriter.Write();
	
	If DeliveryParameters.ShouldSetPasswordsAndEncrypt And ValueIsFilled(DeliveryParameters.CertificateToEncrypt) Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		ArchiveBinaryData = ModuleDigitalSignature.Encrypt(New BinaryData(FullFileName),
			DeliveryParameters.CertificateToEncrypt);
		ArchiveBinaryData.Write(FullFileName);
	EndIf;
	
	Attachments = New Map;
	Attachments.Insert(DeliveryParameters.ArchiveName, FullFileName);
		
	If DeliveryParameters.UseEmail Then
		If DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
			DeliveryParameters.RecipientReportsPresentation = 
				DeliveryParameters.RecipientReportsPresentation 
				+ Chars.LF 
				+ Chars.LF
				+ NStr("en = 'Report files are archived';")
				+ " ";
		EndIf;
		
		If DeliveryParameters.AddReferences = "ToArchive" Then
			// Delivery method involves links adding.
			If DeliveryParameters.HTMLFormatEmail Then
				DeliveryParameters.RecipientReportsPresentation = TrimAll(
					DeliveryParameters.RecipientReportsPresentation
					+"<a href = '"+ FullFileName +"'>"+ DeliveryParameters.ArchiveName +"</a>");
			Else
				DeliveryParameters.RecipientReportsPresentation = TrimAll(
					DeliveryParameters.RecipientReportsPresentation
					+""""+ DeliveryParameters.ArchiveName +""":"+ Chars.LF +"<"+ FullFileName +">");
			EndIf;
		ElsIf DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
			// 
			DeliveryParameters.RecipientReportsPresentation = TrimAll(
				DeliveryParameters.RecipientReportsPresentation
				+""""+ DeliveryParameters.ArchiveName +"""");
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters for saving a spreadsheet document in format.
//
// Parameters:
//   Format - EnumRef.ReportSaveFormats - a format for which you need to get the parameters.
//
// Returns:
//   Structure - 
//       * Extension - String - extension with which you can save the file.
//       * FileType - SpreadsheetDocumentFileType - a spreadsheet document save format.
//           This procedure is used to define the <SpreadsheetFileType> parameter of the SpreadsheetDocument.Write method.
//
Function WriteSpreadsheetDocumentToFormatParameters(Format) Export
	Result = New Structure("Extension, FileType");
	If Format = Enums.ReportSaveFormats.XLSX Then
		Result.Extension = ".xlsx";
		Result.FileType = SpreadsheetDocumentFileType.XLSX;
		
	ElsIf Format = Enums.ReportSaveFormats.XLS Then
		Result.Extension = ".xls";
		Result.FileType = SpreadsheetDocumentFileType.XLS;
		
	ElsIf Format = Enums.ReportSaveFormats.ODS Then
		Result.Extension = ".ods";
		Result.FileType = SpreadsheetDocumentFileType.ODS;
		
	ElsIf Format = Enums.ReportSaveFormats.MXL Then
		Result.Extension = ".mxl";
		Result.FileType = SpreadsheetDocumentFileType.MXL;
		
	ElsIf Format = Enums.ReportSaveFormats.PDF Then
		Result.Extension = ".pdf";
		Result.FileType = StandardSubsystemsServer.TableDocumentFileTypePDF();
		
	ElsIf Format = Enums.ReportSaveFormats.HTML Then
		Result.Extension = ".html";
		Result.FileType = SpreadsheetDocumentFileType.HTML5;
		
	ElsIf Format = Enums.ReportSaveFormats.HTML4 Then
		Result.Extension = ".html";
		Result.FileType = SpreadsheetDocumentFileType.HTML4;
		
	ElsIf Format = Enums.ReportSaveFormats.DOCX Then
		Result.Extension = ".docx";
		Result.FileType = SpreadsheetDocumentFileType.DOCX;
		
	ElsIf Format = Enums.ReportSaveFormats.TXT Then
		Result.Extension = ".txt";
		Result.FileType = SpreadsheetDocumentFileType.TXT;
	
	ElsIf Format = Enums.ReportSaveFormats.ANSITXT Then
		Result.Extension = ".txt";
		Result.FileType = SpreadsheetDocumentFileType.ANSITXT;
		
	Else 
		// 
		// 
		Result.Extension = Undefined;
		Result.FileType = Undefined;
		
	EndIf;
	
	Return Result;
EndFunction

Function FullFileNameFromTemplate(Directory, ReportDescription1, Format, DeliveryParameters, DescriptionTemplate1, Period) Export
	
	FileNameParameters = New Structure("ReportDescription1, ReportFormat, MailingDate, FileExtention");
	FileNameParameters.ReportDescription1 = ReportDescription1;
	FileNameParameters.ReportFormat = Format.Name;
	FileNameParameters.FileExtention = ?(Format.Extension = Undefined, "", Format.Extension);
	
	If ValueIsFilled(DescriptionTemplate1) Then
		FileNameTemplate = DescriptionTemplate1 + "[FileExtention]";
		FileNameParameters.MailingDate = CurrentSessionDate();
		If Period <> Undefined Then
			FileNameParameters.Insert("Period", Period);
		EndIf;
		FileName = ReportMailingClientServer.FillTemplate(FileNameTemplate, FileNameParameters);
	Else
		FileNameTemplate = "[ReportDescription1] ([ReportFormat])[FileExtention]"; // 
		FileName = StringFunctionsClientServer.InsertParametersIntoString(FileNameTemplate, FileNameParameters);
	EndIf;
	
	Return Directory + ConvertFileName(FileName, DeliveryParameters.TransliterateFileNames);
	
EndFunction

// Converts invalid file characters to similar valid characters.
//   Operates only with the file name, the path is not supported.
//
// Parameters:
//   InitialFileName - String - a file name from which you have to remove invalid characters.
//
// Returns:
//   String - 
//
Function ConvertFileName(InitialFileName, TransliterateFileNames)
	
	Result = Left(TrimAll(InitialFileName), 255);
	
	ReplacementsMap = New Map;
	
	// 
	ReplacementsMap.Insert("""", "'");
	ReplacementsMap.Insert("/", "_");
	ReplacementsMap.Insert("\", "_");
	ReplacementsMap.Insert(":", "_");
	ReplacementsMap.Insert(";", "_");
	ReplacementsMap.Insert("|", "_");
	ReplacementsMap.Insert("=", "_");
	ReplacementsMap.Insert("?", "_");
	ReplacementsMap.Insert("*", "_");
	ReplacementsMap.Insert("<", "_");
	ReplacementsMap.Insert(">", "_");
	
	// 
	ReplacementsMap.Insert("[", "");
	ReplacementsMap.Insert("]", "");
	ReplacementsMap.Insert(",", "");
	ReplacementsMap.Insert("{", "");
	ReplacementsMap.Insert("}", "");
	
	For Each KeyAndValue In ReplacementsMap Do
		Result = StrReplace(Result, KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If TransliterateFileNames Then
		Result = StringFunctions.LatinString(Result);
	EndIf;
	
	Return Result;
EndFunction

// Value tree required for generating and delivering reports.
Function CreateReportsTree()
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
	
	ReportsTree = New ValueTree;
	ReportsTree.Columns.Add("Level", New TypeDescription("Number"));
	ReportsTree.Columns.Add("Key");
	ReportsTree.Columns.Add("Value");
	ReportsTree.Columns.Add("Settings", New TypeDescription("Structure"));
	
	Return ReportsTree;
EndFunction

// Checks the current users right to output information. If there are no rights - an event log record is created.
//
// Parameters:
//   LogParameters - Structure
// 
// Returns:
//   Boolean
//
Function OutputRight(LogParameters)
	OutputRight = AccessRight("Output", Metadata);
	If Not OutputRight Then
		LogRecord(LogParameters, EventLogLevel.Error,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 has insufficient rights to export data';"),
			Users.CurrentUser()));
	EndIf;
	Return OutputRight;
EndFunction

// Converts an array of messages to a user in one string.
Function MessagesToUserString(Errors = Undefined, SeeEventLog = True) Export
	If Errors = Undefined Then
		Errors = GetUserMessages(True);
	EndIf;
	
	Indent = Chars.LF + Chars.LF;
	
	AllErrors = "";
	For Each Error In Errors Do
		AllErrors = TrimAll(AllErrors + Indent + ?(TypeOf(Error) = Type("String"), Error, Error.Text));
	EndDo;
	If AllErrors <> "" And SeeEventLog Then
		AllErrors = AllErrors + Indent + "---" + Indent + NStr("en = 'See the Event Log for details.';");
	EndIf;
	
	Return AllErrors;
EndFunction

// If the file exists - adds a suffix to the file name.
//
// Parameters:
//   FullFileName - String - a file name to start a search.
//
Procedure FindFreeFileName(FullFileName)
	File = New File(FullFileName);
	
	If Not File.Exists() Then
		Return;
	EndIf;
	
	// Set a file names template to substitute various suffixes.
	NameTemplate = "";
	NameLength = StrLen(FullFileName);
	SlashCode = CharCode("/");
	BackSlashCode = CharCode("\");
	PointCode = CharCode(".");
	For ReverseIndex = 1 To NameLength Do
		IndexOf = NameLength - ReverseIndex + 1;
		Code = CharCode(FullFileName, IndexOf);
		If Code = PointCode Then
			NameTemplate = Left(FullFileName, IndexOf - 1) + "<template>" + Mid(FullFileName, IndexOf);
			Break;
		ElsIf Code = SlashCode Or Code = BackSlashCode Then
			Break;
		EndIf;
	EndDo;
	If NameTemplate = "" Then
		NameTemplate = FullFileName + "<template>";
	EndIf;
	
	IndexOf = 0;
	While File.Exists() Do
		IndexOf = IndexOf + 1;
		FullFileName = StrReplace(NameTemplate, "<template>", " ("+ Format(IndexOf, "NG=") +")");
		File = New File(FullFileName);
	EndDo;
EndProcedure

// Creates the tree root row for the recipient (if it is absent) and fills it with default parameters.
//
// Parameters:
//   ReportsTree     - See CreateReportsTree
//   RecipientRef  - CatalogRef
//                     - Undefined - the link to the recipient.
//   DeliveryParameters - See ExecuteBulkEmail.DeliveryParameters
//
// Returns: 
//   ValueTreeRow - See CreateReportsTree
//
Function DefineTreeRowForRecipient(ReportsTree, RecipientRef, DeliveryParameters)
	
	RecipientRow = ReportsTree.Rows.Find(RecipientRef, "Key", False);
	If RecipientRow = Undefined Then
		
		RecipientsDirectory = DeliveryParameters.TempFilesDir;
		If RecipientRef <> Undefined Then
			RecipientsDirectory = RecipientsDirectory 
				+ ConvertFileName(String(RecipientRef), DeliveryParameters.TransliterateFileNames)
				+ " (" + String(RecipientRef.UUID()) + ")\";
			CreateDirectory(RecipientsDirectory);
		EndIf;
		
		RecipientRow = ReportsTree.Rows.Add();
		RecipientRow.Level  = 1;
		RecipientRow.Key     = RecipientRef;
		RecipientRow.Value = RecipientsDirectory;
		
	EndIf;
	
	Return RecipientRow;
	
EndFunction

// Generates reports presentation for recipients.
Procedure GenerateReportPresentationsForRecipient(DeliveryParameters, RecipientRow)
	
	GeneratedReports = "";
	
	If DeliveryParameters.UseEmail And DeliveryParameters.FillGeneratedReportsInMessageTemplate Then
		
		Separator = Chars.LF;
		If DeliveryParameters.AddReferences = "AfterReports" Then
			Separator = Separator + Chars.LF;
		EndIf;
		
		IndexOf = 0;
		
		For Each RowReport In DeliveryParameters.GeneralReportsRow.Rows Do
			IndexOf = IndexOf + 1;
			GeneratedReports = GeneratedReports 
			+ Separator 
			+ Format(IndexOf, "NG=") 
			+ ". " 
			+ RowReport.Settings.PresentationInEmail;
		EndDo;
		
		If RecipientRow <> Undefined And RecipientRow <> DeliveryParameters.GeneralReportsRow Then
			For Each RowReport In RecipientRow.Rows Do
				IndexOf = IndexOf + 1;
				GeneratedReports = GeneratedReports 
				+ Separator 
				+ Format(IndexOf, "NG=") 
				+ ". " 
				+ RowReport.Settings.PresentationInEmail;
			EndDo;
		EndIf;
		
	EndIf;
	
	DeliveryParameters.RecipientReportsPresentation = TrimAll(GeneratedReports);
	
EndProcedure

// 
Function TestOfSuccessfulReportDistribution(DeliveryParameters, RecipientRow, RecipientPresentation1, SenderSRepresentation, AdditionalInfo = "")

	GeneratedReports = New Array;

	If DeliveryParameters.UseEmail And DeliveryParameters.FillGeneratedReportsInMessageTemplate Then

		For Each RowReport In DeliveryParameters.GeneralReportsRow.Rows Do
			GeneratedReports.Add(RowReport.Settings.PresentationInEmail);
		EndDo;

		If RecipientRow <> Undefined And RecipientRow <> DeliveryParameters.GeneralReportsRow Then
			For Each RowReport In RecipientRow.Rows Do
				GeneratedReports.Add(RowReport.Settings.PresentationInEmail);
			EndDo;
		EndIf;
		
	EndIf;

	If GeneratedReports.Count() = 1 Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '- ""%1"" is sent from %2. %3';"), GeneratedReports[0],
			SenderSRepresentation, AdditionalInfo);	
	Else

		ReportsAsString = "";

		For Each RowReport In GeneratedReports Do
			ReportsAsString = ReportsAsString 
			+ ?(ValueIsFilled(ReportsAsString), Chars.LF, "")
			+ "- """ 
			+ RowReport 
			+ """";
		EndDo;
				
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 are sent from %2. %3';"), ReportsAsString, SenderSRepresentation,
				AdditionalInfo);

	EndIf;

	If DeliveryParameters.Archive Then
		PackedToArchive = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Packed in the ""%1"" archive';"), DeliveryParameters.ArchiveName);
		MessageText = MessageText + Chars.LF + PackedToArchive;	
	EndIf;

	Return MessageText;
	
EndFunction

// Checks if there are external data sets.
//
// Parameters:
//   DataSets - DataCompositionTemplateDataSets - a collection of data sets to be checked.
//
// Returns: 
//   Boolean - 
//
Function ThereIsExternalDataSet(DataSets)
	
	For Each DataSet In DataSets Do
		
		If TypeOf(DataSet) = Type("DataCompositionTemplateDataSetObject") Then
			
			Return True;
			
		ElsIf TypeOf(DataSet) = Type("DataCompositionTemplateDataSetUnion") Then
			
			If ThereIsExternalDataSet(DataSet.Items) Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function MailingsWithReportsNumber(ReportVariant)
	
	If Not ValueIsFilled(ReportVariant) Or TypeOf(ReportVariant) <> Type("CatalogRef.ReportsOptions") 
		Or ReportVariant.IsEmpty() Then
		Return 0;
	EndIf;
	
	Query = New Query(
		"SELECT ALLOWED
		|	COUNT(DISTINCT Reports.Ref) AS Count
		|FROM
		|	Catalog.ReportMailings.Reports AS Reports
		|WHERE
		|	Reports.Report = &ReportVariant");
		
	Query.SetParameter("ReportVariant", ReportVariant);
	Return Query.Execute().Unload()[0].Count;
	
EndFunction	

// Checks rights and generates error text.
Function CheckAddRightErrorText() Export
	If Not AccessRight("Output", Metadata) Then
		Return NStr("en = 'You have insufficient rights to export data.';");
	EndIf;
	If Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Return NStr("en = 'You have insufficient rights to distribute reports.';");
	EndIf;
	If Not EmailOperations.CanSendEmails() Then
		Return NStr("en = 'You have insufficient rights to send emails or no email accounts.';");
	EndIf;
	Return "";
EndFunction

// Returns a value list of the ReportSaveFormats enumeration.
//
// Returns: 
//   ValueList - 
//     * Value      - EnumRef.ReportSaveFormats - a reference to the described format.
//     * Presentation - String - user presentation of the described format.
//     * Check       - Boolean - a flag of usage as a default format.
//     * Picture      - Picture - a picture of the format.
//
Function FormatsList() Export
	FormatsList = New ValueList;
	
	SetFormatsParameters(FormatsList, "HTML", PictureLib.HTMLFormat, True);
	SetFormatsParameters(FormatsList, "PDF"  , PictureLib.PDFFormat);
	SetFormatsParameters(FormatsList, "XLSX" , PictureLib.ExcelFormat2007);
	SetFormatsParameters(FormatsList, "XLS"  , PictureLib.ExcelFormat);
	SetFormatsParameters(FormatsList, "ODS"  , PictureLib.OpenOfficeCalcFormat);
	SetFormatsParameters(FormatsList, "MXL"  , PictureLib.MXLFormat);
	SetFormatsParameters(FormatsList, "DOCX" , PictureLib.WordFormat2007);
	SetFormatsParameters(FormatsList, "TXT"    , PictureLib.TXTFormat);
	SetFormatsParameters(FormatsList, "ANSITXT", PictureLib.TXTFormat);
	
	ReportMailingOverridable.OverrideFormatsParameters(FormatsList);
	
	// Remaining formats.
	For Each FormatRef In Enums.ReportSaveFormats Do
		If FormatRef = Enums.ReportSaveFormats.HTML4 Then // 
			Continue;
		EndIf;
		SetFormatsParameters(FormatsList, FormatRef);
	EndDo;
	
	Return FormatsList;
EndFunction

// Gets an empty value for the search in the Reports or ReportFormats table of the ReportMailings catalog.
//
// Returns:
//   - CatalogRef.AdditionalReportsAndDataProcessors
//   - CatalogRef.ReportsOptions
//
Function EmptyReportValue() Export
	SetPrivilegedMode(True);
	Return Metadata.Catalogs.ReportMailings.TabularSections.ReportFormats.Attributes.Report.Type.AdjustValue();
EndFunction

// Gets an application title. If it is not specified, gets a configuration metadata synonym.
Function ThisInfobaseName() Export
	
	SetPrivilegedMode(True);
	Result = Constants.SystemTitle.Get();
	Return ?(IsBlankString(Result), Metadata.Synonym, Result);
	
EndFunction

Procedure DisableBulkEmailBeforeDeleteBulkEmailRecipientsType(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ReportMailings.Ref AS Ref
		|FROM
		|	Catalog.ReportMailings AS ReportMailings
		|WHERE
		|	ReportMailings.MailingRecipientType = &MailingRecipientType";
	
	Query.SetParameter("MailingRecipientType", Source.Ref);
	Records = Query.Execute().Select();
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		LockItem = Block.Add(Metadata.Catalogs.ReportMailings.FullName());
		LockItem.SetValue("MailingRecipientType", Source.Ref);
		Block.Lock();
		
		While Records.Next() Do
			BulkEmailObject = Records.Ref.GetObject();
			
			If BulkEmailObject = Undefined Then
				Continue;
			EndIf;
			
			BulkEmailObject.MailingRecipientType = Catalogs.MetadataObjectIDs.EmptyRef();
			BulkEmailObject.IsPrepared = False;
			InfobaseUpdate.WriteData(BulkEmailObject);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Function FormatPresentation(Format) Export
	
	If Format = Enums.ReportSaveFormats.PDF Then
		Return StandardSubsystemsServer.FileTypeRepresentationOfATabularPDFDocument();
	EndIf;
	
	Return String(Format);
	
EndFunction

//  
//
// Parameters:
//   
//       
//         
//         
//         									
//   ResultAddress - String - the address in temporary storage where the result will be placed.
//
Procedure SendBulkSMSMessagesWithReportDistributionArchivePasswordsInBackgroundJob(Parameters, ResultAddress) Export
	
	ModuleSMS = Common.CommonModule("SendSMSMessage");
	DistributionErrorsMessages = New Array;
	SentCount = 0;
	ResultByRecipients = New Array;
	For Each PrepareSMS In Parameters.PreparedSMSMessages Do
		SendingResult = ModuleSMS.SendSMS(PrepareSMS.PhoneNumbers, PrepareSMS.SMSMessageText);
		RecipientResult = New Structure("Recipient, NotSent, Comment");
		RecipientResult.Recipient = PrepareSMS.Recipient;
		If ValueIsFilled(SendingResult.ErrorDescription) Then
			DistributionErrorsMessages.Add(SendingResult.ErrorDescription);
			RecipientResult.Comment = SendingResult.ErrorDescription;
			RecipientResult.NotSent = True;
		Else	
			SentCount = SentCount + 1;
			RecipientResult.Comment = NStr("en = 'The text message is sent.';");
		EndIf;
		ResultByRecipients.Add(RecipientResult);
	EndDo;
	
	UnsentCount = Parameters.UnsentCount + DistributionErrorsMessages.Count();
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Text messages with archive passwords are sent. Sent: %1. Not sent: %2.';"), SentCount,
		UnsentCount);
	
	Result = New Structure;
	Result.Insert("Text", MessageText);
	Result.Insert("More", MessagesToUserString(DistributionErrorsMessages));
	Result.Insert("ResultByRecipients", ResultByRecipients);
	Result.Insert("SentCount", SentCount);
	Result.Insert("UnsentCount", UnsentCount);
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Function ReportDistributionHistoryFields(ReportMailing, Recipient, StartDistribution)

	HistoryFields = New Structure;
	HistoryFields.Insert("ReportMailing", ReportMailing);  
	HistoryFields.Insert("Recipient", Recipient);
	HistoryFields.Insert("StartDistribution", StartDistribution); 
	HistoryFields.Insert("Period", CurrentSessionDate()); 
	HistoryFields.Insert("Account", ""); 
	HistoryFields.Insert("EMAddress", ""); 
	HistoryFields.Insert("Comment", "");
	HistoryFields.Insert("Executed", False);
	HistoryFields.Insert("OutgoingEmail", "");
	HistoryFields.Insert("MethodOfObtaining", "");
	HistoryFields.Insert("EmailID", "");   
	HistoryFields.Insert("DeliveryDate", '00010101');  
	HistoryFields.Insert("Status", Enums.EmailMessagesStatuses.EmptyRef());   
	HistoryFields.Insert("SessionNumber", InfoBaseSessionNumber());

	Return HistoryFields;

EndFunction

// 
//
// Parameters:
//   DeliveryParameters - See ReportMailing.DeliveryParameters.
//   Recipient - DefinedType.BulkEmailRecipient
//   MailAddr - String
// 
//
// Returns: 
//   String
// 
Function DistributionReceiptMethod(DeliveryParameters, Recipient, MailAddr = "")

	MethodOfObtaining = "";

	If DeliveryParameters.UseNetworkDirectory Then
		ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryWindows;
		SystemData = New SystemInfo;
		ServerPlatformType = SystemData.PlatformType;

		If ServerPlatformType = PlatformType.Linux_x86 Or ServerPlatformType = PlatformType.Linux_x86_64 Then
			ServerNetworkDdirectory = DeliveryParameters.NetworkDirectoryLinux;
		EndIf;

		MethodOfObtaining = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Publish to the network directory: ""%1"".';"), ServerNetworkDdirectory);
	EndIf;

	If DeliveryParameters.UseFTPResource Then
		FTPResource = "ftp://" + DeliveryParameters.Server + ":" + Format(DeliveryParameters.Port, "NZ=0; NG=0")
			+ DeliveryParameters.Directory;
		MethodOfObtaining = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Publish to the FTP resource: ""%1"".';"), FTPResource);
	EndIf;

	If DeliveryParameters.UseFolder Then
		MethodOfObtaining = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Publish to the folder: ""%1"".';"), String(DeliveryParameters.Folder));
	EndIf;

	If DeliveryParameters.UseEmail Then
		If Not ValueIsFilled(MailAddr) Then
			If DeliveryParameters.Recipients <> Undefined Then
				Address = DeliveryParameters.Recipients.Get(Recipient);
				MailAddr = ?(Address <> Undefined, Address, NStr("en = 'An email address is not specified.';"));
			Else
				MailAddr = NStr("en = 'An email address is not specified.';");	
			EndIf;
		EndIf;
		If DeliveryParameters.NotifyOnly Then
			Text = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Send a notification by email: ""%1"".';"), MailAddr);
			MethodOfObtaining = ?(ValueIsFilled(MethodOfObtaining), MethodOfObtaining + " " + Text, Text);
		Else
			Text = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Send by email: ""%1"".';"), MailAddr);
			MethodOfObtaining = ?(ValueIsFilled(MethodOfObtaining), MethodOfObtaining + " " + Text, Text);
		EndIf;

	EndIf;

	Return MethodOfObtaining;

EndFunction

// For official use only.
Procedure ClearUpObsoleteRecordsOfReportDistributionHistory() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ReportDistributionHistoryClearUp);
	
	ResultOfClearUpObsoleteRecordsOfReportDistributionHistory();
	
EndProcedure   

Function ResultOfClearUpObsoleteRecordsOfReportDistributionHistory()
	
	DeletionResult = New Structure("DeletedCount", 0);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	ReportsDistributionHistory.ReportMailing AS ReportMailing,
		|	ReportsDistributionHistory.Recipient AS Recipient,
		|	ReportsDistributionHistory.StartDistribution AS StartDistribution
		|FROM
		|	InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
		|WHERE
		|	ReportsDistributionHistory.StartDistribution < &HistoryRetentionStartDate";
	
	NumberOfMonths = Constants.ReportDistributionHistoryRetentionPeriodInMonths.Get();   
	HistoryRetentionStartDate = ?(GetFunctionalOption("RetainReportDistributionHistory"),
		CurrentSessionDate() - NumberOfMonths * 2592000, CurrentSessionDate());

	Query.SetParameter("HistoryRetentionStartDate", HistoryRetentionStartDate);

	BeginTransaction();
	Try

	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.ReportsDistributionHistory");
	DataLockItem.Mode = DataLockMode.Shared;
	DataLock.Lock();

	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		RecordSet = InformationRegisters.ReportsDistributionHistory.CreateRecordSet();
		RecordSet.Filter.ReportMailing.Set(Selection.ReportMailing);
		RecordSet.Filter.Recipient.Set(Selection.Recipient);
		RecordSet.Filter.StartDistribution.Set(Selection.StartDistribution);
		RecordSet.Write();
		DeletionResult.DeletedCount = DeletionResult.DeletedCount + 1;
	EndDo;
	
	CommitTransaction();
	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	SetPrivilegedMode(False);
	
	Return DeletionResult;
	
EndFunction

Procedure ClearUpReportDistributionHistoryInBackgroundJob(Parameters, ResultAddress) Export
	
	DeletionResult = ResultOfClearUpObsoleteRecordsOfReportDistributionHistory();
	
	MessageText = StringFunctionsClientServer.StringWithNumberForAnyLanguage(NStr(
		"en = ';%1 report distribution history record is cleared;;;;
		|%1 report distribution history records are cleared';"),
		DeletionResult.DeletedCount);
	
	Result = New Structure;
	Result.Insert("Text", MessageText);
	PutToTempStorage(Result, ResultAddress);
		
EndProcedure   	

// 
//
Procedure SetReportDistributionHistoryRetentionPeriodInMonths() Export
	
	Constants.ReportDistributionHistoryRetentionPeriodInMonths.Set(3);
	
EndProcedure

Function CanEncryptAttachments() Export

	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return False;
	Else
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		Return ModuleDigitalSignature.UseEncryption();
	EndIf;

EndFunction

// Returns the default body template for delivery by email.
Function TextTemplate1() Export
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr(
		"en = 'Reports are generated:
		|
		|%1';"),
		"[GeneratedReports]
		|
		|[DeliveryMethod]
		|
		|[SystemTitle]
		|[ExecutionDate(DLF='DD')]");
EndFunction

Function GetPeriodFromUserSettings(DCUserSettings) Export
	If DCUserSettings = Undefined Then
		Return Undefined;
	EndIf;

	SoughtForParameterPeriod = New DataCompositionParameter("Period");
	SoughtForParameterReportPeriod = New DataCompositionParameter("ReportPeriod");
	For Each Item In DCUserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionSettingsParameterValue") 
			And (Item.Parameter = SoughtForParameterPeriod Or Item.Parameter = SoughtForParameterReportPeriod) Then
			Return Item.Value;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure AddCommandsAddTextAdditionalParameters(Form) Export

	If Form.EmailTextAdditionalParameters = Undefined Then
		Form.EmailTextAdditionalParameters = New Structure;
	Else
		For Each Parameter In Form.EmailTextAdditionalParameters Do
			Form.Commands.Delete(Form.Commands[Parameter.Value.CommandName]);
			Form.Items.Delete(Form.Items[Parameter.Value.TextButtonName]);
			Form.Items.Delete(Form.Items[Parameter.Value.HTMLButtonName]);
			Form.Items.Delete(Form.Items[Parameter.Value.SubjectButtonName]);
		EndDo;
		Form.EmailTextAdditionalParameters = New Structure;
	EndIf;

	EmailTextAdditionalParameters = New Structure;

	MailingRecipientType = ?(Form.BulkEmailType = "Personal", Undefined, Form.MailingRecipientType);
	ReportMailingOverridable.OnDefineEmailTextParameters(Form.BulkEmailType,
		MailingRecipientType, EmailTextAdditionalParameters);

	If EmailTextAdditionalParameters.Count() = 0 Then
		Return;
	EndIf;

	For Each TextParameter In EmailTextAdditionalParameters Do

		CommandName        = "AddLayout" + StrReplace(Title(TextParameter.Key), Chars.NBSp, "");
		Command           = Form.Commands.Add(CommandName);
		Command.Title = TextParameter.Value;
		Command.ToolTip = TextParameter.Value;
		Command.Action  = "Attachable_AddEmailTextAdditionalParameter";
		
		GroupParameters = Form.Items.EmailTextAddTemplateParameter;
		ButtonNameText = "AddLayout" + CommandName;
		Button = Form.Items.Add(ButtonNameText, Type("FormButton"), GroupParameters);
		Button.Title  = TextParameter.Value;
		Button.CommandName = CommandName;
		Form.Items.MoveTo(Button, GroupParameters, Form.Items.AddDefaultTemplate);
		
		GroupParameters = Form.Items.EmailTextFormattedDocumentAddTemplateParameters;
		HTMLButtonName = "EmailTextFormattedDocumentAddTemplate" + CommandName;
		Button = Form.Items.Add(HTMLButtonName, Type("FormButton"), GroupParameters);
		Button.Title  = TextParameter.Value;
		Button.CommandName = CommandName;
		
		Form.Items.MoveTo(Button, GroupParameters, Form.Items.EmailTextFormattedDocumentAddDefaultTemplate);

		GroupParameters = Form.Items.EmailSubjectContextMenuSubmenuParameter;
		ButtonNameContextMenuSubject = "EmailSubjectContextMenuAddTemplate" + CommandName;
		Button = Form.Items.Add(ButtonNameContextMenuSubject, Type("FormButton"), GroupParameters);
		Button.Title  = TextParameter.Value;
		Button.CommandName = CommandName;
		Form.Items.MoveTo(Button, GroupParameters, Form.Items.EmailSubjectContextMenuAddDefaultTemplate);
		
		ParameterDetails = New Structure();
		ParameterDetails.Insert("Name", TextParameter.Key);
		ParameterDetails.Insert("Presentation", TextParameter.Value);
		ParameterDetails.Insert("CommandName", CommandName);
		ParameterDetails.Insert("TextButtonName", ButtonNameText);
		ParameterDetails.Insert("HTMLButtonName", HTMLButtonName);
		ParameterDetails.Insert("SubjectButtonName", ButtonNameContextMenuSubject);
		
		Form.EmailTextAdditionalParameters.Insert(CommandName, ParameterDetails);
	EndDo;

EndProcedure

Function ReportDistributionProgressText(DeliveryParameters, SentCount, QuantityToSend)
	
	If DeliveryParameters.UseNetworkDirectory Then
		Text = NStr("en = 'Distributing the reports.
			|Reports placed to the network directory: %1 out of %2.
			|Please wait…';");
	ElsIf DeliveryParameters.UseFTPResource Then
		Text = NStr("en = 'Distributing the reports.
			|Reports published on FTP: %1 out of %2.
			|Please wait...';");
	Else 
		Text = NStr("en = 'Distributing the reports.
			|Sent %1 out of %2.
			|Please wait...';");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(Text,
		Format(SentCount, "NZ=0; NG="),
		Format(QuantityToSend, "NZ=0; NG=")); 
	
EndFunction

Function IsMemberOfPersonalReportGroup(Group) Export
	
	PersonalMailingsGroup = Catalogs.ReportMailings.PersonalMailings;
	
	If Not ValueIsFilled(Group) Then
		Return False;
	ElsIf Group = PersonalMailingsGroup Then	
		Return True;
	EndIf;
	
	Return Group.BelongsToItem(PersonalMailingsGroup);
	
EndFunction

Function GetReportDistributionState(BulkEmail) Export
	
	MailoutStatus = New Structure;
	MailoutStatus.Insert("BulkEmail", Catalogs.ReportMailings.EmptyRef());
	MailoutStatus.Insert("LastRunStart", Date(1, 1, 1));
	MailoutStatus.Insert("LastRunCompletion", Date(1, 1, 1));
	MailoutStatus.Insert("SuccessfulStart", Date(1, 1, 1));
	MailoutStatus.Insert("Executed", False);
	MailoutStatus.Insert("WithErrors", False);
	MailoutStatus.Insert("SessionNumber", 0);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ReportMailingStates.BulkEmail AS BulkEmail,
		|	ReportMailingStates.LastRunStart AS LastRunStart,
		|	ReportMailingStates.LastRunCompletion AS LastRunCompletion,
		|	ReportMailingStates.SuccessfulStart AS SuccessfulStart,
		|	ReportMailingStates.Executed AS Executed,
		|	ReportMailingStates.WithErrors AS WithErrors,
		|	ReportMailingStates.SessionNumber AS SessionNumber
		|INTO TT_MailoutStatus
		|FROM
		|	InformationRegister.ReportMailingStates AS ReportMailingStates
		|WHERE
		|	ReportMailingStates.BulkEmail = &ReportMailing
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReportsDistributionHistory.Recipient AS Recipient,
		|	ReportsDistributionHistory.EMAddress AS EMAddress,
		|	MAX(ReportsDistributionHistory.Executed) AS Executed,
		|	TT_MailoutStatus.BulkEmail AS BulkEmail
		|INTO TT_Recipients
		|FROM
		|	TT_MailoutStatus AS TT_MailoutStatus
		|		INNER JOIN InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
		|		ON TT_MailoutStatus.BulkEmail = ReportsDistributionHistory.ReportMailing
		|			AND TT_MailoutStatus.LastRunStart = ReportsDistributionHistory.StartDistribution
		|			AND TT_MailoutStatus.SessionNumber = ReportsDistributionHistory.SessionNumber
		|WHERE
		|	ReportsDistributionHistory.ReportMailing = &ReportMailing
		|	AND ReportsDistributionHistory.EMAddress <> """"
		|
		|GROUP BY
		|	ReportsDistributionHistory.Recipient,
		|	ReportsDistributionHistory.EMAddress,
		|	TT_MailoutStatus.BulkEmail
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Recipients.BulkEmail AS BulkEmail,
		|	COUNT(DISTINCT TT_Recipients.EMAddress) AS Count
		|INTO TT_Undelivered
		|FROM
		|	TT_Recipients AS TT_Recipients
		|WHERE
		|	NOT TT_Recipients.Executed
		|
		|GROUP BY
		|	TT_Recipients.BulkEmail
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_MailoutStatus.BulkEmail AS BulkEmail,
		|	TT_MailoutStatus.LastRunStart AS LastRunStart,
		|	TT_MailoutStatus.LastRunCompletion AS LastRunCompletion,
		|	TT_MailoutStatus.SuccessfulStart AS SuccessfulStart,
		|	TT_MailoutStatus.Executed AS Executed,
		|	TT_MailoutStatus.SessionNumber AS SessionNumber,
		|	CASE
		|		WHEN ISNULL(TT_Undelivered.Count, 0) = 0
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS WithErrors
		|FROM
		|	TT_MailoutStatus AS TT_MailoutStatus
		|		LEFT JOIN TT_Undelivered AS TT_Undelivered
		|		ON TT_MailoutStatus.BulkEmail = TT_Undelivered.BulkEmail";
	
	Query.SetParameter("ReportMailing", BulkEmail);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(MailoutStatus, Selection);
	EndIf;
	
	Return MailoutStatus;
	
EndFunction

Procedure ResendByEmail(ReportsTable, DeliveryParameters, BulkEmail, LogParameters)
	
	If Not DeliveryParameters.UseEmail Or DeliveryParameters.Personal Or DeliveryParameters.NotifyOnly Then
		Return;
	EndIf;
	
	RecordManager = InformationRegisters.ReportMailingStates.CreateRecordManager();
	RecordManager.BulkEmail = BulkEmail;
	RecordManager.Read();
	
	If RecordManager.SessionNumber <> InfoBaseSessionNumber() Then
		Return;
	EndIf;
	
	RedistributionRecipients = ReportRedistributionRecipients(BulkEmail,
		RecordManager.LastRunStart, RecordManager.SessionNumber);
	
	If RedistributionRecipients.Count() = 0 Then
		Return;
	EndIf;
	
	DeliveryParameters.Recipients = RedistributionRecipients;
	DeliveryParameters.UseFolder = False;
	DeliveryParameters.UseNetworkDirectory = False;
	DeliveryParameters.UseFTPResource = False;
	DeliveryParameters.RecipientReportsPresentation = "";
	DeliveryParameters.Recipient = Undefined;
	DeliveryParameters.Images = New Structure;
	DeliveryParameters.EmailParameters.Attachments = New Map;

	LogRecord(LogParameters,
		EventLogLevel.Note,
		NStr("en = 'Resend the reports by email.';"));

	ExecuteBulkEmail(ReportsTable, DeliveryParameters, BulkEmail, LogParameters);
	
EndProcedure

#Region MultiThreadedReportGeneration

Function GenerateReportsInMultipleThreads(Var_Reports, DeliveryParameters, MailingDescription, LogParameters)
	
	PersonalizedReports   = New Map;
	NotPersonalizedReports = New Array;
	
	// 
	ReportsNumber = 1;
	For Each RowReport In Var_Reports Do
		
		LogText = NStr("en = 'Generating report: %1';");
		If RowReport.Settings = Undefined Then
			LogText = LogText + Chars.LF + NStr("en = '(user settings are not set)';");
		EndIf;
		
		ReportPresentation = String(RowReport.Report);
		
		LogRecord(LogParameters,
			EventLogLevel.Note,
			StringFunctionsClientServer.SubstituteParametersToString(LogText, ReportPresentation));
		
		// 
		ReportParameters = New Structure("Report, Settings, Formats, SendIfEmpty, DescriptionTemplate1");
		FillPropertyValues(ReportParameters, RowReport);
		If Not InitializeReport(LogParameters, ReportParameters, DeliveryParameters.Personalized) Then
			Continue;
		EndIf;
		
		If DeliveryParameters.Personalized And Not ReportParameters.IsPersonalized Then
			ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot generate report ""%1"". Recipient is required.';"),
				ReportPresentation);
			
			LogRecord(LogParameters, EventLogLevel.Error, ReportParameters.Errors);
			Continue;
		EndIf;
		
		If ReportParameters.IsPersonalized Then
			For Each KeyAndValue In DeliveryParameters.Recipients Do
				ReportParametersStructure = New Structure("Report, Settings, Formats, SendIfEmpty, DescriptionTemplate1");
				FillPropertyValues(ReportParametersStructure, RowReport);
				
				If PersonalizedReports.Get(KeyAndValue.Key) = Undefined Then
					PersonalizedReports.Insert(KeyAndValue.Key, New Array);
				EndIf;
				PersonalizedReports[KeyAndValue.Key].Add(ReportParametersStructure);
			EndDo;
			
		Else
			ReportParametersStructure = New Structure("Report, Settings, Formats, SendIfEmpty, DescriptionTemplate1");
			FillPropertyValues(ReportParametersStructure, RowReport);
			
			NotPersonalizedReports.Add(ReportParametersStructure);
		EndIf;
		
	EndDo;
	
	MethodParameters = New Map;
	
	// 
	For Each KeyAndValue In PersonalizedReports Do
		ParametersArray = New Array;
		ParametersArray.Add(KeyAndValue.Value);
		ParametersArray.Add(LogParameters);
		ParametersArray.Add(DeliveryParameters);
		ParametersArray.Add(KeyAndValue.Key);
		
		MethodParameters.Insert(KeyAndValue.Key, ParametersArray);
	EndDo; 
	
	If (LogParameters <> Undefined) And LogParameters.Property("Metadata") Then
		LogParameters.Metadata = LogParameters.Metadata.FullName();
	EndIf;
	
	// 
	ReportsNumber  = 0;
	PortionNumber  = 1;
	PortionSize = 2;
	Batch = New Array;
	ReportCount = NotPersonalizedReports.Count();
	For Each Report In NotPersonalizedReports Do
		Batch.Add(Report);
		ReportsNumber = ReportsNumber + 1;
		
		If ReportsNumber % PortionSize = 0 Or ReportCount = ReportsNumber Then
			ParametersArray = New Array;
			ParametersArray.Add(Batch);
			ParametersArray.Add(LogParameters);
			ParametersArray.Add(DeliveryParameters);

			MethodParameters.Insert(PortionNumber, ParametersArray);

			Batch = New Array;
			PortionNumber = PortionNumber + 1;
		EndIf;
	EndDo;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID());
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Report distribution';");
	ExecutionParameters.WaitCompletion = Undefined;
	
	ResultAddress = PutToTempStorage(Undefined, New UUID());
	ExecutionParameters.Insert("ResultAddress", ResultAddress);
	
	ExecutionResult = TimeConsumingOperations.ExecuteFunctionInMultipleThreads(
		"ReportMailing.ReportsBatchGenerationResult",
		ExecutionParameters,
		MethodParameters);
	
	ReportsTree = CreateReportsTree();

	// 
	DeliveryParameters.GeneralReportsRow = DefineTreeRowForRecipient(ReportsTree, Undefined, DeliveryParameters);
	
	AddressesOfChecksResults = GetFromTempStorage(ExecutionResult.ResultAddress);
	
	If AddressesOfChecksResults = Undefined Then
		Return ReportsTree;
	EndIf;
	
	For Each AddressValidationResult In AddressesOfChecksResults Do
		
		ResultsFromThread = GetFromTempStorage(AddressValidationResult.Value.ResultAddress);
		If TypeOf(ResultsFromThread) = Type("Structure")Then
			If ResultsFromThread.Property("ReportsTree") And TypeOf(ResultsFromThread.ReportsTree) = Type("ValueTree") Then
				AddGeneratedReportsToTree(ReportsTree, ResultsFromThread.ReportsTree);
			EndIf;
			If ResultsFromThread.Property("ReportsForEmailText") And TypeOf(ResultsFromThread.ReportsForEmailText) = Type("Map") Then
				MergeReportsForEmailTextFromMultipleThreads(DeliveryParameters, ResultsFromThread.ReportsForEmailText);
			EndIf;
		EndIf;
				
	EndDo;
	
	Return ReportsTree;
	
EndFunction

// 
//
// Parameters: See ExecuteBulkEmail
//
// Returns:
//   Structure:
//     * ReportsTree - See CreateReportsTree
//     * ReportsForEmailText - Array of Map
//
// 
//
Function ReportsBatchGenerationResult(Var_Reports, LogParameters, DeliveryParameters, Recipient = Undefined) Export
	
	LogParameters.Metadata = Common.MetadataObjectByFullName(LogParameters.Metadata);
	
	// 
	ReportsTree = CreateReportsTree();
	
	For Each RowReport In Var_Reports Do
		ReportPresentation = String(RowReport.Report);
		
		// 
		ReportParameters = New Structure("Report, Settings, Formats, SendIfEmpty, DescriptionTemplate1");
		FillPropertyValues(ReportParameters, RowReport);
		If Not InitializeReport(LogParameters, ReportParameters, DeliveryParameters.Personalized) Then
			Continue;
		EndIf;
		
		If DeliveryParameters.Personalized And Not ReportParameters.IsPersonalized Then
			ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot generate report ""%1"". Recipient is required.';"),
				ReportPresentation);
			
			LogRecord(LogParameters, EventLogLevel.Error, ReportParameters.Errors);
			Return Undefined;
		EndIf;
		
		// 
		Try
			If ReportParameters.IsPersonalized Then
				// 
				GenerateAndSaveReport(
					LogParameters,
					ReportParameters,
					ReportsTree,
					DeliveryParameters,
					Recipient);
			Else
				// 
				GenerateAndSaveReport(
					LogParameters,
					ReportParameters,
					ReportsTree,
					DeliveryParameters,
					Undefined);
			EndIf;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Report ""%1"" is generated successfully';"), ReportPresentation);
			
			LogRecord(LogParameters, EventLogLevel.Note, MessageText);
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Report ""%1"" was not generated:';"), ReportPresentation);
			
			LogRecord(LogParameters, , MessageText, ErrorProcessing.DetailErrorDescription(
				ErrorInfo()));
		EndTry;
	EndDo;

	Result = New Structure;
	Result.Insert("ReportsTree", ReportsTree);
	Result.Insert("ReportsForEmailText", DeliveryParameters.ReportsForEmailText);
	
	Return Result;
	
EndFunction
// 

Procedure AddGeneratedReportsToTree(TreeResult, GeneratedReportsTree)
	
	For Each GeneratedReportsTreeRow In GeneratedReportsTree.Rows Do
		
		TreeRowResult = Undefined;
		
		For Each TreeRow In TreeResult.Rows Do
			If TreeRow.Value = GeneratedReportsTreeRow.Value Then
				TreeRowResult = TreeRow;
				Break;
			EndIf;
		EndDo;

		If TreeRowResult = Undefined Then
			TreeRowResult = TreeResult.Rows.Add();
			FillPropertyValues(TreeRowResult, GeneratedReportsTreeRow);
		EndIf;
		
		If GeneratedReportsTreeRow.Rows.Count() > 0 Then
			AddGeneratedReportsToTree(TreeRowResult, GeneratedReportsTreeRow);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure MergeReportsForEmailTextFromMultipleThreads(DeliveryParameters, ReportsForEmailText)
	
	For Each ReportsByUsers In ReportsForEmailText Do
		ReportsForText = DeliveryParameters.ReportsForEmailText.Get(ReportsByUsers.Key);
		
		If ReportsForText = Undefined Then
			DeliveryParameters.ReportsForEmailText.Insert(ReportsByUsers.Key, ReportsByUsers.Value);
		Else  
			For Each FileStructure In ReportsByUsers.Value Do
				ReportsForText.Add(FileStructure);
			EndDo;
		EndIf; 
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
