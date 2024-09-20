///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	ReadExchangeNodeTree();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CurParameters = SetFormParameters();
	Items.ExchangeNodesTree.CurrentRow = CurParameters.CurrentRow;
	
EndProcedure

&AtClient
Procedure OnReopen()
	
	CurParameters = SetFormParameters();
	Items.ExchangeNodesTree.CurrentRow = CurParameters.CurrentRow;
	
EndProcedure

#EndRegion

#Region NodeTreeFormTableItemEventHandlers

&AtClient
Procedure ExchangeNodesTreeSelection(Item, RowSelected, Field, StandardProcessing)
	PerformNodeChoice();
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Selects a node and passes the selected values to the calling form.
&AtClient
Procedure SelectNode(Command)
	PerformNodeChoice();
EndProcedure

// Opens the node form specified in the configuration.
&AtClient
Procedure ChangeNode(Command)
	
	Node = Items.ExchangeNodesTree.CurrentData.Ref;
	If Node <> Undefined Then
		ShowValue(,Node);	
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeCode.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure

&AtClient
Procedure PerformNodeChoice()
	
	Data = Items.ExchangeNodesTree.CurrentData;
	If Data <> Undefined And Data.Ref <> Undefined Then
		NotifyChoice(Data.Ref);
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadExchangeNodeTree()
		
	Tree = FormAttributeToValue("ExchangeNodesTree", Type("ValueTree"));
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	TransportSettings.Peer AS Ref,
		|	TransportSettings.Peer.Code AS Code,
		|	TransportSettings.Peer.Description AS Description,
		|	VALUETYPE(TransportSettings.Peer) AS NodeType
		|FROM
		|	InformationRegister.DataExchangeTransportSettings AS TransportSettings
		|WHERE
		|	TransportSettings.DefaultExchangeMessagesTransportKind = &TransportKind
		|	AND TransportSettings.WSCorrespondentEndpoint <> &MessageExchangeEmptyRef
		|TOTALS BY
		|	NodeType";
	
	Query.SetParameter("TransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	Query.SetParameter("MessageExchangeEmptyRef", ExchangePlans["MessagesExchange"].EmptyRef());
	
	SelectionByNodesTypes = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionByNodesTypes.Next() Do
		
		ExchangePlan = Metadata.FindByType(SelectionByNodesTypes.NodeType);
		
		RowExchangePlan = Tree.Rows.Add();
		RowExchangePlan.Description = String(ExchangePlan);
		RowExchangePlan.PictureIndex = 0;
		
		SelectionByNodes = SelectionByNodesTypes.Select();
		
		While SelectionByNodes.Next() Do
			
			RowNode = RowExchangePlan.Rows.Add();
			FillPropertyValues(RowNode, SelectionByNodes);
			RowNode.PictureIndex = 2;

		EndDo;
		
	EndDo;
	
	ValueToFormAttribute(Tree,  "ExchangeNodesTree");
	
EndProcedure

&AtServer
Function SetFormParameters()
	
	Result = New Structure("CurrentRow");
		
	If Parameters.ChoiceInitialValue <> Undefined Then
		Result.CurrentRow = RowIDByNode(ExchangeNodesTree, Parameters.ChoiceInitialValue);	
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function RowIDByNode(Data, Ref)
	For Each CurRow In Data.GetItems() Do
		If CurRow.Ref = Ref Then
			Return CurRow.GetID();
		EndIf;
		Result = RowIDByNode(CurRow, Ref);
		If Result <> Undefined Then 
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#EndRegion
