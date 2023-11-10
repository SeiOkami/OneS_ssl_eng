///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Sets the original state for selected documents. Called over the "Attachable commands" subsystem.
//
//	Parameters:
//  Ref - DocumentRef - document reference.
//  Parameters -See AttachableCommands.CommandExecuteParameters.
//
Procedure Attachable_SetOriginalState(Ref, Parameters) Export
	
	If Not SourceDocumentsOriginalsRecordingServerCall.RightsToChangeState() Then
		ShowMessageBox(, NStr("en = 'The user has insufficient rights to change source document original state';"));
		Return;
	EndIf;
	
	List = Parameters.Source;
	
	If List.SelectedRows.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No document, for which the selected state can be set, is selected';"));
		Return;
	EndIf;

	If Parameters.CommandDetails.Kind = "SettingStateOriginalReceived" Then
		StateName = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived");
	Else
		StateName = Parameters.CommandDetails.Presentation;
	EndIf;

	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("List",List);

	If Parameters.CommandDetails.Id = "StatesSetup" Then
		OpenStatesSetupForm();
		Return;
	ElsIf Parameters.CommandDetails.Kind = "SettingStateOriginalReceived" And List.SelectedRows.Count() = 1 Then
		AdditionalParameters.Insert("StateName", StateName);
		SetOriginalStateCompletion(DialogReturnCode.Yes, AdditionalParameters);
		Return;
	EndIf;

	AdditionalParameters.Insert("StateName", StateName);
	
	If List.SelectedRows.Count() > 1 Then
		QueryText = NStr("en = 'The ""%StateName%"" original state will be set for documents selected in the list. Continue?';");
		QueryText = StrReplace(QueryText, "%StateName%", StateName);

		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes,NStr("en = 'Set';"));
		Buttons.Add(DialogReturnCode.No,NStr("en = 'Do not set';"));

		ShowQueryBox(New NotifyDescription("SetOriginalStateCompletion", ThisObject, AdditionalParameters), QueryText, Buttons);
	ElsIf SourceDocumentsOriginalsRecordingServerCall.IsAccountingObject(List.CurrentData.Ref) Then 
		SetOriginalStateCompletion(DialogReturnCode.Yes, AdditionalParameters);
	Else
		ShowMessageBox(, NStr("en = 'Records of originals are not kept for this document.';"));
	EndIf;
	
EndProcedure

// Sets the original state for selected documents. Called without integrating the "Attachable commands" subsystem.
//
//	Parameters:
//  Command - String- a name of the form command being executed.
//  Form - ClientApplicationForm - a form of a list or a document.
//  List - FormTable - a form list where the state will be changed.
//
Procedure SetOriginalState(Command, Form, List) Export
	
	If Not SourceDocumentsOriginalsRecordingServerCall.RightsToChangeState() Then
		ShowMessageBox(, NStr("en = 'The user has insufficient rights to change source document original state';"));
		Return;
	EndIf;

	If List.SelectedRows.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No document, for which the selected state can be set, is selected';"));
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("List",List);
	
	If Command = "StatesSetup" Then
		OpenStatesSetupForm();
		Return;
	ElsIf Command = "SetOriginalReceived" And List.SelectedRows.Count()= 1 Then
		AdditionalParameters.Insert("StateName", PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived"));
		SetOriginalStateCompletion(DialogReturnCode.Yes, AdditionalParameters);
		Return;
	EndIf;

	FoundState = Form.Items.Find(Command);

	If Not FoundState = Undefined Then
		StateName = FoundState.Title;
	ElsIf Command = "SetOriginalReceived" Then
		StateName = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived");
	EndIf;

	AdditionalParameters.Insert("StateName", StateName);
	
	If List.SelectedRows.Count() > 1 Then
		QueryText = NStr("en = 'The ""%StateName%"" original state will be set for documents selected in the list. Continue?';");
		QueryText = StrReplace(QueryText, "%StateName%", StateName);

		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Set';"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not set';"));

		ShowQueryBox(New NotifyDescription("SetOriginalStateCompletion", ThisObject, AdditionalParameters), 
			QueryText, Buttons);
	ElsIf SourceDocumentsOriginalsRecordingServerCall.IsAccountingObject(List.CurrentData.Ref) Then 
		SetOriginalStateCompletion(DialogReturnCode.Yes, AdditionalParameters);
	Else
		ShowMessageBox(, NStr("en = 'Records of originals are not kept for this document.';"));
	EndIf;
	
EndProcedure

// Opens a drop-down menu to select an original state in a list form or a document form.
//
//	Parameters:
//  Form - ClientApplicationForm:
//   * Object - FormDataStructure, DocumentObject - Form's main attribute.
//  Source - FormTable -
//                              
//
Procedure OpenStateSelectionMenu(Val Form, Val Source = Undefined) Export 
		
	If Not SourceDocumentsOriginalsRecordingServerCall.RightsToChangeState() Then
		ShowMessageBox(, NStr("en = 'The user has insufficient rights to change source document original state';"));
		Return;
	EndIf;
	
	If TypeOf(Source) = Undefined Then
		Source = Form.Items.Find("OriginalStateDecoration");
	EndIf;
	
	If TypeOf(Source) = Type("FormTable") Then
		
		RecordData = Source.CurrentData;
		UnpostedDocuments = CommonServerCall.CheckDocumentsPosting(
			CommonClientServer.ValueInArray(RecordData.Ref));
		If UnpostedDocuments.Count() = 1 Then
			ShowMessageBox(,NStr("en = 'To run the command, post the document first.';"));
			Return;
		EndIf;
		
		RecordsArray = CommonClientServer.ValueInArray(RecordData);
		NotifyDescription = New NotifyDescription("OpenStateSelectionMenuCompletion", ThisObject, RecordsArray);

		If RecordData.OverallState Or Not ValueIsFilled(RecordData.SourceDocumentOriginalState) Then
			ClarifyByPrintForms = Form.OriginalStatesChoiceList.FindByValue("ClarifyByPrintForms");
			If ClarifyByPrintForms = Undefined Then
				Form.OriginalStatesChoiceList.Add("ClarifyByPrintForms",
					NStr("en = 'Specify for print forms…';"),,
					PictureLib.SetSourceDocumentOriginalStateByPrintForms);
			EndIf;
			Form.ShowChooseFromMenu(NotifyDescription, Form.OriginalStatesChoiceList,
				Form.Items.SourceDocumentOriginalState);
		Else
			ClarifyByPrintForms = Form.OriginalStatesChoiceList.FindByValue("ClarifyByPrintForms");
			If ClarifyByPrintForms <> Undefined Then
				Form.OriginalStatesChoiceList.Delete(ClarifyByPrintForms);
			EndIf;
			Form.ShowChooseFromMenu(NotifyDescription, Form.OriginalStatesChoiceList,
				Form.Items.SourceDocumentOriginalState);
		EndIf;
	Else
		If Form.Object.Ref.IsEmpty() Then
			ShowMessageBox(,NStr("en = 'To run the command, post the document first.';"));
			Return;
		EndIf;
		UnpostedDocuments = CommonServerCall.CheckDocumentsPosting(
			CommonClientServer.ValueInArray(Form.Object.Ref));

		If UnpostedDocuments.Count() = 1 Then
			ShowMessageBox(,NStr("en = 'To run the command, post the document first.';"));
			Return;
		EndIf;

		AdditionalParameters = New Structure("Ref", Form.Object.Ref);
		NotifyDescription = New NotifyDescription("OpenStateSelectionMenuCompletion", ThisObject,
			AdditionalParameters);

		ClarifyByPrintForms = Form.OriginalStatesChoiceList.FindByValue("ClarifyByPrintForms");
		If ClarifyByPrintForms = Undefined Then
			Form.OriginalStatesChoiceList.Add("ClarifyByPrintForms",
				NStr("en = 'Specify for print forms…';"),,
				PictureLib.SetSourceDocumentOriginalStateByPrintForms);
		EndIf;

		Form.ShowChooseFromMenu(NotifyDescription, Form.OriginalStatesChoiceList, Source);
	EndIf;

EndProcedure

// A notification handler of the "Source document tracking" subsystem events for the document form.
//
//	Parameters:
//  EventName - String - a name of the event that occurred.
//  Form - ClientApplicationForm - a document form.
//
Procedure NotificationHandlerDocumentForm(EventName, Form) Export           
		
	If EventName = "SourceDocumentOriginalStateChange" Then 
		GenerateCurrentOriginalStateLabel(Form);
	ElsIf EventName = "AddDeleteSourceDocumentOriginalState" Then			
		Form.RefreshDataRepresentation();	
	EndIf;
		
EndProcedure

// A notification handler of the "Source document tracking" subsystem events for the list form.
//
//	Parameters:
//  EventName - String - a name of the event that occurred.
//  Form - ClientApplicationForm - a list form of documents.
//  List - FormTable - the main form list.
//
Procedure NotificationHandlerListForm(EventName, Form, List) Export 
	
	If EventName = "AddDeleteSourceDocumentOriginalState" Then
		TheStructureOfTheSearch = New Structure;
 		TheStructureOfTheSearch.Insert("OriginalStatesChoiceList", Undefined);
 		FillPropertyValues(TheStructureOfTheSearch, Form);
 		If TheStructureOfTheSearch.OriginalStatesChoiceList<> Undefined Then
			Form.DetachIdleHandler("Attachable_UpdateOriginalStateCommands");
			Form.AttachIdleHandler("Attachable_UpdateOriginalStateCommands", 0.2, True);
			SourceDocumentsOriginalsRecordingServerCall.FillOriginalStatesChoiceList(Form.OriginalStatesChoiceList);
			Form.RefreshDataRepresentation();
		Else
			Return;
		EndIf;
	ElsIf EventName = "SourceDocumentOriginalStateChange" Then
		List.Refresh();
	EndIf;

EndProcedure

// Handler of the "Choice" list event.
//
//	Parameters:
//  FieldName - String - a description of the selected field.
//  Form - ClientApplicationForm - a list form of documents.
//  List - FormTable - the main form list.
//  StandardProcessing - Boolean - True if standard processing of the "Choice" event is used in the form
//
Procedure ListSelection(FieldName, Form, List, StandardProcessing) Export 
	
	If FieldName = "SourceDocumentOriginalState" Or FieldName = "StateOriginalReceived" Then
		StandardProcessing = False;
		If Not SourceDocumentsOriginalsRecordingServerCall.RightsToChangeState() Then
			ShowMessageBox(, NStr("en = 'The user has insufficient rights to change source document original state';"));
			Return;
		EndIf;
			If SourceDocumentsOriginalsRecordingServerCall.IsAccountingObject(List.CurrentData.Ref) Then
			If FieldName = "SourceDocumentOriginalState" Then
				OpenStateSelectionMenu(Form, List);
			ElsIf FieldName = "StateOriginalReceived" Then
				SetOriginalState("SetOriginalReceived", Form, List);
			EndIf;
		Else
			ShowMessageBox(, NStr("en = 'Records of originals are not kept for this document.';"));
		EndIf;
	EndIf;
	
EndProcedure

// The procedure processes actions of originals recording after scanning the document barcode.
//
//	Parameters:
//  Barcode - String - the scanned document barcode.
//  EventName - String - a form event name.
//
Procedure ProcessBarcode(Barcode, EventName) Export
	
	If EventName = "ScanData" Then
		Status(NStr("en = 'Setting original state by barcode…';"));
		SourceDocumentsOriginalsRecordingServerCall.ProcessBarcode(Barcode[0]);
	EndIf;
	
EndProcedure

// The procedure displays a notification about changing a document original state to the user.
//
//	Parameters:
//  ProcessedItemsCount - Number - a number of successfully processed documents.
//  DocumentRef - DocumentRef - a reference to the document for processing the user notification click 
//		in case of the single state setting. Optional parameter.
//  StateName - String - a state to be set.
//
Procedure NotifyUserOfStatesSetting(ProcessedItemsCount, DocumentRef = Undefined, StateName = Undefined) Export

	If ProcessedItemsCount > 1 Then
		MessageText = NStr("en = 'The ""%StateName%"" original state is set for all documents selected in the list';");
		MessageText = StrReplace(MessageText, "%StateName%", StateName);
		
		TitleText = NStr("en = 'The ""%StateName%"" original state is set';");
		TitleText = StrReplace(TitleText, "%StateName%", StateName);

		ShowUserNotification(TitleText,, MessageText, PictureLib.Information32,UserNotificationStatus.Important);
	Else
		NotifyDescription = New NotifyDescription("ProcessNotificationClick",ThisObject,DocumentRef);
		ShowUserNotification(NStr("en = 'Original state changed:';"),NotifyDescription,DocumentRef,PictureLib.Information32,UserNotificationStatus.Important);
	EndIf;

EndProcedure

// Opens a list form of the "SourceDocumentsOriginalsStates" catalog.
Procedure OpenStatesSetupForm() Export
	
	OpenForm("Catalog.SourceDocumentsOriginalsStates.ListForm");

EndProcedure

// Called to record original states of print forms to the register after printing the form.
//
//	Parameters:
//  PrintObjects - ValueList - a list of references to print objects.
//  PrintList - ValueList - a list with template names and print form presentations.
//  Written1 - Boolean - indicates that the document state is written to the register.
//
Procedure WriteOriginalsStatesAfterPrint(PrintObjects, PrintList, Written1 = False) Export

	SourceDocumentsOriginalsRecordingServerCall.WriteOriginalsStatesAfterPrint(PrintObjects, PrintList, Written1);
	If PrintList.Count() = 0 Or Written1 = False Then
		Return;
	EndIf;
		
	Notify("SourceDocumentOriginalStateChange");
	
	If PrintObjects.Count() > 1 Then
		NotifyUserOfStatesSetting(PrintObjects.Count(),,PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted"));
	ElsIf PrintObjects.Count() = 1 Then
		NotifyUserOfStatesSetting(1,PrintObjects[0].Value,PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted"));
	EndIf;
	
EndProcedure

// Opens a form to refine states of the document print forms.
//
//	Parameters:
//  DocumentRef - DocumentRef - a reference to the document for which a record key of overall state must be received.
//
Procedure OpenPrintFormsStatesChangeForm(DocumentRef) Export

	RegisterRecordKey = SourceDocumentsOriginalsRecordingServerCall.OverallStateRecordKey(DocumentRef);
	
	TransmittedParameters = New Structure;
	
	If RegisterRecordKey = Undefined Then
		TransmittedParameters.Insert("DocumentRef",DocumentRef);
		OpenForm("InformationRegister.SourceDocumentsOriginalsStates.Form.SourceDocumentsOriginalsStatesChange",TransmittedParameters);
	Else
		TransmittedParameters.Insert("Key", RegisterRecordKey);
		OpenForm("InformationRegister.SourceDocumentsOriginalsStates.Form.SourceDocumentsOriginalsStatesChange",TransmittedParameters);
	EndIf;

EndProcedure

// Called when opening the source document originals journal if peripheral equipment is used.
// Allows you to define a custom process of connecting the peripheral equipment to the journal.
//	
//	Parameters:
//  Form - ClientApplicationForm - a document list form.
//
Procedure OnConnectBarcodeScanner(Form) Export

	SourceDocumentsOriginalsRecordingClientOverridable.OnConnectBarcodeScanner(Form);

EndProcedure

#EndRegion

#Region Private

// Generates a label to display the current state information on a document form.
//
//	Parameters:
//  Form - ClientApplicationForm:
//   * Object - FormDataStructure, DocumentObject - Form's main attribute.
//
Procedure GenerateCurrentOriginalStateLabel(Form)
	
	OriginalStateDecoration = Form.Items.Find("OriginalStateDecoration");
	If OriginalStateDecoration = Undefined Then
		Return;
	EndIf;
		 
	If ValueIsFilled(Form.Object.Ref) Then
		CurrentOriginalState = SourceDocumentsOriginalsRecordingServerCall.OriginalStateInfoByRef(Form.Object.Ref);
		If CurrentOriginalState.Count() = 0 Then
			CurrentOriginalState=NStr("en = '<Original state is unknown>';");
			OriginalStateDecoration.TextColor = WebColors.Silver;
		Else
			CurrentOriginalState = CurrentOriginalState.SourceDocumentOriginalState;
			OriginalStateDecoration.TextColor = New Color;
		EndIf;
	Else
		OriginalStateDecoration.TextColor = WebColors.Silver;
	EndIf;

	OriginalStateDecoration.Title = CurrentOriginalState;
	
EndProcedure

// Handler of the notification that was called after completing the SetOriginalState(…) procedure.
Procedure SetOriginalStateCompletion(Response, AdditionalParameters) Export

	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	List = AdditionalParameters.List;
	StateName = AdditionalParameters.StateName;

	If List.SelectedRows.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No document, for which the selected state can be set, is selected.';"));
		Return;
	EndIf;

	RowsArray = New Array;
	For Each ListLine In List.SelectedRows Do
		RowData = List.RowData(ListLine);
		RowsArray.Add(RowData);
	EndDo;
	
	WritingObjects = SourceDocumentsOriginalsRecordingServerCall.CanWriteObjects(RowsArray); // Array of DocumentRef-
	If Not TypeOf(WritingObjects) = Type("Array") Then
		ShowMessageBox(, NStr("en = 'To run the command, post all selected documents first.';"));
		Return;
	EndIf;

	IsChanged = False;
	SourceDocumentsOriginalsRecordingServerCall.SetNewOriginalState(WritingObjects, StateName, IsChanged);

	If WritingObjects.Count() = 1 And IsChanged Then 
		NotifyUserOfStatesSetting(1,WritingObjects[0].Ref);
	ElsIf IsChanged Then
		NotifyUserOfStatesSetting(WritingObjects.Count(),,StateName);
	EndIf;
	
	If IsChanged Then
		Notify("SourceDocumentOriginalStateChange");
	EndIf;

EndProcedure

// Handler of the notification that was called after completing the OpenStateSelectionMenu(…) procedure.
//	
//	Parameters:
//  SelectedStateFromList - String - the original state selected by the user.
//  AdditionalParameters - Structure - information required to set the original state:
//                            * Ref - DocumentRef - a reference to a document to set the original state.
//       	                - Array of DocumentRef:
//                            * Ref - DocumentRef - a reference to a document to set the original state.
//
Procedure OpenStateSelectionMenuCompletion(SelectedStateFromList, AdditionalParameters) Export

	If Not SelectedStateFromList = Undefined Then
		If TypeOf(AdditionalParameters)= Type("Array")Then
			OpenStatusSelectionMenuCompletionArray(SelectedStateFromList, AdditionalParameters);
		Else
			OpenStatusSelectionMenuCompletionStructure(SelectedStateFromList, AdditionalParameters);
		EndIf;
	Else
		Return;
	EndIf;

EndProcedure

// Handler of the notification that was called after completing the OpenStateSelectionMenu(…) procedure.
//	
//	Parameters:
//  SelectedStateFromList - String - the original state selected by the user.
//  AdditionalParameters - Array of DocumentRef:
//                            * Ref - DocumentRef - a reference to a document to set the original state.
//
Procedure OpenStatusSelectionMenuCompletionArray(SelectedStateFromList, AdditionalParameters)

	IsChanged = False;
	
	If SelectedStateFromList.Value = "ClarifyByPrintForms" Then
		OpenPrintFormsStatesChangeForm(AdditionalParameters[0].Ref);
	Else
		SourceDocumentsOriginalsRecordingServerCall.SetNewOriginalState(AdditionalParameters,SelectedStateFromList.Value, IsChanged);
		If IsChanged Then
			NotifyUserOfStatesSetting(1,AdditionalParameters[0].Ref,SelectedStateFromList.Value);
			Notify("SourceDocumentOriginalStateChange");
		EndIf;
	EndIf;

EndProcedure

// Handler of the notification that was called after completing the OpenStateSelectionMenu(…) procedure.
//	
//	Parameters:
//  SelectedStateFromList - String - the original state selected by the user.
//  AdditionalParameters - Structure - the information required to set the original state:
//                            * Ref - DocumentRef - a reference to a document to set the original state.
//
Procedure OpenStatusSelectionMenuCompletionStructure(SelectedStateFromList, AdditionalParameters)

	IsChanged = False;
	
	If SelectedStateFromList.Value = "ClarifyByPrintForms" Then
		OpenPrintFormsStatesChangeForm(AdditionalParameters.Ref);
	Else
		SourceDocumentsOriginalsRecordingServerCall.SetNewOriginalState(AdditionalParameters.Ref,SelectedStateFromList.Value, IsChanged);
		If IsChanged Then
			NotifyUserOfStatesSetting(1,AdditionalParameters.Ref,SelectedStateFromList.Value);
			Notify("SourceDocumentOriginalStateChange");
			EndIf;
	EndIf;

EndProcedure

// Handler of the notification that was called after completing the NotifyUserOfStatesSetting(…) procedure.
Procedure ProcessNotificationClick(AdditionalParameters) Export

	ShowValue(,AdditionalParameters);

EndProcedure

#EndRegion
