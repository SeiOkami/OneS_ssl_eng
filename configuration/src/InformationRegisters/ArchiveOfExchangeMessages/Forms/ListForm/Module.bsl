///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterKeys.Clear();
	For Each String In SelectedRows Do
		ListLine = Items.List.RowData(String);
		NewRow = RegisterKeys.Add();
		FillPropertyValues(NewRow, ListLine);
	EndDo;
		
	FilesForDownloading = PrepareFilesAtServer();
	
	If FilesForDownloading.Count() <> 0 Then
		Title = NStr("en = 'Select a directory to save the files';");
		DialogParameters = New GetFilesDialogParameters(Title, True);
		BeginGetFilesFromServer(FilesForDownloading, DialogParameters);
	EndIf;
	
EndProcedure 

#EndRegion

#Region Private

&AtServer
Function PrepareFilesAtServer()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	RegisterKeys.InfobaseNode AS InfobaseNode,
		|	RegisterKeys.Period AS Period
		|INTO TT_RegisterKeys
		|FROM
		|	&RegisterKeys AS RegisterKeys
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Archive.InfobaseNode AS InfobaseNode,
		|	Archive.Period AS Period,
		|	Archive.FullFileName AS FullFileName,
		|	Archive.ReceivedMessageNumber AS ReceivedMessageNumber,
		|	Archive.Store AS Store,
		|	Archive.FileName AS FileName,
		|	Archive.FileExtention AS FileExtention
		|FROM
		|	TT_RegisterKeys AS TT_RegisterKeys
		|		INNER JOIN InformationRegister.ArchiveOfExchangeMessages AS Archive
		|		ON (Archive.InfobaseNode = TT_RegisterKeys.InfobaseNode)
		|			AND (Archive.Period = TT_RegisterKeys.Period)
		|			AND (NOT Archive.IsFileExceeds100MB)";
	
	Query.SetParameter("RegisterKeys", RegisterKeys.Unload());
	
	Selection = Query.Execute().Select();
	
	Result = New Array;
	
	While Selection.Next() Do
		
		If Selection.FullFileName <> "" Then
			BinaryData = New BinaryData(Selection.FullFileName);	
		Else
			BinaryData = Selection.Store.Get();
		EndIf;
		
		If BinaryData = Undefined Then
			
			Template = NStr("en = 'Message #%1 for node ""%2"" dated %3 is not found';");
			MessageText = StrTemplate(Template,
				Selection.ReceivedMessageNumber, 
				Selection.InfobaseNode,
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