///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// 
// 
// 
// 
// 
//
// Parameters:
//  Settings - Structure:
//    * ShouldShowIcons - Boolean
//    * DetailsOfCommands - See ContactsManager.DetailsOfCommands
//    * PositionOfAddButton - ItemHorizontalLocation -
//                                                                  
//                                                                  
//                                                                  
//                                                                         
//                                                                         
//                                                                         
//                                                                         
//    * CommentFieldWidth - Number -
//                                      
//                                      
//
//  Пример:
//     Настройки.ОтображатьИконки = Истина;
//     Настройки.ШиринаПоляКомментарий = 10;
//     Настройки.ПоложениеКнопкиДобавить = ГоризонтальноеПоложениеЭлемента.Авто;
//
//     Адрес = Перечисления.ТипыКонтактнойИнформации.Адрес;
//     Настройки.ОписаниеКоманд[Адрес].ЗапланироватьВстречу.Заголовок  = НСтр("ru='Встреча'");
//     Настройки.ОписаниеКоманд[Адрес].ЗапланироватьВстречу.Подсказка  = НСтр("ru='Создать событие встречи'");
//     Настройки.ОписаниеКоманд[Адрес].ЗапланироватьВстречу.Картинка   = БиблиотекаКартинок.ЗапланированноеВзаимодействие;
//     Настройки.ОписаниеКоманд[Адрес].ЗапланироватьВстречу.Действие   = "_ДемоStandardSubsystemsКлиент.ОткрытьФормуДокументаВстреча";
//    
//     _ДемоФактическийАдресОрганизации = УправлениеКонтактнойИнформацией.ВидКонтактнойИнформацииПоИмени("_ДемоФактическийАдресОрганизации");
//      Настройки.ОписаниеКоманд[_ДемоФактическийАдресОрганизации] = 
//    	ОбщегоНазначения.СкопироватьРекурсивно(УправлениеКонтактнойИнформацией.КомандыТипаКонтактнойИнформации(Перечисления.ТипыКонтактнойИнформации.Адрес));
//      Настройки.ОписаниеКоманд[_ДемоФактическийАдресОрганизации].ЗапланироватьВстречу.Действие = ""; // Отключение действия команды для вида
//
//   Процедурам, указанных в свойстве Действие, передаются 2 параметра:
//       КонтактнаяИнформация - Структура:
//         * Представление - Строка
//         * Значение      - Строка
//         * Тип           - ПеречислениеСсылка.ТипыКонтактнойИнформации
//         * Вид           - СправочникСсылка.ВидыКонтактнойИнформации
//       ДополнительныеПараметры - Структура:        
//         * ВладелецКонтактнойИнформации - ОпределяемыйТип.ВладелецКонтактнойИнформации.
//         * Форма - ФормаКлиентскогоПриложения - форма объекта-владельца, предназначенная для вывода контактной информации.
//
//   Example: 
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
Procedure OnDefineSettings(Settings) Export

	
    
EndProcedure

// Gets descriptions of contact information kinds in different languages.
//
// Parameters:
//  Descriptions - Map of KeyAndValue - a presentation of a contact information kind in the passed language:
//     * Key     - String - a name of a contact information kind. For example, _DemoPartnerAddress.
//     * Value - String - a description of a contact information kind for the passed language code.
//  LanguageCode - String - a language code. For example, "en".
//
// Example:
//  Descriptions["_DemoPartnerAddress"] = NStr("ru='Адрес'; en='Address';", LanguageCode);
//
Procedure OnGetContactInformationKindsDescriptions(Descriptions, LanguageCode) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemFilling
//
// Parameters:
//  LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//  Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//  TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.
//
// Parameters:
//  Object                  - CatalogObject.PerformerRoles - Object to populate.
//  Data                  - ValueTableRow - Object fill data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - Data filled in the OnInitialItemsFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
EndProcedure

#EndRegion
