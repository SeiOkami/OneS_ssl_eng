///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var IsPasswordsCertificatesChanged;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MailingRecipientType        = Parameters.MailingRecipientType;
	RecipientsEmailAddressKind = Parameters.RecipientsEmailAddressKind;
	MailingDescription          = Parameters.MailingDescription;
	Ref = Parameters.Ref;
	
	FillRecipientsTypeInfo(Cancel);
	PrepareItemVisibility(Parameters.Archive);
	PopulateDefaultFilters();
	
	If IsTempStorageURL(Parameters.RecipientsAddress) Then
		PopulateDistributionRecipientsWithEmailAddress(GetFromTempStorage(Parameters.RecipientsAddress));
		DeleteFromTempStorage(Parameters.RecipientsAddress); 
	EndIf;

	TableRecipients = FormAttributeToValue("Recipients");
	ValueToFormAttribute(TableRecipients, "RecipientsNoFilters");
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		Items.WriteAndClose.Representation = ButtonRepresentation.Picture;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	IsPasswordsCertificatesChanged = False;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If IsPasswordsCertificatesChanged Then
		Cancel = True;
		QueryText = StringFunctionsClient.FormattedString(NStr(
		"en = 'Passwords and encryption certificates have been changed for report distribution recipients. Do you want to save the changes?
		|
		|• Click <b>Yes</b> to save the changes.
		|• Click<b>No</b> to close the dialog box without saving the changes.';"));

		ShowQueryBox(New NotifyDescription("ResponseSaveChangeCertificatesPasswords", ThisObject), QueryText,
			QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseFilterPasswordSetOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure FilterPasswordIsSetOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure UseFilterPasswordChangedOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure FilterPasswordChangedOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure UseFilterCertificateSpecifiedOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure FilterCertificateSpecifiedOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure UseFilterCertificateChangedOnChange(Item)
	SetFilters();
EndProcedure

&AtClient
Procedure FilterIsCertificateChangedOnChange(Item)
	SetFilters();
EndProcedure

#EndRegion

#Region RecipientsFormTableItemEventHandlers

&AtClient
Procedure RecipientsBeforeAddRow(Item, Cancel, Copy, Parent, IsFolder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure RecipientsSelection(Item, RowSelected, Field, StandardProcessing)
	
	Recipient = Items.Recipients.CurrentData.Recipient;
	
	If Item.CurrentItem = Items.RecipientsRecipient Or Item.CurrentItem = Items.RecipientsEmail Then
		If ValueIsFilled(Recipient) Then
			ShowValue( , Recipient);
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Procedure RecipientsBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure RecipientsArchivePasswordOnChange(Item)
	
	RowRecipients = Items.Recipients.CurrentData;
	RowRecipients.PasswordChanged = True;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Recipient", RowRecipients.Recipient);
	
	StringsRecipientsNoFilter = RecipientsNoFilters.FindRows(FilterParameters);
	If StringsRecipientsNoFilter.Count() > 0 Then
		StringsRecipientsNoFilter[0].ArchivePassword = RowRecipients.ArchivePassword;
		StringsRecipientsNoFilter[0].PasswordChanged = True;
	EndIf;
	
	IsPasswordsCertificatesChanged = True;
		
	UpdateFilters();	
		
EndProcedure

&AtClient
Procedure Attachable_RecipientsEncryptionCertificateOnChange(Item)
	
	RowRecipients = Items.Recipients.CurrentData;
	RowRecipients.IsCertificateChanged = True;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Recipient", RowRecipients.Recipient);
	
	StringsRecipientsNoFilter = RecipientsNoFilters.FindRows(FilterParameters);
	If StringsRecipientsNoFilter.Count() > 0 Then
		StringRecipientsNoFilter = StringsRecipientsNoFilter[0]; 
		StringRecipientsNoFilter["CertificateToEncrypt"] = RowRecipients["CertificateToEncrypt"];
		StringRecipientsNoFilter.IsCertificateChanged = True;
	EndIf;
	
	IsPasswordsCertificatesChanged = True;
	
	UpdateFilters();
		
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PopulateCertificates(Command)

	QueryText = StringFunctionsClient.FormattedString(NStr(
		"en = 'Encryption certificates will be filled for report distribution recipients if they are available for the respective individual.
		|
		|• Click <b>Yes</b> to re-fill certificates even if they are already specified.
		|• Click <b>No</b> to fill only missing certificates.';"));

	ShowQueryBox(
			New NotifyDescription("BeforePopulateCertificates", ThisObject), QueryText,
		QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);

EndProcedure

&AtClient
Procedure SetPasswords(Command)

	QueryText = StringFunctionsClient.FormattedString(NStr(
		"en = 'Passwords will be set for report distribution recipients.
		|
		|• Click <b>Yes</b> to set new passwords even if they are already set.
		|• Click <b>No</b> to set passwords only if no passwords are set.';"));

	ShowQueryBox(
			New NotifyDescription("BeforeSetPasswords", ThisObject), QueryText,
		QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);

EndProcedure

&AtClient
Procedure TogglePasswordsMasking(Command)
	
	If Items.RecipientsArchivePassword.Visible Then
		Items.RecipientsArchivePassword.Visible = False;
		Items.RecipientsArchivePassword2.Visible = True;
		Items.TogglePasswordsMasking.Picture = PictureLib.CharsBeingTypedHidden;
	Else
		Items.RecipientsArchivePassword.Visible = True;
		Items.RecipientsArchivePassword2.Visible = False;
		Items.TogglePasswordsMasking.Picture = PictureLib.CharsBeingTypedShown;
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintPasswordsList(Command)
	
	ArrayOfRecipients_ = New Array;
	For Each String In Recipients Do
		RecipientInfo = New Structure;
		RecipientInfo.Insert("Recipient", String.Recipient);
		RecipientInfo.Insert("Email", String.Email);
		RecipientInfo.Insert("ArchivePassword", String.ArchivePassword);
		ArrayOfRecipients_.Add(RecipientInfo);
	EndDo;

	PrintParameters = New Structure;
	PrintParameters.Insert("Recipients", ArrayOfRecipients_);
	PrintParameters.Insert("MailingRecipientType", MailingRecipientType);
	PrintParameters.Insert("MetadataObjectID", MetadataObjectID);
	PrintParameters.Insert("MailingDescription", MailingDescription);
	PrintParameters.Insert("Ref", Ref);
	
	CommandParameter = New Array;
	CommandParameter.Add(Ref);
	
	ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
	ModulePrintManagerClient.ExecutePrintCommand("Catalog.ReportMailings", "ReportDistributionPasswords", 
		CommandParameter, ThisObject, PrintParameters);
	
EndProcedure

&AtClient
Procedure DeliverPasswordsViaSMS(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("RecipientsAddress", PutRecipientsInStorage());
	FormParameters.Insert("MailingRecipientType", MailingRecipientType);
	FormParameters.Insert("Ref", Ref);
	FormParameters.Insert("MailingDescription", MailingDescription);
	FormParameters.Insert("MetadataObjectID", MetadataObjectID);
	OpenForm("Catalog.ReportMailings.Form.PasswordDeliveryViaSMS", FormParameters, ThisObject, , , , ,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	WritePasswordsAndEncryptionCertificatesToSecureStorage();
	IsPasswordsCertificatesChanged = False;
	Close();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateFilters()
	
	If UseFilterPasswordSet Or UseFilterPasswordChanged Or UseFilterCertificateSpecified
		Or UseFilterCertificateChanged Then
		SetFilters();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforePopulateCertificates(Result, Var_Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		PopulateRecipientsCertificatesAtServer(True);
		IsPasswordsCertificatesChanged = True;
	ElsIf Result = DialogReturnCode.No Then
		PopulateRecipientsCertificatesAtServer(False);
		IsPasswordsCertificatesChanged = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeSetPasswords(Result, Var_Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SetRecipientsPasswordsAtServer(True);
		IsPasswordsCertificatesChanged = True;
	ElsIf Result = DialogReturnCode.No Then
		SetRecipientsPasswordsAtServer(False);
		IsPasswordsCertificatesChanged = True;
	EndIf;
	
EndProcedure
	
&AtClient
Procedure ResponseSaveChangeCertificatesPasswords(Result, Var_Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		WritePasswordsAndEncryptionCertificatesToSecureStorage();
		IsPasswordsCertificatesChanged = False;
	ElsIf Result = DialogReturnCode.No Then
		IsPasswordsCertificatesChanged = False;
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure PopulateRecipientsCertificatesAtServer(ShouldRepopulateCertificates)
	
	TableRecipients = FormAttributeToValue("Recipients");
	
	If Not ShouldRepopulateCertificates Then	
		ArrayOfRecipients_ = New Array;
		For Each RowRecipients In TableRecipients Do
			If Not ValueIsFilled(RowRecipients.CertificateToEncrypt) Then
				ArrayOfRecipients_.Add(RowRecipients.Recipient);
			EndIf;
		EndDo;
	Else
		// 
		CertificatesEmptyRef = New (TableRecipients.Columns["CertificateToEncrypt"].ValueType.Types()[0]);
		For Each RowRecipients In Recipients Do
			If ValueIsFilled(RowRecipients.CertificateToEncrypt) Then
				RowRecipients.IsCertificateChanged = True;
				RowRecipients["CertificateToEncrypt"] = CertificatesEmptyRef;

				FilterParameters = New Structure;
				FilterParameters.Insert("Recipient", RowRecipients.Recipient);

				StringsRecipientsNoFilter = RecipientsNoFilters.FindRows(FilterParameters);
				If StringsRecipientsNoFilter.Count() > 0 Then
					StringRecipientsNoFilter = StringsRecipientsNoFilter[0];
					StringRecipientsNoFilter["CertificateToEncrypt"] = CertificatesEmptyRef;
					StringRecipientsNoFilter.IsCertificateChanged = True;
				EndIf;
			EndIf;
		EndDo;
		
		ArrayOfRecipients_ = TableRecipients.UnloadColumn("Recipient");
	EndIf;
	
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	
	TypesArray = New Array;
	TypesArray.Add(Type("CatalogRef.Users"));
	TypesArray.Add(Type("CatalogRef.UserGroups"));

	SelectionOfIndividuals = False;
	If MailingRecipientType = Metadata.DefinedTypes.Individual.Type Then
		Selection = ModuleDigitalSignatureInternal.CertificatesOfIndividuals(ArrayOfRecipients_);
		SelectionOfIndividuals = True;
	ElsIf MailingRecipientType = New TypeDescription(TypesArray) Then
		Selection = ModuleDigitalSignatureInternal.CertificatesOfIndividualsUsers(ArrayOfRecipients_);
	Else
		Return;
	EndIf;
	
	While Selection.Next() Do
		FilterParameters = New Structure;
		FilterParameters.Insert("Recipient", ?(SelectionOfIndividuals, Selection.Individual, Selection.User));
	
		StringsRecipientsNoFilter = RecipientsNoFilters.FindRows(FilterParameters);
		If StringsRecipientsNoFilter.Count() > 0 Then
			StringRecipientsNoFilter = StringsRecipientsNoFilter[0]; 
			StringRecipientsNoFilter["CertificateToEncrypt"] = Selection.Certificate;
			StringRecipientsNoFilter.IsCertificateChanged = True;
		EndIf;
	EndDo;
	
	SetFilters();

EndProcedure

&AtServer
Procedure SetRecipientsPasswordsAtServer(ShouldResetPasswords)
	
	PasswordProperties = Users.PasswordProperties();
	PasswordProperties.MinLength = 8;
	PasswordProperties.Complicated = True;
	PasswordProperties.ConsiderSettings = "ForUsers";
	
	For Each RowRecipients In Recipients Do
		
		If Not ShouldResetPasswords And ValueIsFilled(RowRecipients.ArchivePassword) Then	
			Continue;	
		EndIf;
		
		RowRecipients.ArchivePassword = Users.CreatePassword(PasswordProperties);
		RowRecipients.PasswordChanged = True;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Recipient", RowRecipients.Recipient);
		
		StringsRecipientsNoFilter = RecipientsNoFilters.FindRows(FilterParameters);
		If StringsRecipientsNoFilter.Count() > 0 Then
			FillPropertyValues(StringsRecipientsNoFilter[0], RowRecipients);
		EndIf;
	
	EndDo;
	
	SetFilters();
	
EndProcedure

&AtServer
Procedure SetFilters()

	TableRecipientsNoFilters = FormAttributeToValue("RecipientsNoFilters");

	Builder = New QueryBuilder;
	Builder.DataSource = New DataSourceDescription(TableRecipientsNoFilters);

	Filter = Builder.Filter;

	PasswordSet = Filter.Add("ArchivePassword");
	PasswordSet.ComparisonType	= ?(FilterPasswordIsSet, ComparisonType.NotEqual, ComparisonType.Equal);
	PasswordSet.Value		= "";
	PasswordSet.Use	= UseFilterPasswordSet;

	NewPassword = Filter.Add("PasswordChanged");
	NewPassword.ComparisonType	= ComparisonType.Equal;
	NewPassword.Value		= FilterPasswordChanged;
	NewPassword.Use	= UseFilterPasswordChanged;

	If ReportMailing.CanEncryptAttachments() Then
		CertificatePopulated = Filter.Add("CertificateToEncrypt");
		CertificatePopulated.ComparisonType	 = ?(FilterCertificateSpecified, ComparisonType.NotEqual, ComparisonType.Equal);
		CertificatePopulated.Value = New (TableRecipientsNoFilters.Columns["CertificateToEncrypt"].ValueType.Types()[0]);
		CertificatePopulated.Use = UseFilterCertificateSpecified;

		NewCertificate = Filter.Add("IsCertificateChanged");
		NewCertificate.ComparisonType	= ComparisonType.Equal;
		NewCertificate.Value		= FilterIsCertificateChanged;
		NewCertificate.Use	= UseFilterCertificateChanged;
	EndIf;
	
	Builder.Execute();
	ResultTable1 = 	Builder.Result.Unload();

	ValueToFormAttribute(ResultTable1, "Recipients");
	
EndProcedure

&AtServer
Procedure PopulateDistributionRecipientsWithEmailAddress(TableOfRecipients)
	
	RecipientsMetadata = Common.MetadataObjectByID(MetadataObjectID, False);
	RecipientsType = MetadataObjectID.MetadataObjectKey.Get();
		
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
		|SELECT ALLOWED DISTINCT
		|	Recipients.Recipient AS Recipient,
		|	Contacts.Presentation AS EMail,
		|	Recipients.Description AS Description
		|FROM
		|	Recipients AS Recipients
		|		LEFT JOIN Catalog.Users.ContactInformation AS Contacts
		|		ON Contacts.Ref = Recipients.Recipient
		|		AND Contacts.Kind = &RecipientsEmailAddressKind
		|WHERE
		|	NOT Recipients.Excluded
		|
		|ORDER BY
		|	Description
		|TOTALS
		|	MAX(Description) AS Description
		|BY
		|	Recipient";
		
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
		|SELECT ALLOWED DISTINCT
		|	Recipients.Ref AS Recipient,
		|	Contacts.Presentation AS EMail,
		|	Recipients.Description AS Description
		|FROM
		|	Catalog.Users AS Recipients
		|		LEFT JOIN Catalog.Users.ContactInformation AS Contacts
		|		ON Contacts.Ref = Recipients.Ref
		|		AND Contacts.Kind = &RecipientsEmailAddressKind
		|WHERE
		|	Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			NOT Excluded)
		|	AND NOT Recipients.Ref IN HIERARCHY
		|		(SELECT
		|			Recipient
		|		FROM
		|			TableOfRecipients
		|		WHERE
		|			Excluded)
		|	AND NOT Recipients.DeletionMark
		|	AND &ThisIsNotGroup
		|
		|ORDER BY
		|	Description
		|TOTALS
		|	MAX(Description) AS Description
		|BY
		|	Recipient";
		
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
		
	Query.SetParameter("TableOfRecipients", TableOfRecipients);
	If ValueIsFilled(RecipientsEmailAddressKind) Then
		Query.SetParameter("RecipientsEmailAddressKind", RecipientsEmailAddressKind);
	Else
		QueryText = StrReplace(QueryText, ".Kind = &RecipientsEmailAddressKind", ".Type = &MailAddressType");
		Query.SetParameter("MailAddressType", Enums.ContactInformationTypes.Email);
	EndIf;
	Query.Text = QueryText;
	
	Try
		QueryResult = Query.Execute();		
		SampleRecipients = QueryResult.Select(QueryResultIteration.ByGroups);
	Except
		Return;
	EndTry;
	
	ArrayOfRecipients_ = New Array;
	While SampleRecipients.Next() Do
		Selection = SampleRecipients.Select();
		RowRecipients = Recipients.Add();
		RowRecipients.Recipient = SampleRecipients.Recipient;
		ArrayOfRecipients_.Add(RowRecipients.Recipient);
		While Selection.Next() Do
			CurrentAddress = ?(IsBlankString(RowRecipients.Email), "",
				RowRecipients.Email + "; ");
			RowRecipients.Email = CurrentAddress + Selection.EMail;
		EndDo;
	EndDo;	
	
	PopulateArchivePasswordsAndEncryptionCertificates(ArrayOfRecipients_);
	
EndProcedure

&AtServer
Procedure FillRecipientsTypeInfo(Cancel)
	RecipientsTypesTable = ReportMailingCached.RecipientsTypesTable();
	FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
	If FoundItems.Count() = 1 Then
		RecipientRow = FoundItems[0];
		MetadataObjectID = RecipientRow.MetadataObjectID;
	Else
		Cancel = True;
	EndIf;
EndProcedure

&AtServer
Procedure PopulateArchivePasswordsAndEncryptionCertificates(RecipientsList)
	
	SetPrivilegedMode(True);
	RecipientsPasswords = Common.ReadOwnersDataFromSecureStorage(RecipientsList, "ArchivePassword");
	SetPrivilegedMode(False);
	
	For Each Recipient In RecipientsPasswords Do
		RecipientLines_ = Recipients.FindRows(New Structure("Recipient", Recipient.Key));
		If RecipientLines_.Count() > 0 Then
			RecipientLines_[0].ArchivePassword = Recipient.Value;
		EndIf;
	EndDo;
	
	If ReportMailing.CanEncryptAttachments() Then
		RecipientsCertificates = ReportMailing.GetEncryptionCertificatesForDistributionRecipients(RecipientsList);
		For Each RowRecipients In RecipientsCertificates Do
			RecipientLines_ = Recipients.FindRows(New Structure("Recipient", RowRecipients.BulkEmailRecipient));
			If RecipientLines_.Count() > 0 Then
				FillPropertyValues(RecipientLines_[0], RowRecipients);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure WritePasswordsAndEncryptionCertificatesToSecureStorage()
	
	CanEncryptAttachments = ReportMailing.CanEncryptAttachments();
	
	For Each String In RecipientsNoFilters Do
		If String.PasswordChanged Then
			SetPrivilegedMode(True);
			Common.WriteDataToSecureStorage(String.Recipient, String.ArchivePassword, "ArchivePassword");
			SetPrivilegedMode(False);
		EndIf;
		If CanEncryptAttachments And String.IsCertificateChanged Then
			InformationRegisters.CertificatesOfReportDistributionRecipients.SaveCertificateForDistributionRecipient(
				String.Recipient, String.CertificateToEncrypt);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure PrepareItemVisibility(Archive)
	
	AutoTitle = False;
	
	If ReportMailing.CanEncryptAttachments() Then
		AttributesToAddArray = New Array;
		AttributesToAddArray.Add(New FormAttribute("CertificateToEncrypt",
			New TypeDescription("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates"), "Recipients", NStr(
			"en = 'Encryption certificate';")));
		AttributesToAddArray.Add(New FormAttribute("CertificateToEncrypt",
			New TypeDescription("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates"), "RecipientsNoFilters", NStr(
			"en = 'Encryption certificate';")));

		ChangeAttributes(AttributesToAddArray);

		Item = Items.Add("RecipientsEncryptionCertificate", Type("FormField"), Items.Recipients);
		Item.Title = NStr("en = 'Encryption certificate';");
		Item.DataPath = "Recipients.CertificateToEncrypt";
		Item.Type = FormFieldType.InputField;
		Item.EditMode = ColumnEditMode.EnterOnInput;
		Item.Width = 30;
		Item.HeaderPicture = PictureLib.Change;
		Item.BackColor = StyleColors.MasterFieldBackground;
		Item.SetAction("OnChange", "Attachable_RecipientsEncryptionCertificateOnChange");
		
		TypesArray = New Array;
		TypesArray.Add(Type("CatalogRef.Users"));
		TypesArray.Add(Type("CatalogRef.UserGroups"));

		IndividualsTypesDetails = Metadata.DefinedTypes.Individual.Type;
		If IndividualsTypesDetails.Types()[0] = Type("String") Or (MailingRecipientType
			<> IndividualsTypesDetails And MailingRecipientType <> New TypeDescription(TypesArray)) Then
			Items.PopulateCertificates.Visible = False;
		EndIf;	
	
		Title = ?(Archive, NStr("en = 'Passwords and encryption for report distribution';"), NStr(
			"en = 'Encryption for report distribution';"));	
		
	Else
		Items.GroupCertificateFilters.Visible = False;
		Items.PopulateCertificates.Visible   = False;
		Title = NStr("en = 'Passwords for report distribution';");
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Items.PrintPasswordsList.Visible = False;	
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.SendSMSMessage") Then
		Items.DeliverPasswordsViaSMS.Visible    = False;
	EndIf;
	
	If Not Archive Then
		Items.GroupPasswordFilters.Visible      = False;
		Items.SetPasswords.Visible        = False;
		Items.PrintPasswordsList.Visible     = False;
		Items.DeliverPasswordsViaSMS.Visible    = False;
		Items.TogglePasswordsMasking.Visible    = False;
		Items.RecipientsArchivePassword.Visible  = False;
	ElsIf Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Items.TogglePasswordsMasking.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure PopulateDefaultFilters()
	
	FilterPasswordIsSet = True;
	FilterPasswordChanged = True;
	FilterCertificateSpecified = True;
	FilterIsCertificateChanged = True;
	
EndProcedure

&AtServer
Function PutRecipientsInStorage()
	Return PutToTempStorage(Recipients.Unload( , "Recipient, ArchivePassword"), UUID);
EndFunction

#EndRegion
