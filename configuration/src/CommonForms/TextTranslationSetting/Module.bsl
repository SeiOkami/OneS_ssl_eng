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
	
	If Common.IsMobileClient() Then
		Items.WriteAndClose.Representation = ButtonRepresentation.Picture;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Owner = Common.MetadataObjectID("Constant.TextTranslationService");
	
	SetPrivilegedMode(True);
	For Each Parameter In AuthorizationParameters Do
		If Parameter.Presentation <> String(UUID) Then
			Common.WriteDataToSecureStorage(Owner, Parameter.Presentation, Parameter.Value);
		EndIf;
	EndDo;
	SetPrivilegedMode(False);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Not ValueIsFilled(ConstantsSet.TextTranslationService) Then
		ConstantsSet.TextTranslationService = Enums.TextTranslationServices.YandexTranslate;
	EndIf;
	
	FillSettings();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TextTranslationServiceOnChange(Item)
	
	FillSettings();
	
EndProcedure

&AtClient
Procedure PlugInAuthorizationParameterChangingTheEditText(Item, Text, StandardProcessing)
	Item.ChoiceButton = True;
EndProcedure

// Parameters:
//  Item - FormField
//
&AtClient
Procedure PlugInAuthorizationParameterStartOfSelection(Item, ChoiceData, StandardProcessing)
	
	IndexOf = AuthorizationParameters.IndexOf(AuthorizationParameters.FindByValue(Item.Name));
	SwitchPasswordMode(Item, AuthorizationParameters[IndexOf].Presentation, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	Write();
	Close(ConstantsSet.TextTranslationService);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSettings()
	
	TextTranslationService = ConstantsSet.TextTranslationService;
	
	For Each Parameter In AuthorizationParameters Do
		Items.Delete(Items[Parameter.Value]);
	EndDo;
	AuthorizationParameters.Clear();
	
	Items.Instruction.Title = "";
	
	SetPrivilegedMode(True);
	
	AuthorizationSettings = TextTranslationTool.AuthorizationSettings(TextTranslationService);
	If AuthorizationSettings = Undefined Then
		Return;
	EndIf;
	
	TextTranslationServiceSettings = TextTranslationTool.TextTranslationServiceSettings(TextTranslationService);
	Items.Instruction.Title = TextTranslationServiceSettings.ConnectionInstructions;
	
	For IndexOf = 0 To TextTranslationServiceSettings.AuthorizationParameters.Count() - 1  Do
		ParameterDetails = TextTranslationServiceSettings.AuthorizationParameters[IndexOf];
		ParameterValue = AuthorizationSettings[ParameterDetails.Name];
		AuthorizationParameters.Add(ParameterDetails.Name, ?(ValueIsFilled(ParameterValue), UUID, ""));
		
		InputField = Items.Add(ParameterDetails.Name, Type("FormField"), Items.AuthorizationParameters);
		InputField.Type = FormFieldType.InputField;
		InputField.Title = ParameterDetails.Presentation;
		InputField.DataPath = "AuthorizationParameters[" + IndexOf + "].Presentation";
		InputField.ToolTipRepresentation = ParameterDetails.ToolTipRepresentation;
		InputField.ExtendedTooltip.Title = ParameterDetails.ToolTip;
		InputField.SetAction("StartChoice", "PlugInAuthorizationParameterStartOfSelection");
		InputField.SetAction("EditTextChange", "PlugInAuthorizationParameterChangingTheEditText");
		InputField.PasswordMode = True;
		InputField.ChoiceButton = Not ValueIsFilled(ParameterValue);
		InputField.ChoiceButtonPicture = PictureLib.CharsBeingTypedShown;
	EndDo;
	
EndProcedure

&AtClient
Procedure SwitchPasswordMode(Item, Attribute, StandardProcessing)
	
	StandardProcessing = False;
	Attribute = Item.EditText;
	Item.PasswordMode = Not Item.PasswordMode;
	If Item.PasswordMode Then
		Item.ChoiceButtonPicture = PictureLib.CharsBeingTypedShown;
	Else
		Item.ChoiceButtonPicture = PictureLib.CharsBeingTypedHidden;
	EndIf;
	
EndProcedure

#EndRegion

