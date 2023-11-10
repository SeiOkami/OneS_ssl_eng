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

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	ValueList = New ValueList;
	ValueList.Add(Enums.CryptographySignatureTypes.BasicCAdESBES);
	ValueList.Add(Enums.CryptographySignatureTypes.WithTimeCAdEST);
	ValueList.Add(Enums.CryptographySignatureTypes.ArchivalCAdESAv3);
	
	ChoiceData = ValueList;
	
EndProcedure

#EndRegion

#EndIf