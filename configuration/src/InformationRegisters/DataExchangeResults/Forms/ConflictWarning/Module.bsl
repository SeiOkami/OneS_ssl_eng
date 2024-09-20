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
	
	Parameters.Property("ObjectWithIssue", ObjectWithIssue);
	Parameters.Property("LongDesc", LongDesc);
	Parameters.Property("WarningType", WarningType);
	Parameters.Property("InfobaseNode", InfobaseNode);
	Parameters.Property("VersionFromOtherApplication", VersionFromOtherApplication);
	Parameters.Property("ThisApplicationVersion", ThisApplicationVersion);
	Parameters.Property("VersionFromOtherApplicationAccepted", VersionFromOtherApplicationAccepted);
	Parameters.Property("OccurrenceDate", OccurrenceDate);
	Parameters.Property("HideWarning", HideWarning);
	Parameters.Property("WarningComment", WarningComment);
	
	HideFromListFlagUpdateRequired = False;
	CommentUpdateRequired = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChangeThePictureOfTheScenery()
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HideWarningOnChange(Item)
	
	HideFromListFlagUpdateRequired = True;
	
	If HideWarning Then
		
		Items.PictureDecoration.Picture = PictureLib.Information32;
		
	Else
		
		Items.PictureDecoration.Picture = PictureLib.Error32;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectWithIssueClick(Item, StandardProcessing)
	
	HideFromListFlagUpdateRequired = True;
	
EndProcedure

&AtClient
Procedure WarningCommentOnChange(Item)
	
	CommentUpdateRequired = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowDifferences(Command)
	
	If ThisApplicationVersion = 0
		Or VersionFromOtherApplication = 0 Then
		
		CommonClient.MessageToUser(NStr("en = 'There must be two object versions for comparison.';"), CommonClient.DefaultLanguageCode());
		Return;
		
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(VersionFromOtherApplication);
	VersionsToCompare.Add(ThisApplicationVersion);
	
	OpenVersionComparisonReport(ObjectWithIssue, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenVersionInThisApplication(Command)
	
	If Not ValueIsFilled(ObjectWithIssue)
		 Then
		
		Return;
		
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(ThisApplicationVersion);
	
	OpenVersionComparisonReport(ObjectWithIssue, VersionsToCompare);

EndProcedure

&AtClient
Procedure OpenOtherApplicationVersion(Command)
	
	If Not ValueIsFilled(ObjectWithIssue) Then
		
		Return;
		
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(VersionFromOtherApplication);
	
	OpenVersionComparisonReport(ObjectWithIssue, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure ReviseConflictResolutionResult(Command)
	
	If VersionFromOtherApplicationAccepted Then
		
		QueryText = NStr("en = 'Do you want to replace the version from another application with the version from this application?';");
		
	Else
		
		QueryText = NStr("en = 'Do you want to replace the version from this application with the version from another application?';");
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("CompleteTheRevisionOfTheResultOfTheCollision", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure CompleteTheRevisionOfTheResultOfTheCollision(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	ClearMessages();
	
	ErrorMessage = "";
	AcceptRejectVersionAtServer(ErrorMessage);
	
	If IsBlankString(ErrorMessage) Then
		
		HideWarning = True;
		HideFromListFlagUpdateRequired = True;
		
	Else
		
		ShowMessageBox(Undefined, ErrorMessage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	BeforeCloseAtServer();
	
	If HideFromListFlagUpdateRequired
		Or CommentUpdateRequired Then
		
		Close(New Structure("TheListNeedsToBeUpdated", True));
		
	Else
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeThePictureOfTheScenery()
	
	If HideWarning Then
		
		Items.PictureDecoration.Picture = PictureLib.Information32;
		
	Else
		
		Items.PictureDecoration.Picture = PictureLib.Error32;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		ModuleObjectsVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
		ModuleObjectsVersioningClient.OpenVersionComparisonReport(Ref, VersionsToCompare);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AcceptRejectVersionAtServer(ErrorMessage)
	
	If Not Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		Return;
		
	EndIf;
	
	ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
	Try
		
		ModuleObjectsVersioning.OnStartUsingNewObjectVersion(ObjectWithIssue, VersionFromOtherApplication);
		
	Except
		
		ObjectPresentation	= ?(Common.RefExists(ObjectWithIssue), ObjectWithIssue, ObjectWithIssue.Metadata());
		ExceptionText			= ErrorProcessing.BriefErrorDescription(ErrorInfo());
		TextTemplate1			= NStr("en = 'Cannot accept the object version ""%1"" due to:%2 %3.';", Common.DefaultLanguageCode());
		ExceptionText			= StringFunctionsClientServer.SubstituteParametersToString(TextTemplate1, ObjectPresentation, Chars.LF, ExceptionText);
		
		Common.MessageToUser(ExceptionText);
		
	EndTry;
	
EndProcedure

&AtServer
Procedure BeforeCloseAtServer()
	
	If Not Common.SubsystemExists("StandardSubsystems.ObjectsVersioning")
		Or (Not HideFromListFlagUpdateRequired 
			And Not CommentUpdateRequired) Then
		
		Return;
		
	EndIf;
	
	RegisterEntryParameters = New Structure;
	RegisterEntryParameters.Insert("Ref", ObjectWithIssue);
	RegisterEntryParameters.Insert("VersionNumber", VersionFromOtherApplication);
	RegisterEntryParameters.Insert("VersionIgnored", HideWarning);
	RegisterEntryParameters.Insert("Comment", WarningComment);
	
	ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
	ModuleObjectsVersioning.ChangeTheSyncWarning(RegisterEntryParameters, True);
	
EndProcedure

#EndRegion
