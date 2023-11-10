///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Identical procedures and functions of PeriodClosingDates and PeriodEndClosingDateEdit forms.

Function ClosingDatesDetails() Export
	
	List = New Map;
	List.Insert("",                      NStr("en = 'No date';"));
	List.Insert("Custom",      NStr("en = 'Custom date';"));
	List.Insert("EndOfLastYear",     NStr("en = 'End of last year';"));
	List.Insert("EndOfLastQuarter", NStr("en = 'End of last quarter';"));
	List.Insert("EndOfLastMonth",   NStr("en = 'End of last month';"));
	List.Insert("EndOfLastWeek",    NStr("en = 'End of last week';"));
	List.Insert("PreviousDay",        NStr("en = 'Previous day';"));
	
	Return List;
	
EndFunction

Procedure SpecifyPeriodEndClosingDateSetupOnChange(Context, CalculatePeriodEndClosingDate = True) Export
	
	If Not Context.ExtendedModeSelected Then
		If Context.PeriodEndClosingDate <> '00010101' And Context.PeriodEndClosingDateDetails = "" Then
			Context.PeriodEndClosingDateDetails = "Custom";
			
		ElsIf Context.PeriodEndClosingDate = '00010101'
		        And Context.PeriodEndClosingDateDetails = "Custom"
		        And Not Context.RecordExists Then
			
			Context.PeriodEndClosingDateDetails = "";
		EndIf;
	EndIf;
	If Context.PeriodEndClosingDateDetails = "" Then
		Context.PeriodEndClosingDate = "00010101";
	EndIf;
	
	Context.RelativePeriodEndClosingDateLabelText = "";
	
	If Context.PeriodEndClosingDateDetails = "Custom" Or Context.PeriodEndClosingDateDetails = "" Then
		Context.PermissionDaysCount = 0;
		Return;
	EndIf;
	
	CalculatedPeriodEndClosingDates = PeriodEndClosingDateCalculation(
		Context.PeriodEndClosingDateDetails, Context.BegOfDay);
	
	If CalculatePeriodEndClosingDate Then
		Context.PeriodEndClosingDate = CalculatedPeriodEndClosingDates.Current;
	EndIf;
	
	LabelText = "";
	
	If Context.EnableDataChangeBeforePeriodEndClosingDate Then
		Days1 = 60*60*24;
		
		AdjustPermissionDaysCount(
			Context.PeriodEndClosingDateDetails, Context.PermissionDaysCount);
		
		PermissionPeriod = CalculatedPeriodEndClosingDates.Current + Context.PermissionDaysCount * Days1;
		
		If Context.BegOfDay > PermissionPeriod Then
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Data entry and editing for all previous periods 
					|up to %1 are prohibited (%2).
					|Delay that allowed data entry and editing 
					|for the period from %3 to %4 expired on %5.';"),
				Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]),
				Format(CalculatedPeriodEndClosingDates.Prev + Days1, "DLF=D"), Format(CalculatedPeriodEndClosingDates.Current, "DLF=D"),
				Format(PermissionPeriod, "DLF=D"));
		Else
			If CalculatePeriodEndClosingDate Then
				Context.PeriodEndClosingDate = CalculatedPeriodEndClosingDates.Prev;
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '• You cannot enter and edit data till %1 inclusive 
					|for all previous periods up to %2; 
					|there is a delay that allows data entry and editing 
					|for the period from %4 to %5;
					|• Period-end closing becomes effective from %6 
					| for all previous periods up to %5 (%3).';"),
					Format(PermissionPeriod, "DLF=D"), Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]),
					Format(CalculatedPeriodEndClosingDates.Prev + Days1, "DLF=D"),  Format(CalculatedPeriodEndClosingDates.Current, "DLF=D"), 
					Format(PermissionPeriod + Days1, "DLF=D"));
		EndIf;
	Else 
		Context.PermissionDaysCount = 0;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data entry and editing for all previous periods
			           |up to %1 (%2) are restricted';"),
			Format(Context.PeriodEndClosingDate, "DLF=D"), Lower(ClosingDatesDetails()[Context.PeriodEndClosingDateDetails]));
	EndIf;
	
	Context.RelativePeriodEndClosingDateLabelText = LabelText;
	
EndProcedure

// Parameters:
//  Context - ClientApplicationForm:
//    * Items - FormAllItems:
//       ** EnableDataChangeBeforePeriodEndClosingDate - FormField
//       ** PermissionDaysCount - FormField
//       ** NoncustomDateNote - FormField
// 
Procedure UpdatePeriodEndClosingDateDisplayOnChange(Context) Export
	
	If Not Context.ExtendedModeSelected Then
		
		If Context.PeriodEndClosingDateDetails = "" Or Context.PeriodEndClosingDateDetails = "Custom" Then
			Context.ExtendedModeSelected = False;
			Context.Items.ExtendedMode.Visible = False;
			Context.Items.OperationModesGroup.CurrentPage = Context.Items.SimpleMode;
		Else
			Context.ExtendedModeSelected = True;
			Context.Items.ExtendedMode.Visible = True;
			Context.Items.OperationModesGroup.CurrentPage = Context.Items.ExtendedMode;
		EndIf;
		
	EndIf;
	
	If Context.PeriodEndClosingDateDetails = "" Or Context.PeriodEndClosingDateDetails = "Custom" Then
		Context.Items.Custom.CurrentPage = ?(Context.PeriodEndClosingDateDetails = "",
			Context.Items.CustomNotUsed, Context.Items.CustomDateUsed);
		EditFormat = ?(Context.RecordExists, "DP=01.01.0001", "");
		Context.Items.PeriodEndClosingDateSimpleMode.EditFormat = EditFormat;
		Context.Items.PeriodEndClosingDate.EditFormat = EditFormat;
		Context.Items.PeriodEndClosingDateProperties.CurrentPage = Context.Items.GroupLessOptions;
		Context.Items.PeriodEndClosingDateSimpleMode.UpdateEditText();
		Context.Items.PeriodEndClosingDate.UpdateEditText();
		Context.EnableDataChangeBeforePeriodEndClosingDate = False;
		Return;
	EndIf;
	
	Context.Items.PeriodEndClosingDateProperties.CurrentPage = Context.Items.RelativeDate;
	Context.Items.Custom.CurrentPage = Context.Items.CustomNotUsed;
	
	If Context.PeriodEndClosingDateDetails = "PreviousDay" Then
		Context.Items.EnableDataChangeBeforePeriodEndClosingDate.Enabled = False;
		Context.EnableDataChangeBeforePeriodEndClosingDate = False;
	Else
		Context.Items.EnableDataChangeBeforePeriodEndClosingDate.Enabled = True;
	EndIf;
	
	Context.Items.PermissionDaysCount.Enabled = Context.EnableDataChangeBeforePeriodEndClosingDate;
	Context.Items.NoncustomDateNote.Title = Context.RelativePeriodEndClosingDateLabelText;
	
EndProcedure

Function PeriodEndClosingDateCalculation(Val PeriodEndClosingDateOption, Val CurrentDateAtServer)
	
	Days1 = 60*60*24;
	
	CurrentPeriodEndClosingDate    = '00010101';
	PreviousPeriodEndClosingDate = '00010101';
	
	If PeriodEndClosingDateOption = "EndOfLastYear" Then
		CurrentPeriodEndClosingDate    = BegOfYear(CurrentDateAtServer) - Days1;
		PreviousPeriodEndClosingDate = BegOfYear(CurrentPeriodEndClosingDate)   - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastQuarter" Then
		CurrentPeriodEndClosingDate    = BegOfQuarter(CurrentDateAtServer) - Days1;
		PreviousPeriodEndClosingDate = BegOfQuarter(CurrentPeriodEndClosingDate)   - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastMonth" Then
		CurrentPeriodEndClosingDate    = BegOfMonth(CurrentDateAtServer) - Days1;
		PreviousPeriodEndClosingDate = BegOfMonth(CurrentPeriodEndClosingDate)   - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastWeek" Then
		CurrentPeriodEndClosingDate    = BegOfWeek(CurrentDateAtServer) - Days1;
		PreviousPeriodEndClosingDate = BegOfWeek(CurrentPeriodEndClosingDate)   - Days1;
		
	ElsIf PeriodEndClosingDateOption = "PreviousDay" Then
		CurrentPeriodEndClosingDate    = BegOfDay(CurrentDateAtServer) - Days1;
		PreviousPeriodEndClosingDate = BegOfDay(CurrentPeriodEndClosingDate)   - Days1;
	EndIf;
	
	Return New Structure("Current, Prev", CurrentPeriodEndClosingDate, PreviousPeriodEndClosingDate);
	
EndFunction

Procedure AdjustPermissionDaysCount(Val PeriodEndClosingDateDetails, PermissionDaysCount)
	
	If PermissionDaysCount = 0 Then
		PermissionDaysCount = 1;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastYear" Then
		If PermissionDaysCount > 90 Then
			PermissionDaysCount = 90;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastQuarter" Then
		If PermissionDaysCount > 60 Then
			PermissionDaysCount = 60;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastMonth" Then
		If PermissionDaysCount > 25 Then
			PermissionDaysCount = 25;
		EndIf;
		
	ElsIf PeriodEndClosingDateDetails = "EndOfLastWeek" Then
		If PermissionDaysCount > 5 Then
			PermissionDaysCount = 5;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
