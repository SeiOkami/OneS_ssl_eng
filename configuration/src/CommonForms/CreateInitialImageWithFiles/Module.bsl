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
	
	NodeMetadata = Parameters.Node.Metadata(); // MetadataObjectExchangePlan
	Manager = ExchangePlans[NodeMetadata.Name];
	
	If Parameters.Node = Manager.ThisNode() Then
		Raise
			NStr("en = 'Cannot create an initial image for this node.';");
	Else
		InfobaseKind = 0; // File infobase.
		DBMSType = "";
		Node = Parameters.Node;
		CanCreateFileInfobase = True;
		If Common.IsLinuxServer() Then
			CanCreateFileInfobase = False;
		EndIf;
		
		LocaleCodes = GetAvailableLocaleCodes();
		FileModeInfobaseLanguage = Items.Find("FileModeInfobaseLanguage");
		ClientServerModeInfobaseLanguage = Items.Find("ClientServerModeInfobaseLanguage");
		
		FileInfobaseLanguages = FileModeInfobaseLanguage.ChoiceList; // ValueList
		ServerBaseLanguages = ClientServerModeInfobaseLanguage.ChoiceList; // ValueList
		For Each Code In LocaleCodes Do
			Presentation = LocaleCodePresentation(Code);
			FileInfobaseLanguages.Add(Code, Presentation);
			ServerBaseLanguages.Add(Code, Presentation);
		EndDo;
		
		Language = InfoBaseLocaleCode();
		
	EndIf;
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = FilesOperationsInternal.HasFilesInVolumes();
	EndIf;
	
	WindowsOSServers = Common.IsWindowsServer();
	If Common.FileInfobase() Then
		Items.FileInfobaseFullNameLinux.Visible = Not WindowsOSServers;
		Items.FullFileInfobaseName.Visible = WindowsOSServers;
	EndIf;
	
	If HasFilesInVolumes Then
		If WindowsOSServers Then
			Items.FullFileInfobaseName.AutoMarkIncomplete = True;
			Items.VolumesFilesArchivePath.AutoMarkIncomplete = True;
		Else
			Items.FileInfobaseFullNameLinux.AutoMarkIncomplete = True;
			Items.PathToVolumeFilesArchiveLinux.AutoMarkIncomplete = True;
		EndIf;
	Else
		Items.PathToVolumeFilesArchiveGroup.Visible = False;
	EndIf;
	
	If Not Common.FileInfobase() Then
		Items.VolumesFilesArchivePath.InputHint = NStr("en = '\\server name\resource\files.zip';");
		Items.VolumesFilesArchivePath.ChoiceButton = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.FormPages.CurrentPage = Items.RawData;
	Items.CreateInitialImage.Visible = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InfobaseTypeOnChange(Item)
	
	// Switch the parameters page.
	Pages = Items.Find("Pages");
	Pages.CurrentPage = Pages.ChildItems[InfobaseKind];
	
	If InfobaseKind = 0 Then
		Items.VolumesFilesArchivePath.InputHint = "";
		Items.VolumesFilesArchivePath.ChoiceButton = True;
	Else
		Items.VolumesFilesArchivePath.InputHint = NStr("en = '\\server name\resource\files.zip';");
		Items.VolumesFilesArchivePath.ChoiceButton = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure VolumesFilesArchivePathStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		Item,
		"WindowsVolumesFilesArchivePath",
		StandardProcessing,
		"files.zip",
		"Archives zip(*.zip)|*.zip");
	
EndProcedure

&AtClient
Procedure FullFileInfobaseNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		Item,
		"FullWindowsFileInfobaseName",
		StandardProcessing,
		"1Cv8.1CD",
		"Any file(*.*)|*.*");
	
EndProcedure

&AtClient
Procedure FullFileInfobaseNameOnChange(Item)
	
	If IsBlankString(FullWindowsFileInfobaseName) Then
		Return;
	EndIf;
	
	ErrorMessage = "";
	If Not FullFileInfobaseNameCheckAtServer(FullWindowsFileInfobaseName, ErrorMessage) Then
		FullWindowsFileInfobaseName = "";
		If Not IsBlankString(ErrorMessage) Then
			ShowMessageBox(, ErrorMessage);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DBMSTypeOnChange(Item)
	
	DateOffset = ?(DBMSType = "MSSQLServer", 2000, 0);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateInitialImage(Command)
	
	ClearMessages();
	If InfobaseKind = 0 And Not CanCreateFileInfobase Then
		
		Raise
			NStr("en = 'Creation of initial images for file infobases
			           |is not supported on this platform.';");
	Else
		ProgressPercent = 0;
		ProgressAdditionalInformation = "";
		JobParameters = New Structure;
		JobParameters.Insert("Node", Node);
		JobParameters.Insert("WindowsVolumesFilesArchivePath", WindowsVolumesFilesArchivePath);
		JobParameters.Insert("PathToVolumeFilesArchiveLinux", PathToVolumeFilesArchiveLinux);
		
		If InfobaseKind = 0 Then
			// 
			JobParameters.Insert("FormUniqueID", UUID);
			JobParameters.Insert("Language", Language);
			JobParameters.Insert("FullWindowsFileInfobaseName", FullWindowsFileInfobaseName);
			JobParameters.Insert("FileInfobaseFullNameLinux", FileInfobaseFullNameLinux);
			JobParameters.Insert("JobDescription", NStr("en = 'Create initial file image';"));
			JobParameters.Insert("ProcedureDescription", "FilesOperationsInternal.CreateFileInitialImageAtServer");
		Else
			// Server initial image.
			ConnectionString =
				"Srvr="""       + Server + """;"
				+ ?(ValueIsFilled(ClusterAdministratorName), "SUsr=""" + ClusterAdministratorName + """;", "")
				+ ?(ValueIsFilled(ClusterAdministratorPassword), "SPwd=""" + ClusterAdministratorPassword + """;", "")
				+ "Ref="""      + BaseName + """;"
				+ "DBMS="""     + DBMSType + """;"
				+ "DBSrvr="""   + DataBaseServer + """;"
				+ "DB="""       + DataBaseName + """;"
				+ "DBUID="""    + DatabaseUser + """;"
				+ "DBPwd="""    + UserPassword + """;"
				+ "SQLYOffs=""" + Format(DateOffset, "NG=") + """;"
				+ "Locale="""   + Language + """;"
				+ "SchJobDn=""" + ?(SetScheduledJobLock, "Y", "N") + """;";
			
			JobParameters.Insert("ConnectionString", ConnectionString);
			JobParameters.Insert("JobDescription", NStr("en = 'Create initial server image';"));
			JobParameters.Insert("ProcedureDescription", "FilesOperationsInternal.CreateServerInitialImageAtServer");
		EndIf;
		Result = PrepareDataToCreateInitialImage(JobParameters, InfobaseKind);
		If TypeOf(Result) = Type("Structure") Then
			If Result.DataReady Then
				JobParametersAddress = PutToTempStorage(JobParameters, UUID);
				NotifyDescription = New NotifyDescription("RunCreateInitialImage", ThisObject);
				If Result.ConfirmationRequired Then
					ShowQueryBox(NotifyDescription, Result.QueryText, QuestionDialogMode.YesNo);
				Else
					ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.Yes);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.StatusError.Visible = False;
	Items.Back.Visible = False;
	
	Items.StatusDone.Visible = True;
	Items.CreateInitialImage.Visible = True;
	Items.FormPages.CurrentPage = Items.RawData;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function FullFileInfobaseNameCheckAtServer(FullFileInfobaseName, ErrorMessage = "")
	
	FullFileInfobaseName = TrimAll(FullFileInfobaseName);
	
	PathStructure = CommonClientServer.ParseFullFileName(FullFileInfobaseName);
	If Not IsBlankString(PathStructure.Path) Then
		PathToFile = PathStructure.Path;
		
		If IsBlankString(PathStructure.Extension) Then
			PathToFile = PathStructure.FullName; 
			FullFileInfobaseName = CommonClientServer.GetFullFileName(PathStructure.FullName, "1Cv8.1CD");
		EndIf;
		
		If FindFiles(PathToFile).Count() = 0 Then
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Folder ""%1"" does not exist or is unavailable.
				|Make sure that the path is correct.';"),
				PathToFile);
			Return False;
		EndIf;
	Else
		ErrorMessage = NStr("en = 'Please specify the full infobase path.';");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure SaveFileHandler(
		Item,
		PropertyName,
		StandardProcessing,
		FileName,
		Filter = "")
	
	StandardProcessing = False;
	
	Context = New Structure;
	Context.Insert("Item",     Item);
	Context.Insert("PropertyName", PropertyName);
	Context.Insert("FileName",    FileName);
	Context.Insert("Filter",      Filter);
	
	Dialog = New FileDialog(FileDialogMode.Save);
	
	Dialog.Title = NStr("en = 'Select file to save';");
	Dialog.Multiselect = False;
	Dialog.Preview = False;
	Dialog.Filter = Context.Filter;
	Dialog.FullFileName =
		?(ThisObject[Context.PropertyName] = "",
			Context.FileName,
			ThisObject[Context.PropertyName]);
	
	ChoiceDialogNotificationDetails = New NotifyDescription(
		"FileSaveHandlerAfterChoiceInDialog", ThisObject, Context);
	FileSystemClient.ShowSelectionDialog(ChoiceDialogNotificationDetails, Dialog);
	
EndProcedure

// Parameters:
//   SelectedFiles - Array
//                  - Undefined
//   Context - Structure
//
&AtClient
Procedure FileSaveHandlerAfterChoiceInDialog(SelectedFiles, Context) Export
	
	If SelectedFiles <> Undefined
		And SelectedFiles.Count() = 1 Then
		
		ThisObject[Context.PropertyName] = SelectedFiles[0];
		If Context.Item = Items.FullFileInfobaseName Then
			FullFileInfobaseNameOnChange(Context.Item);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PrepareDataToCreateInitialImage(JobParameters, InfobaseKind)
	
	// Writing the parameters of attaching node to constant.
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		Cancel = False;
		
		DataExchangeCreationWizard = DataProcessors["DataExchangeCreationWizard"].Create();
		DataExchangeCreationWizard.Initialization(JobParameters.Node);
		
		Try
			DataProcessors["DataExchangeCreationWizard"].ExportConnectionSettingsForSubordinateDIBNode(
				DataExchangeCreationWizard);
		Except
			Cancel = True;
			WriteLogEvent(NStr("en = 'Data exchange';", Common.DefaultLanguageCode()),
				EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If Cancel Then
			Return Undefined;
		EndIf;
		
	EndIf;
	
	If InfobaseKind = 0 Then
		// 
		// 
		Result = FilesOperationsInternal.PrepareDataToCreateFileInitialImage(JobParameters);
	Else
		// 
		// 
		Result = FilesOperationsInternal.PrepareDataToCreateServerInitialImage(JobParameters);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure RunCreateInitialImage(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		ProgressPercent = 0;
		ProgressAdditionalInformation = "";
		GoToWaitPage();
		AttachIdleHandler("StartInitialImageCreation", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartInitialImageCreation()
	
	Result = CreateInitialImageAtServer(InfobaseKind);
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Running" Then
		CompletionNotification2 = New NotifyDescription("CreateInitialImageAtServerCompletion", ThisObject);
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.OutputProgressBar = True;
		IdleParameters.ExecutionProgressNotification = New NotifyDescription("CreateInitialImageAtServerProgress", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(Result, CompletionNotification2, IdleParameters);
	ElsIf Result.Status = "Completed2" Then
		GoToWaitPage();
		ProgressPercent = 100;
		ProgressAdditionalInformation = "";
		// Go to the page with the result with a 1 sec delay.
		AttachIdleHandler("ExecuteGoResult", 1, True);
	Else
		ProgressPercent = 0;
		Items.StatusError.Title = NStr("en = 'Cannot create an initial image. Reason:';") + "
			|" + Result.BriefErrorDescription;
		ExecuteGoResult();
	EndIf;

EndProcedure

&AtClient
Procedure GoToWaitPage()
	Items.FormPages.CurrentPage = Items.InitialImageCreationWaiting;
	Items.CreateInitialImage.Visible = False;
EndProcedure

&AtServer
Function CreateInitialImageAtServer(Val Action)
	
	If IsTempStorageURL(JobParametersAddress) Then
		JobParameters = GetFromTempStorage(JobParametersAddress);
		If TypeOf(JobParameters) = Type("Structure") Then
			// Start background job.
			ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
			ExecutionParameters.BackgroundJobDescription = JobParameters.JobDescription;
			
			Return TimeConsumingOperations.ExecuteInBackground(JobParameters.ProcedureDescription, JobParameters, ExecutionParameters);
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure CreateInitialImageAtServerCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		ProgressPercent = 0;
		ProgressAdditionalInformation = NStr("en = 'The operation is canceled by administrator.';");
		ExecuteGoResult();
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		ProgressPercent = 0;
		Items.StatusError.Title = NStr("en = 'Cannot create an initial image. Reason:';") + "
			|" + Result.BriefErrorDescription;
		ExecuteGoResult();
		Return;
	EndIf;
	
	ProgressPercent = 100;
	ProgressAdditionalInformation = "";
	ExecuteGoResult();
	
EndProcedure

&AtClient
Procedure CreateInitialImageAtServerProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ProgressStructure = Progress.Progress;
		ProgressPercent = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoResult()
	Items.FormPages.CurrentPage = Items.Result;
	Items.CreateInitialImage.Visible = False;
	
	If ProgressPercent = 100 Then
		CompleteInitialImageCreation(Node);
	Else
		Items.StatusDone.Visible = False;
		Items.StatusError.Visible = True;
		Items.Back.Visible = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CompleteInitialImageCreation(ExchangeNode)
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CompleteInitialImageCreation(ExchangeNode);
	EndIf;
	
EndProcedure

#EndRegion
