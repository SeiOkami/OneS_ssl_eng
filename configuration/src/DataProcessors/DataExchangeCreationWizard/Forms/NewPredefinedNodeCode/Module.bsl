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
	
	ExchangePlanName = Parameters.ExchangePlanName;
	InfobaseNode = ExchangePlans[ExchangePlanName].ThisNode();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetNewCode(Command)
	
	If InstallANewCodeOnTheServer() Then
		Close();	
	EndIf;
	
EndProcedure

&AtServer
Function InstallANewCodeOnTheServer()
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		
		DataLockItem = DataLock.Add("ExchangePlan." + ExchangePlanName);
		DataLockItem.SetValue("Ref", InfobaseNode);
				
		DataLock.Lock();

		ExchangeNodeObject = InfobaseNode.GetObject();
		ExchangeNodeObject.Code = String(New UUID);
		ExchangeNodeObject.DataExchange.Load = True;
		ExchangeNodeObject.Write();
						
		CommitTransaction();
		
		Return True;
		
	Except
				
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	Return False;
	
EndFunction

#EndRegion
