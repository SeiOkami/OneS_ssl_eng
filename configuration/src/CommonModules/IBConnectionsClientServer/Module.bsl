///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Returns the full path to the infobase (connection string).
//
// Parameters:
//  FileModeFlag  - Boolean - output parameter. Takes the following value.
//                                     True if the current infobase is a file infobase;
//                                     False if the infobase is of client/server type.
//  ServerClusterPort    - Number  - input parameter. Used
//                                     if a custom server cluster port is set.
//                                     Default value is 0, 
//                                     which means that the default server cluster port is set.
//
// Returns:
//   String   - the connection string is.
//
Function InfobasePath(FileModeFlag = Undefined, Val ServerClusterPort = 0) Export
	
	ConnectionString = InfoBaseConnectionString();
	
	SearchPosition = StrFind(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // 
		
		IBPath = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		FileModeFlag = True;
		
	Else
		FileModeFlag = False;
		
		SearchPosition = StrFind(Upper(ConnectionString), "SRVR=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = StrFind(ConnectionString, ";");
		StartPositionForCopying = 6 + 1;
		EndPositionForCopying = SemicolonPosition - 2;
		
		ServerName = Mid(ConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// 
		SearchPosition = StrFind(Upper(ConnectionString), "REF=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		StartPositionForCopying = 6;
		SemicolonPosition = StrFind(ConnectionString, ";");
		EndPositionForCopying = SemicolonPosition - 2;
		
		IBNameAtServer = Mid(ConnectionString, StartPositionForCopying, EndPositionForCopying - StartPositionForCopying + 1);
		
		IBPath = """" + ServerName + "\" + IBNameAtServer + """";
	EndIf;
	
	Return IBPath;
	
EndFunction

#EndRegion

#Region Private

// Deletes all infobase sessions except the current one.
//
Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	IBConnectionsServerCall.DeleteAllSessionsExceptCurrent(AdministrationParameters);
	
EndProcedure

// Returns a text constant used to generate messages.
// The function is used for localization purposes.
//
// Returns:
//  String - 
//
Function TextForAdministrator() Export
	
	Return NStr("en = 'Message for administrator:';");
	
EndFunction

// Returns session lock message text intended for a user.
//
// Parameters:
//   Message - String - full message.
// 
// Returns:
//  String - 
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = StrFind(Message, TextForAdministrator());
	If MarkerIndex = 0  Then
		Return Message;
	ElsIf MarkerIndex >= 3 Then
		Return Mid(Message, 1, MarkerIndex - 3);
	Else
		Return "";
	EndIf;
		
EndFunction

#EndRegion
