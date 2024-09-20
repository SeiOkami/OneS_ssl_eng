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
//   WorkScheduleCalendar	- CatalogRef.Calendars
//	             	- CatalogRef.BusinessCalendars -  
//                    
//   DateFrom			- Date - a date starting from which the number of days is to be calculated.
//   DaysArray		- Array of Number - a number of days by which the start date is to be increased.
//   CalculateNextDateFromPrevious	- Boolean - shows whether the following date is to be calculated
//											           from the previous one or all dates are calculated from the passed date.
//   RaiseException1 - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//   Undefined, Array - 
//	                        
//
Function DatesByCalendar(Val WorkScheduleCalendar, Val DateFrom, Val DaysArray, Val CalculateNextDateFromPrevious = False, RaiseException1 = True) Export
	
	If Not ValueIsFilled(WorkScheduleCalendar) Then
		If RaiseException1 Then
			Raise NStr("en = 'Work schedule or business calendar is not specified.';");
		EndIf;
		Return Undefined;
	EndIf;
	
	If TypeOf(WorkScheduleCalendar) <> Type("CatalogRef.BusinessCalendars") Then
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			Return ModuleWorkSchedules.DatesBySchedule(
				WorkScheduleCalendar, DateFrom, DaysArray, CalculateNextDateFromPrevious, RaiseException1);
		EndIf;
	EndIf;
	
	ShiftDays = DaysIncrement(DaysArray, CalculateNextDateFromPrevious);
	
	TypesOfDaysIncludedInCalculation = New Array();
	TypesOfDaysIncludedInCalculation.Add(Enums.BusinessCalendarDaysKinds.Work); 
	TypesOfDaysIncludedInCalculation.Add(Enums.BusinessCalendarDaysKinds.Preholiday);
	
	Query = New Query();
	Query.SetParameter("BusinessCalendar", WorkScheduleCalendar);
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("Days", ShiftDays.DaysIncrement.UnloadColumn("DaysCount"));
	Query.SetParameter("DaysKinds", TypesOfDaysIncludedInCalculation);
	Query.Text =
		"SELECT TOP 0
		|	CalendarSchedules.Date AS Date
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarSchedules
		|WHERE
		|	CalendarSchedules.Date > &DateFrom
		|	AND CalendarSchedules.BusinessCalendar = &BusinessCalendar
		|	AND CalendarSchedules.DayKind IN(&DaysKinds)
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
				NStr("en = 'Производственный календарь ""%1"" не заполнен с даты %2 на указанное количество рабочих дней.';"), 
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
// included in the specified schedule or the WorkScheduleCalendar business calendar.
//
// Parameters:
//   WorkScheduleCalendar	- CatalogRef.Calendars
//	             	- CatalogRef.BusinessCalendars -  
//                    
//   DateFrom			- Date - a date starting from which the number of days is to be calculated.
//   DaysCount	- Number - a number of days by which the start date is to be increased.
//   RaiseException1 - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//   Date, Undefined - 
//	                      
//
Function DateByCalendar(Val WorkScheduleCalendar, Val DateFrom, Val DaysCount, RaiseException1 = True) Export
	
	If Not ValueIsFilled(WorkScheduleCalendar) Then
		If RaiseException1 Then
			Raise NStr("en = 'Work schedule or business calendar is not specified.';");
		EndIf;
		Return Undefined;
	EndIf;
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysCount = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysCount);
	
	DatesArray = DatesByCalendar(WorkScheduleCalendar, DateFrom, DaysArray, , RaiseException1);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// Defines the number of days included in the schedule for the specified period.
//
// Parameters:
//   WorkScheduleCalendar	- CatalogRef.Calendars
//	             	- CatalogRef.BusinessCalendars -  
//                    
//   StartDate		- Date - a period start date.
//   EndDate	- Date - a period end date.
//   RaiseException1 - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//   Number		- 
//	              
//
Function DateDiffByCalendar(Val WorkScheduleCalendar, Val StartDate, Val EndDate, RaiseException1 = True) Export

	If Not ValueIsFilled(WorkScheduleCalendar) Then
		If RaiseException1 Then
			Raise NStr("en = 'Business calendar is not specified.';");
		EndIf;
		Return Undefined;
	EndIf;

	If TypeOf(WorkScheduleCalendar) <> Type("CatalogRef.BusinessCalendars") Then
		Result = Undefined;
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			Result = ModuleWorkSchedules.DateDiffByCalendar(WorkScheduleCalendar, StartDate, EndDate, RaiseException1);
		EndIf;
		Return Result;
	EndIf;

	If EndDate < StartDate Then
		Vrem = StartDate;
		StartDate = EndDate;
		EndDate = Vrem;
	EndIf;
	
	//  
	// 
	Years = New Array();
	Year = Year(StartDate);
	While Year <= Year(EndDate) Do
		Years.Add(Year);
		Year = Year + 1;
	EndDo;
	
	Query = New Query();
	Query.SetParameter("Calendar", WorkScheduleCalendar);
	Query.SetParameter("Years", Years);
	Query.Text = 
		"SELECT DISTINCT
		|	CalendarData.Year AS Year
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarData
		|WHERE
		|	CalendarData.BusinessCalendar = &Calendar
		|	AND CalendarData.Year IN(&Years)";
	If Query.Execute().Unload().Count() <> Years.Count() Then
		If RaiseException1 Then
			ErrorMessage = NStr("en = 'The ""%1"" work schedule is blank for period: %2.';");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, WorkScheduleCalendar, PeriodPresentation(StartDate, EndOfDay(EndDate)));
		Else
			Return Undefined;
		EndIf;
	EndIf;

	IncludedInSchedule = New Array();
	IncludedInSchedule.Add(Enums.BusinessCalendarDaysKinds.Work);
	IncludedInSchedule.Add(Enums.BusinessCalendarDaysKinds.Preholiday);
	
	Query = New Query();
	Query.SetParameter("Calendar", WorkScheduleCalendar);
	Query.SetParameter("Years", Years);
	Query.SetParameter("DaysKinds", IncludedInSchedule);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.Text = 
		"SELECT
		|	COUNT(CalendarData.Date) AS OfDays
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarData
		|WHERE
		|	CalendarData.BusinessCalendar = &Calendar
		|	AND CalendarData.Year IN(&Years)
		|	AND CalendarData.DayKind IN(&DaysKinds)
		|	AND CalendarData.Date BETWEEN &StartDate AND &EndDate";

	Return Query.Execute().Unload().UnloadColumn("OfDays")[0];

EndFunction

// A constructor of parameters for receiving the nearest workdays by a calendar.
//  See NearestWorkDates.
//
// Parameters:
//  BusinessCalendar	 - CatalogRef.BusinessCalendars	 -
//  	if specified, NonWorkPeriods will be filled in by default as an Array from the details
//  	received using the NonWorkDaysPeriods method.
// 
// Returns:
//  Structure:
//   * GetPrevious - Boolean - a method of getting the closest date:
//       if True, workdays preceding the ones passed in the InitialDates parameter are defined.
//       If False, the nearest workdays following the start dates are defined.
//       The default value is False:
//   * ConsiderNonWorkPeriods - Boolean - defines a relation to the dates that fall on non-work periods of the calendar.
//       If True, the dates that fall on a non-work period will be considered non-work ones.
//       If False, non-work periods will be ignored.
//       The default value is True:
//   * NonWorkPeriods - Undefined - specifies non-work periods to be considered.
//       You can set the Array of period numbers or details obtained by the NonWorkDaysPeriods method.
//       If Undefined, all the periods will be considered.
//       If the BusinessCalendar parameter is filled in, all the periods of this calendar will be filled in NonWorkPeriods.
//       The default value is Undefined:
//   * RaiseException1 - Boolean - raising an exception if the schedule is not filled in
//       If True, raise an exception if the schedule is not filled in.
//       If False, dates whose nearest date is not identified will be ignored.
//       The default value is True.
//
Function NearestWorkDatesReceivingParameters(BusinessCalendar = Undefined) Export
	Parameters = New Structure(
		"GetPrevious,
		|ConsiderNonWorkPeriods,
		|NonWorkPeriods,
		|RaiseException1");
	Parameters.GetPrevious = False;
	Parameters.ConsiderNonWorkPeriods = True;
	Parameters.RaiseException1 = True;
	If BusinessCalendar <> Undefined Then
		Parameters.NonWorkPeriods = NonWorkDaysPeriods(BusinessCalendar, New StandardPeriod());
	EndIf;
	Return Parameters;
EndFunction

// Defines a date of the nearest workday for each date.
//
// Parameters:
//  BusinessCalendar	 - CatalogRef.BusinessCalendars	 - a calendar used for calculation.
//  InitialDates				 - Array of Date - the dates to which the nearest ones will be searched.
//  ReceivingParameters			 - See NearestWorkDatesReceivingParameters.
// 
// Returns:
//  Map of KeyAndValue:
//   * Key - Date - a start date,
//   * Value - Date - the working date closest to it (if a working date is passed, it returns).
//
Function NearestWorkDates(BusinessCalendar, InitialDates, ReceivingParameters = Undefined) Export
	
	If ReceivingParameters = Undefined Then
		ReceivingParameters = NearestWorkDatesReceivingParameters();
	EndIf;
	
	CommonClientServer.CheckParameter(
		"CalendarSchedules.NearestWorkDates", 
		"BusinessCalendar", 
		BusinessCalendar, 
		Type("CatalogRef.BusinessCalendars"));

	CommonClientServer.Validate(
		ValueIsFilled(BusinessCalendar), 
		NStr("en = 'The schedule or business calendar is not specified.';"), 
		"CalendarSchedules.NearestWorkDates");
	
	QueriesTexts = New Array;
	For Each InitialDate In InitialDates Do
		If Not ValueIsFilled(InitialDate) Then
			Continue;
		EndIf;
		QueryText = 
			"SELECT
			|	&InitialDate AS Date
			|INTO TTInitialDates";
		QueryText = StrReplace(
			QueryText, "&InitialDate", StrTemplate("DATETIME(%1)", Format(InitialDate, "DF=yyyy,MM,dd"))); // 
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "INTO TTInitialDates", "");
		EndIf;
		QueriesTexts.Add(QueryText);
	EndDo;

	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF);

	If IsBlankString(QueryText) Then
		Return New Map;
	EndIf;

	Query = New Query(QueryText);
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	QueryText = 
		"SELECT
		|	InitialDates.Date,
		|	MIN(CalendarDates.Date) AS NearestDate
		|FROM
		|	TTInitialDates AS InitialDates
		|		LEFT JOIN InformationRegister.BusinessCalendarData AS CalendarDates
		|		ON CalendarDates.Date >= InitialDates.Date
		|		AND CalendarDates.BusinessCalendar = &BusinessCalendar
		|		AND CalendarDates.DayKind IN (VALUE(Enum.BusinessCalendarDaysKinds.Work),
		|			VALUE(Enum.BusinessCalendarDaysKinds.Preholiday))
		|		AND CalendarDates.Date NOT IN (&NonWorkDates)
		|GROUP BY
		|	InitialDates.Date";
	
	If ReceivingParameters.GetPrevious Then
		QueryText = StrReplace(QueryText, "MIN(CalendarDates.Date)", "MAX(CalendarDates.Date)");
		QueryText = StrReplace(QueryText, "CalendarDates.Date >= InitialDates.Date", "CalendarDates.Date <= InitialDates.Date");
	EndIf;
	Query.Text = QueryText;
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	
	NonWorkDates = New Array;
	If ReceivingParameters.ConsiderNonWorkPeriods Then
		NonWorkDates = NonWorkDatesByNonWorkPeriod(ReceivingParameters.NonWorkPeriods, BusinessCalendar);
	EndIf;
	Query.SetParameter("NonWorkDates", NonWorkDates);
	
	Selection = Query.Execute().Select();
	
	WorkdaysDates = New Map;
	While Selection.Next() Do
		If ValueIsFilled(Selection.NearestDate) Then
			WorkdaysDates.Insert(Selection.Date, Selection.NearestDate);
		Else 
			If ReceivingParameters.RaiseException1 Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot determine the workday nearest to %1. 
						 |The work schedule might be blank.';"), 
					Format(Selection.Date, "DLF=D"));
			EndIf;
		EndIf;
	EndDo;
	
	Return WorkdaysDates;
	
EndFunction

// Generates work schedules for dates included in the specified schedules for the specified period.
// If the schedule for a pre-holiday day is not set, it is defined as if this day is a workday.
// Note that this function requires the WorkSchedules subsystem.
//
// Parameters:
//  Schedules       - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//  StartDate    - Date   - a start date of the period, for which schedules are to be created.
//  EndDate - Date   - a period end date.
//
// Returns:
//   ValueTable:
//    * WorkScheduleCalendar    - CatalogRef.Calendars - a work schedule.
//    * ScheduleDate     - Date - a date in the WorkScheduleCalendar work schedule.
//    * BeginTime     - Date - work start time on the ScheduleDate day.
//    * EndTime  - Date - work end time on the ScheduleDate day.
//
Function WorkSchedulesForPeriod(Schedules, StartDate, EndDate) Export
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		Return ModuleWorkSchedules.WorkSchedulesForPeriod(Schedules, StartDate, EndDate);
	EndIf;
	
	Raise NStr("en = 'The ""Work schedules"" subsystem is not found.';");
	
EndFunction

// Creates temporary table TTWorkSchedules in the manager. The table contains columns matching the return
// value of the WorkSchedulesForPeriod function.
// Note that this function requires the WorkSchedules subsystem.
//
// Parameters:
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  Schedules       - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//  StartDate    - Date   - a start date of the period, for which schedules are to be created.
//  EndDate - Date   - a period end date.
//
Procedure CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate);
		Return;
	EndIf;
	
	Raise NStr("en = 'The ""Work schedules"" subsystem is not found.';");
	
EndProcedure

// Fills in an attribute in the form if only one business calendar is used.
//
// Parameters:
//  Form         - ClientApplicationForm - a form, in which the attribute is to be filled in.
//  AttributePath2 - String           - a path to the data, for example: "Object.BusinessCalendar".
//  CRTR			  - String           - a taxpayer ID (tax registration reason code) used to determine a state.
//
Procedure FillBusinessCalendarInForm(Form, AttributePath2, CRTR = Undefined) Export
	
	Calendar = Undefined;
	
	If Not GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Calendar = SingleBusinessCalendar();
	Else
		Calendar = StateBusinessCalendar(CRTR);
	EndIf;
	
	If Calendar <> Undefined Then
		CommonClientServer.SetFormAttributeByPath(Form, AttributePath2, Calendar);
	EndIf;
	
EndProcedure

// Returns a main business calendar used in accounting.
//
// Returns:
//   CatalogRef.BusinessCalendars, Undefined -  
//                                                              
//
Function MainBusinessCalendar() Export
		
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return Undefined;
	EndIf;	
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleFillingInCalendarSchedules.MainBusinessCalendar();
	
EndFunction

// Prepares details of special non-work periods, for example, set according to certain laws.
// These periods can be considered by schedules and override filling by business calendar data.
// 
// Parameters:
//   BusinessCalendar - CatalogRef.BusinessCalendars - the calendar that is a source.
//   PeriodFilter - StandardPeriod - a time interval within which you need to define non-work periods.
// Returns:
//   Array - 
//    * Number     - Number - a sequence number of a period, which can be used for identification.
//    * Period    - StandardPeriod - a non-work period.
//    * Basis - String - a regulation a non-work period is based on.
//    * Dates - Array of Date - dates included in a non-work period.
//    * Presentation  - String - a user presentation of the period.
//
Function NonWorkDaysPeriods(BusinessCalendar, PeriodFilter) Export

	TimeIntervals = New Array;
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return TimeIntervals;
	EndIf;
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	TimeIntervals = ModuleFillingInCalendarSchedules.NonWorkDaysPeriods(BusinessCalendar, PeriodFilter);
	
	DeletePeriodsThatDoNotMatchFilter(TimeIntervals, PeriodFilter);
	
	Return TimeIntervals;

EndFunction

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.ClassifiersOperations 

// The event occurs upon collecting information on classifiers. Registering business calendars.
// 
// Parameters:
//   Classifiers - See ClassifiersOperationsOverridable.OnAddClassifiers.Classifiers
//
Procedure OnAddClassifiers(Classifiers) Export
	
	LongDesc = Undefined;
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		LongDesc = ModuleClassifiersOperations.ClassifierDetails();
	EndIf;
	If LongDesc = Undefined Then
		Return;
	EndIf;
	
	LongDesc.Id = ClassifierID();
	LongDesc.Description = NStr("en = 'Calendars';");
	LongDesc.AutoUpdate = True;
	LongDesc.SharedData = True;
	LongDesc.SharedDataProcessing = True;
	LongDesc.SaveFileToCache = True;
	
	Classifiers.Add(LongDesc);
	
EndProcedure

// See ClassifiersOperationsOverridable.OnImportClassifier.
Procedure OnImportClassifier(Id, Version, Address, Processed, AdditionalParameters) Export
	
	If Id <> ClassifierID() Then
		Return;
	EndIf;
	
	LoadBusinessCalendarsData(Version, Address, Processed, AdditionalParameters);
	
EndProcedure

// End OnlineUserSupport.ClassifiersOperations

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated. Outdated. Use: 
// - — CalendarSchedules.NearestWorkDates — for a business calendar, 
// - — or WorkSchedules.NearestDatesIncludedInSchedule — for a work schedule.
// Defines the nearest workday for each date.
//
// Parameters:
//    Schedule	- CatalogRef.Calendars
//	        	- CatalogRef.BusinessCalendars -  
//                    
//    InitialDates 				- Array - an array of dates (Date).
//    GetPrevious		- Boolean - a method of getting the closest date:
//										if True, workdays preceding the ones passed in the InitialDates parameter are defined, 
//										if False, dates not earlier than the initial date are defined.
//    RaiseException1 - Boolean - if True, throw an exception if the schedule is not filled in.
//    IgnoreUnfilledSchedule - Boolean - if True, a map returns in any way. 
//										Initial dates whose values are missing because of unfilled schedule will not be included.
//
// Returns:
//    - Map of KeyAndValue:
//      * Key - Date - a date from the passed array
//      * Value - Date - the working date closest to it (if a working date is passed, it returns).
//							If the selected schedule is not filled in and RaiseException = False, Undefined returns
//    - Undefined
//
Function ClosestWorkdaysDates(Schedule, InitialDates, GetPrevious = False, RaiseException1 = True, 
	IgnoreUnfilledSchedule = False) Export
	
	If TypeOf(Schedule) <> Type("CatalogRef.BusinessCalendars") Then
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			ReceivingParameters = ModuleWorkSchedules.NearestDatesByScheduleReceivingParameters();
			ReceivingParameters.GetPrevious = GetPrevious;
			ReceivingParameters.RaiseException1 = RaiseException1;
			ReceivingParameters.IgnoreUnfilledSchedule = IgnoreUnfilledSchedule;
			Return ModuleWorkSchedules.NearestDatesIncludedInSchedule(Schedule, InitialDates, ReceivingParameters);
		EndIf;
	EndIf;
	
	ReceivingParameters = NearestWorkDatesReceivingParameters();
	ReceivingParameters.GetPrevious = GetPrevious;
	ReceivingParameters.RaiseException1 = RaiseException1;
	Return NearestWorkDates(Schedule, InitialDates, ReceivingParameters);
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

//  
// 
// 
// 
// Parameters:
//  DaysArray - Array of Number -
//  CalculateNextDateFromPrevious - Boolean -
// 
// Returns:
//  Structure:
//   * DaysIncrement - ValueTable
//   * Maximum - Number
//
Function DaysIncrement(DaysArray, Val CalculateNextDateFromPrevious = False) Export

	Result = New Structure();
	Result.Insert("DaysIncrement", New ValueTable);
	Result.Insert("Maximum", 0);

	Result.DaysIncrement.Columns.Add("RowIndex", New TypeDescription("Number"));
	Result.DaysIncrement.Columns.Add("DaysCount", New TypeDescription("Number"));
	
	DaysCount = 0;
	LineNumber = 0;
	For Each DaysRow In DaysArray Do
		DaysCount = DaysCount + DaysRow;
		String = Result.DaysIncrement.Add();
		String.RowIndex = LineNumber;
		String.DaysCount = ?(CalculateNextDateFromPrevious, DaysCount, DaysRow);
		Result.Maximum = Max(Result.Maximum, String.DaysCount);
		LineNumber = LineNumber + 1;
	EndDo;
	
	Return Result;

EndFunction

// Updates items related to a business calendar, 
// for example, Work schedules.
//
// Parameters:
//  ChangesTable - ValueTable:
//    * BusinessCalendarCode - Number - a code of business calendar whose data is changed.
//    * Year - Number - a year, for which data is to be updated.
//
Procedure DistributeBusinessCalendarsDataChanges(ChangesTable) Export
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangesTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;
	
	FillDataDependentOnBusinessCalendars(ChangesTable);
	
EndProcedure

// Updates items related to a business calendar, 
// for example, Work schedules, in data areas.
//
// Parameters:
//  ChangesTable - ValueTable:
//    * BusinessCalendarCode - Number - a code of business calendar whose data is changed.
//    * Year - Number - a year, for which data is to be updated.
//
Procedure FillDataDependentOnBusinessCalendars(ChangesTable) Export
	
	If ChangesTable.Count() = 0 Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.UpdateWorkSchedulesAccordingToBusinessCalendars(ChangesTable);
	EndIf;
	
	CalendarSchedulesOverridable.OnUpdateDataDependentOnBusinessCalendars(ChangesTable);
	
EndProcedure

// Returns the internal classifier ID for the ClassifiersOperations subsystem.
//
// Returns:
//  String - 
//
Function ClassifierID() Export
	Return "Calendars20";
EndFunction

// Defines a version of data related to calendars built in the configuration.
//
// Returns:
//   Number - version number.
//
Function CalendarsVersion() Export
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return 0;
	EndIf;
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleFillingInCalendarSchedules.CalendarsVersion();
	
EndFunction

// Returns the version of classifier data imported to the infobase.
//
// Returns:
//   Number - 
//
Function LoadedCalendarsVersion() Export
	
	LoadedCalendarsVersion = Undefined;
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		LoadedCalendarsVersion = ModuleClassifiersOperations.ClassifierVersion(ClassifierID());
	EndIf;
	
	If LoadedCalendarsVersion = Undefined Then
		LoadedCalendarsVersion = 0;
	EndIf;
	
	Return LoadedCalendarsVersion;
	
EndFunction

// Requests a file with calendar classifier data. 
// Converts the retrieved file into a structure with calendar tables and their data.
// If the ClassifiersOperations subsystem is unavailable, or the classifier file cannot be retrieved, throws an exception.
//
// Returns:
//  Structure:
//   * BusinessCalendars - Structure:
//     * TableName - String          - a table name.
//     * Data     - ValueTable - a calendar table converted from XML.
//   * BusinessCalendarsData - Structure:
//     * TableName - String          - a table name.
//     * Data     - ValueTable - a calendar table converted from XML.
//
Function ClassifierData() Export
	
	FilesData = Undefined;
	
	IDs = CommonClientServer.ValueInArray(ClassifierID());
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		FilesData = ModuleClassifiersOperations.GetClassifierFiles(IDs);
	EndIf;
	
	If FilesData = Undefined Then
		MessageText = NStr("en = 'Cannot get calendar data.
                               |Classifiers are not supported, or the Classifiers subsystem is missing.';");
		Raise MessageText;
	EndIf;
	
	If Not IsBlankString(FilesData.ErrorCode) Then
		EventName = NStr("en = 'Calendar schedules.Get classifier file';", Common.DefaultLanguageCode());
		WriteLogEvent(
			EventName, 
			EventLogLevel.Error,,, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot get calendar data.
                      |%1';"), 
				FilesData.ErrorInfo));
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot get calendar data.
                               |%1.';"), 
			FilesData.ErrorMessage);
		Raise MessageText;
	EndIf;
	
	RowFilter = New Structure("Id");
	RowFilter.Id = ClassifierID();
	FoundRows = FilesData.ClassifiersData.FindRows(RowFilter);
	If FoundRows.Count() = 0 Then
		MessageText = NStr("en = 'Cannot get calendar data.
                               |The retrieved classifiers do not contain calendars.';");
		Raise MessageText;
	EndIf;
	
	FileInfo2 = FoundRows[0];
	
	If FileInfo2.Version < CalendarsVersion() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process retrieved calendar data due to version conflict.
                  |Calendar versions:
                  |- In the retrieved classifier: %1.
                  |- In the configuration: %2.
                  |- In the previously imported classifier: %3.';"),
			FileInfo2.Version,
			CalendarsVersion(),
			LoadedCalendarsVersion());
		Raise MessageText;
	EndIf;
	
	Try
		ClassifierData = ClassifierFileData(FileInfo2.FileAddress);
	Except
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process retrieved calendar data.
                  |%1.';"),
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Raise MessageText;
	EndTry;
	
	Return ClassifierData;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.66";
	Handler.Procedure = "CalendarSchedules.UpdateDependentBusinessCalendarsData";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.102";
	Handler.Procedure = "CalendarSchedules.UpdateMultipleBusinessCalendarsUsage";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.3.113";
	Handler.Procedure = "CalendarSchedules.ResetClassifierVersion";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.5.80";
	Handler.Procedure = "CalendarSchedules.FixTheDataOfDependentCalendars";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = BusinessCalendarsUpdateVersion();
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = BusinessCalendarsDataUpdateVersion();
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendarsData";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	AddHandlerOfDataDependentOnBusinessCalendars(Handlers);
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ТолькоДляПользователейСистемы.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.AddEditCalendarSchedules.Name);
	
EndProcedure

// Parameters:
//   Types - See ExportImportDataOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport.Types
//
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.BusinessCalendars);
	
EndProcedure

// See SaaSOperationsOverridable.OnEnableSeparationByDataAreas.
Procedure OnEnableSeparationByDataAreas() Export
	
	CalendarsTable = Catalogs.BusinessCalendars.DefaultBusinessCalendars();
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarsTable);
	UpdateMultipleBusinessCalendarsUsage();
	
	BusinessCalendarsData = Catalogs.BusinessCalendars.DefaultBusinessCalendarsData();
	NonWorkDaysPeriods = Catalogs.BusinessCalendars.DefaultNonWorkDaysPeriods();
	FillBusinessCalendarsDataOnUpdate(BusinessCalendarsData, NonWorkDaysPeriods);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update handlers used in other subsystems.

// Updates data dependent on business calendars.
//
Procedure UpdateDataDependentOnBusinessCalendars(ParametersOfUpdate) Export
	
	If Not ParametersOfUpdate.Property("ChangesTable") Then
		ParametersOfUpdate.ProcessingCompleted = True;
		Return;
	EndIf;
	
	ChangesTable = ParametersOfUpdate.ChangesTable; // ValueTable
	ChangesTable.GroupBy("BusinessCalendarCode, Year");
	
	FillDataDependentOnBusinessCalendars(ChangesTable);
	
	ParametersOfUpdate.ProcessingCompleted = True;
	
EndProcedure

Function ThereAreChangeableObjectsDependentOnProductionCalendars() Export
	
	ObjectsToChange = New Array;
	FillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange);
	Return ObjectsToChange.Count() > 0;
	
EndFunction

#EndRegion

#Region Private

// Gets a single business calendar in the infobase.
//
Function SingleBusinessCalendar()
	
	UsedCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	
	If UsedCalendars.Count() = 1 Then
		Return UsedCalendars[0];
	EndIf;
	
EndFunction

// Defines a regional business calendar by KPP.
//
Function StateBusinessCalendar(CRTR)
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return Undefined;
	EndIf;	
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleFillingInCalendarSchedules.StateBusinessCalendar(CRTR);
	
EndFunction

Procedure LoadBusinessCalendarsData(Version, Address, Processed, AdditionalParameters)
	
	ClassifierData = ClassifierFileData(Address);
	
	// Update the list of business calendars.
	CalendarsTable = ClassifierData["BusinessCalendars"].Data;
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarsTable);
	
	// Update business calendar data.
	XMLData1 = ClassifierData["BusinessCalendarsData"];
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromXML(XMLData1, CalendarsTable);
	ChangesTable = Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);
	
	XMLPeriods = ClassifierData["NonWorkDaysPeriods"];
	PeriodsTable = Catalogs.BusinessCalendars.NonWorkDaysPeriodsFromXML(XMLPeriods, CalendarsTable);
	CommonClientServer.SupplementTable(
		Catalogs.BusinessCalendars.UpdateNonWorkDaysPeriods(PeriodsTable), ChangesTable);
	
	ChangesTable.GroupBy("BusinessCalendarCode, Year");
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangesTable);
	
	If Not Common.DataSeparationEnabled() Then
		FillDataDependentOnBusinessCalendars(ChangesTable);
	Else
		// Include changes table in additional parameters to update data areas.
		ParametersOfUpdate = New Structure("ChangesTable");
		ParametersOfUpdate.ChangesTable = ChangesTable;
		AdditionalParameters.Insert(ClassifierID(), ParametersOfUpdate);
	EndIf;
	
	Processed = True;
	
EndProcedure

Function ClassifierFileData(Address)
	
	ClassifierData = New Structure(
		"BusinessCalendars,
		|BusinessCalendarsData,
		|NonWorkDaysPeriods");
	
	PathToFile = GetTempFileName();
	BinaryData = GetFromTempStorage(Address); // BinaryData
	BinaryData.Write(PathToFile);
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	XMLReader.MoveToContent();
	CheckItemStart(XMLReader, "CalendarSuppliedData");
	XMLReader.Read();
	CheckItemStart(XMLReader, "Calendars");
	
	ClassifierData.BusinessCalendars = Common.ReadXMLToTable(XMLReader);
	
	XMLReader.Read();
	CheckItemEnd(XMLReader, "Calendars");
	XMLReader.Read();
	CheckItemStart(XMLReader, "CalendarData");
	
	ClassifierData.BusinessCalendarsData = Common.ReadXMLToTable(XMLReader);
	
	XMLReader.Read();
	CheckItemEnd(XMLReader, "CalendarData");
	XMLReader.Read();
	CheckItemStart(XMLReader, "NonWorkingPeriods");

	ClassifierData.NonWorkDaysPeriods = Common.ReadXMLToTable(XMLReader);
	
	XMLReader.Close();
	DeleteFiles(PathToFile);
	
	Return ClassifierData;
	
EndFunction

Procedure CheckItemStart(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Or XMLReader.Name <> Name Then
		EventName = NStr("en = 'Calendar schedules.Process classifier file';", Common.DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid data file format. Start of ""%1"" element is expected.';"), 
			Name);
		WriteLogEvent(EventName, EventLogLevel.Error, , , MessageText);
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure CheckItemEnd(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.EndElement Or XMLReader.Name <> Name Then
		EventName = NStr("en = 'Calendar schedules.Process classifier file';", Common.DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid data file format. End of the ""%1"" element is expected.';"), 
			Name);
		WriteLogEvent(EventName, EventLogLevel.Error, , , MessageText);
		Raise MessageText;
	EndIf;
	
EndProcedure

Function BusinessCalendarsUpdateVersion()
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return "1.0.0.1";
	EndIf;	
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleFillingInCalendarSchedules.BusinessCalendarsUpdateVersion();
	
EndFunction

Function BusinessCalendarsDataUpdateVersion()
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return "1.0.0.1";
	EndIf;
	
	ModuleFillingInCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleFillingInCalendarSchedules.BusinessCalendarsDataUpdateVersion();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Updates the Business calendars catalog from the template with the same name.
//
Procedure UpdateBusinessCalendars() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	BuiltInCalendarsVersion = CalendarsVersion();
	If BuiltInCalendarsVersion <= LoadedCalendarsVersion() Then
		Return;
	EndIf;
	
	CalendarsTable = Catalogs.BusinessCalendars.BusinessCalendarsFromTemplate();
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarsTable);
	UpdateMultipleBusinessCalendarsUsage();
	
	BusinessCalendarsData = Catalogs.BusinessCalendars.BusinessCalendarsDataFromTemplate();
	NonWorkDaysPeriods = Catalogs.BusinessCalendars.NonWorkDaysPeriodsFromTemplate();
	FillBusinessCalendarsDataOnUpdate(BusinessCalendarsData, NonWorkDaysPeriods);
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		ModuleClassifiersOperations.SetClassifierVersion(ClassifierID(), BuiltInCalendarsVersion);
	EndIf;
	
EndProcedure

// Updates business calendar data from a template.
//  BusinessCalendarsData.
//
Procedure UpdateBusinessCalendarsData() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	BuiltInCalendarsVersion = CalendarsVersion();
	If BuiltInCalendarsVersion <= LoadedCalendarsVersion() Then
		Return;
	EndIf;
	
	BusinessCalendarsData = Catalogs.BusinessCalendars.BusinessCalendarsDataFromTemplate();
	NonWorkDaysPeriods = Catalogs.BusinessCalendars.NonWorkDaysPeriodsFromTemplate();
	FillBusinessCalendarsDataOnUpdate(BusinessCalendarsData, NonWorkDaysPeriods);
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		ModuleClassifiersOperations.SetClassifierVersion(ClassifierID(), BuiltInCalendarsVersion);
	EndIf;
	
EndProcedure

// Updates data of business calendars dependent on the basic ones.
//
Procedure UpdateDependentBusinessCalendarsData() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Year", 2018);
	Query.Text = 
		"SELECT
		|	DependentCalendars.Ref AS Calendar,
		|	DependentCalendars.BasicCalendar AS BasicCalendar
		|INTO TTDependentCalendars
		|FROM
		|	Catalog.BusinessCalendars AS DependentCalendars
		|WHERE
		|	DependentCalendars.BasicCalendar <> VALUE(Catalog.BusinessCalendars.EmptyRef)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	CalendarsData.BusinessCalendar AS BusinessCalendar,
		|	CalendarsData.Year AS Year
		|INTO TTCalendarYears
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarsData
		|WHERE
		|	CalendarsData.Year >= &Year
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	DependentCalendars.BasicCalendar AS BasicCalendar,
		|	DependentCalendars.BasicCalendar.Code AS BusinessCalendarCode,
		|	BasicCalendarData.Year AS Year
		|FROM
		|	TTDependentCalendars AS DependentCalendars
		|		INNER JOIN TTCalendarYears AS BasicCalendarData
		|		ON (BasicCalendarData.BusinessCalendar = DependentCalendars.BasicCalendar)
		|		LEFT JOIN TTCalendarYears AS DependentCalendarData
		|		ON (DependentCalendarData.BusinessCalendar = DependentCalendars.Calendar)
		|			AND (DependentCalendarData.Year = BasicCalendarData.Year)
		|WHERE
		|	DependentCalendarData.Year IS NULL";
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	ChangesTable = QueryResult.Unload();
	Catalogs.BusinessCalendars.UpdateDependentBusinessCalendarsData(ChangesTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;
	
	HandlerParameters = InfobaseUpdateInternal.DeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars");
	If HandlerParameters <> Undefined And HandlerParameters.Property("ChangesTable") Then
		CommonClientServer.SupplementTable(ChangesTable, HandlerParameters.ChangesTable);
	EndIf;
	
	HandlerParameters = New Structure("ChangesTable");
	HandlerParameters.ChangesTable = ChangesTable;
	InfobaseUpdateInternal.WriteDeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars", HandlerParameters);
	
EndProcedure

Procedure FillBusinessCalendarDependentDataUpdateData(ParametersOfUpdate) Export
	
EndProcedure

Procedure FillObjectsToBlockDependentOnBusinessCalendars(Handler)
	
	ObjectsToLock = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.FillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock);
	EndIf;
	
	CalendarSchedulesOverridable.OnFillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock);
	
	Handler.ObjectsToLock = StrConcat(ObjectsToLock, ",");
	
EndProcedure

Procedure FillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange)
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.FillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange);
	EndIf;
	
	CalendarSchedulesOverridable.OnFillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange);
	
EndProcedure

// The procedure updates data dependent on business calendars 
// for all data areas.
//
Procedure PlanUpdateOfDataDependentOnBusinessCalendars(Val UpdateConditions)
	
	CalendarSchedulesInternal.PlanUpdateOfDataDependentOnBusinessCalendars(UpdateConditions);
	
EndProcedure

Procedure FillBusinessCalendarsDataOnUpdate(DataTable, PeriodsTable)
	
	ChangesTable = Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);

	CommonClientServer.SupplementTable(
		Catalogs.BusinessCalendars.UpdateNonWorkDaysPeriods(PeriodsTable), ChangesTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;

	HandlerParameters = InfobaseUpdateInternal.DeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars");
	If HandlerParameters <> Undefined And HandlerParameters.Property("ChangesTable") Then
		CommonClientServer.SupplementTable(ChangesTable, HandlerParameters.ChangesTable);
	EndIf;
	
	HandlerParameters = New Structure("ChangesTable");
	HandlerParameters.ChangesTable = ChangesTable;
	InfobaseUpdateInternal.WriteDeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars", HandlerParameters);
	
EndProcedure

// Sets a value of the constant defining usage of multiple business calendars.
//
Procedure UpdateMultipleBusinessCalendarsUsage() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	UseMultipleCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList().Count() <> 1;
	If UseMultipleCalendars <> GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Constants.UseMultipleBusinessCalendars.Set(UseMultipleCalendars);
	EndIf;
	
EndProcedure

Procedure AddHandlerOfDataDependentOnBusinessCalendars(Handlers)
	
	If Common.DataSeparationEnabled() Then
		// 
		Return;
	EndIf;
	
	ObjectsToChange = New Array;
	FillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange);
	If ObjectsToChange.Count() = 0 Then
		// 
		Return;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = BusinessCalendarsDataUpdateVersion();
	Handler.Procedure = "CalendarSchedules.UpdateDataDependentOnBusinessCalendars";
	Handler.UpdateDataFillingProcedure = "CalendarSchedules.FillBusinessCalendarDependentDataUpdateData";
	Handler.ExecutionMode = "Deferred";
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.ObjectsToRead = "InformationRegister.BusinessCalendarData";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Id = New UUID("b1082291-b482-418f-82ab-3c96e93072cc");
	Handler.Comment = NStr("en = 'Updates work schedules and other data that depends on business calendars.';");
	Handler.ObjectsToChange = StrConcat(ObjectsToChange, ",");
	FillObjectsToBlockDependentOnBusinessCalendars(Handler);
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = ModuleWorkSchedules.WorkSchedulesUpdateProcedureName();
		Priority.Order = "Before";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = ModuleWorkSchedules.ConsiderNonWorkDaysFlagSettingProcedureName();
		Priority.Order = "After";
	EndIf;
	
EndProcedure

Procedure DeletePeriodsThatDoNotMatchFilter(TimeIntervals, PeriodFilter)
	
	IndexOf = 0;
	While IndexOf < TimeIntervals.Count() Do
		PeriodDetails = TimeIntervals[IndexOf];
		If PeriodFilter.StartDate > PeriodDetails.Period.EndDate 
			Or (ValueIsFilled(PeriodFilter.EndDate) And PeriodFilter.EndDate < PeriodDetails.Period.StartDate) Then
			TimeIntervals.Delete(IndexOf);
		Else
			IndexOf = IndexOf + 1;
		EndIf; 
	EndDo;
	
EndProcedure

Function NonWorkDatesByNonWorkPeriod(NonWorkPeriods, BusinessCalendar)

	NonWorkDates = New Array;

	If TypeOf(NonWorkPeriods) = Type("Array") Then
		If NonWorkPeriods.Count() = 0 Then
			Return NonWorkDates;
		EndIf;
		If TypeOf(NonWorkPeriods[0]) = Type("Number") Then
			PeriodsDetails = NonWorkDaysPeriods(BusinessCalendar, New StandardPeriod());
			IndexOf = 0;
			While IndexOf < PeriodsDetails.Count() Do
				If NonWorkPeriods.Find(PeriodsDetails[IndexOf].Number) = Undefined Then
					PeriodsDetails.Delete(IndexOf);
				Else
					IndexOf = IndexOf + 1;
				EndIf; 
			EndDo;
		ElsIf TypeOf(NonWorkPeriods[0]) = Type("Structure") Then
			PeriodsDetails = NonWorkPeriods;
		Else
			CommonClientServer.Validate(False,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid item value type in the %1 parameter:
					           |%2';"), "NonWorkPeriods", TypeOf(NonWorkPeriods[0])),
				"CalendarSchedules.NearestWorkDates");
		EndIf;
	EndIf;

	If NonWorkPeriods = Undefined Then
		PeriodsDetails = NonWorkDaysPeriods(BusinessCalendar, New StandardPeriod());
	EndIf;
	
	For Each Period In PeriodsDetails Do
		CommonClientServer.SupplementArray(NonWorkDates, Period.Dates);
	EndDo;
	
	Return NonWorkDates;
	
EndFunction

Procedure ResetClassifierVersion() Export
	
	If LoadedCalendarsVersion() = 0 Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		ModuleClassifiersOperations.SetClassifierVersion(ClassifierID(), 1);
	EndIf;
	
EndProcedure

Procedure FixTheDataOfDependentCalendars() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	Query = New Query();
	Query.SetParameter("DependentCalendarsUpdateStartYear", 2018);
	Query.Text = 
		"SELECT DISTINCT
		|	DependentCalendars.Ref.Code AS CalendarCode1
		|FROM
		|	InformationRegister.BusinessCalendarData AS BaseCalendarData
		|		INNER JOIN Catalog.BusinessCalendars AS DependentCalendars
		|		ON (DependentCalendars.BasicCalendar = BaseCalendarData.BusinessCalendar)
		|			AND (BaseCalendarData.BusinessCalendar.BasicCalendar = VALUE(Catalog.BusinessCalendars.EmptyRef))
		|			AND (BaseCalendarData.Year >= &DependentCalendarsUpdateStartYear)
		|			AND (NOT TRUE IN
		|					(SELECT TOP 1
		|						TRUE
		|					FROM
		|						InformationRegister.BusinessCalendarData AS Data
		|					WHERE
		|						Data.BusinessCalendar = DependentCalendars.Ref
		|						AND Data.Year = BaseCalendarData.Year))";

	CalendarsCodes = Query.Execute().Unload().UnloadColumn("CalendarCode1");
	If CalendarsCodes.Count() = 0 Then
		Return;
	EndIf;

	BusinessCalendarsData = Catalogs.BusinessCalendars.DefaultBusinessCalendarsData(CalendarsCodes);
	NonWorkDaysPeriods = Catalogs.BusinessCalendars.DefaultNonWorkDaysPeriods();
	FillBusinessCalendarsDataOnUpdate(BusinessCalendarsData, NonWorkDaysPeriods);

EndProcedure

#EndRegion
