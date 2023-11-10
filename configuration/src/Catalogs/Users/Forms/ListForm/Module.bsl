///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

////////////////////////////////////////////////////////////////////////////////
//                          
//
// See UsersOverridable.OnDefineUsersSelectionForm
//

#Region Variables

&AtClient
Var LastItem;

&AtClient
Var SearchStringText;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// The initial setting value (before loading data from the settings).
	SelectHierarchy = True;
	Items.ChoiceCommandBarGroup.Visible = False;
	
	StoredParameters = StoredParameters();
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
	ElsIf Users.IsFullUser() Then
		// 
		CommonClientServer.SetDynamicListFilterItem(
			UsersList, "Prepared", True, ,
			NStr("en = 'Users are submitted for authorization';"), False,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	// If the parameter value is True, hiding users with empty IDs.
	If Parameters.HideUsersWithoutMatchingIBUsers Then
		CommonClientServer.SetDynamicListFilterItem(
			UsersList,
			"IBUserID",
			CommonClientServer.BlankUUID(),
			DataCompositionComparisonType.NotEqual);
	EndIf;
	
	// Hiding internal users.
	If Users.IsFullUser() Then
		CommonClientServer.SetDynamicListFilterItem(
			UsersList, "IsInternal", False, , , True,
			DataCompositionSettingsItemViewMode.Normal,
			String(New UUID));
	Else
		CommonClientServer.SetDynamicListFilterItem(
			UsersList, "IsInternal", False, , , True);
	EndIf;
	
	// Hiding the user passed from the user selection form.
	If TypeOf(Parameters.UsersToHide) = Type("ValueList") Then
		
		DCComparisonType = DataCompositionComparisonType.NotInList;
		CommonClientServer.SetDynamicListFilterItem(
			UsersList,
			"Ref",
			Parameters.UsersToHide,
			DCComparisonType);
		
	EndIf;
	
	ApplyConditionalAppearanceAndHideInvalidUsers();
	SetUpUserListParametersForSetPasswordCommand();
	SetAllUsersGroupOrder(UserGroups);
	
	Items.SelectedUsersAndGroups.Visible = StoredParameters.AdvancedPick;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If Not Users.IsFullUser(, Not DataSeparationEnabled) Then
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.UsersInfo.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
	
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.UsersInfo.Visible = False;
		Items.UserGroups.ChoiceMode = StoredParameters.UsersGroupsSelection;
		// 
		Items.UsersList.EnableStartDrag = False;
		
		If Parameters.Property("NonExistingIBUsersIDs") Then
			CommonClientServer.SetDynamicListFilterItem(
				UsersList, "IBUserID",
				Parameters.NonExistingIBUsersIDs,
				DataCompositionComparisonType.InList, , True,
				DataCompositionSettingsItemViewMode.Inaccessible);
		EndIf;
		
		If Parameters.CloseOnChoice = False Then
			// 
			Items.UsersList.MultipleChoice = True;
			
			If StoredParameters.AdvancedPick Then
				StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "AdvancedPick");
				ChangeExtendedPickFormParameters();
				Items.CommandBar.Visible = False;
				Items.EndAndCloseChoice.DefaultButton = True;
				Items.ChoiceCommandBarGroup.Visible = True;
				Items.UsersList.SearchOnInput = SearchInTableOnInput.DontUse;
				Items.UserGroups.SearchOnInput = SearchInTableOnInput.DontUse;
				CurrentItem = Items.SelectedUsersAndGroupsList;
				Items.EndAndClose.Title = NStr("en = 'Complete and close';");
			EndIf;
			
			If StoredParameters.UsersGroupsSelection Then
				Items.UserGroups.MultipleChoice = True;
			EndIf;
		EndIf;
	Else
		Items.UsersList.ChoiceMode  = False;
		Items.UserGroups.ChoiceMode = False;
		Items.Comments.Visible = False;
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectUser", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectUsersGroup", "Visible", False);
	EndIf;
	
	ConfigureUserGroupsUsageForm();
	StoredParameters.Delete("CurrentRow");
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
	 Or Not Users.IsFullUser()
	 Or Common.IsStandaloneWorkplace() Then
		
		Items.FormChangeSelectedItems.Visible = False;
		Items.UsersListContextMenuChangeSelectedItems.Visible = False;
	EndIf;
	
	ObjectDetails = New Structure;
	ObjectDetails.Insert("Ref", Catalogs.Users.EmptyRef());
	ObjectDetails.Insert("IBUserID", CommonClientServer.BlankUUID());
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(ObjectDetails);
	
	If Not AccessLevel.ListManagement Then
		Items.FormSetPassword.Visible = False;
		Items.UsersListContextMenuSetPassword.Visible = False;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
		Items.UserGroups.ReadOnly = True;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.EndAndClose.Representation = ButtonRepresentation.Picture;
	EndIf;
	
	SelectConversationParticipants = CommonClientServer.StructureProperty(Parameters, "SelectConversationParticipants", False);
	
	If Not Common.SubsystemExists("StandardSubsystems.ImportDataFromFile") Then
		Items.PasteFromClipboard.Visible = False;
	EndIf; 
	
	AddressUserWithoutPhoto = PutToTempStorage(PictureLib.UserWithoutPhoto, UUID);
	PhotoAddress = PutToTempStorage(Undefined, UUID);
	FillContactInformation(ThisObject, Undefined);
	SetTitleOfSelectedUsersAndGroups();
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		 Items.LockInvalidUsersInCollaborationSystem.Visible = True;
	EndIf;
	
	UsersInternal.SetUpFieldDynamicListPicNum(UsersList);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.ChoiceMode Then
		CurrentFormItemModificationCheck();
	EndIf;
	
#If MobileClient Then
	If StoredParameters.UseGroups Then
		Items.GroupsGroup.Title = ?(Items.UserGroups.CurrentData = Undefined,
			NStr("en = 'User groups';"),
			String(Items.UserGroups.CurrentData.Ref));
	EndIf;
#EndIf
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_UserGroups")
	   And Source = Items.UserGroups.CurrentRow
	 Or Upper(EventName) = Upper("ArrangeUsersInGroups")
	 Or Upper(EventName) = Upper("Write_AccessGroups") Then
		
		Items.UsersList.Refresh();
		
	ElsIf Upper(EventName) = Upper("Write_ConstantsSet") Then
		If Upper(Source) = Upper("UseUserGroups") Then
			AttachIdleHandler("UserGroupsUsageOnChange", 0.1, True);
		EndIf;
		
	ElsIf Upper(EventName) = Upper("Write_Users") Then
		AttachIdleHandler("UpdateUserContactInformationCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeImportingDataFromSettingsAtServer(Settings)
	
	If TypeOf(Settings["SelectHierarchy"]) = Type("Boolean") Then
		SelectHierarchy = Settings["SelectHierarchy"];
	EndIf;
	
	If Not SelectHierarchy Then
		RefreshFormContentOnGroupChange(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectHierarchyOnChange(Item)
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowInvalidUsers1OnChange(Item)
	ToggleInvalidUsersVisibility(ShowInvalidUsers);
EndProcedure

&AtClient
Procedure SearchStringEditTextChange(Item, Text, StandardProcessing)
	SearchStringText = Text;
	AttachIdleHandler("SearchStringCompletion", 0.1, True);
EndProcedure

&AtClient
Procedure SearchStringCompletion()

	If Not ValueIsFilled(SearchStringText) Then
		Items.UsersSelectionPages.CurrentPage = Items.UsersAndGroupsSelectionPage;
	Else
		Items.UsersSelectionPages.CurrentPage = Items.SearchPage;
	EndIf;

	
	If StoredParameters.UseGroups Then
		UpdateDataCompositionParameterValue(UsersList,
			"AllUsers", True);
	EndIf;
	
	SetTheSelectionOfTheListOfUsersByTheSearchBar(SearchStringText);
		
EndProcedure

&AtServer
Procedure SetTheSelectionOfTheListOfUsersByTheSearchBar(SearchStringText)

	SelectionByContactInformation = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT DISTINCT
		|	UsersContactInformation.Ref AS Ref
		|FROM
		|	Catalog.Users.ContactInformation AS UsersContactInformation
		|WHERE
		|	UsersContactInformation.Presentation LIKE &SearchString ESCAPE ""~""";
		
		Query.SetParameter("SearchString", Common.GenerateSearchQueryString(SearchStringText) + "%");
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		While SelectionDetailRecords.Next() Do
			SelectionByContactInformation.Add(SelectionDetailRecords.Ref);
		EndDo;
		
	EndIf;
		
	UseFilter1 = ValueIsFilled(SearchStringText);
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(UsersList.Filter,
		"SearchByRow",
		DataCompositionFilterItemsGroupType.OrGroup);
		
	CommonClientServer.AddCompositionItem(FilterGroup,
		"Ref",
		DataCompositionComparisonType.InList,
		SelectionByContactInformation,,
		UseFilter1);
		
	CommonClientServer.AddCompositionItem(FilterGroup,
		"Description",
		DataCompositionComparisonType.Contains,
		SearchStringText,,
		UseFilter1);
		
	Items.UsersListSearch.Refresh();
EndProcedure

&AtClient
Procedure SearchStringClearing(Item, StandardProcessing)
	SearchStringText = "";
	Items.UsersSelectionPages.CurrentPage = Items.UsersAndGroupsSelectionPage;
	
	SelectionGroups = CommonClientServer.FindFilterItemsAndGroups(UsersList.Filter,,
		"SearchByRow");

	For Each FilterGroup In SelectionGroups Do
		FilterGroup.Use = False;
	EndDo;
			
	RefreshFormContentOnGroupChange(ThisObject);		
EndProcedure

#EndRegion

#Region UserGroupsFormTableItemEventHandlers

&AtClient
Procedure UsersGroupsOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure UsersGroupsOnActivateRow(Item)
	
	AttachIdleHandler("UserGroupsAfterActivateRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not StoredParameters.AdvancedPick Then
		NotifyChoice(Value);
	Else
		GetPicturesAndFillSelectedItemsList(Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersGroupsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	If Not Copy Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.UserGroups.CurrentRow) Then
			FormParameters.Insert(
				"FillingValues",
				New Structure("Parent", Items.UserGroups.CurrentRow));
		EndIf;
		
		OpenForm(
			"Catalog.UserGroups.ObjectForm",
			FormParameters,
			Items.UserGroups);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersGroupsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If SelectHierarchy Then
		ShowMessageBox(,
			NStr("en = 'To allow dragging users to groups, clear the
			           |""Show users that belong to subgroups"" check box.';"));
		Return;
	EndIf;
	
	If Items.UserGroups.CurrentRow = String
		Or String = Undefined Then
		Return;
	EndIf;
	
	If DragParameters.Action = DragAction.Move Then
		Move = True;
	Else
		Move = False;
	EndIf;
	
	GroupMarkedForDeletion = Items.UserGroups.RowData(String).DeletionMark;
	UsersCount = DragParameters.Value.Count();
	ActionExcludeUser = (StoredParameters.AllUsersGroup = String);
	AddToGroup = (StoredParameters.AllUsersGroup = Items.UserGroups.CurrentRow);
	
	If UsersCount = 1 Then
		If ActionExcludeUser Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to remove user ""%1"" from group ""%2""?';"),
				String(DragParameters.Value[0]),
				String(Items.UserGroups.CurrentRow));
			
		ElsIf Not GroupMarkedForDeletion Then
			If AddToGroup Then
				Template = NStr("en = 'Do you want to add user ""%1"" to group ""%2""?';");
			ElsIf Move Then
				Template = NStr("en = 'Do you want to move user ""%1"" to group ""%2""?';");
			Else
				Template = NStr("en = 'Do you want to copy user ""%1"" to group ""%2""?';");
			EndIf;
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				String(DragParameters.Value[0]),
				String(String));
		Else
			If AddToGroup Then
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to add user ""%2"" to the group?';");
			ElsIf Move Then
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to move user ""%2"" to the group?';");
			Else
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to copy user ""%2"" to the group?';");
			EndIf;
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				String(String),
				String(DragParameters.Value[0]));
			
		EndIf;
	Else
		If ActionExcludeUser Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to remove %1 users from group ""%2""?';"),
				UsersCount,
				String(Items.UserGroups.CurrentRow));
			
		ElsIf Not GroupMarkedForDeletion Then
			If AddToGroup Then
				Template = NStr("en = 'Do you want to add %1 users to group ""%2""?';");
			ElsIf Move Then
				Template = NStr("en = 'Do you want to move %1 users to group ""%2""?';");
			Else
				Template = NStr("en = 'Do you want to copy %1 users to group ""%2""?';");
			EndIf;
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				UsersCount,
				String(String));
		Else
			If AddToGroup Then
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to add %2 users to the group?';");
			ElsIf Move Then
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to move %2 users to the group?';");
			Else
				Template = NStr("en = 'Group ""%1"" is marked for deletion. Do you want to copy %2 users to the group?';");
			EndIf;
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				String(String),
				UsersCount);
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DragParameters", DragParameters.Value);
	AdditionalParameters.Insert("String", String);
	AdditionalParameters.Insert("Move", Move);
	
	Notification = New NotifyDescription("UsersGroupsDragCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure UsersGroupsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If Items.UserGroups.ReadOnly Then
		DragParameters.AllowedActions = DragAllowedActions.DontProcess;
	Else
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region UsersListFormTableItemEventHandlers

&AtClient
Procedure UsersListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure UsersListOnActivateRow(Item)
	
	If StandardSubsystemsClient.IsDynamicListItem(Items.UsersList) Then
		CanChangePassword = Items.UsersList.CurrentData.CanChangePassword;
	Else
		CanChangePassword = False;
	EndIf;
	
	Items.FormSetPassword.Enabled = CanChangePassword;
	Items.UsersListContextMenuSetPassword.Enabled = CanChangePassword;
	
	// StandardSubsystems.AttachableCommands
	If Not StoredParameters.AdvancedPick Then
	
		If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
			ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
			ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
		EndIf;
	
	EndIf;
	
	// End StandardSubsystems.AttachableCommands
	
	UpdateUserContactInformation(Item);
	
EndProcedure

&AtClient
Procedure UsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not StoredParameters.AdvancedPick Then
		NotifyChoice(Value);
	Else
		GetPicturesAndFillSelectedItemsList(Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("NewUserGroup", Items.UserGroups.CurrentRow);
	
	If Copy And Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm("Catalog.Users.ObjectForm", FormParameters, Items.UsersList);
	
EndProcedure

&AtClient
Procedure UsersListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Not ValueIsFilled(Item.CurrentRow) Then
		Return;
	EndIf;
	
	FormParameters = New Structure("Key", Item.CurrentRow);
	OpenForm("Catalog.Users.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtServerNoContext
Procedure UsersListOnGetDataAtServer(TagName, Settings, Rows)
	
	UsersInternal.DynamicListOnGetDataAtServer(TagName, Settings, Rows);
	
EndProcedure

&AtClient
Procedure UsersListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region SelectedUsersAndGroupsListFormTableItemEventHandlers

&AtClient
Procedure SelectedUsersAndGroupsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	DeleteFromSelectedItems();
	SelectedUsersListLastModified = True;
	
EndProcedure

&AtClient
Procedure SelectedUsersAndGroupsListOnStartEdit(Item, NewRow, Copy)
	
	If NewRow And Not Copy Then
		Item.CurrentData.User = PredefinedValue("Catalog.Users.EmptyRef");
		Item.CurrentData.PictureNumber = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedUsersAndGroupsListOnEditEnd(Item, NewRow, CancelEdit)
	
	SelectedUsersListLastModified = True;
	
EndProcedure

&AtClient
Procedure SelectedUsersAndGroupsListOnActivateRow(Item)
	
	UpdateUserContactInformation(Item);
	
EndProcedure

#EndRegion

#Region UsersListSearchFormTableItemEventHandlers

&AtClient
Procedure UsersListSearchOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	UpdateUserContactInformation(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateUsersGroup(Command)
	
	Items.UserGroups.AddRow();
	
EndProcedure

&AtClient
Procedure AssignGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("Users", Items.UsersList.SelectedRows);
	FormParameters.Insert("ExternalUsers", False);
	
	OpenForm("CommonForm.UserGroups", FormParameters);
	
EndProcedure

&AtClient
Procedure SetPassword(Command)
	
	CurrentData = Items.UsersList.CurrentData;
	
	If StandardSubsystemsClient.IsDynamicListItem(CurrentData) Then
		UsersInternalClient.OpenChangePasswordForm(CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndAndClose(Command)
	
	If StoredParameters.AdvancedPick Then
		UsersArray = SelectionResult();
		NotifyChoice(UsersArray);
		SelectedUsersListLastModified = False;
		Close(UsersArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectUserCommand(Command)
	
	If Items.UsersSelectionPages.CurrentPage = Items.SearchPage Then
		UsersArray = Items.UsersListSearch.SelectedRows;
	Else	
		UsersArray = Items.UsersList.SelectedRows;
	EndIf;
	
	GetPicturesAndFillSelectedItemsList(UsersArray);
	
EndProcedure

&AtClient
Procedure CancelUserOrGroupSelection(Command)
	
	DeleteFromSelectedItems();
	
EndProcedure

&AtClient
Procedure ClearSelectedUsersAndGroupsList(Command)
	
	DeleteFromSelectedItems(True);
	
EndProcedure

&AtClient
Procedure SelectGroup(Command)
	
	GroupsArray1 = Items.UserGroups.SelectedRows;
	GetPicturesAndFillSelectedItemsList(GroupsArray1);
	
EndProcedure

&AtClient
Procedure UsersInfo(Command)
	
	OpenForm(
		"Report.UsersInfo.ObjectForm",
		New Structure("VariantKey", "UsersInfo"),
		ThisObject,
		"UsersInfo");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ChangeSelectedItems(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchObjectsModificationClient.ChangeSelectedItems(Items.UsersList, UsersList);
	EndIf;
	
EndProcedure

&AtClient
Procedure PasteFromClipboard(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", New TypeDescription("CatalogRef.Users"));
	SearchParameters.Insert("ChoiceParameters", New ValueList);
	SearchParameters.Insert("FieldPresentation", Title);
	SearchParameters.Insert("Scenario", "RefsSearch");
	
	ExecutionParameters = New Structure;
	Handler = New NotifyDescription("PasteFromClipboardCompletion", ThisObject, ExecutionParameters);
	
	ModuleDataImportFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleDataImportFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

&AtClient
Procedure PasteFromClipboardCompletion(FoundObjects, ExecutionParameters) Export
	
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	
	PasteFromClipboardCompletionServer(FoundObjects);
	
EndProcedure

&AtServer
Procedure PasteFromClipboardCompletionServer(FoundObjects)

	For Each Value In FoundObjects Do
		SelectedUsersAndGroups.Add().User = Value;
	EndDo;
	Users.FillUserPictureNumbers(SelectedUsersAndGroups, "User", "PictureNumber");

EndProcedure

&AtClient
Procedure Select(Command)
	If Items.UsersSelectionPages.CurrentPage = Items.UsersAndGroupsSelectionPage Then
	    UsersListValueChoice(Items.UsersList,
			SelectedListValues(Items.UsersList),
			False);
	Else	
		UsersListValueChoice(Items.UsersListSearch,
			SelectedListValues(Items.UsersListSearch),
			False);
	EndIf;
EndProcedure

&AtClient
Procedure LockInvalidUsersInCollaborationSystem(Command)
	ProcessingResult = BlockInvalidUsersInTheInteractionSystemOnTheServer();
	If Not IsBlankString(ProcessingResult) Then
		MessageTemplate = NStr("en = 'Cannot lock users due to:
			|
			|%1';");
		ShowMessageBox(,
			StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ProcessingResult),,
			NStr("en = 'Cannot lock users';"));
	Else
		Status(NStr("en = 'Invalid users are
			|locked.';"),,,PictureLib.Success32);
	EndIf;
EndProcedure

&AtServer
Function BlockInvalidUsersInTheInteractionSystemOnTheServer()
	Result = "";
	ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
	InvalidUsers = ModuleConversationsInternal.InvalidUsers();
	For Each InvalidUser In InvalidUsers Do
		BlockingResult = ModuleConversationsInternal.BlockAnInteractionSystemUser(InvalidUser);
		If BlockingResult <> Undefined Then
			Result = ErrorProcessing.BriefErrorDescription(BlockingResult);
			WriteLogEvent(NStr("en = 'Conversations.Lock invalid users';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorProcessing.DetailErrorDescription(BlockingResult));
		EndIf;
	EndDo;
	Return Result;
EndFunction

#EndRegion

#Region Private

&AtClient
Function SelectedListValues(Item)
	Result = New Array;
	
	RowsSelected = CommonClientServer.FormItemPropertyValue(Items, Item.Name, "SelectedRows");
	If RowsSelected <> Undefined Then
	
		For Each RowID In RowsSelected Do
			Result.Add(Item.RowData(RowID).Ref);
		EndDo;
	
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure UpdateUserContactInformation(ItemList)
	
	CurrentData = ItemList.CurrentData;
	If CurrentData = Undefined Then
		FillContactInformation(ThisObject, Undefined);
		Return;
	EndIf;
	
	If ItemList = Items.SelectedUsersAndGroupsList Then
		CurrentUser = CurrentData.User;
	ElsIf Not StandardSubsystemsClient.IsDynamicListItem(ItemList) Then
		FillContactInformation(ThisObject, Undefined);
		Return;
	Else
		CurrentUser = CurrentData.Ref;
	EndIf;
	
	AttachIdleHandler("UpdateUserContactInformationCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure UpdateUserContactInformationCompletion()
	FillContactInformation(ThisObject, CurrentUser);
EndProcedure

&AtClientAtServerNoContext
Procedure FillContactInformation(Form, CurrentUser)
	If Not ValueIsFilled(CurrentUser) Then
		Form.ContactInformationPresentation = "";
		Form.PhotoAddress = Form.AddressUserWithoutPhoto;
		Return;
	EndIf;
	
	UserContactInformation = ?(ValueIsFilled(CurrentUser),
		UserContactInformation(CurrentUser, Form.AddressUserWithoutPhoto, Form.UUID),
		New Structure);
	Form.PhotoAddress = CommonClientServer.StructureProperty(
		UserContactInformation,
		"Photo",
		Form.AddressUserWithoutPhoto);
	
	Template = NStr("en = '%1
	|
	|Phone: %2
	|Email: %3';");
	
	Department = CommonClientServer.StructureProperty(UserContactInformation, "Department", "");
	UserName = CommonClientServer.StructureProperty(UserContactInformation, "Description", "");
	UserPresentation2 = ?(ValueIsFilled(UserName), UserName,"")
		+ ?(ValueIsFilled(Department), Chars.LF + Department, "");
		
	Form.ContactInformationPresentation = StringFunctionsClientServer.SubstituteParametersToString(Template,
		UserPresentation2,
		CommonClientServer.StructureProperty(UserContactInformation, "Phone", ""),
		CommonClientServer.StructureProperty(UserContactInformation, "Email", ""));
EndProcedure

&AtServerNoContext
Function UserContactInformation(User, DefaultPhotoAddress, UUID)
	ContactInformation = UsersInternal.UserDetails(User);
	If ContactInformation.Photo <> Undefined Then
		ContactInformation.Photo = PutToTempStorage(ContactInformation.Photo, UUID);
	Else
		ContactInformation.Photo = DefaultPhotoAddress;
	EndIf;
	
	Return ContactInformation;
EndFunction

// Returns:
//  Structure:
//   * UsersGroupsSelection - Boolean
//   * AdvancedPick - Boolean
//   * UseGroups - Arbitrary
//   * AllUsersGroup - CatalogRef.UserGroups
//   * CurrentRow - 
//   * PickFormHeader - String
//   * PickingCompletionButtonTitle - String
//
&AtServer
Function StoredParameters()
	
	Result = New Structure;
	Result.Insert("UsersGroupsSelection", Parameters.UsersGroupsSelection);
	Result.Insert("AdvancedPick", Parameters.AdvancedPick);
	Result.Insert("UseGroups", GetFunctionalOption("UseUserGroups"));
	Result.Insert("AllUsersGroup", Catalogs.UserGroups.AllUsers);
	Result.Insert("CurrentRow", Parameters.CurrentRow);
	Result.Insert("PickFormHeader", "");
	Result.Insert("PickingCompletionButtonTitle", "");
	Return Result;
	
EndFunction

&AtServer
Procedure ApplyConditionalAppearanceAndHideInvalidUsers()
	
	AppearanceItem = UsersList.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceColorItem = AppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField("Invalid");
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	FilterElement.Use  = True;
	
	CommonClientServer.SetDynamicListFilterItem(
		UsersList, "Invalid", False, , , True);
	
EndProcedure

&AtServer
Procedure SetAllUsersGroupOrder(List)
	
	Var Order;
	
	// Order
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Predefined");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure

&AtServer
Procedure SetUpUserListParametersForSetPasswordCommand()
	
	UpdateDataCompositionParameterValue(UsersList, "CurrentIBUserID",
		InfoBaseUsers.CurrentUser().UUID);
	
	UpdateDataCompositionParameterValue(UsersList, "BlankUUID",
		CommonClientServer.BlankUUID());
	
	UpdateDataCompositionParameterValue(UsersList, "CanChangeOwnPasswordOnly",
		Not Users.IsFullUser());
	
EndProcedure

&AtClient
Procedure CurrentFormItemModificationCheck()
	
	If CurrentItem <> LastItem Then
		CurrentFormItemOnChange();
		LastItem = CurrentItem;
	EndIf;
	
#If WebClient Then
	AttachIdleHandler("CurrentFormItemModificationCheck", 0.7, True);
#Else
	AttachIdleHandler("CurrentFormItemModificationCheck", 0.1, True);
#EndIf
	
EndProcedure

&AtClient
Procedure CurrentFormItemOnChange()
	
	If CurrentItem = Items.UserGroups Then
		Items.Comments.CurrentPage = Items.CommentOfGroup;
		
	ElsIf CurrentItem = Items.UsersList Then
		Items.Comments.CurrentPage = Items.UserComment;
		
	EndIf
	
EndProcedure

&AtServer
Procedure DeleteFromSelectedItems(DeleteAll1 = False)
	
	If DeleteAll1 Then
		SelectedUsersAndGroups.Clear();
		Return;
	EndIf;
	
	ListItemsArray = Items.SelectedUsersAndGroupsList.SelectedRows;
	For Each ListItem In ListItemsArray Do
		SelectedUsersAndGroups.Delete(SelectedUsersAndGroups.FindByID(ListItem));
	EndDo;
	
EndProcedure

&AtClient
Procedure GetPicturesAndFillSelectedItemsList(SelectedItemsArray)
	
	SelectedItemsAndPictures = New Array;
	For Each SelectedElement In SelectedItemsArray Do
		
		If TypeOf(SelectedElement) = Type("CatalogRef.Users") Then
			PictureNumber = Items.UsersList.RowData(SelectedElement).PictureNumber;
		Else
			PictureNumber = Items.UserGroups.RowData(SelectedElement).PictureNumber;
		EndIf;
		
		SelectedItemsAndPictures.Add(
			New Structure("SelectedElement, PictureNumber", SelectedElement, PictureNumber));
	EndDo;
	
	FillSelectedUsersAndGroupsList(SelectedItemsAndPictures);
	
EndProcedure

&AtServer
Function SelectionResult()
	UsersArray = New Array;
	
	SelectedUsersValueTable = SelectedUsersAndGroups.Unload( , "User");
	If SelectConversationParticipants And Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversations = Common.CommonModule("Conversations");
		ParticipantsIDs = ModuleConversations.CollaborationSystemUsers(SelectedUsersValueTable.UnloadColumn("User"));
		For Each UserID2 In ParticipantsIDs Do
		
			If UserID2.Value <> Undefined Then
				UsersArray.Add(UserID2.Value.ID);
			EndIf;
		
		EndDo;
	Else
		UsersArray = SelectedUsersValueTable.UnloadColumn("User");
	EndIf;
	
	Return UsersArray;
EndFunction

&AtServer
Procedure ChangeExtendedPickFormParameters()
	
	// Loading the list of selected users.
	If ValueIsFilled(Parameters.ExtendedPickFormParameters) Then
		ExtendedPickFormParameters = GetFromTempStorage(Parameters.ExtendedPickFormParameters);
	Else
		ExtendedPickFormParameters = Parameters;
	EndIf;
	If TypeOf(ExtendedPickFormParameters.SelectedUsers) = Type("ValueTable") Then
		SelectedUsersAndGroups.Load(ExtendedPickFormParameters.SelectedUsers);
	Else
		For Each SelectedUser In ExtendedPickFormParameters.SelectedUsers Do
			SelectedUsersAndGroups.Add().User = SelectedUser;
		EndDo;
	EndIf;
	Users.FillUserPictureNumbers(SelectedUsersAndGroups, "User", "PictureNumber");
	StoredParameters.PickFormHeader = ExtendedPickFormParameters.PickFormHeader;
	
	If ExtendedPickFormParameters.Property("PickingCompletionButtonTitle") Then 
		StoredParameters.PickingCompletionButtonTitle = ExtendedPickFormParameters.PickingCompletionButtonTitle;
	EndIf;
	
	// 
	Items.EndAndClose.Visible         = True;
	Items.SelectUserGroup.Visible = True;
	// 
	Items.SelectedUsersAndGroups.Visible     = True;
	
	If Common.IsMobileClient() Then
		Items.GroupsAndUsers.Group                 = ChildFormItemsGroup.Vertical;
		Items.GroupsAndUsers.DisplayImportance      = DisplayImportance.VeryHigh;
		Items.ContentGroup.Group                    = ChildFormItemsGroup.AlwaysHorizontal;
		Items.SelectGroupGroup.Visible                   = False;
		Items.SelectUserGroup.Visible             = False;
		Items.Move(Items.SelectedUsersAndGroups, Items.ContentGroup, Items.SelectedUsersAndGroups);
	ElsIf GetFunctionalOption("UseUserGroups") Then
		Items.GroupsAndUsers.Group                 = ChildFormItemsGroup.Vertical;
		Items.UsersList.Height                       = 5;
		Items.UserGroups.Height                      = 3;
		Height                                        = 17;
		Items.SelectGroupGroup.Visible                   = True;
		// 
		Items.UserGroups.TitleLocation          = FormItemTitleLocation.Top;
		Items.UsersList.TitleLocation           = FormItemTitleLocation.Top;
		Items.UsersList.Title                    = NStr("en = 'Users in group';");
		If ExtendedPickFormParameters.Property("CannotPickGroups") Then
			Items.SelectGroup.Visible                     = False;
		EndIf;
	Else
		Items.CancelUserSelection.Visible             = True;
		Items.ClearSelectedItemsList.Visible               = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTitleOfSelectedUsersAndGroups()
	
	If StoredParameters.UseGroups Then
		Items.SelectedUsersAndGroupsList.Title = NStr("en = 'Selected users and groups';");
	Else
		Items.SelectedUsersAndGroupsList.Title = NStr("en = 'Selected users';");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSelectedUsersAndGroupsList(SelectedItemsAndPictures)
	
	UsersInternal.SelectGroupUsers(
		SelectedItemsAndPictures, StoredParameters, Items.UsersList);
	
	For Each ArrayRow In SelectedItemsAndPictures Do
		
		SelectedUserOrGroup = ArrayRow.SelectedElement;
		PictureNumber = ArrayRow.PictureNumber;
		
		FilterParameters = New Structure("User", SelectedUserOrGroup);
		Found3 = SelectedUsersAndGroups.FindRows(FilterParameters);
		If Found3.Count() = 0 Then
			
			SelectedUsersRow = SelectedUsersAndGroups.Add();
			SelectedUsersRow.User = SelectedUserOrGroup;
			SelectedUsersRow.PictureNumber = PictureNumber;
			SelectedUsersListLastModified = True;
			
		EndIf;
		
	EndDo;
	
	SelectedUsersAndGroups.Sort("User Asc");
	
EndProcedure

&AtClient
Procedure UserGroupsUsageOnChange()
	
	ConfigureUserGroupsUsageForm(True);
	
EndProcedure

&AtServer
Procedure ConfigureUserGroupsUsageForm(GroupUsageChanged = False)
	
	If GroupUsageChanged Then
		StoredParameters.UseGroups = GetFunctionalOption("UseUserGroups");
	EndIf;
	
	CurrentStoredParameters = StoredParameters; // See StoredParameters
	If CurrentStoredParameters.Property("CurrentRow") Then
		
		If TypeOf(CurrentStoredParameters.CurrentRow) = Type("CatalogRef.UserGroups") Then
			
			If StoredParameters.UseGroups Then
				Items.UserGroups.CurrentRow = CurrentStoredParameters.CurrentRow;
			Else
				Parameters.CurrentRow = Undefined;
			EndIf;
		ElsIf Not StoredParameters.AdvancedPick
		     Or TypeOf(CurrentStoredParameters.CurrentRow) = Type("CatalogRef.Users") Then
			
			CurrentItem = Items.UsersList;
			Items.UserGroups.CurrentRow = Catalogs.UserGroups.AllUsers;
		EndIf;
	Else
		If Not StoredParameters.UseGroups
		   And Items.UserGroups.CurrentRow
		     <> Catalogs.UserGroups.AllUsers Then
			
			Items.UserGroups.CurrentRow = Catalogs.UserGroups.AllUsers;
		EndIf;
	EndIf;
	
	Items.SelectHierarchy.Visible = StoredParameters.UseGroups;
	
	If Not AccessRight("Edit", Metadata.Catalogs.UserGroups)
	 Or StoredParameters.AdvancedPick
	 Or Common.IsStandaloneWorkplace() Then
		
		Items.AssignGroups.Visible = False;
		Items.UsersListContextMenuAssignGroups.Visible = False;
	Else
		Items.AssignGroups.Visible = StoredParameters.UseGroups;
		Items.UsersListContextMenuAssignGroups.Visible =
			StoredParameters.UseGroups;
	EndIf;
	
	Items.CreateUsersGroup.Visible =
		AccessRight("Insert", Metadata.Catalogs.UserGroups)
		And StoredParameters.UseGroups
		And Not Common.IsStandaloneWorkplace();
	
	UsersGroupsSelection = StoredParameters.UsersGroupsSelection
	                        And StoredParameters.UseGroups
	                        And Parameters.ChoiceMode;
	
	If Parameters.ChoiceMode Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectUsersGroup", "Visible", ?(StoredParameters.AdvancedPick,
				False, UsersGroupsSelection));
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectUser", "DefaultButton", ?(StoredParameters.AdvancedPick,
				False, Not UsersGroupsSelection));
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectUser", "Visible", Not StoredParameters.AdvancedPick);
		
		AutoTitle = False;
		
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			
			If UsersGroupsSelection Then
				
				If StoredParameters.AdvancedPick Then
					Title = StoredParameters.PickFormHeader;
				Else
					Title = NStr("en = 'Pick users and groups';");
				EndIf;
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectUser", "Title", NStr("en = 'Select users';"));
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectUsersGroup", "Title", NStr("en = 'Select groups';"));
			Else
				
				If StoredParameters.AdvancedPick Then
					Title = StoredParameters.PickFormHeader;
					
					If Not IsBlankString(StoredParameters.PickingCompletionButtonTitle) Then
						CommonClientServer.SetFormItemProperty(Items,
							"EndAndCloseChoice", "Title", StoredParameters.PickingCompletionButtonTitle);
					EndIf;
					
				Else
					Title = NStr("en = 'Pick users';");
				EndIf;
				
			EndIf;
			
		Else
			// Selection mode.
			If UsersGroupsSelection Then
				Title = NStr("en = 'Select user or group';");
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectUser", "Title", NStr("en = 'Select user';"));
			Else
				Title = NStr("en = 'Select user';");
			EndIf;
		EndIf;
	EndIf;
	
	RefreshFormContentOnGroupChange(ThisObject);
	
	// 
	// 
	Items.UserGroups.Visible = False;
	Items.UserGroups.Visible = True;
	
EndProcedure

&AtClient
Procedure UserGroupsAfterActivateRow()
	
	RefreshFormContentOnGroupChange(ThisObject);
	
	If Items.UsersList.CurrentData = Undefined Then
		CurrentUser = Undefined;
		FillContactInformation(ThisObject, Undefined);
	EndIf;
	
#If MobileClient Then
	If Not StoredParameters.AdvancedPick Then
		Items.GroupsGroup.Title = ?(Items.UserGroups.CurrentData = Undefined,
			NStr("en = 'User groups';"),
			String(Items.UserGroups.CurrentData.Ref));
		CurrentItem = Items.UsersList;
	EndIf;
#EndIf

EndProcedure

&AtServer
Function MoveUserToNewGroup(UsersArray, NewParentGroup, Move)
	
	If NewParentGroup = Undefined Then
		Return Undefined;
	EndIf;
	
	CurrentParentGroup = Items.UserGroups.CurrentRow;
	UserMessage = UsersInternal.MoveUserToNewGroup(
		UsersArray, CurrentParentGroup, NewParentGroup, Move);
	
	Items.UsersList.Refresh();
	Items.UserGroups.Refresh();
	
	Return UserMessage;
	
EndFunction

// A question handler.
//
// Parameters:
//  Response - DialogReturnCode
//  AdditionalParameters - Structure:
//    * DragParameters - Array of CatalogRef.Users
//    * String - String
//    * Move - Boolean
//
&AtClient
Procedure UsersGroupsDragCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	UserMessage = MoveUserToNewGroup(
		AdditionalParameters.DragParameters,
		AdditionalParameters.String,
		AdditionalParameters.Move);
	
	If UserMessage.Message = Undefined Then
		Return;
	EndIf;
	
	If UserMessage.HasErrors = False Then
		ShowUserNotification(
			NStr("en = 'Move users';"), , UserMessage.Message, PictureLib.Information32);
	Else
		ShowMessageBox(,UserMessage.Message);
	EndIf;
	
	Notify("Write_UserGroups");
	
EndProcedure

&AtClient
Procedure ToggleInvalidUsersVisibility(ShowInvalidUsers)
	
	CommonClientServer.SetDynamicListFilterItem(
		UsersList, "Invalid", False, , ,
		Not ShowInvalidUsers);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshFormContentOnGroupChange(Form)
	
	Items = Form.Items;
	AllUsersGroup = PredefinedValue(
		"Catalog.UserGroups.AllUsers");
	If Not ValueIsFilled(Form.CurrentUser) Then
		Form.PhotoAddress = Form.AddressUserWithoutPhoto;
	EndIf;
	
	
	If Not Form.StoredParameters.UseGroups
	 Or Items.UserGroups.CurrentRow = AllUsersGroup Then
		
		UpdateDataCompositionParameterValue(Form.UsersList,
			"AllUsers", True);
		
		UpdateDataCompositionParameterValue(Form.UsersList,
			"SelectHierarchy", False);
		
		UpdateDataCompositionParameterValue(Form.UsersList,
			"UsersGroup", AllUsersGroup);
	Else
		UpdateDataCompositionParameterValue(Form.UsersList,
			"AllUsers", False);
		
		UpdateDataCompositionParameterValue(Form.UsersList,
			"SelectHierarchy", Form.SelectHierarchy);
		
		UpdateDataCompositionParameterValue(Form.UsersList,
			"UsersGroup", Items.UserGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateDataCompositionParameterValue(Val ParametersOwner,
                                                    Val ParameterName,
                                                    Val ParameterValue)
	
	For Each Parameter In ParametersOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			
			If Parameter.Use
			   And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
	ParametersOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.StartAccessUpdate();
	EndIf;
	
EndProcedure

// Standard subsystems.Pluggable commands

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.UsersList);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.UsersList);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.UsersList);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion