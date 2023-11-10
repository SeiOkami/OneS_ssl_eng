///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#If Not MobileStandaloneServer Then

#Region Variables

Var IBUserProcessingParameters; // 
                                        // 

Var IsNew; // 
                // 

#EndRegion

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

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
	SetPrivilegedMode(True);
	InformationRegisters.UsersInfo.UpdateUserInfoRecords(
		UsersInternal.ObjectRef2(ThisObject), ThisObject);
	SetPrivilegedMode(False);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		And ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		Block = New DataLock;
		Block.Add("Catalog.UserGroups");
		Block.Lock();
		
		GroupObject1 = AdditionalProperties.NewUserGroup.GetObject(); // CatalogObject.UserGroups
		GroupObject1.Content.Add().User = Ref;
		GroupObject1.Write();
	EndIf;
	
	// Updating the content of "All users" auto group.
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	UsersInternal.UpdateUserGroupComposition(
		Catalogs.UserGroups.AllUsers, Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.UpdateUserGroupCompositionUsage(
		Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.EndIBUserProcessing(
		ThisObject, IBUserProcessingParameters);
	
	UsersInternal.AfterUserGroupsUpdate(
		ItemsToChange, ModifiedGroups);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	ContactInformation.Clear();
	Comment = "";
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange() Export
	
	// 
	// 
	
	IBUserDetails = New Structure;
	IBUserDetails.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters, True);
	UsersInternal.EndIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

#EndRegion

#EndIf

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf