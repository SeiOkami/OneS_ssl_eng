///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("en = 'Totals and aggregates are unavailable in SaaS.';");
	EndIf;
	
	If Not Users.IsFullUser() Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	ReadInformationOnRegisters();
	
	UpdateTotalsListAtServer();
	UpdateAggregatesByRegistersAtServer();
	
	If AggregatesByRegisters.Count() <> 0 Then
		Items.AggregatesList.Title = Prefix() + " " + AggregatesByRegisters[0].Description;
	Else
		Items.AggregatesList.Title = Prefix();
	EndIf;
	
	If TotalsList.Count() = 0 Then
		Items.TotalsGroup.Enabled = False;
		Items.SetTotalsPeriod.Enabled = False;
		Items.EnableTotalsUsage.Enabled = False;
	EndIf;
	
	If AggregatesByRegisters.Count() = 0 Then
		Items.AggregatesGroup.Enabled = False;
		Items.RebuildAndFillAggregates.Enabled = False;
		Items.GetOptimalAggregates.Enabled = False;
	EndIf;
	
	Items.Operations.PagesRepresentation = FormPagesRepresentation.None;
	
	SetAdvancedMode();
	
	CalculateTotalsFor = CurrentSessionDate();
	
	Items.PeriodSettingDescription.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.PeriodSettingDescription.Title,
		Format(EndOfPeriod(AddMonth(CalculateTotalsFor, -1)), "DLF=D"),
		Format(EndOfPeriod(CalculateTotalsFor), "DLF=D"));
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetAdvancedMode();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.TotalsAndAggregatesManagement.Form.PeriodChoiceForm") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		TotalsParameters = New Structure;
		TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Setting calculated totals period …';"));
		TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Setting of calculated totals period is complete';"));
		TotalsParameters.Insert("Action",               "SetTotalPeriod");
		TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
		TotalsParameters.Insert("Field",                   "TotalsPeriod");
		TotalsParameters.Insert("Value1",              ValueSelected.PeriodForAccumulationRegisters);
		TotalsParameters.Insert("Value2",              ValueSelected.PeriodForAccountingRegisters);
		TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot set the calculated totals period.';"));
		
		TotalsControl(TotalsParameters);
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.TotalsAndAggregatesManagement.Form.RebuildParametersForm") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		If ChoiceContext = "RebuildAggregates" Then
			
			RelativeSize = ValueSelected.RelativeSize;
			MinimumEffect   = ValueSelected.MinimumEffect;
			
			TotalsParameters = New Structure;
			TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Rebuilding aggregates …';"));
			TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Aggregates are rebuilt';"));
			TotalsParameters.Insert("Action",               "RebuildAggregates");
			TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
			TotalsParameters.Insert("Field",                   "Description");
			TotalsParameters.Insert("Value1",              ValueSelected.RelativeSize);
			TotalsParameters.Insert("Value2",              ValueSelected.MinimumEffect);
			TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot rebuild aggregates.';"));
			
			ChangeAggregatesClient(TotalsParameters);
			
		ElsIf ChoiceContext = "OptimalAggregates" Then
			
			OptimalRelativeSize = ValueSelected.RelativeSize;
			GetOptimalAggregatesClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HyperlinkWithTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	FullFunctionality = Not FullFunctionality;
	SetAdvancedMode();
	
EndProcedure

#EndRegion

#Region TotalsListFormTableItemEventHandlers

&AtClient
Procedure TotalsListOnActivateRow(Item)
	
	AttachIdleHandler("TotalsListOnActivateRowDeferred", 0.1, True);	
		
EndProcedure

&AtClient
Procedure TotalsListOnActivateRowDeferred()
	
	TotalsListOnActivateRowAtServer();	
	
EndProcedure

&AtServer
Procedure TotalsListOnActivateRowAtServer()
		
	SelectedRows = Items.TotalsList.SelectedRows;
	
	RegistersWithTotalsSelected = False;
	RegistersWithTotalsAndBalanceSelected = False;
	RegistersWithTotalsSplitSelected = False;
	
	For Each RowID In SelectedRows Do
		TableRow =  TotalsList.FindByID(RowID);
		If TableRow = Undefined Then
			Continue;
		EndIf;
		If TableRow.AggregatesTotals = 0 Or TableRow.AggregatesTotals = 2 Then
			RegistersWithTotalsSelected = True;
			If TableRow.BalanceAndTurnovers Then
				RegistersWithTotalsAndBalanceSelected = True;
			EndIf;
		EndIf;
		If TableRow.EnableTotalsSplitting Then
			RegistersWithTotalsSplitSelected = True;
		EndIf;
	EndDo;
	
	Items.Totals1Group.Enabled              = RegistersWithTotalsSelected;
	Items.CurrentTotalsGroup.Enabled       = RegistersWithTotalsAndBalanceSelected;
	Items.TotalsSplittingGroup.Enabled   = RegistersWithTotalsSplitSelected;
	Items.SetTotalPeriod.Enabled   = RegistersWithTotalsAndBalanceSelected;	
	
EndProcedure
	
&AtClient
Procedure TotalsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	NameOfMetadataObject = TotalsList.FindByID(RowSelected).NameOfMetadataObject;
	If Field.Name = "TotalsAggregatesTotals" Then
		
		StandardProcessing = False;
		
		ResultArray = AggregatesByRegisters.FindRows(
			New Structure("NameOfMetadataObject", NameOfMetadataObject));
		
		If ResultArray.Count() > 0 Then
			
			IndexOf = AggregatesByRegisters.IndexOf(ResultArray[0]);
			CurrentItem = Items.AggregatesByRegisters;
			Items.AggregatesByRegisters.CurrentRow = IndexOf;
			Items.AggregatesByRegisters.CurrentItem = Items.AggregatesByRegistersDescription;
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableTotalsUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enable totals usage…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling usage of totals is completed';"));
	TotalsParameters.Insert("Action",               "SetTotalsUsing");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "UseTotals");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable totals usage.';"));
	
	TotalsControl(TotalsParameters);

EndProcedure

&AtClient
Procedure EnableCurrentTotalsUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enabling usage of the current totals…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling usage of the current totals is completed';"));
	TotalsParameters.Insert("Action",               "UseCurrentTotals");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "UseCurrentTotals");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable usage of current subtotals.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure DisableTotalsUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Disable totals usage…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Disabling usage of totals is completed';"));
	TotalsParameters.Insert("Action",               "SetTotalsUsing");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "UseTotals");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot disable totals usage.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure DisableCurrentTotalsUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Disabling usage of the current totals …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Disabling usage of the current totals is completed';"));
	TotalsParameters.Insert("Action",               "UseCurrentTotals");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "UseCurrentTotals");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot disable usage of current subtotals.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure UpdateTotalState(Command)
	
	UpdateTotalsListAtServer();
	
EndProcedure

&AtClient
Procedure SetTotalPeriod(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("AccumulationReg",  False);
	FormParameters.Insert("AccountingReg", False);
	
	For Each IndexOf In Items.TotalsList.SelectedRows Do
		RegisterInformation1 = TotalsList.FindByID(IndexOf);
		FormParameters.AccumulationReg  = FormParameters.AccumulationReg  Or RegisterInformation1.Type = 0;
		FormParameters.AccountingReg = FormParameters.AccountingReg Or RegisterInformation1.Type = 1;
	EndDo;
	
	OpenForm("DataProcessor.TotalsAndAggregatesManagement.Form.PeriodChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EnableSplitTotals(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enable totals separation…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling of total separation is completed';"));
	TotalsParameters.Insert("Action",               "SetTotalsSeparation");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "TotalsSeparation");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable totals split.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure DisableTotalsSplitting(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Disable totals separation…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Disabling division of totals is completed';"));
	TotalsParameters.Insert("Action",               "SetTotalsSeparation");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "TotalsSeparation");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot disable totals split.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure UpdateAggregatesInformation(Command)
	
	UpdateAggregatesByRegistersAtServer();
	SetAggregatesListFilter();
	
EndProcedure

&AtClient
Procedure AggregatesByRegistersOnActivateRow(Item)
	
	SetAggregatesListFilter();
	
	If Item.CurrentData = Undefined Then
		ItemsAvailability = False;
		
	ElsIf Item.SelectionMode = TableSelectionMode.SingleRow Then
		ItemsAvailability = Item.CurrentData.AggregateMode;
	Else
		ItemsAvailability = True;
	EndIf;
	
	Items.AggregatesRebuildButton.Enabled                     = ItemsAvailability;
	Items.AggregatesClearAggregatesByRegistersButton.Enabled     = ItemsAvailability;
	Items.AggregatesFillAggregatesByRegistersButton.Enabled    = ItemsAvailability;
	Items.AggregatesOptimalButton.Enabled                     = ItemsAvailability;
	Items.AggregatesDisableAggregatesUsageButton.Enabled = ItemsAvailability;
	Items.AggregatesEnableAggregatesUsageButton.Enabled  = ItemsAvailability;
	
EndProcedure

&AtClient
Procedure EnableAggregateMode(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enable aggregate mode …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling of aggregate mode is completed';"));
	TotalsParameters.Insert("Action",               "SetAggregatesMode");
	TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalsParameters.Insert("Field",                   "AggregateMode");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable aggregate mode.';"));
	
	ChangeAggregatesClient(TotalsParameters);
	
EndProcedure

&AtClient
Procedure EnableTotalsMode(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enabling the totals mode…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling of the totals mode is completed';"));
	TotalsParameters.Insert("Action",               "SetAggregatesMode");
	TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalsParameters.Insert("Field",                   "AggregateMode");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable totals mode.';"));
	
	ChangeAggregatesClient(TotalsParameters);
	
EndProcedure

&AtClient
Procedure EnableAggregatesUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enable aggregate usage…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling of aggregate usage is completed';"));
	TotalsParameters.Insert("Action",               "SetAggregatesUsing");
	TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalsParameters.Insert("Field",                   "AgregateUsage");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable aggregate usage.';"));
	
	ChangeAggregatesClient(TotalsParameters);
	
EndProcedure

&AtClient
Procedure DisableAggregatesUsage(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Disable aggregate usage…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Disabling aggregation usage is completed';"));
	TotalsParameters.Insert("Action",               "SetAggregatesUsing");
	TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalsParameters.Insert("Field",                   "AgregateUsage");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot disable aggregate usage.';"));
	
	ChangeAggregatesClient(TotalsParameters);
	
EndProcedure

&AtClient
Procedure RebuildAggregates(Command)
	
	ChoiceContext = "RebuildAggregates";
	
	FormParameters = New Structure;
	FormParameters.Insert("RelativeSize", RelativeSize);
	FormParameters.Insert("MinimumEffect",   MinimumEffect);
	FormParameters.Insert("RebuildMode",   True);
	
	OpenForm("DataProcessor.TotalsAndAggregatesManagement.Form.RebuildParametersForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ClearAggregatesByRegisters(Command)
	
	QueryText = NStr("en = 'Aggregate cleanup may significantly slow down the reports.';");
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Clear aggregates';"));
	Buttons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("ClearAggregatesByRegistersCompletion", ThisObject);
	ShowQueryBox(Handler, QueryText, Buttons, , DialogReturnCode.Cancel);
	
EndProcedure

&AtClient
Procedure FillAggregatesByRegisters(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Populating aggregates…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Aggregates are populated';"));
	TotalsParameters.Insert("Action",               "FillAggregates");
	TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalsParameters.Insert("Field",                   "Description");
	TotalsParameters.Insert("Value1",              Undefined);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot fill in aggregates.';"));
	
	ChangeAggregatesClient(TotalsParameters);
	
EndProcedure

&AtClient
Procedure OptimalAggregates(Command)
	ChoiceContext = "OptimalAggregates";
	
	FormParameters = New Structure;
	FormParameters.Insert("RelativeSize", OptimalRelativeSize);
	FormParameters.Insert("MinimumEffect",   0);
	FormParameters.Insert("RebuildMode",   False);
	
	OpenForm("DataProcessor.TotalsAndAggregatesManagement.Form.RebuildParametersForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure SetTotalsPeriod(Command)
	
	ClearMessages();
	
	ActionsArray = TotalsList.FindRows(New Structure("BalanceAndTurnovers", True));
	
	If ActionsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform this action.';"));
		Return;
	EndIf;
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Setting calculated totals period …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Setting of calculated totals period is complete';"));
	TotalsParameters.Insert("Action",               "SetTotalPeriod");
	TotalsParameters.Insert("RowsArray",            ActionsArray);
	TotalsParameters.Insert("Field",                   "TotalsPeriod");
	TotalsParameters.Insert("Value1",              EndOfPeriod(AddMonth(CalculateTotalsFor, -1)) );
	TotalsParameters.Insert("Value2",              EndOfPeriod(CalculateTotalsFor) );
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot set the calculated totals period.';"));
	TotalsParameters.Insert("GroupProcessing",     True);
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure EnableTotalsUsageQuickAccess(Command)
	
	ClearMessages();
	
	ActionsArray = TotalsList.FindRows(New Structure("UseTotals", False));
	
	If ActionsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform this action.';"));
		Return;
	EndIf;
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Enable totals usage…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Enabling usage of totals is completed';"));
	TotalsParameters.Insert("Action",               "SetTotalsUsing");
	TotalsParameters.Insert("RowsArray",            ActionsArray);
	TotalsParameters.Insert("Field",                   "");
	TotalsParameters.Insert("Value1",              True);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot enable totals usage.';"));
	TotalsParameters.Insert("GroupProcessing",     True);
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure FillAggregatesAndPerformRebuild(Command)
	
	ClearMessages();
	
	ActionsArray = AggregatesByRegisters.FindRows(New Structure("AggregateMode,AgregateUsage", True, True));
	
	If ActionsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform the selected action for.';"));
		Return;
	EndIf;
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Rebuilding aggregates …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Aggregates are rebuilt';"));
	TotalsParameters.Insert("Action",               "RebuildAggregates");
	TotalsParameters.Insert("RowsArray",            ActionsArray);
	TotalsParameters.Insert("Field",                   "");
	TotalsParameters.Insert("Value1",              0);
	TotalsParameters.Insert("Value2",              0);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot rebuild aggregates.';"));
	TotalsParameters.Insert("GroupProcessing",     True);
	
	ChangeAggregatesClient(TotalsParameters, True);
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Populating aggregates…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Aggregates are populated';"));
	TotalsParameters.Insert("Action",               "FillAggregates");
	TotalsParameters.Insert("RowsArray",            ActionsArray);
	TotalsParameters.Insert("Field",                   "");
	TotalsParameters.Insert("Value1",              Undefined);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot fill in aggregates.';"));
	
	ChangeAggregatesClient(TotalsParameters, False);
	
EndProcedure

&AtClient
Procedure GetOptimalAggregates(Command)
	GetOptimalAggregatesClient();
EndProcedure

&AtClient
Procedure RecalcTotals(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Recalculating totals …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Totals are recalculated.';"));
	TotalsParameters.Insert("Action",               "RecalcTotals");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "Description");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot recalculate totals.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure RecalcPresentTotals(Command)
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Recalculating the current totals …';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Current totals recalculation completed.';"));
	TotalsParameters.Insert("Action",               "RecalcPresentTotals");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "Description");
	TotalsParameters.Insert("Value1",              False);
	TotalsParameters.Insert("Value2",              Undefined);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot recalculate current totals.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

&AtClient
Procedure RecalcTotalsForPeriod(Command)
	Handler = New NotifyDescription("RecalcTotalsForPeriodCompletion", ThisObject);
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = RegistersRecalculationPeriod;
	Dialog.Show(Handler);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Totals';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 1;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Aggregates';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 2;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Just total register';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsUseCurrentTotals.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsTotalsPeriod.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsTotalsSplitting.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.BalanceAndTurnovers");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 2;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsUseTotals.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 1;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ClearAggregatesByRegistersCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		TotalsParameters = New Structure;
		TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Clearing aggregates …';"));
		TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Aggregates are cleared';"));
		TotalsParameters.Insert("Action",               "ClearAggregates");
		TotalsParameters.Insert("RowsArray",            Items.AggregatesByRegisters.SelectedRows);
		TotalsParameters.Insert("Field",                   "Description");
		TotalsParameters.Insert("Value1",              Undefined);
		TotalsParameters.Insert("Value2",              Undefined);
		TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot clear aggregates.';"));
		
		ChangeAggregatesClient(TotalsParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalcTotalsForPeriodCompletion(ValueSelected, AdditionalParameters) Export
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	RegistersRecalculationPeriod = ValueSelected;
	
	TotalsParameters = New Structure;
	TotalsParameters.Insert("ProcessTitle",  NStr("en = 'Recalculating totals for the period…';"));
	TotalsParameters.Insert("AfterProcess1",          NStr("en = 'Totals recalculation for the period completed.';"));
	TotalsParameters.Insert("Action",               "RecalcTotalsForPeriod");
	TotalsParameters.Insert("RowsArray",            Items.TotalsList.SelectedRows);
	TotalsParameters.Insert("Field",                   "Description");
	TotalsParameters.Insert("Value1",              RegistersRecalculationPeriod.StartDate);
	TotalsParameters.Insert("Value2",              RegistersRecalculationPeriod.EndDate);
	TotalsParameters.Insert("ErrorMessageText", NStr("en = 'Cannot recalculate totals for the period.';"));
	
	TotalsControl(TotalsParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure SetAggregatesListFilter()
	
	CurrentData = Items.AggregatesByRegisters.CurrentData;
	
	If CurrentData <> Undefined Then
		Filter = New FixedStructure("NameOfMetadataObject", CurrentData.NameOfMetadataObject);
		NewTitle = Prefix() +  " " + CurrentData.Description;
	Else
		Filter = New FixedStructure("NameOfMetadataObject", "");
		NewTitle = Prefix();
	EndIf;
	
	Items.AggregatesList.RowFilter = Filter;
	
	If Items.AggregatesList.Title <> NewTitle Then
		Items.AggregatesList.Title = NewTitle;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeAggregatesClient(Val TotalsParameters, Val ClearMessages = True)
	
	Result = True;
	If ClearMessages Then
		ClearMessages();
	EndIf;
	SelectedItems = TotalsParameters.RowsArray;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	ProcessStep = 100/SelectedItems.Count();
	
	If TotalsParameters.Property("GroupProcessing") Then
		NeedAbortAfterError = ?(TotalsParameters.GroupProcessing, False, InterruptOnError);
	Else
		NeedAbortAfterError = InterruptOnError;
	EndIf;
	
	For Counter = 1 To SelectedItems.Count() Do
		If TypeOf(SelectedItems[Counter - 1]) = Type("Number") Then
			RowSelected = AggregatesByRegisters.FindByID(SelectedItems[Counter-1]);
		Else
			RowSelected = SelectedItems[Counter-1];
		EndIf;
		
		AfterErrorMessage = "";
		If Not IsBlankString(TotalsParameters.Field) Then
			AfterErrorMessage = "AggregatesByRegisters[" + Format(SelectedItems[Counter-1], "NG=0") + "]." + TotalsParameters.Field;
		EndIf;
		
		If Not RowSelected.AggregateMode
			And Upper(TotalsParameters.Action) <> Upper("SetAggregatesMode") Then
			CommonClient.MessageToUser(
				NStr("en = 'The operation is not allowed in the totals mode';"),
				,
				AfterErrorMessage);
			Continue;
		EndIf;
		
		Status(TotalsParameters.ProcessTitle, Counter * ProcessStep, RowSelected.Description);
		
		ServerParameters = New Structure;
		ServerParameters.Insert("RegisterName",        RowSelected.NameOfMetadataObject);
		ServerParameters.Insert("Action",           TotalsParameters.Action);
		ServerParameters.Insert("ActionValue1",  TotalsParameters.Value1);
		ServerParameters.Insert("ActionValue2",  TotalsParameters.Value2);
		ServerParameters.Insert("ErrorMessage",  TotalsParameters.ErrorMessageText);
		ServerParameters.Insert("FormField",          AfterErrorMessage);
		ServerParameters.Insert("FormIdentifier", UUID);
		Result = ChangeAggregatesServer(ServerParameters);
		
		UserInterruptProcessing();
		
		If Not Result.Success And NeedAbortAfterError Then
			Break;
		EndIf;
		
	EndDo;
	
	If Upper(TotalsParameters.Action) = Upper("SetAggregatesMode")
		Or Upper(TotalsParameters.Action) = Upper("SetAggregatesUsing") Then
		UpdateTotalsListAtServer();
	EndIf;
	
	UpdateAggregatesByRegistersAtServer();
	
	Status(TotalsParameters.AfterProcess1);
	SetAggregatesListFilter();
	
EndProcedure

&AtClient
Procedure TotalsControl(Val TotalsParameters)
	
	Result = True;
	ClearMessages();
	
	SelectedItems = TotalsParameters.RowsArray;
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	ProcessStep = 100/SelectedItems.Count();
	Action = Lower(TotalsParameters.Action);
	
	If TotalsParameters.Property("GroupProcessing") Then
		NeedAbortAfterError = ?(TotalsParameters.GroupProcessing, False, InterruptOnError);
	Else
		NeedAbortAfterError = InterruptOnError;
	EndIf;
	
	ProcessedRowsCount = 0;
	HasRegistersToProcess    = False;
	
	For Counter = 1 To SelectedItems.Count() Do
		If TypeOf(SelectedItems[Counter-1]) = Type("Number") Then
			RowSelected = TotalsList.FindByID(SelectedItems[Counter-1]);
		Else
			RowSelected = SelectedItems[Counter-1];
		EndIf;
		
		Status(TotalsParameters.ProcessTitle, Counter * ProcessStep, RowSelected.Description);
		
		If Upper(Action) = Upper("SetTotalsUsing") Then
			If RowSelected.AggregatesTotals = 1 Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("UseCurrentTotals") Then
			If RowSelected.AggregatesTotals = 1 Or Not RowSelected.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("SetTotalPeriod") Then
			If RowSelected.AggregatesTotals = 1 Or Not RowSelected.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("SetTotalsSeparation") Then
			If Not RowSelected.EnableTotalsSplitting Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcTotals") Then
			If RowSelected.AggregatesTotals = 1 Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcTotalsForPeriod") Then
			If RowSelected.AggregatesTotals = 1 Or Not RowSelected.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcPresentTotals") Then
			If Not RowSelected.BalanceAndTurnovers Then
				Continue;
			EndIf;
		EndIf;
		
		AfterErrorMessage = "";
		If Not IsBlankString(TotalsParameters.Field) Then
			AfterErrorMessage = "TotalsList[" + Format(SelectedItems[Counter-1], "NG=0") + "]." + TotalsParameters.Field;
		EndIf;
		
		HasRegistersToProcess = True;
		
		Result = SetRegisterParametersAtServer(
			RowSelected.Type,
			RowSelected.NameOfMetadataObject,
			TotalsParameters.Action,
			TotalsParameters.Value1,
			TotalsParameters.Value2,
			AfterErrorMessage,
			TotalsParameters.ErrorMessageText);
		
		UserInterruptProcessing();
		
		If Not Result And NeedAbortAfterError Then
			Break;
		EndIf;
		
		If Result Then
			ProcessedRowsCount = ProcessedRowsCount + 1;
		EndIf;
	EndDo;
	
	If Not HasRegistersToProcess Then
		ShowMessageBox(, NStr("en = 'No registers to perform this action.';"));
		Return;
	EndIf;
	
	UpdateTotalsListAtServer();
	
	StateText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Recalculated (%1 of %2)';"),
		ProcessedRowsCount,
		SelectedItems.Count());
	
	Status(TotalsParameters.AfterProcess1 + Chars.LF + StateText);
	
EndProcedure

&AtClient
Procedure GetOptimalAggregatesClient()
	
	If FullFunctionality Then
		If Items.AggregatesByRegisters.SelectedRows.Count() = 0 Then
			Return;
		EndIf;
	Else
		If AggregatesByRegisters.Count() = 0 Then
			ShowMessageBox(, NStr("en = 'No registers to perform this action.';"));
			Return;
		EndIf;
	EndIf;
	
	Result = GetOptimalAggregatesServer();
	Handler = New NotifyDescription("GetOptimalAggregatesClientCompletion", ThisObject, Result);
	If Not Result.CanGet Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Save optimal aggregates to file';");
	Extension = Lower(Mid(Result.FileName, StrFind(Result.FileName, ".") + 1));
	If Extension = "zip" Then
		Filter = NStr("en = 'Aggregate setting files (*.zip)|*.zip';");
	ElsIf Extension = "xml" Then
		Filter = NStr("en = 'Aggregate setting files (*.xml)|*.xml';");
	Else
		Filter = "";
	EndIf;
	SavingParameters.Dialog.Filter = Filter;
	SavingParameters.Dialog.FullFileName = Result.FileName;
	FileSystemClient.SaveFile(Handler, Result.FileAddress, Result.FileName, SavingParameters);
	
EndProcedure

&AtClient
Procedure GetOptimalAggregatesClientCompletion(ObtainedFiles, ExecutionResult) Export
	
	If ObtainedFiles = Undefined Then
		Return;
	EndIf;
	
	If ExecutionResult.HasErrors Then
		Raise ExecutionResult.MessageText;
	EndIf;
	ShowUserNotification(NStr("en = 'Aggregates are received successfully.';"),,
		 ExecutionResult.MessageText, PictureLib.Success32);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClientAtServerNoContext
Function EndOfPeriod(Val Date)
	
	Return EndOfDay(EndOfMonth(Date));
	
EndFunction

&AtClientAtServerNoContext
Function Prefix()
	
	Return NStr("en = 'Register aggregates';");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Function GetOptimalAggregatesServer()
	
	Result = New Structure;
	Result.Insert("CanGet", False);
	Result.Insert("FileAddress", "");
	Result.Insert("FileName", "");
	Result.Insert("HasErrors", False);
	Result.Insert("MessageText", "");
	
	If FullFunctionality Then
		Collection = SelectedRows("AggregatesByRegisters");
		MaximumRelativeSize = OptimalRelativeSize;
	Else
		Collection = AggregatesByRegisters;
		MaximumRelativeSize = 0;
	EndIf;
	Total = Collection.Count();
	Success = 0;
	DetailedErrorText1 = "";
	
	TempFilesDir = CommonClientServer.AddLastPathSeparator(
		GetTempFileName(".TAM")); // Totals & Aggregates Management.
	CreateDirectory(TempFilesDir);
	
	FilesToArchive = New ValueList;
	
	// Get aggregates.
	For LineNumber = 1 To Total Do
		
		AccumulationRegisterName = Collection[LineNumber - 1].NameOfMetadataObject;
		
		RegisterManager = AccumulationRegisters[AccumulationRegisterName];
		Try
			OptimalAggregates1 = RegisterManager.DetermineOptimalAggregates(MaximumRelativeSize);
		Except
			Result.HasErrors = True;
			DetailedErrorText1 = DetailedErrorText1
				+ ?(IsBlankString(DetailedErrorText1), "", Chars.LF + Chars.LF)
				+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1: %2';"), AccumulationRegisterName, 
					ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			Continue;
		EndTry;
		
		FullFileName = TempFilesDir + AccumulationRegisterName + ".xml";
		
		XMLWriter = New XMLWriter();
		XMLWriter.OpenFile(FullFileName);
		XMLWriter.WriteXMLDeclaration();
		XDTOSerializer.WriteXML(XMLWriter, OptimalAggregates1);
		XMLWriter.Close();
		
		FilesToArchive.Add(FullFileName, AccumulationRegisterName);
		Success = Success + 1;
		
	EndDo;
	
	// Preparing result to be passed to client.
	If Success > 0 Then
		
		If Success = 1 Then
			ListItem = FilesToArchive[0];
			FullFileName = ListItem.Value;
			ShortFileName = ListItem.Presentation + ".xml";
		Else
			ShortFileName = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Optimal aggregates of accumulation register %1.zip';"),
				Format(CurrentSessionDate(), "DF=yyyy-MM-dd"));
			FullFileName = TempFilesDir + ShortFileName;
			SaveMode = ZIPStorePathMode.StoreRelativePath;
			ProcessingMode = ZIPSubDirProcessingMode.ProcessRecursively;
			ZipFileWriter = New ZipFileWriter(FullFileName);
			For Each ListItem In FilesToArchive Do
				ZipFileWriter.Add(ListItem.Value, SaveMode, ProcessingMode);
			EndDo;
			ZipFileWriter.Write();
		EndIf;
		BinaryData = New BinaryData(FullFileName);
		Result.CanGet = True;
		Result.FileName      = ShortFileName;
		Result.FileAddress    = PutToTempStorage(BinaryData, UUID);
		
	EndIf;
	
	// Clean up garbage.
	DeleteFiles(TempFilesDir);
	
	// Prepare message texts.
	If Total = 1 Then
		
		// 
		ListItem = Collection[0];
		RegisterName = ListItem.Description;
		If Result.HasErrors Then
			Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot receive optimal aggregates of the ""%1"" accumulation register due to:
					|%2';"), RegisterName, DetailedErrorText1);
		Else
			Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (accumulation register)';"),	RegisterName);
		EndIf;
		
	ElsIf Success = 0 Then
		
		// 
		Result.HasErrors = True;
		Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot receive ideal aggregates of accumulation registers due to:
			|%1';"), DetailedErrorText1);
		
	ElsIf Result.HasErrors Then
		
		// 
		Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Aggregates are successfully received for %1 of %2 registers.
				|Not received for %3 due to:
				|%4';"),
				Success,
				Total,
				Total - Success,
				DetailedErrorText1);
		
	Else
		
		// 
		Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Accumulation registers (%1)';"), Success);
			
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure UpdateTotalsListAtServer()
	
	Managers = New Array;
	Managers.Add(AccumulationRegisters);
	Managers.Add(AccountingRegisters);
	
	For Each TableRow In TotalsList Do
		
		Register = Managers[TableRow.Type][TableRow.NameOfMetadataObject];
		
		TableRow.UseTotals = Register.GetTotalsUsing();
		TableRow.TotalsSeparation  = Register.GetTotalsSplittingMode();
		
		If TableRow.BalanceAndTurnovers Then
			
			TableRow.UseCurrentTotals = Register.GetPresentTotalsUsing();
			TableRow.TotalsPeriod             = Register.GetMaxTotalsPeriod();
			TableRow.AggregatesTotals            = 2;
			
		Else
			
			TableRow.UseCurrentTotals = False;
			TableRow.TotalsPeriod             = Undefined;
			TableRow.AggregatesTotals            = Register.GetAggregatesMode();
			
			If TableRow.AggregatesTotals Then
				TableRow.UseTotals = False;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TotalsGroupTitle = NStr("en = 'Totals';");
	TotalsCount = TotalsList.Count();
	If TotalsCount > 0 Then
		TotalsGroupTitle = TotalsGroupTitle + " (" + Format(TotalsCount, "NG=") + ")";
	EndIf;
	
	Items.TotalsGroup.Title = TotalsGroupTitle;
	
EndProcedure

&AtServer
Procedure UpdateAggregatesByRegistersAtServer()
	
	RegisterAggregatesList.Clear();
	
	For Each TableRow In AggregatesByRegisters Do
		
		RegisterManager = AccumulationRegisters[TableRow.NameOfMetadataObject];
		
		TableRow.AggregateMode         = RegisterManager.GetAggregatesMode();
		TableRow.AgregateUsage = RegisterManager.GetAggregatesUsing();

		Aggregates = RegisterManager.GetAggregates();
		TableRow.BuildDate     = Aggregates.BuildDate;
		TableRow.Size             = Aggregates.Size;
		TableRow.SizeLimit = Aggregates.SizeLimit;
		TableRow.Effect             = Aggregates.Effect;
		
		For Each Aggregate In Aggregates.Aggregates Do // AggregateInformation
			
			DimensionsSynonyms = New Array;
			For Each DimensionName In Aggregate.Dimensions Do
				DimensionSynonym = Metadata.AccumulationRegisters[TableRow.NameOfMetadataObject].Dimensions[DimensionName].Synonym;
				DimensionsSynonyms.Add(DimensionSynonym);
			EndDo;
			
			RegisterAggregatesRow = RegisterAggregatesList.Add();
			RegisterAggregatesRow.NameOfMetadataObject = TableRow.NameOfMetadataObject;
			RegisterAggregatesRow.Periodicity  = String(Aggregate.Periodicity);
			RegisterAggregatesRow.Dimensions      = StrConcat(DimensionsSynonyms, ", ");
			RegisterAggregatesRow.Use  = Aggregate.Use;
			RegisterAggregatesRow.BeginOfPeriod  = Aggregate.BeginOfPeriod;
			RegisterAggregatesRow.EndOfPeriod   = Aggregate.EndOfPeriod;
			RegisterAggregatesRow.Size         = Aggregate.Size;
			
		EndDo;
	EndDo;
	
	RegisterAggregatesList.Sort("Use Desc");
	
	AggregatesGroupTitle = NStr("en = 'Aggregates';");
	AggregatesCount = AggregatesByRegisters.Count();
	If AggregatesCount > 0 Then
		AggregatesGroupTitle = AggregatesGroupTitle + " (" + Format(AggregatesCount, "NG=") + ")";
	EndIf;
	
	Items.AggregatesGroup.Title = AggregatesGroupTitle;
	
EndProcedure

&AtServerNoContext
Function SetRegisterParametersAtServer(Val RegisterType,
                                             Val RegisterName,
                                             Val Action,
                                             Val Value1,
                                             Val Value2, // 
                                             Val ErrorField,
                                             Val ErrorMessage)
	
	Managers = New Array;
	Managers.Add(AccumulationRegisters);
	Managers.Add(AccountingRegisters);
	
	Manager = Managers[RegisterType][RegisterName];
	Action = Lower(Action);
	
	Try
		
		If Upper(Action) = Upper("SetTotalsUsing") Then
			Manager.SetTotalsUsing(Value1);
			
		ElsIf Upper(Action) = Upper("UseCurrentTotals") Then
			Manager.SetPresentTotalsUsing(Value1);
			
		ElsIf Upper(Action) = Upper("SetTotalsSeparation") Then
			Manager.SetTotalsSplittingMode(Value1);
			
		ElsIf Upper(Action) = Upper("SetTotalPeriod") Then
			
			If RegisterType = 0 Then
				Date = Value1;
				
			ElsIf RegisterType = 1 Then
				Date = Value2;
			EndIf;
			
			Manager.SetMaxTotalsPeriod(Date);
			
		ElsIf Upper(Action) = Upper("RecalcTotals") Then
			Manager.RecalcTotals();
			
		ElsIf Upper(Action) = Upper("RecalcPresentTotals") Then
			Manager.RecalcPresentTotals();
			
		ElsIf Upper(Action) = Upper("RecalcTotalsForPeriod") Then
			Manager.RecalcTotalsForPeriod(Value1, Value2);
			
		Else
			Raise NStr("en = 'Incorrect partner name';") + "(1): " + Action;
		EndIf;
		
	Except
		
		Common.MessageToUser(
			ErrorMessage
			+ Chars.LF
			+ ErrorProcessing.BriefErrorDescription(ErrorInfo()),
			,
			ErrorField);
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function ChangeAggregatesServer(Val ServerParameters)
	
	Result = New Structure;
	Result.Insert("Success", True);
	Result.Insert("ActionValue1", ServerParameters.ActionValue1);
	Result.Insert("FileAddressInTempStorage", "");
	
	RegisterManager = AccumulationRegisters[ServerParameters.RegisterName];
	
	Try
		
		If Upper(ServerParameters.Action) = Upper("SetAggregatesMode") Then
			RegisterManager.SetAggregatesMode(ServerParameters.ActionValue1);
			
		ElsIf Upper(ServerParameters.Action) = Upper("SetAggregatesUsing") Then
			RegisterManager.SetAggregatesUsing(ServerParameters.ActionValue1);
			
		ElsIf Upper(ServerParameters.Action) = Upper("FillAggregates") Then
			RegisterManager.UpdateAggregates(False);
			
		ElsIf Upper(ServerParameters.Action) = Upper("RebuildAggregates") Then
			RegisterManager.RebuildAggregatesUsing(ServerParameters.ActionValue1, ServerParameters.ActionValue2);
			
		ElsIf Upper(ServerParameters.Action) = Upper("ClearAggregates") Then
			RegisterManager.ClearAggregates();
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Incorrect name of parameter: %1';"),
				ServerParameters.Action);
		EndIf;
		
	Except
		
		ErrorMessage = ServerParameters.ErrorMessage + " (" + ErrorProcessing.BriefErrorDescription(ErrorInfo()) + ")";
		Common.MessageToUser(ErrorMessage);
		Result.Success = False;
		
	EndTry;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetAdvancedMode()
	
	If FullFunctionality Then
		Title        = NStr("en = 'Totals management - full functionality';");
		HyperlinkText = NStr("en = 'Frequently used features';");
		Items.Operations.CurrentPage = Items.AdvancedFeatures;
	Else
		Title        = NStr("en = 'Totals management - frequently used features';");
		HyperlinkText = NStr("en = 'Full functionality';");
		Items.Operations.CurrentPage = Items.QuickAccess;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SelectedRows(TableName)
	
	Result = New Array;
	SelectedRows = Items[TableName].SelectedRows;
	Table = ThisObject[TableName];
	For Each Id In SelectedRows Do
		Result.Add(Table.FindByID(Id));
	EndDo;
	Return Result;
	
EndFunction

&AtServer
Procedure ReadInformationOnRegisters()
	
	TotalsList.Clear();
	AggregatesByRegisters.Clear();
	RegisterAggregatesList.Clear();
	
	Picture = PictureLib.AccountingRegister;
	For Each Register In Metadata.AccountingRegisters Do
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation() + " (" + NStr("en = 'accounting register';") + ")";
		
		TableRow = TotalsList.Add();
		TableRow.Type                       = 1;
		TableRow.NameOfMetadataObject            = Register.Name;
		TableRow.Picture                  = Picture;
		TableRow.BalanceAndTurnovers           = True;
		TableRow.Description              = Presentation;
		TableRow.EnableTotalsSplitting = Register.EnableTotalsSplitting;
		
	EndDo;
	
	Picture = PictureLib.AccumulationRegister;
	For Each Register In Metadata.AccumulationRegisters Do
		
		Postfix = "";
		If Register.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Turnovers Then
			BalanceAndTurnovers = False;
			Postfix = NStr("en = 'accumulation register, turnovers only';");
		Else
			BalanceAndTurnovers = True;
			Postfix = NStr("en = 'accumulation register, balance and turnovers';");
		EndIf;
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation() + " (" + Postfix + ")";
		
		TableRow = TotalsList.Add();
		TableRow.Type                       = 0;
		TableRow.NameOfMetadataObject            = Register.Name;
		TableRow.Picture                  = Picture;
		TableRow.BalanceAndTurnovers           = BalanceAndTurnovers;
		TableRow.Description              = Presentation;
		TableRow.EnableTotalsSplitting = Register.EnableTotalsSplitting ;
		
	EndDo;
	
	Picture = PictureLib.AccumulationRegister;
	For Each Register In Metadata.AccumulationRegisters Do
		
		If Register.RegisterType <> Metadata.ObjectProperties.AccumulationRegisterType.Turnovers Then
			Continue;
		EndIf;
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation();
		Aggregates = Register.Aggregates;
		If Aggregates.Count() = 0 Then
			Continue;
		EndIf;
		
		TableRow = AggregatesByRegisters.Add();
		TableRow.NameOfMetadataObject       = Register.Name;
		TableRow.Picture             = Picture;
		TableRow.Description         = Presentation;
		TableRow.CompositionIsOptimal = True;
		
	EndDo;
	
	TotalsList.Sort("Description Asc");
	AggregatesByRegisters.Sort("Description Asc");
	
EndProcedure

#EndRegion
