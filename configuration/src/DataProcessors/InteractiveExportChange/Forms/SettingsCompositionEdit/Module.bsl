///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(Object, Parameters.Object , , "AllDocumentsFilterComposer, AdditionalRegistration, AdditionalNodeScenarioRegistration");
	For Each String In Parameters.Object.AdditionalRegistration Do
		FillPropertyValues(Object.AdditionalRegistration.Add(), String);
	EndDo;
	For Each String In Parameters.Object.AdditionalNodeScenarioRegistration Do
		FillPropertyValues(Object.AdditionalNodeScenarioRegistration.Add(), String);
	EndDo;
	
	// Initialize composer manually.
	DataProcessorObject1 = FormAttributeToValue("Object");
	
	Data = GetFromTempStorage(Parameters.Object.AllDocumentsComposerAddress);
	DataProcessorObject1.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	DataProcessorObject1.AllDocumentsFilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	DataProcessorObject1.AllDocumentsFilterComposer.LoadSettings(Data.Settings);
	
	ValueToFormAttribute(DataProcessorObject1, "Object");
	
	CurrentSettingsItemPresentation = Parameters.CurrentSettingsItemPresentation;
	ReadSavedSettings();
EndProcedure

#EndRegion

#Region SettingVariantsFormTableItemEventHandlers
//

&AtClient
Procedure SettingVariantsSelection(Item, RowSelected, Field, StandardProcessing)
	CurrentData = SettingVariants.FindByID(RowSelected);
	If CurrentData<>Undefined Then
		CurrentSettingsItemPresentation = CurrentData.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SettingVariantsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure SettingVariantsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	
	SettingPresentation = Item.CurrentData.Presentation;
	
	TitleText = NStr("en = 'Confirm operation';");
	QueryText   = NStr("en = 'Do you want to delete setting ""%1""?';");
	
	QueryText = StrReplace(QueryText, "%1", SettingPresentation);
	
	AdditionalParameters = New Structure("SettingPresentation", SettingPresentation);
	NotifyDescription = New NotifyDescription("DeleteSettingsVariantRequestNotification", ThisObject, 
		AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure SaveSetting(Command)
	
	If IsBlankString(CurrentSettingsItemPresentation) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please enter the setting name.';"), , "CurrentSettingsItemPresentation");
		Return;
	EndIf;
		
	If SettingVariants.FindByValue(CurrentSettingsItemPresentation)<>Undefined Then
		TitleText = NStr("en = 'Confirm operation';");
		QueryText   = NStr("en = 'Do you want to overwrite setting ""%1""?';");
		QueryText = StrReplace(QueryText, "%1", CurrentSettingsItemPresentation);
		
		AdditionalParameters = New Structure("SettingPresentation", CurrentSettingsItemPresentation);
		NotifyDescription = New NotifyDescription("SaveSettingsVariantRequestNotification", ThisObject, 
			AdditionalParameters);
			
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo,,,TitleText);
		Return;
	EndIf;
	
	// Save without displaying a question.
	SaveAndExecuteCurrentSettingSelection();
EndProcedure
	
&AtClient
Procedure MakeChoice(Command)
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure

#EndRegion

#Region Private
//

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Procedure DeleteSettingItemServer(SettingPresentation)
	ThisObject().DeleteSettingsOption(SettingPresentation);
EndProcedure

&AtServer
Procedure ReadSavedSettings()
	ThisDataProcessor = ThisObject();
	
	VariantFilter = DataExchangeServer.InteractiveExportChangeOptionFilter(Object);
	SettingVariants = ThisDataProcessor.ReadSettingsListPresentations(Object.InfobaseNode, VariantFilter);
	
	ListItem = SettingVariants.FindByValue(CurrentSettingsItemPresentation);
	Items.SettingVariants.CurrentRow = ?(ListItem=Undefined, Undefined, ListItem.GetID())
EndProcedure

&AtServer
Procedure SaveCurrentSettings()
	ThisObject().SaveCurrentValuesInSettings(CurrentSettingsItemPresentation);
EndProcedure

&AtClient
Procedure ExecuteSelection(Presentation)
	If SettingVariants.FindByValue(Presentation)<>Undefined And CloseOnChoice Then 
		NotifyChoice( New Structure("ChoiceAction, SettingPresentation", 3, Presentation) );
	EndIf;
EndProcedure

&AtClient
Procedure DeleteSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteSettingItemServer(AdditionalParameters.SettingPresentation);
	ReadSavedSettings();
EndProcedure

&AtClient
Procedure SaveSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CurrentSettingsItemPresentation = AdditionalParameters.SettingPresentation;
	SaveAndExecuteCurrentSettingSelection();
EndProcedure

&AtClient
Procedure SaveAndExecuteCurrentSettingSelection()
	
	SaveCurrentSettings();
	ReadSavedSettings();
	
	CloseOnChoice = True;
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure;

#EndRegion
