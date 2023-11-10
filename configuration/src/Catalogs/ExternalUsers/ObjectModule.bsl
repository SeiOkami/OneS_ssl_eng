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

Var IBUserProcessingParameters; // 
                                        // 

Var IsNew; // 
                // 

Var PreviousAuthorizationObject; // 
                               // 

#EndRegion

// 
//
// 
//
// 
//
// 

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Not ValueIsFilled(AuthorizationObject) Then
		Raise NStr("en = 'No authorization object is set for the external user.';");
	Else
		ErrorText = "";
		If UsersInternal.AuthorizationObjectIsInUse(
		         AuthorizationObject, Ref, , , ErrorText) Then
			
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Checking whether the authorization object was not changed.
	If IsNew Then
		PreviousAuthorizationObject = NULL;
	Else
		PreviousAuthorizationObject = Common.ObjectAttributeValue(
			Ref, "AuthorizationObject");
		
		If ValueIsFilled(PreviousAuthorizationObject)
		   And PreviousAuthorizationObject <> AuthorizationObject Then
			
			Raise NStr("en = 'Cannot change a previously specified authorization object.';");
		EndIf;
	EndIf;
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
	SetPrivilegedMode(True);
	InformationRegisters.UsersInfo.UpdateUserInfoRecords(
		UsersInternal.ObjectRef2(ThisObject), ThisObject);
	SetPrivilegedMode(False);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating the content of the group that contains the new external user (provided that it is in a group).
	If AdditionalProperties.Property("NewExternalUserGroup")
	   And ValueIsFilled(AdditionalProperties.NewExternalUserGroup) Then
		
		Block = New DataLock;
		Block.Add("Catalog.ExternalUsersGroups");
		Block.Lock();
		
		GroupObject1 = AdditionalProperties.NewExternalUserGroup.GetObject(); // CatalogRef.ExternalUsersGroups
		GroupObject1.Content.Add().ExternalUser = Ref;
		GroupObject1.Write();
	EndIf;
	
	// Updating the content of the "All external users" automatic group.
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	UsersInternal.UpdateExternalUserGroupCompositions(
		Catalogs.ExternalUsersGroups.AllExternalUsers,
		Ref,
		ItemsToChange,
		ModifiedGroups);
	
	UsersInternal.UpdateUserGroupCompositionUsage(
		Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.EndIBUserProcessing(
		ThisObject, IBUserProcessingParameters);
	
	UsersInternal.AfterUpdateExternalUserGroupCompositions(
		ItemsToChange,
		ModifiedGroups);
	
	If PreviousAuthorizationObject <> AuthorizationObject Then
		SSLSubsystemsIntegration.AfterChangeExternalUserAuthorizationObject(
			Ref, PreviousAuthorizationObject, AuthorizationObject);
	EndIf;
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	Comment = "";
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange() Export
	
	// 
	// 
	
	IBUserDetails = New Structure;
	IBUserDetails.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters, True);
	UsersInternal.EndIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf