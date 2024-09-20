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
	
	Explanation = Parameters.Explanation;
	
	TabDoc = New SpreadsheetDocument;
	TabTemplate = DataProcessors.FileTransfer.GetTemplate("ReportTemplate");
	
	HeaderArea_ = TabTemplate.GetArea("Title");
	HeaderArea_.Parameters.LongDesc = NStr("en = 'File';");
	TabDoc.Put(HeaderArea_);
	
	AreaRow = TabTemplate.GetArea("String");
	
	For Each Selection In Parameters.FilesArrayWithErrors Do
		AreaRow.Parameters.Name1 = Selection.FileName;
		AreaRow.Parameters.Version = Selection.Version;
		AreaRow.Parameters.Error = Selection.Error;
		TabDoc.Put(AreaRow);
	EndDo;
	
	Report.Put(TabDoc);
	
EndProcedure

#EndRegion
