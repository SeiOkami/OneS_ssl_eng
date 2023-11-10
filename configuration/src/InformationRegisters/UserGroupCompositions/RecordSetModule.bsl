///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel, Replacing)
	
	// 
	// 
	If DataExchange.Load Then
		If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
			UpdatePeriodClosingDatesVersionOnDataImport();
		EndIf;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure UpdatePeriodClosingDatesVersionOnDataImport()
	
	// 
	// 
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.UpdatePeriodClosingDatesVersionOnDataImport(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf