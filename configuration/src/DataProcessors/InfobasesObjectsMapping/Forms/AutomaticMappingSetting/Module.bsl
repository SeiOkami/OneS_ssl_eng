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
	
	MappingFieldsList = Parameters.MappingFieldsList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MappingFieldsListOnChange(Item)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunMapping(Command)
	
	NotifyChoice(MappingFieldsList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateCommentLabelText()
	
	MarkedListItemArray = CommonClientServer.MarkedItems(MappingFieldsList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NoteLabel = NStr("en = 'Mapping will be performed by internal object UUIDs only.';");
		
	Else
		
		NoteLabel = NStr("en = 'Mapping will be performed by internal object UUIDs and the selected fields.';");
		
	EndIf;
	
EndProcedure

#EndRegion
