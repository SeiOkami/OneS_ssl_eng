///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnReadAtServer(CurrentObject)
	Rereading = (Cache <> Undefined);
	
	// Standard subsystems.Pluggable commands
		If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
			ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
			ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
		EndIf;
	// 

	// Read value storage .
	If CurrentObject.HTMLFormatEmail Then
		EmailAttachmentsStructureInHTMLFormat = CurrentObject.EmailPicturesInHTMLFormat.Get();
		If EmailAttachmentsStructureInHTMLFormat = Undefined Then
			EmailAttachmentsStructureInHTMLFormat = New Structure;
		EndIf;
		EmailTextFormattedDocument.SetHTML(CurrentObject.EmailTextInHTMLFormat, EmailAttachmentsStructureInHTMLFormat);
	EndIf;
	
	// Refill form data to be clear on rereading object from DB.
	If Rereading Then
		FillReportTableInfo();
		ReadJobSchedule();
		DoDisplayImportance();
		AddCommandsAddTextAdditionalParameters();
	EndIf;
	
	For Each String In Object.Reports Do
		String.DoNotSendIfEmpty = Not String.SendIfEmpty;
	EndDo;
	
	CreateAttributeItemEncryptionCertificate();
	VisibilityAvailabilityOfCertificatesPasswords(ThisObject);
	
	If GetFunctionalOption("RetainReportDistributionHistory") And Not Object.Personal And Object.UseEmail Then
		MailoutStatus = ReportMailing.GetReportDistributionState(Object.Ref);
		If MailoutStatus.WithErrors Then
			Items.RedistributionHeader.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The report distribution (%1) was not delivered to some recipients.';"),
				MailoutStatus.LastRunStart);
			Items.GroupRedistribution.Visible = True;
		Else
			Items.GroupRedistribution.Visible = False;
		EndIf;
	EndIf;
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	
	ErrorTextOnOpen = ReportMailing.CheckAddRightErrorText();
	If ValueIsFilled(ErrorTextOnOpen) Then
		Return;
	EndIf;
		
	// Standard subsystems.Pluggable commands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// 
	
	// 
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectsVersioning.OnCreateAtServer(ThisObject);
	EndIf;
	// 
	
	If Object.DeletionMark Then
		ReadOnly = True;
	EndIf;
	
	// Deleting the "To folder" option if the StoredFiles subsystem is not available.
	If TypeOf(Object.Folder) = Type("Undefined") Or TypeOf(Object.Folder) = Type("String") Then
		Items.OtherDeliveryMethod.ChoiceList.Delete(0);
	EndIf;
	
	// Delete the To network directory option if the operation mode in SaaS mode.
	If Common.DataSeparationEnabled() Then
		TransportMethodNetworkDirectory = Items.OtherDeliveryMethod.ChoiceList.FindByValue("UseNetworkDirectory");
		Items.OtherDeliveryMethod.ChoiceList.Delete(TransportMethodNetworkDirectory);
	EndIf;
	
	If Not AccessRight("EventLog", Metadata) Then
		Items.MailingEventsCommand.Visible = False;
		Items.MailingEvents.Visible = False;
	EndIf;
		
	MailingBasis = Parameters.CopyingValue;
	
	// Used on import and write selected report settings.
	CurrentRowIDOfReportsTable = -1;
	
	// Check cache.
	IsNew = Object.Ref.IsEmpty();
	CreatedByCopying = Not MailingBasis.IsEmpty();  
	
	If IsNew Then
		CreateAttributeItemEncryptionCertificate();
		DoDisplayImportance();
	EndIf;
	
	// Add reports to tabular section.
	If Parameters.Property("ReportsToAttach") And TypeOf(Parameters.ReportsToAttach) = Type("Array") Then
		Modified = True;
		AddReportsSettings(Parameters.ReportsToAttach);
	EndIf;
	
	Cache = GetCache();
	
	Schedule = New JobSchedule;
	
	MailingWasPersonalized = Object.Personalized;
	
	// Read
	FillReportTableInfo();
	FillEmptyTemplatesWithStandard(Object);
	
	If IsNew And Not CreatedByCopying Then
		DefineDistributionKind();
		ScheduleOption1_ = Undefined;
		Parameters.Property("ScheduleOption1_", ScheduleOption1_);
		FillScheduleByOption(ScheduleOption1_);
	Else
		ReadJobSchedule();
	EndIf;
	
	// Populate report distribution author.
	If IsNew Then
		// Report distribution author.
		CurrentUser = Users.CurrentUser();
		Object.Author = CurrentUser;
		Object.EmailImportance = "Ordinary";
		Object.ShouldAttachReports = True;
		If Not ValueIsFilled(Object.Author) Then
			Cancel = True;
			
			LogParameters = New Structure;
			LogParameters.Insert("EventName", NStr("en = 'Report distribution. Opening item form';", Common.DefaultLanguageCode()));
			LogParameters.Insert("Data", Undefined);
			LogParameters.Insert("Metadata", Metadata.Catalogs.ReportMailings);
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 cannot be a report distribution author.';"),
				Common.SubjectString(CurrentUser));

			ReportMailing.LogRecord(LogParameters, EventLogLevel.Error, Text);
			
			Return;
		EndIf;
		
		// Asterisks for passwords to be copied from a basis.
		If CreatedByCopying Then
			BasisAuthor = Common.ObjectAttributeValue(MailingBasis, "Author");
			If BasisAuthor = CurrentUser Then
				SetPrivilegedMode(True);
				Passwords = Common.ReadDataFromSecureStorage(MailingBasis,
					"ArchivePassword, FTPPassword");
				SetPrivilegedMode(False);
				If ValueIsFilled(Passwords.ArchivePassword) Then
					ArchivePasswordChanged = True; // See this parameter processing in the OnWriteAtServer.
				EndIf;
				If ValueIsFilled(Passwords.FTPPassword) Then
					FTPPassword = PasswordHidden();
					FTPPasswordChanged = True; // See this parameter processing in the OnWriteAtServer.
				EndIf;
				If Object.Personal And CanEncryptAttachments Then
					RecipientsCertificates = ReportMailing.GetEncryptionCertificatesForDistributionRecipients(Object.Author);
					If RecipientsCertificates.Count() > 0 Then
						ThisObject["CertificateToEncrypt"] = RecipientsCertificates[0].CertificateToEncrypt;
						EncryptionCertificateChanged = True; // See this parameter processing in the OnWriteAtServer.
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		// Reset parameters that cannot be copied to defaults.
		If Not ArchivePasswordChanged Then
			Object.ArchiveName = Cache.Templates.ArchiveName;
		EndIf;
		If Not FTPPasswordChanged Then
			Object.FTPLogin = "";
			Object.FTPServer = "";
			Object.FTPPort = 21;
			Object.FTPDirectory = "";
		EndIf;
	Else
		SetPrivilegedMode(True);
		Passwords = Common.ReadDataFromSecureStorage(Object.Ref, "ArchivePassword, FTPPassword");
		SetPrivilegedMode(False);
		ArchivePassword = ?(ValueIsFilled(Passwords.ArchivePassword), Passwords.ArchivePassword, "");
		FTPPassword = ?(ValueIsFilled(Passwords.FTPPassword), PasswordHidden(), "");
		If Object.Personal And CanEncryptAttachments Then
			RecipientsCertificates = ReportMailing.GetEncryptionCertificatesForDistributionRecipients(Object.Author);
			If RecipientsCertificates.Count() > 0 Then
				ThisObject["CertificateToEncrypt"] = RecipientsCertificates[0].CertificateToEncrypt;
			EndIf;
		EndIf;
	EndIf;
	Passwords = Undefined;
	
	// Allows you to see and control some protected mailing parameters.
	MailingBeingEditedByAuthor = (Object.Author = Users.CurrentUser());
	
	// 
	Items.ReportsAddAdditionalReport.Enabled = ?(Cache.EmptyReportValue = Undefined, True, False);
	//  
	//   
	
	// 
	Items.Author.Enabled = Users.IsFullUser();
	
	// List of formats with marks for default formats.
	DefaultFormatsList = ReportMailing.FormatsList();
	
	// Default formats list presentation.
	DefaultFormatsListPresentation = "";
	For Each ListItem In DefaultFormatsList Do
		If ListItem.Check Then
			DefaultFormatsListPresentation = DefaultFormatsListPresentation + ?(DefaultFormatsListPresentation = "", "", ", ") + String(ListItem.Presentation);
		EndIf;
	EndDo;
	
	// Editable format list.
	FormatsList = DefaultFormatsList.Copy();
	
	// Default formats list presentation within the mailing.
	DefaultFormats = "";
	FoundItems = Object.ReportFormats.FindRows(New Structure("Report", Cache.EmptyReportValue));
	If FoundItems.Count() = 0 Then
		DefaultFormats = DefaultFormatsListPresentation;
	Else
		For Each StringFormat In FoundItems Do
			DefaultFormats = DefaultFormats + ?(DefaultFormats = "", "", ", ") + ReportMailing.FormatPresentation(StringFormat.Format);
		EndDo;
	EndIf;
	
	// Attachments.
	If EmailAttachmentsStructureInHTMLFormat = Undefined Then
		EmailAttachmentsStructureInHTMLFormat = New Structure;
	EndIf;
	
	// 
	Items.EmptySettings.RowFilter = New FixedStructure("PictureIndex", 200);
	
	// Selection list of author postal addresses.
	RecipientMailAddresses(Object.Author, Items.AuthorMailAddressKind.ChoiceList);
	
	// Selection list of author postal addresses.
	ConnectEmailSettingsCache();
	
	// Read object settings from object to be copied.
	If CreatedByCopying Then
		ReadObjectSettingsOfObjectToCopy();
	EndIf;
	
	// Activate the first row.
	If Object.Reports.Count() > 0 And CurrentRowIDOfReportsTable = -1 Then
		ReportsRow = Object.Reports[0];
		RowID = ReportsRow.GetID();
		ErrorText = ReportsOnActivateRowAtServer(RowID);
		If ErrorText <> "" Then
			Common.MessageToUser(ErrorText, , "Object.Reports[0].Presentation");
		EndIf;
	EndIf;
	
	VisibilityAvailabilityCorrectness(ThisObject);
	AddCommandsAddTextAdditionalParameters();
	
	FixAttributesValuesBeforeChange();
	
	For Each String In Object.Reports Do
		String.DoNotSendIfEmpty = Not String.SendIfEmpty;
	EndDo;
	
	If AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Items.ArchivePassword.ChoiceButton = True;
	Else
		Items.ArchivePassword.ChoiceButton = False;
	EndIf;
	
	CheckPeriodsInReports();
	
	If Common.IsMobileClient() Then
		Items.CommandSaveAndClose.Representation = ButtonRepresentation.Picture;
		Items.OtherDeliveryMethods.Group = ChildFormItemsGroup.HorizontalIfPossible;
		Items.UseNetworkDirectory.Group = ChildFormItemsGroup.HorizontalIfPossible;
		Items.UseFolder.Group = ChildFormItemsGroup.HorizontalIfPossible;
		Items.ReplyToAddressBCC.Group = ChildFormItemsGroup.HorizontalIfPossible;
		Items.Move(Items.DeliverRight, Items.AdditionalPage);
		Items.Move(Items.GroupPasswordsEncryption, Items.AdditionalPage);
		Items.DefaultFormats.TitleLocation = FormItemTitleLocation.Top;
		Items.BulkEmailRecipients.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If FormWasModifiedAtServer Then
		Modified = True;
	EndIf;
	If ValueIsFilled(ErrorTextOnOpen) Then
		Cancel = True;
		ShowMessageBox(, ErrorTextOnOpen);
		Return;
	EndIf;
	
	// Standard subsystems.Pluggable commands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// 
	
	If ValueIsFilled(PopupAlertTextOnOpen) Then
		ShowUserNotification(PopupAlertTextOnOpen, , , PictureLib.ExecuteTask)
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	// Check data that is output through the attributes of the form itself.
	If Not ValueIsFilled(Object.Description) Then
		Cancel = True;
		MessageText = NStr("en = 'Description is not entered.';");
		Common.MessageToUser(MessageText, , "Object.Description");
	EndIf;
	If Object.UseEmail And Not Object.Personal Then
		If Not ValueIsFilled(MailingRecipientType) Then
			Cancel = True;
			MessageText = NStr("en = 'Recipient type is not selected.';");
			Common.MessageToUser(MessageText, , "MailingRecipientType");
		EndIf;
	EndIf;
	
	If Object.IsPrepared Then
		If Object.Reports.Count() = 0 Then
			Cancel = True;
			MessageText = NStr("en = 'No report is selected.';");
			Common.MessageToUser(MessageText, , "Object.Reports");
		EndIf;
		
		If Not ValueIsFilled(Object.SchedulePeriodicity) Then
			Cancel = True;
			MessageText = NStr("en = 'Distribution frequency is not specified.';");
			Common.MessageToUser(MessageText, , "Object.SchedulePeriodicity");
		EndIf;
		
		If Object.UseFTPResource Then
			If Not ValueIsFilled(Object.FTPServer)
				Or Not ValueIsFilled(Object.FTPPort)
				Or Not ValueIsFilled(Object.FTPDirectory) Then
				Cancel = True;
				MessageText = NStr("en = 'FTP address is not entered.';");
				Common.MessageToUser(MessageText, , "FTPServerAndDirectory");
			EndIf;
		EndIf;
		
		If Object.UseNetworkDirectory Then
			If Not ValueIsFilled(Object.NetworkDirectoryWindows) Then
				Cancel = True;
				MessageText = NStr("en = 'Windows network directory is not entered.';");
				Common.MessageToUser(MessageText, , "Object.NetworkDirectoryWindows");
			EndIf;
			If Not ValueIsFilled(Object.NetworkDirectoryLinux) Then
				Cancel = True;
				MessageText = NStr("en = 'Linux network directory is not entered.';");
				Common.MessageToUser(MessageText, , "Object.NetworkDirectoryLinux");
			EndIf;
		EndIf;
		
		If Object.UseFolder Then
			If Not ValueIsFilled(Object.Folder) Then
				Cancel = True;
				MessageText = NStr("en = 'Folder is not selected.';");
				Common.MessageToUser(MessageText, , "Object.Folder");
			EndIf;
		EndIf;
		
		If Object.UseEmail Then
			If Object.Personal Then
				If Not ValueIsFilled(Object.RecipientsEmailAddressKind) Then
					Cancel = True;
					MessageText = NStr("en = 'Email address is not selected.';");
					Common.MessageToUser(MessageText, , "Object.RecipientsEmailAddressKind");
				EndIf;
			Else
				If Not RecipientsSpecified(Object.Recipients) Then
					Cancel = True;
				EndIf;
				If Not ValueIsFilled(Object.RecipientsEmailAddressKind) Then
					Cancel = True;
					MessageText = NStr("en = 'Recipient email address type is not selected.';");
					Common.MessageToUser(MessageText, , "BulkEmailRecipients");
				EndIf;
			EndIf;
			If Not ValueIsFilled(Object.Account) Then
				Cancel = True;
				MessageText = NStr("en = 'Account for sending is not selected.';");
				Common.MessageToUser(MessageText, , "Object.Account");
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	If WriteParameters = Undefined Then
		WriteParameters = New Structure;
	EndIf;
	If Not WriteParameters.Property("Step") Then
		Cancel = True;
		WriteAtClient(Undefined, WriteParameters);
	EndIf;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	// Standard subsystems.Pluggable commands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	// 
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	// Write current row settings.
	If CurrentRowIDOfReportsTable <> -1 Then
		WriteReportsRowSettings(CurrentRowIDOfReportsTable);
	EndIf;
	
	// 
	// 
	//     
	//     
	// 
	//     
	CheckRequired1 = Object.IsPrepared;
	// 
	//     
	//     
	MailingIsNotPersonalized = (Not Object.Personalized And MailingWasPersonalized);
	For Each ReportsRow In Object.Reports Do
		
		ReportsRowObject = CurrentObject.Reports.Get(ReportsRow.LineNumber-1);
		
		If ReportsRow.ChangesMade Then
			// [1], [2] and [3] Read uninitialized settings.
			UserSettings = GetFromTempStorage(ReportsRow.SettingsAddress);
			
			// 
			ReportsRowObject.Settings = New ValueStorage(UserSettings, New Deflation(9));
			
			If Not CheckRequired1 And Not MailingIsNotPersonalized Then
				Continue;
			EndIf;
			
		Else
			
			If Not CheckRequired1 And Not MailingIsNotPersonalized Then
				Continue;
			EndIf;
			
			// [2] and [3] Read uninitialized settings.
			If IsTempStorageURL(ReportsRow.SettingsAddress) Then
				UserSettings = GetFromTempStorage(ReportsRow.SettingsAddress);
			Else
				UserSettings = ReportsRowObject.Settings.Get();
			EndIf;
			
		EndIf;
		
		// [2] and [3] Initialize settings.
		ReportParameters = InitializeReport(ReportsRow, True, UserSettings, False);
		ReportSettings = ?(ReportsRow.DCS, ReportParameters.DCSettingsComposer, UserSettings);
		ReportPersonalized = False;
		
		// [2] and [3] DCS reports analysis.
		If ReportsRow.DCS Then
			DCSettings = ReportSettings.Settings;
			DCUserSettings = ReportSettings.UserSettings; // DataCompositionUserSettings
			// 
			Filter = New Structure("Use, Value", True, MailingRecipientValueTemplate());
			FoundItems = ReportsClientServer.SettingsItemsFiltered(DCUserSettings, Filter);
			If FoundItems.Count() > 0 Then
				ReportPersonalized = True;
			EndIf;
			// [2] Search and check the available setting.
			AllRequiredSettingsFilled = True;
			For Each UserSetting In DCUserSettings.Items Do
				If TypeOf(UserSetting) = Type("DataCompositionSettingsParameterValue") Then
					Id = UserSetting.UserSettingID;
					CommonSetting = ReportsClientServer.GetObjectByUserID(DCSettings, Id);
					If CommonSetting = Undefined Then 
						Continue;
					EndIf;
					AvailableSetting = ReportsClientServer.FindAvailableSetting(DCSettings, CommonSetting);
					If AvailableSetting = Undefined Then
						Continue;
					EndIf;
					If Not AvailableSetting.Use = DataCompositionParameterUse.Always
						And Not UserSetting.Use Then
						Continue;
					EndIf;
					If AvailableSetting.DenyIncompleteValues And Not ValueIsFilled(UserSetting.Value) Then
						AllRequiredSettingsFilled = False;
					EndIf;
				EndIf;
			EndDo;
			
			// [2] Error output.
			If Not AllRequiredSettingsFilled Then
				Cancel = True;
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Not all required settings are filled in for the ''%1'' report. Fill in all the required settings or clear the ''Prepared'' check box.';"),
					String(ReportsRow.Report));
				Field = "Reports["+ Format(CurrentObject.Reports.IndexOf(ReportsRowObject), "NZ=0; NG=0") +"].Presentation";
				Common.MessageToUser(MessageText, CurrentObject, Field);
			EndIf;
		EndIf;
		
		// [3] Ordinary report analysis.
		If TypeOf(ReportSettings) = Type("ValueTable") Then
			FoundItems = ReportSettings.FindRows(New Structure("Value, Use", MailingRecipientValueTemplate(), True));
			If FoundItems.Count() > 0 Then
				ReportPersonalized = True;
			EndIf;
		EndIf;
		If MailingIsNotPersonalized And ReportPersonalized Then
			Cancel = True;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Filter by recipients is applied to the ""%1"" report. Remove the filter or change the distribution mode to ""individual report for each recipient"".';"),
				String(ReportsRow.Report));
			Field = "Reports["+ Format(CurrentObject.Reports.IndexOf(ReportsRowObject), "NZ=0; NG=0") +"].Presentation";
			Common.MessageToUser(MessageText, CurrentObject, Field);
		EndIf;
		
		If Object.Personalized And	Not ReportPersonalized Then
			Cancel = True;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Filter by recipient is not specified in the ""%1"" report settings.';"),
				String(ReportsRow.Report));
			Field = "Reports["+ Format(CurrentObject.Reports.IndexOf(ReportsRowObject), "NZ=0; NG=0") +"].Presentation";
			Common.MessageToUser(MessageText, CurrentObject, Field);
		EndIf;
		
	EndDo;
	
	CurrentObject.EmailPicturesInHTMLFormat = Undefined;
	If CurrentObject.HTMLFormatEmail Then
		CurrentObject.EmailText = TrimAll(EmailTextFormattedDocument.GetText());
		If CurrentObject.EmailText = "" Then
			CurrentObject.EmailTextInHTMLFormat = "";
		Else
			EmailTextFormattedDocument.GetHTML(CurrentObject.EmailTextInHTMLFormat, EmailAttachmentsStructureInHTMLFormat);
			If TypeOf(EmailAttachmentsStructureInHTMLFormat) = Type("Structure")
				And EmailAttachmentsStructureInHTMLFormat.Count() > 0 Then
				CurrentObject.EmailPicturesInHTMLFormat = New ValueStorage(EmailAttachmentsStructureInHTMLFormat, New Deflation(9));
			EndIf;
			CurrentObject.EmailText = EmailTextFormattedDocument.GetText();
		EndIf;
	EndIf;
	
	// Write the values.
	If ValueIsFilled(MailingRecipientType) Then
		FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
		If FoundItems.Count() = 1 Then
			CurrentObject.MailingRecipientType = FoundItems[0].MetadataObjectID;
		Else
			CurrentObject.MailingRecipientType = Catalogs.MetadataObjectIDs.EmptyRef();
		EndIf;
	Else
		CurrentObject.MailingRecipientType = Catalogs.MetadataObjectIDs.EmptyRef();
	EndIf;
	
	// All operations with scheduled jobs are placed in the object module.
	If Object.SchedulePeriodicity <> Enums.ReportMailingSchedulePeriodicities.CustomValue Then
		Schedule.EndTime = '00010101';
	EndIf;
	CurrentObject.AdditionalProperties.Insert("Schedule", Schedule);
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	ArchivePasswordChangedButHidden = ArchivePasswordChanged And ArchivePassword = PasswordHidden();
	FTPPasswordChangedButHidden = FTPPasswordChanged And FTPPassword = PasswordHidden();
	
	If (ArchivePasswordChangedButHidden Or FTPPasswordChangedButHidden) And ValueIsFilled(MailingBasis) Then
		CurrentUser = Users.CurrentUser();
		BasisAuthor = Common.ObjectAttributeValue(MailingBasis, "Author");
		If BasisAuthor = CurrentUser Then
			SetPrivilegedMode(True);
			If ArchivePasswordChangedButHidden Then
				TemporaryVariable = Common.ReadDataFromSecureStorage(MailingBasis, "ArchivePassword");
				Common.WriteDataToSecureStorage(CurrentObject.Ref, TemporaryVariable, "ArchivePassword");
				ArchivePasswordChanged = False;
			EndIf;
			If FTPPasswordChangedButHidden Then
				TemporaryVariable = Common.ReadDataFromSecureStorage(MailingBasis, "FTPPassword");
				Common.WriteDataToSecureStorage(CurrentObject.Ref, TemporaryVariable, "FTPPassword");
				FTPPasswordChanged = False;
			EndIf;
			SetPrivilegedMode(False);
		EndIf;
		MailingBasis = Undefined;
	EndIf;
	
	If ArchivePasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, ArchivePassword, "ArchivePassword");
		SetPrivilegedMode(False);
	EndIf;
	
	If FTPPasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, FTPPassword, "FTPPassword");
		SetPrivilegedMode(False);
	EndIf;
	
	If CanEncryptAttachments And EncryptionCertificateChanged Then
		InformationRegisters.CertificatesOfReportDistributionRecipients.SaveCertificateForDistributionRecipient(
			Object.Author, ThisObject["CertificateToEncrypt"]);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

	// Refill form tables associated with objects tables (since object tables have already been filled).
	FillReportTableInfo();
	ReportsOnActivateRowAtServer(CurrentRowIDOfReportsTable);
	
	// Update the attributes initial values in the cache.
	FixAttributesValuesBeforeChange();
	For Each String In Object.Reports Do
		String.DoNotSendIfEmpty = Not String.SendIfEmpty;
	EndDo;
	
	CheckPeriodsInReports();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IsPreparedOnChange(Item)
	VisibilityAvailabilityCorrectness(ThisObject, "IsPrepared");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ExecuteOnScheduleOnChange(Item)
	VisibilityAvailabilityCorrectness(ThisObject, "ExecuteOnSchedule");
EndProcedure

&AtClient
Procedure MonthsOnChange(Item)
	If Item <> Undefined Then
		Schedule.Months = ChangeArrayContent(ThisObject[Item.Name], Cache.Maps1.Months[Item.Name], Schedule.Months);
	EndIf;
	VisibilityAvailabilityCorrectness(ThisObject, "Months");
EndProcedure

&AtClient
Procedure WeekDaysOnChange(Item)
	If Item <> Undefined Then
		Schedule.WeekDays = ChangeArrayContent(ThisObject[Item.Name], Cache.Maps1.WeekDays[Item.Name], Schedule.WeekDays);
	EndIf;
	VisibilityAvailabilityCorrectness(ThisObject, "WeekDays");
EndProcedure

&AtClient
Procedure ModifySchedule(Command)

	If CommonClient.DataSeparationEnabled() Then
		ClearMessages();
		CommonClient.MessageToUser(NStr("en = 'A custom schedule cannot be set over the Internet.';"));
		Return;
	EndIf;
		
	ChangeScheduleInDialog();
EndProcedure

&AtClient
Procedure SchedulePeriodicityOnChange(Item)
	
	VisibilityAvailabilityCorrectness(ThisObject, "SchedulePeriodicity");
	If Object.SchedulePeriodicity = PredefinedValue("Enum.ReportMailingSchedulePeriodicities.CustomValue") 
	   And Not CommonClient.DataSeparationEnabled() Then
		ChangeScheduleInDialog();
	EndIf;
EndProcedure

&AtClient
Procedure BegEndOfMonthHyperlinkClick(Item)
	If Schedule.DayInMonth = 0 Then
		DayInMonth = 1;
		Schedule.DayInMonth = -1;
	Else
		Schedule.DayInMonth = -Schedule.DayInMonth;
	EndIf;
	Modified = True;
	VisibilityAvailabilityCorrectness(ThisObject, "MonthBeginEnd");
EndProcedure

&AtClient
Procedure BeginTimeOnChange(Item)
	Schedule.BeginTime = BeginTime;
	VisibilityAvailabilityCorrectness(ThisObject, "BeginTime");
EndProcedure

&AtClient
Procedure DaysRepeatPeriodOnChange(Item)
	Schedule.DaysRepeatPeriod = DaysRepeatPeriod;
	VisibilityAvailabilityCorrectness(ThisObject, "DaysRepeatPeriod");
EndProcedure

&AtClient
Procedure MonthDayOnChange(Item)
	Schedule.DayInMonth = ?(Schedule.DayInMonth >= 0, DayInMonth, -DayInMonth);
	VisibilityAvailabilityCorrectness(ThisObject, "DayInMonth");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure MailingRecipientTypeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ValueSelected = MailingRecipientType Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", ValueSelected));
	If FoundItems.Count() <> 1 Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	// Clear recipients (if necessary).
	If Object.Recipients.Count() > 0 Then
		StandardProcessing = False;
		
		QuestionRow = NStr("en = 'To continue, clear the recipient list.';");
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Clear';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ValueSelected", ValueSelected);
		Handler = New NotifyDescription("MailingRecipientTypeChoiceProcessingCompletion", ThisObject, AdditionalParameters);
		
		ShowQueryBox(Handler, QuestionRow, Buttons, 60, DialogReturnCode.Yes);
	EndIf;
EndProcedure

&AtClient
Procedure MailingRecipientTypeOnChange(Item)
	FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
	If FoundItems.Count() = 1 Then
		RecipientRow = FoundItems[0];
		Object.MailingRecipientType = RecipientRow.MetadataObjectID;
		Object.RecipientsEmailAddressKind = RecipientRow.MainCIKind;
		AddCommandsAddTextAdditionalParameters();
	EndIf;
EndProcedure

&AtClient
Procedure MailingRecipientTypeClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure AuthorMailAddressKindOpening(Item, StandardProcessing)
	StandardProcessing = False;
	ShowValue(, Object.Author);
EndProcedure

&AtClient
Procedure FTPServerAndDirectoryOnChange(Item)
	ValueSelected = ReportMailingClient.ParseFTPAddress(FTPServerAndDirectory);
	FTPServerAndDirectoryChoiceProcessing(Item, ValueSelected, True);
EndProcedure

&AtClient
Procedure FTPServerAndDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	CustomFormParameters = New Structure("Server, Directory, Port, Login, PassiveConnection");
	For Each KeyAndValue In CustomFormParameters Do
		CustomFormParameters[KeyAndValue.Key] = Object["FTP" + KeyAndValue.Key];
	EndDo;
	CustomFormParameters.Insert("Password", FTPPassword);
	CustomFormParameters.Insert("Title", NStr("en = '<Specify recipient>';"));
	
	OpenForm("Catalog.ReportMailings.Form.FTPParameters", CustomFormParameters, Item);
EndProcedure

&AtClient
Procedure FTPServerAndDirectoryChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	If ValueSelected = Undefined Or TypeOf(ValueSelected) <> Type("Structure") Then
		Return;
	EndIf;
	For Each KeyAndValue In ValueSelected Do
		If KeyAndValue.Key = "Password" Then
			If KeyAndValue.Value <> FTPPassword And KeyAndValue.Value <> PasswordHidden() Then
				FTPPassword = KeyAndValue.Value;
				FTPPasswordChanged = True;
			EndIf;
		Else
			Object["FTP" + KeyAndValue.Key] = KeyAndValue.Value;
		EndIf;
	EndDo;
	
	VisibilityAvailabilityCorrectness(ThisObject, "FTPServerAndDirectory");
	Modified = True;
EndProcedure

&AtClient
Procedure FTPServerAndDirectoryClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FTPServerAndDirectoryOpening(Item, StandardProcessing)

	StandardProcessing = False;
	
	FullAddress = "ftp://"+ Object.FTPServer +":"+ Format(Object.FTPPort, "NZ=21; NG=0") + Object.FTPDirectory;
	FileSystemClient.OpenURL(FullAddress);

EndProcedure

&AtClient
Procedure BulkEmailTypeOnChange(Item)
	Object.Personal            = (BulkEmailType = "Personal");
	Object.Personalized = (BulkEmailType = "Personalized");
	
	If Not Object.ShouldInsertReportsIntoEmailBody And Not Object.NotifyOnly Then
		Object.ShouldAttachReports = True;
	EndIf;
	
	VisibilityAvailabilityCorrectness(ThisObject, "BulkEmailType");
	AddCommandsAddTextAdditionalParameters();
	
EndProcedure

&AtClient
Procedure UseEmailOnChange(Item)
	VisibilityAvailabilityCorrectness(ThisObject, "UseEmail");
	
	If Not Publish And Not Object.UseEmail Then
		Publish = True;
		EvaluateAdditionalDeliveryMethodsCheckBoxes();
		VisibilityAvailabilityCorrectness(ThisObject, "Publish");
	ElsIf Object.UseEmail And Not Object.ShouldInsertReportsIntoEmailBody And Not Object.NotifyOnly Then
		Object.ShouldAttachReports = True;
	EndIf;
EndProcedure

&AtClient
Procedure NotifyOnlyOnChange(Item)
	
	If Object.NotifyOnly Then
		Object.ShouldInsertReportsIntoEmailBody = False;
		Object.ShouldAttachReports = False;
	Else
		Object.ShouldInsertReportsIntoEmailBody = False;
		Object.ShouldAttachReports = True;
	EndIf;
	
	VisibilityAvailabilityCorrectness(ThisObject, "NotifyOnly");
EndProcedure

&AtClient
Procedure OtherDeliveryMethodOnChange(Item)
	EvaluateAdditionalDeliveryMethodsCheckBoxes();
	VisibilityAvailabilityCorrectness(ThisObject, "OtherDeliveryMethod");
EndProcedure

&AtClient
Procedure OtherDeliveryMethodTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	If IsBlankString(Text) Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure PublishOnChange(Item)
	EvaluateAdditionalDeliveryMethodsCheckBoxes();
	VisibilityAvailabilityCorrectness(ThisObject, "Publish");
	
	If Not Publish And Not Object.UseEmail Then
		Object.UseEmail = True;
		Object.ShouldAttachReports  = True;
		VisibilityAvailabilityCorrectness(ThisObject, "UseEmail");
	ElsIf Object.UseEmail And Not Object.ShouldInsertReportsIntoEmailBody And Not Object.NotifyOnly Then
		Object.ShouldAttachReports = True;
	EndIf;
EndProcedure

&AtClient
Procedure FolderOpening(Item, StandardProcessing)
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
		ModuleFilesOperationsInternalClient.ReportsMailingViewFolder(StandardProcessing, Object.Folder);
	EndIf;
EndProcedure

&AtClient
Procedure FolderChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If Not ChangeFolderAndFilesRight(ValueSelected) Then
		StandardProcessing = False;
		WarningText = NStr("en = 'Insufficient rights to change files of folder ""%1"".';");
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText, String(ValueSelected));
		ShowMessageBox(, WarningText);
	EndIf;
EndProcedure

&AtClient
Procedure NetworkDirectoryWindowsOnChange(Item)
	Object.NetworkDirectoryWindows = CommonClientServer.AddLastPathSeparator(Object.NetworkDirectoryWindows);
	If IsBlankString(Object.NetworkDirectoryLinux) Then
		Object.NetworkDirectoryLinux = StrReplace(Object.NetworkDirectoryWindows, "\", "/");
	EndIf; 
EndProcedure

&AtClient
Procedure NetworkDirectoryLinuxOnChange(Item)
	Object.NetworkDirectoryLinux = CommonClientServer.AddLastPathSeparator(Object.NetworkDirectoryLinux);
	If IsBlankString(Object.NetworkDirectoryWindows) Then
		Object.NetworkDirectoryWindows = StrReplace(Object.NetworkDirectoryLinux, "/", "\");
	EndIf; 
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure DefaultFormatsClick(Item, StandardProcessing)
	StandardProcessing = False;
	Handler = New NotifyDescription("DefaultFormatsSelectionCompletion", ThisObject);
	ChooseFormat(Cache.EmptyReportValue, Handler);
EndProcedure

&AtClient
Procedure ArchiveOnChange(Item)
	VisibilityAvailabilityCorrectness(ThisObject, "Archive");
	CheckOnSetArchivePasswordInsertReportsToEmailText();
EndProcedure

&AtClient
Procedure AuthorOnChange(Item)
	CurrentList = Items.AuthorMailAddressKind.ChoiceList;
	CurrentList.Clear();
	NewList = New ValueList;
	RecipientMailAddresses(Object.Author, NewList);
	For Each ListItem In NewList Do
		FillPropertyValues(CurrentList.Add(), ListItem);
	EndDo;
	If NewList.FindByValue(Object.RecipientsEmailAddressKind) = Undefined Then
		Object.RecipientsEmailAddressKind = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure ArchiveNameChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = "DescriptionDistributionDate" Then
		AddLayout();
		StandardProcessing = False;
		CurrentItem.SelectedText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[MailingDescription]", "[ExecutionDate()]");

		Variables1 = New Structure;
		Variables1.Insert("Item", CurrentItem);
		Variables1.Insert("PreviousText1", "");
		Variables1.Insert("Prefix", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[MailingDescription]", "[ExecutionDate("));
		Variables1.Insert("Postfix", ")]");
		Variables1.Insert("FormatText", "");
		Variables1.Insert("PreviousFragmentFound", False);

		Handler = New NotifyDescription("AddChangeMailingDateTemplateCompletion", ThisObject, Variables1);

		Dialog = New FormatStringWizard;
		Dialog.AvailableTypes = New TypeDescription("Date");
		Dialog.Text         = Variables1.FormatText;
		Dialog.Show(Handler);		
	EndIf;
	
EndProcedure

&AtClient
Procedure ArchivePasswordOnChange(Item)
	ArchivePasswordChanged = True;
	
	CheckOnSetArchivePasswordInsertReportsToEmailText();
	
EndProcedure

&AtClient
Procedure ArchivePasswordStartChoice(Item, ChoiceData, StandardProcessing)
	
	EmailOperationsClient.PasswordFieldStartChoice(Item, ArchivePassword, StandardProcessing);

EndProcedure

&AtClient
Procedure Attachable_EncryptionCertificateOnChange(Item)
	EncryptionCertificateChanged = True;

	If ValueIsFilled(ThisObject["CertificateToEncrypt"]) And Object.ShouldInsertReportsIntoEmailBody 
		And Object.ShouldAttachReports Then

		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		
		QuestionButtons = New ValueList;
		QuestionButtons.Add("InstallEncryptionCertificate", NStr("en = 'Install encryption certificate';"));
		QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		QueryText = NStr(
			"en = 'To install the encryption certificate, remove the reports from the email text.';");
		QuestionParameters.DefaultButton = "InstallEncryptionCertificate";

		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("AfterAnswerQuestionPasswordEncryptionReportsInEmailText", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);
	EndIf;

EndProcedure

&AtClient
Procedure ShouldSetPasswordsAndEncryptOnChange(Item)

	VisibilityAvailabilityOfCertificatesPasswords(ThisObject);
	
	If Not Object.ShouldInsertReportsIntoEmailBody And Object.ShouldSetPasswordsAndEncrypt Then
		OpenFormPasswordsEncryption();
	ElsIf Object.ShouldInsertReportsIntoEmailBody And Object.ShouldSetPasswordsAndEncrypt Then
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionParameters.PromptDontAskAgain = False;

		If CanEncryptAttachments Then
			If Object.Archive Then
				QuestionButtons = New ValueList;
				QuestionButtons.Add("ShouldSetPasswordsAndEncrypt", NStr("en = 'Set passwords and encrypt data';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To set the passwords and encrypt data, remove the reports from the email text.';");
				QuestionParameters.DefaultButton = "ShouldSetPasswordsAndEncrypt";
			Else
				QuestionButtons = New ValueList;
				QuestionButtons.Add("ShouldSetPasswordsAndEncrypt", NStr("en = 'Encrypt data';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To encrypt the reports, remove them from the email text.';");
				QuestionParameters.DefaultButton = "Encrypt";
			EndIf;
		ElsIf Object.Archive Then
			QuestionButtons = New ValueList;
			QuestionButtons.Add("ShouldSetPasswordsAndEncrypt", NStr("en = 'Set passwords';"));
			QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
			QueryText = NStr("en = 'To set the passwords, remove the reports from the email text.';");
			QuestionParameters.DefaultButton = "SetPasswords";
		EndIf;
		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("SetPasswordsReportsInEmailBodyAfterQuestionAnswered", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);
	EndIf;

EndProcedure

#EndRegion

#Region ReportsFormTableItemEventHandlers

&AtClient
Procedure ReportsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	FillingStructure = New Structure;
	FillingStructure.Insert("Formats", "");
	FillingStructure.Insert("SendIfEmpty", False);
	FillingStructure.Insert("DoNotSendIfEmpty", True);
	FillingStructure.Insert("Enabled", True);  
	FillingStructure.Insert("DescriptionTemplate1", "[ReportDescription1] [ReportFormat]");
	
	NewRowArray = ChoicePickupDragToTabularSection(
		ValueSelected,
		Object.Reports,
		"Report",
		FillingStructure,
		True);
	
	Template = New FixedStructure("Count, RowsArray, ReportsPresentations, Text", 0, Undefined, "");
	ChoiceStructure = New Structure;
	ChoiceStructure.Insert("SelectedItemsCount",   New Structure(Template));
	ChoiceStructure.Insert("Success",   New Structure(Template));
	ChoiceStructure.Insert("WithErrors", New Structure(Template));
	ChoiceStructure.SelectedItemsCount.RowsArray   = NewRowArray;
	ChoiceStructure.Success.RowsArray   = New Array;
	ChoiceStructure.WithErrors.RowsArray = New Array;
	
	// Initialize the added report rows and fill the selection structure.
	CheckAddedReportRows(ChoiceStructure);
	
	If ChoiceStructure.WithErrors.Count > 0 Then
		
		If ChoiceStructure.SelectedItemsCount.Count = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot include the report in the distribution. Reason:
					|%1';"), ChoiceStructure.WithErrors.Text);
		ElsIf ChoiceStructure.Success.Count = 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot include the reports in the distribution. Reason:
					|%1';"), ChoiceStructure.WithErrors.Text);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Reports included in distribution: %1 out of %2.
					|Details:
					|%3';"),
				Format(ChoiceStructure.Success.Count, "NZ=0; NG="),
				Format(ChoiceStructure.SelectedItemsCount.Count, "NZ=0; NG="), 
				ChoiceStructure.WithErrors.Text);
		EndIf;
		ShowMessageBox(Undefined, MessageText);
		
	Else
		
		If ChoiceStructure.Success.Count = 0 Then
			NotificationTitle = Undefined;
			NotificationText1 = NStr("en = 'All the selected reports are already included in the distribution.';");
		Else
			If ChoiceStructure.SelectedItemsCount.Count = 1 Then
				NotificationTitle = NStr("en = 'The report is included in the distribution.';");
			Else
				NotificationTitle = NStr("en = 'The reports are included in the distribution.';");
			EndIf;
			NotificationText1 = ChoiceStructure.Success.ReportsPresentations;
		EndIf;
		
		ShowUserNotification(
			NotificationTitle,
			,
			NotificationText1,
			PictureLib.Success32);
		
	EndIf;
	CheckPeriodsInReports(ChoiceStructure.Success.RowsArray);
	VisibilityAvailabilityCorrectness(ThisObject, "Reports");
EndProcedure

&AtClient
Procedure ReportsOnActivateRow(Item)
	AttachIdleHandler("ReportsTableRowActivationHandler", 0.1, True);
EndProcedure

&AtClient
Procedure ReportsTableRowActivationHandler()
	ReportsRow = Items.Reports.CurrentData;
	If ReportsRow = Undefined Then
		Items.ReportSettingsPages.CurrentPage = Items.PageEmpty;
		Return;
	EndIf;
	
	RowID = ReportsRow.GetID();
	If RowID = CurrentRowIDOfReportsTable Then
		Return;
	EndIf;
	
	WarningText = ReportsOnActivateRowAtServer(RowID);
	If WarningText <> "" Then
		ShowMessageBox(, WarningText);
	EndIf;
EndProcedure

&AtClient
Procedure ReportsBeforeRowChange(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportsAfterDeleteRow(Item)
	VisibilityAvailabilityCorrectness(ThisObject, "Reports");
EndProcedure

#EndRegion

#Region UserSettingsFormTableItemEventHandlers

&AtClient
Procedure UserSettingsOnChange(Item)
	ReportsRow = Items.Reports.CurrentData;
	If ReportsRow = Undefined Then
		Return;
	EndIf;
	
	ReportsRow.ChangesMade = True;
EndProcedure

&AtClient
Procedure UserSettingsOnActivateRow(Item)
	If Items.ReportSettingsPages.CurrentPage <> Items.ComposerPage Then
		Return;
	EndIf;
	Report = Items.Reports.CurrentData;
	If Report = Undefined Or TypeOf(Report.Report) <> Type("CatalogRef.ReportsOptions") Then
		Return;
	EndIf;
	DCID = Items.UserSettings.CurrentRow;
	ValueViewOnly = False;
	ReportMailingClientOverridable.OnActivateRowSettings(Report, DCSettingsComposer, DCID, ValueViewOnly);
	If Items.UserSettingsValue.ReadOnly <> ValueViewOnly Then
		Items.UserSettingsValue.ReadOnly = ValueViewOnly;
	EndIf;
EndProcedure

&AtClient
Procedure UserSettingsValueStartChoice(Item, ChoiceData, StandardProcessing)
	UserSettingStartChoice(StandardProcessing);
EndProcedure

&AtClient
Procedure UserSettingsValueClearing(Item, StandardProcessing)
	If Items.ReportSettingsPages.CurrentPage <> Items.ComposerPage Then
		Return;
	EndIf;
	Report = Items.Reports.CurrentData;
	If Report = Undefined Or TypeOf(Report.Report) <> Type("CatalogRef.ReportsOptions") Then
		Return;
	EndIf;
	DCID = Items.UserSettings.CurrentRow;
	ReportMailingClientOverridable.OnSettingsClear(Report, DCSettingsComposer, DCID, StandardProcessing);
EndProcedure

&AtClient
Procedure UserSettingsSelection(Item, RowSelected, Field, StandardProcessing)
	UserSettingStartChoice(StandardProcessing);
EndProcedure

#EndRegion

#Region CurrentReportSettingsFormTableItemEventHandlers

&AtClient
Procedure CurrentReportSettingsValueOnChange(Item)
	SettingsString = Items.CurrentReportSettings.CurrentData;
	If SettingsString = Undefined Then
		Return;
	EndIf;
	
	SettingsString.Use = True;
EndProcedure

&AtClient
Procedure CurrentReportSettingsOnChange(Item)
	ReportsRow = Items.Reports.CurrentData;
	If ReportsRow = Undefined Then
		Return;
	EndIf;
	
	ReportsRow.ChangesMade = True;
EndProcedure

#EndRegion

#Region ReportFormatsFormTableItemEventHandlers

&AtClient
Procedure ReportFormatsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportFormatsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportFormatsFormatsStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ReportsRow = Items.ReportFormats.CurrentData;
	If ReportsRow = Undefined Then
		Return;
	EndIf;
	
	Variables1 = New Structure;
	Variables1.Insert("ReportsRow", ReportsRow);
	
	Handler = New NotifyDescription("ReportFormatsEndChoiceFormat", ThisObject, Variables1);
	
	ChooseFormat(ReportsRow.Report, Handler);
EndProcedure

&AtClient
Procedure ReportFormatsFormatsClearing(Item, StandardProcessing)
	StandardProcessing = False;
	ReportsRow = Items.ReportFormats.CurrentData;
	If ReportsRow = Undefined Then
		Return;
	EndIf;
	
	ClearFormat(ReportsRow.Report);
	ReportsRow.Formats = "";
EndProcedure

&AtClient
Procedure ReportFormatsSendIfEmptyOnChange(Item)
	CurrentData = Items.ReportFormats.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData.DoNotSendIfEmpty = Not CurrentData.SendIfEmpty;
EndProcedure

&AtClient
Procedure ReportFormatsDoNotSendIfEmptyOnChange(Item)
	CurrentData = Items.ReportFormats.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData.SendIfEmpty = Not CurrentData.DoNotSendIfEmpty;
EndProcedure

&AtClient
Procedure ReportFormatsOnActivateRow(Item)
	
	ReportsFormatsRow = Item.CurrentData;
	If ReportsFormatsRow = Undefined Then
		Return;
	EndIf;
	
	Items.ReportsFormatsDescriptionTemplate.ChoiceList.Clear();
	Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("ReportDescription1", NStr("en = 'Report name';"));
	Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("ReportDescriptionFormat", NStr("en = 'Report name, format';"));
	If ReportsFormatsRow.ThereIsPeriod Then
		Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("DescriptionPeriod", NStr("en = 'Report name, period';"));
		Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("DescriptionPeriodFormat", NStr("en = 'Report name, period, format';"));
	EndIf;
	Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("DescriptionDistributionDate", NStr("en = 'Report name, report distribution date';"));
	Items.ReportsFormatsDescriptionTemplate.ChoiceList.Add("DescriptionDistributionDateFormat", NStr("en = 'Report name, report distribution date, format';"));

EndProcedure

&AtClient
Procedure ReportsFormatsDescriptionTemplateChoiceProcessing(Item, ValueSelected, StandardProcessing)

	StandardProcessing = False;
	SetDescriptionTemplates(ValueSelected);

EndProcedure

#EndRegion

#Region FormCommandHandlers

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure CommandSaveAndClose(Command)
	WriteParameters = New Structure;
	WriteParameters.Insert("CommandName", "CommandSaveAndClose");
	WriteAtClient(Undefined, WriteParameters);
EndProcedure

&AtClient
Procedure BulkEmailRecipientsClick(Item, StandardProcessing)
	StandardProcessing = False;
	
	If Not ValueIsFilled(Object.MailingRecipientType) Then
		ErrorText = NStr("en = 'To enter recipients, select their type.';");
		CommonClient.MessageToUser(ErrorText, , "MailingRecipientType");
		Return;
	EndIf;
	
	Handler = New NotifyDescription("BulkEmailRecipientsClickCompletion", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("Recipients", Object.Recipients);
	FormParameters.Insert("MailingRecipientType", MailingRecipientType);
	FormParameters.Insert("RecipientsEmailAddressKind", Object.RecipientsEmailAddressKind);
	FormParameters.Insert("MailingDescription", Object.Description);
	
	OpenForm("Catalog.ReportMailings.Form.BulkEmailRecipients", FormParameters, , , , , Handler);
EndProcedure

&AtClient
Procedure CommandWrite(Command)
	WriteParameters = New Structure;
	WriteParameters.Insert("CommandName", "CommandWrite");
	WriteAtClient(Undefined, WriteParameters);
EndProcedure

&AtClient
Procedure ExecuteNowCommand(Command)
	If Not Object.IsPrepared Then
		ShowMessageBox(, NStr("en = 'The report distribution is not prepared.';"));
		Return;
	EndIf;
	WriteParameters = New Structure;
	WriteParameters.Insert("CommandName", "ExecuteNowCommand");
	WriteAtClient(Undefined, WriteParameters);
EndProcedure

&AtClient
Procedure MailingEventsCommand(Command)
	WriteParameters = New Structure;
	WriteParameters.Insert("CommandName", "MailingEventsCommand");
	WriteAtClient(Undefined, WriteParameters);
EndProcedure

&AtClient
Procedure Redistribution(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("Ref", Object.Ref);
	NotifyDescription = New NotifyDescription("AfterCloseRedistribution", ThisObject);
	OpenForm("Catalog.ReportMailings.Form.ResendReports", FormParameters, ThisObject, , , , NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure AddReport(Command)
	SelectedValues = New ValueList;
	For Each ReportsRow In Object.Reports Do
		If TypeOf(ReportsRow.Report) = Type("CatalogRef.ReportsOptions") Then
			SelectedValues.Add(ReportsRow.Report);
		EndIf;
	EndDo;
	
	ChoiceFilter = New Structure;
	ChoiceFilter.Insert("ReportType", 1);
	ChoiceFilter.Insert("Report", New Structure("Kind, Value", "NotInList", Cache.ReportsToExclude));
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("WindowOpeningMode",  FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("ChoiceMode",        True);
	ChoiceFormParameters.Insert("MultipleChoice", True);
	ChoiceFormParameters.Insert("CloseOnChoice", False);
	ChoiceFormParameters.Insert("Filter",              ChoiceFilter);
	ChoiceFormParameters.Insert("SelectedValues",  SelectedValues);
	
	OpenForm("Catalog.ReportsOptions.ChoiceForm", ChoiceFormParameters, Items.Reports);
EndProcedure

&AtClient
Procedure AddAdditionalReport(Command)
	// Additional reports pickup form.
	If CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessorsClient = CommonClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
		ModuleAdditionalReportsAndDataProcessorsClient.ReportDistributionPickAddlReport(Items.Reports);
	EndIf;
EndProcedure

&AtClient
Procedure ReportPreview(Command)
	
	ClearMessages();
	
	ReportsRow = Items.Reports.CurrentData;
	If ReportsRow = Undefined Then
		ShowMessageBox(, NStr("en = 'Select report';"));
		Return;
	EndIf;
	If Not ReportsRow.Enabled Then
		ShowMessageBox(, ReportsRow.Presentation);
		Return;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Report",                ReportsRow.Report);
	ReportParameters.Insert("Settings",            Undefined);
	ReportParameters.Insert("SendIfEmpty", ReportsRow.SendIfEmpty);
	ReportParameters.Insert("Formats",              New Array);
	ReportParameters.Insert("Presentation",        ReportsRow.Presentation);
	ReportParameters.Insert("FullName",            ReportsRow.FullName);
	ReportParameters.Insert("VariantKey",         ReportsRow.VariantKey);
	
	If ReportsRow.DCS Then
		ReportParameters.Settings = DCSettingsComposer.UserSettings;
	Else
		Settings = New Array;
		FoundItems = CurrentReportSettings.FindRows(New Structure("Use", True));
		For Each SettingRow In FoundItems Do
			SettingToAdd = New Structure("Attribute, Value", SettingRow.Attribute, SettingRow.Value);
			Settings.Add(SettingToAdd);
		EndDo;
		ReportParameters.Settings = Settings;
	EndIf;
	
	If Object.Personalized Then
		If Not RecipientsSpecified(Object.Recipients) Then
			Return;
		EndIf;
		Handler = New NotifyDescription("ReportsPreviewContinue", ThisObject, ReportParameters);
		ReportMailingClient.SelectRecipient(Handler, Object, False, False);
	Else
		ReportsPreviewContinue(Undefined, ReportParameters);
	EndIf;
EndProcedure

&AtClient
Procedure ReportsPreviewContinue(SelectionResult, ReportParameters) Export
	DCUserSettings = ReportParameters.Settings;
	Filter = New Structure("Use, Value", True, MailingRecipientValueTemplate());
	PersonalizedSettings = ReportsClientServer.SettingsItemsFiltered(DCUserSettings, Filter);
	If Object.Personalized Then
		If SelectionResult = Undefined Then
			Return;
		Else
			Recipient = SelectionResult.Recipient;
		EndIf;
		For Each DCUserSetting In PersonalizedSettings Do
			If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
				DCUserSetting.RightValue = Recipient;
			ElsIf TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
				DCUserSetting.Value = Recipient;
			EndIf;
		EndDo;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("UserSettings", DCUserSettings);
	FormParameters.Insert("GenerateOnOpen", True);
	
	ReportsOptionsClient.OpenReportForm(ThisObject, ReportParameters.Report, FormParameters);
	
	For Each DCUserSetting In PersonalizedSettings Do
		If TypeOf(DCUserSetting) = Type("DataCompositionFilterItem") Then
			DCUserSetting.RightValue = MailingRecipientValueTemplate();
		ElsIf TypeOf(DCUserSetting) = Type("DataCompositionSettingsParameterValue") Then
			DCUserSetting.Value = MailingRecipientValueTemplate();
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure SpecifyMailingRecipient(Command)
	ClearMessages();
	
	// Check - whether the possibility to personalize the mailing enabled.
	If Not Object.Personalized Then
		KindPresentaion = Items.BulkEmailType.ChoiceList.FindByValue("Personalized").Presentation;
		TheMessageText = NStr("en = 'You can specify recipients in parameters only if the distribution type is ""%1"".';");
		TheMessageText = StringFunctionsClientServer.SubstituteParametersToString(TheMessageText, KindPresentaion);
		CommonClient.MessageToUser(TheMessageText, , "BulkEmailType");
		Return;
	EndIf;
	
	// Get the main type of recipients.
	TypesCount = MailingRecipientType.Types().Count();
	If TypesCount <> 1 And TypesCount <> 2 Then
		CommonClient.MessageToUser(NStr("en = 'The ""Recipients"" field is required.';"), , "MailingRecipientType");
		Return;
	EndIf;
	
	FoundMetadataObjectIDs = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
	If FoundMetadataObjectIDs.Count() <> 1 Then
		ShowMessageBox(, NStr("en = 'Incorrect recipient type.';"));
		Return;
	EndIf;
	
	TypesArray = FoundMetadataObjectIDs[0].MainType.Types();
	If TypesArray.Count() <> 1 Then
		ShowMessageBox(, NStr("en = 'Incorrect recipient type.';"));
		Return;
	EndIf;
	
	MainRecipientsType = TypesArray[0];
	
	Setting = IdentifySetting();
	If Setting = Undefined Then
		Return;
	EndIf;
	
	// Recipients type content check.
	If Not Setting.DetailsOfAvailableTypes.ContainsType(MainRecipientsType) Then
		WarningText = NStr("en = 'Type ""%1"" is not suitable for the selected setting.
			|Select another recipient type or setting.';");
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText, String(MainRecipientsType));
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	
	Setting.Initiator.EndEditRow(False);
	Setting.SettingsString.Use = True;
	If Setting.DCS Then
		If Setting.IsFilterItem Then
			If Setting.SettingsString.ComparisonType = DataCompositionComparisonType.InList
				Or Setting.SettingsString.ComparisonType = DataCompositionComparisonType.InHierarchy
				Or Setting.SettingsString.ComparisonType = DataCompositionComparisonType.InListByHierarchy
				Or Setting.SettingsString.ComparisonType = DataCompositionComparisonType.NotInList
				Or Setting.SettingsString.ComparisonType = DataCompositionComparisonType.NotInHierarchy
				Or Setting.SettingsString.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
				Setting.SettingsString.ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
			Setting.SettingsString.RightValue = MailingRecipientValueTemplate();
		Else
			Setting.SettingsString.Value = MailingRecipientValueTemplate();
		EndIf;
	Else
		Setting.SettingsString.Value = MailingRecipientValueTemplate();
	EndIf;
	
	FindPersonalizationSettings();
	
	MailingWasPersonalized = True;
	Items.Reports.CurrentData.ChangesMade = True;
	Modified = True;
	
EndProcedure

&AtClient
Procedure DeleteMailingRecipient(Command)
	ClearMessages();
	
	Setting = IdentifySetting();
	If Setting = Undefined Then
		Return;
	EndIf;
	
	Setting.Initiator.EndEditRow(False);
	ChangesMade = False;
	If Setting.DCS Then
		If Setting.IsFilterItem Then
			If Setting.SettingsString.RightValue = MailingRecipientValueTemplate() Then
				Setting.SettingsString.RightValue = Undefined;
				ChangesMade = True;
			EndIf;
		Else
			If Setting.SettingsString.Value = MailingRecipientValueTemplate() Then 
				Setting.SettingsString.Value = Undefined;
				ChangesMade = True;
			EndIf;
		EndIf;
	Else
		If Setting.SettingsString.Value = MailingRecipientValueTemplate() Then 
			Setting.SettingsString.Value = Undefined;
			ChangesMade = True;
		EndIf;
	EndIf;
	
	If ChangesMade Then
		Items.Reports.CurrentData.ChangesMade = True;
		Modified = True;
	EndIf;
EndProcedure

&AtClient
Function IdentifySetting()
	
	DCS = (Items.ReportSettingsPages.CurrentPage = Items.ComposerPage);
	If DCS Then
		Initiator = Items.UserSettings;
	Else
		Initiator = Items.CurrentReportSettings;
	EndIf;
	
	// Get details of the types available for selection.
	If DCS Then
		
		// User setting ID.
		SettingID = Initiator.CurrentRow;
		If SettingID = Undefined Then
			ShowMessageBox(, NStr("en = 'Report setting is not selected.';"));
			Return Undefined;
		EndIf;
		
		UserSettings = DCSettingsComposer.UserSettings;
		
		// Get a row from data composition settings.
		SettingsString = UserSettings.GetObjectByID(SettingID);
		If SettingsString = Undefined Then
			ShowMessageBox(, NStr("en = 'Report setting is not selected.';"));
			Return Undefined;
		EndIf;
		
		// Setting type check.
		If TypeOf(SettingsString) = Type("DataCompositionFilterItem") Then
			IsFilterItem = True;
		ElsIf TypeOf(SettingsString) = Type("DataCompositionSettingsParameterValue") Then
			IsFilterItem = False;
		Else
			ShowMessageBox(, NStr("en = 'You can specify the recipient only for report parameters and filters.';"));
			Return Undefined;
		EndIf;
		
		// Data composition field.
		If IsFilterItem Then
			FoundItems1 = UserSettings.GetMainSettingsByUserSettingID(
				SettingsString.UserSettingID);
			
			If FoundItems1.Count() > 0 Then 
				DCField = FoundItems1[0].LeftValue;
			Else
				
				DCField = DetermineFieldFromComposer(SettingID, DCSettingsComposer.Settings.Filter.Items);
				If DCField = Undefined Then
					DCField = DetermineFieldFromComposer(SettingID, UserSettings.Items);
				EndIf;
				If DCField = Undefined Then
					ShowMessageBox(, NStr("en = 'There is no details of an available field for the report setting.';"));
					Return Undefined;
				EndIf;
				
			EndIf;
			AvailableDCField = DCSettingsComposer.Settings.Filter.FilterAvailableFields.FindField(DCField);
			
		Else
			AvailableDCField = DCSettingsComposer.Settings.DataParameters.AvailableParameters.FindParameter(SettingsString.Parameter);
		EndIf;
		
		If AvailableDCField = Undefined Then
			Return Undefined;
		EndIf;
		DetailsOfAvailableTypes = AvailableDCField.ValueType;
		
	Else
		
		// 
		SettingsString = Initiator.CurrentData;
		If SettingsString = Undefined Then
			ShowMessageBox(, NStr("en = 'Report setting is not selected.';"));
			Return Undefined;
		EndIf;
		
		DetailsOfAvailableTypes = SettingsString.Type;
	EndIf;
	
	Result = New Structure;
	Result.Insert("DCS", DCS);
	Result.Insert("Initiator", Initiator);
	Result.Insert("DetailsOfAvailableTypes", DetailsOfAvailableTypes);
	Result.Insert("SettingsString", SettingsString);
	Result.Insert("IsFilterItem", IsFilterItem);
	Return Result;
	
EndFunction

&AtClient
Function DetermineFieldFromComposer(SettingID, Collection)
	For Each Item In Collection Do
		If String(Item.UserSettingID) = String(SettingID)
			And ValueIsFilled(String(Item.LeftValue)) Then
			Return Item.LeftValue;
		EndIf;
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup")
			Or TypeOf(Item) = Type("DataCompositionFilter") Then
			Field = DetermineFieldFromComposer(SettingID, Item.Items);
			If Field <> Undefined Then
				Return Field;
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure SelectCheckBoxes(Command)
	AllMonths = New Array;
	For Each KeyAndValue In Cache.Maps1.Months Do
		ThisObject[KeyAndValue.Key] = True;
		AllMonths.Add(KeyAndValue.Value);
	EndDo;
	Schedule.Months = AllMonths;
	VisibilityAvailabilityCorrectness(ThisObject, "Months");
EndProcedure

&AtClient
Procedure ClearCheckBoxes(Command)
	AllMonths = New Array;
	For Each KeyAndValue In Cache.Maps1.Months Do
		ThisObject[KeyAndValue.Key] = False;
	EndDo;
	Schedule.Months = AllMonths;
	VisibilityAvailabilityCorrectness(ThisObject, "Months");
EndProcedure

&AtClient
Procedure FillScheduleByTemplate(Command)
	Handler = New NotifyDescription("FillScheduleByTemplateCompletion", ThisObject);
	
	VariantList = ReportMailingClient.ScheduleFillingOptionsList();
	VariantList.ShowChooseItem(Handler, NStr("en = 'Select schedule template.';"));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure AddChangeMailingDateTemplate(Command)
	AddLayout();
	
	Variables1 = New Structure;
	Variables1.Insert("Item",      CurrentItem);
	Variables1.Insert("PreviousText1",  Variables1.Item.SelectedText);
	Variables1.Insert("Prefix",      "[ExecutionDate(");
	Variables1.Insert("Postfix",     ")]");
	Variables1.Insert("FormatText", "");
	
	PrefixLength  = StrLen(Variables1.Prefix);
	PrefixPosition  = StrFind(Variables1.PreviousText1, Variables1.Prefix);
	PostfixPosition = StrFind(Variables1.PreviousText1, Variables1.Postfix);
	
	Variables1.Insert("PreviousFragmentFound", (PrefixPosition > 0 And PostfixPosition > PrefixPosition));
	If Variables1.PreviousFragmentFound Then
		Variables1.FormatText = Mid(Variables1.PreviousText1, PrefixPosition + PrefixLength, PostfixPosition - PrefixPosition - PrefixLength);
	EndIf;
	
	Handler = New NotifyDescription("AddChangeMailingDateTemplateCompletion", ThisObject, Variables1);
	
	Dialog = New FormatStringWizard;
	Dialog.AvailableTypes = New TypeDescription("Date");
	Dialog.Text         = Variables1.FormatText;
	Dialog.Show(Handler);
	
EndProcedure

&AtClient
Procedure AddRecipientTemplate(Command)
	// Clean up message window.
	ClearMessages();
	
	//
	If Not Object.Personalized Then
		TheMessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You can specify recipients in template body only if the distribution type is ""%1"".';"),
			Items.BulkEmailType.ChoiceList.FindByValue("Personalized").Presentation);
		CommonClient.MessageToUser(TheMessageText, , "BulkEmailType");
		Return;
	EndIf;
	
	AddLayout(MailingRecipientValueTemplate());
	MailingWasPersonalized = True;
EndProcedure

&AtClient
Procedure AddGeneratedReportsTemplate(Command)
	AddLayout("[GeneratedReports]", True);
EndProcedure

&AtClient
Procedure AddAuthorTemplate(Command)
	AddLayout("[Author]");
EndProcedure

&AtClient
Procedure AddMailingDescriptionTemplate(Command)
	AddLayout("[MailingDescription]");
EndProcedure

&AtClient
Procedure AddSystemTemplate(Command)
	AddLayout("[SystemTitle]");
EndProcedure

&AtClient
Procedure AddDeliveryMethodTemplate(Command)
	AddLayout("[DeliveryMethod]");
EndProcedure

&AtClient
Procedure AddDefaultTemplate(Command)
	OverwriteSubject = (CurrentItem = Items.EmailSubject);
	
	If OverwriteSubject Then
		SubjectValue = Object.EmailSubject;
		DefaultTemplate = Cache.Templates.Subject;
	Else
		If Object.HTMLFormatEmail Then
			SubjectValue = EmailTextFormattedDocument.GetText();
		Else
			SubjectValue = Object.EmailText;
		EndIf;
		SubjectValue = TrimAll(SubjectValue);
		DefaultTemplate = Cache.Templates.Text;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("OverwriteSubject", OverwriteSubject);
	AdditionalParameters.Insert("DefaultTemplate", DefaultTemplate);
	
	If SubjectValue = "" Then
		// Empty subject  - required to be filled without questions.
		AddDefaultTemplateCompletion(1, AdditionalParameters);
		
	ElsIf SubjectValue = DefaultTemplate Then
		// Subject matches the template — no fill required.
		
		If OverwriteSubject Then
			WarningText = NStr("en = 'Email subject already matches the default template.';");
		Else
			WarningText = NStr("en = 'Email text already matches the default template.';");
		EndIf;
		ShowMessageBox(, WarningText);
		
	Else
		// Subject is not empty - you need to ask a replacement for a standard template.
		
		If OverwriteSubject Then
			QuestionTitle = NStr("en = 'Add default template to the email subject';");
			QueryText = NStr("en = 'Replace the email subject with the default template?';");
		Else
			QuestionTitle = NStr("en = 'Add default template to the email body';");
			QueryText = NStr("en = 'Replace the email text with the default template?';");
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(1, NStr("en = 'Replace';"));
		Buttons.Add(2, NStr("en = 'Add';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("AddDefaultTemplateCompletion", ThisObject, AdditionalParameters);
		
		ShowQueryBox(Handler, QueryText, Buttons, 60, 1, QuestionTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplatePreview(Command)
	
	AddLayout();
	
	PicturesForHTML = New Structure;
	
	Template = Object.EmailText;
	If Object.HTMLFormatEmail Then
		TextType = PredefinedValue("Enum.EmailTextTypes.HTML");
		EmailTextFormattedDocument.GetHTML(Template, PicturesForHTML);
		Template = Object.EmailSubject + "<br>" + "<br>" + Template;
	Else
		TextType = PredefinedValue("Enum.EmailTextTypes.PlainText");
		Template = Object.EmailSubject + Chars.LF + Chars.LF + Template;
	EndIf;

	GeneratedReports = "";
	For Each RowReport In Object.Reports Do
		ReportPresentation = StringFunctionsClientServer.SubstituteParametersToString("%1. %2",
			RowReport.LineNumber, RowReport.Presentation);
		GeneratedReports = GeneratedReports + Chars.LF + ReportPresentation;
	EndDo;
	GeneratedReports = TrimAll(GeneratedReports);
	If Object.Archive Then
		GeneratedReports = GeneratedReports + Chars.LF + Chars.LF + NStr(
			"en = 'Report files are archived';") + " ";

		ArchiveNameStructure = New Structure("MailingDescription, ExecutionDate", Object.Description,
			CommonClient.SessionDate());
		ArchiveName = ReportMailingClientServer.FillTemplate(Object.ArchiveName, ArchiveNameStructure);
		ArchiveName = ArchiveName + ".zip";

		GeneratedReports = TrimAll(
				GeneratedReports + """" + ArchiveName + """");
	EndIf;

	DeliveryParameters = ReportMailingClientServer.DeliveryParameters();
	FillPropertyValues(DeliveryParameters, Object);
	DeliveryParameters.ExecutedToFolder = Object.UseFolder;
	DeliveryParameters.ExecutedToNetworkDirectory = Object.UseNetworkDirectory;
	DeliveryParameters.ExecutedAtFTP = Object.UseFTPResource;
	DeliveryMethod = ReportMailingClientServer.DeliveryMethodsPresentation(DeliveryParameters);
	
	TemplateParameters = New Structure;
	TemplateParameters.Insert("MailingDescription", Object.Description);
	TemplateParameters.Insert("Author",                Object.Author);
	TemplateParameters.Insert("SystemTitle",     Cache.SystemTitle);
	TemplateParameters.Insert("ExecutionDate",       CommonClient.SessionDate());
	TemplateParameters.Insert("GeneratedReports", GeneratedReports);
	TemplateParameters.Insert("DeliveryMethod",       DeliveryMethod);
	
	If BulkEmailType = "Personalized" Then
		FirstRecipient = GetFirstRecipient();
		TemplateParameters.Insert("Recipient", FirstRecipient.Description);
		FirstRecipientRef = FirstRecipient.Ref;
	Else
		FirstRecipientRef = Undefined;
	EndIf;
	AddTemplateAdditionalParameters(TemplateParameters, FirstRecipientRef);
	
	// 
	If Object.ShouldInsertReportsIntoEmailBody Then
		ReportsInEmailText = "";
		For Each RowReport In Object.Reports Do
			ReportsInEmailText = ReportsInEmailText + Chars.LF
				+ "------------------------------------------" + Chars.LF
				+ RowReport.Presentation;
		EndDo;
		If Object.HTMLFormatEmail Then
			ReportsInEmailText = StrReplace(ReportsInEmailText, Chars.LF, Chars.LF + "<br>");
		EndIf;
		Template = Template + Chars.LF + Chars.LF + ReportsInEmailText;
	EndIf;
	
	// 
	If Object.ShouldAttachReports Then
		ReportsPlannedList = ReportsPlannedListInAttachments();
		If ReportsPlannedList.Count() > 0 Then
			ReportsList = StrConcat(ReportsPlannedList, Chars.LF);

			AttachmentText = Chars.LF + Chars.LF + NStr("en = 'Email attachments:';");
			If Object.Archive Then
				ArchiveNameStructure = New Structure("MailingDescription, ExecutionDate", Object.Description,
					CommonClient.SessionDate());
				ArchiveName = ReportMailingClientServer.FillTemplate(Object.ArchiveName, ArchiveNameStructure);
				ArchiveName = ArchiveName + ".zip";
				AttachmentText = AttachmentText + Chars.LF + Chars.LF + ArchiveName;
			Else
				AttachmentText = AttachmentText + Chars.LF;
			EndIf;
			FileNumber = 1;
			For Each FullFileName In ReportsPlannedList Do
				NameOfFileWithOrder = StringFunctionsClientServer.SubstituteParametersToString("%1. %2",
					FileNumber, FullFileName);
				If Object.HTMLFormatEmail Then
					AttachmentText = AttachmentText + "<p style=""margin-left: 50px;"">" + NameOfFileWithOrder + "</p>";
				Else
					AttachmentText = AttachmentText + Chars.LF + Chars.Tab + NameOfFileWithOrder;
				EndIf;
				FileNumber = FileNumber + 1;
			EndDo;
			
			If Object.HTMLFormatEmail Then
				AttachmentText = StrReplace(AttachmentText, Chars.LF, Chars.LF + "<br>");
			EndIf;
			Template = Template + Chars.LF + AttachmentText;
		EndIf;
	EndIf;
	
	Text = ReportMailingClientServer.FillTemplate(Template, TemplateParameters);
	
	FormParameters = New Structure;
	FormParameters.Insert("MailingDescription", Object.Description);
	FormParameters.Insert("TextType", TextType);
	FormParameters.Insert("Text", Text);
	If PicturesForHTML.Count() > 0 Then
		FormParameters.Insert("PicturesAddressForHTML", PutPicturesToTempStorage(PicturesForHTML));
	EndIf;
	OpenForm("Catalog.ReportMailings.Form.EmailPreview", FormParameters, ThisObject, , , , ,
		FormWindowOpeningMode.Independent);

EndProcedure

&AtClient
Procedure CheckIfBulkEmailIsPossible(Command)
	
	DeliveryParameters = ReportMailingClientServer.DeliveryParameters();
	DeliveryParameters.ExecutionDate = CommonClient.SessionDate();
	DeliveryParameters.Author = Object.Author;
	DeliveryParameters.UseFolder = Object.UseFolder;
	DeliveryParameters.UseNetworkDirectory = Object.UseNetworkDirectory;
	DeliveryParameters.UseFTPResource = Object.UseFTPResource;
	DeliveryParameters.UseEmail = Object.UseEmail;
	
	CheckMailing(DeliveryParameters);
	
EndProcedure

&AtClient
Procedure ChangeTextTypeToHTML(Command)
	Modified = True;
	Object.HTMLFormatEmail = True;
	EmailTextFromHTML = TrimAll(EmailTextFormattedDocument.GetText());
	If EmailTextFromHTML <> Object.EmailText Then
		EmailTextFormattedDocument.Delete();
		EmailTextFormattedDocument.Add(Object.EmailText, FormattedDocumentItemType.Text);
	EndIf;
	CurrentItem = Items.EmailTextFormattedDocument;
	VisibilityAvailabilityCorrectness(ThisObject, "HTMLFormatEmail");
EndProcedure

&AtClient
Procedure ChangeTextTypeToPlain(Command)
	Modified = True;
	Object.HTMLFormatEmail = False;
	EmailTextFromHTML = TrimAll(EmailTextFormattedDocument.GetText());
	If Object.EmailText <> EmailTextFromHTML Then
		Object.EmailText = EmailTextFromHTML;
	EndIf;
	CurrentItem = Items.EmailText;
	VisibilityAvailabilityCorrectness(ThisObject, "HTMLFormatEmail");
EndProcedure

&AtClient
Procedure ImportanceHigh(Command)
	Object.EmailImportance = "High";
	Items.SeverityGroup.Picture = PictureLib.ImportanceHigh;
	Items.SeverityGroup.ToolTip = NStr("en = 'High importance';");
	Modified = True;
EndProcedure

&AtClient
Procedure ImportanceNormal(Command)
	Object.EmailImportance = "Ordinary";
	Items.SeverityGroup.Picture = PictureLib.ImportanceNotSpecified;
	Items.SeverityGroup.ToolTip = NStr("en = 'Normal importance';");
	Modified = True;
EndProcedure

&AtClient
Procedure ImportanceLow(Command)
	Object.EmailImportance = "Low";
	Items.SeverityGroup.Picture = PictureLib.ImportanceLow;
	Items.SeverityGroup.ToolTip = NStr("en = 'Low importance';");
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_AddEmailTextAdditionalParameter(Command)

	If EmailTextAdditionalParameters = Undefined Then
		Return;
	EndIf;

	If Not EmailTextAdditionalParameters.Property(Command.Name) Then
		Return;
	EndIf;

	ParameterName = "[" + EmailTextAdditionalParameters[Command.Name].Name + "]";
	AddLayout(ParameterName);

EndProcedure

&AtClient
Procedure ShouldInsertReportsIntoEmailBodyOnChange(Item)

	If Object.ShouldInsertReportsIntoEmailBody Then
		Object.NotifyOnly = False;
		If Object.ShouldAttachReports Then
			CheckEncryptionBeforeIncludeReportsToEmailBody();
		EndIf;
	Else
		Object.ShouldAttachReports = True;
		VisibilityAvailabilityCorrectness(ThisObject, "ShouldAttachReports");
	EndIf;

EndProcedure

&AtClient
Procedure ShouldAttachReportsOnChange(Item)

	If Object.ShouldAttachReports Then
		Object.NotifyOnly = False;
		If Object.ShouldAttachReports Then
			CheckEncryptionBeforeIncludeReportsToEmailBody();
		EndIf;
	Else
		Object.ShouldInsertReportsIntoEmailBody = True;
	EndIf;

	VisibilityAvailabilityCorrectness(ThisObject, "ShouldAttachReports");
	

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ResetDefaultFormat(Command)
	ClearFormat(Cache.EmptyReportValue);
	DefaultFormats = DefaultFormatsListPresentation;
	VisibilityAvailabilityCorrectness(ThisObject, "DefaultFormats");
EndProcedure

&AtClient
Procedure ClearAllSendIfBlank(Command)
	If Object.Reports.Count() > 0 Then
		Modified = True;
		For Each StrReport In Object.Reports Do
			StrReport.SendIfEmpty = False;
			StrReport.DoNotSendIfEmpty = True;
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure SelectAllSendIfBlank(Command)
	If Object.Reports.Count() > 0 Then
		Modified = True;
		For Each StrReport In Object.Reports Do
			StrReport.SendIfEmpty = True;
			StrReport.DoNotSendIfEmpty = False;
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure CreateArchivePassword(Command)
	
	If ValueIsFilled(ArchivePassword) Then	
		ShowQueryBox(
			New NotifyDescription("OnCreateArchivePassword", ThisObject),
			NStr("en = 'A password for the archive is already set. Do you want to set a new password?';"),
			QuestionDialogMode.YesNo, , DialogReturnCode.No);	
		Return;
	EndIf;
	
	If Object.ShouldInsertReportsIntoEmailBody And Object.ShouldAttachReports Then
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;

		QuestionButtons = New ValueList;
		QuestionButtons.Add("AutoSetPassword", NStr("en = 'Set password';"));
		QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		QueryText = NStr(
			"en = 'To set a password, remove the reports from the email text.';");
		QuestionParameters.DefaultButton = "SetPassword";

		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("AfterAnswerQuestionPasswordEncryptionReportsInEmailText", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);
	Else
		ArchivePassword = CreatePassword();
		ArchivePasswordChanged = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PasswordsEncryption(Command)

	OpenFormPasswordsEncryption();

EndProcedure

&AtClient
Procedure SetTemplateDescription(Command)
	SetDescriptionTemplates("ReportDescription1", True);
EndProcedure

&AtClient
Procedure SetTemplateDescriptionFormat(Command)
	SetDescriptionTemplates("ReportDescriptionFormat", True);
EndProcedure

&AtClient
Procedure SetTemplateDescriptionPeriod(Command)
	SetDescriptionTemplates("DescriptionPeriod", True);
EndProcedure

&AtClient
Procedure SetTemplateDescriptionPeriodFormat(Command)
	SetDescriptionTemplates("DescriptionPeriodFormat", True);
EndProcedure

&AtClient
Procedure SetTemplateDescriptionDistributionDate(Command)
	SetDescriptionTemplates("DescriptionDistributionDate", True);
EndProcedure

&AtClient
Procedure SetTemplateDescriptionDistributionDateFormat(Command)
	SetDescriptionTemplates("DescriptionDistributionDateFormat", True);
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UserSettingStartChoice(StandardProcessing)
	If Items.ReportSettingsPages.CurrentPage <> Items.ComposerPage Then
		Return;
	EndIf;
	Report = Items.Reports.CurrentData;
	If Report = Undefined Or TypeOf(Report.Report) <> Type("CatalogRef.ReportsOptions") Then
		Return;
	EndIf;
	DCID = Items.UserSettings.CurrentRow;
	Handler = New NotifyDescription("SelectUserSettingsCompletion", ThisObject);
	ReportMailingClientOverridable.OnSettingChoiceStart(Report, DCSettingsComposer, DCID, StandardProcessing, Handler);
EndProcedure

&AtClient
Procedure SelectUserSettingsCompletion(Result, ExecutionParameters) Export
	If TypeOf(Result) = Type("DataCompositionUserSettings") Then
		DCSettingsComposer.LoadUserSettings(Result);
	Else
		Return;
	EndIf;
	Report = Items.Reports.CurrentData;
	If Report = Undefined Or TypeOf(Report.Report) <> Type("CatalogRef.ReportsOptions") Then
		Return;
	EndIf;
	Report.ChangesMade = True;
EndProcedure

// A handler of closing the BulkEmailRecipients form.
//
// Parameters:
//   Result - Structure:
//     * Recipients - ValueTable:
//         * Recipient - CatalogRef.UserGroups,
//                      - CatalogRef._DemoCounterparties,
//                      - CatalogRef._DemoPartners,
//                      - CatalogRef.Users
//         * Excluded - Boolean
//         * Address - String
//         * PictureIndex - Number
//     * RecipientsEmailAddressKind - CatalogRef.ContactInformationKinds
//   Parameter - Structure
//            - Undefined
//
&AtClient
Procedure BulkEmailRecipientsClickCompletion(Result, Parameter) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	Object.RecipientsEmailAddressKind = Result.RecipientsEmailAddressKind;
	Object.Recipients.Clear();
	For Each Item In Result.Recipients Do 
		NewRow = Object.Recipients.Add();
		NewRow.Recipient = Item.Recipient;
		NewRow.Excluded = Item.Excluded;
	EndDo;
	
	VisibilityAvailabilityCorrectness(ThisObject, "BulkEmailRecipients");
	Modified = True;
EndProcedure

&AtClient
Procedure MailingRecipientTypeChoiceProcessingCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Object.Recipients.Clear();
		MailingRecipientType = AdditionalParameters.ValueSelected;
		Modified = True;
		MailingRecipientTypeOnChange(Undefined);
		VisibilityAvailabilityCorrectness(ThisObject, "BulkEmailRecipients");
	EndIf;
EndProcedure

&AtClient
Procedure AddDefaultTemplateCompletion(Response, AdditionalParameters) Export
	DefaultTemplate = AdditionalParameters.DefaultTemplate;
	If Response = 1 Then
		If AdditionalParameters.OverwriteSubject Then
			Object.EmailSubject = DefaultTemplate;
		Else
			If Object.HTMLFormatEmail Then
				EmailTextFormattedDocument.Delete();
				EmailTextFormattedDocument.Add(DefaultTemplate, FormattedDocumentItemType.Text);
			Else
				Object.EmailText = DefaultTemplate;
			EndIf;
		EndIf;
	ElsIf Response = 2 Then
		AddLayout(DefaultTemplate);
	EndIf;
EndProcedure

&AtClient
Procedure CheckMailingAfterResponseToQuestion(Response, DeliveryParameters) Export
	If Response = 1 Or Modified Then
		If Response = 1 Then
			Object.IsPrepared = True;
		EndIf;
		WriteParameters = New Structure;
		WriteParameters.Insert("CommandName", "CommandCheckMailing");
		WriteParameters.Insert("DeliveryParameters", DeliveryParameters);
		WriteAtClient(Undefined, WriteParameters);
		Return;
	ElsIf Response <> -1 Then
		Return;
	EndIf;
	
	ClearMessages();
	
	DeliveryParameters.BulkEmail = Object.Description;
	
	If DeliveryParameters.UseFolder Then
		DeliveryParameters.Folder = Object.Folder;
	EndIf;
	
	If DeliveryParameters.UseNetworkDirectory Then
		DeliveryParameters.NetworkDirectoryWindows = Object.NetworkDirectoryWindows;
		DeliveryParameters.NetworkDirectoryLinux = Object.NetworkDirectoryLinux;
	EndIf;
	
	If DeliveryParameters.UseFTPResource Then
		DeliveryParameters.Owner = Object.Ref;
		DeliveryParameters.Server = Object.FTPServer;
		DeliveryParameters.Port = Object.FTPPort;
		DeliveryParameters.Login = Object.FTPLogin;
		If FTPPasswordChanged Then
			DeliveryParameters.Password = FTPPassword;
		EndIf;
		DeliveryParameters.Directory = Object.FTPDirectory;
		DeliveryParameters.PassiveConnection = Object.FTPPassiveConnection;
	EndIf;
	
	Handler = New NotifyDescription("CheckMailingAfterRecipientsChoice", ThisObject, DeliveryParameters);
	
	If DeliveryParameters.UseEmail Then
		ReportMailingClient.SelectRecipient(Handler, Object, False, True);
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Handler, Undefined);
	
EndProcedure

&AtClient
Procedure CheckMailingAfterRecipientsChoice(SelectionResult, DeliveryParameters) Export
	// CheckMailingAfterResponseToQuestion procedure execution result handler.
	If DeliveryParameters.UseEmail Then
		If SelectionResult = Undefined Then
			Return;
		EndIf;
		
		DeliveryParameters.Account = Object.Account;
		DeliveryParameters.BCCs  = Object.BCCs;
		DeliveryParameters.SubjectTemplate    = NStr("en = 'Test message from 1C:Enterprise';");
		DeliveryParameters.TextTemplate1  = NStr("en = 'This message is sent by 1C: Enterprise mailing system.';")
			+ Chars.LF + Cache.SystemTitle;
		DeliveryParameters.Recipients    = SelectionResult;
	EndIf;
	
	ExecutionResult = CheckTransportMethod(Object.Ref, DeliveryParameters);
	
	WarningParameters = New Structure("Title, Text, More, Ref, UseEmail");
	FillPropertyValues(WarningParameters, DeliveryParameters);
	FillPropertyValues(WarningParameters, ExecutionResult);
	WarningParameters.Title = NStr("en = 'Check result';");
	WarningParameters.Ref = Object.Account;
	
	OpenForm("Catalog.ReportMailings.Form.Warning", WarningParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure FillScheduleByTemplateCompletion(SelectedElement, AdditionalParameters) Export
	If SelectedElement <> Undefined Then
		FillScheduleByOption(SelectedElement.Value, True);
	EndIf;
EndProcedure

// A handler of closing the format string dialog box.
//
// Parameters:
//   ResultRow - String
//   Variables1 - Structure
//
&AtClient
Procedure AddChangeMailingDateTemplateCompletion(ResultRow, Variables1) Export
	If ResultRow = Undefined Then
		Return;
	EndIf;
	
	NewFragment   = Variables1.Prefix + ResultRow + Variables1.Postfix;
	PreviousFragment  = Variables1.Prefix + Variables1.FormatText + Variables1.Postfix;
	
	If Variables1.Property("ChangeReportDescriptionTemplateMultiply")
	   And Variables1.ChangeReportDescriptionTemplateMultiply Then
		If Variables1.PreviousFragmentFound Then
			DescriptionTemplate1 = StrReplace(Variables1.PreviousText1, PreviousFragment, NewFragment);
		Else
			DescriptionTemplate1 = Variables1.PreviousText1 + NewFragment;
		EndIf;
		SetDescriptionTemplatesForAllReports(Variables1.TemplateName, DescriptionTemplate1);
	ElsIf Variables1.Property("ShouldChangeReportDescriptionTemplate") And Variables1.ShouldChangeReportDescriptionTemplate Then
		If Variables1.PreviousFragmentFound Then
			If ResultRow = Variables1.FormatText Then
				Return;
			EndIf;
			Items.ReportFormats.CurrentData.DescriptionTemplate1 = StrReplace(Variables1.PreviousText1, PreviousFragment, NewFragment);
		Else
			Items.ReportFormats.CurrentData.DescriptionTemplate1 = Variables1.PreviousText1 + NewFragment;
		EndIf;
	ElsIf Variables1.Item = Items.EmailTextFormattedDocument Then
		ReplacementExecuted = False;
		If Variables1.PreviousFragmentFound Then
			SearchResult = EmailTextFormattedDocument.FindText(PreviousFragment);
			If SearchResult <> Undefined Then
				FoundItems = EmailTextFormattedDocument.GetItems(SearchResult.BeginBookmark, SearchResult.EndBookmark);
				For Each FDText In FoundItems Do
					If StrFind(FDText.Text, PreviousFragment) > 0 Then
						FDText.Text = StrReplace(FDText.Text, PreviousFragment, NewFragment);
						ReplacementExecuted = True;
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf; // Variable.PreviousFragmentFound
		If Not ReplacementExecuted Then
			If TrimAll(Variables1.PreviousText1) = PreviousFragment Then
				// 
				//  
				Variables1.Item.SelectedText = NewFragment;
			Else
				EmailTextFormattedDocument.Add(NewFragment, FormattedDocumentItemType.Text);
			EndIf;
		EndIf;
	Else
		If Variables1.PreviousFragmentFound Then
			If ResultRow = Variables1.FormatText Then
				Return;
			EndIf;
			Variables1.Item.SelectedText = StrReplace(Variables1.PreviousText1, PreviousFragment, NewFragment);
		Else
			Variables1.Item.SelectedText = Variables1.PreviousText1 + NewFragment;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseFormatCompletion(FormatsList, Variables1) Export
	If FormatsList = Undefined Then
		Return;
	EndIf;
	
	// Check for changes.
	FormatsMatch = True;
	For IndexOf = 1 To FormatsList.Count() Do
		If FormatsList[IndexOf - 1].Check <> Variables1.FormatsListCopy[IndexOf - 1].Check Then
			FormatsMatch = False;
			Break;
		EndIf;
	EndDo;
	If FormatsMatch Then
		Return;
	EndIf;
	
	FormatPresentation = "";
	
	// Clean up existing records.
	ClearFormat(Variables1.ReportRef1);
	
	// Add marked formats.
	For Each ListItem In FormatsList Do
		If ListItem.Check Then
			StringFormat = Object.ReportFormats.Add();
			StringFormat.Report  = Variables1.ReportRef1;
			StringFormat.Format = ListItem.Value;
			FormatPresentation = FormatPresentation + ?(FormatPresentation = "", "", ", ") + String(ListItem.Presentation);
		EndIf;
	EndDo;
	
	If Variables1.IsDefaultFormat And FormatPresentation = "" Then
		FormatPresentation = DefaultFormatsListPresentation;
	EndIf;
	
	ExecuteNotifyProcessing(Variables1.ResultHandler, FormatPresentation);
EndProcedure

&AtClient
Procedure ReportFormatsEndChoiceFormat(FormatPresentation, Variables1) Export
	If FormatPresentation <> Undefined Then
		Variables1.ReportsRow.Formats = FormatPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure DefaultFormatsSelectionCompletion(FormatPresentation, Variables1) Export
	If FormatPresentation <> Undefined Then
		DefaultFormats = FormatPresentation;
	EndIf;
	VisibilityAvailabilityCorrectness(ThisObject, "DefaultFormats");
EndProcedure

&AtClient
Procedure AfterChangeSchedule(ScheduleResult, AdditionalParameters) Export
	If ScheduleResult <> Undefined Then
		Modified = True;
		Schedule = ScheduleResult;
		VisibilityAvailabilityCorrectness(ThisObject, "Schedule");
	EndIf;
EndProcedure

&AtClient
Function ChoicePickupDragItemToTabularSection(PickingItem, TabularSection, Var_AttributeName, FillingStructure, Uniqueness = True)
	
	// (CatalogRef.*) drag from the pickup or selection form.
	AttributeValue = PickingItem;
	
	// Attributes uniqueness in the table borders is required.
	FoundItems = TabularSection.FindRows(New Structure(Var_AttributeName, AttributeValue));
	
	If Uniqueness And FoundItems.Count() > 0 Then
		Return Undefined;
	EndIf;
	
	TableRow = TabularSection.Add();
	TableRow[Var_AttributeName] = AttributeValue;
	FillPropertyValues(TableRow, FillingStructure);
	
	Return TableRow;
EndFunction

&AtClient
Function ChoicePickupDragToTabularSection(ValueSelected, TabularSection, Var_AttributeName, FillingStructure, IDs = False)
	Modified = True;
	NewRowArray = New Array;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each PickingItem In ValueSelected Do
			Result = ChoicePickupDragItemToTabularSection(PickingItem, TabularSection, Var_AttributeName, FillingStructure);
			If Result <> Undefined Then
				NewRowArray.Add(?(IDs, Result.GetID(), Result));
			EndIf;
		EndDo;
	Else
		Result = ChoicePickupDragItemToTabularSection(ValueSelected, TabularSection, Var_AttributeName, FillingStructure);
		If Result <> Undefined Then
			NewRowArray.Add(?(IDs, Result.GetID(), Result));
		EndIf;
	EndIf;
	Return NewRowArray;
EndFunction

&AtClient
Procedure ChooseFormat(ReportRef1, ResultHandler)
	// 
	// 
	// 
	IsDefaultFormat = Not ValueIsFilled(ReportRef1);
	
	FoundItems = Object.ReportFormats.FindRows(New Structure("Report", ReportRef1));
	If FoundItems.Count() > 0 Then
		FormatsList.FillChecks(False);
		For Each StringFormat In FoundItems Do
			FormatsList.FindByValue(StringFormat.Format).Check = True;
		EndDo;
	Else
		FormatsList = DefaultFormatsList.Copy();
		If Not IsDefaultFormat Then
			FoundItems = Object.ReportFormats.FindRows(New Structure("Report", Cache.EmptyReportValue));
			If FoundItems.Count() > 0 Then
				FormatsList.FillChecks(False);
				For Each StringFormat In FoundItems Do
					FormatsList.FindByValue(StringFormat.Format).Check = True;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	If IsDefaultFormat Then
		DialogTitle = NStr("en = 'Select default formats';");
	Else
		DialogTitle = NStr("en = 'Select formats for report ""%1""';");
		DialogTitle = StringFunctionsClientServer.SubstituteParametersToString(DialogTitle, String(ReportRef1));
	EndIf;
	
	Variables1 = New Structure;
	Variables1.Insert("ReportRef1",        ReportRef1);
	Variables1.Insert("FormatsListCopy",  FormatsList.Copy());
	Variables1.Insert("IsDefaultFormat", IsDefaultFormat);
	Variables1.Insert("ResultHandler", ResultHandler);
	Handler = New NotifyDescription("ChooseFormatCompletion", ThisObject, Variables1);
	
	FormatsList.ShowCheckItems(Handler, DialogTitle);
	
EndProcedure

&AtClient
Procedure ClearFormat(ReportRef1)
	Modified = True;
	FoundItems = Object.ReportFormats.FindRows(New Structure("Report", ReportRef1));
	For Each StringFormat In FoundItems Do
		Object.ReportFormats.Delete(StringFormat);
	EndDo;
EndProcedure

&AtClient
Procedure AddLayout(TextTemplate = Undefined, SkipEmailSubject = False)
	// Checking and setting focus on the item.
	If SkipEmailSubject Or Not (CurrentItem = Items.EmailSubject Or CurrentItem = Items.ArchiveName) Then
		If Object.HTMLFormatEmail Then
			If CurrentItem <> Items.EmailTextFormattedDocument Then
				CurrentItem = Items.EmailTextFormattedDocument;
			EndIf;
		Else
			If CurrentItem <> Items.EmailText Then
				CurrentItem = Items.EmailText;
			EndIf;
		EndIf;
	EndIf;
	
	If TextTemplate = Undefined Then
		// 
		Return;
	EndIf;
	
	If CurrentItem.SelectedText = "" Then
		// 
		//  
		//  
		If CurrentItem = Items.EmailTextFormattedDocument Then
			EmailTextFormattedDocument.Add(TextTemplate, FormattedDocumentItemType.Text);
		Else
			CurrentItem.SelectedText = TextTemplate;
		EndIf;
	Else
		CurrentItem.SelectedText = CurrentItem.SelectedText + TextTemplate;
	EndIf;
EndProcedure

&AtClient
Function ChangeArrayContent(Add, Item, Val Array)
	IndexOf = Array.Find(Item);
	If Add And IndexOf = Undefined Then
		UBoundPlus1 = ?(Array.Count() >= Item, Item, Array.Count());
		For IndexOf = 1 To UBoundPlus1 Do
			If Array[UBoundPlus1 - IndexOf] < Item Then
				Array.Insert(UBoundPlus1 - IndexOf + 1, Item);
				Return Array;
			EndIf;
		EndDo;
		Array.Insert(0, Item);
	ElsIf Not Add And IndexOf <> Undefined Then
		Array.Delete(IndexOf);
	EndIf;
	Return Array;
EndFunction

&AtClient
Procedure ChangeScheduleInDialog()
	Handler = New NotifyDescription("AfterChangeSchedule", ThisObject);
	ScheduleDialog1 = New ScheduledJobDialog(Schedule);
	ScheduleDialog1.Show(Handler);
EndProcedure

&AtClient
Procedure EvaluateAdditionalDeliveryMethodsCheckBoxes()
	Object.UseFolder        = Publish And (OtherDeliveryMethod = "UseFolder");
	Object.UseNetworkDirectory = Publish And (OtherDeliveryMethod = "UseNetworkDirectory");
	Object.UseFTPResource    = Publish And (OtherDeliveryMethod = "UseFTPResource");
EndProcedure

&AtClient
Procedure CheckMailing(DeliveryParameters)
	// Clear message window.
	ClearMessages();
	
	// Check the data readiness and the need for writing.
	If Not Object.IsPrepared Or Object.Ref.IsEmpty() Then
		QuestionTitle = NStr("en = 'Check delivery method';");
		If Not Object.IsPrepared Then
			QueryText = NStr("en = 'Prepare the distribution before check.
			|Click ""Continue"" to select the ""Prepared"" check box and save the distribution.';");
		Else
			QueryText = NStr("en = 'Save the distribution before check.
			|Click ""Continue"" to save the distribution.';");
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(1, NStr("en = 'Continue';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("CheckMailingAfterResponseToQuestion", ThisObject, DeliveryParameters);
		ShowQueryBox(Handler, QueryText, Buttons, 60, 1, QuestionTitle);
	Else
		CheckMailingAfterResponseToQuestion(-1, DeliveryParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCreateArchivePassword(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		ArchivePassword = CreatePassword();
		ArchivePasswordChanged = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDescriptionTemplates(TemplateName, MultipleChange = False)

	If MultipleChange Then
		SetDescriptionTemplatesForAllReports(TemplateName);
	Else
		Templates = DescriptionsTemplates();
		Items.ReportFormats.CurrentData.DescriptionTemplate1 = Templates.Get(TemplateName);
	EndIf;
	
	Modified = True;

	If TemplateName = "ReportDescription1" Or TemplateName = "ReportDescriptionFormat" Then
		Return;
	EndIf;

	Variables1 = ReportDescriptionTemplateChoiceVariables(TemplateName, MultipleChange);
	Handler = New NotifyDescription("AddChangeMailingDateTemplateCompletion", ThisObject, Variables1);

	Dialog = New FormatStringWizard;
	Dialog.AvailableTypes = New TypeDescription("Date");
	Dialog.Text         = Variables1.FormatText;
	Dialog.Show(Handler);

EndProcedure

&AtClient
Function ReportDescriptionTemplateChoiceVariables(TemplateName, MultipleChange)

	Variables1 = New Structure;
	Variables1.Insert("Item", Undefined);
	Variables1.Insert("PreviousText1", "");
	Variables1.Insert("Postfix", ")]");
	Variables1.Insert("FormatText", "");
	Variables1.Insert("PreviousFragmentFound", False);
	Variables1.Insert("ShouldChangeReportDescriptionTemplate", True);
	Variables1.Insert("ChangeReportDescriptionTemplateMultiply", MultipleChange);
	Variables1.Insert("TemplateName", TemplateName);

	If TemplateName = "DescriptionDistributionDate" Then

		Variables1.Insert("Prefix", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[ReportDescription1]", "[MailingDate("));

	ElsIf TemplateName = "DescriptionDistributionDateFormat" Then

		Variables1.Insert("Prefix", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[ReportDescription1]", "[MailingDate("));

		Variables1.Insert("Postfix", ")] [ReportFormat]");

	ElsIf TemplateName = "DescriptionPeriod" Then

		Variables1.Insert("Prefix", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 for %2';"), "[ReportDescription1]", "[Period("));

	ElsIf TemplateName = "DescriptionPeriodFormat" Then

		Variables1.Insert("Prefix", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 for %2';"), "[ReportDescription1]", "[Period("));
			
		Variables1.Insert("Postfix", ")] [ReportFormat]");
	EndIf;

	Return Variables1;

EndFunction

&AtClient
Procedure CheckEncryptionBeforeIncludeReportsToEmailBody()

	QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionParameters.PromptDontAskAgain = False;

	If Object.Personalized And Object.ShouldSetPasswordsAndEncrypt Then

		If CanEncryptAttachments Then
			If Object.Archive Then
				QuestionButtons = New ValueList;
				QuestionButtons.Add("DisableEncryptionPasswords", NStr("en = 'Insert reports into email body';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To insert reports into the email body, disable passwords and encryption.';");
				QuestionParameters.DefaultButton = "DisableEncryptionPasswords";
			Else
				QuestionButtons = New ValueList;
				QuestionButtons.Add("DisableEncryptionPasswords", NStr("en = 'Insert reports into email body';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To insert reports into the email body, disable encryption.';");
				QuestionParameters.DefaultButton = "DisableEncryption";
			EndIf;
		ElsIf Object.Archive Then
			QuestionButtons = New ValueList;
			QuestionButtons.Add("DisableEncryptionPasswords", NStr("en = 'Insert reports into email body';"));
			QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
			QueryText = NStr("en = 'To insert reports into the email body, disable passwords.';");
			QuestionParameters.DefaultButton = "DisablePasswords";
		EndIf;
		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);

	ElsIf Object.Personal Then

		If CanEncryptAttachments Then

			If Object.Archive And ValueIsFilled(ArchivePassword) And ValueIsFilled(ThisObject["CertificateToEncrypt"]) Then
				QuestionButtons = New ValueList;
				QuestionButtons.Add("DisablePasswordEncryption", NStr("en = 'Insert reports into email body';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To insert reports into the email body, disable the password and encryption.';");
				QuestionParameters.DefaultButton = "DisablePasswordEncryption";

				StandardSubsystemsClient.ShowQuestionToUser(
					New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject),
					QueryText, QuestionButtons, QuestionParameters);

			ElsIf Object.Archive And ValueIsFilled(ArchivePassword) Then
				QuestionButtons = New ValueList;
				QuestionButtons.Add("ClearUpPassword", NStr("en = 'Insert reports into email body';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr(
					"en = 'To insert reports into the email body, clear the archive password.';");
				QuestionParameters.DefaultButton = "ClearUpPassword";

				StandardSubsystemsClient.ShowQuestionToUser(
					New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject),
					QueryText, QuestionButtons, QuestionParameters);

			ElsIf ValueIsFilled(ThisObject["CertificateToEncrypt"]) Then
				QuestionButtons = New ValueList;
				QuestionButtons.Add("ClearCertificate", NStr("en = 'Insert reports into email body';"));
				QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
				QueryText = NStr("en = 'To insert reports into the email body, clear the encryption certificate field.';");
				QuestionParameters.DefaultButton = "ClearCertificate";

				StandardSubsystemsClient.ShowQuestionToUser(
					New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject),
					QueryText, QuestionButtons, QuestionParameters);
			EndIf;
		ElsIf Object.Archive And ValueIsFilled(ArchivePassword) Then
			QuestionButtons = New ValueList;
			QuestionButtons.Add("ClearUpPassword", NStr("en = 'Insert reports into email body';"));
			QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
			QueryText = NStr(
				"en = 'To insert reports into the email body, clear the archive password.';");
			QuestionParameters.DefaultButton = "ClearUpPassword";

			StandardSubsystemsClient.ShowQuestionToUser(
				New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject), QueryText,
				QuestionButtons, QuestionParameters);
		EndIf;

	ElsIf Not Object.Personalized And Not Object.Personal And Object.Archive And ValueIsFilled(ArchivePassword) Then
		QuestionButtons = New ValueList;
		QuestionButtons.Add("ClearUpPassword", NStr("en = 'Insert reports into email body';"));
		QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		QueryText = NStr(
			"en = 'To insert reports into the email body, clear the archive password.';");
		QuestionParameters.DefaultButton = "ClearUpPassword";

		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("AfterQuestionAnsweredReportsInEmailTextEncryption", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);
	EndIf;

EndProcedure

&AtClient
Procedure AfterQuestionAnsweredReportsInEmailTextEncryption(Result, Var_Parameters) Export

	If Result = Undefined Then
		Return;
	EndIf;

	If Result.Value = "DisableEncryptionPasswords" Then
		Object.ShouldSetPasswordsAndEncrypt = False;
		Items.PasswordsEncryption.Enabled = False;
	ElsIf Result.Value = "DisablePasswordEncryption" Then
		ArchivePassword = "";
		ThisObject["CertificateToEncrypt"] = "";
		ArchivePasswordChanged = True;
		EncryptionCertificateChanged = True;
	ElsIf Result.Value = "ClearUpPassword" Then
		ArchivePassword = "";
		ArchivePasswordChanged = True;
	ElsIf Result.Value = "ClearCertificate" Then
		ThisObject["CertificateToEncrypt"] = "";
		EncryptionCertificateChanged = True;
	ElsIf Result.Value = DialogReturnCode.Cancel Then
		Object.ShouldInsertReportsIntoEmailBody = False;
	EndIf;

EndProcedure

&AtClient
Procedure CheckOnSetArchivePasswordInsertReportsToEmailText()

	If ValueIsFilled(ArchivePassword) And Object.Archive And Object.ShouldInsertReportsIntoEmailBody 
		And Object.ShouldAttachReports Then
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.PromptDontAskAgain = False;
		
		QuestionButtons = New ValueList;
		QuestionButtons.Add("SetPassword", NStr("en = 'Set password';"));
		QuestionButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		QueryText = NStr(
			"en = 'To set a password, remove the reports from the email text.';");
		QuestionParameters.DefaultButton = "SetPassword";

		StandardSubsystemsClient.ShowQuestionToUser(
			New NotifyDescription("AfterAnswerQuestionPasswordEncryptionReportsInEmailText", ThisObject), QueryText,
			QuestionButtons, QuestionParameters);
	EndIf;

EndProcedure

&AtClient
Procedure AfterAnswerQuestionPasswordEncryptionReportsInEmailText(Result, Var_Parameters) Export

	If Result = Undefined Then
		Return;
	EndIf;

	If Result.Value = "SetPassword" Then
		Object.ShouldInsertReportsIntoEmailBody = False;
	ElsIf Result.Value = "AutoSetPassword" Then
		Object.ShouldInsertReportsIntoEmailBody = False;
		ArchivePassword = CreatePassword();
		ArchivePasswordChanged = True;
	ElsIf Result.Value = "InstallEncryptionCertificate" Then
		Object.ShouldInsertReportsIntoEmailBody = False;
	ElsIf Result.Value = DialogReturnCode.Cancel Then
		ArchivePassword = "";
		ArchivePasswordChanged = True;
		ThisObject["CertificateToEncrypt"] = "";
		EncryptionCertificateChanged = True;
	EndIf;

EndProcedure

&AtClient
Procedure SetPasswordsReportsInEmailBodyAfterQuestionAnswered(Result, Var_Parameters) Export

	If Result = Undefined Then
		Return;
	EndIf;

	If Result.Value = "ShouldSetPasswordsAndEncrypt" Then
		Object.ShouldInsertReportsIntoEmailBody = False;
		OpenFormPasswordsEncryption();
	ElsIf Result.Value = DialogReturnCode.Cancel Then
		Object.ShouldSetPasswordsAndEncrypt = False;
	EndIf;

EndProcedure

&AtClient
Procedure OpenFormPasswordsEncryption()

	FormParameters = New Structure;
	FormParameters.Insert("RecipientsAddress", PutRecipientsInStorage());
	FormParameters.Insert("Archive", Object.Archive);
	FormParameters.Insert("MailingRecipientType", MailingRecipientType);
	FormParameters.Insert("RecipientsEmailAddressKind", Object.RecipientsEmailAddressKind);
	FormParameters.Insert("Ref", Object.Ref);
	FormParameters.Insert("MailingDescription", Object.Description);
	OpenForm("Catalog.ReportMailings.Form.PasswordsEncryption", FormParameters, ThisObject, , , , ,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure


&AtClient
Procedure SetDescriptionTemplatesForAllReports(TemplateName, DescriptionTemplate1 = "")
	
	Templates = DescriptionsTemplates();
	
	IsPeriodUsed = TemplateName = "DescriptionPeriod" Or TemplateName = "DescriptionPeriodFormat";
	For Each RowReport In Object.Reports Do
		If IsPeriodUsed Then
			RowID = RowReport.GetID();
			If Not RowReport.ThereIsPeriod Then
				RowReport.DescriptionTemplate1 = Templates.Get("ReportDescriptionFormat");
				Continue;
			EndIf;
		EndIf;
		If ValueIsFilled(DescriptionTemplate1) Then
			RowReport.DescriptionTemplate1 = DescriptionTemplate1;
		Else
			RowReport.DescriptionTemplate1 = Templates.Get(TemplateName);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function DescriptionsTemplates()

	Templates = New Map;
	Templates.Insert("ReportDescription1", "[ReportDescription1]");
	Templates.Insert("ReportDescriptionFormat", "[ReportDescription1] [ReportFormat]");
	Templates.Insert("DescriptionPeriod", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 for %2';"), "[ReportDescription1]", "[Period()]"));
	Templates.Insert("DescriptionPeriodFormat", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 for %2 %3';"), "[ReportDescription1]", "[Period()]", "[ReportFormat]"));
	Templates.Insert("DescriptionDistributionDate", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2';"), "[ReportDescription1]", "[MailingDate()]"));
	Templates.Insert("DescriptionDistributionDateFormat", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 dated %2 %3';"), "[ReportDescription1]", "[MailingDate()]", "[ReportFormat]"));

	Return Templates;

EndFunction

&AtClient
Procedure AfterCloseRedistribution(Result, Var_Parameters) Export
	
	Read();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClientAtServerNoContext
Function PasswordHidden()
	Return "********";
EndFunction

&AtClientAtServerNoContext
Procedure VisibilityAvailabilityCorrectness(Form, Changes = "")
	Object = Form.Object;
	Items = Form.Items;
	
	If Changes = "" Or Changes = "FTPServerAndDirectory" Then
		If ValueIsFilled(Object.FTPServer) Then
			AddressPresentation = "ftp://";
			If ValueIsFilled(Object.FTPLogin) Then
				AddressPresentation = AddressPresentation + Object.FTPLogin + ?(ValueIsFilled(Form.FTPPassword), ":" + PasswordHidden(), "") + "@";
			EndIf;
			Form.FTPServerAndDirectory = AddressPresentation + Object.FTPServer + ":" + Format(Object.FTPPort, "NZ=0; NG=0") + Object.FTPDirectory;
		Else
			Form.FTPServerAndDirectory = "";
		EndIf;
	EndIf;
	
	If Changes = ""
		Or Changes = "IsPrepared"
		Or Changes = "ExecuteOnSchedule"
		Or Changes = "BulkEmailType"
		Or Changes = "Publish"
		Or Changes = "UseEmail" Then
		
		Items.Reports.AutoMarkIncomplete         = Object.IsPrepared;
		Items.ReportFormats.AutoMarkIncomplete = Object.IsPrepared;
		
		Items.SchedulePeriodicity.AutoMarkIncomplete = Object.IsPrepared And Object.ExecuteOnSchedule;
		
		Items.NetworkDirectoryWindows.AutoMarkIncomplete = Object.IsPrepared And Form.Publish;
		Items.NetworkDirectoryLinux.AutoMarkIncomplete   = Object.IsPrepared And Form.Publish;
		Items.FTPServerAndDirectory.AutoMarkIncomplete     = Object.IsPrepared And Form.Publish;
		Items.Folder.AutoMarkIncomplete                 = Object.IsPrepared And Form.Publish;
		
		Items.AuthorMailAddressKind.AutoMarkIncomplete = Object.IsPrepared And Object.Personal;
		Items.Account.AutoMarkIncomplete = Object.IsPrepared And Object.UseEmail;
		
	EndIf;
	
	If Changes = "" Or Changes = "BulkEmailType" Then
		// Valid.
		If Object.Personal And Object.Personalized Then
			Object.Personal = False;
		EndIf;
		
		GroupIncludedIntoPersonalDistributionHierarchy = IsMemberOfPersonalReportGroup(Object.Parent);
		If Object.Personal <> GroupIncludedIntoPersonalDistributionHierarchy Then
			SetFormModified(Form, "Parent", , 
				NStr("en = 'The group applied complies with the distribution type.';"));
			Object.Parent = ?(Object.Personal, Form.Cache.PersonalMailingsGroup, Undefined);
		EndIf;
		
		If Object.Personal Then
			CommonMailing = False;
			Form.BulkEmailType = "Personal";
		ElsIf Object.Personalized Then
			CommonMailing = False;
			Form.BulkEmailType = "Personalized";
		Else
			CommonMailing = True;
			Form.BulkEmailType = "Shared3";
		EndIf;
		
		If Not CommonMailing Then
			Object.UseFolder            = False;
			Object.UseNetworkDirectory   = False;
			Object.UseFTPResource        = False;
			Object.UseEmail = True;
		EndIf;
		
		// 
		Items.BulkEmailTypes.CurrentPage = ?(Object.Personal, Items.BulkEmailTypesPersonal, 
			Items.BulkEmailTypesForRecipients);
		Items.OtherDeliveryMethods.Visible = CommonMailing;
		Items.UseEmail.Visible = CommonMailing;
		
		If Object.Personal Then
			Items.BulkEmailRecipients.Visible = False;
		Else
			Items.BulkEmailRecipients.Visible = True;
			If Not CommonMailing Then
				Items.BulkEmailRecipients.TitleLocation = FormItemTitleLocation.Auto;
			Else
				Items.BulkEmailRecipients.TitleLocation = FormItemTitleLocation.None;
			EndIf;
		EndIf;
		
		// Restore parameters.
		If Object.UseFolder Then
			Form.OtherDeliveryMethod = "UseFolder";
			Form.Publish = True;
		ElsIf Object.UseNetworkDirectory Then
			Form.OtherDeliveryMethod = "UseNetworkDirectory";
			Form.Publish = True;
		ElsIf Object.UseFTPResource Then
			Form.OtherDeliveryMethod = "UseFTPResource";
			Form.Publish = True;
		Else
			Form.OtherDeliveryMethod = Items.OtherDeliveryMethod.ChoiceList[0].Value;
			Form.Publish = False;
		EndIf;
		
		Items.UseMailingRecipientInReport1Setting.Visible = Object.Personalized;
		Items.UseMailingRecipientInReport2Setting.Visible = Object.Personalized;
		Items.UseMailingRecipientInReport3Setting.Visible = Object.Personalized;
		Items.UseMailingRecipientInReport4Setting.Visible = Object.Personalized;
		
		VisibilityAvailabilityOfCertificatesPasswords(Form);
	EndIf;
	
	If Changes = "" Or Changes = "Reports" Then
		ReportCount = Form.Object.Reports.Count();
		If ReportCount > 0 Then
			Items.ReportsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Reports (%1)';"), 
				Format(ReportCount, "NZ=0; NG="));
		Else
			Items.ReportsPage.Title = NStr("en = 'Reports';") ;
		EndIf;
	EndIf;
	
	If Changes = "" Or Changes = "OtherDeliveryMethod" Or Changes = "Publish" Or Changes = "BulkEmailType" Then
		Items.OtherDeliveryMethod.Enabled  = Form.Publish;
		Items.DeliveryParameters.Enabled     = Form.Publish;
		Items.DeliveryParameters.CurrentPage = Items[Form.OtherDeliveryMethod];
		
		Items.Folder.Visible = (Items.DeliveryParameters.CurrentPage = Items.UseFolder);
		Items.NetworkDirectoryWindows.Visible = (Items.DeliveryParameters.CurrentPage = Items.UseNetworkDirectory);
		Items.NetworkDirectoryLinux.Visible = (Items.DeliveryParameters.CurrentPage = Items.UseNetworkDirectory);
		Items.FTPServerAndDirectory.Visible = (Items.DeliveryParameters.CurrentPage = Items.UseFTPResource);
	EndIf;
	
	If Changes = "" Or Changes = "UseEmail" Or Changes = "BulkEmailType" Then
		Items.AccountGroup.Enabled = Object.UseEmail;
		Items.EmailParameters.Enabled = Object.UseEmail;
		Items.AdditionalParametersOfMailing.Enabled = Object.UseEmail;
		Items.BulkEmailRecipients.Enabled = Object.UseEmail;
		Items.ShouldAttachReports.Enabled = Object.UseEmail;
	EndIf;
	
	If Changes = "" Or Changes = "UseEmail" Or Changes = "BulkEmailType"
		Or Changes = "ShouldAttachReports" Or Changes = "Publish" Or Changes = "NotifyOnly" Then
		Items.ReportsFilesSettings.Enabled = Object.ShouldAttachReports Or Form.Publish;
	EndIf;
	
	If Changes = "" Or Changes = "BulkEmailRecipients" Then
		If Form.BulkEmailType <> "Personal" Then
			RecipientsPresentation1 = RecipientsPresentation1(Form);
			Form.BulkEmailRecipients = RecipientsPresentation1.Short;
		EndIf;
	EndIf;
	
	If Changes = ""
		Or Changes = "NotifyOnly"
		Or Changes = "UseEmail"
		Or Changes = "OtherDeliveryMethod"
		Or Changes = "Publish"
		Or Changes = "BulkEmailType" Then
		
		Items.NotifyOnly.Visible = (Object.UseEmail And Form.Publish);
		If Not Items.NotifyOnly.Visible Then
			Object.NotifyOnly = False;
		EndIf;
		
		TransportMethods = "";
		If Object.UseFolder Then
			TransportMethods = NStr("en = 'folder';");
		EndIf;
		If Object.UseNetworkDirectory Then
			TransportMethods = NStr("en = 'network directory';");
		EndIf;
		If Object.UseFTPResource Then
			TransportMethods = NStr("en = 'FTP';");
		EndIf;
		If Object.UseEmail And Not Object.NotifyOnly Then
			TransportMethods = TransportMethods + ?(TransportMethods = "", NStr("en = 'email';"), " "+ NStr("en = 'and email';"));
		EndIf;
		
		Items.DeliveryPage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Delivery (%1)';"), TransportMethods);
	EndIf;
	
	If IsBlankString(Changes) Or StrCompare(Changes, "HTMLFormatEmail") = 0 Then
		
		Items.EmailTextPages.CurrentPage = ?(Object.HTMLFormatEmail,
			Items.EmailTextPagesHTML, Items.EmailTextPagesNormalText);
		
	EndIf;
	
	If Changes = "" Or Changes = "Archive" Then
		Items.ArchiveName.Enabled           = Object.Archive;
		Items.ArchivePassword.Enabled        = Object.Archive;
		Items.CreateArchivePassword.Enabled = Object.Archive;
		VisibilityAvailabilityOfCertificatesPasswords(Form);
	EndIf;
	
	If Changes = "" Or Changes = "ExecuteOnSchedule" Then
		If Object.ExecuteOnSchedule Then
			Items.SchedulePage.Title = NStr("en = 'Schedule (active)';");
		Else
			Items.SchedulePage.Title = NStr("en = 'Schedule (not active)';");
		EndIf;
		Items.ExecuteOnScheduleParameters.Enabled = Object.ExecuteOnSchedule;
		Items.PeriodicityPages.Enabled           = Object.ExecuteOnSchedule;
	EndIf;
	
	If Changes = "" Or Changes = "SchedulePeriodicity" Then
		
		If Object.SchedulePeriodicity = PredefinedValue("Enum.ReportMailingSchedulePeriodicities.Daily") Then
			EnumerationName = "Daily";
		ElsIf Object.SchedulePeriodicity = PredefinedValue("Enum.ReportMailingSchedulePeriodicities.Monthly") Then
			EnumerationName = "Monthly";
		ElsIf Object.SchedulePeriodicity = PredefinedValue("Enum.ReportMailingSchedulePeriodicities.Weekly") Then
			EnumerationName = "Weekly";
		Else
			EnumerationName = "CustomValue";
		EndIf;
		
		Pages = Items.PeriodicityPages.ChildItems;
		VisiblePagesName = "Page"+EnumerationName;
		For Each Page In Pages Do
			Page.Visible = (Page.Name = VisiblePagesName);
		EndDo;
		If EnumerationName = "CustomValue" Then
			Items.TimeOrChangePages.CurrentPage = Items.ChangeSchedulePage;
		Else
			Items.TimeOrChangePages.CurrentPage = Items.BeginTimePage;
		EndIf;
		
		// Reset parameters that do not match simplified editing bookmarks.
		If Changes = "SchedulePeriodicity"
			And (EnumerationName = "Daily" 
			Or EnumerationName = "Weekly"
			Or EnumerationName = "Monthly") Then
			
			// 
			Form.Schedule.StartDate = '00010101';
			Form.Schedule.EndDate  = '00010101';
			Form.Schedule.EndTime = '00010101';
			Form.Schedule.CompletionTime = '00010101';
			Form.Schedule.WeekDayInMonth = 0;
			Form.Schedule.DetailedDailySchedules = New Array;
			Form.Schedule.CompletionInterval = 0;
			Form.Schedule.RepeatPause = 0;
			Form.Schedule.WeeksPeriod = 0;
			Form.Schedule.RepeatPeriodInDay = 0;
			
			If EnumerationName <> "Daily" Then
				Form.Schedule.DaysRepeatPeriod = 1;
			EndIf;
			
			If EnumerationName <> "Weekly" Then
				SelectedWeekDays = New Array;
				For IndexOf = 1 To 7 Do
					SelectedWeekDays.Add(IndexOf);
				EndDo;
				Form.Schedule.WeekDays = SelectedWeekDays;
			EndIf;
			
			If EnumerationName <> "Monthly" Then
				AllMonths = New Array;
				For IndexOf = 1 To 12 Do
					AllMonths.Add(IndexOf);
				EndDo;
				Form.Schedule.Months = AllMonths;
				Form.Schedule.DayInMonth = 0;
			EndIf;
		EndIf;
		
		// Restoring parameters on the current bookmark according to schedule parameters.
		If EnumerationName = "Daily" Then
			Form.BeginTime = Form.Schedule.BeginTime;
			Form.DaysRepeatPeriod = Form.Schedule.DaysRepeatPeriod;
		ElsIf EnumerationName = "Weekly" Then
			Form.BeginTime = Form.Schedule.BeginTime;
			For Each KeyAndValue In Form.Cache.Maps1.WeekDays Do
				Form[KeyAndValue.Key] = (Form.Schedule.WeekDays.Find(KeyAndValue.Value) <> Undefined);
			EndDo;
		ElsIf EnumerationName = "Monthly" Then
			Form.BeginTime = Form.Schedule.BeginTime;
			If Form.Schedule.DayInMonth >= 0 Then
				Form.DayInMonth = Form.Schedule.DayInMonth;
				Items.BegEndOfMonthHyperlink.Title = NStr("en = 'beginning';");
			Else
				Form.DayInMonth = -Form.Schedule.DayInMonth;
				Items.BegEndOfMonthHyperlink.Title = NStr("en = 'end';");
			EndIf;
			For Each KeyAndValue In Form.Cache.Maps1.Months Do
				Form[KeyAndValue.Key] = (Form.Schedule.Months.Find(KeyAndValue.Value) <> Undefined);
			EndDo;
		EndIf;
		
	EndIf; // Changes = Or Changes = SchedulePeriodicity
	
	If Changes = "" Or Changes = "MonthBeginEnd" Then
		Items.BegEndOfMonthHyperlink.Title = ?(Form.Schedule.DayInMonth >= 0, "beginning", "end");
	EndIf;
	
	If Changes = "" Or Changes = "DefaultFormats" Then
		Items.ResetDefaultFormat.Visible = (Form.DefaultFormats <> Form.DefaultFormatsListPresentation);
	EndIf;
	
	If Changes = "" Or Items.Pages.CurrentPage = Items.SchedulePage Then
		Items.SchedulePresentation.Visible = Object.ExecuteOnSchedule;
		If Object.ExecuteOnSchedule Then
			Items.SchedulePresentation.Title = SchedulePresentation(Form.Schedule);
		EndIf;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure VisibilityAvailabilityOfCertificatesPasswords(Form)
	Object = Form.Object;
	Items = Form.Items;

	If Form.CanEncryptAttachments Then
		If Object.Personalized Then
			Items["GroupEncryptionCertificates"].Visible = False;
			If Object.Archive Then
				Items.PasswordsEncryption.Title = NStr("en = 'Set passwords and encrypt data';");
			Else
				Items.PasswordsEncryption.Title = NStr("en = 'Encrypt data';");
			EndIf;
			Items.GroupPasswordsEncryption.Visible = True;
			Items.GroupArchivePassword.Visible = False;
			Items.PasswordsEncryption.Enabled = Object.ShouldSetPasswordsAndEncrypt;
			Items.PasswordsEncryption.ToolTipRepresentation = ToolTipRepresentation.Button;
			Items.PasswordsEncryption.ExtendedTooltip.Title = NStr("en = 'Set and configure passwords and encryption.
				|When distributing reports by email, keep in mind that
				|some mail servers might not accept encrypted files.';");
			Items.ShouldSetPasswordsAndEncrypt.Enabled = True;
		Else
			Items["GroupEncryptionCertificates"].Visible = ?(Form.Object.Personal, True, False);
			Items.GroupArchivePassword.Visible = True;
			Items.GroupPasswordsEncryption.Visible = False;
		EndIf;
	Else
		If Object.Personalized Then
			Items.PasswordsEncryption.Title = NStr("en = 'Set passwords';");
			Items.GroupPasswordsEncryption.Visible   = True;
			Items.GroupArchivePassword.Visible = False;
			Items.PasswordsEncryption.Enabled = Object.Archive And Object.ShouldSetPasswordsAndEncrypt;
			Items.PasswordsEncryption.ToolTipRepresentation = ToolTipRepresentation.Auto;
			Items.PasswordsEncryption.ExtendedTooltip.Title = NStr("en = 'Set and configure passwords.';");
			Items.ShouldSetPasswordsAndEncrypt.Enabled = Object.Archive;
		Else
			Items.GroupArchivePassword.Visible = True;
			Items.GroupPasswordsEncryption.Visible = False;
			If Items.Find("GroupEncryptionCertificates") <> Undefined Then
				Items["GroupEncryptionCertificates"].Visible = False;
			EndIf;
		EndIf;
	EndIf;

EndProcedure

// Generates the presentation of scheduled job schedule.
//
// Parameters:
//   Schedule - JobSchedule - a schedule.
//
// Returns:
//   String - 
//
&AtClientAtServerNoContext
Function SchedulePresentation(Schedule)
	SchedulePresentation = String(Schedule);
	SchedulePresentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
	SchedulePresentation = StrReplace(StrReplace(SchedulePresentation, "  ", " "), " ]", "]") + ".";
	If ValueIsFilled(Schedule.BeginTime) Or ValueIsFilled(Schedule.EndTime) Then
		AddOn = AdditionOfSaaSSchedulePresentation();
		SchedulePresentation = ?(ValueIsFilled(AddOn), SchedulePresentation + Chars.LF + AddOn,
			SchedulePresentation);
	EndIf;
	Return SchedulePresentation;
EndFunction

&AtClientAtServerNoContext
Function RecipientsPresentation1(Form)
	Recipients  = Form.Object.Recipients;
	Included_SSLy  = Recipients.FindRows(New Structure("Excluded", False));
	Disabled1 = Recipients.FindRows(New Structure("Excluded", True));
	
	DisabledPresentation = ReportMailingClientServer.ListPresentation(Disabled1, "Recipient", 0);
	Balance       = 75 - DisabledPresentation.LengthOfShort;
	Presentation = ReportMailingClientServer.ListPresentation(Included_SSLy, "Recipient", Balance);
	
	NumberOfRecipients = RecipientsCountIncludingGroups(Form.Object.Recipients,
		Form.Object.MailingRecipientType);
	
	If NumberOfRecipients.Total = 0 Then
		Presentation.Short = NStr("en = '<Specify recipients>';");
		Return Presentation;
	EndIf;
	
	If DisabledPresentation.MaximumExceeded Then
		DisabledPresentation.Short = DisabledPresentation.Short + ", ...";
	EndIf;
	If Presentation.MaximumExceeded Then
		Presentation.Short = Presentation.Short + ", ...";
	EndIf;
	
	If NumberOfRecipients.ExcludedCount > 0 Then
		SplitTemplate = NStr("en = 'Except';")+ ": ";
		Presentation.Full = Presentation.Full + ";" + Chars.LF + SplitTemplate + DisabledPresentation.Full;
		If Presentation.LengthOfShort + DisabledPresentation.LengthOfShort <= 75 Then
			Presentation.Short = Presentation.Short + "; " + SplitTemplate + DisabledPresentation.Short;
		EndIf;
	EndIf;
	If Presentation.MaximumExceeded
		Or DisabledPresentation.MaximumExceeded Then
		If NumberOfRecipients.ExcludedCount > 0 Then
			EndTemplate = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '(total %1 not including %2)';"),
				NumberOfRecipients.Total,
				NumberOfRecipients.ExcludedCount);
		Else
			EndTemplate = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '(total %1)';"),
				NumberOfRecipients.Total);
		EndIf;
		Presentation.Short = Presentation.Short + "; " + EndTemplate;
	EndIf;
	
	Return Presentation;
EndFunction

&AtServerNoContext
Function RecipientsCountIncludingGroups(Val Recipients, Val MetadataObjectID)

	Return Catalogs.ReportMailings.RecipientsCountIncludingGroups(Recipients, MetadataObjectID);

EndFunction

&AtClientAtServerNoContext
Procedure SetFormModified(Form, Field = "", DataPath = "", Text = "")
	If Not Form.Modified Then
		Form.FormWasModifiedAtServer = True;
		If ValueIsFilled(Text) Then
			Message = New UserMessage;
			Message.Text = Text;
			Message.Field = Field;
			Message.DataPath = DataPath;
			Message.Message();
		EndIf;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function DefaultFormatsPresentation()
	Return NStr("en = 'default';");
EndFunction

&AtClientAtServerNoContext
Function RecipientsSpecified(Recipients)
	
	For Each TableRow In Recipients Do
		If Not TableRow.Excluded Then
			Return True;
		EndIf;
	EndDo;
	
	MessageText = NStr("en = 'No recipient is selected.';");
	
	Message = New UserMessage;
	Message.Text = MessageText;
	Message.Field = "BulkEmailRecipients";
	Message.Message();
	
	Return False;
	
EndFunction

&AtClientAtServerNoContext
Function MailingRecipientValueTemplate()
	
	Return NStr("en = '[Recipient]';");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtServerNoContext
Function RecipientMailAddresses(Recipient, ValueList)
	
	Recipients = New Array;
	Recipients.Add(Recipient);
	ContactInformationTypes = New Array;
	ContactInformationTypes.Add(Enums.ContactInformationTypes.Email);
	Try
		MailAddresses = ContactsManager.ObjectsContactInformation(Recipients, ContactInformationTypes,, CurrentSessionDate());
	Except
		Return ValueList;
	EndTry;
	
	EmailAddressesByKinds = New Map;
	For Each MailAddress In MailAddresses Do
		If Not ValueIsFilled(MailAddress.Presentation) Then 
			Continue;
		EndIf;
		EmailAddressesOfKind = EmailAddressesByKinds.Get(MailAddress.Kind);
		If EmailAddressesOfKind = Undefined Then
			EmailAddressesByKinds.Insert(MailAddress.Kind, MailAddress.Presentation);
		Else
			EmailAddressesByKinds[MailAddress.Kind]= EmailAddressesOfKind + ", " + MailAddress.Presentation;
		EndIf;
	EndDo;
	
	For Each Kind In EmailAddressesByKinds Do
		ValueList.Add(Kind.Key, Kind.Value + " (" + String(Kind.Key) + ")");
	EndDo;
	
	Return ValueList;
	
EndFunction

&AtServerNoContext
Function ChangeFolderAndFilesRight(Folder)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		Result = ModuleFilesOperationsInternal.RightToAddFilesToFolder(Folder);
	Else
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function CreatePassword()
	
	PasswordProperties = Users.PasswordProperties();
	PasswordProperties.MinLength = 8;
	PasswordProperties.Complicated = True;
	PasswordProperties.ConsiderSettings = "ForUsers";
	
	Return Users.CreatePassword(PasswordProperties);
	
EndFunction

&AtServerNoContext
Function AdditionOfSaaSSchedulePresentation()
	
	If Common.DataSeparationEnabled() Then
		Return NStr("en = 'The exact start time might differ from the specified one.';");
	Else
		Return "";
	EndIf;
	
EndFunction

&AtServer
Function ReportsOnActivateRowAtServer(RowID, AddCommonText = True, Val UserSettings = Undefined)
	// Save previous report settings.
	If RowID <> CurrentRowIDOfReportsTable And CurrentRowIDOfReportsTable <> -1 Then
		WriteReportsRowSettings(CurrentRowIDOfReportsTable);
	EndIf;
	CurrentRowIDOfReportsTable = RowID;
	
	// Row search.
	ReportsRow = Object.Reports.FindByID(RowID);
	If ReportsRow = Undefined Then
		CurrentRowIDOfReportsTable = -1;
		Return "";
	EndIf;
	
	If UserSettings = Undefined Then
		// Read current row settings from temporary storage or tabular section by reference.
		If IsTempStorageURL(ReportsRow.SettingsAddress) Then
			UserSettings = GetFromTempStorage(ReportsRow.SettingsAddress);
		Else
			RowIndex = Object.Reports.IndexOf(ReportsRow);
			ReportsRowObject = FormAttributeToValue("Object").Reports.Get(RowIndex);
			UserSettings = ?(ReportsRowObject = Undefined, Undefined, ReportsRowObject.Settings.Get());
		EndIf;
	EndIf;
	
	If Not ReportsRow.Enabled Then
		Items.ReportSettingsPages.CurrentPage = Items.PageEmpty;
		Return "";
	EndIf;
	
	// Initialization.
	ReportParameters = InitializeReport(ReportsRow, AddCommonText, UserSettings);
	
	FindPersonalizationSettings();
	
	Return ReportParameters.Errors;
EndFunction

&AtServer
Procedure FindPersonalizationSettings()
	
	PersonalizationSettings.Clear();
	
	Settings = DCSettingsComposer.UserSettings.Items;
	
	For Each SettingItem In Settings Do 
		
		SettingValue = Undefined;
		
		If TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
			
			SettingValue = SettingItem.RightValue;
			
		ElsIf TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
			
			SettingValue = SettingItem.Value;
		Else
			Continue;
		EndIf;
		
		If SettingValue <> MailingRecipientValueTemplate() Then 
			Continue;
		EndIf;
		
		TitleSettings = TitlePersonalizationSettings(SettingItem.UserSettingID);
		
		If TitleSettings <> Undefined Then 
			PersonalizationSettings.Add(TitleSettings);
		EndIf;
		
	EndDo;
	
	SetUpPersonalizationSettings();
	
EndProcedure

&AtServer
Function TitlePersonalizationSettings(SettingID)
	
	TitleSettings = Undefined;
	SettingDetails = Undefined;
	
	Settings = DCSettingsComposer.Settings;
	UserSettings = DCSettingsComposer.UserSettings;
	
	FoundSettings = UserSettings.GetMainSettingsByUserSettingID(
		SettingID);
	
	If FoundSettings.Count() = 0 Then 
		Return TitleSettings;
	EndIf;
	
	SettingItem = FoundSettings[0];
	
	If TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
		
		TitleSettings = String(SettingItem.LeftValue);
		
		SettingDetails = Settings.Filter.FilterAvailableFields.FindField(
			SettingItem.LeftValue);
		
	ElsIf TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		
		TitleSettings = String(SettingItem.Parameter);
		
		SettingDetails = Settings.DataParameters.AvailableParameters.FindParameter(
			SettingItem.Parameter);
		
	EndIf;
	
	If SettingDetails <> Undefined Then 
		TitleSettings = SettingDetails.Title;
	EndIf;
	
	Return TitleSettings;
	
EndFunction

&AtServer
Procedure FillScheduleByOption(Variant, RefreshVisibility = False)
	
	Schedule = New JobSchedule;
	Schedule.BeginTime = '00010101073000'; // 
	Schedule.DaysRepeatPeriod = 1; // Every day.

	// On weekly basis.
	WeekDayMin = 1;
	WeekDayMax = 7;
	
	// On monthly basis.
	AllMonths = New Array;
	For IndexOf = 1 To 12 Do
		AllMonths.Add(IndexOf);
	EndDo;
	Schedule.Months = AllMonths;
	
	Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Daily;
	If Variant = 2 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Daily;
		Schedule.DaysRepeatPeriod = 2;
		
	ElsIf Variant = 3 Then // 
		Schedule.DaysRepeatPeriod = 4;
		
	ElsIf Variant = 4 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Weekly;
		WeekDayMin = 1;
		WeekDayMax = 5;
		
	ElsIf Variant = 5 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Weekly;
		Schedule.BeginTime = '00010101220000'; // at 10:00 pm
		WeekDayMin = 6;
		WeekDayMax = 7;
		
	ElsIf Variant = 6 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Weekly;
		WeekDayMin = 1;
		WeekDayMax = 1;
		
	ElsIf Variant = 7 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Weekly;
		WeekDayMin = 5;
		WeekDayMax = 5;
		
	ElsIf Variant = 8 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Weekly;
		Schedule.BeginTime = '00010101220000'; // at 10:00 pm
		WeekDayMin = 7;
		WeekDayMax = 7;
		
	ElsIf Variant = 9 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Monthly;
		Schedule.DayInMonth = 1;
		
	ElsIf Variant = 10 Then // 
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Monthly;
		Schedule.DayInMonth = -1;
		
	ElsIf Variant = 11 Then // 
		AllMonths = New Array;
		AllMonths.Add(1);
		AllMonths.Add(4);
		AllMonths.Add(7);
		AllMonths.Add(10);
		Schedule.Months = AllMonths;
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.Monthly;
		Schedule.DayInMonth = 10;
		
	ElsIf Variant = 12 Then // "Другое..."
		Object.SchedulePeriodicity = Enums.ReportMailingSchedulePeriodicities.CustomValue;
	EndIf;
	
	// On weekly basis.
	SelectedWeekDays = New Array;
	For IndexOf = WeekDayMin To WeekDayMax Do
		SelectedWeekDays.Add(IndexOf);
	EndDo;
	Schedule.WeekDays = SelectedWeekDays;
	
	If RefreshVisibility Then
		VisibilityAvailabilityCorrectness(ThisObject);
	EndIf;
EndProcedure

// Checks the selected report.
// 
// Parameters:
//   ChoiceStructure - Structure:
//     * SelectedItemsCount   - Structure - rows selected by the user.
//     * Success   - Structure - rows initialized and added to the list.
//     * WithErrors - Structure - rows not added to the list due to errors:
//         ** RowsArray - Array - an array of rows IDs.
//         ** Count - Number - a number of strings.
//         ** ReportsPresentations - String - presentation of all reports of the specified rows.
//         ** Text - String - an error text.
//
&AtServer
Procedure CheckAddedReportRows(ChoiceStructure)
	ErrorsArray = New Array;
	
	ChoiceStructure.SelectedItemsCount.Count = ChoiceStructure.SelectedItemsCount.RowsArray.Count();
	For ReverseIndex = 1 To ChoiceStructure.SelectedItemsCount.Count Do
		IndexOf = ChoiceStructure.SelectedItemsCount.Count - ReverseIndex;
		ReportsRowID = ChoiceStructure.SelectedItemsCount.RowsArray[IndexOf];
		
		ReportsRow = Object.Reports.FindByID(ReportsRowID);
		If ReportsRow.Presentation = "" Then
			ReportsRow.Presentation = String(ReportsRow.Report);
		EndIf;
		
		WarningString = ReportsOnActivateRowAtServer(ReportsRowID, False);
		If WarningString = "" Then
			Var_Key = "Success";
		Else
			Var_Key = "WithErrors";
			ErrorsArray.Add(WarningString);
		EndIf;
		
		Rows = ChoiceStructure[Var_Key].RowsArray; // Array
		Rows.Add(ReportsRowID);
		
		ChoiceStructure[Var_Key].RowsArray = Rows;
		ChoiceStructure[Var_Key].Count = ChoiceStructure[Var_Key].Count + 1;
		ChoiceStructure[Var_Key].ReportsPresentations = ChoiceStructure[Var_Key].ReportsPresentations
			+ ?(ChoiceStructure[Var_Key].ReportsPresentations = "", "", ", ")
			+ ReportsRow.Presentation;
	EndDo;
	
	// Set cursor position on the first of the added items.
	If ChoiceStructure.Success.Count > 0 Then
		Items.Reports.CurrentRow = ChoiceStructure.Success.RowsArray[0];
		CurrentRowIDOfReportsTable = Items.Reports.CurrentRow;
		ReportsOnActivateRowAtServer(ReportsRowID, False);
	EndIf;
	
	// Error text assembly.
	If ChoiceStructure.WithErrors.Count > 0 Then
		ChoiceStructure.WithErrors.Text = ReportMailing.MessagesToUserString(ErrorsArray);
	EndIf;
EndProcedure

&AtServer
Function CheckTransportMethod(BulkEmail, Val DeliveryParameters)
	
	DeliveryParameters.ExecutionDate = CurrentSessionDate();
	DeliveryParameters.TestMode = True;
	
	// Initialize record parameters to the event log.
	SetPrivilegedMode(True);
	
	LogParameters = New Structure;
	LogParameters.Insert("EventName",   NStr("en = 'Report distribution. Testing delivery method';", Common.DefaultLanguageCode()));
	LogParameters.Insert("Data",       BulkEmail);
	LogParameters.Insert("Metadata",   Metadata.Catalogs.ReportMailings);
	LogParameters.Insert("ErrorsArray", New Array);
	
	SetPrivilegedMode(False);
	
	// 
	FullFileName = GetTempFileName(".html");
	
	TabDoc = New SpreadsheetDocument;
	TabDoc.Write(FullFileName, SpreadsheetDocumentFileType.HTML5);
	
	// Generate attachments.
	File = New File(FullFileName);
	
	Attachments = New Map;
	Attachments.Insert(File.Name, File.FullName);
	
	// Delivery
	BeginTransaction(); // 
	Try
		ReportMailing.ExecuteDelivery(LogParameters, DeliveryParameters, Attachments);
		RollbackTransaction(); // After the end of the test, all changes in the base are rolled back.
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// Clean up attachments.
	For Each Attachment In Attachments Do
		DeleteFiles(Attachment.Value);
	EndDo;
	
	DeleteFiles(FullFileName);
	
	ExecutionResult = New Structure("Text, More", "", "");
	
	If LogParameters.ErrorsArray.Count() = 0 Then 
		ExecutionResult.Text = NStr("en = 'Delivery verification completed successfully.';");
	Else
		ExecutionResult.Text = NStr("en = 'Delivery verification failed.';");
		ExecutionResult.More = ReportMailing.MessagesToUserString(LogParameters.ErrorsArray, False);
	EndIf;
	
	Return ExecutionResult;
EndFunction

&AtServer
Function PutRecipientsInStorage()
	Return PutToTempStorage(Object.Recipients.Unload(), UUID);
EndFunction

&AtServer
Function HasPeriodInSettings(RowID)

	ReportsRow = Object.Reports.FindByID(RowID);
	If ReportsRow = Undefined Then
		Return False;
	EndIf;
	
	If IsTempStorageURL(ReportsRow.SettingsAddress) Then
		UserSettings = GetFromTempStorage(ReportsRow.SettingsAddress);
	Else
		RowIndex = Object.Reports.IndexOf(ReportsRow);
		ReportsRowObject = FormAttributeToValue("Object").Reports.Get(RowIndex);
		UserSettings = ?(ReportsRowObject = Undefined, Undefined, ReportsRowObject.Settings.Get());
	EndIf;  
	
	If UserSettings = Undefined Then
		ReportParameters = New Structure("Report, Settings", ReportsRow.Report, Undefined);
		LogParameters = New Structure;
		LogParameters.Insert("EventName",   NStr("en = 'Report distribution. Report initialization';", Common.DefaultLanguageCode()));
		LogParameters.Insert("Data",       ?(ValueIsFilled(Object.Ref), Object.Ref, ReportsRow.Report));
		LogParameters.Insert("Metadata",   Metadata.Catalogs.ReportMailings);
		LogParameters.Insert("ErrorsArray", New Array);

		ReportMailing.InitializeReport(
			LogParameters,
			ReportParameters,
			Object.Personalized,
			UUID);
		If ReportParameters.DCSettings <> Undefined Then
			UserSettings = ReportParameters.DCSettings.DataParameters;
		EndIf;
	EndIf;
	
	Period = ReportMailing.GetPeriodFromUserSettings(UserSettings);
	If Period <> Undefined Then
		Return True;
	EndIf;

	Return False;

EndFunction

&AtServer
Procedure AddTemplateAdditionalParameters(TemplateParameters, Recipient)

	If EmailTextAdditionalParameters = Undefined Then
		Return;
	EndIf;

	TemplateAdditionalParameters = New Structure;
	For Each Parameter In EmailTextAdditionalParameters Do
		TemplateAdditionalParameters.Insert(Parameter.Value.Name, "");
	EndDo;
	
	ReportMailingOverridable.OnReceiveEmailTextParameters(BulkEmailType, MailingRecipientType, Recipient, TemplateAdditionalParameters);
	
	For Each Parameter In TemplateAdditionalParameters Do
		TemplateParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;

EndProcedure

&AtServer
Function GetFirstRecipient()

	RecipientsMetadata = Common.MetadataObjectByID(Object.MailingRecipientType, False);
	RecipientsType = Object.MailingRecipientType.MetadataObjectKey.Get();

	Query = New Query;

	If RecipientsType = Type("CatalogRef.Users") Then

		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	User.Ref AS Recipient,
		|	MAX(TableOfRecipients.Excluded) AS Excluded,
		|	Users.Description
		|INTO Recipients
		|FROM
		|	TableOfRecipients AS TableOfRecipients
		|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON UserGroupCompositions.UsersGroup = TableOfRecipients.Recipient
		|		LEFT JOIN Catalog.Users AS Users
		|		ON Users.Ref = UserGroupCompositions.User
		|WHERE
		|	NOT Users.DeletionMark
		|	AND NOT Users.Invalid
		|	AND NOT Users.IsInternal
		|GROUP BY
		|	User.Ref,
		|	Users.Description
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT TOP 1
		|	Recipients.Recipient AS Recipient,
		|	Recipients.Description AS Description
		|FROM
		|	Recipients AS Recipients
		|WHERE
		|	NOT Recipients.Excluded
		|
		|ORDER BY
		|	Description";

	Else

		QueryText =
		"SELECT
		|	TableOfRecipients.Recipient,
		|	TableOfRecipients.Excluded
		|INTO TableOfRecipients
		|FROM
		|	&TableOfRecipients AS TableOfRecipients
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT TOP 1
		|	Recipients.Ref AS Recipient,
		|	Recipients.Description AS Description
		|FROM
		|	Catalog.Users AS Recipients
		|WHERE
		|	Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			NOT Excluded)
		|	AND NOT Recipients.DeletionMark
		|	AND &ThisIsNotGroup
		|
		|ORDER BY
		|	Description";

		If Not RecipientsMetadata.Hierarchical Then
			// 
			QueryText = StrReplace(QueryText, "IN HIERARCHY", "In");
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		ElsIf RecipientsMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyOfItems Then
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "");
		Else
			// 
			QueryText = StrReplace(QueryText, "AND &ThisIsNotGroup", "AND NOT Recipients.IsFolder");
		EndIf;

		QueryText = StrReplace(QueryText, "Catalog.Users", RecipientsMetadata.FullName());

	EndIf;
	
	Query.SetParameter("TableOfRecipients", Object.Recipients.Unload());
	Query.Text = QueryText;

	FirstRecipient = New Structure ("Description, Ref", "", New (RecipientsType));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();

	If Selection.Next() Then
		FirstRecipient.Description = Selection.Description;
		FirstRecipient.Ref = Selection.Recipient;
	EndIf;
	
	Return FirstRecipient;

EndFunction

&AtServer
Function ReportsPlannedListInAttachments()

	ListFileNames = New Array;
	DeliveryParameters = New Structure("TransliterateFileNames", Object.TransliterateFileNames);

	// 
	FormatsParameters = New Map;
	For Each MetadataFormat In Metadata.Enums.ReportSaveFormats.EnumValues Do
		Format = Enums.ReportSaveFormats[MetadataFormat.Name];
		FormatParameters = ReportMailing.WriteSpreadsheetDocumentToFormatParameters(Format);
		FormatParameters.Insert("Name", MetadataFormat.Name);
		FormatsParameters.Insert(Format, FormatParameters);
	EndDo;

	For Each RowReport In Object.Reports Do
		FormatsOfReport = New Array;
		FoundItems = Object.ReportFormats.FindRows(New Structure("Report", RowReport.Report));

		If FoundItems.Count() = 0 Then
			For Each StringFormat In DefaultFormatsList Do
				If Not StringFormat.Check Then
					Continue;
				EndIf;
				FormatsOfReport.Add(StringFormat.Value);
			EndDo;
		Else
			For Each StringFormat In FoundItems Do
				FormatsOfReport.Add(StringFormat.Format);
			EndDo;
		EndIf;
		If IsTempStorageURL(RowReport.SettingsAddress) Then
			UserSettings = GetFromTempStorage(RowReport.SettingsAddress);
		Else
			RowIndex = Object.Reports.IndexOf(RowReport);
			ReportsRowObject = FormAttributeToValue("Object").Reports.Get(RowIndex);
			UserSettings = ?(ReportsRowObject = Undefined, Undefined, ReportsRowObject.Settings.Get());
		EndIf;
		Period = ReportMailing.GetPeriodFromUserSettings(UserSettings);

		For Each Format In FormatsOfReport Do
			FormatParameters = FormatsParameters.Get(Format);
			FullFileName = ReportMailing.FullFileNameFromTemplate(
			"", RowReport.Presentation, FormatParameters, DeliveryParameters, RowReport.DescriptionTemplate1, Period);

			// 
			ReportMailingOverridable.BeforeSaveSpreadsheetDocumentToFormat(
			True,
			New SpreadsheetDocument,
			Format,
			FullFileName);

			ListFileNames.Add(FullFileName);
		EndDo;

	EndDo;

	Return ListFileNames;

EndFunction

&AtServerNoContext
Function PutPicturesToTempStorage(PicturesForHTML)
	
	StringType = New TypeDescription("String");
	
	Attachments = New ValueTable;
	Attachments.Columns.Add("AddressInTempStorage", StringType);
	Attachments.Columns.Add("Id", StringType);
	Attachments.Columns.Add("Extension", StringType);
	
	For Each PictureForHTML In PicturesForHTML Do
		StringAttachment = Attachments.Add();
		FileAttachment = PictureForHTML.Value.GetBinaryData();
		StringAttachment.AddressInTempStorage = PutToTempStorage(FileAttachment);
		StringAttachment.Id = PictureForHTML.Key;
		StringAttachment.Extension = String(PictureForHTML.Value.Format());
	EndDo;
	
	Return PutToTempStorage(Attachments);
	
EndFunction

&AtServerNoContext
Function IsMemberOfPersonalReportGroup(Group)
	
	Return ReportMailing.IsMemberOfPersonalReportGroup(Group);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	ProhibitedCellTextColor = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CurrentReportSettings.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("CurrentReportSettings.Found");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", ProhibitedCellTextColor);
	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Reports.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportFormats.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Reports.Enabled");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", ProhibitedCellTextColor);
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportsFormatsDescriptionTemplate.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Reports.DescriptionTemplate1");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("TextColor", ProhibitedCellTextColor);
	Item.Appearance.SetParameterValue("Text", "[ReportDescription1] [ReportFormat]");

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportFormatsFormats.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Reports.Formats");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("TextColor", ProhibitedCellTextColor);
	Item.Appearance.SetParameterValue("Text", DefaultFormatsPresentation());
	
	//
	
	SetUpPersonalizationSettings();
	
EndProcedure

&AtServer
Procedure SetUpPersonalizationSettings()
	
	Item = Undefined;
	DesignParameter = New DataCompositionParameter("Text");
	
	For Each AppearanceItem In ConditionalAppearance.Items Do 
		
		ParameterValue = AppearanceItem.Appearance.FindParameterValue(DesignParameter);
		If ParameterValue.Value = MailingRecipientValueTemplate() Then 
			
			Item = AppearanceItem;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Item <> Undefined Then 
		
		ItemFilter = Item.Filter.Items[0];
		ItemFilter.RightValue = PersonalizationSettings;
		Return;
		
	EndIf;
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserSettingsValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DCSettingsComposer.UserSettings.Setting");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	ItemFilter.RightValue = PersonalizationSettings;
	
	Item.Appearance.SetParameterValue("Text", MailingRecipientValueTemplate());
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtServer
Function GetCache()
	
	// Convert descriptions to values.
	WeekDays = New Map;
	WeekDays.Insert(Items.Monday.Name, 1);
	WeekDays.Insert(Items.Tuesday.Name,     2);
	WeekDays.Insert(Items.Wednesday.Name,       3);
	WeekDays.Insert(Items.Thursday.Name,     4);
	WeekDays.Insert(Items.Friday.Name,     5);
	WeekDays.Insert(Items.Saturday.Name,     6);
	WeekDays.Insert(Items.Sunday.Name, 7);
	WeekDays = New FixedMap(WeekDays);
	
	Months = New Map;
	Months.Insert(Items.January.Name,   1);
	Months.Insert(Items.February.Name,  2);
	Months.Insert(Items.March.Name,     3);
	Months.Insert(Items.April.Name,   4);
	Months.Insert(Items.May.Name,      5);
	Months.Insert(Items.June.Name,     6);
	Months.Insert(Items.July.Name,     7);
	Months.Insert(Items.August.Name,   8);
	Months.Insert(Items.September.Name, 9);
	Months.Insert(Items.October.Name,  10);
	Months.Insert(Items.November.Name,   11);
	Months.Insert(Items.December.Name,  12);
	Months = New FixedMap(Months);
	
	// Defaults for fields that support filling templates.
	Templates = New FixedStructure("Subject, Text, ArchiveName",
		ReportMailingClientServer.SubjectTemplate(),
		ReportMailing.TextTemplate1(),
		ReportMailingClientServer.ArchivePatternName());
	
	// Cache structure.
	Cache = New Structure;
	Cache.Insert("EmptyReportValue", ReportMailing.EmptyReportValue());
	Cache.Insert("PersonalMailingsGroup", Catalogs.ReportMailings.PersonalMailings);
	Cache.Insert("SystemTitle", ReportMailing.ThisInfobaseName());
	Cache.Insert("Maps1", New FixedStructure("WeekDays, Months", WeekDays, Months));
	Cache.Insert("Templates", Templates);
	Cache.Insert("ReportsToExclude", ReportMailingCached.ReportsToExclude());
	
	Return New FixedStructure(Cache);
EndFunction

&AtServer
Procedure FillReportTableInfo()
	ReportsAvailability = ReportsOptions.ReportsAvailability(Object.Reports.Unload(, "Report").UnloadColumn("Report"));
	For Each ReportsRow In Object.Reports Do
		ReportInformation = ReportsAvailability.Find(ReportsRow.Report, "Ref");
		If ReportInformation = Undefined Then
			ReportsRow.Enabled = False;
			ReportsRow.Presentation = NStr("en = '<Insufficient rights to access the report>';");
		Else
			ReportsRow.Enabled = ReportInformation.Available;
			ReportsRow.Presentation = ReportInformation.Presentation;
		EndIf;
		ReportsRow.Formats = "";
		FoundItems = Object.ReportFormats.FindRows(New Structure("Report", ReportsRow.Report));
		For Each StringFormat In FoundItems Do
			ReportsRow.Formats = ReportsRow.Formats + ?(ReportsRow.Formats = "", "", ", ") + String(StringFormat.Format);
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure ReadJobSchedule()
	SetPrivilegedMode(True);
	JobID = ?(CreatedByCopying, MailingBasis.ScheduledJob, Object.ScheduledJob);
	If TypeOf(JobID) = Type("UUID") Then
		Job = ScheduledJobsServer.Job(JobID);
		If Job <> Undefined Then
			Schedule = Job.Schedule;
			If Object.SchedulePeriodicity <> Enums.ReportMailingSchedulePeriodicities.CustomValue Then
				Schedule.EndTime = '00010101';
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure ReadObjectSettingsOfObjectToCopy()
	RowsCount = Object.Reports.Count();
	For ReverseIndex = 1 To RowsCount Do
		IndexOf = RowsCount - ReverseIndex;
		ReportsRow = Object.Reports.Get(IndexOf);
		ObjectToCopyReportsRow = MailingBasis.Reports.Get(IndexOf);
		
		DCUserSettings = ObjectToCopyReportsRow.Settings.Get();
		
		ReportsRow.ChangesMade = True;
		
		RowID = ReportsRow.GetID();
		WarningString = ReportsOnActivateRowAtServer(RowID, True, DCUserSettings);
		If WarningString <> "" Then
			Common.MessageToUser(WarningString, , "Object.Reports["+ IndexOf +"].Presentation");
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure ConnectEmailSettingsCache()
	// 
	RecipientsTypesTable.Load(ReportMailingCached.RecipientsTypesTable());
	
	// Fill the recipients type selection list.
	For Each RecipientRow In RecipientsTypesTable Do
		Items.MailingRecipientType.ChoiceList.Add(RecipientRow.RecipientsType, RecipientRow.Presentation);
		If RecipientRow.MetadataObjectID = Object.MailingRecipientType Then
			MailingRecipientType = RecipientRow.RecipientsType;
			If Object.RecipientsEmailAddressKind.IsEmpty() And ValueIsFilled(RecipientRow.MainCIKind) Then
				Object.RecipientsEmailAddressKind = RecipientRow.MainCIKind;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure FillEmptyTemplatesWithStandard(CurrentObject)
	// Object data.
	If IsBlankString(CurrentObject.EmailSubject) Then
		CurrentObject.EmailSubject = Cache.Templates.Subject;
	EndIf;
	If IsBlankString(CurrentObject.EmailText) Then
		CurrentObject.EmailText = Cache.Templates.Text;
	EndIf;
	If IsBlankString(CurrentObject.ArchiveName) Then
		CurrentObject.ArchiveName = Cache.Templates.ArchiveName;
	EndIf;
	// Form data.
	If IsBlankString(EmailTextFormattedDocument.GetText()) Then
		EmailTextFormattedDocument.Add(Cache.Templates.Text, FormattedDocumentItemType.Text);
	EndIf;
EndProcedure

&AtServer
Procedure WriteReportsRowSettings(RowID)
	ReportsRow = Object.Reports.FindByID(RowID);
	If ReportsRow = Undefined Then
		Return;
	EndIf;
	
	If Not ReportsRow.Initialized Then
		ValueToSave = Undefined;
	ElsIf ReportsRow.DCS Then
		ValueToSave = DCSettingsComposer.UserSettings;
	Else
		ColumnsNames = "Attribute, Presentation, Value, Use";
		Filter = New Structure("Found", True);
		ValueToSave = CurrentReportSettings.Unload().Copy(Filter, ColumnsNames);
	EndIf;
	
	Address = ?(IsTempStorageURL(ReportsRow.SettingsAddress), ReportsRow.SettingsAddress, UUID);
	
	ReportsRow.SettingsAddress = PutToTempStorage(ValueToSave, Address);
EndProcedure

&AtServer
Function InitializeReport(ReportsRow, AddCommonText, UserSettings, Interactively = True)
	// Log parameters.
	LogParameters = New Structure;
	LogParameters.Insert("EventName",   NStr("en = 'Report distribution. Report initialization';", Common.DefaultLanguageCode()));
	LogParameters.Insert("Data",       ?(ValueIsFilled(Object.Ref), Object.Ref, ReportsRow.Report));
	LogParameters.Insert("Metadata",   Metadata.Catalogs.ReportMailings);
	LogParameters.Insert("ErrorsArray", New Array);
	
	// Initialize report.
	ReportParameters = New Structure("Report, Settings", ReportsRow.Report, UserSettings);
	ReportMailing.InitializeReport(
		LogParameters,
		ReportParameters,
		Object.Personalized,
		UUID);
	
	ReportParameters.Insert("ErrorsArray", LogParameters.ErrorsArray);
	ReportParameters.Errors = ReportMailing.MessagesToUserString(ReportParameters.ErrorsArray, AddCommonText);
	
	If ReportParameters.Initialized Then
		ReportsRow.DCS             = ReportParameters.DCS;
		ReportsRow.Initialized = ReportParameters.Initialized;
		ReportsRow.FullName       = ReportParameters.FullName;
		ReportsRow.VariantKey    = ReportParameters.VariantKey;
		// Support the ability to directly select additional reports references in reports mailings.
		If ValueIsFilled(ReportParameters.OptionRef1) Then
			ReportsRow.Report         = ReportParameters.OptionRef1;
			ReportsRow.Presentation = String(ReportsRow.Report);
		EndIf;
	EndIf;
	
	If Not Interactively Then
		Return ReportParameters;
	EndIf;
	
	// Check the initialization result.
	If Not ReportsRow.Initialized Then
		// 
		Object.Reports.Delete(ReportsRow);
		
		// 
		Items.ReportSettingsPages.CurrentPage = Items.PageEmpty;
		
		Return ReportParameters;
	EndIf;
	
	// Restore settings.
	If ReportsRow.DCS Then
		
		DCSettingsComposer = ReportParameters.DCSettingsComposer;
		Items.ReportSettingsPages.CurrentPage = Items.ComposerPage;
		
	Else
		
		// Clear & Restore
		If TypeOf(UserSettings) = Type("ValueTable") Then
			CurrentReportSettings.Load(UserSettings);
		Else
			CurrentReportSettings.Clear();
		EndIf;
		
		For Each KeyAndValue In ReportParameters.AvailableAttributes Do
			// Update attributes to be evaluated.
			FoundItems = CurrentReportSettings.FindRows(New Structure("Attribute", KeyAndValue.Key));
			If FoundItems.Count() = 0 Then
				SettingRow = CurrentReportSettings.Add();
				SettingRow.Attribute = KeyAndValue.Key;
			Else
				SettingRow = FoundItems[0];
			EndIf;
			SettingRow.Presentation = KeyAndValue.Value.Presentation;
			SettingRow.Type           = KeyAndValue.Value.Type;
			SettingRow.Found     = True;
			SettingRow.PictureIndex = 3;
		EndDo;
		
		// 
		FoundItems = CurrentReportSettings.FindRows(New Structure("Found", False));
		For Each SettingRow In FoundItems Do
			SettingRow.Use = False;
			SettingRow.PictureIndex = 4;
		EndDo;
		
		Items.ReportSettingsPages.CurrentPage = Items.CurrentReportSettingsPage;
		
	EndIf;
	
	Return ReportParameters;
EndFunction

&AtServer
Procedure AddReportsSettings(ReportsToAttach)
	
	For Each ReportsParametersRow In ReportsToAttach Do
		If ReportsParametersRow.Property("OptionRef")
			And TypeOf(ReportsParametersRow.OptionRef) = Type("CatalogRef.ReportsOptions")
			And ReportsParametersRow.OptionRef <> Catalogs.ReportsOptions.EmptyRef() Then
			OptionRef = ReportsParametersRow.OptionRef;
		Else
			ReportInformation = ReportsOptions.ReportInformation(ReportsParametersRow.ReportFullName);
			If Not IsBlankString(ReportInformation.ErrorText) Then
				If Not IsBlankString(PopupAlertTextOnOpen) Then
					PopupAlertTextOnOpen = PopupAlertTextOnOpen + Chars.LF;
				EndIf;
				PopupAlertTextOnOpen = PopupAlertTextOnOpen + ReportInformation.ErrorText;
			EndIf;
			OptionRef = ReportsOptions.ReportVariant(ReportInformation.Report, ReportsParametersRow.VariantKey);
		EndIf;
		
		If OptionRef.DeletionMark Then
			Continue;
		EndIf;
		
		FoundItems = Object.Reports.FindRows(New Structure("Report", OptionRef));
		If FoundItems.Count() > 0 Then
			ReportsRow = FoundItems[0];
		Else
			ReportsRow = Object.Reports.Add();
			ReportsRow.Report                = OptionRef;
			ReportsRow.SendIfEmpty = False;
			ReportsRow.DoNotSendIfEmpty   = True;
			ReportsRow.Enabled          = True;
		EndIf;
		
		ReportsRow.ChangesMade = True;
		
		If Not IsNew Then
			If FoundItems.Count() > 0 Then
				MessageRowTemplate = NStr("en = 'New user settings are imported for report ''%1''.';");
			Else
				MessageRowTemplate = NStr("en = '""%1"" report is added.';");
			EndIf;
			MessageRowTemplate = StringFunctionsClientServer.SubstituteParametersToString(MessageRowTemplate, String(OptionRef));
			If Not IsBlankString(PopupAlertTextOnOpen) Then
				PopupAlertTextOnOpen = PopupAlertTextOnOpen + Chars.LF;
			EndIf;
			PopupAlertTextOnOpen = PopupAlertTextOnOpen + MessageRowTemplate;
			RowIndex = Object.Reports.IndexOf(ReportsRow);
		EndIf;
		
		DCUserSettings = ReportsParametersRow.Settings;
		
		RowID = ReportsRow.GetID();
		Items.Reports.CurrentRow = RowID;
		WarningString = ReportsOnActivateRowAtServer(RowID, True, DCUserSettings);
		If WarningString <> "" Then
			Common.MessageToUser(WarningString, , "Object.Reports["+ RowIndex +"].Presentation");
		Else
			WriteReportsRowSettings(RowID);
		EndIf;
	EndDo;
	
	CurrentRowIDOfReportsTable = -1;
EndProcedure

&AtServer
Procedure CreateAttributeItemEncryptionCertificate()
	
	If Not ReportMailing.CanEncryptAttachments() Then
		CanEncryptAttachments = False;
		Return;
	EndIf;
	
	CanEncryptAttachments = True;
	
	If Items.Find("GroupEncryptionCertificates") <> Undefined Then
		Return;
	EndIf;
	
	AttributesToAddArray = New Array;
	AttributesToAddArray.Add(New FormAttribute("CertificateToEncrypt",
		New TypeDescription("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates"),,
		NStr("en = 'Encryption certificate';")));
		
	ChangeAttributes(AttributesToAddArray);
	
	Var_Group = Items.Add("GroupEncryptionCertificates", Type("FormGroup"), Items.ReportsFilesSettings);
	Var_Group.Type = FormGroupType.UsualGroup;
	Var_Group.Title = NStr("en = 'Encryption certificate';");
	Var_Group.ShowTitle = False;
	Var_Group.EnableContentChange = False;
	Var_Group.Representation = UsualGroupRepresentation.None;
	Var_Group.United = True;
	Var_Group.Behavior = UsualGroupBehavior.Usual;
	Var_Group.ThroughAlign = ThroughAlign.DontUse;
	
	Item = Items.Add("CertificateToEncrypt", Type("FormField"), Var_Group);
	Item.Title = NStr("en = 'Encryption certificate';");
	Item.DataPath = "CertificateToEncrypt";
	Item.Width = 70;
	Item.Type = FormFieldType.InputField;
	Item.SetAction("OnChange", "Attachable_EncryptionCertificateOnChange"); 
	Item.ToolTipRepresentation = ToolTipRepresentation.Button;
	Item.ExtendedTooltip.Title = NStr("en = 'When distributing reports by email, keep in mind that
		|some mail servers might not accept encrypted files.';");

EndProcedure

&AtServer
Procedure DoDisplayImportance()

	If Object.EmailImportance = "High" Then
		Items.SeverityGroup.Picture = PictureLib.ImportanceHigh;
		Items.SeverityGroup.ToolTip = NStr("en = 'High importance';");
	ElsIf Object.EmailImportance = "Low" Then
		Items.SeverityGroup.Picture = PictureLib.ImportanceLow;
		Items.SeverityGroup.ToolTip = NStr("en = 'Low importance';");
	Else
		Items.SeverityGroup.Picture = PictureLib.ImportanceNotSpecified;
		Items.SeverityGroup.ToolTip = NStr("en = 'Normal importance';");
	EndIf;

EndProcedure

&AtServer
Procedure AddCommandsAddTextAdditionalParameters()
	ReportMailing.AddCommandsAddTextAdditionalParameters(ThisObject);
EndProcedure

&AtServer
Procedure CheckPeriodsInReports(NewRowArray = Undefined)
	
	If NewRowArray <> Undefined Then 
		For Each RowID In NewRowArray Do
			If HasPeriodInSettings(RowID) Then
				RowReport = Object.Reports.FindByID(RowID);
				RowReport.ThereIsPeriod = True;
			EndIf;
		EndDo;
		Return;
	EndIf;	
		
	For Each RowReport In Object.Reports Do
		RowID = RowReport.GetID();
		If HasPeriodInSettings(RowID) Then
			RowReport.ThereIsPeriod = True;
		EndIf;
	EndDo; 

EndProcedure

&AtServer
Procedure DefineDistributionKind()
	
	If ReportMailing.IsMemberOfPersonalReportGroup(Object.Parent)Then
		 BulkEmailType = "Personal";
		 Object.Personal = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure WriteAtClient(Result, WriteParameters) Export
	// Initialize parameters.
	If Not WriteParameters.Property("Step") Then
		ClearMessages(); // 
		WriteParameters.Insert("Step", 1);
	EndIf;
	
	// Resource permissions.
	If WriteParameters.Step = 1 And PermissionsToUseServerResourcesRequired() Then
		WriteParameters.Step = 2;
		// Question.
		Handler = New NotifyDescription("WriteAtClient", ThisObject, WriteParameters);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Permissions = PermissionsToUseServerResources();
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Permissions, ThisObject, Handler);
		Else
			ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
		EndIf;
	ElsIf WriteParameters.Step = 1 Then
		// 
		WriteParameters.Step = 3;
	ElsIf WriteParameters.Step = 2 Then
		// Process the response.
		If Result = DialogReturnCode.OK Then
			WriteParameters.Step = 3; // 
		Else
			Return; // Cancel writing.
		EndIf;
	EndIf;
	
	// Disable archiving.
	If WriteParameters.Step = 3 And PreferablyDisableArchiving() Then
		WriteParameters.Step = 4;
		// Question.
		QuestionTitle = NStr("en = 'Disable backup';");
		QueryText = NStr("en = 'Disable archiving to ZIP when publishing reports into a folder.';");
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Disable archiving to ZIP';"));
		Buttons.Add(DialogReturnCode.Ignore, NStr("en = 'Continue';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("WriteAtClient", ThisObject, WriteParameters);
		ShowQueryBox(Handler, QueryText, Buttons, 60, DialogReturnCode.Yes, QuestionTitle);
	ElsIf WriteParameters.Step = 3 Then
		// 
		WriteParameters.Step = 5;
	ElsIf WriteParameters.Step = 4 Then
		// Process the response.
		If Result = DialogReturnCode.Yes Then
			Object.Archive = False; // 
			WriteParameters.Step = 5; // 
		ElsIf Result = DialogReturnCode.Ignore Then
			WriteParameters.Step = 5; // 
		Else
			Return; // Cancel writing.
		EndIf;
	EndIf;
	
	// Write.
	If WriteParameters.Step = 5 Then
		WriteParameters.Step = 6;
		Success = Write(WriteParameters);
		If Not Success Then
			Return; // Cancel writing.
		EndIf;
		CommandName = CommonClientServer.StructureProperty(WriteParameters, "CommandName");
		If CommandName = "ExecuteNowCommand" Then
			ExecuteNow();
		ElsIf CommandName = "CommandSaveAndClose" Then
			Close();
		ElsIf CommandName = "MailingEventsCommand" Then
			MailingEvents();
		ElsIf CommandName = "CommandCheckMailing" Then
			CheckMailing(CommonClientServer.StructureProperty(WriteParameters, "DeliveryParameters"));
		EndIf;
	EndIf;
EndProcedure

&AtClient
Function PermissionsToUseServerResourcesRequired()
	If Object.UseNetworkDirectory
		And (ValueIsFilled(Object.NetworkDirectoryWindows) Or ValueIsFilled(Object.NetworkDirectoryLinux)) Then
		// Publish to the network directory. Requires the permissions.
		If AttributesValuesChanged("UseNetworkDirectory, NetworkDirectoryWindows, NetworkDirectoryLinux") Then
			// 
			Return True;
		EndIf;
	EndIf;
	If Object.UseFTPResource And ValueIsFilled(Object.FTPServer) Then
		// Publish to the network directory. Requires the permissions.
		If AttributesValuesChanged("UseFTPResource, FTPServer, FTPDirectory") Then
			// 
			Return True;
		EndIf;
	EndIf;
	
	Return False;
EndFunction

&AtClient
Function PreferablyDisableArchiving()
	If Object.UseFolder
		And Object.Archive
		And (Object.NotifyOnly Or Not Object.UseEmail) Then
		// Publish into the notification distribution folder. We recommend that you disable archivation.
		If AttributesValuesChanged("UseFolder, UseEmail, NotifyOnly, Archive") Then
			// 
			Return True;
		EndIf;
	EndIf;
	
	Return False;
EndFunction

&AtServer
Function PermissionsToUseServerResources()
	PermissionsSet = ReportMailing.PermissionsToUseServerResources(Object);
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	PermissionsRef = ModuleSafeModeManager.RequestToUseExternalResources(PermissionsSet, Object.Ref);
	PermissionsRefArray = New Array;
	PermissionsRefArray.Add(PermissionsRef);
	Return PermissionsRefArray;
EndFunction

&AtClient
Function AttributesValuesChanged(AttributesNames)
	AttributesNames = StrSplit(AttributesNames, ",", False);
	For Each AttributeName In AttributesNames Do
		AttributeName = TrimAll(AttributeName);
		If Object[AttributeName] <> AttributesValuesBeforeChange[AttributeName] Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

&AtServer
Procedure FixAttributesValuesBeforeChange()
	
	AttributesNames = "UseFolder, UseEmail, NotifyOnly, Archive";
	AttributesNames = AttributesNames + ", UseNetworkDirectory, NetworkDirectoryWindows, NetworkDirectoryLinux";
	AttributesNames = AttributesNames + ", UseFTPResource, FTPServer, FTPDirectory";
	AttributesValuesBeforeChange = New Structure(AttributesNames);
	FillPropertyValues(AttributesValuesBeforeChange, Object);
	AttributesValuesBeforeChange = New FixedStructure(AttributesValuesBeforeChange);
	
EndProcedure

// Standard subsystems.Pluggable commands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
    ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
EndProcedure
// 

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ExecuteNow()
	MailingArray = New Array;
	MailingArray.Add(Object.Ref);
	
	StartupParameters = New Structure("MailingArray, Form, IsItemForm");
	StartupParameters.MailingArray = MailingArray;
	StartupParameters.Form = ThisObject;
	StartupParameters.IsItemForm = True;
	
	ReportMailingClient.ExecuteNow(StartupParameters);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure MailingEvents()
	EventLogFormParameters = EventLogParameters(Object.Ref);
	If EventLogFormParameters = Undefined Then
		ShowMessageBox(, NStr("en = 'Report distribution has not been started yet.';"));
		Return;
	EndIf;
	OpenForm("DataProcessor.EventLog.Form", EventLogFormParameters, ThisObject);
EndProcedure

&AtServerNoContext
Function EventLogParameters(BulkEmail)
	Return ReportMailing.EventLogParameters(BulkEmail);
EndFunction

#EndRegion