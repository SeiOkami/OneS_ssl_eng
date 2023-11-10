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
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");	
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visible = False;
		Items.ListCommandBar.Visible = False;
		Items.ShowExecuted.Visible = False;
		Items.TasksTree.Visible = True;
	Else	
		Items.List.Visible = True;
		Items.ListCommandBar.Visible = True;
		Items.ShowExecuted.Visible = True;
		Items.TasksTree.Visible = False;
	EndIf;	
	
	List.Parameters.Items[0].Value = Parameters.FilterValue;
	List.Parameters.Items[0].Use = True;
	Title = NStr("en = 'Tasks on this subject';");
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.TaskDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
	
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksList();
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetFilter(Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowExecutedOnChange(Item)
	SetFilter(New Structure("ShowExecuted", ShowExecuted));
EndProcedure

#EndRegion

#Region TasksTreeFormTableItemEventHandlers

&AtClient
Procedure TasksTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenCurrentTaskTreeLine();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	RefreshTasksList();
	For Each String In TasksTree.GetItems() Do
		Items.TasksTree.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	OpenCurrentTaskTreeLine();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TasksTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TasksTree.IsTaskOverdue");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TasksTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TasksTree.Executed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);

	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	CommonClientServer.DeleteDynamicListFilterGroupItems(List, "Executed");
	If Not FilterParameters["ShowExecuted"] Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TasksTree");
	Tree.Rows.Clear();
	
	AddTasksBySubject(Tree, Parameters.FilterValue);
	
	ValueToFormAttribute(Tree, "TasksTree");
	
EndProcedure	

&AtServer
Procedure RefreshTasksList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		Items.List.Refresh();
		// 
		// 
		BusinessProcessesAndTasksServer.SetTaskAppearance(List); 
	EndIf;
	
EndProcedure

&AtServer
Procedure AddTasksBySubject(Tree, SubjectOf)
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Tasks.Ref,
		|	Tasks.Description,
		|	Tasks.Performer,
		|	Tasks.PerformerRole,
		|	Tasks.TaskDueDate,
		|	Tasks.Executed,
		|	CASE
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.Low)
		|			THEN 0
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN Tasks.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Suspended)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Suspended
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.SubjectOf = &SubjectOf
		|   AND Tasks.DeletionMark = FALSE";
		
	Query.SetParameter("SubjectOf", SubjectOf);

	Result = Query.Execute();
	
	SelectionDetailRecords = Result.Select();

 	TasksBySubject = BusinessProcessesAndTasksServer.NewTasksBySubject();
	
	While SelectionDetailRecords.Next() Do
		
		Branch = Tree.Rows.Find(SelectionDetailRecords.Ref, "Ref", True);
		If Branch = Undefined Then
			String = Tree.Rows.Add();
			
			String.Description = SelectionDetailRecords.Description;
			String.Importance = SelectionDetailRecords.Importance;
			String.Type = 1;
			String.Suspended = SelectionDetailRecords.Suspended;
			String.Ref = SelectionDetailRecords.Ref;
			String.TaskDueDate = SelectionDetailRecords.TaskDueDate;
			String.Executed = SelectionDetailRecords.Executed;
			If SelectionDetailRecords.TaskDueDate <> "00010101"
				And SelectionDetailRecords.TaskDueDate < CurrentSessionDate() Then
				String.IsTaskOverdue = True;
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.Performer) Then
				String.Performer = SelectionDetailRecords.Performer;
			Else
				String.Performer = SelectionDetailRecords.PerformerRole;
			EndIf;
			
			NewRow = TasksBySubject.Add();
			NewRow.TaskRef = SelectionDetailRecords.Ref;
			
		EndIf;
		
	EndDo;
	
	AddSubordinateBusinessProcesses(Tree, TasksBySubject);
	
EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcesses(Tree, TasksBySubject)
	
	RequestText = 
		"SELECT
		|	TasksBySubject.TaskRef AS TaskRef,
		|	BusinessProcesses.Ref,
		|	BusinessProcesses.Description,
		|	BusinessProcesses.Completed,
		|	CASE
		|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceOptions.Low)
		|			THEN 0
		|		WHEN BusinessProcesses.Importance = VALUE(Enum.TaskImportanceOptions.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN BusinessProcesses.State = VALUE(Enum.BusinessProcessStates.Suspended)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Suspended
		|FROM
		|	TasksBySubject AS TasksBySubject
		|	LEFT JOIN &BusinessProcesses AS BusinessProcesses
		|	ON BusinessProcesses.MainTask = TasksBySubject.TaskRef
		|WHERE
		|   BusinessProcesses.DeletionMark = FALSE";
		
	QueryTextSet_ = New Array();
			
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// Business processes are not required to have a main task.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;
		
		SubqueryText = StrReplace(RequestText, "&BusinessProcesses", BusinessProcessMetadata.FullName());
		If QueryTextSet_.Count() = 0 Then
			SubqueryText = StrReplace(SubqueryText, "SELECT", "SELECT ALLOWED"); // @Query-part-1, @Query-part-2
		EndIf; 
		QueryTextSet_.Add(SubqueryText);
		
	EndDo;
		
	QueryText = "SELECT
	|	TasksBySubject.TaskRef AS TaskRef
	|INTO TasksBySubject
	|FROM
	|	&TasksBySubject AS TasksBySubject
	|;
	|" + StrConcat(QueryTextSet_, Chars.LF + "UNION ALL" + Chars.LF);
	
	Query = New Query(QueryText);
	Query.SetParameter("TasksBySubject", TasksBySubject);

	Result = Query.Execute();
	
	SelectionDetailRecords = Result.Select();

	While SelectionDetailRecords.Next() Do
		
		// 
		AddSubordinateBusinessProcessTasks(Tree, SelectionDetailRecords.Ref, SelectionDetailRecords.TaskRef);
		
	EndDo;

EndProcedure

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef, TaskRef)
	
	Branch = Tree.Rows.Find(TaskRef, "Ref", True);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Tasks.Ref,
		|	Tasks.Description,
		|	Tasks.Performer,
		|	Tasks.PerformerRole,
		|	Tasks.TaskDueDate,
		|	Tasks.Executed,
		|	CASE
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.Low)
		|			THEN 0
		|		WHEN Tasks.Importance = VALUE(Enum.TaskImportanceOptions.High)
		|			THEN 2
		|		ELSE 1
		|	END AS Importance,
		|	CASE
		|		WHEN Tasks.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Suspended)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS Suspended
		|FROM
		|	Task.PerformerTask AS Tasks
		|WHERE
		|   Tasks.BusinessProcess = &BusinessProcess
		|   AND Tasks.DeletionMark = FALSE";
		
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	SelectionDetailRecords = Result.Select();
	
	TasksBySubject = BusinessProcessesAndTasksServer.NewTasksBySubject();

	While SelectionDetailRecords.Next() Do
		
		FoundBranch = Tree.Rows.Find(SelectionDetailRecords.Ref, "Ref", True);
		
		If FoundBranch <> Undefined Then
			If FoundBranch.Parent = Undefined Then
				Tree.Rows.Delete(FoundBranch);
			Else
				FoundBranch.Parent.Rows.Delete(FoundBranch);
			EndIf;
		EndIf;
			
		String = Undefined;
		If Branch = Undefined Then
			String = Tree.Rows.Add();
		Else	
			String = Branch.Rows.Add();
		EndIf;
		
		String.Description = SelectionDetailRecords.Description;
		String.Importance = SelectionDetailRecords.Importance;
		String.Type = 1;
		String.Suspended = SelectionDetailRecords.Suspended;
		String.Ref = SelectionDetailRecords.Ref;
		String.TaskDueDate = SelectionDetailRecords.TaskDueDate;
		String.Executed = SelectionDetailRecords.Executed;
		If SelectionDetailRecords.TaskDueDate <> '00010101000000' 
			And SelectionDetailRecords.TaskDueDate < CurrentSessionDate() Then
			String.IsTaskOverdue = True;
		EndIf;
		If ValueIsFilled(SelectionDetailRecords.Performer) Then
			String.Performer = SelectionDetailRecords.Performer;
		Else
			String.Performer = SelectionDetailRecords.PerformerRole;
		EndIf;
		
		NewRow = TasksBySubject.Add();
		NewRow.TaskRef = SelectionDetailRecords.Ref;
	EndDo;
	
	AddSubordinateBusinessProcesses(Tree, TasksBySubject);
	
EndProcedure

&AtClient
Procedure OpenCurrentTaskTreeLine()
	
	If Items.TasksTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(,Items.TasksTree.CurrentData.Ref);
	
EndProcedure

#EndRegion
