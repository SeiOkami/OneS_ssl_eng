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
Var ApplicationsCheckPerformed;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.OpenMachineReadableAuthorizationLetters.Visible = False;
	
	
	DigitalSignatureInternal.SetVisibilityOfRefToAppsTroubleshootingGuide(Items.Instruction);
	
	SetConditionalAppearance();
	DigitalSignatureInternal.SetCertificateListConditionalAppearance(Certificates, True);
	
	URL = "e1cib/app/CommonForm.DigitalSignatureAndEncryptionSettings";
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.SettingsPage.Visible = False;
		NoRightToSaveUserData = True;
	EndIf;
	
	IsFullUser = Users.IsFullUser();
	
	If Parameters.Property("ShowCertificatesPage") Then
		Items.Pages.CurrentPage = Items.CertificatesPage;
		
	ElsIf Parameters.Property("ShowSettingsPage") Then
		Items.Pages.CurrentPage = Items.SettingsPage;
		
	ElsIf Parameters.Property("ShowApplicationsPage") Then
		Items.Pages.CurrentPage = Items.ApplicationPage;
	EndIf;
	
	If ValueIsFilled(Parameters.CertificatesShow) Then
		CertificatesShow = Parameters.CertificatesShow;
	ElsIf IsFullUser Then
		CertificatesShow = "AllCertificates";
	Else
		CertificatesShow = "MyCertificates";
	EndIf;
		
	If Not IsFullUser Or CertificatesShow <> "AllCertificates" Then
		UserSelect = Users.CurrentUser();
	EndIf;
	
	// Application page
	If Not AccessRight("Update", Metadata.Catalogs.DigitalSignatureAndEncryptionApplications) Then
		Items.Programs.ChangeRowSet = False;
		
		CommonClientServer.SetFormItemProperty(Items,
			"ApplicationsAdd", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ApplicationsChange", "Visible", False);
		
		Items.ApplicationsMarkForDeletion.Visible = False;
		
		CommonClientServer.SetFormItemProperty(Items,
			"ApplicationsContextMenuAdd", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ApplicationsContextMenuChange", "Visible", False);
		
		Items.ApplicationsContextMenuApplicationsMarkForDeletion.Visible = False;
		Items.Programs.Title =
			NStr("en = 'List of applications provided by administrator which can be used on your computer';");
	EndIf;
	
	// Certificates page
	
	QueryText = Certificates.QueryText;
	CertificateIssueRequestAvailable = DigitalSignature.CommonSettings().CertificateIssueRequestAvailable;
	
	If CertificateIssueRequestAvailable Then
		
		ModuleApplicationForIssuingANewQualifiedCertificate = Common.CommonModule("DataProcessors.ApplicationForNewQualifiedCertificateIssue");
		ModuleApplicationForIssuingANewQualifiedCertificate.FillInApplicationStateSelectionList(Items.CertificatesShowRequests.ChoiceList);
		ModuleApplicationForIssuingANewQualifiedCertificate.AddStateInListOfCertificatesToRequest(QueryText);
		ModuleApplicationForIssuingANewQualifiedCertificate.AddLegend(ThisObject, Items.LegendGroup);
		Items.CertificatesShow.ChoiceList.Add("MyStatementsInProgress", NStr("en = 'My submitted applications';"));
		StatusApplicationIsNotInOperation = ModuleApplicationForIssuingANewQualifiedCertificate.StatusApplicationIsNotInOperation();
		Items.AddCertificateIssueRequest.Visible = True;
		
	Else
		QueryText = StrReplace(QueryText, "&AdditionalField", "UNDEFINED");
		QueryText = StrReplace(QueryText, "AND &OptionalConnection", "");
		QueryText = StrReplace(QueryText, "&IsRequest", "False");
		
		CommonClientServer.SetFormItemProperty(Items,
				"ReissueCertificate", "Visible", False);
		
		Items.CertificatesShowRequests.Visible  = False;
		Items.CertificatesApplicationState.Visible = False;
		Items.AddCertificateIssueRequest.Visible = False;
	EndIf;
	
	HasRightToAddCertificates =
		AccessRight("Insert", Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates);
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.Certificates, ListProperties);
	
	CertificatesInPersonalStorage = New ValueList;
	SetParametersInCertificateListOnServer();
	CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation);
	
	If Common.IsSubordinateDIBNode() Then
		// 
		// 
		Items.Programs.ChangeRowSet = False;
		Items.ApplicationsMarkForDeletion.Enabled = False;
		Items.ApplicationsContextMenuApplicationsMarkForDeletion.Enabled = False;
		CommonClientServer.SetFormItemProperty(Items,
			"ApplicationsChange", "OnlyInAllActions", False);
	Else
		Items.SettingInCentralNodeLabel.Visible = False;
	EndIf;
	
	If Not DigitalSignatureInternal.RequiresThePathToTheProgram(True) Then
		Items.ApplicationsLinuxPathToApplicationGroup.Visible = False;
	EndIf;
	
	Items.GroupCryptoProvidersHint.Visible = Common.IsWebClient()
		And Parameters.Property("ExtensionNotAttached");
	Items.FormInstallExtension.Visible = Common.IsWebClient();
	
	FillApplicationsAndSettings();
	UpdateCurrentItemsVisibility();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	DefineInstalledApplications();
	AttachIdleHandler("AddCertificatesInPersonalVaultDynamicListParameter", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnReopen()
	
	DefineInstalledApplications();
	If ValueIsFilled(Parameters.CertificatesShow) Then
		CertificatesShow = Parameters.CertificatesShow;
		CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") Then
		If Not ValueIsFilled(Parameter) Then
			Items.Certificates.Refresh();
		ElsIf Parameter.Is_Specified Then
			AttachIdleHandler("UpdateCertificatesList", 0.1, True);
		ElsIf Parameter.IsNew Then
			Items.Certificates.Refresh();
			Items.Certificates.CurrentRow = Source;
		Else
			Items.Certificates.Refresh();
		EndIf;
		Return;
	EndIf;
	
	// When changing application components or settings.
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers")
	 Or Upper(EventName) = Upper("WritePersonalSettingsForDigitalSignatureAndEncryption") Then
		
		AttachIdleHandler("OnChangeApplicationsCompositionOrSettings", 0.1, True);
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("InstallCryptoExtension")
		Or Upper(EventName) = Upper("Installation_AddInExtraCryptoAPI") Then
		DefineInstalledApplications();
		Return;
	EndIf;
	
	// When changing usage settings.
	If Upper(EventName) <> Upper("Write_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("UseDigitalSignature")
	 Or Upper(Source) = Upper("UseEncryption") Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If ApplicationsCheckPerformed <> True Then
		DefineInstalledApplications();
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificatesShowOnChange(Item)
	
	CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation, UsersClient.CurrentUser());
	
EndProcedure

&AtClient
Procedure CertificatesShowRequestsOnChange(Item)
	
	CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation);
	
EndProcedure

&AtClient
Procedure CertificatesOnlyValidOnChange(Item)

	CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation);

EndProcedure

&AtClient
Procedure UserSelectOnChange(Item)
	
	CertificatesUpdateFilter(ThisObject, StatusApplicationIsNotInOperation);
	
EndProcedure

&AtClient
Procedure EncryptedFilesExtensionOnChange(Item)
	
	If IsBlankString(EncryptedFilesExtension) Then
		EncryptedFilesExtension = "p7m";
	EndIf;
	
	ShouldSaveSettings();
	
EndProcedure

&AtClient
Procedure SignatureFilesExtensionOnChange(Item)
	
	If IsBlankString(SignatureFilesExtension) Then
		SignatureFilesExtension = "p7s";
	EndIf;
	
	ShouldSaveSettings();
	
EndProcedure

&AtClient
Procedure ActionsOnSaveSignedDataOnChange(Item)
	
	ShouldSaveSettings();
	
EndProcedure

&AtClient
Procedure SaveCertificateWithSignatureOnChange(Item)
	ShouldSaveSettings();
EndProcedure

&AtClient
Procedure ApplicationsLinuxPathToApplicationOnChange(Item)
	
	CurrentData = Items.Programs.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SaveApplicationPath();
	
EndProcedure

&AtClient
Procedure ApplicationsLinuxPathToApplicationStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Programs.CurrentData;
	If CurrentData = Undefined Then
		ChoiceData = Undefined;
		StandardProcessing = False;
		Return;
	EndIf;
	
	Filter = New Structure("Application", CurrentData.Ref);
	Rows = DefaultApplicationsPaths.FindRows(Filter);
	If Rows.Count() = 0 Then
		ChoiceData = Undefined;
		StandardProcessing = False;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplicationsLinuxPathToApplicationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Programs.CurrentData;
	If Not ValueIsFilled(ValueSelected)
		Or CurrentData = Undefined Then
		
		Return;
	EndIf;
	
	Filter = New Structure("Application", CurrentData.Ref);
	Rows = DefaultApplicationsPaths.FindRows(Filter);
	CurrentData.LinuxApplicationPath = ?(Rows.Count() = 0, "", Rows[0].Path);
	
	SaveApplicationPath();
	
EndProcedure

&AtClient
Procedure DecorationCheckCryptoProviderInstallationURLProcessing(
	Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	CheckParameters = New Structure;
	CheckParameters.Insert("ShouldInstallExtension", True);
	CheckParameters.Insert("SetComponent", True);
	CheckParameters.Insert("ShouldPromptToInstallApp", True);
	CheckParameters.Insert("ExtendedDescription", True);
	
	NotificationAfterAppsCheckCompleted = New NotifyDescription(
		"DetectInstalledAppsAfterCryptoAppsChecked", ThisObject);
	DigitalSignatureInternalClient.CheckCryptographyAppsInstallation(ThisObject, CheckParameters,
		New NotifyDescription("AfterCryptographyAppsChecked", ThisObject, NotificationAfterAppsCheckCompleted));

EndProcedure

#EndRegion

#Region CertificatesFormTableItemEventHandlers

&AtClient
Procedure CertificatesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	
	If Copy And CertificateIssueRequestAvailable Then
		If Items.Certificates.CurrentRow = Undefined Then
			Return;
		EndIf;
		CurrentData = CertificatesCurrentData(Items.Certificates);
		CreationParameters.CreateRequest = True;
		CreationParameters.CertificateBasis = CurrentData.Ref;
	Else
		CreationParameters.HideApplication = Not CertificateIssueRequestAvailable;
	EndIf;
	
	DigitalSignatureInternalClient.ToAddCertificate(CreationParameters);
	
EndProcedure

&AtServerNoContext
Procedure CertificatesOnGetDataAtServer(TagName, Settings, Rows)
	
	For Each String In Rows Do
		If Not String.Value.Data.Property("User") Then
			Return;
		EndIf;
		Break;
	EndDo;
	
	Query = Undefined;
	For Each String In Rows Do
		If ValueIsFilled(String.Value.Data.User) Then
			Continue;
		EndIf;
		If Query = Undefined Then
			Query = New Query;
			Query.Text =
			"SELECT
			|	ElectronicSignatureAndEncryptionKeyCertificatesUsers.Ref AS Ref,
			|	ElectronicSignatureAndEncryptionKeyCertificatesUsers.User AS User,
			|	PRESENTATION(ElectronicSignatureAndEncryptionKeyCertificatesUsers.User) AS UserPresentation
			|FROM
			|	Catalog.DigitalSignatureAndEncryptionKeysCertificates.Users AS
			|		ElectronicSignatureAndEncryptionKeyCertificatesUsers
			|WHERE
			|	ElectronicSignatureAndEncryptionKeyCertificatesUsers.Ref IN (&References)
			|TOTALS
			|	COUNT(User)
			|BY
			|	Ref";
			Query.SetParameter("References", Rows.GetKeys());
			QueryResult = Query.Execute(); // @skip-
			If QueryResult.IsEmpty() Then
				Return;
			EndIf;
			FetchLink = QueryResult.Select(QueryResultIteration.ByGroups);
		EndIf;
		If FetchLink.FindNext(String.Value.Data["Ref"], "Ref") Then
			UsersCount = FetchLink.User;
			SampleUser = FetchLink.Select();
			SampleUser.Next();
			If UsersCount = 1 Then
				String.Value.Data.User = SampleUser.UserPresentation;
				Continue;
			EndIf;
			User1 = SampleUser.UserPresentation;
			SampleUser.Next();
			User2 = SampleUser.UserPresentation;
			String.Value.Data.User = DigitalSignatureInternalClientServer.UsersCertificateString(
				User1, User2, UsersCount);
		EndIf;
	EndDo;
		
EndProcedure

#EndRegion

#Region ProgramsFormTableItemEventHandlers

&AtClient
Procedure ApplicationsOnActivateRow(Item)
	
	Items.ApplicationsMarkForDeletion.Enabled =
		Items.Programs.CurrentData <> Undefined;
	
	If Items.Programs.CurrentData <> Undefined Then
		LinuxPathToCurrentApplication = Items.Programs.CurrentData.LinuxApplicationPath;
	EndIf;
	
	UpdateLinuxProgramPath();
	
EndProcedure

&AtClient
Procedure ApplicationsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
	If Items.Programs.ChangeRowSet Then
		If DigitalSignatureInternalClient.UseCloudSignatureService() Then
			TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
			TheDSSCryptographyServiceModuleClient.AddingElectronicSignatureProgram(Undefined);
		Else	
			OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.ObjectForm");
		EndIf;	
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplicationsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Items.Find("ApplicationsChange") <> Undefined
	   And Items.ApplicationsChange.Visible Then
		If ValueIsFilled(Items.Programs.CurrentData.Ref) Then
			ShowValue(, Items.Programs.CurrentData.Ref);
		Else
			ExtendedApplicationDetails = DigitalSignatureInternalClientServer.NewExtendedApplicationDetails();
			FillPropertyValues(ExtendedApplicationDetails, Items.Programs.CurrentData);
			ExtendedApplicationDetails.Presentation = Items.Programs.CurrentData.Description;
			FormParameters = New Structure("Application, UsageMode", ExtendedApplicationDetails,
				PredefinedValue("Enum.DigitalSignatureAppUsageModes.SetupDone"));
			OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.ObjectForm", FormParameters, ThisObject,,,,,
				FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplicationsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Items.Find("ApplicationsChange") <> Undefined
	   And Items.ApplicationsChange.Visible Then
		
		ApplicationsMarkForDeletion(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure InstructionClick(Item)
	
	DigitalSignatureInternalClient.OpenInstructionOfWorkWithApplications();
	
EndProcedure

&AtClient
Procedure ApplicationsSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.Programs.CurrentData;
	If Field = Items.ApplicationsDetails
		And Not IsBlankString(CurrentData.MoreDetails) Then
		
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("WarningTitle", NStr("en = 'Application check result';"));
		FormParameters.Insert("ErrorTextClient", CurrentData.CheckResult);
		FormParameters.Insert("ErrorTextServer", CurrentData.CheckResultAtServer);
		FormParameters.Insert("ShowNeedHelp", True);
		FormParameters.Insert("ShowInstruction", True);
		
		OpenForm("CommonForm.ExtendedErrorPresentation", FormParameters, ThisObject);
	
	ElsIf Not ValueIsFilled(CurrentData.Ref) Then
	
		StandardProcessing = False;
		ApplicationDetails = DigitalSignatureInternalClientServer.NewExtendedApplicationDetails();
		FillPropertyValues(ApplicationDetails, CurrentData);
		ApplicationDetails.Presentation = CurrentData.Description;
		OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.Form.AutoDeterminedApp",
			New Structure("Application", ApplicationDetails), ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	DigitalSignatureInternalClient.ClearInstalledCryptoProvidersCache();
	FillApplicationsAndSettings(True);
	DefineInstalledApplications();
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure AddCertificateIssueRequest(Command)
	
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	CreationParameters.CreateRequest = True;
	DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice("CertificateIssueRequest", 
		CreationParameters);
	
EndProcedure

&AtClient
Procedure AddToSignAndEncrypt(Command)
	
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice(PurposeToSignAndEncrypt,
		CreationParameters);
	
EndProcedure

&AtClient
Procedure AddFromFiles(Command)
	
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice("OnlyForEncryptionFromFiles",
		CreationParameters);
	
EndProcedure

&AtClient
Procedure AddFromDirectory(Command)
	
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice("OnlyForEncryptionFromDirectory",
		CreationParameters);
	
EndProcedure

&AtClient
Procedure AddToEncryptOnly(Command)
	
	CreationParameters = DigitalSignatureInternalClient.CertificateAddingOptions();
	DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice("ToEncryptOnly",
		CreationParameters);
	
EndProcedure

&AtClient
Procedure InstallExtension(Command)
	
	DigitalSignatureClient.InstallExtension(True);
	
EndProcedure

&AtClient
Procedure ShowVersionComponentsExtraCryptoAPI(Command)
	
	InstallConnectReportVersionComponents(False);
		
EndProcedure

&AtClient
Procedure SetComponentExtraCryptoAPI(Command)
	
	InstallConnectReportVersionComponents(True);

EndProcedure

&AtClient
Procedure TechnicalInformation(Command)
	
	DigitalSignatureInternalClient.GenerateTechnicalInformation(
		NStr("en = 'Digital signature and encryption settings';"));
			
EndProcedure

&AtClient
Procedure ApplicationsMarkForDeletion(Command)
	
	CurrentData = Items.Programs.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	If CurrentData.DeletionMark Then
		QueryText = NStr("en = 'Do you want to clear a deletion mark for ""%1""?';");
	Else
		QueryText = NStr("en = 'Do you want to mark %1 for deletion?';");
	EndIf;
	
	QuestionContent = New Array;
	QuestionContent.Add(PictureLib.DoQueryBox32);
	QuestionContent.Add(StringFunctionsClientServer.SubstituteParametersToString(QueryText, CurrentData.Description));
	
	ShowQueryBox(
		New NotifyDescription("ApplicationsSetDeletionMarkContinue", ThisObject, CurrentData.Ref),
		New FormattedString(QuestionContent),
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateCertificatesList()

	CertificatesInPersonalStorage = New ValueList;
	NotifyDescription = New NotifyDescription(
		"UpdateCertificateListAfterGettingCertificatePropertiesOnClient",
		ThisObject, "UpdateAtServer");
	DigitalSignatureInternalClient.GetCertificatesPropertiesAtClient(NotifyDescription, True, True, True);

EndProcedure

&AtClient
Procedure AddCertificatesInPersonalVaultDynamicListParameter()
				
	DigitalSignatureInternalClient.GetCertificatesPropertiesAtClient(
		New NotifyDescription("UpdateCertificateListAfterGettingCertificatePropertiesOnClient", ThisObject),
		True, True, True);

EndProcedure

&AtClient
Procedure UpdateCertificateListAfterGettingCertificatePropertiesOnClient(Result, Var_Parameters) Export
	
	For Each KeyAndValue In Result.CertificatesPropertiesAtClient Do
		CertificatesInPersonalStorage.Add(KeyAndValue.Key); 
	EndDo;
	
	If Var_Parameters = "UpdateAtServer" Then
		SetParametersInCertificateListOnServer()
	Else	
		CurrentDate = CommonClient.UniversalDate();
		SetParametersInCertificateList(ThisObject, CertificatesInPersonalStorage, CurrentDate);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetParametersInCertificateList(Form, CertificatesList, CurrentDate)
	
	CommonClientServer.SetDynamicListParameter(
		Form.Certificates, "CertificatesInPersonalStorage", CertificatesList, True);
	CommonClientServer.SetDynamicListParameter(
		Form.Certificates, "CurrentDate", CurrentDate, True);

EndProcedure

&AtServer
Procedure SetParametersInCertificateListOnServer()

	DigitalSignatureInternal.AddListofCertificatesInPersonalStorageOnServer(CertificatesInPersonalStorage);
	SetParametersInCertificateList(ThisObject, CertificatesInPersonalStorage, CurrentUniversalDate());
	
EndProcedure	

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Programs.Use");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use  = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("ApplicationsCheckResult");
	AppearanceFieldItem.Use = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("ApplicationsDescription");
	AppearanceFieldItem.Use = True;
	
	If Items.ProgramsCheckResultAtServer.Visible Then
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
		AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
		AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
		AppearanceColorItem.Use = True;
		
		DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue  = New DataCompositionField("Programs.IsInstalledOnServer");
		DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue = False;
		DataFilterItem.Use  = True;
		
		AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
		AppearanceFieldItem.Field = New DataCompositionField("ProgramsCheckResultAtServer");
		AppearanceFieldItem.Use = True;

	EndIf;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Certificates.Revoked");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	AppearanceFieldItem = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceFieldItem.Field = New DataCompositionField("Certificates");
	AppearanceFieldItem.Use = True;
		
EndProcedure

&AtClientAtServerNoContext
Procedure CertificatesUpdateFilter(Form, StatusApplicationIsNotInOperation, CurrentUser = Undefined)
	
	Items = Form.Items;
	
	// Filtering certificates All/My.
	ShowOwnCertificates = Form.CertificatesShow <> "AllCertificates";
	If CurrentUser <> Undefined Then
		If ShowOwnCertificates Then
			Form.UserSelect = CurrentUser;
		Else
			Form.UserSelect = Undefined;
		EndIf;
	EndIf;
	
	// 
	Items.CertificatesUser.Visible = Not ShowOwnCertificates;
	Items.UserSelect.Visible = Not ShowOwnCertificates;
	Form.Certificates.Parameters.SetParameterValue("CertificateUser", ?(ValueIsFilled(
		Form.UserSelect), Form.UserSelect, Undefined));
	
	// Filter by valid certificates.
	SelectionByOperating = Not Form.CertificatesShow = "MyCertificatesWithexpiringValidity" 
						And Not Form.CertificatesShow = "MyStatementsInProgress";
							
	Items.CertificatesOnlyValid.Visible = SelectionByOperating;
	CommonClientServer.SetDynamicListFilterItem(Form.Certificates,
		"Valid_SSLyf", True, , , SelectionByOperating And Form.CertificatesOnlyValid);
	
	CommonClientServer.SetDynamicListFilterItem(Form.Certificates,
		"DeadlineEndsSoon", True, , ,Form.CertificatesShow = "MyCertificatesWithexpiringValidity");
		
	If Form.CertificatesShow = "MyStatementsInProgress" Then
		
		Form.CertificatesShowRequests = Undefined;
		Form.Items.CertificatesShowRequests.Visible = False;
		
		FilterByApplicationState = Undefined;
		CommonClientServer.SetDynamicListFilterItem(Form.Certificates,
			"RequestStatus", StatusApplicationIsNotInOperation, DataCompositionComparisonType.NotInList, , True);
	Else
		
		Form.Items.CertificatesShowRequests.Visible = Form.CertificateIssueRequestAvailable
			And Not Form.CertificatesShow = "MyCertificatesWithexpiringValidity";
		
		If Items.CertificatesShowRequests.Visible Then
			// 
			FilterByApplicationState = ValueIsFilled(Form.CertificatesShowRequests);
			CommonClientServer.SetDynamicListFilterItem(Form.Certificates,
				"RequestStatus", Form.CertificatesShowRequests, , , FilterByApplicationState);
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//  FormTable - FormDataCollection
// 
// Returns:
//  Structure:
//    * Ref - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
//
&AtClient
Function CertificatesCurrentData(FormTable)
	
	Return FormTable.CurrentData;
	
EndFunction

&AtClient
Procedure ApplicationsSetDeletionMarkContinue(Response, CurrentApplication) Export
	
	If Response = DialogReturnCode.Yes Then
		ChangeApplicationDeletionMark(CurrentApplication);
		NotifyChanged(CurrentApplication);
		Notify("Write_DigitalSignatureAndEncryptionApplications", New Structure, CurrentApplication);
		DefineInstalledApplications();
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeApplicationDeletionMark(Application)
	
	If TypeOf(Application) = DigitalSignatureInternal.ServiceProgramTypeSignatures() Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.ChangeApplicationDeletionMark(Application, UUID);
		
	Else
		LockDataForEdit(Application, , UUID);
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.DigitalSignatureAndEncryptionApplications");
		LockItem.SetValue("Ref", Application);
		
		BeginTransaction();
		Try
			
			Block.Lock();
			
			Object = Application.GetObject();
			Object.DeletionMark = Not Object.DeletionMark;
			If Object.DeletionMark Then
				Object.UsageMode = Enums.DigitalSignatureAppUsageModes.NotUsed;
			Else
				Object.UsageMode = Enums.DigitalSignatureAppUsageModes.SetupDone;
			EndIf;
			Object.Write();
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			UnlockDataForEdit(Application, UUID);
			Raise;
		EndTry;
		
		UnlockDataForEdit(Application, UUID);
	EndIf;
	
	FillApplicationsAndSettings(True);
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	UpdateCurrentItemsVisibility();
	
EndProcedure

&AtServer
Procedure UpdateCurrentItemsVisibility()
	
	If DigitalSignature.UseDigitalSignature() Then
		Items.SignatureFilesExtension.Visible = True;
		Items.ActionsOnSaveSignedData.Visible = True;
	Else
		Items.SignatureFilesExtension.Visible = False;
		Items.ActionsOnSaveSignedData.Visible = False;
	EndIf;
	
	Items.EncryptedFilesExtension.Visible = DigitalSignature.UseEncryption();
	
	If Not HasRightToAddCertificates Then
		
		Items.GroupAddCertificates.Visible = False;
		Items.AddCertificateIssueRequest.Visible = False;
		CommonClientServer.SetFormItemProperty(
			Items, "ReissueCertificate", "Visible", False);
		Return;
	EndIf;

	Items.AddCertificateIssueRequest.Visible = CertificateIssueRequestAvailable;
		
	If DigitalSignature.AddEditDigitalSignatures() Then
		
		Items.AddToSignAndEncrypt.Title = NStr("en = 'To sign and encrypt...';");

		If DigitalSignatureInternal.UseCloudSignatureService() Then
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to sign and encrypt from applications installed on DSS server and the computer';");
		ElsIf DigitalSignatureInternal.UseDigitalSignatureSaaS() Then
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to sign and encrypt from applications installed in the service and on the computer';");
		Else
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to sign and encrypt from applications installed on the computer';");
		EndIf;
		
		PurposeToSignAndEncrypt = "ToSignEncryptAndDecrypt";
	
	Else
	
		Items.AddToSignAndEncrypt.Title = NStr("en = 'To encrypt and decrypt...';");

		If DigitalSignatureInternal.UseCloudSignatureService() Then
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to encrypt and decrypt from applications installed on DSS server and the computer';");
		ElsIf DigitalSignatureInternal.UseDigitalSignatureSaaS() Then
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to encrypt and decrypt from applications installed in the service and on the computer';");
		Else
			Items.AddToSignAndEncrypt.ExtendedTooltip.Title = NStr(
				"en = 'Add certificates to encrypt and decrypt from applications installed on the computer';");
		EndIf;
		
		PurposeToSignAndEncrypt = "ToEncryptAndDecrypt";
	
	EndIf;
	
EndProcedure

&AtClient
Procedure DefineInstalledApplications()
	
	If Items.Pages.CurrentPage = Items.ApplicationPage Then
		ApplicationsCheckPerformed = True;
		BeginAttachingCryptoExtension(New NotifyDescription(
			"DetermineApplicationsInstalledAfterAttachExtension", ThisObject));
	Else
		ApplicationsCheckPerformed = Undefined;
	EndIf;
	
EndProcedure

// Continues the DefineInstalledApplications procedure.
&AtClient
Procedure DetermineApplicationsInstalledAfterAttachExtension(Attached, Context) Export
	
	If Attached Then
		Items.ApplicationsAndRefreshPages.CurrentPage = Items.ApplicationsRefreshPage;
	EndIf;
	
	#If WebClient Then
		AttachIdleHandler("IdleHandlerDefineInstalledApplications", 0.3, True);
	#Else
		AttachIdleHandler("IdleHandlerDefineInstalledApplications", 0.1, True);
	#EndIf
	
EndProcedure

&AtClient
Procedure IdleHandlerToContinue()
	
	Return;
	
EndProcedure

&AtClient
Procedure IdleHandlerDefineInstalledApplications()
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"DefineInstalledApplicationsOnAttachExtension", ThisObject));
	
	#If WebClient Then
		AttachIdleHandler("IdleHandlerToContinue", 0.3, True);
	#Else
		AttachIdleHandler("IdleHandlerToContinue", 0.1, True);
	#EndIf
	
EndProcedure

// Continues the IdleHandlerDefineInstalledApplications procedure.
&AtClient
Procedure DefineInstalledApplicationsOnAttachExtension(Attached, Context) Export
	
	If Not Attached Then
		Items.GroupCryptoProvidersHint.Visible = True;
		Items.DecorationCheckCryptoProviderInstallation.Title = StringFunctionsClient.FormattedString(
			NStr("en = '<a href = ""%1"">Click here</a> to install an extension for digital signatures and see all the applications for digital signatures installed on the computer.';"),
			"CheckCryptographyAppsInstallation");
		AttachIdleHandler("IdleHandlerDefineInstalledApplications", 3, True);
		Return;
	EndIf;
	
	DefaultApplicationsPaths.Clear();
	
	CheckParameters = New Structure;
	CheckParameters.Insert("ShouldInstallExtension", False);
	CheckParameters.Insert("SetComponent", False);
	CheckParameters.Insert("ShouldPromptToInstallApp", False);
	CheckParameters.Insert("CheckAtServer1", False);
	CheckParameters.Insert("ExtendedDescription", True);
	
	NotificationAfterAppsCheckCompleted = New NotifyDescription(
		"DetectInstalledAppsAfterCryptoAppsChecked", ThisObject, Context);
	
	DigitalSignatureInternalClient.CheckCryptographyAppsInstallation(ThisObject, CheckParameters,
		New NotifyDescription("AfterCryptographyAppsChecked", ThisObject, NotificationAfterAppsCheckCompleted));

EndProcedure

&AtClient
Async Procedure DetectInstalledAppsAfterCryptoAppsChecked(Result, Context) Export
	
	Attached = Await AttachCryptoExtensionAsync();
	
	If Not Attached Then
		Items.GroupCryptoProvidersHint.Visible = True;
		Items.DecorationCheckCryptoProviderInstallation.Title = StringFunctionsClient.FormattedString(
			NStr("en = '<a href = ""%1"">Click here</a> to install an extension for digital signatures and see all the applications for digital signatures installed on the computer.';"),
			"CheckCryptographyAppsInstallation");
	EndIf;
	
	Context = New Structure;
	Context.Insert("IndexOf", -1);
	Context.Insert("ExtensionAttached", Attached);
	
	IdleHandlerDefineInstalledApplicationsLoopStart(Context);
	
EndProcedure

// Continues the IdleHandlerDefineInstalledApplications procedure.
&AtClient
Procedure IdleHandlerDefineInstalledApplicationsLoopStart(Context)
	
	If Programs.Count() <= Context.IndexOf + 1 Then
		// 
		Items.ApplicationsAndRefreshPages.CurrentPage = Items.AppsListPage;
		CurrentItem = Items.Programs;
		UpdateLinuxProgramPath();
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	ApplicationDetails = Programs.Get(Context.IndexOf);

	Context.Insert("ApplicationDetails", ApplicationDetails);
	
	If ApplicationDetails.AutoDetect Then
		TheHandlerIsWaitingToDetermineTheCurrentlyInstalledProgramsCycleAfterObtainingTheProgramPath(Undefined, Context);
	Else
		DigitalSignatureInternalClient.GetTheDefaultProgramPath(New NotifyDescription(
			"TheHandlerIsWaitingToDetermineTheCurrentlyInstalledProgramsCycleAfterObtainingTheProgramPath", ThisObject, Context),
			ApplicationDetails.Ref);
	EndIf;
	
EndProcedure

// Continues the IdleHandlerDefineInstalledApplications procedure.
&AtClient
Procedure TheHandlerIsWaitingToDetermineTheCurrentlyInstalledProgramsCycleAfterObtainingTheProgramPath(DescriptionOfWay, Context) Export
	
	ApplicationDetails = Context.ApplicationDetails;
	
	If ValueIsFilled(DescriptionOfWay) And ValueIsFilled(DescriptionOfWay.ApplicationPath) Then
		NewRow = DefaultApplicationsPaths.Add();
		NewRow.Application = ApplicationDetails.Ref;
		NewRow.Path = DescriptionOfWay.ApplicationPath;
	EndIf;
	
	If ApplicationDetails.DeletionMark Then
		UpdateValue(ApplicationDetails.CheckResult, "");
		UpdateValue(ApplicationDetails.MoreDetails, "");
		UpdateValue(ApplicationDetails.Use, "");
		UpdateValue(ApplicationDetails.IsInstalledOnServer, "");
		IdleHandlerDefineInstalledApplicationsLoopStart(Context);
		Return;
	ElsIf ApplicationDetails.IsBuiltInCryptoProvider
		Or DigitalSignatureInternalClientServer.PlacementOfTheCertificate(ApplicationDetails.LocationType) = "CloudSignature" Then
		
		UpdateValue(ApplicationDetails.CheckResult, NStr("en = 'Available.';"));
		UpdateValue(ApplicationDetails.Use, True);
		IdleHandlerDefineInstalledApplicationsLoopStart(Context);
		Return;
	EndIf;
	
	If Not Context.ExtensionAttached Then
		IdleHandlerDefineInstalledApplicationsLoopStart(Context);
		Return;
	EndIf;
	
	ApplicationsDetailsCollection = New Array;
	ApplicationsDetailsCollection.Add(Context.ApplicationDetails);
	
	ErrorsDescription = DigitalSignatureInternalClientServer.NewErrorsDescription();
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ApplicationsDetailsCollection",  ApplicationsDetailsCollection);
	ExecutionParameters.Insert("IndexOf",            -1);
	ExecutionParameters.Insert("ShowError",    Undefined);
	ExecutionParameters.Insert("ErrorsDescription",    ErrorsDescription);
	ExecutionParameters.Insert("SignAlgorithm",   "");
	ExecutionParameters.Insert("InteractiveMode", False);
	ExecutionParameters.Insert("IsLinux",   DigitalSignatureInternalClient.RequiresThePathToTheProgram());
	ExecutionParameters.Insert("Manager",   Undefined);
	ExecutionParameters.Insert("Notification", New NotifyDescription(
		"IdleHandlerDefineInstalledApplicationsLoopFollowUp", ThisObject, Context));
	
	Context.Insert("ExecutionParameters", New Structure("ErrorsDescription", ErrorsDescription));
	
	DigitalSignatureInternalClient.CreateCryptoManagerLoopStart(ExecutionParameters);
	
EndProcedure

// Continues the IdleHandlerDefineInstalledApplications procedure.
&AtClient
Procedure IdleHandlerDefineInstalledApplicationsLoopFollowUp(Manager, Context) Export
	
	ApplicationDetails = Context.ApplicationDetails;
	Errors = Context.ExecutionParameters.ErrorsDescription.Errors; // Array of See DigitalSignatureInternalClientServer.NewErrorProperties
	
	If Manager <> Undefined Then
		UpdateValue(ApplicationDetails.CheckResult, NStr("en = 'Installed on the computer.';"));
		If ValueIsFilled(ApplicationDetails.CheckResultAtServer)
			And ApplicationDetails.IsInstalledOnServer <> True Then
			UpdateValue(ApplicationDetails.MoreDetails, NStr("en = 'Details';") + "...");
		Else
			UpdateValue(ApplicationDetails.MoreDetails, "");
		EndIf;
		UpdateValue(ApplicationDetails.Use, True);
		IdleHandlerDefineInstalledApplicationsLoopStart(Context);
		Return;
	EndIf;
	
	For Each Error In Errors Do
		Break;
	EndDo;
	
	If Error.PathNotSpecified Then
		UpdateValue(ApplicationDetails.CheckResult, Error.LongDesc);
		UpdateValue(ApplicationDetails.MoreDetails, NStr("en = 'Details';") + "...");
		UpdateValue(ApplicationDetails.Use, "");
	Else
		ErrorText = NStr("en = 'It is not installed on the computer.';") + " " + Error.LongDesc;
		If Error.ToAdministrator And Not IsFullUser Then
			ErrorText = ErrorText + " " + NStr("en = 'Please contact the application administrator.';");
		EndIf;
		UpdateValue(ApplicationDetails.CheckResult, ErrorText);
		UpdateValue(ApplicationDetails.MoreDetails, NStr("en = 'Details';") + "...");
		UpdateValue(ApplicationDetails.Use, False);
	EndIf;
	
	IdleHandlerDefineInstalledApplicationsLoopStart(Context);
	
EndProcedure

&AtClient
Procedure UpdateLinuxProgramPath()
	
	CurrentData = Items.Programs.CurrentData;
	
	DefaultPath = "";
	If CurrentData <> Undefined Then
		If CurrentData.AutoDetect Then
			Items.ApplicationsLinuxPathToApplication.DropListButton = False;
			Items.ApplicationsLinuxPathToApplication.ReadOnly = True;
			Items.ApplicationsLinuxPathToApplication.InputHint = NStr("en = 'Determined automatically';");
			Return;
		EndIf;
		
		Filter = New Structure("Application", CurrentData.Ref);
		Rows = DefaultApplicationsPaths.FindRows(Filter);
		If Rows.Count() > 0 Then
			DefaultPath = Rows[0].Path;
		EndIf;
	EndIf;
	
	Items.ApplicationsLinuxPathToApplication.DropListButton = ValueIsFilled(DefaultPath);
	Items.ApplicationsLinuxPathToApplication.InputHint = DefaultPath;
	Items.ApplicationsLinuxPathToApplication.ReadOnly = False;
	
	TheListOfChoices = Items.ApplicationsLinuxPathToApplication.ChoiceList;
	TheListOfChoices.Clear();
	If ValueIsFilled(DefaultPath) Then
		If CommonClient.IsLinuxClient() Then
			TheListOfChoices.Add("LinuxPath", NStr("en = 'Standard path for Linux';"));
		Else
			TheListOfChoices.Add("MacPath", NStr("en = 'Standard path for macOS';"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeApplicationsCompositionOrSettings()
	
	FillApplicationsAndSettings();
	
	DefineInstalledApplications();
	
EndProcedure

&AtClient
Procedure AfterCryptographyAppsChecked(Result, Notification) Export
	
	If Not Result.CheckCompleted Then
		Items.GroupCryptoProvidersHint.Visible = True;
		Items.DecorationCheckCryptoProviderInstallation.Title = StringFunctionsClient.FormattedString(
			NStr("en = '<a href = ""%1"">Click here</a> to see all the applications for digital signatures installed on the computer.';"),
			"CheckCryptographyAppsInstallation");
	Else
		Items.GroupCryptoProvidersHint.Visible = False;
	EndIf;
		
	If Result.CheckCompleted Then
		
		For Each Cryptoprovider In Result.Programs Do
			
			If ValueIsFilled(Cryptoprovider.Application) And Not HasAppsToCheck Then
				HasAppsToCheck = True;
			EndIf;
			
			Found4 = Programs.FindRows(New Structure("ApplicationName, ApplicationType",
				Cryptoprovider.ApplicationName, Cryptoprovider.ApplicationType));
			
			If Found4.Count() = 0
				Or DigitalSignatureInternalClientServer.AreAutomaticSettingsUsed(Found4[0].UsageMode) Then
				
				If Found4.Count() = 0 Then 
					NewRow = Programs.Add();
				Else
					NewRow = Found4[0];
				EndIf;
				
				FillPropertyValues(NewRow, Cryptoprovider,, "Ref, AppPathAtServerAuto");
				NewRow.LinuxApplicationPath = NewRow.PathToAppAuto;
				NewRow.LocationType = 1;
				NewRow.AutoDetect = True;
				NewRow.PictureUsageMode = -1;
				NewRow.Description = Cryptoprovider.Presentation;
			EndIf;
			
		EndDo;
		
		If Not HasAppsToCheck Then
			Items.GroupCryptoProvidersHint.Visible = True;
			Items.DecorationCheckCryptoProviderInstallation.Title = StringFunctionsClient.FormattedString(
				NStr("en = 'If you plan to use an advanced qualified digital signature, install a certified application (a cryptographic information protection tool) on your computer.
					|<a href = ""%1"">Install.</a>';"), "CheckCryptographyAppsInstallation");
		EndIf;
	EndIf;
	
	If Notification <> Undefined Then
		ExecuteNotifyProcessing(Notification);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillApplicationsAndSettings(RefreshCached = False)
	
	If RefreshCached Then
		RefreshReusableValues();
	EndIf;
	
	PersonalSettings = DigitalSignature.PersonalSettings();
	
	ActionsOnSavingWithDS                   = PersonalSettings.ActionsOnSavingWithDS;
	EncryptedFilesExtension           = PersonalSettings.EncryptedFilesExtension;
	SignatureFilesExtension                 = PersonalSettings.SignatureFilesExtension;
	ApplicationsPaths                            = PersonalSettings.PathsToDigitalSignatureAndEncryptionApplications;
	SaveCertificateWithSignature         = PersonalSettings.SaveCertificateWithSignature;
	HasApplicationsAtServer                     = False;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Programs.Ref,
	|	Programs.Description AS Description,
	|	Programs.ApplicationName,
	|	Programs.ApplicationType,
	|	Programs.SignAlgorithm,
	|	Programs.HashAlgorithm,
	|	Programs.EncryptAlgorithm,
	|	Programs.DeletionMark AS DeletionMark,
	|	Programs.IsBuiltInCryptoProvider,
	|	Programs.UsageMode,
	|	1 AS LocationType
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS Programs
	|WHERE
	|	NOT Programs.IsBuiltInCryptoProvider
	|
	|UNION ALL
	|
	|SELECT
	|	Programs.Ref,
	|	Programs.Description,
	|	Programs.ApplicationName,
	|	Programs.ApplicationType,
	|	Programs.SignAlgorithm,
	|	Programs.HashAlgorithm,
	|	Programs.EncryptAlgorithm,
	|	Programs.DeletionMark,
	|	Programs.IsBuiltInCryptoProvider,
	|	VALUE(Enum.DigitalSignatureAppUsageModes.SetupDone),
	|	4
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS Programs
	|WHERE
	|	Programs.IsBuiltInCryptoProvider
	|	AND &UseDigitalSignatureSaaS
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("UseDigitalSignatureSaaS", 
		DigitalSignatureInternal.UseDigitalSignatureSaaS());
	
	TheSampleTable = Query.Execute().Unload();
	
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleInternal.AddSelectionOfPrograms(TheSampleTable);
	EndIf;
	
	TheSampleTable.Columns.Add("AppPathAtServerAuto", New TypeDescription("String"));
	TheSampleTable.Columns.Add("CheckResultAtServer", New TypeDescription("String"));
	TheSampleTable.Columns.Add("AutoDetect", New TypeDescription("Boolean"));
	
	Settings = DigitalSignature.CommonSettings();
	If Settings.VerifyDigitalSignaturesOnTheServer Or Settings.GenerateDigitalSignaturesAtServer Then
		
		CheckParameters = New Structure;
		CheckParameters.Insert("ExtendedDescription", True);
		ResultCryptoProviders = DigitalSignature.CheckCryptographyAppsInstallation(CheckParameters);
		
		If ResultCryptoProviders.CheckCompleted Then
			
			For Each Cryptoprovider In ResultCryptoProviders.Programs Do
				
				If ValueIsFilled(Cryptoprovider.Application) And Not HasAppsToCheck Then
					HasAppsToCheck = True;
				EndIf;
				
				Found4 = TheSampleTable.FindRows(New Structure("ApplicationName, ApplicationType",
					Cryptoprovider.ApplicationName, Cryptoprovider.ApplicationType));
				
				If Found4.Count() = 0
					Or DigitalSignatureInternalClientServer.AreAutomaticSettingsUsed(Found4[0].UsageMode) Then
					If Found4.Count() = 0 Then 
						SelectionString = TheSampleTable.Add();
					Else
						SelectionString = Found4[0];
					EndIf;
					FillPropertyValues(SelectionString, Cryptoprovider,,"Ref");
					SelectionString.LocationType = 1;
					SelectionString.DeletionMark = False;
					SelectionString.AppPathAtServerAuto = Cryptoprovider.AppPathAtServerAuto;
					SelectionString.Description = Cryptoprovider.Presentation;
					SelectionString.AutoDetect = True;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		Items.ProgramsCheckResultAtServer.Visible = IsFullUser;
	Else
		Items.ProgramsCheckResultAtServer.Visible = False;
	EndIf;
	
	ProcessedRows = New Map;
	IndexOf = 0;
	
	For Each SelectionString In TheSampleTable Do
		
		ApplicationNotUsed = DigitalSignatureInternalClientServer.ApplicationNotUsed(SelectionString.UsageMode);
		
		If Not Users.IsFullUser() 
			And (ApplicationNotUsed Or SelectionString.DeletionMark) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(SelectionString.Ref) Then
			Rows = Programs.FindRows(New Structure("Ref", SelectionString.Ref));
		Else
			Rows = Programs.FindRows(New Structure("ApplicationName, ApplicationType",
				SelectionString.ApplicationName, SelectionString.ApplicationType));
		EndIf;
		
		If Rows.Count() = 0 Then
			If Programs.Count()-1 < IndexOf Then
				String = Programs.Add();
			Else
				String = Programs.Insert(IndexOf);
			EndIf;
		Else
			String = Rows[0];
			RowIndex = Programs.IndexOf(String);
			If RowIndex <> IndexOf Then
				Programs.Move(RowIndex, IndexOf - RowIndex);
			EndIf;
		EndIf;
		// Updating only changed values not to update the form table once again.
		UpdateValue(String.Ref,                       SelectionString.Ref);
		UpdateValue(String.DeletionMark,              SelectionString.DeletionMark);
		UpdateValue(String.Description,                 SelectionString.Description);
		UpdateValue(String.ApplicationName,                 SelectionString.ApplicationName);
		UpdateValue(String.ApplicationType,                 SelectionString.ApplicationType);
		UpdateValue(String.SignAlgorithm,              SelectionString.SignAlgorithm);
		UpdateValue(String.HashAlgorithm,          SelectionString.HashAlgorithm);
		UpdateValue(String.EncryptAlgorithm,           SelectionString.EncryptAlgorithm);
		UpdateValue(String.AutoDetect,              SelectionString.AutoDetect);
		UpdateValue(String.UsageMode,           SelectionString.UsageMode);
		UpdateValue(String.AppPathAtServerAuto,  SelectionString.AppPathAtServerAuto);
		UpdateValue(String.IsBuiltInCryptoProvider, SelectionString.IsBuiltInCryptoProvider);
		
		If ApplicationNotUsed And Not SelectionString.DeletionMark Then
			UpdateValue(String.LocationType, 9);
		Else
			UpdateValue(String.LocationType, SelectionString.LocationType + ?(SelectionString.DeletionMark, 4, 0));
		EndIf;
		
		If SelectionString.AutoDetect Then // 
			UpdateValue(String.LinuxApplicationPath, SelectionString.AppPathAtServerAuto);
			UpdateValue(String.PictureUsageMode, -1);
		Else
			UpdateValue(String.LinuxApplicationPath, ApplicationsPaths.Get(SelectionString.Ref));
			UpdateValue(String.PictureUsageMode, 0);
		EndIf;
		
		If String.IsBuiltInCryptoProvider And Not String.DeletionMark Then
			UpdateValue(String.CheckResult, NStr("en = 'Available.';"));
			UpdateValue(String.Use, True);
		ElsIf DigitalSignatureInternalClientServer.PlacementOfTheCertificate(SelectionString.LocationType) = "CloudSignature"
				And Not String.DeletionMark Or SelectionString.LocationType = 5 Then
			UpdateValue(String.CheckResult, NStr("en = 'Available.';"));
			UpdateValue(String.Use, True);
		ElsIf String.LocationType = 1 And (Settings.VerifyDigitalSignaturesOnTheServer Or Settings.GenerateDigitalSignaturesAtServer) Then
			CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
			CreationParameters.AutoDetect = False;
			ApplicationDetails = DigitalSignatureInternalClientServer.NewExtendedApplicationDetails();
			FillPropertyValues(ApplicationDetails, String);
			ApplicationDetails.Presentation = String.Description;
			CreationParameters.Application = ApplicationDetails;
			CreationParameters.ErrorDescription = New Structure;
			CryptoManager = DigitalSignatureInternal.CryptoManager("", CreationParameters);
			If CryptoManager = Undefined Then
				UpdateValue(String.CheckResultAtServer, CreationParameters.ErrorDescription.ErrorDescription);
				UpdateValue(String.IsInstalledOnServer, False);
			Else
				UpdateValue(String.CheckResultAtServer, NStr("en = 'Installed on the server.';"));
				UpdateValue(String.IsInstalledOnServer, True);
			EndIf;
		EndIf;
		
		ProcessedRows.Insert(String, True);
		IndexOf = IndexOf + 1;
	EndDo;
	
	IndexOf = Programs.Count()-1;
	While IndexOf >=0 Do
		String = Programs.Get(IndexOf);
		If ProcessedRows.Get(String) = Undefined Then
			Programs.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf-1;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateValue(PreviousValue2, NewValue)
	
	If PreviousValue2 <> NewValue Then
		PreviousValue2 = NewValue;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShouldSaveSettings()
	
	SavingSettings = New Structure;
	SavingSettings.Insert("ActionsOnSavingWithDS",                   ActionsOnSavingWithDS);
	SavingSettings.Insert("EncryptedFilesExtension",           EncryptedFilesExtension);
	SavingSettings.Insert("SignatureFilesExtension",                 SignatureFilesExtension);
	SavingSettings.Insert("SaveCertificateWithSignature",         SaveCertificateWithSignature);
	SaveSettingsAtServer(SavingSettings);
	
EndProcedure

&AtServerNoContext
Procedure SaveSettingsAtServer(SavingSettings)
	
	PersonalSettings = DigitalSignature.PersonalSettings();
	FillPropertyValues(PersonalSettings, SavingSettings);
	DigitalSignatureInternal.SavePersonalSettings(PersonalSettings);
	
	// It is required to update personal settings on the client.
	RefreshReusableValues();
	
EndProcedure

&AtServerNoContext
Procedure SaveLinuxPathAtServer(Application, LinuxPath)
	
	PersonalSettings = DigitalSignature.PersonalSettings();
	PersonalSettings.PathsToDigitalSignatureAndEncryptionApplications.Insert(Application, LinuxPath);
	DigitalSignatureInternal.SavePersonalSettings(PersonalSettings);
	
	// It is required to update personal settings on the client.
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure SaveApplicationPath()
	
	CurrentData = Items.Programs.CurrentData;
	If NoRightToSaveUserData Then
		CurrentData.LinuxApplicationPath = LinuxPathToCurrentApplication;
		ShowMessageBox(,
			NStr("en = 'Couldn''t save path to the application. You do not have sufficient rights to save data.
			           |Contact your administrator.';"));
	Else
		SaveLinuxPathAtServer(CurrentData.Ref, CurrentData.LinuxApplicationPath);
		DefineInstalledApplications();
	EndIf;
	
EndProcedure

&AtClient
Procedure InstallConnectReportVersionComponents(SuggestToImport)
	
	ConnectionParameters = CommonClient.AddInAttachmentParameters();
	ConnectionParameters.ExplanationText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Add-in is required: %1';"), "ExtraCryptoAPI");
	ConnectionParameters.SuggestToImport = SuggestToImport;
	ConnectionParameters.SuggestInstall = True;
	
	ComponentDetails = DigitalSignatureInternalClientServer.ComponentDetails();
	
	CommonClient.AttachAddInFromTemplate(
		New NotifyDescription("ReportResultConnectionsComponents", ThisObject),
		ComponentDetails.ObjectName,
		ComponentDetails.FullTemplateName,
		ConnectionParameters);
		
EndProcedure

&AtClient
Procedure ReportResultConnectionsComponents(Result, AdditionalParameters) Export
	
	If Result.Attached Then
		Try 
			NotificationAfterReceivingTheVersion = New NotifyDescription("ReportComponentVersionAfterConnecting", ThisObject);
			Result.Attachable_Module.StartAChallengeGetAVersion(NotificationAfterReceivingTheVersion);
			Return;
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t determine the add-in version.
				|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			ShowMessageBox(, ErrorText);
		EndTry;
	Else
		If IsBlankString(Result.ErrorDescription) Then 
			// A user canceled the installation.
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Add-in %1 is not installed.';"), "ExtraCryptoAPI");
			ShowMessageBox(, ErrorText);
		Else 
			// Installation failed. The error description is in Result.ErrorDetails.
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Add-in %1 is not installed (%2).';"), "ExtraCryptoAPI", Result.ErrorDescription);
			ShowMessageBox(, ErrorText);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ReportComponentVersionAfterConnecting(Result, Var_Parameters, AdditionalParameters) Export
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Add-in %1 version is %2.';"), "ExtraCryptoAPI", Result);
	ShowMessageBox(, MessageText);
	RefreshReusableValues();
	DigitalSignatureInternalClient.ClearInstalledCryptoProvidersCache();
	Notify("Installation_AddInExtraCryptoAPI");
	
EndProcedure

#EndRegion
