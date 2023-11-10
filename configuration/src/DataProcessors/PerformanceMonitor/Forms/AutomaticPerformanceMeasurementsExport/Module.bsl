///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var ExternalResourcesAllowed;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not PerformanceMonitorInternal.SubsystemExists("StandardSubsystems.Core") Then
        Items.LocalExportDirectory.ChoiceButton = False;
		SSLAvailable = False;
	Else
		SSLAvailable = True;
		SecurityProfilesAvailable = PerformanceMonitorInternal.SubsystemExists("StandardSubsystems.SecurityProfiles");
	EndIf;
	
	ConstantsSet.RunPerformanceMeasurements = Constants.RunPerformanceMeasurements.Get();
	ConstantsSet.LastPerformanceMeasurementsExportDateUTC = Constants.LastPerformanceMeasurementsExportDateUTC.Get();
		
	ConstantsSet.PerformanceMonitorRecordPeriod = PerformanceMonitor.RecordPeriod();
	ConstantsSet.MeasurementsCountInExportPackage = Constants.MeasurementsCountInExportPackage.Get();
	ConstantsSet.KeepMeasurementsPeriod = Constants.KeepMeasurementsPeriod.Get();
	
	DirectoriesForExport = PerformanceMonitorInternal.PerformanceMonitorDataExportDirectories();
	If TypeOf(DirectoriesForExport) <> Type("Structure")
		Or DirectoriesForExport.Count() = 0 Then
		Return;
	EndIf;
	
	DoExportToFTPDirectory = DirectoriesForExport.DoExportToFTPDirectory;
	FTPExportDirectory = DirectoriesForExport.FTPExportDirectory;
	DoExportToLocalDirectory = DirectoriesForExport.DoExportToLocalDirectory;
	LocalExportDirectory = DirectoriesForExport.LocalExportDirectory;
	
	DoExport = DoExportToFTPDirectory Or DoExportToLocalDirectory;
	
EndProcedure

&AtClient
Procedure DoExportOnChange(Item)
	
	ExportAllowed = DoExport;
	DoExportToLocalDirectory = ExportAllowed;
	DoExportToFTPDirectory = ExportAllowed;
	
	Modified = True;
	
EndProcedure	

&AtClient
Procedure DoExportToDirectoryOnChange(Item)
	
	DoExport = DoExportToLocalDirectory Or DoExportToFTPDirectory;
	Modified = True;
	
EndProcedure	

&AtClient
Procedure ExportLocalFileDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If SSLAvailable Then
		NotifyDescription = New NotifyDescription("SelectExportDirectorySuggested", ThisObject);
		ModuleFileSystemClient = Eval("FileSystemClient");
		If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
			ModuleFileSystemClient.AttachFileOperationsExtension(NotifyDescription);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function FillCheckProcessingAtServer()
	ItemsOnControl = New Map;
	ItemsOnControl.Insert(Items.DoExportToLocalDirectory, Items.LocalExportDirectory);
	ItemsOnControl.Insert(Items.DoExportToFTPDirectory, Items.FTPExportDirectory);
	
	NoErrors = True;	
	For Each PathFlag In ItemsOnControl Do
		ExecuteJob = ThisObject[PathFlag.Key.DataPath];
		PathItem = PathFlag.Value;
		If ExecuteJob And IsBlankString(TrimAll(ThisObject[PathItem.DataPath])) Then
			TheMessageText = NStr("en = 'Field %1 is required';");
			TheMessageText = StrReplace(TheMessageText, "%1", PathItem.Title);
			PerformanceMonitorInternal.MessageToUser(
				TheMessageText,
				,
				PathItem.Name,
				PathItem.DataPath);
			NoErrors = False;
		EndIf;
	EndDo;
	
	Return NoErrors;	
EndFunction

&AtServer
Procedure SaveAtServer()
	
	ExecuteLocalDirectory = New Array;
	ExecuteLocalDirectory.Add(DoExportToLocalDirectory);
	ExecuteLocalDirectory.Add(TrimAll(LocalExportDirectory));
	
	ExecuteFTPDirectory = New Array;
	ExecuteFTPDirectory.Add(DoExportToFTPDirectory);
	ExecuteFTPDirectory.Add(TrimAll(FTPExportDirectory));
	
	SetExportDirectory(ExecuteLocalDirectory, ExecuteFTPDirectory);  

	SetScheduledJobUsage(DoExport);
	
	Constants.RunPerformanceMeasurements.Set(ConstantsSet.RunPerformanceMeasurements);
	Constants.PerformanceMonitorRecordPeriod.Set(ConstantsSet.PerformanceMonitorRecordPeriod);
	Constants.MeasurementsCountInExportPackage.Set(ConstantsSet.MeasurementsCountInExportPackage);
	Constants.KeepMeasurementsPeriod.Set(ConstantsSet.KeepMeasurementsPeriod);
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure LocalExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	Modified = True;
	
EndProcedure

&AtClient
Procedure FTPExportDirectoryOnChange(Item)
	
	ExternalResourcesAllowed = False;
	Modified = True;
	
EndProcedure

///////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure SetExportSchedule(Command)
	
	JobSchedule = PerformanceMonitorDataExportSchedule();
	
	Notification = New NotifyDescription("SetExportScheduleCompletion", ThisObject);
	Dialog = New ScheduledJobDialog(JobSchedule);
	Dialog.Show(Notification);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectExportDirectorySuggested(FileSystemExtensionAttached1, AdditionalParameters) Export
	
	If FileSystemExtensionAttached1 Then
		
		SelectingFile = New FileDialog(FileDialogMode.ChooseDirectory);
		SelectingFile.Multiselect = False;
		SelectingFile.Title = NStr("en = 'Select an export directory';");
		
		NotifyDescription = New NotifyDescription("DirectorySelectionDialogBoxCompletion", ThisObject, Undefined);
		If SSLAvailable Then 
			ModuleFileSystemClient = Eval("FileSystemClient");
			If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
				ModuleFileSystemClient.ShowSelectionDialog(NotifyDescription, SelectingFile);
			EndIf;
		Else
			SelectingFile.Show(NotifyDescription);
		EndIf;
		
	EndIf;
	
EndProcedure

// Changes the directory for exporting data.
//
// Parameters:
//  ExportDirectory - String - new export directory.
//
&AtServerNoContext
Procedure SetExportDirectory(ExecuteLocalExportDirectory, ExecuteFTPExportDirectory)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	
	Directories = New Structure();
	Directories.Insert(PerformanceMonitorClientServer.LocalExportDirectoryJobKey(), ExecuteLocalExportDirectory);
	Directories.Insert(PerformanceMonitorClientServer.FTPExportDirectoryJobKey(), ExecuteFTPExportDirectory);
	
	JobParameters = New Array;	
	JobParameters.Add(Directories);
	Job.Parameters = JobParameters;
	CommitScheduledJob(Job);
	
EndProcedure

// Enables or disables a scheduled job.
//
// Parameters:
//  NewValue - Boolean - new value.
//
// Returns:
//  Boolean - 
//
&AtServerNoContext
Function SetScheduledJobUsage(NewValue)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	CurrentState = Job.Use;
	If CurrentState <> NewValue Then
		Job.Use = NewValue;
		CommitScheduledJob(Job);
	EndIf;
	
	Return CurrentState;
	
EndFunction

// Returns the current schedule for a scheduled job.
//
// Returns:
//  JobSchedule - 
//
&AtServerNoContext
Function PerformanceMonitorDataExportSchedule()
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	Return Job.Schedule;
	
EndFunction

// Sets a new schedule for a scheduled job.
//
// Parameters:
//  NewSchedule - JobSchedule - which is to be set.
//
&AtServerNoContext
Procedure SetSchedule(Val NewSchedule)
	
	Job = PerformanceMonitorInternal.PerformanceMonitorDataExportScheduledJob();
	Job.Schedule = NewSchedule;
	CommitScheduledJob(Job);
	
EndProcedure

// Saves scheduled job settings.
//
// Parameters:
//  Job - MetadataObjectScheduledJob
//
&AtServerNoContext
Procedure CommitScheduledJob(Job)
	
	SetPrivilegedMode(True);
	Job.Write();
	
EndProcedure

&AtClient
Procedure SetExportScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetSchedule(Schedule);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShouldSaveSettings(Command)
	
	If FillCheckProcessingAtServer() Then
		ValidatePermissionToAccessExternalResources(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveClose(Command)
	
	If FillCheckProcessingAtServer() Then
		ValidatePermissionToAccessExternalResources(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidatePermissionToAccessExternalResources(CloseForm)
	
	If ExternalResourcesAllowed <> True Then
		If CloseForm Then
			ClosingNotification1 = New NotifyDescription("AllowExternalResourceSaveAndClose", ThisObject);
		Else
			ClosingNotification1 = New NotifyDescription("AllowExternalResourceSave", ThisObject);
		EndIf;
		
		If SecurityProfilesAvailable Then
			
			Directories = New Structure;
			Directories.Insert("DoExportToFTPDirectory", DoExportToFTPDirectory);
			
			URIStructure = PerformanceMonitorClientServer.URIStructure(FTPExportDirectory);
			Directories.Insert("FTPExportDirectory", URIStructure.ServerName);
			If ValueIsFilled(URIStructure.Port) Then
				Directories.Insert("FTPExportDirectoryPort", URIStructure.Port);
			EndIf;
			
			Directories.Insert("DoExportToLocalDirectory", DoExportToLocalDirectory);
			Directories.Insert("LocalExportDirectory", LocalExportDirectory);
			
			Query = RequestToUseExternalResources(Directories);
			
			QueryToArray = New Array;
			QueryToArray.Add(Query);
		
			ModuleSafeModeManagerClient = Eval("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(QueryToArray, ThisObject, ClosingNotification1);
		Else
			ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
		EndIf;
	ElsIf CloseForm Then
		SaveAtServer();
		Close();
	Else
		SaveAtServer();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function RequestToUseExternalResources(Directories)
	
	Return PerformanceMonitorInternal.RequestToUseExternalResources(Directories);
	
EndFunction

&AtClient
Procedure AllowExternalResourceSaveAndClose(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveAtServer();
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceSave(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		SaveAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ConstantsSetPerformanceMonitorRecordPeriodOnChange(Item)
	Modified = True;
	If ConstantsSet.PerformanceMonitorRecordPeriod < 60 Then
		ConstantsSet.PerformanceMonitorRecordPeriod = 60;
	EndIf;
EndProcedure

&AtClient
Procedure ConstantsSetMeasurementsCountInExportPackageOnChange(Item)
	Modified = True;
EndProcedure

&AtClient
Procedure ConstantsSetKeepMeasurementsPeriodOnChange(Item)
	Modified = True;
EndProcedure

&AtClient
Procedure DirectorySelectionDialogBoxCompletion(SelectedFiles, AdditionalParameters) Export
    
    If SelectedFiles <> Undefined Then
		SelectedDirectory = SelectedFiles[0];
		LocalExportDirectory = SelectedDirectory;
		Modified = True;
	EndIf;
		
EndProcedure

#EndRegion
