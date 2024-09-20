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

Var ValueChanged;

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ValueChanged = Value <> Constants.UseExternalUsers.Get();
	
	If ValueChanged
	   And Value
	   And Not UsersInternal.ExternalUsersEmbedded() Then
		Raise NStr("en = 'The application does not support external users.';");
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Constants.UseExternalUserGroups.Refresh();
	
	If ValueChanged Then
		UsersInternal.UpdateExternalUsersRoles();
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.UpdateUserRoles(Type("CatalogRef.ExternalUsers"));
			
			ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
			If ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
				PlanningParameters = ModuleAccessManagementInternal.AccessUpdatePlanningParameters();
				PlanningParameters.ForUsers = False;
				PlanningParameters.ForExternalUsers = True;
				PlanningParameters.IsUpdateContinuation = True;
				PlanningParameters.LongDesc = "UseExternalUsersOnWrite";
				ModuleAccessManagementInternal.ScheduleAccessUpdate(, PlanningParameters);
			EndIf;
		EndIf;
		If Value Then
			UsersInternal.SetShowInListAttributeForAllInfobaseUsers(False);
		Else
			ClearCanSignInAttributeForAllExternalUsers();
		EndIf;
		
		SetPropertySetUsageFlag();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Clears the FlagShowInList attribute for all infobase users.
Procedure ClearCanSignInAttributeForAllExternalUsers()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsers.IBUserID AS Id
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers";
	IDs = Query.Execute().Unload();
	IDs.Indexes.Add("Id");
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each IBUser In IBUsers Do
		
		If IDs.Find(IBUser.UUID, "Id") <> Undefined
		   And Users.CanSignIn(IBUser) Then
			
			IBUser.StandardAuthentication    = False;
			IBUser.OpenIDAuthentication         = False;
			IBUser.OpenIDConnectAuthentication  = False;
			IBUser.AccessTokenAuthentication = False;
			IBUser.OSAuthentication             = False;
			IBUser.Write();
		EndIf;
	EndDo;
	
EndProcedure

Procedure SetPropertySetUsageFlag()
	
	If Not Common.SubsystemExists("StandardSubsystems.Properties") Then
		Return;
	EndIf;
	ModulePropertyManager = Common.CommonModule("PropertyManager");
	
	SetParameters = ModulePropertyManager.PropertySetParametersStructure();
	SetParameters.Used = Value;
	ModulePropertyManager.SetPropertySetParameters("Catalog_ExternalUsers", SetParameters);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf