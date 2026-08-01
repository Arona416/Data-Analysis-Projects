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
