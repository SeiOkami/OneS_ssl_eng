///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Called upon unlocking operations with external resources.
// To enable features disabled in the OnProhibitWorkWithExternalResources procedure.
//
Procedure WhenAllowingWorkWithExternalResources() Export
	
EndProcedure

// Called upon locking operations with external resources.
// Allows enabling arbitrary features that cannot be performed
// in the infobase copy.
//
Procedure WhenYouAreForbiddenToWorkWithExternalResources() Export
	
EndProcedure

#EndRegion