///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables
Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

// 
Var ErrorsMessages;                 // Map

Var ObjectName;                      // 

Var TempExchangeMessageFile;    // 

Var TempExchangeMessagesDirectory; // 

Var MessageSubject1;                   // 

Var SimpleBody;            // Текст тела сообщения с вложением - 

Var CompressedBody;             // Текст тела сообщения с вложением - 

Var BatchBody;           // Текст тела сообщения с вложением - 

Var EmailOperationsCommonModule;
Var DirectoryID;

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Creates a temporary directory in the temporary file directory of the operating system user.
//
// Parameters:
//  No.
// 
//  Returns:
//    Boolean - 
// 
Function ExecuteActionsBeforeProcessMessage() Export
	
	InitMessages();
	
	DirectoryID = Undefined;
	
	Return CreateTempExchangeMessagesDirectory();
	
EndFunction

// Sends the exchange message to the specified resource from the temporary exchange message directory.
//
// Parameters:
//  No.
// 
//  Returns:
//    Boolean - 
// 
Function SendMessage() Export
	
	InitMessages();
	
	Try
		Result = SendExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Gets an exchange message from the specified resource and puts it in the temporary exchange message directory.
//
// Parameters:
//  ExistenceCheck - Boolean - True if it is necessary to check whether exchange messages exist without their import.
// 
//  Returns:
//    Boolean - 
// 
Function GetMessage(ExistenceCheck = False) Export
	
	InitMessages();
	
	Try
		Result = GetExchangeMessage(ExistenceCheck);
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Deletes the temporary exchange message directory after performing data import or export.
//
// Parameters:
//  No.
// 
//  Returns:
//    Boolean - True
//
Function ExecuteActionsAfterProcessMessage() Export
	
	InitMessages();
	
	DeleteTempExchangeMessagesDirectory();
	
	Return True;
	
EndFunction

// Initializes data processor properties with initial values and constants.
//
// Parameters:
//  No.
// 
Procedure Initialization() Export
	
	InitMessages();
	
	MessageSubject1 = "Exchange message (%1)"; // 
	MessageSubject1 = StringFunctionsClientServer.SubstituteParametersToString(MessageSubject1, MessageFileNameTemplate);
	
	SimpleBody	= NStr("en = 'Data exchange message';");
	CompressedBody	= NStr("en = 'Compressed data exchange message';");
	BatchBody	= NStr("en = 'Batch data exchange message';");
	
EndProcedure

// Checks whether the connection to the specified resource can be established.
//
// Parameters:
//  No.
// 
//  Returns:
//    Boolean - 
//
Function ConnectionIsSet() Export
	
	InitMessages();
	
	If Not ValueIsFilled(EMAILAccount) Then
		GetErrorMessage(101);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Time exchange message file changed.
//
// Returns:
//  String - 
//
Function ExchangeMessageFileDate() Export
	
	Result = Undefined;
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		If TempExchangeMessageFile.Exists() Then
			
			Result = TempExchangeMessageFile.GetModificationTime();
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Full exchange message file name.
//
// Returns:
//  String - 
//
Function ExchangeMessageFileName() Export
	
	Name = "";
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		Name = TempExchangeMessageFile.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Full exchange message directory name.
//
// Returns:
//  String - 
//
Function ExchangeMessageDirectoryName() Export
	
	Name = "";
	
	If TypeOf(TempExchangeMessagesDirectory) = Type("File") Then
		
		Name = TempExchangeMessagesDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessagesDirectory()
	
	// Creating the temporary exchange message directory.
	Try
		TempDirectoryName = DataExchangeServer.CreateTempExchangeMessagesDirectory(DirectoryID);
	Except
		GetErrorMessage(4);
		SupplementErrorMessage(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	TempExchangeMessagesDirectory = New File(TempDirectoryName);
	
	MessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNameTemplate + ".xml");
	
	TempExchangeMessageFile = New File(MessageFileName);
	
	Return True;
EndFunction

Function DeleteTempExchangeMessagesDirectory()
	
	Try
		If Not IsBlankString(ExchangeMessageDirectoryName()) Then
			DeleteFiles(ExchangeMessageDirectoryName());
			TempExchangeMessagesDirectory = Undefined;
		EndIf;
		
		If Not DirectoryID = Undefined Then
			DataExchangeServer.GetFileFromStorage(DirectoryID);
			DirectoryID = Undefined;
		EndIf;
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SendExchangeMessage()
	
	Result = True;
	
	Extension = ?(CompressOutgoingMessageFile(), ".zip", ".xml");
	
	OutgoingMessageFileName = MessageFileNameTemplate + Extension;
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the temporary archive file name.
		ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNameTemplate + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ArchivePasswordExchangeMessages, NStr("en = 'Exchange message file';"));
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			
			Result = False;
			GetErrorMessage(3);
			SupplementErrorMessage(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Checking that the exchange message size does not exceed the maximum allowed size.
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ArchiveTempFileName, MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessagebyEmail(
									CompressedBody,
									OutgoingMessageFileName,
									ArchiveTempFileName);
			
		EndIf;
		
	Else
		
		If Result Then
			
			// Checking that the exchange message size does not exceed the maximum allowed size.
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ExchangeMessageFileName(), MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessagebyEmail(
									SimpleBody,
									OutgoingMessageFileName,
									ExchangeMessageFileName());
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns:
//   ValueTable - 
//     * Id - Array of String - a message ID collection.
//     * PostingDate - Date - message sending date.
//
Function ExchangeMessagesTable()
	
	ExchangeMessagesTable = New ValueTable;
	ExchangeMessagesTable.Columns.Add("Id",   New TypeDescription("Array"));
	ExchangeMessagesTable.Columns.Add("PostingDate", New TypeDescription("Date"));
	
	Return ExchangeMessagesTable;
	
EndFunction

Function GetExchangeMessage(ExistenceCheck)
	
	ExchangeMessagesTable = ExchangeMessagesTable();
	
	ColumnsArray1 = New Array;
	
	ColumnsArray1.Add("Id");
	ColumnsArray1.Add("PostingDate");
	ColumnsArray1.Add("Subject");
	
	ImportParameters = New Structure;
	ImportParameters.Insert("Columns", ColumnsArray1);
	ImportParameters.Insert("GetHeaders", True);
	
	Try
		MessageSet = EmailOperationsCommonModule.DownloadEmailMessages(EMAILAccount, ImportParameters);
	Except
		ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		GetErrorMessage(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	SearchSubjectsSubstring = Upper(StrReplace(TrimAll(MessageFileNameTemplate), "Message_", ""));
	
	For Each MailMessage In MessageSet Do
		
		EmailMessageSubject = TrimAll(MailMessage.Subject);
		EmailMessageSubject = StrReplace(EmailMessageSubject, Chars.Tab, "");
		
		If Upper(EmailMessageSubject) <> Upper(TrimAll(MessageSubject1)) Then
			// The message name can be in the format of Message_[prеfix]_UID1_UID2.
			If StrFind(Upper(EmailMessageSubject), SearchSubjectsSubstring) = 0 Then
				Continue;
			EndIf;
		EndIf;
		
		NewRow = ExchangeMessagesTable.Add();
		FillPropertyValues(NewRow, MailMessage);
		
	EndDo;
	
	If ExchangeMessagesTable.Count() = 0 Then
		
		If Not ExistenceCheck Then
			GetErrorMessage(104);
		
			MessageString = NStr("en = 'The messages with ""%1"" header are not found.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, MessageSubject1);
			SupplementErrorMessage(MessageString);
		EndIf;
		
		Return False;
		
	Else
		
		If ExistenceCheck Then
			Return True;
		EndIf;
		
		ExchangeMessagesTable.Sort("PostingDate Desc");
		
		ColumnsArray1 = New Array;
		ColumnsArray1.Add("Attachments");
		
		ImportParameters = New Structure;
		ImportParameters.Insert("Columns", ColumnsArray1);
		ImportParameters.Insert("HeadersIDs", ExchangeMessagesTable[0].Id);
		
		Try
			MessageSet = EmailOperationsCommonModule.DownloadEmailMessages(EMAILAccount, ImportParameters);
		Except
			ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			GetErrorMessage(105);
			SupplementErrorMessage(ErrorText);
			Return False;
		EndTry;
		
		BinaryData = MessageSet[0].Attachments.Get(MessageFileNameTemplate+".zip"); // BinaryData
		
		If BinaryData <> Undefined Then
			FilePacked = True;
		Else
			BinaryData = MessageSet[0].Attachments.Get(MessageFileNameTemplate+".xml");
			FilePacked = False;
		EndIf;
		
		// 
		FilePacked = False;
		SearchTemplate = StrReplace(MessageFileNameTemplate, "Message_","");
		For Each CurAttachment In MessageSet[0].Attachments Do
			If StrFind(CurAttachment.Key, SearchTemplate) > 0 Then
				BinaryData = CurAttachment.Value;
				If StrEndsWith(CurAttachment.Key,".zip") > 0 Then
					FilePacked = True;
				EndIf;
				// Rewrite the accurate file name template as an attachment name without an extension.
				AttachedFileNameStructure = CommonClientServer.ParseFullFileName(CurAttachment.Key,False);
				MessageFileNameTemplate = AttachedFileNameStructure.BaseName;
				Break;
			EndIf;
		EndDo;
			
		If BinaryData = Undefined Then
			GetErrorMessage(109);
			Return False;
		EndIf;
		
		If FilePacked Then
			
			// Getting the temporary archive file name.
			ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileNameTemplate + ".zip");
			
			Try
				BinaryData.Write(ArchiveTempFileName);
			Except
				ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				GetErrorMessage(106);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
			InformationRegisters.ArchiveOfExchangeMessages.PackMessageToArchive(InfobaseNode, ArchiveTempFileName);
			
			// Unpacking the temporary archive file.
			SuccessfullyUnpacked = DataExchangeServer.UnpackZipFile(ArchiveTempFileName, ExchangeMessageDirectoryName(), ArchivePasswordExchangeMessages);
			
			If Not SuccessfullyUnpacked Then
				GetErrorMessage(2);
				Return False;
			EndIf;
			
			// Checking that the message file exists.
			File = New File(ExchangeMessageFileName());
			
			If Not File.Exists() Then
				// The archive name probably does not match name of the file inside.
				MessageFileNameStructure = CommonClientServer.ParseFullFileName(ExchangeMessageFileName(),False);

				If MessageFileNameTemplate <> MessageFileNameStructure.BaseName Then
					UnpackedFilesArray = FindFiles(ExchangeMessageDirectoryName(), "*.xml", False);
					If UnpackedFilesArray.Count() > 0 Then
						UnpackedFile = UnpackedFilesArray[0];
						MoveFile(UnpackedFile.FullName,ExchangeMessageFileName());
					Else
						GetErrorMessage(5);
						Return False;
					EndIf;
				Else
					GetErrorMessage(5);
					Return False;
				EndIf;
				
			EndIf;
			
		Else
			
			Try
				BinaryData.Write(ExchangeMessageFileName());
			Except
				ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				GetErrorMessage(106);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
			InformationRegisters.ArchiveOfExchangeMessages.PackMessageToArchive(ExchangeMessageFileName(), ArchiveTempFileName);
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNo)
	
	SetErrorMessageString(ErrorsMessages[MessageNo]);
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = NStr("en = 'Internal error';");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = ObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

// The overridable function, returns the maximum allowed size of
// a message to be sent.
// 
Function MaxMessageSize()
	
	Return EMAILMaxMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves a flag that shows that the outgoing message file is compressed.
// 
Function CompressOutgoingMessageFile()
	
	Return EMAILCompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization.

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	ErrorsMessages = New Map;
	
	// 
	ErrorsMessages.Insert(001, NStr("en = 'Exchange messages are not detected.';"));
	ErrorsMessages.Insert(002, NStr("en = 'Error extracting message file.';"));
	ErrorsMessages.Insert(003, NStr("en = 'Error packing the exchange message file.';"));
	ErrorsMessages.Insert(004, NStr("en = 'An error occurred when creating a temporary directory.';"));
	ErrorsMessages.Insert(005, NStr("en = 'The archive does not contain the exchange message file.';"));
	ErrorsMessages.Insert(006, NStr("en = 'Couldn''t send the message. Message size exceeds the limit.';"));
	
	// 
	ErrorsMessages.Insert(101, NStr("en = 'Initialization error: the exchange message transport email account is not specified.';"));
	ErrorsMessages.Insert(102, NStr("en = 'Error sending the email message.';"));
	ErrorsMessages.Insert(103, NStr("en = 'Error receiving message headers from the email server.';"));
	ErrorsMessages.Insert(104, NStr("en = 'Exchange messages were not found on the email server.';"));
	ErrorsMessages.Insert(105, NStr("en = 'Error receiving the message from the email server.';"));
	ErrorsMessages.Insert(106, NStr("en = 'Error saving the exchange message file to the hard drive.';"));
	ErrorsMessages.Insert(107, NStr("en = 'Errors occurred while verifying account parameters.';"));
	ErrorsMessages.Insert(108, NStr("en = 'The maximum allowed exchange message size is exceeded.';"));
	ErrorsMessages.Insert(109, NStr("en = 'Error: no exchange message file is found in the email message.';"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for email management.

Function SendMessagebyEmail(Body, OutgoingMessageFileName, PathToFile)
	
	AttachmentDetails = New Structure;
	AttachmentDetails.Insert("Presentation", OutgoingMessageFileName);
	AttachmentDetails.Insert("AddressInTempStorage", PutToTempStorage(New BinaryData(PathToFile)));
	
	Email = Common.ObjectAttributeValue(EMAILAccount, "Email");					
						
	MessageParameters = New Structure;
	MessageParameters.Insert("Whom",     Email);
	MessageParameters.Insert("Subject",     MessageSubject1);
	MessageParameters.Insert("Body",     Body);
	MessageParameters.Insert("Attachments", New Array);
	
	MessageParameters.Attachments.Add(AttachmentDetails);
	
	Try
		NewEmail = EmailOperationsCommonModule.PrepareEmail(EMAILAccount, MessageParameters);
		EmailOperationsCommonModule.SendMail(EMAILAccount, NewEmail);
	Except
		ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#Region Initialization

InitMessages();
ErrorMessageInitialization();

TempExchangeMessagesDirectory = Undefined;
TempExchangeMessageFile    = Undefined;

ObjectName = NStr("en = 'Data processor: %1';");
ObjectName = StringFunctionsClientServer.SubstituteParametersToString(ObjectName, Metadata().Name);

If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
	EmailOperationsCommonModule = Common.CommonModule("EmailOperations");
EndIf;

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf