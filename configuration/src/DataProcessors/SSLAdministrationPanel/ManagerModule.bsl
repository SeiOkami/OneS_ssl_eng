///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(Total,
		"2.2.1.12",
		"Subsystem.НастройкаИАдминистрирование",
		"Subsystem.Administration",
		Library);
	
EndProcedure

// Defines sections, where the report panel is available.
//   For more information, see details of the UsedSections procedure 
//   of the ReportsOptions common module.
//
// Parameters:
//   Sections - ValueList
//
Procedure OnDefineSectionsWithReportOptions(Sections) Export
	
	Sections.Add(Metadata.Subsystems.Administration, NStr("en = 'Administrator reports';"));
	
EndProcedure

// Parameters:
//  Sections - See AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports.Sections
//
Procedure OnDefineSectionsWithAdditionalReports(Sections) Export
	
	Sections.Add(Metadata.Subsystems.Administration);
	
EndProcedure

// Parameters:
//  Sections - See AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports.Sections
//
Procedure OnDefineSectionsWithAdditionalDataProcessors(Sections) Export
	
	Sections.Add(Metadata.Subsystems.Administration);
	
EndProcedure

#EndRegion

#EndIf
