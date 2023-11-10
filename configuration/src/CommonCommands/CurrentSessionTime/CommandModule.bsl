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
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalInformation = AdditionalInformation();
	ShowMessageBox(,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Session time: %1
				|Server time: %2
				|Client time: %3
				|
				|The session time is the server time that
				|has been converted to the time zone:
				|%4.';"),
			Format(CommonClient.SessionDate(), "DLF=T"),
			Format(AdditionalInformation.ServerDate, "DLF=T"),
			Format(CurrentDate(), "DLF=T"), // 
			AdditionalInformation.TimeZonePresentation));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function AdditionalInformation()
	Result = New Structure;
	Result.Insert("TimeZonePresentation", TimeZonePresentation(SessionTimeZone()));
	Result.Insert("ServerDate", CurrentDate()); // 
	Return Result;
EndFunction

#EndRegion