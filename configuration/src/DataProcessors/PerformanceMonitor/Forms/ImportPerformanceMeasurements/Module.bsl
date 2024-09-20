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
		Items.ImportFile3.ChoiceButton = False;
		SSLAvailable = False;
	Else
		SSLAvailable = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectFileToImportSuggested(FileSystemExtensionAttached1, AdditionalParameters) Export
	
	If FileSystemExtensionAttached1 Then
		
		SelectingFile = New FileDialog(FileDialogMode.Open);
		SelectingFile.Multiselect = False;
		SelectingFile.Title = NStr("en = 'Choose a sample file';");
		SelectingFile.Filter = "Files import2 measurings (*.zip)|*.zip";
		
		NotifyDescription = New NotifyDescription("FileDialogCompletion", ThisObject, Undefined);
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
Procedure ImportFile3StartChoice(Item, ChoiceData, StandardProcessing)
	
	If SSLAvailable Then
		NotifyDescription = New NotifyDescription("SelectFileToImportSuggested", ThisObject, Undefined);
		ModuleFileSystemClient = Eval("FileSystemClient");
		If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
			ModuleFileSystemClient.AttachFileOperationsExtension(NotifyDescription);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Import(Command)
	File = New File(ImportFile3);
	File.BeginCheckingExistence(New NotifyDescription("ImportAfterExistenceCheck", ThisObject));
EndProcedure

&AtClient
Procedure ImportAfterExistenceCheck(Exists, AdditionalParameters) Export
	If Not Exists Then 
		Message = New UserMessage();
    	Message.Text = NStr("en = 'Choose a sample file';");
    	Message.Field = "ImportFile3";
    	Message.Message();
		Return;
	EndIf;
	BinaryData = New BinaryData(ImportFile3);
    StorageAddress = PutToTempStorage(BinaryData, UUID);
    ExecuteImportAtServer1(ImportFile3, StorageAddress);	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure ExecuteImportAtServer1(FileName, StorageAddress)
	PerformanceMonitor.LoadPerformanceMonitorFile(FileName, StorageAddress);
EndProcedure                                                                     

&AtClient
Procedure FileDialogCompletion(SelectedFiles, AdditionalParameters) Export
    
    If SelectedFiles <> Undefined Then
		ImportFile3 = SelectedFiles[0];
	EndIf;
		
EndProcedure

#EndRegion