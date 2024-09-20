///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousValue2;

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	PreviousValue2 = Constants.DeliverServerNotificationsWithoutCollaborationSystem.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PreviousValue2 <> Value Then
		ServerNotifications.OnChangeConstantDeliverServerNotificationsWithoutCollaborationSystem(Value);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf