///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region ForCallsFromOtherSubsystems

// 
// 
//
// Parameters:
//  Form - See DataProcessor.SSLAdministrationPanel.Form.InternetSupportAndServices
//  Cancel - Boolean
//  StandardProcessing - Boolean
//
Procedure OnlineSupportAndServicesOnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Items = Form.Items;
	
	Items.ClassifiersGroup.Visible = Not Form.DataSeparationEnabled;
	
	If Items.ClassifiersGroup.Visible Then
		
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			If Not ModuleAddressClassifierInternal.YouHaveRightToChangeAddressInformation() Then
				Items.AddressClassifierSettings.Visible = False;
			EndIf;
		Else
			Items.AddressClassifierSettings.Visible = False;
		EndIf;
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesInternal = Common.CommonModule("CurrencyRateOperationsInternal");
		Items.ImportCurrenciesRatesDataProcessorGroup.Visible =
			  Not Form.DataSeparationEnabled
			And Not Form.IsStandaloneWorkplace
			And ModuleCurrencyExchangeRatesInternal.HasRightToChangeExchangeRates();
	Else
		Items.ImportCurrenciesRatesDataProcessorGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		Items.DeclensionsGroup.Visible =
			  Not Form.DataSeparationEnabled
			And Not Form.IsStandaloneWorkplace
			And Form.IsSystemAdministrator;
		If Items.DeclensionsGroup.Visible Then
			ModuleObjectsPresentationsDeclension     = Common.CommonModule("ObjectPresentationDeclension");
			Form.UseMorpherDeclinationService =
				ModuleObjectsPresentationsDeclension.UseMorpherDeclinationService();
		EndIf;
	Else
		Items.DeclensionsGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Items.MonitoringCenterGroup.Visible = Form.IsSystemAdministrator;
		If Form.IsSystemAdministrator Then
			MonitoringCenterParameters = GetMonitoringCenterParameters();
			Form.MonitoringCenterAllowSendingData = GetDataSendingRadioButtons(
				MonitoringCenterParameters.EnableMonitoringCenter,
				MonitoringCenterParameters.ApplicationInformationProcessingCenter);
			
			ServiceParameters = New Structure("Server, ResourceAddress, Port");
			If Form.MonitoringCenterAllowSendingData = 0 Then
				ServiceParameters.Server = MonitoringCenterParameters.DefaultServer;
				ServiceParameters.ResourceAddress = MonitoringCenterParameters.DefaultResourceAddress;
				ServiceParameters.Port = MonitoringCenterParameters.DefaultPort;
			ElsIf Form.MonitoringCenterAllowSendingData = 1 Then
				ServiceParameters.Server = MonitoringCenterParameters.Server;
				ServiceParameters.ResourceAddress = MonitoringCenterParameters.ResourceAddress;
				ServiceParameters.Port = MonitoringCenterParameters.Port;
			ElsIf Form.MonitoringCenterAllowSendingData = 2 Then
				ServiceParameters = Undefined;
			EndIf;
			
			If ServiceParameters <> Undefined Then
				If ServiceParameters.Port = 80 Then
					Schema = "http://";
					Port = "";
				ElsIf ServiceParameters.Port = 443 Then
					Schema = "https://";
					Port = "";
				Else
					Schema = "http://";
					Port = ":" + Format(ServiceParameters.Port, "NZ=0; NG=");
				EndIf;
				
				Form.MonitoringCenterServiceAddress = Schema
					+ ServiceParameters.Server
					+ Port
					+ "/"
					+ ServiceParameters.ResourceAddress;
			Else
				Form.MonitoringCenterServiceAddress = "";
			EndIf;
			
			Items.MonitoringCenterServiceAddress.Enabled = (Form.MonitoringCenterAllowSendingData = 1);
			Items.MonitoringCenterSettings.Enabled = (Form.MonitoringCenterAllowSendingData <> 2);
			Items.SendContactInformationGroup.Visible =
				(MonitoringCenterParameters.ContactInformationRequest <> 2);
		EndIf;
	Else
		Items.MonitoringCenterGroup.Visible = False;
	EndIf;
	
	AddInsGroupVisibility = False;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then 
		
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		AddInsGroupVisibility = ModuleAddInsInternal.CanImportFromPortal();
		
	EndIf;
	
	Items.AddInsGroup.Visible = AddInsGroupVisibility;
	
	ApplicationSettingsOverridable.OnlineSupportAndServicesOnCreateAtServer(Form);
	
	Items.ConversationsGroup.Visible = Common.SubsystemExists("StandardSubsystems.Conversations");
	
EndProcedure

// 
//
// Parameters:
//  Form - See DataProcessor.SSLAdministrationPanel.Form.InternetSupportAndServices
//  ConstantName - String -
//  NewValue - Arbitrary
//
Procedure OnlineSupportAndServicesOnConstantChange(Form, ConstantName, NewValue) Export
	
	SaveConstantValue(ConstantName, NewValue);
	
	If ConstantName = "UseMorpherDeclinationService"
		And Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		
		ModuleObjectsPresentationsDeclension = Common.CommonModule("ObjectPresentationDeclension");
		ModuleObjectsPresentationsDeclension.SetAvailabilityOfDeclensionService(True);
		
	EndIf;
	
	RefreshReusableValues();
	
EndProcedure

// 
// 
// 
//
// Parameters:
//  Form - See DataProcessor.SSLAdministrationPanel.Form.InternetSupportAndServices
//  Item - FormField
//  OperationParametersList - Structure of KeyAndValue -
//  
//
Procedure OnlineSupportAndServicesAllowSendDataOnChange(Form, Item, OperationParametersList) Export
	Var RunResult;
	
	Items = Form.Items;
	
	Items.MonitoringCenterServiceAddress.Enabled = (Form.MonitoringCenterAllowSendingData = 1);
	Items.MonitoringCenterSettings.Enabled = (Form.MonitoringCenterAllowSendingData <> 2);
	If Form.MonitoringCenterAllowSendingData = 2 Then
		MonitoringCenterParameters =
			New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", False, False);
	ElsIf Form.MonitoringCenterAllowSendingData = 1 Then
		MonitoringCenterParameters =
			New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", False, True);
	ElsIf Form.MonitoringCenterAllowSendingData = 0 Then
		MonitoringCenterParameters =
			New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", True, False);
	EndIf;
	
	Form.MonitoringCenterServiceAddress = GetServiceAddress(Form.MonitoringCenterAllowSendingData);
	
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	ModuleMonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	
	EnableMonitoringCenter = MonitoringCenterParameters.EnableMonitoringCenter;
	ApplicationInformationProcessingCenter = MonitoringCenterParameters.ApplicationInformationProcessingCenter;
	
	Result = GetDataSendingRadioButtons(EnableMonitoringCenter, ApplicationInformationProcessingCenter);
	If Result = 0 Or Result = 1 Then
		RunResult = ModuleMonitoringCenterInternal.StartDiscoveryPackageSending();
		SchedJob = ModuleMonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
		ModuleMonitoringCenterInternal.SetDefaultScheduleExternalCall(SchedJob);
	ElsIf Result = 2 Then
		ModuleMonitoringCenterInternal.DeleteScheduledJobExternalCall("StatisticsDataCollectionAndSending");
		ModuleMonitoringCenterInternal.DisableEventLogging();
	EndIf;
	
	OperationParametersList.Insert("RunResult", RunResult);
	
EndProcedure

// 
// 
//
// Parameters:
//  Form - See DataProcessor.SSLAdministrationPanel.Form.InternetSupportAndServices
//  Item - FormField
//
Procedure OnlineSupportAndServicesMonitoringCenterOnChange(Form, Item) Export
	
	Try
		AddressStructure1 = CommonClientServer.URIStructure(Form.MonitoringCenterServiceAddress);
		AddressStructure1.Insert("SecureConnection", AddressStructure1.Schema = "https");
		If Not ValueIsFilled(AddressStructure1.Port) Then
			AddressStructure1.Port = ?(AddressStructure1.Schema = "https", 443, 80);
		EndIf;
	Except
		// 
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Service address %1 is not a valid web service address for sending application usage reports.';"),
			Form.MonitoringCenterServiceAddress);
		Raise(ErrorDescription);
	EndTry;
	
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("Server", AddressStructure1.Host);
	MonitoringCenterParameters.Insert("ResourceAddress", AddressStructure1.PathAtServer);
	MonitoringCenterParameters.Insert("Port", AddressStructure1.Port);
	MonitoringCenterParameters.Insert("SecureConnection", AddressStructure1.SecureConnection);
	
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	ModuleMonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region MonitoringCenter

Function GetDataSendingRadioButtons(EnableMonitoringCenter, ApplicationInformationProcessingCenter)
	State = ?(EnableMonitoringCenter, "1", "0") + ?(ApplicationInformationProcessingCenter, "1", "0");
	
	If State = "00" Then
		Result = 2;
	ElsIf State = "01" Then
		Result = 1;
	ElsIf State = "10" Then
		Result = 0;
	ElsIf State = "11" Then
		// 
	EndIf;
	
	Return Result;
EndFunction

Function GetServiceAddress(MonitoringCenterAllowSendingData)
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	
	ServiceParameters = New Structure("Server, ResourceAddress, Port");
	
	If MonitoringCenterAllowSendingData = 0 Then
		ServiceParameters.Server = MonitoringCenterParameters.DefaultServer;
		ServiceParameters.ResourceAddress = MonitoringCenterParameters.DefaultResourceAddress;
		ServiceParameters.Port = MonitoringCenterParameters.DefaultPort;
	ElsIf MonitoringCenterAllowSendingData = 1 Then
		ServiceParameters.Server = MonitoringCenterParameters.Server;
		ServiceParameters.ResourceAddress = MonitoringCenterParameters.ResourceAddress;
		ServiceParameters.Port = MonitoringCenterParameters.Port;
	ElsIf MonitoringCenterAllowSendingData = 2 Then
		ServiceParameters = Undefined;
	EndIf;
	
	If ServiceParameters <> Undefined Then
		If ServiceParameters.Port = 80 Then
			Schema = "http://";
			Port = "";
		ElsIf ServiceParameters.Port = 443 Then
			Schema = "https://";
			Port = "";
		Else
			Schema = "http://";
			Port = ":" + Format(ServiceParameters.Port, "NZ=0; NG=");
		EndIf;
		
		ServiceAddress = Schema + ServiceParameters.Server + Port + "/" + ServiceParameters.ResourceAddress;
	Else
		ServiceAddress = "";
	EndIf;
	
	Return ServiceAddress;
EndFunction

Function GetMonitoringCenterParameters()
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	MonitoringCenterParameters = ModuleMonitoringCenterInternal.GetMonitoringCenterParametersExternalCall();
	
	DefaultServiceParameters = ModuleMonitoringCenterInternal.GetDefaultParametersExternalCall();
	MonitoringCenterParameters.Insert("DefaultServer", DefaultServiceParameters.Server);
	MonitoringCenterParameters.Insert("DefaultResourceAddress", DefaultServiceParameters.ResourceAddress);
	MonitoringCenterParameters.Insert("DefaultPort", DefaultServiceParameters.Port);
	
	Return MonitoringCenterParameters;
EndFunction

#EndRegion

Procedure SaveConstantValue(ConstantName, NewValue)
	
	ConstantManager = Constants[ConstantName];
	
	If ConstantManager.Get() <> NewValue Then
		ConstantManager.Set(NewValue);
	EndIf;
	
EndProcedure

#EndRegion