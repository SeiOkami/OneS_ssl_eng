///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Allows to set up common subsystem settings including the list of initial filling objects, message texts for
// the user, and so on.
// 
// Parameters:
//  Parameters - Structure:
//    * UpdateResultNotes - String - tooltip text that indicates the path to
//                                          the "Application update results" form.
//    * UncompletedDeferredHandlersMessageParameters - Structure - message on
//                                          availability of uncompleted deferred handlers that perform an update
//                                          to a previous version; displayed on attempting migration:
//       * MessageText                 - String - text of a message displayed to a user. By default,
//                                          message text is built to allow for its
//                                          continuation, i.e. has a ProhibitContinuation = False parameter.
//       * MessagePicture              - Picture - a picture displayed on the left of a message.
//       * ProhibitContinuation           - Boolean - if True, then continuation of an update will be impossible. Default value is False.
//    * ApplicationChangeHistoryLocation - String - provides location of a command used to
//                                          open the form containing notes on an application release.
//    * MultiThreadUpdate           - Boolean - if True, then several update handlers can operate
//                                          at once. The default value is False.
//                                          This influences both the number of update handlers execution threads
//                                          and the number of update data registration threads.
//                                          NB: before using, read documentation.
//    * DefaultInfobaseUpdateThreadsCount - String - the number of deferred update threads
//                                          used by default (if a constant value is not specified)
//                                          InfobaseUpdateThreadCount. Equals 1 by default.
//   * ObjectsWithInitialFilling - Array - objects that contain initial filling code
//                                          in the manager module of the OnInitialItemsFilling procedure.
//
Procedure OnDefineSettings(Parameters) Export
	
	
	
EndProcedure

// The procedure is called before the infobase data update handler procedures.
// You can implement any non-standard logic for data update: for instance,
// initialize information about versions of subsystems
// using InfobaseUpdate.InfobaseVersion, InfobaseUpdate.SetInfobaseVersion,
// and InfobaseUpdate.RegisterNewSubsystem.
//
// Example:
//  To cancel a regular procedure of migration from another application, register 
//  the fact that the main configuration version is up-to-date:
//  SubsystemsVersions = InfobaseUpdate.SubsystemVersions();
//  If SubsystemVersions.Count () > 0 And SubsystemVersions.Find(Metadata.Name, "SubsystemName") = Undefined Then
//    InfobaseUpdate.RegisterNewSubsystem(Metadata.Name, Metadata.Version);
//  EndIf;
//
Procedure BeforeUpdateInfobase() Export
	
EndProcedure

// The procedure is called after the infobase data is updated.
// Depending on conditions, you can turn off regular opening of a form
// containing description of new version updates at first launch of a program (right after an update),
// and also execute other actions.
//
// It is not recommended to execute any kind of data processing in this procedure.
// Such procedures should be applied by regular update handlers executed for each "*" version.
// 
// Parameters:
//   PreviousIBVersion     - String - The initial version number. For empty infobases, "0.0.0.0".
//   CurrentIBVersion        - String - version after an update. As a rule, it corresponds with Metadata.Version.
//   UpdateIterations     - Array - an array of structures providing information on and keys for updates of each
//                                     library or configuration:
//       * Subsystem              - String - name of a library or a configuration.
//       * Version                  - String - for example, "2.1.3.39". Library (configuration) version number.
//       * IsMainConfiguration - Boolean - True if it is a main configuration, not a library.
//       * Handlers             - ValueTable - all library update handlers;
//                                   see description of columns in InfobaseUpdate.NewUpdateHandlerTable.
//       * CompletedHandlers  - ValueTree - completed update handlers, grouped by
//                                   library and version number.
//                                   See column details in InfobaseUpdate.NewUpdateHandlerTable.
//       * MainServerModuleName - String - name of a library (configuration) module that contains
//                                        basic information about it: name, version, etc.
//       * MainServerModule      - CommonModule - library (configuration) common module which contains
//                                        basic information about it: name, version, etc.
//       * PreviousVersion             - String - for example, "2.1.3.30". Library (configuration) version number before an update.
//   OutputUpdatesDetails - Boolean - if False s set, a form
//                                containing description of new version updates will not be opened at first launch of a program. True by default.
//   ExclusiveMode           - Boolean - indicates that an update was executed in an exclusive mode.
//
// Example:
//  To avoid completed update handlers:
//  For Every UpdateIteration From UpdateIterations Cycle
//  	For Every Version From UpdateIteration.CompletedHandlers.Rows Cycle
//  		
//  		If Version.Version = "*" Then
//  			// A group of handlers that are executed regularly, on every other version.
//  		Else
//  			// A group of handlers that were executed for a particular version.
//  		EndIf;
//  		
//  		For Each Handler From Version.Rows Do
//  			…
//  		EndDo;
//  		
//  	EndDo;
//  EndDo;
//
Procedure AfterUpdateInfobase(Val PreviousIBVersion, Val CurrentIBVersion,
	Val UpdateIterations, OutputUpdatesDetails, Val ExclusiveMode) Export
	
	
EndProcedure

// Called upon creating a document containing details of new version updates
// that are displayed for the user at the first application startup (after update).
//
// Parameters:
//   Template - SpreadsheetDocument - description of new version updates automatically
//                               formed from the AppReleaseNotes common template.
//                               A template can be programmatically modified or substituted with another one.
//
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
EndProcedure

// Called before generating the deferred handler list.
// Allows you to perform an additional check of the deferred handler list.
//
// Parameters:
//   UpdateIterations     - Array - an array of structures providing information on and keys for updates of each
//                                     library or configuration:
//       * Subsystem              - String - name of a library or a configuration.
//       * Version                  - String - for example, "2.1.3.39". Library (configuration) version number.
//       * IsMainConfiguration - Boolean - True if it is a main configuration, not a library.
//       * Handlers             - ValueTable - all library update handlers;
//                                   see description of columns in InfobaseUpdate.NewUpdateHandlerTable.
//       * CompletedHandlers  - ValueTree - completed update handlers, grouped by
//                                   library and version number.
//                                   See column details in InfobaseUpdate.NewUpdateHandlerTable.
//       * MainServerModuleName - String - name of a library (configuration) module that contains
//                                        basic information about it: name, version, etc.
//       * MainServerModule      - CommonModule - library (configuration) common module which contains
//                                        basic information about it: name, version, etc.
//       * PreviousVersion             - String - for example, "2.1.3.30". Library (configuration) version number before an update.
//
// Example:
//  Iteration of all update handlers:
//  For Every UpdateIteration From UpdateIterations Do
//		If UpdateIteration.Subsystem = "OurSubsystemName" Then
//  		For Every Handler From UpdateIteration.Handlers Do
//  		
//  			If Handler.Version = "*" Then
//  				// A group of handlers regularly executed for every new version.
//  			Else
//  				// A group of handlers executed for a particular version.
//  			EndIf;
//  		
//  		EndDo;
//		EndIf;
//  EndDo;
//
Procedure BeforeGenerateDeferredHandlersList(UpdateIterations) Export
	
EndProcedure

// It is required to export new or changed details
// of update handlers to the code using the UpdateHandlersDetails data processor
// only by the subsystems that are developed in this configuration.
// 
//
// Parameters:
//   SubsystemsToDevelop - Array of String - names of subsystems to be developed in the current configuration, 
//                                                  a Subsystem name in the form set in the  
//                                                  InfobaseUpdateXXX common module.
//
Procedure WhenFormingAListOfSubsystemsUnderDevelopment(SubsystemsToDevelop) Export
	
	
	
EndProcedure

// Runs after metadata type order is created (for example, "Constants, Catalogs, Documents").
// Intended for overriding the update order for a metadata object.  
//
// Parameters:
//   PrioritizingMetadataTypes - Map of KeyAndValue - Metadata type update order.
//                   * Key - 
//                   * Value - Number - Update order.
//
// Example:
//   									
//
Procedure WhenPrioritizingMetadataTypes(PrioritizingMetadataTypes) Export
	
EndProcedure

// Called when the InfobaseUpdate.ObjectProcessed function is executed.
// Allows to write arbitrary logic to lock user changes to an object
// during the application update.
//
// Parameters:
//  FullObjectName - String - an object name for which the check is called.
//  BlockUpdate - Boolean - if you set True, the object
//                         will be opened only for reading. The default value is False.
//  MessageText   - String - a message that will be displayed to a user when opening an object.
//
Procedure OnExecuteCheckObjectProcessed(FullObjectName, BlockUpdate, MessageText) Export
	
EndProcedure

// Defines initial population settings.
// Intended for setting up built-in data population for read-only objects on support in other libraries.
// 
//
// Parameters:
//  FullObjectName - String - an object name for which filling is called.
//  Settings - Structure:
//   * OnInitialItemFilling - Boolean - if True, then the OnItemInitialFilling individual filling procedure will be
//      called for each item.
//   * PredefinedData - ValueTable - data filled in the OnInitialItemFilling procedure.
//
Procedure OnSetUpInitialItemsFilling(FullObjectName, Settings) Export
	
EndProcedure

// Runs upon initial data population.
// Intended for setting a description to an population 
// of a built-in read-only objects on support in other libraries.
//
// Parameters:
//  FullObjectName - String - an object name for which filling is called.
//  LanguagesCodes - Array - a list of configuration languages. Relevant to multilingual configurations.
//  Items   - ValueTable - filling data. Columns match the object attributes set.
//  TabularSections - Structure - object table details where:
//   * Key - String - tabular section name;
//   * Value - ValueTable - Value table.
//                                  Its structure must be copied before population. For example:
//                                  Item.Keys = TabularSections.Keys.Copy();
//                                  TSItem = Item.Keys.Add();
//                                  TSItem.KeyName = "Primary";
//
Procedure OnInitialItemsFilling(FullObjectName, LanguagesCodes, Items, TabularSections) Export
	
EndProcedure

// Runs upon initial data population of a created object.
// Intended for setting a description to an additional population or check
// of a built-in read-only objects on support in other libraries.
//
// Parameters:
//  FullObjectName - String - an object name for which filling is called.
//  Object                  - the object to fill in.
//  Data                  - ValueTableRow - object filling data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - data filled in the OnInitialItemFilling procedure.
//
Procedure OnInitialItemFilling(FullObjectName, Object, Data, AdditionalParameters) Export
	
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
// Parameters:
//  Objects - See InfobaseUpdate.AddObjectPlannedForDeletion.Objects
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
//  
//		
//		
//			
//
Procedure OnPopulateObjectsPlannedForDeletion(Objects) Export
	
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use 
// InfobaseUpdateOverridable.OnGenerateListOfSubsystemsToDevelop instead
//
Procedure OnGenerateListOfSubsystemsToDevelop(SubsystemsToDevelop) Export
	
	
EndProcedure

#EndRegion

#EndRegion
