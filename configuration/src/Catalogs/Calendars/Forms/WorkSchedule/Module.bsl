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
	
	DaySchedule = Parameters.WorkSchedule;
	AdjustTimeFieldsFormat();
	
	For Each IntervalDetails In DaySchedule Do
		FillPropertyValues(WorkSchedule.Add(), IntervalDetails);
	EndDo;
	WorkSchedule.Sort("BeginTime");
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		Items.FormCancel.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WorkScheduleOnEditEnd(Item, NewRow, CancelEdit)
		
	If CancelEdit Then
		Return;
	EndIf;
	
	WorkSchedulesClient.RestoreCollectionRowOrderAfterEditing(WorkSchedule, "BeginTime", Item.CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function DaySchedule()
	
	Cancel = False;
	
	DaySchedule = New Array;
	
	EndDay = Undefined;
	
	For Each ScheduleString In WorkSchedule Do
		RowIndex = WorkSchedule.IndexOf(ScheduleString);
		If ScheduleString.BeginTime > ScheduleString.EndTime 
			And ValueIsFilled(ScheduleString.EndTime) Then
			CommonClient.MessageToUser(
				NStr("en = 'The start time is greater than the end time.';"), ,
				StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If ScheduleString.BeginTime = ScheduleString.EndTime Then
			CommonClient.MessageToUser(
				NStr("en = 'The interval length is not specified.';"), ,
				StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If EndDay <> Undefined Then
			If EndDay > ScheduleString.BeginTime 
				Or Not ValueIsFilled(EndDay) Then
				CommonClient.MessageToUser(
					NStr("en = 'Overlapping intervals are detected.';"), ,
					StringFunctionsClientServer.SubstituteParametersToString("WorkSchedule[%1].BeginTime", RowIndex), ,
					Cancel);
			EndIf;
		EndIf;
		EndDay = ScheduleString.EndTime;
		DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
	EndDo;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Return DaySchedule;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	DaySchedule = DaySchedule();
	If DaySchedule = Undefined Then
		Return;
	EndIf;
	
	Modified = False;
	NotifyChoice(New Structure("WorkSchedule", DaySchedule));
	
EndProcedure

&AtServer
Procedure AdjustTimeFieldsFormat()
	
	TimeFormat = ?(WorkSchedules.TwelveHourTimeFormat(),
		NStr("en = 'DF=''hh:mm tt''; DE=';"), NStr("en = 'DF=hh:mm; DE=';"));
	EditingTimeFormat = ?(WorkSchedules.TwelveHourTimeFormat(),
		NStr("en = 'DF=''hh:mm tt''';"), NStr("en = 'DF=hh:mm';"));
	
	Items.WorkScheduleBeginTime.Format = TimeFormat;
	Items.WorkScheduleBeginTime.EditFormat = EditingTimeFormat;
	
	Items.WorkScheduleEndTime.Format = TimeFormat;
	Items.WorkScheduleEndTime.EditFormat = EditingTimeFormat;
	
EndProcedure

#EndRegion
