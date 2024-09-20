///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Intended for setting up subsystem parameters.
//
// Parameters:
//  CommonParameters - Structure:
//      * PersonalSettingsFormName            - String - Name of the user settings edit form.
//      * AskConfirmationOnExit - Boolean - True by default. If False, 
//                                                                  the exit confirmation is not
//                                                                  requested when exiting the application, if it is not clearly enabled in
//                                                                  the personal application settings.
//
//      * MinPlatformVersion - String - a minimum platform version required to start the application.
//                                              The application startup on the platform version earlier than the specified one will be unavailable.
//                                              For example, "8.3.6.1650".
//                                              You can specify multiple semicolon-separated platform versions.
//                                              In this case, the minimum platform version is selected based
//                                              on the current one.
//                                              For example: "8.3.14.1694; 8.3.15.2107; 8.3.16.1791".
//                                              If you use version 8.3.14, you will be offered to migrate to 8.3.14.1694.
//                                              To use version 8.3.15, you will be offered 8.3.15.2107 and for version 8.3.16, you will be offered 8.3.16.1791.
//
//      * RecommendedPlatformVersion            - String - a recommended platform version for the application startup.
//                                                           For example, "8.3.8.2137".
//                                                           You can specify multiple semicolon-separated platform versions
//                                                           . See the MinPlatformVersion parameter as an example. 
//      * DisableMetadataObjectsIDs - Boolean - disables completing the MetadataObjectIDs
//              and ExtensionObjectIDs catalogs, as well as the export/import procedure for DIB nodes.
//              For partial embedding certain library functions into the configuration without enabling support.
//      * RecommendedRAM - Number - Obsolete. Gigabytes RAM recommended for the application.
//                                                      By default, 4 GB.
//
//    Instead, use MinimumPlatformVersion and RecommendedPlatformVersion properties:
//      * MinPlatformVersion1    - String -
//                                                           
//      * MustExit               - Boolean - the initial value is False.
//
Procedure OnDetermineCommonCoreParameters(CommonParameters) Export
	
	
	
EndProcedure

// Defines the map between session parameter names and their installing handlers.
// Called to initialize session parameters from the event handler of the SessionParametersSetting session module
// (for more information about it, see Syntax Assistant). 
//
// In the specified modules, there must be a handler procedure the parameters are being passed to:
//  ParameterName           - String - a parameter name of session to be set.
//  SpecifiedParameters - Array - the names of parameters that are already specified.
// 
// The following is an example of a handler procedure for copying to the specified modules.
//
//// Parameters:
////  ParameterName  - String
////  SpecifiedParameters - Array of String
////
////
//	
//  The SessionParametersSetting procedure(ParameterName, SpecifiedParameters) Export
//		If ParameterName = "CurrentUser", Then
//		SessionParameters.CurrentUser = Value;
//  SpecifiedParameters.Add ("CurrentUser);
//	
//EndIf;
// EndProcedure
//
// Parameters:
//  Handlers - Map of KeyAndValue:
//    * Key     - String - In the "<SessionParameterName>|<SessionParameterNamePrefix*>" format.
//                   The asterisk sing (*) is used at the end of the session parameters name and means
//                   that one handler is called to initialize all session parameters whose name starts
//                   with the word SessionParameterNamePrefix.
//
//    * Value - String - In the "<ModuleName>.SessionParametersSetting" format.
//
//  Example:
//   Handler.Insert("CurrentUser", "UsersInternal.SessionParametersSetting").
//
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	
	
EndProcedure

// Allows you to set parameters values required for the operation of the client code when
// starting configuration (in the BeforeStart or OnStart event handlers) 
// without additional server calls. 
// To get the values of these parameters from the client code
// See StandardSubsystemsClient.ClientParametersOnStart.
//
// Important: do not use cache reset commands of modules that reuse return values 
// because this can lead to unpredictable errors and unneeded service calls.
//
// Parameters:
//   Parameters - Structure - names and values of the client startup parameters that should be set.
//                           To set client startup parameters:
//                           Parameters.Insert(<ParameterName>, <parameter value receive code>);
//
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	
	
EndProcedure

// Allows you to set parameters values required for the operation of the client code
// configuration without additional server calls.
// To get these parameters from the client code
// See StandardSubsystemsClient.ClientRunParameters.
//
// Parameters:
//   Parameters - Structure - names and values of client parameters to be set.
//                           To set the client parameters:
//                           Parameters.Insert(<ParameterName>, <parameter value receive code>);
//
Procedure OnAddClientParameters(Parameters) Export
	
	
	
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
// 
Procedure BeforeStartApplication() Export

EndProcedure

// Defines metadata objects and separate attributes that are excluded from the results of reference search
// and not included in exclusive delete marked, changing references and in the report of usage locations.
// See also: Common.RefsSearchExclusions.
//
// For example, the Object versioning subsystem and the Properties subsystem are attached to the Sales of goods and services document.
// This document can also be specifier in other metadata objects - document or registers.
// Some of them are important for business logic (like register records) and must be shown to user.
// Other part is "technical" references, referred to the document from the Object versioning and the Properties subsystems.
// Such technical references must be hidden from users when deleting, analyzing locations of usage, or prohibiting to edit key attributes.
// The list of technical objects must be specified in this procedure.
//
// At the same time, in order to avoid the appearance of references to non-existent objects,
// it is recommended to provide a procedure for clearing the specified metadata objects.
//   * For information register dimensions select the Master check box,
//     this deletes the register record data once the respective reference specified in a dimension is deleted.
//   * For other attributes of the specified objects, use the BeforeDelete subscription event of all metadata
//     object types that can be recorded to the attributes of the specified metadata objects.
//     It is required to find the "technical" objects in the handler that contain the reference to the object to be deleted in the attributes
//     and select the way of reference clearing: clear the attribute value, delete the row, or delete the whole object.
// For more information see the documentation to the "Deletion of marked objects" subsystem. 
//
// When excluding registers, you can exclude only Dimensions.
// If you need to exclude values from the search in the resources
// or in the register attributes, it is required to exclude the entire register.
//
// Parameters:
//   RefSearchExclusions - Array - metadata objects or their attributes (MetadataObject, String)
//       that are not considered in the business logic.
//       Standard attributes and tabular sections can be specified only as string names (see the example below). 
//
// Example:
//   RefsSearchExclusions.Add(Metadata.InformationRegisters.ObjectsVersions);
//   RefsSearchExclusions.Add(Metadata.InformationRegisters.ObjectsVersions.Dimensions.Object);
//   RefsSearchExclusions.Add("ChartOfCalculationTypes._DemoBaseEarnings.StandardTabularSection.BaseCalculationTypes.StandardAttribute.CalculationType");
//
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	
	
EndProcedure

// 
// 
// 
//
// Parameters:
//  SubordinateObjects - See Common.SubordinateObjects
//
// Example:
//	SubordinateObjectLinks = New Map;
//	SubordinateObjectLinks.Insert("LinksField");
//	SubordinateObject = SubordinateObjects.Add();
//	SubordinateObject.SubordinateObject = Metadata.Catalogs.<SubordinateCatalog>;
//	SubordinateObject.LinksFields = SubordinateObjectLinks;
//	SubordinateObject.RunReferenceReplacementsAutoSearch = True;
//
//	SubordinateObjectLinks = New Array;
//	SubordinateObjectLinks.Insert("LinksField");
//	SubordinateObject = SubordinateObjects.Add();
//	SubordinateObject.SubordinateObject = Metadata.Catalogs.<SubordinateCatalog>;
//	SubordinateObject.LinksFields = SubordinateObjectLinks;
//	SubordinateObject.RunReferenceReplacementsAutoSearch = True;
//
//	SubordinateObject = SubordinateObjects.Add()
//	SubordinateObject.SubordinateObject = Metadata.Catalog.<SubordinateCatalog>;
//	SubordinateObject.LinksFields = "LinksField";
//	SubordinateObject.OnSearchForReferenceReplacement = "<CommonModule>";
// 	
Procedure OnDefineSubordinateObjects(SubordinateObjects) Export

	

EndProcedure

// Executed after reference replacement and before object deletion.
// 
// Parameters:
//  Result - See Common.ReplaceReferences
//  ExecutionParameters - See Common.RefsReplacementParameters
//  SearchTable - See Common.UsageInstances
//
Procedure AfterReplaceRefs(Result, ExecutionParameters, SearchTable) Export

	

EndProcedure

// It is called when the infobase is updated to account to consider renaming subsystems and roles in the configuration.
// Otherwise, there will be an asynchronization between the configuration metadata and 
// the items of the MetadataObjectIDs directory, which will lead to various errors when the configuration is running.
// See also: Common.MetadataObjectID, Common.MetadataObjectIDs.
//
// In this procedure, specify renaming only for the subsystems and roles for each version of the configuration. 
// Do not specify renaming of the remaining metadata objects, since they are processed automatically.
//
// Parameters:
//  Total - ValueTable - a table of renamings that requires filling.
//                           See Common.AddRenaming.
//
// Example:
//	Common.AddRenaming(Total, "2.1.2.14",
//		"Subsystem._DemoSubsystems",
//		"Subsystem._DemoUtilitySubsystems");
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	
	
EndProcedure

// Allows you to disable subsystems, for example, for testing purposes.
// If the subsystem is disabled, functions Common.SubsystemExists and 
// CommonClient.SubsystemExists will return False.
//
// To prevent recursion, do not use Common.SubsystemExists in this procedure. 
// 
//
// Parameters:
//   DisabledSubsystems - Map of KeyAndValue:
//     * Key - String - the name of the subsystem to be disabled
//     * Value - Boolean - True.
//
Procedure OnDetermineDisabledSubsystems(DisabledSubsystems) Export
	
	
	
EndProcedure

// It is called before importing priority data in the subordinate DIB node
// and is designed to fill in the settings for placing the data exchange message or
// to implement non-standard import of priority data from the master DIB node.
//
// First-priority data is predefined items and
// MetadataObjectIDs catalog items.
//
// Parameters:
//  StandardProcessing - Boolean - the initial value is True, if set to False, 
//                the priority data is imported using the
//                DataExchange subsystem will be skipped (the same will happen
//                if the DataExchange subsystem is not in the configuration).
//
Procedure BeforeImportPriorityDataInSubordinateDIBNode(StandardProcessing) Export
	
	
	
EndProcedure

// Defines a list of software interface versions available through the InterfaceVersion web service.
//
// Parameters:
//  SupportedVersions - Structure - specify the application interface in the key,
//                                     and an array of rows with supported versions of this interface in values.
//
// Example:
//
//  // FilesTransferService
//  Versions = New Array;
//  Versions.Add("1.0.1.1");
//  Versions.Add("1.0.2.1"); 
//  SupportedVersions.Insert("FilesTransferService", Versions);
//  // End FilesTransferService
//
Procedure OnDefineSupportedInterfaceVersions(SupportedVersions) Export
	
EndProcedure

// Specifies parameters of the functional options that affect the interface and the desktop.
// For example, if the functional option values are stored in resources of an information register,
// the functional option parameters can define filters by register dimensions
// that are taken into account during reading values of this functional option.
//
// See GetInterfaceFunctionalOption,
// SetInterfaceFunctionalOptionsParameters, and GetInterfaceFunctionalOptionsParameters methods in the Syntax Assistant.
//
// Parameters:
//   InterfaceOptions - Structure - parameter values of functional options that are set for the command interface.
//       The structure item key defines the parameter name and the item value defines the current parameter value.
//
Procedure OnDetermineInterfaceFunctionalOptionsParameters(InterfaceOptions) Export
	
EndProcedure


// 
// 
// 
// 
//
// Parameters:
//  Notifications - Map of KeyAndValue:
//   * Key     - String -
//   * Value - See ServerNotifications.NewServerNotification
//
// Example:
//	
//		
//	
//	
//	
//	
//	
//
Procedure OnAddServerNotifications(Notifications) Export
	
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
// 
//
// Parameters:
//  Parameters - Map of KeyAndValue:
//    * Key     - String       -
//    * Value - Arbitrary -
//  Results - Map of KeyAndValue:
//    * Key     - String       -
//    * Value - Arbitrary -
//
// Example:
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
//		
//
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of data sending and receiving to exchange in an infobase.

// Additional handler for the event of the same name that occurs during data exchange in a distributed infobase.
// It is executed after basic library algorithms are executed.
// It is not executed, if sending of a data item was ignored earlier.
//
// Parameters:
//  Source                  - ExchangePlanObject - a node, for which the exchange is performed.
//  DataElement             - Arbitrary - see the details of the handler of the same name in the Syntax Assistant.
//  ItemSend          - DataItemSend - see the details of the handler of the same name in the Syntax Assistant.
//  InitialImageCreating  - Boolean - see the details of the handler of the same name in the Syntax Assistant.
//
Procedure OnSendDataToSlave(Source, DataElement, ItemSend, InitialImageCreating) Export
	
EndProcedure

// Additional handler for the event of the same name that occurs during data exchange in a distributed infobase.
// It is executed after basic library algorithms are executed.
// It is not executed, if sending of a data item was ignored earlier.
//
// Parameters:
//  Source          - ExchangePlanObject - a node, for which the exchange is performed.
//  DataElement     - Arbitrary - see the details of the handler of the same name in the Syntax Assistant.
//  ItemSend  - DataItemSend - see the details of the handler of the same name in the Syntax Assistant.
//
Procedure OnSendDataToMaster(Source, DataElement, ItemSend) Export
	
EndProcedure

// Additional handler for the event of the same name that occurs during data exchange in a distributed infobase.
// It is executed after basic library algorithms are executed.
// It is not executed, if receiving of a data item was ignored earlier.
//
// Parameters:
//  Source          - ExchangePlanObject - a node, for which the exchange is performed.
//  DataElement     - Arbitrary - see the details of the handler of the same name in the Syntax Assistant.
//  ItemReceive - DataItemReceive - see the details of the handler of the same name in the Syntax Assistant.
//  SendBack     - Boolean - see the details of the handler of the same name in the Syntax Assistant.
//
Procedure OnReceiveDataFromSlave(Source, DataElement, ItemReceive, SendBack) Export
	
EndProcedure

// Additional handler for the event of the same name that occurs during data exchange in a distributed infobase.
// It is executed after basic library algorithms are executed.
// It is not executed, if receiving of a data item was ignored earlier.
//
// Parameters:
//  Source          - ExchangePlanObject - a node, for which the exchange is performed.
//  DataElement     - Arbitrary - see the details of the handler of the same name in the Syntax Assistant.
//  ItemReceive - DataItemReceive - see the details of the handler of the same name in the Syntax Assistant.
//  SendBack     - Boolean - see the details of the handler of the same name in the Syntax Assistant.
//
Procedure OnReceiveDataFromMaster(Source, DataElement, ItemReceive, SendBack) Export
	
EndProcedure

// Allows changing the flag indicating whether the application version is a base one.
//
// Parameters:
//  ThisIsBasic - Boolean - Indicates that the application version is a base one. The default value is True if
//                        the application name has the "Base" word.
// 
Procedure WhenDefiningAFeatureThisIsTheBasicVersionOfTheConfiguration(ThisIsBasic) Export 
	
EndProcedure

#EndRegion
