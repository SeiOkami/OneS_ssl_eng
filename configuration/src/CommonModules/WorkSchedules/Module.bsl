///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns dates that differ from the specified date DateFrom by the number of days
// included in the specified schedule WorkScheduleCalendar.
//
// Parameters:
//  WorkScheduleCalendar	- CatalogRef.Calendars - schedule to be used.
//  DateFrom			- Date - a date starting from which the number of days is to be calculated.
//  DaysArray		- Array - a number of days by which the start date is to be increased.
//  CalculateNextDateFromPrevious	- Boolean - shows whether the following date is to be calculated 
//											           from the previous one or all dates are calculated from the passed date.
//  RaiseException1 - Boolean - if True, an exception is thrown if the schedule is not filled in.
//
// Returns:
//  Array, Undefined - Dates incremented by the number of days from WorkSchedule.
//	                       If WorkSchedule is empty and RaiseException = False, return Undefined.
//
Function DatesBySchedule(Val WorkScheduleCalendar, Val DateFrom, Val DaysArray, 
	Val CalculateNextDateFromPrevious = False, RaiseException1 = True) Export
	
	ShiftDays = CalendarSchedules.DaysIncrement(DaysArray, CalculateNextDateFromPrevious);
	
	Query = New Query;
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkScheduleCalendar", WorkScheduleCalendar);
	Query.SetParameter("Days", ShiftDays.DaysIncrement.UnloadColumn("DaysCount"));
	Query.Text =
		"SELECT TOP 0
		|	CalendarSchedules.ScheduleDate AS Date
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|WHERE
		|	CalendarSchedules.ScheduleDate > &DateFrom
		|	AND CalendarSchedules.Calendar = &WorkScheduleCalendar
		|	AND CalendarSchedules.DayAddedToSchedule
		|
		|ORDER BY
		|	Date";

	// 
	QuerySchema = New QuerySchema();
	QuerySchema.SetQueryText(Query.Text);
	QuerySchema.QueryBatch[0].Operators[0].RetrievedRecordsCount = ShiftDays.Maximum;
	Query.Text = QuerySchema.GetQueryText();
	
	RequestedDays = New Map();
	For Each TableRow In ShiftDays.DaysIncrement Do
		RequestedDays.Insert(TableRow.DaysCount, False);
	EndDo;
	
	Selection = Query.Execute().Select();
	If Selection.Count() < ShiftDays.Maximum Then
		If RaiseException1 Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'График работы ""%1"" не заполнен с даты %2 на указанное количество рабочих дней.';"), 
				WorkScheduleCalendar, 
				Format(DateFrom, "DLF=D"));
		Else
			Return Undefined;
		EndIf;
	EndIf;
	
	OfDays = 0;
	While Selection.Next() Do
		OfDays = OfDays + 1;
		If RequestedDays[OfDays] = False Then
			RequestedDays.Insert(OfDays, Selection.Date);
		EndIf;
	EndDo;
	
	DatesArray = New Array;
	For Each TableRow In ShiftDays.DaysIncrement Do
		Date = RequestedDays[TableRow.DaysCount];
		CommonClientServer.Validate(TypeOf(Date) = Type("Date") And ValueIsFilled(Date));
		DatesArray.Add(Date);
	EndDo;
	
	Return DatesArray;
	
EndFunction

// Returns a date that differs from the specified date DateFrom by the number of days
// included in the specified schedule WorkScheduleCalendar.
//
// Parameters:
//  WorkScheduleCalendar	- CatalogRef.Calendars - schedule to be used.
//  DateFrom			- Date - a date starting from which the number of days is to be calculated.
//  DaysCount	- Number - number of days by which the start date DateFrom is to be increased.
//  RaiseException1 - Boolean - if True, an exception is thrown if the schedule is not filled in.
//
// Returns:
//  Date, Undefined - Date incremented by the number of days from WorkSchedule.
//	                     If WorkSchedule is empty and RaiseException = False, return Undefined.
//
Function DateAccordingToSchedule(Val WorkScheduleCalendar, Val DateFrom, Val DaysCount, RaiseException1 = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysCount = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysCount);
	
	DatesArray = DatesBySchedule(WorkScheduleCalendar, DateFrom, DaysArray, , RaiseException1);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// The constructor of parameters for getting dates nearest to the specified ones and included in the schedule.
//  See NearestWorkDates.
// 
// Returns:
//  Structure:
//   * GetPrevious - Boolean - a method of getting the closest date:
//       if True, workdays preceding the ones passed in the InitialDates parameter are defined,
//       if False, the nearest workdays following the start dates are defined.
//       The default value is False:
//   * IgnoreUnfilledSchedule - Boolean - if True, a map returns in any way.
//       Initial dates whose values are missing because of unfilled schedule will not be included.
//       False - a default value:
//   * RaiseException1 - Boolean - raising an exception if the schedule is not filled in
//       If True, raise an exception if the schedule is not filled in.
//       If False, dates whose nearest date is not identified will be ignored.
//       The default value is True.
//
Function NearestDatesByScheduleReceivingParameters() Export
	Parameters = New Structure(
		"GetPrevious,
		|IgnoreUnfilledSchedule,
		|RaiseException1");
	Parameters.GetPrevious = False;
	Parameters.IgnoreUnfilledSchedule = False;
	Parameters.RaiseException1 = True;
	Return Parameters;
EndFunction

// Defines a date of the nearest workday included in the schedule for each date.
//
// Parameters:
//  WorkScheduleCalendar		 - CatalogRef.Calendars
//  InitialDates		 - Array of Date - dates to which the nearest ones must be detected.
//  ReceivingParameters	 - See NearestDatesByScheduleReceivingParameters.
// 
// Returns:
//  Map of KeyAndValue:
//   * Key - Date - start date.
//   * Value - Date - the date nearest to it and included in the schedule.
//
Function NearestDatesIncludedInSchedule(WorkScheduleCalendar, InitialDates, ReceivingParameters = Undefined) Export
	
	If ReceivingParameters = Undefined Then
		ReceivingParameters = NearestDatesByScheduleReceivingParameters();
	EndIf;
	
	CommonClientServer.CheckParameter(
		"WorkSchedules.NearestDatesIncludedInSchedule", 
		"WorkScheduleCalendar", 
		WorkScheduleCalendar, 
		Type("CatalogRef.Calendars"));

	CommonClientServer.Validate(
		ValueIsFilled(WorkScheduleCalendar), 
		NStr("en = 'Work schedule is not specified.';"), 
		"WorkSchedules.NearestDatesIncludedInSchedule");
	
	QueryTextTT = "";
	FirstPart = True;
	For Each InitialDate In InitialDates Do
		If Not ValueIsFilled(InitialDate) Then
			Continue;
		EndIf;
		If Not FirstPart Then
			QueryTextTT = QueryTextTT + "
			|UNION ALL
			|";
		EndIf;
		If FirstPart Then
			QueryText = "
			|SELECT
			|	DATETIME(2000,01,01) AS Date 
			|INTO TTInitialDates
			|";
		Else	
			QueryText = "
			|SELECT
			|	DATETIME(2000,01,01)";
		EndIf;
		QueryTextTT = QueryTextTT + StrReplace(QueryText, "2000,01,01", 
			Format(InitialDate, "DF=yyyy,MM,dd"));
		FirstPart = False;
	EndDo;

	If IsBlankString(QueryTextTT) Then
		Return New Map;
	EndIf;

	Query = New Query(QueryTextTT);
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	QueryText = 
		"SELECT
		|	InitialDates.Date,
		|	MIN(CalendarDates.ScheduleDate) AS NearestDate
		|FROM
		|	TTInitialDates AS InitialDates
		|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarDates
		|		ON (CalendarDates.ScheduleDate >= InitialDates.Date)
		|			AND (CalendarDates.Calendar = &Schedule)
		|			AND (CalendarDates.DayAddedToSchedule)
		|
		|GROUP BY
		|	InitialDates.Date";
	
	If ReceivingParameters.GetPrevious Then
		QueryText = StrReplace(QueryText, "MIN(CalendarDates.ScheduleDate)", "MAX(CalendarDates.ScheduleDate)");
		QueryText = StrReplace(QueryText, "CalendarDates.ScheduleDate >= InitialDates.Date", "CalendarDates.ScheduleDate <= InitialDates.Date");
	EndIf;
	Query.Text = QueryText;
	Query.SetParameter("Schedule", WorkScheduleCalendar);
	
	Selection = Query.Execute().Select();
	
	WorkdaysDates = New Map;
	While Selection.Next() Do
		If ValueIsFilled(Selection.NearestDate) Then
			WorkdaysDates.Insert(Selection.Date, Selection.NearestDate);
		Else 
			If ReceivingParameters.IgnoreUnfilledSchedule Then
				Continue;
			EndIf;
			If ReceivingParameters.RaiseException1 Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot determine the nearest date included in the schedule for date %1.
						 |The work schedule might be blank.';"), 
					Format(Selection.Date, "DLF=D"));
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	Return WorkdaysDates;
	
EndFunction

// Generates work schedules for dates included in the specified schedules for the specified period.
// If the schedule for a pre-holiday day is not set, it is defined as if this day is a workday.
//
// Parameters:
//  Schedules       - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//  StartDate    - Date   - a start date of the period, for which schedules are to be created.
//  EndDate - Date   - a period end date.
//
// Returns:
//   ValueTable:
//    * WorkScheduleCalendar    - CatalogRef.Calendars - work schedule.
//    * ScheduleDate     - Date - a date in the WorkScheduleCalendar work schedule.
//    * BeginTime     - Date - work start time on the ScheduleDate day.
//    * EndTime  - Date - work end time on the ScheduleDate day.
//
Function WorkSchedulesForPeriod(Schedules, StartDate, EndDate) Export
	
	TempTablesManager = New TempTablesManager;
	
	// Create a temporary schedule table.
	CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate);
	
	QueryText = 
	"SELECT
	|	WorkSchedules1.WorkScheduleCalendar,
	|	WorkSchedules1.ScheduleDate,
	|	WorkSchedules1.BeginTime,
	|	WorkSchedules1.EndTime
	|FROM
	|	TTWorkSchedules AS WorkSchedules1";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Creates temporary table TTWorkSchedules in the manager. The table contains columns matching the return
// value of the WorkSchedulesForPeriod function.
//
// Parameters:
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  Schedules       - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//  StartDate    - Date   - a start date of the period, for which schedules are to be created.
//  EndDate - Date   - a period end date.
//
Procedure CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	QueryText = 
	"SELECT
	|	FillingTemplate.Ref AS WorkScheduleCalendar,
	|	MAX(FillingTemplate.LineNumber) AS PeriodLength
	|INTO TTSchedulePeriodLength
	|FROM
	|	Catalog.Calendars.FillingTemplate AS FillingTemplate
	|WHERE
	|	FillingTemplate.Ref IN(&Calendars)
	|
	|GROUP BY
	|	FillingTemplate.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkScheduleCalendar,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	CASE
	|		WHEN BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDaysKinds.Preholiday)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS PreholidayDay
	|INTO TTPreHolidayDays
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDaysKinds.Preholiday))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkScheduleCalendar,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	BusinessCalendarData.ReplacementDate
	|INTO TTShiftDates
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.ReplacementDate <> DATETIME(1, 1, 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar AS WorkScheduleCalendar,
	|	CalendarSchedules.ScheduleDate AS ScheduleDate,
	|	DATEDIFF(Calendars.StartingDate, CalendarSchedules.ScheduleDate, DAY) + 1 AS DaysFromStartDate,
	|	PreholidayDays.PreholidayDay,
	|	ShiftDates.ReplacementDate
	|INTO TTDaysIncludedInSchedule
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON CalendarSchedules.Calendar = Calendars.Ref
	|			AND (CalendarSchedules.Calendar IN (&Calendars))
	|			AND (CalendarSchedules.ScheduleDate BETWEEN &StartDate AND &EndDate)
	|			AND (CalendarSchedules.DayAddedToSchedule)
	|		LEFT JOIN TTPreHolidayDays AS PreholidayDays
	|		ON (PreholidayDays.WorkScheduleCalendar = CalendarSchedules.Calendar)
	|			AND (PreholidayDays.ScheduleDate = CalendarSchedules.ScheduleDate)
	|		LEFT JOIN TTShiftDates AS ShiftDates
	|		ON (ShiftDates.WorkScheduleCalendar = CalendarSchedules.Calendar)
	|			AND (ShiftDates.ScheduleDate = CalendarSchedules.ScheduleDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncludedInSchedule.WorkScheduleCalendar,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ModuloOperationResult = 0
	|			THEN DaysIncludedInSchedule.PeriodLength
	|		ELSE DaysIncludedInSchedule.ModuloOperationResult
	|	END AS DayNumber,
	|	DaysIncludedInSchedule.PreholidayDay
	|INTO TTDatesDayNumbers
	|FROM
	|	(SELECT
	|		DaysIncludedInSchedule.WorkScheduleCalendar AS WorkScheduleCalendar,
	|		DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|		DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|		DaysIncludedInSchedule.PeriodLength AS PeriodLength,
	|		DaysIncludedInSchedule.DaysFromStartDate - DaysIncludedInSchedule.DivisionOutputIntegerPart * DaysIncludedInSchedule.PeriodLength AS ModuloOperationResult
	|	FROM
	|		(SELECT
	|			DaysIncludedInSchedule.WorkScheduleCalendar AS WorkScheduleCalendar,
	|			DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|			DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|			DaysIncludedInSchedule.DaysFromStartDate AS DaysFromStartDate,
	|			PeriodsLength.PeriodLength AS PeriodLength,
	|			(CAST(DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) - CASE
	|				WHEN (CAST(DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) > DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength
	|					THEN 1
	|				ELSE 0
	|			END AS DivisionOutputIntegerPart
	|		FROM
	|			TTDaysIncludedInSchedule AS DaysIncludedInSchedule
	|				INNER JOIN Catalog.Calendars AS Calendars
	|				ON DaysIncludedInSchedule.WorkScheduleCalendar = Calendars.Ref
	|					AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods))
	|				INNER JOIN TTSchedulePeriodLength AS PeriodsLength
	|				ON DaysIncludedInSchedule.WorkScheduleCalendar = PeriodsLength.WorkScheduleCalendar) AS DaysIncludedInSchedule) AS DaysIncludedInSchedule
	|
	|UNION ALL
	|
	|SELECT
	|	DaysIncludedInSchedule.WorkScheduleCalendar,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ReplacementDate IS NULL 
	|			THEN WEEKDAY(DaysIncludedInSchedule.ScheduleDate)
	|		ELSE WEEKDAY(DaysIncludedInSchedule.ReplacementDate)
	|	END,
	|	DaysIncludedInSchedule.PreholidayDay
	|FROM
	|	TTDaysIncludedInSchedule AS DaysIncludedInSchedule
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON DaysIncludedInSchedule.WorkScheduleCalendar = Calendars.Ref
	|WHERE
	|	Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DaysIncludedInSchedule.WorkScheduleCalendar,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	DaysIncludedInSchedule.DayNumber,
	|	ISNULL(PreholidayWorkSchedules.BeginTime, WorkSchedules1.BeginTime) AS BeginTime,
	|	ISNULL(PreholidayWorkSchedules.EndTime, WorkSchedules1.EndTime) AS EndTime
	|INTO TTWorkSchedules
	|FROM
	|	TTDatesDayNumbers AS DaysIncludedInSchedule
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS WorkSchedules1
	|		ON (WorkSchedules1.Ref = DaysIncludedInSchedule.WorkScheduleCalendar)
	|			AND (WorkSchedules1.DayNumber = DaysIncludedInSchedule.DayNumber)
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS PreholidayWorkSchedules
	|		ON (PreholidayWorkSchedules.Ref = DaysIncludedInSchedule.WorkScheduleCalendar)
	|			AND (PreholidayWorkSchedules.DayNumber = 0)
	|			AND (DaysIncludedInSchedule.PreholidayDay)
	|
	|INDEX BY
	|	DaysIncludedInSchedule.WorkScheduleCalendar,
	|	DaysIncludedInSchedule.ScheduleDate";
	
	// 
	// 
	
	// 
	// 
	
	// 
	// 
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Calendars", Schedules);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.Execute();
	
EndProcedure

#EndRegion

#Region Internal

// Uses business calendar data to update 
// work schedules.
//
// Parameters:
//  - UpdateConditions - ValueTable:
//    - BusinessCalendarCode - Code of the modified business calendar.
//    - Year - Year whose data must be updated.
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	InformationRegisters.CalendarSchedules.UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions);
	
EndProcedure

// Adds work schedule catalog to the list of locked items 
// to make schedules unavailable for changing by user while updating business calendars.
//
// Parameters:
//  ObjectsToLock - Array of String - metadata names of objects to be blocked.
//
Procedure FillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock) Export
	
	ObjectsToLock.Add("Catalog.Calendars");
	
EndProcedure

// Adds the register of calendar schedules to the list of objects to be changed.
//
// Parameters:
//  ObjectsToChange - Array of String - metadata names of objects to be changed.
//
Procedure FillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange) Export
	
	ObjectsToChange.Add("InformationRegister.CalendarSchedules");
	
EndProcedure

// Defines the number of days included in the schedule for the specified period.
//
// Parameters:
//   WorkScheduleCalendar	- CatalogRef.Calendars -
//   StartDate		- Date - start date of the period.
//   EndDate	- Date - end date of the period.
//   RaiseException1 - Boolean - if True, throw an exception if the graph is empty.
//
// Returns:
//   Number		- 
//	              
//
Function DateDiffByCalendar(Val WorkScheduleCalendar, Val StartDate, Val EndDate, RaiseException1 = True) Export
	
	If Not ValueIsFilled(WorkScheduleCalendar) Then
		If RaiseException1 Then
			Raise NStr("en = 'Work schedule is not specified.';");
		EndIf;
		Return Undefined;
	EndIf;
	
	StartDate = BegOfDay(StartDate);
	EndDate = BegOfDay(EndDate);
	
	ScheduleDates = New Array;
	ScheduleDates.Add(StartDate);
	If Year(StartDate) <> Year(EndDate) And EndOfDay(StartDate) <> EndOfYear(StartDate) Then
		// 
		For YearNumber = Year(StartDate) To Year(EndDate) - 1 Do
			ScheduleDates.Add(Date(YearNumber, 12, 31));
		EndDo;
	EndIf;
	ScheduleDates.Add(EndDate);
	
	// 
	QueryText = "";
	For Each ScheduleDate In ScheduleDates Do
		If IsBlankString(QueryText) Then
			UnionTemplate = 
			"SELECT
			|	DATETIME(2020,01,01) AS ScheduleDate
			|INTO TTScheduleDates
			|";
		Else
			UnionTemplate = 
			"UNION ALL
			|
			|SELECT
			|	DATETIME(2020,01,01)";
		EndIf;
		QueryText = QueryText + StrReplace(
			UnionTemplate, "2020,01,01", Format(ScheduleDate, """DF='yyyy,MM,d'")); // 
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
	// 
	Query.SetParameter("WorkScheduleCalendar", WorkScheduleCalendar);
	Query.Text =
	"SELECT DISTINCT
	|	ScheduleDates.ScheduleDate AS ScheduleDate
	|INTO TTDifferentScheduleDates
	|FROM
	|	TTScheduleDates AS ScheduleDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	YEAR(ScheduleDates.ScheduleDate) AS Year
	|INTO TTDifferentScheduleYears
	|FROM
	|	TTScheduleDates AS ScheduleDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Year AS Year,
	|	CalendarSchedules.ScheduleDate AS ScheduleDate,
	|	CalendarSchedules.DayAddedToSchedule AS DayAddedToSchedule
	|INTO TTCalendarSchedules
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN TTDifferentScheduleYears AS ScheduleYears
	|		ON (ScheduleYears.Year = CalendarSchedules.Year)
	|WHERE
	|	CalendarSchedules.Calendar = &WorkScheduleCalendar
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleDates.ScheduleDate AS ScheduleDate,
	|	COUNT(DaysIncludedInSchedule.ScheduleDate) AS DaysCountInScheduleSinceBegOfYear
	|INTO TTNumberOfDaysInSchedule
	|FROM
	|	TTDifferentScheduleDates AS ScheduleDates
	|		LEFT JOIN TTCalendarSchedules AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (DaysIncludedInSchedule.ScheduleDate <= ScheduleDates.ScheduleDate)
	|			AND (DaysIncludedInSchedule.DayAddedToSchedule)
	|
	|GROUP BY
	|	ScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleDates.ScheduleDate AS ScheduleDate,
	|	ISNULL(ScheduleData.DayAddedToSchedule, FALSE) AS DayAddedToSchedule,
	|	DaysIncludedInSchedule.DaysCountInScheduleSinceBegOfYear AS DaysCountInScheduleSinceBegOfYear
	|FROM
	|	TTScheduleDates AS ScheduleDates
	|		LEFT JOIN TTCalendarSchedules AS ScheduleData
	|		ON (ScheduleData.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (ScheduleData.ScheduleDate = ScheduleDates.ScheduleDate)
	|		LEFT JOIN TTNumberOfDaysInSchedule AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.ScheduleDate = ScheduleDates.ScheduleDate)
	|
	|ORDER BY
	|	ScheduleDates.ScheduleDate";
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		If RaiseException1 Then
			ErrorMessage = NStr("en = 'The ""%1"" work schedule is blank for period: %2.';");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, WorkScheduleCalendar, PeriodPresentation(StartDate, EndOfDay(EndDate)));
		Else
			Return Undefined;
		EndIf;
	EndIf;
	
	Selection = Result.Select();
	
	//  
	// 
	//  
	// 
	//  
	//  
	// 
	
	DaysCountInSchedule = Undefined;
	AddFirstDay = False;
	
	While Selection.Next() Do
		If DaysCountInSchedule = Undefined Then
			DaysCountInSchedule = Selection.DaysCountInScheduleSinceBegOfYear;
			AddFirstDay = Selection.DayAddedToSchedule;
		Else
			DaysCountInSchedule = DaysCountInSchedule - Selection.DaysCountInScheduleSinceBegOfYear;
		EndIf;
	EndDo;
	
	Return - DaysCountInSchedule + ?(AddFirstDay, 1, 0);
	
EndFunction

Function WorkSchedulesUpdateProcedureName() Export
	
	Return "InformationRegisters.CalendarSchedules.ProcessDataForMigrationToNewVersion";
	
EndFunction

Function ConsiderNonWorkDaysFlagSettingProcedureName() Export
	
	Return "Catalogs.Calendars.ProcessDataForMigrationToNewVersion";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Metadata.DataProcessors.Find("FillWorkSchedules") <> Undefined Then
		ModuleFillingInWorkSchedules = Common.CommonModule("DataProcessors.FillWorkSchedules");
		ModuleFillingInWorkSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.2.78";
	Handler.Procedure = "InformationRegisters.CalendarSchedules.ProcessDataForMigrationToNewVersion";
	Handler.UpdateDataFillingProcedure = "InformationRegisters.CalendarSchedules.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.ObjectsToRead = "InformationRegister.CalendarSchedules, InformationRegister.ManualWorkScheduleChanges, InformationRegister.BusinessCalendarData";
	Handler.ObjectsToChange = "InformationRegister.CalendarSchedules";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Id = New UUID("39e6fbf8-c02d-4459-bdbd-58adf6c6127c");
	Handler.Comment = NStr("en = 'Corrects the inclusion of working days and days before the holidays falling on Saturdays or Sundays in the schedule.';");
	Handler.ObjectsToLock = "Catalog.Calendars";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	
	If CalendarSchedules.ThereAreChangeableObjectsDependentOnProductionCalendars() Then
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "CalendarSchedules.UpdateDataDependentOnBusinessCalendars";
		Priority.Order = "After";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.3.94";
	Handler.Procedure = "Catalogs.Calendars.ProcessDataForMigrationToNewVersion";
	Handler.UpdateDataFillingProcedure = "Catalogs.Calendars.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.ObjectsToRead = "Catalog.Calendars";
	Handler.ObjectsToChange = "Catalog.Calendars";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Id = New UUID("fe8c3f3a-8973-4538-a993-ba74fa9162d8");
	Handler.Comment = NStr("en = 'Set the new ""Skip non-work periods"" flag to the default value.';");
	Handler.ObjectsToLock = "Catalog.Calendars";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	
	If CalendarSchedules.ThereAreChangeableObjectsDependentOnProductionCalendars() Then
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "CalendarSchedules.UpdateDataDependentOnBusinessCalendars";
		Priority.Order = "Before";
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// СовместноДляПользователейИВнешнихПользователей.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadWorkSchedules.Name);
	
EndProcedure

// See DuplicateObjectsDetection.TypesToExcludeFromPossibleDuplicates
Procedure OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude) Export

	CommonClientServer.SupplementArray(
		TypesToExclude, Metadata.DefinedTypes.WorkScheduleOwner.Type.Types()); 

EndProcedure

#EndRegion

#Region Private

Function TwelveHourTimeFormat() Export
	
	TimePresentation = Format(CurrentSessionDate(), "DLF=T");
	If Upper(Right(TimePresentation, 1)) = "M" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
