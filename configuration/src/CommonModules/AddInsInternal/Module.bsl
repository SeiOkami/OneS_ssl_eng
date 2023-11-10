///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// 
// 
// Returns:
//  Array - 
//
Function SuppliedAddIns() Export

	UsedAddIns = UsedAddIns();
	Return UsedAddIns.UnloadColumn("Id");
		
EndFunction

// Add-in presentation for the event log
//
Function AddInPresentation(Id, Version) Export

	If ValueIsFilled(Version) Then
		AddInPresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1(version %2)';"), Id, Version);
	Else
		AddInPresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (latest version)';"), Id);
	EndIf;

	Return AddInPresentation;

EndFunction

// Checks whether the add-ins import from the portal is allowed.
//
// Returns:
//  Boolean - the availability criterion.
//
Function CanImportFromPortal() Export

	If Common.SubsystemExists("OnlineUserSupport.GetAddIns") Then
		ModuleGetAddIns = Common.CommonModule("GetAddIns");
		Return ModuleGetAddIns.LoadingExternalComponentsIsAvailable();
	EndIf;

	Return False;

EndFunction

// Returns information about an add-in from its file.
//
// Parameters:
//  BinaryData - BinaryData - add-in binary data.
//  ParseInfoFile - Boolean - whether INFO.XML file data is required
//          to analyze additionally.
//  AdditionalInformationSearchParameters - See AddInsClient.ImportParameters.
//
// Returns:
//  Structure:
//      * Disassembled - Boolean - True if information about an add-in is successfully extracted.
//      * Attributes - See AddInAttributes
//      * BinaryData - BinaryData - add-in file export.
//      * AdditionalInformation - Map - information received by passed search parameters.
//      * ErrorDescription - String - an error text if Disassembled = False.
//      * ErrorInfo - ErrorInfo, Undefined -
//      * IsFileOfService - Boolean -
//
Function InformationOnAddInFromFile(BinaryData, ParseInfoFile = True,
	Val AdditionalInformationSearchParameters = Undefined) Export

	Result = New Structure;
	Result.Insert("Disassembled", False);
	Result.Insert("Attributes", New Structure);
	Result.Insert("BinaryData", Undefined);
	Result.Insert("AdditionalInformation", New Map);
	Result.Insert("ErrorDescription", "");
	Result.Insert("ErrorInfo", Undefined);
	Result.Insert("IsFileOfService", False);
	
	Attributes = AddInAttributes();
	If AdditionalInformationSearchParameters = Undefined Then
		AdditionalInformationSearchParameters = New Map;
	EndIf;
	AdditionalInformation = New Map;
	ManifestIsFound = False;

	Try
		Stream = BinaryData.OpenStreamForRead();
		ReadingArchive = New ZipFileReader(Stream);
	Except
		Result.ErrorDescription = NStr("en = 'Add-in information is missing in the file.';");
		Return Result;
	EndTry;

	TempDirectory = FileSystem.CreateTemporaryDirectory("ExtComp");
	For Each ArchiveItem In ReadingArchive.Items Do

		If ArchiveItem.Encrypted Then

			// 
			FileSystem.DeleteTemporaryDirectory(TempDirectory);
			ReadingArchive.Close();
			Stream.Close();

			Result.ErrorDescription = NStr("en = 'ZIP archive must not be encrypted.';");
			Return Result;

		EndIf;

		Try
			
			OriginalFullName = Lower(ArchiveItem.OriginalFullName);

			If OriginalFullName = "external-components.json" Then
				Result.IsFileOfService = True;
				Result.ErrorDescription = NStr("en = 'This is a file to import add-ins from 1C:ITS Portal.';");
				Return Result;
			EndIf;
			
			// Manifest search and parsing.
			If OriginalFullName = "manifest.xml" Then

				Attributes.VersionDate = ArchiveItem.Modified;

				ReadingArchive.Extract(ArchiveItem, TempDirectory);
				ManifestXMLFile = TempDirectory + GetPathSeparator() + ArchiveItem.FullName;
				FillAttributesByManifestXML(ManifestXMLFile, Attributes);

				ManifestIsFound = True;

			EndIf;

			If OriginalFullName = "info.xml" And ParseInfoFile Then

				ReadingArchive.Extract(ArchiveItem, TempDirectory);
				InfoXMLFile = TempDirectory + GetPathSeparator() + ArchiveItem.FullName;
				FillAttributesByInfoXML(InfoXMLFile, Attributes);

			EndIf;

			For Each SearchParameter In AdditionalInformationSearchParameters Do

				XMLFileName = SearchParameter.Value.XMLFileName;

				If OriginalFullName = Lower(XMLFileName) Then

					AdditionalInformationKey = SearchParameter.Key;
					XPathExpression = SearchParameter.Value.XPathExpression;

					ReadingArchive.Extract(ArchiveItem, TempDirectory);
					ManifestXMLFile = TempDirectory + GetPathSeparator() + ArchiveItem.FullName;

					DOMDocument = DOMDocument(ManifestXMLFile);
					XPathValue = EvaluateXPathExpression(XPathExpression, DOMDocument);

					AdditionalInformation.Insert(AdditionalInformationKey, XPathValue);

				EndIf;

			EndDo;

		Except
			Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Incorrect file %1';"), ArchiveItem.OriginalFullName);
			Result.ErrorInfo = ErrorInfo();
			Return Result;
		EndTry;
	EndDo;

	// 
	FileSystem.DeleteTemporaryDirectory(TempDirectory);
	ReadingArchive.Close();
	Stream.Close();

	// Add-in compatibility control.
	If Not ManifestIsFound Then
		ErrorText = NStr("en = 'The required file MANIFEST.XML is missing from the archive.';");

		Result.ErrorDescription = ErrorText;
		Return Result;
	EndIf;

	Result.Disassembled = True;
	Result.Attributes = Attributes;
	Result.BinaryData = BinaryData;
	Result.AdditionalInformation = AdditionalInformation;

	Return Result;

EndFunction

Procedure CheckTheLocationOfTheComponent(Id, Location) Export

	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		If ModuleAddInsSaaSInternal.IsComponentFromStorage(Location) Then
			Return;
		EndIf;
	EndIf;

	//  
	// 
	If Not (Common.DataSeparationEnabled()
			And Common.SeparatedDataUsageAvailable()) Then
		If Not StrStartsWith(Location, "e1cib/data/Catalog.AddIns.AddInStorage") Then
			If Common.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot attach the %1 add-in due to:
					|Access forbidden. Contact the service administrator to place the add-in in the ""Common add-ins"" catalog.';"), Id);
			Else
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot attach the %1 add-in due to:
					|Access forbidden.';"), Id);
				EndIf;
			Raise ExceptionText;
		EndIf;
	EndIf;

	If StrStartsWith(Location, "e1cib/data/Catalog.AddIns.AddInStorage") Then
		Return;
	EndIf;

	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot attach the %1 add-in due to:
		|Invalid %2 add-in location.';"), Id, Location);

EndProcedure

// Import parameters.
// 
// Returns:
//  Structure:
//   * Id - String
//   * Description - String
//   * Version - String
//   * FileName - String
//   * ErrorDescription - String - information about add-in import
//   * UpdateFrom1CITSPortal - Boolean
//   * Data - String - binary data address to temporary storage 
//          - BinaryData
//
Function ImportParameters() Export
	
	Result = New Structure;
	Result.Insert("Id", "");
	Result.Insert("Description", "");
	Result.Insert("Version", "");
	Result.Insert("FileName", "");
	Result.Insert("ErrorDescription", "");
	Result.Insert("UpdateFrom1CITSPortal", True);
	Result.Insert("Data", "");
	
	Return Result;
	
EndFunction

// Adds a binary data add-in to a catalog.
// 
// Parameters:
//  Parameters - See ImportParameters
//  ParseInfoFile - Boolean - whether INFO.XML file data is required
//          to analyze additionally
//  UsedAddIns - See UsedAddIns
//
Procedure LoadAComponentFromBinaryData(Parameters, ParseInfoFile = True, UsedAddIns = Undefined) Export
	
	If TypeOf(Parameters.Data) = Type("String") Then
		If IsBlankString(Parameters.Data) Then
			ExceptionText = NStr("en = 'Data is not filled in.';");
			Raise ExceptionText;
		Else
			If IsTempStorageURL(Parameters.Data) Then
				BinaryData = GetFromTempStorage(Parameters.Data);
			Else
				Raise NStr("en = 'The data address is not a temporary storage address.';");
			EndIf;
		EndIf;
	Else
		BinaryData = Parameters.Data;
	EndIf;
	
	If TypeOf(BinaryData) <> Type("BinaryData") Then
		ExceptionText =  NStr("en = 'The file data is not binary data.';");
		Raise ExceptionText;
	EndIf;
	
	Information = InformationOnAddInFromFile(BinaryData, ParseInfoFile);

	If Not Information.Disassembled Then
		
		ExceptionText = Information.ErrorDescription + ?(Information.ErrorInfo = Undefined, "",
			 ": " + ErrorProcessing.BriefErrorDescription(Information.ErrorInfo));
		
		WriteLogEvent(NStr("en = 'Add add-in';", Common.DefaultLanguageCode()),
			EventLogLevel.Error, , , ExceptionText);
		Raise ExceptionText;
	EndIf;
	
	Id = ?(ValueIsFilled(Parameters.Id), Parameters.Id, Information.Attributes.Id);
	
	If Not ValueIsFilled(Id) Then
		ExceptionText = NStr("en = 'Enter the ID.';");
		Raise ExceptionText;
	EndIf;
	
	BeginTransaction();
	Try

		Block = New DataLock;
		Block.Add("Catalog.AddIns");
		Block.Lock();

		Component_SSLy = Catalogs.AddIns.FindByID(Id);

		If ValueIsFilled(Component_SSLy) Then
			Object = Component_SSLy.GetObject();
			Try
				TheResultOfComparingVersions = CommonClientServer.CompareVersions(Object.Version, Parameters.Version);
			Except
				// 
				TheResultOfComparingVersions = -1;
			EndTry;
			If TheResultOfComparingVersions >= 0 Then
				RollbackTransaction();
				Return;
			EndIf;
		Else
			Object = Catalogs.AddIns.CreateItem();
			// 
			Object.Fill(Undefined); // 
		EndIf;
		
		 // According to manifest data.
		FillPropertyValues(Object, Information.Attributes, , "Description, Version, FileName");
		
		Object.Id = Id;
		// 
		Object.Description = ?(ValueIsFilled(Parameters.Description), Parameters.Description, Information.Attributes.Description);
		Object.Version = ?(ValueIsFilled(Parameters.Version), Parameters.Version, Information.Attributes.Version);
		Object.FileName = ?(ValueIsFilled(Parameters.FileName), Parameters.FileName, Information.Attributes.FileName);
		Object.ErrorDescription = Parameters.ErrorDescription;
		Object.UpdateFrom1CITSPortal = Parameters.UpdateFrom1CITSPortal;
		
		If UsedAddIns <> Undefined Then
			RowOfAddIn = UsedAddIns.Find(Id, "Id");
			If RowOfAddIn <> Undefined Then
				Object.UpdateFrom1CITSPortal = RowOfAddIn.AutoUpdate;
			EndIf;
		EndIf;
		
		Object.AdditionalProperties.Insert("ComponentBinaryData", Information.BinaryData);
		
		Object.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Add add-in';", Common.DefaultLanguageCode()), 
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure


#Region ConfigurationSubsystemsEventHandlers

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export

	Objects.Insert(Metadata.Catalogs.AddIns.FullName(), "AttributesToEditInBatchProcessing");

EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export

	ModuleExportImportData = Common.CommonModule("ExportImportData");
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.AddIns,
		ModuleExportImportData.ActionWithClearLinks());

EndProcedure

// See StandardSubsystems.OnSendDataToMaster.
Procedure OnSendDataToMaster(DataElement, ItemSend,
		Recipient) Export

	If TypeOf(DataElement) = Type("CatalogObject.AddIns") Then
		ItemSend = DataItemSend.Ignore;
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave.
Procedure OnSendDataToSlave(DataElement, ItemSend,
		InitialImageCreating, Recipient) Export

	If TypeOf(DataElement) = Type("CatalogObject.AddIns") Then
		ItemSend = DataItemSend.Ignore;
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive,
		SendBack, Sender) Export

	If TypeOf(DataElement) = Type("CatalogObject.AddIns") Then
		ItemReceive = DataItemReceive.Ignore;
	EndIf;

EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive,
		SendBack, Sender) Export

	If TypeOf(DataElement) = Type("CatalogObject.AddIns") Then
		ItemReceive = DataItemReceive.Ignore;
	EndIf;

EndProcedure

// See CommonOverridable.OnAddServerNotifications
Procedure OnAddServerNotifications(Notifications) Export
	
	Notification = ServerNotifications.NewServerNotification(
		"StandardSubsystems.AddIns");
	
	Notification.NotificationSendModuleName  = "AddInsInternal";
	Notification.NotificationReceiptModuleName = "AddInsInternalClient";
	
	Notifications.Insert(Notification.Name, Notification);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Users.IsExternalUserSession() Or Not Users.IsFullUser() Then
		Return;
	EndIf;

	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.AddIns.FullName());

	UnusedAddInsCount = UnusedAddInsCount();
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add ();
		ToDoItem.Id  = "DeleteUnusedAddIns";
		ToDoItem.HasToDoItems       = UnusedAddInsCount > 0;
		ToDoItem.Presentation  = NStr("en = 'Delete unused add-ins';");
		ToDoItem.Count     = UnusedAddInsCount;
		ToDoItem.Important         = False;
		ToDoItem.Form          = "Catalog.AddIns.ListForm";
		ToDoItem.FormParameters = New Structure("UseFilter", 3);
		ToDoItem.Owner       = Section;
	EndDo;

EndProcedure

#EndRegion

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.6.48";
	Handler.Id = New UUID("cb3e8653-f1d2-4439-afdd-b1d27f6dcc2f");
	Handler.Procedure = "Catalogs.AddIns.ProcessDataForMigrationToNewVersion";
	Handler.Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Fill in the ""%1"", ""%2"", ""%3"" attributes, which were previously not filled in by mistake';"),
		"MacOS_x86_64_Safari", "MacOS_x86_64_Chrome", "MacOS_x86_64_Firefox");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.AddIns.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead      = "Catalog.AddIns";
	Handler.ObjectsToChange    = "Catalog.AddIns";
	
EndProcedure

#EndRegion

#Region Private

// 
// 
// Returns:
//  ValueTable:
//   * Id - String
//   * AutoUpdate - Boolean 
//
Function UsedAddIns() Export
	
	UsedAddIns = New ValueTable;
	UsedAddIns.Columns.Add("Id",          Common.StringTypeDetails(50));
	UsedAddIns.Columns.Add("AutoUpdate", New TypeDescription("Boolean"));
	
	SSLSubsystemsIntegration.OnDefineUsedAddIns(UsedAddIns);
	
	Return UsedAddIns;
	
EndFunction

// 
//
// Returns:
//  Boolean - the availability criterion.
//
Function CanImportFromPortalInteractively() Export

	If Common.SubsystemExists("OnlineUserSupport") 
		And Common.SubsystemExists("OnlineUserSupport.GetAddIns") Then
		ModuleOnlineUserSupportClientServer = Common.CommonModule("OnlineUserSupportClientServer");
		If CommonClientServer.CompareVersions(
			ModuleOnlineUserSupportClientServer.LibraryVersion(), "2.7.2.0") >= 0 Then
			ModuleGetAddIns = Common.CommonModule("GetAddIns");
			Return ModuleGetAddIns.LoadingExternalComponentsIsAvailable();
		EndIf;
	EndIf;

	Return False;

EndFunction

// 
//
// Parameters:
//  Variant - String -
//    
//    
//
// Returns:
//   ValueTable:
//    * Id - String
//    * Version - String
//    * Description - String
//    * VersionDate - Date
//    * AutoUpdate - Boolean
//
Function AddInsData(Variant = "ForUpdate") Export
	
	Query = New Query;
	
	If Variant = "ForUpdate" Then
		Query.Text = 
			"SELECT
			|	AddIns.Id AS Id,
			|	AddIns.Version AS Version,
			|	AddIns.Description AS Description,
			|	AddIns.VersionDate AS VersionDate,
			|	AddIns.UpdateFrom1CITSPortal AS AutoUpdate
			|FROM
			|	Catalog.AddIns AS AddIns
			|WHERE
			|	AddIns.UpdateFrom1CITSPortal";
			
	ElsIf Variant = "ForImport" Then
		
		Query.Text =
			"SELECT
			|	UsedAddIns.Id,
			|	UsedAddIns.AutoUpdate
			|INTO UsedAddIns
			|FROM
			|	&UsedAddIns AS UsedAddIns
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	ISNULL(AddIns.Id, UsedAddIns.Id) AS Id,
			|	ISNULL(AddIns.Version, """") AS Version,
			|	ISNULL(AddIns.Description, """") AS Description,
			|	ISNULL(AddIns.VersionDate, DATETIME(1, 1, 1)) AS VersionDate,
			|	ISNULL(AddIns.UpdateFrom1CITSPortal, UsedAddIns.AutoUpdate) AS
			|		AutoUpdate
			|FROM
			|	Catalog.AddIns AS AddIns
			|		FULL JOIN UsedAddIns AS UsedAddIns
			|		ON AddIns.Id = UsedAddIns.Id";
			
			Query.SetParameter("UsedAddIns", UsedAddIns());
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown parameter %1 in %2.';"), Variant,
			"AddInsInternal.AddInsData");
	EndIf;
	
	QueryResult = Query.Execute();
	AddInsDetails = QueryResult.Unload();
	
	Return AddInsDetails;

EndFunction

Procedure DeleteUnusedAddIns() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AddIns.Ref AS Ref
	|FROM
	|	Catalog.AddIns AS AddIns
	|WHERE
	|	NOT AddIns.DeletionMark
	|	AND NOT AddIns.Id IN (&IDs)";

	Query.SetParameter("IDs", SuppliedAddIns());

	Selection = Query.Execute().Select();
	While Selection.Next() Do

		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AddIns");
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();

			Object = Selection.Ref.GetObject();
			Object.DeletionMark = True;
			Object.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Delete the add-in';", Common.DefaultLanguageCode()),
				EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(
				ErrorInfo()));
			Raise;
		EndTry;
		
	EndDo;
	
	NotifyAllSessionsAboutAddInChange();
	
EndProcedure

Function UnusedAddInsCount()
	
	UnusedAddInsCount = 0;
	
	Query = New Query;
	Query.Text = 
			"SELECT
			|	COUNT(AddIns.Ref) AS UnusedAddInsCount
			|FROM
			|	Catalog.AddIns AS AddIns
			|WHERE
			|	NOT AddIns.DeletionMark
			|	AND NOT AddIns.Id IN (&IDs)";
	
	Query.SetParameter("IDs", SuppliedAddIns());
		
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Return Selection.UnusedAddInsCount;
	EndDo;
	
	Return UnusedAddInsCount;
	
EndFunction

Procedure NotifyAllSessionsAboutAddInChange() Export
	
	ServerNotifications.SendServerNotification(
		"StandardSubsystems.AddIns", "", Undefined, True);
	
EndProcedure

// See StandardSubsystemsServer.OnSendServerNotification
Procedure OnSendServerNotification(NameOfAlert, ParametersVariants) Export
	
	If NameOfAlert <> "StandardSubsystems.AddIns" Then
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.AddIns.Versions";
	PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	NewValue = AddInsVersionsChecksum();
	
	If PreviousValue2 = NewValue Then
		Return;
	EndIf;
	
	ServerNotifications.SendServerNotification(NameOfAlert, "", Undefined);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	BeginTransaction();
	Try
		Block.Lock();
		PreviousValue2 = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
		If PreviousValue2 <> NewValue Then
			StandardSubsystemsServer.SetExtensionParameter(ParameterName, NewValue, True);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function AddInsVersionsChecksum()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AddIns.Ref AS Ref,
	|	AddIns.DataVersion AS DataVersion
	|FROM
	|	Catalog.AddIns AS AddIns";
	
	Selection = Query.Execute().Select();
	
	VersionsList = New ValueList;
	AddAddInVersions(VersionsList, Selection);
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		Selection = ModuleAddInsSaaSInternal.SharedAddInVersions();
		AddAddInVersions(VersionsList, Selection);
	EndIf;
	
	VersionsList.SortByValue();
	Versions = StrConcat(VersionsList.UnloadValues(), Chars.LF);
	Hashing = New DataHashing(HashFunction.SHA256);
	Hashing.Append(Versions);
	StringHashSum = Base64String(Hashing.HashSum);
	
	Return StringHashSum;
	
EndFunction

// Parameters:
//  VersionsList - ValueList
//  Selection - DataSelection:
//   * Ref - CatalogRef
//   * DataVersion - String
//
Procedure AddAddInVersions(VersionsList, Selection)
	
	While Selection.Next() Do
		VersionsList.Add(Lower(Selection.Ref.UUID())
			+ " " + Selection.DataVersion);
	EndDo;
	
EndProcedure

// Checks whether an add-in from the add-in storage 
// based on Native API or COM technologies can be attached on 1C:Enterprise server.
//
// Parameters:
//   Id - String - the add-in identification code.
//   Version        - String - an add-in version.
//   ConnectionParameters - See AddInsServer.ConnectionParameters.
//
// Returns:
//   String - brief description of the error. 
//
Function CheckAddInAttachmentAbility(Val Id,
		Val Version = Undefined,
		Val ConnectionParameters = Undefined) Export

	If ConnectionParameters = Undefined Then
		ConnectionParameters = AddInsServer.ConnectionParameters();
	EndIf;

	If IsBlankString(Id) Then
		AddInContainsOneObjectClass = (ConnectionParameters.ObjectsCreationIDs.Count() = 0);
		If AddInContainsOneObjectClass Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'When attaching an external add-in, ""%1"" and ""%2"" cannot be empty at the same time.';"),
				"Id", "ObjectsCreationIDs");
		EndIf;
		Id = StrConcat(ConnectionParameters.ObjectsCreationIDs, ", ");
	EndIf;

	Result = New Structure;
	Result.Insert("Location", "");
	Result.Insert("Id", Id);
	Result.Insert("ErrorDescription", "");
	Result.Insert("Version", "");

	Information = AddInsInternalServerCall.SavedAddInInformation(Id, Version);
	Result.Insert("Version", Version);
	If Information.State = "DisabledByAdministrator" Then
		Result.ErrorDescription = NStr("en = 'The add-in is disabled by the administrator.';");
		Return Result;
	ElsIf Information.State = "NotFound1" Then
		Result.ErrorDescription = NStr("en = 'The add-in is missing from the list of allowed add-ins.';");
		Return Result;
	ElsIf Not OperatingSystemSupportedByAddInn(Information.Attributes) Then
		SystemInfo = New SystemInfo;
		Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The add-in does not work in the %1 operating system.';"), String(SystemInfo.PlatformType));
		Return Result;
	EndIf;
	CheckTheLocationOfTheComponent(Id, Information.Location);
	Result.Location = Information.Location;
	Return Result;

EndFunction

#Region SavedAddInInformation

Function OperatingSystemSupportedByAddInn(AddInAttributes)

	SystemInfo = New SystemInfo;

	If SystemInfo.PlatformType = PlatformType.Linux_x86 Then
		Return AddInAttributes.Linux_x86;
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		Return AddInAttributes.Linux_x86_64;
	ElsIf SystemInfo.PlatformType = PlatformType.MacOS_x86_64 Then
		Return AddInAttributes.MacOS_x86_64;
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86 Then
		Return AddInAttributes.Windows_x86;
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		Return AddInAttributes.Windows_x86_64;
	EndIf;

	Return False;

EndFunction

Function ImportFromFileIsAvailable()

	Return Users.IsFullUser(, , False);

EndFunction

// Parameters:
//   Id - String               - the add-in identification code.
//   Version        - String
//                 - Undefined - version of the component.
//   ThePathToTheLayoutToSearchForTheLatestVersion 
//                 - 
//                 
//
// Returns:
//  Structure:
//    * CanImportFromPortal - Boolean
//    * ImportFromFileIsAvailable - Boolean
//    * State - String - "NotFound", "FoundInStorage", "FoundInSharedStorage", "DisabledByAdministrator" 
//    * Location - String
//    * Ref - AnyRef
//    * Attributes - See AddInAttributes
//    * TheLatestVersionOfComponentsFromTheLayout 
//    		- See StandardSubsystemsCached.TheLatestVersionOfComponentsFromTheLayout
//    		- Undefined
//
Function SavedAddInInformation(Id, Version = Undefined, ThePathToTheLayoutToSearchForTheLatestVersion = Undefined) Export

	Result = New Structure;
	Result.Insert("Ref");
	Result.Insert("Attributes", AddInAttributes());
	Result.Insert("Location");
	Result.Insert("State");
	Result.Insert("ImportFromFileIsAvailable", ImportFromFileIsAvailable());
	Result.Insert("CanImportFromPortal", CanImportFromPortal());
	Result.Insert("TheLatestVersionOfComponentsFromTheLayout");

	If Common.DataSeparationEnabled()
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
	
		ModuleAddInsSaaSInternal = Common.CommonModule("AddInsSaaSInternal");
		ModuleAddInsSaaSInternal.FillAddInInformation(Result, Version, Id);
	Else	
		ReferenceFromStorage = Catalogs.AddIns.FindByID(Id, Version);
		If ReferenceFromStorage.IsEmpty() Then
			Result.State = "NotFound1";
		Else
			Result.State = "FoundInStorage";
			Result.Ref = ReferenceFromStorage;
		EndIf
	EndIf;
	
	If ThePathToTheLayoutToSearchForTheLatestVersion <> Undefined Then
		Result.TheLatestVersionOfComponentsFromTheLayout = StandardSubsystemsCached.TheLatestVersionOfComponentsFromTheLayout(
			ThePathToTheLayoutToSearchForTheLatestVersion);
	EndIf;

	If Result.State = "NotFound1" Then
		Return Result;
	EndIf;

	Attributes = AddInAttributes();
	If Result.State = "FoundInStorage" Then
		Attributes.Insert("Use");
	EndIf;
	If Result.State = "FoundInSharedStorage" Then
		Attributes.Delete("FileName");
	EndIf;

	ObjectAttributes = Common.ObjectAttributesValues(Result.Ref, Attributes);

	FillPropertyValues(Result.Attributes, ObjectAttributes);
	Result.Location = GetURL(Result.Ref, "AddInStorage");

	If Result.State = "FoundInStorage" Then
		If ObjectAttributes.Use <> Enums.AddInUsageOptions.Used Then
			Result.State = "DisabledByAdministrator";
		EndIf;
	EndIf;
	
	Return Result;

EndFunction

// Returns:
//  Structure:
//    * Windows_x86 - Boolean
//    * Windows_x86_64 - Boolean
//    * Linux_x86 - Boolean
//    * Linux_x86_64 - Boolean
//    * Windows_x86_Firefox - Boolean
//    * Linux_x86_Firefox - Boolean
//    * Linux_x86_64_Firefox - Boolean
//    * Windows_x86_MSIE - Boolean
//    * Windows_x86_64_MSIE - Boolean
//    * Windows_x86_Chrome - Boolean
//    * Linux_x86_Chrome - Boolean
//    * Linux_x86_64_Chrome - Boolean
//    * MacOS_x86_64_Safari - Boolean
//    * MacOS_x86_64_Chrome - Boolean
//    * MacOS_x86_64_Firefox - Boolean
//    * Windows_x86_YandexBrowser - Boolean
//    * Windows_x86_64_YandexBrowser - Boolean
//    * Linux_x86_YandexBrowser - Boolean
//    * Linux_x86_64_YandexBrowser - Boolean
//    * MacOS_x86_64_YandexBrowser - Boolean
//    * Id - String
//    * Description - String
//    * Version - String
//    * VersionDate - Date
//    * FileName - String
//
Function AddInAttributes()

	Attributes = New Structure;
	Attributes.Insert("Windows_x86");
	Attributes.Insert("Windows_x86_64");
	Attributes.Insert("Linux_x86");
	Attributes.Insert("Linux_x86_64");
	Attributes.Insert("Windows_x86_Firefox");
	Attributes.Insert("Linux_x86_Firefox");
	Attributes.Insert("Linux_x86_64_Firefox");
	Attributes.Insert("Windows_x86_MSIE");
	Attributes.Insert("Windows_x86_64_MSIE");
	Attributes.Insert("Windows_x86_Chrome");
	Attributes.Insert("Linux_x86_Chrome");
	Attributes.Insert("Linux_x86_64_Chrome");
	Attributes.Insert("MacOS_x86_64");
	Attributes.Insert("MacOS_x86_64_Safari");
	Attributes.Insert("MacOS_x86_64_Chrome");
	Attributes.Insert("MacOS_x86_64_Firefox");
	Attributes.Insert("Windows_x86_YandexBrowser");
	Attributes.Insert("Windows_x86_64_YandexBrowser");
	Attributes.Insert("Linux_x86_YandexBrowser");
	Attributes.Insert("Linux_x86_64_YandexBrowser");
	Attributes.Insert("MacOS_x86_64_YandexBrowser");
	Attributes.Insert("Id");
	Attributes.Insert("Description");
	Attributes.Insert("Version");
	Attributes.Insert("VersionDate");
	Attributes.Insert("FileName");

	Return Attributes;

EndFunction

#EndRegion

#Region GetInformationFromComponentFile

Procedure FillAttributesByManifestXML(ManifestXMLFileName, Attributes)

	XMLReader = New XMLReader;
	XMLReader.OpenFile(ManifestXMLFileName);

	XMLReader.MoveToContent();
	If XMLReader.Name = "bundle" And XMLReader.NodeType = XMLNodeType.StartElement Then
		While XMLReader.Read() Do
			If XMLReader.Name = "component" And XMLReader.NodeType = XMLNodeType.StartElement Then

				OperatingSystem = Lower(XMLReader.AttributeValue("os"));
				ComponentType = Lower(XMLReader.AttributeValue("type"));
				PlatformArchitecture = Lower(XMLReader.AttributeValue("arch"));
				Viewer = Lower(XMLReader.AttributeValue("client"));

				If OperatingSystem = "windows" And PlatformArchitecture = "i386"
						And (ComponentType = "native" Or ComponentType = "com") Then

					Attributes.Windows_x86 = True;
					Continue;
				EndIf;

				If OperatingSystem = "windows" And PlatformArchitecture = "x86_64"
						And (ComponentType = "native" Or ComponentType = "com") Then

					Attributes.Windows_x86_64 = True;
					Continue;
				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "i386"
						And ComponentType = "native" Then

					Attributes.Linux_x86 = True;
					Continue;
				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "x86_64"
						And ComponentType = "native" Then

					Attributes.Linux_x86_64 = True;
					Continue;
				EndIf;

				If OperatingSystem = "windows" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And Viewer = "firefox" Then

					Attributes.Windows_x86_Firefox = True;
					Continue;
				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And Viewer = "firefox" Then

					Attributes.Linux_x86_Firefox = True;
					Continue;
				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "x86_64"
						And ComponentType = "plugin" And Viewer = "firefox" Then

					Attributes.Linux_x86_64_Firefox = True;
					Continue;
				EndIf;

				If OperatingSystem = "windows" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And Viewer = "msie" Then

					Attributes.Windows_x86_MSIE = True;
					Continue;
				EndIf;

				If OperatingSystem = "windows" And PlatformArchitecture = "x86_64"
						And ComponentType = "plugin" And Viewer = "msie" Then

					Attributes.Windows_x86_64_MSIE = True;
					Continue;
				EndIf;

				If OperatingSystem = "windows" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And (Viewer = "chrome" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Windows_x86_Chrome = True;

				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And (Viewer = "chrome" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Linux_x86_Chrome = True;

				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "x86_64"
						And ComponentType = "plugin" And (Viewer = "chrome" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Linux_x86_64_Chrome = True;

				EndIf;

				If OperatingSystem = "macos" And (PlatformArchitecture = "x86_64"
						Or PlatformArchitecture = "universal") And ComponentType = "native" Then

					Attributes.MacOS_x86_64 = True;
					Continue;
				EndIf;

				If OperatingSystem = "macos" And (PlatformArchitecture = "x86_64"
						Or PlatformArchitecture = "universal") And ComponentType = "plugin"
						And Viewer = "safari" Then

					Attributes.MacOS_x86_64_Safari = True;
					Continue;
				EndIf;
				
				If OperatingSystem = "macos" And (PlatformArchitecture = "x86_64"
						Or PlatformArchitecture = "universal") And ComponentType = "plugin"
						And (Viewer = "chrome" Or Viewer = "anychromiumbased") Then

					Attributes.MacOS_x86_64_Chrome = True;

				EndIf;
				
				If OperatingSystem = "macos" And (PlatformArchitecture = "x86_64"
						Or PlatformArchitecture = "universal") And ComponentType = "plugin"
						And Viewer = "firefox" Then

					Attributes.MacOS_x86_64_Firefox = True;
					Continue;
				EndIf;
				
				If OperatingSystem = "windows" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And (Viewer = "yandexbrowser" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Windows_x86_YandexBrowser = True;

				EndIf;
				
				If OperatingSystem = "windows" And PlatformArchitecture = "x86_64"
						And ComponentType = "plugin" And (Viewer = "yandexbrowser" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Windows_x86_64_YandexBrowser = True;

				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "i386"
						And ComponentType = "plugin" And (Viewer = "yandexbrowser" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Linux_x86_YandexBrowser = True;

				EndIf;

				If OperatingSystem = "linux" And PlatformArchitecture = "x86_64"
						And ComponentType = "plugin" And (Viewer = "yandexbrowser" 
						Or Viewer = "anychromiumbased") Then

					Attributes.Linux_x86_64_YandexBrowser = True;

				EndIf;
				
				If OperatingSystem = "macos" And (PlatformArchitecture = "x86_64"
						Or PlatformArchitecture = "universal") And ComponentType = "plugin"
						And (Viewer = "yandexbrowser" 
						Or Viewer = "anychromiumbased") Then

					Attributes.MacOS_x86_64_YandexBrowser = True;

				EndIf;

			EndIf;
		EndDo;
	EndIf;
	XMLReader.Close();

EndProcedure

Procedure FillAttributesByInfoXML(InfoXMLFileName, Attributes)

	FileRead = False;

	// TryingToParseByPLFormat
	XMLReader = New XMLReader;
	XMLReader.OpenFile(InfoXMLFileName);

	XMLReader.MoveToContent();
	If XMLReader.Name = "drivers" And XMLReader.NodeType = XMLNodeType.StartElement Then
		While XMLReader.Read() Do
			If XMLReader.Name = "component" And XMLReader.NodeType = XMLNodeType.StartElement Then

				Id = XMLReader.AttributeValue("progid");
				
				Attributes.Id = Mid(Id, StrFind(Id, ".") + 1);
				Attributes.Description = XMLReader.AttributeValue("name");
				Attributes.Version = XMLReader.AttributeValue("version");

				FileRead = True;

			EndIf;
		EndDo;
	EndIf;
	XMLReader.Close();

	If FileRead Then
		Return;
	EndIf;

	// 
	XMLReader = New XMLReader;
	XMLReader.OpenFile(InfoXMLFileName);

	InformationOfAddIn = XDTOFactory.ReadXML(XMLReader);
	Attributes.Id = InformationOfAddIn.progid;
	Attributes.Description = InformationOfAddIn.name;
	Attributes.Version = InformationOfAddIn.version;

	XMLReader.Close();

EndProcedure

Function EvaluateXPathExpression(Expression, DOMDocument)

	XPathValue = Undefined;

	Dereferencer = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression(Expression, DOMDocument, Dereferencer);

	ResultNode = XPathResult.IterateNext();
	If TypeOf(ResultNode) = Type("DOMAttribute") Then
		XPathValue = ResultNode.Value;
	EndIf;

	Return XPathValue
EndFunction

Function DOMDocument(PathToFile)

	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(XMLReader);
	XMLReader.Close();

	Return DOMDocument;

EndFunction

#EndRegion

#Region ImportFromPortal

Procedure CheckImportFromPortalAvailability()

	If Not CanImportFromPortal() Then
		Raise NStr("en = 'Cannot update add-ins from the 1C:ITS portal.';");
	EndIf;

EndProcedure

// Returns:
//  Structure:
//   * Id - String
//   * Version - String
//   * AutoUpdate - Boolean
//
Function ComponentParametersFromThePortal() Export
	
	Result = New Structure;
	Result.Insert("Id", "");
	Result.Insert("Version", "");
	Result.Insert("AutoUpdate", True);
	Return Result;
	
EndFunction
	
// Parameters:
//  ProcedureParameters - See ComponentParametersFromThePortal.
//  ResultAddress - String
//
Procedure NewAddInsFromPortal(ProcedureParameters, ResultAddress) Export

	If Common.SubsystemExists("OnlineUserSupport.GetAddIns") Then

		Id = ProcedureParameters.Id;
		Version = ProcedureParameters.Version;

		CheckImportFromPortalAvailability();

		ModuleGetAddIns = Common.CommonModule("GetAddIns");

		AddInsDetails = ModuleGetAddIns.AddInsDetails();
		AddInDetails = AddInsDetails.Add();
		AddInDetails.Id = Id;
		AddInDetails.Version = Version;

		If Not ValueIsFilled(Version) Then
			OperationResult = ModuleGetAddIns.CurrentVersionsOfExternalComponents(AddInsDetails);
		Else
			OperationResult = ModuleGetAddIns.VersionsOfExternalComponents(AddInsDetails);
		EndIf;

		If ValueIsFilled(OperationResult.ErrorCode) Then
			ExceptionText = ?(Users.IsFullUser(), OperationResult.ErrorInfo, OperationResult.ErrorMessage);
			Raise ExceptionText;
		EndIf;

		If OperationResult.AddInsData.Count() = 0 Then
			ExceptionText = NStr("en = 'Add-in is not found on 1C:ITS portal.';");
			WriteLogEvent(NStr("en = 'Updating add-ins';", Common.DefaultLanguageCode()), EventLogLevel.Error, , , ExceptionText);
			Raise ExceptionText;
		EndIf;

		ResultString1 = OperationResult.AddInsData[0];
		ErrorCode = ResultString1.ErrorCode;

		If ValueIsFilled(ErrorCode) Then

			ErrorInfo = "";
			If ErrorCode = "ComponentNotFound" Then
				ErrorInfo = NStr("en = 'The required add-in %1 is missing from the 1C:ITS portal';");
			ElsIf ErrorCode = "VersionNotFound" Then
				ErrorInfo = NStr("en = 'The required version of the %1 add-in is missing from the 1C:ITS portal.';");
			ElsIf ErrorCode = "FileNotImported" Or ErrorCode = "LatestVersion" Then
				ErrorInfo = NStr("en = 'Cannot import the %1 add-in due to an unexpected reason (code %2).';");
			EndIf;

			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorInfo, 
				AddInPresentation(Id, Version), ErrorCode);
			WriteLogEvent(NStr("en = 'Updating add-ins';", Common.DefaultLanguageCode()), 
				EventLogLevel.Error, , , ErrorText);
			Raise ErrorText;
		EndIf;

		BinaryData = GetFromTempStorage(ResultString1.FileAddress);
		Information = InformationOnAddInFromFile(BinaryData, False);

		If Not Information.Disassembled Then
			
			ExceptionText = Information.ErrorDescription + ?(Information.ErrorInfo = Undefined, "",
			 ": " + ErrorProcessing.BriefErrorDescription(Information.ErrorInfo));
				
			WriteLogEvent(NStr("en = 'Updating add-ins';", Common.DefaultLanguageCode()), 
				EventLogLevel.Error, , , ExceptionText);
			Raise ExceptionText;
		EndIf;

		SetPrivilegedMode(True);

		BeginTransaction();
		Try
			// Create an add-in instance.
			Object = Catalogs.AddIns.CreateItem();
			Object.Fill(Undefined); // 
			FillPropertyValues(Object, Information.Attributes); // According to manifest data.
			FillPropertyValues(Object, ResultString1); // 
			Object.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Imported from 1C:ITS Portal. %1.';"), CurrentSessionDate());

			Object.AdditionalProperties.Insert("ComponentBinaryData", Information.BinaryData);

			If Not ValueIsFilled(Version) Then // Если запрос конкретной версии - 
				Object.UpdateFrom1CITSPortal = Object.ThisIsTheLatestVersionComponent()
					And ProcedureParameters.AutoUpdate;
			EndIf;

			Object.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Updating add-ins';", Common.DefaultLanguageCode()), EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		NotifyAllSessionsAboutAddInChange();
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Operation is unavailable. Subsystem ""%1"" is required.';"),
			"OnlineUserSupport.GetAddIns");
	EndIf;

EndProcedure

// Returns:
//   Structure:
//     * AddInsToUpdate - Array of CatalogRef.AddIns 
//  
Function ParametersForUpdatingAComponentFromThePortal() Export
	
	Result = New Structure;
	Result.Insert("AddInsToUpdate", New Array);
	Return Result;
	
EndFunction

// Parameters:
//  ProcedureParameters - See ParametersForUpdatingAComponentFromThePortal
//  ResultAddress - String
//
Procedure UpdateAddInsFromPortal(ProcedureParameters, ResultAddress) Export

	If Common.SubsystemExists("OnlineUserSupport.GetAddIns") Then

		CheckImportFromPortalAvailability();

		ModuleGetAddIns = Common.CommonModule("GetAddIns");
		AddInsDetails = ModuleGetAddIns.AddInsDetails();

		AddInsToUpdate = ProcedureParameters.AddInsToUpdate;
		Attributes = Common.ObjectsAttributesValues(AddInsToUpdate, "Id, Version");
		For Each AddInToUpdate In AddInsToUpdate Do
			ComponentDetails = AddInsDetails.Add();
			ComponentDetails.Id = Attributes[AddInToUpdate].Id;
			ComponentDetails.Version = Attributes[AddInToUpdate].Version;
		EndDo;

		OperationResult = ModuleGetAddIns.CurrentVersionsOfExternalComponents(AddInsDetails);
		If ValueIsFilled(OperationResult.ErrorCode) Then
			ExceptionText = ?(Users.IsFullUser(), OperationResult.ErrorInfo, OperationResult.ErrorMessage);
			Raise ExceptionText;
		EndIf;

		AddInsServer.UpdateAddIns(OperationResult.AddInsData, ResultAddress);
		NotifyAllSessionsAboutAddInChange();
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Operation is unavailable. Subsystem ""%1"" is required.';"),
			"OnlineUserSupport.GetAddIns");
	EndIf;

EndProcedure

#EndRegion

#EndRegion