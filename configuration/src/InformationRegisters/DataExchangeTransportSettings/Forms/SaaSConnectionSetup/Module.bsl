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
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	SetPrivilegedMode(True);
	
	AccountPasswordRecoveryAddress = Parameters.AccountPasswordRecoveryAddress;
	AutomaticSynchronizationSetup = Parameters.AutomaticSynchronizationSetup;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible = True;
	Else
		Items.InternetAccessParameters.Visible = False;
	EndIf;
	
	If Not IsBlankString(Record.WSUserName) Then
		
		User = Users.FindByName(Record.WSUserName);
		
	EndIf;
	
	For Each SynchronizationUser In DataSynchronizationUsers() Do
		
		Items.User.ChoiceList.Add(SynchronizationUser.User, SynchronizationUser.Presentation);
		
	EndDo;
	
	Items.ForgotPassword.Visible = Not IsBlankString(AccountPasswordRecoveryAddress);
	
	If ValueIsFilled(Record.Peer) Then
		Password = Common.ReadDataFromSecureStorage(Record.Peer, "WSPassword");
		WSPassword = ?(ValueIsFilled(Password), ThisObject.UUID, "");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	TestServiceConnection(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If AutomaticSynchronizationSetup Then
		
		Notify("Write_ExchangeTransportSettings",
			New Structure("AutomaticSynchronizationSetup"));
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.WSRememberPassword = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WSPasswordOnChange(Item)
	WSPasswordChanged = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OpenInstructionHowToChangeDataSynchronizationPassword(AccountPasswordRecoveryAddress);
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParametersForm();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure TestServiceConnection(Cancel)
	
	SetPrivilegedMode(True);
	
	// Determine the user name.
	UserProperties = Users.IBUserProperies(
		Common.ObjectAttributeValue(User, "IBUserID"));
	If UserProperties <> Undefined Then
		Record.WSUserName = UserProperties.Name
	EndIf;
	
	// Testing connection to the correspondent.
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	If WSPasswordChanged Then
		ConnectionParameters.WSPassword = WSPassword;
	Else
		ConnectionParameters.WSPassword = Common.ReadDataFromSecureStorage(Record.Peer, "WSPassword");
	EndIf;
	
	UserMessage = "";
	If Not DataExchangeWebService.CorrespondentConnectionEstablished(Record.Peer, ConnectionParameters, UserMessage) Then
		Common.MessageToUser(UserMessage,, "WSPassword",, Cancel);
	Else
		// Connection check is completed successfully. Writing password if it has been changed
		If WSPasswordChanged Then
			Common.WriteDataToSecureStorage(Record.Peer, WSPassword, "WSPassword");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function DataSynchronizationUsers()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // 
	Result.Columns.Add("Presentation");
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.Description AS Presentation,
	|	Users.IBUserID AS IBUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.IsInternal
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.IBUserID) Then
			
			IBUser = InfoBaseUsers.FindByUUID(Selection.IBUserID);
			
			If IBUser <> Undefined
				And DataExchangeServer.DataSynchronizationPermitted(IBUser) Then
				
				FillPropertyValues(Result.Add(), Selection);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
