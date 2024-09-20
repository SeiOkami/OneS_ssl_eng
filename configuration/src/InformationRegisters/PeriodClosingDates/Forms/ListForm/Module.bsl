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
	SetOrder();
	
	ReadOnly = True;
	
	// Set up the command.
	SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
	Items.FormDataImportRestrictionDates.Visible = SectionsProperties.ImportRestrictionDatesImplemented;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PeriodEndClosingDates(Command)
	
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates");
	
EndProcedure

&AtClient
Procedure DataImportRestrictionDates(Command)
	
	FormParameters = New Structure("DataImportRestrictionDates", True);
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates", FormParameters);
	
EndProcedure

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	For Each UserType In Metadata.InformationRegisters.PeriodClosingDates.Dimensions.User.Type.Types() Do
		MetadataObject = Metadata.FindByType(UserType);
		If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		
		ApplyAppearanceValue(Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef(),
			MetadataObject.Presentation() + ": " + NStr("en = '<All infobases>';"));
	EndDo;
	
	ApplyAppearanceValue(Undefined,
		NStr("en = 'Undefined';"));
	
	ApplyAppearanceValue(Catalogs.Users.EmptyRef(),
		NStr("en = 'Empty user';"));
	
	ApplyAppearanceValue(Catalogs.UserGroups.EmptyRef(),
		NStr("en = 'Empty user group';"));
	
	ApplyAppearanceValue(Catalogs.ExternalUsers.EmptyRef(),
		NStr("en = 'Empty external user';"));
	
	ApplyAppearanceValue(Catalogs.ExternalUsersGroups.EmptyRef(),
		NStr("en = 'Empty external user group';"));
	
	ApplyAppearanceValue(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers,
		"<" + Enums.PeriodClosingDatesPurposeTypes.ForAllUsers + ">");
	
	ApplyAppearanceValue(Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases,
		"<" + Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases + ">");
	
EndProcedure

&AtServer
Procedure ApplyAppearanceValue(Value, Text)
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", Text);
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("User");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Value;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("User");
	
EndProcedure

&AtServer
Procedure SetOrder()
	
	Order = List.SettingsComposer.Settings.Order;
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("User");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("Section");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("Object");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
EndProcedure

#EndRegion
