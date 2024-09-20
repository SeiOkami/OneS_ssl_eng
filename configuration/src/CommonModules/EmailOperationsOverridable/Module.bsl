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
//   * CanReceiveEmails - Boolean - show email receiving settings in accounts.
//                                       Default value: False - for basic configuration versions,
//                                       True - for other versions.
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Allows executing additional operations after sending email.
//
// Parameters:
//  EmailParameters - Structure - contains all email data:
//   * Whom      - Array - (required) an email address of the recipient.
//                 Address - String - email address.
//                 Presentation - String - recipient's name.
//
//   * MessageRecipients - Array - array of structures describing recipients:
//                            * ContactInformationSource - CatalogRef - a contact information owner.
//                            * Address - String - email address of the message recipient.
//                            * Presentation - String - an addressee presentation.
//
//   * Cc      - Array - a collection of address structures:
//                   * Address         - String - postal address (must be filled in).
//                   * Presentation - String - a recipient's name.
//                  
//                - String - 
//
//   * BCCs - Array
//                  - String - see the "Cc" field description.
//
//   * Subject       - String - (mandatory) an email subject.
//   * Body       - String - (mandatory) an email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance
//   * Attachments   - Map of KeyAndValue:
//                   * Key     - String - an attachment description.
//                   * Value - BinaryData
//                              - String - 
//                              - Structure:
//                                 * BinaryData - BinaryData - attachment binary data.
//                                 * Id  - String - an attachment ID, used to store pictures
//                                                             displayed in the email body.
//
//   * ReplyToAddress - Map - see the "To" field description.
//   * Password      - String -
//   * BasisIDs - String - IDs of the message basis objects.
//   * ProcessTexts  - Boolean - shows whether message text processing is required on sending.
//   * RequestDeliveryReceipt  - Boolean - shows whether a delivery notification is required.
//   * RequestReadReceipt - Boolean - shows whether a read notification is required.
//   * TextType   - String
//                 - EnumRef.EmailTextTypes
//                 - InternetMailTextType - 
//                  
//                  
//                  
//                                                 
//                                                 
//                  
//                                                 
//
Procedure AfterEmailSending(EmailParameters) Export
	
	
	
EndProcedure

// 
// 
//
//   Parameters:
//  EmailMessagesIDs - ValueTable:
//   * Sender - CatalogRef.EmailAccounts
//   * EmailID - String
//   * RecipientAddress - String -
//
Procedure BeforeGetEmailMessagesStatuses(EmailMessagesIDs) Export
	
EndProcedure

// 
// 
//
// Parameters:
//  DeliveryStatuses - ValueTable:
//   * Sender - CatalogRef.EmailAccounts
//   * EmailID - String 
//   * RecipientAddress - String -
//   * Status - EnumRef.EmailMessagesStatuses 
//   * StatusChangeDate - Date
//   * Cause - String -
//
Procedure AfterGetEmailMessagesStatuses(DeliveryStatuses) Export
	
EndProcedure

#EndRegion
