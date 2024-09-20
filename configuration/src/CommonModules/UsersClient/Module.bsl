///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// See Users.AuthorizedUser.
Function AuthorizedUser() Export
	
	Return StandardSubsystemsClient.ClientParameter("AuthorizedUser");
	
EndFunction

// See Users.CurrentUser.
Function CurrentUser() Export
	
	Return UsersInternalClientServer.CurrentUser(AuthorizedUser());
	
EndFunction

// See Users.IsExternalUserSession.
Function IsExternalUserSession() Export
	
	Return StandardSubsystemsClient.ClientParameter("IsExternalUserSession");
	
EndFunction

// 
// 
// Parameters:
//  CheckSystemAdministrationRights - See Users.IsFullUser.CheckSystemAdministrationRights
//
// Returns:
//  Boolean - 
//
Function IsFullUser(CheckSystemAdministrationRights = False) Export
	
	If CheckSystemAdministrationRights Then
		Return StandardSubsystemsClient.ClientParameter("IsFullUser");
	Else
		Return StandardSubsystemsClient.ClientParameter("IsSystemAdministrator");
	EndIf;
	
EndFunction

#EndRegion
