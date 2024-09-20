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

	SetConditionalAppearance();
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	TwelveHourTimeFormat = WorkSchedules.TwelveHourTimeFormat();
	
	InfobaseUpdate.CheckObjectProcessed("Catalog.Calendars", ThisObject);
	
	// If there is only one business calendar in the application, fill it in by default.
	BusinessCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	If BusinessCalendars.Count() = 1 Then
		Object.BusinessCalendar = BusinessCalendars[0];
	EndIf;
	
	PeriodLength = 7;
	
	Object.StartDate = BegOfYear(CurrentSessionDate());
	Object.StartingDate = BegOfYear(CurrentSessionDate());
	
	FillWithCurrentYearData(Parameters.CopyingValue);
	
	OnGetDataAtServer();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	TwelveHourTimeFormat = WorkSchedules.TwelveHourTimeFormat();
	
	PeriodLength = Object.FillingTemplate.Count();
	FillWithCurrentYearData();
	
	OnGetDataAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	//  
	// 
	
	If ResultModified Then
		InformationRegisters.CalendarSchedules.WriteScheduleDataToRegister(CurrentObject.Ref, ScheduleDays, 
			Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	EndIf;
	SaveManualEditingFlag(CurrentObject, YearNumber);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	PeriodLength = Object.FillingTemplate.Count();
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	FillSchedulePresentation(ThisObject);
	
	SpecifyFillDate();
	
	SetRemoveTemplateModified(ThisObject, False);
	
	FillWithCurrentYearData();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.FillingMethod = Enums.WorkScheduleFillingMethods.ByArbitraryLengthPeriods Then
		CheckedAttributes.Add("PeriodLength");
		CheckedAttributes.Add("StartingDate");
	EndIf;
	
	If Object.FillingTemplate.FindRows(New Structure("DayAddedToSchedule", True)).Count() = 0 Then
		Common.MessageToUser(
			NStr("en = 'Please select the days to include in the work schedule.';"), , "Object.FillingTemplate", , Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BusinessCalendarOnChange(Item)
	
	SetEnabledConsiderHolidays(ThisObject);
	SetAvailabilityConsiderNonWorkPeriods(ThisObject);
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure FillingMethodOnChange(Item)

	ConfigureFillingSettingItems(ThisObject);
	
	ClarifyStartingDate();	
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	FillSchedulePresentation(ThisObject);

	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	If Object.StartDate < Date(1900, 1, 1) Then
		Object.StartDate = BegOfYear(CommonClient.SessionDate());
	EndIf;
	
	SetAvailabilityConsiderNonWorkPeriods(ThisObject);
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	SetAvailabilityConsiderNonWorkPeriods(ThisObject);
EndProcedure

&AtClient
Procedure StartingDateOnChange(Item)
	
	ClarifyStartingDate();
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PeriodLengthOnChange(Item)
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.StartingDate);
	FillSchedulePresentation(ThisObject);

	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure ConsiderHolidaysOnChange(Item)
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
	SetEnabledPreholidaySchedule(ThisObject);

EndProcedure

&AtClient
Procedure ConsiderNonWorkPeriodsOnChange(Item)

	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);

EndProcedure

&AtClient
Procedure PreholidayScheduleClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	StartFillDaySchedule(0);
	
EndProcedure

&AtClient
Procedure PlanningHorizonOnChange(Item)
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.LongDesc");
	
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	If CurrentYearNumber < Year(Object.StartDate)
		Or (ValueIsFilled(Object.EndDate) And CurrentYearNumber > Year(Object.EndDate)) Then
		CurrentYearNumber = PreviousYearNumber;
		Return;
	EndIf;
	
	WriteScheduleData = False;
	
	If ResultModified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Do you want to save the changes for year %1?';"), Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeCompletion", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	
	SetRemoveResultModified(ThisObject, False);
	
	Items.WorkScheduleCalendar.Refresh();
	
EndProcedure

&AtClient
Procedure WorkHoursOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodAppearanceString In PeriodAppearance.Dates Do
		If ScheduleDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayTextColor = CommonClient.StyleColor("BusinessCalendarDayKindColorNotSpecified");
		Else
			DayTextColor = CommonClient.StyleColor("BusinessCalendarDayKindWorkdayColor");
		EndIf;
		PeriodAppearanceString.TextColor = DayTextColor;
		// Manual edit.
		If ChangedDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayBgColor = CommonClient.StyleColor("FieldBackColor");
		Else
			DayBgColor = CommonClient.StyleColor("ChangedScheduleDateBackground");
		EndIf;
		PeriodAppearanceString.BackColor = DayBgColor;
	EndDo;
	
EndProcedure

&AtClient
Procedure WorkHoursSelection(Item, SelectedDate)
	
	If ScheduleDays.Get(SelectedDate) = Undefined Then
		// 
		WorkSchedulesClient.InsertIntoFixedMap(ScheduleDays, SelectedDate, True);
		DayAddedToSchedule = True;
	Else
		// Исключаем of графика
		WorkSchedulesClient.DeleteFromFixedMap(ScheduleDays, SelectedDate);
		DayAddedToSchedule = False;
	EndIf;
	
	// 
	WorkSchedulesClient.InsertIntoFixedMap(ChangedDays, SelectedDate, DayAddedToSchedule);
	
	Items.WorkScheduleCalendar.Refresh();
	
	SetRemoveManualEditingFlag(ThisObject, True);
	SetRemoveResultModified(ThisObject, True);
	
EndProcedure

#EndRegion

#Region FillingTemplateFormTableItemEventHandlers

&AtClient
Procedure FillingTemplateSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TemplateRow = Object.FillingTemplate.FindByID(RowSelected);
	StartFillDaySchedule(TemplateRow.LineNumber, RowSelected);
	
EndProcedure

&AtClient
Procedure FillingTemplateDayAddedToScheduleOnChange(Item)
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FillFromTemplate(Command)
	
	FillByTemplateAtServer();
	
	Items.WorkScheduleCalendar.Refresh();
	
EndProcedure

&AtClient
Procedure FillingResult(Command)
	
	Items.Pages.CurrentPage = Items.FillingResultPage;
	
	If Not ResultFilledByTemplate Then
		FillByTemplateAtServer(True);
	EndIf;
	
	Items.WorkScheduleCalendar.Refresh();
	
EndProcedure

&AtClient
Procedure FillingSettings(Command)
	
	Items.Pages.CurrentPage = Items.FillingSettingsPage;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure OnGetDataAtServer(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(
		CurrentObject.FillingMethod, Object.FillingTemplate, PeriodLength, CurrentObject.StartingDate);
	
	SpecifyFillDate();
	
	FillSchedulePresentation(ThisObject);
	
	SetAvailabilityConsiderNonWorkPeriods(ThisObject);

	SetClearResultsMatchTemplateFlag(ThisObject, True);
	SetRemoveTemplateModified(ThisObject, False);

	SetEnabledConsiderHolidays(ThisObject);
	SetEnabledPreholidaySchedule(ThisObject);
	
	SetManualChangesSet();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateSchedulePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.SchedulePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.DayAddedToSchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", BlankSchedulePresentation());

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateLineNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingMethod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.WorkScheduleFillingMethods.ByWeeks;

	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IsFilledInformationText.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RequiresFilling");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingResultInformationText.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ResultFilledByTemplate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ManualEditing");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PreholidaySchedule.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PreholidaySchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ConsiderHolidays");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", BlankSchedulePresentation());

EndProcedure

&AtClientAtServerNoContext
Procedure ConfigureFillingSettingItems(Form)
	
	CanChangeSetting = Form.Object.FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods");
	
	Form.Items.PeriodLength.ReadOnly = Not CanChangeSetting;
	Form.Items.StartingDate.ReadOnly = Not CanChangeSetting;
	
	Form.Items.StartingDate.AutoMarkIncomplete = CanChangeSetting;
	Form.Items.StartingDate.MarkIncomplete = CanChangeSetting And Not ValueIsFilled(Form.Object.StartingDate);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateFillingTemplate(FillingMethod, FillingTemplate, Val PeriodLength, Val StartingDate = Undefined)
	
	// Generates the table for editing the template used for filling by days.
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		PeriodLength = 7;
	EndIf;
	
	While FillingTemplate.Count() > PeriodLength Do
		FillingTemplate.Delete(FillingTemplate.Count() - 1);
	EndDo;

	While FillingTemplate.Count() < PeriodLength Do
		FillingTemplate.Add();
	EndDo;
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		FillingTemplate[0].DayPresentation = NStr("en = 'Monday';");
		FillingTemplate[1].DayPresentation = NStr("en = 'Tuesday';");
		FillingTemplate[2].DayPresentation = NStr("en = 'Wednesday';");
		FillingTemplate[3].DayPresentation = NStr("en = 'Thursday';");
		FillingTemplate[4].DayPresentation = NStr("en = 'Friday';");
		FillingTemplate[5].DayPresentation = NStr("en = 'Saturday';");
		FillingTemplate[6].DayPresentation = NStr("en = 'Sunday';");
	Else
		DayDate = StartingDate;
		For Each DayRow In FillingTemplate Do
			DayRow.DayPresentation = Format(DayDate, "DF=d.MM");
			DayRow.SchedulePresentation = BlankSchedulePresentation();
			DayDate = DayDate + 86400;
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillSchedulePresentation(Form)
	
	For Each TemplateRow In Form.Object.FillingTemplate Do
		TemplateRow.SchedulePresentation = DaySchedulePresentation(Form, TemplateRow.LineNumber);
	EndDo;
	
	Form.PreholidaySchedule = DaySchedulePresentation(Form, 0);
	
EndProcedure

&AtClientAtServerNoContext
Function DaySchedulePresentation(Form, DayNumber)
	
	IntervalsPresentation = "";
	Seconds = 0;
	For Each ScheduleString In Form.Object.WorkSchedule Do
		If ScheduleString.DayNumber <> DayNumber Then
			Continue;
		EndIf;
		IntervalPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			"%1-%2, ", 
			DayPartPresentation(ScheduleString.BeginTime, Form.TwelveHourTimeFormat), 
			DayPartPresentation(ScheduleString.EndTime, Form.TwelveHourTimeFormat));
		IntervalsPresentation = IntervalsPresentation + IntervalPresentation;
		If Not ValueIsFilled(ScheduleString.EndTime) Then
			IntervalInSeconds = EndOfDay(ScheduleString.EndTime) - ScheduleString.BeginTime + 1;
		Else
			IntervalInSeconds = ScheduleString.EndTime - ScheduleString.BeginTime;
		EndIf;
		Seconds = Seconds + IntervalInSeconds;
	EndDo;
	StringFunctionsClientServer.DeleteLastCharInString(IntervalsPresentation, 2);
	
	If Seconds = 0 Then
		Return BlankSchedulePresentation();
	EndIf;
	
	Hours = Round(Seconds / 3600, 1);
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h (%2)';"), Hours, IntervalsPresentation);
	
EndFunction

&AtClientAtServerNoContext
Function DayPartPresentation(Val DayPart, TwelveHourTimeFormat)
	
	If Not ValueIsFilled(DayPart) Then
		DayPart = Date(1980, 1, 1);
	EndIf;
	
	TimeFormat = ?(TwelveHourTimeFormat,
		NStr("en = 'DF=''hh:mm tt''';"), NStr("en = 'DF=hh:mm; DE=';"));
		
	Return Format(DayPart, TimeFormat);
	
EndFunction

&AtClient
Function WorkSchedule(DayNumber)
	
	DaySchedule = New Array;
	
	For Each ScheduleString In Object.WorkSchedule Do
		If ScheduleString.DayNumber = DayNumber Then
			DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
		EndIf;
	EndDo;
	
	Return DaySchedule;
	
EndFunction

&AtClientAtServerNoContext
Function BlankSchedulePresentation()
	
	Return NStr("en = 'Fill in the schedule';");
	
EndFunction

&AtClientAtServerNoContext
Procedure SetEnabledConsiderHolidays(Form)
	
	Form.Items.ConsiderHolidays.Enabled = ValueIsFilled(Form.Object.BusinessCalendar);
	If Not Form.Items.ConsiderHolidays.Enabled Then
		Form.Object.ConsiderHolidays = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetAvailabilityConsiderNonWorkPeriods(Form)

	Items = Form.Items;
	Object = Form.Object;
	
	Items.ConsiderNonWorkPeriodsGroup.Visible = False;
	If Not ValueIsFilled(Object.BusinessCalendar) Then
		Return;
	EndIf;
	
	TimeIntervals = NonWorkDaysPeriods(Object.BusinessCalendar, Object.StartDate, Object.EndDate);
	If TimeIntervals.Count() = 0 Then
		Return;
	EndIf;
	
	Items.ConsiderNonWorkPeriodsGroup.Visible = True;
	
	Explanation = "";
	For Each PeriodDetails In TimeIntervals Do
		Explanation = Explanation + ?(Not IsBlankString(Explanation), Chars.LF, "") + PeriodDetails.Presentation;
	EndDo;
	Items.NonWorkPeriodsInformation.Title = Explanation;
	
EndProcedure

&AtServerNoContext
Function NonWorkDaysPeriods(BusinessCalendar, StartDate, EndDate)
	Return CalendarSchedules.NonWorkDaysPeriods(
		BusinessCalendar, New StandardPeriod(StartDate, EndDate));
EndFunction

&AtServer
Procedure SpecifyFillDate()
	
	QueryText = 
	"SELECT
	|	MAX(CalendarSchedules.ScheduleDate) AS Date
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkScheduleCalendar";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkScheduleCalendar", Object.Ref);
	Selection = Query.Execute().Select();
	
	FillDate = Undefined;
	If Selection.Next() Then
		FillDate = Selection.Date;
	EndIf;	
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AdjustScheduleFilled(Form)
	
	Form.RequiresFilling = False;
	
	If Form.Parameters.Key.IsEmpty() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Form.FillDate) Then
		Form.IsFilledInformationText = NStr("en = 'The work schedule is blank.';");
		Form.RequiresFilling = True;
	Else	
		If Not ValueIsFilled(Form.Object.PlanningHorizon) Then
			InformationText = NStr("en = 'The work schedule is filled in till %1.';");
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersToString(InformationText, Format(Form.FillDate, "DLF=D"));
		Else
			#If WebClient Or ThinClient Or MobileClient Then
				CurrentDate = CommonClient.SessionDate();
			#Else
				CurrentDate = CurrentSessionDate();
			#EndIf
			EndPlanningHorizon = AddMonth(CurrentDate, Form.Object.PlanningHorizon);
			InformationText = NStr("en = 'The work schedule is filled till %1. The provided scheduling interval requires that you fill it till %2.';");
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersToString(InformationText, Format(Form.FillDate, "DLF=D"), Format(EndPlanningHorizon, "DLF=D"));
			If EndPlanningHorizon > Form.FillDate Then
				Form.RequiresFilling = True;
			EndIf;
		EndIf;
	EndIf;
	Form.Items.IsFilledDecoration.Picture = ?(Form.RequiresFilling, PictureLib.Warning, PictureLib.Information);
	
EndProcedure

&AtServer
Procedure FillByTemplateAtServer(PreserveManualEditing = False)

	FillParameters = InformationRegisters.CalendarSchedules.ScheduleFillingParameters();
	FillParameters.FillingMethod = Object.FillingMethod;
	FillParameters.FillingTemplate = Object.FillingTemplate;
	FillParameters.BusinessCalendar = Object.BusinessCalendar;
	FillParameters.ConsiderHolidays = Object.ConsiderHolidays;
	FillParameters.ConsiderNonWorkPeriods = Object.ConsiderNonWorkPeriods;
	FillParameters.StartingDate = Object.StartingDate;
	
	DaysIncludedInSchedule = InformationRegisters.CalendarSchedules.DaysIncludedInSchedule(
		Object.StartDate, Object.EndDate, FillParameters);
	
	If ManualEditing Then
		If PreserveManualEditing Then
			// Apply manual adjustments.
			For Each KeyAndValue In ChangedDays Do
				ChangesDate = KeyAndValue.Key;
				DayAddedToSchedule = KeyAndValue.Value;
				If DayAddedToSchedule Then
					DaysIncludedInSchedule.Insert(ChangesDate, True);
				Else
					DaysIncludedInSchedule.Delete(ChangesDate);
				EndIf;
			EndDo;
		Else
			SetRemoveResultModified(ThisObject, True);
			SetRemoveManualEditingFlag(ThisObject, False);
		EndIf;
	EndIf;
	
	//  
	// 
	ScheduleDaysMap = New Map(ScheduleDays);
	DayDate = Object.StartDate;
	EndDate = Object.EndDate;
	If Not ValueIsFilled(EndDate) Then
		EndDate = EndOfYear(Object.StartDate);
	EndIf;
	While DayDate <= EndDate Do
		DayAddedToSchedule = DaysIncludedInSchedule[DayDate];
		If DayAddedToSchedule = Undefined Then
			ScheduleDaysMap.Delete(DayDate);
		Else
			ScheduleDaysMap.Insert(DayDate, DayAddedToSchedule);
		EndIf;
		DayDate = DayDate + 86400;
	EndDo;
	
	ScheduleDays = New FixedMap(ScheduleDaysMap);
	
	If Not ResultFilledByTemplate Then
		SetRemoveResultModified(ThisObject, True);
		SetClearResultsMatchTemplateFlag(ThisObject, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillWithCurrentYearData(CopyingValue = Undefined)
	
	// Fills in the form with data of the current year.
	
	SetCalendarField();
	
	If ValueIsFilled(CopyingValue) Then
		ScheduleRef = CopyingValue;
	Else
		ScheduleRef = Object.Ref;
	EndIf;
	
	ScheduleDays = New FixedMap(
		InformationRegisters.CalendarSchedules.ReadScheduleDataFromRegister(ScheduleRef, CurrentYearNumber));

	ReadManualEditingFlag(Object, CurrentYearNumber);
	
	// If there are no manual adjustments or data, generate the result by template for the selected year.
	If ScheduleDays.Count() = 0 And ChangedDays.Count() = 0 Then
		FillParameters = InformationRegisters.CalendarSchedules.ScheduleFillingParameters();
		FillParameters.FillingMethod = Object.FillingMethod;
		FillParameters.FillingTemplate = Object.FillingTemplate;
		FillParameters.BusinessCalendar = Object.BusinessCalendar;
		FillParameters.ConsiderHolidays = Object.ConsiderHolidays;
		FillParameters.ConsiderNonWorkPeriods = Object.ConsiderNonWorkPeriods;
		FillParameters.StartingDate = Object.StartingDate;
		DaysIncludedInSchedule = InformationRegisters.CalendarSchedules.DaysIncludedInSchedule(
			Object.StartDate, Date(CurrentYearNumber, 12, 31), FillParameters);
		ScheduleDays = New FixedMap(DaysIncludedInSchedule);
	EndIf;
	
	SetRemoveResultModified(ThisObject, False);
	SetClearResultsMatchTemplateFlag(ThisObject, Not TemplateModified);

EndProcedure

&AtServer
Procedure ReadManualEditingFlag(CurrentObject, YearNumber)
	
	If CurrentObject.Ref.IsEmpty() Then
		SetRemoveManualEditingFlag(ThisObject, False);
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ManualChanges.ScheduleDate
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|WHERE
	|	ManualChanges.WorkScheduleCalendar = &WorkScheduleCalendar
	|	AND ManualChanges.Year = &Year");
	
	Query.SetParameter("WorkScheduleCalendar", CurrentObject.Ref);
	Query.SetParameter("Year", YearNumber);
	
	Map = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Map.Insert(Selection.ScheduleDate, True);
	EndDo;
	ChangedDays = New FixedMap(Map);
	
	SetRemoveManualEditingFlag(ThisObject, ChangedDays.Count() > 0);
	
EndProcedure

&AtServer
Procedure SaveManualEditingFlag(CurrentObject, YearNumber)
	
	RecordSet = InformationRegisters.ManualWorkScheduleChanges.CreateRecordSet();
	RecordSet.Filter.WorkScheduleCalendar.Set(CurrentObject.Ref);
	RecordSet.Filter.Year.Set(YearNumber);
	
	For Each KeyAndValue In ChangedDays Do
		SetRow = RecordSet.Add();
		SetRow.ScheduleDate = KeyAndValue.Key;
		SetRow.WorkScheduleCalendar = CurrentObject.Ref;
		SetRow.Year = YearNumber;
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

&AtServer
Procedure WriteWorkScheduleDataForYear(YearNumber)
	
	InformationRegisters.CalendarSchedules.WriteScheduleDataToRegister(Object.Ref, ScheduleDays, Date(YearNumber, 1, 1), 
		Date(YearNumber, 12, 31), True);
	SaveManualEditingFlag(Object, YearNumber);
	
EndProcedure

&AtServer
Procedure ProcessYearChange(WriteScheduleData)
	
	If Not WriteScheduleData Then
		FillWithCurrentYearData();
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Write(New Structure("YearNumber", PreviousYearNumber));
	Else
		WriteWorkScheduleDataForYear(PreviousYearNumber);
		FillWithCurrentYearData();	
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveManualEditingFlag(Form, ManualEditing)
	
	Form.ManualEditing = ManualEditing;
	
	If Not ManualEditing Then
		Form.ChangedDays = New FixedMap(New Map);
	EndIf;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetClearResultsMatchTemplateFlag(Form, ResultFilledByTemplate)
	
	Form.ResultFilledByTemplate = ResultFilledByTemplate;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveTemplateModified(Form, TemplateModified)
	
	Form.TemplateModified = TemplateModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveResultModified(Form, ResultModified)
	
	Form.ResultModified = ResultModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillFillingResultInformationText(Form)
	
	InformationText = "";
	InformativeImage = New Picture;
	CanFillByTemplate = False;
	If Form.ManualEditing Then
		InformationText = NStr("en = 'The work schedule for the current year is changed manually. 
                                    |Click ""Fill in by template"" to return to automatic filling.';");
		InformativeImage = PictureLib.Warning;
		CanFillByTemplate = True;
	Else
		If Form.ResultFilledByTemplate Then
			If ValueIsFilled(Form.Object.BusinessCalendar) Then
				InformationText = NStr("en = 'The work schedule is updated automatically upon changing the business calendar for the current year.';");
				InformativeImage = PictureLib.Information;
			EndIf;
		Else
			InformationText = NStr("en = 'The displayed result does not match the template.
                                        |Click ""Fill in by template"" to view the work schedule based on the updated template.';");
			InformativeImage = PictureLib.Warning;
			CanFillByTemplate = True;
		EndIf;
	EndIf;
	
	Form.FillingResultInformationText = InformationText;
	Form.Items.FillingResultDecoration.Picture = InformativeImage;
	Form.Items.FillFromTemplate.Enabled = CanFillByTemplate;
	
	FillInformationTextManualEditing(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillInformationTextManualEditing(Form)
	
	InformationText = "";
	InformativeImage = New Picture;
	If Form.ManualEditing Then
		InformativeImage = PictureLib.Warning;
		InformationText = NStr("en = 'The work schedule for the current year is changed manually. The changes are highlighted.';");
	EndIf;
	
	Form.ManualEditingInformationText = InformationText;
	Form.Items.ManualEditingDecoration.Picture = InformativeImage;
	
EndProcedure

&AtServer
Procedure SetCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	WorkScheduleCalendar = Date(CurrentYearNumber, 1, 1);
	Items.WorkScheduleCalendar.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.WorkScheduleCalendar.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeCompletion(Response, AdditionalParameters) Export
	
	WriteScheduleData = False;
	If Response = DialogReturnCode.Yes Then
		WriteScheduleData = True;
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	SetRemoveResultModified(ThisObject, False);
	Items.WorkScheduleCalendar.Refresh();
	
EndProcedure

&AtClient
Procedure ClarifyStartingDate()
	
	If Object.StartingDate < Date(1900, 1, 1) Then
		Object.StartingDate = BegOfYear(CommonClient.SessionDate());
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetEnabledPreholidaySchedule(Form)
	Items = Form.Items;
	Items.PreholidaySchedule.Enabled = Form.Object.ConsiderHolidays;
EndProcedure

&AtClient
Function AdditionalDayScheduleFillingParameters()

	AdditionalParameters = New Structure(
		"DayNumber,
		|TemplateRowID");
	Return AdditionalParameters;
	
EndFunction

&AtClient
Procedure StartFillDaySchedule(DayNumber, TemplateRowID = Undefined)
	
	ChoiceContext = AdditionalDayScheduleFillingParameters();
	ChoiceContext.DayNumber = DayNumber;
	ChoiceContext.TemplateRowID = TemplateRowID;
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(ChoiceContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	CloseHandler = New NotifyDescription("CompleteDayScheduleFilling", ThisObject, ChoiceContext);
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject, , , , CloseHandler);
	
EndProcedure

&AtClient
Procedure CompleteDayScheduleFilling(ValueSelected, ChoiceContext) Export
	
	If ValueSelected = Undefined Or ReadOnly Then
		Return;
	EndIf;
	
	// Delete the previously filled in schedule for this day.
	DayRows = New Array;
	For Each ScheduleString In Object.WorkSchedule Do
		If ScheduleString.DayNumber = ChoiceContext.DayNumber Then
			DayRows.Add(ScheduleString.GetID());
		EndIf;
	EndDo;
	For Each RowID In DayRows Do
		Object.WorkSchedule.Delete(Object.WorkSchedule.FindByID(RowID));
	EndDo;
	
	// Filling the work hours for a day.
	For Each IntervalDetails In ValueSelected.WorkSchedule Do
		NewRow = Object.WorkSchedule.Add();
		FillPropertyValues(NewRow, IntervalDetails);
		NewRow.DayNumber = ChoiceContext.DayNumber;
	EndDo;
	
	If ChoiceContext.DayNumber = 0 Then
		PreholidaySchedule = DaySchedulePresentation(ThisObject, 0);
	EndIf;
	
	SetClearResultsMatchTemplateFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
	If ChoiceContext.TemplateRowID <> Undefined Then
		TemplateRow = Object.FillingTemplate.FindByID(ChoiceContext.TemplateRowID);
		TemplateRow.DayAddedToSchedule = ValueSelected.WorkSchedule.Count() > 0; // 
		TemplateRow.SchedulePresentation = DaySchedulePresentation(ThisObject, ChoiceContext.DayNumber);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetManualChangesSet()
	
	If Not AccessRight("Update", Metadata.Catalogs.Calendars) Then
		Items.WorkScheduleCalendar.ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion
