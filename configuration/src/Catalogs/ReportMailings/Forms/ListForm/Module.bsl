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
	
	If Parameters.Property("Representation") Then
		Items.List.Representation = TableRepresentation[Parameters.Representation];
	EndIf;
	
	ErrorTextOnOpen = ReportMailing.CheckAddRightErrorText();
	If ValueIsFilled(ErrorTextOnOpen) Then
		Raise ErrorTextOnOpen;
	EndIf;
	
	// Standard subsystems.Pluggable commands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// 
	
	// 
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCreateAtServer(ThisObject);
	EndIf;
	// 
	
	// 
	CommonClientServer.SetDynamicListFilterItem(
		List, "ExecuteOnSchedule", False,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "SchedulePeriodicity", ,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "IsPrepared", False,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Author", ,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	FillListParameter("ChoiceMode");
	FillListParameter("ChoiceFoldersAndItems");
	FillListParameter("MultipleChoice");
	FillListParameter("CurrentRow");
	
	If Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		// Режим показа только личных рассылок - 
		Items.List.Representation = TableRepresentation.List;
		CommonClientServer.SetDynamicListFilterItem(List, "IsFolder", False, , , True,
			DataCompositionSettingsItemViewMode.Inaccessible);
	EndIf;
	
	ReportFilter = Parameters.Report;
	SetFilter(False);

	List.Parameters.SetParameterValue("DateEmpty", '00010101');
	List.Parameters.SetParameterValue("NewStatePresentation", NStr("en = 'New';"));
	List.Parameters.SetParameterValue("NotCompletedStatePresentation", NStr("en = 'Not completed';"));
	List.Parameters.SetParameterValue("CompletedWithErrorsStatePresentation", NStr("en = 'Partially completed';"));
	List.Parameters.SetParameterValue("CompletedStatePresentation", NStr("en = 'Completed';"));
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
		Or Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Items.ChangeSelectedItems.Visible = False;
		Items.ChangeSelectedItemsList.Visible = False;
	EndIf;
	
	If Not AccessRight("EventLog", Metadata) Then
		Items.MailingEvents.Visible = False;
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetListFilter(Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StateFilterOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure ReportFilterOnChange(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure EmployeeResponsibleFilterOnChange(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	If String = PredefinedValue("Catalog.ReportMailings.PersonalMailings") Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	// Standard subsystems.Pluggable commands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// 
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeSelectedItems(Command)
	ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
	ModuleBatchObjectsModificationClient.ChangeSelectedItems(Items.List);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.LastRun", Items.LastRun.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.SuccessfulStart", Items.SuccessfulStart.Name);

	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	// Unprepared report distribution.
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("IsFolder");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("IsPrepared");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
EndProcedure

&AtServer
Procedure FillListParameter(Var_Key)
	If Parameters.Property(Var_Key) And ValueIsFilled(Parameters[Var_Key]) Then
		Items.List[Var_Key] = Parameters[Var_Key];
	EndIf;
EndProcedure

&AtServer
Procedure SetFilter(ClearFixedFilters = True)
	
	If ClearFixedFilters Then
		List.Filter.Items.Clear();
	EndIf;
	FilterParameters = New Map();
	FilterParameters.Insert("WithErrors", StateFilter);
	FilterParameters.Insert("Report", ReportFilter);
	FilterParameters.Insert("Author", EmployeeResponsibleFilter);
	SetListFilter(FilterParameters);
EndProcedure

&AtServer
Procedure SetListFilter(FilterParameters)
	
	CommonClientServer.SetDynamicListFilterItem(List, "Author", FilterParameters["Author"],,,
		Not FilterParameters["Author"].IsEmpty());
	CommonClientServer.SetDynamicListFilterItem(List, "WithErrors", FilterParameters["WithErrors"] = "Incomplete",,, 
		FilterParameters["WithErrors"] <> "All" And ValueIsFilled(FilterParameters["WithErrors"]));
	CommonClientServer.SetDynamicListParameter(List, "ReportFilter", FilterParameters["Report"],
		ValueIsFilled(FilterParameters["Report"]) And Not FilterParameters["Report"].IsEmpty());
	
EndProcedure

// Standard subsystems.Pluggable commands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
	EndIf;
EndProcedure

// 

#EndRegion
