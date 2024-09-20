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
	
	SetConditionalAppearance();

	If Not AccessRight("Edit", Metadata.Catalogs.AddIns) Then
		Items.BulkAdd.Visible = False;
		Items.FormUpdateFromFile.Visible = False;
		Items.FormSaveAs.Visible = False;
		Items.PerformUpdateFrom1CITSPortal.Visible = False;
		Items.ListContextMenuUpdateFromFile.Visible = False;
		Items.ListContextMenuSaveAs.Visible = False;
	Else
		Items.BulkAdd.Visible = Common.SeparatedDataUsageAvailable();
	EndIf;
	
	If Not AddInsInternal.CanImportFromPortal() Then
		Items.AddFromService.Visible = False;
		Items.UpdateFrom1CITSPortal.Visible = False;
		Items.PerformUpdateFrom1CITSPortal.Visible = False;
	Else
		Items.AddFromService.Visible = AddInsInternal.CanImportFromPortalInteractively();
	EndIf;
	
	If Parameters.UseFilter <> Undefined Then
		UseFilter = Parameters.UseFilter;
		SetFilter();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.UseFilter <> Undefined Then
		UseFilter = Parameters.UseFilter;
	EndIf;
	
	SetFilter();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Items.AddFromService.Visible Then
		ModuleGetAddInsClient = CommonClient.CommonModule("GetAddInsClient");
		If EventName = ModuleGetAddInsClient.ImportNotificationEventName() Then
			Items.List.Refresh();
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseFilterOnChange(Item)
	
	SetFilter();
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	If Copy Then 
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateFromThePortal(Command)
	
	ReferencesArrray = Items.List.SelectedRows;
	
	If ReferencesArrray.Count() = 0 Then 
		Return;
	EndIf;
	
	Notification = New NotifyDescription("AfterUpdateAddInFromPortal", ThisObject);
	AddInsInternalClient.UpdateAddInsFromPortal(Notification, ReferencesArrray);
	
EndProcedure

&AtClient
Procedure UpdateFromFile(Command)
	
	RowData = Items.List.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", RowData.Ref);
	FormParameters.Insert("ShowImportFromFileDialogOnOpen", True);
	
	OpenForm("Catalog.AddIns.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	ReferencesArrray = Items.List.SelectedRows;
	
	If ReferencesArrray.Count() = 0 Then 
		Return;
	EndIf;
	
	AddInsInternalClient.SaveAddInToFile(ReferencesArrray);
	
EndProcedure

&AtClient
Procedure AddFromDirectory(Command)
	
	ClearMessages();
	
	Notification = New NotifyDescription("AddAddInsFromDirectoryAfterExtensionsAttached", ThisObject);
		
	SuggestionText =  NStr("en = 'To import add-ins from the directory, install the File System extension.';");
	FileSystemClient.AttachFileOperationsExtension(Notification, SuggestionText, False);
		
EndProcedure

&AtClient
Procedure AddFromService(Command)
	
	ModuleGetAddInsClient = CommonClient.CommonModule("GetAddInsClient");
	ModuleGetAddInsClient.UpdateAddIns();

EndProcedure

&AtClient
Procedure DeleteUnusedItems(Command)
	
	DeleteUnusedAddIns();
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure AddFromFiles(Command)
	
	ClearMessages();
	
	Notification = New NotifyDescription("AddAddInsAfterFilesPut",
		ThisObject);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Title = NStr("en = 'Select add-in files';");
	ImportParameters.Dialog.Filter = NStr("en = 'Archive (*.zip)|*.zip';") + "|"
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	
	ImportParameters.Dialog.Multiselect = True;
	Items.Pages_Group.CurrentPage = Items.WaitPage;
	FileSystemClient.ImportFiles(Notification, ImportParameters);
	
EndProcedure

#EndRegion

#Region Private

// 

&AtClient
Procedure AddAddInsFromDirectoryAfterExtensionsAttached(Result, CreationParameters) Export
	
	If Result <> True Then
		Return;
	EndIf;
		
	Notification = New NotifyDescription("AddAddInsAfterDirectorySelected", ThisObject);
	Items.Pages_Group.CurrentPage = Items.WaitPage;
	FileSystemClient.SelectDirectory(Notification, NStr("en = 'Select a directory with add-in files';"));
	
EndProcedure

// 

&AtClient
Async Procedure AddAddInsAfterDirectorySelected(SelectedDirectory, AdditionalParameters) Export
	
	If Not ValueIsFilled(SelectedDirectory) Then
		Items.Pages_Group.CurrentPage = Items.List_Page;
		Return;
	EndIf;
	
	Notification = New NotifyDescription("AddAddInsAfterFilesPut",
		ThisObject);
	
	DetailsOfFilesToTransfer = New Array;
	
	Files = Await FindFilesAsync(SelectedDirectory,"*.zip", True);

	For Each CurrentFile In Files Do
		If Await CurrentFile.IsDirectoryAsync() Then
			Continue;
		EndIf;
		TransferableFileDescription = New TransferableFileDescription(CurrentFile.FullName);
		DetailsOfFilesToTransfer.Add(TransferableFileDescription);
	EndDo;
	
	If DetailsOfFilesToTransfer.Count() = 0 Then
		Raise NStr("en = 'The specified directory does not contain any add-in files.';");
	EndIf;
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Interactively = False;
	FileSystemClient.ImportFiles(Notification, ImportParameters, DetailsOfFilesToTransfer);
		
EndProcedure

&AtClient
Procedure DownloadAddInsAfterSafetyWarning(Response, PlacedFiles) Export
	
	If Response <> "Continue" Then
		Items.Pages_Group.CurrentPage = Items.List_Page;
		Return;
	EndIf;
	
	If PlacedFiles.Count() = 1 Then
		Items.Pages_Group.CurrentPage = Items.List_Page;
		If IsFileOfService(PlacedFiles[0].Location) Then
			ModuleGetAddInsClient = CommonClient.CommonModule("GetAddInsClient");
			ModuleGetAddInsClient.UpdateAddIns(Undefined, PlacedFiles[0].FullName);
			Return;
		EndIf;
		FormParameters = New Structure;
		FormParameters.Insert("FileThatWasPut", PlacedFiles[0]);
		OpenForm("Catalog.AddIns.ObjectForm", FormParameters);
		Return;
	EndIf;
	
	Result = DownloadAddInsAtServer(PlacedFiles);
	Items.Pages_Group.CurrentPage = Items.List_Page;
	
	If Result.Count() > 0 Then
		TextDocument = New TextDocument;
		TextDocument.SetText(StrConcat(Result, Chars.LF));
		TextDocument.InsertLine(0, NStr(
			"en = 'Cannot import the add-ins. To fill add-in properties manually, import files one by one:';")
			+ Chars.LF);
		TextDocument.Show(NStr("en = 'Cannot import the add-ins';"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Function DownloadAddInsAtServer(PlacedFiles)
	
	ErrorsDescription = New Array;
	
	UsedAddIns = AddInsInternal.UsedAddIns();
	
	For Each ComponentFile In PlacedFiles Do

		Try
			ImportParameters = AddInsInternal.ImportParameters();
			ImportParameters.FileName = ComponentFile.FileName;
			ImportParameters.UpdateFrom1CITSPortal = False;
			ImportParameters.Data = ComponentFile.Location;
			ImportParameters.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Imported from the %1 file. %2.';"),
				ComponentFile.FileName,
				CurrentSessionDate());
			AddInsInternal.LoadAComponentFromBinaryData(ImportParameters, True, UsedAddIns);
		Except
			If ValueIsFilled(ComponentFile.FullName) Then
				PathToFile = ComponentFile.FullName;
			Else
				PathToFile = ComponentFile.FileName;
			EndIf;
			ErrorsDescription.Add(StringFunctionsClientServer.SubstituteParametersToString("%1: %2", PathToFile,
				ErrorProcessing.BriefErrorDescription(ErrorInfo())));
		EndTry;

	EndDo;
	
	Return ErrorsDescription;
	
EndFunction

&AtClient
Procedure AddAddInsAfterFilesPut(PlacedFiles, AdditionalParameters) Export
	
	If Not ValueIsFilled(PlacedFiles) Then
		Items.Pages_Group.CurrentPage = Items.List_Page;
		Return;
	EndIf;
	
	Notification = New NotifyDescription("DownloadAddInsAfterSafetyWarning", ThisObject, PlacedFiles);
	FormParameters = New Structure("Key", "BeforeAddAddIn");
	OpenForm("CommonForm.SecurityWarning", FormParameters,,,,, Notification);
	
EndProcedure

&AtClient
Procedure AfterUpdateAddInFromPortal(Result, AdditionalParameters) Export
	
	Items.List.Refresh();
	
EndProcedure

/////////////////////////////////////////////////////////
// 

&AtServer
Procedure SetFilter()
	
	FilterParameters = New Map();
	FilterParameters.Insert("UseFilter", UseFilter);
	SetListFilter(List, FilterParameters);
	
	Items.DeleteUnusedItems.Visible = UseFilter = 3 And AccessRight("Edit", Metadata.Catalogs.AddIns);
	
EndProcedure

&AtServerNoContext
Procedure SetListFilter(List, FilterParameters)
	
	If FilterParameters["UseFilter"] = 3 Then
		IDs = AddInsInternal.SuppliedAddIns();
		CommonClientServer.SetDynamicListFilterItem(
			List, "Id", IDs, DataCompositionComparisonType.NotInList, , True);
		CommonClientServer.SetDynamicListFilterItem(
				List, "Use", Enums.AddInUsageOptions.Used, , , False);
	Else
		CommonClientServer.SetDynamicListFilterItem(
			List, "Id", Undefined, , , False);
		If FilterParameters["UseFilter"] = 0 Then
			CommonClientServer.SetDynamicListFilterItem(
				List, "Use", , , , False);
		ElsIf FilterParameters["UseFilter"] = 1 Then
			CommonClientServer.SetDynamicListFilterItem(
				List, "Use", Enums.AddInUsageOptions.Used, , , True);
		ElsIf FilterParameters["UseFilter"] = 2 Then
			CommonClientServer.SetDynamicListFilterItem(
				List, "Use", Enums.AddInUsageOptions.isDisabled, , , True);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteUnusedAddIns()
	
	AddInsInternal.DeleteUnusedAddIns();
	
EndProcedure

&AtServerNoContext
Function IsFileOfService(FileAddress)
	
	If AddInsInternal.CanImportFromPortalInteractively() Then
		
		BinaryData = GetFromTempStorage(FileAddress);
		Information = AddInsInternal.InformationOnAddInFromFile(BinaryData, False);
		
		Return Information.IsFileOfService;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	
	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("Use");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.AddInUsageOptions.isDisabled;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue(
		"TextColor", Metadata.StyleItems.InaccessibleCellTextColor.Value);
	
EndProcedure

#EndRegion