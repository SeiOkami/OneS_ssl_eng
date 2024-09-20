///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// Correcting working days and days before the holidays falling on Saturdays or Sundays.
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	ScheduleDays.Calendar AS Calendar,
		|	ScheduleDays.Year AS Year
		|FROM
		|	InformationRegister.CalendarSchedules AS ScheduleDays
		|		INNER JOIN Catalog.Calendars AS WorkSchedules
		|		ON (WorkSchedules.Ref = ScheduleDays.Calendar)
		|			AND (WorkSchedules.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks))
		|			AND (WorkSchedules.ConsiderHolidays)
		|		INNER JOIN InformationRegister.BusinessCalendarData AS CalendarData
		|		ON (WorkSchedules.BusinessCalendar = CalendarData.BusinessCalendar)
		|			AND ScheduleDays.Year = CalendarData.Year
		|			AND ScheduleDays.ScheduleDate = CalendarData.Date
		|			AND (NOT ScheduleDays.DayAddedToSchedule)
		|			AND (WEEKDAY(CalendarData.Date) IN (6, 7))
		|			AND (CalendarData.DayKind IN (VALUE(Enum.BusinessCalendarDaysKinds.Work), VALUE(Enum.BusinessCalendarDaysKinds.Preholiday)))
		|		LEFT JOIN InformationRegister.ManualWorkScheduleChanges AS ManualChanges
		|		ON (ManualChanges.WorkScheduleCalendar = ScheduleDays.Calendar)
		|			AND (ManualChanges.Year = ScheduleDays.Year)
		|			AND (ManualChanges.ScheduleDate = ScheduleDays.ScheduleDate)
		|WHERE
		|	ISNULL(ManualChanges.ManualEdit, FALSE) = FALSE
		|
		|ORDER BY
		|	Calendar,
		|	Year";
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName = Metadata.InformationRegisters.CalendarSchedules.FullName();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload(), AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.CalendarSchedules;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	FilterPresentation   = NStr("en = 'Calendar = ""%1""';");
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(Parameters.Queue, FullRegisterName);
	
	SchedulesArray = New Array;
	While Selection.Next() Do
		SchedulesArray.Add(Selection.Calendar);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("SchedulesArray", SchedulesArray);
	Query.Text = 
		"SELECT
		|	Calendars.Ref AS Ref,
		|	Calendars.BusinessCalendar AS BusinessCalendar,
		|	Calendars.FillingMethod AS FillingMethod,
		|	Calendars.StartingDate AS StartingDate,
		|	Calendars.ConsiderHolidays AS ConsiderHolidays,
		|	Calendars.ConsiderNonWorkPeriods AS ConsiderNonWorkPeriods,
		|	Calendars.FillingTemplate.(
		|		Ref AS Ref,
		|		LineNumber AS LineNumber,
		|		DayAddedToSchedule AS DayAddedToSchedule) AS FillingTemplate
		|FROM
		|	Catalog.Calendars AS Calendars
		|WHERE
		|	Calendars.Ref IN (&SchedulesArray)";
	SchedulesAttributes = Query.Execute().Unload();
	
	SchedulesAttributes.Indexes.Add("Ref");
	RowFilter = New Structure("Ref");
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	Selection.Reset();
	While Selection.Next() Do
		RowFilter.Ref = Selection.Calendar;
		ScheduleAttributes = SchedulesAttributes.FindRows(RowFilter)[0];
		Try
			FillWorkScheduleForYear(Selection.Calendar, Selection.Year, ScheduleAttributes);
			Processed = Processed + 1;
		Except
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process the record set of the ""%1"" register with filter %2. Reason:
                      |%3';"), 
				RegisterPresentation, 
				StringFunctionsClientServer.SubstituteParametersToString(
					FilterPresentation, 
					Selection.Calendar),
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Warning,
				RegisterMetadata, , 
				MessageText);
		EndTry;
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	ProcedureName = "InformationRegister.CalendarSchedules.ProcessDataForMigrationToNewVersion";
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 failed to process and skipped %2 records.';"), 
			ProcedureName,
			RecordsWithIssuesCount);
		Raise MessageText;
	EndIf;
	
	WriteLogEvent(
		InfobaseUpdate.EventLogEvent(), 
		EventLogLevel.Information, RegisterMetadata, ,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 processed yet another batch of records: %2.';"),
			ProcedureName,
			Processed));
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure FillWorkScheduleForYear(WorkScheduleCalendar, Year, ScheduleAttributes)
	
	BegOfYear = Date(Year, 1, 1);
	EndOfYear = Date(Year, 12, 31);
	
	ScheduleAttributes.FillingTemplate.Sort("LineNumber");

	FillParameters = InformationRegisters.CalendarSchedules.ScheduleFillingParameters();
	FillParameters.FillingMethod = ScheduleAttributes.FillingMethod;
	FillParameters.FillingTemplate = ScheduleAttributes.FillingTemplate;
	FillParameters.BusinessCalendar = ScheduleAttributes.BusinessCalendar;
	FillParameters.ConsiderHolidays = ScheduleAttributes.ConsiderHolidays;
	FillParameters.ConsiderNonWorkPeriods = ScheduleAttributes.ConsiderNonWorkPeriods;
	FillParameters.StartingDate = ScheduleAttributes.StartingDate;
	DaysIncludedInSchedule = InformationRegisters.CalendarSchedules.DaysIncludedInSchedule(
		BegOfYear, EndOfYear, FillParameters);
							
	WriteScheduleDataToRegister(WorkScheduleCalendar, DaysIncludedInSchedule, BegOfYear, EndOfYear);
	
EndProcedure

// Uses business calendar data to update 
// work schedules.
//
// Parameters:
//  - UpdateConditions - ValueTable:
//    - BusinessCalendarCode - Code of the modified business calendar.
//    - Year - Year whose data must be updated.
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	// 
	// 
	// 
	
	QueryText = 
		"SELECT
		|	UpdateConditions.BusinessCalendarCode,
		|	UpdateConditions.Year,
		|	DATEADD(DATETIME(1, 1, 1), YEAR, UpdateConditions.Year - 1) AS BegOfYear,
		|	DATEADD(DATETIME(1, 12, 31), YEAR, UpdateConditions.Year - 1) AS EndOfYear
		|INTO UpdateConditions
		|FROM
		|	&UpdateConditions AS UpdateConditions
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.Ref AS WorkScheduleCalendar,
		|	Calendars.BusinessCalendar,
		|	Calendars.StartDate,
		|	Calendars.EndDate
		|INTO TTWorkSchedulesDependingOnCalendars
		|FROM
		|	Catalog.Calendars AS Calendars
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
		|		AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks))
		|
		|UNION ALL
		|
		|SELECT
		|	Calendars.Ref,
		|	Calendars.BusinessCalendar,
		|	Calendars.StartDate,
		|	Calendars.EndDate
		|FROM
		|	Catalog.Calendars AS Calendars
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
		|		AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods))
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.WorkScheduleCalendar,
		|	UpdateConditions.Year,
		|	CASE
		|		WHEN Calendars.StartDate < UpdateConditions.BegOfYear
		|			THEN UpdateConditions.BegOfYear
		|		ELSE Calendars.StartDate
		|	END AS StartDate,
		|	CASE
		|		WHEN Calendars.EndDate > UpdateConditions.EndOfYear
		|			THEN UpdateConditions.EndOfYear
		|		ELSE Calendars.EndDate
		|	END AS EndDate
		|INTO TTWorkSchedulesByUpdateCondition
		|FROM
		|	TTWorkSchedulesDependingOnCalendars AS Calendars
		|		INNER JOIN UpdateConditions AS UpdateConditions
		|		ON (UpdateConditions.BusinessCalendarCode = Calendars.BusinessCalendar.Code)
		|		AND Calendars.StartDate <= UpdateConditions.EndOfYear
		|		AND Calendars.EndDate >= UpdateConditions.BegOfYear
		|		AND (Calendars.EndDate <> DATETIME(1, 1, 1))
		|
		|UNION ALL
		|
		|SELECT
		|	Calendars.WorkScheduleCalendar,
		|	UpdateConditions.Year,
		|	CASE
		|		WHEN Calendars.StartDate < UpdateConditions.BegOfYear
		|			THEN UpdateConditions.BegOfYear
		|		ELSE Calendars.StartDate
		|	END,
		|	UpdateConditions.EndOfYear
		|FROM
		|	TTWorkSchedulesDependingOnCalendars AS Calendars
		|		INNER JOIN UpdateConditions AS UpdateConditions
		|		ON (UpdateConditions.BusinessCalendarCode = Calendars.BusinessCalendar.Code)
		|		AND Calendars.StartDate <= UpdateConditions.EndOfYear
		|		AND (Calendars.EndDate = DATETIME(1, 1, 1))
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.WorkScheduleCalendar,
		|	Calendars.Year,
		|	Calendars.StartDate,
		|	Calendars.EndDate
		|INTO TTUpdatableWorkSchedules
		|FROM
		|	TTWorkSchedulesByUpdateCondition AS Calendars
		|		LEFT JOIN InformationRegister.ManualWorkScheduleChanges AS ManualChangesForAllYears
		|		ON (ManualChangesForAllYears.WorkScheduleCalendar = Calendars.WorkScheduleCalendar)
		|		AND (ManualChangesForAllYears.Year = 0)
		|WHERE
		|	ManualChangesForAllYears.WorkScheduleCalendar IS NULL
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkSchedulesToUpdate.WorkScheduleCalendar,
		|	WorkSchedulesToUpdate.Year,
		|	FillParameters.FillingMethod,
		|	FillParameters.BusinessCalendar,
		|	WorkSchedulesToUpdate.StartDate,
		|	WorkSchedulesToUpdate.EndDate,
		|	FillParameters.StartingDate,
		|	FillParameters.ConsiderHolidays,
		|	FillParameters.ConsiderNonWorkPeriods
		|FROM
		|	TTUpdatableWorkSchedules AS WorkSchedulesToUpdate
		|		LEFT JOIN Catalog.Calendars FillParameters
		|		ON FillParameters.Ref = WorkSchedulesToUpdate.WorkScheduleCalendar
		|ORDER BY
		|	WorkSchedulesToUpdate.WorkScheduleCalendar,
		|	WorkSchedulesToUpdate.Year
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FillingTemplate.Ref AS WorkScheduleCalendar,
		|	FillingTemplate.LineNumber AS LineNumber,
		|	FillingTemplate.DayAddedToSchedule
		|FROM
		|	Catalog.Calendars.FillingTemplate AS FillingTemplate
		|WHERE
		|	FillingTemplate.Ref IN
		|		(SELECT
		|			TTUpdatableWorkSchedules.WorkScheduleCalendar
		|		FROM
		|			TTUpdatableWorkSchedules)
		|ORDER BY
		|	WorkScheduleCalendar,
		|	LineNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("UpdateConditions", UpdateConditions);
	
	QueryResults = Query.ExecuteBatch(); // Array of QueryResult
	SelectionBySchedule = QueryResults[QueryResults.UBound() - 1].Select();
	SelectionByTemplate = QueryResults[QueryResults.UBound()].Select();
	
	FillingTemplate = New ValueTable;
	FillingTemplate.Columns.Add("DayAddedToSchedule", New TypeDescription("Boolean"));
	
	While SelectionBySchedule.NextByFieldValue("WorkScheduleCalendar") Do
		FillingTemplate.Clear();
		While SelectionByTemplate.FindNext(SelectionBySchedule.WorkScheduleCalendar, "WorkScheduleCalendar") Do
			NewRow = FillingTemplate.Add();
			NewRow.DayAddedToSchedule = SelectionByTemplate.DayAddedToSchedule;
		EndDo;
		While SelectionBySchedule.NextByFieldValue("StartDate") Do
			// If the end date is not specified, it will be picked by the business calendar.
			FillParameters = InformationRegisters.CalendarSchedules.ScheduleFillingParameters();
			FillParameters.FillingMethod = SelectionBySchedule.FillingMethod;
			FillParameters.FillingTemplate = FillingTemplate;
			FillParameters.BusinessCalendar = SelectionBySchedule.BusinessCalendar;
			FillParameters.ConsiderHolidays = SelectionBySchedule.ConsiderHolidays;
			FillParameters.ConsiderNonWorkPeriods = SelectionBySchedule.ConsiderNonWorkPeriods;
			FillParameters.StartingDate = SelectionBySchedule.StartingDate;
			DaysIncludedInSchedule = InformationRegisters.CalendarSchedules.DaysIncludedInSchedule(
				SelectionBySchedule.StartDate, SelectionBySchedule.EndDate, FillParameters);
			// 
			WriteScheduleDataToRegister(SelectionBySchedule.WorkScheduleCalendar, DaysIncludedInSchedule, 
				SelectionBySchedule.StartDate, SelectionBySchedule.EndDate);
		EndDo;
	EndDo;
	
EndProcedure

// 
//
// Parameters:
//  WorkScheduleCalendar	- a reference to the current catalog item.
//  YearNumber		- Number of the year for which the schedule is to be read.
//
// Returns:
//   Map - Key is date.
//
Function ReadScheduleDataFromRegister(WorkScheduleCalendar, YearNumber) Export
	
	QueryText =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkScheduleCalendar
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayAddedToSchedule
	|
	|ORDER BY
	|	CalendarDate";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkScheduleCalendar",	WorkScheduleCalendar);
	Query.SetParameter("CurrentYear",		YearNumber);
	
	DaysIncludedInSchedule = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DaysIncludedInSchedule.Insert(Selection.CalendarDate, True);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

// The procedure writes the schedule data to the register.
//
// Parameters:
//  WorkScheduleCalendar	- reference to the current catalog item.
//  YearNumber		- Number of the year for which the schedule is to be recorded.
//  DaysIncludedInSchedule - 
//
// 
//  
//
Procedure WriteScheduleDataToRegister(WorkScheduleCalendar, DaysIncludedInSchedule, StartDate, EndDate, 
	ReplaceManualChanges = False) Export
	
	SetDays = InformationRegisters.CalendarSchedules.CreateRecordSet();
	SetDays.Filter.Calendar.Set(WorkScheduleCalendar);
	
	// 
	// 
	//  
	//  
	// 
	// 
	
	DataByYears = New Map;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		DataByYears.Insert(Year(DayDate), True);
		DayDate = DayDate + DayDurationInSeconds();
	EndDo;
	
	ManualChanges = Undefined;
	If Not ReplaceManualChanges Then
		ManualChanges = ManualScheduleChanges(WorkScheduleCalendar);
	EndIf;
	
	// Process data by years.
	For Each KeyAndValue In DataByYears Do
		Year = KeyAndValue.Key;
		// 
		SetDays.Filter.Year.Set(Year);
		BeginTransaction();
		Try
			DataLock = New DataLock;
			LockItem = DataLock.Add("InformationRegister.CalendarSchedules");
			LockItem.SetValue("Calendar", WorkScheduleCalendar);
			LockItem.SetValue("Year", Year);
			DataLock.Lock();
			SetDays.Read();
			FillDaysSetForYear(SetDays, DaysIncludedInSchedule, Year, WorkScheduleCalendar, ManualChanges, StartDate, EndDate);
			If InfobaseUpdate.IsCallFromUpdateHandler() Then
				InfobaseUpdate.WriteRecordSet(SetDays);
			Else
				SetDays.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

Procedure FillDaysSetForYear(SetDays, DaysIncludedInSchedule, Year, WorkScheduleCalendar, ManualChanges, StartDate, EndDate)
	
	// Fill in contents of the set according to the dates for fast access.
	SetRowsDays = New Map;
	For Each SetRow In SetDays Do
		SetRowsDays.Insert(SetRow.ScheduleDate, SetRow);
	EndDo;
	
	BegOfYear = Date(Year, 1, 1);
	EndOfYear = Date(Year, 12, 31);
	
	TraversalStart = ?(StartDate > BegOfYear, StartDate, BegOfYear);
	TraversalEnd = ?(EndDate < EndOfYear, EndDate, EndOfYear);
	
	// The data in the set should be replaced for the traversal period.
	DayDate = TraversalStart;
	While DayDate <= TraversalEnd Do
		
		If ManualChanges <> Undefined And ManualChanges[DayDate] <> Undefined Then
			// 
			DayDate = DayDate + DayDurationInSeconds();
			Continue;
		EndIf;
		
		// If the set has no row for a date, create it.
		SetRowDays = SetRowsDays[DayDate];
		If SetRowDays = Undefined Then
			SetRowDays = SetDays.Add();
			SetRowDays.Calendar = WorkScheduleCalendar;
			SetRowDays.Year = Year;
			SetRowDays.ScheduleDate = DayDate;
			SetRowsDays.Insert(DayDate, SetRowDays);
		EndIf;
		
		// If the day is included in the schedule, fill in the intervals.
		DayData = DaysIncludedInSchedule.Get(DayDate);
		If DayData = Undefined Then
			// Удаляем строку из набора, если день - 
			SetDays.Delete(SetRowDays);
			SetRowsDays.Delete(DayDate);
		Else
			SetRowDays.DayAddedToSchedule = True;
		EndIf;
		DayDate = DayDate + DayDurationInSeconds();
	EndDo;
	
	// Fill in secondary data to optimize calculations based on calendars.
	DateCounter = BegOfYear;
	DaysCountInScheduleSinceBegOfYear = 0;
	While DateCounter <= EndOfYear Do
		SetRowDays = SetRowsDays[DateCounter];
		If SetRowDays <> Undefined Then
			// 
			DaysCountInScheduleSinceBegOfYear = DaysCountInScheduleSinceBegOfYear + 1;
		Else
			// 
			SetRowDays = SetDays.Add();
			SetRowDays.Calendar = WorkScheduleCalendar;
			SetRowDays.Year = Year;
			SetRowDays.ScheduleDate = DateCounter;
		EndIf;
		SetRowDays.DaysCountInScheduleSinceBegOfYear = DaysCountInScheduleSinceBegOfYear;
		DateCounter = DateCounter + DayDurationInSeconds();
	EndDo;
	
EndProcedure

// The constructor of parameters for filling the work schedule for methods: 
// DaysIncludedInSchedule, DaysIncludedInScheduleByWeeks, DaysIncludedInScheduleCustomPeriods. 
// 
// Returns:
//   Structure:
//   * BusinessCalendar 
//   * FillingMethod 
//   * FillingTemplate 
//   * ConsiderHolidays 
//   * ConsiderNonWorkPeriods 
//   * NonWorkPeriods 
//   * StartingDate 
//
Function ScheduleFillingParameters() Export
	FillParameters = New Structure(
		"BusinessCalendar,
		|FillingMethod,
		|FillingTemplate,
		|ConsiderHolidays,
		|ConsiderNonWorkPeriods,
		|NonWorkPeriods,
		|StartingDate");
	FillParameters.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	FillParameters.NonWorkPeriods = New Array;
	Return FillParameters;
EndFunction

// Creates a collection of workdays based on a business calendar, 
//  filling method, and other settings.
// 
// Parameters:
//   StartDate - Date - data filling start.
//   EndDate - Date - data filling end.
//   FillParameters - see FillingParameters.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - Date
//     * Value - Array of Structure - describing time intervals
//         for the specified date.
//
Function DaysIncludedInSchedule(StartDate, EndDate, FillParameters) Export
	
	DaysIncludedInSchedule = New Map;
	
	If FillParameters.FillingTemplate.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	If Not ValueIsFilled(EndDate) Then
		// 
		EndDate = EndOfYear(StartDate);
		If ValueIsFilled(FillParameters.BusinessCalendar) Then
			// If the business calendar is specified, filling till the end of the calendar.
			FillingEndDate = Catalogs.BusinessCalendars.BusinessCalendarFillingEndDate(
				FillParameters.BusinessCalendar);
			If FillingEndDate <> Undefined 
				And FillingEndDate > EndDate Then
				EndDate = FillingEndDate;
			EndIf;
		EndIf;
	EndIf;
	
	If ValueIsFilled(FillParameters.BusinessCalendar) Then
		FillParameters.NonWorkPeriods = CalendarSchedules.NonWorkDaysPeriods(
			FillParameters.BusinessCalendar, New StandardPeriod(StartDate, EndDate));
	EndIf;
	
	Years = YearsInTheInterval(StartDate, EndDate);
	If FillParameters.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks Then
		Return DaysIncludedInScheduleByWeeks(Years, FillParameters, StartDate, EndDate);
	Else
		Return DaysIncludedInScheduleCustomPeriods(Years, FillParameters, StartDate, EndDate);
	EndIf;
	
EndFunction

Function DaysIncludedInScheduleByWeeks(Years, FillParameters, 
	Val StartDate = Undefined, Val EndDate = Undefined)
	
	DaysIncludedInSchedule = New Map;
	
	FillByBusinessCalendar = ValueIsFilled(FillParameters.BusinessCalendar);
	
	If FillByBusinessCalendar Then
		BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(
			FillParameters.BusinessCalendar, Years);
		BusinessCalendarData.Indexes.Add("Year");
		BusinessCalendarData.Indexes.Add("Date");
		YearsCalendarIsNotFilledIn = New Array;
		For Each Year In Years Do
			If BusinessCalendarData.FindRows(New Structure("Year", Year)).Count() 
				<> DayOfYear(Date(Year, 12, 31)) Then
				// 
				YearsCalendarIsNotFilledIn.Add(Year);
			EndIf;
		EndDo;
	EndIf;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		DayNumber = WeekDay(DayDate);
		If FillByBusinessCalendar Then
			If YearsCalendarIsNotFilledIn.Find(Year(DayDate)) <> Undefined Then
				DayDate = AddAYear(DayDate);
				Continue;
			EndIf;
			If FillParameters.ConsiderHolidays Or FillParameters.NonWorkPeriods.Count() > 0 Then 
				DayData = BusinessCalendarData.FindRows(New Structure("Date", DayDate))[0];
				DayNumber = TemplateDayNumber(DayData, FillParameters);
			EndIf;
		EndIf;
		If DayNumber <> Undefined Then
			DayRow = FillParameters.FillingTemplate[DayNumber - 1];
			If DayRow.DayAddedToSchedule Then
				DaysIncludedInSchedule.Insert(DayDate, True);
			EndIf;
		EndIf;
		DayDate = AddADay(DayDate);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleCustomPeriods(Years, FillParameters, 
	Val StartDate = Undefined, Val EndDate = Undefined)
	
	DaysIncludedInSchedule = New Map;
	
	DayDate = FillParameters.StartingDate;
	While DayDate <= EndDate Do
		For Each DayRow In FillParameters.FillingTemplate Do
			If DayDate > EndDate Then
				Break;
			EndIf;
			If DayRow.DayAddedToSchedule 
				And DayDate >= StartDate Then
				DaysIncludedInSchedule.Insert(DayDate, True);
			EndIf;
			DayDate = AddADay(DayDate);
		EndDo;
	EndDo;
	
	If Not FillParameters.ConsiderHolidays And FillParameters.NonWorkPeriods.Count() = 0 Then  
		Return DaysIncludedInSchedule;
	EndIf;
	
	// Excluding holidays.
	
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(
		FillParameters.BusinessCalendar, Years);
	If BusinessCalendarData.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	If FillParameters.ConsiderNonWorkPeriods Then 
		BusinessCalendarData.Indexes.Add("Date");
		For Each NonWorkPeriod In FillParameters.NonWorkPeriods Do
			For Each Date In NonWorkPeriod.Dates Do
				DaysIncludedInSchedule.Delete(Date);
			EndDo;
		EndDo;
	EndIf;
	
	If FillParameters.ConsiderHolidays Then
		BusinessCalendarData.Indexes.Add("DayKind");
		RowFilter = New Structure("DayKind");
		RowFilter.DayKind = Enums.BusinessCalendarDaysKinds.Holiday;
		HolidaysData = BusinessCalendarData.FindRows(RowFilter);
		For Each DayData In HolidaysData Do
			DaysIncludedInSchedule.Delete(DayData.Date);
		EndDo;
		NonWorkPeriodsDates = New Array;
		RowFilter.DayKind = Enums.BusinessCalendarDaysKinds.Nonworking;
		NonWorkDaysData = BusinessCalendarData.FindRows(RowFilter);
		If NonWorkDaysData.Count() > 0 Then
			If Not FillParameters.ConsiderNonWorkPeriods Then
				For Each NonWorkPeriod In FillParameters.NonWorkPeriods Do
					CommonClientServer.SupplementArray(NonWorkPeriodsDates, NonWorkPeriod.Dates);
				EndDo;
			EndIf;
		EndIf;
		For Each DayData In NonWorkDaysData Do
			If NonWorkPeriodsDates.Find(DayData.Date) = Undefined Then
				DaysIncludedInSchedule.Delete(DayData.Date);
			EndIf;
		EndDo;
	EndIf;
		
	Return DaysIncludedInSchedule;
	
EndFunction

// Determines dates when the specified schedule was changed manually.
//
Function ManualScheduleChanges(WorkScheduleCalendar)
	
	Query = New Query(
	"SELECT
	|	ManualChanges.WorkScheduleCalendar,
	|	ManualChanges.Year,
	|	ManualChanges.ScheduleDate,
	|	ISNULL(CalendarSchedules.DayAddedToSchedule, FALSE) AS DayAddedToSchedule
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = ManualChanges.WorkScheduleCalendar)
	|			AND (CalendarSchedules.Year = ManualChanges.Year)
	|			AND (CalendarSchedules.ScheduleDate = ManualChanges.ScheduleDate)
	|WHERE
	|	ManualChanges.WorkScheduleCalendar = &WorkScheduleCalendar
	|	AND ManualChanges.ScheduleDate <> DATETIME(1, 1, 1)");

	Query.SetParameter("WorkScheduleCalendar", WorkScheduleCalendar);
	
	Selection = Query.Execute().Select();
	
	ManualChanges = New Map;
	While Selection.Next() Do
		ManualChanges.Insert(Selection.ScheduleDate, Selection.DayAddedToSchedule);
	EndDo;
	
	Return ManualChanges;
	
EndFunction

Function TemplateDayNumber(DayData, FillParameters)
	
	DayKind = DayData.DayKind;
	If ThisDateInNonWorkPeriod(DayData.Date, FillParameters.NonWorkPeriods) Then
		If FillParameters.ConsiderNonWorkPeriods Then
			Return Undefined;
		EndIf;
		If DayKind = Enums.BusinessCalendarDaysKinds.Nonworking Then
			DayKind = Enums.BusinessCalendarDaysKinds.Work;
		EndIf;
	EndIf;
	
	If DayKind = Enums.BusinessCalendarDaysKinds.Work 
		Or DayKind = Enums.BusinessCalendarDaysKinds.Preholiday Then
		DayDate = DayData.Date;
		If ValueIsFilled(DayData.ReplacementDate) Then
			DayDate = DayData.ReplacementDate;
		EndIf;
		Return WeekDay(DayDate);
	EndIf;
	
	If DayKind = Enums.BusinessCalendarDaysKinds.Saturday Then
		Return 6;
	EndIf;
	
	If DayKind = Enums.BusinessCalendarDaysKinds.Sunday Then
		Return 7;
	EndIf;

	If DayKind = Enums.BusinessCalendarDaysKinds.Holiday 
		Or DayKind = Enums.BusinessCalendarDaysKinds.Nonworking Then
		If FillParameters.ConsiderHolidays Then
			Return Undefined;
		EndIf;
	EndIf;

	Return WeekDay(DayData.Date);
	
EndFunction

Function ThisDateInNonWorkPeriod(Date, NonWorkPeriods)
	
	For Each NonWorkPeriod In NonWorkPeriods Do
		If NonWorkPeriod.Dates.Find(Date) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
		
EndFunction

Function DayDurationInSeconds()
	Return 24 * 60 * 60;
EndFunction

Function AddADay(Date, OfDays = 1)
	Return Date + OfDays * DayDurationInSeconds();
EndFunction

Function AddAYear(Date)
	Return AddMonth(Date, 12);
EndFunction

Function YearsInTheInterval(StartDate, EndDate)
	
	Years = New Array;
	
	CurrentYear = Year(StartDate);
	While CurrentYear <= Year(EndDate) Do
		Years.Add(CurrentYear);
		CurrentYear = CurrentYear + 1;
	EndDo;
	
	Return Years;

EndFunction

#EndRegion

#EndIf	