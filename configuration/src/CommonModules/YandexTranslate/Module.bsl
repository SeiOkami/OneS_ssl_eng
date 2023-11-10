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
	
	SetPrivilegedMode(True);
	AuthorizationSettings = AuthorizationSettings();
	SetPrivilegedMode(False);
	
	HostName_SSLy = "translate.api.cloud.yandex.net";
	
	HTTPRequest = New HTTPRequest("/translate/v2/translate");
	HTTPRequest.Headers.Insert("Content-Type", "application/json");
	HTTPRequest.Headers.Insert("Authorization", "Bearer" + " " + IAMToken());
	
	QueryOptions = New Structure;
	QueryOptions.Insert("folder_id", AuthorizationSettings.DirectoryID);
	QueryOptions.Insert("texts", Texts);
	QueryOptions.Insert("targetLanguageCode", TranslationLanguage);
	
	If ValueIsFilled(SourceLanguage) Then
		QueryOptions.Insert("sourceLanguageCode", SourceLanguage);
	EndIf;
	
	HTTPRequest.SetBodyFromString(Common.ValueToJSON(QueryOptions));
	QueryResult = ExecuteQuery(HTTPRequest, HostName_SSLy);
	
	If Not QueryResult.QueryCompleted Then
		Raise ErrorText(NStr("en = 'Cannot translate text.';"));
	EndIf;
	
	ServerResponse1 = Common.JSONValue(QueryResult.ServerResponse1);
	
	Result = New Map;
	For IndexOf = 0 To Texts.UBound() Do
		Translation = ServerResponse1["translations"][IndexOf];
		Result.Insert(Texts[IndexOf], Translation["text"]);
		If Not ValueIsFilled(SourceLanguage) Then
			SourceLanguage = Translation["detectedLanguageCode"];
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function MaxBatchSize() Export
	
	Return 10000;
	
EndFunction

Function IAMToken()
	
	TokenParameters = New Structure("IAMToken,ValidityPeriod");
	
	SetPrivilegedMode(True);
	FillPropertyValues(TokenParameters, AuthorizationSettings());
	SetPrivilegedMode(False);
	
	If Not ValueIsFilled(TokenParameters.IAMToken) 
		Or Not ValueIsFilled(TokenParameters.ValidityPeriod)
		Or TokenParameters.ValidityPeriod <= ToUniversalTime(CurrentDate()) Then // ACC:143
		TokenParameters = NewIAMToken();
		SetPrivilegedMode(True);
		Owner = Common.MetadataObjectID("Constant.TextTranslationService");
		Common.WriteDataToSecureStorage(Owner, TokenParameters.IAMToken, "IAMToken");
		Common.WriteDataToSecureStorage(Owner, TokenParameters.ValidityPeriod, "ValidityPeriod");
		SetPrivilegedMode(False);
	EndIf;
	
	Return TokenParameters.IAMToken;
	
EndFunction

Function NewIAMToken()
	
	HostName_SSLy = "iam.api.cloud.yandex.net";
	
	HTTPRequest = New HTTPRequest("/iam/v1/tokens");
	HTTPRequest.Headers.Insert("Content-Type", "application/json");
	
	QueryOptions = New Structure;
	
	SetPrivilegedMode(True);
	QueryOptions.Insert("yandexPassportOauthToken", AuthorizationSettings().OAuthToken);
	SetPrivilegedMode(False);
	
	HTTPRequest.SetBodyFromString(Common.ValueToJSON(QueryOptions));
	
	QueryResult = ExecuteQuery(HTTPRequest, HostName_SSLy);
	
	If Not QueryResult.QueryCompleted Then
		Raise ErrorText(StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Cannot authorize to %1.';"), "Yandex.Cloud"));
	EndIf;
	
	ConfiguringAuthorization = Common.JSONValue(QueryResult.ServerResponse1, "expiresAt");
	IAMToken = ConfiguringAuthorization["iamToken"];
	ValidityPeriod = ConfiguringAuthorization["expiresAt"];
	
	Result = New Structure;
	Result.Insert("IAMToken", IAMToken);
	Result.Insert("ValidityPeriod", ToUniversalTime(ValidityPeriod));
	
	Return Result;
	
EndFunction

Function AvailableLanguages() Export
	
	HostName_SSLy = "translate.api.cloud.yandex.net";
	
	HTTPRequest = New HTTPRequest("/translate/v2/languages");
	HTTPRequest.Headers.Insert("Content-Type", "application/json");
	HTTPRequest.Headers.Insert("Authorization", "Bearer" + " " + IAMToken());
	
	
	QueryOptions = New Structure;
	
	SetPrivilegedMode(True);
	QueryOptions.Insert("folder_id", AuthorizationSettings().DirectoryID);
	SetPrivilegedMode(False);
	
	HTTPRequest.SetBodyFromString(Common.ValueToJSON(QueryOptions));
	
	QueryResult = ExecuteQuery(HTTPRequest, HostName_SSLy);
	
	If Not QueryResult.QueryCompleted Then
		Raise ErrorText(NStr("en = 'Cannot retrieve the list of available languages.';"));
	EndIf;
	
	Result = New Array;
	AvailableLanguages = Common.JSONValue(QueryResult.ServerResponse1);
	For Each Language In AvailableLanguages["languages"] Do
		LanguageCode = Language["code"];
		If ValueIsFilled(LanguageCode) Then
			Result.Add(LanguageCode);
		EndIf;
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
		Raise ErrorInfo["message"];
	EndIf;
	
	Result.QueryCompleted = HTTPResponse.StatusCode = 200;
	Result.ServerResponse1 = HTTPResponse.GetBodyAsString();
	
	Return Result;
	
EndFunction

Function AuthorizationSettings() Export
	
	ParameterNames = "OAuthToken,DirectoryID,IAMToken,ValidityPeriod";
	Result = New Structure(ParameterNames);
	
	Owner = Common.MetadataObjectID("Constant.TextTranslationService");
	Settings = Common.ReadDataFromSecureStorage(Owner, ParameterNames);
	If ValueIsFilled(Settings) Then
		FillPropertyValues(Result, Settings);
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Settings - See TextTranslationTool.TextTranslationServiceSettings
//
Procedure OnDefineSettings(Settings) Export
	
	Settings.ConnectionInstructions = StringFunctions.FormattedString(NStr(
		"en = 'How to set up:
		|1. Register with <a href = ""%1"">Yandex.Cloud</a> and activate a <a href = ""%2"">billing account</a>.
		|2. Go to <a href = ""%3"">Yandex OAuth</a> and copy the alphanumeric string into the <b>OAuth token</b> field.
		|3. Go to <a href = ""%4"">Yandex.Cloud management console</a>. In the <b>Your resources</b> list to the right of the <b>default</b> directory, copy the alphanumeric string and paste it in the <b>Directory ID</b> field.';"),
		"https://cloud.yandex.com/", "https://console.cloud.yandex.com/billing",
		"https://oauth.yandex.com/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb",
		"https://console.cloud.yandex.com/");
	
	Parameter = Settings.AuthorizationParameters.Add();
	Parameter.Name = "OAuthToken";
	Parameter.Presentation = NStr("en = 'OAuth token';");
	Parameter.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
	
	Parameter = Settings.AuthorizationParameters.Add();
	Parameter.Name = "DirectoryID";
	Parameter.Presentation = NStr("en = 'Directory ID';");
	Parameter.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
	
EndProcedure

Function SetupExecuted() Export
	
	SetPrivilegedMode(True);
	AuthorizationSettings = AuthorizationSettings();
	
	Return ValueIsFilled(AuthorizationSettings.OAuthToken)
		And ValueIsFilled(AuthorizationSettings.DirectoryID);
	
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
	Address = "translate.api.cloud.yandex.net";
	Port = Undefined;
	LongDesc = NStr("en = 'Yandex Translate translation service';");
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	Resolution = ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, LongDesc);
	
	Permissions = New Array;
	Permissions.Add(Resolution);
	
	Return Permissions;
	
EndFunction

#EndRegion
