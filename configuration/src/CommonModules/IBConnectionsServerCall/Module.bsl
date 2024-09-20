///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// See IBConnections.ConnectionsInformation.
Function ConnectionsInformation(GetConnectionString = False, MessagesForEventLog = Undefined, ClusterPort = 0) Export
	
	Return IBConnections.ConnectionsInformation(GetConnectionString, MessagesForEventLog, ClusterPort);
	
EndFunction

// Sets the infobase connection lock.
// If this function is called from a session with separator values set,
// it sets the data area session lock.
//
// Parameters:
//  MessageText           - String - text to be used in the error message
//                                      displayed when someone attempts to connect
//                                      to a locked infobase.
// 
//  KeyCode            - String - string to be added to "/uc" command line parameter
//                                       or to "uc" connection string parameter
//                                      in order to establish connection to the infobase
//                                      regardless of the lock.
//                                      Cannot be used for data area session locks.
//  WaitingForTheStartOfBlocking - Number -  delay time of the lock start in minutes.
//  LockDuration   - Number - lock duration in minutes.
//
// Returns:
//   Boolean   - 
//              
//
Function SetConnectionLock(MessageText = "", KeyCode = "KeyCode", // 
	WaitingForTheStartOfBlocking = 0, LockDuration = 0) Export 
	
	Return IBConnections.SetConnectionLock(
		MessageText, KeyCode, WaitingForTheStartOfBlocking, LockDuration);
	
EndFunction

// Removes the infobase lock.
//
// Returns:
//   Boolean   - 
//              
//
Function AllowUserAuthorization() Export
	
	Return IBConnections.AllowUserAuthorization();
	
EndFunction

#EndRegion

#Region Private

// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//  GetSessionCount - Boolean - if True, then the SessionCount field
//                                       is filled in the returned structure.
//
// Returns:
//   Structure:
//     IsSet - Boolean - True if the lock is set, otherwise False. 
//     Start - Date - lock start date. 
//     End - Date - lock end date. 
//     Message - String - message to a user. 
//     SessionTerminationTimeout - Number - interval in seconds.
//     SessionCount - 0 if the GetSessionCount parameter value is False.
//     CurrentSessionDate - Date - current session date.
//
Function SessionLockParameters(GetSessionCount = False) Export
	
	Return IBConnections.SessionLockParameters(GetSessionCount);
	
EndFunction

// Sets the data area session lock.
// 
// Parameters:
//   Parameters         - 
//   LocalTime - Boolean - lock beginning time and lock end time are specified in the local session time.
//                                If the parameter is False, they are specified in universal time.
//
Procedure SetDataAreaSessionLock(Parameters, LocalTime = True) Export
	
	IBConnections.SetDataAreaSessionLock(Parameters, LocalTime);
	
EndProcedure

Function AdministrationParameters() Export
	Return StandardSubsystemsServer.AdministrationParameters();
EndFunction

Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	AllExceptCurrent = New Structure;
	AllExceptCurrent.Insert("Property", "Number");
	AllExceptCurrent.Insert("ComparisonType", ComparisonType.NotEqual);
	AllExceptCurrent.Insert("Value", InfoBaseSessionNumber());
	
	Filter = New Array;
	Filter.Add(AllExceptCurrent);
	
	ClusterAdministration.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

#EndRegion