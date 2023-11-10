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
	
	PeriodForAccumulationRegisters = EndOfPeriod(AddMonth(CurrentSessionDate(), -1));
	PeriodForAccountingRegisters = EndOfPeriod(CurrentSessionDate());
	
	Items.PeriodForAccountingRegisters.Enabled  = Parameters.AccountingReg;
	Items.PeriodForAccumulationRegisters.Enabled = Parameters.AccumulationReg;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodForAccumulationRegistersOnChange(Item)
	
	PeriodForAccumulationRegisters = EndOfPeriod(PeriodForAccumulationRegisters);
	
EndProcedure

&AtClient
Procedure PeriodForAccountingRegistersOnChange(Item)
	
	PeriodForAccountingRegisters = EndOfPeriod(PeriodForAccountingRegisters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectionResult = New Structure("PeriodForAccumulationRegisters, PeriodForAccountingRegisters");
	FillPropertyValues(SelectionResult, ThisObject);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Function EndOfPeriod(Date)
	
	Return EndOfDay(EndOfMonth(Date));
	
EndFunction

#EndRegion
