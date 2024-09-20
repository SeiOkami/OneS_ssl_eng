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

Function NonWorkDaysPeriods(BusinessCalendar) Export
	
	Query = New Query;
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	Query.Text = 
		"SELECT
		|	CalendarNonWorkDaysPeriods.BusinessCalendar AS BusinessCalendar,
		|	CalendarNonWorkDaysPeriods.PeriodNumber AS PeriodNumber,
		|	CalendarNonWorkDaysPeriods.StartDate AS StartDate,
		|	CalendarNonWorkDaysPeriods.EndDate AS EndDate,
		|	CalendarNonWorkDaysPeriods.Basis AS Basis
		|FROM
		|	InformationRegister.CalendarNonWorkDaysPeriods AS CalendarNonWorkDaysPeriods
		|WHERE
		|	CalendarNonWorkDaysPeriods.BusinessCalendar = &BusinessCalendar
		|
		|ORDER BY
		|	PeriodNumber";
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#EndIf	