///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region ObsoleteProceduresAndFunctions

// Deprecated.Dated.
// See Users.AuthorizedUser.
// See UsersClient.AuthorizedUser.
//
Function AuthorizedUser() Export
	
// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return Users.AuthorizedUser();
#Else
	Return UsersClient.AuthorizedUser();
#EndIf
// 
	
EndFunction

// Deprecated.Dated.
// See Users.CurrentUser.
// See UsersClient.CurrentUser.
//
Function CurrentUser() Export
	
// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return Users.CurrentUser();
#Else
	Return UsersClient.CurrentUser();
#EndIf
// 
	
EndFunction

// Deprecated.Dated.
// See ExternalUsers.CurrentExternalUser.
// See ExternalUsersClient.CurrentExternalUser.
//
Function CurrentExternalUser() Export
	
// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return ExternalUsers.CurrentExternalUser();
#Else
	Return ExternalUsersClient.CurrentExternalUser();
#EndIf
// 
	
EndFunction

// Deprecated.Dated.
// See Users.IsExternalUserSession.
// See UsersClient.IsExternalUserSession.
//
Function IsExternalUserSession() Export
	
// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return Users.IsExternalUserSession();
#Else
	Return UsersClient.IsExternalUserSession();
#EndIf
// 
	
EndFunction

#EndRegion

#EndRegion
