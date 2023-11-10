///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens the BIC catalog choice form with filter by passed BIC.
// If the choice list contains a single record, it is automatically selected in the form.
//
// Parameters:
//  BIC - String - Bank ID.
//  Form - ClientApplicationForm - a form that opens the choice form.
//  HandlerNotifications - NotifyDescription - the procedure to which the management is passed after the selection.
//                                              If the parameter is not specified, the standard choice handler will be called.
//    Procedure parameters:
//     * BIC - CatalogRef.BankClassifier - a selected item.
//     * AdditionalParameters - Arbitrary - the parameter passed in the notification details constructor.
// 
Procedure SelectFromTheBICDirectory(BIC, Form, HandlerNotifications = Undefined) Export
	
	Parameters = New Structure;
	Parameters.Insert("BIC", BIC);
	OpenForm("Catalog.BankClassifier.ChoiceForm", Parameters, Form, , , , HandlerNotifications);
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParameters.Property("Banks") And ClientParameters.Banks.OutputMessageOnInvalidity Then
		AttachIdleHandler("BankManagerOutputObsoleteDataNotification", 180, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Update bank classifier.

// Displays the update notification.
//
Procedure NotifyClassifierObsolete() Export
	
	If BankManagerServerCall.ClassifierUpToDate() Then
		Return;
	EndIf;
	
	ShowUserNotification(
		NStr("en = 'The bank classifier is outdated';"),
		NotificationURLImportForm(),
		NStr("en = 'Update the bank classifier';"),
		PictureLib.Warning32,
		UserNotificationStatus.Important,
		"BankClassifierIsOutdated");
	
EndProcedure

// Returns a notification URL.
//
Function NotificationURLImportForm()
	Return "e1cib/command/DataProcessor.ImportBankClassifier.Command.ImportBankClassifier";
EndFunction

Procedure OpenClassifierImportForm() Export
	AttachIdleHandler("BankManagerOpenClassifierImportForm", 0.1, True);
EndProcedure

Procedure GoToClassifierImport() Export
	FileSystemClient.OpenURL(NotificationURLImportForm());
EndProcedure

Procedure SuggestToImportClassifier() Export
	
	NotifyDescription = New NotifyDescription("OnGetAnswerToQuestionAboutClassifierImport", ThisObject);
	QuestionTitle = NStr("en = 'Import bank classifier';");
	QueryText = NStr("en = 'Bank classifier has not been imported yet. Import now?';");
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Import';"));
	Buttons.Add(DialogReturnCode.Cancel);
	ShowQueryBox(NotifyDescription, QueryText, Buttons, , Buttons[0].Value, QuestionTitle);

EndProcedure

Procedure OnGetAnswerToQuestionAboutClassifierImport(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OpenClassifierImportForm();
	
EndProcedure

#EndRegion
