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
	
	Role = Parameters.PerformerRole;
	MainAddressingObject = Parameters.MainAddressingObject;
	AdditionalAddressingObject = Parameters.AdditionalAddressingObject;
	SetAddressingObjectTypes();
	SetItemsState();
	
	If Parameters.SelectAddressingObject Then
		CurrentItem = Items.MainAddressingObject;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If UsedWithoutAddressingObjects Then
		Return;
	EndIf;
		
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects And ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects And ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesAreSet And MainAddressingObject = Undefined Then
		
		Common.MessageToUser( 
		    StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" field is required.';"), Role.MainAddressingObjectTypes.Description ),,,
				"MainAddressingObject", Cancel);
				
	ElsIf TypesOfAditionalAddressingObjectAreSet And AdditionalAddressingObject = Undefined Then
		
		Common.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" field is required.';"), Role.AdditionalAddressingObjectTypes.Description ),,, 
			"AdditionalAddressingObject", Cancel);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKExecute()
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	SelectionResult = ClosingParameters();
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAddressingObjectTypes()
	
	MainAddressingObjectTypes = Role.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Role.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Role.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Role.UsedWithoutAddressingObjects;
	
EndProcedure

&AtServer
Procedure SetItemsState()

	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		And ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		And ValueIsFilled(AdditionalAddressingObjectTypes);
		
	Items.MainAddressingObject.Title = Common.ObjectAttributeValue(
		Role.MainAddressingObjectTypes, "Description",, CurrentLanguage().LanguageCode);
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesAreSet; 
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		And Not UsedWithoutAddressingObjects;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
		
	Items.AdditionalAddressingObject.Title = Common.ObjectAttributeValue(
		Role.AdditionalAddressingObjectTypes, "Description",, CurrentLanguage().LanguageCode);
	Items.AdditionalAddressingObject.Enabled = TypesOfAditionalAddressingObjectAreSet; 
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		And Not UsedWithoutAddressingObjects;
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	                        
EndProcedure

&AtServer
Function ClosingParameters()
	
	Result = New Structure;
	Result.Insert("PerformerRole", Role);
	Result.Insert("MainAddressingObject", MainAddressingObject);
	Result.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	
	If Common.IsReference(TypeOf(Result.MainAddressingObject)) And Result.MainAddressingObject.IsEmpty() Then
		Result.MainAddressingObject = Undefined;
	EndIf;
	
	If Common.IsReference(TypeOf(Result.AdditionalAddressingObject)) And Result.AdditionalAddressingObject.IsEmpty() Then
		Result.AdditionalAddressingObject = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
