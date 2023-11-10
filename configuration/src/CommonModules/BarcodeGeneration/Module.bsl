///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// A blank structure for filling the "BarcodeParameters" parameter that is used for receiving a barcode image.
// 
// Returns:
//   Structure:
//   * Width - Number - width of a barcode image.
//   * Height - Number - height of a barcode image.
//   * CodeType - Number - of a barcode.
//       Possible values:
//      99 -  Autoselect
//      0 - EAN8
//      1 - EAN13
//      2 - EAN128
//      3 - Code39
//      4 - Code128
//      5 - Code16k
//      6 - PDF417
//      7 - Standart (Industrial) 2 of 5
//      8 - Interleaved 2 of 5
//      9 - Code39 Расширение
//      10 - Code93
//      11 - ITF14
//      12 - RSS14
//      14 - EAN13AddOn2
//      15 - EAN13AddOn5
//      16 - QR
//      17 - GS1DataBarExpandedStacked
//      18 - Datamatrix ASCII
//      19 - Datamatrix BASE256
//      20 - Datamatrix TEXT
//      21 - Datamatrix C40
//      22 - Datamatrix X12
//      23 - Datamatrix EDIFACT
//      24 - Datamatrix GS1ASCII:
//   * ShowText - Boolean - display the HRI text for a barcode.
//   * FontSize - Number - font size of the HRI text for a barcode.
//   * AngleOfRotation - Number - rotation angle.
//      Possible values: 0, 90, 180, 270.
//   * Barcode - String - a barcode value as a row or Base64.
//   * InputDataType - Number - input data type 
//      Possible values: 0 - Row, 1 - Base64
//   * Transparent - Boolean - transparent background of a barcode image.
//   * QRErrorCorrectionLevel - Number - correction level of the QR barcode.
//      Possible values: 0 - L, 1 - M, 2 - Q, 3 - H.
//   * Zoomable - Boolean - scale a barcode image.
//   * MaintainAspectRatio - Boolean - save proportions of a barcode image.                                                              
//   * VerticalAlignment - Number - vertical alignment of a barcode.
//      Possible values: 1 - Top, 2 - Center, 3 - Bottom
//   * GS1DatabarRowsCount - Number - a number of rows in the GS1Databar barcode.
//   * RemoveExtraBackgroud - Boolean
//   * LogoImage - String - a string with base64 presentation of a PNG logo image.
//   * LogoSizePercentFromBarcode - Number - a percentage of the generated QR code to add a logo.
//
Function BarcodeGenerationParameters() Export
	
	BarcodeParameters = New Structure;
	BarcodeParameters.Insert("Width"            , 100);
	BarcodeParameters.Insert("Height"            , 100);
	BarcodeParameters.Insert("CodeType"           , 99);
	BarcodeParameters.Insert("ShowText"   , True);
	BarcodeParameters.Insert("FontSize"      , 12);
	BarcodeParameters.Insert("AngleOfRotation"      , 0);
	BarcodeParameters.Insert("Barcode"          , "");
	BarcodeParameters.Insert("Transparent"     , True);
	BarcodeParameters.Insert("QRErrorCorrectionLevel", 1);
	BarcodeParameters.Insert("Zoomable"           , False);
	BarcodeParameters.Insert("MaintainAspectRatio"       , False);
	BarcodeParameters.Insert("VerticalAlignment" , 1); 
	BarcodeParameters.Insert("GS1DatabarRowsCount", 2);
	BarcodeParameters.Insert("InputDataType", 0);
	BarcodeParameters.Insert("RemoveExtraBackgroud" , False); 
	BarcodeParameters.Insert("LogoImage");
	BarcodeParameters.Insert("LogoSizePercentFromBarcode");
	
	Return BarcodeParameters;
	
EndFunction

// Barcode image generation.
//
// Parameters: 
//   BarcodeParameters - See BarcodeGeneration.BarcodeGenerationParameters.
//
// Returns: 
//   Structure:
//      Result - Boolean - barcode generation result.
//      BinaryData - BinaryData - binary data of a barcode image.
//      Picture - Picture - a picture with the generated barcode or UNDEFINED.
//
Function TheImageOfTheBarcode(BarcodeParameters) Export
	
	SystemInfo = New SystemInfo;
	PlatformTypeComponents = String(SystemInfo.PlatformType);
	
	AddIn = BarcodeGenerationServerCached.ToConnectAComponentGeneratingAnImageOfTheBarcode(PlatformTypeComponents);
	
	If AddIn = Undefined Then
		MessageText = NStr("en = 'An error occurred while attaching the barcode printing add-in.';");
	#If Not MobileAppServer Then
		WriteLogEvent(NStr("en = 'Barcode generation error';", 
			Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, 
			MessageText);
	#EndIf
		Raise MessageText;
	EndIf;
	
	Return PrepareABarcodeImage(AddIn, BarcodeParameters); 
	 
EndFunction

// Returns binary data for generating a QR code.
//
// Parameters:
//  QRString         - String - data to be placed in the QR code.
//
//  CorrectionLevel - Number - an image defect level, at which it is still possible to completely recognize this QR
//                             code.
//                     The parameter must have an integer type and have one of the following possible values:
//                     0 (7% defect allowed), 1 (15% defect allowed), 2 (25% defect allowed), 3 (35% defect allowed).
//
//  Size           - Number - determines the size of the output image side, in pixels.
//                     If the smallest possible image size is greater than this parameter, the code is not generated.
//
// Returns:
//  BinaryData  - 
// 
// Example:
//  
//  // Printing a QR code containing information encrypted according to UFEBM.
//
//  QRString = PrintManagement.UFEBMFormatString(PaymentDetails);
//  ErrorText = "";
//  QRCodeData = AccessManagement.QRCodeData(QRString, 0, 190, ErrorText);
//  If Not BlankString (ErrorText)
//      Common.MessageToUser(ErrorText);
//  EndIf;
//
//  QRCodePicture = New Picture(QRCodeData);
//  TemplateArea.Pictures.QRCode.Picture = QRCodePicture;
//
Function QRCodeData(QRString, CorrectionLevel, Size) Export
	
	BarcodeParameters = BarcodeGenerationParameters();
	BarcodeParameters.Width = Size;
	BarcodeParameters.Height = Size;
	BarcodeParameters.Barcode = QRString;
	BarcodeParameters.QRErrorCorrectionLevel = CorrectionLevel;
	BarcodeParameters.CodeType = 16; // QR
	BarcodeParameters.RemoveExtraBackgroud = True;
	
	Try
		TheResultOfTheFormationOfBarcode = TheImageOfTheBarcode(BarcodeParameters);
		BinaryPictureData = TheResultOfTheFormationOfBarcode.BinaryData;
	Except
	#If Not MobileAppServer Then
		WriteLogEvent(NStr("en = 'Barcode generation error';", 
			Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	#EndIf
	EndTry;
	
	Return BinaryPictureData;
	
EndFunction

#EndRegion

#Region Internal

// Attaches the add-in.
//
// Returns: 
//   AddInObject
//   Undefined - if failed to import the add-in.
//
Function ToConnectAComponentGeneratingAnImageOfTheBarcode() Export
	
#If Not MobileAppServer Then  
	SetSafeModeDisabled(True);
#EndIf
	AddIn = Undefined;
	
#If Not MobileAppServer Then
	If Common.SeparatedDataUsageAvailable() Then
		If Common.SubsystemExists("StandardSubsystems.AddIns") Then
			ModuleAddInsServer = Common.CommonModule("AddInsServer");
			ConnectionResult = ModuleAddInsServer.AttachAddInSSL("Barcode");
			If ConnectionResult.Attached Then
				AddIn = ConnectionResult.Attachable_Module;
			EndIf;
		EndIf;
	EndIf;
#EndIf
	
	If AddIn = Undefined Then 
		AddIn = Common.AttachAddInFromTemplate("Barcode", "CommonTemplate.BarcodePrintingAddIn");
	EndIf;
	
	If AddIn = Undefined Then 
		Return Undefined;
	EndIf;
	
	// 
	// 
	If AddIn.FindFont("Tahoma") Then
		// 
		AddIn.Font = "Tahoma";
	Else
		// 
		// 
		For Cnt = 0 To AddIn.NumberOfFonts -1 Do
			// 
			CurrentFont = AddIn.FontAt(Cnt);
			// 
			If CurrentFont <> Undefined Then
				// 
				AddIn.Font = CurrentFont;
				Break;
			EndIf;
		EndDo;
	EndIf;
	// 
	AddIn.FontSize = 12;
	
	Return AddIn;
	
EndFunction

#EndRegion

#Region Private

// Prepare a barcode image.
//
// Parameters: 
//   AddIn - See BarcodeGenerationServerCached.ToConnectAComponentGeneratingAnImageOfTheBarcode
//   BarcodeParameters - See BarcodeGeneration.BarcodeGenerationParameters
//
// Returns: 
//   Structure:
//      Result - Boolean - a barcode generation result.
//      BinaryData - BinaryData - binary data of a barcode image.
//      Picture - Picture - a picture with the generated barcode or UNDEFINED.
//
Function PrepareABarcodeImage(AddIn, BarcodeParameters)
	
	// Result. 
	OperationResult = New Structure();
	OperationResult.Insert("Result", False);
	OperationResult.Insert("BinaryData");
	OperationResult.Insert("Picture");
	
	// Specify the size of the picture being generated.
	TheWidthOfTheBarcode = Round(BarcodeParameters.Width);
	TheHeightOfTheBarcode = Round(BarcodeParameters.Height);
	If TheWidthOfTheBarcode <= 0 Then
		TheWidthOfTheBarcode = 1
	EndIf;
	If TheHeightOfTheBarcode <= 0 Then
		TheHeightOfTheBarcode = 1
	EndIf;
	AddIn.Width = TheWidthOfTheBarcode;
	AddIn.Height = TheHeightOfTheBarcode;
	AddIn.AutoType = False;
	
	TimeBarcode = String(BarcodeParameters.Barcode); // 
	
	If BarcodeParameters.CodeType = 99 Then
		AddIn.AutoType = True;
	Else
		AddIn.AutoType = False;
		AddIn.CodeType = BarcodeParameters.CodeType;
	EndIf;
	
	If BarcodeParameters.Property("Transparent") Then
		AddIn.BgTransparent = BarcodeParameters.Transparent;
	EndIf;
	
	If BarcodeParameters.Property("InputDataType") Then
		AddIn.InputDataType = BarcodeParameters.InputDataType;
	EndIf;
	
	If BarcodeParameters.Property("GS1DatabarRowsCount") Then
		AddIn.GS1DatabarRowCount = BarcodeParameters.GS1DatabarRowsCount;
	EndIf;
	
	If BarcodeParameters.Property("RemoveExtraBackgroud") Then
		AddIn.RemoveExtraBackgroud = BarcodeParameters.RemoveExtraBackgroud;
	EndIf;
	
	AddIn.TextVisible = BarcodeParameters.ShowText;
	// 
	AddIn.CodeValue = TimeBarcode;
	// 
	AddIn.CanvasRotation = ?(BarcodeParameters.Property("AngleOfRotation"), BarcodeParameters.AngleOfRotation, 0);
	// 
	AddIn.QRErrorCorrectionLevel = ?(BarcodeParameters.Property("QRErrorCorrectionLevel"), BarcodeParameters.QRErrorCorrectionLevel, 1);
	
	// For the compatibility with the previous versions of Peripheral Equipment Library.
	If Not BarcodeParameters.Property("Zoomable")
		Or (BarcodeParameters.Property("Zoomable") And BarcodeParameters.Zoomable) Then
		
		If Not BarcodeParameters.Property("MaintainAspectRatio")
				Or (BarcodeParameters.Property("MaintainAspectRatio") And Not BarcodeParameters.MaintainAspectRatio) Then
			// If the specified width is less than the minimal for this barcode.
			If AddIn.Width < AddIn.CodeMinWidth Then
				AddIn.Width = AddIn.CodeMinWidth;
			EndIf;
			// If the specified height is less than the minimal for this barcode.
			If AddIn.Height < AddIn.CodeMinHeight Then
				AddIn.Height = AddIn.CodeMinHeight;
			EndIf;
		ElsIf BarcodeParameters.Property("MaintainAspectRatio") And BarcodeParameters.MaintainAspectRatio Then
			While AddIn.Width < AddIn.CodeMinWidth 
				Or AddIn.Height < AddIn.CodeMinHeight Do
				// If the specified width is less than the minimal for this barcode.
				If AddIn.Width < AddIn.CodeMinWidth Then
					AddIn.Width = AddIn.CodeMinWidth;
					AddIn.Height = Round(AddIn.CodeMinWidth / TheWidthOfTheBarcode) * TheHeightOfTheBarcode;
				EndIf;
				// If the specified height is less than the minimal for this barcode.
				If AddIn.Height < AddIn.CodeMinHeight Then
					AddIn.Height = AddIn.CodeMinHeight;
					AddIn.Width = Round(AddIn.CodeMinHeight / TheHeightOfTheBarcode) * TheWidthOfTheBarcode;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	// CodeVerticalAlignment: 1 - align top, 2 - align center, 3 - align bottom.
	If BarcodeParameters.Property("VerticalAlignment") And (BarcodeParameters.VerticalAlignment > 0) Then
		AddIn.CodeVerticalAlign = BarcodeParameters.VerticalAlignment;
	EndIf;
	
	If BarcodeParameters.Property("FontSize") And (BarcodeParameters.FontSize > 0) 
		And (BarcodeParameters.ShowText) And (AddIn.FontSize <> BarcodeParameters.FontSize) Then
			AddIn.FontSize = BarcodeParameters.FontSize;
	EndIf;
	
	If BarcodeParameters.Property("FontSize") And BarcodeParameters.FontSize > 0
		And BarcodeParameters.Property("MonochromeFont") Then
		If BarcodeParameters.MonochromeFont Then
			AddIn.MaxFontSizeForLowDPIPrinters = BarcodeParameters.FontSize + 1;
		Else
			AddIn.MaxFontSizeForLowDPIPrinters = -1;
		EndIf;
	EndIf;
	
	If BarcodeParameters.CodeType = 16 Then // QR
		If BarcodeParameters.Property("LogoImage") And ValueIsFilled(BarcodeParameters.LogoImage) Then 
			AddIn.LogoImage = BarcodeParameters.LogoImage;    
		Else
			AddIn.LogoImage = "";
		EndIf;
		If BarcodeParameters.Property("LogoSizePercentFromBarcode") And Not IsBlankString(BarcodeParameters.LogoSizePercentFromBarcode) Then 
			AddIn.LogoSizePercentFromBarcode = BarcodeParameters.LogoSizePercentFromBarcode;
		EndIf;
	EndIf;
		
	// Generate a picture.
	BinaryPictureData = AddIn.GetBarcode();
	OperationResult.Result = AddIn.Result = 0;
	// If the picture is generated successfully.
	If BinaryPictureData <> Undefined Then
		OperationResult.BinaryData = BinaryPictureData;
		OperationResult.Picture = New Picture(BinaryPictureData); // 
	EndIf;
	
	Return OperationResult;
	
EndFunction

#EndRegion
