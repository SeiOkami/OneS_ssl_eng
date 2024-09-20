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
	
	If DeletionMark Then
		
		UseScheduledJob = False;
		
	EndIf;
	
	If UseScheduledJob And IsAutoDisabled Then
		
		IsAutoDisabled = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Deleting a scheduled job if necessary.
	If DeletionMark Then
		
		DeleteScheduledJob(Cancel);
		
	EndIf;
	
	// 
	// 
	RefreshReusableValues();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	GUIDScheduledJob = "";
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteScheduledJob(Cancel);
	
EndProcedure

#EndRegion

#Region Private

// Deletes a scheduled job.
//
// Parameters:
//  Cancel                     - Boolean - a cancellation flag. It is set to True if errors
//                                       occur upon the procedure execution.
//  ScheduledJobObject - a scheduled job object to be deleted.
// 
Procedure DeleteScheduledJob(Cancel)
	
	SetPrivilegedMode(True);
			
	// Define a scheduled job.
	ScheduledJobObject = Catalogs.DataExchangeScenarios.ScheduledJobByID(GUIDScheduledJob);
	
	If ScheduledJobObject <> Undefined Then
		
		Try
			If Common.DataSeparationEnabled() Then
				ScheduledJobsServer.DeleteJob(ScheduledJobObject);
			Else
				ScheduledJobObject.Delete();
			EndIf;	
		Except
			MessageString = NStr("en = 'Cannot delete the scheduled job: %1';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, 
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			DataExchangeServer.ReportError(MessageString, Cancel);
		EndTry;
	
	EndIf;
		
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf