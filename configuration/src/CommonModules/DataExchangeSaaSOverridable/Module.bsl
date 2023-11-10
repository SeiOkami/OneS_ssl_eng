///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Defines 1C:Enterprise application version required for the standalone
// workstation. Application of this version must be installed on the user's local computer.
// If a function return value is not specified,
// the default value will be used as a required application version: the first three numbers of the current
// online application version, for example, 8.3.3.
// It is used in the Standalone workstation generation wizard.
//
// Parameters:
//  Version - String - version of the required 1C:Enterprise application in the format of
//	                  "<main version>.<earlier version>.<release>.<additional release number>."
//	                  For example, "8.3.3.715".
//
Procedure OnDefineRequiredApplicationVersion(Version) Export
	
EndProcedure

// It is called when a user initiates standalone workstation creation.
// Additional checks before standalone workstation creation
//  be implemented in event handlers (and if it is impossible, an exception is thrown).
//
Procedure OnCreateStandaloneWorkstation() Export
	
EndProcedure

#EndRegion