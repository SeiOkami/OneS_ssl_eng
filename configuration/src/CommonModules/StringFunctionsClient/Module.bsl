///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Generates a string according to the specified pattern.
// The possible tag values in the template:
// - <span style="Property name: Style element name">String </span> - formats text with style items described
//      in the style attribute.
// - <b> String </b> - highlights the line with an ImportantLabelFont style item
//      that matches the bold font.
// - <a href="Ref">String</a> - adds a hyperlink.
// - <img src="Calendar"> - adds a picture from the picture library.
// The style attribute is used to arrange the text. The attribute can be used for the span and a tags.
// First goes a style property name, then a style item name through the colon.
// Style properties:
//  - color - defines text color. For example, color: HyperlinkColor;
//  - background-color - defines color of the text background. For example, background-color: TotalsGroupBackground;
//  - font - defines text font. For example, font: MainListItem.
// Style properties are separated by semicolon. For example, style="color: HyperlinkColor; font: MainListItem"
// Nested tags are not supported.
//
// Parameters:
//  StringPattern - String - a string containing formatting tags.
//  Parameter<n>  - String - parameter value to insert.
//
// Returns:
//  FormattedString - 
//
// Example:
//  1. StringFunctionsClient.FormattedString(NStr("en='
//       <span style=""color: LockedAttributeColor; font: ImportantLabelFont"">Minimum</span>application version<b>1.1</b>. 
//       <a href = ""Update"">Update</a> the application.'"));
//  2. StringFunctionsClient.FormattedString(NStr("en='Mode: <img src=""EditInDialog"">
//       <a style=""color: ModifiedAttributeValueColor; background-color: ModifiedAttributeValueBackground""
//       href=""e1cib/command/DataProcessor.Editor"">Edit</a>'"));
//  3. StringFunctionsClient.FormattedString(NStr("en='Current date <img src=""Calendar"">
//       <span style=""font:ImportantLabelFont"">%1</span>'"), CurrentSessionDate());
//
Function FormattedString(Val StringPattern, Val Parameter1 = Undefined, Val Parameter2 = Undefined,
	Val Parameter3 = Undefined, Val Parameter4 = Undefined, Val Parameter5 = Undefined) Export
	
	StyleItems = StandardSubsystemsClient.StyleItems();
	Return StringFunctionsClientServer.GenerateFormattedString(StringPattern, StyleItems, Parameter1, Parameter2, Parameter3, Parameter4, Parameter5);
	
EndFunction

// Transliterates the source string.
// It can be used to send text messages in Latin characters or to save
// files and folders to ensure that they can be transferred between different operating systems.
// Reverse conversion from the Latin character is not available.
//
// Parameters:
//  Value - String - arbitrary string.
//
// Returns:
//  String - 
//
Function LatinString(Val Value) Export
	
	TransliterationRules = New Map;
	StandardSubsystemsClientServerLocalization.OnFillTransliterationRules(TransliterationRules);
	Return CommonInternalClientServer.LatinString(Value, TransliterationRules);
	
EndFunction

// Returns a period presentation in lowercase or with an uppercase letter
//  if a phrase or a sentence starts with the period presentation.
//  For example, if the period presentation is displayed in the report heading
//  as "Sales for [ДатаНачала] - [ДатаОкончания]",
//  it will look like this: "Sales for February 2020 - March 2020".
//  The period is in lowercase because it is not the beginning of the sentence.
//
// Parameters:
//  StartDate - Date - period start.
//  EndDate - Date - period end.
//  FormatString - String - determines a period formatting method.
//  Capitalize - Boolean - True if the period presentation is the beginning of a sentence.
//                    The default value is False.
//
// Returns:
//   String - 
//
Function PeriodPresentationInText(StartDate, EndDate, FormatString = "", Capitalize = False) Export 
	
	Return CommonInternalClientServer.PeriodPresentationInText(
		StartDate, EndDate, FormatString, Capitalize);
	
EndFunction

#EndRegion

