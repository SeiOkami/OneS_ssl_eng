///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure:
//   * UseSignaturesAndSeals - Boolean - if it is set to False, the ability to set signatures 
//                                           and seals in print forms is disabled.
//   * HideSignaturesAndSealsForEditing - Boolean - delete pictures of signatures and seals of spreadsheet documents when
//                                           unchecking the "Signatures and Seals" checkbox in the "Print Documents" form
//                                           so that they do not interfere with editing the text below them.
//   * CheckPostingBeforePrint    - Boolean -
//                                        
//                                        See PrintManagement.CreatePrintCommandsCollection.
//                                        
//                                        
//   * PrintObjects - Array -
//
Procedure OnDefinePrintSettings(Settings) Export
	
	
	
EndProcedure

// Allows to override a list of print commands in an arbitrary form.
// Can be used for common forms that do not have a manager module to place the AddPrintCommands procedure in it
// and when the standard functionality is not enough to add commands to such forms. 
// For example, if common forms require specific print commands.
// It is called from the PrintManagement.FormPrintCommands.
// 
// Parameters:
//  FormName             - String - a full name of form, in which print commands are added;
//  PrintCommands        - See PrintManagement.CreatePrintCommandsCollection
//  StandardProcessing - Boolean - when setting to False, the PrintCommands collection will not be filled in automatically.
//
// Example:
//  If FormName = "CommonForm.DocumentJournal" Then
//    If Users.RolesAvailable("PrintProformaInvoiceToPrinter") Then
//      PrintCommand = PrintCommands.Add();
//      PrintCommand.ID = "Invoice";
//      PrintCommand.Presentation = NStr("en = 'Proforma invoice to printer)'");
//      PrintCommand.Picture = PictureLib.PrintImmediately;
//      PrintCommand.CheckPostingBeforePrint = True;
//      PrintCommand.SkipPreview = True;
//    EndIf;
//  EndIf;
//
Procedure BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing) Export
	
EndProcedure

// Allows to set additional print command settings in document journals.
//
// Parameters:
//  ListSettings - Structure - print command list modifiers:
//   * PrintCommandsManager     - CommonModule - an object manager, in which the list of print commands is generated;
//   * AutoFilling - Boolean - filling print commands from the objects included in the journal.
//                                         If the value is False, the list of journal print commands will be
//                                         filled by calling the AddPrintCommands method from the journal manager module.
//                                         The default value is True - the AddPrintCommands method will be called from
//                                         the document manager modules from the journal.
//
// Example:
//   If ListSettings.PrintCommandsManager = "DocumentJournal.WarehouseDocuments" Then
//     ListSettings.Autofill = False;
//   EndIf;
//
Procedure OnGetPrintCommandListSettings(ListSettings) Export
	
EndProcedure

// Allows you to post-process print forms while generating them.
// For example, you can insert a generation date into a print form.
// It is called after completing the Print procedure of the object print manager and has the same parameters.
// Not called upon calling PrintManagementClient.PrintDocuments.
//
// Parameters:
//  ObjectsArray - Array of AnyRef - a list of objects for which the print command is being executed;
//  PrintParameters - Structure - arbitrary parameters passed when calling the print command;
//  PrintFormsCollection - ValueTable - a return parameter, a collection of generated print forms:
//   * TemplateName - String - print form ID;
//   * TemplateSynonym - String - a print form name;
//
//   * SpreadsheetDocument - SpreadsheetDocument - one or several print forms output to one spreadsheet document
//                         To layout print forms inside a spreadsheet document, after outputting every print form,
//                         call the PrintManagement.SetDocumentPrintArea procedure;
//                         The parameter is not used if print forms are output in the office document format
//                         (see the "OfficeDocuments" parameter);
//
//   * OfficeDocuments - Map of KeyAndValue - a collection of print forms in the format of office documents:
//                         ** Key - String - an address in the temporary storage of binary data of the print form;
//                         ** Value - String - a print form file name.
//
//   * PrintFormFileName - String - a print form file name upon saving to a file or sending as
//                                      an email attachment. Do not use for print forms in the office document format.
//                                      By default, a file name is set as
//                                      "[НазваниеПечатнойФормы] # [Номер] from [Дата]" for documents and
//                                      "[НазваниеПечатнойФормы] — [ПредставлениеОбъекта] — [ТекущаяДата]" for objects.
//                           - Map of KeyAndValue - 
//                              ** Key - AnyRef - a reference to a print object from the ObjectsArray collection;
//                              ** Value - String - file name;
//
//   * Copies2 - Number - a number of copies to be printed;
//   * FullTemplatePath - String - used for quick access to print form template editing
//                                  in the PrintDocuments common form;
//   * OutputInOtherLanguagesAvailable - Boolean - set to True if the print form is adapted
//                                            for output in an arbitrary language.
//  
//  PrintObjects - ValueList - an output parameter, mapping between objects and area names in spreadsheet
//                                   documents is filled in automatically
//                                   upon calling PrintManagement.SetDocumentPrintArea:
//   * Value - AnyRef - a reference from the ObjectsArray collection,
//   * Presentation - String - an area name with the object in spreadsheet documents;
//
//  OutputParameters - Structure - print form output settings:
//   * SendOptions - Structure - for automatic filling fields in the message creation form upon sending 
//                                     generated print forms by email:
//     ** Recipient - See EmailOperationsClient.EmailSendOptions.Получатель
//     ** Subject       - See EmailOperationsClient.EmailSendOptions.Тема
//     ** Text      - See EmailOperationsClient.EmailSendOptions.Текст
//   * LanguageCode - String - a language in which the print form needs to be generated.
//                         Consists of the ISO 639-1 language code and the ISO 3166-1 country code (optional)
//                         separated by the underscore character. Examples: "en", "en_US", "en_GB", "ru", "ru_RU".
//
//   * FormCaption - String - overrides title of the document printing form (PrintDocuments).
//
// Example:
//
//  PrintForm = PrintManagement.PrintFormInfo(PrintFormsCollection, "<PrintFormID>");
//  If PrintForm <> Undefined Then
//    SpreadsheetDocument = New SpreadsheetDocument;
//    SpreadsheetDocument.PrintParametersKey = "<PrintFormParametersSaveKey>"
//    For Every Ref From ObjectsArray Do
//      If SpreadsheetDocument.TableHeight > 0 Then
//        SpreadsheetDocument.PutHorizontalPageBreak();
//      EndIf;
//      AreaStart = SpreadsheetDocument.TableHeight + 1;
//      // … code for spreadsheet document generation …
//      PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, AreaStart, PrintObjects, Ref);
//    EndDo;
//    PrintForm.SpreadsheetDocument = SpreadsheetDocument;
//  EndIf;
//
Procedure OnPrint(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	
	
EndProcedure

// 
//
// Parameters:
//  PrintFormID - String - ID of the printed form;
//  PrintObjects      - Array    - collection of links to print objects;
//  PrintParameters - Structure - custom parameters passed when calling the print command;
//
Procedure BeforePrint(Val PrintFormID, PrintObjects, PrintParameters) Export 
	
	
	
EndProcedure

// Overrides the print form send parameters when preparing a message.
// It can be used, for example, to prepare a message text.
//
// Parameters:
//  SendOptions - Structure:
//   * Recipient - Array - a collection of recipient names;
//   * Subject - String - an email subject;
//   * Text - String - an email text;
//   * Attachments - Structure:
//    ** AddressInTempStorage - String - an attachment address in a temporary storage;
//    ** Presentation - String - an attachment file name.
//  PrintObjects - Array - a collection of objects, by which print forms are generated.
//  OutputParameters - Structure - the OutputParameters parameter when calling the Print procedure.
//  PrintForms - ValueTable - a collection of spreadsheet documents:
//   * Name1 - String - a print form name;
//   * SpreadsheetDocument - SpreadsheetDocument - print form.
//
Procedure BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects, PrintForms) Export
	
	
	
EndProcedure

// Defines a set of signatures and seals for documents.
//
// Parameters:
//  Var_Documents      - Array    - a collection of references to print objects;
//  SignaturesAndSeals - Map of KeyAndValue - a collection of print objects and their sets of signatures/and seals:
//   * Key     - AnyRef - a reference to the print object;
//   * Value - Structure   - a set of signatures and seals:
//     ** Key     - String - an ID of signature or seal in print form template. 
//                            It must start with "Signature…", "Seal…", or "Facsimile",
//                            for example, ManagerSignature or CompanySeal;
//     ** Value - Picture - a picture of signature or seal.
//
Procedure OnGetSignaturesAndSeals(Var_Documents, SignaturesAndSeals) Export
	
	
	
EndProcedure

// It is called from the OnCreateAtServer handler of the document print form (CommonForm.PrintDocuments).
// Allows to change form appearance and behavior, for example, place the following additional items on it:
// information labels, buttons, hyperlinks, various settings, and so on.
//
// When adding commands (buttons), specify the Attachable_ExecuteCommand name as a handler
// and place its implementation either to PrintManagementOverridable.PrintDocumentsOnExecuteCommand (server part),
// or to PrintManagementClientOverridable.PrintDocumentsExecuteCommand (client part).
//
// To add your command to the form.
// 1. Create a command and a button in PrintManagementOverridable.PrintDocumentsOnCreateAtServer.
// 2. Implement the command client handler in PrintManagementClientOverridable.PrintDocumentsExecuteCommand.
// 3. (Optional) Implement server command handler in PrintManagementOverridable.PrintDocumentsOnExecuteCommand.
//
// When adding hyperlinks as a click handler, specify the Attachable_URLProcessing name
// and place its implementation to PrintManagementClientOverridable.PrintDocumentsURLProcessing.
//
// When placing items whose values must be remembered between print form openings,
// use the PrintDocumentsOnImportDataFromSettingsAtServer and
// PrintDocumentsOnSaveDataInSettingsAtServer procedures.
//
// Parameters:
//  Form                - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Cancel                - Boolean - indicates that the form creation is canceled. If this parameter is set
//                                  to True, the form is not created.
//  StandardProcessing - Boolean - a flag indicating whether the standard (system) event processing is executed is passed to this
//                                  parameter. If this parameter is set to False, 
//                                  standard event processing will not be carried out.
// 
// Example:
//  FormCommand = Form.Command.Add("MyCommand");
//  FormCommand.Action = "Attachable_ExecuteCommand";
//  FormCommand.Header = NStr("en = 'MyCommand…'");
//  
//  FormButton = Form.Items.Add(FormCommand.Name, Type("FormButton"), Form.Items.CommandBarRightPart);
//  FormButton.Kind = FormButtonKind.CommandBarButton;
//  FormButton.CommandName = FormCommand.Name;
//
Procedure PrintDocumentsOnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	
	
EndProcedure

// It is called from the OnImportDataFromSettingsAtServer handler of the document print form (CommonForm.PrintDocuments).
// Together with PrintDocumentsOnSaveDataInSettingsAtServer, it allows you to import and save form control 
// settings placed using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form     - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Settings - Map     - form attribute values.
//
Procedure PrintDocumentsOnImportDataFromSettingsAtServer(Form, Settings) Export
	
EndProcedure

// It is called from the OnSaveDataInSettingsAtServer handler of the document print form (CommonForm.PrintDocuments).
// Together with PrintDocumentsOnImportDataFromSettingsAtServer, it allows you to import and save form control 
// settings placed using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form     - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  Settings - Map     - form attribute values.
//
Procedure PrintDocumentsOnSaveDataInSettingsAtServer(Form, Settings) Export

EndProcedure

// It is called from the Attachable_ExecuteCommand handler of the document printing form (CommonForm.PrintDocuments).
// It allows you to implement server part of the command handler added to the form 
// using PrintDocumentsOnCreateAtServer.
//
// Parameters:
//  Form                   - ClientApplicationForm - the CommonForm.PrintDocuments form.
//  AdditionalParameters - Arbitrary     - parameters passed from PrintManagementClientOverridable.PrintDocumentsExecuteCommand.
//
// Example:
//  If TypeOf(AdditionalParameters) = Type("Structure") AND AdditionalParameters.CommandName = "MyCommand" Then
//   SpreadsheetDocument = New SpreadsheetDocument;
//   SpreadsheetDocument.Area("R1C1").Text = NStr("en = 'An example of using a server handler of the attached command.'");
//  
//   PrintForm = Form[AdditionalParameters.SpreadsheetDocumentAttributeName];
//   PrintFrom.InsertArea(SpreadsheetDocument.Area("R1"), PrintForm.Area("R1"), 
//    SpreadsheetDocumentShiftType.Horizontally)
//  EndIf;
//
Procedure PrintDocumentsOnExecuteCommand(Form, AdditionalParameters) Export
	
EndProcedure

// 
// 
// 
// 
//
// Parameters:
//  Object - String - Full name of a metadata object.
//                      Or the name of the field from the PrintData template in the format "FullMetadataName.FieldName".
//  PrintDataSources - ValueList:
//    * Value - DataCompositionSchema -
//                                         
//                                         
//                                         
//                                         
//                                         
//      
//    * Presentation - String - Schema ID. Intended to export data.
//    * Check -Boolean - True if the key field is the data source owner.
//
Procedure OnDefinePrintDataSources(Object, PrintDataSources) Export
	
	
	
EndProcedure

// Prepares printable data.
//
// Parameters:
//  DataSources - Array - Objects whose data is being printed out.
//  ExternalDataSets - Structure - Collection of datasets to pass to the data composition processor.
//  DataCompositionSchemaId - String - DCS ID specified in 
//  LanguageCode - String - Language of the data being printed out.
//  AdditionalParameters - Structure:
//   * DataSourceDescriptions - ValueTable - Additional info about objects whose data is being printed out.
//   * SourceDataGroupedByDataSourceOwner - Boolean - Flag indicating whether after composing the print data is grouped in the print schema by the print object owner.
//                           
//  
Procedure WhenPreparingPrintData(DataSources, ExternalDataSets, DataCompositionSchemaId, LanguageCode,
	AdditionalParameters) Export
	
	
	
EndProcedure

// 
//
// Parameters:
//   FullMetadataObjectName   - MetadataObject -
//   PrintCommands 		- See PrintManagement.CreatePrintCommandsCollection
//
Procedure OnReceivePrintCommands(Val FullMetadataObjectName, PrintCommands) Export
	
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated.
// 
// 
// 
//
// Parameters:
//  ListOfObjects - Array - object managers with the AddPrintCommands procedure.
//
Procedure OnDefineObjectsWithPrintCommands(ListOfObjects) Export
		
EndProcedure

#EndRegion

#EndRegion

