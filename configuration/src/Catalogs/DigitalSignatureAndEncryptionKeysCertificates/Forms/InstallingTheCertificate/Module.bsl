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
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ChoiceList = Items.InstallationOption.ChoiceList;
	ChoiceList.Clear();
	
	If Not ValueIsFilled(Parameters.InstallationOptions) Then
		InstallationOptions = CertificateInstallationOptions();
		For Each CurrentVariantOfSetting In InstallationOptions Do
			ChoiceList.Add(CurrentVariantOfSetting.Value, CurrentVariantOfSetting.Presentation);
		EndDo;
	ElsIf Parameters.InstallationOptions = "Container" Then
		ChoiceList.Add("Container", NStr("en = 'Container and personal storage';"));
	ElsIf TypeOf(Parameters.InstallationOptions) = Type("String") Then
		ChoiceList.Add(Parameters.InstallationOptions);
	Else
		For Each CurrentVariantOfSetting In Parameters.InstallationOptions Do
			ChoiceList.Add(CurrentVariantOfSetting.Value, CurrentVariantOfSetting.Presentation);
		EndDo;
	EndIf;
	
	InstallationOption = ChoiceList[0].Value;
	
	CertificateBinaryData_ = Undefined;
	If IsTempStorageURL(Parameters.Certificate) Then
		CertificateBinaryData_ = GetFromTempStorage(Parameters.Certificate);
	ElsIf ValueIsFilled(Parameters.Certificate) Then
		CertificateBinaryData_ = Base64Value(Parameters.Certificate);
	EndIf;
	
	If CertificateBinaryData_ <> Undefined Then
		CertificateProperties = DigitalSignature.CertificateProperties(
			New CryptoCertificate(CertificateBinaryData_));
		DigitalSignatureInternalClientServer.FillCertificateDataDetails(
			DetailsOfCertificateData, CertificateProperties);
	EndIf;
	
	Items.DecorationCurrentContainer.Visible = False;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	InstallationOptionOnChange(Undefined);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InstallationOptionOnChange(Item)
	
	If InstallationOption = "Container" Then
		Items.GroupContainers.Visible = True;
		Items.ContainersRefresh.Visible = True;
		If Containers.Count() = 0 Then
			AttachIdleHandler("FindContainers", 0.1, True);
		EndIf;
	Else
		Items.GroupContainers.Visible = False;
		Items.ContainersRefresh.Visible = False;
	EndIf;
	
	Items.WarningDecoration.Visible = Upper(InstallationOption) = "ROOT";
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	AttachIdleHandler("FindContainers", 0.1, True);
	
EndProcedure

&AtClient
Procedure Set(Command)
	
	CertificateInstallationParameters = DigitalSignatureInternalClient.CertificateInstallationParameters(Parameters.Certificate);
	CertificateInstallationParameters.Form = ThisObject;
	CertificateInstallationParameters.CompletionNotification2 = New NotifyDescription("AfterInstallingTheCertificate", ThisObject, CertificateInstallationParameters);
	
	If InstallationOption = "Container" Then
		
		CurrentData = Items.Containers.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("en = 'Select a container';"));
			Return;
		EndIf;
		
		ContainerProperties = DigitalSignatureInternalClient.ContainerNewProperties();
		FillPropertyValues(ContainerProperties, CurrentData);
		CertificateInstallationParameters.ContainerProperties = ContainerProperties;
		CertificateInstallationParameters.Store = NStr("en = 'container';");
		
	Else
		
		ListItem = Items.InstallationOption.ChoiceList.FindByValue(InstallationOption);
		CertificateInstallationParameters.Store = New Structure("Value, Presentation", InstallationOption, ListItem.Presentation);
		
	EndIf;
	
	DigitalSignatureInternalClient.InstallCertificateAfterInstallationOptionSelected(CertificateInstallationParameters);
	
EndProcedure

&AtClient
Procedure ShowCertificateData(Command)
	
	DigitalSignatureClient.OpenCertificate(Parameters.Certificate, True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterInstallingTheCertificate(Result, Context) Export
	
	If Result.IsInstalledSuccessfully = True Then
		Close(Result);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("WarningTitle", NStr("en = 'Cannot install the certificate.';"));
		FormParameters.Insert("ErrorTextClient", Result.Message);
		
		OpenForm("CommonForm.ExtendedErrorPresentation",
			FormParameters, Context.Form,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Async Procedure FindContainers()
	
	Items.GroupContainers.CurrentPage = Items.UpdateOfTable;
	Containers.Clear();
	Items.DecorationCurrentContainer.Visible = False;
	Items.DecorationCurrentContainer.Title= "";
	
	ContainersByCertificate = Await DigitalSignatureInternalClient.ContainersByCertificate(
		Parameters.Certificate); //  An array of See DigitalSignatureInternalClient.ContainerNewProperties
	
	For Each Container In ContainersByCertificate Do 
		NewRow = Containers.Add();
		FillPropertyValues(NewRow, Container);
		NewRow.ReadingTool = ReadingTool(Container.Name);
		If Container.IsCurrentContainer = True Then
			Items.DecorationCurrentContainer.Visible = True;
			Items.DecorationCurrentContainer.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The certificate is installed in the container: %1';"), Container.Name);
		EndIf;
	EndDo;
	
	Items.GroupContainers.CurrentPage = Items.TableContainers;
	If ContainersByCertificate.Count() = 0 Then
		Items.DecorationCurrentContainer.Title = NStr("en = 'Appropriate containers to install the certificate are not found';");
	EndIf;
	
EndProcedure

&AtClient
Function ReadingTool(Val NameOfContainer)
	
	NameOfContainer = Upper(NameOfContainer);
	
	If StrStartsWith(NameOfContainer, "\\.\REGISTRY") Then
		Return NStr("en = 'Registry';");
	EndIf;

	If StrStartsWith(NameOfContainer, "\\.\FAT12") Then
		Return StringFunctionsClientServer.SubstituteParametersToString( 
			NStr("en = 'Hard drive %1';"), Mid(NameOfContainer, 11, 1));
	EndIf;
	
	If StrStartsWith(NameOfContainer, "\\.\HDIMAGE") Then
		Return NStr("en = 'Disk';");
	EndIf;
	
	Return "";
	
EndFunction

&AtServer
Function CertificateInstallationOptions()
	
	ValueList = New ValueList;
	ValueList.Add("MY", NStr("en = 'Personal certificate storage';"));
	ValueList.Add("CA", NStr("en = 'Intermediate certificates';"));
	ValueList.Add("ROOT", NStr("en = 'Trusted root certificates';"));
	ValueList.Add("Container", NStr("en = 'Container and personal storage';"));
	Return ValueList;
	
EndFunction

#EndRegion
