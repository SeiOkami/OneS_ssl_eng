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
	
	SetOptionAtServer();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FirstOption(Command)
	
	SetOptionAtServer(1);
	
EndProcedure

&AtClient
Procedure SecondOption(Command)
	
	SetOptionAtServer(2);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetOptionAtServer(Variant = 0)
	
	Reports.PeriodClosingDates.SetOption(ThisObject, Variant);
	
EndProcedure

#EndRegion
