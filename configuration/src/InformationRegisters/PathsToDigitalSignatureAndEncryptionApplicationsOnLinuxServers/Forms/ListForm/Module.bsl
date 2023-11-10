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
	
	If Parameters.Filter.Property("Application") 
	   And ValueIsFilled(Parameters.Filter.Application) Then
		
		Application = Parameters.Filter.Application;
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Paths to application %1 on Linux servers';"), Application);
		
		Items.ListApplication.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Not ValueIsFilled(Application) Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", Items.List.CurrentRow);
	FormParameters.Insert("FillingValues", New Structure("Application", Application));
	
	OpenForm("InformationRegister.PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers.RecordForm",
		FormParameters, Items.List, ,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	
	RowToDelete          = Items.List.CurrentRow;
	RowToDeleteApplication = Items.List.CurrentData.Application;
	
EndProcedure

&AtClient
Procedure ListAfterDeleteRow(Item)
	
	Notify("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers",
		New Structure("Application", RowToDeleteApplication), RowToDelete);
	
EndProcedure

#EndRegion
