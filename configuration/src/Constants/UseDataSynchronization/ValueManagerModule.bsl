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
	
	If Value Then
		
		DataSeparationEnabled = Common.DataSeparationEnabled();
		Constants.UseDataSynchronizationInLocalMode.Set(Not DataSeparationEnabled);
		If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
			ManagerOfConstant = Constants["UseDataSynchronizationSaaS"].CreateValueManager();
			ManagerOfConstant.Value = DataSeparationEnabled;
			ManagerOfConstant.Write();
		EndIf;
		
	Else
		
		Constants.UseDataSynchronizationInLocalMode.Set(False);
		If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
			ManagerOfConstant = Constants["UseDataSynchronizationSaaS"].CreateValueManager();
			ManagerOfConstant.Value = False;
			ManagerOfConstant.Write();
		EndIf;
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Value
	   And Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.OnDisableDataSynchronization(Cancel);
	EndIf;
	Job = ScheduledJobsServer.GetScheduledJob(
			Metadata.ScheduledJobs.ObsoleteSynchronizationDataDeletion);
	If Job.Use <> Value Then
		Job.Use = Value;
		Job.Write();
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf