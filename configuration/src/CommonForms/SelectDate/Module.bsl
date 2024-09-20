///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var ActionSelected;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InitialValue = Parameters.InitialValue;
	
	If Not ValueIsFilled(InitialValue) Then
		InitialValue = CurrentSessionDate();
	EndIf;
	
	Parameters.Property("BeginOfRepresentationPeriod", Items.Calendar.BeginOfRepresentationPeriod);
	Parameters.Property("EndOfRepresentationPeriod", Items.Calendar.EndOfRepresentationPeriod);
	
	Calendar = InitialValue;
	
	Parameters.Property("Title", Title);
	
	If Parameters.Property("NoteText") Then
		Items.NoteText.Title = Parameters.NoteText;
	Else
		Items.NoteText.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	If ActionSelected <> True Then
		NotifyChoice(Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CalendarSelection(Item, SelectedDate)
	
	ActionSelected = True;
	NotifyChoice(SelectedDate);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Please select a date.';"));
		Return;
	EndIf;
	
	ActionSelected = True;
	NotifyChoice(SelectedDates[0]);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ActionSelected = True;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

