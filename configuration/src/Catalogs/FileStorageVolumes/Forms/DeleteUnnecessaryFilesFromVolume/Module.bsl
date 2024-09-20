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
	
	FileStorageVolume = Parameters.FileStorageVolume;
	
	FillExcessFilesTable();
	UnnecessaryFilesCount = UnnecessaryFiles.Count();
	
	DateFolder = Format(CurrentSessionDate(), "DF=yyyyMMdd") + GetPathSeparator();
	
	CopyFilesBeforeDelete                = False;
	Items.PathToFolderToCopy.Enabled = False;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DetailsDecoration1Click(Item)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	ReportParameters.Insert("Filter", New Structure("Volume", FileStorageVolume));
	
	OpenForm("Report.VolumeIntegrityCheck.ObjectForm", ReportParameters);
	
EndProcedure

&AtClient
Procedure PathToFolderToCopyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Directory = PathToFolderToCopy;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = Title;
	
	Context = New Structure("OpenFileDialog", OpenFileDialog);
	
	ChoiceDialogNotificationDetails = New NotifyDescription(
		"PathToFolderToCopyStartChoiceCompletion", ThisObject, Context);
	FileSystemClient.ShowSelectionDialog(ChoiceDialogNotificationDetails, OpenFileDialog);
	
EndProcedure

&AtClient
Procedure PathToFolderToCopyStartChoiceCompletion(SelectedFiles, Context) Export
	
	OpenFileDialog = Context.OpenFileDialog;
	
	If SelectedFiles = Undefined Then
		Items.FormDeleteUnnecessaryFiles.Enabled = False;
	Else
		PathToFolderToCopy = OpenFileDialog.Directory;
		PathToFolderToCopy = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
		Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	EndIf;

EndProcedure

&AtClient
Procedure PathToFolderToCopyOnChange(Item)
	
	PathToFolderToCopy                     = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
	Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	
EndProcedure

&AtClient
Procedure CopyFilesBeforeDeleteOnChange(Item)
	
	If Not CopyFilesBeforeDelete Then
		PathToFolderToCopy                      = "";
		Items.PathToFolderToCopy.Enabled = False;
		Items.FormDeleteUnnecessaryFiles.Enabled  = True;
	Else
		Items.PathToFolderToCopy.Enabled = True;
		If ValueIsFilled(PathToFolderToCopy) Then
			Items.FormDeleteUnnecessaryFiles.Enabled = True;
		Else
			Items.FormDeleteUnnecessaryFiles.Enabled = False;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteUnnecessaryFiles(Command)
	
	If UnnecessaryFilesCount = 0 Then
		ShowMessageBox(, NStr("en = 'No extraneous files in the network directory';"));
		Return;
	EndIf;
	
	FileSystemClient.AttachFileOperationsExtension(
		New NotifyDescription("AttachFileSystemExtensionCompletion", ThisObject),, 
		False);
	
EndProcedure

&AtClient
Procedure AttachFileSystemExtensionCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		ShowMessageBox(, NStr("en = 'Cannot perform the action because 1C:Enterprise Extension is not installed.';"));
		Return;
	EndIf;
	
	If Not CopyFilesBeforeDelete Then
		AfterCheckWriteToDirectory(True, New Structure);
	Else
		FolderForCopying = New File(PathToFolderToCopy);
		FolderForCopying.BeginCheckingExistence(New NotifyDescription("FolderExistanceCheckCompletion", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure FolderExistanceCheckCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		ShowMessageBox(, NStr("en = 'The specified folder does not exist.';"));
	Else
		RightToWriteToDirectory(New NotifyDescription("AfterCheckWriteToDirectory", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCheckWriteToDirectory(Result, AdditionalParameters) Export
	
	If Not Result Then
		Return;
	EndIf;
	
	If UnnecessaryFiles.Count() = 0 Then
		Return;
	EndIf;
	
	FinalNotificationParameters = New Structure;
	FinalNotificationParameters.Insert("FilesArrayWithErrors", New Array);
	FinalNotificationParameters.Insert("NumberOfDeletedFiles",  0);
	FinalNotification = New NotifyDescription("AfterProcessFiles", ThisObject, FinalNotificationParameters);
	
	ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
		New Structure("FinalNotification, CurrentFile", FinalNotification, Undefined), "ProcessNextFileError", ThisObject));
	
EndProcedure

&AtClient
Procedure ProcessNextFile(Result, AdditionalParameters) Export
	
	CurrentFile       = AdditionalParameters.CurrentFile;
	LastIteration = False;
	
	If CurrentFile = Undefined Then
		CurrentFile = UnnecessaryFiles.Get(0);
	Else
		
		CurrentFileIndex = UnnecessaryFiles.IndexOf(CurrentFile);
		If CurrentFileIndex = UnnecessaryFiles.Count() - 1 Then
			LastIteration = True;
		Else
			CurrentFile = UnnecessaryFiles.Get(CurrentFileIndex + 1);
		EndIf;
		
	EndIf;
	
	CurrentFileFullName = CurrentFile.FullName;
	CurrentFileParameters = CurrentFileParameters(AdditionalParameters, LastIteration, CurrentFile);
	
	If Not IsBlankString(PathToFolderToCopy) Then
		
		File = New File(CurrentFileFullName);
		File.BeginCheckingExistence(New NotifyDescription("CheckFileExistEnd", ThisObject, CurrentFileParameters));
		
	Else
		
		DeleteAFileOnTheClient(CurrentFileFullName, CurrentFileParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteAFileOnTheClient(PathToFile, AdditionalParameters)
	Result = DeleteFile(PathToFile);
	If Result.Success Then
		ProcessNextFileDeletionEnd(AdditionalParameters);
	Else
		ProcessNextFileError(Result.ErrorInfo, True, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DeleteFile(PathToFile)
	Return FilesOperationsInVolumesInternal.DeleteFile(PathToFile);
EndFunction

// Returns:
//   Structure:
//   * DirectoryForCopying - String
//   * LastIteration - Boolean
//   * CurrentFile - File
//   * FinalNotification - NotifyDescription
//
&AtClient
Function CurrentFileParameters(AdditionalParameters, Val LastIteration, Val CurrentFile)
	DirectoryForCopying  = PathToFolderToCopy + DateFolder + GetPathSeparator();
	
	CurrentFileParameters = New Structure;
	CurrentFileParameters.Insert("FinalNotification",    AdditionalParameters.FinalNotification);
	CurrentFileParameters.Insert("CurrentFile",           CurrentFile);
	CurrentFileParameters.Insert("LastIteration",     LastIteration);
	CurrentFileParameters.Insert("DirectoryForCopying", DirectoryForCopying);
	Return CurrentFileParameters
EndFunction


&AtClient
Procedure CheckFileExistEnd(FileExists, AdditionalParameters) Export
	
	If Not FileExists Then
		ExecuteNotifyProcessing(AdditionalParameters.FinalNotification);
	Else
		CurrentDayDirectory = New File(AdditionalParameters.DirectoryForCopying);
		CurrentDayDirectory.BeginCheckingExistence(New NotifyDescription("DayDirectoryExistEnd", ThisObject, AdditionalParameters));
	EndIf;
	
EndProcedure

// Parameters:
//   DirectoryExist - Boolean
//   AdditionalParameters - See CurrentFileParameters
//
&AtClient
Procedure DayDirectoryExistEnd(DirectoryExist, AdditionalParameters) Export
	
	If Not DirectoryExist Then
		BeginCreatingDirectory(New NotifyDescription("CreateDayDirectoryEnd", ThisObject, AdditionalParameters), AdditionalParameters.DirectoryForCopying);
	Else
		FileTargetName = AdditionalParameters.DirectoryForCopying + AdditionalParameters.CurrentFile.Name;
		File = New File(FileTargetName);
		File.BeginCheckingExistence(New NotifyDescription("CheckTargetFileExistEnd", ThisObject, AdditionalParameters));
	EndIf;
	
EndProcedure

// Parameters:
//   DirectoryName - String
//   AdditionalParameters - See CurrentFileParameters
//
&AtClient
Procedure CreateDayDirectoryEnd(DirectoryName, AdditionalParameters) Export
	FileTargetName = AdditionalParameters.DirectoryForCopying + AdditionalParameters.CurrentFile.Name;
	File = New File(FileTargetName);
	File.BeginCheckingExistence(New NotifyDescription("CheckTargetFileExistEnd", ThisObject, AdditionalParameters));
	
EndProcedure

&AtClient
Procedure CheckTargetFileExistEnd(FileExists, AdditionalParameters) Export
	
	DirectoryForCopying  = AdditionalParameters.DirectoryForCopying;
	CurrentFileName       = AdditionalParameters.CurrentFile.Name;
	CurrentFileFullName = AdditionalParameters.CurrentFile.FullName;
	
	If Not FileExists Then
		FileTargetName = DirectoryForCopying + CurrentFileName;
	Else
		FileSeparatedName = StrSplit(CurrentFileName, ".");
		BaseName    = FileSeparatedName.Get(0);
		Extension          = FileSeparatedName.Get(1);
		FileTargetName    = DirectoryForCopying + BaseName + "_" + String(New UUID) + "." + Extension;
	EndIf;
		
	BeginMovingFile(New NotifyDescription("ProcessNextFileMoveEnd", ThisObject, AdditionalParameters,
		"ProcessNextFileError", ThisObject), CurrentFileFullName, FileTargetName);
	
EndProcedure

&AtClient
Procedure ProcessNextFileMoveEnd(Result, AdditionalParameters) Export
	
	ProcessNextFileCompletion(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ProcessNextFileDeletionEnd(AdditionalParameters)
	
	ProcessNextFileCompletion(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ProcessNextFileCompletion(AdditionalParameters)
	
	CurrentFile                  = AdditionalParameters.CurrentFile;
	FinalNotification           = AdditionalParameters.FinalNotification; // NotifyDescription
	FinalNotificationParameters = FinalNotification.AdditionalParameters;
	
	FinalNotificationParameters.Insert("NumberOfDeletedFiles", FinalNotificationParameters.NumberOfDeletedFiles + 1);
	
	If AdditionalParameters.LastIteration Then
		ExecuteNotifyProcessing(FinalNotification);
	Else
		ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
			New Structure("FinalNotification, CurrentFile", FinalNotification, CurrentFile), "ProcessNextFileError", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessNextFileError(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	
	CurrentFile      = AdditionalParameters.CurrentFile;
	CurrentFileName = CurrentFile.Name;
	
	FinalNotification           = AdditionalParameters.FinalNotification;  // NotifyDescription
	FinalNotificationParameters = FinalNotification.AdditionalParameters;
	
	ErrorStructure = ErrorStructure(CurrentFileName, ErrorInfo);
	
	FilesArrayWithErrors = FinalNotificationParameters.FilesArrayWithErrors; // Array
	FilesArrayWithErrors.Add(ErrorStructure);
	FinalNotificationParameters.Insert("FilesArrayWithErrors", FilesArrayWithErrors);
	
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		ProcessErrorMessage(CurrentFile.FullName, ErrorProcessing.DetailErrorDescription(ErrorInfo));
	Else
		ExplanationText = NStr("en = 'For detailed description of the error,
			|see the earlier event ""Files.Delete files from volume""';");
		ProcessErrorMessage(CurrentFile.FullName, ErrorInfo + Chars.LF + ExplanationText);
	EndIf;
	
	If AdditionalParameters.LastIteration Then
		ExecuteNotifyProcessing(FinalNotification);
	Else
		ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
			New Structure("FinalNotification, CurrentFile", FinalNotification, CurrentFile), "ProcessNextFileError", ThisObject));
	EndIf;
	
EndProcedure

// Returns:
//   Structure:
//   * Name - String
//   * Error - String
//
&AtClient
Function ErrorStructure(CurrentFileName, ErrorInfo)
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	Else
		ErrorText = ErrorInfo;
	EndIf;
	
	ErrorStructure = New Structure;
	ErrorStructure.Insert("Name", CurrentFileName);
	ErrorStructure.Insert("Error", ErrorText);
	Return ErrorStructure;
EndFunction

&AtClient
Procedure AfterProcessFiles(Result, AdditionalParameters) Export
	
	NumberOfDeletedFiles  = AdditionalParameters.NumberOfDeletedFiles;
	FilesArrayWithErrors = AdditionalParameters.FilesArrayWithErrors;// Array of See ErrorStructure
	
	If NumberOfDeletedFiles <> 0 Then
		NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Files deleted: %1';"),
			NumberOfDeletedFiles);
		ShowUserNotification(
			NStr("en = 'The extraneous files are deleted.';"),
			,
			NotificationText1,
			PictureLib.Information32);
	EndIf;
	
	If FilesArrayWithErrors.Count() > 0 Then
		ErrorsReport = New SpreadsheetDocument;
		GenerateErrorsReport(ErrorsReport, FilesArrayWithErrors);
		ErrorsReport.Show();
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillExcessFilesTable()
	
	FilesTableOnHardDrive = FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive();
	VolumePath = TrimAll(FilesOperationsInVolumesInternal.FullVolumePath(FileStorageVolume));
	
	FilesArray = FindFiles(VolumePath,"*", True);
	For Each File In FilesArray Do
		
		If Not File.IsFile() Then
			Continue;
		EndIf;
		
		NewRow = FilesTableOnHardDrive.Add();
		NewRow.Name              = File.Name;
		NewRow.BaseName = File.BaseName;
		NewRow.FullName        = File.FullName;
		NewRow.Path             = File.Path;
		NewRow.Extension       = File.Extension;
		NewRow.CheckStatus   = NStr("en = 'Extraneous files (files in the volume that are not registered in the application)';");
		NewRow.Count       = 1;
		NewRow.Volume              = FileStorageVolume;
		
	EndDo;
	
	FilesOperationsInVolumesInternal.FillInExtraFiles(FilesTableOnHardDrive, FileStorageVolume);
	FilesTableOnHardDrive.Indexes.Add("CheckStatus");
	ExcessFilesArray = FilesTableOnHardDrive.FindRows(
		New Structure("CheckStatus", NStr("en = 'Extraneous files (files in the volume that are not registered in the application)';")));
	
	For Each File In ExcessFilesArray Do
		NewRow = UnnecessaryFiles.Add();
		FillPropertyValues(NewRow, File);
	EndDo;
	
	UnnecessaryFiles.Sort("Name");
	
EndProcedure

&AtClient
Procedure RightToWriteToDirectory(SourceNotification)
	
	If IsBlankString(PathToFolderToCopy) Then
		ExecuteNotifyProcessing(SourceNotification, True);
		Return
	EndIf;
	
	DirectoryName = PathToFolderToCopy + "CheckAccess\";
	
	DirectoryDeletionParameters  = New Structure("SourceNotification, DirectoryName", SourceNotification, DirectoryName);
	DirectoryCreationNotification = New NotifyDescription("AfterCreateDirectory", ThisObject, DirectoryDeletionParameters, "AfterDirectoryCreationError", ThisObject);
	BeginCreatingDirectory(DirectoryCreationNotification, DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDirectoryCreationError(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInfo, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure AfterCreateDirectory(Result, AdditionalParameters) Export
	
	BeginDeletingFiles(New NotifyDescription("AfterDeleteDirectory", ThisObject, AdditionalParameters, "AfterDirectoryDeletionError", ThisObject), AdditionalParameters.DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDeleteDirectory(AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.SourceNotification, True);
	
EndProcedure

&AtClient
Procedure AfterDirectoryDeletionError(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInfo, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure ProcessAccessRightsError(ErrorInfo, SourceNotification)
	
	ErrorTemplate = NStr("en = 'Incorrect folder for copying.
		|An account on whose behalf 1C:Enterprise server is running
		|might have no access rights to the specified folder.
		|
		|%1';");
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
	CommonClient.MessageToUser(ErrorText, , , "PathToFolderToCopy");
	
	ExecuteNotifyProcessing(SourceNotification, False);
	
EndProcedure

&AtServer
Procedure ProcessErrorMessage(FileName, ErrorInfo)
	
	WriteLogEvent(NStr("en = 'Files.Extraneous files deletion error';", Common.DefaultLanguageCode()),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot delete file
				|""%1""
				|due to:
				|%2.';"),
			FileName,
			ErrorInfo));
		
EndProcedure

// Parameters:
//   ErrorsReport - SpreadsheetDocument
//   FilesArrayWithErrors - Array of See ErrorStructure
//
&AtServer
Procedure GenerateErrorsReport(ErrorsReport, FilesArrayWithErrors)
	
	TabTemplate = Catalogs.FileStorageVolumes.GetTemplate("ReportTemplate");
	
	HeaderArea_ = TabTemplate.GetArea("Title");
	HeaderArea_.Parameters.LongDesc = NStr("en = 'Files with errors:';");
	ErrorsReport.Put(HeaderArea_);
	
	AreaRow = TabTemplate.GetArea("String");
	
	For Each FileWithError In FilesArrayWithErrors Do
		AreaRow.Parameters.Name1 = FileWithError.Name;
		AreaRow.Parameters.Error = FileWithError.Error;
		ErrorsReport.Put(AreaRow);
	EndDo;
	
EndProcedure

#EndRegion