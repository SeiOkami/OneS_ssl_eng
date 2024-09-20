///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
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
//                                 
//
//  
//      
//          
//          
//          
//          
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	// 
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	MainCountry           = MainCountry();
	CIKind  = ContactsManagerInternal.ContactInformationKindStructure(Parameters.ContactInformationKind);  // See ContactsManagerInternal.ContactInformationKindStructure
	ContactInformationKind = CIKind;
	OnCreateAtServerStoreChangeHistory();
	
	Title = ?(IsBlankString(Parameters.Title), String(CIKind.Ref), Parameters.Title);
	
	HideObsoleteAddresses  = ContactInformationKind.HideObsoleteAddresses;
	ContactInformationType     = ContactInformationKind.Type;
	
	// Attempting to fill data based on parameter values.
	FieldValues = DefineAddressValue(Parameters);
	
	If IsBlankString(FieldValues) Then
		LocalityDetailed = ContactsManager.NewContactInformationDetails(Enums.ContactInformationTypes.Address); // 
		LocalityDetailed.AddressType = ContactsManagerClientServer.CustomFormatAddress();
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(FieldValues) Then
		AddressData = ContactsManagerInternal.JSONToContactInformationByFields(FieldValues, Enums.ContactInformationTypes.Address);
		LocalityDetailed = PrepareAddressForInput(AddressData);
	Else
		XDTOContact = ExtractObsoleteAddressFormat(FieldValues, ContactInformationType);
		If XDTOContact <> Undefined Then
			AddressData = ContactsManagerInternal.ContactInformationToJSONStructure(XDTOContact, ContactInformationType);
			LocalityDetailed = PrepareAddressForInput(AddressData);
		EndIf;
	EndIf;
	
	FillInPredefinedAddressOptions(Parameters);
	SetAttributesValueByContactInformation(ThisObject, LocalityDetailed);
	
	If ValueIsFilled(LocalityDetailed.Comment) Then
		Items.PagesMain.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		Items.CommentPage.Picture = CommonClientServer.CommentPicture(Comment);
	Else
		Items.PagesMain.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	SetFormUsageKey();
	Items.FormClearAddress.Enabled = Not Parameters.ReadOnly;
	Items.CommandAddGroup.Visible = Not Parameters.ReadOnly;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningTextOnOpen) Then
		CommonClient.MessageToUser(WarningTextOnOpen,, WarningFieldOnOpen);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CountryOnChange(Item)
	
	DisplayFieldsByAddressType();
	
EndProcedure

&AtClient
Procedure CountryClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CountryAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	If Waiting = 0 Then
		// Generating the quick selection list.
		If IsBlankString(Text) Then
			ChoiceData = New ValueList;
		EndIf;
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure CountryTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If IsBlankString(Text) Then
		StandardProcessing = False;
	EndIf;
	
#If WebClient Then
	// 
	StandardProcessing = False;
	ChoiceData         = New ValueList;
	ChoiceData.Add(Country);
#EndIf

EndProcedure

&AtClient
Procedure CountryChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ContactsManagerClient.WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing);
	
EndProcedure


&AtClient
Procedure CommentOnChange(Item)
	
	LocalityDetailed.Comment = Comment;
	AttachIdleHandler("SetCommentIcon", 0.1, True);
	
EndProcedure

&AtClient
Procedure ForeignAddressPresentationOnChange(Item)
	
	LocalityDetailed.street = AddressPresentation;
	LocalityDetailed.AddressType = ContactsManagerClientServer.CustomFormatAddress();
	LocalityDetailed.Comment = Comment;
	LocalityDetailed.Country = String(Country);
	
EndProcedure

// 

&AtClient
Procedure AddressOnDateAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	If StrCompare(Text, TheBeginningOfTheAccounting()) = 0 Or IsBlankString(Text) Then
		Items.AddressOnDate.EditFormat = "";
	EndIf;
EndProcedure

&AtClient
Procedure AddressOnDateOnChange(Item)
	
	If Not EnterNewAddress Then
		
		Filter = New Structure("Kind", ContactInformationKindDetails(ThisObject).Ref);
		FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		Result = DefineValidDate(AddressOnDate, FoundRows);
		
		If Result.CurrentRow <> Undefined Then
			Type = Result.CurrentRow.Type;
			AddressValidFrom = Result.ValidFrom;
			LocalityDetailed = AddressWithHistory(Result.CurrentRow.Value);
		Else
			Type = PredefinedValue("Enum.ContactInformationTypes.Address");
			AddressValidFrom = AddressOnDate;
			LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(Type);
		EndIf;
		
		
		
		If ValueIsFilled(Result.ValidTo) Then
			TextHistoricalAddress = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'valid until %1';"), Format(Result.ValidTo - 10, "DLF=DD"));
		Else
			TextHistoricalAddress = NStr("en = 'valid as of today.';");
		EndIf;
		Items.AddressStillValid.Title = TextHistoricalAddress;
	Else
		AddressValidFrom = AddressOnDate;
	EndIf;
	
	TextOfAccountingStart = TheBeginningOfTheAccounting();
	Items.AddressOnDate.EditFormat = ?(ValueIsFilled(AddressOnDate), "", "DF='""" + TextOfAccountingStart  + """'");
	
EndProcedure

&AtServerNoContext
Function AddressWithHistory(FieldValues)
	
	Return ContactsManagerInternal.JSONToContactInformationByFields(FieldValues, Enums.ContactInformationTypes.Address);
	
EndFunction

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	ConfirmAndClose();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Modified = False;
	Close();
EndProcedure

&AtClient
Procedure ClearAddress(Command)
	
	ClearAddressClient();
	
	
EndProcedure

&AtClient
Procedure ChangeHistory(Command)
	
	AdditionalParameters = New Structure;
	
	AdditionalAttributesDetails = ContactInformationAdditionalAttributesDetails;
	ContactInformationList = FillContactInformationList( ContactInformationKindDetails(ThisObject).Ref, AdditionalAttributesDetails);
	
	FormParameters = New Structure("ContactInformationList", ContactInformationList);
	FormParameters.Insert("ContactInformationKind",  ContactInformationKindDetails(ThisObject).Ref);
	FormParameters.Insert("ReadOnly", ReadOnly);
	FormParameters.Insert("FromAddressEntryForm", True);
	FormParameters.Insert("ValidFrom", AddressOnDate);
	
	ClosingNotification = New NotifyDescription("AfterClosingHistoryForm", ThisObject, AdditionalParameters);
	OpenForm("DataProcessor.ContactInformationInput.Form.ContactInformationHistory", FormParameters, ThisObject,,,, ClosingNotification);
	
EndProcedure

&AtClient
Procedure AddComment(Command)
	Items.PagesMain.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	Items.PagesMain.CurrentPage = Items.CommentPage;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCommentIcon()
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Comment);
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Modified Then // When unmodified, it functions as "cancel".
		Context = New Structure("ContactInformationKind, LocalityDetailed, MainCountry, Country");
		FillPropertyValues(Context, ThisObject);
		Result = FlagUpdateSelectionResults(Context, ReturnValueList);
		
		// Reading contact information kind flags again.
		ContactInformationKind = Context.ContactInformationKind;
		
		Result = Result.ChoiceData;
		If ContactInformationKind.StoreChangeHistory Then
			ProcessContactInformationWithHistory(Result);
		EndIf;
		
		If TypeOf(Result) = Type("Structure") Then
			Result.Insert("ContactInformationAdditionalAttributesDetails", ContactInformationAdditionalAttributesDetails);
		EndIf;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	ElsIf Comment <> CommentCopy Then
		// 
		Result = CommentChoiceOnlyResult(Parameters.FieldValues, Parameters.Presentation, Comment);
		Result = Result.ChoiceData;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) And IsOpen() Then
		ClearModifiedOnChoice();
		SaveFormState();
		Close(Result);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessContactInformationWithHistory(Result)
	
	Result.Insert("ValidFrom", ?(EnterNewAddress, AddressOnDate, AddressValidFrom));
	AttributeName = "";
	Filter = New Structure("Kind", Result.Kind);
	
	ValidAddressString = Undefined;
	DateChanged         = True;
	CurrentAddressDate        = CommonClient.SessionDate();
	Delta                   = AddressOnDate - CurrentAddressDate;
	MinDelta        = ?(Delta > 0, Delta, -Delta);
	FoundRows          = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
	For Each FoundRow In FoundRows Do
		If ValueIsFilled(FoundRow.AttributeName) Then
			AttributeName = FoundRow.AttributeName;
		EndIf;
		If FoundRow.ValidFrom = AddressOnDate Then
			DateChanged = False;
			ValidAddressString = FoundRow;
			Break;
		EndIf;
		
		Delta = CurrentAddressDate - FoundRow.ValidFrom;
		Delta = ?(Delta > 0, Delta, -Delta);
		If Delta <= MinDelta Then
			MinDelta = Delta;
			ValidAddressString = FoundRow;
		EndIf;
	EndDo;
	
	If DateChanged Then
		
		Filter = New Structure("ValidFrom, Kind", AddressValidFrom, Result.Kind);
		StringsWithAddress = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		
		EditableAddressPresentation = ?(StringsWithAddress.Count() > 0, StringsWithAddress[0].Presentation, "");
		If StrCompare(Result.Presentation, EditableAddressPresentation) <> 0 Then
			NewContactInformation = ContactInformationAdditionalAttributesDetails.Add();
			FillPropertyValues(NewContactInformation, Result);
			NewContactInformation.FieldValues           = Result.ContactInformation;
			NewContactInformation.Value                = Result.Value;
			NewContactInformation.ValidFrom              = AddressOnDate;
			NewContactInformation.StoreChangeHistory = True;
			If ValidAddressString = Undefined Then
				Filter = New Structure("IsHistoricalContactInformation, Kind", False, Result.Kind);
				FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
				For Each FoundRow In FoundRows Do
					FoundRow.IsHistoricalContactInformation = True;
					FoundRow.AttributeName = "";
				EndDo;
				NewContactInformation.AttributeName = AttributeName;
				NewContactInformation.IsHistoricalContactInformation = False;
			Else
				NewContactInformation.IsHistoricalContactInformation = True;
				Result.Presentation                = ValidAddressString.Presentation;
				Result.ContactInformation         = ValidAddressString.FieldValues;
				Result.Value = ValidAddressString.Value;
			EndIf;
		ElsIf StrCompare(Result.Comment, ValidAddressString.Comment) <> 0 And StringsWithAddress.Count() > 0 Then
			// 
			StringsWithAddress[0].Comment = Result.Comment;
		EndIf;
	Else
		If StrCompare(Result.Presentation, ValidAddressString.Presentation) <> 0
			Or StrCompare(Result.Comment, ValidAddressString.Comment) <> 0 Then
				FillPropertyValues(ValidAddressString, Result);
				ValidAddressString.FieldValues                       = Result.ContactInformation;
				ValidAddressString.Value                            = Result.Value;
				ValidAddressString.AttributeName                        = AttributeName;
				ValidAddressString.IsHistoricalContactInformation = False;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AfterClosingHistoryForm(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	EnterNewAddress = ?(Result.Property("EnterNewAddress"), Result.EnterNewAddress, False);
	If EnterNewAddress Then
		AddressValidFrom = AddressOnDate;
		AddressOnDate = Result.CurrentAddress;
		LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	Else
		Filter = New Structure("Kind",  ContactInformationKindDetails(ThisObject).Ref);
		FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		
		AttributeName = "";
		For Each ContactInformationRow In FoundRows Do
			If Not ContactInformationRow.IsHistoricalContactInformation Then
				AttributeName = ContactInformationRow.AttributeName;
			EndIf;
			ContactInformationAdditionalAttributesDetails.Delete(ContactInformationRow);
		EndDo;
		
		For Each ContactInformationRow In Result.History Do
			RowData = ContactInformationAdditionalAttributesDetails.Add();
			FillPropertyValues(RowData, ContactInformationRow);
			If Not ContactInformationRow.IsHistoricalContactInformation Then
				RowData.AttributeName = AttributeName;
			EndIf;
			If BegOfDay(Result.CurrentAddress) = BegOfDay(ContactInformationRow.ValidFrom) Then
				AddressOnDate = Result.CurrentAddress;
				LocalityDetailed = JSONStringToStructure(ContactInformationRow.Value);
				
			EndIf;
		EndDo;
	EndIf;
	
	DisplayInformationAboutAddressValidityDate(AddressOnDate);
	
	If Not Modified Then
		Modified = Result.Modified;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JSONStringToStructure(Value)
	Return ContactsManagerInternal.JSONToContactInformationByFields(Value, Enums.ContactInformationTypes.Address);
EndFunction

&AtClient
Procedure SaveFormState()
	SetFormUsageKey();
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	Modified = False;
	CommentCopy   = Comment;
EndProcedure

&AtServerNoContext
Function FlagUpdateSelectionResults(Context, ReturnValueList = False)
	// Update some flags.
	FlagsValue = ContactsManagerInternal.ContactInformationKindStructure(ContactInformationKindDetails(Context).Ref);
	
	Context.ContactInformationKind.OnlyNationalAddress = FlagsValue.OnlyNationalAddress;
	Context.ContactInformationKind.CheckValidity   = FlagsValue.CheckValidity;

	Return SelectionResult(Context, ReturnValueList);
EndFunction

// Parameters:
//  Context - Structure:
//   * ContactInformationKind - See ContactsManagerInternal.ContactInformationKindStructure
//   * LocalityDetailed - Structure
//   * MainCountry - CatalogRef.WorldCountries
//   * Country - CatalogRef.WorldCountries
//  ReturnValueList - Boolean
// Returns:
//  Structure:
//   * ChoiceData - Structure:
//     ** Presentation - String
//     ** ContactInformation - String
//     ** Value - String
//     ** Comment - String
//     ** EnteredInFreeFormat - Boolean
//     ** AsHyperlink - Boolean
//     ** Kind - CatalogRef.ContactInformationKinds
//     ** Type - EnumRef.ContactInformationTypes
//   * FillingErrors - Array of String
//
&AtServerNoContext
Function SelectionResult(Context, ReturnValueList = False)

	LocalityDetailed = Context.LocalityDetailed;
	Result      = New Structure("ChoiceData, FillingErrors");
	
	If Context.ContactInformationKind.IncludeCountryInPresentation And ValueIsFilled(LocalityDetailed.country) Then
		LocalityDetailed.Value = LocalityDetailed.country + ", " + LocalityDetailed.street;
	Else
		LocalityDetailed.Value = LocalityDetailed.street;
	EndIf;
	
	ContactInformationToXML = "";
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		ContactInformationToXML = ModuleContactsManagerLocalization.ContactsFromJSONToXML(LocalityDetailed, Context.ContactInformationKind.Type)
	EndIf;
	
	Result.ChoiceData = New Structure;
	Result.ChoiceData.Insert("Presentation", LocalityDetailed.Value);
	Result.ChoiceData.Insert("ContactInformation", ContactInformationToXML);
	Result.ChoiceData.Insert("Value", ContactsManagerInternal.ToJSONStringStructure(LocalityDetailed));
	Result.ChoiceData.Insert("Comment", LocalityDetailed.Comment);
	Result.ChoiceData.Insert("EnteredInFreeFormat",
		ContactsManagerInternal.AddressEnteredInFreeFormat(LocalityDetailed));
		
		
	
	// 
	Result.FillingErrors = New Array;
		
	If Context.ContactInformationKind.Type = Enums.ContactInformationTypes.Address 
		And Context.ContactInformationKind.EditingOption = "Dialog" Then
			AsHyperlink = True;
	Else
			AsHyperlink = False;
	EndIf;
	Result.ChoiceData.Insert("AsHyperlink", AsHyperlink);
	
	// 
	Result.ChoiceData.Presentation = TrimAll(StrReplace(Result.ChoiceData.Presentation, Chars.LF, " "));
	Result.ChoiceData.Insert("Kind", 	ContactInformationKindDetails(Context).Ref);
	Result.ChoiceData.Insert("Type", Context.ContactInformationKind.Type);
	
	Return Result;
EndFunction

&AtServerNoContext
Function FillContactInformationList(ContactInformationKind, ContactInformationAdditionalAttributesDetails)

	Filter = New Structure("Kind", ContactInformationKind);
	FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
	
	ContactInformationList = New Array;
	For Each ContactInformationRow In FoundRows Do
		ContactInformation = New Structure("Presentation, Value, FieldValues, ValidFrom, Comment");
		FillPropertyValues(ContactInformation, ContactInformationRow);
		ContactInformationList.Add(ContactInformation);
	EndDo;
	
	Return ContactInformationList;
EndFunction

&AtServer
Function CommentChoiceOnlyResult(ContactInfo, Presentation, Comment)
	
	If IsBlankString(ContactInfo) Then
		
		If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
			ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
			NewContactInfo = ModuleContactsManagerLocalization.XMLAddressInXDTO("");
			NewContactInfo.Comment = Comment;
			NewContactInfo = ModuleContactsManagerLocalization.XDTOContactsInXML(NewContactInfo);
		Else
			NewContactInfo = "";
		EndIf;
		AddressEnteredInFreeFormat = False;
		
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInfo) Then
		// Копия
		NewContactInfo = ContactInfo;
		// 
		ContactsManager.SetContactInformationComment(NewContactInfo, Comment);
		AddressEnteredInFreeFormat = ContactsManagerInternal.AddressEnteredInFreeFormat(ContactInfo);
		
	Else
		NewContactInfo = ContactInfo;
		AddressEnteredInFreeFormat = False;
	EndIf;
	
	Result = New Structure("ChoiceData, FillingErrors", New Structure, New ValueList);
	Result.ChoiceData.Insert("ContactInformation", NewContactInfo);
	Result.ChoiceData.Insert("Presentation", Presentation);
	Result.ChoiceData.Insert("Comment", Comment);
	Result.ChoiceData.Insert("EnteredInFreeFormat", AddressEnteredInFreeFormat);
	Return Result;
EndFunction

&AtClient
Procedure DisplayFieldsByAddressType()
	
	LocalityDetailed.Country = TrimAll(Country);
	
EndProcedure

&AtServer
Procedure SetAttributesValueByContactInformation(AddressInfo3, AddressData)
	
	// 
	AddressInfo3.AddressPresentation = AddressData.Value;
	If AddressData.Property("Comment") Then
		AddressInfo3.Comment         = AddressData.Comment;
	EndIf;
	
	// 
	AddressInfo3.CommentCopy = AddressInfo3.Comment;
	
	RefToMainCountry = MainCountry();
	CountryData1 = Undefined;
	If AddressData.Property("Country") And ValueIsFilled(AddressData.Country) Then
		CountryData1 = Catalogs.WorldCountries.WorldCountryData(, TrimAll(AddressData.Country));
	EndIf;
	
	If CountryData1 = Undefined Then
		// 
		AddressInfo3.Country    = RefToMainCountry;
		AddressInfo3.CountryCode = RefToMainCountry.Code;
	Else
		AddressInfo3.Country    = CountryData1.Ref;
		AddressInfo3.CountryCode = CountryData1.Code;
	EndIf;
	
	AddressItems = New Array;
	If ValueIsFilled(AddressData.city) Then
		AddressItems.Add(AddressData.city);
	EndIf;
	If ValueIsFilled(AddressData.street) Then
		AddressItems.Add(AddressData.street);
	EndIf;
	
	// address fields are blank but the presentation is filled in
	If AddressItems.Count() = 0 And ValueIsFilled(AddressData.value) Then
		AddressData.street = AddressData.value;
		AddressItems.Add(AddressData.street);
	EndIf;
	
	AddressInfo3.AddressPresentation = StrConcat(AddressItems, ", ");
	
EndProcedure

&AtServer
Procedure FillInPredefinedAddressOptions(Var_Parameters)
	
	If Var_Parameters.Property("IndexOf") And ValueIsFilled(Var_Parameters.IndexOf) Then
		IndexOf = Var_Parameters.IndexOf;
		LocalityDetailed.ZipCode = IndexOf;
	EndIf;
	
	If Var_Parameters.Property("Country") And IsBlankString(LocalityDetailed.Country) Then
		
		If TypeOf(Var_Parameters.Country) = Type("CatalogRef.WorldCountries") Then
			If ValueIsFilled(Var_Parameters.Country) Then
				Country = Var_Parameters.Country;
				LocalityDetailed.Country = Common.ObjectAttributeValue(Var_Parameters.Country, "Description");
			Else
				Country = MainCountry();
				LocalityDetailed.Country = Common.ObjectAttributeValue(Country, "Description");
			EndIf;
		Else
			Country = ContactsManager.WorldCountryByCodeOrDescription(Var_Parameters.Country);
			If Country <> Catalogs.WorldCountries.EmptyRef() Then
				LocalityDetailed.Country = Var_Parameters.Country;
			Else
				Country = MainCountry();
				LocalityDetailed.Country = Common.ObjectAttributeValue(Country, "Description");
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayInformationAboutAddressValidityDate(ValidFrom)
	
	If EnterNewAddress Then
		TextHistoricalAddress = "";
		AddressOnDate = ValidFrom;
		Items.HistoricalAddressGroup.Visible = ValueIsFilled(ValidFrom);
	Else
		
		Filter = New Structure("Kind", ContactInformationKindDetails(ThisObject).Ref);
		FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
		If FoundRows.Count() = 0 
			Or (FoundRows.Count() = 1 And IsBlankString(FoundRows[0].Presentation)) Then
				AddressOnDate = Date(1, 1, 1);
				Items.HistoricalAddressGroup.Visible = False;
				Items.ChangeHistory.Visible = False;
		Else
			Result = DefineValidDate(ValidFrom, FoundRows);
			AddressOnDate = Result.ValidFrom;
			AddressValidFrom = Result.ValidFrom;
			
			If Not ValueIsFilled(Result.ValidFrom)
				And IsBlankString(Result.CurrentRow.Presentation) Then
					Items.HistoricalAddressGroup.Visible = False;
			ElsIf ValueIsFilled(Result.ValidTo) Then
				TextHistoricalAddress = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'valid until %1';"), Format(Result.ValidTo - 10, "DLF=DD"));
			Else
				TextHistoricalAddress = NStr("en = 'valid as of today.';");
			EndIf;
			DisplayRecordsCountInHistoryChange();
		EndIf;
	EndIf;
	
	Items.AddressStillValid.Title = TextHistoricalAddress;
	Items.AddressOnDate.EditFormat = ?(ValueIsFilled(AddressOnDate), "", "DF='""" + TheBeginningOfTheAccounting() + """'");
	
EndProcedure

&AtServer
Procedure DisplayRecordsCountInHistoryChange()
	
	Filter = New Structure("Kind", ContactInformationKindDetails(ThisObject).Ref);
	FoundRows = ContactInformationAdditionalAttributesDetails.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		Items.ChangeHistoryHyperlink.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Change history (%1)';"), FoundRows.Count());
		Items.ChangeHistoryHyperlink.Visible = True;
	ElsIf FoundRows.Count() = 1 And IsBlankString(FoundRows[0].FieldValues) Then
		Items.ChangeHistoryHyperlink.Visible = False;
	Else
		Items.ChangeHistoryHyperlink.Title = NStr("en = 'Change history';");
		Items.ChangeHistoryHyperlink.Visible = True;
	EndIf;

EndProcedure

&AtClientAtServerNoContext
Function DefineValidDate(ValidFrom, History)
	
	Result = New Structure("ValidTo, ValidFrom, CurrentRow");
	If History.Count() = 0 Then
		Return Result;
	EndIf;
	
	CurrentRow        = Undefined;
	ValidTo          = Undefined;
	Minimum              = -1;
	MinComparative = Undefined;
	
	For Each HistoryString In History Do
		Delta = HistoryString.ValidFrom - ValidFrom;
		If Delta <= 0 And (MinComparative = Undefined Or Delta > MinComparative) Then
			CurrentRow        = HistoryString;
			MinComparative = Delta;
		EndIf;

		If Minimum = -1 Then
			Minimum       = Delta + 1;
			CurrentRow = HistoryString;
		EndIf;
		If Delta > 0 And ModuleNumbers(Delta) < ModuleNumbers(Minimum) Then
			ValidTo = HistoryString.ValidFrom;
			Minimum     = ModuleNumbers(Delta);
		EndIf;
	EndDo;
	
	Result.ValidTo   = ValidTo;
	Result.ValidFrom    = CurrentRow.ValidFrom;
	Result.CurrentRow = CurrentRow;
	
	Return Result;
EndFunction

&AtClientAtServerNoContext
Function ModuleNumbers(Number)
	Return Max(Number, -Number);
EndFunction

&AtClient
Procedure ClearAddressClient()
	
	For Each AddressItem In LocalityDetailed Do
		
		If AddressItem.Key = "Type" Then
			Continue;
		ElsIf AddressItem.Key = "Buildings"  Or AddressItem.Key = "Apartments" Then
			LocalityDetailed[AddressItem.Key] = New Array;
		Else
			LocalityDetailed[AddressItem.Key] = "";
		EndIf;
		
	EndDo;
	
	LocalityDetailed.AddressType = ContactsManagerClientServer.CustomFormatAddress();
	
EndProcedure

&AtServer
Procedure SetFormUsageKey()
	WindowOptionsKey = String(Country);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServer
Procedure OnCreateAtServerStoreChangeHistory()
	
	If ContactInformationKind.StoreChangeHistory Then
		If Parameters.Property("ContactInformationAdditionalAttributesDetails") Then
			For Each CIRow In Parameters.ContactInformationAdditionalAttributesDetails Do
				NewRow = ContactInformationAdditionalAttributesDetails.Add();
				FillPropertyValues(NewRow, CIRow);
			EndDo;
		Else
			Items.ChangeHistory.Visible           = False;
		EndIf;
		Items.ChangeHistoryHyperlink.Visible = Not Parameters.Property("FromHistoryForm");
		EnterNewAddress = ?(Parameters.Property("EnterNewAddress"), Parameters.EnterNewAddress, False);
		If EnterNewAddress Then
			ValidFrom = Parameters.ValidFrom;
		Else
			ValidFrom = ?(ValueIsFilled(Parameters.ValidFrom), Parameters.ValidFrom, CurrentSessionDate());
		EndIf;
		DisplayInformationAboutAddressValidityDate(ValidFrom);
	Else
		Items.ChangeHistory.Visible           = False;
		Items.HistoricalAddressGroup.Visible    = False;
	EndIf;

EndProcedure

&AtServer
Function DefineAddressValue(Var_Parameters)
	
	If Var_Parameters.Property("Value") Then
		If IsBlankString(Var_Parameters.Value) And ValueIsFilled(Var_Parameters.FieldValues) Then
			FieldValues = Var_Parameters.FieldValues;
		Else
			FieldValues = Var_Parameters.Value;
		EndIf;
	Else
		FieldValues = Var_Parameters.FieldValues;
	EndIf;
	Return FieldValues;

EndFunction

&AtServer
Function ExtractObsoleteAddressFormat(Val FieldValues, Val ContactInformationType)
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		Return ModuleContactsManagerLocalization.ExtractObsoleteAddressFormat(FieldValues, ContactInformationType,
			Parameters, MainCountry);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServerNoContext
Function MainCountry()
	
	If ContactsManagerInternalCached.AreAddressManagementModulesAvailable() Then
		
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Return ModuleAddressManagerClientServer.MainCountry();
		
	EndIf;
	
	Return Catalogs.WorldCountries.EmptyRef();

EndFunction

&AtServer
Function PrepareAddressForInput(Data)
	
	LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	FillPropertyValues(LocalityDetailed, Data);
	
	For Each AddressItem In LocalityDetailed Do
		
		If StrEndsWith(AddressItem.Key, "ID")
			And TypeOf(AddressItem.Value) = Type("String")
			And StrLen(AddressItem.Value) = 36 Then
				LocalityDetailed[AddressItem.Key] = New UUID(AddressItem.Value);
		EndIf;
		
	EndDo;
	
	Return LocalityDetailed;
	
EndFunction

// Returns:
//   See ContactsManagerInternal.ContactInformationKindStructure
//
&AtClientAtServerNoContext
Function ContactInformationKindDetails(Form)
	Return Form.ContactInformationKind;
EndFunction

&AtClientAtServerNoContext
Function TheBeginningOfTheAccounting()
	
	Return NStr("en = 'accounting start date';");
	
EndFunction

#EndRegion