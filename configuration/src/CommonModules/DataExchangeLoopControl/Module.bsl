///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Procedure ImportCircuitFromMessage(ExchangeComponents, Header) Export
	
	If Not Header.IsSet("SynchronizationContour") Then
		Return;
	EndIf;
		
	If Header.SynchronizationContour <> Undefined Then
		
		Tree = New ValueTree;
		Tree.Columns.Add("NodeCode");
		Tree.Columns.Add("CorrespondentNodeCode");
		Tree.Columns.Add("NodeName");
		Tree.Columns.Add("PeerInfobaseNodeName");
		Tree.Columns.Add("LatestUpdate");
		Tree.Columns.Add("Prefix");
		Tree.Columns.Add("Looping");
		
		For Each Node In Header.SynchronizationContour.Node Do
			
			NewNode = Tree.Rows.Add();
			NewNode.NodeCode = Node.Code;
			NewNode.NodeName = GetStringFromBinaryData(GetBinaryDataFromBase64String(Node.Name));
			NewNode.LatestUpdate = Node.LastUpdate;
			NewNode.Prefix = Node.Prefix;
				
			For Each CorrNode In Node.CorrNodes.CorrNode Do
					
				NewPeerNode = NewNode.Rows.Add();
				NewPeerNode.CorrespondentNodeCode = CorrNode.Code;
				NewPeerNode.PeerInfobaseNodeName = GetStringFromBinaryData(GetBinaryDataFromBase64String(CorrNode.Name));
				NewPeerNode.Looping = CorrNode.Looping;
				
			EndDo;
			
		EndDo;
		
		ExchangePlanName = ExchangeComponents.CorrespondentNode.Metadata().Name;
		
		UpdateCircuitFromTree(Tree, ExchangePlanName);
		ReplacePrefixes();
		CheckLooping(ExchangePlanName);
		
	EndIf;
	
EndProcedure

Procedure ExportCircuitToMessage(Header, ExchangePlanName) Export
	
	UpdateCircuit(ExchangePlanName);
	
	SynchronizationCircuit = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "SynchronizationContour"));
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit.NodeName AS NodeName,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName,
		|	Circuit.LatestUpdate AS LatestUpdate,
		|	Circuit.Prefix AS Prefix,
		|	Circuit.Looping AS Looping
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|TOTALS
		|	MAX(NodeName),
		|	MAX(LatestUpdate),
		|	MAX(Prefix)
		|BY
		|	NodeCode";
	
	SelectionByNodes = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionByNodes.Next() Do
		
		Node = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "Node"));
		Node.Code 		= SelectionByNodes.NodeCode;
		Node.Name 		= GetBase64StringFromBinaryData(GetBinaryDataFromString(SelectionByNodes.NodeName));
		Node.LastUpdate = SelectionByNodes.LatestUpdate;
		Node.Prefix 	= SelectionByNodes.Prefix;
		
		PeerNodes = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "CorrNodes"));
		
		SelectionByPeerNodes = SelectionByNodes.Select();
		While SelectionByPeerNodes.Next() Do	
			
			PeerNode = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "CorrNode"));
			PeerNode.Code = SelectionByPeerNodes.CorrespondentNodeCode;
			PeerNode.Name = GetBase64StringFromBinaryData(GetBinaryDataFromString(SelectionByPeerNodes.PeerInfobaseNodeName));
			PeerNode.Looping = SelectionByPeerNodes.Looping;
			PeerNodes.CorrNode.Add(PeerNode);
			
		EndDo;
		
		If PeerNodes.CorrNode.Count() > 0 Then
			Node.CorrNodes = PeerNodes;
		Else
			Node.CorrNodes = Undefined;
		EndIf;
		
		SynchronizationCircuit.Node.Add(Node);
		
	EndDo;

	If SynchronizationCircuit.Node.Count() > 0 Then
		Header.SynchronizationContour = SynchronizationCircuit;
	Else
		Header.SynchronizationContour = Undefined;	
	EndIf;
		
EndProcedure

Procedure UpdateCircuit(ExchangePlanName) Export

	QueryText = 
		"SELECT DISTINCT
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.Prefix AS Prefix
		|INTO TT_Prefixes
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Circuit.InfobaseNode AS InfobaseNode,
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit.NodeName AS NodeName,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName,
		|	Circuit.LatestUpdate AS LatestUpdate
		|INTO TT_Circuit
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.InfobaseNode <> UNDEFINED
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Nodes.Ref AS Ref,
		|	ISNULL(TT_Prefixes.NodeCode, Nodes.Code) AS Code,
		|	Nodes.Description AS Description
		|INTO TT_Nodes
		|FROM
		|	&ExchangePlan AS Nodes
		|		LEFT JOIN TT_Prefixes AS TT_Prefixes
		|		ON Nodes.Code = TT_Prefixes.Prefix
		|WHERE
		|	Nodes.Ref <> &ThisNode
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TRUE AS DeletionRequired
		|INTO TT_DeletionRequired
		|FROM
		|	TT_Circuit AS TT_Circuit
		|		FULL JOIN TT_Nodes AS TT_Nodes
		|		ON TT_Circuit.InfobaseNode = TT_Nodes.Ref
		|WHERE
		|	TT_Nodes.Ref IS NULL
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Nodes.Ref AS Ref,
		|	TT_Nodes.Code AS Code,
		|	TT_Nodes.Description AS Description,
		|	TT_Circuit.NodeCode AS NodeCode,
		|	TT_Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	TT_Circuit.InfobaseNode AS InfobaseNode,
		|	CASE
		|		WHEN NOT TT_Circuit.InfobaseNode IS NULL
		|				AND NOT TT_Nodes.Ref IS NULL
		|				AND (TT_Circuit.NodeCode <> &ThisNodeCode
		|					OR TT_Circuit.NodeName <> &ThisNodeDescription
		|					OR TT_Circuit.CorrespondentNodeCode <> TT_Nodes.Code
		|					OR TT_Circuit.PeerInfobaseNodeName <> TT_Nodes.Description)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS UpdateBankingDetails,
		|	CASE
		|		WHEN TT_Circuit.InfobaseNode IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS AddNodeToCircuit,
		|	CASE
		|		WHEN TT_Nodes.Ref IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RemoveNodeFromCircuit,
		|	CASE
		|		WHEN ISNULL(TT_DeletionRequired.DeletionRequired, FALSE)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS InstallNewestUpdate
		|FROM
		|	TT_Circuit AS TT_Circuit
		|		FULL JOIN TT_Nodes AS TT_Nodes
		|		ON TT_Circuit.InfobaseNode = TT_Nodes.Ref
		|		FULL JOIN TT_DeletionRequired AS TT_DeletionRequired
		|		ON (TRUE)";
		
	QueryText = StrReplace(QueryText, "&ExchangePlan", "ExchangePlan." + ExchangePlanName);
	
	ThisNode = DataExchangeCached.GetThisExchangePlanNode(ExchangePlanName);
	Prefix = Constants.DistributedInfobaseNodePrefix.Get();
	
	Query = New Query(QueryText);
	Query.SetParameter("ThisNode", ThisNode);
	Query.SetParameter("ThisNodeCode", ThisNode.Code);
	Query.SetParameter("ThisNodeDescription", ThisNode.Description);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.UpdateBankingDetails Then
			
			Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
			FillPropertyValues(Record, Selection);
			Record.Read();
			Record.NodeCode = ThisNode.Code;
			Record.NodeName = ThisNode.Description;
			Record.CorrespondentNodeCode = Selection.Code;
			Record.PeerInfobaseNodeName = Selection.Description;
			Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
			Record.Prefix = Prefix;
			Record.Write();
			
		ElsIf Selection.AddNodeToCircuit Then
			
			Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
			Record.InfobaseNode = Selection.Ref;
			Record.NodeCode = ThisNode.Code;
			Record.NodeName= ThisNode.Description;
			Record.CorrespondentNodeCode = Selection.Code;
			Record.PeerInfobaseNodeName = Selection.Description;
			Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
			Record.Prefix = Prefix;
			Record.Write();
			
		ElsIf Selection.RemoveNodeFromCircuit Then
			
			Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
			FillPropertyValues(Record, Selection);
			Record.Read();
			Record.Delete();
			
			DeletePeerNode(Selection.NodeCode, Selection.CorrespondentNodeCode);
			
		ElsIf Selection.InstallNewestUpdate Then
			
			Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
			FillPropertyValues(Record, Selection);
			Record.Read();
			Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
			Record.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure 

Procedure CheckLooping(ExchangePlanName, Mode = "CircuitImport") Export
	
	ThisNode = ExchangePlans[ExchangePlanName].ThisNode();
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
		"SELECT
		|	Nodes.InfobaseNode AS InfobaseNode,
		|	Nodes.NodeCode AS NodeCode,
		|	Nodes.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Nodes.NodeName AS NodeName,
		|	Nodes.PeerInfobaseNodeName AS PeerInfobaseNodeName,
		|	Nodes.IsSyncDeleted AS IsSyncDeleted,
		|	Nodes.LatestUpdate AS LatestUpdate,
		|	Nodes.Prefix AS Prefix,
		|	Nodes.Looping AS Looping
		|INTO TT_Circuit
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Nodes
		|		INNER JOIN InformationRegister.SynchronizationCircuit AS PeerNodes
		|		ON Nodes.NodeCode = PeerNodes.CorrespondentNodeCode
		|			AND Nodes.CorrespondentNodeCode = PeerNodes.NodeCode";
	
	Query.Execute();
			
	If Mode = "CircuitImport" Then
		
		//  
		// 

		Query.Text = 
			"SELECT TOP 1
			|	Circuit.NodeCode AS NodeCode
			|FROM
			|	TT_Circuit AS Circuit
			|WHERE
			|	Circuit.InfobaseNode = UNDEFINED
			|	AND Circuit.CorrespondentNodeCode = &NodeCode
			|	AND Circuit.Looping";
		
		Query.SetParameter("NodeCode", ThisNode.Code);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Return;
		EndIf;
		
	EndIf;
	
	//
	Query.Text =
		"SELECT
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit.NodeName AS NodeName,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName
		|FROM
		|	TT_Circuit AS Circuit
		|TOTALS
		|	MAX(NodeName)
		|BY
		|	NodeCode";
		
	SynchronizationCircuit = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	NodesList = CheckLoopRecursively(SynchronizationCircuit, ThisNode.Code);
	
	If NodesList = Undefined Then
		ClearLoopFlag();
	Else
		SetLoopFlag(NodesList);	
	EndIf;
		
EndProcedure  

Function HasLoop() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SynchronizationCircuit.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS SynchronizationCircuit
		|WHERE
		|	SynchronizationCircuit.Looping";
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

Function IsNodeLooped(InfobaseNode) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SynchronizationCircuit.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS SynchronizationCircuit
		|WHERE
		|	SynchronizationCircuit.Looping
		|	AND (SynchronizationCircuit.NodeCode = &NodeCode
		|			OR SynchronizationCircuit.CorrespondentNodeCode = &NodeCode)";
	
	Query.SetParameter("NodeCode", InfobaseNode.Code);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

Function AllLoopedNodesPresentation() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.NodeName AS NodeName,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName
		|INTO TT_Circuit
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.Looping
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_Circuit.NodeName AS NodeName
		|FROM
		|	TT_Circuit AS TT_Circuit
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TT_Circuit.PeerInfobaseNodeName
		|FROM
		|	TT_Circuit AS TT_Circuit";
	
	NodesArray = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NodeName = Selection.NodeName;
		NodesArray.Add(" - " + NodeName);
	EndDo;
	
	Return StrConcat(NodesArray, Chars.LF);
	
EndFunction

Function InfobaseWithSuspendedRegistrationPresentation() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	Circuit.NodeName AS NodeName
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.Looping";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.NodeName;
	Else
		Return "";
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function CheckLoopRecursively(SynchronizationCircuit, InitialNode, CurrentNode = "", Val Parent = "", Val NodesChain = Undefined) 
	
	If NodesChain = Undefined Then
		NodesChain = New ValueList; 
	Else
		NodesChain.Add(CurrentNode);
	EndIf;
	
	If CurrentNode = "" Then
		CurrentNode = InitialNode;
	EndIf;
	
	If NodesChain.FindByValue(InitialNode) <> Undefined Then
		Return NodesChain;
	EndIf;
		
	Filter = New Structure("NodeCode", CurrentNode);
	Nodes = SynchronizationCircuit.Rows.FindRows(Filter);
	
	For Each Node In Nodes Do
		For Each PeerNode In Node.Rows Do
			
			If PeerNode.CorrespondentNodeCode = Parent Then //  
				Continue;
			EndIf;
			
			Result = CheckLoopRecursively(SynchronizationCircuit, InitialNode, PeerNode.CorrespondentNodeCode, CurrentNode, NodesChain);
			
			If Result <> Undefined Then
				Return Result;
			EndIf;
				
		EndDo;
	EndDo;
	
EndFunction 

Procedure UpdateCircuitFromTree(Tree, ExchangePlanName)
	
	ManagerExchangePlan = ExchangePlans[ExchangePlanName];
	ThisNode = ManagerExchangePlan.ThisNode();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit.NodeName AS NodeName,
		|	Circuit.PeerInfobaseNodeName AS PeerInfobaseNodeName,
		|	Circuit.LatestUpdate AS LatestUpdate,
		|	1 AS RecordsCount
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.InfobaseNode = UNDEFINED
		|TOTALS
		|	MAX(LatestUpdate),
		|	SUM(RecordsCount)
		|BY
		|	NodeCode";
	
	SynchronizationCircuit = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each TreeNode In Tree.Rows Do
		
		// 
		If TreeNode.NodeCode = ThisNode.Code Then
			Continue;
		EndIf;
		
		Filter = New Structure("NodeCode", TreeNode.NodeCode);
		CircuitNodes = SynchronizationCircuit.Rows.FindRows(Filter);

		// 
		If CircuitNodes.Count() > 0 
			And CircuitNodes[0].LatestUpdate < TreeNode.LatestUpdate
			And CircuitNodes[0].RecordsCount > 0 Then
			
			For Each CircuitPeerNode In CircuitNodes[0].Rows Do
				
				Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
				Record.InfobaseNode = Undefined;
				Record.NodeCode = CircuitPeerNode.NodeCode;
				Record.CorrespondentNodeCode = CircuitPeerNode.CorrespondentNodeCode;
				Record.Read();
				Record.Delete();
				
			EndDo;
			
		EndIf;
		
		If CircuitNodes.Count() = 0
			Or (CircuitNodes[0].LatestUpdate < TreeNode.LatestUpdate 
			And CircuitNodes[0].RecordsCount > 0) Then
			
			For Each TreePeerNode In TreeNode.Rows Do
				
				Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
				Record.InfobaseNode = Undefined;
				Record.NodeCode = TreeNode.NodeCode;
				Record.NodeName = TreeNode.NodeName;
				Record.CorrespondentNodeCode = TreePeerNode.CorrespondentNodeCode;
				Record.PeerInfobaseNodeName = TreePeerNode.PeerInfobaseNodeName;
				Record.LatestUpdate = TreeNode.LatestUpdate;
				Record.Prefix = TreeNode.Prefix;
				Record.Looping = TreePeerNode.Looping;
				Record.Write();
				
			EndDo;
			
		EndIf;
		
	EndDo;
			
EndProcedure

Procedure ReplacePrefixes()
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	Circuit1.InfobaseNode AS InfobaseNode,
		|	Circuit1.NodeCode AS NodeCode,
		|	Circuit1.CorrespondentNodeCode AS CorrespondentNodeCode,
		|	Circuit2.NodeCode AS NewCodeOfPeerNode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit1
		|		INNER JOIN InformationRegister.SynchronizationCircuit AS Circuit2
		|		ON Circuit1.CorrespondentNodeCode = Circuit2.Prefix"; 
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		Record.CorrespondentNodeCode = Selection.NewCodeOfPeerNode;
		Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
		Record.Write();
			
	EndDo;
	
EndProcedure

Procedure SetLoopFlag(NodesList = Undefined)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.InfobaseNode AS InfobaseNode,
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.InfobaseNode <> UNDEFINED
		|	AND Circuit.CorrespondentNodeCode IN(&NodesList)";
	
	Query.SetParameter("NodesList", NodesList);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		Record.Looping = True;
		Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
		Record.Write();
		
		InformationRegisters.CommonInfobasesNodesSettings.SetLoop(Selection.InfobaseNode, True);
			
	EndDo;
	
	RefreshReusableValues();
	
EndProcedure

Procedure ClearLoopFlag()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.InfobaseNode AS InfobaseNode,
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit";
		
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		Record.Looping = False;
		Record.LatestUpdate = ToUniversalTime(CurrentSessionDate());
		Record.Write();
		
		InformationRegisters.CommonInfobasesNodesSettings.SetLoop(Selection.InfobaseNode, False, False);
			
	EndDo;
	
	RefreshReusableValues();
	
EndProcedure

Procedure DeletePeerNode(NodeCode, CorrespondentNodeCode)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Circuit.InfobaseNode AS InfobaseNode,
		|	Circuit.NodeCode AS NodeCode,
		|	Circuit.CorrespondentNodeCode AS CorrespondentNodeCode
		|FROM
		|	InformationRegister.SynchronizationCircuit AS Circuit
		|WHERE
		|	Circuit.NodeCode = &NodeCode
		|	AND Circuit.CorrespondentNodeCode = &CorrespondentNodeCode";
	
	Query.SetParameter("NodeCode", CorrespondentNodeCode);
	Query.SetParameter("CorrespondentNodeCode", NodeCode);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Record = InformationRegisters.SynchronizationCircuit.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		Record.Delete();
	EndDo;
	
EndProcedure

Function XMLBasicSchema()
	
	Return "http://www.1c.ru/SSL/Exchange/Message";
	
EndFunction

#EndRegion