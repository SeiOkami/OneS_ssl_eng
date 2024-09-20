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

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		
		Return;
		
	EndIf;
	
	AdditionalProperties.Insert("CurrentValue", Constants.IsStandaloneWorkplace.Get());
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		
		Return;
		
	EndIf;
	
	StandardProcessing = True;
	PreviousValue = AdditionalProperties.CurrentValue;
	NewCurrent = Value;
	
	DataExchangeOverridable.WhenChangingOfflineModeOption(PreviousValue, NewCurrent, StandardProcessing);
	
	If StandardProcessing = False Then
		
		Return;
		
	EndIf;
	
	If AdditionalProperties.CurrentValue <> Value Then
		
		RefreshReusableValues();
		
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf