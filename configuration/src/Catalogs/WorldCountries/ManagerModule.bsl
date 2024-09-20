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

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not StandardProcessing 
		Or Not Parameters.Property("AllowClassifierData")
		Or Not Parameters.AllowClassifierData Then
		Return;
	EndIf;
	
	ContactsManagerInternal.ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
EndProcedure

#EndRegion

#Region Internal

// Determines country data by the country catalog or classifier.
// Use ContactsManager.WorldCountryData.
//
// Parameters:
//    CountryCode    - String
//                 - Number - 
//    Description - String        - a country description. If not specified, search by description is not performed.
//
// Returns:
//    Structure:
//          * Code                - String
//          * Description       - String
//          * DescriptionFull - String
//          * CodeAlpha2          - String
//          * CodeAlpha3          - String
//          * Ref             - CatalogRef.WorldCountries
//    Undefined — the country does not exist.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Return ContactsManager.WorldCountryData(CountryCode, Description);
EndFunction

// Determines country data by the world country classifier.
// Use ContactsManager.WorldCountryClassifierDataByCode.
//
// Parameters:
//    Code - String
//        - Number - 
//    CodeType - String - Options: CountryCode (by default), Alpha2, and Alpha3.
//
// Returns:
//    Structure:
//          * Code                - String
//          * Description       - String
//          * DescriptionFull - String
//          * CodeAlpha2          - String
//          * CodeAlpha3          - String
//    Undefined — the country does not exist.
//
Function WorldCountryClassifierDataByCode(Val Code, CodeType = "CountryCode") Export
	Return ContactsManager.WorldCountryClassifierDataByCode(Code, CodeType);
EndFunction

// Determines country data by the classifier.
// Use ContactsManager.WorldCountryClassifierDataByDescription.
//
// Parameters:
//    Description - String - a country description.
//
// Returns:
//    Structure:
//          * Code                - String
//          * Description       - String
//          * DescriptionFull - String
//          * CodeAlpha2          - String
//          * CodeAlpha3          - String
//    Undefined — the country does not exist.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	Return ContactsManager.WorldCountryClassifierDataByDescription(Description);
EndFunction

#EndRegion

#Region Private

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	If ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		ModuleAddressManager.OnInitialItemsFilling(LanguagesCodes, Items, TabularSections);
	EndIf;
	
EndProcedure

#Region InfobaseUpdate

// Registers world countries for processing.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		// Update multilanguage strings if they were modified.
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("UpdateMode", "MultilingualStrings");
		
		InfobaseUpdate.RegisterPredefinedItemsToUpdate(Parameters,
			Metadata.Catalogs.WorldCountries, AdditionalParameters);
	
	EndIf;
	
	CountryList = ContactsManager.CustomEAEUCountries();
	
	NewRow                    = CountryList.Add();
	NewRow.Code                = "203";
	NewRow.Description       = NStr("en = 'CZECH REPUBLIC';");
	NewRow.CodeAlpha2          = "CZ";
	NewRow.CodeAlpha3          = "CZE";
	
	NewRow                    = CountryList.Add();
	NewRow.Code                = "270";
	NewRow.Description       = NStr("en = 'GAMBIA';");
	NewRow.CodeAlpha2          = "GM";
	NewRow.CodeAlpha3          = "GMB";
	NewRow.DescriptionFull = NStr("en = 'Republic of the Gambia';");
	
	NewRow                    = CountryList.Add();
	NewRow.Code                = "807";
	NewRow.Description       = NStr("en = 'REPUBLIC OF MACEDONIA';");
	NewRow.CodeAlpha2          = "MK";
	NewRow.CodeAlpha3          = "MKD";
	NewRow.DescriptionFull =  NStr("en = 'REPUBLIC OF MACEDONIA';");
	
	Query = New Query;
	Query.Text = "SELECT
		|	CountryList.Code AS Code,
		|	CountryList.Description AS Description,
		|	CountryList.CodeAlpha2 AS CodeAlpha2,
		|	CountryList.CodeAlpha3 AS CodeAlpha3,
		|	CountryList.DescriptionFull AS DescriptionFull
		|INTO CountryList
		|FROM
		|	&CountryList AS CountryList
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorldCountries.Ref AS Ref
		|FROM
		|	CountryList AS CountryList
		|		INNER JOIN Catalog.WorldCountries AS WorldCountries
		|		ON (WorldCountries.Code = CountryList.Code)
		|			AND (WorldCountries.Description = CountryList.Description)
		|			AND (WorldCountries.CodeAlpha2 = CountryList.CodeAlpha2)
		|			AND (WorldCountries.CodeAlpha3 = CountryList.CodeAlpha3)
		|			AND (WorldCountries.DescriptionFull = CountryList.DescriptionFull)";
	
	Query.SetParameter("CountryList", CountryList);
	QueryResult = Query.Execute().Unload();
	CountriesToProcess = QueryResult.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, CountriesToProcess);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	WorldCountryRef = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.WorldCountries");
	SettingsOfUpdate = Undefined;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		SettingsOfUpdate = ModuleNationalLanguageSupportServer.SettingsPredefinedDataUpdate(Metadata.Catalogs.WorldCountries);
	EndIf;
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While WorldCountryRef.Next() Do
		RepresentationOfTheReference = String(WorldCountryRef.Ref);
		Try
			
			ClassifierData = ContactsManager.WorldCountryClassifierDataByCode(WorldCountryRef.Ref.Code);
			
			If ClassifierData <> Undefined Then
				
				Block = New DataLock();
				LockItem = Block.Add("Catalog.WorldCountries");
				LockItem.SetValue("Ref", WorldCountryRef.Ref);
				
				BeginTransaction();
				Try
					
					Block.Lock();
					
					WorldCountry = WorldCountryRef.Ref.GetObject();
					FillPropertyValues(WorldCountry, ClassifierData);
					InfobaseUpdate.WriteData(WorldCountry);
					
					CommitTransaction();
					
				Except
					RollbackTransaction();
					Raise;
				EndTry;
				
			Else
				InfobaseUpdate.MarkProcessingCompletion(WorldCountryRef.Ref);
			EndIf;
			
			// Update descriptions.
			If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
				If SettingsOfUpdate.ObjectAttributesToLocalize.Count() > 0 Then
					ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
					ModuleNationalLanguageSupportServer.UpdateMultilanguageStringsOfPredefinedItem(WorldCountryRef, SettingsOfUpdate);
				EndIf;
			EndIf;
			
			ObjectsProcessed = ObjectsProcessed + 1;
			
		Except
			// 
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process country: %1. Reason:
					|%2';"),
				RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.WorldCountries, WorldCountryRef.Ref, MessageText);
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.WorldCountries");
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some countries: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.WorldCountries,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The update procedure processed another portion of world countries: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

