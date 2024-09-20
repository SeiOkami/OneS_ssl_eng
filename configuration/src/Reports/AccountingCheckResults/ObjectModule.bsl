///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.SelectAndEditOptionsWithoutSavingAllowed = True;
	Settings.HideBulkEmailCommands                              = True;
	Settings.GenerateImmediately                                   = True;
	
	Settings.Events.OnCreateAtServer               = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.BeforeLoadVariantAtServer    = True;
	
EndProcedure

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   Cancel - Boolean - passed from the OnCreateAtServer standard handler parameters "as it is".
//   StandardProcessing - Boolean - passed from the OnCreateAtServer standard handler parameters "as it is".
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	FormParameters = Form.Parameters;
	If FormParameters.Property("ObjectReference") Then
		
		ProcedureName = "AccountingAuditClient.OpenObjectIssuesReport";
		CommonClientServer.CheckParameter(ProcedureName, "Form", Form, Type("ClientApplicationForm"));
		CommonClientServer.CheckParameter(ProcedureName, "ObjectWithIssue", FormParameters.ObjectReference, Common.AllRefsTypeDetails());
		CommonClientServer.CheckParameter(ProcedureName, "StandardProcessing", StandardProcessing, Type("Boolean"));
		
		DataParametersStructure = New Structure("Context", FormParameters.ObjectReference);
		SetDataParameters(SettingsComposer.Settings, DataParametersStructure);
		
	ElsIf FormParameters.Property("ContextData") Then
		
		If TypeOf(FormParameters.ContextData) = Type("Structure") Then
			
			ContextData  = FormParameters.ContextData;
			SelectedRows = ContextData.SelectedRows;
			
			If SelectedRows.Count() > 0 Then
				
				ObjectsWithIssues = AccountingAuditInternal.ObjectsWithIssues(ContextData.SelectedRows);
				
				If ObjectsWithIssues.Count() = 0 Then
					Cancel = True;
				Else
					
					ProblemObjectsList = New ValueList;
					ProblemObjectsList.LoadValues(ObjectsWithIssues);
					
					DataParametersStructure = New Structure("Context", ProblemObjectsList);
					SetDataParameters(SettingsComposer.Settings, DataParametersStructure);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	ElsIf FormParameters.Property("ReferencesArrray") Then
		
		ReferencesArrray = FormParameters.ReferencesArrray;
		If ReferencesArrray.Count() > 0 Then
			
			ProblemObjectsList = New ValueList;
			ProblemObjectsList.LoadValues(ReferencesArrray);
			
			DataParametersStructure = New Structure("Context", ProblemObjectsList);
			SetDataParameters(SettingsComposer.Settings, DataParametersStructure);
			
		EndIf;
		
	ElsIf FormParameters.Property("CheckKind") Then
		
		CommonClientServer.CheckParameter("AccountingAuditClient.OpenIssuesReport", "CheckKind", 
			FormParameters.CheckKind, AccountingAuditInternal.TypeDetailsCheckKind());
		
		DetailedInformationOnChecksKinds = AccountingAudit.DetailedInformationOnChecksKinds(FormParameters.CheckKind);
		If DetailedInformationOnChecksKinds.Count() = 0 Then
			Cancel = True;
		Else
			SettingsComposer.Settings.AdditionalProperties.Insert("IssuesList", PrepareChecksList(CommonClientServer.CollapseArray(
				DetailedInformationOnChecksKinds.UnloadColumn("CheckRule"))));
		EndIf;
		
	ElsIf FormParameters.Property("CommandParameter") Then
		
		If TypeOf(FormParameters.CommandParameter) = Type("Array") And FormParameters.CommandParameter.Count() > 0 Then
			SettingsComposer.Settings.AdditionalProperties.Insert("IssuesList", PrepareChecksList(FormParameters.CommandParameter));
		EndIf;
		
	EndIf;
	
	If Not SettingsComposer.Settings.AdditionalProperties.Property("IssuesList") Then
		SettingsComposer.Settings.AdditionalProperties.Insert("IssuesList", New ValueList);
	EndIf;
	
	// Adding commands to the command bar.
	If Users.IsFullUser() Then
		If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
			Command = ModuleObjectsVersioning.ChangeHistoryCommand(Form);
			If Command <> Undefined Then
				ReportsServer.OutputCommand(Form, Command, "Settings");
			EndIf;
		EndIf;
		
		Command = Form.Commands.Add("AccountingAuditIgnoreIssue");
		Command.Action  = "Attachable_Command";
		Command.Title = NStr("en = 'Ignore issue';");
		Command.ToolTip = NStr("en = 'Ignore the selected issue';");
		Command.Picture  = PictureLib.Close;
		ReportsServer.OutputCommand(Form, Command, "Settings");
	EndIf;
	
EndProcedure

// 
//
// Parameters:
//   Context - Arbitrary
//   SchemaKey - String
//   VariantKey - String
//                - Undefined
//   NewDCSettings - DataCompositionSettings
//                    - Undefined
//   NewDCUserSettings - DataCompositionUserSettings
//                                    - Undefined
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, VariantKey, NewDCSettings, NewDCUserSettings) Export
	
	ParameterOutputResponsibleEmployee = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("OutputResponsibleEmployee"));
	If ParameterOutputResponsibleEmployee <> Undefined And NewDCUserSettings <> Undefined Then
		Setting = NewDCUserSettings.Items.Find(ParameterOutputResponsibleEmployee.UserSettingID);
		If Setting <> Undefined Then
			HideGroupByResponsiblePersons(NewDCSettings, Setting);
		EndIf;
	EndIf;
	
	AdditionalProperties = SettingsComposer.Settings.AdditionalProperties;
	If AdditionalProperties.Property("IssuesList") Then
		SetFilterByIssuesList(NewDCSettings.Filter, NewDCUserSettings, AdditionalProperties.IssuesList);
		AdditionalProperties.Delete("IssuesList");
		NewDCSettings.AdditionalProperties.Delete("IssuesList");
	EndIf;
	
	If SchemaKey <> "1" Then
		SchemaKey = "1";
		ReportsServer.AttachSchema(ThisObject, Context, DataCompositionSchema, SchemaKey);
	EndIf;
	
EndProcedure

// This procedure is called in the OnLoadVariantAtServer event handler of a report form after executing the form code.
// For more detailed description go to the syntax assistant, namely, to the extension section
// of the report managed form.
//
// Parameters:
//   Form - ClientApplicationForm - a report form.
//   NewDCSettings - DataCompositionSettings - settings to load into the settings composer.
//
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	DSCParameter         = New DataCompositionParameter("Context");
	DSCParameterContext = SettingsComposer.Settings.DataParameters.Items.Find(DSCParameter);
	
	For Each Filter In NewDCSettings.Filter.Items Do
		If Filter.LeftValue <> New DataCompositionField("EmployeeResponsible") Then
			Continue;
		EndIf;
		
		RightFilterValue = Filter.RightValue;// ValueList 
		RightFilterValue.Add(Users.CurrentUser());
		RightFilterValue.Add(Catalogs.Users.EmptyRef());
		Filter.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
		If Users.IsFullUser() Then
			Filter.UserSettingID = New UUID;
		EndIf;
	EndDo;
	
	If DSCParameterContext <> Undefined Then
		Context = DSCParameterContext.Value;
	EndIf;
	
	If ValueIsFilled(Context) Then
		SetDataParameters(NewDCSettings, New Structure("Context", Context));
	EndIf;
	
	SetParametersValues(NewDCSettings);
	
	AdditionalProperties = SettingsComposer.Settings.AdditionalProperties;
	If AdditionalProperties.Property("IssuesList") Then
		NewDCSettings.AdditionalProperties.Insert("IssuesList", SettingsComposer.Settings.AdditionalProperties.IssuesList);
	EndIf;
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks();
	
	SettingsComposer.Settings.DataParameters.SetParameterValue("LastCheckInformation", LastCheckTooltip());
	
	DCSettings = SettingsComposer.GetSettings();
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate   = TemplateComposer.Execute(DataCompositionSchema, DCSettings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, New Structure("ExternalTable", AccountingChecks.Checks), DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
	
	CompleteReadyTemplate(ResultDocument, ReportStructureNotChanged());
	
EndProcedure

#EndRegion

#Region Private

Function LastCheckTooltip()
	
	LastCheckInformation = AccountingAuditInternal.LastAccountingCheckInformation();
	If ValueIsFilled(LastCheckInformation.LastCheckDate) Then
		ToolTip = NStr("en = 'was performed earlier %1.';");
		ToolTip = StringFunctionsClientServer.SubstituteParametersToString(ToolTip, 
			Format(LastCheckInformation.LastCheckDate, "DLF=D"));
	Else
		ToolTip = NStr("en = 'has not been performed yet.';");
	EndIf;
	If LastCheckInformation.WarnSecondCheckRequired Then
		ToolTip = " " + NStr("en = 'It is recommended that you perform a check to view the relevant results.';");
	EndIf;
		
	Return ToolTip;
	
EndFunction

Procedure CompleteReadyTemplate(ResultDocument, ReportStructureNotChanged)
	
	CompleteHeader(ResultDocument, ReportStructureNotChanged);
	RedefineShowTotals(ResultDocument, ReportStructureNotChanged);
	EnterDecisionsHyperlinks(ResultDocument);
	
EndProcedure

Procedure CompleteHeader(ResultDocument, ReportStructureNotChanged)
	
	TheSearchKeyIsLocalized = "[TheTitleIsHidden]";
	TheSearchKeyIsNotLocalized = "[ЗаголовокСкрыт]"; // @Non-NLS
	If ReportStructureNotChanged Then
		
		FirstRow    = 0;
		LastRow = 0;
		
		TableHeight = ResultDocument.TableHeight;
		
		For RowsIndex = 1 To TableHeight Do
			
			AreaName = "R" + Format(RowsIndex, "NG=0");
			Area    = ResultDocument.Area(AreaName);
			
			If StrFind(Area.Text, TheSearchKeyIsLocalized) <> 0
				Or StrFind(Area.Text, TheSearchKeyIsNotLocalized) <> 0 Then
				If FirstRow = 0 Then
					FirstRow = RowsIndex;
				EndIf;
				LastRow = LastRow + 1;
			EndIf;
			
		EndDo;
		
		If FirstRow = 0 And LastRow = 0 Then
			Return;
		EndIf;
		
		ResultDocument.DeleteArea(ResultDocument.Area("R" + Format(FirstRow, "NG=0") + ":R" + Format(FirstRow + LastRow - 1, "NG=0")),
			SpreadsheetDocumentShiftType.Vertical);
		
		ResultDocument.FixedTop = 0;
		ResultDocument.FixedLeft  = 0;
		
	Else
		
		TableWidth = ResultDocument.TableWidth;
		TableHeight = ResultDocument.TableHeight;
		
		For RowsIndex = 1 To TableHeight Do
		
			For ColumnsIndex = 1 To TableWidth Do
			
				AreaName = "R" + Format(RowsIndex, "NG=0") + "C" + Format(ColumnsIndex, "NG=0");
				Area    = ResultDocument.Area(AreaName);
				
				If StrFind(Area.Text, TheSearchKeyIsLocalized) <> 0
					Or StrFind(Area.Text, TheSearchKeyIsNotLocalized) <> 0 Then
					Area.Text = StrReplace(Area.Text, TheSearchKeyIsLocalized, "");
					Area.Text = StrReplace(Area.Text, TheSearchKeyIsNotLocalized, "");
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf
	
EndProcedure

Procedure RedefineShowTotals(ResultDocument, ReportStructureNotChanged)
	
	If Not ReportStructureNotChanged Then
		Return;
	EndIf;
	
	TableWidth = ResultDocument.TableWidth;
	TableHeight = ResultDocument.TableHeight;
	
	LocalizedParametersStructure = LocalizedParametersStructure();
	
	For RowsIndex = 1 To TableHeight Do
		
		AreaName   = "R" + Format(RowsIndex, "NG=0") + "C1";
		Area      = ResultDocument.Area(AreaName);
		AreaText = TrimAll(Upper(Area.Text));
		
		If AreaText =    Upper(LocalizedParametersStructure.LabelError)
			Or AreaText = Upper(LocalizedParametersStructure.LabelPossibleCauses)
			Or AreaText = Upper(LocalizedParametersStructure.LabelRecommendations)
			Or AreaText = Upper(LocalizedParametersStructure.LabelDecision) Then
			
			For ColumnsIndex = 3 To TableWidth Do
				ResourcesAreaName    = "R" + Format(RowsIndex, "NG=0") + "C" + Format(ColumnsIndex, "NG=0");
				ResourcesArea       = ResultDocument.Area(ResourcesAreaName);
				ResourcesArea.Text = "";
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure EnterDecisionsHyperlinks(ResultDocument)
	
	TableWidth = ResultDocument.TableWidth;
	TableHeight = ResultDocument.TableHeight;
	
	For RowsIndex = 1 To TableHeight Do
		
		For ColumnsIndex = 1 To TableWidth Do
			
			AreaName   = "R" + Format(RowsIndex, "NG=0") + "C" + Format(ColumnsIndex, "NG=0");
			Area      = ResultDocument.Area(AreaName);
			AreaText = Area.Text;
			
			If StrStartsWith(AreaText, "%") And StrEndsWith(AreaText, "%") Then
				
				AreaText      = TrimAll(StrReplace(AreaText, "%", ""));
				SplitRow = StrSplit(AreaText, ",");
				
				If SplitRow.Count() <> 3 Then
					Continue;
				EndIf;
				
				GoToCorrectionHandler = SplitRow.Get(1);
				If Not ValueIsFilled(GoToCorrectionHandler) Then
					Area.Text = "";
					Continue;
				EndIf;
				
				CheckKind = Catalogs.ChecksKinds.GetRef(New UUID(SplitRow.Get(2)));
				
				DetailsStructure2 = New Structure;
				
				DetailsStructure2.Insert("Purpose",                     "FixIssues");
				DetailsStructure2.Insert("CheckID",          SplitRow.Get(0));
				DetailsStructure2.Insert("GoToCorrectionHandler", GoToCorrectionHandler);
				DetailsStructure2.Insert("CheckKind",                    CheckKind);
				
				Area.Details = DetailsStructure2;
				
				ReportsServer.OutputHyperlink(Area, DetailsStructure2, NStr("en = 'Fix issue';"));
				
			ElsIf StrFind(AreaText, "<DetailsList>") <> 0 Then
				
				DetailsStructure2 = New Structure;
				DetailsStructure2.Insert("Purpose", "OpenListForm");
				
				RecordSetFilter = New Structure;
				SeparatedText   = StrSplit(AreaText, Chars.LF);
				
				For Each TextItem In SeparatedText Do
					
					If SeparatedText.Find(TextItem) = 0 Then
						Continue;
					ElsIf SeparatedText.Find(TextItem) = 1 Then
						DetailsStructure2.Insert("FullObjectName", TextItem);
						Continue;
					EndIf;
					
					SeparatedTextItem = StrSplit(TextItem, "~~~", False);
					If SeparatedTextItem.Count() <> 3 Then
						Continue;
					EndIf;
					
					FilterName             = SeparatedTextItem.Get(0);
					ValueTypeFilter     = SeparatedTextItem.Get(1);
					FilterValueAsString = SeparatedTextItem.Get(2);
					
					If ValueTypeFilter = "Number" Or ValueTypeFilter = "String" 
						Or ValueTypeFilter = "Boolean" Or ValueTypeFilter = "Date" Then
						
						FilterValue = XMLValue(Type(ValueTypeFilter), FilterValueAsString);
						
					ElsIf Common.IsEnum(Common.MetadataObjectByFullName(ValueTypeFilter)) Then
						
						FilterValue = XMLValue(Type(StrReplace(ValueTypeFilter, "Enum", "EnumRef")), FilterValueAsString);
						
					Else
						
						ObjectManager = Common.ObjectManagerByFullName(ValueTypeFilter);
						If ObjectManager = Undefined Then
							Continue;
						EndIf;
						FilterValue = ObjectManager.GetRef(New UUID(FilterValueAsString));
						
					EndIf;
					
					RecordSetFilter.Insert(FilterName, FilterValue);
					
				EndDo;
				DetailsStructure2.Insert("Filter", RecordSetFilter);
				
				Area.Details = DetailsStructure2;
				
				If SeparatedText.Count() <> 0 Then
					Area.Text = StrReplace(SeparatedText.Get(0), "<DetailsList>", "");
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function PrepareChecksList(ChecksArray)
	ChecksList = New ValueList;
	TheFirstControl  = ChecksArray.Get(0);
	
	If Not Common.RefTypeValue(TheFirstControl) Then
		ChecksList.LoadValues(ChecksArray);
	Else
		QueryResult = ChecksList(ChecksArray, TheFirstControl);
		For Each ResultItem In QueryResult Do
			ChecksList.Add(ResultItem.Ref, ResultItem.RepresentationOfTheReference);
		EndDo;
	EndIf;
	
	Return ChecksList;
EndFunction

// Parameters:
//   ChecksArray - Array of AnyRef
//   TheFirstControl - AnyRef
// Returns:
//   ValueTable:
//   *Ref - AnyRef
//   *RepresentationOfTheReference - String
//
Function ChecksList(Val ChecksArray, TheFirstControl)
	QueryText =
	"SELECT
	|	Table.Ref AS Ref,
	|	PRESENTATION(Table.Ref) AS RepresentationOfTheReference
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.Ref IN(&ReferencesArrray)";
	
	QueryText = StrReplace(QueryText, "&Table", TheFirstControl.Metadata().FullName());
	Query       = New Query(QueryText);
	Query.SetParameter("ReferencesArrray", ChecksArray);
	
	QueryResult = Query.Execute().Unload();
	Return QueryResult
EndFunction

Procedure SetDataParameters(DCSettings, ParametersStructure)
	
	DataParameters = DCSettings.DataParameters.Items;
	
	For Each Parameter In ParametersStructure Do
	
		CurrentParameter   = New DataCompositionParameter(Parameter.Key);
		CurrentDCSParameter = DataParameters.Find(CurrentParameter);
	
		If CurrentDCSParameter <> Undefined Then
	
			CurrentDCSParameter.Use = True;
			CurrentDCSParameter.Value      = Parameter.Value;
	
		Else
	
			DataParameter               = DCSettings.DataParameters.Items.Add();
			DataParameter.Use = True;
			DataParameter.Value      = Parameter.Value;
			DataParameter.Parameter      = New DataCompositionParameter(Parameter.Key);
	
		EndIf;
	
	EndDo;
	
EndProcedure

Procedure SetParametersValues(DCSettings)
	
	DataParameters = DCSettings.DataParameters.Items;
	
	LocalizedParametersStructure = LocalizedParametersStructure();
	
	For Each StructureItem In LocalizedParametersStructure Do
		
		CurrentDCSParameter = DataParameters.Find(New DataCompositionParameter(StructureItem.Key));
		If CurrentDCSParameter <> Undefined Then
			CurrentDCSParameter.Use = True;
			CurrentDCSParameter.Value      = StructureItem.Value;
		Else
			DataParameter               = DCSettings.DataParameters.Items.Add();
			DataParameter.Use = True;
			DataParameter.Value      = StructureItem.Value;
			DataParameter.Parameter      = New DataCompositionParameter(StructureItem.Key);
		EndIf;
			
	EndDo;
	
EndProcedure

Function LocalizedParametersStructure()
	
	LocalizedParametersStructure = New Structure;
	LocalizedParametersStructure.Insert("LabelError",            NStr("en = 'Error';"));
	LocalizedParametersStructure.Insert("LabelPossibleCauses",  NStr("en = 'Possible causes';"));
	LocalizedParametersStructure.Insert("LabelRecommendations",      NStr("en = 'Recommendations';"));
	LocalizedParametersStructure.Insert("LabelDecision",           NStr("en = 'Solution';"));
	LocalizedParametersStructure.Insert("ObjectsWithIssuesLabel", NStr("en = 'Objects with issues';"));
	
	Return LocalizedParametersStructure;
	
EndFunction

Procedure SetFilterByIssuesList(DCSSettingsFilter, UserSettings, FilterValue)
	
	FilterPresentation = "";
	For Each FilterListItem In FilterValue Do
		FilterPresentation = FilterPresentation + ?(ValueIsFilled(FilterPresentation), "; ", "") + Left(FilterListItem.Presentation, 25) + "...";
	EndDo;
	
	FilterItems1 = DCSSettingsFilter.Items;
	SettingID = Undefined;
	For Each FilterElement In FilterItems1 Do
		If FilterElement.LeftValue <> New DataCompositionField("CheckRule") Then
			Continue;
		EndIf;
		SettingID = FilterElement.UserSettingID;
		Break;
	EndDo;
	
	If SettingID <> Undefined Then
		Setting = UserSettings.Items.Find(SettingID);
		If Setting = Undefined Then
			Return;
		EndIf;
		If ValueIsFilled(FilterValue) Then
			Setting.RightValue = FilterValue;
			Setting.Use  = True;
		Else
			Setting.Use  = False;
		EndIf;
		Return;
	EndIf;
	
	FilterElement                  = FilterItems1.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue    = New DataCompositionField("CheckRule");
	FilterElement.ComparisonType     = ComparisonType;
	FilterElement.RightValue   = FilterValue;
	FilterElement.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterElement.Presentation    = NStr("en = 'Check rule In list';") + " """ + FilterPresentation + """";
	FilterElement.Use    = True;
	
EndProcedure

Procedure HideGroupByResponsiblePersons(NewDCSettings, Setting)
	
	If NewDCSettings <> Undefined Then
		FoundTable = Undefined;
		For Each String In NewDCSettings.Structure Do
			If String.Name = "CommonTable" Then
				FoundTable = String;
				Break;
			EndIf;
		EndDo;
		If FoundTable = Undefined Then
			Return;
		EndIf;
		GroupByReponsiblePersonColumns = FindGroup1(FoundTable.Columns, "EmployeeResponsibleGrouping");
		ResponsiblePersonField                 = FindGroupField(FoundTable.Rows, "EmployeeResponsible");
		If ResponsiblePersonField <> Undefined Then
			ResponsiblePersonField.Use = Setting.Value;
		EndIf;
		If GroupByReponsiblePersonColumns <> Undefined Then
			GroupByReponsiblePersonColumns.State = ?(Setting.Value, DataCompositionSettingsItemState.Enabled,
				DataCompositionSettingsItemState.Disabled);
		EndIf;
	EndIf;
	
EndProcedure

Function FindGroup1(Structure, FieldName)
	
	For Each Item In Structure Do
		
		GroupFields = Item.GroupFields.Items;
		For Each Field In GroupFields Do
			
			If TypeOf(Field) = Type("DataCompositionAutoGroupField") Then
				Continue;
			EndIf;
			If Field.Field = New DataCompositionField(FieldName) Then
				Return Item;
			EndIf;
			
		EndDo;
		
		If Item.Structure.Count() = 0 Then
			Continue;
		EndIf;
		Group = FindGroup1(Item.Structure, FieldName);
	
	EndDo;
	
	Return Group;
	
EndFunction

Function FindGroupField(Structure, FieldName)
	
	Group = FindGroup1(Structure, FieldName);
	
	If Group = Undefined Then
		Return Undefined;
	EndIf;
	
	GroupFields = Group.GroupFields.Items;
	FoundField   = Undefined;
	
	For Each GroupingField In GroupFields Do
		FieldToFind = New DataCompositionField(FieldName);
		If GroupingField.Field = FieldToFind Then
			FoundField = GroupingField;
		EndIf;
	EndDo;
	
	Return FoundField;
	
EndFunction

Function ReportStructureNotChanged(InitialStructure = Undefined, FinalStructure = Undefined)
	
	InitialStructure = ReportStructureAsTree(DataCompositionSchema.DefaultSettings);
	FinalStructure = ReportStructureAsTree(SettingsComposer.Settings);
	Return TreesIdentical(InitialStructure, FinalStructure);
	
EndFunction

Function TreesIdentical(FirstTree, SecondTree, PropertiesToCompare = Undefined)
	
	If PropertiesToCompare = Undefined Then
		PropertiesToCompare = New Array;
		PropertiesToCompare.Add("Type");
		PropertiesToCompare.Add("Subtype");
		PropertiesToCompare.Add("HasStructure");
	EndIf;
	
	FirstTreeRows = FirstTree.Rows;
	SecondTreeRows = SecondTree.Rows;
	
	FirstTreeRowsCount  = FirstTreeRows.Count();
	SecondTreeRowsCount = SecondTreeRows.Count();
	
	If FirstTreeRowsCount <> SecondTreeRowsCount Then
		Return False;
	EndIf;
	
	For RowIndex = 0 To FirstTreeRowsCount - 1 Do
		
		FirstTreeCurrentRow = FirstTreeRows.Get(RowIndex);
		SecondTreeCurrentRow = SecondTreeRows.Get(RowIndex);
		
		For Each PropertyToCompare In PropertiesToCompare Do
			
			If FirstTreeCurrentRow[PropertyToCompare] <> SecondTreeCurrentRow[PropertyToCompare] Then
				Return False;
			EndIf;
			
		EndDo;
		
		If Not DataCompositionNodesSettingsIdentical(FirstTreeCurrentRow.DCNode, SecondTreeCurrentRow.DCNode) Then
			Return False;
		EndIf;
		
		If Not TreesIdentical(FirstTreeCurrentRow, SecondTreeCurrentRow, PropertiesToCompare) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

Function DataCompositionNodesSettingsIdentical(DataCompositionFirstNode, DataCompositionSecondNode)
	
	If TypeOf(DataCompositionFirstNode) <> TypeOf(DataCompositionSecondNode) Then
		Return False;
	EndIf;
	
	If TypeOf(DataCompositionFirstNode) = Type("DataCompositionSettings") Then
		
		If Not SelectedFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
		If Not UserFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
	ElsIf TypeOf(DataCompositionFirstNode) = Type("DataCompositionTable") Then
		
		If Not CompositionTablesPropertiesIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
		If Not SelectedFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
	ElsIf TypeOf(DataCompositionFirstNode) = Type("DataCompositionTableStructureItemCollection") Then
		
		If Not ItemsCollectionsPropertiesOfDataCompositionTableStructureIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
	ElsIf TypeOf(DataCompositionFirstNode) = Type("DataCompositionTableGroup") Or TypeOf(DataCompositionFirstNode) = Type("DataCompositionGroup") Then
		
		If Not CompositionGroupsPropertiesIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
		If Not SelectedFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
		If Not CompositionGroupsFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode) Then
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

// Parameters:
//   DataCompositionFirstNode - DataCompositionSettings 
//   DataCompositionSecondNode - DataCompositionSettings
// Returns:
//   Boolean
//
Function SelectedFieldsIdentical(DataCompositionFirstNode, DataCompositionSecondNode)
	
	FirstNodeSelectedFields = DataCompositionFirstNode.Selection.Items;
	SecondNodeSelectedFields = DataCompositionSecondNode.Selection.Items;
	
	FirstNodeSelectedFieldsCount = FirstNodeSelectedFields.Count();
	SecondNodeSelectedFieldsCount = SecondNodeSelectedFields.Count();
	
	If FirstNodeSelectedFieldsCount <> SecondNodeSelectedFieldsCount Then
		Return False;
	EndIf;
	
	SelectedFieldsProperties = New Array;
	
	For IndexOf = 0 To FirstNodeSelectedFieldsCount - 1 Do
		
		FirstCollectionCurrentRow = FirstNodeSelectedFields.Get(IndexOf);
		SecondCollectionCurrentRow = SecondNodeSelectedFields.Get(IndexOf);
		
		If TypeOf(FirstCollectionCurrentRow) <> TypeOf(SecondCollectionCurrentRow) Then
			Return False;
		EndIf;
		
		If TypeOf(FirstCollectionCurrentRow) = Type("DataCompositionAutoSelectedField") Then
			
			SelectedFieldsProperties.Add("Use");
			SelectedFieldsProperties.Add("Parent");
			
		ElsIf TypeOf(FirstCollectionCurrentRow) = Type("DataCompositionSelectedField") Then
			
			SelectedFieldsProperties.Add("Title");
			SelectedFieldsProperties.Add("Use");
			SelectedFieldsProperties.Add("Field");
			SelectedFieldsProperties.Add("ViewMode");
			SelectedFieldsProperties.Add("Parent");
			
		ElsIf TypeOf(FirstCollectionCurrentRow) = Type("DataCompositionSelectedFieldGroup") Then
			
			Return True;
			
		EndIf;
		
		If Not CompareEntitiesByProperties(FirstCollectionCurrentRow, SecondCollectionCurrentRow, SelectedFieldsProperties) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

Function CompositionTablesPropertiesIdentical(FirstTable, SecondTable)
	
	CompositionTableProperties = New Array;
	CompositionTableProperties.Add("Id");
	CompositionTableProperties.Add("UserSettingID");
	CompositionTableProperties.Add("Name");
	CompositionTableProperties.Add("Use");
	CompositionTableProperties.Add("UserSettingPresentation");
	CompositionTableProperties.Add("ViewMode");
	
	If Not CompareEntitiesByProperties(FirstTable, SecondTable, CompositionTableProperties) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function CompositionGroupsPropertiesIdentical(FirstTable, SecondTable)
	
	CompositionTableProperties = New Array;
	CompositionTableProperties.Add("Id");
	CompositionTableProperties.Add("UserSettingID");
	CompositionTableProperties.Add("Name");
	CompositionTableProperties.Add("Use");
	CompositionTableProperties.Add("UserSettingPresentation");
	CompositionTableProperties.Add("ViewMode");
	CompositionTableProperties.Add("State");
	
	If Not CompareEntitiesByProperties(FirstTable, SecondTable, CompositionTableProperties) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function ItemsCollectionsPropertiesOfDataCompositionTableStructureIdentical(FirstCollection, SecondCollection)
	
	CollectionProperties = New Array;
	CollectionProperties.Add("UserSettingID");
	CollectionProperties.Add("UserSettingPresentation");
	CollectionProperties.Add("ViewMode");
	
	If Not CompareEntitiesByProperties(FirstCollection, SecondCollection, CollectionProperties) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Parameters:
//   FirstGroup1 - DataCompositionTableGroup 
//   SecondGroup1 - DataCompositionTableGroup
// Returns:
//   Boolean
//
Function CompositionGroupsFieldsIdentical(FirstGroup1, SecondGroup1)
	
	FirstFieldsCollection = FirstGroup1.GroupFields.Items;
	SecondFieldsCollection = SecondGroup1.GroupFields.Items;
	
	FieldsCountInFirstCollection  = FirstFieldsCollection.Count();
	FieldsCountInSecondCollection = SecondFieldsCollection.Count();
	
	FieldsProperties = New Array;
	FieldsProperties.Add("Use");
	FieldsProperties.Add("EndOfPeriod");
	FieldsProperties.Add("BeginOfPeriod");
	FieldsProperties.Add("Field");
	FieldsProperties.Add("GroupType");
	FieldsProperties.Add("AdditionType");
	
	If FieldsCountInFirstCollection <> FieldsCountInSecondCollection Then
		Return False;
	EndIf;
	
	For IndexOf = 0 To FieldsCountInFirstCollection - 1 Do
		
		FirstFieldCurrentRow = FirstFieldsCollection.Get(IndexOf);
		SecondFieldCurrentRow = SecondFieldsCollection.Get(IndexOf);
		
		If Not CompareEntitiesByProperties(FirstFieldCurrentRow, SecondFieldCurrentRow, FieldsProperties) Then
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

// Parameters:
//   FirstDCSettings - DataCompositionSettings
//   SecondDCSettings - DataCompositionSettings
// Returns:
//   Boolean
//
Function UserFieldsIdentical(FirstDCSettings, SecondDCSettings)
	
	If FirstDCSettings.UserFields.Items.Count() <> SecondDCSettings.UserFields.Items.Count() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function CompareEntitiesByProperties(FirstEntity, SecondEntity, Properties)
	
	For Each Property In Properties Do
		
		If IsException(FirstEntity, Property) Then
			Continue;
		EndIf;
		
		If FirstEntity[Property] <> SecondEntity[Property] Then
			Return False
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

Function IsException(FirstEntity, Property)
	
	If TypeOf(FirstEntity) = Type("DataCompositionTableGroup") Then
		
		If FirstEntity.Name = "EmployeeResponsible" And Property = "State" Then
			Return True;
		EndIf;
		
	ElsIf TypeOf(FirstEntity) = Type("DataCompositionGroupField") Then
		
		If FirstEntity.Field = New DataCompositionField("EmployeeResponsible") And Property = "Use" Then
			Return True;
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function ReportStructureAsTree(DCSettings)
	
	StructureTree       = StructureTree();
	RegisterOptionTreeNode(DCSettings, DCSettings, StructureTree.Rows);
	Return StructureTree;
	
EndFunction

// Returns:
//   ValueTree:
//   * DCNode - DataCompositionSettingStructureItemCollection
//   * Type - String
//   * Subtype - String
//   * HasStructure - Boolean
//
Function StructureTree()
	
	StructureTree = New ValueTree;
	
	StructureTreeColumns = StructureTree.Columns;
	StructureTreeColumns.Add("DCNode");
	StructureTreeColumns.Add("AvailableDCSetting");
	StructureTreeColumns.Add("Type",                 New TypeDescription("String"));
	StructureTreeColumns.Add("Subtype",              New TypeDescription("String"));
	StructureTreeColumns.Add("HasStructure",       New TypeDescription("Boolean"));
	
	Return StructureTree;
	
EndFunction

Function RegisterOptionTreeNode(DCSettings, DCNode, TreeRowsSet, DPRType = "")
	
	TreeRow = TreeRowsSet.Add();
	TreeRow.DCNode = DCNode;
	TreeRow.Type    = SettingTypeAsString(TypeOf(DCNode));
	TreeRow.Subtype = DPRType;
	
	If StrSplit("Settings,Group,ChartGroup,TableGroup", ",").Find(TreeRow.Type) <> Undefined Then
		TreeRow.HasStructure = True;
	ElsIf StrSplit("Table,Chart,NestedObjectSettings,TableStructureItemCollection
			|ChartStructureItemCollection", "," + Chars.LF, False).Find(TreeRow.Type) = Undefined Then
		Return TreeRow;
	EndIf;
	
	If TreeRow.HasStructure Then
		For Each NestedItem In DCNode.Structure Do
			RegisterOptionTreeNode(DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
	EndIf;
	
	If TreeRow.Type = "Table" Then
		RegisterOptionTreeNode(DCSettings, DCNode.Rows, TreeRow.Rows, "TableRows1");
		RegisterOptionTreeNode(DCSettings, DCNode.Columns, TreeRow.Rows, "ColumnsTable");
	ElsIf TreeRow.Type = "Chart" Then
		RegisterOptionTreeNode(DCSettings, DCNode.Points, TreeRow.Rows, "ChartPoints");
		RegisterOptionTreeNode(DCSettings, DCNode.Series, TreeRow.Rows, "ChartSeries");
	ElsIf TreeRow.Type = "TableStructureItemCollection"
		Or TreeRow.Type = "ChartStructureItemCollection" Then
		For Each NestedItem In DCNode Do
			RegisterOptionTreeNode(DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
	ElsIf TreeRow.Type = "NestedObjectSettings" Then
		RegisterOptionTreeNode(DCSettings, DCNode.Settings, TreeRow.Rows);
	EndIf;
	
	Return TreeRow;
	
EndFunction

Function SettingTypeAsString(Type) Export
	If Type = Type("DataCompositionSettings") Then
		Return "Settings";
	ElsIf Type = Type("DataCompositionNestedObjectSettings") Then
		Return "NestedObjectSettings";
	
	ElsIf Type = Type("DataCompositionFilter") Then
		Return "Filter";
	ElsIf Type = Type("DataCompositionFilterItem") Then
		Return "FilterElement";
	ElsIf Type = Type("DataCompositionFilterItemGroup") Then
		Return "FilterItemsGroup";
	
	ElsIf Type = Type("DataCompositionSettingsParameterValue") Then
		Return "SettingsParameterValue";
	
	ElsIf Type = Type("DataCompositionGroup") Then
		Return "Group";
	ElsIf Type = Type("DataCompositionGroupFields") Then
		Return "GroupFields";
	ElsIf Type = Type("DataCompositionGroupFieldCollection") Then
		Return "GroupFieldsCollection";
	ElsIf Type = Type("DataCompositionGroupField") Then
		Return "GroupingField";
	ElsIf Type = Type("DataCompositionAutoGroupField") Then
		Return "AutoGroupField";
	
	ElsIf Type = Type("DataCompositionSelectedFields") Then
		Return "SelectedFields";
	ElsIf Type = Type("DataCompositionSelectedField") Then
		Return "SelectedField";
	ElsIf Type = Type("DataCompositionSelectedFieldGroup") Then
		Return "SelectedFieldsGroup";
	ElsIf Type = Type("DataCompositionAutoSelectedField") Then
		Return "AutoSelectedField";
	
	ElsIf Type = Type("DataCompositionOrder") Then
		Return "Order";
	ElsIf Type = Type("DataCompositionOrderItem") Then
		Return "OrderItem";
	ElsIf Type = Type("DataCompositionAutoOrderItem") Then
		Return "AutoOrderItem";
	
	ElsIf Type = Type("DataCompositionConditionalAppearance") Then
		Return "ConditionalAppearance";
	ElsIf Type = Type("DataCompositionConditionalAppearanceItem") Then
		Return "ConditionalAppearanceItem";
	
	ElsIf Type = Type("DataCompositionSettingStructure") Then
		Return "SettingsStructure";
	ElsIf Type = Type("DataCompositionSettingStructureItemCollection") Then
		Return "SettingsStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionTable") Then
		Return "Table";
	ElsIf Type = Type("DataCompositionTableGroup") Then
		Return "TableGroup";
	ElsIf Type = Type("DataCompositionTableStructureItemCollection") Then
		Return "TableStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionChart") Then
		Return "Chart";
	ElsIf Type = Type("DataCompositionChartGroup") Then
		Return "ChartGroup";
	ElsIf Type = Type("DataCompositionChartStructureItemCollection") Then
		Return "ChartStructureItemCollection";
	
	ElsIf Type = Type("DataCompositionDataParameterValues") Then
		Return "DataParametersValues";
	
	Else
		Return "";
	EndIf;
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf