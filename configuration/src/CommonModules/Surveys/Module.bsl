///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export

	Objects.Insert(Metadata.Documents.Questionnaire.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.PollPurpose.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.QuestionsForSurvey.FullName(),
		"AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.QuestionnaireAnswersOptions.FullName(),
		"AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.QuestionnaireTemplateQuestions.FullName(),
		"AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.QuestionnaireTemplates.FullName(), "AttributesToEditInBatchProcessing");

EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// СовместноДляПользователейИВнешнихПользователей.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.AddEditQuestionnaireQuestionsAnswers.Name);
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadQuestionnaireQuestionAnswers.Name);

EndProcedure

// See ReportsOptionsOverridable.DefineObjectsWithReportCommands
Procedure OnDefineObjectsWithReportCommands(Objects) Export

	Objects.Add(Metadata.Documents.PollPurpose);

EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export

	Handler = Handlers.Add();
	Handler.Version = "2.3.5.6";
	Handler.Id = New UUID("cfda47d2-f61f-4c23-84a6-80c77b52e6e5");
	Handler.Procedure = "Documents.Questionnaire.ProcessDataForMigrationToNewVersion";
	Handler.Comment = NStr("en = 'The new attribute ""Survey mode"" is being populated in the ""Questionnaire"" documents.
								  |Until the population is complete, the attribute might be displayed incorrectly.';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Documents.Questionnaire.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToRead      = "Document.Questionnaire";
	Handler.ObjectsToChange    = "Document.Questionnaire";
	Handler.ObjectsToLock   = "Document.Questionnaire";

	Handler = Handlers.Add();
	Handler.Version = "2.3.5.6";
	Handler.Id = New UUID("1fdb0962-f814-463a-b560-48ea3d51be27");
	Handler.Procedure = "Catalogs.QuestionnaireTemplateQuestions.ProcessDataForMigrationToNewVersion";
	Handler.Comment = NStr("en = 'New attribute ""Tooltip display mode"" is being populated in the ""Questionnaire template questions"" catalog.
								  |Until the population is complete, the attribute might be displayed incorrectly.';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.QuestionnaireTemplateQuestions.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToRead      = "Catalog.QuestionnaireTemplateQuestions";
	Handler.ObjectsToChange    = "Catalog.QuestionnaireTemplateQuestions";
	Handler.ObjectsToLock   = "Catalog.QuestionnaireTemplateQuestions";

	Handler = Handlers.Add();
	Handler.Version = "3.1.9.6";
	Handler.Id = New UUID("a1581723-c1f5-4b90-b716-a180a4d5a4ad");
	Handler.Procedure = "ChartsOfCharacteristicTypes.QuestionsForSurvey.ProcessDataForMigrationToNewVersion";
	Handler.Comment = NStr("en = 'Fill the new ""Display format"", ""Use minimum value'''', and ""Use maximum value'''' attributes in survey questions.
								  |Until the processing is completed, the questions will be displayed incorrectly.';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "ChartsOfCharacteristicTypes.QuestionsForSurvey.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToRead      = "ChartOfCharacteristicTypes.QuestionsForSurvey";
	Handler.ObjectsToChange    = "ChartOfCharacteristicTypes.QuestionsForSurvey";
	Handler.ObjectsToLock   = "ChartOfCharacteristicTypes.QuestionsForSurvey";

EndProcedure

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.PollStatistics);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.SurveysAnalyticalReport);
EndProcedure


// See ReportMailingOverridable.DetermineReportsToExclude
Procedure WhenDefiningExcludedReports(ReportsToExclude) Export

	ReportsToExclude.Add(Metadata.Reports.PollStatistics);

EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Populate the questionnaire tree.

// Parameters:
//  Questions - See Catalog.QuestionnaireTemplates.Form.TableQuestionsWizardForm.Questions
//  Replies - See Catalog.QuestionnaireTemplates.Form.TableQuestionsWizardForm.Replies
//  TabularQuestionType - See Catalog.QuestionnaireTemplates.Form.TableQuestionsWizardForm.TabularQuestionType
//  Form - See Catalog.QuestionnaireTemplates.Form.TableQuestionsWizardForm
//  TableNamePreview - String
//  Var_Key - String
//
Procedure UpdateTabularQuestionPreview(Questions, Replies, TabularQuestionType, Form, TableNamePreview, Var_Key) Export

	NameOfColumnWithoutNumber = "PreviewTableColumn" + StrReplace(String(Var_Key), "-", "_") + "_";
	TypesDetailsString = New TypeDescription("String", , New StringQualifiers(70));

	ResultingTableServer = Form.FormAttributeToValue(TableNamePreview); // ValueTable
	ResultingTableServer.Columns.Clear();

	AttributesToBeDeleted = New Array;
	FormItemsToDelete = New Array;
	ArrayOfCurrentResultingTableColumns = Form.GetAttributes(TableNamePreview);
	For Each ArrayElement In ArrayOfCurrentResultingTableColumns Do
		AttributesToBeDeleted.Add(ArrayElement.Path + "." + ArrayElement.Name);
		FormItemsToDelete.Add(ArrayElement.Name);
	EndDo;

	For Each ArrayElement In FormItemsToDelete Do
		FoundFormItem = Form.Items.Find(ArrayElement);
		If FoundFormItem <> Undefined Then
			Form.Items.Delete(FoundFormItem);
		EndIf;
	EndDo;

	AttributesToBeAdded = New Array;
	ColumnsCounter = 0;

	QuestionsArray1 = Questions.UnloadColumn("ElementaryQuestion");

	If Questions.Columns.Find("LineNumber") = Undefined Then
		Questions.Columns.Add("LineNumber", New TypeDescription("Number"));
	EndIf;

	For Indus = 0 To Questions.Count() - 1 Do
		Questions.Get(Indus).LineNumber = Indus;
	EndDo;

	Query = New Query;
	Query.Text =
	"SELECT
	|	Questions.ElementaryQuestion AS DoQueryBox,
	|	Questions.LineNumber
	|INTO Questions
	|FROM
	|	&Questions AS Questions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionsForSurvey.Wording,
	|	QuestionsForSurvey.ValueType
	|FROM
	|	Questions AS Questions
	|		INNER JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON Questions.DoQueryBox = QuestionsForSurvey.Ref
	|WHERE
	|	QuestionsForSurvey.Ref IN(&Questions)
	|
	|ORDER BY
	|	Questions.LineNumber";

	Query.SetParameter("Questions", Questions);

	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;

	If TabularQuestionType = Enums.TabularQuestionTypes.Composite Then

		SelectionQuestions = Result.Select();
		While SelectionQuestions.Next() Do

			ColumnsCounter = ColumnsCounter + 1;
			ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + XMLString(ColumnsCounter),
				SelectionQuestions.ValueType, SelectionQuestions.Wording);
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(ColumnsCounter),
				SelectionQuestions.ValueType, TableNamePreview));

		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows Then

		SelectionQuestions = Result.Select();
		While SelectionQuestions.Next() Do

			ColumnsCounter = ColumnsCounter + 1;
			ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + XMLString(ColumnsCounter),
				SelectionQuestions.ValueType, SelectionQuestions.Wording);
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(ColumnsCounter),
				SelectionQuestions.ValueType, TableNamePreview));

		EndDo;

		For Indus = 1 To Replies.Count() Do

			NewRow    = ResultingTableServer.Add();
			NewRow[0] = Replies[Indus - 1].Response;

		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then

		SelectionQuestions = Result.Select();
		If SelectionQuestions.Next() Then

			ColumnsCounter = ColumnsCounter + 1;
			ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + "1", TypesDetailsString,
				SelectionQuestions.Wording);
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + "1", TypesDetailsString,
				TableNamePreview));

		EndIf;

		For Indus = 1 To Replies.Count() Do

			ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + XMLString(Indus + 1), TypesDetailsString,
				Replies[Indus - 1].Response);
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(Indus + 1),
				TypesDetailsString, TableNamePreview));

		EndDo;

		While SelectionQuestions.Next() Do

			NewRow    = ResultingTableServer.Add();
			NewRow[0] = SelectionQuestions.Wording;

		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then

		QuestionsTable = Result.Unload();

		ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + "1", QuestionsTable[0].ValueType,
			QuestionsTable[0].Wording);
		AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + "1", QuestionsTable[0].ValueType,
			TableNamePreview));

		AnswersInColumns = Replies.FindRows(New Structure("ElementaryQuestion", QuestionsArray1[1]));
		For Indus = 1 To AnswersInColumns.Count() Do

			ResultingTableServer.Columns.Add(NameOfColumnWithoutNumber + XMLString(Indus + 1),
				QuestionsTable[2].ValueType, AnswersInColumns[Indus - 1].Response);
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(Indus + 1),
				QuestionsTable[2].ValueType, TableNamePreview));

		EndDo;

		AnswersInRows = Replies.FindRows(New Structure("ElementaryQuestion", QuestionsArray1[0]));
		For Indus = 1 To AnswersInRows.Count() Do

			NewRow    = ResultingTableServer.Add();
			NewRow[0] = AnswersInRows[Indus - 1].Response;

		EndDo;

	EndIf;

	Form.ChangeAttributes(AttributesToBeAdded, AttributesToBeDeleted);
	Form.ValueToFormAttribute(ResultingTableServer, TableNamePreview);

	For Indus = 1 To AttributesToBeAdded.Count() Do

		Item = Form.Items.Add(NameOfColumnWithoutNumber + XMLString(Indus), Type("FormField"),
			Form.Items[TableNamePreview]);
		If AttributesToBeAdded[Indus - 1].ValueType = New TypeDescription("Boolean") Then
			Item.Type = FormFieldType.CheckBoxField;
		Else
			Item.Type = FormFieldType.InputField;
		EndIf;

		Item.DataPath = TableNamePreview + "." + NameOfColumnWithoutNumber + XMLString(Indus);
		If (TabularQuestionType = Enums.TabularQuestionTypes.Composite Or TabularQuestionType
			= Enums.TabularQuestionTypes.PredefinedAnswersInRows) Or (Indus > 1) Then

			Item.Title = ResultingTableServer.Columns.Get(Indus - 1).Title;
		Else
			Item.TitleLocation = FormItemTitleLocation.None;
		EndIf;

	EndDo;

EndProcedure

// 
//
Procedure SetQuestionnaireTreeRootItem(QuestionnaireTree) Export

	TreeItems = QuestionnaireTree.GetItems(); // ValueTreeRowCollection
	NewRow    = TreeItems.Add();

	NewRow.Wording = NStr("en = 'Questionnaire';");
	NewRow.RowType    = "Root";
	NewRow.PictureCode  = SurveysClientServer.GetQuestionnaireTemplatePictureCode(False);

EndProcedure

// Parameters:
//  QuestionnaireTree - FormDataTree - a tree, to which an introduction or conclusion item is added.
//  Wording - String - a localized presentation of a tree's element - either "introduction" or "conclusion".
//  RowType    - String - a type of a tree's element - either "introduction" or "conclusion".
//
Procedure SetQuestionnaireSectionsTreeItemIntroductionConclusion(QuestionnaireTree, Wording, RowType) Export

	TreeItems = QuestionnaireTree.GetItems();
	NewRow    = TreeItems.Add();

	NewRow.Wording = Wording;
	NewRow.RowType    = RowType;
	NewRow.PictureCode  = SurveysClientServer.GetQuestionnaireTemplatePictureCode(False);

EndProcedure

// Parameters:
//  Form                   - ClientApplicationForm - a form for which the tree is filled in.
//  QuestionnaireTreeName         - String - a name of the form attribute, which will contain the questionnaire tree.
//  QuestionnaireTemplate            - CatalogRef.QuestionnaireTemplates - Reference to a questionnaire template that will be used to populate the tree.
//                                                            FillPreviewPages - Boolean - Flag indicating whether question chart preview pages must be generated.
//  
//
Procedure FillQuestionnaireTemplateTree(Form, QuestionnaireTreeName, QuestionnaireTemplate) Export

	If QuestionnaireTemplate = Catalogs.QuestionnaireTemplates.EmptyRef() Then
		Return;
	EndIf;

	Result = ExecuteQueryByQuestionnaireTemplateQuestions(QuestionnaireTemplate);
	If Result.IsEmpty() Then
		Return;
	EndIf;

	QuestionnaireTreeServer = Form.FormAttributeToValue(QuestionnaireTreeName);

	Selection = Result.Select(QueryResultIteration.ByGroupsWithHierarchy);

	If Selection.Count() > 0 Then
		AddQuestionnaireTreeRows(Selection, QuestionnaireTreeServer.Rows[0], 1, Form);
	EndIf;

	Form.ValueToFormAttribute(QuestionnaireTreeServer, QuestionnaireTreeName);

EndProcedure

// Parameters:
//  Selection        - QueryResultSelection - the current query result selection.
//  ParentRow - ValueTreeRow - a parent row of the value tree:
//   * Description - String
//
Procedure AddQuestionnaireTreeRows(Selection, ParentRow, RecursionLevel, Form)

	While Selection.Next() Do

		If Not ValueIsFilled(Selection.ParentQuestion) Then
			NewRow = ParentRow.Rows.Add();
		Else
			ParentRowOfSubordinateQuestion = ParentRow.Rows.Find(Selection.ParentQuestion, "TemplateQuestion");
			If ParentRowOfSubordinateQuestion <> Undefined Then
				NewRow = ParentRowOfSubordinateQuestion.Rows.Add();
			EndIf;
		EndIf;

		NewRow.TemplateQuestion              = Selection.TemplateQuestion;
		NewRow.PictureCode                = SurveysClientServer.GetQuestionnaireTemplatePictureCode(
			Selection.IsSection, Selection.QuestionType);
		NewRow.QuestionType                 = Selection.QuestionType;
		NewRow.TabularQuestionType       = Selection.TabularQuestionType;
		NewRow.ToolTip                  = Selection.ToolTip;
		NewRow.HintPlacement = Selection.HintPlacement;
		NewRow.ShouldUseRefusalToAnswer = Selection.ShouldUseRefusalToAnswer;
		NewRow.RefusalToAnswerText = Selection.RefusalToAnswerText;

		NewRow.RowType            = ?(Selection.IsSection, "Section", "DoQueryBox");
		If Form.FormName = "Catalog.QuestionnaireTemplates.Form.ItemForm" Then
			NewRow.ElementaryQuestion = ?(Selection.IsSection, Selection.Description, ?(Selection.QuestionType
				<> Enums.QuestionnaireTemplateQuestionTypes.Tabular, Selection.ElementaryQuestion, Selection.Wording));
			NewRow.IsRequired       = ?(Selection.IsSection, Undefined, ?(Selection.QuestionType
				<> Enums.QuestionnaireTemplateQuestionTypes.Tabular, Selection.IsRequired, Undefined));
			NewRow.Wording       = ?(Selection.IsSection, Selection.Description, Selection.Wording);
			NewRow.Notes            = Selection.Notes;
			NewRow.HasNotes        = Not IsBlankString(Selection.Notes);
		Else
			NewRow.Wording       = Selection.Wording;
			NewRow.ElementaryQuestion = Selection.ElementaryQuestion;
			NewRow.IsRequired       = Selection.IsRequired;
		EndIf;

		NewRow.Description                      = Selection.Description;
		NewRow.ReplyType                         = Selection.ReplyType;
		NewRow.TableQuestionComposition           = Selection.TableQuestionComposition.Unload();
		NewRow.TableQuestionComposition.Sort("LineNumber Asc");
		NewRow.PredefinedAnswers            = Selection.PredefinedAnswers.Unload();
		NewRow.PredefinedAnswers.Sort("LineNumber Asc");
		NewRow.ComplexQuestionComposition         = Selection.ComplexQuestionComposition.Unload();
		NewRow.TableQuestionComposition.Sort("LineNumber Asc");
		NewRow.NumericalQuestionHintsRange = Selection.NumericalQuestionHintsRange.Unload();
		NewRow.NumericalQuestionHintsRange.Sort("LineNumber Desc");
		NewRow.Composite                        = New UUID;
		NewRow.Length                             = Selection.Length;
		NewRow.MinValue               = Selection.MinValue;
		NewRow.MaxValue              = Selection.MaxValue;
		NewRow.ShouldUseMinValue   = Selection.ShouldUseMinValue;
		NewRow.ShouldUseMaxValue  = Selection.ShouldUseMaxValue;
		NewRow.CommentRequired              = Selection.CommentRequired;
		NewRow.CommentNote              = Selection.CommentNote;
		NewRow.ValueType                       = ?(Selection.ValueType = Null, Undefined, Selection.ValueType);
		NewRow.Accuracy                          = Selection.Accuracy;

		SubordinateSelection = Selection.Select(QueryResultIteration.ByGroupsWithHierarchy);
		If SubordinateSelection.Count() > 0 Then
			AddQuestionnaireTreeRows(SubordinateSelection, NewRow, RecursionLevel + 1, Form);
		EndIf;

	EndDo;

EndProcedure

// Executes a query by a questionnaire template to generate a questionnaire tree in forms.
//
// Parameters:
//   QuestionnaireTemplate - CatalogRef.QuestionnaireTemplates - a reference to a questionnaire template, according to which the query will be executed.
//
// Returns
//   QueryResult - a result of query by a questionnaire template.
//
Function ExecuteQueryByQuestionnaireTemplateQuestions(QuestionnaireTemplate)

	Query = New Query;
	Query.Text =
	"SELECT
	|	QuestionnaireTemplateQuestions.Ref AS TemplateQuestion,
	|	QuestionnaireTemplateQuestions.Parent AS Parent,
	|	QuestionnaireTemplateQuestions.Description AS Description,
	|	QuestionnaireTemplateQuestions.IsRequired AS IsRequired,
	|	QuestionnaireTemplateQuestions.QuestionType AS QuestionType,
	|	QuestionnaireTemplateQuestions.TabularQuestionType AS TabularQuestionType,
	|	QuestionnaireTemplateQuestions.ElementaryQuestion AS ElementaryQuestion,
	|	QuestionnaireTemplateQuestions.IsFolder AS IsSection,
	|	QuestionnaireTemplateQuestions.ParentQuestion AS ParentQuestion,
	|	QuestionnaireTemplateQuestions.ToolTip AS ToolTip,
	|	QuestionnaireTemplateQuestions.HintPlacement AS HintPlacement,
	|	QuestionnaireTemplateQuestions.TableQuestionComposition.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion
	|	) AS TableQuestionComposition,
	|	QuestionnaireTemplateQuestions.PredefinedAnswers.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion,
	|		Response AS Response
	|	) AS PredefinedAnswers,
	|	QuestionnaireTemplateQuestions.ComplexQuestionComposition.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion
	|	) AS ComplexQuestionComposition,
	|	ISNULL(QuestionsForSurvey.Length, 0) AS Length,
	|	QuestionsForSurvey.ValueType AS ValueType,
	|	ISNULL(QuestionsForSurvey.CommentRequired, FALSE) AS CommentRequired,
	|	ISNULL(QuestionsForSurvey.CommentNote, """") AS CommentNote,
	|	ISNULL(QuestionsForSurvey.MinValue, 0) AS MinValue,
	|	ISNULL(QuestionsForSurvey.MaxValue, 0) AS MaxValue,
	|	ISNULL(QuestionsForSurvey.ShouldUseMinValue, FALSE) AS ShouldUseMinValue,
	|	ISNULL(QuestionsForSurvey.ShouldUseMaxValue, FALSE) AS ShouldUseMaxValue,
	|	ISNULL(QuestionsForSurvey.ReplyType, VALUE(Enum.TypesOfAnswersToQuestion.EmptyRef)) AS ReplyType,
	|	ISNULL(QuestionnaireTemplateQuestions.Wording, """") AS Wording,
	|	ISNULL(QuestionsForSurvey.Accuracy, 0) AS Accuracy,
	|	QuestionnaireTemplateQuestions.Notes AS Notes,
	|	QuestionnaireTemplateQuestions.ShouldUseRefusalToAnswer AS ShouldUseRefusalToAnswer,
	|	QuestionnaireTemplateQuestions.RefusalToAnswerText AS RefusalToAnswerText,
	|	QuestionsForSurvey.NumericalQuestionHintsRange.(
	|		ValueUpTo AS ValueUpTo,
	|		ToolTip AS ToolTip,
	|		LineNumber AS LineNumber
	|	) AS NumericalQuestionHintsRange
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|		LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON QuestionnaireTemplateQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|WHERE
	|	NOT QuestionnaireTemplateQuestions.DeletionMark
	|	AND QuestionnaireTemplateQuestions.Owner = &Owner
	|
	|ORDER BY
	|	QuestionnaireTemplateQuestions.Ref HIERARCHY";

	Query.SetParameter("Owner", QuestionnaireTemplate);

	Return Query.Execute();

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Generating a questionnaire filling form.

// Parameters:
//  Form  - See Document.Questionnaire.Form.DocumentForm
//                              See CommonForm.QuestionnaireBySectionWizard
//  CurrentDataSectionsTree - FormDataTreeItem - the current section, for which the filling form is created, where:
//   * Ref - CatalogRef.QuestionnaireTemplateQuestions
//
Procedure CreateFillingFormBySection(Form, CurrentDataSectionsTree) Export

	AttributesToBeAdded = New Array;
	Form.SectionQuestionsTable.Clear();

	ItemLabelIntroduction = Form.Items.IntroductionLabel; //FormField
	If CurrentDataSectionsTree.RowType = "Section" Then

		ItemLabelIntroduction.Title  = NStr("en = 'Section';") + " " + CurrentDataSectionsTree.Wording;
		ItemLabelIntroduction.TextColor =  StyleColors.FunctionsPanelSectionColor;
		ItemLabelIntroduction.Font = StyleFonts.LargeTextFont;

		Section = CurrentDataSectionsTree.Ref;
		FullSectionCode = CurrentDataSectionsTree.FullCode;
		
		// 
		Form.SectionQuestionsTable.Clear();
		GetInformationOnQuestionnaireQuestions(Form, Form.QuestionnaireTemplate, Section, FullSectionCode);
		GenerateAttributesToAddForSection(AttributesToBeAdded, Form);

	Else

		Introduction = ?(IsBlankString(Form.Introduction), NStr("en = 'Click Next to fill out the questionnaire.';"),
			Form.Introduction);
		ClosingStatement = ?(IsBlankString(Form.ClosingStatement), NStr("en = 'Thank you for filling out the questionnaire.';"),
			Form.ClosingStatement);

		ItemLabelIntroduction.Title = ?(CurrentDataSectionsTree.RowType = "Introduction", Introduction,
			ClosingStatement);
		ItemLabelIntroduction.TextColor = StyleColors.FieldTextColor;
		ItemLabelIntroduction.Font = StyleFonts.LargeTextFont;

	EndIf;

	Form.ChangeAttributes(AttributesToBeAdded, Form.DynamicallyAddedAttributes.UnloadValues());
	
	// Deleting form items dynamically generated previously.
	DeleteFillingFormItems(Form, Form.DynamicallyAddedAttributes);
	Form.DynamicallyAddedAttributes.Clear();
	For Each AddedAttribute In AttributesToBeAdded Do
		If IsBlankString(AddedAttribute.Path) Then
			Form.DynamicallyAddedAttributes.Add(AddedAttribute.Name);
		EndIf;
	EndDo;

	If CurrentDataSectionsTree.RowType = "Section" Then
		// Add form items.
		GenerateFormItemsForSection(Form);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Creating attributes of the questionnaire filling form.

// Parameters:
//  AttributesToBeAdded - Array - used to accumulate form attributes to be created.
//  Form                - ClientApplicationForm - a form, for which an array of attributes is generated.
//
Procedure GenerateAttributesToAddForSection(AttributesToBeAdded, Form)

	For Each String In Form.SectionQuestionsTable Do

		AddAttributesForQuestion(String, AttributesToBeAdded, Form);

	EndDo;

EndProcedure

// Parameters:
//  TreeRow         - ValueTreeRow - a row of the questionnaire template tree.
//  AttributesToBeAdded - Array - used to accumulate form attributes to be added.
//
Procedure AddAttributesForQuestion(TreeRow, AttributesToBeAdded, Form)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);

	RowTypeDetails = New TypeDescription("String");
	AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Wording", RowTypeDetails));

	If TreeRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then
		AddAttributesTabularQuestion(TreeRow, AttributesToBeAdded, Form);
	ElsIf TreeRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then
		AddAttributesComplexQuestion(TreeRow, AttributesToBeAdded, Form);
	Else

		If TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.String Or TreeRow.ReplyType
			= Enums.TypesOfAnswersToQuestion.Text Then

			RowTypeDetails = New TypeDescription("String", , New StringQualifiers(TreeRow.Length));
			AttributesToBeAdded.Add(New FormAttribute(QuestionName, RowTypeDetails, ,
				TreeRow.Wording));

		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then
			BooleanTypeDetails = New TypeDescription("Boolean");
			AttributesToBeAdded.Add(New FormAttribute(QuestionName, BooleanTypeDetails, ,
				TreeRow.Wording));
		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.Date Then
			DateTypeDetails = New TypeDescription("Date", New DateQualifiers(DateFractions.Date));
			AttributesToBeAdded.Add(New FormAttribute(QuestionName, DateTypeDetails, ,
				TreeRow.Wording));
		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.Number Then

			TypeDescriptionNumber = New TypeDescription("Number", , , New NumberQualifiers(TreeRow.Length,
				TreeRow.Accuracy));
			AttributesToBeAdded.Add(New FormAttribute(QuestionName, TypeDescriptionNumber, ,
				TreeRow.Wording));

			If TreeRow.ShouldShowRangeSlider Then
				TypeDescriptionNumber = New TypeDescription("Number", , , New NumberQualifiers(15, 2));
				AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_RangeSliderAttribute",
					TypeDescriptionNumber, , TreeRow.Wording));
			EndIf;

		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.InfobaseValue Then

			AttributesToBeAdded.Add(New FormAttribute(QuestionName, TreeRow.ValueType, ,
				TreeRow.Wording));

		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, Form);
			Counter = 0;
			For Each AnswerOption In OptionsOfAnswersToQuestion Do
				Counter = Counter + 1;
				AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Attribute_" + Counter,
					TreeRow.ValueType, , TreeRow.Wording));
			EndDo;

		ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, Form);
			RowTypeDetails = New TypeDescription("String", , New StringQualifiers(150));
			BooleanTypeDetails = New TypeDescription("Boolean");

			Counter = 0;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do
				Counter = Counter + 1;
				AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Attribute_" + Counter,
					BooleanTypeDetails, , AnswerOption.Presentation));
				If AnswerOption.OpenEndedQuestion Then
					AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Comment_" + Counter,
						RowTypeDetails));
				EndIf;
			EndDo;

		EndIf;

		If (TreeRow.ReplyType <> Enums.TypesOfAnswersToQuestion.MultipleOptionsFor)
			And (TreeRow.CommentRequired) Then
			RowTypeDetails = New TypeDescription("String", , New StringQualifiers(150));
			AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Comment", RowTypeDetails, ,
				TreeRow.CommentNote));
		EndIf;

		If TreeRow.ShouldUseRefusalToAnswer Then
			BooleanTypeDetails = New TypeDescription("Boolean");
			AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_ShouldUseRefusalToAnswer",
				BooleanTypeDetails, , TreeRow.RefusalToAnswerText));
		EndIf;

	EndIf;

EndProcedure

// Parameters:
//  TreeRow         - ValueTreeRow - a row of the questionnaire template tree.
//  AttributesToBeAdded - Array - used to accumulate form attributes to be added.
//
Procedure AddAttributesTabularQuestion(TreeRow, AttributesToBeAdded, Form)

	TabularQuestionType = TreeRow.TabularQuestionType;
	QuestionName           = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName           = QuestionName + "_Table";
	NameOfColumnWithoutNumber  = TableName + "_Column_";
	CCTTypesDetails     = Metadata.ChartsOfCharacteristicTypes.QuestionsForSurvey.Type;

	AttributeTable = New FormAttribute(TableName, New TypeDescription("ValueTable"), ,
		TreeRow.Wording);
	AttributesToBeAdded.Add(AttributeTable);

	If TabularQuestionType = Enums.TabularQuestionTypes.Composite Or TabularQuestionType
		= Enums.TabularQuestionTypes.PredefinedAnswersInRows Then

		For Indus = 1 To TreeRow.TableQuestionComposition.Count() Do

			FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
				TreeRow.TableQuestionComposition[Indus - 1].ElementaryQuestion));
			If FoundRows.Count() > 0 Then
				QuestionTypePresentation = FoundRows[0];
			Else
				Continue;
			EndIf;

			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(Indus),
				QuestionTypePresentation.Type, TableName, QuestionTypePresentation.Wording));

		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then
		
		// Question, the answers to which will be displayed in columns.
		QuestionForColumns = TreeRow.TableQuestionComposition[0].ElementaryQuestion;
		// 
		AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + "1",
			New TypeDescription("ChartOfCharacteristicTypesRef.QuestionsForSurvey"), TableName));
		
		// Add other columns.
		AnswersArray1 = TreeRow.PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",
			QuestionForColumns));
		For Indus = 1 To AnswersArray1.Count() Do
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(Indus + 1),
				CCTTypesDetails, TableName, AnswersArray1[Indus - 1].Response));
		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then
		
		// 
		QuestionForColumns = TreeRow.TableQuestionComposition[1].ElementaryQuestion;
		
		// Question that defines the type of cells.
		QuestionForCells  = TreeRow.TableQuestionComposition[2].ElementaryQuestion;
		FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox", QuestionForCells));
		If FoundRows.Count() > 0 Then
			QuestionTypePresentationForCells = FoundRows[0];
		Else
			Return;
		EndIf;
		
		// Question, the answers to which will be displayed in rows of the first column.
		QuestionForRows  = TreeRow.TableQuestionComposition[0].ElementaryQuestion;
		FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox", QuestionForRows));
		If FoundRows.Count() > 0 Then
			QuestionTypePresentationForRows = FoundRows[0];
		Else
			Return;
		EndIf;
		// 
		AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + "1",
			QuestionTypePresentationForRows.Type, TableName, QuestionTypePresentationForRows.Wording));
		
		// 
		AnswersArray1 = TreeRow.PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",
			QuestionForColumns));
		For Indus = 1 To AnswersArray1.Count() Do
			AttributesToBeAdded.Add(New FormAttribute(NameOfColumnWithoutNumber + XMLString(Indus + 1),
				QuestionTypePresentationForCells.Type, TableName, AnswersArray1[Indus - 1].Response));
		EndDo;

	EndIf;

EndProcedure

// Parameters:
//  TreeRow         - ValueTreeRow - a row of the questionnaire template tree.
//  AttributesToBeAdded - Array - used to accumulate form attributes to be added.
//
Procedure AddAttributesComplexQuestion(TreeRow, AttributesToBeAdded, Form)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);
	For Each ComplexQuestionRow In TreeRow.ComplexQuestionComposition Do // LineOfATabularSection of See СправочникТабличнаяЧасть.ВопросыШаблонаАнкеты.CatalogTabularSection.ВопросыШаблонаАнкеты.СоставКомплексногоВопроса

		FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
			ComplexQuestionRow.ElementaryQuestion));
		If FoundRows.Count() > 0 Then
			QuestionTypePresentation = FoundRows[0];
		Else
			Continue;
		EndIf;

		If QuestionTypePresentation.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(ComplexQuestionRow.ElementaryQuestion, Form);

			RowTypeDetails = New TypeDescription("String", , New StringQualifiers(150));
			BooleanTypeDetails = New TypeDescription("Boolean");

			Counter = 0;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do

				Counter = Counter + 1;
				AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Response_" + Format(
					ComplexQuestionRow.LineNumber, "NG=") + "_Attribute_" + Counter, BooleanTypeDetails, ,
					AnswerOption.Presentation));

				If AnswerOption.OpenEndedQuestion Then
					AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Response_" + Format(
						ComplexQuestionRow.LineNumber, "NG=") + "_Comment_" + Counter, RowTypeDetails));
				EndIf;

			EndDo;

		Else

			AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Response_" + Format(
				ComplexQuestionRow.LineNumber, "NG="), QuestionTypePresentation.Type, ,
				QuestionTypePresentation.Wording));

		EndIf;

		If (QuestionTypePresentation.ReplyType <> Enums.TypesOfAnswersToQuestion.MultipleOptionsFor)
			And (ComplexQuestionRow.CommentRequired) Then

			RowTypeDetails = New TypeDescription("String", , New StringQualifiers(150));
			AttributesToBeAdded.Add(New FormAttribute(QuestionName + "_Comment_" + Format(
				ComplexQuestionRow.LineNumber, "NG="), RowTypeDetails, ,
				ComplexQuestionRow.CommentNote));

		EndIf;

	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Creating questionnaire filling form items.

Procedure GenerateFormItemsForSection(Form)

	For Each TableRow In Form.SectionQuestionsTable Do
		AddFormItemsByTableRow(TableRow, Form.Items.QuestionnaireBodyGroup, Form);
	EndDo;
	PositionOnFirstSectionQuestion(Form);

EndProcedure

// Parameters:
//   Form - See Document.Questionnaire.Form.DocumentForm
//
Procedure PositionOnFirstSectionQuestion(Form)

	If Form.SectionQuestionsTable.Count() > 0 Then

		QuestionName = SurveysClientServer.QuestionName(Form.SectionQuestionsTable[0].Composite);

		FoundItem = Form.Items.Find(QuestionName);
		If FoundItem = Undefined Then
			FoundItem = Form.Items.Find(QuestionName + "_Attribute_1");
		EndIf;

		If FoundItem = Undefined Then
			FoundItem = Form.Items.Find(QuestionName + "_Table");
		EndIf;

		If FoundItem <> Undefined Then
			Form.CurrentItem = FoundItem;
			FoundItem.DefaultItem = True;
			Form.PositioningItemName = FoundItem.Name;
		EndIf;

	EndIf;

EndProcedure

// Parameters:
//  TreeRow    - ValueTreeRow - a row of the questionnaire template tree.
//  GroupItem   - FormGroup          - a form group, for which attributes being added are subordinated.
//  Form           - ClientApplicationForm - a form, for which items are added.
//
Procedure AddFormItemsByTableRow(TableRow, GroupItem, Form)

	If TableRow.RowType = "Section" Then
		AddItemsSection(TableRow, GroupItem, Form);
	ElsIf TableRow.RowType = "DoQueryBox" Then
		AddQuestionItems(TableRow, GroupItem, Form);
	EndIf;

EndProcedure

// Parameters:
//  TreeRow    - ValueTreeRow - a row of the questionnaire template tree.
//  GroupItem   - FormGroup - a form group, for which attributes being added are subordinated.
//  Form           - ClientApplicationForm - a form, for which items are added.
//
Procedure AddItemsSection(TableRow, GroupItem, Form)

	SectionName = "Section_" + StrReplace(TableRow.Composite, "-", "_");

	SectionItem = Form.Items.Add(SectionName, Type("FormGroup"), GroupItem);
	SectionItem.Type           = FormGroupType.UsualGroup;
	SectionItem.Title     = FullCodeDescription(TableRow);
	SectionItem.Group   = ChildFormItemsGroup.Vertical;
	SectionItem.VerticalStretch = False;

EndProcedure

// Parameters:
//  TableRow - FormDataCollectionItem - a row of the section questions table.
//  GroupItem - FormGroup - a form group, for which attributes being added are subordinated.
//  Form         - ClientApplicationForm - a form, for which items are added.
//
Procedure AddQuestionItems(TableRow, GroupItem1, Form)

	QuestionName = SurveysClientServer.QuestionName(TableRow.Composite);
	
	// Setting group item for the question.
	QuestionGroupItem = Form.Items.Add(QuestionName + "_Group", Type("FormGroup"), GroupItem1);
	QuestionGroupItem.Type                        = FormGroupType.UsualGroup;
	QuestionGroupItem.ShowTitle        = False;
	QuestionGroupItem.Representation                = UsualGroupRepresentation.NormalSeparation;
	QuestionGroupItem.Group                = ChildFormItemsGroup.Vertical;
	QuestionGroupItem.HorizontalStretch   = True;
	QuestionGroupItem.VerticalStretch     = False;

	If TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then

		QuestionGroupItemBoolean = Form.Items.Add(
			QuestionName + "GroupBoolean", Type("FormGroup"), QuestionGroupItem);
		QuestionGroupItemBoolean.Type                        = FormGroupType.UsualGroup;
		QuestionGroupItemBoolean.ShowTitle        = False;
		QuestionGroupItemBoolean.Representation                = UsualGroupRepresentation.None;
		QuestionGroupItemBoolean.Group                = ChildFormItemsGroup.AlwaysHorizontal;
		QuestionGroupItemBoolean.HorizontalStretch   = True;
		QuestionGroupItemBoolean.VerticalStretch     = False;

	EndIf;

	Form[QuestionName + "_Wording"] = FullCodeDescription(TableRow);

	If TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then
		Item = Form.Items.Add(
			QuestionName + "_Wording", Type("FormDecoration"), QuestionGroupItemBoolean);
	Else
		Item = Form.Items.Add(
			QuestionName + "_Wording", Type("FormDecoration"), QuestionGroupItem); // FormDecorationExtensionForALabel
	EndIf;
	Item.Type                      = FormDecorationType.Label;
	Item.VerticalAlign    = ItemVerticalAlign.Top;
	Item.Title                = Form[QuestionName + "_Wording"];
	Item.AutoMaxWidth   = False;
	Item.MaxWidth       = 100;
	Item.HorizontalStretch = False;
	Item.VerticalStretch   = False;
	Item.ToolTip                = TableRow.ToolTip;
	Item.Font                    = StyleFonts.ImportantLabelFont;

	If TableRow.HintPlacement = Enums.TooltipDisplayMethods.AsQuestionMark Then
		Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	Else
		Item.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	EndIf;

	QuestionGroupItemComment = Form.Items.Add(QuestionName + "GroupQuestionComment", Type(
		"FormGroup"), QuestionGroupItem);
	QuestionGroupItemComment.Type                 = FormGroupType.UsualGroup;
	QuestionGroupItemComment.Representation         = UsualGroupRepresentation.None;
	QuestionGroupItemComment.Group         = ChildFormItemsGroup.Vertical;
	QuestionGroupItemComment.ShowTitle = False;

	If TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then

		AddTabularQuestionItems(TableRow, QuestionGroupItem, Form);

	ElsIf TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then

		AddComplexQuestionItems(TableRow, QuestionGroupItem, Form);

	Else

		If TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.String
			Or TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.InfobaseValue Then

			Item = Form.Items.Add(QuestionName, Type("FormField"), QuestionGroupItemComment);
			Item.Type                        = FormFieldType.InputField;
			Item.TitleLocation         = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete  = TableRow.IsRequired;
			Item.DataPath                = QuestionName;
			Item.AutoMaxWidth     = False;
			Item.HorizontalStretch   = False;

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then

			Item = Form.Items.Add(QuestionName, Type("FormField"), QuestionGroupItemComment);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired;
			Item.DataPath               = QuestionName;
			Item.VerticalStretch    = False;
			Item.AutoMaxWidth    = False;
			SetTextCellItemParameters(Item);

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then

			Item = Form.Items.Add(QuestionName, Type("FormField"), QuestionGroupItemBoolean);
			If TableRow.CheckBoxType = Enums.CheckBoxKindsInQuestionnaires.CheckBox Then
				Item.Type = FormFieldType.CheckBoxField;
			Else
				Item.Type = FormFieldType.InputField;
			EndIf;

			Item.TitleLocation = FormItemTitleLocation.None;
			Item.DataPath        = QuestionName;

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Date Then

			Item = Form.Items.Add(QuestionName, Type("FormField"), QuestionGroupItemComment);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired;
			Item.DataPath               = QuestionName;
			Item.AutoMaxWidth    = False;

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.Number Then

			Item = Form.Items.Add(QuestionName, Type("FormField"), QuestionGroupItemComment);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired
				And Not CanNumericFieldTakeZero(TableRow);
			Item.MinValue       = ?(TableRow.ShouldUseMinValue,
				TableRow.MinValue, Undefined);
			Item.MaxValue      = ?(TableRow.ShouldUseMaxValue,
				TableRow.MaxValue, Undefined);
			Item.ChoiceButton              = False;
			Item.DataPath               = QuestionName;
			Item.AutoMaxWidth    = False;
			If TableRow.MinValue <> 0 Or TableRow.MaxValue <> 0 Then
				Item.SpinButton = True;

				ToolTipText = "";
				If TableRow.ShouldUseMinValue And TableRow.ShouldUseMaxValue Then
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value from %1 to %2';"), TableRow.MinValue,
						TableRow.MaxValue);
				ElsIf Not TableRow.ShouldUseMinValue
					And TableRow.ShouldUseMaxValue Then
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value to %1';"), TableRow.MaxValue);
				Else
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value from %1';"), TableRow.MinValue);
				EndIf;

				Item.ToolTip = ToolTipText;

			EndIf;

			If TableRow.ShouldShowRangeSlider Then

				ItemGroupRangeSlider = Form.Items.Add(QuestionName + "_Group_Question_Slider", Type(
					"FormGroup"), QuestionGroupItem);
				ItemGroupRangeSlider.Type                 = FormGroupType.UsualGroup;
				ItemGroupRangeSlider.Representation         = UsualGroupRepresentation.None;
				ItemGroupRangeSlider.Group         = ChildFormItemsGroup.AlwaysHorizontal;
				ItemGroupRangeSlider.ShowTitle = False;

				ItemSlider = Form.Items.Add(QuestionName + "_TrackBar", Type("FormField"),
					ItemGroupRangeSlider);
				ItemSlider.Type = FormFieldType.TrackBarField;
				ItemSlider.MarkingAppearance = TrackBarMarkingAppearance.BothSides;
				ItemSlider.TitleLocation        = FormItemTitleLocation.None;
				SliderLength = TableRow.MaxValue - TableRow.MinValue;
				ItemSlider.MinValue = 0;
				ItemSlider.MaxValue = SliderLength / TableRow.RangeSliderStep;
				ItemSlider.MarkingStep = 1;
				ItemSlider.Step = 1;
				ItemSlider.LargeStep = 1;
				ItemSlider.DataPath               = QuestionName + "_RangeSliderAttribute";
				ItemSlider.HorizontalStretch = False;
				ItemSlider.MarkingAppearance = TrackBarMarkingAppearance.BothSides;
				ItemSlider.SetAction("OnChange", "Attachable_OnChangeRangeSlider");

				Form.Items.Move(Item, ItemGroupRangeSlider);
				Form.Items.Move(QuestionGroupItemComment, QuestionGroupItem);

				Item.SetAction("OnChange", "Attachable_OnChangeOfNumberField");
				Item.SetAction("Tuning", "Attachable_NumberFieldAdjustment");

				ItemDrilldown = Form.Items.Add(
					QuestionName + "_TooltipBreakdown", Type("FormDecoration"), ItemGroupRangeSlider);
				ItemDrilldown.TextColor = StyleColors.NoteText;

			Else

				ItemDrilldown = Form.Items.Add(
					QuestionName + "_TooltipBreakdown", Type("FormDecoration"), QuestionGroupItemComment);
				ItemDrilldown.TextColor = StyleColors.NoteText;
				QuestionGroupItemComment.Group = ChildFormItemsGroup.AlwaysHorizontal;

			EndIf;

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(TableRow.ElementaryQuestion, Form);
			Counter = 0;

			AnswersOptionsGroupItem = Form.Items.Add(QuestionName + "GroupOptions", Type("FormGroup"),
				QuestionGroupItemComment);
			AnswersOptionsGroupItem.Type                 = FormGroupType.UsualGroup;
			AnswersOptionsGroupItem.Representation         = UsualGroupRepresentation.None;
			AnswersOptionsGroupItem.Group         = ChildFormItemsGroup.AlwaysHorizontal;
			AnswersOptionsGroupItem.ShowTitle = False;

			ItemQuestionsGroup = Form.Items.Add(QuestionName + "_QuestionsGroup", Type("FormGroup"),
				AnswersOptionsGroupItem);
			ItemQuestionsGroup.Type = FormGroupType.UsualGroup;
			ItemQuestionsGroup.Representation = UsualGroupRepresentation.None;
			ItemQuestionsGroup.Group = ChildFormItemsGroup.Vertical;
			ItemQuestionsGroup.ShowTitle = False;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do

				Counter = Counter + 1;

				AnswerOptionGroupItem = Form.Items.Add(QuestionName + "GroupResponseOption" + XMLString(
					Counter), Type("FormGroup"), ItemQuestionsGroup);

				AnswerOptionGroupItem.Type                        = FormGroupType.UsualGroup;
				AnswerOptionGroupItem.Representation                = UsualGroupRepresentation.None;
				AnswerOptionGroupItem.Group                = ChildFormItemsGroup.AlwaysHorizontal;
				AnswerOptionGroupItem.ShowTitle        = False;
				AnswerOptionGroupItem.HorizontalStretch   = True;

				QuestionAttributeName1 = QuestionName + "_Attribute_" + Counter;
				Item = Form.Items.Add(QuestionAttributeName1, Type("FormField"), AnswerOptionGroupItem);
				Item.Type                     = FormFieldType.RadioButtonField;
				Item.TitleLocation      = FormItemTitleLocation.None;
				Item.DataPath             = QuestionAttributeName1;
				Item.ColumnsCount       = 1;
				Item.ItemHeight          = 1;
				Item.HorizontalAlign = ItemHorizontalLocation.Left;
				Item.RadioButtonType = RadioButtonType.RadioButton;
				Item.ColumnsCount = 1;
				Item.ToolTip          = AnswerOption.ToolTip;

				ItemSelectionList = Item.ChoiceList;
				ItemSelectionList.Add(AnswerOption.Response, AnswerOption.Presentation);

			EndDo;

			ItemGroupTooltip = Form.Items.Add(QuestionName + "_TooltipGroup", Type("FormGroup"),
				AnswersOptionsGroupItem);
			ItemGroupTooltip.Type = FormGroupType.UsualGroup;
			ItemGroupTooltip.Representation = UsualGroupRepresentation.None;
			ItemGroupTooltip.Group = ChildFormItemsGroup.Vertical;
			ItemGroupTooltip.ShowTitle = False;

			ItemDrilldown = Form.Items.Add(
				QuestionName + "_TooltipBreakdown", Type("FormDecoration"), ItemGroupTooltip);
			ItemDrilldown.AutoMaxWidth = False;
			ItemDrilldown.HorizontalStretch = True;
			ItemDrilldown.TextColor = StyleColors.NoteText;

		ElsIf TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(TableRow.ElementaryQuestion, Form);
			Counter = 0;

			AnswersOptionsGroupItem = Form.Items.Add(QuestionName + "GroupOptions", Type("FormGroup"),
				QuestionGroupItemComment);

			AnswersOptionsGroupItem.Type                 = FormGroupType.UsualGroup;
			AnswersOptionsGroupItem.Representation         = UsualGroupRepresentation.None;
			AnswersOptionsGroupItem.Group         = ChildFormItemsGroup.Vertical;
			AnswersOptionsGroupItem.ShowTitle = False;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do

				Counter = Counter + 1;

				AnswerOptionGroupItem = Form.Items.Add(QuestionName + "GroupResponseOption" + XMLString(
					Counter), Type("FormGroup"), AnswersOptionsGroupItem);

				AnswerOptionGroupItem.Type                        = FormGroupType.UsualGroup;
				AnswerOptionGroupItem.Representation                = UsualGroupRepresentation.None;
				AnswerOptionGroupItem.Group                = ChildFormItemsGroup.AlwaysHorizontal;
				AnswerOptionGroupItem.ShowTitle        = False;
				AnswerOptionGroupItem.HorizontalStretch   = True;

				QuestionAttributeName1 = QuestionName + "_Attribute_" + Counter;
				Item = Form.Items.Add(QuestionAttributeName1, Type("FormField"), AnswerOptionGroupItem);

				Item.Type                = FormFieldType.CheckBoxField;
				Item.TitleLocation = FormItemTitleLocation.Right;
				Item.DataPath        = QuestionAttributeName1;
				Item.TitleHeight    = 1;
				Item.ToolTip          = AnswerOption.ToolTip;

				If AnswerOption.OpenEndedQuestion Then
					CommentAttributeName = QuestionName + "_Comment_" + Counter;
					Item = Form.Items.Add(CommentAttributeName, Type("FormField"),
						AnswerOptionGroupItem);
					Item.Type 		= FormFieldType.CheckBoxField;
					Item.DataPath	= CommentAttributeName;
					Item.TitleLocation = FormItemTitleLocation.None;
				EndIf;

			EndDo;

		EndIf;

		If TableRow.ShouldUseRefusalToAnswer And TableRow.ReplyType
			<> Enums.TypesOfAnswersToQuestion.Boolean Then
			Item = Form.Items.Add(QuestionName + "_ShouldUseRefusalToAnswer", Type("FormField"),
				QuestionGroupItem);
			Item.Type = FormFieldType.CheckBoxField;
			Item.DataPath = QuestionName + "_ShouldUseRefusalToAnswer";
			Item.TitleLocation = FormItemTitleLocation.Right;
		EndIf;
		
		If (TableRow.ReplyType <> Enums.TypesOfAnswersToQuestion.MultipleOptionsFor)
			And (TableRow.CommentRequired) Then

			Item                        = Form.Items.Add(QuestionName + "_Comment", Type("FormField"),
				QuestionGroupItemComment);
			Item.Type                    = FormFieldType.InputField;
			Item.DataPath            = QuestionName + "_Comment";
			Item.AutoMaxWidth = False;
			Item.InputHint = TableRow.CommentNote;
			Item.TitleLocation = FormItemTitleLocation.None;
			Item.HorizontalStretch = False;
			Item.ChoiceButton = True;
		EndIf;

	EndIf;

EndProcedure

// Parameters:
//  TableRow - FormDataCollectionItem - a row of the section questions table.
//  GroupItem - FormGroup - a form group, for which attributes being added are subordinated.
//  Form         - ClientApplicationForm
//
Procedure AddTabularQuestionItems(TableRow, GroupItem1, Form)

	TabularQuestionType = TableRow.TabularQuestionType;
	QuestionName = SurveysClientServer.QuestionName(TableRow.Composite);
	TableName = QuestionName + "_Table";
	
	ItemTable = Form.Items.Add(TableName, Type("FormTable"), GroupItem1);

	If TabularQuestionType = Enums.TabularQuestionTypes.Composite Then
		ItemTable.CommandBarLocation = FormItemCommandBarLabelLocation.Top;
	Else
		ItemTable.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		ItemTable.ChangeRowSet  = False;
		ItemTable.ChangeRowOrder = False;
	EndIf;
	ItemTable.TitleLocation       = FormItemTitleLocation.None;
	ItemTable.DataPath              = TableName;
	ItemTable.HorizontalStretch = True;
	ItemTable.VerticalStretch   = False;
	
	QuestionTable = Form.FormAttributeToValue(TableName);

	If TableRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns
		And TableRow.TableQuestionComposition.Count() = 3 Then

		FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
			TableRow.TableQuestionComposition[2].ElementaryQuestion));
		If FoundRows.Count() > 0 Then
			ElementaryQuestionAttributes = FoundRows[0];
		Else
			Return;
		EndIf;

	ElsIf TableRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns
		And TableRow.TableQuestionComposition.Count() > 1 Then

	EndIf;

	For Indus = 1 To QuestionTable.Columns.Count() Do

		ColumnName = TableName + "_Column_" + Indus;

		If TableRow.TabularQuestionType <> Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns
			And TableRow.TabularQuestionType <> Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then
			FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
				TableRow.TableQuestionComposition[Indus - 1].ElementaryQuestion));
			If FoundRows.Count() > 0 Then
				ElementaryQuestionAttributes = FoundRows[0];
			Else
				Continue;
			EndIf;
		EndIf;

		Item = Form.Items.Add(ColumnName, Type("FormField"), Form.Items[TableName]); // FormField
		Item.EditMode = ColumnEditMode.Directly;

		If QuestionTable.Columns[ColumnName].ValueType = New TypeDescription("Boolean") Then
			Item.Type = FormFieldType.CheckBoxField;
		Else
			Item.Type = FormFieldType.InputField;
			
			// 
			// 
			If TableRow.TabularQuestionType = Enums.TabularQuestionTypes.Composite Or TableRow.TabularQuestionType
				= Enums.TabularQuestionTypes.PredefinedAnswersInRows Then

				If QuestionTable.Columns[ColumnName].ValueType
					= New TypeDescription("CatalogRef.QuestionnaireAnswersOptions") Then

					Item.ListChoiceMode = True;
					OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(TableRow.TableQuestionComposition[Indus
						- 1].ElementaryQuestion, Form);
					For Each OptionOfAnswerToQuestion In OptionsOfAnswersToQuestion Do
						ItemSelectionList = Item.ChoiceList; // ValueList
						ItemSelectionList.Add(OptionOfAnswerToQuestion.Response);
					EndDo;
					Item.OpenButton = False;

				ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Number Then

					SetNumberCellItemParameters(Item, ElementaryQuestionAttributes);

				ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then

					SetTextCellItemParameters(Item);

				EndIf;

			ElsIf TableRow.TabularQuestionType
				= Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then

				If TableRow.TableQuestionComposition.Count() = 3 And Indus <> 1 Then

					If TableRow.TableQuestionComposition[2].ElementaryQuestion.ValueType
						= New TypeDescription("CatalogRef.QuestionnaireAnswersOptions") Then

						Item.ListChoiceMode = True;
						OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(
							TableRow.TableQuestionComposition[2].ElementaryQuestion, Form);
						For Each OptionOfAnswerToQuestion In OptionsOfAnswersToQuestion Do
							ItemSelectionList = Item.ChoiceList; // ValueList
							ItemSelectionList.Add(OptionOfAnswerToQuestion.Response);
						EndDo;
						Item.OpenButton = False;

					EndIf;

					If ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Number Then

						SetNumberCellItemParameters(Item, ElementaryQuestionAttributes);

					ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then

						SetTextCellItemParameters(Item);

					EndIf;

				EndIf;

			EndIf;
		EndIf;

		Item.DataPath = TableName + "." + ColumnName;

		If (TabularQuestionType <> Enums.TabularQuestionTypes.Composite) And (Indus = 1) Then
			Item.Enabled = False;
		EndIf;

		If (TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns) Then
			If Indus = 1 Then
				Item.TitleLocation = FormItemTitleLocation.None;
			Else
				Item.TypeLink = New TypeLink("Items." + TableName + ".CurrentData." + TableName
					+ "_Column_1");
				ChoiceParameterLinks = New Array;
				ChoiceParameterLinks.Add(New ChoiceParameterLink("Filter.Owner", "Items." + TableName
					+ ".CurrentData." + TableName + "_Column_1"));
				Item.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinks);
			EndIf;
		EndIf;

	EndDo;
	
	If TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows 
		Or TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then

		AnswersArray1 = TableRow.PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",
			TableRow.TableQuestionComposition[0].ElementaryQuestion));

		For Each AnswerRow In AnswersArray1 Do

			NewRow = QuestionTable.Add();
			NewRow[TableName + "_Column_1"] = AnswerRow.Response;

		EndDo;

	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then

		For Indus = 2 To TableRow.TableQuestionComposition.Count() Do

			NewRow = QuestionTable.Add();
			NewRow[TableName + "_Column_1"] = TableRow.TableQuestionComposition[Indus - 1].ElementaryQuestion;

		EndDo;

	EndIf;

	If TabularQuestionType <> Enums.TabularQuestionTypes.Composite Then
		ItemTable.HeightInTableRows = QuestionTable.Count() + 1;
	EndIf;

	Form.ValueToFormAttribute(QuestionTable, TableName);

EndProcedure

// Parameters:
//  TableRow - FormDataCollectionItem
//  GroupItem1 - FormGroup
//  Form - ClientApplicationForm
//
Procedure AddComplexQuestionItems(TableRow, GroupItem1, Form)

	QuestionName = SurveysClientServer.QuestionName(TableRow.Composite);
	For Each ComplexQuestionRow In TableRow.ComplexQuestionComposition Do // LineOfATabularSection of See СправочникТабличнаяЧасть.ВопросыШаблонаАнкеты.CatalogTabularSection.ВопросыШаблонаАнкеты.СоставКомплексногоВопроса

		FoundRows = Form.QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
			ComplexQuestionRow.ElementaryQuestion));
		If FoundRows.Count() > 0 Then
			ElementaryQuestionAttributes = FoundRows[0];
		Else
			Continue;
		EndIf;

		If ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then

			QuestionGroupItemBoolean = Form.Items.Add(
				QuestionName + "_ElementaryQuestion_" + Format(ComplexQuestionRow.LineNumber, "NG=")
				+ "GroupBoolean1", Type("FormGroup"), GroupItem1);

			QuestionGroupItemBoolean.Type                        = FormGroupType.UsualGroup;
			QuestionGroupItemBoolean.ShowTitle        = False;
			QuestionGroupItemBoolean.Representation                = UsualGroupRepresentation.None;
			QuestionGroupItemBoolean.Group                = ChildFormItemsGroup.AlwaysHorizontal;
			QuestionGroupItemBoolean.HorizontalStretch   = True;
			QuestionGroupItemBoolean.VerticalStretch     = False;
		EndIf;

		If ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then
			Item = Form.Items.Add(
				QuestionName + "_ElementaryQuestion_" + Format(ComplexQuestionRow.LineNumber, "NG="), Type(
				"FormDecoration"), QuestionGroupItemBoolean);
		Else
			Item = Form.Items.Add(
				QuestionName + "_ElementaryQuestion_" + Format(ComplexQuestionRow.LineNumber, "NG="), Type(
				"FormDecoration"), GroupItem1);
		EndIf;
		Item.Type                        = FormDecorationType.Label;
		Item.Title                  = ComplexQuestionRow.ElementaryQuestion;
		Item.AutoMaxWidth     = False;
		Item.HorizontalStretch   = (ElementaryQuestionAttributes.ReplyType
			<> Enums.TypesOfAnswersToQuestion.Boolean);
		Item.Font = StyleFonts.SmallTextFont;

		If ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.String 
			Or TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.InfobaseValue Then

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), GroupItem1);
			Item.Type                        = FormFieldType.InputField;
			Item.TitleLocation         = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete  = TableRow.IsRequired;
			Item.DataPath                = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG=");
			Item.AutoMaxWidth     = False;
			Item.HorizontalStretch   = False;

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), GroupItem1);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired;
			Item.DataPath               = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG=");
			Item.VerticalStretch    = False;
			Item.AutoMaxWidth    = False;
			SetTextCellItemParameters(Item);

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), QuestionGroupItemBoolean);
			If ElementaryQuestionAttributes.CheckBoxType = Enums.CheckBoxKindsInQuestionnaires.CheckBox Then
				Item.Type = FormFieldType.CheckBoxField;
			Else
				Item.Type = FormFieldType.InputField;
			EndIf;

			Item.TitleLocation = FormItemTitleLocation.None;
			Item.DataPath        = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber, "NG=");

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Date Then

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), GroupItem1);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired;
			Item.DataPath               = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG=");
			Item.AutoMaxWidth    = False;

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.Number Then

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), GroupItem1);
			Item.Type                       = FormFieldType.InputField;
			Item.TitleLocation        = FormItemTitleLocation.None;
			Item.AutoMarkIncomplete = TableRow.IsRequired
				And Not CanNumericFieldTakeZero(TableRow);
			Item.MinValue       = ?(ElementaryQuestionAttributes.ShouldUseMinValue,
				ElementaryQuestionAttributes.MinValue, Undefined);
			Item.MaxValue      = ?(ElementaryQuestionAttributes.ShouldUseMaxValue,
				ElementaryQuestionAttributes.MaxValue, Undefined);
			Item.ChoiceButton              = False;
			Item.DataPath               = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG=");
			Item.AutoMaxWidth    = False;
			If ElementaryQuestionAttributes.MinValue <> 0
				Or ElementaryQuestionAttributes.MaxValue <> 0 Then
				Item.SpinButton = True;

				ToolTipText = "";
				If ElementaryQuestionAttributes.ShouldUseMinValue
					And ElementaryQuestionAttributes.ShouldUseMaxValue Then
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value from %1 to %2';"),
						ElementaryQuestionAttributes.ShouldUseMinValue,
						ElementaryQuestionAttributes.MaxValue);
				ElsIf Not ElementaryQuestionAttributes.ShouldUseMinValue
					And ElementaryQuestionAttributes.ShouldUseMaxValue Then
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value to %1';"), ElementaryQuestionAttributes.MaxValue);
				Else
					ToolTipText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'You can enter value from %1';"), ElementaryQuestionAttributes.MinValue);
				EndIf;

				Item.ToolTip = ToolTipText;

			EndIf;

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(ComplexQuestionRow.ElementaryQuestion, Form);

			Item = Form.Items.Add(QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG="), Type("FormField"), GroupItem1);
			Item.Type                     = FormFieldType.RadioButtonField;
			Item.TitleLocation      = FormItemTitleLocation.None;
			Item.DataPath             = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
				"NG=");
			Item.ItemHeight          = 1;
			Item.HorizontalAlign = ItemHorizontalLocation.Left;

			If ElementaryQuestionAttributes.RadioButtonType = Enums.RadioButtonTypesInQuestionnaires.Tumbler Then
				Item.RadioButtonType = RadioButtonType.Tumbler;
				Item.ColumnsCount = 0;
				Item.EqualColumnsWidth = False;
			Else
				Item.RadioButtonType = RadioButtonType.RadioButton;
				Item.ColumnsCount = 1;
			EndIf;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do
				Item.ChoiceList.Add(AnswerOption.Response, AnswerOption.Presentation);
			EndDo;

		ElsIf ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

			OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(ComplexQuestionRow.ElementaryQuestion, Form);
			Counter = 0;

			AnswersOptionsGroupItem = Form.Items.Add(QuestionName + "_Response_" + Format(
				ComplexQuestionRow.LineNumber, "NG=") + "GroupOptions", Type("FormGroup"), GroupItem1);

			AnswersOptionsGroupItem.Type                 = FormGroupType.UsualGroup;
			AnswersOptionsGroupItem.Representation         = UsualGroupRepresentation.None;
			AnswersOptionsGroupItem.Group         = ChildFormItemsGroup.Vertical;
			AnswersOptionsGroupItem.ShowTitle = False;

			For Each AnswerOption In OptionsOfAnswersToQuestion Do

				Counter = Counter + 1;

				AnswerOptionGroupItem = Form.Items.Add(QuestionName + "_Response_" + Format(
					ComplexQuestionRow.LineNumber, "NG=") + "GroupResponseOption" + XMLString(Counter), Type(
					"FormGroup"), AnswersOptionsGroupItem);

				AnswerOptionGroupItem.Type                        = FormGroupType.UsualGroup;
				AnswerOptionGroupItem.Representation                = UsualGroupRepresentation.None;
				AnswerOptionGroupItem.Group                = ChildFormItemsGroup.AlwaysHorizontal;
				AnswerOptionGroupItem.ShowTitle        = False;
				AnswerOptionGroupItem.HorizontalStretch   = True;

				QuestionAttributeName1 = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber, "NG=")
					+ "_Attribute_" + Counter;
				Item = Form.Items.Add(QuestionAttributeName1, Type("FormField"), AnswerOptionGroupItem);

				Item.Type                = FormFieldType.CheckBoxField;
				Item.TitleLocation = FormItemTitleLocation.Right;
				Item.DataPath        = QuestionAttributeName1;
				Item.TitleHeight    = 1;

				If AnswerOption.OpenEndedQuestion Then
					CommentAttributeName = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
						"NG=") + "_Comment_" + Counter;
					Item = Form.Items.Add(CommentAttributeName, Type("FormField"),
						AnswerOptionGroupItem);
					Item.Type 		= FormFieldType.CheckBoxField;
					Item.DataPath	= CommentAttributeName;
					Item.TitleLocation = FormItemTitleLocation.None;
				EndIf;

			EndDo;

		EndIf;
		
		If (ElementaryQuestionAttributes.ReplyType <> Enums.TypesOfAnswersToQuestion.MultipleOptionsFor)
			And (ComplexQuestionRow.CommentRequired) Then

			Item = Form.Items.Add(QuestionName + "_Comment_" + Format(
				ComplexQuestionRow.LineNumber, "NG="), Type("FormField"), GroupItem1);

			Item.Type                    = FormFieldType.InputField;
			Item.DataPath            = QuestionName + "_Comment_" + Format(
				ComplexQuestionRow.LineNumber, "NG=");
			Item.AutoMaxWidth = False;
			Item.InputHint = ComplexQuestionRow.ElementaryQuestion.CommentNote;
			Item.TitleLocation = FormItemTitleLocation.None;
			Item.HorizontalStretch = False;
			Item.ChoiceButton = True;
		EndIf;

	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures of a questionnaire filling form.

// Parameters:
//  ElementaryQuestion - ChartOfCharacteristicTypesRef.QuestionsForSurvey -
//  Form              - ClientApplicationForm - the form from which the call originates.
//
// Returns:
//   Array of ValueTableRow
//
Function OptionsOfAnswersToQuestion(ElementaryQuestion, Form) Export

	Return (Form.PossibleAnswers.FindRows(New Structure("DoQueryBox", ElementaryQuestion)));

EndFunction

// Parameters:
//   TableRow - FormDataCollectionItem - a row of the section questions table:
//   * Description - String
//
// Returns:
//   String
//
Function FullCodeDescription(TableRow)

	Return ?(TableRow.RowType = "Section", "Section ", "") + TableRow.FullCode + " " + ?(
		TableRow.RowType = "Section", TableRow.Description, TableRow.Wording);

EndFunction

// 
// 
//
// Parameters:
//  Item - FormField - an item, for which parameters are set.
//
Procedure SetTextCellItemParameters(Item)

	Item.ChoiceButton = True;
	Item.MultiLine = True;
	Item.SetAction("StartChoice", "Attachable_StartChoiceOfTableQuestionsTextCells");

EndProcedure

// Parameters:
//  Item - FormField - an item, for which parameters are set.
//  ElementaryQuestionAttributes - FormDataCollectionItem - contains parameters values.
// 
Procedure SetNumberCellItemParameters(Item, ElementaryQuestionAttributes)

	Item.MinValue  = ?(ElementaryQuestionAttributes.ShouldUseMinValue,
		ElementaryQuestionAttributes.MinValue, Undefined);
	Item.MaxValue = ?(ElementaryQuestionAttributes.ShouldUseMaxValue,
		ElementaryQuestionAttributes.MaxValue, Undefined);

EndProcedure

// Deletes questionnaire filling form items dynamically generated previously.
//
// Parameters:
//  Form              - ClientApplicationForm - a form, from which items are deleted.
//  AttributesToBeDeleted - Array of String - names of form attributes to be deleted, based on which
//                       form items are deleted.
//
Procedure DeleteFillingFormItems(Form, AttributesToBeDeleted)

	For Each AttributeToDelete In AttributesToBeDeleted Do

		QuestionName = Left(AttributeToDelete.Value, 43);

		FoundFormItem = Form.Items.Find(QuestionName + "_Group");

		If FoundFormItem <> Undefined Then
			SubordinateItemsArray = FoundFormItem.ChildItems;
			For Each SubordinateItem In SubordinateItemsArray Do
				Form.Items.Delete(SubordinateItem);
			EndDo;
			Form.Items.Delete(FoundFormItem);
		EndIf;

	EndDo;

EndProcedure

// Parameters:
//  Form          - ClientApplicationForm - a form, for which the operation is executed.
//  SectionsTree - FormDataTree - a tree, for which the data is obtained.
//
Procedure FillSectionsTree(Form, SectionsTree) Export

	SectionsSelection = SectionSelectionByQuestionnaireTemplate(Form.QuestionnaireTemplate);
	AddRowsToSectionsTree(SectionsSelection, SectionsTree);

EndProcedure

// Parameters:
//  QuestionnaireTemplate - CatalogRef.QuestionnaireTemplates -
//
// Returns:
//   QueryResultSelection
//
Function SectionSelectionByQuestionnaireTemplate(QuestionnaireTemplate)

	Query = New Query;
	Query.Text =
	"
	|SELECT
	|	COUNT(DISTINCT QuestionnaireTemplateQuestions.Ref) AS Count,
	|	QuestionnaireTemplateQuestions.Parent AS Parent
	|INTO QuestionsCount
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|WHERE
	|	QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|	AND NOT QuestionnaireTemplateQuestions.IsFolder
	|
	|GROUP BY
	|	QuestionnaireTemplateQuestions.Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionnaireTemplateQuestions.Ref AS Ref,
	|	QuestionnaireTemplateQuestions.Wording AS Wording,
	|	QuestionsCount.Count AS Count
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|		LEFT JOIN QuestionsCount AS QuestionsCount
	|		ON QuestionnaireTemplateQuestions.Ref = QuestionsCount.Parent
	|WHERE
	|	QuestionnaireTemplateQuestions.IsFolder
	|	AND NOT QuestionnaireTemplateQuestions.DeletionMark
	|	AND QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|
	|ORDER BY
	|	Ref HIERARCHY";

	Query.SetParameter("QuestionnaireTemplate", QuestionnaireTemplate);

	Return Query.Execute().Select(QueryResultIteration.ByGroupsWithHierarchy);

EndFunction

// Parameters:
//  SectionsSelection - QueryResultSelection - a hierarchical selection by questionnaire template sections.
//  Parent       - FormDataTreeItem   - a parent item of the tree for which rows are added.
//
Procedure AddRowsToSectionsTree(SectionsSelection, Parent)

	ParentTreeItems = Parent.GetItems();
	While SectionsSelection.Next() Do

		NewTreeItem = ParentTreeItems.Add();
		NewTreeItem.Wording       = SectionsSelection.Wording;
		NewTreeItem.PictureCode        = SurveysClientServer.GetQuestionnaireTemplatePictureCode(True);
		NewTreeItem.RowType          = "Section";
		NewTreeItem.Ref             = SectionsSelection.Ref;
		NewTreeItem.QuestionsCount = SectionsSelection.Count;

		AddRowsToSectionsTree(SectionsSelection.Select(QueryResultIteration.ByGroupsWithHierarchy),
			NewTreeItem);

	EndDo;

EndProcedure

// Gets information on a questionnaire section: section questions, 
// questions attributes, and answers options. Puts received information 
// to form attributes.
//
// Parameters:
//  Form            - ClientApplicationForm - a form for which information is obtained.
//  QuestionnaireTemplate     - CatalogRef.QuestionnaireTemplates - a questionnaire template used to get the information.
//  Section           - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire section, on which information is obtained.
//  FullSectionCode - String - a full code of the section, on which the information is obtained.
//
Procedure GetInformationOnQuestionnaireQuestions(Form, QuestionnaireTemplate, Section, FullSectionCode)

	Query = New Query;
	Query.Text =
	"SELECT
	|	QuestionsForSurvey.Ref AS DoQueryBox,
	|	QuestionsForSurvey.Wording AS Wording,
	|	QuestionsForSurvey.ValueType AS Type,
	|	QuestionsForSurvey.ReplyType AS ReplyType,
	|	QuestionsForSurvey.RadioButtonType AS RadioButtonType,
	|	QuestionsForSurvey.CheckBoxType AS CheckBoxType,
	|	QuestionsForSurvey.MinValue AS MinValue,
	|	QuestionsForSurvey.MaxValue AS MaxValue,
	|	QuestionsForSurvey.ShouldUseMinValue AS ShouldUseMinValue,
	|	QuestionsForSurvey.ShouldUseMaxValue AS ShouldUseMaxValue
	|FROM
	|	ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|WHERE
	|	QuestionsForSurvey.Ref IN
	|			(SELECT DISTINCT
	|				QuestionnaireTemplateQuestions.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|			WHERE
	|				QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestions.Parent = &Section
	|		
	|			UNION ALL
	|		
	|			SELECT
	|				QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions.TableQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfTableQuestion
	|			WHERE
	|				QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.Parent = &Section
	|		
	|			UNION ALL
	|		
	|			SELECT
	|				QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions.ComplexQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfComplexQuestion
	|			WHERE
	|				QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.Parent = &Section)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionnaireTemplateQuestions.Ref AS TemplateQuestion,
	|	QuestionnaireTemplateQuestions.Parent AS Parent,
	|	QuestionnaireTemplateQuestions.Description AS Description,
	|	QuestionnaireTemplateQuestions.IsRequired AS IsRequired,
	|	QuestionnaireTemplateQuestions.QuestionType AS QuestionType,
	|	QuestionnaireTemplateQuestions.TabularQuestionType AS TabularQuestionType,
	|	QuestionnaireTemplateQuestions.ElementaryQuestion AS ElementaryQuestion,
	|	""DoQueryBox"" AS RowType,
	|	QuestionnaireTemplateQuestions.ParentQuestion AS ParentQuestion,
	|	QuestionnaireTemplateQuestions.ToolTip AS ToolTip,
	|	QuestionnaireTemplateQuestions.HintPlacement AS HintPlacement,
	|	QuestionnaireTemplateQuestions.TableQuestionComposition.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion
	|	) AS TableQuestionComposition,
	|	QuestionnaireTemplateQuestions.PredefinedAnswers.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion,
	|		Response AS Response
	|	) AS PredefinedAnswers,
	|	QuestionnaireTemplateQuestions.ComplexQuestionComposition.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestion,
	|		ElementaryQuestion.CommentRequired AS CommentRequired,
	|		ElementaryQuestion.CommentNote AS CommentNote
	|	) AS ComplexQuestionComposition,
	|	ISNULL(QuestionsForSurvey.Length, 0) AS Length,
	|	QuestionsForSurvey.ValueType AS ValueType,
	|	ISNULL(QuestionsForSurvey.CommentRequired, FALSE) AS CommentRequired,
	|	ISNULL(QuestionsForSurvey.CommentNote, """") AS CommentNote,
	|	ISNULL(QuestionsForSurvey.MinValue, 0) AS MinValue,
	|	ISNULL(QuestionsForSurvey.MaxValue, 0) AS MaxValue,
	|	ISNULL(QuestionsForSurvey.RadioButtonType, VALUE(Enum.RadioButtonTypesInQuestionnaires.EmptyRef)) AS RadioButtonType,
	|	ISNULL(QuestionsForSurvey.CheckBoxType, VALUE(Enum.CheckBoxKindsInQuestionnaires.EmptyRef)) AS CheckBoxType,
	|	ISNULL(QuestionsForSurvey.ReplyType, VALUE(Enum.TypesOfAnswersToQuestion.EmptyRef)) AS ReplyType,
	|	ISNULL(QuestionnaireTemplateQuestions.Wording, """") AS Wording,
	|	ISNULL(QuestionsForSurvey.Accuracy, 0) AS Accuracy,
	|	ISNULL(QuestionsForSurvey.ShouldUseMinValue, FALSE) AS ShouldUseMinValue,
	|	ISNULL(QuestionsForSurvey.ShouldUseMaxValue, FALSE) AS ShouldUseMaxValue,
	|	ISNULL(QuestionsForSurvey.ShouldShowRangeSlider, FALSE) AS ShouldShowRangeSlider,
	|	ISNULL(QuestionsForSurvey.RangeSliderStep, 0) AS RangeSliderStep,
	|	QuestionnaireTemplateQuestions.ShouldUseRefusalToAnswer AS ShouldUseRefusalToAnswer,
	|	QuestionnaireTemplateQuestions.RefusalToAnswerText AS RefusalToAnswerText,
	|	QuestionsForSurvey.NumericalQuestionHintsRange.(
	|		LineNumber AS LineNumber,
	|		ValueUpTo AS ValueUpTo,
	|		ToolTip AS ToolTip
	|	) AS NumericalQuestionHintsRange
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|		LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON QuestionnaireTemplateQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|WHERE
	|	NOT QuestionnaireTemplateQuestions.DeletionMark
	|	AND QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|	AND QuestionnaireTemplateQuestions.Parent = &Section
	|	AND NOT QuestionnaireTemplateQuestions.IsFolder
	|
	|ORDER BY
	|	QuestionnaireTemplateQuestions.Code
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionnaireAnswersOptions.Owner AS DoQueryBox,
	|	QuestionnaireAnswersOptions.Ref AS Response,
	|	QuestionnaireAnswersOptions.Presentation AS Presentation,
	|	QuestionnaireAnswersOptions.OpenEndedQuestion AS OpenEndedQuestion,
	|	QuestionnaireAnswersOptions.ToolTip AS ToolTip
	|FROM
	|	Catalog.QuestionnaireAnswersOptions AS QuestionnaireAnswersOptions
	|WHERE
	|	QuestionnaireAnswersOptions.Owner IN
	|			(SELECT
	|				QuestionnaireTemplateQuestions.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|			WHERE
	|				QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestions.Parent = &Section
	|				AND NOT QuestionnaireTemplateQuestions.IsFolder
	|				AND NOT QuestionnaireTemplateQuestions.DeletionMark
	|		
	|			UNION ALL
	|		
	|			SELECT
	|				QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions.TableQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfTableQuestion
	|			WHERE
	|				QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.Parent = &Section
	|				AND NOT QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.IsFolder
	|				AND NOT QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref.DeletionMark
	|		
	|			UNION ALL
	|		
	|			SELECT
	|				QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.ElementaryQuestion
	|			FROM
	|				Catalog.QuestionnaireTemplateQuestions.ComplexQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfComplexQuestion
	|			WHERE
	|				QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.Owner = &QuestionnaireTemplate
	|				AND QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.Parent = &Section
	|				AND NOT QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.IsFolder
	|				AND NOT QuestionnaireTemplateQuestionsCompositionOfComplexQuestion.Ref.DeletionMark)
	|	AND NOT QuestionnaireAnswersOptions.DeletionMark
	|
	|ORDER BY
	|	QuestionnaireAnswersOptions.AddlOrderingAttribute";

	Query.SetParameter("QuestionnaireTemplate", QuestionnaireTemplate);
	Query.SetParameter("Section", Section);

	QueryResultsArray1 = Query.ExecuteBatch();

	Form.QuestionsPresentationTypes.Load(QueryResultsArray1[0].Unload());
	
	QuestionsByQuestionnaireSectionSelection = QueryResultsArray1[1].Select();
	QuestionsCounter = 0;

	While QuestionsByQuestionnaireSectionSelection.Next() Do

		QuestionsCounter = QuestionsCounter + 1;
		FormQuestionsTable = Form.SectionQuestionsTable; // ValueTable
		NewRow = FormQuestionsTable.Add();
		FillPropertyValues(NewRow, QuestionsByQuestionnaireSectionSelection,,
			"TableQuestionComposition,PredefinedAnswers,ComplexQuestionComposition,NumericalQuestionHintsRange");
		NewRow.TableQuestionComposition.Load(QuestionsByQuestionnaireSectionSelection.TableQuestionComposition.Unload());
		NewRow.TableQuestionComposition.Sort("LineNumber Asc");
		NewRow.PredefinedAnswers.Load(QuestionsByQuestionnaireSectionSelection.PredefinedAnswers.Unload());
		NewRow.PredefinedAnswers.Sort("LineNumber Asc");
		NewRow.ComplexQuestionComposition.Load(
			QuestionsByQuestionnaireSectionSelection.ComplexQuestionComposition.Unload());
		NewRow.ComplexQuestionComposition.Sort("LineNumber Asc");
		NewRow.NumericalQuestionHintsRange.Load(
			QuestionsByQuestionnaireSectionSelection.NumericalQuestionHintsRange.Unload());
		NewRow.NumericalQuestionHintsRange.Sort("LineNumber Desc");
		NewRow.Composite = New UUID;
		NewRow.FullCode  = FullSectionCode + "." + XMLString(QuestionsCounter);

	EndDo;
	
	Form.PossibleAnswers.Load(QueryResultsArray1[2].Unload());

EndProcedure

// Parameters:
//   Form  - ClientApplicationForm - a form for which subordination table is generated.
//
Procedure GenerateQuestionsSubordinationTable(Form) Export

	Form.DependentQuestions.Clear();

	Query = New Query;
	Query.Text =
	"
	|SELECT
	|	ExternalSource.TemplateQuestion AS TemplateQuestion,
	|	ExternalSource.ParentQuestion AS ParentQuestion,
	|	ExternalSource.QuestionType,
	|	ExternalSource.KeyString,
	|	ExternalSource.IsRequired,
	|	ExternalSource.CommentRequired,
	|	ExternalSource.ElementaryQuestion,
	|	ExternalSource.ReplyType
	|INTO SectionQuestions
	|FROM
	|	&ExternalSource AS ExternalSource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SectionQuestions.TemplateQuestion AS TemplateQuestion,
	|	SectionQuestions.KeyString
	|INTO QuestionsWithCondition
	|FROM
	|	SectionQuestions AS SectionQuestions
	|WHERE
	|	SectionQuestions.QuestionType = VALUE(Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SectionQuestions.ParentQuestion AS ParentQuestion,
	|	SectionQuestions.TemplateQuestion,
	|	SectionQuestions.KeyString AS Composite,
	|	QuestionsWithCondition.KeyString AS ParentSrtingKey,
	|	SectionQuestions.IsRequired,
	|	SectionQuestions.CommentRequired,
	|	SectionQuestions.QuestionType,
	|	SectionQuestions.ElementaryQuestion,
	|	SectionQuestions.ReplyType
	|FROM
	|	SectionQuestions AS SectionQuestions
	|		INNER JOIN QuestionsWithCondition AS QuestionsWithCondition
	|		ON SectionQuestions.ParentQuestion = QuestionsWithCondition.TemplateQuestion
	|WHERE
	|	SectionQuestions.ParentQuestion IN
	|			(SELECT
	|				QuestionsWithCondition.TemplateQuestion
	|			FROM
	|				QuestionsWithCondition AS QuestionsWithCondition)
	|TOTALS BY
	|	ParentSrtingKey";

	ExternalSource = Form.SectionQuestionsTable.Unload(); // ValueTable
	ExternalSource.Columns.Add("KeyString", New TypeDescription("String", , New StringQualifiers(50)));
	For Each TableRow In ExternalSource Do
		TableRow.KeyString = String(TableRow.Composite);
	EndDo;
	Query.SetParameter("ExternalSource", ExternalSource);

	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;

	Selection = Result.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do

		Form.Items[SurveysClientServer.QuestionName(Selection.ParentSrtingKey)].SetAction(
			"OnChange", "Attachable_OnChangeQuestionsWithConditions");

		DetailsSelection = Selection.Select();

		NewRow = Form.DependentQuestions.Add();
		NewRow.DoQueryBox = Selection.ParentSrtingKey;

		While DetailsSelection.Next() Do

			QuestionName = SurveysClientServer.QuestionName(DetailsSelection.Composite);
			SubordinatesTable = NewRow.SubordinateItems; // ValueTable
			If DetailsSelection.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then

				NewRowSubordinate = SubordinatesTable.Add();
				NewRowSubordinate.SubordinateQuestionItemName = QuestionName + "_Table";
				NewRowSubordinate.IsRequired = Selection.IsRequired;

			ElsIf DetailsSelection.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then

				NewRowSubordinate = SubordinatesTable.Add();
				NewRowSubordinate.SubordinateQuestionItemName = QuestionName + "_Group";
				NewRowSubordinate.IsRequired = Selection.IsRequired;

			Else

				If DetailsSelection.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

					OptionsOfAnswersToQuestion = OptionsOfAnswersToQuestion(DetailsSelection.ElementaryQuestion, Form);

					Counter = 0;
					For Each AnswerOption In OptionsOfAnswersToQuestion Do

						Counter = Counter + 1;
						NewRowSubordinate = SubordinatesTable.Add();
						NewRowSubordinate.SubordinateQuestionItemName = QuestionName + "_Attribute_" + Counter;
						NewRowSubordinate.IsRequired                   = False;

						If AnswerOption.OpenEndedQuestion Then
							NewRowSubordinate = SubordinatesTable.Add();
							NewRowSubordinate.SubordinateQuestionItemName = QuestionName + "_Comment_"
								+ Counter;
							NewRowSubordinate.IsRequired                   = False;
						EndIf;
					EndDo;

				Else

					NewRowSubordinate = SubordinatesTable.Add();
					NewRowSubordinate.SubordinateQuestionItemName = QuestionName;
					NewRowSubordinate.IsRequired                   = DetailsSelection.IsRequired;

					If DetailsSelection.CommentRequired Then
						NewRowSubordinate = SubordinatesTable.Add();
						NewRowSubordinate.SubordinateQuestionItemName = QuestionName + "_Comment";
						NewRowSubordinate.IsRequired                   = False;
					EndIf;

				EndIf;
			EndIf;
		EndDo;
	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

Procedure DeleteQuestionnaireTemplateQuestions(OwnerRef) Export

	SetPrivilegedMode(True);

	Block = New DataLock;
	LockItem = Block.Add("Catalog.QuestionnaireTemplateQuestions");
	LockItem.SetValue("Owner", OwnerRef);

	BeginTransaction();
	Try

		Block.Lock();

		Query = New Query;
		Query.Text =
		"SELECT
		|	QuestionnaireTemplateQuestions.Ref
		|FROM
		|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
		|WHERE
		|	QuestionnaireTemplateQuestions.Owner = &Owner";

		Query.SetParameter("Owner", OwnerRef);

		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then

			ReferencesArrray = QueryResult.Unload().UnloadColumn("Ref");
			For Each ArrayElement In ReferencesArrray Do

				CatalogObject = ArrayElement.GetObject();
				If (Not CatalogObject = Undefined) Then
					CatalogObject.Delete();
				EndIf;

			EndDo;
		EndIf;

		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;

	SetPrivilegedMode(False);

EndProcedure

// Gets presentations of general questions in a question chart
// and populates the QuestionsPresentations map
// (the map will provide question presentations for question charts).
//
// Parameters:
//   QuestionnaireTemplate - CatalogRef.QuestionnaireTemplates - the template used to conduct the survey.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - CatalogRef.QuestionnaireTemplateQuestions
//     * Value - Structure:
//        ** Wording - String
//        ** ShowAggregatedValuesInReports - Boolean
//
Function PresentationOfQuestionChartGeneralQuestions(QuestionnaireTemplate) Export

	QuestionsPresentations = New Map;

	Query = New Query;
	Query.Text =
	"SELECT
	|	QuestionnaireTemplateQuestions.Ref
	|INTO TemplateQuestions
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|WHERE
	|	QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion
	|INTO ElementaryQuestions
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions.TableQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfTableQuestion
	|WHERE
	|	QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref IN
	|			(SELECT
	|				TemplateQuestions.Ref
	|			FROM
	|				TemplateQuestions AS TemplateQuestions)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionsForSurvey.Ref,
	|	QuestionsForSurvey.Wording,
	|	QuestionsForSurvey.ShowAggregatedValuesInReports
	|FROM
	|	ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|WHERE
	|	QuestionsForSurvey.Ref IN
	|			(SELECT
	|				ElementaryQuestions.ElementaryQuestion
	|			FROM
	|				ElementaryQuestions AS ElementaryQuestions)";

	Query.SetParameter("QuestionnaireTemplate", QuestionnaireTemplate);

	Result = Query.Execute();
	If Not Result.IsEmpty() Then

		Selection = Result.Select();
		While Selection.Next() Do
			QuestionsPresentations.Insert(Selection.Ref, New Structure("Wording,ShowAggregatedValuesInReports",
				Selection.Wording, Selection.ShowAggregatedValuesInReports));
		EndDo;

	EndIf;

	Return QuestionsPresentations;

EndFunction

// Parameters:
//  Respondent  - CatalogRef - a respondent, for whom the list of questionnaires is obtained.
//
// Returns:
//   ValueTable   - 
//      * Status        - String
//      * QuestionnaireSurvey   - DocumentRef.Questionnaire
//                      - DocumentRef.PollPurpose
//      * EndDate - Date
//      * Description  - String
//      * QuestionnaireDate    - Date
//   Undefined       - if there are no questionnaires available to the respondent.
//
Function TableOfQuestionnairesAvailableToRespondent(Respondent) Export

	If Not ValueIsFilled(Respondent) Then
		Return Undefined;
	EndIf;

	Query = New Query;
	Query.SetParameter("Respondent", Respondent);
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("DateEmpty", Date(1, 1, 1));
	Query.SetParameter("RespondentsType", Catalogs[Respondent.Metadata().Name].EmptyRef());
	Query.Text =
	"SELECT
	|	PollPurpose.Ref AS Ref,
	|	PollPurpose.FreeSurvey AS FreeSurvey,
	|	PollPurpose.EndDate AS EndDate,
	|	PollPurpose.Description AS Description
	|INTO ActivePolls
	|FROM
	|	Document.PollPurpose AS PollPurpose
	|WHERE
	|	PollPurpose.Posted
	|	AND NOT PollPurpose.DeletionMark
	|	AND PollPurpose.RespondentsType = &RespondentsType
	|	AND (PollPurpose.StartDate = &DateEmpty
	|			OR BEGINOFPERIOD(PollPurpose.StartDate, DAY) < &CurrentDate)
	|	AND (PollPurpose.EndDate = &DateEmpty
	|			OR ENDOFPERIOD(PollPurpose.EndDate, DAY) > &CurrentDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ActivePolls.Ref AS Ref,
	|	ActivePolls.EndDate AS EndDate,
	|	ActivePolls.Description AS Description
	|INTO ActivePollsFilterByRespondent
	|FROM
	|	ActivePolls AS ActivePolls
	|WHERE
	|	ActivePolls.FreeSurvey
	|
	|UNION ALL
	|
	|SELECT
	|	PurposeOfSurveysRespondents.Ref,
	|	PollPurpose.EndDate,
	|	PollPurpose.Description
	|FROM
	|	Document.PollPurpose.Respondents AS PurposeOfSurveysRespondents
	|		LEFT JOIN Document.PollPurpose AS PollPurpose
	|		ON PurposeOfSurveysRespondents.Ref = PollPurpose.Ref
	|WHERE
	|	PurposeOfSurveysRespondents.Respondent = &Respondent
	|	AND PurposeOfSurveysRespondents.Ref IN
	|			(SELECT
	|				ActivePolls.Ref
	|			FROM
	|				ActivePolls AS ActivePolls
	|			WHERE
	|				NOT ActivePolls.FreeSurvey)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Questionnaire.Ref AS Ref,
	|	Questionnaire.EditDate AS Date,
	|	Questionnaire.Posted AS Posted,
	|	Questionnaire.Survey AS Survey
	|INTO QuestionnairesOnActiveRequests
	|FROM
	|	Document.Questionnaire AS Questionnaire
	|WHERE
	|	Questionnaire.Survey IN
	|			(SELECT
	|				ActivePollsFilterByRespondent.Ref
	|			FROM
	|				ActivePollsFilterByRespondent AS ActivePollsFilterByRespondent)
	|	AND Questionnaire.Respondent = &Respondent
	|	AND NOT Questionnaire.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN QuestionnairesOnActiveRequests.Ref IS NULL
	|			THEN ""Surveys""
	|		ELSE ""Questionnaires""
	|	END AS Status,
	|	CASE
	|		WHEN QuestionnairesOnActiveRequests.Ref IS NULL
	|			THEN ActivePollsFilterByRespondent.Ref
	|		ELSE QuestionnairesOnActiveRequests.Ref
	|	END AS QuestionnaireSurvey,
	|	ActivePollsFilterByRespondent.EndDate AS EndDate,
	|	ActivePollsFilterByRespondent.Description AS Description,
	|	QuestionnairesOnActiveRequests.Date AS QuestionnaireDate,
	|	ISNULL(QuestionnairesOnActiveRequests.Posted, FALSE) AS Posted
	|INTO PollsWithoutResponsesSavedQuestionnaires
	|FROM
	|	ActivePollsFilterByRespondent AS ActivePollsFilterByRespondent
	|		LEFT JOIN QuestionnairesOnActiveRequests AS QuestionnairesOnActiveRequests
	|		ON ActivePollsFilterByRespondent.Ref = QuestionnairesOnActiveRequests.Survey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PollsWithoutResponsesSavedQuestionnaires.Status AS Status,
	|	PollsWithoutResponsesSavedQuestionnaires.QuestionnaireSurvey AS QuestionnaireSurvey,
	|	PollsWithoutResponsesSavedQuestionnaires.EndDate AS EndDate,
	|	PollsWithoutResponsesSavedQuestionnaires.Description AS Description,
	|	PollsWithoutResponsesSavedQuestionnaires.QuestionnaireDate AS QuestionnaireDate
	|FROM
	|	PollsWithoutResponsesSavedQuestionnaires AS PollsWithoutResponsesSavedQuestionnaires
	|WHERE
	|	NOT PollsWithoutResponsesSavedQuestionnaires.Posted";

	Result = Query.Execute();

	If Not Result.IsEmpty() Then
		Return Result.Unload();
	EndIf;

EndFunction

Function CanNumericFieldTakeZero(TableRow) Export

	If TableRow.ReplyType <> Enums.TypesOfAnswersToQuestion.Number Then
		Return False;
	EndIf;

	Left = ?(TableRow.ShouldUseMinValue, TableRow.MinValue, -1);
	Right = ?(TableRow.ShouldUseMaxValue, TableRow.MaxValue, 1);

	Return (Left <= 0 And Right >= 0);

EndFunction

#EndRegion