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

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Value = Enums.CryptographySignatureTypes.NormalCMS
		Or Value = Enums.CryptographySignatureTypes.BasicCAdESBES
		Or Not ValueIsFilled(Value) Then
		If Constants.RefineSignaturesAutomatically.Get() <> 0 Then
			Constants.RefineSignaturesAutomatically.Set(0);
		EndIf;
	EndIf;
	
	DigitalSignatureInternal.ChangeRegulatoryTaskExtensionCredibilitySignatures(,,Value);

EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf