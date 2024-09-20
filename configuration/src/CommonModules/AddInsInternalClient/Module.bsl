///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Procedure CheckTheLocationOfTheComponent(Id, Location) Export
	
	If StrStartsWith(Location, "e1cib/data/Catalog.AddIns.AddInStorage") Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaSOperations.AddInsSaaS") Then
		ModuleAddInsSaaSInternalClient = CommonClient.CommonModule("AddInsSaaSInternalClient");
		If ModuleAddInsSaaSInternalClient.IsComponentFromStorage(Location) Then
			Return;
		EndIf;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot attach the %1 add-in in the client application
		           |due to:
		           |Add-in
		           |%2 location is incorrect';"),
		Id, Location);

EndProcedure

// Parameters:
//  Notification - NotifyDescription
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Procedure CheckAddInAvailability(Notification, Context) Export
	
	ThePathToTheLayoutToSearchForTheLatestVersion = Undefined;
	SearchForAComponentOfTheLatestVersion = ValueIsFilled(Context.OriginalLocation) And Not Context.ASearchForANewVersionHasBeenPerformed; 
	If SearchForAComponentOfTheLatestVersion Then
		ThePathToTheLayoutToSearchForTheLatestVersion = Context.OriginalLocation;
	EndIf;
	
	Information = AddInsInternalServerCall.SavedAddInInformation(
		Context.Id, Context.Version, ThePathToTheLayoutToSearchForTheLatestVersion);
	
	Context.Location = Information.Location;
	
	// 
	// 
	// 
	// 
	// 
	
	Result = AddInAvailabilityResult();
	Result.TheComponentOfTheLatestVersion = Information.TheLatestVersionOfComponentsFromTheLayout;
	Result.Location = Information.Location;
	
	If Information.State = "DisabledByAdministrator" Then 
		
		Result.ErrorDescription = NStr("en = 'Disabled by administrator.';");
		ExecuteNotifyProcessing(Notification, Result);
		
	ElsIf Information.State = "NotFound1" Then 
		
		If Information.CanImportFromPortal 
			And Context.SuggestToImport Then 
			
			SearchContext = New Structure;
			SearchContext.Insert("Notification", Notification);
			SearchContext.Insert("Context", Context);
			
			NotificationForms = New NotifyDescription(
				"CheckAddInAvailabilityAfterSearchingAddInOnPortal",
				ThisObject, 
				SearchContext);
			
			ComponentSearchOnPortal(NotificationForms, Context);
			
		Else 
			Result.ErrorDescription = NStr("en = 'The add-in is missing from the list of allowed add-ins.';");
			ExecuteNotifyProcessing(Notification, Result);
		EndIf;
		
	Else
		
		If CurrentClientIsSupportedByAddIn(Information.Attributes) Then
			
			Result.Available = True;
			Result.Insert("Version", Information.Attributes.Version);
			
			If SearchForAComponentOfTheLatestVersion Then
				VersionParts = StrSplit(Result.Version, ".");
				If VersionParts.Count() = 4 Then
					// The component version is later than the template version.
					If CommonClientServer.CompareVersions(Result.Version,
						Result.TheComponentOfTheLatestVersion.Version) > 0 Then
						Result.TheComponentOfTheLatestVersion = New Structure("Id, Version, Location",
							Context.Id, Result.Version, Information.Location);
					EndIf;
				Else
					// 
					Result.TheComponentOfTheLatestVersion = New Structure("Id, Version, Location",
						Context.Id, Result.Version, Information.Location);
				EndIf;
			EndIf;
			
			ExecuteNotifyProcessing(Notification, Result);
			
		Else 
			
			NotificationForms = New NotifyDescription(
				"CheckAddInAvailabilityAfterDisplayingAvailableClientTypes",
				ThisObject,
				Notification);
			
			FormParameters = New Structure;
			FormParameters.Insert("ExplanationText", Context.ExplanationText);
			FormParameters.Insert("SupportedClients", Information.Attributes);
			
			OpenForm("CommonForm.CannotInstallAddIn",
				FormParameters,,,,, NotificationForms);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Function AddInAvailabilityCheckResult(Context) Export
	
	ThePathToTheLayoutToSearchForTheLatestVersion = Undefined;
	SearchForAComponentOfTheLatestVersion = ValueIsFilled(Context.OriginalLocation) And Not Context.ASearchForANewVersionHasBeenPerformed; 
	If SearchForAComponentOfTheLatestVersion Then
		ThePathToTheLayoutToSearchForTheLatestVersion = Context.OriginalLocation;
	EndIf;
	
	Information = AddInsInternalServerCall.SavedAddInInformation(
		Context.Id, Context.Version, ThePathToTheLayoutToSearchForTheLatestVersion);
	
	Context.Location = Information.Location;
	
	// 
	// 
	// 
	// 
	// 
	
	Result = AddInAvailabilityResult();
	Result.TheComponentOfTheLatestVersion = Information.TheLatestVersionOfComponentsFromTheLayout;
	Result.Location = Information.Location;
	
	If Information.State = "DisabledByAdministrator" Then 
		
		Result.ErrorDescription = NStr("en = 'Disabled by administrator.';");
		Return Result;
		
	ElsIf Information.State = "NotFound1" Then 
		
		Result.ErrorDescription = NStr("en = 'The add-in is missing from the list of allowed add-ins.';");
		
		Return Result;
		
	Else
		
		If CurrentClientIsSupportedByAddIn(Information.Attributes) Then
			
			Result.Available = True;
			Result.Insert("Version", Information.Attributes.Version);
			
			If SearchForAComponentOfTheLatestVersion Then
				VersionParts = StrSplit(Result.Version, ".");
				If VersionParts.Count() = 4 Then
					// 
					If CommonClientServer.CompareVersions(Result.Version,
						Result.TheComponentOfTheLatestVersion.Version) > 0 Then
						Result.TheComponentOfTheLatestVersion = New Structure("Id, Version, Location",
							Context.Id, Result.Version, Information.Location);
					EndIf;
				Else
					// 
					Result.TheComponentOfTheLatestVersion = New Structure("Id, Version, Location",
						Context.Id, Result.Version, Information.Location);
				EndIf;
			EndIf;
			
			Return Result;
		
		Else
			
			Result.ErrorDescription = TextCannotInstallAddIn(Context.ExplanationText);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// See StandardSubsystemsClient.OnReceiptServerNotification
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	If NameOfAlert <> "StandardSubsystems.AddIns" Then
		Return;
	EndIf;
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.SymbolicNames",
		New FixedMap(New Map));
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.Objects",
		New FixedMap(New Map));
	
EndProcedure

#EndRegion

#Region Private

#Region CheckAddInAvailability

Procedure CheckAddInAvailabilityAfterSearchingAddInOnPortal(Imported1, SearchContext) Export
	
	Notification = SearchContext.Notification;
	Context   = SearchContext.Context;
	
	If Imported1 Then
		Context.SuggestToImport = False;
		CheckAddInAvailability(Notification, Context);
	Else 
		ExecuteNotifyProcessing(Notification, AddInAvailabilityResult());
	EndIf;
	
EndProcedure

Procedure CheckAddInAvailabilityAfterDisplayingAvailableClientTypes(Result, Notification) Export
	
	ExecuteNotifyProcessing(Notification, AddInAvailabilityResult());
	
EndProcedure

// Returns:
//  Structure:
//   * Available - Boolean
//   * Version - String
//   * TheComponentOfTheLatestVersion - See StandardSubsystemsServer.TheComponentOfTheLatestVersion
//   * ErrorDescription - String
//   * Location - String
//
Function AddInAvailabilityResult() Export
	
	Result = New Structure;
	Result.Insert("Available", False);
	Result.Insert("Version", "");
	Result.Insert("TheComponentOfTheLatestVersion", Undefined);
	Result.Insert("ErrorDescription", "");
	Result.Insert("Location", "");
	
	Return Result;
	
EndFunction

// 
// 
// Parameters:
//  Attributes - See AddInsInternal.РеквизитыКомпоненты
// 
// Returns:
//  Boolean - 
//
Function CurrentClientIsSupportedByAddIn(Attributes)
	
	SystemInfo = New SystemInfo;
	Browser = Undefined;                        
#If WebClient Then
	String = SystemInfo.UserAgentInformation;
	If StrFind(String, "YaBrowser/") > 0 Then
		Browser = "YandexBrowser";
	ElsIf StrFind(String, "Chrome/") > 0 Then
		Browser = "Chrome";
	ElsIf StrFind(String, "MSIE") > 0 Then
		Browser = "MSIE";
	ElsIf StrFind(String, "Safari/") > 0 Then
		Browser = "Safari";
	ElsIf StrFind(String, "Firefox/") > 0 Then
		Browser = "Firefox";
	EndIf;
#EndIf
	
	If SystemInfo.PlatformType = PlatformType.Linux_x86 Then
		
		If Browser = Undefined Then
			Return Attributes.Linux_x86;
		EndIf;
		
		If Browser = "Firefox" Then
			Return Attributes.Linux_x86_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.Linux_x86_Chrome;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.Linux_x86_YandexBrowser;
		EndIf;
			
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		If Browser = Undefined Then
			Return Attributes.Linux_x86_64;
		EndIf;
		
		If Browser = "Firefox" Then
			Return Attributes.Linux_x86_64_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.Linux_x86_64_Chrome;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.Linux_x86_64_YandexBrowser;
		EndIf;
		
	ElsIf SystemInfo.PlatformType = PlatformType.MacOS_x86_64 Then
		
		If Browser = Undefined Then
			Return Attributes.MacOS_x86_64;
		EndIf;
		
		If Browser = "Safari" Then
			Return Attributes.MacOS_x86_64_Safari;
		EndIf;
		
		If Browser = "Firefox" Then
			Return Attributes.MacOS_x86_64_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.MacOS_x86_64_Chrome;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.MacOS_x86_64_YandexBrowser;
		EndIf;
		
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86 Then
		
		If Browser = Undefined Then
			Return Attributes.Windows_x86;
		EndIf;
		
		If Browser = "Firefox" Then
			Return Attributes.Windows_x86_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.Windows_x86_Chrome;
		EndIf;
		
		If Browser = "MSIE" Then
			Return Attributes.Windows_x86_MSIE;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.Windows_x86_YandexBrowser;
		EndIf;
		
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		
		If Browser = Undefined Then
			Return Attributes.Windows_x86_64;
		EndIf;
		
		If Browser = "Firefox" Then
			Return Attributes.Windows_x86_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.Windows_x86_Chrome;
		EndIf;
		
		If Browser = "MSIE" Then
			Return Attributes.Windows_x86_64_MSIE;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.Windows_x86_64_YandexBrowser;
		EndIf;
	
	ElsIf SystemInfo.PlatformType = PlatformType.MacOS_x86 Then
		// Browsers may misdefine the OS.
	
		If Browser = "Firefox" Then
			Return Attributes.MacOS_x86_64_Firefox;
		EndIf;
		
		If Browser = "Chrome" Then
			Return Attributes.MacOS_x86_64_Chrome;
		EndIf;
		
		If Browser = "YandexBrowser" Then
			Return Attributes.MacOS_x86_64_YandexBrowser;
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

Function TextCannotInstallAddIn(Val ExplanationText) Export

	If IsBlankString(ExplanationText) Then
		ExplanationText = NStr("en = 'Cannot install the add-in.';");
	EndIf;

	Return StringFunctionsClient.FormattedString(NStr("en = '%1
			  |
			  |The add-in is not supported 
			  |in the client application <b>%2</b>.
			  |Use <a href = about:blank>a supported client application</a> or contact the add-in developer.';"),
		ExplanationText, PresentationOfCurrentClient());
		
EndFunction

Function PresentationOfCurrentClient() 
	
	SystemInfo = New SystemInfo;
	
#If WebClient Then
	String = SystemInfo.UserAgentInformation;
	
	If StrFind(String, "Chrome/") > 0 Then
		Browser = NStr("en = 'Chrome';");
	ElsIf StrFind(String, "MSIE") > 0 Then
		Browser = NStr("en = 'Internet Explorer';");
	ElsIf StrFind(String, "Safari/") > 0 Then
		Browser = NStr("en = 'Safari';");
	ElsIf StrFind(String, "Firefox/") > 0 Then
		Browser = NStr("en = 'Firefox';");
	EndIf;
	
	Package = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'web client %1';"), Browser);
#ElsIf MobileAppClient Then
	Package = NStr("en = 'mobile application';");
#ElsIf MobileClient Then
	Package = NStr("en = 'mobile client';");
#ElsIf ThinClient Then
	Package = NStr("en = 'thin client';");
#ElsIf ThickClientOrdinaryApplication Then
	Package = NStr("en = 'thick client (standard application)';");
#ElsIf ThickClientManagedApplication Then
	Package = NStr("en = 'thick client';");
#EndIf
	
	If SystemInfo.PlatformType = PlatformType.Windows_x86 Then 
		Platform = NStr("en = 'Windows x86';");
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then 
		Platform = NStr("en = 'Windows x86-64';");
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86 Then 
		Platform = NStr("en = 'Linux x86';");
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then 
		Platform = NStr("en = 'Linux x86-64';");
	ElsIf SystemInfo.PlatformType = PlatformType.MacOS_x86 Then 
		Platform = NStr("en = 'macOS x86';");
	ElsIf SystemInfo.PlatformType = PlatformType.MacOS_x86_64 Then 
		Platform = NStr("en = 'macOS x86-64';");
	EndIf;
	
	// Например:
	// 
	// 
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 %2';"), Package, Platform);
	
EndFunction

#EndRegion

#Region AttachAddInSSL

// Parameters:
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Async Function AttachExtAddInAsync(Context) Export 
	
	Result = AddInAvailabilityCheckResult(Context);
	
	If Result.Available Then 
		Return Await CommonInternalClient.AttachExtAddInAsync(Context);
	Else
		If Not IsBlankString(Result.ErrorDescription) Then 
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the ""%1"" add-in
				           |on the client from the add-in storage.
				           |Reason:
				           |%2';"),
				Context.Id,
				Result.ErrorDescription);
		EndIf;
		
		Return CommonInternalClient.AddInAttachmentError(ErrorText);
		
	EndIf;
	
EndFunction

Procedure AttachAddInSSL(Context) Export 
	
	Notification = New NotifyDescription(
		"AttachAddInAfterAvailabilityCheck", 
		ThisObject, 
		Context);
	
	CheckAddInAvailability(Notification, Context);
	
EndProcedure

// Parameters:
//  Result - Structure - add-in attachment result:
//    * Attached - Boolean - attachment flag.
//    * Attachable_Module - AddInObject - an instance of the add-in.
//    * ErrorDescription - String - brief error message. Empty string on cancel by user
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Procedure AttachAddInAfterAvailabilityCheck(Result, Context) Export
	
	If Result.Available Then 
		CommonInternalClient.AttachAddInSSL(Context);
	Else
		If Not IsBlankString(Result.ErrorDescription) Then 
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the ""%1"" add-in
				           |on the client from the add-in storage.
				           |Reason:
				           |%2';"),
				Context.Id,
				Result.ErrorDescription);
		EndIf;
		
		CommonInternalClient.AttachAddInSSLNotifyOnError(ErrorText, Context);
	EndIf;
	
EndProcedure

#EndRegion

#Region AttachAddInFromWindowsRegistry

// Returns:
//  Structure:
//   * Notification - NotifyDescription
//   * Id - String
//   * ObjectCreationID - String
//
Function ConnectionContextComponentsFromTheWindowsRegistry() Export
	
	Context = New Structure;
	Context.Insert("Notification", Undefined);
	Context.Insert("Id", "");
	Context.Insert("ObjectCreationID", "");
	Return Context;
		
EndFunction

// 
// 
// Parameters:
//  Context - See ConnectionContextComponentsFromTheWindowsRegistry.
//
Async Function AttachAddInFromWindowsRegisterAsync(Context) Export
	
	If AttachAddInFromWindowsRegistryAttachmentAvailable() Then
		
		Try
			
			Attached = Await AttachAddInAsync("AddIn." + Context.Id);
			
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot attach the ""%1"" add-in on the client
					 |from Windows registry.
					 |Reason:
					 |%2';"), Context.Id, ErrorProcessing.BriefErrorDescription(ErrorInfo()));

			Return CommonInternalClient.AddInAttachmentError(ErrorText);
		EndTry;
		
		If Attached Then

			ObjectCreationID = Context.ObjectCreationID;

			If ObjectCreationID = Undefined Then
				ObjectCreationID = Context.Id;
			EndIf;

			Try
				Attachable_Module = New ("AddIn." + ObjectCreationID);
				If Attachable_Module = Undefined Then
					Raise NStr("en = 'The New operator returned Undefined.';");
				EndIf;
			Except
				Attachable_Module = Undefined;
				ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			EndTry;

			If Attachable_Module = Undefined Then

				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create object of the ""%1"" add-in attached on the client
					 |from Windows registry.
					 |Reason:
					 |%2';"), Context.Id, ErrorText);

				Return CommonInternalClient.AddInAttachmentError(ErrorText);

			Else
				
				Result = CommonInternalClient.AddInAttachmentResult();
				Result.Attached = True;
				Result.Attachable_Module = Attachable_Module;
				Return Result;
				
			EndIf;

		Else

			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t attach add-in ""%1"" on the client
				 |from Windows registry.
				 |Reason:
				 |Method ""%2"" returned ""%3"".';"), Context.Id, "AttachAddInAsync", "False");

			Return CommonInternalClient.AddInAttachmentError(ErrorText);

		EndIf;
		
	Else 
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the ""%1"" add-in
			           |on the client from Windows registry.
			           |Reason:
			           |Attaching add-ins from Windows is allowed only in the thin and thick clients.';"),
			Context.Id);
		
		Return CommonInternalClient.AddInAttachmentError(ErrorText);
		
	EndIf;
	
EndFunction

// See AddInsClient.AttachAddInFromWindowsRegistry.
// 
// Parameters:
//  Context - See ConnectionContextComponentsFromTheWindowsRegistry.
//
Procedure AttachAddInFromWindowsRegistry(Context) Export
	
	If AttachAddInFromWindowsRegistryAttachmentAvailable() Then
		
		Notification = New NotifyDescription(
		"AttachAddInFromWindowsRegistryAfterAttachmentAttempt", ThisObject, Context,
		"AttachAddInFromWIndowsRegisterOnProcessError", ThisObject);
		
		BeginAttachingAddIn(Notification, "AddIn." + Context.Id);
		
	Else 
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the ""%1"" add-in
			           |on the client from Windows registry.
			           |Reason:
			           |Attaching add-ins from Windows is allowed only in the thin and thick clients.';"),
		Context.Id);
		
		CommonInternalClient.AttachAddInSSLNotifyOnError(ErrorText, Context);
		
	EndIf;
	
EndProcedure

// Continues the AttachAddInFromWindowsRegistry procedure.
//
// Parameters:
//  Attached - Boolean
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Procedure AttachAddInFromWindowsRegistryAfterAttachmentAttempt(Attached, Context) Export
	
	If Attached Then 
		
		ObjectCreationID = Context.ObjectCreationID;
			
		If ObjectCreationID = Undefined Then 
			ObjectCreationID = Context.Id;
		EndIf;
		
		Try
			Attachable_Module = New("AddIn." + ObjectCreationID);
			If Attachable_Module = Undefined Then 
				Raise NStr("en = 'The New operator returned Undefined';");
			EndIf;
		Except
			Attachable_Module = Undefined;
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		
		If Attachable_Module = Undefined Then 
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create object of the ""%1"" add-in attached on the client
				           |from Windows registry.
				           |Reason:
				           |%2';"),
				Context.Id,
				ErrorText);
				
			CommonInternalClient.AttachAddInSSLNotifyOnError(ErrorText, Context);
			
		Else 
			CommonInternalClient.AttachAddInSSLNotifyOnAttachment(Attachable_Module, Context);
		EndIf;
		
	Else 
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t attach add-in ""%1"" on the client
			           |from Windows registry.
			           |Reason:
			           |Method ""%2"" returned ""%3"".';"),
			Context.Id, "BeginAttachingAddIn", "False");
			
		CommonInternalClient.AttachAddInSSLNotifyOnError(ErrorText, Context);
		
	EndIf;
	
EndProcedure

// Continues the AttachAddInFromWindowsRegistry procedure.
//
// Parameters:
//  ErrorInfo - ErrorInfo
//  StandardProcessing - Boolean
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Procedure AttachAddInFromWIndowsRegisterOnProcessError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot attach the ""%1"" add-in on the client
		           |from Windows registry.
		           |Reason:
		           |%2';"),
		Context.Id,
		ErrorProcessing.BriefErrorDescription(ErrorInfo));
		
	CommonInternalClient.AttachAddInSSLNotifyOnError(ErrorText, Context);
	
EndProcedure

// Continues the AttachAddInFromWindowsRegistry procedure.
Function AttachAddInFromWindowsRegistryAttachmentAvailable()
	
#If WebClient Then
	Return False;
#Else
	Return CommonClient.IsWindowsClient();
#EndIf
	
EndFunction

#EndRegion

#Region InstallAddInSSL

// Parameters:
//  Context - See CommonInternalClient.AddInAttachmentContext
//
Async Function InstallExtAddInAsync(Context) Export
	
	CheckResult = AddInAvailabilityCheckResult(Context);
	
	If CheckResult.Available Then 
		Return Await CommonInternalClient.InstallExtAddInAsync(Context);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the ""%1"" add-in
			           |on the client from the add-in storage.
			           |Reason:
			           |%2';"),
			Context.Id,
			CheckResult.ErrorDescription);
			
		Return CommonInternalClient.AddInInstallationError(ErrorText);
	EndIf;
	
EndFunction

Procedure InstallAddInSSL(Context) Export
	
	Notification = New NotifyDescription(
		"InstallAddInAfterAvailabilityCheck", 
		ThisObject, 
		Context);
	
	CheckAddInAvailability(Notification, Context);
	
EndProcedure

// Parameters:
//  Result - Structure - add-in attachment result:
//    * Attached - Boolean - attachment flag.
//    * Attachable_Module - AddInObject - an instance of the add-in.
//    * ErrorDescription - String - brief error message. Empty string on cancel by user.
//  Context - See CommonInternalClient.AddInAttachmentContext 
//
Procedure InstallAddInAfterAvailabilityCheck(Result, Context) Export
	
	If Result.Available Then 
		CommonInternalClient.InstallAddInSSL(Context);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach the ""%1"" add-in
			           |on the client from the add-in storage.
			           |Reason:
			           |%2';"),
			Context.Id,
			Result.ErrorDescription);
			
		CommonInternalClient.InstallAddInSSLNotifyOnError(ErrorText, Context);
	EndIf;
	
EndProcedure

#EndRegion

#Region ImportAddInFromFile

// Returns:
//  Structure:
//   * Notification - NotifyDescription
//   * Id - String
//   * Version - String
//   * AdditionalInformationSearchParameters - Map
//
Function ContextForLoadingComponentsFromAFile() Export
	
	Context = New Structure;
	Context.Insert("Notification", Undefined);
	Context.Insert("Id", "");
	Context.Insert("Version", "");
	Context.Insert("AdditionalInformationSearchParameters", New Map);
	Return Context;
	
EndFunction
	
// To be called from AddInClient.ImportAddInFromFile.
// 
// Parameters:
//  Context - See ContextForLoadingComponentsFromAFile.
//
Procedure ImportAddInFromFile(Context) Export 
	
	Information = AddInsInternalServerCall.SavedAddInInformation(Context.Id, Context.Version);
	
	If Information.ImportFromFileIsAvailable Then
		
		AdditionalInformationSearchParameters = Context.AdditionalInformationSearchParameters;
		
		FormParameters = New Structure;
		FormParameters.Insert("ShowImportFromFileDialogOnOpen", True);
		FormParameters.Insert("ReturnImportResultFromFile", True);
		FormParameters.Insert("AdditionalInformationSearchParameters", AdditionalInformationSearchParameters);
		
		If Information.State = "FoundInStorage"
			Or Information.State = "DisabledByAdministrator" Then
			
			FormParameters.Insert("ShowImportFromFileDialogOnOpen", False);
			FormParameters.Insert("Key", Information.Ref);
		EndIf;
		
		Notification = New NotifyDescription("ImportAddInFromFileAfterImport", ThisObject, Context);
		OpenForm("Catalog.AddIns.ObjectForm", FormParameters,,,,, Notification);
		
	Else 
		
		Notification = New NotifyDescription("ImportAddInFromFileAfterAvailabilityWarnings", ThisObject, Context);
		ShowMessageBox(Notification, 
			NStr("en = 'Add-in import is canceled
			           |due to:
			           |You must have administrative rights';"));
		
	EndIf;
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
Procedure ImportAddInFromFileAfterAvailabilityWarnings(Context) Export
	
	Result = AddInImportResult();
	Result.Imported1 = False;
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
Procedure ImportAddInFromFileAfterImport(Result, Context) Export
	
	//  
	// 
	//  
	
	UserClosedDialogBox = (Result = Undefined);
	
	Notification = Context.Notification;
	
	If UserClosedDialogBox Then 
		Result = AddInImportResult();
		Result.Imported1 = False;
	EndIf;
	
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
Function AddInImportResult() Export
	
	Result = New Structure;
	Result.Insert("Imported1", False);
	Result.Insert("Id", "");
	Result.Insert("Version", "");
	Result.Insert("Description", "");
	Result.Insert("AdditionalInformation", New Map);
	
	Return Result;
	
EndFunction

#EndRegion

#Region ComponentSearchOnPortal

// Parameters:
//  Notification - NotifyDescription
//  Context - Structure:
//      * ExplanationText - String
//      * Id - String
//      * Version        - String
//                      - Undefined
//      * AutoUpdate - Boolean
//
Procedure ComponentSearchOnPortal(Notification, Context)
	
	FormParameters = New Structure;
	FormParameters.Insert("ExplanationText", Context.ExplanationText);
	FormParameters.Insert("Id", Context.Id);
	FormParameters.Insert("Version", Context.Version);
	FormParameters.Insert("AutoUpdate", Context.AutoUpdate);
	
	NotificationForms = New NotifyDescription("AddInSearchOnPortalOnGenerateResult", ThisObject, Notification);
	
	OpenForm("Catalog.AddIns.Form.SearchForComponentOn1CITSPortal", 
		FormParameters,,,,, NotificationForms)
	
EndProcedure

Procedure AddInSearchOnPortalOnGenerateResult(Result, Notification) Export
	
	Imported1 = (Result = True); // 
	ExecuteNotifyProcessing(Notification, Imported1);
	
EndProcedure

#EndRegion

#Region UpdateAddInsFromPortal

// Parameters:
//  Notification - NotifyDescription
//  AddInsToUpdate - Array of CatalogRef.AddIns
//
Procedure UpdateAddInsFromPortal(Notification, AddInsToUpdate) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("AddInsToUpdate", AddInsToUpdate);
	NotificationForms = New NotifyDescription("UpdateAddInFromPortalOnGenerateResult", ThisObject, Notification);
	OpenForm("Catalog.AddIns.Form.ComponentsUpdateFrom1CITSPortal", 
		FormParameters,,,,, NotificationForms);
	
EndProcedure

Procedure UpdateAddInFromPortalOnGenerateResult(Result, Notification) Export
	
	ExecuteNotifyProcessing(Notification, Undefined);
	
EndProcedure

#EndRegion

#Region SaveAddInToFile

// Parameters:
//  AddInRef - CatalogRef.AddIns
//                          - Array of CatalogRef.AddIns
//
Procedure SaveAddInToFile(AddInRef) Export
	
	If TypeOf(AddInRef) = Type("Array") Then
		References = AddInRef;
	Else
		References = CommonClientServer.ValueInArray(AddInRef);
	EndIf;
	FilesDetails = AddInsInternalServerCall.AddInsFilesDetails(References);

	If References.Count() = 1 Then
		
		SavingParameters = FileSystemClient.FileSavingParameters();
		SavingParameters.Dialog.Title = NStr("en = 'Select a file to save the add-in to';");
		SavingParameters.Dialog.Filter    = NStr("en = 'Add-in files (*.zip)|*.zip';")+"|"
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
		
		Notification = New NotifyDescription("SaveAddInToFileAfterReceivingFiles", ThisObject);
		FileSystemClient.SaveFile(Notification, FilesDetails[0].Location, FilesDetails[0].Name, SavingParameters);
		
		Return;
	EndIf;
	
	Notification = New NotifyDescription("SaveAddInsToFileAfterDirectorySelected", ThisObject, FilesDetails);
	FileSystemClient.SelectDirectory(Notification, NStr("en = 'Select a directory to save the add-ins';"));
	
EndProcedure

// Continue with the save component File procedure.
Procedure SaveAddInsToFileAfterDirectorySelected(Directory, FilesDetails) Export
	
	If IsBlankString(Directory) Then
		Return;
	EndIf;
	
	FilesToSave = New Array;
	For Each FileDetails In FilesDetails Do
		FilesToSave.Add(New TransferableFileDescription(FileDetails.Name, FileDetails.Location));
	EndDo;
	
	SavingParameters = FileSystemClient.FilesSavingParameters();
	SavingParameters.Interactively = False;
	SavingParameters.Dialog.Directory = Directory;
	FileSystemClient.SaveFiles(New NotifyDescription(
		"SaveAddInToFileAfterReceivingFiles", ThisObject), 
		FilesToSave, SavingParameters);

EndProcedure

// Continuation of the SaveAddInToFile procedure.
Procedure SaveAddInToFileAfterReceivingFiles(ObtainedFiles, Context) Export
	
	If ObtainedFiles <> Undefined 
		And ObtainedFiles.Count() > 0 Then
		
		MessageText = ?(ObtainedFiles.Count() = 1, 
			NStr("en = 'The add-in is saved to the file.';"),
			NStr("en = 'The add-ins are saved to the files.';"));
		
		ShowUserNotification(NStr("en = 'Save to file';"),,
			MessageText, PictureLib.Success32);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

