///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Locks or unlocks the infobase,
// depending on the data processor attribute values.
//
Procedure PerformInstallation() Export
	
	ExecuteSetLock(DisableUserAuthorisation);
	
EndProcedure

// Disables the previously enabled session lock.
//
Procedure CancelLock() Export
	
	ExecuteSetLock(False);
	
EndProcedure

// Reads the infobase lock parameters and passes them 
// to the data processor attributes.
//
Procedure GetLockParameters() Export
	
	If Users.IsFullUser(, True) Then
		CurrentMode = GetSessionsLock();
		UnlockCode = CurrentMode.KeyCode;
	Else
		CurrentMode = IBConnections.GetDataAreaSessionLock();
	EndIf;
	
	DisableUserAuthorisation = CurrentMode.Use 
		And (Not ValueIsFilled(CurrentMode.End) Or CurrentSessionDate() < CurrentMode.End);
	MessageForUsers = IBConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If DisableUserAuthorisation Then
		LockEffectiveFrom    = CurrentMode.Begin;
		LockEffectiveTo = CurrentMode.End;
	Else
		// 
		// 
		// 
		LockEffectiveFrom     = BegOfMinute(CurrentSessionDate() + 15 * 60);
	EndIf;
	
EndProcedure

Procedure ExecuteSetLock(Value)
	
	If Users.IsFullUser(, True) Then
		Block = New SessionsLock;
		Block.KeyCode    = UnlockCode;
		Block.Parameter = ServerNotifications.SessionKey();
	Else
		Block = IBConnections.NewConnectionLockParameters();
	EndIf;
	
	Block.Begin           = LockEffectiveFrom;
	Block.End            = LockEffectiveTo;
	Block.Message        = IBConnections.GenerateLockMessage(MessageForUsers, 
		UnlockCode); 
	Block.Use      = Value;
	
	If Users.IsFullUser(, True) Then
		SetSessionsLock(Block);
		
		SetPrivilegedMode(True);
		IBConnections.SendServerNotificationAboutLockSet();
		SetPrivilegedMode(False);
	Else
		IBConnections.SetDataAreaSessionLock(Block);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf