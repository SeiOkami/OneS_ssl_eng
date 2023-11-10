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
	
	If Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;
	
	SetListParameters();
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Calendars);
	HasAttributeBulkEditing = Common.SubsystemExists("StandardSubsystems.BatchEditObjects");
	Items.ListChangeSelectedItems.Visible = HasAttributeBulkEditing And CanBeEdited;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtServerNoContext
Procedure ListOnGetDataAtServer(TagName, Settings, Rows)
	
	Query = New Query;
	Query.SetParameter("Calendars", Rows.GetKeys());
	Query.Text = 
		"SELECT
		|	CalendarSchedules.Calendar AS WorkScheduleCalendar,
		|	MAX(CalendarSchedules.ScheduleDate) AS FillDate
		|INTO TTScheduleBusyDates
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|WHERE
		|	CalendarSchedules.Calendar IN(&Calendars)
		|
		|GROUP BY
		|	CalendarSchedules.Calendar
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BusinessCalendarsData.BusinessCalendar AS BusinessCalendar,
		|	MAX(BusinessCalendarsData.Date) AS FillDate
		|INTO TTCalendarBusyDates
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarsData
		|		INNER JOIN Catalog.Calendars AS Calendars
		|		ON (Calendars.BusinessCalendar = BusinessCalendarsData.BusinessCalendar)
		|			AND (Calendars.Ref IN (&Calendars))
		|
		|GROUP BY
		|	BusinessCalendarsData.BusinessCalendar
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CatalogWorkSchedules.Ref AS Ref,
		|	CatalogWorkSchedules.PlanningHorizon AS PlanningHorizon,
		|	CatalogWorkSchedules.EndDate AS EndDate,
		|	CatalogWorkSchedules.BusinessCalendar AS BusinessCalendar,
		|	ISNULL(SchedulesData.FillDate, DATETIME(1, 1, 1)) AS FillDate,
		|	ISNULL(BusinessCalendarsData.FillDate, DATETIME(1, 1, 1)) AS BusinessCalendarFillDate
		|FROM
		|	Catalog.Calendars AS CatalogWorkSchedules
		|		LEFT JOIN TTScheduleBusyDates AS SchedulesData
		|		ON CatalogWorkSchedules.Ref = SchedulesData.WorkScheduleCalendar
		|		LEFT JOIN TTCalendarBusyDates AS BusinessCalendarsData
		|		ON CatalogWorkSchedules.BusinessCalendar = BusinessCalendarsData.BusinessCalendar
		|WHERE
		|	CatalogWorkSchedules.Ref IN(&Calendars)
		|	AND NOT CatalogWorkSchedules.IsFolder";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RequiredFillingDate = AddMonth(CurrentSessionDate(), Selection.PlanningHorizon);
		RequiresFilling = Selection.FillDate < RequiredFillingDate;
		ListLine = Rows[Selection.Ref];
		ListLine.Data["FillDate"] = Selection.FillDate;
		ListLine.Data["BusinessCalendarFillDate"] = Selection.BusinessCalendarFillDate;
		ListLine.Data["RequiresFilling"] = RequiresFilling;
		ListLine.Data["RequiredFillingDate"] = RequiredFillingDate;
		If Not RequiresFilling Then
			Continue;
		EndIf;
		For Each KeyAndValue In ListLine.Appearance Do
			KeyAndValue.Value.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
		EndDo;
		PossibleReason = "";
		If ValueIsFilled(Selection.BusinessCalendar) Then
			If Not ValueIsFilled(Selection.BusinessCalendarFillDate) Then
				PossibleReason = NStr("en = 'The business calendar is blank.';");
			Else
				If Selection.BusinessCalendarFillDate < RequiredFillingDate Then
					PossibleReason = NStr("en = 'The business calendar for the next calendar year is blank.';");
				EndIf;
			EndIf;
		Else
			If Not ValueIsFilled(Selection.EndDate) Then
				PossibleReason = NStr("en = 'The schedule for the next calendar year was not filled in.';");
			Else
				If Selection.EndDate < RequiredFillingDate Then
					PossibleReason = NStr("en = 'The schedule period is limited (see the ""End date"" field).';")
				EndIf;
			EndIf;
		EndIf;
		ListLine.Data["PossibleReason"] = PossibleReason;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeSelectedItems(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchObjectsModificationClient.ChangeSelectedItems(Items.List);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListParameters()
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "ScheduleOwner", , DataCompositionComparisonType.NotFilled, , ,
		DataCompositionSettingsItemViewMode.Normal);
	
EndProcedure

#EndRegion
