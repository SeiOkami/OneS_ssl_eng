///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// This procedure updates all register data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	Block.Add("InformationRegister.UserGroupCompositions");
	
	LockItem = Block.Add("Catalog.Users");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.UserGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	LockItem = Block.Add("Catalog.ExternalUsers");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.ExternalUsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		// Update user mapping.
		ItemsToChange = New Map;
		ModifiedGroups   = New Map;
		
		Selection = Catalogs.UserGroups.Select();
		While Selection.Next() Do
			UsersInternal.UpdateUserGroupComposition(
				Selection.Ref, , ItemsToChange, ModifiedGroups);
		EndDo;
		
		// 
		Selection = Catalogs.ExternalUsersGroups.Select();
		While Selection.Next() Do
			UsersInternal.UpdateExternalUserGroupCompositions(
				Selection.Ref, , ItemsToChange, ModifiedGroups);
		EndDo;
		
		If ItemsToChange.Count() > 0
		 Or ModifiedGroups.Count() > 0 Then
		
			HasChanges = True;
			
			UsersInternal.AfterUserGroupsUpdate(
				ItemsToChange, ModifiedGroups);
		EndIf;
		
		UsersInternal.UpdateExternalUsersRoles();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf