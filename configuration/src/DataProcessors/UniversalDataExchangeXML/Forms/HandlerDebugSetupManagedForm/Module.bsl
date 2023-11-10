///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// First of all, checking the access rights.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en = 'Only administrators can run the data processor manually.';");
	EndIf;
	
	Object.ExchangeFileName = Parameters.ExchangeFileName;
	Object.ExchangeRulesFileName = Parameters.ExchangeRulesFileName;
	Object.EventHandlerExternalDataProcessorFileName = Parameters.EventHandlerExternalDataProcessorFileName;
	Object.AlgorithmsDebugMode = Parameters.AlgorithmsDebugMode;
	Object.ReadEventHandlersFromExchangeRulesFile = Parameters.ReadEventHandlersFromExchangeRulesFile;
	
	If Parameters.ReadEventHandlersFromExchangeRulesFile Then
		Title = NStr("en = 'Set up handler debugging on data export';");
		ButtonTitle = NStr("en = 'Generate export debugging module';");
	Else
		Title = NStr("en = 'Set up handler debugging on data import';");
		ButtonTitle = NStr("en = 'Generate import debugging module';");
	EndIf;		
	Items.ExportHandlersCode.Title = ButtonTitle;
	
	SpecialTextColor = StyleColors.SpecialTextColor;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibility1();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AlgorithmsDebugOnChange(Item)
	
	OnChangeOfChangeDebugMode();
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	
	FileDialog.Filter     = NStr("en = 'External data processor file (*.epf)|*.epf';");
	FileDialog.DefaultExt = "epf";
	FileDialog.Title = NStr("en = 'Select file';");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	Notification = New NotifyDescription("NameOfExternalDataProcessorFileOfEventHandlersChoiceProcessing", ThisObject, AdditionalParameters);
	FileDialog.Show(Notification);
	
EndProcedure

// Parameters:
//   SelectedFiles - Array of String
//                  - Undefined - result of the file selection.
//   AdditionalParameters - Structure:
//     * Item - FormField - a source of the file choice.
//
&AtClient
Procedure NameOfExternalDataProcessorFileOfEventHandlersChoiceProcessing(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	Object.EventHandlerExternalDataProcessorFileName = SelectedFiles[0];
	
	EventHandlerExternalDataProcessorFileNameOnChange(AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameOnChange(Item)
	
	SetVisibility1();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	If IsBlankString(Object.EventHandlerExternalDataProcessorFileName) Then
		
		MessageToUser(NStr("en = 'Please specify an external data processor file name.';"), "EventHandlerExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	EventHandlerExternalDataProcessorFile = New File(Object.EventHandlerExternalDataProcessorFileName);
	
	Notification = New NotifyDescription("EventHandlerExternalDataProcessorFileExistanceCheckCompletion", ThisObject);
	EventHandlerExternalDataProcessorFile.BeginCheckingExistence(Notification);
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileExistanceCheckCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		MessageToUser(NStr("en = 'The specified external data processor file does not exist.';"),
			"EventHandlerExternalDataProcessorFileName");
		Return;
	EndIf;
	
	ClosingParameters = New Structure;
	ClosingParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	ClosingParameters.Insert("AlgorithmsDebugMode", Object.AlgorithmsDebugMode);
	ClosingParameters.Insert("ExchangeRulesFileName", Object.ExchangeRulesFileName);
	ClosingParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	
	Close(ClosingParameters);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	ShowEventHandlersInWindow();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetVisibility1()
	
	OnChangeOfChangeDebugMode();
	
	// Highlighting wizard steps that require corrections with red color.
	SelectExternalDataProcessorName(IsBlankString(Object.EventHandlerExternalDataProcessorFileName));
	
	Items.OpenFile.Enabled = Not IsBlankString(Object.EventHandlersTempFileName);
	
EndProcedure

&AtClient
Procedure SelectExternalDataProcessorName(NeedToSelect = False) 
	
	Items.Step4Pages.CurrentPage = ?(NeedToSelect, Items.RedPage, Items.GreenPage);
	
EndProcedure

&AtClient
Procedure ExportHandlersCode(Command)
	
	// Data was exported earlier...
	If Not IsBlankString(Object.EventHandlersTempFileName) Then
		
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes, NStr("en = 'Repeat export';"));
		ButtonsList.Add(DialogReturnCode.No, NStr("en = 'Open module';"));
		ButtonsList.Add(DialogReturnCode.Cancel);
		
		NotifyDescription = New NotifyDescription("ExportHandlersCodeCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The debugging module with the handler code is already exported.';"), ButtonsList,,DialogReturnCode.No);
		
	Else
		
		ExportHandlersCodeCompletion(DialogReturnCode.Yes, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportHandlersCodeCompletion(Result, AdditionalParameters) Export
	
	HasExportErrors = False;
	
	If Result = DialogReturnCode.Yes Then
		
		ExportedWithErrors = False;
		ExportEventHandlersAtServer(ExportedWithErrors);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		
		Return;
		
	EndIf;
	
	If Not HasExportErrors Then
		
		SetVisibility1();
		
		ShowEventHandlersInWindow();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventHandlersInWindow()
	
	EventsHandlers = EventsHandlers();
	If EventsHandlers <> Undefined Then
		EventsHandlers.Show(NStr("en = 'Handler debugging module';"));
	EndIf;
	
	
	ExchangeProtocol = ExchangeProtocol();
	If ExchangeProtocol <> Undefined Then
		ExchangeProtocol.Show(NStr("en = 'Errors occurred while exporting an event handler module';"));
	EndIf;
	
EndProcedure

&AtServer
Function EventsHandlers()
	
	EventsHandlers = Undefined;
	
	HandlerFile = New File(Object.EventHandlersTempFileName);
	If HandlerFile.Exists() And HandlerFile.Size() <> 0 Then
		EventsHandlers = New TextDocument;
		EventsHandlers.Read(Object.EventHandlersTempFileName);
	EndIf;
	
	Return EventsHandlers;
	
EndFunction

&AtServer
Function ExchangeProtocol()
	
	ExchangeProtocol = Undefined;
	
	ErrorLogFile = New File(Object.ExchangeProtocolTempFileName);
	If ErrorLogFile.Exists() And ErrorLogFile.Size() <> 0 Then
		ExchangeProtocol = New TextDocument;
		ExchangeProtocol.Read(Object.EventHandlersTempFileName);
	EndIf;
	
	Return ExchangeProtocol;
	
EndFunction

&AtServer
Procedure ExportEventHandlersAtServer(Cancel)
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExportEventHandlers(Cancel);
	ValueToFormAttribute(ObjectForServer, "Object");
	
EndProcedure

&AtClient
Procedure OnChangeOfChangeDebugMode()
	
	ToolTip = Items.AlgorithmsDebugTooltip;
	
	ToolTip.CurrentPage = ToolTip.ChildItems["Group_"+Object.AlgorithmsDebugMode];
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

#EndRegion
