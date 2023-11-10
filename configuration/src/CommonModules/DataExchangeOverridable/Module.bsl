///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Determines a prefix of object codes and numbers of default infobase.
//
// Parameters:
//  Prefix - String, 2 - a prefix of object codes and numbers of default infobase.
//
Procedure OnDetermineDefaultInfobasePrefix(Prefix) Export
	
	
	
EndProcedure

// Determines the list of exchange plans that use data exchange subsystem functionality.
//
// Parameters:
//  SubsystemExchangePlans - Array of MetadataObjectExchangePlan - an array of configuration exchange plans
//                          that use data exchange subsystem functionality.
//                          Array elements are exchange plan metadata objects.
//
// Example:
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithoutConversionRules);
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.ExchangeWithStandardSubsystemsLibrary);
//   SubsystemExchangePlans.Add(Metadata.ExchangePlans.DistributedInfobase);
//
Procedure GetExchangePlans(SubsystemExchangePlans) Export
	
	
	
EndProcedure

// This procedure is called on data export.
// It is used for overriding the standard data export handler.
// This handler must implement the data export logic:
// selecting data to be exported, serializing the data to a message file or to a stream.
// After the running the handler, the data exchange subsystem sends exported data to recipient.
// Messages to be exported can be of arbitrary format.
// If errors occur on sending the data, handler execution must be stopped using the Raise
// method with an error description.
//
// Parameters:
//
//  StandardProcessing - Boolean - a flag indicating whether the standard (system) event processing is executed is passed to this
//                                 parameter.
//   If this parameter is set to False in the processing procedure, standard
//   processing is skipped. Canceling standard processing does not mean canceling the operation.
//   Default value is True.
//
//  Recipient - ExchangePlanRef - an exchange plan node, for which data is being exported.
//
//  MessageFileName - String - a name of the file to export data to.
//   If this parameter is filled, the platform expects
//   data to be exported to file. After exporting, the platform sends data from this file.
//   If this parameter is empty, the system expects data to be exported to the MessageData parameter.
//
//  MessageData - Arbitrary - if the MessageFileName parameter is empty,
//   the system expects data to be exported to this parameter.
//
//  TransactionItemsCount - Number - defines the maximum number of data items
//   that can be placed in the message within a single database transaction.
//   You can implement the algorithms
//   of transaction locks for the data being exported in this handler.
//   The value of this parameter is set in the data exchange subsystem settings.
//
//  EventLogEventName - String - a name of an event log entry for the current data exchange session.
//   This parameter is used to determine the event name (errors, warnings, information) when writing error details to the event log.
//   It matches the EventName parameter of the WriteLogEvent method of the global context.
//
//  SentObjectsCount - Number - a counter of sent objects.
//   It is used to count the number of sent objects.
//   The number is then written to the exchange protocol.
//
Procedure OnDataExport(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemsCount,
								EventLogEventName,
								SentObjectsCount) Export
	
EndProcedure

// This procedure is called on data import.
// It is used for overriding the standard data import handler.
// This handler is to implement the following data export logic:
// required validations before importing data, serialization of data from message file or from
// stream.
// Messages to be imported can be of arbitrary format.
// If errors occur on receiving data, the handler execution must be stopped using the Raise
// method with an error description.
//
// Parameters:
//
//  StandardProcessing - Boolean - a flag indicating whether
//   the standard (system) event processing is executed is passed to this parameter.
//   If this parameter is set to False in the processing procedure,
//   standard processing is skipped.
//   Canceling standard processing does not mean canceling the operation.
//   The default value is True.
//
//  Sender - ExchangePlanRef - an exchange plan node, for which data is imported.
//
//  MessageFileName - String - a name of the file to export data from.
//   If this parameter is empty, data to be imported is passed using the MessageData parameter.
//
//  MessageData - Arbitrary - this parameter contains the data to be imported.
//   If the MessageFileName parameter is empty,
//   the data is to be imported using this parameter.
//
//  TransactionItemsCount - Number - defines the maximum number of data items
//   that can be read from a message and recorded to the infobase within a single transaction.
//   If it is necessary, you can implement algorithms of data recording in transaction.
//   The value of this parameter is set in the data exchange subsystem settings.
//
//  EventLogEventName - String - a name of an event log entry for the current data exchange session.
//   This parameter is used to determine the event name (errors, warnings, information) when writing error details to the event log.
//   It matches the EventName parameter of the WriteLogEvent method of the global context.
//
//  ReceivedObjectsCount - Number -a counter of received objects.
//   It is used to store the number of imported objects
//   in the exchange protocol.
//
Procedure OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemsCount,
								EventLogEventName,
								ReceivedObjectsCount) Export
	
EndProcedure

// Changes registration handler for initial data export.
// It is used for overriding the standard change registration handler.
// Standard processing implies recording all data from the exchange plan composition.
// This handler can improve initial data export performance
// using exchange plan filters for restricting data migration.
// Registering changes with data migration restriction filters must be implemented in this handler.
// You can use the
// DataExchangeServer.RegisterDataByExportStartDateAndCompany
// universal procedure.
// The handler cannot be used for performing exchange
// in a distributed infobase.
// Using this handler, you can improve
// initial data export performance up to 2-4 times.
//
// Parameters:
//
//   Recipient - ExchangePlanRef - an exchange plan node to which data is to be exported.
//   StandardProcessing - Boolean - a flag indicating whether the standard
//                          (system) event processing is executed is passed to this parameter.
//                          If this parameter is set to False
//                          in the processing procedure, standard processing is skipped.
//                          Canceling standard processing does not mean canceling the operation.
//                          Default value is True.
//   Filter - Array of MetadataObject
//         - MetadataObject - 
//           
//
Procedure InitialDataExportChangesRegistration(Val Recipient, StandardProcessing, Filter) Export
	
	
	
EndProcedure

// This procedure is called when a data change conflict is detected.
// The event occurs if an object is modified both in the current infobase and in the correspondent infobase,
// and the modifications are different.
// It overrides the standard data change conflict processing.
// The standard processing of conflicts implies receiving changes from the master node
// and ignoring changes from a subordinate node.
// To change the standard processing,
// redefine the ItemReceive parameter.
// In this handler, you can specify the algorithms of resolving conflicts for individual infobase objects,
// or infobase object properties, or source nodes, or the entire infobase, or
// all data items.
// This handler is called on data exchange execution of any type
// (on data exchange in a distributed infobase and on data exchange based on exchange rules).
//
// Parameters:
//  DataElement - Arbitrary - a data item that is read from the data exchange message.
//                  Data items can be ConstantValueManager.<Constant name>,
//                  infobase objects (except for Object deletion), register record sets,
//                  sequences, or recalculations.
//
//  ItemReceive - DataItemReceive - defines whether a read data item is to be recorded to the infobase
//                                               if a conflict occurs.
//   On calling the handler, the default parameter value is Auto,
//   and this implies receiving data from the master node and ignoring data from the subordinate node.
//   You can redefine the parameter value in the handler.
//
//  Sender - ExchangePlanRef - an exchange plan node on behalf of which data is received.
//
//  GetDataFromMasterNode - Boolean -  in a distributed infobase, this flag shows whether data is received from the master
//                                node.
//   True - data is received from the master node. False - data is received from a subordinate node.
//   In exchanges based on exchange rules, its value is True if the object priority
//   specified in the exchange rules and used for resolving conflicts is set to Higher (the default value) or not specified;
//   This parameter value is False if the object priority is set to Lower or Equal.
//   In other cases, the parameter value is True.
//
Procedure OnDataChangeConflict(Val DataElement, ItemReceive, Val Sender, Val GetDataFromMasterNode) Export
	
	
	
EndProcedure

// The handler of infobase initial setup after creating a DIB node.
// It is called on the first start of the subordinate DIB node (including SWP).
//
Procedure OnSetUpSubordinateDIBNode() Export
	
EndProcedure

// Receives the available versions of universal format EnterpriseData.
//
// Parameters:
//   FormatVersions - Map - map of format version number
//                   to the common module where the export or import handlers for this version are located.
//
// Example:
//   FormatVersions.Insert("1.2", <NameOfCommonModuleWithConversionRules>);
//
Procedure OnGetAvailableFormatVersions(FormatVersions) Export
	
	
	
EndProcedure

// Receives the available extensions of universal format EnterpriseData.
//
// Parameters:
//   FormatExtensions - Map of KeyAndValue:
//     * Key - String - URL of the format extension schema namespace.
//     * Value - String - the number of the extended format version.
//
Procedure OnGetAvailableFormatExtensions(FormatExtensions) Export
	
	
	
EndProcedure

// 
// 
//
// Parameters:
//   PreviousValue - Boolean - Value of constant IsStandaloneWorkplace before change.
//   NewCurrent - Boolean - New value of constant IsStandaloneWorkplace.
//   StandardProcessing - Boolean - Disable standard logic upon constant write. 
//                                   By default, True.
//
Procedure WhenChangingOfflineModeOption(PreviousValue, NewCurrent, StandardProcessing) Export
	
	
	
EndProcedure

// 
// 
// 
// Parameters:
//   ExchangePlanName - String - 
//                             
//   SettingsMode - String -
//                               
//   ExchangePlanIsRecognized - Boolean -
//
Procedure WhenCheckingCorrectnessOfNameOfEnterpriseDataExchangePlan(ExchangePlanName, SettingsMode, ExchangePlanIsRecognized) Export
	
	
	
EndProcedure

#EndRegion

