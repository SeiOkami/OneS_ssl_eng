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
	
	If Parameters.Property("FileOwner") Then
		Record.FileOwner = Parameters.FileOwner;
	EndIf;
	
	If Parameters.Property("FileOwnerType") Then
		Record.FileOwnerType = Parameters.FileOwnerType;
	EndIf;
	
	If Parameters.Property("IsFile") Then
		Record.IsFile = Parameters.IsFile;
	EndIf;
	
	If ValueIsFilled(Record.Account) Then
		Items.Account.ReadOnly = True;
	EndIf;
	
	OwnerPresentation = Common.SubjectString(Record.FileOwner);
	
	Title = NStr("en = 'File synchronization setting:';")
		+ " " + OwnerPresentation;
	
EndProcedure

#EndRegion