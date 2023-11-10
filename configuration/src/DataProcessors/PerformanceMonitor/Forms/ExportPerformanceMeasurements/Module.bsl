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
	If Not PerformanceMonitorInternal.SubsystemExists("StandardSubsystems.Core") Then
		Items.ExportDirectory.ChoiceButton = False;
		SSLAvailable = False;
	Else
		SSLAvailable = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectExportDirectorySuggested(FileSystemExtensionAttached1, AdditionalParameters) Export
	
	If FileSystemExtensionAttached1 Then
		
		SelectingFile = New FileDialog(FileDialogMode.ChooseDirectory);
		SelectingFile.Multiselect = False;
		SelectingFile.Title = NStr("en = 'Select export directory';");
		
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

&AtClient
Procedure ExportDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	If SSLAvailable Then
		NotifyDescription = New NotifyDescription("SelectExportDirectorySuggested", ThisObject);
		ModuleFileSystemClient = Eval("FileSystemClient");
		If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
			ModuleFileSystemClient.AttachFileOperationsExtension(NotifyDescription);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExportPerformanceTestFile(Command)
    
    HasErrors = False;
    
    If Not ValueIsFilled(ExportPeriodStartDate) Then
        
        UserMessage = New UserMessage;
        UserMessage.Field = "ExportPeriodStartDate";
        UserMessage.Text = NStr("en = 'Start date is required.
			|Cannot export.';");
        UserMessage.Message();
        
        HasErrors = True;
        
    EndIf;
    
    If Not ValueIsFilled(ExportPeriodEndDate) Then
        
        UserMessage = New UserMessage;
        UserMessage.Field = "ExportPeriodEndDate";
        UserMessage.Text = NStr("en = 'End date is required.
			|Cannot export.';");
        UserMessage.Message();
        
        HasErrors = True;
        
    EndIf;
    
    If Not ValueIsFilled(ExportDirectory) Then
        
        UserMessage = New UserMessage;
        UserMessage.Field = "ExportDirectory";
        UserMessage.Text = NStr("en = 'Export directory is required.
			|Cannot export.';");
        UserMessage.Message();
        
        HasErrors = True;
        
    EndIf;
    
     If Not ValueIsFilled(ArchiveName) Then
        
        UserMessage = New UserMessage;
        UserMessage.Field = "ArchiveName";
        UserMessage.Text = NStr("en = 'Archive name is required.
			|Cannot export.';");
        UserMessage.Message();
        
        HasErrors = True;
        
    EndIf;
        
    If ValueIsFilled(ExportPeriodStartDate) And ValueIsFilled(ExportPeriodEndDate) And ExportPeriodStartDate >= ExportPeriodEndDate Then
        
        UserMessage = New UserMessage;
        UserMessage.Field = "ExportPeriodStartDate";
        UserMessage.Text = NStr("en = 'End date must be greater than Start date.
			|Cannot export.';");
        UserMessage.Message();
        
        HasErrors = True;
        
    EndIf;
    
    If HasErrors Then
        Return;
    EndIf;
            
	StorageAddress = PutToTempStorage(Undefined, UUID);
	ExportParameters1 = New Structure;
	ExportParameters1.Insert("StartDate", ExportPeriodStartDate);
	ExportParameters1.Insert("EndDate", ExportPeriodEndDate);
	ExportParameters1.Insert("StorageAddress", StorageAddress);
	ExportParameters1.Insert("Profile", Profile);
	RunExportAtServer(ExportParameters1);
	
	BinaryData = GetFromTempStorage(StorageAddress); // BinaryData
	DeleteFromTempStorage(StorageAddress);
    
    If BinaryData <> Undefined Then
        BinaryData.Write(ExportDirectory + GetClientPathSeparator() + ArchiveName + ".zip");
    Else
        UserMessage = New UserMessage;
        UserMessage.Text = NStr("en = 'There are no samples for the period. The archive was not generated.';") + Chars.LF;
        UserMessage.Message();
    EndIf;
    	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure RunExportAtServer(Parameters)
	PerformanceMonitor.PerformanceMonitorDataExport(Undefined, Parameters);	
EndProcedure

&AtClient
Procedure DirectorySelectionDialogBoxCompletion(SelectedFiles, AdditionalParameters) Export
    
    If SelectedFiles <> Undefined Then
		ExportDirectory = SelectedFiles[0];
	EndIf;
		
EndProcedure


#EndRegion