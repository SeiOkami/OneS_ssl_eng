///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Moves a totals border.
Procedure ExecuteCommand(CommandParameters, StorageAddress) Export
	SetPrivilegedMode(True);
	TotalsAndAggregatesManagementInternal.CalculateTotals();
EndProcedure

#EndRegion

#EndIf
