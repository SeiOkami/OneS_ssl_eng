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
	
	If Not AccessRight("DataAdministration", Metadata) Then
		Raise NStr("en = 'Insufficient rights to configure automatic REST service';");
	EndIf;
	
	AuthorizationSettings = DataProcessors.SetUpStandardODataInterface.AuthorizationSettingsForStandardODataInterface();
	CreateStandardODataInterfaceUser = AuthorizationSettings.Used;
	
	If ValueIsFilled(AuthorizationSettings.Login) Then
		
		UserName = AuthorizationSettings.Login;
		If CreateStandardODataInterfaceUser Then
			
			CheckPasswordChange = String(New UUID());
			Password = CheckPasswordChange;
			PasswordConfirmation = CheckPasswordChange;
			
		EndIf;
		
	Else
		UserName = "odata.user";
	EndIf;
		
	SetVisibilityAndAvailability();
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not CreateStandardODataInterfaceUser Then
		Return;
	EndIf;
		
	CheckedAttributes.Add("UserName");
	CheckedAttributes.Add("Password");
	CheckedAttributes.Add("PasswordConfirmation");
	
	If Password <> PasswordConfirmation Then
		Common.MessageToUser(NStr("en = 'Password confirmation does not match password';"), , "PasswordConfirmation");
		Cancel = True;
	EndIf;
	
	If MetadataObjects.GetItems().Count() = 0 Then
		Common.MessageToUser(
			NStr("en = 'Objects that you can access via automatic REST service are not specified.';"),, 
			"MetadataObjects");
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Modified Then
		
		Cancel = True;
		
		NotifyDescription = New NotifyDescription("ContinueClosingAfterQuestion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The data has been changed. Do you want to save the changes?';"), QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MetadataObjectsUseOnChange(Item)
	
	If Items.MetadataObjects.CurrentData.Use Then
		Create = True;
		Dependencies = DependenciesToAddObject(Items.MetadataObjects.CurrentData.GetID());
	Else
		Create = False;
		Dependencies = DependenciesToDeleteObject(Items.MetadataObjects.CurrentData.GetID());
	EndIf;
	
	If Dependencies.Count() > 0 Then
		
		FormParameters = New Structure();
		FormParameters.Insert("FullObjectName", Items.MetadataObjects.CurrentData.FullName);
		FormParameters.Insert("ObjectDependencies", Dependencies);
		FormParameters.Insert("Create", Create);
		
		Context = New Structure();
		Context.Insert("Dependencies", Dependencies);
		Context.Insert("Create", Create);
		
		NotifyDescription = New NotifyDescription("MetadataObjectsUsageOnChangeFollowUp", ThisObject, Context);
		
		OpenForm("DataProcessor.SetUpStandardODataInterface.Form.MetadataObjectDependencies",
			FormParameters,,,,,	NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateStandardODataInterfaceUserOnChange(Item)
	
	SetVisibilityAndAvailability();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Function Save(Command = Undefined)
	
	ClearMessages();
	
	If Not Modified Then
		Return True;
	EndIf;
		
	If Not CheckFilling() Then
		Return False;
	EndIf;
	
	SaveAtServer();
	Return True;
	
EndFunction

&AtClient
Procedure SaveAndLoad(Command = Undefined)
	
	If Save() Then
		Close();
	EndIf;	
	
EndProcedure

&AtClient
Procedure ImportMetadata(Command)
	
	If Modified
		And MetadataObjects.GetItems().Count() > 0 Then
		
		Notification = New NotifyDescription("ImportMetadataFollowUp", ThisObject);
		ShowQueryBox(Notification, NStr("en = 'Import metadata again? The changes made will be lost.';"), QuestionDialogMode.YesNo);
		
	Else
		ImportMetadataFollowUp(DialogReturnCode.Yes, Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportMetadataFollowUp(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Result = StartPreparingSetupParameters();
	JobID = Result.JobID;
	If TypeOf(Result) = Type("Structure") 
		And Result.Status <> "Completed2" Then
		
		Notification = New NotifyDescription("SetupParametersReceivingCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(Result, Notification, TimeConsumingOperationsClient.IdleParameters(ThisObject));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueClosingAfterQuestion(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		SaveAndLoad();
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

// Parameters:
//   Result - DialogReturnCode
//             - Undefined
//   Context  - Structure
//
&AtClient
Procedure MetadataObjectsUsageOnChangeFollowUp(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		SetDependenciesUsage(Context.Dependencies, Context.Create);
	Else
		Items.MetadataObjects.CurrentData.Use = Not Items.MetadataObjects.CurrentData.Use;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetupParametersReceivingCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	If Result.Status <> "Completed2" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	
	StorageAddress = Result.ResultAddress;
	ImportSetupParameters();
	
EndProcedure

&AtServer
Procedure SetVisibilityAndAvailability()
	
	Items.UsernameAndPassword.Enabled = CreateStandardODataInterfaceUser;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	Item.Use = True;
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsUse");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjects.Root");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Show", False);
	
EndProcedure

&AtServer
Function DependenciesToAddObject(Val RowID)
	
	DependenciesTable = FormAttributeToValue("DependenciesForAdding");
	Return DependenciesForObject(RowID, DependenciesTable, True);
	
EndFunction

&AtServer
Function DependenciesToDeleteObject(Val RowID)
	
	DependenciesTable = FormAttributeToValue("DependenciesForDeletion");
	Return DependenciesForObject(RowID, DependenciesTable, False);
	
EndFunction

&AtServer
Function DependenciesForObject(Val RowID, DependenciesTable, UsageReferenceData)
	
	Result = New Array();
	
	CurrentObjectName = MetadataObjects.FindByID(RowID).FullName;
	
	ObjectsTree = FormAttributeToValue("MetadataObjects");
	
	FillRequiredObjectDependenciesByRow(Result, ObjectsTree, DependenciesTable, CurrentObjectName, UsageReferenceData);
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillRequiredObjectDependenciesByRow(Result, ObjectsTree, DependenciesTable, CurrentObjectName, UsageReferenceData)
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ObjectName", CurrentObjectName);
	
	DependenciesStrings = DependenciesTable.FindRows(FilterParameters);
	
	For Each DependencyString In DependenciesStrings Do
		
		DependentObjectInTree = ObjectsTree.Rows.Find(DependencyString.DependentObjectName, "FullName", True);
		
		If DependentObjectInTree.Use <> UsageReferenceData And Result.Find(DependencyString.DependentObjectName) = Undefined Then
			
			Result.Add(DependencyString.DependentObjectName);
			FillRequiredObjectDependenciesByRow(Result, ObjectsTree, DependenciesTable, 
				DependencyString.DependentObjectName, UsageReferenceData);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetDependenciesUsage(Val Dependencies, Val Use)
	
	RootItems = MetadataObjects.GetItems();
	For Each RootItem In RootItems Do
		
		TreeItems = RootItem.GetItems();
		For Each TreeItem In TreeItems Do
			
			If Dependencies.Find(TreeItem.FullName) <> Undefined Then
				TreeItem.Use = Use;
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SaveAtServer()
	
	BeginTransaction();
	
	Try
		
		Settings = New Structure();
		
		Settings.Insert("Used", CreateStandardODataInterfaceUser);
		Settings.Insert("Login", UserName);
		If CheckPasswordChange <> Password Then
			Settings.Insert("Password", Password);
		EndIf;
		
		DataProcessors.SetUpStandardODataInterface.WriteAuthorizationSettingsForStandardODataInterface(Settings);
		
		Content = New Array();
		Tree = FormAttributeToValue("MetadataObjects");
		Rows = Tree.Rows.FindRows(New Structure("Use", True), True);
		For Each String In Rows Do
			Content.Add(String.FullName);
		EndDo;
		
		SetStandardODataInterfaceContent(Content);
		
		Modified = False;
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure ImportSetupParameters()
	
	Data = GetFromTempStorage(StorageAddress);
	If TypeOf(Data) <> Type("Structure") Then
		Return;
	EndIf;
	
	ValueToFormAttribute(Data.ObjectsTree, "MetadataObjects");
	ValueToFormAttribute(Data.AdditionDependencies, "DependenciesForAdding");
	ValueToFormAttribute(Data.DeletionDependencies, "DependenciesForDeletion");
	
EndProcedure

&AtServer
Function StartPreparingSetupParameters()
	
	BackgroundExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	BackgroundExecutionParameters.BackgroundJobDescription = "PrepareStandardODataInterfaceContentSetupParameters";
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.SetUpStandardODataInterface.PrepareStandardODataInterfaceContentSetupParameters",
		New Structure,
		BackgroundExecutionParameters);
	
	StorageAddress = Result.ResultAddress;
	If Result.Status = "Completed2" Then
		ImportSetupParameters();
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion


