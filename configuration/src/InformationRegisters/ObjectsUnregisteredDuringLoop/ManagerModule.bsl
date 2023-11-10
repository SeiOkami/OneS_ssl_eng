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

Procedure RegisterEverything(Schema, Settings) Export
	
	TemplateComposer = New DataCompositionTemplateComposer();
	CompositionTemplate = TemplateComposer.Execute(Schema, Settings, , ,Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Query = New Query;
	QueryText = CompositionTemplate.DataSets.DynamicListDataSet.Query;
	
	SchemaQuery = New QuerySchema;
	SchemaQuery.SetQueryText(QueryText);
	
	SelectedFields = SchemaQuery.QueryBatch[0].Operators[0].SelectedFields;
	SelectedFields.Add("InformationRegisterObjectsUnregisteredDuringLoop.InformationRegisterName");
	SelectedFields.Add("InformationRegisterObjectsUnregisteredDuringLoop.InformationRegisterChanges");
	
	Query.Text = SchemaQuery.GetQueryText();
	
	For Each ParameterValue In CompositionTemplate.ParameterValues Do
		Query.SetParameter(ParameterValue.Name,ParameterValue.Value);
	EndDo;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do	
		RegisterAndDeleteRecords(Selection);
	EndDo;
		
EndProcedure

Procedure RegisterSelected(Address) Export
	
	ObjectsTable = GetFromTempStorage(Address);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ObjectsTable.InfobaseNode AS InfobaseNode,
		|	ObjectsTable.Object AS Object,
		|	ObjectsTable.InformationRegisterKey AS InformationRegisterKey
		|INTO TT_ObjectsTable
		|FROM
		|	&ObjectsTable AS ObjectsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Objects.InfobaseNode AS InfobaseNode,
		|	Objects.Object AS Object,
		|	Objects.InformationRegisterKey AS InformationRegisterKey,
		|	Objects.InformationRegisterName AS InformationRegisterName,
		|	Objects.InformationRegisterChanges AS InformationRegisterChanges
		|FROM
		|	TT_ObjectsTable AS TT_ObjectsTable
		|		LEFT JOIN InformationRegister.ObjectsUnregisteredDuringLoop AS Objects
		|		ON TT_ObjectsTable.InfobaseNode = Objects.InfobaseNode
		|			AND TT_ObjectsTable.Object = Objects.Object
		|			AND TT_ObjectsTable.InformationRegisterKey = Objects.InformationRegisterKey";
	
	Query.SetParameter("ObjectsTable", ObjectsTable);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do	
		RegisterAndDeleteRecords(Selection);
	EndDo;
		
EndProcedure

Procedure RegisterAndDeleteRecords(Parameters)
	
	If ValueIsFilled(Parameters.Object) Then
			
		ExchangePlans.RecordChanges(Parameters.InfobaseNode, Parameters.Object);
		
	Else
		
		RegisterName = Parameters.InformationRegisterName;
		Filter = Parameters.InformationRegisterChanges.Get();
		
		Set = InformationRegisters[RegisterName].CreateRecordSet();
		
		For Each Dimension In Metadata.InformationRegisters[RegisterName].Dimensions Do
			Set.Filter[Dimension.Name].Set(Filter[Dimension.Name]);	
		EndDo;
		
		Set.Read();
		
		ExchangePlans.RecordChanges(Parameters.InfobaseNode, Set);
						
	EndIf;
	
	Record = InformationRegisters.ObjectsUnregisteredDuringLoop.CreateRecordManager();
	FillPropertyValues(Record, Parameters, "InfobaseNode,Object,InformationRegisterKey");
	Record.Read();
	Record.Delete();
	
EndProcedure

#EndRegion

#EndIf