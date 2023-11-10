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

Var ExternalUserGroupPreviousComposition; // 
                                              // 
                                              // 

Var ExternalUserGroupPreviousRolesComposition; // 
                                                   // 
                                                   // 

Var AllAuthorizationObjectsPreviousValue; // 
                                           // 
                                           // 

Var IsNew; // 
                // 

#EndRegion

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("VerifiedObjectAttributes") Then
		VerifiedObjectAttributes = AdditionalProperties.VerifiedObjectAttributes;
	Else
		VerifiedObjectAttributes = New Array;
	EndIf;
	
	Errors = Undefined;
	
	// Check the parent.
	ErrorText = ParentCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		CommonClientServer.AddUserError(Errors,
			"Object.Parent", ErrorText, "");
	EndIf;
	
	// 
	VerifiedObjectAttributes.Add("Content.ExternalUser");
	
	// 
	ErrorText = PurposeCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		CommonClientServer.AddUserError(Errors,
			"Object.Purpose", ErrorText, "");
	EndIf;
	VerifiedObjectAttributes.Add("Purpose");
	
	For Each CurrentRow In Content Do
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Check whether the value is filled.
		If Not ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'The external user is not specified.';"),
				"Object.Content",
				LineNumber,
				NStr("en = 'The external user is not specified in line #%1.';"));
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If FoundValues.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'Duplicate external user.';"),
				"Object.Content",
				LineNumber,
				NStr("en = 'Duplicate external user in line #%1.';"));
		EndIf;
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, VerifiedObjectAttributes);
	
EndProcedure

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
	
	If Not UsersInternal.CannotEditRoles() Then
		QueryResult = Common.ObjectAttributeValue(Ref, "Roles");
		If TypeOf(QueryResult) = Type("QueryResult") Then
			ExternalUserGroupPreviousRolesComposition = QueryResult.Unload();
		Else
			ExternalUserGroupPreviousRolesComposition = Roles.Unload(New Array);
		EndIf;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		FillPurposeWithAllExternalUsersTypes();
		AllAuthorizationObjects  = False;
	EndIf;
	
	ErrorText = ParentCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		If Content.Count() > 0 Then
			Raise
				NStr("en = 'Cannot add members to the predefined group ""All external users.""';");
		EndIf;
	Else
		ErrorText = PurposeCheckErrorText();
		If ValueIsFilled(ErrorText) Then
			Raise ErrorText;
		EndIf;
		
		PreviousValues1 = Common.ObjectAttributesValues(
			Ref, "AllAuthorizationObjects, Parent");
		
		PreviousParent                      = PreviousValues1.Parent;
		AllAuthorizationObjectsPreviousValue = PreviousValues1.AllAuthorizationObjects;
		
		If ValueIsFilled(Ref)
		   And Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			QueryResult = Common.ObjectAttributeValue(Ref, "Content");
			If TypeOf(QueryResult) = Type("QueryResult") Then
				ExternalUserGroupPreviousComposition = QueryResult.Unload();
			Else
				ExternalUserGroupPreviousComposition = Content.Unload(New Array);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UsersInternal.CannotEditRoles() Then
		IsExternalUserGroupRoleCompositionChanged = False;
		
	Else
		IsExternalUserGroupRoleCompositionChanged =
			UsersInternal.ColumnValueDifferences(
				"Role",
				Roles.Unload(),
				ExternalUserGroupPreviousRolesComposition).Count() <> 0;
	EndIf;
	
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	If Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		If AllAuthorizationObjects
		 Or AllAuthorizationObjectsPreviousValue = True Then
			
			UsersInternal.UpdateExternalUserGroupCompositions(
				Ref, , ItemsToChange, ModifiedGroups);
		Else
			CompositionChanges = UsersInternal.ColumnValueDifferences(
				"ExternalUser",
				Content.Unload(),
				ExternalUserGroupPreviousComposition);
			
			UsersInternal.UpdateExternalUserGroupCompositions(
				Ref, CompositionChanges, ItemsToChange, ModifiedGroups);
			
			If PreviousParent <> Parent Then
				
				If ValueIsFilled(Parent) Then
					UsersInternal.UpdateExternalUserGroupCompositions(
						Parent, , ItemsToChange, ModifiedGroups);
				EndIf;
				
				If ValueIsFilled(PreviousParent) Then
					UsersInternal.UpdateExternalUserGroupCompositions(
						PreviousParent, , ItemsToChange, ModifiedGroups);
				EndIf;
			EndIf;
		EndIf;
		
		UsersInternal.UpdateUserGroupCompositionUsage(
			Ref, ItemsToChange, ModifiedGroups);
	EndIf;
	
	If IsExternalUserGroupRoleCompositionChanged Then
		UsersInternal.UpdateExternalUsersRoles(Ref);
	EndIf;
	
	UsersInternal.AfterUpdateExternalUserGroupCompositions(
		ItemsToChange, ModifiedGroups);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillPurposeWithAllExternalUsersTypes()
	
	Purpose.Clear();
	
	BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
	For Each EmptyRef In BlankRefs Do
		NewRow = Purpose.Add();
		NewRow.UsersType = EmptyRef;
	EndDo;
	
EndProcedure

Function ParentCheckErrorText()
	
	If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		Return
			NStr("en = 'Cannot use the predefined group ""All external users"" as a parent.';");
	EndIf;
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		If Not Parent.IsEmpty() Then
			Return
				NStr("en = 'Cannot move the predefined group ""All external users.""';");
		EndIf;
	Else
		If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			Return
				NStr("en = 'Cannot add a subgroup to the predefined group ""All external users.""';");
			
		ElsIf Parent.AllAuthorizationObjects Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add a subgroup to the group ""%1""
				           |because it includes all users.';"), Parent);
		EndIf;
		
		If AllAuthorizationObjects And ValueIsFilled(Parent) Then
			Return
				NStr("en = 'Cannot move a group that includes all users.';");
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

Function PurposeCheckErrorText()
	
	// Checking whether the group purpose is filled.
	If Purpose.Count() = 0 Then
		Return NStr("en = 'The type of group members is not specified.';");
	EndIf;
	
	// Checking whether the group of all authorization objects of the specified type is unique.
	If AllAuthorizationObjects Then
		
		// Checking whether the purpose matches the "All external users" group.
		AllExternalUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
		AllExternalUsersPurpose = Common.ObjectAttributeValue(
			AllExternalUsersGroup, "Purpose").Unload().UnloadColumn("UsersType");
		PurposesArray = Purpose.UnloadColumn("UsersType");
		
		If CommonClientServer.ValueListsAreEqual(AllExternalUsersPurpose, PurposesArray) Then
			Return
				NStr("en = 'Cannot create a group having the same purpose
				           | as the predefined group ""All external users.""';");
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("UsersTypes", Purpose.Unload());
		
		Query.Text =
		"SELECT
		|	UsersTypes.UsersType
		|INTO UsersTypes
		|FROM
		|	&UsersTypes AS UsersTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups.Purpose AS ExternalUsersGroups
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				UsersTypes AS UsersTypes
		|			WHERE
		|				ExternalUsersGroups.Ref <> &Ref
		|				AND ExternalUsersGroups.Ref.AllAuthorizationObjects
		|				AND VALUETYPE(UsersTypes.UsersType) = VALUETYPE(ExternalUsersGroups.UsersType))";
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
		
			Selection = QueryResult.Select();
			Selection.Next();
			
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An existing group ""%1""
				           | includes all users of the specified types.';"),
				Selection.RefPresentation);
		EndIf;
	EndIf;
	
	// 
	// 
	If ValueIsFilled(Parent) Then
		
		ParentUsersType = Common.ObjectAttributeValue(
			Parent, "Purpose").Unload().UnloadColumn("UsersType");
		UsersType = Purpose.UnloadColumn("UsersType");
		
		For Each UserType In UsersType Do
			If ParentUsersType.Find(UserType) = Undefined Then
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The group members type must be identical to the members type
					           |of the parent external user group ""%1.""';"), Parent);
			EndIf;
		EndDo;
	EndIf;
	
	// 
	// 
	If AllAuthorizationObjects
		And ValueIsFilled(Ref) Then
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.Text =
		"SELECT
		|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
		|WHERE
		|	ExternalUsersGroups.Parent = &Ref";
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			Return
				NStr("en = 'Cannot change the type of group 
				           | members as the group contains subgroups.';");
		EndIf;
	EndIf;
	
	// 
	// 
	If ValueIsFilled(Ref) Then
		
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("UsersTypes", Purpose);
		Query.Text =
		"SELECT
		|	UsersTypes.UsersType
		|INTO UsersTypes
		|FROM
		|	&UsersTypes AS UsersTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PRESENTATION(ExternalUserGroupsAssignment.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				UsersTypes AS UsersTypes
		|			WHERE
		|				ExternalUserGroupsAssignment.Ref.Parent = &Ref
		|				AND VALUETYPE(ExternalUserGroupsAssignment.UsersType) <> VALUETYPE(UsersTypes.UsersType))";
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot change the type of group members
				           |as the group contains the subgroup ""%1"" with different member types.';"),
				Selection.RefPresentation);
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf