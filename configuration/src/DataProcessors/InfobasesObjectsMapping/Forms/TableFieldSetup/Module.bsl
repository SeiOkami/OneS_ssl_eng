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
	
	FieldList = Parameters.FieldList;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	MarkedListItemArray = CommonClientServer.MarkedItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en = 'Specify at least one field';");
		
		CommonClient.MessageToUser(NString,,"FieldList");
		
		Return;
		
	EndIf;
	
	NotifyChoice(FieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion
