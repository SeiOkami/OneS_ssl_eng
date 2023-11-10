///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

// 
//   
//    
//    
//

#Region EventHandlersForm

&AtClient
Procedure OnOpen(Cancel)

	AvailabilityControl();
	SetHelpTexts();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each MetadataItem In Metadata.Enums.TabularQuestionTypes.EnumValues Do
		Items.TabularQuestionType.ChoiceList.Add(Enums.TabularQuestionTypes[MetadataItem.Name],MetadataItem.Synonym);
	EndDo;
		
	ProcessOwnerFormParameters();
	
	If Parameters.TabularQuestionType = Enums.TabularQuestionTypes.EmptyRef() Then
		Items.Pages.CurrentPage = Items.TableQuestionTypePage;
	Else
		GenerateResultingTable();
		Items.Pages.CurrentPage = Items.ResultTablePage;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not ClosingInProgress And IsNewLine Then
		Notify("CancelEnterNewQuestionnaireTemplateLine");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TabularQuestionTypeOnChange(Item)
	
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure QuestionsQuestionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	AttributesQuestion = QuestionAttributes(ValueSelected);
	If AttributesQuestion.IsFolder Then
		Return;
	EndIf;
	
	CurItem = Questions.FindByID(Items.Questions.CurrentRow);
	CurItem.ElementaryQuestion = ValueSelected;
	
	CurItem.Presentation = AttributesQuestion.Presentation;
	CurItem.Wording  = AttributesQuestion.Wording;
	CurItem.ReplyType     = AttributesQuestion.ReplyType;
	
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	NewRow = AddAnswerInteractively(Item,Copy,0);
	ProcessAnswersPickingItemAfterAdd(Item,NewRow);
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInColumnsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	NewRow = AddAnswerInteractively(Item,Copy,0);
	ProcessAnswersPickingItemAfterAdd(Item,NewRow);
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInRowsAndColumnsResponse1StartChoice(Item, ChoiceData, StandardProcessing)
	
	ListsChoiceStart(Item,StandardProcessing, QuestionValueType(QuestionForColumns));
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsResponse1StartChoice(Item, ChoiceData, StandardProcessing)
	
	ListsChoiceStart(Item,StandardProcessing, QuestionValueType(QuestionForRows));
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsAndColumnsResponse1StartChoice(Item, ChoiceData, StandardProcessing)
	
	ListsChoiceStart(Item,StandardProcessing, QuestionValueType(QuestionForRows));
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInColumnsResponse1StartChoice(Item, ChoiceData, StandardProcessing)
	
	ListsChoiceStart(Item,StandardProcessing, QuestionValueType(QuestionForColumns));
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInRowsAndColumnsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	NewRow = AddAnswerInteractively(Item,Copy,1);
	ProcessAnswersPickingItemAfterAdd(Item,NewRow);
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsAndColumnsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	NewRow = AddAnswerInteractively(Item,Copy,0);
	ProcessAnswersPickingItemAfterAdd(Item,NewRow);
	
EndProcedure

&AtClient
Procedure QuestionsOnChange(Item)
	
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInRowsAndColumnsOnChange(Item)
	
	OnChangeAnswers(Item);
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsAndColumnsOnChange(Item)
	
	OnChangeAnswers(Item);
	
EndProcedure

&AtClient
Procedure AnswersColumnsAnswersInColumnsOnChange(Item)
	
	OnChangeAnswers(Item);
	
EndProcedure

&AtClient
Procedure AnswersRowsAnswersInRowsOnChange(Item)
	
	OnChangeAnswers(Item);
	
EndProcedure

&AtClient
Procedure WordingOnChange(Item)
	
	If Items.Pages.CurrentPage = Items.ResultTablePage Then
		
		Items.NextPageButton.Enabled 	= ValueIsFilled(Wording);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextPage(Command)
	
	CurrentPage = Items.Pages.CurrentPage;
	
	If CurrentPage = Items.TableQuestionTypePage Then
		
		Items.Pages.CurrentPage = Items.QuestionsPage;
		
	ElsIf (CurrentPage = Items.QuestionsPage) And (TabularQuestionType <> PredefinedValue("Enum.TabularQuestionTypes.Composite")) Then
		
		SetAnswersPage();
		
	ElsIf CurrentPage = Items.ResultTablePage Then
		
		EndEditAndClose();
		
	Else
		
		GenerateResultingTable();
		Items.Pages.CurrentPage = Items.ResultTablePage;
		
	EndIf;
	
	AvailabilityControl();
	SetHelpTexts();
	
EndProcedure

&AtClient
Procedure PreviousPage(Command)

	If Items.Pages.CurrentPage = Items.ResultTablePage Then
		
		If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.Composite") Then
			Items.Pages.CurrentPage = Items.QuestionsPage;
		Else
			SetAnswersPage();
		EndIf;
		
		Items.NextPageButton.Title = NStr("en = 'Next';") + ">";
		
	ElsIf Items.Pages.CurrentPage = Items.QuestionsPage Then
		
		Items.Pages.CurrentPage = Items.TableQuestionTypePage;
		
	Else 
		
		Items.Pages.CurrentPage = Items.QuestionsPage;
		
	EndIf;
	
	AvailabilityControl();
	SetHelpTexts();
	
EndProcedure

&AtClient
Procedure FillAnswersOptionsAnswersInRows(Command)
	
	ClearFillAnswersOptions(QuestionForRows);
	SetFilters();
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure FillAnswersOptionsAnswersInColumns(Command)
	
	ClearFillAnswersOptions(QuestionForColumns);
	SetFilters();
	AvailabilityControl();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function QuestionValueType(DoQueryBox)
	Return Common.ObjectAttributeValue(DoQueryBox,"ValueType");
EndFunction

&AtClient
Procedure SetHelpTexts()
	
	CurrentPage = Items.Pages.CurrentPage;
	
	If CurrentPage = Items.ResultTablePage Then
		InformationHeader                 = NStr("en = 'Result table:';");
		InformationFooter                = NStr("en = 'Click Finish to finish editing.';");
		Items.NextPageButton.Title = NStr("en = 'Finish';");
	Else
		Items.NextPageButton.Title = NStr("en = 'Next>>';");
		If CurrentPage = Items.QuestionsPage Then
			If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.Composite") Then
				InformationHeader  = NStr("en = 'Pick questions. Specify at least one question:';");
				InformationFooter = NStr("en = 'Click Next to view the resulting table.';");
			ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
				InformationHeader  =NStr("en = 'Pick questions. Specify three questions:';");
				InformationFooter =NStr("en = 'Click Next to pick predefined responses.';");
			Else
				InformationHeader   =NStr("en = 'Pick questions. Specify at least two questions:';");
				InformationFooter  =NStr("en = 'Click Next to pick predefined responses.';");
			EndIf;
		ElsIf CurrentPage = Items.TableQuestionTypePage Then
			InformationHeader       = NStr("en = 'Select a question chart type:';");
			InformationFooter      = NStr("en = 'Click Next to pick questions:';");
		Else
			InformationHeader  = NStr("en = 'Pick predefined responses:';");
			InformationFooter = NStr("en = 'Click Next to view the resulting table:';");
		EndIf;
	EndIf;
	
	Items.MainPagesGroup.Title = InformationHeader;
	
EndProcedure

&AtClient
Procedure AvailabilityControl()

	CurrentPage = Items.Pages.CurrentPage;
	
	Items.BackButton.Enabled 	= (Not CurrentPage = Items.TableQuestionTypePage);
		
	If CurrentPage = Items.PredefinedAnswersInRowsAndColumnsPage Then
		 		
		If Not AllAnswersFilled() Then
			Items.NextPageButton.Enabled = False;
			Return;
		EndIf;			
		
		Items.PopulateAnswerOptionsColumnsAnswersInRowsAndColumns.Enabled = (Questions[1].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") 
		                                                                             Or Questions[1].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf"));
		
		Items.PopulateRowsAnswerOptionsAnswersInRowsAndColumns.Enabled    = (Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") 
		                                                                             Or Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf"));
		
		If Replies.FindRows(New Structure("ElementaryQuestion",QuestionForColumns)).Count() > 0 
			And Replies.FindRows(New Structure("ElementaryQuestion",QuestionForRows)).Count() > 0  Then
			
			Items.NextPageButton.Enabled = True;
			
		Else
			
			Items.NextPageButton.Enabled = False;
			
		EndIf;	
		
	ElsIf CurrentPage = Items.PredefinedAnswersInRowsPage Then
		
		Items.PopulateAnswerOptionsAnswersRows.Enabled = (Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") 
		                                                             Or Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf"));
		
		If Not AllAnswersFilled() Then
			Items.NextPageButton.Enabled = False;
			Return;
		EndIf;
		
		Items.NextPageButton.Enabled = (Replies.FindRows(New Structure("ElementaryQuestion",QuestionForRows)).Count() > 0);
		
	ElsIf CurrentPage = Items.PredefinedAnswersInColumnsPage Then
		
		Items.PopulateAnswerOptionsAnswersInColumns.Enabled = (Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") 
		                                                             Or Questions[0].ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf"));
		
		If Not AllAnswersFilled() Then
			Items.NextPageButton.Enabled = False;
			Return;
		EndIf;
		
		Items.NextPageButton.Enabled = (Replies.FindRows(New Structure("ElementaryQuestion",QuestionForColumns)).Count() > 0);
	
	ElsIf CurrentPage = Items.TableQuestionTypePage Then
				
		Items.NextPageButton.Enabled = TabularQuestionType <> PredefinedValue("Enum.TabularQuestionTypes.EmptyRef");
		If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.Composite") Then
			Items.TableQuestionTypePagesPictures.CurrentPage = Items.CompositeQuestionPicturePage;
		ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRows") Then
			Items.TableQuestionTypePagesPictures.CurrentPage = Items.AnswersInRowsPicturePage;
		ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInColumns") Then
			Items.TableQuestionTypePagesPictures.CurrentPage = Items.AnswersInColumnsPicturePage;
		ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
			Items.TableQuestionTypePagesPictures.CurrentPage = Items.AnswersInRowsAndColumnsPicturePage;
		Else
			Items.TableQuestionTypePagesPictures.CurrentPage = Items.BlankPicturePage;
		EndIf;
		
	ElsIf CurrentPage = Items.QuestionsPage Then
		
		If Questions.FindRows(New Structure("ElementaryQuestion",PredefinedValue("ChartOfCharacteristicTypes.QuestionsForSurvey.EmptyRef"))).Count() <> 0  Then
			Items.NextPageButton.Enabled = False;
			Return;
		EndIf;
		
		If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.Composite") Then
			Items.NextPageButton.Enabled = (Questions.Count() > 0); 
		ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRows")
			Or TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInColumns") Then
			Items.NextPageButton.Enabled = (Questions.Count() > 1);
		ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
			Items.NextPageButton.Enabled = (Questions.Count() = 3);
		EndIf;
		
	ElsIf CurrentPage = Items.ResultTablePage Then
		Items.NextPageButton.Enabled =  ValueIsFilled(Wording);
	EndIf;
	
EndProcedure

// Returns:
//   Boolean - True if all answers are filled in.
//
&AtClient
Function AllAnswersFilled()

	For Each Response In Replies Do
	
		If Not ValueIsFilled(Response.Response) Then
			Return  False;
		EndIf;
	
	EndDo;
	
	Return True;

EndFunction

&AtClient
Procedure ListsChoiceStart(Item,StandardProcessing,DetailsOfAvailableTypes)
	
	If TypeOf(ThisObject[Item.TypeLink.DataPath]) = Type("ChartOfCharacteristicTypesRef.QuestionsForSurvey") Then
		
		If DetailsOfAvailableTypes.ContainsType(Type("CatalogRef.QuestionnaireAnswersOptions")) And (DetailsOfAvailableTypes.Types().Count() = 1 ) Then
			
			StandardProcessing = False;
			
			FilterParameters = New Structure;
			FilterParameters.Insert("Owner", ThisObject[Item.TypeLink.DataPath]);
			FilterParameters.Insert("DeletionMark", False);
			OpenForm("Catalog.QuestionnaireAnswersOptions.ChoiceForm", New Structure("Filter",FilterParameters),Item);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure clears up those answers whose parent question is not included in the QuestionsArray passed as a parameter.
// 
//
&AtClient
Procedure ClearAnswersListIfNecessary(QuestionsArray)
	
	AnswersToDelete = New Array;
	
	For Each Response In Replies Do
		
		If QuestionsArray.Find(Response.ElementaryQuestion) = Undefined Then
			 AnswersToDelete.Add(Response);
		EndIf;
		
	EndDo;
	
	For Each AnswerToDelete In AnswersToDelete Do
		Replies.Delete(AnswerToDelete);
	EndDo;
	
EndProcedure 

&AtClient
Procedure SetAnswersPage()
	
	ArrayOfQuestionsToAnswer = New Array;
	
	If TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
		
		Items.Pages.CurrentPage = Items.PredefinedAnswersInRowsAndColumnsPage;
		QuestionForRowsPresentation      = Questions[0].Wording;
		QuestionForRows                    = Questions[0].ElementaryQuestion;
		QuestionForColumnsPresentation    = Questions[1].Wording;
		QuestionForColumns                  = Questions[1].ElementaryQuestion;
		
		ArrayOfQuestionsToAnswer.Add(QuestionForRows);
		ArrayOfQuestionsToAnswer.Add(QuestionForColumns);
		
	ElsIf TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRows") Then 
		
		Items.Pages.CurrentPage = Items.PredefinedAnswersInRowsPage;
		QuestionForRowsPresentation      = Questions[0].Wording;
		QuestionForRows                    = Questions[0].ElementaryQuestion;
		
		ArrayOfQuestionsToAnswer.Add(QuestionForRows);
		
	ElsIf TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInColumns") Then 
		
		Items.Pages.CurrentPage = Items.PredefinedAnswersInColumnsPage;
		QuestionForColumnsPresentation    = Questions[0].Wording;
		QuestionForColumns                  = Questions[0].ElementaryQuestion;
		
		ArrayOfQuestionsToAnswer.Add(QuestionForColumns);
		
	EndIf;
	
	ClearAnswersListIfNecessary(ArrayOfQuestionsToAnswer);
	SetFilters();
	
EndProcedure

&AtServer
Procedure GenerateResultingTable()
	
	Surveys.UpdateTabularQuestionPreview(FormAttributeToValue("Questions"),Replies,TabularQuestionType,ThisObject,"ResultingTable","");
	Items.NextPageButton.Title = NStr("en = 'Finish';");
	
EndProcedure

&AtClient
Function GenerateParametersStructureToPassToOwner()

	ParametersStructure = New Structure;
	ParametersStructure.Insert("TabularQuestionType",TabularQuestionType);
	
	QuestionsToReturn = New Array;
	For Each TableRow In Questions Do
		QuestionsToReturn.Add(TableRow.ElementaryQuestion);
	EndDo;
	ParametersStructure.Insert("Questions",QuestionsToReturn);
	ParametersStructure.Insert("Replies" ,Replies);
	ParametersStructure.Insert("Wording",Wording);
	ParametersStructure.Insert("ToolTip",ToolTip);
	ParametersStructure.Insert("HintPlacement",HintPlacement);

	Return ParametersStructure;

EndFunction

&AtServer
Procedure ProcessOwnerFormParameters()
	
	Wording               = Parameters.Wording;
	ToolTip                  = Parameters.ToolTip;
	HintPlacement = Parameters.HintPlacement;
	IsNewLine             = Parameters.IsNewLine;
	
	If Parameters.TabularQuestionType.IsEmpty() Then
		TabularQuestionType = Enums.TabularQuestionTypes.Composite;
		Return;
	EndIf;
	
	TabularQuestionType = Parameters.TabularQuestionType;
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	Questions.ElementaryQuestion,
	|	Questions.LineNumber
	|INTO ElementaryQuestions
	|FROM
	|	&Questions AS Questions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ElementaryQuestions.ElementaryQuestion AS ElementaryQuestion,
	|	ISNULL(QuestionsForSurvey.Presentation, """""""") AS Presentation,
	|	ISNULL(QuestionsForSurvey.Wording, """""""") AS Wording,
	|	ISNULL(QuestionsForSurvey.ReplyType, """") AS ReplyType
	|FROM
	|	ElementaryQuestions AS ElementaryQuestions
	|		LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON ElementaryQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|
	|ORDER BY
	|	ElementaryQuestions.LineNumber";
	
	Query.SetParameter("Questions", Parameters.TableQuestionComposition.Unload());
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then;
		Selection = Result.Select();
		While Selection.Next() Do
			NewRow = Questions.Add();
			FillPropertyValues(NewRow,Selection);
		EndDo;
	EndIf;
	
	CommonClientServer.SupplementTable(Parameters.PredefinedAnswers, Replies);
	
EndProcedure

&AtClient
Procedure SetFilters()
	
	If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
		
		Items.AnswersColumnsAnswersInRowsAndColumns.RowFilter = New FixedStructure("ElementaryQuestion",QuestionForColumns);
		Items.AnswersRowsAnswersInRowsAndColumns.RowFilter  = New FixedStructure("ElementaryQuestion",QuestionForRows);
		SetLinksOfAnswersAndQuestionsChoiceParameters = True;
		
	ElsIf TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRows") Then
		
		Items.AnswersRowsAnswersInRows.RowFilter = New FixedStructure("ElementaryQuestion",QuestionForRows);
		SetLinksOfAnswersAndQuestionsChoiceParameters = True;
		
	ElsIf TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInColumns") Then
		
		Items.AnswersColumnsAnswersInColumns.RowFilter = New FixedStructure("ElementaryQuestion",QuestionForColumns);
		SetLinksOfAnswersAndQuestionsChoiceParameters = True;
	Else
		SetLinksOfAnswersAndQuestionsChoiceParameters = False;
	EndIf;
	
	If SetLinksOfAnswersAndQuestionsChoiceParameters Then
		AttachIdleHandler("SetLinksOfAnswersAndQuestionsChoiceParameters", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetLinksOfAnswersAndQuestionsChoiceParameters()
	SetParametersRelationsForAnswersAndQuestionsChoiceAtServer();
EndProcedure

&AtServer
Procedure SetParametersRelationsForAnswersAndQuestionsChoiceAtServer()

	If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns") Then
		
		SetLinkOfAnswersAndQuestionsChoiceParameter("AnswersColumnsAnswersInRowsAndColumnsResponse", "QuestionForColumns");
		SetLinkOfAnswersAndQuestionsChoiceParameter("AnswersRowsAnswersInRowsAndColumnsResponse", "QuestionForRows");
		
	ElsIf TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInRows") Then
		
		SetLinkOfAnswersAndQuestionsChoiceParameter("AnswersRowsAnswersInRowsResponse", "QuestionForRows");
		
	ElsIf TabularQuestionType =  PredefinedValue("Enum.TabularQuestionTypes.PredefinedAnswersInColumns") Then
		
		SetLinkOfAnswersAndQuestionsChoiceParameter("AnswersColumnsAnswersInColumnsResponse", "QuestionForColumns");
		
	EndIf;

EndProcedure

&AtServer
Procedure SetLinkOfAnswersAndQuestionsChoiceParameter(AnswerFieldName, QuestionAttributeName)

	FoundQuestions = Questions.FindRows(New Structure("ElementaryQuestion", ThisObject[QuestionAttributeName]));
	If FoundQuestions.Count() > 0 Then
		FoundQuestion = FoundQuestions[0];
		If FoundQuestion.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf
			Or FoundQuestion.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
			ChoiceParametersArray = New Array;
			ChoiceParameterLink = New ChoiceParameterLink("Filter.Owner", QuestionAttributeName, LinkedValueChangeMode.Clear);
			ChoiceParametersArray.Add(ChoiceParameterLink);
			ChoiceParameterLinks = New FixedArray(ChoiceParametersArray);
			Items[AnswerFieldName].ChoiceParameterLinks = ChoiceParameterLinks;
		Else
			Items[AnswerFieldName].ChoiceParameterLinks = New FixedArray(New Array);
		EndIf;
	Else
		Items[AnswerFieldName].ChoiceParameterLinks = New FixedArray(New Array);
	EndIf;

EndProcedure

// Parameters:
//   Item - FormTable -
//
&AtClient
Procedure OnChangeAnswers(Item)
	
	AvailabilityControl();
	SetFilters();
	Item.Refresh();
	
EndProcedure

&AtClient
Procedure ProcessAnswersPickingItemAfterAdd(Item,AddedRow)

	SetFilters();
	Item.Refresh();
	AvailabilityControl();
	Item.CurrentRow = AddedRow.GetID();
	Item.ChangeRow();

EndProcedure

&AtClient
Function AddAnswerInteractively(Item,Copy,SupportQuestionNumber)

	If Copy Then
		
		NewRow = Replies.Add();
		FillPropertyValues(NewRow,Item.CurrentData);
		
	Else	
		
		If Questions.Count() >= SupportQuestionNumber+1 Then
			
			NewRow = Replies.Add();
			NewRow.ElementaryQuestion = Questions[SupportQuestionNumber].ElementaryQuestion;
			
		Else
			Return Undefined;
		EndIf;
		
	EndIf;
	
	Return NewRow;
	
EndFunction

&AtClient
Procedure EndEditAndClose()
	
	If TabularQuestionType = PredefinedValue("Enum.TabularQuestionTypes.Composite") Then
		Replies.Clear();
	EndIf;
	
	ClosingInProgress = True;
	Notify("EndEditTableQuestionParameters",GenerateParametersStructureToPassToOwner());
	Close();
	
EndProcedure

// Parameters:
//  ElementaryQuestion - ChartOfCharacteristicTypesRef.QuestionsForSurvey
//
&AtServer
Procedure ClearFillAnswersOptions(ElementaryQuestion)
	
	If Not ValueIsFilled(ElementaryQuestion) Then
		Return;	
	EndIf;
	
	FoundRows = Replies.FindRows(New Structure("ElementaryQuestion", ElementaryQuestion));
	For Each FoundRow In FoundRows Do
		Replies.Delete(Replies.IndexOf(FoundRow));
	EndDo;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	QuestionnaireAnswersOptions.Ref AS Response
	|FROM
	|	Catalog.QuestionnaireAnswersOptions AS QuestionnaireAnswersOptions
	|WHERE
	|	QuestionnaireAnswersOptions.Owner = &ElementaryQuestion
	|	AND (NOT QuestionnaireAnswersOptions.DeletionMark)
	|
	|ORDER BY
	|	QuestionnaireAnswersOptions.AddlOrderingAttribute";
	
	Query.SetParameter("ElementaryQuestion",ElementaryQuestion);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		While Selection.Next() Do
			NewRow = Replies.Add();
			NewRow.ElementaryQuestion = ElementaryQuestion;
			NewRow.Response              = Selection.Response;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function QuestionAttributes(DoQueryBox)
	
	Return Common.ObjectAttributesValues(DoQueryBox,"Presentation,Wording,IsFolder,ReplyType");
	
EndFunction

#EndRegion
