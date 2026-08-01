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
