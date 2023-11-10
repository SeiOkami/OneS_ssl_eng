///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// 
//
// 
// 
// 
// 
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects - 
//          
//    * Object - FormDataStructure
//             - CatalogObject
//             - DocumentObject
//
//  ContinuationHandler - Undefined - no actions after the procedure execution.
//                       - NotifyDescription - 
//                         
//                           
//                           
//                                    
//
//  OnlyVisible - Boolean - set this parameter to False to get and unlock all object attributes.
//
Procedure AllowObjectAttributeEdit(Val Form, ContinuationHandler = Undefined, OnlyVisible = True) Export
	
	LockedAttributes = Attributes(Form, , OnlyVisible);
	
	If LockedAttributes.Count() = 0 Then
		ShowAllVisibleAttributesUnlockedWarning(
			New NotifyDescription("AllowObjectAttributeEditAfterWarning",
				ObjectAttributesLockInternalClient, ContinuationHandler));
		Return;
	EndIf;
	
	DetailsOfAttributesToLock = New Array;
	
	For Each AttributeDetails In Form.AttributeEditProhibitionParameters Do
		If LockedAttributes.Find(AttributeDetails.AttributeName) = Undefined Then
			Continue;
		EndIf;
		LongDesc = New Structure("AttributeName, Presentation, EditingAllowed,
			|ItemsToLock, RightToEdit, IsFormAttribute");
		FillPropertyValues(LongDesc, AttributeDetails);
		DetailsOfAttributesToLock.Add(LongDesc);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("LockedAttributes", LockedAttributes);
	FormParameters.Insert("Ref", Form.Object.Ref);
	
	NameOfUnlockForm = Form.FullNameOfAttributeUnlockForm;
	If Not ValueIsFilled(NameOfUnlockForm) Then
		NameOfUnlockForm = "CommonForm.AttributeUnlocking";
		FormParameters.Insert("FullObjectName", Form.FullNameOfAttributesUnlockingObject);
		FormParameters.Insert("DetailsOfAttributesToLock", DetailsOfAttributesToLock);
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Form", Form);
	Parameters.Insert("LockedAttributes", LockedAttributes);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	NotifyDescription = New NotifyDescription("AllowEditingObjectAttributesAfterFormClosed",
		ObjectAttributesLockInternalClient, Parameters);
	
	OpenForm(NameOfUnlockForm, FormParameters, , , , , NotifyDescription);
	
EndProcedure

// Sets the availability of form items associated with the specified attributes
// whose editing is allowed. If an attribute array is passed,
// attributes allowed for editing will be supplemented first.
//   If unlocking of form items linked to the specified attributes
// is released for all the attributes, the button that allows editing becomes unavailable.
//
// Parameters:
//  Form        - ClientApplicationForm - a form, in which it is required to allow
//                 editing form items of the specified attributes.
//  
//  Attributes    - Array - values:
//                  * String - 
//                    
//               - Undefined - 
//                 
//                 
//
Procedure SetFormItemEnabled(Val Form, Val Attributes = Undefined) Export
	
	SetAttributeEditEnabling(Form, Attributes);
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.EditingAllowed Then
			For Each FormItemToLock In DescriptionOfAttributeToLock.ItemsToLock Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined Then
					If TypeOf(FormItem) = Type("FormField")
					   And FormItem.Type <> FormFieldType.LabelField
					 Or TypeOf(FormItem) = Type("FormTable") Then
						FormItem.ReadOnly = False;
					Else
						FormItem.Enabled = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Allows editing the attributes whose descriptions are given in the form.
//  Used when form item availability is changed explicitly
// without using the SetFormItemEnabled function.
//
// Parameters:
//  Form        - ClientApplicationForm - — a form in which editing object attributes must be allowed, where:
//    * Items - FormAllItems:
//        ** AllowObjectAttributeEdit - FormButton
//  Attributes    - Array of String - attribute names to mark as allowed for editing.
//  EditingAllowed - Boolean - flag that shows whether you want to allow attribute editing.
//                            The value will not be set to True if you are not authorized to edit the attribute.
//                          - Undefined - 
//  RightToEdit - Boolean - flag used to override availability
//                        of unlocking attributes. It is determined automatically using the AccessRight method.
//                      - Undefined - 
// 
Procedure SetAttributeEditEnabling(Val Form, Val Attributes,
			Val EditingAllowed = True, Val RightToEdit = Undefined) Export
	
	If TypeOf(Attributes) = Type("Array") Then
		
		For Each Attribute In Attributes Do
			AttributeDetails = Form.AttributeEditProhibitionParameters.FindRows(New Structure("AttributeName", Attribute))[0];
			If TypeOf(RightToEdit) = Type("Boolean") Then
				AttributeDetails.RightToEdit = RightToEdit;
			EndIf;
			If TypeOf(EditingAllowed) = Type("Boolean") Then
				AttributeDetails.EditingAllowed = AttributeDetails.RightToEdit And EditingAllowed;
			EndIf;
		EndDo;
	EndIf;
	
	// Updating the availability of AllowObjectAttributeEdit command.
	AllAttributesUnlocked = True;
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.RightToEdit
		And Not DescriptionOfAttributeToLock.EditingAllowed Then
			AllAttributesUnlocked = False;
			Break;
		EndIf;
	EndDo;
	
	If AllAttributesUnlocked Then
		Form.Items.AllowObjectAttributeEdit.Enabled = False;
	EndIf;
	
EndProcedure

// Returns an array of attribute names specified in the AttributesLockParameters form property
// based on the attribute names specified in the object manager module excluding the attributes
// with RightToEdit = False.
//
// Parameters:
//  Form         - ClientApplicationForm - an object form with a required standard Object attribute.
//  OnlyBlocked - Boolean - you can set this parameter to Falsefor debug purposes,
//                  to get a list of all visible attributes that can be unlocked.
//  OnlyVisible - Boolean - set this parameter to False to get and unlock all object attributes.
//
// Returns:
//  Array of String - 
//
Function Attributes(Val Form, Val OnlyBlocked = True, OnlyVisible = True) Export
	
	Attributes = New Array;
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		
		If DescriptionOfAttributeToLock.RightToEdit
		   And (    DescriptionOfAttributeToLock.EditingAllowed = False
		      Or OnlyBlocked = False) Then
			
			AddAttribute = False;
			For Each FormItemToLock In DescriptionOfAttributeToLock.ItemsToLock Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined And (FormItem.Visible Or Not OnlyVisible) Then
					AddAttribute = True;
					Break;
				EndIf;
			EndDo;
			If AddAttribute Then
				Attributes.Add(DescriptionOfAttributeToLock.AttributeName);
			EndIf;
		EndIf;
	EndDo;
	
	Return Attributes;
	
EndFunction

// Displays a warning that all visible attributes are unlocked.
// The warning is required when the unlock command
// remains enabled because of invisible locked attributes.
//
// Parameters:
//  ContinuationHandler - Undefined - no actions after the procedure execution.
//                       - NotifyDescription - 
//
Procedure ShowAllVisibleAttributesUnlockedWarning(ContinuationHandler = Undefined) Export
	
	ShowMessageBox(ContinuationHandler,
		NStr("en = 'Editing visible attributes of the object is already allowed.';"));
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// 
//
// Parameters:
//  Parameters - See NewParametersAllowEditingObjectAttributes
//
Procedure AllowObjectsAttributesEdit(Parameters) Export

	FormParameters = New Structure;
	FormParameters.Insert("BatchEditObjects", True);
	FormParameters.Insert("LockedAttributes",   Parameters.LockedAttributes);
	FormParameters.Insert("AddressOfRefsToObjects",       Parameters.AddressOfRefsToObjects);
	FormParameters.Insert("MarkedAttribute",         Parameters.MarkedAttribute);
	
	FullNameOfStandardForm = "CommonForm.AttributeUnlocking";
	FullFormName = Parameters.FullObjectName + ".Form.AttributeUnlocking";
	
	Try
		// 
		ObtainedForm = GetForm(FullFormName);
		// 
		If Not ObtainedForm.Parameters.Property("BatchEditObjects") Then
			FullFormName = FullNameOfStandardForm;
		EndIf;
	Except
		FullFormName = FullNameOfStandardForm;
	EndTry;
	
	If FullFormName = FullNameOfStandardForm Then
		FormParameters.Insert("FullObjectName", Parameters.FullObjectName);
	EndIf;
	
	OpenForm(FullFormName, FormParameters, , , , , Parameters.ResultProcessing);
	
EndProcedure

// 
//
// Returns:
//  Structure:
//   * ResultProcessing - NotifyDescription -
//             
//             
//
//   * FullObjectName - String -
//
//   * LockedAttributes - Array of String -
//            
//
//   * MarkedAttribute - String -
//            
//
//   * AddressOfRefsToObjects - String -
//            
//
Function NewParametersAllowEditingObjectAttributes() Export
	
	NewParameters = New Structure;
	NewParameters.Insert("ResultProcessing");
	NewParameters.Insert("FullObjectName", "");
	NewParameters.Insert("LockedAttributes", New Array);
	NewParameters.Insert("MarkedAttribute", "");
	NewParameters.Insert("AddressOfRefsToObjects", "");
	
	Return NewParameters;
	
EndFunction

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated.
// 
// 
//
// 
// 
//
// Parameters:
//  ContinuationHandler - NotifyDescription - notification called after the check.
//                         A Boolean parameter is passed to the notification handler:
//                           True - no references are found or the user decided to allow editing.
//                           False   - no visible attributes are locked,
//                                    or references are found and the user decided to cancel the operation.
//  ReferencesArrray         - Array - values:
//                           * Ref - 
//  AttributesSynonyms   - Array - values:
//                           * String - 
//
Procedure CheckObjectRefs(Val ContinuationHandler, Val ReferencesArrray, Val AttributesSynonyms) Export
	
	DialogTitle = NStr("en = 'Allow attribute edit';");
	
	AttributesPresentation = "";
	For Each AttributeSynonym In AttributesSynonyms Do
		AttributesPresentation = AttributesPresentation + AttributeSynonym + "," + Chars.LF;
	EndDo;
	AttributesPresentation = Left(AttributesPresentation, StrLen(AttributesPresentation) - 2);
	
	If AttributesSynonyms.Count() > 1 Then
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To prevent data inconsistency, the following attributes are locked:
			           |%1.
			           |
			           |Before you allow editing, view the occurrences of these attributes
			           |and consider possible data implications.
			           |Generating the list of occurrences might take a while.
			           |';"),
			AttributesPresentation);
	Else
		If ReferencesArrray.Count() = 1 Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To prevent data inconsistency, attribute %1 is locked.
				           |
				           |Before you allow editing, view the occurrences of %2
				           |and consider possible data implications.
				           |Generating the list of occurrences might take a while.
				           |';"),
				AttributesPresentation, ReferencesArrray[0]);
		Else
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To prevent data inconsistency, attribute %1 is locked.
				           |
				           |Before you allow editing, view the occurrences of the selected items (%2)
				           |and consider possible data implications.
				           |Generating the list of occurrences might take a while.
				           |';"),
				AttributesPresentation, ReferencesArrray.Count());
		EndIf;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ReferencesArrray", ReferencesArrray);
	Parameters.Insert("AttributesSynonyms", AttributesSynonyms);
	Parameters.Insert("DialogTitle", DialogTitle);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'View and allow';"));
	Buttons.Add(DialogReturnCode.No, NStr("en = 'Cancel';"));
	
	ShowQueryBox(
		New NotifyDescription("CheckObjectReferenceAfterValidationConfirm",
			ObjectAttributesLockInternalClient, Parameters),
		QueryText, Buttons, , DialogReturnCode.Yes, DialogTitle);
	
EndProcedure

#EndRegion

#EndRegion
