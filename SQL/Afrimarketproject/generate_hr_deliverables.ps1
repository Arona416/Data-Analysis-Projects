$ErrorActionPreference = 'Stop'

$ReferenceDate = [datetime]'2026-08-01'
$Last12Start = $ReferenceDate.AddYears(-1)

New-Item -ItemType Directory -Force -Path 'outputs' | Out-Null
New-Item -ItemType Directory -Force -Path 'sql' | Out-Null

function Parse-DateOrNull($value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    return [datetime]$value
}

function Round2($value) {
    if ($null -eq $value) { return $null }
    return [math]::Round([double]$value, 2)
}

function Export-Utf8Csv($rows, $path) {
    if ($null -eq $rows) {
        Set-Content -Path $path -Value '' -Encoding UTF8
        return
    }
    @($rows) | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
}

$employees = Import-Csv 'data/employes.csv'
$departments = Import-Csv 'data/departements.csv'
$performances = Import-Csv 'data/performances.csv'
$turnover = Import-Csv 'data/turnover.csv'

$deptById = @{}
foreach ($d in $departments) {
    $deptById[[int]$d.id_departement] = $d
}

foreach ($e in $employees) {
    $hireDate = Parse-DateOrNull $e.date_embauche
    $departureDate = Parse-DateOrNull $e.date_depart
    $isActive = ($null -eq $departureDate) -or ($departureDate -gt $ReferenceDate)
    $tenureEnd = if ($isActive) { $ReferenceDate } else { $departureDate }
    $tenureYears = if ($hireDate) { (($tenureEnd - $hireDate).TotalDays / 365.25) } else { $null }

    $dept = $deptById[[int]$e.departement_id]
    $e | Add-Member -NotePropertyName hire_date_dt -NotePropertyValue $hireDate
    $e | Add-Member -NotePropertyName departure_date_dt -NotePropertyValue $departureDate
    $e | Add-Member -NotePropertyName is_active_ref -NotePropertyValue $isActive
    $e | Add-Member -NotePropertyName tenure_years_ref -NotePropertyValue (Round2 $tenureYears)
    $e | Add-Member -NotePropertyName hire_cohort -NotePropertyValue $hireDate.Year
    $e | Add-Member -NotePropertyName department_name -NotePropertyValue $dept.nom_departement
}

$employeeById = @{}
foreach ($e in $employees) {
    $employeeById[[int]$e.id_employe] = $e
}

foreach ($p in $performances) {
    $p | Add-Member -NotePropertyName eval_date_dt -NotePropertyValue ([datetime]$p.date_evaluation)
    $p | Add-Member -NotePropertyName score_num -NotePropertyValue ([double]$p.score)
}

foreach ($t in $turnover) {
    $t | Add-Member -NotePropertyName departure_date_dt -NotePropertyValue ([datetime]$t.date_depart)
}

$perfByEmployee = $performances | Group-Object id_employe
$perfStats = @{}
foreach ($g in $perfByEmployee) {
    $items = $g.Group | Sort-Object eval_date_dt -Descending
    $last3 = $items | Select-Object -First 3
    $avgAll = ($items | Measure-Object score_num -Average).Average
    $avgLast3 = ($last3 | Measure-Object score_num -Average).Average
    $latestYear = ($items | Select-Object -First 1).eval_date_dt.Year
    $perfStats[[int]$g.Name] = [pscustomobject]@{
        AvgScoreAll = Round2 $avgAll
        AvgScoreLast3 = Round2 $avgLast3
        LatestEvalYear = $latestYear
        LatestEvalDate = ($items | Select-Object -First 1).eval_date_dt
    }
}

$enriched = foreach ($e in $employees) {
    $id = [int]$e.id_employe
    $stats = $perfStats[$id]
    $avgLast3 = if ($stats) { $stats.AvgScoreLast3 } else { $null }
    $perfCategory = if ($null -eq $avgLast3) {
        'Нет оценки'
    } elseif ($avgLast3 -lt 60) {
        'Низкая'
    } elseif ($avgLast3 -lt 80) {
        'Средняя'
    } else {
        'Высокая'
    }

    [pscustomobject]@{
        id_employe = $e.id_employe
        nom = $e.nom
        prenom = $e.prenom
        poste = $e.poste
        departement_id = $e.departement_id
        nom_departement = $e.department_name
        date_embauche = $e.date_embauche
        date_depart = $e.date_depart
        statut_au_2026_08_01 = if ($e.is_active_ref) { 'Активен' } else { 'Уволен' }
        salaire = [int]$e.salaire
        anciennete_annees = $e.tenure_years_ref
        cohorte_embauche = $e.hire_cohort
        score_moyen_total = if ($stats) { $stats.AvgScoreAll } else { $null }
        score_moyen_3_derniers_trimestres = $avgLast3
        categorie_performance = $perfCategory
        derniere_evaluation = if ($stats) { $stats.LatestEvalDate.ToString('yyyy-MM-dd') } else { '' }
    }
}
Export-Utf8Csv $enriched 'outputs/dataset_enrichi_rh.csv'

$activeEmployees = @($employees | Where-Object { $_.is_active_ref })
$departuresLast12 = @($turnover | Where-Object { $_.departure_date_dt -ge $Last12Start -and $_.departure_date_dt -le $ReferenceDate })
$departuresUntilRef = @($turnover | Where-Object { $_.departure_date_dt -le $ReferenceDate })
$futureDepartures = @($turnover | Where-Object { $_.departure_date_dt -gt $ReferenceDate })

$turnoverByDept = foreach ($g in ($employees | Group-Object departement_id)) {
    $deptId = [int]$g.Name
    $deptName = $deptById[$deptId].nom_departement
    $ids = @($g.Group | ForEach-Object { [int]$_.id_employe })
    $departures = @($departuresUntilRef | Where-Object { $ids -contains [int]$_.id_employe })
    $departures12 = @($departuresLast12 | Where-Object { $ids -contains [int]$_.id_employe })
    [pscustomobject]@{
        departement_id = $deptId
        departement = $deptName
        effectif_total = $g.Count
        employes_actifs = @($g.Group | Where-Object { $_.is_active_ref }).Count
        departs_jusqu_au_2026_08_01 = $departures.Count
        departs_12_derniers_mois = $departures12.Count
        taux_turnover_reference_pct = Round2 (($departures.Count / $g.Count) * 100)
        taux_turnover_12_mois_pct = Round2 (($departures12.Count / $g.Count) * 100)
    }
}
$turnoverByDept = $turnoverByDept | Sort-Object taux_turnover_reference_pct -Descending
Export-Utf8Csv $turnoverByDept 'outputs/turnover_par_departement.csv'

$salaryByDept = foreach ($g in ($employees | Group-Object departement_id)) {
    $deptId = [int]$g.Name
    [pscustomobject]@{
        departement_id = $deptId
        departement = $deptById[$deptId].nom_departement
        salaire_moyen = Round2 (($g.Group | Measure-Object salaire -Average).Average)
        salaire_min = ($g.Group | Measure-Object salaire -Minimum).Minimum
        salaire_max = ($g.Group | Measure-Object salaire -Maximum).Maximum
        nb_employes = $g.Count
    }
}
$salaryByDept = $salaryByDept | Sort-Object salaire_moyen -Descending
Export-Utf8Csv $salaryByDept 'outputs/salaire_moyen_par_departement.csv'

$seniorEmployees = $enriched | Where-Object { [double]$_.anciennete_annees -gt 5 } | Sort-Object {[double]$_.anciennete_annees} -Descending
Export-Utf8Csv $seniorEmployees 'outputs/employes_plus_5_ans.csv'

$perfByDept = foreach ($g in ($performances | Group-Object {
    $employeeById[[int]$_.id_employe].departement_id
})) {
    $deptId = [int]$g.Name
    [pscustomobject]@{
        departement_id = $deptId
        departement = $deptById[$deptId].nom_departement
        score_moyen_trimestriel = Round2 (($g.Group | Measure-Object score_num -Average).Average)
        nb_evaluations = $g.Count
    }
}
$perfByDept = $perfByDept | Sort-Object score_moyen_trimestriel -Descending
Export-Utf8Csv $perfByDept 'outputs/performance_moyenne_par_departement.csv'

$topEmployees = $enriched | Where-Object { $_.score_moyen_3_derniers_trimestres -ne $null } |
    Sort-Object {[double]$_.score_moyen_3_derniers_trimestres} -Descending |
    Select-Object -First 10
Export-Utf8Csv $topEmployees 'outputs/top_10_employes_3_derniers_trimestres.csv'

$lowEmployees = $enriched | Where-Object { $_.score_moyen_3_derniers_trimestres -ne $null } |
    Sort-Object {[double]$_.score_moyen_3_derniers_trimestres} |
    Select-Object -First 20
Export-Utf8Csv $lowEmployees 'outputs/employes_moins_performants.csv'

$retentionByCohort = foreach ($g in ($employees | Group-Object hire_cohort)) {
    $active = @($g.Group | Where-Object { $_.is_active_ref }).Count
    [pscustomobject]@{
        cohorte_embauche = [int]$g.Name
        nb_embauches = $g.Count
        nb_actifs_au_2026_08_01 = $active
        nb_departs_avant_reference = $g.Count - $active
        retention_pct = Round2 (($active / $g.Count) * 100)
    }
}
$retentionByCohort = $retentionByCohort | Sort-Object cohorte_embauche
Export-Utf8Csv $retentionByCohort 'outputs/retention_par_cohorte.csv'

$recruitingByDept = foreach ($g in ($employees | Group-Object departement_id)) {
    $deptId = [int]$g.Name
    [pscustomobject]@{
        departement_id = $deptId
        departement = $deptById[$deptId].nom_departement
        nb_embauches = $g.Count
        premiere_embauche = ($g.Group | Sort-Object hire_date_dt | Select-Object -First 1).date_embauche
        derniere_embauche = ($g.Group | Sort-Object hire_date_dt -Descending | Select-Object -First 1).date_embauche
    }
}
$recruitingByDept = $recruitingByDept | Sort-Object nb_embauches -Descending
Export-Utf8Csv $recruitingByDept 'outputs/recrutement_par_departement.csv'

$departureType = foreach ($g in ($departuresUntilRef | Group-Object type_depart)) {
    [pscustomobject]@{
        type_depart = $g.Name
        nb_departs = $g.Count
        proportion_pct = Round2 (($g.Count / $departuresUntilRef.Count) * 100)
    }
}
Export-Utf8Csv $departureType 'outputs/proportion_departs_volontaires_involontaires.csv'

function Get-TenureBucket($years) {
    if ($years -lt 1) { return '< 1 год' }
    if ($years -lt 3) { return '1-2 года' }
    if ($years -le 5) { return '3-5 лет' }
    return '> 5 лет'
}

$distributionPosteAnciennete = foreach ($g in ($employees | Group-Object {
    $bucket = Get-TenureBucket ([double]$_.tenure_years_ref)
    "$($_.poste)|$bucket"
})) {
    $parts = $g.Name.Split('|')
    [pscustomobject]@{
        poste = $parts[0]
        tranche_anciennete = $parts[1]
        nb_employes = $g.Count
    }
}
$distributionPosteAnciennete = $distributionPosteAnciennete | Sort-Object poste,tranche_anciennete
Export-Utf8Csv $distributionPosteAnciennete 'outputs/distribution_postes_par_anciennete.csv'

$feedbackYear = 2026
$latestPerformanceYear = ($performances | Sort-Object eval_date_dt -Descending | Select-Object -First 1).eval_date_dt.Year
$employeesFeedback2026 = @($performances | Where-Object { $_.eval_date_dt.Year -eq $feedbackYear } | Select-Object -ExpandProperty id_employe -Unique)
$employeesFeedbackLatestYear = @($performances | Where-Object { $_.eval_date_dt.Year -eq $latestPerformanceYear } | Select-Object -ExpandProperty id_employe -Unique)
$noFeedback2026 = $enriched | Where-Object { $_.statut_au_2026_08_01 -eq 'Активен' -and ($employeesFeedback2026 -notcontains $_.id_employe) }
$noFeedbackLatestYear = $enriched | Where-Object { $_.statut_au_2026_08_01 -eq 'Активен' -and ($employeesFeedbackLatestYear -notcontains $_.id_employe) }
Export-Utf8Csv $noFeedback2026 'outputs/employes_sans_feedback_2026.csv'
Export-Utf8Csv $noFeedbackLatestYear 'outputs/employes_sans_feedback_derniere_annee_disponible_2024.csv'

$performanceSegments = foreach ($g in ($enriched | Group-Object categorie_performance)) {
    [pscustomobject]@{
        categorie_performance = $g.Name
        nb_employes = $g.Count
        proportion_pct = Round2 (($g.Count / $enriched.Count) * 100)
    }
}
$performanceSegments = $performanceSegments | Sort-Object categorie_performance
Export-Utf8Csv $performanceSegments 'outputs/segmentation_performance.csv'

$deptCohortKpis = foreach ($g in ($employees | Group-Object {
    "$($_.departement_id)|$($_.hire_cohort)"
})) {
    $parts = $g.Name.Split('|')
    $deptId = [int]$parts[0]
    $cohort = [int]$parts[1]
    $ids = @($g.Group | ForEach-Object { [int]$_.id_employe })
    $active = @($g.Group | Where-Object { $_.is_active_ref }).Count
    $scores = @($performances | Where-Object { $ids -contains [int]$_.id_employe })
    [pscustomobject]@{
        departement_id = $deptId
        departement = $deptById[$deptId].nom_departement
        cohorte_embauche = $cohort
        nb_employes = $g.Count
        nb_actifs = $active
        nb_departs = $g.Count - $active
        retention_pct = Round2 (($active / $g.Count) * 100)
        salaire_moyen = Round2 (($g.Group | Measure-Object salaire -Average).Average)
        anciennete_moyenne = Round2 (($g.Group | Measure-Object tenure_years_ref -Average).Average)
        score_moyen = if ($scores.Count -gt 0) { Round2 (($scores | Measure-Object score_num -Average).Average) } else { $null }
    }
}
$deptCohortKpis = $deptCohortKpis | Sort-Object departement,cohorte_embauche
Export-Utf8Csv $deptCohortKpis 'outputs/kpis_departement_cohorte.csv'

$summary = [ordered]@{
    reference_date = $ReferenceDate.ToString('yyyy-MM-dd')
    employees_total = $employees.Count
    departments_total = $departments.Count
    performance_rows = $performances.Count
    turnover_rows = $turnover.Count
    active_employees = $activeEmployees.Count
    inactive_by_reference = $employees.Count - $activeEmployees.Count
    departures_last_12_months = $departuresLast12.Count
    departures_until_reference = $departuresUntilRef.Count
    future_departure_rows_after_reference = $futureDepartures.Count
    latest_performance_year = $latestPerformanceYear
    no_feedback_2026_active = @($noFeedback2026).Count
    no_feedback_latest_available_year_active = @($noFeedbackLatestYear).Count
}
$summaryRows = $summary.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{ metric = $_.Key; value = $_.Value }
}
Export-Utf8Csv $summaryRows 'outputs/kpi_global_summary.csv'

function MdTable($rows, $columns, $maxRows = 20) {
    $selected = @($rows | Select-Object -First $maxRows)
    $header = '| ' + ($columns -join ' | ') + ' |'
    $sep = '| ' + (($columns | ForEach-Object { '---' }) -join ' | ') + ' |'
    $lines = @($header, $sep)
    foreach ($row in $selected) {
        $values = foreach ($col in $columns) {
            $value = $row.$col
            if ($null -eq $value) { '' } else { ($value.ToString() -replace '\|','/') }
        }
        $lines += '| ' + ($values -join ' | ') + ' |'
    }
    return ($lines -join "`r`n")
}

$topTurnover = MdTable $turnoverByDept @('departement','effectif_total','employes_actifs','departs_jusqu_au_2026_08_01','taux_turnover_reference_pct') 10
$salaryTable = MdTable $salaryByDept @('departement','salaire_moyen','salaire_min','salaire_max','nb_employes') 10
$perfDeptTable = MdTable $perfByDept @('departement','score_moyen_trimestriel','nb_evaluations') 10
$top10Table = MdTable $topEmployees @('id_employe','nom','prenom','poste','nom_departement','score_moyen_3_derniers_trimestres') 10
$lowTable = MdTable $lowEmployees @('id_employe','nom','prenom','poste','nom_departement','score_moyen_3_derniers_trimestres') 10
$retentionTable = MdTable $retentionByCohort @('cohorte_embauche','nb_embauches','nb_actifs_au_2026_08_01','nb_departs_avant_reference','retention_pct') 10
$recruitingTable = MdTable $recruitingByDept @('departement','nb_embauches','premiere_embauche','derniere_embauche') 10
$departureTypeTable = MdTable $departureType @('type_depart','nb_departs','proportion_pct') 10
$segmentTable = MdTable $performanceSegments @('categorie_performance','nb_employes','proportion_pct') 10
$kpiDeptCohortPreview = MdTable $deptCohortKpis @('departement','cohorte_embauche','nb_employes','nb_actifs','retention_pct','salaire_moyen','score_moyen') 20

$insights = @"
# HR Analytics DataLendo: инсайты и рекомендации

## Методология и допущения

- Дата анализа: **$($ReferenceDate.ToString('yyyy-MM-dd'))**.
- "Активный сотрудник" означает: ``date_depart`` пустая или позже даты анализа.
- "Последние 12 месяцев" означает период с **$($Last12Start.ToString('yyyy-MM-dd'))** по **$($ReferenceDate.ToString('yyyy-MM-dd'))**.
- В таблице ``turnover`` есть **$($futureDepartures.Count)** записей с датой увольнения после даты анализа. Они не включены в показатели увольнений "на текущую дату", но остаются в исходных данных.
- Данные по performance заканчиваются в **$latestPerformanceYear** году. Поэтому показатель "нет feedback в 2026 году" равен всем активным сотрудникам; дополнительно выгружен список для последнего доступного года performance (**$latestPerformanceYear**).

## Ответы на 15 бизнес-вопросов

### 1. Сколько сотрудников сейчас активны?

Активных сотрудников на $($ReferenceDate.ToString('yyyy-MM-dd')): **$($activeEmployees.Count)** из **$($employees.Count)**.

### 2. Сколько увольнений было за последние 12 месяцев?

За последние 12 месяцев: **$($departuresLast12.Count)** увольнений.

### 3. В каких департаментах самый высокий turnover?

$topTurnover

### 4. Средняя зарплата по департаментам

$salaryTable

### 5. Какие сотрудники имеют стаж более 5 лет?

Таких сотрудников: **$(@($seniorEmployees).Count)**. Полный список находится в ``outputs/employes_plus_5_ans.csv``.

### 6. Рейтинг департаментов по средней квартальной performance

$perfDeptTable

### 7. Топ-10 сотрудников за 3 последних квартала

$top10Table

### 8. Сотрудники с самой низкой performance и их департамент

$lowTable

### 9. Средняя retention по когортам найма

$retentionTable

### 10. Какие департаменты нанимают чаще всего?

$recruitingTable

### 11. Доля добровольных и недобровольных увольнений

$departureTypeTable

### 12. Распределение должностей по стажу

Полная таблица находится в ``outputs/distribution_postes_par_anciennete.csv``.

### 13. Какие сотрудники не получили feedback в этом году?

В 2026 году feedback отсутствует у **$(@($noFeedback2026).Count)** активных сотрудников, потому что таблица performance не содержит оценок за 2026 год. Для последнего доступного года performance ($latestPerformanceYear) без feedback осталось **$(@($noFeedbackLatestYear).Count)** активных сотрудников.

### 14. Сегментация сотрудников по performance

$segmentTable

### 15. Сводный KPI по департаментам и когортам

Полная таблица находится в ``outputs/kpis_departement_cohorte.csv``. Первые строки:

$kpiDeptCohortPreview

## Рекомендации HR

1. Сфокусировать retention-план на департаментах с максимальным turnover: проверить нагрузку, зарплатную конкурентность, менеджерскую практику и причины ухода.
2. Для сотрудников из нижнего performance-сегмента запустить индивидуальные планы развития: цели на квартал, регулярные one-to-one и повторная оценка через 90 дней.
3. Проверить процесс performance review: в 2026 году нет оценок в данных, поэтому нужна актуализация HRIS или отдельный контроль закрытия циклов feedback.
4. Сравнить средние зарплаты и turnover по департаментам: если департамент одновременно имеет высокий turnover и низкую оплату, это кандидат на компенсационный пересмотр.
5. Использовать когорты найма для раннего предупреждения: падение retention в конкретном году найма может указывать на проблемы адаптации, менеджмента или ожиданий кандидатов.
6. Для топ-10 сотрудников подготовить программу удержания: карьерные треки, признание, развитие и риск-анализ ухода.
"@
Set-Content -Path 'outputs/insights_rh_ru.md' -Value $insights -Encoding UTF8

$readme = @"
# DataLendo HR Analytics

Проект содержит SQL-анализ HR-данных DataLendo и русскоязычные аналитические результаты.

## Данные

- ``data/employes.csv``: сотрудники, должности, департаменты, даты найма/ухода, зарплата.
- ``data/departements.csv``: справочник департаментов, менеджеры, бюджеты.
- ``data/performances.csv``: квартальные оценки сотрудников и достижение целей.
- ``data/turnover.csv``: события увольнений, тип ухода и стаж.

## Ключевые допущения

- Дата анализа: `$($ReferenceDate.ToString('yyyy-MM-dd'))`.
- Активный сотрудник: ``date_depart IS NULL OR date_depart > DATE '2026-08-01'``.
- Последние 12 месяцев: с `$($Last12Start.ToString('yyyy-MM-dd'))` по `$($ReferenceDate.ToString('yyyy-MM-dd'))`.
- Performance-данные доступны только до `$latestPerformanceYear` года.

## Структура проекта

- ``sql/01_schema.sql``: DDL для создания таблиц.
- ``sql/02_analysis_queries.sql``: SQL-запросы для 15 бизнес-вопросов.
- ``outputs/dataset_enrichi_rh.csv``: обогащенный датасет сотрудников.
- ``outputs/insights_rh_ru.md``: ответы, инсайты и рекомендации на русском языке.
- ``outputs/*.csv``: отдельные таблицы результатов.
- ``generate_hr_deliverables.ps1``: воспроизводимый PowerShell-скрипт генерации результатов.

## Методология

1. Импорт CSV.
2. Нормализация дат и расчет статуса сотрудника на дату анализа.
3. Расчет стажа, когорты найма, среднего score и performance-сегмента.
4. Агрегации по департаментам, когортам, должностям и типам увольнений.
5. Формирование итоговых CSV и markdown-отчета.

## Как воспроизвести

~~~powershell
.\generate_hr_deliverables.ps1
~~~
"@
Set-Content -Path 'README_RU.md' -Value $readme -Encoding UTF8

$schemaSql = @"
-- Schema for DataLendo HR Analytics
-- SQL dialect: PostgreSQL

DROP TABLE IF EXISTS turnover;
DROP TABLE IF EXISTS performances;
DROP TABLE IF EXISTS employes;
DROP TABLE IF EXISTS departements;

CREATE TABLE departements (
    id_departement INTEGER PRIMARY KEY,
    nom_departement VARCHAR(100) NOT NULL,
    manager VARCHAR(100),
    budget NUMERIC(12, 2)
);

CREATE TABLE employes (
    id_employe INTEGER PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    poste VARCHAR(100),
    departement_id INTEGER REFERENCES departements(id_departement),
    date_embauche DATE NOT NULL,
    date_depart DATE,
    salaire NUMERIC(12, 2)
);

CREATE TABLE performances (
    id_performance INTEGER PRIMARY KEY,
    id_employe INTEGER REFERENCES employes(id_employe),
    date_evaluation DATE NOT NULL,
    score NUMERIC(5, 2) NOT NULL,
    objectifs_atteints BOOLEAN
);

CREATE TABLE turnover (
    id_depart INTEGER PRIMARY KEY,
    id_employe INTEGER REFERENCES employes(id_employe),
    date_depart DATE NOT NULL,
    type_depart VARCHAR(20) CHECK (type_depart IN ('volontaire', 'involontaire')),
    anciennete NUMERIC(6, 2)
);
"@
Set-Content -Path 'sql/01_schema.sql' -Value $schemaSql -Encoding UTF8

$analysisSql = @"
-- DataLendo HR Analytics: 15 business questions
-- SQL dialect: PostgreSQL
-- Reference date used in this project: 2026-08-01

-- Common enriched employee view.
WITH perf_ranked AS (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY p.id_employe
            ORDER BY p.date_evaluation DESC
        ) AS rn
    FROM performances p
),
perf_stats AS (
    SELECT
        e.id_employe,
        AVG(p.score) AS score_moyen_total,
        AVG(CASE WHEN pr.rn <= 3 THEN pr.score END) AS score_moyen_3_derniers_trimestres,
        MAX(p.date_evaluation) AS derniere_evaluation
    FROM employes e
    LEFT JOIN performances p ON p.id_employe = e.id_employe
    LEFT JOIN perf_ranked pr
        ON pr.id_performance = p.id_performance
    GROUP BY e.id_employe
),
employes_enrichis AS (
    SELECT
        e.*,
        d.nom_departement,
        CASE
            WHEN e.date_depart IS NULL OR e.date_depart > DATE '2026-08-01'
            THEN TRUE ELSE FALSE
        END AS actif,
        EXTRACT(YEAR FROM e.date_embauche)::INT AS cohorte_embauche,
        ROUND(
            (DATE_PART('day', COALESCE(
                CASE WHEN e.date_depart <= DATE '2026-08-01' THEN e.date_depart END,
                DATE '2026-08-01'
            ) - e.date_embauche) / 365.25)::NUMERIC,
            2
        ) AS anciennete_annees,
        ps.score_moyen_total,
        ps.score_moyen_3_derniers_trimestres,
        CASE
            WHEN ps.score_moyen_3_derniers_trimestres IS NULL THEN 'Нет оценки'
            WHEN ps.score_moyen_3_derniers_trimestres < 60 THEN 'Низкая'
            WHEN ps.score_moyen_3_derniers_trimestres < 80 THEN 'Средняя'
            ELSE 'Высокая'
        END AS categorie_performance,
        ps.derniere_evaluation
    FROM employes e
    JOIN departements d ON d.id_departement = e.departement_id
    LEFT JOIN perf_stats ps ON ps.id_employe = e.id_employe
)

-- 1. Combien d'employes sont actuellement actifs?
SELECT COUNT(*) AS employes_actifs
FROM employes_enrichis
WHERE actif = TRUE;

-- 2. Combien de departs avons-nous eu sur les 12 derniers mois?
SELECT COUNT(*) AS departs_12_derniers_mois
FROM turnover
WHERE date_depart BETWEEN DATE '2025-08-01' AND DATE '2026-08-01';

-- 3. Quels departements ont le turnover le plus eleve?
SELECT
    d.nom_departement,
    COUNT(t.id_depart) AS nb_departs,
    COUNT(e.id_employe) AS effectif_total,
    ROUND((COUNT(t.id_depart)::NUMERIC / COUNT(e.id_employe)) * 100, 2) AS taux_turnover_pct
FROM departements d
JOIN employes e ON e.departement_id = d.id_departement
LEFT JOIN turnover t
    ON t.id_employe = e.id_employe
   AND t.date_depart <= DATE '2026-08-01'
GROUP BY d.nom_departement
ORDER BY taux_turnover_pct DESC, nb_departs DESC;

-- 4. Quel est le salaire moyen par departement?
SELECT
    d.nom_departement,
    ROUND(AVG(e.salaire), 2) AS salaire_moyen,
    MIN(e.salaire) AS salaire_min,
    MAX(e.salaire) AS salaire_max
FROM employes e
JOIN departements d ON d.id_departement = e.departement_id
GROUP BY d.nom_departement
ORDER BY salaire_moyen DESC;

-- 5. Quels employes ont plus de 5 ans d'anciennete?
SELECT *
FROM employes_enrichis
WHERE anciennete_annees > 5
ORDER BY anciennete_annees DESC;

-- 6. Classez les departements par performance moyenne trimestrielle.
SELECT
    d.nom_departement,
    ROUND(AVG(p.score), 2) AS score_moyen_trimestriel,
    COUNT(*) AS nb_evaluations
FROM performances p
JOIN employes e ON e.id_employe = p.id_employe
JOIN departements d ON d.id_departement = e.departement_id
GROUP BY d.nom_departement
ORDER BY score_moyen_trimestriel DESC;

-- 7. Identifier les 10 meilleurs employes sur 3 derniers trimestres.
SELECT
    id_employe, nom, prenom, poste, nom_departement,
    ROUND(score_moyen_3_derniers_trimestres, 2) AS score_moyen_3_derniers_trimestres
FROM employes_enrichis
WHERE score_moyen_3_derniers_trimestres IS NOT NULL
ORDER BY score_moyen_3_derniers_trimestres DESC
LIMIT 10;

-- 8. Identifier les employes les moins performants et leur departement.
SELECT
    id_employe, nom, prenom, poste, nom_departement,
    ROUND(score_moyen_3_derniers_trimestres, 2) AS score_moyen_3_derniers_trimestres
FROM employes_enrichis
WHERE score_moyen_3_derniers_trimestres IS NOT NULL
ORDER BY score_moyen_3_derniers_trimestres ASC
LIMIT 20;

-- 9. Calculer la retention moyenne par cohorte d'embauche.
SELECT
    cohorte_embauche,
    COUNT(*) AS nb_embauches,
    SUM(CASE WHEN actif THEN 1 ELSE 0 END) AS nb_actifs,
    ROUND((SUM(CASE WHEN actif THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS retention_pct
FROM employes_enrichis
GROUP BY cohorte_embauche
ORDER BY cohorte_embauche;

-- 10. Quels departements recrutent le plus souvent?
SELECT
    d.nom_departement,
    COUNT(*) AS nb_embauches,
    MIN(e.date_embauche) AS premiere_embauche,
    MAX(e.date_embauche) AS derniere_embauche
FROM employes e
JOIN departements d ON d.id_departement = e.departement_id
GROUP BY d.nom_departement
ORDER BY nb_embauches DESC;

-- 11. Quelle proportion des departs est volontaire vs involontaire?
SELECT
    type_depart,
    COUNT(*) AS nb_departs,
    ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER ()) * 100, 2) AS proportion_pct
FROM turnover
WHERE date_depart <= DATE '2026-08-01'
GROUP BY type_depart
ORDER BY nb_departs DESC;

-- 12. Quelle est la distribution des postes par anciennete?
SELECT
    poste,
    CASE
        WHEN anciennete_annees < 1 THEN '< 1 год'
        WHEN anciennete_annees < 3 THEN '1-2 года'
        WHEN anciennete_annees <= 5 THEN '3-5 лет'
        ELSE '> 5 лет'
    END AS tranche_anciennete,
    COUNT(*) AS nb_employes
FROM employes_enrichis
GROUP BY poste, tranche_anciennete
ORDER BY poste, tranche_anciennete;

-- 13. Quels employes n'ont pas encore recu de feedback cette annee?
-- Note: for calendar year 2026, performance data is absent in the source file.
SELECT ee.*
FROM employes_enrichis ee
WHERE ee.actif = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM performances p
      WHERE p.id_employe = ee.id_employe
        AND EXTRACT(YEAR FROM p.date_evaluation) = 2026
  );

-- 13b. Practical version: no feedback in the latest available performance year.
SELECT ee.*
FROM employes_enrichis ee
WHERE ee.actif = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM performances p
      WHERE p.id_employe = ee.id_employe
        AND EXTRACT(YEAR FROM p.date_evaluation) = (
            SELECT EXTRACT(YEAR FROM MAX(date_evaluation)) FROM performances
        )
  );

-- 14. Segmenter les employes par niveau de performance.
SELECT
    categorie_performance,
    COUNT(*) AS nb_employes,
    ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER ()) * 100, 2) AS proportion_pct
FROM employes_enrichis
GROUP BY categorie_performance
ORDER BY categorie_performance;

-- 15. Tableau resume avec KPIs par departement et par cohorte.
SELECT
    nom_departement,
    cohorte_embauche,
    COUNT(*) AS nb_employes,
    SUM(CASE WHEN actif THEN 1 ELSE 0 END) AS nb_actifs,
    COUNT(*) - SUM(CASE WHEN actif THEN 1 ELSE 0 END) AS nb_departs,
    ROUND((SUM(CASE WHEN actif THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS retention_pct,
    ROUND(AVG(salaire), 2) AS salaire_moyen,
    ROUND(AVG(anciennete_annees), 2) AS anciennete_moyenne,
    ROUND(AVG(score_moyen_total), 2) AS score_moyen
FROM employes_enrichis
GROUP BY nom_departement, cohorte_embauche
ORDER BY nom_departement, cohorte_embauche;
"@
Set-Content -Path 'sql/02_analysis_queries.sql' -Value $analysisSql -Encoding UTF8

Write-Host "Deliverables generated in outputs/ and sql/."




