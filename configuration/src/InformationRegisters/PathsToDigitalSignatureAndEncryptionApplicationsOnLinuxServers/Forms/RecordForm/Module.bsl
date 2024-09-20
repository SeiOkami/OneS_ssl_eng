///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.FillingValues.Property("Application")
	   And ValueIsFilled(Parameters.FillingValues.Application) Then
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Path to application %1 on Linux server';"),
			Parameters.FillingValues.Application);
		
		Items.Application.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// 
	// 
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers",
		New Structure("Application", Record.Application), Record.SourceRecordKey);
	
EndProcedure

#EndRegion
