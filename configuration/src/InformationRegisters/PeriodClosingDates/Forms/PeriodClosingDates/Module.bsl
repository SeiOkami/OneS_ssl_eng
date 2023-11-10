///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var UsersContinueAdding, SelectedUser, SelectedClosingDateIndicationMethod;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
	
	// 
	// 
	HasRightToViewPeriodEndClosingDates =
		Users.RolesAvailable("ReadPeriodEndClosingDates, AddEditPeriodClosingDates",, False);
	
	HasRightToEditPeriodEndClosingDates = HasRightToViewPeriodEndClosingDates
		And Users.RolesAvailable("AddEditPeriodClosingDates",, False);
	
	HasRightToViewDataImportRestrictionDates =
		  SectionsProperties.ImportRestrictionDatesImplemented
		And Users.RolesAvailable("ReadDataImportRestrictionDates, AddEditDataImportRestrictionDates",, False);
	
	HasRightToEditDataImportRestrictionDates = HasRightToViewDataImportRestrictionDates
		And Users.RolesAvailable("AddEditDataImportRestrictionDates",, False);
	// 
	If Parameters.DataImportRestrictionDates Then
		If Not SectionsProperties.ImportRestrictionDatesImplemented Then
			Raise PeriodClosingDatesInternal.ErrorTextImportRestrictionDatesNotImplemented();
		EndIf;
		If Not HasRightToViewDataImportRestrictionDates Then
			Raise NStr("en = 'Insufficient rights to view data import restriction dates of previous periods from other applications.';");
		EndIf;
	ElsIf Not HasRightToViewPeriodEndClosingDates Then
		Raise NStr("en = 'Insufficient rights to view period-end closing dates of previous periods.';");
	EndIf;
	
	If Not Parameters.DataImportRestrictionDates
	   And Not HasRightToEditPeriodEndClosingDates
	 Or Parameters.DataImportRestrictionDates
	   And Not HasRightToEditDataImportRestrictionDates Then
		
		Items.SetPeriodEndClosingDates.Enabled = False;
		Items.Users.ReadOnly = True;
		Items.UsersPick.Enabled = False;
		Items.ClosingDates.ReadOnly = True;
		Items.ClosingDatesPeriodEndClosingDateDetailsPresentation.CellHyperlink = False;
		Items.DateSettingMethodSingleDate.ReadOnly = True;
		Items.AdvancedOptionsGroup.ReadOnly = True;
	EndIf;
	
	// Caching the current date on the server.
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	// Populate section properties.
	FillPropertyValues(ThisObject, SectionsProperties);
	Table = New ValueTable;
	Table.Columns.Add("Ref", New TypeDescription("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	Table.Columns.Add("Presentation", New TypeDescription("String",,,, New StringQualifiers(150)));
	Table.Columns.Add("IsCommonDate",  New TypeDescription("Boolean"));
	For Each Section In Sections Do
		If TypeOf(Section.Key) = Type("String") Then
			Continue;
		EndIf;
		NewRow = Table.Add();
		SectionProperties = Section.Value; // Structure
		FillPropertyValues(NewRow, SectionProperties);
		If Not ValueIsFilled(SectionProperties.Ref) Then
			NewRow.Presentation = CommonDatePresentationText();
			NewRow.IsCommonDate  = True;
		EndIf;
	EndDo;
	SectionsTableAddress = PutToTempStorage(Table, UUID);
	
	// Prepare the table for setting or removing form locks.
	Dimensions = Metadata.InformationRegisters.PeriodClosingDates.Dimensions;
	Table = New ValueTable;
	Table.Columns.Add("Section",       Dimensions.Section.Type);
	Table.Columns.Add("Object",       Dimensions.Object.Type);
	Table.Columns.Add("User", Dimensions.User.Type);
	Locks = New Structure;
	Locks.Insert("FormIdentifier",   UUID);
	Locks.Insert("Content",               Table);
	Locks.Insert("BegOfDay",            BegOfDay);
	Locks.Insert("NoSectionsAndObjects", NoSectionsAndObjects);
	Locks.Insert("SectionEmptyRef",   SectionEmptyRef);
	
	LocksAddress = PutToTempStorage(Locks, UUID);
	
	// Form field setup.
	If Parameters.DataImportRestrictionDates Then
		Items.ClosingDatesUsageDisabledLabel.Title =
			NStr("en = 'Data import restriction dates of previous periods from other applications are disabled in the settings.';");
		
		Title = NStr("en = 'Data import restriction dates';");
		Items.SetPeriodEndClosingDates.ChoiceList.FindByValue("ForAllUsers").Presentation =
			NStr("en = 'For all infobases';");
		Items.SetPeriodEndClosingDates.ChoiceList.FindByValue("ForSpecifiedUsers").Presentation =
			NStr("en = 'By infobases';");
		
		Items.UsersFullPresentation.Title =
			NStr("en = 'Application: infobase';");
		
		Items.UsersComment.ToolTip =
			NStr("en = 'Describes a reason for a particular restriction for an infobase or an application';");
		
		ValueForAllUsers = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
		
		UserTypes =
			Metadata.InformationRegisters.PeriodClosingDates.Dimensions.User.Type.Types();
		
		For Each UserType In UserTypes Do
			MetadataObject = Metadata.FindByType(UserType);
			If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
				Continue;
			EndIf;
			EmptyRefOfExchangePlanNode = Common.ObjectManagerByFullName(
				MetadataObject.FullName()).EmptyRef();
			
			UserTypesList.Add(
				EmptyRefOfExchangePlanNode, MetadataObject.Presentation());
		EndDo;
		Items.Users.RowsPicture = PictureLib.IconsExchangePlanNode;
		URL = "e1cib/command/InformationRegister.PeriodClosingDates.Command.DataImportRestrictionDates";
		
		If GetFunctionalOption("UsePeriodClosingDates") Then
			If HasRightToEditPeriodEndClosingDates Then
				GoToOtherClosingDates = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'You can also set up <a href=""%1"">period-end closing dates</a> of previous periods.';"),
					"e1cib/command/InformationRegister.PeriodClosingDates.Command.PeriodEndClosingDates");
					
			ElsIf HasRightToViewPeriodEndClosingDates Then
				GoToOtherClosingDates = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'You can also view <a href=""%1"">period-end closing dates</a> of previous periods.';"),
					"e1cib/command/InformationRegister.PeriodClosingDates.Command.PeriodEndClosingDates");
			EndIf;
		EndIf;
	Else
		Items.ClosingDatesUsageDisabledLabel.Title =
			NStr("en = 'Dates of restriction of entering and editing previous period data are disabled in the application settings.';");
		Items.UsersFullPresentation.Title = 
			?(GetFunctionalOption("UseUserGroups"),
			NStr("en = 'User, user group';"), NStr("en = 'User';"));
		Items.UsersComment.ToolTip =
			NStr("en = '1. Determines a user group order when calculating period-end closing dates
			           |2. Describes a reason for a particular restriction for a user or a user group';");
		ValueForAllUsers = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
		UserTypesList.Add(
			Type("CatalogRef.Users"),        NStr("en = 'User';"));
		UserTypesList.Add(
			Type("CatalogRef.ExternalUsers"), NStr("en = 'External user';"));
		
		URL = "e1cib/command/InformationRegister.PeriodClosingDates.Command.PeriodEndClosingDates";
		
		If GetFunctionalOption("UseImportForbidDates") Then
			If HasRightToEditDataImportRestrictionDates Then
				GoToOtherClosingDates = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'You can also set up <a href=""%1"">data import restriction dates</a> from other applications.';"),
					"e1cib/command/InformationRegister.PeriodClosingDates.Command.DataImportRestrictionDates");
					
			ElsIf HasRightToViewDataImportRestrictionDates Then
				GoToOtherClosingDates = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'You can also view <a href=""%1"">data import restriction dates</a> from other applications.';"),
					"e1cib/command/InformationRegister.PeriodClosingDates.Command.DataImportRestrictionDates");
			EndIf;
		EndIf;
	EndIf;
	
	List = Items.PeriodEndClosingDateSettingMethod.ChoiceList;
	
	If NoSectionsAndObjects Then
		Items.PeriodEndClosingDateSettingMethod.Visible =
			ValueIsFilled(CurrentClosingDateIndicationMethod(
				"*", SingleSection, ValueForAllUsers, BegOfDay));
		
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
		List.Delete(List.FindByValue("ByObjects"));
		
	ElsIf Not ShowSections Then
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
	ElsIf AllSectionsWithoutObjects Then
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("ByObjects"));
	Else
		List.Delete(List.FindByValue("ByObjects"));
	EndIf;
	
	UseExternalUsers = ExternalUsers.UseExternalUsers();
	ExternalUsersCatalogAvailable = AccessRight("View", Metadata.Catalogs.ExternalUsers);
	
	UpdateAtServer();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("InformationRegister.PeriodClosingDates.Form.PeriodEndClosingDateEdit") Then
		
		If ValueSelected <> Undefined Then
			SelectedRows = Items.ClosingDates.SelectedRows;
			
			For Each SelectedRow In SelectedRows Do
				String = ClosingDates.FindByID(SelectedRow);
				String.PeriodEndClosingDateDetails              = ValueSelected.PeriodEndClosingDateDetails;
				String.PermissionDaysCount         = ValueSelected.PermissionDaysCount;
				String.PeriodEndClosingDate                      = ValueSelected.PeriodEndClosingDate;
				WriteDetailsAndPeriodEndClosingDate(String);
			EndDo;
			SetFieldsToCalculate(ClosingDates.GetItems());
			UpdateClosingDatesAvailabilityOfCurrentUser();
		EndIf;
		
		// Cancel lock of selected rows.
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) <> Upper("Write_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("UseImportForbidDates")
	 Or Upper(Source) = Upper("UsePeriodClosingDates") Then
		
		AttachIdleHandler("OnChangeOfRestrictionDatesUsage", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	QueryText = NotificationTextOfUnusedSettingModes();
	If Not ValueIsFilled(QueryText) Then
		Return;
	EndIf;
	
	QueryText = NStr("en = 'The period-end closing date settings will be adjusted automatically.';") 
		+ Chars.LF + Chars.LF + QueryText + Chars.LF + Chars.LF + NStr("en = 'Close?';");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, QueryText, "CloseFormWithoutConfirmation");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnChangeOfRestrictionDatesUsage()
	
	OnChangeOfRestrictionDatesUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeOfRestrictionDatesUsageAtServer()
	
	Items.ClosingDatesUsage.CurrentPage = ?(Parameters.DataImportRestrictionDates
		And Not Constants.UseImportForbidDates.Get()
		Or Not Parameters.DataImportRestrictionDates
		And Not Constants.UsePeriodClosingDates.Get(), 
		Items.Disabled, Items.isEnabled);
	
EndProcedure

&AtClient
Procedure SetPeriodEndClosingDate1OnChange(Item)
	
	ValueSelected = SetPeriodEndClosingDateNew;
	If SetPeriodEndClosingDates = ValueSelected Then
		Return;
	EndIf;
	
	CurrentSettingOfPeriodEndClosingDate = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	If CurrentSettingOfPeriodEndClosingDate = "ForSpecifiedUsers" And ValueSelected = "ForAllUsers" Then
		
		If HasInvalidObjectsByUsers Then
			SetPeriodEndClosingDateNew = CurrentSettingOfPeriodEndClosingDate;
			ShowMessageBox(, NStr("en = 'You are not authorized to edit period-end closing dates.';"));
			Return;
		EndIf;
			
		QueryText = NStr("en = 'Do you want to turn off all period-end closing dates except the dates applied for all users?
		|
		|Warning: disabled settings will be permanently deleted.';");
		ShowQueryBox(
			New NotifyDescription(
				"SetPeriodEndClosingDateChoiceProcessingContinue", ThisObject, ValueSelected),
			QueryText,
			QuestionDialogMode.YesNo);
		Return;	
	EndIf;
	
	SetPeriodEndClosingDates = ValueSelected;
	ChangeSettingOfPeriodEndClosingDate(ValueSelected, False);
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateSettingMethodClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateSettingMethodChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If PeriodEndClosingDateSettingMethod = ValueSelected Then
		Return;
	EndIf;
	
	SelectedClosingDateIndicationMethod = ValueSelected;
	
	AttachIdleHandler("IndicationMethodOfClosingDateChoiceProcessingIdleHandler", 0.1, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure PeriodEndClosingDateDetailsOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateDetailsClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	PeriodEndClosingDateDetails = Items.PeriodEndClosingDateDetails.ChoiceList[0].Value;
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure EnableDataChangeBeforePeriodEndClosingDateOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	PermissionDaysCount = Number(Text);
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure MoreOptionsClick(Item)
	
	ExtendedModeSelected = True;
	Items.ExtendedMode.Visible = True;
	Items.OperationModesGroup.CurrentPage = Items.ExtendedMode;
	
EndProcedure

&AtClient
Procedure LessOptionsClick(Item)
	
	ExtendedModeSelected = False;
	Items.ExtendedMode.Visible = False;
	Items.OperationModesGroup.CurrentPage = Items.SimpleMode;
	
EndProcedure

#EndRegion

#Region UsersFormTableItemEventHandlers

&AtClient
Procedure UsersSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AttachIdleHandler("UsersChangeRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersOnActivateRow(Item)
	
	AttachIdleHandler("UpdateUserDataIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersRestoreCurrentRowAfterCancelOnActivateRow()
	
	Items.Users.CurrentRow = UsersCurrentRow;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	// Do not copy as users cannot be repeated.
	If Copy Then
		Cancel = True;
		Return;
	EndIf;
	
	If UsersContinueAdding <> True Then
		Cancel = True;
		UsersContinueAdding = True;
		Items.Users.AddRow();
		Return;
	EndIf;
	
	UsersContinueAdding = Undefined;
	
	ClosingDates.GetItems().Clear();
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	Field          = Item.CurrentItem;
	
	If Field <> Items.UsersFullPresentation And Not ValueIsFilled(CurrentData.Presentation) Then
		// 
		// 
		Item.CurrentItem = Items.UsersFullPresentation;
	EndIf;
	
	Items.UsersComment.ReadOnly =
		Not ValueIsFilled(CurrentData.Presentation);
	
	If ValueIsFilled(CurrentData.Presentation) Then
		DataDetails = New Structure("PeriodEndClosingDate, PeriodEndClosingDateDetails, Comment");
		FillPropertyValues(DataDetails, CurrentData);
		
		LockUserRecordSetAtServer(CurrentData.User,
			LocksAddress, DataDetails);
		
		FillPropertyValues(CurrentData, DataDetails);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.Users.CurrentData;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData", CurrentData);
	
	// 
	AdditionalParameters.Insert("ClosingDatesForAllUsers",
		CurrentData.User = ValueForAllUsers);
	
	If ValueIsFilled(CurrentData.Presentation) And Not CurrentData.NoPeriodEndClosingDate Then
		// Confirm to delete users with records.
		If AdditionalParameters.ClosingDatesForAllUsers Then
			QueryText = NStr("en = 'Do you want to turn off period-end closing dates for all users?';");
		Else
			If TypeOf(CurrentData.User) = Type("CatalogRef.Users") Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off period-end closing dates for ""%1""?';"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.UserGroups") Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off period-end closing dates for ""%1"" user group?';"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsers") Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off period-end closing dates for external user ""%1""?';"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsersGroups") Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off period-end closing dates for external user group ""%1""?';"), CurrentData.User);
			Else
				QueryText = NStr("en = 'Do you want to turn off period-end closing dates?';");
			EndIf;
		EndIf;
		
		QueryText = QueryText + Chars.LF + Chars.LF 
			+ NStr("en = 'Warning: disabled settings will be permanently deleted.';");
		
		ShowQueryBox(
			New NotifyDescription(
				"UsersBeforeDeleteConfirmation", ThisObject, AdditionalParameters),
			QueryText, QuestionDialogMode.YesNo);
		
	Else
		UsersBeforeDeleteContinue(Undefined, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Copy)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.Presentation) Then
		CurrentData.PictureNumber = -1;
		AttachIdleHandler("UsersOnStartEditIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	SelectedUser = Undefined;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Items.UsersFullPresentation.ReadOnly = False;
	Items.UsersComment.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	UsersChoiceProcessingAtServer(ValueSelected);
	
EndProcedure

&AtServer
Procedure UsersChoiceProcessingAtServer(ValueSelected)
	
	Filter = New Structure("User");
	
	For Each Value In ValueSelected Do
		Filter.User = Value;
		If ClosingDatesUsers.FindRows(Filter).Count() = 0 Then
			
			UserDetails = ClosingDatesUsers.Add();
			UserDetails.User  = Filter.User;
			UserDetails.NoPeriodEndClosingDate = True;
			
			UserDetails.Presentation = UserPresentationText(
				ThisObject, Filter.User);
			
			UserDetails.FullPresentation = UserDetails.Presentation;
		EndIf;
	EndDo;
	
	FillPicturesNumbersOfClosingDatesUsers(ThisObject);
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UsersFullPresentationOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.FullPresentation) Then
		CurrentData.FullPresentation = CurrentData.Presentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueForAllUsers Then
		Return;
	EndIf;
	
	// Users can be replaced with themselves or with users not selected in the list.
	SelectPickUsers();
	
EndProcedure

&AtClient
Procedure UsersFullPresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		ShowValue(, Items.Users.CurrentData.User);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueSelected Then
		CurrentData.FullPresentation = CurrentData.Presentation;
		Return;
	EndIf;
	
	SelectedUser = ValueSelected;
	AttachIdleHandler("UsersFullPresentationChoiceProcessingIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersFullPresentationAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UsersCommentOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	WriteComment(CurrentData.User, CurrentData.Comment);
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
	If Not CurrentData.NoPeriodEndClosingDate
	   And (    TypeOf(CurrentData.User) = Type("CatalogRef.UserGroups")
	      Or TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsersGroups")) Then
		
		UpdateAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region ClosingDatesFormTableItemEventHandlers

&AtClient
Procedure ClosingDatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("ClosingDatesChangeRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure ClosingDatesOnActivateRow(Item)
	
	ClosingDatesSetCommandsAvailability(Items.ClosingDates.CurrentData <> Undefined);
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Not Items.ClosingDatesAdd.Enabled Then
		Cancel = True;
		Return;
	EndIf;
	
	If Copy
	 Or AllSectionsWithoutObjects
	 Or PeriodEndClosingDateSettingMethod = "BySections" Then
		
		Cancel = True;
		Return;
	EndIf;
	
	If CurrentUser = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentSection = CurrentSection(, True);
	If CurrentSection = SectionEmptyRef Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Cancel = True;
		Return;
	EndIf;
	
	SectionObjectsTypes = Sections.Get(CurrentSection).ObjectsTypes;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If SectionObjectsTypes <> Undefined
	   And SectionObjectsTypes.Count() > 0 Then
		
		If ShowCurrentUserSections Then
			Parent = CurrentData.GetParent();
			
			If Not CurrentData.IsSection
			      And Parent <> Undefined Then
				// 
				Cancel = True;
				Item.CurrentRow = Parent.GetID();
				Item.AddRow();
			EndIf;
		ElsIf Item.CurrentRow <> Undefined Then
			Cancel = True;
			Item.CurrentRow = Undefined;
			Item.AddRow();
		EndIf;
	Else
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeRowChange(Item, Cancel)
	
	If Not Items.ClosingDatesChange.Enabled Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentData = Item.CurrentData;
	Field = Items.ClosingDates.CurrentItem;
	
	// Going to an available field or opening a form.
	OpenPeriodEndClosingDateEditForm = False;
	
	If Field = Items.ClosingDatesFullPresentation Then
		If CurrentData.IsSection Then
			If IsAllUsers(CurrentUser) Then
				// All sections are always filled in, do not change them.
				If CurrentData.PeriodEndClosingDateDetails <> "Custom"
				 Or Field = Items.ClosingDatesPeriodEndClosingDateDetailsPresentation Then
					OpenPeriodEndClosingDateEditForm = True;
				Else
					CurrentItem = Items.ClosingDatesPeriodEndClosingDate;
				EndIf;
			EndIf;
			
		ElsIf ValueIsFilled(CurrentData.Presentation) Then
			If CurrentData.PeriodEndClosingDateDetails <> "Custom"
			 Or Field = Items.ClosingDatesPeriodEndClosingDateDetailsPresentation Then
				OpenPeriodEndClosingDateEditForm = True;
			Else
				CurrentItem = Items.ClosingDatesPeriodEndClosingDate;
			EndIf;
		EndIf;
	Else
		If Not ValueIsFilled(CurrentData.Presentation) Then
			// 
			// 
			CurrentItem = Items.ClosingDatesFullPresentation;
			
		ElsIf CurrentData.PeriodEndClosingDateDetails <> "Custom"
			  Or Field = Items.ClosingDatesPeriodEndClosingDateDetailsPresentation Then
			OpenPeriodEndClosingDateEditForm = True;
			
		ElsIf CurrentItem = Items.ClosingDatesPeriodEndClosingDate Then
			CurrentItem = Items.ClosingDatesPeriodEndClosingDate;
		EndIf;
	EndIf;
	
	// Locking the record before editing.
	If ValueIsFilled(CurrentData.Presentation) Then
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			CurrentSection(), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndIf;
	
	If OpenPeriodEndClosingDateEditForm Then
		Cancel = True;
		EditPeriodEndClosingDateInForm();
	EndIf;
	
	If Cancel Then
		Items.ClosingDatesFullPresentation.ReadOnly = False;
		Items.ClosingDatesPeriodEndClosingDateDetailsPresentation.ReadOnly = False;
		Items.ClosingDatesPeriodEndClosingDate.ReadOnly = False;
	Else
		// 
		Items.ClosingDatesFullPresentation.ReadOnly =
			ValueIsFilled(CurrentData.Presentation);
		
		Items.ClosingDatesPeriodEndClosingDateDetailsPresentation.ReadOnly = True;
		Items.ClosingDatesPeriodEndClosingDate.ReadOnly =
			    Not ValueIsFilled(CurrentData.Presentation)
			Or CurrentData.PeriodEndClosingDateDetails <> "Custom";
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	CurrentData = Items.ClosingDates.CurrentData;
	SeveralSectionsSelected = Items.ClosingDates.SelectedRows.Count() > 1;
	
	If SeveralSectionsSelected Then
		QueryText = NStr("en = 'Do you want to turn off period-end closing dates for the selected sections?';");
	ElsIf CurrentData.IsSection Then
		If ValueIsFilled(CurrentData.Section) Then
			If CurrentData.GetItems().Count() > 0 Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off all period-end closing dates for section ""%1"" and its objects?';"), CurrentData.Section);
			Else
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Do you want to turn off the period-end closing date for section ""%1""?';"), CurrentData.Section);
			EndIf;
		Else
			QueryText = NStr("en = 'Do you want to turn off the common-date restriction setting for all sections?';");
		EndIf;
	Else
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Do you want to turn off the period-end closing date for object ""%1""?';"), CurrentData.Object);
	EndIf;
	
	QueryText = QueryText + Chars.LF + Chars.LF 
		+ NStr("en = 'Warning: disabled settings will be permanently deleted.';");
	
	If SeveralSectionsSelected Then
		ShowQueryBox(New NotifyDescription("ClosingDatesBeforeDeleteRowCompletion", 
			ThisObject, Items.ClosingDates.SelectedRows),
			QueryText, QuestionDialogMode.YesNo);
		Return;
	EndIf;	
		
	If CurrentData.IsSection Then
		SectionItems = CurrentData.GetItems();
		
		If PeriodEndClosingDateSet(CurrentData, CurrentUser) Or SectionItems.Count() > 0 Then
			// Deleting a period-end closing date for the section (i.e. all section objects).
			ShowQueryBox(New NotifyDescription("ClosingDatesBeforeDeleteSection", ThisObject, CurrentData),
				QueryText, QuestionDialogMode.YesNo);
		Else
			MessageText = NStr("en = 'To disable a period-end closing date for an object, select the object in one of the sections.';");
			ShowMessageBox(, MessageText);
		EndIf;
		Return;
	EndIf;
		
	If PeriodEndClosingDateSet(CurrentData, CurrentUser) Then
		// Deleting a period-end closing date for the object by section.
		ShowQueryBox(New NotifyDescription("ClosingDatesBeforeDeleteRowCompletion", ThisObject, 
			Items.ClosingDates.SelectedRows),	QueryText, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	ClosingDatesOnDelete(CurrentData);
	
EndProcedure

&AtClient
Procedure ClosingDatesOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Then
		Return;
	EndIf;
	
	If Not Items.ClosingDates.CurrentData.IsSection Then
		Items.ClosingDates.CurrentData.Section = CurrentSection(, True);
	EndIf;
	If IsAllUsers(CurrentUser) Or Not Items.ClosingDates.CurrentData.IsSection Then
		Items.ClosingDates.CurrentData.PeriodEndClosingDateDetails = "Custom";
	EndIf;
	SetClosingDateDetailsPresentation(Items.ClosingDates.CurrentData);
	AttachIdleHandler("IdleHandlerSelectObjects", 0.1, True);
	
EndProcedure

&AtClient
Procedure ClosingDatesOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentUser <> Undefined Then
		WriteDetailsAndPeriodEndClosingDate(CurrentData);
	EndIf;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Items.ClosingDatesFullPresentation.ReadOnly = False;
	Items.ClosingDatesPeriodEndClosingDateDetailsPresentation.ReadOnly = False;
	SetClosingDateDetailsPresentation(CurrentData);
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtClient
Procedure ClosingDatesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ClosingDates.CurrentData;
	If CurrentData <> Undefined And CurrentData.Object = ValueSelected Then
		Return;
	EndIf;
	
	SectionID = Undefined;
	
	If ShowCurrentUserSections Then
		Parent = CurrentData.GetParent();
		If Parent = Undefined Then
			ObjectCollection1    = CurrentData.GetItems();
			SectionID = CurrentData.GetID();
		Else
			ObjectCollection1    = Parent.GetItems();
			SectionID = Parent.GetID();
		EndIf;
	Else
		ObjectCollection1 = ClosingDates.GetItems();
	EndIf;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		Objects = ValueSelected;
	Else
		Objects = New Array;
		Objects.Add(ValueSelected);
	EndIf;
	
	ObjectsForAdding = New Array;
	For Each Object In Objects Do
		ValueNotFound = True;
		For Each String In ObjectCollection1 Do
			If String.Object = Object Then
				ValueNotFound = False;
				Break;
			EndIf;
		EndDo;
		If ValueNotFound Then
			ObjectsForAdding.Add(Object);
		EndIf;
	EndDo;
	
	If ObjectsForAdding.Count() > 0 Then
		WriteDates = CurrentUser <> Undefined;
		
		If WriteDates Then
			Comment = CurrentUserComment(ThisObject);
			
			LockAndWriteBlankDates(LocksAddress,
				CurrentSection(, True), ObjectsForAdding, CurrentUser, Comment);
			
			NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		EndIf;
		
		For Each CurrentObject In ObjectsForAdding Do
			ObjectDetails = ObjectCollection1.Add();
			ObjectDetails.Section        = CurrentSection(, True);
			ObjectDetails.Object        = CurrentObject;
			ObjectDetails.Presentation = String(CurrentObject);
			ObjectDetails.FullPresentation = ObjectDetails.Presentation;
			ObjectDetails.PeriodEndClosingDateDetails = "Custom";
			ObjectDetails.PeriodEndClosingDate = '39991231';
			ObjectDetails.RecordExists = WriteDates;
		EndDo;
		SetFieldsToCalculate(ObjectCollection1);
		
		If SectionID <> Undefined Then
			Items.ClosingDates.Expand(SectionID, True);
		EndIf;
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ClosingDatesFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ClosingDatesFullPresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ClosingDatesFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentData.Object = ValueSelected Then
		Return;
	EndIf;
	
	// Object can be replaced only with another object, which is not in the list.
	If ShowCurrentUserSections Then
		ObjectCollection1 = CurrentData.GetParent().GetItems();
	Else
		ObjectCollection1 = ClosingDates.GetItems();
	EndIf;
	
	ValueFound2 = True;
	For Each String In ObjectCollection1 Do
		If String.Object = ValueSelected Then
			ValueFound2 = False;
			Break;
		EndIf;
	EndDo;
	
	If Not ValueFound2 Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" is already in the object list';"), ValueSelected));
		Return;
	EndIf;
	
	If CurrentData.Object <> ValueSelected Then
		
		PropertiesValues = GetCurrentPropertiesValues(
			CurrentData, Items.Users.CurrentData);
		
		If Not ReplaceObjectInUserRecordAtServer(
					CurrentData.Section,
					CurrentData.Object,
					ValueSelected,
					CurrentUser,
					PropertiesValues,
					LocksAddress) Then
			
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" is already in the object list.
					|Refresh the form (F5).';"), ValueSelected));
			Return;
		Else
			UpdateReadPropertiesValues(
				CurrentData, PropertiesValues, Items.Users.CurrentData);
			
			NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		EndIf;
	EndIf;
	
	// 
	CurrentData.Object = ValueSelected;
	CurrentData.Presentation = String(CurrentData.Object);
	CurrentData.FullPresentation = CurrentData.Presentation;
	Items.ClosingDates.EndEditRow(False);
	Items.ClosingDates.CurrentItem = Items.ClosingDatesPeriodEndClosingDate;
	AttachIdleHandler("ClosingDatesChangeRow", 0.1, True);
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ClosingDatesPeriodEndClosingDateOnChange(Item)
	
	WriteDetailsAndPeriodEndClosingDate();
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateAtServer();
	AttachIdleHandler("ExpandUserData", 0.1, True);
	
EndProcedure

&AtClient
Procedure PickObjects(Command)
	
	If CurrentUser = Undefined Then
		Return;
	EndIf;
	
	SelectPickObjects(True);
	
EndProcedure

&AtClient
Procedure PickUsers(Command)
	
	SelectPickUsers(True);
	
EndProcedure

&AtClient
Procedure ShowReport(Command)
	
	If Parameters.DataImportRestrictionDates Then
		ReportFormName = "Report.ImportRestrictionDates.Form";
	Else
		ReportFormName = "Report.PeriodClosingDates.Form";
	EndIf;
	
	OpenForm(ReportFormName);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Mark the required user.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersFullPresentation.Name);
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.FullPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FilterGroup2 = FilterGroup1.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup2.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.User");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotInList;
	ValueList = New ValueList;
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers);
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases);
	ItemFilter.RightValue = ValueList;
	
	ItemFilter = FilterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.NoPeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesFullPresentation.Name);
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.FullPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesPeriodEndClosingDate.Name);
	
	Item.Appearance.SetParameterValue("Text", "");
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.PeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.RecordExists");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesPeriodEndClosingDate.Name);
	
	Item.Appearance.SetParameterValue("Text", "0001.01.01");
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.PeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.RecordExists");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesPeriodEndClosingDateDetailsPresentation.Name);
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.PeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.RecordExists");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	// 
	Item = ConditionalAppearance.Items.Add();
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Default settings. Effective when there are no overriding settings.';"));
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersComment.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.User");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	ValueList = New ValueList;
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers);
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases);
	ItemFilter.RightValue = ValueList;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.Comment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
EndProcedure

&AtClient
Procedure ClosingDatesChangeRow()
	
	If Not Items.ClosingDates.ReadOnly Then
		Items.ClosingDates.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersChangeRow()
	
	If Not Items.Users.ReadOnly Then
		Items.Users.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPeriodEndClosingDateChoiceProcessingContinue(Response, ValueSelected) Export
	
	If Response = DialogReturnCode.No Then
		SetPeriodEndClosingDateNew = SetPeriodEndClosingDates; 
		Return;
	EndIf;
	
	SetPeriodEndClosingDates = ValueSelected;
	ChangeSettingOfPeriodEndClosingDate(ValueSelected, True);
	
EndProcedure

&AtClient
Procedure IndicationMethodOfClosingDateChoiceProcessingIdleHandler()
	
	ValueSelected = SelectedClosingDateIndicationMethod;
	
	Data = Undefined;
	CurrentMethod = CurrentClosingDateIndicationMethod(CurrentUser,
		SingleSection, ValueForAllUsers, BegOfDay, Data);
	
	QueryText = "";
	If CurrentMethod = "BySectionsAndObjects" And ValueSelected = "SingleDate" Then
		QueryText = NStr("en = 'Do you want to turn off period-end closing dates for sections and objects?';");
		
	ElsIf CurrentMethod = "BySectionsAndObjects" And ValueSelected = "BySections"
	      Or CurrentMethod = "ByObjects"          And ValueSelected = "SingleDate" Then
		QueryText = NStr("en = 'Do you want to turn period-end closing dates for objects?';");
		
	ElsIf CurrentMethod = "BySectionsAndObjects" And ValueSelected = "ByObjects"
	      Or CurrentMethod = "BySections"          And ValueSelected = "ByObjects"
	      Or CurrentMethod = "BySections"          And ValueSelected = "SingleDate" Then
		QueryText = NStr("en = 'Do you want to turn off period-end closing dates for sections?';");
		
	EndIf;
	
	If ValueIsFilled(QueryText) Then
		
		If HasUnavailableObjects Then
			ShowMessageBox(, NStr("en = 'You are not authorized to change period-end closing dates.';"));
			Return;
		EndIf;
			
		QueryText = QueryText + Chars.LF + Chars.LF 
			+ NStr("en = 'Warning: disabled settings will be permanently deleted.';");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Data", Data);
		AdditionalParameters.Insert("ValueSelected", ValueSelected);
		
		ShowQueryBox(
			New NotifyDescription(
				"IndicationMethodOfPeriodEndClosingDateChoiceProcessingContinue",
				ThisObject,
				AdditionalParameters),
			QueryText,
			QuestionDialogMode.YesNo);
		Return;	
	EndIf;
	
	PeriodEndClosingDateSettingMethod = ValueSelected;
	ErrorText = "";
	ReadUserData(ThisObject, ErrorText, ValueSelected, Data);
	If ValueIsFilled(ErrorText) Then
		CommonClient.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure IndicationMethodOfPeriodEndClosingDateChoiceProcessingContinue(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	PeriodEndClosingDateSettingMethod = AdditionalParameters.ValueSelected;
	
	DeleteExtraOnChangePeriodEndClosingDateIndicationMethod(
		AdditionalParameters.ValueSelected,
		CurrentUser,
		SetPeriodEndClosingDates);
	
	If SetPeriodEndClosingDates = "ForSpecifiedUsers" Then
		Items.Users.Refresh();
	EndIf;
	
	ErrorText = "";
	ReadUserData(ThisObject, ErrorText,
		AdditionalParameters.ValueSelected, AdditionalParameters.Data);
	
	If ValueIsFilled(ErrorText) Then
		CommonClient.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationChoiceProcessingIdleHandler()
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData = Undefined Or SelectedUser = Undefined Then
		Return;
	EndIf;
	ValueSelected = SelectedUser;
	
	// 
	// 
	Filter = New Structure("User", ValueSelected);
	Rows = ClosingDatesUsers.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		If Not ReplaceUserRecordSet(CurrentUser, ValueSelected, LocksAddress) Then
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" is already in the user list.
					|Refresh the form (F5).';"), ValueSelected));
			Return;
		EndIf;
		// Set the selected user.
		CurrentUser = Undefined;
		CurrentData.User  = ValueSelected;
		CurrentData.Presentation = UserPresentationText(ThisObject, ValueSelected);
		CurrentData.FullPresentation = CurrentData.Presentation;
		
		Items.UsersComment.ReadOnly = False;
		FillPicturesNumbersOfClosingDatesUsers(ThisObject, Items.Users.CurrentRow);
		Items.Users.EndEditRow(False);
		
		UpdateUserData();
		
		NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		Items.Users.CurrentItem = Items.UsersComment;
		AttachIdleHandler("UsersChangeRow", 0.1, True);
	Else
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" is already in the user list.';"), ValueSelected));
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteConfirmation(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteUserRecordSet(AdditionalParameters.CurrentData.User,
		LocksAddress);
	
	If AdditionalParameters.ClosingDatesForAllUsers Then
		If PeriodEndClosingDateSettingMethod = "SingleDate" Then
			PeriodEndClosingDate         = '00010101';
			PeriodEndClosingDateDetails = "";
			RecordExists = False;
			PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
			PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(ThisObject);
		EndIf;
		AdditionalParameters.Insert("DataDeleted");
		UpdateClosingDatesAvailabilityOfCurrentUser();
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
	UsersBeforeDeleteContinue(Undefined, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteContinue(NotDefined, AdditionalParameters)
	
	CurrentData = AdditionalParameters.CurrentData;
	
	If AdditionalParameters.ClosingDatesForAllUsers Then
		If ShowCurrentUserSections Then
			For Each SectionDetails In ClosingDates.GetItems() Do
				If PeriodEndClosingDateSet(SectionDetails, CurrentUser)
				 Or SectionDetails.GetItems().Count() > 0 Then
					SectionDetails.PeriodEndClosingDate         = '00010101';
					SectionDetails.PeriodEndClosingDateDetails = "";
					SectionDetails.GetItems().Clear();
					SectionDetails.RecordExists = False;
					SetClosingDateDetailsPresentation(SectionDetails);
				EndIf;
			EndDo;
		Else
			If ClosingDates.GetItems().Count() > 0 Then
				ClosingDates.GetItems().Clear();
			EndIf;
		EndIf;
		CurrentData.NoPeriodEndClosingDate = True;
		CurrentData.FullPresentation = CurrentData.Presentation;
		Return;
	EndIf;
	
	PeriodEndClosingDateSettingMethod = Undefined;
	UsersOnDelete();
	
EndProcedure

&AtClient
Procedure UsersOnDelete()
	
	IndexOf = ClosingDatesUsers.IndexOf(ClosingDatesUsers.FindByID(
		Items.Users.CurrentRow));
	
	ClosingDatesUsers.Delete(IndexOf);
	
	If ClosingDatesUsers.Count() <= IndexOf And IndexOf > 0 Then
		IndexOf = IndexOf -1;
	EndIf;
	
	If ClosingDatesUsers.Count() > 0 Then
		Items.Users.CurrentRow =
			ClosingDatesUsers[IndexOf].GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteSection(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DisableClosingDateForSection(CurrentData);
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtClient
Procedure DisableClosingDateForSection(Val CurrentData)
	
	SectionItems = CurrentData.GetItems();
	
	SectionObjects = New Array;
	SectionObjects.Add(CurrentData.Section);
	For Each DataElement In SectionItems Do
		SectionObjects.Add(DataElement.Object);
	EndDo;
	
	DeleteUserRecord(LocksAddress,
		CurrentData.Section, SectionObjects, CurrentUser);
	
	SectionItems.Clear();
	CurrentData.PeriodEndClosingDate         = '00010101';
	CurrentData.PeriodEndClosingDateDetails = "";
	CurrentData.RecordExists = False;
	CurrentData.PermissionDaysCount = 0;
	SetClosingDateDetailsPresentation(CurrentData);

EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteRowCompletion(Response, SelectedRows) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	For Each SelectedRow In SelectedRows Do
		CurrentData = ClosingDates.FindByID(SelectedRow);
		If CurrentData = Undefined Then // 
			Continue;
		EndIf;
			
		If CurrentData.IsSection Then
			DisableClosingDateForSection(CurrentData);
			Continue;
		EndIf;	
		
		CurrentSection = CurrentData.GetParent();
		// 
		DeleteUserRecord(LocksAddress, 
			?(CurrentSection <> Undefined, CurrentSection.Section, Undefined), 
			CurrentData.Object, CurrentUser);
		If CurrentSection() = CurrentData.Object Then
			// Common date is deleted.
			PeriodEndClosingDate         = '00010101';
			PeriodEndClosingDateDetails = "";
			RecordExists    = False;
		EndIf;
		
		ClosingDatesOnDelete(CurrentData);
	EndDo;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtClient
Procedure ClosingDatesOnDelete(CurrentData)
	
	CurrentParent = CurrentData.GetParent();
	If CurrentParent = Undefined Then
		ClosingDatesItems = ClosingDates.GetItems();
	Else
		ClosingDatesItems = CurrentParent.GetItems();
	EndIf;
	
	IndexOf = ClosingDatesItems.IndexOf(CurrentData);
	ClosingDatesItems.Delete(IndexOf);
	If ClosingDatesItems.Count() <= IndexOf And IndexOf > 0 Then
		IndexOf = IndexOf -1;
	EndIf;
	
	If ClosingDatesItems.Count() > 0 Then
		Items.ClosingDates.CurrentRow = ClosingDatesItems[IndexOf].GetID();
		
	ElsIf CurrentParent <> Undefined Then
		Items.ClosingDates.CurrentRow = CurrentParent.GetID();
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	OnChangeOfRestrictionDatesUsageAtServer();
	
	// Calculating a restriction date setting.
	SetPeriodEndClosingDates = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	SetPeriodEndClosingDateNew = SetPeriodEndClosingDates;
	// Setting visibility according to the calculated import restriction date setting.
	SetVisibility1();
	
	// Caching the current date on the server.
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	OldUser = CurrentUser;
	
	ReadUsers();
	
	Filter = New Structure("User", OldUser);
	FoundRows = ClosingDatesUsers.FindRows(Filter);
	If FoundRows.Count() = 0 Then
		CurrentUser = ValueForAllUsers;
	Else
		Items.Users.CurrentRow = FoundRows[0].GetID();
		CurrentUser = OldUser;
	EndIf;
	
	ErrorText = "";
	ReadUserData(ThisObject, ErrorText);
	If ValueIsFilled(ErrorText) Then
		Common.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateUserDataIdleHandler()
	
	UpdateUserData();
	
EndProcedure

&AtClient
Procedure UpdateUserData()
	
	CurrentData = Items.Users.CurrentData;
	
	If CurrentData = Undefined
	 Or Not ValueIsFilled(CurrentData.Presentation) Then
		
		NewUser = Undefined;
	Else
		NewUser = CurrentData.User;
	EndIf;
	
	If NewUser = CurrentUser Then
		Return;
	EndIf;
	
	IndicationMethodValueInList =
		Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(PeriodEndClosingDateSettingMethod);
	
	If CurrentUser <> Undefined And IndicationMethodValueInList <> Undefined Then
		
		CurrentIndicationMethod = CurrentClosingDateIndicationMethod(
			CurrentUser, SingleSection, ValueForAllUsers, BegOfDay);
		
		CurrentIndicationMethod =
			?(ValueIsFilled(CurrentIndicationMethod), CurrentIndicationMethod, "SingleDate");
		
		// Warning before a significant change in the form appearance.
		If CurrentIndicationMethod <> IndicationMethodValueInList.Value 
			And Not (IndicationMethodValueInList.Value = "BySectionsAndObjects" 
				And (CurrentIndicationMethod = "BySections" Or CurrentIndicationMethod = "ByObjects")) Then
				
			ListItem = Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(
				CurrentIndicationMethod);
			
			ShowQueryBox(
				New NotifyDescription(
					"UpdateUserDataCompletion",
					ThisObject,
					NewUser),
				MessageTextExcessSetting(
					IndicationMethodValueInList.Value,
					?(ListItem = Undefined, CurrentIndicationMethod, ListItem.Presentation),
					CurrentUser,
					ThisObject) + Chars.LF + Chars.LF + NStr("en = 'Continue?';"),
				QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	UpdateUserDataCompletion(Undefined, NewUser);
	
EndProcedure

&AtClient
Procedure UpdateUserDataCompletion(Response, NewUser) Export
	
	If Response = DialogReturnCode.No Then
		Filter = New Structure("User", CurrentUser);
		FoundRows = ClosingDatesUsers.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			UsersCurrentRow = FoundRows[0].GetID();
			AttachIdleHandler(
				"UsersRestoreCurrentRowAfterCancelOnActivateRow", 0.1, True);
		EndIf;
		Return;
	EndIf;
	
	CurrentUser = NewUser;
	
	// Reading the current user data.
	If NewUser = Undefined Then
		PeriodEndClosingDateSettingMethod = "SingleDate";
		ClosingDates.GetItems().Clear();
		Items.UserData.CurrentPage = Items.UserNotSelectedPage;
	Else
		ErrorText = "";
		ReadUserData(ThisObject, ErrorText);
		If ValueIsFilled(ErrorText) Then
			CommonClient.MessageToUser(ErrorText);
		EndIf;
		AttachIdleHandler("ExpandUserData", 0.1, True);
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
	// Locking commands Pick, Add (object) until a section is selected.
	ClosingDatesSetCommandsAvailability(False);
	
EndProcedure

&AtServer
Procedure ReadUsers()
	
	Query = New Query;
	Query.SetParameter("AllSectionsWithoutObjects",     AllSectionsWithoutObjects);
	Query.SetParameter("DataImportRestrictionDates", Parameters.DataImportRestrictionDates);
	Query.Text =
	"SELECT DISTINCT
	|	PRESENTATION(PeriodClosingDates.User) AS FullPresentation,
	|	PeriodClosingDates.User,
	|	CASE
	|		WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Enum.PeriodClosingDatesPurposeTypes)
	|			THEN 0
	|		ELSE 1
	|	END AS CommonAssignment,
	|	PRESENTATION(PeriodClosingDates.User) AS Presentation,
	|	MAX(PeriodClosingDates.Comment) AS Comment,
	|	FALSE AS NoPeriodEndClosingDate,
	|	-1 AS PictureNumber
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	NOT(PeriodClosingDates.Section <> PeriodClosingDates.Object
	|				AND VALUETYPE(PeriodClosingDates.Object) = TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections))
	|	AND NOT(VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)
	|				AND &AllSectionsWithoutObjects)
	|
	|GROUP BY
	|	PeriodClosingDates.User
	|
	|HAVING
	|	PeriodClosingDates.User <> UNDEFINED AND
	|	CASE
	|		WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|				OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|			THEN &DataImportRestrictionDates = FALSE
	|		ELSE &DataImportRestrictionDates = TRUE
	|	END";
	
	// 
	// 
	Upload0 = Query.Execute().Unload();
	
	// Filling full presentation of users.
	For Each String In Upload0 Do
		String.Presentation       = UserPresentationText(ThisObject, String.User);
		String.FullPresentation = String.Presentation;
	EndDo;
	
	// Filling a presentation of all users.
	AllUsersDetails = Upload0.Find(ValueForAllUsers, "User");
	If AllUsersDetails = Undefined Then
		AllUsersDetails = Upload0.Insert(0);
		AllUsersDetails.User = ValueForAllUsers;
		AllUsersDetails.NoPeriodEndClosingDate = True;
	EndIf;
	AllUsersDetails.Presentation       = PresentationTextForAllUsers(ThisObject);
	AllUsersDetails.FullPresentation = AllUsersDetails.Presentation;
	
	Upload0.Columns.Add("AdditionalOrder", New TypeDescription("String"));
	For Each String In Upload0 Do
		If String.CommonAssignment = 0 Then
			Continue;
		EndIf;
		If Not ValueIsFilled(String.User) Then
			Continue;
		EndIf;
		If TypeOf(String.User) = Type("CatalogRef.UserGroups") Then
			String.AdditionalOrder = "1 " + String.Comment;
		ElsIf TypeOf(String.User) = Type("CatalogRef.ExternalUsersGroups") Then
			String.AdditionalOrder = "2 " + String.Comment;
		ElsIf TypeOf(String.User) = Type("CatalogRef.Users") Then
			String.AdditionalOrder = "3 ";
		ElsIf TypeOf(String.User) = Type("CatalogRef.ExternalUsers") Then
			String.AdditionalOrder = "4 ";
		Else
			String.AdditionalOrder = "5 " + String(TypeOf(String.User));
		EndIf;
	EndDo;
	Upload0.Sort("CommonAssignment Asc, AdditionalOrder Asc, FullPresentation Asc");
	
	ValueToFormAttribute(Upload0, "ClosingDatesUsers");
	
	FillPicturesNumbersOfClosingDatesUsers(ThisObject);
	
	CurrentUser = ValueForAllUsers;
	
EndProcedure

&AtClient
Procedure ExpandUserData()
	
	If ShowCurrentUserSections Then
		For Each SectionDetails In ClosingDates.GetItems() Do
			Items.ClosingDates.Expand(SectionDetails.GetID(), True);
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ReadUserData(Form, ErrorText, CurrentIndicationMethod = Undefined, Data = Undefined)
	
	If Form.SetPeriodEndClosingDates = "ForSpecifiedUsers" Then
		
		FoundRows = Form.ClosingDatesUsers.FindRows(
			New Structure("User", Form.CurrentUser));
		
		If FoundRows.Count() > 0 Then
			Form.Items.CurrentUserPresentation.Title =
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Setting for ""%1"":';"), FoundRows[0].Presentation);
		EndIf;
	EndIf;
	
	Form.Items.UserData.CurrentPage =
		Form.Items.UserSelectedPage;
	
	Form.ClosingDates.GetItems().Clear();
	
	If CurrentIndicationMethod = Undefined Then
		CurrentIndicationMethod = CurrentClosingDateIndicationMethod(
			Form.CurrentUser,
			Form.SingleSection,
			Form.ValueForAllUsers,
			Form.BegOfDay,
			Data);
		
		CurrentIndicationMethod = ?(CurrentIndicationMethod = "", "SingleDate", CurrentIndicationMethod);
		If Form.PeriodEndClosingDateSettingMethod <> CurrentIndicationMethod Then
			Form.PeriodEndClosingDateSettingMethod = CurrentIndicationMethod;
		EndIf;
	EndIf;
	
	If Form.PeriodEndClosingDateSettingMethod = "SingleDate" Then
		Form.Items.DateSettingMethodBySectionsObjects.Visible = False;
		Form.Items.DateSettingMethods.CurrentPage = Form.Items.DateSettingMethodSingleDate;
		// 
		Form.Items.ClosingDates.VerticalStretch = False;
		
		FillPropertyValues(Form, Data);
		Form.EnableDataChangeBeforePeriodEndClosingDate = Form.PermissionDaysCount <> 0;
		PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(Form, False);
		PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(Form);
		Form.Items.PeriodEndClosingDateDetails.ReadOnly = False;
		Form.Items.PeriodEndClosingDate.ReadOnly = False;
		Form.Items.EnableDataChangeBeforePeriodEndClosingDate.ReadOnly = False;
		Form.Items.PermissionDaysCount.ReadOnly = False;
		Try
			LockUserRecordAtServer(Form.LocksAddress,
				Form.SectionEmptyRef,
				Form.SectionEmptyRef,
				Form.CurrentUser,
				True);
		Except
			Form.Items.PeriodEndClosingDateDetails.ReadOnly = True;
			Form.Items.PeriodEndClosingDate.ReadOnly = True;
			Form.Items.EnableDataChangeBeforePeriodEndClosingDate.ReadOnly = True;
			Form.Items.PermissionDaysCount.ReadOnly = True;
			
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		Return;
	EndIf;
	
	Form.Items.DateSettingMethodBySectionsObjects.Visible = True;
	Form.Items.DateSettingMethods.CurrentPage = Form.Items.DateSettingMethodBySectionsObjects;
	Form.Items.ClosingDates.VerticalStretch = True;
	
	SetCommandBarOfClosingDates(Form);
	
	ClosingDatesParameters = New Structure;
	ClosingDatesParameters.Insert("BegOfDay",                    Form.BegOfDay);
	ClosingDatesParameters.Insert("User",                 Form.CurrentUser);
	ClosingDatesParameters.Insert("SingleSection",           Form.SingleSection);
	ClosingDatesParameters.Insert("ShowSections",            Form.ShowSections);
	ClosingDatesParameters.Insert("AllSectionsWithoutObjects",        Form.AllSectionsWithoutObjects);
	ClosingDatesParameters.Insert("SectionsWithoutObjects",           Form.SectionsWithoutObjects);
	ClosingDatesParameters.Insert("SectionsTableAddress",         Form.SectionsTableAddress);
	ClosingDatesParameters.Insert("FormIdentifier",           Form.UUID);
	ClosingDatesParameters.Insert("PeriodEndClosingDateSettingMethod",    Form.PeriodEndClosingDateSettingMethod);
	ClosingDatesParameters.Insert("ValueForAllUsers", Form.ValueForAllUsers);
	ClosingDatesParameters.Insert("DataImportRestrictionDates",    Form.Parameters.DataImportRestrictionDates);
	ClosingDatesParameters.Insert("LocksAddress", Form.LocksAddress);
	
	ClosingDates = UserClosingDates(ClosingDatesParameters);
	Form.ShowCurrentUserSections = ClosingDates.ShowCurrentUserSections;
	Form.HasInvalidObjectsByUsers = ClosingDates.HasInvalidObjectsByUsers;
	Form.HasUnavailableObjects = ClosingDates.HasUnavailableObjects;

	// Importing user data to the collection.
	RowsCollection = Form.ClosingDates.GetItems();
	RowsCollection.Clear();
	For Each String In ClosingDates.ClosingDates Do
		NewRow = RowsCollection.Add();
		FillPropertyValues(NewRow, String.Value);
		SetClosingDateDetailsPresentation(NewRow);
		SubstringsCollection = NewRow.GetItems();
		
		For Each Substring In String.Value.SubstringsList Do
			NewSubstring = SubstringsCollection.Add();
			FillPropertyValues(NewSubstring, Substring.Value);
			FillByInternalDetailsOfPeriodEndClosingDate(
				NewSubstring, NewSubstring.PeriodEndClosingDateDetails);
			
			SetClosingDateDetailsPresentation(NewSubstring);
		EndDo;
		
		If NewRow.IsSection Then
			NewRow.SectionWithoutObjects =
				Form.SectionsWithoutObjects.Find(NewRow.Section) <> Undefined;
		EndIf;
	EndDo;
	
	// Setting the field of the ClosingDates form.
	If Form.ShowCurrentUserSections Then
		If Form.AllSectionsWithoutObjects Then
			// 
			// 
			// 
			Form.Items.ClosingDatesFullPresentation.Title = NStr("en = 'Section';");
			Form.Items.ClosingDates.Representation = TableRepresentation.List;
			
		Else
			Form.Items.ClosingDatesFullPresentation.Title = NStr("en = 'Section, object';");
			Form.Items.ClosingDates.Representation = TableRepresentation.Tree;
		EndIf;
	Else
		ObjectsTypesPresentations = "";
		SectionObjectsTypes = Form.Sections.Get(Form.SingleSection).ObjectsTypes;
		If SectionObjectsTypes <> Undefined Then
			For Each TypeProperties In SectionObjectsTypes Do
				ObjectsTypesPresentations = ObjectsTypesPresentations + Chars.LF
					+ TypeProperties.Presentation;
			EndDo;
		EndIf;
		Form.Items.ClosingDatesFullPresentation.Title = TrimAll(ObjectsTypesPresentations);
		Form.Items.ClosingDates.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UserClosingDates(Val Form)
	
	UnlockAllRecordsAtServer(Form.LocksAddress);
	
	Result = New Structure;
	Result.Insert("ShowCurrentUserSections", 
		Form.ShowSections
		Or Form.PeriodEndClosingDateSettingMethod = "BySections"
		Or Form.PeriodEndClosingDateSettingMethod = "BySectionsAndObjects");
	Result.Insert("HasUnavailableObjects", False);
	Result.Insert("HasInvalidObjectsByUsers", False);
	Result.Insert("ClosingDates", New ValueList);
	
	// Preparing a value tree of period-end closing dates.
	If Result.ShowCurrentUserSections Then
		ReadClosingDates = ReadUserDataWithSections(
			Form.User,
			Form.AllSectionsWithoutObjects,
			Form.SectionsWithoutObjects,
			Form.SectionsTableAddress,
			Form.BegOfDay,
			Form.DataImportRestrictionDates);
	Else
		ReadClosingDates = ReadUserDataWithoutSections(
			Form.User, Form.SingleSection);
	EndIf;
	
	If HasInvalidObjectsByUsers(Form.DataImportRestrictionDates) Then
		Result.HasInvalidObjectsByUsers = True;
	EndIf;
	UnavailableObjects = UnavailableObjects(Form.User);
	
	// For passing from a server to the client in a thick client.
	StringFields = "FullPresentation, Presentation, Section, Object,
	             |PeriodEndClosingDate, PeriodEndClosingDateDetails, PermissionDaysCount,
	             |NoPeriodEndClosingDate, IsSection, SubstringsList, RecordExists";
	
	For Each String In ReadClosingDates.Rows Do
		
		NewRow = New Structure(StringFields);
		FillPropertyValues(NewRow, String);
		NewRow.SubstringsList = New ValueList;
		
		For Each Substring In String.Rows Do
			If UnavailableObjects.Get(Substring.Object) <> Undefined Then
				Result.HasUnavailableObjects = True;
				Continue;
			EndIf;
			NewSubstring = New Structure(StringFields);
			FillPropertyValues(NewSubstring, Substring);
			SubstringsList = NewRow.SubstringsList; // ValueList
			SubstringsList.Add(NewSubstring);
		EndDo;
		
		Result.ClosingDates.Add(NewRow);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ReadUserDataWithSections(Val User,
                                              Val AllSectionsWithoutObjects,
                                              Val SectionsWithoutObjects,
                                              Val SectionsTableAddress,
                                              Val BegOfDay,
                                              Val DataImportRestrictionDates)
	
	// 
	// 
	Query = New Query;
	Query.SetParameter("User",              User);
	Query.SetParameter("AllSectionsWithoutObjects",     AllSectionsWithoutObjects);
	Query.SetParameter("DataImportRestrictionDates", DataImportRestrictionDates);
	Query.SetParameter("SectionsTable", GetFromTempStorage(SectionsTableAddress));
	Query.Text =
	"SELECT DISTINCT
	|	SectionsTable.Ref AS Ref,
	|	SectionsTable.Presentation AS Presentation,
	|	SectionsTable.IsCommonDate AS IsCommonDate
	|INTO SectionsTable
	|FROM
	|	&SectionsTable AS SectionsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sections.Ref AS Ref,
	|	Sections.Presentation AS Presentation,
	|	Sections.IsCommonDate AS IsCommonDate
	|INTO Sections
	|FROM
	|	(SELECT
	|		SectionsTable.Ref AS Ref,
	|		SectionsTable.Presentation AS Presentation,
	|		SectionsTable.IsCommonDate AS IsCommonDate
	|	FROM
	|		SectionsTable AS SectionsTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PeriodClosingDates.Section,
	|		PeriodClosingDates.Section.Description,
	|		FALSE
	|	FROM
	|		InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|			LEFT JOIN SectionsTable AS SectionsTable
	|			ON PeriodClosingDates.Section = SectionsTable.Ref
	|	WHERE
	|		SectionsTable.Ref IS NULL
	|		AND PeriodClosingDates.User <> UNDEFINED
	|		AND CASE
	|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|					THEN &DataImportRestrictionDates = FALSE
	|				ELSE &DataImportRestrictionDates = TRUE
	|			END) AS Sections
	|
	|INDEX BY
	|	Sections.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Sections.Ref AS Section,
	|	Sections.IsCommonDate AS IsCommonDate,
	|	Sections.Presentation AS SectionPresentation,
	|	PeriodClosingDates.Object AS Object,
	|	PRESENTATION(PeriodClosingDates.Object) AS FullPresentation,
	|	PRESENTATION(PeriodClosingDates.Object) AS Presentation,
	|	CASE
	|		WHEN PeriodClosingDates.Object IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NoPeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	FALSE AS IsSection,
	|	0 AS PermissionDaysCount,
	|	TRUE AS RecordExists
	|FROM
	|	Sections AS Sections
	|		LEFT JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON Sections.Ref = PeriodClosingDates.Section
	|			AND (PeriodClosingDates.User = &User)
	|			AND (NOT(PeriodClosingDates.Section <> PeriodClosingDates.Object
	|					AND VALUETYPE(PeriodClosingDates.Object) = TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)))
	|			AND (NOT(VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)
	|					AND &AllSectionsWithoutObjects))
	|
	|ORDER BY
	|	IsCommonDate DESC,
	|	SectionPresentation
	|TOTALS
	|	MAX(IsCommonDate),
	|	MAX(SectionPresentation),
	|	MIN(NoPeriodEndClosingDate),
	|	MAX(IsSection)
	|BY
	|	Section";
	
	ReadClosingDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each String In ReadClosingDates.Rows Do
		String.Presentation = String.SectionPresentation;
		String.Object    = String.Section;
		String.IsSection = True;
		SectionRow = String.Rows.Find(String.Section, "Object");
		If SectionRow <> Undefined Then
			String.RecordExists = True;
			String.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
				SectionRow.PeriodEndClosingDateDetails, SectionRow.PeriodEndClosingDate, BegOfDay);
			
			If ValueIsFilled(SectionRow.PeriodEndClosingDateDetails) Then
				FillByInternalDetailsOfPeriodEndClosingDate(String, SectionRow.PeriodEndClosingDateDetails);
			Else
				String.PeriodEndClosingDateDetails = "Custom";
			EndIf;
			String.Rows.Delete(SectionRow);
		Else
			If String.Rows.Count() = 1
			   And String.Rows[0].Object = Null Then
				
				String.Rows.Delete(String.Rows[0]);
			EndIf;
		EndIf;
		String.FullPresentation = String.Presentation;
		For Each Substring In String.Rows Do
			Substring.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
				Substring.PeriodEndClosingDateDetails, Substring.PeriodEndClosingDate, BegOfDay);
		EndDo;
	EndDo;
	
	Return ReadClosingDates;
	
EndFunction

&AtServerNoContext
Function ReadUserDataWithoutSections(Val User, Val SingleSection)
	
	// Value tree with the first level by objects.
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",           User);
		Query.SetParameter("SingleSection",     SingleSection);
		Query.SetParameter("SingleDatePresentation", CommonDatePresentationText());
		// ACC:494-
		// 
		Query.Text =
		"SELECT ALLOWED
		|	VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef) AS Section,
		|	VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef) AS Object,
		|	&SingleDatePresentation AS FullPresentation,
		|	&SingleDatePresentation AS Presentation,
		|	ISNULL(SingleDate.PeriodEndClosingDate, DATETIME(1, 1, 1, 0, 0, 0)) AS PeriodEndClosingDate,
		|	ISNULL(SingleDate.PeriodEndClosingDateDetails, """") AS PeriodEndClosingDateDetails,
		|	TRUE AS IsSection,
		|	0 AS PermissionDaysCount,
		|	TRUE AS RecordExists
		|FROM
		|	(SELECT
		|		TRUE AS TrueValue) AS Value
		|		LEFT JOIN (SELECT
		|			PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
		|			PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails
		|		FROM
		|			InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|		WHERE
		|			PeriodClosingDates.User = &User
		|			AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|			AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)) AS SingleDate
		|		ON (TRUE)
		|
		|UNION ALL
		|
		|SELECT
		|	&SingleSection,
		|	PeriodClosingDates.Object,
		|	PRESENTATION(PeriodClosingDates.Object),
		|	PRESENTATION(PeriodClosingDates.Object),
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails,
		|	FALSE,
		|	0,
		|	TRUE
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User
		|	AND PeriodClosingDates.Section = &SingleSection
		|	AND VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)";
		// ACC:494-on
		
		ReadClosingDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	IndexOf = ReadClosingDates.Rows.Count()-1;
	While IndexOf >= 0 Do
		String = ReadClosingDates.Rows[IndexOf];
		FillByInternalDetailsOfPeriodEndClosingDate(String, String.PeriodEndClosingDateDetails);
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return ReadClosingDates;
	
EndFunction

&AtServerNoContext
Function HasInvalidObjectsByUsers(DataImportRestrictionDates)
	
	Query = New Query;
	Query.SetParameter("DataImportRestrictionDates", DataImportRestrictionDates);
	// ACC:1377-
	// 
	Query.Text =
	"SELECT ALLOWED
	|	ISNULL(SUM(CASE
	|				WHEN NOT PeriodClosingDates.Object.Ref IS NULL
	|					THEN 1
	|				ELSE 0
	|			END), 0) AS ObjectCount
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	PeriodClosingDates.User <> UNDEFINED
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Enum.PeriodClosingDatesPurposeTypes)
	|	AND CASE
	|			WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|					OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|					OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|					OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|				THEN &DataImportRestrictionDates = FALSE
	|			ELSE &DataImportRestrictionDates = TRUE
	|		END";
	// 
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	ObjectCount = ?(Selection.Next(), Selection.ObjectCount, 0);
	SetPrivilegedMode(False);
	
	Selection = Query.Execute().Select();
	AvailableObjectCount = ?(Selection.Next(), Selection.ObjectCount, 0);
	
	Return ObjectCount > AvailableObjectCount;
	
EndFunction

&AtServerNoContext
Function UnavailableObjects(User)
	
	// 
	// 
	Query = New Query;
	Query.SetParameter("User", User);
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	PeriodClosingDates.Object AS Object
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	PeriodClosingDates.User = &User
	|	AND PeriodClosingDates.Object.Ref IS NULL";
	// 
	
	SetPrivilegedMode(True);
	NonExistentObjects = Query.Execute().Unload().UnloadColumn("Object");
	SetPrivilegedMode(False);
	
	Result = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If NonExistentObjects.Find(Selection.Object) = Undefined Then
			Result.Insert(Selection.Object, True);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure LockUserRecordSetAtServer(Val User, Val LocksAddress, DataDetails = Undefined)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	PeriodClosingDates.Section,
		|	PeriodClosingDates.Object,
		|	PeriodClosingDates.User,
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails,
		|	PeriodClosingDates.Comment
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User";
		
		Upload0 = Query.Execute().Unload();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Locks = GetFromTempStorage(LocksAddress);
	Try
		For Each RecordDetails In Upload0 Do
			If LockRecordAtServer(RecordDetails, LocksAddress) Then
				If DataDetails <> Undefined Then
					// Rereading fields PeriodEndClosingDate, PeriodEndClosingDateDetails, and Comment.
					If Locks.NoSectionsAndObjects Then
						If RecordDetails.Section = Locks.SectionEmptyRef
						   And RecordDetails.Object = Locks.SectionEmptyRef Then
							DataDetails.PeriodEndClosingDate         = RecordDetails.PeriodEndClosingDate;
							DataDetails.PeriodEndClosingDateDetails = RecordDetails.PeriodEndClosingDateDetails;
							DataDetails.Comment         = RecordDetails.Comment;
						EndIf;
					Else
						DataDetails.Comment = RecordDetails.Comment;
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	Except
		UnlockAllRecordsAtServer(LocksAddress);
		Raise;
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure UnlockAllRecordsAtServer(LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	RecordKeyValues = New Structure("Section, Object, User");
	Try
		IndexOf = Locks.Content.Count() - 1;
		While IndexOf >= 0 Do
			FillPropertyValues(RecordKeyValues, Locks.Content[IndexOf]);
			RecordKey = InformationRegisters.PeriodClosingDates.CreateRecordKey(RecordKeyValues);
			UnlockDataForEdit(RecordKey, Locks.FormIdentifier);
			Locks.Content.Delete(IndexOf);
			IndexOf = IndexOf - 1;
		EndDo;
	Except
		PutToTempStorage(Locks, LocksAddress);
		Raise;
	EndTry;
	PutToTempStorage(Locks, LocksAddress);
	
EndProcedure

&AtServerNoContext
Function LockRecordAtServer(RecordKeyDetails, LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	RecordKeyValues = New Structure("Section, Object, User");
	FillPropertyValues(RecordKeyValues, RecordKeyDetails);
	RecordKey = InformationRegisters.PeriodClosingDates.CreateRecordKey(RecordKeyValues);
	LockDataForEdit(RecordKey, , Locks.FormIdentifier);
	LockAdded = False;
	If Locks.Content.FindRows(RecordKeyValues).Count() = 0 Then
		FillPropertyValues(Locks.Content.Add(), RecordKeyValues);
		LockAdded = True;
	EndIf;
	PutToTempStorage(Locks, LocksAddress);
	
	Return LockAdded;
	
EndFunction

&AtServerNoContext
Function ReplaceUserRecordSet(OldUser, NewUser, LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	
	If OldUser <> Undefined Then
		LockUserRecordSetAtServer(OldUser, LocksAddress);
	EndIf;
	LockUserRecordSetAtServer(NewUser, LocksAddress);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.PeriodClosingDates");
		LockItem.SetValue("User", NewUser);
		If OldUser <> Undefined Then
			LockItem = Block.Add("InformationRegister.PeriodClosingDates");
			LockItem.SetValue("User", OldUser);
		EndIf;	
		Block.Lock();
		
		RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		RecordSet.Filter.User.Set(NewUser, True);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RollbackTransaction();
			Return False;
		EndIf;
		
		If OldUser = Undefined Then
			LockAndWriteBlankDates(LocksAddress,
				Locks.SectionEmptyRef, Locks.SectionEmptyRef, NewUser, "");
			RollbackTransaction();
			Return True;
		EndIf;
				
		RecordSet.Filter.User.Set(OldUser, True);
		RecordSet.Read();
		UserData = RecordSet.Unload();
		RecordSet.Clear();
		RecordSet.Write();
		
		UserData.FillValues(NewUser, "User");
		RecordSet.Filter.User.Set(NewUser, True);
		RecordSet.Load(UserData);
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockAllRecordsAtServer(LocksAddress);
		Raise;
	EndTry;
	
	UnlockAllRecordsAtServer(LocksAddress);
	Return True;
	
EndFunction

&AtServerNoContext
Procedure DeleteUserRecordSet(Val User, Val LocksAddress)
	
	LockUserRecordSetAtServer(User, LocksAddress);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	RecordSet.Write();
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtServerNoContext
Procedure WriteComment(User, Comment);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.PeriodClosingDates");
	LockItem.SetValue("User", User);
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		RecordSet.Filter.User.Set(User, True);
		RecordSet.Read();
		UserData = RecordSet.Unload();
		UserData.FillValues(Comment, "Comment");
		RecordSet.Load(UserData);
		RecordSet.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties, CommentCurrentData = False)
	
	If ReadProperties.Comment <> Undefined Then
		
		If CommentCurrentData = False Then
			CurrentPropertiesValues.Comment = ReadProperties.Comment;
			
		ElsIf CommentCurrentData <> Undefined Then
			CommentCurrentData.Comment = ReadProperties.Comment;
		EndIf;
	EndIf;
	
	CurrentPropertiesValues.RecordExists = ReadProperties.PeriodEndClosingDate <> Undefined;
	CurrentPropertiesValues.PeriodEndClosingDate              = ReadProperties.PeriodEndClosingDate;
	CurrentPropertiesValues.PeriodEndClosingDateDetails      = ReadProperties.PeriodEndClosingDateDetails;
	CurrentPropertiesValues.PermissionDaysCount = ReadProperties.PermissionDaysCount;
	SetClosingDateDetailsPresentation(CurrentPropertiesValues);
	
EndProcedure

&AtClientAtServerNoContext
Function GetCurrentPropertiesValues(CurrentData, CommentCurrentData)
	
	Properties = New Structure;
	Properties.Insert("PeriodEndClosingDate");
	Properties.Insert("PeriodEndClosingDateDetails");
	Properties.Insert("PermissionDaysCount");
	Properties.Insert("Comment");
	
	If CommentCurrentData <> Undefined Then
		Properties.Comment = CommentCurrentData.Comment;
	EndIf;
	
	Properties.PeriodEndClosingDate              = CurrentData.PeriodEndClosingDate;
	Properties.PeriodEndClosingDateDetails      = CurrentData.PeriodEndClosingDateDetails;
	Properties.PermissionDaysCount = CurrentData.PermissionDaysCount;
	
	Return Properties;
	
EndFunction

&AtServerNoContext
Function LockUserRecordAtServer(Val LocksAddress, Val Section, Val Object,
			 Val User, Val UnlockPreviouslyLocked = False)
	
	If UnlockPreviouslyLocked Then
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
	RecordKeyValues = New Structure;
	RecordKeyValues.Insert("Section",       Section);
	RecordKeyValues.Insert("Object",       Object);
	RecordKeyValues.Insert("User", User);
	
	LockRecordAtServer(RecordKeyValues, LocksAddress);
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	FillPropertyValues(RecordManager, RecordKeyValues);
	RecordManager.Read();
	
	ReadProperties = New Structure;
	ReadProperties.Insert("PeriodEndClosingDate");
	ReadProperties.Insert("PeriodEndClosingDateDetails");
	ReadProperties.Insert("PermissionDaysCount");
	ReadProperties.Insert("Comment");
	
	If RecordManager.Selected() Then
		Locks = GetFromTempStorage(LocksAddress);
		ReadProperties.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
			RecordManager.PeriodEndClosingDateDetails, RecordManager.PeriodEndClosingDate, Locks.BegOfDay);
		
		ReadProperties.Comment = RecordManager.Comment;
		FillByInternalDetailsOfPeriodEndClosingDate(
			ReadProperties, RecordManager.PeriodEndClosingDateDetails);
	Else
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("User", RecordKeyValues.User);
			Query.Text =
			"SELECT TOP 1
			|	PeriodClosingDates.Comment
			|FROM
			|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
			|WHERE
			|	PeriodClosingDates.User = &User";
			Selection = Query.Execute().Select();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If Selection.Next() Then
			ReadProperties.Comment = Selection.Comment;
		EndIf;
	EndIf;
	
	Return ReadProperties;
	
EndFunction

&AtServerNoContext
Function ReplaceObjectInUserRecordAtServer(Val Section, Val OldObject, Val NewObject, Val User,
			CurrentPropertiesValues, LocksAddress)
	
	// Locking a new record and checking if it exists.
	LockUserRecordAtServer(LocksAddress, Section, NewObject, User);
	
	RecordKeyValues = New Structure;
	RecordKeyValues.Insert("Section",       Section);
	RecordKeyValues.Insert("Object",       NewObject);
	RecordKeyValues.Insert("User", User);
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	FillPropertyValues(RecordManager, RecordKeyValues);
	RecordManager.Read();
	If RecordManager.Selected() Then
		UnlockAllRecordsAtServer(LocksAddress);
		Return False;
	EndIf;
	
	If ValueIsFilled(OldObject) Then
		// Lock an old record.
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			Section, OldObject, User);
		
		UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties);
		
		RecordKeyValues.Object = OldObject;
		FillPropertyValues(RecordManager, RecordKeyValues);
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndIf;
	
	RecordManager.Section              = Section;
	RecordManager.Object              = NewObject;
	RecordManager.User        = User;
	RecordManager.PeriodEndClosingDate         = InternalPeriodEndClosingDate(CurrentPropertiesValues);
	RecordManager.PeriodEndClosingDateDetails = InternalDetailsOfPeriodEndClosingDate(CurrentPropertiesValues);
	RecordManager.Comment         = CurrentPropertiesValues.Comment;
	
	If PeriodEndClosingDateSet(RecordManager, User, True) Then
		RecordManager.Write();
	EndIf;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Return True;
	
EndFunction

&AtClient
Function CurrentSection(CurrentData = Undefined, ObjectsSection = False)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ClosingDates.CurrentData;
	EndIf;
	
	If NoSectionsAndObjects
	 Or PeriodEndClosingDateSettingMethod = "SingleDate" Then
		
		CurrentSection = SectionEmptyRef;
		
	ElsIf ShowCurrentUserSections Then
		If CurrentData.IsSection Then
			CurrentSection = CurrentData.Section;
		Else
			CurrentSection = CurrentData.GetParent().Section;
		EndIf;
		
	Else // The only section hidden from a user.
		If CurrentData <> Undefined
		   And CurrentData.Section = SectionEmptyRef
		   And Not ObjectsSection Then
			
			CurrentSection = SectionEmptyRef;
		Else
			CurrentSection = SingleSection;
		EndIf;
	EndIf;
	
	Return CurrentSection;
	
EndFunction

&AtClient
Procedure WriteCommonPeriodEndClosingDateWithDetails();
	
	Data = CurrentDataOfCommonPeriodEndClosingDate();
	WriteDetailsAndPeriodEndClosingDate(Data);
	RecordExists = Data.RecordExists;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtClient
Procedure UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler()
	
	PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(ThisObject);
	
EndProcedure

&AtClient
Function CurrentDataOfCommonPeriodEndClosingDate()
	
	Data = New Structure;
	Data.Insert("Object",                   SectionEmptyRef);
	Data.Insert("Section",                   SectionEmptyRef);
	Data.Insert("PeriodEndClosingDateDetails",      PeriodEndClosingDateDetails);
	Data.Insert("PermissionDaysCount", PermissionDaysCount);
	Data.Insert("PeriodEndClosingDate",              PeriodEndClosingDate);
	Data.Insert("RecordExists",         RecordExists);
	
	Return Data;
	
EndFunction

&AtClient
Procedure WriteDetailsAndPeriodEndClosingDate(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ClosingDates.CurrentData;
	EndIf;
	
	If PeriodEndClosingDateSet(CurrentData, CurrentUser, True) Then
		// Writing details or a period-end closing date.
		Comment = CurrentUserComment(ThisObject);
		RecordPeriodEndClosingDateWithDetails(
			CurrentData.Section,
			CurrentData.Object,
			CurrentUser,
			InternalPeriodEndClosingDate(CurrentData),
			InternalDetailsOfPeriodEndClosingDate(CurrentData),
			Comment);
		CurrentData.RecordExists = True;
	Else
		DeleteUserRecord(LocksAddress,
			CurrentData.Section,
			CurrentData.Object,
			CurrentUser);
		
		CurrentData.PeriodEndClosingDateDetails = "";
		CurrentData.RecordExists = False;
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtServerNoContext
Procedure RecordPeriodEndClosingDateWithDetails(Val Section, Val Object, Val User, Val PeriodEndClosingDate, Val InternalDetailsOfPeriodEndClosingDate, Val Comment)
	
	If Not ValueIsFilled(PeriodEndClosingDate) Then
		PeriodEndClosingDate = '39991231';
	EndIf;
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	RecordManager.Section              = Section;
	RecordManager.Object              = Object;
	RecordManager.User        = User;
	RecordManager.PeriodEndClosingDate         = PeriodEndClosingDate;
	RecordManager.PeriodEndClosingDateDetails = InternalDetailsOfPeriodEndClosingDate;
	RecordManager.Comment = Comment;
	RecordManager.Write();
	
EndProcedure

&AtServerNoContext
Procedure DeleteUserRecord(Val LocksAddress, Val Section, Val Object, Val User)
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	
	If TypeOf(Object) = Type("Array") Then
		Objects = Object;
	Else
		Objects = New Array;
		Objects.Add(Object);
	EndIf;
	
	For Each CurrentObject In Objects Do
		// 
		LockUserRecordAtServer(LocksAddress,
			Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject In Objects Do
		RecordManager.Section = Section;
		RecordManager.Object = CurrentObject;
		RecordManager.User = User;
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtClient
Procedure UpdateClosingDatesAvailabilityOfCurrentUser()
	
	NoPeriodEndClosingDate = True;
	If PeriodEndClosingDateSettingMethod = "SingleDate" Then
		Data = CurrentDataOfCommonPeriodEndClosingDate();
		NoPeriodEndClosingDate = Not PeriodEndClosingDateSet(Data, CurrentUser);
	Else
		For Each String In ClosingDates.GetItems() Do
			WithoutSectionPeriodEndClosingDate = True;
			If PeriodEndClosingDateSet(String, CurrentUser) Then
				WithoutSectionPeriodEndClosingDate = False;
			EndIf;
			For Each SubordinateRow In String.GetItems() Do
				If PeriodEndClosingDateSet(SubordinateRow, CurrentUser) Then
					SubordinateRow.NoPeriodEndClosingDate = False;
					WithoutSectionPeriodEndClosingDate = False;
				Else
					SubordinateRow.NoPeriodEndClosingDate = True;
				EndIf;
			EndDo;
			String.FullPresentation = String.Presentation;
			String.NoPeriodEndClosingDate = WithoutSectionPeriodEndClosingDate;
			NoPeriodEndClosingDate = NoPeriodEndClosingDate And WithoutSectionPeriodEndClosingDate;
		EndDo;
	EndIf;
	
	If Items.Users.CurrentData <> Undefined Then
		Items.Users.CurrentData.NoPeriodEndClosingDate = NoPeriodEndClosingDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEditIdleHandler()
	
	SelectPickUsers();
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Pick = False)
	
	If Parameters.DataImportRestrictionDates Then
		SelectPickExchangePlansNodes(Pick);
		Return;
	EndIf;
	
	If UseExternalUsers Then
		ShowTypeSelectionUsersOrExternalUsers(
			New NotifyDescription("SelectPickUsersCompletion", ThisObject, Pick));
	Else
		SelectPickUsersCompletion(False, Pick);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickUsersCompletion(ExternalUsersSelectionAndPickup, Pick) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If ExternalUsersSelectionAndPickup Then
		FormParameters.Insert("SelectExternalUsersGroups", True);
	Else
		FormParameters.Insert("UsersGroupsSelection", True);
	EndIf;
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
	
		If ExternalUsersCatalogAvailable Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, FormOwner);
		Else
			ShowMessageBox(, NStr("en = 'Insufficient rights to select external users.';"));
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickExchangePlansNodes(Pick)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectAllNodes", True);
	FormParameters.Insert("ExchangePlansForSelection", UserTypesList.UnloadValues());
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("MultipleChoice", True);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	OpenForm("CommonForm.SelectExchangePlanNodes", FormParameters, FormOwner);
	
EndProcedure

&AtServerNoContext
Function GenerateUserSelectionData(Val Text,
                                             Val IncludeGroups = True,
                                             Val IncludeExternalUsers = Undefined,
                                             Val NoUsers = False)
	
	Return Users.GenerateUserSelectionData(
		Text,
		IncludeGroups,
		IncludeExternalUsers,
		NoUsers);
	
EndFunction

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsers(ContinuationHandler)
	
	ExternalUsersSelectionAndPickup = False;
	
	If UseExternalUsers Then
		
		UserTypesList.ShowChooseItem(
			New NotifyDescription(
				"ShowTypeSelectionUsersOrExternalUsersCompletion",
				ThisObject,
				ContinuationHandler),
			HeaderTextDataTypeSelection(),
			UserTypesList[0]);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsersCompletion(SelectedElement, ContinuationHandler) Export
	
	If SelectedElement <> Undefined Then
		ExternalUsersSelectionAndPickup =
			SelectedElement.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, Undefined);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillPicturesNumbersOfClosingDatesUsers(Form, CurrentRow = Undefined)
	
	Rows = New Array;
	If CurrentRow = Undefined Then
		Rows = Form.ClosingDatesUsers;
	Else
		Rows.Add(Form.ClosingDatesUsers.FindByID(CurrentRow));
	EndIf;
	
	RowsArray = New Array;
	For Each String In Rows Do
		RowProperties = New Structure("User, PictureNumber");
		FillPropertyValues(RowProperties, String);
		RowsArray.Add(RowProperties);
	EndDo;
	
	FillPicturesNumbersOfClosingDatesUsersAtServer(RowsArray,
		Form.Parameters.DataImportRestrictionDates);
	
	IndexOf = Rows.Count()-1;
	While IndexOf >= 0 Do
		FillPropertyValues(Rows[IndexOf], RowsArray[IndexOf], "PictureNumber");
		IndexOf = IndexOf - 1;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure FillPicturesNumbersOfClosingDatesUsersAtServer(RowsArray, DataImportRestrictionDates)
	
	If DataImportRestrictionDates Then
		
		For Each String In RowsArray Do
			
			If String.User =
					Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
				
				String.PictureNumber = -1;
				
			ElsIf Not ValueIsFilled(String.User) Then
				String.PictureNumber = 0;
				
			ElsIf String.User
			        = Common.ObjectManagerByRef(String.User).ThisNode() Then
				
				String.PictureNumber = 1;
			Else
				String.PictureNumber = 2;
			EndIf;
		EndDo;
	Else
		Users.FillUserPictureNumbers(
			RowsArray, "User", "PictureNumber");
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerSelectObjects()
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ClosingDatesSetCommandsAvailability(Val CommandsAvailability)
	
	If Items.ClosingDates.ReadOnly Then
		CommandsAvailability = False;
	EndIf;
	
	Items.ClosingDatesChange.Enabled                = CommandsAvailability;
	Items.ClosingDatesContextMenuChange.Enabled = CommandsAvailability;
	
	If PeriodEndClosingDateSettingMethod = "ByObjects" Then
		CommandsAvailability = Items.ClosingDates.ReadOnly;
	EndIf;
	
	Items.ClosingDatesPick.Enabled = CommandsAvailability;
	
	Items.ClosingDatesAdd.Enabled                = CommandsAvailability;
	Items.ClosingDatesContextMenuAdd.Enabled = CommandsAvailability;
	
EndProcedure

&AtClient
Procedure SelectPickObjects(Pick = False)
	
	// Select data type
	CurrentSection = CurrentSection(, True);
	If CurrentSection = SectionEmptyRef Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Return;
	EndIf;
	SectionObjectsTypes = Sections.Get(CurrentSection).ObjectsTypes;
	If SectionObjectsTypes = Undefined Or SectionObjectsTypes.Count() = 0 Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Return;
	EndIf;
	
	TypesList = New ValueList;
	For Each TypeProperties In SectionObjectsTypes Do
		TypesList.Add(TypeProperties.FullName, TypeProperties.Presentation);
	EndDo;
	
	If TypesList.Count() = 1 Then
		SelectPickObjectsCompletion(TypesList[0], Pick);
	Else
		TypesList.ShowChooseItem(
			New NotifyDescription("SelectPickObjectsCompletion", ThisObject, Pick),
			HeaderTextDataTypeSelection(),
			TypesList[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickObjectsCompletion(Item, Pick) Export
	
	If Item = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(CurrentData = Undefined, Undefined, CurrentData.Object));
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.ClosingDates;
	Else
		FormOwner = Items.ClosingDatesFullPresentation;
	EndIf;
	
	OpenForm(Item.Value + ".ChoiceForm", FormParameters, FormOwner);
	
EndProcedure

&AtClient
Function NotificationTextOfUnusedSettingModes()
	
	If Not ValueIsFilled(CurrentUser) Then
		Return "";
	EndIf;
	
	SetClosingDatesInDatabase = "";
	IndicationMethodInDatabase = "";
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("BegOfDay",                    BegOfDay);
	AdditionalParameters.Insert("DataImportRestrictionDates",    Parameters.DataImportRestrictionDates);
	AdditionalParameters.Insert("User",                 CurrentUser);
	AdditionalParameters.Insert("SingleSection",           SingleSection);
	AdditionalParameters.Insert("ValueForAllUsers", ValueForAllUsers);
	
	GetCurrentSettings(
		SetClosingDatesInDatabase, IndicationMethodInDatabase, AdditionalParameters);
	
	// Notify the user.
	NotificationText2 = "";
	If IsAllUsers(CurrentUser) And IndicationMethodInDatabase = "" Then
		IndicationMethodInDatabase = "SingleDate";
	EndIf;
	
	If PeriodEndClosingDateSettingMethod <> IndicationMethodInDatabase
	   And (SetPeriodEndClosingDates = SetClosingDatesInDatabase
	      Or IsAllUsers(CurrentUser) ) Then
		
		ListItem = Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(IndicationMethodInDatabase);
		If ListItem = Undefined Then
			IndicationMethodInDatabasePresentation = IndicationMethodInDatabase;
		Else
			IndicationMethodInDatabasePresentation = ListItem.Presentation;
		EndIf;
		
		If IndicationMethodInDatabasePresentation <> "" Then
			NotificationText2 = NotificationText2 + MessageTextExcessSetting(
				PeriodEndClosingDateSettingMethod,
				IndicationMethodInDatabasePresentation,
				CurrentUser,
				ThisObject);
		EndIf;
	EndIf;
	
	Return NotificationText2;
	
EndFunction

&AtServerNoContext
Procedure GetCurrentSettings(SetPeriodEndClosingDates, IndicationMethod, Val Parameters)
	
	SetPeriodEndClosingDates = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	IndicationMethod = CurrentClosingDateIndicationMethod(
		Parameters.User,
		Parameters.SingleSection,
		Parameters.ValueForAllUsers,
		Parameters.BegOfDay);
	
EndProcedure

&AtServerNoContext
Function CurrentSettingOfPeriodEndClosingDate(DataImportRestrictionDates)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("DataImportRestrictionDates", DataImportRestrictionDates);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS HasProhibitions
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	(PeriodClosingDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
		|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
		|					THEN &DataImportRestrictionDates = FALSE
		|				ELSE &DataImportRestrictionDates = TRUE
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS ForSpecifiedUsers
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	(PeriodClosingDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
		|					THEN &DataImportRestrictionDates = FALSE
		|				ELSE &DataImportRestrictionDates = TRUE
		|			END)
		|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Enum.PeriodClosingDatesPurposeTypes)";
		
		QueryResults = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If QueryResults[0].IsEmpty() Then
		CurrentSettingOfClosingDates = "ForAllUsers";
		
	ElsIf QueryResults[1].IsEmpty() Then
		CurrentSettingOfClosingDates = "ForAllUsers";
	Else
		CurrentSettingOfClosingDates = "ForSpecifiedUsers";
	EndIf;
	
	Return CurrentSettingOfClosingDates;
	
EndFunction

&AtServer
Procedure SetVisibility1()
	
	ChangeVisibility(Items.ClosingDateSetting, True);
	If Parameters.DataImportRestrictionDates Then
		If SetPeriodEndClosingDates = "ForAllUsers" Then
			ExtendedTooltip = NStr("en = 'Data import restriction dates from other applications are applied the same way for all users.';");
		Else
			ExtendedTooltip = NStr("en = 'Custom setup of data import restriction dates of previous periods from other applications for selected users.';");
		EndIf;
	Else
		If SetPeriodEndClosingDates = "ForAllUsers" Then
			ExtendedTooltip = NStr("en = 'Dates of restriction of entering and editing previous period data are applied the same way for all users.';");
		Else
			ExtendedTooltip = NStr("en = 'Custom setup of period-end closing dates of previous periods for the selected users.';");
		EndIf;
	EndIf;
	If Not IsBlankString(GoToOtherClosingDates) Then
		ExtendedTooltip = ExtendedTooltip + Chars.LF + GoToOtherClosingDates;
	EndIf;	
	Items.SetClosingDateNote.Title = StringFunctions.FormattedString(ExtendedTooltip);
	
	If SetPeriodEndClosingDates <> "ForAllUsers" Then
		ChangeVisibility(Items.SpecifedUsersList, True);
		Items.CurrentUserPresentation.ShowTitle = True;
	Else
		ChangeVisibility(Items.SpecifedUsersList, False);
		Items.CurrentUserPresentation.ShowTitle = False;
	EndIf;
	
	If SetPeriodEndClosingDates <> "ForSpecifiedUsers" Then
		Items.UserData.CurrentPage = Items.UserSelectedPage;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeVisibility(Item, Visible)
	
	If Item.Visible <> Visible Then
		Item.Visible = Visible;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeSettingOfPeriodEndClosingDate(Val ValueSelected, Val DeleteExtra)
	
	If DeleteExtra Then
		
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("DataImportRestrictionDates",
				Parameters.DataImportRestrictionDates);
			
			If ValueSelected = "ForAllUsers" Then
				Query.SetParameter("KeepForAllUsers", True);
			Else
				Query.SetParameter("DataImportRestrictionDates", Undefined);
			EndIf;
			
			Query.Text =
			"SELECT
			|	PeriodClosingDates.Section,
			|	PeriodClosingDates.Object,
			|	PeriodClosingDates.User
			|FROM
			|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
			|WHERE
			|	(PeriodClosingDates.User = UNDEFINED
			|			OR CASE
			|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
			|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
			|					THEN &DataImportRestrictionDates = FALSE
			|				ELSE &DataImportRestrictionDates = TRUE
			|			END)
			|	AND CASE
			|			WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Enum.PeriodClosingDatesPurposeTypes)
			|				THEN &KeepForAllUsers = FALSE
			|			ELSE TRUE
			|		END";
			RecordKeysValues = Query.Execute().Unload();
			
			// Lock records to delete.
			For Each RecordKeyValues In RecordKeysValues Do
				// 
				LockUserRecordAtServer(LocksAddress,
					RecordKeyValues.Section,
					RecordKeyValues.Object,
					RecordKeyValues.User);
			EndDo;
			
			// Delete locked records.
			For Each RecordKeyValues In RecordKeysValues Do
				// 
				DeleteUserRecord(LocksAddress,
					RecordKeyValues.Section,
					RecordKeyValues.Object,
					RecordKeyValues.User);
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			UnlockAllRecordsAtServer(LocksAddress);
			Raise;
		EndTry;
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
	ReadUsers();
	ErrorText = "";
	ReadUserData(ThisObject, ErrorText);
	If ValueIsFilled(ErrorText) Then
		Common.MessageToUser(ErrorText);
	EndIf;
	
	SetVisibility1();
	
EndProcedure

&AtServerNoContext
Function CurrentClosingDateIndicationMethod(Val User, Val SingleSection, Val ValueForAllUsers, Val BegOfDay, Data = Undefined)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",                 User);
		Query.SetParameter("SingleSection",           SingleSection);
		Query.SetParameter("DateEmpty",                   '00010101');
		Query.SetParameter("ValueForAllUsers", ValueForAllUsers);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND NOT(PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|				AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object <> PeriodClosingDates.Section
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Section <> &SingleSection
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Section = PeriodClosingDates.Object";
		
		QueryResults = Query.ExecuteBatch();
		
		CurrentClosingDateIndicationMethod = "";
		
		Query.Text =
		"SELECT
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User
		|	AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)";
		Selection = Query.Execute().Select();
		SingleDateIsRead = Selection.Next();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Data = Undefined Then
		Data = New Structure;
		Data.Insert("PeriodEndClosingDateDetails", "");
		Data.Insert("PeriodEndClosingDate", '00010101');
		Data.Insert("PermissionDaysCount", 0);
		Data.Insert("RecordExists", SingleDateIsRead);
	EndIf;
	
	If SingleDateIsRead Then
		Data.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
			Selection.PeriodEndClosingDateDetails, Selection.PeriodEndClosingDate, BegOfDay);
		FillByInternalDetailsOfPeriodEndClosingDate(Data, Selection.PeriodEndClosingDateDetails);
	EndIf;
	
	If QueryResults[0].IsEmpty() Then
		// 
		CurrentClosingDateIndicationMethod = ?(SingleDateIsRead, "SingleDate", "");
		
	ElsIf Not QueryResults[1].IsEmpty() Then
		// Exists by objects, when it is not blank.
		
		If QueryResults[2].IsEmpty()
		   And ValueIsFilled(SingleSection) Then
			// 
			CurrentClosingDateIndicationMethod = "ByObjects";
		Else
			CurrentClosingDateIndicationMethod = "BySectionsAndObjects";
		EndIf;
	Else
		CurrentClosingDateIndicationMethod = "BySections";
	EndIf;
	
	Return CurrentClosingDateIndicationMethod;
	
EndFunction

&AtServer
Procedure DeleteExtraOnChangePeriodEndClosingDateIndicationMethod(Val ValueSelected, Val CurrentUser, Val SetPeriodEndClosingDates)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.PeriodClosingDates");
		LockItem.SetValue("User", CurrentUser);
		Block.Lock();
		
		RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		RecordSet.Filter.User.Set(CurrentUser);
		RecordSet.Read();
		
		IndexOf = RecordSet.Count()-1;
		While IndexOf >= 0 Do
			Record = RecordSet[IndexOf];
			If  ValueSelected = "SingleDate" Then
				If Not (  Record.Section = SectionEmptyRef
						 And Record.Object = SectionEmptyRef ) Then
					RecordSet.Delete(Record);
				EndIf;
			ElsIf ValueSelected = "BySections" Then
				If Record.Section <> Record.Object
				 Or Record.Section = SectionEmptyRef
				   And Record.Object = SectionEmptyRef Then
					RecordSet.Delete(Record);
				EndIf;
			ElsIf ValueSelected = "ByObjects" Then
				If Record.Section = Record.Object
				   And Record.Section <> SectionEmptyRef
				   And Record.Object <> SectionEmptyRef Then
					RecordSet.Delete(Record);
				EndIf;
			EndIf;
			IndexOf = IndexOf-1;
		EndDo;
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
		
	ErrorText = "";
	ReadUserData(ThisObject, ErrorText);
	If ValueIsFilled(ErrorText) Then
		Common.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPeriodEndClosingDateInForm()
	
	SelectedRows = Items.ClosingDates.SelectedRows;
	// Canceling selection of section rows with objects.
	IndexOf = SelectedRows.Count()-1;
	UpdateSelection = False;
	While IndexOf >= 0 Do
		String = ClosingDates.FindByID(SelectedRows[IndexOf]);
		If Not ValueIsFilled(String.Presentation) Then
			SelectedRows.Delete(IndexOf);
			UpdateSelection = True;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'The selected lines are not filled in.';"));
		Return;
	EndIf;
	
	If UpdateSelection Then
		Items.ClosingDates.Refresh();
		ShowMessageBox(
			New NotifyDescription("EditPeriodEndClosingDateInFormCompletion", ThisObject, SelectedRows),
			NStr("en = 'Unfilled lines are unchecked.';"));
	Else
		EditPeriodEndClosingDateInFormCompletion(SelectedRows)
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPeriodEndClosingDateInFormCompletion(SelectedRows) Export
	
	// Locking records of the selected rows.
	For Each SelectedRow In SelectedRows Do
		CurrentData = ClosingDates.FindByID(SelectedRow);
		// 
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			CurrentSection(CurrentData), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndDo;
	
	// Changing description of a period-end closing date.
	FormParameters = New Structure;
	FormParameters.Insert("UserPresentation", "");
	FormParameters.Insert("SectionPresentation", "");
	FormParameters.Insert("Object", "");
	If SetPeriodEndClosingDates = "ForSpecifiedUsers" Then
		FormParameters.UserPresentation = Items.Users.CurrentData.Presentation;
	Else
		FormParameters.UserPresentation = PresentationTextForAllUsers(ThisObject);
	EndIf;
	
	CurrentData = Items.ClosingDates.CurrentData;
	FormParameters.Insert("PeriodEndClosingDateDetails", CurrentData.PeriodEndClosingDateDetails);
	FormParameters.Insert("PermissionDaysCount", CurrentData.PermissionDaysCount);
	FormParameters.Insert("PeriodEndClosingDate", CurrentData.PeriodEndClosingDate);
	FormParameters.Insert("RecordExists", CurrentData.RecordExists);
	FormParameters.Insert("NoClosingDatePresentation", NoClosingDatePresentation(CurrentData));
	
	If SelectedRows.Count() = 1 Then
		If CurrentData.IsSection Then
			FormParameters.SectionPresentation = CurrentData.Presentation;
		Else
			FormParameters.Object = CurrentData.Object;
			If PeriodEndClosingDateSettingMethod <> "ByObjects" Then
				FormParameters.SectionPresentation = CurrentData.GetParent().Presentation;
			EndIf;	
		EndIf;
	Else
		FormParameters.Object = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Selected lines (%1)';"), SelectedRows.Count());
	EndIf;
	
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodEndClosingDateEdit",
		FormParameters, ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFieldsToCalculate(Val Data)
	
	For Each DataString1 In Data Do
		SetClosingDateDetailsPresentation(DataString1);
		For Each DataString1 In DataString1.GetItems() Do
			SetClosingDateDetailsPresentation(DataString1);
		EndDo;	
	EndDo;	
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetClosingDateDetailsPresentation(Val Data)
	
	// Presentation of the period-end closing date value that is not set.
	If Not ValueIsFilled(Data.PeriodEndClosingDate) And Not Data.RecordExists Then
		Data.PeriodEndClosingDateDetailsPresentation = NoClosingDatePresentation(Data);
		If Not IsBlankString(Data.PeriodEndClosingDateDetailsPresentation) Then
			Return;
		EndIf;
	EndIf;
	
	Presentation = PeriodClosingDatesInternalClientServer.ClosingDatesDetails()[Data.PeriodEndClosingDateDetails];
	If Data.PermissionDaysCount > 0 Then
		Presentation = Presentation + " (" + Format(Data.PermissionDaysCount, "NG=") + ")";
	EndIf;
	Data.PeriodEndClosingDateDetailsPresentation = Presentation;
	
EndProcedure

&AtClientAtServerNoContext
Function NoClosingDatePresentation(Data)
	
	If Data.IsSection And Not Data.Section.IsEmpty() Then
		Return NStr("en = 'Common date for all sections';");
	ElsIf Not Data.IsSection Then	
		SectionData = Data.GetParent();
		If SectionData = Undefined Then
			Return "";
		ElsIf Not ValueIsFilled(SectionData.PeriodEndClosingDate) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Common date for section %1';"), SectionData.Presentation);
		Else	
			Return SectionData.PeriodEndClosingDateDetailsPresentation + " (" + SectionData.Presentation + ")";
		EndIf;
	EndIf;
	Return ""; 
		
EndFunction	

&AtClientAtServerNoContext
Function InternalPeriodEndClosingDate(Data)
	
	If ValueIsFilled(Data.PeriodEndClosingDateDetails)
	   And Data.PeriodEndClosingDateDetails <> "Custom" Then
		
		Return '39990202'; // The relative period-end closing date.
	EndIf;
	
	Return Data.PeriodEndClosingDate;
	
EndFunction

&AtClientAtServerNoContext
Function InternalDetailsOfPeriodEndClosingDate(Val Data)
	
	InternalDetails = "";
	If Data.PeriodEndClosingDateDetails <> "Custom" Then
		InternalDetails = TrimAll(
			Data.PeriodEndClosingDateDetails + Chars.LF
				+ Format(Data.PermissionDaysCount, "NG=0"));
	EndIf;
	
	Return InternalDetails;
	
EndFunction

&AtClientAtServerNoContext
Procedure FillByInternalDetailsOfPeriodEndClosingDate(Val Data, Val InternalDetails)
	
	Data.PeriodEndClosingDateDetails = "Custom";
	Data.PermissionDaysCount = 0;
	
	If ValueIsFilled(InternalDetails) Then
		PeriodEndClosingDateDetails = StrGetLine(InternalDetails, 1);
		PermissionDaysCount = StrGetLine(InternalDetails, 2);
		If PeriodClosingDatesInternalClientServer.ClosingDatesDetails()[PeriodEndClosingDateDetails] = Undefined Then
			Data.PeriodEndClosingDate = '39990303'; // 
		Else
			Data.PeriodEndClosingDateDetails = PeriodEndClosingDateDetails;
			If ValueIsFilled(PermissionDaysCount) Then
				TypeDescriptionNumber = New TypeDescription("Number",,,
					New NumberQualifiers(2, 0, AllowedSign.Nonnegative));
				Data.PermissionDaysCount = TypeDescriptionNumber.AdjustValue(PermissionDaysCount);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function IsAllUsers(User)
	
	Return TypeOf(User) = Type("EnumRef.PeriodClosingDatesPurposeTypes");
	
EndFunction

&AtClientAtServerNoContext
Function PeriodEndClosingDateSet(Data, User, BeforeWrite = False)
	
	If Not BeforeWrite Then
		Return Data.RecordExists;
	EndIf;
	
	If Data.Object <> Data.Section And Not ValueIsFilled(Data.Object) Then
		Return False;
	EndIf;
	
	Return Data.PeriodEndClosingDateDetails <> ""
	      And Not (Data.PeriodEndClosingDateDetails = "Custom"
	            And Data.PeriodEndClosingDate = '00010101');
	
EndFunction

&AtServerNoContext
Procedure LockAndWriteBlankDates(LocksAddress, Section, Object, User, Comment)
	
	If TypeOf(Object) = Type("Array") Then
		ObjectsForAdding = Object;
	Else
		ObjectsForAdding = New Array;
		ObjectsForAdding.Add(Object);
	EndIf;
	
	For Each CurrentObject In ObjectsForAdding Do
		// 
		LockUserRecordAtServer(LocksAddress,
			Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject In ObjectsForAdding Do
		RecordPeriodEndClosingDateWithDetails(
			Section,
			CurrentObject,
			User,
			'00010101',
			"",
			Comment);
	EndDo;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetCommandBarOfClosingDates(Form)
	
	Items = Form.Items;
	
	If IsAllUsers(Form.CurrentUser) Then
		If Form.PeriodEndClosingDateSettingMethod = "BySections" Then
			// ClosingDatesWithoutSectionsSelectionWithoutObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, False);
			SetProperty(Items.ClosingDatesAdd.Visible,  False);
			SetProperty(Items.ClosingDatesContextMenuAdd.Visible, False);
		Else
			// ClosingDatesWithoutSectionsSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.ClosingDatesContextMenuAdd.Visible, True);
		EndIf;
	Else
		If Form.PeriodEndClosingDateSettingMethod = "BySections" Then
			// ClosingDatesWithSectionsSelectionWithoutObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, False);
			SetProperty(Items.ClosingDatesAdd.Visible,  False);
			SetProperty(Items.ClosingDatesContextMenuAdd.Visible, False);
			
		ElsIf Form.PeriodEndClosingDateSettingMethod = "ByObjects" Then
			// ClosingDatesWithCommonDateSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.ClosingDatesContextMenuAdd.Visible, True);
		Else
			// ClosingDatesWithSectionsSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.ClosingDatesContextMenuAdd.Visible, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetProperty(Property, Value)
	If Property <> Value Then
		Property = Value;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function CurrentUserComment(Form)
	
	If Form.SetPeriodEndClosingDates = "ForSpecifiedUsers" Then
		Return Form.Items.Users.CurrentData.Comment;
	EndIf;
	
	Return "";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClientAtServerNoContext
Function PresentationTextForAllUsers(Form)
	
	Return "<" + Form.ValueForAllUsers + ">";
	
EndFunction

&AtClientAtServerNoContext
Function UserPresentationText(Form, User)
	
	If Form.Parameters.DataImportRestrictionDates Then
		For Each ListValue In Form.UserTypesList Do
			If TypeOf(ListValue.Value) = TypeOf(User) Then
				If ValueIsFilled(User) Then
					Return ListValue.Presentation + ": " + String(User);
				Else
					Return ListValue.Presentation + ": " + NStr("en = '<All infobases>';");
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(User) Then
		Return String(User);
	EndIf;
	
	Return String(TypeOf(User));
	
EndFunction

&AtClientAtServerNoContext
Function CommonDatePresentationText()
	
	Return "<" + NStr("en = 'Common date for all sections';") + ">";
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextExcessSetting(IndicationMethodInForm, IndicationMethodInDatabase, CurrentUser, Form)
	
	If IndicationMethodInForm = "BySections" Or IndicationMethodInForm = "BySectionsAndObjects" Then
		If IsAllUsers(CurrentUser) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'No sections have effective period-end closing dates.
					|A general setting %1 will be applied to all users.';"),
				IndicationMethodInDatabase);
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'No sections have effective period-end closing dates.
					|A general setting %1 will be applied to %2.';"),
				CurrentUser, IndicationMethodInDatabase);
		EndIf;
	Else // ByObjects
		If IsAllUsers(CurrentUser) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'No objects have effective period-end closing dates.
					|A general setting %1 will be applied to all users.';"),
				IndicationMethodInDatabase);
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'No objects have effective period-end closing dates.
					|A general setting %1 will be applied to %2.';"),
				CurrentUser, IndicationMethodInDatabase);
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function MessageTextInSelectedSectionClosingDatesForObjectsNotSet(Section)
	
	Return ?(Section <> SectionEmptyRef, 
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Period-end closing date setting is not available for separate objects in the ""%1"" section.';"), Section),
		NStr("en = 'To set a period-end closing date for particular objects, select one of the sections below, and then click Pick.';"));
	
EndFunction

&AtClientAtServerNoContext
Function HeaderTextDataTypeSelection()
	
	Return NStr("en = 'Select data type';");
	
EndFunction

#EndRegion
