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
	
	UserRef             = Parameters.User;
	SettingsOperation           = Parameters.SettingsOperation;
	InfoBaseUser = DataProcessors.UsersSettings.IBUserName(UserRef);
	CurrentUserRef      = Users.CurrentUser();
	CurrentUser            = DataProcessors.UsersSettings.IBUserName(CurrentUserRef);
	
	SelectedSettingsPage = Items.SettingsKinds.CurrentPage.Name;
	
	PersonalSettingsFormName = 
		Common.CommonCoreParameters().PersonalSettingsFormName;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If DataSavedToSettingsStorage
	   And TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		
		Properties = New Structure("ClearSettingsSelectionHistory", False);
		FillPropertyValues(FormOwner, Properties);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Delete("Interface");
	Settings.Delete("ReportsSettings");
	Settings.Delete("OtherSettings");
	
	InterfaceTree       = FormAttributeToValue("Interface");
	ReportSettingsTree = FormAttributeToValue("ReportsSettings");
	OtherSettingsTree  = FormAttributeToValue("OtherSettings");
	
	MarkedInterfaceSettings = MarkedSettings(InterfaceTree);
	MarkedReportSettings      = MarkedSettings(ReportSettingsTree);
	MarkedOtherSettings       = MarkedSettings(OtherSettingsTree);
	
	Settings.Insert("MarkedInterfaceSettings", MarkedInterfaceSettings);
	Settings.Insert("MarkedReportSettings",      MarkedReportSettings);
	Settings.Insert("MarkedOtherSettings",       MarkedOtherSettings);
	
	DataSavedToSettingsStorage = True;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	AllSelectedSettings = New Structure;
	AllSelectedSettings.Insert("MarkedInterfaceSettings");
	AllSelectedSettings.Insert("MarkedReportSettings");
	AllSelectedSettings.Insert("MarkedOtherSettings");
	
	If Parameters.ClearSettingsSelectionHistory Then
		Settings.Clear();
		Return;
	EndIf;
	
	MarkedInterfaceSettings = Settings.Get("MarkedInterfaceSettings");
	MarkedReportSettings      = Settings.Get("MarkedReportSettings");
	MarkedOtherSettings       = Settings.Get("MarkedOtherSettings");
	
	AllSelectedSettings.MarkedInterfaceSettings = MarkedInterfaceSettings;
	AllSelectedSettings.MarkedReportSettings = MarkedReportSettings;
	AllSelectedSettings.MarkedOtherSettings = MarkedOtherSettings;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateSettingsList();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnCurrentPageChange(Item, CurrentPage)
	
	SelectedSettingsPage = CurrentPage.Name;
	
EndProcedure

&AtClient
Procedure SettingsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	UsersInternalClient.OpenReportOrForm(
		CurrentItem, InfoBaseUser, CurrentUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure CheckOnChange(Item)
	
	ChangeMark1(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateSettingsList();
	
EndProcedure

&AtClient
Procedure OpenSettingsItem(Command)
	
	UsersInternalClient.OpenReportOrForm(
		CurrentItem, InfoBaseUser, CurrentUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure SelectAllItems(Command)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		SettingsTree = ReportsSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		SettingsTree = Interface.GetItems();
		MarkTreeItems(SettingsTree, True);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearAllIetms(Command)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		SettingsTree = ReportsSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		SettingsTree = Interface.GetItems();
		MarkTreeItems(SettingsTree, False);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	Result = New Structure;
	
	SelectedInterfaceSettings    = SelectedSettings(Interface);
	SelectedReportSettings         = SelectedSettings(ReportsSettings);
	SelectedOtherSettingsStructure = SelectedSettings(OtherSettings);
	
	SettingsCount = SelectedInterfaceSettings.SettingsCount
	                   + SelectedReportSettings.SettingsCount
	                   + SelectedOtherSettingsStructure.SettingsCount;
	
	If SelectedReportSettings.SettingsCount = 1 Then
		SettingsPresentations = SelectedReportSettings.SettingsPresentations;
	ElsIf SelectedInterfaceSettings.SettingsCount = 1 Then
		SettingsPresentations = SelectedInterfaceSettings.SettingsPresentations;
	ElsIf SelectedOtherSettingsStructure.SettingsCount = 1 Then
		SettingsPresentations = SelectedOtherSettingsStructure.SettingsPresentations;
	EndIf;
	
	Result.Insert("Interface",       SelectedInterfaceSettings.SettingsArray);
	Result.Insert("ReportsSettings", SelectedReportSettings.SettingsArray);
	Result.Insert("OtherSettings",  SelectedOtherSettingsStructure.SettingsArray);
	
	Result.Insert("SettingsPresentations", SettingsPresentations);
	Result.Insert("SettingsCount",    SettingsCount);
	
	Result.Insert("ReportOptionTable",  UserReportOptionTable);
	Result.Insert("SelectedReportsOptions", SelectedReportSettings.ReportsOptions);
	
	Result.Insert("PersonalSettings",           SelectedOtherSettingsStructure.PersonalSettingsArray);
	Result.Insert("OtherUserSettings", SelectedOtherSettingsStructure.OtherUserSettings);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UpdateSettingsList()
	
	Items.CommandBar.Enabled = False;
	Items.TimeConsumingOperationPages.CurrentPage = Items.TimeConsumingOperationPage;
	Result = UpdatingSettingsList();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CompletionNotification2 = New NotifyDescription("UpdateSettingsListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(Result, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtServer
Function UpdatingSettingsList()
	
	If ExecutionResult <> Undefined
		And ValueIsFilled(ExecutionResult.JobID) Then
		TimeConsumingOperations.CancelJobExecution(ExecutionResult.JobID);
	EndIf;
	
	TimeConsumingOperationParameters = TimeConsumingOperationParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0; // 
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update user settings';");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground("UsersInternal.FillSettingsLists",
		TimeConsumingOperationParameters, ExecutionParameters);
	
	Return ExecutionResult;
	
EndFunction

&AtClient
Procedure UpdateSettingsListCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		FillSettings();
		ExpandValueTree();
		Items.TimeConsumingOperationPages.CurrentPage = Items.SettingsPage;
		Items.CommandBar.Enabled = True;
	ElsIf Result.Status = "Error" Then
		Items.TimeConsumingOperationPages.CurrentPage = Items.SettingsPage;
		Raise Result.BriefErrorDescription;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSettings()
	Result = GetFromTempStorage(ExecutionResult.ResultAddress);
	
	ValueToFormAttribute(Result.ReportSettingsTree, "ReportsSettings");
	ValueToFormAttribute(Result.UserReportOptions, "UserReportOptionTable");
	ValueToFormAttribute(Result.InterfaceSettings2, "Interface");
	ValueToFormAttribute(Result.OtherSettingsTree, "OtherSettings");
	
	If Not InitialSettingsImported 
		And AllSelectedSettings <> Undefined Then
		ImportMarkValues(ReportsSettings, AllSelectedSettings.MarkedReportSettings, "ReportsSettings");
		ImportMarkValues(Interface, AllSelectedSettings.MarkedInterfaceSettings, "Interface");
		ImportMarkValues(OtherSettings, AllSelectedSettings.MarkedOtherSettings, "OtherSettings");
		InitialSettingsImported = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ChangeMark1(Item)
	
	MarkedItem = Item.Parent.Parent.CurrentData;
	CheckMarkValue = MarkedItem.Check;
	
	If CheckMarkValue = 2 Then
		CheckMarkValue = 0;
		MarkedItem.Check = CheckMarkValue;
	EndIf;
	
	ItemParent = MarkedItem.GetParent();
	SubordinateItems = MarkedItem.GetItems();
	SettingsCount = 0;
	
	If ItemParent = Undefined Then
		
		For Each SubordinateItem In SubordinateItems Do
			
			If SubordinateItem.Check <> CheckMarkValue Then
				SettingsCount = SettingsCount + 1
			EndIf;
			
			SubordinateItem.Check = CheckMarkValue;
		EndDo;
		
		If SubordinateItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
	Else
		CheckSubordinateItemMarksAndMarkParent(ItemParent, CheckMarkValue);
		SettingsCount = SettingsCount + 1;
	EndIf;
	
	SettingsCount = ?(CheckMarkValue, SettingsCount, -SettingsCount);
	// Updating settings page title.
	RefreshPageTitle(SettingsCount);
	
EndProcedure

&AtClient
Procedure RefreshPageTitle(SettingsCount)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		
		ReportSettingsCount = ReportSettingsCount + SettingsCount;
		
		If ReportSettingsCount = 0 Then
			TitleText = NStr("en = 'Report settings';");
		Else
			TitleText = NStr("en = 'Report settings (%1)';");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, ReportSettingsCount);
		EndIf;
		
		Items.ReportSettingsPage.Title = TitleText;
		
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		
		InterfaceSettingsCount = InterfaceSettingsCount + SettingsCount;
		If InterfaceSettingsCount = 0 Then
			TitleText = NStr("en = 'Interface settings';");
		Else
			TitleText = NStr("en = 'Interface settings (%1)';");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, InterfaceSettingsCount);
		EndIf;
		
		Items.InterfacePage.Title = TitleText;
		
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		
		OtherSettingsCount = OtherSettingsCount + SettingsCount;
		If OtherSettingsCount = 0 Then
			TitleText = NStr("en = 'Other settings';");
		Else
			TitleText = NStr("en = 'Other settings (%1)';");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, OtherSettingsCount);
		EndIf;
		
		Items.OtherSettingsPage.Title = TitleText;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSubordinateItemMarksAndMarkParent(TreeItem, CheckMarkValue)
	
	HasUnmarkedItems = False;
	HasMarkedItems = False;
	
	SubordinateItems = TreeItem.GetItems();
	If SubordinateItems = Undefined Then
		TreeItem.Check = CheckMarkValue;
	Else
		
		For Each SubordinateItem In SubordinateItems Do
			
			If SubordinateItem.Check = 0 Then
				HasUnmarkedItems = True;
			ElsIf SubordinateItem.Check = 1 Then
				HasMarkedItems = True;
			EndIf;
			
		EndDo;
		
		If HasUnmarkedItems 
			And HasMarkedItems Then
			TreeItem.Check = 2;
		ElsIf HasMarkedItems Then
			TreeItem.Check = 1;
		Else
			TreeItem.Check = 0;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkTreeItems(SettingsTree, CheckMarkValue)
	
	SettingsCount = 0;
	For Each TreeItem In SettingsTree Do
		SubordinateItems = TreeItem.GetItems();
		
		For Each SubordinateItem In SubordinateItems Do
			
			SubordinateItem.Check = CheckMarkValue;
			SettingsCount = SettingsCount + 1;
			
		EndDo;
		
		If SubordinateItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
		TreeItem.Check = CheckMarkValue;
	EndDo;
	
	SettingsCount = ?(CheckMarkValue, SettingsCount, 0);
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		ReportSettingsCount = SettingsCount;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		InterfaceSettingsCount = SettingsCount;
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		OtherSettingsCount = SettingsCount;
	EndIf;
	
	RefreshPageTitle(0);
	
EndProcedure

&AtClient
Function SelectedSettings(SettingsTree)
	
	SettingsArray = New Array;
	PersonalSettingsArray = New Array;
	SettingsPresentations = New Array;
	ReportOptionArray = New Array;
	OtherUserSettings = New Array;
	SettingsCount = 0;
	
	For Each Setting In SettingsTree.GetItems() Do
		
		If Setting.Check = 1 Then
			
			If Setting.Type = "PersonalSettings" Then
				PersonalSettingsArray.Add(Setting.Keys);
			ElsIf Setting.Type = "OtherUserSettingsItem1" Then
				UserSettings = New Structure;
				UserSettings.Insert("SettingID", Setting.RowType);
				UserSettings.Insert("SettingValue", Setting.Keys);
				OtherUserSettings.Add(UserSettings);
			Else
				SettingsArray.Add(Setting.Keys);
				
				If Setting.Type = "PersonalOption" Then
					ReportOptionArray.Add(Setting.Keys);
				EndIf;
				
			EndIf;
			ChildItemCount = Setting.GetItems().Count();
			SettingsCount = SettingsCount + ?(ChildItemCount=0,1,ChildItemCount);
			
			If ChildItemCount = 1 Then
				
				ChildSettingsItem = Setting.GetItems()[0];
				SettingsPresentations.Add(Setting.Setting + " - " + ChildSettingsItem.Setting);
				
			ElsIf ChildItemCount = 0 Then
				SettingsPresentations.Add(Setting.Setting);
			EndIf;
			
		Else
			ChildSettings = Setting.GetItems();
			
			For Each ChildSettingsItem In ChildSettings Do
				
				If ChildSettingsItem.Check = 1 Then
					SettingsArray.Add(ChildSettingsItem.Keys);
					SettingsPresentations.Add(Setting.Setting + " - " + ChildSettingsItem.Setting);
					SettingsCount = SettingsCount + 1;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("SettingsArray", SettingsArray);
	SettingsStructure.Insert("PersonalSettingsArray", PersonalSettingsArray);
	SettingsStructure.Insert("OtherUserSettings", OtherUserSettings);
	SettingsStructure.Insert("ReportsOptions", ReportOptionArray);
	SettingsStructure.Insert("SettingsPresentations", SettingsPresentations);
	SettingsStructure.Insert("SettingsCount", SettingsCount);
	
	Return SettingsStructure;
	
EndFunction

&AtClient
Procedure ExpandValueTree()
	
	Rows = ReportsSettings.GetItems();
	For Each String In Rows Do 
		Items.ReportSettingsTree.Expand(String.GetID(), True);
	EndDo;
	
	Rows = Interface.GetItems();
	For Each String In Rows Do 
		Items.Interface.Expand(String.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Function TimeConsumingOperationParameters()
	
	TimeConsumingOperationParameters = New Structure;
	TimeConsumingOperationParameters.Insert("FormName");
	TimeConsumingOperationParameters.Insert("SettingsOperation");
	TimeConsumingOperationParameters.Insert("InfoBaseUser");
	TimeConsumingOperationParameters.Insert("UserRef");
	
	FillPropertyValues(TimeConsumingOperationParameters, ThisObject);
	
	TimeConsumingOperationParameters.Insert("ReportSettingsTree",          FormAttributeToValue("ReportsSettings"));
	TimeConsumingOperationParameters.Insert("InterfaceSettings2",           FormAttributeToValue("Interface"));
	TimeConsumingOperationParameters.Insert("OtherSettingsTree",           FormAttributeToValue("OtherSettings"));
	TimeConsumingOperationParameters.Insert("UserReportOptions", FormAttributeToValue("UserReportOptionTable"));
	
	Return TimeConsumingOperationParameters;
	
EndFunction

&AtServer
Function MarkedSettings(SettingsTree)
	
	MarkedItemList = New ValueList;
	MarkedItemFilter = New Structure("Check", 1);
	UndefinedItemFilter = New Structure("Check", 2);
	
	MarkedItemArray = SettingsTree.Rows.FindRows(MarkedItemFilter, True);
	For Each ArrayRow In MarkedItemArray Do
		MarkedItemList.Add(ArrayRow.RowType, , True);
	EndDo;
	
	UndefinedItemArray = SettingsTree.Rows.FindRows(UndefinedItemFilter, True);
	For Each ArrayRow In UndefinedItemArray Do
		MarkedItemList.Add(ArrayRow.RowType);
	EndDo;
	
	Return MarkedItemList;
	
EndFunction

&AtServer
Procedure ImportMarkValues(ValueTree, MarkedSettings, SettingsType)
	
	If MarkedSettings = Undefined Then
		Return;
	EndIf;
	MarkedItemCount = 0;
	
	For Each MarkedSettingsRow In MarkedSettings Do
		
		MarkedSetting = MarkedSettingsRow.Value;
		
		For Each TreeRow In ValueTree.GetItems() Do
			
			SubordinateItems = TreeRow.GetItems();
			
			If TreeRow.RowType = MarkedSetting Then
				
				If MarkedSettingsRow.Check Then
					TreeRow.Check = 1;
					
					If SubordinateItems.Count() = 0 Then
						MarkedItemCount = MarkedItemCount + 1;
					EndIf;
					
				Else
					TreeRow.Check = 2;
				EndIf;
				
			Else
				
				For Each SubordinateItem In SubordinateItems Do
					
					If SubordinateItem.RowType = MarkedSetting Then
						SubordinateItem.Check = 1;
						MarkedItemCount = MarkedItemCount + 1;
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If MarkedItemCount > 0 Then
		
		If SettingsType = "ReportsSettings" Then
			ReportSettingsCount = MarkedItemCount;
			Items.ReportSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Report settings (%1)';"), MarkedItemCount);
		ElsIf SettingsType = "Interface" Then
			InterfaceSettingsCount = MarkedItemCount;
			Items.InterfacePage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Interface settings (%1)';"), MarkedItemCount);
		ElsIf SettingsType = "OtherSettings" Then
			OtherSettingsCount = MarkedItemCount;
			Items.OtherSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Other settings (%1)';"), MarkedItemCount);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
