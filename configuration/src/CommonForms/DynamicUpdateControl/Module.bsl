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
	
	CheckParameters = Catalogs.ExtensionsVersions.DynamicallyChangedExtensions();
	CheckParameters.Insert("DataBaseConfigurationChangedDynamically", DataBaseConfigurationChangedDynamically());
	
	If CheckParameters.Corrections <> Undefined And CheckParameters.Corrections.NewItemsList.Count() > 0 Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		MethodParameters = New Array;
		MethodParameters.Add(StorageAddress);
		MethodParameters.Add(CheckParameters.Corrections.NewItemsList);
		BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
			"ConfigurationUpdate.NewPatchesDetails1",
			MethodParameters);
		BackgroundJob.WaitForExecutionCompletion(Undefined);
		
		NewPatchesDetails = GetFromTempStorage(StorageAddress);
		LinkToDetails = " " + NStr("en = '<a href = ""%1"">Detailed information</a>';");
	Else
		LinkToDetails = "Ref";
	EndIf;
	
	Message = StandardSubsystemsServer.MessageTextOnDynamicUpdate(CheckParameters,
		LinkToDetails);
	
	Items.Text.Title = StringFunctions.FormattedString(Message, "LinkAction");
	
	WithASchedule = True;
	If CheckParameters.Corrections = Undefined
		Or CheckParameters.Corrections.Added2 = 0 Then
		Items.ScheduleGroup.Visible = False;
		WithASchedule = False;
	Else
		FillInTheFormDisplaySchedule();
	EndIf;
	
	Var_Key = "";
	If CheckParameters.DataBaseConfigurationChangedDynamically Then
		Var_Key = "Configuration";
	EndIf;
	If CheckParameters.Corrections <> Undefined Then
		Var_Key = Var_Key + "Corrections";
	EndIf;
	If CheckParameters.Extensions <> Undefined Then
		Var_Key = Var_Key + "Extensions";
	EndIf;
	If WithASchedule Then
		Var_Key = Var_Key + "Schedule";
	EndIf;
	
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, Var_Key);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If Not Exit Then
		SaveSchedule();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	Document = New TextDocument;
	Document.SetText(NewPatchesDetails);
	Document.Show(NStr("en = 'New bug fixes';"));
EndProcedure

&AtClient
Procedure ScheduleClick(Item, StandardProcessing)
	StandardProcessing = False;
	CompletionHandler = New NotifyDescription("ScheduleClickCompletion", ThisObject);
	List = New ValueList;
	List.Add("Once", NStr("en = 'once a day';"));
	List.Add("Twice", NStr("en = 'twice a day';"));
	List.Add("OtherInterval", NStr("en = 'another interval…';"));
	
	ShowChooseFromMenu(CompletionHandler, List, Items.Schedule);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Restart(Command)
	SaveSchedule();
	StandardSubsystemsClient.SkipExitConfirmation();
	Exit(True, True);
EndProcedure

&AtClient
Procedure RemindLater(Command)
	RemindMeTomorrow();
	Close();
EndProcedure

&AtClient
Procedure DontRemindAgain(Command)
	DontRemindAgainAtServer();
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DontRemindAgainAtServer()
	Common.CommonSettingsStorageSave("UserCommonSettings",
		"ShowInstalledApplicationUpdatesWarning",
		False);
EndProcedure

&AtClient
Procedure RemindMeTomorrow()
	RemindTomorrowOnServer();
EndProcedure

&AtServerNoContext
Procedure RemindTomorrowOnServer()
	
	Common.SystemSettingsStorageSave("DynamicUpdateControl",
		"DateRemindTomorrow", BegOfDay(CurrentSessionDate()) + 60*60*24);
	
EndProcedure

&AtClient
Procedure ScheduleClickCompletion(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Value = "Once" Or Result.Value = "Twice" Then
		SchedulePresentation = Result;
		ScheduleChanged = True;
		CurrentSchedule.Id = Result.Value;
		CurrentSchedule.Presentation = Result.Presentation;
		CurrentSchedule.Schedule = StandardSchedule[Result.Value];
		Return;
	EndIf;
	
	CompletionsHandler = New NotifyDescription("ScheduleClickAfterSelectingAnArbitrarySchedule", ThisObject);
	ScheduleDialog1 = New ScheduledJobDialog(New JobSchedule);
	ScheduleDialog1.Show(CompletionsHandler);
EndProcedure

&AtClient
Procedure ScheduleClickAfterSelectingAnArbitrarySchedule(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	ScheduleChanged = True;
	SchedulePresentation = Result;
	CurrentSchedule.Id = "OtherInterval";
	CurrentSchedule.Presentation = String(Result);
	CurrentSchedule.Schedule = Result;
	
EndProcedure

&AtServer
Procedure SaveSchedule()
	If Not ScheduleChanged Then
		Return;
	EndIf;
	
	Common.SystemSettingsStorageSave("DynamicUpdateControl", "PatchCheckSchedule", CurrentSchedule);
EndProcedure

&AtServer
Procedure FillInTheFormDisplaySchedule()
	
	CurrentSchedule = Common.SystemSettingsStorageLoad("DynamicUpdateControl", "PatchCheckSchedule");
	If CurrentSchedule = Undefined Then
		CurrentSchedule = New Structure;
		CurrentSchedule.Insert("Id");
		CurrentSchedule.Insert("Presentation");
		CurrentSchedule.Insert("Schedule");
		CurrentSchedule.Insert("LastAlert");
		SchedulePresentation = NStr("en = 'by default (every 20 minutes)';");
	Else
		SchedulePresentation = CurrentSchedule.Presentation;
	EndIf;
	
	OnceADay = New JobSchedule;
	OnceADay.DaysRepeatPeriod = 1;
	TwiceADay = New JobSchedule;
	TwiceADay.DaysRepeatPeriod = 1;
	
	FirstRun = New JobSchedule;
	FirstRun.BeginTime = Date(01,01,01,09,00,00);
	TwiceADay.DetailedDailySchedules.Add(FirstRun);
	
	SecondLaunch = New JobSchedule;
	SecondLaunch.BeginTime = Date(01,01,01,15,00,00);
	TwiceADay.DetailedDailySchedules.Add(SecondLaunch);
	
	StandardSchedule = New Structure;
	StandardSchedule.Insert("Once", OnceADay);
	StandardSchedule.Insert("Twice", TwiceADay);
	
EndProcedure

#EndRegion