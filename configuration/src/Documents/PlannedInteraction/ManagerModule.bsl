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

// StandardSubsystems.Interactions

// Gets planned interaction participants.
//
// Parameters:
//  Ref  - DocumentRef.PlannedInteraction - a document whose contacts are to be received.
//
// Returns:
//   ValueTable   - Table containing the columns Contact, Presentation, and Address.
//
Function GetContacts(Ref) Export
	
	Return Interactions.GetParticipantsByTable(Ref);
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Comment");
	Result.Add("Attendees.Contact");
	Result.Add("Attendees.ContactPresentation");
	Result.Add("Attendees.HowToContact");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmployeeResponsible, Disabled AS FALSE)
	|	OR ValueAllowed(Author, Disabled AS FALSE)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	Documents.Meeting.AddGenerateCommand(GenerationCommands);
	Documents.SMSMessage.AddGenerateCommand(GenerationCommands);
	Documents.PhoneCall.AddGenerateCommand(GenerationCommands);
	Documents.OutgoingEmail.AddGenerateCommand(GenerationCommands);
	
EndProcedure

// For use in the AddCreateOnBasisCommands procedure of other object manager modules.
// Adds this object to the list of commands of creation on basis.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	Command = GenerateFrom.AddGenerationCommand(GenerationCommands, Metadata.Documents.PlannedInteraction);
	If Command <> Undefined Then
		Command.FunctionalOptions = "UseOtherInteractions";
		Command.Importance = "SeeAlso";
	EndIf;
	
	Return Command;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.PlannedInteraction.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf