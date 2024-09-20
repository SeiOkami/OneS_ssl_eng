///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.ObjectDetails = Undefined Then
		Return;
	EndIf;
	
	ObjectReference = Parameters.ObjectDetails.Ref;
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Items.LabelsContextMenuCreate.Visible = False;
		Items.LabelsContextMenuChange.Visible = False;
	EndIf;
	
	If Not AccessRight("Update", Metadata.FindByType(TypeOf(ObjectReference))) Then
		Items.LabelsValue.Enabled = False;
		Items.LabelsContextMenuSetAll.Visible = False;
		Items.LabelsContextMenuClearAllIetmsCommand.Visible = False;
	EndIf;
	
	// 
	PropertiesSets = PropertyManagerInternal.GetObjectPropertySets(ObjectReference);
	For Each String In PropertiesSets Do
		AvailablePropertySets.Add(String.Set);
	EndDo;
	
	ObjectLabels.LoadValues(PropertyManager.PropertiesByAdditionalAttributesKind(
		Parameters.ObjectDetails.AdditionalAttributes.Unload(),
		Enums.PropertiesKinds.Labels));
	
	// 
	FillLabels();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// 
	If EventName = "Write_AdditionalAttributesAndInfo" Then
		FillLabels();
	EndIf;
	
EndProcedure

#EndRegion

#Region PropertyValueTableFormTableItemEventHandlers

&AtClient
Procedure LabelsOnChange(Item)
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CompleteEditing(Command)
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Owner", FormOwner);
	NotificationParameters.Insert("LabelsApplied", LabelsApplied(Labels));
	Notify("Write_LabelsChange", NotificationParameters);
	
	Close();
	
EndProcedure

&AtClient
Procedure MarkEditing(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure Create(Command)
	
	CurrentData = Items.Labels.CurrentData;
	If CurrentData = Undefined Then
		If AvailablePropertySets.Count() = 0 Then
			Return;
		EndIf;
		PropertiesSet = AvailablePropertySets[0].Value;
	Else
		PropertiesSet = CurrentData.Set;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertiesSet", PropertiesSet);
	FormParameters.Insert("PropertyKind", PredefinedValue("Enum.PropertiesKinds.Labels"));
	FormParameters.Insert("CurrentPropertiesSet", PropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	CurrentData = Items.Labels.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Property);
	FormParameters.Insert("CurrentPropertiesSet", CurrentData.Set);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetAll(Command)
	
	SetClearAll(Labels, True);
	
EndProcedure

&AtClient
Procedure ClearAllIetmsCommand(Command)
	
	SetClearAll(Labels, False);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillLabels()
	
	Labels.Clear();
	LabelsValues = PropertyManagerInternal.PropertiesValues(
		ObjectReference.AdditionalAttributes,
		AvailablePropertySets,
		Enums.PropertiesKinds.Labels);
		
	For Each Label In LabelsValues Do
		If Label.Deleted Then
			Continue;
		EndIf;
		NewRow = Labels.Add();
		FillPropertyValues(NewRow, Label);
		ObjectLabel = ObjectLabels.FindByValue(Label.Property);
		If ObjectLabel = Undefined Then
			NewRow.Value = False;
		Else
			NewRow.Value = True;
		EndIf;
		NewRow.Description = Label.Description;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function LabelsApplied(Labels)
	
	LabelsApplied = New Array;
	For Each Label In Labels Do
		If Label.Value Then
			LabelsApplied.Add(Label.Property);
		EndIf;
	EndDo;
	
	Return LabelsApplied;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetClearAll(Labels, Set)
	
	For Each Label In Labels Do
		Label.Value = Set;
	EndDo;
	
EndProcedure

#EndRegion