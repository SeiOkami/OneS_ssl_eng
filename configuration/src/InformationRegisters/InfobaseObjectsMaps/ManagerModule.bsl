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

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Load = False) Export
	
	CheckedAttributes = New Array;
	CheckedAttributes.Add("InfobaseNode");
	CheckedAttributes.Add("DestinationUUID");
	
	For Each AttributeToCheck In CheckedAttributes Do
		If RecordStructure.Property(AttributeToCheck)
			And Not ValueIsFilled(RecordStructure[AttributeToCheck]) Then
			
			EventDescription1 = NStr("en = 'Add a record to the ""Mapping of infobase objects"" information register';",
				Common.DefaultLanguageCode());
			Comment     = NStr("en = 'Attribute %1 is not filled in. Cannot create the register record.';");
			Comment     = StringFunctionsClientServer.SubstituteParametersToString(Comment, AttributeToCheck);
			WriteLogEvent(EventDescription1, 
			                         EventLogLevel.Error,
			                         Metadata.InformationRegisters.InfobaseObjectsMaps,
			                         ,
			                         Comment);
			
			Return;
			
		EndIf;
	EndDo;
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "InfobaseObjectsMaps", Load);
	
EndProcedure

// Deletes a register record set based on the passed structure values.
Procedure DeleteRecord(RecordStructure, Load = False) Export
	
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "InfobaseObjectsMaps", Load);
	
EndProcedure

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT TOP 1 1
	|FROM
	|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|WHERE
	|	  InfobaseObjectsMaps.InfobaseNode           = &InfobaseNode
	|	AND InfobaseObjectsMaps.SourceUUID = &SourceUUID
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode",           InfobaseNode);
	Query.SetParameter("SourceUUID", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure DeleteObsoleteExportByRefModeRecords(InfobaseNode) Export
	
	QueryText = "
	|////////////////////////////////////////////////////////// {InfobaseObjectsMapsByRef}
	|SELECT
	|	InfobaseObjectsMaps.InfobaseNode,
	|	InfobaseObjectsMaps.SourceUUID,
	|	InfobaseObjectsMaps.DestinationUUID,
	|	InfobaseObjectsMaps.DestinationType,
	|	InfobaseObjectsMaps.SourceType
	|INTO InfobaseObjectsMapsByRef
	|FROM
	|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|WHERE
	|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
	|	AND InfobaseObjectsMaps.ObjectExportedByRef
	|;
	|
	|//////////////////////////////////////////////////////////{}
	|SELECT DISTINCT
	|	InfobaseObjectsMapsByRef.InfobaseNode,
	|	InfobaseObjectsMapsByRef.SourceUUID,
	|	InfobaseObjectsMapsByRef.DestinationUUID,
	|	InfobaseObjectsMapsByRef.DestinationType,
	|	InfobaseObjectsMapsByRef.SourceType
	|FROM
	|	InfobaseObjectsMapsByRef AS InfobaseObjectsMapsByRef
	|LEFT JOIN InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
	|ON   InfobaseObjectsMaps.SourceUUID = InfobaseObjectsMapsByRef.SourceUUID
	|	AND InfobaseObjectsMaps.ObjectExportedByRef = FALSE
	|	AND InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
	|WHERE
	|	NOT InfobaseObjectsMaps.InfobaseNode IS NULL
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			RecordStructure = New Structure("InfobaseNode, SourceUUID, DestinationUUID, DestinationType, SourceType");
			
			FillPropertyValues(RecordStructure, Selection);
			
			DeleteRecord(RecordStructure, True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddObjectToAllowedObjectsFilter(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("SourceUUID", Object);
		RecordStructure.Insert("ObjectExportedByRef", True);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf