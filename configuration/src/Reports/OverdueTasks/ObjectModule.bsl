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

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	DateFormat = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	TaskDueDate = DataCompositionSchema.DataSets[0].Fields.Find("TaskDueDate");
	TaskDueDate.Appearance.SetParameterValue("Format", DateFormat);
	
	CompletionDate = DataCompositionSchema.DataSets[0].Fields.Find("CompletionDate");
	CompletionDate.Appearance.SetParameterValue("Format", DateFormat);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf