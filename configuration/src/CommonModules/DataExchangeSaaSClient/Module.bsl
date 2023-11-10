///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Client application session startup handler.
// If the current session is a standalone workstation session, the procedure notifies a user
// that data synchronization with a web application is required
// (provided that the appropriate flag is set).
//
Procedure OnStart(Parameters) Export
	
	If CommonClient.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientRunParameters.IsStandaloneWorkplace Then
		ParameterName = "StandardSubsystems.SuggestDataSynchronizationWithWebApplicationOnExit";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, Undefined);
		EndIf;
		
		ApplicationParameters["StandardSubsystems.SuggestDataSynchronizationWithWebApplicationOnExit"] =
			ClientRunParameters.SynchronizeDataWithWebApplicationOnExit;
		
		If ClientRunParameters.SynchronizeDataWithWebApplicationOnStart Then
			
			ShowUserNotification(NStr("en = 'Standalone mode';"), "e1cib/app/DataProcessor.DataExchangeExecution",
				NStr("en = 'It is recommended that you synchronize the workstation data with the web application.';"), PictureLib.Information32);
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SSL subsystems

// Redefines a list of warnings displayed to a user before they exit the application.
//
// Parameters:
//  Cancel - Boolean - indicates whether the application closing must be canceled. If the parameter
//                   is set to True in the handler, the application is not closed.
//  Warnings - Array - you can add elements of the Structure type to the array,
//                            the structure properties are listed in StandardSubsystemsClient.BeforeExit. 
//
Procedure BeforeExit(Cancel, Warnings) Export
	
	StandaloneModeParameters = StandardSubsystemsClient.ClientParameter("StandaloneModeParameters");
	
	If ApplicationParameters["StandardSubsystems.SuggestDataSynchronizationWithWebApplicationOnExit"] = True
		And StandaloneModeParameters.SynchronizationWithServiceNotExecutedLongTime Then
		
		WarningParameters = StandardSubsystemsClient.WarningOnExit();
		WarningParameters.ExtendedTooltip = NStr("en = 'Data synchronization may take a while if:
	        | • The connection is slow
	        | • The amount of data to sync is big
	        | • An application update is available online';");

		WarningParameters.WarningText = NStr("en = 'Data is not synchronized with the web application.';");
		WarningParameters.CheckBoxText = NStr("en = 'Synchronize data with web application';");
		WarningParameters.Priority = 80;
		
		ActionIfFlagSet = WarningParameters.ActionIfFlagSet;
		ActionIfFlagSet.Form = "DataProcessor.DataExchangeExecution.Form.Form";
		
		FormParameters = StandaloneModeParameters.DataExchangeExecutionFormParameters;
		FormParameters = CommonClient.CopyRecursive(FormParameters, False);
		FormParameters.Insert("ShouldExitApp", True);
		ActionIfFlagSet.FormParameters = FormParameters;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

#EndRegion
