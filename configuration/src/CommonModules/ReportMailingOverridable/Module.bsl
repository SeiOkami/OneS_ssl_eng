///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Allows for changing default formats and specify pictures.
// See ReportMailing.SetFormatsParameters.
//
// Parameters:
//   FormatsList - ValueList:
//       * Value      - EnumRef.ReportSaveFormats - a format reference.
//       * Presentation - String - a format presentation.
//       * Check       - Boolean - flag showing that the format is used by default.
//       * Picture      - Picture - a picture of the format.
//
// Example:
//	
//	
//
Procedure OverrideFormatsParameters(FormatsList) Export
	
	
	
EndProcedure

// Allows you to add the details of cross-object links of types for mailing recipients.
// To register type parameters, See ReportMailing.AddItemToRecipientsTypesTable.
// Other examples of usage see the ReportMailingCached.RecipientTypesTable. 
// Important:
//   Use this mechanism only if:
//   1. It is required to describe and present several types as one (as in the Users and
//   UserGroups catalog).
//   2. It is required to change the type representation without changing the metadata synonym.
//   3. It is required to specify the type of email contact information by default.
//   4. t is required to define a group of contact information.
//
// Parameters:
//   TypesTable  - ValueTable - type details table.
//   AvailableTypes - Array - available types.
//
// Example:
//	Settings = New Structure;
//	Settings.Insert(MainType, Type(CatalogRef.Counterparties)).
//	Settings.Insert(CIKind, ContactsManager.ContactInformationKindByName(CounterpartyEmail));
//	ReportMailing.AddItemToRecipientsTypesTable(TypesTable, AvailableTypes, Settings).
//
Procedure OverrideRecipientsTypesTable(TypesTable, AvailableTypes) Export
	
EndProcedure

// Allows you to define a handler for saving a spreadsheet document to a format.
// Important:
//   If non-standard processing is used (StandardProcessing is changed to False),
//   then FullFileName must contain the full file name with extension.
//
// Parameters:
//   StandardProcessing - Boolean - a flag of standard subsystem mechanisms usage for saving to a format.
//   SpreadsheetDocument    - SpreadsheetDocument - a spreadsheet document to be saved.
//   Format               - EnumRef.ReportSaveFormats - a format for saving the spreadsheet
//                                                                        document.
//   FullFileName       - String - a full file name.
//       Passed without an extension if the format was added in the applied configuration.
//
// Example:
//	
//		
//		
//		
//	
//
Procedure BeforeSaveSpreadsheetDocumentToFormat(StandardProcessing, SpreadsheetDocument, Format, FullFileName) Export
	
	
	
EndProcedure

// 
// 
// 
//  
//   
// 
// 
//  
//   
//
// Parameters:
//   RecipientsParameters - CatalogRef.ReportMailings
//                        - Structure - parameters for creating mailing list recipients.
//   Query - Query -
//   StandardProcessing - Boolean -
//   Result - Map of KeyAndValue -
//                                               
//       * Key     - CatalogRef -
//       * Value - String -
// 
Procedure BeforeGenerateMailingRecipientsList(RecipientsParameters, Query, StandardProcessing, Result) Export
	
EndProcedure

// Allows you to exclude reports that are not ready for integration with mailing.
//   Specified reports are used as a filter when selecting reports.
//
// Parameters:
//   ReportsToExclude - Array - a list of reports in the form of objects with the Report type of the MetadataObject
//                       connected to the ReportsOptions storage but not supporting integration with mailings.
//
Procedure DetermineReportsToExclude(ReportsToExclude) Export
	
	
	
EndProcedure

// Allows overriding the report generation parameters.
//
// Parameters:
//  GenerationParameters - Structure:
//    * DCUserSettings - DataCompositionUserSettings - report settings
//                                    for the corresponding distribution.
//  AdditionalParameters - Structure:
//    * Report - CatalogRef.ReportsOptions - a reference to the report option settings storage.
//    * Object - ReportObject - an object of the report to be sent.
//    * DCS - Boolean - indicates whether a report is created by the data composition system.
//    * DCSettingsComposer - DataCompositionSettingsComposer - a report settings composer.
//
Procedure OnPrepareReportGenerationParameters(GenerationParameters, AdditionalParameters) Export 
	
	
	
EndProcedure

// 
// 
// 
// Parameters:
//   BulkEmailType - String -
//   MailingRecipientType        - TypeDescription
//                                 - Undefined - 
//   AdditionalTextParameters - Structure -
//     * Key     - String -
//     * Value - String - representation of the argument.
//
//  Example:
//	
//		
//		
//		
//	
//
Procedure OnDefineEmailTextParameters(BulkEmailType, MailingRecipientType, AdditionalTextParameters) Export
	
	
	
EndProcedure

// 
// 
// 
// Parameters:
//   BulkEmailType - String -
//   MailingRecipientType - TypeDescription
//   Recipient - DefinedType.BulkEmailRecipient -
//              - Undefined - 
//   AdditionalTextParameters - Structure -
//     * Key     - String -
//     * Value - String - representation of the argument.
// 
// Example:
//	
//		
//		
//		
//		
//	
//
Procedure OnReceiveEmailTextParameters(BulkEmailType, MailingRecipientType, Recipient, AdditionalTextParameters) Export
	
	
	
EndProcedure

#EndRegion
