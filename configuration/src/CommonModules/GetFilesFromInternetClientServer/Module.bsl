///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns the parameter structure for getting a file from the Internet.
//
// Returns:
//  Structure:
//     * PathForSaving            - String       - path on the server (including file name) for saving the downloaded file.
//                                                     Not filled in if a file is saved to the temporary storage.
//     * User                 - String       - a user that established the connection.
//     * Password                       - String       - the password of the user that established the connection.
//     * Port                         - Number        - a port used for connecting to the server.
//     * Timeout                      - Number        - the file download timeout, in seconds.
//     * SecureConnection         - Boolean       - indicates the use of secure ftps or https connection.
//                                    - OpenSSLSecureConnection
//                                    - Undefined - 
//
//    
//     * Headers                    - Map - see details of the Headers parameter of the HTTPRequest object in Syntax Assistant.
//     * UseOSAuthentication - Boolean       - see Syntax Assistant for details of
//                                                     the UseOSAuthentication parameter of the HTTPConnection object.
//
//    Parameters only for ftp (ftps) connection:
//     * PassiveConnection          - Boolean       - a flag that indicates that the connection should be passive (or active).
//     * SecureConnectionUsageLevel - FTPSecureConnectionUsageLevel - see details
//         of the property with the same name in the platform Syntax Assistant. Default value is Auto.
//
Function FileGettingParameters() Export
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("PathForSaving", Undefined);
	ReceivingParameters.Insert("User", Undefined);
	ReceivingParameters.Insert("Password", Undefined);
	ReceivingParameters.Insert("Port", Undefined);
	ReceivingParameters.Insert("Timeout", AutomaticTimeoutDetermination());
	ReceivingParameters.Insert("SecureConnection", Undefined);
	ReceivingParameters.Insert("PassiveConnection", Undefined);
	ReceivingParameters.Insert("Headers", New Map);
	ReceivingParameters.Insert("UseOSAuthentication", False);
	ReceivingParameters.Insert("SecureConnectionUsageLevel", Undefined);
	
	Return ReceivingParameters;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use GetFilesFromInternet.GetProxy instead.
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
	
#If WebClient Then
	Raise NStr("en = 'Proxy is not available in the web client.';");
#Else
	
	AcceptableProtocols = New Map();
	AcceptableProtocols.Insert("HTTP",  True);
	AcceptableProtocols.Insert("HTTPS", True);
	AcceptableProtocols.Insert("FTP",   True);
	AcceptableProtocols.Insert("FTPS",  True);
	
	ProxyServerSetting = ProxyServerSetting();
	
	If StrFind(URLOrProtocol, "://") > 0 Then
		Protocol = SplitURL(URLOrProtocol).Protocol;
	Else
		Protocol = Lower(URLOrProtocol);
	EndIf;
	
	If AcceptableProtocols[Upper(Protocol)] = Undefined Then
		Protocol = "HTTP";
	EndIf;
	
	Return NewInternetProxy(ProxyServerSetting, Protocol);
	
#EndIf
	
EndFunction

// Deprecated. Obsolete. Use CommonUseClientServer.URIStructure.
// Splits URL: protocol, server, path to resource.
//
// Parameters:
//    URL - String - link to a web resource.
//
// Returns:
//    Structure:
//        * Protocol            - String - protocol of access to the resource.
//        * ServerName          - String - server the resource is located on.
//        * PathToFileAtServer - String - path to the resource on the server.
//
Function SplitURL(Val URL) Export
	
	URLStructure1 = CommonClientServer.URIStructure(URL);
	
	Result = New Structure;
	Result.Insert("Protocol", ?(IsBlankString(URLStructure1.Schema), "http", URLStructure1.Schema));
	Result.Insert("ServerName", URLStructure1.ServerName);
	Result.Insert("PathToFileAtServer", URLStructure1.PathAtServer);
	
	Return Result;
	
EndFunction

// Deprecated. Obsolete. Use CommonUseClientServer.URIStructure.
// Splits URL: protocol, server, path to resource. Splits the URI string and returns it as a structure.
// The following normalizations are described based on RFC 3986.
//
// Parameters:
//     URIString1 - String - link to the resource in the following format:
//                          <schema>://<username>:<password>@<host>:<port>/<path>?<parameters>#<anchor>.
//
// Returns:
//    Structure - 
//        * Schema         - String - URI schema.
//        * Login         - String - username.
//        * Password        - String - User password.
//        * ServerName    - String - part <host>:<port> of the input parameter.
//        * Host          - String - Server name.
//        * Port          - String - server port.
//        * PathAtServer - String - part <path>?<parameters>#<anchor> of the input parameter.
//
Function URIStructure(Val URIString1) Export
	
	Return CommonClientServer.URIStructure(URIString1);
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region ObsoleteProceduresAndFunctions

// Service information that displays current settings and proxy states to perform diagnostics.
//
// Returns:
//  Structure:
//     * ProxyConnection - Boolean - flag that indicates that proxy connection should be used.
//     * Presentation - String - presentation of the current set up proxy.
//
Function ProxySettingsState() Export
	
#If WebClient Then
	
	Result = New Structure;
	Result.Insert("ProxyConnection", False);
	Result.Insert("Presentation", NStr("en = 'Proxy is not available in the web client.';"));
	Return Result;
	
#Else
	
	Return GetFilesFromInternetInternalServerCall.ProxySettingsState();
	
#EndIf
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Function AutomaticTimeoutDetermination() Export
	
	Return -1;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

#If Not WebClient Then

// Returns proxy according to settings ProxyServerSetting for the specified Protocol protocol.
//
// Parameters:
//   ProxyServerSetting -  Map of KeyAndValue:
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
//      
//                            
//
// Returns:
//   InternetProxy
//
Function NewInternetProxy(ProxyServerSetting, Protocol)
	
	If ProxyServerSetting = Undefined Then
		// Системные установки прокси-
		Return Undefined;
	EndIf;
	
	UseProxy = ProxyServerSetting.Get("UseProxy");
	If Not UseProxy Then
		// Не использовать прокси-
		Return New InternetProxy(False);
	EndIf;
	
	UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
	If UseSystemSettings Then
		// Системные настройки прокси-
		Return New InternetProxy(True);
	EndIf;
	
	// Manually configured proxy settings.
	Proxy = New InternetProxy;
	
	// Detecting a proxy server address and port.
	AdditionalSettings = ProxyServerSetting.Get("AdditionalProxySettings");
	ProxyByProtocol = Undefined;
	If TypeOf(AdditionalSettings) = Type("Map") Then
		ProxyByProtocol = AdditionalSettings.Get(Protocol);
	EndIf;
	
	UseOSAuthentication = ProxyServerSetting.Get("UseOSAuthentication");
	UseOSAuthentication = ?(UseOSAuthentication = True, True, False);
	
	If TypeOf(ProxyByProtocol) = Type("Structure") Then
		Proxy.Set(Protocol, ProxyByProtocol.Address, ProxyByProtocol.Port,
			ProxyServerSetting["User"], ProxyServerSetting["Password"], UseOSAuthentication);
	Else
		Proxy.Set(Protocol, ProxyServerSetting["Server"], ProxyServerSetting["Port"], 
			ProxyServerSetting["User"], ProxyServerSetting["Password"], UseOSAuthentication);
	EndIf;
	
	Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
	
	ExceptionsAddresses = ProxyServerSetting.Get("BypassProxyOnAddresses");
	If TypeOf(ExceptionsAddresses) = Type("Array") Then
		For Each ExceptionAddress In ExceptionsAddresses Do
			Proxy.BypassProxyOnAddresses.Add(ExceptionAddress);
		EndDo;
	EndIf;
	
	Return Proxy;
	
EndFunction

#EndIf

Function ProxyServerSetting()
	
	// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
#Else
	ProxyServerSetting = StandardSubsystemsClient.ClientRunParameters().ProxyServerSettings;
#EndIf
	
	// ACC:547-
	
	Return ProxyServerSetting;
	
EndFunction

#EndRegion

#EndRegion