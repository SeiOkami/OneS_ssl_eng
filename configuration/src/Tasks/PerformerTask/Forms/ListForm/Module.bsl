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
	
	If Not IsBlankString(Parameters.FormCaption) Then
		Title = Parameters.FormCaption;
		AutoTitle = False;
	EndIf;
	
	Items.TitleGroup.Visible = Not IsBlankString(Parameters.BusinessProcess);
	BusinessProcessLine = Parameters.BusinessProcess;
	TaskLine = Parameters.Task;
	
	If Parameters.Property("ShowTasks") Then
		ShowTasks = Parameters.ShowTasks;
	Else
		ShowTasks = 2;
	EndIf;
	
	If Parameters.FiltersVisibility <> Undefined Then
		Items.GroupFilter.Visible = Parameters.FiltersVisibility;
	Else
		ByAuthor = Users.AuthorizedUser();
	EndIf;
	SetFilter();
	
	If Parameters.OwnerWindowLock <> Undefined Then
		WindowOpeningMode = Parameters.OwnerWindowLock;
	EndIf;
		
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.TaskDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.CompletionDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	If Users.IsExternalUserSession() Then
		Items.ByAuthor.Visible = False;
		Items.ByPerformer.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)

	SettingName = ?(Not IsBlankString(Parameters.BusinessProcess), "BPListForm", "ListForm");
	Filter_Settings = Common.SystemSettingsStorageLoad("Tasks.PerformerTask.Forms.ListForm", SettingName);
	If Filter_Settings = Undefined Then 
		Settings.Clear();
		Return;
	EndIf;
	
	For Each Item In Filter_Settings Do
		Settings.Insert(Item.Key, Item.Value);
	EndDo;
	SetListFilter(List, Filter_Settings);
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	SettingsName = ?(Items.TitleGroup.Visible, "BPListForm", "ListForm");
	Common.SystemSettingsStorageSave("Tasks.PerformerTask.Forms.ListForm", SettingsName, Settings);
EndProcedure

&AtClient
Procedure NavigationProcessing(NavigationObject, StandardProcessing)
	
	If Not ValueIsFilled(NavigationObject) Or NavigationObject = Items.List.CurrentRow Then
		Return;
	EndIf;
	
	ByAuthor = Undefined;
	ByPerformer = Undefined;
	ShowTasks = 0;
	SetFilter();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ByPerformerOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ByAuthorOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ShowTasks1OnChange(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Copy, 
		Parent, Var_Group);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	AcceptedForExecution = False;
	If Item.CurrentData <> Undefined Then
		Item.CurrentData.Property("AcceptedForExecution", AcceptedForExecution) 
	EndIf;
	SetAcceptForExecutionAvailability(AcceptedForExecution);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
	SetAcceptForExecutionAvailability(False);
	
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	SetAcceptForExecutionAvailability(True);
	
EndProcedure

&AtClient
Procedure RefreshTasksList(Command)
	
	RefreshTasksListOnServer();
	
EndProcedure

&AtClient
Procedure OpenBusinessProcess(Command)
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	If Items.List.CurrentData.BusinessProcess = Undefined Then
		ShowMessageBox(,NStr("en = 'Business process of the selected task is not specified.';"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.BusinessProcess);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	If TypeOf(Items.List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	If Items.List.CurrentData.SubjectOf = Undefined Then
		ShowMessageBox(,NStr("en = 'Subject of the selected task is not specified.';"));
		Return;
	EndIf;
	ShowValue(, Items.List.CurrentData.SubjectOf);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFilter()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ByAuthor", ByAuthor);
	FilterParameters.Insert("ByPerformer", ByPerformer);
	FilterParameters.Insert("ShowTasks", ShowTasks);
	SetListFilter(List, FilterParameters);
	
EndProcedure	

&AtServerNoContext
Procedure SetListFilter(List, FilterParameters)
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Author", FilterParameters["ByAuthor"],,, FilterParameters["ByAuthor"] <> Undefined And Not FilterParameters["ByAuthor"].IsEmpty());
	
	If FilterParameters["ByPerformer"] = Undefined Or FilterParameters["ByPerformer"].IsEmpty() Then
		List.Parameters.SetParameterValue("SelectedPerformer", NULL);
	Else	
		List.Parameters.SetParameterValue("SelectedPerformer", FilterParameters["ByPerformer"]);
	EndIf;
		
	If FilterParameters["ShowTasks"] = 0 Then 
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,False);
	ElsIf FilterParameters["ShowTasks"] = 1 Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", True,,,True);
	ElsIf FilterParameters["ShowTasks"] = 2 Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False,,,True);
	EndIf;	
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	// 
	// 
	SetConditionalAppearance();
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure SetAcceptForExecutionAvailability(FlagValue1)
	
	Items.AcceptForExecution.Enabled                      = FlagValue1;
	Items.ListContextMenuAcceptForExecution.Enabled = FlagValue1;
	Items.ListContextMenuCancelAcceptForExecution.Enabled = Not FlagValue1;

EndProcedure

#EndRegion
