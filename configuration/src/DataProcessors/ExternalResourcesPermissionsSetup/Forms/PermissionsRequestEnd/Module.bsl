///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var AllowClose;

&AtClient
Var WaitingCompleted;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Duration = Parameters.Duration;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AllowClose = False;
	
	If Duration > 0 Then
		WaitingCompleted = False;
		AttachIdleHandler("AfterWaitForSettingsApplyingInCluster", Duration, True);
	Else
		WaitingCompleted = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not AllowClose Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterWaitForSettingsApplyingInCluster()
	
	AllowClose = True;
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion