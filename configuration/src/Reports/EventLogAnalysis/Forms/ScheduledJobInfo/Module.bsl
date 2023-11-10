///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DetailsFromReport = CommonClientServer.StructureProperty(Parameters, "DetailsFromReport");
	If DetailsFromReport <> Undefined Then
		Report = Reports.EventLogAnalysis.ScheduledJobDetails1(DetailsFromReport).Report;
		
		ScheduledJobName = DetailsFromReport.Get(1);
		EventDescription = DetailsFromReport.Get(2);
		Title = EventDescription;
		If ScheduledJobName <> "" Then
			NameOfEvent = StrReplace(ScheduledJobName, "ScheduledJob.", "");
			
			SetPrivilegedMode(True);
			FilterByScheduledJobs = New Structure;
			ScheduledJobMetadata = Metadata.ScheduledJobs.Find(NameOfEvent);
			If ScheduledJobMetadata <> Undefined Then
				FilterByScheduledJobs.Insert("Metadata", ScheduledJobMetadata);
				If EventDescription <> Undefined Then
					FilterByScheduledJobs.Insert("Description", EventDescription);
				EndIf;
				SchedJob = ScheduledJobsServer.FindJobs(FilterByScheduledJobs);
				If SchedJob.Count() = 0 And FilterByScheduledJobs.Property("Description") Then
					FilterByScheduledJobs.Delete("Description");
					SchedJob = ScheduledJobsServer.FindJobs(FilterByScheduledJobs);
				EndIf;
				If ValueIsFilled(SchedJob) Then
					ScheduledJobID = SchedJob[0].UUID;
				EndIf;
			EndIf;
			SetPrivilegedMode(False);
		EndIf;
	Else
		Report = Parameters.Report;
		ScheduledJobID = Parameters.ScheduledJobID;
		Title = Parameters.Title;
	EndIf;
	
	Items.ModifySchedule.Visible = Common.SubsystemExists("StandardSubsystems.ScheduledJobs");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	StartDate = Details.Get(0);
	EndDate = Details.Get(1);
	ScheduledJobSession.Clear();
	ScheduledJobSession.Add(Details.Get(2)); 
	EventLogFilter = New Structure("Session, StartDate, EndDate", ScheduledJobSession, StartDate, EndDate);
	OpenForm("DataProcessor.EventLog.Form.EventLog", EventLogFilter);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConfigureJobSchedule(Command)
	
	If ValueIsFilled(ScheduledJobID) Then
		
		Dialog = New ScheduledJobDialog(GetSchedule());
		
		NotifyDescription = New NotifyDescription("ConfigureJobScheduleCompletion", ThisObject);
		Dialog.Show(NotifyDescription);
		
	Else
		ShowMessageBox(,NStr("en = 'Cannot change the scheduled job schedule: the scheduled job does not exist in this application version.';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLogCommand(Command)
	
	SelectedAreas = Items.Report.GetSelectedAreas();
	For Each Area In SelectedAreas Do
		If Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
			Details = Area.Details;
		Else
			Details = Undefined;
		EndIf;
		If Details = Undefined
			Or Area.Top <> Area.Bottom Then
			ShowMessageBox(,NStr("en = 'Select the job session line or cell.';"));
			Return;
		EndIf;
		StartDate = Details.Get(0);
		EndDate = Details.Get(1);
		ScheduledJobSession.Clear();
		ScheduledJobSession.Add(Details.Get(2));
		
		UniqueKey = String(StartDate) + "-" + EndDate + "-" + Details.Get(2);
		EventLogFilter = New Structure("Session, StartDate, EndDate", ScheduledJobSession, StartDate, EndDate);
		OpenForm("DataProcessor.EventLog.Form.EventLog", EventLogFilter, , UniqueKey);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = Common.CommonModule("ScheduledJobsServer");
	Return ModuleScheduledJobsServer.JobSchedule(ScheduledJobID);
	
EndFunction

&AtClient
Procedure ConfigureJobScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetJobSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule)
	
	SetPrivilegedMode(True);
	
	JobParameters = New Structure;
	JobParameters.Insert("Schedule", Schedule);
	ModuleScheduledJobsServer = Common.CommonModule("ScheduledJobsServer");
	ModuleScheduledJobsServer.ChangeJob(ScheduledJobID, JobParameters);
	
EndProcedure

#EndRegion
