///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ReportSettings.DefineFormSettings = True;
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersActivityAnalysis");
	OptionSettings.LongDesc = 
		NStr("en = 'Users activity in the application 
		|(total load and affected objects).';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserActivity");
	OptionSettings.LongDesc = 
		NStr("en = 'Objects affected by user activities
		|(detailed).';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "EventLogMonitor");
	OptionSettings.LongDesc = NStr("en = 'Event Log records with ""Critical"" importance.';");
	OptionSettings.SearchSettings.TemplatesNames = "EvengLogErrorReportTemplate";
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ScheduledJobsDuration");
	OptionSettings.LongDesc = NStr("en = 'Scheduled jobs schedule.';");
	OptionSettings.SearchSettings.TemplatesNames = "ScheduledJobsDuration, ScheduledJobsDetails";
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// Gets information on user activity during the specified period
// from the event log.
//
// Parameters:
//    ReportParameters - Structure:
//    * StartDate          - Date   - Beginning of the reporting period.
//    * EndDate       - Date   - End of the reporting period.
//    * User        - String - a user to analyze activity.
//                                     Use this parameter for the "User activity" report option.
//    * UsersAndGroups - ValueList - the values are user group(s) and/or
//                                     user(s) to analyze activity.
//                                     Use this parameter for the "User activity analysis" report option.
//    * ReportVariant       - String - "UserActivity" or "UsersActivityAnalysis".
//    * OutputTasks      - Boolean - Flag indicating whether to get data on tasks from the Event Log.
//    * OutputCatalogs - Boolean - Flag indicating whether to get data on catalogs from the Event Log.
//    * OutputDocuments   - Boolean - Flag indicating whether to get data on documents from the Event Log.
//    * OutputBusinessProcesses - Boolean - Flag indicating whether to get data on business processes from the Event Log.
//
// Returns:
//  ValueTable - 
//     
//
Function EventLogData1(ReportParameters) Export
	
	// Prepare report parameters.
	StartDate = ReportParameters.StartDate;
	EndDate = ReportParameters.EndDate;
	User = ReportParameters.User;
	UsersAndGroups = ReportParameters.UsersAndGroups;
	ReportVariant = ReportParameters.ReportVariant;
	
	If ReportVariant = "UserActivity" Then
		OutputBusinessProcesses = ReportParameters.OutputBusinessProcesses;
		OutputTasks = ReportParameters.OutputTasks;
		OutputCatalogs = ReportParameters.OutputCatalogs;
		OutputDocuments = ReportParameters.OutputDocuments;
	Else
		OutputCatalogs = True;
		OutputDocuments = True;
		OutputBusinessProcesses = False;
		OutputTasks = False;
	EndIf;
	
	// Generating source data table.
	RawData = New ValueTable();
	RawData.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	RawData.Columns.Add("Week", New TypeDescription("String", , New StringQualifiers(10)));
	RawData.Columns.Add("User");
	RawData.Columns.Add("WorkHours", New TypeDescription("Number", New NumberQualifiers(15,2)));
	RawData.Columns.Add("StartsCount", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("DocumentsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("CatalogsCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("DocumentsChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("BusinessProcessesCreated",	New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("TasksCreated", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("BusinessProcessesChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("TasksChanged", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("CatalogsChanged",	New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("Errors1", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("Warnings", New TypeDescription("Number", New NumberQualifiers(10)));
	RawData.Columns.Add("ObjectKind", New TypeDescription("String", , New StringQualifiers(50)));
	RawData.Columns.Add("CatalogDocumentObject");
	
	// Calculating the maximum number of concurrent sessions.
	ConcurrentSessionsData = New ValueTable();
	ConcurrentSessionsData.Columns.Add("ConcurrentUsersDate",
		New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	ConcurrentSessionsData.Columns.Add("ConcurrentUsers",
		New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessionsData.Columns.Add("ConcurrentUsersList");
	
	EventLogData = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	
	Events = New Array;
	Events.Add("_$Session$_.Start"); //  
	Events.Add("_$Session$_.Finish"); //    
	Events.Add("_$Data$_.New"); // 
	Events.Add("_$Data$_.Update"); // 
	
	ApplicationName = New Array;
	ApplicationName.Add("1CV8C");
	ApplicationName.Add("WebClient");
	ApplicationName.Add("1CV8");
	
	UserFilter = New Array;
	
	// Get a user list.
	If ReportVariant = "UserActivity" Then
		UserFilter.Add(IBUserName(User));
	ElsIf TypeOf(UsersAndGroups) = Type("ValueList") Then
		UsersToAnalyze(UserFilter, UsersAndGroups.UnloadValues());
	Else
		UsersToAnalyze(UserFilter, UsersAndGroups);
	EndIf;
	
	DatesInServerTimeZone = CommonClientServer.StructureProperty(ReportParameters, "DatesInServerTimeZone", False);
	If DatesInServerTimeZone Then
		ServerTimeOffset = 0;
	Else
		ServerTimeOffset = EventLog.ServerTimeOffset();
	EndIf;
	
	EventLogFilter = New Structure;
	EventLogFilter.Insert("StartDate", StartDate + ServerTimeOffset);
	EventLogFilter.Insert("EndDate", EndDate + ServerTimeOffset);
	EventLogFilter.Insert("ApplicationName", ApplicationName);
	EventLogFilter.Insert("Level", Levels);
	EventLogFilter.Insert("Event", Events);
	
	If UserFilter.Count() = 0 Then
		Return New Structure("UsersActivityAnalysis, ConcurrentSessionsData, ReportIsBlank", RawData, ConcurrentSessionsData, True);
	EndIf;
	
	If UserFilter.Find("AllUsers") = Undefined Then
		EventLogFilter.Insert("User", UserFilter);
	EndIf;
	
	SetPrivilegedMode(True);
	UnloadEventLog(EventLogData, EventLogFilter);
	SetPrivilegedMode(False);
	
	ReportIsBlank = (EventLogData.Count() = 0);
	
	EventLogData.Sort("Session, Date");
	
	// Add a UUID—UserRef map for future use.
	UsersIDs = EventLogData.UnloadColumn("User");
	UsersIDsMap = UsersUUIDs(UsersIDs);
	
	CurrentSession        = Undefined;
	WorkHours         = 0;
	StartsCount  = 0;
	DocumentsCreated   = 0;
	CatalogsCreated = 0;
	DocumentsChanged  = 0;
	CatalogsChanged= 0;
	ObjectKind          = Undefined;
	SourceDataString= Undefined;
	SessionStarted        = Undefined;
	
	// Calculating data required for the report.
	For Each EventLogDataRow In EventLogData Do
		DocumentsCreated       = 0;
		CatalogsCreated     = 0;
		DocumentsChanged      = 0;
		CatalogsChanged    = 0;
		BusinessProcessesCreated  = 0;
		BusinessProcessesChanged = 0;
		TasksChanged           = 0;
		TasksCreated            = 0;
		ObjectKind              = Undefined;
		
		EventLogDataRow.Date = EventLogDataRow.Date - ServerTimeOffset;
		If EventLogDataRow.UserName = "" Then
			Continue;
		EndIf;
		Session = EventLogDataRow.Session; 
		
		If Not ValueIsFilled(EventLogDataRow.Session)
			Or Not ValueIsFilled(EventLogDataRow.Date) Then
			Continue;
		EndIf;
		
		UsernameRef = UsersIDsMap[EventLogDataRow.User];
		
		// Calculating the duration of user activity and the number of times the application was started.
		If CurrentSession <> Session
			Or EventLogDataRow.Event = "_$Session$_.Start" Then
			If SourceDataString <> Undefined Then
				SourceDataString.WorkHours  = WorkHours;
				SourceDataString.StartsCount = StartsCount;
			EndIf;
			SourceDataString = RawData.Add();
			SourceDataString.Date		  = EventLogDataRow.Date;
			SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			SourceDataString.User = UsernameRef;
			WorkHours			= 0;
			StartsCount	= 0; 
			CurrentSession			= Session; 
			SessionStarted		= EventLogDataRow.Date;
		EndIf;
		
		If EventLogDataRow.Event = "_$Session$_.Finish" Then
			
			StartsCount	= StartsCount + 1;
			If SessionStarted <> Undefined Then 
				
				// Checking whether a user session has ended the day it had started, or the next day.
				If BegOfDay(EventLogDataRow.Date) > BegOfDay(SessionStarted) Then
					// If the session is extended overnight, fill in the work hours for the previous day.
					Diff = EndOfDay(SessionStarted) - SessionStarted;
					WorkHours = Diff/60/60;
					SourceDataString.WorkHours = WorkHours;
					SessionDay = EndOfDay(SessionStarted) + 86400;
					While EndOfDay(EventLogDataRow.Date) > SessionDay Do
						SourceDataString = RawData.Add();
						SourceDataString.Date = SessionDay;
						SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
						SourceDataString.User = UsernameRef;
						WorkHours = (SessionDay - BegOfDay(SessionDay))/60/60;
						SourceDataString.WorkHours  = WorkHours;
						SessionDay = SessionDay + 86400;
					EndDo;	
					SourceDataString = RawData.Add();
					SourceDataString.Date = EventLogDataRow.Date;
					SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
					SourceDataString.User = UsernameRef;
					WorkHours = (EventLogDataRow.Date - BegOfDay(SessionDay))/60/60;
					SourceDataString.WorkHours  = WorkHours;
				Else
					Diff =  (EventLogDataRow.Date - SessionStarted)/60/60;
					WorkHours = WorkHours + Diff;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		// Calculating the number of created documents and catalogs.
		If EventLogDataRow.Event = "_$Data$_.New" Then
			
			If StrFind(EventLogDataRow.Metadata, "Document.") > 0 
				And OutputDocuments Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				DocumentsCreated = DocumentsCreated + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.DocumentsCreated = DocumentsCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date); 
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Catalog.") > 0
				And OutputCatalogs Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				CatalogsCreated = CatalogsCreated + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogsCreated = CatalogsCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of changed documents and catalogs.
		If EventLogDataRow.Event = "_$Data$_.Update" Then
			
			If StrFind(EventLogDataRow.Metadata, "Document.") > 0
				And OutputDocuments Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				DocumentsChanged = DocumentsChanged + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.DocumentsChanged = DocumentsChanged;  	
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Catalog.") > 0
				And OutputCatalogs Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				CatalogsChanged = CatalogsChanged + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.CatalogsChanged = CatalogsChanged;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of created BusinessProcesses and Tasks.
		If EventLogDataRow.Event = "_$Data$_.New" Then
			
			If StrFind(EventLogDataRow.Metadata, "BusinessProcess.") > 0 
				And OutputBusinessProcesses Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				BusinessProcessesCreated = BusinessProcessesCreated + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.BusinessProcessesCreated = BusinessProcessesCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date); 
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Task.") > 0 
				And OutputTasks Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				TasksCreated = TasksCreated + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.TasksCreated = TasksCreated;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
		// Calculating the number of changed BusinessProcesses and Tasks.
		If EventLogDataRow.Event = "_$Data$_.Update" Then
			
			If StrFind(EventLogDataRow.Metadata, "BusinessProcess.") > 0
				And OutputBusinessProcesses Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				BusinessProcessesChanged = BusinessProcessesChanged + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.BusinessProcessesChanged = BusinessProcessesChanged;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
			If StrFind(EventLogDataRow.Metadata, "Task.") > 0 
				And OutputTasks Then
				ObjectKind = EventLogDataRow.MetadataPresentation;
				CatalogDocumentObject = EventLogDataRow.Data;
				TasksChanged = TasksChanged + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date		  = EventLogDataRow.Date;
				SourceDataString.User = UsernameRef;
				SourceDataString.ObjectKind = ObjectKind;
				SourceDataString.TasksChanged = TasksChanged;
				SourceDataString.CatalogDocumentObject = CatalogDocumentObject;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If SourceDataString <> Undefined Then
		SourceDataString.WorkHours  = WorkHours;
		SourceDataString.StartsCount = StartsCount;
	EndIf;
	
	If ReportVariant = "UsersActivityAnalysis" Then
	
		EventLogData.Sort("Date");
		
		UsersArray 	= New Array;
		MaxUsersArray = New Array;
		ConcurrentUsers  = 0;
		Counter                 = 0;
		CurrentDate             = Undefined;
		
		For Each EventLogDataRow In EventLogData Do
			
			If Not ValueIsFilled(EventLogDataRow.Date)
				Or EventLogDataRow.UserName = "" Then
				Continue;
			EndIf;
			
			UsernameRef = UsersIDsMap[EventLogDataRow.User];
			If UsernameRef = Undefined Then
				Continue;
			EndIf;
			
			UsernameRow = IBUserName(UsernameRef);
			
			ConcurrentUsersDate = BegOfDay(EventLogDataRow.Date);
			
			// If the day is changed, clearing all concurrent sessions data and filling the data for the previous day.
			If CurrentDate <> ConcurrentUsersDate Then
				If ConcurrentUsers <> 0 Then
					GenerateConcurrentSessionsRow(ConcurrentSessionsData, MaxUsersArray, 
						ConcurrentUsers, CurrentDate);
				EndIf;
				ConcurrentUsers = 0;
				Counter    = 0;
				UsersArray.Clear();
				CurrentDate = ConcurrentUsersDate;
			EndIf;
			
			If EventLogDataRow.Event = "_$Session$_.Start" Then
				Counter = Counter + 1;
				UsersArray.Add(UsernameRow);
			ElsIf EventLogDataRow.Event = "_$Session$_.Finish" Then
				UserIndex = UsersArray.Find(UsernameRow);
				If Not UserIndex = Undefined Then 
					UsersArray.Delete(UserIndex);
					Counter = Counter - 1;
				EndIf;
			EndIf;
			
			// 
			Counter = Max(Counter, 0);
			If Counter > ConcurrentUsers Then
				MaxUsersArray = New Array;
				For Each Item In UsersArray Do
					MaxUsersArray.Add(Item);
				EndDo;
			EndIf;
			ConcurrentUsers = Max(ConcurrentUsers, Counter);
			
		EndDo;
		
		If ConcurrentUsers <> 0 Then
			GenerateConcurrentSessionsRow(ConcurrentSessionsData, MaxUsersArray, 
				ConcurrentUsers, CurrentDate);
		EndIf;
		
		// 
		EventLogData = Undefined;
		Errors1 					 = 0;
		Warnings			 = 0;
		EventLogData = EventLogErrorsInformation(StartDate, EndDate, ServerTimeOffset);
		
		ReportIsBlank =  ReportIsBlank Or (EventLogData.Count() = 0);
		
		For Each EventLogDataRow In EventLogData Do
			
			If EventLogDataRow.UserName = "" Then
				Continue;
			EndIf;
			
			If UserFilter.Find(EventLogDataRow.UserName) = Undefined
				And UserFilter.Count() <> 0 Then
				Continue;
			EndIf;
			
			UsernameRef = UsersIDsMap[EventLogDataRow.User];
			
			If EventLogDataRow.Level = EventLogLevel.Error Then
				Errors1 = Errors1 + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date = EventLogDataRow.Date;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
				SourceDataString.User = UsernameRef;
				SourceDataString.Errors1 = Errors1;
			EndIf;
			
			If EventLogDataRow.Level = EventLogLevel.Warning Then
				Warnings = Warnings + 1;
				SourceDataString = RawData.Add();
				SourceDataString.Date = EventLogDataRow.Date;
				SourceDataString.Week 	  = WeekOfYearString(EventLogDataRow.Date);
				SourceDataString.User = UsernameRef;
				SourceDataString.Warnings = Warnings;
			EndIf;
			
			Errors1         = 0;
			Warnings = 0;
		EndDo;
		
	EndIf;
	
	Return New Structure("UsersActivityAnalysis, ConcurrentSessionsData, ReportIsBlank", RawData, ConcurrentSessionsData, ReportIsBlank);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Analyze user activities.

Function UsersToAnalyze(UserFilter, Val UsersAndGroups)
	
	If Not TypeOf(UsersAndGroups) = Type("Array") Then
		UsersAndGroups = CommonClientServer.ValueInArray(UsersAndGroups);
	EndIf;
	
	GroupToRetrieveUsers = New Array;
	AllUsers = Catalogs.UserGroups.AllUsers;
	For Each UserOrGroup In UsersAndGroups Do
		If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
			IBUserName = IBUserName(UserOrGroup);
			
			If IBUserName <> Undefined Then
				UserFilter.Add(IBUserName);
			EndIf;
		ElsIf UserOrGroup = AllUsers Then
			UserFilter.Add("AllUsers");
			Return UserFilter;
		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
			GroupToRetrieveUsers.Add(UserOrGroup);
		EndIf;
	EndDo;
	
	If GroupToRetrieveUsers.Count() > 0 Then
		
		Query = New Query;
		Query.SetParameter("Group", GroupToRetrieveUsers);
		Query.Text = 
			"SELECT DISTINCT
			|	UserGroupCompositions.User AS User
			|FROM
			|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
			|WHERE
			|	UserGroupCompositions.UsersGroup IN
			|			(SELECT
			|				UserGroups.Ref AS Ref
			|			FROM
			|				Catalog.UserGroups AS UserGroups
			|			WHERE
			|				UserGroups.Ref IN HIERARCHY (&Group))";
		Result = Query.Execute().Unload();
		
		For Each String In Result Do
			IBUserName = IBUserName(String.User);
			
			If IBUserName <> Undefined Then
				UserFilter.Add(IBUserName);
			EndIf;
		
		EndDo;
		
	EndIf;
	
	Return UserFilter;
EndFunction

Function UsersUUIDs(UsersIDs)
	UsersUUIDsArray = New Array;
	
	CommonClientServer.SupplementArray(UsersUUIDsArray,
		UsersIDs, True);
	UUIDMap = New Map;
	For Each Item In UsersUUIDsArray Do
		
		If ValueIsFilled(Item) Then
			UsernameRef = UserRef(Item);
			IBUserID = Common.ObjectAttributeValue(UsernameRef, "IBUserID");
			
			If IBUserID <> Undefined Then
				UUIDMap.Insert(Item, UsernameRef);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return UUIDMap;
EndFunction

Function UserRef(UUIDUser)
	Return Catalogs.Users.FindByAttribute("IBUserID", UUIDUser);
EndFunction

Function IBUserName(UserRef) Export
	SetPrivilegedMode(True);
	IBUserID = Common.ObjectAttributeValue(UserRef, "IBUserID");
	IBUser = InfoBaseUsers.FindByUUID(IBUserID);
	
	If IBUser <> Undefined Then
		Return IBUser.Name; 
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function WeekOfYearString(DateInYear)
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Week %1';"), WeekOfYear(DateInYear));
EndFunction

Procedure GenerateConcurrentSessionsRow(ConcurrentSessionsData, MaxUsersArray,
			ConcurrentUsers, CurrentDate)
	
	TemporaryArray = New Array;
	IndexOf = 0;
	For Each Item In MaxUsersArray Do
		TemporaryArray.Insert(IndexOf, Item);
		UserSessionsCounter = 0;
		
		For Each UserName In TemporaryArray Do
			If UserName = Item Then
				UserSessionsCounter = UserSessionsCounter + 1;
				UserAndNumber = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2)';"),
					Item,
					UserSessionsCounter);
			EndIf;
		EndDo;
		
		TableRow = ConcurrentSessionsData.Add();
		TableRow.ConcurrentUsersDate = CurrentDate;
		TableRow.ConcurrentUsers = ConcurrentUsers;
		TableRow.ConcurrentUsersList = UserAndNumber;
		IndexOf = IndexOf + 1;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Duration of scheduled jobs.

// Generates a report on scheduled jobs.
//
// Parameters:
//   FillParameters - Structure - a set of parameters required for the report where:
//     * StartDate    - Date - Beginning of the reporting period.
//     * EndDate - Date - the end of the report period.
//   ConcurrentSessionsSize - Number - the minimum number of concurrent scheduled jobs
//                                      to display in the table.
//   MinScheduledJobSessionDuration - Number - the minimum duration of a scheduled job session
//                                                                    (in seconds).
//   DisplayBackgroundJobs - Boolean - if True, display a line with intervals of background jobs sessions
//                                       on the Gantt chart.
//   OutputTitle - DataCompositionTextOutputType - shows whether to show the title.
//   OutputFilter - DataCompositionTextOutputType - shows whether to show the filter.
//   HideScheduledJobs - ValueList - a list of scheduled jobs to exclude from the report.
//
Function GenerateScheduledJobsDurationReport(FillParameters) Export
	
	// Report parameters.
	StartDate = FillParameters.StartDate;
	EndDate = FillParameters.EndDate;
	MinScheduledJobSessionDuration = 
		FillParameters.MinScheduledJobSessionDuration;
	OutputTitle = FillParameters.OutputTitle;
	FilterOutput = FillParameters.FilterOutput;
	
	Result = New Structure;
	Report = New SpreadsheetDocument;
	
	// Getting data to generate the report.
	GetData = DataForScheduledJobsDurationsReport(FillParameters);
	ScheduledJobsSessionsTable = GetData.ScheduledJobsSessionsTable;
	ConcurrentSessionsData = GetData.TotalConcurrentScheduledJobs;
	StartsCount = GetData.StartsCount;
	ReportIsBlank        = GetData.ReportIsBlank;
	Template = GetTemplate("ScheduledJobsDuration");
	
	// A set of colors for the chart and table backgrounds.
	BackColors = New Array;
	BackColors.Add(WebColors.White);
	BackColors.Add(WebColors.LightYellow);
	BackColors.Add(WebColors.LemonChiffon);
	BackColors.Add(WebColors.NavajoWhite);
	
	// Generate a report header.
	If OutputTitle.Value = DataCompositionTextOutputType.Output
		And OutputTitle.Use
		Or Not OutputTitle.Use Then
		Report.Put(TemplateAreaDetails(Template, "ReportHeader1"));
	EndIf;
	
	If FilterOutput.Value = DataCompositionTextOutputType.Output
		And FilterOutput.Use
		Or Not FilterOutput.Use Then
		Area = TemplateAreaDetails(Template, "Filter");
		If MinScheduledJobSessionDuration > 0 Then
			IntervalsViewMode = NStr("en = 'Hide intervals with zero duration';");
		Else
			IntervalsViewMode = NStr("en = 'Show intervals with zero duration';");
		EndIf;
		Area.Parameters.StartDate = StartDate;
		Area.Parameters.EndDate = EndDate;
		Area.Parameters.IntervalsViewMode = IntervalsViewMode;
		Report.Put(Area);
	EndIf;
	
	If ValueIsFilled(ConcurrentSessionsData) Then
	
		Report.Put(TemplateAreaDetails(Template, "TableHeader"));
		
		// Generating a table of the maximum number of concurrent scheduled jobs.
		CurrentSessionsCount = 0; 
		ColorIndex = 3;
		For Each ConcurrentSessionsRow In ConcurrentSessionsData Do
			Area = TemplateAreaDetails(Template, "Table");
			If CurrentSessionsCount <> 0 
				And CurrentSessionsCount <> ConcurrentSessionsRow.ConcurrentScheduledJobs
				And ColorIndex <> 0 Then
				ColorIndex = ColorIndex - 1;
			EndIf;
			If ConcurrentSessionsRow.ConcurrentScheduledJobs = 1 Then
				ColorIndex = 0;
			EndIf;
			Area.Parameters.Fill(ConcurrentSessionsRow);
			TableBackColor = BackColors.Get(ColorIndex);
			TableArea = Area.Areas.Table; // SpreadsheetDocumentRange
			TableArea.BackColor = TableBackColor;
			Report.Put(Area);
			CurrentSessionsCount = ConcurrentSessionsRow.ConcurrentScheduledJobs;
			ScheduledJobsArray = ConcurrentSessionsRow.ScheduledJobsList;
			ScheduledJobIndex = 0;
			Report.StartRowGroup(, False);
			For Each Item In ScheduledJobsArray Do
				If Not TypeOf(Item) = Type("Number")
					And Not TypeOf(Item) = Type("Date") Then
					Area = TemplateAreaDetails(Template, "ScheduledJobsList");
					Area.Parameters.ScheduledJobsList = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (session %2)';"),
						Item,
						ScheduledJobsArray[ScheduledJobIndex+1]);
				ElsIf Not TypeOf(Item) = Type("Date")
					And Not TypeOf(Item) = Type("String") Then	
					Area.Parameters.JobDetails1 = New Array;
					Area.Parameters.JobDetails1.Add("ScheduledJobDetails1");
					Area.Parameters.JobDetails1.Add(Item);
					ScheduledJobName = ScheduledJobsArray.Get(ScheduledJobIndex-1);
					Area.Parameters.JobDetails1.Add(ScheduledJobName);
					Area.Parameters.JobDetails1.Add(StartDate);
					Area.Parameters.JobDetails1.Add(EndDate);
					Report.Put(Area);
				EndIf;
				ScheduledJobIndex = ScheduledJobIndex + 1;
			EndDo;
			Report.EndRowGroup();
		EndDo;
	EndIf;
	
	Report.Put(TemplateAreaDetails(Template, "IsBlankString"));
	
	// 
	Area = TemplateAreaDetails(Template, "Chart");
	GanttChart = Area.Drawings.GanttChart.Object; // GanttChart
	GanttChart.RefreshEnabled = False;  
	
	Series = GanttChart.Series.Add();

	CurrentEvent			 = Undefined;
	OverallScheduledJobsDuration = 0;
	Point					 = Undefined;
	StartsCountRow = Undefined;
	ScheduledJobStarts = 0;
	PointChangedFlag        = False;
	
	// Populate the Gantt chart.	
	For Each ScheduledJobsRow In ScheduledJobsSessionsTable Do
		ScheduledJobIntervalDuration =
			ScheduledJobsRow.JobEndDate - ScheduledJobsRow.JobStartDate;
		If ScheduledJobIntervalDuration >= MinScheduledJobSessionDuration Then
			If CurrentEvent <> ScheduledJobsRow.NameOfEvent Then
				If CurrentEvent <> Undefined
					And PointChangedFlag Then
					DetailsPoint = Point.Details; // Array
					DetailsPoint.Add(ScheduledJobStarts);
					DetailsPoint.Add(OverallScheduledJobsDuration);
					DetailsPoint.Add(StartDate);
					DetailsPoint.Add(EndDate);
					PointName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2 out of %3)';"),
						Point.Value,
						ScheduledJobStarts,
						String(StartsCountRow.Starts));
					Point.Value = PointName;
				EndIf;
				StartsCountRow = StartsCount.Find(
					ScheduledJobsRow.NameOfEvent, "NameOfEvent");
				// Leaving the details of background jobs blank.
				If ScheduledJobsRow.EventMetadata <> "" Then 
					PointName = ScheduledJobsRow.NameOfEvent;
					Point = GanttChart.SetPoint(PointName);
					DetailsPoint  = New Array;
					IntervalStart	  = New Array;
					IntervalEnd	  = New Array;
					ScheduledJobSession = New Array;
					DetailsPoint.Add("DetailsPoint");
					DetailsPoint.Add(ScheduledJobsRow.EventMetadata);
					DetailsPoint.Add(ScheduledJobsRow.NameOfEvent);
					DetailsPoint.Add(StartsCountRow.Canceled);
					DetailsPoint.Add(StartsCountRow.ExecutionError);                                                             
					DetailsPoint.Add(IntervalStart);
					DetailsPoint.Add(IntervalEnd);
					DetailsPoint.Add(ScheduledJobSession);
					DetailsPoint.Add(MinScheduledJobSessionDuration);
					Point.Details = DetailsPoint;
					CurrentEvent = ScheduledJobsRow.NameOfEvent;
					OverallScheduledJobsDuration = 0;				
					ScheduledJobStarts = 0;
					Point.Picture = PictureLib.ScheduledJob;
				ElsIf Not ValueIsFilled(ScheduledJobsRow.EventMetadata) Then
					PointName = NStr("en = 'Background jobs';");
					Point = GanttChart.SetPoint(PointName);
					OverallScheduledJobsDuration = 0;
				EndIf;
			EndIf;
			Value = GanttChart.GetValue(Point, Series);
			Interval = Value.Add();
			Interval.Begin = ScheduledJobsRow.JobStartDate;
			Interval.End = ScheduledJobsRow.JobEndDate;
			Interval.Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 - %2';"),
				Format(Interval.Begin, "DLF=T"),
				Format(Interval.End, "DLF=T"));
			PointChangedFlag = False;
			// Leaving the details of background jobs blank.
			If ScheduledJobsRow.EventMetadata <> "" Then
				IntervalStart.Add(ScheduledJobsRow.JobStartDate);
				IntervalEnd.Add(ScheduledJobsRow.JobEndDate);
				ScheduledJobSession.Add(ScheduledJobsRow.Session);
				OverallScheduledJobsDuration = ScheduledJobIntervalDuration + OverallScheduledJobsDuration;
				ScheduledJobStarts = ScheduledJobStarts + 1;
				PointChangedFlag = True;
			EndIf;
		EndIf;
	EndDo; 
	
	If ScheduledJobStarts <> 0
		And ValueIsFilled(Point.Details) Then
		// 
		DetailsPoint = Point.Details; // Array
		DetailsPoint.Add(ScheduledJobStarts);
		DetailsPoint.Add(OverallScheduledJobsDuration);
		DetailsPoint.Add(StartDate);
		DetailsPoint.Add(EndDate);	
		PointName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2 out of %3)';"),
			Point.Value,
			ScheduledJobStarts,
			String(StartsCountRow.Starts));
		Point.Value = PointName;
	EndIf;
		
	// Setting up chart view settings.
	GanttChartColors(StartDate, GanttChart, ConcurrentSessionsData, BackColors);
	AnalysisPeriod = EndDate - StartDate;
	GanttChartTimescale(GanttChart, AnalysisPeriod);
	
	ColumnsCount = GanttChart.Points.Count();
	Area.Drawings.GanttChart.Height				 = 15 + 10 * ColumnsCount;
	Area.Drawings.GanttChart.Width 				 = 450;
	GanttChart.AutoDetectWholeInterval	 = False; 
	GanttChart.IntervalRepresentation   			 = GanttChartIntervalRepresentation.Flat;
	GanttChart.LegendArea.Placement       = ChartLegendPlacement.None;
	GanttChart.VerticalStretch 			 = GanttChartVerticalStretch.StretchRowsAndData;
	GanttChart.SetWholeInterval(StartDate, EndDate);
	GanttChart.RefreshEnabled = True;

	Report.Put(Area);
	
	Result.Insert("Report", Report);
	Result.Insert("ReportIsBlank", ReportIsBlank);
	Return Result;
EndFunction

// Gets scheduled jobs data from the Event Log.
//
// Parameters:
//   FillParameters - Structure - a set of parameters required for the report:
//   * StartDate    - Date - Beginning of the reporting period.
//   * EndDate - Date - End of the reporting period.
//   * ConcurrentSessionsSize	- Number - the minimum number of concurrent scheduled jobs
// 		to display in the table.
//   * MinScheduledJobSessionDuration - Number - Min scheduled job session duration in seconds.
// 		
//   * DisplayBackgroundJobs - Boolean - if True, display a line with intervals of background jobs sessions 
// 		on the Gantt chart.
//   * HideScheduledJobs - ValueList - a list of scheduled jobs to exclude from the report.
//
// Returns
//   ValueTable - the table that contains scheduled jobs data
//     from the event log.
//
Function DataForScheduledJobsDurationsReport(FillParameters)
	
	StartDate = FillParameters.StartDate;
	EndDate = FillParameters.EndDate;
	ConcurrentSessionsSize = FillParameters.ConcurrentSessionsSize;
	DisplayBackgroundJobs = FillParameters.DisplayBackgroundJobs;
	MinScheduledJobSessionDuration =
		FillParameters.MinScheduledJobSessionDuration;
	HideScheduledJobs = FillParameters.HideScheduledJobs;
	ServerTimeOffset = FillParameters.ServerTimeOffset;
	
	EventLogData = New ValueTable;
	
	Levels = New Array;
	Levels.Add(EventLogLevel.Information);
	Levels.Add(EventLogLevel.Warning);
	Levels.Add(EventLogLevel.Error);
	
	ScheduledJobEvents = New Array;
	ScheduledJobEvents.Add("_$Job$_.Start");
	ScheduledJobEvents.Add("_$Job$_.Cancel");
	ScheduledJobEvents.Add("_$Job$_.Fail");
	ScheduledJobEvents.Add("_$Job$_.Succeed");
	ScheduledJobEvents.Add("_$Job$_.Finish");
	ScheduledJobEvents.Add("_$Job$_.Error");
	
	SetPrivilegedMode(True);
	LogFilter = New Structure;
	LogFilter.Insert("Level", Levels);
	LogFilter.Insert("StartDate", StartDate + ServerTimeOffset);
	LogFilter.Insert("EndDate", EndDate + ServerTimeOffset);
	LogFilter.Insert("Event", ScheduledJobEvents);
	
	UnloadEventLog(EventLogData, LogFilter);
	ReportIsBlank = (EventLogData.Count() = 0);
	
	If ServerTimeOffset <> 0 Then
		For Each TableRow In EventLogData Do
			TableRow.Date = TableRow.Date - ServerTimeOffset;
		EndDo;
	EndIf;
	
	// Generate data for the filter by scheduled jobs.
	AllScheduledJobsList = ScheduledJobsServer.FindJobs(New Structure);
	MetadataIDMap = New Map;
	MetadataNameMap = New Map;
	DescriptionIDMap = New Map;
	SetPrivilegedMode(False);
	
	For Each SchedJob In AllScheduledJobsList Do
		MetadataIDMap.Insert(SchedJob.Metadata, String(SchedJob.UUID));
		DescriptionIDMap.Insert(SchedJob.Description, String(SchedJob.UUID));
		If SchedJob.Description <> "" Then
			MetadataNameMap.Insert(SchedJob.Metadata, SchedJob.Description);
		Else
			MetadataNameMap.Insert(SchedJob.Metadata, SchedJob.Metadata.Synonym);
		EndIf;
	EndDo;
	
	// Populate parameters required for defining concurrent scheduled jobs.
	ConcurrentSessionsParameters = New Structure;
	ConcurrentSessionsParameters.Insert("EventLogData", EventLogData);
	ConcurrentSessionsParameters.Insert("DescriptionIDMap", DescriptionIDMap);
	ConcurrentSessionsParameters.Insert("MetadataIDMap", MetadataIDMap);
	ConcurrentSessionsParameters.Insert("MetadataNameMap", MetadataNameMap);
	ConcurrentSessionsParameters.Insert("HideScheduledJobs", HideScheduledJobs);
	ConcurrentSessionsParameters.Insert("MinScheduledJobSessionDuration",
		MinScheduledJobSessionDuration);
	
	// The maximum number of concurrent scheduled jobs sessions.
	ConcurrentSessionsData = ConcurrentScheduledJobs(ConcurrentSessionsParameters);
	
	// 
	ConcurrentSessionsData.Sort("ConcurrentScheduledJobs Desc");
	
	TotalConcurrentScheduledJobsRow = Undefined;
	TotalConcurrentScheduledJobs = New ValueTable();
	TotalConcurrentScheduledJobs.Columns.Add("ConcurrentScheduledJobsDate", 
		New TypeDescription("String", , New StringQualifiers(50)));
	TotalConcurrentScheduledJobs.Columns.Add("ConcurrentScheduledJobs", 
		New TypeDescription("Number", New NumberQualifiers(10))); 
	TotalConcurrentScheduledJobs.Columns.Add("ScheduledJobsList");
	
	For Each ConcurrentSessionsRow In ConcurrentSessionsData Do
		If ConcurrentSessionsRow.ConcurrentScheduledJobs >= ConcurrentSessionsSize
			And ConcurrentSessionsRow.ConcurrentScheduledJobs >= 2 Then
			TotalConcurrentScheduledJobsRow = TotalConcurrentScheduledJobs.Add();
			TotalConcurrentScheduledJobsRow.ConcurrentScheduledJobsDate = 
				ConcurrentSessionsRow.ConcurrentScheduledJobsDate;
			TotalConcurrentScheduledJobsRow.ConcurrentScheduledJobs = 
				ConcurrentSessionsRow.ConcurrentScheduledJobs;
			TotalConcurrentScheduledJobsRow.ScheduledJobsList = 
				ConcurrentSessionsRow.ScheduledJobsList;
		EndIf;
	EndDo;
	
	EventLogData.Sort("Metadata, Data, Date, Session");
	
	// Populate parameters required for getting data by scheduled jobs session.
	ScheduledJobsSessionsParameters = New Structure;
	ScheduledJobsSessionsParameters.Insert("EventLogData", EventLogData);
	ScheduledJobsSessionsParameters.Insert("DescriptionIDMap", DescriptionIDMap);
	ScheduledJobsSessionsParameters.Insert("MetadataIDMap", MetadataIDMap);
	ScheduledJobsSessionsParameters.Insert("MetadataNameMap", MetadataNameMap);
	ScheduledJobsSessionsParameters.Insert("DisplayBackgroundJobs", DisplayBackgroundJobs);
	ScheduledJobsSessionsParameters.Insert("HideScheduledJobs", HideScheduledJobs);
	
	// Scheduled jobs.
	ScheduledJobsSessionsTable = 
		ScheduledJobsSessions(ScheduledJobsSessionsParameters).ScheduledJobsSessionsTable;
	StartsCount = ScheduledJobsSessions(ScheduledJobsSessionsParameters).StartsCount;
	
	Result = New Structure;
	Result.Insert("ScheduledJobsSessionsTable", ScheduledJobsSessionsTable);
	Result.Insert("TotalConcurrentScheduledJobs", TotalConcurrentScheduledJobs);
	Result.Insert("StartsCount", StartsCount);
	Result.Insert("ReportIsBlank", ReportIsBlank);
	
	Return Result;
EndFunction

Function ConcurrentScheduledJobs(ConcurrentSessionsParameters)
	
	EventLogData 			  = ConcurrentSessionsParameters.EventLogData;
	DescriptionIDMap = ConcurrentSessionsParameters.DescriptionIDMap;
	MetadataIDMap   = ConcurrentSessionsParameters.MetadataIDMap;
	MetadataNameMap 		  = ConcurrentSessionsParameters.MetadataNameMap;
	HideScheduledJobs 			  = ConcurrentSessionsParameters.HideScheduledJobs;
	MinScheduledJobSessionDuration = ConcurrentSessionsParameters.	
		MinScheduledJobSessionDuration;
										
	ConcurrentSessionsData = New ValueTable();
	
	ConcurrentSessionsData.Columns.Add("ConcurrentScheduledJobsDate",
										New TypeDescription("String", , New StringQualifiers(50)));
	ConcurrentSessionsData.Columns.Add("ConcurrentScheduledJobs",
										New TypeDescription("Number", New NumberQualifiers(10)));
	ConcurrentSessionsData.Columns.Add("ScheduledJobsList");
	
	ScheduledJobsArray = New Array;
	
	ConcurrentScheduledJobs	  = 0;
	Counter     				  = 0;
	CurrentDate 					  = Undefined;
	TableRow 				  = Undefined;
	MaxScheduledJobsArray = Undefined;
	
	For Each EventLogDataRow In EventLogData Do 
		If Not ValueIsFilled(EventLogDataRow.Date)
			Or Not ValueIsFilled(EventLogDataRow.Metadata) Then
			Continue;
		EndIf;
		
		NameAndUUID = ScheduledJobSessionNameAndUUID(
			EventLogDataRow, DescriptionIDMap,
			MetadataIDMap, MetadataNameMap);
			
		ScheduledJobName1 = NameAndUUID.SessionName;
		ScheduledJobUUID = 
			NameAndUUID.ScheduledJobUUID;
		
		If Not HideScheduledJobs = Undefined
			And Not TypeOf(HideScheduledJobs) = Type("String") Then
			ScheduledJobsFilter = HideScheduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not ScheduledJobsFilter = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideScheduledJobs = Undefined
			And TypeOf(HideScheduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideScheduledJobs Then
				Continue;
			EndIf;
		EndIf;	
		
		ConcurrentScheduledJobsDate = BegOfHour(EventLogDataRow.Date);
		
		If CurrentDate <> ConcurrentScheduledJobsDate Then
			If TableRow <> Undefined Then
				TableRow.ConcurrentScheduledJobs = ConcurrentScheduledJobs;
				TableRow.ConcurrentScheduledJobsDate = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 - %2';"),
					Format(CurrentDate, "DLF=T"),
					Format(EndOfHour(CurrentDate), "DLF=T"));
				TableRow.ScheduledJobsList = MaxScheduledJobsArray;
			EndIf;
			TableRow = ConcurrentSessionsData.Add();
			ConcurrentScheduledJobs = 0;
			Counter    = 0;
			ScheduledJobsArray.Clear();
			CurrentDate = ConcurrentScheduledJobsDate;
		EndIf;
		
		If EventLogDataRow.Event = "_$Job$_.Start" Then
			Counter = Counter + 1;
			ScheduledJobsArray.Add(ScheduledJobName1);
			ScheduledJobsArray.Add(EventLogDataRow.Session);
			ScheduledJobsArray.Add(EventLogDataRow.Date);
		Else
			ScheduledJobIndex = ScheduledJobsArray.Find(ScheduledJobName1);
			If ScheduledJobIndex = Undefined Then 
				Continue;
			EndIf;
			
			If ValueIsFilled(MaxScheduledJobsArray) Then
				ArrayStringIndex = MaxScheduledJobsArray.Find(ScheduledJobName1);
				If ArrayStringIndex <> Undefined 
					And MaxScheduledJobsArray[ArrayStringIndex+1] = ScheduledJobsArray[ScheduledJobIndex+1]
					And EventLogDataRow.Date - MaxScheduledJobsArray[ArrayStringIndex+2] <
						MinScheduledJobSessionDuration Then
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					MaxScheduledJobsArray.Delete(ArrayStringIndex);
					ConcurrentScheduledJobs = ConcurrentScheduledJobs - 1;
				EndIf;
			EndIf;    						
			ScheduledJobsArray.Delete(ScheduledJobIndex);
			ScheduledJobsArray.Delete(ScheduledJobIndex); // 
			ScheduledJobsArray.Delete(ScheduledJobIndex); // 
			Counter = Counter - 1;
		EndIf;
		
		Counter = Max(Counter, 0);
		If Counter > ConcurrentScheduledJobs Then
			MaxScheduledJobsArray = New Array;
			For Each Item In ScheduledJobsArray Do
				MaxScheduledJobsArray.Add(Item);
			EndDo;
		EndIf;
		ConcurrentScheduledJobs = Max(ConcurrentScheduledJobs, Counter);
	EndDo;
		
	If ConcurrentScheduledJobs <> 0 Then
		TableRow.ConcurrentScheduledJobs  = ConcurrentScheduledJobs;
		TableRow.ConcurrentScheduledJobsDate = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 - %2';"),
			Format(CurrentDate, "DLF=T"),
			Format(EndOfHour(CurrentDate), "DLF=T"));
		TableRow.ScheduledJobsList = MaxScheduledJobsArray;
	EndIf;
	
	Return ConcurrentSessionsData;
EndFunction

Function ScheduledJobsSessions(ScheduledJobsSessionsParameters)

	EventLogData = ScheduledJobsSessionsParameters.EventLogData;
	DescriptionIDMap = ScheduledJobsSessionsParameters.DescriptionIDMap;
	MetadataIDMap = ScheduledJobsSessionsParameters.MetadataIDMap;
	MetadataNameMap = ScheduledJobsSessionsParameters.MetadataNameMap;
	HideScheduledJobs = ScheduledJobsSessionsParameters.HideScheduledJobs;
	DisplayBackgroundJobs = ScheduledJobsSessionsParameters.DisplayBackgroundJobs;  
	
	ScheduledJobsSessionsTable = New ValueTable();
	ScheduledJobsSessionsTable.Columns.Add("JobStartDate",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	ScheduledJobsSessionsTable.Columns.Add("JobEndDate",New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
    ScheduledJobsSessionsTable.Columns.Add("NameOfEvent",New TypeDescription("String", , New StringQualifiers(100)));
	ScheduledJobsSessionsTable.Columns.Add("EventMetadata",New TypeDescription("String", , New StringQualifiers(100)));
	ScheduledJobsSessionsTable.Columns.Add("Session",New TypeDescription("Number", 	New NumberQualifiers(10)));
	
	StartsCount = New ValueTable();
	StartsCount.Columns.Add("NameOfEvent",New TypeDescription("String", , New StringQualifiers(100)));
	StartsCount.Columns.Add("Starts",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("Canceled",New TypeDescription("Number", 	New NumberQualifiers(10)));
	StartsCount.Columns.Add("ExecutionError",New TypeDescription("Number", 	New NumberQualifiers(10))); 	
	
	ScheduledJobsRow = Undefined;
	NameOfEvent			  = Undefined;
	JobEndDate	  = Undefined;
	JobStartDate		  = Undefined;
	EventMetadata		  = Undefined;
	Starts				  = 0;
	CurrentEvent			  = Undefined;
	StartsCountRow  = Undefined;
	CurrentSession			  = 0;
	Canceled				  = 0;
	ExecutionError		  = 0;
	
	For Each EventLogDataRow In EventLogData Do
		If Not ValueIsFilled(EventLogDataRow.Metadata)
			And DisplayBackgroundJobs = False Then
			Continue;
		EndIf;
		
		NameAndUUID = ScheduledJobSessionNameAndUUID(
			EventLogDataRow, DescriptionIDMap,
			MetadataIDMap, MetadataNameMap);
			
		NameOfEvent = NameAndUUID.SessionName;
		ScheduledJobUUID = NameAndUUID.
														ScheduledJobUUID;

		If Not HideScheduledJobs = Undefined
			And Not TypeOf(HideScheduledJobs) = Type("String") Then
			ScheduledJobsFilter = HideScheduledJobs.FindByValue(
				ScheduledJobUUID);
			If Not ScheduledJobsFilter = Undefined Then
				Continue;
			EndIf;
		ElsIf Not HideScheduledJobs = Undefined
			And TypeOf(HideScheduledJobs) = Type("String") Then	
			If ScheduledJobUUID = HideScheduledJobs Then
				Continue;
			EndIf;
		EndIf;
	
		Session = EventLogDataRow.Session;
		If CurrentEvent = Undefined Then                             
			CurrentEvent = NameOfEvent;
			Starts = 0;
		ElsIf CurrentEvent <> NameOfEvent Then
			StartsCountRow = StartsCount.Add();
			StartsCountRow.NameOfEvent = CurrentEvent;
			StartsCountRow.Starts = Starts;
			StartsCountRow.Canceled = Canceled;
			StartsCountRow.ExecutionError = ExecutionError;
			Starts = 0; 
			Canceled = 0;
			ExecutionError = 0;
			CurrentEvent = NameOfEvent;
		EndIf;  
		
		If CurrentSession <> Session Then
			ScheduledJobsRow = ScheduledJobsSessionsTable.Add();
			JobStartDate = EventLogDataRow.Date;
			ScheduledJobsRow.JobStartDate = JobStartDate;    
		EndIf;
		
		If CurrentSession = Session Then
			JobEndDate = EventLogDataRow.Date;
			EventMetadata = EventLogDataRow.Metadata;
			ScheduledJobsRow.NameOfEvent = NameOfEvent;
			ScheduledJobsRow.EventMetadata = EventMetadata;
			ScheduledJobsRow.JobEndDate = JobEndDate;
			ScheduledJobsRow.Session = CurrentSession;
		EndIf;
		CurrentSession = Session;
		
		If EventLogDataRow.Event = "_$Job$_.Cancel" Then
			Canceled = Canceled + 1;
		ElsIf EventLogDataRow.Event = "_$Job$_.Fail" Then
			ExecutionError = ExecutionError + 1;
		ElsIf EventLogDataRow.Event = "_$Job$_.Start" Then
			Starts = Starts + 1
		EndIf;		
	EndDo;
	
	StartsCountRow = StartsCount.Add();
	StartsCountRow.NameOfEvent = CurrentEvent;
	StartsCountRow.Starts = Starts;
	StartsCountRow.Canceled = Canceled;
	StartsCountRow.ExecutionError = ExecutionError;
	
	ScheduledJobsSessionsTable.Sort("EventMetadata, NameOfEvent, JobStartDate");
	
	Return New Structure("ScheduledJobsSessionsTable, StartsCount",
					ScheduledJobsSessionsTable, StartsCount);
EndFunction

// Generates a report for a single scheduled job.
// Parameters:
//   Details - 
//
Function ScheduledJobDetails1(Details) Export
	Result = New Structure;
	Report = New SpreadsheetDocument;
	JobsCanceled = 0;
	ExecutionError = 0;
	
	JobStartDate = Details.Get(5);
	JobEndDate = Details.Get(6);
	SessionsList = Details.Get(7);
	Template = GetTemplate("ScheduledJobsDetails");
	
	Area = TemplateAreaDetails(Template, "Title");
	StartDate = Details.Get(11);
	EndDate = Details.Get(12);
	Area.Parameters.StartDate = StartDate;
	Area.Parameters.EndDate = EndDate;
	If Details.Get(8) = 0 Then
		IntervalsViewMode = NStr("en = 'Show intervals with zero duration';");
	Else
		IntervalsViewMode = NStr("en = 'Hide intervals with zero duration';");
	EndIf;
	Area.Parameters.SessionViewMode = IntervalsViewMode;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("IsBlankString"));
	
	Area = TemplateAreaDetails(Template, "Table");
	Area.Parameters.JobType = NStr("en = 'Scheduled';");
	Area.Parameters.NameOfEvent = Details.Get(2);
	Area.Parameters.Starts = Details.Get(9);
	JobsCanceled = Details.Get(3);
	ExecutionError = Details.Get(4);
	If JobsCanceled = 0 Then
		Area.Parameters.Canceled = "0";
	Else
		Area.Parameters.Canceled = JobsCanceled;
	EndIf;
	If ExecutionError = 0 Then 
		Area.Parameters.ExecutionError = "0";
	Else
		Area.Parameters.ExecutionError = ExecutionError;
	EndIf;
	OverallScheduledJobsDuration = Details.Get(10);
	OverallScheduledJobsDurationTotal = ScheduledJobDuration(OverallScheduledJobsDuration);
	Area.Parameters.OverallScheduledJobsDuration = OverallScheduledJobsDurationTotal;
	Report.Put(Area);
	
	Report.Put(Template.GetArea("IsBlankString")); 
	
	Report.Put(Template.GetArea("IntervalsTitle"));
		
	Report.Put(Template.GetArea("IsBlankString"));
	
	Report.Put(Template.GetArea("TableHeader"));
	
	// Populate the interval table.
	ArraySize = JobStartDate.Count();
	IntervalNumber = 1; 	
    Report.StartRowGroup(, False);
	For IndexOf = 0 To ArraySize-1 Do
		Area = TemplateAreaDetails(Template, "IntervalsTable");
		StartOfRange = JobStartDate.Get(IndexOf);
		EndOfRange = JobEndDate.Get(IndexOf);
		SJDuration = ScheduledJobDuration(EndOfRange - StartOfRange);
		Area.Parameters.IntervalNumber = IntervalNumber;
		Area.Parameters.StartOfRange = Format(StartOfRange, "DLF=T");
		Area.Parameters.EndOfRange = Format(EndOfRange, "DLF=T");
		Area.Parameters.SJDuration = SJDuration;
		Area.Parameters.Session = SessionsList.Get(IndexOf);
		Area.Parameters.IntervalDetails1 = New Array;
		Area.Parameters.IntervalDetails1.Add(StartOfRange);
		Area.Parameters.IntervalDetails1.Add(EndOfRange);
		Area.Parameters.IntervalDetails1.Add(SessionsList.Get(IndexOf));
		Report.Put(Area);
		IntervalNumber = IntervalNumber + 1;
	EndDo;
	Report.EndRowGroup();
	
	Result.Insert("Report", Report);
	Return Result;
EndFunction

// Sets interval and background colors for a Gantt chart.
//
// Parameters:
//   StartDate - 
//   GanttChart - GanttChart, Type - SpreadsheetDocumentDrawing.
//   ConcurrentSessionsData - ValueTable - a value table with data on the number of
// 		concurrent scheduled jobs during the day.
//   BackColors - 
//
Procedure GanttChartColors(StartDate, GanttChart, ConcurrentSessionsData, BackColors)
	// Adding colors of background intervals.
	CurrentSessionsCount = 0;
	ColorIndex = 3;
	For Each ConcurrentSessionsRow In ConcurrentSessionsData Do
		If ConcurrentSessionsRow.ConcurrentScheduledJobs = 1 Then
			Continue
		EndIf;
		DateString = Left(ConcurrentSessionsRow.ConcurrentScheduledJobsDate, 8);
		BackIntervalStartDate =  Date(Format(StartDate,"DLF=D") + " " + DateString);
		BackIntervalEndDate = EndOfHour(BackIntervalStartDate);
		GanttChartInterval = GanttChart.BackgroundIntervals.Add(BackIntervalStartDate, BackIntervalEndDate);
		If CurrentSessionsCount <> 0 
			And CurrentSessionsCount <> ConcurrentSessionsRow.ConcurrentScheduledJobs 
			And ColorIndex <> 0 Then
			ColorIndex = ColorIndex - 1;
		EndIf;
		BackColor = BackColors.Get(ColorIndex);
		GanttChartInterval.Color = BackColor;
		
		CurrentSessionsCount = ConcurrentSessionsRow.ConcurrentScheduledJobs;
	EndDo;
EndProcedure

// Generates a timescale of a Gantt chart.
//
// Parameters:
//   GanttChart - GanttChart, Type - SpreadsheetDocumentDrawing.
//
Procedure GanttChartTimescale(GanttChart, AnalysisPeriod)
	TimeScaleItems = GanttChart.PlotArea.TimeScale.Items;
	
	TheFirstControl = TimeScaleItems[0];
	For IndexOf = 1 To TimeScaleItems.Count()-1 Do
		TimeScaleItems.Delete(TimeScaleItems[1]);
	EndDo; 
		
	TheFirstControl.Unit = TimeScaleUnitType.Day;
	TheFirstControl.PointLines = New Line(ChartLineType.Solid, 1);
	TheFirstControl.DayFormat =  TimeScaleDayFormat.MonthDay;
	
	Item = TimeScaleItems.Add();
	Item.Unit = TimeScaleUnitType.Hour;
	Item.PointLines = New Line(ChartLineType.Dotted, 1);
	
	If AnalysisPeriod <= 3600 Then
		Item = TimeScaleItems.Add();
		Item.Unit = TimeScaleUnitType.Minute;
		Item.PointLines = New Line(ChartLineType.Dotted, 1);
	EndIf;
EndProcedure

Function ScheduledJobDuration(SJDuration)
	If SJDuration = 0 Then
		OverallScheduledJobsDuration = "0";
	ElsIf SJDuration <= 60 Then
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 sec';"), SJDuration);
	ElsIf 60 < SJDuration <= 3600 Then
		DurationMinutes  = Format(SJDuration/60, "NFD=0");
		DurationSeconds = Format((Format(SJDuration/60, "NFD=2")
			- Int(SJDuration/60)) * 60, "NFD=0");
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 min %2 sec';"), DurationMinutes, DurationSeconds);
	ElsIf SJDuration > 3600 Then
		DurationHours    = Format(SJDuration/60/60, "NFD=0");
		DurationMinutes  = (Format(SJDuration/60/60, "NFD=2") - Int(SJDuration/60/60))*60;
		DurationMinutes  = Format(DurationMinutes, "NFD=0");
		OverallScheduledJobsDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h %2 min';"), DurationHours, DurationMinutes);
	EndIf;
	
	Return OverallScheduledJobsDuration;
EndFunction

Function ScheduledJobMetadata(ScheduledJobData)
	If ScheduledJobData <> "" Then
		Return Metadata.ScheduledJobs.Find(
			StrReplace(ScheduledJobData, "ScheduledJob." , ""));
	EndIf;
EndFunction

Function ScheduledJobSessionNameAndUUID(EventLogDataRow,
			DescriptionIDMap, MetadataIDMap, MetadataNameMap)
	If Not EventLogDataRow.Data = "" Then
		ScheduledJobUUID = DescriptionIDMap[
														EventLogDataRow.Data];
		SessionName = EventLogDataRow.Data;
	Else 
		ScheduledJobUUID = MetadataIDMap[
			ScheduledJobMetadata(EventLogDataRow.Metadata)];
		SessionName = MetadataNameMap[ScheduledJobMetadata(
														EventLogDataRow.Metadata)];
	EndIf;
													
	Return New Structure("SessionName, ScheduledJobUUID",
								SessionName, ScheduledJobUUID)
EndFunction

// Parameters:
//  Template - SpreadsheetDocument
//  AreaName - String
//
// Returns:
//  SpreadsheetDocument:
//    * Parameters - SpreadsheetDocumentTemplateParameters:
//        ** StartDate - Date
//        ** EndDate - Date
//        ** IntervalsViewMode - String
//        ** ScheduledJobsList - String
//        ** JobDetails1 - Array of String
//                              - Date
//        ** IntervalDetails1 - Array of String
//
Function TemplateAreaDetails(Template, AreaName)
	
	Return Template.GetArea(AreaName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event log management.

// Generates a report on errors registered in the event log.
//
// Parameters:
//   EventLogData - ValueTable - a table exported from the event log.
//
// It must have the following columns: Date, Username, ApplicationPresentation,
//                                          EventPresentation, Comment, and Level.
//
Function GenerateEventLogMonitorReport(StartDate, EndDate, ServerTimeOffset) Export
	
	Result = New Structure; 	
	Report = New SpreadsheetDocument; 	
	Template = GetTemplate("EvengLogErrorReportTemplate");
	EventLogData = EventLogErrorsInformation(StartDate, EndDate, ServerTimeOffset);
	EventLogRecordsCount = EventLogData.Count();
	
	ReportIsBlank = (EventLogRecordsCount = 0); // 
		
	///////////////////////////////////////////////////////////////////////////////
	// Data preparation block.
	//
	
	CollapseByComments = EventLogData.Copy();
	CollapseByComments.Columns.Add("TotalByComment");
	CollapseByComments.FillValues(1, "TotalByComment");
	CollapseByComments.GroupBy("Level, Comment, Event, EventPresentation", "TotalByComment");
	
	RowsArrayErrorLevel = CollapseByComments.FindRows(
									New Structure("Level", EventLogLevel.Error));
	
	RowsArrayWarningLevel = CollapseByComments.FindRows(
									New Structure("Level", EventLogLevel.Warning));
	
	CollapseErrors         = CollapseByComments.Copy(RowsArrayErrorLevel);
	CollapseErrors.Sort("TotalByComment Desc");
	CollapseWarnings = CollapseByComments.Copy(RowsArrayWarningLevel);
	CollapseWarnings.Sort("TotalByComment Desc");
	
	///////////////////////////////////////////////////////////////////////////////
	// Report generation block.
	//
	
	Area = Template.GetArea("ReportHeader1");
	Area.Parameters.SelectionPeriodStart    = StartDate;
	Area.Parameters.SelectionPeriodEnd = EndDate;
	Area.Parameters.InfobasePresentation = InfobasePresentation();
	Report.Put(Area);
	
	TSCompositionResult = GenerateTabularSection(Template, EventLogData, CollapseErrors);
	
	Report.Put(Template.GetArea("IsBlankString"));
	Area = Template.GetArea("ErrorBlockTitle");
	Area.Parameters.ErrorsCount1 = String(TSCompositionResult.Total);
	Report.Put(Area);
	
	If TSCompositionResult.Total > 0 Then
		Report.Put(TSCompositionResult.TabularSection);
	EndIf;
	
	Result.Insert("TotalByErrors", TSCompositionResult.Total); 	
	TSCompositionResult = GenerateTabularSection(Template, EventLogData, CollapseWarnings);
	
	Report.Put(Template.GetArea("IsBlankString"));
	Area = Template.GetArea("WarningBlockTitle");
	Area.Parameters.WarningsCount = TSCompositionResult.Total;
	Report.Put(Area);
	
	If TSCompositionResult.Total > 0 Then
		Report.Put(TSCompositionResult.TabularSection);
	EndIf;
	
	Result.Insert("TotalByWarnings", TSCompositionResult.Total);	
	Report.ShowGrid = False; 	
	Result.Insert("Report", Report); 
	Result.Insert("ReportIsBlank", ReportIsBlank);
	Return Result;
	
EndFunction

// Gets a presentation of the physical infobase location to display it to an administrator.
//
// Returns:
//   String - Infobase presentation.
//
// Example:
// - For a file infobase: \\FileServer\1c_ib\
// - For a server infobase: ServerName:1111 / information_base_name.
//
Function InfobasePresentation()
	
	DatabaseConnectionString = InfoBaseConnectionString();
	
	If Common.FileInfobase(DatabaseConnectionString) Then
		Return Mid(DatabaseConnectionString, 6, StrLen(DatabaseConnectionString) - 6);
	EndIf;
		
	// Append the infobase name to the server name.
	SearchPosition = StrFind(Upper(DatabaseConnectionString), "SRVR=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	SemicolonPosition = StrFind(DatabaseConnectionString, ";");
	StartPositionForCopying = 6 + 1;
	EndPositionForCopying = SemicolonPosition - 2; 
	
	ServerName = Mid(DatabaseConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
	
	DatabaseConnectionString = Mid(DatabaseConnectionString, SemicolonPosition + 1);
	
	// 
	SearchPosition = StrFind(Upper(DatabaseConnectionString), "REF=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	StartPositionForCopying = 6;
	SemicolonPosition = StrFind(DatabaseConnectionString, ";");
	EndPositionForCopying = SemicolonPosition - 2; 
	
	IBNameAtServer = Mid(DatabaseConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
	PathToDatabase = ServerName + "/ " + IBNameAtServer;
	Return PathToDatabase;
	
EndFunction

// Gets error details for the specified period from the event log.
//
// Parameters:
//   StartDate    - Date - the beginning of the period.
//   EndDate - Date - the end of the report period.
//
// Returns
//   ValueTable - the table contains event log records with the following filter:
//                    EventLogLevel - EventLogLevel.Error
//                    The beginning and end of period are taken from the parameters.
//
Function EventLogErrorsInformation(Val StartDate, Val EndDate, ServerTimeOffset)
	
	EventLogData = New ValueTable;
	
	LogLevels = New Array;
	LogLevels.Add(EventLogLevel.Error);
	LogLevels.Add(EventLogLevel.Warning);
	
	StartDate = StartDate + ServerTimeOffset;
	EndDate = EndDate + ServerTimeOffset;
	
	SetPrivilegedMode(True);
	UnloadEventLog(EventLogData,
							   New Structure("Level, StartDate, EndDate",
											   LogLevels,
											   StartDate,
											   EndDate));
	SetPrivilegedMode(False);
	
	If ServerTimeOffset <> 0 Then
		For Each TableRow In EventLogData Do
			TableRow.Date = TableRow.Date - ServerTimeOffset;
		EndDo;
	EndIf;
	
	Return EventLogData;
	
EndFunction

// Adds a tabular section with errors to the report.
// The errors are grouped by comment.
//
// Parameters:
//   Template  - SpreadsheetDocument - a source of formatted areas
//                              for report generation.
//   EventLogData   - ValueTable - "As is" errors and warnings from the Event Log.
//                              
//   CollapsedData - ValueTable - contains their total numbers (collapsed by comment).
//
Function GenerateTabularSection(Template, EventLogData, CollapsedData)
	
	Report = New SpreadsheetDocument;	
	Total = 0;
	
	If CollapsedData.Count() > 0 Then
		Report.Put(Template.GetArea("IsBlankString"));
		
		For Each Record In CollapsedData Do
			Total = Total + Record.TotalByComment;
			RowsArray = EventLogData.FindRows(
				New Structure("Level, Comment",
					EventLogLevel.Error,
					Record.Comment));
			
			Area = Template.GetArea("TabularSectionBodyHeader");
			Area.Parameters.Fill(Record);
			Report.Put(Area);
			
			Report.StartRowGroup(, False);
			For Each String In RowsArray Do
				Area = Template.GetArea("TabularSectionBodyDetails");
				Area.Parameters.Fill(String);
				Report.Put(Area);
			EndDo;
			Report.EndRowGroup();
			Report.Put(Template.GetArea("IsBlankString"));
		EndDo;
	EndIf;
	
	Result = New Structure("TabularSection, Total", Report, Total);
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf