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
	Parameters.Property("HideWarning", HideWarning);
	Parameters.Property("OccurrenceDate", OccurrenceDate);
	Parameters.Property("MetadataObject", MetadataObject);
	Parameters.Property("UniqueKey", InformationRegisterRecordUniqueKey);
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

&AtServer
Procedure BeforeCloseAtServer()
	
	If Not HideFromListFlagUpdateRequired
		And Not CommentUpdateRequired Then
		
		Return;
		
	EndIf;
	
	RecordManager = InformationRegisters.DataExchangeResults.CreateRecordManager();
	RecordManager.IssueType = WarningType;
	RecordManager.InfobaseNode = InfobaseNode;
	RecordManager.MetadataObject = MetadataObject;
	RecordManager.ObjectWithIssue = ObjectWithIssue;
	RecordManager.UniqueKey = InformationRegisterRecordUniqueKey;
	
	RecordManager.Read(); // 
	If Not RecordManager.Selected() Then
		
		// 
		Return;
		
	EndIf;

	RecordManager.OccurrenceDate = OccurrenceDate;
	RecordManager.Comment = WarningComment;
	RecordManager.IsSkipped = HideWarning;
	RecordManager.Write(True);
	
EndProcedure

#EndRegion
