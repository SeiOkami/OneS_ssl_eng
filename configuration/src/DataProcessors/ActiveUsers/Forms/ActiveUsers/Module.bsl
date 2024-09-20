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
Var AdministrationParameters, PromptForIBAdministrationParameters;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	NotifyOnClose = Parameters.NotifyOnClose;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SessionWithoutSeparators = ModuleSaaSOperations.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	If Common.FileInfobase()
		Or Not ((Not SessionWithoutSeparators And Users.IsFullUser())
		Or Users.IsFullUser(, True)) Then
		
		Items.TerminateSession.Visible = False;
		Items.TerminateSessionContext.Visible = False;
		
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		Items.UsersListDataSeparation.Visible = False;
	EndIf;
	
	SortColumnName = "WorkStart";
	SortDirection = "Asc";
	
	FillConnectionFilterSelectionList();
	If Items.FilterApplicationName.ChoiceList.FindByValue(Parameters.FilterApplicationName) <> Undefined Then
		FilterApplicationName = Parameters.FilterApplicationName;
	EndIf;
	
	FillUserList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	PromptForIBAdministrationParameters = True;
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	If NotifyOnClose Then
		NotifyOnClose = False;
		NotifyChoice(Undefined);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ApplicationNameFilterOnChange(Item)
	FillList();
EndProcedure

#EndRegion

#Region UsersListFormTableItemEventHandlers

&AtClient
Procedure UsersListSelection(Item, RowSelected, Field, StandardProcessing)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TerminateSession(Command)
	
	SelectedLinesNumber = Items.UsersList.SelectedRows.Count();
	
	If SelectedLinesNumber = 0 Then
		ShowMessageBox(,NStr("en = 'Please select users.';"));
		Return;
	ElsIf SelectedLinesNumber = 1 Then
		If Items.UsersList.CurrentData.Session = InfoBaseSessionNumber Then
			ShowMessageBox(,NStr("en = 'Cannot close the current session. To exit the application, close its main window.';"));
			Return;
		EndIf;
	EndIf;
	
	SessionsNumbers = New Array;
	For Each RowID In Items.UsersList.SelectedRows Do
		SessionNumber = UsersList.FindByID(RowID).Session;
		If SessionNumber = InfoBaseSessionNumber Then
			Continue;
		EndIf;
		SessionsNumbers.Add(SessionNumber);
	EndDo;
	
	If CommonClient.DataSeparationEnabled()
	   And CommonClient.SeparatedDataUsageAvailable() Then
		
		StandardProcessing = True;
		NotificationAfterSessionTermination = New NotifyDescription(
			"AfterSessionTermination", ThisObject, New Structure("SessionsNumbers", SessionsNumbers));
		SSLSubsystemsIntegrationClient.OnEndSessions(ThisObject, SessionsNumbers, StandardProcessing, NotificationAfterSessionTermination);
		
	Else
		If PromptForIBAdministrationParameters Then
			NotifyDescription = New NotifyDescription("TerminateSessionContinuation", ThisObject, SessionsNumbers);
			FormCaption = NStr("en = 'Close session';");
			NoteLabel = NStr("en = 'To end the session, enter
				|the server cluster administration parameters';");
			IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, False, True, AdministrationParameters, FormCaption, NoteLabel);
		Else
			TerminateSessionContinuation(AdministrationParameters, SessionsNumbers);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshExecute()
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLog()
	
	SelectedRows = Items.UsersList.SelectedRows;
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Select users to view their event log records.';"));
		Return;
	EndIf;
	
	FilterForSpecifiedUsers = New ValueList;
	For Each RowID In SelectedRows Do
		UserRow1 = UsersList.FindByID(RowID);
		UserName = UserRow1.UserName;
		If FilterForSpecifiedUsers.FindByValue(UserName) = Undefined Then
			FilterForSpecifiedUsers.Add(UserRow1.UserName, UserRow1.UserName);
		EndIf;
	EndDo;
	
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", FilterForSpecifiedUsers));
	
EndProcedure

&AtClient
Procedure SortAsc()
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDesc()
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure OpenUser(Command)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersList.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersList.Session");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	InfoBaseSessionNumber = InfoBaseSessionNumber();
	ItemFilter.RightValue = InfoBaseSessionNumber;

	Item.Appearance.SetParameterValue("Font", StyleFonts.MainListItem);

EndProcedure

&AtClient
Procedure FillList()
	
	// Saving the current session data that will be used to restore the row position.
	CurrentSession = Undefined;
	CurrentData = Items.UsersList.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUserList();
	
	// Restoring the current row position based on the saved session data.
	If CurrentSession <> Undefined Then
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Session", CurrentSession);
		FoundSessions = UsersList.FindRows(TheStructureOfTheSearch);
		If FoundSessions.Count() = 1 Then
			Items.UsersList.CurrentRow = FoundSessions[0].GetID();
			Items.UsersList.SelectedRows.Clear();
			Items.UsersList.SelectedRows.Add(Items.UsersList.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	
	Column = Items.UsersList.CurrentItem;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
	
EndProcedure

&AtServer
Procedure FillConnectionFilterSelectionList()
	ApplicationNames = New Array;
	ApplicationNames.Add("1CV8");
	ApplicationNames.Add("1CV8C");
	ApplicationNames.Add("WebClient");
	ApplicationNames.Add("Designer");
	ApplicationNames.Add("COMConnection");
	ApplicationNames.Add("WSConnection");
	ApplicationNames.Add("BackgroundJob");
	ApplicationNames.Add("SystemBackgroundJob");
	ApplicationNames.Add("SrvrConsole");
	ApplicationNames.Add("COMConsole");
	ApplicationNames.Add("JobScheduler");
	ApplicationNames.Add("Debugger");
	ApplicationNames.Add("OpenIDProvider");
	ApplicationNames.Add("RAS");
	
	ChoiceList = Items.FilterApplicationName.ChoiceList;
	For Each ApplicationName In ApplicationNames Do
		ChoiceList.Add(ApplicationName, ApplicationPresentation(ApplicationName));
	EndDo;
EndProcedure

&AtServer
Procedure FillUserList()
	
	UsersList.Clear();
	
	If Not Common.DataSeparationEnabled()
	 Or Common.SeparatedDataUsageAvailable() Then
		
		Users.FindAmbiguousIBUsers(Undefined);
	EndIf;
	
	InfobaseSessions = GetInfoBaseSessions();
	ActiveUserCount = InfobaseSessions.Count();
	
	FilterApplicationNames = ValueIsFilled(FilterApplicationName);
	If FilterApplicationNames Then
		ApplicationNames = StrSplit(FilterApplicationName, ",");
	EndIf;
	
	UsersRefs = New Map;
	UsersIDs = New Array;
	For Each IBSession In InfobaseSessions Do
		If FilterApplicationNames
			And ApplicationNames.Find(IBSession.ApplicationName) = Undefined Then
			ActiveUserCount = ActiveUserCount - 1;
			Continue;
		EndIf;
		
		UserLine = UsersList.Add();
		
		UserLine.Package   = ApplicationPresentation(IBSession.ApplicationName);
		UserLine.WorkStart = IBSession.SessionStarted;
		UserLine.Computer    = IBSession.ComputerName;
		UserLine.Session        = IBSession.SessionNumber;
		UserLine.Join   = IBSession.ConnectionNumber;
		
		If TypeOf(IBSession.User) = Type("InfoBaseUser")
		   And ValueIsFilled(IBSession.User.Name) Then
			
			UserLine.User        = IBSession.User.Name;
			UserLine.UserName     = IBSession.User.Name;
			UsersIDs.Add(IBSession.User.UUID);
			UsersRefs[IBSession.User.UUID] = UserLine;
			
			If Common.DataSeparationEnabled() 
				And Users.IsFullUser(, True) Then
				
				UserLine.DataSeparation = DataSeparationValuesToString(
					IBSession.User.DataSeparation);
			EndIf;
			
		ElsIf Common.DataSeparationEnabled()
		        And Not Common.SeparatedDataUsageAvailable() Then
			
			UserLine.User       = Users.UnspecifiedUserFullName();
			UserLine.UserName    = "";
			UserLine.UserRef = Undefined;
		Else
			UnspecifiedProperties = UsersInternal.UnspecifiedUserProperties();
			UserLine.User       = UnspecifiedProperties.FullName;
			UserLine.UserName    = "";
			UserLine.UserRef = UnspecifiedProperties.Ref;
		EndIf;

		If IBSession.SessionNumber = InfoBaseSessionNumber Then
			UserLine.UserPictureNumber = 0;
		Else
			UserLine.UserPictureNumber = 1;
		EndIf;
		
	EndDo;

	PopulateRefsByIDs(UsersRefs, UsersIDs);
	UsersList.Sort(SortColumnName + " " + SortDirection);
	
EndProcedure

&AtServer
Function DataSeparationValuesToString(DataSeparation)
	
	Result = "";
	Value = "";
	If DataSeparation.Property("DataArea", Value) Then
		Result = String(Value);
	EndIf;
	
	HasOtherSeparators = False;
	For Each Separator In DataSeparation Do
		If Separator.Key = "DataArea" Then
			Continue;
		EndIf;
		If Not HasOtherSeparators Then
			If Not IsBlankString(Result) Then
				Result = Result + " ";
			EndIf;
			Result = Result + "(";
		EndIf;
		Result = Result + String(Separator.Value);
		HasOtherSeparators = True;
	EndDo;
	If HasOtherSeparators Then
		Result = Result + ")";
	EndIf;
	Return Result;
		
EndFunction

// Parameters:
//  UsersRefs - Map of KeyAndValue:
//    * Key - UUID
//    * Value - FormDataCollectionItem:
//      ** UserRef - 
//  UsersIDs - Array of UUID
//
&AtServerNoContext
Procedure PopulateRefsByIDs(UsersRefs, UsersIDs)

	// 
	If Common.DataSeparationEnabled() 
		And Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If UsersIDs.Count() = 0 Then
		Return;
	EndIf;

	QueryTextTemplate2 = "SELECT
		|	Users.Ref AS Ref,
		|	Users.IBUserID AS IBUserID
		|FROM
		|	&TableName AS Users
		|WHERE
		|	Users.IBUserID IN (&IDs)";
					
	QueryTextForSpecifiedUsers = StrReplace(QueryTextTemplate2, "&TableName", 
		Metadata.Catalogs.Users.FullName());
	Query = New Query(QueryTextForSpecifiedUsers);
	Query.Parameters.Insert("IDs", UsersIDs);
	
	Selection = Query.Execute().Select();
	Count = 0;
	While Selection.Next() Do
		UsersRefs[Selection.IBUserID].UserRef = Selection.Ref;
		Count = Count + 1;
	EndDo;
	
	If Count < UsersIDs.Count() Then
		If ExternalUsers.UseExternalUsers() Then
			ExternalUserQueryText = StrReplace(QueryTextTemplate2, "&TableName", 
				Metadata.Catalogs.ExternalUsers.FullName());
			Query.Text = ExternalUserQueryText;
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				UsersRefs[Selection.IBUserID].UserRef = Selection.Ref;
			EndDo;
		EndIf;
		
		For Each UserRef In UsersRefs Do
			If Not ValueIsFilled(UserRef.Key) Then
				UserRef.Value.UserRef = Catalogs.Users.EmptyRef();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenUserFromList()
	
	CurrentData = Items.UsersList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	User = CurrentData.UserRef;
	If ValueIsFilled(User) Then
		OpeningParameters = New Structure("Key", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			OpenForm("Catalog.Users.ObjectForm", OpeningParameters);
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			OpenForm("Catalog.ExternalUsers.ObjectForm", OpeningParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TerminateSessionContinuation(Result, SessionsArray) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AdministrationParameters = Result;
	
	SessionStructure = New Structure;
	SessionStructure.Insert("Property", "Number");
	SessionStructure.Insert("ComparisonType", ComparisonType.InList);
	SessionStructure.Insert("Value", SessionsArray);
	Filter = CommonClientServer.ValueInArray(SessionStructure);
	
	Try
		DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
	Except
		PromptForIBAdministrationParameters = True;
		Raise;
	EndTry;
	
	PromptForIBAdministrationParameters = False;
	
	AfterSessionTermination(DialogReturnCode.OK, New Structure("SessionsNumbers", SessionsArray));
	
EndProcedure

&AtClient
Procedure AfterSessionTermination(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		If AdditionalParameters.SessionsNumbers.Count() > 1 Then
			
			NotificationText1 = NStr("en = 'Sessions %1 are closed.';");
			SessionsNumbers = StrConcat(AdditionalParameters.SessionsNumbers, ",");
			NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(NotificationText1, SessionsNumbers);
			ShowUserNotification(NStr("en = 'Sessions closed';"),, NotificationText1);
			
		Else
			
			NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Session %1 is closed.';"), AdditionalParameters.SessionsNumbers[0]);
			ShowUserNotification(NStr("en = 'Session closed';"),, NotificationText1);
			
		EndIf;
		
		FillList();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
	
	ClusterAdministration.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

#EndRegion
