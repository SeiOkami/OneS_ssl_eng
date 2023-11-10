///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}InstallExtension
//
// Parameters:
//  InstallationDetails - Structure:
//    * Id - UUID - UUID of the reference to SuppliedAdditionalReportsAndDataProcessors.
//      
//    * Presentation - String - Presentation of the built-in additional data processor installation.
//      It will be used as a description of the AdditionalReportsAndDataProcessors catalog item.
//      
//    * Installation - UUID - UUID of the built-in additional data processor installation.
//      It will be used as the AdditionalReportsAndDataProcessors catalog reference UUID.
//      
//  CommandsSettings - ValueTable - Installation command settings for the built-in additional data processor:
//      
//    * Id - String - a command ID.
//    * QuickAccess - Array - UUIDs (UUID)
//      that determine service users, to which command needs to be included in
//      quick access,
//    * Schedule - JobSchedule - a job schedule for an
//      additional processing command (if executing the command as
//      a scheduled job is allowed).
//  Sections - ValueTable - Settings for enabling commands for built-in additional data processor installation into the command interface.
//      Has the following columns:
//    * Section - CatalogRef.MetadataObjectIDs
//  CatalogsAndDocuments - ValueTable - Settings for enabling commands for built-in additional data processor installation into list and item forms.
//      Has the following columns:
//    * RelatedObject - CatalogRef.MetadataObjectIDs
//  AdditionalReportOptions - Array - the keys of report options for an additional report (String).
//  ServiceUserID - UUID - Determines a service user who installed the built-in additional data processor.
//    
//
Procedure SetAdditionalReportOrDataProcessor(Val InstallationDetails,
		Val CommandsSettings, Val CommandsPlacementSettings, Val Sections, Val CatalogsAndDocuments, Val AdditionalReportOptions,
		Val ServiceUserID) Export
	
	// Settings are filled in based on the message data
	QuickAccess = New ValueTable();
	QuickAccess.Columns.Add("CommandID", New TypeDescription("String"));
	QuickAccess.Columns.Add("User", New TypeDescription("CatalogRef.Users"));
	
	Jobs = New ValueTable();
	Jobs.Columns.Add("Id", New TypeDescription("String"));
	Jobs.Columns.Add("ScheduledJobSchedule", New TypeDescription("ValueList"));
	Jobs.Columns.Add("ScheduledJobUsage", New TypeDescription("Boolean"));
	
	UsersIDs = New Array;
	For Each CommandSetting In CommandsSettings Do
		If ValueIsFilled(CommandSetting.QuickAccess) Then
			For Each UserIdentificator In CommandSetting.QuickAccess Do
				UsersIDs.Add(UserIdentificator);
			EndDo;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("ServiceUsersIDs", UsersIDs);
	Query.Text =
		"SELECT
		|	Users.Ref
		|FROM
		|	Catalog.Users AS Users
		|WHERE
		|	Users.ServiceUserID IN (&ServiceUsersIDs)";
	QuickAccessUsers = Query.Execute().Unload().UnloadColumn("Ref");
	
	For Each CommandSetting In CommandsSettings Do
		If ValueIsFilled(CommandSetting.QuickAccess) Then
			For Each User In QuickAccessUsers Do
				QuickAccessItem = QuickAccess.Add();
				QuickAccessItem.CommandID = CommandSetting.Id;
				QuickAccessItem.User = User;
			EndDo;
		EndIf;
		
		If CommandSetting.Schedule <> Undefined Then
			Job = Jobs.Add();
			Job.Id = CommandSetting.Id;
			ScheduledJobSchedule = New ValueList();
			ScheduledJobSchedule.Add(CommandSetting.Schedule);
			Job.ScheduledJobSchedule= ScheduledJobSchedule;
			Job.ScheduledJobUsage = True;
		EndIf;
	EndDo;
	
	AdditionalReportsAndDataProcessorsSaaS.InstallSuppliedDataProcessorToDataArea(
		InstallationDetails,
		QuickAccess,
		Jobs,
		Sections,
		CatalogsAndDocuments,
		CommandsPlacementSettings,
		AdditionalReportOptions,
		GetAreaUserByServiceUserID(
			ServiceUserID));
	
EndProcedure

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DeleteExtension
//
// Parameters:
//  SuppliedDataProcessorID - UUID - a reference to the item
//    of the SuppliedAdditionalReportsAndDataProcessors catalog.
//  IDOfDataProcessorToUse - UUID - a reference to the item
//    of the AdditionalReportsAndDataProcessors catalog.
//
Procedure DeleteAdditionalReportOrDataProcessor(Val SuppliedDataProcessorID, Val IDOfDataProcessorToUse) Export
	
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
			SuppliedDataProcessorID);
	
	AdditionalReportsAndDataProcessorsSaaS.DeleteSuppliedDataProcessorFromDataArea(
		SuppliedDataProcessor,
		IDOfDataProcessorToUse);
	
EndProcedure

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DisableExtension
//
// Parameters:
//  ExtensionID - UUID - a reference to the item
//                            of the SuppliedAdditionalReportsAndDataProcessors catalog.
//  DisableReason - EnumRef.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS
//
Procedure DisableAdditionalReportOrDataProcessor(Val ExtensionID, Val DisableReason = Undefined) Export
	
	If DisableReason = Undefined Then
		DisableReason = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.LockByServiceAdministrator;
	EndIf;
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		ExtensionID);
	
	If Common.RefExists(SuppliedDataProcessor) Then
		
		Object = SuppliedDataProcessor.GetObject();
		
		Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled;
		Object.DisableReason = DisableReason;
		
		Object.Write();
		
	EndIf;
	
EndProcedure

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}EnableExtension
//
// Parameters:
//  ExtensionID - UUID - a reference to the item
//                            of the SuppliedAdditionalReportsAndDataProcessors catalog.
//
Procedure EnableAdditionalReportOrDataProcessor(Val ExtensionID) Export
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		ExtensionID);
	
	If Common.RefExists(SuppliedDataProcessor) Then
		
		Object = SuppliedDataProcessor.GetObject();
		
		Object.Publication =
			Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
		
		Object.Write();
	EndIf;
	
EndProcedure

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DropExtension
//
// Parameters:
//  ExtensionID - UUID - a reference to the item
//                            of the SuppliedAdditionalReportsAndDataProcessors catalog.
//
Procedure RevokeAdditionalReportOrDataProcessor(Val SuppliedDataProcessorID) Export
	
	SetPrivilegedMode(True);
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		SuppliedDataProcessorID);
	
	If Common.RefExists(SuppliedDataProcessor) Then
		AdditionalReportsAndDataProcessorsSaaS.RevokeSuppliedAdditionalDataProcessor(
			SuppliedDataProcessor);
	EndIf;
	
EndProcedure

// Processing of incoming messages of type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}SetExtensionSecurityProfile
//
// Parameters:
//  SuppliedDataProcessorID - UUID - a reference to the item
//                            of the SuppliedAdditionalReportsAndDataProcessors catalog.
//  IDOfDataProcessorToUse - UUID - a reference to the item
//                            of the AdditionalReportsAndDataProcessors catalog.
//
Procedure SetModeOfAdditionalReportOrDataProcessorAttachmentInDataArea(Val SuppliedDataProcessorID, Val IDOfDataProcessorToUse, Val AttachmentMode) Export
	
	SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(
		SuppliedDataProcessorID);
	
	DataProcessorToUse = Catalogs.AdditionalReportsAndDataProcessors.GetRef(
		IDOfDataProcessorToUse);
	
	If Common.RefExists(DataProcessorToUse) Then
		SSLSubsystemsIntegration.OnSetAdditionalReportOrDataProcessorAttachmentModeInDataArea(SuppliedDataProcessor, AttachmentMode);
	EndIf;
	
EndProcedure

Function GetAreaUserByServiceUserID(Val ServiceUserID)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.ServiceUserID = &ServiceUserID";
	Query.SetParameter("ServiceUserID", ServiceUserID);
	
	Block = New DataLock;
	Block.Add("Catalog.Users");
	
	BeginTransaction();
	Try
		Block.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The user with service user ID %1 is not found';"), ServiceUserID);
		Raise(MessageText);
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

#EndRegion
