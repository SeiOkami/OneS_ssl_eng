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
Var SelectedApplicationDescription;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Common.IsSubordinateDIBNode() Then
		ReadOnly = True;
	Else
		Items.SettingInCentralNodeLabel.Visible = False;
	EndIf;
	
	Items.Description.ChoiceList.Add("", NStr("en = '<Another application>';"));
	SettingsToSupply = Catalogs.DigitalSignatureAndEncryptionApplications.ApplicationsSettingsToSupply();
	For Each SettingToSupply In SettingsToSupply Do
		If ThereIsAClientOrServerVOS(SettingToSupply) Then
			Items.Description.ChoiceList.Add(SettingToSupply.Presentation);
		EndIf;
	EndDo;
	
	// Populates a new object by a built-in setting.
	If Not ValueIsFilled(Object.Ref) Then
		
		If ValueIsFilled(Parameters.SuppliedSettingID) Then
		
			Filter = New Structure("Id", Parameters.SuppliedSettingID);
			Rows = SettingsToSupply.FindRows(Filter);
			If Rows.Count() > 0 Then
				FillPropertyValues(Object, Rows[0]);
				Object.Description = Rows[0].Presentation;
				Items.Description.ReadOnly = True;
				Items.ApplicationName.ReadOnly = True;
				Items.ApplicationType.ReadOnly = True;
			EndIf;
			
		ElsIf ValueIsFilled(Parameters.Application) Then
			
			AppAuto = Parameters.Application; // See DigitalSignatureInternalClientServer.ExtendedApplicationDetails
			
			FillPropertyValues(Object, AppAuto,,"Ref");
			Object.Description = AppAuto.Presentation;
			Items.Description.ReadOnly = True;
			Items.ApplicationName.ReadOnly = True;
			Items.ApplicationType.ReadOnly = True;
			Object.UsageMode = Parameters.UsageMode;
			
		EndIf;
	EndIf;
	
	// 
	Filter = New Structure("ApplicationName, ApplicationType", Object.ApplicationName, Object.ApplicationType);
	Rows = SettingsToSupply.FindRows(Filter);
	SettingToSupply = ?(Rows.Count() = 0, Undefined, Rows[0]);
	FillAlgorithmsChoiceLists(SettingToSupply);
	SetTitleAutoSettings(SettingToSupply);
	SetVisibilityAndAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillSelectedApplicationAlgorithms(True);
	
	If ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	If ValueIsFilled(Object.ApplicationName) Then
		Return;
	EndIf;
	
	AttachIdleHandler("HandlerWaitingToStartTheProgramAfterOpening", 0.1, True);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// 
	// 
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DigitalSignatureAndEncryptionApplications", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("ApplicationName", Object.ApplicationName);
	Query.SetParameter("ApplicationType", Object.ApplicationType);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS DigitalSignatureAndEncryptionApplications
	|WHERE
	|	DigitalSignatureAndEncryptionApplications.Ref <> &Ref
	|	AND DigitalSignatureAndEncryptionApplications.ApplicationName = &ApplicationName
	|	AND DigitalSignatureAndEncryptionApplications.ApplicationType = &ApplicationType";
	
	If Not Query.Execute().IsEmpty() Then
		Cancel = True;
		Common.MessageToUser(
			NStr("en = 'Application with the specified name and type has already been added to the list.';"),
			,
			"Object.ApplicationName");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	FillSelectedApplicationSettings(Object.Description);
	FillSelectedApplicationAlgorithms();
	
EndProcedure

&AtClient
Procedure DescriptionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = "" Then
		Object.Description = "";
		Object.ApplicationName = "";
		Object.ApplicationType = 0;
		Object.SignAlgorithm = "";
		Object.HashAlgorithm = "";
		Object.EncryptAlgorithm = "";
	EndIf;
	
	SelectedApplicationDescription = ValueSelected;
	
	AttachIdleHandler("IdleHandlerDescriptionChoiceProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure ApplicationNameOnChange(Item)
	
	AttachIdleHandler("WaitHandlerNameAndTypeOnChange", 0.1, True);
	
EndProcedure

&AtClient
Procedure ApplicationTypeOnChange(Item)
	
	AttachIdleHandler("WaitHandlerNameAndTypeOnChange", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsageModeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.Automatically") Then
		
		ApplicationsByNamesWithType = DigitalSignatureClient.CommonSettings().ApplicationsByNamesWithType;
		Var_Key = DigitalSignatureInternalClientServer.ApplicationSearchKeyByNameWithType(Object.ApplicationName, Object.ApplicationType);
		ApplicationToSupply = ApplicationsByNamesWithType.Get(Var_Key);
		If ApplicationToSupply = Undefined Then
			StandardProcessing = False;
			ShowMessageBox(, NStr("en = 'An application with the specified name and type cannot be determined automatically.';"));
			Return;
		EndIf;
		
		FillPropertyValues(Object, ApplicationToSupply);
		Object.UsageMode = ValueSelected;
		UsageModeOnChange(Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UsageModeOnChange(Item)
	
	SetVisibilityAndAvailability(ThisObject);
	FillSelectedApplicationAlgorithms();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetDeletionMark(Command)
	
	If Not Modified Then
		SetDeletionMarkCompletion();
		Return;
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("SetDeletionMarksAfterAnswerQuestion", ThisObject),
		NStr("en = 'To set the deletion mark, write the changes you have made.
		           |Write the data?';"), QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSelectedApplicationSettings(Presentation)
	
	SettingsToSupply = Catalogs.DigitalSignatureAndEncryptionApplications.ApplicationsSettingsToSupply();
	If TypeOf(Presentation) = Type("Structure") Then
		Rows = SettingsToSupply.FindRows(Presentation);
		SettingToSupply = ?(Rows.Count() = 0, Undefined, Rows[0]);
	Else
		SettingToSupply = SettingsToSupply.Find(Presentation, "Presentation");
	EndIf;
	
	If SettingToSupply <> Undefined Then
		FillPropertyValues(Object, SettingToSupply);
		Object.Description = SettingToSupply.Presentation;
	EndIf;
	
	SetTitleAutoSettings(SettingToSupply);
	FillAlgorithmsChoiceLists(SettingToSupply);
	
EndProcedure

&AtServer
Procedure SetTitleAutoSettings(SettingToSupply)
	
	If SettingToSupply = Undefined Then
		Items.DecorationLabelAutoSettings.Title = NStr("en = 'This application cannot be determined automatically';");
		Return;
	EndIf;
	
	Items.DecorationLabelAutoSettings.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Algorithms used in this application:
			|Signing algorithm: %1
			|Hashing algorithm: %2
			|Encryption algorithm: %3';"), SettingToSupply.SignAlgorithm, SettingToSupply.HashAlgorithm,
			SettingToSupply.EncryptAlgorithm);
			
EndProcedure

&AtServer
Procedure FillAlgorithmsChoiceLists(SettingToSupply)
	
	SuppliedSignatureAlgorithms.Clear();
	SuppliedHashAlgorithms.Clear();
	SuppliedEncryptionAlgorithms.Clear();
	
	If SettingToSupply = Undefined Then
		Return;
	EndIf;
	
	SuppliedSignatureAlgorithms.LoadValues(SettingToSupply.SignAlgorithms);
	SuppliedHashAlgorithms.LoadValues(SettingToSupply.HashAlgorithms);
	SuppliedEncryptionAlgorithms.LoadValues(SettingToSupply.EncryptAlgorithms);
	
EndProcedure

&AtClient
Procedure FillSelectedApplicationAlgorithms(OnOpen = False)
	
	If Object.UsageMode = PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.Automatically") Then
		Return;
	EndIf;
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"FillAlgorithmsForSelectedApplicationAfterAttachCryptographyExtension", ThisObject));
	
EndProcedure

// Continues the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillAlgorithmsForSelectedApplicationAfterAttachCryptographyExtension(Attached, Context) Export
	
	If Not Attached Then
		FillSelectedApplicationAlgorithmsAfterGetInformation(Undefined, Context);
		Return;
	EndIf;
	
	DigitalSignatureInternalClient.ToObtainThePathToTheProgram(
		New NotifyDescription("FillInTheAlgorithmsOfTheSelectedProgramAfterGettingTheProgramPath",
			ThisObject, Context), Object.Ref);
	
EndProcedure

// Continues the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillInTheAlgorithmsOfTheSelectedProgramAfterGettingTheProgramPath(DescriptionOfWay, Context) Export
	
	CryptoTools.BeginGettingCryptoModuleInformation(New NotifyDescription(
			"FillSelectedApplicationAlgorithmsAfterGetInformation", ThisObject, ,
			"FillAlgorithmsForSelectedApplicationAfterGetDataError", ThisObject),
		Object.ApplicationName, DescriptionOfWay.ApplicationPath, Object.ApplicationType);
	
EndProcedure

// Continues the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillAlgorithmsForSelectedApplicationAfterGetDataError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	FillSelectedApplicationAlgorithmsAfterGetInformation(Undefined, Context);
	
EndProcedure

// Continues the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillSelectedApplicationAlgorithmsAfterGetInformation(ModuleInfo, Context) Export
	
	// 
	// 
	
	If ModuleInfo <> Undefined
	   And Object.ApplicationName <> ModuleInfo.Name
	   And Not DigitalSignatureInternalClient.RequiresThePathToTheProgram() Then
		
		ModuleInfo = Undefined;
	EndIf;
	
	If ModuleInfo = Undefined Then
		Items.SignAlgorithm.ChoiceList.LoadValues(
			SuppliedSignatureAlgorithms.UnloadValues());
		
		Items.HashAlgorithm.ChoiceList.LoadValues(
			SuppliedHashAlgorithms.UnloadValues());
		
		Items.EncryptAlgorithm.ChoiceList.LoadValues(
			SuppliedEncryptionAlgorithms.UnloadValues());
	Else
		Items.SignAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInfo.SignAlgorithms));
		
		Items.HashAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInfo.HashAlgorithms));
		
		Items.EncryptAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInfo.EncryptAlgorithms));
	EndIf;
	
	Items.SignAlgorithm.DropListButton =
		Items.SignAlgorithm.ChoiceList.Count() <> 0;
	
	Items.HashAlgorithm.DropListButton =
		Items.HashAlgorithm.ChoiceList.Count() <> 0;
	
	Items.EncryptAlgorithm.DropListButton =
		Items.EncryptAlgorithm.ChoiceList.Count() <> 0;
	
EndProcedure

&AtClient
Procedure SetDeletionMarksAfterAnswerQuestion(Response, Context) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	SetDeletionMarkCompletion();
	
EndProcedure
	
&AtClient
Procedure SetDeletionMarkCompletion()
	
	Object.DeletionMark = Not Object.DeletionMark;
	Write();
	
	Notify("Write_DigitalSignatureAndEncryptionApplications", New Structure, Object.Ref);
	
EndProcedure

&AtClient
Procedure HandlerWaitingToStartTheProgramAfterOpening()
	
	ShowChooseFromMenu(New NotifyDescription("AfterApplicationChoice", ThisObject),
		Items.Description.ChoiceList, Items.Description);
	
EndProcedure

&AtClient
Procedure AfterApplicationChoice(SelectedElement, Context) Export
	
	If SelectedElement = Undefined Then
		Return
	EndIf;
	
	DescriptionChoiceProcessing(Items.Description, SelectedElement.Value, False);
	
EndProcedure

// Continues the DescriptionChoiceProcessing procedure.
&AtClient
Procedure IdleHandlerDescriptionChoiceProcessing()
	
	FillSelectedApplicationSettings(SelectedApplicationDescription);
	FillSelectedApplicationAlgorithms();
	
EndProcedure

&AtClient
Procedure WaitHandlerNameAndTypeOnChange()
	
	If ValueIsFilled(Object.ApplicationName) And ValueIsFilled(Object.ApplicationType) Then
		FillSelectedApplicationSettings(New Structure("ApplicationName, ApplicationType",
			Object.ApplicationName, Object.ApplicationType));
	EndIf;
	
	FillSelectedApplicationAlgorithms();
	
EndProcedure

&AtServer
Function ThereIsAClientOrServerVOS(Setting)
	
	Return Not Setting.NotInWindows
	      And (Common.IsWindowsClient() Or Common.IsWindowsServer())
	    Or Not Setting.NotOnLinux
	      And (Common.IsLinuxClient() Or Common.IsLinuxServer())
	    Or Not Setting.NotInMacOS
	      And Common.IsMacOSClient();
	
EndFunction

&AtClientAtServerNoContext
Procedure SetVisibilityAndAvailability(Form)
	
	SettingsAvailability = Not DigitalSignatureInternalClientServer.AreAutomaticSettingsUsed(
		Form.Object.UsageMode);
	
	Form.Items.SignAlgorithm.Visible = SettingsAvailability;
	Form.Items.HashAlgorithm.Visible = SettingsAvailability;
	Form.Items.EncryptAlgorithm.Visible = SettingsAvailability;
	Form.Items.SignAlgorithm.Visible = SettingsAvailability;
	Form.Items.DecorationLabelAutoSettings.Visible = Not SettingsAvailability;
	
	If Not SettingsAvailability Then
		Form.Items.Description.ReadOnly = True;
		Form.Items.ApplicationName.ReadOnly = True;
		Form.Items.ApplicationType.ReadOnly = True;
	EndIf;
		
EndProcedure

#EndRegion
