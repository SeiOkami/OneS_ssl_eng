///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// Returns the current user or the current external user,
// depending on which one has signed in.
//  It is recommended that you use the function in a script fragment that supports both sign in options.
//
// Returns:
//  CatalogRef.Users, CatalogRef.ExternalUsers - 
//    
//
Function AuthorizedUser() Export
	
	Return UsersInternal.AuthorizedUser();
	
EndFunction

// Returns the current user.
//  It is recommended that you use the function in a script fragment that does not support external users.
//
//  If the current user is external, throws an exception.
//
// Returns:
//  CatalogRef.Users - user.
//
Function CurrentUser() Export
	
	Return UsersInternalClientServer.CurrentUser(AuthorizedUser());
	
EndFunction

// Returns True if the current user is external.
//
// Returns:
//  Boolean - 
//
Function IsExternalUserSession() Export
	
	Return UsersInternalCached.IsExternalUserSession();
	
EndFunction

// Checks whether the current user or the specified user has full access rights.
// 
// A user is a full access user:
// a) who has the FullAccess role and the role for system administration
//    (if CheckSystemAdministrationRights = True), and if the list of infobase users is not empty;
// b) if the infobase user list is empty and
//    the main role of configuration is not specified or is FullAccess.
//
// Parameters:
//  User - Undefined - checking the current infobase user.
//               - CatalogRef.Users
//               - CatalogRef.ExternalUsers - 
//                    
//                    
//               - InfoBaseUser - 
//
//  CheckSystemAdministrationRights - Boolean - If True, checks whether the user
//                 has the administrative role.
//
//  ForPrivilegedMode - Boolean - If True, the function returns True for the current user
//                 (provided that privileged mode is set).
//
// Returns:
//  Boolean - 
//
Function IsFullUser(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	
	PrivilegedModeSet = PrivilegedMode();
	
	SetPrivilegedMode(True);
	IBUserProperies = CheckedIBUserProperties(User);
	
	If IBUserProperies = Undefined Then
		Return False;
	EndIf;
	
	CheckFullAccessRole = Not CheckSystemAdministrationRights;
	CheckSystemAdministratorRole = CheckSystemAdministrationRights;
	
	If Not IBUserProperies.IsCurrentIBUser Then
		Roles = IBUserProperies.IBUser.Roles;
		
		// Checking roles for the saved infobase user if the user to be checked is not the current one.
		If CheckFullAccessRole
		   And Not Roles.Contains(Metadata.Roles.FullAccess) Then
			Return False;
		EndIf;
		
		If CheckSystemAdministratorRole
		   And Not Roles.Contains(Metadata.Roles.SystemAdministrator) Then
			Return False;
		EndIf;
		
		Return True;
	EndIf;
	
	If ForPrivilegedMode And PrivilegedModeSet Then
		Return True;
	EndIf;
	
	If StandardSubsystemsCached.PrivilegedModeSetOnStart() Then
		// 
		// 
		Return True;
	EndIf;
	
	If Not ValueIsFilled(IBUserProperies.Name) And Metadata.DefaultRoles.Count() = 0 Then
		// 
		// 
		Return True;
	EndIf;
	
	If Not ValueIsFilled(IBUserProperies.Name)
	   And PrivilegedModeSet
	   And IBUserProperies.AdministrationRight Then
		// 
		// 
		// 
		Return True;
	EndIf;
	
	// 
	// 
	If CheckFullAccessRole
	   And Not IBUserProperies.RoleAvailableFullAccess Then
		Return False;
	EndIf;
	
	If CheckSystemAdministratorRole
	   And Not IBUserProperies.SystemAdministratorRoleAvailable Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns True if at least one of the specified roles is available for the user,
// or the user has full access rights.
//
// Parameters:
//  RolesNames   - String - names of roles whose availability is checked, separated by commas.
//
//  User - Undefined - checking the current infobase user.
//               - CatalogRef.Users
//               - CatalogRef.ExternalUsers - 
//                    
//                    
//               - InfoBaseUser - 
//
//  ForPrivilegedMode - Boolean - If True, the function returns True for the current user
//                 (provided that privileged mode is set).
//
// Returns:
//  Boolean - 
//           
//
Function RolesAvailable(RolesNames,
                     User = Undefined,
                     ForPrivilegedMode = True) Export
	
	SystemAdministratorRole1 = IsFullUser(User, True, ForPrivilegedMode);
	FullAccessRole          = IsFullUser(User, False,   ForPrivilegedMode);
	
	If SystemAdministratorRole1 And FullAccessRole Then
		Return True;
	EndIf;
	
	RolesNamesArray = StrSplit(RolesNames, ",", False);
	
	SystemAdministratorRoleRequired = False;
	RolesAssignment = UsersInternalCached.RolesAssignment();
	
	For Each NameOfRole In RolesNamesArray Do
		If RolesAssignment.ForSystemAdministratorsOnly.Get(NameOfRole) <> Undefined Then
			SystemAdministratorRoleRequired = True;
			Break;
		EndIf;
	EndDo;
	
	If SystemAdministratorRole1 And    SystemAdministratorRoleRequired
	 Or FullAccessRole          And Not SystemAdministratorRoleRequired Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	IBUserProperies = CheckedIBUserProperties(User);
	
	If IBUserProperies = Undefined Then
		Return False;
	EndIf;
	
	If IBUserProperies.IsCurrentIBUser Then
		For Each NameOfRole In RolesNamesArray Do
			// 
			//
			If IsInRole(TrimAll(NameOfRole)) Then
				Return True;
			EndIf;
			// 
		EndDo;
	Else
		Roles = IBUserProperies.IBUser.Roles;
		For Each NameOfRole In RolesNamesArray Do
			If Roles.Contains(Metadata.Roles.Find(TrimAll(NameOfRole))) Then
				Return True;
			EndIf;
		EndDo;
	EndIf;
	
	Return False;
	
EndFunction

// 
// 
// 
//
// Parameters:
//  IBUserDetails - UUID - infobase user ID.
//                         - Structure - 
//                             * StandardAuthentication    - Boolean - 1C:Enterprise authentication.
//                             * OSAuthentication             - Boolean - operating system authentication.
//                             * OpenIDAuthentication         - Boolean - OpenID authentication.
//                             * OpenIDConnectAuthentication  - Boolean -
//                             * AccessTokenAuthentication - Boolean -
//                         - InfoBaseUser       - 
//                         - CatalogRef.Users        - user.
//                         - CatalogRef.ExternalUsers - external user.
//
// Returns:
//  Boolean - 
//
Function CanSignIn(IBUserDetails) Export
	
	SetPrivilegedMode(True);
	
	UUID = Undefined;
	
	If TypeOf(IBUserDetails) = Type("CatalogRef.Users")
	 Or TypeOf(IBUserDetails) = Type("CatalogRef.ExternalUsers") Then
		
		UUID = Common.ObjectAttributeValue(
			IBUserDetails, "IBUserID");
		
		If TypeOf(UUID) <> Type("UUID") Then
			Return False;
		EndIf;
		
	ElsIf TypeOf(IBUserDetails) = Type("UUID") Then
		UUID = IBUserDetails;
	EndIf;
	
	If UUID <> Undefined Then
		IBUser = InfoBaseUsers.FindByUUID(UUID);
		
		If IBUser = Undefined Then
			Return False;
		EndIf;
	Else
		IBUser = IBUserDetails;
	EndIf;
	
	Return IBUser.StandardAuthentication
		Or IBUser.OpenIDAuthentication
		Or IBUser.OpenIDConnectAuthentication
		Or IBUser.AccessTokenAuthentication
		Or IBUser.OSAuthentication;
	
EndFunction

// 
// 
//
// Parameters:
//  IBUser      - InfoBaseUser
//  Interactively        - Boolean -
//                          
//  AreStartupRightsOnly - Boolean -
//                          
//
// Returns:
//  Boolean
//
Function HasRightsToLogIn(IBUser, Interactively = True, AreStartupRightsOnly = True) Export
	
	Result =
		    AccessRight("ThinClient",    Metadata, IBUser)
		Or AccessRight("WebClient",       Metadata, IBUser)
		Or AccessRight("MobileClient", Metadata, IBUser)
		Or AccessRight("ThickClient",   Metadata, IBUser);
	
	If Not Interactively Then
		Result = Result
			Or AccessRight("Automation",        Metadata, IBUser)
			Or AccessRight("ExternalConnection", Metadata, IBUser);
	EndIf;
	
	If Not AreStartupRightsOnly Then
		// ACC:515-
		Result = Result And RolesAvailable("BasicSSLRights,
			|BasicSSLRightsForExternalUsers", IBUser, False);
		// 
	EndIf;
	
	Return Result;
	
EndFunction

// Call it when starting the procedures of HTTP-services, web services, COM connections
// if they are used for remote connection of regular users
// to ensure the control of authorization restrictions (by date, by activity, and so on),
// to update the date of the last sign-in of a user, and to fill in the following session parameters:
// AuthorizedUser, CurrentUser, CurrentExternalUser.
//
// The procedure is called automatically only upon interactive sign-in,
// that is when CurrentRunMode() <> is Undefined.
//
// Parameters:
//  RaiseException1 - Boolean - throw an exception if an authorization error occurred,
//                                otherwise, return the error text.
// Returns:
//  Structure:
//   * AuthorizationError      - String - an error text if it is filled in.
//   * PasswordChangeRequired - Boolean - If True, it is a password obsolescence error.
//
Function AuthorizeTheCurrentUserWhenLoggingIn(RaiseException1 = True) Export
	
	Result = UsersInternal.AuthorizeTheCurrentUserWhenLoggingIn(True);
	
	If RaiseException1 And ValueIsFilled(Result.AuthorizationError) Then
		Raise Result.AuthorizationError;
	EndIf;
	
	Return Result;
	
EndFunction

// 
// 
// 
// 
//
// Returns:
//  Boolean
//
Function IndividualUsed() Export
	
	Return UsersInternalCached.Settings().IndividualUsed;
	
EndFunction

// 
// 
// 
// 
//
// Returns:
//  Boolean
//
Function IsDepartmentUsed() Export
	
	Return UsersInternalCached.Settings().IsDepartmentUsed;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in managed forms.

// Returns a list of users, user groups, external users,
// and external user groups.
// The function is used in the TextEditEnd and AutoComplete event handlers.
//
// Parameters:
//  Text         - String - characters entered by the user.
//
//  IncludeGroups - Boolean - If True, includes user groups and external user groups in the result.
//                  Ignored if the UseUserGroups functional option is disabled.
//
//  IncludeExternalUsers - Undefined
//                              - Boolean - 
//                  
//
//  NoUsers - Boolean - If True, the Users catalog items
//                  are excluded from the result.
//
// Returns:
//  ValueList
//
Function GenerateUserSelectionData(Val Text,
                                             Val IncludeGroups = True,
                                             Val IncludeExternalUsers = Undefined,
                                             Val NoUsers = False) Export
	
	IncludeGroups = IncludeGroups And GetFunctionalOption("UseUserGroups");
	
	Query = New Query(
		"SELECT
		|	VALUE(Catalog.Users.EmptyRef) AS Ref,
		|	"""" AS Description,
		|	-1 AS PictureNumber
		|WHERE
		|	FALSE");
	
	If Not NoUsers
	   And AccessRight("Read", Metadata.Catalogs.Users)Then
		
		QueryText =
		"SELECT
		|	Users.Ref AS Ref,
		|	Users.Description AS Description,
		|	ISNULL(UsersInfo.NumberOfStatePicture, 0) - 1 AS PictureNumber
		|FROM
		|	Catalog.Users AS Users
		|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
		|		ON UsersInfo.User = Users.Ref
		|WHERE
		|	Users.Description LIKE &Text ESCAPE ""~""
		|	AND Users.Invalid = FALSE
		|	AND Users.IsInternal = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	UserGroups.Ref,
		|	UserGroups.Description,
		|	CASE
		|		WHEN UserGroups.DeletionMark
		|			THEN 2
		|		ELSE 3
		|	END
		|FROM
		|	Catalog.UserGroups AS UserGroups
		|WHERE
		|	&IncludeGroups
		|	AND UserGroups.Description LIKE &Text ESCAPE ""~""";
		
		Query.Text = Query.Text + " UNION ALL " + QueryText;
	EndIf;
	
	Query.SetParameter("Text", Common.GenerateSearchQueryString(Text) + "%");
	Query.SetParameter("IncludeGroups", IncludeGroups);

	If TypeOf(IncludeExternalUsers) <> Type("Boolean") Then
		IncludeExternalUsers = ExternalUsers.UseExternalUsers();
	EndIf;
	IncludeExternalUsers = IncludeExternalUsers
		And AccessRight("Read", Metadata.Catalogs.ExternalUsers);
	
	If IncludeExternalUsers Then
		QueryText =
		"SELECT
		|	ExternalUsers.Ref AS Ref,
		|	ExternalUsers.Description AS Description,
		|	ISNULL(UsersInfo.NumberOfStatePicture, 0) - 1 AS PictureNumber
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
		|		ON UsersInfo.User = ExternalUsers.Ref
		|WHERE
		|	ExternalUsers.Description LIKE &Text ESCAPE ""~""
		|	AND ExternalUsers.Invalid = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsersGroups.Ref,
		|	ExternalUsersGroups.Description,
		|	CASE
		|		WHEN ExternalUsersGroups.DeletionMark
		|			THEN 8
		|		ELSE 9
		|	END
		|FROM
		|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
		|WHERE
		|	&IncludeGroups
		|	AND ExternalUsersGroups.Description LIKE &Text ESCAPE ""~""";
		
		Query.Text = Query.Text + " UNION ALL " + QueryText;
	EndIf;
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Description, ,
			PictureLib["UserState" + Format(Selection.PictureNumber + 1, "ND=2; NLZ=; NG=")]);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

// Populates user picture numbers, user groups, external users, and external user groups
// in all rows or given rows (see the RowID parameter) of a TableOrTree collection. 
// 
// Parameters:
//  TableOrTree      - FormDataCollection
//                        - FormDataTree - 
//  UserFieldName   - String - the name of the TableOrTree collection row that contains a reference to a user, 
//                                   user group, external user, or external user group.
//                                   It is the input parameter for the picture number.
//  PictureNumberFieldName - String - name of the column in the TableOrTree collection with the picture number 
//                                   that needs to be filled.
//  RowID  - Undefined
//                       - Number -  
//                                 
//                                 
//  ProcessSecondAndThirdLevelHierarchy - Boolean - If True, and the collection of the FormDataTree type is specified 
//                                 in the TableOrTree parameter, 
//                                 the fields will be filled up to the fourth tree level inclusive,
//                                 otherwise, the fields will be filled only at the first and second tree level.
//
Procedure FillUserPictureNumbers(Val TableOrTree,
                                               Val UserFieldName,
                                               Val PictureNumberFieldName,
                                               Val RowID = Undefined,
                                               Val ProcessSecondAndThirdLevelHierarchy = False) Export
	
	SetPrivilegedMode(True);
	
	If RowID = Undefined Then
		RowsArray = Undefined;
		
	ElsIf TypeOf(RowID) = Type("Array") Then
		RowsArray = New Array;
		For Each Id In RowID Do
			RowsArray.Add(TableOrTree.FindByID(Id));
		EndDo;
	Else
		RowsArray = New Array;
		RowsArray.Add(TableOrTree.FindByID(RowID));
	EndIf;
	
	If TypeOf(TableOrTree) = Type("FormDataTree") Then
		If RowsArray = Undefined Then
			RowsArray = TableOrTree.GetItems();
		EndIf;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add(UserFieldName,
			Metadata.InformationRegisters.UserGroupCompositions.Dimensions.UsersGroup.Type);
		For Each String In RowsArray Do
			UsersTable.Add()[UserFieldName] = String[UserFieldName];
			If ProcessSecondAndThirdLevelHierarchy Then
				For Each String2 In String.GetItems() Do
					UsersTable.Add()[UserFieldName] = String2[UserFieldName];
					For Each String3 In String2.GetItems() Do
						UsersTable.Add()[UserFieldName] = String3[UserFieldName];
					EndDo;
				EndDo;
			EndIf;
		EndDo;
	ElsIf TypeOf(TableOrTree) = Type("FormDataCollection") Then
		If RowsArray = Undefined Then
			RowsArray = TableOrTree;
		EndIf;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add(UserFieldName,
			Metadata.InformationRegisters.UserGroupCompositions.Dimensions.UsersGroup.Type);
		For Each String In RowsArray Do
			UsersTable.Add()[UserFieldName] = String[UserFieldName];
		EndDo;
	ElsIf TypeOf(TableOrTree) = Type("Array") Then
		RowsArray = TableOrTree;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add(UserFieldName,
			Metadata.InformationRegisters.UserGroupCompositions.Dimensions.UsersGroup.Type);
		For Each String In TableOrTree Do
			UsersTable.Add()[UserFieldName] = String[UserFieldName];
		EndDo;
	Else
		If RowsArray = Undefined Then
			RowsArray = TableOrTree;
		EndIf;
		UsersTable = TableOrTree.Unload(RowsArray, UserFieldName);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Users.UserFieldName AS User
	|INTO Users
	|FROM
	|	&Users AS Users
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Users.User AS User,
	|	CASE
	|		WHEN Users.User = UNDEFINED
	|			THEN -1
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.Users)
	|			THEN ISNULL(UsersInfo.NumberOfStatePicture, 0) - 1
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.UserGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.UserGroups).DeletionMark
	|						THEN 2
	|					ELSE 3
	|				END
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.ExternalUsers)
	|			THEN ISNULL(UsersInfo.NumberOfStatePicture, 0) - 1
	|		WHEN VALUETYPE(Users.User) = TYPE(Catalog.ExternalUsersGroups)
	|			THEN CASE
	|					WHEN CAST(Users.User AS Catalog.ExternalUsersGroups).DeletionMark
	|						THEN 8
	|					ELSE 9
	|				END
	|		ELSE -2
	|	END AS PictureNumber
	|FROM
	|	Users AS Users
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON UsersInfo.User = Users.User";
	
	Query.Text = StrReplace(Query.Text, "UserFieldName", UserFieldName);
	Query.SetParameter("Users", UsersTable);
	PicturesNumbers = Query.Execute().Unload();
	
	For Each String In RowsArray Do
		FoundRow = PicturesNumbers.Find(String[UserFieldName], "User");
		String[PictureNumberFieldName] = ?(FoundRow = Undefined, -2, FoundRow.PictureNumber);
		If ProcessSecondAndThirdLevelHierarchy Then
			For Each String2 In String.GetItems() Do
				FoundRow = PicturesNumbers.Find(String2[UserFieldName], "User");
				String2[PictureNumberFieldName] = ?(FoundRow = Undefined, -2, FoundRow.PictureNumber);
				For Each String3 In String2.GetItems() Do
					FoundRow = PicturesNumbers.Find(String3[UserFieldName], "User");
					String3[PictureNumberFieldName] = ?(FoundRow = Undefined, -2, FoundRow.PictureNumber);
				EndDo;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for infobase update.

// The procedure is used for infobase update and initial filling. It does one of the following:
// 1) Creates the first administrator and maps it to a new user
//    or an existing item of the Users catalog.
// 2) Maps the administrator that is specified in the InfobaseUser parameter to a new user
//    or an existing Users catalog item.
//
// Parameters:
//  IBUser - Undefined - create the first administrator, if it is missing.
//                 - InfoBaseUser - 
//                   
//                   
//
// Returns:
//  Undefined                  - 
//  
//                                  
//
Function CreateAdministrator(IBUser = Undefined) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		ErrorText = NStr("en = 'The ""Users"" catalog is unavailable in shared mode.';");
		Raise ErrorText;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Add administrator.
	If IBUser = Undefined Then
		IBUsers = InfoBaseUsers.GetUsers();
		
		If IBUsers.Count() = 0 Then
			If Common.DataSeparationEnabled() Then
				ErrorText =
					NStr("en = 'Cannot automatically create the first administrator of the data area.';");
				Raise ErrorText;
			EndIf;
			IBUser = InfoBaseUsers.CreateUser();
			IBUser.Name       = "Administrator";
			IBUser.FullName = IBUser.Name;
			IBUser.Roles.Clear();
			IBUser.Roles.Add(Metadata.Roles.FullAccess);
			SystemAdministratorRole = Metadata.Roles.SystemAdministrator;
			If Not IBUser.Roles.Contains(SystemAdministratorRole) Then
				IBUser.Roles.Add(SystemAdministratorRole);
			EndIf;
			IBUser.Write();
		Else
			// 
			// 
			For Each CurrentIBUser In IBUsers Do
				If UsersInternal.AdministratorRolesAvailable(CurrentIBUser) Then
					Return Undefined; // The first administrator has already been created.
				EndIf;
			EndDo;
			// 
			ErrorText =
				NStr("en = 'The list of infobase users is not blank. No users
				           |with ""Full access"" and ""System administrator"" roles are found.
				           |
				           |The users might have been created in Designer.
				           |Assign ""Full access"" and ""System administrator"" roles to at least one user.';");
			Raise ErrorText;
		EndIf;
	Else
		If Not UsersInternal.AdministratorRolesAvailable(IBUser) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create a user in the catalog
				           |mapped to the infobase user""%1""
				           |because it does not have ""Full access"" and ""System administrator"" roles.
				           |
				           |The user was probably created in Designer.
				           |To have a user created in the catalog automatically,
				           |grant the infobase user both ""Full access"" and ""System administrator"" roles.';"),
				String(IBUser));
			Raise ErrorText;
		EndIf;
		
		FindAmbiguousIBUsers(Undefined, IBUser.UUID);
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.Users");
		LockItem.SetValue("IBUserID", IBUser.UUID);
		LockItem = Block.Add("Catalog.ExternalUsers");
		LockItem.SetValue("IBUserID", IBUser.UUID);
		LockItem = Block.Add("Catalog.Users");
		LockItem.SetValue("Description", IBUser.FullName);
		Block.Lock();
		
		User = Undefined;
		UsersInternal.UserByIDExists(IBUser.UUID,, User);
		If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			ExternalUserObject = User.GetObject();
			ExternalUserObject.IBUserID = Undefined;
			InfobaseUpdate.WriteData(ExternalUserObject);
			User = Undefined;
		EndIf;

		If Not ValueIsFilled(User) Then
			User = Catalogs.Users.FindByDescription(IBUser.FullName);
			
			If ValueIsFilled(User)
			   And ValueIsFilled(User.IBUserID)
			   And User.IBUserID <> IBUser.UUID
			   And InfoBaseUsers.FindByUUID(
			         User.IBUserID) <> Undefined Then
				
				User = Undefined;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(User) Then
			User = Catalogs.Users.CreateItem();
			UserCreated = True;
		Else
			User = User.GetObject();
			UserCreated = False;
		EndIf;
		
		User.Description = IBUser.FullName;
		
		IBUserDetails = New Structure;
		IBUserDetails.Insert("Action", "Write");
		IBUserDetails.Insert("UUID", IBUser.UUID);
		User.AdditionalProperties.Insert(
			"IBUserDetails", IBUserDetails);
		User.AdditionalProperties.Insert("CreateAdministrator",
			?(IBUser = Undefined,
			  NStr("en = 'The first administrator is created.';"),
			  ?(UserCreated,
			    NStr("en = 'The administrator is mapped to a new catalog user.';"),
			    NStr("en = 'The administrator is mapped to an existing catalog user.';")) ) );
			
		User.Write();
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	Return User.Ref;
	
EndFunction

// Sets the UseUserGroups constant value to True
// if at least one user group exists in the catalog.
//
// Used upon infobase update.
//
Procedure IfUserGroupsExistSetUsage() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	UserGroups.Ref <> VALUE(Catalog.UserGroups.AllUsers)
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.Ref <> VALUE(Catalog.ExternalUsersGroups.AllExternalUsers)");
	
	If Not Query.Execute().IsEmpty() Then
		Constants.UseUserGroups.Set(True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for infobase user operations.

// Returns the "<Not specified>" text presentation when a user is not specified or not selected.
// See also Users.UnspecifiedUserRef.
//
// Returns:
//   String
//
Function UnspecifiedUserFullName() Export
	
	Return "<" + NStr("en = 'Not specified';") + ">";
	
EndFunction

// Returns a reference of an unspecified user.
// See also Users.UnspecifiedUserFullName.
//
// Parameters:
//  CreateIfDoesNotExists - Boolean - If True, the "<Not specified>" user will be created.
//
// Returns:
//  CatalogRef.Users
//  Undefined - if an unspecified user does not exist in the catalog.
//
Function UnspecifiedUserRef(CreateIfDoesNotExists = False) Export
	
	Ref = UsersInternal.UnspecifiedUserProperties().Ref;
	
	If Ref = Undefined And CreateIfDoesNotExists Then
		Ref = UsersInternal.CreateUnspecifiedUser();
	EndIf;
	
	Return Ref;
	
EndFunction

// Checks whether the infobase user is mapped to an item of the Users catalog
// or the ExternalUsers catalog.
// 
// Parameters:
//  IBUser - String - a name of an infobase user.
//                 - UUID - 
//                 - InfoBaseUser
//
//  Account  - InfoBaseUser - a return value.
//
// Returns:
//  Boolean - 
//   
//
Function IBUserOccupied(IBUser, Account = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(IBUser) = Type("String") Then
		Account = InfoBaseUsers.FindByName(IBUser);
		
	ElsIf TypeOf(IBUser) = Type("UUID") Then
		Account = InfoBaseUsers.FindByUUID(IBUser);
	Else
		Account = IBUser;
	EndIf;
	
	If Account = Undefined Then
		Return False;
	EndIf;
	
	Return UsersInternal.UserByIDExists(
		Account.UUID);
	
EndFunction

// Returns an empty structure that describes infobase user properties.
// The purpose of the structure properties corresponds to the properties of the InfobaseUser object.
//
// Returns:
//  Structure:
//   * UUID   - UUID - an infobase user UUID.
//   * Name                       - String - the name of an infobase user. For example, "Smith".
//   * FullName                 - String - Full name of an infobase user. 
//                                          For example, "John Smith (Sales Manager)".
//   * Email     - String -
//
//   * StandardAuthentication      - Boolean - the flag that indicates whether user name and password authentication is allowed.
//   * ShowInList        - Boolean - the flag that indicates whether to show the full user name in the list at startup.
//   * Password                         - String -
//                                    - Undefined - 
//   * StoredPasswordValue      - String -
//                                    - Undefined - 
//   * PasswordIsSet               - Boolean - the flag that indicates whether the user has a password.
//   * CannotChangePassword        - Boolean - the flag that indicates whether the user can change the password.
//   * CannotRecoveryPassword - Boolean -
//
//   * OpenIDAuthentication         - Boolean -
//   * OpenIDConnectAuthentication  - Boolean -
//   * AccessTokenAuthentication - Boolean -
//
//   * OSAuthentication          - Boolean - the flag that indicates whether authentication by the means of OS is allowed.
//   * OSUser            - String - the name of the OS user associated to the application user. 
//                                          Not applicable for the training version of the platform.
//
//   * DefaultInterface         - String -
//                                         
//                               - Undefined
//   * RunMode              - String -
//                               - Undefined
//   * Language                      - String -
//                               - Undefined
//   * Roles                      - Array -
//                               - Undefined - roles are not specified.
//
//   * UnsafeActionProtection   - Boolean -
//                                   
//
Function NewIBUserDetails() Export
	
	// Preparing the data structure for storing the return value.
	Properties = New Structure;
	
	Properties.Insert("UUID", CommonClientServer.BlankUUID());
	
	Properties.Insert("Name",                            "");
	Properties.Insert("FullName",                      "");
	Properties.Insert("Email",          "");
	Properties.Insert("StandardAuthentication",      False);
	Properties.Insert("ShowInList",        False);
	Properties.Insert("PreviousPassword",                   Undefined);
	Properties.Insert("Password",                         Undefined);
	Properties.Insert("StoredPasswordValue",      Undefined);
	Properties.Insert("PasswordIsSet",               False);
	Properties.Insert("CannotChangePassword",        False);
	Properties.Insert("CannotRecoveryPassword", True);
	Properties.Insert("OpenIDAuthentication",           False);
	Properties.Insert("OpenIDConnectAuthentication",    False);
	Properties.Insert("AccessTokenAuthentication",   False);
	Properties.Insert("OSAuthentication",               False);
	Properties.Insert("OSUser",                 "");
	
	Properties.Insert("DefaultInterface",
		?(Metadata.DefaultInterface = Undefined, "", Metadata.DefaultInterface.Name));
	
	Properties.Insert("RunMode",              "Auto");
	
	Properties.Insert("Language",
		?(Metadata.DefaultLanguage = Undefined, "", Metadata.DefaultLanguage.Name));
	
	Properties.Insert("Roles", Undefined);
	
	Properties.Insert("UnsafeActionProtection", True);
	
	Return Properties;
	
EndFunction

// Returns an infobase user properties as a structure.
// If a user with the specified ID or name does not exist, Undefined is returned.
//
// Parameters:
//  NameOrID  - String
//                       - UUID - 
//
// Returns:
//  Structure, Undefined - See Users.NewIBUserDetails.
//                            
//
Function IBUserProperies(Val NameOrID) Export
	
	CommonClientServer.CheckParameter("Users.IBUserProperies", "NameOrID",
		NameOrID, New TypeDescription("String, UUID"));
		 
	Properties = NewIBUserDetails();
	Properties.Roles = New Array;
	
	If TypeOf(NameOrID) = Type("UUID") Then
		
		If Common.SubsystemExists("CloudTechnology.Core") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			SessionWithoutSeparators = ModuleSaaSOperations.SessionWithoutSeparators();
		Else
			SessionWithoutSeparators = True;
		EndIf;
		
		If Common.DataSeparationEnabled()
		   And SessionWithoutSeparators
		   And Common.SeparatedDataUsageAvailable()
		   And NameOrID = InfoBaseUsers.CurrentUser().UUID Then
			
			IBUser = InfoBaseUsers.CurrentUser();
		Else
			IBUser = InfoBaseUsers.FindByUUID(NameOrID);
		EndIf;
		
	ElsIf TypeOf(NameOrID) = Type("String") Then
		IBUser = InfoBaseUsers.FindByName(NameOrID);
	Else
		IBUser = Undefined;
	EndIf;
	
	If IBUser = Undefined Then
		Return Undefined;
	EndIf;
	
	CopyIBUserProperties(Properties, IBUser);
	Properties.Insert("IBUser", IBUser);
	Return Properties;
	
EndFunction

// Writes new property values of the specified infobase user or creates a new infobase user.
// An exception will be called if a user does not exist and also on attempts to create an existing user.
//
// Parameters:
//  NameOrID - String
//                      - UUID -  
//                                                  
//  PropertiesToUpdate - See Users.NewIBUserDetails.
//
//  CreateNewOne - Boolean - specify True to create a new infobase user called NameOrID.
//
//  IsExternalUser - Boolean - specify True if the infobase user corresponds to an external user
//                                    (the ExternalUsers item in the directory).
//
Procedure SetIBUserProperies(Val NameOrID, Val PropertiesToUpdate,
	Val CreateNewOne = False, Val IsExternalUser = False) Export
	
	ProcedureName = "Users.SetIBUserProperies";
	
	CommonClientServer.CheckParameter(ProcedureName, "NameOrID",
		NameOrID, New TypeDescription("String, UUID"));
	
	CommonClientServer.CheckParameter(ProcedureName, "PropertiesToUpdate",
		PropertiesToUpdate, Type("Structure"));
	
	CommonClientServer.CheckParameter(ProcedureName, "CreateNewOne",
		CreateNewOne, Type("Boolean"));
	
	CommonClientServer.CheckParameter(ProcedureName, "IsExternalUser",
		IsExternalUser, Type("Boolean"));
	
	PreviousProperties = IBUserProperies(NameOrID);
	UserExists = PreviousProperties <> Undefined;
	If UserExists Then
		IBUser = PreviousProperties.IBUser;
	Else
		IBUser = Undefined;
		PreviousProperties = NewIBUserDetails();
	EndIf;
		
	If Not UserExists Then
		If Not CreateNewOne Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Infobase user ""%1"" does not exist.';"),
				NameOrID);
			Raise ErrorText;
		EndIf;
		IBUser = InfoBaseUsers.CreateUser();
	Else
		If CreateNewOne Then
			ErrorText = ErrorDescriptionOnWriteIBUser(
				NStr("en = 'Cannot create infobase user ""%1"". The user already exists.';"),
				PreviousProperties.Name,
				PreviousProperties.UUID);
			Raise ErrorText;
		EndIf;
		
		If PropertiesToUpdate.Property("PreviousPassword")
		   And TypeOf(PropertiesToUpdate.PreviousPassword) = Type("String") Then
			
			PreviousPasswordMatches = UsersInternal.PreviousPasswordMatchSaved(
				PropertiesToUpdate.PreviousPassword, PreviousProperties.UUID);
			
			If Not PreviousPasswordMatches Then
				ErrorText = ErrorDescriptionOnWriteIBUser(
					NStr("en = 'Couldn''t save infobase user ""%1"". The previous password is incorrect.';"),
					PreviousProperties.Name,
					PreviousProperties.UUID);
				Raise ErrorText;
			EndIf;
		EndIf;
	EndIf;
	
	// Preparing new property values.
	SetPassword = False;
	NewProperties = Common.CopyRecursive(PreviousProperties);
	For Each KeyAndValue In NewProperties Do
		If Not PropertiesToUpdate.Property(KeyAndValue.Key)
		 Or PropertiesToUpdate[KeyAndValue.Key] = Undefined Then
			Continue;
		EndIf;
		If KeyAndValue.Key <> "Password" Then
			NewProperties[KeyAndValue.Key] = PropertiesToUpdate[KeyAndValue.Key];
			Continue;
		EndIf;
		If PropertiesToUpdate.Property("StoredPasswordValue")
		   And PropertiesToUpdate.StoredPasswordValue <> Undefined
		 Or StandardSubsystemsServer.IsTrainingPlatform() Then
			Continue;
		EndIf;
		SetPassword = True;
	EndDo;
	
	CopyIBUserProperties(IBUser, NewProperties);
	
	UsersInternal.SetPasswordPolicy(IBUser, IsExternalUser);
	
	If SetPassword Then
		PasswordErrorText = UsersInternal.PasswordComplianceError(
			PropertiesToUpdate.Password, IBUser);
		
		If ValueIsFilled(PasswordErrorText) Then
			ErrorText = ErrorDescriptionOnWriteIBUser(
				NStr("en = 'Couldn''t save properties of infobase user ""%1"". Reason:
				           |%2.';"),
				IBUser.Name,
				?(UserExists, PreviousProperties.UUID, Undefined),
				PasswordErrorText);
			Raise ErrorText;
		EndIf;
		IBUser.StoredPasswordValue =
			UsersInternal.PasswordHashString(PropertiesToUpdate.Password, True);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		IBUser.ShowInList = False;
	EndIf;
	
	// Attempt to write a new infobase user or edit an existing one.
	Try
		UsersInternal.WriteInfobaseUser(IBUser, IsExternalUser);
	Except
		ErrorText = ErrorDescriptionOnWriteIBUser(
			NStr("en = 'Couldn''t save properties of infobase user ""%1"". Reason:
			           |%2.';"),
			IBUser.Name,
			?(UserExists, PreviousProperties.UUID, Undefined),
			ErrorInfo());
		Raise ErrorText;
	EndTry;
	
	If ValueIsFilled(PreviousProperties.Name) And PreviousProperties.Name <> NewProperties.Name Then
		// 
		UsersInternal.CopyUserSettings(PreviousProperties.Name, NewProperties.Name, True);
	EndIf;
	
	If CreateNewOne Then
		UsersInternal.SetInitialSettings(IBUser.Name, IsExternalUser);
	EndIf;
	
	UsersOverridable.OnWriteInfobaseUser(PreviousProperties, NewProperties);
	PropertiesToUpdate.Insert("UUID", IBUser.UUID);
	PropertiesToUpdate.Insert("IBUser", IBUser);
	
EndProcedure

// Deletes the specified infobase user.
//
// Parameters:
//  NameOrID  - String
//                       - UUID - 
//
Procedure DeleteIBUser(Val NameOrID) Export
	
	CommonClientServer.CheckParameter("Users.DeleteIBUser", "NameOrID",
		NameOrID, New TypeDescription("String, UUID"));
		
	DeletedIBUserProperties = IBUserProperies(NameOrID);
	If DeletedIBUserProperties = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Infobase user ""%1"" does not exist.';"),
			NameOrID);
		Raise ErrorText;
	EndIf;
	IBUser = DeletedIBUserProperties.IBUser;
		
	Try
		
		SSLSubsystemsIntegration.BeforeDeleteIBUser(IBUser);
		IBUser.Delete();
		
	Except
		ErrorText = ErrorDescriptionOnWriteIBUser(
			NStr("en = 'Cannot delete infobase user ""%1"". Reason:
			           |%2.';"),
			IBUser.Name,
			IBUser.UUID,
			ErrorInfo());
		Raise ErrorText;
	EndTry;
	UsersOverridable.AfterDeleteInfobaseUser(DeletedIBUserProperties);
	
EndProcedure

// 
// 
// 
//
//  
//
//  
// 
//
//  
// 
// 
// 
//
//  
// 
//
//  
// 
//
// Parameters:
//  Receiver     - Structure
//               - InfoBaseUser
//               - ClientApplicationForm - 
//                 
//
//  Source     - Structure
//               - InfoBaseUser
//               - ClientApplicationForm - 
//                 
//                 
// 
//  PropertiesToCopy  - String - the list of comma-separated properties to copy (without the prefix).
//  PropertiesToExclude - String - the list of comma-separated properties to exclude from copying (without the prefix).
//  PropertyPrefix      - String - the initial name for Source or Target if its type is NOT structure.
//
Procedure CopyIBUserProperties(Receiver,
                                            Source,
                                            PropertiesToCopy = "",
                                            PropertiesToExclude = "",
                                            PropertyPrefix = "") Export
	
	If TypeOf(Receiver) = Type("InfoBaseUser")
	   And TypeOf(Source) = Type("InfoBaseUser")
	   
	 Or TypeOf(Receiver) = Type("InfoBaseUser")
	   And TypeOf(Source) <> Type("Structure")
	   And TypeOf(Source) <> Type("ClientApplicationForm")
	   
	 Or TypeOf(Source) = Type("InfoBaseUser")
	   And TypeOf(Receiver) <> Type("Structure")
	   And TypeOf(Receiver) <> Type("ClientApplicationForm") Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of parameter %1 or %2.
			           |Common module: %4. Procedure: %3.';"),
			"Receiver",
			"Source",
			"CopyIBUserProperties",
			"Users");
		Raise ErrorText;
	EndIf;
	
	AllProperties = NewIBUserDetails();
	
	If ValueIsFilled(PropertiesToCopy) Then
		CopiedPropertiesStructure = New Structure(PropertiesToCopy);
	Else
		CopiedPropertiesStructure = AllProperties;
	EndIf;
	
	If ValueIsFilled(PropertiesToExclude) Then
		ExcludedPropertiesStructure = New Structure(PropertiesToExclude);
	Else
		ExcludedPropertiesStructure = New Structure;
	EndIf;
	
	If StandardSubsystemsServer.IsTrainingPlatform() Then
		ExcludedPropertiesStructure.Insert("OSAuthentication");
		ExcludedPropertiesStructure.Insert("OSUser");
	EndIf;
	
	PasswordIsSet = False;
	
	For Each KeyAndValue In AllProperties Do
		Property = KeyAndValue.Key;
		
		If Not CopiedPropertiesStructure.Property(Property)
		 Or ExcludedPropertiesStructure.Property(Property) Then
		
			Continue;
		EndIf;
		
		If TypeOf(Source) = Type("InfoBaseUser")
		   And (    TypeOf(Receiver) = Type("Structure")
		      Or TypeOf(Receiver) = Type("ClientApplicationForm") ) Then
			
			If Property = "Password"
			 Or Property = "PreviousPassword" Then
				
				PropertyValue = Undefined;
				
			ElsIf Property = "DefaultInterface" Then
				PropertyValue = ?(Source.DefaultInterface = Undefined,
				                     "",
				                     Source.DefaultInterface.Name);
			
			ElsIf Property = "RunMode" Then
				ValueFullName = GetPredefinedValueFullName(Source.RunMode);
				PropertyValue = Mid(ValueFullName, StrFind(ValueFullName, ".") + 1);
				
			ElsIf Property = "Language" Then
				PropertyValue = ?(Source.Language = Undefined,
				                     "",
				                     Source.Language.Name);
				
			ElsIf Property = "UnsafeActionProtection" Then
				PropertyValue =
					Source.UnsafeOperationProtection.UnsafeOperationWarnings;
				
			ElsIf Property = "Roles" Then
				
				TempStructure = New Structure("Roles", New ValueTable);
				FillPropertyValues(TempStructure, Receiver);
				If TypeOf(TempStructure.Roles) = Type("ValueTable") Then
					Continue;
				ElsIf TempStructure.Roles = Undefined Then
					Receiver.Roles = New Array;
				Else
					Receiver.Roles.Clear();
				EndIf;
				
				For Each Role In Source.Roles Do
					Receiver.Roles.Add(Role.Name);
				EndDo;
				
				Continue;
			Else
				PropertyValue = Source[Property];
			EndIf;
			
			PropertyFullName = PropertyPrefix + Property;
			TempStructure = New Structure(PropertyFullName, PropertyValue);
			FillPropertyValues(Receiver, TempStructure);
		Else
			If TypeOf(Source) = Type("Structure") Then
				If Source.Property(Property) Then
					PropertyValue = Source[Property];
				Else
					Continue;
				EndIf;
			Else
				PropertyFullName = PropertyPrefix + Property;
				TempStructure = New Structure(PropertyFullName, New ValueTable);
				FillPropertyValues(TempStructure, Source);
				PropertyValue = TempStructure[PropertyFullName];
				If TypeOf(PropertyValue) = Type("ValueTable") Then
					Continue;
				EndIf;
			EndIf;
			
			If TypeOf(Receiver) = Type("InfoBaseUser") Then
			
				If Property = "UUID"
				 Or Property = "PreviousPassword"
				 Or Property = "PasswordIsSet" Then
					
					Continue;
					
				ElsIf Property = "StandardAuthentication"
				      Or Property = "OpenIDAuthentication"
				      Or Property = "OpenIDConnectAuthentication"
				      Or Property = "AccessTokenAuthentication"
				      Or Property = "OSAuthentication"
				      Or Property = "OSUser" Then
					
					If Receiver[Property] <> PropertyValue Then
						Receiver[Property] = PropertyValue;
					EndIf;
					
				ElsIf Property = "Password" Then
					If PropertyValue <> Undefined Then
						Receiver.Password = PropertyValue;
						PasswordIsSet = True;
					EndIf;
					
				ElsIf Property = "StoredPasswordValue" Then
					If PropertyValue <> Undefined
					   And Not PasswordIsSet
					   And Receiver.StoredPasswordValue <> PropertyValue Then
						Receiver.StoredPasswordValue = PropertyValue;
					EndIf;
					
				ElsIf Property = "DefaultInterface" Then
					If TypeOf(PropertyValue) = Type("String") Then
						Receiver.DefaultInterface = Metadata.Interfaces.Find(PropertyValue);
					Else
						Receiver.DefaultInterface = Undefined;
					EndIf;
				
				ElsIf Property = "RunMode" Then
					If PropertyValue = "Auto"
					 Or PropertyValue = "OrdinaryApplication"
					 Or PropertyValue = "ManagedApplication" Then
						
						Receiver.RunMode = ClientRunMode[PropertyValue];
					Else
						Receiver.RunMode = ClientRunMode.Auto;
					EndIf;
					
				ElsIf Property = "UnsafeActionProtection" Then
					Receiver.UnsafeOperationProtection.UnsafeOperationWarnings =
						PropertyValue;
					
				ElsIf Property = "Language" Then
					If TypeOf(PropertyValue) = Type("String") Then
						Receiver.Language = Metadata.Languages.Find(PropertyValue);
					Else
						Receiver.Language = Undefined;
					EndIf;
					
				ElsIf Property = "Roles" Then
					Receiver.Roles.Clear();
					If PropertyValue <> Undefined Then
						For Each NameOfRole In PropertyValue Do
							Role = Metadata.Roles.Find(NameOfRole);
							If Role <> Undefined Then
								Receiver.Roles.Add(Role);
							EndIf;
						EndDo;
					EndIf;
				Else
					If Property = "Name"
					   And Receiver[Property] <> PropertyValue Then
					
						If StrLen(PropertyValue) > 64 Then
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Couldn''t save the infobase user.
								           |The username ""%1""
								           |exceeds the limit of 64 characters.';"),
								PropertyValue);
							Raise ErrorText;
							
						ElsIf StrFind(PropertyValue, ":") > 0 Then
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Couldn''t save the infobase user.
								           |The username ""%1""
								           |contains an illegal character (colon).';"),
								PropertyValue);
							Raise ErrorText;
						EndIf;
					EndIf;
					Receiver[Property] = Source[Property];
				EndIf;
			Else
				If Property = "Roles" Then
					
					TempStructure = New Structure("Roles", New ValueTable);
					FillPropertyValues(TempStructure, Receiver);
					If TypeOf(TempStructure.Roles) = Type("ValueTable") Then
						Continue;
					ElsIf TempStructure.Roles = Undefined Then
						Receiver.Roles = New Array;
					Else
						Receiver.Roles.Clear();
					EndIf;
					
					If Source.Roles <> Undefined Then
						For Each Role In Source.Roles Do
							Receiver.Roles.Add(Role.Name);
						EndDo;
					EndIf;
					Continue;
					
				ElsIf TypeOf(Source) = Type("Structure") Then
					PropertyFullName = PropertyPrefix + Property;
				Else
					PropertyFullName = Property;
				EndIf;
				TempStructure = New Structure(PropertyFullName, PropertyValue);
				FillPropertyValues(Receiver, TempStructure);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// 
// 
// 
// Parameters:
//  LoginName - String - the user name for infobase authentication.
//
// Returns:
//  CatalogRef.Users           - 
//  
//  
//  
//
Function FindByName(Val LoginName) Export
	
	SetPrivilegedMode(True);
	
	IBUser = InfoBaseUsers.FindByName(LoginName);
	If IBUser = Undefined Then
		Return Undefined;
	EndIf;
	
	User = FindByID(IBUser.UUID);
	If User = Undefined Then
		User = PredefinedValue("Catalog.Users.EmptyRef");
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return User;
	
EndFunction

// 
// 
// 
// 
// Parameters:
//  IBUserID - UUID -
//
// Returns:
//  CatalogRef.Users           - 
//  
//  
//
Function FindByID(Val IBUserID) Export
	
	If TypeOf(IBUserID) <> Type("UUID") Then
		Return Undefined;
	EndIf;
	
	User = Undefined;
	
	SetPrivilegedMode(True);
	UsersInternal.UserByIDExists(
		IBUserID,, User);
	SetPrivilegedMode(False);
	
	Return User;
	
EndFunction

// 
//  
// 
// 
// Parameters:
//  User -  
//
// Returns:
//  InfoBaseUser - 
//  
//
Function FindByReference(User) Export
	
	SetPrivilegedMode(True);
	IBUserID = Common.ObjectAttributeValue(User,
		"IBUserID");
	SetPrivilegedMode(False);
	
	If TypeOf(IBUserID) <> Type("UUID") Then
		Return Undefined;
	EndIf;
	
	Return InfoBaseUsers.FindByUUID(IBUserID);
	
EndFunction

// Searches for infobase user IDs that are used more than once
// and either raises an exception or returns the list of found infobase
// users.
//
// Parameters:
//  User - Undefined - checking all users and external users.
//               - CatalogRef.Users
//               - CatalogRef.ExternalUsers - 
//                 
//
//  UUID - Undefined - checking all infobase user IDs.
//                          - UUID - 
//
//  FoundIDs - Undefined - If errors found, throws an exception.
//                            If a mapping is passed, don't throw an exception if errors found.
//                            Instead, populate the mapping.
//                          - Map of KeyAndValue:
//                              * Key     - UUID - Undefined user ID.
//                              * Value - Array of CatalogRef.Users, CatalogRef.ExternalUsers
//
//  ServiceUserID - Boolean - If False, check IBUserID.
//                                              If True, check ServiceUserID.
//
Procedure FindAmbiguousIBUsers(Val User,
                                            Val UUID = Undefined,
                                            Val FoundIDs = Undefined,
                                            Val ServiceUserID = False) Export
	
	SetPrivilegedMode(True);
	BlankUUID = CommonClientServer.BlankUUID();
	
	If TypeOf(UUID) <> Type("UUID")
	 Or UUID = BlankUUID Then
		
		UUID = Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("BlankUUID", BlankUUID);
	
	If User = Undefined And UUID = Undefined Then
		Query.Text =
		"SELECT
		|	Users.IBUserID AS AmbiguousID
		|FROM
		|	Catalog.Users AS Users
		|
		|GROUP BY
		|	Users.IBUserID
		|
		|HAVING
		|	Users.IBUserID <> &BlankUUID AND
		|	COUNT(Users.Ref) > 1
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.IBUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|
		|GROUP BY
		|	ExternalUsers.IBUserID
		|
		|HAVING
		|	ExternalUsers.IBUserID <> &BlankUUID AND
		|	COUNT(ExternalUsers.Ref) > 1
		|
		|UNION ALL
		|
		|SELECT
		|	Users.IBUserID
		|FROM
		|	Catalog.Users AS Users
		|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
		|		ON (ExternalUsers.IBUserID = Users.IBUserID)
		|			AND (Users.IBUserID <> &BlankUUID)";
		
	ElsIf UUID <> Undefined Then
		
		Query.SetParameter("UUID", UUID);
		Query.Text =
		"SELECT
		|	Users.IBUserID AS AmbiguousID
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.IBUserID = &UUID
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.IBUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.IBUserID = &UUID";
	Else
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	Users.IBUserID AS AmbiguousID
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.IBUserID IN
		|			(SELECT
		|				CatalogUsers.IBUserID
		|			FROM
		|				Catalog.Users AS CatalogUsers
		|			WHERE
		|				CatalogUsers.Ref = &User
		|				AND CatalogUsers.IBUserID <> &BlankUUID)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUsers.IBUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.IBUserID IN
		|			(SELECT
		|				CatalogUsers.IBUserID
		|			FROM
		|				Catalog.Users AS CatalogUsers
		|			WHERE
		|				CatalogUsers.Ref = &User
		|				AND CatalogUsers.IBUserID <> &BlankUUID)";
		
		If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			Query.Text = StrReplace(Query.Text,
				"Catalog.Users AS CatalogUsers",
				"Catalog.ExternalUsers AS CatalogUsers");
		EndIf;
	EndIf;
	
	If ServiceUserID Then
		Query.Text = StrReplace(Query.Text,
			"IBUserID",
			"ServiceUserID");
	EndIf;
	
	Upload0 = Query.Execute().Unload();
	
	If User = Undefined And UUID = Undefined Then
		If Upload0.Count() = 0 Then
			Return;
		EndIf;
	Else
		If Upload0.Count() < 2 Then
			Return;
		EndIf;
	EndIf;
	
	AmbiguousIDs = Upload0.UnloadColumn("AmbiguousID");
	
	Query = New Query;
	Query.SetParameter("AmbiguousIDs", AmbiguousIDs);
	Query.Text =
	"SELECT
	|	AmbiguousIDs.AmbiguousID AS AmbiguousID,
	|	AmbiguousIDs.User AS User
	|FROM
	|	(SELECT
	|		Users.IBUserID AS AmbiguousID,
	|		Users.Ref AS User
	|	FROM
	|		Catalog.Users AS Users
	|	WHERE
	|		Users.IBUserID IN(&AmbiguousIDs)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ExternalUsers.IBUserID,
	|		ExternalUsers.Ref
	|	FROM
	|		Catalog.ExternalUsers AS ExternalUsers
	|	WHERE
	|		ExternalUsers.IBUserID IN(&AmbiguousIDs)) AS AmbiguousIDs
	|
	|ORDER BY
	|	AmbiguousIDs.AmbiguousID,
	|	AmbiguousIDs.User";
	
	Upload0 = Query.Execute().Unload();
	
	ErrorDescription = "";
	CurrentAmbiguousID = Undefined;
	
	For Each String In Upload0 Do
		If String.AmbiguousID <> CurrentAmbiguousID Then
			CurrentAmbiguousID = String.AmbiguousID;
			If TypeOf(FoundIDs) = Type("Map") Then
				CurrentUsers = New Array;
				FoundIDs.Insert(CurrentAmbiguousID, CurrentUsers);
			Else
				CurrentIBUser = InfoBaseUsers.CurrentUser();
				
				If CurrentIBUser.UUID <> CurrentAmbiguousID Then
					CurrentIBUser =
						InfoBaseUsers.FindByUUID(
							CurrentAmbiguousID);
				EndIf;
				
				If CurrentIBUser = Undefined Then
					LoginName = "<" + NStr("en = 'not found';") + ">";
				Else
					LoginName = CurrentIBUser.Name;
				EndIf;
				
				If ServiceUserID Then
					ErrorDescription = ErrorDescription + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The service user with ID ""%1""
						           |is mapped to multiple catalog items:';"),
						CurrentAmbiguousID);
				Else
					ErrorDescription = ErrorDescription + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Infobase user ""%1"" with ID ""%2""
						           |is mapped to multiple catalog items:';"),
						LoginName,
						CurrentAmbiguousID);
				EndIf;
				ErrorDescription = ErrorDescription + Chars.LF;
			EndIf;
		EndIf;
		
		If TypeOf(FoundIDs) = Type("Map") Then
			CurrentUsers.Add(String.User);
		Else
			ErrorDescription = ErrorDescription + "- "
				+ StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '""%1"" %2';"),
					String.User,
					GetURL(String.User)) + Chars.LF;
		EndIf;
	EndDo;
	
	If TypeOf(FoundIDs) <> Type("Map") Then
		Raise ErrorDescription;
	EndIf;
	
EndProcedure

// Returns a password hash.
//
// Parameters:
//  Password - String - a password for which it is required to get a password hash.
//
// Returns:
//  String - 
//
Function PasswordHashString(Val Password) Export
	
	Return UsersInternal.PasswordHashString(Password);
	
EndFunction

// Generates a new password matching the set rules of complexity checking.
// For easier memorization, a password is formed from syllables (consonant-vowel).
//
// Parameters:
//  PasswordProperties - See PasswordProperties
//                 
//  DeleteIsComplex         - Boolean -
//  DeleteConsiderSettings - String -
//
// Returns:
//  String - 
//
Function CreatePassword(Val PasswordProperties = 7, DeleteIsComplex = False, DeleteConsiderSettings = "ForUsers") Export
	
	If TypeOf(PasswordProperties) = Type("Number") Then
		MinLength = PasswordProperties; 
		PasswordProperties = PasswordProperties();
		PasswordProperties.MinLength = MinLength;
		PasswordProperties.Complicated = DeleteIsComplex;
		PasswordProperties.ConsiderSettings = DeleteConsiderSettings;
	EndIf;
	
	If PasswordProperties.ConsiderSettings = "ForExternalUsers"
	 Or PasswordProperties.ConsiderSettings = "ForUsers" Then
		
		PasswordPolicyName = UsersInternal.PasswordPolicyName(
			PasswordProperties.ConsiderSettings = "ForExternalUsers");
		
		SetPrivilegedMode(True);
		PasswordPolicy = UserPasswordPolicies.FindByName(PasswordPolicyName);
		If PasswordPolicy = Undefined Then
			MinPasswordLength = GetUserPasswordMinLength();
			ComplexPassword          = GetUserPasswordStrengthCheck();
		Else
			MinPasswordLength = PasswordPolicy.PasswordMinLength;
			ComplexPassword          = PasswordPolicy.PasswordStrengthCheck;

		EndIf;
		SetPrivilegedMode(False);
		If MinPasswordLength < PasswordProperties.MinLength Then
			MinPasswordLength = PasswordProperties.MinLength;
		EndIf;
		If Not ComplexPassword And PasswordProperties.Complicated Then
			ComplexPassword = True;
		EndIf;
	Else
		MinPasswordLength = PasswordProperties.MinLength;
		ComplexPassword = PasswordProperties.Complicated;
	EndIf;
	
	PasswordParameters = UsersInternal.PasswordParameters(MinPasswordLength, ComplexPassword);
	
	Return UsersInternal.CreatePassword(PasswordParameters, PasswordProperties.RNG);
	
EndFunction

// 
// 
// Returns:
//   Structure:
//     * MinLength - Number - the smallest password length.
//     * Complicated - Boolean - consider password complexity requirements.
//     * ConsiderSettings - String -
//             "DontConsiderSettings" - do not consider administrator settings,
//             "ForUsers" - consider settings for users (by default),
//             "ForExternalUsers" - consider settings for external users.
//             If administrator settings are considered, the specified password
//             length and complexity parameters will be increased to the values ​​specified in the settings.
//     * RNG - RandomNumberGenerator - if you are already using.
//           - Undefined - 
//
Function PasswordProperties() Export
	
	Result = New Structure;
	Result.Insert("MinLength", 7);
	Result.Insert("Complicated", False);
	Result.Insert("ConsiderSettings", "ForUsers");
	
	Milliseconds = CurrentUniversalDateInMilliseconds();
	BeginningNumber = Milliseconds - Int(Milliseconds / 40) * 40;
	RNG = New RandomNumberGenerator(BeginningNumber);
	
	Result.Insert("RNG", RNG);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Defines if a configuration supports common authentication settings, such as:
// password complexity, password change, application usage time limits, and others.
// See the CommonAuthorizationSettings property in UsersOverridable.OnDefineSettings.
//
// Returns:
//  Boolean - 
//
Function CommonAuthorizationSettingsUsed() Export
	
	Return UsersInternalCached.Settings().CommonAuthorizationSettings;
	
EndFunction

// Returns roles assignment specified by the library and application developers.
// Area of application: only for automatized configuration check.
//
// Returns:
//  Structure - 
//              
//
Function RolesAssignment() Export
	
	RolesAssignment = New Structure;
	RolesAssignment.Insert("ForSystemAdministratorsOnly",                New Array);
	RolesAssignment.Insert("ForSystemUsersOnly",                  New Array);
	RolesAssignment.Insert("ForExternalUsersOnly",                  New Array);
	RolesAssignment.Insert("BothForUsersAndExternalUsers", New Array);
	
	UsersOverridable.OnDefineRoleAssignment(RolesAssignment);
	SSLSubsystemsIntegration.OnDefineRoleAssignment(RolesAssignment);
	
	For Each Role In Metadata.Roles Do
		Extension = Role.ConfigurationExtension();
		If Extension = Undefined Then
			Continue;
		EndIf;
		NameOfRole = Role.Name;
		
		If StrEndsWith(Upper(NameOfRole), Upper("CommonRights")) Then
			RolesAssignment.BothForUsersAndExternalUsers.Add(NameOfRole);
			
		ElsIf StrEndsWith(Upper(NameOfRole), Upper("BasicAccessExternalUsers")) Then
			RolesAssignment.ForExternalUsersOnly.Add(NameOfRole);
			
		ElsIf StrEndsWith(Upper(NameOfRole), Upper("SystemAdministrator")) Then
			RolesAssignment.ForSystemAdministratorsOnly.Add(NameOfRole);
		EndIf;
	EndDo;
	
	Return RolesAssignment;
	
EndFunction

// Checks whether the rights of roles match the role assignments 
// specified in the OnDefineRolesAssignment procedure of the UsersOverridable common module.
//
// It is applied if:
//  - the security of configuration is checked before updating it to a new version automatically;
//  - the configuration is checked before assembling;
//  - the configuration is checked when developing.
//
// Parameters:
//  CheckEverything - Boolean - If False, the role assignment check is skipped
//                          according to the requirements of the service technologies (which is faster), otherwise
//                          the check is performed if separation is enabled.
//
//  ErrorList - Undefined   - If errors are found, the text of errors is generated and an exception is called.
//               - ValueList - 
//                   * Value      - String - a role name.
//                                   - Undefined - 
//                   * Presentation - String - error text.
//
Procedure CheckRoleAssignment(CheckEverything = False, ErrorList = Undefined) Export
	
	RolesAssignment = UsersInternalCached.RolesAssignment();
	
	UsersInternal.CheckRoleAssignment(RolesAssignment, CheckEverything, ErrorList);
	
EndProcedure

// Adds system administrators to the access group
// connected with the predefined OpenExternalReportsAndDataProcessors profile.
// Hides the security warnings that pop-up upon the first start of the administrator session.
// Not for the SaaS mode.
//
// Parameters:
//   OpenAllowed - Boolean - If True, set opening permission.
//
Procedure SetExternalReportsAndDataProcessorsOpenRight(OpenAllowed) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	AdministrationParameters.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", True);
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetExternalReportsAndDataProcessorsOpenRight(OpenAllowed);
		Return;
	EndIf;
	
	SystemAdministratorRole1 = Metadata.Roles.SystemAdministrator;
	InteractiveOpeningRole = Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors;
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each IBUser In IBUsers Do
		
		If Not IBUser.Roles.Contains(SystemAdministratorRole1) Then
			Continue;
		EndIf;
		
		UserChanged = False;
		HasInteractiveOpeningRole = IBUser.Roles.Contains(InteractiveOpeningRole);
		If OpenAllowed Then 
			If Not HasInteractiveOpeningRole Then 
				IBUser.Roles.Add(InteractiveOpeningRole);
				UserChanged = True;
			EndIf;
		Else 
			If HasInteractiveOpeningRole Then
				IBUser.Roles.Delete(InteractiveOpeningRole);
				UserChanged = True;
			EndIf;
		EndIf;
		If UserChanged Then 
			IBUser.Write();
		EndIf;
		
		SettingsDescription = New SettingsDescription;
		SettingsDescription.Presentation = NStr("en = 'Security warning';");
		Common.CommonSettingsStorageSave(
			"SecurityWarning", 
			"UserAccepts", 
			True, 
			SettingsDescription, 
			IBUser.Name);
		
	EndDo;
	
EndProcedure

// 
// 
// 
// Parameters:
//  CommonSettingsToSave - See Users.CommonAuthorizationSettingsNewDetails
//
Procedure SetCommonAuthorizationSettings(CommonSettingsToSave) Export
	
	Block = New DataLock();
	Block.Add("Constant.UserAuthorizationSettings");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		LogonSettings = UsersInternal.LogonSettings();
		Settings = LogonSettings.Overall;
		
		For Each SettingToSave In CommonSettingsToSave Do
			If Not Settings.Property(SettingToSave.Key)
			 Or TypeOf(Settings[SettingToSave.Key]) <> TypeOf(SettingToSave.Value) Then
				Continue;
			EndIf;
			Settings[SettingToSave.Key] = SettingToSave.Value;
		EndDo;
		
		Constants.UserAuthorizationSettings.Set(New ValueStorage(LogonSettings));
		
		If Not CommonSettingsToSave.Property("UpdateOnlyConstant") Then
			UsersInternal.UpdateCommonPasswordPolicy(Settings);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
EndProcedure

// 
// 
// Returns:
//  Structure:
//   * AreSeparateSettingsForExternalUsers - Boolean -
//       
//   * PasswordAttemptsCountBeforeLockout - Number -
//       
//   * PasswordLockoutDuration - Number -
//   * ShowInList - String -
//       
//       
//
Function CommonAuthorizationSettingsNewDetails() Export
	
	Settings = New Structure;
	Settings.Insert("AreSeparateSettingsForExternalUsers", False);
	Settings.Insert("PasswordAttemptsCountBeforeLockout", 3);
	Settings.Insert("PasswordLockoutDuration", 5);
	Settings.Insert("ShowInList",
		?(Common.DataSeparationEnabled()
		  Or ExternalUsers.UseExternalUsers(),
			"HiddenAndDisabledForAllUsers", "EnabledForNewUsers"));
	
	Return Settings;
	
EndFunction

// 
// 
// 
// Parameters:
//  SavingSettings - See Users.NewDescriptionOfLoginSettings
//  ForExternalUsers - Boolean - True if external user authorization settings are saved.
//
Procedure SetLoginSettings(SavingSettings, ForExternalUsers = False) Export
	
	Block = New DataLock();
	Block.Add("Constant.UserAuthorizationSettings");
	
	BeginTransaction();
	Try
		Block.Lock();
		LogonSettings = UsersInternal.LogonSettings();
		
		If ForExternalUsers Then
			Settings = LogonSettings.ExternalUsers;
		Else
			Settings = LogonSettings.Users;
		EndIf;
		
		For Each SettingToSave In SavingSettings Do
			
			If Not Settings.Property(SettingToSave.Key)
			 Or TypeOf(Settings[SettingToSave.Key]) <> TypeOf(SettingToSave.Value)
			 Or Upper(SettingToSave.Key) = Upper("InactivityPeriodActivationDate")
			   And Not ValueIsFilled(Settings[SettingToSave.Key]) Then
				Continue;
			EndIf;
			Settings[SettingToSave.Key] = SettingToSave.Value;
		EndDo;
		
		If Not ValueIsFilled(Settings.InactivityPeriodBeforeDenyingAuthorization) Then
			Settings.InactivityPeriodActivationDate = Date(1, 1, 1);
		ElsIf Not ValueIsFilled(Settings.InactivityPeriodActivationDate) Then
			Settings.InactivityPeriodActivationDate = BegOfDay(CurrentSessionDate());
		EndIf;
		
		Constants.UserAuthorizationSettings.Set(New ValueStorage(LogonSettings));
		
		If Not SavingSettings.Property("UpdateOnlyConstant") Then
			If ForExternalUsers Then
				If LogonSettings.Overall.AreSeparateSettingsForExternalUsers
				   And CommonAuthorizationSettingsUsed() Then
				
					UsersInternal.UpdateExternalUsersPasswordPolicy(Settings);
				Else
					UsersInternal.UpdateExternalUsersPasswordPolicy(Undefined);
				EndIf;
			Else
				UsersInternal.UpdateUsersPasswordPolicy(Settings);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns a structure of the default authentication settings.
// 
// Returns:
//  Structure:
//   * PasswordMustMeetComplexityRequirements - Boolean -
//        
//          
//          
//            
//          
//   * MinPasswordLength - Number - Minimum password length.
//   * MaxPasswordLifetime - Number -
//   * MinPasswordLifetime - Number -
//   * DenyReusingRecentPasswords - Number -
//        
//   * WarnAboutPasswordExpiration - Number -
//        
//   * InactivityPeriodBeforeDenyingAuthorization - Number -
//        
//   * InactivityPeriodActivationDate - Date -
//        
//
Function NewDescriptionOfLoginSettings() Export
	
	Settings = New Structure();
	// 
	Settings.Insert("PasswordMustMeetComplexityRequirements", False);
	Settings.Insert("MinPasswordLength", 0);
	// 
	Settings.Insert("MaxPasswordLifetime", 0);
	Settings.Insert("MinPasswordLifetime", 0);
	Settings.Insert("DenyReusingRecentPasswords", 0);
	Settings.Insert("WarnAboutPasswordExpiration", 0);
	// 
	Settings.Insert("InactivityPeriodBeforeDenyingAuthorization", 0);
	Settings.Insert("InactivityPeriodActivationDate", '00010101');
	
	Return Settings;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// 
// 
// 
// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers
//  StoredPasswordValue - String
//
Procedure AddUsedPassword(User, StoredPasswordValue) Export
	Return;
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Generates a brief error description for displaying to users
// and also writes error details to the event log if WriteToLog is True.
//
// Parameters:
//  ErrorTemplate       - String - Template that contains parameter %1 for infobase user presentation,
//                       and parameter %2 for error details.
//
//  LoginName        - String - the user name for infobase authentication.
//
//  IBUserID - Undefined
//                              - UUID
//
//  ErrorInfo - ErrorInfo
//
//  WriteToLog    - Boolean - If True, write an error description
//                       to the event log.
//
// Returns:
//  String - 
//
Function ErrorDescriptionOnWriteIBUser(ErrorTemplate,
                                              LoginName,
                                              IBUserID,
                                              ErrorInfo = Undefined,
                                              WriteToLog = True)
	
	If WriteToLog Then
		WriteLogEvent(
			NStr("en = 'Users.Error saving infobase user';",
			     Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				"""" + LoginName + """ (" + ?(ValueIsFilled(IBUserID),
					NStr("en = 'New';"), String(IBUserID)) + ")",
				?(TypeOf(ErrorInfo) = Type("ErrorInfo"),
					ErrorProcessing.DetailErrorDescription(ErrorInfo), String(ErrorInfo))));
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, """" + LoginName + """",
		?(TypeOf(ErrorInfo) = Type("ErrorInfo"),
			ErrorProcessing.BriefErrorDescription(ErrorInfo), String(ErrorInfo)));
	
EndFunction

// This method is required by IsFullUser and RolesAvailable functions.

// Details
//
// Parameters:
//  User - Undefined
//               - InfoBaseUser
//               - CatalogRef.ExternalUsers
//               - CatalogRef.Users
// 
// Returns:
//  - Undefined
//  - FixedStructure
//  - Structure:
//    * IsCurrentIBUser - Boolean
//    * IBUser - Undefined
//                     - InfoBaseUser
//
Function CheckedIBUserProperties(User) Export
	
	CurrentIBUserProperties = UsersInternalCached.CurrentIBUserProperties1();
	IBUser = Undefined;
	
	If TypeOf(User) = Type("InfoBaseUser") Then
		IBUser = User;
		
	ElsIf User = Undefined Or User = AuthorizedUser() Then
		Return CurrentIBUserProperties;
	Else
		// User passed to the function is not the current user.
		If ValueIsFilled(User) Then
			IBUserID = Common.ObjectAttributeValue(User, "IBUserID");
			If CurrentIBUserProperties.UUID = IBUserID Then
				Return CurrentIBUserProperties;
			EndIf;
			IBUser = InfoBaseUsers.FindByUUID(IBUserID);
		EndIf;
	EndIf;
	
	If IBUser = Undefined Then
		Return Undefined;
	EndIf;
	
	If CurrentIBUserProperties.UUID = IBUser.UUID Then
		Return CurrentIBUserProperties;
	EndIf;
	
	Properties = New Structure;
	Properties.Insert("IsCurrentIBUser", False);
	Properties.Insert("IBUser", IBUser);
	
	Return Properties;
	
EndFunction

#EndRegion
