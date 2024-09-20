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

Var PreviousValues1; // 
                      // 

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	InformationRegisters.RolesRights.CheckRegisterData();
	
	PreviousValues1 = Common.ObjectAttributesValues(Ref,
		"Ref, Profile, DeletionMark, Users, AccessKinds, AccessValues");
	
	If Not Catalogs.ExtensionsVersions.AllExtensionsConnected() Then
		Catalogs.AccessGroupProfiles.RestoreNonexistentViewsFromAccessValue(PreviousValues1, ThisObject);
	EndIf;
	
	// Deleting blank members of the access group.
	IndexOf = Users.Count() - 1;
	While IndexOf >= 0 Do
		If Not ValueIsFilled(Users[IndexOf].User) Then
			Users.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	If Ref = AccessManagement.AdministratorsAccessGroup() Then
		
		// Administrator predefined profile is always used.
		Profile = AccessManagement.ProfileAdministrator();
		
		// Cannot be a personal access group.
		User = Undefined;
		
		// Regular users cannot be responsible for the group (only full access users can).
		EmployeeResponsible = Undefined;
		
		// Only full access users can make changes.
		If Not PrivilegedMode()
		   And Not AccessManagement.HasRole("FullAccess") Then
			
			Raise
				NStr("en = 'The predefined access group ""Administrators""
				           |can be changed only if you have the ""Full access"" role
				           |or in privileged mode.';");
		EndIf;
		
		// Checking whether the access group contains regular users only.
		For Each CurrentRow In Users Do
			If TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
				Raise
					NStr("en = 'The predefined access group ""Administrators""
					           |can contain only users.
					           |
					           |User groups, external users, and
					           |external user groups are not allowed.';");
			EndIf;
		EndDo;
		
	// Administrator predefined profile cannot be set to an arbitrary access group.
	ElsIf Profile = AccessManagement.ProfileAdministrator() Then
		Raise
			NStr("en = 'Only the predefined access group ""Administrators""
			           |can have the predefined profile ""Administrator.""';");
	EndIf;
	
	If Not IsFolder Then
		
		// Automatically setting attributes for the personal access group.
		If ValueIsFilled(User) Then
			Parent = Catalogs.AccessGroups.PersonalAccessGroupsParent();
		Else
			User = Undefined;
			If Parent = Catalogs.AccessGroups.PersonalAccessGroupsParent(True) Then
				Parent = Undefined;
			EndIf;
		EndIf;
		
		// 
		// 
		If Not DeletionMark And PreviousValues1.DeletionMark = True Then
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add("Catalog.AccessGroupProfiles");
				LockItem.SetValue("Ref", Profile);
				Block.Lock();
				
				ProfileDeletionMark = Common.ObjectAttributeValue(Profile, "DeletionMark");
				ProfileDeletionMark = ?(ProfileDeletionMark = Undefined, False, ProfileDeletionMark);
				If ProfileDeletionMark Then
					LockDataForEdit(Profile);
					ProfileObject = Profile.GetObject();
					ProfileObject.DeletionMark = False;
					ProfileObject.Write();
				EndIf;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;	
		EndIf;
	EndIf;
	
EndProcedure

// Updates:
// - roles of added, remaining, and deleted users
// - InformationRegister.AccessGroupsTables
// - InformationRegister.AccessGroupsValues
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUsersRoles") Then
		UpdateUsersRolesOnChangeAccessGroup();
	EndIf;
	
	HasMembers = Users.Count() <> 0;
	HasOldMembers = PreviousValues1.Ref = Ref And Not PreviousValues1.Users.IsEmpty();
	
	If Profile           <> PreviousValues1.Profile
	 Or DeletionMark   <> PreviousValues1.DeletionMark
	 Or HasMembers <> HasOldMembers Then
		
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(Ref);
	EndIf;
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		CompositionOfRoleChanges = Catalogs.AccessGroups.RolesForUpdatingRights(PreviousValues1, ThisObject);
		AccessManagementInternal.ScheduleAnAccessUpdateWhenTheAccessGroupProfileChanges(
			"AccessGroupWhenChangingTheProfile", CompositionOfRoleChanges, Profile <> PreviousValues1.Profile);
	EndIf;
	
	If Catalogs.AccessGroups.AccessKindsOrAccessValuesChanged(PreviousValues1, ThisObject)
	 Or DeletionMark   <> PreviousValues1.DeletionMark
	 Or HasMembers <> HasOldMembers Then
		
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(Ref);
	EndIf;
	
	Catalogs.AccessGroupProfiles.UpdateAuxiliaryProfilesDataChangedOnImport();
	Catalogs.AccessGroups.UpdateAccessGroupsAuxiliaryDataChangedOnImport();
	Catalogs.AccessGroups.UpdateAuxiliaryDataOfUserGroupsChangedOnImport();
	Catalogs.AccessGroups.UpdateUsersRolesChangedOnImport();
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		ChangedMembersTypes = ChangedMembersTypes(Users, PreviousValues1.Users,
			DeletionMark <> PreviousValues1.DeletionMark);
		AccessManagementInternal.ScheduleAccessGroupsSetsUpdate(
			"AccessGroupsOnChangingMembers",
			ChangedMembersTypes.Users,
			ChangedMembersTypes.ExternalUsers);
		
		If Not DeletionMark Then
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAccessGroupMembers(Ref,
				ChangedMembersTypes);
		EndIf;
		If DeletionMark <> PreviousValues1.DeletionMark Then
			AccessManagementInternal.UpdateAccessGroupsOfAllowedAccessKey(Ref);
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("VerifiedObjectAttributes") Then
		Common.DeleteNotCheckedAttributesFromArray(
			CheckedAttributes, AdditionalProperties.VerifiedObjectAttributes);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  NewMembers - CatalogTabularSection.AccessGroups.Users
//  OldMembers - QueryResult
// Returns:
//  Structure:
//    * ExternalUsers - Boolean
//    * Users - Boolean
//
Function ChangedMembersTypes(NewMembers, OldMembers, DeletionTagHasChanged)
	
	ChangedMembersTypes = New Structure;
	ChangedMembersTypes.Insert("Users", False);
	ChangedMembersTypes.Insert("ExternalUsers", False);
	
	AllMembers = NewMembers.Unload(, "User");
	AllMembers.Columns.Add("LineChangeType", New TypeDescription("Number"));
	AllMembers.FillValues(1, "LineChangeType");
	If OldMembers <> Undefined Then
		Selection = OldMembers.Select();
		While Selection.Next() Do
			NewRow = AllMembers.Add();
			NewRow.User = Selection.User;
			NewRow.LineChangeType = -1;
		EndDo;
	EndIf;
	AllMembers.GroupBy("User", "LineChangeType");
	For Each String In AllMembers Do
		If String.LineChangeType = 0
		   And Not DeletionTagHasChanged Then
			Continue;
		EndIf;
		If TypeOf(String.User) = Type("CatalogRef.Users")
		 Or TypeOf(String.User) = Type("CatalogRef.UserGroups") Then
			ChangedMembersTypes.Users = True;
		EndIf;
		If TypeOf(String.User) = Type("CatalogRef.ExternalUsers")
		 Or TypeOf(String.User) = Type("CatalogRef.ExternalUsersGroups") Then
			ChangedMembersTypes.ExternalUsers = True;
		EndIf;
	EndDo;
	
	Return ChangedMembersTypes;
	
EndFunction

Procedure UpdateUsersRolesOnChangeAccessGroup()
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SessionWithoutSeparators = ModuleSaaSOperations.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	If Common.DataSeparationEnabled()
		And Ref = AccessManagement.AdministratorsAccessGroup()
		And Not SessionWithoutSeparators
		And AdditionalProperties.Property("ServiceUserPassword") Then
		
		ServiceUserPassword = AdditionalProperties.ServiceUserPassword;
	Else
		ServiceUserPassword = Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	UsersForUpdate =
		Catalogs.AccessGroups.UsersForRolesUpdate(PreviousValues1, ThisObject);
	
	If Ref = AccessManagement.AdministratorsAccessGroup() Then
		// Adding users associated with infobase users with the FullAccess role.
		
		For Each IBUser In InfoBaseUsers.GetUsers() Do
			If IBUser.Roles.Contains(Metadata.Roles.FullAccess) Then
				
				FoundUser = Catalogs.Users.FindByAttribute(
					"IBUserID", IBUser.UUID);
				
				If Not ValueIsFilled(FoundUser) Then
					FoundUser = Catalogs.ExternalUsers.FindByAttribute(
						"IBUserID", IBUser.UUID);
				EndIf;
				
				If ValueIsFilled(FoundUser)
				   And UsersForUpdate.Find(FoundUser) = Undefined Then
					
					UsersForUpdate.Add(FoundUser);
				EndIf;
				
			EndIf;
		EndDo;
	EndIf;
	
	AccessManagement.UpdateUserRoles(UsersForUpdate, ServiceUserPassword);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf