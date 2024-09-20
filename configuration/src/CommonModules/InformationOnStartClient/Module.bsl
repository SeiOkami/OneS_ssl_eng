///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Called from the idle handler, and it opens the information window.
Procedure Show() Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		ModulePerformanceMonitorClient.TimeMeasurement("DataOpeningTimeOnStart");
	EndIf;
	
	If CommonClient.SubsystemExists("OnlineUserSupport.Ads") Then
		ModuleAdvertisingManagerClient = CommonClient.CommonModule("WorkingWithAdsClient");
		ModuleAdvertisingManagerClient.Show();
	Else
		OpenForm("DataProcessor.InformationOnStart.Form");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParameters.Property("InformationOnStart") And ClientParameters.InformationOnStart.Show Then
		AttachIdleHandler("ShowInformationAfterStart", 0.2, True);
	EndIf;
	
EndProcedure

#EndRegion
