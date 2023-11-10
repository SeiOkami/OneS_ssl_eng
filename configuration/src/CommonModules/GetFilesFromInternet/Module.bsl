///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Gets the file from the Internet via http(s) protocol or ftp protocol and saves it at the specified path on server.
//
// Parameters:
//   URL                - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - See GetFilesFromInternetClientServer.FileGettingParameters
//   WriteError1   - Boolean - if True, write file download errors to the event log.
//
// Returns:
//   Structure:
//      * Status            - Boolean - a result of receiving a file.
//      * Path   - String   - path to the file on the server. This key is used only if Status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers         - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode      - Number - adds in case of an error.
//                                    See details of the StateCode parameter of the HTTPResponse object in Syntax Assistant.
//
Function DownloadFileAtServer(Val URL, ReceivingParameters = Undefined, Val WriteError1 = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("StorageLocation", "Server");
	
	Return GetFilesFromInternetInternal.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError1);
	
EndFunction

// Gets a file from the Internet over HTTP(S) or FTP and saves it to a temporary storage.
// Note. After getting the file, clear the temporary storage
// using the DeleteFromTempStorage method. If you do not do it, the file will remain in
// the server memory until the session is over.
//
// Parameters:
//   URL                - String - file URL in the following format: [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - See GetFilesFromInternetClientServer.FileGettingParameters.
//   WriteError1   - Boolean - if True, write file download errors to the event log.
//
// Returns:
//   Structure:
//      * Status            - Boolean - a result of receiving a file.
//      * Path              - String   - an address of a temporary storage with binary file data.
//                            The key is used only if the status is True.
//      * ErrorMessage - String - error message if Status is False.
//      * Headers         - Map - see details of the Headers parameter of the HTTPResponse object in Syntax Assistant.
//      * StatusCode      - Number - adds in case of an error.
//                                    See details of the StateCode parameter of the HTTPResponse object in Syntax Assistant.
//
Function DownloadFileToTempStorage(Val URL, ReceivingParameters = Undefined, Val WriteError1 = True) Export
	
	SavingSetting = New Map;
	SavingSetting.Insert("StorageLocation", "TemporaryStorage");
	
	Return GetFilesFromInternetInternal.DownloadFile(URL,
		ReceivingParameters, SavingSetting, WriteError1);
	
EndFunction

// Returns the current user's proxy server settings for Internet access from
// the client.
//
// Returns:
//    Map of KeyAndValue:
//      * Key - String
//      * Value - Arbitrary
//    
//      
//      
//      
//      
//      
//      
//      
//
Function ProxySettingsAtClient() Export
	
	UserName = Undefined;
	
	If Common.FileInfobase() Then
		
		// 
		// 
		
		CurrentInfobaseSession1 = GetCurrentInfoBaseSession();
		BackgroundJob = CurrentInfobaseSession1.GetBackgroundJob();
		IsScheduledJobSession = BackgroundJob <> Undefined And BackgroundJob.ScheduledJob <> Undefined;
		
		If IsScheduledJobSession Then
			
			If Not ValueIsFilled(BackgroundJob.ScheduledJob.UserName) Then 
				
				// 
				// 
				// 
				
				Sessions = GetInfoBaseSessions(); // Array of InfoBaseSession
				For Each Session In Sessions Do 
					If Session.ComputerName = CurrentInfobaseSession1.ComputerName Then 
						UserName = Session.User.Name;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Common.CommonSettingsStorageLoad("ProxyServerSetting", "",,, UserName);
	
EndFunction

// Returns the 1C:Enterprise server's proxy settings.
//
// Returns:
//   Map of KeyAndValue:
//     * Key - String
//     * Value - Arbitrary
//    
//      
//      
//      
//      
//      
//      
//      
//
Function ProxySettingsAtServer() Export
	
	If Common.FileInfobase() Then
		Return ProxySettingsAtClient();
	Else
		SetPrivilegedMode(True);
		ProxySettingsAtServer = Constants.ProxyServerSetting.Get().Get();
		Return ?(TypeOf(ProxySettingsAtServer) = Type("Map"),
			ProxySettingsAtServer,
			Undefined);
	EndIf;
	
EndFunction

// Returns InternetProxy object for Internet access.
// The following protocols are acceptable for creating InternetProxy: http, https, ftp, and ftps.
//
// Parameters:
//    URLOrProtocol - String - URL in the following format: [Protocol://]<Server>/<Path to the file on the server>,
//                              or protocol identifier (http, ftp, …).
//
// Returns:
//    InternetProxy - 
//                     
//                     
//
Function GetProxy(Val URLOrProtocol) Export
	
	Return GetFilesFromInternetInternal.NewInternetProxy(ProxySettingsAtServer(), URLOrProtocol);
	
EndFunction

// Runs the network resource diagnostics.
// In SaaS mode, returns only an error description.
//
// Parameters:
//  URL - String - URL resource address to be diagnosed.
//  WriteError1 - Boolean - indicates whether it is necessary to write errors to the event log.
//
// Returns:
//  Structure:
//    *  ErrorDescription    - String - brief error message.
//    *  DiagnosticsLog - String - a detailed log of diagnostics with technical details.
//
// Example:
//	// Diagnostics of address classifier web service.
//	Result = CommonClientServer.ConnectionDiagnostics("https://api.orgaddress.1c.com/orgaddress/v1?wsdl");
//	
//	ErrorDetails = Result.ErrorDescription;
//	DiagnosticsLog = Result.DiagnosticsLog;
//
Function ConnectionDiagnostics(URL, WriteError1 = True) Export
	
	LongDesc = New Array;
	LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Accessing URL: %1.';"), 
		URL));
	LongDesc.Add(GetFilesFromInternetInternal.DiagnosticsLocationPresentation());
	
	If Common.DataSeparationEnabled() Then
		LongDesc.Add(
			NStr("en = 'Please contact the administrator.';"));
		
		ErrorDescription = StrConcat(LongDesc, Chars.LF);
		
		Result = New Structure;
		Result.Insert("ErrorDescription", ErrorDescription);
		Result.Insert("DiagnosticsLog", "");
		
		Return Result;
	EndIf;
	
	Log = New Array;
	Log.Add(
		NStr("en = 'Diagnostics log:
		           |Server availability test.
		           |See the error description in the next log record.';"));
	Log.Add();
	
	RefStructure = CommonClientServer.URIStructure(URL);
	
	ProxySettingsState = GetFilesFromInternetInternal.ProxySettingsState(RefStructure.Schema);
	ProxyConnection = ProxySettingsState.ProxyConnection;
	Log.Add(ProxySettingsState.Presentation);
	
	If ProxyConnection And Not ProxySettingsState.SystemProxySettingsUsed Then 
		
		LongDesc.Add(
			NStr("en = 'Connection diagnostics are not performed because a proxy server is configured.
			           |Please contact the administrator.';"));
		
	Else 
		
		ResourceServerAddress = RefStructure.Host;
		VerificationServerAddress = "google.com";
		
		If Metadata.CommonModules.Find("GetFilesFromInternetInternalLocalization") <> Undefined Then
			ModuleNetworkDownloadInternalLocalization = Common.CommonModule("GetFilesFromInternetInternalLocalization");
			VerificationServerAddress = ModuleNetworkDownloadInternalLocalization.VerificationServerAddress();
		EndIf;
		
		ResourceAvailabilityResult = GetFilesFromInternetInternal.CheckServerAvailability(ResourceServerAddress);
		
		Log.Add();
		Log.Add("1) " + ResourceAvailabilityResult.DiagnosticsLog);
		
		If ResourceAvailabilityResult.Available Then 
			
			LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Attempted to access a resource that does not exist on server %1,
				           |or some issues occurred on the remote server.';"),
				ResourceServerAddress));
			
		Else 
			
			VerificationResult = GetFilesFromInternetInternal.CheckServerAvailability(VerificationServerAddress);
			Log.Add("2) " + VerificationResult.DiagnosticsLog);
			
			If Not VerificationResult.Available Then
				
				LongDesc.Add(
					NStr("en = 'No Internet access. Possible reasons:
					           |- The computer is not connected to the Internet.
					           | - Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           | is blocking the connection.';"));
				
			Else 
				
				LongDesc.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Server %1 is unavailable. Possible reasons:
					           |- Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           | is blocking the connection.
					           |- The server is turned off or under maintenance.';"),
					ResourceServerAddress));
				
				TraceLog = GetFilesFromInternetInternal.ServerRouteTraceLog(ResourceServerAddress);
				Log.Add("3) " + TraceLog);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ErrorDescription = StrConcat(LongDesc, Chars.LF);
	
	Log.Insert(0);
	Log.Insert(0, ErrorDescription);
	
	DiagnosticsLog = StrConcat(Log, Chars.LF);
	
	If WriteError1 Then
		WriteLogEvent(
			NStr("en = 'Connection diagnostics';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, DiagnosticsLog);
	EndIf;
	
	Result = New Structure;
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("DiagnosticsLog", DiagnosticsLog);
	
	Return Result;
	
EndFunction

#EndRegion
