///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Completes measuring the time of a key operation.
// The procedure is called from an idle handler.
//
Procedure EndTimeMeasurementAuto() Export
	
#If MobileClient Then
	If MainServerAvailable() = False Then
		Return;
	EndIf;
#EndIf
	
	PerformanceMonitorClient.StopTimeMeasurementAtClientAuto();
		
EndProcedure

// Calls the server function for recording measurement results.
// The procedure is called from an idle handler.
//
Procedure WriteResultsAuto() Export
	
#If MobileClient Then
	If MainServerAvailable() = False Then
		Return;
	EndIf;
#EndIf
	
	PerformanceMonitorClient.WriteResultsAutoNotGlobal();
	
EndProcedure

#EndRegion
