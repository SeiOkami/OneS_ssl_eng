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
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	
	If UseSubordinateBusinessProcesses Then
		Items.List.Visible = False;
		Items.ListCommandBar.Visible = False;
		Items.TasksTree.Visible = True;
	Else	
		Items.List.Visible = True;
		Items.ListCommandBar.Visible = True;
		Items.TasksTree.Visible = False;
	EndIf;	
		
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Tasks of business process %1';"), String(Parameters.FilterValue));
		
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
		Items.TaskDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Else
		CommonClientServer.SetDynamicListFilterItem(
			List,"BusinessProcess", Parameters.FilterValue);
		CommonClientServer.SetDynamicListFilterItem(
			List, "Executed", False);
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
	
	ShowExecuted = Settings["ShowExecuted"];
	RefreshTasksList();

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowExecutedOnChange(Item)
	
	RefreshTasksList();
	
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
	
	FillTaskTree();
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
Procedure RefreshTasksList()
	
	UseSubordinateBusinessProcesses = GetFunctionalOption("UseSubordinateBusinessProcesses");
	If UseSubordinateBusinessProcesses Then 
		FillTaskTree();
	Else
		CommonClientServer.DeleteDynamicListFilterGroupItems(List, "Executed");
		If Not ShowExecuted Then
			CommonClientServer.SetDynamicListFilterItem(
				List, "Executed", False);
		EndIf;
		Items.List.Refresh();
	EndIf;
	// 
	// 
	BusinessProcessesAndTasksServer.SetTaskAppearance(List); 
	
EndProcedure

&AtClient
Procedure OpenCurrentTaskTreeLine()
	
	If Items.TasksTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(,Items.TasksTree.CurrentData.Ref);
	
EndProcedure

&AtServer
Procedure FillTaskTree()
	
	Tree = FormAttributeToValue("TasksTree");
	Tree.Rows.Clear();
	
	AddSubordinateBusinessProcessTasks(Tree, Parameters.FilterValue);
	
	ValueToFormAttribute(Tree, "TasksTree");
	
EndProcedure	

&AtServer
Procedure AddSubordinateBusinessProcessTasks(Tree, BusinessProcessRef)
	
	Branch = Tree.Rows.Find(BusinessProcessRef, "Ref", True);
	
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
		|	Tasks.BusinessProcess = &BusinessProcess
		|	AND Tasks.DeletionMark = FALSE";
	If Not ShowExecuted Then	
		Query.Text = Query.Text + "
			|	AND Tasks.Executed = &Executed";
		Query.SetParameter("Executed", False);
	EndIf;	
	Query.SetParameter("BusinessProcess", BusinessProcessRef);

	Result = Query.Execute();
	
	SelectionDetailRecords = Result.Select();
	
	TasksBySubject = BusinessProcessesAndTasksServer.NewTasksBySubject();

	While SelectionDetailRecords.Next() Do
		
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
		
		Branch = Tree.Rows.Find(SelectionDetailRecords.TaskRef, "Ref", True);
		
		String              = Branch.Rows.Add();
		
		String.Description = SelectionDetailRecords.Description;
		String.Importance     = SelectionDetailRecords.Importance;
		String.Suspended   = SelectionDetailRecords.Suspended;
		String.Ref       = SelectionDetailRecords.Ref;
		String.Executed    = SelectionDetailRecords.Completed;
		String.Type          = 0;
		
		// 
		AddSubordinateBusinessProcessTasks(Tree, SelectionDetailRecords.Ref);
		
	EndDo;

EndProcedure

#EndRegion
