///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Sets up multilingual data settings.
//
// Parameters:
//   Settings - Structure - Collection of subsystem settings. Has the following attributes:
//     * AdditionalLanguageCode1 - String - a code of the first default additional language.
//     * AdditionalLanguageCode2 - String - a code of the second default additional language.
//     * MultilanguageData - Boolean - if True, attributes supporting the ability to enter data in several
//                                       languages ​​will automatically add an interface for entering multilingual data.
//
// Example:
//  Settings.AdditionalLanguageCode1 = "en";
//  Settings.AdditionalLanguageCode2 = "it";
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

#EndRegion
