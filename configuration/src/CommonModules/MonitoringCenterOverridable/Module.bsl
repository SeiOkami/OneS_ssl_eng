///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// It is executed upon starting a scheduled job.
//
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	
	
	
	
	
	
EndProcedure

// This procedure defines default settings applied to subsystem objects.
//
// Parameters:
//   Settings - Structure - Collection of subsystem settings. Has the following attributes:
//       * EnableNotifications - Boolean - a default value for user notifications:
//           True - by default, the system administrator is notified, for example, if there is no "To do list" subsystem.
//           False - by default, the system administrator is not notified.
//           The default value depends on availability of the "To do list" subsystem.                              
//
Procedure OnDefineSettings(Settings) Export
	
	
	
EndProcedure

#EndRegion
