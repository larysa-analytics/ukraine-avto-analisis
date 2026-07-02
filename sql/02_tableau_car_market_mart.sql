/**
 * ДАТА-ВІТРИНА (DATA MART): Агрегована статистика ринку легкових автомобілів України
 * * ПРИЗНАЧЕННЯ: Оптимізація та підготовка даних для візуалізації в Tableau.
 * ТИП ОБРОБКИ: ELT/OLAP Агрегація.
 * СУБД: SQLite універсальний (ANSI SQL сумісний завдяки використанню CTE).
 *
 * ОПТИМІЗАЦІЯ: Замість прямого підключення BI до сирих логів (~6.7 млн рядків),
 * дані попередньо очищуються, категоризуються на рівні CTE та фізично матеріалізуються.
 * Це знижує навантаження на пам'ять при фільтрації.
 */

-- Очищення застарілої структури перед релізом вітрини
DROP TABLE IF EXISTS passenger_car_market_summary;

-- Матеріалізація фінальної вітрини даних
CREATE TABLE passenger_car_market_summary AS

-- ЕТАП 1: Розрахунковий шар (Data Cleansing & Transformation Layer)
-- Формуємо бізнес-метрики, виправляємо типи та нормалізуємо довідники без агрегації
WITH prepared_data AS (
    SELECT 
        -- Тимчасові виміри (Time Dimensions)
        v.report_year AS reg_year,
        CAST(STRFTIME('%m', v.D_REG) AS INTEGER) AS reg_month,
        
        -- Демографічні та географічні розрізи (Demographic & Geo Dimensions)
        v.PERSON AS person_type,               -- Юридична / фізична особа
        r.region_name AS region,               -- Декодована назва області з dict_regions
        
        -- Технічні характеристики ТЗ (Vehicle Attributes)
        v.BRAND AS brand,
        v.MODEL AS model,
        v.KIND AS vehicle_type,
        v.FUEL AS fuel_type,
        v.MAKE_YEAR,
        v.report_year,
        
        -- СЕГМЕНТАЦІЯ РИНКУ: Категоризація за кодами реєстраційних дій (OPER_CODE)
        CASE 
            -- Первинні реєстрації: нові авто з салонів та перше ввезення б/в з-за кордону
            WHEN v.OPER_CODE IN (11, 30, 70, 71, 72, 73, 74, 75, 76, 77, 99, 100, 102, 105, 130, 150, 180, 182, 184, 185, 1000, 1100) 
                THEN 'Первинний ринок (Салон / Імпорт)'
                
            -- Вторинний ринок: реальна зміна власників всередині країни
            WHEN v.OPER_CODE IN (10, 40, 49, 50, 62, 140, 186, 300, 301, 306, 307, 308, 310, 311, 312, 313, 314, 315, 316, 317, 319, 320, 321, 322, 324, 329, 331, 332, 363, 364) 
                THEN 'Вторинний ринок (Б/В продаж)'
                
            -- Вибуття: остаточне списання, утилізація чи вивезення за кордон
            WHEN v.OPER_CODE IN (293, 294, 295, 296, 500, 520, 537, 538, 540, 550, 555, 560, 570, 3000, 3001, 3003) 
                THEN 'Вибуття (Списання / Експорт)'
                
            -- Технічний шум: перереєстрація через встановлення ГБО, зміну кольору чи втрату техпаспорта
            ELSE 'Технічні операції (Зміна ГБО/Кольору/Документів)'
        END AS market_segment,
        
        -- КАНАЛ НАДХОДЖЕННЯ: Деталізація походження транспортного засобу
        CASE 
            WHEN v.OPER_CODE IN (69, 99, 105, 180, 185) THEN 'Нове (Салон)'
            WHEN v.OPER_CODE IN (70, 71, 72, 100, 182) THEN 'Імпорт Б/В'
            WHEN v.OPER_CODE IN (74, 75, 76, 77) THEN 'Гуманітарна допомога'
            WHEN v.OPER_CODE IN (10, 40, 49, 50, 186, 314, 315, 308, 307, 313, 317, 320, 310, 321, 322) THEN 'Внутрішній перепродаж'
            ELSE 'Інші реєстраційні дії'
        END AS vehicle_source,
        
        -- ВІКОВІ КАЕГОРІЇ: Динамічний розрахунок віку ТЗ на момент реєстрації
        CASE 
            WHEN (v.report_year - v.MAKE_YEAR) <= 0 THEN 'до 1 року'
            WHEN (v.report_year - v.MAKE_YEAR) BETWEEN 1 AND 5 THEN '1-5 років'
            WHEN (v.report_year - v.MAKE_YEAR) BETWEEN 6 AND 10 THEN '6-10 років'
            ELSE '11+ років'
        END AS age_category

    FROM v_all_years_trends v  
    -- Зв'язуємо за першими двома цифрами коду КОАТУУ для визначення регіону
    LEFT JOIN dict_regions r ON SUBSTR(v.REG_ADDR_KOATUU, 1, 2) = r.region_code

    -- Data Quality Filters: Очищення критичних пропусків та фокус на цільовому сегменті
    WHERE v.BRAND IS NOT NULL AND v.BRAND != ''
      AND v.MAKE_YEAR IS NOT NULL AND v.MAKE_YEAR > 1900 
      AND v.FUEL IS NOT NULL AND v.FUEL != '.' AND v.FUEL != ''
      AND v.KIND = 'ЛЕГКОВИЙ'
)

-- ЕТАП 2: Шар агрегації (Aggregation & Presentation Layer)
-- Розрахунок підсумкових KPI для BI-аналітики
SELECT 
    reg_year,
    reg_month,
    person_type,
    region,
    brand,
    model,
    vehicle_type,
    fuel_type,
    market_segment,
    vehicle_source,
    age_category,
    
    -- Обчислювальні бізнес-метрики (Business Metrics)
    COUNT(*) AS total_registrations,                         -- Обсяг ринку (Об'єм первинних/вторинних дій)
    ROUND(AVG(report_year - MAKE_YEAR), 1) AS avg_vehicle_age -- Середній вік автопарку в розрізі
    
FROM prepared_data

-- Групування за всіма аналітичними вимірами (просікаємо розмірність таблиці)
GROUP BY 
    reg_year,
    reg_month,
    person_type,
    region,
    brand,
    model,
    vehicle_type,
    fuel_type,
    market_segment,
    vehicle_source,
    age_category;