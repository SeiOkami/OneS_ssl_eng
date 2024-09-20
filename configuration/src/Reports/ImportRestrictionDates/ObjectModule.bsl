///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.GenerateImmediately = True;
	
	If Form <> Undefined Then
		SetPredefinedByImplementationOption(Form, VariantKey);
	EndIf;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	Settings = SettingsComposer.GetSettings();
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("DataSet", ClosingDatesPrepared(Settings.DataParameters));
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Procedure SetPredefinedByImplementationOption(Form, VariantKey)
	
	If Form.Parameters.VariantKey <> Undefined Then
		Return; // Report option is specified upon opening.
	EndIf;
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections And Not Properties.AllSectionsWithoutObjects Then
		
		If VariantKey <> "ImportRestrictionDatesByInfobases"
		   And VariantKey <> "ImportRestrictionDatesBySectionsObjectsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobases";
		EndIf;
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		
		If VariantKey <> "ImportRestrictionDatesByInfobasesWithoutObjects"
		   And VariantKey <> "ImportRestrictionDatesBySectionsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobasesWithoutObjects";
		EndIf;
	Else
		If VariantKey <> "ImportRestrictionDatesByInfobasesWithoutSections"
		   And VariantKey <> "ImportRestrictionDatesByObjectsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobasesWithoutSections";
		EndIf;
	EndIf;
	
EndProcedure

Function ClosingDatesPrepared(DataParameters)
	
	Query = New Query;
	Query.Text = QueryText();
	Query.SetParameter("SpecifiedRecipients",     UserParameterValue(DataParameters, "SMSMessageRecipients"));
	Query.SetParameter("SpecifiedSections",      UserParameterValue(DataParameters, "Sections"));
	Query.SetParameter("SpecifiedObjects",      UserParameterValue(DataParameters, "Objects"));
	Query.SetParameter("PeriodClosingDates", PeriodClosingDatesInternal.CalculatedPeriodClosingDates());
	Query.SetParameter("ExchangePlansEmptyRefs", ExchangePlansEmptyRefs());
	
	Table = Query.Execute().Unload();
	Table.Columns.Add("ObjectPresentation",            New TypeDescription("String"));
	Table.Columns.Add("SectionPresentation",            New TypeDescription("String"));
	Table.Columns.Add("SettingsRecipientPresentation",  New TypeDescription("String"));
	Table.Columns.Add("SettingsOwnerPresentation", New TypeDescription("String"));
	Table.Columns.Add("CommonDateSetting",             New TypeDescription("Boolean"));
	Table.Columns.Add("SettingForSection",            New TypeDescription("Boolean"));
	Table.Columns.Add("SettingForAllRecipients",      New TypeDescription("Boolean"));
	
	For Each String In Table Do
		
		If String.Object <> String.Section Then
			String.ObjectPresentation = String(String.Object);
			
		ElsIf ValueIsFilled(String.Section) Then
			String.ObjectPresentation = NStr("en = 'For all objects except for the specified ones';");
		Else
			String.ObjectPresentation = NStr("en = 'For all sections and objects except for the specified ones';");
		EndIf;
		
		If ValueIsFilled(String.Section) Then
			String.SectionPresentation = String(String.Section);
		Else
			String.SectionPresentation = "<" + NStr("en = 'Common date';") + ">";
		EndIf;
		
		If String.SettingsRecipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			String.SettingsRecipientPresentation = NStr("en = 'For all infobases except for the specified ones';");
		Else
			String.SettingsRecipientPresentation = String(TypeOf(String.SettingsRecipient)) + ":"
				+ ?(ValueIsFilled(String.SettingsRecipient),
					String(String.SettingsRecipient),
					NStr("en = 'All infobases';"));
		EndIf;
		
		If String.SettingsOwner = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			String.SettingsOwnerPresentation = NStr("en = 'For all infobases except for the specified ones';");
		Else
			String.SettingsOwnerPresentation = String(TypeOf(String.SettingsOwner)) + ":"
				+ ?(ValueIsFilled(String.SettingsOwner),
					String(String.SettingsOwner),
					NStr("en = 'All infobases';"));
		EndIf;
		
		String.CommonDateSetting  = Not ValueIsFilled(String.Section);
		String.SettingForSection = String.Object = String.Section;
		String.SettingForAllRecipients =
			String.SettingsRecipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
	EndDo;
	
	Return Table;
	
EndFunction

Function ExchangePlansEmptyRefs()
	
	BlankRefs = New ValueTable;
	BlankRefs.Columns.Add("EmptyRef", Metadata.DefinedTypes.PeriodClosingTarget.Type);
	AddresseeTypes = Metadata.DefinedTypes.PeriodClosingTarget.Type.Types();
	For Each Type In AddresseeTypes Do
		MetadataObject = Metadata.FindByType(Type);
		If TypeOf(MetadataObject) <> Type("MetadataObject")
		 Or Not Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		Types = CommonClientServer.ValueInArray(Type);
		TypeDescription = New TypeDescription(Types);
		EmptyRef = TypeDescription.AdjustValue(Undefined);
		BlankRefs.Add().EmptyRef = EmptyRef;
	EndDo;
	
	Return BlankRefs;
	
EndFunction

Function UserParameterValue(DataParameters, ParameterName)
	
	Parameter = DataParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	
	If Not Parameter.Use Then
		Return False;
	EndIf;
	
	If TypeOf(Parameter.Value) = Type("ValueList") Then
		Return Parameter.Value.UnloadValues();
	EndIf;
	
	Array = New Array;
	Array.Add(Parameter.Value);
	
	Return Array;
	
EndFunction

Function QueryText()
	
	// ACC:494-
	// 
	// 
	// 
	Return
	"SELECT
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.Comment AS Comment
	|INTO PeriodClosingDates
	|FROM
	|	&PeriodClosingDates AS PeriodClosingDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlansEmptyRefs.EmptyRef AS EmptyRef
	|INTO ExchangePlansEmptyRefs
	|FROM
	|	&ExchangePlansEmptyRefs AS ExchangePlansEmptyRefs
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ConfiguredUsersWithGroups.User AS User,
	|	PeriodClosingDates.User AS SettingsOwner,
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PriorityCodes.Value AS Priority,
	|	PriorityCodes.Owner AS OwnerPriority
	|INTO ClosingDateWithAllOwners
	|FROM
	|	PeriodClosingDates AS PeriodClosingDates
	|		INNER JOIN (SELECT
	|			0 AS Code,
	|			1 AS Value,
	|			""0"" AS Owner
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			10,
	|			2,
	|			""0""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			11,
	|			3,
	|			""0""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			100,
	|			4,
	|			""1""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			110,
	|			5,
	|			""1""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			111,
	|			6,
	|			""1""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1000,
	|			7,
	|			""2""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1010,
	|			8,
	|			""2""
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1011,
	|			9,
	|			""2"") AS PriorityCodes
	|		ON (CASE
	|				WHEN PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases)
	|					THEN 0
	|				WHEN PeriodClosingDates.User IN
	|						(SELECT
	|							ExchangePlansEmptyRefs.EmptyRef
	|						FROM
	|							ExchangePlansEmptyRefs AS ExchangePlansEmptyRefs)
	|					THEN 100
	|				ELSE 1000
	|			END + CASE
	|				WHEN PeriodClosingDates.Object = PeriodClosingDates.Section
	|					THEN 0
	|				ELSE 1
	|			END + CASE
	|				WHEN PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
	|					THEN 0
	|				ELSE 10
	|			END = PriorityCodes.Code)
	|		INNER JOIN (SELECT
	|			PeriodClosingDates.User AS User,
	|			ExchangePlansEmptyRefs.EmptyRef AS UsersGroup
	|		FROM
	|			PeriodClosingDates AS PeriodClosingDates
	|				INNER JOIN ExchangePlansEmptyRefs AS ExchangePlansEmptyRefs
	|				ON (VALUETYPE(PeriodClosingDates.User) = VALUETYPE(ExchangePlansEmptyRefs.EmptyRef))
	|					AND (FALSE IN (&SpecifiedRecipients)
	|						OR PeriodClosingDates.User IN (&SpecifiedRecipients))
	|		
	|		UNION
	|		
	|		SELECT
	|			VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases),
	|			VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases)
	|		WHERE
	|			(FALSE IN (&SpecifiedRecipients)
	|					OR TRUE IN (&SpecifiedRecipients))) AS ConfiguredUsersWithGroups
	|		ON (PeriodClosingDates.User IN (VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases), ConfiguredUsersWithGroups.UsersGroup, ConfiguredUsersWithGroups.User))
	|			AND (PeriodClosingDates.Object <> UNDEFINED)
	|			AND (NOT(PeriodClosingDates.Object <> PeriodClosingDates.Section
	|					AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ClosingDateWithAllOwners.User AS User,
	|	ClosingDateWithAllOwners.SettingsOwner AS SettingsOwner,
	|	ClosingDateWithAllOwners.Section AS Section,
	|	ClosingDateWithAllOwners.Object AS Object,
	|	ClosingDateWithAllOwners.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	ClosingDateWithAllOwners.Priority AS Priority
	|INTO ClosingDates
	|FROM
	|	ClosingDateWithAllOwners AS ClosingDateWithAllOwners
	|		INNER JOIN (SELECT
	|			OwnersPriorities.User AS User,
	|			MAX(OwnersPriorities.OwnerPriority) AS OwnerPriority
	|		FROM
	|			ClosingDateWithAllOwners AS OwnersPriorities
	|		
	|		GROUP BY
	|			OwnersPriorities.User) AS PrioritizedOwners
	|		ON ClosingDateWithAllOwners.User = PrioritizedOwners.User
	|			AND ClosingDateWithAllOwners.OwnerPriority = PrioritizedOwners.OwnerPriority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ClosingDates.User AS SettingsRecipient,
	|	ClosingDates.SettingsOwner AS SettingsOwner,
	|	ClosingDates.Section AS Section,
	|	ClosingDates.Object AS Object,
	|	PriorityDatesWithExclusionReasons.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	ClosingDates.PeriodEndClosingDate AS PeriodEndClosingDateSettings,
	|	ClosingDates.Priority AS SettingsPriority,
	|	PeriodClosingDates.Comment AS SettingComment,
	|	PriorityDatesWithExclusionReasons.Comment AS Comment
	|FROM
	|	ClosingDates AS ClosingDates
	|		INNER JOIN (SELECT
	|			PriorityDates.User AS User,
	|			PriorityDates.Section AS Section,
	|			PriorityDates.Object AS Object,
	|			PriorityDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|			MAX(PeriodClosingDates.Comment) AS Comment
	|		FROM
	|			(SELECT
	|				ClosingDates.User AS User,
	|				ClosingDates.Section AS Section,
	|				ClosingDates.Object AS Object,
	|				MAX(ClosingDates.PeriodEndClosingDate) AS PeriodEndClosingDate,
	|				MAX(ClosingDates.Priority) AS Priority
	|			FROM
	|				ClosingDates AS ClosingDates
	|					INNER JOIN (SELECT
	|						ClosingDates.User AS User,
	|						ClosingDates.Section AS Section,
	|						ClosingDates.Object AS Object,
	|						MAX(ClosingDates.Priority) AS Priority
	|					FROM
	|						ClosingDates AS ClosingDates
	|					
	|					GROUP BY
	|						ClosingDates.User,
	|						ClosingDates.Section,
	|						ClosingDates.Object) AS MaximumPriority
	|					ON ClosingDates.User = MaximumPriority.User
	|						AND ClosingDates.Section = MaximumPriority.Section
	|						AND ClosingDates.Object = MaximumPriority.Object
	|						AND ClosingDates.Priority = MaximumPriority.Priority
	|			
	|			GROUP BY
	|				ClosingDates.User,
	|				ClosingDates.Section,
	|				ClosingDates.Object) AS PriorityDates
	|				INNER JOIN ClosingDates AS ClosingDates
	|				ON (ClosingDates.User = PriorityDates.User)
	|					AND (ClosingDates.Section = PriorityDates.Section)
	|					AND (ClosingDates.Object = PriorityDates.Object)
	|					AND (ClosingDates.Priority = PriorityDates.Priority)
	|					AND (ClosingDates.PeriodEndClosingDate = PriorityDates.PeriodEndClosingDate)
	|				INNER JOIN PeriodClosingDates AS PeriodClosingDates
	|				ON (ClosingDates.SettingsOwner = PeriodClosingDates.User)
	|					AND (ClosingDates.Section = PeriodClosingDates.Section)
	|					AND (ClosingDates.Object = PeriodClosingDates.Object)
	|					AND (ClosingDates.PeriodEndClosingDate = PeriodClosingDates.PeriodEndClosingDate)
	|		
	|		GROUP BY
	|			PriorityDates.User,
	|			PriorityDates.Section,
	|			PriorityDates.Object,
	|			PriorityDates.Priority,
	|			PriorityDates.PeriodEndClosingDate) AS PriorityDatesWithExclusionReasons
	|		ON ClosingDates.User = PriorityDatesWithExclusionReasons.User
	|			AND ClosingDates.Section = PriorityDatesWithExclusionReasons.Section
	|			AND ClosingDates.Object = PriorityDatesWithExclusionReasons.Object
	|		INNER JOIN PeriodClosingDates AS PeriodClosingDates
	|		ON ClosingDates.SettingsOwner = PeriodClosingDates.User
	|			AND ClosingDates.Section = PeriodClosingDates.Section
	|			AND ClosingDates.Object = PeriodClosingDates.Object
	|WHERE
	|	(FALSE IN (&SpecifiedSections)
	|			OR ClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
	|			OR ClosingDates.Section IN (&SpecifiedSections))
	|	AND (FALSE IN (&SpecifiedObjects)
	|			OR ClosingDates.Object = ClosingDates.Section
	|			OR ClosingDates.Object IN (&SpecifiedObjects))";
	// 
	// 
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf