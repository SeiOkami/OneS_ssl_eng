///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region UserNotification

// ACC:142-off 4 optional parameters for compatibility with the previous library versions.

// Adds the error to the error list that will be displayed to the user with the ShowErrorsToUser()
// procedure.
// The procedure collects errors to a list, which can be processed before they displayed to
// users. You can sort the error list alphabetically, remove doubles,
// or change the appearance (for example, display errors as a spreadsheet document, unlike the MessageToUser method default appearance).
//
// Parameters:
//  Errors - Undefined - create a new list of errors.
//         - Structure:
//            * ErrorList - Array of Structure:
//             ** ErrorField - String
//             ** SingleErrorText - String
//             ** ErrorsGroup1 - Arbitrary
//             ** LineNumber - Number
//             ** SeveralErrorsText - String
//            * ErrorGroups - Map
//         
//  ErrorField - String - the field value in the MessageToUser object.
//           If you want to include a row number, use placeholder "%1".
//           For example, "Object.TIN" or "Object.Users[%1].User".
//  SingleErrorText - String - the error text for scenarios when the collection contains only one ErrorGroup.
//           For example, NStr("en = 'User not selected.'").
//  ErrorsGroup1 - Arbitrary - provides text for a single error
//           or a group of errors. For example, for the Object.Users name.
//           If blank, provides the single error text by default.
//  LineNumber - Number - the row number to pass
//           to ErrorField and in SeveralErrorText. The displayed number is RowNumber + 1.
//  SeveralErrorsText - String - the error text for scenarios when the collection contains a number of errors with the same
//           ErrorGroup property. For example, NStr("en = 'User on row %1 not selected.'").
//  RowIndex - Undefined - the same as the RowNumber parameter.
//           Number - the number to pass
//           to ErrorField.
//
Procedure AddUserError(
		Errors,
		ErrorField,
		SingleErrorText,
		ErrorsGroup1 = Undefined,
		LineNumber = 0,
		SeveralErrorsText = "",
		RowIndex = Undefined) Export
	
	If Errors = Undefined Then
		Errors = New Structure;
		Errors.Insert("ErrorList", New Array);
		Errors.Insert("ErrorGroups", New Map);
	EndIf;
	
	If Not ValueIsFilled(ErrorsGroup1) Then
		// If the error group is empty, the single error text must be used.
	Else
		If Errors.ErrorGroups[ErrorsGroup1] = Undefined Then
			// 
			Errors.ErrorGroups.Insert(ErrorsGroup1, False);
		Else
			// 
			Errors.ErrorGroups.Insert(ErrorsGroup1, True);
		EndIf;
	EndIf;
	
	Error = New Structure;
	Error.Insert("ErrorField", ErrorField);
	Error.Insert("SingleErrorText", SingleErrorText);
	Error.Insert("ErrorsGroup1", ErrorsGroup1);
	Error.Insert("LineNumber", LineNumber);
	Error.Insert("SeveralErrorsText", SeveralErrorsText);
	Error.Insert("RowIndex", RowIndex);
	
	Errors.ErrorList.Add(Error);
	
EndProcedure

// ACC:142-on

// 
// 
// 
//
// Parameters:
//  Errors - See AddUserError.Errors
//  Cancel - Boolean - True, if errors have been reported.
//
Procedure ReportErrorsToUser(Errors, Cancel = False) Export
	
	If Errors = Undefined Then
		Return;
	EndIf;
	Cancel = True;
	
	For Each Error In Errors.ErrorList Do
		
		If Error.RowIndex = Undefined Then
			RowIndex = Error.LineNumber;
		Else
			RowIndex = Error.RowIndex;
		EndIf;
		
		If Errors.ErrorGroups[Error.ErrorsGroup1] <> True Then
			Message = CommonInternalClientServer.UserMessage(
				Error.SingleErrorText,
				Undefined,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		Else
			Message = CommonInternalClientServer.UserMessage(
				StrReplace(Error.SeveralErrorsText, "%1", Format(Error.LineNumber + 1, "NZ=0; NG=")),
				Undefined,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		EndIf;
		Message.Message();
		
	EndDo;
	
EndProcedure

// Generates a filling error text for fields and lists.
//
// Parameters:
//  FieldKind - String - can take the following values: Field, Column, and List.
//  MessageKind - String - can take the following values: FillType and Validity.
//  FieldName - String - Field name.
//  LineNumber - String
//              - Number - 
//  ListName - String - a list name.
//  MessageText - String - the detailed filling error description.
//
// Returns:
//   String - 
//
Function FillingErrorText(
		FieldKind = "Field",
		MessageKind = "FillType",
		FieldName = "",
		LineNumber = "",
		ListName = "",
		MessageText = "") Export
	
	If Upper(FieldKind) = "FIELD" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template =
				NStr("en = 'Field ""%1"" cannot be empty.';");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template =
				NStr("en = 'Invalid value in field ""%1"".
				           |%4';");
		EndIf;
	ElsIf Upper(FieldKind) = "COLUMN" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template = NStr("en = 'Column ""%1"" in line #%2, list ""%3"" cannot be empty.';");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template = 
				NStr("en = 'Column ""%1"" in line #%2, list ""%3"" contains invalid value.
				           |%4';");
		EndIf;
	ElsIf Upper(FieldKind) = "LIST" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template = NStr("en = 'The list ""%3"" is blank.';");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template =
				NStr("en = 'The list ""%3"" contains invalid data.
				           |%4';");
		EndIf;
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		Template,
		FieldName,
		LineNumber,
		ListName,
		MessageText);
	
EndFunction

// Generates a path to the LineNumber row and the AttributeName column of the TabularSectionName 
// tabular section to display messages on the form.
// This procedure is for using with the MessageToUser procedure
// (for passing values to the Field parameter or to the DataPath parameter). 
//
// Parameters:
//  TabularSectionName - String - tabular section name.
//  LineNumber - Number - a table part row number.
//  AttributeName - String - an attribute name.
//
// Returns:
//  String - 
//
Function PathToTabularSection(
		Val TabularSectionName,
		Val LineNumber, 
		Val AttributeName) Export
	
	Return TabularSectionName + "[" + Format(LineNumber - 1, "NZ=0; NG=0") + "]." + AttributeName;
	
EndFunction

#EndRegion

#Region CurrentEnvironment

////////////////////////////////////////////////////////////////////////////////
// The details functions of the current client application environment and operating system.

// For File mode, returns the full name of the directory, where the infobase is located.
// If the application runs in client/server mode, an empty string is returned.
//
// Returns:
//  String - 
//
Function FileInfobaseDirectory() Export
	
	ConnectionParameters = StringFunctionsClientServer.ParametersFromString(InfoBaseConnectionString());
	
	If ConnectionParameters.Property("File") Then
		Return ConnectionParameters.File;
	EndIf;
	
	Return "";
	
EndFunction

// 
//
// Parameters:
//  ValueOf1CEnterpriseType - Undefined -
//                                         
//                        - PlatformType - 
// Returns:
//  String - 
//
Function NameOfThePlatformType(Val ValueOf1CEnterpriseType = Undefined) Export
	
	If TypeOf(ValueOf1CEnterpriseType) <> Type("PlatformType") Then
		SystemInfo = New SystemInfo;
		ValueOf1CEnterpriseType = SystemInfo.PlatformType;
	EndIf;
	
	If ValueOf1CEnterpriseType = PlatformType.Linux_x86 Then
		Return "Linux_x86";
	ElsIf ValueOf1CEnterpriseType = PlatformType.Linux_x86_64 Then
		Return "Linux_x86_64";
	ElsIf ValueOf1CEnterpriseType = PlatformType.MacOS_x86 Then
		Return "MacOS_x86";
	ElsIf ValueOf1CEnterpriseType = PlatformType.MacOS_x86_64 Then
		Return "MacOS_x86_64";
	ElsIf ValueOf1CEnterpriseType = PlatformType.Windows_x86 Then
		Return "Windows_x86";
	ElsIf ValueOf1CEnterpriseType = PlatformType.Windows_x86_64 Then
		Return "Windows_x86_64";
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion

#Region Data

// Raises an exception with Message if Condition is not True.
// Is applied for script self-diagnostics.
//
// Parameters:
//   Condition - Boolean - If not True, exception is raised.
//   Message - String - a message text. If it is not specified, the exception is raised with the default message.
//   CheckContext - String - for example, name of the procedure or function to check.
//
Procedure Validate(Val Condition, Val Message = "", Val CheckContext = "") Export
	
	If Condition <> True Then
		
		If IsBlankString(Message) Then
			ExceptionText = NStr("en = 'Invalid operation.';"); // Assertion failed
		Else
			ExceptionText = Message;
		EndIf;
		
		If Not IsBlankString(CheckContext) Then
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 in %2';"), ExceptionText, CheckContext);
		EndIf;
		
		Raise ExceptionText;
		
	EndIf;
	
EndProcedure

// Raises an exception if the ParameterName parameter value type of the ProcedureOrFunctionName procedure or function
// does not match the excepted one.
// Is intended for validating types of parameters passed to the interface procedures and functions.
//
// Due to the implementation peculiarity, TypeDescription always includes the <Undefined> type.
// if a strict check of the type is required, use 
// a specific type, array or map of types in the ExpectedTypes parameter.
//
// Parameters:
//   NameOfAProcedureOrAFunction - String - name of the procedure or function that contains the parameter to check.
//   ParameterName - String - name of the parameter to check.
//   ParameterValue - Arbitrary - actual value of the parameter.
//   ExpectedTypes - TypeDescription
//                 - Type
//                 - Array
//                 - FixedArray
//                 - Map
//                 - FixedMap - 
//       
//   PropertiesTypesToExpect - Structure - If the expected type is a structure, 
//       this parameter can be used to specify its properties.
//   ExpectedValues - Array, String -
//
Procedure CheckParameter(Val NameOfAProcedureOrAFunction, Val ParameterName, Val ParameterValue, 
	Val ExpectedTypes, Val PropertiesTypesToExpect = Undefined, Val ExpectedValues = Undefined) Export
	
	Context = "CommonClientServer.CheckParameter";
	Validate(TypeOf(NameOfAProcedureOrAFunction) = Type("String"), 
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of %1 parameter.';"), "NameOfAProcedureOrAFunction"), 
		Context);
	Validate(TypeOf(ParameterName) = Type("String"), 
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of %1 parameter.';"), "ParameterName"), 
			Context);
	
	IsCorrectType = ExpectedTypeValue(ParameterValue, ExpectedTypes);
	Validate(IsCorrectType <> Undefined, 
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of %1 parameter.';"), "ExpectedTypes"),
		Context);
		
	If ParameterValue = Undefined Then
		PresentationOfParameterValue = "Undefined";
	ElsIf TypeOf(ParameterValue) = Type("BinaryData") And ParameterValue.Size() = 0 Then
		PresentationOfParameterValue = "";
	Else
		PresentationOfParameterValue = String(ParameterValue);
	EndIf;
	
	Validate(IsCorrectType,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2.
			           |Expected value: %3, passed value: %4 (type: %5).';"),
			ParameterName, NameOfAProcedureOrAFunction, TypesPresentation(ExpectedTypes), 
			PresentationOfParameterValue,
		TypeOf(ParameterValue)));
	
	If TypeOf(ParameterValue) = Type("Structure") And PropertiesTypesToExpect <> Undefined Then
		
		Validate(TypeOf(PropertiesTypesToExpect) = Type("Structure"), 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of %1 parameter.';"), "NameOfAProcedureOrAFunction"),
			Context);
		
		For Each Property In PropertiesTypesToExpect Do
			
			ExpectedPropertyName = Property.Key;
			ExpectedPropertyType = Property.Value;
			PropertyValue = Undefined;
			
			Validate(ParameterValue.Property(ExpectedPropertyName, PropertyValue), 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid value of parameter %1 (Structure) in %2.
					           |Expected value: %3 (type: %4).';"), 
					ParameterName, NameOfAProcedureOrAFunction, ExpectedPropertyName, ExpectedPropertyType));
			
			IsCorrectType = ExpectedTypeValue(PropertyValue, ExpectedPropertyType);
			Validate(IsCorrectType, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid value of property %1 in parameter %2 (Structure) in %3.
					           |Expected value: %4; passed value: %5 (type: %6).';"), 
					ExpectedPropertyName, ParameterName,	NameOfAProcedureOrAFunction,
					TypesPresentation(ExpectedTypes), 
					?(PropertyValue <> Undefined, PropertyValue, NStr("en = 'Undefined';")),
				TypeOf(PropertyValue)));
			
		EndDo;
	EndIf;
	
	If ExpectedValues <> Undefined Then
		If TypeOf(ExpectedValues) = Type("String") Then
			ExpectedValues = StrSplit(ExpectedValues, ",");
		EndIf; 
		Validate(ExpectedValues.Find(ParameterValue) <> Undefined,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter in %2.
				           |Expected value: %3.
				           |Actual value: %4 (type: %5).';"),
				ParameterName, NameOfAProcedureOrAFunction, StrConcat(ExpectedValues, ","), 
				PresentationOfParameterValue, TypeOf(ParameterValue)));
	EndIf;
	
EndProcedure

// Supplements the destination value table with data from the source value table.
// ValueTable, ValueTree, and TabularSection types are not available on the client.
//
// Parameters:
//  SourceTable1 - ValueTable
//                  - ValueTree
//                  - TabularSection
//                  - FormDataCollection - 
//                    
//  DestinationTable - ValueTable
//                  - ValueTree
//                  - TabularSection
//                  - FormDataCollection - 
//                    
//
Procedure SupplementTable(SourceTable1, DestinationTable) Export
	
	For Each SourceTableRow In SourceTable1 Do
		
		FillPropertyValues(DestinationTable.Add(), SourceTableRow);
		
	EndDo;
	
EndProcedure

// Supplements the Table value table with values from the Array array.
//
// Parameters:
//  Table - ValueTable - the table to be filled in with values from an array;
//  Array  - Array - an array of values to provide for the table;
//  FieldName - String - the name of the value table field that receives the array values.
// 
Procedure SupplementTableFromArray(Table, Array, FieldName) Export

	For Each Value In Array Do
		
		Table.Add()[FieldName] = Value;
		
	EndDo;
	
EndProcedure

// Supplements the DestinationArray array with values from the SourceArray array.
//
// Parameters:
//  DestinationArray - Array - the array that receives values.
//  SourceArray1 - Array - an array of values to provide for the table.
//  UniqueValuesOnly - Boolean - If True, the array keeps only unique values.
//
Procedure SupplementArray(DestinationArray, SourceArray1, UniqueValuesOnly = False) Export
	
	If UniqueValuesOnly Then
		
		UniqueValues = New Map;
		
		For Each Value In DestinationArray Do
			UniqueValues.Insert(Value, True);
		EndDo;
		
		For Each Value In SourceArray1 Do
			If UniqueValues[Value] = Undefined Then
				DestinationArray.Add(Value);
				UniqueValues.Insert(Value, True);
			EndIf;
		EndDo;
		
	Else
		
		For Each Value In SourceArray1 Do
			DestinationArray.Add(Value);
		EndDo;
		
	EndIf;
	
EndProcedure

// Supplies the structure with the values from the other structure.
//
// Parameters:
//   Receiver - Structure - the collection that receives new values.
//   Source - Structure - the collection that provides key-value pairs.
//   Replace - Boolean
//            - Undefined - 
//                             
//                             
//                             
//
Procedure SupplementStructure(Receiver, Source, Replace = Undefined) Export
	
	For Each Item In Source Do
		If Replace <> True And Receiver.Property(Item.Key) Then
			If Replace = False Then
				Continue;
			Else
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The source and destination have identical keys: ""%1"".';"), Item.Key);
			EndIf
		EndIf;
		Receiver.Insert(Item.Key, Item.Value);
	EndDo;
	
EndProcedure

// Complete a map with values from another map.
//
// Parameters:
//   Receiver - Map - the collection that receives new values.
//   Source - Map of KeyAndValue - the collection that provides key-value pairs.
//   Replace - Boolean
//            - Undefined - 
//                             
//                             
//                             
//
Procedure SupplementMap(Receiver, Source, Replace = Undefined) Export
	
	For Each Item In Source Do
		If Replace <> True And Receiver[Item.Key] <> Undefined Then
			If Replace = False Then
				Continue;
			Else
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The source and destination have identical keys: ""%1"".';"), Item.Key);
			EndIf
		EndIf;
		Receiver.Insert(Item.Key, Item.Value);
	EndDo;
	
EndProcedure

// 
//  
// 
// 
// Parameters:
//  DestinationList - ValueList
//  SourceList - ValueList
//  ShouldSkipValuesOfOtherTypes - Boolean - 
//                                   
//                                  
//  AddNewItems - Boolean, Undefined -
//                                          
// 
// Returns:
//  Structure:
//    * Total     - Number -
//    * Added2 - Number -
//    * Updated3 - Number - 
//                          
//    * Skipped3 - Number -
//
Function SupplementList(Val DestinationList, Val SourceList, Val ShouldSkipValuesOfOtherTypes = Undefined, 
	Val AddNewItems = True) Export
	
	Result = New Structure;
	Result.Insert("Total", 0);
	Result.Insert("Added2", 0);
	Result.Insert("Updated3", 0);
	Result.Insert("Skipped3", 0);
	
	If DestinationList = Undefined Or SourceList = Undefined Then
		Return Result;
	EndIf;
	
	ReplaceExistingItems = True;
	ReplacePresentation = ReplaceExistingItems And AddNewItems;
	
	If ShouldSkipValuesOfOtherTypes = Undefined Then
		ShouldSkipValuesOfOtherTypes = (DestinationList.ValueType <> SourceList.ValueType);
	EndIf;
	If ShouldSkipValuesOfOtherTypes Then
		DestinationTypesDetails = DestinationList.ValueType;
	EndIf;
	For Each SourceItem In SourceList Do
		Result.Total = Result.Total + 1;
		Value = SourceItem.Value;
		If ShouldSkipValuesOfOtherTypes And Not DestinationTypesDetails.ContainsType(TypeOf(Value)) Then
			Result.Skipped3 = Result.Skipped3 + 1;
			Continue;
		EndIf;
		DestinationItem = DestinationList.FindByValue(Value);
		If DestinationItem = Undefined Then
			If AddNewItems Then
				Result.Added2 = Result.Added2 + 1;
				FillPropertyValues(DestinationList.Add(), SourceItem);
			Else
				Result.Skipped3 = Result.Skipped3 + 1;
			EndIf;
		Else
			If ReplaceExistingItems Then
				Result.Updated3 = Result.Updated3 + 1;
				FillPropertyValues(DestinationItem, SourceItem, , ?(ReplacePresentation, "", "Presentation"));
			Else
				Result.Skipped3 = Result.Skipped3 + 1;
			EndIf;
		EndIf;
	EndDo;
	Return Result;
EndFunction

// Checks whether an arbitrary object has the attribute or property without metadata call.
//
// Parameters:
//  Object       - Arbitrary - the object whose attribute or property you need to check;
//  AttributeName - String       - the attribute or property name.
//
// Returns:
//  Boolean - 
//
Function HasAttributeOrObjectProperty(Object, AttributeName) Export
	
	UniqueKey   = New UUID;
	AttributeStructure = New Structure(AttributeName, UniqueKey);
	FillPropertyValues(AttributeStructure, Object);
	
	Return AttributeStructure[AttributeName] <> UniqueKey;
	
EndFunction

// Deletes all occurrences of the passed value from the array.
//
// Parameters:
//  Array - Array - the array that contains a value to delete;
//  Value - Arbitrary - the array value to delete.
// 
Procedure DeleteAllValueOccurrencesFromArray(Array, Value) Export
	
	CollectionItemsCount = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemsCount Do
		
		IndexOf = CollectionItemsCount - ReverseIndex;
		
		If Array[IndexOf] = Value Then
			
			Array.Delete(IndexOf);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes all occurrences of specified type values.
//
// Parameters:
//  Array - Array - the array that contains values to delete;
//  Type - Type - the type of values to be deleted.
// 
Procedure DeleteAllTypeOccurrencesFromArray(Array, Type) Export
	
	CollectionItemsCount = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemsCount Do
		
		IndexOf = CollectionItemsCount - ReverseIndex;
		
		If TypeOf(Array[IndexOf]) = Type Then
			
			Array.Delete(IndexOf);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes one value from the array.
//
// Parameters:
//  Array - Array - the array that contains a value to delete;
//  Value - Array - the array value to delete.
// 
Procedure DeleteValueFromArray(Array, Value) Export
	
	IndexOf = Array.Find(Value);
	If IndexOf <> Undefined Then
		Array.Delete(IndexOf);
	EndIf;
	
EndProcedure

// Returns the source array copy with the unique values.
//
// Parameters:
//  Array - Array - an array of values.
//
// Returns:
//  Array - 
//
Function CollapseArray(Val Array) Export
	Result = New Array;
	SupplementArray(Result, Array, True);
	Return Result;
EndFunction

// Returns the difference between arrays. The difference between two arrays is an array that contains
// all items of the first array that do not exist in the second array.
//
// Parameters:
//  Array - Array - an array to subtract from;
//  SubtractionArray - Array - an array being subtracted.
// 
// Returns:
//  Array - 
//
// Example:
//	//А = [1, 3, 5, 7];
//	//В = [3, 7, 9];
//	Result = CommonClientServer.ArraysDifference(А, В);
//	//Result = [1, 5];
//
Function ArraysDifference(Val Array, Val SubtractionArray) Export
	
	Result = New Array;
	For Each Item In Array Do
		If SubtractionArray.Find(Item) = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Compares item values in two value list or element values in two arrays.
//
// Parameters:
//  List1 - Array
//          - ValueList - 
//  List2 - Array
//          - ValueList - 
//
// Returns:
//  Boolean - 
//
Function ValueListsAreEqual(List1, List2) Export
	
	ListsAreEqual = True;
	
	For Each ListItem1 In List1 Do
		If FindInList(List2, ListItem1) = Undefined Then
			ListsAreEqual = False;
			Break;
		EndIf;
	EndDo;
	
	If ListsAreEqual Then
		For Each ListItem2 In List2 Do
			If FindInList(List1, ListItem2) = Undefined Then
				ListsAreEqual = False;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return ListsAreEqual;
	
EndFunction

// Creates an array and adds the passed value to it.
//
// Parameters:
//  Value - Arbitrary - a value.
//
// Returns:
//  Array - 
//
Function ValueInArray(Val Value) Export
	
	Result = New Array;
	Result.Add(Value);
	Return Result;
	
EndFunction

// Gets a string that contains character-separated structure keys.
//
// Parameters:
//  Structure - Structure - a structure that contains keys to convert into a string.
//  Separator - String - a separator inserted to a line between the structure keys.
//
// Returns:
//  String - 
//
Function StructureKeysToString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		Result = Result + SeparatorChar + Item.Key;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the structure property value.
//
// Parameters:
//   Structure - Structure
//             - FixedStructure - 
//   Var_Key - String - the structure property whose value to read.
//   DefaultValue - Arbitrary - Returned when the structure contains no value for the given
//                                        key.
//       To keep the system performance, it is recommended to pass only easy-to-calculate values (for example, primitive types).
//       Pass performance-demanding values only after ensuring that the value
//       is required.
//
// Returns:
//   Arbitrary - 
//
Function StructureProperty(Structure, Var_Key, DefaultValue = Undefined) Export
	
	If Structure = Undefined Then
		Return DefaultValue;
	EndIf;
	
	Result = DefaultValue;
	If Structure.Property(Var_Key, Result) Then
		Return Result;
	Else
		Return DefaultValue;
	EndIf;
	
EndFunction

// Returns an empty UUID.
//
// Returns:
//  UUID - 00000000-0000-0000-0000-000000000000
//
Function BlankUUID() Export
	
	Return New UUID("00000000-0000-0000-0000-000000000000");
	
EndFunction

#EndRegion

#Region ConfigurationsVersioning

// Gets the configuration version without the build version.
//
// Parameters:
//  Version - String - the configuration version in the RR.PP.ZZ.CC format,
//                    where CC is the build version and excluded from the result.
// 
// Returns:
//  String - 
//
Function ConfigurationVersionWithoutBuildNumber(Val Version) Export
	
	Array = StrSplit(Version, ".");
	
	If Array.Count() < 3 Then
		Return Version;
	EndIf;
	
	Result = "[Edition].[Subedition].[Release]";
	Result = StrReplace(Result, "[Edition]",    Array[0]);
	Result = StrReplace(Result, "[Subedition]", Array[1]);
	Result = StrReplace(Result, "[Release]",       Array[2]);
	
	Return Result;
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - the first version in the RR.{S|SS}.VV.BB format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number   - 
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString1", VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
	    	NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString2", VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 3 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - the first version in the RR.{P|PP}.ZZ format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number   - 
//
Function CompareVersionsWithoutBuildNumber(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString1", VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
	    	NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString2", VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 2 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

#EndRegion

#Region Forms

////////////////////////////////////////////////////////////////////////////////
// Functions for working with managed forms.
//

// Gets the form attribute value.
//
// Parameters:
//  Form - ClientApplicationForm - Form.
//  AttributePath2 - String - the path to the form attribute data, for example: "Object.AccrualMonth".
//
// Returns:
//  Arbitrary - the requisite forms.
//
Function GetFormAttributeByPath(Form, AttributePath2) Export
	
	NamesArray = StrSplit(AttributePath2, ".");
	
	Object        = Form;
	LastField = NamesArray[NamesArray.Count()-1];
	
	For Cnt = 0 To NamesArray.Count()-2 Do
		Object = Object[NamesArray[Cnt]]
	EndDo;
	
	Return Object[LastField];
	
EndFunction

// Sets the value to the form attribute.
// Parameters:
//  Form - ClientApplicationForm - a form that owns the attribute.
//  AttributePath2 - String - the path to the data, for example: "Object.AccrualMonth".
//  Value - Arbitrary - a value being set.
//  UnfilledOnly - Boolean - skips filling values for attributes
//                                  with already filled values.
//
Procedure SetFormAttributeByPath(Form, AttributePath2, Value, UnfilledOnly = False) Export
	
	NamesArray = StrSplit(AttributePath2, ".");
	
	Object        = Form;
	LastField = NamesArray[NamesArray.Count()-1];
	
	For Cnt = 0 To NamesArray.Count()-2 Do
		Object = Object[NamesArray[Cnt]]
	EndDo;
	If Not UnfilledOnly Or Not ValueIsFilled(Object[LastField]) Then
		Object[LastField] = Value;
	EndIf;
	
EndProcedure

// Searches for a filter item in the collection by the specified presentation.
//
// Parameters:
//  ItemsCollection - DataCompositionFilterItemCollection - container with filter groups and items,
//                                                                  such as List.Filter.Filter items or group.
//  Presentation - String - group presentation.
// 
// Returns:
//  DataCompositionFilterItem - 
//
Function FindFilterItemByPresentation(ItemsCollection, Presentation) Export
	
	ReturnValue = Undefined;
	
	For Each FilterElement In ItemsCollection Do
		If FilterElement.Presentation = Presentation Then
			ReturnValue = FilterElement;
			Break;
		EndIf;
	EndDo;
	
	Return ReturnValue
	
EndFunction

// Sets the PropertyName property of the ItemName form item to Value.
// Is applied when the form item might be missed on the form because of insufficient user rights
// for an object, an object attribute, or a command.
//
// Parameters:
//  FormItems - FormAllItems
//                - FormItems - 
//  TagName   - String       - a form item name.
//  PropertyName   - String       - the name of the form item property to be set.
//  Value      - Arbitrary - the new value of the item.
// 
Procedure SetFormItemProperty(FormItems, TagName, PropertyName, Value) Export
	
	FormItem = FormItems.Find(TagName);
	If FormItem <> Undefined And FormItem[PropertyName] <> Value Then
		FormItem[PropertyName] = Value;
	EndIf;
	
EndProcedure 

// Returns the value of the PropertyName property of the ItemName form item.
// Is applied when the form item might be missed on the form because of insufficient user rights for
// an object, an object attribute, or a command.
//
// Parameters:
//  FormItems - FormAllItems
//                - FormItems - 
//  TagName   - String       - the form item name.
//  PropertyName   - String       - the name of the form item property.
// 
// Returns:
//   Arbitrary - 
// 
Function FormItemPropertyValue(FormItems, TagName, PropertyName) Export
	
	FormItem = FormItems.Find(TagName);
	Return ?(FormItem <> Undefined, FormItem[PropertyName], Undefined);
	
EndFunction 

// Gets a picture to display on a page with a comment
// .
//
// Parameters:
//  Comment  - String - comment text.
//
// Returns:
//  Picture - 
//
Function CommentPicture(Comment) Export

	If Not IsBlankString(Comment) Then
		Picture = PictureLib.Comment;
	Else
		Picture = New Picture;
	EndIf;
	
	Return Picture;
	
EndFunction

#EndRegion

#Region DynamicList

////////////////////////////////////////////////////////////////////////////////
// Dynamic list filter and parameter management functions.
//

// Searches for the item and the group of the dynamic list filter by the passed field name or presentation.
//
// Parameters:
//  SearchArea - DataCompositionFilter
//                - DataCompositionFilterItemGroup    - a container with selection items and groups,
//                                                             such as a List.Selection or group in the selection.
//  FieldName       - String - a composition field name. Not applicable to groups.
//  Presentation - String - the composition field presentation.
//
// Returns:
//  Array - 
//
Function FindFilterItemsAndGroups(Val SearchArea,
									Val FieldName = Undefined,
									Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	Return ItemArray;
	
EndFunction

// Adds filter groups to ItemCollection.
//
// Parameters:
//  ItemsCollection - DataCompositionFilter
//                     - DataCompositionFilterItemGroup    - a container with selection items and groups,
//                                                                  such as a List.Selection or group in the selection.
//  Presentation      - String - group presentation.
//  GroupType          - DataCompositionFilterItemsGroupType - the group type.
//
// Returns:
//  DataCompositionFilterItemGroup - 
//
Function CreateFilterItemGroup(Val ItemsCollection, Presentation, GroupType) Export
	
	If TypeOf(ItemsCollection) = Type("DataCompositionFilterItemGroup")
		Or TypeOf(ItemsCollection) = Type("DataCompositionFilter") Then
		
		ItemsCollection = ItemsCollection.Items;
	EndIf;
	
	FilterItemsGroup = FindFilterItemByPresentation(ItemsCollection, Presentation);
	If FilterItemsGroup = Undefined Then
		FilterItemsGroup = ItemsCollection.Add(Type("DataCompositionFilterItemGroup"));
	Else
		FilterItemsGroup.Items.Clear();
	EndIf;
	
	FilterItemsGroup.Presentation    = Presentation;
	FilterItemsGroup.Application       = DataCompositionFilterApplicationType.Items;
	FilterItemsGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemsGroup.GroupType        = GroupType;
	FilterItemsGroup.Use    = True;
	
	Return FilterItemsGroup;
	
EndFunction

// Adds a composition item into a composition item container.
//
// Parameters:
//  AreaToAddTo - DataCompositionFilter
//                    - DataCompositionFilterItemGroup - a container with selection elements and groups,
//                                                              such as a List.Selection or group in the selection.
//  FieldName                 - String - a data composition field name. Required.
//  Var_ComparisonType            - DataCompositionComparisonType - comparison type.
//  RightValue          - Arbitrary - the value to compare to.
//  Presentation           - String - presentation of the data composition item.
//  Use           - Boolean - Item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID
//                                                    in Syntax Assistant.
// Returns:
//  DataCompositionFilterItem - 
//
Function AddCompositionItem(AreaToAddTo,
									Val FieldName,
									Val Var_ComparisonType,
									Val RightValue = Undefined,
									Val Presentation  = Undefined,
									Val Use  = Undefined,
									Val ViewMode = Undefined,
									Val UserSettingID = Undefined) Export
	
	Item = AreaToAddTo.Items.Add(Type("DataCompositionFilterItem"));
	Item.LeftValue = New DataCompositionField(FieldName);
	Item.ComparisonType = Var_ComparisonType;
	
	If ViewMode = Undefined Then
		Item.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Else
		Item.ViewMode = ViewMode;
	EndIf;
	
	If RightValue <> Undefined Then
		Item.RightValue = RightValue;
	EndIf;
	
	If Presentation <> Undefined Then
		Item.Presentation = Presentation;
	EndIf;
	
	If Use <> Undefined Then
		Item.Use = Use;
	EndIf;
	
	// 
	// 
	// 
	If UserSettingID <> Undefined Then
		Item.UserSettingID = UserSettingID;
	ElsIf Item.ViewMode <> DataCompositionSettingsItemViewMode.Inaccessible Then
		Item.UserSettingID = FieldName;
	EndIf;
	
	Return Item;
	
EndFunction

// Changes the filter item with the specified field name or presentation.
//
// Parameters:
//  SearchArea - DataCompositionFilter
//                - DataCompositionFilterItemGroup - a container with selection items and groups,
//                                                          such as a List.Selection or group in the selection.
//  FieldName                 - String - a data composition field name. Required.
//  Presentation           - String - presentation of the data composition item.
//  RightValue          - Arbitrary - the value to compare to.
//  Var_ComparisonType            - DataCompositionComparisonType - comparison type.
//  Use           - Boolean - Item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID
//                                                    in Syntax Assistant.
//
// Returns:
//  Number - 
//
Function ChangeFilterItems(SearchArea,
								Val FieldName = Undefined,
								Val Presentation = Undefined,
								Val RightValue = Undefined,
								Val Var_ComparisonType = Undefined,
								Val Use = Undefined,
								Val ViewMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item In ItemArray Do
		If FieldName <> Undefined Then
			Item.LeftValue = New DataCompositionField(FieldName);
		EndIf;
		If Presentation <> Undefined Then
			Item.Presentation = Presentation;
		EndIf;
		If Use <> Undefined Then
			Item.Use = Use;
		EndIf;
		If Var_ComparisonType <> Undefined Then
			Item.ComparisonType = Var_ComparisonType;
		EndIf;
		If RightValue <> Undefined Then
			Item.RightValue = RightValue;
		EndIf;
		If ViewMode <> Undefined Then
			Item.ViewMode = ViewMode;
		EndIf;
		If UserSettingID <> Undefined Then
			Item.UserSettingID = UserSettingID;
		EndIf;
	EndDo;
	
	Return ItemArray.Count();
	
EndFunction

// Deletes filter items that contain the given field name or presentation.
//
// Parameters:
//  AreaToDelete - DataCompositionFilterItemCollection - a container with items and filter groups.
//                                                               For example, List.Filter or a group in a filter..
//  FieldName         - String - a composition field name. Not applicable to groups.
//  Presentation   - String - the composition field presentation.
//
Procedure DeleteFilterItems(Val AreaToDelete, Val FieldName = Undefined, Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array; // Array of DataCompositionFilterItem, DataCompositionFilterItemGroup
	
	FindRecursively(AreaToDelete.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item In ItemArray Do
		If Item.Parent = Undefined Then
			AreaToDelete.Items.Delete(Item);
		Else
			Item.Parent.Items.Delete(Item);
		EndIf;
	EndDo;
	
EndProcedure

// Adds or replaces the existing filter item.
//
// Parameters:
//  WhereToAdd - DataCompositionFilter
//                          - DataCompositionFilterItemGroup - a container with selection elements and groups,
//                                     such as a List.Selection or group in the selection.
//  FieldName                 - String - a data composition field name. Required.
//  RightValue          - Arbitrary - the value to compare to.
//  Var_ComparisonType            - DataCompositionComparisonType - comparison type.
//  Presentation           - String - presentation of the data composition item.
//  Use           - Boolean - Item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID
//                                                    in Syntax Assistant.
//
Procedure SetFilterItem(WhereToAdd,
								Val FieldName,
								Val RightValue = Undefined,
								Val Var_ComparisonType = Undefined,
								Val Presentation = Undefined,
								Val Use = Undefined,
								Val ViewMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	ModifiedCount = ChangeFilterItems(WhereToAdd, FieldName, Presentation,
		RightValue, Var_ComparisonType, Use, ViewMode, UserSettingID);
	
	If ModifiedCount = 0 Then
		If Var_ComparisonType = Undefined Then
			If TypeOf(RightValue) = Type("Array")
				Or TypeOf(RightValue) = Type("FixedArray")
				Or TypeOf(RightValue) = Type("ValueList") Then
				Var_ComparisonType = DataCompositionComparisonType.InList;
			Else
				Var_ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
		EndIf;
		If ViewMode = Undefined Then
			ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
		AddCompositionItem(WhereToAdd, FieldName, Var_ComparisonType,
			RightValue, Presentation, Use, ViewMode, UserSettingID);
	EndIf;
	
EndProcedure

// Adds or replaces a filter item of a dynamic list.
//
// Parameters:
//   DynamicList - DynamicList - the list to be filtered.
//   FieldName            - String - the field the filter to apply to.
//   RightValue     - Arbitrary - the filter value.
//       Optional. The default value is Undefined.
//       Warning! If Undefined is passed, the value will not be changed.
//   Var_ComparisonType  - DataCompositionComparisonType - a filter condition.
//   Presentation - String - presentation of the data composition item.
//       Optional. The default value is Undefined.
//       If another value is specified, only the presentation flag is shown, not the value.
//       To show the value, pass an empty string.
//   Use - Boolean - the flag that indicates whether to apply the filter.
//       Optional. The default value is Undefined.
//   ViewMode - DataCompositionSettingsItemViewMode - the filter display
//                                                                          mode:
//        DataCompositionSettingItemDisplayMode.QuickAccess - in the Quick Settings bar on top of the list.
//        DataCompositionSettingItemDisplayMode.Normal       - in the list settings (submenu More).
//        DataCompositionSettingItemDisplayMode.Inaccessible   - prevent users from changing the filter.
//   UserSettingID - String - the filter UUID.
//       Used to link user settings.
//
Procedure SetDynamicListFilterItem(DynamicList, FieldName,
	RightValue = Undefined,
	Var_ComparisonType = Undefined,
	Presentation = Undefined,
	Use = Undefined,
	ViewMode = Undefined,
	UserSettingID = Undefined) Export
	
	If ViewMode = Undefined Then
		ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		DynamicListFilter = DynamicList.SettingsComposer.FixedSettings.Filter;
	Else
		DynamicListFilter = DynamicList.SettingsComposer.Settings.Filter;
	EndIf;
	
	SetFilterItem(
		DynamicListFilter,
		FieldName,
		RightValue,
		Var_ComparisonType,
		Presentation,
		Use,
		ViewMode,
		UserSettingID);
	
EndProcedure

// Deletes a filter group item of a dynamic list.
//
// Parameters:
//  DynamicList - DynamicList - the form attribute whose filter is to be modified.
//  FieldName         - String - a composition field name. Not applicable to groups.
//  Presentation   - String - the composition field presentation.
//
Procedure DeleteDynamicListFilterGroupItems(DynamicList, FieldName = Undefined, Presentation = Undefined) Export
	
	DeleteFilterItems(
		DynamicList.SettingsComposer.FixedSettings.Filter,
		FieldName,
		Presentation);
	
	DeleteFilterItems(
		DynamicList.SettingsComposer.Settings.Filter,
		FieldName,
		Presentation);
	
EndProcedure

// Sets or modifies the ParameterName parameter of the List dynamic list.
//
// Parameters:
//  List          - DynamicList - the form attribute whose parameter is to be modified.
//  ParameterName    - String             - name of the dynamic list parameter.
//  Value        - Arbitrary        - new value of the parameter.
//  Use   - Boolean             - flag indicating whether the parameter is used.
//
Procedure SetDynamicListParameter(List, ParameterName, Value, Use = True) Export
	
	DataCompositionParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If DataCompositionParameterValue <> Undefined Then
		If Use And DataCompositionParameterValue.Value <> Value Then
			DataCompositionParameterValue.Value = Value;
		EndIf;
		If DataCompositionParameterValue.Use <> Use Then
			DataCompositionParameterValue.Use = Use;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FilesOperations

////////////////////////////////////////////////////////////////////////////////
// File management functions.
//

// Adds the trailing separator to the passed directory path if it is missing.
//
// Parameters:
//  DirectoryPath - String - directory path.
//  Delete1CEnterprise - PlatformType - this parameter is deprecated and is no longer used.
//
// Returns:
//  String
//
// Example:
//  Result = AddFinalPathSeparator("C:\My directory"); // Returns "C:\My directory\".
//  Result = AddFinalPathSeparator("C:\My directory\"); // Returns "C:\My directory\".
//  Result = AddFinalPathSeparator("%APPDATA%"); // Returns "%APPDATA%\".
//
Function AddLastPathSeparator(Val DirectoryPath, Val Delete1CEnterprise = Undefined) Export
	If IsBlankString(DirectoryPath) Then
		Return DirectoryPath;
	EndIf;
	
	CharToAdd = GetPathSeparator();
	
	If StrEndsWith(DirectoryPath, CharToAdd) Then
		Return DirectoryPath;
	Else 
		Return DirectoryPath + CharToAdd;
	EndIf;
EndFunction

// Generates the full path to a file from the directory path and the file name.
//
// Parameters:
//  DirectoryName  - String - the path to the directory that contains the file.
//  FileName     - String - the file name.
//
// Returns:
//   String
//
Function GetFullFileName(Val DirectoryName, Val FileName) Export

	If Not IsBlankString(FileName) Then
		
		Slash = "";
		If (Right(DirectoryName, 1) <> "\") And (Right(DirectoryName, 1) <> "/") Then
			Slash = ?(StrFind(DirectoryName, "\") = 0, "/", "\");
		EndIf;
		
		Return DirectoryName + Slash + FileName;
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

// Splits a full file path into parts.
//
// Parameters:
//  FullFileName - String - the full path to a file or folder.
//  IsDirectory - Boolean - Indicates that the directory name is passed.
//
// Returns:
//   Structure - 
//     
//     
//     
//     
//     
// 
// Example:
//  FullFileName = "c:\temp\test.txt";
//  FileNameParts = ParseFullFileName(FullFileName);
//  
//  As a result, the field structure will be filled in as follows:
//    FullName: "c:\temp\test.txt",
//    Path: "c:\temp\",
//    Name: "test.txt",
//    Extension: ".txt",
//    BaseName: "test".
//
Function ParseFullFileName(Val FullFileName, IsDirectory = False) Export
	
	FileNameStructure = New Structure("FullName,Path,Name,Extension,BaseName");
	FillPropertyValues(FileNameStructure, New File(FullFileName));
	
	If FileNameStructure.Path = GetPathSeparator() Then
		FileNameStructure.Path = "";
	EndIf;
	
	Return FileNameStructure;
	
EndFunction

// 
//
// Parameters:
//  String - String - the source string.
//
// Returns:
//  Array of String
//
Function ParseStringByDotsAndSlashes(Val String) Export
	
	Var CurrentPosition;
	
	Particles = New Array;
	
	StartPosition = 1;
	
	For CurrentPosition = 1 To StrLen(String) Do
		CurrentChar = Mid(String, CurrentPosition, 1);
		If CurrentChar = "." Or CurrentChar = "/" Or CurrentChar = "\" Then
			CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
			StartPosition = CurrentPosition + 1;
			Particles.Add(CurrentFragment);
		EndIf;
	EndDo;
	
	If StartPosition <> CurrentPosition Then
		CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
		Particles.Add(CurrentFragment);
	EndIf;
	
	Return Particles;
	
EndFunction

// Returns the file extension.
//
// Parameters:
//  FileName - String - the file name (with or without the directory).
//
// Returns:
//   String
//
Function GetFileNameExtension(Val FileName) Export
	
	FileExtention = "";
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		FileExtention = RowsArray[RowsArray.Count() - 1];
	EndIf;
	Return FileExtention;
	
EndFunction

// Converts the file extension to lower case (without the dot).
//
// Parameters:
//  Extension - String - the file extension.
//
// Returns:
//  String
//
Function ExtensionWithoutPoint(Val Extension) Export
	
	Extension = Lower(TrimAll(Extension));
	
	If Mid(Extension, 1, 1) = "." Then
		Extension = Mid(Extension, 2);
	EndIf;
	
	Return Extension;
	
EndFunction

// Returns the file name with extension.
// If the extension is blank, the dot (.) is not added.
//
// Parameters:
//  BaseName - String - the file name without extension.
//  Extension       - String - extension.
//
// Returns:
//  String
//
Function GetNameWithExtension(BaseName, Extension) Export
	
	If IsBlankString(Extension) Then
		Return BaseName;
	EndIf;
	
	Return BaseName + "." + Extension;
	
EndFunction

// Returns a string of illegal file name characters.
// See the list of symbols on https://en.wikipedia.org/wiki/Filename#Reserved_characters_and_words.
// 
// Returns:
//   String
//
Function GetProhibitedCharsInFileName() Export

	InvalidChars = """/\[]:;|=?*<>";
	InvalidChars = InvalidChars + Chars.Tab + Chars.LF;
	Return InvalidChars;

EndFunction

// Checks whether the file name contains illegal characters.
//
// Parameters:
//  FileName  - String - file name.
//
// Returns:
//   Array of String  - 
//                       
//
Function FindProhibitedCharsInFileName(FileName) Export

	InvalidChars = GetProhibitedCharsInFileName();
	
	FoundProhibitedCharsArray = New Array;
	
	For CharPosition = 1 To StrLen(InvalidChars) Do
		CharToCheck = Mid(InvalidChars,CharPosition,1);
		If StrFind(FileName,CharToCheck) <> 0 Then
			FoundProhibitedCharsArray.Add(CharToCheck);
		EndIf;
	EndDo;
	
	Return FoundProhibitedCharsArray;

EndFunction

// Replaces illegal characters in a file name to legal characters.
//
// Parameters:
//  FileName     - String - an input file name.
//  WhatReplaceWith  - String - the string to substitute an illegal character.
//
// Returns:
//   String
//
Function ReplaceProhibitedCharsInFileName(Val FileName, WhatReplaceWith = " ") Export
	
	Return TrimAll(StrConcat(StrSplit(FileName, GetProhibitedCharsInFileName(), True), WhatReplaceWith));

EndFunction

#EndRegion

#Region EmailAddressesOperations

////////////////////////////////////////////////////////////////////////////////
// Email address management functions.
//

// Parses through a string of email addresses. Validates the addresses.
//
// Parameters:
//  AddressesList - String -
//                           
//
// Returns:
//  Array of Structure:
//   * Alias      - String - Addressee presentation.
//   * Address          - String - An email address that complies with the requirements.
//                               If an email-like string is found, that doesn't comply the requirements, it is set as "Alias".
//                               
//   * ErrorDescription - String - Error text presentation. If no errors are found, empty string.
//
Function EmailsFromString(Val AddressesList) Export
	
	Result = New Array;
	BracketChars = "()[]";
	AddressesList = StrConcat(StrSplit(AddressesList, BracketChars + " ", False), " ");
	AddressesList = StrReplace(AddressesList, ">", ">;");
	
	For Each String In StrSplit(AddressesList, ";", False) Do
		PresentationParts = New Array;
		For Each AddressWithAView In StrSplit(TrimAll(String), ",", False) Do
			If Not ValueIsFilled(AddressWithAView) Then
				PresentationParts.Add(AddressWithAView);
				Continue;
			EndIf;
			
			StringParts1 = StrSplit(TrimR(AddressWithAView), " ", True);
			Address = TrimAll(StringParts1[StringParts1.UBound()]);
			Alias = "";
			ErrorDescription = "";
			
			If StrFind(Address, "@") Or StrFind(Address, "<") Or StrFind(Address, ">") Then
				Address = StrConcat(StrSplit(Address, "<>", False), "");
				If EmailAddressMeetsRequirements(Address) Then
					StringParts1.Delete(StringParts1.UBound());
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr(
						"en = 'Invalid email address: %1.';"), Address);
					Address = "";
				EndIf;
				
				Alias = TrimAll(StrConcat(PresentationParts, ",") + StrConcat(StringParts1, " "));
				PresentationParts.Clear();
				AddressStructure1 = New Structure("Alias, Address, ErrorDescription", Alias, Address, ErrorDescription);
				Result.Add(AddressStructure1);
			Else
				PresentationParts.Add(AddressWithAView);
			EndIf;
		EndDo;
		
		Alias = StrConcat(PresentationParts, ",");
		If ValueIsFilled(Alias) Then
			Address = "";
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Invalid email address: %1.';"), Alias);
			AddressStructure1 = New Structure("Alias, Address, ErrorDescription", Alias, Address, ErrorDescription);
			Result.Add(AddressStructure1);
		EndIf;
	EndDo;
		
	Return Result;
	
EndFunction

// Checks whether the email address meets the RFC 5321, RFC 5322, RFC 5335, RFC 5336,
// and RFC 5336 requirements.
// Also, restricts the usage of special symbols.
// 
// Parameters:
//  Address - String - an email to check.
//  AllowLocalAddresses - Boolean - do not raise an error if the email address is missing a domain.
//
// Returns:
//  Boolean - 
//
Function EmailAddressMeetsRequirements(Val Address, AllowLocalAddresses = False) Export
	
	// Symbols that are allowed in email addresses.
	Letters = "abcdefghijklmnopqrstuvwxyz";
	Digits = "0123456789";
	SpecialChars = ".@_-:+";
	
	// Check if the string has an "at" sign ( @ ).
	If StrOccurrenceCount(Address, "@") <> 1 Then
		Return False;
	EndIf;
	
	// Allowing only one column.
	If StrOccurrenceCount(Address, ":") > 1 Then
		Return False;
	EndIf;
	
	// Checking for double dots.
	If StrFind(Address, "..") > 0 Then
		Return False;
	EndIf;
	
	// 
	Address = Lower(Address);
	
	// Checking for illegal symbols.
	If Not StringContainsAllowedCharsOnly(Address, Letters + Digits + SpecialChars) Then
		Return False;
	EndIf;
	
	// Splitting the address into a local part and domain.
	Position = StrFind(Address,"@");
	LocalName = Left(Address, Position - 1);
	Domain = Mid(Address, Position + 1);
	
	// Checking whether LocalName and Domain are filled and meet the length requirements.
	If IsBlankString(LocalName)
	 	Or IsBlankString(Domain)
		Or StrLen(LocalName) > 64
		Or StrLen(Domain) > 255 Then
		
		Return False;
	EndIf;
	
	// Checking whether there are any special characters at the beginning and at the end of LocalName and Domain.

	If HasCharsLeftRight(Domain, SpecialChars) Then
		Return False;
	EndIf;
	
	// A domain must contain at least one dot.
	If Not AllowLocalAddresses And StrFind(Domain,".") = 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain underscores (_).
	If StrFind(Domain,"_") > 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain colons (:).
	If StrFind(Domain,":") > 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain plus signs.
	If StrFind(Domain,"+") > 0 Then
		Return False;
	EndIf;
	
	// Extracting a top-level domain (TLD) from the domain name.
	Zone = Domain;
	Position = StrFind(Zone,".");
	While Position > 0 Do
		Zone = Mid(Zone, Position + 1);
		Position = StrFind(Zone,".");
	EndDo;
	
	// 
	Return AllowLocalAddresses Or StrLen(Zone) >= 2 And StringContainsAllowedCharsOnly(Zone,Letters);
	
EndFunction

// 
//
// 
//  
// 
//  
//
// Parameters:
//  Addresses - String - the correct string with the email addresses.
//  RaiseException1 - Boolean -
//
// Returns:
//  Array of Structure:
//   * Address - String - Send-to email.
//   * Presentation - String - Recipient name.
//
Function ParseStringWithEmailAddresses(Val Addresses, RaiseException1 = True) Export
	
	Result = New Array;
	ErrorsDetails = New Array;
	SMSMessageRecipients = EmailsFromString(Addresses);
	
	For Each Addressee In SMSMessageRecipients Do
		If ValueIsFilled(Addressee.ErrorDescription) Then
			ErrorsDetails.Add(Addressee.ErrorDescription);
		EndIf;
		
		Result.Add(New Structure("Address, Presentation", Addressee.Address, Addressee.Alias));
	EndDo;
	
	If RaiseException1 And ValueIsFilled(ErrorsDetails) Then
		ErrorText = StrConcat(ErrorsDetails, Chars.LF);
		Raise ErrorText;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ExternalConnection

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external connections.

// Returns the name of the COM class to operate 1C:Enterprise over a COM connection.
//
// Returns:
//  String
//
Function COMConnectorName() Export
	
	SystemData = New SystemInfo;
	VersionSubstrings = StrSplit(SystemData.AppVersion, ".");
	Return "v" + VersionSubstrings[0] + VersionSubstrings[1] + ".COMConnector";
	
EndFunction

// 
// 
// 
// Returns:
//  Structure:
//    * InfobaseOperatingMode - Number -
//    * InfobaseDirectory - String -
//    * NameOf1CEnterpriseServer - String -
//    * NameOfInfobaseOn1CEnterpriseServer - String - 
//    * OperatingSystemAuthentication - Boolean -
//                                          
//    * UserName - String -
//    * UserPassword - String -
//
Function ParametersStructureForExternalConnection() Export
	
	Result = New Structure;
	Result.Insert("InfobaseOperatingMode", 0);
	Result.Insert("InfobaseDirectory", "");
	Result.Insert("NameOf1CEnterpriseServer", "");
	Result.Insert("NameOfInfobaseOn1CEnterpriseServer", "");
	Result.Insert("OperatingSystemAuthentication", False);
	Result.Insert("UserName", "");
	Result.Insert("UserPassword", "");
	
	Return Result;
	
EndFunction

// Extracts connection parameters from the infobase connection string
// and passes parameters to structure for setting external connections.
//
// Parameters:
//  ConnectionString - String - an infobase connection string.
// 
// Returns:
//   See ParametersStructureForExternalConnection
//
Function GetConnectionParametersFromInfobaseConnectionString(Val ConnectionString) Export
	
	Result = ParametersStructureForExternalConnection();
	
	Parameters = StringFunctionsClientServer.ParametersFromString(ConnectionString);
	
	Parameters.Property("File", Result.InfobaseDirectory);
	Parameters.Property("Srvr", Result.NameOf1CEnterpriseServer);
	Parameters.Property("Ref",  Result.NameOfInfobaseOn1CEnterpriseServer);
	
	Result.InfobaseOperatingMode = ?(Parameters.Property("File"), 0, 1);
	
	Return Result;
	
EndFunction

#EndRegion

#Region Math

////////////////////////////////////////////////////////////////////////////////
// Math procedures and functions.

// Distributes the amount according
// to the specified distribution ratios.
//
// Parameters:
//  AmountToDistribute - Number  - the amount to distribute. If set to 0, returns Undefined;
//                                 If set to a negative value, absolute value is calculated and then its sign is inverted.
//  Coefficients        - Array - distribution coefficients. All coefficients must be positive, or all coefficients must be negative
//  Accuracy            - Number  - rounding accuracy during distribution. Optional.
//
// Returns:
//  Array - 
//           
//           
//           
//           
//
// Example:
//
//	Coefficients = New Array;
//	Coefficients.Add(1);
//	Coefficients.Add(2);
//	Result = CommonClientServer.DistributeAmountInProportionToCoefficients(1, Coefficients);
//	// Result = [0.33, 0.67]
//
Function DistributeAmountInProportionToCoefficients(Val AmountToDistribute, Val Coefficients, Val Accuracy = 2) Export
	
	AbsoluteCoefficients = New Array(New FixedArray(Coefficients)); // 
	
	// Keeping the old behavior in event of unspecified amount, for backward compatibility.
	If Not ValueIsFilled(AmountToDistribute) Then 
		Return Undefined;
	EndIf;
	
	If AbsoluteCoefficients.Count() = 0 Then 
		// 
		// 
		Return Undefined;
	EndIf;
	
	MaxCoefficientIndex = 0;
	MaxCoefficient = 0;
	CoefficientsSum = 0;
	NegativeCoefficients = (AbsoluteCoefficients[0] < 0);
	
	For IndexOf = 0 To AbsoluteCoefficients.Count() - 1 Do
		ZoomRatio = AbsoluteCoefficients[IndexOf];
		
		If NegativeCoefficients And ZoomRatio > 0 Then 
			// 
			// 
			Return Undefined;
		EndIf;
		
		If ZoomRatio < 0 Then 
			// 
			ZoomRatio = -ZoomRatio; // Abs(Коэффициент)
			AbsoluteCoefficients[IndexOf] = ZoomRatio; // 
		EndIf;
		
		If MaxCoefficient < ZoomRatio Then
			MaxCoefficient = ZoomRatio;
			MaxCoefficientIndex = IndexOf;
		EndIf;
		
		CoefficientsSum = CoefficientsSum + ZoomRatio;
	EndDo;
	
	If CoefficientsSum = 0 Then
		// 
		// 
		Return Undefined;
	EndIf;
	
	Result = New Array(AbsoluteCoefficients.Count());
	
	Invert = (AmountToDistribute < 0);
	If Invert Then 
		// 
		// 
		AmountToDistribute = -AmountToDistribute; // Abs(РаспределяемаяСумма).
	EndIf;
	
	DistributedAmount = 0;
	
	For IndexOf = 0 To AbsoluteCoefficients.Count() - 1 Do
		Result[IndexOf] = Round(AmountToDistribute * AbsoluteCoefficients[IndexOf] / CoefficientsSum, Accuracy, 1);
		DistributedAmount = DistributedAmount + Result[IndexOf];
	EndDo;
	
	CombinedInaccuracy = AmountToDistribute - DistributedAmount;
	
	If CombinedInaccuracy > 0 Then 
		
		// Adding the round-off error to the ratio with the maximum weight.
		If Not DistributedAmount = AmountToDistribute Then
			Result[MaxCoefficientIndex] = Result[MaxCoefficientIndex] + CombinedInaccuracy;
		EndIf;
		
	ElsIf CombinedInaccuracy < 0 Then 
		
		// Spreading the inaccuracy to the nearest maximum weights if the distributed amount is too large.
		InaccuracyValue = 1 / Pow(10, Accuracy);
		InaccuracyItemCount = -CombinedInaccuracy / InaccuracyValue;
		
		For Cnt = 1 To InaccuracyItemCount Do 
			MaxCoefficient = MaxValueInArray(AbsoluteCoefficients);
			IndexOf = AbsoluteCoefficients.Find(MaxCoefficient);
			Result[IndexOf] = Result[IndexOf] - InaccuracyValue;
			AbsoluteCoefficients[IndexOf] = 0;
		EndDo;
		
	Else 
		// If CombinedInaccuracy = 0, everything is OK.
	EndIf;
	
	If Invert Then 
		For IndexOf = 0 To AbsoluteCoefficients.Count() - 1 Do
			Result[IndexOf] = -Result[IndexOf];
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region XMLSerialization

// Replaces illegal characters in the XML string with the specified characters.
//
// Parameters:
//   Text - String - the string where invalid characters need to be replaced.
//   ReplacementChar - String - the string to be used instead of the invalid character in XML string.
// 
// Returns:
//    String
//
Function ReplaceProhibitedXMLChars(Val Text, ReplacementChar = " ") Export
	
#If Not WebClient Then
	StartPosition = 1;
	Position = FindDisallowedXMLCharacters(Text, StartPosition);
	While Position > 0 Do
		InvalidChar = Mid(Text, Position, 1);
		Text = StrReplace(Text, InvalidChar, ReplacementChar);
		StartPosition = Position + StrLen(ReplacementChar);
		If StartPosition > StrLen(Text) Then
			Break;
		EndIf;
		Position = FindDisallowedXMLCharacters(Text, StartPosition);
	EndDo;
	
	Return Text;
#Else
	// 
	// 
	Total = "";
	StringLength = StrLen(Text);
	
	For CharacterNumber = 1 To StringLength Do
		Char = Mid(Text, CharacterNumber, 1);
		CharCode = CharCode(Char);
		
		If CharCode < 9
		 Or CharCode > 10    And CharCode < 13
		 Or CharCode > 13    And CharCode < 32
		 Or CharCode > 55295 And CharCode < 57344 Then
			
			Char = ReplacementChar;
		EndIf;
		Total = Total + Char;
	EndDo;
	
	Return Total;
#EndIf
	
EndFunction

// Deletes illegal characters from the XML string.
//
// Parameters:
//  Text - String - the string where invalid characters need to be replaced.
// 
// Returns:
//  String
//
Function DeleteDisallowedXMLCharacters(Val Text) Export
	
	Return ReplaceProhibitedXMLChars(Text, "");
	
EndFunction

#EndRegion

#Region SpreadsheetDocument

// 
//
// Parameters:
//  SpreadsheetDocumentField - FormField - a SpreadsheetDocumentField type form field
//                            that requires the state change.
//  State               - String -
//
Procedure SetSpreadsheetDocumentFieldState(SpreadsheetDocumentField, State = "DontUse") Export
	
	If TypeOf(SpreadsheetDocumentField) = Type("FormField") 
		And SpreadsheetDocumentField.Type = FormFieldType.SpreadsheetDocumentField Then
		StatePresentation = SpreadsheetDocumentField.StatePresentation;
		If Upper(State) = "DONTUSE" Then
			StatePresentation.Visible                      = False;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = "";
		ElsIf Upper(State) = "IRRELEVANCE" Then
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = NStr("en = 'To run report, click ""Generate"".';");
		ElsIf Upper(State) = "REPORTGENERATION" Then  
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = PictureLib.TimeConsumingOperation48;
			StatePresentation.Text                          = NStr("en = 'Generating report…';");
		Else
			CheckParameter(
				"CommonClientServer.SetSpreadsheetDocumentFieldState", "State", State, 
				Type("String"),, "DontUse,Irrelevance,ReportGeneration");
		EndIf;
	Else
		CheckParameter(
			"CommonClientServer.SetSpreadsheetDocumentFieldState", "SpreadsheetDocumentField", 
			SpreadsheetDocumentField, Type("FormField"));
		Validate(SpreadsheetDocumentField.Type = FormFieldType.SpreadsheetDocumentField,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value of the %1 parameter in %2.
				           |Expected value: %3, passed value: %4 (type: %5).';"),
				"SpreadsheetDocumentField", "CommonClientServer.SetSpreadsheetDocumentFieldState", 
				"FormFieldType.SpreadsheetDocumentField", SpreadsheetDocumentField.Type, TypeOf(SpreadsheetDocumentField.Type)));	
	EndIf;
	
EndProcedure

// Calculates indicators of numeric cells in a spreadsheet document.
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - the document whose numerical indicators are calculated.
//  SpreadsheetDocumentField - FormField
//                          - SpreadsheetDocumentField - 
//                            
//  CalculationParameters - Undefined
//                   - See CellsIndicatorsCalculationParameters
//
// Returns:
//   Structure:
//       * Count         - Number - selected cells count.
//       * NumericCellsCount - Number - numeric cells count.
//       * Sum      - Number - a sum of the selected cells with numbers.
//       * Mean    - Number - a sum of the selected cells with numbers.
//       * Minimum    - Number - a sum of the selected cells with numbers.
//       * Maximum   - Number - a sum of the selected cells with numbers.
//
Function CalculationCellsIndicators(Val SpreadsheetDocument, Val SpreadsheetDocumentField, CalculationParameters = Undefined) Export 
	
	If CalculationParameters = Undefined Then 
		CalculationParameters = CellsIndicatorsCalculationParameters(SpreadsheetDocumentField);
	EndIf;
	
	If CalculationParameters.CalculateAtServer Then 
		Return StandardSubsystemsServerCall.CalculationCellsIndicators(
			SpreadsheetDocument, CalculationParameters.SelectedAreas);
	EndIf;
	
	Return CommonInternalClientServer.CalculationCellsIndicators(
		SpreadsheetDocument, CalculationParameters.SelectedAreas);
	
EndFunction

// Generates the selected area details of the spreadsheet document.
//
// Parameters:
//  SpreadsheetDocumentField - FormField
//                          - SpreadsheetDocumentField - 
//                            
//
// Returns: 
//   Structure:
//     * SelectedAreas - Array - contains structures with the following properties:
//         * Top  - Number - a row number of the upper area boun.
//         * Bottom   - Number - a row number of the lower area bound.
//         * Left  - Number - a column number of the upper area bound.
//         * Right - Number - a column number of the lower area bound.
//         * AreaType - SpreadsheetDocumentCellAreaType - Columns, Rectangle, Rows, Table.
//     * CalculateAtServer - Boolean - Indicates that the calculation must be executed on the server
//                                      if the number of the selected cells is more than or equal to 1,000
//                                      or the number of the selected areas is more than or equal to 100,
//                                      or the whole spreadsheet document field is selected.
//                                      In these cases, calculating indicators on the client is very consuming. 
//
Function CellsIndicatorsCalculationParameters(SpreadsheetDocumentField) Export 
	
	IndicatorsCalculationParameters = New Structure;
	IndicatorsCalculationParameters.Insert("SelectedAreas", New Array);
	IndicatorsCalculationParameters.Insert("CalculateAtServer", False);
	
	SelectedAreas = IndicatorsCalculationParameters.SelectedAreas;
	SelectedDocumentAreas = SpreadsheetDocumentField.GetSelectedAreas();
	
	NumberOfSelectedCells = 0;
	
	For Each SelectedArea1 In SelectedDocumentAreas Do
		
		If TypeOf(SelectedArea1) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		AreaBoundaries = New Structure("Top, Bottom, Left, Right, AreaType");
		FillPropertyValues(AreaBoundaries, SelectedArea1);
		SelectedAreas.Add(AreaBoundaries);
		
		NumberOfSelectedCells = NumberOfSelectedCells
			+ (SelectedArea1.Right - SelectedArea1.Left + 1)
			* (SelectedArea1.Bottom - SelectedArea1.Top + 1);
		
	EndDo;
	
	SelectedAll = False;
	
	If SelectedAreas.Count() = 1 Then 
		
		SelectedArea1 = SelectedAreas[0];
		SelectedAll = Not Boolean(
			SelectedArea1.Top
			+ SelectedArea1.Bottom
			+ SelectedArea1.Left
			+ SelectedArea1.Right);
		
	EndIf;
	
	IndicatorsCalculationParameters.CalculateAtServer = (SelectedAll
		Or SelectedAreas.Count() >= 100
		Or NumberOfSelectedCells >= 1000);
	
	Return IndicatorsCalculationParameters;
	
EndFunction

#EndRegion

#Region ScheduledJobs

// Converts JobSchedule into a structure.
//
// Parameters:
//  Schedule - JobSchedule - a source schedule.
// 
// Returns:
//  Structure:
//    * CompletionTime          - Date
//    * EndTime               - Date
//    * BeginTime              - Date
//    * EndDate                - Date
//    * StartDate               - Date
//    * DayInMonth              - Date
//    * WeekDayInMonth        - Number
//    * WeekDays                - Number
//    * CompletionInterval       - Number
//    * Months                   - Array of Number
//    * RepeatPause             - Number
//    * WeeksPeriod             - Number
//    * RepeatPeriodInDay - Number
//    * DaysRepeatPeriod        - Number
//    * DetailedDailySchedules   - Array of See ScheduleToStructure 
//
Function ScheduleToStructure(Val Schedule) Export
	
	ScheduleValue = Schedule;
	If ScheduleValue = Undefined Then
		ScheduleValue = New JobSchedule();
	EndIf;
	FieldList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth,"
		+ "WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New Structure(FieldList);
	FillPropertyValues(Result, ScheduleValue, FieldList);
	DetailedDailySchedules = New Array;
	For Each DailySchedule In Schedule.DetailedDailySchedules Do
		DetailedDailySchedules.Add(ScheduleToStructure(DailySchedule));
	EndDo;
	Result.Insert("DetailedDailySchedules", DetailedDailySchedules);
	Return Result;
	
EndFunction

// Converts a structure intoJobSchedule.
//
// Parameters:
//  ScheduleStructure1 - Structure - the schedule in the form of structure.
// 
// Returns:
//  JobSchedule - schedule.
//
Function StructureToSchedule(Val ScheduleStructure1) Export
	
	If ScheduleStructure1 = Undefined Then
		Return New JobSchedule();
	EndIf;
	FieldList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth,"
		+ "WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New JobSchedule;
	FillPropertyValues(Result, ScheduleStructure1, FieldList);
	DetailedDailySchedules = New Array;
	For Each Schedule In ScheduleStructure1.DetailedDailySchedules Do
		DetailedDailySchedules.Add(StructureToSchedule(Schedule));
	EndDo;
	Result.DetailedDailySchedules = DetailedDailySchedules;  
	Return Result;
	
EndFunction

// Compares two schedules.
//
// Parameters:
//  Schedule1 - JobSchedule - the first schedule.
//  Schedule2 - JobSchedule - the second schedule.
//
// Returns:
//  Boolean - 
//
Function SchedulesAreIdentical(Val Schedule1, Val Schedule2) Export
	
	Return String(Schedule1) = String(Schedule2);
	
EndFunction

#EndRegion

#Region Internet

// Splits the URI string and returns it as a structure.
// The following normalizations are described based on RFC 3986.
//
// Parameters:
//  URIString1 - String - link to the resource in the following format:
//                       <schema>://<username>:<password>@<host>:<port>/<path>?<parameters>#<anchor>.
//
// Returns:
//  Structure - 
//   * Schema         - String - the URI schema.
//   * Login         - String - the username from the URI.
//   * Password        - String - the URI password.
//   * ServerName    - String - the <host>:<port> URI part.
//   * Host          - String - the URI host.
//   * Port          - String - the URI port.
//   * PathAtServer - String - the <path>?<parameters>#<anchor> URI part.
//
Function URIStructure(Val URIString1) Export
	
	URIString1 = TrimAll(URIString1);
	
	// Schema.
	Schema = "";
	Position = StrFind(URIString1, "://");
	If Position > 0 Then
		Schema = Lower(Left(URIString1, Position - 1));
		URIString1 = Mid(URIString1, Position + 3);
	EndIf;
	
	// Connection string and path on the server.
	ConnectionString = URIString1;
	PathAtServer = "";
	Position = StrFind(ConnectionString, "/");
	If Position > 0 Then
		PathAtServer = Mid(ConnectionString, Position + 1);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
	
	// User details and server name.
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = StrFind(ConnectionString, "@", SearchDirection.FromEnd);
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// Username and password.
	Login = AuthorizationString;
	Password = "";
	Position = StrFind(AuthorizationString, ":");
	If Position > 0 Then
		Login = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// The host and port.
	Host = ServerName;
	Port = "";
	Position = StrFind(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
		If Not StringFunctionsClientServer.OnlyNumbersInString(Port) Then
			Port = "";
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Schema);
	Result.Insert("Login", Login);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", ServerName);
	Result.Insert("Host", Host);
	Result.Insert("Port", ?(IsBlankString(Port), Undefined, Number(Port)));
	Result.Insert("PathAtServer", PathAtServer);
	
	Return Result;
	
EndFunction

// Creates a details object of the OpenSSL secure connection.
// See also the details of the OpenSSLSecureConnection object in the Syntax Assistant.
//
// Parameters:
//  ClientCertificate - FileClientCertificate
//                    - WindowsClientCertificate
//                    - Undefined - 
//  CertificationAuthorityCertificates - FileCertificationAuthorityCertificates
//                                   - WindowsCertificationAuthorityCertificates
//                                   - LinuxCertificationAuthorityCertificates
//                                   - OSCertificationAuthorityCertificates
//                                   - Undefined -  
//
// Returns:
//  OpenSSLSecureConnection
//
Function NewSecureConnection(ClientCertificate = Undefined, CertificationAuthorityCertificates = Undefined) Export
	
#If WebClient Then
	Return Undefined;
#ElsIf MobileClient Then 
	Return New OpenSSLSecureConnection;
#Else
	Return New OpenSSLSecureConnection(ClientCertificate, CertificationAuthorityCertificates);
#EndIf
	
EndFunction

#EndRegion

#Region DeviceParameters

// Returns a string presentation of the used device type.
//
// Returns:
//   String - 
//
Function DeviceType() Export
	
	DisplayInformation = DeviceDisplayParameters();
	
	DPI    = DisplayInformation.DPI; // ACC:1353 - 
	Height = DisplayInformation.Height;
	Width = DisplayInformation.Width;
	
	DisplaySize = Sqrt((Height/DPI*Height/DPI)+(Width/DPI*Width/DPI));
	If DisplaySize > 16 Then
		Return "PersonalComputer";
	ElsIf DisplaySize >= ?(DPI > 310, 7.85, 9) Then
		Return "Tablet";
	ElsIf DisplaySize >= 4.9 Then
		Return "Phablet";
	Else
		Return "Phone";
	EndIf;
	
EndFunction

// Returns display parameters of the device being used.
//
// Returns:
//   Structure:
//     * Width  - Number - display width in pixels.
//     * Height  - Number - display height in pixels.
//     * DPI     - Number - display pixel density.
//     * Portrait - Boolean - If the display is in portrait orientation, then it is True, otherwise False.
//
Function DeviceDisplayParameters() Export
	
	DisplayParameters1 = New Structure;
	DisplayInformation = GetClientDisplaysInformation();
	
	Width = DisplayInformation[0].Width;
	Height = DisplayInformation[0].Height;
	
	DisplayParameters1.Insert("Width",  Width);
	DisplayParameters1.Insert("Height",  Height);
	DisplayParameters1.Insert("DPI",     DisplayInformation[0].DPI);
	DisplayParameters1.Insert("Portrait", Height > Width);
	
	Return DisplayParameters1;
	
EndFunction

#EndRegion

#Region CheckingTheValueType

// Returns the flag indicating whether the passed value is a number.
//
// Parameters:
//  ValueToCheck - String - the value to be checked for compliance with the number.
//
// Returns:
//   Boolean - 
//
Function IsNumber(Val ValueToCheck) Export 
	
	If ValueToCheck = "0" Then
		Return True;
	EndIf;
	
	NumberDetails = New TypeDescription("Number");
	
	Return NumberDetails.AdjustValue(ValueToCheck) <> 0;
	
EndFunction

#EndRegion

#Region CastingAValue

// Casts a string value to the date.
//
// Parameters:
//  Value - String - a string value cast to the date.
//
// Returns:
//   Date - 
//
Function StringToDate(Val Value) Export 
	
	DateEmpty = Date(1, 1, 1);
	
	If Not ValueIsFilled(Value) Then 
		Return DateEmpty;
	EndIf;
	
	DateDetails = New TypeDescription("Date");
	Date = DateDetails.AdjustValue(Value);
	
	If TypeOf(Date) = Type("Date")
		And ValueIsFilled(Date) Then 
		
		Return Date;
	EndIf;
	
	#Region PreparingDateParts
	
	CharsCount = StrLen(Value);
	
	If CharsCount > 25 Then 
		Return DateEmpty;
	EndIf;
	
	PartsOfTheValue = New Array;
	PartOfTheValue = "";
	
	For CharacterNumber = 1 To CharsCount Do 
		
		Char = Mid(Value, CharacterNumber, 1);
		
		If IsNumber(Char) Then 
			
			PartOfTheValue = PartOfTheValue + Char;
			
		Else
			
			If Not IsBlankString(PartOfTheValue) Then 
				PartsOfTheValue.Add(PartOfTheValue);
			EndIf;
			
			PartOfTheValue = "";
			
		EndIf;
		
		If CharacterNumber = CharsCount
			And Not IsBlankString(PartOfTheValue) Then 
			
			PartsOfTheValue.Add(PartOfTheValue);
		EndIf;
		
	EndDo;
	
	If PartsOfTheValue.Count() < 3 Then 
		Return DateEmpty;
	EndIf;
	
	If PartsOfTheValue.Count() < 4 Then 
		PartsOfTheValue.Add("00");
	EndIf;
	
	If PartsOfTheValue.Count() < 5 Then 
		PartsOfTheValue.Add("00");
	EndIf;
	
	If PartsOfTheValue.Count() < 6 Then 
		PartsOfTheValue.Add("00");
	EndIf;
	
	#EndRegion
	
	// If the format is yyyyMMddXXmmss:
	NormalizedValue = PartsOfTheValue[2] + PartsOfTheValue[1] + PartsOfTheValue[0]
		+ PartsOfTheValue[3] + PartsOfTheValue[4] + PartsOfTheValue[5];
	
	Date = DateDetails.AdjustValue(NormalizedValue);
	
	If TypeOf(Date) = Type("Date")
		And ValueIsFilled(Date) Then 
		
		Return Date;
	EndIf;
	
	// 
	NormalizedValue = PartsOfTheValue[2] + PartsOfTheValue[0] + PartsOfTheValue[1]
		+ PartsOfTheValue[3] + PartsOfTheValue[4] + PartsOfTheValue[5];
	
	Date = DateDetails.AdjustValue(NormalizedValue);
	
	If TypeOf(Date) = Type("Date")
		And ValueIsFilled(Date) Then 
		
		Return Date;
	EndIf;
	
	Return DateEmpty;
	
EndFunction

#EndRegion

#Region ConvertDateForHTTP

// Converts a universal date into a rfc1123-date format.
// See https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html, cl. 3.3.1.
// 
// Parameters:
//  Date - Date
// 
// Returns:
//  String
//
// Example:
//  HTTPDate(Date(2021,12,9,9,14,58)) = "Thu, 09 Dec 2021 09:14:58 GMT".
//
Function HTTPDate(Val Date) Export
	
	WeekDays = StrSplit("Mon,Tue,Wed,Thu,Fri,Sat,Sun", ",");
	Months = StrSplit("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec", ",");
	
	DateTemplate = "[WeekDay], [Day] [Month] [Year] [Hour]:[Minute]:[Second] GMT"; // 
	
	DateParameters = New Structure;
	DateParameters.Insert("WeekDay", WeekDays[WeekDay(Date)-1]);
	DateParameters.Insert("Day", Format(Day(Date), "ND=2; NLZ="));
	DateParameters.Insert("Month", Months[Month(Date)-1]);
	DateParameters.Insert("Year", Format(Year(Date), "ND=4; NLZ=; NG=0"));
	DateParameters.Insert("Hour", Format(Hour(Date), "ND=2; NZ=00; NLZ="));
	DateParameters.Insert("Minute", Format(Minute(Date), "ND=2; NZ=00; NLZ="));
	DateParameters.Insert("Second", Format(Second(Date), "ND=2; NZ=00; NLZ="));
	
	HTTPDate = StringFunctionsClientServer.InsertParametersIntoString(DateTemplate, DateParameters);
	
	Return HTTPDate;
	
EndFunction

// Returns a date converted from rfc1123-date to Date data type.
// See https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html, item 3.3.1.
// 
// Parameters:
//  HTTPDateAsString - String
// 
// Returns:
//  Date
//
// Example:
//  RFC1123Date("Thu, 09 Dec 2021 09:14:58 GMT") = Date(2021,12,9,9,14,58).
//
Function RFC1123Date(HTTPDateAsString) Export

	MonthsNames = "janfebmaraprmayjunjulaugsepoctnovdec";
	// rfc1123-date = wkday "," SP date1 SP time SP "GMT".
	FirstSpacePosition = StrFind(HTTPDateAsString, " ");//
	SubstringDate = Mid(HTTPDateAsString,FirstSpacePosition + 1);
	SubstringTime = Mid(SubstringDate, 13);
	SubstringDate = Left(SubstringDate, 11);
	FirstSpacePosition = StrFind(SubstringTime, " ");
	SubstringTime = Left(SubstringTime,FirstSpacePosition - 1);
	// date1 = 2DIGIT SP month SP 4DIGIT.
	SubstringDay = Left(SubstringDate, 2);
	SubstringMonth = Format(Int(StrFind(MonthsNames,Lower(Mid(SubstringDate,4,3))) / 3)+1, "ND=2; NZ=00; NLZ=");
	SubstringYear = Mid(SubstringDate, 8);
	// time = 2DIGIT ":" 2DIGIT ":" 2DIGIT.
	SubstringHour = Left(SubstringTime, 2);
	SubstringMinute = Mid(SubstringTime, 4, 2);
	SubstringSecond = Right(SubstringTime, 2);
	
	Return Date(SubstringYear + SubstringMonth + SubstringDay + SubstringHour + SubstringMinute + SubstringSecond);
	
EndFunction

#EndRegion

#Region Other

// Removes one conditional appearance item if this is a value list.
// 
// Parameters:
//  ConditionalAppearance - DataCompositionConditionalAppearance - the form item conditional appearance;
//  UserSettingID - String - setting ID;
//  Value - Arbitrary -  the value to remove from the appearance list.
//
Procedure RemoveValueListConditionalAppearance(ConditionalAppearance, Val UserSettingID, 
	Val Value) Export
	
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = UserSettingID Then
			If ConditionalAppearanceItem.Filter.Items.Count() = 0 Then
				Return;
			EndIf;
			ItemFilterList = ConditionalAppearanceItem.Filter.Items[0];
			If ItemFilterList.RightValue = Undefined Then
				Return;
			EndIf;
			ListItem = ItemFilterList.RightValue.FindByValue(Value);
			If ListItem <> Undefined Then
				ItemFilterList.RightValue.Delete(ListItem);
			EndIf;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

// Gets an array of values containing marked items of the value list.
//
// Parameters:
//  List - ValueList - the list that provides values to form an array;
// 
// Returns:
//  Array - 
//
Function MarkedItems(List) Export
	
	// Function return value.
	Array = New Array;
	
	For Each Item In List Do
		
		If Item.Check Then
			
			Array.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return Array;
EndFunction

// Gets value tree row ID (GetID() method) for the specified tree
// row field value.
// Is used to determine the cursor position in hierarchical lists.
//
// Parameters:
//  FieldName - String - a name of the column in the value tree used for searching.
//  RowID - Number - value tree row ID returned by search.
//  TreeItemsCollection - FormDataTreeItemCollection - collection to search.
//  Composite - Arbitrary - the sought field value.
//  StopSearch - Boolean - flag indicating whether the search is to be stopped.
// 
Procedure GetTreeRowIDByFieldValue(FieldName, RowID, TreeItemsCollection, Composite, StopSearch) Export
	
	For Each TreeRow In TreeItemsCollection Do
		
		If StopSearch Then
			Return;
		EndIf;
		
		If TreeRow[FieldName] = Composite Then
			
			RowID = TreeRow.GetID();
			
			StopSearch = True;
			
			Return;
			
		EndIf;
		
		ItemsCollection = TreeRow.GetItems();
		
		If ItemsCollection.Count() > 0 Then
			
			GetTreeRowIDByFieldValue(FieldName, RowID, ItemsCollection, Composite, StopSearch);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Instead, use CommonClientServer.ArraysDifference
// Calculates the difference between arrays. The difference between array A and array B is an array that contains
// all elements from array A that are not present in array B.
//
// Parameters:
//  Array - Array - an array to subtract from;
//  SubtractionArray - Array - an array being subtracted.
// 
// Returns:
//  Array - 
//
Function ReduceArray(Array, SubtractionArray) Export
	
	Return ArraysDifference(Array, SubtractionArray);
	
EndFunction

// ACC:547-off An obsolete API can call obsolete procedures and functions.

// Deprecated. Instead, use CommonClient.InformUser or Common.InformUser.
// Generates and displays the message that can relate to a form item. 
// 
//
// Parameters:
//  MessageToUserText - String - message text.
//  DataKey                 - AnyRef - the infobase record key or object that message refers to.
//  Field                       - String - a form attribute description.
//  DataPath                - String - a data path (a path to a form attribute).
//  Cancel                      - Boolean - an output parameter. Always True.
//
// Example:
//
//  1. Showing the message associated with the object attribute near the managed form field:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FieldInFormAttributeObject",
//   "Object");
//
//  An alternative variant of using in the object form module:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "Object.FieldInFormAttributeObject");
//
//  2. Showing a message for the form attribute, next to the managed form field:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FormAttributeName");
//
//  3. To display a message associated with an infobase object:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), InfobaseObject, "Responsible person",,Cancel);
//
//  4. To display a message from a link to an infobase object:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), Reference, , , Cancel);
//
//  Scenarios of incorrect using:
//   1. Passing DataKey and DataPath parameters at the same time.
//   2. Passing a value of an illegal type to the DataKey parameter.
//   3. Specifying a reference without specifying a field (and/or a data path).
//
Procedure MessageToUser(
		Val MessageToUserText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	IsObject = False;
	
#If Not ThinClient And Not WebClient And Not MobileClient Then
	If DataKey <> Undefined
	   And XMLTypeOf(DataKey) <> Undefined Then
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsObject = StrFind(ValueTypeAsString, "Object.") > 0;
	EndIf;
#EndIf
	
	If IsObject Then
		Message.SetData(DataKey);
	Else
		Message.DataKey = DataKey;
	EndIf;
	
	If Not IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
		
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Deprecated. Instead, use CommonClient.CopyRecursive or Common.CopyRecursive.
// Creates a complete recursive copy of a structure, map, array, list, or value table consistent with the child item type. 
// For object-type values (CatalogObject or DocumentObject), returns references to the source objects. 
// 
//
// Parameters:
//  Source - Structure
//           - Map
//           - Array
//           - ValueList
//           - ValueTable -  
//             
//
// Returns:
//  Structure, Map, Array, ValueList, ValueTable - 
//
Function CopyRecursive(Source) Export
	
	Var Receiver;
	
	SourceType = TypeOf(Source);
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If SourceType = Type("ValueTable") Then
		Return Source.Copy();
	EndIf;
#EndIf	
	If SourceType = Type("Structure") Then
		Receiver = CopyStructure(Source);
	ElsIf SourceType = Type("Map") Then
		Receiver = CopyMap(Source);
	ElsIf SourceType = Type("Array") Then
		Receiver = CopyArray(Source);
	ElsIf SourceType = Type("ValueList") Then
		Receiver = CopyValueList(Source);
	Else
		Receiver = Source;
	EndIf;
	
	Return Receiver;
	
EndFunction

// Deprecated. Instead, use CommonClient.CopyRecursive or Common.CopyRecursive.
// Creates a recursive copy of a Structure consistent with the property value types. 
// For structure properties that contain object-type values (CatalogObject or DocumentObject), returns references to the source objects.
// 
//
// Parameters:
//  SourceStructure - Structure - a structure to copy.
// 
// Returns:
//  Structure - 
//
Function CopyStructure(SourceStructure) Export
	
	ResultingStructure = New Structure;
	
	For Each KeyAndValue In SourceStructure Do
		ResultingStructure.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultingStructure;
	
EndFunction

// Deprecated. Instead, use CommonClient.CopyRecursive or Common.CopyRecursive.
// Creates a recursive copy of a Map consistent with the value types.
// For object-type map values (CatalogObject or DocumentObject), returns references to the objects.
// 
//
// Parameters:
//  SourceMap - Map - the map to copy.
// 
// Returns:
//  Map - 
//
Function CopyMap(SourceMap) Export
	
	ResultingMap = New Map;
	
	For Each KeyAndValue In SourceMap Do
		ResultingMap.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultingMap;

EndFunction

// Deprecated. Instead, use CommonClient.CopyRecursive or Common.CopyRecursive.
// Creates a recursive copy of an Array consistent with the element value types.
// For array elements that contain object-type values (CatalogObject or DocumentObject) returns references to the objects.
// 
//
// Parameters:
//  SourceArray1 - Array - the array to copy.
// 
// Returns:
//  Array - 
//
Function CopyArray(SourceArray1) Export
	
	ResultingArray = New Array;
	
	For Each Item In SourceArray1 Do
		ResultingArray.Add(CopyRecursive(Item));
	EndDo;
	
	Return ResultingArray;
	
EndFunction

// Deprecated. Instead, use CommonClient.CopyRecursive or Common.CopyRecursive.
// Creates a recursive copy of a ValueList consistent with the value types.
// For value lists that contain object-type values (CatalogObject or DocumentObject), returns references to the objects.
// 
//
// Parameters:
//  SourceList - ValueList - the value list to copy.
// 
// Returns:
//  ValueList - 
//
Function CopyValueList(SourceList) Export
	
	ResultingList = New ValueList;
	
	For Each ListItem In SourceList Do
		ResultingList.Add(
			CopyRecursive(ListItem.Value), 
			ListItem.Presentation, 
			ListItem.Check, 
			ListItem.Picture);
	EndDo;
	
	Return ResultingList;
	
EndFunction

// Deprecated. Instead, use CommonClientServer.SupplementTable
// Fills the destination collection with values from the source collection.
// Objects of the following types can be a destination collection and a source collection:
// ValueTable, ValueTree, ValueList, and other collection types.
//
// Parameters:
//  SourceCollection - See SupplementTable.SourceTable1
//  DestinationCollection - See SupplementTable.DestinationTable
// 
Procedure FillPropertyCollection(SourceCollection, DestinationCollection) Export
	
	For Each Item In SourceCollection Do
		FillPropertyValues(DestinationCollection.Add(), Item);
	EndDo;
	
EndProcedure

// Deprecated. Instead, use CommonClient.EstablishExternalConnectionWithInfobase or 
// Common.EstablishExternalConnectionWithInfobase.
// Establishes an external infobase connection with the passed parameters and returns the pointer to the connection.
// 
// 
// Parameters:
//  Parameters - Structure - external connection parameters.
//                          For the properties, see function 
//                          CommonClientServer.ParametersStructureForExternalConnection):
//
//    * InfobaseOperatingMode             - Number - the infobase operation mode. File mode - 0.
//                                                            Client/server mode - 1;
//    * InfobaseDirectory                   - String - the infobase directory;
//    * NameOf1CEnterpriseServer                     - String - the name of the 1C:Enterprise server;
//    * NameOfInfobaseOn1CEnterpriseServer - String - a name of the infobase on 1C Enterprise server;
//    * OperatingSystemAuthentication           - Boolean - Indicates whether the operating system is authenticated on establishing
//                                                             a connection to the infobase;
//    * UserName                             - String - the name of an infobase user;
//    * UserPassword                          - String - the user password.
// 
//  ErrorMessageString - String - If establishing connection fails,
//                                     this parameter will store the error details.
//  AddInAttachmentError - Boolean - (a return parameter) True if add-in attachment failed.
//
// Returns:
//  COMObject, Undefined - 
//    
//
Function EstablishExternalConnection(Parameters, ErrorMessageString = "", AddInAttachmentError = False) Export
	Result = EstablishExternalConnectionWithInfobase(Parameters);
	AddInAttachmentError = Result.AddInAttachmentError;
	ErrorMessageString     = Result.DetailedErrorDetails;
	
	Return Result.Join;
EndFunction

// Deprecated. Instead, use CommonClient.EstablishExternalConnectionWithInfobase 
//  or Common.EstablishExternalConnectionWithInfobase
// Establishes an external infobase connection with the passed parameters and returns a pointer
// to the connection.
// 
// Parameters:
//  Parameters - Structure - external connection parameters.
//                          For the properties, see function 
//                          CommonClientServer.ParametersStructureForExternalConnection):
//
//   * InfobaseOperatingMode             - Number  - the infobase operation mode. File mode - 0.
//                                                            Client/server mode - 1;
//   * InfobaseDirectory                   - String - the infobase directory;
//   * NameOf1CEnterpriseServer                     - String - the name of the 1C:Enterprise server;
//   * NameOfInfobaseOn1CEnterpriseServer - String - a name of the infobase on 1C Enterprise server;
//   * OperatingSystemAuthentication           - Boolean - Indicates whether the operating system is authenticated on establishing
//                                                            a connection to the infobase;
//   * UserName                             - String - the name of an infobase user;
//   * UserPassword                          - String - the user password.
// 
// Returns:
//  Structure:
//    * Join                  - COMObject
//                                  - Undefined - 
//                                    
//    * BriefErrorDetails       - String - brief error description;
//    * DetailedErrorDetails     - String - detailed error description;
//    * AddInAttachmentError - Boolean - a COM connection error flag.
//
Function EstablishExternalConnectionWithInfobase(Parameters) Export
	
	Result = New Structure;
	Result.Insert("Join");
	Result.Insert("BriefErrorDetails", "");
	Result.Insert("DetailedErrorDetails", "");
	Result.Insert("AddInAttachmentError", False);
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		ConnectionNotAvailable = Common.IsLinuxServer();
		BriefErrorDetails = NStr("en = 'Servers on Linux do not support direct infobase connections.';");
	#Else
		ConnectionNotAvailable = IsLinuxClient() Or IsOSXClient() Or IsMobileClient();
		BriefErrorDetails = NStr("en = 'Only Windows clients support direct infobase connections.';");
	#EndIf
	
	If ConnectionNotAvailable Then
		Result.Join = Undefined;
		Result.BriefErrorDetails = BriefErrorDetails;
		Result.DetailedErrorDetails = BriefErrorDetails;
		Return Result;
	EndIf;
	
	#If Not MobileClient Then
		Try
			COMConnector = New COMObject(COMConnectorName()); // "V83.COMConnector"
		Except
			Information = ErrorInfo();
			ErrorMessageString = NStr("en = 'Failed to connect to another application: %1';");
			
			Result.AddInAttachmentError = True;
			Result.DetailedErrorDetails = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.DetailErrorDescription(Information));
			Result.BriefErrorDetails = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.BriefErrorDescription(Information));
			
			Return Result;
		EndTry;
	
		FileRunMode = Parameters.InfobaseOperatingMode = 0;
		
		// Checking parameter correctness.
		FillingCheckError = False;
		If FileRunMode Then
			
			If IsBlankString(Parameters.InfobaseDirectory) Then
				ErrorMessageString = NStr("en = 'The infobase directory location is not specified.';");
				FillingCheckError = True;
			EndIf;
			
		Else
			
			If IsBlankString(Parameters.NameOf1CEnterpriseServer) Or IsBlankString(Parameters.NameOfInfobaseOn1CEnterpriseServer) Then
				ErrorMessageString = NStr("en = 'Required connection parameters are not specified: server name and infobase name.';");
				FillingCheckError = True;
			EndIf;
			
		EndIf;
		
		If FillingCheckError Then
			
			Result.DetailedErrorDetails = ErrorMessageString;
			Result.BriefErrorDetails   = ErrorMessageString;
			Return Result;
			
		EndIf;
		
		// Generate the connection string.
		ConnectionStringPattern = "[InfobaseString][AuthenticationString]";
		
		If FileRunMode Then
			InfobaseString = "File = ""&InfobaseDirectory""";
			InfobaseString = StrReplace(InfobaseString, "&InfobaseDirectory", Parameters.InfobaseDirectory);
		Else
			InfobaseString = "Srvr = ""&NameOf1CEnterpriseServer""; Ref = ""&NameOfInfobaseOn1CEnterpriseServer""";
			InfobaseString = StrReplace(InfobaseString, "&NameOf1CEnterpriseServer",                     Parameters.NameOf1CEnterpriseServer);
			InfobaseString = StrReplace(InfobaseString, "&NameOfInfobaseOn1CEnterpriseServer", Parameters.NameOfInfobaseOn1CEnterpriseServer);
		EndIf;
		
		If Parameters.OperatingSystemAuthentication Then
			AuthenticationString = "";
		Else
			
			If StrFind(Parameters.UserName, """") Then
				Parameters.UserName = StrReplace(Parameters.UserName, """", """""");
			EndIf;
			
			If StrFind(Parameters.UserPassword, """") Then
				Parameters.UserPassword = StrReplace(Parameters.UserPassword, """", """""");
			EndIf;
			
			AuthenticationString = "; Usr = ""&UserName""; Pwd = ""&UserPassword""";
			AuthenticationString = StrReplace(AuthenticationString, "&UserName",    Parameters.UserName);
			AuthenticationString = StrReplace(AuthenticationString, "&UserPassword", Parameters.UserPassword);
		EndIf;
		
		ConnectionString = StrReplace(ConnectionStringPattern, "[InfobaseString]", InfobaseString);
		ConnectionString = StrReplace(ConnectionString, "[AuthenticationString]", AuthenticationString);
		
		Try
			Result.Join = COMConnector.Connect(ConnectionString);
		Except
			Information = ErrorInfo();
			ErrorMessageString = NStr("en = 'Failed to connect to another application: %1';");
			
			Result.AddInAttachmentError = True;
			Result.DetailedErrorDetails     = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.DetailErrorDescription(Information));
			Result.BriefErrorDetails       = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.BriefErrorDescription(Information));
		EndTry;
	#EndIf
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use CommonClient.ClientConnectedOverWebServer 
// or Common.ClientConnectedOverWebServer
// Returns True if a client application is connected to the infobase through a web server.
// False if no client application is available.
//
// Returns:
//  Boolean - 
//
Function ClientConnectedOverWebServer() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	InfoBaseConnectionString = StandardSubsystemsServer.ClientParametersAtServer().Get("InfoBaseConnectionString");
	
	If InfoBaseConnectionString = Undefined Then
		Return False; // No client application.
	EndIf;
#Else
	InfoBaseConnectionString = InfoBaseConnectionString();
#EndIf
	
	Return StrFind(Upper(InfoBaseConnectionString), "WS=") = 1;
	
EndFunction

// Deprecated. Instead, use CommonClient.IsWindowsClient or Common.IsWindowsClient
// Returns True if the client application is running on Windows.
//
// Returns:
//  Boolean - 
//
Function IsWindowsClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsWindowsClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWindowsClient");
	
	If IsWindowsClient = Undefined Then
		Return False; // No client application.
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	             Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
#EndIf
	
	Return IsWindowsClient;
	
EndFunction

// Deprecated. Instead, use CommonClient.IsMacOSClient or Common.IsMacOSClient
// Returns True if the client application runs on OS X.
//
// Returns:
//  Boolean - 
//
Function IsOSXClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsMacOSClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMacOSClient");
	
	If IsMacOSClient = Undefined Then
		Return False; // No client application.
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsMacOSClient = SystemInfo.PlatformType = PlatformType.MacOS_x86
	             Or SystemInfo.PlatformType = PlatformType.MacOS_x86_64;
#EndIf
	
	Return IsMacOSClient;
	
EndFunction

// Deprecated. Instead, use CommonClient.IsLinuxClient or Common.IsLinuxClient
// Returns True if the client application is running on Linux.
//
// Returns:
//  Boolean - 
//
Function IsLinuxClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsLinuxClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsLinuxClient");
	
	If IsLinuxClient = Undefined Then
		Return False; // No client application.
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	             Or SystemInfo.PlatformType = PlatformType.Linux_x86_64;
#EndIf
	
	Return IsLinuxClient;
	
EndFunction

// Deprecated. Instead, use Common.IsWebClient or WebClient preprocessor instruction 
// in the client code.
// Returns True if the client application is a web client.
//
// Returns:
//  Boolean - 
//
Function IsWebClient() Export
	
#If WebClient Then
	Return True;
#ElsIf Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsWebClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWebClient");
	
	If IsWebClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsWebClient;
#Else
	Return False;
#EndIf
	
EndFunction

// Deprecated. Instead, use CommonClient.IsMacOSClient with WebClient preprocessor instruction
// or on the server (Common.IsMacOSClient AND Common.IsWebClient).
// Returns True if this is the OS X web client.
//
// Returns:
//  Boolean - 
//
Function IsMacOSWebClient() Export
	
#If WebClient Then
	Return CommonClient.IsMacOSClient();
#ElsIf Server Or ThickClientOrdinaryApplication Then
	Return IsOSXClient() And IsWebClient();
#Else
	Return False;
#EndIf
	
EndFunction

// Deprecated. Instead, use Common.IsMobileClient or MobileClient preprocessor instruction 
// in the client code.
// Returns True if the client application is a mobile client.
//
// Returns:
//  Boolean - 
//
Function IsMobileClient() Export
	
#If MobileClient Then
	Return True;
#ElsIf Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsMobileClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMobileClient");
	
	If IsMobileClient = Undefined Then
		Return False; // No client application.
	EndIf;
	
	Return IsMobileClient;
#Else
	Return False;
#EndIf
	
EndFunction

// Deprecated. Instead, use CommonClient.RAMAvailableForClientApplication 
//  or Common.RAMAvailableForClientApplication
// Returns the amount of RAM available to the client application.
//
// Returns:
//  Number - 
//  
//
Function RAMAvailableForClientApplication() Export
	
#If Server Or ThickClientOrdinaryApplication Or  ExternalConnection Then
	AvailableMemorySize = StandardSubsystemsServer.ClientParametersAtServer().Get("RAM");
#Else
	SystemInfo = New  SystemInfo;
	AvailableMemorySize = Round(SystemInfo.RAM / 1024,  1);
#EndIf
	
	Return AvailableMemorySize;
	
EndFunction

// Deprecated. Instead, use CommonClient.DebugMode or Common.DebugMode
// Returns True if debug mode is enabled.
//
// Returns:
//  Boolean - 
//
Function DebugMode() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ApplicationStartupParameter = StandardSubsystemsServer.ClientParametersAtServer(False).Get("LaunchParameter");
#Else
	ApplicationStartupParameter = LaunchParameter;
#EndIf
	
	Return StrFind(ApplicationStartupParameter, "DebugMode") > 0;
EndFunction

// Deprecated. Instead, use CommonClient.DefaultLanguageCode or Common.DefaultLanguageCode
// Returns the code of the default configuration language, for example, "en".
//
// Returns:
//  String - 
//
Function DefaultLanguageCode() Export

	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Return Common.DefaultLanguageCode();
	#Else
		Return CommonClient.DefaultLanguageCode();
	#EndIf

EndFunction

// Deprecated. Instead, use CommonClient.LocalDatePresentationWithOffset 
//  or Common.LocalDatePresentationWithOffset
// Convert a local date to the "YYYY-MM-DDThh:mm:ssTZD" format (ISO 8601).
//
// Parameters:
//  LocalDate - Date - a date in the session time zone.
// 
// Returns:
//   String - 
//
Function LocalDatePresentationWithOffset(LocalDate) Export
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Offset = StandardTimeOffset(SessionTimeZone());
	#Else
		Offset = StandardSubsystemsClient.ClientParameter("StandardTimeOffset");
	#EndIf
	OffsetPresentation = "Z";
	If Offset > 0 Then
		OffsetPresentation = "+";
	ElsIf Offset < 0 Then
		OffsetPresentation = "-";
		Offset = -Offset;
	EndIf;
	If Offset <> 0 Then
		OffsetPresentation = OffsetPresentation + Format('00010101' + Offset, "DF=HH:mm");
	EndIf;
	
	Return Format(LocalDate, "DF=yyyy-MM-ddTHH:mm:ss; DE=0001-01-01T00:00:00") + OffsetPresentation;
EndFunction

// Deprecated. Instead, use CommonClient.PredefinedItem 
//  or Common.PredefinedItem
// Retrieves a reference to the predefined item by its full name.
// Only the following objects can contain predefined objects:
//   - Catalogs;
//   - Charts of characteristic types;
//   - Charts of accounts;
//   - Charts of calculation types.
// After changing the list of predefined items, it is recommended that you run
// the UpdateCachedValues() method to clear the cache for Cached modules in the current session.
//
// Parameters:
//   FullPredefinedItemName - String - full path to the predefined item including the name.
//     The format is identical to the PredefinedValue() global context function.
//     Example:
//       "Catalog.ContactInformationKinds.UserEmail"
//       "ChartOfAccounts.SelfFinancing.Materials"
//       "ChartOfCalculationTypes.Accruals.SalaryPayments".
//
// Returns: 
//   AnyRef - 
//   
//
Function PredefinedItem(FullPredefinedItemName) Export
	
	// 
	//   
	//  
	//  
	
	If StrEndsWith(Upper(FullPredefinedItemName), ".EMPTYREF")
		Or StrStartsWith(Upper(FullPredefinedItemName), "ENUM.")
		Or StrStartsWith(Upper(FullPredefinedItemName), "BUSINESSPROCESS.") Then
		
		Return PredefinedValue(FullPredefinedItemName);
	EndIf;
	
	// Parsing the full name of the predefined item.
	FullNameParts1 = StrSplit(FullPredefinedItemName, ".");
	If FullNameParts1.Count() <> 3 Then 
		Raise CommonInternalClientServer.PredefinedValueNotFoundErrorText(
			FullPredefinedItemName);
	EndIf;
	
	FullMetadataObjectName = Upper(FullNameParts1[0] + "." + FullNameParts1[1]);
	PredefinedItemName = FullNameParts1[2];
	
	// Cache to be called is determined by context.
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	PredefinedValues = StandardSubsystemsCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
#Else
	PredefinedValues = StandardSubsystemsClientCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
#EndIf

	// In case of error in metadata name.
	If PredefinedValues = Undefined Then 
		Raise CommonInternalClientServer.PredefinedValueNotFoundErrorText(
			FullPredefinedItemName);
	EndIf;

	// Getting result from cache.
	Result = PredefinedValues.Get(PredefinedItemName);
	
	// If the predefined item does not exist in metadata.
	If Result = Undefined Then 
		Raise CommonInternalClientServer.PredefinedValueNotFoundErrorText(
			FullPredefinedItemName);
	EndIf;
	
	// If the predefined item exists in metadata but not in the infobase.
	If Result = Null Then 
		Return Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

// Deprecated. 
// 
// 
//
// Returns:
//  Structure:
//   * CurrentDirectory              - String - sets the current directory of the application being started up.
//   * WaitForCompletion         - Boolean - wait for the running application to end before proceeding.
//   * GetOutputStream         - Boolean - result is passed to stdout. Ignored
//                                            if WaitForCompletion is not specified.
//   * GetErrorStream         - Boolean - errors are passed to stderr stream. Ignored
//                                            if WaitForCompletion is not specified.
//   * ExecuteWithFullRights - Boolean - It is required to run the application with the elevated system privileges:
//                                            UAC confirmation for Windows;
//                                            or interactive query with GUI sudo and redirection
//                                            $DISPLAY and $XAUTHORITY of the current user for Linux;
//                                            Incompatible with the WaitForCompletion parameter. Ignored when under MacOS.
//   * Encoding                   - String - encoding code specified before the batch operation.
//                                            Ignored under Linux or MacOS.
//
Function ApplicationStartupParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDirectory", "");
	Parameters.Insert("WaitForCompletion", False);
	Parameters.Insert("GetOutputStream", False);
	Parameters.Insert("GetErrorStream", False);
	Parameters.Insert("ExecuteWithFullRights", False);
	Parameters.Insert("Encoding", "");
	
	Return Parameters;
	
EndFunction

// Deprecated. Instead, use FileSystemClient.StartApplication or FileSystem.StartApplication.
// Runs an external application using the startup parameters.
// Doesn't support web client. 
//
// Parameters:
//  StartupCommand - String
//                 - Array - 
//      
//      
//  ApplicationStartupParameters - See ApplicationStartupParameters
//
// Returns:
//  Structure - 
//      
//      
//      
//
// Example:
//	CommonClientServer.StartApplication("calc");
//	
//	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
//	ApplicationStartupParameters.ExecuteWithFullRights = True;
//	CommonClientServer.StartApplication("C:\Program Files\1cv8\common\1cestart.exe", 
//		ApplicationStartupParameters);
//	
//	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
//	ApplicationStartupParameters.WaitForCompletion = True;
//	Result = CommonClientServer.StartApplication("ping 127.0.0.1 -n 5", ApplicationStartupParameters);
//
Function StartApplication(Val StartupCommand, ApplicationStartupParameters = Undefined) Export 
	
#If WebClient Or MobileClient Then
	Raise NStr("en = 'Cannot run applications in the web client.';");
#Else
	
	CommandString = CommonInternalClientServer.SafeCommandString(StartupCommand);
	
	If ApplicationStartupParameters = Undefined Then 
		ApplicationStartupParameters = ApplicationStartupParameters();
	EndIf;
	
	CurrentDirectory              = ApplicationStartupParameters.CurrentDirectory;
	WaitForCompletion         = ApplicationStartupParameters.WaitForCompletion;
	GetOutputStream         = ApplicationStartupParameters.GetOutputStream;
	GetErrorStream         = ApplicationStartupParameters.GetErrorStream;
	ExecuteWithFullRights = ApplicationStartupParameters.ExecuteWithFullRights;
	Encoding                   = ApplicationStartupParameters.Encoding;
	
	If ExecuteWithFullRights Then 
#If ExternalConnection Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Invalid value of %1 parameter.
			|Elevating system privileges from an external connection is not supported.';"),
			"ApplicationStartupParameters.ExecuteWithFullRights");
#EndIf
		
#If Server Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of %1 parameter.
			|Elevating system privileges is not supported on the server.';"),
			"ApplicationStartupParameters.ExecuteWithFullRights");
#EndIf
		
	EndIf;
	
	SystemInfo = New SystemInfo();
	If (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
	
		If Not IsBlankString(Encoding) Then
			CommandString = "chcp " + Encoding + " | " + CommandString;
		EndIf;
	
	EndIf;
	
	If WaitForCompletion Then 
		
		If GetOutputStream Then 
			OutputStreamFile = GetTempFileName("stdout.tmp");
			CommandString = CommandString + " > """ + OutputStreamFile + """";
		EndIf;
		
		If GetErrorStream Then 
			ErrorStreamFile = GetTempFileName("stderr.tmp");
			CommandString = CommandString + " 2>""" + ErrorStreamFile + """";
		EndIf;
		
	EndIf;
	
	ReturnCode = Undefined;
	
	If (SystemInfo.PlatformType = PlatformType.Windows_x86)
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
		
		// Because of the running through shell, redirect the directory with a command.
		If Not IsBlankString(CurrentDirectory) Then 
			CommandString = "cd /D """ + CurrentDirectory + """ && " + CommandString;
		EndIf;
		
		// 
		CommandString = "cmd /S /C "" " + CommandString + " """;
		
#If Server Then
		
		If Common.FileInfobase() Then
			// In a file infobase, the console window must be hidden in the server context as well.
			Shell = New COMObject("Wscript.Shell");
			ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
			Shell = Undefined;
		Else 
			RunApp(CommandString,, WaitForCompletion, ReturnCode);
		EndIf;
		
#Else
		
		If ExecuteWithFullRights Then
			
			If WaitForCompletion Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr(
					"en = 'Cannot set the following parameters simultaneously:
					| - %1 and
					| - %2
					|Processes started by administrator
					|cannot be monitored on behalf of user in this operating system.';"),
					"ApplicationStartupParameters.WaitForCompletion",
					"ApplicationStartupParameters.ExecuteWithFullRights");
			EndIf;
			
			Shell = New COMObject("Shell.Application");
			// Запуск с передачей глагола действия - 
			Shell.ShellExecute("cmd", "/c """ + CommandString + """",, "runas", 0);
			Shell = Undefined;
			
		Else 
			Shell = New COMObject("Wscript.Shell");
			ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
			Shell = Undefined;
		EndIf;
#EndIf
		
	ElsIf (SystemInfo.PlatformType = PlatformType.Linux_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Linux_x86_64) Then
		
		If ExecuteWithFullRights Then
			
			CommandTemplate = "pkexec env DISPLAY=[DISPLAY] XAUTHORITY=[XAUTHORITY] [CommandString]";
			
			TemplateParameters = New Structure;
			TemplateParameters.Insert("CommandString", CommandString);
			
			SubprogramStartupParameters = ApplicationStartupParameters();
			SubprogramStartupParameters.WaitForCompletion = True;
			SubprogramStartupParameters.GetOutputStream = True;
			
			Result = StartApplication("echo $DISPLAY", SubprogramStartupParameters);
			TemplateParameters.Insert("DISPLAY", Result.OutputStream);
			
			Result = StartApplication("echo $XAUTHORITY", SubprogramStartupParameters);
			TemplateParameters.Insert("XAUTHORITY", Result.OutputStream);
			
			CommandString = StringFunctionsClientServer.InsertParametersIntoString(CommandTemplate, TemplateParameters);
			WaitForCompletion = True;
			
		EndIf;
		
		RunApp(CommandString, CurrentDirectory, WaitForCompletion, ReturnCode);
		
	Else
		
		// 
		// 
		RunApp(CommandString, CurrentDirectory, WaitForCompletion, ReturnCode);
		
	EndIf;
	
	// Override the shell returned value.
	If ReturnCode = Undefined Then 
		ReturnCode = 0;
	EndIf;
	
	OutputStream = "";
	ErrorStream = "";
	
	If WaitForCompletion Then 
		
		If GetOutputStream Then
			
			FileInfo3 = New File(OutputStreamFile);
			If FileInfo3.Exists() Then 
				OutputStreamReader = New TextReader(OutputStreamFile, StandardStreamEncoding()); 
				OutputStream = OutputStreamReader.Read();
				OutputStreamReader.Close();
				DeleteTempFile(OutputStreamFile);
			EndIf;
			
			If OutputStream = Undefined Then 
				OutputStream = "";
			EndIf;
			
		EndIf;
		
		If GetErrorStream Then 
			
			FileInfo3 = New File(ErrorStreamFile);
			If FileInfo3.Exists() Then 
				ErrorStreamReader = New TextReader(ErrorStreamFile, StandardStreamEncoding());
				ErrorStream = ErrorStreamReader.Read();
				ErrorStreamReader.Close();
				DeleteTempFile(ErrorStreamFile);
			EndIf;
			
			If ErrorStream = Undefined Then 
				ErrorStream = "";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("ReturnCode", ReturnCode);
	Result.Insert("OutputStream", OutputStream);
	Result.Insert("ErrorStream", ErrorStream);
	
	Return Result;
	
#EndIf
	
EndFunction

// Deprecated. Instead, use GetFilesFromInternet.ConnectionDiagnostics.
// Runs the network resource diagnostics.
// Doesn't support web client.
// In SaaS mode, the functionality is limited to getting error descriptions.
//
// Parameters:
//  URL - String - URL resource address to be diagnosed.
//
// Returns:
//  Structure - 
//      
//      
//
// Example:
//	// Diagnostics of address classifier web service.
//	Result = CommonClientServer.ConnectionDiagnostics("https://api.orgaddress.1c.com/orgaddress/v1?wsdl");
//	
//	ErrorDetails = Result.ErrorDetails;
//	DiagnosticsLog = Result.DiagnosticsLog;
//
Function ConnectionDiagnostics(URL) Export
	
#If WebClient Then
	Raise NStr("en = 'The connection diagnostics are unavailable in the web client.';");
#Else
	
	LongDesc = New Array;
	LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Accessing URL: %1.';"), 
		URL));
	LongDesc.Add(DiagnosticsLocationPresentation());
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.DataSeparationEnabled() Then
		LongDesc.Add(
			NStr("en = 'Please contact the administrator.';"));
		
		ErrorDescription = StrConcat(LongDesc, Chars.LF);
		
		Result = New Structure;
		Result.Insert("ErrorDescription", ErrorDescription);
		Result.Insert("DiagnosticsLog", "");
		
		Return Result;
	EndIf;
#EndIf
	
	Log = New Array;
	Log.Add(
		NStr("en = 'Diagnostics log:
		           |Server availability test.
		           |See the error description in the next log record.';"));
	Log.Add();
	
	ProxyConnection = False;
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = 
			Common.CommonModule("GetFilesFromInternetClientServer");
		ProxySettingsState = ModuleNetworkDownloadClientServer.ProxySettingsState();
		
		ProxyConnection = ProxySettingsState.ProxyConnection;
		
		Log.Add(ProxySettingsState.Presentation);
	EndIf;
#Else
	If CommonClient.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = 
			CommonClient.CommonModule("GetFilesFromInternetClientServer");
		ProxySettingsState = ModuleNetworkDownloadClientServer.ProxySettingsState();
		
		ProxyConnection = ProxySettingsState.ProxyConnection;
		
		Log.Add(ProxySettingsState.Presentation);
	EndIf;
#EndIf
	
	If ProxyConnection Then 
		
		LongDesc.Add(
			NStr("en = 'Connection diagnostics are not performed because a proxy server is configured.
			           |Please contact the administrator.';"));
		
	Else 
		
		RefStructure = URIStructure(URL);
		ResourceServerAddress = RefStructure.Host;
		VerificationServerAddress = "google.com";
		
		ResourceAvailabilityResult = CheckServerAvailability(ResourceServerAddress);
		
		Log.Add();
		Log.Add("1) " + ResourceAvailabilityResult.DiagnosticsLog);
		
		If ResourceAvailabilityResult.Available Then 
			
			LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Attempted to access a resource that does not exist on server %1,
				           |or some issues occurred on the remote server.';"),
				ResourceServerAddress));
			
		Else 
			
			VerificationResult = CheckServerAvailability(VerificationServerAddress);
			Log.Add("2) " + VerificationResult.DiagnosticsLog);
			
			If Not VerificationResult.Available Then
				
				LongDesc.Add(
					NStr("en = 'No Internet access. Possible reasons:
					           |- The computer is not connected to the Internet.
					           | - Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           | is blocking the connection.';"));
				
			Else 
				
				LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Server %1 is unavailable. Possible reasons:
					           |- Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           | is blocking the connection.
					           |- The server is turned off or under maintenance.';"),
					ResourceServerAddress));
				
				TraceLog = ServerRouteTraceLog(ResourceServerAddress);
				Log.Add("3) " + TraceLog);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ErrorDescription = StrConcat(LongDesc, Chars.LF);
	
	Log.Insert(0);
	Log.Insert(0, ErrorDescription);
	
	DiagnosticsLog = StrConcat(Log, Chars.LF);
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	WriteLogEvent(
		NStr("en = 'Connection diagnostics';", DefaultLanguageCode()),
		EventLogLevel.Error,,, DiagnosticsLog);
#Else
	EventLogClient.AddMessageForEventLog(
		NStr("en = 'Connection diagnostics';", DefaultLanguageCode()),
		"Error", DiagnosticsLog,, True);
#EndIf
	
	Result = New Structure;
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("DiagnosticsLog", DiagnosticsLog);
	
	Return Result;
	
#EndIf
	
EndFunction

// ACC:547-on

#EndRegion

#EndRegion

#Region Internal

// Creates an array and adds the passed values to it.
//
// Parameters:
//  Value1 - Arbitrary - Any value.
//  Value2 - Arbitrary
//  Value3 - Arbitrary
//  Value4 - Arbitrary
//
// Returns:
//  Array
//  
// Example:
//   Result = CommonClientServer.ArrayOfValues(1, 2, 3);
//
Function ArrayOfValues(Val Value1, Val Value2 = Undefined, Val Value3 = Undefined, 
	Val Value4 = Undefined) Export
	
	Result = New Array;
	Result.Add(Value1);
	If Value2 <> Undefined Then
		Result.Add(Value2);
	EndIf;
	If Value3 <> Undefined Then
		Result.Add(Value3);
	EndIf;
	If Value4 <> Undefined Then
		Result.Add(Value4);
	EndIf;
	Return Result;
	
EndFunction

Function NameMeetPropertyNamingRequirements(Name) Export
	Letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; // @Non-
	Digits = "1234567890"; // @Non-NLS
	
	If Name = "" Or StrFind(Letters + "_", Upper(Left(Name, 1))) = 0 Then
		Return False;
	EndIf;
	
	Return StrSplit(Upper(Name), Letters + Digits + "_", False).Count() = 0;
EndFunction

#EndRegion

#Region Private

#Region Data

#Region ValueListsAreEqual

// Searches for the item in the value list or in the array.
//
Function FindInList(List, Item)
	
	Var ItemInList;
	
	If TypeOf(List) = Type("ValueList") Then
		If TypeOf(Item) = Type("ValueListItem") Then
			ItemInList = List.FindByValue(Item.Value);
		Else
			ItemInList = List.FindByValue(Item);
		EndIf;
	EndIf;
	
	If TypeOf(List) = Type("Array") Then
		ItemInList = List.Find(Item);
	EndIf;
	
	Return ItemInList;
	
EndFunction

#EndRegion

#Region CheckParameter

Function ExpectedTypeValue(Value, ExpectedTypes)
	
	ValueType = TypeOf(Value);
	If TypeOf(ExpectedTypes) = Type("TypeDescription") Then
		Return ExpectedTypes.Types().Find(ValueType) <> Undefined;
	ElsIf TypeOf(ExpectedTypes) = Type("Type") Then
		Return ValueType = ExpectedTypes;
	ElsIf TypeOf(ExpectedTypes) = Type("Array") 
		Or TypeOf(ExpectedTypes) = Type("FixedArray") Then
		Return ExpectedTypes.Find(ValueType) <> Undefined;
	ElsIf TypeOf(ExpectedTypes) = Type("Map") 
		Or TypeOf(ExpectedTypes) = Type("FixedMap") Then
		Return ExpectedTypes.Get(ValueType) <> Undefined;
	EndIf;
	Return Undefined;
	
EndFunction

Function TypesPresentation(ExpectedTypes)
	
	If TypeOf(ExpectedTypes) = Type("Array")
		Or TypeOf(ExpectedTypes) = Type("FixedArray")
		Or TypeOf(ExpectedTypes) = Type("Map")
		Or TypeOf(ExpectedTypes) = Type("FixedMap") Then
		
		Result = "";
		IndexOf = 0;
		For Each Item In ExpectedTypes Do
			
			If TypeOf(ExpectedTypes) = Type("Map")
				Or TypeOf(ExpectedTypes) = Type("FixedMap") Then 
				
				Type = Item.Key;
			Else 
				Type = Item;
			EndIf;
			
			If Not IsBlankString(Result) Then
				Result = Result + ", ";
			EndIf;
			
			Result = Result + TypePresentation(Type);
			IndexOf = IndexOf + 1;
			If IndexOf > 10 Then
				Result = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1,… (total %2 types)';"), 
					Result, 
					ExpectedTypes.Count());
				Break;
			EndIf;
		EndDo;
		
		Return Result;
		
	Else 
		Return TypePresentation(ExpectedTypes);
	EndIf;
	
EndFunction

Function TypePresentation(Type)
	
	If Type = Undefined Then
		
		Return "Undefined";
		
	ElsIf TypeOf(Type) = Type("TypeDescription") Then
		
		TypeAsString = String(Type);
		Return 
			?(StrLen(TypeAsString) > 150, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1,… (total %2 types)';"),
					Left(TypeAsString, 150),
					Type.Types().Count()), 
				TypeAsString);
		
	Else
		
		TypeAsString = String(Type);
		Return 
			?(StrLen(TypeAsString) > 150, 
				Left(TypeAsString, 150) + "...", 
				TypeAsString);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region EmailAddressesOperations

#Region EmailAddressMeetsRequirements

Function HasCharsLeftRight(String, CharsToCheck)
	
	For Position = 1 To StrLen(CharsToCheck) Do
		Char = Mid(CharsToCheck, Position, 1);
		CharFound = (Left(String,1) = Char) Or (Right(String,1) = Char);
		If CharFound Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

Function StringContainsAllowedCharsOnly(String, AllowedChars)
	CharactersArray = New Array;
	For Position = 1 To StrLen(AllowedChars) Do
		CharactersArray.Add(Mid(AllowedChars,Position,1));
	EndDo;
	
	For Position = 1 To StrLen(String) Do
		If CharactersArray.Find(Mid(String, Position, 1)) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

#EndRegion

#EndRegion

#Region DynamicList

Procedure FindRecursively(ItemsCollection, ItemArray, SearchMethod, SearchValue)
	
	For Each FilterElement In ItemsCollection Do
		
		If TypeOf(FilterElement) = Type("DataCompositionFilterItem") Then
			
			If SearchMethod = 1 Then
				If FilterElement.LeftValue = SearchValue Then
					ItemArray.Add(FilterElement);
				EndIf;
			ElsIf SearchMethod = 2 Then
				If FilterElement.Presentation = SearchValue Then
					ItemArray.Add(FilterElement);
				EndIf;
			EndIf;
		Else
			
			FindRecursively(FilterElement.Items, ItemArray, SearchMethod, SearchValue);
			
			If SearchMethod = 2 And FilterElement.Presentation = SearchValue Then
				ItemArray.Add(FilterElement);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Math

#Region DistributeAmountInProportionToCoefficients

Function MaxValueInArray(Array)
	
	MaxValue = 0;
	
	For IndexOf = 0 To Array.Count() - 1 Do
		Value = Array[IndexOf];
		
		If MaxValue < Value Then
			MaxValue = Value;
		EndIf;
	EndDo;
	
	Return MaxValue;
	
EndFunction

#EndRegion

#EndRegion

#Region ObsoleteProceduresAndFunctions

// ACC:223-off This code is required for backward compatibility. It is used in an obsolete API.

#Region StartApplication

#If Not WebClient Then

// Returns encoding of standard output and error threads for the current operating system.
//
// Returns:
//  TextEncoding - 
//
Function StandardStreamEncoding()
	
	SystemInfo = New SystemInfo();
	If (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
		
		Encoding = TextEncoding.OEM;
	Else
		Encoding = TextEncoding.System;
	EndIf;
	
	Return Encoding;
	
EndFunction

Procedure DeleteTempFile(FullFileName)
	
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
		
	Try
		DeleteFiles(FullFileName);
	Except
		
		// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
		
#If Server Then
		WriteLogEvent(NStr("en = 'Core';", DefaultLanguageCode()),
			EventLogLevel.Warning,,, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot delete temporary file:
				           |%1. Reason: %2';"), 
				FullFileName, 
				ErrorProcessing.BriefErrorDescription(ErrorInfo())));
#EndIf
		
		// ACC:547-on
		
	EndTry;
	
EndProcedure

#EndIf

#EndRegion

#Region ConnectionDiagnostics

#If Not WebClient Then

Function DiagnosticsLocationPresentation()
	
	// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.DataSeparationEnabled() Then
		Return NStr("en = 'Connecting from a remote 1C:Enterprise server.';");
	Else 
		If Common.FileInfobase() Then
			If ClientConnectedOverWebServer() Then 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Connecting from a file infobase on web server <%1>.';"), ComputerName());
			Else 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Connecting from a file infobase on computer <%1>.';"), ComputerName());
			EndIf;
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Connecting from 1C:Enterprise server <%1>.';"), ComputerName());
		EndIf;
	EndIf;
#Else 
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Connecting from computer <%1> (client).';"), ComputerName());
#EndIf
	
	// ACC:547-on
	
EndFunction

Function CheckServerAvailability(ServerAddress)
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	SystemInfo = New SystemInfo();
	IsWindows = (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64);
		
	If IsWindows Then
		CommandTemplate = "ping %1 -n 2 -w 500";
	Else
		CommandTemplate = "ping -c 2 -w 500 %1";
	EndIf;
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandTemplate, ServerAddress);
	
	Result = StartApplication(CommandString, ApplicationStartupParameters);
	
	// 
	// 
	// 
	AvailabilityLog = Result.OutputStream + Result.ErrorStream;
	
	// ACC:1297-disable not localized fragment left for backward compatibility
	
	If IsWindows Then
		UnavailabilityFact = (StrFind(AvailabilityLog, "Preassigned node disabled") > 0) // 
			Or (StrFind(AvailabilityLog, "Destination host unreachable") > 0); // Do not localize.
		
		NoLosses = (StrFind(AvailabilityLog, "(0% loss)") > 0) // 
			Or (StrFind(AvailabilityLog, "(0% loss)") > 0); // Do not localize.
	Else 
		UnavailabilityFact = (StrFind(AvailabilityLog, "Destination Host Unreachable") > 0); // 
		NoLosses = (StrFind(AvailabilityLog, "0% packet loss") > 0) // 
	EndIf;
	
	// ACC:1297-on
	
	Available = Not UnavailabilityFact And NoLosses;
	
	Log = New Array;
	If Available Then
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remote server %1 is available:';"), 
			ServerAddress));
	Else
		Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Remote server %1 is unavailable:';"), 
			ServerAddress));
	EndIf;
	
	Log.Add("> " + CommandString);
	Log.Add(AvailabilityLog);
	
	Return New Structure("Available, DiagnosticsLog", Available, StrConcat(Log, Chars.LF));
	
EndFunction

Function ServerRouteTraceLog(ServerAddress)
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	SystemInfo = New SystemInfo();
	IsWindows = (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64);
	
	If IsWindows Then
		CommandTemplate = "tracert -w 100 -h 15 %1";
	Else 
		// Если вдруг пакет traceroute не установлен - 
		// 
		// 
		CommandTemplate = "traceroute -w 100 -m 100 %1";
	EndIf;
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandTemplate, ServerAddress);
	
	Result = StartApplication(CommandString, ApplicationStartupParameters);
	
	Log = New Array;
	Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Tracing route to remote server %1:';"), ServerAddress));
	
	Log.Add("> " + CommandString);
	Log.Add(Result.OutputStream);
	Log.Add(Result.ErrorStream);
	
	Return StrConcat(Log, Chars.LF);
	
EndFunction

#EndIf

#EndRegion

// ACC:223-on

#EndRegion

#EndRegion
