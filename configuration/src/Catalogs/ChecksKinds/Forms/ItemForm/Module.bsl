///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateTableRowsCounters();
	
EndProcedure

#EndRegion

#Region AdditionalPropertiesFormTableItemEventHandlers

&AtClient
Procedure ObjectPropertiesOnChange(Item)
	
	UpdateTableRowsCounters();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateTableRowsCounters()
	
	SetPageTitle(Items.AdditionalPropertiesPage, Object.ObjectProperties, NStr("en = 'Additional properties';"));
	
EndProcedure

&AtClient
Procedure SetPageTitle(PageItem, AttributeTabularSection, DefaultTitle)
	
	PageHeader = DefaultTitle;
	If AttributeTabularSection.Count() > 0 Then
		PageHeader = DefaultTitle + " (" + AttributeTabularSection.Count() + ")";
	EndIf;
	PageItem.Title = PageHeader;
	
EndProcedure

#EndRegion