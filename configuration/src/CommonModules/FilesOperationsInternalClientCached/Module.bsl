///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Returns PutInUserWorkingDirectory session parameter.
Function UserWorkingDirectory() Export
	
	ParameterName = "StandardSubsystems.WorkingDirectoryAccessCheckExecuted";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, False);
	EndIf;
	
	DirectoryName =
		StandardSubsystemsClient.ClientRunParameters().PersonalFilesOperationsSettings.PathToLocalFileCache;
	
	// Already specified.
	If DirectoryName <> Undefined
		And Not IsBlankString(DirectoryName)
		And ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] Then
		
		Return DirectoryName;
	EndIf;
	
	If DirectoryName = Undefined Then
		DirectoryName = FilesOperationsInternalClient.SelectPathToUserDataDirectory();
		If Not IsBlankString(DirectoryName) Then
			FilesOperationsInternalClient.SetUserWorkingDirectory(DirectoryName);
		Else
			ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] = True;
			Return ""; // Web client without file system extension
		EndIf;
	EndIf;
	
#If Not WebClient Then
	
	// Create a directory for files.
	Try
		// 
		// 
		InformationAboutTheCatalog = New File(DirectoryName);
		If Not InformationAboutTheCatalog.Exists() Then
			Raise NStr("en = 'Directory does not exist.';");
		EndIf;

		CreateDirectory(DirectoryName);
		TestDirectoryName = DirectoryName + "CheckAccess\";
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		// 
		// 
		EventLogMessage = NStr("en = 'Working directory %1 is not found or there is no save permission. Default settings are restored.';");
		EventLogMessage = StringFunctionsClientServer.SubstituteParametersToString(EventLogMessage, DirectoryName);
		DirectoryName = FilesOperationsInternalClient.SelectPathToUserDataDirectory();
		FilesOperationsInternalClient.SetUserWorkingDirectory(DirectoryName);
		
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'File management';", CommonClient.DefaultLanguageCode()),
			"Warning",
			EventLogMessage,
			CommonClient.SessionDate(),
			True);

	EndTry;
	
#EndIf
	
	ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] = True;
	
	Return DirectoryName;
	
EndFunction

Function IsDirectoryFiles(FilesOwner) Export
	
	Return FilesOperationsInternalServerCall.IsDirectoryFiles(FilesOwner);
	
EndFunction

#EndRegion
