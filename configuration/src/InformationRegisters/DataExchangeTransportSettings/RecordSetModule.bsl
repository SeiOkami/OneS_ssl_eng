///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each SetRow In ThisObject Do
		
		// Deleting insignificant characters (spaces) on the left and right for string parameters.
		TrimAllFieldValue(SetRow, "COM1CEnterpriseServerSideInfobaseName");
		TrimAllFieldValue(SetRow, "COMUserName");
		TrimAllFieldValue(SetRow, "COM1CEnterpriseServerName");
		TrimAllFieldValue(SetRow, "COMInfobaseDirectory");
		TrimAllFieldValue(SetRow, "FILEDataExchangeDirectory");
		TrimAllFieldValue(SetRow, "FTPConnectionUser");
		TrimAllFieldValue(SetRow, "FTPConnectionPath");
		TrimAllFieldValue(SetRow, "WSWebServiceURL");
		TrimAllFieldValue(SetRow, "WSUserName");
		
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// 
	// 
	RefreshReusableValues();
	
EndProcedure

#EndRegion

#Region Private

Procedure TrimAllFieldValue(Record, Val Field)
	
	Record[Field] = TrimAll(Record[Field]);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf