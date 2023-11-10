///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

////////////////////////////////////////////////////////////////////////////////
// ACRONYMS IN VARIABLE NAMES

//  
//  
//  
//  
//  
//  

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY MODULE VARIABLES FOR CREATING ALGORITHMS (FOR BOTH IMPORT AND EXPORT)

Var Conversion  Export;  // 

Var Algorithms    Export;  // 
Var Queries      Export;  // 
Var AdditionalDataProcessors Export;  // 

Var Rules      Export;  // 

Var Managers    Export;  // 
Var ManagersForExchangePlans Export;
Var ExchangeFile Export;            // 

Var AdditionalDataProcessorParameters Export;  // 

Var ParametersInitialized Export;  // 

Var mDataProtocolFile Export; // 
Var CommentObjectProcessingFlag Export;

Var EventHandlersExternalDataProcessor Export; // 
                                                   // 

Var CommonProceduresFunctions;  // Переменная хранит ссылку на данный экземпляр обработки - 
                              // 

Var mHandlerParameterTemplate; // 
Var mCommonProceduresFunctionsTemplate;  // 
                                    // 

Var mDataProcessingModes; // 
Var DataProcessingMode;   // 

Var mAlgorithmDebugModes; // 
Var IntegratedAlgorithms; // 

Var HandlersNames; // 

Var ConfigurationSeparators; // 

////////////////////////////////////////////////////////////////////////////////
// FLAGS THAT SHOW WHETHER GLOBAL EVENT HANDLERS EXIST

Var HasBeforeExportObjectGlobalHandler;
Var HasAfterExportObjectGlobalHandler;

Var HasBeforeConvertObjectGlobalHandler;

Var HasBeforeImportObjectGlobalHandler;
Var HasAfterObjectImportGlobalHandler;

Var DestinationPlatformVersion;
Var DestinationPlatform;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT)

Var deStringType;                  // Тип("Строка")
Var deBooleanType;                  // Тип("Булево")
Var deNumberType;                   // Тип("Число")
Var deDateType;                    // Тип("Дата")
Var deValueStorageType;       // Тип("ХранилищеЗначения")
Var deUUIDType; // Тип("УникальныйИдентификатор")
Var deBinaryDataType;          // Тип("ДвоичныеДанные")
Var deAccumulationRecordTypeType;   // Тип("ВидДвиженияНакопления")
Var deObjectDeletionType;         // Тип("УдалениеОбъекта")
Var deAccountTypeType;			    // Тип("ВидСчета")
Var deTypeType;			  		    // Тип("Тип")
Var deMapType;		    // Тип("Соответствие").

Var deXMLNodeTypeEndElement  Export;
Var deXMLNodeTypeStartElement Export;
Var deXMLNodeTypeText          Export;

Var BlankDateValue Export;

Var deMessages;             // Соответствие. Ключ - 

Var mExchangeRuleTemplateList Export;


////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCESSING MODULE VARIABLES
 
Var mExportedObjectCounter Export;   // Number - 
Var mSnCounter Export;   // Number - 
Var mPropertyConversionRuleTable;      // ValueTable - 
                                             //                   
Var mXMLRules;                           // Xml-
Var mTypesForDestinationRow;


////////////////////////////////////////////////////////////////////////////////
// IMPORT PROCESSING MODULE VARIABLES
 
Var mImportedObjectCounter Export;// Number - 

Var mExchangeFileAttributes Export;       //  
                                          //  
                                          // 

Var ImportedObjects Export;         // Соответствие. Ключ - 
                                          // 
Var ImportedGlobalObjects Export;
Var ImportedObjectToStoreCount Export;  //  
                                          //  
                                          // 
Var RememberImportedObjects Export;

Var mExtendedSearchParameterMap;
Var mConversionRuleMap; // 

Var mDataImportDataProcessor Export;

Var mEmptyTypeValueMap;
Var mTypeDescriptionMap;

Var mExchangeRulesReadOnImport Export;

Var mDataExportCallStack;

Var mDataTypeMapForImport;

Var mNotWrittenObjectGlobalStack;

Var EventsAfterParametersImport Export;

Var CurrentNestingLevelExportByRule;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES TO STORE STANDARD SUBSYSTEM MODULES

Var ModulePeriodClosingDates;

#EndRegion

#Region Public

#Region StringOperations

// Splits a string into two parts: before the separator substring and after it.
//
// Parameters:
//  Page1          - String - a string to split;
//  Separator  - String - separator substring:
//  Mode        - Number -0 - separator is not included in the returned substrings;
//                        1 - separator is included in the left substring;
//                        2 - separator is included in the right substring.
//
// Returns:
//  String - 
// 
Function SplitWithSeparator(Page1, Val Separator, Mode=0) Export

	RightPart         = "";
	SeparatorPos      = StrFind(Page1, Separator);
	SeparatorLength    = StrLen(Separator);
	If SeparatorPos > 0 Then
		RightPart	 = Mid(Page1, SeparatorPos + ?(Mode=2, 0, SeparatorLength));
		Page1          = TrimAll(Left(Page1, SeparatorPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction

// Converts values from a string to an array using the specified separator.
//
// Parameters:
//   Page1            - String - a string to split.
//   Separator    - String - separator substring.
//
// Returns:
//   Array of String - 
// 
Function ArrayFromString(Val Page1, Separator=",") Export

	Array      = New Array;
	RightPart = SplitWithSeparator(Page1, Separator);
	
	While Not IsBlankString(Page1) Do
		Array.Add(TrimAll(Page1));
		Page1         = RightPart;
		RightPart = SplitWithSeparator(Page1, Separator);
	EndDo; 

	Return Array;
	
EndFunction

// Splits the string into several strings by the separator. The separator can be any length.
//
// Parameters:
//  String                 - String - delimited text;
//  Separator            - String - a text separator, at least 1 character;
//  SkipEmptyStrings - Boolean - indicates whether empty strings must be included in the result.
//    If this parameter is not set, the function executes in compatibility with its earlier version:
//       if space is used as a separator, empty strings are not included in the result, for other separators empty strings
//       are included in the result;
//       if String parameter does not contain significant characters (or it is an empty string)
//       and space is used as a separator, the function returns an array with a single empty string value (""). - if the String parameter does not contain significant characters (or it is an empty string) and
//       any character except space is used as a separator, the function returns an empty array.
//
//
// Returns:
//  Array of String - 
//
// Example:
//  SplitStringIntoSubstringArray(",One,,Two,", ",") - returns an array of 5 elements, three of which are blank
//  strings;
//  SplitStringIntoSubstringArray(",one,,two,", ",", True) - returns an array of two elements;
//  SplitStringIntoSubstringArray(" one   two  ", " ") - returns an array of two elements;
//  SplitStringIntoSubstringArray("") - returns a blank array;
//  SplitStringIntoSubstringArray("",,False) - returns an array of one element "" (blank string);
//  SplitStringIntoSubstringArray - returns an array with an empty string ("");
//
Function SplitStringIntoSubstringsArray(Val String, Val Separator = ",", Val SkipEmptyStrings = Undefined) Export
	
	Result = New Array;
	
	// For backward compatibility purposes.
	If SkipEmptyStrings = Undefined Then
		SkipEmptyStrings = ?(Separator = " ", True, False);
		If IsBlankString(String) Then 
			If Separator = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = StrFind(String, Separator);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipEmptyStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		String = Mid(String, Position + StrLen(Separator));
		Position = StrFind(String, Separator);
	EndDo;
	
	If Not SkipEmptyStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

// Returns a number in the string format, without a symbolic prefix.
// For example:
//  GetStringNumberWithoutPrefixes("TM0000001234") = "0000001234"
//
// Parameters:
//  Number - String - a number, from which the function result must be calculated.
// 
// Returns:
//   String - 
//
Function GetStringNumberWithoutPrefixes(Number) Export
	
	NumberWithoutPrefixes = "";
	Cnt = StrLen(Number);
	
	While Cnt > 0 Do
		
		Char = Mid(Number, Cnt, 1);
		
		If (Char >= "0" And Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Cnt = Cnt - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Splits a string into a prefix and numerical part.
//
// Parameters:
//  Page1            - String - a string to split;
//  NumericalPart  - Number - variable that contains numeric part of the passed string;
//  Mode          - String -  pass Number if you want numeric part to be returned, otherwise pass Prefix.
//
// Returns:
//  String - 
//
Function GetNumberPrefixAndNumericalPart(Val Page1, NumericalPart = "", Mode = "") Export

	NumericalPart = 0;
	Prefix = "";
	Page1 = TrimAll(Page1);
	Length   = StrLen(Page1);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Page1);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Page1, 1, Length - StringPartLength);
	Else
		Prefix = Page1;	
	EndIf;

	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;

EndFunction

// Casts the number (code) to the required length, splitting the number into a prefix and numeric part. The space between the prefix
// and
// number is filled with zeros.
// Can be used in the event handlers whose script 
// is stored in data exchange rules. м.
// The "No links to function found" message during the configuration check 
// is not an error.
//
// Parameters:
//  Page1          - String - a string to convert.
//  Length        - Number - required length of a row.
//  AddZerosIfLengthNotLessCurrentNumberLength - Boolean - indicates that it is necessary to add zeros.
//  Prefix      - String - a prefix to be added to the number.
//
// Returns:
//  String       - 
// 
Function CastNumberToLength(Val Page1, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "") Export

	If IsBlankString(Page1)
		Or StrLen(Page1) = Length Then
		
		Return Page1;
		
	EndIf;
	
	Page1             = TrimAll(Page1);
	IncomingNumberLength = StrLen(Page1);

	NumericalPart   = "";
	StringNumberPrefix   = GetNumberPrefixAndNumericalPart(Page1, NumericalPart);
	
	FinalPrefix = ?(IsBlankString(Prefix), StringNumberPrefix, Prefix);
	ResultingPrefixLength = StrLen(FinalPrefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);

	If (Length >= IncomingNumberLength And AddZerosIfLengthNotLessCurrentNumberLength)
		Or (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - ResultingPrefixLength - NumericPartLength Do
			
			NumericPartString = "0" + NumericPartString;
			
		EndDo;
	
	EndIf;
	
	// 
	NumericPartString = Right(NumericPartString, Length - ResultingPrefixLength);
		
	Result = FinalPrefix + NumericPartString;

	Return Result;

EndFunction

// Adds a substring to a number or code prefix.
// Can be used in the event handlers 
// whose application code is stored in data exchange rules. It is called by the Execute() method.
// The "No links to function found" message during the configuration check  
// s not an error.
//
// Parameters:
//  Page1          - String - a number or code;
//  Additive      - String - a substring to be added to a prefix;
//  Length        - Number - required resulting length of a row;
//  Mode        - String - pass "Left" if you want to add substring from the left, otherwise the substring will be added from the right.
//
// Returns:
//  String       - 
//
Function AddToPrefix(Val Page1, Additive = "", Length = "", Mode = "Left") Export

	Page1 = TrimAll(Format(Page1,"NG=0"));

	If IsBlankString(Length) Then
		Length = StrLen(Page1);
	EndIf;

	NumericalPart   = "";
	Prefix         = GetNumberPrefixAndNumericalPart(Page1, NumericalPart);

	If Mode = "Left" Then
		Result = TrimAll(Additive) + Prefix;
	Else
		Result = Prefix + TrimAll(Additive);
	EndIf;

	While Length - StrLen(Result) - StrLen(Format(NumericalPart, "NG=0")) > 0 Do
		Result = Result + "0";
	EndDo;

	Result = Result + Format(NumericalPart, "NG=0");

	Return Result;

EndFunction

// Supplements string with the specified symbol to the specified length.
//
// Parameters: 
//  Page1          - String - string to be supplemented;
//  Length        - Number - required length of a resulting row;
//  Than          - String - character used for supplementing the string.
//
// Returns:
//  String - 
//
Function odSupplementString(Page1, Length, Than = " ") Export

	Result = TrimAll(Page1);
	While Length - StrLen(Result) > 0 Do
		Result = Result + Than;
	EndDo;

	Return(Result);

EndFunction

#EndRegion

#Region DataOperations

// Returns a string - a name of the passed enumeration value.
// Can be used in the event handlers 
// whose script is stored in data exchange rules. Is called with the Execute() method.
// The "No links to function found" message during 
// the configuration check is not an error.
//
// Parameters:
//  Value - EnumRef - an enumeration value.
//
// Returns:
//   String - 
//
Function deEnumValueName(Value) Export

	MetadataObjectsList = Value.Metadata();
	
	EnumManager = Enums[MetadataObjectsList.Name]; // EnumManager
	ValueIndex = EnumManager.IndexOf(Value);

	Return MetadataObjectsList.EnumValues.Get(ValueIndex).Name;

EndFunction

// Defines whether the passed value is filled.
//
// Parameters:
//  Value       - Arbitrary - CatalogRef, DocumentRef, String or any other type.
//                   Value to be checked.
//  ThisNULL        - Boolean - if the passed value is NULL, this variable is set to True.
//
// Returns:
//   Boolean - 
//
Function deEmpty(Value, ThisNULL=False) Export

	// Primitive types come first.
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		ThisNULL   = True;
		Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	
	If ValueType = deValueStorageType Then
		
		Result = deEmpty(Value.Get());
		Return Result;
		
	ElsIf ValueType = deBinaryDataType Then
		
		Return False;
		
	Else
		
		// 
		// 
		Try
			Return Not ValueIsFilled(Value);
		Except
			// 
			Return False;
		EndTry;
	EndIf;
	
EndFunction

// Returns the TypeDescription object that contains the specified type.
//
// Parameters:
//  TypeValue - String
//               - Type - 
//  
// Returns:
//  TypeDescription - 
//
Function deTypeDetails(TypeValue) Export
	
	TypeDescription = mTypeDescriptionMap[TypeValue];
	
	If TypeDescription = Undefined Then
		
		TypesArray = New Array;
		If TypeOf(TypeValue) = deStringType Then
			TypesArray.Add(Type(TypeValue));
		Else
			TypesArray.Add(TypeValue);
		EndIf; 
		TypeDescription	= New TypeDescription(TypesArray);
		
		mTypeDescriptionMap.Insert(TypeValue, TypeDescription);
		
	EndIf;
	
	Return TypeDescription;
	
EndFunction

// Returns the blank (default) value of the specified type.
//
// Parameters:
//  Type          - String
//               - Type - 
//
// Returns:
//  Arbitrary - 
// 
Function deGetEmptyValue(Type) Export

	EmptyTypeValue = mEmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deTypeDetails(Type).AdjustValue(Undefined);
		mEmptyTypeValueMap.Insert(Type, EmptyTypeValue);
		
	EndIf;
	
	Return EmptyTypeValue;

EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Manager       - CatalogManager
//                 - DocumentManager - 
//  Property       - String - a property to implement the search: Name, Code, 
//                   Description, or a name of an indexed attribute.
//  Value       - String
//                 - Number
//                 - Date - 
//  FoundByUUIDObject - CatalogObject
//                                             - DocumentObject -  
//                   
//  CommonPropertyStructure - Structure - properties of the object to be searched.
//  CommonSearchProperties - Structure
//  SearchByUUIDQueryString - String - a query text for to search by UUID.
//
// Returns:
//  Arbitrary - 
//
Function FindObjectByProperty(Manager, Property, Value,
	FoundByUUIDObject,
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined,
	SearchByUUIDQueryString = "") Export
	
	If CommonPropertyStructure = Undefined Then
		Try
			CurrPropertiesStructure = Managers[TypeOf(Manager.EmptyRef())];
			TypeName = CurrPropertiesStructure.TypeName;
		Except
			TypeName = "";
		EndTry;
	Else
		TypeName = CommonPropertyStructure.TypeName;
	EndIf;
	
	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "Code"
		And (TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes"
		Or TypeName = "ChartOfAccounts"
		Or TypeName = "ExchangePlan"
		Or TypeName = "ChartOfCalculationTypes") Then
		
		Return Manager.FindByCode(Value);
		
	ElsIf Property = "Description"
		And (TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes"
		Or TypeName = "ChartOfAccounts"
		Or TypeName = "ExchangePlan"
		Or TypeName = "ChartOfCalculationTypes"
		Or TypeName = "Task") Then
		
		Return Manager.FindByDescription(Value, True);
		
	ElsIf Property = "Number"
		And (TypeName = "Document"
		Or TypeName = "BusinessProcess"
		Or TypeName = "Task") Then
		
		Return Manager.FindByNumber(Value);
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref = CheckRefExists(RefByUUID, Manager, FoundByUUIDObject,
			SearchByUUIDQueryString);
			
		Return Ref;
		
	ElsIf Property = "{PredefinedItemName1}" Then
		
		Try
			
			Ref = Manager[Value];
			
		Except
			
			Ref = Manager.FindByCode(Value);
			
		EndTry;
		
		Return Ref;
		
	Else
		
		// You can find it only by attribute, except for strings of arbitrary length and value storage.
		If Not (Property = "Date"
			Or Property = "Posted"
			Or Property = "DeletionMark"
			Or Property = "Owner"
			Or Property = "Parent"
			Or Property = "IsFolder") Then
			
			Try
				
				UnlimitedLengthString = IsUnlimitedLengthParameter(CommonPropertyStructure, Value, Property);
				
			Except
				
				UnlimitedLengthString = False;
				
			EndTry;
			
			If Not UnlimitedLengthString Then
				
				Return Manager.FindByAttribute(Property, Value);
				
			EndIf;
			
		EndIf;
		
		ObjectReference = FindItemUsingRequest(CommonPropertyStructure, CommonSearchProperties, , Manager);
		Return ObjectReference;
		
	EndIf;
	
EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Page1            - String - a property value, by which 
//                   an object is searched;
//  Type            - Type - a type of the object to be found;
//  Property       - String - a property name, by which an object is found.
//
// Returns:
//  Arbitrary - 
//
Function deGetValueByString(Page1, Type, Property = "") Export

	If IsBlankString(Page1) Then
		Return New(Type);
	EndIf; 

	Properties = Managers[Type];

	If Properties = Undefined Then
		
		TypeDescription = deTypeDetails(Type);
		Return TypeDescription.AdjustValue(Page1);
		
	EndIf;

	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName1}";
		EndIf;
		
	EndIf;
	
	Return FindObjectByProperty(Properties.Manager, Property, Page1, Undefined);
	
EndFunction

// Returns a string presentation of a value type.
//
// Parameters: 
//  ValueOrType - Arbitrary - a value of any type or Type.
//
// Returns:
//  String - 
//
Function deValueTypeAsString(ValueOrType) Export

	ValueType	= TypeOf(ValueOrType);
	
	If ValueType = deTypeType Then
		ValueType	= ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = deStringType Then
		Result = "String";
	ElsIf ValueType = deNumberType Then
		Result = "Number";
	ElsIf ValueType = deDateType Then
		Result = "Date";
	ElsIf ValueType = deBooleanType Then
		Result = "Boolean";
	ElsIf ValueType = deValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = deUUIDType Then
		Result = "UUID";
	ElsIf ValueType = deAccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
			
			Text= NStr("en = 'Unknown type:';") + String(TypeOf(ValueType));
			MessageToUser(Text);
			
		Else
			Result = Manager.RefTypeString1;
		EndIf;
	EndIf;

	Return Result;
	
EndFunction

// Returns an XML presentation of the TypesDetails object.
// Can be used in the event handlers 
// whose script is stored in data exchange rules.
// Parameters:
//  TypeDescription  - TypeDescription - a TypesDetails object whose XML presentation is being retrieved.
//
// Returns:
//  String - 
//
Function deGetTypesDescriptionXMLPresentation(TypeDescription) Export
	
	TypesNode = CreateNode("Types");
	
	If TypeOf(TypeDescription) = Type("Structure") Then
		SetAttribute(TypesNode, "AllowedSign",          TrimAll(TypeDescription.AllowedSign));
		SetAttribute(TypesNode, "Digits",             TrimAll(TypeDescription.Digits));
		SetAttribute(TypesNode, "FractionDigits", TrimAll(TypeDescription.FractionDigits));
		SetAttribute(TypesNode, "Length",                   TrimAll(TypeDescription.Length));
		SetAttribute(TypesNode, "AllowedLength",         TrimAll(TypeDescription.AllowedLength));
		SetAttribute(TypesNode, "DateComposition",              TrimAll(TypeDescription.DateFractions));
		
		For Each Page1Type In TypeDescription.Types Do
			NodeOfType = CreateNode("Type");
			NodeOfType.WriteText(TrimAll(Page1Type));
			AddSubordinateNode(TypesNode, NodeOfType);
		EndDo;
	Else
		NumberQualifiers       = TypeDescription.NumberQualifiers;
		StringQualifiers      = TypeDescription.StringQualifiers;
		DateQualifiers        = TypeDescription.DateQualifiers;
		
		SetAttribute(TypesNode, "AllowedSign",          TrimAll(NumberQualifiers.AllowedSign));
		SetAttribute(TypesNode, "Digits",             TrimAll(NumberQualifiers.Digits));
		SetAttribute(TypesNode, "FractionDigits", TrimAll(NumberQualifiers.FractionDigits));
		SetAttribute(TypesNode, "Length",                   TrimAll(StringQualifiers.Length));
		SetAttribute(TypesNode, "AllowedLength",         TrimAll(StringQualifiers.AllowedLength));
		SetAttribute(TypesNode, "DateComposition",              TrimAll(DateQualifiers.DateFractions));
		
		For Each Type In TypeDescription.Types() Do
			NodeOfType = CreateNode("Type");
			NodeOfType.WriteText(deValueTypeAsString(Type));
			AddSubordinateNode(TypesNode, NodeOfType);
		EndDo;
	EndIf;
	
	TypesNode.WriteEndElement();
	
	Return(TypesNode.Close());
	
EndFunction

#EndRegion

#Region ProceeduresAndFunctionsToWorkWithXMLObjectWrite

// Replaces prohibited XML characters with other character.
//
// Parameters:
//       Text - String - a text where the characters are to be changed.
//       ReplacementChar - String - a value, by which the illegal characters will be changed.
// Returns:
//       String - 
//
Function ReplaceProhibitedXMLChars(Val Text, ReplacementChar = " ") Export
	
	Position = FindDisallowedXMLCharacters(Text);
	While Position > 0 Do
		Text = StrReplace(Text, Mid(Text, Position, 1), ReplacementChar);
		Position = FindDisallowedXMLCharacters(Text);
	EndDo;
	
	Return Text;
EndFunction

// Creates a new XML node
// Can be used in the event handlers whose script 
// is stored in data exchange rules. Is called with the Execute() method.
//
// Parameters: 
//   Name - String - a node name.
//
// Returns:
//   XMLWriter - 
//
Function CreateNode(Name) Export

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);

	Return XMLWriter;

EndFunction

// Adds a new xml node to the specified parent node.
// Can be used in the event handlers 
// whose script is stored in data exchange rules. Is called with the Execute() method.
// The "No links to function found" message during the configuration check 
// is not an error.
//
// Parameters: 
//  ParentNode1   - XMLWriter - parent XML node.
//  Name            - String - a name of the node to be added.
//
// Returns:
//  XMLWriter - 
//
Function AddNode(ParentNode1, Name) Export

	ParentNode1.WriteStartElement(Name);

	Return ParentNode1;

EndFunction

// Copies the specified xml node.
// Can be used in the event handlers 
// whose script is stored in data exchange rules. Is called with the Execute() method.
// The "No links to function found" message during the configuration check 
// is not an error.
//
// Parameters: 
//  Node - XMLWriter - XML node.
//
// Returns:
//  XMLWriter - 
//
Function CopyNode(Node) Export

	Page1 = Node.Close();

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	If WriteToXMLAdvancedMonitoring Then
		
		Page1 = CommonClientServer.DeleteDisallowedXMLCharacters(Page1);
		
	EndIf;
	
	XMLWriter.WriteRaw(Page1);

	Return XMLWriter;
	
EndFunction

// Writes item and its value to the specified object.
//
// Parameters:
//  Object         - XMLWriter - an object of the XMLWriter type.
//  Name            - String - item name.
//  Value       - Arbitrary - item value.
//
Procedure deWriteElement(Object, Name, Value="") Export

	Object.WriteStartElement(Name);
	Page1 = XMLString(Value);
	
	If WriteToXMLAdvancedMonitoring Then
		
		Page1 =  CommonClientServer.DeleteDisallowedXMLCharacters(Page1);
		
	EndIf;
	
	Object.WriteText(Page1);
	Object.WriteEndElement();
	
EndProcedure

// Subordinates an xml node to the specified parent node.
//
// Parameters: 
//  ParentNode1   - XMLWriter - parent XML node.
//  Node           - XMLWriter - xml node to be subordinated.
//
Procedure AddSubordinateNode(ParentNode1, Node) Export

	If TypeOf(Node) <> deStringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode1.WriteRaw(InformationToWriteToFile);
		
EndProcedure

// Sets an attribute of the specified xml node.
//
// Parameters: 
//  Node           - XMLWriter - XML node
//  Name            - String - attribute name.
//  Value       - Arbitrary - value to be set.
//
Procedure SetAttribute(Node, Name, Value) Export

	RecordRow = XMLString(Value);
	
	If WriteToXMLAdvancedMonitoring Then
		
		RecordRow = CommonClientServer.DeleteDisallowedXMLCharacters(RecordRow);
		
	EndIf;
	
	Node.WriteAttribute(Name, RecordRow);
	
EndProcedure

#EndRegion

#Region ProceeduresAndFunctionsToWorkWithXMLObjectRead

// Reads the attribute value by the name from the specified object, converts the value
// to the specified primitive type.
//
// Parameters:
//  Object      - XMLReader - an object of the XMLReader type positioned at the beginning of the item
//                whose attribute is required.
//  Type         - Type - attribute type.
//  Name         - String - attribute name.
//
// Returns:
//  Arbitrary - 
//
Function deAttribute(Object, Type, Name) Export

	ValueStr = Object.GetAttribute(Name);
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, TrimR(ValueStr));
	ElsIf      Type = deStringType Then
		Return ""; 
	ElsIf Type = deBooleanType Then
		Return False;
	ElsIf Type = deNumberType Then
		Return 0;
	ElsIf Type = deDateType Then
		Return BlankDateValue;
	EndIf;
		
EndFunction
 
// Skips xml nodes to the end of the specified item (which is currently the default one).
//
// Parameters:
//  Object   - XMLReader - an object of the XMLReader type.
//  Name      - String - a name of node, to the end of which items are skipped.
//
Procedure deSkip(Object, Name = "") Export

	AttachmentsCount = 0; // 

	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
			
		If NodeType = deXMLNodeTypeEndElement Then
				
			If AttachmentsCount = 0 Then
					
				Break;
					
			Else
					
				AttachmentsCount = AttachmentsCount - 1;
					
			EndIf;
				
		ElsIf NodeType = deXMLNodeTypeStartElement Then
				
			AttachmentsCount = AttachmentsCount + 1;
				
		EndIf;
					
	EndDo;
	
EndProcedure

// Reads the element text and converts the value to the specified type.
//
// Parameters:
//  Object           - XMLReader - an object of the XMLReader type whose data is read.
//  Type              - Type - type of the return value.
//  SearchByProperty - String - for reference types, you can specify a property, by which.
//                     search for the following object: Code, Description, <AttributeName>, "Name" (of the predefined value).
//  CutStringRight - Boolean - indicates that you need to cut string on the right.
//
// Returns:
//  Arbitrary - 
//
Function deElementValue(Object, Type, SearchByProperty = "", CutStringRight = True) Export

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = deXMLNodeTypeText Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
						
		ElsIf (Object.LocalName = Name) And (NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;

	
	If (Type = deStringType)
		Or (Type = deBooleanType)
		Or (Type = deNumberType)
		Or (Type = deDateType)
		Or (Type = deValueStorageType)
		Or (Type = deUUIDType)
		Or (Type = deAccumulationRecordTypeType)
		Or (Type = deAccountTypeType) Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf;
	
EndFunction

#EndRegion

#Region ExchangeFileOperationsProceduresAndFunctions

// Saves the specified xml node to file.
//
// Parameters:
//  Node - XMLWriter - XML node to be saved to the file.
//
Procedure WriteToFile(Node) Export

	If TypeOf(Node) <> deStringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If DirectReadingInDestinationIB Then
		
		ErrorStringInDestinationInfobase = "";
		SendWriteInformationToDestination(InformationToWriteToFile, ErrorStringInDestinationInfobase);
		If Not IsBlankString(ErrorStringInDestinationInfobase) Then
			
			Raise ErrorStringInDestinationInfobase;
			
		EndIf;
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfExchangeProtocolOperations

// Returns a Structure type object containing all possible fields of
// the execution protocol record (such as error messages and others).
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//
// Returns:
//  Structure - 
//
Function GetProtocolRecordStructure(MessageCode = "", ErrorString = "") Export

	ErrorStructure = New Structure(
		"OCRName,
		|DPRName,
		|NBSp,
		|Gsn,
		|Source,
		|ObjectType,
		|Property,
		|Value,
		|ValueType,
		|OCR,
		|PCR,
		|PGCR,
		|DER,
		|DPR,
		|Object,
		|DestinationProperty,
		|ConvertedValue,
		|Handler,
		|ErrorDescription,
		|ModulePosition,
		|Text,
		|MessageCode,
		|ExchangePlanNode");
	
	ModuleString = SplitWithSeparator(ErrorString, "{");
	If IsBlankString(ErrorString) Then
		ErrorDescription = TrimAll(SplitWithSeparator(ModuleString, "}:"));
	Else
		ErrorDescription = ErrorString;
		ModuleString   = "{" + ModuleString;
	EndIf;
	
	If ErrorDescription <> "" Then
		ErrorStructure.ErrorDescription = ErrorDescription;
		ErrorStructure.ModulePosition  = ModuleString;
	EndIf;
	
	If ErrorStructure.MessageCode <> "" Then
		
		ErrorStructure.MessageCode = MessageCode;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

// Writes error details to the exchange protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  Object - Arbitrary - object, which the error is related to.
//  ObjectType - Type - type of the object, which the error is related to.
//
// Returns:
//  String - 
//
Function WriteErrorInfoToProtocol(MessageCode, ErrorString, Object, ObjectType = Undefined) Export
	
	WP         = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.Object  = Object;
	
	If ObjectType <> Undefined Then
		WP.ObjectType     = ObjectType;
	EndIf;	
		
	ErrorString = WriteToExecutionProtocol(MessageCode, WP);	
	
	Return ErrorString;	
	
EndFunction

// Registers the error of object conversion rule handler (import) in the execution protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  RuleName - String - a name of an object conversion rule.
//  Source - Arbitrary - source, which conversion caused an error.
//  ObjectType - Type - type of the object, which conversion caused an error.
//  Object - Arbitrary - an object received as a result of conversion.
//  HandlerName - String - name of the handler where an error occurred.
//
Procedure WriteInfoOnOCRHandlerImportError(MessageCode, ErrorString, RuleName, Source,
	ObjectType, Object, HandlerName) Export
	
	WP            = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.OCRName     = RuleName;
	WP.ObjectType = ObjectType;
	WP.Handler = HandlerName;
	
	If Not IsBlankString(Source) Then
		
		WP.Source = Source;
		
	EndIf;
	
	If Object <> Undefined Then
		
		WP.Object = String(Object);
		
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not FlagDebugMode Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

// Registers the error of property conversion rule handler in the execution protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  OCR - ValueTableRow - object conversion rule.
//  PCR - ValueTableRow - a property conversion rule.
//  Source - Arbitrary - source, which conversion caused an error. 
//  HandlerName - String - name of the handler where an error occurred.
//  Value - Arbitrary - value, which conversion caused an error.
//  IsPCR - Boolean - an error occurred when processing the rule of property conversion.
//
Procedure WriteErrorInfoPCRHandlers(MessageCode, ErrorString, OCR, PCR, Source = "", 
	HandlerName = "", Value = Undefined, IsPCR = True) Export
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	RuleName = PCR.Name + "  (" + PCR.Description + ")";
	If IsPCR Then
		WP.PCR                = RuleName;
	Else
		WP.PGCR               = RuleName;
	EndIf;
	
	TypeDescription = New TypeDescription("String");
	StringSource  = TypeDescription.AdjustValue(Source);
	If Not IsBlankString(StringSource) Then
		WP.Object = StringSource + "  (" + TypeOf(Source) + ")";
	Else
		WP.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	If IsPCR Then
		WP.DestinationProperty      = PCR.Receiver + "  (" + PCR.DestinationType + ")";
	EndIf;
	
	If HandlerName <> "" Then
		WP.Handler         = HandlerName;
	EndIf;
	
	If Value <> Undefined Then
		WP.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not FlagDebugMode Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure

#EndRegion

#Region GeneratingHandlerCallInterfacesInExchangeRulesProcedures

// Complements existing collections with rules for exchanging handler call interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  OCRTable           - ValueTable - contains object conversion rules.
//  DERTable           - ValueTree - contains the data export rules.
//  DPRTable           - ValueTree - contains data clearing rules.
//  
Procedure SupplementRulesWithHandlerInterfaces(ConversionStructure, OCRTable, DERTable, DPRTable) Export
	
	mHandlerParameterTemplate = GetTemplate("HandlersParameters");
	
	// Adding the Conversion interfaces (global.
	SupplementWithConversionRuleInterfaceHandler(ConversionStructure);
	
	// Adding the DER interfaces
	SupplementDataExportRulesWithHandlerInterfaces(DERTable, DERTable.Rows);
	
	// Add DPR interfaces.
	SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, DPRTable.Rows);
	
	// Adding OCR, PCR, PGCR interfaces.
	SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable);
	
EndProcedure 

#EndRegion

#Region ExchangeRulesOperationProcedures

// Searches for the conversion rule by name or according to
// the passed object type.
//
// Parameters:
//   Object - Arbitrary - a source object whose conversion rule will be searched.
//   RuleName - String - a conversion rule name.
//
// Returns:
//   ValueTableRow - 
//     * Name - String
//     * Description - String
//     * Source - String
//     * Properties - See PropertiesConversionRulesCollection
// 
Function FindRule(Object = Undefined, RuleName = "") Export

	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName]; // See FindRule
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule = Rule.OCR; // See FindRule
			
			If Rule <> Undefined Then
				RuleName = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Saves exchange rules in the internal format.
//
Procedure SaveRulesInInternalFormat() Export

	For Each Rule In ConversionRulesTable Do
		Rule.Exported_.Clear();
		Rule.OnlyRefsExported.Clear();
	EndDo;

	RulesStructure = RulesStructureDetails();
	
	// Save queries.
	QueriesToSave = New Structure;
	For Each StructureItem In Queries Do
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
	EndDo;

	ParametersToSave = New Structure;
	For Each StructureItem In Parameters Do
		ParametersToSave.Insert(StructureItem.Key, Undefined);
	EndDo;

	RulesStructure.ExportRulesTable = ExportRulesTable;
	RulesStructure.ConversionRulesTable = ConversionRulesTable;
	RulesStructure.Algorithms = Algorithms;
	RulesStructure.Queries = QueriesToSave;
	RulesStructure.Conversion = Conversion;
	RulesStructure.mXMLRules = mXMLRules;
	RulesStructure.ParametersSetupTable = ParametersSetupTable;
	RulesStructure.Parameters = ParametersToSave;
	
	RulesStructure.Insert("DestinationPlatformVersion",   DestinationPlatformVersion);
	
	SavedSettings  = New ValueStorage(RulesStructure);
	
EndProcedure

// Sets parameter values in the Parameters structure 
// by the ParametersSetupTable table.
//
Procedure SetParametersFromDialog() Export

	For Each TableRow In ParametersSetupTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;

EndProcedure

// Sets the parameter value in the parameter table as a handler.
//
// Parameters:
//   ParameterName - String - a parameter name.
//   ParameterValue - Arbitrary - a parameter value.
//
Procedure SetParameterValueInTable(ParameterName, ParameterValue) Export
	
	TableRow = ParametersSetupTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue;	
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ClearingRuleProcessing

// Deletes (or marks for deletion) a selection object according to the specified rule.
//
// Parameters:
//  Object         - Arbitrary - selection object to be deleted (or whose deletion mark will be set).
//  Rule        - ValueTableRow - data clearing rule reference.
//  Properties       - Structure - metadata object properties of the object to be deleted.
//  IncomingData - Arbitrary - arbitrary auxiliary data.
// 
Procedure SelectionObjectDeletion(Object, Rule, Properties=Undefined, IncomingData=Undefined) Export

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Cancel                  = False;
	DeleteDirectly = Rule.Directly;
	
	
	// BeforeSelectionObjectDeletion handler
	If Not IsBlankString(Rule.BeforeDeleteRow) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeDeleteRow"));
				
			Else
				
				Execute(Rule.BeforeDeleteRow);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(29, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, Object, "BeforeDeleteSelectionObject");
			
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;
	
	
	Try
		
		ExecuteObjectDeletion(Object, Properties, DeleteDirectly);
		
	Except
		
		WriteDataClearingHandlerErrorInfo(24, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
			Rule.Name, Object, "");
		
	EndTry;

EndProcedure

#EndRegion

#Region DataExportProcedures

// Exports an object according to the specified conversion rule.
//
// Parameters:
//  Source				 - Arbitrary - data source.
//  Receiver				 - XMLWriter - a destination object XML node.
//  IncomingData			 - Arbitrary - auxiliary data 
//                             to execute conversion.
//  OutgoingData			 - Arbitrary - arbitrary auxiliary data passed to
//                             property conversion rules.
//  OCRName					 - String - a name of the conversion rule used to execute export.
//  RefNode				 - XMLWriter - a destination object reference XML node.
//  GetRefNodeOnly - Boolean - if True, the object is not exported 
//                             but the reference XML node is generated.
//  OCR						 - ValueTableRow - a row of table of conversion rules.
//  IsRuleWithGlobalObjectExport - Boolean - a flag of a rule with global object export.
//  SelectionForDataExport - QueryResultSelection - a selection containing data for export. 
//
// Returns:
//   XMLWriter - 
//
Function ExportByRule(Source					= Undefined,
						   Receiver					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "",
						   RefNode				= Undefined,
						   GetRefNodeOnly	= False,
						   OCR						= Undefined,
						   IsRuleWithGlobalObjectExport = False,
						   SelectionForDataExport = Undefined) Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Search for OCR.
	If OCR = Undefined Then
		
		OCR = FindRule(Source, OCRName);
		
	ElsIf (Not IsBlankString(OCRName))
		And OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
				
	EndIf;	
	
	If OCR = Undefined Then
		
		WP = GetProtocolRecordStructure(45);
		
		WP.Object = Source;
		WP.ObjectType = TypeOf(Source);
		
		WriteToExecutionProtocol(45, WP, True); // 
		Return Undefined;
		
	EndIf;

	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
	
	If CommentObjectProcessingFlag Then
		
		TypeDetails = New TypeDescription("String");
		SourceToString = TypeDetails.AdjustValue(Source);
		SourceToString = ?(SourceToString = "", " ", SourceToString);
		
		ObjectRul = SourceToString + "  (" + TypeOf(Source) + ")";
		
		OCRNameString = " OCR: " + TrimAll(OCRName) + "  (" + TrimAll(OCR.Description) + ")";
		
		StringForUser = ?(GetRefNodeOnly, NStr("en = 'Converting object reference: %1';"), NStr("en = 'Converting object: %1';"));
		StringForUser = SubstituteParametersToString(StringForUser, ObjectRul);
		
		WriteToExecutionProtocol(StringForUser + OCRNameString, , False, CurrentNestingLevelExportByRule + 1, 7);
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = ExecuteDataExchangeInOptimizedFormat And OCR.UseQuickSearchOnImport;

    RememberExportedData       = OCR.RememberExportedData;
	ExportedObjects          = OCR.Exported_;
	ExportedObjectsOnlyRefs = OCR.OnlyRefsExported;
	AllObjectsExported         = OCR.AllObjectsExported;
	DontReplaceObjectOnImport = OCR.NotReplace;
	DontCreateIfNotFound     = OCR.DontCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly     = OCR.OnExchangeObjectByRefSetGIUDOnly;
	
	AutonumberingPrefix		= "";
	WriteMode     			= "";
	PostingMode 			= "";
	TempFileList = Undefined;

   	TypeName          = "";
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf;
	
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;

	// DataToExportKey
	
	If (Source <> Undefined) And RememberExportedData Then
		If TypeName = "InformationRegister" Or TypeName = "Constants" Or IsBlankString(TypeName) Then
			RememberExportedData = False;
		Else
			DataToExportKey = ValueToStringInternal(Source);
		EndIf;
	Else
		DataToExportKey = OCRName;
		RememberExportedData = False;
	EndIf;
	
	
	// Variable for storing the predefined item name.
	PredefinedItemName1 = Undefined;

	// BeforeObjectConversion global handler.
    Cancel = False;	
	If HasBeforeConvertObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeConvertObject"));

			Else
				
				Execute(Conversion.BeforeConvertObject);
				
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (global-level)';");
			WriteInfoOnOCRHandlerExportError(64, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, Source, SubstituteParametersToString(HandlerName, "BeforeConvertObject"));
				
		EndTry;
		
		If Cancel Then	//	
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If OCR.HasBeforeExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "BeforeExport"));
				
			Else
				
				Execute(OCR.BeforeExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(41, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, Source, "BeforeExportObject");
		EndTry;
		
		If Cancel Then	//	
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	// Perhaps this data has already been exported.
	If Not AllObjectsExported Then
		
		NBSp = 0;
		
		If RememberExportedData Then
			
			RefNode = ExportedObjects[DataToExportKey];
			If RefNode <> Undefined Then
				
				If GetRefNodeOnly Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				EndIf;
				
				ExportedRefNumber = ExportedObjectsOnlyRefs[DataToExportKey];
				If ExportedRefNumber = Undefined Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				Else
					
					ExportStackRow = DataExportCallStackCollection().Find(DataToExportKey, "Ref");
				
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return RefNode;
					EndIf;
					
					ExportStackRow = DataExportCallStackCollection().Add();
					ExportStackRow.Ref = DataToExportKey;
					
					NBSp = ExportedRefNumber;
				EndIf;
			EndIf;
			
		EndIf;
		
		If NBSp = 0 Then
			
			mSnCounter = mSnCounter + 1;
			NBSp         = mSnCounter;
			
		EndIf;
		
		// Preventing cyclic reference existence.
		If RememberExportedData Then
			
			ExportedObjects[DataToExportKey] = NBSp;
			If GetRefNodeOnly Then
				ExportedObjectsOnlyRefs[DataToExportKey] = NBSp;
			Else
				
				ExportStackRow = DataExportCallStackCollection().Add();
				ExportStackRow.Ref = DataToExportKey;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ValueMap = OCR.Values;
	ValueMapItemCount = ValueMap.Count();
	
	// Predefined item map processing.
	If DestinationPlatform = "V8" Then
		
		// If the name of predefined item is not defined yet, attempting to define it.
		If PredefinedItemName1 = Undefined Then
			
			If PropertyStructure <> Undefined
				And ValueMapItemCount > 0
				And PropertyStructure.SearchByPredefinedItemsPossible Then
			
				Try
					PredefinedNameSource = PredefinedItemName(Source);
				Except
					PredefinedNameSource = "";
				EndTry;
				
			Else
				
				PredefinedNameSource = "";
				
			EndIf;
			
			If Not IsBlankString(PredefinedNameSource)
				And ValueMapItemCount > 0 Then
				
				PredefinedItemName1 = ValueMap[Source];
				
			Else
				PredefinedItemName1 = Undefined;
			EndIf;
			
		EndIf;
		
		If PredefinedItemName1 <> Undefined Then
			ValueMapItemCount = 0;
		EndIf;
		
	Else
		PredefinedItemName1 = Undefined;
	EndIf;
	
	DontExportByValueMap = (ValueMapItemCount = 0);
	
	If Not DontExportByValueMap Then
		
		// Если нет объекта в соответствии значений - 
		RefNode = ValueMap[Source];
		If RefNode = Undefined
			And OCR.SearchProperties.Count() > 0 Then
			
			// 
			// 
			If PropertyStructure.TypeName = "Enum"
				And StrFind(OCR.Receiver, "EnumRef.") > 0 Then
				
				RefNode = "";
				
			Else
						
				DontExportByValueMap = True;	
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	MustRememberObject = RememberExportedData And (Not AllObjectsExported);

	If DontExportByValueMap Then
		
		If OCR.SearchProperties.Count() > 0 
			Or PredefinedItemName1 <> Undefined Then
			
			//	
			RefNode = CreateNode("Ref");
			
			If MustRememberObject Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(RefNode, "Gsn", NBSp);
				Else
					SetAttribute(RefNode, "NBSp", NBSp);
				EndIf;
				
			EndIf;
			
			ExportRefOnly = OCR.DontExportPropertyObjectsByRefs Or GetRefNodeOnly;
			
			If DontCreateIfNotFound Then
				SetAttribute(RefNode, "DontCreateIfNotFound", DontCreateIfNotFound);
			EndIf;
			
			If OnExchangeObjectByRefSetGIUDOnly Then
				SetAttribute(RefNode, "OnExchangeObjectByRefSetGIUDOnly", OnExchangeObjectByRefSetGIUDOnly);
			EndIf;
			
			ExportProperties(Source, Receiver, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
				RefNode, SelectionForDataExport, PredefinedItemName1, ExportRefOnly);
			
			RefNode.WriteEndElement();
			RefNode = RefNode.Close();
			
			If MustRememberObject Then
				
				ExportedObjects[DataToExportKey] = RefNode;
				
			EndIf;
			
		Else
			RefNode = NBSp;
		EndIf;
		
	Else
		
		// Searching in the value map by VCR.
		If RefNode = Undefined Then
			// If cannot find by value Map, try to find by search properties.
			RecordStructure = New Structure("Source,SourceType", Source, TypeOf(Source));
			WriteToExecutionProtocol(71, RecordStructure);
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Undefined;
		EndIf;
		
		If RememberExportedData Then
			ExportedObjects[DataToExportKey] = RefNode;
		EndIf;
		
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;
	
	If GetRefNodeOnly Or AllObjectsExported Then
	
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;

	If Receiver = Undefined Then
		
		Receiver = CreateNode("Object");
		
		If IsRuleWithGlobalObjectExport Then
			SetAttribute(Receiver, "Gsn", NBSp);
		Else
			SetAttribute(Receiver, "NBSp", NBSp);
		EndIf;
		
		SetAttribute(Receiver, "Type", 			OCR.Receiver);
		SetAttribute(Receiver, "RuleName",	OCR.Name);
		
		If DontReplaceObjectOnImport Then
			SetAttribute(Receiver, "NotReplace",	"true");
		EndIf;
		
		If Not IsBlankString(AutonumberingPrefix) Then
			SetAttribute(Receiver, "AutonumberingPrefix",	AutonumberingPrefix);
		EndIf;
		
		If Not IsBlankString(WriteMode) Then
			SetAttribute(Receiver, "WriteMode",	WriteMode);
			If Not IsBlankString(PostingMode) Then
				SetAttribute(Receiver, "PostingMode",	PostingMode);
			EndIf;
		EndIf;
		
		If TypeOf(RefNode) <> deNumberType Then
			AddSubordinateNode(Receiver, RefNode);
		EndIf; 
		
	EndIf;

	// OnExport handler
	StandardProcessing = True;
	Cancel = False;
	
	If OCR.HasOnExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "OnExport"));
				
			Else
				
				Execute(OCR.OnExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(42, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, Source, "OnExportObject");
		EndTry;
		
		If Cancel Then	//	
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
		EndIf;
		
	EndIf;

	// Export properties.
	If StandardProcessing Then
		
		ExportProperties(Source, Receiver, IncomingData, OutgoingData, OCR, OCR.Properties, , SelectionForDataExport, ,
			OCR.DontExportPropertyObjectsByRefs Or GetRefNodeOnly, TempFileList);
			
	EndIf;
	
	// AfterExport handler
	If OCR.HasAfterExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExport"));
				
			Else
				
				Execute(OCR.AfterExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(43, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, Source, "AfterExportObject");
		EndTry;
		
		If Cancel Then	//	
			
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
			
		EndIf;
		
	EndIf;
	
	If TempFileList = Undefined Then
	
		//	
		Receiver.WriteEndElement();
		WriteToFile(Receiver);
		
	Else
		
		WriteToFile(Receiver);
		
		TransferDataFromTemporaryFiles(TempFileList);
		
		WriteToFile("</Object>");
		
	EndIf;
	
	mExportedObjectCounter = 1 + mExportedObjectCounter;
	
	If MustRememberObject Then
				
		If IsRuleWithGlobalObjectExport Then
			ExportedObjects[DataToExportKey] = NBSp;
		EndIf;
		
	EndIf;
	
	If ExportStackRow <> Undefined Then
		mDataExportCallStack.Delete(ExportStackRow);
	EndIf;
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
	
	// AfterExportToFile handler
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExportToFile"));
				
			Else
				
				Execute(OCR.AfterExportToFile);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(76, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, Source, "HasAfterExportToFileHandler");
		EndTry;
				
	EndIf;
	
	Return RefNode;

EndFunction

// Returns the fragment of query language text that expresses the restriction condition to date interval.
//
// Parameters:
//   Properties - Structure - metadata object properties.
//   TypeName - String - type name.
//   TableGroupName - String - a table group name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//
// Returns:
//     String - 
//
Function GetRestrictionByDateStringForQuery(Properties, TypeName, TableGroupName = "", SelectionForDataClearing = False) Export
	
	ResultingRestrictionByDate = "";
	
	If Not (TypeName = "Document" Or TypeName = "InformationRegister") Then
		Return ResultingRestrictionByDate;
	EndIf;
	
	If TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodic3;
		RestrictionByDateNotRequired = SelectionForDataClearing	Or Nonperiodical;
		
		If RestrictionByDateNotRequired Then
			Return ResultingRestrictionByDate;
		EndIf;
				
	EndIf;	
	
	If IsBlankString(TableGroupName) Then
		RestrictionFieldName = ?(TypeName = "Document", "Date", "Period");
	Else
		RestrictionFieldName = TableGroupName + "." + ?(TypeName = "Document", "Date", "Period");
	EndIf;
	
	If StartDate <> BlankDateValue Then
		
		ResultingRestrictionByDate = "
		|	WHERE
		|		" + RestrictionFieldName + " >= &StartDate";
		
	EndIf;
		
	If EndDate <> BlankDateValue Then
		
		If IsBlankString(ResultingRestrictionByDate) Then
			
			ResultingRestrictionByDate = "
			|	WHERE
			|		" + RestrictionFieldName + " <= &EndDate";
			
		Else
			
			ResultingRestrictionByDate = ResultingRestrictionByDate + "
			|	And
			|		" + RestrictionFieldName + " <= &EndDate";
			
		EndIf;
		
	EndIf;
	
	Return ResultingRestrictionByDate;
	
EndFunction

// Generates the query result for data clearing export.
// 
// Parameters:
//   Properties - See ManagerParametersStructure.
//   TypeName - String - type name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//   DeleteObjectsDirectly - Boolean - a flag showing whether direct deletion is required.
//   SelectAllFields - Boolean - indicates whether it is necessary to select all fields.
//
// Returns:
//   QueryResult, Undefined - 
//
Function GetQueryResultForExportDataClearing(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	PermissionRow = ?(ExportAllowedObjectsOnly, " ALLOWED ", ""); // @Query-part-1
	FieldSelectionString = ?(SelectAllFields, " * ", " ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes" 
		Or TypeName = "ChartOfAccounts" 
		Or TypeName = "ChartOfCalculationTypes" 
		Or TypeName = "AccountingRegister"
		Or TypeName = "ExchangePlan"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		Query = New Query;
		
		If TypeName = "Catalog" Then
			ObjectsMetadata = Metadata.Catalogs[Properties.Name];
		ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		    ObjectsMetadata = Metadata.ChartsOfCharacteristicTypes[Properties.Name];
		ElsIf TypeName = "ChartOfAccounts" Then
		    ObjectsMetadata = Metadata.ChartsOfAccounts[Properties.Name];
		ElsIf TypeName = "ChartOfCalculationTypes" Then
		    ObjectsMetadata = Metadata.ChartsOfCalculationTypes[Properties.Name];
		ElsIf TypeName = "AccountingRegister" Then
		    ObjectsMetadata = Metadata.AccountingRegisters[Properties.Name];
		ElsIf TypeName = "ExchangePlan" Then
		    ObjectsMetadata = Metadata.ExchangePlans[Properties.Name];
		ElsIf TypeName = "Task" Then
		    ObjectsMetadata = Metadata.Tasks[Properties.Name];
		ElsIf TypeName = "BusinessProcess" Then
		    ObjectsMetadata = Metadata.BusinessProcesses[Properties.Name];
		EndIf;
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = " * ";
			TableNameForSelection = Properties.Name + ".RecordsWithExtDimensions";
			
		Else
			
			TableNameForSelection = Properties.Name;
			
			If ExportAllowedObjectsOnly
				And Not SelectAllFields Then
				
				FirstAttributeName = GetFirstMetadataAttributeName(ObjectsMetadata);
				If Not IsBlankString(FirstAttributeName) Then
					FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Query.Text =
		"SELECT ALLOWED
		| *
		|FROM
		|	&MetadataTableName AS ObjectForExport";
		
		If IsBlankString(PermissionRow) Then
			
			Query.Text = StrReplace(Query.Text, "SELECT ALLOWED", "SELECT");
			
		EndIf;
		
		If TrimAll(FieldSelectionString) <> "*" Then
			
			Query.Text = StrReplace(Query.Text, "*", FieldSelectionString);
			
		EndIf;
		
		RowNameOfTheMetadataTable = SubstituteParametersToString("%1.%2", TypeName, TableNameForSelection);
		Query.Text = StrReplace(Query.Text, "&MetadataTableName", RowNameOfTheMetadataTable);
		
	ElsIf TypeName = "Document" Then
		
		If ExportAllowedObjectsOnly Then
			
			FirstAttributeName = GetFirstMetadataAttributeName(Metadata.Documents[Properties.Name]);
			If Not IsBlankString(FirstAttributeName) Then
				FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
			EndIf;
			
		EndIf;
		
		ResultingRestrictionByDate = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
		
		Query = New Query;
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		Query.Text =
		"SELECT ALLOWED
		| *
		|FROM
		|	&MetadataTableName AS ObjectForExport";
		
		If IsBlankString(PermissionRow) Then
			
			Query.Text = StrReplace(Query.Text, "SELECT ALLOWED", "SELECT");
			
		EndIf;
		
		If TrimAll(FieldSelectionString) <> "*" Then
			
			Query.Text = StrReplace(Query.Text, "*", FieldSelectionString);
			
		EndIf;
		
		RowNameOfTheMetadataTable = SubstituteParametersToString("%1.%2", TypeName, Properties.Name);
		Query.Text = StrReplace(Query.Text, "&MetadataTableName", RowNameOfTheMetadataTable);
		Query.Text = Query.Text + Chars.LF + ResultingRestrictionByDate;
		
	ElsIf TypeName = "InformationRegister" Then
		
		ResultingRestrictionByDate = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
		
		Query = New Query;
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		Query.Text =
		"SELECT ALLOWED
		| *
		|
		|,NULL AS Active
		|,NULL AS Recorder
		|,NULL AS LineNumber
		|,NULL AS Period
		|
		|FROM
		|	&MetadataTableName AS ObjectForExport";
		
		If Properties.SubordinateToRecorder Then
			
			Query.Text = StrReplace(Query.Text, ",NULL AS Active", "");
			Query.Text = StrReplace(Query.Text, ",NULL AS Recorder", "");
			Query.Text = StrReplace(Query.Text, ",NULL AS LineNumber", "");
			
		EndIf;
		
		If Properties.Periodic3 Then
			
			Query.Text = StrReplace(Query.Text, ",NULL AS Period", "");
			
		EndIf;
		
		If IsBlankString(PermissionRow) Then
			
			Query.Text = StrReplace(Query.Text, "SELECT ALLOWED", "SELECT");
			
		EndIf;
		
		RowNameOfTheMetadataTable = SubstituteParametersToString("%1.%2", TypeName, Properties.Name);
		Query.Text = StrReplace(Query.Text, "&MetadataTableName", RowNameOfTheMetadataTable);
		Query.Text = Query.Text + Chars.LF + ResultingRestrictionByDate;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Query.Execute();
	
EndFunction

// Generates selection for data clearing export.
//
// Parameters:
//   Properties - Structure - metadata object properties.
//   TypeName - String - type name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//   DeleteObjectsDirectly - Boolean - indicates whether it is required to delete directly.
//   SelectAllFields - Boolean - indicates whether it is necessary to select all fields.
//
// Returns:
//   QueryResultSelection - 
//
Function GetSelectionForDataClearingExport(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForExportDataClearing(Properties, TypeName, 
			SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
			
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
			
	Selection = QueryResult.Select();
	
	Return Selection;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsToExport

// Fills in the passed values table with object types of metadata for deletion having the access right for
// deletion.
//
// Parameters:
//   DataTable - ValueTable - a table to fill in.
//
Procedure FillTypeAvailableToDeleteList(DataTable) Export
	
	DataTable.Clear();
	
	For Each MetadataObjectsList In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "CatalogRef." + MetadataObjectsList.Name;
		
	EndDo;

	For Each MetadataObjectsList In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "ChartOfCharacteristicTypesRef." + MetadataObjectsList.Name;
	EndDo;

	For Each MetadataObjectsList In Metadata.Documents Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "DocumentRef." + MetadataObjectsList.Name;
	EndDo;

	For Each MetadataObjectsList In Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MetadataObjectsList) Then
			Continue;
		EndIf;
		
		Subordinate		=	(MetadataObjectsList.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "InformationRegisterRecord." + MetadataObjectsList.Name;
		
	EndDo;
	
EndProcedure

// Sets mark value in subordinate tree rows
// according to the mark value in the current row.
//
// Parameters:
//  CurRow      - ValueTreeRow - a string, subordinate lines of which are to be processed.
//  Attribute       - String - a name of an attribute, which contains the mark.
// 
Procedure SetSubordinateMarks(CurRow, Attribute) Export

	SubordinateItems = CurRow.Rows;

	If SubordinateItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each String In SubordinateItems Do
		
		If String.BuilderSettings = Undefined 
			And Attribute = "UseFilter1" Then
			
			String[Attribute] = 0;
			
		Else
			
			String[Attribute] = CurRow[Attribute];
			
		EndIf;
		
		SetSubordinateMarks(String, Attribute);
		
	EndDo;
		
EndProcedure

// Sets the mark status for parent rows of the value tree row.
// depending on the mark of the current row.
//
// Parameters:
//  CurRow      - ValueTreeRow - a string, parent lines of which are to be processed.
//  Attribute       - String - a name of an attribute, which contains the mark.
// 
Procedure SetParentMarks(CurRow, Attribute) Export

	Parent = CurRow.Parent;
	If Parent = Undefined Then
		Return;
	EndIf; 

	CurState       = Parent[Attribute];

	EnabledItemsFound  = False;
	DisabledItemsFound = False;

	If Attribute = "UseFilter1" Then
		
		For Each String In Parent.Rows Do
			
			If String[Attribute] = 0 
				And String.BuilderSettings <> Undefined Then
				
				DisabledItemsFound = True;
				
			ElsIf String[Attribute] = 1 Then
				EnabledItemsFound  = True;
			EndIf; 
			
			If EnabledItemsFound And DisabledItemsFound Then
				Break;
			EndIf; 
			
		EndDo;
		
	Else
		
		For Each String In Parent.Rows Do
			If String[Attribute] = 0 Then
				DisabledItemsFound = True;
			ElsIf String[Attribute] = 1
				Or String[Attribute] = 2 Then
				EnabledItemsFound  = True;
			EndIf; 
			If EnabledItemsFound And DisabledItemsFound Then
				Break;
			EndIf; 
		EndDo;
		
	EndIf;

	
	If EnabledItemsFound And DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound And (Not DisabledItemsFound) Then
		Enable = 1;
	ElsIf (Not EnabledItemsFound) And DisabledItemsFound Then
		Enable = 0;
	ElsIf (Not EnabledItemsFound) And (Not DisabledItemsFound) Then
		Enable = 2;
	EndIf;

	If Enable = CurState Then
		Return;
	Else
		Parent[Attribute] = Enable;
		SetParentMarks(Parent, Attribute);
	EndIf; 
	
EndProcedure

// Generates the full path to a file from the directory path and the file name.
//
// Parameters:
//  DirectoryName  - String - the path to the directory that contains the file.
//  FileName     - String - the file name.
//
// Returns:
//   String - 
//
Function GetExchangeFileName(DirectoryName, FileName) Export

	If Not IsBlankString(FileName) Then
		
		Return DirectoryName + ?(Right(DirectoryName, 1) = "\", "", "\") + FileName;	
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

// Passed the data string to import in the destination base.
//
// Parameters:
//  InformationToWriteToFile - String - a data string (XML text).
//  ErrorStringInDestinationInfobase - String - contains error description upon import to the destination infobase.
// 
Procedure SendWriteInformationToDestination(InformationToWriteToFile, ErrorStringInDestinationInfobase = "") Export
	
	mDataImportDataProcessor.ExchangeFile.SetString(InformationToWriteToFile);
	
	mDataImportDataProcessor.RunReadingData(ErrorStringInDestinationInfobase);
	
	If Not IsBlankString(ErrorStringInDestinationInfobase) Then
		
		MessageString = SubstituteParametersToString(NStr("en = 'Importing in destination: %1';"), ErrorStringInDestinationInfobase);
		WriteToExecutionProtocol(MessageString, Undefined, True, , , True);
		
	EndIf;
	
EndProcedure

// Writes a name, a type, and a value of the parameter to an exchange message file. This data is sent to the destination infobase.
//
// Parameters:
//   Name                          - String - a parameter name.
//   InitialParameterValue    - Arbitrary - a parameter value.
//   ConversionRule           - String - a conversion rule name for reference types.
// 
Procedure SendOneParameterToDestination(Name, InitialParameterValue, ConversionRule = "") Export
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", deValueTypeAsString(InitialParameterValue));
		
		ThisNULL = False;
		Empty = deEmpty(InitialParameterValue, ThisNULL);
					
		If Empty Then
			
			// Writing the empty value.
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
	
		deWriteElement(ParameterNode, "Value", InitialParameterValue);
	
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		ThisNULL = False;
		Empty = deEmpty(InitialParameterValue, ThisNULL);
					
		If Empty Then
			
			PropertiesOCR = FindRule(InitialParameterValue, ConversionRule);
			DestinationType  = PropertiesOCR.Receiver;
			SetAttribute(ParameterNode, "Type", DestinationType);
			
			// Writing the empty value.
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
		
		ExportRefObjectData(InitialParameterValue, Undefined, ConversionRule, Undefined, Undefined, ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);				
		
	EndIf;	
	
EndProcedure

#EndRegion

#Region SetAttributesValuesAndDataProcessorModalVariables

// Returns the current value of the data processor version.
//
// Returns:
//  Number - 
//
Function ObjectVersion() Export
	
	Return 218;
	
EndFunction

#EndRegion

#Region InitializingExchangeRulesTables

// Initializes table columns of object property conversion rules.
//
// Parameters:
//  Tab            - ValueTable - a table of property conversion rules to initialize.
// 
Procedure InitPropertyConversionRuleTable(Tab) Export

	Columns = Tab.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "IsFolder", 			deTypeDetails("Boolean"));
    AddMissingColumns(Columns, "GroupRules");

	AddMissingColumns(Columns, "SourceKind");
	AddMissingColumns(Columns, "DestinationKind");
	
	AddMissingColumns(Columns, "SimplifiedPropertyExport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExportGroup", deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "SourceType", deTypeDetails("String"));
	AddMissingColumns(Columns, "DestinationType", deTypeDetails("String"));
	
	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Receiver");

	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "GetFromIncomingData", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "NotReplace", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");

	AddMissingColumns(Columns, "BeforeProcessExport");
	AddMissingColumns(Columns, "AfterProcessExport");

	AddMissingColumns(Columns, "HasBeforeExportHandler",			deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",				deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",				deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "HasBeforeProcessExportHandler",	deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterProcessExportHandler",	deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "CastToLength",	deTypeDetails("Number"));
	AddMissingColumns(Columns, "ParameterForTransferName");
	AddMissingColumns(Columns, "SearchByEqualDate",					deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "ExportGroupToFile",					deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "SearchFieldsString");
	
EndProcedure

#EndRegion

#Region InitAttributesAndModuleVariables

// Initializes the external data processor with event handlers debug module.
//
// Parameters:
//  ExecutionPossible - Boolean - indicates whether an external data processor is initialized successfully.
//  OwnerObject - DataProcessorObject.UniversalDataExchangeXML - an object that will own 
//                   the initialized external data processor.
//  
Procedure InitEventHandlerExternalDataProcessor(ExecutionPossible, OwnerObject) Export
	
	If Not ExecutionPossible Then
		Return;
	EndIf; 
	
	If HandlersDebugModeFlag And IsBlankString(EventHandlerExternalDataProcessorFileName) Then
		
		WriteToExecutionProtocol(77); 
		ExecutionPossible = False;
		
	ElsIf HandlersDebugModeFlag Then
		
		Try
			
			If IsExternalDataProcessor() Then
				
				Raise
					NStr("en = 'The external data processor (debugger) is not supported.';");
				
			Else
				
				EventHandlersExternalDataProcessor = DataProcessors[EventHandlerExternalDataProcessorFileName].Create();
				
			EndIf;
			
			EventHandlersExternalDataProcessor.Designer(OwnerObject);
			
		Except
			
			EventHandlerExternalDataProcessorDestructor();
			
			MessageToUser(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			WriteToExecutionProtocol(78);
			
			ExecutionPossible               = False;
			HandlersDebugModeFlag = False;
			
		EndTry;
		
	EndIf;
	
	If ExecutionPossible Then
		
		CommonProceduresFunctions = ThisObject;
		
	EndIf; 
	
EndProcedure

// External data processor destructor.
//
// Parameters:
//  DebugModeEnabled - Boolean - indicates whether the debug mode is on.
//  
Procedure EventHandlerExternalDataProcessorDestructor(DebugModeEnabled = False) Export
	
	If Not DebugModeEnabled Then
		
		If EventHandlersExternalDataProcessor <> Undefined Then
			
			Try
				
				EventHandlersExternalDataProcessor.Destructor();
				
			Except
				MessageToUser(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			EndTry; 
			
		EndIf; 
		
		EventHandlersExternalDataProcessor = Undefined;
		CommonProceduresFunctions               = Undefined;
		
	EndIf;
	
EndProcedure

// Deletes temporary files with the specified name.
//
// Parameters:
//  TempFileName - String - a full name of the file to be deleted. It clears after the procedure is executed.
//  
Procedure DeleteTempFiles(TempFileName) Export
	
	If Not IsBlankString(TempFileName) Then
		
		Try
			
			DeleteFiles(TempFileName);
			
			TempFileName = "";
			
		Except
			WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region ExchangeFileOperationsProceduresAndFunctions

// Opens an exchange file, writes a file header according to the exchange format.
//
// Parameters:
//  No.
//
Function OpenExportFile(ErrorMessageString = "")

	// Archive files are recognized by the ZIP extension.
	
	If ArchiveFile Then
		ExchangeFileName = StrReplace(ExchangeFileName, ".zip", ".xml");
	EndIf;
    	
	ExchangeFile = New TextWriter;
	Try
		
		If DirectReadingInDestinationIB Then
			ExchangeFile.Open(GetTempFileName(".xml"), TextEncoding.UTF8);
		Else
			ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
		EndIf;
				
	Except
		
		ErrorMessageString = WriteToExecutionProtocol(8);
		Return "";
		
	EndTry; 
	
	XMLInfoString = "<?xml version=""1.0"" encoding=""UTF-8""?>";
	
	ExchangeFile.WriteLine(XMLInfoString);

	TempXMLWriter = New XMLWriter();
	
	TempXMLWriter.SetString();
	
	TempXMLWriter.WriteStartElement("ExchangeFile");
							
	SetAttribute(TempXMLWriter, "FormatVersion", "2.0");
	SetAttribute(TempXMLWriter, "ExportDate",				CurrentSessionDate());
	SetAttribute(TempXMLWriter, "ExportPeriodStart",		StartDate);
	SetAttribute(TempXMLWriter, "ExportPeriodEnd",	EndDate);
	SetAttribute(TempXMLWriter, "SourceConfigurationName",	Conversion().Source);
	SetAttribute(TempXMLWriter, "DestinationConfigurationName",	Conversion().Receiver);
	SetAttribute(TempXMLWriter, "ConversionRulesID",		Conversion().ID_SSLy);
	SetAttribute(TempXMLWriter, "Comment",				Comment);
	
	TempXMLWriter.WriteEndElement();
	
	Page1 = TempXMLWriter.Close(); 
	
	Page1 = StrReplace(Page1, "/>", ">");
	
	ExchangeFile.WriteLine(Page1);
	
	Return XMLInfoString + Chars.LF + Page1;
			
EndFunction

// Closes the exchange file
//
// Parameters:
//  No.
//
Procedure CloseFile()

    ExchangeFile.WriteLine("</ExchangeFile>");
	ExchangeFile.Close();
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfTemporaryFilesOperations

Function WriteTextToTemporaryFile(TempFileList)
	
	RecordFileName = GetTempFileName();
	
	RecordsTemporaryFile = New TextWriter;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Try
		RecordsTemporaryFile.Open(RecordFileName, TextEncoding.UTF8);
	Except
		WriteErrorInfoConversionHandlers(1000,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),
			NStr("en = 'An error occurred when creating a temporary file for data export';"));
		Raise;
	EndTry;
	
	// 
	// 
	TempFileList.Add(RecordFileName);
		
	Return RecordsTemporaryFile;
	
EndFunction

Function ReadTextFromTemporaryFile(TempFileName)
	
	TempFile = New TextReader;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Try
		TempFile.Open(TempFileName, TextEncoding.UTF8);
	Except
		WriteErrorInfoConversionHandlers(1000,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()),
			NStr("en = 'An error occurred when opening the temporary file to transfer data to the exchange file';"));
		Raise;
	EndTry;
	
	Return TempFile;
EndFunction

Procedure TransferDataFromTemporaryFiles(TempFileList)
	
	For Each TempFileName In TempFileList Do
		TempFile = ReadTextFromTemporaryFile(TempFileName);
		
		TempFileLine = TempFile.ReadLine();
		While TempFileLine <> Undefined Do
			WriteToFile(TempFileLine);	
			TempFileLine = TempFile.ReadLine();
		EndDo;
		
		TempFile.Close();
	EndDo;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	For Each TempFileName In TempFileList Do
		DeleteFiles(TempFileName);
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfExchangeProtocolOperations

// Initializes the file to write data import/export events.
//
// Parameters:
//  No.
// 
Procedure InitializeKeepExchangeProtocol() Export
	
	If IsBlankString(ExchangeProtocolFileName) Then
		
		mDataProtocolFile = Undefined;
		CommentObjectProcessingFlag = OutputInfoMessagesToMessageWindow;		
		Return;
		
	Else	
		
		CommentObjectProcessingFlag = OutputInfoMessagesToProtocol Or OutputInfoMessagesToMessageWindow;		
		
	EndIf;
	
	mDataProtocolFile = New TextWriter(ExchangeProtocolFileName, ExchangeProtocolFileEncoding(), , AppendDataToExchangeLog) ;
	
EndProcedure

Procedure InitializeKeepExchangeProtocolForHandlersExport()
	
	ExchangeProtocolTempFileName = GetNewUniqueTempFileName(ExchangeProtocolTempFileName);
	
	mDataProtocolFile = New TextWriter(ExchangeProtocolTempFileName, ExchangeProtocolFileEncoding());
	
	CommentObjectProcessingFlag = False;
	
EndProcedure

Function ExchangeProtocolFileEncoding()
	
	EncodingPresentation1 = TrimAll(ExchangeProtocolFileEncoding);
	
	Result = TextEncoding.ANSI;
	If Not IsBlankString(ExchangeProtocolFileEncoding) Then
		If StrStartsWith(EncodingPresentation1, "TextEncoding.") Then
			EncodingPresentation1 = StrReplace(EncodingPresentation1, "TextEncoding.", "");
			Try
				Result = TextEncoding[EncodingPresentation1];
			Except
				ErrorText = SubstituteParametersToString(NStr("en = 'Unknown encoding of the exchange log file: %1.
				|The supported encoding is ANSI.';"), EncodingPresentation1);
				WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
					EventLogLevel.Warning, , , ErrorText);
			EndTry;
		Else
			Result = EncodingPresentation1;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Closes a data exchange protocol file. File is saved to the hard drive.
//
Procedure FinishKeepExchangeProtocol() Export 
	
	If mDataProtocolFile <> Undefined Then
		
		mDataProtocolFile.Close();
				
	EndIf;	
	
	mDataProtocolFile = Undefined;
	
EndProcedure

// Writes to a protocol or displays messages of the specified structure.
//
// Parameters:
//  Code               - Number - message code.
//  RecordStructure   - Structure - protocol record structure.
//  SetErrorFlag1 - Boolean - if true, then it is an error message. Setting ErrorFlag.
// 
Function WriteToExecutionProtocol(Code="", RecordStructure=Undefined, SetErrorFlag1=True, 
	Level=0, Align=22, UnconditionalWriteToExchangeProtocol = False) Export

	Indent = "";
    For Cnt = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = deNumberType Then
		
		If deMessages = Undefined Then
			InitMessages();
		EndIf;
		
		Page1 = deMessages[Code];
		
	Else
		
		Page1 = String(Code);
		
	EndIf;

	Page1 = Indent + Page1;
	
	If RecordStructure <> Undefined Then
		
		For Each Field In RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			Var_Key = Field.Key;
			Page1  = Page1 + Chars.LF + Indent + Chars.Tab + odSupplementString(Var_Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	ResultingStringToWrite = Chars.LF + Page1;

	
	If SetErrorFlag1 Then
		
		SetErrorFlag2(True);
		MessageToUser(ResultingStringToWrite);
		
	Else
		
		If DontOutputInfoMessagesToUser = False
			And (UnconditionalWriteToExchangeProtocol Or OutputInfoMessagesToMessageWindow) Then
			
			MessageToUser(ResultingStringToWrite);
			
		EndIf;
		
	EndIf;
	
	If mDataProtocolFile <> Undefined Then
		
		If SetErrorFlag1 Then
			
			mDataProtocolFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag1 Or UnconditionalWriteToExchangeProtocol Or OutputInfoMessagesToProtocol Then
			
			mDataProtocolFile.WriteLine(ResultingStringToWrite);
		
		EndIf;		
		
	EndIf;
	
	Return Page1;
		
EndFunction

// Writes error details to the exchange log for data clearing handler.
//
Procedure WriteDataClearingHandlerErrorInfo(MessageCode, ErrorString, DataClearingRuleName, Object = "", HandlerName = "")
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.DPR                    = DataClearingRuleName;
	
	If Object <> "" Then
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			WP.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			WP.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	If HandlerName <> "" Then
		WP.Handler             = HandlerName;
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not FlagDebugMode Then
		Raise ErrorMessageString;
	EndIf;	
	
EndProcedure

// Registers the error of object conversion rule handler (export) in the execution protocol.
//
Procedure WriteInfoOnOCRHandlerExportError(MessageCode, ErrorString, OCR, Source, HandlerName)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	TypeDescription = New TypeDescription("String");
	StringSource  = TypeDescription.AdjustValue(Source);
	If Not IsBlankString(StringSource) Then
		WP.Object = StringSource + "  (" + TypeOf(Source) + ")";
	Else
		WP.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	WP.Handler = HandlerName;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not FlagDebugMode Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure

Procedure WriteErrorInfoDERHandlers(MessageCode, ErrorString, RuleName, HandlerName, Object = Undefined)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.DER                    = RuleName;
	
	If Object <> Undefined Then
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			WP.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			WP.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	WP.Handler             = HandlerName;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not FlagDebugMode Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

Function WriteErrorInfoConversionHandlers(MessageCode, ErrorString, HandlerName)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	WP.Handler             = HandlerName;
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	Return ErrorMessageString;
	
EndFunction

#EndRegion

#Region CollectionsTypesDetails

// Returns:
//   ValueTable - 
//     * Name - String
//     * Description - String
//     * Order - Number
//     * SynchronizeByID - Boolean
//     * DontCreateIfNotFound - Boolean
//     * DontExportPropertyObjectsByRefs - Boolean
//     * SearchBySearchFieldsIfNotFoundByID - Boolean
//     * OnExchangeObjectByRefSetGIUDOnly - Boolean
//     * UseQuickSearchOnImport - Boolean
//     * GenerateNewNumberOrCodeIfNotSet - Boolean
//     * TinyObjectCount - Boolean
//     * RefExportReferenceCount - Number
//     * IBItemsCount - Number
//     * ExportMethod - Arbitrary
//     * Source - Arbitrary
//     * Receiver - Arbitrary
//     * SourceType - String
//     * BeforeExport - Arbitrary
//     * OnExport - Arbitrary
//     * AfterExport - Arbitrary
//     * AfterExportToFile - Arbitrary
//     * HasBeforeExportHandler - Boolean
//     * HasOnExportHandler - Boolean
//     * HasAfterExportHandler - Boolean
//     * HasAfterExportToFileHandler - Boolean
//     * BeforeImport - Arbitrary
//     * OnImport - Arbitrary
//     * AfterImport - Arbitrary
//     * SearchFieldSequence - Arbitrary
//     * SearchInTabularSections - See SearchTabularSectionsCollection
//     * HasBeforeImportHandler - Boolean
//     * HasOnImportHandler - Boolean
//     * HasAfterImportHandler - Boolean
//     * HasSearchFieldSequenceHandler - Boolean
//     * SearchProperties - See PropertiesConversionRulesCollection
//     * Properties - See PropertiesConversionRulesCollection
//     * Exported_ - ValueTable
//     * ExportSourcePresentation - Boolean
//     * NotReplace - Boolean
//     * RememberExportedData - Boolean
//     * AllObjectsExported - Boolean
// 
Function ConversionRulesCollection()
	
	Return ConversionRulesTable;
	
EndFunction

// Returns:
//   ValueTree - 
//     * Enable - Number
//     * IsFolder - Boolean
//     * Name - String
//     * Description - String
//     * Order - Number
//     * DataFilterMethod - Arbitrary
//     * SelectionObject1 - Arbitrary
//     * ConversionRule - Arbitrary
//     * BeforeProcess - String
//     * AfterProcess - String
//     * BeforeExport - String
//     * AfterExport - String
//     * UseFilter1 - Boolean
//     * BuilderSettings - Arbitrary
//     * ObjectForQueryName - String
//     * ObjectNameForRegisterQuery - String
//     * SelectExportDataInSingleQuery - Boolean
//     * ExchangeNodeRef - ExchangePlanRef
//
Function ExportRulesCollection()
	
	Return ExportRulesTable;
	
EndFunction

// Returns:
//   ValueTable - 
//     * TagName - Arbitrary
//     * TSSearchFields - Array of Arbitrary
// 
Function SearchTabularSectionsCollection()
	
	SearchInTabularSections = New ValueTable;
	SearchInTabularSections.Columns.Add("TagName");
	SearchInTabularSections.Columns.Add("TSSearchFields");
	
	Return SearchInTabularSections;
	
EndFunction

// Returns:
//   ValueTable - 
//     * Name - String
//     * Description - String
//     * Order - Number
//     * IsFolder - Boolean
//     * IsSearchField - Boolean
//     * GroupRules - See PropertiesConversionRulesCollection
//     * DisabledGroupRules - Arbitrary
//     * SourceKind - Arbitrary
//     * DestinationKind - Arbitrary
//     * SimplifiedPropertyExport - Boolean
//     * XMLNodeRequiredOnExport - Boolean
//     * XMLNodeRequiredOnExportGroup - Boolean
//     * SourceType - String
//     * DestinationType - String
//     * Source - Arbitrary
//     * Receiver - Arbitrary
//     * ConversionRule - Arbitrary
//     * GetFromIncomingData - Boolean
//     * NotReplace - Boolean
//     * IsRequiredProperty - Boolean
//     * BeforeExport - Arbitrary
//     * BeforeExportHandlerName - Arbitrary
//     * OnExport - Arbitrary
//     * OnExportHandlerName - Arbitrary
//     * AfterExport - Arbitrary
//     * AfterExportHandlerName - Arbitrary
//     * BeforeProcessExport - Arbitrary
//     * BeforeExportProcessHandlerName - Arbitrary
//     * AfterProcessExport - Arbitrary
//     * AfterExportProcessHandlerName - Arbitrary
//     * HasBeforeExportHandler - Boolean
//     * HasOnExportHandler - Boolean
//     * HasAfterExportHandler - Boolean
//     * HasBeforeProcessExportHandler - Boolean
//     * HasAfterProcessExportHandler - Boolean
//     * CastToLength - Number
//     * ParameterForTransferName - String
//     * SearchByEqualDate - Boolean
//     * ExportGroupToFile - Boolean
//     * SearchFieldsString - Arbitrary
// 
Function PropertiesConversionRulesCollection()
	
	Return mPropertyConversionRuleTable;
	
EndFunction

// Returns:
//   ValueTable:
//     * Ref - AnyRef - reference to an object being exported.
//
Function DataExportCallStackCollection()
	
	Return mDataExportCallStack;
	
EndFunction

// Returns:
//   Structure:
//     * ExportRulesTable - See ExportRulesCollection
//     * ConversionRulesTable - See ConversionRulesCollection
//     * Algorithms - Structure
//     * Queries - Structure
//     * Conversion - Arbitrary
//     * mXMLRules - Arbitrary
//     * ParametersSetupTable - ValueTable
//     * Parameters - Structure
//     * DestinationPlatformVersion - String
//
Function RulesStructureDetails()
	
	RulesStructure = New Structure;

	RulesStructure.Insert("ExportRulesTable");
	RulesStructure.Insert("ConversionRulesTable");
	RulesStructure.Insert("Algorithms");
	RulesStructure.Insert("Queries");
	RulesStructure.Insert("Conversion");
	RulesStructure.Insert("mXMLRules");
	RulesStructure.Insert("ParametersSetupTable");
	RulesStructure.Insert("Parameters");
	
	RulesStructure.Insert("DestinationPlatformVersion");
	
	Return RulesStructure;
	
EndFunction

#EndRegion

#Region ExchangeRulesImportProcedures

// Imports the property group conversion rule.
//
// Parameters:
//   ExchangeRules  - XMLReader - an object of the XMLReader type.
//   PropertiesTable - See PropertiesConversionRulesCollection
//
Procedure ImportPGCR(ExchangeRules, PropertiesTable)

	If deAttribute(ExchangeRules, deBooleanType, "Disconnect") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;
	
	NewRow               = PropertiesTable.Add();
	NewRow.IsFolder     = True;
	NewRow.GroupRules = PropertiesConversionRulesCollection().Copy();
	
	// 

	NewRow.NotReplace               = False;
	NewRow.GetFromIncomingData = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldsString = "";	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.DestinationKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.DestinationType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			ImportPCR(ExchangeRules, NewRow.GroupRules, , SearchFieldsString);

		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "NotReplace" Then
			NewRow.NotReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Group") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SearchFieldsString = SearchFieldsString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 

EndProcedure

Procedure AddFieldToSearchString(SearchFieldsString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If Not IsBlankString(SearchFieldsString) Then
		SearchFieldsString = SearchFieldsString + ",";
	EndIf;
	
	SearchFieldsString = SearchFieldsString + FieldName;
	
EndProcedure

// Imports the property group conversion rule.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object containing the text of exchange rules.
//  PropertiesTable - See PropertiesConversionRulesCollection
//  SearchTable - See PropertiesConversionRulesCollection
//
Procedure ImportPCR(ExchangeRules, PropertiesTable, SearchTable = Undefined, SearchFieldsString = "")

	If deAttribute(ExchangeRules, deBooleanType, "Disconnect") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;

	
	IsSearchField = deAttribute(ExchangeRules, deBooleanType, "Search");
	
	If IsSearchField 
		And SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertiesTable.Add();
		
	EndIf;  

	
	// 

	NewRow.NotReplace               = False;
	NewRow.GetFromIncomingData = False;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.DestinationKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.DestinationType	= deAttribute(ExchangeRules, deStringType, "Type");
			
			If IsSearchField Then
				AddFieldToSearchString(SearchFieldsString, NewRow.Receiver);
			EndIf;
			
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "NotReplace" Then
			NewRow.NotReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Property") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SimplifiedPropertyExport = Not NewRow.GetFromIncomingData
		And Not NewRow.HasBeforeExportHandler
		And Not NewRow.HasOnExportHandler
		And Not NewRow.HasAfterExportHandler
		And IsBlankString(NewRow.ConversionRule)
		And NewRow.SourceType = NewRow.DestinationType
		And (NewRow.SourceType = "String" Or NewRow.SourceType = "Number" Or NewRow.SourceType = "Boolean" Or NewRow.SourceType = "Date");
		
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler Or NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports property conversion rules.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  PropertiesTable - ValueTable - a value table containing PCR.
//  SearchTable  - ValueTable - a value table containing PCR (synchronizing).
//
Procedure ImportProperties(ExchangeRules, PropertiesTable, SearchTable)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Property" Then
			ImportPCR(ExchangeRules, PropertiesTable, SearchTable);
		ElsIf NodeName = "Group" Then
			ImportPGCR(ExchangeRules, PropertiesTable);
		ElsIf (NodeName = "Properties") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	PropertiesTable.Sort("Order");
	SearchTable.Sort("Order");
	
EndProcedure

// Imports the value conversion rule.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  Values       - Map - a map of source object values to destination
//                   object presentation strings.
//  SourceType   - String - source object type.
//
Procedure ImportVCR(ExchangeRules, Values, SourceType)

	Source = "";
	Receiver = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			Source = deElementValue(ExchangeRules, deStringType);
		ElsIf NodeName = "Receiver" Then
			Receiver = deElementValue(ExchangeRules, deStringType);
		ElsIf (NodeName = "Value") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If ExchangeMode <> "Load" Then
		Values[deGetValueByString(Source, SourceType)] = Receiver;
	EndIf;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  Values       - Map - a map of source object values to destination
//                   object presentation strings.
//  SourceType   - String - source object type.
//
Procedure LoadValues(ExchangeRules, Values, SourceType)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

// Clears OCR for exchange rule managers.
Procedure ClearManagersOCR()
	
	If Managers = Undefined Then
		Return;
	EndIf;
	
	For Each RuleManager In Managers Do
		RuleManager.Value.OCR = Undefined;
	EndDo;
	
EndProcedure

// Imports the object conversion rule.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportConversionRule(ExchangeRules, XMLWriter)

	XMLWriter.WriteStartElement("Rule");

	NewRow = ConversionRulesCollection().Add();
	
	// 
	
	NewRow.RememberExportedData = True;
	NewRow.NotReplace            = False;
	
	SearchInTSTable = SearchTabularSectionsCollection();
	NewRow.SearchInTabularSections = SearchInTSTable;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
				
		If      NodeName = "Code" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DontCreateIfNotFound" Then
			
			NewRow.DontCreateIfNotFound = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontExportPropertyObjectsByRefs" Then
			
			NewRow.DontExportPropertyObjectsByRefs = deElementValue(ExchangeRules, deBooleanType);
						
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnExchangeObjectByRefSetGIUDOnly" Then
			
			NewRow.OnExchangeObjectByRefSetGIUDOnly = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.OnExchangeObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DontReplaceObjectCreatedInDestinationInfobase" Then
			// Has no effect on the exchange
			deElementValue(ExchangeRules, deBooleanType);	
						
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deElementValue(ExchangeRules, deBooleanType);	
			
		ElsIf NodeName = "GenerateNewNumberOrCodeIfNotSet" Then
			
			NewRow.GenerateNewNumberOrCodeIfNotSet = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.GenerateNewNumberOrCodeIfNotSet);
			
		ElsIf NodeName = "NotRememberExportedData" Then
			
			NewRow.RememberExportedData = Not deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "NotReplace" Then
			
			Value = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.NotReplace = Value;
			
		ElsIf NodeName = "ExchangeObjectsPriority" Then
			
			// Does not take part in the universal exchange.
			deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Receiver" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Receiver = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			
			If ExchangeMode = "Load" Then
				
				NewRow.Source = Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					          
					NewRow.SourceType = Value;
					NewRow.Source     = Type(Value);
					
					Try
						
						Managers[NewRow.Source].OCR = NewRow;
						
					Except
						
						WriteErrorInfoToProtocol(11, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
							String(NewRow.Source));
						
					EndTry; 
					
				EndIf;
				
			EndIf;
			
		// Properties
		
		ElsIf NodeName = "Properties" Then
		
			NewRow.SearchProperties	= mPropertyConversionRuleTable.Copy();
			NewRow.Properties		= mPropertyConversionRuleTable.Copy();
			
			
			If NewRow.SynchronizeByID <> Undefined And NewRow.SynchronizeByID Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Receiver = "{UUID}";
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties);

			
		// Values
		
		ElsIf NodeName = "Values" Then
		
			LoadValues(ExchangeRules, NewRow.Values, NewRow.Source);
		
		// Event handlers.
		
		ElsIf NodeName = "BeforeExport" Then
		
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
			
		// For import.
		
		ElsIf NodeName = "BeforeImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			
 			If ExchangeMode = "Load" Then
				
				NewRow.BeforeImport               = Value;
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				NewRow.OnImport               = Value;
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				NewRow.AfterImport               = Value;
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
	 		EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Load" Then
				
				NewRow.SearchFieldSequence = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			
			For Number = 1 To StrLineCount(Value) Do
				
				CurrentRow = StrGetLine(Value, Number);
				
				SearchString = SplitWithSeparator(CurrentRow, ":");
				
				TableRow = SearchInTSTable.Add();
				TableRow.TagName = CurrentRow;
				
				TableRow.TSSearchFields = SplitStringIntoSubstringsArray(SearchString);
				
			EndDo;
			
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ResultingTSSearchString = "";
	
	// Sending details of tabular section search fields to the destination.
	For Each PropertyString In NewRow.Properties Do
		
		If Not PropertyString.IsFolder
			Or IsBlankString(PropertyString.SourceKind)
			Or IsBlankString(PropertyString.Receiver) Then
			
			Continue;
			
		EndIf;
		
		If IsBlankString(PropertyString.SearchFieldsString) Then
			Continue;
		EndIf;
		
		ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertyString.SourceKind + "." + PropertyString.Receiver + ":" + PropertyString.SearchFieldsString;
		
	EndDo;
	
	ResultingTSSearchString = TrimAll(ResultingTSSearchString);
	
	If Not IsBlankString(ResultingTSSearchString) Then
		
		deWriteElement(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);	
		
	EndIf;

	XMLWriter.WriteEndElement();

	
	// 
	
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure
 
// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportConversionRules(ExchangeRules, XMLWriter)

	ConversionRulesTable.Clear();
	ClearManagersOCR();
	
	XMLWriter.WriteStartElement("ObjectsConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectsConversionRules") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
	ConversionRulesTable.Indexes.Add("Receiver");
	
EndProcedure

// Imports the data clearing rule group according to the exchange rule format.
//
// Parameters:
//  NewRow - ValueTreeRow - a structure which describes data clearing rule group:
//    * Name - String - rule ID.
//    * Description - String - a user presentation of the rule.
// 
Procedure ImportDPRGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disconnect"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDPR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeTypeStartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDPRGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data clearing rule according to the format of exchange rules.
//
// Parameters:
//  NewRow - ValueTreeRow - a structure which describes a data clearing rule:
//    * Name - String - rule ID.
//    * Description - String - a user presentation of the rule.
// 
Procedure ImportDPR(ExchangeRules, NewRow)
	
	NewRow.Enable = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disconnect"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Code" Then
			Value = deElementValue(ExchangeRules, deStringType);
			NewRow.Name = Value;

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataFilterMethod" Then
			NewRow.DataFilterMethod = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "SelectionObject1" Then
			SelectionObject1 = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject1) Then
				NewRow.SelectionObject1 = Type(SelectionObject1);
			EndIf; 

		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deElementValue(ExchangeRules, deBooleanType);

		
		// Event handlers.

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDeleteRow = GetHandlerValueFromText(ExchangeRules);

		// Exit.
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
			
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportClearingRules(ExchangeRules, XMLWriter)
	
 	CleanupRulesTable.Rows.Clear();
	VTRows = CleanupRulesTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");

	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = deXMLNodeTypeStartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Load" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					VTRow = VTRows.Add();
					ImportDPR(ExchangeRules, VTRow);
				ElsIf NodeName = "Group" Then
					VTRow = VTRows.Add();
					ImportDPRGroup(ExchangeRules, VTRow);
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeTypeEndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Load" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeTypeText Then
			If ExchangeMode <> "Load" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;

	VTRows.Sort("Order", True);
	
 	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the algorithm according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Algorithm") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	
	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Load" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure

// Imports algorithms according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)

	Algorithms.Clear();

	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the query according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportQuery(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Query") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Load" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure

// Imports queries according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportQueries(ExchangeRules, XMLWriter)

	Queries.Clear();

	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports parameters according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//
Procedure DoImportParameters(ExchangeRules, XMLWriter)

	Parameters.Clear();
	EventsAfterParametersImport.Clear();
	ParametersSetupTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;

		If NodeName = "Parameter" And NodeType = deXMLNodeTypeStartElement Then
			
			// Importing by the 2.01 rule version.
			Name                     = deAttribute(ExchangeRules, deStringType, "Name");
			Description            = deAttribute(ExchangeRules, deStringType, "Description");
			SetInDialog   = deAttribute(ExchangeRules, deBooleanType, "SetInDialog");
			ValueTypeString      = deAttribute(ExchangeRules, deStringType, "ValueType");
			UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
			PassParameterOnExport = deAttribute(ExchangeRules, deBooleanType, "PassParameterOnExport");
			ConversionRule = deAttribute(ExchangeRules, deStringType, "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, deStringType, "AfterImportParameter");
			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParametersImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			If ExchangeMode = "Load" And Not UsedOnImport Then
				Continue;
			EndIf;
			
			// Determining value types and setting initial values.
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = True;
				Except
					TypeDefined = False;
				EndTry;
				
			Else
				
				TypeDefined = False;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetEmptyValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
						
			If SetInDialog = True Then
				
				TableRow              = ParametersSetupTable.Add();
				TableRow.Description = Description;
				TableRow.Name          = Name;
				TableRow.Value = ParameterValue;				
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule = ConversionRule;
				
			EndIf;
			
			If UsedOnImport
				And ExchangeMode = "Upload0" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name",   Name);
				SetAttribute(XMLWriter, "Description", Description);
					
				If Not IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterImportParameter", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;

		ElsIf (NodeType = deXMLNodeTypeText) Then
			
			// Importing from the string to provide 2.0 compatibility.
			ParametersString1 = ExchangeRules.Value;
			For Each Par In ArrayFromString(ParametersString1) Do
				Parameters.Insert(Par);
			EndDo;
			
		ElsIf (NodeName = "Parameters") And (NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();

EndProcedure

// Imports the data processor according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)

	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	Description            = deAttribute(ExchangeRules, deStringType, "Description");
	IsSetupDataProcessor   = deAttribute(ExchangeRules, deBooleanType, "IsSetupDataProcessor");
	
	UsedOnExport = deAttribute(ExchangeRules, deBooleanType, "UsedOnExport");
	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");

	ParametersString1        = deAttribute(ExchangeRules, deStringType, "Parameters");
	
	DataProcessorStorage      = deElementValue(ExchangeRules, deValueStorageType);

	AdditionalDataProcessorParameters.Insert(Name, ArrayFromString(ParametersString1));
	
	
	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			
		Else
			XMLWriter.WriteStartElement("DataProcessor");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",                     Name);
			SetAttribute(XMLWriter, "Description",            Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor",   IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();
		EndIf;
	EndIf;
	
	If IsSetupDataProcessor Then
		If (ExchangeMode = "Load") And UsedOnImport Then
			ImportSettingsDataProcessors.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "Upload0") And UsedOnExport Then
			ExportSettingsDataProcessors.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure

// Imports external data processors according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  XMLWriter      - XMLWriter - object of the XMLWriter type - rules to be saved into the exchange file and
//                   used on data import.
//
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)

	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	
	ExportSettingsDataProcessors.Clear();
	ImportSettingsDataProcessors.Clear();

	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "DataProcessor" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the data exporting rule group according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  NewRow    - ValueTreeRow - a structure which describes data import rule group:
//    * Name - String - rule ID.
//    * Description - String - a user presentation of the rule.
//
Procedure ImportDERGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disconnect"));
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDER(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeTypeStartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDERGroup(ExchangeRules, VTRow);
					
		ElsIf (NodeName = "Group") And (NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data export rule according to the exchange rule format.
//
// Parameters:
//  ExchangeRules  - XMLReader - an object of the XMLReader type.
//  NewRow    - ValueTreeRow - a structure which describes a data import rule:
//    * Name - String - rule ID.
//    * Description - String - a user presentation of the rule.
//
Procedure ImportDER(ExchangeRules, NewRow)

	NewRow.Enable = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disconnect"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataFilterMethod" Then
			NewRow.DataFilterMethod = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			NewRow.SelectExportDataInSingleQuery = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DoNotExportObjectsCreatedInDestinationInfobase" Then
			// Skipping the parameter during the data exchange.
			deElementValue(ExchangeRules, deBooleanType);

		ElsIf NodeName = "SelectionObject1" Then
			SelectionObject1 = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject1) Then
				NewRow.SelectionObject1 = Type(SelectionObject1);
			EndIf;
			// For filtering using the query builder.
			If StrFind(SelectionObject1, "Ref.") Then
				NewRow.ObjectForQueryName = StrReplace(SelectionObject1, "Ref.", ".");
			Else
				NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject1, "Record.", ".");
			EndIf;

		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);

		// Event handlers.

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeExportObject" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);

		ElsIf NodeName = "AfterExportObject" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
        		
		ElsIf (NodeName = "Rule") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		EndIf;
		
	EndDo;

	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data export rules according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader - an object of the XMLReader type.
//
Procedure ImportExportRules(ExchangeRules)

	ExportRulesTable.Rows.Clear();

	VTRows = ExportRulesTable.Rows;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			VTRow = VTRows.Add();
			ImportDER(ExchangeRules, VTRow);
			
		ElsIf NodeName = "Group" Then
			
			VTRow = VTRows.Add();
			ImportDERGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "DataExportRules") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	VTRows.Sort("Order", True);

EndProcedure

#EndRegion

#Region ProceduresOfExportHandlersAndProceduresToTXTFileFromExchangeRules

// Exports event handlers and algorithms to the temporary text file 
// (user temporary directory).
// Generates debug module with handlers and algorithms and all 
// necessary global variables, common function wrappers, and comments.
//
// Parameters:
//  Cancel - Boolean - a flag showing that debug module creation is canceled. Is set in case of
//          exchange rule reading failure.
//
Procedure ExportEventHandlers(Cancel) Export
	
	InitializeKeepExchangeProtocolForHandlersExport();
	
	DataProcessingMode = mDataProcessingModes.EventHandlersExport;
	
	FlagErrors = False;
	
	ImportExchangeRulesForHandlerExport();
	
	If FlagErrors Then
		Cancel = True;
		Return;
	EndIf; 
	
	SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRulesTable, CleanupRulesTable);
	
	If AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		GetFullAlgorithmScriptRecursively();
		
	EndIf;
	
	EventHandlersTempFileName = GetNewUniqueTempFileName(EventHandlersTempFileName);
	
	Result = New TextWriter(EventHandlersTempFileName, TextEncoding.ANSI);
	
	mCommonProceduresFunctionsTemplate = GetTemplate("CommonProceduresFunctions");
	
	// Add comments.
	AddCommentToStream(Result, "Header");
	AddCommentToStream(Result, "DataProcessorVariables");
	
	// Add the service script.
	AddServiceCodeToStream(Result, "DataProcessorVariables");
	
	// Export global handlers.
	ExportConversionHandlers(Result);
	
	// Export DER.
	AddCommentToStream(Result, "DER", ExportRulesTable.Rows.Count() <> 0);
	ExportDataExportRuleHandlers(Result, ExportRulesTable.Rows);
	
	// Export DPR.
	AddCommentToStream(Result, "DPR", CleanupRulesTable.Rows.Count() <> 0);
	ExportDataClearingRuleHandlers(Result, CleanupRulesTable.Rows);
	
	// Exporting OCR, PCR, PGCR.
	ExportConversionRuleHandlers(Result);
	
	If AlgorithmsDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		// Exporting algorithms with standard (default) parameters.
		ExportAlgorithms(Result);
		
	EndIf; 
	
	// Add comments.
	AddCommentToStream(Result, "Warning");
	AddCommentToStream(Result, "CommonProceduresFunctions");
		
	// Adding common procedures and functions to the stream.
	AddServiceCodeToStream(Result, "CommonProceduresFunctions");

	// Adding the external data processor constructor.
	ExportExternalDataProcessorConstructor(Result);
	
	// Add the destructor.
	AddServiceCodeToStream(Result, "Destructor");
	
	Result.Close();
	
	FinishKeepExchangeProtocol();
	
	If IsInteractiveMode Then
		
		If FlagErrors Then
			
			MessageToUser(NStr("en = 'Error exporting event handlers.';"));
			
		Else
			
			MessageToUser(NStr("en = 'Event handlers exported.';"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Clears variables with structure of exchange rules.
//
// Parameters:
//  No.
//  
Procedure ClearExchangeRules()
	
	ExportRulesTable.Rows.Clear();
	CleanupRulesTable.Rows.Clear();
	ConversionRulesTable.Clear();
	Algorithms.Clear();
	Queries.Clear();

	// Обработки
	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	ExportSettingsDataProcessors.Clear();
	ImportSettingsDataProcessors.Clear();

EndProcedure  

// Exports exchange rules from rule file or data file.
//
// Parameters:
//  No.
//  
Procedure ImportExchangeRulesForHandlerExport()
	
	ClearExchangeRules();
	
	If ReadEventHandlersFromExchangeRulesFile Then
		
		ExchangeMode = ""; // Export data.

		ImportExchangeRules();
		
		mExchangeRulesReadOnImport = False;
		
		InitializeInitialParameterValues();
		
	Else // Data file.
		
		ExchangeMode = "Load"; 
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(15);
			Return;
		EndIf;
		
		OpenImportFile(True);
		
		// 
		// 
		mExchangeRulesReadOnImport = True;

	EndIf;
	
EndProcedure

// Exports global conversion handlers to a text file.
// When exporting handlers from the file with data, the content of the Conversion_AfterParameterImport handler
// is not exported, because the handler code is not in the exchange rule node, but in a separate node.
// During the handler export from the rule file, this algorithm exported as all others.
//
// Parameters:
//  Result - TextWriter - object of the TextWriter type - to output handlers to a text file.
//
Procedure ExportConversionHandlers(Result)
	
	AddCommentToStream(Result, "Conversion");
	
	For Each Item In HandlersNames.Conversion Do
		
		AddConversionHandlerToStream(Result, Item.Key);
		
	EndDo; 
	
EndProcedure 

// Exports handlers of data export rules to the text file.
//
// Parameters:
//  Result    - TextWriter - object of the TextWriter type - to output handlers to a text file.
//  TreeRows - ValueTreeRowCollection - object of the ValueTreeRowCollection type - contains DER of this
//                                                value tree level.
//
Procedure ExportDataExportRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataExportRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlersNames.DER Do
				
				AddHandlerToStream(Result, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports handlers of data clearing rules to the text file.
//
// Parameters:
//  Result    - TextWriter - object of the TextWriter type - to output handlers to a text file.
//  TreeRows - ValueTreeRowCollection - object of the ValueTreeRowCollection type - contains DPR of this
//                                                value tree level.
//
Procedure ExportDataClearingRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataClearingRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlersNames.DPR Do
				
				AddHandlerToStream(Result, Rule, "DPR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports the following conversion rule handlers into a text file: OCR, PCR, and PGCR.
//
// Parameters:
//  Result    - TextWriter - object of the TextWriter type - to output handlers to a text file.
//
Procedure ExportConversionRuleHandlers(Result)
	
	OutputComment = ConversionRulesTable.Count() <> 0;
	
	// Export OCR.
	AddCommentToStream(Result, "OCR", OutputComment);
	
	For Each OCR In ConversionRulesTable Do
		
		For Each Item In HandlersNames.OCR Do
			
			AddOCRHandlerToStream(Result, OCR, Item.Key);
			
		EndDo; 
		
	EndDo; 
	
	// Exporting PCR and PGCR.
	AddCommentToStream(Result, "PCR", OutputComment);
	
	For Each OCR In ConversionRulesTable Do
		
		ExportPropertyConversionRuleHandlers(Result, OCR.SearchProperties);
		ExportPropertyConversionRuleHandlers(Result, OCR.Properties);
		
	EndDo; 
	
EndProcedure 

// Exports handlers of property conversion rules to a text file.
//
// Parameters:
//  Result - TextWriter - object of the TextWriter type - to output handlers to a text file.
//  PCR       - ValueTable - contains rules of conversion of properties or object property group.
//
Procedure ExportPropertyConversionRuleHandlers(Result, PCR)
	
	For Each Rule In PCR Do
		
		If Rule.IsFolder Then // ПКГС
			
			For Each Item In HandlersNames.PGCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo; 

			ExportPropertyConversionRuleHandlers(Result, Rule.GroupRules);
			
		Else
			
			For Each Item In HandlersNames.PCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Exports algorithms to the text file.
//
// Parameters:
//  Result - TextWriter - Object of the TextWriter type - to output algorithms to a text file.
//
Procedure ExportAlgorithms(Result)
	
	// Commenting the Algorithms block.
	AddCommentToStream(Result, "Algorithms", Algorithms.Count() <> 0);
	
	For Each Algorithm In Algorithms Do
		
		AddAlgorithmToSteam(Result, Algorithm);
		
	EndDo; 
	
EndProcedure  

// Exports the constructor of external data processor to the text file.
//  If algorithm debug mode is "debug algorithms as procedures", then the constructor receives structure
//  "Algorithms".
//  Structure item key is algorithm name and its value is the interface of procedure call that contains algorithm code.
//
// Parameters:
//  Result    - TextWriter - object of the TextWriter type - to output handlers to a text file.
//
Procedure ExportExternalDataProcessorConstructor(Result)
	
	// Display the comment.
	AddCommentToStream(Result, "Designer");
	
	ProcedureBody = GetServiceCode("ConstructorProcedureBody");

	If AlgorithmsDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("ConstructorProcedureBodyProceduralAlgorithmCall");
		
		// Adding algorithm calls to the constructor body.
		For Each Algorithm In Algorithms Do
			
			AlgorithmKey = TrimAll(Algorithm.Key);
			
			AlgorithmInterface = GetAlgorithmInterface(AlgorithmKey) + ";";
			
			AlgorithmInterface = StrReplace(StrReplace(AlgorithmInterface, Chars.LF, " ")," ","");
			
			ProcedureBody = ProcedureBody + Chars.LF 
			   + "Algorithms.Insert(""" + AlgorithmKey + """, """ + AlgorithmInterface + """);";

			
		EndDo; 
		
	ElsIf AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("ConstructorProcedureBodyAlgorithmCodeIntegration");
		
	ElsIf AlgorithmsDebugMode = mAlgorithmDebugModes.DontUse Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("ConstructorProcedureBodyDoNotUseAlgorithmDebug");
		
	EndIf; 
	
	ExternalDataProcessorProcedureInterface = "Procedure " + GetExternalDataProcessorProcedureInterface("Designer") + " Export";
	
	AddFullHandlerToStream(Result, ExternalDataProcessorProcedureInterface, ProcedureBody);
	
EndProcedure  

// Adds an OCR, PCR, or PGCR handler to the Result object.
//
// Parameters:
//  Result      - TextWriter - object of the TextWriter type - to output handler to a text file.
//  Rule        - ValueTableRow - with i=object conversion rules.
//  HandlerName - String - handler name.
//
Procedure AddOCRHandlerToStream(Result, Rule, HandlerName)
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds an algorithm code to the Result object.
//
// Parameters:
//  Result - TextWriter - object of the TextWriter type - to output handler to a text file.
//  Algorithm  - KeyAndValue - structure item, an algorithm for the export.
//
Procedure AddAlgorithmToSteam(Result, Algorithm)
	
	AlgorithmInterface = "Procedure " + GetAlgorithmInterface(Algorithm.Key);

	AddFullHandlerToStream(Result, AlgorithmInterface, Algorithm.Value);
	
EndProcedure  

// Adds to the Result object a DER or DPR handler.
//
// Parameters:
//  Result      - TextWriter - object of the TextWriter type - to output handler to a text file.
//  Rule        - 
//  HandlerPrefix - String - a handler prefix: DER or DPR.
//  HandlerName - String - handler name.
//
Procedure AddHandlerToStream(Result, Rule, HandlerPrefix, HandlerName)
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds a global conversion handler to the Result object.
//
// Parameters:
//  Result      - TextWriter - object of the TextWriter type - to output handler to a text file.
//  HandlerName - String - handler name.
//
Procedure AddConversionHandlerToStream(Result, HandlerName)
	
	HandlerAlgorithm = "";
	
	If Conversion.Property(HandlerName, HandlerAlgorithm) And Not IsBlankString(HandlerAlgorithm) Then
		
		HandlerInterface = "Procedure " + Conversion["HandlerInterface" + HandlerName] + " Export";
		
		AddFullHandlerToStream(Result, HandlerInterface, HandlerAlgorithm);
		
	EndIf;
	
EndProcedure  

// Adds a procedure with a handler or algorithm code to the Result object.
//
// Parameters:
//  Result            - TextWriter - object of the TextWriter type - to output procedure to a text file.
//  HandlerInterface - String - full handler interface description:
//                         procedure name, parameters, Export keyword.
//  Handler           - String - a body of handler or algorithm.
//
Procedure AddFullHandlerToStream(Result, HandlerInterface, Handler)
	
	PrefixString = Chars.Tab;
	
	Result.WriteLine("");
	
	Result.WriteLine(HandlerInterface);
	
	Result.WriteLine("");
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, IndexOf);
		
		//  
		// 
		// 
		If AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
			
			HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
			
			If HandlerAlgorithms.Count() <> 0 Then // 
				
				// Receiving the initial algorithm code offset relative to the current handler code.
				PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
				For Each Algorithm In HandlerAlgorithms Do
					
					AlgorithmHandler = IntegratedAlgorithms[Algorithm];
					
					For AlgorithmRowIndex = 1 To StrLineCount(AlgorithmHandler) Do
						
						Result.WriteLine(PrefixStringForInlineCode + StrGetLine(AlgorithmHandler, AlgorithmRowIndex));
						
					EndDo;	
					
				EndDo;
				
			EndIf;
		EndIf;

		Result.WriteLine(PrefixString + HandlerRow);
		
	EndDo;
	
	Result.WriteLine("");
	Result.WriteLine("EndProcedure");
	
EndProcedure

// Adds a comment to the Result object.
//
// Parameters:
//  Result          - TextWriter - object of the TextWriter type - to output comment to a text file.
//  AreaName         - String - a name of the mCommonProceduresFunctionsTemplate text template area
//                       that contains the required comment.
//  OutputComment - Boolean - shows whether it is necessary to display a comment.
//
Procedure AddCommentToStream(Result, AreaName, OutputComment = True)
	
	If Not OutputComment Then
		Return;
	EndIf; 
	
	// Getting handler comments by the area name.
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName+"_Comment");
	
	CommentFromTemplate = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	// 
	CommentFromTemplate = Mid(CommentFromTemplate, 1, StrLen(CommentFromTemplate));
	
	Result.WriteLine(Chars.LF + Chars.LF + CommentFromTemplate);
	
EndProcedure  

// Adds service code to the Result object: parameters, common procedures and functions, and destructor of external data processor.
//
// Parameters:
//  Result          - TextWriter - object of the TextWriter type - to output service code to a text file.
//  AreaName         - String - a name of the mCommonProceduresFunctionsTemplate text template area
//                       that contains the required service code.
//
Procedure AddServiceCodeToStream(Result, AreaName)
	
	// Get the area text.
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Text = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	Text = Mid(Text, 1, StrLen(Text)); // 
	
	Result.WriteLine(Chars.LF + Chars.LF + Text);
	
EndProcedure  

// Retrieves the service code from the specified mCommonProceduresFunctionsTemplate template area.
//
// Parameters:
//  AreaName - String - a name of the mCommonProceduresFunctionsTemplate text template area.
//  
// Returns:
//  String - 
//
Function GetServiceCode(AreaName)
	
	// Get the area text.
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Return GetTextByAreaWithoutAreaTitle(CurrentArea);
EndFunction

#EndRegion

#Region ProceduresAndFUnctionsOfGetFullAlgorithmsCodeConsideringTheyCanBeNested

// Generates the full code of algorithms considering their nesting.
//
// Parameters:
//  No.
//  
Procedure GetFullAlgorithmScriptRecursively()
	
	// 
	IntegratedAlgorithms = New Structure;
	
	For Each Algorithm In Algorithms Do
		
		IntegratedAlgorithms.Insert(Algorithm.Key, ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithm.Value, Algorithm.Key, New Array));
		
	EndDo; 
	
EndProcedure 

// Adds the NewHandler string as a comment to algorithm code insertion.
//
// Parameters:
//  HandlerNew - String - a result string that contains full algorithm scripts taking algorithm nesting into account.
//  AlgorithmName    - String - an algorithm name.
//  PrefixString  - String - sets the initial offset of the comment to be inserted.
//  Title       - String - comment description: "{ALGORITHM START}", "{ALGORITHM END}"…
//
Procedure WriteAlgorithmBlockTitle(HandlerNew, AlgorithmName, PrefixString, Title) 
	
	AlgorithmTitle = "//============================ " + Title + " """ + AlgorithmName + """ ============================";
	
	HandlerNew = HandlerNew + Chars.LF;
	HandlerNew = HandlerNew + Chars.LF + PrefixString + AlgorithmTitle;
	HandlerNew = HandlerNew + Chars.LF;
	
EndProcedure  

// Complements the HandlerAlgorithms array with names of algorithms that are called 
// from the passed procedure of the HandlerLine handler line.
//
// Parameters:
//  HandlerRow - String - a handler line or algorithm line where algorithm calls are searched.
//  HandlerAlgorithms - Array- contains algorithm names that are called from the specified handler.
//  
Procedure GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms)
	
	HandlerRow = Upper(HandlerRow);
	
	SearchTemplate = "ALGORITHMS.";
	
	PatternStringLength = StrLen(SearchTemplate);
	
	InitialChar = StrFind(HandlerRow, SearchTemplate);
	
	If InitialChar = 0 Then
		// 
		Return; 
	EndIf;
	
	// Checking whether this operator is commented.
	HandlerLineBeforeAlgorithmCall = Left(HandlerRow, InitialChar);
	
	If StrFind(HandlerLineBeforeAlgorithmCall, "//") <> 0  Then 
		// 
		// 
		Return;
	EndIf; 
	
	HandlerRow = Mid(HandlerRow, InitialChar + PatternStringLength);
	
	EndChar = StrFind(HandlerRow, ")") - 1;
	
	AlgorithmName = Mid(HandlerRow, 1, EndChar); 
	
	HandlerAlgorithms.Add(TrimAll(AlgorithmName));
	
	//  
	// 
	GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
	
EndProcedure 

// Returns the modified algorithm script taking nested algorithms into account. Instead of the "Execute(Algorithms.Algorithm_1);" algorithm
// call operator, the calling algorithm 
// script is inserted with the PrefixString offset.
// Recursively calls itself to take into account all nested algorithms.
//
// Parameters:
//  Handler                 - String - initial algorithm script.
//  PrefixString             - String - inserting algorithm script offset mode.
//  AlgorithmOwner           - String - a name of the parent 
//                                        algorithm.
//  RequestedItemsArray - Array - names of algorithms that were already processed in this recursion branch.
//                                        It is used to prevent endless function
//                                        recursion and to display the error message.
//  
// Returns:
//  String - 
// 
Function ReplaceAlgorithmCallsWithTheirHandlerScript(Handler, AlgorithmOwner, RequestedItemArray, Val PrefixString = "")
	
	RequestedItemArray.Add(Upper(AlgorithmOwner));
	
	// Initialize return value.
	HandlerNew = "";
	
	WriteAlgorithmBlockTitle(HandlerNew, AlgorithmOwner, PrefixString, NStr("en = '{ALGORITHM START}';"));
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, IndexOf);
		
		HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
		
		If HandlerAlgorithms.Count() <> 0 Then // 
			
			// Receiving the initial algorithm code offset relative to the current code.
			PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
			//  
			// 
			For Each Algorithm In HandlerAlgorithms Do
				
				If RequestedItemArray.Find(Upper(Algorithm)) <> Undefined Then // 
					
					WriteAlgorithmBlockTitle(HandlerNew, Algorithm, PrefixStringForInlineCode, NStr("en = '{RECURSIVE ALGORITHM CALL}';"));
					
					OperatorString = NStr("en = '%1 ""RECURSIVE ALGORITHM CALL: %2"";';");
					OperatorString = SubstituteParametersToString(OperatorString, "CauseTheException", Algorithm);
					
					HandlerNew = HandlerNew + Chars.LF + PrefixStringForInlineCode + OperatorString;
					
					WriteAlgorithmBlockTitle(HandlerNew, Algorithm, PrefixStringForInlineCode, NStr("en = '{RECURSIVE ALGORITHM CALL}';"));
					
					RecordStructure = New Structure;
					RecordStructure.Insert("Algorithm_1", AlgorithmOwner);
					RecordStructure.Insert("Algorithm_2", Algorithm);
					
					WriteToExecutionProtocol(79, RecordStructure);
					
				Else
					
					HandlerNew = HandlerNew + ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithms[Algorithm], Algorithm, CopyArray(RequestedItemArray), PrefixStringForInlineCode);
					
				EndIf; 
				
			EndDo;
			
		EndIf; 
		
		HandlerNew = HandlerNew + Chars.LF + PrefixString + HandlerRow; 
		
	EndDo;
	
	WriteAlgorithmBlockTitle(HandlerNew, AlgorithmOwner, PrefixString, NStr("en = '{ALGORITHM END}';"));
	
	Return HandlerNew;
	
EndFunction

// Copies the passed array and returns a new one.
//
// Parameters:
//  SourceArray1 - Array - a source to receive a new array by copying.
//  
// Returns:
//  Array - 
// 
Function CopyArray(SourceArray1)
	
	NewArray = New Array;
	
	For Each ArrayElement In SourceArray1 Do
		
		NewArray.Add(ArrayElement);
		
	EndDo; 
	
	Return NewArray;
EndFunction 

// Returns an array with names of algorithms that were found in the passed handler body.
//
// Parameters:
//  Handler - String - a handler body.
//  
// Returns:
//  Array - 
//
Function GetHandlerAlgorithms(Handler)
	
	// Initialize return value.
	HandlerAlgorithms = New Array;
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerRow = TrimL(StrGetLine(Handler, IndexOf));
		
		If StrStartsWith(HandlerRow, "//") Then //Skipping the commented string
			Continue;
		EndIf;
		
		GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
		
	EndDo;
	
	Return HandlerAlgorithms;
EndFunction 

// Gets the prefix string to output nested algorithm code.
//
// Parameters:
//  HandlerRow - String - a source string where the call offset value
//                      will be retrieved from.
//  PrefixString    - String - the initial offset.
// Returns:
//  String - 
// 
Function GetInlineAlgorithmPrefix(HandlerRow, PrefixString)
	
	HandlerRow = Upper(HandlerRow);
	
	TemplatePositionNumberExecute = StrFind(HandlerRow, "EXECUTE");
	
	PrefixStringForInlineCode = PrefixString + Left(HandlerRow, TemplatePositionNumberExecute - 1) + Chars.Tab;
	
	// 
	HandlerRow = "";
	
	Return PrefixStringForInlineCode;
EndFunction 

#EndRegion

#Region FunctionsForGenerationUniqueNameOfEventHandlers

// Generates PCR or PGCR handler interface, that is a unique name of the procedure with parameters of the corresponding handler).
//
// Parameters:
//  OCR            - ValueTableRow - contains an object conversion rule.
//  PGCR           - ValueTableRow - contains a property group conversion rule.
//  Rule        - ValueTableRow - contains an object properties conversion rule.
//  HandlerName - String - an event handler name.
//
// Returns:
//  String - 
//
Function GetPCRHandlerInterface(OCR, PGCR, Rule, HandlerName)
	
	Prefix_Name = ?(Rule.IsFolder, "PGCR", "PCR");
	AreaName   = Prefix_Name + "_" + HandlerName;
	
	OwnerName = "_" + TrimAll(OCR.Name);
	
	ParentName  = "";
	
	If PGCR <> Undefined Then
		
		If Not IsBlankString(PGCR.DestinationKind) Then 
			
			ParentName = "_" + TrimAll(PGCR.Receiver);	
			
		EndIf; 
		
	EndIf; 
	
	DestinationName = "_" + TrimAll(Rule.Receiver);
	DestinationKind = "_" + TrimAll(Rule.DestinationKind);
	
	PropertyCode = TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + OwnerName + ParentName + DestinationName + DestinationKind + PropertyCode;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates an OCR, DER, or DPR handler interface, that is a unique name of the procedure with the parameters of the corresponding handler.
//
// Parameters:
//  Rule            - ValueTableRow - OCR, DER, DPR:
//    * Name - String - a rule name.
//  HandlerPrefix - String - possible values are: OCR, DER, DPR.
//  HandlerName     - String - the name handler events for this rules.
//
// Returns:
//  String - 
// 
Function GetHandlerInterface(Rule, HandlerPrefix, HandlerName)
	
	AreaName = HandlerPrefix + "_" + HandlerName;
	
	RuleName = "_" + TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + RuleName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates the interface of the global conversion handler (Generates a unique name of the procedure with parameters of the corresponding
// handler).
//
// Parameters:
//  HandlerName - String - a conversion event handler name.
//
// Returns:
//  String - 
// 
Function GetConversionHandlerInterface(HandlerName)
	
	AreaName = "Conversion_" + HandlerName;
	
	FullHandlerName = AreaName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates procedure interface (constructor or destructor) for an external data processor.
//
// Parameters:
//  ProcedureName - String - a name of procedure.
//
// Returns:
//  String - 
// 
Function GetExternalDataProcessorProcedureInterface(ProcedureName)
	
	AreaName = "DataProcessor_" + ProcedureName;
	
	FullHandlerName = ProcedureName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates an algorithm interface for an external data processor.
// Getting the same parameter set by default for all algorithms.
//
// Parameters:
//  AlgorithmName - String - an algorithm name.
//
// Returns:
//  String - 
// 
Function GetAlgorithmInterface(AlgorithmName)
	
	FullHandlerName = "Algorithm_" + AlgorithmName;
	
	AreaName = "AlgorithmByDefault";
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

Function GetHandlerCallString(Rule, HandlerName)
	
	Return "EventHandlersExternalDataProcessor." + Rule["HandlerInterface" + HandlerName] + ";";
	
EndFunction 

Function GetTextByAreaWithoutAreaTitle(Area)
	
	AreaText = Area.GetText();
	
	If StrFind(AreaText, "#Area") > 0 Then
	
		FirstLinefeed = StrFind(AreaText, Chars.LF);
		
		AreaText = Mid(AreaText, FirstLinefeed + 1);
		
	EndIf;
	
	Return AreaText;
	
EndFunction

Function GetHandlerParameters(AreaName)
	
	NewLineString = Chars.LF + "                                           ";
	
	HandlerParameters = "";
	
	TotalString1 = "";
	
	Area = mHandlerParameterTemplate.GetArea(AreaName);
	
	ParametersArea = Area.Areas[AreaName];
	
	For LineNumber = ParametersArea.Top To ParametersArea.Bottom Do
		
		CurrentArea = Area.GetArea(LineNumber, 2, LineNumber, 2);
		
		Parameter = TrimAll(CurrentArea.CurrentArea.Text);
		
		If Not IsBlankString(Parameter) Then
			
			HandlerParameters = HandlerParameters + Parameter + ", ";
			
			TotalString1 = TotalString1 + Parameter;
			
		EndIf; 
		
		If StrLen(TotalString1) > 50 Then
			
			TotalString1 = "";
			
			HandlerParameters = HandlerParameters + NewLineString;
			
		EndIf; 
		
	EndDo;
	
	HandlerParameters = TrimAll(HandlerParameters);
	
	// 
	
	Return Mid(HandlerParameters, 1, StrLen(HandlerParameters) - 1); 
EndFunction 

#EndRegion

#Region GeneratingHandlerCallInterfacesInExchangeRulesProcedures

// Complements the collection of data clearing rule values with handler interfaces.
//
// Parameters:
//  DPRTable   - ValueTree - contains data clearing rules.
//  TreeRows - ValueTreeRowCollection - object of the ValueTreeRowCollection type - contains DPR of this
//                                                value tree level.
//
Procedure SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlersNames.DPR Do
				
				AddHandlerInterface(DPRTable, Rule, "DPR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements the collection of data export rule values with handler interfaces.
//
// Parameters:
//  DERTable   - ValueTree - contains the data export rules.
//  TreeRows - ValueTreeRowCollection - object of the ValueTreeRowCollection type - contains DER of this
//                                                value tree level.
//
Procedure SupplementDataExportRulesWithHandlerInterfaces(DERTable, TreeRows) 
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementDataExportRulesWithHandlerInterfaces(DERTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlersNames.DER Do
				
				AddHandlerInterface(DERTable, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements conversion structure with handler interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  
Procedure SupplementWithConversionRuleInterfaceHandler(ConversionStructure) 
	
	For Each Item In HandlersNames.Conversion Do
		
		AddConversionHandlerInterface(ConversionStructure, Item.Key);
		
	EndDo; 
	
EndProcedure  

// Complements the collection of object conversion rule values with handler interfaces.
//
// Parameters:
//  OCRTable - See ConversionRulesCollection
//  
Procedure SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable)
	
	For Each OCR In OCRTable Do
		
		For Each Item In HandlersNames.OCR Do
			
			AddOCRHandlerInterface(OCRTable, OCR, Item.Key);
			
		EndDo; 
		
		// Adding interfaces for PCR.
		SupplementWithPCRHandlersInterfaces(OCR, OCR.SearchProperties);
		SupplementWithPCRHandlersInterfaces(OCR, OCR.Properties);
		
	EndDo; 
	
EndProcedure

// Complements the collection of object property conversion rule values with handler interfaces.
//
// Parameters:
//  OCR - ValueTableRow    - contains an object conversion rule.
//  ObjectPropertiesConversionRules - ValueTable - contains rules of conversion of properties or property group of
//                                                       an object from the OCR rule.
//  PGCR - ValueTableRow   - contains a property group conversion rule.
//
Procedure SupplementWithPCRHandlersInterfaces(OCR, ObjectPropertiesConversionRules, PGCR = Undefined)
	
	For Each PCR In ObjectPropertiesConversionRules Do
		
		If PCR.IsFolder Then // ПКГС
			
			For Each Item In HandlersNames.PGCR Do
				
				AddPCRHandlerInterface(ObjectPropertiesConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 

			SupplementWithPCRHandlersInterfaces(OCR, PCR.GroupRules, PCR);
			
		Else
			
			For Each Item In HandlersNames.PCR Do
				
				AddPCRHandlerInterface(ObjectPropertiesConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

Procedure AddHandlerInterface(Table, Rule, HandlerPrefix, HandlerName) 
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
		
	Rule[FieldName] = GetHandlerInterface(Rule, HandlerPrefix, HandlerName);
	
EndProcedure 

Procedure AddOCRHandlerInterface(Table, Rule, HandlerName) 
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	Rule[FieldName] = GetHandlerInterface(Rule, "OCR", HandlerName);
  
EndProcedure 

Procedure AddPCRHandlerInterface(Table, OCR, PGCR, PCR, HandlerName) 
	
	If Not PCR["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	PCR[FieldName] = GetPCRHandlerInterface(OCR, PGCR, PCR, HandlerName);
	
EndProcedure  

Procedure AddConversionHandlerInterface(ConversionStructure, HandlerName)
	
	HandlerAlgorithm = "";
	
	If ConversionStructure.Property(HandlerName, HandlerAlgorithm) And Not IsBlankString(HandlerAlgorithm) Then
		
		FieldName = "HandlerInterface" + HandlerName;
		
		ConversionStructure.Insert(FieldName);
		
		ConversionStructure[FieldName] = GetConversionHandlerInterface(HandlerName); 
		
	EndIf;
	
EndProcedure  

#EndRegion

#Region ExchangeRulesOperationProcedures

Function GetPlatformByDestinationPlatformVersion(PlatformVersion)
	
	If StrFind(PlatformVersion, "8.") > 0 Then
		
		Return "V8";
		
	Else
		
		Return "V7";
		
	EndIf;	
	
EndFunction

// Restores rules from the internal format.
//
// Parameters:
// 
Procedure RestoreRulesFromInternalFormat() Export

	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RulesStructure = SavedSettings.Get(); // See RulesStructureDetails

	ExportRulesTable      = RulesStructure.ExportRulesTable;
	ConversionRulesTable   = RulesStructure.ConversionRulesTable;
	Algorithms                  = RulesStructure.Algorithms;
	QueriesToRestore   = RulesStructure.Queries;
	Conversion                = RulesStructure.Conversion;
	mXMLRules                = RulesStructure.mXMLRules;
	ParametersSetupTable = RulesStructure.ParametersSetupTable;
	Parameters                  = RulesStructure.Parameters;
	
	SupplementInternalTablesWithColumns();
	
	RulesStructure.Property("DestinationPlatformVersion", DestinationPlatformVersion);
	
	DestinationPlatform = GetPlatformByDestinationPlatformVersion(DestinationPlatformVersion);
		
	HasBeforeExportObjectGlobalHandler    = Not IsBlankString(Conversion.BeforeExportObject);
	HasAfterExportObjectGlobalHandler     = Not IsBlankString(Conversion.AfterExportObject);
	HasBeforeImportObjectGlobalHandler    = Not IsBlankString(Conversion.BeforeImportObject);
	HasAfterObjectImportGlobalHandler     = Not IsBlankString(Conversion.AfterImportObject);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeConvertObject);

	// 
	Queries.Clear();
	For Each StructureItem In QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;

	InitManagersAndMessages();
	
	Rules.Clear();
	ClearManagersOCR();
	
	If ExchangeMode = "Upload0" Then
	
		For Each TableRow In ConversionRulesCollection() Do
			Rules.Insert(TableRow.Name, TableRow);
			
			Source = TableRow.Source;

			If Source <> Undefined Then
				
				Try
					If TypeOf(Source) = deStringType Then
						Managers[Type(Source)].OCR = TableRow;
					Else
						Managers[Source].OCR = TableRow;
					EndIf;
				Except
					WriteErrorInfoToProtocol(11, ErrorProcessing.DetailErrorDescription(ErrorInfo()), String(Source));
				EndTry;
				
			EndIf;

		EndDo;
	
	EndIf;	
	
EndProcedure

// Initializes parameters by default values from the exchange rules.
//
// Parameters:
//  No.
// 
Procedure InitializeInitialParameterValues() Export
	
	For Each CurParameter In Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ClearingRuleProcessing

Procedure ExecuteObjectDeletion(Object, Properties, DeleteDirectly)
	
	TypeName = Properties.TypeName;
	
	If TypeName = "InformationRegister" Then
		
		Object.Delete();
		
	Else
		
		If (TypeName = "Catalog"
			Or TypeName = "ChartOfCharacteristicTypes"
			Or TypeName = "ChartOfAccounts"
			Or TypeName = "ChartOfCalculationTypes")
			And Object.Predefined Then
			
			Return;
			
		EndIf;
		
		If DeleteDirectly Then
			
			Object.Delete();
			
		Else
			
			SetObjectDeletionMark(Object, True, Properties.TypeName);
			
		EndIf;
			
	EndIf;	
	
EndProcedure

// Clears data according to the specified rule.
//
// Parameters:
//   Rule - ValueTableRow - data clearing rule reference:
//     * Name - String - a rule name.
// 
Procedure ClearDataByRule(Rule)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// BeforeProcess handle

	Cancel			= False;
	DataSelection	= Undefined;

	OutgoingData	= Undefined;


	// BeforeProcessClearingRule handler
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(27, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, "", "BeforeProcessClearingRule");
			
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard dataset.
	
	Properties = Managers[Rule.SelectionObject1];
	
	If Rule.DataFilterMethod = "StandardSelection" Then
		
		TypeName = Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			Or TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired  = Not IsBlankString(Rule.BeforeDeleteRow);
		
		Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
									
				SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);
					
			Else
					
				SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
					
			EndIf;
				
		EndDo;
		
	ElsIf Rule.DataFilterMethod = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
										
					If TypeName =  "InformationRegister" Then
				
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
											
						SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);				
											
					Else
							
						SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
							
					EndIf;					
					
				EndDo;	
				
			Else
				
				For Each Object In DataSelection Do
					
					SelectionObjectDeletion(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf; 
			
	EndIf; 

	
	// AfterProcessClearingRule handler

	If Not IsBlankString(Rule.AfterProcess) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(28, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, "", "AfterProcessClearingRule");
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Iterates the tree of data clearing rules and executes clearing.
//
// Parameters:
//  Rows         - 
// 
Procedure ProcessClearingRules(Rows)
	
	For Each ClearingRule In Rows Do
		
		If ClearingRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 

		If ClearingRule.IsFolder Then
			
			ProcessClearingRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure

#EndRegion

#Region DataImportProcedures

// Sets the Load parameter value for the DataExchange object property.
//
// Parameters:
//  Object   - the object for which the property is set.
//  Value - the value of the "Upload" property to set.
// 
Procedure SetDataExchangeLoad(Object, Value = True) Export
	
	If Not ImportDataInExchangeMode Then
		Return;
	EndIf;
	
	If HasAttributeOrObjectProperty(Object, "DataExchange") Then
		StructureToFill = New Structure("Load", Value);
		FillPropertyValues(Object.DataExchange, StructureToFill);
	EndIf;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UUID1 = SearchProperties["{UUID}"];
	
	If UUID1 <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UUID1));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction

// Searches for the object by its number in the list of already imported objects.
//
// Parameters:
//   NBSp - Number - a number of the object to be searched in the exchange file.
//
// Returns:
//   - AnyRef - 
//   - Undefined - 
// 
Function FindObjectByNumber(NBSp, MainObjectSearchMode = False)

	If NBSp = 0 Then
		Return Undefined;
	EndIf;
	
	ResultStructure1 = ImportedObjects[NBSp];
	
	If ResultStructure1 = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode And ResultStructure1.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure1.ObjectReference;
	EndIf; 

EndFunction

Function FindObjectByGlobalNumber(NBSp, MainObjectSearchMode = False)

	ResultStructure1 = ImportedGlobalObjects[NBSp];
	
	If ResultStructure1 = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode And ResultStructure1.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure1.ObjectReference;
	EndIf;
	
EndFunction

Procedure WriteObjectToIB(Object, Type)
		
	Try
		
		SetDataExchangeLoad(Object);
		Object.Write();
		
	Except
		
		ErrorMessageString = WriteErrorInfoToProtocol(26, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
			Object, Type);
		
		If Not FlagDebugMode Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Creates a new object of the specified type, sets attributes that are specified
// in the SearchProperties structure.
//
// Parameters:
//  Type - Type - type of the object to be created.
//  SearchProperties - Structure - contains attributes of a new object to be set.
//
// Returns:
//   Arbitrary - 
// 
Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, RegisterRecordSet = Undefined,
	NewRef = Undefined, NBSp = 0, Gsn = 0, ObjectParameters = Undefined,
	SetAllObjectSearchProperties = True)

	MDProperties      = Managers[Type];
	TypeName         = MDProperties.TypeName;
	Manager        = MDProperties.Manager; // 

	If TypeName = "Catalog"
		Or TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
						
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;		
				
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
				
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
				
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
				
	ElsIf TypeName = "InformationRegister" Then
		
		If WriteRegistersAsRecordSets Then
			
			RegisterRecordSet = Manager.CreateRecordSet();
			Object = RegisterRecordSet.Add();
			
		Else
			
			Object = Manager.CreateRecordManager();
						
		EndIf;
		
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
				
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess();
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef;	
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
				
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, Undefined, False, False);
	EndIf;
	
	// Checks.
	If TypeName = "Document"
		Or TypeName = "Task"
		Or TypeName = "BusinessProcess" Then
		
		If Not ValueIsFilled(Object.Date) Then
			
			Object.Date = CurrentSessionDate();
			
		EndIf;
		
	EndIf;
		
	// 
	// 
	
	If WriteObjectImmediatelyAfterCreation Then
		
		If Not ImportReferencedObjectsWithoutDeletionMark Then
			Object.DeletionMark = True;
		EndIf;
		
		If Gsn <> 0
			Or Not OptimizedObjectsWriting Then
		
			WriteObjectToIB(Object, Type);
			
		Else
			
			// 
			// 
			// 
			If NewRef = Undefined Then
				
				// Generating the new reference.
				NewUUID = New UUID;
				NewRef = Manager.GetRef(NewUUID);
				Object.SetNewObjectRef(NewRef);
				
			EndIf;
			
			SupplementNotWrittenObjectStack(NBSp, Gsn, Object, NewRef, Type, ObjectParameters);
			
			Return NewRef;
			
		EndIf;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads the object property node from the file and sets the property value.
//
// Parameters:
//  Type - Type - property value type.
//  ObjectFound - Boolean - False returned after function execution means
//                 that the property object is not found in the infobase and the new object was created.
//
// Returns:
//   Arbitrary - 
// 
Function ReadProperty(Type, OCRName = "")
	
	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Value" Then
			
			SearchByProperty = deAttribute(ExchangeFile, deStringType, "Property");
			Value         = deElementValue(ExchangeFile, Type, SearchByProperty, RemoveTrailingSpaces);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			Value       = FindObjectByRef(Type, OCRName);
			PropertyExistence = True;
			
		ElsIf NodeName = "NBSp" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Gsn" Then
			
			ExchangeFile.Read();
			Gsn = Number(ExchangeFile.Value);
			If Gsn <> 0 Then
				Value  = FindObjectByGlobalNumber(Gsn);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" Or NodeName = "ParameterValue") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			If Not PropertyExistence
				And ValueIsFilled(Type) Then
				
				// Если вообще ничего нет - 
				Value = deGetEmptyValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Expression = deElementValue(ExchangeFile, deStringType, , False);
			Value  = EvalExpression(Expression);
			
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetEmptyValue(Type);
			PropertyExistence = True;		
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;	
	
EndFunction

Function SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	ObjectAttributeChanged = False;
				
	For Each Property In SearchProperties Do
					
		Name      = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			And SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
					
		If Name = "IsFolder" 
			Or Name = "{UUID}" 
			Or Name = "{PredefinedItemName1}" Then
						
			Continue;
						
		ElsIf Name = "DeletionMark" Then
						
			If Not ShouldCompareWithCurrentAttributes
				Or FoundObject.DeletionMark <> Value Then
							
				FoundObject.DeletionMark = Value;
				ObjectAttributeChanged = True;
							
			EndIf;
						
		Else
				
			// Set attributes that are different.
			If FoundObject[Name] <> NULL Then
			
				If Not ShouldCompareWithCurrentAttributes
					Or FoundObject[Name] <> Value Then
						
					FoundObject[Name] = Value;
					ObjectAttributeChanged = True;
						
				EndIf;
				
			EndIf;
				
		EndIf;
					
	EndDo;
	
	Return ObjectAttributeChanged;
	
EndFunction

Function FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
	ObjectTypeName, SearchProperty, SearchPropertyValue, ObjectFound,
	CreateNewItemIfNotFound, FoundOrCreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, NBSp, Gsn,
	ObjectParameters, NewUUIDRef = Undefined)
	
	IsEnum = PropertyStructure.TypeName = "Enum";
	
	If IsEnum Then
		
		SearchString = "";
		
	Else
		
		SearchString = PropertyStructure.SearchString;
		
	EndIf;
	
	If MainObjectSearchMode Or IsBlankString(SearchString) Then
		SearchByUUIDQueryString = "";
	EndIf;
	
	Object = FindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue,
		FoundOrCreatedObject, , , SearchByUUIDQueryString);
		
	ObjectFound = Not (Object = Undefined Or Object.IsEmpty());
		
	If Not ObjectFound Then
		If CreateNewItemIfNotFound Then
		
			Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
				Not MainObjectSearchMode,,NewUUIDRef, NBSp, Gsn, ObjectParameters);
				
			ObjectPropertyModified = True;
		EndIf;
		Return Object;
	
	EndIf;
	
	If IsEnum Then
		Return Object;
	EndIf;			
	
	If MainObjectSearchMode Then
		
		If FoundOrCreatedObject = Undefined Then
			FoundOrCreatedObject = Object.GetObject();
		EndIf;
			
		ObjectPropertyModified = SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
	EndIf;
		
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, deStringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		Return Undefined;
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalData(TypesInformation, PropertyName)
	
	PropertyType1 = GetPropertyType();
				
	If PropertyType1 = Undefined
		And TypesInformation <> Undefined Then
		
		PropertyType1 = TypesInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType1;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypesInformation, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
					
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, deStringType, "Name");
			
			If Name = "{UUID}" 
				Or Name = "{PredefinedItemName1}" Then
				
				PropertyType1 = deStringType;
				
			Else
			
				PropertyType1 = GetPropertyTypeByAdditionalData(TypesInformation, Name);
			
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "NotReplace");
			SearchByEqualDate = SearchByEqualDate 
					Or deAttribute(ExchangeFile, deBooleanType, "SearchByEqualDate");
			//
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType1, OCRName);
			
			If (Name = "IsFolder") And (PropertyValue <> True) Then
				
				PropertyValue = False;
												
			EndIf;
			
			If IsParameter Then
				
				
				AddParameterIfNecessary(ObjectParameters, Name, PropertyValue);
				
			Else
			
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Function UnlimitedLengthField(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If Not TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute In TypeManager.MetadataObjectsList.Attributes Do
			
			If Attribute.Type.ContainsType(deStringType) 
				And (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name);	
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
		
EndFunction

Function IsUnlimitedLengthParameter(TypeManager, ParameterValue, ParameterName)
	
	Try
			
		If TypeOf(ParameterValue) = deStringType Then
			UnlimitedLengthString = UnlimitedLengthField(TypeManager, ParameterName);
		Else
			UnlimitedLengthString = False;
		EndIf;		
												
	Except
				
		UnlimitedLengthString = False;
				
	EndTry;
	
	Return UnlimitedLengthString;	
	
EndFunction

Function FindItemUsingRequest(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		And PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;	
	
	QueryText       = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery       = New Query();
	PropertyUsedInSearchCount = 0;
			
	For Each Property In SearchProperties Do
				
		ParameterName      = Property.Key;
		
		// The following parameters cannot be search fields.
		If ParameterName = "{UUID}"
			Or ParameterName = "{PredefinedItemName1}" Then
						
			Continue;
						
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
				
		Try
			
			UnlimitedLengthString = IsUnlimitedLengthParameter(PropertyStructure, ParameterValue, ParameterName);		
													
		Except
					
			UnlimitedLengthString = False;
					
		EndTry;
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
				
		If UnlimitedLengthString Then
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " And ", "") + ParameterName + " LIKE &" + ParameterName;
					
		Else
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " And ", "") + ParameterName + " = &" + ParameterName;
					
		EndIf;
								
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
			
	If Result.IsEmpty() Then
		
		Return Undefined;
								
	Else
		
		// Returning the first found object.
		Selection = Result.Select();
		Selection.Next();
		ObjectReference = Selection.Ref;
				
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Function GetAdditionalSearchBySearchFieldsUsageByObjectType(RefTypeString1)
	
	MapValue = mExtendedSearchParameterMap.Get(RefTypeString1);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Receiver = RefTypeString1 Then
				
				If Item.Value.SynchronizeByID = True Then
					
					MustContinueSearch = (Item.Value.SearchBySearchFieldsIfNotFoundByID = True);
					mExtendedSearchParameterMap.Insert(RefTypeString1, MustContinueSearch);
					
					Return MustContinueSearch;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mExtendedSearchParameterMap.Insert(RefTypeString1, False);
		Return False;
	
	Except
		
		mExtendedSearchParameterMap.Insert(RefTypeString1, False);
		Return False;
	
    EndTry;
	
EndFunction

// Determines the object conversion rule (OCR) by destination object type.
//
// Parameters:
//  RefTypeString1 - String - Object type as String. For example, CatalogRef.Products.
// 
// Returns:
//  MapValue = object conversion rule.
// 
Function GetConversionRuleWithSearchAlgorithmByDestinationObjectType(RefTypeString1)
	
	MapValue = mConversionRuleMap.Get(RefTypeString1);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Receiver = RefTypeString1 Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					mConversionRuleMap.Insert(RefTypeString1, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mConversionRuleMap.Insert(RefTypeString1, Undefined);
		Return Undefined;
	
	Except
		
		mConversionRuleMap.Insert(RefTypeString1, Undefined);
		Return Undefined;
	
	EndTry;
	
EndFunction

Function FindObjectRefBySingleProperty(SearchProperties, PropertyStructure)
	
	For Each Property In SearchProperties Do
					
		ParameterName      = Property.Key;
					
		// The following parameters cannot be search fields.
		If ParameterName = "{UUID}"
			Or ParameterName = "{PredefinedItemName1}" Then
						
			Continue;
						
		EndIf;
					
		ParameterValue = Property.Value;
		ObjectReference = FindObjectByProperty(PropertyStructure.Manager, ParameterName, ParameterValue, Undefined, PropertyStructure, SearchProperties);
		
	EndDo;
	
	Return ObjectReference;
	
EndFunction

Function FindDocumentRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// 
	SearchWithQuery = SearchByEqualDate Or (RealPropertyForSearchCount <> 2);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	DocumentNumber = SearchProperties["Number"];
	DocumentDate  = SearchProperties["Date"];
					
	If (DocumentNumber <> Undefined) And (DocumentDate <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
																		
	Else
						
		// По дате и номеру найти не удалось - 
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Function FindRefToCatalog(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Owner     = SearchProperties["Owner"];
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
				
	Qty          = 0;
				
	If Owner <> Undefined Then	Qty = 1 + Qty; EndIf;
	If Parent <> Undefined Then	Qty = 1 + Qty; EndIf;
	If Code <> Undefined Then Qty = 1 + Qty; EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty; EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code, , Parent, Owner);
																		
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, True, Parent, Owner);
											
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindRefToCCT(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Parent     <> Undefined Then	Qty = 1 + Qty EndIf;
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code, Parent);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, True, Parent);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
			
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindRefToExchangePlan(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, True);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindTaskRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
					
	If     (Code <> Undefined) And (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(Code);
												
	ElsIf (Code = Undefined) And (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, True);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindRefToBusinessProcess(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Qty          = 0;
				
	If Code <> Undefined Then Qty = 1 + Qty EndIf;
								
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If  (Code <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(Code);
												
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Procedure AddRefToImportedObjectList(GSNRef, RefSN, ObjectReference, DummyRef = False)
	
	// Remembering the object reference.
	If Not RememberImportedObjects 
		Or ObjectReference = Undefined Then
		
		Return;
		
	EndIf;
	
	RecordStructure = New Structure("ObjectReference, DummyRef", ObjectReference, DummyRef);
	
	// Remembering the object reference.
	If GSNRef <> 0 Then
		
		ImportedGlobalObjects[GSNRef] = RecordStructure;
		
	ElsIf RefSN <> 0 Then
		
		ImportedObjects[RefSN] = RecordStructure;
						
	EndIf;	
	
EndProcedure

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, SearchPropertyNameString, SearchByEqualDate)
	
	// 
	// 
	// 
		
	SearchWithQuery = False;	
	
	If IsBlankString(SearchPropertyNameString) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		SelectedProperties = StrSplit(SearchPropertyNameString, ", ", False);
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem In SearchProperties Do
			
			If SelectedProperties.Find(PropertyItem.Key) <> Undefined Then
				TemporarySearchProperties.Insert(PropertyItem.Key, PropertyItem.Value);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty = TemporarySearchProperties["{PredefinedItemName1}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty <> Undefined, 1, 0);
	
	
	If RealPropertyForSearchCount = 1 Then
				
		ObjectReference = FindObjectRefBySingleProperty(TemporarySearchProperties, PropertyStructure);
																						
	ElsIf ObjectTypeName = "Document" Then
				
		ObjectReference = FindDocumentRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
											
	ElsIf ObjectTypeName = "Catalog" Then
				
		ObjectReference = FindRefToCatalog(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
								
	ElsIf ObjectTypeName = "ChartOfCharacteristicTypes" Then
				
		ObjectReference = FindRefToCCT(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "ExchangePlan" Then
				
		ObjectReference = FindRefToExchangePlan(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "Task" Then
				
		ObjectReference = FindTaskRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
												
	ElsIf ObjectTypeName = "BusinessProcess" Then
				
		ObjectReference = FindRefToBusinessProcess(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
									
	Else
				
		SearchWithQuery = True;
				
	EndIf;
		
	If SearchWithQuery Then
			
		ObjectReference = FindItemUsingRequest(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
				
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Procedure ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, 
	SearchPropertiesDontReplace, ObjectReference, CreatedObject, WriteNewObjectToInfobase = True, ObjectAttributeChanged = False)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	If CreatedObject = Undefined Then
		CreatedObject = ObjectReference.GetObject();
	EndIf;
	
	ObjectAttributeChanged = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
	
	// Rewriting the object if changes were made.
	If ObjectAttributeChanged
		And WriteNewObjectToInfobase Then
		
		WriteObjectToIB(CreatedObject, ObjectType);
		
	EndIf;
	
EndProcedure

Function ProcessObjectSearchByStructure(ObjectNumber, ObjectType, CreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, ObjectFound,
	IsGlobalNumber, ObjectParameters)
	
	StructureOfData = mNotWrittenObjectGlobalStack[ObjectNumber];
	
	If StructureOfData <> Undefined Then
		
		ObjectPropertyModified = True;
		CreatedObject = StructureOfData.Object;
		
		If StructureOfData.KnownRef = Undefined Then
			
			SetObjectRef(StructureOfData);
			
		EndIf;
			
		ObjectReference = StructureOfData.KnownRef;
		ObjectParameters = StructureOfData.ObjectParameters;
		
		ObjectFound = False;
		
	Else
		
		CreatedObject = Undefined;
		
		If IsGlobalNumber Then
			ObjectReference = FindObjectByGlobalNumber(ObjectNumber, MainObjectSearchMode);
		Else
			ObjectReference = FindObjectByNumber(ObjectNumber, MainObjectSearchMode);
		EndIf;
		
	EndIf;
	
	If ObjectReference <> Undefined Then
		
		If MainObjectSearchMode Then
			
			SearchProperties = "";
			SearchPropertiesDontReplace = "";
			ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, , ObjectParameters);
			
			// Verifying search fields.
			If CreatedObject = Undefined Then
				
				CreatedObject = ObjectReference.GetObject();
				
			EndIf;
			
			ObjectPropertyModified = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
			
		Else
			
			deSkip(ExchangeFile);
			
		EndIf;
		
		Return ObjectReference;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;		
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;		
	EndIf;	
	
	TypesInformation = mDataTypeMapForImport[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypesInformation, SearchByEqualDate, ObjectParameters);	
	
EndProcedure

// Searches an object in the infobase and creates a new object, if it is not found.
//
// Parameters:
//  ObjectType     - 
//  SearchProperties - Structure - with properties to be used for object searching.
//  ObjectFound   - 
//
// Returns:
//  New or found infobase object.
//  
Function FindObjectByRef(ObjectType,
							OCRName = "",
							SearchProperties = "", 
							SearchPropertiesDontReplace = "", 
							ObjectFound = True, 
							CreatedObject = Undefined, 
							DontCreateObjectIfNotFound = Undefined,
							MainObjectSearchMode = False, 
							ObjectPropertyModified = False,
							GlobalRefSn = 0,
							RefSN = 0,
							KnownUUIDRef = Undefined,
							ObjectParameters = Undefined)

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	SearchByEqualDate = False;
	ObjectReference = Undefined;
	PropertyStructure = Undefined;
	ObjectTypeName = Undefined;
	DummyObjectRef = False;
	OCR = Undefined;
	SearchAlgorithm = "";
	
	If RememberImportedObjects Then
		
		// Есть номер по порядку из файла - 
		GlobalRefSn = deAttribute(ExchangeFile, deNumberType, "Gsn");
		
		If GlobalRefSn <> 0 Then
			
			ObjectReference = ProcessObjectSearchByStructure(GlobalRefSn, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, True, ObjectParameters);
			
			If ObjectReference <> Undefined Then
				Return ObjectReference;
			EndIf;
			
		EndIf;
		
		// Есть номер по порядку из файла - 
		RefSN = deAttribute(ExchangeFile, deNumberType, "NBSp");
		
		If RefSN <> 0 Then
		
			ObjectReference = ProcessObjectSearchByStructure(RefSN, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, False, ObjectParameters);
				
			If ObjectReference <> Undefined Then
				Return ObjectReference;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	DontCreateObjectIfNotFound = deAttribute(ExchangeFile, deBooleanType, "DontCreateIfNotFound");
	OnExchangeObjectByRefSetGIUDOnly = Not MainObjectSearchMode 
		And deAttribute(ExchangeFile, deBooleanType, "OnExchangeObjectByRefSetGIUDOnly");
	
	// Creating object search property.
	ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters);
		
	CreatedObject = Undefined;
	
	If Not ObjectFound Then
		
		ObjectReference = CreateNewObject(ObjectType, SearchProperties, CreatedObject, , , , RefSN, GlobalRefSn);
		AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectReference);
		Return ObjectReference;
		
	EndIf;	
		
	PropertyStructure   = Managers[ObjectType];
	ObjectTypeName     = PropertyStructure.TypeName;
		
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty = SearchProperties["{PredefinedItemName1}"];
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
		And UUIDProperty <> Undefined;
		
	// Searching by name if the item is predefined.
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = Not DontCreateObjectIfNotFound
			And Not OnExchangeObjectByRefSetGIUDOnly;
		
		ObjectReference = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{PredefinedItemName1}", PredefinedNameProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, MainObjectSearchMode, ObjectPropertyModified,
			RefSN, GlobalRefSn, ObjectParameters);
			
	ElsIf (UUIDProperty <> Undefined) Then
			
		// Creating the new item by the UUID is not always necessary. Perhaps, the search must be continued.
		MustContinueSearchIfItemNotFoundByGUID = GetAdditionalSearchBySearchFieldsUsageByObjectType(PropertyStructure.RefTypeString1);
		
		CreateNewObjectAutomatically = (Not DontCreateObjectIfNotFound
			And Not MustContinueSearchIfItemNotFoundByGUID)
			And Not OnExchangeObjectByRefSetGIUDOnly;
			
		ObjectReference = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{UUID}", UUIDProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, 
			MainObjectSearchMode, ObjectPropertyModified,
			RefSN, GlobalRefSn, ObjectParameters, KnownUUIDRef);
			
		If Not MustContinueSearchIfItemNotFoundByGUID Then

			If Not ValueIsFilled(ObjectReference)
				And OnExchangeObjectByRefSetGIUDOnly Then
				
				ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
				ObjectFound = False;
				DummyObjectRef = True;
			
			EndIf;
			
			If ObjectReference <> Undefined 
				And ObjectReference.IsEmpty() Then
						
				ObjectReference = Undefined;
						
			EndIf;
			
			If ObjectReference <> Undefined
				Or CreatedObject <> Undefined Then

				AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectReference, DummyObjectRef);
				
			EndIf;
			
			Return ObjectReference;	
			
		EndIf;
		
	EndIf;
		
	If ObjectReference <> Undefined 
		And ObjectReference.IsEmpty() Then
		
		ObjectReference = Undefined;
		
	EndIf;
		
	// ObjectRef is not found yet.
	If ObjectReference <> Undefined
		Or CreatedObject <> Undefined Then
		
		AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectReference);
		Return ObjectReference;
		
	EndIf;
	
	SearchVariantNumber = 1;
	SearchPropertyNameString = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByDestinationObjectType(PropertyStructure.RefTypeString1);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While SearchVariantNumber <= 10
		And HasSearchAlgorithm Do
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "SearchFieldSequence"));
					
			Else
				
				Execute(SearchAlgorithm);
			
			EndIf;
			
		Except
			
			WriteInfoOnOCRHandlerImportError(73, ErrorProcessing.DetailErrorDescription(ErrorInfo()), "", "",
				ObjectType, Undefined, NStr("en = 'Search field sequence';"));
			
		EndTry;
		
		DontSearch = StopSearch = True 
			Or SearchPropertyNameString = PreviousSearchString
			Or ValueIsFilled(ObjectReference);
		
		If Not DontSearch Then
		
			// 
			ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
				SearchPropertyNameString, SearchByEqualDate);
				
			DontSearch = ValueIsFilled(ObjectReference);
			
			If ObjectReference <> Undefined
				And ObjectReference.IsEmpty() Then
				ObjectReference = Undefined;
			EndIf;
			
		EndIf;
			
		If DontSearch Then
			
			If MainObjectSearchMode And SetAllObjectSearchProperties = True Then
				
				ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, SearchPropertiesDontReplace,
					ObjectReference, CreatedObject, Not MainObjectSearchMode, ObjectPropertyModified);
				
			EndIf;
			
			Break;
			
		EndIf;
		
		SearchVariantNumber = SearchVariantNumber + 1;
		PreviousSearchString = SearchPropertyNameString;
		
	EndDo;
	
	If Not HasSearchAlgorithm Then
		
		// 
		ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
					SearchPropertyNameString, SearchByEqualDate);
		
	EndIf;
	
	ObjectFound = ValueIsFilled(ObjectReference);
	
	If MainObjectSearchMode
		And ValueIsFilled(ObjectReference)
		And (ObjectTypeName = "Document" 
		Or ObjectTypeName = "Task"
		Or ObjectTypeName = "BusinessProcess") Then
		
		// Setting the date if it is in the document search fields.
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (Not EmptyDate) 
			And (SearchPropertiesDontReplace["Date"] = Undefined);
			
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectReference.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
			
		EndIf;
		
	EndIf;
	
	// Creating a new object is not always necessary.
	If Not ValueIsFilled(ObjectReference)
		And CreatedObject = Undefined Then 
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));	
			DummyObjectRef = True;
			
		ElsIf Not DontCreateObjectIfNotFound Then
		
			ObjectReference = CreateNewObject(ObjectType, SearchProperties, CreatedObject, Not MainObjectSearchMode, , KnownUUIDRef, RefSN, 
				GlobalRefSn, ,SetAllObjectSearchProperties);
				
			ObjectPropertyModified = True;
				
		EndIf;
			
		ObjectFound = False;
		
	Else
		
		ObjectFound = ValueIsFilled(ObjectReference);
		
	EndIf;
	
	If ObjectReference <> Undefined
		And ObjectReference.IsEmpty() Then
		
		ObjectReference = Undefined;
		
	EndIf;
	
	AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectReference, DummyObjectRef);
		
	Return ObjectReference;
	
EndFunction

// Sets object (record) properties.
//
// Parameters:
//  Record         - 
//                   
//
Procedure SetRecordProperties(Object, Record, TypesInformation,
	ObjectParameters, BranchName, SearchDataInTS, TSCopyForSearch, RecNo)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
								And (TSCopyForSearch <> Undefined)
								And TSCopyForSearch.Count() <> 0;
								
	If MustSearchInTS Then
		
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, deStringType, "Name");
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Name = "RecordType" And StrFind(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType1 = deAccumulationRecordTypeType;
				
			Else
				
				PropertyType1 = GetPropertyTypeByAdditionalData(TypesInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType1, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNecessary(ObjectParameters, BranchName, RecNo, Name, PropertyValue);			
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue);	
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					WP = GetProtocolRecordStructure(26, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					WP.OCRName           = OCRName;
					WP.Object           = Object;
					WP.ObjectType       = TypeOf(Object);
					WP.Property         = String(Record) + "." + Name;
					WP.Value         = PropertyValue;
					WP.ValueType      = TypeOf(PropertyValue);
					ErrorMessageString = WriteToExecutionProtocol(26, WP, True);
					
					If Not FlagDebugMode Then
						Raise ErrorMessageString;
					EndIf;
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" Or NodeName = "ExtDimensionCr" Then
			
			// The search by extra dimensions is not implemented.
			
			Var_Key = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
								
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, deStringType, "Name");
					OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
					PropertyType1 = GetPropertyTypeByAdditionalData(TypesInformation, Name);
										
					If Name = "Key" Then
						
						Var_Key = ReadProperty(PropertyType1);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType1, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionDr" Or NodeName = "ExtDimensionCr") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
					
					Break;
					
				Else
					
					WriteToExecutionProtocol(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If Var_Key <> Undefined 
				And Value <> Undefined Then
				
				If Not MustSearchInTS Then
				
					Record[NodeName][Var_Key] = Value;
					
				Else
					
					RecordMap = Undefined;
					If Not ExtDimensionReadingStructure.Property(NodeName, RecordMap) Then
						RecordMap = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMap);
					EndIf;
					
					RecordMap.Insert(Var_Key, Value);
					
				EndIf;
				
			EndIf;
				
		ElsIf (NodeName = "Record") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		TheStructureOfTheSearch = New Structure();
		
		For Each SearchItem In  SearchDataInTS.TSSearchFields Do
			
			ElementValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ElementValue);
			
			TheStructureOfTheSearch.Insert(SearchItem, ElementValue);		
			
		EndDo;		
		
		SearchResultArray = TSCopyForSearch.FindRows(TheStructureOfTheSearch);
		
		FoundRecord = SearchResultArray.Count() > 0;
		If FoundRecord Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Filling with properties and extra dimension value.
		For Each KeyAndValue In PropertyReadingStructure Do
			
			Record[KeyAndValue.Key] = KeyAndValue.Value;
			
		EndDo;
		
		For Each ItemName In ExtDimensionReadingStructure Do
			
			For Each ItemKey1 In ItemName.Value Do
			
				Record[ItemName.Key][ItemKey1.Key] = ItemKey1.Value;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports an object tabular section.
//
// Parameters:
//  Object         - 
//  Name            - name of the table part.
//  Clear       - 
// 
Procedure ImportTabularSection(Object, Name, Clear, GeneralDocumentTypeInformation, NeedToWriteObject, 
	ObjectParameters, Rule)

	TabularSectionName = Name + "TabularSection";
	If GeneralDocumentTypeInformation <> Undefined Then
		TypesInformation = GeneralDocumentTypeInformation[TabularSectionName];
	Else
	    TypesInformation = Undefined;
	EndIf;
			
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("TabularSection." + Name, "TagName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	TS = Object[Name];

	If Clear
		And TS.Count() <> 0 Then
		
		NeedToWriteObject = True;
		
		If SearchDataInTS <> Undefined Then
			TSCopyForSearch = TS.Unload();
		EndIf;
		TS.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = TS.Unload();
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Record" Then
			Try
				
				NeedToWriteObject = True;
				Record = TS.Add();
				
			Except
				Record = Undefined;
			EndTry;
			
			If Record = Undefined Then
				deSkip(ExchangeFile);
			Else
				SetRecordProperties(Object, Record, TypesInformation, ObjectParameters, TabularSectionName, SearchDataInTS, TSCopyForSearch, RecNo);
			EndIf;
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "TabularSection") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure 

// Imports object records
//
// Parameters:
//  Object         - 
//  Name            - register name.
//  Clear       - 
// 
Procedure ImportRegisterRecords(Object, Name, Clear, GeneralDocumentTypeInformation, NeedToWriteObject, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If GeneralDocumentTypeInformation <> Undefined Then
		TypesInformation = GeneralDocumentTypeInformation[RegisterRecordName];
	Else
	    TypesInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("RecordSet." + Name, "TagName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	RegisterRecords.Write = True;
	
	If RegisterRecords.Count()=0 Then
		RegisterRecords.Read();
	EndIf;
	
	If Clear
		And RegisterRecords.Count() <> 0 Then
		
		NeedToWriteObject = True;
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
        RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload();	
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
			
		If NodeName = "Record" Then
			
			Record = RegisterRecords.Add();
			NeedToWriteObject = True;
			SetRecordProperties(Object, Record, TypesInformation, ObjectParameters, RegisterRecordName, SearchDataInTS, TSCopyForSearch, RecNo);
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "RecordSet") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports an object of the TypeDescription type from the specified XML source.
//
// Parameters:
//  Source - XMLWriter - an XML source.
// 
Function ImportObjectTypes(Source)
	
	// DateQualifiers
	
	DateComposition =  deAttribute(Source, deStringType,  "DateComposition");
	
	// StringQualifiers
	
	Length           =  deAttribute(Source, deNumberType,  "Length");
	Var_AllowedLength =  deAttribute(Source, deStringType, "AllowedLength");
	
	// NumberQualifiers
	
	Digits             = deAttribute(Source, deNumberType,  "Digits");
	FractionDigits = deAttribute(Source, deNumberType,  "FractionDigits");
	AllowedFlag          = deAttribute(Source, deStringType, "AllowedSign");
	
	// Read the array of types.
	
	TypesArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If      NodeName = "Type" Then
			TypesArray.Add(Type(deElementValue(Source, deStringType)));
		ElsIf (NodeName = "Types") And ( Source.NodeType = deXMLNodeTypeEndElement) Then
			Break;
		Else
			WriteToExecutionProtocol(9);
			Break;
		EndIf;
		
	EndDo;
	
	If TypesArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateComposition = "Date" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Date);
		ElsIf DateComposition = "DateTime" Then
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateComposition = "Time" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		EndIf;
		
		// NumberQualifiers
		
		If Digits > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Character = AllowedSign.Nonnegative;
			Else
				Character = AllowedSign.Any;
			EndIf; 
			NumberQualifiers  = New NumberQualifiers(Digits, FractionDigits, Character);
		Else
			NumberQualifiers  = New NumberQualifiers();
		EndIf;
		
		// StringQualifiers
		
		If Length > 0 Then
			If Var_AllowedLength = "Fixed" Then
				Var_AllowedLength = AllowedLength.Fixed;
			Else
				Var_AllowedLength = AllowedLength.Variable;
			EndIf;
			StringQualifiers = New StringQualifiers(Length, Var_AllowedLength);
		Else
			StringQualifiers = New StringQualifiers();
		EndIf;
		
		Return New TypeDescription(TypesArray, NumberQualifiers, StringQualifiers, DateQualifiers);
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName)
	
	If (DeletionMark = Undefined)
		And (Object.DeletionMark <> True) Then
		
		Return;
		
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeLoad(Object);
		
	// For hierarchical object the deletion mark is set only for the current object.
	If ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ChartOfAccounts" Then
			
		Object.SetDeletionMark(MarkToSet, False);
			
	Else	
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf;
	
EndProcedure

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
						
		Document.Posted = False;
			
	EndIf;		
								
	WriteObjectToIB(Document, ObjectType);
	
EndProcedure

Function GetObjectByRefAndAdditionalInformation(CreatedObject, Ref)
	
	// If you have created an object, work with it, if you have found an object, receive it.
	If CreatedObject <> Undefined Then
		Object = CreatedObject;
	Else
		If Ref.IsEmpty() Then
			Object = Undefined;
		Else
			Object = Ref.GetObject();
		EndIf;		
	EndIf;
	
	Return Object;
	
EndFunction

Procedure ObjectImportComments(NBSp, RuleName, Source, ObjectType, Gsn = 0)
	
	If CommentObjectProcessingFlag Then
		
		If NBSp <> 0 Then
			MessageString = SubstituteParametersToString(NStr("en = 'Importing object #%1';"), NBSp);
		Else
			MessageString = SubstituteParametersToString(NStr("en = 'Importing object #%1';"), Gsn);
		EndIf;
		
		WP = GetProtocolRecordStructure();
		
		If Not IsBlankString(RuleName) Then
			
			WP.OCRName = RuleName;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			WP.Source = Source;
			
		EndIf;
		
		WP.ObjectType = ObjectType;
		WriteToExecutionProtocol(MessageString, WP, False);
		
	EndIf;	
	
EndProcedure

Procedure AddParameterIfNecessary(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNecessary(DataParameters, ParameterBranchName, LineNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData);	
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;		
	
	RowData = CurrentParameterData.Find(LineNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = LineNumber;
	EndIf;		
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Procedure SetObjectRef(NotWrittenObjectStackRow)
	
	// The is not written yet but need a reference.
	ObjectToWrite1 = NotWrittenObjectStackRow.Object;
	
	MDProperties      = Managers[NotWrittenObjectStackRow.ObjectType];
	Manager        = MDProperties.Manager;
		
	NewUUID = New UUID;
	NewRef = Manager.GetRef(NewUUID);
		
	ObjectToWrite1.SetNewObjectRef(NewRef);
	NotWrittenObjectStackRow.KnownRef = NewRef;
	
EndProcedure

Procedure SupplementNotWrittenObjectStack(NBSp, Gsn, Object, KnownRef, ObjectType, ObjectParameters)
	
	NumberForStack = ?(NBSp = 0, Gsn, NBSp);
	
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Object", Object);
	ParametersStructure.Insert("KnownRef", KnownRef);
	ParametersStructure.Insert("ObjectType", ObjectType);
	ParametersStructure.Insert("ObjectParameters", ObjectParameters);

	mNotWrittenObjectGlobalStack.Insert(NumberForStack, ParametersStructure);
	
EndProcedure

Procedure DeleteFromNotWrittenObjectStack(NBSp, Gsn)
	
	NumberForStack = ?(NBSp = 0, Gsn, NBSp);
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString = Undefined Then
		Return;
	EndIf;
	
	mNotWrittenObjectGlobalStack.Delete(NumberForStack);
	
EndProcedure

Procedure ExecuteWriteNotWrittenObjects()
	
	If mNotWrittenObjectGlobalStack = Undefined Then
		Return;
	EndIf;
	
	For Each DataString1 In mNotWrittenObjectGlobalStack Do
		
		// 
		Object = DataString1.Value.Object; // 
		RefSN = DataString1.Key;
		
		WriteObjectToIB(Object, DataString1.Value.ObjectType);
		
		AddRefToImportedObjectList(0, RefSN, Object.Ref);
		
	EndDo;
	
	mNotWrittenObjectGlobalStack.Clear();
	
EndProcedure

Procedure ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, NeedToWriteObject, 
	DataExchangeMode1)
	
	If Not GenerateNewNumberOrCodeIfNotSet
		Or Not DataExchangeMode1 Then
		
		// 
		// 
		Return;
	EndIf;
	
	// Checking whether the code or number are filled (depends on the object type).
	If ObjectTypeName = "Document"
		Or ObjectTypeName =  "BusinessProcess"
		Or ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			NeedToWriteObject = True;
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes"
		Or ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			NeedToWriteObject = True;
			
		EndIf;	
		
	EndIf;
	
EndProcedure

// Reads the next object from the exchange file and imports it.
//
// Parameters:
//  No.
// 
Function ReadObject()

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	NBSp						= deAttribute(ExchangeFile, deNumberType,  "NBSp");
	Gsn					= deAttribute(ExchangeFile, deNumberType,  "Gsn");
	Source				= deAttribute(ExchangeFile, deStringType, "Source");
	RuleName				= deAttribute(ExchangeFile, deStringType, "RuleName");
	DontReplaceObject 		= deAttribute(ExchangeFile, deBooleanType, "NotReplace");
	AutonumberingPrefix	= deAttribute(ExchangeFile, deStringType, "AutonumberingPrefix");
	ObjectTypeString       = deAttribute(ExchangeFile, deStringType, "Type");
	ObjectType 				= Type(ObjectTypeString);
	TypesInformation = mDataTypeMapForImport[ObjectType];

	ObjectImportComments(NBSp, RuleName, Source, ObjectType, Gsn);    
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName   = PropertyStructure.TypeName;

	If ObjectTypeName = "Document" Then
		
		WriteMode     = deAttribute(ExchangeFile, deStringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, deStringType, "PostingMode");
		
	EndIf;	
	
	Ref          = Undefined;
	Object          = Undefined; // 
	ObjectFound    = True;
	DeletionMark = Undefined;
	
	SearchProperties  = New Map;
	SearchPropertiesDontReplace  = New Map;
	
	NeedToWriteObject = Not WriteToInfobaseOnlyChangedObjects;
	


	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler    = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		GenerateNewNumberOrCodeIfNotSet = Rule.GenerateNewNumberOrCodeIfNotSet;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler    = False;
		HasAfterImportHandler  = False;
		GenerateNewNumberOrCodeIfNotSet = False;
		
	EndIf;


    // BeforeImportObject global event handler.
	If HasBeforeImportObjectGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeImportObject"));
				
			Else
				
				Execute(Conversion.BeforeImportObject);
				
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (global-level)';");
			WriteInfoOnOCRHandlerImportError(53, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
				RuleName, Source, ObjectType, Undefined,
				SubstituteParametersToString(HandlerName, "BeforeImportObject"));
							
		EndTry;
						
		If Cancel Then	//	
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
	// BeforeImportObject event handler.
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeImport"));
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteInfoOnOCRHandlerImportError(19, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				RuleName, Source, ObjectType, Undefined, "BeforeImportObject");
			
		EndTry;
		
		If Cancel Then // 
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	ObjectPropertyModified = False;
	RecordSet = Undefined;
	GlobalRefSn = 0;
	RefSN = 0;
	ObjectParameters = Undefined;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			Or NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If Not IsParameterForObject
				And Object = Undefined Then
				
				// Объект не нашли и не создали - 
				ObjectFound = False;

			    // OnImportObject event handler.
				If HasOnImportHandler Then
					
					// Rewriting the object if OnImporthandler exists, because of possible changes.
					WriteObjectWasRequired = NeedToWriteObject;
					ObjectIsModified = True;
										
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
						
						EndIf;
						NeedToWriteObject = ObjectIsModified Or WriteObjectWasRequired;
						
					Except
						
						WriteInfoOnOCRHandlerImportError(20, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
							RuleName, Source, ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;

				// Failed to create the object in the event, creating it separately.
				If Object = Undefined Then
					
					NeedToWriteObject = True;
					
					If ObjectTypeName = "Constants" Then
						
						Object = Constants.CreateSet();
						Object.Read();
						
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSN, GlobalRefSn, ObjectParameters);
												
					EndIf;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "NotReplace");
			OCRName             = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Not IsParameterForObject
				And ((ObjectFound And DontReplaceProperty) 
				Or (Name = "IsFolder")
				Or (Object[Name] = NULL)) Then
				
				// Unknown property.
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 

			
			// Reading and setting the property value.
			PropertyType1 = GetPropertyTypeByAdditionalData(TypesInformation, Name);
			Value    = ReadProperty(PropertyType1, OCRName);
			
			If IsParameterForObject Then
				
				// Supplementing the object parameter collection.
				AddParameterIfNecessary(ObjectParameters, Name, Value);
				
			Else
			
				If Name = "DeletionMark" Then
					
					DeletionMark = Value;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						NeedToWriteObject = True;
					EndIf;
										
				Else
					
					Try
						
						If Not NeedToWriteObject Then
							
							NeedToWriteObject = (Object[Name] <> Value);
							
						EndIf;
						
						Object[Name] = Value;
						
					Except
						
						WP = GetProtocolRecordStructure(26, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
						WP.OCRName           = RuleName;
						WP.NBSp              = NBSp;
						WP.Gsn             = Gsn;
						WP.Source         = Source;
						WP.Object           = Object;
						WP.ObjectType       = ObjectType;
						WP.Property         = Name;
						WP.Value         = Value;
						WP.ValueType      = TypeOf(Value);
						ErrorMessageString = WriteToExecutionProtocol(26, WP, True);
						
						If Not FlagDebugMode Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;					
									
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then
			
			// Reference to item. First receiving an object by reference, and then setting properties.
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			
			Ref = FindObjectByRef(ObjectType,
								RuleName, 
								SearchProperties,
								SearchPropertiesDontReplace,
								ObjectFound,
								CreatedObject,
								DontCreateObjectIfNotFound,
								True,
								ObjectPropertyModified,
								GlobalRefSn,
								RefSN,
								KnownUUIDRef,
								ObjectParameters);
			
			NeedToWriteObject = NeedToWriteObject Or ObjectPropertyModified;
			
			If Ref = Undefined
				And DontCreateObjectIfNotFound = True Then
				
				deSkip(ExchangeFile, "Object");
				Break;
			
			ElsIf ObjectTypeName = "Enum" Then
				
				Object = Ref;
			
			Else
				
				Object = GetObjectByRefAndAdditionalInformation(CreatedObject, Ref);
				
				If ObjectFound And DontReplaceObject And (Not HasOnImportHandler) Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					SupplementNotWrittenObjectStack(NBSp, Gsn, CreatedObject, KnownUUIDRef, ObjectType, ObjectParameters);
					
				EndIf;
							
			EndIf; 
			
		    // OnImportObject event handler.
			If HasOnImportHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
				ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "OnImport"));
						
					Else
						
						Execute(Rule.OnImport);
						
					EndIf;
					
					NeedToWriteObject = ObjectIsModified Or WriteObjectWasRequired;
					
				Except
					DeleteFromNotWrittenObjectStack(NBSp, Gsn);
					WriteInfoOnOCRHandlerImportError(20, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
						RuleName, Source, ObjectType, Object, "OnImportObject");
					
				EndTry;
				
				If ObjectFound And DontReplaceObject Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "TabularSection"
			Or NodeName = "RecordSet" Then

			If Object = Undefined Then
				
				ObjectFound = False;

				// OnImportObject event handler.
				
				If HasOnImportHandler Then
					
					WriteObjectWasRequired = NeedToWriteObject;
					ObjectIsModified = True;
					
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
						NeedToWriteObject = ObjectIsModified Or WriteObjectWasRequired;
						
					Except
						DeleteFromNotWrittenObjectStack(NBSp, Gsn);
						WriteInfoOnOCRHandlerImportError(20, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
							RuleName, Source, ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "NotReplace");
			NotClear          = deAttribute(ExchangeFile, deBooleanType, "NotClear");

			If ObjectFound And DontReplaceProperty Then
				
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
					
				CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSN, GlobalRefSn, ObjectParameters);
				NeedToWriteObject = True;
									
			EndIf;
			
			If NodeName = "TabularSection" Then
				
				// Importing items from the tabular section
				ImportTabularSection(Object, Name, Not NotClear, TypesInformation, NeedToWriteObject, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// Import register records.
				ImportRegisterRecords(Object, Name, Not NotClear, TypesInformation, NeedToWriteObject, ObjectParameters, Rule);
				
			EndIf;			
			
		ElsIf (NodeName = "Object") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Cancel = False;
			
		    // AfterObjectImport global event handler.
			If HasAfterObjectImportGlobalHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
				ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Conversion, "AfterImportObject"));
						
					Else
						
						Execute(Conversion.AfterImportObject);
						
					EndIf;
					
					NeedToWriteObject = ObjectIsModified Or WriteObjectWasRequired;
					
				Except
					
					DeleteFromNotWrittenObjectStack(NBSp, Gsn);
					
					HandlerName = NStr("en = '%1 (global-level)';");
					WriteInfoOnOCRHandlerImportError(54, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
							RuleName, Source, ObjectType, Object,
							SubstituteParametersToString(HandlerName, "AfterImportObject"));
					
				EndTry;
				
			EndIf;
			
			// AfterObjectImport event handler.
			If HasAfterImportHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
				ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "AfterImport"));
						
					Else
						
						Execute(Rule.AfterImport);
				
					EndIf;
					
					NeedToWriteObject = ObjectIsModified Or WriteObjectWasRequired;
					
				Except
					DeleteFromNotWrittenObjectStack(NBSp, Gsn);
					WriteInfoOnOCRHandlerImportError(21, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
						RuleName, Source, ObjectType, Object, "AfterImportObject");
						
				EndTry;
				
			EndIf;
			
			If ObjectTypeName <> "InformationRegister"
				And ObjectTypeName <> "Constants"
				And ObjectTypeName <> "Enum" Then
				// 
				Cancel = Cancel Or DisableDataChangeByDate(Object);
			EndIf;
			
			If Cancel Then
				
				AddRefToImportedObjectList(GlobalRefSn, RefSN, Undefined);
				DeleteFromNotWrittenObjectStack(NBSp, Gsn);
				Return Undefined;
				
			EndIf;
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				Else
					
					WriteMode = ?(WriteMode = "UndoPosting", DocumentWriteMode.UndoPosting, DocumentWriteMode.Write);
					
				EndIf;
				
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);
				

				// Clearing the deletion mark to post the marked for deletion object.
				If Object.DeletionMark
					And (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					NeedToWriteObject = True;
					
					// 
					DeletionMark = False;
									
				EndIf;				
				
				Try
					
					NeedToWriteObject = NeedToWriteObject Or (WriteMode <> DocumentWriteMode.Write);
					
					DataExchangeMode1 = WriteMode = DocumentWriteMode.Write;
					
					ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, 
						ObjectTypeName, NeedToWriteObject, DataExchangeMode1);
					
					If NeedToWriteObject Then
					
						SetDataExchangeLoad(Object, DataExchangeMode1);
						If Object.Posted Then
							Object.DeletionMark = False;
						EndIf;
						
						Object.Write(WriteMode, PostingMode);
						
					EndIf;					
						
				Except
						
					// Failed to execute actions required for the document.
					WriteDocumentInSafeMode(Object, ObjectType);
						
						
					WP                        = GetProtocolRecordStructure(25,
													ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					WP.OCRName                 = RuleName;
						
					If Not IsBlankString(Source) Then
							
						WP.Source           = Source;
							
					EndIf;
						
					WP.ObjectType             = ObjectType;
					WP.Object                 = String(Object);
					WriteToExecutionProtocol(25, WP);
						
				EndTry;
				
				AddRefToImportedObjectList(GlobalRefSn, RefSN, Object.Ref);
									
				DeleteFromNotWrittenObjectStack(NBSp, Gsn);
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					NeedToWriteObject = Not WriteToInfobaseOnlyChangedObjects;
					
					If PropertyStructure.Periodic3 
						And Not ValueIsFilled(Object.Period) Then
						
						Object.Period = CurrentSessionDate();
						NeedToWriteObject = True;
						
					EndIf;
					
					If WriteRegistersAsRecordSets Then
						
						MustCheckDataForTempSet = 
							(WriteToInfobaseOnlyChangedObjects
								And Not NeedToWriteObject) 
							Or DontReplaceObject;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
						EndIf;
						
						// The register requires the filter to be set.
						For Each FilterElement In RecordSet.Filter Do
							
							FilterElement.Set(Object[FilterElement.Name]);
							If MustCheckDataForTempSet Then
								SetFilterItemValue(TemporaryRecordSet.Filter, FilterElement.Name, Object[FilterElement.Name]);
							EndIf;
							
						EndDo;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() = 0 Then
								NeedToWriteObject = True;
							Else
								
								// Existing set is not be replaced.
								If DontReplaceObject Then
									Return Undefined;
								EndIf;
								
								NeedToWriteObject = False;
								NewTable1 = RecordSet.Unload(); // ValueTable
								TableOld = TemporaryRecordSet.Unload(); 
								
								RowNew = NewTable1[0]; 
								OldRow1 = TableOld[0]; 
								
								For Each TableColumn2 In NewTable1.Columns Do
									
									NeedToWriteObject = RowNew[TableColumn2.Name] <>  OldRow1[TableColumn2.Name];
									If NeedToWriteObject Then
										Break;
									EndIf;
									
								EndDo;
								
							EndIf;
							
						EndIf;
						
						Object = RecordSet;
						
						If PropertyStructure.Periodic3 Then
							// 
							// 
							If DisableDataChangeByDate(Object) Then
								Return Undefined;
							EndIf;
						EndIf;
						
					Else
						
						// Checking whether the current record set must be replaced.
						If DontReplaceObject Or PropertyStructure.Periodic3 Then
							
							// 
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
							// The register requires the filter to be set.
							For Each FilterElement In TemporaryRecordSet.Filter Do
							
								FilterElement.Set(Object[FilterElement.Name]);
																
							EndDo;
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() > 0
								Or DisableDataChangeByDate(TemporaryRecordSet) Then
								Return Undefined;
							EndIf;
							
						Else
							// 
							NeedToWriteObject = True;
						EndIf;
						
					EndIf;
					
				EndIf;
				
				IsReferenceObjectType = Not( ObjectTypeName = "InformationRegister"
					Or ObjectTypeName = "Constants"
					Or ObjectTypeName = "Enum");
					
				If IsReferenceObjectType Then 	
					
					ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, NeedToWriteObject, ImportDataInExchangeMode);
					
					If DeletionMark = Undefined Then
						DeletionMark = False;
					EndIf;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						NeedToWriteObject = True;
					EndIf;
					
				EndIf;
				
				// Writing the object directly.
				If NeedToWriteObject Then
				
					WriteObjectToIB(Object, ObjectType);
					
				EndIf;
				
				If IsReferenceObjectType Then
					
					AddRefToImportedObjectList(GlobalRefSn, RefSN, Object.Ref);
					
				EndIf;
				
				DeleteFromNotWrittenObjectStack(NBSp, Gsn);
								
			EndIf;
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Types" Then

			If Object = Undefined Then
				
				ObjectFound = False;
				Ref       = CreateNewObject(ObjectType, SearchProperties, Object, , , , RefSN, GlobalRefSn, ObjectParameters);
								
			EndIf; 

			ObjectTypesDetails = ImportObjectTypes(ExchangeFile);

			If ObjectTypesDetails <> Undefined Then
				
				Object.ValueType = ObjectTypesDetails;
				
			EndIf; 
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;

EndFunction

// Checks whether the import restriction by date is enabled.
//
// Parameters:
//   DataElement	  - 
//                      
//   
//
// Returns:
//   Boolean - 
//
Function DisableDataChangeByDate(DataElement)
	
	DataChangesDenied = False;
	
	If ModulePeriodClosingDates <> Undefined
		And Not Metadata.Constants.Contains(DataElement.Metadata()) Then
		Try
			If ModulePeriodClosingDates.DataChangesDenied(DataElement) Then
				DataChangesDenied = True;
			EndIf;
		Except
			DataChangesDenied = False;
		EndTry;
	EndIf;
	
	DataElement.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
	Return DataChangesDenied;
	
EndFunction

Function CheckRefExists(Ref, Manager, FoundByUUIDObject,
	SearchByUUIDQueryString)
	
	Try
			
		If IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			// 
			// 
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref;	
		
	Except
			
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

Function EvalExpression(Val Expression)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// 
	Return Eval(Expression);
	
EndFunction

Function HasAttributeOrObjectProperty(Object, AttributeName)
	
	UniqueKey   = New UUID;
	AttributeStructure = New Structure(AttributeName, UniqueKey);
	FillPropertyValues(AttributeStructure, Object);
	
	Return AttributeStructure[AttributeName] <> UniqueKey;
	
EndFunction

// Parameters:
//   Filter - Filter - custom filter.
//   ItemKey - String - a filter item name.
//   ElementValue - Arbitrary - filter item value.
//
Procedure SetFilterItemValue(Filter, ItemKey, ElementValue)
	
	FilterElement = Filter.Find(ItemKey);
	If FilterElement <> Undefined Then
		FilterElement.Set(ElementValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region DataExportProcedures

Function GetDocumentRegisterRecordSet(DocumentReference, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordsSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then	
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	SetFilterItemValue(DocumentRegisterRecordSet.Filter, "Recorder", DocumentReference);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction

Procedure WriteStructureToXML(StructureOfData, PropertyCollectionNode)
	
	PropertyCollectionNode.WriteStartElement("Property");
	
	For Each CollectionItem In StructureOfData Do
		
		If CollectionItem.Key = "Expression"
			Or CollectionItem.Key = "Value"
			Or CollectionItem.Key = "NBSp"
			Or CollectionItem.Key = "Gsn" Then
			
			deWriteElement(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();		
	
EndProcedure

Procedure CreateObjectsForXMLWriter(StructureOfData, PropertyNode1, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		PropertyNode1 = CreateNode(XMLNodeDescription);
		SetAttribute(PropertyNode1, "Name", NodeName);
		
	Else
		
		StructureOfData = New Structure("Name", NodeName);	
		
	EndIf;		
	
EndProcedure

Procedure AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode1, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(PropertyNode1, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode1)
	
	If PropertyNodeStructure <> Undefined Then
		WriteStructureToXML(PropertyNodeStructure, PropertyCollectionNode);
	Else
		AddSubordinateNode(PropertyCollectionNode, PropertyNode1);
	EndIf;
	
EndProcedure

// Generates destination object property nodes according to the specified property conversion rule collection.
//
// Parameters:
//  Source		     - custom data source.
//  Receiver		     - XMLWriter - a destination object XML node.
//  IncomingData	     - custom auxiliary data passed to the rule
//                         for performing the conversion.
//  OutgoingData      - custom auxiliary data passed
//                         to the property object conversion rules.
//  OCR				     - 
//  PGCR                 - 
//  PropertyCollectionNode - XMLWriter - property collection XML node.
// 
Procedure ExportPropertyGroup(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	ObjectCollection1 = Undefined;
	NotReplace        = PGCR.NotReplace;
	NotClear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// BeforeProcessExport handler
	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "BeforeProcessExport"));
				
			Else
				
				Execute(PGCR.BeforeProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(48, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, PGCR, Source, "BeforeProcessPropertyGroupExport",, False);
		
		EndTry;
		
		If Cancel Then // 
			
			Return;
			
		EndIf;
		
	EndIf;

	
    DestinationKind = PGCR.DestinationKind;
	SourceKind = PGCR.SourceKind;
	
	
    // Creating a node of subordinate object collection.
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If DestinationKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, True, PGCR.Receiver, MasterNodeName);
		
		If NotReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "NotReplace", "true");
						
		EndIf;
		
		If NotClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "NotClear", "true");
						
		EndIf;
		
	ElsIf DestinationKind = "SubordinateCatalog" Then
				
		
	ElsIf DestinationKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, True, PGCR.Receiver, MasterNodeName);
		
	ElsIf StrFind(DestinationKind, "RecordsSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, True, PGCR.Receiver, MasterNodeName);
		
		If NotReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "NotReplace", "true");
						
		EndIf;
		
		If NotClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "NotClear", "true");
						
		EndIf;
		
	Else  // This is a simple group.
		
		ExportProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		     PropertyCollectionNode, , , OCR.DontExportPropertyObjectsByRefs Or ExportRefOnly);
			
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
					
				Else
					
					Execute(PGCR.AfterProcessExport);
			
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(49, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PGCR, Source, "AfterProcessPropertyGroupExport",, False);
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	// Getting the collection of subordinate objects.
	
	If ObjectCollection1 <> Undefined Then
		
		// The collection was initialized in the BeforeProcess handler.
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectCollection1 = IncomingData[PGCR.Receiver];
			
			If TypeOf(ObjectCollection1) = Type("QueryResult") Then
				
				ObjectCollection1 = ObjectCollection1.Unload();
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(66, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, PGCR, Source,,,False);
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectCollection1 = Source[PGCR.Source];
		
		If TypeOf(ObjectCollection1) = Type("QueryResult") Then
			
			ObjectCollection1 = ObjectCollection1.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf StrFind(SourceKind, "RecordsSet") > 0 Then
		
		ObjectCollection1 = GetDocumentRegisterRecordSet(Source, SourceKind, PGCR.Source);
				
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectCollection1 = Source[PGCR.Receiver];
		
		If TypeOf(ObjectCollection1) = Type("QueryResult") Then
			
			ObjectCollection1 = ObjectCollection1.Unload();
			
		EndIf;
		
	EndIf;
	
	ExportGroupToFile = ExportGroupToFile Or (ObjectCollection1.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile And (DirectReadingInDestinationIB = False);
	
	If ExportGroupToFile Then
		
		PGCR.XMLNodeRequiredOnExport = False;
		
		If TempFileList = Undefined Then
			TempFileList = New Array;
		EndIf;
		
		RecordsTemporaryFile = WriteTextToTemporaryFile(TempFileList);
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		RecordsTemporaryFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
	For Each CollectionObject In ObjectCollection1 Do
		
		// BeforeExport handler
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "BeforeExport"));
					
				Else
					
					Execute(PGCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(50, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PGCR, Source, "BeforeExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
			If Cancel Then	//	
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// OnExport handler
		
		If PGCR.XMLNodeRequiredOnExport Or ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Record");
		Else
			ObjectCollectionNode.WriteStartElement("Record");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing	= True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "OnExport"));
					
				Else
					
					Execute(PGCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(51, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PGCR, Source, "OnExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
		EndIf;

		//	Exporting the collection object properties.
		
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
		 		ExportProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		 			CollectionObjectNode, CollectionObject, , OCR.DontExportPropertyObjectsByRefs Or ExportRefOnly);
				
			EndIf;
			
		EndIf;
		
		// AfterExport handler
		
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterExport"));
					
				Else
					
					Execute(PGCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(52, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PGCR, Source, "AfterExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
			If Cancel Then	//	
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinateNode(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Filling the file with node objects.
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			RecordsTemporaryFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	
    // AfterProcessExport handler

	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
				
			Else
				
				Execute(PGCR.AfterProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(49, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, PGCR, Source, "AfterProcessPropertyGroupExport",, False);
			
		EndTry;
		
		If Cancel Then //	
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		RecordsTemporaryFile.WriteLine("</" + MasterNodeName + ">"); // 
		RecordsTemporaryFile.Close(); 	// 
	Else
		WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;

EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
			
			ObjectForReceivingData = IncomingData;
			
			If Not IsBlankString(PCR.Receiver) Then
			
				PropertyName = PCR.Receiver;
				
			Else
				
				PropertyName = PCR.ParameterForTransferName;
				
			EndIf;
			
			ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
	
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
						
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 17;
			
		EndIf;
		
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
		
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 14;
			
		EndIf;
		
	EndIf;
	
	Try
		
		Value = ObjectForReceivingData[PropertyName];
		
	Except
		
		If ErrorCode <> 14 Then
			WriteErrorInfoPCRHandlers(ErrorCode, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, PCR, Source, "");
		EndIf;
		
	EndTry;
	
EndProcedure

Procedure ExportItemPropertyType(PropertyNode1, PropertyType1)
	
	SetAttribute(PropertyNode1, "Type", PropertyType1);	
	
EndProcedure

Procedure ExportExtDimension1(Source,
							Receiver,
							IncomingData,
							OutgoingData,
							OCR,
							PCR,
							PropertyCollectionNode ,
							CollectionObject,
							Val ExportRefOnly)
	
	//
	// 
	// 
	Var DestinationType, Empty, Expression, NotReplace, PropertyNode1, PropertiesOCR;
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Initialize the value.
	Value = Undefined;
	OCRName = "";
	OCRNameExtDimensionType = "";
	
	// BeforeExport handler
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PCR, "BeforeExport"));
				
			Else
				
				Execute(PCR.BeforeExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(55, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OCR, PCR, Source, "BeforeExportProperty", Value);
				
		EndTry;
			
		If Cancel Then // 
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
		
		CastValueToLength(Value, PCR);
		
	EndIf;
		
	For Each KeyAndValue In Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimension = KeyAndValue.Value;
		OCRName = "";
		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PCR, Source, "OnExportProperty", Value);
				
			EndTry;
				
			If Cancel Then // 
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimension = Undefined
			Or FindRule(ExtDimension, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
			
		ExtDimensionNode = CreateNode(PCR.Receiver);
		
		// Ключ
		PropertyNode1 = CreateNode("Property");
		
		If IsBlankString(OCRNameExtDimensionType) Then
			
			OCRKey = FindRule(ExtDimensionType, OCRNameExtDimensionType);
			
		Else
			
			OCRKey = FindRule(, OCRNameExtDimensionType);
			
		EndIf;
		
		SetAttribute(PropertyNode1, "Name", "Key");
		ExportItemPropertyType(PropertyNode1, OCRKey.Receiver);
			
		RefNode = ExportByRule(ExtDimensionType,, OutgoingData,, OCRNameExtDimensionType,, ExportRefOnly, OCRKey);
			
		If RefNode <> Undefined Then
			
			IsRuleWithGlobalExport = False;
			RefNodeType = TypeOf(RefNode);
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode1, IsRuleWithGlobalExport);
			
		EndIf;
		
		AddSubordinateNode(ExtDimensionNode, PropertyNode1);
		
		// Значение
		PropertyNode1 = CreateNode("Property");
		
		OCRValue = FindRule(ExtDimension, OCRName);
		
		DestinationType = OCRValue.Receiver;
		
		ThisNULL = False;
		Empty = deEmpty(ExtDimension, ThisNULL);
		
		If Empty Then
			
			If ThisNULL 
				Or ExtDimension = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(DestinationType) Then
				
				DestinationType = GetDataTypeForDestination(ExtDimension);
				
			EndIf;
			
			SetAttribute(PropertyNode1, "Name", "Value");
			
			If Not IsBlankString(DestinationType) Then
				SetAttribute(PropertyNode1, "Type", DestinationType);
			EndIf;
			
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference.
			deWriteElement(PropertyNode1, "Empty");
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode1);
			
		Else
			
			IsRuleWithGlobalExport = False;
			RefNode = ExportByRule(ExtDimension,, OutgoingData, , OCRName, , ExportRefOnly, OCRValue, IsRuleWithGlobalExport);
			
			SetAttribute(PropertyNode1, "Name", "Value");
			ExportItemPropertyType(PropertyNode1, DestinationType);
			
			If RefNode = Undefined Then
				
				Continue;
				
			EndIf;
			
			RefNodeType = TypeOf(RefNode);
			
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode1, IsRuleWithGlobalExport);
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode1);
			
		EndIf;
		
		// AfterExport handler
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
					
			Except
					
				WriteErrorInfoPCRHandlers(57, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PCR, Source, "AfterExportProperty", Value);
					
			EndTry;
			
			If Cancel Then // 
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		AddSubordinateNode(PropertyCollectionNode, ExtDimensionNode);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForExport(RefNode, RefNodeType, PropertyNode1, IsRuleWithGlobalExport)
	
	If RefNodeType = deStringType Then
				
		If StrFind(RefNode, "<Ref") > 0 Then
					
			PropertyNode1.WriteRaw(RefNode);
					
		Else
			
			deWriteElement(PropertyNode1, "Value", RefNode);
					
		EndIf;
				
	ElsIf RefNodeType = deNumberType Then
		
		If IsRuleWithGlobalExport Then
		
			deWriteElement(PropertyNode1, "Gsn", RefNode);
			
		Else     		
			
			deWriteElement(PropertyNode1, "NBSp", RefNode);
			
		EndIf;
				
	Else
				
		AddSubordinateNode(PropertyNode1, RefNode);
				
	EndIf;	
	
EndProcedure

Procedure AddPropertyValueToNode(Value, ValueType, DestinationType, PropertyNode1, PropertySet)
	
	PropertySet = True;
		
	If ValueType = deStringType Then
				
		If DestinationType = "String"  Then
		ElsIf DestinationType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf DestinationType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf DestinationType = "Date"  Then
					
			Value = Date(Value);
					
		ElsIf DestinationType = "ValueStorage"  Then
					
			Value = New ValueStorage(Value);
					
		ElsIf DestinationType = "UUID" Then
					
			Value = New UUID(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "String");
					
		EndIf;
				
		deWriteElement(PropertyNode1, "Value", Value);
				
	ElsIf ValueType = deNumberType Then
				
		If DestinationType = "Number"  Then
		ElsIf DestinationType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf DestinationType = "String"  Then
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "Number");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode1, "Value", Value);
				
	ElsIf ValueType = deDateType Then
				
		If DestinationType = "Date"  Then
		ElsIf DestinationType = "String"  Then
					
			Value = Left(String(Value), 10);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "Date");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode1, "Value", Value);
				
	ElsIf ValueType = deBooleanType Then
				
		If DestinationType = "Boolean"  Then
		ElsIf DestinationType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "Boolean");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode1, "Value", Value);
				
	ElsIf ValueType = deValueStorageType Then
				
		If IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "ValueStorage");
					
		ElsIf DestinationType <> "ValueStorage"  Then
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode1, "Value", Value);
				
	ElsIf ValueType = deUUIDType Then
		
		If DestinationType = "UUID" Then
		ElsIf DestinationType = "String"  Then
					
			Value = String(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode1, "Type", "UUID");
					
		Else
					
			Return;
					
		EndIf;
		
		deWriteElement(PropertyNode1, "Value", Value);
		
	ElsIf ValueType = deAccumulationRecordTypeType Then
				
		deWriteElement(PropertyNode1, "Value", String(Value));		
		
	Else	
		
		PropertySet = False;
		
	EndIf;	
	
EndProcedure

Function ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode1, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	RefNode    = ExportByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, PropertiesOCR, IsRuleWithGlobalExport);
	RefNodeType = TypeOf(RefNode);

	If IsBlankString(DestinationType) Then
				
		DestinationType  = PropertiesOCR.Receiver;
		SetAttribute(PropertyNode1, "Type", DestinationType);
				
	EndIf;
			
	If RefNode = Undefined Then
				
		Return Undefined;
				
	EndIf;
				
	AddPropertiesForExport(RefNode, RefNodeType, PropertyNode1, IsRuleWithGlobalExport);	
	
	Return RefNode;
	
EndFunction

Function GetDataTypeForDestination(Value)
	
	DestinationType = deValueTypeAsString(Value);
	
	// 
	// 
	TableRow = ConversionRulesTable.Find(DestinationType, "Receiver");
	
	If TableRow = Undefined Then
		DestinationType = "";
	EndIf;
	
	Return DestinationType;
	
EndFunction

Procedure CastValueToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
		
EndProcedure

// Generates destination object property nodes according to the specified property conversion rule collection.
//
// Parameters:
//  Source		     - Arbitrary - an arbitrary data source.
//  Receiver		     - XMLWriter - a destination object XML node.
//  IncomingData	     - Arbitrary - arbitrary auxiliary data that is passed to
//                         the conversion rule.
//  OutgoingData      - Arbitrary - arbitrary auxiliary data that is passed to
//                         the property object conversion rules.
//  OCR				     - ValueTableRow - a reference to the object conversion rule.
//  PCRCollection         - See PropertiesConversionRulesCollection
//  PropertyCollectionNode - XMLWriter - property collection XML node.
//  CollectionObject      - Arbitrary - if this parameter is specified, collection object properties are exported, otherwise source object properties are exported.
//  PredefinedItemName1 - String - if this parameter is specified, the predefined item name is written to the properties.
//  PGCR                 - a reference to property group conversion rule (PCR collection parent folder). 
//                         For example a document tabular section.
// 
Procedure ExportProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PCRCollection, PropertyCollectionNode = Undefined, 
	CollectionObject = Undefined, PredefinedItemName1 = Undefined, Val ExportRefOnly = False, 
	TempFileList = Undefined)
	
	Var KeyAndValue, ExtDimensionType, ExtDimension, OCRNameExtDimensionType, ExtDimensionNode; // 
	                                                                             // 
	
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Receiver;
		
	EndIf;
	
	// Exporting the predefined item name if it is specified.
	If PredefinedItemName1 <> Undefined Then
		
		PropertyCollectionNode.WriteStartElement("Property");
		SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName1}");
		If Not ExecuteDataExchangeInOptimizedFormat Then
			SetAttribute(PropertyCollectionNode, "Type", "String");
		EndIf;
		deWriteElement(PropertyCollectionNode, "Value", PredefinedItemName1);
		PropertyCollectionNode.WriteEndElement();		
		
	EndIf;
		
	For Each PCR In PCRCollection Do
		
		If PCR.SimplifiedPropertyExport Then
						
			 //	
			 
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Receiver);
			
			If Not ExecuteDataExchangeInOptimizedFormat
				And Not IsBlankString(PCR.DestinationType) Then
			
				SetAttribute(PropertyCollectionNode, "Type", PCR.DestinationType);
				
			EndIf;
			
			If PCR.NotReplace Then
				
				SetAttribute(PropertyCollectionNode, "NotReplace",	"true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
			
			ThisNULL = False;
			Empty = deEmpty(Value, ThisNULL);
						
			If Empty Then
				
				// Writing the empty value.
				If Not ExecuteDataExchangeInOptimizedFormat Then
					deWriteElement(PropertyCollectionNode, "Empty");
				EndIf;
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteElement(PropertyCollectionNode,	"Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;	
			
		ElsIf PCR.DestinationKind = "AccountExtDimensionTypes" Then
			
			ExportExtDimension1(Source, Receiver, IncomingData, OutgoingData, OCR,
				PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" 
			And PCR.Source = "{UUID}" 
			And PCR.Receiver = "{UUID}" Then
			
			If Source = Undefined Then
				Continue;
			EndIf;
			
			If RefTypeValue(Source) Then
				UUID = Source.UUID();
			Else
				
				InitialValue = New UUID();
				StructureToCheckPropertyAvailability = New Structure("Ref", InitialValue);
				FillPropertyValues(StructureToCheckPropertyAvailability, Source);
				
				If InitialValue <> StructureToCheckPropertyAvailability.Ref
					And RefTypeValue(StructureToCheckPropertyAvailability.Ref) Then
					UUID = Source.Ref.UUID();
				EndIf;
				
			EndIf;
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				SetAttribute(PropertyCollectionNode, "Type", "String");
			EndIf;
			
			deWriteElement(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			ExportPropertyGroup(Source, Receiver, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, ExportRefOnly, TempFileList);
			Continue;
			
		EndIf;

		
		//	
		Value 	 = Undefined;
		OCRName		 = PCR.ConversionRule;
		NotReplace   = PCR.NotReplace;
		
		Empty		 = False;
		Expression	 = Undefined;
		DestinationType = PCR.DestinationType;

		ThisNULL      = False;

		
		// BeforeExport handler
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "BeforeExport"));
					
				Else
					
					Execute(PCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(55, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PCR, Source, "BeforeExportProperty", Value);
				
			EndTry;
			
			If Cancel Then // 
				
				Continue;
				
			EndIf;
			
		EndIf;

        		
        //	Create the property node.
		If IsBlankString(PCR.ParameterForTransferName) Then
			
			PropertyNode1 = CreateNode("Property");
			SetAttribute(PropertyNode1, "Name", PCR.Receiver);
			
		Else
			
			PropertyNode1 = CreateNode("ParameterValue");
			SetAttribute(PropertyNode1, "Name", PCR.ParameterForTransferName);
			
		EndIf;
		
		If NotReplace Then
			
			SetAttribute(PropertyNode1, "NotReplace",	"true");
			
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
			
		EndIf;

        		
		//	Perhaps, the conversion rule is already defined.
		If Not IsBlankString(OCRName) Then
			
			PropertiesOCR = Rules[OCRName];
			
		Else
			
			PropertiesOCR = Undefined;
			
		EndIf;


		//	Attempting to define a destination property type.
		If IsBlankString(DestinationType)	And PropertiesOCR <> Undefined Then
			
			DestinationType = PropertiesOCR.Receiver;
			SetAttribute(PropertyNode1, "Type", DestinationType);
			
		ElsIf Not ExecuteDataExchangeInOptimizedFormat 
			And Not IsBlankString(DestinationType) Then
			
			SetAttribute(PropertyNode1, "Type", DestinationType);
						
		EndIf;
		
		If Not IsBlankString(OCRName)
			And PropertiesOCR <> Undefined
			And PropertiesOCR.HasSearchFieldSequenceHandler = True Then
			
			SetAttribute(PropertyNode1, "OCRName", OCRName);
			
		EndIf;
		
        //	Determine the value to be converted.
		If Expression <> Undefined Then
			
			deWriteElement(PropertyNode1, "Expression", Expression);
			AddSubordinateNode(PropertyCollectionNode, PropertyNode1);
			Continue;
			
		ElsIf Empty Then
			
			If IsBlankString(DestinationType) Then
				
				Continue;
				
			EndIf;
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				deWriteElement(PropertyNode1, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode1);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
						
		EndIf;


		OldValueBeforeOnExportHandler = Value;
		Empty = deEmpty(Value, ThisNULL);

		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PCR, Source, "OnExportProperty", Value);
				
			EndTry;
				
			If Cancel Then // 
				
				Continue;
				
			EndIf;
			
		EndIf;


		//  
		// 
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deEmpty(Value, ThisNULL);
			
		EndIf;

		If Empty Then
			
			If ThisNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(DestinationType) Then
				
				DestinationType = GetDataTypeForDestination(Value);
				
				If Not IsBlankString(DestinationType) Then				
				
					SetAttribute(PropertyNode1, "Type", DestinationType);
				
				EndIf;
				
			EndIf;			
				
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference.
			If Not ExecuteDataExchangeInOptimizedFormat Then
				deWriteElement(PropertyNode1, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode1);
			Continue;
			
		EndIf;

      		
		RefNode = Undefined;
		
		If (PropertiesOCR <> Undefined) 
			Or (Not IsBlankString(OCRName)) Then
			
			RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode1, ExportRefOnly);
			
			If RefNode = Undefined Then
				Continue;				
			EndIf;				
										
		Else
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			AddPropertyValueToNode(Value, ValueType, DestinationType, PropertyNode1, PropertySet);
						
			If Not PropertySet Then
				
				ValueManager = Managers(ValueType);
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				PropertiesOCR = ValueManager.OCR;
				
				If PropertiesOCR = Undefined Then
					Continue;
				EndIf;
				
				OCRName = PropertiesOCR.Name;
				
				RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode1, ExportRefOnly);
			
				If RefNode = Undefined Then
					Continue;				
				EndIf;				
												
			EndIf;
			
		EndIf;


		
		// AfterExport handler

		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(57, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					OCR, PCR, Source, "AfterExportProperty", Value);
				
			EndTry;
				
			If Cancel Then // 
				
				Continue;
				
			EndIf;
			
		EndIf;

		
		AddSubordinateNode(PropertyCollectionNode, PropertyNode1);
		
	EndDo;		//	

EndProcedure

// Exports the selection object according to the specified rule.
//
// Parameters:
//  Object         - 
//  Rule        - 
//  Properties       - 
//  IncomingData - arbitrary auxiliary data.
// 
Procedure ExportSelectionObject(Object, Rule, Properties=Undefined, IncomingData=Undefined, SelectionForDataExport = Undefined)

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			ObjectRul   = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			ObjectRul   = TypeOf(Object);
		EndIf;
		
		MessageString = SubstituteParametersToString(NStr("en = 'Exporting object: %1';"), ObjectRul);
		WriteToExecutionProtocol(MessageString, , False, 1, 7);
		
	EndIf;
	
	OCRName			= Rule.ConversionRule;
	Cancel			= False;
	OutgoingData	= Undefined;
	
	// BeforeExportObject global handler.
	If HasBeforeExportObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeExportObject"));
				
			Else
				
				Execute(Conversion.BeforeExportObject);
				
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (global-level)';");
			WriteErrorInfoDERHandlers(65, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
				Rule.Name,
				SubstituteParametersToString(HandlerName, "BeforeExportSelectionObject"),
				Object);
			
		EndTry;
			
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeExport"));
				
			Else
				
				Execute(Rule.BeforeExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(33, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	RefNode = Undefined;
	
	ExportByRule(Object, , OutgoingData, , OCRName, RefNode, , , , SelectionForDataExport);
	
	// AfterExportObject global handler.
	If HasAfterExportObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterExportObject"));
				
			Else
				
				Execute(Conversion.AfterExportObject);
			
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (global-level)';");
			WriteErrorInfoDERHandlers(69, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, 
				SubstituteParametersToString(HandlerName, "AfterExportSelectionObject"), 
				Object);
			
		EndTry;
		
	EndIf;
	
	// AfterExport handler
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterExport"));
				
			Else
				
				Execute(Rule.AfterExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(34, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
				Rule.Name, "AfterExportSelectionObject", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

// Parameters:
//   ObjectMetadata - MetadataObject
//
Function GetFirstMetadataAttributeName(ObjectMetadata)
	
	AttributesSet = ObjectMetadata.Attributes; // MetadataObjectCollection
	
	If AttributesSet.Count() = 0 Then
		Return "";
	EndIf;
	
	Return AttributesSet.Get(0).Name;
	
EndFunction

Function GetSelectionForExportWithRestrictions(Rule, SelectionForSubstitutionToOCR = Undefined, Properties = Undefined)
	
	NameOfMetadataObjects           = Rule.ObjectForQueryName;
	
	PermissionRow = ?(ExportAllowedObjectsOnly, " ALLOWED ", ""); // @Query-part-1
	
	IsRegisterExport = (Rule.ObjectForQueryName = Undefined);
	
	If IsRegisterExport Then
		
		ResultingRestrictionByDate = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName, Rule.ObjectNameForRegisterQuery, False);
		
		QueryText = 
		"SELECT ALLOWED
		| *
		|
		| ,NULL AS Active
		| ,NULL AS Recorder
		| ,NULL AS LineNumber
		| ,NULL AS Period
		|
		|FROM &MetadataTableName AS ObjectForExport";
		
		If Properties.SubordinateToRecorder Then
			
			QueryText = StrReplace(QueryText, ",NULL AS Active", "");
			QueryText = StrReplace(QueryText, ",NULL AS Recorder", "");
			QueryText = StrReplace(QueryText, ",NULL AS LineNumber", "");
			
		EndIf;
		
		If Properties.Periodic3 Then
			
			QueryText = StrReplace(QueryText, ",NULL AS Period", "");
			
		EndIf;
		
		If IsBlankString(PermissionRow) Then
			
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "SELECT");
			
		EndIf;
				
		QueryText = StrReplace(QueryText, "&MetadataTableName", Rule.ObjectNameForRegisterQuery);
		QueryText = QueryText + Chars.LF + ResultingRestrictionByDate;
		
		ReportBuilder.Text = QueryText;
		ReportBuilder.FillSettings();
		
	Else
		
		ResultingRestrictionByDate = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName,, False);
		
		QueryText = 
		"SELECT ALLOWED
		| *
		|
		| FROM &MetadataTableName AS ObjectForExport";
		
		If IsBlankString(PermissionRow) Then
			
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "SELECT");
			
		EndIf;
		
		If Rule.SelectExportDataInSingleQuery <> True Then
			
			QueryText = StrReplace(QueryText, "*", "ObjectForExport.Ref AS Ref");
			
		EndIf;
		
		QueryText = StrReplace(QueryText, "&MetadataTableName", NameOfMetadataObjects);
		QueryText = QueryText + Chars.LF + ResultingRestrictionByDate;
		
		AliasOfTheReportBuilder = StrReplace(NameOfMetadataObjects, ".", "_");
		LinkerConditionString = "{WHERE Ref.* AS AliasOfTheReportBuilder}";
		LinkerConditionString = StrReplace(LinkerConditionString, "AliasOfTheReportBuilder", AliasOfTheReportBuilder);
		QueryText = QueryText + Chars.LF + LinkerConditionString;
		
		ReportBuilder.Text = QueryText;
		
	EndIf;
	
	ReportBuilder.Filter.Reset();
	If Rule.BuilderSettings <> Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;
	
	ReportBuilder.Parameters.Insert("StartDate", StartDate);
	ReportBuilder.Parameters.Insert("EndDate", EndDate);

	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Select();
	
	If Rule.SelectExportDataInSingleQuery Then
		SelectionForSubstitutionToOCR = Selection;
	EndIf;
		
	Return Selection;
		
EndFunction

Function GetExportWithArbitraryAlgorithmSelection(DataSelection)
	
	Selection = Undefined;
	
	If TypeOf(DataSelection) = Type("QueryResultSelection") Then
		
		Selection = DataSelection;
		
	ElsIf TypeOf(DataSelection) = Type("QueryResult") Then
		
		Selection = DataSelection.Select();
		
	ElsIf TypeOf(DataSelection) = Type("Query") Then
		
		QueryResult = DataSelection.Execute();
		Selection          = QueryResult.Select();
		
	EndIf;
		
	Return Selection;	
	
EndFunction

Function GetConstantSetRowForExport(ConstantDataTableForExport)
	
	ConstantSetString = "";
	
	For Each TableRow In ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
		
			ConstantSetString = ConstantSetString + ", " + TableRow.Source;
			
		EndIf;
		
	EndDo;	
	
	If Not IsBlankString(ConstantSetString) Then
		
		ConstantSetString = Mid(ConstantSetString, 3);
		
	EndIf;
	
	Return ConstantSetString;
	
EndFunction

Procedure ExportConstantsSet(Rule, Properties, OutgoingData)
	
	If Properties.OCR <> Undefined Then
	
		ConstantSetNameString = GetConstantSetRowForExport(Properties.OCR.Properties);
		
	Else
		
		ConstantSetNameString = "";
		
	EndIf;
			
	ConstantsSet = Constants.CreateSet(ConstantSetNameString);
	ConstantsSet.Read();
	ExportSelectionObject(ConstantsSet, Rule, Properties, OutgoingData);	
	
EndProcedure

Function MustSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = Not IsBlankString(Conversion.BeforeExportObject)
		Or Not IsBlankString(Rule.BeforeExport)
		Or Not IsBlankString(Conversion.AfterExportObject)
		Or Not IsBlankString(Rule.AfterExport);		
		
	Return AllFieldsRequiredForSelection;	
	
EndFunction

// Exports data according to the specified rule.
//
// Parameters:
//  Rule        - 
// 
Procedure ExportDataByRule(Rule)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		MessageString = SubstituteParametersToString(NStr("en = 'Data export rule: %1 (%2)';"), TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteToExecutionProtocol(MessageString, , False, , 4);
		
	EndIf;
	
	// BeforeProcess handle
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	If Not IsBlankString(Rule.BeforeProcess) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(31, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection with filter.
	If Rule.DataFilterMethod = "StandardSelection" And Rule.UseFilter1 Then
		
		Properties	= Managers[Rule.SelectionObject1];
		TypeName		= Properties.TypeName;
		
		SelectionForOCR = Undefined;
		Selection = GetSelectionForExportWithRestrictions(Rule, SelectionForOCR, Properties);
		
		IsNotReferenceType = TypeName =  "InformationRegister" Or TypeName = "AccountingRegister";
		
		While Selection.Next() Do
			
			If IsNotReferenceType Then
				ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
			Else					
				ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
			EndIf;
			
		EndDo;
		
	// Standard selection without filter.
	ElsIf (Rule.DataFilterMethod = "StandardSelection") Then
		
		Properties	= Managers(Rule.SelectionObject1);
		TypeName		= Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			ExportConstantsSet(Rule, Properties, OutgoingData);
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
				Or TypeName = "AccountingRegister";
			
			If IsNotReferenceType Then
					
				SelectAllFields = MustSelectAllFields(Rule);
				
			Else
				
				// 
				SelectAllFields = Rule.SelectExportDataInSingleQuery;	
				
			EndIf;
			
			Selection = GetSelectionForDataClearingExport(Properties, TypeName, , , SelectAllFields);
			SelectionForOCR = ?(Rule.SelectExportDataInSingleQuery, Selection, Undefined);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataFilterMethod = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					ExportSelectionObject(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For Each Object In DataSelection Do
					
					ExportSelectionObject(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
			
	EndIf;

	
	// AfterProcess handler

	If Not IsBlankString(Rule.AfterProcess) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(32, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	 EndIf;	
	
EndProcedure

// Iterates the tree of data export rules and executes export.
//
// Parameters:
//  Rows         - 
// 
Procedure ProcessExportRules(Rows, ExchangePlanNodesAndExportRowsMap)
	
	For Each ExportRule In Rows Do
		
		If ExportRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 
		
		If (ExportRule.ExchangeNodeRef <> Undefined 
				And Not ExportRule.ExchangeNodeRef.IsEmpty()) Then
			
			ExportRulesArray = ExchangePlanNodesAndExportRowsMap.Get(ExportRule.ExchangeNodeRef);
			
			If ExportRulesArray = Undefined Then
				
				ExportRulesArray = New Array();	
				
			EndIf;
			
			ExportRulesArray.Add(ExportRule);
			
			ExchangePlanNodesAndExportRowsMap.Insert(ExportRule.ExchangeNodeRef, ExportRulesArray);
			
			Continue;
			
		EndIf;

		If ExportRule.IsFolder Then
			
			ProcessExportRules(ExportRule.Rows, ExchangePlanNodesAndExportRowsMap);
			Continue;
			
		EndIf;
		
		ExportDataByRule(ExportRule);
		
	EndDo; 
	
EndProcedure

Function CopyExportRulesArray(SourceArray)
	
	ResultingArray1 = New Array();
	
	For Each Item In SourceArray Do
		
		ResultingArray1.Add(Item);	
		
	EndDo;
	
	Return ResultingArray1;
	
EndFunction

// Returns:
//   ValueTreeRow - 
//     * Name - String
//     * Description - String
//
Function FindExportRulesTreeRowByExportType(RowsArray, ExportType)
	
	For Each ArrayRow In RowsArray Do
		
		If ArrayRow.SelectionObject1 = ExportType Then
			
			Return ArrayRow;
			
		EndIf;
			
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure DeleteExportRulesTreeRowByExportTypeFromArray(RowsArray, ItemToDelete)
	
	Counter = RowsArray.Count() - 1;
	While Counter >= 0 Do
		
		ArrayRow = RowsArray[Counter];
		
		If ArrayRow = ItemToDelete Then
			
			RowsArray.Delete(Counter);
			Return;
			
		EndIf; 
		
		Counter = Counter - 1;	
		
	EndDo;
	
EndProcedure

// Parameters:
//   Data - AnyRef - a catalog and document reference, an information register key, and so on.
//
Procedure GetExportRulesRowByExchangeObject(Data, LastObjectMetadata, ExportObjectMetadata, 
	LastExportRulesRow, CurrentExportRuleRow, TempConversionRulesArray, ObjectForExportRules, 
	ExportingRegister, ExportingConstants, ConstantsWereExported)
	
	CurrentExportRuleRow = Undefined;
	ObjectForExportRules = Undefined;
	ExportingRegister = False;
	ExportingConstants = False;
	
	If LastObjectMetadata = ExportObjectMetadata
		And LastExportRulesRow = Undefined Then
		
		Return;
		
	EndIf;
	
	StructureOfData = ManagersForExchangePlans[ExportObjectMetadata];
	
	If StructureOfData = Undefined Then
		
		ExportingConstants = Metadata.Constants.Contains(ExportObjectMetadata);
		
		If ConstantsWereExported 
			Or Not ExportingConstants Then
			
			Return;
			
		EndIf;
		
		// Searching for the rule for constants.
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRulesTreeRowByExportType(TempConversionRulesArray, Type("ConstantsSet"));
			
		Else
			
			CurrentExportRuleRow = LastExportRulesRow;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	If StructureOfData.IsReferenceType = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRulesTreeRowByExportType(TempConversionRulesArray, StructureOfData.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRulesRow;
			
		EndIf;
		
		ObjectForExportRules = Data.Ref;
		
	ElsIf StructureOfData.IsRegister = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRulesTreeRowByExportType(TempConversionRulesArray, StructureOfData.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRulesRow;	
			
		EndIf;
		
		ObjectForExportRules = Data;
		
		ExportingRegister = True;
		
	EndIf;
	
EndProcedure

Function ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRulesArray, StructureForChangeRegistrationDeletion)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	StructureForChangeRegistrationDeletion.Insert("OCRArray", Undefined);
	StructureForChangeRegistrationDeletion.Insert("MessageNo", Undefined);
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	
	// Create a new message.
	WriteMessage1 = ExchangePlans.CreateMessageWriter();
		
	WriteMessage1.BeginWrite(XMLWriter, ExchangeNode);
	
	// Counting the number of written objects.
	FoundObjectToWriteCount = 0;
	
	LastMetadataObject = Undefined;
	LastExportRuleRow = Undefined; // See FindExportRulesTreeRowByExportType
	
	CurrentMetadataObject1 = Undefined;
	CurrentExportRuleRow = Undefined; // See FindExportRulesTreeRowByExportType
	
	OutgoingData = Undefined;
	
	TempConversionRulesArray = CopyExportRulesArray(ConversionRulesArray);
	
	Cancel           = False;
	OutgoingData = Undefined;
	DataSelection   = Undefined;
	
	ObjectForExportRules = Undefined;
	ConstantsWereExported = False;
	// Start a transaction.
	If UseTransactionsOnExportForExchangePlans Then
		BeginTransaction();
	EndIf;
	
	Try
	
		// Getting changed data selection.
		MetadataToExportArray = New Array();
		
		// Complement the array with only this metadata for which there are rules for export. Other metadata does not matter.
		For Each ExportRuleRow In TempConversionRulesArray Do
			
			DERMetadata = Metadata.FindByType(ExportRuleRow.SelectionObject1);
			MetadataToExportArray.Add(DERMetadata);
			
		EndDo;
		
		ChangesSelection = ExchangePlans.SelectChanges(WriteMessage1.Recipient, WriteMessage1.MessageNo, MetadataToExportArray);
		
		StructureForChangeRegistrationDeletion.MessageNo = WriteMessage1.MessageNo;
		
		While ChangesSelection.Next() Do
					
			Data = ChangesSelection.Get();
			FoundObjectToWriteCount = FoundObjectToWriteCount + 1;
			
			ExportDataType = TypeOf(Data); 
			
			Delete = (ExportDataType = deObjectDeletionType);
			
			// Skip deletion.
			If Delete Then
				Continue;
			EndIf;
			
			CurrentMetadataObject1 = Data.Metadata();
			
			// 
			// 
			
			ExportingRegister = False;
			ExportingConstants = False;
			
			GetExportRulesRowByExchangeObject(Data, LastMetadataObject, CurrentMetadataObject1,
				LastExportRuleRow, CurrentExportRuleRow, TempConversionRulesArray, ObjectForExportRules,
				ExportingRegister, ExportingConstants, ConstantsWereExported);
				
			If LastMetadataObject <> CurrentMetadataObject1 Then
				
				// After processing.
				If LastExportRuleRow <> Undefined Then
			
					If Not IsBlankString(LastExportRuleRow.AfterProcess) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcess"));
								
							Else
								
								Execute(LastExportRuleRow.AfterProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(32, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
								LastExportRuleRow.Name, "AfterProcessDataExport");
							
						EndTry;
						
					EndIf;
					
				EndIf;
				
				// Before processing.
				If CurrentExportRuleRow <> Undefined Then
					
					If CommentObjectProcessingFlag Then
						
						MessageString = SubstituteParametersToString(NStr("en = 'Data export rule: %1 (%2)';"),
							TrimAll(CurrentExportRuleRow.Name), TrimAll(CurrentExportRuleRow.Description));
						WriteToExecutionProtocol(MessageString, , False, , 4);
						
					EndIf;
					
					// 
					Cancel			= False;
					OutgoingData	= Undefined;
					DataSelection	= Undefined;
					
					If Not IsBlankString(CurrentExportRuleRow.BeforeProcess) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(CurrentExportRuleRow, "BeforeProcess"));
								
							Else
								
								Execute(CurrentExportRuleRow.BeforeProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(31, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
								CurrentExportRuleRow.Name, "BeforeProcessDataExport");
							
						EndTry;
						
					EndIf;
					
					If Cancel Then
						
						// 
						CurrentExportRuleRow = Undefined;
						DeleteExportRulesTreeRowByExportTypeFromArray(TempConversionRulesArray, CurrentExportRuleRow);
						ObjectForExportRules = Undefined;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// There is a rule to export data.
			If CurrentExportRuleRow <> Undefined Then
				
				If ExportingRegister Then
					
					For Each RegisterLine In ObjectForExportRules Do
						ExportSelectionObject(RegisterLine, CurrentExportRuleRow, , OutgoingData);
					EndDo;
					
				ElsIf ExportingConstants Then
					
					Properties	= Managers[CurrentExportRuleRow.SelectionObject1];
					ExportConstantsSet(CurrentExportRuleRow, Properties, OutgoingData);
					
				Else
				
					ExportSelectionObject(ObjectForExportRules, CurrentExportRuleRow, , OutgoingData);
				
				EndIf;
				
			EndIf;
			
			LastMetadataObject = CurrentMetadataObject1;
			LastExportRuleRow = CurrentExportRuleRow; 
			
			If ProcessedObjectsCountToUpdateStatus > 0 
				And FoundObjectToWriteCount % ProcessedObjectsCountToUpdateStatus = 0 Then
				
				Try
					NameOfMetadataObjects = CurrentMetadataObject1.FullName();
				Except
					NameOfMetadataObjects = "";
				EndTry;
				
			EndIf;
			
			If UseTransactionsOnExportForExchangePlans 
				And (TransactionItemsCountOnExportForExchangePlans > 0)
				And (FoundObjectToWriteCount = TransactionItemsCountOnExportForExchangePlans) Then
				
				// Completing the subtransaction and beginning a new one.
				CommitTransaction();
				BeginTransaction();
				
				FoundObjectToWriteCount = 0;
			EndIf;
			
		EndDo;
		
		// 
		WriteMessage1.EndWrite();
		
		XMLWriter.Close();
		
		If UseTransactionsOnExportForExchangePlans Then
			CommitTransaction();
		EndIf;
		
	Except
		
		If UseTransactionsOnExportForExchangePlans Then
			RollbackTransaction();
		EndIf;
		
		WP = GetProtocolRecordStructure(72, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WP.ExchangePlanNode  = ExchangeNode;
		WP.Object = Data;
		WP.ObjectType = ExportDataType;
		
		WriteToExecutionProtocol(72, WP, True);
						
		XMLWriter.Close();
		
		Return False;
		
	EndTry;
	
	// Event following processing.
	If LastExportRuleRow <> Undefined Then
	
		If Not IsBlankString(LastExportRuleRow.AfterProcess) Then
		
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcess"));
					
				Else
					
					Execute(LastExportRuleRow.AfterProcess);
					
				EndIf;
				
			Except
				WriteErrorInfoDERHandlers(32, ErrorProcessing.DetailErrorDescription(ErrorInfo()),
					LastExportRuleRow.Name, "AfterProcessDataExport");
				
			EndTry;
			
		EndIf;
		
	EndIf;
	
	StructureForChangeRegistrationDeletion.OCRArray = TempConversionRulesArray;
	
	Return Not Cancel;
	
EndFunction

Function ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRegistrationDeletion)
	
	ExportSuccessful = True;
	
	For Each MapRow In NodeAndExportRuleMap Do
		
		ExchangeNode = MapRow.Key;
		ConversionRulesArray = MapRow.Value;
		
		LocalStructureForChangeRegistrationDeletion = New Structure();
		
		CurrentExportSuccessful = ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRulesArray, LocalStructureForChangeRegistrationDeletion);
		
		ExportSuccessful = ExportSuccessful And CurrentExportSuccessful;
		
		If LocalStructureForChangeRegistrationDeletion.OCRArray <> Undefined
			And LocalStructureForChangeRegistrationDeletion.OCRArray.Count() > 0 Then
			
			StructureForChangeRegistrationDeletion.Insert(ExchangeNode, LocalStructureForChangeRegistrationDeletion);	
			
		EndIf;
		
	EndDo;
	
	Return ExportSuccessful;
	
EndFunction

Procedure ProcessExchangeNodeRecordChangeEditing(NodeAndExportRuleMap)
	
	For Each Item In NodeAndExportRuleMap Do
	
		If ChangesRegistrationDeletionTypeForExportedExchangeNodes = 0 Then
			
			Return;
			
		ElsIf ChangesRegistrationDeletionTypeForExportedExchangeNodes = 1 Then
			
			// 
			ExchangePlans.DeleteChangeRecords(Item.Key, Item.Value.MessageNo);
			
		ElsIf ChangesRegistrationDeletionTypeForExportedExchangeNodes = 2 Then	
			
			// Deleting changes of metadata of the first level exported objects.
			
			For Each ExportedOCR In Item.Value.OCRArray Do
				
				Rule = Rules[ExportedOCR.ConversionRule]; // See FindRule
				
				If ValueIsFilled(Rule.Source) Then
					
					Manager = Managers[Rule.Source];
					
					ExchangePlans.DeleteChangeRecords(Item.Key, Manager.MetadataObjectsList);
					
				EndIf;
				
			EndDo;
			
		EndIf;
	
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsToExport

// Opens an exchange file and reads attributes of file master node according to the exchange format.
//
// Parameters:
//  ReadHeaderOnly - Boolean - If True, then file closes after reading the exchange file header
//  (master node).
//
Procedure OpenImportFile(ReadHeaderOnly=False, ExchangeFileData = "") Export

	If IsBlankString(ExchangeFileName) And ReadHeaderOnly Then
		StartDate         = "";
		EndDate      = "";
		DataExportDate = "";
		ExchangeRulesVersion = "";
		Comment        = "";
		Return;
	EndIf;


    DataImportFileName = ExchangeFileName;
	
	
	// Archive files are recognized by the ZIP extension.
	If StrFind(ExchangeFileName, ".zip") > 0 Then
		
		DataImportFileName = UnpackZipFile(ExchangeFileName);		 
		
	EndIf; 
	
	
	FlagErrors = False;
	ExchangeFile = New XMLReader();

	Try
		If Not IsBlankString(ExchangeFileData) Then
			ExchangeFile.SetString(ExchangeFileData);
		Else
			ExchangeFile.OpenFile(DataImportFileName);
		EndIf;
	Except
		WriteToExecutionProtocol(5);
		Return;
	EndTry;
	
	ExchangeFile.Read();


	mExchangeFileAttributes = New Structure;
	
	
	If ExchangeFile.LocalName = "ExchangeFile" Then
		
		mExchangeFileAttributes.Insert("FormatVersion",            deAttribute(ExchangeFile, deStringType, "FormatVersion"));
		mExchangeFileAttributes.Insert("ExportDate",             deAttribute(ExchangeFile, deDateType,   "ExportDate"));
		mExchangeFileAttributes.Insert("ExportPeriodStart",    deAttribute(ExchangeFile, deDateType,   "ExportPeriodStart"));
		mExchangeFileAttributes.Insert("ExportPeriodEnd", deAttribute(ExchangeFile, deDateType,   "ExportPeriodEnd"));
		mExchangeFileAttributes.Insert("SourceConfigurationName", deAttribute(ExchangeFile, deStringType, "SourceConfigurationName"));
		mExchangeFileAttributes.Insert("DestinationConfigurationName", deAttribute(ExchangeFile, deStringType, "DestinationConfigurationName"));
		mExchangeFileAttributes.Insert("ConversionRulesID",      deAttribute(ExchangeFile, deStringType, "ConversionRulesID"));
		
		StartDate         = mExchangeFileAttributes.ExportPeriodStart;
		EndDate      = mExchangeFileAttributes.ExportPeriodEnd;
		DataExportDate = mExchangeFileAttributes.ExportDate;
		Comment        = deAttribute(ExchangeFile, deStringType, "Comment");
		
	Else
		
		WriteToExecutionProtocol(9);
		Return;
		
	EndIf;


	ExchangeFile.Read();
			
	NodeName = ExchangeFile.LocalName;
		
	If NodeName = "ExchangeRules" Then
		If SafeImport And ValueIsFilled(ExchangeRulesFileName) Then
			ImportExchangeRules(ExchangeRulesFileName, "XMLFile");
			ExchangeFile.Skip();
		Else
			ImportExchangeRules(ExchangeFile, "XMLReader");
		EndIf;				
	Else
		ExchangeFile.Close();
		ExchangeFile = New XMLReader();
		Try
			
			If Not IsBlankString(ExchangeFileData) Then
				ExchangeFile.SetString(ExchangeFileData);
			Else
				ExchangeFile.OpenFile(DataImportFileName);
			EndIf;
			
		Except
			
			WriteToExecutionProtocol(5);
			Return;
			
		EndTry;
		
		ExchangeFile.Read();
		
	EndIf; 
	
	mExchangeRulesReadOnImport = True;

	If ReadHeaderOnly Then
		
		ExchangeFile.Close();
		Return;
		
	EndIf;
   
EndProcedure

Procedure RefreshAllExportRuleParentMarks(ExportRuleTreeRows, MustSetMarks = True)
	
	If ExportRuleTreeRows.Rows.Count() = 0 Then
		
		If MustSetMarks Then
			SetParentMarks(ExportRuleTreeRows, "Enable");	
		EndIf;
		
	Else
		
		MarksRequired = True;
		
		For Each RuleTreeRow In ExportRuleTreeRows.Rows Do
			
			RefreshAllExportRuleParentMarks(RuleTreeRow, MarksRequired);
			If MarksRequired = True Then
				MarksRequired = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillPropertiesForSearch(StructureOfData, PCR)
	
	For Each FieldsString In PCR Do
		
		If FieldsString.IsFolder Then
						
			If FieldsString.DestinationKind = "TabularSection" 
				Or StrFind(FieldsString.DestinationKind, "RecordsSet") > 0 Then
				
				DestinationStructureName = FieldsString.Receiver + ?(FieldsString.DestinationKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = StructureOfData[DestinationStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				StructureOfData[DestinationStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = StructureOfData;	
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldsString.GroupRules);
									
		Else
			
			If IsBlankString(FieldsString.DestinationType)	Then
				
				Continue;
				
			EndIf;
			
			StructureOfData[FieldsString.Receiver] = FieldsString.DestinationType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteExcessiveItemsFromMap(StructureOfData)
	
	For Each Item In StructureOfData Do
		
		If TypeOf(Item.Value) = deMapType Then
			
			DeleteExcessiveItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				StructureOfData.Delete(Item.Key);
			EndIf;
			
		EndIf;		
		
	EndDo;		
	
EndProcedure

Procedure FillInformationByDestinationDataTypes(StructureOfData, Rules)
	
	For Each String In Rules Do
		
		If IsBlankString(String.Receiver) Then
			Continue;
		EndIf;
		
		DataFromStructure = StructureOfData[String.Receiver];
		If DataFromStructure = Undefined Then
			
			DataFromStructure = New Map();
			StructureOfData[String.Receiver] = DataFromStructure;
			
		EndIf;
		
		// Passing through search fields and PCR and writing data types.
		FillPropertiesForSearch(DataFromStructure, String.SearchProperties);
				
		// Properties
		FillPropertiesForSearch(DataFromStructure, String.Properties);
		
	EndDo;
	
	DeleteExcessiveItemsFromMap(StructureOfData);	
	
EndProcedure

Procedure CreateStringWithPropertyTypes(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = deMapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item In PropertyTypes.Value Do
			CreateStringWithPropertyTypes(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	Else		
		
		deWriteElement(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateTypesStringForDestination(StructureOfData)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInformation");	
	
	For Each String In StructureOfData Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", String.Key);
		
		For Each SubordinationRow In String.Value Do
			
			CreateStringWithPropertyTypes(XMLWriter, SubordinationRow);	
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo;	
	
	XMLWriter.WriteEndElement();
	
	ResultString1 = XMLWriter.Close();
	Return ResultString1;
	
EndFunction

Procedure ImportSingleTypeData(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName;
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = deXMLNodeTypeStartElement Then
			
		// This is a new item.
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf;	
	
	ImportTypeMapForSingleType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypeMapForSingleType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
			
		    Break;
			
		EndIf;
		
		// 
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = deXMLNodeTypeStartElement Then
			
			// This is a new item.
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf;	
		
	EndDo;	
	
EndProcedure

Procedure ImportDataTypeInformation()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, deStringType, "Name");
			
			TypeMap = New Map;
			mDataTypeMapForImport.Insert(Type(TypeName), TypeMap);

			ImportTypeMapForSingleType(ExchangeFile, TypeMap);	
			
		ElsIf (NodeName = "DataTypeInformation") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ImportDataExchangeParameterValues()
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Name = deAttribute(ExchangeFile, deStringType, "Name");
		
	PropertyType1 = GetPropertyTypeByAdditionalData(Undefined, Name);
	
	Value = ReadProperty(PropertyType1);
	
	Parameters.Insert(Name, Value);	
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParametersImport.Property(Name, AfterParameterImportAlgorithm)
		And Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		If HandlersDebugModeFlag Then
			
			Raise NStr("en = 'Event handler AfterParameterImport doesn''t support debugging.';");
			
		Else
			
			Execute(AfterParameterImportAlgorithm);
			
		EndIf;
		
	EndIf;
		
EndProcedure

Function GetHandlerValueFromText(ExchangeRules)
	
	HandlerText = deElementValue(ExchangeRules, deStringType);
	
	If StrFind(HandlerText, Chars.LF) = 0 Then
		Return HandlerText;
	EndIf;
	
	HandlerText = StrReplace(HandlerText, Char(10), Chars.LF);
	
	Return HandlerText;
	
EndFunction

// Imports exchange rules according to the format.
//
// Parameters:
//  Source        - String - an object where the exchange rules are imported from;
//  SourceType    - String - specifying a source type: "XMLFile", "ReadingXML", "String".
// 
Procedure ImportExchangeRules(Source="", SourceType="XMLFile") Export
	
	InitManagersAndMessages();
	
	HasBeforeExportObjectGlobalHandler    = False;
	HasAfterExportObjectGlobalHandler     = False;
	
	HasBeforeConvertObjectGlobalHandler = False;

	HasBeforeImportObjectGlobalHandler    = False;
	HasAfterObjectImportGlobalHandler     = False;
	
	CreateConversionStructure();
	
	mPropertyConversionRuleTable = New ValueTable;
	InitPropertyConversionRuleTable(mPropertyConversionRuleTable);
	SupplementInternalTablesWithColumns();
	
	// Perhaps, embedded exchange rules are selected (one of templates.
	
	ExchangeRulesTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRulesFileName;
		If mExchangeRuleTemplateList.FindByValue(Source) <> Undefined Then
			For Each Template In Metadata().Templates Do
				If Template.Synonym = Source Then
					Source = Template.Name;
					Break;
				EndIf; 
			EndDo; 
			ExchangeRuleTemplate              = GetTemplate(Source);
			ExchangeRulesTempFileName = GetTempFileName("xml");
			ExchangeRuleTemplate.Write(ExchangeRulesTempFileName);
			Source = ExchangeRulesTempFileName;
		EndIf;
		
	EndIf;

	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			WriteToExecutionProtocol(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exists() Then
			WriteToExecutionProtocol(3);
			Return; 
		EndIf;
		
		RuleFilePacked = (File.Extension = ".zip");
		
		If RuleFilePacked Then
			
			// 
			Source = UnpackZipFile(Source);
			
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf; 
	

	If Not ((ExchangeRules.LocalName = "ExchangeRules") And (ExchangeRules.NodeType = deXMLNodeTypeStartElement)) Then
		WriteToExecutionProtocol(6);
		Return;
	EndIf;


	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.Indent = True;
	XMLWriter.WriteStartElement("ExchangeRules");
	

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes.
		If NodeName = "FormatVersion" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("FormatVersion", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "ID_SSLy" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("ID_SSLy",                   Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Description",         Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deElementValue(ExchangeRules, deDateType);
			Conversion.Insert("CreationDateTime",    Value);
			deWriteElement(XMLWriter, NodeName, Value);
			ExchangeRulesVersion = Conversion.CreationDateTime;
		ElsIf NodeName = "Source" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Source",             Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Receiver" Then
			
			DestinationPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			DestinationPlatform = GetPlatformByDestinationPlatformVersion(DestinationPlatformVersion);
			
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Receiver",             Value);
			deWriteElement(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "DeleteMappedObjectsFromDestinationOnDeleteFromSource" Then
			deSkip(ExchangeRules);
		
		ElsIf NodeName = "Comment" Then
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deSkip(ExchangeRules);

		ElsIf NodeName = "Parameters" Then
			DoImportParameters(ExchangeRules, XMLWriter)

		// Conversion events.
		
		ElsIf NodeName = "" Then
			
		ElsIf NodeName = "AfterImportExchangeRules" Then
			If ExchangeMode = "Load" Then
				ExchangeRules.Skip();
			Else
				Conversion.Insert("AfterImportExchangeRules", GetHandlerValueFromText(ExchangeRules));
			EndIf;
		ElsIf NodeName = "BeforeExportData" Then
			Conversion.Insert("BeforeExportData", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "AfterExportData" Then
			Conversion.Insert("AfterExportData",  GetHandlerValueFromText(ExchangeRules));

		ElsIf NodeName = "BeforeExportObject" Then
			Conversion.Insert("BeforeExportObject", GetHandlerValueFromText(ExchangeRules));
			HasBeforeExportObjectGlobalHandler = Not IsBlankString(Conversion.BeforeExportObject);

		ElsIf NodeName = "AfterExportObject" Then
			Conversion.Insert("AfterExportObject", GetHandlerValueFromText(ExchangeRules));
			HasAfterExportObjectGlobalHandler = Not IsBlankString(Conversion.AfterExportObject);

		ElsIf NodeName = "BeforeImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("BeforeImportObject", Value);
				HasBeforeImportObjectGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("AfterImportObject", Value);
				HasAfterObjectImportGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "BeforeConvertObject" Then
			Conversion.Insert("BeforeConvertObject", GetHandlerValueFromText(ExchangeRules));
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeConvertObject);
			
		ElsIf NodeName = "BeforeImportData" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.BeforeImportData = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportData" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.AfterImportData = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportParameters" Then
			Conversion.Insert("AfterImportParameters", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("OnGetDeletionInfo", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterGetExchangeNodesInformation" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("AfterGetExchangeNodesInformation", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;

		// Rules.
		
		ElsIf NodeName = "DataExportRules" Then
		
 			If ExchangeMode = "Load" Then
				deSkip(ExchangeRules);
			Else
				ImportExportRules(ExchangeRules);
 			EndIf; 
			
		ElsIf NodeName = "ObjectsConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearingRules(ExchangeRules, XMLWriter)
			
		ElsIf NodeName = "ObjectsRegistrationRules" Then
			deSkip(ExchangeRules); // Object registration rules are imported with another data processor.
			
		// Algorithms, Queries, DataProcessors.
		
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);

		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
		// Exit.
		ElsIf (NodeName = "ExchangeRules") And (ExchangeRules.NodeType = deXMLNodeTypeEndElement) Then
		
			If ExchangeMode <> "Load" Then
				ExchangeRules.Close();
			EndIf;
			Break;

			
		// Invalid format.
		Else
		    RecordStructure = New Structure("NodeName", NodeName);
			WriteToExecutionProtocol(7, RecordStructure);
			Return;
		EndIf;
	EndDo;


	XMLWriter.WriteEndElement();
	mXMLRules = XMLWriter.Close();
	
	For Each ExportRulesString In ExportRulesTable.Rows Do
		RefreshAllExportRuleParentMarks(ExportRulesString, True);
	EndDo;
	
	// Deleting the temporary rule file.
	If Not IsBlankString(ExchangeRulesTempFileName) Then
		Try
 			DeleteFiles(ExchangeRulesTempFileName);
		Except 
			WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndIf;
	
	If SourceType="XMLFile"
		And RuleFilePacked Then
		
		Try
			DeleteFiles(Source);
		Except 
			WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	// Information on destination data types is required for quick data import.
	StructureOfData = New Map();
	FillInformationByDestinationDataTypes(StructureOfData, ConversionRulesTable);
	
	mTypesForDestinationRow = CreateTypesStringForDestination(StructureOfData);
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Event call is required after importing the exchange rules.
	AfterExchangeRulesImportEventText = "";
	If Conversion.Property("AfterImportExchangeRules", AfterExchangeRulesImportEventText)
		And Not IsBlankString(AfterExchangeRulesImportEventText) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Raise NStr("en = 'Event handler AfterImportExchangeRules doesn''t support debugging.';");
				
			Else
				
				Execute(AfterExchangeRulesImportEventText);
				
			EndIf;
			
		Except
			
			Text = NStr("en = 'Handler: ""%1"": %2';");
			Text = SubstituteParametersToString(Text, "AfterImportExchangeRules",
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
				EventLogLevel.Error,,, Text);
				
			MessageToUser(Text);
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ProcessNewItemReadEnd(LastImportObject)
	
	mImportedObjectCounter = 1 + mImportedObjectCounter;
				
	If RememberImportedObjects
		And mImportedObjectCounter % 100 = 0 Then
				
		If ImportedObjects.Count() > ImportedObjectToStoreCount Then
			ImportedObjects.Clear();
		EndIf;
				
	EndIf;
	
	If mImportedObjectCounter % 100 = 0
		And mNotWrittenObjectGlobalStack.Count() > 100 Then
		
		ExecuteWriteNotWrittenObjects();
		
	EndIf;
	
	If UseTransactions
		And ObjectCountPerTransaction > 0 
		And mImportedObjectCounter % ObjectCountPerTransaction = 0 Then
		
		CommitTransaction();
		BeginTransaction();
		
	EndIf;	

EndProcedure

// Sequentially reads files of exchange message and writes data to the infobase.
//
// Parameters:
//  ErrorInfoResultString - String - an error info result string.
// 
Procedure RunReadingData(ErrorInfoResultString = "") Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Try
	
		While ExchangeFile.Read() Do
			
			NodeName = ExchangeFile.LocalName;
			
			If NodeName = "Object" Then
				
				LastImportObject = ReadObject();
				
				ProcessNewItemReadEnd(LastImportObject);
				
			ElsIf NodeName = "ParameterValue" Then	
				
				ImportDataExchangeParameterValues();
				
			ElsIf NodeName = "AfterParameterExportAlgorithm" Then	
				
				Cancel = False;
				CancelReason = "";
				
				AlgorithmText = "";
				Conversion.Property("AfterImportParameters", AlgorithmText);
				
				// 
				// 
				If IsBlankString(AlgorithmText) Then
					AlgorithmText = deElementValue(ExchangeFile, deStringType);
				Else
					ExchangeFile.Ignore();
				EndIf;
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("en = 'Event handler AfterImportParameters doesn''t support debugging.';");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
						If Cancel = True Then
							
							If Not IsBlankString(CancelReason) Then
								ExceptionString = SubstituteParametersToString(NStr("en = 'Data import canceled. Reason: %1';"), CancelReason);
								Raise ExceptionString;
							Else
								Raise NStr("en = 'Data import canceled';");
							EndIf;
							
						EndIf;
						
					Except
												
						WP = GetProtocolRecordStructure(75, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
						WP.Handler     = "AfterImportParameters";
						ErrorMessageString = WriteToExecutionProtocol(75, WP, True);
						
						If Not FlagDebugMode Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;				
				
			ElsIf NodeName = "Algorithm" Then
				
				AlgorithmText = deElementValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("en = 'Global algorithms don''t support debugging.';");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
					Except
						
						WP = GetProtocolRecordStructure(39, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
						WP.Handler     = "ExchangeFileAlgorithm";
						ErrorMessageString = WriteToExecutionProtocol(39, WP, True);
						
						If Not FlagDebugMode Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;
				
			ElsIf NodeName = "ExchangeRules" Then
				
				mExchangeRulesReadOnImport = True;
				
				If ConversionRulesTable.Count() = 0 Then
					ImportExchangeRules(ExchangeFile, "XMLReader");
				Else
					deSkip(ExchangeFile);
				EndIf;
				
			ElsIf NodeName = "DataTypeInformation" Then
				
				ImportDataTypeInformation();
				
			ElsIf (NodeName = "ExchangeFile") And (ExchangeFile.NodeType = deXMLNodeTypeEndElement) Then
				
			Else
				RecordStructure = New Structure("NodeName", NodeName);
				WriteToExecutionProtocol(9, RecordStructure);
			EndIf;
			
		EndDo;
		
	Except
		
		ErrorString = SubstituteParametersToString(NStr("en = 'Data import error: %1';"),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		ErrorInfoResultString = WriteToExecutionProtocol(ErrorString, Undefined, True, , , True);
		
		FinishKeepExchangeProtocol();
		ExchangeFile.Close();
		Return;
		
	EndTry;
	
EndProcedure

// Performs the following actions before reading data from the file: - initializes variables;
// - imports exchange rules from the data file;
// - begins a transaction for writing data to the infobase;
// - executes required event handlers.
//
// Parameters:
//  DataString1 - String - an import file name or XML string containing data to import.
//
//  Returns:
//     Boolean - 
//
Function ExecuteActionsBeforeReadData(DataString1 = "") Export
	
	DataProcessingMode = mDataProcessingModes.Load;

	mExtendedSearchParameterMap       = New Map;
	mConversionRuleMap         = New Map;
	
	Rules.Clear();
	
	InitializeCommentsOnDataExportAndImport();
	
	InitializeKeepExchangeProtocol();
	
	ImportPossible = True;
	
	If IsBlankString(DataString1) Then
	
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(15);
			ImportPossible = False;
		EndIf;
	
	EndIf;
	
	// Initializing the external data processor with export handlers.
	InitEventHandlerExternalDataProcessor(ImportPossible, ThisObject);
	
	If Not ImportPossible Then
		Return False;
	EndIf;
	
	MessageString = SubstituteParametersToString(NStr("en = 'Import started at: %1';"), CurrentSessionDate());
	WriteToExecutionProtocol(MessageString, , False, , , True);
	
	If FlagDebugMode Then
		UseTransactions = False;
	EndIf;
	
	If ProcessedObjectsCountToUpdateStatus = 0 Then
		
		ProcessedObjectsCountToUpdateStatus = 100;
		
	EndIf;
	
	mDataTypeMapForImport = New Map;
	mNotWrittenObjectGlobalStack = New Map;
	
	mImportedObjectCounter = 0;
	FlagErrors                  = False;
	ImportedObjects          = New Map;
	ImportedGlobalObjects = New Map;

	InitManagersAndMessages();
	
	OpenImportFile(,DataString1);
	
	If FlagErrors Then 
		FinishKeepExchangeProtocol();
		Return False; 
	EndIf;

	// Define handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRulesTable, CleanupRulesTable);
		
	EndIf;
	
	// BeforeDataImport handler
	Cancel = False;
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	If Not IsBlankString(Conversion.BeforeImportData) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeImportData"));
				
			Else
				
				Execute(Conversion.BeforeImportData);
				
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (conversion)';"); 
			WriteErrorInfoConversionHandlers(22, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
				SubstituteParametersToString(HandlerName, "BeforeImportData"));
			
			Cancel = True;
			
		EndTry;
		
		If Cancel Then // 
			FinishKeepExchangeProtocol();
			ExchangeFile.Close();
			EventHandlerExternalDataProcessorDestructor();
			Return False;
		EndIf;
		
	EndIf;

	// Clearing infobase by rules.
	ProcessClearingRules(CleanupRulesTable.Rows);
	
	Return True;
	
EndFunction

// Performs the following actions after the data import iteration:
// - commits the transaction (if necessary);
// - closes the exchange message file;
//  - executes the AfterImportData conversion handler;
// - completes the exchange logging (if necessary).
//
// Parameters:
//  No.
// 
Procedure ExecuteActionsAfterDataReadingCompleted() Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ConfigurationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	ExchangeFile.Close();
	
	// AfterImportData handler.
	If Not IsBlankString(Conversion.AfterImportData) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterImportData"));
				
			Else
				
				Execute(Conversion.AfterImportData);
				
			EndIf;
			
		Except
			
			HandlerName = NStr("en = '%1 (conversion)';");
			WriteErrorInfoConversionHandlers(23, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
				SubstituteParametersToString(HandlerName, "AfterImportData"));
			
		EndTry;
		
	EndIf;
	
	EventHandlerExternalDataProcessorDestructor();
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("en = 'Import finished at: %1';"), CurrentSessionDate()), , False, , , True);
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("en = 'Objects imported: %1';"), mImportedObjectCounter), , False, , , True);
	
	FinishKeepExchangeProtocol();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("en = 'Data import completed.';"));
	EndIf;
	
EndProcedure

// Imports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure ExecuteImport() Export
	
	ExecutionPossible = ExecuteActionsBeforeReadData();
	
	If Not ExecutionPossible Then
		Return;
	EndIf;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		RunReadingData();
		// Deferred recording of what was not recorded in the beginning.
		ExecuteWriteNotWrittenObjects();
		If UseTransactions Then
			CommitTransaction();
		EndIf;
	Except
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
	EndTry;
	
	ExecuteActionsAfterDataReadingCompleted();
	
EndProcedure

Procedure CompressResultingExchangeFile()
	
	Try
		
		SourceExchangeFileName = ExchangeFileName;
		If ArchiveFile Then
			ExchangeFileName = StrReplace(ExchangeFileName, ".xml", ".zip");
		EndIf;
		
		Archiver = New ZipFileWriter(ExchangeFileName, ExchangeFileCompressionPassword, NStr("en = 'Data exchange file';"));
		Archiver.Add(SourceExchangeFileName);
		Archiver.Write();
		
		DeleteFiles(SourceExchangeFileName);
		
	Except
		WriteLogEvent(NStr("en = 'Conversion Rule Data Exchange in XML format';", DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Function UnpackZipFile(FileNameForUnpacking)
	
	DirectoryToUnpack = TempFilesDirectory;
	CreateDirectory(DirectoryToUnpack);
	
	UnpackedFileName = "";
	
	Try
		
		Archiver = New ZipFileReader(FileNameForUnpacking, ExchangeFileUnpackPassword);
		
		If Archiver.Items.Count() > 0 Then
			
			ArchiveItem = Archiver.Items.Get(0);
			
			Archiver.Extract(ArchiveItem, DirectoryToUnpack, ZIPRestoreFilePathsMode.DontRestore);
			UnpackedFileName = GetExchangeFileName(DirectoryToUnpack, ArchiveItem.Name);
			
		Else
			
			UnpackedFileName = "";
			
		EndIf;
		
		Archiver.Close();
	
	Except
		
		WP = GetProtocolRecordStructure(2, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteToExecutionProtocol(2, WP, True);
		
		Return "";
							
	EndTry;
	
	Return UnpackedFileName;
		
EndFunction

Function SendExchangeStartedInformationToDestination(CurrentRowForWrite)
	
	If Not DirectReadingInDestinationIB Then
		Return True;
	EndIf;
	
	CurrentRowForWrite = CurrentRowForWrite + Chars.LF + mXMLRules + Chars.LF + "</ExchangeFile>" + Chars.LF;
	
	ExecutionPossible = mDataImportDataProcessor.ExecuteActionsBeforeReadData(CurrentRowForWrite);
	
	Return ExecutionPossible;	
	
EndFunction

Function ExecuteInformationTransferOnCompleteDataTransfer()
	
	If Not DirectReadingInDestinationIB Then
		Return True;
	EndIf;
	
	mDataImportDataProcessor.ExecuteActionsAfterDataReadingCompleted();
	
EndFunction

Procedure SendAdditionalParametersToDestination()
	
	For Each Parameter In ParametersSetupTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			SendOneParameterToDestination(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
					
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SendTypesInformationToDestination()
	
	If Not IsBlankString(mTypesForDestinationRow) Then
		WriteToFile(mTypesForDestinationRow);
	EndIf;
		
EndProcedure

// Exports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure ExecuteExport() Export
	
	DataProcessingMode = mDataProcessingModes.Upload0;
	
	InitializeKeepExchangeProtocol();
	
	InitializeCommentsOnDataExportAndImport();
	
	ExportPossible = True;
	CurrentNestingLevelExportByRule = 0;
	
	mDataExportCallStack = New ValueTable;
	mDataExportCallStack.Columns.Add("Ref");
	mDataExportCallStack.Indexes.Add("Ref");
	
	If mExchangeRulesReadOnImport = True Then
		
		WriteToExecutionProtocol(74);
		ExportPossible = False;	
		
	EndIf;
	
	If IsBlankString(ExchangeRulesFileName) Then
		WriteToExecutionProtocol(12);
		ExportPossible = False;
	EndIf;
	
	If Not DirectReadingInDestinationIB Then
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(10);
			ExportPossible = False;
		EndIf;
		
	Else
		
		mDataImportDataProcessor = EstablishConnectionWithDestinationIB(); 
		
		ExportPossible = mDataImportDataProcessor <> Undefined;
		
	EndIf;
	
	// Initializing the external data processor with export handlers.
	InitEventHandlerExternalDataProcessor(ExportPossible, ThisObject);
	
	If Not ExportPossible Then
		mDataImportDataProcessor = Undefined;
		Return;
	EndIf;
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("en = 'Export started at: %1';"), CurrentSessionDate()), , False, , , True);
		
	InitManagersAndMessages();
	
	mExportedObjectCounter = 0;
	mSnCounter 				= 0;
	FlagErrors                  = False;

	// Import exchange rules.
	If Conversion.Count() = 9 Then
		
		ImportExchangeRules();
		If FlagErrors Then
			FinishKeepExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			Return;
		EndIf;
		
	Else
		
		For Each Rule In ConversionRulesTable Do
			Rule.Exported_.Clear();
			Rule.OnlyRefsExported.Clear();
		EndDo;
		
	EndIf;

	// Assigning parameters that are set in the dialog.
	SetParametersFromDialog();

	// Open the exchange file.
	CurrentRowForWrite = OpenExportFile() + Chars.LF;
	
	If FlagErrors Then
		ExchangeFile = Undefined;
		FinishKeepExchangeProtocol();
		mDataImportDataProcessor = Undefined;
		Return; 
	EndIf;
	
	// Define handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRulesTable, CleanupRulesTable);
		
	EndIf;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Cancel = False;
	
	Try
	
		// 
		ExchangeFile.WriteLine(mXMLRules);
		
		Cancel = Not SendExchangeStartedInformationToDestination(CurrentRowForWrite);
		
		If Not Cancel Then
			
			If SafeMode Then
				SetSafeMode(True);
				For Each SeparatorName In ConfigurationSeparators Do
					SetDataSeparationSafeMode(SeparatorName, True);
				EndDo;
			EndIf;
			
			// BeforeDataExport handler
			Try
				
				If HandlersDebugModeFlag Then
					
					If Not IsBlankString(Conversion.BeforeExportData) Then
						
						Execute(GetHandlerCallString(Conversion, "BeforeExportData"));
						
					EndIf;
					
				Else
					
					Execute(Conversion.BeforeExportData);
					
				EndIf;
				
			Except
				
				HandlerName = NStr("en = '%1 (conversion)';");
				WriteErrorInfoConversionHandlers(62, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
					SubstituteParametersToString(HandlerName, "BeforeExportData"));
					
				Cancel = True;
				
			EndTry;
			
			If Not Cancel Then
				
				If ExecuteDataExchangeInOptimizedFormat Then
					SendTypesInformationToDestination();
				EndIf;
				
				// Sending parameters to the destination.
				SendAdditionalParametersToDestination();
				
				EventTextAfterParametersImport = "";
				If Conversion.Property("AfterImportParameters", EventTextAfterParametersImport)
					And Not IsBlankString(EventTextAfterParametersImport) Then
					
					WritingEvent = New XMLWriter;
					WritingEvent.SetString();
					deWriteElement(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParametersImport);
					WriteToFile(WritingEvent);
					
				EndIf;
				
				NodeAndExportRuleMap = New Map();
				StructureForChangeRegistrationDeletion = New Map();
				
				ProcessExportRules(ExportRulesCollection().Rows, NodeAndExportRuleMap);
				
				SuccessfullyExportedByExchangePlans = ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRegistrationDeletion);
				
				If SuccessfullyExportedByExchangePlans Then
				
					ProcessExchangeNodeRecordChangeEditing(StructureForChangeRegistrationDeletion);
				
				EndIf;
				
				// AfterDataExport handler
				Try
					
					If HandlersDebugModeFlag Then
						
						If Not IsBlankString(Conversion.AfterExportData) Then
							
							Execute(GetHandlerCallString(Conversion, "AfterExportData"));
							
						EndIf;
						
					Else
						
						Execute(Conversion.AfterExportData);
						
					EndIf;

				Except
					
					HandlerName = NStr("en = '%1 (conversion)';");
					WriteErrorInfoConversionHandlers(63, ErrorProcessing.DetailErrorDescription(ErrorInfo()), 
						SubstituteParametersToString(HandlerName, "AfterExportData"));
					
				EndTry;
				
				ExecuteWriteNotWrittenObjects();
				
				If TransactionActive() Then
					CommitTransaction();
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Cancel Then
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
			
			ExecuteInformationTransferOnCompleteDataTransfer();
			
			FinishKeepExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			ExchangeFile = Undefined;
			
			EventHandlerExternalDataProcessorDestructor();
			
		EndIf;
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		Cancel = True;
		ErrorString = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteToExecutionProtocol(SubstituteParametersToString(
			NStr("en = 'Data export error: %1';"), ErrorString), Undefined, True, , , True);
		
		ExecuteInformationTransferOnCompleteDataTransfer();
		
		FinishKeepExchangeProtocol();
		CloseFile();
		mDataImportDataProcessor = Undefined;
				
	EndTry;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Close the exchange file.
	CloseFile();
	
	If ArchiveFile Then
		CompressResultingExchangeFile();
	EndIf;
	
	ExecuteInformationTransferOnCompleteDataTransfer();
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("en = 'Export finished at: %1';"), CurrentSessionDate()), , False, , ,True);
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("en = 'Objects exported: %1';"), mExportedObjectCounter), , False, , , True);
	
	FinishKeepExchangeProtocol();
	
	mDataImportDataProcessor = Undefined;
	
	EventHandlerExternalDataProcessorDestructor();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("en = 'Data has been exported.';"));
	EndIf;
	
EndProcedure

#EndRegion

#Region SetAttributesValuesAndDataProcessorModalVariables

// The procedure of setting the ErrorFlag global variable value.
//
// Parameters:
//  Value - Boolean - the new value of the ErrorFlag variable.
//  
Procedure SetErrorFlag2(Value)
	
	FlagErrors = Value;
	
	If FlagErrors Then
		
		EventHandlerExternalDataProcessorDestructor(FlagDebugMode);
		
	EndIf;
	
EndProcedure

// Returns the current value of the data processor version.
//
// Parameters:
//  No.
// 
// Returns:
//  Current value of the data processor version.
//
Function ObjectVersionAsString() Export
	
	Return "2.1.8";
	
EndFunction

#EndRegion

#Region InitializingExchangeRulesTables

Procedure AddMissingColumns(Columns, Name, Types = Undefined)
	
	If Columns.Find(Name) <> Undefined Then
		Return;
	EndIf;
	
	Columns.Add(Name, Types);
	
EndProcedure

// Initializes table columns of object conversion rules.
//
// Parameters:
//  No.
// 
Procedure InitConversionRuleTable()

	Columns = ConversionRulesTable.Columns;
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "SynchronizeByID");
	AddMissingColumns(Columns, "DontCreateIfNotFound", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "DontExportPropertyObjectsByRefs", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "SearchBySearchFieldsIfNotFoundByID", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "OnExchangeObjectByRefSetGIUDOnly", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "UseQuickSearchOnImport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "GenerateNewNumberOrCodeIfNotSet", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "TinyObjectCount", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "RefExportReferenceCount", deTypeDetails("Number"));
	AddMissingColumns(Columns, "IBItemsCount", deTypeDetails("Number"));
	
	AddMissingColumns(Columns, "ExportMethod");

	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Receiver");
	
	AddMissingColumns(Columns, "SourceType",  deTypeDetails("String"));

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");
	AddMissingColumns(Columns, "AfterExportToFile");
	
	AddMissingColumns(Columns, "HasBeforeExportHandler",	    deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportToFileHandler",	deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "BeforeImport");
	AddMissingColumns(Columns, "OnImport");
	AddMissingColumns(Columns, "AfterImport");
	
	AddMissingColumns(Columns, "SearchFieldSequence");
	AddMissingColumns(Columns, "SearchInTabularSections");
	
	AddMissingColumns(Columns, "HasBeforeImportHandler", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnImportHandler",    deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterImportHandler",  deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "HasSearchFieldSequenceHandler",  deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "SearchProperties",	deTypeDetails("ValueTable"));
	AddMissingColumns(Columns, "Properties",		deTypeDetails("ValueTable"));
	
	AddMissingColumns(Columns, "Values",		deTypeDetails("Map"));

	AddMissingColumns(Columns, "Exported_",							deTypeDetails("Map"));
	AddMissingColumns(Columns, "OnlyRefsExported",				deTypeDetails("Map"));
	AddMissingColumns(Columns, "ExportSourcePresentation",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "NotReplace",					deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "RememberExportedData",       deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "AllObjectsExported",         deTypeDetails("Boolean"));
	
EndProcedure

// Initializes table columns of data export rules.
//
// Parameters:
//  No
// 
Procedure InitExportRuleTable()

	Columns = ExportRulesTable.Columns;

	AddMissingColumns(Columns, "Enable",		deTypeDetails("Number"));
	AddMissingColumns(Columns, "IsFolder",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "DataFilterMethod");
	AddMissingColumns(Columns, "SelectionObject1");
	
	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "AfterExport");
	
	// Columns for filtering using the query builder.
	AddMissingColumns(Columns, "UseFilter1", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "BuilderSettings");
	AddMissingColumns(Columns, "ObjectForQueryName");
	AddMissingColumns(Columns, "ObjectNameForRegisterQuery");
	
	AddMissingColumns(Columns, "SelectExportDataInSingleQuery", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "ExchangeNodeRef");

EndProcedure

// Initializes table columns of data clearing rules.
//
// Parameters:
//  No.
// 
Procedure CleaningRuleTableInitialization()

	Columns = CleanupRulesTable.Columns;

	AddMissingColumns(Columns, "Enable",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "IsFolder",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order",	deTypeDetails("Number"));

	AddMissingColumns(Columns, "DataFilterMethod");
	AddMissingColumns(Columns, "SelectionObject1");
	
	AddMissingColumns(Columns, "DeleteForPeriod");
	AddMissingColumns(Columns, "Directly",	deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");
	AddMissingColumns(Columns, "BeforeDeleteRow");
	
EndProcedure

// Initializes table columns of parameter setup table.
//
// Parameters:
//  No.
// 
Procedure ParametersSetupTableInitialization()

	Columns = ParametersSetupTable.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Value");
	AddMissingColumns(Columns, "PassParameterOnExport");
	AddMissingColumns(Columns, "ConversionRule");

EndProcedure

#EndRegion

#Region InitAttributesAndModuleVariables

Procedure InitializeCommentsOnDataExportAndImport()
	
	CommentOnDataExport = "";
	CommentOnDataImport = "";
	
EndProcedure

// Initializes the deMessages variable that contains mapping of message codes and their description.
//
// Parameters:
//  No.
// 
Procedure InitMessages()

	deMessages = New Map;
	
	deMessages.Insert(2,  NStr("en = 'Error extracting exchange file. File is locked.';"));
	deMessages.Insert(3,  NStr("en = 'The exchange rules file does not exist.';"));
	
	ErrorText = NStr("en = 'An error occurred while creating the %1 COM object';");
	deMessages.Insert(4,  SubstituteParametersToString(ErrorText,"Msxml2.DOMDocument"));
	
	deMessages.Insert(5,  NStr("en = 'Error opening exchange file';"));
	deMessages.Insert(6,  NStr("en = 'Error importing exchange rules';"));
	deMessages.Insert(7,  NStr("en = 'Exchange rule format error';"));
	deMessages.Insert(8,  NStr("en = 'Invalid data export file name';"));
	deMessages.Insert(9,  NStr("en = 'Exchange file format error';"));
	deMessages.Insert(10, NStr("en = 'Data export file name is not specified';"));
	deMessages.Insert(11, NStr("en = 'Exchange rules reference a metadata object that does not exist';"));
	deMessages.Insert(12, NStr("en = 'Exchange rules file name is not specified';"));
	
	deMessages.Insert(13, NStr("en = 'Error getting value of object property by property name in source infobase';"));
	deMessages.Insert(14, NStr("en = 'Error getting value of object property by property name in destination infobase';"));
	
	deMessages.Insert(15, NStr("en = 'Data import file name is not specified';"));
	
	deMessages.Insert(16, NStr("en = 'Error getting value of subordinate object property by property name in source infobase';"));
	deMessages.Insert(17, NStr("en = 'Error getting value of subordinate object property by property name in destination infobase';"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(19, SubstituteParametersToString(ErrorText, "BeforeImportObject"));
	deMessages.Insert(20, SubstituteParametersToString(ErrorText, "OnImportObject"));
	deMessages.Insert(21, SubstituteParametersToString(ErrorText, "AfterImportObject"));
	
	ErrorText = NStr("en = 'Event handler error (data conversion): %1';");
	deMessages.Insert(22, SubstituteParametersToString(ErrorText, "BeforeImportData"));
	deMessages.Insert(23, SubstituteParametersToString(ErrorText, "AfterImportData"));
	
	deMessages.Insert(24, NStr("en = 'Error deleting object';"));
	deMessages.Insert(25, NStr("en = 'Error writing document';"));
	deMessages.Insert(26, NStr("en = 'Error writing object';"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(27, SubstituteParametersToString(ErrorText, "BeforeProcessingTheUploadRule"));
	deMessages.Insert(28, SubstituteParametersToString(ErrorText, "AfterProcessClearingRule"));
	deMessages.Insert(29, SubstituteParametersToString(ErrorText, "BeforeDeleteObject"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(31, SubstituteParametersToString(ErrorText, "BeforeProcessingTheUploadRule"));
	deMessages.Insert(32, SubstituteParametersToString(ErrorText, "AfterProcessingTheUploadRule"));
	deMessages.Insert(33, SubstituteParametersToString(ErrorText, "BeforeExportObject"));
	deMessages.Insert(34, SubstituteParametersToString(ErrorText, "AfterExportObject"));
	
	deMessages.Insert(39, NStr("en = 'Exchange file algorithm execution error';"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(41, SubstituteParametersToString(ErrorText, "BeforeExportObject"));
	deMessages.Insert(42, SubstituteParametersToString(ErrorText, "OnExportObject"));
	deMessages.Insert(43, SubstituteParametersToString(ErrorText, "AfterExportObject"));
	
	deMessages.Insert(45, NStr("en = 'Object conversion rule not found';"));
	
	ErrorText = NStr("en = 'Event handler error: %1 of property group';");
	deMessages.Insert(48, SubstituteParametersToString(ErrorText, "BeforeProcessExport"));
	deMessages.Insert(49, SubstituteParametersToString(ErrorText, "AfterProcessExport"));
	
	ErrorText = NStr("en = 'Event handler error: %1 (of collection object)';");
	deMessages.Insert(50, SubstituteParametersToString(ErrorText, "BeforeExport"));
	deMessages.Insert(51, SubstituteParametersToString(ErrorText, "OnExport"));
	deMessages.Insert(52, SubstituteParametersToString(ErrorText, "AfterExport"));
	
	ErrorText = NStr("en = 'Global event handler error (data conversion): %1';"); 
	deMessages.Insert(53, SubstituteParametersToString(ErrorText, "BeforeImportObject"));
	deMessages.Insert(54, SubstituteParametersToString(ErrorText, "AfterImportObject"));
	
	ErrorText = NStr("en = 'Event handler error: %1 (of property)';");
	deMessages.Insert(55, SubstituteParametersToString(ErrorText, "BeforeExport"));
	deMessages.Insert(56, SubstituteParametersToString(ErrorText, "OnExport"));
	deMessages.Insert(57, SubstituteParametersToString(ErrorText, "AfterExport"));
	
	ErrorText = NStr("en = 'Event handler error (data conversion): %1';");
	deMessages.Insert(62, SubstituteParametersToString(ErrorText, "BeforeExportData"));
	deMessages.Insert(63, SubstituteParametersToString(ErrorText, "AfterExportData"));
	
	ErrorText = NStr("en = 'Global event handler error (data conversion): %1';");
	deMessages.Insert(64,  SubstituteParametersToString(ErrorText, "BeforeConvertObject"));
	deMessages.Insert(65, SubstituteParametersToString(ErrorText, "BeforeExportObject"));
	
	deMessages.Insert(66, NStr("en = 'Error getting collection of subordinate objects from incoming data';"));
	deMessages.Insert(67, NStr("en = 'Error getting property of subordinate object from incoming data';"));
	deMessages.Insert(68, NStr("en = 'Error getting object property from incoming data';"));
	
	ErrorText = NStr("en = 'Global event handler error (data conversion): %1';");
	deMessages.Insert(69, SubstituteParametersToString(ErrorText, "AfterExportObject"));
	
	deMessages.Insert(71, NStr("en = 'Cannot find a match for the source value';"));
	
	deMessages.Insert(72, NStr("en = 'Error exporting data for exchange plan node';"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(73, SubstituteParametersToString(ErrorText, "SearchFieldSequence"));
	
	deMessages.Insert(74, NStr("en = 'Reloading exchange rules is required';"));
	
	deMessages.Insert(75, NStr("en = 'Algorithm fails after parameter values are imported';"));
	
	ErrorText = NStr("en = 'Event handler error: %1';");
	deMessages.Insert(76, SubstituteParametersToString(ErrorText, "AfterUploadingTheObjectToAFile"));
	
	deMessages.Insert(77, NStr("en = 'External data processor file not specified';"));
	
	deMessages.Insert(78, NStr("en = 'Error creating external data processor from file with event handlers';"));
	
	deMessages.Insert(79, NStr("en = 'Cannot integrate algorithms'' code into the handler.
	                         |A recursive algorithm call has been detected.
	                         |If you don''t need to debug algorithms, select ""No debugging"".
	                         |To debug algorithms with a recursive call, select ""Call algorithms as procedures"" and try again.';"));
	
	deMessages.Insert(80, NStr("en = 'You must have full rights to run the data exchange';"));
	
	deMessages.Insert(1000, NStr("en = 'Error creating temporary data export file';"));

EndProcedure

Procedure SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, TypeName, Manager, TypeNamePrefix, SearchByPredefinedItemsPossible = False)
	
	Name              = MetadataObjectsList.Name;
	RefTypeString1 = TypeNamePrefix + "." + Name;
	
	QueryText = 
	"SELECT
	|	AliasOfTheMetadataTable.Ref
	|FROM
	|	&MetadataTableName AS AliasOfTheMetadataTable
	|WHERE
	|	&AutocorrectParameterForZeroingTheConditionSection";
	
	ReplacementString = "";
	ReplacementString = SubstituteParametersToString("%1.%2", TypeName, Name);
	QueryText = StrReplace(QueryText, "&MetadataTableName", ReplacementString);
	QueryText = StrReplace(QueryText, "&AutocorrectParameterForZeroingTheConditionSection", "");
	
	SearchString     = QueryText;
	RefType        = Type(RefTypeString1);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);
	Structure.Insert("SearchByPredefinedItemsPossible", SearchByPredefinedItemsPossible);
	Structure.Insert("SearchString", SearchString);
	Managers.Insert(RefType, Structure);
	
	StructureForExchangePlan = ExchangePlanParametersStructure(Name, RefType, True, False);
	ManagersForExchangePlans.Insert(MetadataObjectsList, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagerArrayWithRegisterType(Managers, MetadataObjectsList, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodic3 = Undefined;
	
	Name					= MetadataObjectsList.Name;
	RefTypeString1	= TypeNamePrefixRecord + "." + Name;
	RefType			= Type(RefTypeString1);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);
	
	If TypeName = "InformationRegister" Then
		
		Periodic3 = (MetadataObjectsList.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinateToRecorder = (MetadataObjectsList.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodic3", Periodic3);
		Structure.Insert("SubordinateToRecorder", SubordinateToRecorder);
		
	EndIf;	
	
	Managers.Insert(RefType, Structure);
		

	StructureForExchangePlan = ExchangePlanParametersStructure(Name, RefType, False, True);

	ManagersForExchangePlans.Insert(MetadataObjectsList, StructureForExchangePlan);
	
	
	RefTypeString1	= SelectionTypeNamePrefix + "." + Name;
	RefType			= Type(RefTypeString1);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);

	If Periodic3 <> Undefined Then
		
		Structure.Insert("Periodic3", Periodic3);
		Structure.Insert("SubordinateToRecorder", SubordinateToRecorder);	
		
	EndIf;
	
	Managers.Insert(RefType, Structure);	
		
EndProcedure

// Initializes the Managers variable that contains mapping of object types and their properties.
//
// Parameters:
//  No.
// 
Procedure ManagersInitialization()

	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
    	
	// REFERENCES
	
	For Each MetadataObjectsList In Metadata.Catalogs Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "Catalog", Catalogs[MetadataObjectsList.Name], "CatalogRef", True);
					
	EndDo;

	For Each MetadataObjectsList In Metadata.Documents Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "Document", Documents[MetadataObjectsList.Name], "DocumentRef");
				
	EndDo;

	For Each MetadataObjectsList In Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MetadataObjectsList.Name], "ChartOfCharacteristicTypesRef", True);
				
	EndDo;
	
	For Each MetadataObjectsList In Metadata.ChartsOfAccounts Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "ChartOfAccounts", ChartsOfAccounts[MetadataObjectsList.Name], "ChartOfAccountsRef", True);
						
	EndDo;
	
	For Each MetadataObjectsList In Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MetadataObjectsList.Name], "ChartOfCalculationTypesRef", True);
				
	EndDo;
	
	For Each MetadataObjectsList In Metadata.ExchangePlans Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "ExchangePlan", ExchangePlans[MetadataObjectsList.Name], "ExchangePlanRef");
				
	EndDo;
	
	For Each MetadataObjectsList In Metadata.Tasks Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "Task", Tasks[MetadataObjectsList.Name], "TaskRef");
				
	EndDo;
	
	For Each MetadataObjectsList In Metadata.BusinessProcesses Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadataObjectsList, "BusinessProcess", BusinessProcesses[MetadataObjectsList.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// Route point references
		Name              = MetadataObjectsList.Name;
		Manager         = BusinessProcesses[Name].RoutePoints;
		SearchString     = "";
		RefTypeString1 = "BusinessProcessRoutePointRef." + Name;
		RefType        = Type(RefTypeString1);
		Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);
		Structure.Insert("EmptyRef", Undefined);
		Structure.Insert("SearchString", SearchString);
		Managers.Insert(RefType, Structure);
				
	EndDo;
	
	// REGISTERS

	For Each MetadataObjectsList In Metadata.InformationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadataObjectsList, "InformationRegister", InformationRegisters[MetadataObjectsList.Name], "InformationRegisterRecord", "InformationRegisterSelection");
						
	EndDo;

	For Each MetadataObjectsList In Metadata.AccountingRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadataObjectsList, "AccountingRegister", AccountingRegisters[MetadataObjectsList.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
				
	EndDo;
	
	For Each MetadataObjectsList In Metadata.AccumulationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadataObjectsList, "AccumulationRegister", AccumulationRegisters[MetadataObjectsList.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
						
	EndDo;
	
	For Each MetadataObjectsList In Metadata.CalculationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadataObjectsList, "CalculationRegister", CalculationRegisters[MetadataObjectsList.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
						
	EndDo;
	
	TypeName = "Enum";
	
	For Each MetadataObjectsList In Metadata.Enums Do
		
		Name              = MetadataObjectsList.Name;
		Manager         = Enums[Name];
		RefTypeString1 = "EnumRef." + Name;
		RefType        = Type(RefTypeString1);
		Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);
		Structure.Insert("EmptyRef", Enums[Name].EmptyRef());

		Managers.Insert(RefType, Structure);
		
	EndDo;	
	
	// Константы
	TypeName             = "Constants";
	MetadataObjectsList            = Metadata.Constants;
	Name					= "Constants";
	Manager			= Constants;
	RefTypeString1	= "ConstantsSet";
	RefType			= Type(RefTypeString1);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList);
	Managers.Insert(RefType, Structure);
	
EndProcedure

// Initializes object managers and all messages of the data exchange protocol.
//
// Parameters:
//  No.
// 
Procedure InitManagersAndMessages() Export
	
	If Managers = Undefined Then
		ManagersInitialization();
	EndIf; 

	If deMessages = Undefined Then
		InitMessages();
	EndIf;
	
EndProcedure

// Returns:
//   Structure:
//     * FormatVersion - String
//     * ID_SSLy - String
//     * Description - String
//     * CreationDateTime - Date
//     * SourcePlatformVersion - String
//     * SourceConfigurationSynonym - String
//     * SourceConfigurationVersion - String
//     * Source - String
//     * DestinationPlatformVersion - String
//     * DestinationConfigurationSynonym - String
//     * DestinationConfigurationVersion - String
//     * Receiver - String
//     * AfterImportExchangeRules - String
//     * BeforeExportData - String
//     * BeforeGetChangedObjects - String
//     * AfterGetExchangeNodesInformation - String
//     * AfterExportData - String
//     * BeforeSendDeletionInfo - String
//     * BeforeExportObject - String
//     * AfterExportObject - String
//     * BeforeImportObject - String
//     * AfterImportObject - String
//     * BeforeConvertObject - String
//     * BeforeImportData - String
//     * AfterImportData - String
//     * AfterImportParameters - String
//     * OnGetDeletionInfo - String
//
Function Conversion()
	Return Conversion;
EndFunction

// Returns:
//   Structure:
//     * Name - String
//     * TypeName - String
//     * RefTypeString1 - String
//     * Manager - CatalogManager
//                - DocumentManager
//                - InformationRegisterManager
//                - 
//     * MetadataObjectsList - MetadataObjectCatalog
//                - MetadataObjectDocument
//                - MetadataObjectInformationRegister
//                - 
//     * OCR - See FindRule
//
Function Managers(Type)
	Return Managers[Type];
EndFunction

Procedure CreateConversionStructure()
	
	Conversion  = New Structure("BeforeExportData, AfterExportData, BeforeExportObject, AfterExportObject, BeforeConvertObject, BeforeImportObject, AfterImportObject, BeforeImportData, AfterImportData");
	
EndProcedure

// Initializes data processor attributes and module variables.
//
// Parameters:
//  No.
// 
Procedure InitAttributesAndModuleVariables()

	ProcessedObjectsCountToUpdateStatus = 100;
	
	RememberImportedObjects     = True;
	ImportedObjectToStoreCount = 5000;
	
	ParametersInitialized        = False;
	
	WriteToXMLAdvancedMonitoring = False;
	DirectReadingInDestinationIB = False;
	DontOutputInfoMessagesToUser = False;
	
	Managers    = Undefined;
	deMessages  = Undefined;
	
	FlagErrors   = False;
	
	CreateConversionStructure();
	
	Rules      = New Structure;
	Algorithms    = New Structure;
	AdditionalDataProcessors = New Structure;
	Queries      = New Structure;

	Parameters    = New Structure;
	EventsAfterParametersImport = New Structure;
	
	AdditionalDataProcessorParameters = New Structure;
	
	// Типы
	deStringType                  = Type("String");
	deBooleanType                  = Type("Boolean");
	deNumberType                   = Type("Number");
	deDateType                    = Type("Date");
	deValueStorageType       = Type("ValueStorage");
	deUUIDType = Type("UUID");
	deBinaryDataType          = Type("BinaryData");
	deAccumulationRecordTypeType   = Type("AccumulationRecordType");
	deObjectDeletionType         = Type("ObjectDeletion");
	deAccountTypeType			     = Type("AccountType");
	deTypeType                     = Type("Type");
	deMapType            = Type("Map");

	BlankDateValue		   = Date('00010101');
	
	mXMLRules  = Undefined;
	
	// 
	
	deXMLNodeTypeEndElement  = XMLNodeType.EndElement;
	deXMLNodeTypeStartElement = XMLNodeType.StartElement;
	deXMLNodeTypeText          = XMLNodeType.Text;


	mExchangeRuleTemplateList  = New ValueList;

	For Each Template In Metadata().Templates Do
		mExchangeRuleTemplateList.Add(Template.Synonym);
	EndDo; 
	    	
	mDataProtocolFile = Undefined;
	
	InfobaseToConnectType = True;
	InfobaseToConnectWindowsAuthentication = False;
	InfobaseToConnectPlatformVersion = "V8";
	OpenExchangeProtocolsAfterExecutingOperations = False;
	ImportDataInExchangeMode = True;
	WriteToInfobaseOnlyChangedObjects = True;
	WriteRegistersAsRecordSets = True;
	OptimizedObjectsWriting = True;
	ExportAllowedObjectsOnly = True;
	ImportReferencedObjectsWithoutDeletionMark = True;	
	UseFilterByDateForAllObjects = True;
	
	mEmptyTypeValueMap = New Map;
	mTypeDescriptionMap = New Map;
	
	mExchangeRulesReadOnImport = False;

	ReadEventHandlersFromExchangeRulesFile = True;
	
	mDataProcessingModes = New Structure;
	mDataProcessingModes.Insert("Upload0",                   0);
	mDataProcessingModes.Insert("Load",                   1);
	mDataProcessingModes.Insert("ExchangeRulesImport",       2);
	mDataProcessingModes.Insert("EventHandlersExport", 3);
	
	DataProcessingMode = mDataProcessingModes.Upload0;
	
	mAlgorithmDebugModes = New Structure;
	mAlgorithmDebugModes.Insert("DontUse",   0);
	mAlgorithmDebugModes.Insert("ProceduralCall", 1);
	mAlgorithmDebugModes.Insert("CodeIntegration",   2);
	
	AlgorithmsDebugMode = mAlgorithmDebugModes.DontUse;
	
	// Standard subsystem modules.
	Try
		// 
		ModulePeriodClosingDates = Eval("PeriodClosingDates");
	Except
		ModulePeriodClosingDates = Undefined;
	EndTry;
	
	ConfigurationSeparators = New Array;
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			ConfigurationSeparators.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	ConfigurationSeparators = New FixedArray(ConfigurationSeparators);
	
	TempFilesDirectory = GetTempFileName();
	DeleteFiles(TempFilesDirectory);
	
EndProcedure

Function DetermineIfEnoughInfobaseConnectionParameters(ConnectionStructure, StringForConnection = "", ErrorMessageString = "")
	
	ErrorsExist = False;
	
	If ConnectionStructure.FileMode  Then
		
		If IsBlankString(ConnectionStructure.IBDirectory) Then
			
			ErrorMessageString = NStr("en = 'Destination infobase directory not specified';");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		StringForConnection = "File=""" + ConnectionStructure.IBDirectory + """";
	Else
		
		If IsBlankString(ConnectionStructure.ServerName) Then
			
			ErrorMessageString = NStr("en = 'Server of destination infobase not specified';");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		If IsBlankString(ConnectionStructure.IBNameAtServer) Then
			
			ErrorMessageString = NStr("en = 'Infobase name on 1C:Enterprise server not specified';");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;		
		
		StringForConnection = "Srvr = """ + ConnectionStructure.ServerName + """; Ref = """ + ConnectionStructure.IBNameAtServer + """";		
		
	EndIf;
	
	Return Not ErrorsExist;	
	
EndFunction

Function ConnectToInfobase(ConnectionStructure, ErrorMessageString = "")
	
	Var StringForConnection;
	
	EnoughParameters = DetermineIfEnoughInfobaseConnectionParameters(ConnectionStructure, StringForConnection, ErrorMessageString);
	
	If Not EnoughParameters Then
		Return Undefined;
	EndIf;
	
	If Not ConnectionStructure.WindowsAuthentication Then
		If Not IsBlankString(ConnectionStructure.User) Then
			StringForConnection = StringForConnection + ";Usr = """ + ConnectionStructure.User + """";
		EndIf;
		If Not IsBlankString(ConnectionStructure.Password) Then
			StringForConnection = StringForConnection + ";Pwd = """ + ConnectionStructure.Password + """";
		EndIf;
	EndIf;
	
	// "V82" or "V83".
	ConnectionObject = ConnectionStructure.PlatformVersion;
	
	StringForConnection = StringForConnection + ";";
	
	Try
		
		ConnectionObject = ConnectionObject +".COMConnector";
		CurrentCOMConnection = New COMObject(ConnectionObject);
		CurCOMObject = CurrentCOMConnection.Connect(StringForConnection);
		
	Except
		
		ErrorMessageString = NStr("en = 'Error when connecting to COM server:
			|%1';");
		ErrorMessageString = SubstituteParametersToString(ErrorMessageString, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		MessageToUser(ErrorMessageString);
		
		Return Undefined;
		
	EndTry;
	
	Return CurCOMObject;
	
EndFunction

// Returns the string part that follows the last specified character.
Function GetStringAfterCharacter(Val InitialString, Val SearchChar)
	
	CharPosition = StrLen(InitialString);
	While CharPosition >= 1 Do
		
		If Mid(InitialString, CharPosition, 1) = SearchChar Then
						
			Return Mid(InitialString, CharPosition + 1); 
			
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return "";
  	
EndFunction

// Returns the file extension.
//
// Parameters:
//  FileName     - String - containing the file name (with or without the directory name).
//
// Returns:
//   String - file extension.
//
Function GetFileNameExtension(Val FileName) Export
	
	Extension = GetStringAfterCharacter(FileName, ".");
	Return Extension;
	
EndFunction

Function GetProtocolNameForCOMConnectionSecondInfobase() Export
	
	If Not IsBlankString(ImportExchangeLogFileName) Then
			
		Return ImportExchangeLogFileName;	
		
	ElsIf Not IsBlankString(ExchangeProtocolFileName) Then
		
		ProtocolFileExtension = GetFileNameExtension(ExchangeProtocolFileName);
		
		If Not IsBlankString(ProtocolFileExtension) Then
							
			ExportProtocolFileName = StrReplace(ExchangeProtocolFileName, "." + ProtocolFileExtension, "");
			
		EndIf;
		
		ExportProtocolFileName = ExportProtocolFileName + "_Load";
		
		If Not IsBlankString(ProtocolFileExtension) Then
			
			ExportProtocolFileName = ExportProtocolFileName + "." + ProtocolFileExtension;	
			
		EndIf;
		
		Return ExportProtocolFileName;
		
	EndIf;
	
	Return "";
	
EndFunction

// Establishing the connection to the target infobase by the specified parameters.
// Returns the initialized UniversalDataExchangeXML target infobase data processor,
// which is used for importing data into the target infobase.
//
// Parameters:
//  No.
// 
//  Returns:
//    DataProcessorObject.UniversalDataExchangeXML - 
//
Function EstablishConnectionWithDestinationIB() Export
	
	ConnectionResult = Undefined;
	
	ConnectionStructure = New Structure();
	ConnectionStructure.Insert("FileMode", InfobaseToConnectType);
	ConnectionStructure.Insert("WindowsAuthentication", InfobaseToConnectWindowsAuthentication);
	ConnectionStructure.Insert("IBDirectory", InfobaseToConnectDirectory);
	ConnectionStructure.Insert("ServerName", InfobaseToConnectServerName);
	ConnectionStructure.Insert("IBNameAtServer", InfobaseToConnectNameOnServer);
	ConnectionStructure.Insert("User", InfobaseToConnectUser);
	ConnectionStructure.Insert("Password", InfobaseToConnectPassword);
	ConnectionStructure.Insert("PlatformVersion", InfobaseToConnectPlatformVersion);
	
	ConnectionObject = ConnectToInfobase(ConnectionStructure);
	
	If ConnectionObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		ConnectionResult = ConnectionObject.DataProcessors.UniversalDataExchangeXML.Create();
	Except
		
		Text = NStr("en = 'An error occurred while trying to create the %1 data processor: %2';");
		Text = SubstituteParametersToString(Text, Metadata().Name, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		MessageToUser(Text);
		ConnectionResult = Undefined;
		
	EndTry;
	
	If ConnectionResult <> Undefined Then
		
		ConnectionResult.UseTransactions = UseTransactions;	
		ConnectionResult.ObjectCountPerTransaction = ObjectCountPerTransaction;
		
		ConnectionResult.FlagDebugMode = FlagDebugMode;
		
		ConnectionResult.ExchangeProtocolFileName = GetProtocolNameForCOMConnectionSecondInfobase();
								
		ConnectionResult.AppendDataToExchangeLog = AppendDataToExchangeLog;
		ConnectionResult.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
		
		ConnectionResult.ExchangeMode = "Load";
		
	EndIf;
	
	Return ConnectionResult;
	
EndFunction

// Deletes objects of the specified type according to the data clearing rules
// (deletes physically or marks for deletion).
//
// Parameters:
//  TypeNameToRemove - String - a string type name.
// 
Procedure DeleteObjectsOfType(TypeNameToRemove) Export
	
	DataTypeToDelete = Type(TypeNameToRemove);
	
	Manager = Managers[DataTypeToDelete];
	TypeName  = Manager.TypeName;
	Properties = Managers[DataTypeToDelete];
	
	Rule = New Structure("Name,Directly,BeforeDeleteRow", "ObjectDeletion", True, "");
					
	Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, True, False);
	
	While Selection.Next() Do
		
		If TypeName =  "InformationRegister" Then
			
			RecordManager = Properties.Manager.CreateRecordManager(); 
			FillPropertyValues(RecordManager, Selection);
								
			SelectionObjectDeletion(RecordManager, Rule, Properties, Undefined);
				
		Else
				
			SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, Undefined);
				
		EndIf;
			
	EndDo;	
	
EndProcedure

Procedure SupplementInternalTablesWithColumns()
	
	InitConversionRuleTable();
	InitExportRuleTable();
	CleaningRuleTableInitialization();
	ParametersSetupTableInitialization();	
	
EndProcedure

Function GetNewUniqueTempFileName(OldTempFileName, Extension = "txt")
	
	DeleteTempFiles(OldTempFileName);
	
	Return GetTempFileName(Extension);
	
EndFunction 

Procedure InitHandlersNamesStructure()
	
	// Conversion handlers.
	ConversionHandlersNames = New Structure;
	ConversionHandlersNames.Insert("BeforeExportData");
	ConversionHandlersNames.Insert("AfterExportData");
	ConversionHandlersNames.Insert("BeforeExportObject");
	ConversionHandlersNames.Insert("AfterExportObject");
	ConversionHandlersNames.Insert("BeforeConvertObject");
	ConversionHandlersNames.Insert("BeforeSendDeletionInfo");
	ConversionHandlersNames.Insert("BeforeGetChangedObjects");
	
	ConversionHandlersNames.Insert("BeforeImportObject");
	ConversionHandlersNames.Insert("AfterImportObject");
	ConversionHandlersNames.Insert("BeforeImportData");
	ConversionHandlersNames.Insert("AfterImportData");
	ConversionHandlersNames.Insert("OnGetDeletionInfo");
	ConversionHandlersNames.Insert("AfterGetExchangeNodesInformation");
	
	ConversionHandlersNames.Insert("AfterImportExchangeRules");
	ConversionHandlersNames.Insert("AfterImportParameters");
	
	// OCR handlers.
	OCRHandlersNames = New Structure;
	OCRHandlersNames.Insert("BeforeExport");
	OCRHandlersNames.Insert("OnExport");
	OCRHandlersNames.Insert("AfterExport");
	OCRHandlersNames.Insert("AfterExportToFile");
	
	OCRHandlersNames.Insert("BeforeImport");
	OCRHandlersNames.Insert("OnImport");
	OCRHandlersNames.Insert("AfterImport");
	
	OCRHandlersNames.Insert("SearchFieldSequence");
	
	// PCR handlers.
	PCRHandlersNames = New Structure;
	PCRHandlersNames.Insert("BeforeExport");
	PCRHandlersNames.Insert("OnExport");
	PCRHandlersNames.Insert("AfterExport");

	// PGCR handlers.
	PGCRHandlersNames = New Structure;
	PGCRHandlersNames.Insert("BeforeExport");
	PGCRHandlersNames.Insert("OnExport");
	PGCRHandlersNames.Insert("AfterExport");
	
	PGCRHandlersNames.Insert("BeforeProcessExport");
	PGCRHandlersNames.Insert("AfterProcessExport");
	
	// DER handlers.
	DERHandlersNames = New Structure;
	DERHandlersNames.Insert("BeforeProcess");
	DERHandlersNames.Insert("AfterProcess");
	DERHandlersNames.Insert("BeforeExport");
	DERHandlersNames.Insert("AfterExport");
	
	// DPR handlers.
	DPRHandlersNames = New Structure;
	DPRHandlersNames.Insert("BeforeProcess");
	DPRHandlersNames.Insert("AfterProcess");
	DPRHandlersNames.Insert("BeforeDeleteRow");
	
	// 
	HandlersNames = New Structure;
	HandlersNames.Insert("Conversion", ConversionHandlersNames); 
	HandlersNames.Insert("OCR",         OCRHandlersNames); 
	HandlersNames.Insert("PCR",         PCRHandlersNames); 
	HandlersNames.Insert("PGCR",        PGCRHandlersNames); 
	HandlersNames.Insert("DER",         DERHandlersNames); 
	HandlersNames.Insert("DPR",         DPRHandlersNames); 
	
EndProcedure  

// Returns:
//   Structure - 
//     * Name - String
//     * TypeName - String
//     * RefTypeString1 - String
//     * Manager - Arbitrary
//     * MetadataObjectsList - MetadataObject
//     * SearchByPredefinedItemsPossible - Boolean
//     * OCR - Arbitrary
//
Function ManagerParametersStructure(Name, TypeName, RefTypeString1, Manager, MetadataObjectsList)
	Structure = New Structure();
	Structure.Insert("Name", Name);
	Structure.Insert("TypeName", TypeName);
	Structure.Insert("RefTypeString1", RefTypeString1);
	Structure.Insert("Manager", Manager);
	Structure.Insert("MetadataObjectsList", MetadataObjectsList);
	Structure.Insert("SearchByPredefinedItemsPossible", False);
	Structure.Insert("OCR");
	Return Structure;
EndFunction

Function ExchangePlanParametersStructure(Name, RefType, IsReferenceType, IsRegister)
	Structure = New Structure();
	Structure.Insert("Name",Name);
	Structure.Insert("RefType",RefType);
	Structure.Insert("IsReferenceType",IsReferenceType);
	Structure.Insert("IsRegister",IsRegister);
	Return Structure;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone mode support.

Function SubsystemExists(FullSubsystemName) Export
	
	SubsystemsNames = SubsystemsNames();
	Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

Function SubsystemsNames() Export
	
	Return New FixedMap(SubordinateSubsystemsNames(Metadata));
	
EndFunction

Function SubordinateSubsystemsNames(ParentSubsystem)
	
	Names = New Map;
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		Names.Insert(CurrentSubsystem.Name, True);
		SubordinatesNames = SubordinateSubsystemsNames(CurrentSubsystem);
		
		For Each SubordinateFormName In SubordinatesNames Do
			Names.Insert(CurrentSubsystem.Name + "." + SubordinateFormName.Key, True);
		EndDo;
	EndDo;
	
	Return Names;
	
EndFunction

Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("en = 'Common module ""%1"" is not found.';"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

Procedure MessageToUser(MessageToUserText) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Message();
	
EndProcedure

Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
	
EndFunction

Function IsExternalDataProcessor()
	
	Return ?(StrFind(EventHandlerExternalDataProcessorFileName, ".") <> 0, True, False);
	
EndFunction

Function PredefinedItemName(Ref)
	
	QueryText =
	"SELECT
	|	SpecifiedTableAlias.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&MetadataTableName AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref";
	
	QueryText = StrReplace(QueryText, "&MetadataTableName", Ref.Metadata().FullName());
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.PredefinedDataName;
	
EndFunction

Function RefTypeValue(Value)
	
	Type = TypeOf(Value);
	
	Return Type <> Type("Undefined") 
		And (Catalogs.AllRefsType().ContainsType(Type)
		Or Documents.AllRefsType().ContainsType(Type)
		Or Enums.AllRefsType().ContainsType(Type)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		Or ChartsOfAccounts.AllRefsType().ContainsType(Type)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		Or Tasks.AllRefsType().ContainsType(Type)
		Or ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

Function DefaultLanguageCode()
	If SubsystemExists("StandardSubsystems.Core") Then
		ModuleCommon = CommonModule("Common");
		Return ModuleCommon.DefaultLanguageCode();
	EndIf;
	Return Metadata.DefaultLanguage.LanguageCode;
EndFunction

#EndRegion

#EndRegion

#Region Initialization

InitAttributesAndModuleVariables();
SupplementInternalTablesWithColumns();
InitHandlersNamesStructure();

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf