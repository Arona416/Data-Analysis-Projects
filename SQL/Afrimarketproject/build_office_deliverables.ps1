$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path 'deliverables' | Out-Null

function Escape-Xml([string]$Text) {
    if ($null -eq $Text) { return '' }
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-ZipFromMap($Path, [hashtable]$Files) {
    if (Test-Path $Path) { Remove-Item $Path -Force }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($name in $Files.Keys) {
            $entry = $zip.CreateEntry($name)
            $stream = $entry.Open()
            try {
                $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))
                $writer.Write($Files[$name])
            } finally {
                if ($writer) { $writer.Dispose() }
                $stream.Dispose()
            }
        }
    } finally {
        if ($zip) { $zip.Dispose() }
        $fs.Dispose()
    }
}

function W-Run($Text, $Bold = $false, $Size = 22, $Color = '1F2937') {
    $b = if ($Bold) { '<w:b/>' } else { '' }
    return "<w:r><w:rPr>$b<w:color w:val=""$Color""/><w:sz w:val=""$Size""/><w:szCs w:val=""$Size""/><w:rFonts w:ascii=""Calibri"" w:hAnsi=""Calibri"" w:cs=""Calibri""/><w:lang w:val=""ru-RU"" w:eastAsia=""ru-RU"" w:bidi=""ru-RU""/></w:rPr><w:t xml:space=""preserve"">$(Escape-Xml $Text)</w:t></w:r>"
}

function W-Para($Text, $Style = 'Normal', $Bold = $false, $Size = 22, $Color = '1F2937') {
    $styleXml = if ($Style -ne 'Normal') { "<w:pStyle w:val=""$Style""/>" } else { '' }
    return "<w:p><w:pPr>$styleXml<w:spacing w:after=""120"" w:line=""280"" w:lineRule=""auto""/></w:pPr>$(W-Run $Text $Bold $Size $Color)</w:p>"
}

function W-Cell($Text, $Width, $Header = $false, $Align = 'left') {
    $fill = if ($Header) { '<w:shd w:fill="E8EEF5"/>' } else { '' }
    $bold = if ($Header) { $true } else { $false }
    $size = if ($Header) { 19 } else { 18 }
    $color = if ($Header) { '0B2545' } else { '1F2937' }
    $jc = if ($Align -eq 'center') { '<w:jc w:val="center"/>' } elseif ($Align -eq 'right') { '<w:jc w:val="right"/>' } else { '' }
    $para = "<w:p><w:pPr>$jc<w:spacing w:after=""40"" w:line=""260"" w:lineRule=""auto""/></w:pPr>$(W-Run ([string]$Text) $bold $size $color)</w:p>"
    return "<w:tc><w:tcPr><w:tcW w:w=""$Width"" w:type=""dxa""/>$fill<w:vAlign w:val=""center""/><w:noWrap w:val=""0""/></w:tcPr>$para</w:tc>"
}

function W-Table($Headers, $Rows, $Widths = $null, $Alignments = $null) {
    $cols = $Headers.Count
    if ($null -eq $Widths) {
        $width = [math]::Floor(9360 / $cols)
        $Widths = @(for ($i = 0; $i -lt $cols; $i++) { $width })
    }
    if ($null -eq $Alignments) {
        $Alignments = @(for ($i = 0; $i -lt $cols; $i++) { if ($i -eq 0) { 'left' } else { 'center' } })
    }
    $grid = (($Widths | ForEach-Object { "<w:gridCol w:w=""$_""/>" }) -join '')
    $xml = "<w:tbl><w:tblPr><w:tblW w:w=""9360"" w:type=""dxa""/><w:tblInd w:w=""120"" w:type=""dxa""/><w:tblLayout w:type=""fixed""/><w:tblBorders><w:top w:val=""single"" w:sz=""6"" w:color=""AAB4C0""/><w:left w:val=""single"" w:sz=""4"" w:color=""D0D7DE""/><w:bottom w:val=""single"" w:sz=""6"" w:color=""AAB4C0""/><w:right w:val=""single"" w:sz=""4"" w:color=""D0D7DE""/><w:insideH w:val=""single"" w:sz=""4"" w:color=""D0D7DE""/><w:insideV w:val=""single"" w:sz=""4"" w:color=""E5E7EB""/></w:tblBorders><w:tblCellMar><w:top w:w=""120"" w:type=""dxa""/><w:left w:w=""170"" w:type=""dxa""/><w:bottom w:w=""120"" w:type=""dxa""/><w:right w:w=""170"" w:type=""dxa""/></w:tblCellMar></w:tblPr><w:tblGrid>$grid</w:tblGrid>"
    $xml += '<w:tr>'
    for ($i = 0; $i -lt $cols; $i++) {
        $xml += W-Cell $Headers[$i] $Widths[$i] $true $Alignments[$i]
    }
    $xml += '</w:tr>'
    $normalizedRows = @()
    $currentRow = @()
    foreach ($item in @($Rows)) {
        if (($item -is [array]) -and -not ($item -is [string]) -and $item.Count -eq $cols) {
            $normalizedRows += ,@($item)
        } else {
            $currentRow += $item
            if ($currentRow.Count -eq $cols) {
                $normalizedRows += ,@($currentRow)
                $currentRow = @()
            }
        }
    }
    foreach ($row in $normalizedRows) {
        $xml += '<w:tr>'
        for ($i = 0; $i -lt $cols; $i++) {
            $xml += W-Cell $row[$i] $Widths[$i] $false $Alignments[$i]
        }
        $xml += '</w:tr>'
    }
    return $xml + '</w:tbl>'
}

function Build-Docx {
    $path = (Resolve-Path '.').Path + '\deliverables\HR_Analytics_DataLendo_Insights_RU_PRESENTABLE.docx'
    $summary = Import-Csv 'outputs/kpi_global_summary.csv'
    $turnover = Import-Csv 'outputs/turnover_par_departement.csv' | Select-Object -First 5
    $perfDept = Import-Csv 'outputs/performance_moyenne_par_departement.csv' | Select-Object -First 5
    $salary = Import-Csv 'outputs/salaire_moyen_par_departement.csv' | Select-Object -First 5
    $retention = Import-Csv 'outputs/retention_par_cohorte.csv'
    $segments = Import-Csv 'outputs/segmentation_performance.csv'
    $departureTypes = Import-Csv 'outputs/proportion_departs_volontaires_involontaires.csv'

    $kpi = @{}
    foreach ($r in $summary) { $kpi[$r.metric] = $r.value }

    $body = ''
    $body += W-Para 'HR Analytics DataLendo' 'Title' $true 52 '0B2545'
    $body += W-Para 'Исполнительный аналитический отчет для руководства' 'Subtitle' $false 28 '475569'
    $body += W-Para 'Дата анализа: 2026-08-01 | Источник: employes, departements, performances, turnover' 'Normal' $false 20 '64748B'
    $body += W-Para 'Краткий вывод' 'Heading1' $true 32 '2E74B5'
    $body += W-Para "Компания имеет устойчивую базу сотрудников: $($kpi.active_employees) активных из $($kpi.employees_total). Основной управленческий риск находится не в общем масштабе увольнений, а в концентрации turnover по отдельным департаментам и в отсутствии свежего цикла performance feedback после 2024 года." 'Normal' $false 22 '1F2937'
    $body += W-Table @('Показатель','Значение','Интерпретация') @(
        @('Активные сотрудники', $kpi.active_employees, 'Основа для текущей численности и capacity planning'),
        @('Увольнения за 12 месяцев', $kpi.departures_last_12_months, 'Текущий уровень ухода умеренный, но требует анализа по департаментам'),
        @('Увольнения до даты анализа', $kpi.departures_until_reference, 'Историческая база для оценки retention'),
        @('Будущие даты увольнений в turnover', $kpi.future_departure_rows_after_reference, 'Не включены в текущий turnover; требуют проверки качества данных'),
        @('Последний год оценок', $kpi.latest_performance_year, 'Performance-процесс в данных не обновлен на 2026 год')
    ) @(2600, 1500, 5260) @('left','center','left')

    $body += W-Para 'Turnover и зоны риска' 'Heading1' $true 32 '2E74B5'
    $body += W-Para 'Наиболее высокий turnover наблюдается в Direction Générale, Data & Analytics и Juridique. Это приоритетные зоны для управленческого интервью, анализа причин ухода и сравнения компенсаций.' 'Normal' $false 22 '1F2937'
    $body += W-Table @('Департамент','Сотрудники','Активные','Увольнения','Turnover %') (
        $turnover | ForEach-Object { @($_.departement, $_.effectif_total, $_.employes_actifs, $_.departs_jusqu_au_2026_08_01, $_.taux_turnover_reference_pct) }
    ) @(3300, 1350, 1350, 1550, 1810) @('left','center','center','center','center')

    $body += W-Para 'Performance' 'Heading1' $true 32 '2E74B5'
    $body += W-Para 'Средние оценки по департаментам близки друг к другу, поэтому управленческий фокус лучше переносить с общего рейтинга на хвост распределения: сотрудников с низкой performance и департаменты, где низкая performance сочетается с turnover.' 'Normal' $false 22 '1F2937'
    $body += W-Table @('Департамент','Средний score','Кол-во оценок') (
        $perfDept | ForEach-Object { @($_.departement, $_.score_moyen_trimestriel, $_.nb_evaluations) }
    ) @(4300, 2300, 2760) @('left','center','center')

    $body += W-Para 'Компенсации' 'Heading1' $true 32 '2E74B5'
    $body += W-Para 'Разброс средней зарплаты между департаментами заметен. Для HR важнее всего сопоставить компенсацию с turnover: департаменты с высокой текучестью и низкой средней зарплатой должны попасть в отдельный compensation review.' 'Normal' $false 22 '1F2937'
    $body += W-Table @('Департамент','Средняя зарплата','Мин.','Макс.','Сотрудники') (
        $salary | ForEach-Object { @($_.departement, $_.salaire_moyen, $_.salaire_min, $_.salaire_max, $_.nb_employes) }
    ) @(3200, 1900, 1350, 1350, 1560) @('left','center','center','center','center')

    $body += W-Para 'Retention по когортам' 'Heading1' $true 32 '2E74B5'
    $body += W-Para 'Retention наиболее высокая у когорты 2023 года, но это естественно для более новой когорты. Для старших когорт важно смотреть не только процент удержания, но и причины ухода, качество onboarding и карьерные траектории.' 'Normal' $false 22 '1F2937'
    $body += W-Table @('Когорта','Наймы','Активные','Ушли','Retention %') (
        $retention | ForEach-Object { @($_.cohorte_embauche, $_.nb_embauches, $_.nb_actifs_au_2026_08_01, $_.nb_departs_avant_reference, $_.retention_pct) }
    ) @(1900, 1600, 1900, 1600, 2360) @('center','center','center','center','center')

    $body += W-Para 'Сегментация performance и увольнения' 'Heading1' $true 32 '2E74B5'
    $body += W-Table @('Сегмент performance','Сотрудники','Доля %') (
        $segments | ForEach-Object { @($_.categorie_performance, $_.nb_employes, $_.proportion_pct) }
    ) @(4600, 2300, 2460) @('left','center','center')
    $body += W-Table @('Тип ухода','Увольнения','Доля %') (
        $departureTypes | ForEach-Object { @($_.type_depart, $_.nb_departs, $_.proportion_pct) }
    ) @(4600, 2300, 2460) @('left','center','center')

    $body += W-Para 'Рекомендации руководству' 'Heading1' $true 32 '2E74B5'
    $body += W-Para '1. Провести targeted retention review в трех департаментах с максимальным turnover: интервью, анализ руководителей, нагрузки и компенсаций.' 'Normal' $false 22 '1F2937'
    $body += W-Para '2. Запустить план развития для сотрудников с низкой performance: 90-дневные цели, регулярный feedback и повторная оценка.' 'Normal' $false 22 '1F2937'
    $body += W-Para '3. Обновить процесс performance review: в данных нет оценок после 2024 года, поэтому текущая управленческая картина неполная.' 'Normal' $false 22 '1F2937'
    $body += W-Para '4. Совместить compensation review с turnover-анализом, особенно для департаментов с высокой текучестью.' 'Normal' $false 22 '1F2937'
    $body += W-Para '5. Создать ежеквартальный HR dashboard: активная численность, turnover, retention, performance-сегменты, сотрудники без feedback.' 'Normal' $false 22 '1F2937'

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$body
<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>
</w:body>
</w:document>
"@
    $stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:pPr><w:spacing w:after="80"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="52"/><w:color w:val="0B2545"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:pPr><w:spacing w:after="320"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="28"/><w:color w:val="475569"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:spacing w:before="320" w:after="160"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="32"/><w:color w:val="2E74B5"/></w:rPr></w:style>
</w:styles>
"@
    $contentTypes = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
"@
    $rels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"@
    $docRels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@
    New-ZipFromMap $path @{
        '[Content_Types].xml' = $contentTypes
        '_rels/.rels' = $rels
        'word/document.xml' = $documentXml
        'word/_rels/document.xml.rels' = $docRels
        'word/styles.xml' = $stylesXml
    }
    return $path
}

function AText($Id, $X, $Y, $W, $H, $Text, $Size = 2200, $Color = '1F2937', $Bold = $false) {
    $b = if ($Bold) { '<a:b/>' } else { '' }
    return @"
<p:sp><p:nvSpPr><p:cNvPr id="$Id" name="Text $Id"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$W" cy="$H"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" anchor="t"><a:spAutoFit/></a:bodyPr><a:lstStyle/><a:p><a:r><a:rPr lang="ru-RU" sz="$Size" dirty="0">$b<a:solidFill><a:srgbClr val="$Color"/></a:solidFill><a:latin typeface="Aptos"/><a:cs typeface="Aptos"/></a:rPr><a:t>$(Escape-Xml $Text)</a:t></a:r></a:p></p:txBody></p:sp>
"@
}

function ARect($Id, $X, $Y, $W, $H, $Fill = 'FFFFFF', $Line = 'D0D7DE') {
    return "<p:sp><p:nvSpPr><p:cNvPr id=""$Id"" name=""Box $Id""/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=""$X"" y=""$Y""/><a:ext cx=""$W"" cy=""$H""/></a:xfrm><a:prstGeom prst=""rect""><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=""$Fill""/></a:solidFill><a:ln w=""10000""><a:solidFill><a:srgbClr val=""$Line""/></a:solidFill></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
}

function ABar($Id, $X, $Y, $W, $H, $Fill = '2E74B5') {
    return "<p:sp><p:nvSpPr><p:cNvPr id=""$Id"" name=""Bar $Id""/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=""$X"" y=""$Y""/><a:ext cx=""$W"" cy=""$H""/></a:xfrm><a:prstGeom prst=""rect""><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=""$Fill""/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
}

function SlideXml($Inner) {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>$Inner</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>
"@
}

function Build-Pptx {
    $path = (Resolve-Path '.').Path + '\deliverables\HR_Analytics_DataLendo_Executive_Deck_RU.pptx'
    $turnover = Import-Csv 'outputs/turnover_par_departement.csv' | Select-Object -First 5
    $perfDept = Import-Csv 'outputs/performance_moyenne_par_departement.csv' | Select-Object -First 5
    $retention = Import-Csv 'outputs/retention_par_cohorte.csv'
    $segments = Import-Csv 'outputs/segmentation_performance.csv'
    $departureTypes = Import-Csv 'outputs/proportion_departs_volontaires_involontaires.csv'
    $salary = Import-Csv 'outputs/salaire_moyen_par_departement.csv' | Select-Object -First 5

    $slides = @()
    $s = ''
    $s += ARect 10 0 0 12192000 6858000 'F8FAFC' 'F8FAFC'
    $s += AText 11 640000 650000 7200000 650000 'HR Analytics DataLendo' 4200 '0B2545' $true
    $s += AText 12 650000 1320000 8800000 420000 'Исполнительные инсайты по численности, turnover, performance и retention' 2100 '475569'
    $s += AText 13 650000 5600000 6000000 320000 'Дата анализа: 2026-08-01 | Подготовлено для руководства' 1400 '64748B'
    $s += ARect 20 8200000 800000 2450000 1000000 '0B2545' '0B2545'
    $s += AText 21 8420000 1000000 2000000 420000 '1336' 3600 'FFFFFF' $true
    $s += AText 22 8420000 1450000 2100000 320000 'активных сотрудников' 1350 'CBD5E1'
    $s += ARect 23 8200000 2020000 2450000 1000000 '2E74B5' '2E74B5'
    $s += AText 24 8420000 2220000 2000000 420000 '24' 3600 'FFFFFF' $true
    $s += AText 25 8420000 2670000 2100000 320000 'ухода за 12 месяцев' 1350 'E0F2FE'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'FFFFFF' 'FFFFFF'
    $s += AText 11 550000 350000 8800000 420000 'Главный вывод: численность стабильна, но риск сконцентрирован по департаментам' 2600 '0B2545' $true
    $s += AText 12 550000 920000 9300000 300000 'Управленческий фокус: targeted retention, актуализация performance review и compensation review для зон риска.' 1500 '475569'
    $metrics = @(@('1336','активных'),@('164','ухода до даты анализа'),@('36','будущих дат ухода'),@('2024','последний год performance'))
    $x = 650000; $id=20
    foreach($m in $metrics){ $s += ARect $id $x 1700000 2400000 1100000 'F1F5F9' 'CBD5E1'; $s += AText ($id+1) ($x+160000) 1900000 1900000 390000 $m[0] 3000 '0B2545' $true; $s += AText ($id+2) ($x+160000) 2350000 1900000 280000 $m[1] 1300 '475569'; $x += 2700000; $id += 3 }
    $s += AText 40 650000 3650000 9000000 700000 'Риск данных: performance-оценки заканчиваются 2024 годом. Для принятия решений в 2026 году необходимо обновить HRIS или загрузить последний цикл feedback.' 1800 '1F2937'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'F8FAFC' 'F8FAFC'
    $s += AText 11 550000 350000 9200000 450000 'Turnover: три департамента требуют первого управленческого разбора' 2550 '0B2545' $true
    $y=1250000; $id=20
    foreach($r in $turnover){ $w=[int]([double]($r.taux_turnover_reference_pct -replace ',','.')*430000); $s += AText $id 800000 $y 2600000 300000 $r.departement 1250 '334155'; $s += ABar ($id+1) 3500000 ($y+30000) $w 240000 '2E74B5'; $s += AText ($id+2) (3600000+$w) $y 900000 280000 "$($r.taux_turnover_reference_pct)%" 1250 '0B2545' $true; $y += 620000; $id += 3 }
    $s += AText 50 750000 5000000 9000000 420000 'Приоритет: Direction Générale, Data & Analytics, Juridique. Рекомендуется провести интервью причин ухода и проверить менеджерскую нагрузку.' 1600 '475569'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'FFFFFF' 'FFFFFF'
    $s += AText 11 550000 350000 9300000 450000 'Performance: средние оценки близки, управлять нужно хвостом распределения' 2550 '0B2545' $true
    $y=1250000; $id=20
    foreach($r in $perfDept){ $w=[int]([double]($r.score_moyen_trimestriel -replace ',','.')*85000); $s += AText $id 800000 $y 2600000 300000 $r.departement 1250 '334155'; $s += ABar ($id+1) 3500000 ($y+30000) $w 240000 '10B981'; $s += AText ($id+2) (3600000+$w) $y 900000 280000 $r.score_moyen_trimestriel 1250 '064E3B' $true; $y += 620000; $id += 3 }
    $s += AText 50 750000 5000000 9000000 420000 'Разница между департаментами невелика; больший эффект даст работа с низким performance-сегментом и сотрудниками без свежего feedback.' 1600 '475569'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'F8FAFC' 'F8FAFC'
    $s += AText 11 550000 350000 9200000 450000 'Retention по когортам: новые когорты удерживаются лучше, старшие требуют диагностики' 2500 '0B2545' $true
    $y=1300000; $id=20
    foreach($r in $retention){ $w=[int]([double]($r.retention_pct -replace ',','.')*85000); $s += AText $id 900000 $y 900000 300000 $r.cohorte_embauche 1300 '334155' $true; $s += ABar ($id+1) 2000000 ($y+30000) $w 240000 'F59E0B'; $s += AText ($id+2) (2100000+$w) $y 900000 280000 "$($r.retention_pct)%" 1250 '92400E' $true; $y += 650000; $id += 3 }
    $s += AText 50 750000 5100000 9100000 420000 'Когорта 2023 показывает 94,37%, но ее горизонт наблюдения короче. Для честного вывода нужен когортный мониторинг по одинаковому периоду после найма.' 1550 '475569'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'FFFFFF' 'FFFFFF'
    $s += AText 11 550000 350000 9300000 450000 'Компенсации: проверять нужно связь зарплаты и ухода, а не только средние значения' 2500 '0B2545' $true
    $y=1300000; $id=20
    foreach($r in $salary){ $w=[int]([double]($r.salaire_moyen -replace ',','.')*1700); $s += AText $id 850000 $y 2600000 300000 $r.departement 1250 '334155'; $s += ABar ($id+1) 3600000 ($y+30000) $w 240000 '6366F1'; $s += AText ($id+2) (3700000+$w) $y 900000 280000 $r.salaire_moyen 1250 '3730A3' $true; $y += 610000; $id += 3 }
    $s += AText 50 750000 5050000 8900000 420000 'Следующий шаг: построить матрицу "turnover x salaire moyen" и определить департаменты для compensation review.' 1600 '475569'
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 'F8FAFC' 'F8FAFC'
    $s += AText 11 550000 350000 9300000 450000 'Сегменты performance и типы увольнений задают HR-план действий' 2550 '0B2545' $true
    $x=900000; $id=20
    foreach($r in $segments){ $s += ARect $id $x 1350000 2700000 850000 'EEF2FF' 'CBD5E1'; $s += AText ($id+1) ($x+180000) 1530000 2200000 300000 $r.categorie_performance 1450 '3730A3' $true; $s += AText ($id+2) ($x+180000) 1880000 2200000 300000 "$($r.nb_employes) сотрудников | $($r.proportion_pct)%" 1250 '475569'; $x += 3100000; $id += 3 }
    $x=1500000
    foreach($r in $departureTypes){ $s += ARect $id $x 3300000 3600000 800000 'F8FAFC' '94A3B8'; $s += AText ($id+1) ($x+180000) 3480000 3100000 280000 "Уход: $($r.type_depart)" 1400 '0B2545' $true; $s += AText ($id+2) ($x+180000) 3820000 3100000 280000 "$($r.nb_departs) случаев | $($r.proportion_pct)%" 1250 '475569'; $x += 4100000; $id += 3 }
    $slides += SlideXml $s

    $s = ARect 10 0 0 12192000 6858000 '0B2545' '0B2545'
    $s += AText 11 650000 420000 9000000 450000 'Решения для руководства на следующий квартал' 2800 'FFFFFF' $true
    $actions = @(
        'Targeted retention review в 3 департаментах с максимальным turnover',
        '90-дневные планы развития для low-performance сотрудников',
        'Обновить performance feedback за 2025-2026 и закрыть пробел данных',
        'Запустить compensation review там, где turnover сочетается с низкой зарплатой',
        'Собрать ежеквартальный HR dashboard для Executive Team'
    )
    $y=1300000; $id=20; $n=1
    foreach($a in $actions){ $s += AText $id 900000 $y 500000 320000 "$n" 2000 '93C5FD' $true; $s += AText ($id+1) 1500000 $y 8800000 360000 $a 1700 'E2E8F0'; $y += 760000; $id += 2; $n++ }
    $slides += SlideXml $s

    $slideFiles = @{}
    $slideRels = @{}
    for($i=1; $i -le $slides.Count; $i++){
        $slideFiles["ppt/slides/slide$i.xml"] = $slides[$i-1]
        $slideRels["ppt/slides/_rels/slide$i.xml.rels"] = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?><Relationships xmlns=""http://schemas.openxmlformats.org/package/2006/relationships""><Relationship Id=""rId1"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"" Target=""../slideLayouts/slideLayout1.xml""/></Relationships>"
    }
    $slideIds = ''; $presRels = ''
    for($i=1; $i -le $slides.Count; $i++){ $rid="rId$i"; $sid=255+$i; $slideIds += "<p:sldId id=""$sid"" r:id=""$rid""/>"; $presRels += "<Relationship Id=""$rid"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"" Target=""slides/slide$i.xml""/>" }
    $presRels += '<Relationship Id="rIdMaster" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rIdTheme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>'
    $presentationXml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?><p:presentation xmlns:a=""http://schemas.openxmlformats.org/drawingml/2006/main"" xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships"" xmlns:p=""http://schemas.openxmlformats.org/presentationml/2006/main""><p:sldMasterIdLst><p:sldMasterId id=""2147483648"" r:id=""rIdMaster""/></p:sldMasterIdLst><p:sldIdLst>$slideIds</p:sldIdLst><p:sldSz cx=""12192000"" cy=""6858000"" type=""screen16x9""/><p:notesSz cx=""6858000"" cy=""9144000""/></p:presentation>"
    $contentTypes = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?><Types xmlns=""http://schemas.openxmlformats.org/package/2006/content-types""><Default Extension=""rels"" ContentType=""application/vnd.openxmlformats-package.relationships+xml""/><Default Extension=""xml"" ContentType=""application/xml""/><Override PartName=""/ppt/presentation.xml"" ContentType=""application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml""/><Override PartName=""/ppt/slideMasters/slideMaster1.xml"" ContentType=""application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml""/><Override PartName=""/ppt/slideLayouts/slideLayout1.xml"" ContentType=""application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml""/><Override PartName=""/ppt/theme/theme1.xml"" ContentType=""application/vnd.openxmlformats-officedocument.theme+xml""/>"
    for($i=1; $i -le $slides.Count; $i++){ $contentTypes += "<Override PartName=""/ppt/slides/slide$i.xml"" ContentType=""application/vnd.openxmlformats-officedocument.presentationml.slide+xml""/>" }
    $contentTypes += '</Types>'
    $files = @{
        '[Content_Types].xml' = $contentTypes
        '_rels/.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>'
        'ppt/presentation.xml' = $presentationXml
        'ppt/_rels/presentation.xml.rels' = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?><Relationships xmlns=""http://schemas.openxmlformats.org/package/2006/relationships"">$presRels</Relationships>"
        'ppt/slideMasters/slideMaster1.xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>'
        'ppt/slideMasters/_rels/slideMaster1.xml.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>'
        'ppt/slideLayouts/slideLayout1.xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld></p:sldLayout>'
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>'
        'ppt/theme/theme1.xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="DataLendo"><a:themeElements><a:clrScheme name="DataLendo"><a:dk1><a:srgbClr val="0B2545"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="1F2937"/></a:dk2><a:lt2><a:srgbClr val="F8FAFC"/></a:lt2><a:accent1><a:srgbClr val="2E74B5"/></a:accent1><a:accent2><a:srgbClr val="10B981"/></a:accent2><a:accent3><a:srgbClr val="F59E0B"/></a:accent3><a:accent4><a:srgbClr val="6366F1"/></a:accent4><a:accent5><a:srgbClr val="EF4444"/></a:accent5><a:accent6><a:srgbClr val="64748B"/></a:accent6><a:hlink><a:srgbClr val="2E74B5"/></a:hlink><a:folHlink><a:srgbClr val="6366F1"/></a:folHlink></a:clrScheme><a:fontScheme name="DataLendo"><a:majorFont><a:latin typeface="Aptos Display"/><a:cs typeface="Aptos"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/><a:cs typeface="Aptos"/></a:minorFont></a:fontScheme><a:fmtScheme name="DataLendo"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle/></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>'
    }
    foreach($k in $slideFiles.Keys){ $files[$k] = $slideFiles[$k] }
    foreach($k in $slideRels.Keys){ $files[$k] = $slideRels[$k] }
    New-ZipFromMap $path $files
    return $path
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$docx = Build-Docx
$pptx = Build-Pptx
Write-Host "Created: $docx"
Write-Host "Created: $pptx"



