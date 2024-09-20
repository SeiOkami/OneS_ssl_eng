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
	
	Date                        = Parameters.Date;
	UserName             = Parameters.UserName;
	ApplicationPresentation     = Parameters.ApplicationPresentation;
	Computer                   = Parameters.Computer;
	Event                     = Parameters.Event;
	EventPresentation        = Parameters.EventPresentation;
	Comment                 = Parameters.Comment;
	MetadataPresentation     = Parameters.MetadataPresentation;
	Data                      = Parameters.Data;
	DataPresentation         = Parameters.DataPresentation;
	Transaction                  = Parameters.Transaction;
	TransactionStatus            = Parameters.TransactionStatus;
	Session                       = Parameters.Session;
	ServerName               = Parameters.ServerName;
	PrimaryIPPort              = Parameters.PrimaryIPPort;
	SyncPort       = Parameters.SyncPort;
	
	If Parameters.Property("SessionDataSeparation") Then
		SessionDataSeparation = Parameters.SessionDataSeparation;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, %2';"), 
		Parameters.Level, Date);
	
	// Enabling the open button for the metadata list.
	If TypeOf(MetadataPresentation) = Type("ValueList") Then
		Items.MetadataPresentation.OpenButton = True;
		Items.AccessMetadataPresentation.OpenButton = True;
		Items.AccessRightDeniedMetadataPresentation.OpenButton = True;
		Items.AccessActionDeniedMetadataPresentation.OpenButton = True;
	EndIf;
	
	// 
	Items.AccessData.Visible = False;
	Items.AccessRightDeniedData.Visible = False;
	Items.AccessActionDeniedData.Visible = False;
	Items.AuthenticationData.Visible = False;
	Items.IBUserData.Visible = False;
	Items.SimpleData.Visible = False;
	Items.DataPresentations.PagesRepresentation = FormPagesRepresentation.None;
	
	If Not ValueIsFilled(Parameters.DataStorage) Then
		EventsData = New Map;
	Else
		EventsData = GetFromTempStorage(Parameters.DataStorage);
	EndIf;
	
	If Event = "_$Access$_.Access" Then
		Items.DataPresentations.CurrentPage = Items.AccessData;
		Items.AccessData.Visible = True;
		EventData = EventsData[Parameters.DataAddress]; // Structure
		If EventData <> Undefined Then
			CreateFormTable("AccessDataTable", "DataTable", EventData.Data);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	ElsIf Event = "_$Access$_.AccessDenied" Then
		EventData = EventsData[Parameters.DataAddress]; // Structure
		
		If EventData <> Undefined Then
			If EventData.Property("Right") Then
				Items.DataPresentations.CurrentPage = Items.AccessRightDeniedData;
				Items.AccessRightDeniedData.Visible = True;
				AccessRightDenied = EventData.Right;
			Else
				Items.DataPresentations.CurrentPage = Items.AccessActionDeniedData;
				Items.AccessActionDeniedData.Visible = True;
				AccessActionDenied = EventData.Action;
				ТаблицаДанные = Undefined;
				If EventData.Property("Data") Then
					ТаблицаДанные = EventData.Data;
				EndIf;
				CreateFormTable("AccessActionDeniedDataTable", "DataTable", ТаблицаДанные);
				Items.Comment.VerticalStretch = False;
				Items.Comment.Height = 1;
			EndIf;
		EndIf;
		
	ElsIf Event = "_$Session$_.Authentication"
		  Or Event = "_$Session$_.AuthenticationError" Then
		EventData = EventsData[Parameters.DataAddress];
		Items.DataPresentations.CurrentPage = Items.AuthenticationData;
		Items.AuthenticationData.Visible = True;
		If EventData <> Undefined Then
			EventData.Property("Name",                   AuthenticationUsername);
			EventData.Property("OSUser",        AuthenticationOSUser);
			EventData.Property("CurrentOSUser", AuthenticationCurrentOSUser);
		EndIf;
		
	ElsIf Event = "_$User$_.Delete"
		  Or Event = "_$User$_.New"
		  Or Event = "_$User$_.Update" Then
		EventData = EventsData[Parameters.DataAddress];
		Items.DataPresentations.CurrentPage = Items.IBUserData;
		Items.IBUserData.Visible = True;
		IBUserProperies = New ValueTable;
		IBUserProperies.Columns.Add("Name");
		IBUserProperies.Columns.Add("Value");
		RolesArray = Undefined;
		If EventData <> Undefined Then
			For Each KeyAndValue In EventData Do
				If KeyAndValue.Key = "Roles" Then
					RolesArray = KeyAndValue.Value;
					Continue;
				EndIf;
				NewRow = IBUserProperies.Add();
				NewRow.Name      = KeyAndValue.Key;
				NewRow.Value = KeyAndValue.Value;
			EndDo;
		EndIf;
		IBUserProperies.Sort("Name Asc");
		CreateFormTable("IBUserPropertiesTable", "DataTable", IBUserProperies);
		If RolesArray <> Undefined Then
			IBUserRoles1 = New ValueTable;
			IBUserRoles1.Columns.Add("Role",, NStr("en = 'Role';"));
			For Each CurrentRole In RolesArray Do
				IBUserRoles1.Add().Role = CurrentRole;
			EndDo;
			CreateFormTable("IBUserRolesTable", "Roles", IBUserRoles1);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	Else
		Items.DataPresentations.CurrentPage = Items.SimpleData;
		Items.SimpleData.Visible = True;
	EndIf;
	
	Items.SessionDataSeparation.Visible = Not Common.SeparatedDataUsageAvailable();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MetadataPresentationOpening(Item, StandardProcessing)
	
	ShowValue(, MetadataPresentation);
	
EndProcedure

&AtClient
Procedure SessionDataSeparationOpening(Item, StandardProcessing)
	
	ShowValue(, SessionDataSeparation);
	
EndProcedure

#EndRegion

#Region AccessActionDeniedDataTableFormTableItemEventHandlers

&AtClient
Procedure DataTableChoice(Item, RowSelected, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData[Mid(Field.Name, StrLen(Item.Name)+1)]);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CreateFormTable(Val FormTableFieldName, Val AttributeNameFormDataCollection, Val ValueTable)
	
	If TypeOf(ValueTable) <> Type("ValueTable") Then
		ValueTable = New ValueTable;
		ValueTable.Columns.Add("Undefined", , " ");
	EndIf;
	
	// Adding form table attributes.
	AttributesToBeAdded = New Array;
	For Each Column In ValueTable.Columns Do
		AttributesToBeAdded.Add(New FormAttribute(Column.Name, Column.ValueType, AttributeNameFormDataCollection, Column.Title));
	EndDo;
	ChangeAttributes(AttributesToBeAdded);
	
	// Add items to the form.
	For Each Column In ValueTable.Columns Do
		AttributeItem = Items.Add(FormTableFieldName + Column.Name, Type("FormField"), Items[FormTableFieldName]);
		AttributeItem.DataPath = AttributeNameFormDataCollection + "." + Column.Name;
	EndDo;
	
	ValueToFormAttribute(ValueTable, AttributeNameFormDataCollection);
	
EndProcedure

#EndRegion
