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
	CoreAvailable = PerformanceMonitorInternal.SubsystemExists("StandardSubsystems.Core");
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure LoadKeyOperationsProfile(Command)
	
	If CoreAvailable Then
		ModuleFileSystemClient = Eval("FileSystemClient");
		If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
			ImportParameters = ModuleFileSystemClient.FileImportParameters();
			ImportParameters.Dialog.Title = NStr("en = 'Select file of key operation profile';");
			ImportParameters.Dialog.Filter = "Files profile2 key operations (*.xml)|*.xml";
			
			NotifyDescription = New NotifyDescription("FileDialogCompletion", ThisObject, Undefined);
			ModuleFileSystemClient.ImportFile_(NotifyDescription, ImportParameters);
		EndIf;
	Else          		
		AdditionalParameters = New Structure("Mode, Title, ClosingNotification1",  
		FileDialogMode.Open, 
		NStr("en = 'Select file of key operation profile';"),
		New NotifyDescription("FileDialogCompletion", ThisObject, Undefined));  
		#If WebClient Then
			Notification = New NotifyDescription("BeginAttachingFileSystemExtensionCompletion", ThisObject,
			New NotifyDescription("DialogueFileSelectionShow", ThisObject, AdditionalParameters));
			BeginAttachingFileSystemExtension(Notification);
		#Else
			DialogueFileSelectionShow(True, AdditionalParameters);
		#EndIf  		
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveKeyOperationsProfile(Command)
	
	If CoreAvailable Then
		ModuleFileSystemClient = Eval("FileSystemClient");
		If TypeOf(ModuleFileSystemClient) = Type("CommonModule") Then
			SavingParameters = ModuleFileSystemClient.FileSavingParameters();
			SavingParameters.Dialog.Title = NStr("en = 'Save key operation profile to file';");
			SavingParameters.Dialog.Filter = "Files profile2 key operations (*.xml)|*.xml";  		
			ModuleFileSystemClient.SaveFile(New NotifyDescription("SaveFileDialogCompletion", ThisObject, Undefined), SaveKeyOperationsProfileToServer(), , SavingParameters);
		EndIf;
	Else              		
		AdditionalParameters = New Structure("Mode, Title, ClosingNotification1",  
			FileDialogMode.Save, 
			NStr("en = 'Save key operation profile to file';"),
			New NotifyDescription("SaveFileDialogCompletion", ThisObject, Undefined));  
		#If WebClient Then
		Notification = New NotifyDescription("BeginAttachingFileSystemExtensionCompletion", ThisObject,
			New NotifyDescription("DialogueFileSelectionShow", ThisObject, AdditionalParameters));
		BeginAttachingFileSystemExtension(Notification);
		#Else
			DialogueFileSelectionShow(True, AdditionalParameters);
		#EndIf     		
	EndIf;
	
EndProcedure

&AtClient
Procedure Fill(Command)
	FillAtServer();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DialogueFileSelectionShow(Result, AdditionalParameters) Export
	If Result Then
		ChoiceDialog = New FileDialog(AdditionalParameters.Mode);
		ChoiceDialog.Title = AdditionalParameters.Title;
		ChoiceDialog.Filter = "Files profile2 key operations (*.xml)|*.xml";
		If AdditionalParameters.Mode = FileDialogMode.Open Then
			BeginPuttingFiles(AdditionalParameters.ClosingNotification1,, ChoiceDialog, True, UUID);
		ElsIf AdditionalParameters.Mode = FileDialogMode.Save Then
			FilesToReceive = New Array;
			FilesToReceive.Add(New TransferableFileDescription("", SaveKeyOperationsProfileToServer()));
			BeginGettingFiles(AdditionalParameters.ClosingNotification1, FilesToReceive, ChoiceDialog, True);
		EndIf;
		
	Else
		MessageToUser(NStr("en = 'To manage files, you need to install File system extension.';"), "Object");
	EndIf;
EndProcedure

&AtClient
Procedure FileDialogCompletion(SelectedFile, AdditionalParameters) Export
	
	If SelectedFile = Undefined Then
		Return;
	EndIf;
	
	If CoreAvailable Then		
		If Not ValueIsFilled(Object.Description) Then
			File_Name = New File(SelectedFile.Name);
			Object.Description = File_Name.BaseName;
		EndIf;
		LoadKeyOperationsProfileAtServer(SelectedFile.Location);		
	Else
		If Not ValueIsFilled(Object.Description) Then
			File_Name = New File(SelectedFile[0].Name);
			Object.Description = File_Name.BaseName;
		EndIf;
			
		LoadKeyOperationsProfileAtServer(SelectedFile[0].Location);				
	EndIf;
	Modified = True;
	
EndProcedure

&AtClient
Procedure SaveFileDialogCompletion(SelectedFiles, AdditionalParameters) Export
    
	Status(NStr("en = 'The files are saved.';"));
    
EndProcedure

&AtClient
Procedure BeginAttachingFileSystemExtensionCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached Then
		ExecuteNotifyProcessing(AdditionalParameters, True);
		Return;
	EndIf;
	
	If Not ExtensionInstallationPrompted Then
		ExtensionInstallationPrompted = True;
		NotifyDescriptionQuestion = New NotifyDescription("QueryAboutExtensionInstallation", ThisObject, AdditionalParameters);
		BeginInstallFileSystemExtension(NotifyDescriptionQuestion );
	Else
		ExecuteNotifyProcessing(AdditionalParameters, ExtensionAttached);
	EndIf;
	
EndProcedure

&AtClient
Procedure QueryAboutExtensionInstallation(Notification) Export
	
	NotificationOnChecking = New NotifyDescription("BeginAttachingFileSystemExtensionCompletion", ThisObject,
			New NotifyDescription("DialogueFileSelectionShow", ThisObject, Notification));
	BeginAttachingFileSystemExtension(NotificationOnChecking);
	
EndProcedure

&AtClient
Procedure MessageToUser(MessageText, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = MessageText;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure


&AtServer
Function SaveKeyOperationsProfileToServer()
    
    TempFileName = GetTempFileName("xml");
    
    XMLWriter = New XMLWriter;
    XMLWriter.OpenFile(TempFileName);
    
    XMLWriter.WriteStartElement("Items");
    XMLWriter.WriteAttribute("Description", Object.Description);
    XMLWriter.WriteAttribute("Columns", "Name,ResponseTimeThreshold,Importance");
    
    For Each CurRow In Object.ProfileKeyOperations Do
        XMLWriter.WriteStartElement("Item");
        XMLWriter.WriteAttribute("Name", CurRow.KeyOperation.Name);
        XMLWriter.WriteAttribute("ResponseTimeThreshold", Format(CurRow.ResponseTimeThreshold, "NG=0"));
        XMLWriter.WriteAttribute("Importance", Format(CurRow.Priority, "NG=0"));
        XMLWriter.WriteEndElement();
    EndDo;
        
    XMLWriter.WriteEndElement();
    
    XMLWriter.Close();
    
    BinaryData = New BinaryData(TempFileName);
    StorageAddress = PutToTempStorage(BinaryData, UUID);
    
    DeleteFiles(TempFileName);
    
    Return StorageAddress;
    
EndFunction

&AtServer
Procedure LoadKeyOperationsProfileAtServer(StorageAddress)
    
    BinaryData = GetFromTempStorage(StorageAddress); // BinaryData
        
    TempFileName = GetTempFileName("xml");
    BinaryData.Write(TempFileName);
    
    XMLReader = New XMLReader;
    XMLReader.OpenFile(TempFileName);
    KeyOperations = XDTOFactory.ReadXML(XMLReader);
    
    Columns = StrSplit(KeyOperations["Columns"], ",",False);
    If KeyOperations.Properties().Get("Item") <> Undefined Then
	    If TypeOf(KeyOperations["Item"]) = Type("XDTODataObject") Then
	        LoadXDTODataObject(KeyOperations["Item"], Columns);
	    Else
	        For Each CurItem In KeyOperations["Item"] Do
	            LoadXDTODataObject(CurItem, Columns);
	        EndDo;
		EndIf;
	EndIf;
            
    XMLReader.Close();
    DeleteFiles(TempFileName);
    
EndProcedure

&AtServer
Procedure LoadXDTODataObject(XDTODataObject, Columns)
    
    CurItem = XDTODataObject;
	
	KeyOperation = Catalogs.KeyOperations.FindByAttribute("Name", CurItem.Name);
	If KeyOperation.IsEmpty() Then
		KeyOperation = PerformanceMonitor.CreateKeyOperation(CurItem.Name);
	EndIf;
    FilterParameters = New Structure("KeyOperation", KeyOperation);
    FoundRows = Object.ProfileKeyOperations.FindRows(FilterParameters);
    
    If FoundRows.Count() = 0 Then
        
        NewString = Object.ProfileKeyOperations.Add();
		NewString.KeyOperation = KeyOperation;
        
		For Each CurColumn In Columns Do
			ColumnName = ?(CurColumn = "Importance", "Priority", CurColumn);
            If NewString.Property(ColumnName) And CurItem.Properties().Get(CurColumn) <> Undefined Then
                NewString[ColumnName] = CurItem[CurColumn];
            EndIf;
        EndDo;
        
        If Not ValueIsFilled(NewString.Priority) Then
            NewString.Priority = 5;
        EndIf;
    Else
        For Each NewString In FoundRows Do
			For Each CurColumn In Columns Do
				ColumnName = ?(CurColumn = "Importance", "Priority", CurColumn);
                If NewString.Property(ColumnName) And CurItem.Properties().Get(CurColumn) <> Undefined Then
                    NewString[ColumnName] = CurItem[CurColumn];
                EndIf;
            EndDo;
        EndDo;
    EndIf;
    
EndProcedure

&AtServer
Procedure FillAtServer()
	Query = New Query("SELECT
	                      |	KeyOperations.Ref AS KeyOperation,
	                      |	KeyOperations.ResponseTimeThreshold AS ResponseTimeThreshold,
	                      |	CASE
	                      |		WHEN KeyOperations.Priority = 0
	                      |			THEN 5
	                      |		ELSE KeyOperations.Priority
	                      |	END AS Priority
	                      |FROM
	                      |	Catalog.KeyOperations AS KeyOperations
	                      |WHERE
	                      |	NOT KeyOperations.DeletionMark
	                      |
	                      |ORDER BY
	                      |	KeyOperations.Description");
	Object.ProfileKeyOperations.Load(Query.Execute().Unload());
EndProcedure

#EndRegion
