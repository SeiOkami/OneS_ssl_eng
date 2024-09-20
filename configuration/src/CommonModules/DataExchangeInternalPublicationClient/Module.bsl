///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Procedure HandleURLInNodeForm(Form, URL, StandardProcessing) Export
	
 	StandardProcessing = False;
	
	If URL = "FormSynchronizationLoop" Then
		
		OpenForm("InformationRegister.SynchronizationCircuit.Form.SynchronizationLoop");
		
	ElsIf URL = "FormObjectsUnregisteredWhileLooping" Then
		
		FormParameters = New Structure("InfobaseNode", Form.Object.Ref);
		OpenForm("InformationRegister.ObjectsUnregisteredDuringLoop.ListForm", 
			FormParameters, Form);
			
	ElsIf URL = "FormMigrationToExchangeOverInternetWizardInternalPublication" Then
		
		FormParameters = New Structure("ExchangeNode", Form.Object.Ref);
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.MigrationToExchangeOverInternet", 
			FormParameters, Form,,,,, FormWindowOpeningMode.LockOwnerWindow);
		
	ElsIf URL = "ShouldMutePromptToMigrateToWebService" Then
		
		CommonClientServer.SetFormItemProperty(Form.Items, 
			"MigrationToWebService", "Visible", False);
		
		DataExchangeInternalPublicationServerCall.SettingFlagShouldMutePromptToMigrateToWebService(Form.Object.Ref, True);
	
	EndIf;
	
EndProcedure

#EndRegion