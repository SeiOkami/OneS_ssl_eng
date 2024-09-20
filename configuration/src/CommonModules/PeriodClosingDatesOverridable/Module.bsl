///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Allows you to change interface upon embedding.
//
// Parameters:
//  InterfaceSettings5 - Structure:
//   * UseExternalUsers - Boolean - initial value is False
//     if you set to True, period-end closing dates can be set up for external users.
//
Procedure InterfaceSetup(InterfaceSettings5) Export
	
	
	
EndProcedure

// Fills in sections of period-end closing dates used upon their setup.
// If you do not specify any section, then only common period-end closing date setup will be available.
//
// Parameters:
//  Sections - ValueTable:
//   * Name - String - a name used in data source details
//       in the FillDataSourcesForPeriodClosingCheck procedure.
//
//   * Id - UUID - an item reference ID of chart of characteristic types.
//       To get an ID, execute the platform method in 1C:Enterprise mode:
//       "ChartsOfCharacteristicTypes.PeriodClosingDatesSections.GetRef().UUID()".
//       Do not specify IDs received using any other method
//       as it can violate their uniqueness.
//
//   * Presentation - String - presents a section in the form of period-end closing date setup.
//
//   * ObjectsTypes  - Array - object reference types, by which you can set period-end closing dates,
//       for example, Type("CatalogRef.Companies"), if no type is specified,
//       period-end closing dates are set up only to the precision of a section.
//
Procedure OnFillPeriodClosingDatesSections(Sections) Export
	
	
	
EndProcedure

// Allows you to specify tables and object fields to check period-end closing.
// To add a new source to DataSources See PeriodClosingDates.AddRow.
//
// Called from the ChangeProhibited procedure of the PeriodClosingDates common module
// used in the BeforeWrite event subscription of the object to check for period-end
// closing and canceled restricted object changes.
//
// Parameters:
//  DataSources - ValueTable:
//   * Table     - String - a full name of a metadata object,
//                   for example, Metadata.Documents.PurchaseInvoice.FullName().
//   * DateField    - String - an attribute name of an object or a tabular section,
//                   for example: "Date", "Goods.ShipmentDate".
//   * Section      - String - a name of a period-end closing date section
//                   specified in the OnFillPeriodClosingDatesSections procedure (see above). 
//   * ObjectField - String - an attribute name of an object or a tabular section,
//                   for example: "Company", "Goods.Warehouse".
//
Procedure FillDataSourcesForPeriodClosingCheck(DataSources) Export
	
	
	
EndProcedure

// Allows you to arbitrarily override period-end closing check:
//
// If you check upon writing the document, the AdditionalProperties property of the Object document contains
// the WriteMode property.
//  
// Parameters:
//  Object       - CatalogObject
//               - DocumentObject
//               - ChartOfCharacteristicTypesObject
//               - ChartOfAccountsObject
//               - ChartOfCalculationTypesObject
//               - BusinessProcessObject
//               - TaskObject
//               - ExchangePlanObject
//               - InformationRegisterRecordSet
//               - AccumulationRegisterRecordSet
//               - AccountingRegisterRecordSet
//               - CalculationRegisterRecordSet -  
//                 
//
//  PeriodClosingCheck    - Boolean - set to False to skip period-end closing check.
//  ImportRestrictionCheckNode - ExchangePlanRef
//                              - Undefined -  
//                                
//  ObjectVersion               - String - set "OldVersion" or "NewVersion" to check only the old
//                                object version (in the database) or only the new object version 
//                                (in the Object parameter).
//                                By default, contains the "" value - both object versions are checked at the same time.
//
Procedure BeforeCheckPeriodClosing(Object,
                                         PeriodClosingCheck,
                                         ImportRestrictionCheckNode,
                                         ObjectVersion) Export
	
	
	
EndProcedure

// Overrides getting data to check the closing date for an old (existing) data version.
//
// Parameters:
//  MetadataObject - MetadataObject - a metadata object of data to be received.
//  DataID - CatalogRef
//                      - DocumentRef
//                      - ChartOfCharacteristicTypesRef
//                      - ChartOfAccountsRef
//                      - ChartOfCalculationTypesRef
//                      - BusinessProcessRef
//                      - TaskRef
//                      - ExchangePlanRef
//                      - Filter - Reference to a data item or a record set filter to be checked.
//                                The value to be checked will be received from the database.
//
//  ImportRestrictionCheckNode - Undefined
//                              - ExchangePlanRef -  
//                                
//
//  DataToCheck - See PeriodClosingDates.DataToCheckTemplate.
//
//  Example:
//  If TypeOf(DataID) = Type("DocumentRef.Order") Then
//  	Data = Common.ObjectAttributesValues(DataID, "Company, WorkEndDate, WorkOrder");
//  	If Data.WorkOrder Then
//  		Check = DataToCheck.Add();
//  		Check.Section = "WorkOrders";
//  		Check.Object = Data.Company;
//  		Check.Date = Data.WorkEndDate;
//  	EndIf;
//  EndIf;
//
Procedure BeforeCheckOldDataVersion(MetadataObject, DataID, ImportRestrictionCheckNode, DataToCheck) Export
	
EndProcedure

// Overrides getting data to check the closing date for a new (future) data version.
//
// Parameters:
//  MetadataObject - MetadataObject - a metadata object of data to be received.
//  Data  - CatalogObject
//          - DocumentObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfAccountsObject
//          - ChartOfCalculationTypesObject
//          - BusinessProcessObject
//          - TaskObject
//          - ExchangePlanObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet - Data item or record set to be checked.
//
//  ImportRestrictionCheckNode - Undefined
//                              - ExchangePlanRef -  
//                                
//
//  DataToCheck - See PeriodClosingDates.DataToCheckTemplate.
//
//  Example:
//  If TypeOf(Data) = Type("DocumentObject.Order") AND Data.WorkOrder Then
//  	
//  	Check = DataToCheck.Add();
//  	Check.Section = "WorkOrders";
//  	Check.Object = Data.Company;
//  	Check.Date = Data.WorkEndDate;
//  	
//  EndIf;
//
Procedure BeforeCheckNewDataVersion(MetadataObject, Data, ImportRestrictionCheckNode, DataToCheck) Export
	
EndProcedure

#EndRegion
