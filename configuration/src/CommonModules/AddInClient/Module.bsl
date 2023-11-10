///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Parameters for the call of the AddInClient.AttachAddInSSL procedure.
//
// Returns:
//  Structure:
//      * Cached - Boolean - use component caching on the client (the default value is True).
//      * SuggestInstall - Boolean - (default value is True) prompt to install the add-in.
//      * SuggestToImport - Boolean - (default value is True) prompt to import the add-in from the ITS website.
//      * ExplanationText - String - a text that describes the add-in purpose and which functionality requires the add-in.
//      * ObjectsCreationIDs - Array - string array of object module instance.
//                Use it only for add-ins with several object creation IDs.
//                On specify, the ID parameter is used only to determine add-in.
//
// Example:
//
//  AttachmentParameters = AddInClient.AttachmentParameters();
//  AttachmentParameters.NoteText = 
//      AttachmentParameters.NoteText = NStr("en = 'To use a barcode scanner, install
//                 |the 1C:Barcode scanners (NativeApi) add-in.'");
//
Function ConnectionParameters() Export

	Return AddInsClient.ConnectionParameters();

EndFunction

// Attaches the add-in based on Native API or COM technologies on the client computer.
// Web client can display the dialog box with installation tips.
// Checking whether the add-in can be executed on the current user client.
//
// Parameters:
//  Notification - NotifyDescription - connection notification details with the following parameters:
//      * Result - Structure - add-in attachment result:
//          ** Attached - Boolean - attachment flag;
//          ** Attachable_Module - AddInObject - an instance of the add-in;
//                                - FixedMap of KeyAndValue - 
//                                      
//                                    *** Key - String - the add-in ID;
//                                    *** Value - AddInObject - an instance of the add-in.
//          ** ErrorDescription - String - brief error message. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  Id - String - the add-in identification code.
//  Version        - String - an add-in version.
//  ConnectionParameters - See AddInsClient.ConnectionParameters.
//
// Example:
//
//  Notification = New NotifyDescription("AttachAddInSSLCompletion", ThisObject);
//
//  AttachmentParameters = AddInClient.AttachmentParameters();
//  AttachmentParameters.NoteText = 
//      NStr("en = 'To use a barcode scanner, install
//                 |the 1C:Barcode scanners (NativeApi) add-in.'");
//
//  AddInClient.AttachAddInSSL(Notification,"InputDevice",, AttachmentParameters);
//
//  &AtClient
//  Procedure AttachAddInSSLCompletion(Result, AdditionalParameters) Export
//
//      AttachableModule = Undefined;
//
//      If Result.Attached Then 
//          AttachableModule = Result.AttachableModule;
//      Else
//          If Not IsBlankString(Result.ErrorDetails) Then
//              ShowMessageBox (, Result.ErrorDetails);
//          EndIf;
//      EndIf;
//
//      If AttachableModule <> Undefined Then 
//          // AttachableModule contains the instance of the attached add-in.
//      EndIf;
//
//      AttachableModule = Undefined;
//
//  EndProcedure
//
Procedure AttachAddInSSL(Notification, Id, Version = Undefined,
	ConnectionParameters = Undefined) Export

	AddInsClient.AttachAddInSSL(Notification, Id, Version, ConnectionParameters);

EndProcedure

// Attaches the add-in based on COM technology from Windows registry in asynchronous mode.
// (not recommended for backward compatibility with 1C:Enterprise 7.7 add-ins). 
//
// Parameters:
//  Notification - NotifyDescription - connection notification details with the following parameters:
//      * Result - Structure - add-in attachment result:
//          ** Attached - Boolean - attachment flag.
//          ** Attachable_Module - AddInObject  - an instance of the add-in.
//          ** ErrorDescription - String - brief error message.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  Id - String - the add-in identification code.
//  ObjectCreationID - String - object creation ID of object module instance
//          (only for add-ins with object creation ID different from ProgID).
//
// Example:
//
//  Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//  AddInClient.AttachAddInFromWindowsRegistry(Notification, "SBRFCOMObject", "SBRFCOMExtension");
//
//  &AtClient
//  Procedure AttachAddInSSLCompletion(Result, AdditionalParameters) Export
//
//      AttachableModule = Undefined;
//
//      If Result.Attached Then 
//          AttachableModule = Result.AttachableModule;
//      Else 
//          ShowMessageBox (, Result.ErrorDetails);
//      EndIf;
//
//      If AttachableModule <> Undefined Then 
//          // AttachableModule contains the instance of the attached add-in.
//      EndIf;
//
//      AttachableModule = Undefined;
//
//  EndProcedure
//
Procedure AttachAddInFromWindowsRegistry(Notification, Id,
	ObjectCreationID = Undefined) Export 

	AddInsClient.AttachAddInFromWindowsRegistry(Notification, Id, ObjectCreationID);

EndProcedure

// Parameter structure for see the InstallAddIn procedure. 
//
// Returns:
//  Structure:
//      * ExplanationText - String - a text that describes the add-in purpose and which functionality requires the add-in.
//      * SuggestToImport - Boolean - prompt to import the add-in from the ITS website
//      * SuggestInstall - Boolean - (default value is False) prompt to install the add-in.
//
// Example:
//
//  InstallationParameters = AddInClient.InstallationParameters();
//  InstallationParameters.NoteText = 
//      NStr("en = 'To use a barcode scanner, install
//                 |the 1C:Barcode scanners (NativeApi) add-in.'");
//
Function InstallationParameters() Export

	Return AddInsClient.InstallationParameters();

EndFunction

// Connects an add-in based on Native API and COM technology in an asynchronous mode.
// Checking whether the add-in can be executed on the current user client.
//
// Parameters:
//  Notification - NotifyDescription - notification details of add-in installation:
//      * Result - Structure - install component result:
//          ** IsSet - Boolean - installation flag.
//          ** ErrorDescription - String - brief error message. Empty string on cancel by user.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  Id - String - the add-in identification code.
//  Version - String - an add-in version.
//  InstallationParameters - See InstallationParameters.
//
// Example:
//
//  Notification = New NotifyDescription("SetCompletionComponent", ThisObject);
//
//  InstallationParameters = AddInClient.InstallationParameters();
//  InstallationParameters.ExplanationText = 
//      NStr("en = 'To use a barcode scanner, install
//                 |the 1C:Barcode scanners (NativeApi) add-in.'");
//
//  AddInClient.InstallAddIn(Notification,"InputDevice",, InstallationParameters);
//
//  &AtClient
//  Procedure InstallAddInEnd(Result, AdditionalParameters) Export
//
//      If Not Result.Installed and Not EmptyString(Result.ErrorDetails) Then 
//          ShowMessageBox (, Result.ErrorDetails);
//      EndIf;
//
//  EndProcedure
//
Procedure InstallAddInSSL(Notification, Id, Version = Undefined, 
	InstallationParameters = Undefined) Export

	AddInsClient.InstallAddInSSL(Notification, Id, Version, InstallationParameters);

EndProcedure

// Returns a parameter structure to describe search rules of additional information within an add-in.
// See the ImportAddInFromFile procedure.
//
// Returns:
//  Structure:
//      * XMLFileName - String - (optional) file name within an add-in from which information is extracted.
//      * XPathExpression - String - (optional) XPath path to information in the file.
//
// Example:
//
//  ImportParameters = AddInClient.AdditionalInformationSearchParameters();
//  ImportParameters.XMLFileName = "INFO.XML";
//  ImportParameters.XPathExpression = "//drivers/component/@type";
//
Function AdditionalInformationSearchParameters() Export

	Return AddInsClient.AdditionalInformationSearchParameters();

EndFunction

// Parameter structure for see the AttachAddInSSL procedure.ImportComponentFromFile. 
//
// Returns:
//  Structure:
//      * Id - String -(optional) add-in object ID.
//      * Version - String - (optional) a component version.
//      * AdditionalInformationSearchParameters - Map of KeyAndValue - (optional) parameters:
//          ** Key - String - requested additional information ID.
//          ** Value - See AdditionalInformationSearchParameters.
// Example:
//
//  ImportParameters = AddInClient.ImportParameters();
//  ImportParameters.ID = "InputDevice";
//  ImportParameters.Version = "8.1.7.10";
//
Function ImportParameters() Export

	Return AddInsClient.ImportParameters();

EndFunction

// Imports add-in file to the add-ins catalog in asynchronous mode. 
//
// Parameters:
//  Notification - NotifyDescription - notification details of add-in installation:
//      * Result - Structure - import add-in result:
//          ** Imported1 - Boolean - imported flag.
//          ** Id  - String - the add-in identification code.
//          ** Version - String - version of the imported add-in.
//          ** Description - String - version of the imported add-in.
//          ** AdditionalInformation - Map of KeyAndValue - additional information on an add-in;
//                     if not requested – blank map:
//               *** Key - See AdditionalInformationSearchParameters.
//               *** Value - See AdditionalInformationSearchParameters.
//      * AdditionalParameters - Structure - a value that was specified on creating the NotifyDescription object.
//  ImportParameters - See ImportParameters.
//
// Example:
//
//  ImportParameters = AddInClient.ImportParameters();
//  ImportParameters.ID = "InputDevice";
//  ImportParameters.Version = "8.1.7.10";
//
//  Notification = New NotifyDescription("LoadAddInFromFileAfterAddInImport", ThisObject);
//
//  AddInClient.ImportAddInsFromFile(Notification, ImportParameters);
//
//  &AtClient
//  Procedure LoadAddInFromFileAfterAddInImport(Result, AdditionalParameters) Export
//
//      If Result.Imported Then 
//          ID = Result.ID;
//          Version = Result.Version;
//      EndIf;
//
//  EndProcedure
//
Procedure ImportAddInFromFile(Notification, ImportParameters = Undefined) Export

	AddInsClient.ImportAddInFromFile(Notification, ImportParameters);

EndProcedure

#EndRegion