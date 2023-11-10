///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#If Not MobileStandaloneServer Then

// 
//
// Parameters:
//  ReportResult - SpreadsheetDocument -
//  ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure SaveUserReportSnapshot(ReportResult, ReportSettings) Export

	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ReportsSnapshots.CreateRecordManager();
	
	RecordManager.User = Users.CurrentUser();
	RecordManager.Report = ReportSettings.ReportRef;
	RecordManager.Variant = ReportSettings.OptionRef;
	
	RecordManager.UserSettingsHash = Common.CheckSumString(
		ReportSettings.ResultProperties.SettingsComposer.UserSettings);
	RecordManager.UserSetting = New ValueStorage(ReportSettings.ResultProperties.SettingsComposer.UserSettings);

	RecordManager.ReportResult = New ValueStorage(ReportResult);
	RecordManager.UpdateDate = CurrentSessionDate();
	RecordManager.LastViewedDate = CurrentSessionDate();
	
	RecordManager.Write();

EndProcedure

// 
//
// Parameters:
//  FillParameters - Structure:
//   * User - CatalogRef.Users -
//   * ReportsSnapshots - ValueTable:
//    ** User - CatalogRef.Users
//    ** Report - CatalogRef.MetadataObjectIDs
//    ** Variant - CatalogRef.ReportsOptions
//    ** UserSettingsHash - Number
//   * CatalogNameReportOptions - String -
//  StorageAddress - String -
//
Procedure UpdateUserReportsSnapshots(FillParameters, StorageAddress) Export

	SetPrivilegedMode(True);
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		MeasurementDetails = ModulePerformanceMonitor.StartTimeConsumingOperationMeasurement(
			"UpdateUserReportsSnapshots");
	EndIf;
	
	CatalogNameReportOptions = "";
	FillParameters.Property("CatalogNameReportOptions", CatalogNameReportOptions);
	
	Query = New Query;
	Query.SetParameter("User", FillParameters.User);
	If FillParameters.Property("ReportsSnapshots") Then
		Query.SetParameter("ReportsSnapshots", FillParameters.ReportsSnapshots);
		Query.Text = 
		"SELECT
		|	ReportsSnapshots.User AS User,
		|	ReportsSnapshots.Report AS Report,
		|	ReportsSnapshots.Variant AS Variant,
		|	ReportsSnapshots.UserSettingsHash AS UserSettingsHash
		|INTO SavedReportsSnapshots
		|FROM
		|	&ReportsSnapshots AS ReportsSnapshots
		|
		|INDEX BY
		|	User,
		|	Report,
		|	Variant,
		|	UserSettingsHash
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReportsSnapshots.User AS User,
		|	ReportsSnapshots.Report AS Report,
		|	ReportsSnapshots.Variant AS Variant,
		|	ReportsSnapshots.Variant.VariantKey AS VariantKey,
		|	ReportsSnapshots.UserSettingsHash AS UserSettingsHash,
		|	ReportsSnapshots.UserSetting AS UserSetting
		|FROM
		|	InformationRegister.ReportsSnapshots AS ReportsSnapshots
		|		INNER JOIN SavedReportsSnapshots AS SavedReportsSnapshots
		|		ON ReportsSnapshots.User = SavedReportsSnapshots.User
		|			AND ReportsSnapshots.Report = SavedReportsSnapshots.Report
		|			AND ReportsSnapshots.Variant = SavedReportsSnapshots.Variant
		|			AND ReportsSnapshots.UserSettingsHash = SavedReportsSnapshots.UserSettingsHash
		|WHERE
		|	ReportsSnapshots.User = &User
		|	AND ReportsSnapshots.Variant REFS Catalog.ReportsOptions";
	Else	
		Query.Text = 
		"SELECT
		|	ReportsSnapshots.User AS User,
		|	ReportsSnapshots.Report AS Report,
		|	ReportsSnapshots.Variant AS Variant,
		|	ReportsSnapshots.Variant.VariantKey AS VariantKey,
		|	ReportsSnapshots.UserSettingsHash AS UserSettingsHash,
		|	ReportsSnapshots.UserSetting AS UserSetting
		|FROM
		|	InformationRegister.ReportsSnapshots AS ReportsSnapshots
		|WHERE
		|	ReportsSnapshots.User = &User
		|	AND ReportsSnapshots.Variant REFS Catalog.ReportsOptions";
	EndIf;
	If Not IsBlankString(CatalogNameReportOptions) Then
		Query.Text = StrReplace(Query.Text, "ReportsOptions", CatalogNameReportOptions);
	EndIf;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
	
		RecordManager = InformationRegisters.ReportsSnapshots.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection, "User, Report, Variant, UserSettingsHash");
	
		ReportGenerationParameters = ReportsOptions.ReportGenerationParameters();
	
		ReportGenerationParameters.OptionRef1 = Selection.Variant;
		ReportGenerationParameters.RefOfReport = Selection.Report;
		ReportGenerationParameters.VariantKey = Selection.VariantKey;
		ReportGenerationParameters.DCUserSettings = Selection.UserSetting.Get();
		If Not IsBlankString(CatalogNameReportOptions) Then
			VariantKey = Selection.Report.Name;
			ReportGenerationParameters.VariantKey = VariantKey;
			ReportGenerationParameters.OptionRef1 = ReportsOptions.ReportVariant(Selection.Report, VariantKey);
		EndIf;
		
		Generation1 = ReportsOptions.GenerateReport(ReportGenerationParameters, True, False);
		
		If Not Generation1.Success Then
			WriteLogEvent(NStr("en = 'Update report snapshots';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Common.MetadataObjectByID(Selection.Report),
			Selection.Variant,
			Generation1.ErrorText);
		EndIf;
		
		RecordManager.ReportResult = New ValueStorage(Generation1.SpreadsheetDocument, New Deflation);
		RecordManager.UserSetting = Selection.UserSetting;
		RecordManager.UpdateDate = CurrentSessionDate();
		RecordManager.LastViewedDate = CurrentSessionDate();
		RecordManager.ReportUpdateError = Not Generation1.Success;
		RecordManager.Write();
	
	EndDo;
	
	If ModulePerformanceMonitor <> Undefined Then
		ModulePerformanceMonitor.EndTimeConsumingOperationMeasurement(MeasurementDetails, Selection.Count());
	EndIf;

EndProcedure

#EndIf

// 
//
// Parameters:
//  User - CatalogRef.Users -
//  CatalogNameReportOptions - String -
// Returns:
//  ValueTable:
//   * User - CatalogRef.Users -
//   * Report - CatalogRef.MetadataObjectIDs -
//   * Variant - DefinedType.OptionOfReportToUpdate -
//   * OptionDescription - String -
//   * UserSettingsHash - Number  -
//
Function UserReportsSnapshots(User, CatalogNameReportOptions) Export

	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.Text =
	"SELECT
	|	ReportsSnapshots.User AS User,
	|	ReportsSnapshots.Report AS Report,
	|	ReportsSnapshots.Variant AS Variant,
	|	ReportsSnapshots.Variant.Description AS OptionDescription,
	|	ReportsSnapshots.UserSettingsHash AS UserSettingsHash,
	|	ReportsSnapshots.UpdateDate AS UpdateDate
	|FROM
	|	InformationRegister.ReportsSnapshots AS ReportsSnapshots
	|WHERE
	|	ReportsSnapshots.User = &User
	|	AND ReportsSnapshots.Variant REFS Catalog.ReportsOptions
	|	AND NOT ReportsSnapshots.Variant.Description IS NULL
	|
	|ORDER BY
	|	Report,
	|	Variant,
	|	UserSettingsHash";
	If User = Undefined Then
		Query.Text = StrReplace(Query.Text, "ReportsSnapshots.User = &User", "TRUE");
	EndIf;
	If Not IsBlankString(CatalogNameReportOptions) Then
		Query.Text = StrReplace(Query.Text, "ReportsOptions", CatalogNameReportOptions);
	EndIf;

	Return Query.Execute().Unload();

EndFunction

#Region ForCallsFromOtherSubsystems

// 

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(User)";
	
EndProcedure

// 

#EndRegion

#EndRegion

#EndIf
