///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Redefines the standard behavior of the Users subsystem.
//
// Parameters:
//  Settings - Structure:
//   * CommonAuthorizationSettings - Boolean - Indicates whether the "Users and rights settings" administration panel has authorization settings,
//          and whether expiration settings will be available in user and external user forms.
//          By default, True. For basic configuration versions, False.
//          In SaaS, the value is got from the service manager settings, and it cannot be overridden.
//          
//
//   * EditRoles - Boolean - shows whether the role editing interface is available 
//          in profiles of users, external users, and groups of external users.
//          This affects both regular users and administrators. Default value is True.
//
//   * IndividualUsed - Boolean -
//          
//
//   * IsDepartmentUsed  - Boolean -
//          
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Allows you to specify roles, the purpose of which will be controlled in a special way.
// The majority of configuration roles here are not required as they are intended for any users  
// except for external ones.
//
// Parameters:
//  RolesAssignment - Structure:
//   * ForSystemAdministratorsOnly - Array - role names that, when separation is disabled,
//     are intended for any users other than external users, and in separated mode,
//     are intended only for service administrators, for example:
//       Administration, UpdateDatabaseConfiguration, SystemAdministrator,
//     and also all roles with the rights:
//       Administration,
//       Administration of configuration extensions,
//       Update database configuration.
//     Such roles are usually available in SSL and not available in applications.
//
//   * ForSystemUsersOnly - Array - role names that, when separation is disabled,
//     are intended for any users other than external users, and in separated mode,
//     are intended only for non-separated users (technical support stuff
//     and service administrators), for example:
//       AddEditAddressInfo, AddEditBanks,
//     and all roles with rights to change non-separated data and those that have the following rules:
//       Thick client,
//       External connection,
//       Automation,
//       Mode "All functions",
//       Interactive open external data processors,
//       Interactive open external reports.
//     Such roles are mainly available in SSL. However, they might be available in applications.
//
//   * ForExternalUsersOnly - Array - role names that are intended
//     only for external users (roles with a specially developed set of rights), for example:
//       AddEditQuestionnaireQuestionsAnswers, BasicSSLRightsForExternalUsers.
//     Such roles are available both both in SSL and applications (if external users are used).
//
//   * BothForUsersAndExternalUsers - Array - role names that are intended
//     for any users (internal, external, and non-separated), for example:
//       ReadQuestionnaireQuestionsAnswers, AddEditPersonalReportsOptions.
//     Such roles are available both both in SSL and applications (if external users are used).
//
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	
	
EndProcedure

// Overrides the behavior of the user form, the external user form,
// and a group of external users, when it should be different from the default behavior.
//
// For example, you need to hide, show, or allow to change or lock
// some properties in cases that are defined by the applied logic.
//
// Parameters:
//  UserOrGroup - CatalogRef.Users
//                        - CatalogRef.ExternalUsers
//                        - CatalogRef.ExternalUsersGroups - 
//                          
//
//  ActionsOnForm - Structure:
//         * Roles                   - String - "", "View," "Edit."
//                                             For example, when roles are edited in another form, you can hide them
//                                             in this form or just lock editing.
//         * ContactInformation   - String - "", "View," "Edit."
//                                             This property is not available for external user groups.
//                                             For example, you may need to hide contact information
//                                             from the user with no application rights to view CI.
//         * IBUserProperies - String - "", "View," "Edit."
//                                             This property is not available for external user groups.
//                                             For example, you may need to show infobase user properties
//                                             for a user who has application rights to this information.
//         * ItemProperties       - String - "", "View," "Edit."
//                                             For example, Description is the full name of the infobase user.
//                                             It might require editing the description
//                                             for a user who has application rights for employee operations.
//
Procedure ChangeActionsOnForm(Val UserOrGroup, Val ActionsOnForm) Export
	
EndProcedure

// Additionally defines actions upon infobase user writing.
// For example, if a record in the matching register must be synchronously updated and so on.
// The method is called from the Users.SetIBUserProperies procedure if the user was changed.
// If the Name field in the PreviousProperties structure is not filled in, a new infobase user is created.
//
// Parameters:
//  PreviousProperties - See Users.NewIBUserDetails.
//  NewProperties  - See Users.NewIBUserDetails.
//
Procedure OnWriteInfobaseUser(Val PreviousProperties, Val NewProperties) Export
	
EndProcedure

// Redefines actions that are required after deleting an infobase user.
// For example, if you need to synchronously update record in the matching register and so on.
// The procedure is called from the DeleteInfobaseUser() procedure if the user has been deleted.
//
// Parameters:
//  PreviousProperties - See Users.NewIBUserDetails.
//
Procedure AfterDeleteInfobaseUser(Val PreviousProperties) Export
	
EndProcedure

// Overrides interface settings for new users.
// For example, you can set initial settings of command interface sections location.
//
// Parameters:
//  InitialSettings1 - Structure:
//   * ClientSettings    - ClientSettings           - client application settings.
//   * InterfaceSettings - CommandInterfaceSettings            - Command interface settings (for sections panel,
//                                                                      navigation panel, and actions panel).
//   * TaxiSettings      - ClientApplicationInterfaceSettings - client application interface settings
//                                                                      (panel content and positions).
//
//   * IsExternalUser - Boolean - If True, then this is an external user.
//
Procedure OnSetInitialSettings(InitialSettings1) Export
	
	
	
EndProcedure

// Allows you to add an arbitrary setting on the Others tab to the UsersSettings
// handler interface so that other users can delete or copy it.
// To be able to manage the setting, write a code for its copying (See OnSaveOtherSetings)
// and deleting (See OnDeleteOtherSettings)
//
// that will be called upon performing interactive actions involving the setting.
// For example, a flag that indicates whether to show a warning when closing the application.
//
// Parameters:
//  UserInfo - Structure - string and referential user presentation:
//       * UserRef  - CatalogRef.Users - a user,
//                               from which you need to receive settings.
//       * InfobaseUserName - String - an infobase user,
//                                             from which you need to receive settings.
//  Settings - Structure - other user settings:
//       * Key     - String - string ID of a setting that is used
//                             for copying and clearing the setting.
//       * Value - Structure:
//              ** SettingName1  - String - name to be displayed in the setting tree.
//              ** PictureSettings  - Picture -  picture to be displayed in the tree of settings.
//              ** SettingsList     - ValueList - a list of received settings.
//
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	
	
EndProcedure

// Saves arbitrary settings of the specified user.
// Also see OnGetOtherSettings.
//
// Parameters:
//  Settings - Structure:
//       * SettingID - String - a string of a setting to be copied.
//       * SettingValue      - ValueList - a list of values of settings being copied.
//  UserInfo - Structure - string and referential user presentation:
//       * UserRef - CatalogRef.Users - a user
//                              who needs to copy a setting.
//       * InfobaseUserName - String - an infobase user
//                                             who needs to copy a setting.
//
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	
	
EndProcedure

// Clears an arbitrary setting of a passed user.
// Also see OnGetOtherSettings.
//
// Parameters:
//  Settings - Structure:
//       * SettingID - String - a string of a setting to be cleared.
//       * SettingValue      - ValueList - a list of values of settings being cleared.
//  UserInfo - Structure - string and referential user presentation:
//       * UserRef - CatalogRef.Users - a user
//                              who needs to clear a setting.
//       * InfobaseUserName - String - an infobase
//                                             user.
//
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	
	
EndProcedure

// Allows you to specify a custom user choice form.
//
// When developing the form:
// - set the Internal filter to False, the filter must be cleared only for a user with full rights;
// - set the Invalid filter to False, the filter must be cleared for any user.
//
// When implementing the custom form, you must support form parameters or use a standard form:
// - CloseOnChoice
// - MultipleChoice
// - SelectConversationParticipants
//
// To use a form for selecting conversation participants:
// - pass the selection result to the notification about closing
// - present the selection result as an array of
//   Collaboration system user IDs.
//
// Parameters:
//   SelectedForm - String - name of form to open.
//   FormParameters - Structure - form parameters when opening, Read only:
//   * CloseOnChoice - Boolean - indicates that a form
// 									must be closed after selecting an option.
// 									If the property is set to False, you can 
// 									select several positions or items in the form.
//   * MultipleChoice - Boolean - allows or forbids you to select several rows from the list.
//   * SelectConversationParticipants - Boolean - If True, the form is called as a form to select conversation participants.
// 										   The form must return an array of
// 										   Collaboration system user IDs.
//
//   * PickingCompletionButtonTitle - String - the title of the selection completion button.
//   * HideUsersWithoutMatchingIBUsers - Boolean - If True, users without
// 													  infobase user ID must not be displayed in the list.
//   * UsersGroupsSelection - Boolean - allows you to select user groups.
// 										 If user groups are used and the parameter is not supported,
// 										 you cannot assign rights to a user group via the choice form.
//   * AdvancedPick - Boolean - If True, viewing user groups is available.
//   * ExtendedPickFormParameters - String - temporary storage address with the structure:
//   ** UsersToHide - Array - users that are not displayed in the pick form.
//   ** SelectExternalUsersGroups - Boolean - allows you to select external user groups.
//   ** CannotPickGroups - Boolean
//   ** PickFormHeader - String - allows you to override the pick form header.
//   ** SelectedUsers - Array - users that must be displayed in the list of selected users.
//   ** CurrentRow - CatalogRef.UserGroups - a row that will be used for positioning 
// 															 of user groups
// 															 in the dynamic list when opening the form.
//
Procedure OnDefineUsersSelectionForm(SelectedForm, FormParameters) Export

EndProcedure

#EndRegion
