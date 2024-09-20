///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns a message interface version namespace.
//
// Returns:
//   String
//
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Management/" + Version();
	
EndFunction

// Returns a message interface version supported by the handler.
//
// Returns:
//   String
//
Function Version() Export
	
	Return "1.0.1.2";
	
EndFunction

// Returns a base type for version messages.
//
// Returns:
//   String
//
Function BaseType() Export
	
	Return XDTOFactory.Type("http://www.1c.ru/SaaS/Messages", "Body");
	
EndFunction

// Processing incoming SaaS messages
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessagesExchange - exchange plan node that matches the message sender
//  MessageProcessed - Boolean - indicates whether the message is successfully processed. The parameter value must be
//    set to True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = AdditionalReportsAndDataProcessorsManagementMessagesInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageSetAdditionalReportOrDataProcessor(Package()) Then
		SetAdditionalReportOrDataProcessor(Message, Sender);
	ElsIf MessageType = Dictionary.MessageDeleteAdditionalReportOrDataProcessor(Package()) Then
		DeleteAdditionalReportOrDataProcessor(Message, Sender);
	ElsIf MessageType = Dictionary.MessageDisableAdditionalReportOrDataProcessor(Package()) Then
		DisableAdditionalReportOrDataProcessor(Message, Sender);
	ElsIf MessageType = Dictionary.MessageEnableAdditionalReportOrDataProcessor(Package()) Then
		EnableAdditionalReportOrDataProcessor(Message, Sender);
	ElsIf MessageType = Dictionary.MessageWithdrawAdditionalReportOrDataProcessor(Package()) Then
		RevokeAdditionalReportOrDataProcessor(Message, Sender);
	ElsIf MessageType = Dictionary.MessageSetAdditionalReportOrDataProcessorExecutionModeInDataArea(Package()) Then
		SetModeOfAdditionalReportOrDataProcessorAttachmentInDataArea(Message, Sender);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetAdditionalReportOrDataProcessor(Val Message, Val Sender)
	
	Body = Message.Body;
	
	Try
	
		CommandsSettings = CommandsSettings(Body);
		
		SectionsSettings = New ValueTable();
		SectionsSettings.Columns.Add("Section");
		
		AssignmentSettings = New ValueTable();
		AssignmentSettings.Columns.Add("RelatedObject");
		
		CommandsPlacementSettings = New Structure();
		
		If ValueIsFilled(Body.Assignments) Then
			
			For Each Assignment In Body.Assignments Do
				
				If Assignment.Type() = AdditionalReportsAndDataProcessorsSaaSManifestInterface.AssignmentToSectionsType(ManifestPackage()) Then
					
					For Each AssignmentObject In Assignment.Objects Do
						
						SectionRow = SectionsSettings.Add();
						If AssignmentObject.ObjectName = AdditionalReportsAndDataProcessorsClientServer.StartPageName() Then
							SectionRow.Section = Catalogs.MetadataObjectIDs.EmptyRef();
						Else
							Section = Common.MetadataObjectID(AssignmentObject.ObjectName, False);
							SectionRow.Section = ?(ValueIsFilled(Section), Section, Catalogs.MetadataObjectIDs.EmptyRef());
						EndIf;
						
					EndDo;
					
				ElsIf Assignment.Type() = AdditionalReportsAndDataProcessorsSaaSManifestInterface.AssignmentToCatalogsAndDocumentsType(ManifestPackage()) Then
					
					For Each AssignmentObject In Assignment.Objects Do
						RelatedObject = Common.MetadataObjectID(AssignmentObject.ObjectName, False);
						SectionRow.RelatedObject = ?(ValueIsFilled(RelatedObject), RelatedObject, Catalogs.MetadataObjectIDs.EmptyRef());
					EndDo;
					
					CommandsPlacementSettings.Insert("UseForListForm", Assignment.UseInListsForms);
					CommandsPlacementSettings.Insert("UseForObjectForm", Assignment.UseInObjectsForms);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		OptionsSettings = OptionsSettings(Body);
		
		InstallationDetails = New Structure(
			"Id,Presentation,Installation",
			Body.Extension,
			Body.Representation,
			Body.Installation);
		
		AdditionalReportsAndDataProcessorsManagementMessagesImplementation.SetAdditionalReportOrDataProcessor(
			InstallationDetails, CommandsSettings, CommandsPlacementSettings, SectionsSettings,
			AssignmentSettings, OptionsSettings, Body.InitiatorServiceID);
		
	Except
		ExceptionText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(Body.Extension);
		AdditionalReportsAndDataProcessorsSaaS.ProcessErrorOfInstallingAdditionalDataProcessorToDataArea(
			SuppliedDataProcessor, Body.Installation, ExceptionText);
	EndTry;
	
EndProcedure

Function OptionsSettings(Val Body)
	
	OptionsSettings = New ValueTable();
	OptionsSettings.Columns.Add("Key", New TypeDescription("String"));
	OptionsSettings.Columns.Add("Location", New TypeDescription("Array"));
	OptionsSettings.Columns.Add("Presentation", New TypeDescription("String"));
	If Body.ReportVariants = Undefined Then
		Return OptionsSettings;
	EndIf;
		
	For Each ReportVariant In Body.ReportVariants Do
		
		OptionSetting = OptionsSettings.Add();
		OptionSetting.Key = ReportVariant.VariantKey;
		OptionSetting.Presentation = ReportVariant.Representation;
		
		Location = New Array;
		For Each ReportVariantAssignment In ReportVariant.Assignments Do
			
			Section = Common.MetadataObjectID(ReportVariantAssignment.ObjectName, False);
			If Not ValueIsFilled(Section) Then
				Section = Catalogs.MetadataObjectIDs.EmptyRef();
			EndIf;	
			
			Important = False;
			SeeAlso = False;
			If ReportVariantAssignment.Importance = "High" Then
				Important = True;
			ElsIf ReportVariantAssignment.Importance = "Low" Then
				SeeAlso = True;
			EndIf;
			PlacementItem = New Structure("Section,Important,SeeAlso", Section, Important, SeeAlso);
			Location.Add(PlacementItem);
			
		EndDo;
		
		OptionSetting.Location = Location;
		
	EndDo;

	Return OptionsSettings;

EndFunction

Function CommandsSettings(Val Body)
	
	CommandsSettings = New ValueTable();
	CommandsSettings.Columns.Add("Id");
	CommandsSettings.Columns.Add("QuickAccess");
	CommandsSettings.Columns.Add("Schedule");
	
	If Not ValueIsFilled(Body.CommandSettings) Then
		Return CommandsSettings;
	EndIf;
		
	For Each CommandSettings In Body.CommandSettings Do
		
		CommandSettingsSSL = CommandsSettings.Add();
		CommandSettingsSSL.Id = CommandSettings.Id;
		
		If CommandSettings.Settings <> Undefined Then
			
			ArrayOfIdentifiers = New Array;
			For Each UserGUID In CommandSettings.Settings.UsersFastAccess Do
				ArrayOfIdentifiers.Add(UserGUID);
			EndDo;
			
			CommandSettingsSSL.QuickAccess = ArrayOfIdentifiers;
			
			If CommandSettings.Settings.Schedule <> Undefined Then
				CommandSettingsSSL.Schedule = XDTOSerializer.ReadXDTO(CommandSettings.Settings.Schedule);
			EndIf;
			
		EndIf;
		
	EndDo;
	Return CommandsSettings;

EndFunction

Procedure DeleteAdditionalReportOrDataProcessor(Val Message, Val Sender)
	
	Body = Message.Body;
	AdditionalReportsAndDataProcessorsManagementMessagesImplementation.DeleteAdditionalReportOrDataProcessor(
		Body.Extension, Body.Installation);
	
EndProcedure

Procedure DisableAdditionalReportOrDataProcessor(Val Message, Val Sender)
	
	If Message.Body.Reason = "LockByOwner" Then
		DisableReason = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.LockByOwner;
	ElsIf Message.Body.Reason = "LockByProvider" Then
		DisableReason = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.LockByServiceAdministrator;
	EndIf;
	
	AdditionalReportsAndDataProcessorsManagementMessagesImplementation.DisableAdditionalReportOrDataProcessor(
		Message.Body.Extension, DisableReason);
	
EndProcedure

Procedure EnableAdditionalReportOrDataProcessor(Val Message, Val Sender)
	
	AdditionalReportsAndDataProcessorsManagementMessagesImplementation.EnableAdditionalReportOrDataProcessor(
		Message.Body.Extension);
	
EndProcedure

Procedure RevokeAdditionalReportOrDataProcessor(Val Message, Val Sender)
	
	AdditionalReportsAndDataProcessorsManagementMessagesImplementation.RevokeAdditionalReportOrDataProcessor(
		Message.Body.Extension);
	
EndProcedure

Procedure SetModeOfAdditionalReportOrDataProcessorAttachmentInDataArea(Val Message, Val Sender)
	
	AdditionalReportsAndDataProcessorsManagementMessagesImplementation.SetModeOfAdditionalReportOrDataProcessorAttachmentInDataArea(
		Message.Body.Extension, Message.Body.Installation, Message.Body.SecurityProfile);
	
EndProcedure

Function ManifestPackage()
	
	Return AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package("1.0.0.1");
	
EndFunction

#EndRegion