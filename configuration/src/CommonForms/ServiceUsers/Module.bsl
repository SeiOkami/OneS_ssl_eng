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
	
	// The form is not available until the preparation is finished.
	Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ServiceUserPassword = Undefined Then
		Cancel = True;
		StandardSubsystemsClient.SetFormStorageOption(ThisObject, True);
		AttachIdleHandler("RequestPasswordForAuthenticationInService", 0.1, True);
	Else
		PrepareForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetAll(Command)
	
	For Each TableRow In TableOfServiceUsers Do
		If TableRow.Access Then
			Continue;
		EndIf;
		TableRow.Add = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAllIetmsCommand(Command)
	
	For Each TableRow In TableOfServiceUsers Do
		TableRow.Add = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSelectedUsers(Command)
	
	AddSelectedUsersAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TableOfServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersFullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAccess.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("TableOfServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtClient
Procedure RequestPasswordForAuthenticationInService()
	
	StandardSubsystemsClient.SetFormStorageOption(ThisObject, False);
	
	UsersInternalClient.RequestPasswordForAuthenticationInService(
		New NotifyDescription("OnOpenFollowUp", ThisObject));
	
EndProcedure

&AtClient
Procedure OnOpenFollowUp(SaaSUserNewPassword, Context) Export
	
	If SaaSUserNewPassword <> Undefined Then
		ServiceUserPassword = SaaSUserNewPassword;
		Open();
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareForm()
	
	UsersInternalSaaS.GetActionsWithSaaSUser(
		Catalogs.Users.EmptyRef());
		
	UsersTable = UsersInternalSaaS.GetSaaSUsers(
		ServiceUserPassword);
		
	For Each UserInformation In UsersTable Do
		UserRow1 = TableOfServiceUsers.Add();
		FillPropertyValues(UserRow1, UserInformation);
	EndDo;
	
	Enabled = True;
	
EndProcedure

&AtServer
Procedure AddSelectedUsersAtServer()
	
	SetPrivilegedMode(True);
	
	Counter = 0;
	RowsCount = TableOfServiceUsers.Count();
	For Counter = 1 To RowsCount Do
		TableRow = TableOfServiceUsers[RowsCount - Counter];
		If Not TableRow.Add Then
			Continue;
		EndIf;
		
		UsersInternalSaaS.GrantSaaSUserAccess(
			TableRow.Id, ServiceUserPassword);
		
		TableOfServiceUsers.Delete(TableRow);
	EndDo;
	
EndProcedure

#EndRegion
