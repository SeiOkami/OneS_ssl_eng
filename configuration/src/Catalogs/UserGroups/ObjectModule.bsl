///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousParent; // 
                      // 

Var PreviousUserGroupComposition; // 
                                       // 
                                       // 

Var IsNew; // 
                // 

#EndRegion

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Check the parent.
	If Parent = Catalogs.UserGroups.AllUsers Then
		CommonClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en = 'Cannot use the predefined group ""All users"" as a parent.';"),
			"");
	EndIf;
	
	// 
	VerifiedObjectAttributes.Add("Content.User");
	
	For Each CurrentRow In Content Do;
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Check whether the value is filled.
		If Not ValueIsFilled(CurrentRow.User) Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'User is not selected.';"),
				"Object.Content",
				LineNumber,
				NStr("en = 'User is not selected in line #%1.';"));
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = Content.FindRows(New Structure("User", CurrentRow.User));
		If FoundValues.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("en = 'Duplicate user.';"),
				"Object.Content",
				LineNumber,
				NStr("en = 'Duplicate user in line #%1.';"));
		EndIf;
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, VerifiedObjectAttributes);
	
EndProcedure

// Cancels actions that cannot be performed on the "All users" group.
Procedure BeforeWrite(Cancel)
	
	// 
	// 
	// 
	// 
	// 
	Block = New DataLock;
	Block.Add("InformationRegister.UserGroupCompositions");
	Block.Lock();
	// 
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.UserGroups.AllUsers Then
		If Not Parent.IsEmpty() Then
			Raise
				NStr("en = 'The position of the predefined group ""All users"" cannot be changed.
				           |It is the root of the group tree.';");
		EndIf;
		If Content.Count() > 0 Then
			Raise
				NStr("en = 'Cannot add users to group
				           |""All users.""';");
		EndIf;
	Else
		If Parent = Catalogs.UserGroups.AllUsers Then
			Raise
				NStr("en = 'Cannot use the predefined group ""All users""
				           |as a parent.';");
		EndIf;
		
		PreviousParent = ?(
			Ref.IsEmpty(),
			Undefined,
			Common.ObjectAttributeValue(Ref, "Parent"));
			
		If ValueIsFilled(Ref)
		   And Ref <> Catalogs.UserGroups.AllUsers Then
			
			PreviousUserGroupComposition =
				Common.ObjectAttributeValue(Ref, "Content").Unload();
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	If Ref <> Catalogs.UserGroups.AllUsers Then
		
		CompositionChanges = UsersInternal.ColumnValueDifferences(
			"User",
			Content.Unload(),
			PreviousUserGroupComposition);
		
		UsersInternal.UpdateUserGroupComposition(
			Ref, CompositionChanges, ItemsToChange, ModifiedGroups);
		
		If PreviousParent <> Parent Then
			
			If ValueIsFilled(Parent) Then
				UsersInternal.UpdateUserGroupComposition(
					Parent, , ItemsToChange, ModifiedGroups);
			EndIf;
			
			If ValueIsFilled(PreviousParent) Then
				UsersInternal.UpdateUserGroupComposition(
					PreviousParent, , ItemsToChange, ModifiedGroups);
			EndIf;
		EndIf;
		
		UsersInternal.UpdateUserGroupCompositionUsage(
			Ref, ItemsToChange, ModifiedGroups);
		
		If Not Users.IsFullUser() Then
			CheckChangeCompositionRight(CompositionChanges);
		EndIf;
	EndIf;
	
	UsersInternal.AfterUserGroupsUpdate(
		ItemsToChange, ModifiedGroups);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckChangeCompositionRight(CompositionChanges)
	
	Query = New Query;
	Query.SetParameter("Users", CompositionChanges);
	Query.Text =
	"SELECT
	|	Users.Description AS Description
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref IN(&Users)
	|	AND NOT Users.Prepared";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	UsersContent = QueryResult.Unload().UnloadColumn("Description");
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Insufficient access rights to modify:
		           |%1
		           |
		           |Only new users who have not yet been approved by the administrator
		           |can be included in or excluded from user groups
		           |(that is, the administrator has not yet allowed users to sign in).';"),
		StrConcat(UsersContent, Chars.LF));
	
	Raise ErrorText;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf