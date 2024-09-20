///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	UseReminders = GetRemindersSettings().UseReminders;
	CurrentRemindersList = ?(UseReminders,
		CurrentUserRemindersList(), New Array);
	
	Result = New Structure;
	Result.Insert("UseReminders",  UseReminders);
	Result.Insert("CurrentRemindersList", CurrentRemindersList);
	
	Parameters.Insert("ReminderSettings", New FixedStructure(Result));
	
EndProcedure 

// See CommonOverridable.OnAddServerNotifications
Procedure OnAddServerNotifications(Notifications) Export
	
	If Not GetFunctionalOption("UseUserReminders") Then
		Return;
	EndIf;
	
	Notification = ServerNotifications.NewServerNotification(
		UserRemindersClientServer.ServerNotificationName());
	
	Notification.NotificationSendModuleName  = "UserRemindersInternal";
	Notification.NotificationReceiptModuleName = "UserRemindersClient";
	
	Notifications.Insert(Notification.Name, Notification);
	
EndProcedure

// See StandardSubsystemsServer.OnSendServerNotification
Procedure OnSendServerNotification(NameOfAlert, ParametersVariants) Export
	
	// 
	// 
	// 
	
	UpdateRemindersList(False);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.UsingReminders";
	NewName  = "Role.AddEditNotifications";
	Common.AddRenaming(Total, "2.3.3.11", OldName, NewName, Library);
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.InformationRegisters.UserReminders, True);
	
EndProcedure

// Change the reminder text for this subject.
// 
// Parameters:
//  SubjectOf - AnyRef - Reminder's subject.
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//  NewText - String - Reminder text.
//
Procedure EditReminderTextOnSubject(SubjectOf, Id, NewText) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	UserReminders.User,
		|	UserReminders.EventTime,
		|	UserReminders.Source
		|FROM
		|	InformationRegister.UserReminders AS UserReminders
		|WHERE
		|	UserReminders.Id = &Id
		|	AND UserReminders.Source = &Source";
	
	Query.SetParameter("Id", Id);
	Query.SetParameter("Source", SubjectOf);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	While SelectionDetailRecords.Next() Do
		RecordManager = InformationRegisters.UserReminders.CreateRecordManager();
		FillPropertyValues(RecordManager, SelectionDetailRecords);
		RecordManager.Read();
		RecordManager.LongDesc = NewText;
		RecordManager.Write();
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function SubsystemSettings() Export
	Settings = New Structure;
	Settings.Insert("Schedules1", GetStandardSchedulesForReminder());
	Settings.Insert("StandardIntervals", StandardNotifyIntervals());
	UserRemindersOverridable.OnDefineSettings(Settings);
	
	Return Settings;
EndFunction

Function StandardNotifyIntervals()
	
	Result = New Array;
	Result.Add(NStr("en = '5 minutes';"));
	Result.Add(NStr("en = '10 minutes';"));
	Result.Add(NStr("en = '15 minutes';"));
	Result.Add(NStr("en = '30 minutes';"));
	Result.Add(NStr("en = '1 hour';"));
	Result.Add(NStr("en = '2 hours';"));
	Result.Add(NStr("en = '4 hours';"));
	Result.Add(NStr("en = '8 hours';"));
	Result.Add(NStr("en = '1 day';"));
	Result.Add(NStr("en = '2 days';"));
	Result.Add(NStr("en = '3 days';"));
	Result.Add(NStr("en = '1 week';"));
	Result.Add(NStr("en = '2 weeks';"));
	
	Return Result;
	
EndFunction

// Returns standard schedules for repeated reminders.
Function GetStandardSchedulesForReminder()
	
	Result = New Map;
		
	// On Mondays at 9 a.m.
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	WeekDays = New Array;
	WeekDays.Add(1);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("en = 'on Mondays at 9.00 AM';"), Schedule);
	
	// 
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101150000';
	WeekDays = New Array;
	WeekDays.Add(5);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("en = 'on Fridays at 3.00 PM';"), Schedule);
	
	// 
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	Result.Insert(NStr("en = 'every day at 9:00 AM';"), Schedule);
	
	Return Result;
	
EndFunction

// Returns settings structure of user reminders.
Function GetRemindersSettings()
	
	Result = New Structure;
	Result.Insert("UseReminders",
		HasRightToUseReminders()
		And GetFunctionalOption("UseUserReminders"));
	
	Return Result;
	
EndFunction

// Checks if the user has the right to change the UserReminders information register.
//
// Returns:
//  Boolean - 
//
Function HasRightToUseReminders()
	Return AccessRight("Update", Metadata.InformationRegisters.UserReminders); 
EndFunction

// Returns the closest date on schedule relative to the date passed in the parameter.
//
// Parameters:
//  Schedule - JobSchedule - Schedule.
//  PreviousDate - Date - Date of the previous event according to the schedule.
//  SearchForFutureDatesOnly - Boolean - False if you need to find a date in the past.
//  
// Returns:
//   Date - Date and time of the next scheduled event.
//
Function GetClosestEventDateOnSchedule(Schedule, PreviousDate = '000101010000', SearchForFutureDatesOnly = True) Export

	Result = Undefined;
	CurrentSessionDate = CurrentSessionDate();
	
	StartingDate = PreviousDate;
	If Not ValueIsFilled(StartingDate) Then
		StartingDate = CurrentSessionDate;
	EndIf;
	If SearchForFutureDatesOnly Then
		StartingDate = Max(StartingDate, CurrentSessionDate);
	EndIf;
	
	Calendar = GetCalendarForFuture(365*4+1, StartingDate, Schedule.BeginDate, Schedule.DaysRepeatPeriod, Schedule.WeeksPeriod);
	
	WeekDays = Schedule.WeekDays;
	If WeekDays.Count() = 0 Then
		WeekDays = New Array;
		For Day = 1 To 7 Do
			WeekDays.Add(Day);
		EndDo;
	EndIf;
	
	Months = Schedule.Months;
	If Months.Count() = 0 Then
		Months = New Array;
		For Month = 1 To 12 Do
			Months.Add(Month);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = "SELECT * INTO Calendar FROM &Calendar AS Calendar";
	Query.SetParameter("Calendar", Calendar);
	Query.Execute();
	
	Query.SetParameter("StartDate",			Schedule.BeginDate);
	Query.SetParameter("EndDate",			Schedule.EndDate);
	Query.SetParameter("WeekDays",			WeekDays);
	Query.SetParameter("Months",				Months);
	Query.SetParameter("DayInMonth",		Schedule.DayInMonth);
	Query.SetParameter("WeekDayInMonth",	Schedule.WeekDayInMonth);
	Query.SetParameter("DaysRepeatPeriod",	?(Schedule.DaysRepeatPeriod = 0,1,Schedule.DaysRepeatPeriod));
	Query.SetParameter("WeeksPeriod",		?(Schedule.WeeksPeriod = 0,1,Schedule.WeeksPeriod));
	
	Query.Text = 
	"SELECT
	|	Calendar.Date,
	|	Calendar.MonthNumber,
	|	Calendar.WeekDayNumberInMonth,
	|	Calendar.WeekDayNumberFromMonthEnd,
	|	Calendar.DayNumberInMonth,
	|	Calendar.DayNumberInMonthFromMonthEnd,
	|	Calendar.DayNumberInWeek,
	|	Calendar.DayNumberInPeriod,
	|	Calendar.WeekNumberInPeriod
	|FROM
	|	Calendar AS Calendar
	|WHERE
	|	CASE
	|			WHEN &StartDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date >= &StartDate
	|		END
	|	AND CASE
	|			WHEN &EndDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date <= &EndDate
	|		END
	|	AND Calendar.DayNumberInWeek IN(&WeekDays)
	|	AND Calendar.MonthNumber IN(&Months)
	|	AND CASE
	|			WHEN &DayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &DayInMonth > 0
	|						THEN Calendar.DayNumberInMonth = &DayInMonth
	|					ELSE Calendar.DayNumberInMonthFromMonthEnd = -&DayInMonth
	|				END
	|		END
	|	AND CASE
	|			WHEN &WeekDayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &WeekDayInMonth > 0
	|						THEN Calendar.WeekDayNumberInMonth = &WeekDayInMonth
	|					ELSE Calendar.WeekDayNumberFromMonthEnd = -&WeekDayInMonth
	|				END
	|		END
	|	AND Calendar.DayNumberInPeriod = &DaysRepeatPeriod
	|	AND Calendar.WeekNumberInPeriod = &WeeksPeriod";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		NearestDate = Selection.Date;
		StartingTime = '00010101';
		If BegOfDay(NearestDate) = BegOfDay(StartingDate) Then
			StartingTime = StartingTime + (StartingDate-BegOfDay(StartingDate));
		EndIf;
		
		ClosestTime = GetClosestTimeFromSchedule(Schedule, StartingTime);
		If ClosestTime <> Undefined Then
			Result = NearestDate + (ClosestTime - '00010101');
		Else
			If Selection.Next() Then
				Time = GetClosestTimeFromSchedule(Schedule);
				Result = Selection.Date + (Time - '00010101');
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function GetCalendarForFuture(CalendarDaysCount, StartingDate, Val PeriodicityStartDate = Undefined, Val PeriodDays = 1, Val WeeksPeriod = 1) 
	
	If WeeksPeriod = 0 Then 
		WeeksPeriod = 1;
	EndIf;
	
	If PeriodDays = 0 Then
		PeriodDays = 1;
	EndIf;
	
	If Not ValueIsFilled(PeriodicityStartDate) Then
		PeriodicityStartDate = StartingDate;
	EndIf;
	
	Calendar = New ValueTable;
	Calendar.Columns.Add("Date", New TypeDescription("Date",,,New DateQualifiers()));
	Calendar.Columns.Add("MonthNumber", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("WeekDayNumberInMonth", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("WeekDayNumberFromMonthEnd", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInMonth", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInMonthFromMonthEnd", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInWeek", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("DayNumberInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("WeekNumberInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));
	
	Date = BegOfDay(StartingDate);
	PeriodicityStartDate = BegOfDay(PeriodicityStartDate);
	DayNumberInPeriod = 0;
	WeekNumberInPeriod = 0;
	
	If PeriodicityStartDate <= Date Then
		DaysCount = (Date - PeriodicityStartDate)/60/60/24;
		DayNumberInPeriod = DaysCount - Int(DaysCount/PeriodDays)*PeriodDays;
		
		WeeksCount = Int(DaysCount / 7);
		WeekNumberInPeriod = WeeksCount - Int(WeeksCount/WeeksPeriod)*WeeksPeriod;
	EndIf;
	
	If DayNumberInPeriod = 0 Then 
		DayNumberInPeriod = PeriodDays;
	EndIf;
	
	If WeekNumberInPeriod = 0 Then 
		WeekNumberInPeriod = WeeksPeriod;
	EndIf;
	
	For Counter = 0 To CalendarDaysCount - 1 Do
		
		Date = BegOfDay(StartingDate) + Counter * 60*60*24;
		NewRow = Calendar.Add();
		NewRow.Date = Date;
		NewRow.MonthNumber = Month(Date);
		NewRow.WeekDayNumberInMonth = Int((Date - BegOfMonth(Date))/60/60/24/7) + 1;
		NewRow.WeekDayNumberFromMonthEnd = Int((EndOfMonth(BegOfDay(Date)) - Date)/60/60/24/7) + 1;
		NewRow.DayNumberInMonth = Day(Date);
		NewRow.DayNumberInMonthFromMonthEnd = Day(EndOfMonth(BegOfDay(Date))) - Day(Date) + 1;
		NewRow.DayNumberInWeek = WeekDay(Date);
		
		If PeriodicityStartDate <= Date Then
			NewRow.DayNumberInPeriod = DayNumberInPeriod;
			NewRow.WeekNumberInPeriod = WeekNumberInPeriod;
			
			DayNumberInPeriod = ?(DayNumberInPeriod+1 > PeriodDays, 1, DayNumberInPeriod+1);
			
			If NewRow.DayNumberInWeek = 1 Then
				WeekNumberInPeriod = ?(WeekNumberInPeriod+1 > WeeksPeriod, 1, WeekNumberInPeriod+1);
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Calendar;
	
EndFunction

Function GetClosestTimeFromSchedule(Schedule, Val StartingTime = '000101010000')
	
	Result = Undefined;
	
	ValueList = New ValueList;
	
	If Schedule.DetailedDailySchedules.Count() = 0 Then
		ValueList.Add(Schedule.BeginTime);
	Else
		For Each DaySchedule In Schedule.DetailedDailySchedules Do
			ValueList.Add(DaySchedule.BeginTime);
		EndDo;
	EndIf;
	
	ValueList.SortByValue(SortDirection.Asc);
	
	For Each TimeOfDay In ValueList Do
		If StartingTime <= TimeOfDay.Value Then
			Result = TimeOfDay.Value;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//  Schedule - JobSchedule
//  BeginOfPeriod - Date
//  EndOfPeriod - Date
// Returns:
//  Array of Date
// 
Function EventSchedule(Schedule, BeginOfPeriod, EndOfPeriod)

	Result = Undefined;
	
	StartingDate = BeginOfPeriod;
	
	Calendar = GetCalendarForFuture((BegOfDay(EndOfPeriod) - BegOfDay(BeginOfPeriod)) / (60*60*24) + 1, 
		StartingDate, Schedule.BeginDate, Schedule.DaysRepeatPeriod, Schedule.WeeksPeriod);
	
	WeekDays = Schedule.WeekDays;
	If WeekDays.Count() = 0 Then
		WeekDays = New Array;
		For Day = 1 To 7 Do
			WeekDays.Add(Day);
		EndDo;
	EndIf;
	
	Months = Schedule.Months;
	If Months.Count() = 0 Then
		Months = New Array;
		For Month = 1 To 12 Do
			Months.Add(Month);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = "SELECT * INTO Calendar FROM &Calendar AS Calendar";
	Query.SetParameter("Calendar", Calendar);
	Query.Execute();
	
	Query.SetParameter("StartDate",			Schedule.BeginDate);
	Query.SetParameter("EndDate",			Schedule.EndDate);
	Query.SetParameter("WeekDays",			WeekDays);
	Query.SetParameter("Months",				Months);
	Query.SetParameter("DayInMonth",		Schedule.DayInMonth);
	Query.SetParameter("WeekDayInMonth",	Schedule.WeekDayInMonth);
	Query.SetParameter("DaysRepeatPeriod",	?(Schedule.DaysRepeatPeriod = 0,1,Schedule.DaysRepeatPeriod));
	Query.SetParameter("WeeksPeriod",		?(Schedule.WeeksPeriod = 0,1,Schedule.WeeksPeriod));
	
	Query.Text = 
	"SELECT
	|	Calendar.Date,
	|	Calendar.MonthNumber,
	|	Calendar.WeekDayNumberInMonth,
	|	Calendar.WeekDayNumberFromMonthEnd,
	|	Calendar.DayNumberInMonth,
	|	Calendar.DayNumberInMonthFromMonthEnd,
	|	Calendar.DayNumberInWeek,
	|	Calendar.DayNumberInPeriod,
	|	Calendar.WeekNumberInPeriod
	|FROM
	|	Calendar AS Calendar
	|WHERE
	|	CASE
	|			WHEN &StartDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date >= &StartDate
	|		END
	|	AND CASE
	|			WHEN &EndDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date <= &EndDate
	|		END
	|	AND Calendar.DayNumberInWeek IN(&WeekDays)
	|	AND Calendar.MonthNumber IN(&Months)
	|	AND CASE
	|			WHEN &DayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &DayInMonth > 0
	|						THEN Calendar.DayNumberInMonth = &DayInMonth
	|					ELSE Calendar.DayNumberInMonthFromMonthEnd = -&DayInMonth
	|				END
	|		END
	|	AND CASE
	|			WHEN &WeekDayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &WeekDayInMonth > 0
	|						THEN Calendar.WeekDayNumberInMonth = &WeekDayInMonth
	|					ELSE Calendar.WeekDayNumberFromMonthEnd = -&WeekDayInMonth
	|				END
	|		END
	|	AND Calendar.DayNumberInPeriod = &DaysRepeatPeriod
	|	AND Calendar.WeekNumberInPeriod = &WeeksPeriod";
	
	Selection = Query.Execute().Select();
	
	Result = New Array;
	
	While Selection.Next() Do
		NearestDate = Selection.Date;
		StartingTime = '00010101';
		If BegOfDay(NearestDate) = BegOfDay(StartingDate) Then
			StartingTime = StartingTime + (StartingDate-BegOfDay(StartingDate));
		EndIf;
		
		DateAndTime = Undefined;
		ClosestTime = GetClosestTimeFromSchedule(Schedule, StartingTime);
		If ClosestTime <> Undefined Then
			DateAndTime = NearestDate + (ClosestTime - '00010101');
		Else
			If Selection.Next() Then
				Time = GetClosestTimeFromSchedule(Schedule);
				DateAndTime = Selection.Date + (Time - '00010101');
			EndIf;
		EndIf;
		
		If ValueIsFilled(DateAndTime) And DateAndTime <= EndOfPeriod Then
			Result.Add(DateAndTime);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Checks attribute changes for the subjects the user subscribed to.
// If necessary, changes the reminder time.
//
Procedure UpdateRemindersForSubjects(Subjects) Export
	
	SetPrivilegedMode(True);
	
	ResultTable2 = RemindersBySubjects(Subjects);
	
	For Each TableRow In ResultTable2 Do
		SubjectDate = Common.ObjectAttributeValue(TableRow.Source, TableRow.SourceAttributeName);
		If (SubjectDate - TableRow.ReminderInterval) <> TableRow.EventTime Then
			// 
			DisableReminder(TableRow, False);
			TableRow.ReminderTime = SubjectDate - TableRow.ReminderInterval;
			TableRow.EventTime = SubjectDate;
			If TableRow.Schedule.Get() <> Undefined Then
				TableRow.RepeatAnnually = True;
			EndIf;
			
			ReminderParameters = Common.ValueTableRowToStructure(TableRow);
			ReminderParameters.Schedule = TableRow.Schedule.Get();
			// 
			Reminder = CreateReminder(ReminderParameters);
			AttachReminder(Reminder);
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  Subjects - Array of AnyRef
// 
// Returns:
//  ValueTable:
//   * User - CatalogRef.Users
//   * EventTime - Date
//   * Source - DefinedType.ReminderSubject
//   * ReminderTime - Date
//   * LongDesc - String
//   * ReminderTimeSettingMethod - EnumRef.ReminderTimeSettingMethods
//   * ReminderInterval - Number
//   * SourceAttributeName - String
//   * Schedule - ValueStorage
//   * RepeatAnnually - Boolean
//
Function RemindersBySubjects(Val Subjects)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Reminders.User,
	|	Reminders.EventTime,
	|	Reminders.Source,
	|	Reminders.ReminderTime,
	|	Reminders.LongDesc,
	|	Reminders.ReminderTimeSettingMethod,
	|	Reminders.ReminderInterval,
	|	Reminders.SourceAttributeName,
	|	Reminders.Schedule,
	|	Reminders.Id,
	|	FALSE AS RepeatAnnually
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTimeSettingMethod = VALUE(Enum.ReminderTimeSettingMethods.RelativeToSubjectTime)
	|	AND Reminders.Source IN(&Subjects)";
	
	Query.SetParameter("Subjects", Subjects);
	ResultTable2 = Query.Execute().Unload();
	
	Return ResultTable2
	
EndFunction


// Handler of subscription to event OnWrite object, for which you can create reminders.
Procedure CheckForDateChangesInItemWhenRecording(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseUserReminders") Then
		UpdateRemindersForSubjects(CommonClientServer.ValueInArray(Source.Ref));
	EndIf;
	
EndProcedure

// Creates a user reminder. If an object already has a reminder, the procedure shifts reminder time forward by seconds.
Procedure AttachReminder(ReminderParameters, UpdateReminderPeriod = False, ShouldDisableClientNotifications = False) Export
	
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	If ShouldDisableClientNotifications Then
		RecordSet.AdditionalProperties.Insert("ShouldDisableClientNotifications");
	EndIf;
	RecordSet.Filter.User.Set(ReminderParameters.User);
	RecordSet.Filter.Source.Set(ReminderParameters.Source);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.UserReminders");
	LockItem.SetValue("User", ReminderParameters.User);
	LockItem.SetValue("Source", ReminderParameters.Source);
	
	If UpdateReminderPeriod Then
		RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
		LockItem.SetValue("EventTime", ReminderParameters.EventTime);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet.Read();
		
		If UpdateReminderPeriod Then
			For Each Record In RecordSet Do
				FillPropertyValues(Record, ReminderParameters);
			EndDo;
		Else
			If RecordSet.Count() > 0 Then
				BusyTime = RecordSet.Unload(,"EventTime").UnloadColumn("EventTime");
				While BusyTime.Find(ReminderParameters.EventTime) <> Undefined Do
					ReminderParameters.EventTime = ReminderParameters.EventTime + 1;
				EndDo;
			EndIf;
			NewRecord = RecordSet.Add();
			FillPropertyValues(NewRecord, ReminderParameters);
		EndIf;
		
		If RecordSet.Count() > 0 Then
			RecordSet.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Disables a reminder if any. If the reminder is repeated, the procedure attaches it to the nearest date on the schedule.
Procedure DisableReminder(ReminderParameters, AttachBySchedule = True, ShouldDisableClientNotifications = False) Export
	
	QueryText = 
	"SELECT
	|	UserReminders.User AS User,
	|	UserReminders.EventTime AS EventTime,
	|	UserReminders.Source AS Source,
	|	UserReminders.ReminderTime AS ReminderTime,
	|	UserReminders.LongDesc AS LongDesc,
	|	UserReminders.ReminderTimeSettingMethod AS ReminderTimeSettingMethod,
	|	UserReminders.Schedule AS Schedule,
	|	UserReminders.ReminderInterval AS ReminderInterval,
	|	UserReminders.SourceAttributeName AS SourceAttributeName,
	|	UserReminders.Id AS Id
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND UserReminders.EventTime = &EventTime
	|	AND UserReminders.Source = &Source";
	
	Query = New Query(QueryText);
	Query.SetParameter("User", ReminderParameters.User);
	Query.SetParameter("EventTime", ReminderParameters.EventTime);
	Query.SetParameter("Source", ReminderParameters.Source);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.UserReminders");
	LockItem.SetValue("User", ReminderParameters.User);
	LockItem.SetValue("Source", ReminderParameters.Source);
	LockItem.SetValue("EventTime", ReminderParameters.EventTime);
	
	BeginTransaction();
	Try
		Block.Lock();
		
		QueryResult = Query.Execute().Unload();
		Reminder = Undefined;
		If QueryResult.Count() > 0 Then
			Reminder = QueryResult[0];
		EndIf;
		
		// Delete the existing record.
		RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
		If ShouldDisableClientNotifications Then
			RecordSet.AdditionalProperties.Insert("ShouldDisableClientNotifications");
		EndIf;
		RecordSet.Filter.User.Set(ReminderParameters.User);
		RecordSet.Filter.Source.Set(ReminderParameters.Source);
		RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
		RecordSet.Write();
		
		// Attach the next reminder on the schedule.
		NextDateOnSchedule = Undefined;
		DefinedNextDateOnSchedule = False;
		
		If AttachBySchedule And Reminder <> Undefined Then
			Schedule = Reminder.Schedule.Get();
			If Schedule <> Undefined Then
				If Schedule.DaysRepeatPeriod > 0 Then
					NextDateOnSchedule = GetClosestEventDateOnSchedule(Schedule, ReminderParameters.EventTime + 1);
				EndIf;
				DefinedNextDateOnSchedule = NextDateOnSchedule <> Undefined;
			EndIf;
			
			If DefinedNextDateOnSchedule Then
				Reminder.EventTime = NextDateOnSchedule;
				Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
				AttachReminder(Reminder, ShouldDisableClientNotifications);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns:
//  Structure:
//   * User - CatalogRef.Users
//   * EventTime - Date
//   * Source - DefinedType.ReminderSubject
//   * ReminderTime - Date
//   * LongDesc - String
//   * ReminderTimeSettingMethod - EnumRef.ReminderTimeSettingMethods
//   * ReminderInterval - Number
//   * SourceAttributeName - String
//   * Schedule - ValueStorage - the JobSchedule type value
//   * SourcePresentation - String
//   * Id - String
//
Function AttachArbitraryReminder(Text, EventTime, IntervalTillEvent = 0, SubjectOf = Undefined, Id = Undefined) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("LongDesc", Text);
	If TypeOf(EventTime) = Type("JobSchedule") Then
		ReminderParameters.Insert("Schedule", EventTime);
	ElsIf TypeOf(EventTime) = Type("String") Then
		ReminderParameters.Insert("SourceAttributeName", EventTime);
	Else
		ReminderParameters.Insert("EventTime", EventTime);
	EndIf;
	ReminderParameters.Insert("ReminderInterval", IntervalTillEvent);
	ReminderParameters.Insert("Source", SubjectOf);
	ReminderParameters.Insert("Id", Id);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

Function AttachReminderTillSubjectTime(Text, Interval, SubjectOf, AttributeName, RepeatAnnually = False) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("LongDesc", Text);
	ReminderParameters.Insert("Source", SubjectOf);
	ReminderParameters.Insert("SourceAttributeName", AttributeName);
	ReminderParameters.Insert("ReminderInterval", Interval);
	ReminderParameters.Insert("RepeatAnnually", RepeatAnnually);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

// Returns structure of a new reminder for further attachment.
Function CreateReminder(ReminderParameters)
	
	Reminder = UserRemindersClientServer.ReminderDetails(ReminderParameters, True);
	
	If Not ValueIsFilled(Reminder.User) Then
		Reminder.User = Users.CurrentUser();
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderTimeSettingMethod) Then
		If ValueIsFilled(Reminder.Source) And Not IsBlankString(Reminder.SourceAttributeName) Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToSubjectTime;
		ElsIf Reminder.Schedule <> Undefined Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.Periodically;
		ElsIf Not ValueIsFilled(Reminder.EventTime) Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToCurrentTime;
		Else
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime;
		EndIf;
	EndIf;
	
	If Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToSubjectTime Then
		Reminder.EventTime = Common.ObjectAttributeValue(Reminder.Source, Reminder.SourceAttributeName);
		Reminder.ReminderTime = Reminder.EventTime - ?(ValueIsFilled(Reminder.EventTime), Reminder.ReminderInterval, 0);
	ElsIf Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToCurrentTime Then
		Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime;
		Reminder.EventTime = CurrentSessionDate() + Reminder.ReminderInterval;
	ElsIf Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime Then
		Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderTime) Then
		Reminder.ReminderTime = Reminder.EventTime;
	EndIf;
	
	If Reminder.RepeatAnnually Then
		If ValueIsFilled(Reminder.EventTime) Then
			Reminder.Schedule = UserRemindersClientServer.AnnualSchedule(Reminder.EventTime);
		EndIf;
	EndIf;
	
	If Reminder.Schedule <> Undefined Then
		Reminder.EventTime = GetClosestEventDateOnSchedule(Reminder.Schedule);
		If Reminder.EventTime = Undefined Then
			Reminder.EventTime = '00010101';
		EndIf;
		Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
	EndIf;
	
	Reminder.Schedule = New ValueStorage(Reminder.Schedule, New Deflation(9));
	
	Return Reminder;
	
EndFunction

// Returns:
//  Structure:
//   * Added1 - See CurrentUserRemindersList
//   * Trash   - See CurrentUserRemindersList
//
Function NewModifiedReminders() Export
	
	Return New Structure("Added1, Trash", New Array, New Array);
	
EndFunction

// Stops overdue repeated reminders.
Procedure UpdateRemindersList(OnStart)
	
	QueryText =
	"SELECT ALLOWED
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderTime AS ReminderTime,
	|	Reminders.LongDesc AS LongDesc,
	|	Reminders.ReminderTimeSettingMethod AS ReminderTimeSettingMethod,
	|	Reminders.ReminderInterval AS ReminderInterval,
	|	Reminders.SourceAttributeName AS SourceAttributeName,
	|	Reminders.Schedule AS Schedule,
	|	Reminders.SourcePresentation AS SourcePresentation,
	|	Reminders.Id AS Id
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.EventTime <= &CurrentDate
	|	AND &FilterByUser";
	
	Query = New Query(QueryText);
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	If OnStart Then
		Query.SetParameter("User", Users.CurrentUser());
		Query.Text = StrReplace(Query.Text, "&FilterByUser",
			"Reminders.User = &User");
	Else
		Query.Text = StrReplace(Query.Text, "&FilterByUser", "TRUE");
	EndIf;
	
	SetPrivilegedMode(True);
	RemindersList = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	For Each Reminder In RemindersList Do
		Schedule = Reminder.Schedule.Get();
		If Schedule = Undefined Then
			Continue;
		EndIf;
		
		// 
		EventScheduleForYear = EventSchedule(Schedule, Reminder.EventTime, AddMonth(Reminder.EventTime, 12) - 1);
		// 
		ComingEventTime = EventSchedule(Schedule, Reminder.EventTime + 1, CurrentSessionDate());
		
		// - 
		If ComingEventTime.Count() > 0
			// - 
			Or ValueIsFilled(Schedule.CompletionTime) And CurrentSessionDate() > (Reminder.EventTime + (Schedule.CompletionTime - Schedule.BeginTime))
			// - 
			Or EventScheduleForYear.Count() = 1 And CurrentSessionDate() > AddMonth(Reminder.EventTime, 1)
			// - 
			Or EventScheduleForYear.Count() = 12 And CurrentSessionDate() > Reminder.EventTime + 60*60*24*7 Then
				BeginTransaction();
				Try
					If ComingEventTime.Count() > 0 Then
						// 
						DisableReminder(Reminder, False, OnStart);
						
						ReminderParameters = Common.ValueTableRowToStructure(Reminder);
						ReminderParameters.Schedule = Reminder.Schedule.Get();
						// @skip-
						Reminder = CreateReminder(ReminderParameters);
						Reminder.EventTime = ComingEventTime[ComingEventTime.UBound()];
						Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
						
						AttachReminder(Reminder,, OnStart);
					EndIf;
					// 
					DisableReminder(Reminder, True, OnStart);
					CommitTransaction();
				Except
					RollbackTransaction();
					WriteLogEvent(NStr("en = 'User reminders';", Common.DefaultLanguageCode()),
						EventLogLevel.Error, Metadata.InformationRegisters.UserReminders, , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				EndTry;
		EndIf;
	EndDo;
	
EndProcedure

// 
// 
// 
//
// Returns:
//  Array of Structure:
//   * User - CatalogRef.Users
//   * EventTime - Date
//   * Source - DefinedType.ReminderSubject
//   * ReminderTime - Date
//   * LongDesc - String
//   * PictureIndex - Number
//
Function CurrentUserRemindersList() Export
	
	UpdateRemindersList(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderTime AS ReminderTime,
	|	Reminders.LongDesc AS LongDesc,
	|	2 AS PictureIndex
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTime <= &ReminderPeriodBoundary
	|	AND Reminders.User = &User
	|
	|ORDER BY
	|	EventTime";
	
	Query.SetParameter("ReminderPeriodBoundary",
		CurrentSessionDate() + ReminderTimeReserveForCache());
	
	Query.SetParameter("User", Users.CurrentUser());
	
	SetPrivilegedMode(True);
	Result = Common.ValueTableToArray(Query.Execute().Unload());
	
	Return Result;
	
EndFunction

Function ReminderTimeReserveForCache() Export
	
	Return 30*60;
	
EndFunction

// See UserReminders.OnReadAtServer
Procedure OnCreateAtServer(Form, PlacementParameters) Export
	
	If Not GetFunctionalOption("UseUserReminders") Then
		Return;
	EndIf;
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserReminders) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(PlacementParameters.NameOfAttributeWithEventDate) Then
		Return;
	EndIf;
	
	Object = Undefined;
	For Each Attribute In Form.GetAttributes() Do
		If TypeOf(Form[Attribute.Name]) = Type("FormDataStructure") Then
			Object = Form[Attribute.Name];
			Break;
		EndIf;
	EndDo;
	
	If Object = Undefined Then
		Return;
	EndIf;
	
	NameOfAttributeWithEventDate = PlacementParameters.NameOfAttributeWithEventDate;
	
	SubjectOf = Object.Ref;
	MetadataObject = SubjectOf.Metadata();
	
	AttributeWithDate = MetadataObject.Attributes.Find(NameOfAttributeWithEventDate);
	If AttributeWithDate = Undefined Then
		PropertiesValues = New Structure("NameOfAttributeWithEventDate");
		FillPropertyValues(PropertiesValues, MetadataObject.StandardAttributes);
		AttributeWithDate = PropertiesValues.NameOfAttributeWithEventDate;
	EndIf;
	
	If AttributeWithDate = Undefined Then
		Return;
	EndIf;
	
	ShouldDisplayShortIntervals = True;
	DateTypeDetails = AttributeWithDate.Type; // TypeDescription
	If DateTypeDetails.DateQualifiers.DateFractions = DateFractions.Date Then
		ShouldDisplayShortIntervals = False;
	EndIf;
		
	NameOfReminderSettingsField = UserRemindersClientServer.NameOfReminderSettingsField();
	NameOfItemGroup = "ReminderSetup";
	FieldNameReminderTimeInterval = UserRemindersClientServer.FieldNameReminderTimeInterval();
	FieldNameRemindAboutEvent = FieldNameRemindAboutEvent();
	
	SettingsOfReminder = PlacementParameters();
	SettingsOfReminder.Delete("Group");
	
	FillPropertyValues(SettingsOfReminder, PlacementParameters);
	
	SettingsOfReminder.Insert("SubjectOf", SubjectOf);
	
	If Form.Items.Find(NameOfItemGroup) = Undefined Then
		AttributesToBeAdded = New Array;
		
		AttributesToBeAdded.Add(New FormAttribute(NameOfReminderSettingsField, New TypeDescription));
			
		AttributesToBeAdded.Add(New FormAttribute(FieldNameRemindAboutEvent,
			New TypeDescription("Boolean"), , NStr("en = 'Remind';"), True));
			
		AttributesToBeAdded.Add(New FormAttribute(FieldNameReminderTimeInterval,
			New TypeDescription("String"), ,  NStr("en = 'Reminder interval';"), True));
		
		Form.ChangeAttributes(AttributesToBeAdded);
		
		Group = Form.Items.Add(NameOfItemGroup, Type("FormGroup"), PlacementParameters.Group);
		Group.Type = FormGroupType.UsualGroup;
		Group.ShowTitle = False;
		Group.Title = NStr("en = 'Set up reminder';");
		Group.Representation = UsualGroupRepresentation.None;
		
		If SettingsOfReminder.ShouldAddFlag Then
			CheckBox = Form.Items.Add(FieldNameRemindAboutEvent, Type("FormField"), Group);
			CheckBox.DataPath = FieldNameRemindAboutEvent;
			CheckBox.Type = FormFieldType.CheckBoxField;
			CheckBox.TitleLocation = FormItemTitleLocation.Right;
			CheckBox.Title = NStr("en = 'Remind:';");
		EndIf;
		
		InputField = Form.Items.Add(FieldNameReminderTimeInterval, Type("FormField"), Group);
		InputField.DataPath = FieldNameReminderTimeInterval;
		InputField.Type = FormFieldType.InputField;
		InputField.ToolTip = NStr("en = 'Time interval to remind about the event';");
		If SettingsOfReminder.ShouldAddFlag Then
			InputField.TitleLocation = FormItemTitleLocation.None;
		Else
			InputField.Title = NStr("en = 'Remind';");
		EndIf;
		InputField.SetAction("OnChange", "Attachable_OnChangeReminderSettings");
		InputField.EditTextUpdate = EditTextUpdate.OnValueChange;
		InputField.DropListButton = True;
		InputField.Width = 12;
		InputField.HorizontalStretch = False;
		
		SubsystemSettings = SubsystemSettings();
		TimeIntervals_SSLy = SubsystemSettings.StandardIntervals;
		
		InputField.ChoiceList.Clear();
		If Not SettingsOfReminder.ShouldAddFlag Then
			InputField.ChoiceList.Add(UserRemindersClientServer.EnumPresentationDoNotRemind());
		EndIf;
		InputField.ChoiceList.Add(UserRemindersClientServer.EnumPresentationOnOccurrence());
		
		For Each Interval In TimeIntervals_SSLy Do
			If Not ShouldDisplayShortIntervals And TimeIntervalFromString(Interval) < 24*60*60 Then
				Continue;
			EndIf;

			InputField.ChoiceList.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 before';"), Interval));
		EndDo;
		
		If SettingsOfReminder.ReminderInterval = Undefined Then
			SettingsOfReminder.ReminderInterval = 0;
		EndIf;
		
		If SettingsOfReminder.ShouldAddFlag Then
			If SettingsOfReminder.ReminderInterval = 0 Then
				Form[FieldNameReminderTimeInterval] = UserRemindersClientServer.EnumPresentationOnOccurrence();
			Else
				Form[FieldNameReminderTimeInterval] = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 before';"), TimePresentation(SettingsOfReminder.ReminderInterval, , False));
			EndIf;
		Else
			Form[FieldNameReminderTimeInterval] = UserRemindersClientServer.EnumPresentationDoNotRemind();
		EndIf;
		
		Form[NameOfReminderSettingsField] = SettingsOfReminder;
	EndIf;
	
	If Not ValueIsFilled(SubjectOf) Then
		Return;
	EndIf;
	
	ReadSettingsOfSubjectReminder(Form, SubjectOf);
	
EndProcedure

// See UserReminders.OnReadAtServer
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	If Not GetFunctionalOption("UseUserReminders") Then
		Return;
	EndIf;
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserReminders) Then
		Return;
	EndIf;
	
	SettingsOfReminder = UserRemindersClientServer.ReminderSettingsInForm(Form);
	If SettingsOfReminder = Undefined Then
		Return;
	EndIf;
	
	SubjectOf = CurrentObject.Ref;
	ReadSettingsOfSubjectReminder(Form, SubjectOf);
	
EndProcedure

Procedure OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters, Val ReminderText) Export
	
	If Not GetFunctionalOption("UseUserReminders") Then
		Return;
	EndIf;
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserReminders) Then
		Return;
	EndIf;
	
	SettingsOfReminder = UserRemindersClientServer.ReminderSettingsInForm(Form);
	IsReminderOn = Form[FieldNameRemindAboutEvent()];
	SubjectOf = CurrentObject.Ref;
	SettingsOfReminder.Insert("SubjectOf", SubjectOf);
	
	NameOfAttributeWithEventDate = SettingsOfReminder.NameOfAttributeWithEventDate;
	ReminderInterval = SettingsOfReminder.ReminderInterval;
	Text = ReminderText;
	If Not ValueIsFilled(Text) Then
		Text = Common.SubjectString(SubjectOf);
	EndIf;
	
	If IsReminderOn Then
		ReSetReminderBySubject(SubjectOf, NameOfAttributeWithEventDate, ReminderInterval, Text);
	Else
		DeleteRemindersBySubject(SubjectOf, NameOfAttributeWithEventDate)
	EndIf;
	
EndProcedure

// See UserReminders.PlacementParameters
Function PlacementParameters() Export
	
	Result = New Structure;
	Result.Insert("Group");
	Result.Insert("NameOfAttributeWithEventDate");
	Result.Insert("ReminderInterval");
	Result.Insert("ShouldAddFlag", False);
	
	Return Result;
	
EndFunction

// See UserRemindersClientServer.TimePresentation
Function TimePresentation(Val Time, FullPresentation = True, OutputSeconds = True)
		
	Return UserRemindersClientServer.TimePresentation(Time, FullPresentation, OutputSeconds);
	
EndFunction

Procedure DeleteRemindersBySubject(SubjectOf, AttributeName)
	
	RemindersBySubject = UserReminders.FindReminders(SubjectOf);
	For Each Reminder In RemindersBySubject Do
		If Lower(Reminder.SourceAttributeName) = Lower(AttributeName) Then
			// 
			DisableReminder(Reminder, False);
		EndIf;
	EndDo;
	
EndProcedure

Procedure ReSetReminderBySubject(SubjectOf, AttributeName, ReminderInterval, Text)

	DeleteRemindersBySubject(SubjectOf, AttributeName);
	AttachArbitraryReminder(Text, AttributeName, ReminderInterval, SubjectOf);
	
EndProcedure

// See UserRemindersClientServer.TimeIntervalFromString
Function TimeIntervalFromString(Val StringWithTime) Export
	
	Return UserRemindersClientServer.TimeIntervalFromString(StringWithTime);
	
EndFunction

Function FieldNameRemindAboutEvent() Export
	
	Return UserRemindersClientServer.FieldNameRemindAboutEvent();
	
EndFunction

Procedure ReadSettingsOfSubjectReminder(Form, SubjectOf)
	
	SettingsOfReminder = UserRemindersClientServer.ReminderSettingsInForm(Form);
	If SettingsOfReminder = Undefined Then
		Return;
	EndIf;
	
	SettingsOfReminder.Insert("SubjectOf", SubjectOf);
	
	RemindersBySubject = UserReminders.FindReminders(SubjectOf);
	For Each Reminder In RemindersBySubject Do
		If Lower(Reminder.SourceAttributeName) = Lower(SettingsOfReminder.NameOfAttributeWithEventDate) Then
			FieldNameRemindAboutEvent = FieldNameRemindAboutEvent();
			FieldNameReminderTimeInterval = UserRemindersClientServer.FieldNameReminderTimeInterval();
			
			Form[FieldNameRemindAboutEvent] = True;
			Form[FieldNameReminderTimeInterval] = UserRemindersClientServer.ReminderTimePresentation(Reminder);
			Break;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
