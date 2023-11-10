///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Gets the name of the additional property that shows whether priority check is skipped when writing key operations.
//
// Returns:
//  String - 
//
Function DoNotCheckPriority() Export
	
	Return "DoNotCheckPriority";
	
EndFunction

// Key of the scheduled job parameter for the local export directory.
//
Function LocalExportDirectoryJobKey() Export
	
	Return "LocalExportDirectory";
	
EndFunction

// Returns scheduled job parameter key that corresponds to the export FTP directory
//
Function FTPExportDirectoryJobKey() Export
	
	Return "FTPExportDirectory";
	
EndFunction

#Region CommonClientServerCopy

// Splits the URI string and returns it as a structure.
// The following normalizations are described based on RFC 3986.
//
// Parameters:
//     URIString1 - String - link to the resource in the following format:
//                          <schema>://<username>:<password>@<host>:<port>/<path>?<parameters>#<anchor>.
//
// Returns:
//     Structure - 
//         * Schema         - String
//         * Login         - String
//         * Password        - String
//         * ServerName    - String - part <host>:<port> of the input parameter.
//         * Host          - String
//         * Port          - String
//         * PathAtServer - String - part <path>?<parameters>#<anchor> of the input parameter.
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
	Position = StrFind(ConnectionString, "@");
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
		If Not OnlyNumbersInString(Port) Then
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

// Adds a composition item into a composition item container.
//
// Parameters:
//  AreaToAddTo - 
//                  
//  FieldName                 - String - a data composition field name. Required.
//  RightValue          - Arbitrary - the value to compare to.
//  ComparisonType            - DataCompositionComparisonType - a comparison type.
//  Presentation           - String - presentation of the data composition item.
//  Use           - Boolean - item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID
//                                                    in Syntax Assistant.
//
Function AddCompositionItem(AreaToAddTo,
									Val FieldName,
									Val Var_ComparisonType,
									Val RightValue = Undefined,
									Val Presentation  = Undefined,
									Val Use  = Undefined,
									Val ViewMode = Undefined,
									Val UserSettingID = Undefined)
	
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
//  FieldName                 - String - a data composition field name. Required.
//  Presentation           - String - presentation of the data composition item.
//  RightValue          - Arbitrary - the value to compare to.
//  Var_ComparisonType            - DataCompositionComparisonType - comparison type.
//  Use           - Boolean - item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - the item display mode.
//
Function ChangeFilterItems(SearchArea,
								Val FieldName = Undefined,
								Val Presentation = Undefined,
								Val RightValue = Undefined,
								Val Var_ComparisonType = Undefined,
								Val Use = Undefined,
								Val ViewMode = Undefined,
								Val UserSettingID = Undefined)
	
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

// Adds or replaces the existing filter item.
//
// Parameters:
//  WhereToAdd - 
//                  
//  FieldName                 - String - a data composition field name. Required.
//  RightValue          - Arbitrary - the value to compare to.
//  Var_ComparisonType            - DataCompositionComparisonType - comparison type.
//  Presentation           - String - presentation of the data composition item.
//  Use           - Boolean - item usage.
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
//   ViewMode - DataCompositionSettingsItemViewMode - the filter display mode:
//       QuickAccess - in the Quick Settings bar on top of the list;
//       Normal       - in the list settings (submenu More);
//       Inaccessible   - prevent users from changing the filter.
//   UserSettingID - String - the filter UUID.
//       Used to link user settings.
//
// See also:
//   Same name properties of the DataCompositionFilterItem item in the syntax assistant.
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

#Region StringFunctionsClientServerCopy

// Checks whether the string contains numeric characters only.
//
// Parameters:
//  CheckString          - String - a string to check.
//  IncludingLeadingZeros - Boolean - if True, ignore leading zeros.
//  IncludingSpaces        - Boolean - if True, ignore spaces.
//
// Returns:
//   Boolean - 
//
Function OnlyNumbersInString(Val CheckString, Val IncludingLeadingZeros = True, Val IncludingSpaces = True)
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not IncludingSpaces Then
		CheckString = StrReplace(CheckString, " ", "");
	EndIf;
		
	If IsBlankString(CheckString) Then
		Return True;
	EndIf;
	
	If Not IncludingLeadingZeros Then
		Position = 1;
		// If an out-of-border symbol is taken, an empty string is returned.
		While Mid(CheckString, Position, 1) = "0" Do
			Position = Position + 1;
		EndDo;
		CheckString = Mid(CheckString, Position);
	EndIf;
	
	// 
	// 
	Return StrLen(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace( 
			CheckString, "0", ""), "1", ""), "2", ""), "3", ""), "4", ""), "5", ""), "6", ""), "7", ""), "8", ""), "9", "")) = 0;
	
EndFunction

// Checks whether the string contains Cyrillic characters only.
//
// Parameters:
//  WithWordSeparators - Boolean - if True, treat word separators as legit characters.
//  AllowedChars - string to check.
//
// Returns:
//  Boolean - 
//           
//
Function OnlyLatinInString(Val CheckString, Val WithWordSeparators = True, AllowedChars = "") Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CheckString) Then
		Return True;
	EndIf;
	
	ValidCharCodes = New Array;
	ValidCharCodes.Add(1105); // "ё"
	ValidCharCodes.Add(1025); // "Ё"
	
	For IndexOf = 1 To StrLen(AllowedChars) Do
		ValidCharCodes.Add(CharCode(Mid(AllowedChars, IndexOf, 1)));
	EndDo;
	
	For IndexOf = 1 To StrLen(CheckString) Do
		CharCode = CharCode(Mid(CheckString, IndexOf, 1));
		If ((CharCode < 1040) Or (CharCode > 1103)) 
			And (ValidCharCodes.Find(CharCode) = Undefined) 
			And Not (Not WithWordSeparators And IsWordSeparator(CharCode)) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Checks whether the string contains Latin characters only.
//
// Parameters:
//  WithWordSeparators - Boolean - if True, treat word separators as legit characters.
//  AllowedChars - String - for check.
//
// Returns:
//  Boolean - 
//           
//
Function OnlyRomanInString(Val CheckString, Val WithWordSeparators = True, AllowedChars = "") Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CheckString) Then
		Return True;
	EndIf;
	
	ValidCharCodes = New Array;
	
	For IndexOf = 1 To StrLen(AllowedChars) Do
		ValidCharCodes.Add(CharCode(Mid(AllowedChars, IndexOf, 1)));
	EndDo;
	
	For IndexOf = 1 To StrLen(CheckString) Do
		CharCode = CharCode(Mid(CheckString, IndexOf, 1));
		If ((CharCode < 65) Or (CharCode > 90 And CharCode < 97) Or (CharCode > 122))
			And (ValidCharCodes.Find(CharCode) = Undefined) 
			And Not (Not WithWordSeparators And IsWordSeparator(CharCode)) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Determines whether the character is a separator.
//
// Parameters:
//  CharCode      - Number  - code of the char to check;
//  WordSeparators - String - separator characters.
//
// Returns:
//  Boolean - 
//
Function IsWordSeparator(CharCode, WordSeparators = Undefined)
	
	If WordSeparators <> Undefined Then
		Return StrFind(WordSeparators, Char(CharCode)) > 0;
	EndIf;
		
	Ranges = New Array;
	Ranges.Add(New Structure("Min,Max", 48, 57)); 		// цифры
	Ranges.Add(New Structure("Min,Max", 65, 90)); 		// 
	Ranges.Add(New Structure("Min,Max", 97, 122)); 		// 
	Ranges.Add(New Structure("Min,Max", 1040, 1103)); 	// кириллица
	Ranges.Add(New Structure("Min,Max", 1025, 1025)); 	// 
	Ranges.Add(New Structure("Min,Max", 1105, 1105)); 	// 
	Ranges.Add(New Structure("Min,Max", 95, 95)); 		// 
	
	For Each Span In Ranges Do
		If CharCode >= Span.Min And CharCode <= Span.Max Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Substitutes parameters in a string. The maximum number of parameters is 9.
// Parameters in the string have the following format: %<parameter number>. The parameter numbering starts from 1.
//
// Parameters:
//  StringPattern  - String - string pattern with parameters formatted as "%<parameter number>", 
//                           e.g. "%1 went to %2");
//  Parameter<n>   - String - parameter value to insert.
//
// Returns:
//  String   - 
//
// Example:
//  StringFunctionsClientServer.SubstituteParametersToString(NStr("en='%1 went to %2'"), "Jane", "the zoo") = "Jane went
//  to the zoo".
//
Function SubstituteParametersToString(Val StringPattern,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	
	HasParametersWithPercentageChar = StrFind(Parameter1, "%")
		Or StrFind(Parameter2, "%")
		Or StrFind(Parameter3, "%")
		Or StrFind(Parameter4, "%")
		Or StrFind(Parameter5, "%")
		Or StrFind(Parameter6, "%")
		Or StrFind(Parameter7, "%")
		Or StrFind(Parameter8, "%")
		Or StrFind(Parameter9, "%");
		
	If HasParametersWithPercentageChar Then
		Return SubstituteParametersWithPercentageChar(StringPattern, Parameter1,
			Parameter2, Parameter3, Parameter4, Parameter5, Parameter6, Parameter7, Parameter8, Parameter9);
	EndIf;
	
	StringPattern = StrReplace(StringPattern, "%1", Parameter1);
	StringPattern = StrReplace(StringPattern, "%2", Parameter2);
	StringPattern = StrReplace(StringPattern, "%3", Parameter3);
	StringPattern = StrReplace(StringPattern, "%4", Parameter4);
	StringPattern = StrReplace(StringPattern, "%5", Parameter5);
	StringPattern = StrReplace(StringPattern, "%6", Parameter6);
	StringPattern = StrReplace(StringPattern, "%7", Parameter7);
	StringPattern = StrReplace(StringPattern, "%8", Parameter8);
	StringPattern = StrReplace(StringPattern, "%9", Parameter9);
	Return StringPattern;
	
EndFunction

// Substitutes parameters in the string for %1, %2, and so on.
Function SubstituteParametersWithPercentageChar(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined)
	
	Result = "";
	Position = StrFind(SubstitutionString, "%");
	While Position > 0 Do 
		Result = Result + Left(SubstitutionString, Position - 1);
		CharAfterPercentage = Mid(SubstitutionString, Position + 1, 1);
		ParameterToSubstitute = Undefined;
		If CharAfterPercentage = "1" Then
			ParameterToSubstitute = Parameter1;
		ElsIf CharAfterPercentage = "2" Then
			ParameterToSubstitute = Parameter2;
		ElsIf CharAfterPercentage = "3" Then
			ParameterToSubstitute = Parameter3;
		ElsIf CharAfterPercentage = "4" Then
			ParameterToSubstitute = Parameter4;
		ElsIf CharAfterPercentage = "5" Then
			ParameterToSubstitute = Parameter5;
		ElsIf CharAfterPercentage = "6" Then
			ParameterToSubstitute = Parameter6;
		ElsIf CharAfterPercentage = "7" Then
			ParameterToSubstitute = Parameter7
		ElsIf CharAfterPercentage = "8" Then
			ParameterToSubstitute = Parameter8;
		ElsIf CharAfterPercentage = "9" Then
			ParameterToSubstitute = Parameter9;
		EndIf;
		If ParameterToSubstitute = Undefined Then
			Result = Result + "%";
			SubstitutionString = Mid(SubstitutionString, Position + 1);
		Else
			Result = Result + ParameterToSubstitute;
			SubstitutionString = Mid(SubstitutionString, Position + 2);
		EndIf;
		Position = StrFind(SubstitutionString, "%");
	EndDo;
	Result = Result + SubstitutionString;
	
	Return Result;
EndFunction

#EndRegion

#EndRegion
