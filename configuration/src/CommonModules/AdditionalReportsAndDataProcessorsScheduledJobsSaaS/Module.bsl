///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use ScheduledJobsServer.AddJob().
//
// Returns:
//   Undefined - 
//
Function CreateNewJob() Export
	
	Return Undefined;
	
EndFunction

// Deprecated. Obsolete. Use ScheduledJobsServer.UUID().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
// Returns:
//   Undefined - 
//
Function GetJobID(Val Job) Export
	
	Return Undefined;
	
EndFunction

// Deprecated. Obsolete. Use ScheduledJobsServer.ChangeJob().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//   Use - Boolean - indicates whether a scheduled job is used.
//   Parameters - Array - parameters of the scheduled job.
//   Schedule - JobSchedule - a scheduled job schedule.
//
Procedure SetJobParameters(Job, Use, Parameters, Schedule) Export
	
	Return;
	
EndProcedure

// Deprecated. Obsolete. Use ScheduledJobsServer.FindJobs().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
// Returns:
//   Undefined - 
//
Function GetJobParameters(Val Job) Export
	
	Return Undefined;
	
EndFunction

// Deprecated. Obsolete. Use ScheduledJobsServer.Job().
//
// Parameters:
//   Id - UUID - a scheduled job ID.
//
// Returns:
//   Undefined - 
//
Function FindJob(Val Id) Export
	
	Return Undefined;
	
EndFunction

// Deprecated. Obsolete. Use ScheduledJobsServer.DeleteJob().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
Procedure DeleteJob(Val Job) Export
	
	Return;
	
EndProcedure

#EndRegion

#EndRegion
