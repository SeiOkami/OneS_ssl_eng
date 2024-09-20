///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Displays a request for sending dumps.
//
Procedure MonitoringCenterDumpSendingRequest() Export
	MonitoringCenterClientInternal.NotifyRequestForSendingDumps();
EndProcedure

// Displays a request for collecting and sending dumps (one time).
//
Procedure MonitoringCenterDumpCollectionAndSendingRequest() Export
	MonitoringCenterClientInternal.NotifyRequestForReceivingDumps();
EndProcedure

// Displays a request for getting administrator contact information.
//
Procedure MonitoringCenterContactInformationRequest() Export
	MonitoringCenterClientInternal.NotifyContactInformationRequest();
EndProcedure

#EndRegion
