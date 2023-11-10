///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Function TranslateText(Text, TranslationLanguage = Undefined, SourceLanguage = Undefined) Export
	
	If Not ValueIsFilled(Text) Then
		Return Text;
	EndIf;
	
	Return TranslateTheTexts(CommonClientServer.ValueInArray(Text), TranslationLanguage, SourceLanguage)[Text];
	
EndFunction

Function TranslateTheTexts(Texts, TranslationLanguage = Undefined, SourceLanguage = Undefined) Export
	
	CommonClientServer.CheckParameter("TranslateTheTexts", "Texts", Texts, Type("Array"));
	
	If Not ValueIsFilled(TranslationLanguage) Then
		TranslationLanguage = Common.DefaultLanguageCode();
	EndIf;
	
	HostName_SSLy = "translation.googleapis.com";
	
	SetPrivilegedMode(True);
	HTTPRequest = New HTTPRequest("/language/translate/v2?key=" + AuthorizationSettings().APIKey);
	SetPrivilegedMode(False);
	
	QueryOptions = New Structure;
	QueryOptions.Insert("format", "text");
	QueryOptions.Insert("q", Texts);
	QueryOptions.Insert("target", TranslationLanguage);
	
	If ValueIsFilled(SourceLanguage) Then
		QueryOptions.Insert("source", SourceLanguage);
	EndIf;
	
	HTTPRequest.SetBodyFromString(Common.ValueToJSON(QueryOptions));
	QueryResult = ExecuteQuery(HTTPRequest, HostName_SSLy);
	
	If Not QueryResult.QueryCompleted Then
		Raise ErrorText(NStr("en = 'Cannot translate text.';"));
	EndIf;
	
	ServerResponse1 = Common.JSONValue(QueryResult.ServerResponse1);
	
	Result = New Map;
	For IndexOf = 0 To Texts.UBound() Do
		Translation = ServerResponse1["data"]["translations"][IndexOf];
		Result.Insert(Texts[IndexOf], Translation["translatedText"]);
		If Not ValueIsFilled(SourceLanguage) Then
			SourceLanguage = Translation["detectedSourceLanguage"];
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function MaxBatchSize() Export
	
	Return 10000;
	
EndFunction

Function AvailableLanguages() Export
	
	HostName_SSLy = "translation.googleapis.com";
	
	SetPrivilegedMode(True);
	HTTPRequest = New HTTPRequest("/language/translate/v2/languages?key=" + AuthorizationSettings().APIKey);
	SetPrivilegedMode(False);
	
	QueryResult = ExecuteQuery(HTTPRequest, HostName_SSLy);
	
	If Not QueryResult.QueryCompleted Then
		Raise ErrorText(NStr("en = 'Cannot retrieve the list of available languages.';"));
	EndIf;
	
	Result = New Array;
	AvailableLanguages = Common.JSONValue(QueryResult.ServerResponse1);
	For Each Language In AvailableLanguages["data"]["languages"] Do
		LanguageCode = Language["language"];
		Result.Add(LanguageCode);
	EndDo;
	
	Return Result;
	
EndFunction

Function ExecuteQuery(Val HTTPRequest, Val HostName_SSLy)
	
	Proxy = GetFilesFromInternet.GetProxy("https");
	SecureConnection = CommonClientServer.NewSecureConnection();
	
	Try
		Join = New HTTPConnection(HostName_SSLy, , , , Proxy, 60, SecureConnection);
		HTTPResponse = Join.Post(HTTPRequest);
	Except
		WriteErrorToEventLog(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot establish a connection with server %1 due to:
			|%2';"), HostName_SSLy, ErrorProcessing.DetailErrorDescription(ErrorInfo())));
		Raise;
	EndTry;
	
	Result = New Structure;
	Result.Insert("QueryCompleted", False);
	Result.Insert("ServerResponse1", "");
	
	If HTTPResponse.StatusCode <> 200 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Request ""%1"" failed. Status code: %2.';"),
			HTTPRequest.ResourceAddress,
			HTTPResponse.StatusCode) + Chars.LF + HTTPResponse.GetBodyAsString();
		WriteErrorToEventLog(ErrorText);
	EndIf;
		
	If HTTPResponse.StatusCode = 401 
		Or HTTPResponse.StatusCode = 403 Then
		ErrorInfo = Common.JSONValue(HTTPResponse.GetBodyAsString());
		Raise ErrorInfo["error"]["message"];
	EndIf;
	
	Result.QueryCompleted = HTTPResponse.StatusCode = 200;
	Result.ServerResponse1 = HTTPResponse.GetBodyAsString();
	
	Return Result;
	
EndFunction

Function AuthorizationSettings() Export
	
	ParameterNames = "APIKey";
	Result = New Structure(ParameterNames);
	
	If Common.SeparatedDataUsageAvailable() Then
		Owner = Common.MetadataObjectID("Constant.TextTranslationService");
		Settings = Common.ReadDataFromSecureStorage(Owner, ParameterNames);
		
		If TypeOf(Settings) = Type("Structure") Then
			FillPropertyValues(Result, Settings);
		ElsIf TypeOf(Settings) = Type("String") Then
			Result.APIKey = Settings;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Settings - See TextTranslationTool.TextTranslationServiceSettings
//
Procedure OnDefineSettings(Settings) Export
	
	Settings.ConnectionInstructions = StringFunctions.FormattedString(NStr(
		"en = 'How to setup:
		|1. Activate a billing account in <a href = ""%1"">Google Cloud</a>.
		|2. On the <a href = ""%2"">API Credentials</a> page, click <b>Create credentials</b> and select <b>API key</b>.
		|3. Copy the resulting string from the <b>Your API key</b> field into the <b>API key</b> field.';"),
		"https://console.cloud.google.com/billing",
		"https://console.cloud.google.com/apis/credentials");
	
	Parameter = Settings.AuthorizationParameters.Add();
	Parameter.Name = "APIKey";
	Parameter.Presentation = NStr("en = 'API key';");
	Parameter.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
	
EndProcedure

Function SetupExecuted() Export
	
	SetPrivilegedMode(True);
	Return ValueIsFilled(AuthorizationSettings().APIKey);
	
EndFunction

Procedure WriteErrorToEventLog(Comment)
	
	WriteLogEvent(NStr("en = 'Translator';", Common.DefaultLanguageCode()),
		EventLogLevel.Error, , Enums.TextTranslationServices.YandexTranslate, Comment);
	
EndProcedure

Function ErrorText(ErrorText)
	
	If Users.IsFullUser() Then
		Return ErrorText + Chars.LF + NStr("en = 'See the Event log for details.';");
	EndIf;
	
	Return ErrorText + Chars.LF + NStr("en = 'Please contact the administrator.';");
	
EndFunction

// Returns a list of permissions to use the translation service.
//
// Returns:
//  Array
//
Function Permissions() Export
	
	Protocol = "HTTPS";
	Address = "translation.googleapis.com";
	Port = Undefined;
	LongDesc = NStr("en = 'Google Translate translation service';");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Resolution = ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, LongDesc);
	
	Permissions = New Array;
	Permissions.Add(Resolution);
	
	Return Permissions;
	
EndFunction

#EndRegion
