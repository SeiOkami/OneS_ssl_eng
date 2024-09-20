///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var AccessRestrictionAtRecordLevelEnabled; // 
                                                 // 

Var AccessRestrictionAtRecordLevelChanged; // 
                                                 // 

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccessRestrictionAtRecordLevelEnabled
		= Value And Not Constants.LimitAccessAtRecordLevel.Get();
	
	AccessRestrictionAtRecordLevelChanged
		= Value <>   Constants.LimitAccessAtRecordLevel.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AccessRestrictionAtRecordLevelChanged Then
		RefreshReusableValues();
		Try
			AccessManagementInternal.OnChangeAccessRestrictionAtRecordLevel(
				AccessRestrictionAtRecordLevelEnabled);
		Except
			RefreshReusableValues();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure RegisterAChangeWhenUploading(DataElement) Export
	
	PreviousValue2 = Constants.LimitAccessAtRecordLevel.Get();
	
	If PreviousValue2 = DataElement.Value Then
		Return;
	EndIf;
	
	AccessRestrictionAtRecordLevelEnabled = PreviousValue2 And Not DataElement.Value;
	
	Catalogs.AccessGroups.RegisterRefs("LimitAccessAtRecordLevel",
		AccessRestrictionAtRecordLevelEnabled);
	
EndProcedure

// For internal use only.
Procedure ProcessTheChangeRegisteredDuringTheUpload() Export
	
	If Common.DataSeparationEnabled() Then
		// 
		Return;
	EndIf;
	
	Changes = Catalogs.AccessGroups.RegisteredRefs("LimitAccessAtRecordLevel");
	If Changes.Count() = 0 Then
		Return;
	EndIf;
	
	AccessManagementInternal.OnChangeAccessRestrictionAtRecordLevel(Changes[0]);
	
	Catalogs.AccessGroups.RegisterRefs("LimitAccessAtRecordLevel", Null);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf