///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var SettingEnabled; // 
                         // 

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SettingEnabled = Value And Not Constants.UseImportForbidDates.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// 
	// 
	If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
		PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersion();
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If SettingEnabled Then
		SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
		If Not SectionsProperties.ImportRestrictionDatesImplemented Then
			Raise PeriodClosingDatesInternal.ErrorTextImportRestrictionDatesNotImplemented();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf