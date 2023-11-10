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
Procedure OnCreateAtServer(Cancel,StandardProcessing)
	
	SetConditionalAppearance();
	
	Surveys.SetQuestionnaireTreeRootItem(QuestionnaireTree);
	Surveys.FillQuestionnaireTemplateTree(ThisObject,"QuestionnaireTree",Object.Ref);
	SurveysClientServer.GenerateTreeNumbering(QuestionnaireTree);
	SetConditionalFormAppearance();
	DetermineIfThereAreQuestionnairesForThisTemplate();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	Items.QuestionnaireTreeForm.Expand(QuestionnaireTree.GetItems()[0].GetID(),False);
	
	If Object.TemplateEditCompleted Or TemplateHasQuestionnaires Then
		SetEditingUnavailability();
	Else
		DetermineTemplateTreeAvailability();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Surveys.DeleteQuestionnaireTemplateQuestions(Object.Ref);
	QuestionnaireTemplateTree  = FormAttributeToValue("QuestionnaireTree");
	
	WriteQuestionnaireTemplateTree(QuestionnaireTemplateTree.Rows[0],1);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If EventName = "EndEditTableQuestionParameters" Then
		
		ProcessTabularQuestionWizardResult(CurrentData,Parameter,Items.QuestionnaireTreeForm.CurrentRow);
		Modified = True;
		
	ElsIf EventName = "EndEditComplexQuestionParameters" Then
		
		ProcessComplexQuestionsWizardResult(CurrentData,Parameter,Items.QuestionnaireTreeForm.CurrentRow);
		Modified = True;
		
	ElsIf EventName = "EndEditQuestionnaireTemplateLineParameters" Then
		
		FillPropertyValues(CurrentData,Parameter);
		CurrentData.HasNotes = Not IsBlankString(CurrentData.Notes);
		Modified = True;
		
		If CurrentData.RowType <> "DoQueryBox" Then
			CurrentData.IsRequired = Undefined;
		EndIf;
		
	ElsIf EventName = "CancelEnterNewQuestionnaireTemplateLine" Then
		If CurrentData.IsNewLine Then
			CurrentRow = QuestionnaireTree.FindByID(CurrentData.GetID());
			If CurrentRow <> Undefined Then
				CurrentRow.GetParent().GetItems().Delete(CurrentRow);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	QuestionnaireTemplateTree  = FormAttributeToValue("QuestionnaireTree");
	
	If QuestionnaireTemplateTree.Rows[0].Rows.Find("","Wording",True) <> Undefined Then
		Common.MessageToUser(NStr("en = 'Not all wordings or section names are filled in.';"),,"QuestionnaireTree");
		Cancel = True;
	EndIf;
	
	FilterStructure1 = New Structure;
	FilterStructure1.Insert("ElementaryQuestion",ChartsOfCharacteristicTypes.QuestionsForSurvey.EmptyRef());
	FilterStructure1.Insert("RowType","DoQueryBox");
	
	FoundRows = QuestionnaireTemplateTree.Rows[0].Rows.FindRows(FilterStructure1,True);
	If FoundRows.Count() <> 0 Then
		For Each FoundRow In FoundRows Do
			If FoundRow.QuestionType <> Enums.QuestionnaireTemplateQuestionTypes.Tabular
					And FoundRow.QuestionType <> Enums.QuestionnaireTemplateQuestionTypes.Complex Then
				
				Common.MessageToUser(NStr("en = 'Not all questions are filled in.';"),,"QuestionnaireTree");
				Cancel = True;
				Break;
				
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	DetermineTemplateTreeAvailability();
	If Object.TemplateEditCompleted Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region QuestionnaireTreeFormFormTableItemEventHandlers

&AtClient
Procedure QuestionnaireTreeFormBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.RowType = "Root" Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormOnActivateRow(Item)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If (String = Undefined) Or (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
		
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Number") Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	AssignmentRow     = QuestionnaireTree.FindByID(String);
	RowDrag = QuestionnaireTree.FindByID(DragParameters.Value);
	
	If (RowDrag.RowType = "Section") And (AssignmentRow.RowType = "DoQueryBox")
		Or (RowDrag.RowType = "DoQueryBox") And (AssignmentRow.RowType = "Root")	Then
		DragParameters.Action = DragAction.Cancel;
	ElsIf (RowDrag.RowType = "Section") And (AssignmentRow.RowType = "Section") Then
		If RowDrag.TemplateQuestion = AssignmentRow.TemplateQuestion Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
		Parent = AssignmentRow.GetParent();
		While Parent.RowType <> "Root" Do
			If Parent = RowDrag Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			Parent = Parent.GetParent();
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormDragStart(Item, DragParameters, StandardProcessing)
	
	If Items.QuestionnaireTreeForm.ReadOnly Then
		StandardProcessing = False;
		DragParameters.Action = DragAction.Cancel;
	EndIf; 
	
	RowDrag = QuestionnaireTree.FindByID(DragParameters.Value);
	If TypeOf(RowDrag) = Type("Undefined") Then
		StandardProcessing = False;
		DragParameters.Action = DragAction.Cancel;
	Else
		If RowDrag.RowType = "Root" Then
			StandardProcessing = False;
			DragParameters.Action = DragAction.Cancel;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	AssignmentRow     = QuestionnaireTree.FindByID(String);
	RowDrag = QuestionnaireTree.FindByID(DragParameters.Value);
	
	If (RowDrag.RowType = "DoQueryBox") And (AssignmentRow.RowType = "DoQueryBox") Then
		
		// Dragging a question without condition to a question with condition.
		If RowDrag.QuestionType <> PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition")
			And AssignmentRow.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition") Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, False);
				Modified = True;
			EndIf;
			
		ElsIf RowDrag.GetParent() <> AssignmentRow.GetParent() Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, True);
				Modified = True;
			EndIf;
			
		EndIf;
		
	ElsIf (RowDrag.RowType = "DoQueryBox") And (AssignmentRow.RowType = "Section") Then
		
		If RowDrag.GetParent() <> AssignmentRow Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, False);
				Modified = True;
			EndIf;
			
		EndIf;
		
	ElsIf (RowDrag.RowType = "Section") And (AssignmentRow.RowType = "Section") Then
		
		If RowDrag.GetParent() <> AssignmentRow Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, False);
				Modified = True;
			EndIf;
			
		ElsIf RowDrag.GetParent() <> AssignmentRow.GetParent() Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, True);
				Modified = True;
			EndIf;
			
		EndIf;
		
	ElsIf (RowDrag.RowType = "Section") And (AssignmentRow.RowType = "DoQueryBox") Then
		
		If RowDrag.GetParent() <> AssignmentRow.GetParent() Then
			
			StandardProcessing = False;
			If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
				DragTreeItem(AssignmentRow, RowDrag, True);
				Modified = True;
			EndIf;
			
		EndIf;
		
	ElsIf ((RowDrag.RowType = "Section") Or (RowDrag.RowType = "DoQueryBox")) And (AssignmentRow.RowType = "Root") Then
		
		StandardProcessing = False;
		If Not TheseAreSubordinateElements(RowDrag, AssignmentRow) Then
			DragTreeItem(AssignmentRow, RowDrag, False);
			Modified = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormOnChange(Item)
	
	Modified = True;
	SurveysClientServer.GenerateTreeNumbering(QuestionnaireTree);
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.RowType = "Root" Then
		Cancel = True;
		Return;
	ElsIf CurrentData.RowType = "Section" 
		Or (CurrentData.RowType = "DoQueryBox" 
		                               And CurrentData.QuestionType <> PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular")
		                               And CurrentData.QuestionType <> PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex")) Then
		
		OpenSimpleQuestionsForm(CurrentData);
		
	ElsIf CurrentData.RowType = "DoQueryBox" And CurrentData.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex") Then
		
		OpenComplexQuestionsWizardForm(CurrentData);
		
	ElsIf CurrentData.RowType = "DoQueryBox" And CurrentData.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular") Then
		
		OpenTabularQuestionsWizardForm(CurrentData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	ChoiceList = New ValueList;
	ChoiceList.Add("Section", NStr("en = 'Section';"));
	ChoiceList.Add("Basic", NStr("en = 'Basic question';"));
	ChoiceList.Add("Complex", NStr("en = 'Interview question';"));
	ChoiceList.Add("Conditional", NStr("en = 'Conditional question';"));
	ChoiceList.Add("Tabular", NStr("en = 'Question chart';"));
	
	OnCloseNotifyHandler = New NotifyDescription("SelectAddedItemTypeOnCompletion", ThisObject);
	ChoiceList.ShowChooseItem(OnCloseNotifyHandler, NStr("en = 'Select a type of the item being added.';"), ChoiceList[0]);
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormDragEnd(Item, DragParameters, StandardProcessing)
	
	SurveysClientServer.GenerateTreeNumbering(QuestionnaireTree);
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeFormSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Items.QuestionnaireTreeForm.ReadOnly Then
		Return;	
	EndIf;
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.RowType = "Root" Then
		Return;
	ElsIf CurrentData.RowType = "Section" 
		Or (CurrentData.RowType = "DoQueryBox" And CurrentData.QuestionType <> PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular")
												And CurrentData.QuestionType <> PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex") ) Then
		
		OpenSimpleQuestionsForm(CurrentData);
		
	ElsIf CurrentData.RowType = "DoQueryBox" And CurrentData.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex") Then
		
		OpenComplexQuestionsWizardForm(CurrentData);
		
	ElsIf CurrentData.RowType = "DoQueryBox" And CurrentData.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular") Then
		
		OpenTabularQuestionsWizardForm(CurrentData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeNotesOnChange(Item)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.HasNotes = Not IsBlankString(CurrentData.HasNotes);
	
EndProcedure

&AtClient
Procedure QuestionnaireTreeNotesStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClosingNotification1 = New NotifyDescription("NoteEditOnClose", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(ClosingNotification1, Item.EditText, NStr("en = 'Notes';"));
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EndEdit(Command)
	
	Object.TemplateEditCompleted = True;
	Write();
	
	If Modified Then
		Object.TemplateEditCompleted = False;
	Else
		SetEditingUnavailability();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddSection(Command)
	
	If Not WriteIfNewExecutedSuccessfully() Then
		Return;
	EndIf;
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
		
	Parent = GetParentQuestionnaireTree(CurrentData,True);
	AddQuestionnaireTreeRow(Parent,"Section");
	
EndProcedure

&AtClient
Procedure AddSimpleQuestion(Command)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AddQuestion(CurrentData,PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Basic"));
	
EndProcedure 

&AtClient
Procedure AddComplexQuestion(Command)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AddQuestion(CurrentData,PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex"));
	
EndProcedure

&AtClient
Procedure AddQuestionWithCondition(Command)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AddQuestion(CurrentData,PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition"));
	
EndProcedure

&AtClient
Procedure AddTabularQuestion(Command)
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AddQuestion(CurrentData,PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular"));
	
EndProcedure 

&AtClient
Procedure OpenQuestionnaireResponseForm(Command)
	
	If Not WriteIfNewExecutedSuccessfully() Then
		Return;
	EndIf;
	
	If Modified Then
		OnCloseNotifyHandler = New NotifyDescription("PromptForWriteRequiredAfterCompletion", ThisObject);
		ShowQueryBox(OnCloseNotifyHandler,
		               NStr("en = 'The questionnaire template was modified. 
		                   |To display all the changes correctly, save the template.
		                   |Do you want to save it?';"),
		               QuestionDialogMode.YesNo,
		               ,
		               DialogReturnCode.Yes,
		               NStr("en = 'Do you want to save it?';"));
	Else
		OpenQuestionnaireWizardFormBySections();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.QuestionnaireTreeIsRequired.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuestionnaireTree.RowType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = NStr("en = 'Question';");

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.QuestionnaireTreeIsRequired.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuestionnaireTree.QuestionType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.QuestionnaireTemplateQuestionTypes.Tabular;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.QuestionnaireTreeWording.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuestionnaireTree.RowType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = NStr("en = 'Root';");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuestionnaireTree.Wording");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);

EndProcedure

// Parameters:
//   Parent   - ValueTreeRow - an item of the form values tree, from which a new branch starts.
//   RowType  - String - a type of a tree row.
//   
// Returns:
//   String
//
&AtClient
Function AddQuestionnaireTreeRow(Parent,RowType,QuestionType = Undefined)
	
	TreeItems = Parent.GetItems();
	NewRow    = TreeItems.Add();
	
	NewRow.RowType      = RowType;
	NewRow.IsRequired   = False;
	NewRow.Composite     = New UUID;
	NewRow.IsNewLine = True;
	
	If RowType = "DoQueryBox" Then
		
		NewRow.QuestionType         = QuestionType;
		NewRow.PictureCode        = SurveysClientServer.GetQuestionnaireTemplatePictureCode(False,QuestionType);
		NewRow.ElementaryQuestion = ?(QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular")
		                                   Or QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex"),
		                                   "",
		                                   PredefinedValue("ChartOfCharacteristicTypes.QuestionsForSurvey.EmptyRef"));
		NewRow.IsRequired       = ?(QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular")
		                                   Or QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex"),"",False);
		
	Else
		
		NewRow.QuestionType         = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.EmptyRef");
		NewRow.PictureCode        = SurveysClientServer.GetQuestionnaireTemplatePictureCode(True);
		NewRow.ElementaryQuestion = "";
		NewRow.IsRequired       = "";
		
	EndIf;
	
	NewRow.HintPlacement = PredefinedValue("Enum.TooltipDisplayMethods.AsTooltip");
	
	SurveysClientServer.GenerateTreeNumbering(QuestionnaireTree);
	Items.QuestionnaireTreeForm.CurrentRow = NewRow.GetID();
	
	Modified = True;
	Items.QuestionnaireTreeForm.ChangeRow();
	
	Return NewRow;
	
EndFunction

&AtServer
Procedure WriteQuestionnaireTemplateTree(TreeRowParent,RecursionLevel,CatalogParent = Undefined)
	
	Counter = 0;
	
	For Each TreeRow In TreeRowParent.Rows Do
		
		Counter = Counter + 1;
		CatRef = AddQuestionnaireTemplateQuestionCatalogItem(TreeRow,?(RecursionLevel = 1,Counter,Undefined),CatalogParent);
		
		If TreeRow.Rows.Count() > 0 Then
			If TreeRow.RowType = "Section" Then
				WriteQuestionnaireTemplateTree(TreeRow,RecursionLevel+1,CatRef);
			Else
				For Each RowSubordinateQuestion In TreeRow.Rows Do
					AddQuestionnaireTemplateQuestionCatalogItem(RowSubordinateQuestion,Undefined,CatalogParent,CatRef);
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function AddQuestionnaireTemplateQuestionCatalogItem(TreeRow,Code = Undefined,CatalogParent = Undefined,QuestionParent = Undefined)
	
	If TreeRow.RowType = "Section" Then
		
		CatObject = Catalogs.QuestionnaireTemplateQuestions.CreateFolder();
		
	Else
		
		CatObject = Catalogs.QuestionnaireTemplateQuestions.CreateItem();
		CatObject.QuestionType                        = TreeRow.QuestionType;
		CatObject.ElementaryQuestion                = TreeRow.ElementaryQuestion;
		CatObject.TabularQuestionType              = TreeRow.TabularQuestionType;
		CatObject.IsRequired                      = TreeRow.IsRequired;
		CatObject.ToolTip                         = TreeRow.ToolTip;
		CatObject.HintPlacement        = TreeRow.HintPlacement;
		CatObject.ShouldUseRefusalToAnswer     = TreeRow.ShouldUseRefusalToAnswer;
		CatObject.RefusalToAnswerText      = TreeRow.RefusalToAnswerText;
		CatObject.ParentQuestion                    = ?(QuestionParent = Undefined, Catalogs.QuestionnaireTemplateQuestions.EmptyRef(),QuestionParent);
		CommonClientServer.SupplementTable(TreeRow.TableQuestionComposition,CatObject.TableQuestionComposition);
		CommonClientServer.SupplementTable(TreeRow.PredefinedAnswers,CatObject.PredefinedAnswers);
		CommonClientServer.SupplementTable(TreeRow.ComplexQuestionComposition,CatObject.ComplexQuestionComposition);
		
	EndIf;
	
	If Code <> Undefined Then
		CatObject.Code = Code;
	EndIf;
	CatObject.Description = TreeRow.Wording;
	CatObject.Notes      = TreeRow.Notes;
	CatObject.Wording = TreeRow.Wording;
	CatObject.Parent     = ?(CatalogParent = Undefined,Catalogs.QuestionnaireTemplateQuestions.EmptyRef(),CatalogParent);
	CatObject.Owner    = Object.Ref;
	
	CatObject.Write();
	
	Return CatObject.Ref;
	
EndFunction

// Parameters:
//  CurrentData -FormDataTreeItem - the current data of the template tree.
//  Parameter  - Structure - Result of the question chart wizard.
//
&AtClient
Procedure ProcessTabularQuestionWizardResult(CurrentData,Parameter,CurrentRow)
	
	CurrentData.TableQuestionComposition.Clear();
	CurrentData.PredefinedAnswers.Clear();
	
	CurrentData.TabularQuestionType       = Parameter.TabularQuestionType;
	CurrentData.Description               = Parameter.Wording;
	CurrentData.Wording               = Parameter.Wording;
	CurrentData.ElementaryQuestion         = Parameter.Wording;
	CurrentData.IsRequired               = "";
	CurrentData.ToolTip                  = Parameter.ToolTip;
	CurrentData.HintPlacement = Parameter.HintPlacement;
	CurrentData.IsNewLine             = False;
	
	LineNumber = 1;
	For Each DoQueryBox In Parameter.Questions Do
	
		NewRow = CurrentData.TableQuestionComposition.Add();
		NewRow.ElementaryQuestion = DoQueryBox;
		NewRow.LineNumber        = LineNumber;
		
		LineNumber = LineNumber + 1;
	
	EndDo;
	
	For Each Response In Parameter.Replies Do
		FillPropertyValues(CurrentData.PredefinedAnswers.Add(),Response);
	EndDo;
	
	SetConditionalFormAppearance();
	
EndProcedure

&AtClient
Procedure ProcessComplexQuestionsWizardResult(CurrentData,Parameter,CurrentRow)
	
	CurrentData.ComplexQuestionComposition.Clear();
	
	CurrentData.Description               = Parameter.Wording;
	CurrentData.Wording               = Parameter.Wording;
	CurrentData.ElementaryQuestion         = Parameter.Wording;
	CurrentData.IsRequired               = "";
	CurrentData.ToolTip                  = Parameter.ToolTip;
	CurrentData.HintPlacement = Parameter.HintPlacement;
	CurrentData.IsNewLine             = False;
	
	LineNumber = 1;
	For Each DoQueryBox In Parameter.Questions Do
	
		NewRow = CurrentData.ComplexQuestionComposition.Add();
		NewRow.ElementaryQuestion = DoQueryBox;
		NewRow.LineNumber        = LineNumber;
		
		LineNumber = LineNumber + 1;
	
	EndDo;
	
	SetConditionalFormAppearance();
	
EndProcedure

&AtServer
Procedure SetConditionalFormAppearance();
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("QuestionnaireTree.RowType");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	DataFilterItem.Use = True;
	DataFilterItem.RightValue = "DoQueryBox";
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Use = True;
	AppearanceField.Field          = New DataCompositionField("QuestionnaireTreeIsRequired");
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor",WebColors.Gainsboro);
	
EndProcedure

&AtServer
Procedure DetermineIfThereAreQuestionnairesForThisTemplate()
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "
	|SELECT TOP 1
	|	Questionnaire.Ref
	|FROM
	|	Document.Questionnaire AS Questionnaire
	|WHERE
	|	(NOT Questionnaire.DeletionMark)
	|	AND Questionnaire.Survey IN
	|			(SELECT
	|				PollPurpose.Ref
	|			FROM
	|				Document.PollPurpose AS PollPurpose
	|			WHERE
	|				PollPurpose.QuestionnaireTemplate = &QuestionnaireTemplate)";
	
	Query.SetParameter("QuestionnaireTemplate",Object.Ref);
	
	If Not Query.Execute().IsEmpty() Then
		
		TemplateHasQuestionnaires = True;
		
	Else
		
		TemplateHasQuestionnaires = False;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

&AtClient
Function GetParentQuestionnaireTree(CurrentParent,CanBeRoot,QuestionType = Undefined)
	
	If CanBeRoot Then
		
		While (CurrentParent.RowType <> "Root") And (CurrentParent.RowType <> "Section") Do
			CurrentParent = CurrentParent.GetParent();
			If CurrentParent = Undefined Then
				Return QuestionnaireTree.GetItems()[0];
			EndIf;
		EndDo;
		
	Else 
		
		While (CurrentParent.RowType <> "Section")
			And ((CurrentParent.RowType = "DoQueryBox") And (Not CurrentParent.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition"))
			Or (CurrentParent.RowType = "DoQueryBox" And  CurrentParent.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition") And QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition"))) Do
			
			CurrentParent = CurrentParent.GetParent();
			
		EndDo
		
	EndIf;
	
	Return CurrentParent;
	
EndFunction

// Parameters:
//  CurrentData - FormDataTreeItem
//  QuestionType    - EnumRef.QuestionnaireTemplateQuestionTypes
//
&AtClient
Procedure AddQuestion(CurrentData, QuestionType)

	Parent = GetParentQuestionnaireTree(CurrentData, False, QuestionType);
	If Parent.RowType = "Root" Then
		ShowMessageBox(, NStr("en = 'Cannot add questions to the questionnaire root.';"));
		Return;
	EndIf;
	AddQuestionnaireTreeRow(Parent, "DoQueryBox", QuestionType);

EndProcedure

&AtClient
Procedure DetermineTemplateTreeAvailability()
	
	EditingUnavailability   = Object.TemplateEditCompleted Or TemplateHasQuestionnaires;
	
	Items.QuestionnaireTree.ReadOnly                                      = EditingUnavailability;
	Items.QuestionnaireTreeForm.ReadOnly                                 = EditingUnavailability;
	Items.EndEdit.Enabled                              = Not EditingUnavailability;
	Items.QuestionnaireTreeForm.CommandBar.Enabled                    = Not EditingUnavailability;
	Items.QuestionnaireTreeForm.ContextMenu.Enabled                    = Not EditingUnavailability;
	Items.QuestionnaireTreeFormContextMenuAdd.Enabled             = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuAddSection.Enabled            = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuMoveUp.Enabled          = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuMoveDown.Enabled           = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuAddQuestion.Enabled            = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuAddConditionalQuestion.Enabled   = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuAddTableQuestion.Enabled   = Not EditingUnavailability;
	Items.QuestionnaireTreeContextMenuAddInterviewQuestion.Enabled = Not EditingUnavailability;
	
EndProcedure

&AtClient
Procedure SetEditingUnavailability()
	
	If Object.TemplateEditCompleted Or TemplateHasQuestionnaires Then
		
		ReadOnly                                                 = True;
		Items.QuestionnaireTree.ReadOnly                                      = True;
		Items.QuestionnaireTreeForm.ReadOnly                                 = True;
		Items.QuestionnaireTreeForm.CommandBar.Enabled                    = False;
		Items.QuestionnaireTreeContextMenuAddSection.Enabled            = False;
		Items.QuestionnaireTreeContextMenuMoveUp.Enabled          = False;
		Items.QuestionnaireTreeContextMenuMoveDown.Enabled           = False;
		Items.QuestionnaireTreeContextMenuAddQuestion.Enabled            = False;
		Items.QuestionnaireTreeContextMenuAddConditionalQuestion.Enabled   = False;
		Items.QuestionnaireTreeContextMenuAddTableQuestion.Enabled   = False;
		Items.QuestionnaireTreeContextMenuAddInterviewQuestion.Enabled = False;
		Items.EndEdit.Enabled                              = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenSimpleQuestionsForm(CurrentData)
	
	SimpleQuestion = New Structure;
	SimpleQuestion.Insert("TreeRowType", CurrentData.RowType);
	SimpleQuestion.Insert("ElementaryQuestion", CurrentData.ElementaryQuestion);
	SimpleQuestion.Insert("IsRequired", CurrentData.IsRequired);
	SimpleQuestion.Insert("QuestionType", CurrentData.QuestionType);
	SimpleQuestion.Insert("Wording", CurrentData.Wording);
	SimpleQuestion.Insert("CloseOnChoice", True);
	SimpleQuestion.Insert("CloseOnOwnerClose", True);
	SimpleQuestion.Insert("ReadOnly", False);
	SimpleQuestion.Insert("Notes", CurrentData.Notes);
	SimpleQuestion.Insert("IsNewLine", CurrentData.IsNewLine);
	SimpleQuestion.Insert("ToolTip", CurrentData.ToolTip);
	SimpleQuestion.Insert("HintPlacement", CurrentData.HintPlacement);
	SimpleQuestion.Insert("ShouldUseRefusalToAnswer", CurrentData.ShouldUseRefusalToAnswer);
	SimpleQuestion.Insert("RefusalToAnswerText", CurrentData.RefusalToAnswerText);
	
	OpenForm("Catalog.QuestionnaireTemplates.Form.BasicQuestionsForm", SimpleQuestion, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenComplexQuestionsWizardForm(CurrentData)
	
	ComplexQuestion = New Structure;
	ComplexQuestion.Insert("ComplexQuestionComposition", CurrentData.ComplexQuestionComposition);
	ComplexQuestion.Insert("Wording" ,CurrentData.Wording);
	ComplexQuestion.Insert("ToolTip", CurrentData.ToolTip);
	ComplexQuestion.Insert("HintPlacement", CurrentData.HintPlacement);
	ComplexQuestion.Insert("IsNewLine",             CurrentData.IsNewLine);
	
	OpenForm("Catalog.QuestionnaireTemplates.Form.ComplexQuestionsWizardForm", ComplexQuestion, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenTabularQuestionsWizardForm(CurrentData)
	
	TabularQuestion = New Structure;
	TabularQuestion.Insert("TabularQuestionType",       CurrentData.TabularQuestionType);
	TabularQuestion.Insert("TableQuestionComposition",    CurrentData.TableQuestionComposition);
	TabularQuestion.Insert("PredefinedAnswers",     CurrentData.PredefinedAnswers);
	TabularQuestion.Insert("Wording",               CurrentData.Wording);
	TabularQuestion.Insert("ToolTip",                  CurrentData.ToolTip);
	TabularQuestion.Insert("HintPlacement", CurrentData.HintPlacement);
	TabularQuestion.Insert("IsNewLine",             CurrentData.IsNewLine);
	
	OpenForm("Catalog.QuestionnaireTemplates.Form.TableQuestionsWizardForm", TabularQuestion, ThisObject);
	
EndProcedure

&AtClient
Procedure DragTreeItem(AssignmentRow, RowDrag, UseAssignmentRowParent = False,DeleteAfterAdd = True);
	
	If UseAssignmentRowParent Then
		NewRow = AssignmentRow.GetParent().GetItems().Add();
	Else
		NewRow = AssignmentRow.GetItems().Add();
	EndIf;
	
	FillPropertyValues(NewRow,RowDrag,,
		"TableQuestionComposition,PredefinedAnswers, ComplexQuestionComposition, NumericalQuestionHintsRange");
	If RowDrag.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular") Then
		CommonClientServer.SupplementTable(RowDrag.TableQuestionComposition,NewRow.TableQuestionComposition);
		CommonClientServer.SupplementTable(RowDrag.PredefinedAnswers,NewRow.PredefinedAnswers);
	EndIf;
	
	If RowDrag.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex") Then
		CommonClientServer.SupplementTable(RowDrag.ComplexQuestionComposition,NewRow.ComplexQuestionComposition);
	EndIf;
	
	For Each Item In RowDrag.GetItems() Do
		DragTreeItem(NewRow, Item, False, False);
	EndDo;
	
	If DeleteAfterAdd Then
		RowDrag.GetParent().GetItems().Delete(RowDrag);
	EndIf;
	
	If UseAssignmentRowParent Then
		Items.QuestionnaireTreeForm.Expand(AssignmentRow.GetParent().GetID(), False);
	Else	
		Items.QuestionnaireTreeForm.Expand(AssignmentRow.GetID(), False);
	EndIf;
	
EndProcedure

&AtClient
Function TheseAreSubordinateElements(ParentElementOfTree, TreeItem)
	ParentItem = TreeItem;
	While ParentItem <> Undefined Do
		If ParentElementOfTree = ParentItem Then
			Return True;
		EndIf;
		ParentItem = ParentItem.GetParent();
	EndDo;
	Return False;
EndFunction

&AtClient
Procedure SelectAddedItemTypeOnCompletion(SelectedElement, AdditionalParameters) Export
	
	If Not SelectedElement = Undefined Then
		
		If SelectedElement.Value = "Section" Then
			
			AddSection(Commands.AddSection);
			
		ElsIf SelectedElement.Value = "Basic" Then
			
			AddSimpleQuestion(Commands.AddSimpleQuestion)
			
		ElsIf SelectedElement.Value = "Complex" Then
			
			AddComplexQuestion(Commands.AddSimpleQuestion)
			
		ElsIf SelectedElement.Value = "Conditional" Then
			
			AddQuestionWithCondition(Commands.AddQuestionWithCondition)
			
		ElsIf SelectedElement.Value = "Tabular" Then
			
			AddTabularQuestion(Commands.AddTabularQuestion);
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure PromptForWriteRequiredAfterCompletion(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
			Write();
	EndIf;
	
	OpenQuestionnaireWizardFormBySections();
	
EndProcedure

&AtClient
Procedure OpenQuestionnaireWizardFormBySections()

	ParametersStructure1 = New Structure;
	ParametersStructure1.Insert("QuestionnaireTemplate",Object.Ref);
	OpenForm("CommonForm.QuestionnaireBySectionWizard",ParametersStructure1,ThisObject);

EndProcedure 

&AtClient
Procedure NoteEditOnClose(ReturnText, AdditionalParameters) Export
	
	CurrentData = Items.QuestionnaireTreeForm.CurrentData;
	If CurrentData <> Undefined Then
		If CurrentData.Notes <> ReturnText Then
			CurrentData.Notes = ReturnText;
			CurrentData.HasNotes = Not IsBlankString(CurrentData.Notes);
			Modified = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function WriteAtServerExecutedSuccessfully()

	If Not CheckFilling() Then
		Return False;
	Else
		Write();
		Return True;
	EndIf;

EndFunction

&AtClient
Function WriteIfNewExecutedSuccessfully()

	If Object.Ref.IsEmpty() Then
		
		ClearMessages();
		Return WriteAtServerExecutedSuccessfully();
		
	Else
		
		Return True;
		
	EndIf;

EndFunction

#EndRegion
