///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// This procedure is called on processing message http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  DataAreaUser - CatalogRef.Users - the user 
//   to be added to or removed from the Administrators group.
//  AccessAllowed - Boolean - if True, the user is added to the group.
//   If False, the user is removed from the group.
//
Procedure SetUserBelongingToAdministratorGroup(Val DataAreaUser, Val AccessAllowed) Export
	
	AdministratorsGroup = AccessManagement.AdministratorsAccessGroup();
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", AdministratorsGroup);
	Block.Lock();
	
	GroupObject = AdministratorsGroup.GetObject();
	
	UserString = GroupObject.Users.Find(DataAreaUser, "User");
	
	If AccessAllowed And UserString = Undefined Then
		
		UserString = GroupObject.Users.Add();
		UserString.User = DataAreaUser;
		GroupObject.Write();
		
	ElsIf Not AccessAllowed And UserString <> Undefined Then
		
		GroupObject.Users.Delete(UserString);
		GroupObject.Write();
	Else
		AccessManagement.UpdateUserRoles(DataAreaUser);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.DataFillingForAccessRestriction.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.AccessUpdateOnRecordsLevel.Name);
	
EndProcedure

// See ExportImportDataOverridable.AfterImportData.
Procedure AfterImportData(Container) Export
	
	// 
	// 
	// 
	If Not Common.DataSeparationEnabled() Then
		Catalogs.AccessGroupProfiles.UpdateSuppliedProfiles();
		Catalogs.AccessGroupProfiles.UpdateUnshippedProfiles();
	EndIf;
	
	AccessManagementInternal.ScheduleAccessRestrictionParametersUpdate(
		"AfterUploadingDataToTheDataArea");
	
EndProcedure

// This procedure is called when updating the infobase user roles.
//
// Parameters:
//  IBUserID - UUID.
//  Cancel - Boolean - if this parameter is set to False in the event handler,
//    roles are not updated for this infobase user.
//
Procedure OnUpdateIBUserRoles(Val UserIdentificator, Cancel) Export
	
	If Common.DataSeparationEnabled()
		And UsersInternalSaaS.UserRegisteredAsShared(UserIdentificator) Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion
