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
	
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	HasRightsToAddApp = AccessRight("Insert", Metadata.Catalogs.DigitalSignatureAndEncryptionApplications);
	
	If ValueIsFilled(Parameters.Application) Then
		FillPropertyValues(ThisObject, Parameters.Application);
		
		Title = Parameters.Application.Presentation;
		
		ApplicationPath = Parameters.Application.PathToAppAuto;
		Items.ApplicationPath.Visible = ValueIsFilled(ApplicationPath);
		
		PathToAppAtServer = Parameters.Application.PathToAppAuto;
		Items.PathToAppAtServer.Visible = ValueIsFilled(PathToAppAtServer);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)

	AddToCatalog(PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.SetupDone"));

EndProcedure

&AtClient
Procedure Disable(Command)

	AddToCatalog(PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.NotUsed"));

EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AddToCatalog(UsageMode)
	
	If Not HasRightsToAddApp Then

		ShowMessageBox( , NStr("en = 'To change the application settings, contact the administrator.';"));

	ElsIf IsSubordinateDIBNode Then

		ShowMessageBox( , NStr("en = 'To change the application settings, add it to the catalog.
					 |Add the application in the infobase master node.';"));

	Else
	
		FormParameters = New Structure("Application, UsageMode", Parameters.Application, UsageMode);
		OpenForm("Catalog.DigitalSignatureAndEncryptionApplications.ObjectForm", FormParameters,,,,,,
			FormWindowOpeningMode.Independent);
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion