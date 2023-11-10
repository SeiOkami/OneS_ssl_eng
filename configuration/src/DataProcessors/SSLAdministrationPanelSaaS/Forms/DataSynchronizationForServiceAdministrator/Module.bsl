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
Var RefreshInterface;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Users.IsFullUser(Undefined, True, False) Then
		Raise NStr("en = 'Insufficient rights to administer data synchronization between applications. ';");
	EndIf;
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Raise NStr("en = 'Administration functionality of data synchronization is not supported in SaaS.';");
	EndIf;
	
	SetPrivilegedMode(True);
	
	// 
	Items.ApplySettingsGroup.Visible = Common.IsWebClient();
	Items.StandaloneMode.Visible = StandaloneModeInternal.StandaloneModeSupported();
	Items.TemporaryServerClusterDirectoriesGroup.Visible = (Not Common.FileInfobase())
		And Users.IsFullUser(, True);
	
	// Update items states.
	SetAvailability();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	#If Not WebClient Then
	RefreshApplicationInterface();
	#EndIf
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HowToApplySettingsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	RefreshInterface = True;
	AttachIdleHandler("RefreshApplicationInterface", 0.1, True);
EndProcedure

&AtClient
Procedure DataExchangeMessageDirectoryForWindowsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessageDirectoryForLinuxOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DataSynchronizationMonitor(Command)
	
	OpenForm("CommonForm.DataSynchronizationMonitorSaaS",, ThisObject);
	
EndProcedure

&AtClient
Procedure ExchangeTransportSettings(Command)
	
	TransportSettingsRegisterName = "MessageExchangeTransportSettings";
	TransportSettingsFormName = "InformationRegister.[TransportSettingsRegisterName].ListForm";
	TransportSettingsFormName = StrReplace(TransportSettingsFormName,
		"[TransportSettingsRegisterName]", TransportSettingsRegisterName);
	
	OpenForm(TransportSettingsFormName, , ThisObject);
	
EndProcedure

&AtClient
Procedure DataAreasExchangeTransportSettings(Command)
	
	OpenForm("InformationRegister.DataAreasExchangeTransportSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataExchangeRules(Command)
	
	OpenForm("InformationRegister.DataExchangeRules.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationOnChange(Item)
	
	If ConstantsSet.UseDataSynchronization = False Then
		ConstantsSet.UseOfflineModeSaaS = False;
		ConstantsSet.UseDataSynchronizationSaaSWithLocalApplication = False;
		ConstantsSet.UseDataSynchronizationSaaSWithWebApplication = False;
		ConstantsSet.UsePerformanceMonitoringOfDataSynchronization = False;
	EndIf;
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseOfflineModeSaaSOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationSaaSWithWebApplicationOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationSaaSWithLocalApplicationOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UsePerformanceEvaluationOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, InterfaceUpdateIsRequired = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	
	If InterfaceUpdateIsRequired Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	ConstantName = SaveAttributeValue(DataPathAttribute);
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		Return "";
	EndIf;
	
	ConstantName = NameParts[1];
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If DataPathAttribute = "ConstantsSet.UseDataSynchronization" Or DataPathAttribute = "" Then
		Items.DataSynchronizationSubordinateGroup.Enabled           = ConstantsSet.UseDataSynchronization;
		Items.DataSynchronizationDataSynchronizationMonitorGroup.Enabled = ConstantsSet.UseDataSynchronization;
		Items.TemporaryServerClusterDirectoriesGroup.Enabled             = ConstantsSet.UseDataSynchronization;
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UsePerformanceMonitoringOfDataSynchronization"
		Or DataPathAttribute = "ConstantsSet.UseDataSynchronization"
		Or DataPathAttribute = "")  Then
		Items.ExchangeSessions.Enabled = ConstantsSet.UsePerformanceMonitoringOfDataSynchronization;
	EndIf;
	
EndProcedure



#EndRegion
