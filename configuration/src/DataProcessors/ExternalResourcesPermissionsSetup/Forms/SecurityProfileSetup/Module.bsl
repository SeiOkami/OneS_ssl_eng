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
	
	If Not SafeModeManagerInternal.SecurityProfilesUsageAvailable() Then
		Raise NStr("en = 'Warning! Use of security profiles is not available for this configuration';");
	EndIf;
	
	If Not SafeModeManagerInternal.CanSetUpSecurityProfiles() Then
		Raise NStr("en = 'Warning! Setting of security profiles is unavailable.';");
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Raise NStr("en = 'Insufficient access rights';");
	EndIf;
	
	// Visibility settings at startup.
	ReadSecurityProfilesUsageMode();
	
	// Update items states.
	SetAvailability();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProfileSecurityUsageModeOnChange(Item)
	
	Try
		
		StartApplyingSecurityProfilesSettings(UUID);
		
		PreviousMode = CurrentSecurityProfilesUsageMode();
		NewMode = ProfileSecurityUsageMode;
		
		If (PreviousMode <> NewMode) Then
			
			If (PreviousMode = 2 Or NewMode = 2) Then
				
				ClosingNotification1 = New NotifyDescription("AfterCloseSecurityProfileCustomizationWizard", ThisObject, True);
				
				If NewMode = 2 Then
					
					ExternalResourcesPermissionsSetupClient.StartEnablingSecurityProfilesUsage(ThisObject, ClosingNotification1);
					
				Else
					
					ExternalResourcesPermissionsSetupClient.StartDisablingSecurityProfilesUsage(ThisObject, ClosingNotification1);
					
				EndIf;
				
			Else
				
				EndApplyingSecurityProfilesSettings();
				SetAvailability("ProfileSecurityUsageMode");
				
			EndIf;
			
		EndIf;
		
	Except
		
		ReadSecurityProfilesUsageMode();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure InfobaseSecurityProfileOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RequiredPermissions(Command)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	
	OpenForm(
		"Report.ExternalResourcesInUse.ObjectForm",
		ReportParameters);
	
EndProcedure

&AtClient
Procedure RestoreSecurityProfiles(Command)
	
	Try
		
		StartApplyingSecurityProfilesSettings(UUID);
		ClosingNotification1 = New NotifyDescription("AfterCloseSecurityProfileCustomizationWizard", ThisObject, True);
		ExternalResourcesPermissionsSetupClient.StartRestoringSecurityProfiles(ThisObject, ClosingNotification1);
		
	Except
		
		ReadSecurityProfilesUsageMode();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessor(Command)
	
	SafeModeManagerClient.OpenExternalDataProcessorOrReport(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterCloseSecurityProfileCustomizationWizard(Result, ClientApplicationRestartRequired) Export
	
	If Result = DialogReturnCode.OK Then
		EndApplyingSecurityProfilesSettings();
	EndIf;
	
	ReadSecurityProfilesUsageMode();
	
	If Result = DialogReturnCode.OK And ClientApplicationRestartRequired Then
		Terminate(True);
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadSecurityProfilesUsageMode()
	
	ProfileSecurityUsageMode = CurrentSecurityProfilesUsageMode();
	SetAvailability("ProfileSecurityUsageMode");
	
EndProcedure

&AtServer
Function CurrentSecurityProfilesUsageMode()
	
	If SafeModeManagerInternal.SecurityProfilesUsageAvailable() And GetFunctionalOption("UseSecurityProfiles") Then
		
		If Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get() Then
			
			Result = 2; // 
			
		Else
			
			Result = 1; // 
			
		EndIf;
		
	Else
		
		Result = 0; // 
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure StartApplyingSecurityProfilesSettings(Val UUID)
	
	If Not SafeModeManagerInternal.SecurityProfilesUsageAvailable() Then
		Raise NStr("en = 'Warning! Enabling automatic permission request is not available.';");
	EndIf;
	
	SetExclusiveMode(True);
	
EndProcedure

&AtServer
Procedure EndApplyingSecurityProfilesSettings()
	
	If ProfileSecurityUsageMode = 0 Then
		
		Constants.UseSecurityProfiles.Set(False);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(False);
		Constants.InfobaseSecurityProfile.Set("");
		
	ElsIf ProfileSecurityUsageMode = 1 Then
		
		Constants.UseSecurityProfiles.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(False);
		
	ElsIf ProfileSecurityUsageMode = 2 Then
		
		Constants.UseSecurityProfiles.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
	EndIf;
	
	If ExclusiveMode() Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	
	If ShouldRefreshInterface Then
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

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	ConstantName = SaveAttributeValue(DataPathAttribute);
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	Return ConstantName;
	
EndFunction

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
	
	If Users.IsFullUser(, True) Then
		
		If DataPathAttribute = "ProfileSecurityUsageMode" Or DataPathAttribute = "" Then
			
			Items.InfobaseSecurityProfileGroup.Enabled = ProfileSecurityUsageMode > 0;
			
			Items.InfobaseSecurityProfile.ReadOnly = (ProfileSecurityUsageMode = 2);
			Items.SecurityProfilesRestorationGroup.Enabled = (ProfileSecurityUsageMode = 2);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
