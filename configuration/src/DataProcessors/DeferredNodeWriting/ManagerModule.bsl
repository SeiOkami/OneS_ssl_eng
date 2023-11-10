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

Procedure WriteANode(Node, NodeBeforeWrite) Export
	
	ObjectNode = Node.GetObject();
	
	For Each KeyAndValue In NodeBeforeWrite Do
		
		Var_Key = KeyAndValue.Key;
		Value = KeyAndValue.Value;
		
		If TypeOf(Value) = Type("ValueTable") Then
			ObjectNode[Var_Key].Load(Value);
		Else
			ObjectNode[Var_Key] = Value;	
		EndIf;
		
	EndDo;
	
	BeginTransaction();
	
	Try
			
		Block = New DataLock;
		LockItem = Block.Add(Common.TableNameByRef(Node));
		LockItem.SetValue("Ref", Node);
		Block.Lock();

		ObjectNode.AdditionalProperties.Insert("DeferredNodeWriting");
		ObjectNode.Write();
		
		Cancel  = False;
		DataExchangeServer.NodeFormOnWriteAtServer(ObjectNode, Cancel);

		CommitTransaction();

	Except
	
		RollbackTransaction();
	    Raise;
		
	EndTry;
	
EndProcedure


#EndRegion

#EndIf