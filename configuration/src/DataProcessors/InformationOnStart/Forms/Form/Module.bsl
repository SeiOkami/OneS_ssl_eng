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
	
	CurrentLineIndex = -1;
	BaseConfiguration = StandardSubsystemsServer.IsBaseConfigurationVersion();
	
	StandardPrefix = GetInfoBaseURL() + "/";
	IsWebClient = StrFind(StandardPrefix, "http://") > 0;
	If IsWebClient Then
		LocalizationCode = CurrentLocaleCode();
		StandardPrefix = StandardPrefix + LocalizationCode + "/";
	EndIf;
	
	DataSaveRight = AccessRight("SaveUserData", Metadata);
	
	If BaseConfiguration Or Not DataSaveRight Then
		Items.ShowAtStartup.Visible = False;
	Else
		ShowAtStartup = InformationOnStart.ShowAtStartup();
	EndIf;
	
	If Not PrepareFormData() Then
		OpeningDenied = True;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If OpeningDenied Then
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WebContentOnClick(Item, EventData, StandardProcessing)
	If EventData.Property("href") And ValueIsFilled(EventData.href) Then
		PageNameToOpen = TrimAll(EventData.href);
		Protocol = Upper(StrLeftBeforeChar(PageNameToOpen, ":"));
		If Protocol <> "HTTP" And Protocol <> "HTTPS" And Protocol <> "E1C" Then
			Return; // Not a reference.
		EndIf;
		
		PageNameToOpen = DecodedString(PageNameToOpen);
		StandardPrefixAbbreviated = GetInfoBaseURL();
		
		If StrFind(PageNameToOpen, StandardPrefix) > 0 Then
			PageNameToOpen = StrReplace(PageNameToOpen, StandardPrefix, "");
			If StrStartsWith(PageNameToOpen, "#") Then
				Return;
			EndIf;
			ViewPage("ByInternalRef", PageNameToOpen);
		ElsIf StrFind(PageNameToOpen, StrReplace(StandardPrefix, " ", "%20")) > 0 Then
			PageNameToOpen = StrReplace(PageNameToOpen, "%20", " ");
			PageNameToOpen = StrReplace(PageNameToOpen, StandardPrefix, "");
			If StrStartsWith(PageNameToOpen, "#") Then
				Return;
			EndIf;
			ViewPage("ByInternalRef", PageNameToOpen);
		ElsIf StrFind(PageNameToOpen, StandardPrefixAbbreviated) > 0 Then
			PageNameToOpen = StrReplace(PageNameToOpen, StandardPrefixAbbreviated, "");
			If StrStartsWith(PageNameToOpen, "#") Then
				Return;
			EndIf;
			ViewPage("ByInternalRef", PageNameToOpen);
		Else
			FileSystemClient.OpenURL(PageNameToOpen);
		EndIf;
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure ShowAtStartupOnChange(Item)
	If Not BaseConfiguration And DataSaveRight Then
		SaveCheckBoxState(ShowAtStartup);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoForward(Command)
	ViewPage("GoForward", Undefined);
EndProcedure

&AtClient
Procedure Back(Command)
	ViewPage("Back", Undefined);
EndProcedure

&AtClient
Procedure Attachable_GoToPage(Command)
	ViewPage("CommandFromCommandBar", Command.Name);
EndProcedure

#EndRegion

#Region Private

&AtServer
Function PrepareFormData()
	CurrentSectionDescription = "-";
	CurrentSubmenu = Undefined;
	SubmenuAdded = 0;
	PackagesWithMinimumPriority = New Array;
	MainLocked = False;
	
	UseRegisterCache = True;
	If Common.DebugMode()
		Or Lower(StrLeftBeforeChar(FormName, ".")) = Lower("ExternalDataProcessor") Then
		UseRegisterCache = False;
	EndIf;
	
	If UseRegisterCache Then
		SetPrivilegedMode(True);
		RegisterRecord = InformationRegisters.InformationPackagesOnStart.Get(New Structure("Number", 0));
		PagesPackages = RegisterRecord.Content.Get();
		SetPrivilegedMode(False);
		If PagesPackages = Undefined Then
			UseRegisterCache = False;
		EndIf;
	EndIf;
	
	If Not UseRegisterCache Then
		PagesPackages = InformationOnStart.PagesPackages(FormAttributeToValue("Object"));
	EndIf;
	
	Information = InformationOnStart.PreparePagesPackageForOutput(PagesPackages, BegOfDay(CurrentSessionDate()));
	If Information.PreparedPackages.Count() = 0
		Or Information.MinPriority = 100 Then
		Return False;
	EndIf;
	
	PreparedPackages.Load(Information.PreparedPackages);
	PreparedPackages.Sort("Section");
	For Each PagesPackage In PreparedPackages Do
		PagesPackage.FormCaption = NStr("en = 'Information';");
		
		If PagesPackage.Priority = Information.MinPriority Then
			PackagesWithMinimumPriority.Add(PagesPackage);
		EndIf;
		
		If StrStartsWith(PagesPackage.Section, "_") Then
			SubmenuNumber = Mid(PagesPackage.Section, 2);
			If SubmenuNumber = "0" Then
				PagesPackage.Section = "";
				If Not MainLocked Then
					PagesPackage.Id = "MainPage";
					MainLocked = True;
					Continue;
				EndIf;
				CurrentSubmenu = Items.NoSubmenu;
			Else
				SubmenuName = "Popup" + SubmenuNumber;
				CurrentSubmenu = Items.Find(SubmenuName);
				If CurrentSubmenu = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Group ""%1"" is not found';"), SubmenuName);
				EndIf;
				PagesPackage.Section = CurrentSubmenu.Title;
			EndIf;
		ElsIf CurrentSectionDescription <> PagesPackage.Section Then
			CurrentSectionDescription = PagesPackage.Section;
			
			IsMain1 = (PagesPackage.Section = NStr("en = 'Main';"));
			If IsMain1 And Not MainLocked Then
				PagesPackage.Id = "MainPage";
				MainLocked = True;
				Continue;
			EndIf;
			
			If IsMain1 Or PagesPackage.Section = "" Then
				CurrentSubmenu = Items.NoSubmenu;
			Else
				SubmenuAdded = SubmenuAdded + 1;
				SubmenuName = "Popup" + String(SubmenuAdded);
				CurrentSubmenu = Items.Find(SubmenuName);
				If CurrentSubmenu = Undefined Then
					CurrentSubmenu = Items.Add(SubmenuName, Type("FormGroup"), Items.TopBar);
					CurrentSubmenu.Type = FormGroupType.Popup;
				EndIf;
				CurrentSubmenu.Title = PagesPackage.Section;
			EndIf;
		EndIf;
		
		If CurrentSubmenu <> Items.NoSubmenu Then
			PagesPackage.FormCaption = PagesPackage.FormCaption + ": " + PagesPackage.Section +" / "+ PagesPackage.StartPageDescription;
		EndIf;
		
		CommandName = "AddedElement_" + PagesPackage.Id;
		
		Command = Commands.Add(CommandName);
		Command.Action = "Attachable_GoToPage";
		Command.Title = PagesPackage.StartPageDescription;
		
		Button = Items.Add(CommandName, Type("FormButton"), CurrentSubmenu);
		Button.CommandName = CommandName;
		
	EndDo;
	
	Items.MainPage.Visible = MainLocked;
	
	// Determine a package for display.
	RNG = New RandomNumberGenerator;
	LineNumber = RNG.RandomNumber(1, PackagesWithMinimumPriority.Count());
	StartPagesPackage = PackagesWithMinimumPriority[LineNumber-1];
	
	// Read package from the register.
	If UseRegisterCache Then
		Filter = New Structure("Number", StartPagesPackage.NumberInRegister);
		SetPrivilegedMode(True);
		RegisterRecord = InformationRegisters.InformationPackagesOnStart.Get(Filter);
		PackageFiles = RegisterRecord.Content.Get();
		SetPrivilegedMode(False);
	Else
		PackageFiles = Undefined;
	EndIf;
	If PackageFiles = Undefined Then
		PackageFiles = InformationOnStart.ExtractPackageFiles(FormAttributeToValue("Object"), StartPagesPackage.TemplateName);
	EndIf;
	
	If PackageFiles = Undefined Then
		Return False;
	EndIf;
	
	// Prepare a package for display.
	PlacePackagePages(StartPagesPackage, PackageFiles);
	
	// Display the first page.
	If Not ViewPage("CommandFromAddedItemsTable", StartPagesPackage) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function ViewPage(ActionType, Parameter = Undefined)
	Var PagesPackage, PageAddress, NewHistoryRow, NewRowIndex;
	
	If ActionType = "ByInternalRef" Then
		
		PageNameToOpen = Parameter;
		HistoryRow = BrowseHistory.Get(CurrentLineIndex);
		PagesPackage = PreparedPackages.FindByID(HistoryRow.IDOfPackage);
		
		Search = New Structure("RelativeName", StrReplace(PageNameToOpen, "\", "/"));
		
		FoundItems = PagesPackage.WebPages.FindRows(Search);
		If FoundItems.Count() = 0 Then
			Return False;
		EndIf;
		PageAddress = FoundItems[0].Address;
		
	ElsIf ActionType = "Back" Or ActionType = "GoForward" Then
		
		HistoryRow = BrowseHistory.Get(CurrentLineIndex);
		
		NewRowIndex = CurrentLineIndex + ?(ActionType = "Back", -1, +1);
		NewHistoryRow = BrowseHistory[NewRowIndex];
		
		PagesPackage = PreparedPackages.FindByID(NewHistoryRow.IDOfPackage);
		PageAddress = NewHistoryRow.PageAddress;
		
	ElsIf ActionType = "CommandFromCommandBar" Then
		
		CommandName = Parameter;
		FoundItems = PreparedPackages.FindRows(New Structure("Id", StrReplace(CommandName, "AddedElement_", "")));
		If FoundItems.Count() = 0 Then
			Return False;
		EndIf;
		PagesPackage = FoundItems[0];
		
	ElsIf ActionType = "CommandFromAddedItemsTable" Then
		
		PagesPackage = Parameter;
		
	Else
		
		Return False;
		
	EndIf;
	
	// Add to the temporary storage.
	If PagesPackage.HomePageURL = "" Then
		PackageFiles = InformationOnStart.ExtractPackageFiles(FormAttributeToValue("Object"), PagesPackage.TemplateName);
		PlacePackagePages(PagesPackage, PackageFiles);
	EndIf;
	
	// Get the address of page placement in the temporary storage.
	If PageAddress = Undefined Then
		PageAddress = PagesPackage.HomePageURL;
	EndIf;
	
	// Register in view history.
	If NewHistoryRow = Undefined Then
		
		NewHistoryRowStructure = New Structure("IDOfPackage, PageAddress");
		NewHistoryRowStructure.IDOfPackage = PagesPackage.GetID();
		NewHistoryRowStructure.PageAddress = PageAddress;
		
		FoundItems = BrowseHistory.FindRows(NewHistoryRowStructure);
		For Each NewHistoryRowDuplicate In FoundItems Do
			BrowseHistory.Delete(NewHistoryRowDuplicate);
		EndDo;
		
		NewHistoryRow = BrowseHistory.Add();
		FillPropertyValues(NewHistoryRow, NewHistoryRowStructure);
		
	EndIf;
	
	If NewRowIndex = Undefined Then
		NewRowIndex = BrowseHistory.IndexOf(NewHistoryRow);
	EndIf;
	
	If ActionType = "ByInternalRef" And CurrentLineIndex <> -1 And CurrentLineIndex <> NewRowIndex - 1 Then
		IndexesDifferences = CurrentLineIndex - NewRowIndex;
		Move = IndexesDifferences + ?(IndexesDifferences < 0, 1, 0);
		BrowseHistory.Move(NewRowIndex, Move);
		NewRowIndex = NewRowIndex + Move;
	EndIf;
	
	CurrentLineIndex = NewRowIndex;
	
	// 
	Items.FormBack.Enabled = (CurrentLineIndex > 0);
	Items.FormGoForward.Enabled = (CurrentLineIndex < BrowseHistory.Count() - 1);
	
	// Set web content and form header.
	WebContent = GetFromTempStorage(PageAddress);
	Title = PagesPackage.FormCaption;
	
	Return True;
EndFunction

&AtServer
Procedure PlacePackagePages(PagesPackage, PackageFiles)
	
	Columns = PackageFiles.Images.Columns; // ValueTableColumnCollection
	Columns.Add("Address", New TypeDescription("String"));
	
	// Register pictures and references to the online help page.
	For Each WebPage In PackageFiles.WebPages Do
		HTMLText = WebPage.Data;
		
		// Register pictures.
		Length = StrLen(WebPage.RelativeDirectory);
		For Each Picture In PackageFiles.Images Do
			// Store pictures to a temporary storage.
			If IsBlankString(Picture.Address) Then
				Picture.Address = PutToTempStorage(Picture.Data, UUID);
			EndIf;
			// 
			// 
			PathToPicture = Picture.RelativeName;
			If Length > 0 And StrStartsWith(PathToPicture, WebPage.RelativeDirectory) Then
				PathToPicture = Mid(PathToPicture, Length + 1);
			EndIf;
			// 
			HTMLText = StrReplace(HTMLText, PathToPicture, Picture.Address);
		EndDo;
		
		// 
		HTMLText = StrReplace(HTMLText, "v8config://", StandardPrefix + "e1cib/helpservice/topics/v8config/");
		
		// Register online help hyperlinks.
		AddOnlineHelpURLs(HTMLText, PagesPackage.WebPages);
		
		// Add HTML content to temporary storage.
		WebPageRegistration = PagesPackage.WebPages.Add();
		WebPageRegistration.RelativeName     = WebPage.RelativeName;
		WebPageRegistration.RelativeDirectory = WebPage.RelativeDirectory;
		WebPageRegistration.Address                = PutToTempStorage(HTMLText, UUID);
		
		// Register home page.
		If WebPageRegistration.RelativeName = PagesPackage.HomePageFileName Then
			PagesPackage.HomePageURL = WebPageRegistration.Address;
		EndIf;
	EndDo;
EndProcedure

&AtServerNoContext
Procedure SaveCheckBoxState(ShowAtStartup)
	Common.CommonSettingsStorageSave("InformationOnStart", "Show", ShowAtStartup);
	If Not ShowAtStartup Then
		NextShowDate = BegOfDay(CurrentSessionDate() + 14*24*60*60);
		Common.CommonSettingsStorageSave("InformationOnStart", "NextShowDate", NextShowDate);
	EndIf;
EndProcedure

&AtServer
Procedure AddOnlineHelpURLs(HTMLText, WebPages)
	OnlineHelpURLPrefix = """" + StandardPrefix + "e1cib/helpservice/topics/v8config/v8cfgHelp/";
	Balance = HTMLText;
	While True Do
		PrefixPosition = StrFind(Balance, OnlineHelpURLPrefix);
		If PrefixPosition = 0 Then
			Break;
		EndIf;
		Balance = Mid(Balance, PrefixPosition + 1);
		
		QuoteCharPosition = StrFind(Balance, """");
		If QuoteCharPosition = 0 Then
			Break;
		EndIf;
		Hyperlink = Left(Balance, QuoteCharPosition - 1);
		Balance = Mid(Balance, QuoteCharPosition + 1);
		
		RelativeName = StrReplace(Hyperlink, StandardPrefix, "");
		Content = Hyperlink;
		
		FileLocation = WebPages.Add();
		FileLocation.RelativeName = RelativeName;
		FileLocation.Address = PutToTempStorage(Content, UUID);
		FileLocation.RelativeDirectory = "";
	EndDo;
EndProcedure

&AtClientAtServerNoContext
Function StrLeftBeforeChar(String, Separator, Balance = Undefined)
	Position = StrFind(String, Separator);
	If Position = 0 Then
		StringBeforeDot = String;
		Balance = "";
	Else
		StringBeforeDot = Left(String, Position - 1);
		Balance = Mid(String, Position + StrLen(Separator));
	EndIf;
	Return StringBeforeDot;
EndFunction

&AtServer
Function DecodedString(String)
	
	Return DecodeString(String, StringEncodingMethod.URLEncoding);
	
EndFunction

#EndRegion
