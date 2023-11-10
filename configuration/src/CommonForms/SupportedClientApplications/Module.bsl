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
	
	If TypeOf(Parameters.SupportedClients) = Type("Structure") Then 
		FillPropertyValues(ThisObject, Parameters.SupportedClients);
	EndIf;
	
	PictureAvailable = PictureLib.AddInIsAvailable;
	PictureUnavailable = PictureLib.AddInNotAvailable;
	
	Items.Windows_x86_1CEnterprise.Picture = ?(Windows_x86, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_Chrome.Picture = ?(Windows_x86_Chrome, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_Firefox.Picture = ?(Windows_x86_Firefox, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_MSIE.Picture = ?(Windows_x86_MSIE, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_64_1CEnterprise.Picture = ?(Windows_x86_64, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_64_Chrome.Picture = ?(Windows_x86_Chrome, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_64_Firefox.Picture = ?(Windows_x86_Firefox, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_64_MSIE.Picture = ?(Windows_x86_64_MSIE, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_1CEnterprise.Picture = ?(Linux_x86, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_Chrome.Picture = ?(Linux_x86_Chrome, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_Firefox.Picture = ?(Linux_x86_Firefox, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_64_1CEnterprise.Picture = ?(Linux_x86_64, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_64_Chrome.Picture = ?(Linux_x86_64_Chrome, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_64_Firefox.Picture = ?(Linux_x86_64_Firefox, PictureAvailable, PictureUnavailable);
	Items.MacOS_x86_64_1CEnterprise.Picture = ?(MacOS_x86_64, PictureAvailable, PictureUnavailable);
	Items.MacOS_x86_64_Safari.Picture = ?(MacOS_x86_64_Safari, PictureAvailable, PictureUnavailable);
	Items.MacOS_x86_64_Chrome.Picture = ?(MacOS_x86_64_Chrome, PictureAvailable, PictureUnavailable);
	Items.MacOS_x86_64_Firefox.Picture = ?(MacOS_x86_64_Firefox, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_YandexBrowser.Picture = ?(Windows_x86_YandexBrowser, PictureAvailable, PictureUnavailable);
	Items.Windows_x86_64_YandexBrowser.Picture = ?(Windows_x86_64_YandexBrowser, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_YandexBrowser.Picture = ?(Linux_x86_YandexBrowser, PictureAvailable, PictureUnavailable);
	Items.Linux_x86_64_YandexBrowser.Picture = ?(Linux_x86_64_YandexBrowser, PictureAvailable, PictureUnavailable);
	Items.MacOS_x86_64_YandexBrowser.Picture = ?(MacOS_x86_64_YandexBrowser, PictureAvailable, PictureUnavailable);
	
	
EndProcedure

#EndRegion