///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Translates a text into another language using the text translation service.
//
// Parameters:
//  Text        - String - free text about the item.
//  TranslationLanguage - String - the language code in ISO 639-1 format, into which translation is executed.
//                          For example, "de".
//                          If not specified, translation is executed into the current language.
//  SourceLanguage - String - the language code in ISO 639-1 format, from which translation is executed.
//                          For example, "en".
//                          If not specified, the language will be set by the text translation service.
//
// Returns:
//  String
//
Function TranslateText(Text, TranslationLanguage = Undefined, SourceLanguage = Undefined) Export
	
	If Not ValueIsFilled(Text) Then
		Return Text;
	EndIf;
	
	Return TranslateTheTexts(CommonClientServer.ValueInArray(Text), TranslationLanguage, SourceLanguage)[Text];
	
EndFunction

// Translates texts into another language using the text translation service.
//
// Parameters:
//  Texts - Array of String - arbitrary texts.
//  TranslationLanguage - String - the language code in ISO 639-1 format, into which translation is executed.
//                          For example, "de".
//                          If not specified, translation is executed into the current language.
//  SourceLanguage - String - the language code in ISO 639-1 format, from which translation is executed.
//                          For example, "en".
//                          If not specified, the language will be set by the text translation service.
//
// Returns:
//  Map of KeyAndValue:
//   * Key     - String - a text.
//   * Value - String - a translation.
//
Function TranslateTheTexts(Texts, TranslationLanguage = Undefined, SourceLanguage = Undefined) Export
	
	CheckSettings();
	
	If ValueIsFilled(SourceLanguage) And TranslationLanguage = SourceLanguage Then
		FoundTranslations = New Map;
		For Each Text In Texts Do
			FoundTranslations.Insert(Text, Text);
		EndDo;
		Return FoundTranslations;
	EndIf;
	
	FoundTranslations = FindATranslationOfTexts(Texts, TranslationLanguage, SourceLanguage);
	
	If Not GetFunctionalOption("UseTextTranslationService") Then
		Return FoundTranslations;
	EndIf;	
	
	TextsRequiringTranslation = New Map;
	TextTranslationServiceModule = TextTranslationServiceModule();
	MaxBatchSize = TextTranslationServiceModule.MaxBatchSize();
	
	For Each Text In Texts Do
		If ValueIsFilled(FoundTranslations[Text]) Then
			Continue;
		EndIf;
		If ValueIsFilled(Text) Then
			TextsRequiringTranslation[Text] = SplitTextByDelimiter(Text, MaxBatchSize, Chars.LF + ".;!?, ");
		EndIf;
	EndDo;
	
	TransferQueue = New Array;
	Batch = New Array;
	PortionSize = 0;
	
	For Each TextDetails In TextsRequiringTranslation Do
		TextFragments = TextDetails.Value;
		For Each Particle In TextFragments Do
			If PortionSize + StrLen(Particle) > MaxBatchSize Then
				TransferQueue.Add(Batch);
				Batch = New Array;
				PortionSize = 0;
			EndIf;
			Batch.Add(Particle);
			PortionSize = PortionSize + StrLen(Particle);
		EndDo;
	EndDo;
	If ValueIsFilled(Batch) Then
		TransferQueue.Add(Batch);
	EndIf;
	
	TranslatedFragments = New Map;
	
	For Each Batch In TransferQueue Do
		Try
			Transfers = TextTranslationServiceModule.TranslateTheTexts(Batch, TranslationLanguage, SourceLanguage);
		Except
			WriteLogEvent(NStr("en = 'Translator';", Common.DefaultLanguageCode()), EventLogLevel.Error,
				Metadata.Enums.TextTranslationServices, Constants.TextTranslationService.Get(), ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			If Users.IsFullUser() Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
					"en = 'Cannot perform the operation. Reason:
					|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			Else
				ErrorText = NStr("en = 'Cannot perform the operation. Contact the Administrator.';");
			EndIf;
			
			Raise ErrorText;
		EndTry;
		For Each Translation In Transfers Do
			SaveTextTranslation(Translation.Key, Translation.Value, SourceLanguage, TranslationLanguage);
			TranslatedFragments.Insert(Translation.Key, Translation.Value);
		EndDo;
	EndDo;
	
	For Each TextDetails In TextsRequiringTranslation Do
		Text = TextDetails.Key;
		TextFragments = TextDetails.Value;

		TranslatedTextParts = New Array;
		For Each Particle In TextFragments Do	
			TranslatedTextParts.Add(TranslatedFragments[Particle]);
		EndDo;
		
		FoundTranslations.Insert(Text, StrConcat(TranslatedTextParts, Chars.LF));
	EndDo;
	
	Return FoundTranslations;
	
EndFunction

// Returns a list of languages available in the text translation service.
//
// Returns:
//  ValueList:
//   * Value - 
//   * Presentation - 
//
Function AvailableLanguages() Export
	
	LanguagesPresentations = New Map;
	For Each LanguageCode In GetAvailableLocaleCodes() Do
		LanguagesPresentations.Insert(LanguageCode, LocaleCodePresentation(LanguageCode));
	EndDo;
	
	Result = New ValueList;
	
	TextTranslationServiceModule = TextTranslationServiceModule();
	If TextTranslationServiceModule = Undefined Then
		Return Result;
	EndIf;
	
	Try
		AvailableLanguages = TextTranslationServiceModule.AvailableLanguages();
	Except
		WriteLogEvent(NStr("en = 'Translator';", Common.DefaultLanguageCode()), EventLogLevel.Error,
			Metadata.Enums.TextTranslationServices, Constants.TextTranslationService.Get(), ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		If Users.IsFullUser() Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
				"en = 'Cannot perform the operation. Reason:
				|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Else
			ErrorText = NStr("en = 'Cannot perform the operation. Contact the Administrator.';");
		EndIf;
		
		Raise ErrorText;
	EndTry;
	
	For Each LanguageCode In AvailableLanguages Do
		Presentation = LanguagesPresentations[LanguageCode];
		If ValueIsFilled(Presentation) Then
			Result.Add(LanguageCode, Title(Presentation));
		EndIf;
	EndDo;
	
	Result.SortByPresentation();
	
	Return Result;
	
EndFunction

#EndRegion

#Region Internal

Function TextTranslationAvailable() Export
	
	Return GetFunctionalOption("UseTextTranslationService");
	
EndFunction

Function TextTranslationService() Export
	
	Return Constants.TextTranslationService.Get();
	
EndFunction

Procedure TranslateSpreadsheetTexts(SpreadsheetDocument, TranslationLanguage, SourceLanguage) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Return;
	EndIf;
	
	CellTexts = New Map;
	
	For LineNumber = 1 To SpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			Area = SpreadsheetDocument.Area(LineNumber, ColumnNumber);
			If ValueIsFilled(Area.Text) Then
				Text = RemoveParametersFromTheText(Area.Text).Text;
				CellTexts.Insert(Text, True);
			EndIf;
		EndDo;
	EndDo;
	
	TextsForTranslation = New Array;
	For Each Item In CellTexts Do
		TextsForTranslation.Add(Item.Key);
	EndDo;
	
	Transfers = TranslateTheTexts(TextsForTranslation, TranslationLanguage, SourceLanguage);
	
	For LineNumber = 1 To SpreadsheetDocument.TableHeight Do
		For ColumnNumber = 1 To SpreadsheetDocument.TableWidth Do
			Area = SpreadsheetDocument.Area(LineNumber, ColumnNumber);
			If ValueIsFilled(Area.Text) Then
				ProcessingResult = RemoveParametersFromTheText(Area.Text);
				Text = ProcessingResult.Text;
				If ValueIsFilled(Transfers[Text]) Then
					Area.Text = ReturnParametersToText(Transfers[Text], ProcessingResult.Parameters);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	For Each ProviderModule In TextTranslationServiceModules() Do
		TextTranslationServiceModule = ProviderModule.Value;
		Permissions = TextTranslationServiceModule.Permissions();
		PermissionsRequest = ModuleSafeModeManager.RequestToUseExternalResources(Permissions);
		PermissionsRequests.Add(PermissionsRequest);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function FindATranslationOfTexts(Texts, TranslationLanguage, SourceLanguage)
	
	TextsForSearch = New Array;
	TextIdentifiers = New Map;
	For Each Text In Texts Do
		TextID = TextID(Text);
		TextsForSearch.Add(TextID);
		TextIdentifiers.Insert(Text, TextID);
	EndDo;
	
	QueryText =
	"SELECT
	|	TranslationCache.Text AS Text,
	|	TranslationCache.Translation AS Translation,
	|	TranslationCache.SourceLanguage AS SourceLanguage
	|FROM
	|	InformationRegister.TranslationCache AS TranslationCache
	|WHERE
	|	TranslationCache.Text IN(&Text)
	|	AND TranslationCache.TranslationLanguage = &TranslationLanguage
	|	AND TranslationCache.SourceLanguage = &SourceLanguage";
	
	Query = New Query(QueryText);
	Query.SetParameter("Text", TextsForSearch);
	Query.SetParameter("TranslationLanguage", TranslationLanguage);
	Query.SetParameter("SourceLanguage", SourceLanguage);
	
	TranslatedTexts = New Map;
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	While Selection.Next() Do
		TranslatedTexts.Insert(Selection.Text, Selection.Translation);
	EndDo;
	
	Result = New Map;
	For Each Text In Texts Do
		If ValueIsFilled(Text) Then
			Result.Insert(Text, TranslatedTexts[TextIdentifiers[Text]]);
		Else
			Result.Insert(Text, Text);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure SaveTextTranslation(Text, Translation, SourceLanguage, TranslationLanguage)
	
	If Not ValueIsFilled(Text) Or Not ValueIsFilled(Translation) Or Not ValueIsFilled(TranslationLanguage) Then
		Return;
	EndIf;
	
	TextID = TextID(Text);
	
	RecordSet = InformationRegisters.TranslationCache.CreateRecordSet();
	RecordSet.Filter.Text.Set(TextID);
	RecordSet.Filter.TranslationLanguage.Set(TranslationLanguage);
	RecordSet.Filter.SourceLanguage.Set(SourceLanguage);
	Record = RecordSet.Add();
	Record.Text = TextID;
	Record.SourceLanguage = SourceLanguage;
	Record.TranslationLanguage = TranslationLanguage;
	Record.Translation = TrimAll(Translation);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.TranslationCache");
	LockItem.SetValue("Text", TextID);
	LockItem.SetValue("SourceLanguage", SourceLanguage);
	LockItem.SetValue("TranslationLanguage", TranslationLanguage);
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function TextID(Val Text)
	
	Return Common.TrimStringUsingChecksum(Lower(TrimAll(Text)), 50);
	
EndFunction

Function LanguagePresentation(LanguageCode) Export
	
	If GetAvailableLocaleCodes().Find(LanguageCode) <> Undefined Then
		Return LocaleCodePresentation(LanguageCode);
	EndIf;
	
	Return "";
	
EndFunction

Function TextTranslationServiceModule(Val TextTranslationService = Undefined)
	
	If TextTranslationService = Undefined Then
		TextTranslationService = Constants.TextTranslationService.Get();
	EndIf;
	
	Return TextTranslationServiceModules()[TextTranslationService];
	
EndFunction

// Module names match value names of the TextTranslationServices enumeration.
Function TextTranslationServiceModules()
	
	Result = New Map;
	
	For Each MetadataObject In Metadata.Enums.TextTranslationServices.EnumValues Do
		ModuleName = MetadataObject.Name;
		If Metadata.CommonModules.Find(ModuleName) <> Undefined Then
			Result.Insert(Enums.TextTranslationServices[MetadataObject.Name], Common.CommonModule(ModuleName));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure CheckSettings()
	
	TextTranslationServiceModule = TextTranslationServiceModule();
	If TextTranslationServiceModule = Undefined Or Not TextTranslationServiceModule.SetupExecuted() Then
		Raise NStr("en = 'Text translation service settings are not specified.';");
	EndIf;
	
EndProcedure

// Returns:
//  Structure:
//   * ConnectionInstructions - String
//   * AuthorizationParameters - See AuthorizationParameters
//
Function TextTranslationServiceSettings(TextTranslationService) Export
	
	Settings = New Structure;
	Settings.Insert("ConnectionInstructions");
	Settings.Insert("AuthorizationParameters", AuthorizationParameters());
	TextTranslationServiceModule(TextTranslationService).OnDefineSettings(Settings);
	
	Return Settings;
	
EndFunction

// Returns:
//  ValueTable:
//   * Name - String
//   * Presentation - String
//   * ToolTip - String
//   * ToolTipRepresentation - ToolTipRepresentation
//
Function AuthorizationParameters()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("Presentation");
	Result.Columns.Add("ToolTip");
	Result.Columns.Add("ToolTipRepresentation", New TypeDescription("ToolTipRepresentation"));
	
	Return Result;
	
EndFunction

Function AuthorizationSettings(Val TextTranslationService = Undefined) Export
	
	TextTranslationServiceModule = TextTranslationServiceModule(TextTranslationService);
	If TextTranslationServiceModule = Undefined Then
		Return Undefined;
	EndIf;
	
	Return TextTranslationServiceModule(TextTranslationService).AuthorizationSettings();
	
EndFunction

Function RemoveParametersFromTheText(Val Text)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		TheParametersOfThe = ModulePrintManager.FindParametersInText(Text);
		TheProcessedParameters = New Array;
		
		Counter = 0;
		For Each Parameter In TheParametersOfThe Do
			If StrFind(Text, Parameter) Then
				Counter = Counter + 1;
				Text = StrReplace(Text, Parameter, ParameterId(Counter));
				TheProcessedParameters.Add(Parameter);
			EndIf;
		EndDo;
		
		Result = New Structure;
		Result.Insert("Text", Text);
		Result.Insert("Parameters", TheProcessedParameters);
		
		Return Result;
	
	EndIf;
	
EndFunction

Function ReturnParametersToText(Val Text, TheProcessedParameters)
	
	For Counter = 1 To TheProcessedParameters.Count() Do
		Text = StrReplace(Text, ParameterId(Counter), "%" + XMLString(Counter));
	EndDo;
	
	Return StringFunctionsClientServer.SubstituteParametersToStringFromArray(Text, TheProcessedParameters);
	
EndFunction

// A sequence of characters that must not change when translated into any language.
Function ParameterId(Number)
	
	Return "{<" + XMLString(Number) + ">}"; 
	
EndFunction

Function SplitTextByDelimiter(Val Text, Val TextPartsMaxSize, Val Separators)
	
	Result = New Array;
	
	Separator = Left(Separators, 1);
	Separators = Mid(Separators, 2);
	
	Particles = New Array;
	PieceOfText = StrSplit(Text, Separator, True);
	
	For IndexOf = 0 To PieceOfText.UBound() Do
		IsLastFragment = IndexOf = PieceOfText.UBound();
		Particle = PieceOfText[IndexOf] + ?(IsLastFragment, "", Separator);
		FragmentSize = StrLen(Particle);
		
		If FragmentSize > TextPartsMaxSize Then
			If Separators <> "" Then
				FragmentParts = SplitTextByDelimiter(Particle, TextPartsMaxSize, Separators);
			Else
				Raise NStr("en = 'Cannot split the text into parts.';");
			EndIf;
			
			For Each Particle In FragmentParts Do
				Particles.Add(Particle);
			EndDo;
		Else
			Particles.Add(Particle);
		EndIf;
	EndDo;

	Batch = New Array;
	PortionSize = 0;
	
	For IndexOf = 0 To Particles.UBound() Do
		Particle = Particles[IndexOf];
		FragmentSize = StrLen(Particle);
		IsLastFragment = IndexOf = Particles.UBound();
		
		If PortionSize + FragmentSize > TextPartsMaxSize Then
			Result.Add(StrConcat(Batch, ""));
			Batch = New Array;
			PortionSize = 0;
		EndIf;

		Batch.Add(Particle);
		PortionSize = PortionSize + FragmentSize;
	EndDo;
	
	If ValueIsFilled(Batch) Then
		Result.Add(StrConcat(Batch, ""));
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
