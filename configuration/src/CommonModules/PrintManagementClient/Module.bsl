///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Generates and displays print forms.
// 
// Parameters:
//  PrintManagerName - String - a print manager for the objects to print;
//  TemplatesNames       - String - print form IDs;
//  ObjectsArray     - AnyRef
//                     - Array of AnyRef - 
//  FormOwner      - ClientApplicationForm - a form from which the printing is executed;
//  PrintParameters    - Structure - arbitrary parameters to pass to the print manager.
//
// Example:
//   PrintManagementClient.ExecutePrintCommand("DataProcessor.PrintForm", "GoodsWriteOff", DocumentsForPrinting, ThisObject);
//
Procedure ExecutePrintCommand(PrintManagerName, TemplatesNames, ObjectsArray, FormOwner, PrintParameters = Undefined) Export
	
	If Not CheckPassedObjectsCount(ObjectsArray) Then
		Return;
	EndIf;
	
	OpeningParameters = PrintManagementInternalClient.ParametersForOpeningPrintForm();
	OpeningParameters.PrintManagerName = PrintManagerName;
	OpeningParameters.TemplatesNames		 = TemplatesNames;
	OpeningParameters.CommandParameter	 = ObjectsArray;
	OpeningParameters.PrintParameters	 = PrintParameters;
	
	If FormOwner = Undefined Then
		OpeningParameters.StorageUUID = New UUID;
	Else
		OpeningParameters.StorageUUID = FormOwner.UUID;
	EndIf;
		
	TimeConsumingOperation = PrintManagementServerCall.StartGeneratingPrintForms(OpeningParameters);
	OpeningParameters.FormOwner = FormOwner;
	
	CompletionNotification2 = New NotifyDescription("ExecutePrintCommandAfterFormationOfPrintedForms", ThisObject, OpeningParameters);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, PrintManagementInternalClient.IdleParameters(FormOwner));	
EndProcedure

// Generates and outputs print forms to the printer.
//
// Parameters:
//  PrintManagerName - String - a print manager for the objects to print;
//  TemplatesNames       - String - print form IDs;
//  ObjectsArray     - AnyRef
//                     - Array of AnyRef - 
//  PrintParameters    - Structure - arbitrary parameters to pass to the print manager.
//
// Example:
//   PrintManagementClient.ExecutePrintToPrinterCommand("DataProcessor.PrintForm", "GoodsWriteOff", DocumentsForPrinting);
//
Procedure ExecutePrintToPrinterCommand(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters = Undefined) Export

	// Check the number of objects.
	If Not CheckPassedObjectsCount(ObjectsArray) Then
		Return;
	EndIf;
	
	// Generate spreadsheet documents.
#If ThickClientOrdinaryApplication Then
	PrintForms = PrintManagementServerCall.GeneratePrintFormsForQuickPrintOrdinaryApplication(
			PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters);
	If Not PrintForms.Cancel Then
		PrintObjects = New ValueList;
		For Each PrintObject In PrintForms.PrintObjects Do
			PrintObjects.Add(PrintObject.Value, PrintObject.Key);
		EndDo;
		PrintForms.PrintObjects = PrintObjects;
	EndIf;
#Else
	PrintForms = PrintManagementServerCall.GeneratePrintFormsForQuickPrint(
			PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters);
#EndIf
	
	If PrintForms.Cancel Then
		CommonClient.MessageToUser(NStr("en = 'Insufficient rights to print out the form. Contact your administrator.';"));
		Return;
	EndIf;
	
	// Print out.
	PrintSpreadsheetDocuments(PrintForms.SpreadsheetDocuments, PrintForms.PrintObjects);
	
	// StandardSubsystems.SourceDocumentsOriginalsRecording
	If CommonClient.SubsystemExists("StandardSubsystems.SourceDocumentsOriginalsRecording") Then
		PrintList = New ValueList;
		For Each Template In PrintForms.SpreadsheetDocuments Do 
			PrintList.Add(TemplatesNames, Template.Presentation);
		EndDo;
	  	ModuleSourceDocumentsOriginalsAccountingClient = CommonClient.CommonModule("SourceDocumentsOriginalsRecordingClient");
		ModuleSourceDocumentsOriginalsAccountingClient.WriteOriginalsStatesAfterPrint(PrintForms.PrintObjects, PrintList);
	EndIf;
	// End StandardSubsystems.SourceDocumentsOriginalsRecording

EndProcedure

// Outputting spreadsheet documents to the printer.
//
// Parameters:
//  SpreadsheetDocuments           - ValueList - print forms.
//  PrintObjects                - ValueList - a correspondence between objects and names of spreadsheet document areas.
//  PrintInSets          - Boolean
//                               - Undefined - 
//  SetCopies    - Number - a number of each document set copies.
//
Procedure PrintSpreadsheetDocuments(SpreadsheetDocuments, PrintObjects, Val PrintInSets = Undefined, 
	Val SetCopies = 1) Export
	
	PrintInSets = SpreadsheetDocuments.Count() > 1;
	RepresentableDocumentBatch = PrintManagementServerCall.DocumentsPackage(SpreadsheetDocuments,
		PrintObjects, PrintInSets, SetCopies);
	RepresentableDocumentBatch.Print(PrintDialogUseMode.DontUse);
	
EndProcedure

// Executes interactive document posting before printing.
// If there are unposted documents, prompts the user to post them. Asks
// the user whether they want to continue if any of the documents are not posted and at the same time some of the documents are posted.
//
// Parameters:
//  CompletionProcedureDetails - NotifyDescription - a procedure, to which control after
//                                                     execution is transferred.
//                                Parameters of the procedure being called:
//                                  DocumentsList - Array - posted documents;
//                                  AdditionalParameters - a value specified when creating a notification
//                                                            object.
//  DocumentsList            - Array            - references to the documents that require posting.
//  Form                       - ClientApplicationForm  - a form the command is called from. The parameter
//                                                    is required to reread the form when the procedure
//                                                    is called from the object form.
//
Procedure CheckDocumentsPosting(CompletionProcedureDetails, DocumentsList, Form = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CompletionProcedureDetails", CompletionProcedureDetails);
	AdditionalParameters.Insert("DocumentsList", DocumentsList);
	AdditionalParameters.Insert("Form", Form);
	
	UnpostedDocuments = CommonServerCall.CheckDocumentsPosting(DocumentsList);
	HasUnpostedDocuments = UnpostedDocuments.Count() > 0;
	If HasUnpostedDocuments Then
		AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
		PrintManagementInternalClient.CheckDocumentsPostedPostingDialog(AdditionalParameters);
	Else
		ExecuteNotifyProcessing(CompletionProcedureDetails, DocumentsList);
	EndIf;
	
EndProcedure

// Opens the PrintDocuments form for a spreadsheet document collection.
//
// Parameters:
//  PrintFormsCollection - Array of See NewPrintFormsCollection
//  PrintObjects - ValueList - See PrintManagementOverridable.OnPrint
//  AdditionalParameters - See PrintParameters
//                          - ClientApplicationForm - a form, from which the printing is executed;
//
Procedure PrintDocuments(PrintFormsCollection, Val PrintObjects = Undefined,
	AdditionalParameters = Undefined) Export
	
	PrintParameters = PrintParameters();
	
	FormOwner = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(PrintParameters, AdditionalParameters);
		FormOwner = PrintParameters.FormOwner;
		PrintParameters.Delete("FormOwner");
	ElsIf TypeOf(AdditionalParameters) = Type("ClientApplicationForm") Then 
		FormOwner = AdditionalParameters; // 
	EndIf;
	
	If PrintObjects = Undefined Then
		PrintObjects = New ValueList;
	EndIf;
	
	UniqueKey = String(New UUID);
	
	OpeningParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
	OpeningParameters.CommandParameter = New Array;
	OpeningParameters.Insert("PrintFormsCollection", PrintFormsCollection);
	OpeningParameters.Insert("PrintObjects", PrintObjects);
	OpeningParameters.Insert("PrintParameters", PrintParameters);
	
	OpenForm("CommonForm.PrintDocuments", OpeningParameters, FormOwner, UniqueKey);
	
EndProcedure

// Constructor of the AdditionalParameters parameter of the PrintDocuments procedure.
//
//  Returns:
//   Structure - 
//    * FormOwner - ClientApplicationForm - a form from which the printing is executed.
//    * Title     - String - a title of the PrintDocuments form.
//
Function PrintParameters() Export
	
	Result = New Structure;
	Result.Insert("FormOwner");
	Result.Insert("FormCaption");
	
	Return Result;
	
EndFunction

// Constructor of the PrintFormsCollection parameter for procedures and functions of this module.
// See PrintDocuments()
// See PrintFormDetails().
//
// Parameters:
//  IDs - String - print form IDs.
//
// Returns:
//  Array - 
//           
//           
//
Function NewPrintFormsCollection(Val IDs) Export
	
	If TypeOf(IDs) = Type("String") Then
		IDs = StrSplit(IDs, ",");
	EndIf;
	
	Fields = PrintManagementClientServer.PrintFormsCollectionFieldsNames();
	AddedPrintForms = New Map;
	Result = New Array;
	
	For Each Id In IDs Do
		PrintForm = AddedPrintForms[Id];
		If PrintForm = Undefined Then
			PrintForm = New Structure(StrConcat(Fields, ","));
			PrintForm.TemplateName = Id;
			PrintForm.UpperCaseName = Upper(Id);
			PrintForm.Copies2 = 1;
			AddedPrintForms.Insert(Id, PrintForm);
			Result.Add(PrintForm);
		Else
			PrintForm.Copies2 = PrintForm.Copies2 + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns description of the print form found in the collection.
// If the description does not exist, returns Undefined.
//
// Parameters:
//  PrintFormsCollection - Array of See NewPrintFormsCollection.
//  Id         - String - print form ID.
//
// Returns:
//  Structure - 
//   * TemplateSynonym - String - a print form presentation;
//   * SpreadsheetDocument - SpreadsheetDocument - print form;
//   * Copies2 - Number - a number of copies to be printed;
//   * FullTemplatePath - String - used for quick access to print form template editing;
//   * PrintFormFileName - String - file name;
//                           - Map of KeyAndValue - 
//                              ** Key - AnyRef - a reference to the print object;
//                              ** Value - String - file name;
//   * OfficeDocuments - Map of KeyAndValue - a collection of print forms in the format of office documents:
//                         ** Key - String - an address in the temporary storage of binary data of the print form;
//                         ** Value - String - a print form file name.
//
Function PrintFormDetails(PrintFormsCollection, Id) Export
	For Each PrintFormDetails In PrintFormsCollection Do
		If PrintFormDetails.UpperCaseName = Upper(Id) Then
			Return PrintFormDetails;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

// Opens a selection form of template opening mode.
//
Procedure SetActionOnChoosePrintFormTemplate() Export
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.SelectTemplateOpeningMode");
	
EndProcedure

// Opens a form showing how to create a facsimile signature and a seal.
Procedure ShowInstructionOnHowToCreateFacsimileSignatureAndSeal() Export
	
	ScanAvailable = False;
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ScanAvailable = ModuleFilesOperationsClient.ScanAvailable();
	EndIf;
	GenerationParameters = New Structure ("ScanAvailable", ScanAvailable);
	ExecutePrintCommand("InformationRegister.CommonSuppliedPrintTemplates", "GuideToCreateFacsimileAndStamp", 
		PredefinedValue("Catalog.MetadataObjectIDs.EmptyRef"), Undefined, GenerationParameters);
	
EndProcedure

// To be used in the procedures of the PrintManagementClientOverridable.PrintDocuments module<…>.
// Returns a collection of the current print form parameters in the "Print documents" form (CommonForm.PrintDocuments).
// 
// Parameters:
//  Form - ClientApplicationForm - PrintDocuments form passed in the Form parameter of the common module procedure
//                             PrintManagementClientOverridable.
//
// Returns:
//  FormDataCollectionItem - 
//
Function CurrentPrintFormSetup(Form) Export
	Result = Form.Items.PrintFormsSettings.CurrentData;
	If Result = Undefined And Form.PrintFormsSettings.Count() > 0 Then
		Result = Form.PrintFormsSettings[0];
	EndIf;
	Return Result;
EndFunction

// 
// 
// Returns:
//  Structure:
//   * Form - ClientApplicationForm - a form where printing is executed.
//   * PrintObjects - Array of AnyRef - objects by which print forms must be generated.
//   * Id - String - a print command ID. The print manager uses this ID to determine a print
//                              form to be generated.
//                              For example, "OrderInvoice".
//
//                              To print multiple print forms, you can specify all their
//                              IDs at once (as a comma-separated string or an array of strings), for example:
//                              "OrderInvoice,WarrantyLetter".
//
//                              To set a number of copies for a print form, duplicate its
//                              ID as many times as the number of copies you want
//                              generated. Consider that the order of print
//                              forms in the set matches the order of print form IDs
//                              specified in this parameter. For example (2 proforma invoices + 1 warranty letter):
//                              "OrderInvoice,OrderInvoice,WarrantyLetter".
//
//                              A print form ID can contain an alternative print
//                              manager if it is different from the print manager specified in the PrintManager parameter,
//                              for example: "OrderInvoice,Processing.PrintForm.WarrantyLetter".
//
//                              In this example, WarrantyLetter is generated in the
//                              Processing.PrintForm print manager and OrderInvoice is generated in the print manager specified in
//                              the PrintManager parameter.
//
//                   - Array - 
//
//   * PrintManager - String           - (optional) name of the object whose manager module contains
//                                        the Print procedure that generates spreadsheet documents for this command.
//                                        Default value is a name of the object manager module.
//                                         For example, "Document.ProformaInvoice".
//
//   * Handler    - String            - (optional) command client handler
//                                        executed instead of the standard Print command handler. It is used,
//                                        for example, when the print form is generated on the client.
//                                        Format "<CommonModuleName>.<ProcedureName>" is used when the procedure is
//                                        in a common module.
//                                        The"<ProcedureName>" format is used when the procedure is placed
//                                        in the main form module of a report or a data processor specified in PrintManager.
//                                        For example,
//                                          PrintCommand.Handler = "_DemoStandardSubsystemsClient.PrintProformaInvoices";
//                                        An example of handler in the form module:
//                                          // Generates a print form <print form presentation>.
//                                          //
//                                          //
//                                          // Parameters:
//                                          //   PrintParameters - Structure - a print form info.
//                                          //       * PrintObjects - Array — an array of selected object references.
//                                          //       * Form — ClientApplicationForm - a form, from which the
//                                          //                                              print command is called from.
//                                          //       * AdditionalParameters — Structure — additional print parameters.
//                                          //       Other structure keys match the columns of the PrintCommands table, 
//                                          //
//                                          //       for more information, see the PrintManagement.CreatePrintCommandsCollection function.
//                                          //
//                                          	&AtClient
//                                          Function <FunctionName>(PrintParameters) Export
//                                        // Print handler.
//                                        EndFunction
//                                        Remember that the handler is called using the Calculate method,
//                                        so only a function can act as a handler.
//                                        The return value of the function is not used by the subsystem.
//
//   * SkipPreview - Boolean           - (Optional) Flag indicating whether the documents must be sent to a printer without a preview.
//                                        If not specified, the print command opens the "Print documents" preview form.
//                                        
//
//   * SaveFormat - SpreadsheetDocumentFileType - (optional) used for quick saving of a print
//                                        form (without additional actions) to non-MXL formats.
//                                        If the parameter is not specified, the print form is saved to an MXL format.
//                                        For example, SpreadsheetDocumentFileType.PDF.
//
//                                        In this example, selecting a print command opens a PDF
//                                        document.
//
//   * FormCaption  - String          - (optional) an arbitrary string overriding the standard header of
//                                         the Print documents form.
//                                         For example, "Customize set".
//
//   * OverrideCopiesUserSetting - Boolean - (optional) shows whether the option to save or restore the number of copies selected by
//                                        user for printing in
//                                        the PrintDocuments form is to be disabled. If the parameter is not specified,
//                                        the option of saving or restoring settings will be applied upon opening the form.
//                                        PrintDocuments.
//
//   * AddExternalPrintFormsToSet - Boolean - (optional) shows whether the document set is to be supplemented
//                                        with all external print forms connected to the object
//                                        (the AdditionalReportsAndDataProcessors subsystem). If the parameter is not specified, external
//                                        print forms are not added to the set.
//   * FixedSet - Boolean    - (optional) shows whether users can change
//                                        the document set. If the parameter is not specified, the user can
//                                        exclude some print forms from the set in the PrintDocuments form and
//                                        change the number of copies.
//
//   * AdditionalParameters - Structure - (optional) arbitrary parameters to pass to the print manager.
//
//
Function DescriptionOfPrintParameters() Export
	
	Result = New Structure;
	Result.Insert("Form");
	Result.Insert("PrintObjects");
	Result.Insert("Id");
	Result.Insert("PrintManager");
	Result.Insert("Handler");
	Result.Insert("SkipPreview");
	Result.Insert("SaveFormat");
	Result.Insert("FormCaption");
	Result.Insert("OverrideCopiesUserSetting");
	Result.Insert("AddExternalPrintFormsToSet");
	Result.Insert("FixedSet");
	Result.Insert("AdditionalParameters");
	
	Return Result;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates.

//	
//	
//
////////////////////////////////////////////////////////////////////////////////
//	
//	
//	
//	
//						
//						
//	
//	
//							
////////////////////////////////////////////////////////////////////////////////
//	
//	
//	
//							
//							
//							
//							
//

////////////////////////////////////////////////////////////////////////////////
// Functions for initializing and closing references.

// Deprecated. Obsolete. Use PrintManagement.InitializePrintForm.
//
// Creates a connection to the output print form.
// Call this function before performing any actions on the form.
// The function does not work in any other browsers except for Internet Explorer.
// This function requires 1C:Enterprise Extension installed to operate in the web client.
//
// Parameters:
//  DocumentType            - String - a print form type: DOC or ODT;
//  TemplatePagesSettings - Map - parameters from the structure returned by the InitializeTemplate function
//                                           (the parameter is obsolete, skip it and use the Template parameter);
//  Template                   - Structure - a result of the InitializeTemplate function.
//
// Returns:
//  Structure - 
// 
Function InitializePrintForm(Val DocumentType, Val TemplatePagesSettings = Undefined, Template = Undefined) Export
	
	If Upper(DocumentType) = "DOC" Then
		Parameter = ?(Template = Undefined, TemplatePagesSettings, Template); // 
		PrintForm = PrintManagementMSWordClient.InitializeMSWordPrintForm(Parameter);
		PrintForm.Insert("Type", "DOC");
		PrintForm.Insert("LastOutputArea", Undefined);
		Return PrintForm;
	ElsIf Upper(DocumentType) = "ODT" Then
		PrintForm = PrintManagementOOWriterClient.InitializeOOWriterPrintForm(Template);
		PrintForm.Insert("Type", "ODT");
		PrintForm.Insert("LastOutputArea", Undefined);
		Return PrintForm;
	EndIf;
	
EndFunction

// Deprecated. Obsolete. Use PrintManagement.InitializeOfficeDocumentTemplate.
//
// Creates a COM connection with a template. This connection is used later for getting template areas (tags and
// tables).
// The function does not work in any other browsers except for Internet Explorer.
// This function requires 1C:Enterprise Extension installed to operate in the web client.
//
// Parameters:
//  BinaryTemplateData - BinaryData - a binary template data;
//  TemplateType            - String - a print form template type: DOC or ODT;
//  TemplateName            - String - a name to be used for creating a temporary template file.
//
// Returns:
//  Structure - 
//
Function InitializeOfficeDocumentTemplate(Val BinaryTemplateData, Val TemplateType, Val TemplateName = "") Export
	
	Template = Undefined;
	TempFileName = "";
	
	#If WebClient Then
		If IsBlankString(TemplateName) Then
			TempFileName = String(New UUID) + "." + Lower(TemplateType);
		Else
			TempFileName = TemplateName + "." + Lower(TemplateType);
		EndIf;
	#EndIf
	
	If Upper(TemplateType) = "DOC" Then
		Template = PrintManagementMSWordClient.GetMSWordTemplate(BinaryTemplateData, TempFileName);
		If Template <> Undefined Then
			Template.Insert("Type", "DOC");
		EndIf;
	ElsIf Upper(TemplateType) = "ODT" Then
		Template = PrintManagementOOWriterClient.GetOOWriterTemplate(BinaryTemplateData, TempFileName);
		If Template <> Undefined Then
			Template.Insert("Type", "ODT");
			Template.Insert("TemplatePagesSettings", Undefined);
		EndIf;
	EndIf;
	
	Return Template;
	
EndFunction

// Deprecated. Obsolete. Use the PrintManagement.ClearRefs procedure.
//
// Releases links in the created interface of connection with office application.
// Always call this procedure after the template is generated and the print form is displayed to a user.
//
// Parameters:
//  PrintForm     - Structure - a result of the InitializePrintForm and InitializeOfficeDocumentTemplate functions;
//  CloseApplication - Boolean    - True, if it is necessary to close the application.
//                                  Connection to the template must be closed when closing the application.
//                                  PrintForm does not need to be closed.
//
Procedure ClearRefs(PrintForm, Val CloseApplication = True) Export
	
	If PrintForm <> Undefined Then
		If PrintForm.Type = "DOC" Then
			PrintManagementMSWordClient.CloseConnection(PrintForm, CloseApplication);
		Else
			PrintManagementOOWriterClient.CloseConnection(PrintForm, CloseApplication);
		EndIf;
		PrintForm = Undefined;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Function that displays a print form to a user.

// Deprecated. Obsolete. It is not required anymore.
//
// Shows the generated document to a user.
//
// Parameters:
//  PrintForm - Structure - a result of the InitializePrintForm function.
//
Procedure ShowDocument(Val PrintForm) Export
	
	If PrintForm.Type = "DOC" Then
		PrintManagementMSWordClient.ShowMSWordDocument(PrintForm);
	ElsIf PrintForm.Type = "ODT" Then
		PrintManagementOOWriterClient.ShowOOWriterDocument(PrintForm);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 
// 

// Deprecated. Obsolete. Use PrintManagement.TemplateArea.
//
// Gets a print form template area.
//
// Parameters:
//  RefToTemplate   - Structure - a print form template.
//  AreaDetails - Structure:
//   * AreaName - String -area name;
//   * AreaTypeType - String - an area type: "Header", "Footer", "Common", "TableRow", "List".
//   
// Returns:
//  Structure - 
//
Function TemplateArea(Val RefToTemplate, Val AreaDetails) Export
	
	Area = Undefined;
	If RefToTemplate.Type = "DOC" Then
		
		If		AreaDetails.AreaType = "Header" Then
			Area = PrintManagementMSWordClient.GetHeaderArea(RefToTemplate);
		ElsIf	AreaDetails.AreaType = "Footer" Then
			Area = PrintManagementMSWordClient.GetFooterArea(RefToTemplate);
		ElsIf	AreaDetails.AreaType = "Shared3" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDetails.AreaName, 1, 0);
		ElsIf	AreaDetails.AreaType = "TableRow" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDetails.AreaName);
		ElsIf	AreaDetails.AreaType = "List" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefToTemplate, AreaDetails.AreaName, 1, 0);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Area type is not specified or invalid: %1.';"), AreaDetails.AreaType);
		EndIf;
		
		If Area <> Undefined Then
			Area.Insert("AreaDetails", AreaDetails);
		EndIf;
	ElsIf RefToTemplate.Type = "ODT" Then
		
		If		AreaDetails.AreaType = "Header" Then
			Area = PrintManagementOOWriterClient.GetHeaderArea(RefToTemplate);
		ElsIf	AreaDetails.AreaType = "Footer" Then
			Area = PrintManagementOOWriterClient.GetFooterArea(RefToTemplate);
		ElsIf	AreaDetails.AreaType = "Shared3"
				Or AreaDetails.AreaType = "TableRow"
				Or AreaDetails.AreaType = "List" Then
			Area = PrintManagementOOWriterClient.GetTemplateArea(RefToTemplate, AreaDetails.AreaName);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Area type is not specified or invalid: %1.';"), AreaDetails.AreaName);
		EndIf;
		
		If Area <> Undefined Then
			Area.Insert("AreaDetails", AreaDetails);
		EndIf;
	EndIf;
	
	Return Area;
	
EndFunction

// Deprecated. Obsolete. Use PrintManagement.AttachArea.
//
// Attaches an area to a template print form.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - See InitializePrintForm.
//  TemplateArea - See TemplateArea.
//  GoToNextRow1 - Boolean - True, if you need to add a line break after the area output.
//
Procedure AttachArea(Val PrintForm, Val TemplateArea, Val GoToNextRow1 = True) Export
	
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	Try
		AreaDetails = TemplateArea.AreaDetails;
		
		If PrintForm.Type = "DOC" Then
			
			DerivedArea = Undefined;
			
			If		AreaDetails.AreaType = "Header" Then
				PrintManagementMSWordClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	AreaDetails.AreaType = "Footer" Then
				PrintManagementMSWordClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	AreaDetails.AreaType = "Shared3" Then
				DerivedArea = PrintManagementMSWordClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1);
			ElsIf	AreaDetails.AreaType = "List" Then
				DerivedArea = PrintManagementMSWordClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1);
			ElsIf	AreaDetails.AreaType = "TableRow" Then
				If PrintForm.LastOutputArea <> Undefined
				   And PrintForm.LastOutputArea.AreaType = "TableRow"
				   And Not PrintForm.LastOutputArea.GoToNextRow1 Then
					DerivedArea = PrintManagementMSWordClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1, True);
				Else
					DerivedArea = PrintManagementMSWordClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1);
				EndIf;
			Else
				Raise AreaTypeSpecifiedIncorrectlyText();
			EndIf;
			
			AreaDetails.Insert("Area", DerivedArea);
			AreaDetails.Insert("GoToNextRow1", GoToNextRow1);
			
			// 
			PrintForm.LastOutputArea = AreaDetails;
			
		ElsIf PrintForm.Type = "ODT" Then
			If		AreaDetails.AreaType = "Header" Then
				PrintManagementOOWriterClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	AreaDetails.AreaType = "Footer" Then
				PrintManagementOOWriterClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	AreaDetails.AreaType = "Shared3"
					Or AreaDetails.AreaType = "List" Then
				PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
				PrintManagementOOWriterClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1);
			ElsIf	AreaDetails.AreaType = "TableRow" Then
				PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
				PrintManagementOOWriterClient.AttachArea(PrintForm, TemplateArea, GoToNextRow1, True);
			Else
				Raise AreaTypeSpecifiedIncorrectlyText();
			EndIf;
			// 
			PrintForm.LastOutputArea = AreaDetails;
		EndIf;
	Except
		ErrorMessage = TrimAll(ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		ErrorMessage = ?(Right(ErrorMessage, 1) = ".", ErrorMessage, ErrorMessage + ".");
		ErrorMessage = ErrorMessage + " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error occurred during output of %1 template area.';"),
			TemplateArea.AreaDetails.AreaName);
		Raise ErrorMessage;
	EndTry;
	
EndProcedure

// Deprecated. Obsolete. Use PrintManagement.FillParameters.
//
// Fills parameters of the print form area.
//
// Parameters:
//  PrintForm - Structure - either a print form area or a print form itself.
//  Data - Structure - filling data.
//
Procedure FillParameters_(Val PrintForm, Val Data) Export
	
	AreaDetails = PrintForm.LastOutputArea; // See TemplateArea.AreaDetails
	
	If PrintForm.Type = "DOC" Then
		If		AreaDetails.AreaType = "Header" Then
			PrintManagementMSWordClient.FillHeaderParameters(PrintForm, Data);
		ElsIf	AreaDetails.AreaType = "Footer" Then
			PrintManagementMSWordClient.FillFooterParameters(PrintForm, Data);
		ElsIf	AreaDetails.AreaType = "Shared3"
				Or AreaDetails.AreaType = "TableRow"
				Or AreaDetails.AreaType = "List" Then
			PrintManagementMSWordClient.FillParameters_(AreaDetails.Area, Data);
		Else
			Raise AreaTypeSpecifiedIncorrectlyText();
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		PrintForm.LastOutputArea.AreaType = "Header" Then
			PrintManagementOOWriterClient.SetMainCursorToHeader(PrintForm);
		ElsIf	PrintForm.LastOutputArea.AreaType = "Footer" Then
			PrintManagementOOWriterClient.SetMainCursorToFooter(PrintForm);
		ElsIf	AreaDetails.AreaType = "Shared3"
				Or AreaDetails.AreaType = "TableRow"
				Or AreaDetails.AreaType = "List" Then
			PrintManagementOOWriterClient.SetMainCursorToDocumentBody(PrintForm);
		EndIf;
		PrintManagementOOWriterClient.FillParameters_(PrintForm, Data);
	EndIf;
	
EndProcedure

// Deprecated. Obsolete. Use PrintManagement.AttachAreaAndFillParameters.
//
// Adds an area from a template to a print form, replacing the area parameters with the object data values.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - See InitializePrintForm.
//  TemplateArea - See TemplateArea.
//  Data - Structure - filling data.
//  GoToNextRow1 - Boolean - True, if you need to add a line break after the area output.
//
Procedure AttachAreaAndFillParameters(Val PrintForm, Val TemplateArea,
	Val Data, Val GoToNextRow1 = True) Export
	
	If TemplateArea <> Undefined Then
		AttachArea(PrintForm, TemplateArea, GoToNextRow1);
		FillParameters_(PrintForm, Data)
	EndIf;
	
EndProcedure

// Deprecated. Obsolete. Use PrintManagement.AttachAndFillCollection.
//
// Adds an area from a template to a print form, replacing
// the area parameters with the object data values.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - See InitializePrintForm.
//  TemplateArea - See TemplateArea
//  Data - Array - an item collection of the Structure type - object data.
//  GoToNextRow - Boolean - True, if you need to add a line break after the area output.
//
Procedure JoinAndFillCollection(Val PrintForm,
										Val TemplateArea,
										Val Data,
										Val GoToNextRow = True) Export
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	AreaDetails = TemplateArea.AreaDetails;
	
	If PrintForm.Type = "DOC" Then
		If		AreaDetails.AreaType = "TableRow" Then
			PrintManagementMSWordClient.JoinAndFillTableArea(PrintForm, TemplateArea, Data, GoToNextRow);
		ElsIf	AreaDetails.AreaType = "List" Then
			PrintManagementMSWordClient.JoinAndFillSet(PrintForm, TemplateArea, Data, GoToNextRow);
		Else
			Raise AreaTypeSpecifiedIncorrectlyText();
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		AreaDetails.AreaType = "TableRow" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, True, GoToNextRow);
		ElsIf	AreaDetails.AreaType = "List" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, False, GoToNextRow);
		Else
			Raise AreaTypeSpecifiedIncorrectlyText();
		EndIf;
	EndIf;
	
EndProcedure

// Deprecated. Obsolete. Use PrintManagement.InsertNewLineBreak.
//
// Inserts a line break as a newline character.
//
// Parameters:
//  PrintForm - See InitializePrintForm.
//
Procedure InsertBreakAtNewLine(Val PrintForm) Export
	
	If	  PrintForm.Type = "DOC" Then
		PrintManagementMSWordClient.InsertBreakAtNewLine(PrintForm);
	ElsIf PrintForm.Type = "ODT" Then
		PrintManagementOOWriterClient.InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Opens a template file import dialog box for editing it in an external application.
Procedure EditTemplateInExternalApplication(NotifyDescription, TemplateParameters1, Form) Export
	OpenForm("InformationRegister.UserPrintTemplates.Form.EditTemplate2", TemplateParameters1, Form, , , , NotifyDescription);
EndProcedure

// The SettingsForSaving parameter constructor of the PrintManagement.PrintToFile function.
// Defines a format and other settings of writing a spreadsheet document to file.
// 
// Returns:
//  Structure - 
//   * SaveFormats - Array - a collection of values of the SpreadsheetDocumentFileType type converted into a string;
//   * PackToArchive   - Boolean - if set to True, one archive file with files of the specified formats will be created;
//   * TransliterateFilesNames - Boolean - if set to True, names of the received files will be in Latin characters.
//   * SignatureAndSeal    - Boolean - if it is set to True and a spreadsheet document being saved supports placement of
//                                  signatures and seals, they will be placed to saved files.
//
Function SettingsForSaving() Export
	
	Return PrintManagementClientServer.SettingsForSaving();
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  Command - FormCommand
//
Procedure SwitchLanguage(Form, Command) Export
	
	Parameters = New Structure;
	Parameters.Insert("Form", Form);
	ArrayOfLangWords = StrSplit(Command.Name, "_", False);
	ArrayOfLangWords.Delete(0);
	TheSelectedLanguage = StrConcat(ArrayOfLangWords, "_");
	
	Parameters.Insert("TheSelectedLanguage", TheSelectedLanguage);

	FormButton = Form.Items[Command.Name]; // FormButton
	Parameters.Insert("Title", Form.Items["Language_"+TheSelectedLanguage].Title);
	Parameters.Insert("FormButton", FormButton);
	
	If Form.Modified Then
		NotifyDescription = New NotifyDescription("WhenSwitchingTheLanguage", ThisObject, Parameters);
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.OK, NStr("en = 'Continue';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		QueryText = NStr("en = 'Current template changes are not saved. Do you want to continue?';");
		ShowQueryBox(NotifyDescription, QueryText, Buttons, , DialogReturnCode.Cancel);
	Else
		WhenSwitchingTheLanguage(DialogReturnCode.OK, Parameters);
	EndIf;
	
EndProcedure

Function AreaID(Area) Export
	
	Return PrintManagementClientServer.AreaID(Area);
	
EndFunction

// Returns:
//  Structure:
//   * FilesDetails1 - Array of Structure
//   * DirectoryName - String
//   * CompletionHandler - NotifyDescription
//   * IndexOf - Number
//   * Counter - Number
//   * FileName - String
//
Function FileNamePreparationOptions(FilesDetails1, DirectoryName, CompletionHandler) Export
	
	Result = New Structure;
	
	Result.Insert("FilesDetails1", FilesDetails1);
	Result.Insert("DirectoryName", DirectoryName);
	Result.Insert("CompletionHandler", CompletionHandler);
	Result.Insert("IndexOf", Undefined);
	Result.Insert("Counter", 1);
	Result.Insert("FileName", "");
	
	Return Result;
	
EndFunction

// Parameters:
//  PreparationParameters - See FileNamePreparationOptions
//
Procedure PrepareFileNamesToSaveToADirectory(PreparationParameters) Export
	
	FilesDetails1 = PreparationParameters.FilesDetails1;
	
	If PreparationParameters.IndexOf = Undefined Then
		For Each FileDetails In FilesDetails1 Do
			FileDetails.Presentation = PreparationParameters.DirectoryName + FileDetails.Presentation;
		EndDo;
		PreparationParameters.IndexOf = 0;
	EndIf;
	
	If PreparationParameters.IndexOf > FilesDetails1.UBound() Then
		ExecuteNotifyProcessing(PreparationParameters.CompletionHandler, FilesDetails1);
		Return;
	EndIf;
	
	FileDetails = FilesDetails1[PreparationParameters.IndexOf];
	File = New File(FileDetails.Presentation);
	If PreparationParameters.Counter > 1 Then
		File = New File(File.Path +  File.BaseName + " (" + PreparationParameters.Counter + ")" + File.Extension);
	EndIf;
	
	PreparationParameters.FileName = File.Name;
	NotifyDescription = New NotifyDescription("WhenCheckingTheExistenceOfAFile", ThisObject, PreparationParameters);
	File.BeginCheckingExistence(NotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

// Before executing a print command, check whether at least one object is passed as an empty array can be passed
// for commands that accept multiple objects.
//
Function CheckPassedObjectsCount(CommandParameter)
	
	If TypeOf(CommandParameter) = Type("Array") And CommandParameter.Count() = 0 Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

Function AreaTypeSpecifiedIncorrectlyText()
	Return NStr("en = 'Area type is not specified or invalid.';");
EndFunction

Procedure WhenSwitchingTheLanguage(Response, Parameters) Export
	
	If Response <> DialogReturnCode.OK Then
		Return
	EndIf;
	
	Form = Parameters.Form; // ClientApplicationForm - 
	TheSelectedLanguage = Parameters.TheSelectedLanguage;
	Title = Parameters.Title;
	Form.Items.Language.Title = Title;
	FormButton = Parameters.FormButton;
	
	IsEditorForm = StrStartsWith(Form.FormName, "CommonForm.Edit");
	
	If IsEditorForm Then
		IsTemplateCreated = Form.TemplateSavedLangs.FindByValue(Form.CurrentLanguage)<>Undefined;
	EndIf;
	
	LangSwitchFrom = Form.CurrentLanguage;
	
	Form.CurrentLanguage = TheSelectedLanguage;
	MenuLang = Form.Items.Language;
	
	For Each LangButton In MenuLang.ChildItems Do
		If TypeOf(LangButton) = Type("FormButton") Then
			LangButton.Check = False;
			If FormButton.CommandName = "Add"+LangButton.CommandName Then
				LangButton.Visible = True;
				LangButton.Check = True;
			EndIf;
		EndIf;
	EndDo;
	
	If FormButton.Parent = MenuLang Then
		FormButton.Check = True;
	Else
		FormButton.Visible = False;
	EndIf;

	If IsEditorForm Then
				
		If Not IsTemplateCreated Then
			LangsToAdd = Form.Items.LangsToAdd;
			For Each LangButton In LangsToAdd.ChildItems Do
				If StrEndsWith(LangButton.Name, LangSwitchFrom) Then
					LangButton.Visible = True;
					Break;
				EndIf;
			EndDo;
			
			For Each LangButton In MenuLang.ChildItems Do
				If TypeOf(LangButton) = Type("FormButton") Then
					If StrEndsWith(LangButton.Name, LangSwitchFrom) Then
						LangButton.Visible = False;
						LangButton.Check = False;
						Break;
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
	EndIf;
	
	Form.Modified = False;
	
	NotifyDescription = New NotifyDescription("Attachable_WhenSwitchingTheLanguage", Form);
	ExecuteNotifyProcessing(NotifyDescription, TheSelectedLanguage);
	
EndProcedure

// Parameters:
//  Exists - Boolean
//  PreparationParameters - See FileNamePreparationOptions
//
Procedure WhenCheckingTheExistenceOfAFile(Exists, PreparationParameters) Export
	
	If Exists Then
		PreparationParameters.Counter = PreparationParameters.Counter + 1;
	Else
		FileDetails = PreparationParameters.FilesDetails1[PreparationParameters.IndexOf];
		FileDetails.Presentation = PreparationParameters.FileName;
		PreparationParameters.Counter = 0;
		PreparationParameters.IndexOf = PreparationParameters.IndexOf + 1;
	EndIf;
	
	PrepareFileNamesToSaveToADirectory(PreparationParameters);
	
EndProcedure

Procedure ExecutePrintCommandAfterFormationOfPrintedForms(BackgroundOperationResult, OpeningParameters) Export
	If BackgroundOperationResult <> Undefined Then
		If BackgroundOperationResult.Status = "Error" Then
			Raise BackgroundOperationResult.BriefErrorDescription;
		EndIf;
		ResultStructure1 = GetFromTempStorage(BackgroundOperationResult.ResultAddress);
		
		OpeningParameters.Insert("PrintObjects", ResultStructure1.PrintObjects);
		OpeningParameters.Insert("OutputParameters", ResultStructure1.OutputParameters);
		OpeningParameters.Insert("PrintParameters", ResultStructure1.PrintParameters); 
		
		PrintFormsCollection	 = ResultStructure1.PrintFormsCollection;
		OfficeDocuments		 = ResultStructure1.OfficeDocuments;
		For Each PrintForm In PrintFormsCollection Do
			OfficeDocsNewAddresses = New Map();
			If ValueIsFilled(PrintForm.OfficeDocuments) Then
				For Each OfficeDocument In PrintForm.OfficeDocuments Do
					OfficeDocsNewAddresses.Insert(PutToTempStorage(OfficeDocuments[OfficeDocument.Key], OpeningParameters.StorageUUID), OfficeDocument.Value);
				EndDo;
				PrintForm.OfficeDocuments = OfficeDocsNewAddresses;
			EndIf;
		EndDo;
		
		OpeningParameters.Insert("PrintFormsCollection", PrintFormsCollection);
		
		JobMessages = New Array(BackgroundOperationResult.Messages);
		CommonClientServer.SupplementArray(JobMessages, ResultStructure1.Messages);
		OpeningParameters.Insert("Messages", JobMessages);
		
		FormOwner = OpeningParameters.FormOwner;
		OpeningParameters.Delete("FormOwner");
		
		OpenForm("CommonForm.PrintDocuments", OpeningParameters, FormOwner, String(New UUID));
	EndIf;
EndProcedure


#EndRegion
