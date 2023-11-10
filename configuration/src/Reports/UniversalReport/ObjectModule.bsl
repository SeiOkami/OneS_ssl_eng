///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.BeforeLoadVariantAtServer = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.OnDefineSelectionParameters = True;
	Settings.Events.OnDefineSettingsFormItemsProperties = True;
	
	Settings.ImportSchemaAllowed = True;
	Settings.EditSchemaAllowed = True;
	Settings.RestoreStandardSchemaAllowed = True;
	
	Settings.ImportSettingsOnChangeParameters = Reports.UniversalReport.ImportSettingsOnChangeParameters();
EndProcedure

// See ReportsOverridable.OnCreateAtServer
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	EditOptionsAllowed = CommonClientServer.StructureProperty(
		Form.ReportSettings, "EditOptionsAllowed", False);
	
	If EditOptionsAllowed Then
		Form.ReportSettings.SettingsFormAdvancedMode = 1;
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Form.Items, "SelectSettings", "Visible", False);
	CommonClientServer.SetFormItemProperty(Form.Items, "ShouldSaveSettings", "Visible", False);
	CommonClientServer.SetFormItemProperty(Form.Items, "ShareSettings", "Visible", False);
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters.
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	AvailableValues = CommonClientServer.StructureProperty(
		SettingsComposer.Settings.AdditionalProperties, "AvailableValues", New Structure);
	
	Try
		ValuesForSelection = CommonClientServer.StructureProperty(
			AvailableValues, StrReplace(SettingProperties.DCField, "DataParameters.", ""));
	Except
		ValuesForSelection = Undefined;
	EndTry;
	
	If ValuesForSelection <> Undefined Then 
		SettingProperties.RestrictSelectionBySpecifiedValues = True;
		SettingProperties.ValuesForSelection = ValuesForSelection;
	EndIf;
EndProcedure

// Called in the event handler of the report form after executing the form code.
// See "Managed form extension for reports.BeforeLoadOptionAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - report form.
//   Settings - DataCompositionSettings - settings to load into the settings composer.
//   BeforeDownloadingSettings - Boolean -
//
Procedure BeforeLoadVariantAtServer(Form, Settings, BeforeDownloadingSettings = False) Export
	CurrentSchemaKey = Undefined;
	Schema = Undefined;
	
	IsImportedSchema = False;
	
	If TypeOf(Settings) = Type("DataCompositionSettings") Or Settings = Undefined Then
		If Settings = Undefined Then
			AdditionalSettingsProperties = SettingsComposer.Settings.AdditionalProperties;
		Else
			AdditionalSettingsProperties = Settings.AdditionalProperties;
		EndIf;
		IsMainOption = Form.CurrentVariantKey = "Main"
			Or Form.CurrentVariantKey = "Main";
		
		If Form.ReportFormType = ReportFormType.Main
			And (Form.DetailsMode Or Not IsMainOption) Then 
			
			AdditionalSettingsProperties.Insert("ReportInitialized", True);
		EndIf;
		
		SchemaBinaryData = CommonClientServer.StructureProperty(
			AdditionalSettingsProperties, "DataCompositionSchema");
		
		If TypeOf(SchemaBinaryData) = Type("BinaryData") Then
			IsImportedSchema = True;
			CurrentSchemaKey = BinaryDataHash(SchemaBinaryData);
			Schema = Reports.UniversalReport.ExtractSchemaFromBinaryData(SchemaBinaryData);
		EndIf;
		
		AdditionalSettingsProperties.Delete("SetFixedParameters");
		AdditionalSettingsProperties.Delete("DownloadedXMLSettings");
		
		If Not IsMainOption
		   And Not BeforeDownloadingSettings
		   And TypeOf(Settings) = Type("DataCompositionSettings")
		   And AdditionalSettingsProperties.Property("AvailableValues") Then
			
			If AdditionalSettingsProperties.Property("SavableFixedParameters") Then
				AdditionalSettingsProperties.Insert("SetFixedParameters");
			Else
				AdditionalSettingsProperties.Insert("DownloadedXMLSettings",
					Common.ValueToXMLString(Settings));
			EndIf;
		EndIf;
		
	EndIf;
	
	If IsImportedSchema Then
		SchemaKey = CurrentSchemaKey;
		ReportsServer.AttachSchema(ThisObject, Form, Schema, SchemaKey);
	EndIf;
EndProcedure

// 
//
// Parameters:
//   Context - Arbitrary
//   SchemaKey - String
//   VariantKey - String
//                - Undefined
//   NewDCSettings - DataCompositionSettings
//                    - Undefined
//   NewDCUserSettings - DataCompositionUserSettings
//                                    - Undefined
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, VariantKey, NewDCSettings, NewDCUserSettings) Export
	CurrentSchemaKey = Undefined;
	
	If NewDCSettings = Undefined Then 
		NewDCSettings = SettingsComposer.Settings;
	EndIf;
	
	IsImportedSchema = False;
	SchemaBinaryData = CommonClientServer.StructureProperty(
		NewDCSettings.AdditionalProperties, "DataCompositionSchema");
	
	If TypeOf(SchemaBinaryData) = Type("BinaryData") Then
		CurrentSchemaKey = BinaryDataHash(SchemaBinaryData);
		If CurrentSchemaKey <> SchemaKey Then
			Schema = Reports.UniversalReport.ExtractSchemaFromBinaryData(SchemaBinaryData);
			IsImportedSchema = True;
		EndIf;
	EndIf;
	
	If NewDCSettings.AdditionalProperties.Property("SetFixedParameters") Then
		NewDCSettings.AdditionalProperties.Delete("SetFixedParameters");
		Try
			Reports.UniversalReport.SetFixedParameters(ThisObject,
				NewDCSettings.AdditionalProperties.SavableFixedParameters,
				NewDCSettings,
				NewDCUserSettings);
		Except
			ErrorInfo = ErrorInfo();
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot set fixed parameters
				           |for the universal report option with the ""%1"" key. Reason:
				           |%2';"),
				           VariantKey,
				           ErrorProcessing.DetailErrorDescription(ErrorInfo));
			WriteLogEvent(NStr("en = 'Report options.Set up universal report parameters';", 
				Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.ReportsOptions,,
				Comment);
		EndTry;
		
	ElsIf Not NewDCSettings.AdditionalProperties.Property("ReportInitialized")
	        And TypeOf(NewDCUserSettings) = Type("DataCompositionUserSettings") Then
		
		// 
		// 
		SchemaKey = "";
	EndIf;
	
	AvailableValues = Undefined;
	FixedParameters = Reports.UniversalReport.FixedParameters(
		NewDCSettings, NewDCUserSettings, AvailableValues);
	
	If NewDCSettings.AdditionalProperties.Property("DownloadedXMLSettings") Then
		DownloadedXMLSettings = NewDCSettings.AdditionalProperties.DownloadedXMLSettings;
		NewDCSettings.AdditionalProperties.Delete("DownloadedXMLSettings");
		Try
			DCUploadedSettings = Common.ValueFromXMLString(DownloadedXMLSettings);
			DCUploadedSettings.AdditionalProperties.Insert("AvailableValues", AvailableValues);
			DCUploadedSettings.AdditionalProperties.Insert("SavableFixedParameters", FixedParameters);
			ReportKey = Context.ReportSettings.FullName;
			SettingsDescription = SettingsStorages.ReportsVariantsStorage.GetDescription(ReportKey, VariantKey);
			SettingsStorages.ReportsVariantsStorage.Save(ReportKey,
				VariantKey, DCUploadedSettings, SettingsDescription);
		Except
			ErrorInfo = ErrorInfo();
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the fixed parameters
				           |for the universal report option with the ""%1"" key. Reason:
				           |%2';"),
				           VariantKey,
				           ErrorProcessing.DetailErrorDescription(ErrorInfo));
			WriteLogEvent(NStr("en = 'Report options.Set up universal report parameters';", 
				Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.ReportsOptions,,
				Comment);
		EndTry;
	EndIf;
	
	If CurrentSchemaKey = Undefined Then 
		CurrentSchemaKey = FixedParameters.MetadataObjectType
			+ "/" + FixedParameters.MetadataObjectName
			+ "/" + FixedParameters.TableName;
		CurrentSchemaKey = Common.TrimStringUsingChecksum(CurrentSchemaKey, 100);
		
		If CurrentSchemaKey <> SchemaKey Then
			SchemaKey = "";
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(SchemaKey) And Not IsImportedSchema Then
		Schema = Reports.UniversalReport.DataCompositionSchema(FixedParameters);
	EndIf;
	
	If CurrentSchemaKey <> Undefined And (CurrentSchemaKey <> SchemaKey) Then
		SchemaKey = CurrentSchemaKey;
		ReportsServer.AttachSchema(ThisObject, Context, Schema, SchemaKey);
		
		If IsImportedSchema Then
			Reports.UniversalReport.SetStandardImportedSchemaSettings(
				ThisObject, SchemaBinaryData, NewDCSettings, NewDCUserSettings);
		Else
			Reports.UniversalReport.CustomizeStandardSettings(
				ThisObject, FixedParameters, NewDCSettings, NewDCUserSettings);
		EndIf;
		
		If TypeOf(Context) = Type("ClientApplicationForm") Then
			// Переопределение.
			SSLSubsystemsIntegration.BeforeLoadVariantAtServer(Context, NewDCSettings);
			ReportsOverridable.BeforeLoadVariantAtServer(Context, NewDCSettings);
			BeforeLoadVariantAtServer(Context, NewDCSettings, True);
			
			TablesToUse = ReportsOptions.TablesToUse(DataCompositionSchema);
			TablesToUse.Add(Metadata().FullName());
			Context.ReportSettings.Insert("TablesToUse", TablesToUse);
		ElsIf TypeOf(Context) = Type("Structure") Then
			SchemaURL = CommonClientServer.StructureProperty(Context, "SchemaURL");
			If Not IsTempStorageURL(SchemaURL) Then 
				Context.Insert("SchemaURL", PutToTempStorage(Schema, New UUID));
			EndIf;
		EndIf;
		AvailableValues = Undefined;
		FixedParameters = Reports.UniversalReport.FixedParameters(
			NewDCSettings, NewDCUserSettings, AvailableValues);
	Else
		Reports.UniversalReport.SetFixedParameters(
			ThisObject, FixedParameters, NewDCSettings, NewDCUserSettings);
	EndIf;
	NewDCSettings.AdditionalProperties.Insert("SavableFixedParameters", FixedParameters);
	NewDCSettings.AdditionalProperties.Insert("AvailableValues", AvailableValues);
	
	Reports.UniversalReport.SetStandardReportHeader(
		Context, NewDCSettings, FixedParameters, AvailableValues);
EndProcedure

// It is called after defining form item properties connected to user settings.
// See ReportsServer.СвойстваЭлементовФормыНастроек()
// It allows to override properties for report personalization purposes.
//
// Parameters:
//  FormType - ReportFormType - See Syntax Assistant.
//  ItemsProperties - See ReportsServer.SettingsFormItemsProperties
//  UserSettings - DataCompositionUserSettingsItemCollection - items of current
//                              user settings that affect the creation of linked form items.
//
Procedure OnDefineSettingsFormItemsProperties(FormType, ItemsProperties, UserSettings) Export 
	If FormType <> ReportFormType.Main Then 
		Return;
	EndIf;
	
	GroupProperties = ReportsServer.FormItemsGroupProperties();
	GroupProperties.Group = ChildFormItemsGroup.AlwaysHorizontal;
	ItemsProperties.Groups.Insert("FixedParameters", GroupProperties);
	
	FixedParameters = New Structure("Period, MetadataObjectType, MetadataObjectName, TableName");
	MarginWidth = New Structure("MetadataObjectType, MetadataObjectName, TableName", 20, 35, 20);
	
	For Each SettingItem In UserSettings Do 
		If TypeOf(SettingItem) <> Type("DataCompositionSettingsParameterValue")
			Or Not FixedParameters.Property(SettingItem.Parameter) Then 
			Continue;
		EndIf;
		
		FieldProperties = ItemsProperties.Fields.Find(
			SettingItem.UserSettingID, "SettingID");
		
		If FieldProperties = Undefined Then 
			Continue;
		EndIf;
		
		FieldProperties.GroupID = "FixedParameters";
		
		ParameterName = String(SettingItem.Parameter);
		If ParameterName <> "Period" Then 
			FieldProperties.TitleLocation = FormItemTitleLocation.None;
			FieldProperties.Width = MarginWidth[ParameterName];
			FieldProperties.HorizontalStretch = False;
		EndIf;
	EndDo;
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	Settings = SettingsComposer.GetSettings();
	
	Reports.UniversalReport.OutputSubordinateRecordsCount(Settings, DataCompositionSchema, StandardProcessing);
	
	If StandardProcessing Then 
		Return;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate,, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

#EndRegion

#Region Private

// Returns binary data hash.
//
// Parameters:
//   BinaryData - BinaryData - data, from which hash is calculated.
//
Function BinaryDataHash(BinaryData)
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(BinaryData);
	Return StrReplace(DataHashing.HashSum, " ", "") + "_" + Format(BinaryData.Size(), "NG=");
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf