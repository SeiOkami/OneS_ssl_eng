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
	
	CertificateUsers = Parameters.Users;
	CertificateRecipient = Parameters.User;
	ViewMode = Parameters.ViewMode;
	
	If CertificateUsers = Undefined Then
		CertificateUsers = New Array;
	EndIf;
	
	If CertificateUsers.Count() > 0
		Or CertificateRecipient <> Users.CurrentUser()
		Or Not ValueIsFilled(CertificateRecipient) Then
		ChoiceMode = "UsersList";
	Else
		ChoiceMode = "JustForMe";
	EndIf;
	
	FillInTheFullList(CertificateUsers, CertificateRecipient);
	FormControl(ThisObject);
	ConfigureConditionalFormatting();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChoiceModeOnChange(Item)
	
	FormControl(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If ViewMode Then
		Result = Undefined;
	Else	
		Result = New Structure;
		Result.Insert("Users", New Array);
		Result.Insert("User", PredefinedValue("Catalog.Users.EmptyRef"));
		
		If ChoiceMode = "UsersList" Then
			For Each UserRow1 In UsersTable Do
				If UserRow1.Check Then
					Result.Users.Add(UserRow1.User);
				EndIf;
			EndDo;
		Else
			Result.User = UsersClient.CurrentUser();	
		EndIf;
		If Result.Users.Count() = 1 Then
			Result.User = Result.Users[0];
			Result.Users.Clear();
		EndIf;
	EndIf;
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure CancelCheck(Command)
	
	ChangeTheListLabels(False);
	
EndProcedure

&AtClient
Procedure SelectAllItems(Command)
	
	ChangeTheListLabels(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeTheListLabels(CheckMarkValue)
	
	For Each UserRow1 In UsersTable Do
		UserRow1.Check = CheckMarkValue;
	EndDo;
	
EndProcedure

&AtServer
Procedure ConfigureConditionalFormatting()
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("BackColor");
	AppearanceColorItem.Value = StyleColors.AddedAttributeBackground;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("UsersTable.Main");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	DesignFieldElement = ConditionalAppearanceItem.Fields.Items.Add();
	DesignFieldElement.Field = New DataCompositionField("UsersTable");
	DesignFieldElement.Use = True;
	
EndProcedure

&AtServer
Procedure FillInTheFullList(CertificateUsers, CertificateRecipient)
	
	UsersArray = New Array;
	If CertificateUsers <> Undefined Then
		UsersArray = CertificateUsers;
	EndIf;
	
	If ValueIsFilled(CertificateRecipient)
		And ChoiceMode = "UsersList" Then
		UsersArray.Add(CertificateRecipient);
	EndIf;
	
	QueryText = 
	"SELECT ALLOWED
	|	Users.Ref AS User,
	|	CASE
	|		WHEN Users.Ref IN (&Users)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Check,
	|	CASE
	|		WHEN Users.Ref = &CertificateRecipient
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Main
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	(NOT Users.DeletionMark
	|				AND NOT Users.Invalid
	|				AND (NOT Users.IsInternal
	|						AND Users.IBUserID <> &EmptyIDOfTheIBUser
	|					OR Users.Ref = &CurrentUser)
	|			OR Users.Ref IN (&Users))
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query(QueryText);
	Query.SetParameter("Users", UsersArray);
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("EmptyIDOfTheIBUser", New UUID("00000000-0000-0000-0000-000000000000"));
	Query.SetParameter("CertificateRecipient", CertificateRecipient);
	
	UsersTable.Load(Query.Execute().Unload());
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormControl(TheFormContext)
	
	FormItems = TheFormContext.Items;
	
	If TheFormContext.ViewMode Then
		FormItems.UsersTable.ReadOnly = True;
		FormItems.ChoiceMode.ReadOnly = True;
		FormItems.SelectionMethodList.ReadOnly = True;
	Else	
		FormItems.UsersTable.ReadOnly = Not TheFormContext.ChoiceMode = "UsersList";
	EndIf;	
	
	FormItems.UsersSelectAll.Enabled = Not FormItems.UsersTable.ReadOnly;
	FormItems.UsersCancelCheck.Enabled = Not FormItems.UsersTable.ReadOnly;
		
EndProcedure

#EndRegion
