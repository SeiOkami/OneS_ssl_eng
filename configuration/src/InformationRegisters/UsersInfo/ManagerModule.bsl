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

// For forms of directory elements, Users and external Users.
//
// Parameters:
//  Form - ClientApplicationForm:
//    * Object - CatalogObject.Users
//             - CatalogObject.ExternalUsers
//
Procedure ReadUserInfo(Form) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	User = Form.Object.Ref;
	
	If Not ValueIsFilled(User) Then
		Return;
	EndIf;
	
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(Form.Object);
	
	RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
	RecordSet.Filter.User.Set(User);
	RecordSet.Read();
	
	Form.UserMustChangePasswordOnAuthorization             = False;
	Form.UnlimitedValidityPeriod                    = False;
	Form.ValidityPeriod                               = Undefined;
	Form.InactivityPeriodBeforeDenyingAuthorization = 0;
	
	If RecordSet.Count() > 0 Then
		
		If AccessLevel.ListManagement
		 Or AccessLevel.ChangeCurrent Then
		
			FillPropertyValues(Form, RecordSet[0],
				"UserMustChangePasswordOnAuthorization,
				|UnlimitedValidityPeriod,
				|ValidityPeriod,
				|InactivityPeriodBeforeDenyingAuthorization");
		Else
			Form.UserMustChangePasswordOnAuthorization = RecordSet[0].UserMustChangePasswordOnAuthorization;
		EndIf;
	EndIf;
	
EndProcedure

// For forms of directory elements, Users and external Users.
//
// Parameters:
//  Form - ClientApplicationForm
//  CurrentObject - CatalogObject.Users
//                - CatalogObject.ExternalUsers
//
Procedure ObtainUserInfo(Form, CurrentObject) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	UserInfo = New Structure(
		"UserMustChangePasswordOnAuthorization,
		|UnlimitedValidityPeriod,
		|ValidityPeriod,
		|InactivityPeriodBeforeDenyingAuthorization");
	
	FillPropertyValues(UserInfo, Form);
	
	CurrentObject.AdditionalProperties.Insert("InfobaseUserExtendedProperties",
		UserInfo);
	
EndProcedure

// Parameters:
//  UserDetails - InfoBaseUser
//                       - UUID - ID of the IB user.
//
// Returns:
//  Structure:
//   * HasNoRights - Boolean
//   * HasInsufficientRightsForStartup - Boolean
//   * HasInsufficientRightForLogon - Boolean
//
Function WhetherRightsAreAssigned(UserDetails) Export
	
	Result = New Structure;
	Result.Insert("HasNoRights", False);
	Result.Insert("HasInsufficientRightsForStartup", False);
	Result.Insert("HasInsufficientRightForLogon", False);
	
	If TypeOf(UserDetails) = Type("UUID") Then
		IBUser = InfoBaseUsers.FindByUUID(
			UserDetails);
		
		If IBUser = Undefined Then
			Return Result;
		EndIf;
	Else
		IBUser = UserDetails;
	EndIf;
	
	For Each Role In IBUser.Roles Do
		Break;
	EndDo;
	
	Result.HasNoRights = (Role = Undefined);
	
	Result.HasInsufficientRightsForStartup = Result.HasNoRights
		Or Not Users.HasRightsToLogIn(IBUser, False, True);
	
	Result.HasInsufficientRightForLogon = Result.HasInsufficientRightsForStartup
		Or Not Users.HasRightsToLogIn(IBUser, False, False);
	
	Return Result;
	
EndFunction

// Parameters:
//  UserObject - CatalogObject.Users
//                     - CatalogObject.ExternalUsers - 
//
Function AreSavedInfobaseUserPropertiesMismatch(UserObject) Export
	
	Query = PropertiesQuery(UserObject.Ref);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Selection = Undefined;
	EndIf;
	
	Properties = UserNewProperties(UserObject.Ref, Selection, UserObject);
	
	Return Properties <> Undefined;
	
EndFunction

// Returns:
//  Boolean
//
Function AskAboutDisablingOpenIDConnect(Flag = Null) Export
	
	DecisionMade = Common.CommonSettingsStorageLoad(
		"DisableOpenIDConnectAuthenticationAfterInfobaseUpdated", "DecisionMade", Undefined, , "");
	
	Return DecisionMade = Flag;
	
EndFunction

// Parameters:
//  Disconnect - Boolean
//
Procedure ProcessAnswerOnDisconnectingOpenIDConnect(Disconnect) Export
	
	If Disconnect Then
		ResetOpenIDConnectAuthenticationForAllUsers();
	EndIf;
	
	Common.CommonSettingsStorageSave(
		"DisableOpenIDConnectAuthenticationAfterInfobaseUpdated", "DecisionMade", Disconnect, , "");
	
EndProcedure

// 
// 
//
// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers
//               - Undefined - 
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(User = Undefined, HasChanges = Undefined) Export
	
	If User = Undefined Then
		DeleteInfoRecordsOnDeletedUsers(User, HasChanges);
	EndIf;
	
	Query = PropertiesQuery(User);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Properties = UserNewProperties(Selection.Ref, Selection);
		If Properties = Undefined Then
			Continue;
		EndIf;
		// 
		UpdateUserInfoRecords(Selection.Ref,,, HasChanges);
	EndDo;
	
EndProcedure

// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers
//
//  Selection - QueryResultSelection
//          - ValueTableRow
//
//  UserObject - CatalogObject.Users
//                     - CatalogObject.ExternalUsers
//                     - FormDataStructure
//                     - Undefined
//
//  IBUser - InfoBaseUser
//                 - Undefined
//
Function UserNewProperties(User, Selection,
			UserObject = Undefined, IBUser = Undefined) Export
	
	CurrentProperties = New Structure;
	CurrentProperties.Insert("DeletionMark", False);
	CurrentProperties.Insert("IBUserID",
		CommonClientServer.BlankUUID());
	
	IsExternalUser = TypeOf(User) = Type("CatalogRef.ExternalUsers");
	Properties = NewProperties(IsExternalUser);
	
	If Selection <> Undefined And Selection.ValidityPeriod <> Null Then
		FillPropertyValues(Properties, Selection,
			"UserMustChangePasswordOnAuthorization,
			|UnlimitedValidityPeriod,
			|ValidityPeriod,
			|InactivityPeriodBeforeDenyingAuthorization");
	EndIf;
	
	AuthenticationPropertiesNames =
	"StandardAuthentication,
	|OpenIDAuthentication,
	|OpenIDConnectAuthentication,
	|AccessTokenAuthentication,
	|OSAuthentication";
	
	If UserObject <> Undefined Then
		If TypeOf(UserObject) <> Type("FormDataStructure")
		   And UserObject.AdditionalProperties.Property("InfobaseUserExtendedProperties")
		   And TypeOf(UserObject.AdditionalProperties.InfobaseUserExtendedProperties) = Type("Structure") Then
			
			Extensions = UserObject.AdditionalProperties.InfobaseUserExtendedProperties;
			AccessLevel = UsersInternal.UserPropertiesAccessLevel(UserObject);
			If AccessLevel.AuthorizationSettings2 Then
				FillPropertyValues(Properties, Extensions,
					"UserMustChangePasswordOnAuthorization,
					|UnlimitedValidityPeriod,
					|ValidityPeriod,
					|InactivityPeriodBeforeDenyingAuthorization");
			Else
				Properties.UserMustChangePasswordOnAuthorization =
					Extensions.UserMustChangePasswordOnAuthorization;
			EndIf;
		EndIf;
		If TypeOf(UserObject) <> Type("FormDataStructure")
		   And UserObject.AdditionalProperties.Property("StoredIBUserProperties")
		   And TypeOf(UserObject.AdditionalProperties.StoredIBUserProperties) = Type("Structure") Then
			
			StoredProperties = UserObject.AdditionalProperties.StoredIBUserProperties;
			IntermediateStructure = New Structure(AuthenticationPropertiesNames);
			FillPropertyValues(IntermediateStructure, Properties);
			FillPropertyValues(IntermediateStructure, StoredProperties);
			FillPropertyValues(Properties, IntermediateStructure);
		EndIf;
		FillPropertyValues(CurrentProperties, UserObject);
		
	ElsIf Selection <> Undefined Then
		FillPropertyValues(CurrentProperties, Selection);
	EndIf;
	
	If IBUser = Undefined Then
		IBUser = InfoBaseUsers.FindByUUID(
			CurrentProperties.IBUserID);
	EndIf;
	
	Properties.IsAppLogonRestricted = ValueIsFilled(Properties.ValidityPeriod)
		Or ValueIsFilled(Properties.InactivityPeriodBeforeDenyingAuthorization);
	
	If IBUser <> Undefined Then
		CanSignIn = Users.CanSignIn(IBUser);
		FillPropertyValues(Properties, IBUser,,
			"Language, UnsafeActionProtection" + ?(CanSignIn, "",
				"," + AuthenticationPropertiesNames));
		
		If Not CanSignIn
		   And StoredProperties = Undefined
		   And Selection <> Undefined Then
			
			FillPropertyValues(Properties, Selection, AuthenticationPropertiesNames);
		EndIf;
		
		If TypeOf(IBUser.Language) = Type("MetadataObject") Then
			Properties.Language = IBUser.Language.Name;
		EndIf;
		Properties.UnsafeActionProtection =
			IBUser.UnsafeOperationProtection.UnsafeOperationWarnings;
		Properties.CanSignIn = CanSignIn;
		WhetherRightsAreAssigned = WhetherRightsAreAssigned(IBUser);
		FillPropertyValues(Properties, WhetherRightsAreAssigned);
	EndIf;
	
	If CurrentProperties.DeletionMark Then
		Properties.NumberOfStatePicture = 1 + ?(IsExternalUser, 6, 0);
		
	ElsIf IBUser = Undefined Then
		Properties.NumberOfStatePicture = 15 + ?(IsExternalUser, 3, 0);
		
	ElsIf Not Properties.CanSignIn
	      Or Properties.HasNoRights
	      Or Properties.HasInsufficientRightForLogon Then
		
		Properties.NumberOfStatePicture = 13 + ?(IsExternalUser, 3, 0);
		
	ElsIf Properties.IsAppLogonRestricted Then
		Properties.NumberOfStatePicture = 14 + ?(IsExternalUser, 3, 0);
	Else
		Properties.NumberOfStatePicture = 2 + ?(IsExternalUser, 6, 0);
	EndIf;
	
	If Selection = Undefined Then
		Return Properties;
	EndIf;
	
	For Each KeyAndValue In Properties Do
		If Selection[KeyAndValue.Key] <> Properties[KeyAndValue.Key] Then
			Return Properties;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers
//
//  UserObject - CatalogObject.Users
//                     - CatalogObject.ExternalUsers
//                     - Undefined
//
//  IBUser - InfoBaseUser
//                 - Undefined
//
//  HasChanges - Boolean - the return value.
//
Procedure UpdateUserInfoRecords(User, UserObject = Undefined,
			IBUser = Undefined, HasChanges = False) Export
	
	Block = New DataLock;
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		LockItem = Block.Add("Catalog.ExternalUsers");
	Else
		LockItem = Block.Add("Catalog.Users");
	EndIf;
	LockItem.SetValue("Ref", User);
	LockItem = Block.Add("InformationRegister.UsersInfo");
	LockItem.SetValue("User", User);
	
	Query = PropertiesQuery(User);
	
	BeginTransaction();
	Try
		Block.Lock();
		Selection = Query.Execute().Select();
		If Not Selection.Next() Then
			Selection = Undefined;
		EndIf;
		Properties = UserNewProperties(User, Selection, UserObject, IBUser);
		If Properties <> Undefined Then
			RecordSet = ServiceRecordSet(InformationRegisters.UsersInfo);
			RecordSet.Filter.User.Set(User);
			RecordSet.Read();
			If RecordSet.Count() = 0 Then
				Record = RecordSet.Add();
				Record.User = User;
			Else
				Record = RecordSet[0];
			EndIf;
			FillPropertyValues(Record, Properties);
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function NewProperties(IsExternalUser)
	
	Properties = New Structure;
	Properties.Insert("NumberOfStatePicture", 0);
	
	Properties.Insert("UserMustChangePasswordOnAuthorization", False);
	Properties.Insert("UnlimitedValidityPeriod", False);
	Properties.Insert("ValidityPeriod", '00010101');
	Properties.Insert("InactivityPeriodBeforeDenyingAuthorization", 0);
	
	Properties.Insert("CanSignIn", False);
	Properties.Insert("IsAppLogonRestricted", False);
	Properties.Insert("HasNoRights", False);
	Properties.Insert("HasInsufficientRightForLogon", False);
	Properties.Insert("Name", "");
	Properties.Insert("Email", "");
	Properties.Insert("StandardAuthentication", False);
	Properties.Insert("CannotChangePassword", False);
	Properties.Insert("CannotRecoveryPassword", False);
	Properties.Insert("ShowInList", False);
	Properties.Insert("OpenIDAuthentication", False);
	Properties.Insert("OpenIDConnectAuthentication", False);
	Properties.Insert("AccessTokenAuthentication", False);
	Properties.Insert("OSAuthentication", False);
	Properties.Insert("OSUser", "");
	Properties.Insert("Language", "");
	Properties.Insert("UnsafeActionProtection", False);
	
	Return Properties;
	
EndFunction

Function PropertiesQuery(User) Export
	
	QueryText =
	"SELECT
	|	ISNULL(Users.Ref, UsersInfo.User) AS Ref,
	|	Users.IBUserID AS IBUserID,
	|	Users.DeletionMark AS DeletionMark,
	|	UsersInfo.UserMustChangePasswordOnAuthorization AS UserMustChangePasswordOnAuthorization,
	|	UsersInfo.UnlimitedValidityPeriod AS UnlimitedValidityPeriod,
	|	UsersInfo.ValidityPeriod AS ValidityPeriod,
	|	UsersInfo.InactivityPeriodBeforeDenyingAuthorization AS InactivityPeriodBeforeDenyingAuthorization,
	|	UsersInfo.NumberOfStatePicture AS NumberOfStatePicture,
	|	UsersInfo.CanSignIn AS CanSignIn,
	|	UsersInfo.IsAppLogonRestricted AS IsAppLogonRestricted,
	|	UsersInfo.HasNoRights AS HasNoRights,
	|	UsersInfo.HasInsufficientRightForLogon AS HasInsufficientRightForLogon,
	|	UsersInfo.Name AS Name,
	|	UsersInfo.Email AS Email,
	|	UsersInfo.StandardAuthentication AS StandardAuthentication,
	|	UsersInfo.CannotChangePassword AS CannotChangePassword,
	|	UsersInfo.CannotRecoveryPassword AS CannotRecoveryPassword,
	|	UsersInfo.ShowInList AS ShowInList,
	|	UsersInfo.OpenIDAuthentication AS OpenIDAuthentication,
	|	UsersInfo.OpenIDConnectAuthentication AS OpenIDConnectAuthentication,
	|	UsersInfo.AccessTokenAuthentication AS AccessTokenAuthentication,
	|	UsersInfo.OSAuthentication AS OSAuthentication,
	|	UsersInfo.OSUser AS OSUser,
	|	UsersInfo.Language AS Language,
	|	UsersInfo.UnsafeActionProtection AS UnsafeActionProtection
	|FROM
	|	Catalog.Users AS Users
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = Users.Ref)
	|WHERE
	|	&FilterByUser";
	
	Query = New Query;
	
	If User = Undefined Then
		QueryText = StrReplace(QueryText, "&FilterByUser", "TRUE");
		Query.Text = QueryText + Chars.LF + Chars.LF
			+ "UNION ALL" + Chars.LF + Chars.LF
			+ StrReplace(QueryText, "Catalog.Users",
				"Catalog.ExternalUsers");
	Else
		QueryText = StrReplace(QueryText, "LEFT JOIN", "FULL JOIN");
		QueryText = StrReplace(QueryText, "&FilterByUser",
				"Users.Ref = &User
			|	OR UsersInfo.User = &User");
		Query.SetParameter("User", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			Query.Text = QueryText;
		Else
			Query.Text = StrReplace(QueryText, "Catalog.Users",
				"Catalog.ExternalUsers");
		EndIf;
	EndIf;
	
	Return Query;
	
EndFunction

Procedure DeleteInfoRecordsOnDeletedUsers(User, HasChanges = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UsersInfo.User AS Ref
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	UsersInfo.User.Ref IS NULL
	|	AND &FilterByUser";
	
	If User = Undefined Then
		Query.Text = StrReplace(Query.Text, "&FilterByUser", "TRUE");
	Else
		Query.Text = StrReplace(Query.Text, "&FilterByUser",
			"UsersInfo.User = &User");
		Query.SetParameter("User", User);
	EndIf;
	
	// 
	Selection = Query.Execute().Select();
	// 
	While Selection.Next() Do
		RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
		RecordSet.Filter.User.Set(Selection.Ref);
		RecordSet.Write();
		HasChanges = True;
	EndDo;
	
EndProcedure

// Creates a catalog service item that does not subscribe to events.
//
// Parameters:
//   Ref - CatalogRef
//
Function ServiceItem(Ref)
	
	CatalogItem = Ref.GetObject();
	If CatalogItem = Undefined Then
		Return Undefined;
	EndIf;
	
	CatalogItem.AdditionalProperties.Insert("DontControlObjectsToDelete");
	CatalogItem.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	CatalogItem.DataExchange.Recipients.AutoFill = False;
	CatalogItem.DataExchange.Load = True;
	
	Return CatalogItem;
	
EndFunction

// Creates a record set of a service register that does subscribe to events.
Function ServiceRecordSet(RegisterManager)
	
	RecordSet = RegisterManager.CreateRecordSet();
	RecordSet.AdditionalProperties.Insert("DontControlObjectsToDelete");
	RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	RecordSet.DataExchange.Recipients.AutoFill = False;
	RecordSet.DataExchange.Load = True;
	
	Return RecordSet;
	
EndFunction

Procedure UpdateUsersInfoAndDisableAuthentication() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.Users AS Users
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|
	|UNION ALL
	|
	|SELECT
	|	UsersInfo.User
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	UsersInfo.User.Ref IS NULL";
	
	Selection = Query.Execute().Select();
	
	UsersTable = InformationRegisters.UsersInfo.CreateRecordSet().Unload(, "User");
	UsersTable.Add();
	
	While Selection.Next() Do
		User = Selection.User;
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.UsersInfo");
		LockItem.SetValue("User", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			LockItem = Block.Add("Catalog.Users");
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			LockItem = Block.Add("Catalog.ExternalUsers");
		Else
			Continue;
		EndIf;
		LockItem.SetValue("Ref", User);
		
		BeginTransaction();
		Try
			Block.Lock();
			HasChanges = False;
			// 
			DeleteInfoRecordsOnDeletedUsers(User, HasChanges);
			If Not HasChanges Then
				UserObject = ServiceItem(User);
				If UserObject <> Undefined Then
					ResetAuthenticationForInvalidUser(UserObject);
					ResetUnwantedOpenIDConnectAuthentication(UserObject);
					PreviousProperties = UserObject.DeleteInfobaseUserProperties.Get();
					If PreviousProperties <> Undefined Then
						UserObject.DeleteInfobaseUserProperties = New ValueStorage(Undefined);
						If TypeOf(PreviousProperties) = Type("Structure") Then
							UserObject.AdditionalProperties.Insert("StoredIBUserProperties",
								UsersInternal.StoredIBUserProperties(PreviousProperties));
						EndIf;
					EndIf;
					// 
					UpdateUserInfoRecords(User, UserObject);
					If UserObject.Modified() Then
						// ACC:1363-
						UserObject.Write();
						// 
					EndIf;
				EndIf;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion()
	 Or Common.FileInfobase() Then
		
		ResetOpenIDConnectAuthenticationForAllUsers();
		
	ElsIf AskAboutDisablingOpenIDConnect(Undefined)
	        And HasEnabledOpenIDConnectAuth() Then
		
		Common.CommonSettingsStorageSave(
			"DisableOpenIDConnectAuthenticationAfterInfobaseUpdated", "DecisionMade", Null, , "");
	EndIf;
	
EndProcedure

Procedure ResetAuthenticationForInvalidUser(UserObject)
	
	If Not UserObject.Invalid
	   And Not UserObject.DeletionMark Then
		Return;
	EndIf;
	
	IBUser = InfoBaseUsers.FindByUUID(
		UserObject.IBUserID);
	
	If IBUser = Undefined Then
		Return;
	EndIf;
	
	Write = False;
	If IBUser.StandardAuthentication Then
		IBUser.StandardAuthentication = False;
		Write = True;
	EndIf;
	
	If IBUser.OpenIDAuthentication Then
		IBUser.OpenIDAuthentication = False;
		Write = True;
	EndIf;
	
	If IBUser.OpenIDConnectAuthentication Then
		IBUser.OpenIDConnectAuthentication = False;
		Write = True;
	EndIf;
	
	If IBUser.AccessTokenAuthentication Then
		IBUser.AccessTokenAuthentication = False;
		Write = True;
	EndIf;
	
	If IBUser.OSAuthentication Then
		IBUser.OSAuthentication = False;
		Write = True;
	EndIf;
	
	If Write Then
		IBUser.Write();
	EndIf;
	
EndProcedure

Procedure ResetUnwantedOpenIDConnectAuthentication(UserObject)
	
	If UserObject.Invalid
	 Or UserObject.DeletionMark Then
		Return;
	EndIf;
	
	IBUser = InfoBaseUsers.FindByUUID(
		UserObject.IBUserID);
	
	If IBUser = Undefined Then
		Return;
	EndIf;
	
	If Not IBUser.StandardAuthentication
	   And Not IBUser.OpenIDAuthentication
	   And    IBUser.OpenIDConnectAuthentication
	   And Not IBUser.AccessTokenAuthentication
	   And Not IBUser.OSAuthentication Then
		
		IBUser.OpenIDConnectAuthentication = False;
		IBUser.Write();
	EndIf;
	
EndProcedure

Procedure ResetOpenIDConnectAuthenticationForAllUsers()
	
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.IBUserID AS IBUserID
	|FROM
	|	Catalog.Users AS Users
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.IBUserID
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers";
	Upload0 = Query.Execute().Unload();
	
	For Each IBUser In AllIBUsers Do
		If Not IBUser.OpenIDConnectAuthentication Then
			Continue;
		EndIf;
		IBUser.OpenIDConnectAuthentication = False;
		String = Upload0.Find(IBUser.UUID, "IBUserID");
		BeginTransaction();
		Try
			IBUser.Write();
			If String <> Undefined Then
				// 
				UpdateUserInfoRecords(String.Ref);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

Function HasEnabledOpenIDConnectAuth()
	
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For Each IBUser In AllIBUsers Do
		If IBUser.OpenIDConnectAuthentication Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#EndIf
