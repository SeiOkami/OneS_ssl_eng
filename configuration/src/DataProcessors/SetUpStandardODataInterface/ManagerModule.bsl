///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// ACC:581-off Called from development tools.

// Puts a prepared structure to view metadata in the temporary storage.
// To call from a long-running operation (background job).
//
// Parameters:
//  Parameters		 - Structure - Empty structure. 
//  StorageAddress	 - String - Temporary storage address to return the data to. 
//
Procedure PrepareStandardODataInterfaceContentSetupParameters(Parameters, StorageAddress) Export
	
	InitializationData = DataProcessors.SetUpStandardODataInterface.StandardODataInterfaceCompositionSetupParameters();
	PutToTempStorage(InitializationData, StorageAddress);
	
EndProcedure

// Returns a role to be assigned to an infobase user
// whose username and password will be used upon connection to standard OData Interface.
//
// Returns:
//   MetadataObjectRole
//
Function RoleForStandardODataInterface() Export
	
	Return Metadata.Roles.RemoteODataAccess;
	
EndFunction

// Returns authorization settings for standard OData interface (SaaS).
//
// Returns:
//   FixedStructure:
//                        * Used - Boolean - OData authorization availability flag.
//                                         
//                        * Login - String - Username to access the standard OData interface.
//                                         
//
Function AuthorizationSettingsForStandardODataInterface() Export
	
	Result = New Structure("Used, Login");
	Result.Used = False;
	
	UserProperties = StandardODataInterfaceUserProperties();
	If ValueIsFilled(UserProperties.User) Then
		Result.Login = UserProperties.Name;
		Result.Used = UserProperties.Authentication;
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

// Writes authorization settings for standard OData interface (SaaS).
//
// Parameters:
//  AuthorizationSettings - Structure:
//                        * Used - Boolean - OData authorization availability flag.
//                                         
//                        * Login - String - Username to authenticate to standard OData interface.
//                                         
//                        * Password - String - Password to authenticate to standard OData interface.
//                                         Passed within the structure only for password change.
//                                         
//                                         
//
Procedure WriteAuthorizationSettingsForStandardODataInterface(Val AuthorizationSettings) Export
	
	UserProperties = StandardODataInterfaceUserProperties();
	
	If AuthorizationSettings.Used Then
		
		// Create or update an infobase user.
		
		CheckCanCreateUserForStandardODataInterfaceCalls();
		
		IBUserDetails = New Structure();
		IBUserDetails.Insert("Action", "Write");
		IBUserDetails.Insert("Name", AuthorizationSettings.Login);
		IBUserDetails.Insert("StandardAuthentication", True);
		IBUserDetails.Insert("OpenIDAuthentication", False);
		IBUserDetails.Insert("OpenIDConnectAuthentication", False);
		IBUserDetails.Insert("AccessTokenAuthentication", False);
		IBUserDetails.Insert("OSAuthentication", False);
		IBUserDetails.Insert("ShowInList", False);
		If AuthorizationSettings.Property("Password") Then
			IBUserDetails.Insert("Password", AuthorizationSettings.Password);
		EndIf;
		IBUserDetails.Insert("CannotChangePassword", True);
		IBUserDetails.Insert("Roles",
			CommonClientServer.ValueInArray(
			RoleForStandardODataInterface().Name));
		
		BeginTransaction();
		Try
			
			If ValueIsFilled(UserProperties.User) Then
				
				Block = New DataLock;
				LockItem = Block.Add("Catalog.Users");
				LockItem.SetValue("Ref", UserProperties.User);
				Block.Lock();
				
				StandardODataInterfaceUser = UserProperties.User.GetObject();
				
			Else
				StandardODataInterfaceUser = Catalogs.Users.CreateItem();
			EndIf;
			
			StandardODataInterfaceUser.Description = NStr("en = 'Automatic REST service';");
			StandardODataInterfaceUser.IsInternal = True;
			StandardODataInterfaceUser.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
			StandardODataInterfaceUser.Write();
			
			Constants.StandardODataInterfaceUser.Set(
				StandardODataInterfaceUser.Ref);
				
			If IBUserDetails.Property("Password") Then
				IBUserDetails.Delete("Password");
			EndIf;
			
			AbbreviatedDetails = New Structure;
			CommonClientServer.SupplementStructure(AbbreviatedDetails, IBUserDetails);
			AbbreviatedDetails.Delete("IBUser");
			
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'A user for the standard OData interface is saved with the result: %1
					|User details:
					|%2';"),
				StandardODataInterfaceUser.AdditionalProperties.IBUserDetails.ActionResult,
				Common.ValueToXMLString(AbbreviatedDetails));
			
			WriteLogEvent(
				NStr("en = 'Configure the standard OData interface.Save user';", Common.DefaultLanguageCode()),
				EventLogLevel.Information,
				Metadata.Catalogs.Users,
				,
				Comment);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			IBUserDetails.Delete("Password");
			
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save a user for the standard OData interface due to:
					|%1
					|
					|User details:
					|%2';"),
				ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				Common.ValueToXMLString(IBUserDetails));
			
			WriteLogEvent(
				NStr("en = 'Configure the standard OData interface.Save user';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.Users,
				,
				Comment);
			
			Raise;
			
		EndTry;
		
	Else
		
		If ValueIsFilled(UserProperties.User) Then
			
			// 
			
			IBUserDetails = New Structure();
			IBUserDetails.Insert("Action", "Write");
			
			IBUserDetails.Insert("CanSignIn", False);
			
			StandardODataInterfaceUser = UserProperties.User.GetObject();
			StandardODataInterfaceUser.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
			StandardODataInterfaceUser.IsInternal = True;
			StandardODataInterfaceUser.Write();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Returns a data model for object that can be included in standard
// OData interface (SaaS).
//
// Returns:
//   ValueTable:
//                         * MetadataObject - MetadataObject - Metadata object that can
//                                              be included in standard OData interface,
//                         * Read - Boolean -  access to write the object can be granted
//                                              using standard OData interface,
//                         * Record - Boolean -  access to write the object
//                                              can be granted using standard OData interface,
//                         * Dependencies -      Array of MetadataObject - Array of metadata objects.
//                                              They will be included in standard OData interface when the current object is included.
//                                              
//
Function ModelOfDataToProvideForStandardODataInterface() Export
	
	ToExclude = New Map();
	For Each ObjectToExclude In ObjectsToExcludeFromStandardODataInterface() Do
		If TypeOf(ObjectToExclude) = Type("Structure")
			Or TypeOf(ObjectToExclude) = Type("FixedStructure") Then
			ToExclude[ObjectToExclude.Type.FullName()] = True;
		Else
			ToExclude[ObjectToExclude.FullName()] = True;
		EndIf;
	EndDo;
	
	Result = New ValueTable();
	Result.Columns.Add("FullName", New TypeDescription("String"));
	Result.Columns.Add("Read", New TypeDescription("Boolean"));
	Result.Columns.Add("Update", New TypeDescription("Boolean"));
	Result.Columns.Add("Dependencies", New TypeDescription("Array"));
	Result.Indexes.Add("FullName");
	
	For Each Items In ODataInterfaceInternalCached.ConfigurationDataModelDetails() Do
		For Each KeyAndValue In Items.Value Do
			ObjectDetails = KeyAndValue.Value;
			If ToExclude[ObjectDetails.FullName] <> Undefined Then
				Continue;
			EndIf;
			If Not IsSeparatedObject(ObjectDetails) Then
				Continue;
			EndIf;
			FillModelOfDataToProvideForStandardODataInterface(Result, ObjectDetails.FullName, ToExclude);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction


// Returns a reference role to be assigned to an infobase user
// whose username and password will be used upon connection to standard
// OData interface (SaaS).
//
// Returns:
//   Map of KeyAndValue:
//     * Key - MetadataObject -
//     * Value - Array of String - 
//                                     
//
Function ReferenceRoleCompositionForStandardODataInterface() Export
	
	Result = New Map();
	
	RightsKinds = RightsKindsForStandardODataInterface(Metadata.FullName(), False, False);
	If RightsKinds.Count() > 0 Then
		Result.Insert(Metadata, RightsKinds);
	EndIf;
	
	For Each SessionParameter In Metadata.SessionParameters Do
		RightsKinds = RightsKindsForStandardODataInterface(SessionParameter, True, False);
		If RightsKinds.Count() > 0 Then
			Result.Insert(SessionParameter.FullName(), RightsKinds);
		EndIf;
	EndDo;
	
	For Each TableName In DependantTablesForODataImportExport() Do
		RightsKinds = RightsKindsForStandardODataInterface(TableName, True, True);
		If RightsKinds.Count() > 0 Then
			Result.Insert(TableName, RightsKinds);
		EndIf;
	EndDo;
	
	Model = ModelOfDataToProvideForStandardODataInterface();
	For Each ModelItem In Model Do
		
		RightsKinds = RightsKindsForStandardODataInterface(
			ModelItem.FullName,
			ModelItem.Read,
			ModelItem.Update);
		
		If RightsKinds.Count() > 0 Then
			Result.Insert(ModelItem.FullName, RightsKinds);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns errors in a role to be assigned to an infobase
// user whose username and password will be used upon connection to standard
// OData interface (SaaS).
//
// Returns:
//   Array - 
//
Function ODataRoleCompositionErrors(ErrorsByObjects = Undefined) Export
	
	Role = RoleForStandardODataInterface();
	
	ExcessRights = New Map();
	MissingRights = New Map();
	
	ReferenceComposition = ReferenceRoleCompositionForStandardODataInterface();
	
	CheckODataRoleCompositionByMetadataObject(Metadata, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.SessionParameters, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.Constants, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.Catalogs, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.Documents, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.DocumentJournals, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.ChartsOfCharacteristicTypes, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.ChartsOfAccounts, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.ChartsOfCalculationTypes, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.ExchangePlans, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.BusinessProcesses, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.Tasks, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.Sequences, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.InformationRegisters, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.AccumulationRegisters, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.AccountingRegisters, ReferenceComposition, ExcessRights, MissingRights);
	CheckODataRoleCompositionByMetadataCollection(Metadata.CalculationRegisters, ReferenceComposition, ExcessRights, MissingRights);
	For Each CalculationRegister In Metadata.CalculationRegisters Do
		CheckODataRoleCompositionByMetadataCollection(CalculationRegister.Recalculations, ReferenceComposition, ExcessRights, MissingRights);
	EndDo;
	
	Errors = New Array();
	If ExcessRights.Count() > 0 Then
		ErrorText = Chars.NBSp + NStr("en = 'The following rights are excessively included in the role:';") + Chars.LF + Chars.CR
			+ ExcessOrMissingRightsPresentation(ExcessRights, 2);
		Errors.Add(ErrorText);
	EndIf;
	
	If MissingRights.Count() > 0 Then
		ErrorText = Chars.NBSp + NStr("en = 'The following rights must be included in the role:';") + Chars.LF + Chars.CR
			+ ExcessOrMissingRightsPresentation(MissingRights, 2);
		Errors.Add(ErrorText);
	EndIf;
	
	If TypeOf(ErrorsByObjects) = Type("Map") Then
		For Each KeyAndValue In ExcessRights Do
			FullName = KeyAndValue.Key.FullName();
			ErrorsByObjects.Insert(FullName, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The following rights to object %1 are redundantly included in role %2: %3';"),
				FullName, Role.Name, StrConcat(KeyAndValue.Value, ", ")));
		EndDo;
		For Each KeyAndValue In MissingRights Do
			FullName = KeyAndValue.Key.FullName();
			ErrorsText = ErrorsByObjects.Get(FullName);
			ErrorsText = ?(ErrorsText = Undefined, "", ErrorsText + Chars.LF);
			ErrorsText = ErrorsText + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The following rights to object %1 must be included in role %2: %3';"),
				FullName, Role.Name, StrConcat(KeyAndValue.Value, ", "));
			ErrorsByObjects.Insert(FullName, ErrorsText);
		EndDo;
	EndIf;
	
	Return Errors;
	
EndFunction

// ACC:581-on

#EndRegion

#Region Private

Function IsSeparatedObject(ObjectDetails)
	IsSeparatedMetadataObject = False;
	
	If Common.SubsystemExists("CloudTechnology") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		IsSeparatedMetadataObject = ObjectDetails.DataSeparation.Property(ModuleSaaSOperations.MainDataSeparator());
	Else
		MetadataObject = Common.MetadataObjectByFullName(ObjectDetails.FullName);
		If IsRefData(MetadataObject) 
				Or Common.IsRegister(MetadataObject) 
				Or Common.IsConstant(MetadataObject) Then
			
			IsSeparatedMetadataObject = AccessRight("Update", MetadataObject, Metadata.Roles.RemoteODataAccess);
		EndIf;
		
		If Common.IsDocumentJournal(MetadataObject)
				Or Common.IsEnum(MetadataObject) Then
				
			IsSeparatedMetadataObject = AccessRight("Read", MetadataObject, Metadata.Roles.RemoteODataAccess);
		EndIf;
	EndIf;
	
	Return IsSeparatedMetadataObject;
EndFunction

Function StandardODataInterfaceCompositionSetupParameters() Export
	
	Object = Create();
	Return Object.InitializeDataToSetUpStandardODataInterfaceComposition();
	
EndFunction

Procedure CheckODataRoleCompositionByMetadataCollection(MetadataCollection, ReferenceComposition, ExcessRights, MissingRights)
	
	For Each MetadataObject In MetadataCollection Do
		CheckODataRoleCompositionByMetadataObject(MetadataObject, ReferenceComposition, ExcessRights, MissingRights);
	EndDo;
	
EndProcedure

Procedure CheckODataRoleCompositionByMetadataObject(MetadataObject, ReferenceComposition, ExcessRights, MissingRights)
	
	RightsKinds = AllowedRightsForMetadataObject(MetadataObject);
	
	ReferenceRights = ReferenceComposition.Get(MetadataObject.FullName());
	If ReferenceRights = Undefined Then
		ReferenceRights = New Array();
	EndIf;
	
	GrantedRights = New Array();
	For Each RightKind In RightsKinds Do
		If AccessRight(RightKind.Name, MetadataObject, RoleForStandardODataInterface()) Then
			GrantedRights.Add(RightKind.Name);
		EndIf;
	EndDo;
	
	// The rights that are present in reference rights but missing in granted rights are considered lacking.
	MissingRightsByObject = New Array();
	For Each RightKind In ReferenceRights Do
		If GrantedRights.Find(RightKind) = Undefined Then
			MissingRightsByObject.Add(RightKind);
		EndIf;
	EndDo;
	If MissingRightsByObject.Count() > 0 Then
		MissingRights.Insert(MetadataObject, MissingRightsByObject);
	EndIf;
	
	// The rights that are present in granted rights but missing in reference rights are considered excessive.
	ExcessRightsByObject = New Array();
	For Each RightKind In GrantedRights Do
		If ReferenceRights.Find(RightKind) = Undefined Then
			ExcessRightsByObject.Add(RightKind);
		EndIf;
	EndDo;
	If ExcessRightsByObject.Count() > 0 Then
		ExcessRights.Insert(MetadataObject, ExcessRightsByObject);
	EndIf;
	
EndProcedure

Function RightsKindsForStandardODataInterface(Val MetadataObject, Val AllowReadingData, Val AllowChangingData)
	
	AllRightsKinds = AllowedRightsForMetadataObject(MetadataObject);
	
	FilterRight = New Structure();
	FilterRight.Insert("Interactive", False);
	FilterRight.Insert("InfobaseAdministration", False);
	FilterRight.Insert("DataAreaAdministration", False);
	
	If AllowReadingData And Not AllowChangingData Then
		FilterRight.Insert("Read", AllowReadingData);
	EndIf;
	
	If AllowChangingData And Not AllowReadingData Then
		FilterRight.Insert("Update", AllowChangingData);
	EndIf;
	
	RequiredRightsKinds = AllRightsKinds.Copy(FilterRight);
	
	Return RequiredRightsKinds.UnloadColumn("Name");
	
EndFunction

Procedure FillModelOfDataToProvideForStandardODataInterface(Val Result, Val FullName, Val ToExclude)
	
	MetadataObject = Common.MetadataObjectByFullName(FullName);
	If Not IsValidODataMetadataObject(MetadataObject) Then
		Return;
	EndIf;
	
	String = Result.Find(FullName, "FullName");
	If String = Undefined Then
		String = Result.Add();
	EndIf;
	
	ConfigurationDataModelDetails = ODataInterfaceInternalCached.ConfigurationDataModelDetails();
	MetadataObjectProperties = ODataInterfaceInternal.ConfigurationModelObjectProperties(
		ConfigurationDataModelDetails, FullName);
	
	IsSeparatedMetadataObject = IsSeparatedObject(MetadataObjectProperties);
	
	String.Read = True;
	String.FullName = FullName;
	If Common.IsEnum(MetadataObject) Then
		String.Update = False;
	ElsIf Common.IsDocumentJournal(MetadataObject) Then
		String.Update = False;
	Else
		String.Update = IsSeparatedMetadataObject;
	EndIf;
	
	For Each KeyAndValue In MetadataObjectProperties.Dependencies Do
		
		FullDependencyName = KeyAndValue.Key;
		If FullDependencyName = FullName Or ToExclude[FullDependencyName] <> Undefined Then
			Continue;
		EndIf;
		
		String.Dependencies.Add(FullDependencyName);
		DependentMetadataObject = ODataInterfaceInternal.ConfigurationModelObjectProperties(
			ConfigurationDataModelDetails, FullDependencyName);
		MetadataObject = Common.MetadataObjectByFullName(FullDependencyName);
		If DependentMetadataObject <> Undefined And IsSeparatedObject(DependentMetadataObject) 
			And Not Common.IsEnum(MetadataObject) Then
			Continue;
		EndIf;

		DependencyString = Result.Find(FullDependencyName, "FullName");
		If DependencyString <> Undefined Then
			Continue;
		EndIf;

		FillModelOfDataToProvideForStandardODataInterface(Result, FullDependencyName, ToExclude);
		
	EndDo;
	
EndProcedure

Function IsValidODataMetadataObject(Val MetadataObject)
	
	Return Common.IsCatalog(MetadataObject)
		Or Common.IsDocument(MetadataObject)
		Or Common.IsExchangePlan(MetadataObject)
		Or Common.IsChartOfAccounts(MetadataObject)
		Or Common.IsChartOfCalculationTypes(MetadataObject)
		Or Common.IsChartOfCharacteristicTypes(MetadataObject)
		Or Common.IsAccountingRegister(MetadataObject)
		Or Common.IsInformationRegister(MetadataObject)
		Or Common.IsCalculationRegister(MetadataObject)
		Or Common.IsAccumulationRegister(MetadataObject)
		Or Common.IsDocumentJournal(MetadataObject)
		Or Common.IsEnum(MetadataObject)
		Or Common.IsTask(MetadataObject)
		Or Common.IsBusinessProcess(MetadataObject)
		Or Common.IsConstant(MetadataObject);
	
EndFunction

Function ExcessOrMissingRightsPresentation(Val RightsDetails1, Val Indent)
	
	Result = "";
	
	For Each KeyAndValue In RightsDetails1 Do
		
		MetadataObject = KeyAndValue.Key;
		Rights = KeyAndValue.Value;
		
		String = "";
		
		For Step = 1 To Indent Do
			String = String + Chars.NBSp;
		EndDo;
		
		String = String + MetadataObject.FullName() + ": " + StrConcat(Rights, ", ");
		
		If Not IsBlankString(Result) Then
			Result = Result + Chars.LF;
		EndIf;
		
		Result = Result + String;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function ObjectsToExcludeFromStandardODataInterface()
	
	TypesToExclude = New Array;
	SSLSubsystemsIntegration.OnFillTypesExcludedFromExportImportOData(TypesToExclude);
	Return TypesToExclude;
	
EndFunction

Function StandardODataInterfaceUserProperties()
	
	If Not AccessRight("DataAdministration", Metadata) Then
		Raise NStr("en = 'Insufficient access rights to configure automatic REST service';");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	Result.Insert("User", Catalogs.Users.EmptyRef());
	Result.Insert("Id");
	Result.Insert("Name", "");
	Result.Insert("Authentication", False);
	
	User = Constants.StandardODataInterfaceUser.Get();
	If ValueIsFilled(User) Then
		
		Result.User = User;
		Id = Common.ObjectAttributeValue(User, "IBUserID");
		If ValueIsFilled(Id) Then
			
			Result.Id = Id;
			IBUser = InfoBaseUsers.FindByUUID(Id);
			If IBUser <> Undefined Then
				Result.Name = IBUser.Name;
				Result.Authentication = IBUser.StandardAuthentication;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure CheckCanCreateUserForStandardODataInterfaceCalls()
	
	SetPrivilegedMode(True);
	UsersCount = InfoBaseUsers.GetUsers().Count();
	SetPrivilegedMode(False);
	
	If UsersCount = 0 Then
		Raise NStr("en = 'Cannot create a separate username and password for using the automatic REST service, as there are no other users in the application.';");
	EndIf;
	
EndProcedure

Function DependantTablesForODataImportExport()
	
	Tables = New Array;
	ODataInterfaceOverridable.OnPopulateDependantTablesForODataImportExport(Tables);
	SSLSubsystemsIntegration.OnPopulateDependantTablesForODataImportExport(Tables);
	
	Return Tables;
	
EndFunction

#Region Metadata

Function AllowedRightsForMetadataObject(Val MetadataObject)
	
	RightsKinds = New ValueTable();
	RightsKinds.Columns.Add("Name", New TypeDescription("String"));
	RightsKinds.Columns.Add("Interactive", New TypeDescription("Boolean"));
	RightsKinds.Columns.Add("Read", New TypeDescription("Boolean"));
	RightsKinds.Columns.Add("Update", New TypeDescription("Boolean"));
	RightsKinds.Columns.Add("InfobaseAdministration", New TypeDescription("Boolean"));
	RightsKinds.Columns.Add("DataAreaAdministration", New TypeDescription("Boolean"));
	
	If TypeOf(MetadataObject) = Type("String") Then
		MetadataObjectName = MetadataObject;
		MetadataObjectToAnalyze = Common.MetadataObjectByFullName(MetadataObject);
	Else
		MetadataObjectName = MetadataObject.FullName();
		MetadataObjectToAnalyze = MetadataObject;
	EndIf;
	
	If IsConfigurationMetadataObject(MetadataObjectName) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Administration";
		RightKind.InfobaseAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "DataAdministration";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "UpdateDataBaseConfiguration";
		RightKind.InfobaseAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "ExclusiveMode";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "ActiveUsers";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "EventLog";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "ThinClient";
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "WebClient";
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "ThickClient";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "ExternalConnection";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Automation";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "AllFunctionsMode";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "SaveUserData";
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveOpenExtDataProcessors";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveOpenExtReports";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Output";
		RightKind.Interactive = True;
		
	ElsIf IsSessionParameter(MetadataObjectName) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Get"; //@Access-right-1
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Set";
		RightKind.Update = True;
		
	ElsIf IsCommonAttribute(MetadataObjectName) Then
		
		RightKind = RightsKinds.Add();
		RightKind = "View";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
	ElsIf Common.IsConstant(MetadataObjectToAnalyze) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "View";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
	ElsIf IsRefData(MetadataObjectToAnalyze) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Insert"; //@Access-right-1
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Delete";
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "View";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveInsert";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveDelete";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveSetDeletionMark"; //@Access-right-1
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveClearDeletionMark";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InteractiveDeleteMarked";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		If Common.IsDocument(MetadataObjectToAnalyze) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "Posting";
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "UndoPosting";
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractivePosting";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractivePostingRegular";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveUndoPosting";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveChangeOfPosted";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "InputByString";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		If Common.IsBusinessProcess(MetadataObjectToAnalyze) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveActivate";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "Start";
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveStart";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If Common.IsTask(MetadataObjectToAnalyze) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveActivate";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "Execute"; //@Access-right-1
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveExecute";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If IsRefDataSupportingPredefinedItems(MetadataObjectToAnalyze) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveDeletePredefinedData";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveSetDeletionMarkPredefinedData";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveClearDeletionMarkPredefinedData";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "InteractiveDeleteMarkedPredefinedData";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
	ElsIf ODataInterfaceInternal.IsRecordSet(MetadataObjectName) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		If Not ODataInterfaceInternal.IsSequenceRecordSet(MetadataObjectName)
			And Not ODataInterfaceInternal.IsRecalculationRecordSet(MetadataObjectName) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "View";
			RightKind.Interactive = True;
			RightKind.Read = True;
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "Edit";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If IsRecordSetSupportingTotals(MetadataObjectToAnalyze) Then
			
			RightKind = RightsKinds.Add();
			RightKind.Name = "TotalsControl";
			RightKind.DataAreaAdministration = True;
			
		EndIf;
		
	ElsIf Common.IsDocumentJournal(MetadataObjectToAnalyze) Then
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKinds.Add();
		RightKind.Name = "View";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
	EndIf;
	
	Return RightsKinds;
	
EndFunction

// Checks whether the passed metadata object is ConfigurationMetadataObject.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsConfigurationMetadataObject(Val MetadataObject)
	
	Return TypeOf(MetadataObject) = Type("ConfigurationMetadataObject");
	
EndFunction

// Checks whether the passed metadata object is a session parameter.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsSessionParameter(Val MetadataObject)
	
	Return ODataInterfaceInternal.IsClassMetadataObject(MetadataObject,
		ODataInterfaceInternalCached.MetadataClassesInConfigurationModel().SessionParameters);
	
EndFunction

// Checks whether the passed metadata object is a common attribute.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsCommonAttribute(Val MetadataObject)
	
	Return ODataInterfaceInternal.IsClassMetadataObject(MetadataObject,
		ODataInterfaceInternalCached.MetadataClassesInConfigurationModel().CommonAttributes);
	
EndFunction

// Checks whether the passed metadata object is a reference object.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsRefData(Val MetadataObject)
	
	Return Common.IsCatalog(MetadataObject)
		Or Common.IsDocument(MetadataObject)
		Or Common.IsBusinessProcess(MetadataObject)
		Or Common.IsTask(MetadataObject)
		Or Common.IsChartOfAccounts(MetadataObject)
		Or Common.IsExchangePlan(MetadataObject)
		Or Common.IsChartOfCharacteristicTypes(MetadataObject)
		Or Common.IsChartOfCalculationTypes(MetadataObject)
		Or Common.IsEnum(MetadataObject);
		
EndFunction

// Checks whether the passed metadata object has a reference type that supports predefined items.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsRefDataSupportingPredefinedItems(Val MetadataObject)
	
	Return Common.IsCatalog(MetadataObject)
		Or Common.IsChartOfAccounts(MetadataObject)
		Or Common.IsChartOfCharacteristicTypes(MetadataObject)
		Or Common.IsChartOfCalculationTypes(MetadataObject);
	
EndFunction

// Checks whether the passed metadata object is a record set that supports totals.
//
// Parameters:
//  MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsRecordSetSupportingTotals(Val MetadataObject)
	
	If Common.IsInformationRegister(MetadataObject) Then
		
		If TypeOf(MetadataObject) = Type("String") Then
			MetadataObject = Common.MetadataObjectByFullName(MetadataObject);
		EndIf;
		
		Return MetadataObject.EnableTotalsSliceFirst
			Or MetadataObject.EnableTotalsSliceLast;
		
	ElsIf Common.IsAccumulationRegister(MetadataObject) Then
		Return True;
	ElsIf Common.IsAccountingRegister(MetadataObject) Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
