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
	
	If Not Parameters.Property("QuestionnaireTemplate") Then
		Cancel = True;
		Return;
	Else
		QuestionnaireTemplate = Parameters.QuestionnaireTemplate;
	EndIf;
	
	SetFormAttributesValuesAccordingToQuestionnaireTemplate();
	Surveys.SetQuestionnaireSectionsTreeItemIntroductionConclusion(SectionsTree, NStr("en = 'Introduction';"), "Introduction");
	Surveys.FillSectionsTree(ThisObject,SectionsTree);
	Surveys.SetQuestionnaireSectionsTreeItemIntroductionConclusion(SectionsTree, NStr("en = 'Closing statement';"), "ClosingStatement");
	SurveysClientServer.GenerateTreeNumbering(SectionsTree,True);
	
	Items.SectionsTree.CurrentRow = 0;
	CreateFormAccordingToSection();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SectionsNavigationButtonAvailabilityControl();
	
EndProcedure 

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SectionsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.SectionsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExecuteFillingFormCreation();
	SectionsNavigationButtonAvailabilityControl();
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeQuestionsWithConditions(Item)

	AvailabilityControlSubordinateQuestions();

EndProcedure

&AtClient
Procedure Attachable_OnChangeRangeSlider(Item)
	
	SurveysClient.OnChangeRangeSlider(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeOfNumberField(Item)
	
	SurveysClient.OnChangeOfNumberField(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_NumberFieldAdjustment(Item, Direction, StandardProcessing)
	
	SurveysClient.NumberFieldAdjustment(ThisObject, Item, Direction, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure HideSections(Command)

	ChangeSectionsTreeVisibility();
	
EndProcedure

&AtClient
Procedure PreviousSection(Command)
	
	ChangeSection("Back");
	
EndProcedure

&AtClient
Procedure NextSection(Command)
	
	ChangeSection("GoForward");
	
EndProcedure

&AtClient
Procedure SelectSection(Command)
	
	ExecuteFillingFormCreation();
	SectionsNavigationButtonAvailabilityControl();

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

EndProcedure

&AtServer
Procedure CreateFormAccordingToSection()
	
	CurrentDataSectionsTree = SectionsTree.FindByID(Items.SectionsTree.CurrentRow);
	If CurrentDataSectionsTree = Undefined Then
		Return;
	EndIf;
	
	CurrentSectionNumber = Items.SectionsTree.CurrentRow;
	Surveys.CreateFillingFormBySection(ThisObject,CurrentDataSectionsTree);
	Surveys.GenerateQuestionsSubordinationTable(ThisObject);
	
	Items.FooterPreviousSection.Visible = (SectionQuestionsTable.Count() > 0);
	Items.FooterNextSection.Visible  = (SectionQuestionsTable.Count() > 0);
	
	SurveysClientServer.SwitchQuestionnaireBodyGroupsVisibility(ThisObject, True);
	
EndProcedure

&AtClient
Procedure ExecuteFillingFormCreation()
	
	SurveysClientServer.SwitchQuestionnaireBodyGroupsVisibility(ThisObject, False);
	AttachIdleHandler("EndBuildFillingForm",0.1,True);
	
EndProcedure

&AtClient
Procedure EndBuildFillingForm()
	
	CreateFormAccordingToSection();
	AvailabilityControlSubordinateQuestions();
	SectionsNavigationButtonAvailabilityControl();
	
EndProcedure

&AtClient
Procedure SectionsNavigationButtonAvailabilityControl()
	
	IsFirstSection = Items.SectionsTree.CurrentRow = 0;
	IsLastSection = SectionsTree.FindByID(Items.SectionsTree.CurrentRow +  1) = Undefined;

	Items.PreviousSection.Visible        = Not IsFirstSection;
	Items.FooterPreviousSection.Visible  = Not IsFirstSection;
	Items.NextSection.Visible         = Not IsLastSection;
	Items.NextSection.DefaultButton = Not IsLastSection;
	Items.FooterNextSection.Visible   = Not IsLastSection;
	Items.Close.Visible                 = IsLastSection;
	Items.Close.DefaultButton         = IsLastSection;
	
EndProcedure

&AtClient
Procedure ChangeSection(Direction)
	
	Items.SectionsTree.CurrentRow = CurrentSectionNumber + ?(Direction = "GoForward",1,-1);
	CurrentSectionNumber = CurrentSectionNumber + ?(Direction = "GoForward",1,-1);
	CurrentDataSectionsTree = SectionsTree.FindByID(Items.SectionsTree.CurrentRow);
	If CurrentDataSectionsTree.QuestionsCount = 0 And CurrentDataSectionsTree.RowType = "Section"  Then
		ChangeSection(Direction);
	EndIf;
	ExecuteFillingFormCreation();
	
EndProcedure

&AtClient
Procedure ChangeSectionsTreeVisibility()

	Items.SectionsTreeGroup.Visible         = Not Items.SectionsTreeGroup.Visible;
	Items.HideSections.Title = ?(Items.SectionsTreeGroup.Visible,NStr("en = 'Hide sections';"), NStr("en = 'Show sections';"));

EndProcedure 

&AtClient
Procedure AvailabilityControlSubordinateQuestions()
	
	For Each CollectionItem In DependentQuestions Do
		
		QuestionName = SurveysClientServer.QuestionName(CollectionItem.DoQueryBox);
		
		For Each SubordinateQuestion In CollectionItem.SubordinateItems Do
			
			ItemOfSubordinateQuestion = Items[SubordinateQuestion.SubordinateQuestionItemName];
			ItemOfSubordinateQuestion.ReadOnly = Not ThisObject[QuestionName];
			If StrOccurrenceCount(SubordinateQuestion.SubordinateQuestionItemName, "Attribute") = 0 Then
				
				Try
					ItemOfSubordinateQuestion.AutoMarkIncomplete = 
						ThisObject[QuestionName] And SubordinateQuestion.IsRequired;
				Except
					// 
				EndTry;
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure 

&AtServer
Procedure SetFormAttributesValuesAccordingToQuestionnaireTemplate()

	AttributesQuestionnaireTemplate = Common.ObjectAttributesValues(QuestionnaireTemplate,"Title,Introduction,ClosingStatement");
	FillPropertyValues(ThisObject,AttributesQuestionnaireTemplate);

EndProcedure

#EndRegion
