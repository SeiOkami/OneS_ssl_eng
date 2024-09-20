///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Outputs messages about existing data integrity issues
// when the ToDoList subsystem is missing.
//
Procedure NotifyOfAccountingIssues() Export
	
#If MobileClient Then
	If MainServerAvailable() = False Then
		Return;
	EndIf;
#EndIf
	
	AccountingAuditInternalClient.NotifyOfAccountingIssuesCases();
EndProcedure

#EndRegion
