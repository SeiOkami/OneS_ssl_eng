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
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	RegistrationObject = Parameters.RegistrationObject;
	Details       = "";
	
	If TypeOf(RegistrationObject) = Type("Structure") Then
		RegistrationTable = Parameters.RegistrationTable;
		ObjectAsString = RegistrationTable;
		For Each KeyValue In RegistrationObject Do
			Details = Details + "," + KeyValue.Value;
		EndDo;
		Details = Mid(Details, 2);
	Else		
		RegistrationTable = "";
		ObjectAsString = RegistrationObject;
	EndIf;
	
	If IsBlankString(Details) Then
		Title = StrReplace(NStr("en = 'Register %1';"), "%1", CurrentObject.RepresentationOfTheReference(ObjectAsString));
	Else
		Title = StrReplace(NStr("en = 'Register %1 (%2)';"), "%1", CurrentObject.RepresentationOfTheReference(ObjectAsString));
		Title = StrReplace(Title, "%2", Details);
	EndIf;
	
	ReadExchangeNodes();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ExpandAllNodes();
EndProcedure

#EndRegion

#Region ExchangeNodesTreeFormTableItemEventHandlers
//

&AtClient
Procedure ExchangeNodesTreeSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	If Field = Items.ExchangeNodesTreeDescription Or Field = Items.ExchangeNodesTreeCode Then
		OpenOtherObjectEditForm();
		Return;
	ElsIf Field <> Items.ExchangeNodesTreeMessageNo Then
		Return;
	EndIf;
	
	CurrentData = Items.ExchangeNodesTree.CurrentData;
	Notification = New NotifyDescription("ExchangeNodesTreeSelectionCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Node", CurrentData.Ref);
	
	ToolTip = NStr("en = 'Sent message number';"); 
	ShowInputNumber(Notification, CurrentData.MessageNo, ToolTip);
EndProcedure

&AtClient
Procedure ExchangeNodesTreeCheckOnChange(Item)
	ChangeMark(Items.ExchangeNodesTree.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure RereadNodeTree(Command)
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes();
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenEditFormFromNode(Command)
	OpenOtherObjectEditForm();
EndProcedure

&AtClient
Procedure CheckAllNodes(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		PlanRow.Check = True;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAllNodes(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		PlanRow.Check = False;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure InvertAllNodesChecks(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			NodeRow.Check = Not NodeRow.Check;
			ChangeMark(NodeRow.GetID())
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure EditRegistration(Command)
	
	QuestionTitle = NStr("en = 'Confirm operation';");
	Text = NStr("en = 'Do you want to change registration state
	             |of %1 at all nodes?';");
	
	Text = StrReplace(Text, "%1", RegistrationObject);
	
	Notification = New NotifyDescription("EditRegistrationCompletion", ThisObject);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure EditRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Count = NodeRegistrationEdit(ExchangeNodesTree);
	If Count > 0 Then
		Text = NStr("en = 'Registration state of %1 changed at %2 nodes.';");
		NotificationTitle = NStr("en = 'Registration state changed:';");
		
		Text = StrReplace(Text, "%1", RegistrationObject);
		Text = StrReplace(Text, "%2", Count);
		
		ShowUserNotification(NotificationTitle,
			GetURL(RegistrationObject),
			Text,
			Items.HiddenPictureInformation32.Picture);
		
		If Parameters.NotifyAboutChanges Then
			Notify("ObjectDataExchangeRegistrationEdit",
				New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
				ThisObject);
		EndIf;
	EndIf;
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeMessageNo.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Check");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'ExchangeNodesTreeMessageNumber';"));
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Pending export';"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeAutoRecord.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure
//

&AtClient
Procedure ExchangeNodesTreeSelectionCompletion(Val Number, Val AdditionalParameters) Export
	If Number = Undefined Then 
		// 
		Return;
	EndIf;
	
	EditMessageNumberAtServer(AdditionalParameters.Node, Number, RegistrationObject, RegistrationTable);
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
	
	If Parameters.NotifyAboutChanges Then
		Notify("ObjectDataExchangeRegistrationEdit",
			New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
			ThisObject);
	EndIf;
EndProcedure

&AtClient
Function CurrentSelectedNode()
	CurrentData = Items.ExchangeNodesTree.CurrentData;
	If CurrentData = Undefined Then
		Return Undefined;
	EndIf;
	Return New Structure("Description, Ref", CurrentData.Description, CurrentData.Ref);
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure OpenOtherObjectEditForm()
	CurFormName = GetFormName() + "Form.Form";
	Data = Items.ExchangeNodesTree.CurrentData;
	If Data <> Undefined And Data.Ref <> Undefined Then
		CurParameters = New Structure("ExchangeNode, CommandID, RelatedObjects", Data.Ref);
		OpenForm(CurFormName, CurParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllNodes(FocusNode = Undefined)
	FoundNode = Undefined;
	
	For Each String In ExchangeNodesTree.GetItems() Do
		Id = String.GetID();
		Items.ExchangeNodesTree.Expand(Id, True);
		
		If FocusNode <> Undefined And FoundNode = Undefined Then
			If String.Description = FocusNode.Description And String.Ref = FocusNode.Ref Then
				FoundNode = Id;
			Else
				For Each Substring In String.GetItems() Do
					If Substring.Description = FocusNode.Description And Substring.Ref = FocusNode.Ref Then
						FoundNode = Substring.GetID();
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If FocusNode <> Undefined And FoundNode <> Undefined Then
		Items.ExchangeNodesTree.CurrentRow = FoundNode;
	EndIf;
	
EndProcedure

&AtServer
Function NodeRegistrationEdit(Val Data)
	CurrentObject = ThisObject();
	NodeCount = 0;
	For Each String In Data.GetItems() Do
		If String.Ref <> Undefined Then
			AlreadyRegistered = CurrentObject.ObjectRegisteredForNode(String.Ref, RegistrationObject, RegistrationTable);
			If String.Check = 0 And AlreadyRegistered Then
				Result = CurrentObject.EditRegistrationAtServer(False, True, String.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Success;
			ElsIf String.Check = 1 And (Not AlreadyRegistered) Then
				Result = CurrentObject.EditRegistrationAtServer(True, True, String.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Success;
			EndIf;
		EndIf;
		NodeCount = NodeCount + NodeRegistrationEdit(String);
	EndDo;
	Return NodeCount;
EndFunction

&AtServer
Function EditMessageNumberAtServer(Node, MessageNo, Data, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(MessageNo, True, Node, Data, TableName);
EndFunction

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction

&AtServer
Procedure ChangeMark(String)
	DataElement = ExchangeNodesTree.FindByID(String);
	ThisObject().ChangeMark(DataElement);
EndProcedure

&AtServer
Procedure ReadExchangeNodes(OnlyUpdate = False)
	CurrentObject = ThisObject();
	Tree = CurrentObject.GenerateNodeTree(RegistrationObject, RegistrationTable);
	
	If OnlyUpdate Then
		// Updating  fields using the current tree values.
		For Each PlanRow In ExchangeNodesTree.GetItems() Do
			For Each NodeRow In PlanRow.GetItems() Do
				TreeRow = Tree.Rows.Find(NodeRow.Ref, "Ref", True);
				If TreeRow <> Undefined Then
					FillPropertyValues(NodeRow, TreeRow, "Check, InitialMark, MessageNo, NotExported");
				EndIf;
			EndDo;
		EndDo;
	Else
		// Assign a new value to the ExchangeNodeTree form attribute,
		ValueToFormAttribute(Tree, "ExchangeNodesTree");
	EndIf;
	
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			CurrentObject.ChangeMark(NodeRow);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion
