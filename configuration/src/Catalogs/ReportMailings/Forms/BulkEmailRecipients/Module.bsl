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
	
	FillPropertyValues(ThisObject, Parameters, "MailingRecipientType, RecipientsEmailAddressKind");
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report recipients (%1)';"),
		Parameters.MailingDescription);
	
	For Each TableRow In Parameters.Recipients Do
		NewRow = Recipients.Add();
		NewRow.Recipient = TableRow.Recipient;
		NewRow.Excluded = TableRow.Excluded;
	EndDo;
	
	Items.RecipientsRecipient.TypeRestriction = MailingRecipientType;
	
	FillRecipientsTypeInfo(Cancel);
	FillMailAddresses();
	
	If Not Common.SubsystemExists("StandardSubsystems.ImportDataFromFile") Then
		Items.PasteFromClipboard.Visible = False;
	EndIf;
	
	RefreshRecipientCount(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RecipientsEmailAddressKindOnChange(Item)
	FillMailAddresses();
EndProcedure

#EndRegion

#Region RecipientsFormTableItemEventHandlers

&AtClient
Procedure PickRecipients(Command)
	OpenAddRecipientsForm(True);
EndProcedure

&AtClient
Procedure OpenAddRecipientsForm(IsPick)
	SelectedUsers = New Array;
	For Each String In Recipients Do
		SelectedUsers.Add(String.Recipient);
	EndDo;
	
	ChoiceFormParameters = New Structure;
	
	// 
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", ?(IsPick, False, True));
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", IsPick);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	
	// 
	ChoiceFormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("SelectGroups", True);
	ChoiceFormParameters.Insert("UsersGroupsSelection", True);
	
	// 
	// 
	If IsPick Then
		ChoiceFormParameters.Insert("AdvancedPick", True);
		ChoiceFormParameters.Insert("PickFormHeader", NStr("en = 'Pick recipients';"));
		ChoiceFormParameters.Insert("SelectedUsers", SelectedUsers);
	EndIf;
	
	OpenForm(ChoiceFormPath, ChoiceFormParameters, Items.Recipients);
EndProcedure

&AtClient
Procedure RecipientsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	AddDragRecipient(ValueSelected);
	RefreshRecipientCount(ThisObject);
EndProcedure

&AtClient
Procedure RecipientsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	OpenAddRecipientsForm(False);
EndProcedure

&AtClient
Procedure RecipientsExcludedOnChange(Item)
	RefreshRecipientCount(ThisObject);
EndProcedure

&AtClient
Procedure RecipientsAfterDeleteRow(Item)
	RefreshRecipientCount(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	Result = New Structure;
	Result.Insert("Recipients", Recipients);
	Result.Insert("RecipientsEmailAddressKind", RecipientsEmailAddressKind);
	Close(Result);
EndProcedure

&AtClient
Procedure PasteFromClipboard(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", MailingRecipientType);
	SearchParameters.Insert("ChoiceParameters", Undefined);
	SearchParameters.Insert("FieldPresentation", "Recipients");
	SearchParameters.Insert("Scenario", "RefsSearch");
	
	ExecutionParameters = New Structure;
	Handler = New NotifyDescription("PasteFromClipboardCompletion", ThisObject, ExecutionParameters);
	
	ModuleDataImportFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleDataImportFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

&AtClient
Procedure SelectCheckBoxes(Command)
	
	For Each Recipient In Recipients Do
		Recipient.Excluded = True;
	EndDo;
	
	RefreshRecipientCount(ThisObject);
	
EndProcedure

&AtClient
Procedure ClearCheckBoxes(Command)
	
	For Each Recipient In Recipients Do
		Recipient.Excluded = False;
	EndDo;
	
	RefreshRecipientCount(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AddDragRecipient(RecipientOrRecipientsSet)
	// Delete users who have been deleted in the pickup form or who are already in the list.
	If IsPickupUsersOrGroup(RecipientOrRecipientsSet) Then
		Count = Recipients.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			RecipientRow = Recipients.Get(ReverseIndex);
			
			IndexInArray = RecipientOrRecipientsSet.Find(RecipientRow.Recipient);
			If IndexInArray = Undefined Then
				Recipients.Delete(RecipientRow); // User is deleted in the pickup form.
			Else
				RecipientOrRecipientsSet.Delete(IndexInArray); // 
			EndIf;
		EndDo;
	EndIf;
	
	// Add selected rows.
	NewRowArray = ChoicePickupDragToTabularSection(RecipientOrRecipientsSet);
	
	// Prepare notification text.
	If NewRowArray.Count() > 0 Then
		If NewRowArray.Count() = 1 Then
			NotificationTitle = NStr("en = 'The user is added to the recipient list.';");
		Else
			NotificationTitle = NStr("en = 'The users are added to the recipient list.';");
		EndIf;
		
		NotificationText1 = "";
		For Each RecipientRow In NewRowArray Do
			NotificationText1 = NotificationText1 + ?(NotificationText1 = "", "", ", ") + RecipientRow;
		EndDo;
		ShowUserNotification(NotificationTitle,, NotificationText1, PictureLib.ExecuteTask);
		
		FillMailAddresses();
	EndIf;
EndProcedure

&AtClient
Function IsPickupUsersOrGroup(RecipientOrRecipientsSet)
	Return TypeOf(RecipientOrRecipientsSet) = Type("Array")
		And MailingRecipientType.ContainsType(Type("CatalogRef.Users"));
EndFunction

&AtClient
Function ChoicePickupDragToTabularSection(ValueSelected)
	NewRowArray = New Array;
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each PickingItem In ValueSelected Do
			Result = ChoicePickupDragItemToTabularSection(PickingItem);
			AddValueToNotificationArray(Result, NewRowArray);
		EndDo;
	Else
		Result = ChoicePickupDragItemToTabularSection(ValueSelected);
		AddValueToNotificationArray(Result, NewRowArray);
	EndIf;
	Return NewRowArray;
EndFunction

&AtClient
Procedure AddValueToNotificationArray(Text, NewRowArray)
	If ValueIsFilled(Text) Then
		NewRowArray.Add(Text);
	EndIf;
EndProcedure

&AtClient
Function ChoicePickupDragItemToTabularSection(AttributeValue)
	Filter = New Structure("Recipient", AttributeValue);
	FoundRows = Recipients.FindRows(Filter);
	
	If FoundRows.Count() > 0 Then
		Return Undefined;
	EndIf;
	
	String = Recipients.Add();
	String.Recipient = AttributeValue;
	
	Return AttributeValue;
EndFunction

&AtClient
Procedure PasteFromClipboardCompletion(Result, Parameter) Export

	If Result <> Undefined Then 
		For Each Recipient In Result Do 
			NewRow = Recipients.Add();
			NewRow.Recipient = Recipient;
		EndDo;
		
		FillMailAddresses();
	EndIf;
	

EndProcedure

&AtServer
Procedure FillMailAddresses()
	
	RecipientsParameters = New Structure("Ref, RecipientsEmailAddressKind, Personal, Recipients, MailingRecipientType");
	FillPropertyValues(RecipientsParameters, ThisObject);
	RecipientsParameters.Personal = False;
	RecipientsParameters.MailingRecipientType = MetadataObjectID;
	RecipientsParameters.Recipients = Recipients;
	
	BulkEmailRecipients = ReportMailing.GenerateMailingRecipientsList(RecipientsParameters);
	For Each BulkEmailRecipient In Recipients Do
		If BulkEmailRecipients.Count() = 0 Then
			If BulkEmailRecipient.Recipient = Undefined Then 
				Continue;
			EndIf;
		Else	
			RecipientEmailAddr = BulkEmailRecipients.Get(BulkEmailRecipient.Recipient);
			BulkEmailRecipient.Address = ?(RecipientEmailAddr <> Undefined, RecipientEmailAddr, "")
		EndIf;
		If BulkEmailRecipient.Recipient.IsFolder Or TypeOf(BulkEmailRecipient.Recipient) = Type("CatalogRef.UserGroups") Then
			BulkEmailRecipient.PictureIndex = 3;
		Else
			BulkEmailRecipient.PictureIndex = 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecipientsRecipient.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecipientsExcluded.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Recipients.Excluded");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", Metadata.StyleItems.OverdueDataColor.Value);

EndProcedure

&AtServer
Procedure FillRecipientsTypeInfo(Cancel)
	RecipientsTypesTable = ReportMailingCached.RecipientsTypesTable();
	FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
	If FoundItems.Count() = 1 Then
		RecipientRow = FoundItems[0];
		MetadataObjectID            = RecipientRow.MetadataObjectID;
		ChoiceFormPath                           = RecipientRow.ChoiceFormPath;
		ContactInformationOfRecipientsTypeGroup = RecipientRow.CIGroup;
		// CI group is used for the RecipientsEmailAddressKind field in the ChoiceParameterLinks.Filter.
	Else
		Cancel = True;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshRecipientCount(Form)

	NumberOfRecipients = RecipientsCountIncludingGroups(Form.Recipients,
		Form.MetadataObjectID);

	Form.ResultTotalCount = NumberOfRecipients.Total;
	Form.ResultExcludedCount = NumberOfRecipients.ExcludedCount;

EndProcedure

&AtServerNoContext
Function RecipientsCountIncludingGroups(Val Recipients, Val MetadataObjectID)

	Return Catalogs.ReportMailings.RecipientsCountIncludingGroups(Recipients, MetadataObjectID);

EndFunction

#EndRegion