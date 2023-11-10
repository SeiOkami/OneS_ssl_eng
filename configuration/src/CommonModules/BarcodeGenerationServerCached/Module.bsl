///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// The function attaches the add-in and its initial setup.
// Attaches the add-in.
// The function returns Undefined if failed to import the add-in.
//
// Parameters:
//   PlatformTypeComponents - String - platform type
//
// Returns:
//   AddInObject:
//    * ECL - Number
//    * GS1DatabarRowCount - Number
//    * AutoType - Boolean
//    * Version - String
//    * CodeVerticalAlign - Number
//    * CanvasYOffset - Number
//    * CodeShowCS - Boolean
//    * CodeAlignment - Number
//    * Height - Number
//    * CanvasXOffset - Number
//    * GraphicsPresent - Boolean
//    * CodeValue - String
//    * FileName - String
//    * ColumnCount - Number
//    * RowCount - Number
//    * FontCount - Number
//    * CodeCheckSymbol - String
//    * LogoImage - Picture 
//    * LogoSizePercentFromBarcode - Number
//    * MaxFontSizeForLowDPIPrinters - Number
//    * CodeMinHeight - Number
//    * CodeMinWidth - Number
//    * TextAlign - Number
//    * TextVisible - Boolean
//    * TextPos - Number
//    * BgTransparent - Boolean
//    * AspectRatio - String
//    * CodeSentinel - Number
//    * CanvasMargin - Number
//    * FontSize - Number
//    * Result - Number
//    * ContainsCS - Boolean
//    * CodeText - String
//    * InputDataType - Number
//    * CodeType - Number
//    * RemoveExtraBackgroud - Boolean
//    * CanvasRotation - Number
//    * QRErrorCorrectionLevel - Number
//    * BarColor - Number
//    * TextColor - Number
//    * BgColor - Number
//    * Width - Number
//    * Font - String
//   Undefined
//
Function ToConnectAComponentGeneratingAnImageOfTheBarcode(PlatformTypeComponents) Export
	
	Return BarcodeGeneration.ToConnectAComponentGeneratingAnImageOfTheBarcode();
	
EndFunction

#EndRegion