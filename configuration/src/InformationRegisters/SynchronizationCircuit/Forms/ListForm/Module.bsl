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
	
	SetConditionalAppearance();
	
	UpdateCircuit();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateCircuit();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Circuit");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Circuit.IsNode");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Font", New Font(,,True));
		
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Circuit");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Circuit.Order");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("BackColor", WebColors.LightYellow);

EndProcedure

&AtServer
Procedure UpdateCircuit()
	
	Circuit.GetItems().Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.NodeCode AS Code,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit.NodeName AS Name,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName,
		|	Circuit.LatestUpdate AS LatestUpdate,
		|	Circuit.Looping AS Looping,
		|	CASE
		|		WHEN Circuit.InfobaseNode = UNDEFINED
		|			THEN 1
		|		ELSE 0
		|	END AS Order
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|
		|ORDER BY
		|	Order
		|TOTALS
		|	MAX(NodeName),
		|	MAX(LatestUpdate),
		|	MAX(Looping),
		|	MAX(Order)
		|BY
		|	NodeCode";
	
	SelectionByNodes = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionByNodes.Next() Do
		
		NewNode = Circuit.GetItems().Add();
		FillPropertyValues(NewNode, SelectionByNodes);
		NewNode.IsNode = True;
		
		SelectionByPeerNodes = SelectionByNodes.Select();
		
		While SelectionByPeerNodes.Next() Do
			NewRootNode = NewNode.GetItems().Add();
			FillPropertyValues(NewRootNode, SelectionByNodes);
			NewRootNode.Code = SelectionByPeerNodes.CorrespondentNodeCode;
			NewRootNode.Name = SelectionByPeerNodes.PeerInfobaseNodeName;
		EndDo;
			
	EndDo;
		
EndProcedure

#EndRegion