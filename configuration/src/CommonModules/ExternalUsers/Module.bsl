///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns a flag that shows whether external users are enabled in the application
// (the UseExternalUsers functional option value).
//
// Returns:
//  Boolean - 
//
Function UseExternalUsers() Export
	
	Return GetFunctionalOption("UseExternalUsers");
	
EndFunction

// Returns the current external user.
//  It is recommended that you use the function in a script fragment that supports external users only.
//
//  If the current user is not external, throws an exception.
//
// Returns:
//  CatalogRef.ExternalUsers - external user.
//
Function CurrentExternalUser() Export
	
	Return UsersInternalClientServer.CurrentExternalUser(
		Users.AuthorizedUser());
	
EndFunction

// Returns a reference to the external user authorization object from the infobase.
// Authorization object is a reference to an infobase object (for example, a counterparty, an individual, and others
//  associated with an external user.
//
// Parameters:
//  ExternalUser - Undefined - the current external user.
//                      - CatalogRef.ExternalUsers - 
//
// Returns:
//  AnyRef - 
//           
//
Function GetExternalUserAuthorizationObject(ExternalUser = Undefined) Export
	
	If ExternalUser = Undefined Then
		ExternalUser = CurrentExternalUser();
	EndIf;
	
	AuthorizationObject = Common.ObjectAttributesValues(ExternalUser, "AuthorizationObject").AuthorizationObject;
	
	If ValueIsFilled(AuthorizationObject) Then
		If UsersInternal.AuthorizationObjectIsInUse(AuthorizationObject, ExternalUser) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Authorization object ""%1"" (%2)
					|is set for several external users.';"),
				AuthorizationObject,
				TypeOf(AuthorizationObject));
		EndIf;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No authorization object is set for the external user ""%1"".';"),
			ExternalUser);
	EndIf;
	
	Return AuthorizationObject;
	
EndFunction

// 
// 
// 
// 
// 
// 
//
// Parameters:
//  Form - ClientApplicationForm
//  AdditionalParameters - See ParametersOfExternalUsersListDisplaySetting
//
Procedure ShowExternalUsersListView(Form, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = ParametersOfExternalUsersListDisplaySetting();
	EndIf;
	
	List = Form[AdditionalParameters.ListName];
	UsersInternal.RestrictUsageOfDynamicListFieldToFill(List,
		AdditionalParameters.FieldName);
	
	If AccessRight("Read", Metadata.Catalogs.ExternalUsers)
	   And UseExternalUsers() Then
		Return;
	EndIf;
	
	Item = Form.Items.Find(AdditionalParameters.TagName);
	If Item <> Undefined Then
		Item.Visible = False;
	EndIf;
	
	Item = Form.Items.Find(AdditionalParameters.LegendGroupName);
	If Item <> Undefined Then
		Item.Visible = False;
		Return;
	EndIf;
	
	// Hiding unavailable information items.
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(List.QueryText);
	Sources = QuerySchema.QueryBatch[0].Operators[0].Sources; // QuerySchemaSources
	IndexOf = Sources.Count();
	While IndexOf > 0 Do
		IndexOf = IndexOf - 1;
		If Sources[IndexOf].Source.TableName = "Catalog.ExternalUsers" Then
			Sources.Delete(IndexOf);
		EndIf;
	EndDo;
	List.QueryText = QuerySchema.GetQueryText();
	
EndProcedure

// 
//
// Returns:
//  Structure:
//   * ListName        - String -
//   * FieldName          - String -
//   * TagName      - String -
//   * LegendGroupName - String -
//
Function ParametersOfExternalUsersListDisplaySetting() Export
	
	Result = New Structure;
	Result.Insert("ListName",        "List");
	Result.Insert("FieldName",          "ExternalAccessPicNum");
	Result.Insert("TagName",      "ExternalAccessPicNum");
	Result.Insert("LegendGroupName", "ExternalAccessLegend");
	
	Return Result;
	
EndFunction

// 
// 
// 
//
// 
// 
//
// Parameters:
//  TagName - String
//  Settings - DataCompositionSettings
//  Rows - DynamicListRows
//  FieldName - String -
//
Procedure ExternalUserListOnRetrievingDataAtServer(TagName, Settings, Rows,
			FieldName = "ExternalAccessPicNum") Export
	
	If Rows.Count() = 0
	 Or Not AccessRight("Read", Metadata.Catalogs.ExternalUsers) Then
		Return;
	EndIf;
	
	For Each KeyAndValue In Rows Do
		Properties = New Structure("Ref" + "," + FieldName);
		FillPropertyValues(Properties, KeyAndValue.Value.Data);
		If KeyAndValue.Key <> Properties.Ref
		 Or TypeOf(Properties[FieldName]) <> Type("Number") Then
			Return;
		EndIf;
		Break;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("AuthorizationObjects", Rows.GetKeys());
	Query.Text =
	"SELECT
	|	ExternalUsers.AuthorizationObject AS AuthorizationObject,
	|	UsersInfo.NumberOfStatePicture - 1 AS PictureNumber
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|		INNER JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = ExternalUsers.Ref)
	|WHERE
	|	ExternalUsers.AuthorizationObject IN(&AuthorizationObjects)";
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	While Selection.Next() Do
		String = Rows.Get(Selection.AuthorizationObject);
		String.Data[FieldName] = Selection.PictureNumber;
	EndDo;
	
EndProcedure

#EndRegion
