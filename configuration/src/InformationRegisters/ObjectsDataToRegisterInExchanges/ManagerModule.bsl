///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.ObjectsDataToRegisterInExchanges AS ObjectsDataToRegisterInExchanges
	|WHERE
	|	  ObjectsDataToRegisterInExchanges.InfobaseNode           = &InfobaseNode
	|	AND ObjectsDataToRegisterInExchanges.Ref = &Object
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Object", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure AddObjectToAllowedObjectsFilter(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("Ref", Object);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

Procedure DeleteInformationAboutUploadingObjects(ExportedByRefObjects, InfobaseNode) Export
	
	RecordStructure = New Structure("Ref, InfobaseNode");
	If TypeOf(ExportedByRefObjects) = Type("Array") Then
		
		For Each ArrayElement In ExportedByRefObjects Do
			
			RecordStructure.Ref = ArrayElement;
			RecordStructure.InfobaseNode = InfobaseNode;
			DeleteRecord(RecordStructure, True);
			
			
		EndDo;
		
	Else
		
		RecordStructure.Ref = ExportedByRefObjects;
		RecordStructure.InfobaseNode = InfobaseNode;
		DeleteRecord(RecordStructure, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Load = False)
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "ObjectsDataToRegisterInExchanges", Load);
	
EndProcedure

Procedure DeleteRecord(RecordStructure, Load = False)
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ObjectsDataToRegisterInExchanges");
		LockItem.SetValue("Ref", RecordStructure.Ref);
		LockItem.SetValue("InfobaseNode", RecordStructure.InfobaseNode);
		Block.Lock();
		
		// Use the set to support DataExchange.Import.
		RecordSet = InformationRegisters.ObjectsDataToRegisterInExchanges.CreateRecordSet();
		RecordSet.Filter.Ref.Set(RecordStructure.Ref, True);
		RecordSet.Filter.InfobaseNode.Set(RecordStructure.InfobaseNode, True);
		RecordSet.DataExchange.Load = Load;
		RecordSet.Write(True);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndIf