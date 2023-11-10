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
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	If Not ValueIsFilled(Record.SourceRecordKey.InfobaseNode) Then
		Record.FilesCount = 1;
		Record.StoreOnDisk = True;
	EndIf;
	
	StorageLocation = Record.StoreOnDisk;
	
	CommonClientServer.SetDynamicListFilterItem(
		ArchiveOfExchangeMessages, "InfobaseNode", Record.InfobaseNode);

	ItemsAvailability();
	
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StorageLocationOnChange(Item)
	
	Record.StoreOnDisk = StorageLocation;
	
	ItemsAvailability();
	
EndProcedure

&AtClient
Procedure FullPathStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Title = NStr("en = 'Select a folder to store exchange files';");
	CompletionHandler = New NotifyDescription("FullPathToSelectionCompletion", ThisObject);
	
	FileSystemClient.SelectDirectory(CompletionHandler, Title, Record.FullPath);
	
EndProcedure

&AtClient
Procedure FullPathOnChange(Item)
	
	AppendFullPath();
	
EndProcedure

&AtClient
Procedure FilesCountOnChange(Item)
	
	If DataSeparationEnabled Then
		Record.FilesCount = Min(Record.FilesCount, 1);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	
	SelectedRows = Items.ArchiveOfExchangeMessages.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	TimeIntervals = New Array;
	For Each String In SelectedRows Do
		ListLine = Items.ArchiveOfExchangeMessages.RowData(String);
		TimeIntervals.Add(ListLine.Period);
	EndDo;
		
	FilesForDownloading = PrepareFilesAtServer(Record.InfobaseNode, TimeIntervals);
	If FilesForDownloading.Count() <> 0 Then
		Title = NStr("en = 'Select a directory to save the files';");
		DialogParameters = New GetFilesDialogParameters(Title, True);
		BeginGetFilesFromServer(FilesForDownloading, DialogParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFolderAvailability(Command)
	CheckAvailabilityOfServerDir();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("ArchiveOfExchangeMessages");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ArchiveOfExchangeMessages.IsFileExceeds100MB");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

EndProcedure

&AtServer
Procedure ItemsAvailability()
	
	Items.GroupFolder.Enabled = Record.StoreOnDisk;
	
	If DataSeparationEnabled And Not Record.StoreOnDisk Then
		Items.StorageLocation.ToolTipRepresentation = ToolTipRepresentation.ShowRight;
	Else
		Items.StorageLocation.ToolTipRepresentation = ToolTipRepresentation.None
	EndIf;
		
EndProcedure

&AtClient
Procedure FullPathToSelectionCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Record.FullPath = Result;
	
	AppendFullPath();
	
EndProcedure

&AtServer
Procedure CheckAvailabilityOfServerDir()
	
	HelpDir = New File(Record.FullPath);
	If HelpDir.Exists() Then
		Common.MessageToUser(NStr("en = 'Directory is available';"));
	Else
		Common.MessageToUser(NStr("en = 'Directory is unavailable';"));	
	EndIf;
	
EndProcedure

&AtClient
Procedure AppendFullPath()
	
	If Not IsBlankString(Record.FullPath) Then
		
		FullPath = TrimAll(Record.FullPath);	
		Record.FullPath = CommonClientServer.AddLastPathSeparator(FullPath);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PrepareFilesAtServer(InfobaseNode, TimeIntervals)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Archive.FullFileName AS FullFileName,
		|	Archive.Period AS Period,
		|	Archive.ReceivedMessageNumber AS ReceivedMessageNumber,
		|	Archive.Store AS Store,
		|	Archive.FileName AS FileName,
		|	Archive.FileExtention AS FileExtention
		|FROM
		|	InformationRegister.ArchiveOfExchangeMessages AS Archive
		|WHERE
		|	Archive.Period IN(&TimeIntervals)
		|	AND Archive.InfobaseNode = &InfobaseNode
		|	AND NOT Archive.IsFileExceeds100MB";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("TimeIntervals", TimeIntervals);
	
	Selection = Query.Execute().Select();
	
	Result = New Array;
	
	While Selection.Next() Do
		
		If Selection.FullFileName <> "" Then
			BinaryData = New BinaryData(Selection.FullFileName);	
		Else
			BinaryData = Selection.Store.Get();
		EndIf; 
		
		If BinaryData = Undefined Then
			
			Template = NStr("en = 'Message #%1 dated %2 is not found';");
			MessageText = StrTemplate(Template,
				Selection.ReceivedMessageNumber,
				Selection.Period);
				
			Common.MessageToUser(MessageText);
			
			Continue;
			
		EndIf;
		
		Address = PutToTempStorage(BinaryData);
		FileName = Selection.FileName + "." + Selection.FileExtention;
		Result.Add(New TransferableFileDescription(FileName, Address))
		
	EndDo;
	
	Return Result;

EndFunction

#EndRegion