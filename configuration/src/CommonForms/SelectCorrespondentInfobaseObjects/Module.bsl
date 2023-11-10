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
	
	Parameters.Property("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	
	PickMode = (Parameters.CloseOnChoice = False);
	AttributeName = Parameters.AttributeName;
	
	If Parameters.ExternalConnectionParameters.JoinType = "ExternalConnection" Then
		
		Connection = DataExchangeServer.ExternalConnectionToInfobase(Parameters.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDetails;
		ExternalConnection       = Connection.Join;
		
		If ExternalConnection = Undefined Then
			Common.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		MetadataObjectProperties = ExternalConnection.DataExchangeExternalConnection.MetadataObjectProperties(Parameters.CorrespondentInfobaseTableFullName);
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			Or Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseTable = Common.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Parameters.CorrespondentInfobaseTableFullName));
			
		Else
			
			CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Parameters.CorrespondentInfobaseTableFullName));
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		ElsIf Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			Common.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			Or Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseData = XDTOSerializer.ReadXDTO(WSProxy.GetIBData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = CorrespondentInfobaseData.MetadataObjectProperties;
			CorrespondentInfobaseTable = Common.ValueFromXMLString(CorrespondentInfobaseData.CorrespondentInfobaseTable);
			
		Else
			
			CorrespondentInfobaseData = ValueFromStringInternal(WSProxy.GetIBData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = ValueFromStringInternal(CorrespondentInfobaseData.MetadataObjectProperties);
			CorrespondentInfobaseTable = ValueFromStringInternal(CorrespondentInfobaseData.CorrespondentInfobaseTable);
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "TemporaryStorage" Then
		TempStorageData = GetFromTempStorage(Parameters.ExternalConnectionParameters.TempStorageAddress);
		CorrespondentInfobaseData = TempStorageData.Get().Get(Parameters.CorrespondentInfobaseTableFullName);
		
		MetadataObjectProperties = CorrespondentInfobaseData.MetadataObjectProperties;
		CorrespondentInfobaseTable = Common.ValueFromXMLString(CorrespondentInfobaseData.CorrespondentInfobaseTable);
		
	EndIf;
	
	UpdateItemsIconsIndexes(CorrespondentInfobaseTable);
	
	Title = MetadataObjectProperties.Synonym;
	
	Items.List.Representation = ?(MetadataObjectProperties.Hierarchical = True, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
	TreeItemsCollection = List.GetItems();
	TreeItemsCollection.Clear();
	Common.FillFormDataTreeItemCollection(TreeItemsCollection, CorrespondentInfobaseTable);
	
	// Place the cursor in the value tree.
	If Not IsBlankString(Parameters.ChoiceInitialValue) Then
		
		RowID = 0;
		
		CommonClientServer.GetTreeRowIDByFieldValue("Id", RowID, TreeItemsCollection, Parameters.ChoiceInitialValue, False);
		
		Items.List.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ValueChoiceProcessing1();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChooseValue(Command)
	
	ValueChoiceProcessing1();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ValueChoiceProcessing1()
	CurrentData = Items.List.CurrentData;
	
	If CurrentData=Undefined Then 
		Return
	EndIf;
	
	// 
	//     
	//     
	
	IsFolder = CurrentData.PictureIndex=0 Or CurrentData.PictureIndex=1;
	If (IsFolder And ChoiceFoldersAndItems=FoldersAndItems.Items) 
		Or (Not IsFolder And ChoiceFoldersAndItems=FoldersAndItems.Folders) Then
		Return;
	EndIf;
	
	Data = New Structure("Presentation, Id");
	FillPropertyValues(Data, CurrentData);
	
	Data.Insert("PickMode", PickMode);
	Data.Insert("AttributeName", AttributeName);
	
	NotifyChoice(Data);
EndProcedure

// For backward compatibility purposes.
//
&AtServer
Procedure UpdateItemsIconsIndexes(CorrespondentInfobaseTable)
	
	For IndexOf = -3 To -2 Do
		
		Filter = New Structure;
		Filter.Insert("PictureIndex", - IndexOf);
		
		FoundIndexes = CorrespondentInfobaseTable.Rows.FindRows(Filter, True);
		
		For Each FoundIndex In FoundIndexes Do
			
			FoundIndex.PictureIndex = FoundIndex.PictureIndex + 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion
