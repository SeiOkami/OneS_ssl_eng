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
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	PersonalAccessGroupsParent = Catalogs.AccessGroups.PersonalAccessGroupsParent(True);
	
	SimplifiedAccessRightsSetupInterface = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
	If SimplifiedAccessRightsSetupInterface Then
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreate", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreate", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCopy", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCopy", "Visible", False);
	EndIf;
	
	List.Parameters.SetParameterValue("Profile", Parameters.Profile);
	If ValueIsFilled(Parameters.Profile) Then
		Items.Profile.Visible = False;
		Items.List.Representation = TableRepresentation.List;
		AutoTitle = False;
		
		Title = NStr("en = 'Access groups';");
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreateFolder", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreateFolder", "Visible", False);
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.AccessGroupProfiles) Then
		Items.Profile.Visible = False;
	EndIf;
	
	If Not Users.IsFullUser() Then
		// 
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref", AccessManagement.AdministratorsAccessGroup(),
			DataCompositionComparisonType.NotEqual, , True);
	EndIf;
	
	ChoiceMode = Parameters.ChoiceMode;
	
	If Parameters.ChoiceMode Then
		
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// 
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("en = 'Pick access groups';");
		Else
			Title = NStr("en = 'Select access group';");
		EndIf;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Not StandardSubsystemsClient.IsDynamicListItem(Items.List) Then
		Return;
	EndIf;
	
	CurrentData = CurrentTableData(Items.List);
	TransferAvailable = Not ValueIsFilled(CurrentData.User)
	                  And CurrentData.Ref <> PersonalAccessGroupsParent;
	
	CommonClientServer.SetFormItemProperty(Items,
		"FormMoveItem", "Enabled", TransferAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"ListContextMenuMoveItem", "Enabled", TransferAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"ListMoveItem", "Enabled", TransferAvailable);
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If Value = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'The group can contain only personal access groups.';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Parent = PersonalAccessGroupsParent Then
		
		Cancel = True;
		
		If Var_Group Then
			ShowMessageBox(, NStr("en = 'The group cannot contain subgroups.';"));
			
		ElsIf SimplifiedAccessRightsSetupInterface Then
			ShowMessageBox(,
				NStr("en = 'Personal access groups
				           |can be created only in the ""Access rights"" form.';"));
		Else
			ShowMessageBox(, NStr("en = 'Personal access groups are disabled.';"));
		EndIf;
		
	ElsIf Not Var_Group
	        And SimplifiedAccessRightsSetupInterface Then
		
		Cancel = True;
		
		ShowMessageBox(,
			NStr("en = 'Personal access groups can be created
			           |only in the ""Access rights"" form.';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	
	If CurrentData = Undefined
	 Or CurrentData.IsFolder Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure("Key", CurrentData.Ref);
	OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtServerNoContext
Procedure ListOnGetDataAtServer(TagName, Settings, Rows)
	
	For Each String In Rows Do
		If TypeOf(String.Key) <> Type("CatalogRef.AccessGroups") Then
			Continue;
		EndIf;
		Data = String.Value.Data;
		
		If Data.IsFolder
		 Or Not ValueIsFilled(Data.User) Then
			Continue;
		EndIf;
		
		Data.Description =
			AccessManagementInternalClientServer.PresentationAccessGroups(Data);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If String = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'This folder is for personal access groups only.';"));
		
	ElsIf DragParameters.Value = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Cannot move a personal access groups folder.';"));
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	AccessManagementInternal.StartAccessUpdate();
	
EndProcedure

// Parameters:
//  FormTable - FormDataCollection
// 
// Returns:
//  FormDataStructure:
//   * Ref - CatalogRef.AccessGroups
//   * User - CatalogRef.Users
//                  - CatalogRef.ExternalUsers
//
&AtClient
Function CurrentTableData(FormTable)
	Return FormTable.CurrentData;
EndFunction

#EndRegion
