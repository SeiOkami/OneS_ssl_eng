///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(BulkEmail, Parameters)
	EventLogParameters = EventLogParameters(BulkEmail);
	If EventLogParameters = Undefined Then
		ShowMessageBox(, NStr("en = 'Report distribution has not been started yet.';"));
		Return;
	EndIf;
	OpenForm("DataProcessor.EventLog.Form", EventLogParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtServer
Function EventLogParameters(BulkEmail)
	Return ReportMailing.EventLogParameters(BulkEmail);
EndFunction

#EndRegion
