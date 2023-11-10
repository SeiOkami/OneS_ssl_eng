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
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	CommonClientServer.SetDynamicListFilterItem(AnswersOptions,"Owner", Object.Ref, DataCompositionComparisonType.Equal, ,True);
	
	SetAnswerType();
	
	If ReplyType = Enums.TypesOfAnswersToQuestion.String Then
		StringLength = Object.Length;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.RadioButtonType = Enums.RadioButtonTypesInQuestionnaires.RadioButton;
		Object.CheckBoxType = Enums.CheckBoxKindsInQuestionnaires.InputField;
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	PlacementParameters.Sources = New TypeDescription("ChartOfCharacteristicTypesRef.QuestionsForSurvey");
	PlacementParameters.CommandBar = Items.FormCommandBar;
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	
	PlacementParameters = AttachableCommands.PlacementParameters();
	PlacementParameters.Sources = New TypeDescription("CatalogRef.QuestionnaireAnswersOptions");
	PlacementParameters.CommandBar = Items.TableAnswersOptionsCommandBar;
	PlacementParameters.GroupsPrefix = "QuestionnaireAnswersOptions";
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
	DescriptionBeforeEditing = Object.Description;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Ref.IsEmpty() Then
		OnChangeAnswerType();
	EndIf;
	VisibilityManagement();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Number") Then
		
		If Object.MinValue > Object.MaxValue Then
			CommonClient.MessageToUser(
				NStr("en = 'The minimum allowed value cannot be greater than the maximum allowed value.';"),,
				"Object.MinValue");
			Cancel = True;
		EndIf;
		
		If Object.ShouldUseMinValue And Object.ShouldUseMaxValue Then
			If Object.MinValue = Object.MaxValue Then
				CommonClient.MessageToUser(
					NStr("en = 'The minimum allowed value cannot be equal to the maximum allowed value.';"),,
					"Object.MinValue");
				Cancel = True;
			EndIf;
		EndIf;
		
		If Object.ShouldShowRangeSlider Then
			If Object.RangeSliderStep > Object.MaxValue - Object.MinValue Then
			CommonClient.MessageToUser(
				NStr("en = 'A slider increment cannot be greater than the difference between the maximum and minimum values.';"),,
				"Object.RangeSliderStep");
			Cancel = True;
			EndIf;
		EndIf;
		
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.String") Then	
		
		Object.Length = StringLength;
		If StringLength = 0 Then
			CommonClient.MessageToUser(NStr("en = 'The string length is not specified.';"),,"StringLength");
			Cancel = True;
		EndIf;
		
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Text") Then
		
		Object.Length = 1024;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	AnswersOptionsTableAvailability(ThisObject);
	CommonClientServer.SetDynamicListFilterItem(AnswersOptions,
	                                                                        "Owner",
	                                                                        Object.Ref,
	                                                                        DataCompositionComparisonType.Equal,
	                                                                        ,
	                                                                        True);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
	SetHintRangePresentationForNumericalQuestion();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReplyTypeOnChange(Item)
	
	OnChangeAnswerType();
	
EndProcedure

&AtClient
Procedure TableAnswersOptionsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	OpenQuestionnaireAnswersQuestionsCatalogItemForm(Item,True);
	
EndProcedure

&AtClient
Procedure CommentRequiredOnChange(Item)
	
	CommentNoteRequiredAvailable();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	If Object.Wording = DescriptionBeforeEditing Then
	
		Object.Wording = Object.Description;
	
	EndIf;
	
	DescriptionBeforeEditing = Object.Description;
	
EndProcedure

&AtClient
Procedure TableAnswersOptionsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	OpenQuestionnaireAnswersQuestionsCatalogItemForm(Item,False);
	
EndProcedure

&AtClient
Procedure TableAnswersOptionsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenQuestionnaireAnswersQuestionsCatalogItemForm(Item,False);
	
EndProcedure

&AtClient
Procedure LengthOnChange(Item)
	
	SetPrecisionBasedOnNumberLength();
	
	ClearMarkIncomplete();
	
EndProcedure

&AtClient
Procedure AccuracyOnChange(Item)
	
	SetPrecisionBasedOnNumberLength();
	
EndProcedure

&AtClient
Procedure PresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClosingNotification1 = New NotifyDescription("WordingEditOnClose", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(ClosingNotification1, Item.EditText, NStr("en = 'Wording';"));
	
EndProcedure

&AtClient
Procedure ShouldUseMinValueOnChange(Item) 
	
	Items.MinValue.Enabled = Object.ShouldUseMinValue;
	
	SetRangeSliderSetupAvailability();
	
EndProcedure 

&AtClient
Procedure ShouldUseMaxValueOnChange(Item)
	
	Items.MaxValue.Enabled = Object.ShouldUseMaxValue;
	
	SetRangeSliderSetupAvailability();
	SetDefaultRangeSliderStep();
	
EndProcedure

&AtClient
Procedure MinValueOnChange(Item)
	
	SetDefaultRangeSliderStep();
	
EndProcedure

&AtClient
Procedure MaxValueOnChange(Item)
	
	SetDefaultRangeSliderStep();
	
EndProcedure

&AtClient
Procedure ShouldShowRangeSliderOnChange(Item)
	
	Items.RangeSliderStep.Enabled = Object.ShouldShowRangeSlider;
	
EndProcedure

&AtClient
Procedure RangeSliderIncrementStepOnChange(Item)
	
	SetDefaultRangeSliderStep();
	
EndProcedure

&AtClient
Procedure ShouldShowHintForNumericalQuestionsOnChange(Item)
	
	SetHintsRangeAvailability();

	If Object.ShouldShowHintForNumericalQuestions And Object.NumericalQuestionHintsRange.Count() = 0 Then
		NewRow = Object.NumericalQuestionHintsRange.Add();
		NewRow.ValueUpTo = NumericalQuestionHintsRangeCapValue();
	EndIf;
	
	SetHintRangePresentationForNumericalQuestion();
	
EndProcedure

&AtClient
Procedure HintsRangeOnStartEdit(Item, NewRow, Copy)
	
	HintsRangePreviousValue = Item.CurrentData.ValueUpTo;
	
	If Item.CurrentItem = Items.HintsRangeValueUpTo Then
		Item.CurrentData.DisableConditionalAppearance = True
	EndIf;
	
EndProcedure

&AtClient
Procedure HintsRangeBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.DisableConditionalAppearance = False;
	
	If CancelEdit Then
		If ReturnValueToRange Then
			CurrentData.ValueUpTo = HintsRangePreviousValue;
			ReturnValueToRange = False;
		EndIf;
		Return;
	EndIf;
	
	If Not NewRow And HintsRangePreviousValue = CurrentData.ValueUpTo Then
		Return;
	EndIf;
		
	TableOfRanges = Object.NumericalQuestionHintsRange;
	
	If Not NewRow And HintsRangePreviousValue = CurrentData.ValueUpTo Then
		Return;
	EndIf;
	
	CheckIfHintsRangeFilled(TableOfRanges, Cancel);
	
	If Not Cancel Then
		SetHintRangePosition(TableOfRanges, CurrentData, CurrentData.ValueUpTo);
		SetHintRangePresentationForNumericalQuestion();
	Else
		ReturnValueToRange = True;
		
		ClearMessages();
		If NewRow Then
			NameOfFormField = StrTemplate("Object.NumericalQuestionHintsRange[%1]",
				TableOfRanges.IndexOf(CurrentData));
		Else
			NameOfFormField = StrTemplate("Object.NumericalQuestionHintsRange[%1].ValueUpTo",
				TableOfRanges.IndexOf(CurrentData));
		EndIf;
		CommonClient.MessageToUser(
			NStr("en = 'This value already exists in a hint range.';"),, NameOfFormField);
	EndIf;
	
EndProcedure

&AtClient
Procedure HintsRangeBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.ValueUpTo = NumericalQuestionHintsRangeCapValue() Then
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure HintsRangeAfterDeleteRow(Item)
	SetHintRangePresentationForNumericalQuestion();
EndProcedure

#EndRegion

#Region FormCommandHandlers

// StandardSubsystems.AttachableCommands
// 
// Parameters:
//   Command - FormCommand
// 
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If StrStartsWith(Command.Name, "QuestionnaireAnswersOptions") Then
		AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.TableAnswersOptions);
	Else
		AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If StrStartsWith(ExecutionParameters.CommandNameInForm, "QuestionnaireAnswersOptions") Then
		AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.TableAnswersOptions);
	Else
		AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.TableAnswersOptions);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Length.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Length");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ReplyType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TypesOfAnswersToQuestion.String;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ReplyType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TypesOfAnswersToQuestion.Number;

	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReplyType.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReplyType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.TypesOfAnswersToQuestion.InfobaseValue;

	Item.Appearance.SetParameterValue("MarkIncomplete", True);

	// 

	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	PropertyDecorationItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	PropertyDecorationItem.Value = New DataCompositionField("Object.NumericalQuestionHintsRange.ValuePresentation");
	PropertyDecorationItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Object.NumericalQuestionHintsRange.ValuePresentation");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Object.NumericalQuestionHintsRange.DisableConditionalAppearance");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False ;
	DataFilterItem.Use = True;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("HintsRangeValueUpTo");
	FormattedField.Use = True;
	
	// 
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	PropertyDecorationItem = ConditionalAppearanceItem.Appearance.Items.Find("ReadOnly");
	PropertyDecorationItem.Value = True;
	PropertyDecorationItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Object.NumericalQuestionHintsRange.ValueUpTo");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = NumericalQuestionHintsRangeCapValue();
	DataFilterItem.Use = True;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("HintsRangeValueUpTo");
	FormattedField.Use = True;

EndProcedure

&AtClient
Procedure VisibilityManagement()
	
	CommentPossible = Not (Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") 
	                        Or Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Text"));
	Items.CommentRequired.Enabled  = CommentPossible;
	Items.Comment.Enabled           = CommentPossible;
	If Not CommentPossible Then
		Object.CommentRequired = False;
		Object.CommentNote = "";
	EndIf;
	CommentNoteRequiredAvailable();
	
	If Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.String") Then 
		Items.DependentParameters.CurrentPage = Items.StringPage;
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Number") Then
		Items.DependentParameters.CurrentPage = Items.NumericAttributesPage;
		Items.MinValue.Enabled = Object.ShouldUseMinValue;
		Items.MaxValue.Enabled = Object.ShouldUseMaxValue;
		
		SetRangeSliderSetupAvailability();
		SetHintsRangeAvailability();
		SetHintRangePresentationForNumericalQuestion();
		
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.InfobaseValue") Then
		Items.DependentParameters.CurrentPage = Items.IsEmpty;
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") 
	      Or Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") Then
		Items.DependentParameters.CurrentPage = Items.AnswersOptions; 
		AnswersOptionsTableAvailability(ThisObject);
	Else
		Items.DependentParameters.CurrentPage = Items.IsEmpty;
	EndIf;
	
	If Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") Then
		Items.RadioButtonTypeGroup.CurrentPage = Items.ShowRadioButtonType;
	ElsIf Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Boolean") Then
		Items.RadioButtonTypeGroup.CurrentPage = Items.ShowRadioButtonTypeBooleanTypeGroup;
	Else
		Items.RadioButtonTypeGroup.CurrentPage = Items.HideRadioButtonTypeGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeAnswerType()

	If TypeOf(ReplyType) = Type("EnumRef.TypesOfAnswersToQuestion") Then
		
		Object.ReplyType = ReplyType;
		
	ElsIf TypeOf(ReplyType) = Type("TypeDescription") Then
		
		Object.ReplyType   = PredefinedValue("Enum.TypesOfAnswersToQuestion.InfobaseValue");
		Object.ValueType = ReplyType;
		
	EndIf;
	
	VisibilityManagement();
	
	If Object.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Number") Then
		SetPrecisionBasedOnNumberLength();
	EndIf;

EndProcedure 

&AtClient
Procedure CommentNoteRequiredAvailable()
	
	Items.CommentNote.AutoMarkIncomplete = Object.CommentRequired;
	Items.CommentNote.ReadOnly            = Not Object.CommentRequired;
	
	ClearMarkIncomplete();
	
EndProcedure

&AtClientAtServerNoContext
Procedure AnswersOptionsTableAvailability(Form)
	
	If Form.Object.Ref.IsEmpty() Then
		Form.Items.TableAnswersOptions.ReadOnly  = True;
		Form.AnswersOptionsInfo                       = NStr("en = 'Before you start editing the responses, save the question';");
	Else
		Form.Items.TableAnswersOptions.ReadOnly = False;
		Form.AnswersOptionsInfo                      = NStr("en = 'Response options:';");
	EndIf; 
	
	If Form.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") Then
		Form.Items.OpenEndedQuestion.Visible = False;
	ElsIf Form.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") Then
		Form.Items.OpenEndedQuestion.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenQuestionnaireAnswersQuestionsCatalogItemForm(Item,InsertMode)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Owner",Object.Ref);
	ParametersStructure.Insert("ReplyType",Object.ReplyType);
	
	If Not InsertMode Then
		CurrentData = Items.TableAnswersOptions.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		ParametersStructure.Insert("Key",CurrentData.Ref);
		ParametersStructure.Insert("Description",CurrentData.Description);
	EndIf;
		
	OpenForm("Catalog.QuestionnaireAnswersOptions.ObjectForm", ParametersStructure,Item);
	
EndProcedure

&AtServer
Procedure SetAnswerType()
	
	For Each EnumerationValue In Metadata.Enums.TypesOfAnswersToQuestion.EnumValues Do
		
		If Enums.TypesOfAnswersToQuestion[EnumerationValue.Name] = Enums.TypesOfAnswersToQuestion.InfobaseValue Then 
			
			For Each AvailableType In FormAttributeToValue("Object").Metadata().Type.Types() Do
				
				If AvailableType = Type("String") Or AvailableType = Type("Boolean") Or AvailableType = Type("Number") Or AvailableType = Type("Date") Or AvailableType = Type("CatalogRef.QuestionnaireAnswersOptions") Then
					Continue;
				EndIf;
				
				TypesArray = New Array;
				TypesArray.Add(AvailableType);
				Items.ReplyType.ChoiceList.Add(New TypeDescription(TypesArray));
				
			EndDo;
			
		Else
			Items.ReplyType.ChoiceList.Add(Enums.TypesOfAnswersToQuestion[EnumerationValue.Name]);
		EndIf;
		
	EndDo;
	
	If Object.ReplyType = Enums.TypesOfAnswersToQuestion.InfobaseValue Then
		
		ReplyType = Object.ValueType;
		
	ElsIf Object.ReplyType = Enums.TypesOfAnswersToQuestion.EmptyRef() Then
		
		ReplyType = Items.ReplyType.ChoiceList[0].Value;
		
	Else
		
		ReplyType = Object.ReplyType;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPrecisionBasedOnNumberLength()

	If Object.Length > 15 Then
		Object.Length = 15;
	EndIf;
	
	If Object.Length = 0 Then
		Object.Accuracy = 0;
	ElsIf Object.Length <= Object.Accuracy Then
		Object.Accuracy = Object.Length - 1;
	EndIf;
	
	If Object.Accuracy > 3 Then
		Object.Accuracy = 3;
	EndIf;
	
	If (Object.Length - Object.Accuracy) > 12 Then
		Object.Length = Object.Accuracy + 12;
	EndIf;
	
EndProcedure

&AtClient
Procedure WordingEditOnClose(ReturnText, AdditionalParameters) Export
	
	If Object.Wording <> ReturnText Then
		Object.Wording = ReturnText;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetRangeSliderSetupAvailability()
	
	Items.ShouldShowRangeSlider.Enabled = Object.ShouldUseMinValue
		And Object.ShouldUseMaxValue;
	Items.RangeSliderStep.Enabled = Object.ShouldShowRangeSlider;
	
EndProcedure

&AtClient
Procedure SetDefaultRangeSliderStep()
	
	If Not Object.ShouldShowRangeSlider Then
		Return;
	EndIf;
	
	// 
	SliderLength = (Object.MaxValue - Object.MinValue) / Object.RangeSliderStep;
	If SliderLength <> Int(SliderLength) Then
		Object.RangeSliderStep = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetHintsRangeAvailability()
	
	Items.HintsRange.Enabled = Object.ShouldShowHintForNumericalQuestions;
	
EndProcedure

&AtClientAtServerNoContext
Function NumericalQuestionHintsRangeCapValue()
	Return 9999999999999.99;
EndFunction

&AtClient
Procedure SetHintRangePresentationForNumericalQuestion()
	
	TableOfRanges = Object.NumericalQuestionHintsRange;
	
	For Each CurrentRow In TableOfRanges Do
		CurrentIndex = Object.NumericalQuestionHintsRange.IndexOf(CurrentRow);
		If CurrentRow.ValueUpTo = NumericalQuestionHintsRangeCapValue() Then
			If CurrentIndex = 0 Then
				ValuePresentation = NStr("en = 'any value';");
				CurrentRow.ValuePresentation = ValuePresentation;
			Else
				PreviousString = TableOfRanges[CurrentIndex - 1];
				If PreviousString.ValueUpTo = NumericalQuestionHintsRangeCapValue() Then
					CurrentRow.ValuePresentation = PreviousString.ValuePresentation;
				Else
					StringPattern = NStr("en = 'greater than %1';");
					CurrentRow.ValuePresentation = StrTemplate(StringPattern, String(PreviousString.ValueUpTo));
				EndIf;
			EndIf;
		Else
			If CurrentIndex = 0 Then
				StringPattern = NStr("en = '%1 or less';");
				CurrentRow.ValuePresentation = StrTemplate(StringPattern, String(CurrentRow.ValueUpTo));
			Else
				PreviousString = TableOfRanges[CurrentIndex - 1];
				If PreviousString.ValueUpTo = CurrentRow.ValueUpTo Then
					CurrentRow.ValuePresentation = PreviousString.ValuePresentation;
				Else
					CurrentRow.ValuePresentation = StrTemplate(NStr("en = 'from %1 to %2';"),
						String(PreviousString.ValueUpTo), 
						String(CurrentRow.ValueUpTo));
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckIfHintsRangeFilled(TableOfRanges, Cancel)
	
	ArrayOfValues = New Array;
	
	For Each CurrentRow In TableOfRanges Do
		If ArrayOfValues.Find(CurrentRow.ValueUpTo) <> Undefined Then
			Cancel = True;
			Return;
		EndIf;
		ArrayOfValues.Add(CurrentRow.ValueUpTo);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetHintRangePosition(TableOfRanges, CurrentData, ElementValue)
	
	ItemCount = TableOfRanges.Count();
	
	If ItemCount <= 1 Then
		Return;
	EndIf;
	
	CurrentPosition = TableOfRanges.IndexOf(CurrentData);
	
	IsPositionFound = False;
	For Each CollectionItem In TableOfRanges Do
		
		CurrentIndex = TableOfRanges.IndexOf(CollectionItem);
		IsLastItem = ?(ItemCount = CurrentIndex + 1, True, False);
		
		If Not IsLastItem Then
			NewPosition = CurrentIndex;
		EndIf;
		
		IsGreatestValueItemFound = ?(CollectionItem.ValueUpTo > ElementValue, True, False);
		
		If IsGreatestValueItemFound Then
			IsPositionFound = True;
		EndIf;
		
		If IsPositionFound Then
			If NewPosition > CurrentPosition Then
				NewPosition = NewPosition - 1;
			EndIf;
			Break;
		EndIf
		
	EndDo;
	
	Move = NewPosition - CurrentPosition;
	TableOfRanges.Move(CurrentPosition, Move);
	
EndProcedure

#EndRegion
