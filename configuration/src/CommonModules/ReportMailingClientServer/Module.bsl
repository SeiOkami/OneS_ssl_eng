///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// 
//
// Parameters:
//   Template - String - an initial template. For example, "Welcome, [ФИО]".
//   Parameters - Structure:
//      * Key - String -
//      * Value - Arbitrary -
//
// Returns: 
//   String
//
Function FillTemplate(Template, Parameters) Export
	ParameterStart = "["; 
	ParameterEnd = "]";
	StartOfFormat = "("; 
	EndOfFormat = ")"; 
	CutBorders = True; // 
	
	Result = Template;
	For Each KeyAndValue In Parameters Do
		// 
		Result = StrReplace(
			Result,
			ParameterStart + KeyAndValue.Key + ParameterEnd, 
			?(CutBorders, "", ParameterStart) + KeyAndValue.Value + ?(CutBorders, "", ParameterEnd));
		LengthLeftFormat = StrLen(ParameterStart + KeyAndValue.Key + StartOfFormat);
		// Replace [key(format)] to value in the format.
		Position1 = StrFind(Result, ParameterStart + KeyAndValue.Key + StartOfFormat);
		While Position1 > 0 Do
			Position2 = StrFind(Result, EndOfFormat + ParameterEnd);
			If Position2 = 0 Then
				Break;
			EndIf;
			FormatString = Mid(Result, Position1 + LengthLeftFormat, Position2 - Position1 - LengthLeftFormat);
			Try
				If TypeOf(KeyAndValue.Value) = Type("StandardPeriod") Then
					ValueWithFormat = NStr("en = '%StartDate% - %EndDate%';");
					ValueWithFormat = StrReplace(ValueWithFormat, "%StartDate%", Format(
						KeyAndValue.Value.StartDate, FormatString));
					ValueWithFormat = StrReplace(ValueWithFormat, "%EndDate%", Format(
						KeyAndValue.Value.EndDate, FormatString));
				Else
					ValueWithFormat = Format(KeyAndValue.Value, FormatString);
				EndIf;
				ReplacedWith = ?(CutBorders, "", ParameterStart) + ValueWithFormat + ?(CutBorders, "", ParameterEnd);
			Except
				ReplacedWith = ?(CutBorders, "", ParameterStart) + KeyAndValue.Value + ?(CutBorders, "", ParameterEnd);
			EndTry;
			Result = StrReplace(
				Result,
				ParameterStart + KeyAndValue.Key + StartOfFormat + FormatString + EndOfFormat + ParameterEnd, 
				ReplacedWith);
			Position1 = StrFind(Result, ParameterStart + KeyAndValue.Key + StartOfFormat);
		EndDo;
	EndDo;
	Return Result;
EndFunction

// Generates the delivery methods presentation according to delivery parameters.
//
// Parameters:
//   DeliveryParameters - 
//
// Returns:
//   String
//
Function DeliveryMethodsPresentation(DeliveryParameters) Export
	Prefix = NStr("en = 'Result';");
	PresentationText = "";
	Suffix = "";
	
	If Not DeliveryParameters.NotifyOnly Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("en = 'and';")) 
		+ " "
		+ NStr("en = 'sent by email (see attachments)';");
		
	EndIf;
	
	If DeliveryParameters.ExecutedToFolder Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("en = 'and';")) 
		+ " "
		+ NStr("en = 'delivered to folder';")
		+ " ";
		
		Ref = GetInfoBaseURL() +"#"+ GetURL(DeliveryParameters.Folder);
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ Ref
			+ "'>" 
			+ String(DeliveryParameters.Folder)
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ """"
			+ String(DeliveryParameters.Folder)
			+ """";
			Suffix = Suffix + ":" + Chars.LF + "<" + Ref + ">";
		EndIf;
		
	EndIf;
	
	If DeliveryParameters.ExecutedToNetworkDirectory Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("en = 'and';")) 
		+ " "
		+ NStr("en = 'delivered to network directory';")
		+ " ";
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ DeliveryParameters.NetworkDirectoryWindows
			+ "'>" 
			+ DeliveryParameters.NetworkDirectoryWindows
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ "<"
			+ DeliveryParameters.NetworkDirectoryWindows
			+ ">";
		EndIf;
		
	EndIf;
	
	If DeliveryParameters.ExecutedAtFTP Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("en = 'and';")) 
		+ " "
		+ NStr("en = 'delivered to FTP resource';")
		+ " ";
		
		Ref = "ftp://"
		+ DeliveryParameters.Server 
		+ ":"
		+ Format(DeliveryParameters.Port, "NZ=0; NG=0") 
		+ DeliveryParameters.Directory;
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ Ref
			+ "'>" 
			+ Ref
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ "<"
			+ Ref
			+ ">";
		EndIf;
		
	EndIf;
	
	PresentationText = PresentationText + ?(Suffix = "", ".", Suffix);
	
	Return PresentationText;
EndFunction

Function ListPresentation(Collection, ColumnName = "", MaxChars = 60) Export
	Result = New Structure;
	Result.Insert("Total", 0);
	Result.Insert("LengthOfFull", 0);
	Result.Insert("LengthOfShort", 0);
	Result.Insert("Short", "");
	Result.Insert("Full", "");
	Result.Insert("MaximumExceeded", False);
	For Each Object In Collection Do
		ValuePresentation = String(?(ColumnName = "", Object, Object[ColumnName]));
		If IsBlankString(ValuePresentation) Then
			Continue;
		EndIf;
		If Result.Total = 0 Then
			Result.Total        = 1;
			Result.Full       = ValuePresentation;
			Result.LengthOfFull = StrLen(ValuePresentation);
		Else
			Full       = Result.Full + ", " + ValuePresentation;
			LengthOfFull = Result.LengthOfFull + 2 + StrLen(ValuePresentation);
			If Not Result.MaximumExceeded And LengthOfFull > MaxChars Then
				Result.Short          = Result.Full;
				Result.LengthOfShort    = Result.LengthOfFull;
				Result.MaximumExceeded = True;
			EndIf;
			Result.Total        = Result.Total + 1;
			Result.Full       = Full;
			Result.LengthOfFull = LengthOfFull;
		EndIf;
	EndDo;
	If Result.Total > 0 And Not Result.MaximumExceeded Then
		Result.Short       = Result.Full;
		Result.LengthOfShort = Result.LengthOfFull;
		Result.MaximumExceeded = Result.LengthOfFull > MaxChars;
	EndIf;
	Return Result;
EndFunction

// Returns the default subject template for delivery by email.
Function SubjectTemplate() Export
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 dated %2';"), "[MailingDescription]", "[ExecutionDate(DLF='D')]");
EndFunction

// Returns the default archive name template.
Function ArchivePatternName() Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[MailingDescription]", "[ExecutionDate(DF='yyyy-MM-dd')]");
	
EndFunction

// Constructor for the value of the delivery parametersthe function perform dispatch.
//
// Returns:
//   Structure - 
//     
//       * Author - CatalogRef.Users - author of the mailing list.
//       * UseFolder            - Boolean - to deliver the reports in a folder of the subsystem "Working with files".
//       * UseNetworkDirectory   - Boolean - deliver reports to a file system folder.
//       * UseFTPResource        - Boolean - to deliver reports via FTP.
//       * UseEmail - Boolean - to deliver reports via e-mail.
//
//     Properties when to use the folder = True:
//       * Folder - CatalogRef.FilesFolders - the folder of the subsystem "Working with files".
//
//     Properties when to use networkdirectory = True:
//       * NetworkDirectoryWindows - String - directory of the file system (local on the server or network).
//       * NetworkDirectoryLinux   - String - a file system directory (local on the server or network).
//
//     Properties when UseFTPResource = True:
//       * Owner            - CatalogRef.ReportMailings
//       * Server              - String - name of the FTP server.
//       * Port                - Number  - port of the FTP server.
//       * Login               - String - name of the FTP server user.
//       * Password              - String - password of the FTP server user.
//       * Directory             - String - path to the folder on the FTP server.
//       * PassiveConnection - Boolean - use a passive connection.
//
//     Properties when to use Electronic Mail = True:
//       * Account - CatalogRef.EmailAccounts - to send a mail message.
//       * Recipients - Map of KeyAndValue - set of recipients and their e-mail addresses:
//           ** Key - CatalogRef - recipient.
//           ** Value - String - email addresses of the recipient, separated by commas.
//
//     Additional properties:
//       * Archive - Boolean - archive all generated reports into one archive.
//                                 Archiving can be required, for example, when mailing schedules in html format.
//       * ArchiveName    - String - archive name.
//       * ArchivePassword - String - backup password.
//       * TransliterateFileNames - Boolean -
//       * CertificateToEncrypt - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates -
//           
//       * MailingRecipientType - TypeDescription
//                                - Undefined
//
//     
//       * Personalized - Boolean - a mailing personalized by recipients.
//           The default value is False.
//           If True value is set, each recipient will receive a report with a filter by it.
//           To do this, in reports, set the "[Получатель]" filter by the attribute that match the recipient type.
//           Applies only to delivery by mail,
//           so when setting to the True, other delivery methods are disabled.
//       * NotifyOnly - Boolean - False - send only notifications (do not attach generated reports).
//       * BCCs    - Boolean - False - if True, when sending fill BCCs instead of To.
//       * SubjectTemplate      - String -       message subject.
//       * TextTemplate1    - String -       message body.
//       * FormatsParameters - Map of KeyAndValue:
//           ** Key - EnumRef.ReportSaveFormats
//           ** Value - Structure:
//                *** Extension - String
//                *** FileType - SpreadsheetDocumentFileType
//                *** Name - String
//       * EmailParameters - See EmailSendOptions
//       * ShouldInsertReportsIntoEmailBody - Boolean
//       * ShouldAttachReports - Boolean
//       * ShouldSetPasswordsAndEncrypt - Boolean
//       * ReportsForEmailText - Array of Map
//
Function DeliveryParameters() Export
	
	DeliveryParameters = New Structure;
	DeliveryParameters.Insert("ExecutionDate", Undefined);
	DeliveryParameters.Insert("Join", Undefined);
	DeliveryParameters.Insert("StartCommitted", False);
	DeliveryParameters.Insert("Author", Undefined);
	DeliveryParameters.Insert("EmailParameters", EmailSendOptions());
	
	DeliveryParameters.Insert("RecipientsSettings", New Map);
	DeliveryParameters.Insert("Recipients", Undefined);
	DeliveryParameters.Insert("Account", Undefined);
	DeliveryParameters.Insert("BulkEmail", "");
	
	DeliveryParameters.Insert("HTMLFormatEmail", False);
	DeliveryParameters.Insert("Personalized", False);
	DeliveryParameters.Insert("TransliterateFileNames", False);
	DeliveryParameters.Insert("NotifyOnly", False);
	DeliveryParameters.Insert("BCCs", False);
	
	DeliveryParameters.Insert("UseEmail", False);
	DeliveryParameters.Insert("UseFolder", False);
	DeliveryParameters.Insert("UseNetworkDirectory", False);
	DeliveryParameters.Insert("UseFTPResource", False);
	
	DeliveryParameters.Insert("Directory", Undefined);
	DeliveryParameters.Insert("NetworkDirectoryWindows", Undefined);
	DeliveryParameters.Insert("NetworkDirectoryLinux", Undefined);
	DeliveryParameters.Insert("TempFilesDir", "");
	
	DeliveryParameters.Insert("Owner", Undefined);
	DeliveryParameters.Insert("Server", Undefined);
	DeliveryParameters.Insert("Port", Undefined);
	DeliveryParameters.Insert("PassiveConnection", False);
	DeliveryParameters.Insert("Login", Undefined);
	DeliveryParameters.Insert("Password", Undefined);
	
	DeliveryParameters.Insert("Folder", Undefined);
	DeliveryParameters.Insert("Archive", False);
	DeliveryParameters.Insert("ArchiveName", ArchivePatternName());
	DeliveryParameters.Insert("ArchivePassword", Undefined);
	DeliveryParameters.Insert("CertificateToEncrypt", Undefined);
		
	DeliveryParameters.Insert("FillRecipientInSubjectTemplate", False);
	DeliveryParameters.Insert("FillRecipientInMessageTemplate", False);
	DeliveryParameters.Insert("FillGeneratedReportsInMessageTemplate", False);
	DeliveryParameters.Insert("FillDeliveryMethodInMessageTemplate", False);
	DeliveryParameters.Insert("RecipientReportsPresentation", "");
	DeliveryParameters.Insert("SubjectTemplate", SubjectTemplate());
	DeliveryParameters.Insert("TextTemplate1", "");
	
	DeliveryParameters.Insert("FormatsParameters", New Map);
	DeliveryParameters.Insert("TransliterateFileNames", False);
	DeliveryParameters.Insert("GeneralReportsRow", Undefined);
	DeliveryParameters.Insert("AddReferences", "");
	
	DeliveryParameters.Insert("TestMode", False);
	DeliveryParameters.Insert("HadErrors", False);
	DeliveryParameters.Insert("HasWarnings", False);
	DeliveryParameters.Insert("ExecutedToFolder", False);
	DeliveryParameters.Insert("ExecutedToNetworkDirectory", False);
	DeliveryParameters.Insert("ExecutedAtFTP", False);
	DeliveryParameters.Insert("ExecutedByEmail", False);
	DeliveryParameters.Insert("ExecutedPublicationMethods", "");
	DeliveryParameters.Insert("Recipient", Undefined);
	DeliveryParameters.Insert("Images", New Structure);
	DeliveryParameters.Insert("Personal", False);
	DeliveryParameters.Insert("MailingRecipientType", Undefined);
	DeliveryParameters.Insert("ShouldInsertReportsIntoEmailBody", True);
	DeliveryParameters.Insert("ShouldAttachReports", False);
	DeliveryParameters.Insert("ShouldSetPasswordsAndEncrypt", False);
	DeliveryParameters.Insert("ReportsForEmailText", New Map);
	DeliveryParameters.Insert("ReportsTree", Undefined);
	
	Return DeliveryParameters;
	
EndFunction

// 
//
// Returns:
//   Structure - contains all the necessary information about the email:
//     * Whom - Array
//            - String - 
//            - Array - a collection of structures, addresses:
//                * Address         - String - postal address (must be filled in).
//                * Presentation - String - destination name.
//            - String - 
//
//     * MessageRecipients - Array - array of structures describing the recipients:
//       ** Address - String - email address of the message recipient.
//       ** Presentation - String - representation of the addressee.
//
//     * Cc        - Array
//                    - String - 
//
//     * BCCs - Array
//                    - String - 
//
//     * Subject       - String - (required) subject of the email message.
//     * Body       - String - (required) text of the email message (plain text in win-1251 encoding).
//
//     * Attachments - Array - files to be attached (described as structures):
//       ** Presentation - String - attachment file name;
//       ** AddressInTempStorage - String - address of the attachment's binary data in temporary storage.
//       ** Encoding - String - encoding of the attachment (used if it differs from the encoding of the message).
//       ** Id - String - (optional) used to mark images displayed in the message body.
//
//     * ReplyToAddress - String -
//     * BasisIDs - String - IDs of the bases of this message.
//     * ProcessTexts  - Boolean - the need to process the message texts when sending.
//     * RequestDeliveryReceipt  - Boolean - need to request a delivery notification.
//     * RequestReadReceipt - Boolean - need to request a read notification.
//     * TextType - String
//                 - EnumRef.EmailTextTypes
//                 - InternetMailTextType - 
//                   
//                   
//                   
//                                                 
//                   
//                                                 
//     * Importance  - InternetMailMessageImportance
//
Function EmailSendOptions() Export
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Whom", New Array);
	EmailParameters.Insert("MessageRecipients", New Array);
	EmailParameters.Insert("Cc", New Array);
	EmailParameters.Insert("BCCs", New Array);
	EmailParameters.Insert("Subject", "");
	EmailParameters.Insert("Body", "");
	EmailParameters.Insert("Attachments", New Map);
	EmailParameters.Insert("ReplyToAddress", "");
	EmailParameters.Insert("BasisIDs", "");
	EmailParameters.Insert("ProcessTexts", False);
	EmailParameters.Insert("RequestDeliveryReceipt", False);
	EmailParameters.Insert("RequestReadReceipt", False);
	EmailParameters.Insert("TextType", "PlainText");
	EmailParameters.Insert("Importance", "");
	
	Return EmailParameters;
	
EndFunction

#EndRegion