///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Version = "3.1.5.231";
	Handler.Procedure = "Catalogs.PrintFormsLanguages.FillInTheSuppliedLanguages";
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

Procedure AddPrintFormsLanguages(LanguagesCodes) Export
	
	Catalogs.PrintFormsLanguages.AddLanguages(LanguagesCodes);
	
EndProcedure

Function AvailableLanguages(WithRegionalSettings = False) Export
	
	Return Catalogs.PrintFormsLanguages.AvailableLanguages(WithRegionalSettings);
	
EndFunction

Function AdditionalLanguagesOfPrintedForms() Export
	
	Return Catalogs.PrintFormsLanguages.AdditionalLanguagesOfPrintedForms();
	
EndFunction

Function ItIsAnAdditionalLanguageOfPrintedForms(LanguageCode) Export
	
	Return Catalogs.PrintFormsLanguages.ItIsAnAdditionalLanguageOfPrintedForms(LanguageCode);
	
EndFunction

Function LanguagePresentation(LanguageCode) Export
	
	Return NationalLanguageSupportServer.LanguagePresentation(LanguageCode);
	
EndFunction

Function LayoutLanguages(TemplatePath) Export
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Template ""%1"" does not exist. The operation is canceled.';"), TemplatePath);
	PathParts = StrSplit(TemplatePath, ".", True);
	
	PrintFormsLanguages = AvailableLanguages();
	Id = PathParts[PathParts.UBound()];
	
	If StrStartsWith(Id, "PF_") Then
		Id = Mid(Id, 4);
		If StringFunctionsClientServer.IsUUID(Id) Then
			LayoutLanguages = Catalogs.PrintFormTemplates.LayoutLanguages(New UUID(Id));
			If Not ValueIsFilled(LayoutLanguages) Then
				Raise ErrorText;
			EndIf;

			Result = New Array;
			For Each LanguageCode In PrintFormsLanguages Do
				If LayoutLanguages.Find(LanguageCode) <> Undefined Then
					Result.Add(LanguageCode);
				EndIf;
			EndDo;
			
			Return Result;
		EndIf;
	EndIf;
	
	If PathParts.Count() <> 2 And PathParts.Count() <> 3 Then
		Raise ErrorText;
	EndIf;
	
	TemplateName = PathParts[PathParts.UBound()];
	PathParts.Delete(PathParts.UBound());
	ObjectName = StrConcat(PathParts, ".");
	
	For Each LanguageCode In PrintFormsLanguages Do
		If StrEndsWith(TemplateName, "_" + LanguageCode) Then
			TemplateName = Left(TemplateName, StrLen(TemplateName) - StrLen(LanguageCode) - 1);
			Break;
		EndIf;
	EndDo;
	
	QueryText = 
	"SELECT
	|	UserPrintTemplates.TemplateName AS TemplateName
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|WHERE
	|	UserPrintTemplates.Object = &Object
	|	AND UserPrintTemplates.TemplateName LIKE &LayoutNameTemplate ESCAPE ""~""
	|	AND UserPrintTemplates.Use";
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("Object", ObjectName);
	Query.Parameters.Insert("LayoutNameTemplate", Common.GenerateSearchQueryString(TemplateName) + "_%");
	
	Selection = Query.Execute().Select();
	FoundLanguages = New Map;
	
	While Selection.Next() Do
		For Each LanguageCode In PrintFormsLanguages Do
			LocalizationCode = LanguageCode;
			If StrEndsWith(Selection.TemplateName, "_" + LocalizationCode) Then
				FoundLanguages.Insert(LocalizationCode, True);
				Continue;
			EndIf;
		EndDo;
	EndDo;
	
	SearchNames = New Map;
	For Each LanguageCode In AdditionalLanguagesOfPrintedForms() Do
		SearchNames.Insert(LanguageCode, TemplateName + "_" + LanguageCode);
	EndDo;
	
	IsCommonTemplate = StrSplit(ObjectName, ".").Count() = 1;
	
	TemplatesCollection = Metadata.CommonTemplates;
	If Not IsCommonTemplate Then
		MetadataObject = Common.MetadataObjectByFullName(ObjectName);
		If MetadataObject = Undefined Then
			Raise ErrorText;
		EndIf;
		TemplatesCollection = MetadataObject.Templates;
	EndIf;
	
	For Each Item In SearchNames Do
		SearchName = Item.Value;
		LanguageCode = Item.Key;
		If TemplatesCollection.Find(SearchName) <> Undefined Then
			FoundLanguages.Insert(LanguageCode, True);
		EndIf;
	EndDo;
	
	For Each LanguageCode In StandardSubsystemsServer.ConfigurationLanguages() Do
		FoundLanguages.Insert(LanguageCode, True);
	EndDo;
	
	Result = New Array;
	For Each LanguageCode In PrintFormsLanguages Do
		If FoundLanguages[LanguageCode] <> Undefined Then
			Result.Add(LanguageCode);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function RepresentationOfLayoutLanguages(TemplateMetadataObjectName) Export
	
	LanguagesPresentations = New Array;
	For Each LanguageCode In LayoutLanguages(TemplateMetadataObjectName) Do
		If ItIsAnAdditionalLanguageOfPrintedForms(LanguageCode) Then
			LanguagesPresentations.Add(LanguagePresentation(LanguageCode));
		EndIf;
	EndDo;
	
	Return StrConcat(LanguagesPresentations, ", ");
	
EndFunction

// Parameters:
//   LanguagesSet - ValueTable:
//    * LanguageCode - String
//    * Presentation - String
//    * Suffix - String
//
Procedure WhenFillingInASetOfLanguages(LanguagesSet) Export
	
	LanguagesPresentations = New Map;
	For Each ConfigurationLanguage In Metadata.Languages Do
		LanguagesPresentations.Insert(ConfigurationLanguage.LanguageCode, ConfigurationLanguage.Presentation());
	EndDo;
	
	For Each LanguageCode In AvailableLanguages() Do
		NewLanguage = LanguagesSet.Add();
		NewLanguage.LanguageCode = LanguageCode;
		LanguagePresentation = LanguagesPresentations[LanguageCode];
		If Not ValueIsFilled(LanguagePresentation) Then
			LanguagePresentation = LanguagePresentation(LanguageCode);
		EndIf;
		NewLanguage.Presentation = LanguagePresentation;
	EndDo;
	
EndProcedure

Function AdditionalLanguagesOfPrintedFormsAreUsed() Export
	
	Return Catalogs.PrintFormsLanguages.AdditionalLanguagesOfPrintedForms().Count() > 0
	
EndFunction

// Parameters:
//   Form - ClientApplicationForm:
//     * Items - FormAllItems:
//       ** Language - FormGroup 
//   CurrentLanguage - String
//   Filter - Array of String
//
Procedure FillInTheLanguageSubmenu(Form, CurrentLanguage = Undefined, Val Filter = Undefined) Export
	
	UseRegionalLanguageRepresentations = True; // 
	If Filter = Undefined Then
		Filter = AvailableLanguages();
		UseRegionalLanguageRepresentations = False; // 
	EndIf;
	
	If Not ValueIsFilled(CurrentLanguage) Then
		CurrentLanguage = Common.DefaultLanguageCode();
		If Filter.Find(CurrentLanguage) = Undefined Then
			For Each LanguageCode In Filter Do
				If StrStartsWith(LanguageCode, CurrentLanguage) Then
					CurrentLanguage = LanguageCode;
					Break;
				EndIf;
			EndDo;
			If ValueIsFilled(Filter) Then
				CurrentLanguage = Filter[0];
			EndIf;
		EndIf;
	EndIf;
	
	Items = Form.Items;
	Commands = Form.Commands;
	
	If Filter.Count() < 2 Then
		Return;
	EndIf;

	Form.CurrentLanguage = CurrentLanguage;
	AvailableLanguages = AvailableLanguages(UseRegionalLanguageRepresentations);
		
	IsEditorForm = StrStartsWith(Form.FormName, "CommonForm.Edit");		
		
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then
		
		If IsEditorForm Then
			Items.Language.Title = "";
			If ValueIsFilled(Form.IdentifierOfTemplate) Then
				LayoutLanguages = LayoutLanguages(Form.IdentifierOfTemplate);
			ElsIf ValueIsFilled(Form.IDOfTemplateBeingCopied) Then
				LayoutLanguages = LayoutLanguages(Form.IDOfTemplateBeingCopied);
			Else
				LayoutLanguages = New Array;
				LayoutLanguages.Add(Common.DefaultLanguageCode());
			EndIf;
			Form.TemplateSavedLangs.LoadValues(LayoutLanguages);
		ElsIf StrStartsWith(Form.FormName, "CommonForm.PrintDocuments") Then
			Items.Language.Title = "";
			LayoutLanguages = New Array(New FixedArray(AvailableLanguages));
		Else
			Items.Language.Title = "";
			LayoutLanguages = New Array;
		EndIf;
	EndIf;
	
	For Each LocalizationCode In AvailableLanguages Do
		LanguageCode = StrSplit(LocalizationCode, "_", True)[0];
		If Filter.Find(LanguageCode) = Undefined Then
			Continue;
		EndIf;
		
		LanguagePresentation = LanguagePresentation(LocalizationCode);
		If Not ValueIsFilled(Items.Language.Title) And LanguageCode = CurrentLanguage Then
			Items.Language.Title = LanguagePresentation;
		EndIf;
		
		Command = Commands.Add("Language_" + LocalizationCode);
		Command.Action = "Attachable_SwitchLanguage";
		Command.Title = LanguagePresentation;
		
		TemplateInCurrLang = LayoutLanguages.Find(LanguageCode) <> Undefined;
		
		FormButton = Items.Add(Command.Name, Type("FormButton"), Items.Language);
		FormButton.Type = FormButtonType.CommandBarButton;
		FormButton.Check = LanguageCode = CurrentLanguage;
		FormButton.CommandName = Command.Name;
		FormButton.Title = LanguagePresentation;
		FormButton.LocationInCommandBar = ?(IsMobileClient, 
			ButtonLocationInCommandBar.InAdditionalSubmenu, ButtonLocationInCommandBar.InCommandBar);
		FormButton.Visible = TemplateInCurrLang Or Not IsEditorForm;
		
		If IsEditorForm Then
			Command = Commands.Add("AddLanguage_" + LocalizationCode);
			Command.Action = "Attachable_SwitchLanguage";
			Command.Title = NStr("en = 'Add:';") + " " + LanguagePresentation;
			
			FormButton = Items.Add(Command.Name, Type("FormButton"), Items.LangsToAdd);
			FormButton.Type = FormButtonType.CommandBarButton;
			FormButton.CommandName = Command.Name;
			FormButton.Title = NStr("en = 'Add:';") + " " + LanguagePresentation;
			FormButton.LocationInCommandBar= ?(IsMobileClient, 
			ButtonLocationInCommandBar.InAdditionalSubmenu, ButtonLocationInCommandBar.InCommandBar);
			FormButton.Visible = Not TemplateInCurrLang;
		EndIf;
	EndDo;
	
EndProcedure

Function AutomaticTranslationAvailable(LanguageCode) Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
		ModuleTranslationOfTextIntoOtherLanguages = Common.CommonModule("TextTranslationTool");
		Return ItIsAnAdditionalLanguageOfPrintedForms(LanguageCode) And ModuleTranslationOfTextIntoOtherLanguages.TextTranslationAvailable();
	EndIf;
	
	Return False;
	
EndFunction

Function AvailableforTranslationLayouts() Export
	
	Templates = New Array;
	PrintManagementNationalLanguageSupportOverridable.WhenDefiningAvailableForTranslationLayouts(Templates);
	
	Result = New Map;
	For Each Template In Templates Do
		Result.Insert(Template, True);
	EndDo;
	
	Return Result;

EndFunction

Function AvailableTranslationLayout(TemplatePath) Export
	
	ObjectMetadataLayout = PrintManagement.ObjectMetadataLayout(TemplatePath);
	If ObjectMetadataLayout = Undefined Then
		Return True;
	EndIf;
	
	Return AvailableforTranslationLayouts()[ObjectMetadataLayout] = True;
	
EndFunction

// See PrintManagementOverridable.OnDefinePrintDataSources
Procedure OnDefinePrintDataSources(Object, PrintDataSources) Export
	
	StringParts1 = StrSplit(Object, ".", True);
	If StringParts1.Count() = 3 Then
		AttributeName = StringParts1[StringParts1.UBound()];
		StringParts1.Delete(StringParts1.UBound());
		MetadataObjectName = StrConcat(StringParts1, ".");
		MetadataObject = Common.MetadataObjectByFullName(MetadataObjectName);
		
		MultilingualObjectAttributes = NationalLanguageSupportServer.MultilingualObjectAttributes(MetadataObject);
		If MultilingualObjectAttributes[AttributeName] = True Then
			PrintDataSources.Add(SchemaDataPrintingMultilanguageRequisites(), "DataPrintMultilingualRequisites");
		EndIf;
	EndIf;
	
EndProcedure

// See PrintManagementOverridable.WhenPreparingPrintData
Procedure WhenPreparingPrintData(DataSources, ExternalDataSets, DataCompositionSchemaId, LanguageCode,
	AdditionalParameters) Export

	If DataCompositionSchemaId = "DataPrintMultilingualRequisites" Then
		AdditionalParameters.SourceDataGroupedByDataSourceOwner = True;
		ExternalDataSets.Insert("Data", DataPrintMultilingualRequisites(AdditionalParameters.DataSourceDescriptions));
		Return;
	EndIf;
	
EndProcedure

Procedure TranslateOfficeDoc(TemplateFileAddress, TranslationLanguage, SourceLanguage) Export
	
	OfficeDocument = GetFromTempStorage(TemplateFileAddress);

	TreeOfTemplate = PrintManagement.InitializeTemplateOfDCSOfficeDoc(OfficeDocument);
	
	DocumentRoot = TreeOfTemplate.DocumentStructure.DocumentTree.Rows[0]; 
	
	TranslateOfficeDocTree(DocumentRoot, TranslationLanguage, SourceLanguage);
	
	For Each HeaderOrFooter In TreeOfTemplate.DocumentStructure.HeaderFooter Do
		HeaderOrFooterRoot = HeaderOrFooter.Value.Rows[0];
		TranslateOfficeDocTree(HeaderOrFooterRoot, TranslationLanguage, SourceLanguage);
	EndDo;
		
	PrintManagement.GetPrintForm(TreeOfTemplate, TemplateFileAddress);
	
EndProcedure

#EndRegion

#Region Private

Function SchemaDataPrintingMultilanguageRequisites()
	
	FieldList = PrintManagement.PrintDataFieldTable();
	
	Field = FieldList.Add();
	Field.Id = "Ref";
	Field.Presentation = NStr("en = 'Ref';");
	Field.ValueType = New TypeDescription();	

	AvailableLanguages = AvailableLanguages();
	For IndexOf = 0 To AvailableLanguages.UBound() Do
		LanguageCode = AvailableLanguages[IndexOf];
		Field = FieldList.Add();
		Field.Id = LanguageCode;
		Field.Presentation = LanguagePresentation(LanguageCode);
		Field.ValueType = New TypeDescription("String");
		Field.Order = IndexOf + 1;
	EndDo;
	
	Return PrintManagement.SchemaCompositionDataPrint(FieldList);
	
EndFunction

Function DataPrintMultilingualRequisites(DataSourceDescriptions)
	AvailableLanguages();
	
	DataSources = DataSourceDescriptions.UnloadColumn("Owner");
	DataSources = CommonClientServer.CollapseArray(DataSources);
	For IndexOf = -DataSources.UBound() To 0 Do
		If DataSources[-IndexOf] = Undefined Then
			DataSources.Delete(-IndexOf);
		EndIf;
	EndDo;
	
	AttributesNames = DataSourceDescriptions.UnloadColumn("Name");
	AttributesNames = CommonClientServer.CollapseArray(AttributesNames);
	
	AttributesValues = New Map();
	
	AvailableLanguages= AvailableLanguages();
	
	PrintData = New ValueTable();
	PrintData.Columns.Add("Ref");
	
	For Each LanguageCode In AvailableLanguages Do
		PrintData.Columns.Add(LanguageCode, New TypeDescription("String"));
		AttributesValues.Insert(LanguageCode, Common.ObjectsAttributesValues(DataSources, AttributesNames, , LanguageCode));
	EndDo;
	
	For Each DataSource In DataSources Do
		For Each AttributeName In AttributesNames Do
			NewRow = PrintData.Add();
			NewRow.Ref = DataSource;

			For Each LanguageCode In AvailableLanguages Do
				NewRow[LanguageCode] = AttributesValues[LanguageCode][DataSource][AttributeName];
			EndDo;
		EndDo;
	EndDo;
	
	Return PrintData;
	
EndFunction

Procedure TranslateOfficeDocTree(DocumentRoot, TranslationLanguage, SourceLanguage)
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		TextsNodes = ModulePrintManager.GetTextsNodes(DocumentRoot);
		
		TextsForTranslation = New Array;
		NodesToTexts = New Map();
				
		For Each NodeOfText In TextsNodes Do
			
			TextOfNodeWithoutParameters = RemovePlaceholdersFromOfficeDocText(NodeOfText.Value).Text;
			
			TextsForTranslation.Add(TextOfNodeWithoutParameters);
			
			TextMapping = NodesToTexts.Get(TextOfNodeWithoutParameters);
			If TextMapping = Undefined Then
				TextMapping = New Array();
			EndIf;
			
			TextMapping.Add(NodeOfText);
			NodesToTexts.Insert(TextOfNodeWithoutParameters, TextMapping);
				
		EndDo;		 
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.TextTranslation") Then
			ModuleTranslationOfTextIntoOtherLanguages = Common.CommonModule("TextTranslationTool");
			Transfers = ModuleTranslationOfTextIntoOtherLanguages.TranslateTheTexts(TextsForTranslation, TranslationLanguage, SourceLanguage);
		EndIf;
		
		For Each Translation In Transfers Do
			For Each NodeToReplace In NodesToTexts[Translation.Key] Do
				
				ProcessingResult = RemovePlaceholdersFromOfficeDocText(NodeToReplace.Key.Text);
				NodeToReplace.Key.Text = ReturnParametersToText(Translation.Value, ProcessingResult.Parameters);
					
			EndDo;
		EndDo;
	EndIf;
EndProcedure

Function RemovePlaceholdersFromOfficeDocText(Val Text)
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		TheProcessedParameters = New Array;
		
		Counter = 0;
		
		ArrayOfConditionsStrings = StrSplit(Text, "{");
		For Each ConditionString_ In ArrayOfConditionsStrings Do
			FoundConditionPosition = StrFind(ConditionString_, TagNameCondition());
			If FoundConditionPosition And FoundConditionPosition < 3 Then
				Parameter = "{"+StrSplit(ConditionString_, "}")[0]+"}";
				Counter = Counter + 1;
				Text = StrReplace(Text, Parameter, ParameterId(Counter));
				TheProcessedParameters.Add(Parameter);
			EndIf;
		EndDo;
		
		TheParametersOfThe = ModulePrintManager.FindParametersInText(Text);
		
		For Each Parameter In TheParametersOfThe Do
			If StrFind(Text, Parameter) Then
				Counter = Counter + 1;
				Text = StrReplace(Text, Parameter, ParameterId(Counter));
				TheProcessedParameters.Add(Parameter);
			EndIf;
		EndDo;
		
		If StrFind(Text, TagNameCondition()) Then
			Counter = Counter + 1;
			Text = StrReplace(Text, TagNameCondition(), ParameterId(Counter));
			TheProcessedParameters.Add(TagNameCondition());
		EndIf;
		
		
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

Function TagNameCondition()
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClientServer = Common.CommonModule("PrintManagementClientServer");
		Return ModulePrintManagerClientServer.TagNameCondition();
	Else
		Return "";
	EndIf;
EndFunction


#EndRegion