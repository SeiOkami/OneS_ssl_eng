///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Handlers of conditional calls from SSL

// Checks standalone workstation setup and notifies of errors.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("RestartAfterStandaloneWorkstationSetup") Then
		Parameters.Cancel = True;
		Parameters.Restart = True;
		Return;
	EndIf;
	
	If Not ClientParameters.Property("StandaloneWorkstationSetupError") Then
		Return;
	EndIf;
	
	Parameters.Cancel = True;
	Parameters.InteractiveHandler = New NotifyDescription(
		"OnCheckStandaloneWorkstationSetupInteractiveHandler", ThisObject);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Notifies about a standalone workstation setup error.
Procedure OnCheckStandaloneWorkstationSetupInteractiveHandler(Parameters, NotDefined) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	StandardSubsystemsClient.ShowMessageBoxAndContinue(
		Parameters, ClientParameters.StandaloneWorkstationSetupError);
	
EndProcedure

#EndRegion
