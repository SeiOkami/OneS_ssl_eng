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
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FilesFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else
		If Parameters.SelectTemplate1 Then
			
			CommonClientServer.SetDynamicListFilterItem(
				Folders, "Ref", Catalogs.FilesFolders.Templates,
				DataCompositionComparisonType.InHierarchy, , True);
			
			Items.Folders.CurrentRow = Catalogs.FilesFolders.Templates;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		EndIf;
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.Folders.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If MobileClient Then
	SetFoldersTreeTitle();
#EndIf
	
EndProcedure

#EndRegion

#Region FoldersFormTableItemEventHandlers

&AtClient
Procedure FoldersOnActivateRow(Item)
	
	AttachIdleHandler("IdleHandler", 0.2, True);
	
#If MobileClient Then
	AttachIdleHandler("SetFoldersTreeTitle", 0.1, True);
	CurrentItem = Items.List;
#EndIf
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	FileRef = Items.List.CurrentRow;
	
	Parameter = New Structure;
	Parameter.Insert("FileRef", FileRef);
	
	NotifyChoice(Parameter);
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IdleHandler()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFoldersTreeTitle()
	
	Items.Folders.Title = ?(Items.Folders.CurrentData = Undefined, "",
		Items.Folders.CurrentData.Description);
	
EndProcedure

#EndRegion
