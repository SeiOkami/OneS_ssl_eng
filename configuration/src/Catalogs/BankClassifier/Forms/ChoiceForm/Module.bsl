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
	
	SetConditionalAppearance();
	
	DataProcessorName = "ImportBankClassifier";
	HasDataImportSource = Metadata.DataProcessors.Find(DataProcessorName) <> Undefined;
	
	CanUpdateClassifier = False;
	DataProcessorName = "ImportBankClassifier";
	If Metadata.DataProcessors.Find(DataProcessorName) <> Undefined Then
		CanUpdateClassifier = DataProcessors[DataProcessorName].ClassifierDownloadAvailable();
	EndIf;
	
	CanUpdateClassifier = CanUpdateClassifier
		And Not Common.IsSubordinateDIBNode()   // The distributed infobase node is updated automatically.
		And AccessRight("Update", Metadata.Catalogs.BankClassifier); // 
	
	Items.FormImportClassifier.Visible = CanUpdateClassifier And HasDataImportSource;
	
	If Common.DataSeparationEnabled() Or Common.IsSubordinateDIBNode() Then
		ReadOnly = True;
	EndIf;
	
	PromptToImportClassifier = CanUpdateClassifier And HasDataImportSource 
		And BankManagerInternal.PromptToImportClassifier();
	
	SwitchInactiveBanksVisibility(False);
	
	If ValueIsFilled(Parameters.BIC) Then
		Items.List.Representation = TableRepresentation.HierarchicalList;
		BICInformation = BankManager.BICInformation(Parameters.BIC).UnloadColumn("Ref");
		If BICInformation.Count() = 1 Then
			SelectedBIC = BICInformation[0];
		ElsIf BICInformation.Count() > 1 Then
			Items.List.Representation = TableRepresentation.List;
			CommonClientServer.SetDynamicListFilterItem(List, "Code", Parameters.BIC,,,True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(SelectedBIC) Then
		Close(SelectedBIC);
		Return;
	EndIf;
	
	If PromptToImportClassifier Then
		AttachIdleHandler("SuggestToImportClassifier", 1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportClassifier(Command)
	BankManagerClient.OpenClassifierImportForm();
EndProcedure

&AtClient
Procedure ShowInactiveBanks(Command)
	SwitchInactiveBanksVisibility(Not Items.FormShowInactiveBanks.Check);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SwitchInactiveBanksVisibility(Visible)
	
	Items.FormShowInactiveBanks.Check = Visible;
	
	CommonClientServer.SetDynamicListFilterItem(
			List, "OutOfBusiness", False, , , Not Visible);
			
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OutOfBusiness");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure SuggestToImportClassifier()
	
	BankManagerClient.SuggestToImportClassifier();
	
EndProcedure

#EndRegion
