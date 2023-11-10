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
	
	If Not Parameters.Property("ExchangeNodeReference", ExchangeNodeReference) Then
		Cancel = True;
		Return;
	EndIf;
	
	Title = ExchangeNodeReference;
	
	ReadMessageNumbers();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// The procedure writes modified data and closes the form.
//
&AtClient
Procedure WriteNodeChanges(Command)
	
	WriteMessageNumbers();
	Notify("ExchangeNodeDataEdit", ExchangeNodeReference, ThisObject);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ThisObject() 
	
	Return FormAttributeToValue("Object");
	
EndFunction

&AtServer
Procedure ReadMessageNumbers()
	
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeReference, "SentNo, ReceivedNo");
	FillPropertyValues(ThisObject, Data);
	
EndProcedure

&AtServer
Procedure WriteMessageNumbers()
	
	Data = New Structure("SentNo, ReceivedNo", SentNo, ReceivedNo);
	ThisObject().SetExchangeNodeParameters(ExchangeNodeReference, Data);
	
EndProcedure

#EndRegion
