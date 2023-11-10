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

Procedure BeforeWrite(Cancel, Replacing)
	
	// 
	AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	// 
	DataExchange.Recipients.Clear();
	
	// Filling the SourceUUIDString by the source reference.
	If Count() > 0 Then
		
		If ThisObject[0].ObjectExportedByRef = True Then
			Return;
		EndIf;
		
		ThisObject[0]["SourceUUIDString"] = String(ThisObject[0]["SourceUUID"].UUID());
		
	EndIf;
	
	If DataExchange.Load
		Or Not ValueIsFilled(Filter.InfobaseNode.Value)
		Or Not ValueIsFilled(Filter.DestinationUUID.Value)
		Or Not Common.RefExists(Filter.InfobaseNode.Value) Then
		Return;
	EndIf;
	
	// 
	DataExchange.Recipients.Add(Filter.InfobaseNode.Value);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf