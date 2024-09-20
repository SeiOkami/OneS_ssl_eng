///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region FilesImport

// Shows a file selection dialog box and places the selected file into a temporary storage.
// This method provides the functionality of both BeginPutFile and BeginPuttingFiles global context methods.
// Its return value is not affected by availability of the extension to work with 1C:Enterprise.
// Restrictions:
//   Not used to select catalogs -this option is not supported in the web client mode.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains details of the procedure that will be called after
//                             the file with the following parameters is imported:
//      * FileThatWasPut - Undefined -
//                       - Structure    - 
//                           ** Location  - String - data location in a temporary storage.
//                           ** Name       - String - In the thin client and in the web client with the file system extension
//                                        installed it is the local path where
//                                        the file was received. In a web client without a file system
//                                        extension it is the name of the file with extension.
//      * AdditionalParameters - Arbitrary - a value that was specified on creating
//                                the NotifyDescription object.
//   ImportParameters         - See FileSystemClient.FileImportParameters.
//   FileName                  - String - the full path to the file that will be offered to the user at the beginning of
//                             interactive selection or will be put to the temporary storage in noninteractive. If
//                             noninteractive mode is selected and the parameter is not filled, an exception will be called.
//   AddressInTempStorage - String - the address where the file will be saved.
//
// Example:
//   Notification = New NotifyDescription("SelectFileAfterPutFiles", ThisObject, Context);
//   ImportParameters = FileSystemClient.FileImportParameters();
//   ImportParameters.FormID = UUID;
//   FileSystemClient.ImportFile(Notification, ImportParameters);
//
Procedure ImportFile_(
		CompletionHandler, 
		ImportParameters = Undefined, 
		FileName = "",
		AddressInTempStorage = "") Export
	
	If ImportParameters = Undefined Then
		ImportParameters = FileImportParameters();
	ElsIf Not ImportParameters.Interactively
		And IsBlankString(FileName) Then
		Raise NStr("en = 'Import in non-interactive mode failed. The name of the file to import is not specified.';");
	EndIf;
	
	If Not ValueIsFilled(ImportParameters.FormIdentifier) Then
		ImportParameters.FormIdentifier = New UUID;
	EndIf;
	
	FileDetails = New TransferableFileDescription(FileName, AddressInTempStorage);
	ImportParameters.Insert("FilesToUpload", FileDetails);
	
	ImportParameters.Dialog.FullFileName     = FileName;
	ImportParameters.Dialog.Multiselect = False;
	ShowPutFile(CompletionHandler, ImportParameters);
	
EndProcedure

// Shows a file selection dialog and puts the selected files to a temporary storage.
// This method provides the functionality of both BeginPutFile and BeginPuttingFiles global context methods.
// Its return value is not affected by availability of the extension to work with 1C:Enterprise.
// Restrictions:
//   Not used to select catalogs -this option is not supported in the web client mode.
//   Multiple selection in the web client is only supported if the extension to work with 1C:Enterprise is available.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains the description of the procedure that will be called after
//                             the files with the following parameters will be imported:
//      * PlacedFiles - Undefined -
//                        - Array - 
//                           ** Location  - String - data location in a temporary storage.
//                           ** Name       - String - In the thin client and in the web client with the file system extension
//                                        installed it is the local path where
//                                        the file was received. In a web client without a file system
//                                        extension it is the name of the file with extension.
//                           ** FullName - String - In the thin client and in the web client with the file system extension
//                                         installed it is the local path where
//                                         the file was received. In the web client without file system extension
//                                         it takes value "".
//                           ** FileName  - String - a name of a file with extension.
//      * AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//   ImportParameters    - See FileSystemClient.FileImportParameters.
//   FilesToUpload     - Array - contains objects of the TransferableFileDetails type. Can be filled completely.
//                        In this case the files being imported will be saved to the specified addresses. Can be filled
//                        partially. Only the names of the array items are filled. In this case the files being imported will be
//                        placed in new temporary storages. Array can be empty. In this case the files
//                        to put are defined by the values specified in the ImportParameters parameter. If noninteractive mode is selected in
//                        import parameters, and the FilesToUpload parameter is not filled, an exception
//                        will be called.
//
// Example:
//   Notification = New NotifyDescription("LoadExtensionAfterPutFiles", ThisObject, Context);
//   ImportParameters = FileSystemClient.FileImportParameters();
//   ImportParameters.FormID = UUID;
//   FileSystemClient.ImportFiles(Notification, ImportParameters);
//
Procedure ImportFiles(
		CompletionHandler, 
		ImportParameters = Undefined,
		FilesToUpload = Undefined) Export
	
	If ImportParameters = Undefined Then
		ImportParameters = FileImportParameters();
	EndIf;
	
	If Not ImportParameters.Interactively
		And (FilesToUpload = Undefined 
		Or (TypeOf(FilesToUpload) = Type("Array")
		And FilesToUpload.Count() = 0)) Then
		
		Raise NStr("en = 'Import in non-interactive mode failed. The files to import are not specified.';");
		
	EndIf;
	
	If FilesToUpload = Undefined Then
		FilesToUpload = New Array;
	EndIf;
	
	If Not ValueIsFilled(ImportParameters.FormIdentifier) Then
		ImportParameters.FormIdentifier = New UUID;
	EndIf;
	
	ImportParameters.Dialog.Multiselect = True;
	ImportParameters.Insert("FilesToUpload", FilesToUpload);
	ShowPutFile(CompletionHandler, ImportParameters);
	
EndProcedure

#EndRegion

#Region ModifiesStoredData

// Gets the file and saves it to the local file system of the user.
//
// Parameters:
//   CompletionHandler      - NotifyDescription
//                             - Undefined -  
//                                              
//      * ObtainedFiles         - Undefined - files are not received.
//                                - Array - 
//      * AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//   AddressInTempStorage - String - data location in a temporary storage.
//   FileName                  - String - a full path according to which the received file and the file name
//                                        with an extension must be saved.
//   SavingParameters       - See FileSystemClient.FileSavingParameters
//
// Example:
//   Notification = New NotifyDescription("SaveCertificateAfterFilesReceipt", ThisObject, Context);
//   SavingParameters = FileSystemClient.FileSavingParameters();
//   FileSystemClient.SaveFile(Notification, Context.CertificateAddress, FileName, SavingParameters);
//
Procedure SaveFile(CompletionHandler, AddressInTempStorage, FileName = "",
	SavingParameters = Undefined) Export
	
	If SavingParameters = Undefined Then
		SavingParameters = FileSavingParameters();
	EndIf;
	
	FileData = New TransferableFileDescription(FileName, AddressInTempStorage);
	
	FilesToSave = New Array;
	FilesToSave.Add(FileData);
	
	ShowDownloadFiles(CompletionHandler, FilesToSave, SavingParameters);
	
EndProcedure

// Gets the files and saves them to the local file system of the user.
// To save files in noninteractive mode, the Name property of the FilesToSave parameter must have
// the full path to the file being saved, or if the Name property contains only the file name with extension, the Directory property of the Dialog item of the SavingParameters parameter is to be
// filled. Otherwise, an exception
// will be called.
//
// Parameters:
//   CompletionHandler - NotifyDescription
//                        - Undefined - 
//                             
//     * ObtainedFiles         - Undefined - files are not received.
//                               - Array - 
//     * AdditionalParameters - Arbitrary - a value that was specified on creating
//                               the NotifyDescription object.
//   FilesToSave     - Array of TransferableFileDescription
//   SavingParameters  - See FileSystemClient.FileSavingParameters
//
// Example:
//   Notification = New NotifyDescription("SavePrintFormToFileAfterGetFiles", ThisObject);
//   SavingParameters = FileSystemClient.FilesSavingParameters();
//   FileSystemClient.SaveFiles(Notification, FilesToGet, SavingParameters);
//
Procedure SaveFiles(CompletionHandler, FilesToSave, SavingParameters = Undefined) Export
	
	If SavingParameters = Undefined Then
		SavingParameters = FilesSavingParameters();
	EndIf;
	
	ShowDownloadFiles(CompletionHandler, FilesToSave, SavingParameters);
	
EndProcedure

#EndRegion

#Region Parameters

// Initializes a parameter structure to import the file from the file system.
// To be used in FileSystemClient.ImportFile and FileSystemClient.ImportFiles
//
// Returns:
//  Structure:
//    * FormIdentifier                  - UUID - a UUID of the form
//                                          used to place files. If the parameter is filled,
//                                          the DeleteFromTempStorage global context method is to be called
//                                          after completing the operation with the binary data. Default
//                                          value is Undefined.
//    * Interactively                        - Boolean - Indicates interactive mode usage when a file selection dialog is showed to
//                                          the user. Default
//                                          value is True.
//    * Dialog                              - FileDialog - for the properties, see the Syntax Assistant. 
//                                          It is used if the Interactively property is True, and
//                                          if the extension to work with 1C:Enterprise was applied.
//    * SuggestionText                    - String - a text of a suggestion to install the extension. If the parameter
//                                          takes the value "", the standard suggestion text will be output.
//                                          Default value - "".
//    * AcrtionBeforeStartPutFiles - NotifyDescription
//                                          - Undefined - 
//                                          
//                                          
//                                          
//                                          
//        ** Files         - FileRef
//                                   - Array - 
//                                   
//        ** RefusalToPlaceFile   - Boolean - Indicates that file putting was canceled. If the parameter is set to True in
//                                   the handler procedure body, the file is not placed.
//        ** AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//
// Example:
//  ImportParameters = FileSystemClient.FileImportParameters();
//  ImportParameters.Dialog.Title = NStr("en = 'Select a document'");
//  ImportParameters.Dialog.Filter = NStr("en = 'MS Word files (*.doc;*.docx)|*.doc;*.docx|All files (*.*)|*.*'");
//  FileSystemClient.ImportFile(Notification, ImportParameters);
//
Function FileImportParameters() Export
	
	ImportParameters = OperationContext(FileDialogMode.Open);
	ImportParameters.Insert("FormIdentifier", Undefined);
	ImportParameters.Insert("AcrtionBeforeStartPutFiles", Undefined);
	Return ImportParameters;
	
EndFunction

// Initializes a parameter structure to save the file to the file system.
// To be used in FileSystemClient.SaveFile.
//
// Returns:
//  Structure:
//    * Interactively     - Boolean - Indicates interactive mode usage when a file selection dialog is showed to
//                       the user. Default
//                       value is True.
//    * Dialog           - FileDialog - for the properties, see the Syntax Assistant. 
//                       It is used if the Interactively property is True, and
//                       if the extension to work with 1C:Enterprise was applied.
//    * SuggestionText - String - a text of a suggestion to install the extension. If the parameter
//                       takes the value "", the standard suggestion text will be output.
//                       Default value - "".
//
// Example:
//  SavingParameters = FileSystemClient.FileSavingParameters();
//  SavingParameters.Dialog.Title = NStr("en = 'Save key operation profile to file");
//  SavingParameters.Dialog.Filter = "Key operation profile files (*.xml)|*.xml";
//  FileSystemClient.SaveFile(Undefined, SaveKeyOperationsProfileToServer(), , SavingParameters);
//
Function FileSavingParameters() Export
	
	Return OperationContext(FileDialogMode.Save);
	
EndFunction

// Initializes a parameter structure to save the file to the file system.
// To be used in FileSystemClient.SaveFiles
//
// Returns:
//  Structure:
//    * Interactively     - Boolean - Indicates interactive mode usage when a file selection dialog is showed to
//                       the user. Default
//                       value is True.
//    * Dialog           - FileDialog - for the properties, see the Syntax Assistant. 
//                       It is used if the Interactively property is True, and
//                       if the extension to work with 1C:Enterprise was applied.
//    * SuggestionText - String - a text of a suggestion to install the extension. If the parameter
//                       takes the value "", the standard suggestion text will be output.
//                       Default value - "".
//
// Example:
//  SavingParameters = FileSystemClient.FilesSavingParameters();
//  SavingParameters.Dialog.Title = NStr("en ='Select a folder to save generated document'");
//  FileSystemClient.SaveFiles(Notification, FilesToGet, SavingParameters);
//
Function FilesSavingParameters() Export
	
	Return OperationContext(FileDialogMode.ChooseDirectory);
	
EndFunction

// Initializes a parameter structure to open the file.
// To be used in FileSystemClient.OpenFile
//
// Returns:
//  Structure:
//    *Encoding         - String - a text file encoding. If the parameter is not specified, the text format
//                       will be determined automatically. See the code list in the Syntax Assistant in  
//                       the Write method details of the text document. Default value - "".
//    *ForEditing - Boolean - True to open the file for editing, False otherwise. If
//                       the parameter takes the True value, waiting for application closing, and if in the
//                       FileLocation parameter the address is stored in the temporary storage, it updates the file data.
//                       Default value is False.
//
Function FileOpeningParameters() Export
	
	Context = New Structure;
	Context.Insert("Encoding", "");
	Context.Insert("ForEditing", False);
	Return Context;
	
EndFunction

#EndRegion

#Region RunExternalApplications

// Opens a file for viewing or editing.
// If the file is opened from the binary data in a temporary storage, it is previously saved
// to the temporary directory.
//
// Parameters:
//  FileLocation1    - String - a full path to the file in the file system or file data location
//                       in the temporary storage.
//  CompletionHandler - NotifyDescription
//                       - Undefined - 
//                       
//    * TheModifiedFile             - Boolean -
//    * AdditionalParameters - Arbitrary - a value that was specified on creating
//                              the NotifyDescription object.
//  FileName             - String - the name of the file with an extension or the file extension without the dot. If
//                       the FileLocation parameter contains the address in a temporary storage and the parameter
//                       FileName is empty, an exception is thrown.
//  OpeningParameters    - See FileSystemClient.FileOpeningParameters.
//
Procedure OpenFile(
		FileLocation1,
		CompletionHandler = Undefined,
		FileName = "",
		OpeningParameters = Undefined) Export
		
	If OpeningParameters = Undefined Then
		OpeningParameters = FileOpeningParameters();
	EndIf;
	
	OpeningParameters.Insert("CompletionHandler", CompletionHandler);
	If IsTempStorageURL(FileLocation1) Then
		
		If IsBlankString(FileName) Then
			Raise NStr("en = 'The file name is not specified.';");
		EndIf;
		
		PathToFile = TempFileFullName(FileName);
		ShortenFullFileNameToAllowedNTFSLength(PathToFile);
		
		OpeningParameters.Insert("PathToFile", PathToFile);
		OpeningParameters.Insert("AddressOfBinaryDataToUpdate", FileLocation1);
		OpeningParameters.Insert("DeleteAfterDataUpdate", True);
		
		SavingParameters = FileSavingParameters();
		SavingParameters.Interactively = False;
		
		NotifyDescription = New NotifyDescription(
			"OpenFileAfterSaving", FileSystemInternalClient, OpeningParameters);
		
		SaveFile(NotifyDescription, FileLocation1, PathToFile, SavingParameters);
		
	Else
		FileSystemInternalClient.OpenFileAfterSaving(
			New Structure("FullName", FileLocation1), OpeningParameters);
	EndIf;
	
EndProcedure

// Opens Windows Explorer to the specified directory.
// If a file path is specified, the pointer is placed on the file.
//
// Parameters:
//  PathToDirectoryOrFile - String -
//
// Example:
//  // For Windows OS
//  FileSystemClient.OpenExplorer("C:\Users");
//  FileSystemClient.OpenExplorer("C:\Program Files\1cv8\common\1cestart.exe");
//  // For Linux OS
//  FileSystemClient.OpenExplorer("/home/");
//  FileSystemClient.OpenExplorer("/opt/1C/v8.3/x86_64/1cv8c");
//
Procedure OpenExplorer(PathToDirectoryOrFile) Export
	
	FileInfo3 = New File(PathToDirectoryOrFile);
	
	Context = New Structure;
	Context.Insert("FileInfo3", FileInfo3);
	
	Notification = New NotifyDescription(
		"OpenExplorerAfterCheckFileSystemExtension", FileSystemInternalClient, Context);
		
	SuggestionText = NStr("en = 'To open the folder, install 1C:Enterprise Extension.';");
	AttachFileOperationsExtension(Notification, SuggestionText, False);
	
EndProcedure

// Opens a URL in an application associated with URL protocol.
//
// Valid protocols: http, https, e1c, v8help, mailto, tel, skype.
//
// Do not use protocol file:// to open Explorer or a file.
// - To Open Explorer See OpenExplorer.
// - To open a file in an associated application, use OpenFileInViewer. 
//
// Parameters:
//  URL - String - a link to open.
//  Notification - NotifyDescription - notification on file open attempt.
//      If the notification is not specified and an error occurs, the method shows a warning.
//      ApplicationStarted - Boolean - True if the external application opened successfully.
//      AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//
// Example:
//  FileSystemClient.OpenURL("e1cib/navigationpoint/startpage"); // Home page.
//  FileSystemClient.OpenURL("v8help://1cv8/QueryLanguageFullTextSearchInData");
//  FileSystemClient.OpenURL("https://1c.ru");
//  FileSystemClient.OpenURL("mailto:help@1c.ru");
//  FileSystemClient.OpenURL("skype:echo123?call");
//
Procedure OpenURL(URL, Val Notification = Undefined) Export
	
	// CAC:534-off safe start methods are provided with this function
	
	Context = New Structure;
	Context.Insert("URL", URL);
	Context.Insert("Notification", Notification);
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot open URL ""%1"".
		           |The URL is invalid.';"),
		URL);
	
	If Not FileSystemInternalClient.IsAllowedRef(URL) Then 
		
		FileSystemInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
		
	ElsIf FileSystemInternalClient.IsWebURL(URL)
		Or CommonInternalClient.IsURL(URL) Then 
		
		Try
		
#If ThickClientOrdinaryApplication Then
			
			// 
			Notification = New NotifyDescription(
				,, Context,
				"OpenURLOnProcessError", FileSystemInternalClient);
			BeginRunningApplication(Notification, URL);
#Else
			GotoURL(URL);
#EndIf
			
			If Notification <> Undefined Then 
				ApplicationStarted = True;
				ExecuteNotifyProcessing(Notification, ApplicationStarted);
			EndIf;
			
		Except
			FileSystemInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
		EndTry;
		
	ElsIf FileSystemInternalClient.IsHelpRef(URL) Then 
		
		OpenHelp(URL);
		
	Else 
		
		Notification = New NotifyDescription(
			"OpenURLAfterCheckFileSystemExtension", FileSystemInternalClient, Context);
		
		SuggestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To open link %1, install 1C:Enterprise Extension.';"),
			URL);
		AttachFileOperationsExtension(Notification, SuggestionText, False);
		
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// Parameter constructor for FileSystemClient.StartApplication.
//
// Returns:
//  Structure:
//    * CurrentDirectory - String - sets the current directory of the application being started up.
//    * Notification - NotifyDescription - notification of the running application completion result, 
//          if the notification is not specified and an error occurs, the method shows a warning. Completion handler parameters:
//          Result - Structure - the application operation result:
//              -- 
//              -- 
//              -- 
//              -- 
//                             
//              -- 
//                             
//          
//    * WaitForCompletion - Boolean - True, wait for the running application to end before proceeding.
//    * GetOutputStream - Boolean - False - result is passed to stdout.
//         Ignored if WaitForCompletion is not specified.
//    * GetErrorStream - Boolean - False - errors are passed to stderr stream.
//         Ignored if WaitForCompletion is not specified.
//    * ThreadsEncoding - TextEncoding
//                       - String - 
//         
//    * ExecutionEncoding - String
//                          - Number - 
//         
//         
//         
//         
//    * ExecuteWithFullRights - Boolean - True, if the application must be run
//          with full system privileges:
//          Windows: UAC query;
//          Linux: execution with pkexec command;
//          macOS, web client, and mobile client: Result.ErrorDetails will be returned.
//    * ExecutionEnvironment - String - an empty string if the runtime is not Windows. Used when identifying 
//								   invalid characters in the launch string.
//
Function ApplicationStartupParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDirectory", "");
	Parameters.Insert("Notification", Undefined);
	Parameters.Insert("WaitForCompletion", True);
	Parameters.Insert("GetOutputStream", False);
	Parameters.Insert("GetErrorStream", False);
	Parameters.Insert("ThreadsEncoding", Undefined);
	Parameters.Insert("ExecutionEncoding", Undefined);
	Parameters.Insert("ExecuteWithFullRights", False);
	
	ExecutionEnvironment = ?(CommonClient.IsWindowsClient(), "Windows", ""); 
	Parameters.Insert("ExecutionEnvironment", ExecutionEnvironment);
	
	Return Parameters;
	
EndFunction

// Starts up an external application for execution (for example, * .exe, * bat), 
// or a system command (for example, ping, tracert or traceroute, access the rac client),
// It also allows you to get a return code and the values ​​of output streams (stdout) and errors (stderr)
//
// When an external program is started up in batch mode, the output stream and error stream may return in an unexpected language. 
// To pass to the external application the language in which the expected result must be, you need to:
// - specify the language in the startup parameter of this application (if such a parameter is provided). 
//   For example, batch mode of 1C:Enterprise has the "/L en" key;
// - In other cases, explicitly set the encoding for the batch command execution.
//   See the ExecutionEncoding property of return value FileSystemClient.ApplicationStartupParameters. 
//
// Parameters:
//  StartupCommand - String - application startup command line.
//                 - Array - 
//      
//      
//  ApplicationStartupParameters - See FileSystemClient.ApplicationStartupParameters.
//
// Example: 
//	// Simple start
//  FileSystemClient.StartApplication("calc");
//
//  // Startup with waiting for completion and getting return code:
//  ApplicationStartupParameters = FileSystemClient.ApplicationStartupParameters();
//  ApplicationStartupParameters.WaitForCompletion = True;
//  ApplicationStartupParameters.GetOutputStream = True;
//  ApplicationStartupParameters.GetErrorsStream = True;
//
//  Result = FileSystemClient.StartApplication("ping 127.0.0.1 -n 5", ApplicationStartupParameters);
//
//  ReturnCode = Result.ReturnCode;
//  OutputStream = Result.OutputStream;
//  ErrorsStream = Result.ErrorsStream;
//
Procedure StartApplication(Val StartupCommand, Val ApplicationStartupParameters = Undefined) Export
	
	If ApplicationStartupParameters = Undefined Then 
		ApplicationStartupParameters = ApplicationStartupParameters();
	EndIf;
	
	CommandString = CommonInternalClientServer.SafeCommandString(StartupCommand);
	
	OutputThreadFileName = "";
	ErrorsThreadFileName = "";
	
#If Not WebClient Then
	If ApplicationStartupParameters.WaitForCompletion Then
		
		// CAC:441-off temporary files are deleted after the asynchronous operations
		
		If ApplicationStartupParameters.GetOutputStream Then
			OutputThreadFileName = GetTempFileName("stdout.tmp");
			CommandString = CommandString + " > """ + OutputThreadFileName + """";
		EndIf;
		
		If ApplicationStartupParameters.GetErrorStream Then 
			ErrorsThreadFileName = GetTempFileName("stderr.tmp");
			CommandString = CommandString + " 2> """ + ErrorsThreadFileName + """";
		EndIf;
		
		// ACC:441-on
		
	EndIf;
#EndIf
	
	Context = New Structure;
	Context.Insert("CommandString", CommandString);
	Context.Insert("CurrentDirectory", ApplicationStartupParameters.CurrentDirectory);
	Context.Insert("Notification", ApplicationStartupParameters.Notification);
	Context.Insert("WaitForCompletion", ApplicationStartupParameters.WaitForCompletion);
	Context.Insert("ThreadsEncoding", ApplicationStartupParameters.ThreadsEncoding);
	Context.Insert("ExecutionEncoding", ApplicationStartupParameters.ExecutionEncoding);
	Context.Insert("GetOutputStream", ApplicationStartupParameters.GetOutputStream);
	Context.Insert("GetErrorStream", ApplicationStartupParameters.GetErrorStream);
	Context.Insert("OutputThreadFileName", OutputThreadFileName);
	Context.Insert("ErrorsThreadFileName", ErrorsThreadFileName);
	Context.Insert("ExecuteWithFullRights", ApplicationStartupParameters.ExecuteWithFullRights);
	
	Notification = New NotifyDescription("StartApplicationAfterCheckFileSystemExtension", 
		FileSystemInternalClient, Context);
	AttachFileOperationsExtension(Notification, 
		NStr("en = 'To create a temporary folder, install 1C:Enterprise Extension.';"), False);
	
EndProcedure

// Prints the file by an external application.
//
// Parameters:
//  FileToOpenName - String
//
Procedure PrintFromApplicationByFileName(FileToOpenName) Export
	
	If Not ValueIsFilled(FileToOpenName) Then
		Return;
	EndIf;
	
#If Not MobileClient Then
	If CommonClient.IsWindowsClient() Then
		Shell = New COMObject("Shell.Application");
		Shell.ShellExecute(FileToOpenName, "", "", "print", 1);
	ElsIf CommonClient.IsLinuxClient() Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("FileToOpenName", FileToOpenName);
		NotifyDescription = New NotifyDescription("PrintFromTheApplicationByTheLinuxFileName", 
			ThisObject, AdditionalParameters);
		CheckIfTheLinuxProgramIsInstalled("Unoconv", NotifyDescription);
	Else
		ShowMessageBox(, NStr("en = 'You can print this type of files only from an application for Windows or Linux.';"));
		Return;
	EndIf;
#EndIf

EndProcedure

#EndRegion

#Region Other

// Calls directory selection dialog.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains the description of the procedure that will be called after
//                        the selection dialog box is closed, with the following parameters:
//      -- 
//                        
//      -- 
//   Title - String - a title of the directory selection dialog.
//   Directory   - String - the initial default directory value.
//
Procedure SelectDirectory(CompletionHandler, Title = "", Directory = "") Export
	
	Context = New Structure;
	Context.Insert("CompletionHandler", CompletionHandler);
	Context.Insert("Title", Title);
	Context.Insert("Directory", Directory);
	
	NotifyDescription = New NotifyDescription(
		"SelectDirectoryOnAttachFileSystemExtension", FileSystemInternalClient, Context);
	AttachFileOperationsExtension(NotifyDescription);
	
EndProcedure

// Shows a file selection dialog.
// In the web client, a user will see the dialog box for installing a file system
// extension if it is required.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains the description of the procedure that will be called after
//           the selection dialog box is closed, with the parameters:
//          * Result - Array of String - selected file names.
//           			- String - 
//           			- Undefined - 
//      * AdditionalParameters - Structure - additional notification parameters.
//   Dialog - FileDialog - for the properties, see the Syntax Assistant. 
//
Procedure ShowSelectionDialog(CompletionHandler, Dialog) Export
	
	Context = New Structure;
	Context.Insert("CompletionHandler", CompletionHandler);
	Context.Insert("Dialog", Dialog);
	
	NotifyDescription = New NotifyDescription(
		"ShowSelectionDialogOnAttachFileSystemExtension", FileSystemInternalClient, Context);
	AttachFileOperationsExtension(NotifyDescription, , False);
	
EndProcedure

// Gets temporary directory name.
//
// Parameters:
//  Notification - NotifyDescription - notification on getting directory name attempt with the following parameters.
//    -- 
//    -- 
//  Extension - String - the suffix in the directory name, which helps to identify the directory for analysis.
//
Procedure CreateTemporaryDirectory(Val Notification, Extension = "") Export 
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Extension", Extension);
	
	Notification = New NotifyDescription("CreateTemporaryDirectoryAfterCheckFileSystemExtension",
		FileSystemInternalClient, Context);
	AttachFileOperationsExtension(Notification, 
		NStr("en = 'To create a temporary folder, install 1C:Enterprise Extension.';"), False);
	
EndProcedure

// Suggests the user to install the extension to work with 1C:Enterprise in the web client.
// The function to be incorporated in the beginning of code areas that process files.
//
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - the description of the procedure to be called once a form
//          is closed. Parameters:
//    -- 
//    -- 
//  SuggestionText - String - the message text. If the text is not specified, the default text is displayed.
//  CanContinueWithoutInstalling - Boolean - If True, displays the ContinueWithoutInstalling button.
//          If False, displays the Cancel button.
//
// Example:
//
//  Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//  MessageText = NStr("en = 'To print the document, install the system extension to work with 1C:Enterprise.'");
//  FileSystemClient.AttachFileOperationsExtension(Notification, MessageText);
//
//  Procedure PrintDocumentCompletion(ExtensionAttached, AdditionalParameters) Export
//    If ExtensionAttached Then
//     // Script that print a document only if the file system extension is attached.
//     // …
//    Else
//     // Script that print a document if the file system extension is not attached.
//     // …
//    EndIf;
//
Procedure AttachFileOperationsExtension(
		OnCloseNotifyDescription, 
		SuggestionText = "",
		CanContinueWithoutInstalling = True) Export
	
	NotifyDescriptionCompletion = New NotifyDescription(
		"StartFileSystemExtensionAttachingWhenAnsweringToInstallationQuestion", FileSystemInternalClient,
		OnCloseNotifyDescription);
	
#If Not WebClient Then
	// In thin, thick, and web clients, the extension is always attached.
	ExecuteNotifyProcessing(NotifyDescriptionCompletion, "AttachmentNotRequired");
	Return;
#EndIf
	
	Context = New Structure;
	Context.Insert("NotifyDescriptionCompletion", NotifyDescriptionCompletion);
	Context.Insert("SuggestionText",             SuggestionText);
	Context.Insert("CanContinueWithoutInstalling", CanContinueWithoutInstalling);
	
	Notification = New NotifyDescription(
		"StartFileSystemExtensionAttachingOnSetExtension", FileSystemInternalClient, Context);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

// Generates a unique file name in the specified folder and adds a sequence number to the name if needed.
// For example: "file (2).txt", "file (3).txt", and so on.
//
// Parameters:
//   FileName - String - a full name of the file and folder. For example: "C:\Documents\file.txt".
//
// Returns:
//   String - 
//
Function UniqueFileName(Val FileName) Export
	
	Return FileSystemInternalClientServer.UniqueFileName(FileName);

EndFunction

#EndRegion

#EndRegion

#Region Private

// Initializes a parameter structure to interact with the file system.
//
// Parameters:
//  DialogMode - FileDialogMode - the run mode of generating file selection dialog. 
//
// Returns:
//  Structure:
//   * Dialog - FileDialog
//   * Interactively - Boolean
//   * SuggestionText - String
//
Function OperationContext(DialogMode)
	
	Context = New Structure();
	Context.Insert("Dialog", New FileDialog(DialogMode));
	Context.Insert("Interactively", True);
	Context.Insert("SuggestionText", "");
	
	Return Context;
	
EndFunction

// Places the selected files into a temporary storage.
// See FileSystemClient.ImportFile_ and FileSystemClient.ImportFiles
//
Procedure ShowPutFile(CompletionHandler, PutParameters)
	
	PutParameters.Insert("CompletionHandler", CompletionHandler);
	NotifyDescription = New NotifyDescription(
		"ShowPutFileOnAttachFileSystemExtension", FileSystemInternalClient, PutParameters);
	AttachFileOperationsExtension(NotifyDescription, PutParameters.SuggestionText);
	
EndProcedure

// Saves files from temporary storage to the file system.
// See FileSystemClient.SaveFile and FileSystemClient.SaveFiles
//
Procedure ShowDownloadFiles(CompletionHandler, FilesToSave, ReceivingParameters)
	
	ReceivingParameters.Insert("FilesToObtain",      FilesToSave);
	ReceivingParameters.Insert("CompletionHandler", CompletionHandler);
	
	NotifyDescription = New NotifyDescription(
		"ShowDownloadFilesOnAttachFileSystemExtension", FileSystemInternalClient, ReceivingParameters);
	AttachFileOperationsExtension(NotifyDescription, ReceivingParameters.SuggestionText);
	
EndProcedure

// Gets the path to save the file in the temporary files catalog.
//
// Parameters:
//  FileName - String - the name of the file with an extension or the file extension without the dot.
//
// Returns:
//  String - 
//
Function TempFileFullName(Val FileName)

#If WebClient Then
	
	Return ?(StrFind(FileName, ".") = 0, 
		Format(CommonClient.SessionDate(), "DF=yyyyMMddHHmmss") + "." + FileName, FileName);
	
#Else
	
	ExtensionPosition = StrFind(FileName, ".");
	If ExtensionPosition = 0 Then
		Return GetTempFileName(FileName);
	Else
		Return TempFilesDir() + FileName;
	EndIf;
	
#EndIf

EndFunction

// Trims the file name length based on the rule that the length of a full file path must be 260 characters maximum.
//
// Parameters:
//  FullFileName - String - a full file name with the path and extension.
//
Procedure ShortenFullFileNameToAllowedNTFSLength(FullFileName)
	
	AllowedNTFSLength = 260;
	FullFileNameLength = StrLen(FullFileName);
	
	If FullFileNameLength <= AllowedNTFSLength Then
		Return;
	EndIf;
	
	File = New File(FullFileName);
	
	ExtensionLength = StrLen(File.Extension);
	PathLength       = StrLen(File.Path);
	
	// Analyze the directory path length. 1 character is the minimum length of the directory name.
	If PathLength > AllowedNTFSLength - ExtensionLength - 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'File path is too long:
		|%1';"), FullFileName);
	EndIf;
	
	BaseName = Mid(File.BaseName, 1, AllowedNTFSLength - PathLength - ExtensionLength - 1);
	
	FullFileName = File.Path + BaseName + File.Extension;
	
EndProcedure

Procedure CheckIfTheLinuxProgramIsInstalled(ApplicationName, Notification)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Notification", Notification);
	TheLinuxProgramIsInstalledCompletion = New NotifyDescription("CheckTheLinuxProgramIsInstalledCompletion", 
		ThisObject, AdditionalParameters);
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.Insert("WaitForCompletion", True);
	ApplicationStartupParameters.Insert("GetOutputStream", True);
	ApplicationStartupParameters.Insert("GetErrorStream", True);
	ApplicationStartupParameters.Insert("Notification", TheLinuxProgramIsInstalledCompletion);
	
	StartApplication(StringFunctionsClientServer.SubstituteParametersToString(
		"dpkg -s '%1'", String(ApplicationName)), ApplicationStartupParameters);
	
EndProcedure

Procedure CheckTheLinuxProgramIsInstalledCompletion(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	TheResultOfTheProcedure = StrFind(Result.OutputStream, "Status: install ok installed") <> False;
	ExecuteNotifyProcessing(Parameters.Notification, TheResultOfTheProcedure);
	
EndProcedure

Procedure PrintFromTheApplicationByTheLinuxFileName(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result = False Then
		ShowMessageBox(, NStr("en = 'The ""Unoconv"" application installation is required';"));
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("PrintFromTheApplicationByTheLinuxFileNameRunningUnoconv", 
		ThisObject, Parameters);
	GetTheFullNameOfTheTemporaryFile(NotifyDescription);
		
EndProcedure

Procedure PrintFromTheApplicationByTheLinuxFileNameRunningUnoconv(TempFileName, Parameters) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("TheFileOfTheConvertedData", TempFileName);
	
	NotifyDescription = New NotifyDescription("PrintFromTheApplicationByTheLinuxFileNameRunningLpr", 
		ThisObject, AdditionalParameters);
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.Insert("WaitForCompletion", True);
	ApplicationStartupParameters.Insert("GetErrorStream", True);
	ApplicationStartupParameters.Insert("Notification", NotifyDescription);
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString("unoconv --stdout '%1' >""%2""",
		Parameters.FileToOpenName, TempFileName);
	StartApplication(CommandString, ApplicationStartupParameters);
	
EndProcedure

Procedure PrintFromTheApplicationByTheLinuxFileNameRunningLpr(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Not Result.ApplicationStarted Then
		ShowMessageBox(, Result.ErrorDescription);
	Else
		
		Parameters.Insert("ErrorDescription", Result.ErrorDescription);
		
		NotifyDescription = New NotifyDescription("PrintFromTheApplicationByTheLinuxFileNameCompletion", ThisObject, Parameters);
		ApplicationStartupParameters = ApplicationStartupParameters();
		ApplicationStartupParameters.Insert("WaitForCompletion", True);
		ApplicationStartupParameters.Insert("GetErrorStream", True);
		ApplicationStartupParameters.Insert("Notification", NotifyDescription);
		
		StartApplication(
			StringFunctionsClientServer.SubstituteParametersToString("lpr %1", Parameters.TheFileOfTheConvertedData), 
			ApplicationStartupParameters);
		
	EndIf;
	
EndProcedure

Procedure PrintFromTheApplicationByTheLinuxFileNameCompletion(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	File = New File(Parameters.TheFileOfTheConvertedData);
	If File.Exists() Then// 
		DeleteFiles(Parameters.TheFileOfTheConvertedData);// 
	EndIf;
	
	If Not Result.ApplicationStarted Or ValueIsFilled(Result.ErrorDescription) Or ValueIsFilled(Result.ErrorStream) Then
		ShowMessageBox(, ?(ValueIsFilled(Result.ErrorDescription),Result.ErrorDescription + Chars.LF, "") + Result.ErrorStream);
	EndIf;
	
EndProcedure

#Region GetTheFullNameOfTheTemporaryFile

// Getting the name of the temporary file.
//
// Parameters:
//  Notification - NotifyDescription - notification of the receipt result with the following parameters.
//    -- 
//    -- 
//  Extension - String - the extension of the temporary file.
//
Procedure GetTheFullNameOfTheTemporaryFile(Val Notification, Extension = "")
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Extension", Extension);
	
	Notification = New NotifyDescription("GetTheNameOfATemporaryFileAfterCheckingTheFileExtension",
		ThisObject, Context);
	AttachFileOperationsExtension(Notification, 
		NStr("en = 'To get a temporary file name, install 1C:Enterprise Extension.';"), False);
	
EndProcedure

// The continuation of the procedure will receive the full timefile.
// 
// Parameters:
//  ExtensionAttached - Boolean
//  Context - Structure:
//   * Notification - NotifyDescription
//   * Extension - String
//
Procedure GetTheNameOfATemporaryFileAfterCheckingTheFileExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
#If WebClient Then
		Notification = New NotifyDescription(
			"GetTheNameOfTheTemporaryFileAfterGettingTheTemporaryDirectory", ThisObject, Context,
			"GetTheNameOfATemporaryFileWhenProcessingAnError", ThisObject);
		BeginGettingTempFilesDir(Notification);
#Else
		GetTheNameOfTheTemporaryFileAfterGettingTheTemporaryDirectory("", Context);
#EndIf
	Else
		GetTheNameOfTheTemporaryFileNotifyAboutTheError(NStr("en = 'Cannot install 1C:Enterprise Extension.';"), Context);
	EndIf;
	
EndProcedure

// The continuation of the procedure will receive the full timefile.
// 
// Parameters:
//  TempFilesDirName - String
//  Context - Structure:
//   * Notification - NotifyDescription
//   * Extension - String
//
Procedure GetTheNameOfTheTemporaryFileAfterGettingTheTemporaryDirectory(TempFilesDirName, Context) Export
	
	Notification = Context.Notification;
	Extension = Context.Extension;
	
#If WebClient Then
	TempFileName = TempFilesDirName + String(New UUID);
#Else
	TempFileName = GetTempFileName(Extension); // 
#EndIf
	
	If Not IsBlankString(Extension) Then 
		TempFileName = TempFileName + "." + Extension;
	EndIf;
	
	ExecuteNotifyProcessing(Notification, TempFileName);
	
EndProcedure

// The continuation of the procedure will receive the full timefile.
Procedure GetTheNameOfATemporaryFileWhenProcessingAnError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	GetTheNameOfTheTemporaryFileNotifyAboutTheError(ErrorDescription, Context);
	
EndProcedure

// The continuation of the procedure will receive the full timefile.
Procedure GetTheNameOfTheTemporaryFileNotifyAboutTheError(ErrorDescription, Context)
	
	ShowMessageBox(, ErrorDescription);
	TempFileName = "";
	ExecuteNotifyProcessing(Context.Notification, TempFileName);
	
EndProcedure

#EndRegion

#EndRegion