///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

//  
//  
// 
//
// 
// 
// 
// 
//
// Parameters:
//  Parameters - Structure:
//   * Cancel         - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - a return value. If True and the Cancel parameter
//                              is True, restarts the application.
// 
//   * AdditionalParametersOfCommandLine - String - a return value. Has a point when Cancel
//                              and Restart are True.
//
//   * InteractiveHandler - NotifyDescription -
//                              
//                               
//
//   * ContinuationHandler   - NotifyDescription -
//                               
//
//   * Modules                 - Array - references to the modules that will run the procedure after the return.
//                              You can add modules only by calling an overridable module procedure.
//                              It helps to simplify the design where a sequence of asynchronous calls
//                              are made to a number of subsystems. See the example for SSLSubsystemsIntegrationClient.BeforeStart. 
//
// Example:
//  The below code opens a window that blocks signing in to an application.
//
//		If OpenWindowOnStart Then
//			Parameter.InteractiveHandler = New NotificationDetails("OpenWindow", ThisObject);
//		EndIf;
//
//	Procedure OpenWindow(Parameters, AdditionalParameters) Export
//		// Showing the window. Once the window is closed, calling the OpenWindowCompletion notification handler.
//		Notification = New NotificationDetails("OpenWindowCompletion", ThisObject, Parameters);
//		Form = OpenForm(… ,,, … Notification);
//		If Not Form.IsOpen() Then // If OnCreateAtServer Cancel is True.
//			ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		EndIf;
//	EndProcedure
//
//	Procedure OpenWindowCompletion(Result, Parameters) Export
//		…
//		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		
//	EndProcedure
//
Procedure BeforeStart(Parameters) Export
	
EndProcedure

//  
//  
// 
//
// 
// 
// 
// 
//
// Parameters:
//  Parameters - Structure:
//   * Cancel         - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - a return value. If True and the Cancel parameter
//                              is True, restarts the application.
//
//   * AdditionalParametersOfCommandLine - String - a return value. Has a point
//                              when Cancel and Restart are True.
//
//   * InteractiveHandler - NotifyDescription - a return value. To open the window that locks the application
//                              start, pass the notification description handler
//                              that opens the window. See the BeforeStart for an example. 
//
//   * ContinuationHandler   - NotifyDescription -
//                              
//                              
//   * Modules                 - Array - references to the modules that will run the procedure after the return.
//                              You can add modules only by calling an overridable module procedure.
//                              It helps to simplify the design where a sequence of asynchronous calls
//                              are made to a number of subsystems. See the example for SSLSubsystemsIntegrationClient.BeforeStart. 
//
Procedure OnStart(Parameters) Export
	
	
	
	
	
EndProcedure

// 
//  
// 
//
// Parameters:
//  StartupParameters  - Array of String -
//                      
//  Cancel             - Boolean - If True, the start is aborted.
//
Procedure LaunchParametersOnProcess(StartupParameters, Cancel) Export
	
EndProcedure

// 
// 
// 
//
// 
// 
// 
// 
//
Procedure AfterStart() Export
	
EndProcedure

//  
//  
//  
// 
//  
// 
//
// 
// 
// 
// 
//
// Parameters:
//  Cancel          - Boolean - If True, the application exit 
//                            is interrupted.
//  Warnings - Array of See StandardSubsystemsClient.WarningOnExit - 
//                            you can add information about the warning appearance and the next steps.
//
Procedure BeforeExit(Cancel, Warnings) Export
	
EndProcedure

// 
//
// Parameters:
//  ApplicationCaption - String -
//  OnStart          - Boolean -
//                                 
//                                  
//                                 
//                                  
//
// Example:
//   
//  
//
//	
//		
//	
//	
//		
//	
//	   
//		
//	
//
Procedure ClientApplicationCaptionOnSet(ApplicationCaption, OnStart) Export
	
	
	
EndProcedure

// 
// 
// 
// 
// 
//
// 
// 
// 
// 
//
// 
// 
// 
//
// Parameters:
//  Parameters - Map of KeyAndValue:
//    * Key     - String       -
//    * Value - Arbitrary -
//
// Example:
//	
//	
//		
//			
//			
//		
//	
//		
//	
//	
//		
//
Procedure BeforeRecurringClientDataSendToServer(Parameters) Export
	
EndProcedure

// 
// 
// 
//
// 
// 
// 
//
// Parameters:
//  Results - Map of KeyAndValue:
//    * Key     - String       -
//    * Value - Arbitrary -
//
// Example:
//	
//	
//		
//			
//			
//		
//	
//		
//	
//	
//		
//
Procedure AfterRecurringReceiptOfClientDataOnServer(Results) Export
	
EndProcedure

#EndRegion
