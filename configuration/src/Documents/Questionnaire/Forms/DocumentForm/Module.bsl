///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////
#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsCommonUserSession = Not Users.IsExternalUserSession();
	If Not IsCommonUserSession And Not Object.Ref.IsEmpty() 
		And Object.Respondent <> ExternalUsers.GetExternalUserAuthorizationObject() Then
		Cancel = True;
		Return;
	EndIf;

	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);

	If Object.SurveyMode = Enums.SurveyModes.Interview Then

		If Not Object.QuestionnaireTemplate.IsEmpty() Then
			AttributesSurvey = QuestionnaireTemplateAttributesValues(Object.QuestionnaireTemplate);
			SetAttributesValuesBySurvey(AttributesSurvey);
		EndIf;

		AllowSavingQuestionnaireDraft = Parameters.AllowSavingQuestionnaireDraft;

	EndIf;

	If Not Object.Survey.IsEmpty() Then
		AttributesSurvey = ReportAssignmentAttributesValues(Object.Survey);
		SetAttributesValuesBySurvey(AttributesSurvey);
		Object.QuestionnaireTemplate = QuestionnaireTemplate;
	EndIf;

	If QuestionnaireTemplate.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;

	If Parameters.FillingFormOnly Then
		AutoTitle = False;
		SetLabelHeader(AttributesSurvey);
	EndIf;

	Surveys.SetQuestionnaireSectionsTreeItemIntroductionConclusion(SectionsTree, 
		NStr("en = 'Introduction';"), "Introduction");
	Surveys.FillSectionsTree(ThisObject, SectionsTree);
	Surveys.SetQuestionnaireSectionsTreeItemIntroductionConclusion(SectionsTree, 
		NStr("en = 'Closing statement';"), "ClosingStatement");
	SurveysClientServer.GenerateTreeNumbering(SectionsTree, True);

	If (Not Object.Posted) And ValueIsFilled(Object.SectionToEdit) Then
		If TypeOf(Object.SectionToEdit) = Type("CatalogRef.QuestionnaireTemplateQuestions") Then
			CurrentSectionNumber = SurveysClientServer.FindStringInFormDataTree(SectionsTree,
				Object.SectionToEdit, "Ref", True);
		Else
			CurrentSectionNumber = SurveysClientServer.FindStringInFormDataTree(SectionsTree,
				Object.SectionToEdit, "RowType", True);
		EndIf;
		If CurrentSectionNumber = -1 Then
			CurrentSectionNumber = 0;
		EndIf;
	EndIf;
	Items.SectionsTree.CurrentRow = CurrentSectionNumber;
	CreateFormAccordingToSection();

	Items.FooterPreviousSection.Visible = False;
	Items.FooterNextSection.Visible  = False;

	SetVisibilityAccessibilityOfFormElements();

	Items.SectionsTreeGroup.Visible = False;
	TitleSectionsCommand = NStr("en = 'Show sections';");
	Items.HideShowSectionsTreeDocument.Title = TitleSectionsCommand;

	ChangeFormItemsVisibility(ThisObject);
		
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
		
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	Items.SectionsTree.CurrentRow = CurrentSectionNumber;
	SetSectionsNavigationAvailability();
	HighlightAnsweredQuestions();

	If (Not ReadOnly) Then
		AvailabilityControlSubordinateQuestions(False);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)

	If Items.QuestionnaireBodyGroup.ReadOnly Then
		Modified = False;
	EndIf;

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	ConvertSectionFillingResultsToTabularSection();
	CurrentObject.Content.Clear();
	For Each CompositionRow In Object.Content Do
		NewRow = CurrentObject.Content.Add();
		FillPropertyValues(NewRow, CompositionRow);
	EndDo;
	CurrentObject.SectionToEdit = Object.SectionToEdit;
	CurrentObject.EditDate = CurrentSessionDate();

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	ShowUserNotification(NStr("en = 'Edited';"),, String(Object.Ref), PictureLib.Information32);

	Notify("Write_Questionnaire", New Structure, Object.Ref);

	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RespondentStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;

	FilterArray = New Array;
	If RespondentsFilter.Count() > 0 Then
		FilterArray.Add(SurveysClient.CreateFilterParameterStructure(Type("DataCompositionFilterItem"),
			"Ref", DataCompositionComparisonType.InListByHierarchy, RespondentsFilter));
	EndIf;

	OpenForm(RespondentMetadataName + ".ChoiceForm", New Structure("FilterArray", FilterArray), Item);

EndProcedure

&AtClient
Procedure Attachable_OnChangeQuestionsWithConditions(Item)

	AvailabilityControlSubordinateQuestions();

EndProcedure

&AtClient
Procedure Attachable_OnChangeQuestion(Item)

	Modified = True;
	SurveysClient.OnChangeQuestion(ThisObject, Item);

EndProcedure

&AtClient
Procedure Attachable_OnChangeRangeSlider(Item)

	Modified = True;
	SurveysClient.OnChangeRangeSlider(ThisObject, Item);

EndProcedure

&AtClient
Procedure Attachable_OnChangeOfNumberField(Item)

	Modified = True;
	SurveysClient.OnChangeOfNumberField(ThisObject, Item);

EndProcedure

&AtClient
Procedure Attachable_NumberFieldAdjustment(Item, Direction, StandardProcessing)

	Modified = True;
	SurveysClient.NumberFieldAdjustment(ThisObject, Item, Direction, StandardProcessing);

EndProcedure

&AtClient
Procedure Attachable_StartChoiceOfTableQuestionsTextCells(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;

	AdditionalParameters = New Structure("Item", Item);
	HandlerNotifications = New NotifyDescription("EditMultilineTextOnEnd", ThisObject,
		AdditionalParameters);
	CommonClient.ShowMultilineTextEditingForm(HandlerNotifications,
		Item.EditText);

EndProcedure

&AtClient
Procedure Attachable_ChoiceStartComment(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	If Items.Find(Item.Name) = Undefined Then
		Return;
	EndIf;

	CommonClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, Item.Name, Item.InputHint);

EndProcedure

&AtClient
Procedure Attachable_OnChangeFlagDoNotAnswerQuestion(Item)

	Modified = True;
	SurveysClient.OnChangeFlagDoNotAnswerQuestion(ThisObject, Item);

EndProcedure

&AtClient
Procedure SectionsTreeSelection(Item, RowSelected, Field, StandardProcessing)

	CurrentData = Items.SectionsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	ExecuteFillingFormCreation();
	SetSectionsNavigationAvailability();

EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)

	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ResponseFormWrite(Command)

	Cancel = EndEditFillingForm(DocumentWriteMode.Write);
	If Not Cancel Then

		ShowUserNotification(NStr("en = 'Edited';"),, String(Object.Ref),
			PictureLib.Information32);

		Notify("Write_Questionnaire", New Structure, Object.Ref);

	EndIf;

EndProcedure

&AtClient
Procedure FillingFormEndAndClose(Command)

	OnCloseNotifyHandler = New NotifyDescription("PromptForAcceptingQuestionnaireAfterCompletion", ThisObject);
	ShowQueryBox(OnCloseNotifyHandler, 
		NStr("en = 'You will not be able to edit your responses
			|after you submit the questionnaire.
			|Would you like to submit it?';"), QuestionDialogMode.YesNo);

EndProcedure

&AtClient
Procedure ShowSections(Command)

	ChangeSectionsTreeVisibility();

EndProcedure

&AtClient
Procedure NextSection(Command)

	ChangeSection("GoForward");

EndProcedure

&AtClient
Procedure PreviousSection(Command)

	ChangeSection("Back");

EndProcedure

&AtClient
Procedure SelectSection(Command)

	ExecuteFillingFormCreation();
	SetSectionsNavigationAvailability();

EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure SetSectionFillingFormAttributesValues()

	SectionQuestionsTable.Unload().UnloadColumn("TemplateQuestion");

	Query = New Query;
	Query.Text = 
		"SELECT
		|	ExternalSource.DoQueryBox AS DoQueryBox,
		|	CAST(ExternalSource.ElementaryQuestion AS ChartOfCharacteristicTypes.QuestionsForSurvey) AS ElementaryQuestion,
		|	ExternalSource.CellNumber AS CellNumber,
		|	ExternalSource.Response AS Response,
		|	ExternalSource.OpenAnswer AS OpenAnswer,
		|	ExternalSource.IsUnanswered AS IsUnanswered
		|INTO AnswersTable
		|FROM
		|	&ExternalSource AS ExternalSource
		|WHERE
		|	ExternalSource.DoQueryBox IN(&SectionQuestions)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AnswersTable.DoQueryBox AS DoQueryBox,
		|	AnswersTable.ElementaryQuestion AS ElementaryQuestion,
		|	AnswersTable.CellNumber AS CellNumber,
		|	AnswersTable.Response AS Response,
		|	AnswersTable.OpenAnswer AS OpenAnswer,
		|	AnswersTable.ElementaryQuestion.CommentRequired AS OpenEndedQuestion,
		|	AnswersTable.IsUnanswered AS IsUnanswered
		|FROM
		|	AnswersTable AS AnswersTable
		|TOTALS BY
		|	DoQueryBox";

	Query.SetParameter("ExternalSource", Object.Content.Unload());
	Query.SetParameter("SectionQuestions", SectionQuestionsTable.Unload().UnloadColumn("TemplateQuestion"));

	Result = Query.Execute();
	If Not Result.IsEmpty() Then

		Selection = Result.Select(QueryResultIteration.ByGroups);
		While Selection.Next() Do

			SelectionQuestion = Selection.Select();
			SetAttributeValue(Selection.DoQueryBox, SelectionQuestion);

		EndDo;

	EndIf;

EndProcedure

// Parameters:
//  TemplateQuestion  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  QuestionnaireTreeServer - ValueTree - a value tree containing the questionnaire template.
//
&AtServer
Procedure SetAttributeValue(TemplateQuestion, SelectionQuestion)

	FoundRows = SectionQuestionsTable.FindRows(New Structure("TemplateQuestion", TemplateQuestion));

	If FoundRows.Count() > 0 Then
		FoundRow = FoundRows[0];
		If FoundRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then
			SetTabularQuestionAttributeValue(TemplateQuestion, SelectionQuestion, FoundRow);
			SetAttributeValuesComplexQuestion(TemplateQuestion, SelectionQuestion, FoundRow);
		ElsIf FoundRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then
			SetAttributeValuesComplexQuestion(TemplateQuestion, SelectionQuestion, FoundRow);
		Else
			SetSimpleQuestionAttributeValue(TemplateQuestion, SelectionQuestion, FoundRow);
		EndIf;
	EndIf;

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetSimpleQuestionAttributeValue(DoQueryBox, SelectionQuestion, TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);

	If TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

		OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, ThisObject);

		While SelectionQuestion.Next() Do

			AnswerParameters = FindAnswerInArray(SelectionQuestion.Response, OptionsOfAnswersToQuestion);

			If AnswerParameters <> Undefined Then
				ThisObject[QuestionName + "_Attribute_" + AnswerParameters.AttributeSequenceNumber] = True;
				If AnswerParameters.OpenEndedQuestion Then

					ThisObject[QuestionName + "_Comment_" + AnswerParameters.AttributeSequenceNumber] = 
						SelectionQuestion.OpenAnswer;

				EndIf;
			EndIf;

		EndDo;

	ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then

		OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, ThisObject);

		While SelectionQuestion.Next() Do
			AnswerParameters = FindAnswerInArray(SelectionQuestion.Response, OptionsOfAnswersToQuestion);
			If AnswerParameters <> Undefined Then
				ThisObject[QuestionName + "_Attribute_" + AnswerParameters.AttributeSequenceNumber] = SelectionQuestion.Response;
			EndIf;
			If (TreeRow.CommentRequired) Then
				ThisObject[QuestionName + "_Comment"] = SelectionQuestion.OpenAnswer;
			EndIf;
			If TreeRow.ShouldUseRefusalToAnswer Then
				ThisObject[QuestionName + "_ShouldUseRefusalToAnswer"] = SelectionQuestion.IsUnanswered;
			EndIf;
		EndDo;

	Else

		If SelectionQuestion.Next() Then

			If TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then

				ThisObject[QuestionName] = SelectionQuestion.OpenAnswer;

			Else

				ThisObject[QuestionName] = SelectionQuestion.Response;

				If TreeRow.ShouldShowRangeSlider Then
					ThisObject[QuestionName + "_RangeSliderAttribute"] = (ThisObject[QuestionName]
						- TreeRow.MinValue) / TreeRow.RangeSliderStep;
				EndIf;

				If (TreeRow.CommentRequired) Then
					ThisObject[QuestionName + "_Comment"] = SelectionQuestion.OpenAnswer;
				EndIf;

			EndIf;

			If TreeRow.ShouldUseRefusalToAnswer Then
				ThisObject[QuestionName + "_ShouldUseRefusalToAnswer"] = SelectionQuestion.IsUnanswered;
			EndIf;

		EndIf;

	EndIf;

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetTabularQuestionAttributeValue(DoQueryBox, SelectionQuestion, TreeRow)

	If TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.Composite Then

		SetAttributeValuesCompositeTabularQuestion(DoQueryBox, SelectionQuestion, TreeRow);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows Then

		SetAttributeValuesTabularQuestionAnswersInRows(DoQueryBox, SelectionQuestion, TreeRow);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then

		SetAttributeValuesTabularQuestionAnswersInColumns(DoQueryBox, SelectionQuestion, TreeRow);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then

		SetAttributeValuesTabularQuestionAnswersInRowsAndColumns(DoQueryBox, SelectionQuestion, TreeRow);

	EndIf;

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetAttributeValuesCompositeTabularQuestion(DoQueryBox, SelectionQuestion, TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName = QuestionName + "_Table";
	Table    = FormAttributeToValue(TableName);

	QuestionnaireQuestions = TreeRow.TableQuestionComposition.Unload().UnloadColumn("ElementaryQuestion");

	While SelectionQuestion.Next() Do

		If QuestionnaireQuestions.Find(SelectionQuestion.ElementaryQuestion) = Undefined Then
			Continue;
		EndIf;

		If SelectionQuestion.CellNumber > Table.Count() Then
			For IndexOf = 1 To SelectionQuestion.CellNumber - Table.Count() Do
				Table.Add();
			EndDo;
		EndIf;

		QuestionNumberInArray = QuestionnaireQuestions.Find(SelectionQuestion.ElementaryQuestion);
		If QuestionNumberInArray <> Undefined Then
			Table[SelectionQuestion.CellNumber - 1][QuestionNumberInArray] = SelectionQuestion.Response;
		EndIf;

	EndDo;

	ValueToFormAttribute(Table, TableName);

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetAttributeValuesTabularQuestionAnswersInRows(DoQueryBox, SelectionQuestion, TreeRow)
	
	QuestionName          = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName          = QuestionName + "_Table";
	NameOfColumnWithoutNumber = TableName + "_Column_";
	Table             = FormAttributeToValue(TableName);

	QuestionnaireQuestions = TreeRow.TableQuestionComposition.Unload().UnloadColumn("ElementaryQuestion");
	While SelectionQuestion.Next() Do

		QuestionNumber = QuestionnaireQuestions.Find(SelectionQuestion.ElementaryQuestion);
		If (QuestionNumber <> Undefined) And (SelectionQuestion.CellNumber <= Table.Count()) Then
			Table[SelectionQuestion.CellNumber - 1][NameOfColumnWithoutNumber + XMLString(QuestionNumber + 1)] = SelectionQuestion.Response;
		EndIf;

	EndDo;

	ValueToFormAttribute(Table, TableName);

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetAttributeValuesTabularQuestionAnswersInColumns(DoQueryBox, SelectionQuestion, TreeRow)
	
	QuestionName          = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName          = QuestionName + "_Table";
	NameOfColumnWithoutNumber = TableName + "_Column_";
	Table             = FormAttributeToValue(TableName);

	QuestionnaireQuestions = TreeRow.TableQuestionComposition.Unload().UnloadColumn("ElementaryQuestion");
	QuestionnaireQuestions.Delete(0);

	While SelectionQuestion.Next() Do

		QuestionNumber = QuestionnaireQuestions.Find(SelectionQuestion.ElementaryQuestion);
		If (QuestionNumber <> Undefined) Then
			If (QuestionNumber <= Table.Count()) And (SelectionQuestion.CellNumber <= Table.Columns.Count()) Then
				Table[QuestionNumber][NameOfColumnWithoutNumber + XMLString(SelectionQuestion.CellNumber + 1)] = SelectionQuestion.Response;
			EndIf;
		EndIf;

	EndDo;

	ValueToFormAttribute(Table, TableName);

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//            for which attributes values are set.
//  SelectionQuestion - QueryResultSelection - a selection containing values of answers 
//                  to the questionnaire template question.
//  TreeRow - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetAttributeValuesTabularQuestionAnswersInRowsAndColumns(DoQueryBox, SelectionQuestion, TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName = QuestionName + "_Table";
	NameOfColumnWithoutNumber = TableName + "_Column_";
	Table = FormAttributeToValue(TableName);
	ColumnsCount = Table.Columns.Count();

	QuestionCell = TreeRow.TableQuestionComposition[2].ElementaryQuestion;

	While SelectionQuestion.Next() Do
		If SelectionQuestion.ElementaryQuestion = QuestionCell Then
			ColumnNumber = ?(SelectionQuestion.CellNumber % (ColumnsCount - 1) = 0, ColumnsCount - 1,
				SelectionQuestion.CellNumber % (ColumnsCount - 1));
			LineNumber  = Int((SelectionQuestion.CellNumber + Int(SelectionQuestion.CellNumber / ColumnsCount)) / ColumnsCount);
			Table[LineNumber][NameOfColumnWithoutNumber + XMLString(ColumnNumber + 1)] = SelectionQuestion.Response;
		EndIf;
	EndDo;

	ValueToFormAttribute(Table, TableName);

EndProcedure

// Parameters:
//  DoQueryBox  - CatalogRef.QuestionnaireTemplateQuestions - a questionnaire template question, 
//                 for which attributes values are set.
//  SelectionQuestion  - QueryResultSelection - a selection containing values of answers 
//                 to the questionnaire template question.
//  TreeRow  - ValueTreeRow - a value tree row containing the questionnaire template question data.
//
&AtServer
Procedure SetAttributeValuesComplexQuestion(DoQueryBox, SelectionQuestion, TreeRow)
	
	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);
	QuestionnaireQuestions = TreeRow.ComplexQuestionComposition.Unload().UnloadColumn("ElementaryQuestion");

	SelectionQuestion.Reset();
	While SelectionQuestion.Next() Do

		If QuestionnaireQuestions.Find(SelectionQuestion.ElementaryQuestion) = Undefined Then
			Continue;
		EndIf;

		QuestionRows = TreeRow.ComplexQuestionComposition.FindRows(New Structure("ElementaryQuestion",
			SelectionQuestion.ElementaryQuestion));
		LineNumber = QuestionRows[0].LineNumber;
		AttributeName =  QuestionName + "_Response_" + Format(LineNumber, "NG=");

		If SelectionQuestion.ElementaryQuestion.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

			OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(SelectionQuestion.ElementaryQuestion,
				ThisObject);

			AnswerParameters = FindAnswerInArray(SelectionQuestion.Response, OptionsOfAnswersToQuestion);
			If AnswerParameters <> Undefined Then
				ThisObject[AttributeName + "_Attribute_" + AnswerParameters.AttributeSequenceNumber] = True;
				If AnswerParameters.OpenEndedQuestion Then
					ThisObject[AttributeName + "_Comment_" + AnswerParameters.AttributeSequenceNumber] = SelectionQuestion.OpenAnswer;
				EndIf;
			EndIf;

		ElsIf SelectionQuestion.ElementaryQuestion.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then
			ThisObject[AttributeName] = SelectionQuestion.OpenAnswer;
		Else
			ThisObject[AttributeName] = SelectionQuestion.Response;

			If (SelectionQuestion.OpenEndedQuestion) Then
				ThisObject[QuestionName + "_Comment_" + Format(LineNumber, "NG=")] = SelectionQuestion.OpenAnswer;
			EndIf;
		EndIf;

	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Function EndEditFillingForm(WriteMode)

	ConvertSectionFillingResultsToTabularSection();
	If WriteMode = DocumentWriteMode.Posting Then
		If CheckQuestionnaireFilling() Then
			Return True;
		EndIf;
	EndIf;

	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.EditDate = CurrentSessionDate();
	If WriteMode = DocumentWriteMode.Posting Then
		If Not DocumentObject.CheckFilling() Then
			Return True;
		EndIf;
	EndIf;
	DocumentObject.Write(WriteMode);

	If WriteMode = DocumentWriteMode.Write Then
		ValueToFormAttribute(DocumentObject, "Object");
		Modified = False;
	EndIf;

	Return False;

EndFunction

&AtServer
Procedure ConvertSectionFillingResultsToTabularSection()

	CurrentSection = SectionsTree.FindByID(Items.SectionsTree.CurrentRow);
	If CurrentSection <> Undefined Then
		If CurrentSection.RowType = "Section" Then
			Object.SectionToEdit = CurrentSection.Ref;
		Else
			Object.SectionToEdit = CurrentSection.RowType;
		EndIf;
	EndIf;

	PreviousSectionWithoutQuestions = (SectionQuestionsTable.Count() = 0);

	For Each TableRow In SectionQuestionsTable Do
		
		// Removes the existing data from the table.
		FoundRows = Object.Content.FindRows(New Structure("DoQueryBox", TableRow.TemplateQuestion));
		For Each FoundRow In FoundRows Do
			Object.Content.Delete(FoundRow);
		EndDo;

		If ValueIsFilled(TableRow.ParentQuestion) Then
			FoundRows = SectionQuestionsTable.FindRows(New Structure("TemplateQuestion",
				TableRow.ParentQuestion));
			If FoundRows.Count() > 0 Then
				ParentRow = FoundRows[0];
				If (Not ThisObject[SurveysClientServer.QuestionName(ParentRow.Composite)] = True) Then
					Continue;
				EndIf;
			EndIf;
		EndIf;

		If TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then
			FillAnswersTableTabularQuestion(TableRow);
		ElsIf TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then
			FillAnswersComplexQuestion(TableRow);
		Else
			FillAnswerSimpleQuestion(TableRow);
		EndIf;

	EndDo;

EndProcedure

// Parameters:
//   TreeRow - ValueTreeRow - a row of the questionnaire template tree.
//
&AtServer
Procedure FillAnswersTableTabularQuestion(TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);
	TableName = QuestionName + "_Table";
	Table = FormAttributeToValue(TableName);

	If Table.Count() = 0 Then
		Return;
	EndIf;

	If TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.Composite Then

		FillAnswersCompositeTabularQuestion(TreeRow, Table);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows Then

		FillAnswersTabularQuestionAnswersInRows(TreeRow, Table);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then

		FillAnswersTabularQuestionAnswersInColumns(TreeRow, Table);

	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then

		FillAnswersTabularQuestionAnswersInRowsAndColumns(TreeRow, Table);

	EndIf;

EndProcedure

// Gets answers to a composite question chart and appends them to the main
// table of answers.
//
// Parameters:
//  TreeRow - ValueTreeRow - a row of the questionnaire template tree.
//  Table      - ValueTable - Chart the question belongs to.
//
&AtServer
Procedure FillAnswersCompositeTabularQuestion(TreeRow, Table)

	For ColumnIndex = 0 To TreeRow.TableQuestionComposition.Count() - 1 Do

		For RowIndex = 0 To Table.Count() - 1 Do

			Response = Table[RowIndex][ColumnIndex];
			If ValueIsFilled(Response) Then

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = TreeRow.TableQuestionComposition[ColumnIndex].ElementaryQuestion;
				NewRow.Response              = Response;
				NewRow.CellNumber        = RowIndex + 1;

			EndIf;
		EndDo;
	EndDo;

EndProcedure

// Gets answers to a question chart with predefined answers in rows, and appends them to the main table of answers. 
// 
//
// Parameters:
//  TreeRow - ValueTreeRow - a row of the questionnaire template tree.
//  Table      - ValueTable - Chart the question belongs to.
//
&AtServer
Procedure FillAnswersTabularQuestionAnswersInRows(TreeRow, Table)

	QuestionFirstColumn = TreeRow.TableQuestionComposition[0].ElementaryQuestion;
	NameOfColumnWithoutNumber = SurveysClientServer.QuestionName(TreeRow.Composite) + "TableColumn";

	For RowIndex = 0 To Table.Count() - 1 Do

		HasAtLeastOneAnswerSpecifiedByRespondent = False;

		For ColumnIndex = 1 To TreeRow.TableQuestionComposition.Count() - 1 Do

			Response = Table[RowIndex][NameOfColumnWithoutNumber + XMLString(ColumnIndex + 1)];
			If ValueIsFilled(Response) Then

				HasAtLeastOneAnswerSpecifiedByRespondent = True;

				NewRow                    = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = TreeRow.TableQuestionComposition[ColumnIndex].ElementaryQuestion;
				NewRow.Response              = Response;
				NewRow.CellNumber        = RowIndex + 1;

			EndIf;

		EndDo;

		If HasAtLeastOneAnswerSpecifiedByRespondent Then

			Response = Table[RowIndex][NameOfColumnWithoutNumber + "1"];
			If ValueIsFilled(Response) Then

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = QuestionFirstColumn;
				NewRow.Response              = Response;
				NewRow.CellNumber        = RowIndex + 1;

			EndIf;

		EndIf;

	EndDo;

EndProcedure

// Gets answers to a question chart with predefined answers in rows and columns, and appends them to the main table of answers. 
// 
//
// Parameters:
//  TreeRow - ValueTreeRow - a row of the questionnaire template tree.
//  Table      - ValueTable - Chart the question belongs to.
//
&AtServer
Procedure FillAnswersTabularQuestionAnswersInRowsAndColumns(TreeRow, Table)

	QuestionForRows   = TreeRow.TableQuestionComposition[0].ElementaryQuestion;
	QuestionForColumns = TreeRow.TableQuestionComposition[1].ElementaryQuestion;
	QuestionForCells   = TreeRow.TableQuestionComposition[2].ElementaryQuestion;

	RowsAnswers  = TreeRow.PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",
		QuestionForRows));
	ColumnsAnswers = TreeRow.PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",
		QuestionForColumns));

	NameOfColumnWithoutNumber = SurveysClientServer.QuestionName(TreeRow.Composite) + "TableColumn";

	For RowIndex = 0 To Table.Count() - 1 Do
		For ColumnIndex = 1 To Table.Columns.Count() - 1 Do

			Response = Table[RowIndex][NameOfColumnWithoutNumber + XMLString(ColumnIndex + 1)];
			If ValueIsFilled(Response) Then

				CellNumber = ColumnIndex + RowIndex * (Table.Columns.Count() - 1);

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = QuestionForRows;
				NewRow.Response              = RowsAnswers[RowIndex].Response;
				NewRow.CellNumber        = CellNumber;

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = QuestionForColumns;
				NewRow.Response              = ColumnsAnswers[ColumnIndex - 1].Response;
				NewRow.CellNumber        = CellNumber;

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = QuestionForCells;
				NewRow.Response              = Response;
				NewRow.CellNumber        = CellNumber;

			EndIf;
		EndDo;
	EndDo;

EndProcedure

// Gets answers to a question chart with predefined answers in columns, and appends them to the main table of answers. 
// 
//
// Parameters:
//  TreeRow - ValueTreeRow - a row of the questionnaire template tree.
//  Table      - ValueTable - Chart the question belongs to.
//
&AtServer
Procedure FillAnswersTabularQuestionAnswersInColumns(TreeRow, Table)

	QuestionForColumns = TreeRow.TableQuestionComposition[0].ElementaryQuestion;
	NameOfColumnWithoutNumber = SurveysClientServer.QuestionName(TreeRow.Composite) + "TableColumn";

	For ColumnIndex = 1 To Table.Columns.Count() - 1 Do

		HasAtLeastOneAnswerSpecifiedByRespondent = False;

		For RowIndex = 0 To Table.Count() - 1 Do

			Response = Table[RowIndex][NameOfColumnWithoutNumber + XMLString(ColumnIndex + 1)];
			If ValueIsFilled(Response) Then

				HasAtLeastOneAnswerSpecifiedByRespondent = True;

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = TreeRow.TableQuestionComposition[RowIndex + 1].ElementaryQuestion;
				NewRow.Response              = Response;
				NewRow.CellNumber        = ColumnIndex;

			EndIf;

		EndDo;

		If HasAtLeastOneAnswerSpecifiedByRespondent Then

			NewRow = Object.Content.Add();
			NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
			NewRow.ElementaryQuestion = QuestionForColumns;
			NewRow.Response              = TreeRow.PredefinedAnswers[ColumnIndex - 1].Response;
			NewRow.CellNumber        = ColumnIndex;

		EndIf;

	EndDo;

EndProcedure

// Gets answers to a basic question and appends them to the main table of answers. 
// 
//
// Parameters:
//  TreeRow   - ValueTreeRow - a row of the questionnaire template tree.
//
&AtServer
Procedure FillAnswerSimpleQuestion(TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);

	RefusalToAnswer = False;
	If TreeRow.ShouldUseRefusalToAnswer Then
		RefusalToAnswer = ThisObject[QuestionName + "_ShouldUseRefusalToAnswer"];
	EndIf;

	If TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

		OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, ThisObject);

		Counter = 0;
		For Each AnswerOption In OptionsOfAnswersToQuestion Do

			Counter = Counter + 1;
			AttributeName =  QuestionName + "_Attribute_" + Counter;

			If ThisObject[AttributeName] Then

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = TreeRow.ElementaryQuestion;
				NewRow.Response              = AnswerOption.Response;
				NewRow.CellNumber        = Counter;
				If AnswerOption.OpenEndedQuestion Then
					NewRow.OpenAnswer	= ThisObject[QuestionName + "_Comment_" + Counter];
				EndIf;

			EndIf;

		EndDo;

	ElsIf TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then

		OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(TreeRow.ElementaryQuestion, ThisObject);

		Counter = 0;
		IsAnswered = False;
		For Each AnswerOption In OptionsOfAnswersToQuestion Do

			Counter = Counter + 1;
			AttributeName =  QuestionName + "_Attribute_" + Counter;

			If ValueIsFilled(ThisObject[AttributeName]) Then

				IsAnswered = True;

				NewRow = Object.Content.Add();
				NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
				NewRow.ElementaryQuestion = TreeRow.ElementaryQuestion;
				NewRow.Response              = AnswerOption.Response;
				NewRow.CellNumber        = Counter;
				NewRow.IsUnanswered          = RefusalToAnswer;
				If TreeRow.CommentRequired Then
					NewRow.OpenAnswer = ThisObject[QuestionName + "_Comment"];
				EndIf;

			EndIf;

		EndDo;

		If Not IsAnswered And RefusalToAnswer Then
			NewRow = Object.Content.Add();
			NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
			NewRow.ElementaryQuestion = TreeRow.ElementaryQuestion;
			NewRow.IsUnanswered          = RefusalToAnswer;
		EndIf;

	Else

		Response = ThisObject[QuestionName];

		If ValueIsFilled(Response) Or Surveys.CanNumericFieldTakeZero(TreeRow)
			Or RefusalToAnswer Then

			NewRow = Object.Content.Add();
			NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
			NewRow.ElementaryQuestion = TreeRow.ElementaryQuestion;
			If TreeRow.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then
				NewRow.OpenAnswer = Response;
			Else
				NewRow.Response = Response;
				If TreeRow.CommentRequired Then
					NewRow.OpenAnswer = ThisObject[QuestionName + "_Comment"];
				EndIf;
			EndIf;
			NewRow.IsUnanswered = RefusalToAnswer;

		EndIf;

	EndIf;

EndProcedure

&AtServer
Procedure FillAnswersComplexQuestion(TreeRow)

	QuestionName = SurveysClientServer.QuestionName(TreeRow.Composite);

	For Each ComplexQuestionRow In TreeRow.ComplexQuestionComposition Do

		AttributeName =  QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber, "NG=");

		If ComplexQuestionRow.ElementaryQuestion.ReplyType
			<> Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then

			NewRow = Object.Content.Add();
			NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
			NewRow.ElementaryQuestion = ComplexQuestionRow.ElementaryQuestion;
			If ComplexQuestionRow.ElementaryQuestion.ReplyType = Enums.TypesOfAnswersToQuestion.Text Then
				NewRow.OpenAnswer = ThisObject[AttributeName];
			Else
				NewRow.Response              = ThisObject[AttributeName];
				If ComplexQuestionRow.CommentRequired Then
					NewRow.OpenAnswer	= ThisObject[QuestionName + "_Comment_" + Format(
						ComplexQuestionRow.LineNumber, "NG=")];
				EndIf;
			EndIf;

		Else

			OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(
				ComplexQuestionRow.ElementaryQuestion, ThisObject);

			Counter = 0;
			For Each AnswerOption In OptionsOfAnswersToQuestion Do

				Counter = Counter + 1;
				CurAttributeName =  AttributeName + "_Attribute_" + Counter;

				If ThisObject[CurAttributeName] Then

					NewRow = Object.Content.Add();
					NewRow.DoQueryBox             = TreeRow.TemplateQuestion;
					NewRow.ElementaryQuestion = ComplexQuestionRow.ElementaryQuestion;
					NewRow.Response              = AnswerOption.Response;
					NewRow.CellNumber        = Counter;
					If AnswerOption.OpenEndedQuestion Then
						NewRow.OpenAnswer	= ThisObject[AttributeName + "_Comment_" + Counter];
					EndIf;

				EndIf;

			EndDo;

		EndIf;

	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other

&AtServer
Procedure CreateFormAccordingToSection()
	
	CurrentDataSectionsTree = SectionsTree.FindByID(Items.SectionsTree.CurrentRow);
	If CurrentDataSectionsTree = Undefined Then
		Return;
	EndIf;

	If Not Items.QuestionnaireBodyGroup.ReadOnly Then
		ConvertSectionFillingResultsToTabularSection();
	EndIf;
	CurrentSectionNumber = Items.SectionsTree.CurrentRow;
	Surveys.CreateFillingFormBySection(ThisObject, CurrentDataSectionsTree);
	SetSectionFillingFormAttributesValues();
	Surveys.GenerateQuestionsSubordinationTable(ThisObject);
	SetOnChangeEventHandlerForQuestions();

	Items.FooterPreviousSection.Visible = (SectionQuestionsTable.Count() > 0);
	Items.FooterNextSection.Visible  = (SectionQuestionsTable.Count() > 0);

	SurveysClientServer.SwitchQuestionnaireBodyGroupsVisibility(ThisObject, True);

EndProcedure

// Returns:
//   Boolean
//
&AtServer
Function CheckQuestionnaireFilling()

	Query = New Query;
	Query.Text =
	"SELECT
	|	AnswerComposition.DoQueryBox,
	|	AnswerComposition.ElementaryQuestion,
	|	AnswerComposition.CellNumber,
	|	AnswerComposition.Response,
	|	AnswerComposition.OpenAnswer
	|INTO AnswerComposition
	|FROM
	|	&ExternalSource AS AnswerComposition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	QuestionsWithoutAnswers.Ref
	|INTO MandatoryQuestionsWithoutAnswers
	|FROM
	|	(SELECT
	|		QuestionnaireTemplateQuestions.Ref AS Ref,
	|		SUM(CASE
	|				WHEN AnswerComposition.Response IS NULL 
	|					THEN 0
	|				ELSE 1
	|			END) AS AnswerCount
	|	FROM
	|		Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|			LEFT JOIN AnswerComposition AS AnswerComposition
	|			ON (AnswerComposition.DoQueryBox = QuestionnaireTemplateQuestions.Ref)
	|	WHERE
	|		QuestionnaireTemplateQuestions.IsRequired
	|		AND (NOT QuestionnaireTemplateQuestions.DeletionMark)
	|		AND (NOT QuestionnaireTemplateQuestions.IsFolder)
	|		AND QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|		AND QuestionnaireTemplateQuestions.ParentQuestion = VALUE(Catalog.QuestionnaireTemplateQuestions.EmptyRef)
	|	
	|	GROUP BY
	|		QuestionnaireTemplateQuestions.Ref
	|	
	|	HAVING
	|		SUM(CASE
	|				WHEN AnswerComposition.Response IS NULL 
	|					THEN 0
	|				ELSE 1
	|			END) = 0
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		QuestionnaireTemplateQuestions.Ref,
	|		SUM(CASE
	|				WHEN AnswerComposition.Response IS NULL 
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|			LEFT JOIN AnswerComposition AS AnswerComposition
	|			ON QuestionnaireTemplateQuestions.Ref = AnswerComposition.DoQueryBox
	|	WHERE
	|		QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|		AND (NOT QuestionnaireTemplateQuestions.DeletionMark)
	|		AND (NOT QuestionnaireTemplateQuestions.IsFolder)
	|		AND QuestionnaireTemplateQuestions.ParentQuestion <> VALUE(Catalog.QuestionnaireTemplateQuestions.EmptyRef)
	|		AND QuestionnaireTemplateQuestions.ParentQuestion IN
	|				(SELECT DISTINCT
	|					NestedQuery.Ref
	|				FROM
	|					(SELECT
	|						QuestionnaireTemplateQuestions.Ref AS Ref,
	|						ISNULL(AnswerComposition.Response, FALSE) AS Response
	|					FROM
	|						Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions LEFT JOIN AnswerComposition AS AnswerComposition
	|							ON
	|								QuestionnaireTemplateQuestions.Ref = AnswerComposition.DoQueryBox
	|					WHERE
	|						QuestionnaireTemplateQuestions.QuestionType = VALUE(Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition)
	|						AND (NOT QuestionnaireTemplateQuestions.DeletionMark)
	|						AND (NOT QuestionnaireTemplateQuestions.IsFolder)
	|						AND QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|						AND ISNULL(AnswerComposition.Response, FALSE) = TRUE
	|					) AS NestedQuery)
	|		AND QuestionnaireTemplateQuestions.IsRequired
	|	
	|	GROUP BY
	|		QuestionnaireTemplateQuestions.Ref
	|	
	|	HAVING
	|		SUM(CASE
	|				WHEN AnswerComposition.Response IS NULL 
	|					THEN 0
	|				ELSE 1
	|			END) = 0) AS QuestionsWithoutAnswers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuestionnaireTemplateQuestions.Ref,
	|	QuestionnaireTemplateQuestions.Wording
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|WHERE
	|	QuestionnaireTemplateQuestions.Ref IN
	|			(SELECT
	|				MandatoryQuestionsWithoutAnswers.Ref
	|			FROM
	|				MandatoryQuestionsWithoutAnswers AS MandatoryQuestionsWithoutAnswers)
	|
	|ORDER BY
	|	QuestionnaireTemplateQuestions.Ref";

	Query.SetParameter("ExternalSource", Object.Content.Unload());
	Query.SetParameter("QuestionnaireTemplate", Object.QuestionnaireTemplate);

	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	EndIf;

	Selection = Result.Select();
	While Selection.Next() Do
		Common.MessageToUser(NStr("en = 'No response was given to question';") + "- " 
			+ StrReplace(Selection.Ref.FullCode(), "/", ".") + " " + Selection.Wording);
	EndDo;

	Return True;

EndFunction

// Parameters:
//  Response         - Characteristic.QuestionsForSurvey - an answer we are looking for.
//  AnswersArray - Array - an array of value table rows.
//
// Returns:
//   Structure:
//     * AttributeSequenceNumber - Number
//     * OpenEndedQuestion - Boolean
//
&AtServerNoContext
Function FindAnswerInArray(Response, AnswersArray)

	Result = New Structure;

	For IndexOf = 1 To AnswersArray.Count() Do

		If AnswersArray[IndexOf - 1].Response = Response Then

			Result.Insert("AttributeSequenceNumber", IndexOf);
			Result.Insert("OpenEndedQuestion", AnswersArray[IndexOf - 1].OpenEndedQuestion);
			Return Result;
		EndIf;

	EndDo;

	Return Undefined;

EndFunction

&AtServer
Procedure SetAttributesValuesBySurvey(AttributesSurvey)

	AllowSavingQuestionnaireDraft = AttributesSurvey.AllowSavingQuestionnaireDraft;
	QuestionnaireTemplate = AttributesSurvey.QuestionnaireTemplate;
	Introduction = ?(IsBlankString(AttributesSurvey.Introduction), 
		NStr("en = 'Click Next to fill out the questionnaire.';"), 
		AttributesSurvey.Introduction);
	ClosingStatement = ?(IsBlankString(AttributesSurvey.ClosingStatement), 
		NStr("en = 'Thank you for filling out the questionnaire.';"), 
		AttributesSurvey.ClosingStatement);

EndProcedure 

&AtServer
Function ReportAssignmentAttributesValues(Survey)

	Query = New Query;
	Query.Text =
	"SELECT
	|	PollPurpose.QuestionnaireTemplate,
	|	PollPurpose.RespondentsType,
	|	PollPurpose.AllowSavingQuestionnaireDraft,
	|	PollPurpose.Respondents.(
	|		Ref,
	|		LineNumber,
	|		Respondent
	|	),
	|	QuestionnaireTemplates.Title,
	|	QuestionnaireTemplates.Introduction,
	|	QuestionnaireTemplates.ClosingStatement
	|FROM
	|	Document.PollPurpose AS PollPurpose
	|		LEFT JOIN Catalog.QuestionnaireTemplates AS QuestionnaireTemplates
	|		ON PollPurpose.QuestionnaireTemplate = QuestionnaireTemplates.Ref
	|WHERE
	|	PollPurpose.Ref = &Survey";

	Query.SetParameter("Survey", Survey);

	Selection = Query.Execute().Select();
	Selection.Next();
	Return Selection;

EndFunction

&AtServerNoContext
Function QuestionnaireTemplateAttributesValues(QuestionnaireTemplate)

	Query = New Query;
	Query.Text =
	"SELECT
	|	QuestionnaireTemplates.Ref AS QuestionnaireTemplate,
	|	FALSE AS AllowSavingQuestionnaireDraft,
	|	QuestionnaireTemplates.Title,
	|	QuestionnaireTemplates.Introduction,
	|	QuestionnaireTemplates.ClosingStatement
	|FROM
	|	Catalog.QuestionnaireTemplates AS QuestionnaireTemplates
	|WHERE
	|	QuestionnaireTemplates.Ref = &QuestionnaireTemplate";

	Query.SetParameter("QuestionnaireTemplate", QuestionnaireTemplate);

	Selection = Query.Execute().Select();
	Selection.Next();
	Return Selection;

EndFunction

&AtServer
Procedure SetLabelHeader(AttributesSurvey)

	Title = ?(Not IsBlankString(Parameters.Title), Parameters.Title, AttributesSurvey.Title);
	Items.IntroductionLabel.Title = AttributesSurvey.Introduction;
	Introduction = AttributesSurvey.Introduction;

EndProcedure

&AtClient
Procedure AvailabilityControlSubordinateQuestions(SetModification = True)

	For Each CollectionItem In DependentQuestions Do

		QuestionName = SurveysClientServer.QuestionName(CollectionItem.DoQueryBox);
		For Each SubordinateQuestion In CollectionItem.SubordinateItems Do

			ItemOfSubordinateQuestion = Items[SubordinateQuestion.SubordinateQuestionItemName];
			ItemOfSubordinateQuestion.ReadOnly = Not ThisObject[QuestionName];
			If StrOccurrenceCount(SubordinateQuestion.SubordinateQuestionItemName, "Attribute") = 0 Then
				ValueAutoMarkUnfilled = ThisObject[QuestionName] And SubordinateQuestion.IsRequired;
				Try
					ItemOfSubordinateQuestion.AutoMarkIncomplete = ValueAutoMarkUnfilled;
				Except
					// 
				EndTry;
			EndIf;
		EndDo;
	EndDo;

	If AllowSavingQuestionnaireDraft And SetModification Then
		Modified = True;
	EndIf;

	ClearMarkIncomplete();

EndProcedure

&AtServer
Procedure SetVisibilityAccessibilityOfFormElements()

	If Parameters.FillingFormOnly Then

		IsInterview = Object.SurveyMode = PredefinedValue("Enum.SurveyModes.Interview");

		Items.MainAttributesGroup.Visible              = IsInterview;
		Items.Date.Enabled                               = False;
		Items.FormCommandBarPostAndClose.Visible = False;
		Items.FormCommandBarWrite.Visible         = False;
		Items.Post.Visible                             = False;
		Items.FormUndoPosting.Visible                = False;
		Items.FormReread.Visible                      = False;
		Items.QuestionnaireShowInList.Visible                = False;
		Items.FormSetDeletionMark.Visible       = False;
		Items.Comment.Visible                          = False;

		Items.SurveyMode.ReadOnly = IsInterview;
		Items.Survey.ReadOnly              = IsInterview;
		Items.QuestionnaireTemplate.ReadOnly       = IsInterview;

		If Object.Ref.IsEmpty() Then
			Object.Date = CurrentSessionDate();
		EndIf;

		If Parameters.ReadOnly = True Then

			Items.QuestionnaireBodyGroup.ReadOnly          = True;
			Items.FillingFormEndAndClose.Visible = False;
			Items.ResponseFormWrite.Visible        = False;

		Else

			Items.ResponseFormWrite.Visible = AllowSavingQuestionnaireDraft;
			Items.FillingFormEndAndClose.DefaultButton = True;

		EndIf;

		Modified = False;

	Else

		Items.FillingFormEndAndClose.Visible = False;
		Items.ResponseFormWrite.Visible        = False;
		Items.QuestionnaireBodyGroup.ReadOnly          = True;
		Items.MainAttributesGroup.ReadOnly   = True;

	EndIf;

EndProcedure

&AtServer
Procedure SetOnChangeEventHandlerForQuestions()

	If Not AllowSavingQuestionnaireDraft Then
		Return;
	EndIf;

	For Each TableRow In SectionQuestionsTable Do

		If TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.QuestionWithCondition Then
			Continue;
		EndIf;

		QuestionName = SurveysClientServer.QuestionName(TableRow.Composite);

		If TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then
			Items[QuestionName + "_Table"].SetAction("OnChange", "Attachable_OnChangeQuestion");
		ElsIf TableRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Complex Then
			SetOnChangeEventHandlerForComplexQuestions(TableRow, QuestionName);
		Else
			If TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor
				Or TableRow.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf Then
				OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(TableRow.ElementaryQuestion,
					ThisObject);
				For IndexOf = 1 To OptionsOfAnswersToQuestion.Count() Do
					Items[QuestionName + "_Attribute_" + IndexOf].SetAction("OnChange",
						"Attachable_OnChangeQuestion");
					If OptionsOfAnswersToQuestion[IndexOf - 1].OpenEndedQuestion Then
						Items[QuestionName + "_Comment_" + IndexOf].SetAction("OnChange",
							"Attachable_OnChangeQuestion");
					EndIf;
				EndDo;
			Else
				If Not TableRow.ShouldShowRangeSlider Then
					Items[QuestionName].SetAction("OnChange", "Attachable_OnChangeQuestion");
				EndIf;
			EndIf;
			If TableRow.CommentRequired Then
				Items[QuestionName + "_Comment"].SetAction("OnChange",
					"Attachable_OnChangeQuestion");
				Items[QuestionName + "_Comment"].SetAction("StartChoice",
					"Attachable_ChoiceStartComment");
			EndIf;
			If TableRow.ShouldUseRefusalToAnswer 
				And TableRow.ReplyType <> Enums.TypesOfAnswersToQuestion.Boolean Then
				Items[QuestionName + "_ShouldUseRefusalToAnswer"].SetAction("OnChange",
					"Attachable_OnChangeFlagDoNotAnswerQuestion");
			EndIf;
		EndIf;

	EndDo;

EndProcedure

&AtServer
Procedure SetOnChangeEventHandlerForComplexQuestions(TableRow, QuestionName)

	For Each ComplexQuestionRow In TableRow.ComplexQuestionComposition Do

		FoundRows = QuestionsPresentationTypes.FindRows(New Structure("DoQueryBox",
			ComplexQuestionRow.ElementaryQuestion));
		If FoundRows.Count() > 0 Then
			ElementaryQuestionAttributes = FoundRows[0];
		Else
			Continue;
		EndIf;

		If ElementaryQuestionAttributes.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
			OptionsOfAnswersToQuestion = Surveys.OptionsOfAnswersToQuestion(
				ComplexQuestionRow.ElementaryQuestion, ThisObject);
			For IndexOf = 1 To OptionsOfAnswersToQuestion.Count() Do
				QuestionAttributeName1 = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber, "NG=")
					+ "_Attribute_" + IndexOf;
				Items[QuestionAttributeName1].SetAction("OnChange", "Attachable_OnChangeQuestion");
				If OptionsOfAnswersToQuestion[IndexOf - 1].OpenEndedQuestion Then
					CommentAttributeName = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber,
						"NG=") + "_Comment_" + IndexOf;
					Items[CommentAttributeName].SetAction("OnChange",
						"Attachable_OnChangeQuestion");
				EndIf;
			EndDo;
		Else
			QuestionAttributeName1 = QuestionName + "_Response_" + Format(ComplexQuestionRow.LineNumber, "NG=");
			Items[QuestionAttributeName1].SetAction("OnChange", "Attachable_OnChangeQuestion");
			If ComplexQuestionRow.CommentRequired Then
				CommentAttributeName = QuestionName + "_Comment_" + Format(ComplexQuestionRow.LineNumber, "NG=");
				Items[CommentAttributeName].SetAction("OnChange", "Attachable_OnChangeQuestion");
			EndIf;
		EndIf;

	EndDo;

EndProcedure

&AtClient
Procedure ExecuteFillingFormCreation()

	SurveysClientServer.SwitchQuestionnaireBodyGroupsVisibility(ThisObject, False);
	AttachIdleHandler("EndBuildFillingForm", 0.1, True);

EndProcedure

&AtClient
Procedure EndBuildFillingForm()

	CreateFormAccordingToSection();
	AvailabilityControlSubordinateQuestions(PreviousSectionWithoutQuestions = False And Not IsCommonUserSession
		And Not ReadOnly);
	SetSectionsNavigationAvailability();
	HighlightAnsweredQuestions();

	ItemForPositioning = Items.Find(PositioningItemName);
	If ItemForPositioning <> Undefined Then
		CurrentItem = ItemForPositioning;
	EndIf;

EndProcedure

&AtClient
Procedure ChangeSectionsTreeVisibility()

	Items.SectionsTreeGroup.Visible = Not Items.SectionsTreeGroup.Visible;
	TitleSectionsCommand = ?(Items.SectionsTreeGroup.Visible, NStr("en = 'Hide sections';"), 
		NStr("en = 'Show sections';"));
	Items.HideShowSectionsTreeDocument.Title = TitleSectionsCommand;

EndProcedure

&AtClient
Procedure SetSectionsNavigationAvailability()

	AvailabilityPreviousSection = (Items.SectionsTree.CurrentRow > 0);
	AvailabilityNextSection  = (SectionsTree.FindByID(Items.SectionsTree.CurrentRow + 1)
		<> Undefined);

	Items.FooterPreviousSection.Enabled = AvailabilityPreviousSection;
	Items.PreviousSection.Enabled = AvailabilityPreviousSection;
	Items.FooterNextSection.Enabled = AvailabilityNextSection;
	Items.NextSection.Enabled = AvailabilityNextSection;

EndProcedure

&AtClient
Procedure ChangeSection(Direction)

	Items.SectionsTree.CurrentRow = CurrentSectionNumber + ?(Direction = "GoForward", 1, -1);
	CurrentSectionNumber = CurrentSectionNumber + ?(Direction = "GoForward", 1, -1);
	CurrentDataSectionsTree = SectionsTree.FindByID(Items.SectionsTree.CurrentRow);
	If CurrentDataSectionsTree.QuestionsCount = 0 And CurrentDataSectionsTree.RowType = "Section" Then
		ChangeSection(Direction);
	EndIf;
	ExecuteFillingFormCreation();

EndProcedure

&AtClient
Procedure PromptForAcceptingQuestionnaireAfterCompletion(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;

	Cancel = EndEditFillingForm(DocumentWriteMode.Posting);
	If Not Cancel Then
		ShowUserNotification(NStr("en = 'Edited';"),, String(Object.Ref), PictureLib.Information32);
		Notify("PostingQuestionnaire", New Structure, Object.Ref);
		Modified = False;
		Close();
	EndIf;

EndProcedure

// Parameters:
//   ChangedText         - String
//   AdditionalParameters - Structure
//
&AtClient
Procedure EditMultilineTextOnEnd(ChangedText, AdditionalParameters) Export

	Item = AdditionalParameters.Item;

	If TypeOf(Item.Parent) = Type("FormGroup") Then
		If ThisObject[Item.Name] <> ChangedText Then
			ThisObject[Item.Name] = ChangedText;
			Modified = True;
		EndIf;
	Else

		FoundRow = ThisObject[Item.Parent.Name].FindByID(Item.Parent.CurrentRow);
		RowIndex    = ThisObject[Item.Parent.Name].IndexOf(FoundRow);

		If ThisObject[Item.Parent.Name][RowIndex][Item.Name] <> ChangedText Then
			ThisObject[Item.Parent.Name][RowIndex][Item.Name] = ChangedText;
			Modified = True;
		EndIf;

	EndIf;

EndProcedure

&AtClient
Procedure HighlightAnsweredQuestions()

	SurveysClient.HighlightAnsweredQuestions(ThisObject);

EndProcedure

&AtClientAtServerNoContext
Procedure ChangeFormItemsVisibility(Form)

	IsInterview = Form.Object.SurveyMode = PredefinedValue("Enum.SurveyModes.Interview");
	Form.Items.Survey.Visible = Not IsInterview;
	Form.Items.QuestionnaireTemplate.Visible = IsInterview;
	Form.Items.Interviewer.Visible = IsInterview;

EndProcedure

// Standard subsystems.Pluggable commands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// 

#EndRegion