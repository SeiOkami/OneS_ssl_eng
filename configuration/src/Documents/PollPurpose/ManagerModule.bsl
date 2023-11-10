///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("StartDate");
	Result.Add("EndDate");
	Result.Add("AllowSavingQuestionnaireDraft");
	Result.Add("ShowInQuestionnaireArchive");
	Result.Add("Comment");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.ReportsOptions

// Determines a report command list.
//
// Parameters:
//  ReportsCommands - See ReportsOptionsOverridable.BeforeAddReportCommands.ReportsCommands
//  Parameters - See ReportsOptionsOverridable.BeforeAddReportCommands.Parameters
//
Procedure AddReportCommands(ReportsCommands, Parameters) Export
	
	If AccessRight("View", Metadata.Reports.PollStatistics) Then
		Command = ReportsCommands.Add();
		Command.Presentation      = NStr("en = 'Survey analysis';");
		Command.MultipleChoice = False;
		Command.FormParameterName  = "Survey";
		Command.WriteMode        = "Write";
		Command.Manager           = "Report.PollStatistics";
	EndIf;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

// StandardSubsystems.MessagesTemplates

// It is called when preparing message templates and allows you to override a list of attributes and attachments.
//
// Parameters:
//  Attributes - See MessageTemplatesOverridable.OnPrepareMessageTemplate.Attributes
//  Attachments  - See MessageTemplatesOverridable.OnPrepareMessageTemplate.Attachments
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, AdditionalParameters) Export
	
EndProcedure

// It is called upon creating messages from template to fill in values of attributes and attachments.
//
// Parameters:
//  Message - Structure:
//    * AttributesValues - Map of KeyAndValue - a list of attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * CommonAttributesValues - Map of KeyAndValue - a list of common attributes used in the template:
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * Attachments - Map of KeyAndValue:
//      ** Key     - String - an attachment name in the template.
//      ** Value - BinaryData
//                  - String - 
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  AdditionalParameters - Structure - a full name of a message template assignment.
//
Procedure OnCreateMessage(Message, MessageSubject, AdditionalParameters) Export
	
EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable:
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - 
//    * SubjectOf               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - indicates whether to send a text message immediately.
//    * MessageParameters - Structure - Additional message parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, MessageSubject) Export
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   EmailRecipients - ValueTable - a list of mail recipients:
//     * SendingOption - String -
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - 
//    * SubjectOf               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - a kind of a message being generated: Email or SMSMessage.
//    * MessageParameters - Structure - Additional message parameters.
//    * ConvertHTMLForFormattedDocument - Boolean - indicates whether to convert an HTML text
//             of a message that contains pictures in an email text because of specifics of displaying pictures
//             in a formatted document.
//    * Account - CatalogRef.EmailAccounts - an account used to send an email.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, MessageSubject) Export
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#EndRegion

#EndIf

