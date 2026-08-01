# HR Analytics DataLendo: инсайты и рекомендации

## Методология и допущения

- Дата анализа: **2026-08-01**.
- "Активный сотрудник" означает: `date_depart` пустая или позже даты анализа.
- "Последние 12 месяцев" означает период с **2025-08-01** по **2026-08-01**.
- В таблице `turnover` есть **36** записей с датой увольнения после даты анализа. Они не включены в показатели увольнений "на текущую дату", но остаются в исходных данных.
- Данные по performance заканчиваются в **2024** году. Поэтому показатель "нет feedback в 2026 году" равен всем активным сотрудникам; дополнительно выгружен список для последнего доступного года performance (**2024**).

## Ответы на 15 бизнес-вопросов

### 1. Сколько сотрудников сейчас активны?

Активных сотрудников на 2026-08-01: **1336** из **1500**.

### 2. Сколько увольнений было за последние 12 месяцев?

За последние 12 месяцев: **24** увольнений.

### 3. В каких департаментах самый высокий turnover?

| departement | effectif_total | employes_actifs | departs_jusqu_au_2026_08_01 | taux_turnover_reference_pct |
| --- | --- | --- | --- | --- |
| Direction Générale | 130 | 112 | 19 | 14,62 |
| Data & Analytics | 152 | 134 | 19 | 12,5 |
| Juridique | 161 | 141 | 20 | 12,42 |
| Opérations | 150 | 129 | 18 | 12 |
| Informatique | 159 | 141 | 19 | 11,95 |
| Marketing | 150 | 135 | 16 | 10,67 |
| Service Client | 136 | 123 | 13 | 9,56 |
| Ressources Humaines | 164 | 151 | 15 | 9,15 |
| Ventes | 159 | 144 | 14 | 8,81 |
| Finance | 139 | 126 | 11 | 7,91 |

### 4. Средняя зарплата по департаментам

| departement | salaire_moyen | salaire_min | salaire_max | nb_employes |
| --- | --- | --- | --- | --- |
| Direction Générale | 3057,57 | 811 | 4980 | 130 |
| Finance | 3052,11 | 915 | 4935 | 139 |
| Service Client | 3036,49 | 843 | 4938 | 136 |
| Informatique | 2989,18 | 802 | 4999 | 159 |
| Juridique | 2951,06 | 875 | 4988 | 161 |
| Ventes | 2925,3 | 815 | 4980 | 159 |
| Ressources Humaines | 2868,03 | 926 | 4982 | 164 |
| Opérations | 2781,61 | 816 | 4931 | 150 |
| Data & Analytics | 2773,31 | 834 | 4998 | 152 |
| Marketing | 2694,07 | 818 | 4906 | 150 |

### 5. Какие сотрудники имеют стаж более 5 лет?

Таких сотрудников: **669**. Полный список находится в `outputs/employes_plus_5_ans.csv`.

### 6. Рейтинг департаментов по средней квартальной performance

| departement | score_moyen_trimestriel | nb_evaluations |
| --- | --- | --- |
| Opérations | 74,87 | 1800 |
| Service Client | 74,72 | 1632 |
| Data & Analytics | 74,69 | 1824 |
| Finance | 74,59 | 1668 |
| Ressources Humaines | 74,52 | 1968 |
| Juridique | 74,49 | 1932 |
| Ventes | 74,42 | 1908 |
| Direction Générale | 74,41 | 1560 |
| Informatique | 74,22 | 1908 |
| Marketing | 73,83 | 1800 |

### 7. Топ-10 сотрудников за 3 последних квартала

| id_employe | nom | prenom | poste | nom_departement | score_moyen_3_derniers_trimestres |
| --- | --- | --- | --- | --- | --- |
| 493 | Nom_493 | Prenom_493 | Developpeur | Direction Générale | 98,33 |
| 1156 | Nom_1156 | Prenom_1156 | RH | Ressources Humaines | 97,33 |
| 1009 | Nom_1009 | Prenom_1009 | Analyste | Data & Analytics | 96 |
| 536 | Nom_536 | Prenom_536 | Finance | Ventes | 95 |
| 424 | Nom_424 | Prenom_424 | Analyste | Opérations | 95 |
| 852 | Nom_852 | Prenom_852 | Analyste | Marketing | 94,67 |
| 1366 | Nom_1366 | Prenom_1366 | RH | Opérations | 94,67 |
| 549 | Nom_549 | Prenom_549 | Analyste | Ventes | 94,67 |
| 1490 | Nom_1490 | Prenom_1490 | Finance | Marketing | 94,33 |
| 280 | Nom_280 | Prenom_280 | Analyste | Service Client | 94 |

### 8. Сотрудники с самой низкой performance и их департамент

| id_employe | nom | prenom | poste | nom_departement | score_moyen_3_derniers_trimestres |
| --- | --- | --- | --- | --- | --- |
| 957 | Nom_957 | Prenom_957 | Finance | Direction Générale | 52,33 |
| 755 | Nom_755 | Prenom_755 | Finance | Marketing | 53,33 |
| 1367 | Nom_1367 | Prenom_1367 | Finance | Ressources Humaines | 54 |
| 431 | Nom_431 | Prenom_431 | RH | Informatique | 54,33 |
| 1240 | Nom_1240 | Prenom_1240 | RH | Ressources Humaines | 54,33 |
| 1411 | Nom_1411 | Prenom_1411 | Analyste | Ressources Humaines | 54,33 |
| 1143 | Nom_1143 | Prenom_1143 | Developpeur | Juridique | 54,67 |
| 8 | Nom_8 | Prenom_8 | Finance | Juridique | 54,67 |
| 10 | Nom_10 | Prenom_10 | Manager | Ventes | 55,33 |
| 69 | Nom_69 | Prenom_69 | Manager | Direction Générale | 55,67 |

### 9. Средняя retention по когортам найма

| cohorte_embauche | nb_embauches | nb_actifs_au_2026_08_01 | nb_departs_avant_reference | retention_pct |
| --- | --- | --- | --- | --- |
| 2019 | 280 | 245 | 35 | 87,5 |
| 2020 | 288 | 246 | 42 | 85,42 |
| 2021 | 331 | 296 | 35 | 89,43 |
| 2022 | 317 | 281 | 36 | 88,64 |
| 2023 | 284 | 268 | 16 | 94,37 |

### 10. Какие департаменты нанимают чаще всего?

| departement | nb_embauches | premiere_embauche | derniere_embauche |
| --- | --- | --- | --- |
| Ressources Humaines | 164 | 2019-01-09 | 2023-12-25 |
| Juridique | 161 | 2019-01-10 | 2023-12-12 |
| Informatique | 159 | 2019-01-02 | 2023-12-16 |
| Ventes | 159 | 2019-01-04 | 2023-12-22 |
| Data & Analytics | 152 | 2019-01-14 | 2023-12-18 |
| Opérations | 150 | 2019-01-02 | 2023-12-21 |
| Marketing | 150 | 2019-01-01 | 2023-12-30 |
| Finance | 139 | 2019-01-22 | 2023-12-08 |
| Service Client | 136 | 2019-01-13 | 2023-12-29 |
| Direction Générale | 130 | 2019-01-01 | 2023-12-29 |

### 11. Доля добровольных и недобровольных увольнений

| type_depart | nb_departs | proportion_pct |
| --- | --- | --- |
| involontaire | 82 | 50 |
| volontaire | 82 | 50 |

### 12. Распределение должностей по стажу

Полная таблица находится в `outputs/distribution_postes_par_anciennete.csv`.

### 13. Какие сотрудники не получили feedback в этом году?

В 2026 году feedback отсутствует у **1336** активных сотрудников, потому что таблица performance не содержит оценок за 2026 год. Для последнего доступного года performance (2024) без feedback осталось **0** активных сотрудников.

### 14. Сегментация сотрудников по performance

| categorie_performance | nb_employes | proportion_pct |
| --- | --- | --- |
| Высокая | 408 | 27,2 |
| Низкая | 62 | 4,13 |
| Средняя | 1030 | 68,67 |

### 15. Сводный KPI по департаментам и когортам

Полная таблица находится в `outputs/kpis_departement_cohorte.csv`. Первые строки:

| departement | cohorte_embauche | nb_employes | nb_actifs | retention_pct | salaire_moyen | score_moyen |
| --- | --- | --- | --- | --- | --- | --- |
| Data & Analytics | 2019 | 23 | 20 | 86,96 | 2691,87 | 74,61 |
| Data & Analytics | 2020 | 42 | 36 | 85,71 | 2762,55 | 74,75 |
| Data & Analytics | 2021 | 34 | 29 | 85,29 | 2723,44 | 73,97 |
| Data & Analytics | 2022 | 21 | 18 | 85,71 | 2968,48 | 75,92 |
| Data & Analytics | 2023 | 32 | 31 | 96,88 | 2770,88 | 74,64 |
| Direction Générale | 2019 | 23 | 18 | 78,26 | 2709,43 | 74,2 |
| Direction Générale | 2020 | 26 | 23 | 88,46 | 2893,69 | 74,93 |
| Direction Générale | 2021 | 30 | 27 | 90 | 3205,67 | 74,02 |
| Direction Générale | 2022 | 24 | 20 | 83,33 | 2978,62 | 76,08 |
| Direction Générale | 2023 | 27 | 24 | 88,89 | 3417,56 | 73,04 |
| Finance | 2019 | 26 | 22 | 84,62 | 3148,5 | 73,87 |
| Finance | 2020 | 28 | 27 | 96,43 | 3274 | 74,85 |
| Finance | 2021 | 29 | 26 | 89,66 | 2902,24 | 75,5 |
| Finance | 2022 | 30 | 26 | 86,67 | 2919,37 | 74,46 |
| Finance | 2023 | 26 | 25 | 96,15 | 3037,08 | 74,18 |
| Informatique | 2019 | 26 | 22 | 84,62 | 3003,5 | 75,42 |
| Informatique | 2020 | 25 | 21 | 84 | 3043,96 | 73,25 |
| Informatique | 2021 | 36 | 31 | 86,11 | 3063,31 | 74,44 |
| Informatique | 2022 | 39 | 36 | 92,31 | 3103,49 | 73,7 |
| Informatique | 2023 | 33 | 31 | 93,94 | 2720,45 | 74,4 |

## Рекомендации HR

1. Сфокусировать retention-план на департаментах с максимальным turnover: проверить нагрузку, зарплатную конкурентность, менеджерскую практику и причины ухода.
2. Для сотрудников из нижнего performance-сегмента запустить индивидуальные планы развития: цели на квартал, регулярные one-to-one и повторная оценка через 90 дней.
3. Проверить процесс performance review: в 2026 году нет оценок в данных, поэтому нужна актуализация HRIS или отдельный контроль закрытия циклов feedback.
4. Сравнить средние зарплаты и turnover по департаментам: если департамент одновременно имеет высокий turnover и низкую оплату, это кандидат на компенсационный пересмотр.
5. Использовать когорты найма для раннего предупреждения: падение retention в конкретном году найма может указывать на проблемы адаптации, менеджмента или ожиданий кандидатов.
6. Для топ-10 сотрудников подготовить программу удержания: карьерные треки, признание, развитие и риск-анализ ухода.
